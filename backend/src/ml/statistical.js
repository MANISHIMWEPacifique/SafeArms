const logger = require('../utils/logger');

/**
 * Statistical Outlier Detection
 * Uses z-score analysis to identify anomalous custody patterns
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

        // Calculate statistical anomaly score (0 to 1)
        const statisticalScore = outliers.length > 0
            ? Math.min(maxZScore / 4.0, 1.0)
            : 0;

        return {
            is_anomaly: outliers.length > 0,
            anomaly_score: statisticalScore,
            outliers,
            max_zscore: maxZScore,
            detection_method: 'statistical'
        };
    } catch (error) {
        logger.error('Statistical outlier detection error:', error);
        return {
            is_anomaly: false,
            anomaly_score: 0,
            outliers: [],
            max_zscore: 0,
            detection_method: 'statistical'
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

    // Critical value for Grubbs' test (simplified)
    const n = values.length;
    const criticalValue = ((n - 1) / Math.sqrt(n)) *
        Math.sqrt(Math.pow(1.96, 2) / (n - 2 + Math.pow(1.96, 2)));

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
