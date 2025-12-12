const { query } = require('../config/database');

/**
 * Audit Logger Middleware
 * Logs all sensitive operations to audit_logs table
 */
const auditLogger = (action_type) => {
    return async (req, res, next) => {
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

                    await query(
                        `INSERT INTO audit_logs (
              user_id, action_type, table_name, 
              record_id, new_values, ip_address, 
              user_agent, success
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                        [
                            req.user?.user_id || null,
                            action_type,
                            req.params.table || req.baseUrl.split('/').pop(),
                            req.params.id || req.body.id || null,
                            success ? JSON.stringify(req.body) : null,
                            req.ip || req.connection.remoteAddress,
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
const logCustodyAssignment = auditLogger('ASSIGN_CUSTODY');
const logCustodyReturn = auditLogger('RETURN_CUSTODY');

module.exports = {
    auditLogger,
    logCreate,
    logUpdate,
    logDelete,
    logLogin,
    logLogout,
    logApproval,
    logCustodyAssignment,
    logCustodyReturn
};
