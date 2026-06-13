-- Migration 037: Preserve mobile verification/device history when operator users are deleted.

ALTER TABLE officer_devices
    DROP CONSTRAINT IF EXISTS officer_devices_enrolled_by_fkey;

ALTER TABLE officer_devices
    ADD CONSTRAINT officer_devices_enrolled_by_fkey
    FOREIGN KEY (enrolled_by)
    REFERENCES users(user_id)
    ON DELETE SET NULL;

ALTER TABLE officer_devices
    DROP CONSTRAINT IF EXISTS officer_devices_revoked_by_fkey;

ALTER TABLE officer_devices
    ADD CONSTRAINT officer_devices_revoked_by_fkey
    FOREIGN KEY (revoked_by)
    REFERENCES users(user_id)
    ON DELETE SET NULL;

ALTER TABLE officer_verification_requests
    ALTER COLUMN requested_by DROP NOT NULL;

ALTER TABLE officer_verification_requests
    DROP CONSTRAINT IF EXISTS officer_verification_requests_requested_by_fkey;

ALTER TABLE officer_verification_requests
    ADD CONSTRAINT officer_verification_requests_requested_by_fkey
    FOREIGN KEY (requested_by)
    REFERENCES users(user_id)
    ON DELETE SET NULL;

ALTER TABLE officer_verification_requests
    DROP CONSTRAINT IF EXISTS officer_verification_requests_consumed_by_fkey;

ALTER TABLE officer_verification_requests
    ADD CONSTRAINT officer_verification_requests_consumed_by_fkey
    FOREIGN KEY (consumed_by)
    REFERENCES users(user_id)
    ON DELETE SET NULL;
