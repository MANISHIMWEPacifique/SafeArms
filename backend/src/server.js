const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const { pool, setShuttingDown } = require('./config/database');
const { SERVER_CONFIG } = require('./config/server');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const logger = require('./utils/logger');

// Import background jobs
const { scheduleModelTraining } = require('./jobs/modelTraining.job');
const { scheduleViewRefresh } = require('./jobs/viewRefresh.job');
const { scheduleOverdueDetection } = require('./jobs/overdueDetection.job');

// Import routes
const authRoutes = require('./routes/auth.routes');
const usersRoutes = require('./routes/users.routes');
const unitsRoutes = require('./routes/units.routes');
const officersRoutes = require('./routes/officers.routes');
const firearmsRoutes = require('./routes/firearms.routes');
const custodyRoutes = require('./routes/custody.routes');
const anomaliesRoutes = require('./routes/anomalies.routes');
const approvalsRoutes = require('./routes/approvals.routes');
const dashboardRoutes = require('./routes/dashboard.routes');
const ballisticRoutes = require('./routes/ballistic.routes');
const reportsRoutes = require('./routes/reports.routes');
const settingsRoutes = require('./routes/settings.routes');

// Initialize Express app
const app = express();

// Security middleware
app.use(helmet());
app.use(cors(SERVER_CONFIG.cors));

// Logging middleware
if (SERVER_CONFIG.nodeEnv === 'development') {
    app.use(morgan('dev'));
} else {
    app.use(morgan('combined', {
        stream: {
            write: (message) => logger.info(message.trim())
        }
    }));
}

// Body parsing middleware
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ extended: true, limit: '2mb' }));

// Static firearm image uploads
const firearmUploadsDir = path.join(__dirname, '../uploads/firearms');
if (!fs.existsSync(firearmUploadsDir)) {
    fs.mkdirSync(firearmUploadsDir, { recursive: true });
}
app.use('/uploads/firearms', express.static(firearmUploadsDir));

// Static user profile photo uploads
const userUploadsDir = path.join(__dirname, '../uploads/users');
if (!fs.existsSync(userUploadsDir)) {
    fs.mkdirSync(userUploadsDir, { recursive: true });
}
app.use('/uploads/users', express.static(userUploadsDir));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        environment: SERVER_CONFIG.nodeEnv
    });
});

// API Info endpoint
app.get('/api', (req, res) => {
    res.json({
        name: 'SafeArms API',
        version: '1.0.0',
        description: 'Police Firearm Control and Investigation Support Platform',
        endpoints: {
            health: '/health',
            auth: '/api/auth',
            users: '/api/users',
            units: '/api/units',
            officers: '/api/officers',
            firearms: '/api/firearms',
            custody: '/api/custody',
            anomalies: '/api/anomalies',
            approvals: '/api/approvals',
            dashboard: '/api/dashboard',
            ballisticProfiles: '/api/ballistic-profiles',
            reports: '/api/reports'
        }
    });
});

// Mount API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/units', unitsRoutes);
app.use('/api/officers', officersRoutes);
app.use('/api/firearms', firearmsRoutes);
app.use('/api/custody', custodyRoutes);
app.use('/api/anomalies', anomaliesRoutes);
app.use('/api/approvals', approvalsRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/ballistic-profiles', ballisticRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/settings', settingsRoutes);
app.use('/api/audit-logs', settingsRoutes);  // For /api/audit-logs endpoint
app.use('/api/system', settingsRoutes);       // For /api/system/health endpoint
app.use('/api/ml', settingsRoutes);           // For /api/ml/config and /api/ml/train endpoints

// 404 handler
app.use(notFoundHandler);

// Global error handler
app.use(errorHandler);

// Start server — verify DB *before* accepting traffic
const PORT = SERVER_CONFIG.port;

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const waitForDatabase = async () => {
    const maxAttempts = parseInt(process.env.DB_CONNECT_RETRIES || '6', 10);
    const retryDelayMs = parseInt(process.env.DB_CONNECT_RETRY_DELAY_MS || '3000', 10);

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
            await pool.query('SELECT NOW()');
            return;
        } catch (error) {
            if (attempt === maxAttempts) {
                throw error;
            }

            console.warn(
                `[WARN] Database check attempt ${attempt}/${maxAttempts} failed: ${error.message}. Retrying in ${retryDelayMs}ms...`
            );
            await sleep(retryDelayMs);
        }
    }
};

(async () => {
    console.log('\n========================================');
    console.log('[SafeArms] Backend Server');
    console.log('========================================');
    console.log(`[..] Environment: ${SERVER_CONFIG.nodeEnv}`);

    // 1. Test database connection before binding port
    try {
        await waitForDatabase();
        console.log('[OK] Database connected successfully');
    } catch (error) {
        console.error('[ERROR] Database connection failed:', error.message);
        console.error('[ERROR] Server will not start without a database connection.');
        process.exit(1);
    }

    // 2. Bind port only after DB is confirmed
    let bootstrapTimer = null;
    const server = app.listen(PORT, () => {
        console.log(`[OK] Server running on port ${PORT}`);
        console.log(`[OK] API Base URL: ${SERVER_CONFIG.apiBaseUrl}`);

        // 3. Schedule background jobs (non-critical)
        try {
            scheduleModelTraining();
            scheduleViewRefresh();
            scheduleOverdueDetection();
            console.log('[OK] Background jobs scheduled');
        } catch (error) {
            console.error('[WARN] Failed to schedule background jobs:', error.message);
        }

        // 4. Bootstrap feature extraction + rules-based detection (delayed, non-blocking)
        //    NOTE: This does NOT train the ML model. Model training is admin-initiated
        //    (via Settings > Train Model) or scheduled every 3 weeks.
        bootstrapTimer = setTimeout(async () => {
            try {
                const { bootstrapIfNeeded } = require('./jobs/modelTraining.job');
                await bootstrapIfNeeded();
            } catch (e) {
                logger.error('ML bootstrap check failed:', e);
            }
        }, 10000);

        console.log('========================================\n');
        logger.info(`SafeArms backend server started on port ${PORT}`);
    });

    // Expose server for graceful shutdown handlers
    setupShutdown(server, bootstrapTimer);
})();

function setupShutdown(server, bootstrapTimer) {

    const shutdown = (signal) => {
        logger.info(`${signal} received, shutting down gracefully...`);

        // Prevent new queries from being dispatched
        setShuttingDown();

        // Cancel pending bootstrap if it hasn't fired yet
        if (bootstrapTimer) clearTimeout(bootstrapTimer);

        // Force exit after 10s if graceful shutdown stalls
        const forceTimer = setTimeout(() => {
            logger.error('Graceful shutdown timed out, forcing exit');
            process.exit(1);
        }, 10000);
        forceTimer.unref();

        server.close(() => {
            logger.info('Server closed');
            pool.end(() => {
                logger.info('Database pool closed');
                process.exit(0);
            });
        });
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    process.on('unhandledRejection', (reason, promise) => {
        logger.error('Unhandled Rejection at:', { promise, reason: reason?.toString() });
    });

    process.on('uncaughtException', (error) => {
        logger.error('Uncaught Exception:', { message: error.message, stack: error.stack });
        process.exit(1);
    });
}

module.exports = app;
