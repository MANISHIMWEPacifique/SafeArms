#!/usr/bin/env node

/*
 * Deployment smoke checks for a hosted SafeArms backend.
 *
 * Usage:
 *   node src/scripts/deploySmokeCheck.js --base-url https://your-api.example.com
 *
 * Optional officer verification check:
 *   node src/scripts/deploySmokeCheck.js \
 *     --base-url https://your-api.example.com \
 *     --officer-id OFF-001 \
 *     --device-key DVK-XXXX \
 *     --device-token YOUR_TOKEN
 */

const REQUIRED_ARGS = ['--base-url'];

function readArg(name) {
  const i = process.argv.indexOf(name);
  if (i === -1 || i + 1 >= process.argv.length) {
    return '';
  }
  return String(process.argv[i + 1]).trim();
}

function hasArg(name) {
  return process.argv.includes(name);
}

function normalizeBaseUrl(value) {
  const trimmed = value.trim();
  if (!trimmed) {
    throw new Error('Missing --base-url value.');
  }

  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch (error) {
    throw new Error(`Invalid --base-url value: ${trimmed}`);
  }

  if (!['http:', 'https:'].includes(parsed.protocol)) {
    throw new Error('Base URL must start with http:// or https://');
  }

  return parsed.toString().replace(/\/$/, '');
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();

  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch (_) {
      // Keep raw text in case endpoint is not JSON.
    }
  }

  return { response, text, json };
}

async function run() {
  if (hasArg('--help') || hasArg('-h')) {
    console.log('Usage:');
    console.log('  node src/scripts/deploySmokeCheck.js --base-url https://your-api.example.com');
    console.log('Optional officer endpoint check arguments: --officer-id --device-key --device-token');
    process.exit(0);
  }

  for (const arg of REQUIRED_ARGS) {
    if (!hasArg(arg)) {
      throw new Error(`Required argument missing: ${arg}`);
    }
  }

  const baseUrl = normalizeBaseUrl(readArg('--base-url'));
  const officerId = readArg('--officer-id');
  const deviceKey = readArg('--device-key');
  const deviceToken = readArg('--device-token');

  const checks = [];

  const healthUrl = `${baseUrl}/health`;
  console.log(`[SMOKE] GET ${healthUrl}`);
  const health = await fetchJson(healthUrl, { method: 'GET' });

  if (!health.response.ok) {
    throw new Error(`Health check failed (${health.response.status}): ${health.text || '<empty>'}`);
  }

  checks.push('health');
  console.log('[OK] Health endpoint reachable.');

  const hasOfficerArgs = officerId && deviceKey && deviceToken;
  const hasPartialOfficerArgs = officerId || deviceKey || deviceToken;

  if (hasPartialOfficerArgs && !hasOfficerArgs) {
    throw new Error('Provide all officer args together: --officer-id --device-key --device-token');
  }

  if (hasOfficerArgs) {
    const pendingUrl = `${baseUrl}/api/officer-verification/mobile/pending`;
    console.log(`[SMOKE] POST ${pendingUrl}`);

    const pending = await fetchJson(pendingUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        officer_id: officerId,
        device_key: deviceKey,
        device_token: deviceToken,
      }),
    });

    if (!pending.response.ok) {
      throw new Error(
        `Officer pending check failed (${pending.response.status}): ${pending.text || '<empty>'}`,
      );
    }

    checks.push('officer-mobile-pending');
    console.log('[OK] Officer mobile pending endpoint reachable and responded successfully.');
  } else {
    console.log('[SKIP] Officer mobile pending check skipped (credentials not provided).');
  }

  console.log(`\n[PASS] Smoke checks complete: ${checks.join(', ')}`);
}

run().catch((error) => {
  console.error(`\n[FAIL] ${error.message}`);
  process.exit(1);
});
