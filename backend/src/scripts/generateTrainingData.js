/**
 * Generate Sample Training Data
 * 
 * Creates synthetic custody records for ML model training.
 * USE FOR DEVELOPMENT/TESTING ONLY - Not for production!
 * 
 * Run with: node src/scripts/generateTrainingData.js
 */

require('dotenv').config();
const { pool, query } = require('../config/database');
const { v4: uuidv4 } = require('uuid');

const generateTrainingData = async () => {
    console.log('='.repeat(60));
    console.log('SafeArms Sample Training Data Generator');
    console.log('='.repeat(60));
    console.log('\n⚠️  WARNING: This is for DEVELOPMENT/TESTING only!');
    console.log('    Do not use synthetic data in production.\n');

    try {
        // Get existing officers, firearms, and units
        const officers = await query(`SELECT officer_id, unit_id FROM officers WHERE is_active = true LIMIT 20`);
        const firearms = await query(`SELECT firearm_id, assigned_unit_id FROM firearms WHERE current_status = 'available' LIMIT 30`);
        const units = await query(`SELECT unit_id FROM units WHERE is_active = true`);
        const users = await query(`SELECT user_id FROM users WHERE role IN ('station_commander', 'hq_firearm_commander') LIMIT 5`);

        if (officers.rows.length === 0 || firearms.rows.length === 0 || units.rows.length === 0) {
            console.log('❌ Not enough base data. Make sure you have:');
            console.log('   - Officers in the officers table');
            console.log('   - Firearms in the firearms table');
            console.log('   - Units in the units table');
            console.log('\nRun the seed_data_new.sql script first.');
            return;
        }

        console.log(`Found: ${officers.rows.length} officers, ${firearms.rows.length} firearms, ${units.rows.length} units`);

        // Generate synthetic custody records
        const recordsToGenerate = 150; // Generate 150 records for training
        console.log(`\nGenerating ${recordsToGenerate} synthetic custody records...`);

        const custodyTypes = ['permanent', 'temporary'];
        const assignmentReasons = [
            'Standard patrol duty',
            'Special operation',
            'VIP protection detail',
            'Training exercise',
            'Night shift security',
            'Event security',
            'Investigation support',
            'Community patrol'
        ];

        let created = 0;
        const now = new Date();

        for (let i = 0; i < recordsToGenerate; i++) {
            const officer = officers.rows[Math.floor(Math.random() * officers.rows.length)];
            const firearm = firearms.rows[Math.floor(Math.random() * firearms.rows.length)];
            const unit = officer.unit_id || units.rows[Math.floor(Math.random() * units.rows.length)].unit_id;
            const issuedBy = users.rows[Math.floor(Math.random() * users.rows.length)]?.user_id || null;

            // Random date within last 6 months
            const daysAgo = Math.floor(Math.random() * 180);
            const issuedAt = new Date(now.getTime() - daysAgo * 24 * 60 * 60 * 1000);
            
            // Random hour (with some bias towards normal hours)
            const hour = Math.random() < 0.85 
                ? Math.floor(Math.random() * 12) + 6  // 6 AM to 6 PM (85%)
                : Math.floor(Math.random() * 24);     // Any hour (15%)
            issuedAt.setHours(hour, Math.floor(Math.random() * 60), 0, 0);

            // Most are returned (80%)
            const isReturned = Math.random() < 0.8;
            const custodyDurationHours = isReturned 
                ? Math.floor(Math.random() * 240) + 1  // 1 to 240 hours
                : null;
            
            const returnedAt = isReturned 
                ? new Date(issuedAt.getTime() + custodyDurationHours * 60 * 60 * 1000)
                : null;

            const custodyType = isReturned && custodyDurationHours < 24 
                ? 'temporary' 
                : custodyTypes[Math.floor(Math.random() * custodyTypes.length)];

            try {
                await query(`
                    INSERT INTO custody_records (
                        custody_id, firearm_id, officer_id, unit_id, custody_type,
                        issued_at, issued_by, returned_at, returned_to,
                        custody_duration_seconds, assignment_reason, notes,
                        issue_hour, issue_day_of_week, is_night_issue, is_weekend_issue
                    ) VALUES (
                        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16
                    )
                    ON CONFLICT (custody_id) DO NOTHING
                `, [
                    uuidv4(),
                    firearm.firearm_id,
                    officer.officer_id,
                    unit,
                    custodyType,
                    issuedAt,
                    issuedBy,
                    returnedAt,
                    isReturned ? issuedBy : null,
                    isReturned ? custodyDurationHours * 3600 : null,
                    assignmentReasons[Math.floor(Math.random() * assignmentReasons.length)],
                    'Generated sample data for ML training',
                    issuedAt.getHours(),
                    issuedAt.getDay(),
                    issuedAt.getHours() >= 20 || issuedAt.getHours() <= 6,
                    issuedAt.getDay() === 0 || issuedAt.getDay() === 6
                ]);
                created++;
                process.stdout.write(`\rCreated: ${created}/${recordsToGenerate}`);
            } catch (err) {
                // Ignore conflicts
            }
        }

        console.log('\n');
        console.log('='.repeat(60));
        console.log('Sample Data Generation Complete');
        console.log('='.repeat(60));
        console.log(`Created: ${created} custody records`);

        // Check total
        const totalCount = await query(`SELECT COUNT(*) as count FROM custody_records`);
        console.log(`Total custody records: ${totalCount.rows[0].count}`);

        console.log('\nNext steps:');
        console.log('  1. Extract features: node src/scripts/populateTrainingFeatures.js');
        console.log('  2. Train model: node src/scripts/trainModel.js');

    } catch (error) {
        console.error('\n❌ Error:', error.message);
        throw error;
    } finally {
        await pool.end();
    }
};

generateTrainingData().catch(console.error);
