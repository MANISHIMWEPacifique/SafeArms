const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authenticate } = require('../middleware/authentication');
const { asyncHandler } = require('../middleware/errorHandler');

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id } = req.user;

    let dashboardData = {
        role,
        unit_id,
        timestamp: new Date().toISOString()
    };

    // Common stats for all roles
    const firearmsStats = await query(`
    SELECT 
      COUNT(*) as total,
      COUNT(*) FILTER (WHERE current_status = 'available') as available,
      COUNT(*) FILTER (WHERE current_status = 'in_custody') as in_custody,
      COUNT(*) FILTER (WHERE current_status = 'maintenance') as maintenance
    FROM firearms
    ${role === 'station_commander' ? 'WHERE assigned_unit_id = $1' : ''}
  `, role === 'station_commander' ? [unit_id] : []);

    dashboardData.firearms = firearmsStats.rows[0];

    // Active custody count
    const custodyStats = await query(`
    SELECT COUNT(*) as active_custody
    FROM custody_records
    WHERE returned_at IS NULL
    ${role === 'station_commander' ? 'AND unit_id = $1' : ''}
  `, role === 'station_commander' ? [unit_id] : []);

    dashboardData.active_custody = parseInt(custodyStats.rows[0].active_custody);

    // Recent anomalies
    const anomaliesStats = await query(`
    SELECT 
      severity,
      COUNT(*) as count
    FROM anomalies
    WHERE detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
    ${role === 'station_commander' ? 'AND unit_id = $1' : ''}
    GROUP BY severity
  `, role === 'station_commander' ? [unit_id] : []);

    dashboardData.anomalies = anomaliesStats.rows;

    // Pending approvals (HQ Commander only)
    if (role === 'hq_firearm_commander' || role === 'admin') {
        const pendingStats = await query(`
      SELECT 
        (SELECT COUNT(*) FROM loss_reports WHERE status = 'pending') as loss_reports,
        (SELECT COUNT(*) FROM destruction_requests WHERE status = 'pending') as destruction_requests,
        (SELECT COUNT(*) FROM procurement_requests WHERE status = 'pending') as procurement_requests
    `);
        dashboardData.pending_approvals = pendingStats.rows[0];
    }

    res.json({
        success: true,
        data: dashboardData
    });
}));

module.exports = router;
