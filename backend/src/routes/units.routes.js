const express = require('express');
const router = express.Router();
const Unit = require('../models/Unit');
const { authenticate } = require('../middleware/authentication');
const { requireAdmin, requireAdminOrHQ } = require('../middleware/authorization');
const { logCreate, logUpdate, logDelete } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const units = await Unit.findAll(req.query);
    res.json({ success: true, data: units });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const unit = await Unit.findById(req.params.id);
    if (!unit) return res.status(404).json({ success: false, message: 'Unit not found' });
    res.json({ success: true, data: unit });
}));

router.post('/', authenticate, requireAdmin, logCreate, asyncHandler(async (req, res) => {
    const unit = await Unit.create(req.body);
    res.status(201).json({ success: true, data: unit });
}));

router.put('/:id', authenticate, requireAdminOrHQ, logUpdate, asyncHandler(async (req, res) => {
    const unit = await Unit.update(req.params.id, req.body);
    if (!unit) return res.status(404).json({ success: false, message: 'Unit not found' });
    res.json({ success: true, data: unit });
}));

router.delete('/:id', authenticate, requireAdminOrHQ, logDelete, asyncHandler(async (req, res) => {
    const unit = await Unit.delete(req.params.id);
    if (!unit) return res.status(404).json({ success: false, message: 'Unit not found' });
    res.json({ success: true, message: 'Unit deleted successfully', data: unit });
}));

module.exports = router;
