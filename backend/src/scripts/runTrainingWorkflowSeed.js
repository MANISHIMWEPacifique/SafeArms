/**
 * Run deterministic training workflow SQL seeds.
 *
 * Usage:
 *   node src/scripts/runTrainingWorkflowSeed.js all
 *   node src/scripts/runTrainingWorkflowSeed.js baseline
 *   node src/scripts/runTrainingWorkflowSeed.js anomalies
 *   node src/scripts/runTrainingWorkflowSeed.js validate
 */

require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool, query } = require('../config/database');

const TRAINING_DIR = path.resolve(__dirname, '../../../database/training');

const FILES = {
    baseline: ['training_regular_weeks_baseline.sql'],
    anomalies: ['training_anomaly_injection.sql'],
    all: [
        'training_regular_weeks_baseline.sql',
        'training_anomaly_injection.sql'
    ],
    validate: ['training_seed_validation.sql']
};

const mode = (process.argv[2] || 'all').toLowerCase();

const run = async () => {
    console.log('='.repeat(70));
    console.log('SafeArms Deterministic Training Seed Runner');
    console.log('='.repeat(70));
    console.log(`Mode: ${mode}`);

    if (!FILES[mode]) {
        console.error('Unsupported mode. Use one of: baseline, anomalies, all, validate');
        process.exitCode = 1;
        return;
    }

    try {
        for (const fileName of FILES[mode]) {
            const fullPath = path.join(TRAINING_DIR, fileName);
            if (!fs.existsSync(fullPath)) {
                throw new Error(`Seed file not found: ${fullPath}`);
            }

            const sql = fs.readFileSync(fullPath, 'utf8');
            console.log(`\n[RUN] ${fileName}`);
            await query(sql, [], { query_timeout: 120000 });
            console.log(`[OK] Executed ${fileName}`);
        }

        if (mode !== 'validate') {
            const seededCountResult = await query(`
                SELECT COUNT(*) AS count
                FROM custody_records
                WHERE custody_id LIKE 'CUS-RW26-%'
            `);

            const seededCount = parseInt(seededCountResult.rows[0].count, 10);
            console.log(`\n[INFO] Total deterministic seeded custody rows: ${seededCount}`);
            console.log('[NEXT] Extract features: node src/scripts/populateTrainingFeatures.js');
            console.log('[NEXT] Train model: node src/scripts/trainModel.js');
            console.log('[NEXT] Validate: node src/scripts/runTrainingWorkflowSeed.js validate');
        }

        console.log('\n[DONE] Training seed operation completed.');
    } catch (error) {
        console.error(`\n[ERROR] ${error.message}`);
        process.exitCode = 1;
    } finally {
        await pool.end();
    }
};

run().catch((error) => {
    console.error(`[FATAL] ${error.message}`);
    process.exit(1);
});
