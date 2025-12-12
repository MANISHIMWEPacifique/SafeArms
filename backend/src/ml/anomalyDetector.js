const { query } = require('../config/database');
const { extractAllFeatures } = require('./featureExtractor');
const { predictKMeans } = require('./kmeans');
const { detectStatisticalOutliers } = require('./statistical');
const { calculateEnsembleScore } = require('./scorer');
const { sendAnomalyAlert } = require('../services/email.service');
const logger = require('../utils/logger');

/**
 * Main Anomaly Detector
 * Orchestrates feature extraction, ML prediction, and anomaly recording
 */

/**
 * Detect anomalies in a custody record
 * @param {Object} custodyRecord - Custody record from database
 * @returns {Promise<Object>} Detection result
 */
const detectAnomaly = async (custodyRecord) => {
    try {
        logger.info(`Running anomaly detection for custody: ${custodyRecord.custody_id}`);

        // Step 1: Extract features
        const features = await extractAllFeatures(custodyRecord);

        // Step 2: Get active ML model
        const modelResult = await query(`
      SELECT * FROM ml_model_metadata
      WHERE model_type = 'kmeans' AND is_active = true
      ORDER BY training_date DESC
      LIMIT 1
    `);

        if (modelResult.rows.length === 0) {
            logger.warn('No active ML model found. Skipping K-Means detection.');
            // Continue with statistical detection only
        }

        const model = modelResult.rows[0];

        // Step 3: Prepare feature vector for ML
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

        // Step 4: Run K-Means prediction
        let kmeansResult = null;
        if (model) {
            kmeansResult = predictKMeans(featureVector, model);
        }

        // Step 5: Run statistical outlier detection
        const statisticalResult = await detectStatisticalOutliers(features);

        // Step 6: Calculate ensemble score
        const ensembleResult = calculateEnsembleScore(kmeansResult, statisticalResult, features);

        // Step 7: If anomaly detected, create anomaly record
        if (ensembleResult.is_anomaly) {
            await recordAnomaly(custodyRecord, ensembleResult, model?.model_id);

            // Send alerts for high/critical anomalies
            if (ensembleResult.severity === 'high' || ensembleResult.severity === 'critical') {
                await sendAnomalyAlerts(custodyRecord, ensembleResult);
            }
        }

        logger.info(`Anomaly detection complete for custody: ${custodyRecord.custody_id}. Anomaly: ${ensembleResult.is_anomaly}, Score: ${ensembleResult.anomaly_score.toFixed(3)}`);

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
 * Record anomaly in database
 * @param {Object} custodyRecord
 * @param {Object} detection Result
 * @param {string} modelId
 * @returns {Promise<Object>}
 */
const recordAnomaly = async (custodyRecord, detectionResult, modelId) => {
    try {
        const result = await query(`
      INSERT INTO anomalies (
        custody_record_id, firearm_id, officer_id, unit_id,
        anomaly_score, anomaly_type, detection_method, model_id,
        severity, confidence_level, contributing_factors, feature_importance
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING anomaly_id
    `, [
            custodyRecord.custody_id,
            custodyRecord.firearm_id,
            custodyRecord.officer_id,
            custodyRecord.unit_id,
            detectionResult.anomaly_score,
            detectionResult.anomaly_type,
            'ensemble',
            modelId,
            detectionResult.severity,
            detectionResult.confidence,
            JSON.stringify(detectionResult.contributing_factors),
            JSON.stringify(detectionResult.feature_importance)
        ]);

        logger.info(`Anomaly recorded: ${result.rows[0].anomaly_id}`);

        return result.rows[0];
    } catch (error) {
        logger.error('Record anomaly error:', error);
        throw error;
    }
};

/**
 * Send anomaly alerts to relevant personnel
 * @param {Object} custodyRecord
 * @param {Object} detectionResult
 * @returns {Promise<void>}
 */
const sendAnomalyAlerts = async (custodyRecord, detectionResult) => {
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
                    {
                        anomaly_id: `A-${new Date().getFullYear()}-${custodyRecord.custody_id.substring(0, 8)}`,
                        severity: detectionResult.severity,
                        anomaly_score: detectionResult.anomaly_score,
                        firearm: details.firearm_desc,
                        officer: details.officer_name,
                        unit: details.unit_name
                    }
                );
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send alert to ${commander.email}:`, err);
            }
        }

        // Notify Station Commander
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
                    {
                        anomaly_id: `A-${new Date().getFullYear()}-${custodyRecord.custody_id.substring(0, 8)}`,
                        severity: detectionResult.severity,
                        anomaly_score: detectionResult.anomaly_score,
                        firearm: details.firearm_desc,
                        officer: details.officer_name,
                        unit: details.unit_name
                    }
                );
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send alert to station commander:`, err);
            }
        }

        // Update anomaly record with notification info
        await query(`
      UPDATE anomalies
      SET auto_notification_sent = true,
          notification_sent_at = CURRENT_TIMESTAMP,
          notified_users = $1
      WHERE custody_record_id = $2
    `, [JSON.stringify(notifiedUsers), custodyRecord.custody_id]);

        logger.info(`Anomaly alerts sent to ${notifiedUsers.length} users`);
    } catch (error) {
        logger.error('Send anomaly alerts error:', error);
        // Don't throw - alert failure shouldn't break detection
    }
};

/**
 * Get anomalies for a specific unit
 * @param {string} unitId
 * @param {Object} filters
 * @returns {Promise<Array>}
 */
const getUnitAnomalies = async (unitId, filters = {}) => {
    try {
        const { severity, status, limit = 50, offset = 0 } = filters;

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

        return result.rows;
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
        const { severity, status, unit_id, limit = 100, offset = 0 } = filters;

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

        return result.rows;
    } catch (error) {
        logger.error('Get all anomalies error:', error);
        throw error;
    }
};

module.exports = {
    detectAnomaly,
    recordAnomaly,
    getUnitAnomalies,
    getAllAnomalies
};
