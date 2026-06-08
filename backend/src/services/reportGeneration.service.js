const { query } = require('../config/database');
const { ROLES } = require('../middleware/authorization');

const GENERATED_REPORT_ROLE_RULES = {
    firearm_history: [ROLES.HQ_COMMANDER, ROLES.INVESTIGATOR],
    ballistic_summary: [ROLES.HQ_COMMANDER, ROLES.INVESTIGATOR],
    anomaly_summary: [ROLES.HQ_COMMANDER, ROLES.INVESTIGATOR],
    user_activity: [ROLES.ADMIN]
};

const ensureGeneratedReportAccess = (userRole, reportType) => {
    const allowedRoles = GENERATED_REPORT_ROLE_RULES[reportType];
    if (!allowedRoles) {
        return {
            allowed: false,
            status: 400,
            payload: { success: false, message: `Unknown report type: ${reportType}` }
        };
    }

    if (!allowedRoles.includes(userRole)) {
        return {
            allowed: false,
            status: 403,
            payload: {
                success: false,
                message: 'Access denied. This report is not available for your role.'
            }
        };
    }

    return { allowed: true };
};

const parsePagination = ({ page = 1, limit = 100 }) => {
    const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 100, 1), 500);
    const parsedPage = Math.max(parseInt(page, 10) || 1, 1);
    return {
        limit: parsedLimit,
        offset: (parsedPage - 1) * parsedLimit
    };
};

const normalizeDateRange = ({ start_date, end_date }) => {
    const startDate = start_date ? new Date(start_date) : null;
    const endDate = end_date ? new Date(end_date) : null;

    if (endDate) {
        endDate.setHours(23, 59, 59, 999);
    }

    return {
        startDate: startDate && !Number.isNaN(startDate.getTime()) ? startDate : null,
        endDate: endDate && !Number.isNaN(endDate.getTime()) ? endDate : null
    };
};

const appendDateFilter = (params, column, dateRange) => {
    let filter = '';

    if (dateRange.startDate) {
        params.push(dateRange.startDate);
        filter += ` AND ${column} >= $${params.length}`;
    }

    if (dateRange.endDate) {
        params.push(dateRange.endDate);
        filter += ` AND ${column} <= $${params.length}`;
    }

    return filter;
};

const appendDateCondition = (params, column, dateRange) => {
    const conditions = [];

    if (dateRange.startDate) {
        params.push(dateRange.startDate);
        conditions.push(`${column} >= $${params.length}`);
    }

    if (dateRange.endDate) {
        params.push(dateRange.endDate);
        conditions.push(`${column} <= $${params.length}`);
    }

    return conditions.length > 0 ? `(${conditions.join(' AND ')})` : '';
};

const fetchRecentCustodyLogs = async (firearmIds, dateRange) => {
    if (firearmIds.length === 0) return [];

    const params = [firearmIds];
    const dateFilter = appendDateFilter(params, 'cr.issued_at', dateRange);

    const result = await query(`
        SELECT cr.custody_id, cr.firearm_id, cr.issued_at, cr.returned_at,
               cr.custody_type,
               CASE WHEN cr.returned_at IS NULL THEN 'active' ELSE 'returned' END as custody_status,
               f.serial_number,
               o.full_name as officer_name, o.officer_id,
               u.unit_name
        FROM custody_records cr
        LEFT JOIN firearms f ON cr.firearm_id = f.firearm_id
        LEFT JOIN officers o ON cr.officer_id = o.officer_id
        LEFT JOIN units u ON cr.unit_id = u.unit_id
        WHERE cr.firearm_id = ANY($1)
        ${dateFilter}
        ORDER BY cr.issued_at DESC
        LIMIT 500
    `, params);

    return result.rows;
};

const buildFirearmHistoryReport = async (filters, pagination) => {
    const { startDate, endDate } = normalizeDateRange(filters);
    const dateRange = { startDate, endDate };
    const params = [];
    let firearmFilter = 'WHERE 1=1';

    if (filters.serial_number) {
        params.push(`%${filters.serial_number}%`);
        firearmFilter += ` AND f.serial_number ILIKE $${params.length}`;
    }

    if (filters.unit_id) {
        params.push(filters.unit_id);
        firearmFilter += ` AND f.assigned_unit_id = $${params.length}`;
    }

    const dateConditions = [];
    const createdAtCondition = appendDateCondition(params, 'f.created_at', dateRange);
    if (createdAtCondition) dateConditions.push(createdAtCondition);

    const custodyIssuedCondition = appendDateCondition(params, 'cr.issued_at', dateRange);
    if (custodyIssuedCondition) {
        dateConditions.push(`EXISTS (
            SELECT 1 FROM custody_records cr
            WHERE cr.firearm_id = f.firearm_id
            AND ${custodyIssuedCondition}
        )`);
    }

    const movementCondition = appendDateCondition(params, 'fum.authorization_date', dateRange);
    if (movementCondition) {
        dateConditions.push(`EXISTS (
            SELECT 1 FROM firearm_unit_movements fum
            WHERE fum.firearm_id = f.firearm_id
            AND ${movementCondition}
        )`);
    }

    if (dateConditions.length > 0) {
        firearmFilter += ` AND (${dateConditions.join(' OR ')})`;
    }

    params.push(pagination.limit, pagination.offset);
    const firearms = await query(`
        SELECT f.firearm_id, f.serial_number, f.firearm_type, f.caliber,
               f.manufacturer, f.model, f.acquisition_date, f.current_status,
               f.created_at, u.unit_name
        FROM firearms f
        LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
        ${firearmFilter}
        ORDER BY f.created_at DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}
    `, params);

    const firearmIds = firearms.rows.map(f => f.firearm_id);
    let custodyRecords = [];
    let unitHistory = [];
    let anomalies = [];
    let ballisticProfile = null;

    if (firearmIds.length > 0) {
        const custodyParams = [firearmIds];
        const custodyDateFilter = appendDateFilter(custodyParams, 'cr.issued_at', dateRange);
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
            ${custodyDateFilter}
            ORDER BY cr.issued_at ASC
            LIMIT 500
        `, custodyParams);
        custodyRecords = custodyResult.rows;

        const movementParams = [firearmIds];
        const movementDateFilter = appendDateFilter(movementParams, 'fum.authorization_date', dateRange);
        const movementResult = await query(`
            SELECT fum.movement_id, fum.firearm_id, fum.movement_type,
                   fum.authorization_date as assigned_date,
                   fum.reason,
                   f.serial_number,
                   from_unit.unit_name as from_unit_name,
                   to_unit.unit_name as unit_name,
                   u.full_name as authorized_by_name
            FROM firearm_unit_movements fum
            LEFT JOIN firearms f ON fum.firearm_id = f.firearm_id
            LEFT JOIN units from_unit ON fum.from_unit_id = from_unit.unit_id
            LEFT JOIN units to_unit ON fum.to_unit_id = to_unit.unit_id
            LEFT JOIN users u ON fum.authorized_by = u.user_id
            WHERE fum.firearm_id = ANY($1)
            ${movementDateFilter}
            ORDER BY fum.authorization_date ASC
            LIMIT 500
        `, movementParams);
        unitHistory = movementResult.rows;

        const anomalyParams = [firearmIds];
        const anomalyDateFilter = appendDateFilter(anomalyParams, 'a.detected_at', dateRange);
        const anomalyResult = await query(`
            SELECT a.anomaly_id, a.firearm_id, a.severity, a.status,
                   a.detected_at, a.anomaly_type,
                   f.serial_number, u.unit_name
            FROM anomalies a
            LEFT JOIN firearms f ON a.firearm_id = f.firearm_id
            LEFT JOIN units u ON a.unit_id = u.unit_id
            WHERE a.firearm_id = ANY($1)
            ${anomalyDateFilter}
            ORDER BY a.detected_at DESC
            LIMIT 500
        `, anomalyParams);
        anomalies = anomalyResult.rows;

        if (firearmIds.length === 1) {
            const ballisticResult = await query(`
                SELECT bp.*, f.serial_number, f.firearm_type, f.caliber
                FROM ballistic_profiles bp
                LEFT JOIN firearms f ON bp.firearm_id = f.firearm_id
                WHERE bp.firearm_id = $1
                LIMIT 1
            `, [firearmIds[0]]);
            ballisticProfile = ballisticResult.rows[0] || null;
        }
    }

    return {
        firearms: firearms.rows,
        custody_records: custodyRecords,
        unit_history: unitHistory,
        anomalies,
        ballistic_profile: ballisticProfile,
        recent_custody_logs: custodyRecords.slice().reverse().slice(0, 100)
    };
};

const buildBallisticSummaryReport = async (filters, pagination) => {
    const dateRange = normalizeDateRange(filters);
    const params = [];
    let bpFilter = 'WHERE 1=1';

    if (filters.serial_number) {
        params.push(`%${filters.serial_number}%`);
        bpFilter += ` AND f.serial_number ILIKE $${params.length}`;
    }

    if (filters.unit_id) {
        params.push(filters.unit_id);
        bpFilter += ` AND f.assigned_unit_id = $${params.length}`;
    }

    bpFilter += appendDateFilter(params, 'bp.created_at', dateRange);

    params.push(pagination.limit, pagination.offset);
    const profiles = await query(`
        SELECT bp.ballistic_id, bp.firearm_id, bp.rifling_characteristics, bp.firing_pin_impression,
               bp.ejector_marks, bp.extractor_marks, bp.chamber_marks,
               bp.test_date, bp.test_location, bp.forensic_lab,
               bp.is_locked, bp.registration_hash,
               bp.created_at,
               f.serial_number, f.firearm_type, f.caliber
        FROM ballistic_profiles bp
        LEFT JOIN firearms f ON bp.firearm_id = f.firearm_id
        ${bpFilter}
        ORDER BY bp.created_at DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}
    `, params);

    const firearmIds = profiles.rows.map(p => p.firearm_id).filter(Boolean);
    let activities = [];
    let recentCustodyLogs = [];

    if (firearmIds.length > 0) {
        recentCustodyLogs = await fetchRecentCustodyLogs(firearmIds, dateRange);

        const accessParams = [firearmIds];
        const accessDateFilter = appendDateFilter(accessParams, 'bal.accessed_at', dateRange);
        const accessLogs = await query(`
            SELECT bal.access_id as id, bal.firearm_id, 'Access Log' as activity_type,
                   bal.access_type as action,
                   bal.access_reason as notes, u.full_name as investigator_name,
                   bal.accessed_at as activity_date, f.serial_number
            FROM ballistic_access_logs bal
            LEFT JOIN users u ON bal.accessed_by = u.user_id
            LEFT JOIN firearms f ON bal.firearm_id = f.firearm_id
            WHERE bal.firearm_id = ANY($1)
            ${accessDateFilter}
        `, accessParams);

        const investigationParams = [firearmIds];
        const investigationDateFilter = appendDateFilter(investigationParams, 'ai.investigation_date', dateRange);
        const investigations = await query(`
            SELECT ai.investigation_id as id, a.firearm_id, 'Investigation' as activity_type,
                   COALESCE(ai.outcome, ai.action_taken) as action,
                   ai.findings as notes, u.full_name as investigator_name,
                   ai.investigation_date as activity_date, f.serial_number
            FROM anomaly_investigations ai
            LEFT JOIN anomalies a ON ai.anomaly_id = a.anomaly_id
            LEFT JOIN users u ON ai.investigator_id = u.user_id
            LEFT JOIN firearms f ON a.firearm_id = f.firearm_id
            WHERE a.firearm_id = ANY($1)
            ${investigationDateFilter}
        `, investigationParams);

        activities = [...accessLogs.rows, ...investigations.rows]
            .sort((a, b) => new Date(b.activity_date) - new Date(a.activity_date))
            .slice(0, 500);
    }

    return {
        profiles: profiles.rows,
        investigator_activities: activities,
        recent_custody_logs: recentCustodyLogs
    };
};

const buildAnomalySummaryReport = async (filters, pagination) => {
    const dateRange = normalizeDateRange(filters);
    const params = [];
    let aFilter = 'WHERE 1=1';

    if (filters.unit_id) {
        params.push(filters.unit_id);
        aFilter += ` AND a.unit_id = $${params.length}`;
    }

    if (filters.serial_number) {
        params.push(`%${filters.serial_number}%`);
        aFilter += ` AND f.serial_number ILIKE $${params.length}`;
    }

    aFilter += appendDateFilter(params, 'a.detected_at', dateRange);

    params.push(pagination.limit, pagination.offset);
    const anomalies = await query(`
        SELECT a.anomaly_id, a.severity, a.status,
               a.detected_at, a.anomaly_type,
               f.serial_number,
               u.unit_name
        FROM anomalies a
        LEFT JOIN firearms f ON a.firearm_id = f.firearm_id
        LEFT JOIN units u ON a.unit_id = u.unit_id
        ${aFilter}
        ORDER BY a.detected_at DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}
    `, params);

    const groupedAnomalies = {};
    anomalies.rows.forEach(a => {
        const groupKey = (filters.unit_id || !filters.serial_number)
            ? (a.unit_name || 'Unassigned Unit')
            : (a.serial_number || 'Unknown Firearm');
        if (!groupedAnomalies[groupKey]) groupedAnomalies[groupKey] = [];
        groupedAnomalies[groupKey].push(a);
    });

    const anomalyGroups = Object.keys(groupedAnomalies).map(groupName => ({
        group_name: groupName,
        records: groupedAnomalies[groupName]
    }));

    const total = anomalies.rows.length;
    const high = anomalies.rows.filter(a => ['high', 'critical'].includes(a.severity?.toLowerCase())).length;
    const medium = anomalies.rows.filter(a => a.severity?.toLowerCase() === 'medium').length;
    const low = anomalies.rows.filter(a => a.severity?.toLowerCase() === 'low').length;
    const reviewed = anomalies.rows.filter(a => ['resolved', 'false_positive', 'acceptable_change', 'archived'].includes(a.status?.toLowerCase())).length;
    const pending = anomalies.rows.filter(a => ['open', 'pending', 'investigating'].includes(a.status?.toLowerCase())).length;

    return {
        anomalies: anomalies.rows,
        anomaly_groups: anomalyGroups,
        summary: { total, high, medium, low, reviewed, pending }
    };
};

const buildUserActivityReport = async (filters, pagination) => {
    const dateRange = normalizeDateRange(filters);
    const params = [];
    let uaFilter = 'WHERE al.success = true';

    if (filters.user_id) {
        params.push(filters.user_id);
        uaFilter += ` AND al.user_id = $${params.length}`;
    } else if (filters.username) {
        params.push(String(filters.username).trim());
        uaFilter += ` AND LOWER(u.username) = LOWER($${params.length})`;
    }

    if (filters.role) {
        params.push(filters.role);
        uaFilter += ` AND u.role = $${params.length}`;
    }

    uaFilter += appendDateFilter(params, 'al.created_at', dateRange);

    params.push(pagination.limit, pagination.offset);
    const activities = await query(`
        SELECT al.log_id, al.action_type, al.table_name,
               al.record_id, al.created_at,
               u.username, u.role, u.full_name
        FROM audit_logs al
        LEFT JOIN users u ON al.user_id = u.user_id
        ${uaFilter}
        ORDER BY al.created_at DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}
    `, params);

    return { activities: activities.rows };
};

const generateAnalyticalReport = async (requestQuery, userRole) => {
    const { type } = requestQuery;
    const access = ensureGeneratedReportAccess(userRole, type);

    if (!access.allowed) {
        return { error: access };
    }

    const pagination = parsePagination(requestQuery);
    const filters = {
        ...requestQuery,
        role: requestQuery.role
    };

    let data;
    switch (type) {
        case 'firearm_history':
            data = await buildFirearmHistoryReport(filters, pagination);
            break;
        case 'ballistic_summary':
            data = await buildBallisticSummaryReport(filters, pagination);
            break;
        case 'anomaly_summary':
            data = await buildAnomalySummaryReport(filters, pagination);
            break;
        case 'user_activity':
            data = await buildUserActivityReport(filters, pagination);
            break;
        default:
            return {
                error: {
                    status: 400,
                    payload: { success: false, message: `Unknown report type: ${type}` }
                }
            };
    }

    return {
        data,
        meta: {
            type,
            page: Math.floor(pagination.offset / pagination.limit) + 1,
            limit: pagination.limit
        }
    };
};

module.exports = {
    generateAnalyticalReport
};
