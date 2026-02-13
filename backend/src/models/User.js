const { query } = require('../config/database');

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
              unit_id, is_active, must_change_password, unit_confirmed, last_login
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
              unit_id, is_active, must_change_password, unit_confirmed, created_at
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
            role, unit_id, created_by
        } = userData;

        // Generate user_id
        const idResult = await query(`SELECT COUNT(*) as count FROM users`);
        const count = parseInt(idResult.rows[0].count) + 1;
        const user_id = `USR-${String(count).padStart(3, '0')}`;

        const result = await query(
            `INSERT INTO users (
        user_id, username, password_hash, full_name, email, phone_number,
        role, unit_id, created_by
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
      RETURNING user_id, username, full_name, email, role, unit_id, is_active, must_change_password`,
            [user_id, username, password_hash, full_name, email, phone_number, role, unit_id || null, created_by]
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
       RETURNING user_id, username, full_name, email, role, unit_id, is_active, must_change_password`,
            values
        );

        return result.rows[0];
    },

    /**
     * Delete user (soft delete)
     */
    async delete(userId) {
        const result = await query(
            'UPDATE users SET is_active = false WHERE user_id = $1 RETURNING user_id',
            [userId]
        );

        return result.rows[0];
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
