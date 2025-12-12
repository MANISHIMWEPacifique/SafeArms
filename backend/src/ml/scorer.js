const logger = require('../utils/logger');

/**
 * Ensemble Anomaly Scorer
 * Combines multiple detection methods into a single anomaly score
 */

/**
 * Calculate ensemble anomaly score
 * @param {Object} kmeansResult - K-Means detection result
 * @param {Object} statisticalResult - Statistical detection result
 * @param {Object} features - Original features
 * @returns {Object} Final anomaly verdict
 */
const calculateEnsembleScore = (kmeansResult, statisticalResult, features) => {
    try {
        // Weight configuration
        const weights = {
            kmeans: 0.5,
            statistical: 0.3,
            ruleBased: 0.2
        };

        // Rule-based score from pattern flags
        const ruleScore = calculateRuleBasedScore(features);

        // Calculate weighted ensemble score
        const ensembleScore = (
            weights.kmeans * (kmeansResult?.anomaly_score || 0) +
            weights.statistical * (statisticalResult?.anomaly_score || 0) +
            weights.ruleBased * ruleScore
        );

        // Calculate confidence based on detector agreement
        const detectorAgreement = [
            kmeansResult?.is_anomaly || false,
            statisticalResult?.is_anomaly || false,
            ruleScore > 0.5
        ].filter(Boolean).length;

        const confidence = detectorAgreement / 3.0;

        // Classify severity
        const severity = classifySeverity(ensembleScore, confidence);

        // Determine anomaly type
        const anomalyType = determineAnomalyType(features, kmeansResult, statisticalResult);

        // Calculate feature importance
        const featureImportance = calculateFeatureImportance(features, kmeansResult, statisticalResult);

        // Build contributing factors
        const contributingFactors = buildContributingFactors(features, kmeansResult, statisticalResult);

        return {
            is_anomaly: ensembleScore > 0.35, // Detection threshold
            anomaly_score: ensembleScore,
            confidence,
            severity,
            anomaly_type: anomalyType,
            feature_importance: featureImportance,
            contributing_factors: contributingFactors,
            detection_methods: {
                kmeans: kmeansResult,
                statistical: statisticalResult,
                rule_based: { score: ruleScore }
            }
        };
    } catch (error) {
        logger.error('Calculate ensemble score error:', error);
        return {
            is_anomaly: false,
            anomaly_score: 0,
            confidence: 0,
            severity: 'low',
            anomaly_type: 'unknown',
            feature_importance: {},
            contributing_factors: {}
        };
    }
};

/**
 * Calculate rule-based anomaly score
 * @param {Object} features
 * @returns {number} Score between 0 and 1
 */
const calculateRuleBasedScore = (features) => {
    let score = 0;
    let flagCount = 0;

    // Rapid exchange flag (high weight)
    if (features.rapid_exchange_flag) {
        score += 0.8;
        flagCount++;
    }

    // Night issue (medium weight)
    if (features.is_night_issue) {
        score += 0.3;
        flagCount++;
    }

    // Weekend issue (low weight)
    if (features.is_weekend_issue) {
        score += 0.2;
        flagCount++;
    }

    // Cross-unit movement (medium weight)
    if (features.cross_unit_movement_flag) {
        score += 0.4;
        flagCount++;
    }

    // High exchange rate
    if (features.firearm_exchange_rate_7d > 1.0) {
        score += 0.5;
        flagCount++;
    }

    // Normalize score
    return flagCount > 0 ? Math.min(score / flagCount, 1.0) : 0;
};

/**
 * Classify severity based on score and confidence
 * @param {number} score
 * @param {number} confidence
 * @returns {string}
 */
const classifySeverity = (score, confidence) => {
    if (score >= 0.85 && confidence >= 0.6) return 'critical';
    if (score >= 0.70) return 'high';
    if (score >= 0.50) return 'medium';
    return 'low';
};

/**
 * Determine primary anomaly type
 * @param {Object} features
 * @param {Object} kmeansResult
 * @param {Object} statisticalResult
 * @returns {string}
 */
const determineAnomalyType = (features, kmeansResult, statisticalResult) => {
    // Priority-based classification
    if (features.rapid_exchange_flag) {
        return 'rapid_exchange_pattern';
    }

    if (statisticalResult?.outliers?.length > 0) {
        const primaryOutlier = statisticalResult.outliers[0];
        if (primaryOutlier.feature === 'custody_duration') {
            return 'unusual_custody_duration';
        }
        if (primaryOutlier.feature === 'issue_frequency') {
            return 'unusual_issue_frequency';
        }
    }

    if (features.cross_unit_movement_flag) {
        return 'cross_unit_anomaly';
    }

    if (features.is_night_issue && features.is_weekend_issue) {
        return 'off_hours_activity';
    }

    if (kmeansResult?.is_anomaly) {
        return 'cluster_outlier';
    }

    if (features.firearm_exchange_rate_7d > 1.5) {
        return 'high_exchange_rate';
    }

    return 'behavioral_deviation';
};

/**
 * Calculate feature importance scores
 * @param {Object} features
 * @param {Object} kmeansResult
 * @param {Object} statisticalResult
 * @returns {Object}
 */
const calculateFeatureImportance = (features, kmeansResult, statisticalResult) => {
    const importance = {};

    // Rapid exchange - highest importance if triggered
    if (features.rapid_exchange_flag) {
        importance.rapid_exchange = 0.95;
    }

    // Statistical outliers
    if (statisticalResult?.outliers) {
        statisticalResult.outliers.forEach(outlier => {
            const score = Math.min(Math.abs(outlier.zscore) / 4.0, 1.0);
            importance[outlier.feature] = score;
        });
    }

    // K-Means distance
    if (kmeansResult?.distance) {
        importance.cluster_distance = Math.min(kmeansResult.distance / 3.0, 1.0);
    }

    // Temporal anomalies
    if (features.is_night_issue) {
        importance.night_issue = 0.6;
    }

    if (features.is_weekend_issue) {
        importance.weekend_issue = 0.4;
    }

    // Cross-unit movement
    if (features.cross_unit_movement_flag) {
        importance.cross_unit_movement = 0.7;
    }

    // Exchange rate
    if (features.firearm_exchange_rate_7d > 0.5) {
        importance.exchange_rate = Math.min(features.firearm_exchange_rate_7d / 2.0, 1.0);
    }

    return importance;
};

/**
 * Build human-readable contributing factors
 * @param {Object} features
 * @param {Object} kmeansResult
 * @param {Object} statisticalResult
 * @returns {Object}
 */
const buildContributingFactors = (features, kmeansResult, statisticalResult) => {
    const factors = {};

    if (features.rapid_exchange_flag) {
        factors.rapid_exchange = `Firearm returned and reissued within 1 hour`;
    }

    if (features.is_night_issue) {
        factors.night_issue = `Custody issued during night hours (${features.issue_hour}:00)`;
    }

    if (features.is_weekend_issue) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        factors.weekend_issue = `Issued on ${days[features.issue_day_of_week]}`;
    }

    if (features.cross_unit_movement_flag) {
        factors.cross_unit_movement = `Officer received firearm from different unit`;
    }

    if (features.firearm_exchange_rate_7d > 1.0) {
        factors.high_exchange_rate = `Firearm exchanged ${features.firearm_exchange_rate_7d.toFixed(1)}x per day (7-day average)`;
    }

    if (statisticalResult?.outliers) {
        statisticalResult.outliers.forEach(outlier => {
            factors[outlier.feature + '_outlier'] = outlier.description;
        });
    }

    if (kmeansResult?.distance > 2.0) {
        factors.cluster_outlier = `Pattern significantly deviates from normal clusters (distance: ${kmeansResult.distance.toFixed(2)})`;
    }

    if (features.officer_issue_frequency_30d > 2.0) {
        factors.high_frequency = `Officer receives firearms ${features.officer_issue_frequency_30d.toFixed(1)} times per day`;
    }

    return factors;
};

module.exports = {
    calculateEnsembleScore,
    calculateRuleBasedScore,
    classifySeverity,
    determineAnomalyType,
    calculateFeatureImportance,
    buildContributingFactors
};
