-- SafeArms Database Migration: Forensic Traceability Integration
-- Version: 1.1.0
-- Purpose: Integrate ballistic records into firearm chain-of-custody model
--
-- CONSTRAINTS:
-- - Ballistic profiles are immutable after creation (forensic integrity)
-- - All ballistic access events are logged and auditable
-- - Chain-of-custody integrity is legally critical
-- - No forensic analysis or matching capabilities

-- ============================================
-- BALLISTIC ACCESS LOGS TABLE
-- ============================================
-- Tracks every access to ballistic profile data
-- Required for forensic traceability and compliance

CREATE TABLE IF NOT EXISTS ballistic_access_logs (
    access_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ballistic_id UUID NOT NULL REFERENCES ballistic_profiles(ballistic_id),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    accessed_by UUID NOT NULL REFERENCES users(user_id),
    access_type VARCHAR(50) NOT NULL CHECK (access_type IN (
        'view_profile',
        'view_custody_chain', 
        'export_data',
        'forensic_query',
        'traceability_report'
    )),
    access_reason TEXT,
    -- Context at time of access
    firearm_status_at_access VARCHAR(50),
    current_custody_officer_id UUID REFERENCES officers(officer_id),
    current_custody_unit_id UUID REFERENCES units(unit_id),
    -- Request metadata
    ip_address VARCHAR(50),
    user_agent TEXT,
    -- Timestamps
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- FIREARM TRACEABILITY VIEW
-- ============================================
-- Unified view combining custody + ballistic data for traceability
-- READ-ONLY forensic view - no analysis or interpretation

CREATE OR REPLACE VIEW firearm_traceability_timeline AS
SELECT 
    f.firearm_id,
    f.serial_number,
    f.manufacturer,
    f.model,
    f.firearm_type,
    f.caliber,
    f.acquisition_date,
    f.current_status,
    f.assigned_unit_id,
    -- Ballistic profile info (if exists)
    bp.ballistic_id,
    bp.test_date as ballistic_test_date,
    bp.test_location as ballistic_test_location,
    bp.forensic_lab,
    CASE WHEN bp.ballistic_id IS NOT NULL THEN true ELSE false END as has_ballistic_profile,
    -- Current custody info
    active_custody.custody_id as current_custody_id,
    active_custody.officer_id as current_officer_id,
    active_custody.officer_name as current_officer_name,
    active_custody.unit_id as current_unit_id,
    active_custody.unit_name as current_unit_name,
    active_custody.issued_at as custody_start_date,
    active_custody.custody_type,
    -- Summary stats
    (SELECT COUNT(*) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) as total_custody_events,
    (SELECT COUNT(DISTINCT cr.unit_id) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) as units_transferred_to,
    (SELECT COUNT(*) FROM ballistic_access_logs bal WHERE bal.firearm_id = f.firearm_id) as total_ballistic_accesses
FROM firearms f
LEFT JOIN ballistic_profiles bp ON f.firearm_id = bp.firearm_id
LEFT JOIN LATERAL (
    SELECT 
        cr.custody_id,
        cr.officer_id,
        o.full_name as officer_name,
        cr.unit_id,
        u.unit_name,
        cr.issued_at,
        cr.custody_type
    FROM custody_records cr
    JOIN officers o ON cr.officer_id = o.officer_id
    JOIN units u ON cr.unit_id = u.unit_id
    WHERE cr.firearm_id = f.firearm_id 
    AND cr.returned_at IS NULL
    ORDER BY cr.issued_at DESC
    LIMIT 1
) active_custody ON true;

-- ============================================
-- CUSTODY CHAIN TIMELINE VIEW
-- ============================================
-- Complete chronological custody history for a firearm
-- Used for forensic traceability reports

CREATE OR REPLACE VIEW custody_chain_timeline AS
SELECT 
    cr.custody_id,
    cr.firearm_id,
    f.serial_number,
    cr.officer_id,
    o.full_name as officer_name,
    o.rank as officer_rank,
    o.officer_number,
    cr.unit_id,
    u.unit_name,
    u.unit_type,
    cr.custody_type,
    cr.issued_at,
    cr.returned_at,
    cr.custody_duration_seconds,
    cr.issued_by,
    issued_user.full_name as issued_by_name,
    cr.returned_to,
    returned_user.full_name as returned_to_name,
    cr.assignment_reason,
    cr.return_condition,
    cr.notes,
    -- Calculate if this was a cross-unit transfer
    LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at) as previous_unit_id,
    CASE 
        WHEN LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at) IS NOT NULL 
        AND LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at) != cr.unit_id 
        THEN true 
        ELSE false 
    END as is_cross_unit_transfer,
    -- Row number for timeline ordering
    ROW_NUMBER() OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at) as custody_sequence
FROM custody_records cr
JOIN firearms f ON cr.firearm_id = f.firearm_id
JOIN officers o ON cr.officer_id = o.officer_id
JOIN units u ON cr.unit_id = u.unit_id
LEFT JOIN users issued_user ON cr.issued_by = issued_user.user_id
LEFT JOIN users returned_user ON cr.returned_to = returned_user.user_id
ORDER BY cr.firearm_id, cr.issued_at;

-- ============================================
-- ADD IMMUTABILITY MARKERS TO BALLISTIC PROFILES
-- ============================================
-- Add columns to enforce and track immutability

ALTER TABLE ballistic_profiles 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(user_id),
ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT true,
ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN IF NOT EXISTS locked_by UUID REFERENCES users(user_id),
ADD COLUMN IF NOT EXISTS registration_hash VARCHAR(64);

-- Comment explaining immutability
COMMENT ON COLUMN ballistic_profiles.is_locked IS 'Ballistic profiles are immutable after creation. This flag is always true.';
COMMENT ON COLUMN ballistic_profiles.registration_hash IS 'SHA-256 hash of profile data at creation for integrity verification';

-- ============================================
-- ADD BALLISTIC REFERENCE TO ML FEATURES
-- ============================================
-- Include ballistic access context in anomaly detection

ALTER TABLE ml_training_features
ADD COLUMN IF NOT EXISTS has_ballistic_profile BOOLEAN DEFAULT false,
ADD COLUMN IF NOT EXISTS ballistic_accesses_7d INTEGER DEFAULT 0;

-- ============================================
-- INDEXES FOR PERFORMANCE
-- ============================================

-- Ballistic access logs indexes
CREATE INDEX IF NOT EXISTS idx_ballistic_access_ballistic ON ballistic_access_logs(ballistic_id);
CREATE INDEX IF NOT EXISTS idx_ballistic_access_firearm ON ballistic_access_logs(firearm_id);
CREATE INDEX IF NOT EXISTS idx_ballistic_access_user ON ballistic_access_logs(accessed_by);
CREATE INDEX IF NOT EXISTS idx_ballistic_access_type ON ballistic_access_logs(access_type);
CREATE INDEX IF NOT EXISTS idx_ballistic_access_time ON ballistic_access_logs(accessed_at);

-- Composite index for traceability queries
CREATE INDEX IF NOT EXISTS idx_custody_firearm_time ON custody_records(firearm_id, issued_at DESC);

-- ============================================
-- FUNCTION: Log Ballistic Access
-- ============================================
-- Automatically logs access to ballistic profiles

CREATE OR REPLACE FUNCTION log_ballistic_access(
    p_ballistic_id UUID,
    p_user_id UUID,
    p_access_type VARCHAR(50),
    p_access_reason TEXT DEFAULT NULL,
    p_ip_address VARCHAR(50) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_firearm_id UUID;
    v_firearm_status VARCHAR(50);
    v_current_officer_id UUID;
    v_current_unit_id UUID;
    v_access_id UUID;
BEGIN
    -- Get firearm info from ballistic profile
    SELECT bp.firearm_id, f.current_status
    INTO v_firearm_id, v_firearm_status
    FROM ballistic_profiles bp
    JOIN firearms f ON bp.firearm_id = f.firearm_id
    WHERE bp.ballistic_id = p_ballistic_id;

    -- Get current custody info if any
    SELECT cr.officer_id, cr.unit_id
    INTO v_current_officer_id, v_current_unit_id
    FROM custody_records cr
    WHERE cr.firearm_id = v_firearm_id
    AND cr.returned_at IS NULL
    ORDER BY cr.issued_at DESC
    LIMIT 1;

    -- Insert access log
    INSERT INTO ballistic_access_logs (
        ballistic_id, firearm_id, accessed_by, access_type, access_reason,
        firearm_status_at_access, current_custody_officer_id, current_custody_unit_id,
        ip_address, user_agent
    ) VALUES (
        p_ballistic_id, v_firearm_id, p_user_id, p_access_type, p_access_reason,
        v_firearm_status, v_current_officer_id, v_current_unit_id,
        p_ip_address, p_user_agent
    ) RETURNING access_id INTO v_access_id;

    RETURN v_access_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Generate Traceability Report
-- ============================================
-- Returns complete chain of custody with ballistic context

CREATE OR REPLACE FUNCTION get_firearm_traceability(p_firearm_id UUID)
RETURNS TABLE (
    event_type VARCHAR(50),
    event_id UUID,
    event_timestamp TIMESTAMP,
    event_description TEXT,
    unit_id UUID,
    unit_name VARCHAR(200),
    officer_id UUID,
    officer_name VARCHAR(200),
    user_id UUID,
    user_name VARCHAR(200)
) AS $$
BEGIN
    RETURN QUERY
    -- Firearm registration event
    SELECT 
        'firearm_registered'::VARCHAR(50) as event_type,
        f.firearm_id as event_id,
        f.created_at as event_timestamp,
        CONCAT('Firearm registered: ', f.serial_number, ' (', f.manufacturer, ' ', f.model, ')') as event_description,
        f.assigned_unit_id as unit_id,
        u.unit_name,
        NULL::UUID as officer_id,
        NULL::VARCHAR(200) as officer_name,
        f.registered_by as user_id,
        reg_user.full_name as user_name
    FROM firearms f
    LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
    LEFT JOIN users reg_user ON f.registered_by = reg_user.user_id
    WHERE f.firearm_id = p_firearm_id

    UNION ALL

    -- Ballistic profile creation event
    SELECT 
        'ballistic_profile_created'::VARCHAR(50),
        bp.ballistic_id,
        bp.created_at,
        CONCAT('Ballistic profile created at ', bp.forensic_lab),
        NULL::UUID,
        NULL::VARCHAR(200),
        NULL::UUID,
        NULL::VARCHAR(200),
        bp.created_by,
        creator.full_name
    FROM ballistic_profiles bp
    LEFT JOIN users creator ON bp.created_by = creator.user_id
    WHERE bp.firearm_id = p_firearm_id

    UNION ALL

    -- Custody assignment events
    SELECT 
        'custody_assigned'::VARCHAR(50),
        cr.custody_id,
        cr.issued_at,
        CONCAT('Assigned to ', o.full_name, ' (', o.rank, ')'),
        cr.unit_id,
        unit.unit_name,
        cr.officer_id,
        o.full_name,
        cr.issued_by,
        issuer.full_name
    FROM custody_records cr
    JOIN officers o ON cr.officer_id = o.officer_id
    JOIN units unit ON cr.unit_id = unit.unit_id
    LEFT JOIN users issuer ON cr.issued_by = issuer.user_id
    WHERE cr.firearm_id = p_firearm_id

    UNION ALL

    -- Custody return events
    SELECT 
        'custody_returned'::VARCHAR(50),
        cr.custody_id,
        cr.returned_at,
        CONCAT('Returned by ', o.full_name, ' - Condition: ', COALESCE(cr.return_condition, 'Not specified')),
        cr.unit_id,
        unit.unit_name,
        cr.officer_id,
        o.full_name,
        cr.returned_to,
        returner.full_name
    FROM custody_records cr
    JOIN officers o ON cr.officer_id = o.officer_id
    JOIN units unit ON cr.unit_id = unit.unit_id
    LEFT JOIN users returner ON cr.returned_to = returner.user_id
    WHERE cr.firearm_id = p_firearm_id AND cr.returned_at IS NOT NULL

    UNION ALL

    -- Ballistic access events
    SELECT 
        'ballistic_accessed'::VARCHAR(50),
        bal.access_id,
        bal.accessed_at,
        CONCAT('Ballistic profile accessed: ', bal.access_type),
        bal.current_custody_unit_id,
        access_unit.unit_name,
        bal.current_custody_officer_id,
        access_officer.full_name,
        bal.accessed_by,
        accessor.full_name
    FROM ballistic_access_logs bal
    LEFT JOIN units access_unit ON bal.current_custody_unit_id = access_unit.unit_id
    LEFT JOIN officers access_officer ON bal.current_custody_officer_id = access_officer.officer_id
    LEFT JOIN users accessor ON bal.accessed_by = accessor.user_id
    WHERE bal.firearm_id = p_firearm_id

    ORDER BY event_timestamp;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- RBAC: Restrict ballistic access by role
-- ============================================
-- Note: Actual enforcement is in application middleware
-- This comment documents the policy

COMMENT ON TABLE ballistic_access_logs IS 
'Tracks all access to ballistic profile data. 
RBAC Policy:
- forensic_analyst: Full read access to all ballistic profiles
- hq_firearm_commander: Read access to all ballistic profiles  
- station_commander: Read access ONLY to firearms assigned to their unit
- admin: Read access for audit purposes only';

COMMENT ON TABLE ballistic_profiles IS
'Ballistic profiles are IMMUTABLE after creation.
- Created during firearm registration by HQ Commander
- Cannot be updated or deleted (forensic integrity)
- All access is logged to ballistic_access_logs';
