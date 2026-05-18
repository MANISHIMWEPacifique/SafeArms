-- Migration 026: Lockdown Supabase Data API
-- Enables Row-Level Security on all tables in the public schema 
-- to satisfy the Supabase Security Advisor and prevent unauthorized API access.

DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
        EXECUTE 'ALTER TABLE public.' || quote_ident(r.tablename) || ' ENABLE ROW LEVEL SECURITY;';
    END LOOP;
END;
$$;
