const { query } = require('../config/database');
const { extractAllFeatures } = require('./featureExtractor');
const { predictKMeans } = require('./kmeans');
const { detectStatisticalOutliers } = require('./statistical');
const {
    calculateEnsembleScore,
    DEFAULT_SCORING_THRESHOLDS,
    normalizeScoringThresholds
} = require('./scorer');
const { evaluateRules } = require('./rulesEngine');
const { sendAnomalyAlert } = require('../services/email.service');
const { getSystemSettings } = require('../services/systemSettings.service');
const logger = require('../utils/logger');
const { parseDecimalFields } = require('../utils/helpers');

const ANOMALY_DECIMAL_FIELDS = ['anomaly_score', 'confidence_level'];
const SCORING_THRESHOLD_SETTING_KEYS = [
    'anomaly_trigger_threshold',
    'anomaly_medium_threshold',
    'anomaly_high_threshold',
    'anomaly_critical_threshold',
    'anomaly_critical_min_confidence'
];

const toOptionalNumber = (value) => {
    if (value === undefined || value === null) {
        return null;
    }

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

const loadScoringThresholds = async () => {
    try {
        const settings = await getSystemSettings(SCORING_THRESHOLD_SETTING_KEYS);

        return normalizeScoringThresholds({
            anomaly_trigger_threshold:
                toOptionalNumber(settings.anomaly_trigger_threshold) ??
                DEFAULT_SCORING_THRESHOLDS.anomaly_trigger_threshold,
            anomaly_medium_threshold:
                toOptionalNumber(settings.anomaly_medium_threshold) ??
                DEFAULT_SCORING_THRESHOLDS.anomaly_medium_threshold,
            anomaly_high_threshold:
                toOptionalNumber(settings.anomaly_high_threshold) ??
                DEFAULT_SCORING_THRESHOLDS.anomaly_high_threshold,
            anomaly_critical_threshold:
                toOptionalNumber(settings.anomaly_critical_threshold) ??
                DEFAULT_SCORING_THRESHOLDS.anomaly_critical_threshold,
            anomaly_critical_min_confidence:
                toOptionalNumber(settings.anomaly_critical_min_confidence) ??
                DEFAULT_SCORING_THRESHOLDS.anomaly_critical_min_confidence
        });
    } catch (error) {
        logger.warn(`Unable to load anomaly scoring thresholds from system settings: ${error.message}`);
        return DEFAULT_SCORING_THRESHOLDS;
    }
};

/**
 * Main Anomaly Detector - EVENT-BASED Detection System
 * 
 * IMPORTANT PRINCIPLES:
 * 1. This system evaluates EVENTS, not people
 * 2. Anomalies represent patterns requiring human review
 * 3. Severity indicates REVIEW URGENCY, not wrongdoing
 * 4. Cross-unit transfers contribute to anomaly score but are not mandatory
 * 5. Ballistic access timing relative to custody is a key feature
 * 6. The system is unsupervised - no labeled training data required
 * 
 * SEVERITY LEVELS (Review Urgency):
 * - critical: Immediate review required (same day)
 * - high: Review within 24 hours
 * - medium: Review within 72 hours
 * - low: Standard review queue
 */

/**
 * Detect anomalies in a custody event
 * @param {Object} custodyRecord - Custody record from database
 * @returns {Promise<Object>} Detection result
 */
const detectAnomaly = async (custodyRecord) => {
    try {
        logger.info(`Running EVENT-BASED anomaly detection for custody: ${custodyRecord.custody_id}`);

        // Step 1: Extract features (feeds both rules context and K-Means)
        const features = await extractAllFeatures(custodyRecord);

        // Step 2: Run rules engine (ALWAYS active — no model required)
        const rulesResult = await evaluateRules(custodyRecord, features);

        // Step 3: Get active ML model (optional — only contributes when trained)
        const modelResult = await query(`
      SELECT * FROM ml_model_metadata
      WHERE model_type = 'kmeans' AND is_active = true
      ORDER BY training_date DESC
      LIMIT 1
    `);

        const model = modelResult.rows[0] || null;
        const hasModel = model !== null;

        if (!hasModel) {
            logger.info('No active ML model. Using rules + statistical detection only.');
        }

        // Step 4: Prepare feature vector and run K-Means (only when model exists)
        let kmeansResult = null;
        if (hasModel) {
            const featureVector = [
                features.officer_issue_frequency_30d || 0,
                features.officer_avg_custody_duration_30d || 0,
                features.firearm_exchange_rate_7d || 0,
                (features.issue_hour || 0) / 24.0,
                features.is_night_issue ? 1.0 : 0.0,
                features.is_weekend_issue ? 1.0 : 0.0,
                features.rapid_exchange_flag ? 1.0 : 0.0,
                features.cross_unit_movement_flag ? 1.0 : 0.0,
                features.custody_duration_zscore || 0,
                features.issue_frequency_zscore || 0
            ];
            kmeansResult = predictKMeans(featureVector, model);
        }

        // Step 5: Run statistical outlier detection
        const statisticalResult = await detectStatisticalOutliers(features);

        // Step 6: Load scoring thresholds from system settings (cached)
        const scoringThresholds = await loadScoringThresholds();

        // Step 7: Calculate ensemble score (adaptive weights based on model availability)
        const ensembleResult = calculateEnsembleScore(
            kmeansResult,
            statisticalResult,
            features,
            rulesResult,
            hasModel,
            { thresholds: scoringThresholds }
        );

        // Step 8: If anomaly detected, create anomaly record
        if (ensembleResult.is_anomaly) {
            const anomalyRecord = await recordAnomaly(custodyRecord, features, ensembleResult, model?.model_id);

            // Send alerts for high/critical anomalies
            if (ensembleResult.severity === 'high' || ensembleResult.severity === 'critical') {
                await sendAnomalyAlerts(custodyRecord, ensembleResult, anomalyRecord);
            }
        }

        logger.info(`EVENT anomaly detection complete for custody: ${custodyRecord.custody_id}. ` +
            `Anomaly: ${ensembleResult.is_anomaly}, Score: ${ensembleResult.anomaly_score.toFixed(3)}, ` +
            `Mode: ${ensembleResult.weighting_mode}, Rules: ${rulesResult.rule_count}, Severity: ${ensembleResult.severity}`);

        return ensembleResult;
    } catch (error) {
        logger.error('Anomaly detection error:', error);
        // Don't throw - detection failure shouldn't break custody operations
        return {
            is_anomaly: false,
            anomaly_score: 0,
            error: error.message
        };
    }
};

/**
 * Record anomaly in database (EVENT-CENTRIC)
 * @param {Object} custodyRecord
 * @param {Object} features - Extracted features including event_context
 * @param {Object} detectionResult
 * @param {string} modelId
 * @returns {Promise<Object>}
 */
const recordAnomaly = async (custodyRecord, features, detectionResult, modelId) => {
    try {
        // Generate anomaly_id
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(anomaly_id FROM 6) AS INTEGER)), 0) as max_num FROM anomalies WHERE anomaly_id ~ '^ANOM-[0-9]+$'`);
        const nextNum = parseInt(idResult.rows[0].max_num) + 1;
        const anomaly_id = `ANOM-${String(nextNum).padStart(3, '0')}`;

        // Build dynamic detection_method from which detectors contributed
        const methods = [];
        if (detectionResult.rules_triggered?.length > 0) methods.push('rules');
        if (detectionResult.detection_methods?.kmeans?.is_anomaly) methods.push('kmeans');
        if (detectionResult.detection_methods?.statistical?.is_anomaly) methods.push('statistical');
        if ((detectionResult.detection_methods?.ballistic_timing?.score || 0) > 0.5) methods.push('ballistic');
        const detectionMethod = methods.length > 0 ? methods.join('+') : 'ensemble';

        const result = await query(`
      INSERT INTO anomalies (
        anomaly_id, custody_record_id, firearm_id, officer_id, unit_id,
        anomaly_score, anomaly_type, detection_method, model_id,
        severity, confidence_level, contributing_factors, feature_importance,
        is_mandatory_review, event_context, ballistic_access_context
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING anomaly_id
    `, [
            anomaly_id,
            custodyRecord.custody_id,
            custodyRecord.firearm_id,
            custodyRecord.officer_id,
            custodyRecord.unit_id,
            detectionResult.anomaly_score,
            detectionResult.anomaly_type,
            detectionMethod,
            modelId,
            detectionResult.severity,
            detectionResult.confidence,
            JSON.stringify(detectionResult.contributing_factors),
            JSON.stringify(detectionResult.feature_importance),
            detectionResult.is_mandatory_review || false,
            JSON.stringify(features.event_context || detectionResult.event_context),
            JSON.stringify(detectionResult.ballistic_access_context)
        ]);

        const anomalyId = result.rows[0].anomaly_id;
        logger.info(`EVENT anomaly recorded: ${anomalyId} (type: ${detectionResult.anomaly_type}, severity: ${detectionResult.severity})`);

        return { anomaly_id: anomalyId, ...result.rows[0] };
    } catch (error) {
        logger.error('Record anomaly error:', error);
        throw error;
    }
};

/**
 * Send anomaly alerts to relevant personnel
 * Includes event context and ballistic access information
 * @param {Object} custodyRecord
 * @param {Object} detectionResult
 * @param {Object} anomalyRecord - The created anomaly record
 * @returns {Promise<void>}
 */
const sendAnomalyAlerts = async (custodyRecord, detectionResult, anomalyRecord) => {
    try {
        const notifiedUsers = [];

        // Get firearm, officer, and unit details for alert
        const detailsResult = await query(`
      SELECT 
        f.serial_number || ' ' || f.manufacturer || ' ' || f.model as firearm_desc,
        o.full_name as officer_name,
        u.unit_name
      FROM custody_records cr
      JOIN firearms f ON cr.firearm_id = f.firearm_id
      JOIN officers o ON cr.officer_id = o.officer_id
      JOIN units u ON cr.unit_id = u.unit_id
      WHERE cr.custody_id = $1
    `, [custodyRecord.custody_id]);

        if (detailsResult.rows.length === 0) return;

        const details = detailsResult.rows[0];
        
        // Build alert context
        const alertContext = {
            anomaly_id: anomalyRecord?.anomaly_id || `A-${new Date().getFullYear()}-${custodyRecord.custody_id.substring(0, 8)}`,
            severity: detectionResult.severity,
            severity_description: getSeverityDescription(detectionResult.severity),
            anomaly_score: detectionResult.anomaly_score,
            anomaly_type: detectionResult.anomaly_type,
            is_mandatory_review: detectionResult.is_mandatory_review,
            firearm: details.firearm_desc,
            officer: details.officer_name,
            unit: details.unit_name,
            // New: Include event context
            is_cross_unit_transfer: detectionResult.event_context?.is_cross_unit_transfer || false,
            previous_unit: detectionResult.event_context?.previous_unit_name || null,
            ballistic_timing_concern: (detectionResult.ballistic_access_context?.timing_score || 0) > 0.5,
            contributing_factors: Object.values(detectionResult.contributing_factors || {}).slice(0, 3)
        };

        // Always notify HQ Commanders for HIGH/CRITICAL
        const hqCommanders = await query(`
      SELECT user_id, email, full_name 
      FROM users
      WHERE role = 'hq_firearm_commander' AND is_active = true
    `);

        for (const commander of hqCommanders.rows) {
            try {
                await sendAnomalyAlert(
                    commander.email,
                    commander.full_name,
                    alertContext
                );
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send alert to ${commander.email}:`, err);
            }
        }

        // Notify Station Commander (for their unit's events)
        const stationCommander = await query(`
      SELECT user_id, email, full_name
      FROM users
      WHERE role = 'station_commander' AND unit_id = $1 AND is_active = true
    `, [custodyRecord.unit_id]);

        if (stationCommander.rows.length > 0) {
            const commander = stationCommander.rows[0];
            try {
                await sendAnomalyAlert(
                    commander.email,
                    commander.full_name,
                    alertContext
                );
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send alert to station commander:`, err);
            }
        }

        // Update anomaly record with notification info
        if (anomalyRecord?.anomaly_id) {
            await query(`
                UPDATE anomalies
                SET auto_notification_sent = true,
                    notification_sent_at = CURRENT_TIMESTAMP,
                    notified_users = $1
                WHERE anomaly_id = $2
            `, [JSON.stringify(notifiedUsers), anomalyRecord.anomaly_id]);
        }

        logger.info(`EVENT anomaly alerts sent to ${notifiedUsers.length} users for anomaly ${anomalyRecord?.anomaly_id}`);
    } catch (error) {
        logger.error('Send anomaly alerts error:', error);
        // Don't throw - alert failure shouldn't break detection
    }
};

/**
 * Get human-readable severity description
 * IMPORTANT: Severity is about REVIEW URGENCY, not wrongdoing
 * @param {string} severity
 * @returns {string}
 */
const getSeverityDescription = (severity) => {
    const descriptions = {
        critical: 'Immediate review required (same day)',
        high: 'Review within 24 hours',
        medium: 'Review within 72 hours',
        low: 'Standard review queue'
    };
    return descriptions[severity] || 'Standard review';
};

/**
 * Get anomalies for a specific unit
 * @param {string} unitId
 * @param {Object} filters
 * @returns {Promise<Array>}
 */
const getUnitAnomalies = async (unitId, filters = {}) => {
    try {
        const {
            severity,
            status,
            firearm_id,
            include_removed,
            limit = 50,
            offset = 0
        } = filters;
        const includeRemoved = include_removed === true || include_removed === 'true';

        let whereClause = 'WHERE a.unit_id = $1';
        let params = [unitId];
        let paramCount = 1;

        if (severity) {
            paramCount++;
            whereClause += ` AND a.severity = $${paramCount}`;
            params.push(severity);
        }

        if (status) {
            paramCount++;
            whereClause += ` AND a.status = $${paramCount}`;
            params.push(status);
        }

        if (firearm_id) {
            paramCount++;
            whereClause += ` AND a.firearm_id = $${paramCount}`;
            params.push(firearm_id);
        }

        if (!includeRemoved) {
            whereClause += ` AND COALESCE(a.removed_from_dashboard, false) = false`;
        }

        paramCount++;
        params.push(limit);
        const limitParam = `$${paramCount}`;

        paramCount++;
        params.push(offset);
        const offsetParam = `$${paramCount}`;

        const result = await query(`
      SELECT 
        a.*,
        f.serial_number,
        f.manufacturer,
        f.model,
        o.full_name as officer_name,
        o.rank,
        u.unit_name,
        cr.issued_at
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      JOIN custody_records cr ON a.custody_record_id = cr.custody_id
      ${whereClause}
      ORDER BY a.detected_at DESC
      LIMIT ${limitParam} OFFSET ${offsetParam}
    `, params);

        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    } catch (error) {
        logger.error('Get unit anomalies error:', error);
        throw error;
    }
};

/**
 * Get all anomalies (HQ view)
 * @param {Object} filters
 * @returns {Promise<Array>}
 */
const getAllAnomalies = async (filters = {}) => {
    try {
        const {
            severity,
            status,
            unit_id,
            firearm_id,
            include_removed,
            limit = 100,
            offset = 0
        } = filters;
        const includeRemoved = include_removed === true || include_removed === 'true';

        let whereClause = 'WHERE 1=1';
        let params = [];
        let paramCount = 0;

        if (severity) {
            paramCount++;
            whereClause += ` AND a.severity = $${paramCount}`;
            params.push(severity);
        }

        if (status) {
            paramCount++;
            whereClause += ` AND a.status = $${paramCount}`;
            params.push(status);
        }

        if (unit_id) {
            paramCount++;
            whereClause += ` AND a.unit_id = $${paramCount}`;
            params.push(unit_id);
        }

        if (firearm_id) {
            paramCount++;
            whereClause += ` AND a.firearm_id = $${paramCount}`;
            params.push(firearm_id);
        }

        if (!includeRemoved) {
            whereClause += ` AND COALESCE(a.removed_from_dashboard, false) = false`;
        }

        paramCount++;
        params.push(limit);
        const limitParam = `$${paramCount}`;

        paramCount++;
        params.push(offset);
        const offsetParam = `$${paramCount}`;

        const result = await query(`
      SELECT 
        a.*,
        f.serial_number,
        f.manufacturer,
        f.model,
        o.full_name as officer_name,
        o.rank,
        u.unit_name,
        cr.issued_at
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      JOIN custody_records cr ON a.custody_record_id = cr.custody_id
      ${whereClause}
      ORDER BY a.detected_at DESC
      LIMIT ${limitParam} OFFSET ${offsetParam}
    `, params);

        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    } catch (error) {
        logger.error('Get all anomalies error:', error);
        throw error;
    }
};

/**
 * Record an overdue custody anomaly
 * Called by the overdue detection cron job when a custody record is past its expected return date
 *
 * @param {Object} overdueRecord - Overdue custody record with joined details
 * @param {number} hoursOverdue - How many hours past the expected return
 * @param {string} severity - Calculated severity (low/medium/high/critical)
 * @returns {Promise<Object>} Created anomaly record
 */
const recordOverdueAnomaly = async (overdueRecord, hoursOverdue, severity) => {
    try {
        const { calculateOverdueScore } = require('../jobs/overdueDetection.job');
        const anomalyScore = calculateOverdueScore(hoursOverdue);
        const daysOverdue = Math.floor(hoursOverdue / 24);
        const remainingHours = Math.floor(hoursOverdue % 24);

        // Generate anomaly_id
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(anomaly_id FROM 6) AS INTEGER)), 0) as max_num FROM anomalies WHERE anomaly_id ~ '^ANOM-[0-9]+$'`);
        const nextNum = parseInt(idResult.rows[0].max_num) + 1;
        const anomaly_id = `ANOM-${String(nextNum).padStart(3, '0')}`;

        // Build contributing factors
        const contributingFactors = {
            overdue_duration: `Firearm not returned for ${daysOverdue} day(s) and ${remainingHours} hour(s) past expected return`,
            expected_return: `Expected return: ${new Date(overdueRecord.expected_return_date).toISOString()}`,
            issued_at: `Originally issued: ${new Date(overdueRecord.issued_at).toISOString()}`
        };

        if (overdueRecord.duration_type) {
            contributingFactors.shift_type = `Assigned shift type: ${overdueRecord.duration_type.replace('_', ' ')}`;
        }

        if (daysOverdue >= 7) {
            contributingFactors.critical_warning = 'Firearm has been overdue for more than 7 days - immediate action required';
        }

        // Build feature importance
        const featureImportance = {
            overdue_hours: Math.min(hoursOverdue / 336, 1.0), // Normalize to 14 days max
            custody_duration: 0.9,
            expected_return_breach: 1.0
        };

        // Build event context
        const eventContext = {
            event_type: 'overdue_return',
            event_id: overdueRecord.custody_id,
            firearm_id: overdueRecord.firearm_id,
            officer_id: overdueRecord.officer_id,
            unit_id: overdueRecord.unit_id,
            hours_overdue: hoursOverdue,
            days_overdue: daysOverdue,
            expected_return_date: overdueRecord.expected_return_date,
            issued_at: overdueRecord.issued_at,
            custody_type: overdueRecord.custody_type,
            duration_type: overdueRecord.duration_type
        };

        // Determine specific anomaly type
        let anomalyType = 'overdue_return';
        if (hoursOverdue >= 168) {
            anomalyType = 'overdue_return_critical';
        } else if (hoursOverdue >= 72) {
            anomalyType = 'overdue_return_extended';
        }

        const result = await query(`
            INSERT INTO anomalies (
                anomaly_id, custody_record_id, firearm_id, officer_id, unit_id,
                anomaly_score, anomaly_type, detection_method, model_id,
                severity, confidence_level, contributing_factors, feature_importance,
                is_mandatory_review, event_context, ballistic_access_context
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING anomaly_id
        `, [
            anomaly_id,
            overdueRecord.custody_id,
            overdueRecord.firearm_id,
            overdueRecord.officer_id,
            overdueRecord.unit_id,
            anomalyScore,
            anomalyType,
            'overdue_scanner',
            null, // No ML model used - this is rule-based
            severity,
            0.95, // High confidence since this is deterministic (date comparison)
            JSON.stringify(contributingFactors),
            JSON.stringify(featureImportance),
            severity === 'high' || severity === 'critical', // Mandatory review for high/critical
            JSON.stringify(eventContext),
            JSON.stringify(null) // No ballistic context for overdue
        ]);

        logger.info(`OVERDUE anomaly recorded: ${anomaly_id} (custody: ${overdueRecord.custody_id}, ${daysOverdue}d ${remainingHours}h overdue, severity: ${severity})`);

        return { anomaly_id: result.rows[0].anomaly_id };
    } catch (error) {
        logger.error('Record overdue anomaly error:', error);
        throw error;
    }
};

module.exports = {
    detectAnomaly,
    recordAnomaly,
    recordOverdueAnomaly,
    getUnitAnomalies,
    getAllAnomalies
};
