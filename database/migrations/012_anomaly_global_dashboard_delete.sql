-- Migration 012: Global dashboard-delete metadata for anomalies
-- Dashboard delete should remove anomaly from dashboard views,
-- while retaining it for reports and system records.

ALTER TABLE anomalies
    ADD COLUMN IF NOT EXISTS removed_from_dashboard BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS removed_from_dashboard_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS removed_from_dashboard_by VARCHAR(20) REFERENCES users(user_id),
    ADD COLUMN IF NOT EXISTS removed_from_dashboard_reason TEXT;

CREATE INDEX IF NOT EXISTS idx_anomalies_removed_from_dashboard
    ON anomalies(removed_from_dashboard);
