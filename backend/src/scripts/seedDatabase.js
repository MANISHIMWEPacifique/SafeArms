// SafeArms Database Seeding Script
// Run with: node src/scripts/seedDatabase.js
// 
// This script creates clean demo data with proper unit assignments.
// IMPORTANT: Firearms are assigned to specific units and should ONLY
// be visible to users of those units (except HQ/Admin/Investigator who see all).

require('dotenv').config();
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('localhost') ? false : { rejectUnauthorized: false }
});

async function seedDatabase() {
  const client = await pool.connect();
  
  try {
    console.log('[INFO] Starting SafeArms Database Seeding...\n');
    console.log('[WARN] This will clear existing data and create fresh demo data.\n');

    const destructiveResetAllowed = process.env.ALLOW_DESTRUCTIVE_SEED_RESET === 'true';
    const retainedState = await client.query(`
      SELECT
        (SELECT COUNT(*)::int FROM anomalies) AS anomaly_count,
        (SELECT COUNT(*)::int FROM ml_training_features) AS feature_count,
        (SELECT COUNT(*)::int FROM ml_model_metadata) AS model_count
    `);
    const retained = retainedState.rows[0] || {};
    const hasRetainedMlState =
      (retained.anomaly_count || 0) > 0 ||
      (retained.feature_count || 0) > 0 ||
      (retained.model_count || 0) > 0;

    if (hasRetainedMlState && !destructiveResetAllowed) {
      throw new Error(
        'Refusing to reset retained anomaly/model state. Set ALLOW_DESTRUCTIVE_SEED_RESET=true only when an intentional full reset is required.'
      );
    }

    // Generate password hash for all test users (Admin@123)
    const passwordHash = await bcrypt.hash('Admin@123', 10);
    console.log('[OK] Password hash generated for: Admin@123');

    // ============================================
    // CLEAR EXISTING DATA
    // ============================================
    console.log('\n[CLEAN] Clearing existing data...');
    await client.query('DELETE FROM anomaly_investigations');
    await client.query('DELETE FROM anomalies');
    await client.query('DELETE FROM ml_training_features');
    await client.query('DELETE FROM ml_model_metadata');
    await client.query('DELETE FROM ballistic_access_logs');
    await client.query('DELETE FROM firearm_unit_movements');
    await client.query('DELETE FROM procurement_requests');
    await client.query('DELETE FROM destruction_requests');
    await client.query('DELETE FROM loss_reports');
    await client.query('DELETE FROM custody_records');
    await client.query('DELETE FROM ballistic_profiles');
    await client.query('DELETE FROM firearms');
    await client.query('DELETE FROM officers');
    await client.query('DELETE FROM audit_logs');
    await client.query('DELETE FROM system_settings');
    await client.query('DELETE FROM users');
    await client.query('DELETE FROM units');
    console.log('[OK] Existing data cleared');

    // ============================================
    // UNITS - User-Friendly IDs
    // ============================================
    console.log('\n[SEED] Seeding Units...');
    
    await client.query(`
      INSERT INTO units (unit_id, unit_name, unit_type, location, province, district, commander_name, is_active)
      VALUES 
        ('UNIT-HQ', 'Rwanda National Police Headquarters', 'headquarters', 'Kacyiru, Kigali', 'Kigali', 'Gasabo', 'Commissioner General', true),
        ('UNIT-NYA', 'Nyamirambo Police Station', 'station', 'Nyamirambo, Kigali', 'Kigali', 'Nyarugenge', 'CSP Mugabo Jean', true),
        ('UNIT-KIM', 'Kimironko Police Station', 'station', 'Kimironko, Kigali', 'Kigali', 'Gasabo', 'CSP Uwimana Marie', true),
        ('UNIT-REM', 'Remera Police Station', 'station', 'Remera, Kigali', 'Kigali', 'Gasabo', 'CSP Habimana Pierre', true),
        ('UNIT-KIC', 'Kicukiro Police Station', 'station', 'Kicukiro, Kigali', 'Kigali', 'Kicukiro', 'CSP Niyonsaba Claire', true),
        ('UNIT-PTS', 'Police Training School Gishari', 'specialized', 'Gishari, Eastern Province', 'Eastern', 'Rwamagana', 'ACP Karangwa Emmanuel', true)
    `);
    console.log('[OK] 6 units seeded (UNIT-HQ, UNIT-NYA, UNIT-KIM, UNIT-REM, UNIT-KIC, UNIT-PTS)');

    // ============================================
    // USERS
    // ============================================
    console.log('\n[SEED] Seeding Users...');

    // Admin
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES ('USR-001', 'admin', $1, 'System Administrator', 'admin@rnp.gov.rw', '+250788000000', 'admin', 'UNIT-HQ', true, true, true, false)
    `, [passwordHash]);
    console.log('  [OK] admin (System Admin) at HQ');

    // HQ Commanders
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ('USR-002', 'hq_commander', $1, 'CSP Nkusi Patrick', 'nkusi.patrick@rnp.gov.rw', '+250788000001', 'hq_firearm_commander', 'UNIT-HQ', true, true, true, false),
        ('USR-003', 'hq_commander2', $1, 'CSP Mukamana Jeanne', 'mukamana.jeanne@rnp.gov.rw', '+250788000002', 'hq_firearm_commander', 'UNIT-HQ', true, true, true, false)
    `, [passwordHash]);
    console.log('  [OK] hq_commander, hq_commander2 (HQ Firearm Commanders) at HQ');

    // Station Commanders - Each at their respective station
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ('USR-004', 'station_nyamirambo', $1, 'IP Mugabo Jean', 'mugabo.jean@rnp.gov.rw', '+250788000003', 'station_commander', 'UNIT-NYA', true, true, true, false),
        ('USR-005', 'station_kimironko', $1, 'IP Uwimana Marie', 'uwimana.marie@rnp.gov.rw', '+250788000004', 'station_commander', 'UNIT-KIM', true, true, true, false),
        ('USR-006', 'station_remera', $1, 'IP Habimana Pierre', 'habimana.pierre@rnp.gov.rw', '+250788000005', 'station_commander', 'UNIT-REM', true, true, true, false),
        ('USR-007', 'station_kicukiro', $1, 'IP Niyonsaba Claire', 'niyonsaba.claire@rnp.gov.rw', '+250788000006', 'station_commander', 'UNIT-KIC', true, true, true, false)
    `, [passwordHash]);
    console.log('  [OK] station_nyamirambo (UNIT-NYA), station_kimironko (UNIT-KIM), station_remera (UNIT-REM), station_kicukiro (UNIT-KIC)');

    // Investigators
    await client.query(`
      INSERT INTO users (user_id, username, password_hash, full_name, email, phone_number, role, unit_id, otp_verified, unit_confirmed, is_active, must_change_password)
      VALUES 
        ('USR-008', 'investigator', $1, 'IP Kamanzi Eric', 'kamanzi.eric@rnp.gov.rw', '+250788000007', 'investigator', 'UNIT-HQ', true, true, true, false),
        ('USR-009', 'investigator2', $1, 'IP Ingabire Alice', 'ingabire.alice@rnp.gov.rw', '+250788000008', 'investigator', 'UNIT-HQ', true, true, true, false)
    `, [passwordHash]);
    console.log('  [OK] investigator, investigator2 (Investigators) at HQ');

    // ============================================
    // OFFICERS - Assigned to specific units
    // ============================================
    console.log('\n[SEED] Seeding Officers...');

    // Nyamirambo Station Officers (UNIT-NYA)
    await client.query(`
      INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
      VALUES 
        ('OFF-001', 'RNP-2024-001', 'P/Cst. Mugisha Jean', 'Police Constable', 'UNIT-NYA', '+250788100001', 'mugisha.jean@rnp.gov.rw', true, true),
        ('OFF-002', 'RNP-2024-002', 'P/Cst. Uwase Marie', 'Police Constable', 'UNIT-NYA', '+250788100002', 'uwase.marie@rnp.gov.rw', true, true),
        ('OFF-003', 'RNP-2024-003', 'Sgt. Ndayisaba Paul', 'Sergeant', 'UNIT-NYA', '+250788100003', 'ndayisaba.paul@rnp.gov.rw', true, true)
    `);
    console.log('  [OK] 3 officers at Nyamirambo Station (UNIT-NYA)');

    // Kimironko Station Officers (UNIT-KIM)
    await client.query(`
      INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
      VALUES 
        ('OFF-004', 'RNP-2024-004', 'P/Cst. Habimana David', 'Police Constable', 'UNIT-KIM', '+250788100004', 'habimana.david@rnp.gov.rw', true, true),
        ('OFF-005', 'RNP-2024-005', 'P/Cst. Mukamana Rose', 'Police Constable', 'UNIT-KIM', '+250788100005', 'mukamana.rose@rnp.gov.rw', true, true),
        ('OFF-006', 'RNP-2024-006', 'Sgt. Uwimana Claude', 'Sergeant', 'UNIT-KIM', '+250788100006', 'uwimana.claude@rnp.gov.rw', true, true)
    `);
    console.log('  [OK] 3 officers at Kimironko Station (UNIT-KIM)');

    // Remera Station Officers (UNIT-REM)
    await client.query(`
      INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
      VALUES 
        ('OFF-007', 'RNP-2024-007', 'Sgt. Nshimiyimana Felix', 'Sergeant', 'UNIT-REM', '+250788100007', 'nshimiyimana.felix@rnp.gov.rw', true, true),
        ('OFF-008', 'RNP-2024-008', 'P/Cst. Uwera Diane', 'Police Constable', 'UNIT-REM', '+250788100008', 'uwera.diane@rnp.gov.rw', true, true)
    `);
    console.log('  [OK] 2 officers at Remera Station (UNIT-REM)');

    // Kicukiro Station Officers (UNIT-KIC)
    await client.query(`
      INSERT INTO officers (officer_id, officer_number, full_name, rank, unit_id, phone_number, email, firearm_certified, is_active)
      VALUES 
        ('OFF-009', 'RNP-2024-009', 'Sgt. Karangwa Patrick', 'Sergeant', 'UNIT-KIC', '+250788100009', 'karangwa.patrick@rnp.gov.rw', true, true),
        ('OFF-010', 'RNP-2024-010', 'P/Cst. Ingabire Grace', 'Police Constable', 'UNIT-KIC', '+250788100010', 'ingabire.grace@rnp.gov.rw', true, true)
    `);
    console.log('  [OK] 2 officers at Kicukiro Station (UNIT-KIC)');

    // ============================================
    // FIREARMS - Each assigned to a SPECIFIC unit
    // ============================================
    console.log('\n[SEED] Seeding Firearms...');

    
    const units = ['UNIT-NYA', 'UNIT-KIM', 'UNIT-REM', 'UNIT-KIC', 'UNIT-PTS', 'UNIT-HQ'];
    
    // Generate 5 firearms per unit (1 Glock, 4 AK-47s)
    let faCount = 1;
    for (const unit of units) {
      const inserts = [];
      for (let i = 1; i <= 5; i++) {
        const faId = `FA-${faCount.toString().padStart(3, '0')}`;
        const isAK = i > 1; // 1st is Glock, rest are AK-47
        const model = isAK ? 'AK-47' : 'Glock 17 Gen5';
        const manufacturer = isAK ? 'Kalashnikov' : 'Glock';
        const type = isAK ? 'rifle' : 'pistol';
        const caliber = isAK ? '7.62x39mm' : '9mm';
        const sn = isAK ? `AK-${unit.replace('UNIT-', '')}-${i.toString().padStart(4, '0')}` : `GLK-${unit.replace('UNIT-', '')}-${i.toString().padStart(4, '0')}`;
        
        inserts.push(`('${faId}', '${sn}', '${manufacturer}', '${model}', '${type}', '${caliber}', 2020, '2020-01-15', 'Government Procurement', 'hq', 'USR-002', '${unit}', 'available', true)`);
        
        faCount++;
      }
      
      await client.query(`
        INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
        VALUES ${inserts.join(', ')}
      `);
      console.log(`  [OK] 5 firearms assigned to ${unit}`);
    }


    // Dynamic additional firearms if requested by arguments e.g., node seedDatabase.js 50
    const desiredTotal = parseInt(process.argv[2], 10);
    if (!isNaN(desiredTotal) && desiredTotal > 30) {
      const extraCount = desiredTotal - 30;
      console.log(`\n[SEED] Generating ${extraCount} additional firearms as requested...`);
      const extraValues = [];
      for (let i = 1; i <= extraCount; i++) {
        const faIdNumber = 30 + i;
        const faId = `FA-${faIdNumber.toString().padStart(3, '0')}`;
        const sn = `GEN-EXT-${faIdNumber.toString().padStart(4, '0')}`;
        extraValues.push(`('${faId}', '${sn}', 'Kalashnikov', 'AK-47', 'rifle', '7.62x39mm', 2024, '2024-01-01', 'Government Procurement', 'hq', 'USR-002', 'UNIT-HQ', 'available', true)`);
      }
      
      for (let i = 0; i < extraValues.length; i += 100) {
        const batch = extraValues.slice(i, i + 100);
        await client.query(`
          INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
          VALUES ${batch.join(', ')}
        `);
      }
      console.log(`  [OK] ${extraCount} additional firearms generated at HQ (UNIT-HQ)`);
      faCount += extraCount;
    }

    // ============================================

    // BALLISTIC PROFILES
    // ============================================
    console.log('\n[SEED] Seeding Ballistic Profiles...');

    
    let bpInserts = [];
    // faCount now holds total firearms created + 1
    for (let i = 1; i < faCount; i++) {
      const faId = `FA-${i.toString().padStart(3, '0')}`;
      const bpId = `BP-${i.toString().padStart(3, '0')}`;
      const isRifle = i % 5 !== 1; // Simplistic but matches our manual generation where 1st of 5 is Glock
      const rifling = isRifle ? '4 grooves, right-hand twist, 1:9.45 pitch' : '6 grooves, right-hand twist, 1:10 pitch';
      
      bpInserts.push(`('${bpId}', '${faId}', '2023-01-10', 'RNP Forensic Laboratory', '${rifling}', 'Circular, centered, 0.8mm diameter', 'Semi-circular', 'Dr. Kamanzi Eric', 'RNP Central Forensic Lab', 'USR-008')`);
      
      if (bpInserts.length === 50) {
        await client.query(`
          INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab, created_by)
          VALUES ${bpInserts.join(', ')}
        `);
        bpInserts = [];
      }
    }
    
    if (bpInserts.length > 0) {
      await client.query(`
        INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab, created_by)
        VALUES ${bpInserts.join(', ')}
      `);
    }
    console.log(`  [OK] ${faCount - 1} ballistic profiles seeded`);


    // ============================================
    // SAMPLE CUSTODY RECORDS
    // ============================================
    console.log('\n[SEED] Seeding Sample Custody Records...');

    // Nyamirambo custody records
    await client.query(`
      INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_by, assignment_reason)
      VALUES 
        ('CUS-001', 'FA-001', 'OFF-001', 'UNIT-NYA', 'permanent', 'USR-004', 'Regular duty assignment'),
        ('CUS-002', 'FA-002', 'OFF-002', 'UNIT-NYA', 'temporary', 'USR-004', 'Night patrol duty')
    `);
    console.log('  [OK] 2 custody records for Nyamirambo Station');

    // Kimironko custody records
    await client.query(`
      INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_by, assignment_reason)
      VALUES 
        ('CUS-003', 'FA-004', 'OFF-004', 'UNIT-KIM', 'permanent', 'USR-005', 'Regular duty assignment')
    `);
    console.log('  [OK] 1 custody record for Kimironko Station');

    // Update firearms to in_custody status for those assigned
    await client.query(`
      UPDATE firearms SET current_status = 'in_custody' 
      WHERE firearm_id IN ('FA-001', 'FA-002', 'FA-004')
    `);

    // ============================================
    // UNIT MOVEMENTS (Initial Assignments)
    // ============================================
    console.log('\n[SEED] Seeding Unit Movement Records...');

    
    let movInserts = [];
    let currentUnitIdx = 0;
    const allUnits = ['UNIT-NYA', 'UNIT-KIM', 'UNIT-REM', 'UNIT-KIC', 'UNIT-PTS', 'UNIT-HQ'];
    
    for (let i = 1; i < faCount; i++) {
      const faId = `FA-${i.toString().padStart(3, '0')}`;
      const movId = `MOV-${i.toString().padStart(3, '0')}`;
      
      // Determine unit (First 30 are distributed 5 each to the 6 units. The rest are HQ)
      let targetUnit = 'UNIT-HQ';
      if (i <= 30) {
         targetUnit = allUnits[Math.floor((i - 1) / 5)];
      }

      movInserts.push(`('${movId}', '${faId}', NULL, '${targetUnit}', 'initial_assignment', 'USR-002', 'Initial firearm registration and assignment')`);
      
      if (movInserts.length === 100) {
         await client.query(`
           INSERT INTO firearm_unit_movements (movement_id, firearm_id, from_unit_id, to_unit_id, movement_type, authorized_by, reason)
           VALUES ${movInserts.join(', ')}
         `);
         movInserts = [];
      }
    }
    
    if (movInserts.length > 0) {
       await client.query(`
         INSERT INTO firearm_unit_movements (movement_id, firearm_id, from_unit_id, to_unit_id, movement_type, authorized_by, reason)
         VALUES ${movInserts.join(', ')}
       `);
    }

    console.log('[OK] 12 unit movement records seeded');

    // ============================================
    // REFRESH MATERIALIZED VIEWS
    // ============================================
    console.log('\n[REFRESH] Refreshing materialized views...');
    try {
      await client.query('REFRESH MATERIALIZED VIEW officer_behavior_profile');
      await client.query('REFRESH MATERIALIZED VIEW firearm_usage_profile');
      console.log('[OK] Materialized views refreshed');
    } catch (err) {
      console.log('[WARN] Could not refresh materialized views (they may not exist yet)');
    }

    // ============================================
    // SUMMARY
    // ============================================
    console.log('\n' + '='.repeat(60));
    console.log('[DONE] DATABASE SEEDING COMPLETED SUCCESSFULLY!');
    console.log('='.repeat(60));

    console.log('\n[SUMMARY] DATA SUMMARY:');
    console.log('┌────────────────────────┬──────────────────────────────────┐');
    console.log('│ Entity                 │ Count                            │');
    console.log('├────────────────────────┼──────────────────────────────────┤');
    console.log('│ Units                  │ 6 (HQ + 4 stations + 1 special)  │');
    console.log('│ Users                  │ 9 (1 admin + 2 HQ + 4 station +  │');
    console.log('│                        │    2 investigators)              │');
    console.log('│ Officers               │ 10 (distributed across units)    │');
    console.log(`│ Firearms               │ ${faCount - 1} (assigned to specific units)  │`);
    console.log(`│ Ballistic Profiles     │ ${faCount - 1}                                │`);
    console.log('│ Custody Records        │ 3                                │');
    console.log('└────────────────────────┴──────────────────────────────────┘');

    console.log('\n[UNITS] UNIT IDs (User-Friendly):');
    console.log('┌─────────────┬─────────────────────────────────────────────┐');
    console.log('│ Unit ID     │ Unit Name                                   │');
    console.log('├─────────────┼─────────────────────────────────────────────┤');
    console.log('│ UNIT-HQ     │ Rwanda National Police Headquarters         │');
    console.log('│ UNIT-NYA    │ Nyamirambo Police Station                   │');
    console.log('│ UNIT-KIM    │ Kimironko Police Station                    │');
    console.log('│ UNIT-REM    │ Remera Police Station                       │');
    console.log('│ UNIT-KIC    │ Kicukiro Police Station                     │');
    console.log('│ UNIT-PTS    │ Police Training School Gishari              │');
    console.log('└─────────────┴─────────────────────────────────────────────┘');

    console.log('\n[FIREARMS] FIREARMS BY UNIT:');
    console.log('┌─────────────┬──────────────────────────────────────────────┐');
    console.log('│ Unit        │ Firearms                                     │');
    console.log('├─────────────┼──────────────────────────────────────────────┤');
    console.log('│ UNIT-HQ     │ 5 firearms (mostly AK-47)                    │');
    console.log('│ UNIT-NYA    │ 5 firearms (mostly AK-47)                    │');
    console.log('│ UNIT-KIM    │ 5 firearms (mostly AK-47)                    │');
    console.log('│ UNIT-REM    │ 5 firearms (mostly AK-47)                    │');
    console.log('│ UNIT-KIC    │ 5 firearms (mostly AK-47)                    │');
    console.log('│ UNIT-PTS    │ 5 firearms (mostly AK-47)                    │');
    console.log('└─────────────┴──────────────────────────────────────────────┘');

    console.log('\n[CREDENTIALS] TEST USER CREDENTIALS (Password: Admin@123)');
    console.log('┌─────────────────────┬──────────────────────┬─────────────┐');
    console.log('│ Username            │ Role                 │ Unit        │');
    console.log('├─────────────────────┼──────────────────────┼─────────────┤');
    console.log('│ admin               │ System Admin         │ UNIT-HQ     │');
    console.log('│ hq_commander        │ HQ Firearm Commander │ UNIT-HQ     │');
    console.log('│ hq_commander2       │ HQ Firearm Commander │ UNIT-HQ     │');
    console.log('│ station_nyamirambo  │ Station Commander    │ UNIT-NYA    │');
    console.log('│ station_kimironko   │ Station Commander    │ UNIT-KIM    │');
    console.log('│ station_remera      │ Station Commander    │ UNIT-REM    │');
    console.log('│ station_kicukiro    │ Station Commander    │ UNIT-KIC    │');
    console.log('│ investigator        │ Investigator         │ UNIT-HQ     │');
    console.log('│ investigator2       │ Investigator         │ UNIT-HQ     │');
    console.log('└─────────────────────┴──────────────────────┴─────────────┘');

    console.log('\n[IMPORTANT] ACCESS RULES:');
    console.log('   • Station Commanders can ONLY see firearms assigned to their unit');
    console.log('   • HQ Commanders, Admin, and Investigators see ALL firearms');
    console.log('   • Officers can only receive custody of firearms in their unit');
    console.log('\n');

    // Sync sequences after seeding to prevent duplicate key errors during runtime
    console.log('[SEED] Synchronizing database sequences...');
    try {
      await client.query(`
        SELECT setval(
            'audit_logs_id_seq',
            COALESCE(
                (
                    SELECT MAX(
                        CAST(
                            NULLIF(REGEXP_REPLACE(log_id, '[^0-9]', '', 'g'), '')
                            AS INTEGER
                        )
                    )
                    FROM audit_logs
                ),
                0
            ) + 1,
            false
        )
      `);
      console.log('  [OK] audit_logs_id_seq synchronized');
    } catch (seqError) {
      console.warn('  [WARN] Failed to sync sequence:', seqError.message);
    }
    
  } catch (error) {
    console.error('[ERROR] Seeding Error:', error.message);
    console.error(error.stack);
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

seedDatabase().catch(console.error);
