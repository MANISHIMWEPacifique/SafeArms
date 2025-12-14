const express = require('express');
const router = express.Router();
const { getPendingApprovals, processLossReport, processDestructionRequest, processProcurementRequest } = require('../services/workflow.service');
const { authenticate } = require('../middleware/authentication');
const { requireHQCommander } = require('../middleware/authorization');
const { logApproval } = require('../middleware/auditLogger');
const { asyncHandler } = require('../middleware/errorHandler');
const { query } = require('../config/database');

// ===== STATISTICS =====
router.get('/stats', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const lossQuery = `
        SELECT 
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'approved') as approved,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM loss_reports
    `;
    const destructionQuery = `
        SELECT 
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'approved') as approved,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM destruction_requests
    `;
    const procurementQuery = `
        SELECT 
            COUNT(*) FILTER (WHERE status = 'pending') as pending,
            COUNT(*) FILTER (WHERE status = 'approved') as approved,
            COUNT(*) FILTER (WHERE status = 'rejected') as rejected
        FROM procurement_requests
    `;
    
    const [lossResult, destructionResult, procurementResult] = await Promise.all([
        query(lossQuery),
        query(destructionQuery),
        query(procurementQuery)
    ]);
    
    res.json({
        success: true,
        data: {
            loss_reports: lossResult.rows[0],
            destruction_requests: destructionResult.rows[0],
            procurement_requests: procurementResult.rows[0],
            total_pending: 
                parseInt(lossResult.rows[0].pending || 0) + 
                parseInt(destructionResult.rows[0].pending || 0) + 
                parseInt(procurementResult.rows[0].pending || 0)
        }
    });
}));

// ===== LOSS REPORTS =====
router.get('/loss-reports', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const { priority, unit, status } = req.query;
    
    let sql = `
        SELECT 
            lr.*,
            f.serial_number, f.manufacturer, f.model, f.firearm_type,
            u.unit_name,
            reporter.full_name as reported_by_name,
            reviewer.full_name as reviewed_by_name
        FROM loss_reports lr
        LEFT JOIN firearms f ON lr.firearm_id = f.firearm_id
        LEFT JOIN units u ON lr.unit_id = u.unit_id
        LEFT JOIN users reporter ON lr.reported_by = reporter.user_id
        LEFT JOIN users reviewer ON lr.reviewed_by = reviewer.user_id
        WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;
    
    if (unit && unit !== 'all') {
        sql += ` AND lr.unit_id = $${paramIndex}`;
        params.push(unit);
        paramIndex++;
    }
    
    if (status && status !== 'all') {
        sql += ` AND lr.status = $${paramIndex}`;
        params.push(status);
        paramIndex++;
    } else {
        // Default to pending only
        sql += ` AND lr.status = 'pending'`;
    }
    
    sql += ` ORDER BY lr.created_at DESC`;
    
    const result = await query(sql, params);
    res.json({ success: true, data: result.rows });
}));

router.put('/loss-reports/:id/approve', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { approval_notes, follow_up_actions } = req.body;
    const result = await processLossReport(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'approved',
        review_notes: approval_notes
    });
    res.json({ success: true, data: result, message: 'Loss report approved' });
}));

router.put('/loss-reports/:id/reject', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { rejection_reason, detailed_feedback, required_actions } = req.body;
    const review_notes = `Reason: ${rejection_reason}\nFeedback: ${detailed_feedback}`;
    const result = await processLossReport(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'rejected',
        review_notes
    });
    res.json({ success: true, data: result, message: 'Loss report rejected' });
}));

// ===== DESTRUCTION REQUESTS =====
router.get('/destruction-requests', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const { priority, unit, status } = req.query;
    
    let sql = `
        SELECT 
            dr.*,
            f.serial_number, f.manufacturer, f.model, f.firearm_type,
            u.unit_name,
            requester.full_name as requested_by_name,
            reviewer.full_name as reviewed_by_name
        FROM destruction_requests dr
        LEFT JOIN firearms f ON dr.firearm_id = f.firearm_id
        LEFT JOIN units u ON dr.unit_id = u.unit_id
        LEFT JOIN users requester ON dr.requested_by = requester.user_id
        LEFT JOIN users reviewer ON dr.reviewed_by = reviewer.user_id
        WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;
    
    if (unit && unit !== 'all') {
        sql += ` AND dr.unit_id = $${paramIndex}`;
        params.push(unit);
        paramIndex++;
    }
    
    if (status && status !== 'all') {
        sql += ` AND dr.status = $${paramIndex}`;
        params.push(status);
        paramIndex++;
    } else {
        sql += ` AND dr.status = 'pending'`;
    }
    
    sql += ` ORDER BY dr.created_at DESC`;
    
    const result = await query(sql, params);
    res.json({ success: true, data: result.rows });
}));

router.put('/destruction-requests/:id/approve', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { approval_notes, scheduled_date } = req.body;
    const result = await processDestructionRequest(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'approved',
        review_notes: approval_notes
    });
    res.json({ success: true, data: result, message: 'Destruction request approved' });
}));

router.put('/destruction-requests/:id/reject', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { rejection_reason, detailed_feedback } = req.body;
    const review_notes = `Reason: ${rejection_reason}\nFeedback: ${detailed_feedback}`;
    const result = await processDestructionRequest(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'rejected',
        review_notes
    });
    res.json({ success: true, data: result, message: 'Destruction request rejected' });
}));

// ===== PROCUREMENT REQUESTS =====
router.get('/procurement-requests', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const { priority, unit, status } = req.query;
    
    let sql = `
        SELECT 
            pr.*,
            u.unit_name,
            requester.full_name as requested_by_name,
            reviewer.full_name as reviewed_by_name
        FROM procurement_requests pr
        LEFT JOIN units u ON pr.unit_id = u.unit_id
        LEFT JOIN users requester ON pr.requested_by = requester.user_id
        LEFT JOIN users reviewer ON pr.reviewed_by = reviewer.user_id
        WHERE 1=1
    `;
    const params = [];
    let paramIndex = 1;
    
    if (unit && unit !== 'all') {
        sql += ` AND pr.unit_id = $${paramIndex}`;
        params.push(unit);
        paramIndex++;
    }
    
    if (priority && priority !== 'all') {
        sql += ` AND pr.priority = $${paramIndex}`;
        params.push(priority);
        paramIndex++;
    }
    
    if (status && status !== 'all') {
        sql += ` AND pr.status = $${paramIndex}`;
        params.push(status);
        paramIndex++;
    } else {
        sql += ` AND pr.status = 'pending'`;
    }
    
    sql += ` ORDER BY 
        CASE pr.priority 
            WHEN 'urgent' THEN 1 
            WHEN 'high' THEN 2 
            ELSE 3 
        END,
        pr.created_at DESC
    `;
    
    const result = await query(sql, params);
    res.json({ success: true, data: result.rows });
}));

router.put('/procurement-requests/:id/approve', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { approval_notes, budget_code } = req.body;
    const result = await processProcurementRequest(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'approved',
        review_notes: approval_notes
    });
    res.json({ success: true, data: result, message: 'Procurement request approved' });
}));

router.put('/procurement-requests/:id/reject', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { rejection_reason, detailed_feedback } = req.body;
    const review_notes = `Reason: ${rejection_reason}\nFeedback: ${detailed_feedback}`;
    const result = await processProcurementRequest(req.params.id, {
        reviewed_by: req.user.user_id,
        status: 'rejected',
        review_notes
    });
    res.json({ success: true, data: result, message: 'Procurement request rejected' });
}));

// ===== LEGACY ENDPOINTS (keeping for backwards compatibility) =====
router.get('/pending', authenticate, requireHQCommander, asyncHandler(async (req, res) => {
    const approvals = await getPendingApprovals();
    res.json({ success: true, data: approvals });
}));

router.post('/loss-report/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processLossReport(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Loss report ${status}` });
}));

router.post('/destruction/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processDestructionRequest(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Destruction request ${status}` });
}));

router.post('/procurement/:id', authenticate, requireHQCommander, logApproval, asyncHandler(async (req, res) => {
    const { status, review_notes } = req.body;
    const result = await processProcurementRequest(req.params.id, { reviewed_by: req.user.user_id, status, review_notes });
    res.json({ success: true, data: result, message: `Procurement request ${status}` });
}));

module.exports = router;
