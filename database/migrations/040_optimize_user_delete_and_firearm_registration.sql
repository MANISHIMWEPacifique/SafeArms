-- Migration 040: Optimize slow user deletion and firearm registration paths.
-- - Adds sequence-backed ballistic profile IDs to avoid MAX scans.
-- - Synchronizes ID sequences so sequence-based inserts do not collide.
-- - Adds indexes for user deletion cleanup queries.

CREATE SEQUENCE IF NOT EXISTS ballistic_profiles_id_seq START 1;

SELECT setval(
    'firearms_id_seq',
    COALESCE(
        (
            SELECT MAX(
                CAST(NULLIF(REGEXP_REPLACE(firearm_id, '[^0-9]', '', 'g'), '') AS INTEGER)
            )
            FROM firearms
        ),
        0
    ) + 1,
    false
);

SELECT setval(
    'ballistic_profiles_id_seq',
    COALESCE(
        (
            SELECT MAX(
                CAST(NULLIF(REGEXP_REPLACE(ballistic_id, '[^0-9]', '', 'g'), '') AS INTEGER)
            )
            FROM ballistic_profiles
        ),
        0
    ) + 1,
    false
);

CREATE OR REPLACE FUNCTION generate_firearm_id()
RETURNS TRIGGER AS $$
DECLARE
    next_id_number TEXT;
BEGIN
    IF NEW.firearm_id IS NULL OR NEW.firearm_id = '' THEN
        next_id_number := nextval('firearms_id_seq')::TEXT;
        NEW.firearm_id := 'FA-' ||
            CASE
                WHEN LENGTH(next_id_number) >= 3 THEN next_id_number
                ELSE LPAD(next_id_number, 3, '0')
            END;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE INDEX IF NOT EXISTS idx_users_created_by
    ON users(created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_system_settings_updated_by
    ON system_settings(updated_by)
    WHERE updated_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_device_enrollment_pins_created_by
    ON device_enrollment_pins(created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_officer_devices_enrolled_by
    ON officer_devices(enrolled_by)
    WHERE enrolled_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_officer_devices_revoked_by
    ON officer_devices(revoked_by)
    WHERE revoked_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_officer_verification_requests_requested_by
    ON officer_verification_requests(requested_by)
    WHERE requested_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_officer_verification_requests_consumed_by
    ON officer_verification_requests(consumed_by)
    WHERE consumed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_officer_verification_events_actor_user
    ON officer_verification_events(actor_user_id)
    WHERE actor_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomalies_removed_by
    ON anomalies(removed_from_dashboard_by)
    WHERE removed_from_dashboard_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomalies_archived_by
    ON anomalies(archived_by)
    WHERE archived_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomalies_investigated_by
    ON anomalies(investigated_by)
    WHERE investigated_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomalies_explanation_by
    ON anomalies(explanation_by)
    WHERE explanation_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomalies_explanation_requested_by
    ON anomalies(explanation_requested_by)
    WHERE explanation_requested_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_anomaly_investigations_investigator
    ON anomaly_investigations(investigator_id);

CREATE INDEX IF NOT EXISTS idx_ballistic_profiles_created_by
    ON ballistic_profiles(created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ballistic_profiles_locked_by
    ON ballistic_profiles(locked_by)
    WHERE locked_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_custody_issued_by
    ON custody_records(issued_by);

CREATE INDEX IF NOT EXISTS idx_custody_returned_to
    ON custody_records(returned_to)
    WHERE returned_to IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_firearms_registered_by
    ON firearms(registered_by);

CREATE INDEX IF NOT EXISTS idx_firearm_unit_movements_authorized_by
    ON firearm_unit_movements(authorized_by);

CREATE INDEX IF NOT EXISTS idx_loss_reports_reviewed_by
    ON loss_reports(reviewed_by)
    WHERE reviewed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_destruction_requests_reviewed_by
    ON destruction_requests(reviewed_by)
    WHERE reviewed_by IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_procurement_requests_reviewed_by
    ON procurement_requests(reviewed_by)
    WHERE reviewed_by IS NOT NULL;

ANALYZE users;
ANALYZE system_settings;
ANALYZE device_enrollment_pins;
ANALYZE officer_devices;
ANALYZE officer_verification_requests;
ANALYZE officer_verification_events;
ANALYZE units;
ANALYZE anomalies;
ANALYZE anomaly_investigations;
ANALYZE ballistic_profiles;
ANALYZE custody_records;
ANALYZE firearms;
ANALYZE firearm_unit_movements;
ANALYZE loss_reports;
ANALYZE destruction_requests;
ANALYZE procurement_requests;
