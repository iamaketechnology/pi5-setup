#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Configure Supabase CORS for Localhost Development
# =============================================================================
# Purpose: Allow localhost access to Supabase for local development
# Usage: ./configure-cors-localhost.sh [localhost_port]
# Author: PI5-SETUP Project
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[CORS]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
TARGET_USER="${SUDO_USER:-pi}"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
ENV_FILE="${SUPABASE_DIR}/.env"
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

    ok "Supabase installation found"
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

backup_env_file() {
    log "Creating backup of .env file..."

    mkdir -p "$BACKUP_DIR"
    local backup_file="$BACKUP_DIR/.env.backup-$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$backup_file"

    ok "Backup created: $backup_file"
}

detect_local_ip() {
    log "Detecting local IP addresses..."

    # Get main local IP
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    ok "Local IP detected: $LOCAL_IP"
    echo "$LOCAL_IP"
}

configure_cors() {
    log "Configuring CORS for localhost development..."

    local local_ip=$(detect_local_ip)

    # Build CORS URLs list
    local cors_urls="http://localhost:${LOCALHOST_PORT}"
    cors_urls="${cors_urls},http://localhost:5173"  # Vite default
    cors_urls="${cors_urls},http://localhost:3000"  # Next.js default
    cors_urls="${cors_urls},http://${local_ip}:${LOCALHOST_PORT}"
    cors_urls="${cors_urls},http://${local_ip}:5173"
    cors_urls="${cors_urls},http://${local_ip}:3000"

    log "CORS URLs to add: $cors_urls"

    # Check if ADDITIONAL_REDIRECT_URLS exists
    if grep -q "^ADDITIONAL_REDIRECT_URLS=" "$ENV_FILE"; then
        # Variable exists, update it
        log "Updating existing ADDITIONAL_REDIRECT_URLS..."

        # Get current value
        local current_value=$(grep "^ADDITIONAL_REDIRECT_URLS=" "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

        # Merge with new URLs (avoid duplicates)
        if [[ -n "$current_value" ]]; then
            # Combine and deduplicate
            local combined="${current_value},${cors_urls}"
            local unique_urls=$(echo "$combined" | tr ',' '\n' | sort -u | tr '\n' ',' | sed 's/,$//')
            cors_urls="$unique_urls"
        fi

        # Update in file
        sed -i.bak "s|^ADDITIONAL_REDIRECT_URLS=.*|ADDITIONAL_REDIRECT_URLS=\"${cors_urls}\"|" "$ENV_FILE"
    else
        # Variable doesn't exist, add it
        log "Adding ADDITIONAL_REDIRECT_URLS to .env..."
        echo "" >> "$ENV_FILE"
        echo "# CORS Configuration for Localhost (added $(date))" >> "$ENV_FILE"
        echo "ADDITIONAL_REDIRECT_URLS=\"${cors_urls}\"" >> "$ENV_FILE"
    fi

    # Check if SITE_URL exists and update
    if ! grep -q "^SITE_URL=" "$ENV_FILE"; then
        echo "SITE_URL=\"http://localhost:${LOCALHOST_PORT}\"" >> "$ENV_FILE"
    fi

    ok "CORS configuration updated"
}

restart_supabase() {
    log "Restarting Supabase services..."

    cd "$SUPABASE_DIR"

    log "Stopping services..."
    sudo -u "$TARGET_USER" docker compose stop kong auth

    sleep 2

    log "Starting services..."
    sudo -u "$TARGET_USER" docker compose start kong auth

    sleep 5

    # Check if services are healthy
    if docker ps | grep -q "supabase-kong.*healthy"; then
        ok "Services restarted successfully"
    else
        warn "Services restarted but health check pending (wait ~30s)"
    fi
}

verify_configuration() {
    log "Verifying CORS configuration..."

    echo ""
    echo "=========================================="
    echo "Current CORS Configuration:"
    echo "=========================================="
    grep "ADDITIONAL_REDIRECT_URLS" "$ENV_FILE" || echo "Not configured"
    grep "SITE_URL" "$ENV_FILE" || echo "Not configured"
    echo ""
}

show_summary() {
    echo ""
    echo "=========================================="
    echo "🎉 CORS Configuration Complete"
    echo "=========================================="
    echo ""
    echo "✅ Localhost access enabled for:"
    echo "   - http://localhost:${LOCALHOST_PORT}"
    echo "   - http://localhost:5173 (Vite)"
    echo "   - http://localhost:3000 (Next.js)"
    echo "   - Local IP variations"
    echo ""
    echo "📝 Configuration file: $ENV_FILE"
    echo "💾 Backup created in: $BACKUP_DIR"
    echo ""
    echo "🔄 Services restarted:"
    echo "   - supabase-kong (API Gateway)"
    echo "   - supabase-auth (Authentication)"
    echo ""
    echo "🧪 Test your app now!"
    echo "   Your local dev app should now connect successfully."
    echo ""
    echo "⚠️  Important:"
    echo "   - This configuration is for DEVELOPMENT only"
    echo "   - For production, use proper domain/HTTPS"
    echo "   - CORS is now open to localhost (secure in dev)"
    echo ""
    echo "🔙 Rollback (if needed):"
    echo "   Latest backup: $(ls -t "$BACKUP_DIR"/.env.backup-* 2>/dev/null | head -n1)"
    echo "   sudo cp <backup_file> $ENV_FILE"
    echo "   cd $SUPABASE_DIR && sudo docker compose restart kong auth"
    echo ""
    echo "=========================================="
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root

    echo ""
    log "=== Supabase CORS Configuration for Localhost ==="
    log "Version: $SCRIPT_VERSION"
    log "Port: $LOCALHOST_PORT"
    echo ""

    # Validation
    check_supabase
    echo ""

    # Backup
    backup_env_file
    echo ""

    # Configure
    configure_cors
    echo ""

    # Restart
    restart_supabase
    echo ""

    # Verify
    verify_configuration

    # Summary
    show_summary
}

main "$@"
