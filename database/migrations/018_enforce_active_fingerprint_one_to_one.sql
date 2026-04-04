-- Migration 018: Enforce active device fingerprint one-to-one binding.
-- Policy:
-- 1) Keep newest active enrollment per fingerprint.
-- 2) Revoke older active duplicates.
-- 3) Enforce uniqueness for active fingerprints going forward.

WITH ranked_active_fingerprints AS (
    SELECT
        device_key,
        ROW_NUMBER() OVER (
            PARTITION BY lower(device_fingerprint)
            ORDER BY COALESCE(last_seen_at, enrolled_at, created_at) DESC,
                     created_at DESC,
                     device_key DESC
        ) AS rn
    FROM officer_devices
    WHERE is_revoked = false
      AND device_fingerprint IS NOT NULL
      AND btrim(device_fingerprint) <> ''
)
UPDATE officer_devices d
SET is_revoked = true,
    revoked_at = COALESCE(d.revoked_at, CURRENT_TIMESTAMP),
    updated_at = CURRENT_TIMESTAMP,
    metadata = COALESCE(d.metadata, '{}'::jsonb) || jsonb_build_object(
        'auto_revoked_reason',
        'active_fingerprint_uniqueness_enforcement'
    )
FROM ranked_active_fingerprints r
WHERE d.device_key = r.device_key
  AND r.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS idx_officer_devices_one_active_fingerprint
    ON officer_devices ((lower(device_fingerprint)))
    WHERE is_revoked = false
      AND device_fingerprint IS NOT NULL
      AND btrim(device_fingerprint) <> '';
