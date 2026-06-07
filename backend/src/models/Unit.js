const { query, withTransaction } = require('../config/database');

const ELIGIBLE_COMMANDER_ROLES = ['station_commander', 'hq_firearm_commander'];
const STATION_COMMANDER_ROLE = 'station_commander';

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

const isMissingCommanderUserIdColumnError = (error) => {
    return error && error.code === '42703' && typeof error.message === 'string' && error.message.includes('commander_user_id');
};

const isMissingArchiveColumnError = (error) => {
    return error && error.code === '42703' && typeof error.message === 'string' && (
        error.message.includes('archived_at') ||
        error.message.includes('removed_from_dashboard')
    );
};

const buildAnomalyCountSelect = (useArchiveFilters) => {
    const archiveFilter = useArchiveFilters
        ? 'AND a.archived_at IS NULL AND COALESCE(a.removed_from_dashboard, false) = false'
        : '';

    return `(SELECT CAST(COUNT(*) AS INTEGER)
             FROM anomalies a
             WHERE a.unit_id = u.unit_id
               AND a.status IN ('open', 'pending')
               ${archiveFilter}) as anomaly_count`;
};

const buildUnitSelect = ({ whereClause, includeCommanderJoin, useArchiveFilters, pageClause = '' }) => {
    const commanderSelect = includeCommanderJoin
        ? 'COALESCE(cmd.full_name, u.commander_name) as commander_name'
        : 'u.commander_name as commander_name';
    const commanderJoin = includeCommanderJoin
        ? 'LEFT JOIN users cmd ON u.commander_user_id = cmd.user_id'
        : '';

    return `
        SELECT u.*,
               ${commanderSelect},
               (SELECT CAST(COUNT(*) AS INTEGER) FROM firearms f WHERE f.assigned_unit_id = u.unit_id AND f.is_active = true) as firearm_count,
               (SELECT CAST(COUNT(*) AS INTEGER) FROM officers o WHERE o.unit_id = u.unit_id AND o.is_active = true) as officer_count,
               (SELECT CAST(COUNT(*) AS INTEGER) FROM custody_records c WHERE c.unit_id = u.unit_id AND c.returned_at IS NULL) as active_custody,
               ${buildAnomalyCountSelect(useArchiveFilters)}
        FROM units u
        ${commanderJoin}
        ${whereClause}
        ORDER BY u.unit_name
        ${pageClause}
    `;
};

const queryUnitsWithFallback = async ({ whereClause, params, pageClause = '' }) => {
    let includeCommanderJoin = true;
    let useArchiveFilters = true;

    for (let attempt = 0; attempt < 4; attempt++) {
        try {
            return await query(buildUnitSelect({
                whereClause,
                includeCommanderJoin,
                useArchiveFilters,
                pageClause
            }), params);
        } catch (error) {
            if (isMissingCommanderUserIdColumnError(error) && includeCommanderJoin) {
                includeCommanderJoin = false;
                continue;
            }

            if (isMissingArchiveColumnError(error) && useArchiveFilters) {
                useArchiveFilters = false;
                continue;
            }

            throw error;
        }
    }

    return await query(buildUnitSelect({
        whereClause,
        includeCommanderJoin,
        useArchiveFilters,
        pageClause
    }), params);
};

const syncStationCommanderForUnit = async (executeQuery, { unitId, previousCommanderUserId, nextCommanderUserId }) => {
    if (previousCommanderUserId && previousCommanderUserId !== nextCommanderUserId) {
        await executeQuery(
            `UPDATE users
             SET unit_id = NULL,
                 unit_confirmed = false,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $1
               AND role = $2
               AND unit_id = $3`,
            [previousCommanderUserId, STATION_COMMANDER_ROLE, unitId]
        );
    }

    if (!nextCommanderUserId) {
        return;
    }

    await executeQuery(
        `UPDATE users
         SET unit_id = $1,
             unit_confirmed = false,
             updated_at = CURRENT_TIMESTAMP
         WHERE user_id = $2
           AND role = $3`,
        [unitId, nextCommanderUserId, STATION_COMMANDER_ROLE]
    );
};

const Unit = {
    async resolveCommanderFields(commanderUserId, fallbackCommanderName = null, dbClient = null) {
        const executeQuery = dbClient ? dbClient.query.bind(dbClient) : query;
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

            const commanderResult = await executeQuery(
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
        const result = await queryUnitsWithFallback({
            whereClause: 'WHERE u.unit_id = $1',
            params: [unitId]
        });

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

        const result = await queryUnitsWithFallback({
            whereClause: where,
            params,
            pageClause: `LIMIT $${pCount - 1} OFFSET $${pCount}`
        });

        return result.rows;
    },

    async create(unitData) {
        const { unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name, commander_user_id, is_active } = unitData;

        return await withTransaction(async (client) => {
            // Generate unit_id
            const idResult = await client.query(`SELECT COALESCE(MAX(CAST(SUBSTRING(unit_id FROM 6) AS INTEGER)), 0) as max_num FROM units WHERE unit_id ~ '^UNIT-[0-9]+$'`);
            const count = parseInt(idResult.rows[0].max_num) + 1;
            const unit_id = `UNIT-${String(count).padStart(3, '0')}`;

            // Map unit_type to valid CHECK constraint values
            const validTypes = ['headquarters', 'district', 'station', 'specialized'];
            let mappedType = unit_type;
            if (!validTypes.includes(unit_type)) {
                if (unit_type === 'training_school' || unit_type === 'special_unit') mappedType = 'specialized';
                else mappedType = 'station';
            }

            const commanderFields = await this.resolveCommanderFields(
                commander_user_id,
                commander_name || null,
                client
            );

            const insertResult = await client.query(
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

            await syncStationCommanderForUnit(client.query.bind(client), {
                unitId: unit_id,
                previousCommanderUserId: null,
                nextCommanderUserId: commanderFields.commander_user_id ?? null
            });

            return {
                ...insertResult.rows[0],
                commander_name: commanderFields.commander_name,
                firearm_count: 0,
                officer_count: 0,
                active_custody: 0,
                anomaly_count: 0
            };
        });
    },

    async update(unitId, updates) {
        const normalizedUpdates = { ...updates };

        // Map unit_type to valid CHECK constraint values (if using an older schema version)
        // or just allow the new types through
        if (normalizedUpdates.unit_type) {
            const validTypes = ['headquarters', 'district', 'station', 'specialized', 'training_school', 'special_unit'];
            if (!validTypes.includes(normalizedUpdates.unit_type)) {
                normalizedUpdates.unit_type = 'station';
            }
        }

        const hasCommanderAssignmentUpdate = Object.prototype.hasOwnProperty.call(normalizedUpdates, 'commander_user_id');

        const updated = await withTransaction(async (client) => {
            let previousCommanderUserId = null;

            if (hasCommanderAssignmentUpdate) {
                const existingResult = await client.query(
                    'SELECT commander_user_id FROM units WHERE unit_id = $1',
                    [unitId]
                );

                if (!existingResult.rows[0]) {
                    return false;
                }

                previousCommanderUserId = existingResult.rows[0].commander_user_id;

                const commanderFields = await this.resolveCommanderFields(
                    normalizedUpdates.commander_user_id,
                    normalizedUpdates.commander_name || null,
                    client
                );

                normalizedUpdates.commander_user_id = commanderFields.commander_user_id;
                normalizedUpdates.commander_name = commanderFields.commander_name;
            }

            const fields = Object.keys(normalizedUpdates).map((key, idx) => `${key} = $${idx + 2}`);
            if (fields.length > 0) {
                const values = [unitId, ...Object.values(normalizedUpdates)];
                const result = await client.query(
                    `UPDATE units SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE unit_id = $1 RETURNING unit_id`,
                    values
                );

                if (!result.rows[0]) {
                    return false;
                }
            } else {
                const existingResult = await client.query(
                    'SELECT unit_id FROM units WHERE unit_id = $1',
                    [unitId]
                );

                if (!existingResult.rows[0]) {
                    return false;
                }
            }

            if (hasCommanderAssignmentUpdate) {
                await syncStationCommanderForUnit(client.query.bind(client), {
                    unitId,
                    previousCommanderUserId,
                    nextCommanderUserId: normalizedUpdates.commander_user_id ?? null
                });
            }

            return true;
        });

        if (!updated) {
            return null;
        }

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
            const retainedHistory = await client.query(`
                SELECT
                    (SELECT COUNT(*)::int FROM anomalies WHERE unit_id = $1) AS anomaly_count,
                    (SELECT COUNT(*)::int FROM ml_training_features WHERE unit_id = $1) AS feature_count
            `, [unitId]);

            const history = retainedHistory.rows[0] || {};
            if ((history.anomaly_count || 0) > 0 || (history.feature_count || 0) > 0) {
                throw new Error('Unit cannot be hard-deleted because retained anomaly or ML training history exists. Deactivate the unit instead.');
            }

            // Delete records from tables that reference this unit with NOT NULL constraints
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
