/**
 * Input Validation Utilities
 * Provides validation functions for common input types
 */

/**
 * Validate email format
 * @param {string} email
 * @returns {boolean}
 */
const isValidEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
};

/**
 * Validate phone number (Rwanda format)
 * @param {string} phone
 * @returns {boolean}
 */
const isValidPhone = (phone) => {
    // Rwanda phone format: +250XXXXXXXXX or 07XXXXXXXX or 08XXXXXXXX or 09XXXXXXXX
    const phoneRegex = /^(\+?250|0)?[7-9]\d{8}$/;
    return phoneRegex.test(phone);
};

/**
 * Validate password strength
 * At least 8 characters, 1 uppercase, 1 lowercase, 1 number, 1 special char
 * @param {string} password
 * @returns {boolean}
 */
const isValidPassword = (password) => {
    if (!password || password.length < 8) return false;

    const hasUppercase = /[A-Z]/.test(password);
    const hasLowercase = /[a-z]/.test(password);
    const hasNumber = /\d/.test(password);
    const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

    return hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
};

/**
 * Validate UUID format (legacy - for backwards compatibility)
 * @param {string} uuid
 * @returns {boolean}
 */
const isValidUUID = (uuid) => {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    return uuidRegex.test(uuid);
};

/**
 * Validate entity ID format (user-friendly IDs like UNIT-HQ, FA-001, etc.)
 * @param {string} id - The ID to validate
 * @param {string} [prefix] - Optional prefix to check (e.g., 'UNIT', 'FA', 'USR')
 * @returns {boolean}
 */
const isValidEntityId = (id, prefix = null) => {
    if (!id || typeof id !== 'string') return false;
    // Allow formats like: UNIT-HQ, UNIT-NYA, FA-001, USR-001, OFF-001, etc.
    const idRegex = /^[A-Z]{2,5}-[A-Z0-9]{1,10}$/i;
    if (!idRegex.test(id)) return false;
    if (prefix) {
        return id.toUpperCase().startsWith(prefix.toUpperCase() + '-');
    }
    return true;
};

/**
 * Validate serial number format
 * @param {string} serialNumber
 * @returns {boolean}
 */
const isValidSerialNumber = (serialNumber) => {
    // Serial number should be alphanumeric, 6-50 characters
    const serialRegex = /^[A-Z0-9-]{6,50}$/i;
    return serialRegex.test(serialNumber);
};

/**
 * Sanitize string input (remove potentially dangerous characters)
 * @param {string} input
 * @returns {string}
 */
const sanitizeString = (input) => {
    if (!input) return '';
    return input.replace(/[<>]/g, '').trim();
};

/**
 * Validate pagination parameters
 * @param {number} page
 * @param {number} limit
 * @returns {Object} validated parameters
 */
const validatePagination = (page, limit) => {
    const validatedPage = Math.max(1, parseInt(page) || 1);
    const validatedLimit = Math.min(100, Math.max(1, parseInt(limit) || 20));

    return {
        page: validatedPage,
        limit: validatedLimit,
        offset: (validatedPage - 1) * validatedLimit
    };
};

/**
 * Validate date format (YYYY-MM-DD)
 * @param {string} dateString
 * @returns {boolean}
 */
const isValidDate = (dateString) => {
    const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
    if (!dateRegex.test(dateString)) return false;

    const date = new Date(dateString);
    return date instanceof Date && !isNaN(date);
};

/**
 * Validate required fields exist in object
 * @param {Object} obj
 * @param {string[]} requiredFields
 * @returns {Object} {valid: boolean, missing: string[]}
 */
const validateRequiredFields = (obj, requiredFields) => {
    const missing = [];

    for (const field of requiredFields) {
        if (!obj[field] || obj[field] === '') {
            missing.push(field);
        }
    }

    return {
        valid: missing.length === 0,
        missing
    };
};

/**
 * Validate firearm type
 * @param {string} type
 * @returns {boolean}
 */
const isValidFirearmType = (type) => {
    const validTypes = ['pistol', 'rifle', 'shotgun', 'submachine_gun', 'other'];
    return validTypes.includes(type);
};

/**
 * Validate user role
 * @param {string} role
 * @returns {boolean}
 */
const isValidRole = (role) => {
    const validRoles = ['admin', 'hq_firearm_commander', 'station_commander', 'forensic_analyst'];
    return validRoles.includes(role);
};

/**
 * Validate custody type
 * @param {string} type
 * @returns {boolean}
 */
const isValidCustodyType = (type) => {
    const validTypes = ['permanent', 'temporary', 'personal_long_term'];
    return validTypes.includes(type);
};

module.exports = {
    isValidEmail,
    isValidPhone,
    isValidPassword,
    isValidUUID,
    isValidEntityId,
    isValidSerialNumber,
    sanitizeString,
    validatePagination,
    isValidDate,
    validateRequiredFields,
    isValidFirearmType,
    isValidRole,
    isValidCustodyType
};
