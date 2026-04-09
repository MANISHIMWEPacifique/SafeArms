-- Migration 020: Externalize auth rate-limit settings into system_settings

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'system_settings'
    ) THEN
        INSERT INTO system_settings (setting_key, setting_value, description)
        VALUES
            ('auth_rate_limit_window_minutes', '15'::jsonb, 'Rolling window in minutes for auth endpoint rate limiting'),
            ('auth_rate_limit_max_per_ip', '60'::jsonb, 'Maximum auth requests per IP in each auth rate-limit window'),
            ('auth_rate_limit_max_per_account', '10'::jsonb, 'Maximum auth requests per username/account in each auth rate-limit window')
        ON CONFLICT (setting_key) DO NOTHING;
    END IF;
END $$;
