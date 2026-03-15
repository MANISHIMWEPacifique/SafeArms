const { query, withTransaction } = require('../config/database');

const ELIGIBLE_COMMANDER_ROLES = ['station_commander', 'hq_firearm_commander'];

const normalizeCommanderUserId = (commanderUserId) => {
    if (commanderUserId === undefined) return undefined;
    if (commanderUserId === null) return null;

    const trimmed = String(commanderUserId).trim();
    return trimmed.length > 0 ? trimmed : null;
};

const createBadRequestError = (message) => {
    const error = new Error(message);
    error.statusCode = 400;
    return error;
};

const Unit = {
    async resolveCommanderFields(commanderUserId, fallbackCommanderName = null) {
        const normalizedCommanderUserId = normalizeCommanderUserId(commanderUserId);

        if (normalizedCommanderUserId === undefined) {
            return {
                commander_user_id: undefined,
                commander_name: fallbackCommanderName
            };
        }

        if (normalizedCommanderUserId === null) {
            return {
                commander_user_id: null,
                commander_name: null
            };
        }

        const commanderResult = await query(
            `SELECT user_id, full_name
             FROM users
             WHERE user_id = $1
               AND is_active = true
               AND role = ANY($2)`,
            [normalizedCommanderUserId, ELIGIBLE_COMMANDER_ROLES]
        );

        if (!commanderResult.rows[0]) {
            throw createBadRequestError('Selected commander is invalid. Choose an active station or HQ commander.');
        }

        return {
            commander_user_id: commanderResult.rows[0].user_id,
            commander_name: commanderResult.rows[0].full_name
        };
    },

    async findById(unitId) {
        const result = await query(`
            SELECT u.*,
                   COALESCE(cmd.full_name, u.commander_name) as commander_name,
                   COALESCE(f.firearm_count, 0) as firearm_count,
                   COALESCE(o.officer_count, 0) as officer_count,
                   COALESCE(c.active_custody, 0) as active_custody,
                   COALESCE(a.anomaly_count, 0) as anomaly_count
            FROM units u
            LEFT JOIN users cmd ON u.commander_user_id = cmd.user_id
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
                FROM anomalies WHERE status IN ('open', 'pending') 
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
                   COALESCE(cmd.full_name, u.commander_name) as commander_name,
                   COALESCE(f.firearm_count, 0) as firearm_count,
                   COALESCE(o.officer_count, 0) as officer_count,
                   COALESCE(c.active_custody, 0) as active_custody,
                   COALESCE(a.anomaly_count, 0) as anomaly_count
            FROM units u
            LEFT JOIN users cmd ON u.commander_user_id = cmd.user_id
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
                FROM anomalies WHERE status IN ('open', 'pending') 
                GROUP BY unit_id
            ) a ON u.unit_id = a.unit_id
            ${where} 
            ORDER BY u.unit_name 
            LIMIT $${pCount - 1} OFFSET $${pCount}
        `, params);
        return result.rows;
    },

    async create(unitData) {
        const { unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name, commander_user_id, is_active } = unitData;

        // Generate unit_id
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(unit_id FROM 6) AS INTEGER)), 0) as max_num FROM units WHERE unit_id ~ '^UNIT-[0-9]+$'`);
        const count = parseInt(idResult.rows[0].max_num) + 1;
        const unit_id = `UNIT-${String(count).padStart(3, '0')}`;

        // Map unit_type to valid CHECK constraint values
        const validTypes = ['headquarters', 'district', 'station', 'specialized'];
        let mappedType = unit_type;
        if (!validTypes.includes(unit_type)) {
            if (unit_type === 'training_school' || unit_type === 'special_unit') mappedType = 'specialized';
            else mappedType = 'station';
        }

        const commanderFields = await this.resolveCommanderFields(commander_user_id, commander_name || null);

        await query(
            `INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name, commander_user_id, is_active)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11) RETURNING *`,
            [
                unit_id,
                unit_name,
                mappedType,
                location,
                province,
                district,
                contact_phone,
                contact_email,
                commanderFields.commander_name,
                commanderFields.commander_user_id ?? null,
                is_active !== undefined ? is_active : true
            ]
        );

        return await this.findById(unit_id);
    },

    async update(unitId, updates) {
        // Map unit_type to valid CHECK constraint values
        if (updates.unit_type) {
            const validTypes = ['headquarters', 'district', 'station', 'specialized'];
            if (!validTypes.includes(updates.unit_type)) {
                if (updates.unit_type === 'training_school' || updates.unit_type === 'special_unit') {
                    updates.unit_type = 'specialized';
                } else {
                    updates.unit_type = 'station';
                }
            }
        }

        if (Object.prototype.hasOwnProperty.call(updates, 'commander_user_id')) {
            const commanderFields = await this.resolveCommanderFields(
                updates.commander_user_id,
                updates.commander_name || null
            );

            updates.commander_user_id = commanderFields.commander_user_id;
            updates.commander_name = commanderFields.commander_name;
        }

        const fields = Object.keys(updates).map((key, idx) => `${key} = $${idx + 2}`);
        if (fields.length === 0) {
            return await this.findById(unitId);
        }

        const values = [unitId, ...Object.values(updates)];
        await query(
            `UPDATE units SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE unit_id = $1 RETURNING *`,
            values
        );

        return await this.findById(unitId);
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
    },

    async delete(unitId) {
        return await withTransaction(async (client) => {
            // Delete records from tables that reference this unit with NOT NULL constraints
            await client.query('DELETE FROM ml_training_features WHERE unit_id = $1', [unitId]);
            await client.query('DELETE FROM anomalies WHERE unit_id = $1', [unitId]);
            await client.query('DELETE FROM loss_reports WHERE unit_id = $1', [unitId]);
            await client.query('DELETE FROM destruction_requests WHERE unit_id = $1', [unitId]);
            await client.query('DELETE FROM procurement_requests WHERE unit_id = $1', [unitId]);

            // Nullify nullable unit references
            await client.query('UPDATE ballistic_access_logs SET current_custody_unit_id = NULL WHERE current_custody_unit_id = $1', [unitId]);
            await client.query('UPDATE firearm_unit_movements SET from_unit_id = NULL WHERE from_unit_id = $1', [unitId]);

            // Delete firearm unit movements where this unit is the destination
            await client.query('DELETE FROM firearm_unit_movements WHERE to_unit_id = $1', [unitId]);

            // Delete custody records for this unit
            await client.query('DELETE FROM custody_records WHERE unit_id = $1', [unitId]);

            // Nullify unit references on officers and firearms
            await client.query('DELETE FROM officers WHERE unit_id = $1', [unitId]);
            await client.query('UPDATE firearms SET assigned_unit_id = NULL WHERE assigned_unit_id = $1', [unitId]);
            await client.query('UPDATE users SET unit_id = NULL WHERE unit_id = $1', [unitId]);

            // Finally delete the unit
            const result = await client.query(
                'DELETE FROM units WHERE unit_id = $1 RETURNING *',
                [unitId]
            );

            return result.rows[0];
        });
    }
};

module.exports = Unit;
