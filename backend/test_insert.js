require('dotenv').config();
const { query } = require('./src/config/database');

async function test() {
  await query(`
    INSERT INTO custody_records (custody_id, firearm_id, officer_id, unit_id, custody_type, issued_at, issued_by) 
    VALUES ('CUS-TEST-999', 'FA-008', 'OFF-001', 'UNIT-NYA', 'permanent', NOW(), 'USR-002')
  `);
  const res = await query('SELECT count(*) FROM ml_training_features');
  console.log('Features count: ', res.rows[0].count);
  await query(`DELETE FROM custody_records WHERE custody_id = 'CUS-TEST-999'`);
  process.exit(0);
}
test().catch(err => { console.error(err); process.exit(1); });