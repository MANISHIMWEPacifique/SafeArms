const { query } = require('../config/database');

const CustodyRecord = {
    async findById(custodyId) {
        const result = await query(`
      SELECT cr.*, 
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name, o.rank,
             u.unit_name
      FROM custody_records cr
      JOIN firearms f ON cr.firearm_id = f.firearm_id
      JOIN officers o ON cr.officer_id = o.officer_id
      JOIN units u ON cr.unit_id = u.unit_id
      WHERE cr.custody_id = $1
    `, [custodyId]);
        return result.rows[0];
    },

    async findByFirearmId(firearmId, limit = 50) {
        const result = await query(`
      SELECT cr.*, o.full_name as officer_name, u.unit_name
      FROM custody_records cr
      JOIN officers o ON cr.officer_id = o.officer_id
      JOIN units u ON cr.unit_id = u.unit_id
      WHERE cr.firearm_id = $1
      ORDER BY cr.issued_at DESC
      LIMIT $2
    `, [firearmId, limit]);
        return result.rows;
    },

    async findByOfficerId(officerId, limit = 50) {
        const result = await query(`
      SELECT cr.*, f.serial_number, f.manufacturer, f.model, u.unit_name
      FROM custody_records cr
      JOIN firearms f ON cr.firearm_id = f.firearm_id
      JOIN units u ON cr.unit_id = u.unit_id
      WHERE cr.officer_id = $1
      ORDER BY cr.issued_at DESC
      LIMIT $2
    `, [officerId, limit]);
        return result.rows;
    },

    async findActive(filters = {}) {
        const { unit_id, officer_id, limit = 100 } = filters;
        let where = 'WHERE cr.returned_at IS NULL';
        let params = [];
        let pCount = 0;

        if (unit_id) {
            pCount++;
            where += ` AND cr.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        if (officer_id) {
            pCount++;
            where += ` AND cr.officer_id = $${pCount}`;
            params.push(officer_id);
        }

        pCount++;
        params.push(limit);

        const result = await query(`
      SELECT cr.*, 
             f.serial_number, f.manufacturer, f.model,
             o.full_name as officer_name, o.rank,
             u.unit_name
      FROM custody_records cr
      JOIN firearms f ON cr.firearm_id = f.firearm_id
      JOIN officers o ON cr.officer_id = o.officer_id
      JOIN units u ON cr.unit_id = u.unit_id
      ${where}
      ORDER BY cr.issued_at DESC
      LIMIT $${pCount}
    `, params);
        return result.rows;
    }
};

module.exports = CustodyRecord;
