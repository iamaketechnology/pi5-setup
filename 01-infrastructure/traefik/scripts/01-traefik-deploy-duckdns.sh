#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Traefik v3 Deployment with DuckDNS DNS Provider for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Traefik v3 reverse proxy with DuckDNS integration
# Architecture: ARM64 (Raspberry Pi 5)
# DNS Provider: DuckDNS
# SSL Challenge: HTTP-01 (Let's Encrypt)
# Routing Mode: Path-based (/studio, /api, /traefik)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[TRAEFIK]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]  \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.1.0"
LOG_FILE="/var/log/traefik-deploy-duckdns-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
STACK_DIR="/home/${TARGET_USER}/stacks/traefik"
TRAEFIK_VERSION="v3.3"

# User-provided variables (will be prompted)
DUCKDNS_SUBDOMAIN=""
DUCKDNS_TOKEN=""
USER_EMAIL=""
DASHBOARD_PASSWORD=""

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

    local dependencies=("curl" "docker" "htpasswd" "openssl")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"

        # Try to install missing dependencies
        log "Attempting to install missing dependencies..."
        apt update -qq

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                htpasswd)
                    apt install -y apache2-utils
                    ;;
                docker)
                    error_exit "Docker not found. Please install Docker first."
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

    # Test Docker
    if ! docker info &> /dev/null; then
        error_exit "Docker is not functioning correctly"
    fi

    # Check Docker Compose plugin
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin not found. Please install docker-compose-plugin"
    fi

    ok "Docker is installed and running"
}

check_existing_traefik() {
    log "Checking for existing Traefik installation..."

    # Check if Traefik container is running
    if docker ps -a --format '{{.Names}}' | grep -q '^traefik$'; then
        warn "Existing Traefik container found"
        read -p "Do you want to remove it and continue? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping and removing existing Traefik container..."
            docker stop traefik 2>/dev/null || true
            docker rm traefik 2>/dev/null || true
            ok "Existing container removed"
        else
            error_exit "Installation cancelled by user"
        fi
    fi

    # Check if port 80 and 443 are available
    if netstat -tuln 2>/dev/null | grep -q ':80 ' || ss -tuln 2>/dev/null | grep -q ':80 '; then
        warn "Port 80 is in use. Traefik requires this port."
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled due to port conflict"
        fi
    fi

    if netstat -tuln 2>/dev/null | grep -q ':443 ' || ss -tuln 2>/dev/null | grep -q ':443 '; then
        warn "Port 443 is in use. Traefik requires this port."
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled due to port conflict"
        fi
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
    local disk_gb=$(df "$STACK_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt 5 ]]; then
        warn "Low disk space: ${disk_gb}GB available (minimum 5GB recommended)"
    else
        ok "Disk space: ${disk_gb}GB available"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting configuration information..."
    echo ""
    echo "=========================================="
    echo "Traefik DuckDNS Configuration"
    echo "=========================================="
    echo ""

    # DuckDNS subdomain
    while [[ -z "$DUCKDNS_SUBDOMAIN" ]]; do
        read -p "Enter your DuckDNS subdomain (e.g., mypi): " DUCKDNS_SUBDOMAIN
        if [[ -z "$DUCKDNS_SUBDOMAIN" ]]; then
            warn "Subdomain cannot be empty"
        fi
    done

    # DuckDNS token
    while [[ -z "$DUCKDNS_TOKEN" ]]; do
        read -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
        if [[ -z "$DUCKDNS_TOKEN" ]]; then
            warn "Token cannot be empty"
        fi
    done

    # Email for Let's Encrypt
    while [[ -z "$USER_EMAIL" ]]; do
        read -p "Enter your email for Let's Encrypt notifications: " USER_EMAIL
        if [[ -z "$USER_EMAIL" ]]; then
            warn "Email cannot be empty"
        elif [[ ! "$USER_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            warn "Invalid email format"
            USER_EMAIL=""
        fi
    done

    # Dashboard password
    echo ""
    log "Generating secure dashboard password..."
    DASHBOARD_PASSWORD=$(openssl rand -base64 16)
    ok "Password generated: $DASHBOARD_PASSWORD"
    echo ""
    warn "IMPORTANT: Save this password securely!"
    echo ""

    # Confirmation
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "DuckDNS Domain: ${DUCKDNS_SUBDOMAIN}.duckdns.org"
    echo "Email: $USER_EMAIL"
    echo "Dashboard Password: $DASHBOARD_PASSWORD"
    echo "=========================================="
    echo ""

    read -p "Is this information correct? [y/N]: " -n 1 -r
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

    log "=== Traefik DuckDNS Deployment - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_directory_structure() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "$STACK_DIR"/{config,dynamic,logs,acme}

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR"

    ok "Directory structure created at $STACK_DIR"
}

generate_traefik_static_config() {
    log "Generating Traefik static configuration..."

    cat > "$STACK_DIR/config/traefik.yml" << EOF
# Traefik v3 Static Configuration
# Generated: $(date)
# Provider: DuckDNS
# Challenge: HTTP-01

global:
  checkNewVersion: true
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: true  # Enable dashboard on localhost:8081 (port 8080 internal)

ping:
  entryPoint: "web"

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true

  websecure:
    address: ":443"
    http:
      tls:
        certResolver: letsencrypt

certificatesResolvers:
  letsencrypt:
    acme:
      email: ${USER_EMAIL}
      storage: /acme/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: traefik_network

  file:
    directory: /dynamic
    watch: true

log:
  level: INFO
  filePath: /logs/traefik.log
  format: common

accessLog:
  filePath: /logs/access.log
  format: common
  bufferingSize: 100
  filters:
    statusCodes:
      - "400-599"
EOF

    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/config/traefik.yml"
    ok "Static configuration generated"
}

generate_traefik_dynamic_config() {
    log "Generating Traefik dynamic configuration..."

    # Generate htpasswd hash for dashboard
    local htpasswd_hash=$(htpasswd -nb admin "$DASHBOARD_PASSWORD")

    # Middlewares configuration
    cat > "$STACK_DIR/dynamic/middlewares.yml" << EOF
# Traefik v3 Dynamic Configuration - Middlewares
# Generated: $(date)

http:
  middlewares:
    # Enhanced Security headers (with CSP)
    security-headers:
      headers:
        browserXssFilter: true
        contentTypeNosniff: true
        forceSTSHeader: true
        stsIncludeSubdomains: true
        stsPreload: true
        stsSeconds: 31536000
        customFrameOptionsValue: "SAMEORIGIN"
        contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'"
        referrerPolicy: "strict-origin-when-cross-origin"
        permissionsPolicy: "geolocation=(), microphone=(), camera=()"
        customResponseHeaders:
          X-Robots-Tag: "none"
          X-Content-Type-Options: "nosniff"

    # Dashboard authentication
    dashboard-auth:
      basicAuth:
        users:
          - "${htpasswd_hash}"

    # Rate limiting - Global (moderate profile)
    rate-limit-global:
      rateLimit:
        average: 100
        burst: 50
        period: 1s

    # Rate limiting - API endpoints
    rate-limit-api:
      rateLimit:
        average: 60
        burst: 30
        period: 1s
        sourceCriterion:
          ipStrategy:
            depth: 1

    # Rate limiting - Authentication endpoints
    rate-limit-auth:
      rateLimit:
        average: 20
        burst: 10
        period: 1s
        sourceCriterion:
          ipStrategy:
            depth: 1
            excludedIPs:
              - "127.0.0.1/32"
              - "192.168.1.0/24"

    # Rate limiting - Strict (admin/sensitive endpoints)
    rate-limit-strict:
      rateLimit:
        average: 10
        burst: 5
        period: 1s
        sourceCriterion:
          ipStrategy:
            depth: 1

    # CORS headers
    cors-headers:
      headers:
        accessControlAllowMethods:
          - "GET"
          - "POST"
          - "PUT"
          - "DELETE"
          - "PATCH"
          - "OPTIONS"
        accessControlAllowOriginList:
          - "*"
        accessControlAllowHeaders:
          - "Content-Type"
          - "Authorization"
          - "X-Requested-With"
        accessControlMaxAge: 86400
        addVaryHeader: true

    # Compression
    compression:
      compress: {}

    # Path prefix stripping
    strip-prefix-studio:
      stripPrefix:
        prefixes:
          - "/studio"

    strip-prefix-api:
      stripPrefix:
        prefixes:
          - "/api"

    strip-prefix-traefik:
      stripPrefix:
        prefixes:
          - "/traefik"
EOF

    # TLS configuration
    cat > "$STACK_DIR/dynamic/tls.yml" << EOF
# Traefik v3 Dynamic Configuration - TLS
# Generated: $(date)

tls:
  options:
    default:
      minVersion: VersionTLS12
      cipherSuites:
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305
        - TLS_AES_128_GCM_SHA256
        - TLS_AES_256_GCM_SHA384
        - TLS_CHACHA20_POLY1305_SHA256
      curvePreferences:
        - CurveP521
        - CurveP384
      sniStrict: true
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR/dynamic"
    ok "Dynamic configuration generated"
}

generate_env_file() {
    log "Generating environment file..."

    cat > "$STACK_DIR/.env" << EOF
# Traefik DuckDNS Environment Variables
# Generated: $(date)
# WARNING: This file contains sensitive information - keep it secure!

# DuckDNS Configuration
DUCKDNS_SUBDOMAIN=${DUCKDNS_SUBDOMAIN}
DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
DUCKDNS_DOMAIN=${DUCKDNS_SUBDOMAIN}.duckdns.org

# Let's Encrypt Configuration
LETSENCRYPT_EMAIL=${USER_EMAIL}

# Dashboard Credentials
DASHBOARD_USER=admin
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}

# Traefik Version
TRAEFIK_VERSION=${TRAEFIK_VERSION}
EOF

    chmod 600 "$STACK_DIR/.env"
    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/.env"
    ok "Environment file created with restricted permissions"
}

generate_docker_compose() {
    log "Generating docker-compose.yml..."

    cat > "$STACK_DIR/docker-compose.yml" << 'EOF'
# Traefik v3 with DuckDNS Docker Compose Configuration
# Generated: $(date)

version: '3.8'

services:
  traefik:
    image: traefik:${TRAEFIK_VERSION}
    container_name: traefik
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - traefik_network
    ports:
      - "80:80"
      - "443:443"
      - "127.0.0.1:8081:8080"  # Dashboard API (localhost only)
    environment:
      - TZ=UTC
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/traefik.yml:ro
      - ./dynamic:/dynamic:ro
      - ./acme:/acme
      - ./logs:/logs
    labels:
      - "traefik.enable=true"

      # Dashboard routing (DISABLED - PathPrefix not supported by Traefik v3 dashboard)
      # Traefik v3 dashboard requires fixed paths /dashboard/ and /api/
      # Path-based routing with StripPrefix does not work with api@internal service
      #
      # WORKAROUND: Use insecure mode on port 8080 (localhost only)
      # To enable: Change traefik.yml api.insecure to true
      # Then access: http://localhost:8080/dashboard/
      #
      # For production: Use subdomain (traefik.domain.com) instead of path prefix
      # DuckDNS limitation: Only 1 subdomain available (used for main domain)
      #
      # Alternative monitoring: Use Portainer at http://IP:9000 for container management
    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    restart: unless-stopped
    networks:
      - traefik_network
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=UTC
      - SUBDOMAINS=${DUCKDNS_SUBDOMAIN}
      - TOKEN=${DUCKDNS_TOKEN}
      - LOG_FILE=true
    volumes:
      - ./logs/duckdns:/config
    healthcheck:
      test: ["CMD-SHELL", "grep -q 'successful' /config/duck.log || exit 1"]
      interval: 5m
      timeout: 10s
      retries: 3
      start_period: 30s

networks:
  traefik_network:
    name: traefik_network
    driver: bridge
EOF

    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/docker-compose.yml"
    ok "Docker Compose configuration generated"
}

configure_acme_permissions() {
    log "Configuring ACME certificate storage..."

    # Create acme.json with proper permissions
    touch "$STACK_DIR/acme/acme.json"
    chmod 600 "$STACK_DIR/acme/acme.json"
    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/acme/acme.json"

    ok "ACME storage configured with secure permissions"
}

deploy_traefik_stack() {
    log "Deploying Traefik stack..."

    # Change to stack directory
    cd "$STACK_DIR"

    # Pull images first
    log "Pulling Docker images..."
    sudo -u "$TARGET_USER" docker compose pull

    # Start the stack
    log "Starting Traefik stack..."
    sudo -u "$TARGET_USER" docker compose up -d

    # Wait for containers to be healthy
    log "Waiting for containers to start..."
    sleep 10

    ok "Traefik stack deployed successfully"
}

configure_firewall() {
    log "Configuring firewall rules..."

    if command -v ufw &> /dev/null; then
        # Allow HTTP and HTTPS
        ufw allow 80/tcp comment "Traefik HTTP" 2>/dev/null || true
        ufw allow 443/tcp comment "Traefik HTTPS" 2>/dev/null || true

        ok "Firewall rules configured"
    else
        warn "UFW not found - skipping firewall configuration"
    fi
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_deployment() {
    log "Verifying deployment..."

    local checks_passed=0
    local total_checks=5

    # Check Traefik container
    if docker ps | grep -q 'traefik'; then
        ok "  Traefik container is running"
        ((checks_passed++))
    else
        error "  Traefik container is not running"
    fi

    # Check DuckDNS container
    if docker ps | grep -q 'duckdns'; then
        ok "  DuckDNS container is running"
        ((checks_passed++))
    else
        error "  DuckDNS container is not running"
    fi

    # Check Traefik health
    sleep 5
    if docker exec traefik traefik healthcheck --ping &> /dev/null; then
        ok "  Traefik health check passed"
        ((checks_passed++))
    else
        warn "  Traefik health check failed (may need more time)"
    fi

    # Check network
    if docker network ls | grep -q 'traefik_network'; then
        ok "  Traefik network created"
        ((checks_passed++))
    else
        error "  Traefik network not found"
    fi

    # Check acme.json permissions
    if [[ "$(stat -c %a "$STACK_DIR/acme/acme.json" 2>/dev/null || stat -f %A "$STACK_DIR/acme/acme.json")" == "600" ]]; then
        ok "  ACME file permissions correct"
        ((checks_passed++))
    else
        error "  ACME file permissions incorrect"
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
    log "Testing connections..."

    local domain="${DUCKDNS_SUBDOMAIN}.duckdns.org"

    # Wait for DuckDNS to update
    log "Waiting 30 seconds for DuckDNS IP update..."
    sleep 30

    # Test HTTP redirect
    log "Testing HTTP to HTTPS redirect..."
    if curl -s -I -L "http://${domain}" -m 10 | grep -q "HTTP/.*200\|HTTP/.*301\|HTTP/.*302"; then
        ok "HTTP redirect working"
    else
        warn "HTTP redirect test failed (this is normal if DNS hasn't propagated yet)"
    fi

    # Test HTTPS
    log "Testing HTTPS connection..."
    if curl -s -I -k "https://${domain}" -m 10 &> /dev/null; then
        ok "HTTPS connection successful"
    else
        warn "HTTPS test failed (DNS propagation may take a few minutes)"
    fi
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    local domain="${DUCKDNS_SUBDOMAIN}.duckdns.org"

    echo ""
    echo "=========================================="
    echo "Traefik DuckDNS Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Installation Details:"
    echo "  Domain: https://${domain}"
    echo "  Stack Location: $STACK_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access URLs:"
    echo "  Dashboard: http://localhost:8081/dashboard/ (localhost only)"
    echo "  Username: admin"
    echo "  Password: $DASHBOARD_PASSWORD"
    echo ""
    echo "Path-based Routing Examples:"
    echo "  Studio: https://${domain}/studio"
    echo "  API: https://${domain}/api"
    echo "  Traefik Dashboard: http://localhost:8081/dashboard/ (localhost only)"
    echo ""
    echo "DuckDNS Configuration:"
    echo "  Subdomain: $DUCKDNS_SUBDOMAIN"
    echo "  Auto-update: Enabled (5-minute interval)"
    echo ""
    echo "SSL Certificate:"
    echo "  Provider: Let's Encrypt"
    echo "  Challenge: HTTP-01"
    echo "  Auto-renewal: Enabled"
    echo "  Storage: $STACK_DIR/acme/acme.json"
    echo ""
    echo "Container Management:"
    echo "  View logs: cd $STACK_DIR && docker compose logs -f"
    echo "  Restart: cd $STACK_DIR && docker compose restart"
    echo "  Stop: cd $STACK_DIR && docker compose down"
    echo "  Start: cd $STACK_DIR && docker compose up -d"
    echo ""
    echo "Important Notes:"
    echo "  - DNS propagation may take 5-15 minutes"
    echo "  - SSL certificate will be issued on first HTTPS request"
    echo "  - Dashboard password is in $STACK_DIR/.env"
    echo "  - DuckDNS updates your IP every 5 minutes"
    echo ""
    echo "Next Steps:"
    echo "  1. Wait for DNS propagation (check: nslookup ${domain})"
    echo "  2. Access dashboard at https://${domain}/traefik"
    echo "  3. Configure your services with Traefik labels"
    echo "  4. Review logs: docker compose logs -f traefik"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Traefik logs: docker logs traefik"
    echo "  - Check DuckDNS logs: docker logs duckdns"
    echo "  - Verify DNS: nslookup ${domain}"
    echo "  - Test locally: curl -I http://localhost"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$STACK_DIR/DEPLOYMENT_INFO.txt" << SUMMARY
Traefik DuckDNS Deployment Summary
Generated: $(date)

Domain: https://${domain}

Dashboard Access (Localhost Only):
  URL: http://localhost:8081/dashboard/
  Note: PathPrefix routing not supported by Traefik v3 dashboard
  Access via SSH tunnel: ssh -L 8081:localhost:8081 pi@<PI_IP>

DuckDNS Subdomain: ${DUCKDNS_SUBDOMAIN}
Let's Encrypt Email: ${USER_EMAIL}

Stack Directory: ${STACK_DIR}
Log File: ${LOG_FILE}

Container Commands:
  cd ${STACK_DIR}
  docker compose logs -f          # View logs
  docker compose restart          # Restart services
  docker compose down             # Stop services
  docker compose up -d            # Start services

Configuration Files:
  Static Config: ${STACK_DIR}/config/traefik.yml
  Dynamic Config: ${STACK_DIR}/dynamic/
  Environment: ${STACK_DIR}/.env
  ACME Storage: ${STACK_DIR}/acme/acme.json
SUMMARY

    chmod 600 "$STACK_DIR/DEPLOYMENT_INFO.txt"
    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/DEPLOYMENT_INFO.txt"

    ok "Deployment information saved to $STACK_DIR/DEPLOYMENT_INFO.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root
    setup_logging

    echo ""
    log "Starting Traefik v3 DuckDNS deployment for Raspberry Pi 5"
    echo ""

    # Validation
    check_dependencies
    check_docker
    check_system_resources
    check_existing_traefik
    echo ""

    # User input
    prompt_user_input
    echo ""

    # Main execution
    create_directory_structure
    generate_traefik_static_config
    generate_traefik_dynamic_config
    generate_env_file
    generate_docker_compose
    configure_acme_permissions
    configure_firewall
    echo ""

    # Deployment
    deploy_traefik_stack
    echo ""

    # Verification
    verify_deployment
    test_connection
    echo ""

    # Summary
    show_summary
}

main "$@"
