const cron = require('node-cron');

const { query } = require('../config/database');
const logger = require('../utils/logger');
const {
    expireStaleRequests,
    getCustodyVerificationPolicy,
    recordVerificationEvent
} = require('../services/officerVerification.service');

const toInt = (value, fallback) => {
    const parsed = Number.parseInt(String(value), 10);
    if (!Number.isFinite(parsed)) {
        return fallback;
    }
    return parsed;
};

const cleanupExpiredVerificationArtifacts = async () => {
    const policy = await getCustodyVerificationPolicy();
    const retentionDays = Math.max(7, Math.min(365, policy.cleanupRetentionDays || 30));

    const expiryUpdate = await expireStaleRequests();

    const pruneEventsResult = await query(
        `DELETE FROM officer_verification_events
         WHERE created_at < CURRENT_TIMESTAMP - ($1::TEXT || ' days')::INTERVAL
           AND event_type IN (
             'REQUEST_EXPIRED',
             'INVALID_CHALLENGE',
             'REPLAY_BLOCKED',
             'REQUEST_REUSED'
           )`,
        [retentionDays]
    );

    const staleRequestsResult = await query(
        `UPDATE officer_verification_requests
         SET decision = CASE
                WHEN decision = 'pending' THEN 'expired'
                ELSE decision
             END,
             updated_at = CURRENT_TIMESTAMP
         WHERE created_at < CURRENT_TIMESTAMP - ($1::TEXT || ' days')::INTERVAL
           AND consumed_at IS NULL
           AND decision IN ('pending', 'expired', 'cancelled')`,
        [retentionDays]
    );

    logger.info(
        `[OfficerVerification] cleanup complete | retention_days=${retentionDays} | ` +
            `expired_now=${expiryUpdate.expiredCount} | pruned_events=${pruneEventsResult.rowCount} | ` +
            `stale_requests_updated=${staleRequestsResult.rowCount}`
    );

    return {
        retention_days: retentionDays,
        expired_now: expiryUpdate.expiredCount,
        pruned_events: pruneEventsResult.rowCount,
        stale_requests_updated: staleRequestsResult.rowCount
    };
};

const collectVerificationMetrics = async () => {
    const policy = await getCustodyVerificationPolicy();
    const days = Math.max(1, Math.min(60, policy.metricsWindowDays || 14));

    const metricsResult = await query(
        `WITH scoped AS (
            SELECT *
            FROM officer_verification_requests
            WHERE created_at >= CURRENT_TIMESTAMP - ($1::TEXT || ' days')::INTERVAL
        )
        SELECT
            COUNT(*)::INT AS total,
            COUNT(*) FILTER (WHERE decision = 'approved')::INT AS approved,
            COUNT(*) FILTER (WHERE decision = 'rejected')::INT AS rejected,
            COUNT(*) FILTER (WHERE decision = 'expired')::INT AS expired,
            COUNT(*) FILTER (WHERE decision = 'pending' AND expires_at > CURRENT_TIMESTAMP)::INT AS pending,
            COUNT(*) FILTER (WHERE consumed_at IS NOT NULL)::INT AS consumed,
            ROUND(
                AVG(
                    CASE
                        WHEN decided_at IS NOT NULL THEN EXTRACT(EPOCH FROM (decided_at - created_at))
                        ELSE NULL
                    END
                )
            )::INT AS avg_decision_latency_seconds
        FROM scoped`,
        [days]
    );

    const metrics = metricsResult.rows[0] || {};
    await recordVerificationEvent({
        eventType: 'REQUEST_DELIVERED',
        reason: 'Periodic metrics snapshot',
        metadata: {
            metrics_window_days: days,
            metrics
        }
    });

    logger.info(
        `[OfficerVerification] metrics snapshot | window_days=${days} | total=${metrics.total || 0} | ` +
            `approved=${metrics.approved || 0} | rejected=${metrics.rejected || 0} | ` +
            `expired=${metrics.expired || 0} | pending=${metrics.pending || 0}`
    );

    return {
        metrics_window_days: days,
        ...metrics
    };
};

const runVerificationOpsCycle = async () => {
    const cleanup = await cleanupExpiredVerificationArtifacts();
    const metrics = await collectVerificationMetrics();

    return {
        cleanup,
        metrics
    };
};

const scheduleOfficerVerificationOps = () => {
    const schedule = process.env.OFFICER_VERIFICATION_OPS_SCHEDULE || '*/15 * * * *';
    logger.info(`Scheduling officer verification ops job: ${schedule}`);

    const task = cron.schedule(
        schedule,
        async () => {
            try {
                await runVerificationOpsCycle();
            } catch (error) {
                logger.error('[OfficerVerification] ops cycle failed:', error);
            }
        },
        {
            scheduled: true,
            timezone: 'Africa/Kigali'
        }
    );

    logger.info('[OK] Officer verification ops job scheduled successfully');
    return task;
};

const triggerManualVerificationOps = async () => {
    const result = await runVerificationOpsCycle();
    return {
        success: true,
        message: 'Officer verification operations cycle completed',
        data: result
    };
};

module.exports = {
    scheduleOfficerVerificationOps,
    triggerManualVerificationOps,
    cleanupExpiredVerificationArtifacts,
    collectVerificationMetrics,
    runVerificationOpsCycle
};