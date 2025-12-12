const express = require('express');
const router = express.Router();
const Officer = require('../models/Officer');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireUnitAccess } = require('../middleware/authorization');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { unit_id } = req.query;
    const officers = await Officer.findByUnitId(unit_id || req.user.unit_id, req.query);
    res.json({ success: true, data: officers });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const officer = await Officer.findById(req.params.id);
    if (!officer) return res.status(404).json({ success: false, message: 'Officer not found' });
    res.json({ success: true, data: officer });
}));

router.post('/', authenticate, requireCommander, requireUnitAccess, logCreate, asyncHandler(async (req, res) => {
    const officer = await Officer.create(req.body);
    res.status(201).json({ success: true, data: officer });
}));

router.put('/:id', authenticate, requireCommander, requireUnitAccess, logUpdate, asyncHandler(async (req, res) => {
    const officer = await Officer.update(req.params.id, req.body);
    if (!officer) return res.status(404).json({ success: false, message: 'Officer not found' });
    res.json({ success: true, data: officer });
}));

module.exports = router;
