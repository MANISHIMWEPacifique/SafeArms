const { query } = require('../config/database');

/**
 * CustodyRecord Model
 * 
 * Chain-of-custody tracking for firearms.
 * - All custody records are IMMUTABLE after creation (core fields)
 * - Cross-unit transfers are explicitly detected and flagged
 * - Supports timeline reconstruction for forensic traceability
 */

const CustodyRecord = {
    async findById(custodyId) {
        const result = await query(`
            SELECT cr.*, 
                   f.serial_number, f.manufacturer, f.model,
                   o.full_name as officer_name, o.rank,
                   u.unit_name,
                   issued_user.full_name as issued_by_name,
                   returned_user.full_name as returned_to_name
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN officers o ON cr.officer_id = o.officer_id
            JOIN units u ON cr.unit_id = u.unit_id
            LEFT JOIN users issued_user ON cr.issued_by = issued_user.user_id
            LEFT JOIN users returned_user ON cr.returned_to = returned_user.user_id
            WHERE cr.custody_id = $1
        `, [custodyId]);
        return result.rows[0];
    },

    async findByFirearmId(firearmId, limit = 50) {
        const result = await query(`
            SELECT cr.*, o.full_name as officer_name, u.unit_name,
                   issued_user.full_name as issued_by_name,
                   returned_user.full_name as returned_to_name
            FROM custody_records cr
            JOIN officers o ON cr.officer_id = o.officer_id
            JOIN units u ON cr.unit_id = u.unit_id
            LEFT JOIN users issued_user ON cr.issued_by = issued_user.user_id
            LEFT JOIN users returned_user ON cr.returned_to = returned_user.user_id
            WHERE cr.firearm_id = $1
            ORDER BY cr.issued_at DESC
            LIMIT $2
        `, [firearmId, limit]);
        return result.rows;
    },

    async findByOfficerId(officerId, limit = 50) {
        const result = await query(`
            SELECT cr.*, f.serial_number, f.manufacturer, f.model, u.unit_name
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN units u ON cr.unit_id = u.unit_id
            WHERE cr.officer_id = $1
            ORDER BY cr.issued_at DESC
            LIMIT $2
        `, [officerId, limit]);
        return result.rows;
    },

    async findActive(filters = {}) {
        const { unit_id, officer_id, limit = 100 } = filters;
        let where = 'WHERE cr.returned_at IS NULL';
        let params = [];
        let pCount = 0;

        if (unit_id) {
            pCount++;
            where += ` AND cr.unit_id = $${pCount}`;
            params.push(unit_id);
        }

        if (officer_id) {
            pCount++;
            where += ` AND cr.officer_id = $${pCount}`;
            params.push(officer_id);
        }

        pCount++;
        params.push(limit);

        const result = await query(`
            SELECT cr.*, 
                   f.serial_number, f.manufacturer, f.model,
                   o.full_name as officer_name, o.rank,
                   u.unit_name
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN officers o ON cr.officer_id = o.officer_id
            JOIN units u ON cr.unit_id = u.unit_id
            ${where}
            ORDER BY cr.issued_at DESC
            LIMIT $${pCount}
        `, params);
        return result.rows;
    },

    /**
     * Detect if this custody assignment is a cross-unit transfer
     * Returns the previous unit if it differs from current
     */
    async detectCrossUnitTransfer(firearmId, newUnitId) {
        const result = await query(`
            SELECT cr.unit_id as previous_unit_id, u.unit_name as previous_unit_name
            FROM custody_records cr
            JOIN units u ON cr.unit_id = u.unit_id
            WHERE cr.firearm_id = $1
            ORDER BY cr.issued_at DESC
            LIMIT 1
        `, [firearmId]);

        if (result.rows.length === 0) {
            return { isCrossUnit: false, previousUnitId: null };
        }

        const previousUnitId = result.rows[0].previous_unit_id;
        return {
            isCrossUnit: previousUnitId !== newUnitId,
            previousUnitId,
            previousUnitName: result.rows[0].previous_unit_name
        };
    },

    /**
     * Get full custody chain timeline with cross-unit flags
     * Uses the database view for efficiency
     */
    async getCustodyChainTimeline(firearmId) {
        const result = await query(`
            SELECT * FROM custody_chain_timeline
            WHERE firearm_id = $1
            ORDER BY custody_sequence ASC
        `, [firearmId]);
        return result.rows;
    },

    /**
     * Get unified timeline (custody + ballistic access events)
     * Uses the unified_firearm_events_timeline view
     */
    async getUnifiedTimeline(firearmId, options = {}) {
        const { categories, limit = 100 } = options;
        
        let whereClause = 'WHERE firearm_id = $1';
        let params = [firearmId];
        let pCount = 1;

        if (categories && categories.length > 0) {
            pCount++;
            whereClause += ` AND event_category = ANY($${pCount})`;
            params.push(categories);
        }

        pCount++;
        params.push(limit);

        const result = await query(`
            SELECT * FROM unified_firearm_events_timeline
            ${whereClause}
            ORDER BY event_timestamp DESC, event_priority
            LIMIT $${pCount}
        `, params);
        return result.rows;
    },

    /**
     * Get cross-unit transfer history for a firearm
     */
    async getCrossUnitTransfers(firearmId) {
        const result = await query(`
            SELECT 
                cr.custody_id,
                cr.issued_at as transfer_date,
                prev_unit.unit_name as from_unit,
                curr_unit.unit_name as to_unit,
                o.full_name as assigned_to_officer,
                issuer.full_name as authorized_by
            FROM custody_records cr
            JOIN units curr_unit ON cr.unit_id = curr_unit.unit_id
            JOIN officers o ON cr.officer_id = o.officer_id
            LEFT JOIN users issuer ON cr.issued_by = issuer.user_id
            LEFT JOIN LATERAL (
                SELECT unit_id 
                FROM custody_records prev
                WHERE prev.firearm_id = cr.firearm_id 
                  AND prev.issued_at < cr.issued_at
                ORDER BY prev.issued_at DESC
                LIMIT 1
            ) prev_custody ON true
            LEFT JOIN units prev_unit ON prev_custody.unit_id = prev_unit.unit_id
            WHERE cr.firearm_id = $1
              AND (prev_custody.unit_id IS NULL OR prev_custody.unit_id != cr.unit_id)
            ORDER BY cr.issued_at DESC
        `, [firearmId]);
        return result.rows;
    },

    /**
     * Count custody events for statistics
     */
    async getCustodyStats(firearmId) {
        const result = await query(`
            SELECT 
                COUNT(*) as total_custody_events,
                COUNT(DISTINCT officer_id) as unique_officers,
                COUNT(DISTINCT unit_id) as unique_units,
                COUNT(*) FILTER (WHERE returned_at IS NULL) as active_custody,
                MIN(issued_at) as first_custody_date,
                MAX(issued_at) as last_custody_date,
                SUM(custody_duration_seconds) as total_custody_seconds
            FROM custody_records
            WHERE firearm_id = $1
        `, [firearmId]);
        return result.rows[0];
    }
};

module.exports = CustodyRecord;
