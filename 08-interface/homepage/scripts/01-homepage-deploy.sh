#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Homepage Dashboard Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Homepage dashboard as central portal with auto-detection
# Architecture: ARM64 (Raspberry Pi 5)
# Service: Homepage (https://gethomepage.dev/)
# Auto-Detection: Traefik scenario (DuckDNS, Cloudflare, VPN)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 3-5 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[HOMEPAGE]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]   \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.2"
LOG_FILE="/var/log/homepage-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
HOMEPAGE_DIR="/home/${TARGET_USER}/stacks/homepage"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
MONITORING_DIR="/home/${TARGET_USER}/stacks/monitoring"
CONFIG_DIR="${HOMEPAGE_DIR}/config"
COMPOSE_FILE="${HOMEPAGE_DIR}/docker-compose.yml"

# Traefik scenario detection
TRAEFIK_SCENARIO=""
DOMAIN=""
HOMEPAGE_URL=""
HOMEPAGE_SUBDOMAIN=""
USE_SUBDOMAIN=false

# Service detection
HAS_SUPABASE=false
HAS_TRAEFIK=false
HAS_PORTAINER=false
HAS_GRAFANA=false
PORTAINER_URL=""
PI_IP=""

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

    local dependencies=("docker" "curl" "ip")
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
        error_exit "Traefik container is not running. Please deploy Traefik first using one of the 01-traefik-deploy-*.sh scripts"
    fi

    if [[ ! -d "$TRAEFIK_DIR" ]]; then
        error_exit "Traefik directory not found at $TRAEFIK_DIR"
    fi

    if [[ ! -f "$TRAEFIK_DIR/.env" ]]; then
        error_exit "Traefik .env file not found. Cannot detect deployment scenario."
    fi

    HAS_TRAEFIK=true
    ok "Traefik is installed and running"
}

check_traefik_network() {
    log "Checking for Traefik network..."

    if ! docker network ls --format '{{.Name}}' | grep -q '^traefik_network$'; then
        error_exit "Traefik network 'traefik_network' not found. Please ensure Traefik is properly deployed."
    fi

    ok "Traefik network exists"
}

check_existing_homepage() {
    log "Checking for existing Homepage installation..."

    if docker ps -a --format '{{.Names}}' | grep -q '^homepage$'; then
        warn "Existing Homepage container found"
        read -p "Do you want to remove it and continue? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping and removing existing Homepage container..."
            docker stop homepage 2>/dev/null || true
            docker rm homepage 2>/dev/null || true
            ok "Existing container removed"
        else
            error_exit "Installation cancelled by user"
        fi
    fi
}

detect_traefik_scenario() {
    log "Detecting Traefik deployment scenario..."

    # Read Traefik .env file to determine scenario
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

detect_installed_services() {
    log "Detecting installed services..."

    # Check for Supabase
    if [[ -d "$SUPABASE_DIR" ]] && docker ps --format '{{.Names}}' | grep -q 'supabase'; then
        HAS_SUPABASE=true
        ok "  Supabase installation detected"
    else
        log "  Supabase not found (optional)"
    fi

    # Check for Portainer
    if docker ps --format '{{.Names}}' | grep -q 'portainer'; then
        HAS_PORTAINER=true
        PORTAINER_URL="http://${PI_IP}:9000"
        ok "  Portainer installation detected"
    else
        log "  Portainer not found (optional)"
    fi

    # Check for Grafana/Monitoring
    if [[ -d "$MONITORING_DIR" ]] && docker ps --format '{{.Names}}' | grep -q 'grafana'; then
        HAS_GRAFANA=true
        ok "  Grafana installation detected"
    else
        log "  Grafana not found (optional)"
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
        warn "Low RAM detected: ${ram_gb}GB (minimum 2GB recommended)"
    else
        ok "RAM: ${ram_gb}GB"
    fi

    # Check disk space
    local disk_gb=$(df "$HOMEPAGE_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt 2 ]]; then
        warn "Low disk space: ${disk_gb}GB available (minimum 2GB recommended)"
    else
        ok "Disk space: ${disk_gb}GB available"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting Homepage configuration..."
    echo ""
    echo "=========================================="
    echo "Homepage Dashboard Configuration"
    echo "=========================================="
    echo ""
    echo "Detected Scenario: $TRAEFIK_SCENARIO"
    echo "Base Domain: $DOMAIN"
    echo ""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing - use /home path
            log "Using path-based routing:"
            echo "  Homepage will be accessible at: https://${DOMAIN}/home"
            echo ""
            HOMEPAGE_URL="https://${DOMAIN}/home"
            ;;

        cloudflare)
            # Subdomain-based routing
            echo "Do you want to use a subdomain or root domain for Homepage?"
            echo ""
            read -p "Use subdomain (e.g., home.$DOMAIN)? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                USE_SUBDOMAIN=true
                read -p "Enter subdomain for Homepage (default: home): " HOMEPAGE_SUBDOMAIN
                if [[ -z "$HOMEPAGE_SUBDOMAIN" ]]; then
                    HOMEPAGE_SUBDOMAIN="home"
                    log "Using default: home"
                fi
                HOMEPAGE_URL="https://${HOMEPAGE_SUBDOMAIN}.${DOMAIN}"
            else
                HOMEPAGE_URL="https://${DOMAIN}"
            fi

            echo ""
            log "Homepage will be accessible at: $HOMEPAGE_URL"
            ;;

        vpn)
            # Local .pi.local domain
            echo "Enter local domain for Homepage:"
            echo "(Use .pi.local suffix for VPN scenario)"
            echo ""
            read -p "Enter domain for Homepage (default: home.pi.local): " HOMEPAGE_SUBDOMAIN
            if [[ -z "$HOMEPAGE_SUBDOMAIN" ]]; then
                HOMEPAGE_SUBDOMAIN="home.pi.local"
                log "Using default: home.pi.local"
            fi
            HOMEPAGE_URL="https://${HOMEPAGE_SUBDOMAIN}"

            echo ""
            log "Homepage will be accessible at: $HOMEPAGE_URL"
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Scenario: $TRAEFIK_SCENARIO"
    echo "Homepage URL: $HOMEPAGE_URL"
    echo "Detected Services:"
    [[ "$HAS_SUPABASE" == true ]] && echo "  - Supabase (Studio, API)"
    [[ "$HAS_TRAEFIK" == true ]] && echo "  - Traefik Dashboard"
    [[ "$HAS_PORTAINER" == true ]] && echo "  - Portainer ($PORTAINER_URL)"
    [[ "$HAS_GRAFANA" == true ]] && echo "  - Grafana"
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

    log "=== Homepage Dashboard Deployment - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_directory_structure() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "$HOMEPAGE_DIR"
    mkdir -p "$CONFIG_DIR"

    # Create backup directory
    mkdir -p "${HOMEPAGE_DIR}/backups"

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$HOMEPAGE_DIR"

    ok "Directory structure created at $HOMEPAGE_DIR"
}

generate_services_yaml() {
    log "Generating services.yaml configuration..."

    local services_content="---
# Homepage Services Configuration
# Generated: $(date)
# Auto-detected services based on installation

"

    # Add Supabase section if detected
    if [[ "$HAS_SUPABASE" == true ]]; then
        case "$TRAEFIK_SCENARIO" in
            duckdns)
                services_content+="- Supabase:
    - Studio:
        href: https://${DOMAIN}/studio
        description: Database management interface
        icon: supabase
        widget:
          type: customapi
          url: https://${DOMAIN}/studio
          method: GET
    - API:
        href: https://${DOMAIN}/api
        description: REST API endpoint
        icon: supabase
        widget:
          type: customapi
          url: https://${DOMAIN}/api
          method: GET

"
                ;;
            cloudflare|vpn)
                local studio_domain="${HOMEPAGE_SUBDOMAIN:-studio}.${DOMAIN}"
                local api_domain="${HOMEPAGE_SUBDOMAIN:-api}.${DOMAIN}"
                services_content+="- Supabase:
    - Studio:
        href: https://${studio_domain}
        description: Database management interface
        icon: supabase
    - API:
        href: https://${api_domain}
        description: REST API endpoint
        icon: supabase

"
                ;;
        esac
    fi

    # Add Infrastructure section
    services_content+="- Infrastructure:
"

    # Add Traefik
    if [[ "$HAS_TRAEFIK" == true ]]; then
        case "$TRAEFIK_SCENARIO" in
            duckdns)
                services_content+="    - Traefik:
        href: https://${DOMAIN}/traefik
        description: Reverse proxy dashboard
        icon: traefik
        widget:
          type: traefik
          url: https://${DOMAIN}/traefik
"
                ;;
            cloudflare)
                services_content+="    - Traefik:
        href: https://traefik.${DOMAIN}
        description: Reverse proxy dashboard
        icon: traefik
        widget:
          type: traefik
          url: https://traefik.${DOMAIN}
"
                ;;
            vpn)
                services_content+="    - Traefik:
        href: https://traefik.pi.local
        description: Reverse proxy dashboard
        icon: traefik
        widget:
          type: traefik
          url: https://traefik.pi.local
"
                ;;
        esac
    fi

    # Add Portainer
    # Note: env value (endpoint ID) may need adjustment
    # Use create-portainer-token.sh to auto-detect correct endpoint ID
    if [[ "$HAS_PORTAINER" == true ]]; then
        services_content+="    - Portainer:
        href: ${PORTAINER_URL}
        description: Docker management interface
        icon: portainer
        widget:
          type: portainer
          url: ${PORTAINER_URL}
          env: 1  # Will be auto-corrected by create-portainer-token.sh
          key: {{HOMEPAGE_VAR_PORTAINER_KEY}}
"
    fi

    # Add Grafana
    if [[ "$HAS_GRAFANA" == true ]]; then
        case "$TRAEFIK_SCENARIO" in
            duckdns)
                services_content+="    - Grafana:
        href: https://${DOMAIN}/grafana
        description: Monitoring & metrics
        icon: grafana
        widget:
          type: grafana
          url: https://${DOMAIN}/grafana
          username: {{HOMEPAGE_VAR_GRAFANA_USER}}
          password: {{HOMEPAGE_VAR_GRAFANA_PASSWORD}}
"
                ;;
            cloudflare|vpn)
                local grafana_domain="${HOMEPAGE_SUBDOMAIN:-grafana}.${DOMAIN}"
                services_content+="    - Grafana:
        href: https://${grafana_domain}
        description: Monitoring & metrics
        icon: grafana
        widget:
          type: grafana
          url: https://${grafana_domain}
          username: {{HOMEPAGE_VAR_GRAFANA_USER}}
          password: {{HOMEPAGE_VAR_GRAFANA_PASSWORD}}
"
                ;;
        esac
    fi

    # Write services.yaml
    cat > "$CONFIG_DIR/services.yaml" << EOF
$services_content
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/services.yaml"
    ok "services.yaml generated"
}

generate_widgets_yaml() {
    log "Generating widgets.yaml configuration..."

    cat > "$CONFIG_DIR/widgets.yaml" << 'EOF'
---
# Homepage Widgets Configuration
# Generated: $(date)

- logo:
    icon: https://gethomepage.dev/img/banner_light.png

- search:
    provider: duckduckgo
    target: _blank

- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
      hourCycle: h23

- resources:
    cpu: true
    memory: true
    disk: /
    cputemp: true
    uptime: true
    units: metric
    refresh: 3000

- kubernetes:
    cluster:
      show: false
    nodes:
      show: false
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/widgets.yaml"
    ok "widgets.yaml generated"
}

generate_settings_yaml() {
    log "Generating settings.yaml configuration..."

    cat > "$CONFIG_DIR/settings.yaml" << 'EOF'
---
# Homepage Settings Configuration
# Generated: $(date)

title: Raspberry Pi Dashboard
favicon: https://gethomepage.dev/img/favicon.ico

theme: dark
color: slate

layout:
  Supabase:
    style: row
    columns: 2
  Infrastructure:
    style: row
    columns: 3

headerStyle: boxed

hideVersion: false

quicklaunch:
  searchDescription: true
  hideInternetSearch: true
  showSearchSuggestions: true

providers:
  openweathermap: openweathermapapikey
  weatherapi: weatherapiapikey

language: en

hideErrors: false

statusStyle: dot

showStats: true
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/settings.yaml"
    ok "settings.yaml generated"
}

generate_bookmarks_yaml() {
    log "Generating bookmarks.yaml configuration..."

    cat > "$CONFIG_DIR/bookmarks.yaml" << 'EOF'
---
# Homepage Bookmarks Configuration
# Generated: $(date)

- Documentation:
    - Homepage Docs:
        - href: https://gethomepage.dev/
          description: Official Homepage documentation
          icon: https://gethomepage.dev/img/favicon.ico
    - Supabase Docs:
        - href: https://supabase.com/docs
          description: Supabase documentation
          icon: supabase
    - Traefik Docs:
        - href: https://doc.traefik.io/traefik/
          description: Traefik documentation
          icon: traefik

- Development:
    - GitHub:
        - href: https://github.com
          description: GitHub repositories
          icon: github
    - Docker Hub:
        - href: https://hub.docker.com
          description: Docker images
          icon: docker

- Raspberry Pi:
    - Pi Forums:
        - href: https://forums.raspberrypi.com
          description: Raspberry Pi community
          icon: https://www.raspberrypi.org/app/uploads/2018/03/RPi-Logo-Reg-SCREEN.png
    - Pi Documentation:
        - href: https://www.raspberrypi.com/documentation/
          description: Official Raspberry Pi docs
          icon: https://www.raspberrypi.org/app/uploads/2018/03/RPi-Logo-Reg-SCREEN.png
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/bookmarks.yaml"
    ok "bookmarks.yaml generated"
}

generate_docker_compose() {
    log "Generating docker-compose.yml..."

    local traefik_labels=""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing - use /home path to avoid conflicts with Supabase /project and Kong /api
            traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.homepage.rule=Host(\`${DOMAIN}\`) && PathPrefix(\`/home\`)\"
      - \"traefik.http.routers.homepage.entrypoints=websecure\"
      - \"traefik.http.routers.homepage.tls.certresolver=letsencrypt\"
      - \"traefik.http.routers.homepage.middlewares=homepage-stripprefix\"
      - \"traefik.http.routers.homepage.priority=10\"
      - \"traefik.http.services.homepage.loadbalancer.server.port=3000\"
      - \"traefik.http.middlewares.homepage-stripprefix.stripprefix.prefixes=/home\"

      # Router for Next.js static assets (/_next, /api, /site.webmanifest, /icons)
      - \"traefik.http.routers.homepage-assets.rule=Host(\`${DOMAIN}\`) && (PathPrefix(\`/_next\`) || PathPrefix(\`/api/config\`) || PathPrefix(\`/site.webmanifest\`) || PathPrefix(\`/icons\"))\"
      - \"traefik.http.routers.homepage-assets.entrypoints=websecure\"
      - \"traefik.http.routers.homepage-assets.tls.certresolver=letsencrypt\"
      - \"traefik.http.routers.homepage-assets.service=homepage\"
      - \"traefik.http.routers.homepage-assets.priority=15\""
            ;;

        cloudflare)
            if [[ "$USE_SUBDOMAIN" == true ]]; then
                local full_domain="${HOMEPAGE_SUBDOMAIN}.${DOMAIN}"
                traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.homepage.rule=Host(\`${full_domain}\`)\"
      - \"traefik.http.routers.homepage.entrypoints=websecure\"
      - \"traefik.http.routers.homepage.tls.certresolver=cloudflare\"
      - \"traefik.http.services.homepage.loadbalancer.server.port=3000\""
            else
                traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.homepage.rule=Host(\`${DOMAIN}\`)\"
      - \"traefik.http.routers.homepage.entrypoints=websecure\"
      - \"traefik.http.routers.homepage.tls.certresolver=cloudflare\"
      - \"traefik.http.services.homepage.loadbalancer.server.port=3000\""
            fi
            ;;

        vpn)
            traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.homepage.rule=Host(\`${HOMEPAGE_SUBDOMAIN}\`)\"
      - \"traefik.http.routers.homepage.entrypoints=websecure\"
      - \"traefik.http.routers.homepage.tls=true\"
      - \"traefik.http.services.homepage.loadbalancer.server.port=3000\""
            ;;
    esac

    cat > "$COMPOSE_FILE" << EOF
# Homepage Dashboard Docker Compose Configuration
# Generated: $(date)
# Note: No port mapping to avoid conflict with Supabase Studio on port 3000
#       Homepage is accessible via Traefik HTTPS only

services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    restart: unless-stopped
    volumes:
      - ./config:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    networks:
      - traefik_network
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
    labels:
${traefik_labels}
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:3000/api/healthcheck"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 20s

networks:
  traefik_network:
    external: true
    name: traefik_network
EOF

    chown "$TARGET_USER:$TARGET_USER" "$COMPOSE_FILE"
    ok "docker-compose.yml generated"
}

create_backup() {
    if [[ -f "$CONFIG_DIR/services.yaml" ]] || [[ -f "$COMPOSE_FILE" ]]; then
        log "Creating backup of existing configuration..."

        local backup_dir="${HOMEPAGE_DIR}/backups"
        local backup_file="${backup_dir}/homepage-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

        mkdir -p "$backup_dir"

        tar -czf "$backup_file" -C "$HOMEPAGE_DIR" \
            $(ls "$CONFIG_DIR" 2>/dev/null | sed 's|^|config/|' || true) \
            $(basename "$COMPOSE_FILE" 2>/dev/null || true) 2>/dev/null || true

        if [[ -f "$backup_file" ]]; then
            chown "$TARGET_USER:$TARGET_USER" "$backup_file"
            ok "Backup created: $backup_file"
        fi
    fi
}

deploy_homepage() {
    log "Deploying Homepage dashboard..."

    # Change to homepage directory
    cd "$HOMEPAGE_DIR"

    # Pull image first
    log "Pulling Homepage Docker image..."
    sudo -u "$TARGET_USER" docker compose pull

    # Start the stack
    log "Starting Homepage stack..."
    sudo -u "$TARGET_USER" docker compose up -d

    # Wait for container to be healthy
    log "Waiting for container to start..."
    sleep 10

    ok "Homepage deployed successfully"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_deployment() {
    log "Verifying deployment..."

    local checks_passed=0
    local total_checks=5

    # Check Homepage container
    if docker ps | grep -q 'homepage'; then
        ok "  Homepage container is running"
        ((checks_passed++))
    else
        error "  Homepage container is not running"
    fi

    # Check Homepage health
    sleep 5
    if docker exec homepage wget -q --tries=1 --spider http://localhost:3000 &> /dev/null; then
        ok "  Homepage health check passed"
        ((checks_passed++))
    else
        warn "  Homepage health check failed (may need more time)"
    fi

    # Check network
    if docker inspect homepage 2>/dev/null | grep -q "traefik_network"; then
        ok "  Homepage connected to Traefik network"
        ((checks_passed++))
    else
        error "  Homepage not connected to Traefik network"
    fi

    # Check config files
    if [[ -f "$CONFIG_DIR/services.yaml" ]] && [[ -f "$CONFIG_DIR/widgets.yaml" ]] && \
       [[ -f "$CONFIG_DIR/settings.yaml" ]] && [[ -f "$CONFIG_DIR/bookmarks.yaml" ]]; then
        ok "  Configuration files created"
        ((checks_passed++))
    else
        error "  Some configuration files missing"
    fi

    # Check Traefik can see the service
    sleep 5
    local traefik_routers=$(docker exec traefik wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | grep -c "homepage" || echo "0")
    if [[ $traefik_routers -ge 1 ]]; then
        ok "  Traefik detected Homepage router"
        ((checks_passed++))
    else
        warn "  Traefik may not have detected router yet"
    fi

    echo ""
    log "Verification: $checks_passed/$total_checks checks passed"

    if [[ $checks_passed -ge 4 ]]; then
        ok "Deployment verification successful"
        return 0
    else
        error "Some verification checks failed"
        return 1
    fi
}

test_connection() {
    log "Testing connection to Homepage..."

    # Wait for SSL certificates (only for first-time setup)
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        log "Waiting 30 seconds for SSL certificate generation..."
        sleep 30
    fi

    # Test Homepage endpoint
    log "Testing Homepage: $HOMEPAGE_URL"
    if curl -s -k -m 10 "$HOMEPAGE_URL" &> /dev/null; then
        ok "Homepage accessible"
    else
        warn "Homepage test failed (DNS propagation may take time)"
    fi
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "Homepage Dashboard Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Installation Details:"
    echo "  Homepage URL: $HOMEPAGE_URL"
    echo "  Stack Location: $HOMEPAGE_DIR"
    echo "  Config Directory: $CONFIG_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access Information:"
    echo "  Main Dashboard: $HOMEPAGE_URL"
    echo "  Internal Port: 3000"
    echo ""
    echo "Detected Services:"
    [[ "$HAS_SUPABASE" == true ]] && echo "  - Supabase (Studio, API)"
    [[ "$HAS_TRAEFIK" == true ]] && echo "  - Traefik Dashboard"
    [[ "$HAS_PORTAINER" == true ]] && echo "  - Portainer ($PORTAINER_URL)"
    [[ "$HAS_GRAFANA" == true ]] && echo "  - Grafana"
    echo ""
    echo "Configuration Files:"
    echo "  Services: $CONFIG_DIR/services.yaml"
    echo "  Widgets: $CONFIG_DIR/widgets.yaml"
    echo "  Settings: $CONFIG_DIR/settings.yaml"
    echo "  Bookmarks: $CONFIG_DIR/bookmarks.yaml"
    echo ""
    echo "Container Management:"
    echo "  View logs: cd $HOMEPAGE_DIR && docker compose logs -f"
    echo "  Restart: cd $HOMEPAGE_DIR && docker compose restart"
    echo "  Stop: cd $HOMEPAGE_DIR && docker compose down"
    echo "  Start: cd $HOMEPAGE_DIR && docker compose up -d"
    echo ""

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "Important Notes:"
        echo "  - DNS propagation may take 5-15 minutes"
        echo "  - SSL certificate will be issued automatically"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]] && [[ "$USE_SUBDOMAIN" == true ]]; then
        echo "  - Ensure DNS record for ${HOMEPAGE_SUBDOMAIN}.${DOMAIN} points to your Pi's IP"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "vpn" ]]; then
        echo "Important Notes:"
        echo "  - Ensure VPN DNS is configured for .pi.local domains"
        echo "  - Access only works when connected to VPN"
    fi

    echo ""
    echo "Customization:"
    echo "  - Edit services: nano $CONFIG_DIR/services.yaml"
    echo "  - Edit widgets: nano $CONFIG_DIR/widgets.yaml"
    echo "  - Edit settings: nano $CONFIG_DIR/settings.yaml"
    echo "  - Edit bookmarks: nano $CONFIG_DIR/bookmarks.yaml"
    echo "  - Restart after changes: cd $HOMEPAGE_DIR && docker compose restart"
    echo ""

    if [[ "$HAS_PORTAINER" == true ]]; then
        echo "Portainer Widget Configuration:"
        echo "  The Portainer widget requires an API token to display container stats."
        echo "  To generate and configure the token, run:"
        echo "    curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/portainer/scripts/create-portainer-token.sh | sudo bash"
        echo "  This script will:"
        echo "    - Prompt for your Portainer credentials"
        echo "    - Generate an API token"
        echo "    - Automatically update Homepage configuration"
        echo "    - Restart Homepage container"
        echo ""
    fi
    echo "Troubleshooting:"
    echo "  - Check logs: docker logs homepage"
    echo "  - Check Traefik: docker logs traefik"
    echo "  - View Traefik routers: docker exec traefik wget -qO- http://localhost:8080/api/http/routers"

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "  - Verify DNS: nslookup ${DOMAIN}"
    fi

    echo "  - Test locally: curl -I -k $HOMEPAGE_URL"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$HOMEPAGE_DIR/DEPLOYMENT_INFO.txt" << SUMMARY
Homepage Dashboard Deployment Summary
Generated: $(date)

Homepage URL: ${HOMEPAGE_URL}
Scenario: ${TRAEFIK_SCENARIO}

Stack Directory: ${HOMEPAGE_DIR}
Config Directory: ${CONFIG_DIR}
Log File: ${LOG_FILE}

Detected Services:
$([ "$HAS_SUPABASE" = true ] && echo "  - Supabase")
$([ "$HAS_TRAEFIK" = true ] && echo "  - Traefik")
$([ "$HAS_PORTAINER" = true ] && echo "  - Portainer")
$([ "$HAS_GRAFANA" = true ] && echo "  - Grafana")

Configuration Files:
  ${CONFIG_DIR}/services.yaml
  ${CONFIG_DIR}/widgets.yaml
  ${CONFIG_DIR}/settings.yaml
  ${CONFIG_DIR}/bookmarks.yaml

Container Commands:
  cd ${HOMEPAGE_DIR}
  docker compose logs -f          # View logs
  docker compose restart          # Restart service
  docker compose down             # Stop service
  docker compose up -d            # Start service

Customization:
  Edit configuration files in ${CONFIG_DIR}/
  Restart container after changes

Docker Compose: ${COMPOSE_FILE}
SUMMARY

    chmod 600 "$HOMEPAGE_DIR/DEPLOYMENT_INFO.txt"
    chown "$TARGET_USER:$TARGET_USER" "$HOMEPAGE_DIR/DEPLOYMENT_INFO.txt"

    ok "Deployment information saved to $HOMEPAGE_DIR/DEPLOYMENT_INFO.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root
    setup_logging

    echo ""
    log "Starting Homepage Dashboard deployment for Raspberry Pi 5"
    echo ""

    # Validation
    check_dependencies
    check_docker
    check_traefik_installation
    check_traefik_network
    check_existing_homepage
    check_system_resources
    detect_traefik_scenario
    detect_pi_ip
    detect_installed_services
    echo ""

    # User input
    prompt_user_input
    echo ""

    # Main execution
    create_directory_structure
    create_backup
    generate_services_yaml
    generate_widgets_yaml
    generate_settings_yaml
    generate_bookmarks_yaml
    generate_docker_compose
    echo ""

    # Deployment
    deploy_homepage
    echo ""

    # Verification
    verify_deployment
    test_connection
    echo ""

    # Summary
    show_summary
}

main "$@"
