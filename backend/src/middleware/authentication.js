const { verifyToken } = require('../config/auth');

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

        // Attach user info to request
        req.user = {
            user_id: decoded.user_id,
            username: decoded.username,
            role: decoded.role,
            unit_id: decoded.unit_id,
            email: decoded.email
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
