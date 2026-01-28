const { query } = require('../config/database');
const crypto = require('crypto');

/**
 * BallisticProfile Model
 * 
 * IMPORTANT: Ballistic profiles are IMMUTABLE after creation.
 * - No UPDATE operations allowed (forensic integrity)
 * - All access is logged for audit trail
 * - Chain-of-custody integration for traceability
 */

const BallisticProfile = {
    /**
     * Generate hash of profile data for integrity verification
     */
    generateRegistrationHash(profileData) {
        const dataString = JSON.stringify({
            firearm_id: profileData.firearm_id,
            test_date: profileData.test_date,
            rifling_characteristics: profileData.rifling_characteristics,
            firing_pin_impression: profileData.firing_pin_impression,
            ejector_marks: profileData.ejector_marks,
            extractor_marks: profileData.extractor_marks,
            chamber_marks: profileData.chamber_marks
        });
        return crypto.createHash('sha256').update(dataString).digest('hex');
    },

    /**
     * Log access to ballistic profile
     */
    async logAccess(ballisticId, userId, accessType, accessReason = null, ipAddress = null, userAgent = null) {
        try {
            const result = await query(
                `SELECT log_ballistic_access($1, $2, $3, $4, $5, $6) as access_id`,
                [ballisticId, userId, accessType, accessReason, ipAddress, userAgent]
            );
            return result.rows[0]?.access_id;
        } catch (error) {
            console.error('Failed to log ballistic access:', error);
            // Don't throw - logging failure shouldn't break the operation
            return null;
        }
    },

    async findById(ballisticId, requestingUserId = null, accessReason = null, reqInfo = {}) {
        const result = await query(`
            SELECT bp.*, f.serial_number, f.manufacturer, f.model, f.current_status,
                   f.assigned_unit_id, u.unit_name as assigned_unit_name
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            WHERE bp.ballistic_id = $1
        `, [ballisticId]);
        
        // Log access if user provided
        if (result.rows[0] && requestingUserId) {
            await this.logAccess(
                ballisticId, 
                requestingUserId, 
                'view_profile', 
                accessReason,
                reqInfo.ip,
                reqInfo.userAgent
            );
        }
        
        return result.rows[0];
    },

    async findByFirearmId(firearmId, requestingUserId = null, reqInfo = {}) {
        const result = await query(
            `SELECT bp.*, f.serial_number, f.manufacturer, f.model, f.current_status
             FROM ballistic_profiles bp
             JOIN firearms f ON bp.firearm_id = f.firearm_id
             WHERE bp.firearm_id = $1`,
            [firearmId]
        );
        
        // Log access if found and user provided
        if (result.rows[0] && requestingUserId) {
            await this.logAccess(
                result.rows[0].ballistic_id, 
                requestingUserId, 
                'view_profile',
                'Accessed via firearm lookup',
                reqInfo.ip,
                reqInfo.userAgent
            );
        }
        
        return result.rows[0];
    },

    /**
     * Create ballistic profile (IMMUTABLE after creation)
     * Only HQ Commander can create during firearm registration
     */
    async create(profileData, createdByUserId) {
        const { 
            firearm_id, test_date, test_location, rifling_characteristics, 
            firing_pin_impression, ejector_marks, extractor_marks, chamber_marks,
            test_conducted_by, forensic_lab, test_ammunition, notes 
        } = profileData;

        // Generate integrity hash
        const registrationHash = this.generateRegistrationHash(profileData);

        const result = await query(`
            INSERT INTO ballistic_profiles (
                firearm_id, test_date, test_location, rifling_characteristics,
                firing_pin_impression, ejector_marks, extractor_marks, chamber_marks,
                test_conducted_by, forensic_lab, test_ammunition, notes,
                created_by, is_locked, locked_at, locked_by, registration_hash
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, true, CURRENT_TIMESTAMP, $13, $14)
            RETURNING *
        `, [
            firearm_id, test_date, test_location, rifling_characteristics, 
            firing_pin_impression, ejector_marks, extractor_marks, chamber_marks,
            test_conducted_by, forensic_lab, test_ammunition, notes,
            createdByUserId, registrationHash
        ]);

        return result.rows[0];
    },

    // UPDATE REMOVED - Ballistic profiles are immutable after HQ registration
    // This ensures forensic integrity for investigative purposes

    /**
     * Search ballistic profiles with access logging
     */
    async search(searchParams, requestingUserId = null, reqInfo = {}) {
        const { test_location, forensic_lab, firearm_serial, limit = 50 } = searchParams;
        let where = 'WHERE 1=1';
        let params = [];
        let pCount = 0;

        if (test_location) {
            pCount++;
            where += ` AND bp.test_location ILIKE $${pCount}`;
            params.push(`%${test_location}%`);
        }

        if (forensic_lab) {
            pCount++;
            where += ` AND bp.forensic_lab = $${pCount}`;
            params.push(forensic_lab);
        }

        if (firearm_serial) {
            pCount++;
            where += ` AND f.serial_number ILIKE $${pCount}`;
            params.push(`%${firearm_serial}%`);
        }

        pCount++;
        params.push(limit);

        const result = await query(`
            SELECT bp.*, f.serial_number, f.manufacturer, f.model, f.current_status,
                   f.assigned_unit_id, u.unit_name as assigned_unit_name
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            ${where}
            ORDER BY bp.test_date DESC
            LIMIT $${pCount}
        `, params);

        // Log search query (not individual results) for audit purposes
        if (requestingUserId && result.rows.length > 0) {
            // Log one access event for the search operation
            await query(`
                INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address, user_agent)
                VALUES ($1, 'SEARCH', 'ballistic_profiles', $2, $3, $4)
            `, [
                requestingUserId,
                JSON.stringify({ search_params: searchParams, result_count: result.rows.length }),
                reqInfo.ip,
                reqInfo.userAgent
            ]);
        }

        return result.rows;
    },

    /**
     * Get access history for a ballistic profile
     */
    async getAccessHistory(ballisticId, limit = 100) {
        const result = await query(`
            SELECT 
                bal.*,
                u.full_name as accessed_by_name,
                u.role as accessed_by_role,
                o.full_name as custody_officer_name,
                unit.unit_name as custody_unit_name
            FROM ballistic_access_logs bal
            JOIN users u ON bal.accessed_by = u.user_id
            LEFT JOIN officers o ON bal.current_custody_officer_id = o.officer_id
            LEFT JOIN units unit ON bal.current_custody_unit_id = unit.unit_id
            WHERE bal.ballistic_id = $1
            ORDER BY bal.accessed_at DESC
            LIMIT $2
        `, [ballisticId, limit]);
        return result.rows;
    },

    /**
     * Verify integrity of ballistic profile
     */
    async verifyIntegrity(ballisticId) {
        const profile = await query(
            'SELECT * FROM ballistic_profiles WHERE ballistic_id = $1',
            [ballisticId]
        );
        
        if (!profile.rows[0]) {
            return { valid: false, error: 'Profile not found' };
        }

        const storedHash = profile.rows[0].registration_hash;
        const currentHash = this.generateRegistrationHash(profile.rows[0]);

        return {
            valid: storedHash === currentHash,
            is_locked: profile.rows[0].is_locked,
            locked_at: profile.rows[0].locked_at,
            registration_hash: storedHash
        };
    }
};

module.exports = BallisticProfile;
