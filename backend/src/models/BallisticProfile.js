const { query } = require('../config/database');
const crypto = require('crypto');

const normalizeSearchValue = (value) => (
    typeof value === 'string' && value.trim().length > 0
        ? value.trim()
        : null
);

const evidenceStrength = (score, heldAtIncident) => {
    if (heldAtIncident && score >= 70) return 'Strong candidate';
    if (score >= 45 || heldAtIncident) return 'Partial candidate';
    return 'Reference match';
};

const parseMatchedFields = (value) => {
    if (!value) return [];
    if (Array.isArray(value)) return value.filter(Boolean);
    if (typeof value === 'string') {
        try {
            const parsed = JSON.parse(value);
            return Array.isArray(parsed) ? parsed.filter(Boolean) : [];
        } catch (_) {
            return [];
        }
    }
    return [];
};

const mapSearchResult = (row, hasIncidentDate) => {
    const heldAtIncident = row.held_at_incident === true || row.held_at_incident === 'true';
    const matchScore = Number.parseInt(row.match_score, 10) || 0;
    const matchedFields = parseMatchedFields(row.matched_fields);

    return {
        ...row,
        match_score: matchScore,
        matched_fields: matchedFields,
        evidence_strength: evidenceStrength(matchScore, heldAtIncident),
        incident_custody: hasIncidentDate
            ? {
                held_at_incident: heldAtIncident,
                custody_id: row.incident_custody_id || null,
                officer_id: row.incident_officer_id || null,
                officer_name: row.incident_officer_name || null,
                officer_rank: row.incident_officer_rank || null,
                unit_id: row.incident_unit_id || null,
                unit_name: row.incident_unit_name || null,
                issued_at: row.incident_issued_at || null,
                returned_at: row.incident_returned_at || null
            }
            : {
                held_at_incident: false
            },
        incident_custody_id: undefined,
        incident_officer_id: undefined,
        incident_officer_name: undefined,
        incident_officer_rank: undefined,
        incident_unit_id: undefined,
        incident_unit_name: undefined,
        incident_issued_at: undefined,
        incident_returned_at: undefined,
        held_at_incident: undefined
    };
};

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

        // Generate ballistic_id
        const idResult = await query(`SELECT COALESCE(MAX(CAST(SUBSTRING(ballistic_id FROM 4) AS INTEGER)), 0) as max_num FROM ballistic_profiles WHERE ballistic_id ~ '^BP-[0-9]+$'`);
        const nextNum = parseInt(idResult.rows[0].max_num) + 1;
        const ballistic_id = `BP-${String(nextNum).padStart(3, '0')}`;

        const result = await query(`
            INSERT INTO ballistic_profiles (
                ballistic_id, firearm_id, test_date, test_location, rifling_characteristics,
                firing_pin_impression, ejector_marks, extractor_marks, chamber_marks,
                test_conducted_by, forensic_lab, test_ammunition, notes,
                created_by, is_locked, locked_at, locked_by, registration_hash
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, true, CURRENT_TIMESTAMP, $14, $15)
            RETURNING *
        `, [
            ballistic_id,
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
     * Supports filtering by all 5 ballistic characteristics:
     * 1. Firing Pin Shape/Pattern (firing_pin_impression)
     * 2. Caliber/Chambering (caliber from firearms table)
     * 3. Barrel Rifling (rifling_characteristics)
     * 4. Chamber/Feed System (chamber_marks)
     * 5. Breech Face Pattern (ejector_marks, extractor_marks)
     */
    async search(searchParams, requestingUserId = null, reqInfo = {}) {
        const { 
            test_location, forensic_lab, firearm_serial, 
            // Ballistic characteristic filters
            firing_pin, caliber, rifling, chamber_feed, breech_face,
            // General search
            search,
            // Date-based custody search
            incident_date,
            incident_date_mode = 'filter',
            // Pagination
            page = 1,
            limit = 20 
        } = searchParams;
        const pageNum = Math.max(1, parseInt(page) || 1);
        const pageSize = Math.min(100, Math.max(1, parseInt(limit) || 20));
        const offset = (pageNum - 1) * pageSize;
        const incidentDateMode = incident_date_mode === 'annotate' ? 'annotate' : 'filter';
        const hasIncidentDate = Boolean(normalizeSearchValue(incident_date));

        let where = 'WHERE 1=1';
        let joins = '';
        let params = [];
        let pCount = 0;
        const scoreParts = [];
        const matchedFieldParts = [];

        const addFilter = ({ value, condition, paramValue, score, label }) => {
            const cleanValue = normalizeSearchValue(value);
            if (!cleanValue) return;

            pCount++;
            where += ` AND ${condition(pCount)}`;
            params.push(paramValue(cleanValue));
            scoreParts.push(`CASE WHEN ${condition(pCount)} THEN ${score} ELSE 0 END`);
            matchedFieldParts.push(`CASE WHEN ${condition(pCount)} THEN '${label}' ELSE NULL END`);
        };

        addFilter({
            value: test_location,
            condition: (param) => `bp.test_location ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 5,
            label: 'Test location'
        });

        addFilter({
            value: forensic_lab,
            condition: (param) => `bp.forensic_lab ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 5,
            label: 'Forensic lab'
        });

        addFilter({
            value: firearm_serial,
            condition: (param) => `f.serial_number ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 20,
            label: 'Serial number'
        });

        // 1. Firing Pin Shape/Pattern
        addFilter({
            value: firing_pin,
            condition: (param) => `bp.firing_pin_impression ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 20,
            label: 'Firing pin'
        });

        // 2. Caliber/Chambering
        addFilter({
            value: caliber,
            condition: (param) => `f.caliber ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 15,
            label: 'Caliber'
        });

        // 3. Barrel Rifling
        addFilter({
            value: rifling,
            condition: (param) => `bp.rifling_characteristics ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 20,
            label: 'Rifling'
        });

        // 4. Chamber/Feed System
        addFilter({
            value: chamber_feed,
            condition: (param) => `bp.chamber_marks ILIKE $${param}`,
            paramValue: (value) => `%${value}%`,
            score: 15,
            label: 'Chamber/feed'
        });

        // 5. Breech Face Pattern (searches both ejector and extractor marks)
        addFilter({
            value: breech_face,
            condition: (param) => `(bp.ejector_marks ILIKE $${param} OR bp.extractor_marks ILIKE $${param})`,
            paramValue: (value) => `%${value}%`,
            score: 20,
            label: 'Breech face'
        });

        // General search across all characteristics
        addFilter({
            value: search,
            condition: (param) => `(
                f.serial_number ILIKE $${param} OR
                f.manufacturer ILIKE $${param} OR
                f.model ILIKE $${param} OR
                f.caliber ILIKE $${param} OR
                bp.firing_pin_impression ILIKE $${param} OR
                bp.rifling_characteristics ILIKE $${param} OR
                bp.chamber_marks ILIKE $${param} OR
                bp.ejector_marks ILIKE $${param} OR
                bp.extractor_marks ILIKE $${param}
            )`,
            paramValue: (value) => `%${value}%`,
            score: 10,
            label: 'General evidence'
        });

        // Date-based custody search: find firearms that had custody on a specific date
        if (hasIncidentDate) {
            pCount++;
            const incidentDateParam = pCount;
            const incidentCustodyJoin = `
                LEFT JOIN LATERAL (
                    SELECT cr.custody_id, cr.officer_id, o.full_name as officer_name,
                           o.rank as officer_rank, cr.unit_id, u.unit_name,
                           cr.issued_at, cr.returned_at
                    FROM custody_records cr
                    JOIN officers o ON cr.officer_id = o.officer_id
                    JOIN units u ON cr.unit_id = u.unit_id
                    WHERE cr.firearm_id = f.firearm_id
                      AND cr.issued_at::date <= $${incidentDateParam}::date
                      AND (cr.returned_at IS NULL OR cr.returned_at::date >= $${incidentDateParam}::date)
                    ORDER BY cr.issued_at DESC
                    LIMIT 1
                ) incident_cr ON true
            `;
            joins += incidentCustodyJoin;
            if (incidentDateMode === 'filter') {
                where += ` AND incident_cr.custody_id IS NOT NULL`;
            }
            params.push(incident_date);
        }

        const scoreExpression = scoreParts.length > 0 ? scoreParts.join(' + ') : '0';
        const incidentBonusExpression = hasIncidentDate
            ? 'CASE WHEN COALESCE(incident_cr.custody_id IS NOT NULL, false) THEN 25 ELSE 0 END'
            : '0';
        const matchedFieldsExpression = matchedFieldParts.length > 0
            ? `to_jsonb(array_remove(ARRAY[${matchedFieldParts.join(', ')}], NULL))`
            : `'[]'::jsonb`;
        const orderBy = hasIncidentDate && incidentDateMode === 'annotate'
            ? 'held_at_incident DESC, match_score DESC, sort_test_date DESC'
            : 'match_score DESC, sort_test_date DESC';
        const incidentSelect = hasIncidentDate
            ? `
                   COALESCE(incident_cr.custody_id IS NOT NULL, false) as held_at_incident,
                   incident_cr.custody_id as incident_custody_id,
                   incident_cr.officer_id as incident_officer_id,
                   incident_cr.officer_name as incident_officer_name,
                   incident_cr.officer_rank as incident_officer_rank,
                   incident_cr.unit_id as incident_unit_id,
                   incident_cr.unit_name as incident_unit_name,
                   incident_cr.issued_at as incident_issued_at,
                   incident_cr.returned_at as incident_returned_at,`
            : `
                   false as held_at_incident,
                   NULL::varchar as incident_custody_id,
                   NULL::varchar as incident_officer_id,
                   NULL::text as incident_officer_name,
                   NULL::text as incident_officer_rank,
                   NULL::varchar as incident_unit_id,
                   NULL::text as incident_unit_name,
                   NULL::timestamp as incident_issued_at,
                   NULL::timestamp as incident_returned_at,`;

        // Count total results first
        const countParams = [...params];
        const countResult = await query(`
            SELECT COUNT(DISTINCT bp.ballistic_id) as total
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            ${joins}
            ${where}
        `, countParams);
        const total = parseInt(countResult.rows[0].total) || 0;

        // Fetch paginated results
        pCount++;
        params.push(pageSize);
        pCount++;
        params.push(offset);

        const result = await query(`
            SELECT DISTINCT bp.*, f.serial_number, f.manufacturer, f.model, f.caliber, f.firearm_type,
                   f.current_status, f.assigned_unit_id, u.unit_name as assigned_unit_name,
                   (${scoreExpression}) + ${incidentBonusExpression} as match_score,
                   ${matchedFieldsExpression} as matched_fields,
                   ${incidentSelect}
                   bp.test_date as sort_test_date
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            ${joins}
            ${where}
            ORDER BY ${orderBy}
            LIMIT $${pCount - 1} OFFSET $${pCount}
        `, params);

        // Log search query (not individual results) for audit purposes
        if (requestingUserId && result.rows.length > 0) {
            try {
                const logId = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
                // Log one access event for the search operation
                await query(`
                    INSERT INTO audit_logs (log_id, user_id, action_type, table_name, new_values, ip_address, user_agent)
                    VALUES ($1, $2, 'SEARCH', 'ballistic_profiles', $3, $4, $5)
                `, [
                    logId,
                    requestingUserId,
                    JSON.stringify({ search_params: searchParams, result_count: total }),
                    reqInfo.ip,
                    reqInfo.userAgent
                ]);
            } catch (error) {
                console.error('Failed to log ballistic search audit:', error);
            }
        }

        return {
            data: result.rows.map((row) => mapSearchResult(row, hasIncidentDate)),
            total,
            page: pageNum,
            pageSize,
            totalPages: Math.ceil(total / pageSize)
        };
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
