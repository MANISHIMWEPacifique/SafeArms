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

        // ============================================
        // NEW: Cross-unit transfer patterns
        // ============================================
        
        // Multiple cross-unit transfers in short period
        const crossUnitCount30d = features.cross_unit_transfer_count_30d || 0;
        if (crossUnitCount30d > 2) {
            outliers.push({
                feature: 'cross_unit_transfer_frequency',
                value: crossUnitCount30d,
                severity: crossUnitCount30d > 4 ? 'high' : 'medium',
                description: `Firearm has crossed between units ${crossUnitCount30d} times in 30 days`
            });
            maxZScore = Math.max(maxZScore, crossUnitCount30d / 2.0);
        }

        // Calculate statistical anomaly score (0 to 1)
        const statisticalScore = outliers.length > 0
            ? Math.min(maxZScore / 4.0, 1.0)
            : 0;

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

/**
 * Calculate modified z-score (robust to outliers)
 * @param {number} value
 * @param {number} median
 * @param {number} mad - Median Absolute Deviation
 * @returns {number}
 */
const calculateModifiedZScore = (value, median, mad) => {
    if (mad === 0) return 0;
    return 0.6745 * (value - median) / mad;
};

/**
 * Detect univariate outliers using Interquartile Range (IQR)
 * @param {Array} values
 * @param {number} threshold - IQR multiplier (default: 1.5)
 * @returns {Object}
 */
const detectIQROutliers = (values, threshold = 1.5) => {
    if (values.length === 0) return { outliers: [], bounds: {} };

    const sorted = [...values].sort((a, b) => a - b);
    const q1Index = Math.floor(sorted.length * 0.25);
    const q3Index = Math.floor(sorted.length * 0.75);

    const q1 = sorted[q1Index];
    const q3 = sorted[q3Index];
    const iqr = q3 - q1;

    const lowerBound = q1 - threshold * iqr;
    const upperBound = q3 + threshold * iqr;

    const outliers = values
        .map((val, idx) => ({ value: val, index: idx }))
        .filter(item => item.value < lowerBound || item.value > upperBound);

    return {
        outliers,
        bounds: { lowerBound, upperBound, q1, q3, iqr }
    };
};

/**
 * Calculate percentile rank of a value
 * @param {number} value
 * @param {Array} dataset
 * @returns {number} Percentile (0-100)
 */
const calculatePercentile = (value, dataset) => {
    if (dataset.length === 0) return 50;

    const sorted = [...dataset].sort((a, b) => a - b);
    const countBelow = sorted.filter(v => v < value).length;

    return (countBelow / sorted.length) * 100;
};

/**
 * Detect multivariate outliers using Mahalanobis distance
 * (Simplified version for small datasets)
 * @param {Array} point - Feature vector
 * @param {Array} dataset - Array of feature vectors
 * @returns {number} Mahalanobis-like distance score
 */
const calculateMahalanobisDistance = (point, dataset) => {
    if (dataset.length === 0) return 0;

    const numFeatures = point.length;
    const means = new Array(numFeatures).fill(0);
    const stddevs = new Array(numFeatures).fill(0);

    // Calculate means
    dataset.forEach(row => {
        row.forEach((val, idx) => {
            means[idx] += val;
        });
    });
    means.forEach((sum, idx) => {
        means[idx] = sum / dataset.length;
    });

    // Calculate standard deviations
    dataset.forEach(row => {
        row.forEach((val, idx) => {
            stddevs[idx] += Math.pow(val - means[idx], 2);
        });
    });
    stddevs.forEach((sum, idx) => {
        stddevs[idx] = Math.sqrt(sum / dataset.length);
    });

    // Calculate normalized Euclidean distance (approximation of Mahalanobis)
    let distance = 0;
    point.forEach((val, idx) => {
        const normalized = stddevs[idx] > 0
            ? (val - means[idx]) / stddevs[idx]
            : 0;
        distance += normalized * normalized;
    });

    return Math.sqrt(distance);
};

/**
 * Perform Grubbs' test for outlier detection
 * @param {Array} values
 * @param {number} alpha - Significance level (default: 0.05)
 * @returns {Object}
 */
const grubbsTest = (values, alpha = 0.05) => {
    if (values.length < 3) return { hasOutlier: false };

    const mean = values.reduce((sum, v) => sum + v, 0) / values.length;
    const stddev = Math.sqrt(
        values.reduce((sum, v) => sum + Math.pow(v - mean, 2), 0) / values.length
    );

    if (stddev === 0) return { hasOutlier: false };

    // Find maximum deviation
    let maxDeviation = 0;
    let outlierValue = null;

    values.forEach(value => {
        const deviation = Math.abs(value - mean) / stddev;
        if (deviation > maxDeviation) {
            maxDeviation = deviation;
            outlierValue = value;
        }
    });

    // Critical value for Grubbs' test
    // Map common alpha values to t-distribution approximations
    const n = values.length;
    const tValues = { 0.01: 2.576, 0.05: 1.96, 0.10: 1.645 };
    const tCritical = tValues[alpha] || 1.96;
    const criticalValue = ((n - 1) / Math.sqrt(n)) *
        Math.sqrt(Math.pow(tCritical, 2) / (n - 2 + Math.pow(tCritical, 2)));

    return {
        hasOutlier: maxDeviation > criticalValue,
        outlierValue,
        maxDeviation,
        criticalValue
    };
};

module.exports = {
    detectStatisticalOutliers,
    calculateZScore,
    calculateModifiedZScore,
    detectIQROutliers,
    calculatePercentile,
    calculateMahalanobisDistance,
    grubbsTest
};
