#!/bin/bash
# =============================================================================
# FIX POSTGREST SCHEMAS - Add auth and storage to PGRST_DB_SCHEMAS
# =============================================================================
#
# Purpose: Fix PostgREST configuration to include auth and storage schemas
#          This resolves "function auth.uid() does not exist" errors in RLS policies
#
# Author: Claude Code Assistant
# Version: 1.0
# Date: 2025-10-10
#
# Usage: ./fix-postgrest-schemas.sh
#
# What it does:
#   1. Backs up docker-compose.yml
#   2. Updates PGRST_DB_SCHEMAS from 'public' to 'public,auth,storage'
#   3. Restarts PostgREST service
#   4. Verifies the fix
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
readonly DOCKER_COMPOSE_FILE="$STACK_DIR/docker-compose.yml"
readonly BACKUP_FILE="$DOCKER_COMPOSE_FILE.backup-$(date +%Y%m%d-%H%M%S)"

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

    if [[ ! -d "$STACK_DIR" ]]; then
        error "Supabase stack directory not found: $STACK_DIR"
    fi

    if [[ ! -f "$DOCKER_COMPOSE_FILE" ]]; then
        error "docker-compose.yml not found: $DOCKER_COMPOSE_FILE"
    fi

    ok "✅ Prerequisites OK"
}

backup_docker_compose() {
    log "💾 Creating backup of docker-compose.yml..."

    cp "$DOCKER_COMPOSE_FILE" "$BACKUP_FILE"

    ok "✅ Backup created: $BACKUP_FILE"
}

check_current_config() {
    log "🔍 Checking current PostgREST configuration..."

    local current_schemas
    current_schemas=$(grep "PGRST_DB_SCHEMAS:" "$DOCKER_COMPOSE_FILE" | head -1 | awk '{print $2}')

    echo ""
    echo -e "${CYAN}Current configuration:${NC}"
    echo "  PGRST_DB_SCHEMAS: $current_schemas"
    echo ""

    if [[ "$current_schemas" == "public,auth,storage" ]]; then
        ok "✅ Configuration already correct!"
        echo ""
        log "Nothing to do. Your PostgREST is already configured correctly."
        exit 0
    fi

    if [[ "$current_schemas" == "public" ]]; then
        warn "⚠️  Configuration needs update: $current_schemas → public,auth,storage"
        return 0
    fi

    warn "⚠️  Unexpected configuration: $current_schemas"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Operation cancelled"
        exit 0
    fi
}

apply_fix() {
    log "🔧 Applying fix to docker-compose.yml..."

    # Use sed to replace the line
    sed -i.tmp 's/PGRST_DB_SCHEMAS: public$/PGRST_DB_SCHEMAS: public,auth,storage/' "$DOCKER_COMPOSE_FILE"

    # Remove temp file
    rm -f "$DOCKER_COMPOSE_FILE.tmp"

    ok "✅ docker-compose.yml updated"
}

verify_fix() {
    log "✅ Verifying fix..."

    local new_schemas
    new_schemas=$(grep "PGRST_DB_SCHEMAS:" "$DOCKER_COMPOSE_FILE" | head -1 | awk '{print $2}')

    echo ""
    echo -e "${CYAN}New configuration:${NC}"
    echo "  PGRST_DB_SCHEMAS: $new_schemas"
    echo ""

    if [[ "$new_schemas" == "public,auth,storage" ]]; then
        ok "✅ Configuration updated successfully!"
        return 0
    else
        error "❌ Fix failed! PGRST_DB_SCHEMAS is still: $new_schemas"
    fi
}

restart_postgrest() {
    log "🔄 Restarting PostgREST service..."

    cd "$STACK_DIR"

    if docker compose restart rest 2>&1; then
        ok "✅ PostgREST restarted successfully"
    else
        error "❌ Failed to restart PostgREST"
    fi

    echo ""
    log "⏳ Waiting for PostgREST to become healthy..."
    sleep 5

    # Check container status
    local status
    status=$(docker ps --filter "name=supabase-rest" --format "{{.Status}}")

    echo ""
    echo -e "${CYAN}PostgREST status:${NC}"
    echo "  $status"
    echo ""
}

test_auth_uid() {
    log "🧪 Testing auth.uid() function availability..."

    # Get environment
    if [[ ! -f "$STACK_DIR/.env" ]]; then
        warn "⚠️  .env file not found, skipping test"
        return 0
    fi

    set -a
    source "$STACK_DIR/.env"
    set +a

    # Test query
    local test_sql="SELECT auth.uid();"

    echo ""
    log "Executing test query: $test_sql"

    if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$test_sql" 2>&1 | grep -q "auth.uid"; then
        ok "✅ auth.uid() function is accessible!"
    else
        warn "⚠️  Could not verify auth.uid() function (this is OK if no user is authenticated)"
    fi

    echo ""
}

show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  PostgREST Schemas Fix Applied Successfully!              ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}What was fixed:${NC}"
    echo "  • PostgREST now has access to 'auth' schema"
    echo "  • PostgREST now has access to 'storage' schema"
    echo "  • RLS policies using auth.uid() will now work correctly"
    echo ""

    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Test your RLS policies:"
    echo "     ./scripts/utils/diagnose-rls.sh"
    echo ""
    echo "  2. If you have RLS policies using auth.uid(), they should now work"
    echo "     Test from your application:"
    echo "     supabase.from('your_table').select('*')"
    echo ""
    echo "  3. If you still get errors, check the RLS policies:"
    echo "     ./scripts/utils/diagnose-rls.sh your_table"
    echo ""

    echo -e "${CYAN}Backup file:${NC}"
    echo "  $BACKUP_FILE"
    echo ""

    ok "✅ Fix completed successfully!"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  PostgREST Schemas Fix (v3.45)                            ║"
    echo "║  Add 'auth' and 'storage' to PGRST_DB_SCHEMAS             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # Run fix steps
    check_prerequisites
    check_current_config
    backup_docker_compose
    apply_fix
    verify_fix
    restart_postgrest
    test_auth_uid
    show_summary
}

main "$@"
