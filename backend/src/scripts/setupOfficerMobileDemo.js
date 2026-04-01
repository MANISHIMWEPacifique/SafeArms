require('dotenv').config();

const { query } = require('../config/database');
const { assignCustody } = require('../services/custody.service');
const {
  registerOfficerDevice,
  createCustodyAssignmentVerificationRequest,
} = require('../services/officerVerification.service');

const DEFAULT_OFFICER_ID = 'OFF-001';

const run = async () => {
  const officerId = process.argv[2] || DEFAULT_OFFICER_ID;

  const officerResult = await query(
    `SELECT officer_id, full_name, unit_id, is_active
     FROM officers
     WHERE officer_id = $1`,
    [officerId]
  );

  if (officerResult.rows.length === 0) {
    throw new Error(`Officer not found: ${officerId}`);
  }

  const officer = officerResult.rows[0];
  if (!officer.is_active) {
    throw new Error(`Officer is inactive: ${officerId}`);
  }

  const commanderResult = await query(
    `SELECT user_id, username, role, unit_id
     FROM users
     WHERE is_active = true
       AND (
         (role = 'station_commander' AND unit_id = $1)
         OR role = 'admin'
         OR role = 'hq_firearm_commander'
       )
     ORDER BY
       CASE
         WHEN role = 'station_commander' THEN 0
         WHEN role = 'admin' THEN 1
         ELSE 2
       END,
       user_id
     LIMIT 1`,
    [officer.unit_id]
  );

  if (commanderResult.rows.length === 0) {
    throw new Error(`No eligible commander/admin user found for unit ${officer.unit_id}`);
  }

  const commander = commanderResult.rows[0];

  const deviceFingerprint =
    process.env.MOBILE_DEMO_DEVICE_FINGERPRINT || `DEMO-${officer.officer_id}-${Date.now()}`;

  const enrollment = await registerOfficerDevice({
    officerId: officer.officer_id,
    platform: 'android',
    deviceName: process.env.MOBILE_DEMO_DEVICE_NAME || 'SafeArms Demo Phone',
    deviceFingerprint,
    appVersion: process.env.MOBILE_DEMO_APP_VERSION || '1.0.0',
    metadata: {
      seeded_by: 'setupOfficerMobileDemo',
      created_at: new Date().toISOString(),
    },
    enrolledBy: commander.user_id,
    requestingUser: {
      user_id: commander.user_id,
      role: commander.role,
      unit_id: commander.unit_id,
    },
  });

  let firearmResult = await query(
    `SELECT firearm_id, serial_number, assigned_unit_id
     FROM firearms
     WHERE current_status = 'available'
       AND assigned_unit_id = $1
     ORDER BY firearm_id
     LIMIT 1`,
    [officer.unit_id]
  );

  if (firearmResult.rows.length === 0) {
    firearmResult = await query(
      `SELECT firearm_id, serial_number, assigned_unit_id
       FROM firearms
       WHERE current_status = 'available'
       ORDER BY firearm_id
       LIMIT 1`
    );
  }

  if (firearmResult.rows.length === 0) {
    throw new Error('No available firearm found to create custody assignment.');
  }

  const firearm = firearmResult.rows[0];

  const custody = await assignCustody({
    firearm_id: firearm.firearm_id,
    officer_id: officer.officer_id,
    unit_id: officer.unit_id,
    custody_type: 'temporary',
    assignment_reason: 'Mobile verification demo setup',
    duration_type: '8_hours',
    notes: 'Created by setupOfficerMobileDemo script',
    issued_by: commander.user_id,
  });

  const verification = await createCustodyAssignmentVerificationRequest({
    custodyId: custody.custody_id,
    requestedBy: commander.user_id,
    requestingUser: {
      user_id: commander.user_id,
      role: commander.role,
      unit_id: commander.unit_id,
    },
  });

  const output = {
    officer: {
      officer_id: officer.officer_id,
      full_name: officer.full_name,
      unit_id: officer.unit_id,
    },
    commander: {
      user_id: commander.user_id,
      username: commander.username,
      role: commander.role,
      unit_id: commander.unit_id,
    },
    device: {
      device_key: enrollment.device.device_key,
      device_token: enrollment.device_token,
      reused_existing_device: enrollment.reused_existing_device,
    },
    custody: {
      custody_id: custody.custody_id,
      firearm_id: custody.firearm_id,
    },
    verification: {
      verification_id: verification.verification_id,
      challenge_code: verification.challenge_code,
      expires_at: verification.expires_at,
      is_existing: verification.is_existing,
    },
    build_defines: {
      SAFEARMS_USE_MOCK_FLOW: 'false',
      SAFEARMS_API_BASE_URL:
        process.env.MOBILE_DEMO_API_BASE_URL || 'http://<LAN-IP>:3000/api',
      SAFEARMS_OFFICER_ID: officer.officer_id,
      SAFEARMS_DEVICE_KEY: enrollment.device.device_key,
      SAFEARMS_DEVICE_TOKEN: enrollment.device_token,
    },
  };

  console.log(JSON.stringify(output, null, 2));
};

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
