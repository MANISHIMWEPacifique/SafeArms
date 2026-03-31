/**
 * Generate realistic custody-cycle training data and extract features.
 *
 * Usage:
 *   node src/scripts/generateTrainingData.js
 *   node src/scripts/generateTrainingData.js all
 *   node src/scripts/generateTrainingData.js baseline
 *   node src/scripts/generateTrainingData.js anomalies
 *   node src/scripts/generateTrainingData.js all 2026-04-06
 *
 * The optional second argument is cycle start date (YYYY-MM-DD).
 */

require('dotenv').config();
const { pool } = require('../config/database');
const { generateTrainingDataBatch } = require('../services/trainingDataGenerator.service');

const mode = (process.argv[2] || 'all').toLowerCase();
const startDate = process.argv[3] || null;

const run = async () => {
    console.log('='.repeat(70));
    console.log('SafeArms Realistic Training Data Generator');
    console.log('='.repeat(70));
    console.log(`Mode: ${mode}`);
    console.log(`Start date: ${startDate || 'auto'}`);

    try {
        const result = await generateTrainingDataBatch({
            mode,
            startDate,
            extractFeatures: true
        });

        console.log('\n[OK] Training data generation completed');
        console.log(`Batch code: ${result.batch_code}`);
        console.log(`Cycle start: ${result.cycle_start_date}`);
        console.log(`Seeded rows: ${result.seeded_rows}`);
        console.log(`Extracted features: ${result.extracted_features}`);
        console.log(`Training readiness: ${result.can_train ? 'READY' : 'NOT READY'}`);
        console.log(`Available samples: ${result.available_training_samples}`);
        console.log(`Minimum required: ${result.minimum_required_samples}`);
        console.log('\n[NEXT] Train model from admin dashboard Settings > Train model');
    } catch (error) {
        console.error(`\n[ERROR] ${error.message}`);
        process.exitCode = 1;
    } finally {
        await pool.end();
    }
};

run().catch(async (error) => {
    console.error(`[FATAL] ${error.message}`);
    await pool.end();
    process.exit(1);
});
