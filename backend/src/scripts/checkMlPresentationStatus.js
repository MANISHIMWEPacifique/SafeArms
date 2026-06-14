/**
 * Print the live ML/anomaly state for presentation readiness checks.
 *
 * Run with:
 *   node src/scripts/checkMlPresentationStatus.js
 */

require('dotenv').config();
const { pool, query } = require('../config/database');

const main = async () => {
    const activeModel = await query(`
        SELECT model_id,
               training_samples_count,
               num_clusters,
               ROUND(silhouette_score::numeric, 4) AS silhouette_score,
               ROUND(outlier_threshold::numeric, 4) AS outlier_threshold,
               training_date
        FROM ml_model_metadata
        WHERE model_type = 'kmeans'
          AND is_active = true
        ORDER BY training_date DESC
        LIMIT 1
    `);

    const activeModelCount = await query(`
        SELECT COUNT(*)::int AS active_count
        FROM ml_model_metadata
        WHERE model_type = 'kmeans'
          AND is_active = true
    `);

    const anomalyReview = await query(`
        SELECT COUNT(*)::int AS total,
               COUNT(*) FILTER (WHERE status = 'false_positive')::int AS false_positives,
               COUNT(*) FILTER (WHERE status IN ('resolved', 'false_positive', 'acceptable_change'))::int AS reviewed,
               COUNT(*) FILTER (WHERE status IN ('open', 'pending', 'investigating'))::int AS pending_review,
               COUNT(*) FILTER (WHERE status = 'archived')::int AS archived
        FROM anomalies
    `);

    const severity = await query(`
        SELECT severity, COUNT(*)::int AS count
        FROM anomalies
        WHERE status != 'archived'
        GROUP BY severity
        ORDER BY severity
    `);

    const sequences = await query(`
        SELECT 'anomalies_id_seq' AS sequence_name, last_value, is_called
        FROM anomalies_id_seq
        UNION ALL
        SELECT 'anomaly_investigations_id_seq' AS sequence_name, last_value, is_called
        FROM anomaly_investigations_id_seq
    `);

    console.log(JSON.stringify({
        active_model: activeModel.rows[0] || null,
        active_model_count: activeModelCount.rows[0]?.active_count || 0,
        anomaly_review: anomalyReview.rows[0] || {},
        severity: severity.rows,
        sequences: sequences.rows
    }, null, 2));
};

main()
    .catch((error) => {
        console.error(error);
        process.exitCode = 1;
    })
    .finally(async () => {
        await pool.end();
    });
