/**
 * Detect anomalies for deterministic seeded custody records.
 *
 * Usage:
 *   node src/scripts/detectSeededAnomalies.js
 */

require('dotenv').config();
const { pool, query } = require('../config/database');
const { detectAnomaly } = require('../ml/anomalyDetector');

const run = async () => {
    console.log('='.repeat(70));
    console.log('SafeArms Seeded Anomaly Detection Runner');
    console.log('='.repeat(70));

    try {
        const recordsResult = await query(`
            SELECT
                custody_id,
                officer_id,
                firearm_id,
                unit_id,
                issued_at,
                returned_at,
                custody_type,
                duration_type,
                custody_duration_seconds,
                issue_hour,
                issue_day_of_week,
                is_night_issue,
                is_weekend_issue
            FROM custody_records
                        WHERE custody_id LIKE 'CUS-RW26-A%'
                            AND NOT EXISTS (
                                    SELECT 1
                                    FROM anomalies a
                                    WHERE a.custody_record_id = custody_records.custody_id
                            )
            ORDER BY issued_at ASC
        `, [], { query_timeout: 120000 });

        const records = recordsResult.rows;
        console.log(`[INFO] Seeded anomaly candidates found: ${records.length}`);

        let anomaliesDetected = 0;
        for (const record of records) {
            try {
                const result = await detectAnomaly(record);
                if (result.is_anomaly) {
                    anomaliesDetected++;
                }
                process.stdout.write(`\rProcessed ${anomaliesDetected}/${records.length} anomalies so far`);
            } catch (error) {
                // Continue on per-record failures.
            }
        }

        const dbCountResult = await query(`
            SELECT COUNT(*) AS count
            FROM anomalies a
            WHERE EXISTS (
                SELECT 1
                FROM custody_records cr
                WHERE cr.custody_id = a.custody_record_id
                  AND cr.custody_id LIKE 'CUS-RW26-A%'
            )
        `);

        console.log('\n');
        console.log('[DONE] Seeded anomaly detection completed.');
        console.log(`[INFO] New anomalies linked to CUS-RW26-A%% records: ${dbCountResult.rows[0].count}`);
    } catch (error) {
        console.error(`[ERROR] ${error.message}`);
        process.exitCode = 1;
    } finally {
        await pool.end();
    }
};

run().catch((error) => {
    console.error(`[FATAL] ${error.message}`);
    process.exit(1);
});
