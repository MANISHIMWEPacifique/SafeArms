-- Migration 041: Optimize anomaly and investigation ID generation.
-- Avoids MAX(...) scans during anomaly detection and review actions.

CREATE SEQUENCE IF NOT EXISTS anomalies_id_seq START 1;
CREATE SEQUENCE IF NOT EXISTS anomaly_investigations_id_seq START 1;

SELECT setval(
    'anomalies_id_seq',
    COALESCE(
        (
            SELECT MAX(
                CAST(NULLIF(REGEXP_REPLACE(anomaly_id, '[^0-9]', '', 'g'), '') AS INTEGER)
            )
            FROM anomalies
        ),
        0
    ) + 1,
    false
);

SELECT setval(
    'anomaly_investigations_id_seq',
    COALESCE(
        (
            SELECT MAX(
                CAST(NULLIF(REGEXP_REPLACE(investigation_id, '[^0-9]', '', 'g'), '') AS INTEGER)
            )
            FROM anomaly_investigations
        ),
        0
    ) + 1,
    false
);
