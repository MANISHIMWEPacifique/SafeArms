const { verifyToken } = require('../config/auth');
const { query } = require('../config/database');

const STATION_COMMANDER_ROLE = 'station_commander';
const PENDING_ASSIGNMENT_ALLOWED_PATHS = [
    '/api/auth/confirm-unit',
    '/api/auth/change-password',
    '/api/auth/logout'
];

const isPendingAssignmentAllowedRequest = (req) => {
    const requestPath = req.originalUrl || req.url || '';
    return PENDING_ASSIGNMENT_ALLOWED_PATHS.some((path) => requestPath.startsWith(path));
};

const resolveStationCommanderUnitId = async (decoded) => {
    if (decoded.role !== STATION_COMMANDER_ROLE || decoded.unit_id) {
        return decoded.unit_id || null;
    }

    const result = await query(
        `SELECT unit_id
         FROM users
         WHERE user_id = $1
           AND role = $2
           AND is_active = true`,
        [decoded.user_id, STATION_COMMANDER_ROLE]
    );

    return result.rows[0]?.unit_id || null;
};

/**
 * Authentication middleware - Verify JWT token
 * Attaches decoded user info to req.user
 */
const authenticate = async (req, res, next) => {
    try {
        // Get token from Authorization header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Access denied. No token provided.'
            });
        }

        // Extract token
        const token = authHeader.substring(7); // Remove 'Bearer ' prefix

        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Access denied. Invalid token format.'
            });
        }

        // Verify token
        const decoded = verifyToken(token);

        const resolvedUnitId = await resolveStationCommanderUnitId(decoded);
        const isPendingStationCommanderAssignment = decoded.role === STATION_COMMANDER_ROLE && !resolvedUnitId;

        if (isPendingStationCommanderAssignment && !isPendingAssignmentAllowedRequest(req)) {
            return res.status(403).json({
                success: false,
                message: 'Station commander account is pending unit assignment. Please contact an administrator.',
                code: 'UNIT_ASSIGNMENT_PENDING'
            });
        }

        // Attach user info to request
        req.user = {
            user_id: decoded.user_id,
            username: decoded.username,
            role: decoded.role,
            unit_id: resolvedUnitId,
            email: decoded.email,
            unit_assignment_pending: isPendingStationCommanderAssignment
        };

        next();
    } catch (error) {
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                success: false,
                message: 'Token expired. Please login again.'
            });
        }

        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                success: false,
                message: 'Invalid token. Please login again.'
            });
        }

        return res.status(401).json({
            success: false,
            message: 'Authentication failed.',
            error: error.message
        });
    }
};

/**
 * Optional authentication - Attach user if token exists, but don't require it
 */
const optionalAuthenticate = async (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.substring(7);
            const decoded = verifyToken(token);
            req.user = {
                user_id: decoded.user_id,
                username: decoded.username,
                role: decoded.role,
                unit_id: decoded.unit_id,
                email: decoded.email
            };
        }

        next();
    } catch (error) {
        // Continue without authentication
        next();
    }
};

module.exports = {
    authenticate,
    optionalAuthenticate
};
