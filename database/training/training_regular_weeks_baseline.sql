-- SafeArms deterministic 3-week baseline workflow seed
-- Purpose: realistic normal custody operations for model training baseline
-- Window: 2026-02-02 to 2026-02-22
-- Total inserted by this file: 150 records
--   - Weekday regular patrols: 120
--   - Weekend duties: 18
--   - Night shifts: 12

BEGIN;

-- Disable status side effects while bulk-loading historical returned custody records.
ALTER TABLE custody_records DISABLE TRIGGER trg_update_firearm_status;

-- 1) Weekday regular patrol patterns (15 weekdays x 8 patterns = 120 rows)
WITH weekday_dates AS (
    SELECT d::date AS duty_date
    FROM generate_series('2026-02-02'::date, '2026-02-22'::date, '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) BETWEEN 1 AND 5
),
regular_patterns AS (
    SELECT *
    FROM (VALUES
        (1, 'UNIT-NYA', 'USR-004', 'OFF-001', 'FA-001', 7, 11, 'Routine patrol - Nyamirambo sector A'),
        (2, 'UNIT-NYA', 'USR-004', 'OFF-002', 'FA-002', 7, 10, 'Routine patrol - Nyamirambo sector B'),
        (3, 'UNIT-KIM', 'USR-005', 'OFF-006', 'FA-006', 7, 10, 'Routine patrol - Kimironko market zone'),
        (4, 'UNIT-KIM', 'USR-005', 'OFF-007', 'FA-007', 8, 10, 'Routine patrol - Kimironko transport hub'),
        (5, 'UNIT-REM', 'USR-006', 'OFF-011', 'FA-011', 7, 11, 'Routine patrol - Remera commercial district'),
        (6, 'UNIT-REM', 'USR-006', 'OFF-012', 'FA-012', 7, 10, 'Routine patrol - Remera residential blocks'),
        (7, 'UNIT-KIC', 'USR-007', 'OFF-015', 'FA-015', 7, 10, 'Routine patrol - Kicukiro civic center'),
        (8, 'UNIT-KIC', 'USR-007', 'OFF-016', 'FA-016', 8, 10, 'Routine patrol - Kicukiro perimeter road')
    ) AS t(pattern_id, unit_id, issued_by, officer_id, firearm_id, start_hour, base_duration_hours, assignment_reason)
),
generated_weekday AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY wd.duty_date, rp.pattern_id) AS rn,
        wd.duty_date,
        rp.pattern_id,
        rp.unit_id,
        rp.issued_by,
        rp.officer_id,
        rp.firearm_id,
        rp.assignment_reason,
        rp.start_hour + ((EXTRACT(DAY FROM wd.duty_date)::int + rp.pattern_id) % 2) AS issue_hour,
        rp.base_duration_hours + ((EXTRACT(DAY FROM wd.duty_date)::int + rp.pattern_id + 1) % 2) AS duration_hours
    FROM weekday_dates wd
    CROSS JOIN regular_patterns rp
)
INSERT INTO custody_records (
    custody_id,
    firearm_id,
    officer_id,
    unit_id,
    custody_type,
    issued_at,
    issued_by,
    returned_at,
    returned_to,
    custody_duration_seconds,
    assignment_reason,
    notes,
    issue_hour,
    issue_day_of_week,
    is_night_issue,
    is_weekend_issue
)
SELECT
    'CUS-RW26-B' || LPAD(gw.rn::text, 4, '0') AS custody_id,
    gw.firearm_id,
    gw.officer_id,
    gw.unit_id,
    'temporary' AS custody_type,
    (gw.duty_date + make_interval(hours => gw.issue_hour))::timestamp AS issued_at,
    gw.issued_by,
    (gw.duty_date + make_interval(hours => (gw.issue_hour + gw.duration_hours)))::timestamp AS returned_at,
    gw.issued_by AS returned_to,
    gw.duration_hours * 3600 AS custody_duration_seconds,
    gw.assignment_reason,
    'Seeded baseline regular workflow (weekday)' AS notes,
    gw.issue_hour,
    EXTRACT(DOW FROM (gw.duty_date + make_interval(hours => gw.issue_hour)))::int AS issue_day_of_week,
    false AS is_night_issue,
    false AS is_weekend_issue
FROM generated_weekday gw
ON CONFLICT (custody_id) DO NOTHING;

-- 2) Weekend planned duties (6 weekend days x 3 patterns = 18 rows)
WITH weekend_dates AS (
    SELECT d::date AS duty_date
    FROM generate_series('2026-02-02'::date, '2026-02-22'::date, '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) IN (6, 7)
),
weekend_patterns AS (
    SELECT *
    FROM (VALUES
        (1, 'UNIT-NYA', 'USR-004', 'OFF-003', 'FA-003', 8, 8, 'Weekend checkpoint supervision'),
        (2, 'UNIT-KIM', 'USR-005', 'OFF-008', 'FA-008', 8, 8, 'Weekend market crowd management'),
        (3, 'UNIT-KIC', 'USR-007', 'OFF-018', 'FA-017', 8, 7, 'Weekend event perimeter duty')
    ) AS t(pattern_id, unit_id, issued_by, officer_id, firearm_id, start_hour, base_duration_hours, assignment_reason)
),
generated_weekend AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY wd.duty_date, wp.pattern_id) AS rn,
        wd.duty_date,
        wp.pattern_id,
        wp.unit_id,
        wp.issued_by,
        wp.officer_id,
        wp.firearm_id,
        wp.assignment_reason,
        wp.start_hour + ((EXTRACT(DAY FROM wd.duty_date)::int + wp.pattern_id) % 2) AS issue_hour,
        wp.base_duration_hours AS duration_hours
    FROM weekend_dates wd
    CROSS JOIN weekend_patterns wp
)
INSERT INTO custody_records (
    custody_id,
    firearm_id,
    officer_id,
    unit_id,
    custody_type,
    issued_at,
    issued_by,
    returned_at,
    returned_to,
    custody_duration_seconds,
    assignment_reason,
    notes,
    issue_hour,
    issue_day_of_week,
    is_night_issue,
    is_weekend_issue
)
SELECT
    'CUS-RW26-W' || LPAD(gw.rn::text, 4, '0') AS custody_id,
    gw.firearm_id,
    gw.officer_id,
    gw.unit_id,
    'temporary' AS custody_type,
    (gw.duty_date + make_interval(hours => gw.issue_hour))::timestamp AS issued_at,
    gw.issued_by,
    (gw.duty_date + make_interval(hours => (gw.issue_hour + gw.duration_hours)))::timestamp AS returned_at,
    gw.issued_by AS returned_to,
    gw.duration_hours * 3600 AS custody_duration_seconds,
    gw.assignment_reason,
    'Seeded baseline regular workflow (weekend)' AS notes,
    gw.issue_hour,
    EXTRACT(DOW FROM (gw.duty_date + make_interval(hours => gw.issue_hour)))::int AS issue_day_of_week,
    false AS is_night_issue,
    true AS is_weekend_issue
FROM generated_weekend gw
ON CONFLICT (custody_id) DO NOTHING;

-- 3) Planned night shifts (Tue/Thu x 3 weeks x 2 patterns = 12 rows)
WITH night_dates AS (
    SELECT d::date AS duty_date
    FROM generate_series('2026-02-02'::date, '2026-02-22'::date, '1 day') AS d
    WHERE EXTRACT(ISODOW FROM d) IN (2, 4)
),
night_patterns AS (
    SELECT *
    FROM (VALUES
        (1, 'UNIT-NYA', 'USR-004', 'OFF-002', 'FA-002', 22, 8, 'Night patrol and rapid response'),
        (2, 'UNIT-KIM', 'USR-005', 'OFF-007', 'FA-007', 22, 8, 'Night infrastructure protection')
    ) AS t(pattern_id, unit_id, issued_by, officer_id, firearm_id, start_hour, base_duration_hours, assignment_reason)
),
generated_night AS (
    SELECT
        ROW_NUMBER() OVER (ORDER BY nd.duty_date, np.pattern_id) AS rn,
        nd.duty_date,
        np.pattern_id,
        np.unit_id,
        np.issued_by,
        np.officer_id,
        np.firearm_id,
        np.assignment_reason,
        np.start_hour AS issue_hour,
        np.base_duration_hours AS duration_hours
    FROM night_dates nd
    CROSS JOIN night_patterns np
)
INSERT INTO custody_records (
    custody_id,
    firearm_id,
    officer_id,
    unit_id,
    custody_type,
    issued_at,
    issued_by,
    returned_at,
    returned_to,
    custody_duration_seconds,
    assignment_reason,
    notes,
    issue_hour,
    issue_day_of_week,
    is_night_issue,
    is_weekend_issue
)
SELECT
    'CUS-RW26-N' || LPAD(gn.rn::text, 4, '0') AS custody_id,
    gn.firearm_id,
    gn.officer_id,
    gn.unit_id,
    'temporary' AS custody_type,
    (gn.duty_date + make_interval(hours => gn.issue_hour))::timestamp AS issued_at,
    gn.issued_by,
    (gn.duty_date + make_interval(hours => (gn.issue_hour + gn.duration_hours)))::timestamp AS returned_at,
    gn.issued_by AS returned_to,
    gn.duration_hours * 3600 AS custody_duration_seconds,
    gn.assignment_reason,
    'Seeded baseline regular workflow (night shift)' AS notes,
    gn.issue_hour,
    EXTRACT(DOW FROM (gn.duty_date + make_interval(hours => gn.issue_hour)))::int AS issue_day_of_week,
    true AS is_night_issue,
    false AS is_weekend_issue
FROM generated_night gn
ON CONFLICT (custody_id) DO NOTHING;

ALTER TABLE custody_records ENABLE TRIGGER trg_update_firearm_status;

COMMIT;
