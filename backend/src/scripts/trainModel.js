/**
 * Train ML Model Script
 * 
 * Manually triggers K-Means model training.
 * 
 * Run with: node src/scripts/trainModel.js
 */

require('dotenv').config();
const { pool, query } = require('../config/database');
const { trainModel, checkRetrainingNeeded, getModelMetrics } = require('../ml/modelTrainer');
const logger = require('../utils/logger');

const trainMLModel = async () => {
    console.log('='.repeat(60));
    console.log('SafeArms ML Model Training Script');
    console.log('='.repeat(60));

    try {
        // Check training data availability
        const countResult = await query(`
            SELECT COUNT(*) as count
            FROM ml_training_features
            WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
        `);
        const sampleCount = parseInt(countResult.rows[0].count);
        
        console.log(`\nTraining samples available: ${sampleCount}`);
        
        if (sampleCount < 100) {
            console.log('\n❌ Insufficient training data!');
            console.log(`   Need at least 100 samples, you have ${sampleCount}.`);
            console.log('\nOptions:');
            console.log('  1. Create more custody records in the app');
            console.log('  2. Run: node src/scripts/populateTrainingFeatures.js');
            console.log('  3. Import more seed data');
            return;
        }

        // Check if retraining is needed
        console.log('\nChecking if retraining is needed...');
        const check = await checkRetrainingNeeded();
        console.log(`Retraining: ${check.needed ? 'NEEDED' : 'OPTIONAL'}`);
        console.log(`Reason: ${check.reason}`);

        // Proceed with training
        console.log('\n' + '-'.repeat(60));
        console.log('Starting K-Means model training...');
        console.log('-'.repeat(60));

        const result = await trainModel({ k: 6, minSamples: 100 });

        console.log('\n' + '='.repeat(60));
        console.log('✅ MODEL TRAINING COMPLETE');
        console.log('='.repeat(60));
        console.log(`Model ID: ${result.model_id}`);
        console.log(`Training samples: ${result.training_samples}`);
        console.log(`Number of clusters: ${result.num_clusters}`);
        console.log(`Silhouette score: ${result.silhouette_score?.toFixed(4)}`);
        console.log(`Outlier threshold: ${result.outlier_threshold?.toFixed(4)}`);
        console.log(`Training date: ${new Date().toISOString()}`);

        // Verify model is active
        const activeModel = await query(`
            SELECT model_id, is_active
            FROM ml_model_metadata
            WHERE is_active = true
            ORDER BY training_date DESC
            LIMIT 1
        `);

        if (activeModel.rows.length > 0) {
            console.log(`\n✅ Active model: ${activeModel.rows[0].model_id}`);
            console.log('\nThe model is now ready for anomaly detection.');
            console.log('Anomalies will be automatically detected on new custody transactions.');
        }

    } catch (error) {
        console.error('\n❌ Training failed:', error.message);
        throw error;
    } finally {
        await pool.end();
    }
};

trainMLModel().catch(console.error);
