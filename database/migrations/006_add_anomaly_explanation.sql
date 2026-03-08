-- Migration 006: Add explanation fields for critical anomaly workflow
-- Critical anomalies require station commanders to explain to HQ

-- Add explanation fields to anomalies table
ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_message TEXT;
ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_by VARCHAR(20) REFERENCES users(user_id);
ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_date TIMESTAMP;

-- Index for finding anomalies needing explanation
CREATE INDEX IF NOT EXISTS idx_anomalies_explanation ON anomalies(severity, explanation_message) WHERE severity = 'critical' AND explanation_message IS NULL;
