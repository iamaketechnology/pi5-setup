#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Complete CORS Fix for Supabase (Kong + .env)
# =============================================================================
# Purpose: Fix CORS for both Kong configuration and .env file
# Usage: sudo ./fix-cors-complete.sh [localhost_port]
# Author: PI5-SETUP Project
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[CORS-FIX]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]   \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.3.0"
TARGET_USER="${SUDO_USER:-pi}"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
ENV_FILE="${SUPABASE_DIR}/.env"
KONG_CONFIG="${SUPABASE_DIR}/volumes/kong/kong.yml"
BACKUP_DIR="${SUPABASE_DIR}/backups"
LOCALHOST_PORT="${1:-8080}"

# Error handling
error_exit() {
    error "$1"
    exit 1
}

trap 'error_exit "Script failed at line $LINENO"' ERR

# =============================================================================
# VALIDATION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root"
        echo "Usage: sudo $0 [port]"
        exit 1
    fi
}

check_supabase() {
    log "Checking Supabase installation..."

    if [[ ! -d "$SUPABASE_DIR" ]]; then
        error_exit "Supabase directory not found at $SUPABASE_DIR"
    fi

    if [[ ! -f "$ENV_FILE" ]]; then
        error_exit "Supabase .env file not found at $ENV_FILE"
    fi

    if [[ ! -f "$KONG_CONFIG" ]]; then
        error_exit "Kong configuration file not found at $KONG_CONFIG"
    fi

    ok "Supabase installation found"
}

# =============================================================================
# BACKUP
# =============================================================================

create_backups() {
    log "Creating backups..."

    mkdir -p "$BACKUP_DIR"
    local timestamp=$(date +%Y%m%d_%H%M%S)

    # Backup .env
    cp "$ENV_FILE" "$BACKUP_DIR/.env.backup-$timestamp"
    ok "Backup created: .env.backup-$timestamp"

    # Backup kong.yml
    cp "$KONG_CONFIG" "$BACKUP_DIR/kong.yml.backup-$timestamp"
    ok "Backup created: kong.yml.backup-$timestamp"
}

# =============================================================================
# FIX .ENV FILE
# =============================================================================

fix_env_file() {
    log "Fixing .env file CORS configuration..."

    local local_ip=$(hostname -I | awk '{print $1}')

    # Build CORS URLs list
    local cors_urls="http://localhost:${LOCALHOST_PORT}"
    cors_urls="${cors_urls},http://localhost:5173"
    cors_urls="${cors_urls},http://localhost:3000"
    cors_urls="${cors_urls},http://${local_ip}:${LOCALHOST_PORT}"
    cors_urls="${cors_urls},http://${local_ip}:5173"
    cors_urls="${cors_urls},http://${local_ip}:3000"

    # Clean any ANSI codes from .env file
    log "Cleaning ANSI codes from .env..."
    sed -i 's/\x1b\[[0-9;]*m//g' "$ENV_FILE"

    # Remove corrupted CORS lines (if any)
    sed -i '/^.*\[CORS\].*$/d' "$ENV_FILE"
    sed -i '/^.*Detecting IPv4.*$/d' "$ENV_FILE"
    sed -i '/^.*\[OK\].*$/d' "$ENV_FILE"
    sed -i '/^.*\[INFO\].*$/d' "$ENV_FILE"
    sed -i '/^.*\[WARN\].*$/d' "$ENV_FILE"
    sed -i '/^.*Local IP detected.*$/d' "$ENV_FILE"
    sed -i '/^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}:[0-9]\+.*$/d' "$ENV_FILE"

    # Remove empty lines at end of file
    sed -i -e :a -e '/^\s*$/d;N;ba' "$ENV_FILE"

    # Check if ADDITIONAL_REDIRECT_URLS exists
    if grep -q "^ADDITIONAL_REDIRECT_URLS=" "$ENV_FILE"; then
        # Update existing
        sed -i "s|^ADDITIONAL_REDIRECT_URLS=.*|ADDITIONAL_REDIRECT_URLS=\"${cors_urls}\"|" "$ENV_FILE"
        ok "Updated ADDITIONAL_REDIRECT_URLS"
    else
        # Add new
        echo "" >> "$ENV_FILE"
        echo "# CORS Configuration for Localhost (added $(date))" >> "$ENV_FILE"
        echo "ADDITIONAL_REDIRECT_URLS=\"${cors_urls}\"" >> "$ENV_FILE"
        ok "Added ADDITIONAL_REDIRECT_URLS"
    fi

    # Check SITE_URL
    if ! grep -q "^SITE_URL=" "$ENV_FILE"; then
        echo "SITE_URL=\"http://localhost:${LOCALHOST_PORT}\"" >> "$ENV_FILE"
        ok "Added SITE_URL"
    fi
}

# =============================================================================
# FIX KONG CONFIG
# =============================================================================

fix_kong_config() {
    log "Fixing Kong CORS configuration..."

    # Check if CORS plugin already exists for auth-v1-open with all required headers
    if grep -A 40 "name: auth-v1-open" "$KONG_CONFIG" | grep -A 30 "name: cors" | grep -q "x-supabase-api-version"; then
        if grep -A 40 "name: auth-v1-open" "$KONG_CONFIG" | grep -A 30 "name: cors" | grep -q "preflight_continue"; then
            ok "CORS configuration already complete with all headers and preflight_continue"
            return 0
        fi
    fi

    log "Removing existing incomplete CORS configuration (if any)..."

    # Remove any existing CORS plugin from auth-v1-open service
    # This uses sed to delete lines between the cors plugin start and its end
    local temp_clean=$(mktemp)

    # Create a clean version by removing the plugins section if it exists
    awk '
    BEGIN { in_auth = 0; in_plugins = 0; in_cors = 0; skip_until_next_service = 0 }
    /^  - name: auth-v1-open$/ { in_auth = 1 }
    in_auth && /^    plugins:$/ {
        in_plugins = 1
        skip_until_next_service = 1
        next
    }
    skip_until_next_service && /^  - name:/ {
        skip_until_next_service = 0
        in_auth = 0
        in_plugins = 0
    }
    skip_until_next_service { next }
    { print }
    ' "$KONG_CONFIG" > "$temp_clean"

    mv "$temp_clean" "$KONG_CONFIG"

    log "Adding complete CORS plugin with all required headers..."

    # Create CORS plugin configuration in a temp file
    local cors_config=$(mktemp)
    cat > "$cors_config" << 'CORS_CONFIG'
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - PATCH
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Accept-Language
            - Content-Language
            - Content-Type
            - Authorization
            - apikey
            - x-client-info
            - x-supabase-api-version
          exposed_headers:
            - X-Total-Count
          credentials: true
          preflight_continue: false

CORS_CONFIG

    # Find line number where to insert (just before auth-v1-admin service)
    local insert_before_line=$(grep -n "^  - name: auth-v1-admin" "$KONG_CONFIG" | head -1 | cut -d: -f1)

    if [[ -z "$insert_before_line" ]]; then
        error_exit "Could not find auth-v1-admin service in kong.yml"
    fi

    local insert_line=$((insert_before_line - 1))

    # Insert CORS configuration
    sed -i "${insert_line}r $cors_config" "$KONG_CONFIG"

    # Cleanup temp file
    rm -f "$cors_config"

    # Fix permissions on kong.yml (must be readable by Kong container)
    chmod 644 "$KONG_CONFIG"

    # Clean up temp files
    rm -f /tmp/kong-*.yml /tmp/tmp.*

    ok "CORS plugin added to Kong configuration"
}

# =============================================================================
# CLEANUP
# =============================================================================

cleanup_residual_files() {
    log "Cleaning up residual files on Pi..."

    # Remove any leftover temp files from previous runs
    rm -f /tmp/fix-cors-*.sh
    rm -f /tmp/kong-*.yml
    rm -f /tmp/tmp.*
    rm -f /tmp/*.backup

    # Clean old backups (keep last 10)
    if [[ -d "$BACKUP_DIR" ]]; then
        ls -t "$BACKUP_DIR"/kong.yml.backup-* 2>/dev/null | tail -n +11 | xargs -r rm -f
        ls -t "$BACKUP_DIR"/.env.backup-* 2>/dev/null | tail -n +11 | xargs -r rm -f
    fi

    ok "Cleanup complete"
}

# =============================================================================
# RESTART SERVICES
# =============================================================================

restart_services() {
    log "Restarting Supabase services..."

    cd "$SUPABASE_DIR"

    log "Stopping services..."
    sudo -u "$TARGET_USER" docker compose down

    sleep 3

    log "Starting services..."
    sudo -u "$TARGET_USER" docker compose up -d

    log "Waiting for services to be healthy..."
    sleep 15

    # Check health
    local healthy_count=$(docker ps --filter "name=supabase" --format '{{.Status}}' | grep -c "healthy" || true)

    if [[ $healthy_count -gt 5 ]]; then
        ok "Services restarted successfully ($healthy_count/10 healthy)"
    else
        warn "Services restarted but some may still be initializing ($healthy_count/10 healthy)"
        warn "Wait 30-60 seconds and check with: docker ps"
    fi
}

# =============================================================================
# VERIFICATION
# =============================================================================

verify_configuration() {
    log "Verifying configuration..."

    echo ""
    echo "=========================================="
    echo "📋 .env Configuration:"
    echo "=========================================="
    grep "ADDITIONAL_REDIRECT_URLS" "$ENV_FILE" 2>/dev/null || echo "Not found"
    grep "SITE_URL" "$ENV_FILE" 2>/dev/null || echo "Not found"

    echo ""
    echo "=========================================="
    echo "📋 Kong CORS Plugin:"
    echo "=========================================="
    if grep -A 30 "name: auth-v1-open" "$KONG_CONFIG" | grep -q "name: cors"; then
        ok "CORS plugin configured in Kong"
    else
        error "CORS plugin NOT found in Kong config"
    fi

    echo ""
}

# =============================================================================
# SUMMARY
# =============================================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "🎉 Complete CORS Fix Applied"
    echo "=========================================="
    echo ""
    echo "✅ What was fixed:"
    echo "   1. .env file - CORS URLs configured"
    echo "   2. Kong config - CORS plugin added to auth service"
    echo "   3. Services restarted"
    echo ""
    echo "📝 Configuration:"
    echo "   - Localhost ports: ${LOCALHOST_PORT}, 5173, 3000"
    echo "   - Local IP variations included"
    echo "   - CORS origins: * (wildcard for development)"
    echo ""
    echo "💾 Backups created in: $BACKUP_DIR"
    echo ""
    echo "🧪 Test your app now!"
    echo "   Your localhost app should connect without CORS errors."
    echo ""
    echo "🔙 Rollback (if needed):"
    echo "   cd $SUPABASE_DIR"
    echo "   cp backups/.env.backup-* .env"
    echo "   cp backups/kong.yml.backup-* volumes/kong/kong.yml"
    echo "   docker compose restart"
    echo ""
    echo "📊 Check services:"
    echo "   docker ps --filter name=supabase"
    echo ""
    echo "⚠️  If Kong shows DNS errors (name resolution failed):"
    echo "   1. Try: sudo reboot"
    echo "   2. This resets Docker network and fixes DNS resolution"
    echo ""
    echo "=========================================="
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root

    echo ""
    log "=== Complete CORS Fix for Supabase ==="
    log "Version: $SCRIPT_VERSION"
    log "Port: $LOCALHOST_PORT"
    echo ""

    # Cleanup residual files from previous runs
    cleanup_residual_files
    echo ""

    # Validation
    check_supabase
    echo ""

    # Backup
    create_backups
    echo ""

    # Fix .env
    fix_env_file
    echo ""

    # Fix Kong
    fix_kong_config
    echo ""

    # Restart
    restart_services
    echo ""

    # Verify
    verify_configuration

    # Final cleanup
    cleanup_residual_files
    echo ""

    # Summary
    show_summary
}

main "$@"
