require('dotenv').config();

// Server configuration
const SERVER_CONFIG = {
    port: parseInt(process.env.PORT) || 3000,
    nodeEnv: process.env.NODE_ENV || 'development',
    apiBaseUrl: process.env.API_BASE_URL || 'http://localhost:3000',

    // CORS configuration
    cors: {
        origin: process.env.CORS_ORIGIN || '*',
        credentials: true,
        optionsSuccessStatus: 200
    },

    // Pagination defaults
    pagination: {
        defaultPageSize: parseInt(process.env.DEFAULT_PAGE_SIZE) || 20,
        maxPageSize: parseInt(process.env.MAX_PAGE_SIZE) || 100
    },

    // Rate limiting (optional - can be implemented later)
    rateLimit: {
        windowMs: 15 * 60 * 1000, // 15 minutes
        max: 100 // Limit each IP to 100 requests per windowMs
    },

    // Logging
    logging: {
        level: process.env.LOG_LEVEL || 'info',
        format: process.env.LOG_FORMAT || 'combined'
    }
};

/**
 * Check if server is in production mode
 * @returns {boolean}
 */
const isProduction = () => {
    return SERVER_CONFIG.nodeEnv === 'production';
};

/**
 * Check if server is in development mode
 * @returns {boolean}
 */
const isDevelopment = () => {
    return SERVER_CONFIG.nodeEnv === 'development';
};

module.exports = {
    SERVER_CONFIG,
    isProduction,
    isDevelopment
};
