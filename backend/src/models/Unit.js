const { query } = require('../config/database');

const Unit = {
    async findById(unitId) {
        const result = await query('SELECT * FROM units WHERE unit_id = $1', [unitId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { unit_type, is_active, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (unit_type) {
            pCount++;
            where += ` AND unit_type = $${pCount}`;
            params.push(unit_type);
        }

        if (is_active !== undefined) {
            pCount++;
            where += ` AND is_active = $${pCount}`;
            params.push(is_active);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(
            `SELECT * FROM units ${where} ORDER BY unit_name LIMIT $${pCount - 1} OFFSET $${pCount}`,
            params
        );
        return result.rows;
    },

    async create(unitData) {
        const { unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name } = unitData;
        const result = await query(
            `INSERT INTO units (unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
            [unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name]
        );
        return result.rows[0];
    },

    async update(unitId, updates) {
        const fields = Object.keys(updates).map((key, idx) => `${key} = $${idx + 2}`);
        const values = [unitId, ...Object.values(updates)];
        const result = await query(
            `UPDATE units SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE unit_id = $1 RETURNING *`,
            values
        );
        return result.rows[0];
    },

    async getStats() {
        const result = await query(`
            SELECT 
                COUNT(*) as total_units,
                COUNT(*) FILTER (WHERE is_active = true) as active_units,
                COUNT(*) FILTER (WHERE unit_type = 'station') as stations,
                COUNT(*) FILTER (WHERE unit_type = 'headquarters') as headquarters
            FROM units
        `);
        return result.rows[0];
    }
};

module.exports = Unit;
