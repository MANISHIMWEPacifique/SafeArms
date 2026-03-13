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
  connectionTimeoutMillis: parseInt(process.env.DB_CONNECTION_TIMEOUT_MS || '20000', 10), // Wait up to 20s for a connection
  statement_timeout: parseInt(process.env.DB_STATEMENT_TIMEOUT_MS || '30000', 10),         // Kill queries running longer than 30s
  query_timeout: parseInt(process.env.DB_QUERY_TIMEOUT_MS || '30000', 10),                 // Query timeout 30s
  keepalive: true,                 // Enable TCP keepalive
  keepaliveInitialDelayMillis: 10000, // Start keepalive after 10s idle
  allowExitOnIdle: false,          // Don't let pool close when idle
});

// Log only the first connection event
let connectionLogged = false;
pool.on('connect', (client) => {
  // Set timezone and statement timeout for each connection
  const tz = process.env.DB_TIMEZONE || 'Africa/Kigali';
  const safeTz = /^[A-Za-z0-9_\/+\-]+$/.test(tz) ? tz : 'UTC';
  const escapedTz = safeTz.replace(/'/g, "''");

  // Use literal form because parameterized SET can fail for utility statements.
  client.query(`SET TIME ZONE '${escapedTz}'`).catch((err) => {
    console.warn(`[WARN] Failed to set DB timezone to ${safeTz}: ${err.message}`);
  });
  client.query("SET statement_timeout = '30s'").catch(() => {});
  if (!connectionLogged) {
    console.log(`[OK] PostgreSQL database connected successfully (timezone: ${safeTz})`);
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
// Supports per-query timeout overrides via the optional third argument.
const query = async (text, params, options = {}) => {
  if (isShuttingDown) {
    throw new Error('Database pool is shutting down, query rejected');
  }
  const start = Date.now();
  try {
    const queryConfig =
      typeof text === 'object' && text !== null
        ? { ...text, ...options }
        : { text, values: params, ...options };

    const res = await pool.query(queryConfig);
    const duration = Date.now() - start;
    // Only log slow queries (>500ms) to reduce console noise
    if (duration > 500) {
      const preview = typeof text === 'string'
        ? text.substring(0, 80)
        : (text?.text || '').substring(0, 80);
      console.log('[WARN] Slow query', { text: preview, duration, rows: res.rowCount });
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
