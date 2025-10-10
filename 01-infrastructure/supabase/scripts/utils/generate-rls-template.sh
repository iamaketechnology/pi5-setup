#!/bin/bash
# =============================================================================
# SUPABASE RLS POLICY TEMPLATE GENERATOR
# =============================================================================
#
# Purpose: Generate custom RLS policy SQL templates for your tables
# Usage: ./generate-rls-template.sh <table_name> [options]
# Author: Claude Code Assistant
# Version: 1.0
#
# Examples:
#   ./generate-rls-template.sh users
#   ./generate-rls-template.sh posts --public-read
#   ./generate-rls-template.sh comments --owner-only
#   ./generate-rls-template.sh profiles --custom
#
# =============================================================================

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Script configuration
TABLE_NAME=""
POLICY_TYPE="basic"
OUTPUT_FILE=""

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${CYAN}ℹ${NC} $*"
}

ok() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

# =============================================================================
# TEMPLATE GENERATORS
# =============================================================================

generate_basic_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Basic (Authenticated users can manage their own data)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies if re-running
DROP POLICY IF EXISTS "Users can view their own $table" ON public.$table;
DROP POLICY IF EXISTS "Users can insert their own $table" ON public.$table;
DROP POLICY IF EXISTS "Users can update their own $table" ON public.$table;
DROP POLICY IF EXISTS "Users can delete their own $table" ON public.$table;

-- SELECT Policy: Users can view their own rows
CREATE POLICY "Users can view their own $table"
ON public.$table
FOR SELECT
TO authenticated
USING (user_id = auth.uid());

-- INSERT Policy: Users can insert rows with their user_id
CREATE POLICY "Users can insert their own $table"
ON public.$table
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- UPDATE Policy: Users can update their own rows
CREATE POLICY "Users can update their own $table"
ON public.$table
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- DELETE Policy: Users can delete their own rows
CREATE POLICY "Users can delete their own $table"
ON public.$table
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

-- Verify policies
SELECT schemaname, tablename, policyname
FROM pg_policies
WHERE tablename = '$table';

EOF
}

generate_public_read_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Public Read (Anyone can read, only owners can modify)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies
DROP POLICY IF EXISTS "Anyone can view $table" ON public.$table;
DROP POLICY IF EXISTS "Users can insert their own $table" ON public.$table;
DROP POLICY IF EXISTS "Users can update their own $table" ON public.$table;
DROP POLICY IF EXISTS "Users can delete their own $table" ON public.$table;

-- SELECT Policy: Anyone (including anonymous) can read
CREATE POLICY "Anyone can view $table"
ON public.$table
FOR SELECT
TO public
USING (true);

-- INSERT Policy: Authenticated users can insert their own data
CREATE POLICY "Users can insert their own $table"
ON public.$table
FOR INSERT
TO authenticated
WITH CHECK (user_id = auth.uid());

-- UPDATE Policy: Users can only update their own rows
CREATE POLICY "Users can update their own $table"
ON public.$table
FOR UPDATE
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- DELETE Policy: Users can only delete their own rows
CREATE POLICY "Users can delete their own $table"
ON public.$table
FOR DELETE
TO authenticated
USING (user_id = auth.uid());

EOF
}

generate_owner_only_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Owner Only (Strict privacy - users only see their own data)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies
DROP POLICY IF EXISTS "Users can only access their own $table" ON public.$table;

-- ALL operations: Users can ONLY access their own data
CREATE POLICY "Users can only access their own $table"
ON public.$table
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- This single policy covers SELECT, INSERT, UPDATE, DELETE
-- Users are completely isolated from each other's data

EOF
}

generate_email_based_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Email-based (For tables using email instead of user_id)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies
DROP POLICY IF EXISTS "Users can view their own $table by email" ON public.$table;
DROP POLICY IF EXISTS "Users can insert their own $table by email" ON public.$table;
DROP POLICY IF EXISTS "Users can update their own $table by email" ON public.$table;
DROP POLICY IF EXISTS "Users can delete their own $table by email" ON public.$table;

-- SELECT Policy: Users can view rows matching their email
CREATE POLICY "Users can view their own $table by email"
ON public.$table
FOR SELECT
TO authenticated
USING (email = (auth.jwt() ->> 'email'));

-- INSERT Policy: Users can insert rows with their email
CREATE POLICY "Users can insert their own $table by email"
ON public.$table
FOR INSERT
TO authenticated
WITH CHECK (email = (auth.jwt() ->> 'email'));

-- UPDATE Policy: Users can update rows with their email
CREATE POLICY "Users can update their own $table by email"
ON public.$table
FOR UPDATE
TO authenticated
USING (email = (auth.jwt() ->> 'email'))
WITH CHECK (email = (auth.jwt() ->> 'email'));

-- DELETE Policy: Users can delete rows with their email
CREATE POLICY "Users can delete their own $table by email"
ON public.$table
FOR DELETE
TO authenticated
USING (email = (auth.jwt() ->> 'email'));

EOF
}

generate_role_based_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Role-based (Admin, Manager, User roles)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies
DROP POLICY IF EXISTS "Admins can do anything on $table" ON public.$table;
DROP POLICY IF EXISTS "Managers can manage $table" ON public.$table;
DROP POLICY IF EXISTS "Users can view $table" ON public.$table;

-- ADMIN Policy: Full access
CREATE POLICY "Admins can do anything on $table"
ON public.$table
FOR ALL
TO authenticated
USING (
    (auth.jwt() ->> 'role') = 'admin'
)
WITH CHECK (
    (auth.jwt() ->> 'role') = 'admin'
);

-- MANAGER Policy: Can view and update
CREATE POLICY "Managers can manage $table"
ON public.$table
FOR ALL
TO authenticated
USING (
    (auth.jwt() ->> 'role') IN ('admin', 'manager')
    OR user_id = auth.uid()
)
WITH CHECK (
    (auth.jwt() ->> 'role') IN ('admin', 'manager')
    OR user_id = auth.uid()
);

-- USER Policy: Can only view
CREATE POLICY "Users can view $table"
ON public.$table
FOR SELECT
TO authenticated
USING (true);

-- NOTE: To use role-based policies, you need to add 'role' to JWT claims
-- in your Supabase Auth settings or via database trigger

EOF
}

generate_team_based_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Team-based (Users belong to teams/organizations)
-- =============================================================================

-- Assumption: Table has 'team_id' or 'organization_id' column
-- Users' team membership stored in auth.users metadata or separate table

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- DROP existing policies
DROP POLICY IF EXISTS "Users can view team $table" ON public.$table;
DROP POLICY IF EXISTS "Users can insert team $table" ON public.$table;
DROP POLICY IF EXISTS "Users can update team $table" ON public.$table;
DROP POLICY IF EXISTS "Users can delete team $table" ON public.$table;

-- SELECT Policy: Users can view their team's data
CREATE POLICY "Users can view team $table"
ON public.$table
FOR SELECT
TO authenticated
USING (
    team_id = (auth.jwt() ->> 'team_id')::uuid
    OR user_id = auth.uid()  -- Can also see own data
);

-- INSERT Policy: Users can insert data for their team
CREATE POLICY "Users can insert team $table"
ON public.$table
FOR INSERT
TO authenticated
WITH CHECK (
    team_id = (auth.jwt() ->> 'team_id')::uuid
    AND user_id = auth.uid()
);

-- UPDATE Policy: Users can update their team's data
CREATE POLICY "Users can update team $table"
ON public.$table
FOR UPDATE
TO authenticated
USING (
    team_id = (auth.jwt() ->> 'team_id')::uuid
)
WITH CHECK (
    team_id = (auth.jwt() ->> 'team_id')::uuid
);

-- DELETE Policy: Users can delete their team's data
CREATE POLICY "Users can delete team $table"
ON public.$table
FOR DELETE
TO authenticated
USING (
    team_id = (auth.jwt() ->> 'team_id')::uuid
);

-- NOTE: You need to add 'team_id' to JWT claims via:
-- 1. Database trigger on auth.users
-- 2. Or Supabase Auth settings (app_metadata)

EOF
}

generate_custom_template() {
    local table="$1"

    cat << EOF
-- =============================================================================
-- CUSTOM RLS POLICIES FOR TABLE: $table
-- Generated: $(date)
-- Policy Type: Custom (Edit this template to match your needs)
-- =============================================================================

-- Enable RLS
ALTER TABLE public.$table ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- EXAMPLE 1: Time-based policy (only show data from last 30 days)
-- ============================================================================

DROP POLICY IF EXISTS "Users can view recent $table" ON public.$table;

CREATE POLICY "Users can view recent $table"
ON public.$table
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    AND created_at > now() - interval '30 days'
);

-- ============================================================================
-- EXAMPLE 2: Conditional policy based on column value
-- ============================================================================

DROP POLICY IF EXISTS "Users can view published $table" ON public.$table;

CREATE POLICY "Users can view published $table"
ON public.$table
FOR SELECT
TO authenticated
USING (
    status = 'published'
    OR user_id = auth.uid()  -- Owners can see drafts
);

-- ============================================================================
-- EXAMPLE 3: Complex policy with subquery
-- ============================================================================

DROP POLICY IF EXISTS "Team members can view $table" ON public.$table;

CREATE POLICY "Team members can view $table"
ON public.$table
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
    OR team_id IN (
        SELECT team_id
        FROM team_members
        WHERE user_id = auth.uid()
    )
);

-- ============================================================================
-- EXAMPLE 4: Service role bypass (for backend operations)
-- ============================================================================

DROP POLICY IF EXISTS "Service role has full access to $table" ON public.$table;

CREATE POLICY "Service role has full access to $table"
ON public.$table
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- ============================================================================
-- YOUR CUSTOM POLICIES BELOW
-- ============================================================================

-- Add your custom policies here...

EOF
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

show_usage() {
    cat << EOF
${CYAN}Supabase RLS Policy Template Generator${NC}

Usage: $0 <table_name> [policy_type]

Policy Types:
    --basic         Users can manage their own data (default)
    --public-read   Anyone can read, owners can modify
    --owner-only    Strict isolation - users only see their own data
    --email         Email-based policies (instead of user_id)
    --role          Role-based access (admin/manager/user)
    --team          Team/organization-based access
    --custom        Custom policy template with examples

Examples:
    $0 users                    # Generate basic policies for 'users' table
    $0 posts --public-read      # Public read, owner write
    $0 profiles --email         # Email-based policies
    $0 documents --team         # Team-based policies

Output:
    Generated SQL will be saved to: rls-policies-<table>-<type>.sql

EOF
}

main() {
    # Check arguments
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    TABLE_NAME="$1"
    POLICY_TYPE="${2:---basic}"

    # Remove leading dashes if present
    POLICY_TYPE="${POLICY_TYPE#--}"

    # Generate filename
    OUTPUT_FILE="rls-policies-${TABLE_NAME}-${POLICY_TYPE}.sql"

    log "Generating RLS policy template for table: $TABLE_NAME"
    log "Policy type: $POLICY_TYPE"
    log "Output file: $OUTPUT_FILE"
    echo ""

    # Generate appropriate template
    case "$POLICY_TYPE" in
        basic)
            generate_basic_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        public-read)
            generate_public_read_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        owner-only)
            generate_owner_only_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        email)
            generate_email_based_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        role)
            generate_role_based_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        team)
            generate_team_based_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        custom)
            generate_custom_template "$TABLE_NAME" > "$OUTPUT_FILE"
            ;;
        *)
            warn "Unknown policy type: $POLICY_TYPE"
            show_usage
            exit 1
            ;;
    esac

    ok "Template generated: $OUTPUT_FILE"
    echo ""
    log "Next steps:"
    log "  1. Review and edit the SQL file: $OUTPUT_FILE"
    log "  2. Apply it using: ./setup-rls-policies.sh --custom $OUTPUT_FILE"
    echo ""
    log "Or apply directly:"
    log "  cat $OUTPUT_FILE | docker exec -i -e PGPASSWORD=\$POSTGRES_PASSWORD supabase-db psql -U postgres -d postgres"
}

main "$@"
