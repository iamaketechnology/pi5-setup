#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Gitea Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Gitea (GitHub-like Git hosting) with CI/CD capabilities
# Architecture: ARM64 (Raspberry Pi 5)
# Service: Gitea + PostgreSQL
# Auto-Detection: Traefik scenario (DuckDNS, Cloudflare, VPN)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[GITEA]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]  \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]    \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/gitea-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
GITEA_DIR="/home/${TARGET_USER}/stacks/gitea"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
HOMEPAGE_DIR="/home/${TARGET_USER}/stacks/homepage"
CONFIG_DIR="${GITEA_DIR}/config"
COMPOSE_FILE="${GITEA_DIR}/docker-compose.yml"

# Traefik scenario detection
TRAEFIK_SCENARIO=""
BASE_DOMAIN=""
GITEA_DOMAIN=""
GITEA_SUBDOMAIN=""
GITEA_URL=""
USE_SUBDOMAIN=false

# Gitea configuration (can be overridden by env vars)
GITEA_ADMIN_USER="${GITEA_ADMIN_USER:-admin}"
GITEA_ADMIN_PASSWORD="${GITEA_ADMIN_PASSWORD:-}"
GITEA_ADMIN_EMAIL="${GITEA_ADMIN_EMAIL:-}"
GITEA_APP_NAME="${GITEA_APP_NAME:-My Gitea}"
GITEA_DISABLE_REGISTRATION="${GITEA_DISABLE_REGISTRATION:-true}"
GITEA_REQUIRE_SIGNIN_VIEW="${GITEA_REQUIRE_SIGNIN_VIEW:-false}"
GITEA_ENABLE_ACTIONS="${GITEA_ENABLE_ACTIONS:-true}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"

# Service detection
HAS_TRAEFIK=false
HAS_HOMEPAGE=false
PI_IP=""

# SSH configuration
GITEA_SSH_PORT="${GITEA_SSH_PORT:-222}"
GITEA_HTTP_PORT="${GITEA_HTTP_PORT:-3000}"

# Error handling
error_exit() {
    error "$1"
    exit 1
}

# Trap errors
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

    local dependencies=("docker" "curl" "openssl" "ip")
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
                ip)
                    apt install -y iproute2
                    ;;
                *)
                    apt install -y "$dep"
                    ;;
            esac
        done
    fi

    ok "All dependencies are present"
}

check_docker() {
    log "Verifying Docker installation..."

    if ! systemctl is-active --quiet docker; then
        warn "Docker service is not running. Starting Docker..."
        systemctl start docker || error_exit "Failed to start Docker"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker is not functioning correctly"
    fi

    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin not found. Please install docker-compose-plugin"
    fi

    ok "Docker is installed and running"
}

check_traefik_installation() {
    log "Checking for Traefik installation..."

    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        warn "Traefik container is not running"
        log "Gitea can still be deployed, but will only be accessible via local ports"
        HAS_TRAEFIK=false
    else
        if [[ ! -d "$TRAEFIK_DIR" ]] || [[ ! -f "$TRAEFIK_DIR/.env" ]]; then
            warn "Traefik running but .env file not found"
            HAS_TRAEFIK=false
        else
            HAS_TRAEFIK=true
            ok "Traefik is installed and running"
        fi
    fi
}

check_traefik_network() {
    if [[ "$HAS_TRAEFIK" == true ]]; then
        log "Checking for Traefik network..."

        if ! docker network ls --format '{{.Name}}' | grep -q '^traefik_network$'; then
            warn "Traefik network 'traefik_network' not found. Will create it."
            docker network create traefik_network 2>/dev/null || true
        fi

        ok "Traefik network exists"
    fi
}

check_existing_gitea() {
    log "Checking for existing Gitea installation..."

    if docker ps -a --format '{{.Names}}' | grep -q '^gitea$'; then
        warn "Existing Gitea container found"
        read -p "Do you want to remove it and continue? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping and removing existing Gitea containers..."
            docker stop gitea gitea-db 2>/dev/null || true
            docker rm gitea gitea-db 2>/dev/null || true
            ok "Existing containers removed"
        else
            error_exit "Installation cancelled by user"
        fi
    fi
}

check_ports() {
    log "Checking port availability..."

    # Check SSH port
    if netstat -tuln 2>/dev/null | grep -q ":${GITEA_SSH_PORT} " || ss -tuln 2>/dev/null | grep -q ":${GITEA_SSH_PORT} "; then
        warn "Port ${GITEA_SSH_PORT} is in use"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled due to port conflict"
        fi
    fi

    # Check HTTP port
    if netstat -tuln 2>/dev/null | grep -q ":${GITEA_HTTP_PORT} " || ss -tuln 2>/dev/null | grep -q ":${GITEA_HTTP_PORT} "; then
        warn "Port ${GITEA_HTTP_PORT} is in use"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled due to port conflict"
        fi
    fi

    ok "Required ports are available"
}

detect_traefik_scenario() {
    if [[ "$HAS_TRAEFIK" == false ]]; then
        log "Traefik not detected - using local access only"
        TRAEFIK_SCENARIO="none"
        return
    fi

    log "Detecting Traefik deployment scenario..."

    # Read Traefik .env file to determine scenario
    source "$TRAEFIK_DIR/.env"

    if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="duckdns"
        BASE_DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        ok "Detected scenario: DuckDNS (path-based routing)"
        log "Base domain: $BASE_DOMAIN"
    elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="cloudflare"
        BASE_DOMAIN="${CLOUDFLARE_DOMAIN}"
        ok "Detected scenario: Cloudflare (subdomain-based routing)"
        log "Base domain: $BASE_DOMAIN"
    elif [[ -n "${VPN_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="vpn"
        BASE_DOMAIN="${VPN_DOMAIN}"
        ok "Detected scenario: VPN (local .pi.local domains)"
        log "Base domain: $BASE_DOMAIN"
    else
        warn "Could not detect Traefik deployment scenario from .env file"
        TRAEFIK_SCENARIO="none"
    fi
}

detect_pi_ip() {
    log "Detecting Raspberry Pi IP address..."

    # Get primary network interface IP
    PI_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null || echo "192.168.1.100")

    if [[ -z "$PI_IP" ]]; then
        warn "Could not detect IP address, using default: 192.168.1.100"
        PI_IP="192.168.1.100"
    else
        ok "Detected IP address: $PI_IP"
    fi
}

detect_homepage() {
    log "Checking for Homepage dashboard..."

    if [[ -d "$HOMEPAGE_DIR" ]] && docker ps --format '{{.Names}}' | grep -q '^homepage$'; then
        HAS_HOMEPAGE=true
        ok "Homepage installation detected"
    else
        log "Homepage not found (optional)"
        HAS_HOMEPAGE=false
    fi
}

check_system_resources() {
    log "Checking system resources..."

    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        error_exit "Architecture $arch not supported (ARM64 required)"
    fi
    ok "Architecture: ARM64 (aarch64)"

    # Check RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt 2 ]]; then
        warn "Low RAM detected: ${ram_gb}GB (minimum 2GB recommended for Gitea)"
    else
        ok "RAM: ${ram_gb}GB"
    fi

    # Check disk space
    local disk_gb=$(df "$GITEA_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt 5 ]]; then
        warn "Low disk space: ${disk_gb}GB available (minimum 5GB recommended)"
    else
        ok "Disk space: ${disk_gb}GB available"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

generate_secure_password() {
    openssl rand -base64 24 | tr -d "=+/" | cut -c1-20
}

prompt_user_input() {
    log "Collecting Gitea configuration..."
    echo ""
    echo "=========================================="
    echo "Gitea Git Server Configuration"
    echo "=========================================="
    echo ""

    # Traefik scenario information
    if [[ "$HAS_TRAEFIK" == true ]]; then
        echo "Detected Scenario: $TRAEFIK_SCENARIO"
        echo "Base Domain: $BASE_DOMAIN"
        echo ""

        case "$TRAEFIK_SCENARIO" in
            duckdns)
                # Path-based routing
                log "Using path-based routing:"
                echo "  Gitea will be accessible at: https://${BASE_DOMAIN}/git"
                echo ""
                GITEA_DOMAIN="${BASE_DOMAIN}"
                GITEA_URL="https://${BASE_DOMAIN}/git"
                ;;

            cloudflare)
                # Subdomain-based routing
                echo "Do you want to use a subdomain or path-based routing for Gitea?"
                echo ""
                read -p "Use subdomain (e.g., git.$BASE_DOMAIN)? [Y/n]: " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    USE_SUBDOMAIN=true
                    read -p "Enter subdomain for Gitea (default: git): " GITEA_SUBDOMAIN
                    if [[ -z "$GITEA_SUBDOMAIN" ]]; then
                        GITEA_SUBDOMAIN="git"
                        log "Using default: git"
                    fi
                    GITEA_DOMAIN="${GITEA_SUBDOMAIN}.${BASE_DOMAIN}"
                    GITEA_URL="https://${GITEA_DOMAIN}"
                else
                    GITEA_DOMAIN="${BASE_DOMAIN}"
                    GITEA_URL="https://${BASE_DOMAIN}/git"
                fi

                echo ""
                log "Gitea will be accessible at: $GITEA_URL"
                ;;

            vpn)
                # Local .pi.local domain
                echo "Enter local domain for Gitea:"
                echo "(Use .pi.local suffix for VPN scenario)"
                echo ""
                read -p "Enter domain for Gitea (default: git.pi.local): " GITEA_SUBDOMAIN
                if [[ -z "$GITEA_SUBDOMAIN" ]]; then
                    GITEA_SUBDOMAIN="git.pi.local"
                    log "Using default: git.pi.local"
                fi
                GITEA_DOMAIN="${GITEA_SUBDOMAIN}"
                GITEA_URL="https://${GITEA_DOMAIN}"

                echo ""
                log "Gitea will be accessible at: $GITEA_URL"
                ;;
        esac
    else
        echo "No Traefik detected - using local access only"
        GITEA_DOMAIN="${PI_IP}"
        GITEA_URL="http://${PI_IP}:${GITEA_HTTP_PORT}"
        echo "  Gitea will be accessible at: $GITEA_URL"
        echo ""
    fi

    # Admin user configuration
    echo ""
    log "Admin Account Configuration"
    echo ""

    # Admin username
    if [[ -z "${GITEA_ADMIN_USER}" ]] || [[ "${GITEA_ADMIN_USER}" == "admin" ]]; then
        read -p "Enter admin username (default: admin): " input_user
        if [[ -n "$input_user" ]]; then
            GITEA_ADMIN_USER="$input_user"
        else
            GITEA_ADMIN_USER="admin"
        fi
    fi

    # Admin password
    if [[ -z "$GITEA_ADMIN_PASSWORD" ]]; then
        GITEA_ADMIN_PASSWORD=$(generate_secure_password)
        ok "Generated secure password: $GITEA_ADMIN_PASSWORD"
        echo ""
        warn "IMPORTANT: Save this password securely!"
        echo ""
        read -p "Press Enter to continue or type a custom password: " input_pass
        if [[ -n "$input_pass" ]]; then
            GITEA_ADMIN_PASSWORD="$input_pass"
        fi
    fi

    # Admin email
    if [[ -z "$GITEA_ADMIN_EMAIL" ]]; then
        while true; do
            read -p "Enter admin email: " GITEA_ADMIN_EMAIL
            if [[ -z "$GITEA_ADMIN_EMAIL" ]]; then
                warn "Email cannot be empty"
            elif [[ ! "$GITEA_ADMIN_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                warn "Invalid email format"
                GITEA_ADMIN_EMAIL=""
            else
                break
            fi
        done
    fi

    # PostgreSQL password
    if [[ -z "$POSTGRES_PASSWORD" ]]; then
        POSTGRES_PASSWORD=$(generate_secure_password)
        ok "Generated database password"
    fi

    # Gitea Actions configuration
    echo ""
    log "Gitea Actions (CI/CD) Configuration"
    echo ""
    if [[ -z "${GITEA_ENABLE_ACTIONS}" ]] || [[ "${GITEA_ENABLE_ACTIONS}" == "true" ]]; then
        read -p "Enable Gitea Actions (CI/CD)? [Y/n]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            GITEA_ENABLE_ACTIONS="false"
        else
            GITEA_ENABLE_ACTIONS="true"
        fi
    fi

    # Security settings
    echo ""
    log "Security Settings"
    echo ""

    # Disable public registration
    read -p "Disable public registration (admin creates users)? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        GITEA_DISABLE_REGISTRATION="false"
    else
        GITEA_DISABLE_REGISTRATION="true"
    fi

    # Require signin to view
    read -p "Require sign-in to view content? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        GITEA_REQUIRE_SIGNIN_VIEW="true"
    else
        GITEA_REQUIRE_SIGNIN_VIEW="false"
    fi

    # SSH port configuration
    echo ""
    log "SSH Configuration"
    echo ""
    echo "Current SSH port: $GITEA_SSH_PORT (default: 222)"
    read -p "Change SSH port? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter SSH port (avoid 22 - used by system): " input_port
        if [[ -n "$input_port" ]] && [[ "$input_port" =~ ^[0-9]+$ ]]; then
            GITEA_SSH_PORT="$input_port"
        fi
    fi

    # Confirmation
    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Gitea URL: $GITEA_URL"
    if [[ "$HAS_TRAEFIK" == true ]]; then
        echo "Traefik Scenario: $TRAEFIK_SCENARIO"
    else
        echo "Access: Local only (no Traefik)"
    fi
    echo "Admin User: $GITEA_ADMIN_USER"
    echo "Admin Email: $GITEA_ADMIN_EMAIL"
    echo "Admin Password: $GITEA_ADMIN_PASSWORD"
    echo "SSH Port: $GITEA_SSH_PORT"
    echo "HTTP Port: $GITEA_HTTP_PORT"
    echo "Gitea Actions: $GITEA_ENABLE_ACTIONS"
    echo "Public Registration: $([ "$GITEA_DISABLE_REGISTRATION" = "true" ] && echo "Disabled" || echo "Enabled")"
    echo "Require Sign-in: $([ "$GITEA_REQUIRE_SIGNIN_VIEW" = "true" ] && echo "Yes" || echo "No")"
    echo "=========================================="
    echo ""

    read -p "Proceed with this configuration? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error_exit "Installation cancelled by user"
    fi
}

# =============================================================================
# MAIN EXECUTION SECTION
# =============================================================================

setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    log "=== Gitea Deployment - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_directory_structure() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "$GITEA_DIR"/{data,postgres,config,backups}

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$GITEA_DIR"

    ok "Directory structure created at $GITEA_DIR"
}

generate_env_file() {
    log "Generating environment file..."

    cat > "$GITEA_DIR/.env" << EOF
# Gitea Environment Variables
# Generated: $(date)
# WARNING: This file contains sensitive information - keep it secure!

# Gitea Configuration
GITEA_DOMAIN=${GITEA_DOMAIN}
GITEA_ROOT_URL=${GITEA_URL}
GITEA_SSH_PORT=${GITEA_SSH_PORT}
GITEA_HTTP_PORT=${GITEA_HTTP_PORT}
GITEA_APP_NAME=${GITEA_APP_NAME}

# Admin Account
GITEA_ADMIN_USER=${GITEA_ADMIN_USER}
GITEA_ADMIN_PASSWORD=${GITEA_ADMIN_PASSWORD}
GITEA_ADMIN_EMAIL=${GITEA_ADMIN_EMAIL}

# Security Settings
GITEA_DISABLE_REGISTRATION=${GITEA_DISABLE_REGISTRATION}
GITEA_REQUIRE_SIGNIN_VIEW=${GITEA_REQUIRE_SIGNIN_VIEW}

# Gitea Actions (CI/CD)
GITEA_ENABLE_ACTIONS=${GITEA_ENABLE_ACTIONS}

# Database Configuration
POSTGRES_USER=gitea
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
POSTGRES_DB=gitea

# Traefik Integration
TRAEFIK_SCENARIO=${TRAEFIK_SCENARIO}
HAS_TRAEFIK=${HAS_TRAEFIK}
EOF

    chmod 600 "$GITEA_DIR/.env"
    chown "$TARGET_USER:$TARGET_USER" "$GITEA_DIR/.env"
    ok "Environment file created with restricted permissions"
}

generate_docker_compose() {
    log "Generating docker-compose.yml..."

    # Determine Traefik labels based on scenario
    local traefik_labels=""
    local networks_config=""

    if [[ "$HAS_TRAEFIK" == true ]]; then
        networks_config="    networks:
      - traefik_network
      - gitea_internal"

        case "$TRAEFIK_SCENARIO" in
            duckdns)
                # Path-based routing
                traefik_labels="    labels:
      - \"traefik.enable=true\"
      - \"traefik.http.routers.gitea.rule=Host(\\\`${BASE_DOMAIN}\\\`) && PathPrefix(\\\`/git\\\`)\"
      - \"traefik.http.routers.gitea.entrypoints=websecure\"
      - \"traefik.http.routers.gitea.tls=true\"
      - \"traefik.http.routers.gitea.tls.certresolver=letsencrypt\"
      - \"traefik.http.services.gitea.loadbalancer.server.port=${GITEA_HTTP_PORT}\"
      - \"traefik.http.middlewares.gitea-stripprefix.stripprefix.prefixes=/git\"
      - \"traefik.http.routers.gitea.middlewares=gitea-stripprefix\"
      - \"traefik.docker.network=traefik_network\""
                ;;

            cloudflare)
                if [[ "$USE_SUBDOMAIN" == true ]]; then
                    # Subdomain-based routing
                    traefik_labels="    labels:
      - \"traefik.enable=true\"
      - \"traefik.http.routers.gitea.rule=Host(\\\`${GITEA_DOMAIN}\\\`)\"
      - \"traefik.http.routers.gitea.entrypoints=websecure\"
      - \"traefik.http.routers.gitea.tls=true\"
      - \"traefik.http.routers.gitea.tls.certresolver=cloudflare\"
      - \"traefik.http.services.gitea.loadbalancer.server.port=${GITEA_HTTP_PORT}\"
      - \"traefik.docker.network=traefik_network\""
                else
                    # Path-based routing
                    traefik_labels="    labels:
      - \"traefik.enable=true\"
      - \"traefik.http.routers.gitea.rule=Host(\\\`${BASE_DOMAIN}\\\`) && PathPrefix(\\\`/git\\\`)\"
      - \"traefik.http.routers.gitea.entrypoints=websecure\"
      - \"traefik.http.routers.gitea.tls=true\"
      - \"traefik.http.routers.gitea.tls.certresolver=cloudflare\"
      - \"traefik.http.services.gitea.loadbalancer.server.port=${GITEA_HTTP_PORT}\"
      - \"traefik.http.middlewares.gitea-stripprefix.stripprefix.prefixes=/git\"
      - \"traefik.http.routers.gitea.middlewares=gitea-stripprefix\"
      - \"traefik.docker.network=traefik_network\""
                fi
                ;;

            vpn)
                # VPN local domain
                traefik_labels="    labels:
      - \"traefik.enable=true\"
      - \"traefik.http.routers.gitea.rule=Host(\\\`${GITEA_DOMAIN}\\\`)\"
      - \"traefik.http.routers.gitea.entrypoints=websecure\"
      - \"traefik.http.routers.gitea.tls=true\"
      - \"traefik.http.services.gitea.loadbalancer.server.port=${GITEA_HTTP_PORT}\"
      - \"traefik.docker.network=traefik_network\""
                ;;
        esac
    else
        networks_config="    networks:
      - gitea_internal"
    fi

    cat > "$COMPOSE_FILE" << EOF
# Gitea Git Server Docker Compose Configuration
# Generated: $(date)

version: '3.8'

services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=gitea-db:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=\${POSTGRES_PASSWORD}
      - GITEA__server__DOMAIN=\${GITEA_DOMAIN}
      - GITEA__server__ROOT_URL=\${GITEA_ROOT_URL}
      - GITEA__server__SSH_PORT=\${GITEA_SSH_PORT}
      - GITEA__server__HTTP_PORT=\${GITEA_HTTP_PORT}
      - GITEA__server__APP_NAME=\${GITEA_APP_NAME}
      - GITEA__service__DISABLE_REGISTRATION=\${GITEA_DISABLE_REGISTRATION}
      - GITEA__service__REQUIRE_SIGNIN_VIEW=\${GITEA_REQUIRE_SIGNIN_VIEW}
      - GITEA__actions__ENABLED=\${GITEA_ENABLE_ACTIONS}
      - GITEA__actions__DEFAULT_ACTIONS_URL=https://gitea.com
      - GITEA__security__INSTALL_LOCK=false
      - GITEA__log__MODE=console
      - GITEA__log__LEVEL=Info
    volumes:
      - ./data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "\${GITEA_HTTP_PORT}:\${GITEA_HTTP_PORT}"
      - "\${GITEA_SSH_PORT}:22"
${networks_config}
    depends_on:
      gitea-db:
        condition: service_healthy
${traefik_labels}
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:\${GITEA_HTTP_PORT}/api/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  gitea-db:
    image: postgres:15-alpine
    container_name: gitea-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=gitea
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
      - POSTGRES_DB=gitea
    volumes:
      - ./postgres:/var/lib/postgresql/data
    networks:
      - gitea_internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gitea"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

networks:
  gitea_internal:
    name: gitea_internal
    driver: bridge
EOF

    # Add traefik_network if Traefik is available
    if [[ "$HAS_TRAEFIK" == true ]]; then
        cat >> "$COMPOSE_FILE" << EOF
  traefik_network:
    external: true
    name: traefik_network
EOF
    fi

    chown "$TARGET_USER:$TARGET_USER" "$COMPOSE_FILE"
    ok "Docker Compose configuration generated"
}

generate_app_ini() {
    log "Generating app.ini configuration template..."

    mkdir -p "$CONFIG_DIR"

    cat > "$CONFIG_DIR/app.ini.template" << 'EOF'
# Gitea Configuration File (app.ini)
# This is a template - actual configuration will be generated on first run
# Additional settings can be added here

[server]
DOMAIN               = ${GITEA_DOMAIN}
ROOT_URL             = ${GITEA_ROOT_URL}
SSH_PORT             = ${GITEA_SSH_PORT}
HTTP_PORT            = ${GITEA_HTTP_PORT}
APP_NAME             = ${GITEA_APP_NAME}
DISABLE_SSH          = false
START_SSH_SERVER     = true
SSH_LISTEN_PORT      = 22
LFS_START_SERVER     = true

[database]
DB_TYPE  = postgres
HOST     = gitea-db:5432
NAME     = gitea
USER     = gitea
PASSWD   = ${POSTGRES_PASSWORD}
SSL_MODE = disable

[service]
DISABLE_REGISTRATION       = ${GITEA_DISABLE_REGISTRATION}
REQUIRE_SIGNIN_VIEW        = ${GITEA_REQUIRE_SIGNIN_VIEW}
REGISTER_EMAIL_CONFIRM     = false
ENABLE_NOTIFY_MAIL         = false
ALLOW_ONLY_EXTERNAL_REGISTRATION = false
ENABLE_CAPTCHA             = false
DEFAULT_KEEP_EMAIL_PRIVATE = false
DEFAULT_ALLOW_CREATE_ORGANIZATION = true

[actions]
ENABLED = ${GITEA_ENABLE_ACTIONS}
DEFAULT_ACTIONS_URL = https://gitea.com

[security]
INSTALL_LOCK = true
SECRET_KEY   =
INTERNAL_TOKEN =

[log]
MODE      = console
LEVEL     = Info
ROOT_PATH = /data/log

[repository]
ROOT = /data/git/repositories

[ui]
DEFAULT_THEME = auto
THEMES        = auto,gitea,arc-green

[webhook]
ALLOWED_HOST_LIST = *

[openid]
ENABLE_OPENID_SIGNIN = false
ENABLE_OPENID_SIGNUP = false

[other]
SHOW_FOOTER_VERSION = true
SHOW_FOOTER_TEMPLATE_LOAD_TIME = true
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/app.ini.template"
    ok "Configuration template created"
}

configure_firewall() {
    log "Configuring firewall rules..."

    if command -v ufw &> /dev/null; then
        # Allow SSH port for Git
        ufw allow "${GITEA_SSH_PORT}/tcp" comment "Gitea SSH" 2>/dev/null || true

        # Allow HTTP port if not using Traefik
        if [[ "$HAS_TRAEFIK" == false ]]; then
            ufw allow "${GITEA_HTTP_PORT}/tcp" comment "Gitea HTTP" 2>/dev/null || true
        fi

        ok "Firewall rules configured"
    else
        warn "UFW not found - skipping firewall configuration"
    fi
}

deploy_gitea_stack() {
    log "Deploying Gitea stack..."

    # Change to gitea directory
    cd "$GITEA_DIR"

    # Pull images first
    log "Pulling Docker images (this may take a few minutes)..."
    sudo -u "$TARGET_USER" docker compose pull

    # Start the stack
    log "Starting Gitea stack..."
    sudo -u "$TARGET_USER" docker compose up -d

    # Wait for containers to be healthy
    log "Waiting for containers to start (this may take up to 2 minutes)..."
    sleep 30

    # Wait for database to be ready
    log "Waiting for database initialization..."
    local retries=0
    local max_retries=20
    while ! docker exec gitea-db pg_isready -U gitea &>/dev/null; do
        ((retries++))
        if [[ $retries -ge $max_retries ]]; then
            error "Database failed to start after ${max_retries} attempts"
            break
        fi
        sleep 3
    done

    ok "Gitea stack deployed successfully"
}

create_admin_user() {
    log "Creating admin user..."

    # Wait for Gitea to be fully ready
    log "Waiting for Gitea to finish initialization..."
    sleep 30

    # Check if admin user already exists
    if docker exec gitea gitea admin user list 2>/dev/null | grep -q "^${GITEA_ADMIN_USER}$"; then
        ok "Admin user already exists"
        return
    fi

    # Create admin user
    log "Creating admin user: ${GITEA_ADMIN_USER}"
    if docker exec gitea gitea admin user create \
        --username "${GITEA_ADMIN_USER}" \
        --password "${GITEA_ADMIN_PASSWORD}" \
        --email "${GITEA_ADMIN_EMAIL}" \
        --admin \
        --must-change-password=false 2>&1 | tee -a "$LOG_FILE"; then
        ok "Admin user created successfully"
    else
        warn "Admin user creation may have failed - check logs"
        log "You can create the user manually via web interface"
    fi
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_deployment() {
    log "Verifying deployment..."

    local checks_passed=0
    local total_checks=6

    # Check Gitea container
    if docker ps | grep -q 'gitea'; then
        ok "  Gitea container is running"
        ((checks_passed++))
    else
        error "  Gitea container is not running"
    fi

    # Check database container
    if docker ps | grep -q 'gitea-db'; then
        ok "  PostgreSQL container is running"
        ((checks_passed++))
    else
        error "  PostgreSQL container is not running"
    fi

    # Check database health
    if docker exec gitea-db pg_isready -U gitea &>/dev/null; then
        ok "  Database health check passed"
        ((checks_passed++))
    else
        warn "  Database health check failed"
    fi

    # Check Gitea health
    sleep 5
    if curl -sf "http://localhost:${GITEA_HTTP_PORT}/api/healthz" &>/dev/null; then
        ok "  Gitea health check passed"
        ((checks_passed++))
    else
        warn "  Gitea health check failed (may need more time)"
    fi

    # Check network
    if docker network ls | grep -q 'gitea_internal'; then
        ok "  Gitea internal network created"
        ((checks_passed++))
    else
        error "  Gitea internal network not found"
    fi

    # Check Traefik integration if applicable
    if [[ "$HAS_TRAEFIK" == true ]]; then
        if docker inspect gitea 2>/dev/null | grep -q "traefik_network"; then
            ok "  Gitea connected to Traefik network"
            ((checks_passed++))
        else
            warn "  Gitea not connected to Traefik network"
        fi
    else
        ok "  Traefik integration skipped (not installed)"
        ((checks_passed++))
    fi

    echo ""
    log "Verification: $checks_passed/$total_checks checks passed"

    if [[ $checks_passed -ge 5 ]]; then
        ok "Deployment verification successful"
        return 0
    else
        error "Some verification checks failed"
        return 1
    fi
}

test_connection() {
    log "Testing connection to Gitea..."

    # Wait for SSL certificates if using Traefik
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        log "Waiting 30 seconds for SSL certificate generation..."
        sleep 30
    fi

    # Test Gitea endpoint
    log "Testing Gitea: $GITEA_URL"
    if curl -sf -k -m 10 "$GITEA_URL" &> /dev/null; then
        ok "Gitea accessible"
    else
        warn "Gitea test failed (DNS propagation may take time)"
    fi
}

# =============================================================================
# INTEGRATION SECTION
# =============================================================================

update_homepage_integration() {
    if [[ "$HAS_HOMEPAGE" == false ]]; then
        return
    fi

    log "Updating Homepage dashboard integration..."

    local services_file="${HOMEPAGE_DIR}/config/services.yaml"

    if [[ ! -f "$services_file" ]]; then
        warn "Homepage services.yaml not found - skipping integration"
        return
    fi

    # Check if Gitea entry already exists
    if grep -q "Gitea:" "$services_file" 2>/dev/null; then
        ok "Gitea already in Homepage dashboard"
        return
    fi

    # Add Gitea entry to Homepage
    log "Adding Gitea to Homepage dashboard..."

    # Backup existing file
    cp "$services_file" "${services_file}.backup"

    # Add Gitea entry (append to Infrastructure section if exists)
    if grep -q "Infrastructure:" "$services_file"; then
        # Add after Infrastructure section
        sed -i.tmp '/^- Infrastructure:/a\
    - Gitea:\
        href: '"${GITEA_URL}"'\
        description: Git hosting and CI/CD\
        icon: gitea' "$services_file"
        rm -f "${services_file}.tmp"
    else
        # Create new section
        cat >> "$services_file" << EOF

- Git & CI/CD:
    - Gitea:
        href: ${GITEA_URL}
        description: Git hosting and CI/CD
        icon: gitea
EOF
    fi

    # Restart Homepage to apply changes
    if docker ps --format '{{.Names}}' | grep -q '^homepage$'; then
        log "Restarting Homepage..."
        docker restart homepage &>/dev/null || true
        ok "Homepage integration updated"
    fi
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "Gitea Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Installation Details:"
    echo "  Gitea URL: $GITEA_URL"
    echo "  Stack Location: $GITEA_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access Information:"
    echo "  Web Interface: $GITEA_URL"
    echo "  Admin Username: $GITEA_ADMIN_USER"
    echo "  Admin Password: $GITEA_ADMIN_PASSWORD"
    echo "  Admin Email: $GITEA_ADMIN_EMAIL"
    echo ""
    echo "Git SSH Access:"
    echo "  SSH Port: $GITEA_SSH_PORT"
    if [[ "$HAS_TRAEFIK" == true ]]; then
        echo "  Clone URL: git@${GITEA_DOMAIN}:${GITEA_SSH_PORT}/username/repo.git"
    else
        echo "  Clone URL: git@${PI_IP}:${GITEA_SSH_PORT}/username/repo.git"
    fi
    echo ""
    echo "Example Git Commands:"
    echo "  git clone git@${GITEA_DOMAIN}:${GITEA_SSH_PORT}/username/repo.git"
    echo "  git remote add origin git@${GITEA_DOMAIN}:${GITEA_SSH_PORT}/username/repo.git"
    echo ""
    echo "Features:"
    echo "  Gitea Actions (CI/CD): $([ "$GITEA_ENABLE_ACTIONS" = "true" ] && echo "Enabled" || echo "Disabled")"
    echo "  Public Registration: $([ "$GITEA_DISABLE_REGISTRATION" = "true" ] && echo "Disabled" || echo "Enabled")"
    echo "  Require Sign-in: $([ "$GITEA_REQUIRE_SIGNIN_VIEW" = "true" ] && echo "Yes" || echo "No")"
    echo "  Git LFS: Enabled"
    echo ""
    if [[ "$HAS_TRAEFIK" == true ]]; then
        echo "Traefik Integration:"
        echo "  Scenario: $TRAEFIK_SCENARIO"
        echo "  Domain: $GITEA_DOMAIN"
        echo "  HTTPS: Automatic via Traefik"
    else
        echo "Access Mode: Local only (no Traefik)"
        echo "  Use VPN or port forwarding for remote access"
    fi
    echo ""
    echo "Container Management:"
    echo "  View logs: cd $GITEA_DIR && docker compose logs -f"
    echo "  Restart: cd $GITEA_DIR && docker compose restart"
    echo "  Stop: cd $GITEA_DIR && docker compose down"
    echo "  Start: cd $GITEA_DIR && docker compose up -d"
    echo ""
    echo "Administration:"
    echo "  User management: docker exec gitea gitea admin user list"
    echo "  Create user: docker exec gitea gitea admin user create --username <name> --email <email>"
    echo "  Change password: docker exec gitea gitea admin user change-password -u <username>"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Gitea at: $GITEA_URL"
    echo "  2. Login with admin credentials shown above"
    echo "  3. Configure your SSH key in User Settings"
    if [[ "$GITEA_ENABLE_ACTIONS" == "true" ]]; then
        echo "  4. Install Gitea Actions Runner: ./02-runners-setup.sh (coming soon)"
    fi
    echo "  5. Create your first repository"
    echo "  6. Clone and start developing!"
    echo ""

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "Important Notes:"
        echo "  - DNS propagation may take 5-15 minutes"
        echo "  - SSL certificate will be issued automatically"
        echo "  - SSH access requires port ${GITEA_SSH_PORT} to be forwarded on your router"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "vpn" ]]; then
        echo "Important Notes:"
        echo "  - Access only works when connected to VPN"
        echo "  - Ensure VPN DNS is configured for .pi.local domains"
    fi

    echo ""
    echo "Backup:"
    echo "  Repositories: $GITEA_DIR/data/git/repositories"
    echo "  Database: PostgreSQL in $GITEA_DIR/postgres"
    echo "  Config: $GITEA_DIR/data/gitea/conf/app.ini"
    echo "  Backups directory: $GITEA_DIR/backups"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check logs: docker logs gitea"
    echo "  - Check database: docker logs gitea-db"
    echo "  - Test locally: curl -I http://localhost:${GITEA_HTTP_PORT}"
    if [[ "$HAS_TRAEFIK" == true ]]; then
        echo "  - Check Traefik: docker logs traefik"
        echo "  - Verify Traefik routing: docker exec traefik wget -qO- http://localhost:8080/api/http/routers"
    fi
    echo ""
    echo "Documentation:"
    echo "  Gitea Docs: https://docs.gitea.io/"
    echo "  Gitea Actions: https://docs.gitea.io/en-us/actions/"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$GITEA_DIR/DEPLOYMENT_INFO.txt" << SUMMARY
Gitea Deployment Summary
Generated: $(date)

Gitea URL: ${GITEA_URL}
Admin Username: ${GITEA_ADMIN_USER}
Admin Password: ${GITEA_ADMIN_PASSWORD}
Admin Email: ${GITEA_ADMIN_EMAIL}

Git SSH Access:
  SSH Port: ${GITEA_SSH_PORT}
  Clone URL: git@${GITEA_DOMAIN}:${GITEA_SSH_PORT}/username/repo.git

Features:
  Gitea Actions: ${GITEA_ENABLE_ACTIONS}
  Public Registration: $([ "$GITEA_DISABLE_REGISTRATION" = "true" ] && echo "Disabled" || echo "Enabled")
  Require Sign-in: $([ "$GITEA_REQUIRE_SIGNIN_VIEW" = "true" ] && echo "Yes" || echo "No")

Stack Directory: ${GITEA_DIR}
Log File: ${LOG_FILE}

Container Commands:
  cd ${GITEA_DIR}
  docker compose logs -f          # View logs
  docker compose restart          # Restart services
  docker compose down             # Stop services
  docker compose up -d            # Start services

Administration:
  docker exec gitea gitea admin user list
  docker exec gitea gitea admin user create --username <name> --email <email>
  docker exec gitea gitea admin user change-password -u <username>

Backup Locations:
  Repositories: ${GITEA_DIR}/data/git/repositories
  Database: ${GITEA_DIR}/postgres
  Config: ${GITEA_DIR}/data/gitea/conf/app.ini
  Backups: ${GITEA_DIR}/backups

Configuration:
  Environment: ${GITEA_DIR}/.env
  Docker Compose: ${COMPOSE_FILE}
SUMMARY

    chmod 600 "$GITEA_DIR/DEPLOYMENT_INFO.txt"
    chown "$TARGET_USER:$TARGET_USER" "$GITEA_DIR/DEPLOYMENT_INFO.txt"

    ok "Deployment information saved to $GITEA_DIR/DEPLOYMENT_INFO.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root
    setup_logging

    echo ""
    log "Starting Gitea deployment for Raspberry Pi 5"
    echo ""

    # Validation
    check_dependencies
    check_docker
    check_traefik_installation
    check_traefik_network
    check_existing_gitea
    check_ports
    check_system_resources
    detect_traefik_scenario
    detect_pi_ip
    detect_homepage
    echo ""

    # User input
    prompt_user_input
    echo ""

    # Main execution
    create_directory_structure
    generate_env_file
    generate_docker_compose
    generate_app_ini
    configure_firewall
    echo ""

    # Deployment
    deploy_gitea_stack
    create_admin_user
    echo ""

    # Verification
    verify_deployment
    test_connection
    echo ""

    # Integration
    update_homepage_integration
    echo ""

    # Summary
    show_summary
}

main "$@"
