const { trainKMeansModel } = require('./kmeans');
const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Model Trainer
 * Handles periodic retraining of ML models
 */

/**
 * Train a new K-Means model
 * @param {Object} options - Training options
 * @returns {Promise<Object>} Training results
 */
const trainModel = async (options = {}) => {
    try {
        const { k = 6, minSamples = 100 } = options;

        logger.info('Starting model training...');

        // Check if sufficient training data exists
        const countResult = await query(`
      SELECT COUNT(*) as count
      FROM ml_training_features
      WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);

        const sampleCount = parseInt(countResult.rows[0].count);

        if (sampleCount < minSamples) {
            throw new Error(`Insufficient training data. Need at least ${minSamples} samples, got ${sampleCount}`);
        }

        // Train K-Means model
        const modelResult = await trainKMeansModel(k);

        logger.info(`Model training complete. Model ID: ${modelResult.model_id}`);

        return {
            success: true,
            ...modelResult
        };
    } catch (error) {
        logger.error('Model training error:', error);
        throw error;
    }
};

/**
 * Check if model retraining is needed
 * @returns {Promise<Object>} Recommendation
 */
const checkRetrainingNeeded = async () => {
    try {
        // Get active model
        const modelResult = await query(`
      SELECT * FROM ml_model_metadata
      WHERE model_type = 'kmeans' AND is_active = true
      ORDER BY training_date DESC
      LIMIT 1
    `);

        if (modelResult.rows.length === 0) {
            return {
                needed: true,
                reason: 'No active model found'
            };
        }

        const model = modelResult.rows[0];
        const modelAgeDays = Math.floor(
            (new Date() - new Date(model.training_date)) / (1000 * 60 * 60 * 24)
        );

        // Check model age (retrain if > 30 days old)
        if (modelAgeDays > 30) {
            return {
                needed: true,
                reason: `Model is ${modelAgeDays} days old (threshold: 30 days)`
            };
        }

        // Check new data availability
        const newDataResult = await query(`
      SELECT COUNT(*) as count
      FROM ml_training_features
      WHERE feature_extraction_date > $1
    `, [model.training_date]);

        const newSamples = parseInt(newDataResult.rows[0].count);

        // Retrain if > 1000 new samples
        if (newSamples > 1000) {
            return {
                needed: true,
                reason: `${newSamples} new samples available (threshold: 1000)`
            };
        }

        // Check model performance (false positive rate)
        const performanceResult = await query(`
      SELECT 
        COUNT(*) FILTER (WHERE status = 'false_positive') as false_positives,
        COUNT(*) as total_detections
      FROM anomalies
      WHERE model_id = $1
      AND detected_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    `, [model.model_id]);

        const performance = performanceResult.rows[0];
        const fpRate = performance.total_detections > 0
            ? performance.false_positives / performance.total_detections
            : 0;

        // Retrain if false positive rate > 30%
        if (fpRate > 0.30 && performance.total_detections > 20) {
            return {
                needed: true,
                reason: `High false positive rate: ${(fpRate * 100).toFixed(1)}% (threshold: 30%)`
            };
        }

        return {
            needed: false,
            reason: `Model is performing well (age: ${modelAgeDays} days, new samples: ${newSamples}, FP rate: ${(fpRate * 100).toFixed(1)}%)`
        };
    } catch (error) {
        logger.error('Check retraining needed error:', error);
        return {
            needed: false,
            reason: 'Error checking retraining status',
            error: error.message
        };
    }
};

/**
 * Get model performance metrics
 * @param {string} modelId
 * @returns {Promise<Object>}
 */
const getModelMetrics = async (modelId) => {
    try {
        const result = await query(`
      SELECT 
        COUNT(*) as total_detections,
        COUNT(*) FILTER (WHERE severity = 'critical') as critical_count,
        COUNT(*) FILTER (WHERE severity = 'high') as high_count,
        COUNT(*) FILTER (WHERE severity = 'medium') as medium_count,
        COUNT(*) FILTER (WHERE severity = 'low') as low_count,
        COUNT(*) FILTER (WHERE status = 'false_positive') as false_positives,
        COUNT(*) FILTER (WHERE status = 'resolved') as resolved_count,
        AVG(anomaly_score) as avg_anomaly_score,
        AVG(confidence_level) as avg_confidence
      FROM anomalies
      WHERE model_id = $1
    `, [modelId]);

        const stats = result.rows[0];

        const falsePositiveRate = stats.total_detections > 0
            ? parseFloat(stats.false_positives) / parseFloat(stats.total_detections)
            : 0;

        return {
            total_detections: parseInt(stats.total_detections),
            severity_distribution: {
                critical: parseInt(stats.critical_count),
                high: parseInt(stats.high_count),
                medium: parseInt(stats.medium_count),
                low: parseInt(stats.low_count)
            },
            false_positive_rate: falsePositiveRate,
            resolution_rate: stats.total_detections > 0
                ? parseFloat(stats.resolved_count) / parseFloat(stats.total_detections)
                : 0,
            avg_anomaly_score: parseFloat(stats.avg_anomaly_score) || 0,
            avg_confidence: parseFloat(stats.avg_confidence) || 0
        };
    } catch (error) {
        logger.error('Get model metrics error:', error);
        throw error;
    }
};

module.exports = {
    trainModel,
    checkRetrainingNeeded,
    getModelMetrics
};
