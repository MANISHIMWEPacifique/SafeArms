const express = require('express');
const router = express.Router();
const { login, verifyOTP, resendOTP, changePassword, confirmUnit } = require('../services/auth.service');
const { authenticate } = require('../middleware/authentication');
const { verifyEmailOTP } = require('../middleware/twoFactorAuth');
const { logLogin, logLogout } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { isValidPassword } = require('../utils/validators');
const { getSystemSettings } = require('../services/systemSettings.service');

/**
 * Simple in-memory rate limiter for auth endpoints
 * Prevents brute-force attacks on login/OTP endpoints
 */
const rateLimitStore = new Map();
const DEFAULT_AUTH_RATE_LIMIT_WINDOW_MINUTES = 15;
const DEFAULT_AUTH_RATE_LIMIT_MAX_PER_IP = 60;
const DEFAULT_AUTH_RATE_LIMIT_MAX_PER_ACCOUNT = 10;
const AUTH_RATE_LIMIT_SETTINGS_REFRESH_MS = 30000;

const authRateLimitCache = {
    value: {
        windowMs: DEFAULT_AUTH_RATE_LIMIT_WINDOW_MINUTES * 60 * 1000,
        maxPerIp: DEFAULT_AUTH_RATE_LIMIT_MAX_PER_IP,
        maxPerAccount: DEFAULT_AUTH_RATE_LIMIT_MAX_PER_ACCOUNT
    },
    refreshedAt: 0
};

const parsePositiveInt = (value, fallback) => {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const resolveAuthRateLimitConfig = async () => {
    if (Date.now() - authRateLimitCache.refreshedAt < AUTH_RATE_LIMIT_SETTINGS_REFRESH_MS) {
        return authRateLimitCache.value;
    }

    try {
        const settings = await getSystemSettings([
            'auth_rate_limit_window_minutes',
            'auth_rate_limit_max_per_ip',
            'auth_rate_limit_max_per_account'
        ]);

        const windowMinutes = parsePositiveInt(
            settings.auth_rate_limit_window_minutes,
            DEFAULT_AUTH_RATE_LIMIT_WINDOW_MINUTES
        );

        authRateLimitCache.value = {
            windowMs: windowMinutes * 60 * 1000,
            maxPerIp: parsePositiveInt(
                settings.auth_rate_limit_max_per_ip,
                DEFAULT_AUTH_RATE_LIMIT_MAX_PER_IP
            ),
            maxPerAccount: parsePositiveInt(
                settings.auth_rate_limit_max_per_account,
                DEFAULT_AUTH_RATE_LIMIT_MAX_PER_ACCOUNT
            )
        };
        authRateLimitCache.refreshedAt = Date.now();
    } catch (_) {
        // Keep defaults/cache on transient settings read failures.
        authRateLimitCache.refreshedAt = Date.now();
    }

    return authRateLimitCache.value;
};

const sanitizeRateLimitToken = (value, fallback = 'anonymous') => {
    if (typeof value !== 'string') {
        return fallback;
    }

    const trimmed = value.trim().toLowerCase();
    if (!trimmed) {
        return fallback;
    }

    return trimmed;
};

const registerAttempt = (key, now, maxAttempts, windowMs) => {
    const record = rateLimitStore.get(key);

    if (record && now - record.start < windowMs) {
        record.count += 1;
        if (record.count > maxAttempts) {
            return {
                limited: true,
                retryAfterSeconds: Math.ceil((windowMs - (now - record.start)) / 1000)
            };
        }

        return { limited: false };
    }

    rateLimitStore.set(key, { start: now, count: 1 });
    return { limited: false };
};

const authRateLimit = async (req, res, next) => {
    try {
        const config = await resolveAuthRateLimitConfig();
        const now = Date.now();
        const ip = sanitizeRateLimitToken(req.ip || req.connection?.remoteAddress, 'unknown_ip');
        const username = sanitizeRateLimitToken(req.body?.username);
        const endpoint = sanitizeRateLimitToken(req.path || req.originalUrl, 'auth');

        const ipLimit = registerAttempt(
            `ip:${endpoint}:${ip}`,
            now,
            config.maxPerIp,
            config.windowMs
        );

        if (ipLimit.limited) {
            return res.status(429).json({
                success: false,
                message: 'Too many attempts from this network. Please try again later.',
                retry_after_seconds: ipLimit.retryAfterSeconds
            });
        }

        const accountLimit = registerAttempt(
            `account:${endpoint}:${username}`,
            now,
            config.maxPerAccount,
            config.windowMs
        );

        if (accountLimit.limited) {
            return res.status(429).json({
                success: false,
                message: 'Too many attempts for this account. Please try again later.',
                retry_after_seconds: accountLimit.retryAfterSeconds
            });
        }

        // Clean up old entries periodically
        if (rateLimitStore.size > 1000) {
            for (const [k, v] of rateLimitStore) {
                if (now - v.start > config.windowMs) rateLimitStore.delete(k);
            }
        }

        next();
    } catch (_) {
        next();
    }
};

/**
 * @route POST /api/auth/login
 * @desc Login with username and password, sends OTP to email
 * @access Public
 */
router.post('/login', authRateLimit, logLogin, asyncHandler(async (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({
            success: false,
            message: 'Username and password are required'
        });
    }

    const result = await login(username, password);

    // Populate req.user so auditLogger can capture user details for LOGIN events
    req.user = result.user || {
        user_id: result.user_id,
        role: result.role,
        unit_id: result.unit_id,
        username: result.username
    };

    res.json({
        success: true,
        message: result.otp_sent === false ? 'Login successful' : 'OTP sent to your email',
        data: result
    });
}));

/**
 * @route POST /api/auth/verify-otp
 * @desc Verify OTP and get JWT token
 * @access Public
 */
router.post('/verify-otp', authRateLimit, verifyEmailOTP, asyncHandler(async (req, res) => {
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
router.post('/resend-otp', authRateLimit, asyncHandler(async (req, res) => {
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
