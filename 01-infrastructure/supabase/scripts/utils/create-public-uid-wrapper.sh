#!/bin/bash
# =============================================================================
# CREATE PUBLIC.UID() WRAPPER - Temporary workaround for RLS policies
# =============================================================================
#
# Purpose: Create a public.uid() function that wraps auth.uid()
#          This is a TEMPORARY workaround if you cannot modify PostgREST config
#
# Author: Claude Code Assistant
# Version: 1.0
# Date: 2025-10-10
#
# Usage: ./create-public-uid-wrapper.sh
#
# IMPORTANT: This is a workaround! The PROPER fix is to update PostgREST
#            configuration using: ./fix-postgrest-schemas.sh
#
# =============================================================================

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Configuration
readonly STACK_DIR="${STACK_DIR:-$HOME/stacks/supabase}"
readonly ENV_FILE="$STACK_DIR/.env"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

check_prerequisites() {
    log "🔍 Checking prerequisites..."

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found: $ENV_FILE"
    fi

    # Load environment
    set -a
    source "$ENV_FILE"
    set +a

    if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
        error "POSTGRES_PASSWORD not found in $ENV_FILE"
    fi

    ok "✅ Prerequisites OK"
}

show_warning() {
    echo ""
    warn "╔════════════════════════════════════════════════════════════╗"
    warn "║  IMPORTANT: This is a TEMPORARY workaround!               ║"
    warn "╚════════════════════════════════════════════════════════════╝"
    echo ""
    warn "The PROPER solution is to fix PostgREST configuration:"
    warn "  ./fix-postgrest-schemas.sh"
    echo ""
    warn "This script creates a wrapper function public.uid() that"
    warn "calls auth.uid(). This works but is not the recommended approach."
    echo ""

    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Operation cancelled"
        log "Please run: ./fix-postgrest-schemas.sh instead"
        exit 0
    fi
}

create_uid_wrapper() {
    log "🔧 Creating public.uid() wrapper function..."

    local sql="
-- =============================================================================
-- PUBLIC.UID() WRAPPER FUNCTION
-- =============================================================================
-- This function wraps auth.uid() to make it accessible from the public schema
-- This is a WORKAROUND - the proper fix is to configure PostgREST schemas

CREATE OR REPLACE FUNCTION public.uid()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS \$\$
  SELECT COALESCE(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    (nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')
  )::uuid
\$\$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.uid() TO anon, authenticated, service_role;

-- Add comment
COMMENT ON FUNCTION public.uid() IS 'Wrapper for auth.uid() - TEMPORARY workaround until PostgREST schemas are fixed';
"

    echo ""
    log "Executing SQL..."
    echo ""
    echo -e "${CYAN}$sql${NC}"
    echo ""

    if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$sql" 2>&1 | tee /tmp/uid-wrapper.log; then
        ok "✅ Function created successfully"
    else
        error "❌ Failed to create function. See /tmp/uid-wrapper.log for details"
    fi
}

verify_function() {
    log "✅ Verifying function..."

    local test_sql="SELECT public.uid();"

    echo ""
    log "Executing test query: $test_sql"

    if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$test_sql" 2>&1 | grep -q "public.uid"; then
        ok "✅ public.uid() function is accessible!"
    else
        warn "⚠️  Could not verify public.uid() function"
    fi

    echo ""
}

update_rls_policies_info() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  How to use this workaround in RLS policies              ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${YELLOW}Instead of using auth.uid(), use public.uid():${NC}"
    echo ""

    cat << 'EOF'
-- ❌ BEFORE (won't work with PostgREST if auth schema not in PGRST_DB_SCHEMAS)
CREATE POLICY "Users can view own data"
ON public.users FOR SELECT TO authenticated
USING (user_id = auth.uid());

-- ✅ AFTER (works with this workaround)
CREATE POLICY "Users can view own data"
ON public.users FOR SELECT TO authenticated
USING (user_id = public.uid());
EOF

    echo ""
}

show_next_steps() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Next Steps                                                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo "1. Update your RLS policies to use public.uid() instead of auth.uid()"
    echo ""
    echo "2. Generate new templates with the fix:"
    echo "   ./generate-rls-template.sh your_table --basic"
    echo "   # Then manually replace auth.uid() with public.uid()"
    echo ""
    echo "3. Test your policies:"
    echo "   ./diagnose-rls.sh your_table"
    echo ""
    echo "4. IMPORTANT: When possible, apply the PROPER fix:"
    echo "   ./fix-postgrest-schemas.sh"
    echo "   # This is the recommended long-term solution"
    echo ""

    ok "✅ Workaround applied successfully!"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Create public.uid() Wrapper (Temporary Workaround)       ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    check_prerequisites
    show_warning
    create_uid_wrapper
    verify_function
    update_rls_policies_info
    show_next_steps
}

main "$@"
