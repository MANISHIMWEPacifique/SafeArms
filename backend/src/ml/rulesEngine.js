const { query } = require('../config/database');
const logger = require('../utils/logger');

/**
 * Rules Engine for Anomaly Detection
 *
 * Implements hard-coded, shift-aware thresholds from the SafeArms operational policy.
 * These rules fire immediately and consistently — no ML model required.
 *
 * The rules catch what you can define:
 *   - Excessive daily transfers
 *   - Custody duration outside shift bounds
 *   - Officer firearm rotation beyond limits
 *   - Elevated station loss/overdue rates
 *   - Repeated short-term assignments
 *
 * The K-Means model (when trained) catches what you can't define:
 *   - Unusual combinations that look normal individually
 *   - Station-level behavioral drift
 *   - Cross-feature anomalies
 *   - Gradual pattern changes
 */

// ── Shift-aware constants ──────────────────────────────────────────

const DURATION_TYPE_HOURS = {
    '6_hours': 6,
    '8_hours': 8,
    '12_hours': 12,
    '1_day': 24
};

// Custody duration bounds per shift type (with ±1h tolerance baked in)
const SHIFT_DURATION_BOUNDS = {
    '6_hours':  { minHours: 2, maxHours: 8 },
    '8_hours':  { minHours: 2, maxHours: 10 },
    '12_hours': { minHours: 2, maxHours: 14 },
    '1_day':    { minHours: 2, maxHours: 26 }
};

// "Short-term" threshold per shift type (half the shift)
const SHORT_TERM_HOURS = {
    '6_hours': 3,
    '8_hours': 4,
    '12_hours': 6,
    '1_day': 12
};

// ── Individual Rule Functions ──────────────────────────────────────

/**
 * Rule 1: Daily Firearm Transfer Frequency
 * Normal: 0–4 per day. Unusual: more than 6 per day.
 * Applies across all shift types.
 *
 * Counts how many times ONE firearm is issued in a single day at the station level.
 */
const checkDailyTransferFrequency = async (custodyRecord) => {
    const eventTime = custodyRecord.issued_at || new Date().toISOString();

    const result = await query(`
        SELECT COUNT(*) as today_count
        FROM custody_records
        WHERE firearm_id = $1
          AND issued_at::date = $2::date
    `, [custodyRecord.firearm_id, eventTime]);

    const todayCount = parseInt(result.rows[0].today_count);

    if (todayCount <= 6) return null;

    const score = Math.min(0.4 + (todayCount - 6) * 0.075, 1.0);
    const severity = todayCount > 10 ? 'high' : 'medium';

    return {
        rule_id: 'daily_transfer_frequency',
        triggered: true,
        anomaly_type: 'excessive_daily_transfers',
        severity,
        score,
        description: `Firearm transferred ${todayCount} times today (normal: 0-4, threshold: >6)`,
        context: { today_count: todayCount, firearm_id: custodyRecord.firearm_id }
    };
};

/**
 * Rule 2: Custody Duration vs Assigned Shift
 * Expected custody matches shift: 6h, 8h, or 12h (±1h tolerance).
 * Flag if less than 2h or more than shift + 2h.
 *
 * Only evaluates when the record has been returned (actual duration known).
 */
const checkCustodyDurationVsShift = async (custodyRecord) => {
    if (!custodyRecord.returned_at || !custodyRecord.duration_type) return null;

    const bounds = SHIFT_DURATION_BOUNDS[custodyRecord.duration_type];
    if (!bounds) return null;

    const durationSeconds = custodyRecord.custody_duration_seconds
        || (new Date(custodyRecord.returned_at) - new Date(custodyRecord.issued_at)) / 1000;
    const actualHours = durationSeconds / 3600;

    if (actualHours >= bounds.minHours && actualHours <= bounds.maxHours) return null;

    const isTooShort = actualHours < bounds.minHours;
    const shiftHours = DURATION_TYPE_HOURS[custodyRecord.duration_type];

    let severity, score;
    if (isTooShort) {
        severity = actualHours < 1 ? 'high' : 'medium';
        score = Math.min(0.5 + (bounds.minHours - actualHours) * 0.25, 1.0);
    } else {
        const overHours = actualHours - bounds.maxHours;
        severity = overHours > 4 ? 'high' : 'medium';
        score = Math.min(0.4 + overHours * 0.1, 1.0);
    }

    return {
        rule_id: 'custody_duration_shift',
        triggered: true,
        anomaly_type: isTooShort ? 'short_custody_duration' : 'extended_custody_duration',
        severity,
        score,
        description: `Custody lasted ${actualHours.toFixed(1)}h for ${shiftHours}h shift (expected: ${bounds.minHours}-${bounds.maxHours}h)`,
        context: {
            actual_hours: parseFloat(actualHours.toFixed(2)),
            shift_hours: shiftHours,
            duration_type: custodyRecord.duration_type,
            bounds
        }
    };
};

/**
 * Rule 3: Officer Firearm Rotation Rate
 * Normal: 1–2 firearms per shift. Unusual: more than 3 per shift or more than 4 per day.
 *
 * Counts distinct firearms issued to one officer within the shift window and per day.
 */
const checkOfficerFirearmRotation = async (custodyRecord) => {
    const shiftHours = DURATION_TYPE_HOURS[custodyRecord.duration_type] || 8;
    const eventTime = custodyRecord.issued_at || new Date().toISOString();

    // Count distinct firearms in current shift window
    const shiftResult = await query(`
        SELECT COUNT(DISTINCT firearm_id) as shift_firearms
        FROM custody_records
        WHERE officer_id = $1
        AND issued_at >= $2::timestamp - make_interval(hours => $3)
        AND issued_at <= $2::timestamp
    `, [custodyRecord.officer_id, eventTime, shiftHours]);

    // Count distinct firearms today
    const dailyResult = await query(`
        SELECT COUNT(DISTINCT firearm_id) as daily_firearms
        FROM custody_records
        WHERE officer_id = $1
        AND issued_at::date = $2::date
    `, [custodyRecord.officer_id, eventTime]);

    const shiftCount = parseInt(shiftResult.rows[0].shift_firearms);
    const dailyCount = parseInt(dailyResult.rows[0].daily_firearms);

    if (shiftCount <= 3 && dailyCount <= 4) return null;

    const isShiftViolation = shiftCount > 3;
    const worst = Math.max(shiftCount - 3, dailyCount - 4);
    const score = Math.min(0.4 + worst * 0.15, 1.0);
    const severity = (shiftCount > 5 || dailyCount > 6) ? 'high' : 'medium';

    return {
        rule_id: 'officer_rotation_rate',
        triggered: true,
        anomaly_type: 'excessive_officer_rotation',
        severity,
        score,
        description: isShiftViolation
            ? `Officer handled ${shiftCount} different firearms in ${shiftHours}h shift (normal: 1-2, threshold: >3)`
            : `Officer handled ${dailyCount} different firearms today (threshold: >4/day)`,
        context: {
            shift_firearms: shiftCount,
            daily_firearms: dailyCount,
            shift_hours: shiftHours
        }
    };
};

/**
 * Rule 4: Station Loss/Overdue Report Rate
 * Normal: 0–1 per year. Unusual: more than 2 per year.
 * Not shift-dependent.
 *
 * Counts high-severity overdue anomalies and loss reports for the station in the past year.
 */
const checkStationLossRate = async (custodyRecord) => {
    const eventTime = custodyRecord.issued_at || new Date().toISOString();

    // Count loss reports
    const lossResult = await query(`
        SELECT COUNT(*) as loss_count
        FROM loss_reports
        WHERE unit_id = $1
          AND loss_date >= ($2::date - INTERVAL '1 year')
    `, [custodyRecord.unit_id, eventTime]);

    const lossCount = parseInt(lossResult.rows[0].loss_count);

    if (lossCount <= 2) return null;

    const severity = lossCount > 4 ? 'high' : 'medium';
    const score = Math.min(0.5 + (lossCount - 2) * 0.15, 1.0);

    return {
        rule_id: 'station_loss_rate',
        triggered: true,
        anomaly_type: 'elevated_station_loss_rate',
        severity,
        score,
        description: `Station has ${lossCount} loss reports in the past year (normal: 0-1, threshold: >2)`,
        context: { loss_count: lossCount, unit_id: custodyRecord.unit_id }
    };
};

/**
 * Rule 5: Consecutive Short-Term Assignments
 * Normal: 0–1 per shift. Unusual: more than 3 per shift, all under half the assigned shift.
 * Threshold scales with shift length: <3h for 6h, <4h for 8h, <6h for 12h.
 *
 * Counts returned custody records for the same officer within the shift window
 * that lasted less than half the shift.
 */
const checkShortTermAssignments = async (custodyRecord) => {
    const shiftHours = DURATION_TYPE_HOURS[custodyRecord.duration_type] || 8;
    const shortThresholdHours = SHORT_TERM_HOURS[custodyRecord.duration_type] || 4;
    const shortThresholdSeconds = shortThresholdHours * 3600;
    const eventTime = custodyRecord.issued_at || new Date().toISOString();

    const result = await query(`
        SELECT COUNT(*) as short_count
        FROM custody_records
        WHERE officer_id = $1
          AND issued_at >= $2::timestamp - make_interval(hours => $3)
          AND issued_at <= $2::timestamp
          AND returned_at IS NOT NULL
          AND custody_duration_seconds IS NOT NULL
          AND custody_duration_seconds < $4
    `, [custodyRecord.officer_id, eventTime, shiftHours, shortThresholdSeconds]);

    const shortCount = parseInt(result.rows[0].short_count);

    if (shortCount <= 3) return null;

    const severity = shortCount > 5 ? 'high' : 'medium';
    const score = Math.min(0.4 + (shortCount - 3) * 0.15, 1.0);

    return {
        rule_id: 'short_term_assignments',
        triggered: true,
        anomaly_type: 'excessive_short_assignments',
        severity,
        score,
        description: `Officer has ${shortCount} short-term assignments (under ${shortThresholdHours}h) in ${shiftHours}h window (normal: 0-1, threshold: >3)`,
        context: {
            short_count: shortCount,
            threshold_hours: shortThresholdHours,
            shift_hours: shiftHours
        }
    };
};

// ── Main evaluator ─────────────────────────────────────────────────

/**
 * Evaluate all Section 4 rules against a custody event.
 *
 * @param {Object} custodyRecord - The custody record (custody_id, officer_id, firearm_id, etc.)
 * @param {Object} features - Pre-extracted features from featureExtractor (used for context only)
 * @returns {Promise<Object>} { rules_triggered, aggregate_score, rule_count, highest_severity }
 */
const evaluateRules = async (custodyRecord, features) => {
    const ruleChecks = [
        checkDailyTransferFrequency,
        checkCustodyDurationVsShift,
        checkOfficerFirearmRotation,
        checkStationLossRate,
        checkShortTermAssignments
    ];

    const results = [];

    for (const check of ruleChecks) {
        try {
            const result = await check(custodyRecord);
            if (result && result.triggered) {
                results.push(result);
            }
        } catch (error) {
            logger.error(`Rule check ${check.name} failed:`, error);
            // Individual rule failure does not block others
        }
    }

    // Aggregate: highest individual score + small bonus per additional trigger
    const aggregateScore = results.length > 0
        ? Math.min(
            results.reduce((max, r) => Math.max(max, r.score), 0) +
            (results.length - 1) * 0.05,
            1.0
        )
        : 0;

    const severityOrder = { low: 1, medium: 2, high: 3, critical: 4 };
    const highestSeverity = results.reduce((max, r) =>
        (severityOrder[r.severity] || 0) > (severityOrder[max] || 0) ? r.severity : max,
        'low'
    );

    return {
        rules_triggered: results,
        aggregate_score: aggregateScore,
        rule_count: results.length,
        highest_severity: highestSeverity
    };
};

module.exports = {
    evaluateRules,
    SHIFT_DURATION_BOUNDS,
    SHORT_TERM_HOURS,
    DURATION_TYPE_HOURS
};
