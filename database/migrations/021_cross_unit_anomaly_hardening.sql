-- Migration 021: Cross-unit anomaly hardening and investigation decision traceability
-- 1) Preserve acceptable_change as an explicit investigation outcome
-- 2) Add index support for latest investigation trace lookups

DO $$
DECLARE
    constraint_record RECORD;
BEGIN
    FOR constraint_record IN
        SELECT con.conname
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = rel.relnamespace
        WHERE nsp.nspname = 'public'
          AND rel.relname = 'anomaly_investigations'
          AND con.contype = 'c'
          AND pg_get_constraintdef(con.oid) ILIKE '%outcome%'
    LOOP
        EXECUTE format(
            'ALTER TABLE anomaly_investigations DROP CONSTRAINT %I',
            constraint_record.conname
        );
    END LOOP;
END $$;

ALTER TABLE anomaly_investigations
    ADD CONSTRAINT anomaly_investigations_outcome_check
    CHECK (
        outcome IN (
            'confirmed',
            'false_positive',
            'needs_further_review',
            'acceptable_change'
        )
    );

CREATE INDEX IF NOT EXISTS idx_anomaly_investigations_anomaly_date
    ON anomaly_investigations (anomaly_id, investigation_date DESC, created_at DESC);
