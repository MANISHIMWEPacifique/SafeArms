const jwt = require('jsonwebtoken');
require('dotenv').config();

// JWT Configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key_change_in_production_min_32_chars';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';

// Email OTP Configuration
const OTP_EXPIRES_IN = parseInt(process.env.OTP_EXPIRES_IN) || 300; // 5 minutes in seconds
const OTP_LENGTH = 6;
const OTP_ISSUER = process.env.OTP_ISSUER || 'SafeArms RNP';

// Security Configuration
const BCRYPT_ROUNDS = parseInt(process.env.BCRYPT_ROUNDS) || 10;
const MAX_LOGIN_ATTEMPTS = parseInt(process.env.MAX_LOGIN_ATTEMPTS) || 5;
const LOCKOUT_DURATION = parseInt(process.env.LOCKOUT_DURATION) || 900; // 15 minutes in seconds

/**
 * Generate JWT token for authenticated user
 * @param {Object} user - User object
 * @returns {string} JWT token
 */
const generateToken = (user) => {
    const payload = {
        user_id: user.user_id,
        username: user.username,
        role: user.role,
        unit_id: user.unit_id,
        email: user.email
    };

    return jwt.sign(payload, JWT_SECRET, {
        expiresIn: JWT_EXPIRES_IN,
        issuer: OTP_ISSUER
    });
};

/**
 * Verify JWT token
 * @param {string} token - JWT token
 * @returns {Object} Decoded token payload
 */
const verifyToken = (token) => {
    try {
        return jwt.verify(token, JWT_SECRET);
    } catch (error) {
        throw new Error('Invalid or expired token');
    }
};

/**
 * Generate random 6-digit OTP code
 * @returns {string} 6-digit OTP code
 */
const generateOTP = () => {
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    return otp;
};

/**
 * Calculate OTP expiration timestamp
 * @returns {Date} Expiration timestamp
 */
const getOTPExpiration = () => {
    return new Date(Date.now() + OTP_EXPIRES_IN * 1000);
};

module.exports = {
    JWT_SECRET,
    JWT_EXPIRES_IN,
    OTP_EXPIRES_IN,
    OTP_LENGTH,
    OTP_ISSUER,
    BCRYPT_ROUNDS,
    MAX_LOGIN_ATTEMPTS,
    LOCKOUT_DURATION,
    generateToken,
    verifyToken,
    generateOTP,
    getOTPExpiration
};
