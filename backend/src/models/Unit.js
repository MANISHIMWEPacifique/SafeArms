const { query } = require('../config/database');

const Unit = {
    async findById(unitId) {
        const result = await query(`
            SELECT u.*,
                   COALESCE(f.firearm_count, 0) as firearm_count,
                   COALESCE(o.officer_count, 0) as officer_count,
                   COALESCE(c.active_custody, 0) as active_custody,
                   COALESCE(a.anomaly_count, 0) as anomaly_count
            FROM units u
            LEFT JOIN (
                SELECT assigned_unit_id, COUNT(*) as firearm_count 
                FROM firearms WHERE is_active = true 
                GROUP BY assigned_unit_id
            ) f ON u.unit_id = f.assigned_unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as officer_count 
                FROM officers WHERE is_active = true 
                GROUP BY unit_id
            ) o ON u.unit_id = o.unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as active_custody 
                FROM custody_records WHERE returned_at IS NULL 
                GROUP BY unit_id
            ) c ON u.unit_id = c.unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as anomaly_count 
                FROM anomalies WHERE status = 'pending' 
                GROUP BY unit_id
            ) a ON u.unit_id = a.unit_id
            WHERE u.unit_id = $1
        `, [unitId]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        const { unit_type, is_active, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (unit_type) {
            pCount++;
            where += ` AND u.unit_type = $${pCount}`;
            params.push(unit_type);
        }

        if (is_active !== undefined) {
            pCount++;
            where += ` AND u.is_active = $${pCount}`;
            params.push(is_active);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(`
            SELECT u.*,
                   COALESCE(f.firearm_count, 0) as firearm_count,
                   COALESCE(o.officer_count, 0) as officer_count,
                   COALESCE(c.active_custody, 0) as active_custody,
                   COALESCE(a.anomaly_count, 0) as anomaly_count
            FROM units u
            LEFT JOIN (
                SELECT assigned_unit_id, COUNT(*) as firearm_count 
                FROM firearms WHERE is_active = true 
                GROUP BY assigned_unit_id
            ) f ON u.unit_id = f.assigned_unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as officer_count 
                FROM officers WHERE is_active = true 
                GROUP BY unit_id
            ) o ON u.unit_id = o.unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as active_custody 
                FROM custody_records WHERE returned_at IS NULL 
                GROUP BY unit_id
            ) c ON u.unit_id = c.unit_id
            LEFT JOIN (
                SELECT unit_id, COUNT(*) as anomaly_count 
                FROM anomalies WHERE status = 'pending' 
                GROUP BY unit_id
            ) a ON u.unit_id = a.unit_id
            ${where} 
            ORDER BY u.unit_name 
            LIMIT $${pCount - 1} OFFSET $${pCount}
        `, params);
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
