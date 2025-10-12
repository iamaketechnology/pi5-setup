#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - ROUNDCUBE DEPLOYMENT (EXTERNAL MAIL PROVIDER)
#==============================================================================
# Version: 1.0.0
# Description: Deploy Roundcube webmail with external IMAP/SMTP provider
#              (Gmail, Proton, Outlook, etc.)
# Architecture: ARM64 (Raspberry Pi 5)
# Requirements: Docker, Docker Compose, Traefik
#
# Supports:
# - Gmail (IMAP: imap.gmail.com:993, SMTP: smtp.gmail.com:587)
# - Outlook (IMAP: outlook.office365.com:993, SMTP: smtp.office365.com:587)
# - Proton Mail (IMAP: 127.0.0.1:1143 via bridge, SMTP: 127.0.0.1:1025)
# - Custom IMAP/SMTP servers
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/.../01-roundcube-deploy-external.sh | sudo bash
#   OR
#   sudo bash 01-roundcube-deploy-external.sh
#==============================================================================

set -euo pipefail

#------------------------------------------------------------------------------
# CONFIGURATION
#------------------------------------------------------------------------------

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose/docker-compose-external.yml"
readonly CONFIG_DIR="${PROJECT_ROOT}/config/roundcube"
readonly LOG_DIR="/var/log/pi5-email"
readonly LOG_FILE="${LOG_DIR}/roundcube-deploy-external.log"
readonly BACKUP_DIR="/var/backups/pi5-email"
readonly ENV_FILE="${PROJECT_ROOT}/.env"

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
        warn "Traefik is not running. HTTPS will not work."
        warn "Deploy Traefik first: curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-*.sh | sudo bash"
    fi

    ok "All dependencies satisfied"
}

create_directories() {
    log "Creating directories..."

    mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$CONFIG_DIR"
    chmod 755 "$LOG_DIR" "$BACKUP_DIR" "$CONFIG_DIR"

    ok "Directories created"
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

detect_traefik_scenario() {
    log "Detecting Traefik configuration..."

    local traefik_config=""

    if [[ -f "/opt/pi5-traefik/.env" ]]; then
        traefik_config="/opt/pi5-traefik/.env"
    elif [[ -f "/opt/traefik/.env" ]]; then
        traefik_config="/opt/traefik/.env"
    else
        warn "Traefik .env not found, using default cert resolver"
        echo "letsencrypt"
        return
    fi

    if grep -q "CERT_RESOLVER=cloudflare" "$traefik_config"; then
        echo "cloudflare"
    elif grep -q "CERT_RESOLVER=duckdns" "$traefik_config"; then
        echo "duckdns"
    else
        echo "letsencrypt"
    fi
}

prompt_mail_provider() {
    log "Select your email provider:"
    echo ""
    echo "1) Gmail (imap.gmail.com / smtp.gmail.com)"
    echo "2) Outlook (outlook.office365.com / smtp.office365.com)"
    echo "3) Proton Mail (requires Proton Bridge)"
    echo "4) Custom IMAP/SMTP server"
    echo ""

    read -p "Choice [1-4]: " provider_choice

    case "$provider_choice" in
        1)
            IMAP_HOST="ssl://imap.gmail.com"
            IMAP_PORT=993
            SMTP_HOST="tls://smtp.gmail.com"
            SMTP_PORT=587
            ok "Gmail selected"
            ;;
        2)
            IMAP_HOST="ssl://outlook.office365.com"
            IMAP_PORT=993
            SMTP_HOST="tls://smtp.office365.com"
            SMTP_PORT=587
            ok "Outlook selected"
            ;;
        3)
            warn "Proton Mail requires Proton Bridge to be installed locally"
            warn "See: https://proton.me/mail/bridge"
            IMAP_HOST="127.0.0.1"
            IMAP_PORT=1143
            SMTP_HOST="127.0.0.1"
            SMTP_PORT=1025
            ok "Proton Mail (Bridge) selected"
            ;;
        4)
            read -p "IMAP host (e.g., imap.example.com): " custom_imap_host
            read -p "IMAP port (default 993): " custom_imap_port
            read -p "SMTP host (e.g., smtp.example.com): " custom_smtp_host
            read -p "SMTP port (default 587): " custom_smtp_port

            IMAP_HOST="ssl://${custom_imap_host}"
            IMAP_PORT="${custom_imap_port:-993}"
            SMTP_HOST="tls://${custom_smtp_host}"
            SMTP_PORT="${custom_smtp_port:-587}"
            ok "Custom server configured"
            ;;
        *)
            error "Invalid choice"
            ;;
    esac
}

prompt_domain() {
    log "Enter your domain for webmail access:"
    echo ""
    echo "Examples:"
    echo "  - mail.yourdomain.com (subdomain)"
    echo "  - roundcube.yourdomain.com (subdomain)"
    echo "  - yourdomain.duckdns.org (DuckDNS)"
    echo ""

    read -p "Domain: " MAIL_DOMAIN

    if [[ -z "$MAIL_DOMAIN" ]]; then
        error "Domain cannot be empty"
    fi

    ok "Domain: $MAIL_DOMAIN"
}

generate_env_file() {
    log "Generating .env file..."

    local db_password
    db_password=$(generate_password)

    local cert_resolver
    cert_resolver=$(detect_traefik_scenario)

    cat > "$ENV_FILE" <<EOF
#==============================================================================
# PI5-EMAIL-STACK - EXTERNAL MAIL PROVIDER CONFIGURATION
#==============================================================================
# Generated: $(date)
# Version: ${SCRIPT_VERSION}
#==============================================================================

# Domain Configuration
MAIL_DOMAIN=${MAIL_DOMAIN}

# Traefik Configuration
TRAEFIK_CERT_RESOLVER=${cert_resolver}

# IMAP Configuration
IMAP_HOST=${IMAP_HOST}
IMAP_PORT=${IMAP_PORT}

# SMTP Configuration
SMTP_HOST=${SMTP_HOST}
SMTP_PORT=${SMTP_PORT}

# Roundcube Database
ROUNDCUBE_DB_PASSWORD=${db_password}

#==============================================================================
# IMPORTANT NOTES
#==============================================================================
# 1. For Gmail: Enable "App Passwords" or "Less secure app access"
#    https://support.google.com/accounts/answer/185833
#
# 2. For Outlook: Use regular credentials (2FA supported)
#
# 3. For Proton Mail: Install Proton Bridge first
#    https://proton.me/mail/bridge
#
# 4. Users will authenticate with their email credentials
#    directly in Roundcube web interface
#==============================================================================
EOF

    chmod 600 "$ENV_FILE"
    ok ".env file created"
}

create_roundcube_config() {
    log "Creating Roundcube configuration..."

    cat > "${CONFIG_DIR}/config.inc.php" <<'EOF'
<?php
// Roundcube configuration for external mail providers

$config = [];

// Database
$config['db_dsnw'] = sprintf(
    'pgsql://%s:%s@%s:%s/%s',
    getenv('ROUNDCUBEMAIL_DB_USER'),
    getenv('ROUNDCUBEMAIL_DB_PASSWORD'),
    getenv('ROUNDCUBEMAIL_DB_HOST'),
    getenv('ROUNDCUBEMAIL_DB_PORT'),
    getenv('ROUNDCUBEMAIL_DB_NAME')
);

// IMAP
$config['default_host'] = getenv('ROUNDCUBEMAIL_DEFAULT_HOST');
$config['default_port'] = getenv('ROUNDCUBEMAIL_DEFAULT_PORT');
$config['imap_auth_type'] = null;
$config['imap_delimiter'] = null;

// SMTP
$config['smtp_server'] = getenv('ROUNDCUBEMAIL_SMTP_SERVER');
$config['smtp_port'] = getenv('ROUNDCUBEMAIL_SMTP_PORT');
$config['smtp_user'] = '%u';
$config['smtp_pass'] = '%p';
$config['smtp_auth_type'] = 'LOGIN';

// Security
$config['des_key'] = bin2hex(random_bytes(24));
$config['cipher_method'] = 'AES-256-CBC';
$config['useragent'] = 'Roundcube Webmail';

// Interface
$config['skin'] = getenv('ROUNDCUBEMAIL_SKIN') ?: 'elastic';
$config['language'] = 'fr_FR';
$config['date_format'] = 'd/m/Y';
$config['time_format'] = 'H:i';

// Features
$config['enable_installer'] = false;
$config['auto_create_user'] = true;
$config['identities_level'] = 0;
$config['draft_autosave'] = 60;
$config['preview_pane'] = true;
$config['htmleditor'] = 1;

// Uploads
$config['max_message_size'] = getenv('ROUNDCUBEMAIL_UPLOAD_MAX_FILESIZE') ?: '25M';

// Plugins
$config['plugins'] = [
    'archive',
    'zipdownload',
    'managesieve',
    'emoticons',
    'markasjunk'
];

// Session
$config['session_lifetime'] = 30;
$config['session_domain'] = '';
$config['session_name'] = 'roundcube_sessid';

// Logging
$config['log_driver'] = 'syslog';
$config['syslog_facility'] = LOG_USER;
$config['per_user_logging'] = false;
$config['smtp_log'] = true;
$config['log_logins'] = true;
$config['log_session'] = false;
$config['sql_debug'] = false;
$config['imap_debug'] = false;
$config['ldap_debug'] = false;
$config['smtp_debug'] = false;

return $config;
EOF

    chmod 644 "${CONFIG_DIR}/config.inc.php"
    ok "Roundcube config created"
}

backup_existing_data() {
    if docker ps -a --format '{{.Names}}' | grep -q '^roundcube$'; then
        log "Backing up existing Roundcube data..."

        local backup_file="${BACKUP_DIR}/roundcube-backup-$(date +%Y%m%d-%H%M%S).tar.gz"

        docker exec roundcube-db pg_dump -U roundcube roundcube | gzip > "${backup_file}"

        ok "Backup saved: ${backup_file}"
    fi
}

deploy_stack() {
    log "Deploying Roundcube stack..."

    cd "$PROJECT_ROOT"

    # Pull images
    docker-compose -f "$COMPOSE_FILE" pull

    # Deploy
    docker-compose -f "$COMPOSE_FILE" up -d

    ok "Stack deployed"
}

wait_for_services() {
    log "Waiting for services to be healthy..."

    local max_wait=120
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        if docker ps --format '{{.Names}}\t{{.Status}}' | grep '^roundcube' | grep -q 'healthy\|Up'; then
            ok "Services are ready"
            return 0
        fi
        sleep 5
        waited=$((waited + 5))
        echo -n "."
    done

    error "Services failed to become healthy after ${max_wait}s"
}

print_summary() {
    local traefik_running=false
    if docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        traefik_running=true
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                  ROUNDCUBE DEPLOYMENT SUCCESS                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📧 WEBMAIL ACCESS"
    echo "   URL: https://${MAIL_DOMAIN}"
    if [[ "$traefik_running" == false ]]; then
        echo "   ⚠️  Traefik not running - HTTP only: http://$(hostname -I | awk '{print $1}'):8080"
    fi
    echo ""
    echo "🔑 LOGIN INSTRUCTIONS"
    echo "   Username: your-email@domain.com"
    echo "   Password: your email account password"
    echo ""
    echo "📝 PROVIDER-SPECIFIC SETUP"
    case "$IMAP_HOST" in
        *gmail*)
            echo "   GMAIL:"
            echo "   1. Enable 2FA: https://myaccount.google.com/security"
            echo "   2. Create App Password: https://myaccount.google.com/apppasswords"
            echo "   3. Use App Password (not your regular password)"
            ;;
        *outlook*|*office365*)
            echo "   OUTLOOK:"
            echo "   - Use your regular Microsoft credentials"
            echo "   - 2FA supported natively"
            ;;
        *127.0.0.1*)
            echo "   PROTON MAIL:"
            echo "   1. Install Proton Bridge: https://proton.me/mail/bridge"
            echo "   2. Configure Bridge (IMAP: 1143, SMTP: 1025)"
            echo "   3. Use Bridge credentials in Roundcube"
            ;;
    esac
    echo ""
    echo "📂 CONFIGURATION FILES"
    echo "   Environment: ${ENV_FILE}"
    echo "   Config:      ${CONFIG_DIR}/config.inc.php"
    echo "   Logs:        ${LOG_FILE}"
    echo ""
    echo "🔧 USEFUL COMMANDS"
    echo "   View logs:    docker-compose -f ${COMPOSE_FILE} logs -f roundcube"
    echo "   Restart:      docker-compose -f ${COMPOSE_FILE} restart"
    echo "   Stop:         docker-compose -f ${COMPOSE_FILE} stop"
    echo "   Start:        docker-compose -f ${COMPOSE_FILE} start"
    echo "   Remove:       docker-compose -f ${COMPOSE_FILE} down"
    echo ""
    echo "📚 DOCUMENTATION"
    echo "   Gmail:   https://support.google.com/mail/answer/7126229"
    echo "   Outlook: https://support.microsoft.com/en-us/office/pop-imap-and-smtp-settings"
    echo "   Proton:  https://proton.me/support/bridge-clients"
    echo ""
    echo "✅ Deployment completed successfully!"
    echo ""
}

#------------------------------------------------------------------------------
# MAIN
#------------------------------------------------------------------------------

main() {
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║         PI5-EMAIL-STACK - ROUNDCUBE DEPLOYMENT                ║"
    echo "║               (External Mail Provider)                        ║"
    echo "║                    Version ${SCRIPT_VERSION}                           ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    check_root
    create_directories

    # Log to file
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1

    log "Starting Roundcube deployment (external mail provider)..."

    check_dependencies
    prompt_mail_provider
    prompt_domain
    generate_env_file
    create_roundcube_config
    backup_existing_data
    deploy_stack
    wait_for_services

    print_summary

    ok "Script completed successfully"
}

# Run main
main "$@"
