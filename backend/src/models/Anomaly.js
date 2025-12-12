const { query } = require('../config/database');

const Anomaly = {
    async findById(anomalyId) {
        const result = await query(`
      SELECT a.*,
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name, o.rank,
             u.unit_name
      FROM anomalies a
      JOIN firearms f ON a.firearm_id = f.firearm_id
      JOIN officers o ON a.officer_id = o.officer_id
      JOIN units u ON a.unit_id = u.unit_id
      WHERE a.anomaly_id = $1
    `, [anomalyId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { severity, status, unit_id, limit = 100, offset = 0 } = filters;
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
      ORDER BY a.detected_at DESC
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
        COUNT(*) as count
      FROM anomalies
      WHERE unit_id = $1
      AND detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
      GROUP BY severity
    `, [unitId]);
        return result.rows;
    }
};

module.exports = Anomaly;
