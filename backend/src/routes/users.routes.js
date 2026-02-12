const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcrypt');
const { authenticate } = require('../middleware/authentication');
const { requireAdmin, requireAdminOrHQ } = require('../middleware/authorization');
const { logCreate, logUpdate, logDelete } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { isValidEmail, isValidPassword, isValidRole } = require('../utils/validators');
const { BCRYPT_ROUNDS } = require('../config/auth');

router.get('/', authenticate, requireAdminOrHQ, asyncHandler(async (req, res) => {
    const { role, unit_id, is_active, limit, offset } = req.query;
    const users = await User.findAll({ role, unit_id, is_active, limit, offset });
    res.json({ success: true, data: users });
}));

// Get user statistics - must be before /:id route
router.get('/stats', authenticate, requireAdminOrHQ, asyncHandler(async (req, res) => {
    const stats = await User.getStats();
    res.json({ 
        success: true, 
        data: {
            total: parseInt(stats.total_users) || 0,
            active: parseInt(stats.active_users) || 0,
            inactive: (parseInt(stats.total_users) || 0) - (parseInt(stats.active_users) || 0),
            admins: parseInt(stats.admins) || 0,
            hqCommanders: parseInt(stats.hq_commanders) || 0,
            stationCommanders: parseInt(stats.station_commanders) || 0,
            investigators: parseInt(stats.investigators) || 0,
            byRole: {
                admin: parseInt(stats.admins) || 0,
                hq_firearm_commander: parseInt(stats.hq_commanders) || 0,
                station_commander: parseInt(stats.station_commanders) || 0,
                investigator: parseInt(stats.investigators) || 0
            }
        }
    });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, data: user });
}));

router.post('/', authenticate, requireAdmin, logCreate, asyncHandler(async (req, res) => {
    const { username, password, full_name, email, phone_number, role, unit_id } = req.body;

    if (!username || !password || !full_name || !email || !role) {
        return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    if (!isValidEmail(email)) {
        return res.status(400).json({ success: false, message: 'Invalid email format' });
    }

    if (!isValidPassword(password)) {
        return res.status(400).json({ success: false, message: 'Password must be at least 8 characters with uppercase, lowercase, number, and special character' });
    }

    if (!isValidRole(role)) {
        return res.status(400).json({ success: false, message: 'Invalid role' });
    }

    const password_hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const user = await User.create({ ...req.body, password_hash, created_by: req.user.user_id });

    res.status(201).json({ success: true, data: user });
}));

router.put('/:id', authenticate, requireAdminOrHQ, logUpdate, asyncHandler(async (req, res) => {
    const user = await User.update(req.params.id, req.body);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, data: user });
}));

router.delete('/:id', authenticate, requireAdmin, logDelete, asyncHandler(async (req, res) => {
    const user = await User.delete(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'User deactivated successfully' });
}));

module.exports = router;
