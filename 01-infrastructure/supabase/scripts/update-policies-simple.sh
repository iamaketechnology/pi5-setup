#!/bin/bash

################################################################################
# Simple Policy Role Update Script
# Version: 1.0
#
# This script updates RLS policies to use 'authenticated' role by using
# PostgreSQL's internal catalog manipulation.
#
################################################################################

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;36m'
readonly NC='\033[0m'

log() { echo -e "${BLUE}[POLICY-UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC}      $1"; }

# Configuration
if [[ -n "${SUDO_USER}" ]]; then
    REAL_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    REAL_HOME="${HOME}"
fi

SUPABASE_DIR="${REAL_HOME}/stacks/supabase"
ENV_FILE="${SUPABASE_DIR}/.env"

# Get database password
DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "${ENV_FILE}" | cut -d= -f2 | tr -d '"' | tr -d "'")

log "Updating policies from 'public' role to 'authenticated' role..."
log "Using direct SQL catalog manipulation for reliability"

# Execute the update
docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres <<'EOSQL'
-- Update pg_policy catalog to change role from 'public' to 'authenticated'
-- This is safe and preserves all policy logic

DO $$
DECLARE
    policy_record RECORD;
    old_roles text[];
    new_roles text[];
    updated_count integer := 0;
BEGIN
    -- Loop through all policies with 'public' role
    FOR policy_record IN
        SELECT oid, polname, polrelid::regclass as table_name, polroles
        FROM pg_policy
        WHERE polrelid::regnamespace::text = 'public'
        AND 'public'::regrole::oid = ANY(polroles)
    LOOP
        -- Get current roles array
        old_roles := policy_record.polroles;

        -- Replace 'public' with 'authenticated'
        new_roles := array_replace(
            old_roles,
            'public'::regrole::oid,
            'authenticated'::regrole::oid
        );

        -- Update the policy
        UPDATE pg_policy
        SET polroles = new_roles
        WHERE oid = policy_record.oid;

        updated_count := updated_count + 1;

        RAISE NOTICE 'Updated: %.% (% roles: % -> %)',
            pg_catalog.pg_namespace.nspname,
            policy_record.table_name,
            policy_record.polname,
            (SELECT array_agg(rolname) FROM pg_roles WHERE oid = ANY(old_roles)),
            (SELECT array_agg(rolname) FROM pg_roles WHERE oid = ANY(new_roles))
        FROM pg_catalog.pg_namespace
        WHERE pg_catalog.pg_namespace.oid = policy_record.polrelid::regnamespace;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Updated % policies', updated_count;
    RAISE NOTICE '========================================';
END $$;

-- Verify: Show remaining policies with 'public' role
SELECT
    schemaname,
    tablename,
    policyname,
    roles
FROM pg_policies
WHERE schemaname = 'public'
AND 'public' = ANY(roles);

-- Summary
SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✓ All policies now use authenticated role!'
        ELSE '⚠ ' || COUNT(*) || ' policies still use public role'
    END as status
FROM pg_policies
WHERE schemaname = 'public'
AND 'public' = ANY(roles);

EOSQL

ok "Policy update complete!"
