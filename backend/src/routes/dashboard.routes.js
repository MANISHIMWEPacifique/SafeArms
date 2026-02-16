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

    // Station Commander specific stats: officers count
    if (role === 'station_commander') {
        // Officers in this unit
        const officersCount = await query(
            `SELECT COUNT(*) as total FROM officers WHERE unit_id = $1 AND is_active = true`,
            [unit_id]
        );
        dashboardData.officers_count = parseInt(officersCount.rows[0].total);
    }

    // Recent custody activity - available for ALL roles
    // Station commanders see their unit only; others see all units
    const recentCustody = await query(`
        SELECT 
            cr.custody_id,
            cr.issued_at,
            cr.returned_at,
            cr.assignment_reason,
            cr.custody_type,
            o.full_name as officer_name,
            f.serial_number,
            f.firearm_type,
            u.unit_name
        FROM custody_records cr
        JOIN officers o ON cr.officer_id = o.officer_id
        JOIN firearms f ON cr.firearm_id = f.firearm_id
        LEFT JOIN units u ON cr.unit_id = u.unit_id
        ${role === 'station_commander' ? 'WHERE cr.unit_id = $1' : ''}
        ORDER BY cr.issued_at DESC
        LIMIT 10
    `, role === 'station_commander' ? [unit_id] : []);
    dashboardData.recent_custody = recentCustody.rows;

    // Recent activities from audit logs - available for ALL roles
    const recentActivities = await query(`
        SELECT 
            al.log_id,
            al.action_type,
            al.table_name,
            al.record_id,
            al.created_at,
            al.success,
            u.full_name as actor_name,
            COALESCE(
                al.new_values->>'subject_name',
                al.new_values->>'subject_type',
                al.table_name
            ) as subject_description
        FROM audit_logs al
        LEFT JOIN users u ON al.user_id = u.user_id
        WHERE al.success = true
        ${role === 'station_commander' ? "AND (u.unit_id = $1 OR al.new_values->>'actor_unit_id' = $1)" : ''}
        ORDER BY al.created_at DESC
        LIMIT 10
    `, role === 'station_commander' ? [unit_id] : []);
    dashboardData.recent_activities = recentActivities.rows;

    // Investigator specific stats
    if (role === 'investigator') {
        // Ballistic profiles count
        const ballisticCount = await query(`SELECT COUNT(*) as total FROM ballistic_profiles`);
        dashboardData.ballistic_profiles_count = parseInt(ballisticCount.rows[0].total);

        // Total custody records (for tracing)
        const totalCustody = await query(`SELECT COUNT(*) as total FROM custody_records`);
        dashboardData.total_custody_traces = parseInt(totalCustody.rows[0].total);

        // Loss reports summary (active cases for investigator)
        const lossReportStats = await query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE status = 'pending') as pending,
                COUNT(*) FILTER (WHERE status = 'approved') as approved,
                COUNT(*) FILTER (WHERE status = 'rejected') as rejected
            FROM loss_reports
        `);
        dashboardData.loss_reports_summary = lossReportStats.rows[0];

        // Anomalies needing investigator review (open or investigating)
        const pendingAnomalies = await query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE severity = 'critical') as critical,
                COUNT(*) FILTER (WHERE severity = 'high') as high,
                COUNT(*) FILTER (WHERE severity IN ('critical', 'high') AND status = 'open') as mandatory_pending
            FROM anomalies
            WHERE status IN ('open', 'investigating')
        `);
        dashboardData.pending_anomalies_summary = pendingAnomalies.rows[0];

        // Recent ballistic profiles with full characteristics for dashboard table
        const recentProfiles = await query(`
            SELECT 
                bp.ballistic_id,
                bp.firearm_id,
                bp.test_date,
                bp.test_location,
                bp.rifling_characteristics,
                bp.firing_pin_impression,
                bp.ejector_marks,
                bp.extractor_marks,
                bp.chamber_marks,
                bp.forensic_lab,
                bp.is_locked,
                bp.registration_hash,
                bp.created_at,
                f.serial_number,
                f.manufacturer,
                f.model,
                f.caliber,
                f.firearm_type,
                f.current_status as firearm_status,
                u.unit_name as assigned_unit_name
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            ORDER BY bp.created_at DESC
            LIMIT 10
        `);
        dashboardData.recent_ballistic_profiles = recentProfiles.rows;

        // Recent custody events across all units (for investigator timeline)
        const recentCustodyEvents = await query(`
            SELECT 
                cr.custody_id,
                cr.custody_type,
                cr.issued_at,
                cr.returned_at,
                cr.assignment_reason,
                f.serial_number,
                f.manufacturer,
                f.model,
                f.firearm_type,
                f.caliber,
                o.full_name as officer_name,
                o.rank as officer_rank,
                u.unit_name,
                CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as custody_status
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN officers o ON cr.officer_id = o.officer_id
            LEFT JOIN units u ON cr.unit_id = u.unit_id
            ORDER BY cr.issued_at DESC
            LIMIT 15
        `);
        dashboardData.recent_custody_events = recentCustodyEvents.rows;
    }

    res.json({
        success: true,
        data: dashboardData
    });
}));

module.exports = router;
