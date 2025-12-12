const { query } = require('../config/database');

const LossReport = {
    async findById(lossId) {
        const result = await query(`
      SELECT lr.*,
             f.serial_number, f.manufacturer, f.model,
             u.unit_name,
             reporter.full_name as reporter_name,
             reviewer.full_name as reviewer_name
      FROM loss_reports lr
      JOIN firearms f ON lr.firearm_id = f.firearm_id
      JOIN units u ON lr.unit_id = u.unit_id
      LEFT JOIN users reporter ON lr.reported_by = reporter.user_id
      LEFT JOIN users reviewer ON lr.reviewed_by = reviewer.user_id
      WHERE lr.loss_id = $1
    `, [lossId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { status, unit_id, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (status) {
            pCount++;
            where += ` AND lr.status = $${pCount}`;
            params.push(status);
        }

        if (unit_id) {
            pCount++;
            where += ` AND lr.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT lr.*,
             f.serial_number, f.manufacturer, f.model,
             u.unit_name,
             reporter.full_name as reporter_name
      FROM loss_reports lr
      JOIN firearms f ON lr.firearm_id = f.firearm_id
      JOIN units u ON lr.unit_id = u.unit_id
      LEFT JOIN users reporter ON lr.reported_by = reporter.user_id
      ${where}
      ORDER BY lr.created_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return result.rows;
    },

    async create(reportData) {
        const { firearm_id, unit_id, reported_by, officer_id, loss_type, loss_date, loss_location, circumstances, police_case_number } = reportData;

        const result = await query(`
      INSERT INTO loss_reports (
        firearm_id, unit_id, reported_by, officer_id, loss_type,
        loss_date, loss_location, circumstances, police_case_number
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING *
    `, [firearm_id, unit_id, reported_by, officer_id, loss_type, loss_date, loss_location, circumstances, police_case_number]);

        return result.rows[0];
    },

    async update(lossId, updates) {
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
        values.push(lossId);

        const result = await query(
            `UPDATE loss_reports SET ${fields.join(', ')} WHERE loss_id = $${pCount} RETURNING *`,
            values
        );
        return result.rows[0];
    }
};

module.exports = LossReport;
