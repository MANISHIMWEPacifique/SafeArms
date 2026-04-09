-- Migration 019: Externalize anomaly scoring thresholds into system_settings

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'system_settings'
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
