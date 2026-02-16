-- SafeArms Database Migration
-- Sync schema with backend models and routes
-- Run this on existing databases to add missing objects
-- Date: 2026-02-16

-- ============================================
-- 1. ADD MISSING COLUMNS TO anomalies TABLE
-- ============================================

ALTER TABLE anomalies
    ADD COLUMN IF NOT EXISTS is_mandatory_review BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS event_context JSONB,
    ADD COLUMN IF NOT EXISTS ballistic_access_context JSONB;

-- ============================================
-- 2. FIX CHECK CONSTRAINTS
-- ============================================

-- Fix anomalies.status: add 'pending' value
ALTER TABLE anomalies DROP CONSTRAINT IF EXISTS anomalies_status_check;
ALTER TABLE anomalies ADD CONSTRAINT anomalies_status_check
    CHECK (status IN ('open', 'pending', 'investigating', 'resolved', 'false_positive'));

-- Fix loss_reports.status: add 'under_investigation' value
ALTER TABLE loss_reports DROP CONSTRAINT IF EXISTS loss_reports_status_check;
ALTER TABLE loss_reports ADD CONSTRAINT loss_reports_status_check
    CHECK (status IN ('pending', 'approved', 'rejected', 'under_investigation'));

-- ============================================
-- 3. ADD SEQUENCES FOR AUTO-ID GENERATION
-- ============================================

CREATE SEQUENCE IF NOT EXISTS firearms_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS loss_reports_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS destruction_requests_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS procurement_requests_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS audit_logs_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS ballistic_access_id_seq START 1;

-- Sync sequences with existing data (NULLIF handles IDs with no digits)
SELECT setval('firearms_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(firearm_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM firearms), 0) + 1,
    false);

SELECT setval('loss_reports_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(loss_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM loss_reports), 0) + 1,
    false);

SELECT setval('destruction_requests_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(destruction_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM destruction_requests), 0) + 1,
    false);

SELECT setval('procurement_requests_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(procurement_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM procurement_requests), 0) + 1,
    false);

SELECT setval('audit_logs_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(log_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM audit_logs), 0) + 1,
    false);

SELECT setval('ballistic_access_id_seq',
    COALESCE((SELECT MAX(CAST(NULLIF(REGEXP_REPLACE(access_id, '[^0-9]', '', 'g'), '') AS INTEGER)) FROM ballistic_access_logs), 0) + 1,
    false);

-- ============================================
-- 4. CREATE ID GENERATION FUNCTIONS & TRIGGERS
-- ============================================

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

-- Create triggers (drop first to avoid duplicates)
DROP TRIGGER IF EXISTS trg_generate_firearm_id ON firearms;
CREATE TRIGGER trg_generate_firearm_id BEFORE INSERT ON firearms
    FOR EACH ROW EXECUTE FUNCTION generate_firearm_id();

DROP TRIGGER IF EXISTS trg_generate_loss_id ON loss_reports;
CREATE TRIGGER trg_generate_loss_id BEFORE INSERT ON loss_reports
    FOR EACH ROW EXECUTE FUNCTION generate_loss_id();

DROP TRIGGER IF EXISTS trg_generate_destruction_id ON destruction_requests;
CREATE TRIGGER trg_generate_destruction_id BEFORE INSERT ON destruction_requests
    FOR EACH ROW EXECUTE FUNCTION generate_destruction_id();

DROP TRIGGER IF EXISTS trg_generate_procurement_id ON procurement_requests;
CREATE TRIGGER trg_generate_procurement_id BEFORE INSERT ON procurement_requests
    FOR EACH ROW EXECUTE FUNCTION generate_procurement_id();

DROP TRIGGER IF EXISTS trg_generate_audit_log_id ON audit_logs;
CREATE TRIGGER trg_generate_audit_log_id BEFORE INSERT ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION generate_audit_log_id();

-- ============================================
-- 5. CREATE log_ballistic_access FUNCTION
-- ============================================

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
    v_access_id := 'BAL-' || LPAD(nextval('ballistic_access_id_seq')::TEXT, 4, '0');

    SELECT bp.firearm_id, f.current_status
    INTO v_firearm_id, v_firearm_status
    FROM ballistic_profiles bp
    JOIN firearms f ON bp.firearm_id = f.firearm_id
    WHERE bp.ballistic_id = p_ballistic_id;

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
-- 6. CREATE MISSING VIEWS
-- ============================================

-- Custody chain timeline view
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
    LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) AS previous_unit_id,
    CASE WHEN LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) IS NOT NULL
         AND LAG(cr.unit_id) OVER (PARTITION BY cr.firearm_id ORDER BY cr.issued_at ASC) != cr.unit_id
         THEN true ELSE false END AS is_cross_unit_transfer
FROM custody_records cr
JOIN officers o ON cr.officer_id = o.officer_id
JOIN units u ON cr.unit_id = u.unit_id
LEFT JOIN users issued_user ON cr.issued_by = issued_user.user_id
LEFT JOIN users returned_user ON cr.returned_to = returned_user.user_id;

-- Firearm traceability timeline view
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

-- Unified firearm events timeline view
CREATE OR REPLACE VIEW unified_firearm_events_timeline AS
SELECT
    'custody' AS event_category,
    cr.custody_id AS event_id,
    cr.firearm_id,
    cr.issued_at AS event_timestamp,
    CASE WHEN cr.returned_at IS NOT NULL THEN 'Custody Returned' ELSE 'Custody Issued' END AS event_title,
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
-- 7. CREATE TRACEABILITY FUNCTION
-- ============================================

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
-- 8. REFRESH MATERIALIZED VIEWS (if they exist)
-- ============================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'officer_behavior_profile') THEN
        REFRESH MATERIALIZED VIEW officer_behavior_profile;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'firearm_usage_profile') THEN
        REFRESH MATERIALIZED VIEW firearm_usage_profile;
    END IF;
END $$;

-- Migration complete
