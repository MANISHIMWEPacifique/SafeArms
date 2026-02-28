-- ============================================
-- Migration 004: Additional Performance Indexes
-- ============================================
-- Targets remaining slow queries from production logs:
-- - Officers queries ORDER BY full_name (3363ms -> <500ms)
-- - Custody records: active count without unit filter
-- - Firearms: full table scan with JOIN on unit
--
-- Run AFTER migration 003.

-- ============================================
-- OFFICERS: Composite index for unit listing sorted by name
-- ============================================
-- Query: SELECT * FROM officers WHERE unit_id = $1 ORDER BY full_name LIMIT $2 OFFSET $3
-- Without this index, PostgreSQL does a sequential scan + sort
CREATE INDEX IF NOT EXISTS idx_officers_unit_fullname ON officers(unit_id, full_name);

-- Composite for active officers by unit (used in custody assignment dropdown)
CREATE INDEX IF NOT EXISTS idx_officers_unit_active_name ON officers(unit_id, is_active, full_name) WHERE is_active = true;

-- ============================================
-- CUSTODY RECORDS: Global active count (no unit filter)
-- ============================================
-- Dashboard query: SELECT COUNT(*) as active_custody FROM custody_records WHERE returned_at IS NULL
-- (no unit_id filter for admin/HQ roles)
CREATE INDEX IF NOT EXISTS idx_custody_returned_at ON custody_records(returned_at) WHERE returned_at IS NULL;

-- Composite for ID generation: filter on pattern + MAX
CREATE INDEX IF NOT EXISTS idx_custody_id_pattern ON custody_records(custody_id) WHERE custody_id ~ '^CUS-[0-9]+$';

-- ============================================
-- FIREARMS: Covering index for listing with unit JOIN
-- ============================================
-- Query: SELECT f.*, u.unit_name FROM firearms f LEFT JOIN units u ON f.assigned_unit_id = u.unit_id
CREATE INDEX IF NOT EXISTS idx_firearms_assigned_unit ON firearms(assigned_unit_id) INCLUDE (serial_number, manufacturer, model, firearm_type, current_status);

-- Available firearms for custody assignment
CREATE INDEX IF NOT EXISTS idx_firearms_available_unit ON firearms(assigned_unit_id, current_status) WHERE current_status = 'available';

-- ============================================
-- ANOMALIES: Global queries (admin/HQ without unit filter)
-- ============================================
-- For dashboard anomaly stats: detected_at filtering + severity grouping
CREATE INDEX IF NOT EXISTS idx_anomalies_global_detected ON anomalies(detected_at DESC, severity);

-- ============================================
-- REFRESH STATISTICS
-- ============================================
ANALYZE officers;
ANALYZE custody_records;
ANALYZE firearms;
ANALYZE anomalies;
