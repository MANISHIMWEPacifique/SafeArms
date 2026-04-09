const express = require('express');
const router = express.Router();
const LossReport = require('../models/LossReport');
const DestructionRequest = require('../models/DestructionRequest');
const ProcurementRequest = require('../models/ProcurementRequest');
const { authenticate } = require('../middleware/authentication');
const { requireCommander, requireRole, PERMISSIONS, ROLES } = require('../middleware/authorization');
const { logCreate, logDelete, logLossReport, exportLegalChainOfCustody, verifyChainIntegrity } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

const ensureDeleteAccess = (req, reportRow, reportLabel) => {
    if (!reportRow) {
        return {
            allowed: false,
            status: 404,
            payload: { success: false, message: `${reportLabel} not found` }
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
    const { type, start_date, end_date, unit_id, serial_number, case_ref, user_id, role: filterRole } = req.query;
    const userRole = req.user.role;

    // Build date filter
    let dateFilter = '';
    const dateParams = [];
    let paramIdx = 1;

    if (start_date) {
        dateFilter += ` AND created_at >= $${paramIdx}`;
        dateParams.push(new Date(start_date));
        paramIdx++;
    }
    if (end_date) {
        const endDate = new Date(end_date);
        endDate.setHours(23, 59, 59, 999);
        dateFilter += ` AND created_at <= $${paramIdx}`;
        dateParams.push(endDate);
        paramIdx++;
    }

    let data = {};

    switch (type) {
        // ===== FIREARM HISTORY =====
        case 'firearm_history': {
            let firearmFilter = 'WHERE 1=1';
            const fParams = [...dateParams];
            let fIdx = paramIdx;

            if (serial_number) {
                firearmFilter += ` AND f.serial_number ILIKE $${fIdx}`;
                fParams.push(`%${serial_number}%`);
                fIdx++;
            }
            if (unit_id) {
                firearmFilter += ` AND f.assigned_unit_id = $${fIdx}`;
                fParams.push(unit_id);
                fIdx++;
            }

            const firearms = await query(`
                SELECT f.firearm_id, f.serial_number, f.firearm_type, f.caliber,
                       f.manufacturer, f.model, f.acquisition_date, f.current_status,
                       u.unit_name
                FROM firearms f
                LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
                ${(firearmFilter + dateFilter).replace(/created_at/g, 'f.created_at')}
                ORDER BY f.created_at DESC
                LIMIT 100
            `, fParams);

            // Get custody records for those firearms
            const firearmIds = firearms.rows.map(f => f.firearm_id);
            let custodyRecords = [];
            let anomalies = [];
            let ballisticProfile = null;

            if (firearmIds.length > 0) {
                const custodyResult = await query(`
                    SELECT cr.custody_id, cr.firearm_id, cr.issued_at, cr.returned_at,
                           cr.custody_type, f.serial_number,
                           CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as custody_status,
                           o.full_name as officer_name, o.officer_id,
                           u.unit_name,
                           CASE WHEN cr.returned_at IS NOT NULL 
                                THEN EXTRACT(DAY FROM (cr.returned_at - cr.issued_at)) || ' days'
                                ELSE 'Active'
                           END as duration
                    FROM custody_records cr
                    LEFT JOIN firearms f ON cr.firearm_id = f.firearm_id
                    LEFT JOIN officers o ON cr.officer_id = o.officer_id
                    LEFT JOIN units u ON cr.unit_id = u.unit_id
                    WHERE cr.firearm_id = ANY($1)
                    ORDER BY cr.issued_at ASC
                    LIMIT 500
                `, [firearmIds]);
                custodyRecords = custodyResult.rows;

                const anomalyResult = await query(`
                    SELECT anomaly_id, severity, status
                    FROM anomalies
                    WHERE firearm_id = ANY($1)
                    ORDER BY detected_at DESC
                `, [firearmIds]);
                anomalies = anomalyResult.rows;

                // Get ballistic profile for first firearm (for investigator detail view)
                if (firearmIds.length === 1 || serial_number) {
                    const bpResult = await query(`
                        SELECT bp.ballistic_id, bp.rifling_characteristics, bp.firing_pin_impression,
                               bp.ejector_marks, bp.extractor_marks, bp.chamber_marks,
                               bp.test_date, bp.test_location, bp.forensic_lab,
                               bp.is_locked, bp.registration_hash,
                               bp.created_at
                        FROM ballistic_profiles bp
                        WHERE bp.firearm_id = $1
                        LIMIT 1
                    `, [firearmIds[0]]);
                    if (bpResult.rows.length > 0) {
                        ballisticProfile = bpResult.rows[0];
                    }
                }
            }

            data = {
                firearms: firearms.rows,
                custody_records: custodyRecords,
                anomalies: anomalies,
                ballistic_profile: ballisticProfile,
            };
            break;
        }

        // ===== BALLISTIC REFERENCE SUMMARY =====
        case 'ballistic_summary': {
            let bpFilter = 'WHERE 1=1';
            const bParams = [...dateParams];
            let bIdx = paramIdx;

            if (serial_number) {
                bpFilter += ` AND f.serial_number ILIKE $${bIdx}`;
                bParams.push(`%${serial_number}%`);
                bIdx++;
            }
            if (unit_id) {
                bpFilter += ` AND f.assigned_unit_id = $${bIdx}`;
                bParams.push(unit_id);
                bIdx++;
            }

            const profiles = await query(`
                SELECT bp.ballistic_id, bp.firearm_id, bp.rifling_characteristics, bp.firing_pin_impression,
                       bp.ejector_marks, bp.extractor_marks, bp.chamber_marks,
                       bp.test_date, bp.test_location, bp.forensic_lab,
                       bp.is_locked, bp.registration_hash,
                       bp.created_at,
                       f.serial_number, f.firearm_type, f.caliber
                FROM ballistic_profiles bp
                LEFT JOIN firearms f ON bp.firearm_id = f.firearm_id
                ${(bpFilter + dateFilter).replace(/created_at/g, 'bp.created_at')}
                ORDER BY bp.created_at DESC
                LIMIT 100
            `, bParams);

            const firearmIds = profiles.rows.map(p => p.firearm_id).filter(Boolean);
            let recent_custody_logs = [];

            if (firearmIds.length > 0) {
                const custodyResult = await query(`
                    SELECT cr.custody_id, cr.firearm_id, cr.issued_at, cr.returned_at,
                           cr.custody_type, o.full_name as officer_name,
                           u.unit_name
                    FROM custody_records cr
                    LEFT JOIN officers o ON cr.officer_id = o.officer_id
                    LEFT JOIN units u ON cr.unit_id = u.unit_id
                    WHERE cr.firearm_id = ANY($1)
                    ORDER BY cr.issued_at DESC
                    LIMIT 200
                `, [firearmIds]);
                recent_custody_logs = custodyResult.rows;
            }

            data = { 
                profiles: profiles.rows,
                recent_custody_logs: recent_custody_logs
            };
            break;
        }

        // ===== ANOMALY SUMMARY =====
        case 'anomaly_summary': {
            if (userRole === 'admin') {
                return res.status(403).json({
                    success: false,
                    message: 'Access denied. Admin role cannot access anomaly summary reports.'
                });
            }

            let aFilter = 'WHERE 1=1';
            const aParams = [...dateParams];
            let aIdx = paramIdx;

            if (unit_id) {
                aFilter += ` AND a.unit_id = $${aIdx}`;
                aParams.push(unit_id);
                aIdx++;
            }

            const anomalies = await query(`
                SELECT a.anomaly_id, a.severity, a.status,
                       a.detected_at, a.anomaly_type,
                       f.serial_number,
                       u.unit_name
                FROM anomalies a
                LEFT JOIN firearms f ON a.firearm_id = f.firearm_id
                LEFT JOIN units u ON a.unit_id = u.unit_id
                ${(aFilter + dateFilter).replace(/created_at/g, 'a.detected_at')}
                ORDER BY a.detected_at DESC
                LIMIT 100
            `, aParams);

            // Summary counts
            const total = anomalies.rows.length;
            const high = anomalies.rows.filter(a => a.severity?.toLowerCase() === 'high' || a.severity?.toLowerCase() === 'critical').length;
            const medium = anomalies.rows.filter(a => a.severity?.toLowerCase() === 'medium').length;
            const low = anomalies.rows.filter(a => a.severity?.toLowerCase() === 'low').length;
            const reviewed = anomalies.rows.filter(a => a.status?.toLowerCase() === 'reviewed' || a.status?.toLowerCase() === 'resolved').length;
            const pending = anomalies.rows.filter(a => a.status?.toLowerCase() === 'pending' || a.status?.toLowerCase() === 'open').length;

            data = {
                anomalies: anomalies.rows,
                summary: { total, high, medium, low, reviewed, pending }
            };
            break;
        }

        // ===== USER ACTIVITY (Admin only) =====
        case 'user_activity': {
            if (userRole !== 'admin') {
                return res.status(403).json({ success: false, message: 'Admin access required' });
            }

            let uaFilter = 'WHERE al.success = true';
            const uaParams = [...dateParams];
            let uaIdx = paramIdx;

            if (user_id) {
                uaFilter += ` AND al.user_id = $${uaIdx}`;
                uaParams.push(user_id);
                uaIdx++;
            }
            if (filterRole) {
                uaFilter += ` AND u.role = $${uaIdx}`;
                uaParams.push(filterRole);
                uaIdx++;
            }

            const activities = await query(`
                SELECT al.log_id, al.action_type, al.table_name,
                       al.record_id, al.created_at,
                       u.username, u.role, u.full_name
                FROM audit_logs al
                LEFT JOIN users u ON al.user_id = u.user_id
                ${(uaFilter + dateFilter).replace(/created_at/g, 'al.created_at')}
                ORDER BY al.created_at DESC
                LIMIT 200
            `, uaParams);

            data = { activities: activities.rows };
            break;
        }

        // ===== SYSTEM AUDIT LOG (Admin only) =====
        case 'audit_log': {
            if (userRole !== 'admin') {
                return res.status(403).json({ success: false, message: 'Admin access required' });
            }

            let alFilter = 'WHERE 1=1';
            const alParams = [...dateParams];
            let alIdx = paramIdx;

            if (user_id) {
                alFilter += ` AND al.user_id = $${alIdx}`;
                alParams.push(user_id);
                alIdx++;
            }
            if (filterRole) {
                alFilter += ` AND u.role = $${alIdx}`;
                alParams.push(filterRole);
                alIdx++;
            }

            const logs = await query(`
                SELECT al.log_id, al.action_type, al.table_name,
                       al.record_id, al.created_at, al.success,
                       al.ip_address,
                       u.username, u.full_name as actor_name, u.role
                FROM audit_logs al
                LEFT JOIN users u ON al.user_id = u.user_id
                ${(alFilter + dateFilter).replace(/created_at/g, 'al.created_at')}
                ORDER BY al.created_at DESC
                LIMIT 200
            `, alParams);

            data = { audit_logs: logs.rows };
            break;
        }

        default:
            return res.status(400).json({ success: false, message: `Unknown report type: ${type}` });
    }

    res.json({ success: true, data });
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
        await query(`
            INSERT INTO audit_logs (user_id, action_type, table_name, record_id, reason, ip_address, user_agent, is_chain_of_custody_event)
            VALUES ($1, 'CHAIN_OF_CUSTODY_EXPORT', 'chain_of_custody_audit', $2, $3, $4, $5, true)
        `, [
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
router.patch('/loss/:id/status', authenticate, requireRole(['hq_firearm_commander', 'admin']), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected', 'under_investigation'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const report = await LossReport.update(req.params.id, { 
        status, 
        review_notes,
        reviewed_by: req.user.user_id,
        review_date: new Date().toISOString()
    });
    if (!report) return res.status(404).json({ success: false, message: 'Loss report not found' });
    res.json({ success: true, data: report });
}));

router.delete('/loss/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const reportResult = await query(
        `SELECT loss_id, unit_id FROM loss_reports WHERE loss_id = $1`,
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
router.patch('/destruction/:id/status', authenticate, requireRole(['hq_firearm_commander', 'admin']), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const request = await DestructionRequest.update(req.params.id, { 
        status, 
        review_notes,
        reviewed_by: req.user.user_id,
        review_date: new Date().toISOString()
    });
    if (!request) return res.status(404).json({ success: false, message: 'Destruction request not found' });
    res.json({ success: true, data: request });
}));

router.delete('/destruction/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const requestResult = await query(
        `SELECT destruction_id, unit_id FROM destruction_requests WHERE destruction_id = $1`,
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
router.patch('/procurement/:id/status', authenticate, requireRole(['hq_firearm_commander', 'admin']), asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    if (!['approved', 'rejected'].includes(status)) {
        return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const request = await ProcurementRequest.update(req.params.id, { 
        status, 
        review_notes,
        reviewed_by: req.user.user_id,
        review_date: new Date().toISOString()
    });
    if (!request) return res.status(404).json({ success: false, message: 'Procurement request not found' });
    res.json({ success: true, data: request });
}));

router.delete('/procurement/:id', authenticate, requireRole([ROLES.STATION_COMMANDER, ROLES.HQ_COMMANDER, ROLES.ADMIN]), logDelete, asyncHandler(async (req, res) => {
    const requestResult = await query(
        `SELECT procurement_id, unit_id FROM procurement_requests WHERE procurement_id = $1`,
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
