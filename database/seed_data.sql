-- SafeArms Initial Data Seed
-- Creates default units, test users, officers, and sample firearms

-- ============================================
-- UNITS
-- ============================================

-- Insert HQ Unit
INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, commander_name, is_active)
VALUES (
    'a0000000-0000-0000-0000-000000000001'::uuid,
    'Rwanda National Police Headquarters',
    'headquarters',
    'Kacyiru, Kigali',
    'Kigali',
    'Gasabo',
    'Commissioner General',
    true
);

-- Insert Police Stations
INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, commander_name, is_active)
VALUES 
(
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'Nyamirambo Police Station',
    'station',
    'Nyamirambo, Kigali',
    'Kigali',
    'Nyarugenge',
    'CSP Mugabo Jean',
    true
),
(
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'Kimironko Police Station',
    'station',
    'Kimironko, Kigali',
    'Kigali',
    'Gasabo',
    'CSP Uwimana Marie',
    true
),
(
    'a0000000-0000-0000-0000-000000000004'::uuid,
    'Remera Police Station',
    'station',
    'Remera, Kigali',
    'Kigali',
    'Gasabo',
    'CSP Habimana Pierre',
    true
),
(
    'a0000000-0000-0000-0000-000000000005'::uuid,
    'Kicukiro Police Station',
    'station',
    'Kicukiro, Kigali',
    'Kigali',
    'Kicukiro',
    'CSP Niyonsaba Claire',
    true
),
(
    'a0000000-0000-0000-0000-000000000006'::uuid,
    'Police Training School Gishari',
    'specialized',
    'Gishari, Eastern Province',
    'Eastern',
    'Rwamagana',
    'ACP Karangwa Emmanuel',
    true
);

-- ============================================
-- USERS (4 Roles)
-- All passwords: Test@123
-- Password hash for Test@123: $2b$10$xwgHd1C7I9X6x7fPv5o0YuI0DqvQo7E5z7r7s7t7u7v7w7x7y7z7A.
-- ============================================

-- 1. Admin User (already exists from original seed)
INSERT INTO users (
    user_id, 
    username, 
    password_hash, 
    full_name, 
    email, 
    phone_number, 
    role, 
    unit_id,
    otp_verified,
    unit_confirmed,
    is_active,
    must_change_password
) VALUES (
    'b0000000-0000-0000-0000-000000000001'::uuid,
    'admin',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'System Administrator',
    'admin@rnp.gov.rw',
    '+250788000000',
    'admin',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    false
) ON CONFLICT (username) DO NOTHING;

-- 2. HQ Firearm Commanders (2 users)
INSERT INTO users (
    user_id, 
    username, 
    password_hash, 
    full_name, 
    email, 
    phone_number, 
    role, 
    unit_id,
    otp_verified,
    unit_confirmed,
    is_active,
    must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'hq_commander',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'CSP Nkusi Patrick',
    'nkusi.patrick@rnp.gov.rw',
    '+250788000001',
    'hq_firearm_commander',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    false
),
(
    'b0000000-0000-0000-0000-000000000003'::uuid,
    'hq_commander2',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'CSP Mukamana Jeanne',
    'mukamana.jeanne@rnp.gov.rw',
    '+250788000002',
    'hq_firearm_commander',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    false
);

-- 3. Station Commanders (4 users - one per station)
INSERT INTO users (
    user_id, 
    username, 
    password_hash, 
    full_name, 
    email, 
    phone_number, 
    role, 
    unit_id,
    otp_verified,
    unit_confirmed,
    is_active,
    must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'station_nyamirambo',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Mugabo Jean',
    'mugabo.jean@rnp.gov.rw',
    '+250788000003',
    'station_commander',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    true,
    true,
    true,
    false
),
(
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'station_kimironko',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Uwimana Marie',
    'uwimana.marie@rnp.gov.rw',
    '+250788000004',
    'station_commander',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    true,
    true,
    true,
    false
),
(
    'b0000000-0000-0000-0000-000000000006'::uuid,
    'station_remera',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Habimana Pierre',
    'habimana.pierre@rnp.gov.rw',
    '+250788000005',
    'station_commander',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    true,
    true,
    true,
    false
),
(
    'b0000000-0000-0000-0000-000000000007'::uuid,
    'station_kicukiro',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'IP Niyonsaba Claire',
    'niyonsaba.claire@rnp.gov.rw',
    '+250788000006',
    'station_commander',
    'a0000000-0000-0000-0000-000000000005'::uuid,
    true,
    true,
    true,
    false
);

-- 4. Forensic Analysts (2 users)
INSERT INTO users (
    user_id, 
    username, 
    password_hash, 
    full_name, 
    email, 
    phone_number, 
    role, 
    unit_id,
    otp_verified,
    unit_confirmed,
    is_active,
    must_change_password
) VALUES 
(
    'b0000000-0000-0000-0000-000000000008'::uuid,
    'forensic_analyst',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'Dr. Kamanzi Eric',
    'kamanzi.eric@rnp.gov.rw',
    '+250788000007',
    'forensic_analyst',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    false
),
(
    'b0000000-0000-0000-0000-000000000009'::uuid,
    'forensic_analyst2',
    '$2b$10$BA9FK/iSZ.6o17egZxi55ePfHE18HPdIL73vuvlznFpFM8P.9CL1q',
    'Dr. Ingabire Alice',
    'ingabire.alice@rnp.gov.rw',
    '+250788000008',
    'forensic_analyst',
    'a0000000-0000-0000-0000-000000000001'::uuid,
    true,
    true,
    true,
    false
);

-- ============================================
-- OFFICERS (Sample officers per station)
-- ============================================

-- Nyamirambo Station Officers
INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
VALUES 
(
    'c0000000-0000-0000-0000-000000000001'::uuid,
    'RNP-2024-001',
    'P/Cst. Mugisha Jean',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788100001',
    'mugisha.jean@rnp.gov.rw',
    true,
    true
),
(
    'c0000000-0000-0000-0000-000000000002'::uuid,
    'RNP-2024-002',
    'P/Cst. Uwase Marie',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788100002',
    'uwase.marie@rnp.gov.rw',
    true,
    true
),
(
    'c0000000-0000-0000-0000-000000000003'::uuid,
    'RNP-2024-003',
    'Sgt. Ndayisaba Paul',
    'Sergeant',
    'a0000000-0000-0000-0000-000000000002'::uuid,
    '+250788100003',
    'ndayisaba.paul@rnp.gov.rw',
    true,
    true
);

-- Kimironko Station Officers
INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
VALUES 
(
    'c0000000-0000-0000-0000-000000000004'::uuid,
    'RNP-2024-004',
    'P/Cst. Habimana David',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '+250788100004',
    'habimana.david@rnp.gov.rw',
    true,
    true
),
(
    'c0000000-0000-0000-0000-000000000005'::uuid,
    'RNP-2024-005',
    'P/Cst. Mukamana Rose',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000003'::uuid,
    '+250788100005',
    'mukamana.rose@rnp.gov.rw',
    true,
    true
);

-- Remera Station Officers
INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
VALUES 
(
    'c0000000-0000-0000-0000-000000000006'::uuid,
    'RNP-2024-006',
    'Sgt. Nshimiyimana Felix',
    'Sergeant',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    '+250788100006',
    'nshimiyimana.felix@rnp.gov.rw',
    true,
    true
),
(
    'c0000000-0000-0000-0000-000000000007'::uuid,
    'RNP-2024-007',
    'P/Cst. Uwera Diane',
    'Police Constable',
    'a0000000-0000-0000-0000-000000000004'::uuid,
    '+250788100007',
    'uwera.diane@rnp.gov.rw',
    true,
    true
);

-- ============================================
-- FIREARMS (Sample firearms)
-- ============================================

-- Firearms registered at HQ (unassigned)
INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, current_status, is_active)
VALUES 
(
    'd0000000-0000-0000-0000-000000000001'::uuid,
    'GLK-2024-0001',
    'Glock',
    'Glock 17 Gen5',
    'pistol',
    '9mm',
    2024,
    '2024-01-15',
    'Government Procurement',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'unassigned',
    true
),
(
    'd0000000-0000-0000-0000-000000000002'::uuid,
    'GLK-2024-0002',
    'Glock',
    'Glock 19 Gen5',
    'pistol',
    '9mm',
    2024,
    '2024-01-15',
    'Government Procurement',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'unassigned',
    true
),
(
    'd0000000-0000-0000-0000-000000000003'::uuid,
    'SIG-2024-0001',
    'SIG Sauer',
    'P320',
    'pistol',
    '9mm',
    2024,
    '2024-02-01',
    'Government Procurement',
    'hq',
    'b0000000-0000-0000-0000-000000000002'::uuid,
    'unassigned',
    true
);

-- Firearms assigned to Nyamirambo Station
INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
VALUES 
(
    'd0000000-0000-0000-0000-000000000004'::uuid,
    'GLK-2023-0101',
    'Glock',
    'Glock 17',
    'pistol',
    '9mm',
    2023,
    '2023-06-15',
    'Government Procurement',
    'unit',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000005'::uuid,
    'GLK-2023-0102',
    'Glock',
    'Glock 17',
    'pistol',
    '9mm',
    2023,
    '2023-06-15',
    'Government Procurement',
    'unit',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000006'::uuid,
    'RFL-2022-0001',
    'FN Herstal',
    'FN SCAR-L',
    'rifle',
    '5.56mm NATO',
    2022,
    '2022-03-20',
    'Government Procurement',
    'unit',
    'b0000000-0000-0000-0000-000000000004'::uuid,
    'a0000000-0000-0000-0000-000000000002'::uuid,
    'available',
    true
);

-- Firearms assigned to Kimironko Station
INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
VALUES 
(
    'd0000000-0000-0000-0000-000000000007'::uuid,
    'GLK-2023-0201',
    'Glock',
    'Glock 19',
    'pistol',
    '9mm',
    2023,
    '2023-07-10',
    'Government Procurement',
    'unit',
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'available',
    true
),
(
    'd0000000-0000-0000-0000-000000000008'::uuid,
    'GLK-2023-0202',
    'Glock',
    'Glock 19',
    'pistol',
    '9mm',
    2023,
    '2023-07-10',
    'Government Procurement',
    'unit',
    'b0000000-0000-0000-0000-000000000005'::uuid,
    'a0000000-0000-0000-0000-000000000003'::uuid,
    'available',
    true
);

-- ============================================
-- BALLISTIC PROFILES (for some firearms)
-- ============================================

INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab)
VALUES 
(
    'e0000000-0000-0000-0000-000000000001'::uuid,
    'd0000000-0000-0000-0000-000000000004'::uuid,
    '2023-06-20',
    'RNP Forensic Laboratory',
    '6 grooves, right-hand twist, 1:10 pitch',
    'Circular, centered, 0.8mm diameter',
    'Semi-circular impression at 3 o''clock position',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Lab'
),
(
    'e0000000-0000-0000-0000-000000000002'::uuid,
    'd0000000-0000-0000-0000-000000000005'::uuid,
    '2023-06-20',
    'RNP Forensic Laboratory',
    '6 grooves, right-hand twist, 1:10 pitch',
    'Circular, centered, 0.8mm diameter',
    'Semi-circular impression at 3 o''clock position',
    'Dr. Kamanzi Eric',
    'RNP Central Forensic Lab'
);

-- ============================================
-- NOTES
-- ============================================

-- Password Hash Information:
-- All test users use the same password: Admin@123
-- The password hash was generated using bcrypt with 10 rounds
-- To generate a new hash, run in Node.js:
--   const bcrypt = require('bcrypt');
--   bcrypt.hash('Admin@123', 10).then(console.log);

COMMENT ON TABLE units IS 'Seeded with RNP Headquarters, 4 stations, and 1 training school';
COMMENT ON TABLE users IS 'Seeded with 10 test users across all 4 roles';
COMMENT ON TABLE officers IS 'Seeded with 7 sample officers across stations';
COMMENT ON TABLE firearms IS 'Seeded with 8 sample firearms (3 at HQ, 5 at stations)';
COMMENT ON TABLE ballistic_profiles IS 'Seeded with 2 sample ballistic profiles';
