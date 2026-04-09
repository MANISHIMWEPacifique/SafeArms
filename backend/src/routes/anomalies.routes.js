const express = require('express');
const router = express.Router();
const { getAllAnomalies, getUnitAnomalies } = require('../ml/anomalyDetector');
const Anomaly = require('../models/Anomaly');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireRole, ROLES } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');

// Roles that can view anomalies (admin excluded: training-only policy)
const requireAnomalyAccess = requireRole([
    ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.INVESTIGATOR
]);

// Only station commanders can make anomaly decisions.
const requireStationDecision = requireRole([ROLES.STATION_COMMANDER]);

const parseListFilters = (req) => ({
    ...req.query,
    include_removed: req.query.include_removed === 'true'
});

const ensureStationScope = (req, anomaly) => {
    if (req.user.role !== ROLES.STATION_COMMANDER) {
        return true;
    }

    return anomaly.unit_id === req.user.unit_id;
};

const getScopedAnomaly = async (req, res, anomalyId) => {
    const anomaly = await Anomaly.findById(anomalyId);
    if (!anomaly) {
        res.status(404).json({ success: false, message: 'Anomaly not found' });
        return null;
    }

    if (!ensureStationScope(req, anomaly)) {
        res.status(403).json({
            success: false,
            message: 'Access denied. Station commanders can only manage anomalies from their unit.'
        });
        return null;
    }

    return anomaly;
};

// Get anomalies - role-based scope, excluding dashboard-deleted records by default.
router.get('/', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { role, unit_id } = req.user;
    const filters = parseListFilters(req);

    if (role === 'station_commander') {
        const anomalies = await getUnitAnomalies(unit_id, filters);
        return res.json({ success: true, data: anomalies });
    }

    const anomalies = await getAllAnomalies(filters);
    res.json({ success: true, data: anomalies });
}));

// Investigation search by unit and time interval.
router.get('/investigation/search', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const { unit_id, start_date, end_date, severity, status, limit = 100, offset = 0 } = req.query;
    const includeRemoved = req.query.include_removed === undefined
        ? true
        : req.query.include_removed === 'true';

    const effectiveUnitId = req.user.role === 'station_commander' ? req.user.unit_id : unit_id;

    const results = await Anomaly.searchForInvestigation({
        unit_id: effectiveUnitId,
        start_date,
        end_date,
        severity,
        status,
        include_removed: includeRemoved,
        limit: parseInt(limit),
        offset: parseInt(offset)
    });
    res.json({ success: true, data: results });
}));

router.get('/unit/:unit_id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    if (req.user.role === 'station_commander' && req.user.unit_id !== req.params.unit_id) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view anomalies for your assigned unit.'
        });
    }

    const anomalies = await getUnitAnomalies(req.params.unit_id, parseListFilters(req));
    res.json({ success: true, data: anomalies });
}));

router.get('/unit/:unit_id/stats', authenticate, requireCommander, asyncHandler(async (req, res) => {
    if (req.user.role === 'station_commander' && req.user.unit_id !== req.params.unit_id) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view stats for your assigned unit.'
        });
    }

    const stats = await Anomaly.getStatsByUnit(req.params.unit_id);
    res.json({ success: true, data: stats });
}));

router.get('/:id', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const anomaly = await getScopedAnomaly(req, res, req.params.id);
    if (!anomaly) return;
    res.json({ success: true, data: anomaly });
}));

router.put('/:id', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const anomaly = await Anomaly.update(req.params.id, req.body);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Start investigation on an anomaly
router.post('/:id/investigate', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { notes } = req.body;
    const anomaly = await Anomaly.investigate(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Resolve an anomaly
router.post('/:id/resolve', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { notes } = req.body;
    const anomaly = await Anomaly.resolve(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Mark anomaly as false positive (feeds ML training data)
router.post('/:id/false-positive', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { notes } = req.body;
    const anomaly = await Anomaly.markFalsePositive(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Mark anomaly as acceptable operational change.
router.post('/:id/acceptable-change', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { notes } = req.body;
    const anomaly = await Anomaly.markAcceptableChange(req.params.id, req.user.user_id, notes);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Submit explanation for critical anomaly (station commanders explain to HQ)
router.post('/:id/explanation', authenticate, requireStationDecision, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { message } = req.body;
    if (!message || !message.trim()) {
        return res.status(400).json({ success: false, message: 'Explanation message is required' });
    }
    const anomaly = await Anomaly.submitExplanation(req.params.id, req.user.user_id, message.trim());
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

// Delete anomaly from dashboard views globally (soft delete/archive style).
router.post('/:id/delete-from-dashboard', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { reason } = req.body || {};
    const removed = await Anomaly.removeFromDashboard(req.params.id, req.user.user_id, reason);
    res.json({ success: true, data: removed });
}));

// Backward-compatible alias for existing clients.
router.post('/:id/hide', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const { reason } = req.body || {};
    const result = await Anomaly.removeFromDashboard(req.params.id, req.user.user_id, reason);
    res.json({ success: true, data: result });
}));

// Restore anomaly into dashboard views.
router.delete('/:id/delete-from-dashboard', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const result = await Anomaly.restoreToDashboard(req.params.id, req.user.user_id);
    if (!result) {
        return res.status(404).json({ success: false, message: 'Anomaly was not deleted from dashboard' });
    }

    res.json({ success: true, data: result });
}));

// Backward-compatible alias for existing clients.
router.delete('/:id/hide', authenticate, requireAnomalyAccess, asyncHandler(async (req, res) => {
    const scoped = await getScopedAnomaly(req, res, req.params.id);
    if (!scoped) return;

    const result = await Anomaly.restoreToDashboard(req.params.id, req.user.user_id);
    if (!result) {
        return res.status(404).json({ success: false, message: 'Anomaly was not deleted from dashboard' });
    }

    res.json({ success: true, data: result });
}));

module.exports = router;
