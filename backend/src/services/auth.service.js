const bcrypt = require('bcrypt');
const { query } = require('../config/database');
const { generateToken, generateOTP, getOTPExpiration, BCRYPT_ROUNDS } = require('../config/auth');
const { sendOTPEmail } = require('./email.service');
const logger = require('../utils/logger');

/**
 * Authenticate user with username and password
 * Generates and sends OTP to user's email
 * @param {string} username
 * @param {string} password
 * @returns {Promise<Object>} User info without password
 */
const login = async (username, password) => {
    try {
        // Find user by username
        const result = await query(
            `SELECT user_id, username, password_hash, full_name, email, 
              phone_number, role, unit_id,is_active, must_change_password 
       FROM users 
       WHERE username = $1`,
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('Invalid username or password');
        }

        const user = result.rows[0];

        // Check if user is active
        if (!user.is_active) {
            throw new Error('Account is inactive. Contact administrator.');
        }

        // Verify password
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);

        if (!isPasswordValid) {
            throw new Error('Invalid username or password');
        }

        // Generate OTP
        const otp = generateOTP();
        const otpExpiresAt = getOTPExpiration();

        // Store OTP in database
        await query(
            `UPDATE users 
       SET otp_code = $1, 
           otp_expires_at = $2, 
           otp_verified = false,
           last_login = CURRENT_TIMESTAMP
       WHERE user_id = $3`,
            [otp, otpExpiresAt, user.user_id]
        );

        // In development mode, skip email and log OTP to console
        if (process.env.NODE_ENV === 'development') {
            console.log(`\n========================================`);
            console.log(`🔐 DEV MODE - OTP for ${user.username}: ${otp}`);
            console.log(`========================================\n`);
        } else {
            // Send OTP via email in production
            await sendOTPEmail(user.email, user.full_name, otp);
        }

        logger.info(`Login initiated for user: ${username}`);

        // Return user info (without password and OTP)
        return {
            user_id: user.user_id,
            username: user.username,
            full_name: user.full_name,
            email: user.email,
            role: user.role,
            unit_id: user.unit_id,
            must_change_password: user.must_change_password,
            otp_sent: true,
            otp_expires_in: 300 // seconds
        };
    } catch (error) {
        logger.error('Login error:', error);
        throw error;
    }
};

/**
 * Verify OTP and complete authentication
 * @param {string} username
 * @param {string} otp
 * @returns {Promise<Object>} JWT token and user info
 */
const verifyOTP = async (username, otp) => {
    try {
        // Get user with OTP info
        const result = await query(
            `SELECT user_id, username, full_name, email, role, unit_id,
              otp_code, otp_expires_at, otp_verified, unit_confirmed
       FROM users 
       WHERE username = $1`,
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        // Check if OTP already verified
        if (user.otp_verified) {
            throw new Error('OTP already used. Please request a new code.');
        }

        // Check if OTP exists
        if (!user.otp_code) {
            throw new Error('No OTP found. Please login again.');
        }

        // Check if OTP expired
        const now = new Date();
        const expiresAt = new Date(user.otp_expires_at);

        if (now > expiresAt) {
            throw new Error('OTP expired. Please login again.');
        }

        // Verify OTP code
        if (user.otp_code !== otp) {
            throw new Error('Invalid OTP code');
        }

        // Mark OTP as verified
        await query(
            'UPDATE users SET otp_verified = true WHERE user_id = $1',
            [user.user_id]
        );

        // Generate JWT token
        const token = generateToken(user);

        logger.info(`OTP verified for user: ${username}`);

        return {
            token,
            user: {
                user_id: user.user_id,
                username: user.username,
                full_name: user.full_name,
                email: user.email,
                role: user.role,
                unit_id: user.unit_id,
                unit_confirmed: user.unit_confirmed,
                requires_unit_confirmation: user.role === 'station_commander' && !user.unit_confirmed
            }
        };
    } catch (error) {
        logger.error('OTP verification error:', error);
        throw error;
    }
};

/**
 * Resend OTP code to user's email
 * @param {string} username
 * @returns {Promise<Object>}
 */
const resendOTP = async (username) => {
    try {
        // Get user
        const result = await query(
            'SELECT user_id, email, full_name FROM users WHERE username = $1',
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        // Generate new OTP
        const otp = generateOTP();
        const otpExpiresAt = getOTPExpiration();

        // Update OTP in database
        await query(
            `UPDATE users 
       SET otp_code = $1, otp_expires_at = $2, otp_verified = false
       WHERE user_id = $3`,
            [otp, otpExpiresAt, user.user_id]
        );

        // Send OTP via email
        await sendOTPEmail(user.email, user.full_name, otp);

        logger.info(`OTP resent for user: ${username}`);

        return {
            success: true,
            message: 'OTP sent to your email',
            otp_expires_in: 300
        };
    } catch (error) {
        logger.error('Resend OTP error:', error);
        throw error;
    }
};

/**
 * Change user password
 * @param {string} userId
 * @param {string} oldPassword
 * @param {string} newPassword
 * @returns {Promise<Object>}
 */
const changePassword = async (userId, oldPassword, newPassword) => {
    try {
        // Get current password hash
        const result = await query(
            'SELECT password_hash FROM users WHERE user_id = $1',
            [userId]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        // Verify old password
        const isPasswordValid = await bcrypt.compare(oldPassword, user.password_hash);

        if (!isPasswordValid) {
            throw new Error('Current password is incorrect');
        }

        // Hash new password
        const newPasswordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

        // Update password and reset must_change_password flag
        await query(
            `UPDATE users 
       SET password_hash = $1, must_change_password = false, updated_at = CURRENT_TIMESTAMP
       WHERE user_id = $2`,
            [newPasswordHash, userId]
        );

        logger.info(`Password changed for user ID: ${userId}`);

        return {
            success: true,
            message: 'Password changed successfully'
        };
    } catch (error) {
        logger.error('Change password error:', error);
        throw error;
    }
};

/**
 * Confirm unit assignment for Station Commander
 * @param {string} userId
 * @param {string} unitId
 * @returns {Promise<Object>}
 */
const confirmUnit = async (userId, unitId) => {
    try {
        // Verify user is a station commander and unit matches
        const result = await query(
            `SELECT role, unit_id, unit_confirmed 
       FROM users 
       WHERE user_id = $1`,
            [userId]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        if (user.role !== 'station_commander') {
            throw new Error('Only station commanders need to confirm units');
        }

        if (user.unit_id !== unitId) {
            throw new Error('Unit ID does not match assigned unit');
        }

        if (user.unit_confirmed) {
            throw new Error('Unit already confirmed');
        }

        // Confirm unit
        await query(
            'UPDATE users SET unit_confirmed = true WHERE user_id = $1',
            [userId]
        );

        logger.info(`Unit confirmed for user ID: ${userId}`);

        return {
            success: true,
            message: 'Unit confirmed successfully'
        };
    } catch (error) {
        logger.error('Confirm unit error:', error);
        throw error;
    }
};

module.exports = {
    login,
    verifyOTP,
    resendOTP,
    changePassword,
    confirmUnit
};
