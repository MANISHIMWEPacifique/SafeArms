const logger = require('../utils/logger');

/**
 * Custom application error class with HTTP status code
 */
class AppError extends Error {
    constructor(message, statusCode = 500) {
        super(message);
        this.name = 'AppError';
        this.statusCode = statusCode;
    }
}

/**
 * Map common error messages to HTTP status codes
 * Used when services throw plain Error objects without statusCode
 */
const getStatusCodeFromMessage = (message) => {
    if (!message) return 500;
    const msg = message.toLowerCase();

    // 401 Unauthorized
    if (msg.includes('invalid username or password') ||
        msg.includes('invalid otp') ||
        msg.includes('invalid token') ||
        msg.includes('token expired') ||
        msg.includes('authentication required') ||
        msg.includes('no token provided')) {
        return 401;
    }

    // 403 Forbidden
    if (msg.includes('account is inactive') ||
        msg.includes('account is disabled') ||
        msg.includes('access denied') ||
        msg.includes('insufficient permissions') ||
        msg.includes('does not belong to this unit') ||
        msg.includes('cannot assign custody to inactive')) {
        return 403;
    }

    // 404 Not Found
    if (msg.includes('not found') ||
        msg.includes('no user found') ||
        msg.includes('does not exist')) {
        return 404;
    }

    // 409 Conflict
    if (msg.includes('already exists') ||
        msg.includes('already returned') ||
        msg.includes('already in use') ||
        msg.includes('duplicate')) {
        return 409;
    }

    // 429 Too Many Requests
    if (msg.includes('too many attempts') ||
        msg.includes('too many requests')) {
        return 429;
    }

    // 503 Service Unavailable
    if (msg.includes('unable to deliver otp')) {
        return 503;
    }

    // 400 Bad Request
    if (msg.includes('is required') ||
        msg.includes('missing required') ||
        msg.includes('otp expired') ||
        msg.includes('otp has expired')) {
        return 400;
    }

    // 409 Conflict — resource state conflicts
    if (msg.includes('is currently') ||
        msg.includes('cannot return') ||
        msg.includes('cannot assign')) {
        return 409;
    }

    return null; // No match — will default to 500
};

/**
 * Global error handler middleware
 * Catches all errors and returns consistent error responses
 */
const errorHandler = (err, req, res, next) => {
    // Log error
    logger.error('Error:', {
        message: err.message,
        stack: err.stack,
        path: req.path,
        method: req.method,
        user: req.user?.username || 'unauthenticated'
    });

    // Determine status code: explicit > message-based > default 500
    let statusCode = err.statusCode || getStatusCodeFromMessage(err.message) || 500;
    let message = err.message || 'Internal server error';

    // Handle specific error types
    if (err.name === 'ValidationError') {
        statusCode = 400;
        message = 'Validation error';
    }

    if (err.name === 'UnauthorizedError') {
        statusCode = 401;
        message = 'Unauthorized access';
    }

    if (err.code === '23505') {
        // PostgreSQL unique violation
        statusCode = 409;
        message = 'Duplicate entry. Record already exists.';
    }

    if (err.code === '23503') {
        // PostgreSQL foreign key violation
        statusCode = 400;
        message = 'Invalid reference. Related record not found.';
    }

    if (err.code === '23502') {
        // PostgreSQL not null violation
        statusCode = 400;
        message = 'Missing required field.';
    }

    // Send error response
    res.status(statusCode).json({
        success: false,
        message: message,
        error: process.env.NODE_ENV === 'development' ? {
            details: err.message,
            stack: err.stack
        } : undefined
    });
};

/**
 * 404 Not Found handler
 * Catches all undefined routes
 */
const notFoundHandler = (req, res, next) => {
    const error = new Error(`Route not found: ${req.method} ${req.originalUrl}`);
    error.statusCode = 404;
    next(error);
};

/**
 * Async error wrapper
 * Wraps async route handlers to catch errors
 */
const asyncHandler = (fn) => {
    return (req, res, next) => {
        Promise.resolve(fn(req, res, next)).catch(next);
    };
};

module.exports = {
    errorHandler,
    notFoundHandler,
    asyncHandler,
    AppError
};
