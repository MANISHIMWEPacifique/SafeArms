-- Migration: Add system settings table
DROP TABLE IF EXISTS system_settings;

CREATE TABLE system_settings (
    setting_key VARCHAR(100) PRIMARY KEY,
    setting_value JSONB NOT NULL,
    description TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(20) REFERENCES users(user_id)
);

-- Insert defaults if table is empty
INSERT INTO system_settings (setting_key, setting_value, description)
VALUES 
    ('platform_name', '"SafeArms"'::jsonb, 'Name of the platform'),
    ('organization', '"Rwanda National Police"'::jsonb, 'Organization name'),
    ('date_format', '"DD/MM/YYYY"'::jsonb, 'Date format'),
    ('time_format', '"24-hour"'::jsonb, 'Time format'),
    ('items_per_page', '10'::jsonb, 'Items per page'),
    ('session_timeout', '30'::jsonb, 'Session timeout in minutes'),
    ('enforce_2fa', 'false'::jsonb, 'Two factor auth required globally'),
    ('min_password_length', '8'::jsonb, 'Minimum password length'),
    ('max_otp_attempts', '5'::jsonb, 'Max login attempts before lockout'),
    ('otp_validity_minutes', '15'::jsonb, 'OTP validity'),
    ('anomaly_threshold', '0.85'::jsonb, 'Anomaly threshold'),
    ('critical_threshold', '0.95'::jsonb, 'Critical threshold'),
    ('auto_refresh_enabled', 'true'::jsonb, 'Auto refresh enabled'),
    ('auto_refresh_interval', '60'::jsonb, 'Auto refresh interval in seconds'),
    ('notify_critical_anomalies', 'true'::jsonb, 'Notify critical anomalies'),
    ('notify_pending_approvals', 'true'::jsonb, 'Notify pending approvals'),
    ('notify_custody_changes', 'true'::jsonb, 'Notify custody changes')
ON CONFLICT (setting_key) DO NOTHING;
