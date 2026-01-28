-- SafeArms Database Seed Data
-- PostgreSQL 14+
-- Comprehensive sample data for testing and development
-- ============================================
-- IMPORTANT NOTES:
-- 1. All firearms are registered at HQ level by HQ Commanders
-- 2. Firearms are then assigned to units
-- 3. Officers are DATA ENTITIES (not users) for custody tracking
-- 4. Users are SYSTEM USERS who authenticate (admin, hq_commander, station_commander, forensic_analyst)
-- 5. Ballistic profiles are READ-ONLY after creation during HQ registration
-- 6. Password for all test users: Admin@123
-- ============================================

-- ============================================
-- CLEAR ALL EXISTING DATA
-- ============================================

TRUNCATE TABLE audit_logs CASCADE;
TRUNCATE TABLE anomaly_investigations CASCADE;
TRUNCATE TABLE anomalies CASCADE;
TRUNCATE TABLE ml_training_features CASCADE;
TRUNCATE TABLE ml_model_metadata CASCADE;
TRUNCATE TABLE custody_records CASCADE;
TRUNCATE TABLE procurement_requests CASCADE;
TRUNCATE TABLE destruction_requests CASCADE;
TRUNCATE TABLE loss_reports CASCADE;
TRUNCATE TABLE ballistic_profiles CASCADE;
TRUNCATE TABLE firearms CASCADE;
TRUNCATE TABLE officers CASCADE;
TRUNCATE TABLE users CASCADE;
TRUNCATE TABLE units CASCADE;

-- ============================================
-- UNITS (Police Units/Stations)
-- ============================================
-- HQ: a0000000-0000-0000-0000-000000000001
-- Nyamirambo: a0000000-0000-0000-0000-000000000002
-- Kimironko: a0000000-0000-0000-0000-000000000003
-- Remera: a0000000-0000-0000-0000-000000000004
-- Kicukiro: a0000000-0000-0000-0000-000000000005
-- Training: a0000000-0000-0000-0000-000000000006

INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, contact_phone, contact_email, commander_name, is_active)
VALUES 
(
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'RNP Headquarters',
    'headquarters',
    'Kacyiru, Kigali',
    'Kigali City',
    'Gasabo',
    '+250788000001',
    'hq@rnp.gov.rw',
    'Commissioner General',
    true
),
(
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'Nyamirambo Police Station',
    'station',
    'Nyamirambo, Kigali',
    'Kigali City',
    'Nyarugenge',
    '+250788000002',
    'nyamirambo@rnp.gov.rw',
    'IP Mugabo Jean',
    true
),
(
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'Kimironko Police Station',
    'station',
    'Kimironko, Kigali',
    'Kigali City',
    'Gasabo',
    '+250788000003',
    'kimironko@rnp.gov.rw',
    'IP Uwimana Marie',
    true
),
(
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'Remera Police Station',
    'station',
    'Remera, Kigali',
    'Kigali City',
    'Gasabo',
    '+250788000004',
    'remera@rnp.gov.rw',
    'IP Habimana Pierre',
    true
),
(
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'Kicukiro Police Station',
    'station',
    'Kicukiro, Kigali',
    'Kigali City',
    'Kicukiro',
    '+250788000005',
    'kicukiro@rnp.gov.rw',
    'IP Niyonsaba Claire',
    true
),
(
    'a0000000-0000-0000-0000-000000000006'::uuid,
    'Police Training School',
    'specialized',
    'Gishari, Rwamagana',
    'Eastern Province',
    'Rwamagana',
    '+250788000006',
    'training@rnp.gov.rw',
    'ACP Ntawuyirushintege Jean',
    true
);

-- ============================================
-- USERS (System Users who authenticate)
-- ============================================
-- Password for all users: Admin@123
-- BCrypt hash: $2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q

-- 1. Admin User (at HQ)
INSERT INTO users (
    user_id, username, password_hash, full_name, email, phone_number, 
    role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password
) VALUES (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    'admin',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'System Administrator',
    'admin@rnp.gov.rw',
    '+250788000100',
    'admin',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true, true, true, false
);

-- 2. HQ Firearm Commanders (2 users at HQ)
INSERT INTO users (
    user_id, username, password_hash, full_name, email, phone_number, 
    role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'hq_commander',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'CSP Nkusi Patrick',
    'nkusi.patrick@rnp.gov.rw',
    '+250788000101',
    'hq_firearm_commander',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true, true, true, false
),
(
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'hq_commander2',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'CSP Mukamana Jeanne',
    'mukamana.jeanne@rnp.gov.rw',
    '+250788000102',
    'hq_firearm_commander',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true, true, true, false
);

-- 3. Station Commanders (one per station)
INSERT INTO users (
    user_id, username, password_hash, full_name, email, phone_number, 
    role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'station_nyamirambo',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Mugabo Jean',
    'mugabo.jean@rnp.gov.rw',
    '+250788000103',
    'station_commander',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    true, true, true, false
),
(
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'station_kimironko',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Uwimana Marie',
    'uwimana.marie@rnp.gov.rw',
    '+250788000104',
    'station_commander',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    true, true, true, false
),
(
    'b0000000-0000-0000-0000-000000000006'::uuid,
    'station_remera',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Habimana Pierre',
    'habimana.pierre@rnp.gov.rw',
    '+250788000105',
    'station_commander',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    true, true, true, false
),
(
    'b0000000-0000-0000-0000-000000000007'::uuid,
    'station_kicukiro',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Niyonsaba Claire',
    'niyonsaba.claire@rnp.gov.rw',
    '+250788000106',
    'station_commander',
    'a0000000-0000-0000-0000-000000000005'::uuid,
    true, true, true, false
);

-- 4. Forensic Analysts (at HQ)
INSERT INTO users (
    user_id, username, password_hash, full_name, email, phone_number, 
    role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000008'::uuid,
    'forensic_analyst',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'Dr. Kamanzi Eric',
    'kamanzi.eric@rnp.gov.rw',
    '+250788000107',
    'forensic_analyst',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true, true, true, false
),
(
    'b0000000-0000-0000-0000-000000000009'::uuid,
    'forensic_analyst2',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'Dr. Ingabire Alice',
    'ingabire.alice@rnp.gov.rw',
    '+250788000108',
    'forensic_analyst',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true, true, true, false
);

-- ============================================
-- OFFICERS (Data entities for custody - NOT system users)
-- ============================================
-- Officers are assigned to specific stations
-- They can receive firearms but CANNOT log in to the system

-- Nyamirambo Station Officers (3 officers)
INSERT INTO officers (
    officer_id, officer_number, full_name, rank, unit_id, 
    phone_number, email, firearm_certified, is_active
) VALUES 
(
    'c0000000-0000-0000-0000-000000000001'::uuid,
    'RNP-2024-001',
    'P/Cst. Mugisha Jean-Baptiste',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788200001',
    'mugisha.jb@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000002'::uuid,
    'RNP-2024-002',
    'P/Cst. Uwase Marie-Claire',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788200002',
    'uwase.mc@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000003'::uuid,
    'RNP-2024-003',
    'Sgt. Ndayisaba Paul',
    'Sergeant',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788200003',
    'ndayisaba.paul@rnp.gov.rw',
    true, true
);

-- Kimironko Station Officers (3 officers)
INSERT INTO officers (
    officer_id, officer_number, full_name, rank, unit_id, 
    phone_number, email, firearm_certified, is_active
) VALUES 
(
    'c0000000-0000-0000-0000-000000000004'::uuid,
    'RNP-2024-004',
    'P/Cst. Habimana David',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '+250788200004',
    'habimana.david@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000005'::uuid,
    'RNP-2024-005',
    'P/Cst. Mukamana Rose',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '+250788200005',
    'mukamana.rose@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000006'::uuid,
    'RNP-2024-006',
    'IP Nshuti Emmanuel',
    'Inspector of Police',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '+250788200006',
    'nshuti.emmanuel@rnp.gov.rw',
    true, true
);

-- Remera Station Officers (3 officers)
INSERT INTO officers (
    officer_id, officer_number, full_name, rank, unit_id, 
    phone_number, email, firearm_certified, is_active
) VALUES 
(
    'c0000000-0000-0000-0000-000000000007'::uuid,
    'RNP-2024-007',
    'Sgt. Nshimiyimana Felix',
    'Sergeant',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    '+250788200007',
    'nshimiyimana.felix@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000008'::uuid,
    'RNP-2024-008',
    'P/Cst. Uwera Diane',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    '+250788200008',
    'uwera.diane@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000009'::uuid,
    'RNP-2024-009',
    'P/Cst. Keza Patrick',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    '+250788200009',
    'keza.patrick@rnp.gov.rw',
    true, true
);

-- Kicukiro Station Officers (3 officers)
INSERT INTO officers (
    officer_id, officer_number, full_name, rank, unit_id, 
    phone_number, email, firearm_certified, is_active
) VALUES 
(
    'c0000000-0000-0000-0000-000000000010'::uuid,
    'RNP-2024-010',
    'IP Mugabo Vincent',
    'Inspector of Police',
    'a0000000-0000-0000-0000-000000000005'::uuid,
    '+250788200010',
    'mugabo.vincent@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000011'::uuid,
    'RNP-2024-011',
    'Sgt. Irakoze Grace',
    'Sergeant',
    'a0000000-0000-0000-0000-000000000005'::uuid,
    '+250788200011',
    'irakoze.grace@rnp.gov.rw',
    true, true
),
(
    'c0000000-0000-0000-0000-000000000012'::uuid,
    'RNP-2024-012',
    'P/Cst. Niyonzima Claude',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000005'::uuid,
    '+250788200012',
    'niyonzima.claude@rnp.gov.rw',
    true, true
);

-- ============================================
-- FIREARMS (All registered at HQ level)
-- ============================================
-- All firearms are registered by HQ commanders (registration_level = 'hq')
-- Then assigned to specific units (assigned_unit_id)

-- Firearms for Nyamirambo Station (4 firearms)
INSERT INTO firearms (
    firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
    manufacture_year, acquisition_date, acquisition_source, 
    registration_level, registered_by, assigned_unit_id, current_status, is_active
) VALUES 
(
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'GLK-2023-0001',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-01-15',
    'Government Procurement - Contract GP/2024/001',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'GLK-2023-0002',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-01-15',
    'Government Procurement - Contract GP/2024/001',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000003'::uuid,
    'SIG-2023-0001',
    'SIG Sauer',
    'P320',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-02-01',
    'Government Procurement - Contract GP/2024/002',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000004'::uuid,
    'FNH-2022-0001',
    'FN Herstal',
    'FN SCAR-L',
    'rifle',
    '5.56mm NATO',
    2022,
    '2023-06-20',
    'Government Procurement - Contract GP/2023/015',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'available',
    true
);

-- Firearms for Kimironko Station (4 firearms)
INSERT INTO firearms (
    firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
    manufacture_year, acquisition_date, acquisition_source, 
    registration_level, registered_by, assigned_unit_id, current_status, is_active
) VALUES 
(
    'd0000000-0000-0000-0000-000000000005'::uuid,
    'GLK-2023-0003',
    'Glock',
    'Glock 19 Gen5',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-01-15',
    'Government Procurement - Contract GP/2024/001',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000006'::uuid,
    'GLK-2023-0004',
    'Glock',
    'Glock 19 Gen5',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-01-15',
    'Government Procurement - Contract GP/2024/001',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000007'::uuid,
    'BER-2023-0001',
    'Beretta',
    'M9A3',
    'pistol',
    '9mm Parabellum',
    2023,
    '2024-03-01',
    'Government Procurement - Contract GP/2024/003',
    'hq',
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000008'::uuid,
    'FNH-2022-0002',
    'FN Herstal',
    'FN SCAR-H',
    'rifle',
    '7.62mm NATO',
    2022,
    '2023-06-20',
    'Government Procurement - Contract GP/2023/015',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'available',
    true
);

-- Firearms for Remera Station (4 firearms)
INSERT INTO firearms (
    firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
    manufacture_year, acquisition_date, acquisition_source, 
    registration_level, registered_by, assigned_unit_id, current_status, is_active
) VALUES 
(
    'd0000000-0000-0000-0000-000000000009'::uuid,
    'GLK-2024-0001',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-06-01',
    'Government Procurement - Contract GP/2024/010',
    'hq',
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000010'::uuid,
    'GLK-2024-0002',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-06-01',
    'Government Procurement - Contract GP/2024/010',
    'hq',
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000011'::uuid,
    'SIG-2024-0001',
    'SIG Sauer',
    'P226',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-06-15',
    'Government Procurement - Contract GP/2024/011',
    'hq',
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000012'::uuid,
    'REM-2023-0001',
    'Remington',
    '870 Express Tactical',
    'shotgun',
    '12 Gauge',
    2023,
    '2024-02-15',
    'Government Procurement - Contract GP/2024/004',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'available',
    true
);

-- Firearms for Kicukiro Station (4 firearms)
INSERT INTO firearms (
    firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
    manufacture_year, acquisition_date, acquisition_source, 
    registration_level, registered_by, assigned_unit_id, current_status, is_active
) VALUES 
(
    'd0000000-0000-0000-0000-000000000013'::uuid,
    'GLK-2024-0003',
    'Glock',
    'Glock 19 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-06-01',
    'Government Procurement - Contract GP/2024/010',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000014'::uuid,
    'GLK-2024-0004',
    'Glock',
    'Glock 19 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-06-01',
    'Government Procurement - Contract GP/2024/010',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'in_custody',
    true
),
(
    'd0000000-0000-0000-0000-000000000015'::uuid,
    'BER-2024-0001',
    'Beretta',
    'APX',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-07-01',
    'Government Procurement - Contract GP/2024/012',
    'hq',
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000016'::uuid,
    'HK-2023-0001',
    'Heckler & Koch',
    'MP5A3',
    'submachine_gun',
    '9mm Parabellum',
    2023,
    '2024-01-10',
    'Government Procurement - Contract GP/2024/001',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'available',
    true
);

-- Unassigned firearms at HQ (2 firearms awaiting distribution)
INSERT INTO firearms (
    firearm_id, serial_number, manufacturer, model, firearm_type, caliber,
    manufacture_year, acquisition_date, acquisition_source, 
    registration_level, registered_by, assigned_unit_id, current_status, is_active
) VALUES 
(
    'd0000000-0000-0000-0000-000000000017'::uuid,
    'GLK-2024-0005',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-08-01',
    'Government Procurement - Contract GP/2024/015',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    NULL,
    'unassigned',
    true
),
(
    'd0000000-0000-0000-0000-000000000018'::uuid,
    'GLK-2024-0006',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm Parabellum',
    2024,
    '2024-08-01',
    'Government Procurement - Contract GP/2024/015',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    NULL,
    'unassigned',
    true
);

-- ============================================
-- BALLISTIC PROFILES (Created during HQ registration)
-- ============================================
-- These are READ-ONLY profiles created when firearms are registered
-- They can be searched/matched but NEVER modified

INSERT INTO ballistic_profiles (
    ballistic_id, firearm_id, test_date, test_location,
    rifling_characteristics, firing_pin_impression, ejector_marks,
    extractor_marks, chamber_marks, test_conducted_by, forensic_lab,
    test_ammunition, notes
) VALUES 
(
    'e0000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000001'::uuid,
    '2024-01-18',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:9.84" twist rate, polygonal rifling',
    'Rectangular, centered, 0.75mm x 0.80mm',
    'Semi-circular impression at 2 o''clock position, slight drag mark',
    'Linear striation at 6 o''clock, 0.3mm depth',
    'Parallel striations on case head',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Laboratory',
    'Federal 9mm 124gr FMJ',
    'Test fired 5 rounds. Clear and consistent markings observed.'
),
(
    'e0000000-0000-0000-0000-000000000002'::uuid,
    'd0000000-0000-0000-0000-000000000002'::uuid,
    '2024-01-18',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:9.84" twist rate, polygonal rifling',
    'Rectangular, centered, 0.78mm x 0.82mm',
    'Semi-circular impression at 2 o''clock position',
    'Linear striation at 6 o''clock, 0.28mm depth',
    'Parallel striations on case head',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Laboratory',
    'Federal 9mm 124gr FMJ',
    'Test fired 5 rounds. Slightly different firing pin impression than GLK-2023-0001.'
),
(
    'e0000000-0000-0000-0000-000000000003'::uuid,
    'd0000000-0000-0000-0000-000000000003'::uuid,
    '2024-02-05',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:10" twist rate, traditional rifling',
    'Circular, slightly off-center left, 0.85mm diameter',
    'Rectangular impression at 4 o''clock position',
    'Curved striation at 5 o''clock',
    'Concentric circles on case head',
    'Dr. Ingabire Alice',
    'RNP Central Forensic Laboratory',
    'Winchester 9mm 147gr FMJ',
    'Test fired 5 rounds. SIG Sauer characteristic patterns observed.'
),
(
    'e0000000-0000-0000-0000-000000000004'::uuid,
    'd0000000-0000-0000-0000-000000000004'::uuid,
    '2023-06-25',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:7" twist rate, chrome-lined barrel',
    'Circular, centered, 0.70mm diameter',
    'Triangular impression at 1 o''clock position',
    'Double linear striations at 7 o''clock',
    'Radial striations from bolt face',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Laboratory',
    'M855 5.56mm 62gr FMJ',
    'Test fired 3 rounds. FN SCAR-L specific markings recorded.'
),
(
    'e0000000-0000-0000-0000-000000000005'::uuid,
    'd0000000-0000-0000-0000-000000000005'::uuid,
    '2024-01-20',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:9.84" twist rate, polygonal rifling',
    'Rectangular, centered, 0.72mm x 0.78mm',
    'Semi-circular impression at 3 o''clock position',
    'Linear striation at 6 o''clock',
    'Parallel striations on case head',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Laboratory',
    'Federal 9mm 124gr FMJ',
    'Test fired 5 rounds. Glock 19 Gen5 characteristics.'
),
(
    'e0000000-0000-0000-0000-000000000006'::uuid,
    'd0000000-0000-0000-0000-000000000006'::uuid,
    '2024-01-20',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:9.84" twist rate, polygonal rifling',
    'Rectangular, centered, 0.74mm x 0.79mm',
    'Semi-circular impression at 3 o''clock position, slight asymmetry',
    'Linear striation at 6 o''clock',
    'Parallel striations on case head',
    'Dr. Ingabire Alice',
    'RNP Central Forensic Laboratory',
    'Federal 9mm 124gr FMJ',
    'Test fired 5 rounds. Similar to GLK-2023-0003 but distinguishable by firing pin.'
),
(
    'e0000000-0000-0000-0000-000000000007'::uuid,
    'd0000000-0000-0000-0000-000000000007'::uuid,
    '2024-03-05',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:10" twist rate, traditional rifling',
    'Circular, centered, 0.68mm diameter',
    'Rectangular impression at 2 o''clock position',
    'Curved striation at 8 o''clock',
    'Star pattern from extractor',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Laboratory',
    'Beretta 9mm 115gr FMJ',
    'Test fired 5 rounds. Beretta M9A3 distinctive extractor pattern.'
),
(
    'e0000000-0000-0000-0000-000000000008'::uuid,
    'd0000000-0000-0000-0000-000000000009'::uuid,
    '2024-06-05',
    'RNP Central Forensic Laboratory',
    '6 grooves, right-hand twist, 1:9.84" twist rate, polygonal rifling',
    'Rectangular, centered, 0.76mm x 0.81mm',
    'Semi-circular impression at 2 o''clock position',
    'Linear striation at 6 o''clock, 0.32mm depth',
    'Parallel striations on case head',
    'Dr. Ingabire Alice',
    'RNP Central Forensic Laboratory',
    'Federal 9mm 124gr FMJ',
    'Test fired 5 rounds. 2024 production Glock 17.'
);

-- ============================================
-- CUSTODY RECORDS (Firearm assignments to officers)
-- ============================================

-- Active Custody: Nyamirambo Station
INSERT INTO custody_records (
    custody_id, firearm_id, officer_id, unit_id, custody_type,
    issued_at, issued_by, expected_return_date, assignment_reason, notes
) VALUES 
(
    'f0000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'c0000000-0000-0000-0000-000000000001'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'permanent',
    '2024-01-20 08:00:00',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    NULL,
    'Standard duty firearm assignment',
    'Officer Mugisha assigned personal duty weapon'
),
(
    'f0000000-0000-0000-0000-000000000002'::uuid,
    'd0000000-0000-0000-0000-000000000003'::uuid,
    'c0000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'permanent',
    '2024-02-10 09:30:00',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    NULL,
    'Sergeant duty weapon',
    'Sgt. Ndayisaba assigned SIG Sauer as rank-appropriate weapon'
);

-- Active Custody: Kimironko Station
INSERT INTO custody_records (
    custody_id, firearm_id, officer_id, unit_id, custody_type,
    issued_at, issued_by, expected_return_date, assignment_reason, notes
) VALUES 
(
    'f0000000-0000-0000-0000-000000000003'::uuid,
    'd0000000-0000-0000-0000-000000000005'::uuid,
    'c0000000-0000-0000-0000-000000000004'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'permanent',
    '2024-01-22 07:45:00',
    'b0000000-0000-0000-0000-000000000005'::uuid,
    NULL,
    'Standard duty firearm assignment',
    'Officer Habimana duty weapon'
),
(
    'f0000000-0000-0000-0000-000000000004'::uuid,
    'd0000000-0000-0000-0000-000000000007'::uuid,
    'c0000000-0000-0000-0000-000000000006'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'permanent',
    '2024-03-08 08:15:00',
    'b0000000-0000-0000-0000-000000000005'::uuid,
    NULL,
    'Inspector personal weapon',
    'IP Nshuti assigned Beretta M9A3'
);

-- Active Custody: Remera Station
INSERT INTO custody_records (
    custody_id, firearm_id, officer_id, unit_id, custody_type,
    issued_at, issued_by, expected_return_date, assignment_reason, notes
) VALUES 
(
    'f0000000-0000-0000-0000-000000000005'::uuid,
    'd0000000-0000-0000-0000-000000000009'::uuid,
    'c0000000-0000-0000-0000-000000000007'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'permanent',
    '2024-06-08 08:00:00',
    'b0000000-0000-0000-0000-000000000006'::uuid,
    NULL,
    'Sergeant duty weapon',
    'Sgt. Nshimiyimana assigned new Glock 17'
);

-- Active Custody: Kicukiro Station
INSERT INTO custody_records (
    custody_id, firearm_id, officer_id, unit_id, custody_type,
    issued_at, issued_by, expected_return_date, assignment_reason, notes
) VALUES 
(
    'f0000000-0000-0000-0000-000000000006'::uuid,
    'd0000000-0000-0000-0000-000000000013'::uuid,
    'c0000000-0000-0000-0000-000000000010'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'permanent',
    '2024-06-10 07:30:00',
    'b0000000-0000-0000-0000-000000000007'::uuid,
    NULL,
    'Inspector personal weapon',
    'IP Mugabo Vincent duty weapon'
),
(
    'f0000000-0000-0000-0000-000000000007'::uuid,
    'd0000000-0000-0000-0000-000000000014'::uuid,
    'c0000000-0000-0000-0000-000000000011'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'permanent',
    '2024-06-10 08:00:00',
    'b0000000-0000-0000-0000-000000000007'::uuid,
    NULL,
    'Sergeant duty weapon',
    'Sgt. Irakoze assigned Glock 19'
);

-- Completed Custody Record (returned firearm - historical data)
INSERT INTO custody_records (
    custody_id, firearm_id, officer_id, unit_id, custody_type,
    issued_at, issued_by, expected_return_date, returned_at, returned_to,
    return_condition, assignment_reason, notes
) VALUES 
(
    'f0000000-0000-0000-0000-000000000008'::uuid,
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'c0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'temporary',
    '2024-03-01 06:00:00',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    '2024-03-01',
    '2024-03-01 18:30:00',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'good',
    'Special patrol duty',
    'Officer Uwase used weapon for patrol shift and returned end of day'
);

-- ============================================
-- LOSS REPORTS (Sample workflow items)
-- ============================================

-- One pending loss report (awaiting HQ review)
INSERT INTO loss_reports (
    loss_id, firearm_id, unit_id, reported_by, officer_id,
    loss_type, loss_date, loss_location, circumstances,
    police_case_number, status
) VALUES 
(
    'a1000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000010'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'b0000000-0000-0000-0000-000000000006'::uuid,
    'c0000000-0000-0000-0000-000000000008'::uuid,
    'lost',
    '2024-08-15',
    'Remera Sector, during patrol near Remera Bus Park',
    'Officer Uwera reported that during a foot chase of a suspect, the firearm fell from the holster. After extensive search, the weapon could not be located. Area was searched by multiple officers. CCTV footage from nearby shops being reviewed.',
    'RNP/REM/2024/0456',
    'pending'
);

-- ============================================
-- DESTRUCTION REQUESTS (Sample workflow items)
-- ============================================

-- One pending destruction request
INSERT INTO destruction_requests (
    destruction_id, firearm_id, unit_id, requested_by,
    destruction_reason, condition_description, status
) VALUES 
(
    'a2000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000011'::uuid,
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'b0000000-0000-0000-0000-000000000006'::uuid,
    'Barrel wear beyond safe operational parameters. Multiple misfires during range qualification. Armorer recommends decommissioning.',
    'Significant barrel erosion, worn rifling affecting accuracy. Firing pin spring weakened. General wear consistent with high round count.',
    'pending'
);

-- ============================================
-- PROCUREMENT REQUESTS (Sample workflow items)
-- ============================================

-- Multiple procurement requests at different stages
INSERT INTO procurement_requests (
    procurement_id, unit_id, requested_by, firearm_type,
    quantity, justification, priority, estimated_cost, status
) VALUES 
(
    'a3000000-0000-0000-0000-000000000001'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'pistol',
    5,
    'Nyamirambo station has expanded patrol zones. Currently 3 officers share 4 pistols. Need additional pistols to ensure all patrol officers have assigned weapons.',
    'high',
    2500000.00,
    'pending'
),
(
    'a3000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'rifle',
    2,
    'Kimironko station requires tactical rifles for VIP escort duties and high-risk operations. Current inventory only has pistols.',
    'routine',
    3200000.00,
    'pending'
),
(
    'a3000000-0000-0000-0000-000000000003'::uuid,
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'b0000000-0000-0000-0000-000000000007'::uuid,
    'pistol',
    3,
    'New officers joining Kicukiro station next month. Need additional service pistols.',
    'routine',
    1500000.00,
    'approved'
);

-- ============================================
-- ANOMALIES (Sample ML-detected anomalies)
-- ============================================

-- Sample anomaly for investigation
INSERT INTO anomalies (
    anomaly_id, custody_record_id, firearm_id, officer_id, unit_id,
    anomaly_score, anomaly_type, detection_method, severity,
    confidence_level, contributing_factors, status
) VALUES 
(
    'a4000000-0000-0000-0000-000000000001'::uuid,
    'f0000000-0000-0000-0000-000000000008'::uuid,
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'c0000000-0000-0000-0000-000000000002'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    0.78,
    'rapid_exchange',
    'statistical',
    'low',
    0.85,
    '{"issue_hour": 6, "is_early_morning": true, "custody_duration_hours": 12.5}'::jsonb,
    'resolved'
);

-- ============================================
-- NOTES FOR TESTING
-- ============================================

-- Password Information:
-- All test users use the same password: Admin@123
-- BCrypt hash: $2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q

-- Login Credentials:
-- Admin:           admin / Admin@123
-- HQ Commander 1:  hq_commander / Admin@123
-- HQ Commander 2:  hq_commander2 / Admin@123
-- Nyamirambo:      station_nyamirambo / Admin@123
-- Kimironko:       station_kimironko / Admin@123
-- Remera:          station_remera / Admin@123
-- Kicukiro:        station_kicukiro / Admin@123
-- Forensic 1:      forensic_analyst / Admin@123
-- Forensic 2:      forensic_analyst2 / Admin@123

-- Data Summary:
-- Units: 6 (1 HQ, 4 stations, 1 training school)
-- Users: 9 (1 admin, 2 hq_commanders, 4 station_commanders, 2 forensic_analysts)
-- Officers: 12 (3 per station)
-- Firearms: 18 (4 per station + 2 unassigned at HQ)
-- Ballistic Profiles: 8
-- Active Custody Records: 7
-- Historical Custody Records: 1
-- Loss Reports: 1 (pending)
-- Destruction Requests: 1 (pending)
-- Procurement Requests: 3 (2 pending, 1 approved)
-- Anomalies: 1 (resolved)

-- SafeArms seed data loaded successfully
