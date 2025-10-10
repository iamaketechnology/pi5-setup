#!/bin/bash
# =============================================================================
# SUPABASE RLS POLICIES - Setup Script
# =============================================================================
#
# Purpose: Configure Row Level Security policies for Supabase tables
# Usage: ./setup-rls-policies.sh [options]
# Author: Claude Code Assistant
# Version: 1.0
#
# Options:
#   --table <name>      Apply RLS to specific table only
#   --disable          Disable RLS on tables (use with caution!)
#   --list             List current RLS policies
#   --dry-run          Show SQL without executing
#   --custom <file>    Execute custom RLS SQL file
#
# Examples:
#   ./setup-rls-policies.sh                    # Apply default policies
#   ./setup-rls-policies.sh --table users      # Apply to 'users' table only
#   ./setup-rls-policies.sh --list             # Show current policies
#   ./setup-rls-policies.sh --dry-run          # Preview SQL
#   ./setup-rls-policies.sh --custom my-rls.sql
#
# =============================================================================

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Script configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="${PROJECT_DIR:-$HOME/stacks/supabase}"
readonly ENV_FILE="$PROJECT_DIR/.env"
readonly LOG_FILE="/var/log/supabase-rls-setup-$(date +%Y%m%d-%H%M%S).log"

# Database connection info
POSTGRES_PASSWORD=""
DB_CONTAINER="supabase-db"
DB_USER="postgres"
DB_NAME="postgres"

# Script options
DRY_RUN=false
LIST_ONLY=false
DISABLE_RLS=false
SPECIFIC_TABLE=""
CUSTOM_SQL_FILE=""

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
    exit 1
}

# =============================================================================
# LOAD ENVIRONMENT
# =============================================================================

load_environment() {
    log "📂 Loading environment from $ENV_FILE..."

    if [[ ! -f "$ENV_FILE" ]]; then
        error "Environment file not found: $ENV_FILE"
    fi

    # Source environment file
    set -a
    source "$ENV_FILE"
    set +a

    POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

    if [[ -z "$POSTGRES_PASSWORD" ]]; then
        error "POSTGRES_PASSWORD not found in $ENV_FILE"
    fi

    ok "✅ Environment loaded successfully"
}

# =============================================================================
# DATABASE HELPERS
# =============================================================================

execute_sql() {
    local sql="$1"
    local description="${2:-Executing SQL}"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY-RUN]${NC} $description"
        echo -e "${CYAN}$sql${NC}"
        return 0
    fi

    log "🔧 $description..."

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" -c "$sql" 2>&1 | tee -a "$LOG_FILE"

    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        ok "✅ $description completed"
        return 0
    else
        warn "⚠️  $description failed (exit code: $exit_code)"
        return $exit_code
    fi
}

execute_sql_file() {
    local sql_file="$1"
    local description="${2:-Executing SQL file}"

    if [[ ! -f "$sql_file" ]]; then
        error "SQL file not found: $sql_file"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}[DRY-RUN]${NC} $description"
        cat "$sql_file"
        return 0
    fi

    log "🔧 $description..."

    docker exec -i -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" < "$sql_file" 2>&1 | tee -a "$LOG_FILE"

    local exit_code=${PIPESTATUS[0]}

    if [[ $exit_code -eq 0 ]]; then
        ok "✅ $description completed"
        return 0
    else
        error "$description failed"
    fi
}

get_tables() {
    local schema="${1:-public}"

    docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$DB_CONTAINER" \
        psql -U "$DB_USER" -d "$DB_NAME" -t -c \
        "SELECT tablename FROM pg_tables WHERE schemaname = '$schema' ORDER BY tablename;" \
        2>/dev/null | sed 's/^[[:space:]]*//' | grep -v '^$'
}

# =============================================================================
# RLS POLICY FUNCTIONS
# =============================================================================

list_rls_policies() {
    log "📋 Listing current RLS policies..."

    local sql="
    SELECT
        schemaname,
        tablename,
        CASE WHEN rowsecurity THEN '✅ Enabled' ELSE '❌ Disabled' END as rls_status
    FROM pg_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY schemaname, tablename;
    "

    echo ""
    echo -e "${CYAN}=== RLS Status by Table ===${NC}"
    execute_sql "$sql" "Checking RLS status"

    echo ""
    echo -e "${CYAN}=== Active RLS Policies ===${NC}"

    local policy_sql="
    SELECT
        schemaname || '.' || tablename as table,
        policyname as policy,
        CASE cmd
            WHEN 'r' THEN 'SELECT'
            WHEN 'a' THEN 'INSERT'
            WHEN 'w' THEN 'UPDATE'
            WHEN 'd' THEN 'DELETE'
            WHEN '*' THEN 'ALL'
        END as operation,
        roles::text as roles
    FROM pg_policies
    ORDER BY schemaname, tablename, policyname;
    "

    execute_sql "$policy_sql" "Listing policies"
}

enable_rls_on_table() {
    local table="$1"
    local schema="${2:-public}"

    local sql="ALTER TABLE $schema.$table ENABLE ROW LEVEL SECURITY;"
    execute_sql "$sql" "Enabling RLS on $schema.$table"
}

disable_rls_on_table() {
    local table="$1"
    local schema="${2:-public}"

    warn "⚠️  Disabling RLS on $schema.$table - this removes security protection!"

    local sql="ALTER TABLE $schema.$table DISABLE ROW LEVEL SECURITY;"
    execute_sql "$sql" "Disabling RLS on $schema.$table"
}

create_basic_auth_policies() {
    local table="$1"
    local schema="${2:-public}"

    log "🔐 Creating basic authenticated user policies for $schema.$table..."

    # Policy 1: Authenticated users can SELECT their own data (if user_id column exists)
    local select_policy="
    DO \$\$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            AND column_name = 'user_id'
        ) THEN
            DROP POLICY IF EXISTS \"Users can view their own ${table}\" ON $schema.$table;
            CREATE POLICY \"Users can view their own ${table}\"
            ON $schema.$table FOR SELECT TO authenticated
            USING (user_id = auth.uid());
        ELSE
            RAISE NOTICE 'Table $schema.$table has no user_id column, skipping user-specific SELECT policy';
        END IF;
    END \$\$;
    "

    execute_sql "$select_policy" "Creating SELECT policy for $schema.$table"

    # Policy 2: Authenticated users can INSERT their own data
    local insert_policy="
    DO \$\$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            AND column_name = 'user_id'
        ) THEN
            DROP POLICY IF EXISTS \"Users can insert their own ${table}\" ON $schema.$table;
            CREATE POLICY \"Users can insert their own ${table}\"
            ON $schema.$table FOR INSERT TO authenticated
            WITH CHECK (user_id = auth.uid());
        END IF;
    END \$\$;
    "

    execute_sql "$insert_policy" "Creating INSERT policy for $schema.$table"

    # Policy 3: Authenticated users can UPDATE their own data
    local update_policy="
    DO \$\$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            AND column_name = 'user_id'
        ) THEN
            DROP POLICY IF EXISTS \"Users can update their own ${table}\" ON $schema.$table;
            CREATE POLICY \"Users can update their own ${table}\"
            ON $schema.$table FOR UPDATE TO authenticated
            USING (user_id = auth.uid())
            WITH CHECK (user_id = auth.uid());
        END IF;
    END \$\$;
    "

    execute_sql "$update_policy" "Creating UPDATE policy for $schema.$table"

    # Policy 4: Authenticated users can DELETE their own data
    local delete_policy="
    DO \$\$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            AND column_name = 'user_id'
        ) THEN
            DROP POLICY IF EXISTS \"Users can delete their own ${table}\" ON $schema.$table;
            CREATE POLICY \"Users can delete their own ${table}\"
            ON $schema.$table FOR DELETE TO authenticated
            USING (user_id = auth.uid());
        END IF;
    END \$\$;
    "

    execute_sql "$delete_policy" "Creating DELETE policy for $schema.$table"
}

create_email_based_policies() {
    local table="$1"
    local schema="${2:-public}"

    log "📧 Creating email-based policies for $schema.$table..."

    # For tables with 'email' column instead of 'user_id'
    local email_policy="
    DO \$\$
    BEGIN
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = '$schema'
            AND table_name = '$table'
            AND column_name = 'email'
        ) THEN
            DROP POLICY IF EXISTS \"Users can view their own ${table} by email\" ON $schema.$table;
            CREATE POLICY \"Users can view their own ${table} by email\"
            ON $schema.$table FOR SELECT TO authenticated
            USING (email = auth.jwt() ->> 'email');
        END IF;
    END \$\$;
    "

    execute_sql "$email_policy" "Creating email-based SELECT policy for $schema.$table"
}

# =============================================================================
# MAIN SETUP FUNCTION
# =============================================================================

setup_rls_policies() {
    log "🔐 Setting up RLS policies..."

    if [[ -n "$SPECIFIC_TABLE" ]]; then
        log "📌 Applying RLS to specific table: $SPECIFIC_TABLE"

        enable_rls_on_table "$SPECIFIC_TABLE"
        create_basic_auth_policies "$SPECIFIC_TABLE"
        create_email_based_policies "$SPECIFIC_TABLE"

        ok "✅ RLS policies applied to $SPECIFIC_TABLE"
        return 0
    fi

    # Get all public tables
    log "🔍 Discovering tables in public schema..."
    local tables
    tables=$(get_tables "public")

    if [[ -z "$tables" ]]; then
        warn "⚠️  No tables found in public schema"
        return 0
    fi

    echo ""
    echo -e "${CYAN}=== Tables Found ===${NC}"
    echo "$tables"
    echo ""

    # Ask for confirmation
    if [[ "$DRY_RUN" != "true" ]]; then
        read -p "Apply RLS policies to all these tables? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            warn "⚠️  Operation cancelled by user"
            exit 0
        fi
    fi

    # Apply RLS to each table
    while IFS= read -r table; do
        if [[ -n "$table" ]]; then
            log "📋 Processing table: $table"

            if [[ "$DISABLE_RLS" == "true" ]]; then
                disable_rls_on_table "$table"
            else
                enable_rls_on_table "$table"
                create_basic_auth_policies "$table"
                create_email_based_policies "$table"
            fi

            echo ""
        fi
    done <<< "$tables"

    ok "✅ RLS setup completed for all tables"
}

# =============================================================================
# USAGE & ARGUMENT PARSING
# =============================================================================

show_usage() {
    cat << EOF
${CYAN}Supabase RLS Policies Setup Script${NC}

Usage: $0 [options]

Options:
    --table <name>      Apply RLS to specific table only
    --disable          Disable RLS on tables (use with caution!)
    --list             List current RLS policies
    --dry-run          Show SQL without executing
    --custom <file>    Execute custom RLS SQL file
    -h, --help         Show this help message

Examples:
    $0                              # Apply default policies to all tables
    $0 --table users                # Apply to 'users' table only
    $0 --list                       # Show current policies
    $0 --dry-run                    # Preview SQL
    $0 --custom my-rls.sql          # Execute custom SQL file
    $0 --table invites --disable    # Disable RLS on 'invites' table

Default Policies Created:
    - SELECT: Users can view their own data (user_id = auth.uid())
    - INSERT: Users can insert their own data
    - UPDATE: Users can update their own data
    - DELETE: Users can delete their own data
    - Email-based: For tables with 'email' column (email = auth.jwt()->>'email')

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --table)
                SPECIFIC_TABLE="$2"
                shift 2
                ;;
            --disable)
                DISABLE_RLS=true
                shift
                ;;
            --list)
                LIST_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --custom)
                CUSTOM_SQL_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1\nUse --help for usage information"
                ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       SUPABASE RLS POLICIES SETUP                          ║"
    echo "║       Row Level Security Configuration                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    # Load environment
    load_environment

    # List only mode
    if [[ "$LIST_ONLY" == "true" ]]; then
        list_rls_policies
        exit 0
    fi

    # Custom SQL file mode
    if [[ -n "$CUSTOM_SQL_FILE" ]]; then
        execute_sql_file "$CUSTOM_SQL_FILE" "Executing custom RLS SQL file: $CUSTOM_SQL_FILE"
        ok "✅ Custom SQL executed successfully"
        exit 0
    fi

    # Setup RLS policies
    setup_rls_policies

    # Show final status
    echo ""
    log "📊 Final RLS Status:"
    list_rls_policies

    echo ""
    ok "✅ RLS setup completed successfully!"
    log "📄 Full log saved to: $LOG_FILE"
}

# Run main function
main "$@"
