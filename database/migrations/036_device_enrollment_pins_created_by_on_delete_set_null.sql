-- Migration 036: Preserve enrollment PIN history when the creator user is deleted.
ALTER TABLE device_enrollment_pins
    DROP CONSTRAINT IF EXISTS device_enrollment_pins_created_by_fkey;

ALTER TABLE device_enrollment_pins
    ADD CONSTRAINT device_enrollment_pins_created_by_fkey
    FOREIGN KEY (created_by)
    REFERENCES users(user_id)
    ON DELETE SET NULL;
