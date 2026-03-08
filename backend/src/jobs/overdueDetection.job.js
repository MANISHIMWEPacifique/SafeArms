const cron = require('node-cron');
const { query } = require('../config/database');
const { recordOverdueAnomaly } = require('../ml/anomalyDetector');
const { sendAnomalyAlert } = require('../services/email.service');
const logger = require('../utils/logger');

/**
 * Overdue Custody Detection Job
 *
 * Periodically scans for custody records that have exceeded their expected_return_date
 * and generates real anomaly alerts based on how overdue they are.
 *
 * OVERDUE SEVERITY (based on hours overdue):
 * - low:      1-24 hours overdue (first day)
 * - medium:   24-72 hours overdue (1-3 days)
 * - high:     72-168 hours overdue (3-7 days)
 * - critical: >168 hours overdue (>7 days)
 *
 * The job avoids creating duplicate anomalies for the same custody record
 * by checking if an overdue anomaly already exists. If a record becomes
 * MORE overdue (severity escalation), a new anomaly is created.
 */

/**
 * Scan for overdue custody records and generate anomalies
 * @returns {Promise<Object>} Scan results
 */
const scanOverdueCustody = async () => {
    try {
        logger.info('=== Overdue Custody Detection Started ===');
        const startTime = Date.now();

        // Find all active custody records past their expected return date
        // Uses the idx_custody_overdue_check index
        const overdueRecords = await query(`
            SELECT
                cr.custody_id,
                cr.firearm_id,
                cr.officer_id,
                cr.unit_id,
                cr.custody_type,
                cr.duration_type,
                cr.issued_at,
                cr.expected_return_date,
                cr.issued_by,
                cr.notes,
                EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - cr.expected_return_date)) / 3600.0 AS hours_overdue,
                f.serial_number,
                f.manufacturer,
                f.model AS firearm_model,
                o.full_name AS officer_name,
                o.rank AS officer_rank,
                u.unit_name
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN officers o ON cr.officer_id = o.officer_id
            JOIN units u ON cr.unit_id = u.unit_id
            WHERE cr.returned_at IS NULL
              AND cr.expected_return_date IS NOT NULL
              AND cr.expected_return_date < CURRENT_TIMESTAMP
            ORDER BY (CURRENT_TIMESTAMP - cr.expected_return_date) DESC
        `);

        if (overdueRecords.rows.length === 0) {
            logger.info('No overdue custody records found');
            return { scanned: 0, anomalies_created: 0, escalated: 0 };
        }

        logger.info(`Found ${overdueRecords.rows.length} overdue custody record(s)`);

        let anomaliesCreated = 0;
        let escalated = 0;
        let skipped = 0;

        for (const record of overdueRecords.rows) {
            const hoursOverdue = parseFloat(record.hours_overdue);
            const newSeverity = classifyOverdueSeverity(hoursOverdue);

            // Check if an anomaly already exists for this custody record with overdue type
            const existingAnomaly = await query(`
                SELECT anomaly_id, severity, anomaly_score
                FROM anomalies
                WHERE custody_record_id = $1
                  AND anomaly_type LIKE 'overdue_return%'
                ORDER BY detected_at DESC
                LIMIT 1
            `, [record.custody_id]);

            const existingRecord = existingAnomaly.rows[0];

            // Skip if anomaly already exists at the same or higher severity
            if (existingRecord) {
                const severityOrder = { low: 1, medium: 2, high: 3, critical: 4 };
                if (severityOrder[existingRecord.severity] >= severityOrder[newSeverity]) {
                    skipped++;
                    continue;
                }
                // Severity escalation needed
                escalated++;
                logger.info(`Escalating overdue anomaly for ${record.custody_id}: ${existingRecord.severity} -> ${newSeverity} (${hoursOverdue.toFixed(1)}h overdue)`);
            }

            // Create new anomaly
            try {
                const anomalyResult = await recordOverdueAnomaly(record, hoursOverdue, newSeverity);
                anomaliesCreated++;

                // Send alerts for high/critical overdue
                if (newSeverity === 'high' || newSeverity === 'critical') {
                    await sendOverdueAlerts(record, hoursOverdue, newSeverity, anomalyResult);
                }
            } catch (err) {
                logger.error(`Failed to create overdue anomaly for ${record.custody_id}:`, err);
            }
        }

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        logger.info(`Overdue scan complete in ${duration}s: ${overdueRecords.rows.length} scanned, ${anomaliesCreated} anomalies created, ${escalated} escalated, ${skipped} skipped`);

        return {
            scanned: overdueRecords.rows.length,
            anomalies_created: anomaliesCreated,
            escalated,
            skipped
        };
    } catch (error) {
        logger.error('[ERROR] Overdue custody detection failed:', error);
        return { scanned: 0, anomalies_created: 0, escalated: 0, error: error.message };
    } finally {
        logger.info('=== Overdue Custody Detection Finished ===');
    }
};

/**
 * Classify overdue severity based on hours overdue
 * @param {number} hoursOverdue
 * @returns {string} severity level
 */
const classifyOverdueSeverity = (hoursOverdue) => {
    if (hoursOverdue >= 168) return 'critical';  // > 7 days
    if (hoursOverdue >= 72) return 'high';        // 3-7 days
    if (hoursOverdue >= 24) return 'medium';      // 1-3 days
    return 'low';                                  // < 1 day
};

/**
 * Calculate anomaly score based on overdue hours
 * Maps overdue duration to a 0-1 score
 * @param {number} hoursOverdue
 * @returns {number} score between 0 and 1
 */
const calculateOverdueScore = (hoursOverdue) => {
    // Score scales with how overdue it is:
    // 1h -> ~0.35 (just above anomaly threshold)
    // 24h -> ~0.55
    // 72h -> ~0.75
    // 168h (7 days) -> ~0.90
    // 336h (14 days) -> ~0.97
    // Uses logarithmic scaling so it increases rapidly at first then plateaus
    const score = Math.min(0.35 + 0.65 * (1 - Math.exp(-hoursOverdue / 120)), 1.0);
    return parseFloat(score.toFixed(3));
};

/**
 * Send email alerts for overdue custody
 * @param {Object} record - Overdue custody record
 * @param {number} hoursOverdue
 * @param {string} severity
 * @param {Object} anomalyResult - Created anomaly record
 */
const sendOverdueAlerts = async (record, hoursOverdue, severity, anomalyResult) => {
    try {
        const daysOverdue = Math.floor(hoursOverdue / 24);
        const remainingHours = Math.floor(hoursOverdue % 24);

        const alertContext = {
            anomaly_id: anomalyResult?.anomaly_id || 'UNKNOWN',
            severity,
            severity_description: severity === 'critical'
                ? 'CRITICAL: Firearm overdue more than 7 days - immediate action required'
                : 'HIGH: Firearm overdue more than 3 days - review within 24 hours',
            anomaly_score: calculateOverdueScore(hoursOverdue),
            anomaly_type: 'overdue_return',
            is_mandatory_review: true,
            firearm: `${record.serial_number} ${record.manufacturer} ${record.firearm_model}`,
            officer: record.officer_name,
            unit: record.unit_name,
            contributing_factors: [
                `Firearm overdue by ${daysOverdue} day(s) and ${remainingHours} hour(s)`,
                `Expected return: ${new Date(record.expected_return_date).toLocaleString()}`,
                `Issued: ${new Date(record.issued_at).toLocaleString()}`
            ]
        };

        // Notify HQ Commanders
        const hqCommanders = await query(`
            SELECT user_id, email, full_name
            FROM users
            WHERE role = 'hq_firearm_commander' AND is_active = true
        `);

        const notifiedUsers = [];
        for (const commander of hqCommanders.rows) {
            try {
                await sendAnomalyAlert(commander.email, commander.full_name, alertContext);
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send overdue alert to ${commander.email}:`, err);
            }
        }

        // Notify Station Commander for the relevant unit
        const stationCommander = await query(`
            SELECT user_id, email, full_name
            FROM users
            WHERE role = 'station_commander' AND unit_id = $1 AND is_active = true
        `, [record.unit_id]);

        if (stationCommander.rows.length > 0) {
            const commander = stationCommander.rows[0];
            try {
                await sendAnomalyAlert(commander.email, commander.full_name, alertContext);
                notifiedUsers.push(commander.user_id);
            } catch (err) {
                logger.error(`Failed to send overdue alert to station commander:`, err);
            }
        }

        // Update anomaly record with notification info
        if (anomalyResult?.anomaly_id) {
            await query(`
                UPDATE anomalies
                SET auto_notification_sent = true,
                    notification_sent_at = CURRENT_TIMESTAMP,
                    notified_users = $1
                WHERE anomaly_id = $2
            `, [JSON.stringify(notifiedUsers), anomalyResult.anomaly_id]);
        }

        logger.info(`Overdue alerts sent to ${notifiedUsers.length} users for ${record.custody_id}`);
    } catch (error) {
        logger.error('Send overdue alerts error:', error);
    }
};

/**
 * Schedule overdue detection job
 * Runs every hour by default to catch overdue records promptly
 * @returns {cron.ScheduledTask}
 */
const scheduleOverdueDetection = () => {
    const schedule = process.env.OVERDUE_DETECTION_SCHEDULE || '0 * * * *'; // Default: every hour

    logger.info(`Scheduling overdue custody detection: ${schedule}`);

    const task = cron.schedule(schedule, async () => {
        await scanOverdueCustody();
    }, {
        scheduled: true,
        timezone: 'Africa/Kigali'
    });

    logger.info('[OK] Overdue custody detection job scheduled successfully');

    return task;
};

/**
 * Run overdue detection manually (for testing or admin trigger)
 * @returns {Promise<Object>}
 */
const triggerManualOverdueScan = async () => {
    logger.info('Manual overdue custody scan triggered');
    const result = await scanOverdueCustody();
    return { success: true, message: 'Overdue scan completed', ...result };
};

module.exports = {
    scheduleOverdueDetection,
    scanOverdueCustody,
    triggerManualOverdueScan,
    classifyOverdueSeverity,
    calculateOverdueScore
};
