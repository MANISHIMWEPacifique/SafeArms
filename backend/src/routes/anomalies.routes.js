const express = require('express');
const router = express.Router();
const { getAllAnomalies, getUnitAnomalies } = require('../ml/anomalyDetector');
const Anomaly = require('../models/Anomaly');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireAdminOrHQ } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, requireAdminOrHQ, asyncHandler(async (req, res) => {
    const anomalies = await getAllAnomalies(req.query);
    res.json({ success: true, data: anomalies });
}));

router.get('/unit/:unit_id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const anomalies = await getUnitAnomalies(req.params.unit_id, req.query);
    res.json({ success: true, data: anomalies });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const anomaly = await Anomaly.findById(req.params.id);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

router.put('/:id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const anomaly = await Anomaly.update(req.params.id, req.body);
    if (!anomaly) return res.status(404).json({ success: false, message: 'Anomaly not found' });
    res.json({ success: true, data: anomaly });
}));

router.get('/unit/:unit_id/stats', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const stats = await Anomaly.getStatsByUnit(req.params.unit_id);
    res.json({ success: true, data: stats });
}));

module.exports = router;
