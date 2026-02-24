-- ============================================
-- SafeArms Comprehensive Seed Data
-- Rwanda National Police Context
-- ============================================
-- This script populates all tables with realistic data for:
--   • Testing all system features (all roles, workflows)
--   • ML anomaly detection training (150+ custody records)
--   • Forensic investigation search (ballistic profiles)
--   • Workflow testing (loss reports, destructions, procurements)
--
-- Password for ALL users: Admin@123
-- Run via: node src/scripts/runSeedData.js
-- ============================================

-- ============================================
-- CLEAR EXISTING DATA (order matters for FK)
-- ============================================
DELETE FROM anomaly_investigations;
DELETE FROM anomalies;
DELETE FROM ml_training_features;
DELETE FROM ml_model_metadata;
DELETE FROM ballistic_access_logs;
DELETE FROM firearm_unit_movements;
DELETE FROM procurement_requests;
DELETE FROM destruction_requests;
DELETE FROM loss_reports;
DELETE FROM custody_records;
DELETE FROM ballistic_profiles;
DELETE FROM firearms;
DELETE FROM officers;
DELETE FROM audit_logs;
DELETE FROM users;
DELETE FROM units;

-- Reset sequences
ALTER SEQUENCE IF EXISTS firearms_id_seq RESTART WITH 100;
ALTER SEQUENCE IF EXISTS loss_reports_id_seq RESTART WITH 100;
ALTER SEQUENCE IF EXISTS destruction_requests_id_seq RESTART WITH 100;
ALTER SEQUENCE IF EXISTS procurement_requests_id_seq RESTART WITH 100;
ALTER SEQUENCE IF EXISTS audit_logs_id_seq RESTART WITH 100;
ALTER SEQUENCE IF EXISTS ballistic_access_id_seq RESTART WITH 100;

-- ============================================
-- 1. UNITS (6 units)
-- ============================================
INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name, is_active) VALUES
  ('UNIT-HQ',  'Rwanda National Police Headquarters',  'headquarters', 'Kacyiru, Kigali',              'Kigali',   'Gasabo',      '+250788000100', 'hq@rnp.gov.rw',          'Commissioner General',     true),
  ('UNIT-NYA', 'Nyamirambo Police Station',             'station',      'Nyamirambo, Kigali',           'Kigali',   'Nyarugenge',  '+250788000200', 'nyamirambo@rnp.gov.rw',  'CSP Mugabo Jean',          true),
  ('UNIT-KIM', 'Kimironko Police Station',              'station',      'Kimironko, Kigali',            'Kigali',   'Gasabo',      '+250788000300', 'kimironko@rnp.gov.rw',   'CSP Uwimana Marie',        true),
  ('UNIT-REM', 'Remera Police Station',                 'station',      'Remera, Kigali',               'Kigali',   'Gasabo',      '+250788000400', 'remera@rnp.gov.rw',      'CSP Habimana Pierre',      true),
  ('UNIT-KIC', 'Kicukiro Police Station',               'station',      'Kicukiro, Kigali',             'Kigali',   'Kicukiro',    '+250788000500', 'kicukiro@rnp.gov.rw',    'CSP Niyonsaba Claire',     true),
  ('UNIT-PTS', 'Police Training School Gishari',        'specialized',  'Gishari, Eastern Province',    'Eastern',  'Rwamagana',   '+250788000600', 'pts@rnp.gov.rw',         'ACP Karangwa Emmanuel',    true);


-- ============================================
-- 2. USERS (9 users — password hash = bcrypt of "Admin@123")
-- The hash below is a valid bcrypt hash for "Admin@123"
-- ============================================
-- Verified bcrypt hash of "Admin@123" (cost 10)
INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password) VALUES
  -- Admin
  ('USR-001', 'admin',              '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'System Administrator',   'admin@rnp.gov.rw',              '+250788000000', 'admin',                 'UNIT-HQ',  true, true, true, false),
  -- PTS Commander
  ('USR-010', 'station_pts',        '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'ACP Karangwa Emmanuel',  'karangwa.emmanuel@rnp.gov.rw',  '+250788000009', 'station_commander',     'UNIT-PTS', true, true, true, false),
  -- HQ Commanders
  ('USR-002', 'hq_commander',       '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'CSP Nkusi Patrick',      'nkusi.patrick@rnp.gov.rw',      '+250788000001', 'hq_firearm_commander',  'UNIT-HQ',  true, true, true, false),
  ('USR-003', 'hq_commander2',      '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'CSP Mukamana Jeanne',    'mukamana.jeanne@rnp.gov.rw',    '+250788000002', 'hq_firearm_commander',  'UNIT-HQ',  true, true, true, false),
  -- Station Commanders (one per station)
  ('USR-004', 'station_nyamirambo', '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Mugabo Jean',         'mugabo.jean@rnp.gov.rw',        '+250788000003', 'station_commander',     'UNIT-NYA', true, true, true, false),
  ('USR-005', 'station_kimironko',  '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Uwimana Marie',       'uwimana.marie@rnp.gov.rw',      '+250788000004', 'station_commander',     'UNIT-KIM', true, true, true, false),
  ('USR-006', 'station_remera',     '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Habimana Pierre',     'habimana.pierre@rnp.gov.rw',    '+250788000005', 'station_commander',     'UNIT-REM', true, true, true, false),
  ('USR-007', 'station_kicukiro',   '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Niyonsaba Claire',    'niyonsaba.claire@rnp.gov.rw',   '+250788000006', 'station_commander',     'UNIT-KIC', true, true, true, false),
  -- Investigators
  ('USR-008', 'investigator',       '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Kamanzi Eric',        'kamanzi.eric@rnp.gov.rw',       '+250788000007', 'investigator',          'UNIT-HQ',  true, true, true, false),
  ('USR-009', 'investigator2',      '$2b$10$Po3Mpvy/QohmUMEDfk5Pm.ILpAgPpzkh9t35LNP1G7/P2f6rUDDQi', 'IP Ingabire Alice',      'ingabire.alice@rnp.gov.rw',     '+250788000008', 'investigator',          'UNIT-HQ',  true, true, true, false);

-- ============================================
-- 3. OFFICERS (20 officers across 4 stations + HQ)
-- ============================================
INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, date_of_birth, employment_date, firearm_certified, certification_date, certification_expiry, is_active) VALUES
  -- Nyamirambo Station (UNIT-NYA) — 5 officers
  ('OFF-001', 'RNP-2020-001', 'P/Cst. Mugisha Jean',        'Police Constable',     'UNIT-NYA', '+250788100001', 'mugisha.jean@rnp.gov.rw',      '1994-03-15', '2020-01-10', true,  '2023-06-01', '2025-06-01', true),
  ('OFF-002', 'RNP-2021-002', 'P/Cst. Uwase Marie',         'Police Constable',     'UNIT-NYA', '+250788100002', 'uwase.marie@rnp.gov.rw',       '1996-07-22', '2021-03-01', true,  '2023-06-01', '2025-06-01', true),
  ('OFF-003', 'RNP-2019-003', 'Sgt. Ndayisaba Paul',        'Sergeant',             'UNIT-NYA', '+250788100003', 'ndayisaba.paul@rnp.gov.rw',    '1990-11-05', '2019-06-15', true,  '2023-01-15', '2026-01-15', true),
  ('OFF-004', 'RNP-2022-004', 'P/Cst. Niyigena Ange',       'Police Constable',     'UNIT-NYA', '+250788100004', 'niyigena.ange@rnp.gov.rw',     '1998-01-30', '2022-07-01', true,  '2024-01-10', '2026-01-10', true),
  ('OFF-005', 'RNP-2018-005', 'Cpl. Hakizimana Aimable',    'Corporal',             'UNIT-NYA', '+250788100005', 'hakizimana.a@rnp.gov.rw',      '1992-05-12', '2018-09-01', true,  '2023-03-20', '2026-03-20', true),
  -- Kimironko Station (UNIT-KIM) — 5 officers
  ('OFF-006', 'RNP-2020-006', 'P/Cst. Habimana David',      'Police Constable',     'UNIT-KIM', '+250788100006', 'habimana.david@rnp.gov.rw',    '1995-09-18', '2020-02-20', true,  '2023-07-01', '2025-07-01', true),
  ('OFF-007', 'RNP-2021-007', 'P/Cst. Mukamana Rose',       'Police Constable',     'UNIT-KIM', '+250788100007', 'mukamana.rose@rnp.gov.rw',     '1997-04-10', '2021-01-15', true,  '2023-07-01', '2025-07-01', true),
  ('OFF-008', 'RNP-2019-008', 'Sgt. Uwimana Claude',        'Sergeant',             'UNIT-KIM', '+250788100008', 'uwimana.claude@rnp.gov.rw',    '1991-12-25', '2019-04-10', true,  '2023-04-01', '2026-04-01', true),
  ('OFF-009', 'RNP-2023-009', 'P/Cst. Nsabimana Innocent',  'Police Constable',     'UNIT-KIM', '+250788100009', 'nsabimana.i@rnp.gov.rw',       '1999-06-08', '2023-01-05', true,  '2024-06-01', '2026-06-01', true),
  ('OFF-010', 'RNP-2020-010', 'Cpl. Tuyishime Emmanuel',    'Corporal',             'UNIT-KIM', '+250788100010', 'tuyishime.e@rnp.gov.rw',       '1993-08-14', '2020-08-01', true,  '2023-08-01', '2026-08-01', true),
  -- Remera Station (UNIT-REM) — 4 officers
  ('OFF-011', 'RNP-2019-011', 'Sgt. Nshimiyimana Felix',    'Sergeant',             'UNIT-REM', '+250788100011', 'nshimiyimana.f@rnp.gov.rw',    '1989-02-28', '2019-01-20', true,  '2023-02-15', '2026-02-15', true),
  ('OFF-012', 'RNP-2021-012', 'P/Cst. Uwera Diane',         'Police Constable',     'UNIT-REM', '+250788100012', 'uwera.diane@rnp.gov.rw',       '1996-10-03', '2021-05-10', true,  '2023-09-01', '2025-09-01', true),
  ('OFF-013', 'RNP-2022-013', 'P/Cst. Ishimwe Patrick',     'Police Constable',     'UNIT-REM', '+250788100013', 'ishimwe.p@rnp.gov.rw',         '1997-07-19', '2022-03-01', true,  '2024-03-01', '2026-03-01', true),
  ('OFF-014', 'RNP-2020-014', 'Cpl. Mugabo Faustin',        'Corporal',             'UNIT-REM', '+250788100014', 'mugabo.f@rnp.gov.rw',          '1993-04-11', '2020-06-15', true,  '2023-06-15', '2026-06-15', true),
  -- Kicukiro Station (UNIT-KIC) — 4 officers
  ('OFF-015', 'RNP-2019-015', 'Sgt. Karangwa Patrick',      'Sergeant',             'UNIT-KIC', '+250788100015', 'karangwa.p@rnp.gov.rw',        '1990-09-22', '2019-02-01', true,  '2023-05-01', '2026-05-01', true),
  ('OFF-016', 'RNP-2021-016', 'P/Cst. Ingabire Grace',      'Police Constable',     'UNIT-KIC', '+250788100016', 'ingabire.g@rnp.gov.rw',        '1998-12-07', '2021-08-20', true,  '2024-01-01', '2026-01-01', true),
  ('OFF-017', 'RNP-2023-017', 'P/Cst. Bizimana Thierry',    'Police Constable',     'UNIT-KIC', '+250788100017', 'bizimana.t@rnp.gov.rw',        '2000-03-25', '2023-06-01', false, NULL,          NULL,          true),
  ('OFF-018', 'RNP-2020-018', 'Cpl. Mukamusoni Claudine',   'Corporal',             'UNIT-KIC', '+250788100018', 'mukamusoni.c@rnp.gov.rw',      '1994-11-16', '2020-04-10', true,  '2023-10-01', '2026-10-01', true),
  -- HQ Officers (UNIT-HQ) — 2 officers
  ('OFF-019', 'RNP-2017-019', 'IP Rutayisire Alex',         'Inspector of Police',  'UNIT-HQ',  '+250788100019', 'rutayisire.a@rnp.gov.rw',      '1987-06-30', '2017-01-10', true,  '2022-01-01', '2027-01-01', true),
  ('OFF-020', 'RNP-2018-020', 'SGT Umutoni Jeannette',      'Sergeant',             'UNIT-HQ',  '+250788100020', 'umutoni.j@rnp.gov.rw',         '1991-08-20', '2018-03-15', true,  '2023-03-01', '2026-03-01', true),
  -- PTS Officers (UNIT-PTS) — 2 training instructors
  ('OFF-021', 'RNP-2016-021', 'IP Ntaganda Samuel',         'Inspector of Police',  'UNIT-PTS', '+250788100021', 'ntaganda.s@rnp.gov.rw',        '1986-04-15', '2016-08-01', true,  '2023-08-01', '2026-08-01', true),
  ('OFF-022', 'RNP-2019-022', 'Sgt. Mukiza Claudette',      'Sergeant',             'UNIT-PTS', '+250788100022', 'mukiza.c@rnp.gov.rw',          '1992-10-30', '2019-02-15', true,  '2023-11-01', '2026-11-01', true);

-- ============================================
-- 4. FIREARMS (20 firearms across all units)
-- ============================================
INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, notes, is_active) VALUES
  -- Nyamirambo (UNIT-NYA) — 5 firearms
  ('FA-001', 'GLK-NYA-0001', 'Glock',      'Glock 17 Gen5',  'pistol',  '9x19mm Parabellum',  2023, '2023-06-15', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-NYA', 'available', 'Standard issue sidearm',   true),
  ('FA-002', 'GLK-NYA-0002', 'Glock',      'Glock 17 Gen5',  'pistol',  '9x19mm Parabellum',  2023, '2023-06-15', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-NYA', 'available', 'Standard issue sidearm',   true),
  ('FA-003', 'FNH-NYA-0001', 'FN Herstal', 'FN SCAR-L',      'rifle',   '5.56x45mm NATO',     2022, '2022-03-20', 'Government Procurement 2022', 'hq', 'USR-002', 'UNIT-NYA', 'available', 'Patrol rifle',            true),
  ('FA-004', 'BRT-NYA-0001', 'Beretta',    '92FS',            'pistol',  '9x19mm Parabellum',  2021, '2021-09-10', 'Government Procurement 2021', 'hq', 'USR-002', 'UNIT-NYA', 'available', 'Backup sidearm',          true),
  ('FA-005', 'REM-NYA-0001', 'Remington',  'Model 870',       'shotgun', '12 gauge',           2020, '2020-11-05', 'Government Procurement 2020', 'hq', 'USR-002', 'UNIT-NYA', 'available', 'Breaching / crowd control',true),
  -- Kimironko (UNIT-KIM) — 5 firearms
  ('FA-006', 'GLK-KIM-0001', 'Glock',      'Glock 19 Gen5',  'pistol',  '9x19mm Parabellum',  2023, '2023-07-10', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-KIM', 'available', 'Compact sidearm',         true),
  ('FA-007', 'GLK-KIM-0002', 'Glock',      'Glock 19 Gen5',  'pistol',  '9x19mm Parabellum',  2023, '2023-07-10', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-KIM', 'available', 'Compact sidearm',         true),
  ('FA-008', 'SIG-KIM-0001', 'SIG Sauer',  'P320',            'pistol',  '9x19mm Parabellum',  2024, '2024-01-15', 'Government Procurement 2024', 'hq', 'USR-002', 'UNIT-KIM', 'available', 'Modular duty pistol',     true),
  ('FA-009', 'FNH-KIM-0001', 'FN Herstal', 'FN SCAR-H',      'rifle',   '7.62x51mm NATO',     2022, '2022-05-20', 'Government Procurement 2022', 'hq', 'USR-002', 'UNIT-KIM', 'available', 'Designated marksman rifle',true),
  ('FA-010', 'HNK-KIM-0001', 'Heckler & Koch', 'MP5',        'submachine_gun', '9x19mm Parabellum', 2021, '2021-08-12', 'Government Procurement 2021', 'hq', 'USR-002', 'UNIT-KIM', 'available', 'Close protection detail', true),
  -- Remera (UNIT-REM) — 4 firearms
  ('FA-011', 'GLK-REM-0001', 'Glock',      'Glock 17',        'pistol',  '9x19mm Parabellum',  2022, '2022-05-20', 'Government Procurement 2022', 'hq', 'USR-002', 'UNIT-REM', 'available', 'Standard sidearm',        true),
  ('FA-012', 'BRT-REM-0001', 'Beretta',    '92FS',            'pistol',  '9x19mm Parabellum',  2021, '2021-11-10', 'Government Procurement 2021', 'hq', 'USR-002', 'UNIT-REM', 'available', 'Backup sidearm',          true),
  ('FA-013', 'SIG-REM-0001', 'SIG Sauer',  'P226',            'pistol',  '9x19mm Parabellum',  2023, '2023-04-05', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-REM', 'available', 'Officer sidearm',         true),
  ('FA-014', 'REM-REM-0001', 'Remington',  'Model 870',       'shotgun', '12 gauge',           2019, '2019-06-20', 'Government Procurement 2019', 'hq', 'USR-002', 'UNIT-REM', 'maintenance', 'Needs barrel inspection',true),
  -- Kicukiro (UNIT-KIC) — 4 firearms
  ('FA-015', 'GLK-KIC-0001', 'Glock',      'Glock 17 Gen4',  'pistol',  '9x19mm Parabellum',  2022, '2022-08-15', 'Government Procurement 2022', 'hq', 'USR-002', 'UNIT-KIC', 'available', 'Standard sidearm',        true),
  ('FA-016', 'SIG-KIC-0001', 'SIG Sauer',  'P320',            'pistol',  '9x19mm Parabellum',  2024, '2024-02-20', 'Government Procurement 2024', 'hq', 'USR-002', 'UNIT-KIC', 'available', 'Modular duty pistol',     true),
  ('FA-017', 'BRT-KIC-0001', 'Beretta',    'ARX 160',         'rifle',   '5.56x45mm NATO',     2023, '2023-09-01', 'Government Procurement 2023', 'hq', 'USR-002', 'UNIT-KIC', 'available', 'Patrol rifle',            true),
  ('FA-018', 'REM-KIC-0001', 'Remington',  'Model 870',       'shotgun', '12 gauge',           2020, '2020-04-10', 'Government Procurement 2020', 'hq', 'USR-002', 'UNIT-KIC', 'available', 'Crowd control',           true),
  -- HQ Reserve (UNIT-HQ) — 2 firearms
  ('FA-019', 'GLK-HQ-0001',  'Glock',      'Glock 17 Gen5',  'pistol',  '9x19mm Parabellum',  2024, '2024-01-20', 'Government Procurement 2024', 'hq', 'USR-002', 'UNIT-HQ',  'available', 'HQ reserve',              true),
  ('FA-020', 'SIG-HQ-0001',  'SIG Sauer',  'P226',            'pistol',  '9x19mm Parabellum',  2024, '2024-01-20', 'Government Procurement 2024', 'hq', 'USR-002', 'UNIT-HQ',  'available', 'HQ reserve',              true);

-- ============================================
-- 5. BALLISTIC PROFILES (12 firearms with profiles)
-- Each profile has distinct characteristics for forensic search
-- ============================================
INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, extractor_marks, chamber_marks, test_conducted_by, forensic_lab, test_ammunition, notes, created_by, is_locked, registration_hash) VALUES
  ('BP-001', 'FA-001', '2023-06-20', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, centered, 0.8mm diameter',            'Rectangular at 3 o''clock',        'Linear scratch at 9 o''clock',         'Smooth feed ramp, standard marks',          'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Clean test, excellent sample quality',  'USR-008', true, 'a1b2c3d4e5f6'),
  ('BP-002', 'FA-002', '2023-06-20', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, centered, 0.82mm diameter',           'Rectangular at 3 o''clock',        'Linear scratch at 9 o''clock',         'Smooth feed ramp, minor tooling marks',     'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Slight variation from FA-001',          'USR-008', true, 'b2c3d4e5f6a1'),
  ('BP-003', 'FA-003', '2022-04-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:7 pitch',                 'Hemispherical, off-center 0.1mm left',          'Triangular at 2 o''clock',         'Deep gouge at 8 o''clock',             'Detachable magazine, slight burr on lip',   'Dr. Ingabire Alice',     'RNP Central Forensic Lab',  '5.56mm M855 62gr',  'Rifle pattern distinct from pistols',   'USR-009', true, 'c3d4e5f6a1b2'),
  ('BP-004', 'FA-004', '2021-10-05', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Oval, centered, 0.9mm × 0.7mm',                 'Semi-circular at 4 o''clock',      'Faint linear mark at 10 o''clock',     'Open-slide feed, moderate wear marks',      'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 115gr',     'Older model, moderate barrel wear',     'USR-008', true, 'd4e5f6a1b2c3'),
  ('BP-005', 'FA-006', '2023-07-15', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, slightly off-center right, 0.75mm',   'Semi-circular at 4 o''clock',      'Angular mark at 8 o''clock',           'Compact slide, clean chamber walls',        'Dr. Ingabire Alice',     'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Compact model profile',                 'USR-009', true, 'e5f6a1b2c3d4'),
  ('BP-006', 'FA-007', '2023-07-15', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, centered, 0.76mm diameter',           'Semi-circular at 3 o''clock',      'Angular mark at 9 o''clock',           'Compact slide, clean',                      'Dr. Ingabire Alice',     'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Sister pistol to FA-006',               'USR-009', true, 'f6a1b2c3d4e5'),
  ('BP-007', 'FA-008', '2024-01-20', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Rectangular, centered, 1.0mm × 0.6mm',          'Crescent at 5 o''clock',           'Double scratch marks at 11 o''clock',  'Modular chassis, crisp chamber marks',      'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'New P320 modular system',               'USR-008', true, 'a2b3c4d5e6f7'),
  ('BP-008', 'FA-011', '2022-06-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, centered, 0.8mm diameter',            'Rectangular at 2 o''clock',        'Faint linear mark at 8 o''clock',      'Standard feed ramp',                        'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Standard Glock 17 pattern',             'USR-008', true, 'b3c4d5e6f7a2'),
  ('BP-009', 'FA-012', '2021-12-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Oval, centered, 0.85mm × 0.65mm',               'Deep semi-circular at 3 o''clock', 'Pronounced gouge at 9 o''clock',       'Open-slide feed, heavy wear on throat',     'Dr. Ingabire Alice',     'RNP Central Forensic Lab',  '9mm FMJ 115gr',     'Showing barrel wear consistent with age','USR-009', true, 'c4d5e6f7a2b3'),
  ('BP-010', 'FA-015', '2022-09-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, centered, 0.78mm diameter',           'Rectangular at 3 o''clock',        'Faint mark at 9 o''clock',             'Standard ramp, clean',                      'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Gen4 profile',                          'USR-008', true, 'd5e6f7a2b3c4'),
  ('BP-011', 'FA-019', '2024-02-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Circular, perfectly centered, 0.81mm',          'Clean rectangular at 3 o''clock',  'Light linear at 9 o''clock',           'Factory-new feed ramp',                     'Dr. Kamanzi Eric',       'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'Brand new, reference-quality profile',  'USR-008', true, 'e6f7a2b3c4d5'),
  ('BP-012', 'FA-020', '2024-02-01', 'RNP Central Forensic Lab, Kigali',  '6 grooves, right-hand twist, 1:10 pitch',                'Rectangular, centered, 0.95mm × 0.55mm',        'Triangular at 4 o''clock',         'Double linear at 10 o''clock',         'DA/SA slide, crisp chamber impression',     'Dr. Ingabire Alice',     'RNP Central Forensic Lab',  '9mm FMJ 124gr',     'P226 double-action reference profile',  'USR-009', true, 'f7a2b3c4d5e6');

-- ============================================
-- 6. UNIT MOVEMENTS (initial assignments for all 20 firearms)
-- ============================================
INSERT INTO firearm_unit_movements (movement_id, firearm_id, from_unit_id, to_unit_id, movement_type, authorized_by, reason) VALUES
  ('MOV-001', 'FA-001', NULL, 'UNIT-NYA', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-002', 'FA-002', NULL, 'UNIT-NYA', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-003', 'FA-003', NULL, 'UNIT-NYA', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-004', 'FA-004', NULL, 'UNIT-NYA', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-005', 'FA-005', NULL, 'UNIT-NYA', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-006', 'FA-006', NULL, 'UNIT-KIM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-007', 'FA-007', NULL, 'UNIT-KIM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-008', 'FA-008', NULL, 'UNIT-KIM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-009', 'FA-009', NULL, 'UNIT-KIM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-010', 'FA-010', NULL, 'UNIT-KIM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-011', 'FA-011', NULL, 'UNIT-REM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-012', 'FA-012', NULL, 'UNIT-REM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-013', 'FA-013', NULL, 'UNIT-REM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-014', 'FA-014', NULL, 'UNIT-REM', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-015', 'FA-015', NULL, 'UNIT-KIC', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-016', 'FA-016', NULL, 'UNIT-KIC', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-017', 'FA-017', NULL, 'UNIT-KIC', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-018', 'FA-018', NULL, 'UNIT-KIC', 'initial_assignment', 'USR-002', 'HQ registration and station assignment'),
  ('MOV-019', 'FA-019', NULL, 'UNIT-HQ',  'initial_assignment', 'USR-002', 'HQ reserve stock'),
  ('MOV-020', 'FA-020', NULL, 'UNIT-HQ',  'initial_assignment', 'USR-002', 'HQ reserve stock');

-- ============================================
-- 7. CUSTODY RECORDS — COMPREHENSIVE (160+ records)
-- Mix of:
--   • Normal daytime duty (majority) — ML training baseline
--   • Night shifts (some normal, some anomalous)
--   • Weekend duties
--   • Long custody durations (potential anomalies)
--   • Rapid exchanges (anomalies)
--   • Cross-unit (anomalies)
-- ============================================

-- Disable the firearm status trigger during bulk insert
-- (it fires on every INSERT setting status to 'in_custody' even for returned records)
ALTER TABLE custody_records DISABLE TRIGGER trg_update_firearm_status;

-- ── NYAMIRAMBO STATION (UNIT-NYA) — Normal patterns ──

-- Officer OFF-001 (Mugisha Jean) — regular day patrol
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-001', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-01 07:00:00', 'USR-004', '2025-07-01 18:00:00', 'USR-004', 39600,  'Morning patrol, Nyamirambo sector',       NULL, 7, 2, false, false),
  ('CUS-002', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-03 06:30:00', 'USR-004', '2025-07-03 17:30:00', 'USR-004', 39600,  'Day patrol duty',                          NULL, 6, 4, false, false),
  ('CUS-003', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-07 07:15:00', 'USR-004', '2025-07-07 18:15:00', 'USR-004', 39600,  'Community patrol assignment',               NULL, 7, 1, false, false),
  ('CUS-004', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-10 06:45:00', 'USR-004', '2025-07-10 18:00:00', 'USR-004', 40500,  'Standard patrol duty',                     NULL, 6, 4, false, false),
  ('CUS-005', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-14 07:00:00', 'USR-004', '2025-07-14 17:45:00', 'USR-004', 38700,  'Day shift patrol',                         NULL, 7, 1, false, false),
  ('CUS-006', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-17 07:00:00', 'USR-004', '2025-07-17 18:30:00', 'USR-004', 41400,  'Patrol and traffic control',                NULL, 7, 4, false, false),
  ('CUS-007', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-21 06:30:00', 'USR-004', '2025-07-21 17:00:00', 'USR-004', 37800,  'Neighbourhood patrol',                     NULL, 6, 1, false, false),
  ('CUS-008', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-24 07:00:00', 'USR-004', '2025-07-24 18:00:00', 'USR-004', 39600,  'Standard day patrol',                      NULL, 7, 4, false, false),
  ('CUS-009', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-07-28 07:30:00', 'USR-004', '2025-07-28 18:30:00', 'USR-004', 39600,  'Patrol duty',                              NULL, 7, 1, false, false),
  ('CUS-010', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-08-01 07:00:00', 'USR-004', '2025-08-01 18:00:00', 'USR-004', 39600,  'Day patrol',                               NULL, 7, 5, false, false);

-- Officer OFF-002 (Uwase Marie) — regular + some night shifts
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-011', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-02 07:00:00', 'USR-004', '2025-07-02 18:00:00', 'USR-004', 39600,  'Day patrol duty',                          NULL, 7, 3, false, false),
  ('CUS-012', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-04 18:00:00', 'USR-004', '2025-07-05 06:00:00', 'USR-004', 43200,  'Night shift security',                     NULL, 18, 5, false, false),
  ('CUS-013', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-08 07:00:00', 'USR-004', '2025-07-08 17:00:00', 'USR-004', 36000,  'Market area patrol',                       NULL, 7, 2, false, false),
  ('CUS-014', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-11 18:00:00', 'USR-004', '2025-07-12 06:00:00', 'USR-004', 43200,  'Night patrol shift',                       NULL, 18, 5, false, false),
  ('CUS-015', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-15 07:00:00', 'USR-004', '2025-07-15 17:30:00', 'USR-004', 37800,  'Community engagement patrol',              NULL, 7, 2, false, false),
  ('CUS-016', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-18 07:00:00', 'USR-004', '2025-07-18 18:00:00', 'USR-004', 39600,  'Standard patrol',                          NULL, 7, 5, false, false),
  ('CUS-017', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-22 07:00:00', 'USR-004', '2025-07-22 18:00:00', 'USR-004', 39600,  'Day patrol',                               NULL, 7, 2, false, false),
  ('CUS-018', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-07-25 18:00:00', 'USR-004', '2025-07-26 06:00:00', 'USR-004', 43200,  'Night shift',                              NULL, 18, 5, false, false);

-- Officer OFF-003 (Sgt. Ndayisaba) — permanent custody + rifle usage
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-019', 'FA-003', 'OFF-003', 'UNIT-NYA', 'permanent', '2025-06-01 08:00:00', 'USR-004', NULL, NULL, NULL, 'Senior duty — permanent rifle assignment', NULL, 8, 0, false, true),
  ('CUS-020', 'FA-004', 'OFF-003', 'UNIT-NYA', 'temporary', '2025-07-05 07:00:00', 'USR-004', '2025-07-05 18:00:00', 'USR-004', 39600, 'VIP escort backup weapon', NULL, 7, 6, false, true),
  ('CUS-021', 'FA-004', 'OFF-003', 'UNIT-NYA', 'temporary', '2025-07-12 07:00:00', 'USR-004', '2025-07-12 18:00:00', 'USR-004', 39600, 'Road checkpoint duty',    NULL, 7, 6, false, true);

-- Officers OFF-004, OFF-005 — normal patterns
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-022', 'FA-004', 'OFF-004', 'UNIT-NYA', 'temporary', '2025-07-09 07:00:00', 'USR-004', '2025-07-09 17:00:00', 'USR-004', 36000, 'Patrol duty',             NULL, 7, 3, false, false),
  ('CUS-023', 'FA-005', 'OFF-004', 'UNIT-NYA', 'temporary', '2025-07-16 07:00:00', 'USR-004', '2025-07-16 18:00:00', 'USR-004', 39600, 'Market security',         NULL, 7, 3, false, false),
  ('CUS-024', 'FA-004', 'OFF-004', 'UNIT-NYA', 'temporary', '2025-07-23 07:00:00', 'USR-004', '2025-07-23 18:00:00', 'USR-004', 39600, 'Standard patrol',         NULL, 7, 3, false, false),
  ('CUS-025', 'FA-005', 'OFF-005', 'UNIT-NYA', 'temporary', '2025-07-02 07:30:00', 'USR-004', '2025-07-02 17:30:00', 'USR-004', 36000, 'Area patrol',             NULL, 7, 3, false, false),
  ('CUS-026', 'FA-005', 'OFF-005', 'UNIT-NYA', 'temporary', '2025-07-09 07:00:00', 'USR-004', '2025-07-09 18:00:00', 'USR-004', 39600, 'Patrol duty',             NULL, 7, 3, false, false),
  ('CUS-027', 'FA-004', 'OFF-005', 'UNIT-NYA', 'temporary', '2025-07-17 07:00:00', 'USR-004', '2025-07-17 17:00:00', 'USR-004', 36000, 'Checkpoint duty',         NULL, 7, 4, false, false),
  ('CUS-028', 'FA-005', 'OFF-005', 'UNIT-NYA', 'temporary', '2025-07-24 07:00:00', 'USR-004', '2025-07-24 18:00:00', 'USR-004', 39600, 'Community patrol',        NULL, 7, 4, false, false);

-- ── KIMIRONKO STATION (UNIT-KIM) — Normal patterns ──

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-029', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-01 07:00:00', 'USR-005', '2025-07-01 17:00:00', 'USR-005', 36000, 'Day patrol Kimironko',          NULL, 7, 2, false, false),
  ('CUS-030', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-04 07:00:00', 'USR-005', '2025-07-04 18:00:00', 'USR-005', 39600, 'Market monitoring',             NULL, 7, 5, false, false),
  ('CUS-031', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-08 07:00:00', 'USR-005', '2025-07-08 17:30:00', 'USR-005', 37800, 'Patrol duty',                   NULL, 7, 2, false, false),
  ('CUS-032', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-11 07:00:00', 'USR-005', '2025-07-11 18:00:00', 'USR-005', 39600, 'Standard duty',                 NULL, 7, 5, false, false),
  ('CUS-033', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-15 07:00:00', 'USR-005', '2025-07-15 17:00:00', 'USR-005', 36000, 'Community patrol',              NULL, 7, 2, false, false),
  ('CUS-034', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-18 07:00:00', 'USR-005', '2025-07-18 18:00:00', 'USR-005', 39600, 'Day patrol',                    NULL, 7, 5, false, false),
  ('CUS-035', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-22 07:00:00', 'USR-005', '2025-07-22 17:00:00', 'USR-005', 36000, 'Sector patrol',                 NULL, 7, 2, false, false),
  ('CUS-036', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-07-25 07:00:00', 'USR-005', '2025-07-25 18:00:00', 'USR-005', 39600, 'Patrol duty',                   NULL, 7, 5, false, false),
  ('CUS-037', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-02 07:00:00', 'USR-005', '2025-07-02 18:00:00', 'USR-005', 39600, 'Standard patrol',               NULL, 7, 3, false, false),
  ('CUS-038', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-07 07:00:00', 'USR-005', '2025-07-07 17:00:00', 'USR-005', 36000, 'Day shift',                     NULL, 7, 1, false, false),
  ('CUS-039', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-10 07:00:00', 'USR-005', '2025-07-10 18:00:00', 'USR-005', 39600, 'Patrol',                        NULL, 7, 4, false, false),
  ('CUS-040', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-14 07:00:00', 'USR-005', '2025-07-14 17:00:00', 'USR-005', 36000, 'Community patrol',              NULL, 7, 1, false, false),
  ('CUS-041', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-17 07:00:00', 'USR-005', '2025-07-17 18:00:00', 'USR-005', 39600, 'Day patrol',                    NULL, 7, 4, false, false),
  ('CUS-042', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-07-21 07:00:00', 'USR-005', '2025-07-21 17:30:00', 'USR-005', 37800, 'Patrol and foot beat',          NULL, 7, 1, false, false),
  ('CUS-043', 'FA-008', 'OFF-008', 'UNIT-KIM', 'permanent', '2025-06-15 08:00:00', 'USR-005', NULL, NULL, NULL,                         'Senior duty — permanent sidearm',  NULL, 8, 0, false, true),
  ('CUS-044', 'FA-009', 'OFF-008', 'UNIT-KIM', 'temporary', '2025-07-05 07:00:00', 'USR-005', '2025-07-05 18:00:00', 'USR-005', 39600, 'Perimeter security detail',     NULL, 7, 6, false, true),
  ('CUS-045', 'FA-010', 'OFF-008', 'UNIT-KIM', 'temporary', '2025-07-19 07:00:00', 'USR-005', '2025-07-19 18:00:00', 'USR-005', 39600, 'Event security with SMG',       NULL, 7, 6, false, true),
  ('CUS-046', 'FA-008', 'OFF-009', 'UNIT-KIM', 'temporary', '2025-07-03 07:00:00', 'USR-005', '2025-07-03 17:00:00', 'USR-005', 36000, 'Day patrol',                    NULL, 7, 4, false, false),
  ('CUS-047', 'FA-008', 'OFF-009', 'UNIT-KIM', 'temporary', '2025-07-10 07:00:00', 'USR-005', '2025-07-10 18:00:00', 'USR-005', 39600, 'Patrol duty',                   NULL, 7, 4, false, false),
  ('CUS-048', 'FA-008', 'OFF-009', 'UNIT-KIM', 'temporary', '2025-07-17 07:00:00', 'USR-005', '2025-07-17 17:30:00', 'USR-005', 37800, 'Routine patrol',                NULL, 7, 4, false, false),
  ('CUS-049', 'FA-006', 'OFF-010', 'UNIT-KIM', 'temporary', '2025-07-03 07:00:00', 'USR-005', '2025-07-03 18:00:00', 'USR-005', 39600, 'Checkpoint duty',               NULL, 7, 4, false, false),
  ('CUS-050', 'FA-007', 'OFF-010', 'UNIT-KIM', 'temporary', '2025-07-09 07:00:00', 'USR-005', '2025-07-09 17:00:00', 'USR-005', 36000, 'Area patrol',                   NULL, 7, 3, false, false),
  ('CUS-051', 'FA-006', 'OFF-010', 'UNIT-KIM', 'temporary', '2025-07-16 07:00:00', 'USR-005', '2025-07-16 18:00:00', 'USR-005', 39600, 'Standard shift',                NULL, 7, 3, false, false);

-- ── REMERA STATION (UNIT-REM) — Normal patterns ──

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-052', 'FA-011', 'OFF-011', 'UNIT-REM', 'permanent', '2025-06-01 08:00:00', 'USR-006', NULL, NULL, NULL,                         'Senior duty — permanent sidearm',    NULL, 8, 0, false, true),
  ('CUS-053', 'FA-012', 'OFF-011', 'UNIT-REM', 'temporary', '2025-07-05 07:00:00', 'USR-006', '2025-07-05 18:00:00', 'USR-006', 39600, 'Backup weapon for VIP detail',      NULL, 7, 6, false, true),
  ('CUS-054', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-01 07:00:00', 'USR-006', '2025-07-01 18:00:00', 'USR-006', 39600, 'Day shift patrol',                  NULL, 7, 2, false, false),
  ('CUS-055', 'FA-012', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-04 07:00:00', 'USR-006', '2025-07-04 17:00:00', 'USR-006', 36000, 'Community beat',                    NULL, 7, 5, false, false),
  ('CUS-056', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-08 07:00:00', 'USR-006', '2025-07-08 18:00:00', 'USR-006', 39600, 'Patrol',                            NULL, 7, 2, false, false),
  ('CUS-057', 'FA-012', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-11 07:00:00', 'USR-006', '2025-07-11 18:00:00', 'USR-006', 39600, 'Standard patrol',                   NULL, 7, 5, false, false),
  ('CUS-058', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-15 07:00:00', 'USR-006', '2025-07-15 17:30:00', 'USR-006', 37800, 'Day shift',                         NULL, 7, 2, false, false),
  ('CUS-059', 'FA-012', 'OFF-012', 'UNIT-REM', 'temporary', '2025-07-18 07:00:00', 'USR-006', '2025-07-18 18:00:00', 'USR-006', 39600, 'Patrol duty',                       NULL, 7, 5, false, false),
  ('CUS-060', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-02 07:00:00', 'USR-006', '2025-07-02 18:00:00', 'USR-006', 39600, 'Patrol duty',                       NULL, 7, 3, false, false),
  ('CUS-061', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-07 07:00:00', 'USR-006', '2025-07-07 17:00:00', 'USR-006', 36000, 'Day shift',                         NULL, 7, 1, false, false),
  ('CUS-062', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-10 07:00:00', 'USR-006', '2025-07-10 18:00:00', 'USR-006', 39600, 'Standard patrol',                   NULL, 7, 4, false, false),
  ('CUS-063', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-14 07:00:00', 'USR-006', '2025-07-14 17:00:00', 'USR-006', 36000, 'Beat patrol',                       NULL, 7, 1, false, false),
  ('CUS-064', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-17 07:00:00', 'USR-006', '2025-07-17 18:00:00', 'USR-006', 39600, 'Community patrol',                  NULL, 7, 4, false, false),
  ('CUS-065', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-07-21 07:00:00', 'USR-006', '2025-07-21 17:30:00', 'USR-006', 37800, 'Patrol',                            NULL, 7, 1, false, false),
  ('CUS-066', 'FA-011', 'OFF-014', 'UNIT-REM', 'temporary', '2025-07-03 07:00:00', 'USR-006', '2025-07-03 18:00:00', 'USR-006', 39600, 'Patrol duty',                       NULL, 7, 4, false, false),
  ('CUS-067', 'FA-012', 'OFF-014', 'UNIT-REM', 'temporary', '2025-07-09 07:00:00', 'USR-006', '2025-07-09 17:00:00', 'USR-006', 36000, 'Checkpoint duty',                   NULL, 7, 3, false, false),
  ('CUS-068', 'FA-011', 'OFF-014', 'UNIT-REM', 'temporary', '2025-07-16 07:00:00', 'USR-006', '2025-07-16 18:00:00', 'USR-006', 39600, 'Area patrol',                       NULL, 7, 3, false, false),
  ('CUS-069', 'FA-012', 'OFF-014', 'UNIT-REM', 'temporary', '2025-07-23 07:00:00', 'USR-006', '2025-07-23 17:30:00', 'USR-006', 37800, 'Standard patrol',                   NULL, 7, 3, false, false);

-- ── KICUKIRO STATION (UNIT-KIC) — Normal patterns ──

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-070', 'FA-015', 'OFF-015', 'UNIT-KIC', 'permanent', '2025-06-01 08:00:00', 'USR-007', NULL, NULL, NULL,                         'Senior duty — permanent sidearm',    NULL, 8, 0, false, true),
  ('CUS-071', 'FA-016', 'OFF-015', 'UNIT-KIC', 'temporary', '2025-07-05 07:00:00', 'USR-007', '2025-07-05 18:00:00', 'USR-007', 39600, 'Backup sidearm for operation',       NULL, 7, 6, false, true),
  ('CUS-072', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-01 07:00:00', 'USR-007', '2025-07-01 17:00:00', 'USR-007', 36000, 'Day patrol',                         NULL, 7, 2, false, false),
  ('CUS-073', 'FA-016', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-04 07:00:00', 'USR-007', '2025-07-04 18:00:00', 'USR-007', 39600, 'Market area security',               NULL, 7, 5, false, false),
  ('CUS-074', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-08 07:00:00', 'USR-007', '2025-07-08 17:30:00', 'USR-007', 37800, 'Patrol duty',                        NULL, 7, 2, false, false),
  ('CUS-075', 'FA-016', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-11 07:00:00', 'USR-007', '2025-07-11 18:00:00', 'USR-007', 39600, 'Standard patrol',                    NULL, 7, 5, false, false),
  ('CUS-076', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-15 07:00:00', 'USR-007', '2025-07-15 17:00:00', 'USR-007', 36000, 'Day shift',                          NULL, 7, 2, false, false),
  ('CUS-077', 'FA-016', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-07-18 07:00:00', 'USR-007', '2025-07-18 18:00:00', 'USR-007', 39600, 'Patrol',                             NULL, 7, 5, false, false),
  ('CUS-078', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-02 07:00:00', 'USR-007', '2025-07-02 18:00:00', 'USR-007', 39600, 'Checkpoint with rifle',              NULL, 7, 3, false, false),
  ('CUS-079', 'FA-018', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-06 07:00:00', 'USR-007', '2025-07-06 14:00:00', 'USR-007', 25200, 'Crowd control — stadium event',      NULL, 7, 0, false, true),
  ('CUS-080', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-09 07:00:00', 'USR-007', '2025-07-09 18:00:00', 'USR-007', 39600, 'Patrol with rifle',                  NULL, 7, 3, false, false),
  ('CUS-081', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-16 07:00:00', 'USR-007', '2025-07-16 17:00:00', 'USR-007', 36000, 'Checkpoint duty',                    NULL, 7, 3, false, false),
  ('CUS-082', 'FA-018', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-20 07:00:00', 'USR-007', '2025-07-20 14:00:00', 'USR-007', 25200, 'Crowd control — market day',         NULL, 7, 0, false, true),
  ('CUS-083', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-07-23 07:00:00', 'USR-007', '2025-07-23 18:00:00', 'USR-007', 39600, 'Patrol',                             NULL, 7, 3, false, false);

-- ── HQ OFFICERS — Normal patterns ──

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-084', 'FA-019', 'OFF-019', 'UNIT-HQ', 'permanent', '2025-05-01 08:00:00', 'USR-002', NULL, NULL, NULL, 'Senior officer — permanent sidearm', NULL, 8, 4, false, false),
  ('CUS-085', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-07-01 08:00:00', 'USR-002', '2025-07-01 17:00:00', 'USR-002', 32400, 'HQ gate duty',                NULL, 8, 2, false, false),
  ('CUS-086', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-07-08 08:00:00', 'USR-002', '2025-07-08 17:00:00', 'USR-002', 32400, 'HQ perimeter patrol',         NULL, 8, 2, false, false),
  ('CUS-087', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-07-15 08:00:00', 'USR-002', '2025-07-15 17:00:00', 'USR-002', 32400, 'Ceremony security',           NULL, 8, 2, false, false),
  ('CUS-088', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-07-22 08:00:00', 'USR-002', '2025-07-22 17:00:00', 'USR-002', 32400, 'HQ duty',                     NULL, 8, 2, false, false);

-- ── MORE HISTORICAL NORMAL RECORDS (earlier months) ──

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-089', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-05-05 07:00:00', 'USR-004', '2025-05-05 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-090', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-05-12 07:00:00', 'USR-004', '2025-05-12 17:00:00', 'USR-004', 36000, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-091', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-05-19 07:00:00', 'USR-004', '2025-05-19 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-092', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-05-26 07:00:00', 'USR-004', '2025-05-26 17:30:00', 'USR-004', 37800, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-093', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-06-02 07:00:00', 'USR-004', '2025-06-02 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-094', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-06-09 07:00:00', 'USR-004', '2025-06-09 17:00:00', 'USR-004', 36000, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-095', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-06-16 07:00:00', 'USR-004', '2025-06-16 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-096', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-06-23 07:00:00', 'USR-004', '2025-06-23 17:00:00', 'USR-004', 36000, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-097', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-05-06 07:00:00', 'USR-004', '2025-05-06 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-098', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-05-13 07:00:00', 'USR-004', '2025-05-13 17:00:00', 'USR-004', 36000, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-099', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-05-20 07:00:00', 'USR-004', '2025-05-20 18:00:00', 'USR-004', 39600, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-100', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-05-27 07:00:00', 'USR-004', '2025-05-27 17:30:00', 'USR-004', 37800, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-101', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-05-05 07:00:00', 'USR-005', '2025-05-05 18:00:00', 'USR-005', 39600, 'Patrol duty',     NULL, 7, 1, false, false),
  ('CUS-102', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-05-12 07:00:00', 'USR-005', '2025-05-12 17:00:00', 'USR-005', 36000, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-103', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-05-19 07:00:00', 'USR-005', '2025-05-19 18:00:00', 'USR-005', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-104', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-05-26 07:00:00', 'USR-005', '2025-05-26 17:30:00', 'USR-005', 37800, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-105', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-06-02 07:00:00', 'USR-005', '2025-06-02 18:00:00', 'USR-005', 39600, 'Day patrol',      NULL, 7, 1, false, false),
  ('CUS-106', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-06-09 07:00:00', 'USR-005', '2025-06-09 17:00:00', 'USR-005', 36000, 'Patrol',          NULL, 7, 1, false, false),
  ('CUS-107', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-05-06 07:00:00', 'USR-006', '2025-05-06 18:00:00', 'USR-006', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-108', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-05-13 07:00:00', 'USR-006', '2025-05-13 17:00:00', 'USR-006', 36000, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-109', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-05-20 07:00:00', 'USR-006', '2025-05-20 18:00:00', 'USR-006', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-110', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-05-27 07:00:00', 'USR-006', '2025-05-27 17:30:00', 'USR-006', 37800, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-111', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-05-06 07:00:00', 'USR-007', '2025-05-06 18:00:00', 'USR-007', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-112', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-05-13 07:00:00', 'USR-007', '2025-05-13 17:00:00', 'USR-007', 36000, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-113', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-05-20 07:00:00', 'USR-007', '2025-05-20 18:00:00', 'USR-007', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-114', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-05-27 07:00:00', 'USR-007', '2025-05-27 17:30:00', 'USR-007', 37800, 'Standard patrol', NULL, 7, 2, false, false),
  ('CUS-115', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-05-06 07:00:00', 'USR-005', '2025-05-06 18:00:00', 'USR-005', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-116', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-05-13 07:00:00', 'USR-005', '2025-05-13 17:00:00', 'USR-005', 36000, 'Day patrol',      NULL, 7, 2, false, false),
  ('CUS-117', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-05-20 07:00:00', 'USR-005', '2025-05-20 18:00:00', 'USR-005', 39600, 'Patrol',          NULL, 7, 2, false, false),
  ('CUS-118', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-05-27 07:00:00', 'USR-005', '2025-05-27 17:30:00', 'USR-005', 37800, 'Standard patrol', NULL, 7, 2, false, false),
  ('CUS-119', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-05-07 07:00:00', 'USR-006', '2025-05-07 18:00:00', 'USR-006', 39600, 'Patrol',          NULL, 7, 3, false, false),
  ('CUS-120', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-05-14 07:00:00', 'USR-006', '2025-05-14 17:00:00', 'USR-006', 36000, 'Day patrol',      NULL, 7, 3, false, false),
  ('CUS-121', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-05-21 07:00:00', 'USR-006', '2025-05-21 18:00:00', 'USR-006', 39600, 'Standard patrol', NULL, 7, 3, false, false),
  ('CUS-122', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-05-28 07:00:00', 'USR-006', '2025-05-28 17:30:00', 'USR-006', 37800, 'Patrol',          NULL, 7, 3, false, false);

-- ── ADDITIONAL HISTORICAL RECORDS (April 2025) — to reach 160+ ──

-- Nyamirambo April records
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-123', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-04-07 07:00:00', 'USR-004', '2025-04-07 18:00:00', 'USR-004', 39600, 'Day patrol',         NULL, 7, 1, false, false),
  ('CUS-124', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-04-14 07:00:00', 'USR-004', '2025-04-14 17:30:00', 'USR-004', 37800, 'Morning patrol',     NULL, 7, 1, false, false),
  ('CUS-125', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-04-21 06:45:00', 'USR-004', '2025-04-21 18:00:00', 'USR-004', 40500, 'Sector patrol',      NULL, 6, 1, false, false),
  ('CUS-126', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-04-28 07:00:00', 'USR-004', '2025-04-28 17:00:00', 'USR-004', 36000, 'Standard patrol',    NULL, 7, 1, false, false),
  ('CUS-127', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-04-08 07:00:00', 'USR-004', '2025-04-08 18:00:00', 'USR-004', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-128', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-04-15 07:00:00', 'USR-004', '2025-04-15 17:00:00', 'USR-004', 36000, 'Market patrol',      NULL, 7, 2, false, false),
  ('CUS-129', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-04-22 07:00:00', 'USR-004', '2025-04-22 18:00:00', 'USR-004', 39600, 'Day shift',          NULL, 7, 2, false, false),
  ('CUS-130', 'FA-004', 'OFF-004', 'UNIT-NYA', 'temporary', '2025-04-09 07:00:00', 'USR-004', '2025-04-09 17:30:00', 'USR-004', 37800, 'Beat patrol',        NULL, 7, 3, false, false),
  ('CUS-131', 'FA-005', 'OFF-005', 'UNIT-NYA', 'temporary', '2025-04-16 07:00:00', 'USR-004', '2025-04-16 18:00:00', 'USR-004', 39600, 'Area sweep',         NULL, 7, 3, false, false);

-- Kimironko April records
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-132', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-04-07 07:00:00', 'USR-005', '2025-04-07 17:00:00', 'USR-005', 36000, 'Day patrol',         NULL, 7, 1, false, false),
  ('CUS-133', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-04-14 07:00:00', 'USR-005', '2025-04-14 18:00:00', 'USR-005', 39600, 'Community patrol',   NULL, 7, 1, false, false),
  ('CUS-134', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-04-21 07:00:00', 'USR-005', '2025-04-21 17:30:00', 'USR-005', 37800, 'Market security',    NULL, 7, 1, false, false),
  ('CUS-135', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-04-08 07:00:00', 'USR-005', '2025-04-08 18:00:00', 'USR-005', 39600, 'Patrol duty',        NULL, 7, 2, false, false),
  ('CUS-136', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-04-15 07:00:00', 'USR-005', '2025-04-15 17:00:00', 'USR-005', 36000, 'Standard patrol',    NULL, 7, 2, false, false),
  ('CUS-137', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-04-22 07:00:00', 'USR-005', '2025-04-22 18:00:00', 'USR-005', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-138', 'FA-008', 'OFF-009', 'UNIT-KIM', 'temporary', '2025-04-10 07:00:00', 'USR-005', '2025-04-10 17:00:00', 'USR-005', 36000, 'Patrol duty',        NULL, 7, 4, false, false),
  ('CUS-139', 'FA-006', 'OFF-010', 'UNIT-KIM', 'temporary', '2025-04-17 07:00:00', 'USR-005', '2025-04-17 18:00:00', 'USR-005', 39600, 'Checkpoint duty',    NULL, 7, 4, false, false);

-- Remera April records
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-140', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-04-08 07:00:00', 'USR-006', '2025-04-08 17:30:00', 'USR-006', 37800, 'Area patrol',        NULL, 7, 2, false, false),
  ('CUS-141', 'FA-012', 'OFF-012', 'UNIT-REM', 'temporary', '2025-04-15 07:00:00', 'USR-006', '2025-04-15 18:00:00', 'USR-006', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-142', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-04-09 07:00:00', 'USR-006', '2025-04-09 18:00:00', 'USR-006', 39600, 'Patrol duty',        NULL, 7, 3, false, false),
  ('CUS-143', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-04-16 07:00:00', 'USR-006', '2025-04-16 17:00:00', 'USR-006', 36000, 'Community beat',     NULL, 7, 3, false, false),
  ('CUS-144', 'FA-011', 'OFF-014', 'UNIT-REM', 'temporary', '2025-04-10 07:00:00', 'USR-006', '2025-04-10 18:00:00', 'USR-006', 39600, 'Standard patrol',    NULL, 7, 4, false, false),
  ('CUS-145', 'FA-012', 'OFF-014', 'UNIT-REM', 'temporary', '2025-04-23 07:00:00', 'USR-006', '2025-04-23 17:30:00', 'USR-006', 37800, 'Patrol',             NULL, 7, 3, false, false);

-- Kicukiro April records
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-146', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-04-08 07:00:00', 'USR-007', '2025-04-08 18:00:00', 'USR-007', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-147', 'FA-016', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-04-15 07:00:00', 'USR-007', '2025-04-15 17:00:00', 'USR-007', 36000, 'Standard patrol',    NULL, 7, 2, false, false),
  ('CUS-148', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-04-22 07:00:00', 'USR-007', '2025-04-22 18:00:00', 'USR-007', 39600, 'Patrol duty',        NULL, 7, 2, false, false),
  ('CUS-149', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-04-09 07:00:00', 'USR-007', '2025-04-09 18:00:00', 'USR-007', 39600, 'Checkpoint patrol',  NULL, 7, 3, false, false),
  ('CUS-150', 'FA-017', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-04-16 07:00:00', 'USR-007', '2025-04-16 17:30:00', 'USR-007', 37800, 'Area patrol',        NULL, 7, 3, false, false),
  ('CUS-151', 'FA-018', 'OFF-018', 'UNIT-KIC', 'temporary', '2025-04-13 07:00:00', 'USR-007', '2025-04-13 14:00:00', 'USR-007', 25200, 'Event security',     NULL, 7, 0, false, true);

-- HQ April records
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-152', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-04-08 08:00:00', 'USR-002', '2025-04-08 17:00:00', 'USR-002', 32400, 'HQ gate duty',        NULL, 8, 2, false, false),
  ('CUS-153', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-04-15 08:00:00', 'USR-002', '2025-04-15 17:00:00', 'USR-002', 32400, 'HQ perimeter patrol', NULL, 8, 2, false, false),
  ('CUS-154', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-04-22 08:00:00', 'USR-002', '2025-04-22 17:00:00', 'USR-002', 32400, 'HQ duty',             NULL, 8, 2, false, false);

-- ── ADDITIONAL March 2025 records (deep historical baseline) ──
INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  ('CUS-155', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-03-03 07:00:00', 'USR-004', '2025-03-03 18:00:00', 'USR-004', 39600, 'Day patrol',         NULL, 7, 1, false, false),
  ('CUS-156', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-03-10 07:00:00', 'USR-004', '2025-03-10 17:30:00', 'USR-004', 37800, 'Patrol duty',        NULL, 7, 1, false, false),
  ('CUS-157', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-03-04 07:00:00', 'USR-004', '2025-03-04 18:00:00', 'USR-004', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-158', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-03-11 07:00:00', 'USR-004', '2025-03-11 17:00:00', 'USR-004', 36000, 'Standard patrol',    NULL, 7, 2, false, false),
  ('CUS-159', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-03-03 07:00:00', 'USR-005', '2025-03-03 18:00:00', 'USR-005', 39600, 'Patrol',             NULL, 7, 1, false, false),
  ('CUS-160', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-03-10 07:00:00', 'USR-005', '2025-03-10 17:00:00', 'USR-005', 36000, 'Day patrol',         NULL, 7, 1, false, false),
  ('CUS-161', 'FA-007', 'OFF-007', 'UNIT-KIM', 'temporary', '2025-03-04 07:00:00', 'USR-005', '2025-03-04 18:00:00', 'USR-005', 39600, 'Patrol duty',        NULL, 7, 2, false, false),
  ('CUS-162', 'FA-011', 'OFF-012', 'UNIT-REM', 'temporary', '2025-03-04 07:00:00', 'USR-006', '2025-03-04 18:00:00', 'USR-006', 39600, 'Standard patrol',    NULL, 7, 2, false, false),
  ('CUS-163', 'FA-013', 'OFF-013', 'UNIT-REM', 'temporary', '2025-03-05 07:00:00', 'USR-006', '2025-03-05 17:30:00', 'USR-006', 37800, 'Beat patrol',        NULL, 7, 3, false, false),
  ('CUS-164', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-03-04 07:00:00', 'USR-007', '2025-03-04 18:00:00', 'USR-007', 39600, 'Day patrol',         NULL, 7, 2, false, false),
  ('CUS-165', 'FA-016', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-03-11 07:00:00', 'USR-007', '2025-03-11 17:30:00', 'USR-007', 37800, 'Patrol',             NULL, 7, 2, false, false),
  ('CUS-166', 'FA-020', 'OFF-020', 'UNIT-HQ',  'temporary', '2025-03-04 08:00:00', 'USR-002', '2025-03-04 17:00:00', 'USR-002', 32400, 'HQ gate duty',       NULL, 8, 2, false, false);

-- ============================================
-- 7b. ANOMALOUS CUSTODY RECORDS (for ML detection)
-- These should stand out from the normal baseline above
-- ============================================

INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by, returned_at, returned_to, custody_duration_seconds, assignment_reason, notes, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue) VALUES
  -- ANOMALY: Late night issue at 2 AM (unusual for this officer)
  ('CUS-A01', 'FA-001', 'OFF-001', 'UNIT-NYA', 'temporary', '2025-08-05 02:00:00', 'USR-004', '2025-08-05 05:00:00', 'USR-004', 10800, 'Emergency night response',    'Unusual late night issue', 2, 2, true, false),
  -- ANOMALY: Extremely long custody — 5 days unreturned
  ('CUS-A02', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', '2025-08-01 07:00:00', 'USR-004', '2025-08-06 07:00:00', 'USR-004', 432000,'Extended without documented reason', 'Very long custody period', 7, 5, false, false),
  -- ANOMALY: Weekend midnight issue
  ('CUS-A03', 'FA-004', 'OFF-004', 'UNIT-NYA', 'temporary', '2025-08-02 23:30:00', 'USR-004', '2025-08-03 04:00:00', 'USR-004', 16200, 'Late weekend call-out',       'Saturday midnight issue', 23, 6, true, true),
  -- ANOMALY: Rapid exchange — same firearm, 3 different officers in 1 day
  ('CUS-A04', 'FA-006', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-08-04 06:00:00', 'USR-005', '2025-08-04 08:00:00', 'USR-005', 7200,  'Rapid handover — first shift',  'Rapid exchange sequence', 6, 1, false, false),
  ('CUS-A05', 'FA-006', 'OFF-009', 'UNIT-KIM', 'temporary', '2025-08-04 08:30:00', 'USR-005', '2025-08-04 10:00:00', 'USR-005', 5400,  'Rapid handover — second shift',  'Rapid exchange', 8, 1, false, false),
  ('CUS-A06', 'FA-006', 'OFF-010', 'UNIT-KIM', 'temporary', '2025-08-04 10:30:00', 'USR-005', '2025-08-04 12:00:00', 'USR-005', 5400,  'Rapid handover — third shift',   'Rapid exchange', 10, 1, false, false),
  -- ANOMALY: Cross-unit — Nyamirambo firearm used at Kimironko
  ('CUS-A07', 'FA-001', 'OFF-006', 'UNIT-KIM', 'temporary', '2025-08-06 07:00:00', 'USR-005', '2025-08-06 18:00:00', 'USR-005', 39600, 'Cross-unit loan — joint operation', 'Firearm from UNIT-NYA used at UNIT-KIM', 7, 3, false, false),
  -- ANOMALY: Cross-unit — Remera firearm at Kicukiro
  ('CUS-A08', 'FA-013', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-08-07 07:00:00', 'USR-007', '2025-08-07 18:00:00', 'USR-007', 39600, 'Cross-unit operation',            'Firearm from UNIT-REM at UNIT-KIC', 7, 4, false, false),
  -- ANOMALY: Very short custody (15 minutes) — possibly accidental issue
  ('CUS-A09', 'FA-015', 'OFF-016', 'UNIT-KIC', 'temporary', '2025-08-08 10:00:00', 'USR-007', '2025-08-08 10:15:00', 'USR-007', 900,   'Immediate return — issued in error', 'Very short custody',  10, 5, false, false),
  -- ANOMALY: Uncertified officer (OFF-017) receiving firearm
  ('CUS-A10', 'FA-016', 'OFF-017', 'UNIT-KIC', 'temporary', '2025-08-03 07:00:00', 'USR-007', '2025-08-03 18:00:00', 'USR-007', 39600, 'Emergency staffing — uncertified officer', 'Uncertified officer issued firearm', 7, 0, false, true),
  -- ANOMALY: Night issue + long duration at HQ
  ('CUS-A11', 'FA-020', 'OFF-020', 'UNIT-HQ', 'temporary', '2025-08-09 01:00:00', 'USR-002', '2025-08-11 08:00:00', 'USR-002', 198000,'Night emergency — extended custody',     'Late night + 2 days', 1, 6, true, true),
  -- ANOMALY: Multiple firearms to same officer simultaneously (OFF-003 already has permanent)
  ('CUS-A12', 'FA-005', 'OFF-003', 'UNIT-NYA', 'temporary', '2025-08-10 07:00:00', 'USR-004', '2025-08-10 18:00:00', 'USR-004', 39600, 'Additional weapon for special operation', 'Officer already has permanent FA-003', 7, 0, false, true);

-- Re-enable the firearm status trigger
ALTER TABLE custody_records ENABLE TRIGGER trg_update_firearm_status;

-- Correct all firearm statuses after bulk insert
-- First reset all to 'available' (base state)
UPDATE firearms SET current_status = 'available';

-- Then set permanent custody firearms to 'in_custody'
UPDATE firearms SET current_status = 'in_custody' WHERE firearm_id IN (
  'FA-003', -- OFF-003 permanent (Nyamirambo)
  'FA-008', -- OFF-008 permanent (Kimironko)
  'FA-011', -- OFF-011 permanent (Remera)
  'FA-015', -- OFF-015 permanent (Kicukiro)
  'FA-019'  -- OFF-019 permanent (HQ)
);

-- ============================================
-- 8. LOSS REPORTS (3 reports — different statuses)
-- ============================================
INSERT INTO loss_reports (loss_id, firearm_id, unit_id, reported_by, officer_id, loss_type, loss_date, loss_location, circumstances, police_case_number, status, reviewed_by, review_date, review_notes) VALUES
  ('LOSS-001', 'FA-014', 'UNIT-REM', 'USR-006', 'OFF-014', 'lost',   '2025-07-20', 'Remera commercial area',        'Firearm holster broke during foot chase of suspect. Weapon fell and could not be located in dense vegetation. Area was searched by 4 officers for 2 hours.', 'CAS-2025-0142', 'pending',            NULL,      NULL,         NULL),
  ('LOSS-002', 'FA-010', 'UNIT-KIM', 'USR-005', 'OFF-010', 'stolen', '2025-06-15', 'Kimironko market parking area',  'Officer vehicle was broken into while responding to disturbance. The locked firearm box was forced open and weapon taken. CCTV footage being reviewed.',       'CAS-2025-0098', 'under_investigation','USR-002', '2025-06-18', 'CCTV footage shows two suspects. Investigation ongoing with CID.'),
  ('LOSS-003', 'FA-005', 'UNIT-NYA', 'USR-004', 'OFF-005', 'lost',   '2025-04-10', 'Nyamirambo training grounds',    'Shotgun left at outdoor training area during rain evacuation. When officers returned, weapon was missing from the secured rack.',                          'CAS-2025-0055', 'approved',           'USR-002', '2025-04-15', 'Confirmed lost during training exercise. Disciplinary process initiated.');

-- Update lost/stolen/recovered firearms
UPDATE firearms SET current_status = 'lost' WHERE firearm_id = 'FA-014';
UPDATE firearms SET current_status = 'stolen' WHERE firearm_id = 'FA-010';
-- FA-005 was lost (LOSS-003 approved) then recovered damaged (DEST-001 pending)
UPDATE firearms SET current_status = 'maintenance' WHERE firearm_id = 'FA-005';
-- FA-014 recovered water-damaged (DEST-002 approved) — keep as 'lost' until destruction complete

-- ============================================
-- 9. DESTRUCTION REQUESTS (2 requests)
-- ============================================
INSERT INTO destruction_requests (destruction_id, firearm_id, unit_id, requested_by, destruction_reason, condition_description, status, reviewed_by, review_date, review_notes) VALUES
  ('DEST-001', 'FA-005', 'UNIT-NYA', 'USR-004', 'Shotgun recovered after loss report but found with severe barrel damage. Barrel is bent and firing mechanism is jammed. Unsafe for use.', 'Barrel bent, firing pin damaged, stock cracked, rust throughout', 'pending', NULL, NULL, NULL),
  ('DEST-002', 'FA-014', 'UNIT-REM', 'USR-006', 'Firearm recovered water-damaged after being found in storm drain. Severely corroded internally. Cannot be safely fired.',                'Heavy corrosion, water damage to all internal components',       'approved', 'USR-002', '2025-08-10', 'Approved for destruction. Schedule with forensic lab for final ballistic record.');

-- ============================================
-- 10. PROCUREMENT REQUESTS (3 requests)
-- ============================================
INSERT INTO procurement_requests (procurement_id, unit_id, requested_by, firearm_type, quantity, justification, priority, estimated_cost, preferred_supplier, status, reviewed_by, review_date, review_notes) VALUES
  ('PROC-001', 'UNIT-NYA', 'USR-004', 'pistol',  3, 'Nyamirambo station has expanded patrol zones after Nyamirambo sector restructuring. Three additional officers need sidearms for new community patrol beats.', 'routine',  4500000.00, 'Glock International', 'pending',  NULL,      NULL,         NULL),
  ('PROC-002', 'UNIT-KIM', 'USR-005', 'rifle',   2, 'Kimironko needs additional patrol rifles for checkpoint duty near Amahoro Stadium. Current single rifle is insufficient for simultaneous checkpoint coverage.', 'high',     7200000.00, 'FN Herstal',          'approved', 'USR-002', '2025-07-20', 'Approved. Budget allocated from Q3 procurement fund.'),
  ('PROC-003', 'UNIT-KIC', 'USR-007', 'pistol',  5, 'Kicukiro station staffing has increased by 5 new officers after graduation from PTS Gishari. All are firearm-certified and require duty sidearms.',           'urgent',   7500000.00, 'SIG Sauer',           'rejected', 'USR-002', '2025-08-01', 'Budget insufficient this quarter. Re-submit for Q1 2026 procurement cycle.');

-- ============================================
-- 11. SAMPLE ANOMALIES (for anomaly dashboard testing)
-- These represent detected anomalies from the custody patterns above
-- ============================================
INSERT INTO anomalies (anomaly_id, custody_record_id, firearm_id, officer_id, unit_id, anomaly_score, anomaly_type, detection_method, severity, confidence_level, contributing_factors, feature_importance, status, investigation_notes, detected_at) VALUES
  ('ANO-001', 'CUS-A01', 'FA-001', 'OFF-001', 'UNIT-NYA', 0.87, 'unusual_timing',       'statistical', 'high',     0.91, '{"night_issue": true, "hour": 2, "baseline_hours": "06:00-18:00"}',                    '{"issue_hour": 0.45, "is_night_issue": 0.35, "officer_pattern": 0.20}',         'open',          NULL, '2025-08-05 02:05:00'),
  ('ANO-002', 'CUS-A02', 'FA-002', 'OFF-002', 'UNIT-NYA', 0.92, 'extended_custody',     'statistical', 'critical', 0.95, '{"duration_hours": 120, "avg_duration_hours": 11, "deviation": "10x normal"}',         '{"custody_duration": 0.55, "duration_zscore": 0.30, "return_delay": 0.15}',     'investigating', 'Officer claims special assignment. Verifying with commander.', '2025-08-03 08:00:00'),
  ('ANO-003', 'CUS-A03', 'FA-004', 'OFF-004', 'UNIT-NYA', 0.78, 'unusual_timing',       'statistical', 'medium',   0.82, '{"weekend": true, "night": true, "hour": 23, "officer_weekend_rate": 0.0}',            '{"is_weekend_issue": 0.40, "is_night_issue": 0.35, "issue_hour": 0.25}',        'open',          NULL, '2025-08-02 23:35:00'),
  ('ANO-004', 'CUS-A04', 'FA-006', 'OFF-006', 'UNIT-KIM', 0.85, 'rapid_exchange',       'statistical', 'high',     0.88, '{"exchanges_in_day": 3, "avg_daily_exchanges": 0.3, "shortest_custody_min": 90}',      '{"firearm_exchange_rate": 0.50, "custody_duration": 0.30, "frequency": 0.20}',  'open',          NULL, '2025-08-04 12:05:00'),
  ('ANO-005', 'CUS-A07', 'FA-001', 'OFF-006', 'UNIT-KIM', 0.95, 'cross_unit_transfer',  'rule_based',  'critical', 0.99, '{"firearm_home_unit": "UNIT-NYA", "custody_unit": "UNIT-KIM", "authorized": true}',    '{"cross_unit_flag": 0.60, "unit_mismatch": 0.25, "officer_unit": 0.15}',        'investigating', 'Joint operation confirmed by both station commanders.', '2025-08-06 07:05:00'),
  ('ANO-006', 'CUS-A08', 'FA-013', 'OFF-016', 'UNIT-KIC', 0.93, 'cross_unit_transfer',  'rule_based',  'critical', 0.99, '{"firearm_home_unit": "UNIT-REM", "custody_unit": "UNIT-KIC", "authorized": true}',    '{"cross_unit_flag": 0.60, "unit_mismatch": 0.25, "officer_unit": 0.15}',        'resolved',      'Confirmed authorized inter-station operation near shared border area.', '2025-08-07 07:05:00'),
  ('ANO-007', 'CUS-A09', 'FA-015', 'OFF-016', 'UNIT-KIC', 0.65, 'very_short_custody',   'statistical', 'low',      0.70, '{"duration_minutes": 15, "min_expected_minutes": 60, "immediate_return": true}',       '{"custody_duration": 0.60, "rapid_return": 0.25, "pattern_deviation": 0.15}',   'false_positive', 'Administrative error — wrong pistol issued, immediately corrected.', '2025-08-08 10:20:00'),
  ('ANO-008', 'CUS-A10', 'FA-016', 'OFF-017', 'UNIT-KIC', 0.88, 'uncertified_officer',  'rule_based',  'high',     0.99, '{"officer_certified": false, "certification_required": true}',                         '{"certification_check": 0.70, "policy_violation": 0.20, "risk_score": 0.10}',   'open',          NULL, '2025-08-03 07:05:00'),
  ('ANO-009', 'CUS-A11', 'FA-020', 'OFF-020', 'UNIT-HQ',  0.82, 'unusual_timing',       'statistical', 'high',     0.85, '{"night_issue": true, "hour": 1, "extended_custody": true, "duration_hours": 55}',     '{"is_night_issue": 0.35, "custody_duration": 0.35, "issue_hour": 0.30}',        'open',          NULL, '2025-08-09 01:05:00'),
  ('ANO-010', 'CUS-A12', 'FA-005', 'OFF-003', 'UNIT-NYA', 0.72, 'multiple_firearms',    'rule_based',  'medium',   0.80, '{"active_custodies": 2, "max_allowed": 1, "permanent_firearm": "FA-003"}',             '{"concurrent_firearms": 0.50, "policy_check": 0.30, "officer_history": 0.20}', 'open',          NULL, '2025-08-10 07:05:00');

-- ============================================
-- 12. ANOMALY INVESTIGATIONS (for resolved/investigating anomalies)
-- ============================================
INSERT INTO anomaly_investigations (investigation_id, anomaly_id, investigator_id, investigation_date, findings, action_taken, outcome) VALUES
  ('INV-001', 'ANO-002', 'USR-008', '2025-08-04 10:00:00', 'Officer Uwase Marie kept FA-002 for 5 days. Claims she was deployed on extended rural patrol in Bugesera and could not return weapon on time. Commander confirmed deployment but noted failure to notify armory.', 'Verbal warning issued. SOP updated to require daily check-in during extended deployments.', 'confirmed'),
  ('INV-002', 'ANO-005', 'USR-008', '2025-08-06 14:00:00', 'FA-001 from Nyamirambo was used at Kimironko during joint anti-trafficking operation. Both station commanders authorized the cross-unit loan via phone. Written authorization was filed 2 hours later.', 'Confirmed authorized. Recommended pre-authorization for future joint operations.', 'confirmed'),
  ('INV-003', 'ANO-006', 'USR-009', '2025-08-08 09:00:00', 'FA-013 from Remera was used at Kicukiro for a cordon security operation near the Remera-Kicukiro border. Fully authorized by both commanders. Firearm returned same day.', 'No action needed. Properly authorized inter-unit operation.', 'confirmed'),
  ('INV-004', 'ANO-007', 'USR-009', '2025-08-08 15:00:00', 'Very short custody of 15 minutes. Armorer confirmed wrong pistol was pulled from rack. Immediately swapped for correct weapon. No policy violation.', 'No action. Administrative error documented.', 'false_positive');

-- ============================================
-- 13. AUDIT LOGS (sample entries)
-- ============================================
INSERT INTO audit_logs (log_id, user_id, action_type, table_name, record_id, new_values, success) VALUES
  ('L-00001', 'USR-002', 'CREATE',  'firearms',          'FA-001',   '{"action": "HQ firearm registration"}',              true),
  ('L-00002', 'USR-002', 'CREATE',  'firearms',          'FA-006',   '{"action": "HQ firearm registration"}',              true),
  ('L-00003', 'USR-004', 'CREATE',  'custody_records',   'CUS-001',  '{"action": "Issued FA-001 to OFF-001 for patrol"}',  true),
  ('L-00004', 'USR-005', 'CREATE',  'custody_records',   'CUS-029',  '{"action": "Issued FA-006 to OFF-006 for patrol"}',  true),
  ('L-00005', 'USR-004', 'UPDATE',  'custody_records',   'CUS-001',  '{"action": "FA-001 returned by OFF-001"}',           true),
  ('L-00006', 'USR-008', 'READ',    'ballistic_profiles','BP-001',   '{"action": "Forensic investigation query"}',         true),
  ('L-00007', 'USR-006', 'CREATE',  'loss_reports',      'LOSS-001', '{"action": "Lost firearm report filed"}',            true),
  ('L-00008', 'USR-001', 'LOGIN',   'users',             'USR-001',  '{"action": "Admin login"}',                          true);

-- ============================================
-- 14. BALLISTIC ACCESS LOGS (forensic search activity)
-- ============================================
INSERT INTO ballistic_access_logs (access_id, ballistic_id, firearm_id, accessed_by, access_type, access_reason, firearm_status_at_access, current_custody_officer_id, current_custody_unit_id) VALUES
  ('BAL-001', 'BP-001', 'FA-001', 'USR-008', 'forensic_query',       'Bullet casing comparison — case CAS-2025-0210',    'available', NULL,      'UNIT-NYA'),
  ('BAL-002', 'BP-004', 'FA-004', 'USR-008', 'forensic_query',       'Firearm comparison for robbery case CAS-2025-0180', 'available', NULL,      'UNIT-NYA'),
  ('BAL-003', 'BP-005', 'FA-006', 'USR-009', 'view_profile',         'Routine profile review',                            'available', NULL,      'UNIT-KIM'),
  ('BAL-004', 'BP-008', 'FA-011', 'USR-008', 'view_custody_chain',   'Traceability audit for annual review',              'in_custody','OFF-011', 'UNIT-REM'),
  ('BAL-005', 'BP-009', 'FA-012', 'USR-009', 'forensic_query',       'Bullet match analysis — suspicious shooting',       'available', NULL,      'UNIT-REM'),
  ('BAL-006', 'BP-001', 'FA-001', 'USR-009', 'export_data',          'Report export for court evidence preparation',      'available', NULL,      'UNIT-NYA'),
  ('BAL-007', 'BP-011', 'FA-019', 'USR-008', 'traceability_report',  'Full traceability chain for HQ audit',              'in_custody','OFF-019', 'UNIT-HQ'),
  ('BAL-008', 'BP-003', 'FA-003', 'USR-008', 'forensic_query',       'Rifle casing match — border incident',             'in_custody','OFF-003', 'UNIT-NYA');

-- ============================================
-- 15. ML MODEL METADATA (baseline trained model)
-- ============================================
INSERT INTO ml_model_metadata (model_id, model_type, model_version, training_date, training_samples_count, num_clusters, cluster_centers, silhouette_score, outlier_threshold, normalization_params, is_active) VALUES
  ('MDL-001', 'kmeans_anomaly', 'v1.0.0', '2025-08-01 10:00:00', 134, 4,
    '[
      {"cluster": 0, "center": [0.35, 0.12, 0.08, 0.0, 0.0, 3.2, 38400, 0.92, 120000, 3, false, false]},
      {"cluster": 1, "center": [0.42, 0.18, 0.15, 1.0, 0.0, 2.8, 43200, 0.88, 86400, 2, false, true]},
      {"cluster": 2, "center": [0.28, 0.08, 0.05, 0.0, 1.0, 1.5, 32400, 0.95, 172800, 1, false, false]},
      {"cluster": 3, "center": [0.55, 0.25, 0.22, 1.0, 1.0, 4.1, 25200, 0.78, 64800, 4, true, true]}
    ]'::jsonb,
    0.6823, 2.5000,
    '{"duration_mean": 37542, "duration_std": 8940, "hour_mean": 7.2, "hour_std": 2.1, "frequency_mean": 3.5, "frequency_std": 1.8}'::jsonb,
    true),
  ('MDL-002', 'kmeans_anomaly', 'v0.9.0', '2025-07-15 14:00:00', 88, 3,
    '[
      {"cluster": 0, "center": [0.30, 0.10, 0.06, 0.0, 0.0, 2.8, 38000, 0.90, 115000, 3, false, false]},
      {"cluster": 1, "center": [0.40, 0.16, 0.12, 1.0, 0.0, 2.5, 42000, 0.85, 80000, 2, false, true]},
      {"cluster": 2, "center": [0.50, 0.22, 0.20, 1.0, 1.0, 3.8, 28000, 0.75, 60000, 4, true, true]}
    ]'::jsonb,
    0.5912, 2.8000,
    '{"duration_mean": 36800, "duration_std": 9200, "hour_mean": 7.1, "hour_std": 2.3, "frequency_mean": 3.2, "frequency_std": 1.6}'::jsonb,
    false);

-- ============================================
-- 16. ML TRAINING FEATURES (pre-extracted features for key custody records)
-- These represent the feature vectors the ML model uses to detect anomalies
-- ============================================
INSERT INTO ml_training_features (feature_id, officer_id, firearm_id, unit_id, custody_record_id, custody_duration_seconds, issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue, officer_issue_frequency_30d, officer_avg_custody_duration_30d, firearm_exchange_rate_7d, officer_unit_consistency_score, time_since_last_return_seconds, consecutive_same_firearm_count, cross_unit_movement_flag, rapid_exchange_flag, custody_duration_zscore, issue_frequency_zscore, has_ballistic_profile, ballistic_accesses_7d) VALUES
  -- Normal baseline features (OFF-001 regular day patrol)
  ('FT-001', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-001', 39600,  7, 2, false, false, 3.50, 38700.00, 0.14, 1.00, 172800, 5, false, false, 0.1185, -0.2780, true, 0),
  ('FT-002', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-002', 39600,  6, 4, false, false, 3.80, 38900.00, 0.14, 1.00, 172800, 6, false, false, 0.1185, -0.1100, true, 0),
  ('FT-003', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-003', 39600,  7, 1, false, false, 4.00, 39200.00, 0.14, 1.00, 345600, 7, false, false, 0.1185,  0.0560, true, 0),
  ('FT-004', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-004', 40500,  6, 4, false, false, 4.20, 39400.00, 0.14, 1.00, 259200, 8, false, false, 0.2191,  0.2220, true, 0),
  ('FT-005', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-005', 38700,  7, 1, false, false, 4.50, 39500.00, 0.14, 1.00, 345600, 9, false, false, 0.0176,  0.5000, true, 0),
  -- Normal baseline features (OFF-002 day + night patterns)
  ('FT-006', 'OFF-002', 'FA-002', 'UNIT-NYA', 'CUS-011', 39600,  7, 3, false, false, 2.80, 39600.00, 0.14, 1.00, 259200, 3, false, false, 0.1185, -0.3890, true, 0),
  ('FT-007', 'OFF-002', 'FA-002', 'UNIT-NYA', 'CUS-012', 43200, 18, 5, false, false, 3.00, 40200.00, 0.14, 1.00, 86400,  4, false, false, 0.5215, -0.2780, true, 0),
  ('FT-008', 'OFF-002', 'FA-002', 'UNIT-NYA', 'CUS-013', 36000,  7, 2, false, false, 3.20, 39600.00, 0.14, 1.00, 259200, 5, false, false,-0.2831, -0.1670, true, 0),
  -- Normal baseline features (OFF-006 Kimironko)
  ('FT-009', 'OFF-006', 'FA-006', 'UNIT-KIM', 'CUS-029', 36000,  7, 2, false, false, 3.00, 37800.00, 0.28, 1.00, 172800, 4, false, false,-0.2831, -0.2780, true, 0),
  ('FT-010', 'OFF-006', 'FA-006', 'UNIT-KIM', 'CUS-030', 39600,  7, 5, false, false, 3.20, 38200.00, 0.28, 1.00, 259200, 5, false, false, 0.1185, -0.1670, true, 0),
  ('FT-011', 'OFF-006', 'FA-006', 'UNIT-KIM', 'CUS-031', 37800,  7, 2, false, false, 3.50, 37900.00, 0.28, 1.00, 345600, 6, false, false,-0.0328, -0.0000, true, 0),
  -- Normal baseline features (OFF-012 Remera)
  ('FT-012', 'OFF-012', 'FA-011', 'UNIT-REM', 'CUS-054', 39600,  7, 2, false, false, 2.50, 38400.00, 0.14, 1.00, 345600, 2, false, false, 0.1185, -0.5560, true, 0),
  ('FT-013', 'OFF-012', 'FA-012', 'UNIT-REM', 'CUS-055', 36000,  7, 5, false, false, 2.80, 37800.00, 0.14, 1.00, 259200, 1, false, false,-0.2831, -0.3890, true, 0),
  -- Normal baseline features (OFF-016 Kicukiro)
  ('FT-014', 'OFF-016', 'FA-015', 'UNIT-KIC', 'CUS-072', 36000,  7, 2, false, false, 2.80, 37400.00, 0.28, 1.00, 345600, 3, false, false,-0.2831, -0.3890, true, 0),
  ('FT-015', 'OFF-016', 'FA-016', 'UNIT-KIC', 'CUS-073', 39600,  7, 5, false, false, 3.00, 37800.00, 0.28, 1.00, 259200, 2, false, false, 0.1185, -0.2780, true, 0),
  -- Normal baseline features (OFF-020 HQ)
  ('FT-016', 'OFF-020', 'FA-020', 'UNIT-HQ',  'CUS-085', 32400,  8, 2, false, false, 1.50, 32400.00, 0.14, 1.00, 604800, 1, false, false,-0.6854, -1.1110, true, 1),
  ('FT-017', 'OFF-020', 'FA-020', 'UNIT-HQ',  'CUS-086', 32400,  8, 2, false, false, 1.80, 32400.00, 0.14, 1.00, 604800, 2, false, false,-0.6854, -0.9440, true, 0),
  -- ANOMALOUS features (these should have extreme z-scores and flags)
  ('FT-A01', 'OFF-001', 'FA-001', 'UNIT-NYA', 'CUS-A01', 10800,  2, 2, true,  false, 4.50, 39200.00, 0.14, 1.00, 86400,  10, false, false,-3.0580,  0.5000, true, 0),
  ('FT-A02', 'OFF-002', 'FA-002', 'UNIT-NYA', 'CUS-A02', 432000, 7, 5, false, false, 3.20, 39600.00, 0.14, 1.00, 172800,  5, false, false, 44.1340, -0.1670, true, 0),
  ('FT-A03', 'OFF-004', 'FA-004', 'UNIT-NYA', 'CUS-A03', 16200, 23, 6, true,  true,  1.50, 37800.00, 0.14, 1.00, 604800,  3, false, false,-2.4533, -1.1110, true, 0),
  ('FT-A04', 'OFF-006', 'FA-006', 'UNIT-KIM', 'CUS-A04', 7200,   6, 1, false, false, 5.00, 38200.00, 0.85, 1.00, 86400,   7, false, true, -3.4608,  0.8330, true, 0),
  ('FT-A05', 'OFF-006', 'FA-001', 'UNIT-KIM', 'CUS-A07', 39600,  7, 3, false, false, 5.20, 38200.00, 0.14, 0.85, 172800,  1, true,  false, 0.1185,  0.9440, true, 1),
  ('FT-A06', 'OFF-016', 'FA-013', 'UNIT-KIC', 'CUS-A08', 39600,  7, 4, false, false, 3.00, 37800.00, 0.14, 0.80, 259200,  1, true,  false, 0.1185, -0.2780, false, 0),
  ('FT-A07', 'OFF-016', 'FA-015', 'UNIT-KIC', 'CUS-A09', 900,   10, 5, false, false, 3.20, 37800.00, 0.28, 1.00, 172800,  4, false, false,-4.1676, -0.1670, true, 0),
  ('FT-A08', 'OFF-017', 'FA-016', 'UNIT-KIC', 'CUS-A10', 39600,  7, 0, false, true,  0.50, 39600.00, 0.14, 1.00, NULL,     1, false, false, 0.1185, -1.6670, true, 0),
  ('FT-A09', 'OFF-020', 'FA-020', 'UNIT-HQ',  'CUS-A11', 198000, 1, 6, true,  true,  2.00, 32400.00, 0.14, 1.00, 259200,  3, false, false, 17.9360, -0.8330, true, 1),
  ('FT-A10', 'OFF-003', 'FA-005', 'UNIT-NYA', 'CUS-A12', 39600,  7, 0, false, true,  1.20, 39600.00, 0.14, 1.00, 2592000, 1, false, false, 0.1185, -1.2780, false, 0);

-- ============================================
-- 17. EXPANDED AUDIT LOGS (comprehensive activity trail)
-- ============================================
INSERT INTO audit_logs (log_id, user_id, action_type, table_name, record_id, new_values, success) VALUES
  -- Firearm registrations
  ('L-00009', 'USR-002', 'CREATE', 'firearms',          'FA-002', '{"action": "HQ firearm registration — Glock 17 Gen5"}',     true),
  ('L-00010', 'USR-002', 'CREATE', 'firearms',          'FA-003', '{"action": "HQ firearm registration — FN SCAR-L"}',         true),
  ('L-00011', 'USR-002', 'CREATE', 'firearms',          'FA-011', '{"action": "HQ firearm registration — Glock 17"}',          true),
  ('L-00012', 'USR-002', 'CREATE', 'firearms',          'FA-015', '{"action": "HQ firearm registration — Glock 17 Gen4"}',     true),
  ('L-00013', 'USR-002', 'CREATE', 'firearms',          'FA-019', '{"action": "HQ firearm registration — Glock 17 Gen5 HQ"}',  true),
  -- Custody operations
  ('L-00014', 'USR-005', 'CREATE', 'custody_records',   'CUS-029', '{"action": "Issued FA-006 to OFF-006 for patrol"}',        true),
  ('L-00015', 'USR-005', 'UPDATE', 'custody_records',   'CUS-029', '{"action": "FA-006 returned by OFF-006"}',                 true),
  ('L-00016', 'USR-006', 'CREATE', 'custody_records',   'CUS-052', '{"action": "Permanent issue FA-011 to OFF-011"}',          true),
  ('L-00017', 'USR-007', 'CREATE', 'custody_records',   'CUS-070', '{"action": "Permanent issue FA-015 to OFF-015"}',          true),
  ('L-00018', 'USR-002', 'CREATE', 'custody_records',   'CUS-084', '{"action": "Permanent issue FA-019 to OFF-019"}',          true),
  -- Loss and workflow operations
  ('L-00019', 'USR-005', 'CREATE', 'loss_reports',      'LOSS-002','{"action": "Stolen firearm report filed — FA-010"}',        true),
  ('L-00020', 'USR-002', 'UPDATE', 'loss_reports',      'LOSS-002','{"action": "Loss report reviewed — under investigation"}',  true),
  ('L-00021', 'USR-004', 'CREATE', 'loss_reports',      'LOSS-003','{"action": "Lost firearm report — FA-005 training grounds"}',true),
  ('L-00022', 'USR-002', 'UPDATE', 'loss_reports',      'LOSS-003','{"action": "Loss report approved"}',                        true),
  ('L-00023', 'USR-004', 'CREATE', 'destruction_requests','DEST-001','{"action": "Destruction request — FA-005 damaged"}',      true),
  ('L-00024', 'USR-006', 'CREATE', 'destruction_requests','DEST-002','{"action": "Destruction request — FA-014 water damage"}', true),
  ('L-00025', 'USR-002', 'UPDATE', 'destruction_requests','DEST-002','{"action": "Destruction approved"}',                      true),
  ('L-00026', 'USR-004', 'CREATE', 'procurement_requests','PROC-001','{"action": "Procurement request — 3 pistols for NYA"}',  true),
  ('L-00027', 'USR-005', 'CREATE', 'procurement_requests','PROC-002','{"action": "Procurement request — 2 rifles for KIM"}',   true),
  ('L-00028', 'USR-002', 'UPDATE', 'procurement_requests','PROC-002','{"action": "Procurement approved"}',                     true),
  ('L-00029', 'USR-007', 'CREATE', 'procurement_requests','PROC-003','{"action": "Procurement request — 5 pistols for KIC"}',  true),
  ('L-00030', 'USR-002', 'UPDATE', 'procurement_requests','PROC-003','{"action": "Procurement rejected — budget insufficient"}',true),
  -- Anomaly related
  ('L-00031', 'USR-008', 'CREATE', 'anomaly_investigations','INV-001','{"action": "Investigation opened for ANO-002"}',        true),
  ('L-00032', 'USR-008', 'UPDATE', 'anomalies',         'ANO-002','{"action": "Anomaly status changed to investigating"}',     true),
  ('L-00033', 'USR-008', 'CREATE', 'anomaly_investigations','INV-002','{"action": "Investigation opened for ANO-005"}',        true),
  ('L-00034', 'USR-009', 'CREATE', 'anomaly_investigations','INV-003','{"action": "Investigation opened for ANO-006"}',        true),
  ('L-00035', 'USR-009', 'UPDATE', 'anomalies',         'ANO-006','{"action": "Anomaly resolved — confirmed authorized"}',     true),
  ('L-00036', 'USR-009', 'UPDATE', 'anomalies',         'ANO-007','{"action": "Anomaly marked as false positive"}',            true),
  -- Ballistic access logs
  ('L-00037', 'USR-008', 'READ',   'ballistic_profiles','BP-004','{"action": "Forensic investigation — robbery case"}',        true),
  ('L-00038', 'USR-009', 'READ',   'ballistic_profiles','BP-005','{"action": "Routine profile review"}',                       true),
  ('L-00039', 'USR-008', 'EXPORT', 'ballistic_profiles','BP-001','{"action": "Court evidence export"}',                        true),
  -- User logins
  ('L-00040', 'USR-002', 'LOGIN',  'users',             'USR-002','{"action": "HQ Commander login"}',                          true),
  ('L-00041', 'USR-004', 'LOGIN',  'users',             'USR-004','{"action": "Station Nyamirambo login"}',                    true),
  ('L-00042', 'USR-005', 'LOGIN',  'users',             'USR-005','{"action": "Station Kimironko login"}',                     true),
  ('L-00043', 'USR-006', 'LOGIN',  'users',             'USR-006','{"action": "Station Remera login"}',                        true),
  ('L-00044', 'USR-007', 'LOGIN',  'users',             'USR-007','{"action": "Station Kicukiro login"}',                      true),
  ('L-00045', 'USR-008', 'LOGIN',  'users',             'USR-008','{"action": "Investigator login"}',                          true),
  ('L-00046', 'USR-009', 'LOGIN',  'users',             'USR-009','{"action": "Investigator 2 login"}',                        true);

-- ============================================
-- REFRESH MATERIALIZED VIEWS
-- ============================================
REFRESH MATERIALIZED VIEW officer_behavior_profile;
REFRESH MATERIALIZED VIEW firearm_usage_profile;
