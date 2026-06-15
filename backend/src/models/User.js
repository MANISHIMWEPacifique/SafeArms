const { query, withTransaction } = require('../config/database');

/**
 * User Model
 * Database operations for users table
 */

const User = {
    /**
     * Find user by ID
     */
    async findById(userId) {
        const result = await query(
            `SELECT user_id, username, full_name, email, phone_number, role, 
                            unit_id, profile_photo_url, is_active, must_change_password, unit_confirmed, last_login
       FROM users WHERE user_id = $1`,
            [userId]
        );
        return result.rows[0];
    },

    /**
     * Find user by username
     */
    async findByUsername(username) {
        const result = await query(
            'SELECT * FROM users WHERE username = $1',
            [username]
        );
        return result.rows[0];
    },

    /**
     * Find user by email
     */
    async findByEmail(email) {
        const result = await query(
            'SELECT * FROM users WHERE email = $1',
            [email]
        );
        return result.rows[0];
    },

    async findByUsernameExcludingUser(username, userId = null) {
        const params = [username];
        let where = 'username = $1';

        if (userId) {
            params.push(userId);
            where += ' AND user_id != $2';
        }

        const result = await query(
            `SELECT user_id, username FROM users WHERE ${where} LIMIT 1`,
            params
        );
        return result.rows[0];
    },

    async findByEmailExcludingUser(email, userId = null) {
        const params = [email];
        let where = 'email = $1';

        if (userId) {
            params.push(userId);
            where += ' AND user_id != $2';
        }

        const result = await query(
            `SELECT user_id, email FROM users WHERE ${where} LIMIT 1`,
            params
        );
        return result.rows[0];
    },

    /**
     * Get all users with filters
     */
    async findAll(filters = {}) {
        const { role, unit_id, is_active, limit = 100, offset = 0 } = filters;

        let whereClause = 'WHERE 1=1';
        let params = [];
        let paramCount = 0;

        if (role) {
            paramCount++;
            whereClause += ` AND role = $${paramCount}`;
            params.push(role);
        }

        if (unit_id) {
            paramCount++;
            whereClause += ` AND unit_id = $${paramCount}`;
            params.push(unit_id);
        }

        if (is_active !== undefined) {
            paramCount++;
            whereClause += ` AND is_active = $${paramCount}`;
            params.push(is_active);
        }

        paramCount++;
        params.push(limit);
        const limitParam = `$${paramCount}`;

        paramCount++;
        params.push(offset);
        const offsetParam = `$${paramCount}`;

        const result = await query(
            `SELECT user_id, username, full_name, email, phone_number, role,
                            unit_id, profile_photo_url, is_active, must_change_password, unit_confirmed, created_at
       FROM users
       ${whereClause}
       ORDER BY created_at DESC
       LIMIT ${limitParam} OFFSET ${offsetParam}`,
            params
        );

        return result.rows;
    },

    /**
     * Create new user
     */
    async create(userData) {
        const {
            username, password_hash, full_name, email, phone_number,
            role, unit_id, profile_photo_url, created_by
        } = userData;

        // Generate user_id using MAX to avoid collisions after deletions
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(user_id FROM 5) AS INTEGER)), 0) as max_num FROM users WHERE user_id ~ '^USR-[0-9]+$'`);
        const nextNum = parseInt(idResult.rows[0].max_num) + 1;
        const user_id = `USR-${String(nextNum).padStart(3, '0')}`;

        const result = await query(
            `INSERT INTO users (
        user_id, username, password_hash, full_name, email, phone_number,
                role, unit_id, profile_photo_url, created_by
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING user_id, username, full_name, email, role, unit_id, profile_photo_url, is_active, must_change_password`,
                        [user_id, username, password_hash, full_name, email, phone_number, role, unit_id || null, profile_photo_url || null, created_by]
        );

        return result.rows[0];
    },

    /**
     * Update user
     */
    async update(userId, updates) {
        const fields = [];
        const values = [];
        let paramCount = 0;

        Object.entries(updates).forEach(([key, value]) => {
            if (value !== undefined) {
                paramCount++;
                fields.push(`${key} = $${paramCount}`);
                values.push(value);
            }
        });

        if (fields.length === 0) return null;

        paramCount++;
        values.push(userId);

        const result = await query(
            `UPDATE users 
       SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $${paramCount}
       RETURNING user_id, username, full_name, email, role, unit_id, profile_photo_url, is_active, must_change_password`,
            values
        );

        if (result.rows.length > 0 && (updates.unit_id !== undefined || updates.role !== undefined)) {
            const updatedUser = result.rows[0];
            const isEligibleRole = ['admin', 'hq_firearm_commander', 'station_commander'].includes(updatedUser.role);
            
            if (!isEligibleRole || !updatedUser.unit_id) {
                await query('UPDATE units SET commander_user_id = NULL, commander_name = NULL WHERE commander_user_id = $1', [userId]);
            } else {
                await query('UPDATE units SET commander_user_id = NULL, commander_name = NULL WHERE commander_user_id = $1 AND unit_id != $2', [userId, updatedUser.unit_id]);
            }
        }

        return result.rows[0];
    },

    /**
     * Delete user (hard delete)
     * Deletes dependent operational records and clears nullable references
     * before deleting the user.
     * Wrapped in a transaction to prevent partial deletions
     */
    async delete(userId) {
        return await withTransaction(async (client) => {
            await client.query(`
                UPDATE units
                SET commander_user_id = NULL, commander_name = NULL
                WHERE commander_user_id = $1
            `, [userId]);

            await client.query(`
                UPDATE users
                SET created_by = NULL
                WHERE created_by = $1 AND user_id != $1
            `, [userId]);

            await client.query(`
                UPDATE device_enrollment_pins
                SET created_by = NULL
                WHERE created_by = $1
            `, [userId]);

            await client.query(`
                UPDATE officer_devices
                SET
                    enrolled_by = CASE WHEN enrolled_by = $1 THEN NULL ELSE enrolled_by END,
                    revoked_by = CASE WHEN revoked_by = $1 THEN NULL ELSE revoked_by END
                WHERE enrolled_by = $1 OR revoked_by = $1
            `, [userId]);

            await client.query(`
                UPDATE officer_verification_requests
                SET
                    requested_by = CASE WHEN requested_by = $1 THEN NULL ELSE requested_by END,
                    consumed_by = CASE WHEN consumed_by = $1 THEN NULL ELSE consumed_by END
                WHERE requested_by = $1 OR consumed_by = $1
            `, [userId]);

            await client.query(`
                UPDATE officer_verification_events
                SET actor_user_id = NULL
                WHERE actor_user_id = $1
            `, [userId]);

            await client.query(`
                UPDATE system_settings
                SET updated_by = NULL
                WHERE updated_by = $1
            `, [userId]);

            await client.query(`
                DELETE FROM anomaly_investigations
                WHERE investigator_id = $1
                   OR anomaly_id IN (
                        SELECT anomaly_id
                        FROM anomalies
                        WHERE firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                           OR custody_record_id IN (
                                SELECT custody_id
                                FROM custody_records
                                WHERE issued_by = $1
                                   OR returned_to = $1
                                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                           )
                           OR removed_from_dashboard_by = $1
                           OR archived_by = $1
                           OR investigated_by = $1
                           OR explanation_by = $1
                           OR explanation_requested_by = $1
                   )
            `, [userId]);

            await client.query(`
                DELETE FROM ballistic_access_logs
                WHERE accessed_by = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   OR ballistic_id IN (
                        SELECT ballistic_id
                        FROM ballistic_profiles
                        WHERE created_by = $1
                           OR locked_by = $1
                           OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   )
            `, [userId]);

            await client.query(`
                DELETE FROM ml_training_features
                WHERE firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   OR custody_record_id IN (
                        SELECT custody_id
                        FROM custody_records
                        WHERE issued_by = $1
                           OR returned_to = $1
                           OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   )
            `, [userId]);

            await client.query(`
                DELETE FROM officer_verification_requests
                WHERE firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   OR custody_id IN (
                        SELECT custody_id
                        FROM custody_records
                        WHERE issued_by = $1
                           OR returned_to = $1
                           OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   )
            `, [userId]);

            await client.query(`
                DELETE FROM anomalies
                WHERE firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   OR custody_record_id IN (
                        SELECT custody_id
                        FROM custody_records
                        WHERE issued_by = $1
                           OR returned_to = $1
                           OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   )
                   OR removed_from_dashboard_by = $1
                   OR archived_by = $1
                   OR investigated_by = $1
                   OR explanation_by = $1
                   OR explanation_requested_by = $1
            `, [userId]);

            await client.query(`
                DELETE FROM firearm_unit_movements
                WHERE authorized_by = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   OR custody_record_id IN (
                        SELECT custody_id
                        FROM custody_records
                        WHERE issued_by = $1
                           OR returned_to = $1
                           OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
                   )
            `, [userId]);

            await client.query(`
                DELETE FROM loss_reports
                WHERE reported_by = $1
                   OR reviewed_by = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
            `, [userId]);

            await client.query(`
                DELETE FROM destruction_requests
                WHERE requested_by = $1
                   OR reviewed_by = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
            `, [userId]);

            await client.query(`
                DELETE FROM procurement_requests
                WHERE requested_by = $1 OR reviewed_by = $1
            `, [userId]);

            await client.query(`
                DELETE FROM audit_logs
                WHERE user_id = $1
            `, [userId]);

            await client.query(`
                DELETE FROM custody_records
                WHERE issued_by = $1
                   OR returned_to = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
            `, [userId]);

            await client.query(`
                DELETE FROM ballistic_profiles
                WHERE created_by = $1
                   OR locked_by = $1
                   OR firearm_id IN (SELECT firearm_id FROM firearms WHERE registered_by = $1)
            `, [userId]);

            await client.query(`
                DELETE FROM firearms
                WHERE registered_by = $1
            `, [userId]);

            const result = await client.query(
                'DELETE FROM users WHERE user_id = $1 RETURNING user_id',
                [userId]
            );

            return result.rows[0];
        });
    },

    /**
     * Get user count by role
     */
    async countByRole() {
        const result = await query(`
      SELECT role, COUNT(*) as count
      FROM users
      WHERE is_active = true
      GROUP BY role
    `);

        return result.rows;
    },

    /**
     * Get user statistics
     */
    async getStats() {
        const result = await query(`
            SELECT 
                COUNT(*) as total_users,
                COUNT(*) FILTER (WHERE is_active = true) as active_users,
                COUNT(*) FILTER (WHERE role = 'admin') as admins,
                COUNT(*) FILTER (WHERE role = 'hq_firearm_commander') as hq_commanders,
                COUNT(*) FILTER (WHERE role = 'station_commander') as station_commanders,
                COUNT(*) FILTER (WHERE role = 'investigator') as investigators
            FROM users
        `);
        return result.rows[0];
    }
};

module.exports = User;
