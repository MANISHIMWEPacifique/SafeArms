const express = require('express');
const router = express.Router();
const Firearm = require('../models/Firearm');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireHQCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

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
    
    const { getClient } = require('../config/database');
    const client = await getClient();
    
    try {
        await client.query('BEGIN');
        
        // Create the firearm
        const firearmData = { ...req.body, registered_by: req.user.user_id, registration_level: 'hq' };
        delete firearmData.ballistic_profile; // Remove from firearm data
        
        const firearmInsert = `
            INSERT INTO firearms (
                serial_number, manufacturer, model, firearm_type, caliber,
                manufacture_year, acquisition_date, acquisition_source,
                assigned_unit_id, registered_by, registration_level, notes
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING *
        `;
        const firearmValues = [
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
            const profileInsert = `
                INSERT INTO ballistic_profiles (
                    firearm_id, rifling_characteristics, firing_pin_impression,
                    ejector_marks, extractor_marks, chamber_marks,
                    test_ammunition, test_conducted_by, forensic_lab, notes,
                    created_by
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING *
            `;
            const profileValues = [
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
        
        await client.query('COMMIT');
        
        res.status(201).json({ 
            success: true, 
            data: firearm,
            ballistic_profile: createdProfile
        });
    } catch (error) {
        await client.query('ROLLBACK');
        throw error;
    } finally {
        client.release();
    }
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

module.exports = router;
