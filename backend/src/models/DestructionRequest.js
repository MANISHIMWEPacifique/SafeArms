const { query } = require('../config/database');

const DestructionRequest = {
    async findById(destructionId) {
        const result = await query(`
      SELECT dr.*,
             f.serial_number, f.manufacturer, f.model,
             u.unit_name,
             requester.full_name as requester_name,
             reviewer.full_name as reviewer_name
      FROM destruction_requests dr
      JOIN firearms f ON dr.firearm_id = f.firearm_id
      JOIN units u ON dr.unit_id = u.unit_id
      LEFT JOIN users requester ON dr.requested_by = requester.user_id
      LEFT JOIN users reviewer ON dr.reviewed_by = reviewer.user_id
      WHERE dr.destruction_id = $1
    `, [destructionId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { status, unit_id, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (status) {
            pCount++;
            where += ` AND dr.status = $${pCount}`;
            params.push(status);
        }

        if (unit_id) {
            pCount++;
            where += ` AND dr.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT dr.*,
             f.serial_number, f.manufacturer, f.model,
             u.unit_name,
             requester.full_name as requester_name
      FROM destruction_requests dr
      JOIN firearms f ON dr.firearm_id = f.firearm_id
      JOIN units u ON dr.unit_id = u.unit_id
      LEFT JOIN users requester ON dr.requested_by = requester.user_id
      ${where}
      ORDER BY dr.created_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return result.rows;
    },

    async create(requestData) {
        const { firearm_id, unit_id, requested_by, destruction_reason, condition_description, supporting_documents } = requestData;

        const result = await query(`
      INSERT INTO destruction_requests (
        firearm_id, unit_id, requested_by, destruction_reason,
        condition_description, supporting_documents
      ) VALUES ($1, $2, $3, $4, $5, $6)
      RETURNING *
    `, [firearm_id, unit_id, requested_by, destruction_reason, condition_description, supporting_documents]);

        return result.rows[0];
    },

    async update(destructionId, updates) {
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
        values.push(destructionId);

        const result = await query(
            `UPDATE destruction_requests SET ${fields.join(', ')} WHERE destruction_id = $${pCount} RETURNING *`,
            values
        );
        return result.rows[0];
    }
};

module.exports = DestructionRequest;
