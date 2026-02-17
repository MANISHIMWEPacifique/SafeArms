const cron = require('node-cron');
const { trainModel, checkRetrainingNeeded } = require('../ml/modelTrainer');
const logger = require('../utils/logger');

/**
 * Model Training Background Job
 * Automatically trains ML models on a schedule
 */

/**
 * Run model training
 * @returns {Promise<void>}
 */
const runModelTraining = async () => {
    try {
        logger.info('=== Model Training Job Started ===');

        // Check if retraining is needed
        const check = await checkRetrainingNeeded();

        logger.info(`Retraining check: ${check.needed ? 'NEEDED' : 'NOT NEEDED'} - ${check.reason}`);

        if (!check.needed) {
            logger.info('Model training skipped - not needed at this time');
            return;
        }

        // Train new model
        const result = await trainModel();

        logger.info(`[OK] Model training completed successfully`);
        logger.info(`Model ID: ${result.model_id}`);
        logger.info(`Training samples: ${result.training_samples}`);
        logger.info(`Silhouette score: ${result.silhouette_score?.toFixed(4)}`);
        logger.info(`Outlier threshold: ${result.outlier_threshold?.toFixed(4)}`);

    } catch (error) {
        logger.error('[ERROR] Model training job failed:', error);
        // Don't throw - job failure shouldn't crash the server
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
const triggerManualTraining = async () => {
    logger.info('Manual model training triggered');
    await runModelTraining();
    return { success: true, message: 'Model training completed' };
};

module.exports = {
    scheduleModelTraining,
    runModelTraining,
    triggerManualTraining
};
