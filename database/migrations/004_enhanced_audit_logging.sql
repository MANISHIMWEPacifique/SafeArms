-- ============================================
-- MIGRATION: Enhanced Audit Logging for Legal Chain-of-Custody
-- SafeArms Database Migration 004
-- 
-- PURPOSE: Strengthen audit logging to support legal chain-of-custody
-- reconstruction for forensic and investigative purposes.
--
-- REQUIREMENTS ADDRESSED:
-- 1. All custody, unit transfer, and ballistic access events are logged
-- 2. Logs are immutable and append-only
-- 3. Each log entry records who, what, when, and why
-- 4. Logs support legal chain-of-custody reconstruction
-- ============================================

-- ============================================
-- ENHANCED AUDIT LOG TABLE
-- Add missing fields for legal chain-of-custody
-- ============================================

-- Add reason/justification field (the "why")
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS reason TEXT;

-- Add actor context fields
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS actor_role VARCHAR(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS actor_unit_id UUID;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS actor_unit_name VARCHAR(200);

-- Add subject context (what was acted upon)
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS subject_type VARCHAR(50);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS subject_id UUID;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS subject_name VARCHAR(255);

-- Add previous values for change tracking
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS old_values JSONB;

-- Add session tracking
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS session_id VARCHAR(100);

-- Add legal/compliance fields
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS is_chain_of_custody_event BOOLEAN DEFAULT false;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS legal_hold BOOLEAN DEFAULT false;
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS integrity_hash VARCHAR(128);

-- Add request tracking
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS request_id VARCHAR(100);
ALTER TABLE audit_logs ADD COLUMN IF NOT EXISTS correlation_id VARCHAR(100);

-- Add indexes for chain-of-custody queries
CREATE INDEX IF NOT EXISTS idx_audit_chain_of_custody ON audit_logs(is_chain_of_custody_event) WHERE is_chain_of_custody_event = true;
CREATE INDEX IF NOT EXISTS idx_audit_subject ON audit_logs(subject_type, subject_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor_role ON audit_logs(actor_role);
CREATE INDEX IF NOT EXISTS idx_audit_correlation ON audit_logs(correlation_id);
CREATE INDEX IF NOT EXISTS idx_audit_legal_hold ON audit_logs(legal_hold) WHERE legal_hold = true;

-- ============================================
-- CHAIN-OF-CUSTODY AUDIT LOG TABLE
-- Specialized table for custody chain events
-- Optimized for legal reconstruction
-- ============================================

CREATE TABLE IF NOT EXISTS chain_of_custody_audit (
    audit_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Event identification
    event_sequence SERIAL,  -- Monotonically increasing sequence for ordering
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
        'INITIAL_REGISTRATION',     -- Firearm first registered
        'CUSTODY_ASSIGNED',         -- Custody given to officer
        'CUSTODY_RETURNED',         -- Custody returned
        'CUSTODY_TRANSFERRED',      -- Direct transfer between officers
        'UNIT_TRANSFER_OUT',        -- Firearm leaving unit
        'UNIT_TRANSFER_IN',         -- Firearm entering unit
        'CROSS_UNIT_MOVEMENT',      -- Movement between units
        'STATUS_CHANGE',            -- Status changed (available, maintenance, etc.)
        'BALLISTIC_PROFILE_CREATED', -- Ballistic profile created
        'BALLISTIC_ACCESSED',       -- Ballistic data viewed
        'CONDITION_CHANGE',         -- Physical condition changed
        'LOSS_REPORTED',            -- Firearm reported lost/stolen
        'DESTRUCTION_INITIATED',    -- Destruction process started
        'DESTRUCTION_COMPLETED'     -- Destruction completed
    )),
    event_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- What (the subject)
    firearm_id UUID NOT NULL REFERENCES firearms(firearm_id),
    firearm_serial VARCHAR(100) NOT NULL,  -- Denormalized for immutability
    firearm_model VARCHAR(200),
    
    -- Who (the actor)
    actor_user_id UUID REFERENCES users(user_id),
    actor_username VARCHAR(100) NOT NULL,  -- Denormalized for immutability
    actor_role VARCHAR(50) NOT NULL,
    actor_full_name VARCHAR(200),
    
    -- Who (the custodian - for custody events)
    custodian_officer_id UUID REFERENCES officers(officer_id),
    custodian_officer_number VARCHAR(50),
    custodian_officer_name VARCHAR(200),
    custodian_rank VARCHAR(50),
    
    -- Where (unit context)
    unit_id UUID REFERENCES units(unit_id),
    unit_name VARCHAR(200) NOT NULL,       -- Denormalized for immutability
    unit_code VARCHAR(50),
    
    -- Previous state (for transfers)
    previous_unit_id UUID REFERENCES units(unit_id),
    previous_unit_name VARCHAR(200),
    previous_custodian_officer_id UUID REFERENCES officers(officer_id),
    previous_custodian_name VARCHAR(200),
    previous_status VARCHAR(50),
    
    -- New state
    new_status VARCHAR(50),
    new_condition VARCHAR(50),
    
    -- Why (justification)
    reason TEXT NOT NULL,                  -- REQUIRED - legal chain requires justification
    authorization_reference VARCHAR(100),  -- Order number, case number, etc.
    
    -- Related records
    custody_record_id UUID REFERENCES custody_records(custody_id),
    movement_id UUID,                      -- Reference to firearm_unit_movements
    ballistic_profile_id UUID REFERENCES ballistic_profiles(ballistic_id),
    
    -- Access context
    ip_address VARCHAR(50),
    user_agent TEXT,
    session_id VARCHAR(100),
    
    -- Integrity fields
    integrity_hash VARCHAR(128),           -- SHA-256 hash of record contents
    previous_hash VARCHAR(128),            -- Hash of previous record (blockchain-style)
    
    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Ensure chain integrity with indexes
CREATE INDEX IF NOT EXISTS idx_coc_firearm ON chain_of_custody_audit(firearm_id);
CREATE INDEX IF NOT EXISTS idx_coc_event_type ON chain_of_custody_audit(event_type);
CREATE INDEX IF NOT EXISTS idx_coc_timestamp ON chain_of_custody_audit(event_timestamp);
CREATE INDEX IF NOT EXISTS idx_coc_actor ON chain_of_custody_audit(actor_user_id);
CREATE INDEX IF NOT EXISTS idx_coc_custodian ON chain_of_custody_audit(custodian_officer_id);
CREATE INDEX IF NOT EXISTS idx_coc_unit ON chain_of_custody_audit(unit_id);
CREATE INDEX IF NOT EXISTS idx_coc_sequence ON chain_of_custody_audit(event_sequence);
CREATE INDEX IF NOT EXISTS idx_coc_firearm_sequence ON chain_of_custody_audit(firearm_id, event_sequence);

-- ============================================
-- MAKE CHAIN-OF-CUSTODY AUDIT IMMUTABLE
-- ============================================

CREATE OR REPLACE FUNCTION prevent_coc_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Chain-of-custody audit records are IMMUTABLE and cannot be deleted. Audit ID: %, Firearm: %', 
            OLD.audit_id, OLD.firearm_serial;
    ELSIF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Chain-of-custody audit records are IMMUTABLE and cannot be updated. Audit ID: %, Firearm: %', 
            OLD.audit_id, OLD.firearm_serial;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_coc_audit_modification ON chain_of_custody_audit;
CREATE TRIGGER trg_prevent_coc_audit_modification
    BEFORE UPDATE OR DELETE ON chain_of_custody_audit
    FOR EACH ROW
    EXECUTE FUNCTION prevent_coc_audit_modification();

-- ============================================
-- INTEGRITY HASH GENERATION
-- Generates cryptographic hash of record for tamper detection
-- ============================================

CREATE OR REPLACE FUNCTION generate_coc_integrity_hash()
RETURNS TRIGGER AS $$
DECLARE
    v_previous_hash VARCHAR(128);
    v_content TEXT;
BEGIN
    -- Get previous record's hash (blockchain-style chaining)
    SELECT integrity_hash INTO v_previous_hash
    FROM chain_of_custody_audit
    WHERE firearm_id = NEW.firearm_id
    ORDER BY event_sequence DESC
    LIMIT 1;
    
    -- Build content string for hashing
    v_content := COALESCE(v_previous_hash, 'GENESIS') || '|' ||
                 NEW.event_type || '|' ||
                 NEW.firearm_id::TEXT || '|' ||
                 NEW.firearm_serial || '|' ||
                 NEW.actor_user_id::TEXT || '|' ||
                 NEW.actor_username || '|' ||
                 COALESCE(NEW.custodian_officer_id::TEXT, '') || '|' ||
                 NEW.unit_id::TEXT || '|' ||
                 NEW.reason || '|' ||
                 NEW.event_timestamp::TEXT;
    
    -- Generate SHA-256 hash
    NEW.integrity_hash := encode(digest(v_content, 'sha256'), 'hex');
    NEW.previous_hash := v_previous_hash;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_generate_coc_integrity_hash ON chain_of_custody_audit;
CREATE TRIGGER trg_generate_coc_integrity_hash
    BEFORE INSERT ON chain_of_custody_audit
    FOR EACH ROW
    EXECUTE FUNCTION generate_coc_integrity_hash();

-- ============================================
-- FUNCTION: Log Chain-of-Custody Event
-- Centralized function for logging all custody events
-- ============================================

CREATE OR REPLACE FUNCTION log_chain_of_custody_event(
    p_event_type VARCHAR(50),
    p_firearm_id UUID,
    p_actor_user_id UUID,
    p_custodian_officer_id UUID,
    p_unit_id UUID,
    p_previous_unit_id UUID,
    p_previous_custodian_id UUID,
    p_reason TEXT,
    p_custody_record_id UUID DEFAULT NULL,
    p_movement_id UUID DEFAULT NULL,
    p_ballistic_profile_id UUID DEFAULT NULL,
    p_new_status VARCHAR(50) DEFAULT NULL,
    p_new_condition VARCHAR(50) DEFAULT NULL,
    p_authorization_reference VARCHAR(100) DEFAULT NULL,
    p_ip_address VARCHAR(50) DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_session_id VARCHAR(100) DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_audit_id UUID;
    v_firearm RECORD;
    v_actor RECORD;
    v_custodian RECORD;
    v_unit RECORD;
    v_prev_unit RECORD;
    v_prev_custodian RECORD;
    v_previous_status VARCHAR(50);
BEGIN
    -- Get firearm details (denormalized for immutability)
    SELECT firearm_id, serial_number, manufacturer || ' ' || model as model, current_status
    INTO v_firearm
    FROM firearms
    WHERE firearm_id = p_firearm_id;
    
    IF v_firearm IS NULL THEN
        RAISE EXCEPTION 'Firearm not found: %', p_firearm_id;
    END IF;
    
    v_previous_status := v_firearm.current_status;
    
    -- Get actor details
    SELECT user_id, username, role, full_name
    INTO v_actor
    FROM users
    WHERE user_id = p_actor_user_id;
    
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'Actor user not found: %', p_actor_user_id;
    END IF;
    
    -- Get custodian details (if applicable)
    IF p_custodian_officer_id IS NOT NULL THEN
        SELECT officer_id, officer_number, full_name, rank
        INTO v_custodian
        FROM officers
        WHERE officer_id = p_custodian_officer_id;
    END IF;
    
    -- Get unit details
    SELECT unit_id, unit_name, unit_code
    INTO v_unit
    FROM units
    WHERE unit_id = p_unit_id;
    
    -- Get previous unit details (if applicable)
    IF p_previous_unit_id IS NOT NULL THEN
        SELECT unit_id, unit_name
        INTO v_prev_unit
        FROM units
        WHERE unit_id = p_previous_unit_id;
    END IF;
    
    -- Get previous custodian details (if applicable)
    IF p_previous_custodian_id IS NOT NULL THEN
        SELECT officer_id, full_name
        INTO v_prev_custodian
        FROM officers
        WHERE officer_id = p_previous_custodian_id;
    END IF;
    
    -- Insert the chain-of-custody audit record
    INSERT INTO chain_of_custody_audit (
        event_type,
        firearm_id,
        firearm_serial,
        firearm_model,
        actor_user_id,
        actor_username,
        actor_role,
        actor_full_name,
        custodian_officer_id,
        custodian_officer_number,
        custodian_officer_name,
        custodian_rank,
        unit_id,
        unit_name,
        unit_code,
        previous_unit_id,
        previous_unit_name,
        previous_custodian_officer_id,
        previous_custodian_name,
        previous_status,
        new_status,
        new_condition,
        reason,
        authorization_reference,
        custody_record_id,
        movement_id,
        ballistic_profile_id,
        ip_address,
        user_agent,
        session_id
    ) VALUES (
        p_event_type,
        p_firearm_id,
        v_firearm.serial_number,
        v_firearm.model,
        p_actor_user_id,
        v_actor.username,
        v_actor.role,
        v_actor.full_name,
        p_custodian_officer_id,
        v_custodian.officer_number,
        v_custodian.full_name,
        v_custodian.rank,
        p_unit_id,
        v_unit.unit_name,
        v_unit.unit_code,
        p_previous_unit_id,
        v_prev_unit.unit_name,
        p_previous_custodian_id,
        v_prev_custodian.full_name,
        v_previous_status,
        p_new_status,
        p_new_condition,
        p_reason,
        p_authorization_reference,
        p_custody_record_id,
        p_movement_id,
        p_ballistic_profile_id,
        p_ip_address,
        p_user_agent,
        p_session_id
    )
    RETURNING audit_id INTO v_audit_id;
    
    -- Also log to main audit_logs for unified search
    INSERT INTO audit_logs (
        user_id,
        action_type,
        table_name,
        record_id,
        new_values,
        reason,
        actor_role,
        actor_unit_id,
        subject_type,
        subject_id,
        subject_name,
        is_chain_of_custody_event,
        ip_address,
        user_agent,
        session_id
    ) VALUES (
        p_actor_user_id,
        p_event_type,
        'chain_of_custody_audit',
        v_audit_id,
        jsonb_build_object(
            'firearm_id', p_firearm_id,
            'firearm_serial', v_firearm.serial_number,
            'custodian_officer_id', p_custodian_officer_id,
            'unit_id', p_unit_id,
            'previous_unit_id', p_previous_unit_id
        ),
        p_reason,
        v_actor.role,
        p_unit_id,
        'firearm',
        p_firearm_id,
        v_firearm.serial_number,
        true,
        p_ip_address,
        p_user_agent,
        p_session_id
    );
    
    RETURN v_audit_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VIEW: Complete Chain-of-Custody for a Firearm
-- Provides legal-ready timeline reconstruction
-- ============================================

CREATE OR REPLACE VIEW legal_chain_of_custody AS
SELECT 
    coc.audit_id,
    coc.event_sequence,
    coc.event_type,
    coc.event_timestamp,
    coc.firearm_id,
    coc.firearm_serial,
    coc.firearm_model,
    coc.actor_username,
    coc.actor_role,
    coc.actor_full_name,
    coc.custodian_officer_number,
    coc.custodian_officer_name,
    coc.custodian_rank,
    coc.unit_name,
    coc.unit_code,
    coc.previous_unit_name,
    coc.previous_custodian_name,
    coc.previous_status,
    coc.new_status,
    coc.new_condition,
    coc.reason,
    coc.authorization_reference,
    coc.ip_address,
    coc.integrity_hash,
    coc.previous_hash,
    -- Verify hash chain integrity
    CASE 
        WHEN coc.event_sequence = 1 THEN true
        WHEN coc.previous_hash = (
            SELECT integrity_hash 
            FROM chain_of_custody_audit prev 
            WHERE prev.firearm_id = coc.firearm_id 
              AND prev.event_sequence = coc.event_sequence - 1
        ) THEN true
        ELSE false
    END as integrity_verified,
    coc.created_at
FROM chain_of_custody_audit coc
ORDER BY coc.firearm_id, coc.event_sequence;

COMMENT ON VIEW legal_chain_of_custody IS 
'Provides complete chain-of-custody timeline for legal/forensic reconstruction. 
Includes integrity verification of hash chain.';

-- ============================================
-- FUNCTION: Verify Chain Integrity
-- Validates the entire hash chain for a firearm
-- ============================================

CREATE OR REPLACE FUNCTION verify_chain_integrity(p_firearm_id UUID)
RETURNS TABLE (
    is_valid BOOLEAN,
    total_events INTEGER,
    broken_at_sequence INTEGER,
    first_event_timestamp TIMESTAMP,
    last_event_timestamp TIMESTAMP,
    verification_timestamp TIMESTAMP
) AS $$
DECLARE
    v_current RECORD;
    v_expected_hash VARCHAR(128);
    v_total_events INTEGER;
    v_broken_sequence INTEGER := NULL;
BEGIN
    -- Count total events
    SELECT COUNT(*) INTO v_total_events
    FROM chain_of_custody_audit
    WHERE firearm_id = p_firearm_id;
    
    -- Check each record's hash chain
    FOR v_current IN 
        SELECT * FROM chain_of_custody_audit
        WHERE firearm_id = p_firearm_id
        ORDER BY event_sequence
    LOOP
        IF v_current.event_sequence = 1 THEN
            -- First record should have no previous hash or 'GENESIS'
            IF v_current.previous_hash IS NOT NULL AND v_current.previous_hash != 'GENESIS' THEN
                v_broken_sequence := 1;
                EXIT;
            END IF;
        ELSE
            -- Get expected previous hash
            SELECT integrity_hash INTO v_expected_hash
            FROM chain_of_custody_audit
            WHERE firearm_id = p_firearm_id 
              AND event_sequence = v_current.event_sequence - 1;
            
            IF v_current.previous_hash != v_expected_hash THEN
                v_broken_sequence := v_current.event_sequence;
                EXIT;
            END IF;
        END IF;
    END LOOP;
    
    RETURN QUERY
    SELECT 
        v_broken_sequence IS NULL as is_valid,
        v_total_events,
        v_broken_sequence,
        (SELECT MIN(event_timestamp) FROM chain_of_custody_audit WHERE firearm_id = p_firearm_id),
        (SELECT MAX(event_timestamp) FROM chain_of_custody_audit WHERE firearm_id = p_firearm_id),
        CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCTION: Export Legal Chain-of-Custody Report
-- Returns formatted data for legal proceedings
-- ============================================

CREATE OR REPLACE FUNCTION export_legal_chain_of_custody(
    p_firearm_id UUID,
    p_start_date TIMESTAMP DEFAULT NULL,
    p_end_date TIMESTAMP DEFAULT NULL
)
RETURNS TABLE (
    sequence_number INTEGER,
    event_date TIMESTAMP,
    event_type VARCHAR(50),
    action_performed_by TEXT,
    action_performed_by_role VARCHAR(50),
    custodian TEXT,
    custodian_unit TEXT,
    previous_custodian TEXT,
    previous_unit TEXT,
    reason_justification TEXT,
    authorization_ref VARCHAR(100),
    firearm_status VARCHAR(50),
    digital_signature VARCHAR(128)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        coc.event_sequence::INTEGER,
        coc.event_timestamp,
        coc.event_type,
        COALESCE(coc.actor_full_name, coc.actor_username)::TEXT,
        coc.actor_role,
        (COALESCE(coc.custodian_rank || ' ', '') || COALESCE(coc.custodian_officer_name, 'N/A'))::TEXT,
        coc.unit_name::TEXT,
        COALESCE(coc.previous_custodian_name, 'N/A')::TEXT,
        COALESCE(coc.previous_unit_name, 'N/A')::TEXT,
        coc.reason::TEXT,
        coc.authorization_reference,
        COALESCE(coc.new_status, coc.previous_status),
        coc.integrity_hash
    FROM chain_of_custody_audit coc
    WHERE coc.firearm_id = p_firearm_id
      AND (p_start_date IS NULL OR coc.event_timestamp >= p_start_date)
      AND (p_end_date IS NULL OR coc.event_timestamp <= p_end_date)
    ORDER BY coc.event_sequence;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- AUTOMATIC CUSTODY EVENT LOGGING TRIGGER
-- Logs to chain-of-custody when custody records change
-- ============================================

CREATE OR REPLACE FUNCTION auto_log_custody_to_chain()
RETURNS TRIGGER AS $$
DECLARE
    v_event_type VARCHAR(50);
    v_actor_user_id UUID;
    v_previous_unit_id UUID;
    v_previous_custodian_id UUID;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Determine if this is a cross-unit transfer
        SELECT unit_id, officer_id INTO v_previous_unit_id, v_previous_custodian_id
        FROM custody_records
        WHERE firearm_id = NEW.firearm_id
          AND custody_id != NEW.custody_id
          AND returned_at IS NOT NULL
        ORDER BY returned_at DESC
        LIMIT 1;
        
        IF v_previous_unit_id IS NOT NULL AND v_previous_unit_id != NEW.unit_id THEN
            v_event_type := 'CROSS_UNIT_MOVEMENT';
        ELSE
            v_event_type := 'CUSTODY_ASSIGNED';
        END IF;
        
        PERFORM log_chain_of_custody_event(
            v_event_type,
            NEW.firearm_id,
            NEW.issued_by,
            NEW.officer_id,
            NEW.unit_id,
            v_previous_unit_id,
            v_previous_custodian_id,
            COALESCE(NEW.assignment_reason, 'Custody assignment'),
            NEW.custody_id,
            NULL,  -- movement_id
            NULL,  -- ballistic_profile_id
            'in_custody',
            NULL,  -- condition
            NULL   -- authorization_reference
        );
        
    ELSIF TG_OP = 'UPDATE' THEN
        -- Check if this is a return event
        IF OLD.returned_at IS NULL AND NEW.returned_at IS NOT NULL THEN
            PERFORM log_chain_of_custody_event(
                'CUSTODY_RETURNED',
                NEW.firearm_id,
                NEW.returned_to,
                NEW.officer_id,
                NEW.unit_id,
                NULL,  -- no previous unit for returns
                NULL,  -- no previous custodian for returns
                COALESCE(NEW.notes, 'Custody returned'),
                NEW.custody_id,
                NULL,  -- movement_id
                NULL,  -- ballistic_profile_id
                'available',
                NEW.return_condition
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_log_custody_to_chain ON custody_records;
CREATE TRIGGER trg_auto_log_custody_to_chain
    AFTER INSERT OR UPDATE ON custody_records
    FOR EACH ROW
    EXECUTE FUNCTION auto_log_custody_to_chain();

-- ============================================
-- AUTOMATIC UNIT MOVEMENT LOGGING TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION auto_log_unit_movement_to_chain()
RETURNS TRIGGER AS $$
DECLARE
    v_event_type VARCHAR(50);
BEGIN
    IF NEW.from_unit_id IS NULL THEN
        v_event_type := 'INITIAL_REGISTRATION';
    ELSIF NEW.movement_type = 'transfer' THEN
        v_event_type := 'UNIT_TRANSFER_OUT';
    ELSE
        v_event_type := 'CROSS_UNIT_MOVEMENT';
    END IF;
    
    PERFORM log_chain_of_custody_event(
        v_event_type,
        NEW.firearm_id,
        NEW.authorized_by,
        NULL,  -- No specific custodian for unit movements
        NEW.to_unit_id,
        NEW.from_unit_id,
        NULL,  -- No previous custodian
        COALESCE(NEW.reason, 'Unit movement: ' || NEW.movement_type),
        NEW.custody_record_id,
        NEW.movement_id,
        NULL,  -- ballistic_profile_id
        NULL,  -- new_status
        NULL,  -- new_condition
        NEW.authorization_reference
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_log_unit_movement_to_chain ON firearm_unit_movements;
CREATE TRIGGER trg_auto_log_unit_movement_to_chain
    AFTER INSERT ON firearm_unit_movements
    FOR EACH ROW
    EXECUTE FUNCTION auto_log_unit_movement_to_chain();

-- ============================================
-- AUTOMATIC BALLISTIC PROFILE LOGGING TRIGGER
-- ============================================

CREATE OR REPLACE FUNCTION auto_log_ballistic_profile_to_chain()
RETURNS TRIGGER AS $$
DECLARE
    v_unit_id UUID;
BEGIN
    -- Get the firearm's current unit
    SELECT assigned_unit_id INTO v_unit_id
    FROM firearms
    WHERE firearm_id = NEW.firearm_id;
    
    PERFORM log_chain_of_custody_event(
        'BALLISTIC_PROFILE_CREATED',
        NEW.firearm_id,
        NEW.created_by,
        NULL,  -- No custodian for ballistic creation
        v_unit_id,
        NULL,  -- No previous unit
        NULL,  -- No previous custodian
        'Ballistic profile created at ' || COALESCE(NEW.forensic_lab, 'unknown lab'),
        NULL,  -- custody_record_id
        NULL,  -- movement_id
        NEW.ballistic_id
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auto_log_ballistic_profile_to_chain ON ballistic_profiles;
CREATE TRIGGER trg_auto_log_ballistic_profile_to_chain
    AFTER INSERT ON ballistic_profiles
    FOR EACH ROW
    EXECUTE FUNCTION auto_log_ballistic_profile_to_chain();

-- ============================================
-- COMMENTS AND DOCUMENTATION
-- ============================================

COMMENT ON TABLE chain_of_custody_audit IS 
'Immutable, append-only chain-of-custody audit log for legal reconstruction. 
Each record contains cryptographic hash linking to previous record (blockchain-style integrity).
Supports who, what, when, where, and why for every custody event.';

COMMENT ON COLUMN chain_of_custody_audit.event_sequence IS 
'Monotonically increasing sequence number for ordering and integrity verification';

COMMENT ON COLUMN chain_of_custody_audit.integrity_hash IS 
'SHA-256 hash of record contents including previous hash (blockchain-style)';

COMMENT ON COLUMN chain_of_custody_audit.reason IS 
'REQUIRED justification for the action - essential for legal chain-of-custody';

COMMENT ON FUNCTION log_chain_of_custody_event IS 
'Centralized function for logging all chain-of-custody events with full denormalized context';

COMMENT ON FUNCTION verify_chain_integrity IS 
'Validates the hash chain for a firearm to detect any tampering';

COMMENT ON FUNCTION export_legal_chain_of_custody IS 
'Exports formatted chain-of-custody data suitable for legal proceedings';
