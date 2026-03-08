const { Pool } = require('pg');

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
  max: 15,                         // 15 connections is plenty for a single Node process
  min: 2,                          // Keep 2 connections warm
  idleTimeoutMillis: 30000,        // Release idle connections after 30s
  connectionTimeoutMillis: 10000,  // Wait up to 10s for a connection
  statement_timeout: 30000,        // Kill queries running longer than 30s
  query_timeout: 30000,            // Query timeout 30s
  keepalive: true,                 // Enable TCP keepalive
  keepaliveInitialDelayMillis: 10000, // Start keepalive after 10s idle
  allowExitOnIdle: false,          // Don't let pool close when idle
});

// Log only the first connection event
let connectionLogged = false;
pool.on('connect', (client) => {
  // Set timezone and statement timeout for each connection
  const tz = process.env.DB_TIMEZONE || 'Africa/Kigali';
  client.query('SET timezone TO $1', [tz]).catch(() => {});
  client.query("SET statement_timeout = '30s'").catch(() => {});
  if (!connectionLogged) {
    console.log(`[OK] PostgreSQL database connected successfully (timezone: ${tz})`);
    connectionLogged = true;
  }
});

pool.on('error', (err) => {
  console.error('[ERROR] Unexpected database error:', err);
  // Don't exit - let the app try to recover with remaining pool connections
});

// Shutdown flag to prevent queries after pool.end()
let isShuttingDown = false;
const setShuttingDown = () => { isShuttingDown = true; };

// Helper function for parameterized queries
const query = async (text, params) => {
  if (isShuttingDown) {
    throw new Error('Database pool is shutting down, query rejected');
  }
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
  withTransaction,
  setShuttingDown
};
