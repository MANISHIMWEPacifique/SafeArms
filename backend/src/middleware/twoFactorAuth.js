const { query } = require('../config/database');

/**
 * Email OTP Verification Middleware
 * Checks if OTP is valid and not expired
 * Note: This is for email-based OTP (6-digit code sent to user's email)
 */
const verifyEmailOTP = async (req, res, next) => {
    try {
        const { username, otp } = req.body;

        if (!username || !otp) {
            return res.status(400).json({
                success: false,
                message: 'Username and OTP code are required'
            });
        }

        // Fetch OTP record from database
        const result = await query(
            `SELECT otp_code, otp_expires_at, otp_verified 
       FROM users 
       WHERE username = $1`,
            [username]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const user = result.rows[0];

        // Check if OTP already used
        if (user.otp_verified) {
            return res.status(400).json({
                success: false,
                message: 'OTP already used. Please request a new code.'
            });
        }

        // Check if OTP exists
        if (!user.otp_code) {
            return res.status(400).json({
                success: false,
                message: 'No OTP code found. Please request a new code.'
            });
        }

        // Check if OTP expired
        const now = new Date();
        const expiresAt = new Date(user.otp_expires_at);

        if (now > expiresAt) {
            return res.status(400).json({
                success: false,
                message: 'OTP code expired. Please request a new code.',
                expired_at: expiresAt
            });
        }

        // Verify OTP code
        if (user.otp_code !== otp) {
            return res.status(400).json({
                success: false,
                message: 'Invalid OTP code. Please check and try again.'
            });
        }

        // OTP is valid - continue to next middleware
        next();
    } catch (error) {
        console.error('OTP verification error:', error);
        return res.status(500).json({
            success: false,
            message: 'OTP verification failed',
            error: error.message
        });
    }
};

/**
 * Check if user requires unit confirmation
 * (Only for Station Commanders on first login)
 */
const checkUnitConfirmation = async (req, res, next) => {
    try {
        if (!req.user) {
            return res.status(401).json({
                success: false,
                message: 'Authentication required'
            });
        }

        // Only Station Commanders need unit confirmation
        if (req.user.role !== 'station_commander') {
            return next();
        }

        // Check if unit already confirmed
        const result = await query(
            'SELECT unit_confirmed FROM users WHERE user_id = $1',
            [req.user.user_id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const user = result.rows[0];

        if (!user.unit_confirmed) {
            return res.status(403).json({
                success: false,
                message: 'Unit confirmation required before accessing system',
                requires_unit_confirmation: true
            });
        }

        next();
    } catch (error) {
        console.error('Unit confirmation check error:', error);
        return res.status(500).json({
            success: false,
            message: 'Unit confirmation check failed',
            error: error.message
        });
    }
};

module.exports = {
    verifyEmailOTP,
    checkUnitConfirmation
};
