const express = require('express');
const router = express.Router();
const LossReport = require('../models/LossReport');
const DestructionRequest = require('../models/DestructionRequest');
const ProcurementRequest = require('../models/ProcurementRequest');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireRole, ROLES } = require('../middleware/authorization');
const { logCreate, logDelete, logLossReport, exportLegalChainOfCustody, verifyChainIntegrity } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');
const { generateAnalyticalReport } = require('../services/reportGeneration.service');
const {
    processLossReport,
    processDestructionRequest,
    processProcurementRequest
} = require('../services/workflow.service');

const ensureDeleteAccess = (req, reportRow, reportLabel) => {
    if (!reportRow) {
        return {
            allowed: false,
            status: 404,
            payload: { success: false, message: `${reportLabel} not found` }
        };
    }

    if (reportRow.status === 'pending') {
        return {
            allowed: false,
            status: 403,
            payload: {
                success: false,
                message: 'Pending lifecycle requests cannot be deleted. Please approve or reject them first.'
            }
        };
    }

    if (req.user.role === ROLES.STATION_COMMANDER && req.user.unit_id !== reportRow.unit_id) {
        return {
            allowed: false,
            status: 403,
            payload: {
                success: false,
                message: 'Access denied. You can only delete reports from your assigned unit.'
            }
        };
    }

    return { allowed: true };
};

/**
 * Reports Routes
 * 
 * Includes:
 * - Report Generation (NEW)
 * - Loss Reports
 * - Destruction Requests
 * - Procurement Requests
 * - Legal Chain-of-Custody Export
 * - Audit Trail Reports
 */

// ============================================
// REPORT GENERATION ENDPOINT
// Unified endpoint for all role-based reports
// ============================================

router.get('/generate', authenticate, asyncHandler(async (req, res) => {
    const generatedReport = await generateAnalyticalReport(req.query, req.user.role);

    if (generatedReport.error) {
        return res
            .status(generatedReport.error.status)
            .json(generatedReport.error.payload);
    }

    res.json({ success: true, data: generatedReport.data, meta: generatedReport.meta });
}));

// ============================================
// LEGAL CHAIN-OF-CUSTODY REPORTS
// For forensic and legal proceedings
// ============================================

/**
 * Export legal chain-of-custody report for a firearm
 * Access: HQ Commander, Investigator, Admin
 * 
 * This endpoint generates a tamper-evident chain-of-custody report
 * suitable for legal proceedings and investigations.
 */
router.get('/chain-of-custody/:firearm_id', 
    authenticate, 
    requireRole([ROLES.HQ_COMMANDER, ROLES.INVESTIGATOR, ROLES.ADMIN]),
    asyncHandler(async (req, res) => {
        const { firearm_id } = req.params;
        const { start_date, end_date, format } = req.query;

        // Get firearm details first
        const firearmResult = await query(
            `SELECT f.*, u.unit_name as assigned_unit_name
             FROM firearms f
             LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
             WHERE f.firearm_id = $1`,
            [firearm_id]
        );

        if (firearmResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Firearm not found'
            });
        }

        const firearm = firearmResult.rows[0];

        // Get chain of custody records
        const chainRecords = await exportLegalChainOfCustody(
            firearm_id,
            start_date ? new Date(start_date) : null,
            end_date ? new Date(end_date) : null
        );

        // Verify chain integrity
        const integrityCheck = await verifyChainIntegrity(firearm_id);

        // Log this access
        const logId = `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).substring(2, 5).toUpperCase()}`;
        await query(`
            INSERT INTO audit_logs (log_id, user_id, action_type, table_name, record_id, reason, ip_address, user_agent, is_chain_of_custody_event)
            VALUES ($1, $2, 'CHAIN_OF_CUSTODY_EXPORT', 'chain_of_custody_audit', $3, $4, $5, $6, true)
        `, [
            logId,
            req.user.user_id,
            firearm_id,
            req.query.reason || 'Legal chain-of-custody export',
            req.ip,
            req.get('user-agent')
        ]);

        res.json({
            success: true,
            data: {
                firearm: {
                    firearm_id: firearm.firearm_id,
                    serial_number: firearm.serial_number,
                    manufacturer: firearm.manufacturer,
                    model: firearm.model,
                    current_status: firearm.current_status,
                    assigned_unit: firearm.assigned_unit_name
                },
                integrity: {
                    is_valid: integrityCheck.is_valid,
                    total_events: integrityCheck.total_events,
                    first_event: integrityCheck.first_event_timestamp,
                    last_event: integrityCheck.last_event_timestamp,
                    verification_timestamp: integrityCheck.verification_timestamp,
                    broken_at_sequence: integrityCheck.broken_at_sequence
                },
                chain_of_custody: chainRecords,
                export_metadata: {
                    exported_by: req.user.username,
                    exported_at: new Date().toISOString(),
                    filter_start_date: start_date || null,
                    filter_end_date: end_date || null,
                    record_count: chainRecords.length
                }
            }
        });
    })
);

/**
 * Verify chain-of-custody integrity for a firearm
 * Access: HQ Commander, Investigator, Admin
 */
router.get('/chain-of-custody/:firearm_id/verify', 
    authenticate, 
    requireRole([ROLES.HQ_COMMANDER, ROLES.INVESTIGATOR, ROLES.ADMIN]),
    asyncHandler(async (req, res) => {
        const { firearm_id } = req.params;

        const integrityCheck = await verifyChainIntegrity(firearm_id);

        res.json({
            success: true,
            data: {
                firearm_id,
                ...integrityCheck,
                message: integrityCheck.is_valid 
                    ? 'Chain of custody integrity verified - no tampering detected'
                    : `Chain integrity broken at sequence ${integrityCheck.broken_at_sequence}`
            }
        });
    })
);

/**
 * Get audit trail for a specific entity
 * Access: Admin, HQ Commander
 */
router.get('/audit-trail/:entity_type/:entity_id', 
    authenticate, 
    requireRole([ROLES.ADMIN, ROLES.HQ_COMMANDER]),
    asyncHandler(async (req, res) => {
        const { entity_type, entity_id } = req.params;
        const { limit = 100, offset = 0 } = req.query;

        const auditRecords = await query(`
            SELECT 
                al.log_id,
                al.action_type,
                al.created_at as timestamp,
                al.reason,
                al.actor_role,
                al.actor_unit_name,
                al.old_values,
                al.new_values,
                al.ip_address,
                al.success,
                u.username as actor_username,
                u.full_name as actor_full_name
            FROM audit_logs al
            LEFT JOIN users u ON al.user_id = u.user_id
            WHERE al.subject_type = $1 AND al.subject_id = $2
            ORDER BY al.created_at DESC
            LIMIT $3 OFFSET $4
        `, [entity_type, entity_id, limit, offset]);

        res.json({
            success: true,
            data: auditRecords.rows
        });
    })
);

/**
 * Get system-wide audit summary
 * Access: Admin only
 */
router.get('/audit-summary', 
    authenticate, 
    requireRole([ROLES.ADMIN]),
    asyncHandler(async (req, res) => {
        const { days = 30 } = req.query;

        const summary = await query(`
            SELECT 
                action_type,
                COUNT(*) as count,
                COUNT(*) FILTER (WHERE success = true) as successful,
                COUNT(*) FILTER (WHERE success = false) as failed,
                COUNT(*) FILTER (WHERE is_chain_of_custody_event = true) as chain_of_custody_events
            FROM audit_logs
            WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 day' * $1
            GROUP BY action_type
            ORDER BY count DESC
        `, [days]);

        const totalEvents = await query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE is_chain_of_custody_event = true) as chain_of_custody,
                COUNT(DISTINCT user_id) as unique_actors
            FROM audit_logs
            WHERE created_at > CURRENT_TIMESTAMP - INTERVAL '1 day' * $1
        `, [days]);

        res.json({
            success: true,
            data: {
                period_days: parseInt(days),
                totals: totalEvents.rows[0],
                by_action_type: summary.rows
            }
        });
    })
);

// ============================================
// LOSS REPORTS
// ============================================

router.get('/loss', authenticate, asyncHandler(async (req, res) => {
    const reports = await LossReport.findAll(req.query);
    res.json({ success: true, data: reports });
}));

router.post('/loss', authenticate, requireCommander, logLossReport, asyncHandler(async (req, res) => {
    // Loss reports are chain-of-custody events
    const report = await LossReport.create({ ...req.body, reported_by: req.user.user_id, unit_id: req.user.unit_id });
    res.status(201).json({ success: true, data: report });
}));

// Update loss report status
router.patch('/loss/:id/status', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected', 'under_investigation'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const report = status === 'under_investigation'
        ? await LossReport.update(req.params.id, {
            status,
            review_notes,
            reviewed_by: req.user.user_id,
            review_date: new Date().toISOString()
        })
        : await processLossReport(req.params.id, {
            status,
            review_notes,
            reviewed_by: req.user.user_id
        });
    if (!report) return res.status(404).json({ success: false, message: 'Loss report not found' });
    res.json({ success: true, data: report });
}));

router.delete('/loss/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const reportResult = await query(
        `SELECT loss_id, unit_id, status FROM loss_reports WHERE loss_id = $1`,
        [req.params.id]
    );

    const access = ensureDeleteAccess(req, reportResult.rows[0], 'Loss report');
    if (!access.allowed) {
        return res.status(access.status).json(access.payload);
    }

    const deleteResult = await query(
        `DELETE FROM loss_reports WHERE loss_id = $1 RETURNING loss_id`,
        [req.params.id]
    );

    res.json({
        success: true,
        message: 'Loss report deleted successfully',
        data: {
            id: deleteResult.rows[0].loss_id,
            type: 'loss'
        }
    });
}));

// ============================================
// DESTRUCTION REQUESTS
// ============================================
router.get('/destruction', authenticate, asyncHandler(async (req, res) => {
    const requests = await DestructionRequest.findAll(req.query);
    res.json({ success: true, data: requests });
}));

router.post('/destruction', authenticate, requireCommander, logCreate, asyncHandler(async (req, res) => {
    const request = await DestructionRequest.create({ ...req.body, requested_by: req.user.user_id, unit_id: req.user.unit_id });
    res.status(201).json({ success: true, data: request });
}));

// Update destruction request status
router.patch('/destruction/:id/status', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const request = await processDestructionRequest(req.params.id, {
        status,
        review_notes,
        reviewed_by: req.user.user_id
    });
    if (!request) return res.status(404).json({ success: false, message: 'Destruction request not found' });
    res.json({ success: true, data: request });
}));

router.delete('/destruction/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const requestResult = await query(
        `SELECT destruction_id, unit_id, status FROM destruction_requests WHERE destruction_id = $1`,
        [req.params.id]
    );

    const access = ensureDeleteAccess(req, requestResult.rows[0], 'Destruction request');
    if (!access.allowed) {
        return res.status(access.status).json(access.payload);
    }

    const deleteResult = await query(
        `DELETE FROM destruction_requests WHERE destruction_id = $1 RETURNING destruction_id`,
        [req.params.id]
    );

    res.json({
        success: true,
        message: 'Destruction request deleted successfully',
        data: {
            id: deleteResult.rows[0].destruction_id,
            type: 'destruction'
        }
    });
}));

// Procurement Requests
router.get('/procurement', authenticate, asyncHandler(async (req, res) => {
    const requests = await ProcurementRequest.findAll(req.query);
    res.json({ success: true, data: requests });
}));

router.post('/procurement', authenticate, requireCommander, logCreate, asyncHandler(async (req, res) => {
    const request = await ProcurementRequest.create({ ...req.body, requested_by: req.user.user_id, unit_id: req.user.unit_id });
    res.status(201).json({ success: true, data: request });
}));

// Update procurement request status
router.patch('/procurement/:id/status', authenticate, requireRole([ROLES.HQ_COMMANDER, ROLES.ADMIN]), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const request = await processProcurementRequest(req.params.id, {
        status,
        review_notes,
        reviewed_by: req.user.user_id
    });
    if (!request) return res.status(404).json({ success: false, message: 'Procurement request not found' });
    res.json({ success: true, data: request });
}));

router.delete('/procurement/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const requestResult = await query(
        `SELECT procurement_id, unit_id, status FROM procurement_requests WHERE procurement_id = $1`,
        [req.params.id]
    );

    const access = ensureDeleteAccess(req, requestResult.rows[0], 'Procurement request');
    if (!access.allowed) {
        return res.status(access.status).json(access.payload);
    }

    const deleteResult = await query(
        `DELETE FROM procurement_requests WHERE procurement_id = $1 RETURNING procurement_id`,
        [req.params.id]
    );

    res.json({
        success: true,
        message: 'Procurement request deleted successfully',
        data: {
            id: deleteResult.rows[0].procurement_id,
            type: 'procurement'
        }
    });
}));

module.exports = router;
