const { query } = require('../config/database');
const { AppError } = require('../middleware/errorHandler');
const logger = require('../utils/logger');
const { ROLES } = require('../middleware/authorization');
const { assignCustody, returnCustody } = require('./custody.service');
const {
    createCustodyAssignmentVerificationRequest,
    markVerificationConsumed
} = require('./officerVerification.service');

const serializeAssignmentVerification = (request) => {
    const metadata =
        request.metadata && typeof request.metadata === 'object'
            ? request.metadata
            : {};

    return {
        created: true,
        verification_id: request.verification_id,
        challenge_code: request.challenge_code,
        expires_at: request.expires_at,
        is_existing: request.is_existing,
        target_device_key: metadata.target_device_key || null
    };
};

const resolveAssignmentUnitId = async ({ payload, user }) => {
    if (user.role === ROLES.STATION_COMMANDER) {
        if (payload.unit_id && payload.unit_id !== user.unit_id) {
            logger.warn(
                `[SECURITY] Station commander ${user.user_id} attempted custody assign in unit ${payload.unit_id} (assigned: ${user.unit_id})`
            );
        }
        return user.unit_id;
    }

    if (payload.unit_id || !payload.officer_id) {
        return payload.unit_id;
    }

    const officerResult = await query(
        'SELECT unit_id FROM officers WHERE officer_id = $1',
        [payload.officer_id]
    );

    return officerResult.rows[0]?.unit_id || payload.unit_id;
};

const assignCustodyWithVerification = async ({ payload, user }) => {
    const unitId = await resolveAssignmentUnitId({ payload, user });
    const custodyRecord = await assignCustody({
        ...payload,
        unit_id: unitId,
        issued_by: user.user_id
    });

    try {
        const verificationRequest = await createCustodyAssignmentVerificationRequest({
            custodyId: custodyRecord.custody_id,
            requestedBy: user.user_id,
            requestingUser: user,
            ttlMinutes: payload.verification_ttl_minutes,
            targetDeviceKey: payload.verification_device_key
        });

        return {
            custodyRecord,
            verification: serializeAssignmentVerification(verificationRequest)
        };
    } catch (verificationError) {
        logger.warn(
            `Unable to create assignment verification for custody ${custodyRecord.custody_id}: ${verificationError.message}`
        );

        return {
            custodyRecord,
            verification: {
                created: false,
                message: verificationError.message
            }
        };
    }
};

const getReturnableCustody = async ({ custodyId, user }) => {
    const custodyLookup = await query(
        `SELECT custody_id, officer_id, unit_id, returned_at
         FROM custody_records
         WHERE custody_id = $1`,
        [custodyId]
    );

    if (custodyLookup.rows.length === 0) {
        throw new AppError('Custody record not found', 404);
    }

    const custody = custodyLookup.rows[0];
    if (user.role === ROLES.STATION_COMMANDER && user.unit_id !== custody.unit_id) {
        throw new AppError(
            'Access denied. You can only return custody records for your unit.',
            403
        );
    }

    return custody;
};

const findLatestApprovedVerificationId = async (custodyId) => {
    const result = await query(
        `SELECT verification_id
         FROM officer_verification_requests
         WHERE custody_id = $1
           AND decision = 'approved'
           AND consumed_at IS NULL
         ORDER BY COALESCE(decided_at, updated_at, created_at) DESC
         LIMIT 1`,
        [custodyId]
    );

    return result.rows[0]?.verification_id || '';
};

const consumeReturnVerification = async ({ custodyId, requestedVerificationId, user }) => {
    let verificationConsumed = null;
    let warning = null;
    let verificationId = requestedVerificationId;

    if (!verificationId) {
        verificationId = await findLatestApprovedVerificationId(custodyId);
    }

    if (!verificationId) {
        return {
            consumed: false,
            verification_id: null,
            warning: null
        };
    }

    try {
        verificationConsumed = await markVerificationConsumed({
            verificationId,
            custodyId,
            consumedBy: user.user_id
        });
    } catch (verificationError) {
        if (requestedVerificationId) {
            throw verificationError;
        }

        warning =
            'Custody return completed, but approved verification could not be marked as consumed automatically.';
        logger.warn(
            `Custody ${custodyId} returned without verification consumption: ${verificationError.message}`
        );
    }

    return {
        consumed: verificationConsumed !== null,
        verification_id: verificationConsumed?.verification_id || verificationId || null,
        warning
    };
};

const returnCustodyWithVerification = async ({ custodyId, payload, user }) => {
    const custody = await getReturnableCustody({ custodyId, user });
    const requestedVerificationId = String(payload.verification_id || '').trim();

    const custodyRecord = await returnCustody(custodyId, {
        ...payload,
        returned_to: user.user_id
    });

    const verification = await consumeReturnVerification({
        custodyId: custody.custody_id,
        requestedVerificationId,
        user
    });

    return { custodyRecord, verification };
};

module.exports = {
    assignCustodyWithVerification,
    returnCustodyWithVerification
};
