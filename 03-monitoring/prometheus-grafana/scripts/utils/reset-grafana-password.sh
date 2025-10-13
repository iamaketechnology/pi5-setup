#!/bin/bash
# =============================================================================
# Grafana Password Reset Script
# =============================================================================
#
# Description: Reset Grafana admin password
# Usage: sudo bash reset-grafana-password.sh [NEW_PASSWORD]
# Version: 1.0.0
#
# =============================================================================

set -euo pipefail

# Colors for output
log()   { echo -e "\033[1;36m[GRAFANA]   \033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]      \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]        \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]     \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
TARGET_USER="${SUDO_USER:-pi}"
MONITORING_DIR="/home/${TARGET_USER}/stacks/monitoring"
CONTAINER_NAME="grafana"

# =============================================================================
# FUNCTIONS
# =============================================================================

error_exit() {
    error "$1"
    exit 1
}

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)"
    fi

    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        error_exit "Docker is not running"
    fi

    # Check if Grafana container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error_exit "Grafana container not found. Is monitoring stack deployed?"
    fi

    # Check if Grafana container is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        error_exit "Grafana container is not running. Start it first: cd ${MONITORING_DIR} && docker compose up -d"
    fi

    # Check if monitoring directory exists
    if [[ ! -d "$MONITORING_DIR" ]]; then
        error_exit "Monitoring directory not found: ${MONITORING_DIR}"
    fi

    ok "All prerequisites met"
}

prompt_new_password() {
    log "Enter new Grafana admin password..."
    echo ""

    # Check if password provided as argument
    if [[ -n "${1:-}" ]]; then
        NEW_PASSWORD="$1"
        log "Using password from command line argument"
    else
        # Prompt for password
        while true; do
            read -sp "New password (min 8 chars, or press Enter for default 'Monitoring2025!Pi5'): " password1
            echo ""

            # Use default if empty
            if [[ -z "$password1" ]]; then
                NEW_PASSWORD="Monitoring2025!Pi5"
                log "Using default password: Monitoring2025!Pi5"
                break
            fi

            # Validate length
            if [[ ${#password1} -lt 8 ]]; then
                warn "Password must be at least 8 characters long"
                continue
            fi

            # Confirm password
            read -sp "Confirm password: " password2
            echo ""

            if [[ "$password1" == "$password2" ]]; then
                NEW_PASSWORD="$password1"
                ok "Password confirmed"
                break
            else
                warn "Passwords do not match. Please try again."
                echo ""
            fi
        done
    fi

    echo ""
}

reset_password() {
    log "Resetting Grafana admin password..."

    # Reset password using Grafana CLI
    if docker exec "$CONTAINER_NAME" grafana cli admin reset-admin-password "$NEW_PASSWORD" >/dev/null 2>&1; then
        ok "Password reset successfully in Grafana"
    else
        error_exit "Failed to reset password in Grafana container"
    fi
}

update_env_file() {
    log "Updating .env file..."

    local env_file="${MONITORING_DIR}/.env"

    if [[ ! -f "$env_file" ]]; then
        warn ".env file not found at ${env_file}"
        log "Creating new .env file..."
        echo "GRAFANA_ADMIN_PASSWORD=${NEW_PASSWORD}" > "$env_file"
        chmod 600 "$env_file"
        chown "${TARGET_USER}:${TARGET_USER}" "$env_file"
    else
        # Update existing .env file
        if grep -q "^GRAFANA_ADMIN_PASSWORD=" "$env_file"; then
            sed -i "s|^GRAFANA_ADMIN_PASSWORD=.*|GRAFANA_ADMIN_PASSWORD=${NEW_PASSWORD}|" "$env_file"
            ok ".env file updated"
        else
            echo "GRAFANA_ADMIN_PASSWORD=${NEW_PASSWORD}" >> "$env_file"
            ok "Password added to .env file"
        fi
    fi
}

update_credentials_file() {
    log "Updating CREDENTIALS.txt..."

    local creds_file="${MONITORING_DIR}/CREDENTIALS.txt"

    # Update or create credentials file
    cat > "$creds_file" << EOF
# Monitoring Stack Credentials
# Last updated: $(date)

## Grafana Access
URL: https://$(grep 'GRAFANA_ROOT_URL=' "${MONITORING_DIR}/.env" | cut -d'=' -f2 || echo "YOUR_DOMAIN/grafana")
Username: admin
Password: ${NEW_PASSWORD}

## Password Reset (if needed)
# Change password from container:
docker exec grafana grafana cli admin reset-admin-password 'NEW_PASSWORD'

# Or use the reset script:
sudo bash ${MONITORING_DIR%/*}/scripts/utils/reset-grafana-password.sh

# Then update the .env:
sed -i 's/GRAFANA_ADMIN_PASSWORD=.*/GRAFANA_ADMIN_PASSWORD=NEW_PASSWORD/' ${MONITORING_DIR}/.env

## Prometheus (Internal Only)
URL: http://prometheus:9090 (Docker network)
No authentication required (internal service)

## Exporters (Internal Only)
- Node Exporter: http://node_exporter:9100
- cAdvisor: http://cadvisor:8080
- Postgres Exporter: http://postgres_exporter:9187

All exporters are internal-only and do not require authentication.
EOF

    chmod 600 "$creds_file"
    chown "${TARGET_USER}:${TARGET_USER}" "$creds_file"
    ok "CREDENTIALS.txt updated"
}

display_summary() {
    echo ""
    echo "=========================================="
    echo "Password Reset Complete"
    echo "=========================================="
    echo ""
    echo "Grafana Login:"
    echo "  URL: $(grep 'GRAFANA_ROOT_URL=' "${MONITORING_DIR}/.env" | cut -d'=' -f2 || echo "https://YOUR_DOMAIN/grafana")"
    echo "  Username: admin"
    echo "  Password: ${NEW_PASSWORD}"
    echo ""
    echo "Files Updated:"
    echo "  - ${MONITORING_DIR}/.env"
    echo "  - ${MONITORING_DIR}/CREDENTIALS.txt"
    echo ""
    ok "You can now login to Grafana with the new password"
    echo ""
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    log "=== Grafana Password Reset - Version ${SCRIPT_VERSION} ==="
    echo ""

    check_prerequisites
    prompt_new_password "${1:-}"
    reset_password
    update_env_file
    update_credentials_file
    display_summary
}

# Run main function with all arguments
main "$@"
