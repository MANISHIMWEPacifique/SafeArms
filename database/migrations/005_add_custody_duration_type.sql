-- Migration 005: Add custody duration type for temporary assignments
-- Supports real police activity durations: 6 hours, 8 hours, 12 hours, 1 day
-- 
-- In real police operations, temporary firearm custody follows shift-based
-- durations rather than arbitrary date selection.

-- Add duration_type column to custody_records
ALTER TABLE custody_records 
ADD COLUMN IF NOT EXISTS duration_type VARCHAR(20) 
CHECK (duration_type IN ('6_hours', '8_hours', '12_hours', '1_day'));

-- Change expected_return_date from DATE to TIMESTAMP for sub-day precision
-- This allows hour-level expected return times
ALTER TABLE custody_records 
ALTER COLUMN expected_return_date TYPE TIMESTAMP USING expected_return_date::TIMESTAMP;

-- Add index on duration_type for filtering
CREATE INDEX IF NOT EXISTS idx_custody_duration_type ON custody_records(duration_type) WHERE duration_type IS NOT NULL;

-- Add composite index for overdue checks (active temporary records with expected return)
CREATE INDEX IF NOT EXISTS idx_custody_overdue_check ON custody_records(expected_return_date, returned_at) 
WHERE returned_at IS NULL AND expected_return_date IS NOT NULL;

COMMENT ON COLUMN custody_records.duration_type IS 'Duration type for temporary custody: 6_hours, 8_hours, 12_hours, 1_day. Only applicable when custody_type = temporary.';
