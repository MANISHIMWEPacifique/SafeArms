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
    console.log('🚀 Running SafeArms Database Schema...\n');
    
    // Read the schema file
    const schemaPath = path.join(__dirname, '../../../database/schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');
    
    console.log('📄 Schema file loaded from:', schemaPath);
    console.log('📊 Schema size:', Math.round(schema.length / 1024), 'KB\n');
    
    // Execute the schema
    console.log('⏳ Executing schema (this may take a moment)...');
    await client.query(schema);
    
    console.log('\n✅ Schema executed successfully!');
    console.log('\n📋 Next step: Run the seed script to populate demo data:');
    console.log('   npm run seed');
    
  } catch (error) {
    console.error('\n❌ Schema Error:', error.message);
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
