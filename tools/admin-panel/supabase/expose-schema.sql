-- =============================================================================
-- Expose control_center schema to PostgREST API
-- =============================================================================
-- This script grants necessary permissions for the control_center schema
-- to be accessible via Supabase REST API (PostgREST)
-- =============================================================================

-- Grant schema usage to anon and authenticated roles
GRANT USAGE ON SCHEMA control_center TO anon, authenticated;

-- Grant table permissions to anon and authenticated
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA control_center TO anon, authenticated;

-- Grant sequence permissions (for auto-increment IDs)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA control_center TO anon, authenticated;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA control_center
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO anon, authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA control_center
GRANT USAGE, SELECT ON SEQUENCES TO anon, authenticated;

-- Notify success
DO $$
BEGIN
    RAISE NOTICE '✅ Schema control_center exposed to PostgREST API';
    RAISE NOTICE '   - Granted USAGE on schema to anon, authenticated';
    RAISE NOTICE '   - Granted table permissions to anon, authenticated';
    RAISE NOTICE '   - Set default privileges for future objects';
END $$;
