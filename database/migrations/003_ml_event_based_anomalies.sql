-- Migration 003: ML Event-Based Anomaly Detection Enhancements
-- Date: 2026-01-28
-- 
-- This migration extends the anomaly detection system to support:
-- 1. EVENT-based detection (not person-based)
-- 2. Chain-of-custody context in anomalies
-- 3. Ballistic access timing features
-- 4. Mandatory review flags for cross-unit transfers
--
-- IMPORTANT: This system evaluates EVENTS, not people.
-- Severity indicates REVIEW URGENCY, not wrongdoing.

-- ============================================
-- ADD NEW COLUMNS TO ANOMALIES TABLE
-- ============================================

-- Add event context column (stores the custody event details)
ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS event_context JSONB DEFAULT NULL;

COMMENT ON COLUMN anomalies.event_context IS 
'Event-centric context: event_type, firearm_id, officer_id, unit_id, is_cross_unit_transfer, previous_unit_id, previous_unit_name, is_first_custody';

-- Add ballistic access context column
ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS ballistic_access_context JSONB DEFAULT NULL;

COMMENT ON COLUMN anomalies.ballistic_access_context IS 
'Ballistic access timing context: has_profile, accesses_24h, timing_score, access_during_custody, access_before_hours, access_after_hours';

-- Add mandatory review flag (for policy-mandated reviews like cross-unit transfers)
ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS is_mandatory_review BOOLEAN DEFAULT FALSE;

COMMENT ON COLUMN anomalies.is_mandatory_review IS 
'True if this anomaly requires mandatory review (e.g., cross-unit transfers). Policy-driven, not risk-based.';

-- Add notification tracking columns if they don't exist
ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS auto_notification_sent BOOLEAN DEFAULT FALSE;

ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS notification_sent_at TIMESTAMP WITH TIME ZONE;

ALTER TABLE anomalies 
ADD COLUMN IF NOT EXISTS notified_users JSONB;

-- ============================================
-- ADD NEW COLUMNS TO ML_TRAINING_FEATURES TABLE
-- ============================================

-- Add cross-unit transfer features
ALTER TABLE ml_training_features 
ADD COLUMN IF NOT EXISTS is_cross_unit_transfer BOOLEAN DEFAULT FALSE;

ALTER TABLE ml_training_features 
ADD COLUMN IF NOT EXISTS cross_unit_transfer_count_30d INTEGER DEFAULT 0;

-- Add ballistic access timing features
ALTER TABLE ml_training_features 
ADD COLUMN IF NOT EXISTS ballistic_accesses_24h INTEGER DEFAULT 0;

ALTER TABLE ml_training_features 
ADD COLUMN IF NOT EXISTS ballistic_access_timing_score NUMERIC(4,3) DEFAULT 0;

-- Add event context column for full feature storage
ALTER TABLE ml_training_features 
ADD COLUMN IF NOT EXISTS event_context JSONB;

-- ============================================
-- CREATE INDEXES FOR NEW QUERY PATTERNS
-- ============================================

-- Index for finding cross-unit transfer anomalies
CREATE INDEX IF NOT EXISTS idx_anomalies_cross_unit 
ON anomalies (anomaly_type) 
WHERE anomaly_type = 'cross_unit_transfer';

-- Index for finding mandatory review items
CREATE INDEX IF NOT EXISTS idx_anomalies_mandatory_review 
ON anomalies (is_mandatory_review, status) 
WHERE is_mandatory_review = true;

-- Index for ballistic timing queries (using GIN for JSONB)
CREATE INDEX IF NOT EXISTS idx_anomalies_ballistic_context 
ON anomalies USING GIN (ballistic_access_context);

-- Index for event context queries
CREATE INDEX IF NOT EXISTS idx_anomalies_event_context 
ON anomalies USING GIN (event_context);

-- Composite index for common dashboard queries
CREATE INDEX IF NOT EXISTS idx_anomalies_dashboard 
ON anomalies (severity, status, detected_at DESC);

-- ============================================
-- UPDATE COMMENTS FOR CLARITY
-- ============================================

COMMENT ON TABLE anomalies IS 
'EVENT-BASED anomaly records. Each record represents a custody EVENT that warrants human review. 
Severity indicates REVIEW URGENCY, not wrongdoing. Cross-unit transfers always trigger mandatory review.';

COMMENT ON COLUMN anomalies.severity IS 
'Review urgency level: critical (same day), high (24h), medium (72h), low (standard queue). NOT an indication of wrongdoing.';

COMMENT ON COLUMN anomalies.anomaly_type IS 
'Primary anomaly classification: cross_unit_transfer, rapid_exchange_pattern, ballistic_access_timing_pattern, unusual_custody_duration, etc.';

-- ============================================
-- ADD NEW ANOMALY TYPES TO ENUM (if using enum)
-- ============================================

-- Note: If anomaly_type is a VARCHAR, no action needed.
-- If it's an ENUM, you would need to add values like:
-- ALTER TYPE anomaly_type_enum ADD VALUE IF NOT EXISTS 'cross_unit_transfer';
-- ALTER TYPE anomaly_type_enum ADD VALUE IF NOT EXISTS 'ballistic_access_before_custody';
-- ALTER TYPE anomaly_type_enum ADD VALUE IF NOT EXISTS 'ballistic_access_after_custody';
-- ALTER TYPE anomaly_type_enum ADD VALUE IF NOT EXISTS 'ballistic_access_timing_pattern';

-- ============================================
-- CREATE VIEW FOR PENDING REVIEWS DASHBOARD
-- ============================================

CREATE OR REPLACE VIEW pending_anomaly_reviews AS
SELECT 
    a.anomaly_id,
    a.anomaly_type,
    a.severity,
    a.anomaly_score,
    a.is_mandatory_review,
    CASE a.severity
        WHEN 'critical' THEN 'Immediate review required'
        WHEN 'high' THEN 'Review within 24 hours'
        WHEN 'medium' THEN 'Review within 72 hours'
        ELSE 'Standard review queue'
    END as review_urgency,
    a.detected_at,
    f.serial_number,
    f.manufacturer || ' ' || f.model as firearm,
    o.full_name as officer_name,
    u.unit_name,
    a.event_context->>'previous_unit_name' as from_unit,
    (a.ballistic_access_context->>'timing_score')::numeric as ballistic_timing_score,
    a.contributing_factors
FROM anomalies a
JOIN firearms f ON a.firearm_id = f.firearm_id
JOIN officers o ON a.officer_id = o.officer_id
JOIN units u ON a.unit_id = u.unit_id
WHERE a.status = 'pending'
ORDER BY 
    CASE a.severity 
        WHEN 'critical' THEN 1 
        WHEN 'high' THEN 2 
        WHEN 'medium' THEN 3 
        ELSE 4 
    END,
    a.is_mandatory_review DESC,
    a.detected_at ASC;

COMMENT ON VIEW pending_anomaly_reviews IS 
'Dashboard view of pending anomaly reviews, ordered by urgency. Severity indicates review priority, NOT wrongdoing.';

-- ============================================
-- CREATE FUNCTION TO GET REVIEW STATISTICS
-- ============================================

CREATE OR REPLACE FUNCTION get_anomaly_review_stats(p_unit_id UUID DEFAULT NULL)
RETURNS TABLE (
    total_pending INTEGER,
    critical_pending INTEGER,
    high_pending INTEGER,
    mandatory_pending INTEGER,
    cross_unit_pending INTEGER,
    ballistic_timing_pending INTEGER,
    avg_pending_age_hours NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_pending,
        COUNT(*) FILTER (WHERE severity = 'critical')::INTEGER as critical_pending,
        COUNT(*) FILTER (WHERE severity = 'high')::INTEGER as high_pending,
        COUNT(*) FILTER (WHERE is_mandatory_review = true)::INTEGER as mandatory_pending,
        COUNT(*) FILTER (WHERE anomaly_type = 'cross_unit_transfer')::INTEGER as cross_unit_pending,
        COUNT(*) FILTER (WHERE (ballistic_access_context->>'timing_score')::numeric > 0.5)::INTEGER as ballistic_timing_pending,
        ROUND(AVG(EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - detected_at)) / 3600)::numeric, 1) as avg_pending_age_hours
    FROM anomalies
    WHERE status = 'pending'
    AND (p_unit_id IS NULL OR unit_id = p_unit_id);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_anomaly_review_stats IS 
'Returns statistics for pending anomaly reviews. Use for dashboard widgets and workload monitoring.';

-- ============================================
-- GRANT PERMISSIONS
-- ============================================

-- Ensure the application user can access new views/functions
-- GRANT SELECT ON pending_anomaly_reviews TO safearms_app;
-- GRANT EXECUTE ON FUNCTION get_anomaly_review_stats TO safearms_app;

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

-- Log migration completion
DO $$
BEGIN
    RAISE NOTICE 'Migration 003_ml_event_based_anomalies completed successfully';
    RAISE NOTICE 'New features: event_context, ballistic_access_context, is_mandatory_review';
    RAISE NOTICE 'New view: pending_anomaly_reviews';
    RAISE NOTICE 'New function: get_anomaly_review_stats()';
END $$;
