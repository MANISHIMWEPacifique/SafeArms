const express = require('express');
const router = express.Router();
const LossReport = require('../models/LossReport');
const DestructionRequest = require('../models/DestructionRequest');
const ProcurementRequest = require('../models/ProcurementRequest');
const { authenticate } = require('../middleware/authentication');
const { requireCommander } = require('../middleware/authorization');
const { logCreate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

// Loss Reports
router.get('/loss', authenticate, asyncHandler(async (req, res) => {
    const reports = await LossReport.findAll(req.query);
    res.json({ success: true, data: reports });
}));

router.post('/loss', authenticate, requireCommander, logCreate, asyncHandler(async (req, res) => {
    const report = await LossReport.create({ ...req.body, reported_by: req.user.user_id });
    res.status(201).json({ success: true, data: report });
}));

// Destruction Requests
router.get('/destruction', authenticate, asyncHandler(async (req, res) => {
    const requests = await DestructionRequest.findAll(req.query);
    res.json({ success: true, data: requests });
}));

router.post('/destruction', authenticate, requireCommander, logCreate, asyncHandler(async (req, res) => {
    const request = await DestructionRequest.create({ ...req.body, requested_by: req.user.user_id });
    res.status(201).json({ success: true, data: request });
}));

// Procurement Requests
router.get('/procurement', authenticate, asyncHandler(async (req, res) => {
    const requests = await ProcurementRequest.findAll(req.query);
    res.json({ success: true, data: requests });
}));

router.post('/procurement', authenticate, requireCommander, logCreate, asyncHandler(async (req, res) => {
    const request = await ProcurementRequest.create({ ...req.body, requested_by: req.user.user_id });
    res.status(201).json({ success: true, data: request });
}));

module.exports = router;
