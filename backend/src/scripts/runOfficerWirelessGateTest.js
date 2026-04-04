require('dotenv').config();

const http = require('http');

const { query, pool } = require('../config/database');
const { generateToken } = require('../config/auth');
const { assignCustody } = require('../services/custody.service');
const {
  registerOfficerDevice,
  createCustodyAssignmentVerificationRequest,
  getVerificationStatus,
  getVerificationMetrics,
} = require('../services/officerVerification.service');

const API_HOST = process.env.GATE_TEST_API_HOST || '127.0.0.1';
const API_PORT = Number.parseInt(process.env.GATE_TEST_API_PORT || '3000', 10);

const requestJson = ({ method, path, body, token }) =>
  new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const headers = {
      Accept: 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(payload
        ? {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
          }
        : {}),
    };

    const req = http.request(
      {
        host: API_HOST,
        port: API_PORT,
        method,
        path,
        headers,
      },
      (res) => {
        let raw = '';
        res.on('data', (chunk) => {
          raw += chunk.toString();
        });

        res.on('end', () => {
          let parsed = null;
          try {
            parsed = raw ? JSON.parse(raw) : null;
          } catch (_) {
            parsed = raw;
          }

          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve({ statusCode: res.statusCode, data: parsed });
            return;
          }

          const message =
            (parsed && typeof parsed === 'object' && parsed.message) ||
            `Request failed with status ${res.statusCode}`;
          const error = new Error(message);
          error.response = { statusCode: res.statusCode, data: parsed };
          reject(error);
        });
      }
    );

    req.on('error', reject);
    if (payload) {
      req.write(payload);
    }
    req.end();
  });

const selectScenarioContext = async () => {
  const actorResult = await query(
    `SELECT o.officer_id,
            o.full_name AS officer_name,
            o.unit_id AS officer_unit_id,
            u.user_id,
            u.username,
            u.role,
            u.unit_id AS user_unit_id,
            u.email
     FROM officers o
     JOIN users u ON u.is_active = true
     WHERE o.is_active = true
       AND (
         (u.role = 'station_commander' AND u.unit_id = o.unit_id)
         OR u.role = 'admin'
         OR u.role = 'hq_firearm_commander'
       )
     ORDER BY
       CASE
         WHEN u.role = 'station_commander' THEN 0
         WHEN u.role = 'admin' THEN 1
         ELSE 2
       END,
       o.officer_id
     LIMIT 1`
  );

  if (actorResult.rows.length === 0) {
    throw new Error('No eligible officer/commander context found for gate test.');
  }

  const actor = actorResult.rows[0];

  let firearmResult = await query(
    `SELECT firearm_id, serial_number, assigned_unit_id
     FROM firearms
     WHERE is_active = true
       AND current_status = 'available'
       AND assigned_unit_id = $1
     ORDER BY firearm_id
     LIMIT 1`,
    [actor.officer_unit_id]
  );

  if (firearmResult.rows.length === 0) {
    firearmResult = await query(
      `SELECT firearm_id, serial_number, assigned_unit_id
       FROM firearms
       WHERE is_active = true
         AND current_status = 'available'
       ORDER BY firearm_id
       LIMIT 1`
    );
  }

  if (firearmResult.rows.length === 0) {
    throw new Error('No available firearm found for gate test.');
  }

  return {
    officer: {
      officer_id: actor.officer_id,
      full_name: actor.officer_name,
      unit_id: actor.officer_unit_id,
    },
    commander: {
      user_id: actor.user_id,
      username: actor.username,
      role: actor.role,
      unit_id: actor.user_unit_id,
      email: actor.email,
    },
    firearm: firearmResult.rows[0],
  };
};

const buildCommanderContext = (commander) => ({
  user_id: commander.user_id,
  username: commander.username,
  role: commander.role,
  unit_id: commander.unit_id,
  email: commander.email,
});

const run = async () => {
  const startedAt = new Date().toISOString();
  const scenario = await selectScenarioContext();
  const commanderCtx = buildCommanderContext(scenario.commander);

  const uniqueSuffix = `${Date.now()}`;
  const enrollment = await registerOfficerDevice({
    officerId: scenario.officer.officer_id,
    platform: 'android',
    deviceName: `Gate Test Phone ${uniqueSuffix}`,
    deviceFingerprint: `GATE-${scenario.officer.officer_id}-${uniqueSuffix}`,
    appVersion: '1.0.0-gate',
    metadata: {
      seeded_by: 'runOfficerWirelessGateTest',
      started_at: startedAt,
    },
    enrolledBy: scenario.commander.user_id,
    requestingUser: commanderCtx,
  });

  const custody = await assignCustody({
    firearm_id: scenario.firearm.firearm_id,
    officer_id: scenario.officer.officer_id,
    unit_id: scenario.officer.unit_id,
    custody_type: 'temporary',
    assignment_reason: 'Wireless gate test assignment',
    duration_type: '6_hours',
    notes: 'Created by runOfficerWirelessGateTest script',
    issued_by: scenario.commander.user_id,
  });

  const firstVerification = await createCustodyAssignmentVerificationRequest({
    custodyId: custody.custody_id,
    requestedBy: scenario.commander.user_id,
    requestingUser: commanderCtx,
  });

  const mobileCredentials = {
    officer_id: scenario.officer.officer_id,
    device_key: enrollment.device.device_key,
    device_token: enrollment.device_token,
  };

  const pendingBeforeReject = await requestJson({
    method: 'POST',
    path: '/api/officer-verification/mobile/pending',
    body: mobileCredentials,
  });

  const rejectResponse = await requestJson({
    method: 'POST',
    path: '/api/officer-verification/mobile/decision',
    body: {
      verification_id: firstVerification.verification_id,
      ...mobileCredentials,
      challenge_code: firstVerification.challenge_code,
      decision: 'reject',
      reason: 'Gate test rejection path',
      metadata: { channel: 'wireless_gate_test' },
    },
  });

  const rejectedStatus = await getVerificationStatus({
    verificationId: firstVerification.verification_id,
  });

  const secondVerification = await createCustodyAssignmentVerificationRequest({
    custodyId: custody.custody_id,
    requestedBy: scenario.commander.user_id,
    requestingUser: commanderCtx,
  });

  const pendingBeforeApprove = await requestJson({
    method: 'POST',
    path: '/api/officer-verification/mobile/pending',
    body: mobileCredentials,
  });

  const approveResponse = await requestJson({
    method: 'POST',
    path: '/api/officer-verification/mobile/decision',
    body: {
      verification_id: secondVerification.verification_id,
      ...mobileCredentials,
      challenge_code: secondVerification.challenge_code,
      decision: 'approve',
      metadata: { channel: 'wireless_gate_test' },
    },
  });

  const approvedStatus = await getVerificationStatus({
    verificationId: secondVerification.verification_id,
  });

  const commanderToken = generateToken({
    user_id: scenario.commander.user_id,
    username: scenario.commander.username || scenario.commander.user_id,
    role: scenario.commander.role,
    unit_id: scenario.commander.unit_id || scenario.officer.unit_id,
    email: scenario.commander.email || 'gate-test@safearms.local',
  });

  const returnResponse = await requestJson({
    method: 'POST',
    path: `/api/custody/${custody.custody_id}/return`,
    token: commanderToken,
    body: {
      return_condition: 'good',
      notes: 'Wireless gate test return',
      verification_id: secondVerification.verification_id,
    },
  });

  const statusAfterReturn = await requestJson({
    method: 'GET',
    path: `/api/officer-verification/requests/${secondVerification.verification_id}/status`,
    token: commanderToken,
  });

  const metricsFromService = await getVerificationMetrics({
    days: 3,
    unitId: scenario.officer.unit_id,
  });

  const metricsFromRoute = await requestJson({
    method: 'GET',
    path: `/api/officer-verification/ops/metrics?days=3&unit_id=${encodeURIComponent(
      scenario.officer.unit_id
    )}`,
    token: commanderToken,
  });

  const passChecks = {
    pending_before_reject_has_first_request: Array.isArray(
      pendingBeforeReject.data?.data
    )
      ? pendingBeforeReject.data.data.some(
          (item) => item.verification_id === firstVerification.verification_id
        )
      : false,
    rejected_status_persisted: rejectedStatus.decision === 'rejected',
    pending_before_approve_has_second_request: Array.isArray(
      pendingBeforeApprove.data?.data
    )
      ? pendingBeforeApprove.data.data.some(
          (item) => item.verification_id === secondVerification.verification_id
        )
      : false,
    approved_status_persisted: approvedStatus.decision === 'approved',
    custody_return_consumed_verification:
      returnResponse.data?.verification?.consumed === true,
    consumed_at_visible_in_status: Boolean(
      statusAfterReturn.data?.data?.consumed_at
    ),
    metrics_include_rejected: Number(metricsFromService.rejected || 0) >= 1,
    metrics_include_approved: Number(metricsFromService.approved || 0) >= 1,
    metrics_include_consumed: Number(metricsFromService.consumed || 0) >= 1,
  };

  const failedCheck = Object.entries(passChecks).find(([, value]) => !value);
  if (failedCheck) {
    throw new Error(`Gate test failed at check: ${failedCheck[0]}`);
  }

  const summary = {
    started_at: startedAt,
    finished_at: new Date().toISOString(),
    api_target: `http://${API_HOST}:${API_PORT}`,
    officer: scenario.officer,
    commander: {
      user_id: scenario.commander.user_id,
      role: scenario.commander.role,
      unit_id: scenario.commander.unit_id,
    },
    device: {
      device_key: enrollment.device.device_key,
      device_token: enrollment.device_token,
      token_rotated: enrollment.reused_existing_device === true,
    },
    custody: {
      custody_id: custody.custody_id,
      firearm_id: custody.firearm_id,
      return_condition: returnResponse.data?.data?.return_condition,
    },
    verification: {
      rejected_verification_id: firstVerification.verification_id,
      approved_verification_id: secondVerification.verification_id,
      consumed_verification_id:
        returnResponse.data?.verification?.verification_id || null,
      rejected_decision: rejectedStatus.decision,
      approved_decision: approvedStatus.decision,
      approved_consumed_at: statusAfterReturn.data?.data?.consumed_at || null,
    },
    metrics_service: metricsFromService,
    metrics_route: metricsFromRoute.data?.data || null,
    checks: passChecks,
  };

  console.log(JSON.stringify(summary, null, 2));
};

run()
  .then(async () => {
    await pool.end();
    process.exit(0);
  })
  .catch(async (error) => {
    const detail = {
      message: error.message,
      response: error.response || null,
      stack: error.stack,
    };
    console.error(JSON.stringify(detail, null, 2));
    await pool.end().catch(() => {});
    process.exit(1);
  });
