-- =============================================================================
-- PI5 Control Center - Row Level Security (RLS) Policies
-- =============================================================================
-- Version: 4.0.0
-- Description: Security policies for multi-tenant Pi management
-- Usage: Execute after schema.sql
-- =============================================================================

-- =============================================================================
-- Enable RLS on all tables
-- =============================================================================

ALTER TABLE control_center.pis ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_center.installations ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_center.system_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE control_center.scheduled_tasks ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- Service Role Bypass (for backend API)
-- =============================================================================
-- Service role has full access (bypass RLS)
-- This is used by the Control Center backend via SERVICE_ROLE_KEY

-- Grant all permissions to service_role
GRANT ALL ON ALL TABLES IN SCHEMA control_center TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA control_center TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA control_center TO service_role;

-- =============================================================================
-- Authenticated Users Policies (Future: Web UI access)
-- =============================================================================
-- For now, we'll use service_role for all operations
-- In future, if you add user authentication to the Control Center web UI,
-- these policies will govern access based on user identity

-- Grant basic read access to authenticated users
GRANT SELECT ON ALL TABLES IN SCHEMA control_center TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA control_center TO authenticated;

-- =============================================================================
-- Table: pis - Policies
-- =============================================================================

-- Service role: Full access (no RLS restrictions)
CREATE POLICY "service_role_pis_all"
ON control_center.pis
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated: Read all Pis (future: filter by user ownership)
CREATE POLICY "authenticated_pis_select"
ON control_center.pis
FOR SELECT
TO authenticated
USING (true); -- Future: Add user_id column and filter

-- =============================================================================
-- Table: installations - Policies
-- =============================================================================

-- Service role: Full access
CREATE POLICY "service_role_installations_all"
ON control_center.installations
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated: Read installations for accessible Pis
CREATE POLICY "authenticated_installations_select"
ON control_center.installations
FOR SELECT
TO authenticated
USING (
    -- Can view installations for any Pi (future: join with pis ownership)
    EXISTS (
        SELECT 1 FROM control_center.pis
        WHERE pis.id = installations.pi_id
    )
);

-- =============================================================================
-- Table: system_stats - Policies
-- =============================================================================

-- Service role: Full access
CREATE POLICY "service_role_system_stats_all"
ON control_center.system_stats
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated: Read stats for accessible Pis
CREATE POLICY "authenticated_system_stats_select"
ON control_center.system_stats
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM control_center.pis
        WHERE pis.id = system_stats.pi_id
    )
);

-- =============================================================================
-- Table: scheduled_tasks - Policies
-- =============================================================================

-- Service role: Full access
CREATE POLICY "service_role_scheduled_tasks_all"
ON control_center.scheduled_tasks
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated: Read tasks for accessible Pis
CREATE POLICY "authenticated_scheduled_tasks_select"
ON control_center.scheduled_tasks
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM control_center.pis
        WHERE pis.id = scheduled_tasks.pi_id
    )
);

-- =============================================================================
-- Future: Multi-User Support
-- =============================================================================
-- When adding user authentication, add these columns and update policies:
--
-- ALTER TABLE control_center.pis ADD COLUMN user_id UUID REFERENCES auth.users(id);
-- ALTER TABLE control_center.pis ADD COLUMN organization_id UUID;
--
-- Then update policies to filter by:
-- USING (user_id = auth.uid() OR organization_id IN (
--   SELECT organization_id FROM user_organizations WHERE user_id = auth.uid()
-- ))

-- =============================================================================
-- Security Notes
-- =============================================================================
-- 1. Current Setup: Service role has full access (backend only)
-- 2. Authenticated policies prepared for future web UI with user login
-- 3. No public access (anon role has no policies)
-- 4. All tables protected by RLS, but service_role bypasses RLS
-- 5. For production: Add user_id/organization_id columns for multi-tenancy
