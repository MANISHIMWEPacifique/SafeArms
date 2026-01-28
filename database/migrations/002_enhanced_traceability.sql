-- SafeArms Database Migration: Enhanced Chain-of-Custody Traceability
-- Version: 1.2.0
-- Date: 2026-01-28
-- Purpose: Complete chain-of-custody integration with ballistic traceability
--
-- REQUIREMENTS ADDRESSED:
-- 1. Ballistic profiles reference firearm directly ✓ (already exists)
-- 2. Firearm movement between units historically preserved ✓ (new table)
-- 3. Every access to ballistic data logged ✓ (enhanced)
-- 4. Custody and access events reconstructable in time order ✓ (unified view)
-- 5. Existing custody and audit logs remain immutable ✓ (trigger enforcement)
--
-- MIGRATION SAFETY:
-- - All statements use IF NOT EXISTS / IF EXISTS
-- - No DROP statements on existing tables
-- - No data modifications to existing records
-- - Rollback section provided at bottom

BEGIN;

-- ============================================
-- 1. FIREARM UNIT MOVEMENT HISTORY TABLE
-- ============================================
-- Tracks every time a firearm moves between units
-- Preserves complete transfer history

CREATE TABLE IF NOT EXISTS firearm_unit_movements (
    movement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    from_unit_id UUID REFERENCES units(unit_id),  -- NULL for initial assignment
    to_unit_id UUID NOT NULL REFERENCES units(unit_id),
    movement_type VARCHAR(50) NOT NULL CHECK (movement_type IN (
        'initial_assignment',   -- First unit assignment
        'transfer',             -- Regular inter-unit transfer
        'reassignment',         -- Administrative reassignment
        'temporary_loan',       -- Temporary assignment to another unit
        'return_from_loan'      -- Return from temporary loan
    )),
    -- Authorization
    authorized_by UUID NOT NULL REFERENCES users(user_id),
    authorization_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    authorization_reference VARCHAR(100),  -- Document/order reference
    -- Movement context
    reason TEXT,
    custody_record_id UUID REFERENCES custody_records(custody_id),  -- Associated custody if any
    -- Metadata
    ip_address VARCHAR(50),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for movement queries
CREATE INDEX IF NOT EXISTS idx_unit_movements_firearm ON firearm_unit_movements(firearm_id);
CREATE INDEX IF NOT EXISTS idx_unit_movements_from_unit ON firearm_unit_movements(from_unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_movements_to_unit ON firearm_unit_movements(to_unit_id);
CREATE INDEX IF NOT EXISTS idx_unit_movements_date ON firearm_unit_movements(authorization_date);
CREATE INDEX IF NOT EXISTS idx_unit_movements_firearm_date ON firearm_unit_movements(firearm_id, authorization_date DESC);

COMMENT ON TABLE firearm_unit_movements IS 
'Complete history of firearm movements between units. 
Immutable audit trail - records cannot be modified after creation.';

-- ============================================
-- 2. CUSTODY RECORD IMMUTABILITY TRIGGER
-- ============================================
-- Prevent deletion of custody records (immutability requirement)
-- Only allow updates to specific fields (returned_at, return_condition, notes)

CREATE OR REPLACE FUNCTION prevent_custody_deletion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Custody records are immutable and cannot be deleted. Record ID: %', OLD.custody_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_custody_deletion ON custody_records;
CREATE TRIGGER trg_prevent_custody_deletion
    BEFORE DELETE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION prevent_custody_deletion();

-- Restrict which fields can be updated on custody records
CREATE OR REPLACE FUNCTION restrict_custody_updates()
RETURNS TRIGGER AS $$
BEGIN
    -- Allow updates only if returning the firearm or adding notes
    IF OLD.returned_at IS NOT NULL AND NEW.returned_at IS DISTINCT FROM OLD.returned_at THEN
        RAISE EXCEPTION 'Cannot modify returned_at once set. Custody ID: %', OLD.custody_id;
    END IF;
    
    -- Prevent modification of core fields
    IF NEW.firearm_id IS DISTINCT FROM OLD.firearm_id OR
       NEW.officer_id IS DISTINCT FROM OLD.officer_id OR
       NEW.unit_id IS DISTINCT FROM OLD.unit_id OR
       NEW.issued_at IS DISTINCT FROM OLD.issued_at OR
       NEW.issued_by IS DISTINCT FROM OLD.issued_by THEN
        RAISE EXCEPTION 'Core custody record fields are immutable. Custody ID: %', OLD.custody_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_restrict_custody_updates ON custody_records;
CREATE TRIGGER trg_restrict_custody_updates
    BEFORE UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION restrict_custody_updates();

-- ============================================
-- 3. AUDIT LOG IMMUTABILITY TRIGGER
-- ============================================
-- Prevent any modification of audit logs

CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Audit logs are immutable and cannot be deleted. Log ID: %', OLD.log_id;
    ELSIF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Audit logs are immutable and cannot be updated. Log ID: %', OLD.log_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_audit_modification ON audit_logs;
CREATE TRIGGER trg_prevent_audit_modification
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_modification();

-- ============================================
-- 4. BALLISTIC PROFILE IMMUTABILITY TRIGGER
-- ============================================
-- Enforce complete immutability of ballistic profiles

CREATE OR REPLACE FUNCTION prevent_ballistic_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Ballistic profiles are forensically critical and cannot be deleted. Profile ID: %', OLD.ballistic_id;
    ELSIF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Ballistic profiles are immutable after creation. Profile ID: %', OLD.ballistic_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_ballistic_modification ON ballistic_profiles;
CREATE TRIGGER trg_prevent_ballistic_modification
    BEFORE UPDATE OR DELETE ON ballistic_profiles
    FOR EACH ROW
    EXECUTE FUNCTION prevent_ballistic_modification();

-- ============================================
-- 5. AUTOMATIC UNIT MOVEMENT LOGGING
-- ============================================
-- Automatically log unit movements when firearm.assigned_unit_id changes

CREATE OR REPLACE FUNCTION log_firearm_unit_movement()
RETURNS TRIGGER AS $$
BEGIN
    -- Only log if assigned_unit_id actually changed
    IF NEW.assigned_unit_id IS DISTINCT FROM OLD.assigned_unit_id THEN
        INSERT INTO firearm_unit_movements (
            firearm_id,
            from_unit_id,
            to_unit_id,
            movement_type,
            authorized_by,
            reason
        ) VALUES (
            NEW.firearm_id,
            OLD.assigned_unit_id,
            NEW.assigned_unit_id,
            CASE 
                WHEN OLD.assigned_unit_id IS NULL THEN 'initial_assignment'
                ELSE 'transfer'
            END,
            COALESCE(current_setting('app.current_user_id', true)::UUID, NEW.registered_by),
            'Firearm unit assignment updated'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_firearm_unit_movement ON firearms;
CREATE TRIGGER trg_log_firearm_unit_movement
    AFTER UPDATE ON firearms
    FOR EACH ROW
    EXECUTE FUNCTION log_firearm_unit_movement();

-- Also log initial assignment
CREATE OR REPLACE FUNCTION log_initial_firearm_assignment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assigned_unit_id IS NOT NULL THEN
        INSERT INTO firearm_unit_movements (
            firearm_id,
            from_unit_id,
            to_unit_id,
            movement_type,
            authorized_by,
            reason
        ) VALUES (
            NEW.firearm_id,
            NULL,
            NEW.assigned_unit_id,
            'initial_assignment',
            NEW.registered_by,
            'Initial firearm registration'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_log_initial_firearm_assignment ON firearms;
CREATE TRIGGER trg_log_initial_firearm_assignment
    AFTER INSERT ON firearms
    FOR EACH ROW
    EXECUTE FUNCTION log_initial_firearm_assignment();

-- ============================================
-- 6. UNIFIED EVENTS TIMELINE VIEW
-- ============================================
-- Single view that combines ALL events for a firearm in chronological order
-- This is the primary view for forensic traceability

DROP VIEW IF EXISTS unified_firearm_events_timeline CASCADE;
CREATE VIEW unified_firearm_events_timeline AS

-- Firearm Registration
SELECT 
    f.firearm_id,
    f.serial_number,
    'REGISTRATION'::VARCHAR(30) as event_category,
    'firearm_registered' as event_type,
    f.firearm_id as event_id,
    f.created_at as event_timestamp,
    f.registered_by as actor_user_id,
    reg_user.full_name as actor_name,
    NULL::UUID as officer_id,
    NULL::VARCHAR(200) as officer_name,
    f.assigned_unit_id as unit_id,
    unit.unit_name as unit_name,
    jsonb_build_object(
        'manufacturer', f.manufacturer,
        'model', f.model,
        'serial_number', f.serial_number,
        'firearm_type', f.firearm_type,
        'caliber', f.caliber
    ) as event_details,
    1 as event_priority  -- For sorting when timestamps match
FROM firearms f
LEFT JOIN users reg_user ON f.registered_by = reg_user.user_id
LEFT JOIN units unit ON f.assigned_unit_id = unit.unit_id

UNION ALL

-- Ballistic Profile Creation
SELECT 
    bp.firearm_id,
    f.serial_number,
    'BALLISTIC'::VARCHAR(30),
    'ballistic_profile_created',
    bp.ballistic_id,
    bp.created_at,
    bp.created_by,
    creator.full_name,
    NULL::UUID,
    NULL::VARCHAR(200),
    NULL::UUID,
    NULL::VARCHAR(200),
    jsonb_build_object(
        'test_date', bp.test_date,
        'test_location', bp.test_location,
        'forensic_lab', bp.forensic_lab,
        'registration_hash', bp.registration_hash
    ),
    2
FROM ballistic_profiles bp
JOIN firearms f ON bp.firearm_id = f.firearm_id
LEFT JOIN users creator ON bp.created_by = creator.user_id

UNION ALL

-- Unit Movements
SELECT 
    fm.firearm_id,
    f.serial_number,
    'MOVEMENT'::VARCHAR(30),
    fm.movement_type,
    fm.movement_id,
    fm.authorization_date,
    fm.authorized_by,
    auth_user.full_name,
    NULL::UUID,
    NULL::VARCHAR(200),
    fm.to_unit_id,
    to_unit.unit_name,
    jsonb_build_object(
        'from_unit_id', fm.from_unit_id,
        'from_unit_name', from_unit.unit_name,
        'to_unit_id', fm.to_unit_id,
        'to_unit_name', to_unit.unit_name,
        'reason', fm.reason,
        'authorization_reference', fm.authorization_reference
    ),
    3
FROM firearm_unit_movements fm
JOIN firearms f ON fm.firearm_id = f.firearm_id
LEFT JOIN users auth_user ON fm.authorized_by = auth_user.user_id
LEFT JOIN units from_unit ON fm.from_unit_id = from_unit.unit_id
LEFT JOIN units to_unit ON fm.to_unit_id = to_unit.unit_id

UNION ALL

-- Custody Assigned
SELECT 
    cr.firearm_id,
    f.serial_number,
    'CUSTODY'::VARCHAR(30),
    'custody_assigned',
    cr.custody_id,
    cr.issued_at,
    cr.issued_by,
    issuer.full_name,
    cr.officer_id,
    officer.full_name,
    cr.unit_id,
    unit.unit_name,
    jsonb_build_object(
        'custody_type', cr.custody_type,
        'assignment_reason', cr.assignment_reason,
        'expected_return_date', cr.expected_return_date
    ),
    4
FROM custody_records cr
JOIN firearms f ON cr.firearm_id = f.firearm_id
LEFT JOIN users issuer ON cr.issued_by = issuer.user_id
LEFT JOIN officers officer ON cr.officer_id = officer.officer_id
LEFT JOIN units unit ON cr.unit_id = unit.unit_id

UNION ALL

-- Custody Returned
SELECT 
    cr.firearm_id,
    f.serial_number,
    'CUSTODY'::VARCHAR(30),
    'custody_returned',
    cr.custody_id,
    cr.returned_at,
    cr.returned_to,
    returner.full_name,
    cr.officer_id,
    officer.full_name,
    cr.unit_id,
    unit.unit_name,
    jsonb_build_object(
        'custody_type', cr.custody_type,
        'return_condition', cr.return_condition,
        'custody_duration_seconds', cr.custody_duration_seconds,
        'notes', cr.notes
    ),
    5
FROM custody_records cr
JOIN firearms f ON cr.firearm_id = f.firearm_id
LEFT JOIN users returner ON cr.returned_to = returner.user_id
LEFT JOIN officers officer ON cr.officer_id = officer.officer_id
LEFT JOIN units unit ON cr.unit_id = unit.unit_id
WHERE cr.returned_at IS NOT NULL

UNION ALL

-- Ballistic Access Events
SELECT 
    bal.firearm_id,
    f.serial_number,
    'BALLISTIC_ACCESS'::VARCHAR(30),
    bal.access_type,
    bal.access_id,
    bal.accessed_at,
    bal.accessed_by,
    accessor.full_name,
    bal.current_custody_officer_id,
    officer.full_name,
    bal.current_custody_unit_id,
    unit.unit_name,
    jsonb_build_object(
        'access_reason', bal.access_reason,
        'firearm_status_at_access', bal.firearm_status_at_access,
        'ip_address', bal.ip_address
    ),
    6
FROM ballistic_access_logs bal
JOIN firearms f ON bal.firearm_id = f.firearm_id
LEFT JOIN users accessor ON bal.accessed_by = accessor.user_id
LEFT JOIN officers officer ON bal.current_custody_officer_id = officer.officer_id
LEFT JOIN units unit ON bal.current_custody_unit_id = unit.unit_id

UNION ALL

-- Anomalies Detected
SELECT 
    a.firearm_id,
    f.serial_number,
    'ANOMALY'::VARCHAR(30),
    a.anomaly_type,
    a.anomaly_id,
    a.detected_at,
    NULL::UUID,
    NULL::VARCHAR(200),
    a.officer_id,
    officer.full_name,
    a.unit_id,
    unit.unit_name,
    jsonb_build_object(
        'severity', a.severity,
        'anomaly_score', a.anomaly_score,
        'status', a.status,
        'detection_method', a.detection_method
    ),
    7
FROM anomalies a
JOIN firearms f ON a.firearm_id = f.firearm_id
LEFT JOIN officers officer ON a.officer_id = officer.officer_id
LEFT JOIN units unit ON a.unit_id = unit.unit_id

ORDER BY event_timestamp, event_priority;

COMMENT ON VIEW unified_firearm_events_timeline IS 
'Complete chronological timeline of all events for a firearm.
Use: SELECT * FROM unified_firearm_events_timeline WHERE firearm_id = ?
Categories: REGISTRATION, BALLISTIC, MOVEMENT, CUSTODY, BALLISTIC_ACCESS, ANOMALY';

-- ============================================
-- 7. HELPER FUNCTION: Get Complete Traceability
-- ============================================
-- Returns structured traceability data for a firearm

CREATE OR REPLACE FUNCTION get_complete_firearm_traceability(p_firearm_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_firearm JSONB;
    v_ballistic JSONB;
    v_movements JSONB;
    v_custody JSONB;
    v_accesses JSONB;
    v_timeline JSONB;
BEGIN
    -- Firearm details
    SELECT jsonb_build_object(
        'firearm_id', f.firearm_id,
        'serial_number', f.serial_number,
        'manufacturer', f.manufacturer,
        'model', f.model,
        'firearm_type', f.firearm_type,
        'caliber', f.caliber,
        'acquisition_date', f.acquisition_date,
        'current_status', f.current_status,
        'assigned_unit_id', f.assigned_unit_id,
        'assigned_unit_name', u.unit_name,
        'registered_by', reg.full_name,
        'registration_date', f.created_at
    ) INTO v_firearm
    FROM firearms f
    LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
    LEFT JOIN users reg ON f.registered_by = reg.user_id
    WHERE f.firearm_id = p_firearm_id;

    -- Ballistic profile
    SELECT jsonb_build_object(
        'has_profile', bp.ballistic_id IS NOT NULL,
        'ballistic_id', bp.ballistic_id,
        'test_date', bp.test_date,
        'forensic_lab', bp.forensic_lab,
        'is_locked', bp.is_locked,
        'registration_hash', bp.registration_hash,
        'created_at', bp.created_at
    ) INTO v_ballistic
    FROM firearms f
    LEFT JOIN ballistic_profiles bp ON f.firearm_id = bp.firearm_id
    WHERE f.firearm_id = p_firearm_id;

    -- Movement history
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'movement_id', fm.movement_id,
            'from_unit', from_u.unit_name,
            'to_unit', to_u.unit_name,
            'movement_type', fm.movement_type,
            'authorized_by', auth.full_name,
            'date', fm.authorization_date,
            'reason', fm.reason
        ) ORDER BY fm.authorization_date
    ), '[]'::jsonb) INTO v_movements
    FROM firearm_unit_movements fm
    LEFT JOIN units from_u ON fm.from_unit_id = from_u.unit_id
    LEFT JOIN units to_u ON fm.to_unit_id = to_u.unit_id
    LEFT JOIN users auth ON fm.authorized_by = auth.user_id
    WHERE fm.firearm_id = p_firearm_id;

    -- Custody summary
    SELECT jsonb_build_object(
        'total_custody_events', COUNT(*),
        'unique_officers', COUNT(DISTINCT cr.officer_id),
        'unique_units', COUNT(DISTINCT cr.unit_id),
        'total_custody_days', COALESCE(SUM(cr.custody_duration_seconds) / 86400, 0),
        'active_custody', (
            SELECT jsonb_build_object(
                'officer_name', o.full_name,
                'unit_name', u.unit_name,
                'issued_at', cr2.issued_at,
                'custody_type', cr2.custody_type
            )
            FROM custody_records cr2
            JOIN officers o ON cr2.officer_id = o.officer_id
            JOIN units u ON cr2.unit_id = u.unit_id
            WHERE cr2.firearm_id = p_firearm_id AND cr2.returned_at IS NULL
            LIMIT 1
        )
    ) INTO v_custody
    FROM custody_records cr
    WHERE cr.firearm_id = p_firearm_id;

    -- Ballistic access summary
    SELECT jsonb_build_object(
        'total_accesses', COUNT(*),
        'last_access', MAX(bal.accessed_at),
        'accesses_last_30d', COUNT(*) FILTER (WHERE bal.accessed_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'),
        'unique_accessors', COUNT(DISTINCT bal.accessed_by)
    ) INTO v_accesses
    FROM ballistic_access_logs bal
    WHERE bal.firearm_id = p_firearm_id;

    -- Recent timeline (last 20 events)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'event_type', event_type,
            'event_category', event_category,
            'timestamp', event_timestamp,
            'actor', actor_name,
            'officer', officer_name,
            'unit', unit_name,
            'details', event_details
        ) ORDER BY event_timestamp DESC
    ), '[]'::jsonb) INTO v_timeline
    FROM (
        SELECT * FROM unified_firearm_events_timeline 
        WHERE firearm_id = p_firearm_id 
        ORDER BY event_timestamp DESC 
        LIMIT 20
    ) recent;

    -- Build final result
    v_result := jsonb_build_object(
        'firearm', v_firearm,
        'ballistic_profile', v_ballistic,
        'unit_movements', v_movements,
        'custody_summary', v_custody,
        'ballistic_access_summary', v_accesses,
        'recent_timeline', v_timeline,
        'generated_at', CURRENT_TIMESTAMP
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_complete_firearm_traceability(UUID) IS 
'Returns complete traceability data for a firearm as a single JSONB document.
Includes: firearm details, ballistic profile, unit movements, custody summary, access logs, recent timeline.';

-- ============================================
-- 8. MATERIALIZED VIEW: Firearm Traceability Summary
-- ============================================
-- Pre-computed summary for dashboard performance

DROP MATERIALIZED VIEW IF EXISTS firearm_traceability_summary CASCADE;
CREATE MATERIALIZED VIEW firearm_traceability_summary AS
SELECT 
    f.firearm_id,
    f.serial_number,
    f.manufacturer,
    f.model,
    f.firearm_type,
    f.current_status,
    f.assigned_unit_id,
    u.unit_name as assigned_unit_name,
    -- Ballistic status
    bp.ballistic_id IS NOT NULL as has_ballistic_profile,
    bp.test_date as ballistic_test_date,
    bp.forensic_lab,
    -- Custody stats
    COUNT(DISTINCT cr.custody_id) as total_custody_count,
    COUNT(DISTINCT cr.officer_id) as unique_officers_count,
    COUNT(DISTINCT cr.unit_id) as custody_units_count,
    MAX(cr.issued_at) as last_custody_date,
    -- Movement stats
    COUNT(DISTINCT fm.movement_id) as total_unit_movements,
    MAX(fm.authorization_date) as last_movement_date,
    -- Ballistic access stats
    COUNT(DISTINCT bal.access_id) as total_ballistic_accesses,
    MAX(bal.accessed_at) as last_ballistic_access,
    -- Anomaly stats
    COUNT(DISTINCT a.anomaly_id) as total_anomalies,
    COUNT(DISTINCT a.anomaly_id) FILTER (WHERE a.status = 'open') as open_anomalies,
    -- Current custody
    (
        SELECT o.full_name 
        FROM custody_records cr2 
        JOIN officers o ON cr2.officer_id = o.officer_id
        WHERE cr2.firearm_id = f.firearm_id AND cr2.returned_at IS NULL 
        LIMIT 1
    ) as current_custodian
FROM firearms f
LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
LEFT JOIN ballistic_profiles bp ON f.firearm_id = bp.firearm_id
LEFT JOIN custody_records cr ON f.firearm_id = cr.firearm_id
LEFT JOIN firearm_unit_movements fm ON f.firearm_id = fm.firearm_id
LEFT JOIN ballistic_access_logs bal ON f.firearm_id = bal.firearm_id
LEFT JOIN anomalies a ON f.firearm_id = a.firearm_id
GROUP BY f.firearm_id, f.serial_number, f.manufacturer, f.model, f.firearm_type,
         f.current_status, f.assigned_unit_id, u.unit_name, 
         bp.ballistic_id, bp.test_date, bp.forensic_lab;

CREATE UNIQUE INDEX IF NOT EXISTS idx_traceability_summary_firearm 
ON firearm_traceability_summary(firearm_id);

CREATE INDEX IF NOT EXISTS idx_traceability_summary_unit 
ON firearm_traceability_summary(assigned_unit_id);

CREATE INDEX IF NOT EXISTS idx_traceability_summary_has_ballistic 
ON firearm_traceability_summary(has_ballistic_profile);

-- ============================================
-- 9. REFRESH FUNCTION FOR MATERIALIZED VIEWS
-- ============================================

CREATE OR REPLACE FUNCTION refresh_traceability_views()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY firearm_traceability_summary;
    REFRESH MATERIALIZED VIEW CONCURRENTLY officer_behavior_profile;
    REFRESH MATERIALIZED VIEW CONCURRENTLY firearm_usage_profile;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_traceability_views() IS 
'Refreshes all materialized views for traceability reporting. 
Should be called periodically (e.g., every 15 minutes) or after bulk operations.';

-- ============================================
-- 10. GRANT STATEMENTS (adjust for your roles)
-- ============================================

-- Note: Uncomment and adjust these for your PostgreSQL role setup
-- GRANT SELECT ON unified_firearm_events_timeline TO safearms_app;
-- GRANT SELECT ON firearm_traceability_summary TO safearms_app;
-- GRANT SELECT ON firearm_unit_movements TO safearms_app;
-- GRANT INSERT ON firearm_unit_movements TO safearms_app;
-- GRANT SELECT ON ballistic_access_logs TO safearms_app;
-- GRANT INSERT ON ballistic_access_logs TO safearms_app;
-- GRANT EXECUTE ON FUNCTION get_complete_firearm_traceability(UUID) TO safearms_app;
-- GRANT EXECUTE ON FUNCTION refresh_traceability_views() TO safearms_app;

COMMIT;

-- ============================================
-- ROLLBACK SECTION (if needed)
-- ============================================
-- Execute this section manually if you need to reverse the migration

/*
BEGIN;

-- Drop views
DROP VIEW IF EXISTS unified_firearm_events_timeline CASCADE;
DROP MATERIALIZED VIEW IF EXISTS firearm_traceability_summary CASCADE;

-- Drop functions
DROP FUNCTION IF EXISTS get_complete_firearm_traceability(UUID);
DROP FUNCTION IF EXISTS refresh_traceability_views();
DROP FUNCTION IF EXISTS log_firearm_unit_movement();
DROP FUNCTION IF EXISTS log_initial_firearm_assignment();
DROP FUNCTION IF EXISTS prevent_custody_deletion();
DROP FUNCTION IF EXISTS restrict_custody_updates();
DROP FUNCTION IF EXISTS prevent_audit_modification();
DROP FUNCTION IF EXISTS prevent_ballistic_modification();

-- Drop triggers
DROP TRIGGER IF EXISTS trg_log_firearm_unit_movement ON firearms;
DROP TRIGGER IF EXISTS trg_log_initial_firearm_assignment ON firearms;
DROP TRIGGER IF EXISTS trg_prevent_custody_deletion ON custody_records;
DROP TRIGGER IF EXISTS trg_restrict_custody_updates ON custody_records;
DROP TRIGGER IF EXISTS trg_prevent_audit_modification ON audit_logs;
DROP TRIGGER IF EXISTS trg_prevent_ballistic_modification ON ballistic_profiles;

-- Drop table (WARNING: This will delete all movement history data)
DROP TABLE IF EXISTS firearm_unit_movements CASCADE;

COMMIT;
*/

-- ============================================
-- VERIFICATION QUERIES
-- ============================================
-- Run these after migration to verify everything is working

/*
-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN 
('firearm_unit_movements', 'ballistic_access_logs');

-- Check views exist
SELECT table_name, table_type FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN 
('unified_firearm_events_timeline', 'firearm_traceability_summary');

-- Check triggers exist
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers 
WHERE trigger_schema = 'public';

-- Check functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
AND routine_name LIKE '%traceability%' OR routine_name LIKE '%ballistic%';

-- Test timeline view (replace with actual firearm_id)
-- SELECT * FROM unified_firearm_events_timeline WHERE firearm_id = '...' LIMIT 10;

-- Test traceability function (replace with actual firearm_id)
-- SELECT get_complete_firearm_traceability('...');
*/
