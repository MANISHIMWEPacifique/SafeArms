const { query } = require('../config/database');

const ProcurementRequest = {
    async findById(procurementId) {
        const result = await query(`
      SELECT pr.*,
             u.unit_name,
             requester.full_name as requester_name,
             reviewer.full_name as reviewer_name
      FROM procurement_requests pr
      JOIN units u ON pr.unit_id = u.unit_id
      LEFT JOIN users requester ON pr.requested_by = requester.user_id
      LEFT JOIN users reviewer ON pr.reviewed_by = reviewer.user_id
      WHERE pr.procurement_id = $1
    `, [procurementId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { status, unit_id, priority, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (status) {
            pCount++;
            where += ` AND pr.status = $${pCount}`;
            params.push(status);
        }

        if (unit_id) {
            pCount++;
            where += ` AND pr.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        if (priority) {
            pCount++;
            where += ` AND pr.priority = $${pCount}`;
            params.push(priority);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
      SELECT pr.*,
             u.unit_name,
             requester.full_name as requester_name
      FROM procurement_requests pr
      JOIN units u ON pr.unit_id = u.unit_id
      LEFT JOIN users requester ON pr.requested_by = requester.user_id
      ${where}
      ORDER BY 
        CASE pr.priority 
          WHEN 'urgent' THEN 1
          WHEN 'high' THEN 2
          WHEN 'routine' THEN 3
        END,
        pr.created_at DESC
      LIMIT $${pCount - 1} OFFSET $${pCount}
    `, params);
        return result.rows;
    },

    async create(requestData) {
        const { unit_id, requested_by, firearm_type, quantity, justification, priority, estimated_cost, preferred_supplier } = requestData;

        const result = await query(`
      INSERT INTO procurement_requests (
        unit_id, requested_by, firearm_type, quantity, justification,
        priority, estimated_cost, preferred_supplier
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *
    `, [unit_id, requested_by, firearm_type, quantity, justification, priority || 'routine', estimated_cost, preferred_supplier]);

        return result.rows[0];
    },

    async update(procurementId, updates) {
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
        values.push(procurementId);

        const result = await query(
            `UPDATE procurement_requests SET ${fields.join(', ')} WHERE procurement_id = $${pCount} RETURNING *`,
            values
        );
        return result.rows[0];
    }
};

module.exports = ProcurementRequest;
