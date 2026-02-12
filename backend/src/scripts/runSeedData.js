// SafeArms Database Seeder
// Run this script to populate the database with test data

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config();

const DATABASE_URL = process.env.DATABASE_URL;

if (!DATABASE_URL) {
  console.error('❌ DATABASE_URL not found in environment variables');
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: { rejectUnauthorized: false },
});

async function runSeedData() {
  console.log('🌱 Starting database seeding...\n');

  try {
    // Read the seed data SQL file
    const sqlFilePath = path.join(__dirname, '..', '..', '..', 'database', 'seed_data_new.sql');
    const sql = fs.readFileSync(sqlFilePath, 'utf8');

    console.log('📂 Read seed data file:', sqlFilePath);
    console.log('📝 SQL file size:', sql.length, 'characters\n');

    // Execute the SQL
    console.log('🔄 Executing SQL statements...\n');
    await pool.query(sql);

    console.log('✅ Seed data loaded successfully!\n');

    // Verify the data was loaded
    console.log('📊 Verifying data counts:\n');
    
    const tables = [
      'units',
      'users', 
      'officers',
      'firearms',
      'ballistic_profiles',
      'custody_records',
      'loss_reports',
      'destruction_requests',
      'procurement_requests',
      'anomalies'
    ];

    for (const table of tables) {
      const result = await pool.query(`SELECT COUNT(*) FROM ${table}`);
      console.log(`   ${table}: ${result.rows[0].count} records`);
    }

    console.log('\n✅ Database seeding complete!');
    console.log('\n📋 Login Credentials:');
    console.log('   Admin:           admin / Admin@123');
    console.log('   HQ Commander:    hq_commander / Admin@123');
    console.log('   Nyamirambo:      station_nyamirambo / Admin@123');
    console.log('   Kimironko:       station_kimironko / Admin@123');
    console.log('   Remera:          station_remera / Admin@123');
    console.log('   Kicukiro:        station_kicukiro / Admin@123');
    console.log('   Investigator:    investigator / Admin@123');

  } catch (error) {
    console.error('❌ Error seeding database:', error.message);
    if (error.detail) {
      console.error('   Detail:', error.detail);
    }
    if (error.hint) {
      console.error('   Hint:', error.hint);
    }
    process.exit(1);
  } finally {
    await pool.end();
  }
}

runSeedData();
