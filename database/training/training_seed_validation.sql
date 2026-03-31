-- SafeArms training seed validation checks
-- Run after baseline + anomaly injection + feature extraction.

-- 1) Verify custody seed volumes by seed class
SELECT
    COUNT(*) FILTER (WHERE custody_id LIKE 'CUS-RW26-B%') AS baseline_weekday_rows,
    COUNT(*) FILTER (WHERE custody_id LIKE 'CUS-RW26-W%') AS baseline_weekend_rows,
    COUNT(*) FILTER (WHERE custody_id LIKE 'CUS-RW26-N%') AS baseline_night_rows,
    COUNT(*) FILTER (WHERE custody_id LIKE 'CUS-RW26-A%') AS anomaly_injection_rows,
    COUNT(*) FILTER (WHERE custody_id LIKE 'CUS-RW26-%') AS total_seeded_rows
FROM custody_records;

-- 2) Distribution sanity by unit
SELECT unit_id, COUNT(*) AS seeded_rows
FROM custody_records
WHERE custody_id LIKE 'CUS-RW26-%'
GROUP BY unit_id
ORDER BY seeded_rows DESC;

-- 3) Duration sanity (hours)
SELECT
    ROUND(MIN(custody_duration_seconds) / 3600.0, 2) AS min_hours,
    ROUND(AVG(custody_duration_seconds) / 3600.0, 2) AS avg_hours,
    ROUND(MAX(custody_duration_seconds) / 3600.0, 2) AS max_hours
FROM custody_records
WHERE custody_id LIKE 'CUS-RW26-%'
  AND custody_duration_seconds IS NOT NULL;

-- 4) Confirm excessive transfer anomaly setup (>6 on same day for one firearm)
SELECT firearm_id, issued_at::date AS duty_date, COUNT(*) AS transfers
FROM custody_records
WHERE custody_id LIKE 'CUS-RW26-A00%'
  AND firearm_id = 'FA-020'
GROUP BY firearm_id, issued_at::date;

-- 5) Confirm short and extended duration anomaly setup
SELECT custody_id, custody_duration_seconds, ROUND(custody_duration_seconds / 3600.0, 2) AS duration_hours
FROM custody_records
WHERE custody_id IN ('CUS-RW26-A009', 'CUS-RW26-A010')
ORDER BY custody_id;

-- 6) Feature extraction coverage for seeded custody records
SELECT
    COUNT(*) AS seeded_rows,
    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM ml_training_features mf
            WHERE mf.custody_record_id = cr.custody_id
        )
    ) AS seeded_rows_with_features,
    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM ml_training_features mf
            WHERE mf.custody_record_id = cr.custody_id
        )
    ) AS seeded_rows_missing_features
FROM custody_records cr
WHERE cr.custody_id LIKE 'CUS-RW26-%';

-- 7) Overall training readiness snapshot (last 6 months)
SELECT
    COUNT(*) AS available_training_samples,
    MIN(feature_extraction_date) AS earliest_feature_timestamp,
    MAX(feature_extraction_date) AS latest_feature_timestamp
FROM ml_training_features
WHERE feature_extraction_date >= CURRENT_TIMESTAMP - INTERVAL '6 months';

-- 8) Anomaly detections generated from seeded rows (after detector run)
SELECT
    COUNT(*) AS detected_anomalies_from_seed,
    COUNT(*) FILTER (WHERE severity = 'critical') AS critical_count,
    COUNT(*) FILTER (WHERE severity = 'high') AS high_count,
    COUNT(*) FILTER (WHERE severity = 'medium') AS medium_count,
    COUNT(*) FILTER (WHERE severity = 'low') AS low_count
FROM anomalies a
WHERE EXISTS (
    SELECT 1
    FROM custody_records cr
    WHERE cr.custody_id = a.custody_record_id
      AND cr.custody_id LIKE 'CUS-RW26-%'
);
