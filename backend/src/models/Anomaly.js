const { query, withTransaction } = require('../config/database');
const { parseDecimalFields } = require('../utils/helpers');

const ANOMALY_DECIMAL_FIELDS = ['anomaly_score', 'confidence_level', 'avg_score'];
const toBoolean = (value) => value === true || value === 'true';
const INVESTIGATION_ID_LOCK_KEY = 947214;

const getExecutor = (client) => (
    client && typeof client.query === 'function'
        ? client
        : { query }
);

const createInvestigationRecord = async ({
    anomalyId,
    userId,
    findings,
    actionTaken,
    outcome = 'needs_further_review',
    client
}) => {
    const executor = getExecutor(client);

    if (client) {
        await executor.query('SELECT pg_advisory_xact_lock($1)', [INVESTIGATION_ID_LOCK_KEY]);
    }

    const idResult = await executor.query(`
        SELECT COALESCE(MAX(CAST(SUBSTRING(investigation_id FROM 5) AS INTEGER)), 0) as max_num
        FROM anomaly_investigations WHERE investigation_id ~ '^INV-[0-9]+$'
    `);
    const nextNum = parseInt(idResult.rows[0].max_num) + 1;
    const investigationId = `INV-${String(nextNum).padStart(3, '0')}`;

    await executor.query(`
        INSERT INTO anomaly_investigations (investigation_id, anomaly_id, investigator_id, findings, action_taken, outcome)
        VALUES ($1, $2, $3, $4, $5, $6)
    `, [investigationId, anomalyId, userId, findings, actionTaken, outcome]);
};

const createAnomalyAuditLog = async ({ userId, anomalyId, actionType, payload = {}, client }) => {
    const executor = getExecutor(client);
    const logId = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;

    await executor.query(`
        INSERT INTO audit_logs (log_id, user_id, action_type, table_name, record_id, new_values)
        VALUES ($1, $2, $3, 'anomalies', $4, $5)
    `, [logId, userId, actionType, anomalyId, JSON.stringify(payload)]);
};

/**
 * Anomaly Model - EVENT-BASED Anomaly Records
 * 
 * IMPORTANT: This system evaluates EVENTS, not people.
 * - Anomalies represent custody events that require human review
 * - Severity indicates REVIEW URGENCY, not wrongdoing
 * - Cross-unit transfers always trigger mandatory review
 * 
 * SEVERITY LEVELS (Review Urgency):
 * - critical: Immediate review required (same day)
 * - high: Review within 24 hours
 * - medium: Review within 72 hours
 * - low: Standard review queue
 */

const Anomaly = {
    async findById(anomalyId) {
        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name, o.rank,
             u.unit_name,
             CASE 
               WHEN a.is_mandatory_review THEN 'Policy-mandated review'
               ELSE NULL
             END as review_reason
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      WHERE a.anomaly_id = $1
    `, [anomalyId]);
        return parseDecimalFields(result.rows[0], ANOMALY_DECIMAL_FIELDS);
    },

    async findAll(filters = {}) {
        const {
            severity,
            status,
            unit_id,
            anomaly_type,
            is_mandatory_review,
            include_removed,
            limit = 100,
            offset = 0
        } = filters;
        const includeRemoved = toBoolean(include_removed);
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (severity) {
            pCount++;
            where += ` AND a.severity = $${pCount}`;
            params.push(severity);
        }

        if (status) {
            pCount++;
            where += ` AND a.status = $${pCount}`;
            params.push(status);
        }

        if (unit_id) {
            pCount++;
            where += ` AND a.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        if (anomaly_type) {
            pCount++;
            where += ` AND a.anomaly_type = $${pCount}`;
            params.push(anomaly_type);
        }

        if (is_mandatory_review !== undefined) {
            pCount++;
            where += ` AND a.is_mandatory_review = $${pCount}`;
            params.push(is_mandatory_review);
        }

        if (!includeRemoved) {
            where += ` AND COALESCE(a.removed_from_dashboard, false) = false`;
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name, o.rank,
             u.unit_name
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      ${where}
      ORDER BY 
        CASE a.severity 
          WHEN 'critical' THEN 1 
          WHEN 'high' THEN 2 
          WHEN 'medium' THEN 3 
          ELSE 4 
        END,
        a.detected_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    },

    async update(anomalyId, updates) {
        const ALLOWED_FIELDS = [
            'status', 'investigated_by', 'investigation_notes',
            'resolution_date'
        ];

        const fields = [];
        const values = [];
        let pCount = 0;

        Object.entries(updates).forEach(([key, value]) => {
            if (value !== undefined && ALLOWED_FIELDS.includes(key)) {
                pCount++;
                fields.push(`${key} = $${pCount}`);
                values.push(value);
            }
        });

        if (fields.length === 0) return null;

        pCount++;
        values.push(anomalyId);

        const result = await query(
            `UPDATE anomalies SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
       WHERE anomaly_id = $${pCount} RETURNING *`,
            values
        );
        return parseDecimalFields(result.rows[0], ANOMALY_DECIMAL_FIELDS);
    },

    async investigate(anomalyId, userId, notes) {
        const investigationNotes = notes || 'Investigation started';
        const anomalyRow = await withTransaction(async (client) => {
            const anomalyResult = await client.query(`
                UPDATE anomalies
                SET status = 'investigating',
                    investigated_by = COALESCE(investigated_by, $2),
                    investigation_notes = CASE
                        WHEN investigation_notes IS NOT NULL AND investigation_notes != ''
                        THEN investigation_notes || E'\n' || $3
                        ELSE $3
                    END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE anomaly_id = $1
                RETURNING *
            `, [anomalyId, userId, investigationNotes]);

            if (anomalyResult.rows.length === 0) return null;

            await createInvestigationRecord({
                anomalyId,
                userId,
                findings: investigationNotes,
                actionTaken: 'Investigation initiated',
                outcome: 'needs_further_review',
                client
            });

            await createAnomalyAuditLog({
                userId,
                anomalyId,
                actionType: 'ANOMALY_INVESTIGATE',
                payload: { notes: investigationNotes },
                client
            });

            return anomalyResult.rows[0];
        });

        if (!anomalyRow) return null;
        return parseDecimalFields(anomalyRow, ANOMALY_DECIMAL_FIELDS);
    },

    async resolve(anomalyId, userId, notes) {
        const investigationNotes = notes || 'Resolved';
        const anomalyRow = await withTransaction(async (client) => {
            const result = await client.query(`
                UPDATE anomalies
                SET status = 'resolved',
                    investigated_by = COALESCE(investigated_by, $2),
                    investigation_notes = CASE
                        WHEN investigation_notes IS NOT NULL AND investigation_notes != ''
                        THEN investigation_notes || E'\n' || $3
                        ELSE $3
                    END,
                    resolution_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE anomaly_id = $1
                RETURNING *
            `, [anomalyId, userId, investigationNotes]);

            if (result.rows.length === 0) return null;

            await createInvestigationRecord({
                anomalyId,
                userId,
                findings: investigationNotes,
                actionTaken: 'Anomaly resolved',
                outcome: 'confirmed',
                client
            });

            await createAnomalyAuditLog({
                userId,
                anomalyId,
                actionType: 'ANOMALY_RESOLVE',
                payload: { notes: investigationNotes },
                client
            });

            return result.rows[0];
        });

        if (!anomalyRow) return null;
        return parseDecimalFields(anomalyRow, ANOMALY_DECIMAL_FIELDS);
    },

    async markFalsePositive(anomalyId, userId, notes) {
        const investigationNotes = notes || 'Marked as false positive';
        const anomalyRow = await withTransaction(async (client) => {
            const result = await client.query(`
                UPDATE anomalies
                SET status = 'false_positive',
                    investigated_by = COALESCE(investigated_by, $2),
                    investigation_notes = CASE
                        WHEN investigation_notes IS NOT NULL AND investigation_notes != ''
                        THEN investigation_notes || E'\n' || $3
                        ELSE $3
                    END,
                    resolution_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE anomaly_id = $1
                RETURNING *
            `, [anomalyId, userId, investigationNotes]);

            if (result.rows.length === 0) return null;

            await createInvestigationRecord({
                anomalyId,
                userId,
                findings: investigationNotes,
                actionTaken: 'Marked as false positive',
                outcome: 'false_positive',
                client
            });

            await createAnomalyAuditLog({
                userId,
                anomalyId,
                actionType: 'ANOMALY_FALSE_POSITIVE',
                payload: { notes: investigationNotes },
                client
            });

            return result.rows[0];
        });

        if (!anomalyRow) return null;
        return parseDecimalFields(anomalyRow, ANOMALY_DECIMAL_FIELDS);
    },

    async markAcceptableChange(anomalyId, userId, notes) {
        const investigationNotes = notes || 'Marked as acceptable change';
        const anomalyRow = await withTransaction(async (client) => {
            const result = await client.query(`
                UPDATE anomalies
                SET status = 'acceptable_change',
                    investigated_by = COALESCE(investigated_by, $2),
                    investigation_notes = CASE
                        WHEN investigation_notes IS NOT NULL AND investigation_notes != ''
                        THEN investigation_notes || E'\n' || $3
                        ELSE $3
                    END,
                    resolution_date = CURRENT_TIMESTAMP,
                    updated_at = CURRENT_TIMESTAMP
                WHERE anomaly_id = $1
                RETURNING *
            `, [anomalyId, userId, investigationNotes]);

            if (result.rows.length === 0) return null;

            await createInvestigationRecord({
                anomalyId,
                userId,
                findings: investigationNotes,
                actionTaken: 'Marked as acceptable operational change',
                outcome: 'acceptable_change',
                client
            });

            await createAnomalyAuditLog({
                userId,
                anomalyId,
                actionType: 'ANOMALY_ACCEPTABLE_CHANGE',
                payload: { notes: investigationNotes },
                client
            });

            return result.rows[0];
        });

        if (!anomalyRow) return null;
        return parseDecimalFields(anomalyRow, ANOMALY_DECIMAL_FIELDS);
    },

    async getStatsByUnit(unitId) {
        const result = await query(`
      SELECT 
        severity,
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE is_mandatory_review = true) as mandatory_reviews
      FROM anomalies
      WHERE unit_id = $1
            AND COALESCE(removed_from_dashboard, false) = false
      AND detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
      GROUP BY severity
    `, [unitId]);
        return result.rows;
    },

    /**
     * Get anomalies by type for analysis
     */
    async getByType(anomalyType, filters = {}) {
        const { limit = 50, offset = 0 } = filters;
        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name,
             u.unit_name
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      WHERE a.anomaly_type = $1
      ORDER BY a.detected_at DESC
      LIMIT $2 OFFSET $3
    `, [anomalyType, limit, offset]);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    },

    /**
     * Get cross-unit transfer anomalies (always mandatory review)
     */
    async getCrossUnitTransferAnomalies(filters = {}) {
        const { status, limit = 50, offset = 0 } = filters;
        let where = `WHERE a.anomaly_type = 'cross_unit_transfer'`;
        let params = [];
        let pCount = 0;

        if (status) {
            pCount++;
            where += ` AND a.status = $${pCount}`;
            params.push(status);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name,
             u.unit_name,
             a.event_context->>'previous_unit_name' as from_unit
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      ${where}
      ORDER BY a.detected_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    },

    /**
     * Get anomalies with ballistic timing concerns
     */
    async getBallisticTimingAnomalies(filters = {}) {
        const { severity, limit = 50, offset = 0 } = filters;
        let where = `WHERE (a.ballistic_access_context->>'timing_score')::numeric > 0.5`;
        let params = [];
        let pCount = 0;

        if (severity) {
            pCount++;
            where += ` AND a.severity = $${pCount}`;
            params.push(severity);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name,
             u.unit_name,
             a.ballistic_access_context->>'timing_score' as ballistic_timing_score,
             a.ballistic_access_context->>'access_before_hours' as access_before_hours,
             a.ballistic_access_context->>'access_after_hours' as access_after_hours
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      ${where}
      ORDER BY (a.ballistic_access_context->>'timing_score')::numeric DESC, a.detected_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    },

    /**
     * Get summary of anomaly types for dashboard
     */
    async getTypeSummary(filters = {}) {
        const { unit_id, include_removed, days = 30 } = filters;
        const includeRemoved = toBoolean(include_removed);
        let where = `WHERE a.detected_at >= CURRENT_TIMESTAMP - INTERVAL '1 day' * $1`;
        let params = [parseInt(days)];
        let pCount = 1;

        if (!includeRemoved) {
            where += ` AND COALESCE(a.removed_from_dashboard, false) = false`;
        }

        if (unit_id) {
            pCount++;
            where += ` AND a.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        const result = await query(`
      SELECT 
        a.anomaly_type,
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE a.status = 'pending') as pending,
        COUNT(*) FILTER (WHERE a.is_mandatory_review = true) as mandatory,
        AVG(a.anomaly_score) as avg_score
      FROM anomalies a
      ${where}
      GROUP BY a.anomaly_type
      ORDER BY count DESC
    `, params);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    },

    /**
     * Submit explanation for critical anomaly (station commander explains to HQ)
     */
    async submitExplanation(anomalyId, userId, message) {
        const anomalyRow = await withTransaction(async (client) => {
            const result = await client.query(`
                UPDATE anomalies
                SET explanation_message = $3,
                    explanation_by = $2,
                    explanation_date = CURRENT_TIMESTAMP,
                    status = CASE
                        WHEN status = 'open' THEN 'investigating'
                        ELSE status
                    END,
                    updated_at = CURRENT_TIMESTAMP
                WHERE anomaly_id = $1
                RETURNING *
            `, [anomalyId, userId, message]);

            if (result.rows.length === 0) return null;

            await createInvestigationRecord({
                anomalyId,
                userId,
                findings: message,
                actionTaken: 'Explanation submitted for critical anomaly',
                outcome: 'needs_further_review',
                client
            });

            await createAnomalyAuditLog({
                userId,
                anomalyId,
                actionType: 'ANOMALY_EXPLANATION',
                payload: { message },
                client
            });

            return result.rows[0];
        });

        if (!anomalyRow) return null;
        return parseDecimalFields(anomalyRow, ANOMALY_DECIMAL_FIELDS);
    },

    async removeFromDashboard(anomalyId, userId, reason) {
        const result = await query(`
            UPDATE anomalies
            SET removed_from_dashboard = true,
                removed_from_dashboard_at = CURRENT_TIMESTAMP,
                removed_from_dashboard_by = $2,
                removed_from_dashboard_reason = $3,
                updated_at = CURRENT_TIMESTAMP
            WHERE anomaly_id = $1
            RETURNING anomaly_id, removed_from_dashboard, removed_from_dashboard_at,
                      removed_from_dashboard_by, removed_from_dashboard_reason
        `, [anomalyId, userId, reason || 'Deleted from dashboard']);

        if (result.rows.length === 0) return null;

        await createAnomalyAuditLog({
            userId,
            anomalyId,
            actionType: 'ANOMALY_DASHBOARD_DELETE',
            payload: { reason: reason || 'Deleted from dashboard' }
        });

        return result.rows[0];
    },

    async restoreToDashboard(anomalyId, userId) {
        const result = await query(`
            UPDATE anomalies
            SET removed_from_dashboard = false,
                removed_from_dashboard_at = NULL,
                removed_from_dashboard_by = NULL,
                removed_from_dashboard_reason = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE anomaly_id = $1
            RETURNING anomaly_id, removed_from_dashboard
        `, [anomalyId]);

        if (result.rows.length === 0) return null;

        await createAnomalyAuditLog({
            userId,
            anomalyId,
            actionType: 'ANOMALY_DASHBOARD_RESTORE',
            payload: {}
        });

        return result.rows[0];
    },

    /**
     * Search anomalies for investigation - filter by unit and time interval
     */
    async searchForInvestigation(filters = {}) {
        const {
            unit_id,
            start_date,
            end_date,
            severity,
            status,
            include_removed,
            limit = 100,
            offset = 0
        } = filters;
        const includeRemoved = toBoolean(include_removed);
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (unit_id) {
            pCount++;
            where += ` AND a.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        if (start_date) {
            pCount++;
            where += ` AND a.detected_at >= $${pCount}`;
            params.push(start_date);
        }

        if (end_date) {
            pCount++;
            where += ` AND a.detected_at <= $${pCount}`;
            params.push(end_date);
        }

        if (severity) {
            pCount++;
            where += ` AND a.severity = $${pCount}`;
            params.push(severity);
        }

        if (status) {
            pCount++;
            where += ` AND a.status = $${pCount}`;
            params.push(status);
        }

        if (!includeRemoved) {
            where += ` AND COALESCE(a.removed_from_dashboard, false) = false`;
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
            SELECT a.*,
                   f.serial_number, f.manufacturer, f.model,
                   o.full_name as officer_name, o.rank,
                   u.unit_name,
                   cr.issued_at,
                   cr.returned_at,
                   cr.custody_type,
                   cr.duration_type,
                   cr.issued_at as issue_date,
                   cr.returned_at as return_date,
                   cr.duration_type as shift_type,
                   latest_inv.latest_investigation_date,
                   latest_inv.latest_investigation_outcome,
                   latest_inv.latest_investigator_id,
                   latest_inv.latest_investigator_name,
                   latest_inv.latest_action_taken,
                   latest_inv.latest_findings,
                   inv_trace.investigation_count,
                   inv_trace.investigation_trace
            FROM anomalies a
            JOIN firearms f ON a.firearm_id = f.firearm_id
            JOIN officers o ON a.officer_id = o.officer_id
            JOIN units u ON a.unit_id = u.unit_id
            LEFT JOIN custody_records cr ON a.custody_record_id = cr.custody_id
            LEFT JOIN LATERAL (
                SELECT ai.investigation_date as latest_investigation_date,
                       ai.outcome as latest_investigation_outcome,
                       ai.investigator_id as latest_investigator_id,
                       investigator.full_name as latest_investigator_name,
                       ai.action_taken as latest_action_taken,
                       ai.findings as latest_findings
                FROM anomaly_investigations ai
                LEFT JOIN users investigator ON investigator.user_id = ai.investigator_id
                WHERE ai.anomaly_id = a.anomaly_id
                ORDER BY ai.investigation_date DESC, ai.created_at DESC
                LIMIT 1
            ) latest_inv ON true
            LEFT JOIN LATERAL (
                SELECT COUNT(*)::INTEGER as investigation_count,
                       COALESCE(
                           jsonb_agg(
                               jsonb_build_object(
                                   'investigation_id', ai_trace.investigation_id,
                                   'investigation_date', ai_trace.investigation_date,
                                   'investigator_id', ai_trace.investigator_id,
                                   'investigator_name', trace_user.full_name,
                                   'findings', ai_trace.findings,
                                   'action_taken', ai_trace.action_taken,
                                   'outcome', ai_trace.outcome
                               )
                               ORDER BY ai_trace.investigation_date DESC, ai_trace.created_at DESC
                           ),
                           '[]'::jsonb
                       ) as investigation_trace
                FROM anomaly_investigations ai_trace
                LEFT JOIN users trace_user ON trace_user.user_id = ai_trace.investigator_id
                WHERE ai_trace.anomaly_id = a.anomaly_id
            ) inv_trace ON true
            ${where}
            ORDER BY 
                CASE a.severity 
                    WHEN 'critical' THEN 1 
                    WHEN 'high' THEN 2 
                    WHEN 'medium' THEN 3 
                    ELSE 4 
                END,
                a.detected_at DESC
            LIMIT $${pCount - 1} OFFSET $${pCount}
        `, params);
        return parseDecimalFields(result.rows, ANOMALY_DECIMAL_FIELDS);
    }
};

module.exports = Anomaly;
