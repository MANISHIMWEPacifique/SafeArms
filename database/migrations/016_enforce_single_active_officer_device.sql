-- Migration 016: Enforce one active officer device per officer.

WITH ranked_active_devices AS (
    SELECT
        device_key,
        ROW_NUMBER() OVER (
            PARTITION BY officer_id
            ORDER BY COALESCE(last_seen_at, enrolled_at, created_at) DESC,
                     created_at DESC,
                     device_key DESC
        ) AS rn
    FROM officer_devices
    WHERE is_revoked = false
)
UPDATE officer_devices d
SET is_revoked = true,
    revoked_at = COALESCE(d.revoked_at, CURRENT_TIMESTAMP),
    updated_at = CURRENT_TIMESTAMP,
    metadata = COALESCE(d.metadata, '{}'::jsonb) || jsonb_build_object(
        'auto_revoked_reason',
        'single_active_device_enforcement'
    )
FROM ranked_active_devices r
WHERE d.device_key = r.device_key
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_officer_devices_one_active_per_officer
    ON officer_devices(officer_id)
    WHERE is_revoked = false;
