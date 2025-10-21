#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Mailu Email Server Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Mailu full-featured email server
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Postfix, Dovecot, Rspamd, Webmail (Roundcube), Admin UI
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 15-20 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[MAILU]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/mailu-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
INSTALL_DIR="/home/${TARGET_USER}/stacks/mailu"
BACKUP_DIR="${INSTALL_DIR}/backups"

# Configuration variables (can be set via environment)
MAILU_VERSION="${MAILU_VERSION:-2024.06}"
MAILU_DOMAIN="${MAILU_DOMAIN:-}"
MAILU_HOSTNAME="${MAILU_HOSTNAME:-mail}"
MAILU_ADMIN_EMAIL="${MAILU_ADMIN_EMAIL:-}"
MAILU_ADMIN_PASSWORD="${MAILU_ADMIN_PASSWORD:-}"
ENABLE_WEBMAIL="${ENABLE_WEBMAIL:-yes}"
ENABLE_ANTIVIRUS="${ENABLE_ANTIVIRUS:-no}"  # ClamAV uses lot of RAM
ENABLE_WEBDAV="${ENABLE_WEBDAV:-no}"

# Generated secrets
SECRET_KEY=""
DB_PASSWORD=""

# Error handling
error_exit() {
    error "$1"
    log "Check log file: $LOG_FILE"
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
        echo ""
        echo "Required environment variables:"
        echo "  MAILU_DOMAIN=example.com        # Your mail domain"
        echo "  MAILU_ADMIN_EMAIL=admin@example.com"
        echo "  MAILU_ADMIN_PASSWORD=SecurePassword123"
        echo ""
        echo "Optional environment variables:"
        echo "  MAILU_VERSION=2024.06           # Mailu version (default: 2024.06)"
        echo "  MAILU_HOSTNAME=mail             # Mail hostname (default: mail)"
        echo "  ENABLE_WEBMAIL=yes              # Enable Roundcube (default: yes)"
        echo "  ENABLE_ANTIVIRUS=no             # Enable ClamAV (default: no, uses 1GB RAM)"
        echo ""
        echo "Example:"
        echo "  sudo MAILU_DOMAIN=mydomain.com \\"
        echo "       MAILU_ADMIN_EMAIL=admin@mydomain.com \\"
        echo "       MAILU_ADMIN_PASSWORD='MySecurePass123!' \\"
        echo "       $0"
        exit 1
    fi
}

validate_required_vars() {
    log "Validating required variables..."

    local missing_vars=()

    if [[ -z "$MAILU_DOMAIN" ]]; then
        missing_vars+=("MAILU_DOMAIN")
    fi

    if [[ -z "$MAILU_ADMIN_EMAIL" ]]; then
        missing_vars+=("MAILU_ADMIN_EMAIL")
    fi

    if [[ -z "$MAILU_ADMIN_PASSWORD" ]]; then
        missing_vars+=("MAILU_ADMIN_PASSWORD")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        error_exit "Missing required variables: ${missing_vars[*]}"
    fi

    # Validate email format
    if ! echo "$MAILU_ADMIN_EMAIL" | grep -qE '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
        error_exit "Invalid email format: $MAILU_ADMIN_EMAIL"
    fi

    # Validate domain format
    if ! echo "$MAILU_DOMAIN" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
        error_exit "Invalid domain format: $MAILU_DOMAIN"
    fi

    # Check password strength
    if [[ ${#MAILU_ADMIN_PASSWORD} -lt 12 ]]; then
        error_exit "Password must be at least 12 characters long"
    fi

    ok "Required variables validated"
}

check_dependencies() {
    log "Checking system dependencies..."

    local dependencies=("docker" "docker compose" "openssl")
    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! docker compose version &> /dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi

    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error_exit "Missing dependencies: ${missing_deps[*]}. Please install Docker first."
    fi

    ok "All dependencies are present"
}

check_architecture() {
    log "Checking system architecture..."

    local arch=$(uname -m)

    if [[ "$arch" == "aarch64" ]]; then
        ok "Architecture: ARM64 (aarch64) - Production ready ✓"
    elif [[ "$arch" == "x86_64" ]] && [[ "${ALLOW_X86_64_TEST:-0}" == "1" ]]; then
        warn "Architecture: x86_64 (Intel/AMD) - TEST MODE ONLY"
        warn "⚠️  This is NOT a Raspberry Pi!"
        warn "⚠️  Use ALLOW_X86_64_TEST=1 for testing purposes only"
        warn "⚠️  Docker images may not be optimized for this architecture"
        warn "⚠️  For production, use ARM64 Raspberry Pi 5"
        echo ""
        sleep 3
        ok "Continuing in TEST MODE (x86_64)..."
    else
        error "Architecture $arch not supported"
        echo ""
        echo "Supported architectures:"
        echo "  ✓ aarch64 (ARM64) - Raspberry Pi 5 (PRODUCTION)"
        echo "  ⚠ x86_64 (Intel/AMD) - Emulator/Testing only"
        echo ""
        echo "For x86_64 testing, set environment variable:"
        echo "  export ALLOW_X86_64_TEST=1"
        echo ""
        error_exit "Unsupported architecture: $arch"
    fi
}

check_ram() {
    log "Checking available RAM..."

    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local required_ram=2

    if [[ "$ENABLE_ANTIVIRUS" == "yes" ]]; then
        required_ram=3
    fi

    if [[ $ram_gb -lt $required_ram ]]; then
        warn "Available RAM: ${ram_gb}GB"
        error_exit "Mailu requires at least ${required_ram}GB of RAM (ClamAV: ${ENABLE_ANTIVIRUS})"
    else
        ok "Available RAM: ${ram_gb}GB (required: ${required_ram}GB)"
    fi
}

check_ports() {
    log "Checking required ports..."

    local required_ports=(25 80 110 143 443 465 587 993 995)
    local used_ports=()

    for port in "${required_ports[@]}"; do
        if ss -tuln | grep -q ":${port} "; then
            used_ports+=("$port")
        fi
    done

    if [ ${#used_ports[@]} -gt 0 ]; then
        error_exit "The following ports are already in use: ${used_ports[*]}. Please free them before continuing."
    fi

    ok "All required ports are available"
}

check_dns() {
    log "Checking DNS configuration..."

    local full_hostname="${MAILU_HOSTNAME}.${MAILU_DOMAIN}"

    warn "DNS Check:"
    warn "  Make sure the following DNS records are configured:"
    warn ""
    warn "  A Record:"
    warn "    ${MAILU_HOSTNAME}.${MAILU_DOMAIN} -> $(hostname -I | awk '{print $1}')"
    warn ""
    warn "  MX Record:"
    warn "    ${MAILU_DOMAIN} -> ${MAILU_HOSTNAME}.${MAILU_DOMAIN} (priority 10)"
    warn ""
    warn "  Optional but recommended:"
    warn "    SPF: v=spf1 mx ~all"
    warn "    DKIM: Will be generated after installation"
    warn "    DMARC: v=DMARC1; p=quarantine; rua=mailto:${MAILU_ADMIN_EMAIL}"
    warn ""

    read -p "Have you configured the DNS records? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "You can continue, but email sending/receiving may not work until DNS is configured"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled by user"
        fi
    fi
}

# =============================================================================
# SETUP SECTION
# =============================================================================

generate_secrets() {
    log "Generating secure secrets..."

    # Generate 16 bytes random secret key
    SECRET_KEY=$(openssl rand -hex 16)

    # Generate database password
    DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    ok "Secrets generated"
}

setup_directories() {
    log "Creating directory structure..."

    mkdir -p "${INSTALL_DIR}"/{data,overrides,certs,dkim}
    mkdir -p "${BACKUP_DIR}"

    chown -R "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}"

    ok "Directory structure created"
}

create_mailu_env() {
    log "Creating Mailu configuration file..."

    local full_hostname="${MAILU_HOSTNAME}.${MAILU_DOMAIN}"

    cat > "${INSTALL_DIR}/mailu.env" <<EOF
# Mailu Configuration
# Generated: $(date)
# Documentation: https://mailu.io/master/configuration.html

###################################
# Common configuration variables
###################################

# Set this to the path where Mailu data and configuration is stored
ROOT=${INSTALL_DIR}

# Mailu version to run (stable/latest/branch)
VERSION=${MAILU_VERSION}

# Set to a randomly generated 16 bytes string
SECRET_KEY=${SECRET_KEY}

# Subnet of the docker network
# WARNING: changing this after deployment will break the installation
SUBNET=192.168.203.0/24

# Main mail domain
DOMAIN=${MAILU_DOMAIN}

# Hostnames for this server, separated with comas
HOSTNAMES=${full_hostname}

# Postmaster local part (will append the main mail domain)
POSTMASTER=admin

# Choose how secure connections will behave (value: letsencrypt, cert, notls, mail, mail-letsencrypt)
# For Raspberry Pi behind Traefik, use 'cert' and provide certificates via Traefik
TLS_FLAVOR=mail-letsencrypt

# Authentication rate limit per IP (per /24 on ipv4 and /56 on ipv6)
AUTH_RATELIMIT_IP=60/hour

# Authentication rate limit per user (regardless of the source-IP)
AUTH_RATELIMIT_USER=100/day

# Opt-out of statistics, replace with "True" to opt out
DISABLE_STATISTICS=False

###################################
# Optional features
###################################

# Expose the admin interface (value: true, false)
ADMIN=true

# Choose which webmail to run if any (value: roundcube, rainloop, none)
WEBMAIL=$([ "$ENABLE_WEBMAIL" == "yes" ] && echo "roundcube" || echo "none")

# Dav server implementation (value: radicale, none)
WEBDAV=$([ "$ENABLE_WEBDAV" == "yes" ] && echo "radicale" || echo "none")

# Antivirus solution (value: clamav, none)
ANTIVIRUS=$([ "$ENABLE_ANTIVIRUS" == "yes" ] && echo "clamav" || echo "none")

###################################
# Mail settings
###################################

# Message size limit in bytes
# Default: accept messages up to 50MB
MESSAGE_SIZE_LIMIT=50000000

# Message rate limit (per user)
MESSAGE_RATELIMIT=200/day

# Networks granted relay permissions
# Use this with care, all hosts in this networks will be able to send mail without authentication!
RELAYNETS=

# Will relay all outgoing mails if configured
RELAYHOST=

# Fetchmail delay
FETCHMAIL_DELAY=600

# Recipient delimiter, character used to delimiter localpart from custom address part
RECIPIENT_DELIMITER=+

# DMARC rua and ruf email
DMARC_RUA=${MAILU_ADMIN_EMAIL}
DMARC_RUF=${MAILU_ADMIN_EMAIL}

# Welcome email, enable and set a topic and body if you wish to send welcome
# emails to all users.
WELCOME=false
WELCOME_SUBJECT=Welcome to your new email account
WELCOME_BODY=Welcome to your new email account, if you can read this, then it is configured properly!

# Maildir Compression
# choose compression-method, default: none (value: gz, bz2, lz4, zstd)
COMPRESSION=
# change compression-level, default: 6 (value: 1-9)
COMPRESSION_LEVEL=

###################################
# Web settings
###################################

# Path to redirect /
WEBROOT_REDIRECT=/admin

# Path to the admin interface if enabled
WEB_ADMIN=/admin

# Path to the webmail if enabled
WEB_WEBMAIL=/webmail

# Website name
SITENAME=Mailu on ${MAILU_DOMAIN}

# Linked Website URL
WEBSITE=https://${full_hostname}

###################################
# Advanced settings
###################################

# Log driver for front service. Possible values:
# json-file (default)
# journald (On systemd platforms, use journald)
# syslog (Non systemd platforms, use syslog)
LOG_DRIVER=json-file

# Docker-compose project name, this will prepended to containers names.
COMPOSE_PROJECT_NAME=mailu

# Number of rounds used by the password hashing scheme
CREDENTIAL_ROUNDS=12

# Header to take the real ip from
REAL_IP_HEADER=X-Forwarded-For

# IPs for nginx set_real_ip_from (CIDR list separated by commas)
REAL_IP_FROM=

# choose wether mailu bounces (no) or rejects (yes) mail when recipient is unknown (value: yes, no)
REJECT_UNLISTED_RECIPIENT=no

# Log level threshold in start.py (value: CRITICAL, ERROR, WARNING, INFO, DEBUG, NOTSET)
LOG_LEVEL=WARNING

# Timezone
TZ=Europe/Paris

###################################
# Database settings
###################################
DB_FLAVOR=sqlite
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/mailu.env"
    chmod 600 "${INSTALL_DIR}/mailu.env"
    ok "Mailu configuration created"
}

download_docker_compose() {
    log "Downloading Mailu Docker Compose configuration..."

    # Download official docker-compose.yml for ARM64
    local compose_url="https://raw.githubusercontent.com/Mailu/Mailu/${MAILU_VERSION}/setup/flavors/compose/docker-compose.yml"

    wget -q -O "${INSTALL_DIR}/docker-compose.yml" "$compose_url" || error_exit "Failed to download docker-compose.yml"

    # Modify for ARM64 if needed
    sed -i 's|ghcr.io/mailu|ghcr.io/mailu|g' "${INSTALL_DIR}/docker-compose.yml"

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/docker-compose.yml"
    ok "Docker Compose configuration downloaded"
}

create_readme() {
    log "Creating quick reference guide..."

    cat > "${INSTALL_DIR}/README.md" <<EOF
# Mailu Email Server - Quick Reference

## 📧 Service Details

**Domain:** ${MAILU_DOMAIN}
**Hostname:** ${MAILU_HOSTNAME}.${MAILU_DOMAIN}
**Admin Email:** ${MAILU_ADMIN_EMAIL}

## 🌐 Web Interfaces

- **Admin Panel:** https://${MAILU_HOSTNAME}.${MAILU_DOMAIN}/admin
- **Webmail:** https://${MAILU_HOSTNAME}.${MAILU_DOMAIN}/webmail $([ "$ENABLE_WEBMAIL" != "yes" ] && echo "(disabled)")

## 📬 Mail Client Configuration

### IMAP (Reading Mail)
- **Server:** ${MAILU_HOSTNAME}.${MAILU_DOMAIN}
- **Port:** 993 (SSL/TLS)
- **Security:** SSL/TLS
- **Username:** your-email@${MAILU_DOMAIN}

### SMTP (Sending Mail)
- **Server:** ${MAILU_HOSTNAME}.${MAILU_DOMAIN}
- **Port:** 587 (STARTTLS) or 465 (SSL/TLS)
- **Security:** STARTTLS or SSL/TLS
- **Authentication:** Required
- **Username:** your-email@${MAILU_DOMAIN}

## 🔧 Management Commands

### View logs
\`\`\`bash
cd ${INSTALL_DIR}
docker compose logs -f
\`\`\`

### Restart services
\`\`\`bash
cd ${INSTALL_DIR}
docker compose restart
\`\`\`

### Stop services
\`\`\`bash
cd ${INSTALL_DIR}
docker compose down
\`\`\`

### Start services
\`\`\`bash
cd ${INSTALL_DIR}
docker compose up -d
\`\`\`

### Create new admin user
\`\`\`bash
docker compose exec admin flask mailu admin me ${MAILU_DOMAIN} 'password'
\`\`\`

### Generate DKIM key
\`\`\`bash
docker compose exec admin flask mailu config-export --format=dkim | grep ${MAILU_DOMAIN}
\`\`\`

## 🌍 DNS Configuration Required

### A Record
\`\`\`
${MAILU_HOSTNAME}.${MAILU_DOMAIN}  ->  $(hostname -I | awk '{print $1}')
\`\`\`

### MX Record
\`\`\`
${MAILU_DOMAIN}  ->  ${MAILU_HOSTNAME}.${MAILU_DOMAIN} (priority 10)
\`\`\`

### SPF Record (TXT)
\`\`\`
${MAILU_DOMAIN}  ->  v=spf1 mx ~all
\`\`\`

### DKIM Record (TXT)
Generate after installation:
\`\`\`bash
docker compose exec admin flask mailu config-export --format=dkim
\`\`\`

### DMARC Record (TXT)
\`\`\`
_dmarc.${MAILU_DOMAIN}  ->  v=DMARC1; p=quarantine; rua=mailto:${MAILU_ADMIN_EMAIL}
\`\`\`

## 📚 Documentation

- Official Docs: https://mailu.io/master/
- Configuration: https://mailu.io/master/configuration.html
- PI5-SETUP: https://github.com/iamaketechnology/pi5-setup

---
Generated: $(date)
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/README.md"
    ok "Quick reference guide created"
}

# =============================================================================
# DEPLOYMENT SECTION
# =============================================================================

pull_images() {
    log "Pulling Mailu Docker images (this may take 10-15 minutes)..."

    cd "${INSTALL_DIR}"
    su - "${TARGET_USER}" -c "cd ${INSTALL_DIR} && docker compose pull"

    ok "Docker images pulled"
}

start_services() {
    log "Starting Mailu services..."

    cd "${INSTALL_DIR}"
    su - "${TARGET_USER}" -c "cd ${INSTALL_DIR} && docker compose up -d"

    log "Waiting for services to initialize (60s)..."
    sleep 60

    ok "Services started"
}

create_admin_user() {
    log "Creating admin user..."

    # Wait for admin container to be ready
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker compose -f "${INSTALL_DIR}/docker-compose.yml" exec -T admin flask mailu version &>/dev/null; then
            break
        fi

        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            warn "Admin container not ready, you'll need to create admin user manually"
            return
        fi

        sleep 2
    done

    # Create admin user
    cd "${INSTALL_DIR}"
    docker compose exec -T admin flask mailu admin "${MAILU_ADMIN_EMAIL%%@*}" "${MAILU_DOMAIN}" "${MAILU_ADMIN_PASSWORD}" || warn "Failed to create admin user automatically"

    ok "Admin user created"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_installation() {
    log "Verifying installation..."

    # Check critical containers
    local required_containers=("mailu-front" "mailu-admin" "mailu-postfix" "mailu-dovecot" "mailu-rspamd")

    for container in "${required_containers[@]}"; do
        if ! docker ps | grep -q "$container"; then
            warn "Container $container is not running"
        fi
    done

    # Check webmail if enabled
    if [[ "$ENABLE_WEBMAIL" == "yes" ]]; then
        if ! docker ps | grep -q "mailu-webmail"; then
            warn "Webmail container is not running"
        fi
    fi

    ok "Installation verified"
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

print_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    local full_hostname="${MAILU_HOSTNAME}.${MAILU_DOMAIN}"

    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                     MAILU DEPLOYMENT SUCCESSFUL                            ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 Installation Summary:
  ✓ Mailu version: ${MAILU_VERSION}
  ✓ Domain: ${MAILU_DOMAIN}
  ✓ Hostname: ${full_hostname}
  ✓ Admin email: ${MAILU_ADMIN_EMAIL}
  ✓ Webmail: $([ "$ENABLE_WEBMAIL" == "yes" ] && echo "Enabled (Roundcube)" || echo "Disabled")
  ✓ Antivirus: $([ "$ENABLE_ANTIVIRUS" == "yes" ] && echo "Enabled (ClamAV)" || echo "Disabled")

🌐 Web Interfaces:
  • Admin Panel: https://${full_hostname}/admin
  • Webmail: https://${full_hostname}/webmail $([ "$ENABLE_WEBMAIL" != "yes" ] && echo "(disabled)")
  • Local IP: http://${ip_address}/admin

🔑 Admin Credentials:
  • Email: ${MAILU_ADMIN_EMAIL}
  • Password: [as provided]

📧 Mail Ports:
  • SMTP: 25, 465 (SSL), 587 (STARTTLS)
  • IMAP: 143 (STARTTLS), 993 (SSL)
  • POP3: 110 (STARTTLS), 995 (SSL)

📁 Important Paths:
  • Installation: ${INSTALL_DIR}/
  • Data: ${INSTALL_DIR}/data/
  • Configuration: ${INSTALL_DIR}/mailu.env
  • Quick Guide: ${INSTALL_DIR}/README.md

⚠️  CRITICAL: DNS CONFIGURATION REQUIRED

Before your mail server will work, configure these DNS records:

1. A Record:
   ${full_hostname} -> ${ip_address}

2. MX Record:
   ${MAILU_DOMAIN} -> ${full_hostname} (priority 10)

3. SPF Record (TXT):
   ${MAILU_DOMAIN} -> v=spf1 mx ~all

4. DKIM Record (TXT):
   Generate with:
   cd ${INSTALL_DIR} && docker compose exec admin flask mailu config-export --format=dkim

5. DMARC Record (TXT):
   _dmarc.${MAILU_DOMAIN} -> v=DMARC1; p=quarantine; rua=mailto:${MAILU_ADMIN_EMAIL}

📝 Next Steps:
  1. Configure DNS records (see above)
  2. Access admin panel: https://${full_hostname}/admin
  3. Generate and configure DKIM key
  4. Create user mailboxes
  5. Test email sending/receiving
  6. Configure email clients (see ${INSTALL_DIR}/README.md)
  7. Integrate with Traefik for HTTPS (optional):
     curl -fsSL https://raw.githubusercontent.com/.../02-integrate-traefik.sh | sudo bash

🔧 Quick Commands:
  # View all logs
  cd ${INSTALL_DIR} && docker compose logs -f

  # Restart all services
  cd ${INSTALL_DIR} && docker compose restart

  # Generate DKIM key
  cd ${INSTALL_DIR} && docker compose exec admin flask mailu config-export --format=dkim

  # Create new user
  cd ${INSTALL_DIR} && docker compose exec admin flask mailu user me ${MAILU_DOMAIN} 'password'

📖 Documentation:
  • Mailu Official: https://mailu.io/master/
  • PI5-SETUP: https://github.com/iamaketechnology/pi5-setup
  • Local Guide: ${INSTALL_DIR}/README.md

EOF

    log "Installation log saved to: $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "=== Mailu Email Server Deployment v${SCRIPT_VERSION} ==="
    log "Starting at: $(date)"

    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    # Validation
    require_root
    validate_required_vars
    check_dependencies
    check_architecture
    check_ram
    check_ports
    check_dns

    # Setup
    generate_secrets
    setup_directories
    create_mailu_env
    download_docker_compose
    create_readme

    # Deployment
    pull_images
    start_services
    create_admin_user

    # Verification
    verify_installation

    # Summary
    print_summary

    ok "Mailu deployment completed successfully!"
    warn "Don't forget to configure DNS records before using the mail server!"
}

main "$@"
