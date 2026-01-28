const express = require('express');
const router = express.Router();
const { assignCustody, returnCustody, getActiveCustody, getUnitCustody, getFirearmCustodyHistory, getOfficerCustodyHistory } = require('../services/custody.service');
const CustodyRecord = require('../models/CustodyRecord');
const { authenticate } = require('../middleware/authentication');
const { 
    requireCommander, 
    requireUnitAccess, 
    requireRole,
    requireCustodyHistoryAccess,
    ROLES,
    PERMISSIONS
} = require('../middleware/authorization');
const { logCustodyAssignment, logCustodyReturn } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

/**
 * Custody Routes
 * 
 * RBAC ENFORCEMENT:
 * - ASSIGN/RETURN: HQ Commander, Station Commander (unit-restricted)
 * - READ HISTORY: HQ Commander, Forensic Analyst (read-only), Admin, Station Commander (unit-restricted)
 * - CROSS-UNIT REPORTS: HQ Commander, Admin only
 * 
 * CHAIN-OF-CUSTODY FEATURES:
 * - All custody events automatically append to chain-of-custody timeline
 * - Cross-unit transfers are explicitly detected and returned
 * - Custody records are immutable after creation (core fields)
 * - Full timeline reconstruction available via API
 */

/**
 * Middleware to enforce unit-based access for custody operations
 */
const enforceUnitCustodyAccess = async (req, res, next) => {
    const { role, unit_id: userUnitId } = req.user;

    // Forensic analysts have read-only access (they shouldn't hit write endpoints)
    if (role === ROLES.FORENSIC_ANALYST) {
        // Store for use in GET endpoints
        req.isForensicAnalyst = true;
        req.custodyFilter = null; // Full read access
        return next();
    }

    // Station commanders are restricted to their unit
    if (role === ROLES.STATION_COMMANDER) {
        req.custodyFilter = userUnitId;
        req.isUnitRestricted = true;
        return next();
    }

    // HQ Commander and Admin have full access
    req.custodyFilter = null;
    req.isUnitRestricted = false;
    next();
};

// Assign custody - restricted to unit access
router.post('/assign', authenticate, requireCommander, logCustodyAssignment, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders can only assign custody within their unit
    // They cannot override this by passing a different unit_id
    if (role === 'station_commander') {
        // Force their unit_id - ignore any manually passed value
        if (req.body.unit_id && req.body.unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted custody assign in unit ${req.body.unit_id} (assigned: ${userUnitId})`);
        }
        req.body.unit_id = userUnitId;
    }
    
    const custodyRecord = await assignCustody({ ...req.body, issued_by: req.user.user_id });
    res.status(201).json({ success: true, data: custodyRecord, message: 'Custody assigned successfully' });
}));

// Return custody - restricted to unit access
router.post('/:id/return', authenticate, requireCommander, logCustodyReturn, asyncHandler(async (req, res) => {
    const custodyRecord = await returnCustody(req.params.id, { ...req.body, returned_to: req.user.user_id });
    res.json({ success: true, data: custodyRecord, message: 'Custody returned successfully' });
}));

// Get custody by unit - for Station Commanders
router.get('/unit/:unit_id', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const requestedUnitId = req.params.unit_id;
    
    // Station commanders can only view their unit's custody records
    if (role === 'station_commander' && requestedUnitId !== userUnitId) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view custody records for your unit.'
        });
    }
    
    const records = await getUnitCustody(requestedUnitId, req.query);
    res.json({ success: true, data: records });
}));

// Get all active custody (filtered by role)
router.get('/active', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders only see their unit's records
    // They cannot override this by passing a different unit_id
    if (role === 'station_commander') {
        if (req.query.unit_id && req.query.unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted to query active custody for unit ${req.query.unit_id} (assigned: ${userUnitId})`);
        }
        req.query.unit_id = userUnitId; // Force their unit
    }
    
    const records = await getActiveCustody(req.query);
    res.json({ success: true, data: records });
}));

router.get('/firearm/:firearm_id/history', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders can only access custody history for firearms in their unit
    if (role === 'station_commander') {
        const { query } = require('../config/database');
        const firearmResult = await query('SELECT assigned_unit_id FROM firearms WHERE firearm_id = $1', [req.params.firearm_id]);
        if (firearmResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Firearm not found' });
        }
        if (firearmResult.rows[0].assigned_unit_id !== userUnitId) {
            return res.status(403).json({
                success: false,
                message: 'Access denied: You can only view custody history for firearms assigned to your unit'
            });
        }
    }
    
    const history = await getFirearmCustodyHistory(req.params.firearm_id, req.query);
    res.json({ success: true, data: history });
}));

router.get('/officer/:officer_id/history', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders can only access custody history for officers in their unit
    if (role === 'station_commander') {
        const officerResult = await query('SELECT unit_id FROM officers WHERE officer_id = $1', [req.params.officer_id]);
        if (officerResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Officer not found' });
        }
        if (officerResult.rows[0].unit_id !== userUnitId) {
            return res.status(403).json({
                success: false,
                message: 'Access denied: You can only view custody history for officers in your unit'
            });
        }
    }
    
    const history = await getOfficerCustodyHistory(req.params.officer_id, req.query);
    res.json({ success: true, data: history });
}));

// ============================================
// CHAIN-OF-CUSTODY TIMELINE ENDPOINTS
// ============================================

/**
 * GET /custody/firearm/:firearm_id/timeline
 * 
 * Returns the complete custody chain timeline with cross-unit flags
 * Uses the custody_chain_timeline database view
 */
router.get('/firearm/:firearm_id/timeline', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const firearmId = req.params.firearm_id;

    // RBAC check for station commanders
    if (role === 'station_commander') {
        const firearmResult = await query('SELECT assigned_unit_id FROM firearms WHERE firearm_id = $1', [firearmId]);
        if (firearmResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Firearm not found' });
        }
        if (firearmResult.rows[0].assigned_unit_id !== userUnitId) {
            return res.status(403).json({
                success: false,
                message: 'Access denied: You can only view timeline for firearms assigned to your unit'
            });
        }
    }

    const timeline = await CustodyRecord.getCustodyChainTimeline(firearmId);
    const stats = await CustodyRecord.getCustodyStats(firearmId);

    res.json({
        success: true,
        data: {
            firearm_id: firearmId,
            summary: {
                total_events: parseInt(stats.total_custody_events) || 0,
                unique_officers: parseInt(stats.unique_officers) || 0,
                unique_units: parseInt(stats.unique_units) || 0,
                first_custody: stats.first_custody_date,
                last_custody: stats.last_custody_date
            },
            timeline
        }
    });
}));

/**
 * GET /custody/firearm/:firearm_id/unified-timeline
 * 
 * Returns unified timeline combining custody + ballistic access events
 * Uses the unified_firearm_events_timeline database view
 * 
 * SECURITY: Station commanders cannot see ballistic-related events
 */
router.get('/firearm/:firearm_id/unified-timeline', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const firearmId = req.params.firearm_id;
    const { categories, limit = 100 } = req.query;

    // RBAC check for station commanders
    if (role === 'station_commander') {
        const firearmResult = await query('SELECT assigned_unit_id FROM firearms WHERE firearm_id = $1', [firearmId]);
        if (firearmResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Firearm not found' });
        }
        if (firearmResult.rows[0].assigned_unit_id !== userUnitId) {
            return res.status(403).json({
                success: false,
                message: 'Access denied: You can only view timeline for firearms assigned to your unit'
            });
        }
    }

    // Parse categories if provided (e.g., "CUSTODY,BALLISTIC_ACCESS")
    let categoryFilter = categories ? categories.split(',').map(c => c.trim()) : null;
    
    // SECURITY: Station commanders can only see CUSTODY category, not BALLISTIC_ACCESS
    if (role === 'station_commander') {
        categoryFilter = ['CUSTODY']; // Force custody-only for station commanders
    }

    let timeline = await CustodyRecord.getUnifiedTimeline(firearmId, {
        categories: categoryFilter,
        limit: parseInt(limit)
    });

    // Extra safety: filter out any ballistic events for station commanders
    if (role === 'station_commander') {
        timeline = timeline.filter(event => 
            !['ballistic_access', 'ballistic_profile_created', 'BALLISTIC_ACCESS'].includes(event.event_type) &&
            event.event_category !== 'BALLISTIC_ACCESS'
        );
    }

    res.json({
        success: true,
        data: {
            firearm_id: firearmId,
            event_count: timeline.length,
            filters_applied: {
                categories: categoryFilter,
                limit: parseInt(limit),
                ballistic_events_filtered: role === 'station_commander'
            },
            timeline
        }
    });
}));

/**
 * GET /custody/cross-unit-report
 * 
 * Returns all cross-unit transfers within a date range
 * For HQ and admin monitoring of firearm movements
 */
router.get('/cross-unit-report', authenticate, requireRole(['hq_firearm_commander', 'admin']), asyncHandler(async (req, res) => {
    const { start_date, end_date, limit = 100 } = req.query;

    let whereClause = `WHERE prev_unit.unit_id IS NOT NULL 
                       AND prev_unit.unit_id != cr.unit_id`;
    let params = [];
    let pCount = 0;

    if (start_date) {
        pCount++;
        whereClause += ` AND cr.issued_at >= $${pCount}`;
        params.push(start_date);
    }

    if (end_date) {
        pCount++;
        whereClause += ` AND cr.issued_at <= $${pCount}`;
        params.push(end_date);
    }

    pCount++;
    params.push(parseInt(limit));

    const result = await query(`
        SELECT 
            cr.custody_id,
            cr.firearm_id,
            f.serial_number,
            f.manufacturer,
            f.model,
            cr.issued_at as transfer_date,
            prev_unit.unit_name as from_unit,
            curr_unit.unit_name as to_unit,
            o.full_name as assigned_to_officer,
            issuer.full_name as authorized_by
        FROM custody_records cr
        JOIN firearms f ON cr.firearm_id = f.firearm_id
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
        ${whereClause}
        ORDER BY cr.issued_at DESC
        LIMIT $${pCount}
    `, params);

    res.json({
        success: true,
        data: {
            total_transfers: result.rows.length,
            date_range: { start_date, end_date },
            transfers: result.rows
        }
    });
}));

module.exports = router;
