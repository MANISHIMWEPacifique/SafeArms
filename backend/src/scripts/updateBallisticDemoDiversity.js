// Audited demo ballistic profile diversity updater.
// Run from backend with:
//   node src/scripts/updateBallisticDemoDiversity.js --apply

require('dotenv').config();
const { Pool } = require('pg');
const crypto = require('crypto');

const shouldApply = process.argv.includes('--apply');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('localhost') ? false : { rejectUnauthorized: false }
});

const generateRegistrationHash = (profileData) => {
  const dataString = JSON.stringify({
    firearm_id: profileData.firearm_id,
    test_date: profileData.test_date,
    rifling_characteristics: profileData.rifling_characteristics,
    firing_pin_impression: profileData.firing_pin_impression,
    ejector_marks: profileData.ejector_marks,
    extractor_marks: profileData.extractor_marks,
    chamber_marks: profileData.chamber_marks
  });
  return crypto.createHash('sha256').update(dataString).digest('hex');
};

const nextLogId = () => (
  `L-${Date.now().toString(36).toUpperCase()}${Math.random().toString(36).slice(2, 7).toUpperCase()}`
);

const isNineMillimeter = (caliber = '') => /(^|[^0-9])9\s*(x|mm)/i.test(caliber);

const traitUpdates = [
  {
    label: 'punctuated pistol firing pin',
    prefer: (row) => row.firearm_type === 'pistol' || isNineMillimeter(row.caliber || ''),
    values: {
      rifling_characteristics: '6 grooves, right-hand twist, 1:10 pitch',
      firing_pin_impression: 'Circular, centered, 0.82.mm with smooth primer rim',
      ejector_marks: 'Semi-circular ejector mark at 4 o clock, polished edge',
      extractor_marks: 'Fine linear extractor mark at 10 o clock',
      chamber_marks: 'Polygonal chamber with shallow feed-ramp polish',
      notes: 'Demo diversity update: punctuation-insensitive firing-pin search candidate'
    }
  },
  {
    label: 'AK diagonal feed-ramp profile',
    prefer: (row) => row.firearm_type === 'rifle' || /7\.62/i.test(row.caliber || ''),
    values: {
      rifling_characteristics: '4 grooves, right-hand twist, 1:9.45 pitch',
      firing_pin_impression: 'Rectangular, centered, 1.20mm x 0.80mm with shallow drag tail',
      ejector_marks: 'Rectangular ejector mark at 3 o clock, light brass smear',
      extractor_marks: 'Linear extractor score at 9 o clock, medium depth',
      chamber_marks: 'Stamped receiver marks with diagonal feed-ramp striation',
      notes: 'Demo diversity update: AK-pattern chamber and feed-ramp comparison profile'
    }
  },
  {
    label: 'NATO clean-shoulder profile',
    prefer: (row) => row.firearm_type === 'rifle' || /5\.56/i.test(row.caliber || ''),
    values: {
      rifling_characteristics: '6 grooves, right-hand twist, 1:7 pitch',
      firing_pin_impression: 'Circular, centered, 1.00mm diameter with crisp rim',
      ejector_marks: 'Rectangular ejector mark at 2 o clock, clean shoulder',
      extractor_marks: 'Linear extractor mark at 8 o clock with short secondary scratch',
      chamber_marks: 'Clean chamber with moderate parallel tool marks',
      notes: 'Demo diversity update: NATO-pattern rifle profile for comparison searches'
    }
  },
  {
    label: 'offset extractor profile',
    prefer: () => true,
    values: {
      rifling_characteristics: '4 grooves, right-hand twist, 1:9.45 pitch',
      firing_pin_impression: 'Rectangular, slight left offset, 1.12mm x 0.76mm',
      ejector_marks: 'Rectangular ejector mark at 4 o clock with chipped lower edge',
      extractor_marks: 'Double linear extractor mark at 8 o clock',
      chamber_marks: 'Chamber rub with two short parallel tool marks',
      notes: 'Demo diversity update: distinct extractor and chamber-rub comparison profile'
    }
  }
];

const selectRowsForUpdates = (rows) => {
  const selectedIds = new Set();
  return traitUpdates
    .map((update) => {
      const preferred = rows.find((row) => !selectedIds.has(row.ballistic_id) && update.prefer(row));
      const fallback = rows.find((row) => !selectedIds.has(row.ballistic_id));
      const row = preferred || fallback;
      if (row) selectedIds.add(row.ballistic_id);
      return row ? { row, update } : null;
    })
    .filter(Boolean);
};

async function run() {
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required');
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const profiles = await client.query(`
      SELECT bp.*, f.firearm_type, f.caliber
      FROM ballistic_profiles bp
      JOIN firearms f ON bp.firearm_id = f.firearm_id
      ORDER BY bp.ballistic_id
      LIMIT 40
    `);

    const selected = selectRowsForUpdates(profiles.rows);
    if (selected.length === 0) {
      console.log('[INFO] No ballistic profiles found to update.');
      await client.query('ROLLBACK');
      return;
    }

    for (const { row, update } of selected) {
      const nextProfile = {
        ...row,
        ...update.values
      };
      const registrationHash = generateRegistrationHash(nextProfile);

      const updated = await client.query(`
        UPDATE ballistic_profiles
        SET rifling_characteristics = $1,
            firing_pin_impression = $2,
            ejector_marks = $3,
            extractor_marks = $4,
            chamber_marks = $5,
            notes = $6,
            registration_hash = $7,
            updated_at = CURRENT_TIMESTAMP
        WHERE ballistic_id = $8
        RETURNING *
      `, [
        update.values.rifling_characteristics,
        update.values.firing_pin_impression,
        update.values.ejector_marks,
        update.values.extractor_marks,
        update.values.chamber_marks,
        update.values.notes,
        registrationHash,
        row.ballistic_id
      ]);

      await client.query(`
        INSERT INTO audit_logs (
          log_id, user_id, action_type, table_name, record_id,
          old_values, new_values, reason, success
        )
        VALUES ($1, NULL, 'BALLISTIC_DEMO_DIVERSITY_UPDATE', 'ballistic_profiles', $2, $3, $4, $5, true)
      `, [
        nextLogId(),
        row.ballistic_id,
        JSON.stringify(row),
        JSON.stringify(updated.rows[0]),
        `Audited demo updater applied ${update.label}`
      ]);

      console.log(`[OK] Prepared ${row.ballistic_id}: ${update.label}`);
    }

    if (shouldApply) {
      await client.query('COMMIT');
      console.log(`[OK] Applied ${selected.length} audited ballistic profile updates.`);
    } else {
      await client.query('ROLLBACK');
      console.log('[INFO] Dry run complete. Re-run with --apply to update the database.');
    }
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

run().catch((error) => {
  console.error('[ERROR] Failed to update ballistic demo diversity:', error.message);
  process.exit(1);
});
