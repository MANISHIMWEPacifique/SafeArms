const { query } = require('../config/database');

const Firearm = {
    async findById(firearmId) {
        const result = await query(`
      SELECT f.*, u.unit_name, bp.ballistic_id
      FROM firearms f
      LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
      LEFT JOIN ballistic_profiles bp ON f.firearm_id = bp.firearm_id
      WHERE f.firearm_id = $1
    `, [firearmId]);
        return result.rows[0];
    },

    async findBySerialNumber(serialNumber) {
        const result = await query('SELECT * FROM firearms WHERE serial_number = $1', [serialNumber]);
        return result.rows[0];
    },

    async findAll(filters = {}) {
        // Support both 'unit_id' and 'assigned_unit_id' for filtering
        // Support both 'status' and 'current_status', 'type' and 'firearm_type'
        const { unit_id, assigned_unit_id, current_status, status, firearm_type, type, limit = 100, offset = 0 } = filters;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        // Use assigned_unit_id if provided, otherwise fall back to unit_id
        const filterUnitId = assigned_unit_id || unit_id;
        if (filterUnitId) {
            pCount++;
            where += ` AND f.assigned_unit_id = $${pCount}`;
            params.push(filterUnitId);
        }

        const filterStatus = current_status || status;
        if (filterStatus) {
            pCount++;
            where += ` AND current_status = $${pCount}`;
            params.push(filterStatus);
        }

        const filterType = firearm_type || type;
        if (filterType) {
            pCount++;
            where += ` AND firearm_type = $${pCount}`;
            params.push(filterType);
        }

        pCount++;
        params.push(limit);
        pCount++;
        params.push(offset);

        const result = await query(
            `SELECT f.*, u.unit_name FROM firearms f
       LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
       ${where} ORDER BY f.created_at DESC LIMIT $${pCount - 1} OFFSET $${pCount}`,
            params
        );
        return result.rows;
    },

    async create(firearmData) {
        const { serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id } = firearmData;
        const result = await query(
            `INSERT INTO firearms (serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *`,
            [serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id]
        );
        return result.rows[0];
    },

    async update(firearmId, updates) {
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
        values.push(firearmId);

        const result = await query(
            `UPDATE firearms SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE firearm_id = $${pCount} RETURNING *`,
            values
        );
        return result.rows[0];
    },

    async getStatsByUnit(unitId) {
        const result = await query(`
      SELECT 
        current_status,
        COUNT(*) as count
      FROM firearms
      WHERE assigned_unit_id = $1
      GROUP BY current_status
    `, [unitId]);
        return result.rows;
    }
};

module.exports = Firearm;
