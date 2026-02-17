/**
 * Populate ML Training Features
 * 
 * This script extracts features from existing custody records
 * and populates the ml_training_features table for model training.
 * 
 * Run with: node src/scripts/populateTrainingFeatures.js
 */

require('dotenv').config();
const { pool, query } = require('../config/database');
const { extractAllFeatures } = require('../ml/featureExtractor');
const logger = require('../utils/logger');

const populateTrainingFeatures = async () => {
    console.log('='.repeat(60));
    console.log('SafeArms ML Training Features Population Script');
    console.log('='.repeat(60));

    try {
        // Check current training features count
        const existingCount = await query(`
            SELECT COUNT(*) as count FROM ml_training_features
        `);
        console.log(`\nExisting training features: ${existingCount.rows[0].count}`);

        // Get all custody records that don't have features extracted
        const custodyRecords = await query(`
            SELECT 
                cr.custody_id,
                cr.firearm_id,
                cr.officer_id,
                cr.unit_id,
                cr.issued_at,
                cr.returned_at,
                cr.custody_type,
                cr.custody_duration_seconds,
                EXTRACT(HOUR FROM cr.issued_at) as issue_hour,
                EXTRACT(DOW FROM cr.issued_at) as issue_day_of_week,
                CASE WHEN EXTRACT(HOUR FROM cr.issued_at) >= 20 
                     OR EXTRACT(HOUR FROM cr.issued_at) <= 6 
                     THEN true ELSE false END as is_night_issue,
                CASE WHEN EXTRACT(DOW FROM cr.issued_at) IN (0, 6) 
                     THEN true ELSE false END as is_weekend_issue
            FROM custody_records cr
            WHERE NOT EXISTS (
                SELECT 1 FROM ml_training_features mf 
                WHERE mf.custody_record_id = cr.custody_id
            )
            ORDER BY cr.issued_at DESC
        `);

        console.log(`\nCustody records without features: ${custodyRecords.rows.length}`);

        if (custodyRecords.rows.length === 0) {
            console.log('All custody records already have features extracted.');
            console.log('\nTo train the model, you need at least 100 custody records.');
            
            const totalCustody = await query(`SELECT COUNT(*) as count FROM custody_records`);
            console.log(`Total custody records in database: ${totalCustody.rows[0].count}`);
            
            return;
        }

        console.log('\nExtracting features from custody records...\n');

        let success = 0;
        let failed = 0;

        for (const record of custodyRecords.rows) {
            try {
                await extractAllFeatures(record);
                success++;
                process.stdout.write(`\rProcessed: ${success}/${custodyRecords.rows.length}`);
            } catch (error) {
                failed++;
                logger.error(`Failed to extract features for ${record.custody_id}:`, error.message);
            }
        }

        console.log('\n');
        console.log('='.repeat(60));
        console.log('Feature Extraction Complete');
        console.log('='.repeat(60));
        console.log(`Successfully extracted: ${success}`);
        console.log(`Failed: ${failed}`);

        // Check final count
        const finalCount = await query(`
            SELECT COUNT(*) as count FROM ml_training_features
        `);
        console.log(`\nTotal training features now: ${finalCount.rows[0].count}`);

        if (parseInt(finalCount.rows[0].count) >= 100) {
            console.log('\n[OK] You have enough data to train the ML model!');
            console.log('\nTo train the model:');
            console.log('  1. Start the backend server: npm start');
            console.log('  2. POST to /api/settings/train (as admin)');
            console.log('  OR run: node src/scripts/trainModel.js');
        } else {
            console.log(`\n[WARN] You need at least 100 samples. Currently: ${finalCount.rows[0].count}`);
            console.log('Create more custody records to generate training data.');
        }

    } catch (error) {
        console.error('\n[ERROR] Error:', error.message);
        throw error;
    } finally {
        await pool.end();
    }
};

populateTrainingFeatures().catch(console.error);
