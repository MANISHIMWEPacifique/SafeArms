/**
 * Role-Based Access Control (RBAC) Middleware
 * Enforces permission rules based on user roles
 * 
 * ROLE PERMISSIONS MATRIX:
 * ============================================
 * | Permission              | Admin | HQ Cmd | Station Cmd | Forensic |
 * |-------------------------|-------|--------|-------------|----------|
 * | Create Ballistic Profile|  No   |  Yes   |     No      |    No    |
 * | Read Ballistic Profile  |  Yes* |  Yes   |     No      |    Yes   |
 * | Read Custody History    |  Yes  |  Yes   |   Unit Only |    Yes   |
 * | Assign/Return Custody   |  No   |  Yes   |   Unit Only |    No    |
 * | View All Firearms       |  Yes  |  Yes   |     No      |    Yes   |
 * | View Unit Firearms      |  Yes  |  Yes   |   Unit Only |    Yes   |
 * | System Administration   |  Yes  |  No    |     No      |    No    |
 * ============================================
 * * Admin has audit access only (for compliance review)
 */

const ROLES = {
    ADMIN: 'admin',
    HQ_COMMANDER: 'hq_firearm_commander',
    STATION_COMMANDER: 'station_commander',
    FORENSIC_ANALYST: 'forensic_analyst'
};

/**
 * Permission definitions for centralized access control
 */
const PERMISSIONS = {
    // Ballistic permissions
    BALLISTIC_CREATE: [ROLES.HQ_COMMANDER],
    BALLISTIC_READ: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    BALLISTIC_ACCESS_HISTORY: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    BALLISTIC_VERIFY_INTEGRITY: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST],
    
    // Custody permissions
    CUSTODY_ASSIGN: [ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER],
    CUSTODY_RETURN: [ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER],
    CUSTODY_READ_ALL: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    CUSTODY_READ_UNIT: [ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    
    // Firearm permissions
    FIREARM_CREATE: [ROLES.HQ_COMMANDER],
    FIREARM_READ_ALL: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    FIREARM_READ_UNIT: [ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    FIREARM_UPDATE: [ROLES.HQ_COMMANDER, ROLES.STATION_COMMANDER],
    FIREARM_FULL_HISTORY: [ROLES.HQ_COMMANDER, ROLES.FORENSIC_ANALYST, ROLES.ADMIN],
    
    // Cross-unit reports (organization-wide view)
    CROSS_UNIT_REPORTS: [ROLES.HQ_COMMANDER, ROLES.ADMIN],
    
    // System administration
    SYSTEM_ADMIN: [ROLES.ADMIN],
    USER_MANAGEMENT: [ROLES.ADMIN]
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
 * Check permission using centralized PERMISSIONS object
 * @param {string} permission - Permission key from PERMISSIONS
 */
const requirePermission = (permission) => {
    const allowedRoles = PERMISSIONS[permission];
    if (!allowedRoles) {
        throw new Error(`Unknown permission: ${permission}`);
    }
    return requireRole(allowedRoles);
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
 * Ballistic data access - CENTRALIZED CHECK
 * Station Commanders are EXPLICITLY DENIED access to ballistic data
 * Only: HQ Commander, Forensic Analyst, Admin (audit only)
 */
const requireBallisticAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Authentication required'
        });
    }

    const { role } = req.user;

    // EXPLICIT DENY: Station commanders cannot access ballistic data
    if (role === ROLES.STATION_COMMANDER) {
        return res.status(403).json({
            success: false,
            message: 'Access denied. Station Commanders do not have access to ballistic profile data.',
            code: 'BALLISTIC_ACCESS_DENIED'
        });
    }

    // ALLOW: HQ Commander, Forensic Analyst, Admin
    if (PERMISSIONS.BALLISTIC_READ.includes(role)) {
        return next();
    }

    return res.status(403).json({
        success: false,
        message: 'Access denied. Your role does not have ballistic data access.'
    });
};

/**
 * Check if user has access to specific unit
 * Station Commanders are locked to their assigned unit
 * HQ Commanders, Forensic Analysts, and Admins have national access
 */
const requireUnitAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Authentication required'
        });
    }

    // Admin, HQ Commander, and Forensic Analyst have access to all units
    if (req.user.role === ROLES.ADMIN || 
        req.user.role === ROLES.HQ_COMMANDER ||
        req.user.role === ROLES.FORENSIC_ANALYST) {
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
 * Unit-level firearm access check
 * Ensures station commanders can only access firearms in their unit
 * Returns filter for database queries
 */
const enforceUnitFirearmAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Authentication required'
        });
    }

    const { role, unit_id: userUnitId } = req.user;

    // Station commanders are strictly limited to their unit
    if (role === ROLES.STATION_COMMANDER) {
        req.unitFirearmFilter = userUnitId;
        req.isUnitRestricted = true;
    } else {
        req.unitFirearmFilter = null;
        req.isUnitRestricted = false;
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

/**
 * Custody history access - allows forensic analyst read-only
 */
const requireCustodyHistoryAccess = (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({
            success: false,
            message: 'Authentication required'
        });
    }

    const { role, unit_id: userUnitId } = req.user;

    // Full access for HQ, Forensic, Admin
    if (PERMISSIONS.CUSTODY_READ_ALL.includes(role)) {
        req.custodyFilter = null; // No filter
        return next();
    }

    // Station commanders: unit-restricted access
    if (role === ROLES.STATION_COMMANDER) {
        req.custodyFilter = userUnitId;
        return next();
    }

    return res.status(403).json({
        success: false,
        message: 'Access denied. Your role does not have custody history access.'
    });
};

module.exports = {
    ROLES,
    PERMISSIONS,
    requireRole,
    requirePermission,
    requireAdmin,
    requireHQCommander,
    requireStationCommander,
    requireForensicAnalyst,
    requireAdminOrHQ,
    requireCommander,
    requireBallisticAccess,
    requireUnitAccess,
    enforceUnitFirearmAccess,
    requireOwnerOrAdmin,
    requireCustodyHistoryAccess
};
