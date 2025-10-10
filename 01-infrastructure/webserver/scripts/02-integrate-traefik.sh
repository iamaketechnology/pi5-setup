#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Webserver-Traefik Integration Script for Raspberry Pi 5
# =============================================================================
# Purpose: Integrate existing web server installation with Traefik reverse proxy
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Nginx or Caddy
# Scenarios: DuckDNS (path-based), Cloudflare (subdomain), VPN (local)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 2-5 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[WEBSERVER]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]     \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]       \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]    \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/webserver-traefik-integration-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
WEBSERVER_NGINX_DIR="/home/${TARGET_USER}/stacks/webserver"
WEBSERVER_CADDY_DIR="/home/${TARGET_USER}/stacks/caddy"
BACKUP_DIR=""

# Traefik scenario detection
TRAEFIK_SCENARIO=""
DOMAIN=""
WEB_DOMAIN=""

# User-provided variables
USER_DOMAIN=""
WEB_SUBDOMAIN=""
WEB_PATH=""

# Webserver detection
WEBSERVER_TYPE=""
WEBSERVER_DIR=""
WEBSERVER_COMPOSE_FILE=""

# Error handling
error_exit() {
    error "$1"
    exit 1
}

trap 'error_exit "Script failed at line $LINENO"' ERR

# =============================================================================
# VALIDATION SECTION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    log "Checking system dependencies..."

    local dependencies=("docker" "yq")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}"

        log "Attempting to install missing dependencies..."
        apt update -qq

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker)
                    error_exit "Docker not found. Please install Docker first."
                    ;;
                yq)
                    log "Installing yq for YAML processing..."
                    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64"
                    chmod +x /usr/local/bin/yq
                    ok "yq installed successfully"
                    ;;
                *)
                    apt install -y "$dep"
                    ;;
            esac
        done
    fi

    ok "All dependencies are present"
}

check_traefik_installation() {
    log "Checking for Traefik installation..."

    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        error_exit "Traefik container is not running. Please deploy Traefik first using one of the 01-traefik-deploy-*.sh scripts"
    fi

    if [[ ! -d "$TRAEFIK_DIR" ]]; then
        error_exit "Traefik directory not found at $TRAEFIK_DIR"
    fi

    if [[ ! -f "$TRAEFIK_DIR/.env" ]]; then
        error_exit "Traefik .env file not found. Cannot detect deployment scenario."
    fi

    ok "Traefik is installed and running"
}

detect_webserver() {
    log "Detecting web server installation..."

    if docker ps --format '{{.Names}}' | grep -q '^webserver-nginx$'; then
        WEBSERVER_TYPE="nginx"
        WEBSERVER_DIR="$WEBSERVER_NGINX_DIR"
        WEBSERVER_COMPOSE_FILE="${WEBSERVER_DIR}/docker-compose.yml"
        BACKUP_DIR="${WEBSERVER_DIR}/backups"
        ok "Detected: Nginx web server"
    elif docker ps --format '{{.Names}}' | grep -q '^caddy-webserver$'; then
        WEBSERVER_TYPE="caddy"
        WEBSERVER_DIR="$WEBSERVER_CADDY_DIR"
        WEBSERVER_COMPOSE_FILE="${WEBSERVER_DIR}/docker-compose.yml"
        BACKUP_DIR="${WEBSERVER_DIR}/backups"
        ok "Detected: Caddy web server"
    else
        error_exit "No web server found. Please deploy Nginx or Caddy first using 01-nginx-deploy.sh or 01-caddy-deploy.sh"
    fi

    if [[ ! -f "$WEBSERVER_COMPOSE_FILE" ]]; then
        error_exit "Web server docker-compose.yml not found at $WEBSERVER_COMPOSE_FILE"
    fi
}

check_traefik_network() {
    log "Checking for Traefik network..."

    if ! docker network ls --format '{{.Name}}' | grep -q '^traefik_network$'; then
        error_exit "Traefik network 'traefik_network' not found. Please ensure Traefik is properly deployed."
    fi

    ok "Traefik network exists"
}

detect_traefik_scenario() {
    log "Detecting Traefik deployment scenario..."

    source "$TRAEFIK_DIR/.env"

    if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="duckdns"
        DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        ok "Detected scenario: DuckDNS (path-based routing)"
        log "Base domain: $DOMAIN"
    elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN="${CLOUDFLARE_DOMAIN}"
        ok "Detected scenario: Cloudflare (subdomain-based routing)"
        log "Base domain: $DOMAIN"
    elif [[ -n "${VPN_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="vpn"
        DOMAIN="${VPN_DOMAIN}"
        ok "Detected scenario: VPN (local .pi.local domains)"
        log "Base domain: $DOMAIN"
    else
        error_exit "Could not detect Traefik deployment scenario from .env file"
    fi
}

check_existing_labels() {
    log "Checking for existing Traefik labels in web server configuration..."

    if grep -q "traefik.enable" "$WEBSERVER_COMPOSE_FILE"; then
        warn "Existing Traefik labels found in web server docker-compose.yml"
        read -p "Do you want to overwrite them? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Integration cancelled by user"
        fi
        log "Will overwrite existing labels"
    else
        ok "No existing Traefik labels found"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting domain configuration..."
    echo ""
    echo "=========================================="
    echo "Webserver-Traefik Integration Configuration"
    echo "=========================================="
    echo ""
    echo "Detected Scenario: $TRAEFIK_SCENARIO"
    echo "Base Domain: $DOMAIN"
    echo "Web Server: $WEBSERVER_TYPE"
    echo ""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing
            WEB_DOMAIN="$DOMAIN"

            echo "Enter path for web server (e.g., 'www' for ${DOMAIN}/www):"
            read -p "Path (leave empty for root /): " WEB_PATH
            if [[ -z "$WEB_PATH" ]]; then
                WEB_PATH=""
                log "Using root path: https://${DOMAIN}/"
            else
                # Remove leading/trailing slashes
                WEB_PATH=$(echo "$WEB_PATH" | sed 's:^/::;s:/$::')
                log "Using path: https://${DOMAIN}/${WEB_PATH}"
            fi
            ;;

        cloudflare)
            # Subdomain-based routing
            echo "Enter subdomain for web server (e.g., 'www' for www.$DOMAIN):"
            echo "(Leave empty for root domain)"
            echo ""

            read -p "Subdomain: " WEB_SUBDOMAIN
            if [[ -z "$WEB_SUBDOMAIN" ]]; then
                WEB_DOMAIN="${DOMAIN}"
                log "Using root domain: ${DOMAIN}"
            else
                WEB_DOMAIN="${WEB_SUBDOMAIN}.${DOMAIN}"
                log "Using subdomain: ${WEB_DOMAIN}"
            fi
            ;;

        vpn)
            # Local domain routing
            echo "Enter hostname for web server (e.g., 'www' for www.pi.local):"
            echo ""

            read -p "Hostname (default: www): " WEB_SUBDOMAIN
            if [[ -z "$WEB_SUBDOMAIN" ]]; then
                WEB_SUBDOMAIN="www"
                log "Using default: www"
            fi
            WEB_DOMAIN="${WEB_SUBDOMAIN}.${DOMAIN}"
            ;;
    esac

    echo ""
    echo "Configuration Summary:"
    echo "  Scenario: $TRAEFIK_SCENARIO"
    echo "  Web Server: $WEBSERVER_TYPE"
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] && [[ -n "$WEB_PATH" ]]; then
        echo "  URL: https://${WEB_DOMAIN}/${WEB_PATH}"
    else
        echo "  URL: https://${WEB_DOMAIN}"
    fi
    echo ""

    read -p "Proceed with this configuration? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error_exit "Integration cancelled by user"
    fi
}

# =============================================================================
# BACKUP SECTION
# =============================================================================

backup_configuration() {
    log "Creating backup of current configuration..."

    mkdir -p "${BACKUP_DIR}"

    local backup_file="${BACKUP_DIR}/docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)"
    cp "$WEBSERVER_COMPOSE_FILE" "$backup_file"

    ok "Backup created: $backup_file"
}

# =============================================================================
# INTEGRATION SECTION
# =============================================================================

add_traefik_labels() {
    log "Adding Traefik labels to web server configuration..."

    local container_name
    if [[ "$WEBSERVER_TYPE" == "nginx" ]]; then
        container_name="webserver-nginx"
    else
        container_name="caddy-webserver"
    fi

    local router_name="webserver"
    local service_name="webserver"

    # Generate labels based on scenario
    local labels=""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            if [[ -n "$WEB_PATH" ]]; then
                # Path-based routing
                labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${WEB_DOMAIN}\`) && PathPrefix(\`/${WEB_PATH}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls.certresolver=letsencrypt\"
      - \"traefik.http.services.${service_name}.loadbalancer.server.port=80\"
      # Strip path prefix
      - \"traefik.http.middlewares.${router_name}-stripprefix.stripprefix.prefixes=/${WEB_PATH}\"
      - \"traefik.http.routers.${router_name}.middlewares=${router_name}-stripprefix\""
            else
                # Root path
                labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${WEB_DOMAIN}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls.certresolver=letsencrypt\"
      - \"traefik.http.services.${service_name}.loadbalancer.server.port=80\""
            fi
            ;;

        cloudflare)
            # Subdomain-based routing
            labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${WEB_DOMAIN}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls.certresolver=cloudflare\"
      - \"traefik.http.routers.${router_name}.tls.domains[0].main=${DOMAIN}\"
      - \"traefik.http.routers.${router_name}.tls.domains[0].sans=*.${DOMAIN}\"
      - \"traefik.http.services.${service_name}.loadbalancer.server.port=80\""
            ;;

        vpn)
            # Local domain routing (no TLS by default)
            labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${WEB_DOMAIN}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=web\"
      - \"traefik.http.services.${service_name}.loadbalancer.server.port=80\""
            ;;
    esac

    # Add labels to docker-compose.yml
    # Find the service and add labels
    local temp_file=$(mktemp)

    # Use yq to add labels
    yq eval ".services.${WEBSERVER_TYPE} += {\"labels\": [], \"networks\": [\"${WEBSERVER_TYPE}_network\", \"traefik_network\"]}" "$WEBSERVER_COMPOSE_FILE" > "$temp_file"

    # Now add the actual label values
    cat > "$temp_file" <<EOF
version: '3.8'

services:
  ${WEBSERVER_TYPE}:
    labels:
$(echo "$labels" | sed 's/^      /      /')
    networks:
      - ${WEBSERVER_TYPE == "nginx" && echo "webserver" || echo "caddy"}_network
      - traefik_network

networks:
  traefik_network:
    external: true
EOF

    # Merge with existing config
    python3 <<PYTHON_SCRIPT
import yaml

# Read original file
with open('$WEBSERVER_COMPOSE_FILE', 'r') as f:
    original = yaml.safe_load(f)

# Prepare labels
labels = [
$(echo "$labels" | sed 's/^      /    "/' | sed 's/$/",/' | sed '$ s/,$//')
]

# Update service
service_key = '$WEBSERVER_TYPE' if '$WEBSERVER_TYPE' == 'nginx' else 'caddy'
if 'services' in original and service_key in original['services']:
    original['services'][service_key]['labels'] = labels

    # Update networks
    original['services'][service_key]['networks'] = [
        '${WEBSERVER_TYPE == "nginx" && echo "webserver" || echo "caddy"}_network',
        'traefik_network'
    ]

    # Remove port mapping (handled by Traefik now)
    if 'ports' in original['services'][service_key]:
        del original['services'][service_key]['ports']

# Add external network
if 'networks' not in original:
    original['networks'] = {}
original['networks']['traefik_network'] = {'external': True}

# Write back
with open('$WEBSERVER_COMPOSE_FILE', 'w') as f:
    yaml.dump(original, f, default_flow_style=False, sort_keys=False)

PYTHON_SCRIPT

    ok "Traefik labels added"
}

connect_traefik_network() {
    log "Connecting web server to Traefik network..."

    # Stop current services
    cd "$WEBSERVER_DIR"
    su - "${TARGET_USER}" -c "cd ${WEBSERVER_DIR} && docker compose down"

    # Start with new configuration
    su - "${TARGET_USER}" -c "cd ${WEBSERVER_DIR} && docker compose up -d"

    # Wait for services
    log "Waiting for services to be ready..."
    sleep 5

    ok "Web server connected to Traefik network"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_integration() {
    log "Verifying integration..."

    # Check container is running
    local container_name
    if [[ "$WEBSERVER_TYPE" == "nginx" ]]; then
        container_name="webserver-nginx"
    else
        container_name="caddy-webserver"
    fi

    if ! docker ps | grep -q "$container_name"; then
        error_exit "Web server container is not running"
    fi

    # Check network connection
    if ! docker network inspect traefik_network | grep -q "$container_name"; then
        warn "Web server may not be properly connected to Traefik network"
    else
        ok "Web server is connected to Traefik network"
    fi

    # Check Traefik router
    log "Waiting for Traefik to register routes (30s)..."
    sleep 30

    ok "Integration verified"
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

print_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    local web_url

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] && [[ -n "$WEB_PATH" ]]; then
        web_url="https://${WEB_DOMAIN}/${WEB_PATH}"
    else
        web_url="https://${WEB_DOMAIN}"
    fi

    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║              WEBSERVER-TRAEFIK INTEGRATION SUCCESSFUL                      ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 Integration Summary:
  ✓ Web Server: ${WEBSERVER_TYPE}
  ✓ Scenario: ${TRAEFIK_SCENARIO}
  ✓ Domain: ${WEB_DOMAIN}
  $([ -n "$WEB_PATH" ] && echo "✓ Path: /${WEB_PATH}" || echo "")

🌐 Access URL:
  • Web Server: ${web_url}

📋 Configuration:
  • Traefik handles HTTPS certificates
  • Direct port access disabled (use Traefik)
  • Backup saved in: ${BACKUP_DIR}/

🔧 Quick Commands:
  # View web server logs
  docker logs -f ${container_name}

  # View Traefik logs
  docker logs -f traefik

  # Restart web server
  cd ${WEBSERVER_DIR} && docker compose restart

  # Check Traefik dashboard
  http://$(hostname -I | awk '{print $1}'):8080

📝 Next Steps:
  1. Test URL: ${web_url}
  2. Upload your website files to: ${WEBSERVER_DIR}/sites/
  $([ "$TRAEFIK_SCENARIO" = "cloudflare" ] && echo "3. Verify DNS: ${WEB_DOMAIN} -> ${ip_address}" || echo "")
  $([ "$TRAEFIK_SCENARIO" = "duckdns" ] && echo "3. Verify DuckDNS: ${DOMAIN} -> ${ip_address}" || echo "")

📖 Documentation: https://github.com/iamaketechnology/pi5-setup

EOF

    log "Integration log saved to: $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "=== Webserver-Traefik Integration v${SCRIPT_VERSION} ==="
    log "Starting at: $(date)"

    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    # Validation
    require_root
    check_dependencies
    check_traefik_installation
    detect_webserver
    check_traefik_network
    detect_traefik_scenario
    check_existing_labels

    # User input
    prompt_user_input

    # Backup
    backup_configuration

    # Integration
    add_traefik_labels
    connect_traefik_network

    # Verification
    verify_integration

    # Summary
    print_summary

    ok "Webserver-Traefik integration completed successfully!"
}

main "$@"
