const logger = require('../utils/logger');

/**
 * Statistical Outlier Detection for EVENT-Based Anomaly Detection
 * 
 * Uses z-score analysis to identify anomalous custody EVENT patterns.
 * 
 * IMPORTANT: This evaluates EVENTS, not people.
 * Outliers indicate patterns that warrant human review.
 */

/**
 * Calculate z-score for a value
 * @param {number} value
 * @param {number} mean
 * @param {number} stddev
 * @returns {number}
 */
const calculateZScore = (value, mean, stddev) => {
    if (stddev === 0) return 0;
    return (value - mean) / stddev;
};

/**
 * Detect statistical outliers in features
 * Includes chain-of-custody and ballistic access timing analysis
 * @param {Object} features - Extracted features
 * @returns {Promise<Object>} Outlier detection results
 */
const detectStatisticalOutliers = async (features) => {
    try {
        const outliers = [];
        let maxZScore = 0;

        // Check custody duration outlier
        const durationZScore = Math.abs(features.custody_duration_zscore || 0);
        if (durationZScore > 2.5) {
            outliers.push({
                feature: 'custody_duration',
                zscore: features.custody_duration_zscore,
                severity: durationZScore > 3.0 ? 'high' : 'medium',
                description: durationZScore > 0
                    ? 'Unusually long custody duration'
                    : 'Unusually short custody duration'
            });
            maxZScore = Math.max(maxZScore, durationZScore);
        }

        // Check issue frequency outlier
        const frequencyZScore = Math.abs(features.issue_frequency_zscore || 0);
        if (frequencyZScore > 2.5) {
            outliers.push({
                feature: 'issue_frequency',
                zscore: features.issue_frequency_zscore,
                severity: frequencyZScore > 3.0 ? 'high' : 'medium',
                description: frequencyZScore > 0
                    ? 'Officer receives firearms unusually frequently'
                    : 'Officer receives firearms unusually infrequently'
            });
            maxZScore = Math.max(maxZScore, frequencyZScore);
        }

        // Check firearm exchange rate
        const exchangeRate = features.firearm_exchange_rate_7d || 0;
        if (exchangeRate > 1.0) { // More than 1 exchange per day
            outliers.push({
                feature: 'firearm_exchange_rate',
                value: exchangeRate,
                severity: exchangeRate > 2.0 ? 'high' : 'medium',
                description: `Firearm exchanged ${exchangeRate.toFixed(1)} times per day`
            });
            maxZScore = Math.max(maxZScore, exchangeRate);
        }

        // ============================================
        // NEW: Ballistic access timing outliers
        // ============================================
        
        // High ballistic access frequency
        const ballisticAccesses24h = features.ballistic_accesses_24h || 0;
        if (ballisticAccesses24h > 3) {
            outliers.push({
                feature: 'ballistic_access_frequency',
                value: ballisticAccesses24h,
                severity: ballisticAccesses24h > 5 ? 'high' : 'medium',
                description: `Ballistic profile accessed ${ballisticAccesses24h} times in 24 hours`
            });
            maxZScore = Math.max(maxZScore, ballisticAccesses24h / 3.0);
        }

        // Ballistic access close to custody change
        const accessBeforeHours = features.ballistic_access_before_custody_hours;
        if (accessBeforeHours !== null && accessBeforeHours < 6) {
            const proximityScore = (6 - accessBeforeHours) / 6.0 * 3.0; // Convert to pseudo-zscore
            outliers.push({
                feature: 'ballistic_access_before_custody',
                value: accessBeforeHours,
                severity: accessBeforeHours < 2 ? 'high' : 'medium',
                description: `Ballistic profile accessed ${accessBeforeHours.toFixed(1)} hours before custody transfer`
            });
            maxZScore = Math.max(maxZScore, proximityScore);
        }

        const accessAfterHours = features.ballistic_access_after_custody_hours;
        if (accessAfterHours !== null && accessAfterHours < 6) {
            const proximityScore = (6 - accessAfterHours) / 6.0 * 3.0;
            outliers.push({
                feature: 'ballistic_access_after_custody',
                value: accessAfterHours,
                severity: accessAfterHours < 2 ? 'high' : 'medium',
                description: `Ballistic profile accessed ${accessAfterHours.toFixed(1)} hours after custody transfer`
            });
            maxZScore = Math.max(maxZScore, proximityScore);
        }

        // Calculate statistical anomaly score (0 to 1)
        // Produce a small baseline score from z-score magnitudes even when no outlier threshold is breached
        let statisticalScore;
        if (outliers.length > 0) {
            statisticalScore = Math.min(maxZScore / 4.0, 1.0);
        } else {
            const durationZ = Math.abs(features.custody_duration_zscore || 0);
            const frequencyZ = Math.abs(features.issue_frequency_zscore || 0);
            const peakZ = Math.max(durationZ, frequencyZ);
            // Proportional baseline: z=1.0 → ~0.025, z=2.0 → ~0.035
            statisticalScore = peakZ > 0 ? Math.min(peakZ * 0.018, 0.035) : 0.025;
        }

        return {
            is_anomaly: outliers.length > 0,
            anomaly_score: statisticalScore,
            outliers,
            max_zscore: maxZScore,
            detection_method: 'statistical',
            categories_detected: {
                custody_timing: outliers.some(o => ['custody_duration', 'issue_frequency'].includes(o.feature)),
                exchange_pattern: outliers.some(o => o.feature === 'firearm_exchange_rate'),
                ballistic_timing: outliers.some(o => o.feature.startsWith('ballistic_')),
                cross_unit: outliers.some(o => o.feature === 'cross_unit_transfer_frequency')
            }
        };
    } catch (error) {
        logger.error('Statistical outlier detection error:', error);
        return {
            is_anomaly: false,
            anomaly_score: 0,
            outliers: [],
            max_zscore: 0,
            detection_method: 'statistical',
            categories_detected: {}
        };
    }
};

module.exports = {
    detectStatisticalOutliers,
    calculateZScore
};
