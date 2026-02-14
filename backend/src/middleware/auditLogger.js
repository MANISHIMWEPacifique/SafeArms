const { query } = require('../config/database');
const crypto = require('crypto');

/**
 * Audit Logger Middleware
 * Logs all sensitive operations to audit_logs table
 * 
 * CHAIN-OF-CUSTODY SUPPORT:
 * - Records who, what, when, and why for every action
 * - Captures actor context (role, unit)
 * - Captures subject context (type, id, name)
 * - Supports legal chain-of-custody reconstruction
 * 
 * IMMUTABILITY:
 * - Logs are append-only (enforced by database triggers)
 * - Records cannot be updated or deleted
 */

/**
 * Generate a unique request ID for correlation using crypto
 */
const generateRequestId = () => crypto.randomUUID();

/**
 * Enhanced audit logger with full chain-of-custody context
 * @param {string} action_type - The type of action being logged
 * @param {Object} options - Additional options
 * @param {boolean} options.isChainOfCustodyEvent - Whether this is a custody chain event
 * @param {string} options.subjectType - Type of subject (firearm, officer, unit, etc.)
 */
const auditLogger = (action_type, options = {}) => {
    const { isChainOfCustodyEvent = false, subjectType = null } = options;

    return async (req, res, next) => {
        // Generate request ID for correlation
        const requestId = generateRequestId();
        req.requestId = requestId;

        // Store original send function
        const originalSend = res.send;

        // Override send function to capture response
        res.send = function (data) {
            // Restore original send
            res.send = originalSend;

            // Log audit trail asynchronously (don't block response)
            setImmediate(async () => {
                try {
                    const success = res.statusCode >= 200 && res.statusCode < 300;

                    // Extract reason from request body or query
                    const reason = req.body?.reason || 
                                   req.body?.assignment_reason || 
                                   req.body?.notes || 
                                   req.query?.reason ||
                                   null;

                    // Extract subject information
                    const subjectId = req.params.id || 
                                      req.params.firearm_id || 
                                      req.body?.firearm_id || 
                                      req.body?.id || 
                                      null;

                    const subjectName = req.body?.serial_number ||
                                        req.body?.name ||
                                        null;

                    // Get old values if this is an update (stored by previous middleware)
                    const oldValues = req.oldValues || null;

                    await query(
                        `INSERT INTO audit_logs (
                            log_id,
                            user_id, 
                            action_type, 
                            table_name, 
                            record_id, 
                            new_values, 
                            ip_address, 
                            user_agent, 
                            success
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)`,
                        [
                            `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substr(2, 3).toUpperCase()}`,
                            req.user?.user_id || null,
                            action_type,
                            req.params.table || req.baseUrl.split('/').pop(),
                            req.params.id || req.body?.id || subjectId || null,
                            success ? JSON.stringify({
                                body: req.body,
                                reason: reason,
                                subject_type: subjectType || req.baseUrl.split('/').pop()?.slice(0, -1),
                                subject_name: subjectName,
                                is_chain_of_custody_event: isChainOfCustodyEvent,
                                request_id: requestId,
                                actor_role: req.user?.role,
                                actor_unit_id: req.user?.unit_id
                            }) : null,
                            req.ip || req.connection?.remoteAddress,
                            req.get('user-agent'),
                            success
                        ]
                    );
                } catch (error) {
                    console.error('Audit logging failed:', error);
                    // Don't throw - audit failure shouldn't break the app
                }
            });

            // Send original response
            return originalSend.call(this, data);
        };

        next();
    };
};

/**
 * Log specific operation types
 */
const logCreate = auditLogger('CREATE');
const logUpdate = auditLogger('UPDATE');
const logDelete = auditLogger('DELETE');
const logLogin = auditLogger('LOGIN');
const logLogout = auditLogger('LOGOUT');
const logApproval = auditLogger('APPROVAL');

// Chain-of-custody specific loggers
const logCustodyAssignment = auditLogger('CUSTODY_ASSIGNED', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logCustodyReturn = auditLogger('CUSTODY_RETURNED', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logCustodyTransfer = auditLogger('CUSTODY_TRANSFERRED', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logUnitTransfer = auditLogger('UNIT_TRANSFER', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logBallisticAccess = auditLogger('BALLISTIC_ACCESS', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'ballistic_profile' 
});

const logBallisticCreate = auditLogger('BALLISTIC_PROFILE_CREATED', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'ballistic_profile' 
});

const logFirearmRegistration = auditLogger('INITIAL_REGISTRATION', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logStatusChange = auditLogger('STATUS_CHANGE', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

const logLossReport = auditLogger('LOSS_REPORTED', { 
    isChainOfCustodyEvent: true, 
    subjectType: 'firearm' 
});

/**
 * Enhanced chain-of-custody logger
 * Logs to both audit_logs and chain_of_custody_audit tables
 * @param {Object} params - The event parameters
 */
const logChainOfCustodyEvent = async (params) => {
    const {
        eventType,
        firearmId,
        actorUserId,
        custodianOfficerId = null,
        unitId,
        previousUnitId = null,
        previousCustodianId = null,
        reason,
        custodyRecordId = null,
        movementId = null,
        ballisticProfileId = null,
        newStatus = null,
        newCondition = null,
        authorizationReference = null,
        ipAddress = null,
        userAgent = null,
        sessionId = null
    } = params;

    try {
        // Use the database function for consistent logging
        await query(
            `SELECT log_chain_of_custody_event(
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17
            )`,
            [
                eventType,
                firearmId,
                actorUserId,
                custodianOfficerId,
                unitId,
                previousUnitId,
                previousCustodianId,
                reason,
                custodyRecordId,
                movementId,
                ballisticProfileId,
                newStatus,
                newCondition,
                authorizationReference,
                ipAddress,
                userAgent,
                sessionId
            ]
        );
    } catch (error) {
        console.error('Chain-of-custody logging failed:', error);
        // Don't throw - logging failure shouldn't break the operation
        // But we should alert on this in production
    }
};

/**
 * Middleware to capture old values before update
 * Use this before update operations to enable change tracking
 */
const captureOldValues = (tableName, idField = 'id') => {
    return async (req, res, next) => {
        try {
            const recordId = req.params.id || req.params[idField] || req.body?.id;
            if (recordId) {
                const result = await query(
                    `SELECT * FROM ${tableName} WHERE ${idField.replace('_id', '')}${idField.includes('_id') ? '' : '_id'} = $1`,
                    [recordId]
                );
                req.oldValues = result.rows[0] || null;
            }
        } catch (error) {
            console.error('Failed to capture old values:', error);
            // Continue anyway - this shouldn't block the operation
        }
        next();
    };
};

/**
 * Verify chain-of-custody integrity for a firearm
 * @param {string} firearmId - The firearm ID to verify
 * @returns {Promise<Object>} - Verification result
 */
const verifyChainIntegrity = async (firearmId) => {
    try {
        const result = await query(
            'SELECT * FROM verify_chain_integrity($1)',
            [firearmId]
        );
        return result.rows[0];
    } catch (error) {
        console.error('Chain integrity verification failed:', error);
        throw error;
    }
};

/**
 * Export legal chain-of-custody report
 * @param {string} firearmId - The firearm ID
 * @param {Date} startDate - Optional start date
 * @param {Date} endDate - Optional end date
 * @returns {Promise<Array>} - Chain of custody records
 */
const exportLegalChainOfCustody = async (firearmId, startDate = null, endDate = null) => {
    try {
        const result = await query(
            'SELECT * FROM export_legal_chain_of_custody($1, $2, $3)',
            [firearmId, startDate, endDate]
        );
        return result.rows;
    } catch (error) {
        console.error('Legal chain export failed:', error);
        throw error;
    }
};

module.exports = {
    auditLogger,
    logCreate,
    logUpdate,
    logDelete,
    logLogin,
    logLogout,
    logApproval,
    logCustodyAssignment,
    logCustodyReturn,
    logCustodyTransfer,
    logUnitTransfer,
    logBallisticAccess,
    logBallisticCreate,
    logFirearmRegistration,
    logStatusChange,
    logLossReport,
    logChainOfCustodyEvent,
    captureOldValues,
    verifyChainIntegrity,
    exportLegalChainOfCustody,
    generateRequestId
};
