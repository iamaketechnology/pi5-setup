#!/bin/bash

################################################################################
# Update RLS Policies to Use Authenticated Role
# Version: 1.0
#
# This script updates all RLS policies that use 'public' role to use
# 'authenticated' role instead.
#
# Usage:
#   sudo bash update-policies-to-authenticated.sh
#
################################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;36m'
readonly NC='\033[0m'

log() { echo -e "${BLUE}[POLICY-UPDATE]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC}      $1"; }
error() { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }

# Configuration
if [[ -n "${SUDO_USER}" ]]; then
    REAL_HOME=$(getent passwd "${SUDO_USER}" | cut -d: -f6)
else
    REAL_HOME="${HOME}"
fi

SUPABASE_DIR="${REAL_HOME}/stacks/supabase"
ENV_FILE="${SUPABASE_DIR}/.env"

# Check prerequisites
if [[ ! -f "${ENV_FILE}" ]]; then
    error ".env file not found at ${ENV_FILE}"
fi

# Get database password
DB_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "${ENV_FILE}" | cut -d= -f2 | tr -d '"' | tr -d "'")
if [[ -z "${DB_PASSWORD}" ]]; then
    error "Could not retrieve database password from .env file"
fi

log "Starting policy update process..."
log "This will update all policies from 'public' role to 'authenticated' role"

# Get list of policies to update
log "Fetching policies that need updating..."
POLICIES=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
    "SELECT tablename || '|' || policyname || '|' || cmd
     FROM pg_policies
     WHERE schemaname = 'public' AND 'public' = ANY(roles)
     ORDER BY tablename, policyname;")

if [[ -z "${POLICIES}" ]]; then
    ok "No policies need updating!"
    exit 0
fi

# Count policies
POLICY_COUNT=$(echo "$POLICIES" | wc -l | tr -d ' ')
log "Found ${POLICY_COUNT} policies to update"

# Update each policy
UPDATED=0
FAILED=0

while IFS='|' read -r table policy cmd; do
    # Trim whitespace
    table=$(echo "$table" | xargs)
    policy=$(echo "$policy" | xargs)
    cmd=$(echo "$cmd" | xargs)

    log "Updating: ${table}.${policy} (${cmd})"

    # Get policy details from pg_policies view
    POLICY_INFO=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
        "SELECT cmd, qual, with_check FROM pg_policies WHERE schemaname = 'public' AND tablename = '${table}' AND policyname = '${policy}';")

    if [[ -z "${POLICY_INFO}" ]]; then
        warn "Could not get definition for ${table}.${policy}, skipping"
        ((FAILED++))
        continue
    fi

    # Parse policy components
    IFS='|' read -r cmd_type qual_expr with_check_expr <<< "$POLICY_INFO"
    cmd_type=$(echo "$cmd_type" | xargs)
    qual_expr=$(echo "$qual_expr" | xargs)
    with_check_expr=$(echo "$with_check_expr" | xargs)

    # Build new policy
    NEW_POLICY="CREATE POLICY \"${policy}\" ON ${table}"

    # Add command type
    if [[ "$cmd_type" != "ALL" ]]; then
        NEW_POLICY="${NEW_POLICY} FOR ${cmd_type}"
    fi

    # Add role
    NEW_POLICY="${NEW_POLICY} TO authenticated"

    # Add USING clause if exists
    if [[ -n "$qual_expr" && "$qual_expr" != "" ]]; then
        NEW_POLICY="${NEW_POLICY} USING (${qual_expr})"
    fi

    # Add WITH CHECK clause if exists
    if [[ -n "$with_check_expr" && "$with_check_expr" != "" ]]; then
        NEW_POLICY="${NEW_POLICY} WITH CHECK (${with_check_expr})"
    fi

    NEW_POLICY="${NEW_POLICY};"

    # Drop the old policy and create new one
    if docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -c \
        "DROP POLICY IF EXISTS \"${policy}\" ON ${table}; ${NEW_POLICY}" > /dev/null 2>&1; then
        ok "✓ ${table}.${policy}"
        ((UPDATED++))
    else
        warn "✗ Failed to update ${table}.${policy}"
        warn "   Command: ${NEW_POLICY}"
        ((FAILED++))
    fi

done <<< "$POLICIES"

# Summary
echo ""
echo "=========================================="
echo "Policy Update Complete"
echo "=========================================="
echo ""
ok "Successfully updated: ${UPDATED} policies"
if [[ ${FAILED} -gt 0 ]]; then
    warn "Failed to update: ${FAILED} policies"
fi
echo ""

# Verify
log "Verifying remaining policies with 'public' role..."
REMAINING=$(docker exec -e PGPASSWORD="${DB_PASSWORD}" supabase-db psql -h localhost -U postgres -d postgres -t -c \
    "SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public' AND 'public' = ANY(roles);")

REMAINING=$(echo "$REMAINING" | xargs)

if [[ "${REMAINING}" -eq 0 ]]; then
    ok "✓ All policies now use 'authenticated' role!"
else
    warn "⚠ ${REMAINING} policies still use 'public' role"
fi

echo ""
ok "Done!"
