-- Migration 031: Explicit archive lifecycle for retained anomaly records
-- Archive replaces dashboard-delete wording while preserving all anomaly history.

ALTER TABLE anomalies
    ADD COLUMN IF NOT EXISTS archived_at TIMESTAMP,
    ADD COLUMN IF NOT EXISTS archived_by VARCHAR(20) REFERENCES users(user_id),
    ADD COLUMN IF NOT EXISTS archive_note TEXT;

ALTER TABLE anomalies DROP CONSTRAINT IF EXISTS anomalies_status_check;
ALTER TABLE anomalies ADD CONSTRAINT anomalies_status_check
    CHECK (status IN (
        'open',
        'pending',
        'investigating',
        'resolved',
        'false_positive',
        'acceptable_change',
        'archived'
    ));

UPDATE anomalies
SET archived_at = COALESCE(archived_at, removed_from_dashboard_at),
    archived_by = COALESCE(archived_by, removed_from_dashboard_by),
    archive_note = COALESCE(archive_note, removed_from_dashboard_reason),
    status = CASE
        WHEN COALESCE(removed_from_dashboard, false) = true THEN 'archived'
        ELSE status
    END
WHERE COALESCE(removed_from_dashboard, false) = true;

CREATE INDEX IF NOT EXISTS idx_anomalies_archived_at
    ON anomalies(archived_at);

CREATE INDEX IF NOT EXISTS idx_anomalies_active_status
    ON anomalies(status, detected_at DESC)
    WHERE archived_at IS NULL AND COALESCE(removed_from_dashboard, false) = false;
