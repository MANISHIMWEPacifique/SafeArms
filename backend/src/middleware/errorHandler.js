const logger = require('../utils/logger');

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

    // Default error status and message
    let statusCode = err.statusCode || 500;
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
    asyncHandler
};
