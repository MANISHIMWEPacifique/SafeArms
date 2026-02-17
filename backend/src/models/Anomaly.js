const { query } = require('../config/database');

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
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { severity, status, unit_id, anomaly_type, is_mandatory_review, limit = 100, offset = 0 } = filters;
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
        return result.rows;
    },

    async update(anomalyId, updates) {
        const fields = [];
        const values = [];
        let pCount = 0;

        Object.entries(updates).forEach(([key, value]) => {
            if (value !== undefined) {
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
        return result.rows[0];
    },

    async getStatsByUnit(unitId) {
        const result = await query(`
      SELECT 
        severity,
        COUNT(*) as count,
        COUNT(*) FILTER (WHERE is_mandatory_review = true) as mandatory_reviews
      FROM anomalies
      WHERE unit_id = $1
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
        return result.rows;
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
        return result.rows;
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
        return result.rows;
    },

    /**
     * Get summary of anomaly types for dashboard
     */
    async getTypeSummary(filters = {}) {
        const { unit_id, days = 30 } = filters;
        let where = `WHERE a.detected_at >= CURRENT_TIMESTAMP - INTERVAL '1 day' * $1`;
        let params = [parseInt(days)];
        let pCount = 1;

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
        return result.rows;
    }
};

module.exports = Anomaly;
