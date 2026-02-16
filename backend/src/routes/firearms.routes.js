const express = require('express');
const router = express.Router();
const Firearm = require('../models/Firearm');
const CustodyRecord = require('../models/CustodyRecord');
const BallisticProfile = require('../models/BallisticProfile');
const { authenticate } = require('../middleware/authentication');
const { 
    requireCommander, 
    requireHQCommander, 
    requireUnitAccess, 
    requireRole,
    enforceUnitFirearmAccess,
    ROLES 
} = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

/**
 * Firearms Routes - Chain of Custody and Registry Management
 * 
 * RBAC Summary:
 * - admin: Full access to all firearms and history
 * - hq_firearm_commander: Full access to all firearms, can create/update
 * - station_commander: Can only access firearms assigned to their unit
 *                      CANNOT access ballistic data (profiles, access history)
 * - investigator: Read-only access to all firearms and history including ballistic
 * 
 * NOTE: Station commanders are explicitly denied ballistic data even when 
 * accessing their unit's firearms. The full-history endpoint returns 
 * custody data only for station commanders.
 */

// Search firearms by serial number, manufacturer, model
router.get('/search', authenticate, asyncHandler(async (req, res) => {
    const { q } = req.query;
    const { role, unit_id: userUnitId } = req.user;
    
    if (!q || q.trim().length === 0) {
        return res.json({ success: true, data: [] });
    }
    
    let unitFilter = '';
    let params = [`%${q}%`, `%${q}%`, `%${q}%`];
    
    // Station commanders can only search within their unit
    if (role === 'station_commander') {
        unitFilter = 'AND f.assigned_unit_id = $4';
        params.push(userUnitId);
    }
    
    const { query: dbQuery } = require('../config/database');
    const result = await dbQuery(`
        SELECT f.*, u.unit_name
        FROM firearms f
        LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
        WHERE (f.serial_number ILIKE $1 OR f.manufacturer ILIKE $2 OR f.model ILIKE $3)
        ${unitFilter}
        ORDER BY f.serial_number
        LIMIT 50
    `, params);
    
    res.json({ success: true, data: result.rows });
}));

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    let queryParams = { ...req.query };
    
    // SECURITY: Station commanders are ALWAYS filtered to their unit
    // They cannot override this by passing assigned_unit_id in query params
    if (role === 'station_commander') {
        // Force their unit_id - ignore any manually passed unit filter
        queryParams.assigned_unit_id = userUnitId;
        // Log attempted bypass for security audit
        if (req.query.assigned_unit_id && req.query.assigned_unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted to query unit ${req.query.assigned_unit_id} (assigned: ${userUnitId})`);
        }
    }
    
    const firearms = await Firearm.findAll(queryParams);
    res.json({ success: true, data: firearms });
}));

// General stats endpoint - must be before /:id route
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const { unit_id } = req.query;
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders are ALWAYS limited to their unit's stats
    // They cannot override this by passing unit_id in query params
    let queryUnitId = unit_id;
    if (role === 'station_commander') {
        queryUnitId = userUnitId; // Force their unit - ignore any passed unit_id
        if (unit_id && unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted to query stats for unit ${unit_id} (assigned: ${userUnitId})`);
        }
    }
    
    let statsQuery;
    let params = [];
    
    if (queryUnitId) {
        statsQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE current_status = 'available') as available,
                COUNT(*) FILTER (WHERE current_status = 'in_custody') as in_custody,
                COUNT(*) FILTER (WHERE current_status = 'maintenance') as maintenance,
                COUNT(*) FILTER (WHERE current_status = 'lost') as lost,
                COUNT(*) FILTER (WHERE current_status = 'stolen') as stolen,
                COUNT(*) FILTER (WHERE current_status = 'destroyed') as destroyed,
                COUNT(DISTINCT firearm_type) as firearm_types
            FROM firearms
            WHERE assigned_unit_id = $1
        `;
        params = [queryUnitId];
    } else {
        statsQuery = `
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE current_status = 'available') as available,
                COUNT(*) FILTER (WHERE current_status = 'in_custody') as in_custody,
                COUNT(*) FILTER (WHERE current_status = 'maintenance') as maintenance,
                COUNT(*) FILTER (WHERE current_status = 'lost') as lost,
                COUNT(*) FILTER (WHERE current_status = 'stolen') as stolen,
                COUNT(*) FILTER (WHERE current_status = 'destroyed') as destroyed,
                COUNT(DISTINCT firearm_type) as firearm_types
            FROM firearms
        `;
    }
    
    const { query } = require('../config/database');
    const result = await query(statsQuery, params);
    
    // Also get type breakdown
    let typeQuery;
    if (queryUnitId) {
        typeQuery = `
            SELECT firearm_type, COUNT(*) as count
            FROM firearms
            WHERE assigned_unit_id = $1
            GROUP BY firearm_type
            ORDER BY count DESC
        `;
    } else {
        typeQuery = `
            SELECT firearm_type, COUNT(*) as count
            FROM firearms
            GROUP BY firearm_type
            ORDER BY count DESC
        `;
    }
    const typeResult = await query(typeQuery, queryUnitId ? [queryUnitId] : []);
    
    res.json({ 
        success: true, 
        data: {
            ...result.rows[0],
            by_type: typeResult.rows
        }
    });
}));

// Unit-specific firearms endpoint - must be before /:id route
router.get('/unit/:unit_id', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const requestedUnitId = req.params.unit_id;
    
    // Station commanders can only access their own unit's firearms
    if (role === 'station_commander' && requestedUnitId !== userUnitId) {
        return res.status(403).json({ 
            success: false, 
            message: 'Access denied: You can only view firearms from your unit' 
        });
    }
    
    const firearms = await Firearm.findAll({ 
        assigned_unit_id: requestedUnitId,
        ...req.query 
    });
    
    res.json({ success: true, data: firearms });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const firearm = await Firearm.findById(req.params.id);
    
    if (!firearm) {
        return res.status(404).json({ success: false, message: 'Firearm not found' });
    }
    
    // Station commanders can only view firearms in their unit
    if (role === 'station_commander' && firearm.assigned_unit_id !== userUnitId) {
        return res.status(403).json({ 
            success: false, 
            message: 'Access denied: You can only view firearms assigned to your unit' 
        });
    }
    
    res.json({ success: true, data: firearm });
}));

router.get('/:id/stats', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const stats = await Firearm.getStatsByUnit(req.params.id);
    res.json({ success: true, data: stats });
}));

router.post('/', authenticate, requireHQCommander, logCreate, asyncHandler(async (req, res) => {
    const { assigned_unit_id, ballistic_profile } = req.body;
    
    // Validate that unit_id is provided - firearms must be assigned to a unit at registration
    if (!assigned_unit_id) {
        return res.status(400).json({
            success: false,
            message: 'Firearm must be assigned to a unit at registration. Please provide assigned_unit_id.'
        });
    }
    
    const { withTransaction } = require('../config/database');
    
    const result = await withTransaction(async (client) => {
        // Generate firearm_id
        const faIdResult = await client.query(`SELECT COALESCE(MAX(CAST(SUBSTRING(firearm_id FROM 4) AS INTEGER)), 0) as max_num FROM firearms WHERE firearm_id ~ '^FA-[0-9]+$'`);
        const faNextNum = parseInt(faIdResult.rows[0].max_num) + 1;
        const firearm_id = `FA-${String(faNextNum).padStart(3, '0')}`;

        // Create the firearm
        const firearmData = { ...req.body, registered_by: req.user.user_id, registration_level: 'hq' };
        delete firearmData.ballistic_profile; // Remove from firearm data
        
        const firearmInsert = `
            INSERT INTO firearms (
                firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
                manufacture_year, acquisition_date, acquisition_source,
                assigned_unit_id, registered_by, registration_level, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *
        `;
        const firearmValues = [
            firearm_id,
            firearmData.serial_number,
            firearmData.manufacturer,
            firearmData.model,
            firearmData.firearm_type,
            firearmData.caliber,
            firearmData.manufacture_year,
            firearmData.acquisition_date,
            firearmData.acquisition_source,
            firearmData.assigned_unit_id,
            firearmData.registered_by,
            firearmData.registration_level,
            firearmData.notes || null
        ];
        
        const firearmResult = await client.query(firearmInsert, firearmValues);
        const firearm = firearmResult.rows[0];
        
        let createdProfile = null;
        
        // If ballistic profile data is provided, create it
        if (ballistic_profile && (
            ballistic_profile.rifling_characteristics ||
            ballistic_profile.firing_pin_impression ||
            ballistic_profile.ejector_marks ||
            ballistic_profile.extractor_marks
        )) {
            // Generate ballistic_id
            const bpIdResult = await client.query(`SELECT COALESCE(MAX(CAST(SUBSTRING(ballistic_id FROM 4) AS INTEGER)), 0) as max_num FROM ballistic_profiles WHERE ballistic_id ~ '^BP-[0-9]+$'`);
            const bpNextNum = parseInt(bpIdResult.rows[0].max_num) + 1;
            const ballistic_id = `BP-${String(bpNextNum).padStart(3, '0')}`;

            const profileInsert = `
                INSERT INTO ballistic_profiles (
                    ballistic_id, firearm_id, rifling_characteristics, firing_pin_impression,
                    ejector_marks, extractor_marks, chamber_marks,
                    test_ammunition, test_conducted_by, forensic_lab, notes,
                    created_by
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                RETURNING *
            `;
            const profileValues = [
                ballistic_id,
                firearm.firearm_id,
                ballistic_profile.rifling_characteristics || null,
                ballistic_profile.firing_pin_impression || null,
                ballistic_profile.ejector_marks || null,
                ballistic_profile.extractor_marks || null,
                ballistic_profile.chamber_marks || null,
                ballistic_profile.test_ammunition || null,
                ballistic_profile.test_conducted_by || null,
                ballistic_profile.forensic_lab || null,
                ballistic_profile.notes || null,
                req.user.user_id
            ];
            
            const profileResult = await client.query(profileInsert, profileValues);
            createdProfile = profileResult.rows[0];
        }
        
        return { firearm, createdProfile };
    });
    
    res.status(201).json({ 
        success: true, 
        data: result.firearm,
        ballistic_profile: result.createdProfile
    });
}));

router.put('/:id', authenticate, requireCommander, requireUnitAccess, logUpdate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // Station commanders can only update firearms in their own unit
    if (role === 'station_commander') {
        const existingFirearm = await Firearm.findById(req.params.id);
        if (!existingFirearm) {
            return res.status(404).json({ success: false, message: 'Firearm not found' });
        }
        if (existingFirearm.assigned_unit_id !== userUnitId) {
            return res.status(403).json({ 
                success: false, 
                message: 'Access denied: You can only modify firearms assigned to your unit' 
            });
        }
        // Prevent changing the assigned unit
        delete req.body.assigned_unit_id;
    }
    
    const firearm = await Firearm.update(req.params.id, req.body);
    if (!firearm) return res.status(404).json({ success: false, message: 'Firearm not found' });
    res.json({ success: true, data: firearm });
}));

// ============================================
// FULL TRACEABILITY ENDPOINT
// ============================================
// Returns complete custody + ballistic-access history for a firearm
// This is the primary forensic traceability API

/**
 * GET /firearms/:id/full-history
 * 
 * Returns:
 * - Firearm details
 * - Ballistic profile summary (if exists) - NOT FOR STATION COMMANDERS
 * - Complete custody chain with cross-unit flags
 * - Ballistic access history - NOT FOR STATION COMMANDERS
 * - Unified timeline of all events
 * - Summary statistics
 * 
 * RBAC:
 * - investigator: Full access to all firearms including ballistic data
 * - hq_firearm_commander: Full access to all firearms including ballistic data
 * - admin: Full access for audit purposes
 * - station_commander: Only firearms assigned to their unit, NO BALLISTIC DATA
 */
router.get('/:id/full-history', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const firearmId = req.params.id;
    const { include_timeline = 'true', timeline_limit = 100 } = req.query;

    // Get firearm first
    const firearm = await Firearm.findById(firearmId);
    if (!firearm) {
        return res.status(404).json({ success: false, message: 'Firearm not found' });
    }

    // RBAC: Station commanders can only access their unit's firearms
    if (role === 'station_commander' && firearm.assigned_unit_id !== userUnitId) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view history for firearms assigned to your unit.'
        });
    }

    // SECURITY: Station commanders CANNOT access ballistic data
    const canAccessBallisticData = role !== 'station_commander';
    
    // Only fetch ballistic profile if user has access
    let ballisticProfile = null;
    if (canAccessBallisticData) {
        ballisticProfile = await BallisticProfile.findByFirearmId(
            firearmId, 
            req.user.user_id, 
            { ip: req.ip, userAgent: req.get('user-agent') }
        );
    }

    // Gather all traceability data in parallel
    const [
        custodyStats,
        custodyChain,
        crossUnitTransfers,
        ballisticAccessHistory
    ] = await Promise.all([
        CustodyRecord.getCustodyStats(firearmId),
        CustodyRecord.getCustodyChainTimeline(firearmId),
        CustodyRecord.getCrossUnitTransfers(firearmId),
        // Only fetch ballistic access history if user has ballistic access
        (canAccessBallisticData && ballisticProfile) ? 
            query(`
                SELECT bal.*, u.full_name as accessed_by_name, u.role as accessed_by_role
                FROM ballistic_access_logs bal
                JOIN users u ON bal.accessed_by = u.user_id
                WHERE bal.firearm_id = $1
                ORDER BY bal.accessed_at DESC
                LIMIT 50
            `, [firearmId]).then(r => r.rows) :
            Promise.resolve([])
    ]);

    // Get unified timeline if requested
    let unifiedTimeline = null;
    if (include_timeline === 'true') {
        unifiedTimeline = await CustodyRecord.getUnifiedTimeline(firearmId, { limit: parseInt(timeline_limit) });
        
        // If station commander, filter out ballistic events from timeline
        if (role === 'station_commander' && unifiedTimeline) {
            unifiedTimeline = unifiedTimeline.filter(event => 
                !['ballistic_access', 'ballistic_profile_created'].includes(event.event_type)
            );
        }
    }

    // Build response
    const response = {
        firearm: {
            firearm_id: firearm.firearm_id,
            serial_number: firearm.serial_number,
            manufacturer: firearm.manufacturer,
            model: firearm.model,
            firearm_type: firearm.firearm_type,
            caliber: firearm.caliber,
            current_status: firearm.current_status,
            assigned_unit_id: firearm.assigned_unit_id,
            unit_name: firearm.unit_name,
            registration_date: firearm.created_at
        },
        // Include ballistic data only for authorized roles
        ballistic_profile: canAccessBallisticData ? (ballisticProfile ? {
            ballistic_id: ballisticProfile.ballistic_id,
            has_profile: true,
            test_date: ballisticProfile.test_date,
            forensic_lab: ballisticProfile.forensic_lab,
            is_locked: ballisticProfile.is_locked,
            created_at: ballisticProfile.created_at
        } : {
            has_profile: false
        }) : {
            access_denied: true,
            reason: 'Station commanders do not have access to ballistic data'
        },
        custody_summary: {
            total_custody_events: parseInt(custodyStats.total_custody_events) || 0,
            unique_officers: parseInt(custodyStats.unique_officers) || 0,
            unique_units: parseInt(custodyStats.unique_units) || 0,
            currently_in_custody: parseInt(custodyStats.active_custody) > 0,
            first_custody_date: custodyStats.first_custody_date,
            last_custody_date: custodyStats.last_custody_date,
            total_custody_days: custodyStats.total_custody_seconds ? 
                Math.round(custodyStats.total_custody_seconds / 86400) : 0,
            cross_unit_transfers: crossUnitTransfers.length
        },
        custody_chain: custodyChain.map(record => ({
            custody_id: record.custody_id,
            sequence: record.custody_sequence,
            officer_name: record.officer_name,
            officer_rank: record.officer_rank,
            officer_number: record.officer_number,
            unit_name: record.unit_name,
            custody_type: record.custody_type,
            issued_at: record.issued_at,
            returned_at: record.returned_at,
            duration_seconds: record.custody_duration_seconds,
            issued_by: record.issued_by_name,
            returned_to: record.returned_to_name,
            return_condition: record.return_condition,
            is_cross_unit_transfer: record.is_cross_unit_transfer
        })),
        cross_unit_transfers: crossUnitTransfers,
        // Include ballistic access history only for authorized roles
        ballistic_access_history: canAccessBallisticData ? ballisticAccessHistory.map(access => ({
            access_id: access.access_id,
            accessed_at: access.accessed_at,
            access_type: access.access_type,
            accessed_by: access.accessed_by_name,
            accessed_by_role: access.accessed_by_role,
            access_reason: access.access_reason,
            firearm_status_at_access: access.firearm_status_at_access
        })) : undefined,
        unified_timeline: unifiedTimeline,
        role_access_level: canAccessBallisticData ? 'full' : 'custody_only',
        generated_at: new Date().toISOString()
    };

    // Log this comprehensive access
    await query(`
        INSERT INTO audit_logs (user_id, action_type, table_name, record_id, new_values, ip_address, user_agent)
        VALUES ($1, 'FULL_HISTORY_ACCESS', 'firearms', $2, $3, $4, $5)
    `, [
        req.user.user_id,
        firearmId,
        JSON.stringify({ 
            include_timeline, 
            timeline_limit,
            has_ballistic_profile: !!ballisticProfile 
        }),
        req.ip,
        req.get('user-agent')
    ]);

    res.json({ success: true, data: response });
}));

/**
 * GET /firearms/:id/cross-unit-transfers
 * 
 * Returns all cross-unit transfer events for a firearm
 * Useful for investigating firearm movement patterns
 */
router.get('/:id/cross-unit-transfers', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const firearmId = req.params.id;

    // Get firearm for RBAC check
    const firearm = await Firearm.findById(firearmId);
    if (!firearm) {
        return res.status(404).json({ success: false, message: 'Firearm not found' });
    }

    // RBAC: Station commanders limited to their unit
    if (role === 'station_commander' && firearm.assigned_unit_id !== userUnitId) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view transfers for firearms assigned to your unit.'
        });
    }

    const transfers = await CustodyRecord.getCrossUnitTransfers(firearmId);
    
    res.json({ 
        success: true, 
        data: {
            firearm_id: firearmId,
            serial_number: firearm.serial_number,
            total_transfers: transfers.length,
            transfers
        }
    });
}));

module.exports = router;
