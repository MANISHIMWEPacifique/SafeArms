const express = require('express');
const router = express.Router();
const { getAllAnomalies, getUnitAnomalies } = require('../ml/anomalyDetector');
const Anomaly = require('../models/Anomaly');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireAdminOrHQ, requireRole, ROLES } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');

// All roles that can view/act on anomalies
const requireAnomalyAccess = requireRole([
    ROLES.ADMIN, ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.INVESTIGATOR
]);

// Get anomalies - role-based access
// Admin/HQ see all, Station commanders see their unit, Investigators see all for analysis
router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id } = req.user;
    
    // Station commanders can only see their unit's anomalies
    if (role === 'station_commander') {
        const anomalies = await getUnitAnomalies(unit_id, req.query);
        return res.json({ success: true, data: anomalies });
    }
    
    // Admin, HQ Commander, and Investigator can see all anomalies
    const anomalies = await getAllAnomalies(req.query);
    res.json({ success: true, data: anomalies });
}));

// Investigation search - for investigators to search anomalies by unit and time interval
router.get('/investigation/search', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { unit_id, start_date, end_date, severity, status, limit = 100, offset = 0 } = req.query;
    
    // Station commanders restricted to their unit
    const effectiveUnitId = req.user.role === 'station_commander' ? req.user.unit_id : unit_id;
    
    const results = await Anomaly.searchForInvestigation({
        unit_id: effectiveUnitId,
        start_date,
        end_date,
        severity,
        status,
        limit: parseInt(limit),
        offset: parseInt(offset)
    });
    res.json({ success: true, data: results });
}));

router.get('/unit/:unit_id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const anomalies = await getUnitAnomalies(req.params.unit_id, req.query);
    res.json({ success: true, data: anomalies });
}));

router.get('/unit/:unit_id/stats', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const stats = await Anomaly.getStatsByUnit(req.params.unit_id);
    res.json({ success: true, data: stats });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const anomaly = await Anomaly.findById(req.params.id);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

router.put('/:id', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const anomaly = await Anomaly.update(req.params.id, req.body);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Start investigation on an anomaly
router.post('/:id/investigate', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { notes } = req.body;
    const anomaly = await Anomaly.investigate(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Resolve an anomaly
router.post('/:id/resolve', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { notes } = req.body;
    const anomaly = await Anomaly.resolve(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Mark anomaly as false positive (feeds ML training data)
router.post('/:id/false-positive', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { notes } = req.body;
    const anomaly = await Anomaly.markFalsePositive(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Submit explanation for critical anomaly (station commanders explain to HQ)
router.post('/:id/explanation', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { message } = req.body;
    if (!message || !message.trim()) {
        return res.status(400).json({ success: false, message: 'Explanation message is required' });
    }
    const anomaly = await Anomaly.submitExplanation(req.params.id, req.user.user_id, message.trim());
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

module.exports = router;
