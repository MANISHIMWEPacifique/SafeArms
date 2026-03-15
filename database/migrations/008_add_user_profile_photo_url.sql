-- Migration 008: Add users profile photo URL column
-- Stores optional profile photo path for uploaded user avatars

ALTER TABLE users
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;
