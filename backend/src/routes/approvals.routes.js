const express = require('express');
const router = express.Router();
const { getPendingApprovals, processLossReport, processDestructionRequest, processProcurementRequest } = require('../services/workflow.service');
const { authenticate } = require('../middleware/authentication');
const { requireHQCommander } = require('../middleware/authorization');
const { logApproval } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/pending', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const approvals = await getPendingApprovals();
    res.json({ success: true, data: approvals });
}));

router.post('/loss-report/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processLossReport(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Loss report ${status}` });
}));

router.post('/destruction/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processDestructionRequest(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Destruction request ${status}` });
}));

router.post('/procurement/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processProcurementRequest(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Procurement request ${status}` });
}));

module.exports = router;
