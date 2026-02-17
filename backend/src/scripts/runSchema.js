// Run Schema Script - Execute schema.sql on the database
// Run with: node src/scripts/runSchema.js

require('dotenv').config();
const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runSchema() {
  const client = await pool.connect();
  
  try {
    console.log('[INFO] Running SafeArms Database Schema...\n');
    
    // Read the schema file
    const schemaPath = path.join(__dirname, '../../../database/schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    
    console.log('[INFO] Schema file loaded from:', schemaPath);
    console.log('[INFO] Schema size:', Math.round(schema.length / 1024), 'KB\n');
    
    // Execute the schema
    console.log('[WAIT] Executing schema (this may take a moment)...');
    await client.query(schema);
    
    console.log('\n[OK] Schema executed successfully!');
    console.log('\n[NEXT] Run the seed script to populate demo data:');
    console.log('   npm run seed');
    
  } catch (error) {
    console.error('\n[ERROR] Schema Error:', error.message);
    if (error.position) {
      console.error('   Position:', error.position);
    }
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runSchema().catch(console.error);
