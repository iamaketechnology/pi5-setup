#!/usr/bin/env bash

#==============================================================================
# *arr Stack Deployment Script for Raspberry Pi 5
#==============================================================================
# Description: Automated deployment of Radarr + Sonarr + Prowlarr stack
#              for media management with Traefik integration and Homepage widgets
#
# Components:
#   - Prowlarr: Centralized indexer manager
#   - Radarr: Movie collection management and automation
#   - Sonarr: TV show collection management and automation
#
# Author: DevOps Agent (Claude)
# Platform: Raspberry Pi OS (64-bit) / ARM64
# Requirements: Docker, Docker Compose
# Estimated Runtime: 3-5 minutes
#
# Usage:
#   sudo ./02-arr-stack-deploy.sh [OPTIONS]
#
# Options:
#   --dry-run           Show what would be done without executing
#   --verbose           Enable detailed output
#   --help              Display this help message
#
#==============================================================================

set -euo pipefail

#==============================================================================
# Script Directory Detection & Library Import
#==============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library functions
# shellcheck source=../../common-scripts/lib.sh
if [[ -f "${SCRIPT_DIR}/../../common-scripts/lib.sh" ]]; then
    source "${SCRIPT_DIR}/../../common-scripts/lib.sh"
else
    echo "ERROR: Could not find lib.sh at ${SCRIPT_DIR}/../../common-scripts/lib.sh"
    exit 1
fi

#==============================================================================
# Environment Variables & Configuration
#==============================================================================

# *arr Stack Versions
RADARR_VERSION=${RADARR_VERSION:-latest}
SONARR_VERSION=${SONARR_VERSION:-latest}
PROWLARR_VERSION=${PROWLARR_VERSION:-latest}

# Service Ports
RADARR_PORT=${RADARR_PORT:-7878}
SONARR_PORT=${SONARR_PORT:-8989}
PROWLARR_PORT=${PROWLARR_PORT:-9696}

# Media & Download Paths
MEDIA_DIR=${MEDIA_DIR:-/home/pi/media}
DOWNLOADS_DIR=${DOWNLOADS_DIR:-/home/pi/downloads}

MOVIES_DIR=${MOVIES_DIR:-${MEDIA_DIR}/movies}
TV_SHOWS_DIR=${TV_SHOWS_DIR:-${MEDIA_DIR}/tv}

# Stack Configuration
STACK_NAME=${STACK_NAME:-arr-stack}
STACK_DIR=${STACK_DIR:-/home/pi/stacks/arr}

# Traefik Integration
TRAEFIK_ENABLE=${TRAEFIK_ENABLE:-auto}
RADARR_DOMAIN=${RADARR_DOMAIN:-}
SONARR_DOMAIN=${SONARR_DOMAIN:-}
PROWLARR_DOMAIN=${PROWLARR_DOMAIN:-}

# Homepage Integration
HOMEPAGE_ENABLE=${HOMEPAGE_ENABLE:-auto}

# Timezone
TZ=${TZ:-Europe/Paris}

# User configuration
TARGET_USER=${SUDO_USER:-pi}
TARGET_UID=$(id -u "${TARGET_USER}" 2>/dev/null || echo "1000")
TARGET_GID=$(id -g "${TARGET_USER}" 2>/dev/null || echo "1000")

# Traefik scenario detection results
TRAEFIK_SCENARIO=""
TRAEFIK_DOMAIN=""
TRAEFIK_NETWORK=""

# Service URLs (populated after detection)
RADARR_URL=""
SONARR_URL=""
PROWLARR_URL=""

#==============================================================================
# Usage Function
#==============================================================================

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy *arr Stack (Radarr + Sonarr + Prowlarr) on Raspberry Pi 5

OPTIONS:
    --dry-run           Show what would be done without executing
    --verbose           Enable detailed output
    --help              Display this help message

EXAMPLES:
    # Standard deployment
    sudo ./02-arr-stack-deploy.sh

    # Dry-run to see what would happen
    sudo ./02-arr-stack-deploy.sh --dry-run

    # Verbose output for debugging
    sudo ./02-arr-stack-deploy.sh --verbose

ENVIRONMENT VARIABLES:
    RADARR_VERSION      Radarr Docker image version (default: latest)
    SONARR_VERSION      Sonarr Docker image version (default: latest)
    PROWLARR_VERSION    Prowlarr Docker image version (default: latest)
    RADARR_PORT         Radarr port (default: 7878)
    SONARR_PORT         Sonarr port (default: 8989)
    PROWLARR_PORT       Prowlarr port (default: 9696)
    MEDIA_DIR           Media directory path (default: /home/pi/media)
    DOWNLOADS_DIR       Downloads directory path (default: /home/pi/downloads)
    STACK_DIR           Stack directory (default: /home/pi/stacks/arr)
    TZ                  Timezone (default: Europe/Paris)

EOF
    exit 0
}

#==============================================================================
# Traefik Scenario Detection
#==============================================================================

detect_traefik_scenario() {
    log_section "Detecting Traefik Configuration"

    local traefik_env="/home/pi/stacks/traefik/.env"

    if [[ ! -f "${traefik_env}" ]]; then
        log_info "Traefik not detected, using local port-based access"
        TRAEFIK_SCENARIO="none"
        TRAEFIK_ENABLE="false"

        # Set local URLs
        RADARR_URL="http://$(hostname -I | awk '{print $1}'):${RADARR_PORT}"
        SONARR_URL="http://$(hostname -I | awk '{print $1}'):${SONARR_PORT}"
        PROWLARR_URL="http://$(hostname -I | awk '{print $1}'):${PROWLARR_PORT}"

        return 0
    fi

    log_info "Traefik detected, analyzing configuration..."

    # Source Traefik environment file
    # shellcheck disable=SC1090
    source "${traefik_env}"

    # Detect scenario based on environment variables
    if [[ -n "${DUCKDNS_TOKEN:-}" ]] || [[ "${CERT_RESOLVER:-}" == "letsencrypt" ]]; then
        TRAEFIK_SCENARIO="duckdns"
        TRAEFIK_DOMAIN="${DOMAIN:-}"
        TRAEFIK_NETWORK="traefik-public"

        # DuckDNS uses path-based routing
        RADARR_URL="https://${TRAEFIK_DOMAIN}/radarr"
        SONARR_URL="https://${TRAEFIK_DOMAIN}/sonarr"
        PROWLARR_URL="https://${TRAEFIK_DOMAIN}/prowlarr"

        log_success "Scenario: DuckDNS (path-based routing)"
        log_info "Domain: ${TRAEFIK_DOMAIN}"

    elif [[ -n "${CF_API_EMAIL:-}" ]] || [[ "${CERT_RESOLVER:-}" == "cloudflare" ]]; then
        TRAEFIK_SCENARIO="cloudflare"
        TRAEFIK_DOMAIN="${DOMAIN:-}"
        TRAEFIK_NETWORK="traefik-public"

        # Cloudflare uses subdomain routing
        RADARR_DOMAIN="${RADARR_DOMAIN:-radarr.${TRAEFIK_DOMAIN}}"
        SONARR_DOMAIN="${SONARR_DOMAIN:-sonarr.${TRAEFIK_DOMAIN}}"
        PROWLARR_DOMAIN="${PROWLARR_DOMAIN:-prowlarr.${TRAEFIK_DOMAIN}}"

        RADARR_URL="https://${RADARR_DOMAIN}"
        SONARR_URL="https://${SONARR_DOMAIN}"
        PROWLARR_URL="https://${PROWLARR_DOMAIN}"

        log_success "Scenario: Cloudflare (subdomain routing)"
        log_info "Domain: ${TRAEFIK_DOMAIN}"

    elif [[ -n "${VPN_PROVIDER:-}" ]] || [[ "${USE_VPN:-}" == "true" ]]; then
        TRAEFIK_SCENARIO="vpn"
        TRAEFIK_DOMAIN="${DOMAIN:-pi.local}"
        TRAEFIK_NETWORK="traefik-public"

        # VPN uses local subdomain routing
        RADARR_URL="http://radarr.${TRAEFIK_DOMAIN}"
        SONARR_URL="http://sonarr.${TRAEFIK_DOMAIN}"
        PROWLARR_URL="http://prowlarr.${TRAEFIK_DOMAIN}"

        log_success "Scenario: VPN (local subdomain routing)"
        log_info "Domain: ${TRAEFIK_DOMAIN}"

    else
        log_warning "Unknown Traefik scenario, falling back to local access"
        TRAEFIK_SCENARIO="none"
        TRAEFIK_ENABLE="false"

        RADARR_URL="http://$(hostname -I | awk '{print $1}'):${RADARR_PORT}"
        SONARR_URL="http://$(hostname -I | awk '{print $1}'):${SONARR_PORT}"
        PROWLARR_URL="http://$(hostname -I | awk '{print $1}'):${PROWLARR_PORT}"
    fi

    # Override with auto-enable if Traefik scenario detected
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]] && [[ "${TRAEFIK_ENABLE}" == "auto" ]]; then
        TRAEFIK_ENABLE="true"
        log_info "Traefik integration: ENABLED"
    fi
}

#==============================================================================
# Directory Setup
#==============================================================================

setup_directories() {
    log_section "Setting Up Directory Structure"

    # Create media directories
    log_info "Creating media directories..."

    local dirs=(
        "${MEDIA_DIR}"
        "${MOVIES_DIR}"
        "${TV_SHOWS_DIR}"
        "${DOWNLOADS_DIR}"
        "${DOWNLOADS_DIR}/movies"
        "${DOWNLOADS_DIR}/tv"
        "${DOWNLOADS_DIR}/incomplete"
    )

    for dir in "${dirs[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            run_cmd mkdir -p "${dir}"
            run_cmd chown "${TARGET_USER}:${TARGET_USER}" "${dir}"
            run_cmd chmod 755 "${dir}"
            log_success "Created: ${dir}"
        else
            log_info "Exists: ${dir}"
        fi
    done

    # Create stack directory
    log_info "Creating stack directory..."
    run_cmd mkdir -p "${STACK_DIR}"
    run_cmd mkdir -p "${STACK_DIR}/radarr/config"
    run_cmd mkdir -p "${STACK_DIR}/sonarr/config"
    run_cmd mkdir -p "${STACK_DIR}/prowlarr/config"

    # Set ownership
    run_cmd chown -R "${TARGET_USER}:${TARGET_USER}" "${STACK_DIR}"

    log_success "Directory structure created successfully"
}

#==============================================================================
# Docker Compose File Generation
#==============================================================================

create_docker_compose() {
    log_section "Generating Docker Compose Configuration"

    local compose_file="${STACK_DIR}/docker-compose.yml"

    log_info "Creating docker-compose.yml..."

    # Generate Traefik labels based on scenario
    local prowlarr_labels=""
    local radarr_labels=""
    local sonarr_labels=""

    if [[ "${TRAEFIK_ENABLE}" == "true" ]]; then
        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                # Path-based routing for DuckDNS
                prowlarr_labels=$(cat << 'EOF'
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=PathPrefix(\`/prowlarr\`)"
      - "traefik.http.routers.prowlarr.entrypoints=websecure"
      - "traefik.http.routers.prowlarr.tls.certresolver=letsencrypt"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
      - "traefik.http.middlewares.prowlarr-stripprefix.stripprefix.prefixes=/prowlarr"
      - "traefik.http.routers.prowlarr.middlewares=prowlarr-stripprefix"
EOF
)
                radarr_labels=$(cat << 'EOF'
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=PathPrefix(\`/radarr\`)"
      - "traefik.http.routers.radarr.entrypoints=websecure"
      - "traefik.http.routers.radarr.tls.certresolver=letsencrypt"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
      - "traefik.http.middlewares.radarr-stripprefix.stripprefix.prefixes=/radarr"
      - "traefik.http.routers.radarr.middlewares=radarr-stripprefix"
EOF
)
                sonarr_labels=$(cat << 'EOF'
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=PathPrefix(\`/sonarr\`)"
      - "traefik.http.routers.sonarr.entrypoints=websecure"
      - "traefik.http.routers.sonarr.tls.certresolver=letsencrypt"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
      - "traefik.http.middlewares.sonarr-stripprefix.stripprefix.prefixes=/sonarr"
      - "traefik.http.routers.sonarr.middlewares=sonarr-stripprefix"
EOF
)
                ;;

            cloudflare)
                # Subdomain routing for Cloudflare
                prowlarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=Host(\\\`${PROWLARR_DOMAIN}\\\`)"
      - "traefik.http.routers.prowlarr.entrypoints=websecure"
      - "traefik.http.routers.prowlarr.tls.certresolver=cloudflare"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
EOF
)
                radarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(\\\`${RADARR_DOMAIN}\\\`)"
      - "traefik.http.routers.radarr.entrypoints=websecure"
      - "traefik.http.routers.radarr.tls.certresolver=cloudflare"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
EOF
)
                sonarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(\\\`${SONARR_DOMAIN}\\\`)"
      - "traefik.http.routers.sonarr.entrypoints=websecure"
      - "traefik.http.routers.sonarr.tls.certresolver=cloudflare"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
EOF
)
                ;;

            vpn)
                # Local subdomain routing for VPN
                prowlarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.prowlarr.rule=Host(\\\`prowlarr.${TRAEFIK_DOMAIN}\\\`)"
      - "traefik.http.routers.prowlarr.entrypoints=web"
      - "traefik.http.services.prowlarr.loadbalancer.server.port=9696"
EOF
)
                radarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.radarr.rule=Host(\\\`radarr.${TRAEFIK_DOMAIN}\\\`)"
      - "traefik.http.routers.radarr.entrypoints=web"
      - "traefik.http.services.radarr.loadbalancer.server.port=7878"
EOF
)
                sonarr_labels=$(cat << EOF
      - "traefik.enable=true"
      - "traefik.http.routers.sonarr.rule=Host(\\\`sonarr.${TRAEFIK_DOMAIN}\\\`)"
      - "traefik.http.routers.sonarr.entrypoints=web"
      - "traefik.http.services.sonarr.loadbalancer.server.port=8989"
EOF
)
                ;;
        esac
    fi

    # Build networks section
    local networks_section=""
    if [[ "${TRAEFIK_ENABLE}" == "true" ]]; then
        networks_section=$(cat << EOF

networks:
  traefik-public:
    external: true
EOF
)
    fi

    # Build service network configuration
    local service_networks=""
    if [[ "${TRAEFIK_ENABLE}" == "true" ]]; then
        service_networks=$(cat << 'EOF'
    networks:
      - traefik-public
EOF
)
    fi

    # Generate docker-compose.yml
    cat > "${compose_file}" << EOF
#==============================================================================
# *arr Stack Docker Compose Configuration
#==============================================================================
# Generated by: 02-arr-stack-deploy.sh
# Description: Radarr + Sonarr + Prowlarr stack for automated media management
#
# Services:
#   - Prowlarr: Centralized indexer manager
#   - Radarr: Movie management and automation
#   - Sonarr: TV show management and automation
#
# Traefik Integration: ${TRAEFIK_ENABLE}
# Scenario: ${TRAEFIK_SCENARIO}
#==============================================================================

version: '3.8'

services:

  #============================================================================
  # Prowlarr - Indexer Manager
  #============================================================================
  prowlarr:
    image: linuxserver/prowlarr:\${PROWLARR_VERSION:-latest}
    container_name: prowlarr
    restart: unless-stopped
    environment:
      - PUID=\${PUID:-1000}
      - PGID=\${PGID:-1000}
      - TZ=\${TZ:-Europe/Paris}
    volumes:
      - ./prowlarr/config:/config
    ports:
      - "\${PROWLARR_PORT:-9696}:9696"
${service_networks}
EOF

    # Add Prowlarr labels if Traefik enabled
    if [[ -n "${prowlarr_labels}" ]]; then
        cat >> "${compose_file}" << EOF
    labels:
${prowlarr_labels}
EOF
    fi

    # Add Radarr service
    cat >> "${compose_file}" << EOF

  #============================================================================
  # Radarr - Movie Management
  #============================================================================
  radarr:
    image: linuxserver/radarr:\${RADARR_VERSION:-latest}
    container_name: radarr
    restart: unless-stopped
    environment:
      - PUID=\${PUID:-1000}
      - PGID=\${PGID:-1000}
      - TZ=\${TZ:-Europe/Paris}
    volumes:
      - ./radarr/config:/config
      - \${MOVIES_DIR}:/movies
      - \${DOWNLOADS_DIR}:/downloads
    ports:
      - "\${RADARR_PORT:-7878}:7878"
${service_networks}
EOF

    # Add Radarr labels if Traefik enabled
    if [[ -n "${radarr_labels}" ]]; then
        cat >> "${compose_file}" << EOF
    labels:
${radarr_labels}
EOF
    fi

    # Add Sonarr service
    cat >> "${compose_file}" << EOF

  #============================================================================
  # Sonarr - TV Show Management
  #============================================================================
  sonarr:
    image: linuxserver/sonarr:\${SONARR_VERSION:-latest}
    container_name: sonarr
    restart: unless-stopped
    environment:
      - PUID=\${PUID:-1000}
      - PGID=\${PGID:-1000}
      - TZ=\${TZ:-Europe/Paris}
    volumes:
      - ./sonarr/config:/config
      - \${TV_SHOWS_DIR}:/tv
      - \${DOWNLOADS_DIR}:/downloads
    ports:
      - "\${SONARR_PORT:-8989}:8989"
${service_networks}
EOF

    # Add Sonarr labels if Traefik enabled
    if [[ -n "${sonarr_labels}" ]]; then
        cat >> "${compose_file}" << EOF
    labels:
${sonarr_labels}
EOF
    fi

    # Add networks section if Traefik enabled
    if [[ -n "${networks_section}" ]]; then
        cat >> "${compose_file}" << EOF
${networks_section}
EOF
    fi

    log_success "Docker Compose configuration created: ${compose_file}"
}

#==============================================================================
# Environment File Generation
#==============================================================================

create_env_file() {
    log_section "Generating Environment Configuration"

    local env_file="${STACK_DIR}/.env"

    log_info "Creating .env file..."

    cat > "${env_file}" << EOF
#==============================================================================
# *arr Stack Environment Configuration
#==============================================================================
# Generated by: 02-arr-stack-deploy.sh
# Date: $(date '+%Y-%m-%d %H:%M:%S')
#==============================================================================

#------------------------------------------------------------------------------
# Docker Image Versions
#------------------------------------------------------------------------------
RADARR_VERSION=${RADARR_VERSION}
SONARR_VERSION=${SONARR_VERSION}
PROWLARR_VERSION=${PROWLARR_VERSION}

#------------------------------------------------------------------------------
# Service Ports
#------------------------------------------------------------------------------
RADARR_PORT=${RADARR_PORT}
SONARR_PORT=${SONARR_PORT}
PROWLARR_PORT=${PROWLARR_PORT}

#------------------------------------------------------------------------------
# User Configuration
#------------------------------------------------------------------------------
PUID=${TARGET_UID}
PGID=${TARGET_GID}

#------------------------------------------------------------------------------
# Timezone
#------------------------------------------------------------------------------
TZ=${TZ}

#------------------------------------------------------------------------------
# Media Paths
#------------------------------------------------------------------------------
MEDIA_DIR=${MEDIA_DIR}
MOVIES_DIR=${MOVIES_DIR}
TV_SHOWS_DIR=${TV_SHOWS_DIR}
DOWNLOADS_DIR=${DOWNLOADS_DIR}

#------------------------------------------------------------------------------
# Traefik Integration
#------------------------------------------------------------------------------
TRAEFIK_ENABLE=${TRAEFIK_ENABLE}
TRAEFIK_SCENARIO=${TRAEFIK_SCENARIO}
EOF

    # Add domain configuration for Cloudflare scenario
    if [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
        cat >> "${env_file}" << EOF
RADARR_DOMAIN=${RADARR_DOMAIN}
SONARR_DOMAIN=${SONARR_DOMAIN}
PROWLARR_DOMAIN=${PROWLARR_DOMAIN}
EOF
    fi

    # Set secure permissions
    run_cmd chmod 600 "${env_file}"
    run_cmd chown "${TARGET_USER}:${TARGET_USER}" "${env_file}"

    log_success "Environment configuration created: ${env_file}"
}

#==============================================================================
# Wait for Services to be Ready
#==============================================================================

wait_for_arr_services_ready() {
    log_section "Waiting for Services to Start"

    local max_wait=120
    local wait_interval=5
    local elapsed=0

    local services=("prowlarr:9696" "radarr:7878" "sonarr:8989")

    for service in "${services[@]}"; do
        local service_name="${service%%:*}"
        local service_port="${service##*:}"

        log_info "Waiting for ${service_name} to be ready..."

        elapsed=0
        while [[ ${elapsed} -lt ${max_wait} ]]; do
            if docker exec "${service_name}" curl -sf "http://localhost:${service_port}" >/dev/null 2>&1; then
                log_success "${service_name} is ready"
                break
            fi

            sleep ${wait_interval}
            elapsed=$((elapsed + wait_interval))

            if [[ ${elapsed} -ge ${max_wait} ]]; then
                log_warning "${service_name} not ready after ${max_wait}s (may still be initializing)"
            fi
        done
    done

    log_success "All services have been started"
}

#==============================================================================
# Homepage Widget Configuration
#==============================================================================

configure_homepage_widgets() {
    log_section "Configuring Homepage Integration"

    local homepage_dir="/home/pi/stacks/homepage"
    local services_file="${homepage_dir}/config/services.yaml"

    # Check if Homepage is installed
    if [[ ! -d "${homepage_dir}" ]]; then
        log_info "Homepage not detected, skipping widget configuration"
        return 0
    fi

    log_info "Homepage detected, configuring widgets..."

    # Check if services.yaml exists
    if [[ ! -f "${services_file}" ]]; then
        log_warning "Homepage services.yaml not found, skipping widget configuration"
        return 0
    fi

    # Backup services.yaml
    run_cmd cp "${services_file}" "${services_file}.backup-$(date +%Y%m%d-%H%M%S)"

    # Check if *arr stack section already exists
    if grep -q "name: Media Management" "${services_file}" 2>/dev/null; then
        log_info "*arr stack widgets already configured, skipping"
        return 0
    fi

    # Determine API endpoint format based on Traefik scenario
    local prowlarr_api_url
    local radarr_api_url
    local sonarr_api_url

    if [[ "${TRAEFIK_ENABLE}" == "true" ]]; then
        prowlarr_api_url="${PROWLARR_URL}"
        radarr_api_url="${RADARR_URL}"
        sonarr_api_url="${SONARR_URL}"
    else
        prowlarr_api_url="http://prowlarr:9696"
        radarr_api_url="http://radarr:7878"
        sonarr_api_url="http://sonarr:8989"
    fi

    # Add *arr stack widgets to services.yaml
    cat >> "${services_file}" << EOF

#==============================================================================
# Media Management (*arr Stack)
#==============================================================================
- Media Management:
    - Prowlarr:
        icon: prowlarr.png
        href: ${PROWLARR_URL}
        description: Indexer Manager
        widget:
          type: prowlarr
          url: ${prowlarr_api_url}
          key: {{HOMEPAGE_VAR_PROWLARR_API_KEY}}

    - Radarr:
        icon: radarr.png
        href: ${RADARR_URL}
        description: Movie Management
        widget:
          type: radarr
          url: ${radarr_api_url}
          key: {{HOMEPAGE_VAR_RADARR_API_KEY}}

    - Sonarr:
        icon: sonarr.png
        href: ${SONARR_URL}
        description: TV Show Management
        widget:
          type: sonarr
          url: ${sonarr_api_url}
          key: {{HOMEPAGE_VAR_SONARR_API_KEY}}
EOF

    log_success "Homepage widgets configured"
    log_info "Note: API keys must be configured manually in Homepage .env file"
    log_info "      after first launch of each service"
}

#==============================================================================
# Jellyfin Integration Instructions
#==============================================================================

integrate_with_jellyfin() {
    local jellyfin_dir="/home/pi/stacks/jellyfin"

    if [[ ! -d "${jellyfin_dir}" ]]; then
        return 0
    fi

    log_info "Jellyfin detected at ${jellyfin_dir}"
    log_info "Media directories are configured to match Jellyfin paths:"
    log_info "  Movies: ${MOVIES_DIR}"
    log_info "  TV Shows: ${TV_SHOWS_DIR}"
}

#==============================================================================
# Prowlarr Integration Setup Instructions
#==============================================================================

setup_prowlarr_integration() {
    log_info "Prowlarr will sync indexers to Radarr and Sonarr automatically"
    log_info "Configuration steps will be shown in the deployment summary"
}

#==============================================================================
# Check Prerequisites
#==============================================================================

check_prerequisites() {
    log_section "Checking Prerequisites"

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        log_info "Please install Docker first using the Docker deployment script"
        exit 1
    fi

    # Check if Docker Compose is available
    if ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not available"
        log_info "Please install Docker Compose plugin"
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        log_info "Please start Docker: sudo systemctl start docker"
        exit 1
    fi

    log_success "All prerequisites met"
}

#==============================================================================
# Check Port Availability
#==============================================================================

check_port_availability() {
    log_section "Checking Port Availability"

    local ports=(
        "${RADARR_PORT}:Radarr"
        "${SONARR_PORT}:Sonarr"
        "${PROWLARR_PORT}:Prowlarr"
    )

    local port_conflicts=0

    for port_info in "${ports[@]}"; do
        local port="${port_info%%:*}"
        local service="${port_info##*:}"

        if netstat -tuln 2>/dev/null | grep -q ":${port} " || \
           ss -tuln 2>/dev/null | grep -q ":${port} "; then
            log_warning "Port ${port} (${service}) is already in use"
            port_conflicts=$((port_conflicts + 1))
        else
            log_success "Port ${port} (${service}) is available"
        fi
    done

    if [[ ${port_conflicts} -gt 0 ]]; then
        log_warning "${port_conflicts} port(s) in use - services may fail to start"
        log_info "You can change ports using environment variables (RADARR_PORT, etc.)"
    fi
}

#==============================================================================
# Verify Traefik Network
#==============================================================================

verify_traefik_network() {
    if [[ "${TRAEFIK_ENABLE}" != "true" ]]; then
        return 0
    fi

    log_info "Verifying Traefik network..."

    if ! docker network inspect "${TRAEFIK_NETWORK}" &> /dev/null; then
        log_warning "Traefik network '${TRAEFIK_NETWORK}' not found, creating..."
        run_cmd docker network create "${TRAEFIK_NETWORK}"
        log_success "Traefik network created"
    else
        log_success "Traefik network exists"
    fi
}

#==============================================================================
# Deploy Stack
#==============================================================================

deploy_stack() {
    log_section "Deploying *arr Stack"

    log_info "Starting services with Docker Compose..."

    cd "${STACK_DIR}" || exit 1

    # Pull latest images
    log_info "Pulling Docker images..."
    run_cmd docker compose pull

    # Start services
    log_info "Starting containers..."
    run_cmd docker compose up -d

    # Wait for services to be healthy
    wait_for_arr_services_ready

    log_success "*arr Stack deployed successfully"
}

#==============================================================================
# Deployment Summary
#==============================================================================

display_deployment_summary() {
    log_section "Deployment Summary"

    cat << EOF

${COLOR_GREEN}${SYMBOL_SUCCESS} *arr Stack deployed successfully!${COLOR_RESET}

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}DEPLOYED SERVICES${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  ${COLOR_YELLOW}Prowlarr (Indexer Manager)${COLOR_RESET}
    URL: ${COLOR_CYAN}${PROWLARR_URL}${COLOR_RESET}
    Port: ${PROWLARR_PORT}

  ${COLOR_YELLOW}Radarr (Movie Management)${COLOR_RESET}
    URL: ${COLOR_CYAN}${RADARR_URL}${COLOR_RESET}
    Port: ${RADARR_PORT}

  ${COLOR_YELLOW}Sonarr (TV Show Management)${COLOR_RESET}
    URL: ${COLOR_CYAN}${SONARR_URL}${COLOR_RESET}
    Port: ${SONARR_PORT}

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}DIRECTORY STRUCTURE${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  Movies:        ${COLOR_CYAN}${MOVIES_DIR}${COLOR_RESET}
  TV Shows:      ${COLOR_CYAN}${TV_SHOWS_DIR}${COLOR_RESET}
  Downloads:     ${COLOR_CYAN}${DOWNLOADS_DIR}${COLOR_RESET}
  Configuration: ${COLOR_CYAN}${STACK_DIR}${COLOR_RESET}

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}CONFIGURATION STEPS (Follow in Order)${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

${COLOR_BOLD}${COLOR_YELLOW}1. Configure Prowlarr (Indexer Manager)${COLOR_RESET}

   a. Open Prowlarr:
      ${COLOR_CYAN}${PROWLARR_URL}${COLOR_RESET}

   b. Complete initial setup wizard

   c. Go to: Settings → General
      - Copy the ${COLOR_YELLOW}API Key${COLOR_RESET} (you will need this)

   d. Add Indexers: Indexers → Add Indexer
      ${COLOR_GREEN}Recommended Public Indexers:${COLOR_RESET}
      - YTS (movies - high quality)
      - 1337x (movies + TV shows)
      - The Pirate Bay (backup)
      - EZTV (TV shows)
      - RARBG (if available)

      ${COLOR_YELLOW}Note:${COLOR_RESET} Configure any private trackers you have access to

   e. Connect Applications: Settings → Apps → Add Application

      ${COLOR_CYAN}Add Radarr:${COLOR_RESET}
      - Name: Radarr
      - Sync Level: Full Sync
      - Prowlarr Server: http://prowlarr:9696
      - Radarr Server: http://radarr:7878
      - API Key: [Get from Radarr in step 2]
      - Click Test, then Save

      ${COLOR_CYAN}Add Sonarr:${COLOR_RESET}
      - Name: Sonarr
      - Sync Level: Full Sync
      - Prowlarr Server: http://prowlarr:9696
      - Sonarr Server: http://sonarr:8989
      - API Key: [Get from Sonarr in step 3]
      - Click Test, then Save

${COLOR_BOLD}${COLOR_YELLOW}2. Configure Radarr (Movie Management)${COLOR_RESET}

   a. Open Radarr:
      ${COLOR_CYAN}${RADARR_URL}${COLOR_RESET}

   b. Complete initial setup wizard

   c. Settings → Media Management:
      - ${COLOR_GREEN}Add Root Folder${COLOR_RESET}: /movies
      - Enable: Rename Movies
      - Enable: Replace Illegal Characters
      - Standard Movie Format:
        {Movie Title} ({Release Year})

   d. Settings → Download Clients:
      ${COLOR_YELLOW}Add your torrent client${COLOR_RESET} (e.g., qBittorrent, Transmission)
      - Category: radarr
      - Directory: /downloads/movies

   e. Settings → General:
      - Copy the ${COLOR_YELLOW}API Key${COLOR_RESET}
      - Go back to Prowlarr and add this API key in Apps

   f. Settings → Profiles:
      - Create quality profiles (e.g., HD-1080p, 4K)

${COLOR_BOLD}${COLOR_YELLOW}3. Configure Sonarr (TV Show Management)${COLOR_RESET}

   a. Open Sonarr:
      ${COLOR_CYAN}${SONARR_URL}${COLOR_RESET}

   b. Complete initial setup wizard

   c. Settings → Media Management:
      - ${COLOR_GREEN}Add Root Folder${COLOR_RESET}: /tv
      - Enable: Rename Episodes
      - Enable: Replace Illegal Characters
      - Standard Episode Format:
        {Series Title} - S{season:00}E{episode:00} - {Episode Title}

   d. Settings → Download Clients:
      ${COLOR_YELLOW}Add your torrent client${COLOR_RESET} (same as Radarr)
      - Category: sonarr
      - Directory: /downloads/tv

   e. Settings → General:
      - Copy the ${COLOR_YELLOW}API Key${COLOR_RESET}
      - Go back to Prowlarr and add this API key in Apps

   f. Settings → Profiles:
      - Create quality profiles (e.g., HD-1080p)
      - Configure Language Profiles if needed

${COLOR_BOLD}${COLOR_YELLOW}4. Sync Indexers from Prowlarr${COLOR_RESET}

   a. Return to Prowlarr → Settings → Apps

   b. Click ${COLOR_GREEN}Sync App Indexers${COLOR_RESET} for each application

   c. Verify in Radarr and Sonarr:
      - Settings → Indexers
      - Should see all indexers from Prowlarr

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}WORKFLOW EXPLANATION${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

${COLOR_YELLOW}How the *arr Stack Works:${COLOR_RESET}

1. ${COLOR_GREEN}Add Content${COLOR_RESET}
   Radarr: Search for movie → Add to library
   Sonarr: Search for TV show → Add to library

2. ${COLOR_GREEN}Search & Download${COLOR_RESET}
   Service searches indexers (via Prowlarr)
   ↓
   Finds best torrent based on quality profile
   ↓
   Sends to download client (qBittorrent/Transmission)

3. ${COLOR_GREEN}Monitor Download${COLOR_RESET}
   Service monitors download progress
   ↓
   Waits for completion

4. ${COLOR_GREEN}Import & Organize${COLOR_RESET}
   Radarr: /downloads/movies → /movies/Movie Name (Year)/
   Sonarr: /downloads/tv → /tv/Show Name/Season 01/

5. ${COLOR_GREEN}Rename & Clean${COLOR_RESET}
   Renames file to standard format
   ↓
   Removes from download client
   ↓
   Deletes original torrent files

6. ${COLOR_GREEN}Update Media Server${COLOR_RESET}
EOF

    if [[ -d "/home/pi/stacks/jellyfin" ]]; then
        cat << EOF
   ${COLOR_GREEN}Jellyfin automatically scans new files${COLOR_RESET}
   ↓
   Movie/Show appears in your library
   ↓
   Ready to watch!
EOF
    else
        cat << EOF
   ${COLOR_YELLOW}Install Jellyfin to complete the media stack${COLOR_RESET}
   ↓
   Point Jellyfin libraries to:
   - Movies: ${MOVIES_DIR}
   - TV Shows: ${TV_SHOWS_DIR}
EOF
    fi

    cat << EOF

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}JELLYFIN INTEGRATION${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

EOF

    if [[ -d "/home/pi/stacks/jellyfin" ]]; then
        cat << EOF
  ${COLOR_GREEN}${SYMBOL_SUCCESS} Jellyfin Detected${COLOR_RESET}

  Media directories are configured to match Jellyfin:
  - Movies:   ${COLOR_CYAN}${MOVIES_DIR}${COLOR_RESET}
  - TV Shows: ${COLOR_CYAN}${TV_SHOWS_DIR}${COLOR_RESET}

  ${COLOR_YELLOW}Setup:${COLOR_RESET}
  1. Radarr/Sonarr will automatically move completed downloads
  2. Files appear in Jellyfin libraries
  3. Jellyfin scans and adds to your collection
  4. Start watching!

  ${COLOR_GREEN}Tip:${COLOR_RESET} Enable "Run a library scan" in Jellyfin settings
        for automatic detection of new media

EOF
    else
        cat << EOF
  ${COLOR_YELLOW}${SYMBOL_INFO} Jellyfin Not Detected${COLOR_RESET}

  To complete your media stack:
  1. Install Jellyfin: ./scripts/01-jellyfin-deploy.sh
  2. Configure libraries pointing to:
     - Movies:   ${COLOR_CYAN}${MOVIES_DIR}${COLOR_RESET}
     - TV Shows: ${COLOR_CYAN}${TV_SHOWS_DIR}${COLOR_RESET}

EOF
    fi

    cat << EOF
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}USAGE EXAMPLES${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

${COLOR_YELLOW}Adding a Movie (Radarr):${COLOR_RESET}
  1. Open ${COLOR_CYAN}${RADARR_URL}${COLOR_RESET}
  2. Click "Add New" → Search for movie
  3. Select movie → Choose quality profile
  4. Click "Add Movie"
  5. Radarr automatically searches and downloads
  6. Movie appears in Jellyfin when complete

${COLOR_YELLOW}Adding a TV Show (Sonarr):${COLOR_RESET}
  1. Open ${COLOR_CYAN}${SONARR_URL}${COLOR_RESET}
  2. Click "Add New" → Search for show
  3. Select show → Choose quality profile
  4. Monitor: All Episodes / Future Episodes
  5. Click "Add Series"
  6. Sonarr downloads all monitored episodes
  7. New episodes download automatically on release

${COLOR_YELLOW}Managing Indexers (Prowlarr):${COLOR_RESET}
  1. Open ${COLOR_CYAN}${PROWLARR_URL}${COLOR_RESET}
  2. Add/remove indexers in one place
  3. Click "Sync" to update Radarr/Sonarr
  4. Test indexer health regularly

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}MANAGEMENT COMMANDS${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  View logs:
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml logs -f${COLOR_RESET}

  Restart services:
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml restart${COLOR_RESET}

  Stop services:
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml stop${COLOR_RESET}

  Start services:
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml start${COLOR_RESET}

  Update services:
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml pull${COLOR_RESET}
    ${COLOR_CYAN}docker compose -f ${STACK_DIR}/docker-compose.yml up -d${COLOR_RESET}

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}RECOMMENDED NEXT STEPS${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  ${COLOR_YELLOW}1.${COLOR_RESET} Configure Prowlarr indexers (see step 1 above)
  ${COLOR_YELLOW}2.${COLOR_RESET} Set up Radarr and Sonarr (see steps 2-3 above)
  ${COLOR_YELLOW}3.${COLOR_RESET} Install a download client:
      - qBittorrent (recommended): ./scripts/03-qbittorrent-deploy.sh
      - Transmission: ./scripts/03-transmission-deploy.sh
  ${COLOR_YELLOW}4.${COLOR_RESET} Connect download client to Radarr/Sonarr
  ${COLOR_YELLOW}5.${COLOR_RESET} Sync indexers from Prowlarr (see step 4 above)
  ${COLOR_YELLOW}6.${COLOR_RESET} Start adding movies and TV shows!

EOF

    if [[ -d "/home/pi/stacks/homepage" ]]; then
        cat << EOF
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}HOMEPAGE INTEGRATION${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  ${COLOR_GREEN}${SYMBOL_SUCCESS} Homepage widgets configured${COLOR_RESET}

  To enable API integration:
  1. Get API keys from each service (Settings → General)
  2. Add to ${COLOR_CYAN}/home/pi/stacks/homepage/.env${COLOR_RESET}:
     HOMEPAGE_VAR_PROWLARR_API_KEY=your_prowlarr_key
     HOMEPAGE_VAR_RADARR_API_KEY=your_radarr_key
     HOMEPAGE_VAR_SONARR_API_KEY=your_sonarr_key
  3. Restart Homepage to see live stats

EOF
    fi

    cat << EOF
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}
${COLOR_BOLD}TROUBLESHOOTING${COLOR_RESET}
${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

  ${COLOR_YELLOW}Services not accessible?${COLOR_RESET}
    - Check containers: docker ps
    - View logs: docker logs prowlarr (or radarr/sonarr)
    - Verify ports: netstat -tuln | grep -E '7878|8989|9696'

  ${COLOR_YELLOW}Indexers not syncing?${COLOR_RESET}
    - Verify Prowlarr → Apps configuration
    - Check API keys are correct
    - Ensure services can communicate (same Docker network)

  ${COLOR_YELLOW}Downloads not importing?${COLOR_RESET}
    - Check download client connection
    - Verify paths match in all services
    - Ensure proper permissions (${TARGET_USER}:${TARGET_USER})

  ${COLOR_YELLOW}Permissions issues?${COLOR_RESET}
    - Check directory ownership: ls -la ${MEDIA_DIR}
    - Fix permissions: sudo chown -R ${TARGET_USER}:${TARGET_USER} ${MEDIA_DIR}

${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}

${COLOR_GREEN}${SYMBOL_SUCCESS} Deployment complete! Happy media managing!${COLOR_RESET}

EOF
}

#==============================================================================
# Main Execution
#==============================================================================

main() {
    # Parse command line arguments
    parse_common_args "$@"

    # Check if running as root
    require_root

    # Display header
    log_section "*arr Stack Deployment for Raspberry Pi 5"
    log_info "Deploying Radarr + Sonarr + Prowlarr"
    log_info "Script: $(basename "$0")"
    log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Detect Traefik scenario
    detect_traefik_scenario

    # Check port availability
    check_port_availability

    # Setup directories
    setup_directories

    # Create stack directory
    log_info "Creating stack directory: ${STACK_DIR}"
    run_cmd mkdir -p "${STACK_DIR}"

    # Generate Docker Compose configuration
    create_docker_compose

    # Generate environment file
    create_env_file

    # Verify Traefik network if enabled
    verify_traefik_network

    # Deploy stack
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "[DRY RUN] Would deploy stack with: docker compose up -d"
    else
        deploy_stack
    fi

    # Configure Homepage widgets
    configure_homepage_widgets

    # Display integration information
    integrate_with_jellyfin
    setup_prowlarr_integration

    # Display deployment summary
    display_deployment_summary

    log_success "Deployment complete!"
}

#==============================================================================
# Script Entry Point
#==============================================================================

# Handle --help flag
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    usage
fi

# Execute main function
main "$@"
