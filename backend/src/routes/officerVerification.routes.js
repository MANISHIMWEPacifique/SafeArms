const express = require('express');

const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireRole, ROLES } = require('../middleware/authorization');
const { asyncHandler } = require('../middleware/errorHandler');
const { triggerManualVerificationOps } = require('../jobs/officerVerification.job');
const {
    registerOfficerDevice,
    listOfficerDevices,
    removeOfficerDevice,
    revokeOfficerDevice,
    reassignOfficerDevice,
    createCustodyAssignmentVerificationRequest,
    getPendingVerificationRequestsForOfficer,
    submitVerificationDecision,
    getVerificationStatus,
    getVerificationMetrics,
    getIncidentFallbackSummary
} = require('../services/officerVerification.service');

const router = express.Router();

// Commander enrolls an officer device and receives one-time device token.
router.post('/devices/register', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const result = await registerOfficerDevice({
        officerId: req.body.officer_id,
        platform: req.body.platform,
        deviceName: req.body.device_name,
        deviceFingerprint: req.body.device_fingerprint,
        appVersion: req.body.app_version,
        metadata: req.body.metadata,
        enrolledBy: req.user.user_id,
        requestingUser: req.user
    });

    res.status(result.reused_existing_device ? 200 : 201).json({
        success: true,
        message: 'Officer device enrolled successfully',
        data: result
    });
}));

router.get('/devices/officer/:officer_id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const devices = await listOfficerDevices({
        officerId: req.params.officer_id,
        includeRevoked: req.query.include_revoked === 'true',
        requestingUser: req.user
    });

    res.json({ success: true, data: devices });
}));

router.delete('/devices/:device_key', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const device = await removeOfficerDevice({
        deviceKey: req.params.device_key,
        removedBy: req.user.user_id,
        requestingUser: req.user
    });

    res.json({
        success: true,
        message: 'Officer device removed successfully',
        data: device
    });
}));

router.patch('/devices/:device_key/revoke', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const device = await revokeOfficerDevice({
        deviceKey: req.params.device_key,
        revokedBy: req.user.user_id,
        requestingUser: req.user
    });

    res.json({
        success: true,
        message: 'Officer device revoked successfully',
        data: device
    });
}));

router.patch('/devices/:device_key/reassign', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const device = await reassignOfficerDevice({
        deviceKey: req.params.device_key,
        officerId: req.body.officer_id,
        reassignedBy: req.user.user_id,
        requestingUser: req.user
    });

    res.json({
        success: true,
        message: 'Officer device reassigned successfully',
        data: device
    });
}));

// Commander creates (or reuses) a pending custody-assignment verification request.
router.post('/requests/custody/:custody_id', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const request = await createCustodyAssignmentVerificationRequest({
        custodyId: req.params.custody_id,
        requestedBy: req.user.user_id,
        requestingUser: req.user,
        ttlMinutes: req.body?.ttl_minutes,
        targetDeviceKey: req.body?.device_key
    });

    res.status(request.is_existing ? 200 : 201).json({
        success: true,
        message: request.is_existing
            ? 'Existing pending verification request returned'
            : 'Custody assignment verification request created successfully',
        data: request
    });
}));

router.get('/requests/:verification_id/status', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const status = await getVerificationStatus({ verificationId: req.params.verification_id });

    if (req.user.role === ROLES.STATION_COMMANDER && req.user.unit_id !== status.unit_id) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only view verification requests for your unit.'
        });
    }

    res.json({ success: true, data: status });
}));

router.get('/ops/metrics', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const days = req.query.days;
    let unitId = req.query.unit_id || null;

    if (req.user.role === ROLES.STATION_COMMANDER) {
        unitId = req.user.unit_id;
    }

    const metrics = await getVerificationMetrics({ days, unitId });
    res.json({ success: true, data: metrics });
}));

router.get('/ops/incident-summary', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const summary = await getIncidentFallbackSummary({ days: req.query.days });
    res.json({ success: true, data: summary });
}));

router.post('/ops/run-maintenance', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const result = await triggerManualVerificationOps();
    res.json(result);
}));

// Officer mobile endpoints use device credentials (no user login required).
router.post('/mobile/pending', asyncHandler(async (req, res) => {
    const requests = await getPendingVerificationRequestsForOfficer({
        officerId: req.body.officer_id,
        deviceKey: req.body.device_key,
        deviceToken: req.body.device_token
    });

    res.json({ success: true, data: requests });
}));

router.post('/mobile/decision', asyncHandler(async (req, res) => {
    const decision = await submitVerificationDecision({
        verificationId: req.body.verification_id,
        officerId: req.body.officer_id,
        deviceKey: req.body.device_key,
        deviceToken: req.body.device_token,
        challengeCode: req.body.challenge_code,
        decision: req.body.decision,
        reason: req.body.reason,
        metadata: req.body.metadata
    });

    res.json({
        success: true,
        message: 'Verification decision submitted successfully',
        data: decision
    });
}));

module.exports = router;