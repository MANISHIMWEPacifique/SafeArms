const express = require('express');
const router = express.Router();
const { assignCustody, returnCustody, getActiveCustody, getUnitCustody, getFirearmCustodyHistory, getOfficerCustodyHistory } = require('../services/custody.service');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCustodyAssignment, logCustodyReturn } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

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
        const { query } = require('../config/database');
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

module.exports = router;
