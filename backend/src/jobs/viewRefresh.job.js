const cron = require('node-cron');
const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Materialized View Refresh Job
 * Refreshes officer_behavior_profile and firearm_usage_profile views
 */

/**
 * Refresh materialized views
 * @returns {Promise<void>}
 */
const refreshViews = async () => {
    try {
        logger.info('=== Materialized View Refresh Started ===');

        const startTime = Date.now();

        // Refresh officer_behavior_profile
        logger.info('Refreshing officer_behavior_profile...');
        await query('REFRESH MATERIALIZED VIEW CONCURRENTLY officer_behavior_profile');
        logger.info('✅ officer_behavior_profile refreshed');

        // Refresh firearm_usage_profile
        logger.info('Refreshing firearm_usage_profile...');
        await query('REFRESH MATERIALIZED VIEW CONCURRENTLY firearm_usage_profile');
        logger.info('✅ firearm_usage_profile refreshed');

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        logger.info(`✅ All materialized views refreshed in ${duration}s`);

    } catch (error) {
        logger.error('❌ Materialized view refresh failed:', error);
        // Don't throw - job failure shouldn't crash the server
    } finally {
        logger.info('=== Materialized View Refresh Finished ===');
    }
};

/**
 * Schedule materialized view refresh
 * Runs every 6 hours
 * @returns {cron.ScheduledTask}
 */
const scheduleViewRefresh = () => {
    const schedule = process.env.ML_VIEW_REFRESH_SCHEDULE || '0 */6 * * *'; // Default: Every 6 hours

    logger.info(`Scheduling materialized view refresh: ${schedule}`);

    const task = cron.schedule(schedule, async () => {
        await refreshViews();
    }, {
        scheduled: true,
        timezone: 'Africa/Kigali'
    });

    logger.info('✅ Materialized view refresh job scheduled successfully');

    return task;
};

/**
 * Analyze database tables for query optimization
 * @returns {Promise<void>}
 */
const analyzeDatabase = async () => {
    try {
        logger.info('Running database analysis...');

        // Analyze key tables
        const tables = [
            'custody_records',
            'firearms',
            'officers',
            'anomalies',
            'ml_training_features'
        ];

        for (const table of tables) {
            await query(`ANALYZE ${table}`);
            logger.info(`✅ Analyzed table: ${table}`);
        }

        logger.info('✅ Database analysis complete');
    } catch (error) {
        logger.error('Database analysis error:', error);
    }
};

/**
 * Run view refresh manually (for testing or admin trigger)
 * @returns {Promise<Object>}
 */
const triggerManualRefresh = async () => {
    logger.info('Manual view refresh triggered');
    await refreshViews();
    await analyzeDatabase();
    return { success: true, message: 'Views refreshed and database analyzed' };
};

module.exports = {
    scheduleViewRefresh,
    refreshViews,
    analyzeDatabase,
    triggerManualRefresh
};
