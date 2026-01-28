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
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
-- COMMENTS
-- ============================================

COMMENT ON TABLE users IS 'System users with role-based access control';
COMMENT ON TABLE officers IS 'Police officers who can be assigned firearms';
COMMENT ON TABLE firearms IS 'Firearm registry with ballistic profiles';
COMMENT ON TABLE custody_records IS 'Firearm custody tracking with ML features';
COMMENT ON TABLE anomalies IS 'ML-detected anomalies in custody patterns';
COMMENT ON TABLE ml_training_features IS 'Extracted features for ML model training';
COMMENT ON TABLE ml_model_metadata IS 'ML model versions and parameters';
COMMENT ON TABLE audit_logs IS 'System-wide audit trail';

-- End of schema
