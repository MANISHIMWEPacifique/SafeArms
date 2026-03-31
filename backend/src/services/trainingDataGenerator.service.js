const fs = require('fs');
const path = require('path');
const { query } = require('../config/database');
const { extractAllFeatures } = require('../ml/featureExtractor');
const { getMinTrainingSamples } = require('../ml/modelTrainer');
const logger = require('../utils/logger');

const TRAINING_DIR = path.resolve(__dirname, '../../../database/training');
const BASELINE_TEMPLATE = 'training_regular_weeks_baseline.sql';
const ANOMALY_TEMPLATE = 'training_anomaly_injection.sql';
const BASELINE_TEMPLATE_START = '2026-02-02';
const MS_PER_DAY = 24 * 60 * 60 * 1000;

const TEMPLATE_MODES = {
    baseline: [BASELINE_TEMPLATE],
    anomalies: [ANOMALY_TEMPLATE],
    all: [BASELINE_TEMPLATE, ANOMALY_TEMPLATE]
};

const pad2 = (value) => String(value).padStart(2, '0');

const parseYmdUtc = (value) => {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || '').trim());
    if (!match) return null;

    const year = parseInt(match[1], 10);
    const month = parseInt(match[2], 10);
    const day = parseInt(match[3], 10);
    const date = new Date(Date.UTC(year, month - 1, day));

    if (
        Number.isNaN(date.getTime()) ||
        date.getUTCFullYear() !== year ||
        date.getUTCMonth() !== month - 1 ||
        date.getUTCDate() !== day
    ) {
        return null;
    }

    return date;
};

const formatYmdUtc = (date) => {
    return `${date.getUTCFullYear()}-${pad2(date.getUTCMonth() + 1)}-${pad2(date.getUTCDate())}`;
};

const startOfDayUtc = (date) => {
    return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
};

const addDaysUtc = (date, days) => {
    return new Date(startOfDayUtc(date).getTime() + days * MS_PER_DAY);
};

const diffDaysUtc = (laterDate, earlierDate) => {
    return Math.round((startOfDayUtc(laterDate) - startOfDayUtc(earlierDate)) / MS_PER_DAY);
};

const alignToMondayUtc = (date) => {
    const normalized = startOfDayUtc(date);
    const day = normalized.getUTCDay(); // Sunday=0, Monday=1
    const delta = (1 - day + 7) % 7;
    return addDaysUtc(normalized, delta);
};

const buildBatchCode = () => {
    const now = new Date();
    const yy = String(now.getUTCFullYear()).slice(-2);
    const mm = pad2(now.getUTCMonth() + 1);
    const dd = pad2(now.getUTCDate());
    const suffix = (now.getTime() % 1296).toString(36).toUpperCase().padStart(2, '0');
    return `RW${yy}${mm}${dd}${suffix}`;
};

const shiftYmd = (dateString, dayOffset) => {
    const parsed = parseYmdUtc(dateString);
    if (!parsed) {
        return dateString;
    }

    return formatYmdUtc(addDaysUtc(parsed, dayOffset));
};

const applyTemplateTransform = ({ sql, batchCode, dayOffset }) => {
    return sql
        .replace(/CUS-RW26-/g, `CUS-${batchCode}-`)
        .replace(/\b\d{4}-\d{2}-\d{2}\b/g, (match) => shiftYmd(match, dayOffset));
};

const toPositiveInt = (value, fallback) => {
    const parsed = parseInt(value, 10);
    return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
};

const resolveMode = (mode) => {
    const normalized = String(mode || 'all').toLowerCase();
    return TEMPLATE_MODES[normalized] ? normalized : null;
};

const resolveStartDate = async (requestedStartDate) => {
    if (requestedStartDate) {
        const parsed = parseYmdUtc(requestedStartDate);
        if (!parsed) {
            throw new Error('Invalid start_date. Expected format YYYY-MM-DD');
        }
        return alignToMondayUtc(parsed);
    }

    const result = await query(`
        SELECT MAX(issued_at)::date AS max_seeded_date
        FROM custody_records
        WHERE custody_id LIKE 'CUS-RW%'
    `);

    const maxSeededDate = result.rows[0]?.max_seeded_date;
    if (!maxSeededDate) {
        const fallback = addDaysUtc(startOfDayUtc(new Date()), -56);
        return alignToMondayUtc(fallback);
    }

    let parsed;
    if (maxSeededDate instanceof Date) {
        parsed = startOfDayUtc(maxSeededDate);
    } else {
        parsed = parseYmdUtc(String(maxSeededDate).slice(0, 10));
    }

    if (!parsed) {
        const fallback = addDaysUtc(startOfDayUtc(new Date()), -56);
        return alignToMondayUtc(fallback);
    }

    const nextDay = addDaysUtc(parsed, 1);
    return alignToMondayUtc(nextDay);
};

const countRowsForBatch = async (batchCode) => {
    const result = await query(
        `SELECT COUNT(*)::int AS count FROM custody_records WHERE custody_id LIKE $1`,
        [`CUS-${batchCode}-%`]
    );
    return toPositiveInt(result.rows[0]?.count, 0);
};

const extractFeaturesForBatch = async (batchCode) => {
    const pendingResult = await query(`
        SELECT cr.custody_id, cr.officer_id, cr.firearm_id, cr.unit_id,
               cr.issued_at, cr.returned_at, cr.custody_type,
               cr.duration_type,
               cr.custody_duration_seconds,
               cr.issue_hour, cr.issue_day_of_week,
               cr.is_night_issue, cr.is_weekend_issue
        FROM custody_records cr
        WHERE cr.custody_id LIKE $1
          AND NOT EXISTS (
              SELECT 1 FROM ml_training_features mf WHERE mf.custody_record_id = cr.custody_id
          )
        ORDER BY cr.issued_at ASC
    `, [`CUS-${batchCode}-%`], { query_timeout: 120000 });

    let extracted = 0;
    let failed = 0;

    for (const record of pendingResult.rows) {
        try {
            await extractAllFeatures(record);
            extracted++;
        } catch (error) {
            failed++;
        }
    }

    return {
        extracted,
        failed,
        pending_records: pendingResult.rows.length
    };
};

const getTrainingReadiness = async () => {
    const minimumRequiredSamples = getMinTrainingSamples();
    const samplesResult = await query(`
        SELECT COUNT(*)::int AS count
        FROM ml_training_features
        WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months'
    `);

    const availableTrainingSamples = toPositiveInt(samplesResult.rows[0]?.count, 0);

    return {
        minimum_required_samples: minimumRequiredSamples,
        available_training_samples: availableTrainingSamples,
        can_train: availableTrainingSamples >= minimumRequiredSamples
    };
};

const generateTrainingDataBatch = async (options = {}) => {
    const mode = resolveMode(options.mode || 'all');
    if (!mode) {
        throw new Error('Unsupported mode. Use one of: baseline, anomalies, all');
    }

    const extractFeatures = options.extractFeatures !== false;
    const startDate = await resolveStartDate(options.startDate);
    const batchCode = options.batchCode || buildBatchCode();
    const baseTemplateDate = parseYmdUtc(BASELINE_TEMPLATE_START);
    const dayOffset = diffDaysUtc(startDate, baseTemplateDate);

    logger.info(
        `Generating realistic training data batch ${batchCode} (mode=${mode}, start=${formatYmdUtc(startDate)}, offset=${dayOffset}d)`
    );

    for (const templateName of TEMPLATE_MODES[mode]) {
        const templatePath = path.join(TRAINING_DIR, templateName);
        if (!fs.existsSync(templatePath)) {
            throw new Error(`Training template not found: ${templatePath}`);
        }

        const templateSql = fs.readFileSync(templatePath, 'utf8');
        const transformedSql = applyTemplateTransform({
            sql: templateSql,
            batchCode,
            dayOffset
        });

        await query(transformedSql, [], { query_timeout: 120000 });
    }

    const seededRows = await countRowsForBatch(batchCode);

    let extraction = {
        extracted: 0,
        failed: 0,
        pending_records: 0
    };

    if (extractFeatures) {
        extraction = await extractFeaturesForBatch(batchCode);
    }

    const readiness = await getTrainingReadiness();

    return {
        status: 'completed',
        mode,
        batch_code: batchCode,
        cycle_start_date: formatYmdUtc(startDate),
        seeded_rows: seededRows,
        extracted_features: extraction.extracted,
        failed_feature_extractions: extraction.failed,
        ...readiness
    };
};

module.exports = {
    generateTrainingDataBatch
};
