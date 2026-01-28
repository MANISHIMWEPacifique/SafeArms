-- SafeArms Database Schema
-- PostgreSQL 14+
-- Police Firearm Control and Forensic Support Platform

-- ============================================
-- IMPORTANT: USER vs OFFICER SEPARATION
-- ============================================
-- USERS: System users who authenticate and manage the platform
--        (Admin, HQ Commander, Station Commander, Forensic Analyst)
--        - Have username, password, roles
--        - Can log in and perform system operations
--
-- OFFICERS: Police officers who receive firearm custody
--        - NO authentication credentials (cannot log in)
--        - NO roles (not system users)
--        - Referenced in custody_records for firearm assignments
--        - Managed by Station Commanders within their unit
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- CORE TABLES
-- ============================================

-- Units Table
CREATE TABLE units (
    unit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(200) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(20),
    role VARCHAR(50) NOT NULL CHECK (role IN ('admin', 'hq_firearm_commander', 'station_commander', 'forensic_analyst')),
    unit_id UUID REFERENCES units(unit_id),
    otp_code VARCHAR(6),
    otp_expires_at TIMESTAMP,
    otp_attempts INTEGER DEFAULT 0,
    otp_verified BOOLEAN DEFAULT false,
    unit_confirmed BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    must_change_password BOOLEAN DEFAULT true,
    last_login TIMESTAMP,
    created_by UUID REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Officers Table
CREATE TABLE officers (
    officer_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    officer_number VARCHAR(50) NOT NULL UNIQUE,
    full_name VARCHAR(200) NOT NULL,
    rank VARCHAR(100) NOT NULL,
    unit_id UUID NOT NULL REFERENCES units(unit_id),
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
    firearm_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    serial_number VARCHAR(100) NOT NULL UNIQUE,
    manufacturer VARCHAR(100) NOT NULL,
    model VARCHAR(100) NOT NULL,
    firearm_type VARCHAR(50) NOT NULL CHECK (firearm_type IN ('pistol', 'rifle', 'shotgun', 'submachine_gun', 'other')),
    caliber VARCHAR(50),
    manufacture_year INTEGER,
    acquisition_date DATE NOT NULL,
    acquisition_source VARCHAR(200),
    registration_level VARCHAR(10) NOT NULL CHECK (registration_level IN ('hq', 'unit')),
    registered_by UUID NOT NULL REFERENCES users(user_id),
    assigned_unit_id UUID REFERENCES units(unit_id),
    current_status VARCHAR(50) DEFAULT 'unassigned' CHECK (current_status IN ('unassigned', 'available', 'in_custody', 'maintenance', 'lost', 'stolen', 'destroyed')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ballistic Profiles Table
-- IMPORTANT: Ballistic profiles are IMMUTABLE after creation (forensic integrity)
CREATE TABLE ballistic_profiles (
    ballistic_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL UNIQUE REFERENCES firearms(firearm_id),
    test_date DATE NOT NULL,
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
    -- Immutability and traceability fields
    created_by UUID REFERENCES users(user_id),
    is_locked BOOLEAN DEFAULT true,
    locked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    locked_by UUID REFERENCES users(user_id),
    registration_hash VARCHAR(64),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Firearm Unit Movements Table
-- Tracks every movement of a firearm between units
CREATE TABLE firearm_unit_movements (
    movement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    from_unit_id UUID REFERENCES units(unit_id),
    to_unit_id UUID NOT NULL REFERENCES units(unit_id),
    movement_type VARCHAR(50) NOT NULL CHECK (movement_type IN (
        'initial_assignment', 'transfer', 'reassignment', 'temporary_loan', 'return_from_loan'
    )),
    authorized_by UUID NOT NULL REFERENCES users(user_id),
    authorization_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    authorization_reference VARCHAR(100),
    reason TEXT,
    custody_record_id UUID REFERENCES custody_records(custody_id),
    ip_address VARCHAR(50),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Ballistic Access Logs Table
-- Tracks every access to ballistic profile data
CREATE TABLE ballistic_access_logs (
    access_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ballistic_id UUID NOT NULL REFERENCES ballistic_profiles(ballistic_id),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    accessed_by UUID NOT NULL REFERENCES users(user_id),
    access_type VARCHAR(50) NOT NULL CHECK (access_type IN (
        'view_profile', 'view_custody_chain', 'export_data', 'forensic_query', 'traceability_report'
    )),
    access_reason TEXT,
    firearm_status_at_access VARCHAR(50),
    current_custody_officer_id UUID REFERENCES officers(officer_id),
    current_custody_unit_id UUID REFERENCES units(unit_id),
    ip_address VARCHAR(50),
    user_agent TEXT,
    accessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Custody Records Table
CREATE TABLE custody_records (
    custody_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    officer_id UUID NOT NULL REFERENCES officers(officer_id),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    custody_type VARCHAR(50) NOT NULL CHECK (custody_type IN ('permanent', 'temporary', 'personal_long_term')),
    issued_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    issued_by UUID NOT NULL REFERENCES users(user_id),
    expected_return_date DATE,
    returned_at TIMESTAMP,
    returned_to UUID REFERENCES users(user_id),
    return_condition VARCHAR(50) CHECK (return_condition IN ('good', 'fair', 'needs_maintenance', 'damaged')),
    assignment_reason TEXT,
    notes TEXT,
    -- ML Feature Engineering Fields
    custody_duration_seconds INTEGER,
    issue_hour INTEGER,
    issue_day_of_week INTEGER,
    is_night_issue BOOLEAN,
    is_weekend_issue BOOLEAN,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- ML SYSTEM TABLES
-- ============================================

-- ML Training Features Table
CREATE TABLE ml_training_features (
    feature_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    officer_id UUID NOT NULL REFERENCES officers(officer_id),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    custody_record_id UUID NOT NULL REFERENCES custody_records(custody_id),
    -- Temporal Features
    custody_duration_seconds INTEGER,
    issue_hour INTEGER,
    issue_day_of_week INTEGER,
    is_night_issue BOOLEAN,
    is_weekend_issue BOOLEAN,
    -- Behavioral Features
    officer_issue_frequency_30d DECIMAL(10,2),
    officer_avg_custody_duration_30d DECIMAL(10,2),
    firearm_exchange_rate_7d DECIMAL(10,2),
    officer_unit_consistency_score DECIMAL(5,2),
    time_since_last_return_seconds INTEGER,
    consecutive_same_firearm_count INTEGER,
    -- Pattern Flags
    cross_unit_movement_flag BOOLEAN,
    rapid_exchange_flag BOOLEAN,
    -- Statistical Features
    custody_duration_zscore DECIMAL(10,4),
    issue_frequency_zscore DECIMAL(10,4),
    -- Ballistic Context Features
    has_ballistic_profile BOOLEAN DEFAULT false,
    ballistic_accesses_7d INTEGER DEFAULT 0,
    feature_extraction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ML Model Metadata Table
CREATE TABLE ml_model_metadata (
    model_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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
    anomaly_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    custody_record_id UUID NOT NULL REFERENCES custody_records(custody_id),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    officer_id UUID NOT NULL REFERENCES officers(officer_id),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    anomaly_score DECIMAL(5,3) NOT NULL,
    anomaly_type VARCHAR(100) NOT NULL,
    detection_method VARCHAR(50) NOT NULL,
    model_id UUID REFERENCES ml_model_metadata(model_id),
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    confidence_level DECIMAL(5,3),
    contributing_factors JSONB,
    feature_importance JSONB,
    status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'false_positive')),
    investigated_by UUID REFERENCES users(user_id),
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
    investigation_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    anomaly_id UUID NOT NULL REFERENCES anomalies(anomaly_id),
    investigator_id UUID NOT NULL REFERENCES users(user_id),
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
    loss_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    reported_by UUID NOT NULL REFERENCES users(user_id),
    officer_id UUID REFERENCES officers(officer_id),
    loss_type VARCHAR(50) NOT NULL CHECK (loss_type IN ('lost', 'stolen')),
    loss_date DATE NOT NULL,
    loss_location VARCHAR(200),
    circumstances TEXT NOT NULL,
    police_case_number VARCHAR(100),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Destruction Requests Table
CREATE TABLE destruction_requests (
    destruction_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    requested_by UUID NOT NULL REFERENCES users(user_id),
    destruction_reason TEXT NOT NULL,
    condition_description TEXT,
    supporting_documents TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    actual_destruction_date DATE,
    destruction_method VARCHAR(100),
    witnesses TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Procurement Requests Table
CREATE TABLE procurement_requests (
    procurement_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    unit_id UUID NOT NULL REFERENCES units(unit_id),
    requested_by UUID NOT NULL REFERENCES users(user_id),
    firearm_type VARCHAR(50) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    justification TEXT NOT NULL,
    priority VARCHAR(20) DEFAULT 'routine' CHECK (priority IN ('urgent', 'high', 'routine')),
    estimated_cost DECIMAL(15,2),
    preferred_supplier VARCHAR(200),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reviewed_by UUID REFERENCES users(user_id),
    review_date TIMESTAMP,
    review_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- AUDIT TABLE
-- ============================================

-- Audit Logs Table
CREATE TABLE audit_logs (
    log_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(user_id),
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(100),
    record_id UUID,
    new_values JSONB,
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
CREATE INDEX idx_unit_movements_firearm_date ON firearm_unit_movements(firearm_id, authorization_date DESC);

-- Composite indexes for traceability queries
CREATE INDEX idx_custody_firearm_time ON custody_records(firearm_id, issued_at DESC);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to calculate custody duration
CREATE OR REPLACE FUNCTION calculate_custody_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.returned_at IS NOT NULL THEN
        NEW.custody_duration_seconds := EXTRACT(EPOCH FROM (NEW.returned_at - NEW.issued_at))::INTEGER;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to extract temporal ML features
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

-- Function to update firearm status on custody assignment
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

-- Custody duration trigger
CREATE TRIGGER trg_calculate_custody_duration
    BEFORE UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION calculate_custody_duration();

-- Temporal features trigger
CREATE TRIGGER trg_extract_temporal_features
    BEFORE INSERT ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION extract_temporal_features();

-- Firearm status trigger
CREATE TRIGGER trg_update_firearm_status
    AFTER INSERT OR UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION update_firearm_status_on_custody();

-- ============================================
-- MATERIALIZED VIEWS FOR ML PERFORMANCE
-- ============================================

-- Officer Behavior Profile View
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

-- Firearm Usage Profile View
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
-- TRACEABILITY VIEWS
-- ============================================

-- Unified Firearm Events Timeline View
-- Complete chronological timeline of all events for a firearm
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
    1 as event_priority
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
LEFT JOIN units unit ON a.unit_id = unit.unit_id;

COMMENT ON VIEW unified_firearm_events_timeline IS 
'Complete chronological timeline of all events for a firearm.
Use: SELECT * FROM unified_firearm_events_timeline WHERE firearm_id = ? ORDER BY event_timestamp, event_priority
Categories: REGISTRATION, BALLISTIC, MOVEMENT, CUSTODY, BALLISTIC_ACCESS, ANOMALY';

-- ============================================
-- IMMUTABILITY TRIGGERS
-- ============================================

-- Prevent deletion of custody records
CREATE OR REPLACE FUNCTION prevent_custody_deletion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Custody records are immutable and cannot be deleted. Record ID: %', OLD.custody_id;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_custody_deletion
    BEFORE DELETE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION prevent_custody_deletion();

-- Restrict custody record updates
CREATE OR REPLACE FUNCTION restrict_custody_updates()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.returned_at IS NOT NULL AND NEW.returned_at IS DISTINCT FROM OLD.returned_at THEN
        RAISE EXCEPTION 'Cannot modify returned_at once set. Custody ID: %', OLD.custody_id;
    END IF;
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

CREATE TRIGGER trg_restrict_custody_updates
    BEFORE UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION restrict_custody_updates();

-- Prevent audit log modification
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

CREATE TRIGGER trg_prevent_audit_modification
    BEFORE UPDATE OR DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION prevent_audit_modification();

-- Prevent ballistic profile modification
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

CREATE TRIGGER trg_prevent_ballistic_modification
    BEFORE UPDATE OR DELETE ON ballistic_profiles
    FOR EACH ROW
    EXECUTE FUNCTION prevent_ballistic_modification();

-- Auto-log firearm unit movements
CREATE OR REPLACE FUNCTION log_firearm_unit_movement()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assigned_unit_id IS DISTINCT FROM OLD.assigned_unit_id THEN
        INSERT INTO firearm_unit_movements (
            firearm_id, from_unit_id, to_unit_id, movement_type,
            authorized_by, reason
        ) VALUES (
            NEW.firearm_id, OLD.assigned_unit_id, NEW.assigned_unit_id,
            CASE WHEN OLD.assigned_unit_id IS NULL THEN 'initial_assignment' ELSE 'transfer' END,
            COALESCE(current_setting('app.current_user_id', true)::UUID, NEW.registered_by),
            'Firearm unit assignment updated'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_firearm_unit_movement
    AFTER UPDATE ON firearms
    FOR EACH ROW
    EXECUTE FUNCTION log_firearm_unit_movement();

-- Log initial firearm assignment
CREATE OR REPLACE FUNCTION log_initial_firearm_assignment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.assigned_unit_id IS NOT NULL THEN
        INSERT INTO firearm_unit_movements (
            firearm_id, from_unit_id, to_unit_id, movement_type,
            authorized_by, reason
        ) VALUES (
            NEW.firearm_id, NULL, NEW.assigned_unit_id,
            'initial_assignment', NEW.registered_by, 'Initial firearm registration'
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_initial_firearm_assignment
    AFTER INSERT ON firearms
    FOR EACH ROW
    EXECUTE FUNCTION log_initial_firearm_assignment();

-- ============================================
-- TRACEABILITY HELPER FUNCTIONS
-- ============================================

-- Log ballistic access function
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
    SELECT bp.firearm_id, f.current_status
    INTO v_firearm_id, v_firearm_status
    FROM ballistic_profiles bp
    JOIN firearms f ON bp.firearm_id = f.firearm_id
    WHERE bp.ballistic_id = p_ballistic_id;

    SELECT cr.officer_id, cr.unit_id
    INTO v_current_officer_id, v_current_unit_id
    FROM custody_records cr
    WHERE cr.firearm_id = v_firearm_id AND cr.returned_at IS NULL
    ORDER BY cr.issued_at DESC LIMIT 1;

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

-- Get complete firearm traceability as JSON
CREATE OR REPLACE FUNCTION get_complete_firearm_traceability(p_firearm_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'firearm', (
            SELECT jsonb_build_object(
                'firearm_id', f.firearm_id,
                'serial_number', f.serial_number,
                'manufacturer', f.manufacturer,
                'model', f.model,
                'current_status', f.current_status,
                'assigned_unit', u.unit_name
            )
            FROM firearms f
            LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
            WHERE f.firearm_id = p_firearm_id
        ),
        'has_ballistic_profile', EXISTS(SELECT 1 FROM ballistic_profiles WHERE firearm_id = p_firearm_id),
        'total_custody_events', (SELECT COUNT(*) FROM custody_records WHERE firearm_id = p_firearm_id),
        'total_unit_movements', (SELECT COUNT(*) FROM firearm_unit_movements WHERE firearm_id = p_firearm_id),
        'total_ballistic_accesses', (SELECT COUNT(*) FROM ballistic_access_logs WHERE firearm_id = p_firearm_id),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- COMMENTS
-- ============================================

COMMENT ON TABLE users IS 'System users with role-based access control';
COMMENT ON TABLE officers IS 'Police officers who can be assigned firearms';
COMMENT ON TABLE firearms IS 'Firearm registry with ballistic profiles';
COMMENT ON TABLE custody_records IS 'Firearm custody tracking with ML features - IMMUTABLE after creation';
COMMENT ON TABLE anomalies IS 'ML-detected anomalies in custody patterns';
COMMENT ON TABLE ml_training_features IS 'Extracted features for ML model training';
COMMENT ON TABLE ml_model_metadata IS 'ML model versions and parameters';
COMMENT ON TABLE audit_logs IS 'System-wide audit trail - IMMUTABLE';
COMMENT ON TABLE ballistic_profiles IS 'Ballistic profiles for firearms - IMMUTABLE after creation';
COMMENT ON TABLE ballistic_access_logs IS 'Tracks all access to ballistic profile data';
COMMENT ON TABLE firearm_unit_movements IS 'Complete history of firearm movements between units - IMMUTABLE';

-- End of schema
