const { trainKMeansModel } = require('./kmeans');
const { extractAllFeatures } = require('./featureExtractor');
const { query, withTransaction } = require('../config/database');
const logger = require('../utils/logger');

const toPositiveInt = (value, fallback) => {
    const parsed = parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const toFiniteNumber = (value, fallback = 0) => {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const MIN_TRAINING_SAMPLES = toPositiveInt(process.env.ML_MIN_TRAINING_SAMPLES, 100);
const SCORING_THRESHOLD_SETTING_KEYS = [
    'anomaly_trigger_threshold',
    'anomaly_medium_threshold',
    'anomaly_high_threshold',
    'anomaly_critical_threshold',
    'anomaly_critical_min_confidence'
];

const getMinTrainingSamples = () => MIN_TRAINING_SAMPLES;

const getFeatureExtractionCandidates = async ({ refreshExisting = false } = {}) => {
    const result = await query(`
        SELECT cr.custody_id, cr.officer_id, cr.firearm_id, cr.unit_id,
               cr.issued_at, cr.returned_at, cr.custody_type,
               cr.duration_type,
               cr.custody_duration_seconds,
               cr.issue_hour, cr.issue_day_of_week,
               cr.is_night_issue, cr.is_weekend_issue
        FROM custody_records cr
        WHERE cr.issued_at IS NOT NULL
          AND (
              $1::boolean = true
              OR NOT EXISTS (
                  SELECT 1
                  FROM ml_training_features mf
                  WHERE mf.custody_record_id = cr.custody_id
              )
          )
          AND (
              $1::boolean = false
              OR cr.issued_at >= CURRENT_TIMESTAMP - INTERVAL '6 months'
          )
        ORDER BY cr.issued_at ASC
    `, [refreshExisting]);

    return result.rows;
};

const prepareTrainingFeatures = async ({ refreshExisting = false } = {}) => {
    const records = await getFeatureExtractionCandidates({ refreshExisting });
    const summary = {
        checked_records: records.length,
        extracted: 0,
        failed: 0
    };

    for (const record of records) {
        try {
            await extractAllFeatures(record, { throwOnStoreFailure: true });
            summary.extracted += 1;
        } catch (error) {
            summary.failed += 1;
            logger.warn(`Skipping feature extraction for ${record.custody_id}: ${error.message}`);
        }
    }

    return summary;
};

const generateAuditLogId = () => (
    `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`
);

const normalizeJsonValue = (value) => {
    if (typeof value !== 'string') {
        return value;
    }

    try {
        return JSON.parse(value);
    } catch (error) {
        return null;
    }
};

const normalizeCandidateRow = (row = {}) => ({
    model_id: row.model_id,
    model_type: row.model_type || 'kmeans',
    model_version: row.model_version,
    training_date: row.training_date,
    training_samples: parseInt(row.training_samples_count ?? row.training_samples ?? 0, 10),
    num_clusters: parseInt(row.num_clusters ?? 0, 10),
    silhouette_score: toFiniteNumber(row.silhouette_score, NaN),
    outlier_threshold: toFiniteNumber(row.outlier_threshold, NaN),
    cluster_centers: normalizeJsonValue(row.cluster_centers),
    normalization_params: normalizeJsonValue(row.normalization_params)
});

const assertCandidateModelQuality = (modelResult, minSamples) => {
    if (!modelResult?.model_id) {
        throw new Error('Candidate model did not return a model_id');
    }

    if (toFiniteNumber(modelResult.training_samples, 0) < minSamples) {
        throw new Error(
            `Candidate model has insufficient training samples. Need at least ${minSamples}, got ${modelResult.training_samples || 0}`
        );
    }

    if (!Number.isFinite(toFiniteNumber(modelResult.silhouette_score, NaN))) {
        throw new Error('Candidate model silhouette score is invalid');
    }

    if (toFiniteNumber(modelResult.outlier_threshold, 0) <= 0) {
        throw new Error('Candidate model outlier threshold is invalid');
    }

    if (!Number.isInteger(modelResult.num_clusters) || modelResult.num_clusters < 2) {
        throw new Error('Candidate model cluster count is invalid');
    }

    if (!Array.isArray(modelResult.cluster_centers) || modelResult.cluster_centers.length < modelResult.num_clusters) {
        throw new Error('Candidate model cluster centers are invalid');
    }

    const normalization = modelResult.normalization_params;
    if (
        !normalization ||
        !Array.isArray(normalization.mins) ||
        !Array.isArray(normalization.maxs) ||
        normalization.mins.length === 0 ||
        normalization.mins.length !== normalization.maxs.length
    ) {
        throw new Error('Candidate model normalization parameters are invalid');
    }
};

const findLatestPromotableCandidate = async ({ minSamples, requiredSampleCount }) => {
    const result = await query(`
        WITH active_model AS (
            SELECT training_date
            FROM ml_model_metadata
            WHERE model_type = 'kmeans' AND is_active = true
            ORDER BY training_date DESC
            LIMIT 1
        )
        SELECT model_id, model_type, model_version, training_date,
               training_samples_count, num_clusters, cluster_centers,
               silhouette_score, outlier_threshold, normalization_params
        FROM ml_model_metadata
        WHERE model_type = 'kmeans'
          AND is_active = false
          AND training_samples_count >= $1
          AND training_samples_count >= $2
          AND num_clusters >= 2
          AND cluster_centers IS NOT NULL
          AND normalization_params IS NOT NULL
          AND outlier_threshold > 0
          AND training_date >= COALESCE((SELECT training_date FROM active_model), '-infinity'::timestamp)
        ORDER BY training_date DESC
        LIMIT 1
    `, [minSamples, requiredSampleCount]);

    if (result.rows.length === 0) {
        return null;
    }

    const candidate = normalizeCandidateRow(result.rows[0]);
    assertCandidateModelQuality(candidate, minSamples);
    return candidate;
};

const loadPromotionSnapshot = async (client) => {
    const activeModelResult = await client.query(`
        SELECT model_id, model_type, model_version, training_date,
               training_samples_count, num_clusters, silhouette_score,
               outlier_threshold, is_active
        FROM ml_model_metadata
        WHERE model_type = 'kmeans' AND is_active = true
        ORDER BY training_date DESC
        LIMIT 1
    `);

    const thresholdResult = await client.query(`
        SELECT setting_key, setting_value
        FROM system_settings
        WHERE setting_key = ANY($1::text[])
        ORDER BY setting_key
    `, [SCORING_THRESHOLD_SETTING_KEYS]);

    const thresholds = thresholdResult.rows.reduce((settings, row) => {
        settings[row.setting_key] = row.setting_value;
        return settings;
    }, {});

    return {
        previousActiveModel: activeModelResult.rows[0] || null,
        thresholds
    };
};

const promoteCandidateModel = async ({ modelResult, minSamples }) => {
    return withTransaction(async (client) => {
        await client.query('SELECT pg_advisory_xact_lock($1)', [947216]);

        const candidateResult = await client.query(`
            SELECT model_id, model_type, model_version, training_date,
                   training_samples_count, num_clusters, cluster_centers,
                   silhouette_score, outlier_threshold, normalization_params
            FROM ml_model_metadata
            WHERE model_id = $1
              AND model_type = 'kmeans'
            FOR UPDATE
        `, [modelResult.model_id]);

        if (candidateResult.rows.length === 0) {
            throw new Error(`Candidate model ${modelResult.model_id} not found for promotion`);
        }

        const candidate = normalizeCandidateRow(candidateResult.rows[0]);
        assertCandidateModelQuality(candidate, minSamples);

        const { previousActiveModel, thresholds } = await loadPromotionSnapshot(client);

        await client.query(`
            UPDATE ml_model_metadata
            SET precision_score = NULL,
                recall_score = NULL,
                f1_score = NULL,
                effectiveness_score = NULL,
                false_positive_rate_estimate = NULL
            WHERE model_id = $1
        `, [candidate.model_id]);

        await client.query(`
            INSERT INTO audit_logs (
                log_id, user_id, action_type, table_name, record_id,
                old_values, new_values, reason
            ) VALUES ($1, NULL, 'ML_MODEL_PROMOTE', 'ml_model_metadata', $2, $3, $4, $5)
        `, [
            generateAuditLogId(),
            candidate.model_id,
            JSON.stringify({ previous_active_model: previousActiveModel }),
            JSON.stringify({
                candidate_model: {
                    model_id: candidate.model_id,
                    model_version: candidate.model_version,
                    training_samples: candidate.training_samples,
                    num_clusters: candidate.num_clusters,
                    silhouette_score: candidate.silhouette_score,
                    outlier_threshold: candidate.outlier_threshold,
                    training_data_fingerprint: modelResult.training_data_fingerprint || null,
                    training_data_summary: modelResult.training_data_summary || null
                },
                preserved_thresholds: thresholds,
                minimum_required_samples: minSamples
            }),
            'Promoting validated unsupervised K-Means candidate while preserving prior model metadata and thresholds.'
        ]);

        await client.query(`
            UPDATE ml_model_metadata
            SET is_active = false
            WHERE model_type = 'kmeans'
              AND is_active = true
              AND model_id != $1
        `, [candidate.model_id]);

        const promoted = await client.query(`
            UPDATE ml_model_metadata
            SET is_active = true
            WHERE model_id = $1
            RETURNING model_id
        `, [candidate.model_id]);

        if (promoted.rows.length === 0) {
            throw new Error(`Candidate model ${candidate.model_id} not found for promotion`);
        }

        await client.query(`
            UPDATE ml_training_features
            SET used_in_model_id = $1
            WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
        `, [candidate.model_id]);

        const activeCountResult = await client.query(`
            SELECT COUNT(*)::int AS active_count
            FROM ml_model_metadata
            WHERE model_type = 'kmeans'
              AND is_active = true
        `);

        if (parseInt(activeCountResult.rows[0].active_count, 10) !== 1) {
            throw new Error('Model promotion failed to leave exactly one active K-Means model');
        }

        return {
            previous_active_model_id: previousActiveModel?.model_id || null,
            promoted_model_id: promoted.rows[0].model_id,
            preserved_thresholds: thresholds,
            training_data_fingerprint: modelResult.training_data_fingerprint || null
        };
    });
};

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
        const {
            k = 6,
            minSamples = getMinTrainingSamples(),
            reuseExistingCandidate = false,
            refreshExistingFeatures = false
        } = options;

        logger.info('Starting model training...');
        const preparedFeatures = await prepareTrainingFeatures({
            refreshExisting: refreshExistingFeatures
        });
        logger.info(
            `Training preparation complete. Missing records checked: ${preparedFeatures.checked_records}, ` +
            `extracted: ${preparedFeatures.extracted}, failed: ${preparedFeatures.failed}`
        );

        if (preparedFeatures.failed > 0) {
            throw new Error(`Feature extraction failed for ${preparedFeatures.failed} custody record(s); training stopped before promotion.`);
        }

        // Check if sufficient training data exists across the full recent
        // baseline. Previously used rows stay eligible so retraining extends
        // learned patterns instead of starting from only new rows.
        const countResult = await query(`
            SELECT COUNT(*) as count
            FROM ml_training_features
            WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
        `);

        const sampleCount = parseInt(countResult.rows[0].count);

        if (sampleCount < minSamples) {
            throw new Error(`Insufficient training data. Need at least ${minSamples} samples, got ${sampleCount}`);
        }

        let modelResult = null;

        if (reuseExistingCandidate) {
            modelResult = await findLatestPromotableCandidate({
                minSamples,
                requiredSampleCount: sampleCount
            });

            if (modelResult) {
                logger.info(`Promoting existing validated K-Means candidate ${modelResult.model_id}`);
            }
        }

        if (!modelResult) {
            modelResult = await trainKMeansModel(k);
        }

        assertCandidateModelQuality(modelResult, minSamples);

        const promotion = await promoteCandidateModel({
            modelResult,
            minSamples
        });

        logger.info(`Model training complete. Model ID: ${modelResult.model_id}`);

        return {
            success: true,
            ...modelResult,
            prepared_features: preparedFeatures,
            promotion
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

        // Check model age (retrain if > 21 days / 3 weeks old)
        if (modelAgeDays > 21) {
            return {
                needed: true,
                reason: `Model is ${modelAgeDays} days old (threshold: 21 days)`
            };
        }

        // Check new data availability
                const newDataResult = await query(`
            SELECT COUNT(*) as count
            FROM ml_training_features
            WHERE used_in_model_id IS NULL
                AND feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
        `);

        const newSamples = parseInt(newDataResult.rows[0].count);

        // Retrain if > 1000 new samples
        if (newSamples > 1000) {
            return {
                needed: true,
                reason: `${newSamples} new samples available (threshold: 1000)`
            };
        }

        // Check model performance using reviewed outcomes only. Open anomalies
        // are pending review, not confirmed non-false-positives.
        const performanceResult = await query(`
      SELECT 
        COUNT(*) FILTER (WHERE status = 'false_positive') as false_positives,
        COUNT(*) FILTER (WHERE status IN ('resolved', 'false_positive', 'acceptable_change')) as reviewed_detections,
        COUNT(*) as total_detections
      FROM anomalies
      WHERE model_id = $1
      AND detected_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    `, [model.model_id]);

        const performance = performanceResult.rows[0];
        const reviewedDetections = parseInt(performance.reviewed_detections || 0, 10);
        const fpRate = reviewedDetections > 0
            ? parseInt(performance.false_positives || 0, 10) / reviewedDetections
            : null;

        // Retrain if false positive rate > 30%
        if (fpRate !== null && fpRate > 0.30 && reviewedDetections > 20) {
            return {
                needed: true,
                reason: `High false positive rate: ${(fpRate * 100).toFixed(1)}% (threshold: 30%)`
            };
        }

        const reviewSummary = fpRate === null
            ? 'review outcomes pending'
            : `reviewed FP rate: ${(fpRate * 100).toFixed(1)}%`;

        return {
            needed: false,
            reason: `Model is current (age: ${modelAgeDays} days, new samples: ${newSamples}, ${reviewSummary})`
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
        COUNT(*) FILTER (WHERE status IN ('resolved', 'false_positive', 'acceptable_change')) as reviewed_count,
        AVG(anomaly_score) as avg_anomaly_score,
        AVG(confidence_level) as avg_confidence
      FROM anomalies
      WHERE model_id = $1
    `, [modelId]);

        const stats = result.rows[0];

        const reviewedDetections = parseInt(stats.reviewed_count || 0, 10);
        const falsePositiveRate = reviewedDetections > 0
            ? parseFloat(stats.false_positives) / reviewedDetections
            : null;

        return {
            total_detections: parseInt(stats.total_detections),
            severity_distribution: {
                critical: parseInt(stats.critical_count),
                high: parseInt(stats.high_count),
                medium: parseInt(stats.medium_count),
                low: parseInt(stats.low_count)
            },
            false_positive_rate: falsePositiveRate,
            reviewed_detections: reviewedDetections,
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
    prepareTrainingFeatures,
    checkRetrainingNeeded,
    getModelMetrics,
    getMinTrainingSamples
};
