-- Migration: 029_dashboard_timeout_indexes.sql
-- Description: Indexes to optimize slow dashboard analytical queries

-- Functional index for recent custody lists
CREATE INDEX IF NOT EXISTS idx_custody_coalesce_time 
ON custody_records (COALESCE(returned_at, issued_at) DESC);

-- GIN index for audit logs JSONB filtering (used heavily by Station Commander activity feed)
CREATE INDEX IF NOT EXISTS idx_audit_logs_new_values_gin 
ON audit_logs USING GIN (new_values);

-- Covering indexes for fast active counts
CREATE INDEX IF NOT EXISTS idx_units_active_covering 
ON units (is_active) INCLUDE (unit_id)
WHERE is_active = true;

CREATE INDEX IF NOT EXISTS idx_users_active_covering 
ON users (is_active) INCLUDE (user_id)
WHERE is_active = true;
