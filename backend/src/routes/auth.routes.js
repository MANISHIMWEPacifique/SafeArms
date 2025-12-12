const express = require('express');
const router = express.Router();
const { login, verifyOTP, resendOTP, changePassword, confirmUnit } = require('../services/auth.service');
const { authenticate } = require('../middleware/authentication');
const { verifyEmailOTP } = require('../middleware/twoFactorAuth');
const { logLogin, logLogout } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { isValidPassword } = require('../utils/validators');

/**
 * @route POST /api/auth/login
 * @desc Login with username and password, sends OTP to email
 * @access Public
 */
router.post('/login', logLogin, asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: 'Username and password are required'
        });
    }

    const result = await login(username, password);

    res.json({
        success: true,
        message: 'OTP sent to your email',
        data: result
    });
}));

/**
 * @route POST /api/auth/verify-otp
 * @desc Verify OTP and get JWT token
 * @access Public
 */
router.post('/verify-otp', verifyEmailOTP, asyncHandler(async (req, res) => {
    const { username, otp } = req.body;

    const result = await verifyOTP(username, otp);

    res.json({
        success: true,
        message: 'Login successful',
        data: result
    });
}));

/**
 * @route POST /api/auth/resend-otp
 * @desc Resend OTP code
 * @access Public
 */
router.post('/resend-otp', asyncHandler(async (req, res) => {
    const { username } = req.body;

    if (!username) {
        return res.status(400).json({
            success: false,
            message: 'Username is required'
        });
    }

    const result = await resendOTP(username);

    res.json({
        success: true,
        ...result
    });
}));

/**
 * @route POST /api/auth/change-password
 * @desc Change user password
 * @access Private
 */
router.post('/change-password', authenticate, asyncHandler(async (req, res) => {
    const { old_password, new_password } = req.body;

    if (!old_password || !new_password) {
        return res.status(400).json({
            success: false,
            message: 'Old password and new password are required'
        });
    }

    if (!isValidPassword(new_password)) {
        return res.status(400).json({
            success: false,
            message: 'Password must be at least 8 characters with uppercase, lowercase, number, and special character'
        });
    }

    await changePassword(req.user.user_id, old_password, new_password);

    res.json({
        success: true,
        message: 'Password changed successfully'
    });
}));

/**
 * @route POST /api/auth/confirm-unit
 * @desc Confirm unit assignment (Station Commanders only)
 * @access Private
 */
router.post('/confirm-unit', authenticate, asyncHandler(async (req, res) => {
    const { unit_id } = req.body;

    if (!unit_id) {
        return res.status(400).json({
            success: false,
            message: 'Unit ID is required'
        });
    }

    await confirmUnit(req.user.user_id, unit_id);

    res.json({
        success: true,
        message: 'Unit confirmed successfully'
    });
}));

/**
 * @route POST /api/auth/logout
 * @desc Logout user
 * @access Private
 */
router.post('/logout', authenticate, logLogout, (req, res) => {
    res.json({
        success: true,
        message: 'Logged out successfully'
    });
});

module.exports = router;
