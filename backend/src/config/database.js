const { Pool } = require('pg');
const { isTransientDatabaseError } = require('../utils/dbErrors');

const parsePositiveInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
};

const DB_CONNECTION_TIMEOUT_MS = parsePositiveInt(process.env.DB_CONNECTION_TIMEOUT_MS, 15000);
const DB_STATEMENT_TIMEOUT_MS = parsePositiveInt(process.env.DB_STATEMENT_TIMEOUT_MS, 60000);
const DB_QUERY_TIMEOUT_MS = parsePositiveInt(process.env.DB_QUERY_TIMEOUT_MS, 60000);
const DB_SLOW_QUERY_LOG_MS = parsePositiveInt(process.env.DB_SLOW_QUERY_LOG_MS, 1000);
const DB_TRANSIENT_MAX_RETRIES = parsePositiveInt(process.env.DB_TRANSIENT_MAX_RETRIES, 2);
const DB_TRANSIENT_RETRY_DELAY_MS = parsePositiveInt(process.env.DB_TRANSIENT_RETRY_DELAY_MS, 250);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const normalizeRetryCount = (value, fallback) => {
  if (value === undefined || value === null) {
    return fallback;
  }
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
};

const isReadOnlyQuery = (queryText = '') => {
  const normalized = String(queryText).trim().toLowerCase();
  if (!/^(select|with)\b/.test(normalized)) {
    return false;
  }
  if (/\b(insert|update|delete|merge|create|alter|drop|truncate)\b/.test(normalized)) {
    return false;
  }
  return !/\bfor\s+update\b/.test(normalized);
};

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
  connectionTimeoutMillis: DB_CONNECTION_TIMEOUT_MS, // Wait for an available connection before failing
  statement_timeout: DB_STATEMENT_TIMEOUT_MS,        // Server-side limit per SQL statement
  query_timeout: DB_QUERY_TIMEOUT_MS,                // Client-side query timeout
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
  client.query(`SET statement_timeout = ${DB_STATEMENT_TIMEOUT_MS}`).catch(() => {});
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

  const { retryTransient, maxRetries, ...pgOptions } = options || {};

  const queryConfig =
    typeof text === 'object' && text !== null
      ? { ...text, ...pgOptions }
      : { text, values: params, ...pgOptions };

  const queryText = typeof queryConfig.text === 'string' ? queryConfig.text : '';
  const allowTransientRetry =
    retryTransient === true ||
    (retryTransient !== false && isReadOnlyQuery(queryText));
  const retryLimit = allowTransientRetry
    ? normalizeRetryCount(maxRetries, DB_TRANSIENT_MAX_RETRIES)
    : 0;

  let attempt = 0;

  while (true) {
    try {
      const res = await pool.query(queryConfig);
      const duration = Date.now() - start;
      if (duration > DB_SLOW_QUERY_LOG_MS) {
        console.log('[WARN] Slow query', {
          text: queryText.substring(0, 80),
          duration,
          rows: res.rowCount,
          attempts: attempt + 1
        });
      }
      return res;
    } catch (error) {
      const shouldRetry =
        attempt < retryLimit &&
        isTransientDatabaseError(error) &&
        !isShuttingDown;

      if (!shouldRetry) {
        console.error('Database query error:', error);
        throw error;
      }

      attempt += 1;
      const backoffMs = DB_TRANSIENT_RETRY_DELAY_MS * attempt;
      console.warn(
        `[WARN] Transient database error on attempt ${attempt}/${retryLimit + 1}: ${error.message}. Retrying in ${backoffMs}ms...`
      );
      await sleep(backoffMs);
    }
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
