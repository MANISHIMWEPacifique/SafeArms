const bcrypt = require('bcrypt');
const { query } = require('../config/database');
const { generateToken, generateOTP, BCRYPT_ROUNDS } = require('../config/auth');
const { sendOTPEmail } = require('./email.service');
const logger = require('../utils/logger');

const DEFAULT_OTP_VALIDITY_MINUTES = 5;
const DEFAULT_MAX_OTP_ATTEMPTS = 5;
const OTP_ALLOWED_EMAIL_SUFFIXES = ['@gmail.com', '@rnp.gov.rw'];
const INSECURE_OTP_CONSOLE_FALLBACK_ENABLED =
    process.env.ALLOW_INSECURE_OTP_CONSOLE_FALLBACK !== 'false' &&
    process.env.NODE_ENV !== 'production';

const clampPositiveInt = (value, fallback) => {
    const parsed = parseInt(value, 10);
    if (!Number.isFinite(parsed) || parsed <= 0) {
        return fallback;
    }

    return parsed;
};

const loadAuthSecuritySettings = async () => {
    const settings = {
        enforce2Fa: true,
        otpValidityMinutes: DEFAULT_OTP_VALIDITY_MINUTES,
        maxOtpAttempts: DEFAULT_MAX_OTP_ATTEMPTS
    };

    try {
        const settingsResult = await query(
            `SELECT setting_key, setting_value
             FROM system_settings
             WHERE setting_key IN ('enforce_2fa', 'otp_validity_minutes', 'max_otp_attempts')`
        );

        for (const row of settingsResult.rows) {
            if (row.setting_key === 'enforce_2fa') {
                settings.enforce2Fa =
                    row.setting_value === true || row.setting_value === 'true';
            }

            if (row.setting_key === 'otp_validity_minutes') {
                settings.otpValidityMinutes = clampPositiveInt(
                    row.setting_value,
                    DEFAULT_OTP_VALIDITY_MINUTES
                );
            }

            if (row.setting_key === 'max_otp_attempts') {
                settings.maxOtpAttempts = clampPositiveInt(
                    row.setting_value,
                    DEFAULT_MAX_OTP_ATTEMPTS
                );
            }
        }
    } catch (error) {
        logger.error('Error fetching auth security settings:', error);
    }

    return settings;
};

const isOtpEmailRoutable = (email) => {
    const normalized = String(email || '').trim().toLowerCase();
    return OTP_ALLOWED_EMAIL_SUFFIXES.some((suffix) => normalized.endsWith(suffix));
};

const deliverOtpOrThrow = async ({ user, otp, context }) => {
    const shouldUseEmail =
        isOtpEmailRoutable(user.email) || process.env.NODE_ENV === 'production';

    if (shouldUseEmail) {
        try {
            await sendOTPEmail(user.email, user.full_name, otp);
            logger.info(`OTP delivered via email for ${context} user: ${user.username}`);
            return;
        } catch (error) {
            logger.error(`OTP email delivery failed for ${context} user ${user.username}:`, error);
            if (!INSECURE_OTP_CONSOLE_FALLBACK_ENABLED) {
                throw new Error('Unable to deliver OTP at this time. Please try again.');
            }
        }
    }

    if (!INSECURE_OTP_CONSOLE_FALLBACK_ENABLED) {
        throw new Error('Unable to deliver OTP at this time. Please contact administrator.');
    }

    // Explicitly opt-in fallback for local demo usage only.
    console.log(`\n========================================`);
    console.log(`[INSECURE OTP FALLBACK ENABLED] OTP for ${user.username} (${user.email}): ${otp}`);
    console.log(`========================================\n`);
    logger.warn(`Using insecure OTP console fallback for ${context} user: ${user.username}`);
};

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
                            phone_number, role, unit_id, profile_photo_url, is_active, must_change_password 
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

        const authSettings = await loadAuthSecuritySettings();
        const is2FaRequired = authSettings.enforce2Fa;
        const otpValidityMinutes = authSettings.otpValidityMinutes;

        if (!is2FaRequired) {
            // Bypass OTP, generate JWT token directly
            await query(
                'UPDATE users SET otp_verified = true, last_login = CURRENT_TIMESTAMP WHERE user_id = $1',
                [user.user_id]
            );

            const token = generateToken(user);
            logger.info(`Login bypass OTP for user: ${username}`);
            
            return {
                token,
                user: {
                    user_id: user.user_id,
                    username: user.username,
                    full_name: user.full_name,
                    email: user.email,
                    role: user.role,
                    unit_id: user.unit_id,
                    profile_photo_url: user.profile_photo_url,
                    must_change_password: user.must_change_password,
                },
                otp_sent: false
            };
        }

        // Generate OTP
        const otp = generateOTP();
        
        // Calculate OTP expiration based on dynamic setting
        const otpExpiresAtSeconds = otpValidityMinutes * 60;
        const otpExpiresAt = new Date(Date.now() + otpExpiresAtSeconds * 1000);

        // Store OTP in database
        await query(
            `UPDATE users 
       SET otp_code = $1, 
           otp_expires_at = $2, 
           otp_verified = false,
           otp_attempts = 0,
           last_login = CURRENT_TIMESTAMP
       WHERE user_id = $3`,
            [otp, otpExpiresAt, user.user_id]
        );

        await deliverOtpOrThrow({ user, otp, context: 'login' });

        logger.info(`Login initiated for user: ${username}`);

        // Return user info (without password and OTP)
        return {
            user_id: user.user_id,
            username: user.username,
            full_name: user.full_name,
            email: user.email,
            role: user.role,
            unit_id: user.unit_id,
            profile_photo_url: user.profile_photo_url,
            must_change_password: user.must_change_password,
            otp_sent: true,
            otp_expires_in: otpValidityMinutes * 60 // use settings value
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
                            profile_photo_url,
                            otp_code, otp_expires_at, otp_attempts, otp_verified, unit_confirmed,
              must_change_password
       FROM users 
       WHERE username = $1`,
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];
        const authSettings = await loadAuthSecuritySettings();
        const maxOtpAttempts = authSettings.maxOtpAttempts;
        const currentAttempts = parseInt(user.otp_attempts, 10) || 0;

        if (currentAttempts >= maxOtpAttempts) {
            throw new Error('Too many invalid OTP attempts. Please login again.');
        }

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
            const nextAttempts = currentAttempts + 1;
            const shouldInvalidateOtp = nextAttempts >= maxOtpAttempts;

            await query(
                `UPDATE users
                 SET otp_attempts = $1,
                     otp_code = CASE WHEN $2 THEN NULL ELSE otp_code END,
                     otp_expires_at = CASE WHEN $2 THEN NULL ELSE otp_expires_at END,
                     otp_verified = false
                 WHERE user_id = $3`,
                [nextAttempts, shouldInvalidateOtp, user.user_id]
            );

            if (shouldInvalidateOtp) {
                throw new Error('Too many invalid OTP attempts. Please login again.');
            }

            const remainingAttempts = maxOtpAttempts - nextAttempts;
            throw new Error(`Invalid OTP code. ${remainingAttempts} attempt(s) remaining.`);
        }

        // Mark OTP as verified
        await query(
            `UPDATE users
             SET otp_verified = true,
                 otp_attempts = 0,
                 otp_code = NULL,
                 otp_expires_at = NULL
             WHERE user_id = $1`,
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
                profile_photo_url: user.profile_photo_url,
                unit_confirmed: user.unit_confirmed,
                must_change_password: user.must_change_password,
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
            'SELECT user_id, username, email, full_name FROM users WHERE username = $1',
            [username]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        const user = result.rows[0];

        const authSettings = await loadAuthSecuritySettings();
        const otpValidityMinutes = authSettings.otpValidityMinutes;

        // Generate new OTP
        const otp = generateOTP();
        const otpExpiresAtSeconds = otpValidityMinutes * 60;
        const otpExpiresAt = new Date(Date.now() + otpExpiresAtSeconds * 1000);

        // Update OTP in database
        await query(
            `UPDATE users 
       SET otp_code = $1,
           otp_expires_at = $2,
           otp_verified = false,
           otp_attempts = 0
       WHERE user_id = $3`,
            [otp, otpExpiresAt, user.user_id]
        );

        await deliverOtpOrThrow({ user, otp, context: 'resend' });

        logger.info(`OTP resent for user: ${username}`);

        return {
            success: true,
            message: 'OTP sent to your email',
            otp_expires_in: otpValidityMinutes * 60
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
