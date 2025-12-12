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
