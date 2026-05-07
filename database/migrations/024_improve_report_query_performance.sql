-- 024_improve_report_query_performance.sql

-- 1. Add missing indexes on anomaly status and date to optimize dashboard and reports
CREATE INDEX IF NOT EXISTS idx_anomalies_status ON anomalies(status);
CREATE INDEX IF NOT EXISTS idx_anomalies_detected_at ON anomalies(detected_at);

-- 2. Add covering indexes for report date range filters
CREATE INDEX IF NOT EXISTS idx_cr_issued_returned ON custody_records(issued_at, returned_at);
CREATE INDEX IF NOT EXISTS idx_bp_created_at ON ballistic_profiles(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- 3. Create a Materialized View for anomaly summaries
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_anomaly_summary AS
SELECT 
    DATE_TRUNC('day', detected_at) as report_date,
    unit_id,
    severity,
    status,
    COUNT(*) as anomaly_count
FROM anomalies
GROUP BY 1, 2, 3, 4;

-- Index the materialized view for fast querying
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_anomaly_summary ON mv_anomaly_summary(report_date, unit_id, severity, status);
