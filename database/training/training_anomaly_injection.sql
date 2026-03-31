-- SafeArms targeted anomaly injection seed
-- Purpose: inject controlled events that should exceed rule thresholds
-- Window: 2026-02-24 to 2026-02-28
-- Total inserted by this file: 17 records

BEGIN;

-- Disable status side effects while bulk-loading historical returned custody records.
ALTER TABLE custody_records DISABLE TRIGGER trg_update_firearm_status;

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
) VALUES
    -- A1) Excessive daily transfers (>6/day) for one firearm in one day
    ('CUS-RW26-A001', 'FA-020', 'OFF-019', 'UNIT-HQ', 'temporary', '2026-02-24 06:00:00', 'USR-002', '2026-02-24 07:00:00', 'USR-002', 3600, 'Rapid handover cycle 1', 'Anomaly injection: excessive daily transfer sequence', 6, 2, false, false),
    ('CUS-RW26-A002', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2026-02-24 07:20:00', 'USR-002', '2026-02-24 08:20:00', 'USR-002', 3600, 'Rapid handover cycle 2', 'Anomaly injection: excessive daily transfer sequence', 7, 2, false, false),
    ('CUS-RW26-A003', 'FA-020', 'OFF-019', 'UNIT-HQ', 'temporary', '2026-02-24 08:40:00', 'USR-002', '2026-02-24 09:40:00', 'USR-002', 3600, 'Rapid handover cycle 3', 'Anomaly injection: excessive daily transfer sequence', 8, 2, false, false),
    ('CUS-RW26-A004', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2026-02-24 10:00:00', 'USR-002', '2026-02-24 11:00:00', 'USR-002', 3600, 'Rapid handover cycle 4', 'Anomaly injection: excessive daily transfer sequence', 10, 2, false, false),
    ('CUS-RW26-A005', 'FA-020', 'OFF-019', 'UNIT-HQ', 'temporary', '2026-02-24 11:20:00', 'USR-002', '2026-02-24 12:20:00', 'USR-002', 3600, 'Rapid handover cycle 5', 'Anomaly injection: excessive daily transfer sequence', 11, 2, false, false),
    ('CUS-RW26-A006', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2026-02-24 13:00:00', 'USR-002', '2026-02-24 14:00:00', 'USR-002', 3600, 'Rapid handover cycle 6', 'Anomaly injection: excessive daily transfer sequence', 13, 2, false, false),
    ('CUS-RW26-A007', 'FA-020', 'OFF-019', 'UNIT-HQ', 'temporary', '2026-02-24 14:20:00', 'USR-002', '2026-02-24 15:20:00', 'USR-002', 3600, 'Rapid handover cycle 7', 'Anomaly injection: excessive daily transfer sequence', 14, 2, false, false),
    ('CUS-RW26-A008', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2026-02-24 16:00:00', 'USR-002', '2026-02-24 17:00:00', 'USR-002', 3600, 'Rapid handover cycle 8', 'Anomaly injection: excessive daily transfer sequence', 16, 2, false, false),

    -- A2) Very short and extended custody durations
    ('CUS-RW26-A009', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2026-02-25 14:00:00', 'USR-004', '2026-02-25 14:45:00', 'USR-004', 2700, 'Brief equipment check', 'Anomaly injection: short custody duration', 14, 3, false, false),
    ('CUS-RW26-A010', 'FA-005', 'OFF-005', 'UNIT-NYA', 'temporary', '2026-02-25 06:00:00', 'USR-004', '2026-02-25 21:00:00', 'USR-004', 54000, 'Extended operation', 'Anomaly injection: extended custody duration', 6, 3, false, false),

    -- A3) Officer rotation spike (>3 firearms in one shift)
    ('CUS-RW26-A011', 'FA-006', 'OFF-010', 'UNIT-KIM', 'temporary', '2026-02-26 07:00:00', 'USR-005', '2026-02-26 08:30:00', 'USR-005', 5400, 'Equipment readiness cycle 1', 'Anomaly injection: officer rotation burst', 7, 4, false, false),
    ('CUS-RW26-A012', 'FA-007', 'OFF-010', 'UNIT-KIM', 'temporary', '2026-02-26 08:45:00', 'USR-005', '2026-02-26 10:15:00', 'USR-005', 5400, 'Equipment readiness cycle 2', 'Anomaly injection: officer rotation burst', 8, 4, false, false),
    ('CUS-RW26-A013', 'FA-008', 'OFF-010', 'UNIT-KIM', 'temporary', '2026-02-26 10:30:00', 'USR-005', '2026-02-26 12:00:00', 'USR-005', 5400, 'Equipment readiness cycle 3', 'Anomaly injection: officer rotation burst', 10, 4, false, false),
    ('CUS-RW26-A014', 'FA-009', 'OFF-010', 'UNIT-KIM', 'temporary', '2026-02-26 12:15:00', 'USR-005', '2026-02-26 13:45:00', 'USR-005', 5400, 'Equipment readiness cycle 4', 'Anomaly injection: officer rotation burst', 12, 4, false, false),
    ('CUS-RW26-A015', 'FA-010', 'OFF-010', 'UNIT-KIM', 'temporary', '2026-02-26 14:00:00', 'USR-005', '2026-02-26 15:30:00', 'USR-005', 5400, 'Equipment readiness cycle 5', 'Anomaly injection: officer rotation burst', 14, 4, false, false),

    -- A4) Cross-unit movement flags
    ('CUS-RW26-A016', 'FA-001', 'OFF-006', 'UNIT-KIM', 'temporary', '2026-02-27 08:00:00', 'USR-005', '2026-02-27 18:00:00', 'USR-005', 36000, 'Joint operation support', 'Anomaly injection: cross-unit movement from UNIT-NYA to UNIT-KIM', 8, 5, false, false),
    ('CUS-RW26-A017', 'FA-013', 'OFF-016', 'UNIT-KIC', 'temporary', '2026-02-27 09:00:00', 'USR-007', '2026-02-27 19:00:00', 'USR-007', 36000, 'Joint operation support', 'Anomaly injection: cross-unit movement from UNIT-REM to UNIT-KIC', 9, 5, false, false)
ON CONFLICT (custody_id) DO NOTHING;

ALTER TABLE custody_records ENABLE TRIGGER trg_update_firearm_status;

COMMIT;
