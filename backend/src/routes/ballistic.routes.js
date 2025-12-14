const express = require('express');
const router = express.Router();
const BallisticProfile = require('../models/BallisticProfile');
const { authenticate } = require('../middleware/authentication');
const { logCreate, logUpdate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

// Stats endpoint - must be before /:id route
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const statsQuery = `
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE profile_status = 'pending') as pending,
            COUNT(*) FILTER (WHERE profile_status = 'complete' OR profile_status = 'verified') as matched,
            COUNT(*) FILTER (WHERE profile_status = 'no_match') as no_match
        FROM ballistic_profiles
    `;
    
    const result = await query(statsQuery);
    res.json({ 
        success: true, 
        data: result.rows[0] || { total: 0, pending: 0, matched: 0, no_match: 0 }
    });
}));

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const profiles = await BallisticProfile.search(req.query);
    res.json({ success: true, data: profiles });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findById(req.params.id);
    if (!profile) return res.status(404).json({ success: false, message: 'Ballistic profile not found' });
    res.json({ success: true, data: profile });
}));

router.get('/firearm/:firearm_id', authenticate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findByFirearmId(req.params.firearm_id);
    res.json({ success: true, data: profile });
}));

router.post('/', authenticate, logCreate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.create(req.body);
    res.status(201).json({ success: true, data: profile });
}));

router.put('/:id', authenticate, logUpdate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.update(req.params.id, req.body);
    if (!profile) return res.status(404).json({ success: false, message: 'Ballistic profile not found' });
    res.json({ success: true, data: profile });
}));

module.exports = router;
