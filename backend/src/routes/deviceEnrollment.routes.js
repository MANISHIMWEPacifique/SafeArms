const express = require('express');
const crypto = require('crypto');
const { query } = require('../config/database');
const { AppError, asyncHandler } = require('../middleware/errorHandler');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, ROLES } = require('../middleware/authorization');
const logger = require('../utils/logger');
const { registerOfficerDevice } = require('../services/officerVerification.service');

const router = express.Router();

const generateSecurePin = () => {
    // Generate a 6-digit numeric PIN
    const min = 100000;
    const max = 999999;
    return Math.floor(crypto.randomInt(min, max + 1)).toString();
};

const getActiveOfficerDevice = async (officerId) => {
    const result = await query(
        `SELECT device_key
         FROM officer_devices
         WHERE officer_id = $1
           AND is_revoked = false
         ORDER BY COALESCE(last_seen_at, enrolled_at, created_at) DESC, created_at DESC
         LIMIT 1`,
        [officerId]
    );

    return result.rows[0] || null;
};

const rollbackConsumedPin = async ({ pin, officerId, unitId }) => {
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
        logger.warn(`PIN rollback affected 0 rows after enrollment conflict for officer ${officerId}`);
    }
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

    const officerResult = await query(
        `SELECT officer_id, unit_id, is_active
         FROM officers
         WHERE officer_id = $1`,
        [officerId]
    );

    if (officerResult.rowCount === 0) {
        throw new AppError('Officer not found', 404);
    }

    const officer = officerResult.rows[0];
    if (!officer.is_active) {
        throw new AppError('Officer is inactive and cannot enroll a device', 409);
    }

    if (officer.unit_id !== unitId) {
        throw new AppError('Officer does not belong to the provided unit', 409);
    }

    if (req.user.role === ROLES.STATION_COMMANDER && req.user.unit_id !== officer.unit_id) {
        throw new AppError('Access denied. You can only enroll officers in your unit.', 403);
    }

    const activeDevice = await getActiveOfficerDevice(officerId);
    if (activeDevice) {
        throw new AppError(
            'Officer already has an active enrolled device. Remove it before generating a new PIN.',
            409
        );
    }

    const expiresAt = new Date(Date.now() + 15 * 60 * 1000); // 15 minutes
    let pin;

    for (let attempt = 0; attempt < 5; attempt += 1) {
        pin = generateSecurePin();

        try {
            await query(
                `INSERT INTO device_enrollment_pins (pin, officer_id, unit_id, created_by, expires_at)
                 VALUES ($1, $2, $3, $4, $5)`,
                [pin, officerId, officer.unit_id, createdBy, expiresAt]
            );
            break;
        } catch (error) {
            if (error.code === '23505' && attempt < 4) {
                continue;
            }
            throw error;
        }
    }

    if (!pin) {
        throw new AppError('Unable to generate enrollment PIN right now. Please try again.', 500);
    }

    logger.info(`Generated enrollment PIN for officer ${officerId}`, {
        officerId,
        unitId: officer.unit_id,
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

    const activeDevice = await getActiveOfficerDevice(officerId);
    if (activeDevice) {
        await rollbackConsumedPin({ pin, officerId, unitId });
        throw new AppError(
            'Officer already has an active enrolled device. Remove it before enrolling again.',
            409
        );
    }

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
            requestingUser: { role: ROLES.ADMIN, unit_id: unitId } // Bypass checks as we've already proven commander intent via PIN
        });
    } catch (error) {
        try {
            await rollbackConsumedPin({ pin, officerId, unitId });
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
