-- Migration 027: Optimize officer verification queries

-- Add index on decision and expires_at to optimize expireStaleRequests
CREATE INDEX IF NOT EXISTS idx_officer_verification_requests_decision_expires_at
ON officer_verification_requests (decision, expires_at);

-- Add index on decision and created_at to optimize cleanup jobs
CREATE INDEX IF NOT EXISTS idx_officer_verification_requests_decision_created_at
ON officer_verification_requests (decision, created_at);
