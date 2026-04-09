const express = require('express');
const router = express.Router();
const { query } = require('../config/database');
const { authenticate } = require('../middleware/authentication');
const { asyncHandler } = require('../middleware/errorHandler');

const parsedDashboardBatchSize = parseInt(process.env.DASHBOARD_QUERY_BATCH_SIZE || '10', 10);
const DASHBOARD_QUERY_BATCH_SIZE = Number.isFinite(parsedDashboardBatchSize) && parsedDashboardBatchSize > 0
    ? parsedDashboardBatchSize
    : 5;

const executeQueryMapInBatches = async (queries, batchSize = DASHBOARD_QUERY_BATCH_SIZE) => {
    const keys = Object.keys(queries);
    const results = {};

    for (let i = 0; i < keys.length; i += batchSize) {
        const batchKeys = keys.slice(i, i + batchSize);
        const batchResults = await Promise.all(batchKeys.map((key) => queries[key]()));

        batchKeys.forEach((key, index) => {
            results[key] = batchResults[index];
        });
    }

    return results;
};

router.get('/', authenticate, asyncHandler(async (req, res) => {
    const { role, unit_id } = req.user;
    const isStationCmd = role === 'station_commander';
    const unitParams = isStationCmd ? [unit_id] : [];

    // ── Build all queries up-front, then run in ONE Promise.all ──
    const queries = {};

    // Common stats (all roles)
    queries.firearmsStats = () => query(`
        SELECT 
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE current_status = 'available') as available,
          COUNT(*) FILTER (WHERE current_status = 'in_custody') as in_custody,
          COUNT(*) FILTER (WHERE current_status = 'maintenance') as maintenance
        FROM firearms
        ${isStationCmd ? 'WHERE assigned_unit_id = $1' : ''}
    `, unitParams);

    queries.custodyStats = () => query(`
        SELECT COUNT(*) as active_custody
        FROM custody_records
        WHERE returned_at IS NULL
        ${isStationCmd ? 'AND unit_id = $1' : ''}
    `, unitParams);

    if (role === 'admin') {
        queries.anomaliesStats = async () => ({ rows: [] });
    } else {
        queries.anomaliesStats = () => query(`
        SELECT severity, COUNT(*) as count
        FROM anomalies
        WHERE detected_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
        ${isStationCmd ? 'AND unit_id = $1' : ''}
        GROUP BY severity
    `, unitParams);
    }

    queries.recentCustody = () => query(`
        SELECT 
            cr.custody_id, cr.issued_at, cr.returned_at,
            cr.assignment_reason, cr.custody_type,
            COALESCE(cr.returned_at, cr.issued_at) as activity_at,
            o.full_name as officer_name,
            f.serial_number, f.firearm_type,
            u.unit_name,
            CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as custody_status
        FROM custody_records cr
        JOIN officers o ON cr.officer_id = o.officer_id
        JOIN firearms f ON cr.firearm_id = f.firearm_id
        LEFT JOIN units u ON cr.unit_id = u.unit_id
        ${isStationCmd
            ? 'WHERE cr.unit_id = $1 AND COALESCE(cr.returned_at, cr.issued_at) <= CURRENT_TIMESTAMP'
            : 'WHERE COALESCE(cr.returned_at, cr.issued_at) <= CURRENT_TIMESTAMP'}
        ORDER BY COALESCE(cr.returned_at, cr.issued_at) DESC
        LIMIT 10
    `, unitParams);

    queries.recentActivities = () => query(`
        SELECT 
            al.log_id, al.action_type, al.table_name,
            al.record_id, al.created_at, al.success,
            u.full_name as actor_name,
            COALESCE(
                al.new_values->>'subject_name',
                al.new_values->>'subject_type',
                al.table_name
            ) as subject_description
        FROM audit_logs al
        LEFT JOIN users u ON al.user_id = u.user_id
        WHERE al.success = true
        AND al.created_at <= CURRENT_TIMESTAMP
        ${isStationCmd ? `AND (
            u.unit_id = $1
            OR al.new_values->>'actor_unit_id' = $1
            OR al.new_values->>'unit_id' = $1
            OR al.new_values->'body'->>'unit_id' = $1
            OR al.new_values->>'to_unit_id' = $1
            OR al.new_values->>'from_unit_id' = $1
            OR al.new_values->'body'->>'to_unit_id' = $1
            OR al.new_values->'body'->>'from_unit_id' = $1
            OR (
                (
                    al.table_name IN ('custody', 'custody_records')
                    OR al.action_type IN ('CUSTODY_ASSIGNED', 'CUSTODY_RETURNED', 'CROSS_UNIT_TRANSFER')
                )
                AND EXISTS (
                    SELECT 1
                    FROM custody_records cr
                    WHERE cr.unit_id = $1
                      AND (
                          cr.custody_id = al.record_id
                          OR cr.firearm_id = al.record_id
                          OR cr.custody_id = COALESCE(al.new_values->>'record_id', al.new_values->'body'->>'custody_id')
                          OR cr.firearm_id = COALESCE(al.new_values->>'firearm_id', al.new_values->'body'->>'firearm_id')
                      )
                )
            )
        )` : ''}
        ORDER BY al.created_at DESC
        LIMIT 10
    `, unitParams);

    // Role-specific queries
    if (role === 'hq_firearm_commander' || role === 'admin') {
        queries.pendingApprovals = () => query(`
            SELECT 
                (SELECT COUNT(*) FROM loss_reports WHERE status = 'pending') as loss_reports,
                (SELECT COUNT(*) FROM destruction_requests WHERE status = 'pending') as destruction_requests,
                (SELECT COUNT(*) FROM procurement_requests WHERE status = 'pending') as procurement_requests
        `);
    }

    if (role === 'admin') {
        queries.usersCount = () => query(`SELECT COUNT(*) as total FROM users WHERE is_active = true`);
        queries.activeUnits = () => query(`SELECT COUNT(*) as total FROM units WHERE is_active = true`);
        queries.roleActivity = () => query(`
            SELECT 
                DATE(created_at) as activity_date,
                new_values->>'actor_role' as actor_role,
                COUNT(*) as actions_count
            FROM audit_logs
            WHERE created_at >= CURRENT_DATE - INTERVAL '90 days'
            AND new_values->>'actor_role' IS NOT NULL
            GROUP BY DATE(created_at), new_values->>'actor_role'
            ORDER BY activity_date ASC
        `);
    }

    if (role === 'hq_firearm_commander') {
        queries.activeUnits = () => query(`SELECT COUNT(*) as total FROM units WHERE is_active = true`);
    }

    if (isStationCmd) {
        queries.officersCount = () => query(
            `SELECT COUNT(*) as total FROM officers WHERE unit_id = $1 AND is_active = true`,
            [unit_id]
        );
    }

    if (role === 'investigator') {
        queries.ballisticCount = () => query(`SELECT COUNT(*) as total FROM ballistic_profiles`);
        queries.totalCustody = () => query(`SELECT COUNT(*) as total FROM custody_records`);
        queries.lossReportStats = () => query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE status = 'pending') as pending,
                COUNT(*) FILTER (WHERE status = 'approved') as approved,
                COUNT(*) FILTER (WHERE status = 'rejected') as rejected
            FROM loss_reports
        `);
        queries.pendingAnomalies = () => query(`
            SELECT 
                COUNT(*) as total,
                COUNT(*) FILTER (WHERE severity = 'critical') as critical,
                COUNT(*) FILTER (WHERE severity = 'high') as high,
                COUNT(*) FILTER (WHERE severity IN ('critical', 'high') AND status = 'open') as mandatory_pending
            FROM anomalies
            WHERE status IN ('open', 'investigating')
        `);
        queries.recentProfiles = () => query(`
            SELECT 
                bp.ballistic_id, bp.firearm_id, bp.test_date, bp.test_location,
                bp.rifling_characteristics, bp.firing_pin_impression,
                bp.ejector_marks, bp.extractor_marks, bp.chamber_marks,
                bp.forensic_lab, bp.is_locked, bp.registration_hash, bp.created_at,
                f.serial_number, f.manufacturer, f.model, f.caliber,
                f.firearm_type, f.current_status as firearm_status,
                u.unit_name as assigned_unit_name
            FROM ballistic_profiles bp
            JOIN firearms f ON bp.firearm_id = f.firearm_id
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            ORDER BY bp.created_at DESC
            LIMIT 10
        `);
        queries.recentCustodyEvents = () => query(`
            SELECT 
                cr.custody_id, cr.custody_type, cr.issued_at,
                cr.returned_at, cr.assignment_reason,
                COALESCE(cr.returned_at, cr.issued_at) as activity_at,
                f.serial_number, f.manufacturer, f.model,
                f.firearm_type, f.caliber,
                o.full_name as officer_name, o.rank as officer_rank,
                u.unit_name,
                CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as custody_status
            FROM custody_records cr
            JOIN firearms f ON cr.firearm_id = f.firearm_id
            JOIN officers o ON cr.officer_id = o.officer_id
            LEFT JOIN units u ON cr.unit_id = u.unit_id
            WHERE COALESCE(cr.returned_at, cr.issued_at) <= CURRENT_TIMESTAMP
            ORDER BY COALESCE(cr.returned_at, cr.issued_at) DESC
            LIMIT 15
        `);
    }

    // Execute independent queries in bounded parallel batches to reduce latency
    // while keeping DB pool usage controlled under concurrent traffic.
    const r = await executeQueryMapInBatches(queries);

    // ── Assemble response ──
    const dashboardData = {
        role,
        unit_id,
        timestamp: new Date().toISOString(),
        firearms: r.firearmsStats.rows[0],
        active_custody: parseInt(r.custodyStats.rows[0].active_custody),
        anomalies: r.anomaliesStats.rows,
        recent_custody: r.recentCustody.rows,
        recent_activities: r.recentActivities.rows,
    };

    if (r.pendingApprovals) dashboardData.pending_approvals = r.pendingApprovals.rows[0];
    if (r.usersCount) dashboardData.total_users = parseInt(r.usersCount.rows[0].total);
    if (r.activeUnits) dashboardData.active_units = parseInt(r.activeUnits.rows[0].total);
    if (r.roleActivity) dashboardData.role_activity = r.roleActivity.rows;
    if (r.officersCount) dashboardData.officers_count = parseInt(r.officersCount.rows[0].total);

    if (role === 'investigator') {
        dashboardData.ballistic_profiles_count = parseInt(r.ballisticCount.rows[0].total);
        dashboardData.total_custody_traces = parseInt(r.totalCustody.rows[0].total);
        dashboardData.loss_reports_summary = r.lossReportStats.rows[0];
        dashboardData.pending_anomalies_summary = r.pendingAnomalies.rows[0];
        dashboardData.recent_ballistic_profiles = r.recentProfiles.rows;
        dashboardData.recent_custody_events = r.recentCustodyEvents.rows;
    }

    res.json({ success: true, data: dashboardData });
}));

module.exports = router;
