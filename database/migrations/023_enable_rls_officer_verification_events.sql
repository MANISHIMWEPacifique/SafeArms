-- Enable RLS on officer_verification_events to satisfy Supabase security advisor.
-- Since the Node.js backend connects as a superuser and handles all validation,
-- enabling RLS with no policies effectively blocks direct public API access 
-- without affecting normal backend operations.

ALTER TABLE public.officer_verification_events ENABLE ROW LEVEL SECURITY;
