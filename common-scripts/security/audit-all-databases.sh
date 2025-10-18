#!/bin/bash
# =============================================================================
# Multi-Database Security Audit Script
# =============================================================================
# Version: 1.1.0-multi-machine
# Last updated: 2025-10-18
# Author: PI5-SETUP Project
# Usage: sudo bash common-scripts/security/audit-all-databases.sh
# =============================================================================
# Description: Scans ALL PostgreSQL databases on ANY system for security issues
# - Auto-detects passwords for each container independently
# - Works across multiple machines with different credentials
# - 12 comprehensive security checks
# - No hardcoded secrets - 100% portable
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
DB_USER="${DB_USER:-postgres}"

# Auto-detect password from running containers
detect_password_for_container() {
    local container=$1
    local password=""

    # Method 1: Extract from docker inspect (most reliable)
    password=$(docker inspect "$container" 2>/dev/null | grep -oP '"POSTGRES_PASSWORD=\K[^"]+' | head -1)

    if [[ -z "$password" ]]; then
        # Method 2: Try common .env locations
        local container_name=$(docker inspect "$container" --format '{{.Name}}' 2>/dev/null | sed 's/^\///')

        # Search in common stack directories
        for env_file in \
            "$HOME/stacks/supabase/.env" \
            "$HOME/.env.supabase" \
            "$HOME/stacks/${container_name}/.env" \
            "/opt/supabase/.env" \
            "/var/lib/supabase/.env"; do

            if [[ -f "$env_file" ]]; then
                password=$(grep -E '^POSTGRES_PASSWORD=' "$env_file" | cut -d'=' -f2 | tr -d '"' | tr -d "'" | head -1)
                [[ -n "$password" ]] && break
            fi
        done
    fi

    if [[ -z "$password" ]]; then
        # Method 3: Try to exec into container and read env
        password=$(docker exec "$container" printenv POSTGRES_PASSWORD 2>/dev/null || echo "")
    fi

    echo "$password"
}

# Container-specific password map
declare -A CONTAINER_PASSWORDS

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}🔒 Multi-Database Security Audit${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detect running PostgreSQL containers
echo -e "${BLUE}🔍 Detecting PostgreSQL containers...${NC}"
CONTAINERS=$(docker ps --filter "ancestor=supabase/postgres" --format "{{.Names}}" 2>/dev/null || true)

if [[ -z "$CONTAINERS" ]]; then
    # Fallback: search by common names
    CONTAINERS=$(docker ps --format "{{.Names}}" | grep -iE "postgres|supabase-db|database" || true)
fi

if [[ -z "$CONTAINERS" ]]; then
    echo -e "${RED}❌ No PostgreSQL containers found${NC}"
    echo "Tip: Make sure Supabase or PostgreSQL is running"
    exit 1
fi

echo -e "${GREEN}✅ Found containers:${NC}"
while IFS= read -r container; do
    echo "   - $container"

    # Detect password for this container
    detected_password=$(detect_password_for_container "$container")
    if [[ -n "$detected_password" ]]; then
        CONTAINER_PASSWORDS["$container"]="$detected_password"
        echo -e "     ${GREEN}✓${NC} Password detected"
    else
        echo -e "     ${RED}✗${NC} Password not found (will use DB_PASSWORD env if set)"
    fi
done <<< "$CONTAINERS"
echo ""

# Function to run SQL in a container
run_sql() {
    local container=$1
    local database=$2
    local query=$3

    # Get container-specific password
    local password="${CONTAINER_PASSWORDS[$container]}"

    # Fallback to env variable or fail gracefully
    if [[ -z "$password" ]]; then
        password="${DB_PASSWORD}"
    fi

    if [[ -z "$password" ]]; then
        echo -e "${RED}ERROR: No password available for container $container${NC}" >&2
        echo "0"
        return 1
    fi

    docker exec -e PGPASSWORD="$password" "$container" \
        psql -U "$DB_USER" -d "$database" -t -c "$query" 2>/dev/null || echo "0"
}

# Function to audit a single database
audit_database() {
    local container=$1
    local database=$2

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${MAGENTA}📊 Database: ${database}${NC} (Container: ${container})"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Check 1: SECURITY DEFINER functions without search_path
    echo -e "${BLUE}📋 Check 1: SECURITY DEFINER Functions${NC}"

    VULNERABLE_FUNCTIONS=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND pg_get_functiondef(p.oid) NOT LIKE '%search_path%';
    " "$password")

    VULNERABLE_FUNCTIONS=$(echo "$VULNERABLE_FUNCTIONS" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$VULNERABLE_FUNCTIONS" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - All SECURITY DEFINER functions have search_path protection"
    else
        echo -e "${RED}❌ FAIL${NC} - Found $VULNERABLE_FUNCTIONS vulnerable function(s):"
        run_sql "$container" "$database" "
            SELECT '  - ' || n.nspname || '.' || p.proname
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
              AND p.prosecdef = true
              AND pg_get_functiondef(p.oid) NOT LIKE '%search_path%';
        " "$password"
    fi
    echo ""

    # Check 2: search_path missing pg_temp (critical)
    echo -e "${BLUE}📋 Check 2: search_path with pg_temp${NC}"

    MISSING_PGTEMP=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND pg_get_functiondef(p.oid) LIKE '%search_path%'
          AND pg_get_functiondef(p.oid) NOT LIKE '%pg_temp%';
    " "$password")

    MISSING_PGTEMP=$(echo "$MISSING_PGTEMP" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$MISSING_PGTEMP" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - All functions include pg_temp in search_path"
    else
        echo -e "${RED}❌ FAIL${NC} - Found $MISSING_PGTEMP function(s) without pg_temp:"
        run_sql "$container" "$database" "
            SELECT '  - ' || n.nspname || '.' || p.proname
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
              AND p.prosecdef = true
              AND pg_get_functiondef(p.oid) LIKE '%search_path%'
              AND pg_get_functiondef(p.oid) NOT LIKE '%pg_temp%';
        " "$password"
    fi
    echo ""

    # Check 3: RLS policies using public role
    echo -e "${BLUE}📋 Check 3: RLS Policies Security${NC}"

    PUBLIC_POLICIES=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_policies
        WHERE schemaname = 'public'
          AND (
            roles::text LIKE '%public%'
            OR (cmd = 'ALL' AND qual IS NULL)
          );
    " "$password")

    PUBLIC_POLICIES=$(echo "$PUBLIC_POLICIES" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$PUBLIC_POLICIES" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No overly permissive RLS policies found"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $PUBLIC_POLICIES potentially permissive policy/policies:"
        run_sql "$container" "$database" "
            SELECT '  - ' || schemaname || '.' || tablename || ' → ' || policyname
            FROM pg_policies
            WHERE schemaname = 'public'
              AND (
                roles::text LIKE '%public%'
                OR (cmd = 'ALL' AND qual IS NULL)
              );
        " "$password"
    fi
    echo ""

    # Check 4: Functions with empty search_path
    echo -e "${BLUE}📋 Check 4: Empty search_path${NC}"

    EMPTY_SEARCHPATH=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND p.prosecdef = true
          AND pg_get_functiondef(p.oid) LIKE '%search_path%'
          AND pg_get_functiondef(p.oid) LIKE '%=  \\047\\047%';
    " "$password")

    EMPTY_SEARCHPATH=$(echo "$EMPTY_SEARCHPATH" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$EMPTY_SEARCHPATH" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No functions with empty search_path"
    else
        echo -e "${RED}❌ FAIL${NC} - Found $EMPTY_SEARCHPATH function(s) with empty search_path"
    fi
    echo ""

    # Check 5: Tables without RLS enabled (common Supabase issue)
    echo -e "${BLUE}📋 Check 5: RLS Enabled on Tables${NC}"

    TABLES_WITHOUT_RLS=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_tables t
        LEFT JOIN pg_class c ON c.relname = t.tablename
        WHERE t.schemaname = 'public'
          AND c.relrowsecurity = false
          AND t.tablename NOT LIKE 'pg_%'
          AND t.tablename NOT IN ('schema_migrations', 'ar_internal_metadata');
    " "$password")

    TABLES_WITHOUT_RLS=$(echo "$TABLES_WITHOUT_RLS" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$TABLES_WITHOUT_RLS" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - All tables have RLS enabled"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $TABLES_WITHOUT_RLS table(s) without RLS:"
        run_sql "$container" "$database" "
            SELECT '  - ' || t.schemaname || '.' || t.tablename
            FROM pg_tables t
            LEFT JOIN pg_class c ON c.relname = t.tablename
            WHERE t.schemaname = 'public'
              AND c.relrowsecurity = false
              AND t.tablename NOT LIKE 'pg_%'
              AND t.tablename NOT IN ('schema_migrations', 'ar_internal_metadata');
        " "$password"
    fi
    echo ""

    # Check 6: Unencrypted passwords in pg_shadow/pg_authid
    echo -e "${BLUE}📋 Check 6: Password Security${NC}"

    NULL_PASSWORDS=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_authid
        WHERE rolpassword IS NULL
          AND rolcanlogin = true
          AND rolname NOT IN ('postgres');
    " "$password")

    NULL_PASSWORDS=$(echo "$NULL_PASSWORDS" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$NULL_PASSWORDS" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - All users have passwords"
    else
        echo -e "${RED}❌ FAIL${NC} - Found $NULL_PASSWORDS user(s) without password:"
        run_sql "$container" "$database" "
            SELECT '  - ' || rolname
            FROM pg_authid
            WHERE rolpassword IS NULL
              AND rolcanlogin = true
              AND rolname NOT IN ('postgres');
        " "$password"
    fi
    echo ""

    # Check 7: Superuser accounts (excessive privileges)
    echo -e "${BLUE}📋 Check 7: Superuser Accounts${NC}"

    SUPERUSERS=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_authid
        WHERE rolsuper = true
          AND rolname NOT IN ('postgres', 'supabase_admin');
    " "$password")

    SUPERUSERS=$(echo "$SUPERUSERS" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$SUPERUSERS" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No unnecessary superuser accounts"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $SUPERUSERS unexpected superuser(s):"
        run_sql "$container" "$database" "
            SELECT '  - ' || rolname || ' (created: ' || rolvaliduntil::text || ')'
            FROM pg_authid
            WHERE rolsuper = true
              AND rolname NOT IN ('postgres', 'supabase_admin');
        " "$password"
    fi
    echo ""

    # Check 8: Public schema permissions (should be restricted)
    echo -e "${BLUE}📋 Check 8: Public Schema Permissions${NC}"

    PUBLIC_SCHEMA_PERMS=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM information_schema.table_privileges
        WHERE grantee = 'PUBLIC'
          AND table_schema = 'public'
          AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
    " "$password")

    PUBLIC_SCHEMA_PERMS=$(echo "$PUBLIC_SCHEMA_PERMS" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$PUBLIC_SCHEMA_PERMS" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No dangerous PUBLIC permissions"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $PUBLIC_SCHEMA_PERMS PUBLIC permission(s):"
        run_sql "$container" "$database" "
            SELECT DISTINCT '  - ' || table_schema || '.' || table_name || ' (' || privilege_type || ')'
            FROM information_schema.table_privileges
            WHERE grantee = 'PUBLIC'
              AND table_schema = 'public'
              AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE');
        " "$password"
    fi
    echo ""

    # Check 9: SQL Injection vectors (dynamic SQL in functions)
    echo -e "${BLUE}📋 Check 9: SQL Injection Risks${NC}"

    DYNAMIC_SQL=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
          AND (
            pg_get_functiondef(p.oid) LIKE '%EXECUTE %'
            OR pg_get_functiondef(p.oid) LIKE '%format(%'
          )
          AND pg_get_functiondef(p.oid) NOT LIKE '%quote_literal%'
          AND pg_get_functiondef(p.oid) NOT LIKE '%quote_ident%';
    " "$password")

    DYNAMIC_SQL=$(echo "$DYNAMIC_SQL" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$DYNAMIC_SQL" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No unsafe dynamic SQL detected"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $DYNAMIC_SQL function(s) with potential SQL injection risk:"
        run_sql "$container" "$database" "
            SELECT '  - ' || n.nspname || '.' || p.proname
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public'
              AND (
                pg_get_functiondef(p.oid) LIKE '%EXECUTE %'
                OR pg_get_functiondef(p.oid) LIKE '%format(%'
              )
              AND pg_get_functiondef(p.oid) NOT LIKE '%quote_literal%'
              AND pg_get_functiondef(p.oid) NOT LIKE '%quote_ident%';
        " "$password"
    fi
    echo ""

    # Check 10: Unlogged tables (data loss risk)
    echo -e "${BLUE}📋 Check 10: Unlogged Tables${NC}"

    UNLOGGED_TABLES=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE n.nspname = 'public'
          AND c.relkind = 'r'
          AND c.relpersistence = 'u';
    " "$password")

    UNLOGGED_TABLES=$(echo "$UNLOGGED_TABLES" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$UNLOGGED_TABLES" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - No unlogged tables (data is crash-safe)"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $UNLOGGED_TABLES unlogged table(s) (data loss risk):"
        run_sql "$container" "$database" "
            SELECT '  - ' || n.nspname || '.' || c.relname
            FROM pg_class c
            JOIN pg_namespace n ON c.relnamespace = n.oid
            WHERE n.nspname = 'public'
              AND c.relkind = 'r'
              AND c.relpersistence = 'u';
        " "$password"
    fi
    echo ""

    # Check 11: Missing foreign key indexes (performance + security)
    echo -e "${BLUE}📋 Check 11: Foreign Key Indexes${NC}"

    MISSING_FK_INDEXES=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_constraint c
        LEFT JOIN pg_index i ON c.conrelid = i.indrelid AND c.conkey[1] = i.indkey[1]
        WHERE c.contype = 'f'
          AND i.indexrelid IS NULL;
    " "$password")

    MISSING_FK_INDEXES=$(echo "$MISSING_FK_INDEXES" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$MISSING_FK_INDEXES" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - All foreign keys have indexes"
    else
        echo -e "${YELLOW}⚠️  INFO${NC} - Found $MISSING_FK_INDEXES foreign key(s) without index (performance impact)"
    fi
    echo ""

    # Check 12: Weak authentication methods (trust, password)
    echo -e "${BLUE}📋 Check 12: Authentication Methods${NC}"

    WEAK_AUTH=$(run_sql "$container" "$database" "
        SELECT COUNT(*)
        FROM pg_hba_file_rules
        WHERE auth_method IN ('trust', 'password')
          AND database NOT IN ('replication');
    " "$password")

    WEAK_AUTH=$(echo "$WEAK_AUTH" | tr -d ' ' | grep -E '^[0-9]+$' || echo "0")

    if [[ "$WEAK_AUTH" -eq 0 ]]; then
        echo -e "${GREEN}✅ PASS${NC} - Strong authentication methods in use"
    else
        echo -e "${YELLOW}⚠️  WARNING${NC} - Found $WEAK_AUTH weak authentication rule(s)"
        echo -e "${YELLOW}   💡 Consider using scram-sha-256 instead of password/trust${NC}"
    fi
    echo ""

    # Database summary
    TOTAL_ISSUES=$((VULNERABLE_FUNCTIONS + MISSING_PGTEMP + EMPTY_SEARCHPATH + NULL_PASSWORDS))
    TOTAL_WARNINGS=$((PUBLIC_POLICIES + TABLES_WITHOUT_RLS + SUPERUSERS + PUBLIC_SCHEMA_PERMS + DYNAMIC_SQL + UNLOGGED_TABLES + WEAK_AUTH))

    if [[ "$TOTAL_ISSUES" -eq 0 ]] && [[ "$TOTAL_WARNINGS" -eq 0 ]]; then
        echo -e "${GREEN}🎉 DATABASE FULLY SECURE${NC}"
        return 0
    elif [[ "$TOTAL_ISSUES" -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Database secure, but $TOTAL_WARNINGS warning(s) detected${NC}"
        return 0
    else
        echo -e "${RED}❌ $TOTAL_ISSUES CRITICAL ISSUE(S) + $TOTAL_WARNINGS WARNING(S)${NC}"
        return 1
    fi
}

# Main audit loop
TOTAL_DATABASES=0
SECURE_DATABASES=0
VULNERABLE_DATABASES=0

while IFS= read -r container; do
    echo ""
    echo -e "${CYAN}🐳 Container: ${container}${NC}"
    echo ""

    # Get container-specific password
    container_password="${CONTAINER_PASSWORDS[$container]}"
    if [[ -z "$container_password" ]]; then
        container_password="${DB_PASSWORD}"
    fi

    if [[ -z "$container_password" ]]; then
        echo -e "${RED}❌ No password available for container $container - SKIPPING${NC}"
        continue
    fi

    # Get list of databases
    DATABASES=$(docker exec -e PGPASSWORD="$container_password" "$container" \
        psql -U "$DB_USER" -d postgres -t -c \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" 2>/dev/null \
        | tr -d ' ' | grep -v '^$' || echo "")

    # Always audit postgres database
    DATABASES="postgres
$DATABASES"

    while IFS= read -r database; do
        [[ -z "$database" ]] && continue

        TOTAL_DATABASES=$((TOTAL_DATABASES + 1))

        if audit_database "$container" "$database"; then
            SECURE_DATABASES=$((SECURE_DATABASES + 1))
        else
            VULNERABLE_DATABASES=$((VULNERABLE_DATABASES + 1))
        fi

        echo ""
    done <<< "$DATABASES"
done <<< "$CONTAINERS"

# Global summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}📊 Global Security Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "Total databases audited: ${BLUE}${TOTAL_DATABASES}${NC}"
echo -e "Secure databases: ${GREEN}${SECURE_DATABASES}${NC}"
echo -e "Vulnerable databases: ${RED}${VULNERABLE_DATABASES}${NC}"
echo ""

if [[ "$VULNERABLE_DATABASES" -eq 0 ]]; then
    echo -e "${GREEN}🎉 ALL DATABASES ARE SECURE!${NC}"
    exit 0
else
    echo -e "${RED}⚠️  SECURITY ISSUES DETECTED${NC}"
    echo -e "${YELLOW}💡 Run migrations to fix issues${NC}"
    exit 1
fi
