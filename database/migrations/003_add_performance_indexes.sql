-- ============================================
-- Migration 003: Performance Indexes
-- ============================================
-- Fixes slow queries caused by missing indexes on:
-- - Workflow tables (loss_reports, destruction_requests, procurement_requests)
-- - Audit logs composite indexes
-- - Custody records composite indexes for active custody queries
-- - Anomalies composite indexes for dashboard/list queries
--
-- These indexes target the specific slow queries identified in production:
-- - GET /api/dashboard (68s -> should be <2s)
-- - GET /api/anomalies (46s -> should be <1s)
-- - GET /api/reports/loss (60s -> should be <1s)
-- - GET /api/approvals/pending (8s -> should be <1s)
-- - GET /api/firearms/stats (6s -> should be <500ms)

-- ============================================
-- LOSS REPORTS: Missing FK and filter indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_loss_reports_firearm_id ON loss_reports(firearm_id);
CREATE INDEX IF NOT EXISTS idx_loss_reports_unit_id ON loss_reports(unit_id);
CREATE INDEX IF NOT EXISTS idx_loss_reports_reported_by ON loss_reports(reported_by);
CREATE INDEX IF NOT EXISTS idx_loss_reports_created_at ON loss_reports(created_at DESC);
-- Composite for pending approvals query (status + created_at for ORDER BY)
CREATE INDEX IF NOT EXISTS idx_loss_reports_status_created ON loss_reports(status, created_at DESC);

-- ============================================
-- DESTRUCTION REQUESTS: Missing FK and filter indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_destruction_requests_firearm_id ON destruction_requests(firearm_id);
CREATE INDEX IF NOT EXISTS idx_destruction_requests_unit_id ON destruction_requests(unit_id);
CREATE INDEX IF NOT EXISTS idx_destruction_requests_requested_by ON destruction_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_destruction_requests_created_at ON destruction_requests(created_at DESC);
-- Composite for pending approvals query
CREATE INDEX IF NOT EXISTS idx_destruction_requests_status_created ON destruction_requests(status, created_at DESC);

-- ============================================
-- PROCUREMENT REQUESTS: Missing FK and filter indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_procurement_requests_unit_id ON procurement_requests(unit_id);
CREATE INDEX IF NOT EXISTS idx_procurement_requests_requested_by ON procurement_requests(requested_by);
CREATE INDEX IF NOT EXISTS idx_procurement_requests_created_at ON procurement_requests(created_at DESC);
-- Composite for pending approvals query (status + priority + created_at)
CREATE INDEX IF NOT EXISTS idx_procurement_requests_status_created ON procurement_requests(status, created_at DESC);

-- ============================================
-- AUDIT LOGS: Composite indexes for dashboard queries
-- ============================================
-- Dashboard recent activities query: WHERE success = true ORDER BY created_at DESC
CREATE INDEX IF NOT EXISTS idx_audit_logs_success_created ON audit_logs(success, created_at DESC);
-- Dashboard station commander query: filters by user unit
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_created ON audit_logs(user_id, created_at DESC);

-- ============================================
-- CUSTODY RECORDS: Composite indexes for active custody & dashboard
-- ============================================
-- Active custody count: WHERE returned_at IS NULL (partial index)
CREATE INDEX IF NOT EXISTS idx_custody_active ON custody_records(unit_id) WHERE returned_at IS NULL;
-- Dashboard recent custody: ORDER BY issued_at DESC with JOINs
CREATE INDEX IF NOT EXISTS idx_custody_issued_desc ON custody_records(issued_at DESC);
-- Composite for unit-scoped active custody
CREATE INDEX IF NOT EXISTS idx_custody_unit_returned ON custody_records(unit_id, returned_at);

-- ============================================
-- ANOMALIES: Composite indexes for list/filter queries
-- ============================================
-- Dashboard anomaly stats: WHERE detected_at >= ... GROUP BY severity
CREATE INDEX IF NOT EXISTS idx_anomalies_detected_severity ON anomalies(detected_at, severity);
-- Unit-scoped anomaly stats
CREATE INDEX IF NOT EXISTS idx_anomalies_unit_detected ON anomalies(unit_id, detected_at DESC);
-- List query with status filter + ORDER BY
CREATE INDEX IF NOT EXISTS idx_anomalies_status_detected ON anomalies(status, detected_at DESC);
-- Composite for investigator dashboard: status IN (...) with severity
CREATE INDEX IF NOT EXISTS idx_anomalies_status_severity ON anomalies(status, severity);

-- ============================================
-- FIREARMS: Additional composite indexes
-- ============================================
-- Stats query: unit + status
CREATE INDEX IF NOT EXISTS idx_firearms_unit_status ON firearms(assigned_unit_id, current_status);
-- List query: unit + created_at ordering
CREATE INDEX IF NOT EXISTS idx_firearms_unit_created ON firearms(assigned_unit_id, created_at DESC);
-- Active firearms (partial index)
CREATE INDEX IF NOT EXISTS idx_firearms_active ON firearms(is_active) WHERE is_active = true;

-- ============================================
-- BALLISTIC PROFILES: For investigator dashboard
-- ============================================
CREATE INDEX IF NOT EXISTS idx_ballistic_profiles_created ON ballistic_profiles(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ballistic_profiles_firearm ON ballistic_profiles(firearm_id);

-- ============================================
-- OFFICERS: For active count queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_officers_unit_active ON officers(unit_id, is_active);

-- ============================================
-- UNITS: For active count queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_units_active ON units(is_active) WHERE is_active = true;

-- ============================================
-- USERS: For active count queries
-- ============================================
CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true;

-- ============================================
-- REFRESH STATISTICS
-- ============================================
ANALYZE loss_reports;
ANALYZE destruction_requests;
ANALYZE procurement_requests;
ANALYZE audit_logs;
ANALYZE custody_records;
ANALYZE anomalies;
ANALYZE firearms;
ANALYZE ballistic_profiles;
ANALYZE officers;
ANALYZE units;
ANALYZE users;
