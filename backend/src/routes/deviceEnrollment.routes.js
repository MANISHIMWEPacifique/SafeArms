const express = require('express');
const crypto = require('crypto');
const { query } = require('../config/database');
const { AppError, asyncHandler } = require('../middleware/errorHandler');
const { authenticate } = require('../middleware/authentication');
const { requireCommander } = require('../middleware/authorization');
const logger = require('../utils/logger');
const { registerOfficerDevice } = require('../services/officerVerification.service');

const router = express.Router();

const generateSecurePin = () => {
    // Generate a 6-digit numeric PIN
    const min = 100000;
    const max = 999999;
    return Math.floor(crypto.randomInt(min, max + 1)).toString();
};

/**
 * POST /api/enrollment/generate-pin
 * Generates a short-lived PIN for a specific officer.
 * Admin/Commander action.
 */
router.post('/generate-pin', authenticate, requireCommander, asyncHandler(async (req, res) => {
    const { officer_id: officerId, unit_id: unitId } = req.body;
    const createdBy = req.user.user_id;

    if (!officerId || !unitId) {
        throw new AppError('officer_id and unit_id are required', 400);
    }

    const pin = generateSecurePin();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes

    await query(
        `INSERT INTO device_enrollment_pins (pin, officer_id, unit_id, created_by, expires_at)
         VALUES ($1, $2, $3, $4, $5)`,
        [pin, officerId, unitId, createdBy, expiresAt]
    );

    logger.info(`Generated enrollment PIN for officer ${officerId}`, {
        officerId,
        unitId,
        createdBy
    });

    res.status(201).json({
        success: true,
        data: {
            pin,
            expires_at: expiresAt
        }
    });
}));

/**
 * POST /api/enrollment/exchange-pin
 * Public endpoint for mobile app to exchange the PIN for true credentials.
 */
router.post('/exchange-pin', asyncHandler(async (req, res) => {
    const { pin, device_fingerprint: deviceFingerprint, device_name: deviceName, platform, app_version: appVersion } = req.body;

    if (!pin || pin.length !== 6) {
        throw new AppError('A valid 6-digit PIN is required', 400);
    }
    if (!deviceFingerprint || !deviceName || !platform) {
        throw new AppError('device_fingerprint, device_name, and platform are required', 400);
    }

    // Validate and consume the PIN
    const pinResult = await query(
        `UPDATE device_enrollment_pins 
         SET is_used = true, used_at = CURRENT_TIMESTAMP
         WHERE pin = $1 
           AND is_used = false 
           AND expires_at > CURRENT_TIMESTAMP
                 RETURNING officer_id, unit_id, created_by`,
        [pin]
    );

    if (pinResult.rowCount === 0) {
        throw new AppError('Invalid or expired PIN', 401);
    }

    const { officer_id: officerId, unit_id: unitId, created_by: createdBy } = pinResult.rows[0];

    // Register the device under this officer
    // In the background this bypasses the standard commander check since the PIN generation acted as the authorization.
    let enrollment;
    try {
        enrollment = await registerOfficerDevice({
            officerId,
            platform,
            deviceName,
            deviceFingerprint,
            appVersion,
            enrolledBy: createdBy || null,
            requestingUser: { role: 'admin', unit_id: unitId } // Bypass checks as we've already proven commander intent via PIN
        });
    } catch (error) {
        try {
            const rollbackResult = await query(
                `UPDATE device_enrollment_pins
                 SET is_used = false, used_at = NULL
                 WHERE pin = $1
                   AND officer_id = $2
                   AND unit_id = $3
                   AND is_used = true`,
                [pin, officerId, unitId]
            );

            if (rollbackResult.rowCount === 0) {
                logger.warn(`PIN rollback affected 0 rows after enrollment failure for officer ${officerId}`);
            }
        } catch (rollbackError) {
            logger.warn(`Failed to rollback consumed PIN for officer ${officerId}: ${rollbackError.message}`);
        }

        throw error;
    }

    const enrolledDeviceKey = enrollment?.device?.device_key;
    const enrolledDeviceToken = enrollment?.device_token;

    if (!enrolledDeviceKey || !enrolledDeviceToken) {
        throw new AppError('Enrollment completed but device credentials payload is incomplete', 500);
    }

    logger.info(`Exchanged PIN for officer device credentials`, {
        officerId,
        deviceKey: enrolledDeviceKey,
        pin: '*****'
    });

    res.status(200).json({
        success: true,
        data: {
            officer_id: officerId,
            device_key: enrolledDeviceKey,
            device_token: enrolledDeviceToken
        }
    });
}));

module.exports = router;
