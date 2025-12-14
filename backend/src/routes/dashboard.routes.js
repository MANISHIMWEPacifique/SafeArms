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

    // Admin-specific stats: total users and units
    if (role === 'admin') {
        const usersCount = await query(`SELECT COUNT(*) as total FROM users WHERE is_active = true`);
        const unitsCount = await query(`SELECT COUNT(*) as total FROM units WHERE is_active = true`);
        dashboardData.total_users = parseInt(usersCount.rows[0].total);
        dashboardData.active_units = parseInt(unitsCount.rows[0].total);
    }

    // HQ Commander stats: active units nationwide
    if (role === 'hq_firearm_commander') {
        const unitsCount = await query(`SELECT COUNT(*) as total FROM units WHERE is_active = true`);
        dashboardData.active_units = parseInt(unitsCount.rows[0].total);
    }

    // Station Commander specific stats: officers count and recent custody
    if (role === 'station_commander') {
        // Officers in this unit
        const officersCount = await query(
            `SELECT COUNT(*) as total FROM officers WHERE unit_id = $1 AND is_active = true`,
            [unit_id]
        );
        dashboardData.officers_count = parseInt(officersCount.rows[0].total);

        // Recent custody activity for this unit
        const recentCustody = await query(`
            SELECT 
                cr.custody_id,
                cr.issued_at,
                cr.returned_at,
                cr.assignment_reason,
                cr.custody_type,
                o.full_name as officer_name,
                f.serial_number,
                f.firearm_type
            FROM custody_records cr
            JOIN officers o ON cr.officer_id = o.officer_id
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            WHERE cr.unit_id = $1
            ORDER BY cr.issued_at DESC
            LIMIT 5
        `, [unit_id]);
        dashboardData.recent_custody = recentCustody.rows;
    }

    // Forensic Analyst specific stats
    if (role === 'forensic_analyst') {
        // Ballistic profiles count
        const ballisticCount = await query(`SELECT COUNT(*) as total FROM ballistic_profiles`);
        dashboardData.ballistic_profiles_count = parseInt(ballisticCount.rows[0].total);

        // Total custody records (for tracing)
        const totalCustody = await query(`SELECT COUNT(*) as total FROM custody_records`);
        dashboardData.total_custody_traces = parseInt(totalCustody.rows[0].total);
    }

    res.json({
        success: true,
        data: dashboardData
    });
}));

module.exports = router;
