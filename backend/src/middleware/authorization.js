/**
 * Role-Based Access Control (RBAC) Middleware
 * Enforces permission rules based on user roles
 */

const ROLES = {
    ADMIN: 'admin',
    HQ_COMMANDER: 'hq_firearm_commander',
    STATION_COMMANDER: 'station_commander',
    FORENSIC_ANALYST: 'forensic_analyst'
};

/**
 * Check if user has required role(s)
 * @param {string|string[]} allowedRoles - Role or array of roles that can access
 */
const requireRole = (allowedRoles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        // Convert single role to array
        const roles = Array.isArray(allowedRoles) ? allowedRoles : [allowedRoles];

        // Check if user's role is in allowed roles
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Access denied. Insufficient permissions.',
                required_roles: roles,
                user_role: req.user.role
            });
        }

        next();
    };
};

/**
 * Admin only access
 */
const requireAdmin = requireRole(ROLES.ADMIN);

/**
 * HQ Commander only access
 */
const requireHQCommander = requireRole(ROLES.HQ_COMMANDER);

/**
 * Station Commander only access
 */
const requireStationCommander = requireRole(ROLES.STATION_COMMANDER);

/**
 * Forensic Analyst only access
 */
const requireForensicAnalyst = requireRole(ROLES.FORENSIC_ANALYST);

/**
 * Admin or HQ Commander access
 * (Used for system-wide operations and approvals)
 */
const requireAdminOrHQ = requireRole([ROLES.ADMIN, ROLES.HQ_COMMANDER]);

/**
 * Any commander access (HQ or Station)
 * (Used for firearm and custody operations)
 */
const requireCommander = requireRole([ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER]);

/**
 * Check if user has access to specific unit
 * Station Commanders are locked to their assigned unit
 * HQ Commanders and Admins have national access
 */
const requireUnitAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Authentication required'
        });
    }

    // Admin and HQ Commander have access to all units
    if (req.user.role === ROLES.ADMIN || req.user.role === ROLES.HQ_COMMANDER) {
        return next();
    }

    // Station Commander must match unit
    if (req.user.role === ROLES.STATION_COMMANDER) {
        const requestedUnitId = req.params.unit_id || req.body.unit_id || req.query.unit_id;

        if (requestedUnitId && requestedUnitId !== req.user.unit_id) {
            return res.status(403).json({
                success: false,
                message: 'Access denied. You can only access your assigned unit.',
                assigned_unit: req.user.unit_id,
                requested_unit: requestedUnitId
            });
        }
    }

    next();
};

/**
 * Check if user owns the resource or has elevated permissions
 * @param {string} ownerField - Field name containing owner user_id
 */
const requireOwnerOrAdmin = (ownerField = 'user_id') => {
    return async (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        // Admin has access to everything
        if (req.user.role === ROLES.ADMIN) {
            return next();
        }

        // Check if user owns the resource
        const resourceOwnerId = req.params[ownerField] || req.body[ownerField];

        if (resourceOwnerId === req.user.user_id) {
            return next();
        }

        return res.status(403).json({
            success: false,
            message: 'Access denied. You can only modify your own resources.'
        });
    };
};

module.exports = {
    ROLES,
    requireRole,
    requireAdmin,
    requireHQCommander,
    requireStationCommander,
    requireForensicAnalyst,
    requireAdminOrHQ,
    requireCommander,
    requireUnitAccess,
    requireOwnerOrAdmin
};
