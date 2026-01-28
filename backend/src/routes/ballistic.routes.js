const express = require('express');
const router = express.Router();
const BallisticProfile = require('../models/BallisticProfile');
const { authenticate } = require('../middleware/authentication');
const { requireHQCommander } = require('../middleware/authorization');
const { logCreate } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

// Stats endpoint - must be before /:id route
// Returns counts for search/matching purposes (not analysis workflow)
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const statsQuery = `
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE rifling_characteristics IS NOT NULL) as with_rifling,
            COUNT(*) FILTER (WHERE firing_pin_impression IS NOT NULL) as with_firing_pin,
            COUNT(*) FILTER (WHERE ejector_marks IS NOT NULL OR extractor_marks IS NOT NULL) as with_ejector_extractor
        FROM ballistic_profiles
    `;
    
    const result = await query(statsQuery);
    res.json({ 
        success: true, 
        data: result.rows[0] || { total: 0, with_rifling: 0, with_firing_pin: 0, with_ejector_extractor: 0 }
    });
}));

// Search ballistic profiles - read-only for all authenticated users
router.get('/', authenticate, asyncHandler(async (req, res) => {
    const profiles = await BallisticProfile.search(req.query);
    res.json({ success: true, data: profiles });
}));

// Get single profile - read-only
router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findById(req.params.id);
    if (!profile) return res.status(404).json({ success: false, message: 'Ballistic profile not found' });
    res.json({ success: true, data: profile });
}));

// Get profile by firearm - read-only
router.get('/firearm/:firearm_id', authenticate, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findByFirearmId(req.params.firearm_id);
    res.json({ success: true, data: profile });
}));

// Create ballistic profile - HQ Commander only (during firearm registration)
// Profiles are created as part of the firearm registration workflow
router.post('/', authenticate, requireHQCommander, logCreate, asyncHandler(async (req, res) => {
    // Verify firearm exists
    const firearmCheck = await query('SELECT firearm_id FROM firearms WHERE firearm_id = $1', [req.body.firearm_id]);
    if (firearmCheck.rows.length === 0) {
        return res.status(400).json({
            success: false,
            message: 'Firearm not found. Ballistic profiles can only be created for registered firearms.'
        });
    }
    
    // Check if profile already exists for this firearm
    const existingProfile = await BallisticProfile.findByFirearmId(req.body.firearm_id);
    if (existingProfile) {
        return res.status(400).json({
            success: false,
            message: 'Ballistic profile already exists for this firearm. Profiles are immutable after creation.'
        });
    }
    
    const profile = await BallisticProfile.create(req.body);
    res.status(201).json({ success: true, data: profile });
}));

// UPDATE REMOVED - Ballistic profiles are immutable after creation
// This ensures forensic integrity of ballistic data for investigative purposes
// If corrections are needed, a new registration must be done by HQ

module.exports = router;
