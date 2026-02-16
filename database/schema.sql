-- SafeArms Database Schema (Consolidated for Demonstration)
-- PostgreSQL 14+
-- Police Firearm Control and Investigation Support Platform
-- Rwanda National Police
--
-- This is a consolidated schema for demonstration purposes.
-- All tables, views, functions, and triggers in a single file.

-- ============================================
-- DROP EXISTING OBJECTS (Clean Start)
-- ============================================
DROP MATERIALIZED VIEW IF EXISTS firearm_usage_profile CASCADE;
DROP MATERIALIZED VIEW IF EXISTS officer_behavior_profile CASCADE;
DROP VIEW IF EXISTS unified_firearm_events_timeline CASCADE;
DROP TABLE IF EXISTS anomaly_investigations CASCADE;
DROP TABLE IF EXISTS anomalies CASCADE;
DROP TABLE IF EXISTS ml_training_features CASCADE;
DROP TABLE IF EXISTS ml_model_metadata CASCADE;
DROP TABLE IF EXISTS procurement_requests CASCADE;
DROP TABLE IF EXISTS destruction_requests CASCADE;
DROP TABLE IF EXISTS loss_reports CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS ballistic_access_logs CASCADE;
DROP TABLE IF EXISTS firearm_unit_movements CASCADE;
DROP TABLE IF EXISTS custody_records CASCADE;
DROP TABLE IF EXISTS ballistic_profiles CASCADE;
DROP TABLE IF EXISTS firearms CASCADE;
DROP TABLE IF EXISTS officers CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS units CASCADE;

-- ============================================
-- IMPORTANT: USER vs OFFICER SEPARATION
-- ============================================
-- USERS: System users who authenticate and manage the platform
--        (Admin, HQ Commander, Station Commander, Investigator)
--        - Have username, password, roles
--        - Can log in and perform system operations
--
-- OFFICERS: Police officers who receive firearm custody
--        - NO authentication credentials (cannot log in)
--        - NO roles (not system users)
--        - Referenced in custody_records for firearm assignments
--        - Managed by Station Commanders within their unit
-- ============================================

-- ============================================
-- CORE TABLES
-- ============================================

-- Units Table (User-friendly IDs)
CREATE TABLE units (
    unit_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'UNIT-001', 'UNIT-HQ'
    unit_name VARCHAR(200) NOT NULL UNIQUE,
    unit_type VARCHAR(50) NOT NULL CHECK (unit_type IN ('headquarters', 'district', 'station', 'specialized')),
    location VARCHAR(200),
    province VARCHAR(100),
    district VARCHAR(100),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(100),
    commander_name VARCHAR(200),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Users Table
CREATE TABLE users (
    user_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'USR-001'
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'hq_firearm_commander', 'station_commander', 'investigator')),
    unit_id VARCHAR(20) REFERENCES units(unit_id),
    otp_code VARCHAR(6),
    otp_expires_at TIMESTAMP,
    otp_attempts INTEGER DEFAULT 0,
    otp_verified BOOLEAN DEFAULT false,
    unit_confirmed BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    must_change_password BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_by VARCHAR(20) REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Officers Table
CREATE TABLE officers (
    officer_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'OFF-001'
    officer_number VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(200) NOT NULL,
    rank VARCHAR(100) NOT NULL,
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    phone_number VARCHAR(20),
    email VARCHAR(100),
    date_of_birth DATE,
    employment_date DATE,
    firearm_certified BOOLEAN DEFAULT false,
    certification_date DATE,
    certification_expiry DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Firearms Table
CREATE TABLE firearms (
    firearm_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'FA-001'
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    manufacturer VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    firearm_type VARCHAR(50) NOT NULL CHECK (firearm_type IN ('pistol', 'rifle', 'shotgun', 'submachine_gun', 'other')),
    caliber VARCHAR(50),
    manufacture_year INTEGER,
    acquisition_date DATE NOT NULL,
    acquisition_source VARCHAR(200),
    registration_level VARCHAR(10) NOT NULL CHECK (registration_level IN ('hq', 'unit')),
    registered_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    assigned_unit_id VARCHAR(20) REFERENCES units(unit_id),
    current_status VARCHAR(50) DEFAULT 'available' CHECK (current_status IN ('unassigned', 'available', 'in_custody', 'maintenance', 'lost', 'stolen', 'destroyed')),
    notes TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ballistic Profiles Table (IMMUTABLE after creation)
CREATE TABLE ballistic_profiles (
    ballistic_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'BP-001'
    firearm_id VARCHAR(20) NOT NULL UNIQUE REFERENCES firearms(firearm_id),
    test_date DATE DEFAULT CURRENT_DATE,
    test_location VARCHAR(200),
    rifling_characteristics TEXT,
    firing_pin_impression TEXT,
    ejector_marks TEXT,
    extractor_marks TEXT,
    chamber_marks TEXT,
    test_conducted_by VARCHAR(200),
    forensic_lab VARCHAR(200),
    test_ammunition VARCHAR(200),
    notes TEXT,
    created_by VARCHAR(20) REFERENCES users(user_id),
    is_locked BOOLEAN DEFAULT true,
    locked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    locked_by VARCHAR(20) REFERENCES users(user_id),
    registration_hash VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Custody Records Table
CREATE TABLE custody_records (
    custody_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'CUS-001'
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    custody_type VARCHAR(50) NOT NULL CHECK (custody_type IN ('permanent', 'temporary', 'personal_long_term')),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    issued_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    expected_return_date DATE,
    returned_at TIMESTAMP,
    returned_to VARCHAR(20) REFERENCES users(user_id),
    return_condition VARCHAR(50) CHECK (return_condition IN ('good', 'fair', 'needs_maintenance', 'damaged')),
    assignment_reason TEXT,
    notes TEXT,
    -- ML Feature Fields
    custody_duration_seconds INTEGER,
    issue_hour INTEGER,
    issue_day_of_week INTEGER,
    is_night_issue BOOLEAN,
    is_weekend_issue BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Firearm Unit Movements Table
CREATE TABLE firearm_unit_movements (
    movement_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'MOV-001'
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    from_unit_id VARCHAR(20) REFERENCES units(unit_id),
    to_unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    movement_type VARCHAR(50) NOT NULL CHECK (movement_type IN (
        'initial_assignment', 'transfer', 'reassignment', 'temporary_loan', 'return_from_loan'
    )),
    authorized_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    authorization_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    authorization_reference VARCHAR(100),
    reason TEXT,
    custody_record_id VARCHAR(20) REFERENCES custody_records(custody_id),
    ip_address VARCHAR(50),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ballistic Access Logs Table
CREATE TABLE ballistic_access_logs (
    access_id VARCHAR(20) PRIMARY KEY,  -- e.g., 'BAL-001'
    ballistic_id VARCHAR(20) NOT NULL REFERENCES ballistic_profiles(ballistic_id),
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    accessed_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    access_type VARCHAR(50) NOT NULL CHECK (access_type IN (
        'view_profile', 'view_custody_chain', 'export_data', 'forensic_query', 'traceability_report'
    )),
    access_reason TEXT,
    firearm_status_at_access VARCHAR(50),
    current_custody_officer_id VARCHAR(20) REFERENCES officers(officer_id),
    current_custody_unit_id VARCHAR(20) REFERENCES units(unit_id),
    ip_address VARCHAR(50),
    user_agent TEXT,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- ML SYSTEM TABLES
-- ============================================

-- ML Training Features Table
CREATE TABLE ml_training_features (
    feature_id VARCHAR(20) PRIMARY KEY,
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id),
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    custody_record_id VARCHAR(20) NOT NULL REFERENCES custody_records(custody_id),
    custody_duration_seconds INTEGER,
    issue_hour INTEGER,
    issue_day_of_week INTEGER,
    is_night_issue BOOLEAN,
    is_weekend_issue BOOLEAN,
    officer_issue_frequency_30d DECIMAL(10,2),
    officer_avg_custody_duration_30d DECIMAL(10,2),
    firearm_exchange_rate_7d DECIMAL(10,2),
    officer_unit_consistency_score DECIMAL(5,2),
    time_since_last_return_seconds INTEGER,
    consecutive_same_firearm_count INTEGER,
    cross_unit_movement_flag BOOLEAN,
    rapid_exchange_flag BOOLEAN,
    custody_duration_zscore DECIMAL(10,4),
    issue_frequency_zscore DECIMAL(10,4),
    has_ballistic_profile BOOLEAN DEFAULT false,
    ballistic_accesses_7d INTEGER DEFAULT 0,
    feature_extraction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ML Model Metadata Table
CREATE TABLE ml_model_metadata (
    model_id VARCHAR(20) PRIMARY KEY,
    model_type VARCHAR(50) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    training_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    training_samples_count INTEGER,
    num_clusters INTEGER,
    cluster_centers JSONB,
    silhouette_score DECIMAL(5,4),
    outlier_threshold DECIMAL(10,4),
    normalization_params JSONB,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Anomalies Table
CREATE TABLE anomalies (
    anomaly_id VARCHAR(20) PRIMARY KEY,
    custody_record_id VARCHAR(20) NOT NULL REFERENCES custody_records(custody_id),
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    anomaly_score DECIMAL(5,3) NOT NULL,
    anomaly_type VARCHAR(100) NOT NULL,
    detection_method VARCHAR(50) NOT NULL,
    model_id VARCHAR(20) REFERENCES ml_model_metadata(model_id),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    confidence_level DECIMAL(5,3),
    contributing_factors JSONB,
    feature_importance JSONB,
    is_mandatory_review BOOLEAN DEFAULT false,
    event_context JSONB,
    ballistic_access_context JSONB,
    status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'pending', 'investigating', 'resolved', 'false_positive')),
    investigated_by VARCHAR(20) REFERENCES users(user_id),
    investigation_notes TEXT,
    resolution_date TIMESTAMP,
    auto_notification_sent BOOLEAN DEFAULT false,
    notification_sent_at TIMESTAMP,
    notified_users JSONB,
    detected_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Anomaly Investigations Table
CREATE TABLE anomaly_investigations (
    investigation_id VARCHAR(20) PRIMARY KEY,
    anomaly_id VARCHAR(20) NOT NULL REFERENCES anomalies(anomaly_id),
    investigator_id VARCHAR(20) NOT NULL REFERENCES users(user_id),
    investigation_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    findings TEXT,
    action_taken TEXT,
    outcome VARCHAR(50) CHECK (outcome IN ('confirmed', 'false_positive', 'needs_further_review')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- WORKFLOW TABLES
-- ============================================

-- Loss Reports Table
CREATE TABLE loss_reports (
    loss_id VARCHAR(20) PRIMARY KEY,
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    reported_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    officer_id VARCHAR(20) REFERENCES officers(officer_id),
    loss_type VARCHAR(50) NOT NULL CHECK (loss_type IN ('lost', 'stolen')),
    loss_date DATE NOT NULL,
    loss_location VARCHAR(200),
    circumstances TEXT NOT NULL,
    police_case_number VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'under_investigation')),
    reviewed_by VARCHAR(20) REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Destruction Requests Table
CREATE TABLE destruction_requests (
    destruction_id VARCHAR(20) PRIMARY KEY,
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    requested_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    destruction_reason TEXT NOT NULL,
    condition_description TEXT,
    supporting_documents TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by VARCHAR(20) REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    actual_destruction_date DATE,
    destruction_method VARCHAR(100),
    witnesses TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Procurement Requests Table
CREATE TABLE procurement_requests (
    procurement_id VARCHAR(20) PRIMARY KEY,
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    requested_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    firearm_type VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    justification TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'routine' CHECK (priority IN ('urgent', 'high', 'routine')),
    estimated_cost DECIMAL(15,2),
    preferred_supplier VARCHAR(200),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by VARCHAR(20) REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- AUDIT TABLE
-- ============================================

CREATE TABLE audit_logs (
    log_id VARCHAR(20) PRIMARY KEY,
    user_id VARCHAR(20) REFERENCES users(user_id),
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    reason TEXT,
    actor_role VARCHAR(50),
    actor_unit_name VARCHAR(100),
    subject_type VARCHAR(100),
    subject_id VARCHAR(50),
    is_chain_of_custody_event BOOLEAN DEFAULT false,
    ip_address VARCHAR(50),
    user_agent TEXT,
    success BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- INDEXES
-- ============================================

-- Users
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_unit ON users(unit_id);

-- Officers
CREATE INDEX idx_officers_number ON officers(officer_number);
CREATE INDEX idx_officers_unit ON officers(unit_id);
CREATE INDEX idx_officers_active ON officers(is_active);

-- Firearms
CREATE INDEX idx_firearms_serial ON firearms(serial_number);
CREATE INDEX idx_firearms_unit ON firearms(assigned_unit_id);
CREATE INDEX idx_firearms_status ON firearms(current_status);
CREATE INDEX idx_firearms_type ON firearms(firearm_type);

-- Custody Records
CREATE INDEX idx_custody_firearm ON custody_records(firearm_id);
CREATE INDEX idx_custody_officer ON custody_records(officer_id);
CREATE INDEX idx_custody_unit ON custody_records(unit_id);
CREATE INDEX idx_custody_issued_at ON custody_records(issued_at);
CREATE INDEX idx_custody_returned_at ON custody_records(returned_at);
CREATE INDEX idx_custody_firearm_time ON custody_records(firearm_id, issued_at DESC);

-- Anomalies
CREATE INDEX idx_anomalies_firearm ON anomalies(firearm_id);
CREATE INDEX idx_anomalies_officer ON anomalies(officer_id);
CREATE INDEX idx_anomalies_unit ON anomalies(unit_id);
CREATE INDEX idx_anomalies_severity ON anomalies(severity);
CREATE INDEX idx_anomalies_status ON anomalies(status);
CREATE INDEX idx_anomalies_detected_at ON anomalies(detected_at);

-- ML Features
CREATE INDEX idx_ml_features_officer ON ml_training_features(officer_id);
CREATE INDEX idx_ml_features_firearm ON ml_training_features(firearm_id);
CREATE INDEX idx_ml_features_date ON ml_training_features(feature_extraction_date);

-- Audit Logs
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_action ON audit_logs(action_type);
CREATE INDEX idx_audit_created ON audit_logs(created_at);

-- Workflows
CREATE INDEX idx_loss_status ON loss_reports(status);
CREATE INDEX idx_destruction_status ON destruction_requests(status);
CREATE INDEX idx_procurement_status ON procurement_requests(status);

-- Ballistic Access Logs
CREATE INDEX idx_ballistic_access_ballistic ON ballistic_access_logs(ballistic_id);
CREATE INDEX idx_ballistic_access_firearm ON ballistic_access_logs(firearm_id);
CREATE INDEX idx_ballistic_access_user ON ballistic_access_logs(accessed_by);
CREATE INDEX idx_ballistic_access_type ON ballistic_access_logs(access_type);
CREATE INDEX idx_ballistic_access_time ON ballistic_access_logs(accessed_at);

-- Firearm Unit Movements
CREATE INDEX idx_unit_movements_firearm ON firearm_unit_movements(firearm_id);
CREATE INDEX idx_unit_movements_from_unit ON firearm_unit_movements(from_unit_id);
CREATE INDEX idx_unit_movements_to_unit ON firearm_unit_movements(to_unit_id);
CREATE INDEX idx_unit_movements_date ON firearm_unit_movements(authorization_date);

-- ============================================
-- ID GENERATION SEQUENCES & FUNCTIONS
-- ============================================

-- Sequence-based ID generators for tables whose models don't generate PKs
CREATE SEQUENCE IF NOT EXISTS firearms_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS loss_reports_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS destruction_requests_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS procurement_requests_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS audit_logs_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS ballistic_access_id_seq START 1;

-- Auto-generate firearm_id if not provided
CREATE OR REPLACE FUNCTION generate_firearm_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.firearm_id IS NULL OR NEW.firearm_id = '' THEN
        NEW.firearm_id := 'FA-' || LPAD(nextval('firearms_id_seq')::TEXT, 3, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_loss_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.loss_id IS NULL OR NEW.loss_id = '' THEN
        NEW.loss_id := 'LOSS-' || LPAD(nextval('loss_reports_id_seq')::TEXT, 3, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_destruction_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.destruction_id IS NULL OR NEW.destruction_id = '' THEN
        NEW.destruction_id := 'DEST-' || LPAD(nextval('destruction_requests_id_seq')::TEXT, 3, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_procurement_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.procurement_id IS NULL OR NEW.procurement_id = '' THEN
        NEW.procurement_id := 'PROC-' || LPAD(nextval('procurement_requests_id_seq')::TEXT, 3, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION generate_audit_log_id()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.log_id IS NULL OR NEW.log_id = '' THEN
        NEW.log_id := 'L-' || LPAD(nextval('audit_logs_id_seq')::TEXT, 5, '0');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- BALLISTIC ACCESS LOGGING FUNCTION
-- ============================================

-- log_ballistic_access: called by BallisticProfile.logAccess()
CREATE OR REPLACE FUNCTION log_ballistic_access(
    p_ballistic_id VARCHAR(20),
    p_user_id VARCHAR(20),
    p_access_type VARCHAR(50),
    p_access_reason TEXT DEFAULT NULL,
    p_ip_address VARCHAR(50) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS VARCHAR(20) AS $$
DECLARE
    v_access_id VARCHAR(20);
    v_firearm_id VARCHAR(20);
    v_firearm_status VARCHAR(50);
    v_custody_officer_id VARCHAR(20);
    v_custody_unit_id VARCHAR(20);
BEGIN
    -- Generate access ID
    v_access_id := 'BAL-' || LPAD(nextval('ballistic_access_id_seq')::TEXT, 4, '0');

    -- Get firearm info from ballistic profile
    SELECT bp.firearm_id, f.current_status
    INTO v_firearm_id, v_firearm_status
    FROM ballistic_profiles bp
    JOIN firearms f ON bp.firearm_id = f.firearm_id
    WHERE bp.ballistic_id = p_ballistic_id;

    -- Get current custody holder (if any)
    SELECT cr.officer_id, cr.unit_id
    INTO v_custody_officer_id, v_custody_unit_id
    FROM custody_records cr
    WHERE cr.firearm_id = v_firearm_id
      AND cr.returned_at IS NULL
    ORDER BY cr.issued_at DESC
    LIMIT 1;

    INSERT INTO ballistic_access_logs (
        access_id, ballistic_id, firearm_id, accessed_by,
        access_type, access_reason, firearm_status_at_access,
        current_custody_officer_id, current_custody_unit_id,
        ip_address, user_agent
    ) VALUES (
        v_access_id, p_ballistic_id, v_firearm_id, p_user_id,
        p_access_type, p_access_reason, v_firearm_status,
        v_custody_officer_id, v_custody_unit_id,
        p_ip_address, p_user_agent
    );

    RETURN v_access_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- CUSTODY & TEMPORAL FUNCTIONS
-- ============================================

-- Calculate custody duration
CREATE OR REPLACE FUNCTION calculate_custody_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.returned_at IS NOT NULL THEN
        NEW.custody_duration_seconds := EXTRACT(EPOCH FROM (NEW.returned_at - NEW.issued_at))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Extract temporal ML features
CREATE OR REPLACE FUNCTION extract_temporal_features()
RETURNS TRIGGER AS $$
BEGIN
    NEW.issue_hour := EXTRACT(HOUR FROM NEW.issued_at);
    NEW.issue_day_of_week := EXTRACT(DOW FROM NEW.issued_at);
    NEW.is_night_issue := (NEW.issue_hour >= 22 OR NEW.issue_hour < 6);
    NEW.is_weekend_issue := (NEW.issue_day_of_week = 0 OR NEW.issue_day_of_week = 6);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Update firearm status on custody changes
CREATE OR REPLACE FUNCTION update_firearm_status_on_custody()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE firearms SET current_status = 'in_custody' WHERE firearm_id = NEW.firearm_id;
    ELSIF TG_OP = 'UPDATE' AND NEW.returned_at IS NOT NULL AND OLD.returned_at IS NULL THEN
        UPDATE firearms SET current_status = 'available' WHERE firearm_id = NEW.firearm_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGERS
-- ============================================

CREATE TRIGGER trg_calculate_custody_duration
    BEFORE UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION calculate_custody_duration();

CREATE TRIGGER trg_extract_temporal_features
    BEFORE INSERT ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION extract_temporal_features();

CREATE TRIGGER trg_update_firearm_status
    AFTER INSERT OR UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION update_firearm_status_on_custody();

-- Auto-generate PKs
CREATE TRIGGER trg_generate_firearm_id
    BEFORE INSERT ON firearms
    FOR EACH ROW
    EXECUTE FUNCTION generate_firearm_id();

CREATE TRIGGER trg_generate_loss_id
    BEFORE INSERT ON loss_reports
    FOR EACH ROW
    EXECUTE FUNCTION generate_loss_id();

CREATE TRIGGER trg_generate_destruction_id
    BEFORE INSERT ON destruction_requests
    FOR EACH ROW
    EXECUTE FUNCTION generate_destruction_id();

CREATE TRIGGER trg_generate_procurement_id
    BEFORE INSERT ON procurement_requests
    FOR EACH ROW
    EXECUTE FUNCTION generate_procurement_id();

CREATE TRIGGER trg_generate_audit_log_id
    BEFORE INSERT ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION generate_audit_log_id();

-- ============================================
-- DATABASE VIEWS
-- ============================================

-- Custody chain timeline view (used by CustodyRecord.getCustodyChainTimeline)
CREATE OR REPLACE VIEW custody_chain_timeline AS
SELECT
    cr.custody_id,
    cr.firearm_id,
    cr.officer_id,
    o.full_name AS officer_name,
    o.rank AS officer_rank,
    cr.unit_id,
    u.unit_name,
    cr.custody_type,
    cr.issued_at,
    cr.returned_at,
    cr.custody_duration_seconds,
    cr.return_condition,
    cr.issued_by,
    issued_user.full_name AS issued_by_name,
    cr.returned_to,
    returned_user.full_name AS returned_to_name,
    cr.assignment_reason,
    ROW_NUMBER() OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) AS custody_sequence,
    -- Cross-unit detection
    LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) AS previous_unit_id,
    CASE WHEN LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) IS NOT NULL
         AND LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) != cr.unit_id
         THEN true ELSE false END AS is_cross_unit_transfer
FROM custody_records cr
JOIN officers o ON cr.officer_id = o.officer_id
JOIN units u ON cr.unit_id = u.unit_id
LEFT JOIN users issued_user ON cr.issued_by = issued_user.user_id
LEFT JOIN users returned_user ON cr.returned_to = returned_user.user_id;

-- Firearm traceability timeline view (used by ballistic.routes.js)
CREATE OR REPLACE VIEW firearm_traceability_timeline AS
SELECT
    f.firearm_id,
    f.serial_number,
    f.manufacturer,
    f.model,
    f.caliber,
    f.firearm_type,
    f.current_status,
    f.acquisition_date,
    f.assigned_unit_id,
    u.unit_name AS assigned_unit_name,
    bp.ballistic_id,
    bp.is_locked AS ballistic_locked,
    bp.registration_hash,
    bp.test_date AS ballistic_test_date,
    (SELECT COUNT(*) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) AS total_custody_events,
    (SELECT COUNT(DISTINCT cr.officer_id) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) AS unique_officers,
    (SELECT COUNT(DISTINCT cr.unit_id) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) AS unique_units,
    (SELECT MAX(cr.issued_at) FROM custody_records cr WHERE cr.firearm_id = f.firearm_id) AS last_custody_date,
    (SELECT COUNT(*) FROM ballistic_access_logs bal WHERE bal.firearm_id = f.firearm_id) AS total_ballistic_accesses
FROM firearms f
LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
LEFT JOIN ballistic_profiles bp ON f.firearm_id = bp.firearm_id;

-- Unified firearm events timeline view (used by CustodyRecord.getUnifiedTimeline)
CREATE OR REPLACE VIEW unified_firearm_events_timeline AS
-- Custody events
SELECT
    'custody' AS event_category,
    cr.custody_id AS event_id,
    cr.firearm_id,
    cr.issued_at AS event_timestamp,
    CASE
        WHEN cr.returned_at IS NOT NULL THEN 'Custody Returned'
        ELSE 'Custody Issued'
    END AS event_title,
    CONCAT('Assigned to ', o.full_name, ' (', o.rank, ') at ', u.unit_name) AS event_description,
    cr.officer_id AS actor_id,
    o.full_name AS actor_name,
    cr.unit_id,
    u.unit_name,
    1 AS event_priority
FROM custody_records cr
JOIN officers o ON cr.officer_id = o.officer_id
JOIN units u ON cr.unit_id = u.unit_id
UNION ALL
-- Ballistic access events
SELECT
    'ballistic_access' AS event_category,
    bal.access_id AS event_id,
    bal.firearm_id,
    bal.accessed_at AS event_timestamp,
    CONCAT('Ballistic ', REPLACE(bal.access_type, '_', ' ')) AS event_title,
    COALESCE(bal.access_reason, 'No reason provided') AS event_description,
    bal.accessed_by AS actor_id,
    usr.full_name AS actor_name,
    bal.current_custody_unit_id AS unit_id,
    COALESCE(unit.unit_name, 'N/A') AS unit_name,
    2 AS event_priority
FROM ballistic_access_logs bal
LEFT JOIN users usr ON bal.accessed_by = usr.user_id
LEFT JOIN units unit ON bal.current_custody_unit_id = unit.unit_id
UNION ALL
-- Unit movement events
SELECT
    'movement' AS event_category,
    mov.movement_id AS event_id,
    mov.firearm_id,
    mov.authorization_date AS event_timestamp,
    CONCAT('Unit ', REPLACE(mov.movement_type, '_', ' ')) AS event_title,
    COALESCE(mov.reason, 'Transfer') AS event_description,
    mov.authorized_by AS actor_id,
    auth_user.full_name AS actor_name,
    mov.to_unit_id AS unit_id,
    to_unit.unit_name AS unit_name,
    3 AS event_priority
FROM firearm_unit_movements mov
LEFT JOIN users auth_user ON mov.authorized_by = auth_user.user_id
LEFT JOIN units to_unit ON mov.to_unit_id = to_unit.unit_id;

-- ============================================
-- TRACEABILITY FUNCTION
-- ============================================

-- get_firearm_traceability: returns combined traceability data
CREATE OR REPLACE FUNCTION get_firearm_traceability(p_firearm_id VARCHAR(20))
RETURNS TABLE (
    event_category TEXT,
    event_id VARCHAR(20),
    firearm_id VARCHAR(20),
    event_timestamp TIMESTAMP,
    event_title TEXT,
    event_description TEXT,
    actor_id VARCHAR(20),
    actor_name VARCHAR(200),
    unit_id VARCHAR(20),
    unit_name VARCHAR(200),
    event_priority INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM unified_firearm_events_timeline uft
    WHERE uft.firearm_id = p_firearm_id
    ORDER BY uft.event_timestamp DESC, uft.event_priority;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- MATERIALIZED VIEWS FOR ML PERFORMANCE
-- ============================================

CREATE MATERIALIZED VIEW officer_behavior_profile AS
SELECT 
    o.officer_id,
    o.full_name,
    o.unit_id,
    COUNT(cr.custody_id) as total_custody_count,
    AVG(cr.custody_duration_seconds) as avg_custody_duration,
    COUNT(DISTINCT cr.firearm_id) as unique_firearms_used,
    MAX(cr.issued_at) as last_custody_date,
    COUNT(*) FILTER (WHERE cr.issued_at >= CURRENT_TIMESTAMP - INTERVAL '30 days') as recent_30d_count
FROM officers o
LEFT JOIN custody_records cr ON o.officer_id = cr.officer_id
GROUP BY o.officer_id, o.full_name, o.unit_id;

CREATE UNIQUE INDEX idx_officer_behavior_profile ON officer_behavior_profile(officer_id);

CREATE MATERIALIZED VIEW firearm_usage_profile AS
SELECT 
    f.firearm_id,
    f.serial_number,
    f.assigned_unit_id,
    COUNT(cr.custody_id) as total_custody_count,
    COUNT(DISTINCT cr.officer_id) as unique_officers_count,
    AVG(cr.custody_duration_seconds) as avg_custody_duration,
    MAX(cr.issued_at) as last_custody_date,
    COUNT(*) FILTER (WHERE cr.issued_at >= CURRENT_TIMESTAMP - INTERVAL '7 days') as recent_7d_count
FROM firearms f
LEFT JOIN custody_records cr ON f.firearm_id = cr.firearm_id
GROUP BY f.firearm_id, f.serial_number, f.assigned_unit_id;

CREATE UNIQUE INDEX idx_firearm_usage_profile ON firearm_usage_profile(firearm_id);

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE units IS 'Police units with user-friendly IDs (UNIT-HQ, UNIT-NYA, etc.)';
COMMENT ON TABLE users IS 'System users with role-based access control';
COMMENT ON TABLE officers IS 'Police officers who can be assigned firearms';
COMMENT ON TABLE firearms IS 'Firearm registry - IMPORTANT: assigned_unit_id determines which unit can access the firearm';
COMMENT ON TABLE custody_records IS 'Firearm custody tracking with ML features';
COMMENT ON TABLE anomalies IS 'ML-detected anomalies in custody patterns';
COMMENT ON TABLE audit_logs IS 'System-wide audit trail';
COMMENT ON TABLE ballistic_profiles IS 'Ballistic profiles for firearms';

-- End of SafeArms Database Schema
