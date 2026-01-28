const logger = require('../utils/logger');

/**
 * Ensemble Anomaly Scorer for EVENT-Based Detection
 * 
 * IMPORTANT PRINCIPLES:
 * 1. This system evaluates EVENTS, not people
 * 2. Severity indicates REVIEW URGENCY, not wrongdoing
 * 3. Cross-unit transfers ALWAYS trigger anomalies (organizational policy)
 * 4. Ballistic access timing relative to custody is a key feature
 * 5. The system remains unsupervised - it identifies patterns for human review
 * 
 * SEVERITY LEVELS (Review Urgency):
 * - critical: Immediate review required (same day)
 * - high: Review within 24 hours
 * - medium: Review within 72 hours  
 * - low: Standard review queue
 */

/**
 * Calculate ensemble anomaly score
 * @param {Object} kmeansResult - K-Means detection result
 * @param {Object} statisticalResult - Statistical detection result
 * @param {Object} features - Original features including event context
 * @returns {Object} Final anomaly verdict
 */
const calculateEnsembleScore = (kmeansResult, statisticalResult, features) => {
    try {
        // MANDATORY ANOMALY: Cross-unit transfers always trigger review
        const isCrossUnitTransfer = features.is_cross_unit_transfer === true;
        
        // Weight configuration
        const weights = {
            kmeans: 0.35,
            statistical: 0.25,
            ruleBased: 0.25,
            ballisticTiming: 0.15
        };

        // Rule-based score from pattern flags
        const ruleScore = calculateRuleBasedScore(features);
        
        // Ballistic timing score (new feature)
        const ballisticTimingScore = features.ballistic_access_timing_score || 0;

        // Calculate weighted ensemble score
        let ensembleScore = (
            weights.kmeans * (kmeansResult?.anomaly_score || 0) +
            weights.statistical * (statisticalResult?.anomaly_score || 0) +
            weights.ruleBased * ruleScore +
            weights.ballisticTiming * ballisticTimingScore
        );

        // POLICY: Cross-unit transfers always have minimum score of 0.4
        if (isCrossUnitTransfer) {
            ensembleScore = Math.max(ensembleScore, 0.4);
        }

        // Calculate confidence based on detector agreement
        const detectorAgreement = [
            kmeansResult?.is_anomaly || false,
            statisticalResult?.is_anomaly || false,
            ruleScore > 0.5,
            ballisticTimingScore > 0.5,
            isCrossUnitTransfer
        ].filter(Boolean).length;

        const confidence = detectorAgreement / 5.0;

        // Classify severity (review urgency, NOT wrongdoing indication)
        const severity = classifySeverity(ensembleScore, confidence, features);

        // Determine anomaly type
        const anomalyType = determineAnomalyType(features, kmeansResult, statisticalResult);

        // Calculate feature importance
        const featureImportance = calculateFeatureImportance(features, kmeansResult, statisticalResult);

        // Build contributing factors
        const contributingFactors = buildContributingFactors(features, kmeansResult, statisticalResult);

        // DECISION: Anomaly if score > 0.35 OR if cross-unit transfer
        const isAnomaly = ensembleScore > 0.35 || isCrossUnitTransfer;

        return {
            is_anomaly: isAnomaly,
            anomaly_score: ensembleScore,
            confidence,
            severity,
            anomaly_type: anomalyType,
            is_mandatory_review: isCrossUnitTransfer, // Policy-mandated review
            feature_importance: featureImportance,
            contributing_factors: contributingFactors,
            event_context: features.event_context || null,
            ballistic_access_context: {
                has_profile: features.has_ballistic_profile,
                accesses_24h: features.ballistic_accesses_24h || 0,
                timing_score: ballisticTimingScore,
                access_during_custody: features.ballistic_access_during_custody || false,
                access_before_hours: features.ballistic_access_before_custody_hours,
                access_after_hours: features.ballistic_access_after_custody_hours
            },
            detection_methods: {
                kmeans: kmeansResult,
                statistical: statisticalResult,
                rule_based: { score: ruleScore },
                ballistic_timing: { score: ballisticTimingScore }
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
            is_mandatory_review: false,
            feature_importance: {},
            contributing_factors: {},
            event_context: null,
            ballistic_access_context: null
        };
    }
};

/**
 * Calculate rule-based anomaly score
 * Includes cross-unit transfer and ballistic timing rules
 * @param {Object} features
 * @returns {number} Score between 0 and 1
 */
const calculateRuleBasedScore = (features) => {
    let score = 0;
    let flagCount = 0;

    // POLICY: Cross-unit transfer (HIGH weight - always requires review)
    if (features.is_cross_unit_transfer) {
        score += 1.0;
        flagCount++;
    }

    // Rapid exchange flag (high weight)
    if (features.rapid_exchange_flag) {
        score += 0.8;
        flagCount++;
    }

    // Ballistic access around custody change (medium-high weight)
    if (features.ballistic_access_before_custody_hours !== null && 
        features.ballistic_access_before_custody_hours < 6) {
        score += 0.6;
        flagCount++;
    }
    if (features.ballistic_access_after_custody_hours !== null && 
        features.ballistic_access_after_custody_hours < 6) {
        score += 0.6;
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

    // Cross-unit movement in officer history (medium weight)
    if (features.cross_unit_movement_flag) {
        score += 0.4;
        flagCount++;
    }

    // High exchange rate
    if (features.firearm_exchange_rate_7d > 1.0) {
        score += 0.5;
        flagCount++;
    }

    // High ballistic access frequency
    if (features.ballistic_accesses_24h > 3) {
        score += 0.4;
        flagCount++;
    }

    // Multiple cross-unit transfers for same firearm
    if (features.cross_unit_transfer_count_30d > 2) {
        score += 0.5;
        flagCount++;
    }

    // Normalize score
    return flagCount > 0 ? Math.min(score / flagCount, 1.0) : 0;
};

/**
 * Classify severity based on score, confidence, and features
 * 
 * IMPORTANT: Severity indicates REVIEW URGENCY, not wrongdoing
 * - critical: Immediate review required (same day)
 * - high: Review within 24 hours
 * - medium: Review within 72 hours
 * - low: Standard review queue
 * 
 * @param {number} score
 * @param {number} confidence
 * @param {Object} features
 * @returns {string}
 */
const classifySeverity = (score, confidence, features = {}) => {
    // Cross-unit transfers are always at least 'medium' urgency
    const isCrossUnit = features.is_cross_unit_transfer === true;
    
    // Ballistic access timing issues elevate urgency
    const hasBallisticTimingConcern = (features.ballistic_access_timing_score || 0) > 0.6;

    if (score >= 0.85 && confidence >= 0.6) return 'critical';
    if (score >= 0.70 || (isCrossUnit && hasBallisticTimingConcern)) return 'high';
    if (score >= 0.50 || isCrossUnit) return 'medium';
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
    
    // HIGHEST PRIORITY: Cross-unit transfer (organizational policy)
    if (features.is_cross_unit_transfer) {
        return 'cross_unit_transfer';
    }
    
    if (features.rapid_exchange_flag) {
        return 'rapid_exchange_pattern';
    }
    
    // Ballistic access timing anomalies
    if (features.ballistic_access_timing_score > 0.6) {
        if (features.ballistic_access_before_custody_hours !== null && 
            features.ballistic_access_before_custody_hours < 6) {
            return 'ballistic_access_before_custody';
        }
        if (features.ballistic_access_after_custody_hours !== null && 
            features.ballistic_access_after_custody_hours < 6) {
            return 'ballistic_access_after_custody';
        }
        return 'ballistic_access_timing_pattern';
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

    // Cross-unit transfer - highest importance (policy-mandated)
    if (features.is_cross_unit_transfer) {
        importance.cross_unit_transfer = 1.0;
    }

    // Rapid exchange - highest importance if triggered
    if (features.rapid_exchange_flag) {
        importance.rapid_exchange = 0.95;
    }

    // Ballistic timing features
    if (features.ballistic_access_timing_score > 0) {
        importance.ballistic_access_timing = features.ballistic_access_timing_score;
    }
    if (features.ballistic_access_before_custody_hours !== null && 
        features.ballistic_access_before_custody_hours < 24) {
        importance.ballistic_before_custody = Math.max(0.4, 1 - (features.ballistic_access_before_custody_hours / 24));
    }
    if (features.ballistic_access_after_custody_hours !== null && 
        features.ballistic_access_after_custody_hours < 24) {
        importance.ballistic_after_custody = Math.max(0.4, 1 - (features.ballistic_access_after_custody_hours / 24));
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

    // Cross-unit movement in history
    if (features.cross_unit_movement_flag) {
        importance.cross_unit_history = 0.7;
    }

    // Exchange rate
    if (features.firearm_exchange_rate_7d > 0.5) {
        importance.exchange_rate = Math.min(features.firearm_exchange_rate_7d / 2.0, 1.0);
    }

    // Multiple cross-unit transfers
    if (features.cross_unit_transfer_count_30d > 1) {
        importance.repeated_cross_unit = Math.min(features.cross_unit_transfer_count_30d / 5.0, 1.0);
    }

    return importance;
};

/**
 * Build human-readable contributing factors
 * NOTE: These are observations for review, NOT accusations
 * @param {Object} features
 * @param {Object} kmeansResult
 * @param {Object} statisticalResult
 * @returns {Object}
 */
const buildContributingFactors = (features, kmeansResult, statisticalResult) => {
    const factors = {};

    // Cross-unit transfer (policy-mandated review)
    if (features.is_cross_unit_transfer) {
        factors.cross_unit_transfer = `Firearm transferred from ${features.previous_unit_name || 'another unit'} - requires standard cross-unit review`;
    }

    if (features.rapid_exchange_flag) {
        factors.rapid_exchange = `Firearm returned and reissued within 1 hour`;
    }

    // Ballistic access timing factors
    if (features.ballistic_access_before_custody_hours !== null && 
        features.ballistic_access_before_custody_hours < 24) {
        factors.ballistic_before_custody = `Ballistic profile accessed ${features.ballistic_access_before_custody_hours.toFixed(1)} hours before custody change`;
    }
    if (features.ballistic_access_after_custody_hours !== null && 
        features.ballistic_access_after_custody_hours < 24) {
        factors.ballistic_after_custody = `Ballistic profile accessed ${features.ballistic_access_after_custody_hours.toFixed(1)} hours after custody change`;
    }
    if (features.ballistic_accesses_24h > 3) {
        factors.high_ballistic_access = `Ballistic profile accessed ${features.ballistic_accesses_24h} times in last 24 hours`;
    }

    if (features.is_night_issue) {
        factors.night_issue = `Custody issued during night hours (${features.issue_hour}:00)`;
    }

    if (features.is_weekend_issue) {
        const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
        factors.weekend_issue = `Issued on ${days[features.issue_day_of_week]}`;
    }

    if (features.cross_unit_movement_flag) {
        factors.cross_unit_history = `Officer has history of receiving firearms from other units`;
    }

    if (features.firearm_exchange_rate_7d > 1.0) {
        factors.high_exchange_rate = `Firearm exchanged ${features.firearm_exchange_rate_7d.toFixed(1)}x per day (7-day average)`;
    }

    if (features.cross_unit_transfer_count_30d > 1) {
        factors.repeated_cross_unit = `Firearm has changed units ${features.cross_unit_transfer_count_30d} times in last 30 days`;
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
