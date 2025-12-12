const express = require('express');
const router = express.Router();
const { assignCustody, returnCustody, getActiveCustody, getFirearmCustodyHistory, getOfficerCustodyHistory } = require('../services/custody.service');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCustodyAssignment, logCustodyReturn } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.post('/assign', authenticate, requireCommander, requireUnitAccess, logCustodyAssignment, asyncHandler(async (req, res) => {
    const custodyRecord = await assignCustody({ ...req.body, issued_by: req.user.user_id });
    res.status(201).json({ success: true, data: custodyRecord, message: 'Custody assigned successfully' });
}));

router.post('/:id/return', authenticate, requireCommander, requireUnitAccess, logCustodyReturn, asyncHandler(async (req, res) => {
    const custodyRecord = await returnCustody(req.params.id, { ...req.body, returned_to: req.user.user_id });
    res.json({ success: true, data: custodyRecord, message: 'Custody returned successfully' });
}));

router.get('/active', authenticate, asyncHandler(async (req, res) => {
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
