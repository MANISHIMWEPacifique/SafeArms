-- Migration 014: Officer verification hardening and operational controls

CREATE TABLE IF NOT EXISTS officer_verification_events (
    event_id BIGSERIAL PRIMARY KEY,
    verification_id VARCHAR(32) REFERENCES officer_verification_requests(verification_id) ON DELETE CASCADE,
    custody_id VARCHAR(20) REFERENCES custody_records(custody_id) ON DELETE SET NULL,
    officer_id VARCHAR(20) REFERENCES officers(officer_id) ON DELETE SET NULL,
    unit_id VARCHAR(20) REFERENCES units(unit_id) ON DELETE SET NULL,
    device_key VARCHAR(32) REFERENCES officer_devices(device_key) ON DELETE SET NULL,
    event_type VARCHAR(60) NOT NULL CHECK (
        event_type IN (
            'REQUEST_CREATED',
            'REQUEST_REUSED',
            'REQUEST_DELIVERED',
            'REQUEST_EXPIRED',
            'REQUEST_CANCELLED',
            'DECISION_APPROVED',
            'DECISION_REJECTED',
            'REQUEST_CONSUMED',
            'DEVICE_REGISTERED',
            'DEVICE_REVOKED',
            'DEVICE_REASSIGNED',
            'INVALID_CHALLENGE',
            'REPLAY_BLOCKED',
            'MANUAL_FALLBACK_USED'
        )
    ),
    event_status VARCHAR(30),
    reason TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    actor_user_id VARCHAR(20) REFERENCES users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_verification_events_verification
    ON officer_verification_events(verification_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_verification_events_unit
    ON officer_verification_events(unit_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_verification_events_type
    ON officer_verification_events(event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_verification_events_created
    ON officer_verification_events(created_at DESC);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'system_settings'
    ) THEN
        INSERT INTO system_settings (setting_key, setting_value, description)
        VALUES
            ('mobile_verification_incident_mode', 'false'::jsonb, 'Emergency mode allows manual custody fallback while preserving audit traces'),
            ('mobile_verification_incident_note', '""'::jsonb, 'Current incident mode note shown to operators'),
            ('mobile_verification_max_invalid_attempts', '5'::jsonb, 'Maximum invalid challenge attempts before request cancellation'),
            ('mobile_verification_cleanup_retention_days', '30'::jsonb, 'Retention window for operational cleanup of transient verification records'),
            ('mobile_verification_pilot_units', '[]'::jsonb, 'List of unit_id values participating in staged verification enforcement rollout'),
            ('mobile_verification_metrics_window_days', '14'::jsonb, 'Default metrics dashboard time window in days')
        ON CONFLICT (setting_key) DO NOTHING;
    END IF;
END $$;