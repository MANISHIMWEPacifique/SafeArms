const { query } = require('../config/database');

/**
 * Officer Model
 * 
 * IMPORTANT: Officers are NOT system users
 * - Officers CANNOT authenticate (no username/password)
 * - Officers do NOT have roles
 * - Officers receive firearm custody assignments
 * - Officers are managed by Station Commanders within their unit
 * 
 * System users (with authentication) are in the User model
 */
const Officer = {
    async findById(officerId) {
        const result = await query('SELECT * FROM officers WHERE officer_id = $1', [officerId]);
        return result.rows[0];
    },

    /**
     * Find all officers (no unit filter) - for admin/HQ users
     */
    async findAll(filters = {}) {
        const { is_active, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

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
            `SELECT o.*, u.unit_name FROM officers o LEFT JOIN units u ON o.unit_id = u.unit_id ${where} ORDER BY o.full_name LIMIT $${pCount - 1} OFFSET $${pCount}`,
            params
        );
        return result.rows;
    },

    async findByUnitId(unitId, filters = {}) {
        const { is_active, limit = 100, offset = 0 } = filters;
        let where = 'WHERE unit_id = $1';
        let params = [unitId];

        if (is_active !== undefined) {
            const isActiveBool = (is_active === true || is_active === 'true');
            where += ' AND is_active = $2';
            params.push(isActiveBool);
            params.push(parseInt(limit) || 100, parseInt(offset) || 0);
            const result = await query(
                `SELECT * FROM officers ${where} ORDER BY full_name LIMIT $3 OFFSET $4`,
                params
            );
            return result.rows;
        }

        params.push(parseInt(limit) || 100, parseInt(offset) || 0);
        const result = await query(
            `SELECT * FROM officers ${where} ORDER BY full_name LIMIT $2 OFFSET $3`,
            params
        );
        return result.rows;
    },

    async create(officerData) {
        const { officer_number, full_name, rank, unit_id, phone_number, email, date_of_birth, employment_date, firearm_certified, certification_date, certification_expiry } = officerData;
        const result = await query(
            `INSERT INTO officers (officer_number, full_name, rank, unit_id, phone_number, email, date_of_birth, employment_date, firearm_certified, certification_date, certification_expiry)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *`,
            [officer_number, full_name, rank, unit_id, phone_number, email, date_of_birth, employment_date, firearm_certified || false, certification_date, certification_expiry]
        );
        return result.rows[0];
    },

    async update(officerId, updates) {
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
        values.push(officerId);

        const result = await query(
            `UPDATE officers SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE officer_id = $${pCount} RETURNING *`,
            values
        );
        return result.rows[0];
    },

    async getStats(options = {}) {
        const { unit_id } = options;
        let whereClause = '';
        let params = [];
        
        // Filter by unit if specified (enforced for station commanders)
        if (unit_id) {
            whereClause = 'WHERE unit_id = $1';
            params.push(unit_id);
        }
        
        const result = await query(`
            SELECT 
                COUNT(*) as total_officers,
                COUNT(*) FILTER (WHERE is_active = true) as active_officers,
                COUNT(*) FILTER (WHERE firearm_certified = true) as certified_officers,
                COUNT(*) FILTER (WHERE firearm_certified = true AND certification_expiry < CURRENT_DATE) as expired_certifications
            FROM officers
            ${whereClause}
        `, params);
        return result.rows[0];
    }
};

module.exports = Officer;
