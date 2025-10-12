#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - APPS ENVIRONMENT SETUP
#==============================================================================
# Version: 1.0.0
# Description: Initialize /opt/apps/ structure for deploying React/Next.js apps
# Architecture: ARM64 (Raspberry Pi 5)
# Requirements: Docker, Docker Compose, Traefik
#
# This script:
# - Creates /opt/apps/ directory structure
# - Copies templates to /opt/pi5-apps-stack/
# - Configures permissions
# - Validates prerequisites
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../01-apps-setup.sh | sudo bash
#   OR
#   sudo bash 01-apps-setup.sh
#==============================================================================

set -euo pipefail

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly APPS_DIR="/opt/apps"
readonly APPS_STACK_DIR="/opt/pi5-apps-stack"
readonly LOG_DIR="/var/log/pi5-apps"
readonly LOG_FILE="${LOG_DIR}/apps-setup.log"

# Common scripts library
readonly COMMON_SCRIPTS_DIR="/opt/pi5-setup/common-scripts"
if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
    source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
    # Fallback functions
    log() { echo -e "\033[36m[INFO]\033[0m $*"; }
    warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
    ok() { echo -e "\033[32m[OK]\033[0m $*"; }
    error() { echo -e "\033[31m[ERROR]\033[0m $* (line ${BASH_LINENO[0]})" >&2; exit 1; }
fi

#------------------------------------------------------------------------------
# HELPER FUNCTIONS
#------------------------------------------------------------------------------

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_dependencies() {
    log "Checking dependencies..."

    local missing_deps=()

    if ! command -v docker &>/dev/null; then
        missing_deps+=("docker")
    fi

    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        missing_deps+=("docker-compose")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing_deps[*]}\nRun: curl -fsSL https://raw.githubusercontent.com/.../01-prerequisites-setup.sh | sudo bash"
    fi

    # Check if Traefik is running
    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        warn "Traefik is not running. HTTPS routing will not work."
        warn "Deploy Traefik first: curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-*.sh | sudo bash"
    fi

    ok "All dependencies satisfied"
}

detect_supabase() {
    log "Detecting Supabase installation..."

    local supabase_env=""

    if [[ -f "/opt/pi5-supabase/.env" ]]; then
        supabase_env="/opt/pi5-supabase/.env"
    elif [[ -f "/opt/supabase/.env" ]]; then
        supabase_env="/opt/supabase/.env"
    else
        warn "Supabase not found. Apps won't have Supabase credentials auto-injected."
        return 1
    fi

    # Extract Supabase credentials
    if [[ -f "$supabase_env" ]]; then
        SUPABASE_URL=$(grep -E '^(SUPABASE_URL|PUBLIC_REST_URL)' "$supabase_env" | cut -d= -f2 | tr -d '"' | head -1)
        SUPABASE_ANON_KEY=$(grep -E '^ANON_KEY' "$supabase_env" | cut -d= -f2 | tr -d '"')
        SUPABASE_SERVICE_ROLE_KEY=$(grep -E '^SERVICE_ROLE_KEY' "$supabase_env" | cut -d= -f2 | tr -d '"')

        ok "Supabase found: ${SUPABASE_URL}"
        export SUPABASE_URL SUPABASE_ANON_KEY SUPABASE_SERVICE_ROLE_KEY
        return 0
    fi

    return 1
}

detect_traefik_cert_resolver() {
    log "Detecting Traefik certificate resolver..."

    local traefik_env=""

    if [[ -f "/opt/pi5-traefik/.env" ]]; then
        traefik_env="/opt/pi5-traefik/.env"
    elif [[ -f "/opt/traefik/.env" ]]; then
        traefik_env="/opt/traefik/.env"
    else
        warn "Traefik .env not found, using default cert resolver: letsencrypt"
        echo "letsencrypt"
        return
    fi

    if grep -q "CERT_RESOLVER=cloudflare" "$traefik_env"; then
        echo "cloudflare"
    elif grep -q "CERT_RESOLVER=duckdns" "$traefik_env"; then
        echo "duckdns"
    else
        echo "letsencrypt"
    fi
}

create_directories() {
    log "Creating directories..."

    mkdir -p "$LOG_DIR" "$APPS_DIR" "${APPS_STACK_DIR}"/{templates,scripts,config}
    chmod 755 "$LOG_DIR" "$APPS_DIR" "$APPS_STACK_DIR"

    ok "Directories created"
}

copy_templates() {
    log "Copying templates to ${APPS_STACK_DIR}..."

    # Copy templates
    cp -r "${PROJECT_ROOT}/templates" "${APPS_STACK_DIR}/"
    cp -r "${PROJECT_ROOT}/scripts" "${APPS_STACK_DIR}/"
    cp -r "${PROJECT_ROOT}/examples" "${APPS_STACK_DIR}/"

    # Make scripts executable
    chmod +x "${APPS_STACK_DIR}"/scripts/*.sh
    chmod +x "${APPS_STACK_DIR}"/scripts/utils/*.sh

    ok "Templates copied"
}

create_global_config() {
    log "Creating global apps configuration..."

    local cert_resolver
    cert_resolver=$(detect_traefik_cert_resolver)

    cat > "${APPS_STACK_DIR}/config/apps.conf" <<EOF
#==============================================================================
# PI5-APPS-STACK - GLOBAL CONFIGURATION
#==============================================================================
# Generated: $(date)
# Version: ${SCRIPT_VERSION}
#==============================================================================

# Directories
APPS_DIR="${APPS_DIR}"
APPS_STACK_DIR="${APPS_STACK_DIR}"

# Traefik Configuration
CERT_RESOLVER="${cert_resolver}"

# Supabase Configuration (auto-detected)
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
SUPABASE_SERVICE_ROLE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-}"

#==============================================================================
# NOTES
#==============================================================================
# This file is sourced by deployment scripts to auto-inject credentials
# Edit manually if Supabase credentials change
#==============================================================================
EOF

    chmod 644 "${APPS_STACK_DIR}/config/apps.conf"
    ok "Global config created"
}

create_helper_aliases() {
    log "Creating shell aliases..."

    cat > /etc/profile.d/pi5-apps.sh <<'EOF'
# PI5-APPS-STACK Shell Aliases

alias apps-list='sudo bash /opt/pi5-apps-stack/scripts/utils/list-apps.sh'
alias apps-deploy='sudo bash /opt/pi5-apps-stack/scripts/utils/deploy-app.sh'
alias apps-remove='sudo bash /opt/pi5-apps-stack/scripts/utils/remove-app.sh'
alias apps-update='sudo bash /opt/pi5-apps-stack/scripts/utils/update-app.sh'
alias apps-logs='sudo bash /opt/pi5-apps-stack/scripts/utils/logs-app.sh'
EOF

    chmod 644 /etc/profile.d/pi5-apps.sh

    ok "Shell aliases created (run 'source /etc/profile.d/pi5-apps.sh' to load)"
}

print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              PI5-APPS-STACK SETUP COMPLETE                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📂 DIRECTORIES"
    echo "   Apps:        ${APPS_DIR}/"
    echo "   Templates:   ${APPS_STACK_DIR}/templates/"
    echo "   Scripts:     ${APPS_STACK_DIR}/scripts/"
    echo "   Logs:        ${LOG_DIR}/"
    echo ""
    echo "🚀 AVAILABLE TEMPLATES"
    echo "   - nextjs-ssr       Next.js with SSR (standalone output)"
    echo "   - react-spa        React SPA (Vite/CRA + Nginx)"
    echo "   - nodejs-api       Node.js Express API"
    echo ""
    echo "🔧 DEPLOYMENT SCRIPTS"
    echo "   Deploy Next.js:   sudo bash ${APPS_STACK_DIR}/scripts/utils/deploy-nextjs-app.sh <name> <domain> [git-repo]"
    echo "   Deploy React:     sudo bash ${APPS_STACK_DIR}/scripts/utils/deploy-react-spa.sh <name> <domain> [git-repo]"
    echo "   List apps:        sudo bash ${APPS_STACK_DIR}/scripts/utils/list-apps.sh"
    echo ""
    echo "💡 QUICK START EXAMPLE"
    echo "   # Deploy a Next.js app"
    echo "   sudo bash ${APPS_STACK_DIR}/scripts/utils/deploy-nextjs-app.sh \\"
    echo "       myapp \\"
    echo "       app.yourdomain.com \\"
    echo "       https://github.com/user/myapp.git"
    echo ""
    echo "   # Access: https://app.yourdomain.com"
    echo ""
    echo "🔑 SUPABASE INTEGRATION"
    if [[ -n "${SUPABASE_URL:-}" ]]; then
        echo "   ✅ Supabase detected: ${SUPABASE_URL}"
        echo "   Apps will auto-receive Supabase credentials"
    else
        echo "   ⚠️  Supabase not found"
        echo "   Deploy Supabase first or manually configure credentials"
    fi
    echo ""
    echo "📚 DOCUMENTATION"
    echo "   Templates:   ${APPS_STACK_DIR}/templates/*/README.md"
    echo "   Examples:    ${APPS_STACK_DIR}/examples/"
    echo ""
    echo "🔄 SHELL ALIASES (reload shell to activate)"
    echo "   apps-list    List deployed apps"
    echo "   apps-deploy  Deploy new app"
    echo "   apps-remove  Remove app"
    echo "   apps-update  Update app"
    echo ""
    echo "✅ Setup completed successfully!"
    echo ""
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              PI5-APPS-STACK - SETUP                           ║"
    echo "║          React/Next.js Apps Deployment Environment           ║"
    echo "║                    Version ${SCRIPT_VERSION}                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    create_directories

    # Log to file
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1

    log "Starting apps environment setup..."

    check_dependencies
    detect_supabase || true
    copy_templates
    create_global_config
    create_helper_aliases

    print_summary

    ok "Script completed successfully"
}

# Run main
main "$@"
