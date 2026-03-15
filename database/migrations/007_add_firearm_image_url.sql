-- Migration 007: Add firearm image URL column
-- Adds optional single image field used as firearm visual indicator

ALTER TABLE firearms
ADD COLUMN IF NOT EXISTS image_url TEXT;
