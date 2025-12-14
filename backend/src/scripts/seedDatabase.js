// SafeArms Database Seeding Script
// Run with: node src/scripts/seedDatabase.js

require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function seedDatabase() {
  const client = await pool.connect();
  
  try {
    console.log('🚀 Starting database seeding...\n');

    // Generate password hash for all test users (Admin@123)
    const passwordHash = await bcrypt.hash('Admin@123', 10);
    console.log('✅ Password hash generated for: Admin@123');

    // ============================================
    // UNITS
    // ============================================
    console.log('\n📍 Seeding Units...');
    
    await client.query(`
      INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, commander_name, is_active)
      VALUES 
        ('a0000000-0000-0000-0000-000000000001', 'Rwanda National Police Headquarters', 'headquarters', 'Kacyiru, Kigali', 'Kigali', 'Gasabo', 'Commissioner General', true),
        ('a0000000-0000-0000-0000-000000000002', 'Nyamirambo Police Station', 'station', 'Nyamirambo, Kigali', 'Kigali', 'Nyarugenge', 'CSP Mugabo Jean', true),
        ('a0000000-0000-0000-0000-000000000003', 'Kimironko Police Station', 'station', 'Kimironko, Kigali', 'Kigali', 'Gasabo', 'CSP Uwimana Marie', true),
        ('a0000000-0000-0000-0000-000000000004', 'Remera Police Station', 'station', 'Remera, Kigali', 'Kigali', 'Gasabo', 'CSP Habimana Pierre', true),
        ('a0000000-0000-0000-0000-000000000005', 'Kicukiro Police Station', 'station', 'Kicukiro, Kigali', 'Kigali', 'Kicukiro', 'CSP Niyonsaba Claire', true),
        ('a0000000-0000-0000-0000-000000000006', 'Police Training School Gishari', 'specialized', 'Gishari, Eastern Province', 'Eastern', 'Rwamagana', 'ACP Karangwa Emmanuel', true)
      ON CONFLICT (unit_id) DO NOTHING
    `);
    console.log('✅ 6 units seeded');

    // ============================================
    // USERS
    // ============================================
    console.log('\n👤 Seeding Users...');

    // Admin
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      ON CONFLICT (username) DO UPDATE SET password_hash = $3
    `, [
      'b0000000-0000-0000-0000-000000000001',
      'admin',
      passwordHash,
      'System Administrator',
      'admin@rnp.gov.rw',
      '+250788000000',
      'admin',
      'a0000000-0000-0000-0000-000000000001',
      true, true, true, false
    ]);
    console.log('  ✅ admin (System Admin)');

    // HQ Commanders
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ($1, 'hq_commander', $2, 'CSP Nkusi Patrick', 'nkusi.patrick@rnp.gov.rw', '+250788000001', 'hq_firearm_commander', 'a0000000-0000-0000-0000-000000000001', true, true, true, false),
        ($3, 'hq_commander2', $2, 'CSP Mukamana Jeanne', 'mukamana.jeanne@rnp.gov.rw', '+250788000002', 'hq_firearm_commander', 'a0000000-0000-0000-0000-000000000001', true, true, true, false)
      ON CONFLICT (username) DO UPDATE SET password_hash = $2
    `, [
      'b0000000-0000-0000-0000-000000000002',
      passwordHash,
      'b0000000-0000-0000-0000-000000000003'
    ]);
    console.log('  ✅ hq_commander, hq_commander2 (HQ Firearm Commanders)');

    // Station Commanders
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ('b0000000-0000-0000-0000-000000000004', 'station_nyamirambo', $1, 'IP Mugabo Jean', 'mugabo.jean@rnp.gov.rw', '+250788000003', 'station_commander', 'a0000000-0000-0000-0000-000000000002', true, true, true, false),
        ('b0000000-0000-0000-0000-000000000005', 'station_kimironko', $1, 'IP Uwimana Marie', 'uwimana.marie@rnp.gov.rw', '+250788000004', 'station_commander', 'a0000000-0000-0000-0000-000000000003', true, true, true, false),
        ('b0000000-0000-0000-0000-000000000006', 'station_remera', $1, 'IP Habimana Pierre', 'habimana.pierre@rnp.gov.rw', '+250788000005', 'station_commander', 'a0000000-0000-0000-0000-000000000004', true, true, true, false),
        ('b0000000-0000-0000-0000-000000000007', 'station_kicukiro', $1, 'IP Niyonsaba Claire', 'niyonsaba.claire@rnp.gov.rw', '+250788000006', 'station_commander', 'a0000000-0000-0000-0000-000000000005', true, true, true, false)
      ON CONFLICT (username) DO UPDATE SET password_hash = $1
    `, [passwordHash]);
    console.log('  ✅ station_nyamirambo, station_kimironko, station_remera, station_kicukiro (Station Commanders)');

    // Forensic Analysts
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ('b0000000-0000-0000-0000-000000000008', 'forensic_analyst', $1, 'Dr. Kamanzi Eric', 'kamanzi.eric@rnp.gov.rw', '+250788000007', 'forensic_analyst', 'a0000000-0000-0000-0000-000000000001', true, true, true, false),
        ('b0000000-0000-0000-0000-000000000009', 'forensic_analyst2', $1, 'Dr. Ingabire Alice', 'ingabire.alice@rnp.gov.rw', '+250788000008', 'forensic_analyst', 'a0000000-0000-0000-0000-000000000001', true, true, true, false)
      ON CONFLICT (username) DO UPDATE SET password_hash = $1
    `, [passwordHash]);
    console.log('  ✅ forensic_analyst, forensic_analyst2 (Forensic Analysts)');

    // ============================================
    // OFFICERS
    // ============================================
    console.log('\n👮 Seeding Officers...');

    await client.query(`
      INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
      VALUES 
        ('c0000000-0000-0000-0000-000000000001', 'RNP-2024-001', 'P/Cst. Mugisha Jean', 'Police Constable', 'a0000000-0000-0000-0000-000000000002', '+250788100001', 'mugisha.jean@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000002', 'RNP-2024-002', 'P/Cst. Uwase Marie', 'Police Constable', 'a0000000-0000-0000-0000-000000000002', '+250788100002', 'uwase.marie@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000003', 'RNP-2024-003', 'Sgt. Ndayisaba Paul', 'Sergeant', 'a0000000-0000-0000-0000-000000000002', '+250788100003', 'ndayisaba.paul@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000004', 'RNP-2024-004', 'P/Cst. Habimana David', 'Police Constable', 'a0000000-0000-0000-0000-000000000003', '+250788100004', 'habimana.david@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000005', 'RNP-2024-005', 'P/Cst. Mukamana Rose', 'Police Constable', 'a0000000-0000-0000-0000-000000000003', '+250788100005', 'mukamana.rose@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000006', 'RNP-2024-006', 'Sgt. Nshimiyimana Felix', 'Sergeant', 'a0000000-0000-0000-0000-000000000004', '+250788100006', 'nshimiyimana.felix@rnp.gov.rw', true, true),
        ('c0000000-0000-0000-0000-000000000007', 'RNP-2024-007', 'P/Cst. Uwera Diane', 'Police Constable', 'a0000000-0000-0000-0000-000000000004', '+250788100007', 'uwera.diane@rnp.gov.rw', true, true)
      ON CONFLICT (officer_id) DO NOTHING
    `);
    console.log('✅ 7 officers seeded');

    // ============================================
    // FIREARMS
    // ============================================
    console.log('\n🔫 Seeding Firearms...');

    // HQ registered (unassigned)
    await client.query(`
      INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, current_status, is_active)
      VALUES 
        ('d0000000-0000-0000-0000-000000000001', 'GLK-2024-0001', 'Glock', 'Glock 17 Gen5', 'pistol', '9mm', 2024, '2024-01-15', 'Government Procurement', 'hq', 'b0000000-0000-0000-0000-000000000002', 'unassigned', true),
        ('d0000000-0000-0000-0000-000000000002', 'GLK-2024-0002', 'Glock', 'Glock 19 Gen5', 'pistol', '9mm', 2024, '2024-01-15', 'Government Procurement', 'hq', 'b0000000-0000-0000-0000-000000000002', 'unassigned', true),
        ('d0000000-0000-0000-0000-000000000003', 'SIG-2024-0001', 'SIG Sauer', 'P320', 'pistol', '9mm', 2024, '2024-02-01', 'Government Procurement', 'hq', 'b0000000-0000-0000-0000-000000000002', 'unassigned', true)
      ON CONFLICT (firearm_id) DO NOTHING
    `);

    // Station firearms
    await client.query(`
      INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
      VALUES 
        ('d0000000-0000-0000-0000-000000000004', 'GLK-2023-0101', 'Glock', 'Glock 17', 'pistol', '9mm', 2023, '2023-06-15', 'Government Procurement', 'unit', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002', 'available', true),
        ('d0000000-0000-0000-0000-000000000005', 'GLK-2023-0102', 'Glock', 'Glock 17', 'pistol', '9mm', 2023, '2023-06-15', 'Government Procurement', 'unit', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002', 'available', true),
        ('d0000000-0000-0000-0000-000000000006', 'RFL-2022-0001', 'FN Herstal', 'FN SCAR-L', 'rifle', '5.56mm NATO', 2022, '2022-03-20', 'Government Procurement', 'unit', 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000002', 'available', true),
        ('d0000000-0000-0000-0000-000000000007', 'GLK-2023-0201', 'Glock', 'Glock 19', 'pistol', '9mm', 2023, '2023-07-10', 'Government Procurement', 'unit', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000003', 'available', true),
        ('d0000000-0000-0000-0000-000000000008', 'GLK-2023-0202', 'Glock', 'Glock 19', 'pistol', '9mm', 2023, '2023-07-10', 'Government Procurement', 'unit', 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000003', 'available', true)
      ON CONFLICT (firearm_id) DO NOTHING
    `);
    console.log('✅ 8 firearms seeded');

    // ============================================
    // BALLISTIC PROFILES
    // ============================================
    console.log('\n🔬 Seeding Ballistic Profiles...');

    await client.query(`
      INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab)
      VALUES 
        ('e0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000004', '2023-06-20', 'RNP Forensic Laboratory', '6 grooves, right-hand twist, 1:10 pitch', 'Circular, centered, 0.8mm diameter', 'Semi-circular impression at 3 oclock position', 'Dr. Kamanzi Eric', 'RNP Central Forensic Lab'),
        ('e0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000005', '2023-06-20', 'RNP Forensic Laboratory', '6 grooves, right-hand twist, 1:10 pitch', 'Circular, centered, 0.8mm diameter', 'Semi-circular impression at 3 oclock position', 'Dr. Kamanzi Eric', 'RNP Central Forensic Lab')
      ON CONFLICT (ballistic_id) DO NOTHING
    `);
    console.log('✅ 2 ballistic profiles seeded');

    console.log('\n' + '='.repeat(50));
    console.log('🎉 DATABASE SEEDING COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(50));
    console.log('\n📋 TEST USER CREDENTIALS (Password: Admin@123)\n');
    console.log('┌─────────────────────┬──────────────────────┬─────────────────────────┐');
    console.log('│ Username            │ Role                 │ Unit                    │');
    console.log('├─────────────────────┼──────────────────────┼─────────────────────────┤');
    console.log('│ admin               │ System Admin         │ RNP HQ                  │');
    console.log('│ hq_commander        │ HQ Firearm Commander │ RNP HQ                  │');
    console.log('│ hq_commander2       │ HQ Firearm Commander │ RNP HQ                  │');
    console.log('│ station_nyamirambo  │ Station Commander    │ Nyamirambo Station      │');
    console.log('│ station_kimironko   │ Station Commander    │ Kimironko Station       │');
    console.log('│ station_remera      │ Station Commander    │ Remera Station          │');
    console.log('│ station_kicukiro    │ Station Commander    │ Kicukiro Station        │');
    console.log('│ forensic_analyst    │ Forensic Analyst     │ RNP HQ                  │');
    console.log('│ forensic_analyst2   │ Forensic Analyst     │ RNP HQ                  │');
    console.log('└─────────────────────┴──────────────────────┴─────────────────────────┘');
    console.log('\n');

  } catch (error) {
    console.error('❌ Seeding Error:', error.message);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

seedDatabase().catch(console.error);
