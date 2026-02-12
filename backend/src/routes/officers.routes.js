const express = require('express');
const router = express.Router();
const Officer = require('../models/Officer');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { unit_id } = req.query;
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders are ALWAYS filtered to their unit
    // They cannot override this by passing unit_id in query params
    let queryUnitId = unit_id;
    if (role === 'station_commander') {
        queryUnitId = userUnitId; // Force their unit - ignore any passed unit_id
        if (unit_id && unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted to query officers for unit ${unit_id} (assigned: ${userUnitId})`);
        }
    }
    
    const officers = await Officer.findByUnitId(queryUnitId || req.user.unit_id, req.query);
    res.json({ success: true, data: officers });
}));

// Get officers statistics
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // SECURITY: Station commanders can only see their unit's stats
    // They cannot override this
    const options = {};
    if (role === 'station_commander') {
        options.unit_id = userUnitId;
        if (req.query.unit_id && req.query.unit_id !== userUnitId) {
            console.warn(`[SECURITY] Station commander ${req.user.user_id} attempted to query officer stats for unit ${req.query.unit_id} (assigned: ${userUnitId})`);
        }
    }
    
    const stats = await Officer.getStats(options);
    res.json({ success: true, data: stats });
}));

// Unit-specific officers endpoint - must be before /:id route
router.get('/unit/:unit_id', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const requestedUnitId = req.params.unit_id;
    
    // Station commanders can only access their own unit's officers
    if (role === 'station_commander' && requestedUnitId !== userUnitId) {
        return res.status(403).json({ 
            success: false, 
            message: 'Access denied: You can only view officers from your unit' 
        });
    }
    
    const officers = await Officer.findByUnitId(requestedUnitId, req.query);
    res.json({ success: true, data: officers });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    const officer = await Officer.findById(req.params.id);
    
    if (!officer) {
        return res.status(404).json({ success: false, message: 'Officer not found' });
    }
    
    // Station commanders can only view officers in their unit
    if (role === 'station_commander' && officer.unit_id !== userUnitId) {
        return res.status(403).json({ 
            success: false, 
            message: 'Access denied: You can only view officers from your unit' 
        });
    }
    
    res.json({ success: true, data: officer });
}));

// Search officers
router.get('/search', authenticate, asyncHandler(async (req, res) => {
    const { q } = req.query;
    const { role, unit_id: userUnitId } = req.user;
    
    if (!q || q.trim().length === 0) {
        return res.json({ success: true, data: [] });
    }
    
    let unitFilter = '';
    let params = [`%${q}%`, `%${q}%`];
    
    // Station commanders can only search within their unit
    if (role === 'station_commander') {
        unitFilter = 'AND o.unit_id = $3';
        params.push(userUnitId);
    }
    
    const { query: dbQuery } = require('../config/database');
    const result = await dbQuery(`
        SELECT o.*, u.unit_name
        FROM officers o
        JOIN units u ON o.unit_id = u.unit_id
        WHERE (o.full_name ILIKE $1 OR o.officer_number ILIKE $2)
        ${unitFilter}
        ORDER BY o.full_name
        LIMIT 50
    `, params);
    
    res.json({ success: true, data: result.rows });
}));

router.post('/', authenticate, requireCommander, requireUnitAccess, logCreate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    let officerData = { ...req.body };
    
    // Station commanders can only add officers to their own unit
    if (role === 'station_commander') {
        officerData.unit_id = userUnitId;
    }
    
    const officer = await Officer.create(officerData);
    res.status(201).json({ success: true, data: officer });
}));

router.put('/:id', authenticate, requireCommander, requireUnitAccess, logUpdate, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    // Station commanders can only update officers in their own unit
    if (role === 'station_commander') {
        const existingOfficer = await Officer.findById(req.params.id);
        if (!existingOfficer) {
            return res.status(404).json({ success: false, message: 'Officer not found' });
        }
        if (existingOfficer.unit_id !== userUnitId) {
            return res.status(403).json({ 
                success: false, 
                message: 'Access denied: You can only modify officers in your unit' 
            });
        }
        // Prevent changing the unit
        delete req.body.unit_id;
    }
    
    const officer = await Officer.update(req.params.id, req.body);
    if (!officer) return res.status(404).json({ success: false, message: 'Officer not found' });
    res.json({ success: true, data: officer });
}));

// Deactivate (soft delete) an officer
router.delete('/:id', authenticate, requireCommander, requireUnitAccess, asyncHandler(async (req, res) => {
    const { role, unit_id: userUnitId } = req.user;
    
    const existingOfficer = await Officer.findById(req.params.id);
    if (!existingOfficer) {
        return res.status(404).json({ success: false, message: 'Officer not found' });
    }
    
    // Station commanders can only deactivate officers in their unit
    if (role === 'station_commander' && existingOfficer.unit_id !== userUnitId) {
        return res.status(403).json({ 
            success: false, 
            message: 'Access denied: You can only modify officers in your unit' 
        });
    }
    
    // Soft delete - set is_active to false
    const officer = await Officer.update(req.params.id, { is_active: false });
    res.json({ success: true, data: officer, message: 'Officer deactivated successfully' });
}));

module.exports = router;
