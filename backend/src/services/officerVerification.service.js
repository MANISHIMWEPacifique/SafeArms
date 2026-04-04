const crypto = require('crypto');

const { query } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');

const DEFAULT_POLICY = {
    ttlMinutes: 10,
    maxInvalidAttempts: 5,
    cleanupRetentionDays: 30,
    metricsWindowDays: 14
};

const parseInteger = (value, fallback) => {
    const parsed = Number.parseInt(String(value), 10);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

const isObject = (value) => typeof value === 'object' && value !== null && !Array.isArray(value);

const normalizeRequiredText = (value) => String(value || '').trim();

const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

const normalizePlatform = (platform) => {
    const normalized = String(platform || 'unknown').trim().toLowerCase();
    if (['android', 'ios', 'web'].includes(normalized)) {
        return normalized;
    }
    return 'unknown';
};

const generateDeviceKey = () => `DVK-${crypto.randomBytes(6).toString('hex').toUpperCase()}`;

const generateDeviceToken = () => crypto.randomBytes(24).toString('hex');

const generateChallengeCode = () => {
    const numeric = crypto.randomInt(0, 1000000);
    return String(numeric).padStart(6, '0');
};

const sanitizeDevice = (row) => {
    if (!row) {
        return null;
    }

    return {
        device_key: row.device_key,
        officer_id: row.officer_id,
        unit_id: row.unit_id,
        platform: row.platform,
        device_name: row.device_name,
        device_fingerprint: row.device_fingerprint,
        app_version: row.app_version,
        metadata: row.metadata,
        enrolled_by: row.enrolled_by,
        enrolled_at: row.enrolled_at,
        last_seen_at: row.last_seen_at,
        is_revoked: row.is_revoked,
        revoked_at: row.revoked_at,
        revoked_by: row.revoked_by,
        created_at: row.created_at,
        updated_at: row.updated_at
    };
};

const recordVerificationEvent = async ({
    verificationId = null,
    custodyId = null,
    officerId = null,
    unitId = null,
    deviceKey = null,
    eventType,
    eventStatus = null,
    reason = null,
    metadata = {},
    actorUserId = null
}) => {
    if (!eventType) {
        return;
    }

    try {
        const safeMetadata = isObject(metadata) ? metadata : {};
        await query(
            `INSERT INTO officer_verification_events (
                verification_id,
                custody_id,
                officer_id,
                unit_id,
                device_key,
                event_type,
                event_status,
                reason,
                metadata,
                actor_user_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10)`,
            [
                verificationId,
                custodyId,
                officerId,
                unitId,
                deviceKey,
                eventType,
                eventStatus,
                reason,
                JSON.stringify(safeMetadata),
                actorUserId
            ]
        );
    } catch (error) {
        logger.warn(`Failed to record officer verification event ${eventType}: ${error.message}`);
    }
};

const getCustodyVerificationPolicy = async () => {
    return {
        ttlMinutes: clamp(
            parseInteger(process.env.OFFICER_VERIFICATION_TTL_MINUTES, DEFAULT_POLICY.ttlMinutes),
            2,
            60
        ),
        maxInvalidAttempts: clamp(
            parseInteger(
                process.env.OFFICER_VERIFICATION_MAX_INVALID_ATTEMPTS,
                DEFAULT_POLICY.maxInvalidAttempts
            ),
            1,
            20
        ),
        cleanupRetentionDays: clamp(
            parseInteger(
                process.env.OFFICER_VERIFICATION_CLEANUP_RETENTION_DAYS,
                DEFAULT_POLICY.cleanupRetentionDays
            ),
            7,
            365
        ),
        metricsWindowDays: clamp(
            parseInteger(
                process.env.OFFICER_VERIFICATION_METRICS_WINDOW_DAYS,
                DEFAULT_POLICY.metricsWindowDays
            ),
            1,
            60
        )
    };
};

const getOfficerOrThrow = async (officerId) => {
    const result = await query(
        `SELECT officer_id, unit_id, full_name, rank, is_active
         FROM officers
         WHERE officer_id = $1`,
        [officerId]
    );

    if (result.rows.length === 0) {
        throw new AppError('Officer not found', 404);
    }

    const officer = result.rows[0];
    if (!officer.is_active) {
        throw new AppError('Officer is inactive', 409);
    }

    return officer;
};

const assertStationCommanderUnitAccess = (requestingUser, unitId) => {
    if (!requestingUser) {
        return;
    }

    if (requestingUser.role === 'station_commander' && requestingUser.unit_id !== unitId) {
        throw new AppError('Access denied. You can only manage officers in your unit.', 403);
    }
};

const clearDeviceReferences = async (deviceKey) => {
    await query(
        `UPDATE officer_verification_requests
         SET decided_device_key = NULL,
             updated_at = CURRENT_TIMESTAMP
         WHERE decided_device_key = $1`,
        [deviceKey]
    );

    await query(
        `UPDATE officer_verification_requests
         SET metadata = (COALESCE(metadata, '{}'::jsonb) - 'target_device_key')
                        || jsonb_build_object('request_target_mode', 'officer_any_active_device'),
             updated_at = CURRENT_TIMESTAMP
         WHERE decision = 'pending'
           AND consumed_at IS NULL
           AND COALESCE(metadata ->> 'target_device_key', '') = $1`,
        [deviceKey]
    );
};

const hardDeleteOfficerDeviceRow = async ({ deviceRow, actorUserId, reason }) => {
    await recordVerificationEvent({
        deviceKey: deviceRow.device_key,
        officerId: deviceRow.officer_id,
        unitId: deviceRow.unit_id,
        eventType: 'DEVICE_REVOKED',
        eventStatus: 'revoked',
        reason: reason || 'Device enrollment removed',
        metadata: {
            hard_deleted: true,
            removed_device_key: deviceRow.device_key
        },
        actorUserId: actorUserId || null
    });

    await clearDeviceReferences(deviceRow.device_key);

    const deleteResult = await query(
        `DELETE FROM officer_devices
         WHERE device_key = $1
         RETURNING *`,
        [deviceRow.device_key]
    );

    return deleteResult.rows[0] || null;
};

const enforceSingleActiveDeviceForOfficer = async ({ officerId, keepDeviceKey, actorUserId }) => {
    const staleDeviceResult = await query(
        `SELECT *
         FROM officer_devices
         WHERE officer_id = $1
           AND is_revoked = false
           AND ($2::TEXT IS NULL OR device_key <> $2)
         ORDER BY created_at DESC`,
        [officerId, keepDeviceKey || null]
    );

    const replacementLabel = keepDeviceKey
        ? `Superseded by active device ${keepDeviceKey}`
        : 'Superseded by a new active device enrollment';

    for (const staleDevice of staleDeviceResult.rows) {
        await hardDeleteOfficerDeviceRow({
            deviceRow: staleDevice,
            actorUserId,
            reason: replacementLabel
        });
    }

    return staleDeviceResult.rowCount;
};

const authenticateOfficerDevice = async ({ officerId, deviceKey, deviceToken }) => {
    if (!officerId || !deviceKey || !deviceToken) {
        throw new AppError('officer_id, device_key, and device_token are required', 400);
    }

    const result = await query(
        `SELECT *
         FROM officer_devices
         WHERE device_key = $1
         LIMIT 1`,
        [deviceKey]
    );

    if (result.rows.length === 0) {
        throw new AppError(
            'Device enrollment not found. Re-enroll this phone from Station Commander dashboard.',
            401
        );
    }

    const device = result.rows[0];
    if (device.officer_id !== officerId) {
        throw new AppError(
            'This device is enrolled for a different officer. Check Connection Setup credentials.',
            401
        );
    }

    if (device.is_revoked) {
        throw new AppError(
            'This device is no longer active. Re-enroll the phone from Station Commander dashboard.',
            401
        );
    }

    const incomingHash = hashToken(deviceToken);
    if (incomingHash !== device.token_hash) {
        throw new AppError(
            'Device token is invalid or outdated. Update Connection Setup with latest credentials.',
            401
        );
    }

    await query(
        `UPDATE officer_devices
         SET last_seen_at = CURRENT_TIMESTAMP,
             updated_at = CURRENT_TIMESTAMP
         WHERE device_key = $1`,
        [deviceKey]
    );

    return device;
};

const resolveTargetDeviceKey = async ({ officerId, deviceKey }) => {
    const normalizedDeviceKey = String(deviceKey || '').trim();
    if (!normalizedDeviceKey) {
        return null;
    }

    const result = await query(
        `SELECT device_key
         FROM officer_devices
         WHERE device_key = $1
           AND officer_id = $2
           AND is_revoked = false
         LIMIT 1`,
        [normalizedDeviceKey, officerId]
    );

    if (result.rows.length === 0) {
        throw new AppError('Selected device is not an active enrollment for this officer', 409);
    }

    return result.rows[0].device_key;
};

const registerOfficerDevice = async ({
    officerId,
    platform,
    deviceName,
    deviceFingerprint,
    appVersion,
    metadata,
    enrolledBy,
    requestingUser
}) => {
    if (!officerId) {
        throw new AppError('officer_id is required', 400);
    }

    const normalizedDeviceName = normalizeRequiredText(deviceName);
    if (normalizedDeviceName.length < 3) {
        throw new AppError('device_name is required and must be at least 3 characters', 400);
    }

    const normalizedFingerprint = normalizeRequiredText(deviceFingerprint);
    if (normalizedFingerprint.length < 6) {
        throw new AppError('device_fingerprint is required and must be at least 6 characters', 400);
    }

    const normalizedAppVersion = normalizeRequiredText(appVersion) || null;

    const officer = await getOfficerOrThrow(officerId);
    assertStationCommanderUnitAccess(requestingUser, officer.unit_id);

    const normalizedPlatform = normalizePlatform(platform);
    const safeMetadata = isObject(metadata) ? metadata : {};

    const existingDeviceResult = await query(
        `SELECT *
         FROM officer_devices
         WHERE officer_id = $1
           AND device_fingerprint = $2
           AND is_revoked = false
         ORDER BY created_at DESC
         LIMIT 1`,
        [officerId, normalizedFingerprint]
    );

    const plainToken = generateDeviceToken();
    const tokenHash = hashToken(plainToken);

    if (existingDeviceResult.rows.length > 0) {
        const existing = existingDeviceResult.rows[0];
        const effectiveAppVersion = normalizedAppVersion || existing.app_version;
        const updateResult = await query(
            `UPDATE officer_devices
             SET platform = $1,
                 device_name = $2,
                 app_version = $3,
                 token_hash = $4,
                 metadata = $5::jsonb,
                 updated_at = CURRENT_TIMESTAMP,
                 last_seen_at = CURRENT_TIMESTAMP
             WHERE device_key = $6
             RETURNING *`,
            [
                normalizedPlatform,
                normalizedDeviceName,
                effectiveAppVersion,
                tokenHash,
                JSON.stringify(safeMetadata),
                existing.device_key
            ]
        );

        await recordVerificationEvent({
            deviceKey: existing.device_key,
            officerId: officer.officer_id,
            unitId: officer.unit_id,
            eventType: 'DEVICE_REGISTERED',
            eventStatus: 'active',
            reason: 'Existing device credentials rotated',
            metadata: {
                reused_existing_device: true,
                platform: normalizedPlatform,
                app_version: effectiveAppVersion
            },
            actorUserId: enrolledBy || null
        });

        const removedPreviousDevices = await enforceSingleActiveDeviceForOfficer({
            officerId: officer.officer_id,
            keepDeviceKey: existing.device_key,
            actorUserId: enrolledBy || null
        });

        return {
            device: sanitizeDevice(updateResult.rows[0]),
            device_token: plainToken,
            officer: {
                officer_id: officer.officer_id,
                full_name: officer.full_name,
                unit_id: officer.unit_id
            },
            reused_existing_device: true,
            removed_previous_active_devices: removedPreviousDevices
        };
    }

    const removedPreviousDevices = await enforceSingleActiveDeviceForOfficer({
        officerId: officer.officer_id,
        keepDeviceKey: null,
        actorUserId: enrolledBy || null
    });

    const deviceKey = generateDeviceKey();

    const result = await query(
        `INSERT INTO officer_devices (
            device_key,
            officer_id,
            unit_id,
            platform,
            device_name,
            device_fingerprint,
            app_version,
            token_hash,
            metadata,
            enrolled_by
         )
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb, $10)
         RETURNING *`,
        [
            deviceKey,
            officer.officer_id,
            officer.unit_id,
            normalizedPlatform,
            normalizedDeviceName,
            normalizedFingerprint,
            normalizedAppVersion,
            tokenHash,
            JSON.stringify(safeMetadata),
            enrolledBy || null
        ]
    );

    await recordVerificationEvent({
        deviceKey,
        officerId: officer.officer_id,
        unitId: officer.unit_id,
        eventType: 'DEVICE_REGISTERED',
        eventStatus: 'active',
        reason: 'Device enrolled for officer verification',
        metadata: {
            reused_existing_device: false,
            platform: normalizedPlatform,
            app_version: normalizedAppVersion
        },
        actorUserId: enrolledBy || null
    });

    return {
        device: sanitizeDevice(result.rows[0]),
        device_token: plainToken,
        officer: {
            officer_id: officer.officer_id,
            full_name: officer.full_name,
            unit_id: officer.unit_id
        },
        reused_existing_device: false,
        removed_previous_active_devices: removedPreviousDevices
    };
};

const listOfficerDevices = async ({ officerId, requestingUser, includeRevoked = false }) => {
    if (!officerId) {
        throw new AppError('officer_id is required', 400);
    }

    const officer = await getOfficerOrThrow(officerId);
    assertStationCommanderUnitAccess(requestingUser, officer.unit_id);

    const result = await query(
        `SELECT *
         FROM officer_devices
         WHERE officer_id = $1
           AND ($2::BOOLEAN = true OR is_revoked = false)
         ORDER BY is_revoked ASC, created_at DESC`,
        [officerId, includeRevoked]
    );

    return result.rows.map((row) => sanitizeDevice(row));
};

const removeOfficerDevice = async ({ deviceKey, removedBy, requestingUser }) => {
    if (!deviceKey) {
        throw new AppError('device_key is required', 400);
    }

    const lookupResult = await query(
        `SELECT *
         FROM officer_devices
         WHERE device_key = $1`,
        [deviceKey]
    );

    if (lookupResult.rows.length === 0) {
        throw new AppError('Device not found', 404);
    }

    const existing = lookupResult.rows[0];
    assertStationCommanderUnitAccess(requestingUser, existing.unit_id);

    const deleted = await hardDeleteOfficerDeviceRow({
        deviceRow: existing,
        actorUserId: removedBy || null,
        reason: 'Device removed by commander/admin'
    });

    if (!deleted) {
        throw new AppError('Device not found', 404);
    }

    return sanitizeDevice(deleted);
};

const revokeOfficerDevice = async ({ deviceKey, revokedBy, requestingUser }) => {
    return removeOfficerDevice({
        deviceKey,
        removedBy: revokedBy,
        requestingUser
    });
};

const reassignOfficerDevice = async ({ deviceKey, officerId, reassignedBy, requestingUser }) => {
    if (!deviceKey || !officerId) {
        throw new AppError('device_key and officer_id are required', 400);
    }

    const existingResult = await query(
        `SELECT *
         FROM officer_devices
         WHERE device_key = $1`,
        [deviceKey]
    );

    if (existingResult.rows.length === 0) {
        throw new AppError('Device not found', 404);
    }

    const currentDevice = existingResult.rows[0];
    if (currentDevice.is_revoked) {
        throw new AppError('Cannot reassign a revoked device', 409);
    }

    const targetOfficer = await getOfficerOrThrow(officerId);
    assertStationCommanderUnitAccess(requestingUser, currentDevice.unit_id);
    assertStationCommanderUnitAccess(requestingUser, targetOfficer.unit_id);

    const updateResult = await query(
        `UPDATE officer_devices
         SET officer_id = $1,
             unit_id = $2,
             updated_at = CURRENT_TIMESTAMP,
             metadata = COALESCE(metadata, '{}'::jsonb) || $3::jsonb
         WHERE device_key = $4
         RETURNING *`,
        [
            targetOfficer.officer_id,
            targetOfficer.unit_id,
            JSON.stringify({
                reassigned_from_officer_id: currentDevice.officer_id,
                reassigned_at: new Date().toISOString(),
                reassigned_by: reassignedBy || null
            }),
            deviceKey
        ]
    );

    await recordVerificationEvent({
        deviceKey,
        officerId: targetOfficer.officer_id,
        unitId: targetOfficer.unit_id,
        eventType: 'DEVICE_REASSIGNED',
        eventStatus: 'active',
        reason: `Device reassigned from ${currentDevice.officer_id} to ${targetOfficer.officer_id}`,
        metadata: {
            previous_officer_id: currentDevice.officer_id,
            previous_unit_id: currentDevice.unit_id,
            new_officer_id: targetOfficer.officer_id,
            new_unit_id: targetOfficer.unit_id
        },
        actorUserId: reassignedBy || null
    });

    return sanitizeDevice(updateResult.rows[0]);
};

const expireStaleRequests = async (custodyId = null) => {
    const baseSql = `
        UPDATE officer_verification_requests
        SET decision = 'expired',
            updated_at = CURRENT_TIMESTAMP
        WHERE decision = 'pending'
          AND expires_at <= CURRENT_TIMESTAMP
    `;

    if (custodyId) {
        const scopedResult = await query(
            `${baseSql} AND custody_id = $1
             RETURNING verification_id, custody_id, officer_id, unit_id`,
            [custodyId]
        );

        for (const row of scopedResult.rows) {
            await recordVerificationEvent({
                verificationId: row.verification_id,
                custodyId: row.custody_id,
                officerId: row.officer_id,
                unitId: row.unit_id,
                eventType: 'REQUEST_EXPIRED',
                eventStatus: 'expired',
                reason: 'Expired by periodic cleanup'
            });
        }

        return { expiredCount: scopedResult.rowCount };
    }

    const result = await query(
        `${baseSql}
         RETURNING verification_id, custody_id, officer_id, unit_id`
    );

    for (const row of result.rows) {
        await recordVerificationEvent({
            verificationId: row.verification_id,
            custodyId: row.custody_id,
            officerId: row.officer_id,
            unitId: row.unit_id,
            eventType: 'REQUEST_EXPIRED',
            eventStatus: 'expired',
            reason: 'Expired by periodic cleanup'
        });
    }

    return { expiredCount: result.rowCount };
};

const getNextVerificationId = async () => {
    const idResult = await query(
        `SELECT 'VRQ-' || LPAD(
            CAST(COALESCE(MAX(CAST(SUBSTRING(verification_id FROM 5) AS INTEGER)), 0) + 1 AS TEXT),
            6,
            '0'
        ) AS next_id
        FROM officer_verification_requests
        WHERE verification_id ~ '^VRQ-[0-9]+$'`
    );

    return idResult.rows[0].next_id;
};

const createCustodyAssignmentVerificationRequest = async ({
    custodyId,
    requestedBy,
    requestingUser,
    ttlMinutes,
    targetDeviceKey
}) => {
    if (!custodyId) {
        throw new AppError('custody_id is required', 400);
    }

    if (!requestedBy) {
        throw new AppError('requested_by is required', 400);
    }

    const policy = await getCustodyVerificationPolicy();

    const custodyResult = await query(
        `SELECT cr.custody_id,
                cr.officer_id,
                cr.unit_id,
                cr.firearm_id,
                cr.returned_at,
                cr.assignment_reason,
                o.is_active AS officer_active,
                o.full_name AS officer_name,
                f.serial_number AS firearm_serial
         FROM custody_records cr
         JOIN officers o ON o.officer_id = cr.officer_id
         JOIN firearms f ON f.firearm_id = cr.firearm_id
         WHERE cr.custody_id = $1`,
        [custodyId]
    );

    if (custodyResult.rows.length === 0) {
        throw new AppError('Custody record not found', 404);
    }

    const custody = custodyResult.rows[0];
    assertStationCommanderUnitAccess(requestingUser, custody.unit_id);

    if (custody.returned_at) {
        throw new AppError('Custody already returned', 409);
    }

    if (!custody.officer_active) {
        throw new AppError('Cannot create verification request for inactive officer', 409);
    }

    const activeDeviceResult = await query(
        `SELECT COUNT(*)::INT AS total
         FROM officer_devices
         WHERE officer_id = $1
           AND is_revoked = false`,
        [custody.officer_id]
    );

    const activeDevices = activeDeviceResult.rows[0]?.total || 0;
    if (activeDevices < 1) {
        throw new AppError(
            'Officer has no active mobile device enrollment for verification',
            409
        );
    }

    let scopedDeviceKey = await resolveTargetDeviceKey({
        officerId: custody.officer_id,
        deviceKey: targetDeviceKey
    });

    if (!scopedDeviceKey) {
        const defaultDeviceResult = await query(
            `SELECT device_key
             FROM officer_devices
             WHERE officer_id = $1
               AND is_revoked = false
             ORDER BY COALESCE(last_seen_at, enrolled_at, created_at) DESC, created_at DESC
             LIMIT 1`,
            [custody.officer_id]
        );

        scopedDeviceKey = defaultDeviceResult.rows[0]?.device_key || null;
    }

    await expireStaleRequests(custodyId);

    const pendingResult = await query(
        `SELECT *
         FROM officer_verification_requests
         WHERE custody_id = $1
           AND decision = 'pending'
           AND consumed_at IS NULL
           AND expires_at > CURRENT_TIMESTAMP
         ORDER BY created_at DESC
         LIMIT 1`,
        [custodyId]
    );

    if (pendingResult.rows.length > 0) {
        let pending = pendingResult.rows[0];
        const pendingMetadata = isObject(pending.metadata) ? pending.metadata : {};
        const existingTargetDeviceKey = String(pendingMetadata.target_device_key || '').trim() || null;

        if (scopedDeviceKey && existingTargetDeviceKey !== scopedDeviceKey) {
            const updatedMetadata = {
                ...pendingMetadata,
                target_device_key: scopedDeviceKey,
                request_target_mode: 'single_device'
            };

            const updateResult = await query(
                `UPDATE officer_verification_requests
                 SET metadata = $1::jsonb,
                     updated_at = CURRENT_TIMESTAMP
                 WHERE verification_id = $2
                 RETURNING *`,
                [JSON.stringify(updatedMetadata), pending.verification_id]
            );

            pending = updateResult.rows[0];

            await recordVerificationEvent({
                verificationId: pending.verification_id,
                custodyId: pending.custody_id,
                officerId: pending.officer_id,
                unitId: pending.unit_id,
                eventType: 'REQUEST_TARGET_UPDATED',
                eventStatus: 'pending',
                reason: 'Pending verification request retargeted to a specific device',
                metadata: {
                    target_device_key: scopedDeviceKey
                },
                actorUserId: requestedBy
            });
        }

        await recordVerificationEvent({
            verificationId: pending.verification_id,
            custodyId: pending.custody_id,
            officerId: pending.officer_id,
            unitId: pending.unit_id,
            eventType: 'REQUEST_REUSED',
            eventStatus: 'pending',
            reason: 'Existing pending verification reused',
            metadata: {
                target_device_key: scopedDeviceKey
            },
            actorUserId: requestedBy
        });

        return {
            ...pending,
            is_existing: true,
            policy
        };
    }

    const effectiveTtl = Math.max(
        2,
        Math.min(60, ttlMinutes ? Number(ttlMinutes) : policy.ttlMinutes)
    );

    const verificationId = await getNextVerificationId();
    const challengeCode = generateChallengeCode();

    try {
        const createResult = await query(
            `INSERT INTO officer_verification_requests (
                verification_id,
                request_type,
                custody_id,
                officer_id,
                unit_id,
                firearm_id,
                requested_by,
                challenge_code,
                expires_at,
                metadata
            )
            VALUES (
                $1,
                'custody_assignment',
                $2,
                $3,
                $4,
                $5,
                $6,
                $7,
                CURRENT_TIMESTAMP + ($8::TEXT || ' minutes')::INTERVAL,
                $9::jsonb
            )
            RETURNING *`,
            [
                verificationId,
                custody.custody_id,
                custody.officer_id,
                custody.unit_id,
                custody.firearm_id,
                requestedBy,
                challengeCode,
                effectiveTtl,
                JSON.stringify({
                    officer_name: custody.officer_name,
                    firearm_serial: custody.firearm_serial,
                    assignment_reason: custody.assignment_reason,
                    request_channel: 'custody_assignment',
                    request_target_mode: scopedDeviceKey
                        ? 'single_device'
                        : 'officer_any_active_device',
                    target_device_key: scopedDeviceKey
                })
            ]
        );

        await recordVerificationEvent({
            verificationId,
            custodyId: custody.custody_id,
            officerId: custody.officer_id,
            unitId: custody.unit_id,
            eventType: 'REQUEST_CREATED',
            eventStatus: 'pending',
            reason: 'New custody assignment verification request created',
            metadata: {
                ttl_minutes: effectiveTtl,
                challenge_code: challengeCode,
                target_device_key: scopedDeviceKey
            },
            actorUserId: requestedBy
        });

        return {
            ...createResult.rows[0],
            is_existing: false,
            policy
        };
    } catch (error) {
        // Concurrent request creation can hit unique pending index. Return the existing row.
        if (error.code === '23505') {
            const retryPending = await query(
                `SELECT *
                 FROM officer_verification_requests
                 WHERE custody_id = $1
                   AND decision = 'pending'
                   AND consumed_at IS NULL
                   AND expires_at > CURRENT_TIMESTAMP
                 ORDER BY created_at DESC
                 LIMIT 1`,
                [custodyId]
            );

            if (retryPending.rows.length > 0) {
                await recordVerificationEvent({
                    verificationId: retryPending.rows[0].verification_id,
                    custodyId: retryPending.rows[0].custody_id,
                    officerId: retryPending.rows[0].officer_id,
                    unitId: retryPending.rows[0].unit_id,
                    eventType: 'REQUEST_REUSED',
                    eventStatus: 'pending',
                    reason: 'Concurrent create returned existing pending request',
                    actorUserId: requestedBy
                });

                return {
                    ...retryPending.rows[0],
                    is_existing: true,
                    policy
                };
            }
        }

        throw error;
    }
};

const getPendingVerificationRequestsForOfficer = async ({ officerId, deviceKey, deviceToken }) => {
    await authenticateOfficerDevice({ officerId, deviceKey, deviceToken });
    await expireStaleRequests();

    const result = await query(
        `SELECT vr.verification_id,
                vr.request_type,
                vr.custody_id,
                vr.officer_id,
                vr.unit_id,
                vr.firearm_id,
                vr.challenge_code,
                vr.decision,
                vr.expires_at,
                vr.created_at,
                vr.metadata,
                f.serial_number AS firearm_serial,
                f.manufacturer,
                f.model,
                u.unit_name,
                requester.full_name AS requested_by_name
         FROM officer_verification_requests vr
         JOIN firearms f ON f.firearm_id = vr.firearm_id
         JOIN units u ON u.unit_id = vr.unit_id
         JOIN users requester ON requester.user_id = vr.requested_by
         WHERE vr.officer_id = $1
           AND vr.decision = 'pending'
           AND vr.consumed_at IS NULL
           AND vr.expires_at > CURRENT_TIMESTAMP
                     AND (
                                COALESCE(vr.metadata ->> 'target_device_key', '') = ''
                                OR vr.metadata ->> 'target_device_key' = $2
                     )
         ORDER BY vr.created_at DESC`,
                [officerId, deviceKey]
    );

    return result.rows;
};

const getInvalidAttemptCount = async (verificationId, minutesWindow = 15) => {
    const result = await query(
        `SELECT COUNT(*)::INT AS count
         FROM officer_verification_events
         WHERE verification_id = $1
           AND event_type = 'INVALID_CHALLENGE'
           AND created_at >= CURRENT_TIMESTAMP - ($2::TEXT || ' minutes')::INTERVAL`,
        [verificationId, minutesWindow]
    );

    return result.rows[0]?.count || 0;
};

const submitVerificationDecision = async ({
    verificationId,
    officerId,
    deviceKey,
    deviceToken,
    challengeCode,
    decision,
    reason,
    metadata
}) => {
    const normalizedDecision = String(decision || '').trim().toLowerCase();
    if (!['approve', 'approved', 'reject', 'rejected'].includes(normalizedDecision)) {
        throw new AppError('decision must be approve or reject', 400);
    }

    const finalDecision = normalizedDecision.startsWith('approve') ? 'approved' : 'rejected';

    if (finalDecision === 'rejected' && !String(reason || '').trim()) {
        throw new AppError('reason is required when rejecting a verification request', 400);
    }

    await authenticateOfficerDevice({ officerId, deviceKey, deviceToken });

    const requestResult = await query(
        `SELECT *
         FROM officer_verification_requests
         WHERE verification_id = $1
           AND officer_id = $2`,
        [verificationId, officerId]
    );

    if (requestResult.rows.length === 0) {
        throw new AppError('Verification request not found', 404);
    }

    const requestRow = requestResult.rows[0];
    const requestMetadata = isObject(requestRow.metadata) ? requestRow.metadata : {};
    const targetDeviceKey = String(requestMetadata.target_device_key || '').trim();

    if (targetDeviceKey && targetDeviceKey !== deviceKey) {
        await recordVerificationEvent({
            verificationId,
            custodyId: requestRow.custody_id,
            officerId,
            unitId: requestRow.unit_id,
            deviceKey,
            eventType: 'TARGET_DEVICE_MISMATCH',
            eventStatus: 'rejected',
            reason: 'Decision submitted from non-targeted device',
            metadata: {
                target_device_key: targetDeviceKey
            }
        });

        throw new AppError('Verification request is assigned to another enrolled device', 403);
    }

    if (requestRow.decision !== 'pending') {
        throw new AppError(`Verification request is already ${requestRow.decision}`, 409);
    }

    if (requestRow.expires_at <= new Date()) {
        await query(
            `UPDATE officer_verification_requests
             SET decision = 'expired',
                 updated_at = CURRENT_TIMESTAMP
             WHERE verification_id = $1`,
            [verificationId]
        );
        throw new AppError('Verification request has expired', 409);
    }

    if (requestRow.challenge_code !== challengeCode) {
        const policy = await getCustodyVerificationPolicy();
        const invalidAttempts = await getInvalidAttemptCount(verificationId, 15) + 1;

        await recordVerificationEvent({
            verificationId,
            custodyId: requestRow.custody_id,
            officerId,
            unitId: requestRow.unit_id,
            deviceKey,
            eventType: 'INVALID_CHALLENGE',
            eventStatus: 'rejected',
            reason: 'Invalid challenge code submitted',
            metadata: {
                invalid_attempts: invalidAttempts,
                max_invalid_attempts: policy.maxInvalidAttempts
            }
        });

        if (invalidAttempts >= policy.maxInvalidAttempts) {
            await query(
                `UPDATE officer_verification_requests
                 SET decision = 'cancelled',
                     decision_reason = 'Cancelled due to repeated invalid challenge submissions',
                     updated_at = CURRENT_TIMESTAMP
                 WHERE verification_id = $1`,
                [verificationId]
            );

            await recordVerificationEvent({
                verificationId,
                custodyId: requestRow.custody_id,
                officerId,
                unitId: requestRow.unit_id,
                deviceKey,
                eventType: 'REQUEST_CANCELLED',
                eventStatus: 'cancelled',
                reason: 'Cancelled after invalid challenge threshold reached',
                metadata: {
                    invalid_attempts: invalidAttempts,
                    threshold: policy.maxInvalidAttempts
                }
            });

            throw new AppError('Verification request was cancelled due to repeated invalid attempts', 409);
        }

        throw new AppError('Invalid verification challenge code', 401);
    }

    const safeMetadata = isObject(metadata)
        ? metadata
        : {};

    const mergedMetadata = {
        ...safeMetadata,
        decision_channel: 'mobile_app',
        ...(targetDeviceKey ? { target_device_key: targetDeviceKey } : {})
    };

    const updateResult = await query(
        `UPDATE officer_verification_requests
         SET decision = $1,
             decision_reason = $2,
             decided_at = CURRENT_TIMESTAMP,
             decided_by_officer_id = $3,
             decided_device_key = $4,
             metadata = COALESCE(metadata, '{}'::jsonb) || $5::jsonb,
             updated_at = CURRENT_TIMESTAMP
         WHERE verification_id = $6
         RETURNING *`,
        [
            finalDecision,
            reason || null,
            officerId,
            deviceKey,
            JSON.stringify(mergedMetadata),
            verificationId
        ]
    );

    await recordVerificationEvent({
        verificationId,
        custodyId: updateResult.rows[0].custody_id,
        officerId,
        unitId: updateResult.rows[0].unit_id,
        deviceKey,
        eventType: finalDecision === 'approved' ? 'DECISION_APPROVED' : 'DECISION_REJECTED',
        eventStatus: finalDecision,
        reason: reason || null,
        metadata: mergedMetadata
    });

    return updateResult.rows[0];
};

const getVerificationStatus = async ({ verificationId }) => {
    if (!verificationId) {
        throw new AppError('verification_id is required', 400);
    }

    const result = await query(
        `SELECT vr.*, u.unit_name, requester.full_name AS requested_by_name
         FROM officer_verification_requests vr
         JOIN units u ON u.unit_id = vr.unit_id
         JOIN users requester ON requester.user_id = vr.requested_by
         WHERE vr.verification_id = $1`,
        [verificationId]
    );

    if (result.rows.length === 0) {
        throw new AppError('Verification request not found', 404);
    }

    const row = result.rows[0];
    if (row.decision === 'pending' && row.expires_at <= new Date()) {
        await query(
            `UPDATE officer_verification_requests
             SET decision = 'expired',
                 updated_at = CURRENT_TIMESTAMP
             WHERE verification_id = $1`,
            [verificationId]
        );

        row.decision = 'expired';
    }

    return row;
};

const markVerificationConsumed = async ({ verificationId, custodyId, consumedBy }) => {
    if (!verificationId) {
        throw new AppError('verification_id is required', 400);
    }

    const result = await query(
        `UPDATE officer_verification_requests
         SET consumed_at = CURRENT_TIMESTAMP,
             consumed_by = $1,
             updated_at = CURRENT_TIMESTAMP
         WHERE verification_id = $2
           AND custody_id = $3
           AND decision = 'approved'
           AND consumed_at IS NULL
         RETURNING *`,
        [consumedBy || null, verificationId, custodyId]
    );

    if (result.rows.length === 0) {
        throw new AppError('Unable to mark verification request as consumed', 409);
    }

    const consumed = result.rows[0];
    await recordVerificationEvent({
        verificationId,
        custodyId,
        officerId: consumed.officer_id,
        unitId: consumed.unit_id,
        deviceKey: consumed.decided_device_key,
        eventType: 'REQUEST_CONSUMED',
        eventStatus: 'consumed',
        reason: 'Verification consumed by custody return action',
        actorUserId: consumedBy || null
    });

    return consumed;
};

const getVerificationMetrics = async ({ days = 14, unitId = null }) => {
    const safeDays = Math.max(1, Math.min(60, Number(days) || 14));

    const result = await query(
        `WITH scoped AS (
            SELECT *
            FROM officer_verification_requests
            WHERE created_at >= CURRENT_TIMESTAMP - ($1::TEXT || ' days')::INTERVAL
              AND ($2::TEXT IS NULL OR unit_id = $2)
        )
        SELECT
            COUNT(*)::INT AS total,
            COUNT(*) FILTER (WHERE decision = 'approved')::INT AS approved,
            COUNT(*) FILTER (WHERE decision = 'rejected')::INT AS rejected,
            COUNT(*) FILTER (WHERE decision = 'expired')::INT AS expired,
            COUNT(*) FILTER (WHERE decision = 'cancelled')::INT AS cancelled,
            COUNT(*) FILTER (WHERE decision = 'pending' AND expires_at > CURRENT_TIMESTAMP)::INT AS pending,
            COUNT(*) FILTER (WHERE consumed_at IS NOT NULL)::INT AS consumed,
            ROUND(
                AVG(
                    CASE
                        WHEN decided_at IS NOT NULL THEN EXTRACT(EPOCH FROM (decided_at - created_at))
                        ELSE NULL
                    END
                )
            )::INT AS avg_decision_latency_seconds,
            ROUND(
                100.0 * COUNT(*) FILTER (WHERE decision = 'approved') / NULLIF(COUNT(*), 0),
                2
            )::DECIMAL(6,2) AS approval_rate,
            ROUND(
                100.0 * COUNT(*) FILTER (WHERE decision = 'rejected') / NULLIF(COUNT(*), 0),
                2
            )::DECIMAL(6,2) AS rejection_rate,
            ROUND(
                100.0 * COUNT(*) FILTER (WHERE decision = 'expired') / NULLIF(COUNT(*), 0),
                2
            )::DECIMAL(6,2) AS expiry_rate
        FROM scoped`,
        [safeDays, unitId || null]
    );

    return {
        window_days: safeDays,
        unit_id: unitId,
        ...(result.rows[0] || {})
    };
};

const getIncidentFallbackSummary = async ({ days = 7 }) => {
    const safeDays = Math.max(1, Math.min(30, Number(days) || 7));

    const result = await query(
        `SELECT
            COUNT(*)::INT AS fallback_events,
            MAX(created_at) AS last_fallback_at
         FROM officer_verification_events
         WHERE event_type = 'MANUAL_FALLBACK_USED'
           AND created_at >= CURRENT_TIMESTAMP - ($1::TEXT || ' days')::INTERVAL`,
        [safeDays]
    );

    return {
        window_days: safeDays,
        fallback_events: result.rows[0]?.fallback_events || 0,
        last_fallback_at: result.rows[0]?.last_fallback_at || null
    };
};

module.exports = {
    getCustodyVerificationPolicy,
    recordVerificationEvent,
    registerOfficerDevice,
    listOfficerDevices,
    removeOfficerDevice,
    revokeOfficerDevice,
    reassignOfficerDevice,
    expireStaleRequests,
    createCustodyAssignmentVerificationRequest,
    getPendingVerificationRequestsForOfficer,
    submitVerificationDecision,
    getVerificationStatus,
    markVerificationConsumed,
    getVerificationMetrics,
    getIncidentFallbackSummary
};