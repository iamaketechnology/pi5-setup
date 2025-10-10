#!/bin/bash
# =============================================================================
# SUPABASE RLS DIAGNOSTIC TOOL
# =============================================================================
#
# Purpose: Diagnose RLS configuration and troubleshoot permission errors
# Usage: ./diagnose-rls.sh [table_name]
# Author: Claude Code Assistant
# Version: 1.0
#
# Examples:
#   ./diagnose-rls.sh                    # Check all tables
#   ./diagnose-rls.sh users              # Check specific table
#   ./diagnose-rls.sh --fix-common       # Auto-fix common issues
#
# =============================================================================

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly PROJECT_DIR="${PROJECT_DIR:-$HOME/stacks/supabase}"
readonly ENV_FILE="$PROJECT_DIR/.env"
POSTGRES_PASSWORD=""
DB_CONTAINER="supabase-db"
SPECIFIC_TABLE=""
FIX_COMMON=false

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

load_env() {
    if [[ -f "$ENV_FILE" ]]; then
        set -a
        source "$ENV_FILE"
        set +a
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
    else
        error "Environment file not found: $ENV_FILE"
        exit 1
    fi
}

exec_sql() {
    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
        psql -U postgres -d postgres -t -c "$1" 2>/dev/null | sed 's/^[[:space:]]*//'
}

exec_sql_formatted() {
    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
        psql -U postgres -d postgres -c "$1" 2>/dev/null
}

# =============================================================================
# DIAGNOSTIC FUNCTIONS
# =============================================================================

check_rls_status() {
    local table="$1"
    local schema="${2:-public}"

    log "Checking RLS status for $schema.$table..."

    local rls_enabled
    rls_enabled=$(exec_sql "
        SELECT CASE WHEN rowsecurity THEN 'true' ELSE 'false' END
        FROM pg_tables
        WHERE schemaname = '$schema' AND tablename = '$table';
    ")

    if [[ "$rls_enabled" == "true" ]]; then
        ok "✅ RLS is ENABLED on $schema.$table"
        return 0
    else
        warn "❌ RLS is DISABLED on $schema.$table"
        return 1
    fi
}

list_policies() {
    local table="$1"
    local schema="${2:-public}"

    log "Listing policies for $schema.$table..."

    local policies
    policies=$(exec_sql "
        SELECT COUNT(*)
        FROM pg_policies
        WHERE schemaname = '$schema' AND tablename = '$table';
    ")

    if [[ "$policies" -gt 0 ]]; then
        ok "✅ Found $policies policies"

        echo ""
        exec_sql_formatted "
            SELECT
                policyname,
                CASE cmd
                    WHEN 'r' THEN 'SELECT'
                    WHEN 'a' THEN 'INSERT'
                    WHEN 'w' THEN 'UPDATE'
                    WHEN 'd' THEN 'DELETE'
                    WHEN '*' THEN 'ALL'
                END as operation,
                roles::text
            FROM pg_policies
            WHERE schemaname = '$schema' AND tablename = '$table'
            ORDER BY policyname;
        "
        return 0
    else
        warn "❌ No policies found"
        return 1
    fi
}

check_table_structure() {
    local table="$1"
    local schema="${2:-public}"

    log "Analyzing table structure for $schema.$table..."

    echo ""
    echo -e "${CYAN}=== Table Columns ===${NC}"
    exec_sql_formatted "
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_default
        FROM information_schema.columns
        WHERE table_schema = '$schema' AND table_name = '$table'
        ORDER BY ordinal_position;
    "

    # Check for common RLS columns
    local has_user_id
    local has_email
    local has_team_id

    has_user_id=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name = 'user_id';
    ")

    has_email=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name = 'email';
    ")

    has_team_id=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name IN ('team_id', 'organization_id');
    ")

    echo ""
    echo -e "${CYAN}=== RLS-relevant Columns ===${NC}"

    if [[ "$has_user_id" -gt 0 ]]; then
        ok "✅ Has 'user_id' column (good for user-based policies)"
    else
        warn "⚠️  No 'user_id' column found"
    fi

    if [[ "$has_email" -gt 0 ]]; then
        ok "✅ Has 'email' column (good for email-based policies)"
    else
        log "   No 'email' column"
    fi

    if [[ "$has_team_id" -gt 0 ]]; then
        ok "✅ Has 'team_id' or 'organization_id' (good for team-based policies)"
    else
        log "   No team/organization column"
    fi
}

check_permissions() {
    local table="$1"
    local schema="${2:-public}"

    log "Checking table permissions..."

    echo ""
    echo -e "${CYAN}=== Table Permissions ===${NC}"
    exec_sql_formatted "
        SELECT
            grantee,
            string_agg(privilege_type, ', ') as privileges
        FROM information_schema.table_privileges
        WHERE table_schema = '$schema' AND table_name = '$table'
        GROUP BY grantee
        ORDER BY grantee;
    "
}

test_policy_with_user() {
    local table="$1"
    local schema="${2:-public}"
    local test_user_id="${3:-00000000-0000-0000-0000-000000000000}"

    log "Testing SELECT policy with test user ID: $test_user_id..."

    # This requires auth.uid() function which may not work in direct psql
    warn "⚠️  Policy testing requires actual authenticated session"
    log "   Use Supabase client library to test policies properly"
    log "   Example: supabase.from('$table').select('*')"
}

suggest_policies() {
    local table="$1"
    local schema="${2:-public}"

    echo ""
    echo -e "${CYAN}=== Suggested Policies ===${NC}"

    local has_user_id
    has_user_id=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name = 'user_id';
    ")

    local has_email
    has_email=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.columns
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND column_name = 'email';
    ")

    if [[ "$has_user_id" -gt 0 ]]; then
        echo ""
        log "💡 Recommended: Basic user-based policies"
        echo "   ./generate-rls-template.sh $table --basic"
        echo ""
    elif [[ "$has_email" -gt 0 ]]; then
        echo ""
        log "💡 Recommended: Email-based policies"
        echo "   ./generate-rls-template.sh $table --email"
        echo ""
    else
        echo ""
        log "💡 Recommended: Custom policies (no standard columns found)"
        echo "   ./generate-rls-template.sh $table --custom"
        echo ""
    fi

    log "📖 View all policy types:"
    echo "   ./generate-rls-template.sh --help"
}

check_common_issues() {
    local table="$1"
    local schema="${2:-public}"

    echo ""
    echo -e "${CYAN}=== Common Issues Check ===${NC}"

    local issues_found=0

    # Issue 1: RLS enabled but no policies
    local rls_enabled
    rls_enabled=$(exec_sql "
        SELECT CASE WHEN rowsecurity THEN 'true' ELSE 'false' END
        FROM pg_tables
        WHERE schemaname = '$schema' AND tablename = '$table';
    ")

    local policy_count
    policy_count=$(exec_sql "
        SELECT COUNT(*)
        FROM pg_policies
        WHERE schemaname = '$schema' AND tablename = '$table';
    ")

    if [[ "$rls_enabled" == "true" ]] && [[ "$policy_count" -eq 0 ]]; then
        error "❌ ISSUE: RLS enabled but NO policies defined"
        log "   This will block ALL access to the table"
        log "   Fix: Create policies or disable RLS"
        ((issues_found++))
    fi

    # Issue 2: Table accessible to PUBLIC role
    local public_access
    public_access=$(exec_sql "
        SELECT COUNT(*)
        FROM information_schema.table_privileges
        WHERE table_schema = '$schema'
        AND table_name = '$table'
        AND grantee = 'PUBLIC';
    ")

    if [[ "$public_access" -gt 0 ]]; then
        warn "⚠️  WARNING: Table has PUBLIC role permissions"
        log "   This might bypass RLS in some cases"
        ((issues_found++))
    fi

    # Issue 3: Missing auth.uid() function
    local auth_uid_exists
    auth_uid_exists=$(exec_sql "
        SELECT COUNT(*)
        FROM pg_proc
        WHERE proname = 'uid'
        AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth');
    " || echo "0")

    if [[ "$auth_uid_exists" -eq 0 ]]; then
        error "❌ CRITICAL: auth.uid() function not found"
        log "   User-based policies won't work"
        log "   This is a Supabase installation issue"
        ((issues_found++))
    fi

    if [[ "$issues_found" -eq 0 ]]; then
        ok "✅ No common issues detected"
    fi

    return $issues_found
}

# =============================================================================
# FULL DIAGNOSTIC
# =============================================================================

diagnose_table() {
    local table="$1"
    local schema="${2:-public}"

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  RLS DIAGNOSTIC: $schema.$table"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 1. Check if table exists
    local table_exists
    table_exists=$(exec_sql "
        SELECT COUNT(*)
        FROM pg_tables
        WHERE schemaname = '$schema' AND tablename = '$table';
    ")

    if [[ "$table_exists" -eq 0 ]]; then
        error "❌ Table $schema.$table does not exist"
        return 1
    fi

    ok "✅ Table exists"

    # 2. Check RLS status
    echo ""
    check_rls_status "$table" "$schema"

    # 3. List policies
    echo ""
    list_policies "$table" "$schema"

    # 4. Check table structure
    echo ""
    check_table_structure "$table" "$schema"

    # 5. Check permissions
    echo ""
    check_permissions "$table" "$schema"

    # 6. Check common issues
    echo ""
    check_common_issues "$table" "$schema"

    # 7. Suggest policies
    suggest_policies "$table" "$schema"

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

diagnose_all_tables() {
    log "Discovering all tables..."

    local tables
    tables=$(exec_sql "
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
        ORDER BY tablename;
    ")

    if [[ -z "$tables" ]]; then
        warn "No tables found in public schema"
        return 0
    fi

    local table_count
    table_count=$(echo "$tables" | wc -l)

    log "Found $table_count tables"
    echo ""

    # Summary first
    echo -e "${CYAN}=== RLS Summary ===${NC}"
    exec_sql_formatted "
        SELECT
            tablename,
            CASE WHEN rowsecurity THEN '✅ Enabled' ELSE '❌ Disabled' END as rls,
            COALESCE(policy_count.count, 0) as policies
        FROM pg_tables
        LEFT JOIN (
            SELECT tablename, COUNT(*) as count
            FROM pg_policies
            WHERE schemaname = 'public'
            GROUP BY tablename
        ) policy_count USING (tablename)
        WHERE schemaname = 'public'
        ORDER BY tablename;
    "

    echo ""
    read -p "Show detailed diagnostics for each table? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        while IFS= read -r table; do
            if [[ -n "$table" ]]; then
                diagnose_table "$table"
                echo ""
            fi
        done <<< "$tables"
    fi
}

# =============================================================================
# MAIN
# =============================================================================

show_usage() {
    cat << EOF
${CYAN}Supabase RLS Diagnostic Tool${NC}

Usage: $0 [table_name] [options]

Options:
    <table_name>    Diagnose specific table
    --all           Diagnose all tables (default if no table specified)
    --help          Show this help

Examples:
    $0                  # Diagnose all tables
    $0 users            # Diagnose 'users' table only
    $0 posts            # Diagnose 'posts' table only

What it checks:
    ✓ RLS enabled/disabled status
    ✓ Existing policies
    ✓ Table structure (user_id, email columns)
    ✓ Permissions
    ✓ Common configuration issues
    ✓ Policy suggestions

EOF
}

main() {
    if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
        show_usage
        exit 0
    fi

    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       SUPABASE RLS DIAGNOSTIC TOOL                         ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    load_env

    if [[ $# -eq 0 ]] || [[ "${1:-}" == "--all" ]]; then
        diagnose_all_tables
    else
        SPECIFIC_TABLE="$1"
        diagnose_table "$SPECIFIC_TABLE"
    fi

    echo ""
    ok "✅ Diagnostic complete"
}

main "$@"
