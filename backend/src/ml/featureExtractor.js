const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * ML Feature Extractor
 * Extracts features from custody records for anomaly detection
 */

/**
 * Extract temporal features from custody record
 * @param {Object} custodyRecord
 * @returns {Object} Temporal features
 */
const extractTemporalFeatures = (custodyRecord) => {
    const issuedAt = new Date(custodyRecord.issued_at);

    return {
        issue_hour: custodyRecord.issue_hour,
        issue_day_of_week: custodyRecord.issue_day_of_week,
        is_night_issue: custodyRecord.is_night_issue,
        is_weekend_issue: custodyRecord.is_weekend_issue,
        timestamp: issuedAt.getTime()
    };
};

/**
 * Extract behavioral features from historical data
 * @param {string} officerId
 * @param {string} firearmId
 * @returns {Promise<Object>}
 */
const extractBehavioralFeatures = async (officerId, firearmId) => {
    try {
        // Officer's recent activity (last 30 days)
        const officerStats = await query(
            `SELECT 
        COUNT(*) as issue_count_30d,
        AVG(custody_duration_seconds) as avg_duration_30d,
        STDDEV(custody_duration_seconds) as stddev_duration_30d
       FROM custody_records
       WHERE officer_id = $1 
       AND issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'`,
            [officerId]
        );

        // Firearm's recent exchange rate (last 7 days)
        const firearmStats = await query(
            `SELECT 
        COUNT(*) as exchange_count_7d,
        COUNT(DISTINCT officer_id) as unique_officers_7d
       FROM custody_records
       WHERE firearm_id = $1 
       AND issued_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'`,
            [firearmId]
        );

        // Officer's consecutive same firearm count
        const consecutiveCount = await query(
            `SELECT COUNT(*) as consecutive_same_firearm
       FROM custody_records
       WHERE officer_id = $1 AND firearm_id = $2`,
            [officerId, firearmId]
        );

        const officerData = officerStats.rows[0] || {};
        const firearmData = firearmStats.rows[0] || {};
        const consecutiveData = consecutiveCount.rows[0] || {};

        return {
            officer_issue_frequency_30d: parseFloat(officerData.issue_count_30d || 0) / 30,
            officer_avg_custody_duration_30d: parseFloat(officerData.avg_duration_30d || 0),
            firearm_exchange_rate_7d: parseFloat(firearmData.exchange_count_7d || 0) / 7,
            consecutive_same_firearm_count: parseInt(consecutiveData.consecutive_same_firearm || 0)
        };
    } catch (error) {
        logger.error('Extract behavioral features error:', error);
        return {
            officer_issue_frequency_30d: 0,
            officer_avg_custody_duration_30d: 0,
            firearm_exchange_rate_7d: 0,
            consecutive_same_firearm_count: 0
        };
    }
};

/**
 * Detect pattern-based anomaly flags
 * @param {Object} custodyRecord
 * @returns {Promise<Object>}
 */
const extractPatternFlags = async (custodyRecord) => {
    try {
        const { firearm_id, officer_id, unit_id } = custodyRecord;

        // Check for rapid exchange (firearm returned and reissued within 1 hour)
        const rapidExchange = await query(
            `SELECT COUNT(*) as count
       FROM custody_records
       WHERE firearm_id = $1
       AND returned_at IS NOT NULL
       AND returned_at >= CURRENT_TIMESTAMP - INTERVAL '1 hour'`,
            [firearm_id]
        );

        // Check for cross-unit movement
        const crossUnit = await query(
            `SELECT COUNT(*) as count
       FROM custody_records cr
       JOIN officers o ON cr.officer_id = o.officer_id
       WHERE cr.officer_id = $1
       AND o.unit_id != $2`,
            [officer_id, unit_id]
        );

        // Time since last return for this firearm
        const lastReturn = await query(
            `SELECT returned_at
       FROM custody_records
       WHERE firearm_id = $1 AND returned_at IS NOT NULL
       ORDER BY returned_at DESC
       LIMIT 1`,
            [firearm_id]
        );

        let timeSinceLastReturn = null;
        if (lastReturn.rows.length > 0) {
            const lastReturnTime = new Date(lastReturn.rows[0].returned_at);
            const now = new Date();
            timeSinceLastReturn = (now - lastReturnTime) / 1000; // seconds
        }

        return {
            rapid_exchange_flag: parseInt(rapidExchange.rows[0]?.count || 0) > 0,
            cross_unit_movement_flag: parseInt(crossUnit.rows[0]?.count || 0) > 0,
            time_since_last_return_seconds: timeSinceLastReturn
        };
    } catch (error) {
        logger.error('Extract pattern flags error:', error);
        return {
            rapid_exchange_flag: false,
            cross_unit_movement_flag: false,
            time_since_last_return_seconds: null
        };
    }
};

/**
 * Calculate statistical features (z-scores)
 * @param {Object} custodyRecord
 * @param {Object} behavioralFeatures
 * @returns {Promise<Object>}
 */
const extractStatisticalFeatures = async (custodyRecord, behavioralFeatures) => {
    try {
        // Get population statistics for custody duration
        const durationStats = await query(
            `SELECT 
        AVG(custody_duration_seconds) as mean,
        STDDEV(custody_duration_seconds) as stddev
       FROM custody_records
       WHERE custody_duration_seconds IS NOT NULL`
        );

        // Get population statistics for issue frequency
        const frequencyStats = await query(
            `SELECT 
        AVG(issue_frequency) as mean,
        STDDEV(issue_frequency) as stddev
       FROM (
         SELECT officer_id, COUNT(*)::DECIMAL / 30 as issue_frequency
         FROM custody_records
         WHERE issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
         GROUP BY officer_id
       ) freq_table`
        );

        const durationData = durationStats.rows[0] || {};
        const frequencyData = frequencyStats.rows[0] || {};

        // Calculate z-scores
        const durationMean = parseFloat(durationData.mean || 0);
        const durationStddev = parseFloat(durationData.stddev || 1);
        const frequencyMean = parseFloat(frequencyData.mean || 0);
        const frequencyStddev = parseFloat(frequencyData.stddev || 1);

        // For new custody (not yet returned), estimate duration as expected duration
        const estimatedDuration = behavioralFeatures.officer_avg_custody_duration_30d || durationMean;

        const custodyDurationZScore = durationStddev > 0
            ? (estimatedDuration - durationMean) / durationStddev
            : 0;

        const issueFrequencyZScore = frequencyStddev > 0
            ? (behavioralFeatures.officer_issue_frequency_30d - frequencyMean) / frequencyStddev
            : 0;

        return {
            custody_duration_zscore: custodyDurationZScore,
            issue_frequency_zscore: issueFrequencyZScore
        };
    } catch (error) {
        logger.error('Extract statistical features error:', error);
        return {
            custody_duration_zscore: 0,
            issue_frequency_zscore: 0
        };
    }
};

/**
 * Extract all features from a custody record
 * @param {Object} custodyRecord
 * @returns {Promise<Object>} Complete feature set
 */
const extractAllFeatures = async (custodyRecord) => {
    try {
        const { officer_id, firearm_id, custody_id } = custodyRecord;

        // Extract all feature types
        const temporal = extractTemporalFeatures(custodyRecord);
        const behavioral = await extractBehavioralFeatures(officer_id, firearm_id);
        const patternFlags = await extractPatternFlags(custodyRecord);
        const statistical = await extractStatisticalFeatures(custodyRecord, behavioral);

        // Combine all features
        const features = {
            custody_id,
            ...temporal,
            ...behavioral,
            ...patternFlags,
            ...statistical,
            extracted_at: new Date()
        };

        logger.info(`Features extracted for custody: ${custody_id}`);

        // Store features in database for model training
        await storeFeatures(custodyRecord, features);

        return features;
    } catch (error) {
        logger.error('Extract all features error:', error);
        throw error;
    }
};

/**
 * Store extracted features in ml_training_features table
 * @param {Object} custodyRecord
 * @param {Object} features
 * @returns {Promise<void>}
 */
const storeFeatures = async (custodyRecord, features) => {
    try {
        await query(
            `INSERT INTO ml_training_features (
        officer_id, firearm_id, unit_id, custody_record_id,
        custody_duration_seconds, issue_hour, issue_day_of_week,
        is_night_issue, is_weekend_issue,
        officer_issue_frequency_30d, officer_avg_custody_duration_30d,
        firearm_exchange_rate_7d, officer_unit_consistency_score,
        time_since_last_return_seconds, consecutive_same_firearm_count,
        cross_unit_movement_flag, rapid_exchange_flag,
        custody_duration_zscore, issue_frequency_zscore
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)`,
            [
                custodyRecord.officer_id,
                custodyRecord.firearm_id,
                custodyRecord.unit_id,
                custodyRecord.custody_id,
                custodyRecord.custody_duration_seconds || 0,
                features.issue_hour,
                features.issue_day_of_week,
                features.is_night_issue,
                features.is_weekend_issue,
                features.officer_issue_frequency_30d,
                features.officer_avg_custody_duration_30d,
                features.firearm_exchange_rate_7d,
                1.0, // unit_consistency_score (placeholder)
                features.time_since_last_return_seconds,
                features.consecutive_same_firearm_count,
                features.cross_unit_movement_flag,
                features.rapid_exchange_flag,
                features.custody_duration_zscore,
                features.issue_frequency_zscore
            ]
        );
    } catch (error) {
        logger.error('Store features error:', error);
        // Don't throw - feature storage failure shouldn't break custody operations
    }
};

module.exports = {
    extractAllFeatures,
    extractTemporalFeatures,
    extractBehavioralFeatures,
    extractPatternFlags,
    extractStatisticalFeatures
};
