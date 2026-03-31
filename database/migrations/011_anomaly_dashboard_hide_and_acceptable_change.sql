-- Migration 011: Simplified anomaly workflow support
-- 1) Add acceptable_change as a valid anomaly status
-- 2) Add per-user anomaly dashboard hide table (hide from dashboard only)

ALTER TABLE anomalies DROP CONSTRAINT IF EXISTS anomalies_status_check;
ALTER TABLE anomalies ADD CONSTRAINT anomalies_status_check
    CHECK (status IN ('open', 'pending', 'investigating', 'resolved', 'false_positive', 'acceptable_change'));

CREATE TABLE IF NOT EXISTS anomaly_dashboard_hides (
    hide_id BIGSERIAL PRIMARY KEY,
    anomaly_id VARCHAR(20) NOT NULL REFERENCES anomalies(anomaly_id) ON DELETE CASCADE,
    user_id VARCHAR(20) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    reason TEXT,
    hidden_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (anomaly_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_anomaly_hides_user ON anomaly_dashboard_hides(user_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_hides_anomaly ON anomaly_dashboard_hides(anomaly_id);
CREATE INDEX IF NOT EXISTS idx_anomaly_hides_hidden_at ON anomaly_dashboard_hides(hidden_at);
