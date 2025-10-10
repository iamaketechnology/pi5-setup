#!/bin/bash
# =============================================================================
# AUTO-CONFIGURE RLS - Intelligent RLS Setup for Any Application
# =============================================================================
#
# Purpose: Automatically detect tables and configure appropriate RLS policies
#          Works with ANY application - no assumptions made
#
# Author: Claude Code Assistant
# Version: 1.0
# Date: 2025-10-10
#
# Usage: ./auto-configure-rls.sh [options]
#
# Options:
#   --dry-run          Show what would be done without doing it
#   --skip-tables      Comma-separated list of tables to skip
#   --policy-type      Force a specific policy type (basic/email/team)
#   --interactive      Ask for confirmation for each table
#
# Examples:
#   ./auto-configure-rls.sh
#   ./auto-configure-rls.sh --dry-run
#   ./auto-configure-rls.sh --skip-tables "migrations,schema_migrations"
#   ./auto-configure-rls.sh --interactive
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
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Options
DRY_RUN=false
SKIP_TABLES=""
FORCE_POLICY_TYPE=""
INTERACTIVE=false

# Statistics
TABLES_PROCESSED=0
TABLES_SKIPPED=0
POLICIES_CREATED=0

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() { echo -e "${CYAN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# =============================================================================
# ENVIRONMENT SETUP
# =============================================================================

load_environment() {
    log "📂 Loading environment..."

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found: $ENV_FILE"
    fi

    set -a
    source "$ENV_FILE"
    set +a

    if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
        error "POSTGRES_PASSWORD not found in $ENV_FILE"
    fi

    ok "✅ Environment loaded"
}

# =============================================================================
# TABLE DETECTION
# =============================================================================

get_all_tables() {
    log "🔍 Discovering tables in public schema..."

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -t -c \
        "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;" \
        2>/dev/null | sed 's/^[[:space:]]*//' | grep -v '^$'
}

is_table_skipped() {
    local table="$1"

    # Default skip patterns
    local default_skip=(
        "schema_migrations"
        "migrations"
        "supabase_migrations"
        "supabase_functions_migrations"
        "pg_stat"
        "pg_"
    )

    # Check default skip patterns
    for skip in "${default_skip[@]}"; do
        if [[ "$table" == *"$skip"* ]]; then
            return 0  # Skip this table
        fi
    done

    # Check user-provided skip list
    if [[ -n "$SKIP_TABLES" ]]; then
        IFS=',' read -ra skip_list <<< "$SKIP_TABLES"
        for skip in "${skip_list[@]}"; do
            if [[ "$table" == "$skip" ]]; then
                return 0  # Skip this table
            fi
        done
    fi

    return 1  # Don't skip
}

# =============================================================================
# COLUMN DETECTION
# =============================================================================

detect_table_columns() {
    local table="$1"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -t -c \
        "SELECT column_name FROM information_schema.columns
         WHERE table_schema = 'public' AND table_name = '$table'
         ORDER BY ordinal_position;" \
        2>/dev/null | sed 's/^[[:space:]]*//' | grep -v '^$'
}

has_column() {
    local table="$1"
    local column="$2"

    local columns
    columns=$(detect_table_columns "$table")

    echo "$columns" | grep -q "^${column}$"
}

# =============================================================================
# POLICY TYPE DETECTION
# =============================================================================

determine_policy_type() {
    local table="$1"

    # Force type if specified
    if [[ -n "$FORCE_POLICY_TYPE" ]]; then
        echo "$FORCE_POLICY_TYPE"
        return 0
    fi

    # Check for common column patterns
    if has_column "$table" "user_id"; then
        echo "basic"  # User-based policies
    elif has_column "$table" "email"; then
        echo "email"  # Email-based policies
    elif has_column "$table" "team_id" || has_column "$table" "organization_id"; then
        echo "team"   # Team-based policies
    elif has_column "$table" "owner_id"; then
        echo "basic"  # Owner-based (similar to user_id)
    else
        echo "custom" # No clear pattern, need custom
    fi
}

# =============================================================================
# RLS CONFIGURATION
# =============================================================================

enable_rls_on_table() {
    local table="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would enable RLS on: $table"
        return 0
    fi

    local sql="ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$sql" &>/dev/null

    if [[ $? -eq 0 ]]; then
        ok "  ✓ RLS enabled on $table"
        return 0
    else
        warn "  ⚠ Failed to enable RLS on $table"
        return 1
    fi
}

create_basic_policy() {
    local table="$1"
    local user_column="${2:-user_id}"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would create basic policies on: $table (column: $user_column)"
        return 0
    fi

    local sql="
-- Basic user-based policies for $table
DROP POLICY IF EXISTS \"Users can view their own $table\" ON public.$table;
CREATE POLICY \"Users can view their own $table\"
ON public.$table FOR SELECT TO authenticated
USING ($user_column = auth.uid());

DROP POLICY IF EXISTS \"Users can insert their own $table\" ON public.$table;
CREATE POLICY \"Users can insert their own $table\"
ON public.$table FOR INSERT TO authenticated
WITH CHECK ($user_column = auth.uid());

DROP POLICY IF EXISTS \"Users can update their own $table\" ON public.$table;
CREATE POLICY \"Users can update their own $table\"
ON public.$table FOR UPDATE TO authenticated
USING ($user_column = auth.uid())
WITH CHECK ($user_column = auth.uid());

DROP POLICY IF EXISTS \"Users can delete their own $table\" ON public.$table;
CREATE POLICY \"Users can delete their own $table\"
ON public.$table FOR DELETE TO authenticated
USING ($user_column = auth.uid());
"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$sql" &>/dev/null

    if [[ $? -eq 0 ]]; then
        ok "  ✓ Basic policies created on $table"
        ((POLICIES_CREATED += 4))
        return 0
    else
        warn "  ⚠ Failed to create policies on $table"
        return 1
    fi
}

create_email_policy() {
    local table="$1"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would create email-based policies on: $table"
        return 0
    fi

    local sql="
-- Email-based policies for $table
DROP POLICY IF EXISTS \"Users can view their own $table by email\" ON public.$table;
CREATE POLICY \"Users can view their own $table by email\"
ON public.$table FOR SELECT TO authenticated
USING (email = (auth.jwt() ->> 'email'));

DROP POLICY IF EXISTS \"Users can insert their own $table by email\" ON public.$table;
CREATE POLICY \"Users can insert their own $table by email\"
ON public.$table FOR INSERT TO authenticated
WITH CHECK (email = (auth.jwt() ->> 'email'));
"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$sql" &>/dev/null

    if [[ $? -eq 0 ]]; then
        ok "  ✓ Email-based policies created on $table"
        ((POLICIES_CREATED += 2))
        return 0
    else
        warn "  ⚠ Failed to create email policies on $table"
        return 1
    fi
}

create_team_policy() {
    local table="$1"
    local team_column="team_id"

    # Detect if it's organization_id instead
    if has_column "$table" "organization_id"; then
        team_column="organization_id"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would create team-based policies on: $table (column: $team_column)"
        return 0
    fi

    local sql="
-- Team-based policies for $table
DROP POLICY IF EXISTS \"Users can view team $table\" ON public.$table;
CREATE POLICY \"Users can view team $table\"
ON public.$table FOR SELECT TO authenticated
USING ($team_column = (auth.jwt() ->> '$team_column')::uuid);

DROP POLICY IF EXISTS \"Users can insert team $table\" ON public.$table;
CREATE POLICY \"Users can insert team $table\"
ON public.$table FOR INSERT TO authenticated
WITH CHECK ($team_column = (auth.jwt() ->> '$team_column')::uuid);
"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" supabase-db \
        psql -U postgres -d postgres -c "$sql" &>/dev/null

    if [[ $? -eq 0 ]]; then
        ok "  ✓ Team-based policies created on $table (using $team_column)"
        ((POLICIES_CREATED += 2))
        return 0
    else
        warn "  ⚠ Failed to create team policies on $table"
        return 1
    fi
}

skip_table_with_warning() {
    local table="$1"
    local reason="$2"

    warn "  ⚠ Skipping $table: $reason"
    log "     Generate custom policy: ./generate-rls-template.sh $table --custom"
    ((TABLES_SKIPPED++))
}

# =============================================================================
# MAIN PROCESSING
# =============================================================================

process_table() {
    local table="$1"

    echo ""
    log "━━━ Processing: $table ━━━"

    # Skip check
    if is_table_skipped "$table"; then
        warn "  ⊘ Skipped (migration/system table)"
        ((TABLES_SKIPPED++))
        return 0
    fi

    # Interactive mode
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo ""
        read -p "Configure RLS for '$table'? (y/N/s=skip): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Ss]$ ]]; then
            warn "  ⊘ Skipped by user"
            ((TABLES_SKIPPED++))
            return 0
        elif [[ ! $REPLY =~ ^[Yy]$ ]]; then
            warn "  ⊘ Skipped by user"
            ((TABLES_SKIPPED++))
            return 0
        fi
    fi

    # Detect columns
    local columns
    columns=$(detect_table_columns "$table")

    log "  Columns: $(echo "$columns" | tr '\n' ',' | sed 's/,$//')"

    # Determine policy type
    local policy_type
    policy_type=$(determine_policy_type "$table")

    log "  Policy type: $policy_type"

    # Enable RLS
    enable_rls_on_table "$table" || return 1

    # Create policies based on type
    case "$policy_type" in
        basic)
            if has_column "$table" "user_id"; then
                create_basic_policy "$table" "user_id"
            elif has_column "$table" "owner_id"; then
                create_basic_policy "$table" "owner_id"
            else
                skip_table_with_warning "$table" "No user_id or owner_id column"
            fi
            ;;
        email)
            create_email_policy "$table"
            ;;
        team)
            create_team_policy "$table"
            ;;
        custom)
            skip_table_with_warning "$table" "No standard columns detected, needs custom policy"
            ;;
        *)
            warn "  ⚠ Unknown policy type: $policy_type"
            ((TABLES_SKIPPED++))
            ;;
    esac

    ((TABLES_PROCESSED++))
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Auto-Configure RLS - Summary                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}Statistics:${NC}"
    echo "  Tables processed: $TABLES_PROCESSED"
    echo "  Tables skipped:   $TABLES_SKIPPED"
    echo "  Policies created: $POLICIES_CREATED"
    echo ""

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "🔍 This was a DRY-RUN - no changes were made"
        echo "   Run without --dry-run to apply changes"
        echo ""
    fi

    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Verify policies: ./diagnose-rls.sh"
    echo "  2. Test from application"
    echo "  3. For skipped tables, create custom policies:"
    echo "     ./generate-rls-template.sh <table_name> --custom"
    echo ""

    ok "✅ Auto-configuration completed!"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-tables)
                SKIP_TABLES="$2"
                shift 2
                ;;
            --policy-type)
                FORCE_POLICY_TYPE="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            -h|--help)
                cat << EOF
Auto-Configure RLS - Intelligent RLS Setup for Any Application

Usage: $0 [options]

Options:
    --dry-run           Show what would be done without doing it
    --skip-tables       Comma-separated list of tables to skip
    --policy-type       Force a specific policy type (basic/email/team)
    --interactive       Ask for confirmation for each table
    -h, --help          Show this help

Examples:
    $0
    $0 --dry-run
    $0 --skip-tables "migrations,logs"
    $0 --policy-type basic
    $0 --interactive

Detection Logic:
    - Has 'user_id' → Basic user-based policies
    - Has 'email' → Email-based policies
    - Has 'team_id' or 'organization_id' → Team-based policies
    - Has 'owner_id' → Basic owner-based policies
    - None of above → Custom (manual configuration needed)

Skipped by default:
    - schema_migrations, migrations, pg_* tables
EOF
                exit 0
                ;;
            *)
                error "Unknown option: $1\nUse --help for usage information"
                ;;
        esac
    done
}

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Auto-Configure RLS for Any Application                   ║"
    echo "║  Intelligent Detection & Configuration                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""

    # Parse arguments
    parse_arguments "$@"

    # Load environment
    load_environment

    # Get all tables
    local tables
    tables=$(get_all_tables)

    if [[ -z "$tables" ]]; then
        warn "No tables found in public schema"
        exit 0
    fi

    local table_count
    table_count=$(echo "$tables" | wc -l)

    log "Found $table_count tables in public schema"

    if [[ "$DRY_RUN" == "true" ]]; then
        warn "🔍 DRY-RUN mode - no changes will be made"
    fi

    echo ""

    # Process each table
    while IFS= read -r table; do
        if [[ -n "$table" ]]; then
            process_table "$table"
        fi
    done <<< "$tables"

    # Show summary
    show_summary
}

main "$@"
