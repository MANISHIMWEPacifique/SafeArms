#!/usr/bin/env node

/*
 * Verifies the SafeArms ML training/anomaly hardening work.
 *
 * Usage:
 *   node src/scripts/verifyMlTrainingHardening.js
 *   node src/scripts/verifyMlTrainingHardening.js --train
 */

require('dotenv').config();

const { pool, query } = require('../config/database');
const { trainModel, getMinTrainingSamples } = require('../ml/modelTrainer');
const { calculateEnsembleScore } = require('../ml/scorer');

const REQUIRED_AUDIT_COLUMNS = [
    'old_values',
    'new_values',
    'reason',
    'actor_role',
    'actor_unit_name',
    'subject_type',
    'subject_id',
    'is_chain_of_custody_event'
];

const REQUIRED_THRESHOLD_KEYS = [
    'anomaly_trigger_threshold',
    'anomaly_medium_threshold',
    'anomaly_high_threshold',
    'anomaly_critical_threshold',
    'anomaly_critical_min_confidence'
];

const hasArg = (name) => process.argv.includes(name);

const assert = (condition, message) => {
    if (!condition) {
        throw new Error(message);
    }
};

const logOk = (message) => {
    console.log(`[OK] ${message}`);
};

const verifyAuditSchema = async () => {
    const result = await query(`
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'audit_logs'
          AND column_name = ANY($1::text[])
    `, [REQUIRED_AUDIT_COLUMNS]);

    const found = new Set(result.rows.map((row) => row.column_name));
    const missing = REQUIRED_AUDIT_COLUMNS.filter((column) => !found.has(column));
    assert(missing.length === 0, `audit_logs is missing required column(s): ${missing.join(', ')}`);
    logOk('audit_logs has required training/audit columns.');
};

const verifyThresholdSettings = async () => {
    const result = await query(`
        SELECT setting_key
        FROM system_settings
        WHERE setting_key = ANY($1::text[])
    `, [REQUIRED_THRESHOLD_KEYS]);

    const found = new Set(result.rows.map((row) => row.setting_key));
    const missing = REQUIRED_THRESHOLD_KEYS.filter((key) => !found.has(key));
    assert(missing.length === 0, `system_settings is missing anomaly threshold(s): ${missing.join(', ')}`);
    logOk('anomaly scoring thresholds are seeded.');
};

const verifyFeatureUniqueness = async () => {
    const result = await query(`
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'ml_training_features'
          AND indexname = 'idx_ml_training_features_custody_record_unique'
        LIMIT 1
    `);

    assert(result.rows.length === 1, 'missing unique index on ml_training_features(custody_record_id)');
    logOk('ml_training_features is unique by custody_record_id.');
};

const verifyTrainingReadiness = async () => {
    const minimumSamples = getMinTrainingSamples();
    const result = await query(`
        SELECT COUNT(*)::int AS recent_features
        FROM ml_training_features
        WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);

    const recentFeatures = parseInt(result.rows[0].recent_features, 10);
    assert(
        recentFeatures >= minimumSamples,
        `insufficient recent training features: need ${minimumSamples}, found ${recentFeatures}`
    );
    logOk(`training readiness met (${recentFeatures}/${minimumSamples} recent features).`);
};

const verifyActiveModelInvariant = async () => {
    const result = await query(`
        SELECT COUNT(*)::int AS active_count
        FROM ml_model_metadata
        WHERE model_type = 'kmeans'
          AND is_active = true
    `);

    const activeCount = parseInt(result.rows[0].active_count, 10);
    assert(activeCount === 1, `expected exactly one active K-Means model, found ${activeCount}`);
    logOk('exactly one active K-Means model exists.');
};

const verifyRulesOnlyScoring = () => {
    const result = calculateEnsembleScore(
        null,
        { is_anomaly: false, anomaly_score: 0, outliers: [] },
        {
            is_cross_unit_transfer: true,
            previous_unit_name: 'Previous Unit',
            ballistic_access_timing_score: 0,
            has_ballistic_profile: false
        },
        { aggregate_score: 0, rules_triggered: [], rule_count: 0 },
        false
    );

    assert(result.is_anomaly === true, 'rules-only cross-unit scoring did not flag an anomaly');
    assert(result.is_mandatory_review === true, 'cross-unit scoring did not require mandatory review');
    assert(result.weighting_mode === 'rules_only', 'rules-only scoring did not report rules_only mode');
    logOk('rules/statistical fallback scoring works without an active ML contribution.');
};

const runTrainingVerification = async () => {
    console.log('[INFO] Running end-to-end model training verification...');

    const result = await trainModel({ minSamples: getMinTrainingSamples() });
    assert(result.success === true, 'trainModel did not return success');
    assert(result.promotion?.promoted_model_id === result.model_id, 'promoted model id does not match training result');

    await verifyActiveModelInvariant();

    const auditResult = await query(`
        SELECT log_id
        FROM audit_logs
        WHERE action_type = 'ML_MODEL_PROMOTE'
          AND table_name = 'ml_model_metadata'
          AND record_id = $1
        ORDER BY created_at DESC
        LIMIT 1
    `, [result.model_id]);

    assert(auditResult.rows.length === 1, `missing ML_MODEL_PROMOTE audit log for ${result.model_id}`);
    logOk(`training promoted ${result.model_id} and wrote promotion audit log.`);
};

const run = async () => {
    const shouldTrain = hasArg('--train');

    await verifyAuditSchema();
    await verifyThresholdSettings();
    await verifyFeatureUniqueness();
    await verifyTrainingReadiness();
    await verifyActiveModelInvariant();
    verifyRulesOnlyScoring();

    if (shouldTrain) {
        await runTrainingVerification();
    } else {
        console.log('[SKIP] Training flow skipped. Pass --train to run the mutating end-to-end training check.');
    }

    console.log('\n[PASS] ML training/anomaly hardening verification complete.');
};

run()
    .catch((error) => {
        console.error(`\n[FAIL] ${error.message}`);
        process.exitCode = 1;
    })
    .finally(async () => {
        await pool.end();
    });
