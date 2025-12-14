const express = require('express');
const router = express.Router();
const Firearm = require('../models/Firearm');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const firearms = await Firearm.findAll(req.query);
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

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const firearm = await Firearm.findById(req.params.id);
    if (!firearm) return res.status(404).json({ success: false, message: 'Firearm not found' });
    res.json({ success: true, data: firearm });
}));

router.get('/:id/stats', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const stats = await Firearm.getStatsByUnit(req.params.id);
    res.json({ success: true, data: stats });
}));

router.post('/', authenticate, requireCommander, requireUnitAccess, logCreate, asyncHandler(async (req, res) => {
    const firearm = await Firearm.create({ ...req.body, registered_by: req.user.user_id });
    res.status(201).json({ success: true, data: firearm });
}));

router.put('/:id', authenticate, requireCommander, requireUnitAccess, logUpdate, asyncHandler(async (req, res) => {
    const firearm = await Firearm.update(req.params.id, req.body);
    if (!firearm) return res.status(404).json({ success: false, message: 'Firearm not found' });
    res.json({ success: true, data: firearm });
}));

module.exports = router;
