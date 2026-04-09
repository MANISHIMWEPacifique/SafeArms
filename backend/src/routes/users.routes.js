const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const User = require('../models/User');
const bcrypt = require('bcrypt');
const { authenticate } = require('../middleware/authentication');
const { requireAdmin, requireAdminOrHQ } = require('../middleware/authorization');
const { logCreate, logUpdate, logDelete } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { isValidEmail, isValidPassword, isValidRole, isValidEntityId } = require('../utils/validators');
const { BCRYPT_ROUNDS } = require('../config/auth');

const userUploadsDir = path.join(__dirname, '../../uploads/users');
if (!fs.existsSync(userUploadsDir)) {
    fs.mkdirSync(userUploadsDir, { recursive: true });
}

const profileUpload = multer({
    storage: multer.diskStorage({
        destination: (req, file, cb) => cb(null, userUploadsDir),
        filename: (req, file, cb) => {
            const ext = path.extname(file.originalname || '').toLowerCase() || '.jpg';
            const safeId = String(req.params.id || 'user').replace(/[^a-zA-Z0-9-_]/g, '');
            cb(null, `${safeId}-${Date.now()}${ext}`);
        }
    }),
    limits: {
        fileSize: 3 * 1024 * 1024
    },
    fileFilter: (req, file, cb) => {
        const ext = path.extname(file.originalname || '').toLowerCase();
        const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
        if (!allowedExtensions.includes(ext)) {
            return cb(new Error('Invalid file type. Allowed formats: JPG, PNG, WEBP'));
        }
        cb(null, true);
    }
});

const handleProfileUpload = (req, res, next) => {
    profileUpload.single('photo')(req, res, (err) => {
        if (!err) {
            return next();
        }

        if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                success: false,
                message: 'Profile photo is too large. Maximum allowed size is 3MB'
            });
        }

        return res.status(400).json({
            success: false,
            message: err.message || 'Invalid upload request'
        });
    });
};

router.get('/', authenticate, requireAdminOrHQ, asyncHandler(async (req, res) => {
    const { role, unit_id, is_active, limit, offset } = req.query;
    const users = await User.findAll({ role, unit_id, is_active, limit, offset });
    res.json({ success: true, data: users });
}));

// Get user statistics - must be before /:id route
router.get('/stats', authenticate, requireAdminOrHQ, asyncHandler(async (req, res) => {
    const stats = await User.getStats();
    res.json({ 
        success: true, 
        data: {
            total: parseInt(stats.total_users) || 0,
            active: parseInt(stats.active_users) || 0,
            inactive: (parseInt(stats.total_users) || 0) - (parseInt(stats.active_users) || 0),
            admins: parseInt(stats.admins) || 0,
            hqCommanders: parseInt(stats.hq_commanders) || 0,
            stationCommanders: parseInt(stats.station_commanders) || 0,
            investigators: parseInt(stats.investigators) || 0,
            byRole: {
                admin: parseInt(stats.admins) || 0,
                hq_firearm_commander: parseInt(stats.hq_commanders) || 0,
                station_commander: parseInt(stats.station_commanders) || 0,
                investigator: parseInt(stats.investigators) || 0
            }
        }
    });
}));

router.get('/:id', authenticate, asyncHandler(async (req, res) => {
    const user = await User.findById(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, data: user });
}));

router.post('/', authenticate, requireAdmin, logCreate, asyncHandler(async (req, res) => {
    const { username, password, full_name, email, phone_number, role, unit_id } = req.body;

    if (!username || !password || !full_name || !email || !role) {
        return res.status(400).json({ success: false, message: 'Missing required fields' });
    }

    if (!isValidEmail(email)) {
        return res.status(400).json({ success: false, message: 'Invalid email format' });
    }

    if (!isValidPassword(password)) {
        return res.status(400).json({ success: false, message: 'Password must be at least 8 characters with uppercase, lowercase, number, and special character' });
    }

    if (!isValidRole(role)) {
        return res.status(400).json({ success: false, message: 'Invalid role' });
    }

    if (unit_id && !isValidEntityId(unit_id, 'UNIT')) {
        return res.status(400).json({
            success: false,
            message: 'Invalid unit_id format. Expected format: UNIT-XXX'
        });
    }

    const password_hash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    const user = await User.create({ ...req.body, password_hash, created_by: req.user.user_id });

    res.status(201).json({ success: true, data: user });
}));

router.put('/:id', authenticate, requireAdminOrHQ, logUpdate, asyncHandler(async (req, res) => {
    // Prevent direct password_hash modification - use change-password endpoint instead
    const { password_hash, password, otp_code, otp_expires_at, otp_verified, ...safeUpdates } = req.body;
    
    const user = await User.update(req.params.id, safeUpdates);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, data: user });
}));

router.post('/:id/photo', authenticate, requireAdmin, logUpdate, handleProfileUpload, asyncHandler(async (req, res) => {
    const existingUser = await User.findById(req.params.id);

    if (!existingUser) {
        if (req.file) {
            fs.unlink(req.file.path, () => { });
        }
        return res.status(404).json({ success: false, message: 'User not found' });
    }

    if (!req.file) {
        return res.status(400).json({ success: false, message: 'Photo file is required' });
    }

    const relativePhotoPath = `/uploads/users/${req.file.filename}`;
    const updatedUser = await User.update(req.params.id, {
        profile_photo_url: relativePhotoPath
    });

    if (existingUser.profile_photo_url) {
        const oldFileName = path.basename(existingUser.profile_photo_url);
        const oldFilePath = path.join(userUploadsDir, oldFileName);
        if (fs.existsSync(oldFilePath)) {
            fs.unlink(oldFilePath, () => { });
        }
    }

    res.json({
        success: true,
        message: 'Profile photo uploaded successfully',
        data: updatedUser
    });
}));

// Admin reset user password - sets new password and forces password change on next login
router.post('/:id/reset-password', authenticate, requireAdmin, logUpdate, asyncHandler(async (req, res) => {
    const { new_password } = req.body;

    if (!new_password) {
        return res.status(400).json({ success: false, message: 'New password is required' });
    }

    if (!isValidPassword(new_password)) {
        return res.status(400).json({ 
            success: false, 
            message: 'Password must be at least 8 characters with uppercase, lowercase, number, and special character' 
        });
    }

    const password_hash = await bcrypt.hash(new_password, BCRYPT_ROUNDS);
    const user = await User.update(req.params.id, { 
        password_hash, 
        must_change_password: true 
    });
    
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, message: 'Password reset successfully. User will be required to change password on next login.' });
}));

router.delete('/:id', authenticate, requireAdmin, logDelete, asyncHandler(async (req, res) => {
    const existingUser = await User.findById(req.params.id);
    if (!existingUser) return res.status(404).json({ success: false, message: 'User not found' });

    const user = await User.delete(req.params.id);
    if (!user) return res.status(404).json({ success: false, message: 'User not found' });

    if (existingUser.profile_photo_url) {
        const oldFileName = path.basename(existingUser.profile_photo_url);
        const oldFilePath = path.join(userUploadsDir, oldFileName);
        if (fs.existsSync(oldFilePath)) {
            fs.unlink(oldFilePath, () => { });
        }
    }

    res.json({ success: true, message: 'User deleted successfully' });
}));

module.exports = router;
