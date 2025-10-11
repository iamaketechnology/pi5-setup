#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mailu-Traefik Integration Script for Raspberry Pi 5
# =============================================================================
# Purpose: Integrate existing Mailu installation with Traefik reverse proxy
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Mailu Admin, Webmail (HTTP/HTTPS via Traefik)
# Note: SMTP/IMAP ports remain direct (25, 465, 587, 993, etc.)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[MAILU]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/mailu-traefik-integration-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
MAILU_DIR="/home/${TARGET_USER}/stacks/mailu"
MAILU_COMPOSE_FILE="${MAILU_DIR}/docker-compose.yml"
BACKUP_DIR="${MAILU_DIR}/backups"

# Traefik scenario detection
TRAEFIK_SCENARIO=""
DOMAIN=""
MAIL_DOMAIN=""

# User-provided variables
MAIL_SUBDOMAIN=""

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

check_mailu_installation() {
    log "Checking for Mailu installation..."

    if [[ ! -d "$MAILU_DIR" ]]; then
        error_exit "Mailu directory not found at $MAILU_DIR. Please install Mailu first."
    fi

    if [[ ! -f "$MAILU_COMPOSE_FILE" ]]; then
        error_exit "Mailu docker-compose.yml not found at $MAILU_COMPOSE_FILE"
    fi

    # Check if Mailu containers are running
    local mailu_containers=$(docker ps --filter "name=mailu" --format '{{.Names}}' | wc -l)
    if [[ $mailu_containers -lt 3 ]]; then
        warn "Mailu containers may not be fully running (found $mailu_containers containers)"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled by user"
        fi
    fi

    ok "Mailu installation found"
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
    log "Checking for existing Traefik labels in Mailu configuration..."

    if grep -q "traefik.enable" "$MAILU_COMPOSE_FILE"; then
        warn "Existing Traefik labels found in Mailu docker-compose.yml"
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
    echo "Mailu-Traefik Integration Configuration"
    echo "=========================================="
    echo ""
    echo "Detected Scenario: $TRAEFIK_SCENARIO"
    echo "Base Domain: $DOMAIN"
    echo ""

    warn "IMPORTANT: Email server (SMTP/IMAP) ports will remain directly exposed!"
    warn "Only web interfaces (Admin/Webmail) will be proxied through Traefik."
    echo ""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing - use same domain
            MAIL_DOMAIN="$DOMAIN"
            log "Using path-based routing:"
            echo "  Admin: https://${MAIL_DOMAIN}/admin"
            echo "  Webmail: https://${MAIL_DOMAIN}/webmail"
            ;;

        cloudflare)
            # Subdomain-based routing
            echo "Enter subdomain for mail server (e.g., 'mail' for mail.$DOMAIN):"
            echo ""

            read -p "Mail subdomain: " MAIL_SUBDOMAIN
            if [[ -z "$MAIL_SUBDOMAIN" ]]; then
                MAIL_SUBDOMAIN="mail"
                log "Using default: mail"
            fi
            MAIL_DOMAIN="${MAIL_SUBDOMAIN}.${DOMAIN}"
            log "Mail domain: ${MAIL_DOMAIN}"
            ;;

        vpn)
            # Local domain routing
            echo "Enter hostname for mail server (e.g., 'mail' for mail.pi.local):"
            echo ""

            read -p "Mail hostname (default: mail): " MAIL_SUBDOMAIN
            if [[ -z "$MAIL_SUBDOMAIN" ]]; then
                MAIL_SUBDOMAIN="mail"
                log "Using default: mail"
            fi
            MAIL_DOMAIN="${MAIL_SUBDOMAIN}.${DOMAIN}"
            ;;
    esac

    echo ""
    echo "Configuration Summary:"
    echo "  Scenario: $TRAEFIK_SCENARIO"
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]]; then
        echo "  Admin URL: https://${MAIL_DOMAIN}/admin"
        echo "  Webmail URL: https://${MAIL_DOMAIN}/webmail"
    else
        echo "  Admin URL: https://${MAIL_DOMAIN}/admin"
        echo "  Webmail URL: https://${MAIL_DOMAIN}/webmail"
    fi
    echo "  SMTP/IMAP: Direct connection (ports 25, 465, 587, 993, etc.)"
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
    cp "$MAILU_COMPOSE_FILE" "$backup_file"

    ok "Backup created: $backup_file"
}

# =============================================================================
# INTEGRATION SECTION
# =============================================================================

update_mailu_env() {
    log "Updating Mailu environment configuration..."

    local mailu_env_file="${MAILU_DIR}/mailu.env"

    if [[ ! -f "$mailu_env_file" ]]; then
        error_exit "Mailu .env file not found at $mailu_env_file"
    fi

    # Update TLS_FLAVOR to use cert (Traefik will handle TLS)
    sed -i "s/^TLS_FLAVOR=.*/TLS_FLAVOR=cert/" "$mailu_env_file"

    # Update HOSTNAMES
    sed -i "s/^HOSTNAMES=.*/HOSTNAMES=${MAIL_DOMAIN}/" "$mailu_env_file"

    ok "Mailu environment updated"
}

add_traefik_labels() {
    log "Adding Traefik labels to Mailu front service..."

    local labels=""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing
            labels="      - \"traefik.enable=true\"
      # Admin interface
      - \"traefik.http.routers.mailu-admin.rule=Host(\`${MAIL_DOMAIN}\`) && PathPrefix(\`/admin\`)\"
      - \"traefik.http.routers.mailu-admin.entrypoints=websecure\"
      - \"traefik.http.routers.mailu-admin.tls.certresolver=letsencrypt\"
      - \"traefik.http.routers.mailu-admin.service=mailu-admin\"
      - \"traefik.http.services.mailu-admin.loadbalancer.server.port=80\"
      # Webmail interface
      - \"traefik.http.routers.mailu-webmail.rule=Host(\`${MAIL_DOMAIN}\`) && PathPrefix(\`/webmail\`)\"
      - \"traefik.http.routers.mailu-webmail.entrypoints=websecure\"
      - \"traefik.http.routers.mailu-webmail.tls.certresolver=letsencrypt\"
      - \"traefik.http.routers.mailu-webmail.service=mailu-webmail\"
      - \"traefik.http.services.mailu-webmail.loadbalancer.server.port=80\""
            ;;

        cloudflare)
            # Subdomain-based routing
            labels="      - \"traefik.enable=true\"
      # Admin and Webmail on same domain
      - \"traefik.http.routers.mailu.rule=Host(\`${MAIL_DOMAIN}\`)\"
      - \"traefik.http.routers.mailu.entrypoints=websecure\"
      - \"traefik.http.routers.mailu.tls.certresolver=cloudflare\"
      - \"traefik.http.routers.mailu.tls.domains[0].main=${DOMAIN}\"
      - \"traefik.http.routers.mailu.tls.domains[0].sans=*.${DOMAIN}\"
      - \"traefik.http.services.mailu.loadbalancer.server.port=80\""
            ;;

        vpn)
            # Local domain routing (no TLS)
            labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.mailu.rule=Host(\`${MAIL_DOMAIN}\`)\"
      - \"traefik.http.routers.mailu.entrypoints=web\"
      - \"traefik.http.services.mailu.loadbalancer.server.port=80\""
            ;;
    esac

    # Find the front service and add labels
    python3 <<PYTHON_SCRIPT
import yaml
import sys

compose_file = '$MAILU_COMPOSE_FILE'

try:
    with open(compose_file, 'r') as f:
        config = yaml.safe_load(f)

    # Prepare labels list
    labels = [
$(echo "$labels" | sed 's/^      /        "/' | sed 's/$/",/' | sed '$ s/,$//')
    ]

    # Update front service
    if 'services' in config and 'front' in config['services']:
        if 'labels' not in config['services']['front']:
            config['services']['front']['labels'] = []
        config['services']['front']['labels'] = labels

        # Add to traefik network
        if 'networks' not in config['services']['front']:
            config['services']['front']['networks'] = {}

        # Preserve existing networks and add traefik
        if isinstance(config['services']['front']['networks'], list):
            if 'traefik_network' not in config['services']['front']['networks']:
                config['services']['front']['networks'].append('traefik_network')
        else:
            config['services']['front']['networks']['traefik_network'] = None

        # Note: We keep port 80 exposed for direct access if needed
        # SMTP/IMAP ports (25, 465, 587, 993, etc.) remain untouched

    # Add traefik network to networks section
    if 'networks' not in config:
        config['networks'] = {}
    config['networks']['traefik_network'] = {'external': True}

    # Write back
    with open(compose_file, 'w') as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)

    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -ne 0 ]; then
        error_exit "Failed to add Traefik labels"
    fi

    ok "Traefik labels added to Mailu front service"
}

restart_mailu() {
    log "Restarting Mailu services with new configuration..."

    cd "$MAILU_DIR"
    su - "${TARGET_USER}" -c "cd ${MAILU_DIR} && docker compose down"
    sleep 5
    su - "${TARGET_USER}" -c "cd ${MAILU_DIR} && docker compose up -d"

    log "Waiting for services to be ready (60s)..."
    sleep 60

    ok "Mailu services restarted"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_integration() {
    log "Verifying integration..."

    # Check front container
    if ! docker ps | grep -q "mailu-front"; then
        error_exit "Mailu front container is not running"
    fi

    # Check network connection
    if ! docker network inspect traefik_network | grep -q "mailu-front"; then
        warn "Mailu front may not be properly connected to Traefik network"
    else
        ok "Mailu is connected to Traefik network"
    fi

    # Wait for Traefik to register routes
    log "Waiting for Traefik to register routes (30s)..."
    sleep 30

    ok "Integration verified"
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

print_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    local admin_url
    local webmail_url

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]]; then
        admin_url="https://${MAIL_DOMAIN}/admin"
        webmail_url="https://${MAIL_DOMAIN}/webmail"
    else
        admin_url="https://${MAIL_DOMAIN}/admin"
        webmail_url="https://${MAIL_DOMAIN}/webmail"
    fi

    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                MAILU-TRAEFIK INTEGRATION SUCCESSFUL                        ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 Integration Summary:
  ✓ Scenario: ${TRAEFIK_SCENARIO}
  ✓ Mail domain: ${MAIL_DOMAIN}
  ✓ Traefik handles: HTTP/HTTPS (Admin + Webmail)
  ✓ Direct access: SMTP/IMAP ports

🌐 Web Access URLs:
  • Admin Panel: ${admin_url}
  • Webmail: ${webmail_url}

📬 Mail Server Configuration (unchanged):
  • SMTP: ${ip_address}:25, 465, 587
  • IMAP: ${ip_address}:993, 143
  • POP3: ${ip_address}:995, 110

⚠️  DNS Configuration Required:

1. Update MX record to point to: ${MAIL_DOMAIN}
2. Update A record: ${MAIL_DOMAIN} -> ${ip_address}
$([ "$TRAEFIK_SCENARIO" = "cloudflare" ] && echo "3. Wildcard DNS: *.${DOMAIN} -> ${ip_address}" || echo "")

📋 Email Client Setup:
  • Incoming (IMAP): ${MAIL_DOMAIN}:993 (SSL/TLS)
  • Outgoing (SMTP): ${MAIL_DOMAIN}:587 (STARTTLS)
  • Username: your-email@${MAIL_DOMAIN}

🔧 Quick Commands:
  # View Mailu logs
  cd ${MAILU_DIR} && docker compose logs -f

  # View Traefik logs
  docker logs -f traefik

  # Restart Mailu
  cd ${MAILU_DIR} && docker compose restart

  # Generate DKIM key
  cd ${MAILU_DIR} && docker compose exec admin flask mailu config-export --format=dkim

📝 Next Steps:
  1. Access admin panel: ${admin_url}
  2. Verify HTTPS certificate (may take 2-5 minutes)
  3. Update DNS records (if not done already)
  4. Generate and configure DKIM key
  5. Test email sending/receiving
  6. Configure email clients

📖 Documentation:
  • Mailu Docs: https://mailu.io/master/
  • Local Guide: ${MAILU_DIR}/README.md
  • PI5-SETUP: https://github.com/iamaketechnology/pi5-setup

EOF

    log "Integration log saved to: $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "=== Mailu-Traefik Integration v${SCRIPT_VERSION} ==="
    log "Starting at: $(date)"

    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    # Validation
    require_root
    check_dependencies
    check_traefik_installation
    check_mailu_installation
    check_traefik_network
    detect_traefik_scenario
    check_existing_labels

    # User input
    prompt_user_input

    # Backup
    backup_configuration

    # Integration
    update_mailu_env
    add_traefik_labels
    restart_mailu

    # Verification
    verify_integration

    # Summary
    print_summary

    ok "Mailu-Traefik integration completed successfully!"
}

main "$@"
