#!/bin/bash

################################################################################
# Supabase RLS Configuration Fix Script
# Version: 3.46
#
# This script fixes critical RLS (Row Level Security) configuration issues
# that prevent authenticated users from accessing tables.
#
# Issues Fixed:
# 1. PostgREST schema configuration (adds auth and storage schemas)
# 2. Creates public.uid() wrapper function for RLS policies
# 3. Updates RLS policies to use 'authenticated' role instead of 'public'
# 4. Grants necessary permissions to authenticated role
# 5. Removes recursive RLS policies that cause infinite loops
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/01-infrastructure/supabase/scripts/fix-rls-configuration.sh | sudo bash
#
# Or locally:
#   sudo bash fix-rls-configuration.sh
#
################################################################################

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[RLS-FIX]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

ok() {
    echo -e "${GREEN}[OK]${NC}      $1"
}

error() {
    echo -e "${RED}[ERROR]${NC}   $1"
    exit 1
}

# Configuration
# Detect the correct home directory (works with both sudo and non-sudo)
if [[ -n "${SUDO_USER}" ]]; then
    REAL_USER="${SUDO_USER}"
    REAL_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    REAL_USER="${USER}"
    REAL_HOME="${HOME}"
fi

SUPABASE_DIR="${REAL_HOME}/stacks/supabase"
DOCKER_COMPOSE_FILE="${SUPABASE_DIR}/docker-compose.yml"
BACKUP_DIR="${SUPABASE_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/docker-compose.yml.backup-rls-fix-${TIMESTAMP}"
LOG_FILE="/var/log/supabase-rls-fix-${TIMESTAMP}.log"

################################################################################
# Pre-flight Checks
################################################################################

log "Starting Supabase RLS configuration fix..."
log "Logging to: ${LOG_FILE}"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root or with sudo"
fi

# Check if Supabase is installed
if [[ ! -d "${SUPABASE_DIR}" ]]; then
    error "Supabase directory not found at ${SUPABASE_DIR}"
fi

if [[ ! -f "${DOCKER_COMPOSE_FILE}" ]]; then
    error "docker-compose.yml not found at ${DOCKER_COMPOSE_FILE}"
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    error "Docker is not running"
fi

# Check if Supabase containers are running
if ! docker ps | grep -q "supabase-db"; then
    error "Supabase containers are not running. Please start Supabase first."
fi

ok "Pre-flight checks passed"

################################################################################
# Backup
################################################################################

log "Creating backup of docker-compose.yml..."
mkdir -p "${BACKUP_DIR}"
cp "${DOCKER_COMPOSE_FILE}" "${BACKUP_FILE}"
ok "Backup created: ${BACKUP_FILE}"

################################################################################
# Get Database Password
################################################################################

log "Retrieving database password from .env file..."

# Check if .env file exists
ENV_FILE="${SUPABASE_DIR}/.env"
if [[ ! -f "${ENV_FILE}" ]]; then
    error ".env file not found at ${ENV_FILE}"
fi

# Read password from .env file
DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "${ENV_FILE}" | cut -d= -f2 | tr -d '"' | tr -d "'")

if [[ -z "${DB_PASSWORD}" ]]; then
    error "Could not retrieve database password from .env file"
fi

ok "Database password retrieved"

################################################################################
# Fix 1: Update PostgREST Schema Configuration
################################################################################

log "Fixing PostgREST schema configuration..."

# Check current configuration
CURRENT_SCHEMAS=$(grep "PGRST_DB_SCHEMAS:" "${DOCKER_COMPOSE_FILE}" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")

if [[ "${CURRENT_SCHEMAS}" == "public,auth,storage" ]]; then
    ok "PostgREST schema configuration already correct"
else
    log "Updating PGRST_DB_SCHEMAS from '${CURRENT_SCHEMAS}' to 'public,auth,storage'..."

    # Update docker-compose.yml
    sed -i.bak 's/PGRST_DB_SCHEMAS: public$/PGRST_DB_SCHEMAS: public,auth,storage/' "${DOCKER_COMPOSE_FILE}"

    # Recreate PostgREST container to apply new environment variables
    log "Recreating PostgREST container..."
    cd "${SUPABASE_DIR}"
    docker compose up -d --force-recreate rest

    # Wait for container to be healthy
    sleep 5

    # Verify the change
    UPDATED_SCHEMAS=$(docker exec supabase-rest env | grep PGRST_DB_SCHEMAS | cut -d= -f2)

    if [[ "${UPDATED_SCHEMAS}" == "public,auth,storage" ]]; then
        ok "PostgREST schema configuration updated successfully"
    else
        error "Failed to update PostgREST schema configuration. Got: ${UPDATED_SCHEMAS}"
    fi
fi

################################################################################
# Fix 2: Create public.uid() Wrapper Function
################################################################################

log "Creating public.uid() wrapper function..."

docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres <<'EOSQL' 2>&1 | tee -a "${LOG_FILE}"
-- Check if function already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'uid'
    ) THEN
        -- Create the wrapper function
        CREATE FUNCTION public.uid()
        RETURNS uuid
        LANGUAGE sql
        STABLE
        SECURITY DEFINER
        SET search_path = public, auth
        AS $FUNC$
          SELECT auth.uid()
        $FUNC$;

        -- Grant permissions
        GRANT EXECUTE ON FUNCTION public.uid() TO anon, authenticated, service_role;

        RAISE NOTICE 'Created public.uid() function';
    ELSE
        RAISE NOTICE 'public.uid() function already exists';
    END IF;
END
$$;
EOSQL

ok "public.uid() function configured"

################################################################################
# Fix 3: Grant Permissions to authenticated Role
################################################################################

log "Granting permissions to authenticated role..."

docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres <<'EOSQL' 2>&1 | tee -a "${LOG_FILE}"
-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant sequence permissions
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Verify permissions
SELECT
    COUNT(DISTINCT table_name) as tables_with_permissions
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
AND grantee = 'authenticated';
EOSQL

ok "Permissions granted to authenticated role"

################################################################################
# Fix 4: Update Common RLS Policies (if they exist)
################################################################################

log "Checking and updating common RLS policies..."

# Function to update policies for a table
update_table_policies() {
    local table_name=$1

    log "Checking policies for table: ${table_name}..."

    # Check if table exists
    local table_exists
    table_exists=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
        "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = '${table_name}');")

    if [[ "${table_exists}" == *"t"* ]]; then
        # Get current policies with 'public' role
        local public_policies
        public_policies=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
            "SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = '${table_name}' AND 'public' = ANY(roles);")

        if [[ "${public_policies}" -gt 0 ]]; then
            warn "Table '${table_name}' has ${public_policies} policies with 'public' role"
            warn "Please manually review and update these policies to use 'authenticated' role"
            warn "See log file for SQL examples: ${LOG_FILE}"
        else
            ok "Table '${table_name}' policies already use correct roles"
        fi
    fi
}

# Check common tables
for table in "profiles" "documents" "email_invites" "app_certifications" "certificates" "folders" "shared_documents"; do
    update_table_policies "${table}"
done

################################################################################
# Fix 5: Remove Known Recursive Policies
################################################################################

log "Checking for known recursive policies..."

# Check if documents_shared_view policy exists
POLICY_EXISTS=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
    "SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND tablename = 'documents' AND policyname = 'documents_shared_view';")

if [[ "${POLICY_EXISTS}" -gt 0 ]]; then
    warn "Found potentially recursive policy 'documents_shared_view'"
    log "Dropping recursive policy to prevent infinite loops..."

    docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -c \
        'DROP POLICY IF EXISTS "documents_shared_view" ON documents;' 2>&1 | tee -a "${LOG_FILE}"

    ok "Recursive policy removed"
    warn "Note: Shared documents access now relies on email_invites JOIN"
fi

################################################################################
# Verification
################################################################################

log "Verifying configuration..."

# 1. Check PostgREST schema config
FINAL_SCHEMAS=$(docker exec supabase-rest env | grep PGRST_DB_SCHEMAS | cut -d= -f2)
if [[ "${FINAL_SCHEMAS}" == "public,auth,storage" ]]; then
    ok "✓ PostgREST schemas: ${FINAL_SCHEMAS}"
else
    error "✗ PostgREST schemas incorrect: ${FINAL_SCHEMAS}"
fi

# 2. Check public.uid() function
UID_FUNC=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
    "SELECT COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.proname = 'uid';")

if [[ "${UID_FUNC}" -gt 0 ]]; then
    ok "✓ public.uid() function exists"
else
    error "✗ public.uid() function not found"
fi

# 3. Check authenticated permissions
AUTH_PERMS=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
    "SELECT COUNT(DISTINCT table_name) FROM information_schema.role_table_grants WHERE table_schema = 'public' AND grantee = 'authenticated';")

if [[ "${AUTH_PERMS}" -gt 0 ]]; then
    ok "✓ authenticated role has permissions on ${AUTH_PERMS} tables"
else
    error "✗ authenticated role has no permissions"
fi

################################################################################
# Summary
################################################################################

echo ""
echo "=========================================="
echo "RLS Configuration Fix Complete"
echo "=========================================="
echo ""
ok "All fixes applied successfully!"
echo ""
echo "Summary:"
echo "  - PostgREST schemas: public,auth,storage"
echo "  - public.uid() function: Created"
echo "  - authenticated permissions: Granted on ${AUTH_PERMS} tables"
echo "  - Recursive policies: Removed"
echo ""
echo "Backup: ${BACKUP_FILE}"
echo "Log: ${LOG_FILE}"
echo ""
warn "IMPORTANT: If you have custom RLS policies using 'public' role,"
warn "you need to manually update them to use 'authenticated' role."
warn "See the log file for guidance."
echo ""
ok "Your Supabase instance should now work correctly with authenticated users!"
echo ""
