/**
 * Helper utility functions
 */

/**
 * Format date to YYYY-MM-DD
 * @param {Date} date
 * @returns {string}
 */
const formatDate = (date) => {
    if (!date) return null;
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
};

/**
 * Format datetime to ISO string
 * @param {Date} date
 * @returns {string}
 */
const formatDateTime = (date) => {
    if (!date) return null;
    return new Date(date).toISOString();
};

/**
 * Calculate days between two dates
 * @param {Date} startDate
 * @param {Date} endDate
 * @returns {number}
 */
const daysBetween = (startDate, endDate) => {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = Math.abs(end - start);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    return diffDays;
};

/**
 * Generate random alphanumeric string
 * @param {number} length
 * @returns {string}
 */
const generateRandomString = (length = 10) => {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
};

/**
 * Calculate pagination metadata
 * @param {number} total - Total records
 * @param {number} page - Current page
 * @param {number} limit - Records per page
 * @returns {Object}
 */
const getPaginationMeta = (total, page, limit) => {
    const totalPages = Math.ceil(total / limit);
    return {
        total,
        page,
        limit,
        totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1
    };
};

/**
 * Remove null/undefined values from object
 * @param {Object} obj
 * @returns {Object}
 */
const removeNullValues = (obj) => {
    return Object.fromEntries(
        Object.entries(obj).filter(([_, v]) => v != null)
    );
};

/**
 * Convert string to title case
 * @param {string} str
 * @returns {string}
 */
const toTitleCase = (str) => {
    if (!str) return '';
    return str.replace(/\w\S*/g, (txt) => {
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
    });
};

/**
 * Truncate string to specified length
 * @param {string} str
 * @param {number} maxLength
 * @returns {string}
 */
const truncate = (str, maxLength = 100) => {
    if (!str || str.length <= maxLength) return str;
    return str.substring(0, maxLength) + '...';
};

/**
 * Group array of objects by key
 * @param {Array} array
 * @param {string} key
 * @returns {Object}
 */
const groupBy = (array, key) => {
    return array.reduce((result, item) => {
        const group = item[key];
        if (!result[group]) {
            result[group] = [];
        }
        result[group].push(item);
        return result;
    }, {});
};

/**
 * Sleep/delay function
 * @param {number} ms - Milliseconds to sleep
 * @returns {Promise}
 */
const sleep = (ms) => {
    return new Promise(resolve => setTimeout(resolve, ms));
};

/**
 * Check if current time is within business hours
 * @returns {boolean}
 */
const isBusinessHours = () => {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Monday-Friday, 6 AM - 6 PM
    return day >= 1 && day <= 5 && hour >= 6 && hour < 18;
};

/**
 * Format number with thousand separators
 * @param {number} num
 * @returns {string}
 */
const formatNumber = (num) => {
    if (num === null || num === undefined) return '0';
    return num.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
};

/**
 * Calculate custody duration in hours
 * @param {Date} issuedAt
 * @param {Date} returnedAt
 * @returns {number}
 */
const calculateCustodyDuration = (issuedAt, returnedAt = new Date()) => {
    const issued = new Date(issuedAt);
    const returned = new Date(returnedAt);
    const durationMs = returned - issued;
    const durationHours = durationMs / (1000 * 60 * 60);
    return Math.round(durationHours * 10) / 10; // Round to 1 decimal
};

module.exports = {
    formatDate,
    formatDateTime,
    daysBetween,
    generateRandomString,
    getPaginationMeta,
    removeNullValues,
    toTitleCase,
    truncate,
    groupBy,
    sleep,
    isBusinessHours,
    formatNumber,
    calculateCustodyDuration
};
