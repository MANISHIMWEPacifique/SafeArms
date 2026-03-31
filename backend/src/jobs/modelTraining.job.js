const cron = require('node-cron');
const {
    trainModel,
    checkRetrainingNeeded,
    getMinTrainingSamples
} = require('../ml/modelTrainer');
const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Model Training Background Job
 * Automatically trains ML models on a schedule
 */

/**
 * Run model training
 * @param {Object} options
 * @param {boolean} options.force - Force retraining even when checks say not needed
 * @param {string} options.trigger - Trigger source label (scheduled/manual)
 * @returns {Promise<Object>} Training outcome
 */
let latestTrainingRun = {
    status: 'idle',
    trigger: null,
    started_at: null,
    finished_at: null,
    reason: null,
    error: null,
    model_id: null,
    training_samples: null,
    silhouette_score: null,
    outlier_threshold: null
};

const runModelTraining = async (options = {}) => {
    const { force = false, trigger = 'scheduled' } = options;
    const startedAt = new Date().toISOString();

    latestTrainingRun = {
        status: 'running',
        trigger,
        started_at: startedAt,
        finished_at: null,
        reason: null,
        error: null,
        model_id: null,
        training_samples: null,
        silhouette_score: null,
        outlier_threshold: null
    };

    try {
        logger.info('=== Model Training Job Started ===');
        logger.info(`Training trigger: ${trigger}, force: ${force}`);

        // Check if retraining is needed
        let check = { needed: true, reason: 'Forced retraining' };
        if (!force) {
            check = await checkRetrainingNeeded();
        }

        logger.info(`Retraining check: ${check.needed ? 'NEEDED' : 'NOT NEEDED'} - ${check.reason}`);

        if (!check.needed) {
            logger.info('Model training skipped - not needed at this time');
            const skippedResult = {
                success: true,
                status: 'skipped',
                trigger,
                force,
                reason: check.reason,
                started_at: startedAt,
                finished_at: new Date().toISOString()
            };

            latestTrainingRun = {
                ...latestTrainingRun,
                status: 'skipped',
                reason: check.reason,
                finished_at: skippedResult.finished_at
            };

            return skippedResult;
        }

        // Train new model
        const result = await trainModel({ minSamples: getMinTrainingSamples() });

        logger.info(`[OK] Model training completed successfully`);
        logger.info(`Model ID: ${result.model_id}`);
        logger.info(`Training samples: ${result.training_samples}`);
        logger.info(`Silhouette score: ${result.silhouette_score?.toFixed(4)}`);
        logger.info(`Outlier threshold: ${result.outlier_threshold?.toFixed(4)}`);

        const completedResult = {
            success: true,
            status: 'completed',
            trigger,
            force,
            reason: check.reason,
            model_id: result.model_id,
            training_samples: result.training_samples,
            silhouette_score: result.silhouette_score,
            outlier_threshold: result.outlier_threshold,
            started_at: startedAt,
            finished_at: new Date().toISOString()
        };

        latestTrainingRun = {
            ...latestTrainingRun,
            status: 'completed',
            reason: check.reason,
            model_id: result.model_id,
            training_samples: result.training_samples,
            silhouette_score: result.silhouette_score,
            outlier_threshold: result.outlier_threshold,
            finished_at: completedResult.finished_at
        };

        return completedResult;

    } catch (error) {
        logger.error('[ERROR] Model training job failed:', error);

        const failedResult = {
            success: false,
            status: 'failed',
            trigger,
            force,
            error: error.message,
            started_at: startedAt,
            finished_at: new Date().toISOString()
        };

        latestTrainingRun = {
            ...latestTrainingRun,
            status: 'failed',
            error: error.message,
            finished_at: failedResult.finished_at
        };

        // Don't throw - job failure shouldn't crash the server
        return failedResult;
    } finally {
        logger.info('=== Model Training Job Finished ===');
    }
};

/**
 * Schedule model training job
 * Runs every Sunday at 2:00 AM
 * @returns {cron.ScheduledTask}
 */
const scheduleModelTraining = () => {
    const schedule = process.env.ML_MODEL_TRAINING_SCHEDULE || '0 2 * * 0'; // Default: Sunday 2 AM

    logger.info(`Scheduling model training job: ${schedule}`);

    const task = cron.schedule(schedule, async () => {
        await runModelTraining();
    }, {
        scheduled: true,
        timezone: 'Africa/Kigali'
    });

    logger.info('[OK] Model training job scheduled successfully');

    return task;
};

/**
 * Run model training manually (for testing or admin trigger)
 * @returns {Promise<Object>}
 */
const triggerManualTraining = async ({ force = false, wait = true } = {}) => {
    logger.info(`Manual model training triggered (force=${force}, wait=${wait})`);

    if (!wait) {
        runModelTraining({ force, trigger: 'manual' }).catch((error) => {
            logger.error('Background manual model training failed:', error);
        });

        return {
            success: true,
            status: 'started',
            trigger: 'manual',
            force,
            started_at: new Date().toISOString(),
            message: 'Model training started in background'
        };
    }

    return runModelTraining({ force, trigger: 'manual' });
};

const getLatestTrainingRun = () => latestTrainingRun;

/**
 * Bootstrap training data if insufficient samples exist.
 * Extracts features from existing custody records that don't have features yet,
 * then trains the model if enough data is available.
 * After training, runs anomaly detection on recent records to populate demo data.
 */
/**
 * Bootstrap training data if insufficient samples exist.
 * Extracts features from existing custody records that don't have features yet,
 * then runs rules-based anomaly detection on recent records.
 *
 * NOTE: This does NOT train the ML model. Model training is triggered by:
 *   1. System admin via POST /api/ml/train
 *   2. Scheduled cron job (every 3 weeks via checkRetrainingNeeded)
 */
const bootstrapIfNeeded = async () => {
    try {
        const minimumSamples = getMinTrainingSamples();
        const countResult = await query(`
            SELECT COUNT(*) as count FROM ml_training_features
            WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
        `, [], { query_timeout: 120000 });
        const sampleCount = parseInt(countResult.rows[0].count);

        if (sampleCount >= minimumSamples) {
            logger.info(`Bootstrap: ${sampleCount} training features found (minimum ${minimumSamples}), sufficient`);
        } else {
            logger.info(`Bootstrap: Only ${sampleCount} training features found. Extracting from existing custody records...`);

            const { extractAllFeatures } = require('../ml/featureExtractor');

            // Get custody records that don't have features extracted yet
            const custodyRecords = await query(`
                SELECT cr.custody_id, cr.officer_id, cr.firearm_id, cr.unit_id,
                       cr.issued_at, cr.returned_at, cr.custody_type,
                       cr.duration_type,
                       cr.custody_duration_seconds,
                       cr.issue_hour, cr.issue_day_of_week,
                       cr.is_night_issue, cr.is_weekend_issue
                FROM custody_records cr
                WHERE NOT EXISTS (
                    SELECT 1 FROM ml_training_features mf WHERE mf.custody_record_id = cr.custody_id
                )
                AND cr.issued_at IS NOT NULL
                ORDER BY cr.issued_at DESC
                LIMIT 200
            `, [], { query_timeout: 120000 });

            let extracted = 0;
            for (const record of custodyRecords.rows) {
                try {
                    await extractAllFeatures(record);
                    extracted++;
                } catch (e) {
                    // Skip individual extraction failures silently
                }
            }

            const newTotal = sampleCount + extracted;
            logger.info(`Bootstrap: Extracted features for ${extracted} records (total: ${newTotal})`);
        }

        // Run rules-based anomaly detection on recent records (no ML model required)
        await bootstrapAnomalies();
    } catch (error) {
        logger.error('Bootstrap check error:', error);
    }
};

/**
 * Run anomaly detection on recent custody records to populate the anomalies table.
 * Only runs if no anomalies exist yet (first-time setup / demo preparation).
 * Uses rules engine + statistical detection — ML model is NOT required.
 */
const bootstrapAnomalies = async () => {
    try {
        // Check if anomalies already exist
        const anomalyCount = await query(`SELECT COUNT(*) as count FROM anomalies`, [], { query_timeout: 120000 });
        const existingAnomalies = parseInt(anomalyCount.rows[0].count);

        if (existingAnomalies > 0) {
            logger.info(`Bootstrap anomalies: ${existingAnomalies} anomalies already exist, skipping`);
            return;
        }

        logger.info('Bootstrap anomalies: No anomalies found, scanning recent custody records with rules engine...');

        const { detectAnomaly } = require('../ml/anomalyDetector');

        // Get recent custody records to scan
        const records = await query(`
            SELECT cr.custody_id, cr.officer_id, cr.firearm_id, cr.unit_id,
                   cr.issued_at, cr.returned_at, cr.custody_type,
                   cr.duration_type,
                   cr.custody_duration_seconds,
                   cr.issue_hour, cr.issue_day_of_week,
                   cr.is_night_issue, cr.is_weekend_issue
            FROM custody_records cr
            WHERE cr.issued_at IS NOT NULL
            ORDER BY cr.issued_at DESC
            LIMIT 100
        `, [], { query_timeout: 120000 });

        let detected = 0;
        for (const record of records.rows) {
            try {
                const result = await detectAnomaly(record);
                if (result.is_anomaly) {
                    detected++;
                }
            } catch (e) {
                // Skip individual detection failures
            }
        }

        logger.info(`Bootstrap anomalies: Scanned ${records.rows.length} records, detected ${detected} anomalies`);
    } catch (error) {
        logger.error('Bootstrap anomalies error:', error);
    }
};

module.exports = {
    scheduleModelTraining,
    runModelTraining,
    triggerManualTraining,
    getLatestTrainingRun,
    bootstrapIfNeeded
};
