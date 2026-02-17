const { Pool } = require('pg');
require('dotenv').config();

// PostgreSQL connection pool configuration
// Use connection string if provided, otherwise use individual params
const connectionConfig = process.env.DATABASE_URL 
  ? {
      connectionString: process.env.DATABASE_URL,
      ssl: { rejectUnauthorized: false },
    }
  : {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT) || 5432,
      database: process.env.DB_NAME || 'safearms',
      user: process.env.DB_USER || 'safearms_user',
      password: process.env.DB_PASSWORD,
      ssl: process.env.DB_HOST?.includes('supabase') ? { rejectUnauthorized: false } : false,
    };

const pool = new Pool({
  ...connectionConfig,
  max: 20,
  min: 2,                      // Keep at least 2 connections warm
  idleTimeoutMillis: 120000,   // Keep idle connections for 2 minutes (was 30s)
  connectionTimeoutMillis: 10000,
});

// Log only the first connection event
let connectionLogged = false;
pool.on('connect', () => {
  if (!connectionLogged) {
    console.log('[OK] PostgreSQL database connected successfully');
    connectionLogged = true;
  }
});

pool.on('error', (err) => {
  console.error('[ERROR] Unexpected database error:', err);
  // Don't exit - let the app try to recover with remaining pool connections
});

// Helper function for parameterized queries
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    // Only log slow queries (>500ms) to reduce console noise
    if (duration > 500) {
      console.log('[WARN] Slow query', { text: text.substring(0, 80), duration, rows: res.rowCount });
    }
    return res;
  } catch (error) {
    console.error('Database query error:', error);
    throw error;
  }
};

// Helper function for transactions
const withTransaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

module.exports = {
  pool,
  query,
  withTransaction
};
