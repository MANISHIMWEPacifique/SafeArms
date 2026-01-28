const express = require('express');
const router = express.Router();
const BallisticProfile = require('../models/BallisticProfile');
const { authenticate } = require('../middleware/authentication');
const { 
    requireHQCommander, 
    requireRole, 
    requireBallisticAccess,
    PERMISSIONS 
} = require('../middleware/authorization');
const { logCreate, auditLogger } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

/**
 * Ballistic Profile Routes
 * 
 * RBAC ENFORCEMENT:
 * - CREATE: HQ Firearm Commander ONLY
 * - READ: HQ Commander, Forensic Analyst, Admin (audit)
 * - Station Commanders: NO ACCESS (explicitly denied)
 * 
 * IMPORTANT CONSTRAINTS:
 * - Ballistic profiles are IMMUTABLE after creation
 * - All access is logged for forensic traceability
 * - NO forensic analysis or matching capabilities (read-only traceability)
 */

// Middleware to log ballistic access
const logBallisticAccess = auditLogger('BALLISTIC_ACCESS');

/**
 * Log every ballistic access as a first-class audit event
 */
const auditBallisticAccess = async (req, res, next) => {
    // This will be logged after successful response
    res.on('finish', async () => {
        if (res.statusCode >= 200 && res.statusCode < 300 && req.user) {
            try {
                await query(`
                    INSERT INTO audit_logs (user_id, action_type, table_name, new_values, ip_address, user_agent)
                    VALUES ($1, 'BALLISTIC_ACCESS', 'ballistic_profiles', $2, $3, $4)
                `, [
                    req.user.user_id,
                    JSON.stringify({
                        endpoint: req.originalUrl,
                        method: req.method,
                        params: req.params,
                        query: req.query,
                        timestamp: new Date().toISOString()
                    }),
                    req.ip,
                    req.get('user-agent')
                ]);
            } catch (err) {
                console.error('Failed to audit ballistic access:', err);
            }
        }
    });
    next();
};

// Stats endpoint - returns counts for dashboard
// Station commanders see NO ballistic data (returns zeros)
router.get('/stats', authenticate, asyncHandler(async (req, res) => {
    const { role } = req.user;
    
    // Station commanders cannot access ballistic data - return empty stats
    if (role === 'station_commander') {
        return res.json({ 
            success: true, 
            data: { total: 0, with_rifling: 0, with_firing_pin: 0, with_ejector_extractor: 0 },
            message: 'Ballistic data access restricted for your role'
        });
    }
    
    // Only HQ Commander, Forensic Analyst, Admin can see stats
    if (!PERMISSIONS.BALLISTIC_READ.includes(role)) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Your role does not have ballistic data access.'
        });
    }
    
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

// Search ballistic profiles - RBAC enforced, access logged
router.get('/', authenticate, requireBallisticAccess, auditBallisticAccess, logBallisticAccess, asyncHandler(async (req, res) => {
    const profiles = await BallisticProfile.search(
        req.query, 
        req.user.user_id,
        { ip: req.ip, userAgent: req.get('user-agent') }
    );
    
    res.json({ success: true, data: profiles });
}));

// Get single profile with access logging
router.get('/:id', authenticate, requireBallisticAccess, auditBallisticAccess, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findById(
        req.params.id,
        req.user.user_id,
        req.query.reason || 'Profile view',
        { ip: req.ip, userAgent: req.get('user-agent') }
    );
    
    if (!profile) {
        return res.status(404).json({ success: false, message: 'Ballistic profile not found' });
    }
    
    res.json({ success: true, data: profile });
}));

// Get profile by firearm with access logging
router.get('/firearm/:firearm_id', authenticate, requireBallisticAccess, auditBallisticAccess, asyncHandler(async (req, res) => {
    const profile = await BallisticProfile.findByFirearmId(
        req.params.firearm_id,
        req.user.user_id,
        { ip: req.ip, userAgent: req.get('user-agent') }
    );
    
    res.json({ success: true, data: profile });
}));

// Get access history for a profile (forensic analyst/HQ only)
router.get('/:id/access-history', authenticate, requireRole(PERMISSIONS.BALLISTIC_ACCESS_HISTORY), asyncHandler(async (req, res) => {
    const history = await BallisticProfile.getAccessHistory(req.params.id, req.query.limit);
    res.json({ success: true, data: history });
}));

// Verify profile integrity (forensic analyst/HQ only)
router.get('/:id/verify-integrity', authenticate, requireRole(PERMISSIONS.BALLISTIC_VERIFY_INTEGRITY), asyncHandler(async (req, res) => {
    const verification = await BallisticProfile.verifyIntegrity(req.params.id);
    res.json({ success: true, data: verification });
}));

// ============================================
// FORENSIC TRACEABILITY ENDPOINTS (READ-ONLY)
// ============================================

// Get complete firearm traceability timeline
router.get('/traceability/:firearm_id', authenticate, requireBallisticAccess, auditBallisticAccess, asyncHandler(async (req, res) => {
    const { firearm_id } = req.params;
    
    // Get full traceability timeline using the database function
    const timeline = await query(
        'SELECT * FROM get_firearm_traceability($1)',
        [firearm_id]
    );
    
    // Get firearm summary
    const summary = await query(`
        SELECT * FROM firearm_traceability_timeline WHERE firearm_id = $1
    `, [firearm_id]);
    
    // Log this access to ballistic_access_logs if profile exists
    const profile = await query(
        'SELECT ballistic_id FROM ballistic_profiles WHERE firearm_id = $1',
        [firearm_id]
    );
    
    if (profile.rows[0]) {
        await BallisticProfile.logAccess(
            profile.rows[0].ballistic_id,
            req.user.user_id,
            'traceability_report',
            'Traceability timeline view',
            req.ip,
            req.get('user-agent')
        );
    }
    
    res.json({ 
        success: true, 
        data: {
            summary: summary.rows[0] || null,
            timeline: timeline.rows
        }
    });
}));

// Get custody chain for a firearm (chronological custody history)
router.get('/custody-chain/:firearm_id', authenticate, requireBallisticAccess, auditBallisticAccess, asyncHandler(async (req, res) => {
    const { firearm_id } = req.params;
    
    const custodyChain = await query(`
        SELECT * FROM custody_chain_timeline WHERE firearm_id = $1
    `, [firearm_id]);
    
    res.json({ success: true, data: custodyChain.rows });
}));

// ============================================
// CREATE ENDPOINT (HQ Commander Only)
// ============================================

// Create ballistic profile - HQ Commander only (during firearm registration)
// Profiles are IMMUTABLE after creation
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
    
    const profile = await BallisticProfile.create(req.body, req.user.user_id);
    res.status(201).json({ success: true, data: profile });
}));

// UPDATE/DELETE REMOVED - Ballistic profiles are immutable after creation
// This ensures forensic integrity of ballistic data for investigative purposes
// If corrections are needed, a new registration must be done by HQ

module.exports = router;
