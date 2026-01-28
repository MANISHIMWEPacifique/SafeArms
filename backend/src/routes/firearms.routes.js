const express = require('express');
const router = express.Router();
const Firearm = require('../models/Firearm');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    let queryParams = { ...req.query };
    
    // Station commanders can only see their unit's firearms
    if (role === 'station_commander') {
        queryParams.assigned_unit_id = userUnitId;
    }
    
    const firearms = await Firearm.findAll(queryParams);
    res.json({ success: true, data: firearms });
}));

// General stats endpoint - must be before /:id route
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const { unit_id } = req.query;
    const { role, unit_id: userUnitId } = req.user;
    
    // Station commanders can only see their unit's stats
    let queryUnitId = unit_id;
    if (role === 'station_commander') {
        queryUnitId = userUnitId;
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

router.post('/', authenticate, requireCommander, requireUnitAccess, logCreate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    let firearmData = { ...req.body, registered_by: req.user.user_id };
    
    // Station commanders can only register firearms to their own unit
    if (role === 'station_commander') {
        firearmData.assigned_unit_id = userUnitId;
    }
    
    const firearm = await Firearm.create(firearmData);
    res.status(201).json({ success: true, data: firearm });
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
