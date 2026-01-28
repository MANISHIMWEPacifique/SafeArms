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
    
    // Station commanders can only assign custody within their unit
    if (role === 'station_commander') {
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
    
    // Station commanders only see their unit's records
    if (role === 'station_commander') {
        req.query.unit_id = userUnitId;
    }
    
    const records = await getActiveCustody(req.query);
    res.json({ success: true, data: records });
}));

router.get('/firearm/:firearm_id/history', authenticate, asyncHandler(async (req, res) => {
    const history = await getFirearmCustodyHistory(req.params.firearm_id, req.query);
    res.json({ success: true, data: history });
}));

router.get('/officer/:officer_id/history', authenticate, asyncHandler(async (req, res) => {
    const history = await getOfficerCustodyHistory(req.params.officer_id, req.query);
    res.json({ success: true, data: history });
}));

module.exports = router;
