-- Migration 033: Forensic demo custody incident records
-- Adds returned custody events that can be used to demonstrate incident-date
-- custody overlap in forensic search.
--
-- Safety notes:
-- - Does not touch ml_training_features, ml_model_metadata, or system_settings.
-- - Does not add anomalies or retrain the model.
-- - Temporarily disables only the firearm-status trigger so historical returned
--   records do not incorrectly mark firearms as currently in custody.
-- - Uses ON CONFLICT DO NOTHING so it can be re-run safely.

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
) 
SELECT
    v.custody_id,
    v.firearm_id,
    v.officer_id,
    v.unit_id,
    v.custody_type,
    v.issued_at::timestamp,
    v.issued_by,
    v.returned_at::timestamp,
    v.returned_to,
    v.custody_duration_seconds::integer,
    v.assignment_reason,
    v.notes,
    v.issue_hour::integer,
    v.issue_day_of_week::integer,
    v.is_night_issue::boolean,
    v.is_weekend_issue::boolean
FROM (VALUES
    (
        'CUS-F01',
        'FA-006',
        'OFF-006',
        'UNIT-KIM',
        'temporary',
        '2025-08-04 12:30:00',
        'USR-005',
        '2025-08-04 20:30:00',
        'USR-005',
        28800,
        'Demo incident CAS-2025-0311 - Amahoro perimeter response',
        'Assigned and returned same day. Incident date 2025-08-04; recovered 7.62x39 casing can be compared with AK-103 profile BP-005.',
        12,
        1,
        false,
        false
    ),
    (
        'CUS-F02',
        'FA-007',
        'OFF-007',
        'UNIT-KIM',
        'temporary',
        '2025-08-04 06:45:00',
        'USR-005',
        '2025-08-04 18:15:00',
        'USR-005',
        41400,
        'Demo incident CAS-2025-0311 - Kimironko market patrol',
        'Assigned and returned same day. Same incident date as CAS-2025-0311; AKM profile BP-006 is a plausible comparison alternative.',
        6,
        1,
        false,
        false
    ),
    (
        'CUS-F03',
        'FA-001',
        'OFF-001',
        'UNIT-NYA',
        'temporary',
        '2025-08-05 15:30:00',
        'USR-004',
        '2025-08-05 22:00:00',
        'USR-004',
        23400,
        'Demo incident CAS-2025-0318 - Nyamirambo evening response',
        'Assigned and returned after evening response. Incident date 2025-08-05; AK-47 profile BP-001 should appear as a custody-overlap candidate.',
        15,
        2,
        false,
        false
    ),
    (
        'CUS-F04',
        'FA-015',
        'OFF-016',
        'UNIT-KIC',
        'temporary',
        '2025-08-08 11:00:00',
        'USR-007',
        '2025-08-08 19:00:00',
        'USR-007',
        28800,
        'Demo incident CAS-2025-0330 - Kicukiro roadblock support',
        'Assigned and returned same day. Incident date 2025-08-08; AKM profile BP-010 gives a second Kicukiro AK-family comparison.',
        11,
        5,
        false,
        false
    ),
    (
        'CUS-F05',
        'FA-008',
        'OFF-008',
        'UNIT-KIM',
        'temporary',
        '2025-08-09 06:30:00',
        'USR-005',
        '2025-08-09 18:00:00',
        'USR-005',
        41400,
        'Demo incident CAS-2025-0342 - stadium perimeter rifle detail',
        'Assigned and returned same day. Incident date 2025-08-09; AR-15 profile BP-007 gives an alternative to HQ M4 profile BP-012.',
        6,
        6,
        false,
        true
    ),
    (
        'CUS-F04L',
        'FA-017',
        'OFF-009',
        'UNIT-KIC',
        'temporary',
        '2025-08-08 11:00:00',
        'USR-007',
        '2025-08-08 19:00:00',
        'USR-007',
        28800,
        'Demo incident CAS-2025-0330 - Kicukiro roadblock support',
        'Compatibility row for older demo databases. Incident date 2025-08-08; Type 81 profile BP-017 gives a Kicukiro AK-family comparison.',
        11,
        5,
        false,
        false
    )
) AS v(
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
JOIN firearms f ON f.firearm_id = v.firearm_id
JOIN officers o ON o.officer_id = v.officer_id
JOIN units un ON un.unit_id = v.unit_id
JOIN users issuer ON issuer.user_id = v.issued_by
JOIN users receiver ON receiver.user_id = v.returned_to
ON CONFLICT (custody_id) DO NOTHING;

ALTER TABLE custody_records ENABLE TRIGGER trg_update_firearm_status;

INSERT INTO audit_logs (
    log_id,
    user_id,
    action_type,
    table_name,
    record_id,
    new_values,
    success
) 
SELECT
    v.log_id,
    v.user_id,
    v.action_type,
    v.table_name,
    v.record_id,
    v.new_values::jsonb,
    v.success::boolean
FROM (VALUES
    (
        'L-F001',
        'USR-005',
        'CREATE',
        'custody_records',
        'CUS-F01',
        '{"action": "Demo custody insert", "case": "CAS-2025-0311", "firearm_id": "FA-006", "incident_date": "2025-08-04"}',
        true
    ),
    (
        'L-F002',
        'USR-005',
        'CREATE',
        'custody_records',
        'CUS-F02',
        '{"action": "Demo custody insert", "case": "CAS-2025-0311", "firearm_id": "FA-007", "incident_date": "2025-08-04"}',
        true
    ),
    (
        'L-F003',
        'USR-004',
        'CREATE',
        'custody_records',
        'CUS-F03',
        '{"action": "Demo custody insert", "case": "CAS-2025-0318", "firearm_id": "FA-001", "incident_date": "2025-08-05"}',
        true
    ),
    (
        'L-F004',
        'USR-007',
        'CREATE',
        'custody_records',
        'CUS-F04',
        '{"action": "Demo custody insert", "case": "CAS-2025-0330", "firearm_id": "FA-015", "incident_date": "2025-08-08"}',
        true
    ),
    (
        'L-F005',
        'USR-005',
        'CREATE',
        'custody_records',
        'CUS-F05',
        '{"action": "Demo custody insert", "case": "CAS-2025-0342", "firearm_id": "FA-008", "incident_date": "2025-08-09"}',
        true
    ),
    (
        'L-F04L',
        'USR-007',
        'CREATE',
        'custody_records',
        'CUS-F04L',
        '{"action": "Demo custody insert", "case": "CAS-2025-0330", "firearm_id": "FA-017", "incident_date": "2025-08-08"}',
        true
    )
) AS v(
    log_id,
    user_id,
    action_type,
    table_name,
    record_id,
    new_values,
    success
)
JOIN custody_records cr ON cr.custody_id = v.record_id
JOIN users u ON u.user_id = v.user_id
ON CONFLICT (log_id) DO NOTHING;

INSERT INTO ballistic_access_logs (
    access_id,
    ballistic_id,
    firearm_id,
    accessed_by,
    access_type,
    access_reason,
    firearm_status_at_access,
    current_custody_officer_id,
    current_custody_unit_id
) 
SELECT
    v.access_id,
    v.ballistic_id,
    v.firearm_id,
    v.accessed_by,
    v.access_type,
    v.access_reason,
    v.firearm_status_at_access,
    v.current_custody_officer_id,
    v.current_custody_unit_id
FROM (VALUES
    (
        'BAL-F01',
        'BP-005',
        'FA-006',
        'USR-009',
        'forensic_query',
        'Demo case CAS-2025-0311 - compare recovered 7.62x39 casing with AK-103 profile',
        'available',
        NULL,
        'UNIT-KIM'
    ),
    (
        'BAL-F02',
        'BP-006',
        'FA-007',
        'USR-009',
        'forensic_query',
        'Demo case CAS-2025-0311 - AKM alternative comparison on same incident date',
        'available',
        NULL,
        'UNIT-KIM'
    ),
    (
        'BAL-F03',
        'BP-001',
        'FA-001',
        'USR-008',
        'forensic_query',
        'Demo case CAS-2025-0318 - Nyamirambo AK-family evidence comparison',
        'available',
        NULL,
        'UNIT-NYA'
    ),
    (
        'BAL-F04',
        'BP-010',
        'FA-015',
        'USR-009',
        'forensic_query',
        'Demo case CAS-2025-0330 - Kicukiro AKM comparison with custody overlap',
        'available',
        NULL,
        'UNIT-KIC'
    ),
    (
        'BAL-F05',
        'BP-007',
        'FA-008',
        'USR-008',
        'forensic_query',
        'Demo case CAS-2025-0342 - AR-15 comparison alternative for 5.56 evidence',
        'available',
        NULL,
        'UNIT-KIM'
    ),
    (
        'BAL-F04L',
        'BP-017',
        'FA-017',
        'USR-009',
        'forensic_query',
        'Demo case CAS-2025-0330 - Type 81 comparison for older Kicukiro demo database',
        'available',
        NULL,
        'UNIT-KIC'
    )
) AS v(
    access_id,
    ballistic_id,
    firearm_id,
    accessed_by,
    access_type,
    access_reason,
    firearm_status_at_access,
    current_custody_officer_id,
    current_custody_unit_id
)
JOIN ballistic_profiles bp ON bp.ballistic_id = v.ballistic_id AND bp.firearm_id = v.firearm_id
JOIN firearms f ON f.firearm_id = v.firearm_id
JOIN users u ON u.user_id = v.accessed_by
LEFT JOIN officers o ON o.officer_id = v.current_custody_officer_id
JOIN units un ON un.unit_id = v.current_custody_unit_id
WHERE v.current_custody_officer_id IS NULL OR o.officer_id IS NOT NULL
ON CONFLICT (access_id) DO NOTHING;
