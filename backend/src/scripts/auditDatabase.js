// SafeArms Database Audit Script
// Checks all tables, FK integrity, views, functions, triggers, and sequences

const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function audit() {
  console.log('============================================');
  console.log('  SafeArms Database Integrity Audit');
  console.log('============================================\n');

  // 1. TABLE COUNTS
  const tables = [
    'units', 'users', 'officers', 'firearms', 'ballistic_profiles',
    'custody_records', 'firearm_unit_movements', 'ballistic_access_logs',
    'loss_reports', 'destruction_requests', 'procurement_requests',
    'anomalies', 'anomaly_investigations', 'audit_logs',
    'ml_training_features', 'ml_model_metadata'
  ];

  console.log('=== TABLE COUNTS ===');
  for (const t of tables) {
    try {
      const r = await pool.query(`SELECT COUNT(*) FROM ${t}`);
      console.log(`  ${t}: ${r.rows[0].count}`);
    } catch (e) {
      console.log(`  ${t}: ERROR - ${e.message}`);
    }
  }

  // 2. FK INTEGRITY
  console.log('\n=== FOREIGN KEY INTEGRITY ===');
  const fkChecks = [
    { name: 'Users -> Units', q: `SELECT u.user_id, u.unit_id FROM users u LEFT JOIN units un ON u.unit_id = un.unit_id WHERE un.unit_id IS NULL AND u.unit_id IS NOT NULL` },
    { name: 'Officers -> Units', q: `SELECT o.officer_id, o.unit_id FROM officers o LEFT JOIN units un ON o.unit_id = un.unit_id WHERE un.unit_id IS NULL` },
    { name: 'Firearms -> Units', q: `SELECT f.firearm_id, f.assigned_unit_id FROM firearms f LEFT JOIN units un ON f.assigned_unit_id = un.unit_id WHERE un.unit_id IS NULL AND f.assigned_unit_id IS NOT NULL` },
    { name: 'Firearms -> Users (registered_by)', q: `SELECT f.firearm_id, f.registered_by FROM firearms f LEFT JOIN users u ON f.registered_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Custody -> Firearms', q: `SELECT cr.custody_id, cr.firearm_id FROM custody_records cr LEFT JOIN firearms f ON cr.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Custody -> Officers', q: `SELECT cr.custody_id, cr.officer_id FROM custody_records cr LEFT JOIN officers o ON cr.officer_id = o.officer_id WHERE o.officer_id IS NULL` },
    { name: 'Custody -> Units', q: `SELECT cr.custody_id, cr.unit_id FROM custody_records cr LEFT JOIN units u ON cr.unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Custody -> Users (issued_by)', q: `SELECT cr.custody_id, cr.issued_by FROM custody_records cr LEFT JOIN users u ON cr.issued_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Custody -> Users (returned_to)', q: `SELECT cr.custody_id, cr.returned_to FROM custody_records cr LEFT JOIN users u ON cr.returned_to = u.user_id WHERE u.user_id IS NULL AND cr.returned_to IS NOT NULL` },
    { name: 'Anomalies -> Custody', q: `SELECT a.anomaly_id, a.custody_record_id FROM anomalies a LEFT JOIN custody_records cr ON a.custody_record_id = cr.custody_id WHERE cr.custody_id IS NULL` },
    { name: 'Anomalies -> Firearms', q: `SELECT a.anomaly_id, a.firearm_id FROM anomalies a LEFT JOIN firearms f ON a.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Anomalies -> Officers', q: `SELECT a.anomaly_id, a.officer_id FROM anomalies a LEFT JOIN officers o ON a.officer_id = o.officer_id WHERE o.officer_id IS NULL` },
    { name: 'Anomalies -> Units', q: `SELECT a.anomaly_id, a.unit_id FROM anomalies a LEFT JOIN units u ON a.unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Investigations -> Anomalies', q: `SELECT ai.investigation_id, ai.anomaly_id FROM anomaly_investigations ai LEFT JOIN anomalies a ON ai.anomaly_id = a.anomaly_id WHERE a.anomaly_id IS NULL` },
    { name: 'Investigations -> Users', q: `SELECT ai.investigation_id, ai.investigator_id FROM anomaly_investigations ai LEFT JOIN users u ON ai.investigator_id = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Loss Reports -> Firearms', q: `SELECT lr.loss_id, lr.firearm_id FROM loss_reports lr LEFT JOIN firearms f ON lr.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Loss Reports -> Units', q: `SELECT lr.loss_id, lr.unit_id FROM loss_reports lr LEFT JOIN units u ON lr.unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Loss Reports -> Users', q: `SELECT lr.loss_id, lr.reported_by FROM loss_reports lr LEFT JOIN users u ON lr.reported_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Destruction -> Firearms', q: `SELECT d.destruction_id, d.firearm_id FROM destruction_requests d LEFT JOIN firearms f ON d.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Destruction -> Units', q: `SELECT d.destruction_id, d.unit_id FROM destruction_requests d LEFT JOIN units u ON d.unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Procurement -> Units', q: `SELECT p.procurement_id, p.unit_id FROM procurement_requests p LEFT JOIN units u ON p.unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Procurement -> Users', q: `SELECT p.procurement_id, p.requested_by FROM procurement_requests p LEFT JOIN users u ON p.requested_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Ballistic Profiles -> Firearms', q: `SELECT bp.ballistic_id, bp.firearm_id FROM ballistic_profiles bp LEFT JOIN firearms f ON bp.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Ballistic Access -> Profiles', q: `SELECT bal.access_id, bal.ballistic_id FROM ballistic_access_logs bal LEFT JOIN ballistic_profiles bp ON bal.ballistic_id = bp.ballistic_id WHERE bp.ballistic_id IS NULL` },
    { name: 'Ballistic Access -> Users', q: `SELECT bal.access_id, bal.accessed_by FROM ballistic_access_logs bal LEFT JOIN users u ON bal.accessed_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'Movements -> Firearms', q: `SELECT m.movement_id, m.firearm_id FROM firearm_unit_movements m LEFT JOIN firearms f ON m.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
    { name: 'Movements -> Units (to)', q: `SELECT m.movement_id, m.to_unit_id FROM firearm_unit_movements m LEFT JOIN units u ON m.to_unit_id = u.unit_id WHERE u.unit_id IS NULL` },
    { name: 'Movements -> Users (auth)', q: `SELECT m.movement_id, m.authorized_by FROM firearm_unit_movements m LEFT JOIN users u ON m.authorized_by = u.user_id WHERE u.user_id IS NULL` },
    { name: 'ML Features -> Custody', q: `SELECT mf.feature_id, mf.custody_record_id FROM ml_training_features mf LEFT JOIN custody_records cr ON mf.custody_record_id = cr.custody_id WHERE cr.custody_id IS NULL` },
    { name: 'ML Features -> Officers', q: `SELECT mf.feature_id, mf.officer_id FROM ml_training_features mf LEFT JOIN officers o ON mf.officer_id = o.officer_id WHERE o.officer_id IS NULL` },
    { name: 'ML Features -> Firearms', q: `SELECT mf.feature_id, mf.firearm_id FROM ml_training_features mf LEFT JOIN firearms f ON mf.firearm_id = f.firearm_id WHERE f.firearm_id IS NULL` },
  ];

  let fkIssues = 0;
  for (const check of fkChecks) {
    try {
      const r = await pool.query(check.q);
      if (r.rows.length > 0) {
        console.log(`  FAIL: ${check.name} — ${r.rows.length} orphan(s): ${JSON.stringify(r.rows)}`);
        fkIssues += r.rows.length;
      } else {
        console.log(`  OK: ${check.name}`);
      }
    } catch (e) {
      console.log(`  ERROR: ${check.name} — ${e.message}`);
    }
  }
  console.log(`\n  Total FK issues: ${fkIssues}`);

  // 3. DATA DISTRIBUTIONS
  console.log('\n=== FIREARM STATUS DISTRIBUTION ===');
  const st = await pool.query('SELECT current_status, COUNT(*) as cnt FROM firearms GROUP BY current_status ORDER BY cnt DESC');
  st.rows.forEach(r => console.log(`  ${r.current_status}: ${r.cnt}`));

  console.log('\n=== CUSTODY TYPE DISTRIBUTION ===');
  const ct = await pool.query('SELECT custody_type, COUNT(*) as cnt FROM custody_records GROUP BY custody_type');
  ct.rows.forEach(r => console.log(`  ${r.custody_type}: ${r.cnt}`));

  console.log('\n=== ANOMALY STATUS DISTRIBUTION ===');
  const as2 = await pool.query('SELECT status, COUNT(*) as cnt FROM anomalies GROUP BY status');
  as2.rows.forEach(r => console.log(`  ${r.status}: ${r.cnt}`));

  console.log('\n=== USER ROLES DISTRIBUTION ===');
  const rl = await pool.query('SELECT role, COUNT(*) as cnt FROM users GROUP BY role');
  rl.rows.forEach(r => console.log(`  ${r.role}: ${r.cnt}`));

  console.log('\n=== LOSS REPORT STATUS ===');
  const ls = await pool.query('SELECT status, COUNT(*) as cnt FROM loss_reports GROUP BY status');
  ls.rows.forEach(r => console.log(`  ${r.status}: ${r.cnt}`));

  console.log('\n=== DESTRUCTION STATUS ===');
  const ds = await pool.query('SELECT status, COUNT(*) as cnt FROM destruction_requests GROUP BY status');
  ds.rows.forEach(r => console.log(`  ${r.status}: ${r.cnt}`));

  console.log('\n=== PROCUREMENT STATUS ===');
  const ps = await pool.query('SELECT status, COUNT(*) as cnt FROM procurement_requests GROUP BY status');
  ps.rows.forEach(r => console.log(`  ${r.status}: ${r.cnt}`));

  // 4. ML MODEL STATUS
  console.log('\n=== ML MODEL METADATA ===');
  const ml = await pool.query('SELECT model_id, model_version, is_active, training_samples_count FROM ml_model_metadata');
  if (ml.rows.length === 0) {
    console.log('  WARNING: No ML models found!');
  } else {
    ml.rows.forEach(r => console.log(`  ${r.model_id} v${r.model_version} active=${r.is_active} samples=${r.training_samples_count}`));
  }

  // 5. MATERIALIZED VIEWS
  console.log('\n=== MATERIALIZED VIEWS ===');
  for (const mv of ['officer_behavior_profile', 'firearm_usage_profile']) {
    try {
      const r = await pool.query(`SELECT COUNT(*) FROM ${mv}`);
      console.log(`  ${mv}: ${r.rows[0].count} rows`);
    } catch (e) {
      console.log(`  ${mv}: ERROR - ${e.message}`);
    }
  }

  // 6. VIEWS
  console.log('\n=== VIEWS ===');
  for (const v of ['custody_chain_timeline', 'firearm_traceability_timeline', 'unified_firearm_events_timeline']) {
    try {
      const r = await pool.query(`SELECT COUNT(*) FROM ${v}`);
      console.log(`  ${v}: ${r.rows[0].count} rows`);
    } catch (e) {
      console.log(`  ${v}: ERROR - ${e.message}`);
    }
  }

  // 7. SEQUENCES
  console.log('\n=== SEQUENCES ===');
  const seqs = ['firearms_id_seq', 'loss_reports_id_seq', 'destruction_requests_id_seq', 'procurement_requests_id_seq', 'audit_logs_id_seq', 'ballistic_access_id_seq'];
  for (const s of seqs) {
    try {
      const r = await pool.query(`SELECT last_value FROM ${s}`);
      console.log(`  ${s}: ${r.rows[0].last_value}`);
    } catch (e) {
      console.log(`  ${s}: ERROR - ${e.message}`);
    }
  }

  // 8. FUNCTIONS
  console.log('\n=== FUNCTIONS ===');
  const fns = await pool.query(`SELECT routine_name FROM information_schema.routines WHERE routine_schema = 'public' AND routine_type = 'FUNCTION' ORDER BY routine_name`);
  fns.rows.forEach(r => console.log(`  ${r.routine_name}`));

  // 9. TRIGGERS
  console.log('\n=== TRIGGERS ===');
  const trg = await pool.query(`SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'public' ORDER BY event_object_table, trigger_name`);
  trg.rows.forEach(r => console.log(`  ${r.trigger_name} ON ${r.event_object_table}`));

  // 10. CROSS-CHECKS
  console.log('\n=== CROSS-CHECKS ===');
  
  // Check every officer has at least one custody record
  const noActivity = await pool.query(`SELECT o.officer_id, o.full_name FROM officers o LEFT JOIN custody_records cr ON o.officer_id = cr.officer_id WHERE cr.custody_id IS NULL`);
  if (noActivity.rows.length > 0) {
    console.log(`  Officers without any custody records: ${noActivity.rows.map(r => r.officer_id + ' (' + r.full_name + ')').join(', ')}`);
  } else {
    console.log('  OK: All officers have custody records');
  }

  // Check every unit has at least one officer
  const noOfficers = await pool.query(`SELECT u.unit_id, u.unit_name FROM units u LEFT JOIN officers o ON u.unit_id = o.unit_id WHERE o.officer_id IS NULL`);
  if (noOfficers.rows.length > 0) {
    console.log(`  Units without officers: ${noOfficers.rows.map(r => r.unit_id + ' (' + r.unit_name + ')').join(', ')}`);
  } else {
    console.log('  OK: All units have officers');
  }

  // Check every unit has a user (commander)
  const noUsers = await pool.query(`SELECT u.unit_id, u.unit_name FROM units u LEFT JOIN users us ON u.unit_id = us.unit_id WHERE us.user_id IS NULL`);
  if (noUsers.rows.length > 0) {
    console.log(`  Units without system users: ${noUsers.rows.map(r => r.unit_id + ' (' + r.unit_name + ')').join(', ')}`);
  } else {
    console.log('  OK: All units have system users');
  }

  // Check lost/stolen firearms have correct status
  const lostCheck = await pool.query(`SELECT lr.loss_id, lr.firearm_id, lr.loss_type, f.current_status FROM loss_reports lr JOIN firearms f ON lr.firearm_id = f.firearm_id WHERE lr.status != 'rejected'`);
  console.log('\n  Loss report vs firearm status:');
  lostCheck.rows.forEach(r => {
    const expected = r.loss_type;
    const match = r.current_status === expected ? 'OK' : 'MISMATCH';
    console.log(`    ${r.loss_id}: ${r.firearm_id} type=${r.loss_type} status=${r.current_status} [${match}]`);
  });

  // Check permanent custody firearms are in_custody
  const permCheck = await pool.query(`SELECT cr.custody_id, cr.firearm_id, f.current_status FROM custody_records cr JOIN firearms f ON cr.firearm_id = f.firearm_id WHERE cr.custody_type = 'permanent' AND cr.returned_at IS NULL`);
  console.log('\n  Permanent custody vs firearm status:');
  permCheck.rows.forEach(r => {
    const match = r.current_status === 'in_custody' ? 'OK' : 'MISMATCH';
    console.log(`    ${r.custody_id}: ${r.firearm_id} status=${r.current_status} [${match}]`);
  });

  console.log('\n============================================');
  console.log('  Audit Complete');
  console.log('============================================');

  await pool.end();
}

audit().catch(e => {
  console.error('FATAL:', e.message);
  process.exit(1);
});
