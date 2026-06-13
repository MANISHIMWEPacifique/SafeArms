-- Migration 007: Add explanation_requested fields for anomaly workflow
-- Allow HQ commanders to explicitly request explanations

ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_requested BOOLEAN DEFAULT false;
ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_requested_at TIMESTAMP;
ALTER TABLE anomalies ADD COLUMN IF NOT EXISTS explanation_requested_by VARCHAR(20) REFERENCES users(user_id);

-- Add index to quickly find anomalies where an explanation is requested but not yet provided
CREATE INDEX IF NOT EXISTS idx_anomalies_explanation_requested ON anomalies(explanation_requested) WHERE explanation_requested = true AND explanation_message IS NULL;
