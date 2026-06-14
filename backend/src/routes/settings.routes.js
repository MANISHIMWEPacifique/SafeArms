const express = require('express');
const router = express.Router();
const { authenticate } = require('../middleware/authentication');
const { requireAdmin } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');
const { triggerManualTraining, getLatestTrainingRun } = require('../jobs/modelTraining.job');
const { getMinTrainingSamples } = require('../ml/modelTrainer');
const { triggerManualOverdueScan } = require('../jobs/overdueDetection.job');
const { generateTrainingDataBatch } = require('../services/trainingDataGenerator.service');
const { mergeSystemSettingsCache } = require('../services/systemSettings.service');
const logger = require('../utils/logger');

const DEFAULT_SETTINGS = {
    platform_name: 'SafeArms',
    organization: 'Rwanda National Police',
    timezone: 'Africa/Kigali',
    date_format: 'DD/MM/YYYY',
    time_format: '24-hour',
    items_per_page: 25,
    session_timeout: 30,
    concurrent_sessions: false,
    remember_me_duration: 7,
    two_factor_required: false,
    password_expiry_days: 90,
    min_password_length: 8,
    otp_validity_minutes: 5,
    max_otp_attempts: 3,
    enforce_2fa: true,
    max_login_attempts: 5,
    lockout_duration: 15,
    auth_rate_limit_window_minutes: 15,
    auth_rate_limit_max_per_ip: 60,
    auth_rate_limit_max_per_account: 10,
    audit_retention_days: 365,
    backup_frequency: 'daily',
    anomaly_threshold: 0.70,
    critical_threshold: 0.85,
    anomaly_trigger_threshold: 0.35,
    anomaly_medium_threshold: 0.50,
    anomaly_high_threshold: 0.70,
    anomaly_critical_threshold: 0.85,
    anomaly_critical_min_confidence: 0.60,
    auto_refresh_enabled: true,
    auto_refresh_interval: 5,
    notify_critical_anomalies: true,
    notify_pending_approvals: true,
    notify_custody_changes: false,
    notification_email: true,
    notification_sms: false
};

const ANOMALY_SCORING_THRESHOLD_KEYS = [
    'anomaly_trigger_threshold',
    'anomaly_medium_threshold',
    'anomaly_high_threshold',
    'anomaly_critical_threshold',
    'anomaly_critical_min_confidence'
];

const toOptionalNumber = (value) => {
    if (typeof value === 'number' && Number.isFinite(value)) {
        return value;
    }

    if (typeof value === 'string' && value.trim().length > 0) {
        const parsed = Number.parseFloat(value);
        if (Number.isFinite(parsed)) {
            return parsed;
        }
    }

    return null;
};

const ENUM_SETTINGS = {
    date_format: ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'],
    time_format: ['24-hour', '12-hour']
};

const INTEGER_SETTINGS = {
    items_per_page: { min: 5, max: 200 },
    session_timeout: { min: 5, max: 1440 },
    min_password_length: { min: 8, max: 128 },
    otp_validity_minutes: { min: 1, max: 60 },
    max_otp_attempts: { min: 1, max: 10 },
    auto_refresh_interval: { min: 1, max: 60 }
};

const NUMBER_SETTINGS = {
    anomaly_threshold: { min: 0, max: 1 },
    critical_threshold: { min: 0, max: 1 },
    anomaly_trigger_threshold: { min: 0, max: 1 },
    anomaly_medium_threshold: { min: 0, max: 1 },
    anomaly_high_threshold: { min: 0, max: 1 },
    anomaly_critical_threshold: { min: 0, max: 1 },
    anomaly_critical_min_confidence: { min: 0, max: 1 }
};

const BOOLEAN_SETTINGS = new Set([
    'enforce_2fa',
    'auto_refresh_enabled',
    'notify_critical_anomalies',
    'notify_pending_approvals',
    'notify_custody_changes'
]);

const parseSettingNumber = (value) => (
    typeof value === 'number'
        ? value
        : (typeof value === 'string' && value.trim().length > 0 ? Number.parseFloat(value) : NaN)
);

const parseSettingBoolean = (value) => {
    if (typeof value === 'boolean') {
        return value;
    }

    const normalized = typeof value === 'string' ? value.trim().toLowerCase() : '';
    if (normalized === 'true') {
        return true;
    }
    if (normalized === 'false') {
        return false;
    }

    return null;
};

const normalizeKnownSettings = (settings) => {
    const normalized = { ...settings };
    const errors = [];

    for (const [key, value] of Object.entries(settings)) {
        if (ENUM_SETTINGS[key]) {
            const normalizedValue = typeof value === 'string' ? value.trim() : '';
            if (ENUM_SETTINGS[key].includes(normalizedValue)) {
                normalized[key] = normalizedValue;
            } else {
                errors.push(`${key} must be one of: ${ENUM_SETTINGS[key].join(', ')}.`);
            }
            continue;
        }

        const integerBounds = INTEGER_SETTINGS[key];
        if (integerBounds) {
            const parsed = parseSettingNumber(value);
            if (Number.isInteger(parsed) && parsed >= integerBounds.min && parsed <= integerBounds.max) {
                normalized[key] = parsed;
            } else {
                errors.push(`${key} must be a whole number between ${integerBounds.min} and ${integerBounds.max}.`);
            }
            continue;
        }

        const numberBounds = NUMBER_SETTINGS[key];
        if (numberBounds) {
            const parsed = parseSettingNumber(value);
            if (Number.isFinite(parsed) && parsed >= numberBounds.min && parsed <= numberBounds.max) {
                normalized[key] = parsed;
            } else {
                errors.push(`${key} must be a number between ${numberBounds.min} and ${numberBounds.max}.`);
            }
            continue;
        }

        if (BOOLEAN_SETTINGS.has(key)) {
            const parsed = parseSettingBoolean(value);
            if (parsed === null) {
                errors.push(`${key} must be true or false.`);
            } else {
                normalized[key] = parsed;
            }
        }
    }

    return {
        isValid: errors.length === 0,
        errors,
        normalized
    };
};

const validateAnomalyScoringThresholds = (settings) => {
    const normalized = {};
    const errors = [];

    for (const key of ANOMALY_SCORING_THRESHOLD_KEYS) {
        const value = toOptionalNumber(settings[key]);
        if (value === null) {
            errors.push(`${key} must be numeric.`);
            continue;
        }

        if (value < 0 || value > 1) {
            errors.push(`${key} must be between 0 and 1.`);
            continue;
        }

        normalized[key] = value;
    }

    if (errors.length === 0) {
        if (!(
            normalized.anomaly_trigger_threshold <= normalized.anomaly_medium_threshold &&
            normalized.anomaly_medium_threshold <= normalized.anomaly_high_threshold &&
            normalized.anomaly_high_threshold <= normalized.anomaly_critical_threshold
        )) {
            errors.push('Threshold ordering must satisfy anomaly_trigger_threshold <= anomaly_medium_threshold <= anomaly_high_threshold <= anomaly_critical_threshold.');
        }
    }

    return {
        isValid: errors.length === 0,
        errors,
        normalized
    };
};

const parsePositiveInt = (value, fallback) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const SETTINGS_CACHE_TTL_MS = parsePositiveInt(process.env.SETTINGS_CACHE_TTL_MS, 30000);

const settingsCache = {
    data: null,
    cachedAt: 0
};

const getDefaultSettings = () => ({ ...DEFAULT_SETTINGS });

const getCachedSettings = () => {
    if (!settingsCache.data) {
        return null;
    }

    if (Date.now() - settingsCache.cachedAt > SETTINGS_CACHE_TTL_MS) {
        settingsCache.data = null;
        settingsCache.cachedAt = 0;
        return null;
    }

    return settingsCache.data;
};

const setCachedSettings = (settings) => {
    settingsCache.data = settings;
    settingsCache.cachedAt = Date.now();
};

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
    
    // Otherwise, return system settings from database table
    try {
        const cachedSettings = getCachedSettings();
        if (cachedSettings) {
            return res.json({
                success: true,
                data: cachedSettings
            });
        }

        const result = await query('SELECT setting_key, setting_value FROM system_settings');
        
        const settings = {};
        for (const row of result.rows) {
            settings[row.setting_key] = row.setting_value;
        }

        // If the table is empty for some reason, provide fallbacks
        if (Object.keys(settings).length === 0) {
            const defaultSettings = getDefaultSettings();
            setCachedSettings(defaultSettings);
            mergeSystemSettingsCache(defaultSettings);
            return res.json({
                success: true,
                data: defaultSettings
            });
        }

        setCachedSettings(settings);
        mergeSystemSettingsCache(settings);

        res.json({
            success: true,
            data: settings
        });
    } catch (e) {
        logger.error('Error fetching settings:', e);

        const cachedSettings = getCachedSettings();
        if (cachedSettings) {
            return res.json({
                success: true,
                data: cachedSettings
            });
        }

        // Fallback if table doesn't exist yet
        const defaultSettings = getDefaultSettings();
        setCachedSettings(defaultSettings);
        mergeSystemSettingsCache(defaultSettings);
        res.json({
            success: true,
            data: defaultSettings
        });
    }
}));

// Update system settings
router.put('/', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const settings = req.body;

    if (!settings || typeof settings !== 'object' || Array.isArray(settings)) {
        return res.status(400).json({
            success: false,
            message: 'Settings payload must be a JSON object'
        });
    }

    const sanitizedSettings = Object.fromEntries(
        Object.entries(settings).filter(([key]) => typeof key === 'string' && key.trim().length > 0)
    );

    const knownSettingsValidation = normalizeKnownSettings(sanitizedSettings);
    if (!knownSettingsValidation.isValid) {
        return res.status(400).json({
            success: false,
            message: 'Invalid system settings.',
            errors: knownSettingsValidation.errors
        });
    }

    Object.assign(sanitizedSettings, knownSettingsValidation.normalized);

    const updatesThresholdSettings = Object.keys(sanitizedSettings)
        .some((key) => ANOMALY_SCORING_THRESHOLD_KEYS.includes(key));

    if (updatesThresholdSettings) {
        const currentSettings = getCachedSettings() || getDefaultSettings();
        const validationTarget = {
            ...currentSettings,
            ...sanitizedSettings
        };
        const thresholdValidation = validateAnomalyScoringThresholds(validationTarget);

        if (!thresholdValidation.isValid) {
            return res.status(400).json({
                success: false,
                message: 'Invalid anomaly scoring thresholds.',
                errors: thresholdValidation.errors
            });
        }

        for (const key of ANOMALY_SCORING_THRESHOLD_KEYS) {
            if (Object.prototype.hasOwnProperty.call(sanitizedSettings, key)) {
                sanitizedSettings[key] = thresholdValidation.normalized[key];
            }
        }
    }

    if (Object.keys(sanitizedSettings).length > 0) {
        await query(`
            INSERT INTO system_settings (setting_key, setting_value, updated_at, updated_by)
            SELECT kv.key, kv.value, CURRENT_TIMESTAMP, $2
            FROM jsonb_each($1::jsonb) AS kv
            ON CONFLICT (setting_key) DO UPDATE
            SET setting_value = EXCLUDED.setting_value,
                updated_at = CURRENT_TIMESTAMP,
                updated_by = EXCLUDED.updated_by
        `, [JSON.stringify(sanitizedSettings), req.user.user_id]);
    }
    
    // Log the settings update
    const logId = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
    await query(`
        INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, $2, 'UPDATE', 'system_settings', $3, $4)
    `, [logId, req.user.user_id, JSON.stringify(sanitizedSettings), req.ip]);

    const currentSettings = getCachedSettings() || getDefaultSettings();
    setCachedSettings({
        ...currentSettings,
        ...sanitizedSettings
    });
    mergeSystemSettingsCache(sanitizedSettings);
    
    res.json({
        success: true,
        message: 'Settings updated successfully',
        data: sanitizedSettings
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
            (SELECT COUNT(*) FROM anomalies WHERE status IN ('open', 'pending') AND archived_at IS NULL AND COALESCE(removed_from_dashboard, false) = false) as pending_anomalies
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

// Get ML configuration — serves both /api/settings/config and /api/ml/config
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
    
    const logId = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
    await query(`
        INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, $2, 'UPDATE', 'ml_configuration', $3, $4)
    `, [logId, req.user.user_id, JSON.stringify(config), req.ip]);
    
    res.json({
        success: true,
        message: 'ML configuration updated successfully',
        data: config
    });
}));

// Trigger ML model training manually
router.post('/train', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const force = req.body?.force === true || req.query.force === 'true';
    const wait = req.body?.wait === undefined
        ? true
        : req.body.wait === true || req.query.wait === 'true';

    logger.info(`ML model training triggered by user: ${req.user.user_id} (force=${force}, wait=${wait})`);
    
    // Log the training initiation gracefully
    try {
        const logIdTraining = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
        await query(`
            INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address)
            VALUES ($1, $2, 'TRAIN', 'ml_model', $3, $4)
        `, [
            logIdTraining,
            req.user.user_id,
            JSON.stringify({ status: 'initiated', force, wait }),
            req.ip
        ]);
    } catch (logError) {
        logger.warn(`Failed to insert audit log for ML training: ${logError.message}`);
    }

    const result = await triggerManualTraining({ force, wait });

    if (result.status === 'failed') {
        return res.status(500).json({
            success: false,
            message: `ML model training failed: ${result.error || 'unknown error'}`,
            data: result
        });
    }

    if (result.status === 'skipped') {
        return res.json({
            success: true,
            message: `ML model training skipped: ${result.reason}`,
            data: result
        });
    }

    if (result.status === 'started' || result.status === 'running') {
        return res.json({
            success: true,
            message: 'ML model training started in background. Monitor /api/ml/ml-status for progress.',
            data: result
        });
    }

    res.json({
        success: true,
        message: 'ML model training completed successfully.',
        data: result
    });
}));

// Generate realistic custody-cycle training data batch
router.post('/generate-training-data', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const mode = req.body?.mode || req.query.mode || 'all';
    const extractFeatures = req.body?.extract_features === undefined
        ? true
        : req.body.extract_features === true || req.query.extract_features === 'true';
    const startDate = req.body?.start_date || req.query.start_date || null;

    logger.info(
        `Training data generation triggered by user: ${req.user.user_id} (mode=${mode}, extract_features=${extractFeatures}, start_date=${startDate || 'auto'})`
    );

    let result;
    try {
        result = await generateTrainingDataBatch({
            mode,
            extractFeatures,
            startDate
        });
    } catch (error) {
        if (error.message?.includes('Unsupported mode') || error.message?.includes('Invalid start_date')) {
            return res.status(400).json({
                success: false,
                message: error.message
            });
        }
        throw error;
    }

    const logIdGenerate = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
    await query(`
        INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, $2, 'GENERATE_TRAINING_DATA', 'custody_records', $3, $4)
    `, [
        logIdGenerate,
        req.user.user_id,
        JSON.stringify(result),
        req.ip
    ]);

    res.json({
        success: true,
        message: `Generated ${result.seeded_rows} realistic custody-cycle records in batch ${result.batch_code}.`,
        data: result
    });
}));

// Get ML model status
router.get('/ml-status', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    const minimumRequiredSamples = getMinTrainingSamples();

    // Get active model info
    const modelResult = await query(`
        SELECT 
            model_id,
            model_type,
            training_date,
            training_samples_count as training_samples,
            num_clusters,
            silhouette_score,
            outlier_threshold,
            is_active
        FROM ml_model_metadata
        WHERE is_active = true
        ORDER BY training_date DESC
        LIMIT 1
    `);
    
    const model = modelResult.rows[0] || null;
    
    // Get training feature counts. Training uses the full recent feature
    // window, while new_training_samples remains useful as a drift signal.
    const featuresResult = await query(`
        SELECT
            COUNT(*) as total_count,
            COUNT(*) FILTER (WHERE used_in_model_id IS NULL) as new_count
        FROM ml_training_features
        WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);
    
    const availableSamples = parseInt(featuresResult.rows[0].total_count);
    const newTrainingSamples = parseInt(featuresResult.rows[0].new_count);
    
    // Get recent anomaly stats
    const anomalyResult = await query(`
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE status = 'false_positive') as false_positives,
            COUNT(*) FILTER (WHERE status IN ('resolved', 'false_positive', 'acceptable_change')) as reviewed,
            COUNT(*) FILTER (WHERE status IN ('open', 'pending', 'investigating')) as pending_review
        FROM anomalies
        WHERE detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
    `);
    
    const anomalyStats = anomalyResult.rows[0];
    const totalDetections = parseInt(anomalyStats.total);
    const falsePositives = parseInt(anomalyStats.false_positives);
    const reviewedDetections = parseInt(anomalyStats.reviewed);
    const pendingReview = parseInt(anomalyStats.pending_review);
    const actualFalsePositiveRate = reviewedDetections > 0
        ? falsePositives / reviewedDetections
        : null;

    const falsePositiveRateLabel = reviewedDetections === 0
        ? 'Awaiting review'
        : (falsePositives === 0
            ? 'None confirmed'
            : `${(actualFalsePositiveRate * 100).toFixed(1)}%`);
    const latestTrainingRun = getLatestTrainingRun();

    const generationResult = await query(`
        SELECT user_id, created_at, new_values
        FROM audit_logs
        WHERE action_type = 'GENERATE_TRAINING_DATA'
        ORDER BY created_at DESC
        LIMIT 1
    `);

    const generationRow = generationResult.rows[0] || null;
    const generationPayload = generationRow?.new_values && typeof generationRow.new_values === 'object'
        ? generationRow.new_values
        : null;

    const lastGenerationRun = generationRow ? {
        generated_at: generationRow.created_at,
        generated_by: generationRow.user_id,
        batch_code: generationPayload?.batch_code || null,
        mode: generationPayload?.mode || null,
        seeded_rows: parseInt(generationPayload?.seeded_rows || 0),
        extracted_features: parseInt(generationPayload?.extracted_features || 0),
        available_training_samples: parseInt(generationPayload?.available_training_samples || 0),
        new_training_samples: parseInt(generationPayload?.new_training_samples || 0),
        can_train: generationPayload?.can_train === true
    } : null;
    
    res.json({
        success: true,
        data: {
            active_model: model ? {
                model_id: model.model_id,
                model_type: model.model_type,
                training_date: model.training_date,
                training_samples: model.training_samples,
                num_clusters: model.num_clusters,
                silhouette_score: parseFloat(model.silhouette_score) || 0,
                outlier_threshold: parseFloat(model.outlier_threshold) || 0
            } : null,
            available_training_samples: availableSamples,
            new_training_samples: newTrainingSamples,
            minimum_required_samples: minimumRequiredSamples,
            can_train: availableSamples >= minimumRequiredSamples,
            recent_detections: totalDetections,
            false_positive_rate: falsePositiveRateLabel,
            false_positive_rate_value: actualFalsePositiveRate,
            false_positive_rate_source: reviewedDetections === 0 ? 'awaiting_human_review' : 'reviewed_anomalies',
            false_positive_reviewed_count: reviewedDetections,
            false_positive_confirmed_count: falsePositives,
            pending_review_count: pendingReview,
            last_training_run: latestTrainingRun,
            last_generation_run: lastGenerationRun
        }
    });
}));

// Trigger overdue custody scan manually
router.post('/scan-overdue', authenticate, requireAdmin, asyncHandler(async (req, res) => {
    logger.info(`Overdue custody scan triggered by user: ${req.user.user_id}`);

    const logIdScan = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
    await query(`
        INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address)
        VALUES ($1, $2, 'SCAN', 'custody_records', '{"type": "overdue_scan"}', $3)
    `, [logIdScan, req.user.user_id, req.ip]);

    const result = await triggerManualOverdueScan();

    res.json({
        success: true,
        message: 'Overdue custody scan completed',
        data: result
    });
}));

module.exports = router;
