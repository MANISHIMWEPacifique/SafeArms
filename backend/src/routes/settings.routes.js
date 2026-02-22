const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/authentication');
const { requireAdmin } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');
const { triggerManualTraining } = require('../jobs/modelTraining.job');
const logger = require('../utils/logger');

// Get audit logs - mounted at /api/audit-logs
router.get('/', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    // Check if this is the audit-logs endpoint
    if (req.baseUrl === '/api/audit-logs') {
        const { start_date, end_date, user_id, action, status, limit = 100, offset = 0 } = req.query;
        
        let sql = `
            SELECT 
                al.*,
                u.full_name as user_name,
                u.username
            FROM audit_logs al
            LEFT JOIN users u ON al.user_id = u.user_id
            WHERE 1=1
        `;
        const params = [];
        let paramIndex = 1;
        
        if (start_date) {
            sql += ` AND al.created_at >= $${paramIndex}`;
            params.push(start_date);
            paramIndex++;
        }
        
        if (end_date) {
            sql += ` AND al.created_at <= $${paramIndex}`;
            params.push(end_date);
            paramIndex++;
        }
        
        if (user_id) {
            sql += ` AND al.user_id = $${paramIndex}`;
            params.push(user_id);
            paramIndex++;
        }
        
        if (action) {
            sql += ` AND al.action_type = $${paramIndex}`;
            params.push(action);
            paramIndex++;
        }
        
        sql += ` ORDER BY al.created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
        params.push(parseInt(limit), parseInt(offset));
        
        const result = await query(sql, params);
        return res.json({ success: true, data: result.rows });
    }
    
    // Otherwise, return system settings
    res.json({
        success: true,
        data: {
            platform_name: 'SafeArms',
            organization: 'Rwanda National Police',
            timezone: 'Africa/Kigali',
            date_format: 'DD/MM/YYYY',
            time_format: '24-hour',
            session_timeout: 30,
            concurrent_sessions: false,
            remember_me_duration: 7,
            two_factor_required: false,
            password_expiry_days: 90,
            min_password_length: 8,
            max_login_attempts: 5,
            lockout_duration: 15,
            audit_retention_days: 365,
            backup_frequency: 'daily',
            notification_email: true,
            notification_sms: false
        }
    });
}));

// Update system settings
router.put('/', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    // In production, save to database
    const settings = req.body;
    
    // Log the settings update
    await query(`
        INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, 'UPDATE', 'system_settings', $2, $3)
    `, [req.user.user_id, JSON.stringify(settings), req.ip]);
    
    res.json({
        success: true,
        message: 'Settings updated successfully',
        data: settings
    });
}));

// Get system health
router.get('/health', authenticate, asyncHandler(async (req, res) => {
    // Check database connection
    let dbStatus = 'healthy';
    let dbResponseTime = 0;
    
    try {
        const start = Date.now();
        await query('SELECT 1');
        dbResponseTime = Date.now() - start;
    } catch (e) {
        dbStatus = 'unhealthy';
    }
    
    // Get some stats
    const statsResult = await query(`
        SELECT 
            (SELECT COUNT(*) FROM users WHERE is_active = true) as active_users,
            (SELECT COUNT(*) FROM firearms WHERE is_active = true) as total_firearms,
            (SELECT COUNT(*) FROM custody_records WHERE returned_at IS NULL) as active_custody,
            (SELECT COUNT(*) FROM anomalies WHERE status IN ('open', 'pending')) as pending_anomalies
    `);
    
    res.json({
        success: true,
        data: {
            status: 'operational',
            database: {
                status: dbStatus,
                response_time_ms: dbResponseTime
            },
            services: {
                authentication: 'operational',
                ml_anomaly_detection: 'operational',
                background_jobs: 'operational'
            },
            stats: statsResult.rows[0],
            uptime: process.uptime(),
            memory_usage: process.memoryUsage(),
            timestamp: new Date().toISOString()
        }
    });
}));

// Get ML configuration
router.get('/ml-config', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    res.json({
        success: true,
        data: {
            anomaly_detection: {
                enabled: true,
                threshold: 0.85,
                model_type: 'random_forest',
                training_frequency: 'weekly',
                last_trained: null
            },
            features: {
                temporal_patterns: true,
                geographic_clustering: true,
                behavioral_analysis: true,
                network_analysis: true
            },
            alerts: {
                email_notifications: true,
                dashboard_alerts: true,
                severity_threshold: 'medium'
            }
        }
    });
}));

// Update ML configuration
router.put('/ml-config', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const config = req.body;
    
    // Log the ML config update
    await query(`
        INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, 'UPDATE', 'ml_configuration', $2, $3)
    `, [req.user.user_id, JSON.stringify(config), req.ip]);
    
    res.json({
        success: true,
        message: 'ML configuration updated successfully',
        data: config
    });
}));

// ML config endpoint for /api/ml/config
router.get('/config', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    res.json({
        success: true,
        data: {
            anomaly_detection: {
                enabled: true,
                threshold: 0.85,
                model_type: 'random_forest',
                training_frequency: 'weekly',
                last_trained: null
            },
            features: {
                temporal_patterns: true,
                geographic_clustering: true,
                behavioral_analysis: true,
                network_analysis: true
            },
            alerts: {
                email_notifications: true,
                dashboard_alerts: true,
                severity_threshold: 'medium'
            }
        }
    });
}));

router.put('/config', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const config = req.body;
    
    await query(`
        INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, 'UPDATE', 'ml_configuration', $2, $3)
    `, [req.user.user_id, JSON.stringify(config), req.ip]);
    
    res.json({
        success: true,
        message: 'ML configuration updated successfully',
        data: config
    });
}));

// Trigger ML model training manually
router.post('/train', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    logger.info(`ML model training triggered by user: ${req.user.user_id}`);
    
    // Log the training initiation
    await query(`
        INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, 'TRAIN', 'ml_model', '{"status": "initiated"}', $2)
    `, [req.user.user_id, req.ip]);
    
    // Trigger actual training (async - don't wait for completion)
    triggerManualTraining().then(() => {
        logger.info('ML model training completed successfully');
    }).catch((err) => {
        logger.error('ML model training failed:', err);
    });
    
    res.json({
        success: true,
        message: 'ML model training initiated. This may take a few minutes.',
        data: {
            status: 'training',
            started_at: new Date().toISOString()
        }
    });
}));

// Get ML model status
router.get('/ml-status', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    // Get active model info
    const modelResult = await query(`
        SELECT 
            model_id,
            model_type,
            training_date,
            training_samples_count as training_samples,
            num_clusters,
            silhouette_score,
            is_active
        FROM ml_model_metadata
        WHERE is_active = true
        ORDER BY training_date DESC
        LIMIT 1
    `);
    
    const model = modelResult.rows[0] || null;
    
    // Get training features count
    const featuresResult = await query(`
        SELECT COUNT(*) as count
        FROM ml_training_features
        WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);
    
    const availableSamples = parseInt(featuresResult.rows[0].count);
    
    // Get recent anomaly stats
    const anomalyResult = await query(`
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'false_positive') as false_positives
        FROM anomalies
        WHERE detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
    `);
    
    const anomalyStats = anomalyResult.rows[0];
    
    res.json({
        success: true,
        data: {
            active_model: model ? {
                model_id: model.model_id,
                model_type: model.model_type,
                training_date: model.training_date,
                training_samples: model.training_samples,
                num_clusters: model.num_clusters,
                silhouette_score: model.silhouette_score
            } : null,
            available_training_samples: availableSamples,
            minimum_required_samples: 100,
            can_train: availableSamples >= 100,
            recent_detections: parseInt(anomalyStats.total),
            false_positive_rate: anomalyStats.total > 0 
                ? (parseInt(anomalyStats.false_positives) / parseInt(anomalyStats.total) * 100).toFixed(1) + '%'
                : '0%'
        }
    });
}));

module.exports = router;
