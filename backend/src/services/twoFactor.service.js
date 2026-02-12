const { query } = require('../config/database');
const { generateOTP, getOTPExpiration } = require('../config/auth');
const { sendOTPEmail } = require('./email.service');
const logger = require('../utils/logger');

/**
 * Email-based Two-Factor Authentication Service
 * Generates and manages 6-digit OTP codes sent via email
 */

/**
 * Generate and send OTP to user's email
 * @param {string} userId - User ID
 * @returns {Promise<Object>}
 */
const generateAndSendOTP = async (userId) => {
    try {
        // Get user email
        const result = await query(
            'SELECT email, full_name FROM users WHERE user_id = $1',
            [userId]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const { email, full_name } = result.rows[0];

        // Generate OTP
        const otp = generateOTP();
        const otpExpiresAt = getOTPExpiration();

        // Log OTP to console in development mode
        if (process.env.NODE_ENV !== 'production') {
            console.log('\n========================================');
            console.log(`🔐 OTP for ${email}: ${otp}`);
            console.log('========================================\n');
        }

        // Store OTP in database
        await query(
            `UPDATE users 
       SET otp_code = $1, otp_expires_at = $2, otp_verified = false
       WHERE user_id = $3`,
            [otp, otpExpiresAt, userId]
        );

        // Send OTP via email
        await sendOTPEmail(email, full_name, otp);

        logger.info(`OTP generated and sent for user ID: ${userId}`);

        return {
            success: true,
            message: 'OTP sent to your email',
            expires_in: 300 // 5 minutes in seconds
        };
    } catch (error) {
        logger.error('Generate OTP error:', error);
        throw error;
    }
};

/**
 * Verify OTP code
 * @param {string} userId - User ID
 * @param {string} otp - 6-digit OTP code
 * @returns {Promise<boolean>}
 */
const verifyOTPCode = async (userId, otp) => {
    try {
        // Get stored OTP
        const result = await query(
            'SELECT otp_code, otp_expires_at, otp_verified FROM users WHERE user_id = $1',
            [userId]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        // Check if OTP already used
        if (user.otp_verified) {
            throw new Error('OTP already used');
        }

        // Check if OTP exists
        if (!user.otp_code) {
            throw new Error('No OTP found');
        }

        // Check if OTP expired
        const now = new Date();
        const expiresAt = new Date(user.otp_expires_at);

        if (now > expiresAt) {
            throw new Error('OTP expired');
        }

        // Verify OTP code
        if (user.otp_code !== otp) {
            return false;
        }

        // Mark OTP as verified
        await query(
            'UPDATE users SET otp_verified = true WHERE user_id = $1',
            [userId]
        );

        logger.info(`OTP verified for user ID: ${userId}`);

        return true;
    } catch (error) {
        logger.error('Verify OTP error:', error);
        throw error;
    }
};

/**
 * Invalidate OTP (mark as used)
 * @param {string} userId
 * @returns {Promise<void>}
 */
const invalidateOTP = async (userId) => {
    try {
        await query(
            'UPDATE users SET otp_code = NULL, otp_verified = true WHERE user_id = $1',
            [userId]
        );

        logger.info(`OTP invalidated for user ID: ${userId}`);
    } catch (error) {
        logger.error('Invalidate OTP error:', error);
        throw error;
    }
};

module.exports = {
    generateAndSendOTP,
    verifyOTPCode,
    invalidateOTP
};
