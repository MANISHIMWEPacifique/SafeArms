-- Migration 013: Officer mobile verification pilot (custody return)
-- Adds device enrollment and verification request lifecycle tables.

CREATE TABLE IF NOT EXISTS officer_devices (
    device_key VARCHAR(32) PRIMARY KEY,
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id) ON DELETE CASCADE,
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    platform VARCHAR(20) NOT NULL DEFAULT 'unknown' CHECK (platform IN ('android', 'ios', 'web', 'unknown')),
    device_name VARCHAR(120),
    device_fingerprint VARCHAR(120),
    app_version VARCHAR(32),
    token_hash VARCHAR(64) NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    enrolled_by VARCHAR(20) REFERENCES users(user_id),
    enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen_at TIMESTAMP,
    is_revoked BOOLEAN NOT NULL DEFAULT false,
    revoked_at TIMESTAMP,
    revoked_by VARCHAR(20) REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (token_hash)
);

CREATE INDEX IF NOT EXISTS idx_officer_devices_officer_active
    ON officer_devices(officer_id, is_revoked);

CREATE INDEX IF NOT EXISTS idx_officer_devices_unit_active
    ON officer_devices(unit_id, is_revoked);

CREATE INDEX IF NOT EXISTS idx_officer_devices_fingerprint
    ON officer_devices(device_fingerprint)
    WHERE device_fingerprint IS NOT NULL;

CREATE TABLE IF NOT EXISTS officer_verification_requests (
    verification_id VARCHAR(32) PRIMARY KEY,
    request_type VARCHAR(40) NOT NULL DEFAULT 'custody_return' CHECK (request_type IN ('custody_return')),
    custody_id VARCHAR(20) NOT NULL REFERENCES custody_records(custody_id) ON DELETE CASCADE,
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id),
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id),
    firearm_id VARCHAR(20) NOT NULL REFERENCES firearms(firearm_id),
    requested_by VARCHAR(20) NOT NULL REFERENCES users(user_id),
    decision VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending', 'approved', 'rejected', 'expired', 'cancelled')),
    decision_reason TEXT,
    decided_at TIMESTAMP,
    decided_by_officer_id VARCHAR(20) REFERENCES officers(officer_id),
    decided_device_key VARCHAR(32) REFERENCES officer_devices(device_key),
    challenge_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    delivered_at TIMESTAMP,
    consumed_at TIMESTAMP,
    consumed_by VARCHAR(20) REFERENCES users(user_id),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_verification_officer_pending
    ON officer_verification_requests(officer_id, decision, expires_at);

CREATE INDEX IF NOT EXISTS idx_verification_custody
    ON officer_verification_requests(custody_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_verification_unit_pending
    ON officer_verification_requests(unit_id, decision, created_at DESC);

CREATE UNIQUE INDEX IF NOT EXISTS idx_verification_one_pending_per_custody
    ON officer_verification_requests(custody_id)
    WHERE decision = 'pending' AND consumed_at IS NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'system_settings'
    ) THEN
        INSERT INTO system_settings (setting_key, setting_value, description)
        VALUES
            ('mobile_verification_enabled', 'false'::jsonb, 'Enable officer mobile verification workflow'),
            ('mobile_verification_custody_required', 'false'::jsonb, 'Require mobile verification before custody return'),
            ('mobile_verification_ttl_minutes', '10'::jsonb, 'Minutes before pending mobile verification expires'),
            ('mobile_verification_manual_fallback', 'true'::jsonb, 'Allow manual custody return when mobile verification is unavailable')
        ON CONFLICT (setting_key) DO NOTHING;
    END IF;
END $$;