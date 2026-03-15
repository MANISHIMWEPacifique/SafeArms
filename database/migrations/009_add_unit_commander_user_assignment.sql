-- Migration 009: Add commander_user_id relation for units
-- Allows selecting and reassigning a unit commander from eligible system users

ALTER TABLE units
ADD COLUMN IF NOT EXISTS commander_user_id VARCHAR(20);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE constraint_name = 'fk_units_commander_user'
          AND table_name = 'units'
    ) THEN
        ALTER TABLE units
        ADD CONSTRAINT fk_units_commander_user
        FOREIGN KEY (commander_user_id)
        REFERENCES users(user_id)
        ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_units_commander_user ON units(commander_user_id);

-- Backfill commander_user_id for units where commander_name uniquely matches
-- one active eligible user.
WITH commander_matches AS (
    SELECT
        u.unit_id,
        MIN(usr.user_id) AS commander_user_id,
        COUNT(*) AS match_count
    FROM units u
    JOIN users usr
      ON LOWER(TRIM(usr.full_name)) = LOWER(TRIM(u.commander_name))
    WHERE u.commander_user_id IS NULL
      AND u.commander_name IS NOT NULL
      AND TRIM(u.commander_name) <> ''
      AND usr.is_active = true
      AND usr.role IN ('station_commander', 'hq_firearm_commander')
    GROUP BY u.unit_id
)
UPDATE units u
SET commander_user_id = cm.commander_user_id
FROM commander_matches cm
WHERE u.unit_id = cm.unit_id
  AND cm.match_count = 1;

-- Ensure commander_name matches linked user display name when relation exists.
UPDATE units u
SET commander_name = usr.full_name
FROM users usr
WHERE u.commander_user_id = usr.user_id
  AND u.commander_name IS DISTINCT FROM usr.full_name;
