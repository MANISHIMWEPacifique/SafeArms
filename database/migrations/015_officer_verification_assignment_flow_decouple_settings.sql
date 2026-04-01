-- Migration 015: Move officer verification to custody-assignment flow and decouple from system settings

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'officer_verification_requests'
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conrelid = 'officer_verification_requests'::regclass
              AND conname = 'officer_verification_requests_request_type_check'
        ) THEN
            ALTER TABLE officer_verification_requests
                DROP CONSTRAINT officer_verification_requests_request_type_check;
        END IF;

        ALTER TABLE officer_verification_requests
            ADD CONSTRAINT officer_verification_requests_request_type_check
            CHECK (request_type IN ('custody_assignment', 'custody_return'));

        ALTER TABLE officer_verification_requests
            ALTER COLUMN request_type SET DEFAULT 'custody_assignment';

        UPDATE officer_verification_requests
        SET request_type = 'custody_assignment'
        WHERE request_type = 'custody_return';
    END IF;
END $$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'system_settings'
    ) THEN
        DELETE FROM system_settings
        WHERE setting_key IN (
            'mobile_verification_enabled',
            'mobile_verification_custody_required',
            'mobile_verification_manual_fallback',
            'mobile_verification_ttl_minutes',
            'mobile_verification_incident_mode',
            'mobile_verification_incident_note',
            'mobile_verification_max_invalid_attempts',
            'mobile_verification_cleanup_retention_days',
            'mobile_verification_pilot_units',
            'mobile_verification_metrics_window_days'
        );
    END IF;
END $$;
