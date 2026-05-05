-- Migration 022: Dashboard Performance Indexes
-- Fixes pool exhaustion and timeouts effectively caused by unindexed JSONB extracts 
-- on audit_logs, particularly for recentActivities and roleActivity queries.

-- 1. Index for HQ/Admin roleActivity query
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_actor_role 
ON audit_logs ((new_values->>'actor_role')) 
WHERE new_values->>'actor_role' IS NOT NULL;

-- 2. GIN Index for rapid JSONB containment and key checks
-- This allows speeding up OR conditions if rewritten properly, or at least supports
-- high-speed json filters in recentActivities.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_new_values_gin
ON audit_logs USING GIN (new_values);

-- 3. Composite for recentActivities timestamp scanning
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_success_created
ON audit_logs (success, created_at DESC);
