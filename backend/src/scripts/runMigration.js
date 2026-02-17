// Run Migration Script - Execute a migration file on the database
// Run with: node src/scripts/runMigration.js [migration_file]
// Example:  node src/scripts/runMigration.js 002_sync_schema_with_backend.sql

require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runMigration() {
  const migrationFile = process.argv[2] || '002_sync_schema_with_backend.sql';
  const migrationPath = path.join(__dirname, '../../../database/migrations', migrationFile);

  if (!fs.existsSync(migrationPath)) {
    console.error(`[ERROR] Migration file not found: ${migrationPath}`);
    process.exit(1);
  }

  const client = await pool.connect();

  try {
    console.log(`[INFO] Running migration: ${migrationFile}\n`);

    const sql = fs.readFileSync(migrationPath, 'utf8');
    console.log('[INFO] Migration loaded from:', migrationPath);
    console.log('[INFO] Size:', Math.round(sql.length / 1024), 'KB\n');

    console.log('[WAIT] Executing migration...');
    await client.query(sql);

    console.log('\n[OK] Migration executed successfully!');
  } catch (error) {
    console.error('\n[ERROR] Migration Error:', error.message);
    if (error.position) {
      const pos = parseInt(error.position);
      const sql = fs.readFileSync(migrationPath, 'utf8');
      const lines = sql.substring(0, pos).split('\n');
      console.error(`   At line ${lines.length}: ${lines[lines.length - 1].trim()}`);
    }
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigration().catch(console.error);
