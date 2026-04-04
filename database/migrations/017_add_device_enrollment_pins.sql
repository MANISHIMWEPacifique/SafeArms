-- Migration 017: Admin-initiated device enrollment PINs
CREATE TABLE IF NOT EXISTS device_enrollment_pins (
    pin VARCHAR(6) PRIMARY KEY,
    officer_id VARCHAR(20) NOT NULL REFERENCES officers(officer_id) ON DELETE CASCADE,
    unit_id VARCHAR(20) NOT NULL REFERENCES units(unit_id) ON DELETE CASCADE,
    created_by VARCHAR(20) REFERENCES users(user_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_enrollment_pins_officer ON device_enrollment_pins(officer_id);
