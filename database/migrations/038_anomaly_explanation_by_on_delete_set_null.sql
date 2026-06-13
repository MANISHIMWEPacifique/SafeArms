-- Migration 038: Preserve anomaly explanation history when the explaining user is deleted.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'anomalies'
          AND column_name = 'explanation_by'
    ) THEN
        ALTER TABLE anomalies
            DROP CONSTRAINT IF EXISTS anomalies_explanation_by_fkey;

        ALTER TABLE anomalies
            ADD CONSTRAINT anomalies_explanation_by_fkey
            FOREIGN KEY (explanation_by)
            REFERENCES users(user_id)
            ON DELETE SET NULL;
    END IF;
END $$;
