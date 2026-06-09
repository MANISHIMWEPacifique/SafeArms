-- Migration 035: ML training audit/schema hardening
-- Keeps the live database aligned with the consolidated demo schema and
-- makes feature extraction idempotent by custody event.

ALTER TABLE audit_logs
    ADD COLUMN IF NOT EXISTS old_values JSONB,
    ADD COLUMN IF NOT EXISTS reason TEXT,
    ADD COLUMN IF NOT EXISTS actor_role VARCHAR(50),
    ADD COLUMN IF NOT EXISTS actor_unit_name VARCHAR(100),
    ADD COLUMN IF NOT EXISTS subject_type VARCHAR(100),
    ADD COLUMN IF NOT EXISTS subject_id VARCHAR(50),
    ADD COLUMN IF NOT EXISTS is_chain_of_custody_event BOOLEAN DEFAULT false;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
          AND table_name = 'system_settings'
    ) THEN
        INSERT INTO system_settings (setting_key, setting_value, description)
        VALUES
            ('anomaly_trigger_threshold', '0.35'::jsonb, 'Minimum ensemble score required to record an anomaly event'),
            ('anomaly_medium_threshold', '0.50'::jsonb, 'Minimum score mapped to medium review urgency'),
            ('anomaly_high_threshold', '0.70'::jsonb, 'Minimum score mapped to high review urgency'),
            ('anomaly_critical_threshold', '0.85'::jsonb, 'Minimum score mapped to critical review urgency when confidence gate also passes'),
            ('anomaly_critical_min_confidence', '0.60'::jsonb, 'Minimum detector confidence required for critical severity')
        ON CONFLICT (setting_key) DO NOTHING;
    END IF;
END $$;

DELETE FROM ml_training_features a
USING ml_training_features b
WHERE a.custody_record_id = b.custody_record_id
  AND (
      a.feature_extraction_date > b.feature_extraction_date
      OR (
          a.feature_extraction_date = b.feature_extraction_date
          AND a.feature_id > b.feature_id
      )
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_ml_training_features_custody_record_unique
    ON ml_training_features (custody_record_id);
