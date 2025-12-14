const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const { pool } = require('./config/database');
const { SERVER_CONFIG } = require('./config/server');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const logger = require('./utils/logger');

// Import background jobs
const { scheduleModelTraining } = require('./jobs/modelTraining.job');
const { scheduleViewRefresh } = require('./jobs/viewRefresh.job');

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
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

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
        description: 'Police Firearm Control and Forensic Support Platform',
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

// Start server
const PORT = SERVER_CONFIG.port;

const server = app.listen(PORT, async () => {
    console.log('\n========================================');
    console.log('🔷 SafeArms Backend Server');
    console.log('========================================');
    console.log(`✅ Server running on port ${PORT}`);
    console.log(`✅ Environment: ${SERVER_CONFIG.nodeEnv}`);
    console.log(`✅ API Base URL: ${SERVER_CONFIG.apiBaseUrl}`);

    // Test database connection
    try {
        await pool.query('SELECT NOW()');
        console.log('✅ Database connected successfully');
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
    }

    // Schedule background jobs
    try {
        scheduleModelTraining();
        scheduleViewRefresh();
        console.log('✅ Background jobs scheduled');
    } catch (error) {
        console.error('⚠️  Failed to schedule background jobs:', error.message);
    }

    console.log('========================================\n');
    logger.info(`SafeArms backend server started on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully...');
    server.close(() => {
        logger.info('Server closed');
        pool.end(() => {
            logger.info('Database pool closed');
            process.exit(0);
        });
    });
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully...');
    server.close(() => {
        logger.info('Server closed');
        pool.end(() => {
            logger.info('Database pool closed');
            process.exit(0);
        });
    });
});

module.exports = app;
