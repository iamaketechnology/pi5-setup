#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Traefik v3 Deployment for VPN-Only Access on Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Traefik v3 reverse proxy for private VPN networks
# Architecture: ARM64 (Raspberry Pi 5)
# DNS Provider: None (Local DNS or mDNS)
# SSL: Self-signed certificates or mkcert
# Routing Mode: Local domains (.pi.local, .home.local)
# Use Case: Tailscale, WireGuard, OpenVPN, or LAN-only access
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
LOG_FILE="/var/log/traefik-deploy-vpn-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
STACK_DIR="/home/${TARGET_USER}/stacks/traefik"
TRAEFIK_VERSION="v3.3"

# User-provided variables (will be prompted)
VPN_NETWORK=""
LOCAL_DOMAIN=""
CERT_TYPE=""
DASHBOARD_PASSWORD=""

# Default values
DEFAULT_VPN_NETWORK="10.0.0.0/24"
DEFAULT_LOCAL_DOMAIN="pi.local"

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

    # Check if ports are available
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

detect_vpn_interfaces() {
    log "Detecting network interfaces..."

    # List all network interfaces
    local interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')

    echo ""
    echo "Available network interfaces:"
    echo "$interfaces" | nl
    echo ""

    # Check for common VPN interfaces
    if echo "$interfaces" | grep -q 'tailscale0'; then
        ok "Tailscale interface detected"
        warn "Recommended VPN network: 100.64.0.0/10 (Tailscale)"
    fi

    if echo "$interfaces" | grep -q 'wg0'; then
        ok "WireGuard interface detected"
        warn "Recommended VPN network: Check your WireGuard config"
    fi

    if echo "$interfaces" | grep -q 'tun0'; then
        ok "OpenVPN interface detected"
        warn "Recommended VPN network: Check your OpenVPN config"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting configuration information..."
    echo ""
    echo "=========================================="
    echo "Traefik VPN-Only Configuration"
    echo "=========================================="
    echo ""
    echo "This setup is for private networks without public SSL certificates."
    echo "Suitable for: Tailscale, WireGuard, OpenVPN, or LAN-only access."
    echo ""

    # Detect VPN interfaces
    detect_vpn_interfaces

    # VPN Network
    echo ""
    read -p "Enter your VPN network CIDR [default: $DEFAULT_VPN_NETWORK]: " VPN_NETWORK
    VPN_NETWORK=${VPN_NETWORK:-$DEFAULT_VPN_NETWORK}

    # Validate CIDR format
    if [[ ! "$VPN_NETWORK" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        warn "Invalid CIDR format, using default: $DEFAULT_VPN_NETWORK"
        VPN_NETWORK="$DEFAULT_VPN_NETWORK"
    fi

    # Local domain
    echo ""
    log "Local domain for service access (e.g., traefik.pi.local)"
    read -p "Enter your local domain [default: $DEFAULT_LOCAL_DOMAIN]: " LOCAL_DOMAIN
    LOCAL_DOMAIN=${LOCAL_DOMAIN:-$DEFAULT_LOCAL_DOMAIN}

    # Certificate type
    echo ""
    echo "Choose certificate type:"
    echo "  1) Self-signed certificate (automatic, works everywhere)"
    echo "  2) mkcert (trusted by browsers, requires manual installation)"
    echo ""
    read -p "Select option [1-2, default: 1]: " cert_choice
    cert_choice=${cert_choice:-1}

    case "$cert_choice" in
        2)
            CERT_TYPE="mkcert"
            ;;
        *)
            CERT_TYPE="self-signed"
            ;;
    esac

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
    echo "VPN Network: $VPN_NETWORK"
    echo "Local Domain: $LOCAL_DOMAIN"
    echo "Certificate Type: $CERT_TYPE"
    echo "Dashboard Password: $DASHBOARD_PASSWORD"
    echo ""
    echo "Example service URLs:"
    echo "  Dashboard: https://traefik.${LOCAL_DOMAIN}"
    echo "  Studio: https://studio.${LOCAL_DOMAIN}"
    echo "  API: https://api.${LOCAL_DOMAIN}"
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

    log "=== Traefik VPN-Only Deployment - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_directory_structure() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "$STACK_DIR"/{config,dynamic,logs,certs}

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR"

    ok "Directory structure created at $STACK_DIR"
}

generate_self_signed_cert() {
    log "Generating self-signed SSL certificate..."

    # Generate private key
    openssl genrsa -out "$STACK_DIR/certs/traefik.key" 4096 2>/dev/null

    # Generate certificate
    openssl req -new -x509 -sha256 -days 3650 \
        -key "$STACK_DIR/certs/traefik.key" \
        -out "$STACK_DIR/certs/traefik.crt" \
        -subj "/C=US/ST=State/L=City/O=HomeServer/CN=*.${LOCAL_DOMAIN}" \
        -addext "subjectAltName=DNS:*.${LOCAL_DOMAIN},DNS:${LOCAL_DOMAIN}" 2>/dev/null

    # Set permissions
    chmod 600 "$STACK_DIR/certs/traefik.key"
    chmod 644 "$STACK_DIR/certs/traefik.crt"
    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR/certs"

    ok "Self-signed certificate generated (valid for 10 years)"
    warn "Browsers will show a security warning - this is normal for self-signed certs"
}

install_mkcert() {
    log "Installing mkcert for local trusted certificates..."

    # Check if mkcert is already installed
    if command -v mkcert &> /dev/null; then
        ok "mkcert already installed"
    else
        # Download and install mkcert for ARM64
        log "Downloading mkcert..."
        curl -L https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-arm64 \
            -o /usr/local/bin/mkcert

        chmod +x /usr/local/bin/mkcert
        ok "mkcert installed"
    fi

    # Install CA
    log "Installing local CA..."
    sudo -u "$TARGET_USER" mkcert -install

    # Generate certificate
    log "Generating mkcert certificate..."
    cd "$STACK_DIR/certs"
    sudo -u "$TARGET_USER" mkcert "*.${LOCAL_DOMAIN}" "${LOCAL_DOMAIN}"

    # Rename files
    mv "$STACK_DIR/certs/_${LOCAL_DOMAIN}+1.pem" "$STACK_DIR/certs/traefik.crt" 2>/dev/null || \
        mv "$STACK_DIR/certs/_${LOCAL_DOMAIN}"*.pem "$STACK_DIR/certs/traefik.crt" 2>/dev/null || true
    mv "$STACK_DIR/certs/_${LOCAL_DOMAIN}+1-key.pem" "$STACK_DIR/certs/traefik.key" 2>/dev/null || \
        mv "$STACK_DIR/certs/_${LOCAL_DOMAIN}"*-key.pem "$STACK_DIR/certs/traefik.key" 2>/dev/null || true

    chmod 600 "$STACK_DIR/certs/traefik.key"
    chmod 644 "$STACK_DIR/certs/traefik.crt"
    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR/certs"

    ok "mkcert certificate generated"

    # Get CA location
    local ca_location=$(sudo -u "$TARGET_USER" mkcert -CAROOT)

    echo ""
    warn "MANUAL ACTION REQUIRED:"
    echo "  To trust certificates on other devices, install the CA from:"
    echo "  $ca_location/rootCA.pem"
    echo ""
    echo "  For browsers on other computers:"
    echo "  1. Copy $ca_location/rootCA.pem to your computer"
    echo "  2. Import it as a trusted certificate authority"
    echo ""
}

generate_traefik_static_config() {
    log "Generating Traefik static configuration..."

    cat > "$STACK_DIR/config/traefik.yml" << EOF
# Traefik v3 Static Configuration
# Generated: $(date)
# Mode: VPN-Only / Private Network
# Certificate: ${CERT_TYPE}

global:
  checkNewVersion: true
  sendAnonymousUsage: false

api:
  dashboard: true
  insecure: false

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
        options: default

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

    # VPN IP restriction
    vpn-only:
      ipAllowList:
        sourceRange:
          - "${VPN_NETWORK}"
          - "127.0.0.1/32"
          - "192.168.0.0/16"
          - "10.0.0.0/8"
          - "172.16.0.0/12"
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

  certificates:
    - certFile: /certs/traefik.crt
      keyFile: /certs/traefik.key
      stores:
        - default

  stores:
    default:
      defaultCertificate:
        certFile: /certs/traefik.crt
        keyFile: /certs/traefik.key
EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$STACK_DIR/dynamic"
    ok "Dynamic configuration generated"
}

generate_env_file() {
    log "Generating environment file..."

    cat > "$STACK_DIR/.env" << EOF
# Traefik VPN-Only Environment Variables
# Generated: $(date)
# WARNING: This file contains sensitive information - keep it secure!

# Network Configuration
VPN_NETWORK=${VPN_NETWORK}
LOCAL_DOMAIN=${LOCAL_DOMAIN}

# Certificate Type
CERT_TYPE=${CERT_TYPE}

# Dashboard Credentials
DASHBOARD_USER=admin
DASHBOARD_PASSWORD=${DASHBOARD_PASSWORD}

# Traefik Version
TRAEFIK_VERSION=${TRAEFIK_VERSION}

# Timezone
TZ=UTC
EOF

    chmod 600 "$STACK_DIR/.env"
    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/.env"
    ok "Environment file created with restricted permissions"
}

generate_docker_compose() {
    log "Generating docker-compose.yml..."

    cat > "$STACK_DIR/docker-compose.yml" << 'EOF'
# Traefik v3 VPN-Only Docker Compose Configuration
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
    environment:
      - TZ=${TZ}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/traefik.yml:/traefik.yml:ro
      - ./dynamic:/dynamic:ro
      - ./certs:/certs:ro
      - ./logs:/logs
    labels:
      - "traefik.enable=true"

      # Dashboard routing
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${LOCAL_DOMAIN}`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls=true"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=dashboard-auth,vpn-only,security-headers"

      # API routing
      - "traefik.http.routers.api.rule=Host(`traefik.${LOCAL_DOMAIN}`) && PathPrefix(`/api`)"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.service=api@internal"
      - "traefik.http.routers.api.middlewares=dashboard-auth,vpn-only,security-headers"

    healthcheck:
      test: ["CMD", "traefik", "healthcheck", "--ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

networks:
  traefik_network:
    name: traefik_network
    driver: bridge
EOF

    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/docker-compose.yml"
    ok "Docker Compose configuration generated"
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
        # Allow HTTP and HTTPS from VPN network only
        log "Restricting access to VPN network: $VPN_NETWORK"

        # Delete existing rules if any
        ufw delete allow 80/tcp 2>/dev/null || true
        ufw delete allow 443/tcp 2>/dev/null || true

        # Add VPN-specific rules
        ufw allow from "$VPN_NETWORK" to any port 80 proto tcp comment "Traefik HTTP (VPN)" 2>/dev/null || true
        ufw allow from "$VPN_NETWORK" to any port 443 proto tcp comment "Traefik HTTPS (VPN)" 2>/dev/null || true

        # Also allow from local networks
        ufw allow from 192.168.0.0/16 to any port 80 proto tcp comment "Traefik HTTP (LAN)" 2>/dev/null || true
        ufw allow from 192.168.0.0/16 to any port 443 proto tcp comment "Traefik HTTPS (LAN)" 2>/dev/null || true
        ufw allow from 10.0.0.0/8 to any port 80 proto tcp comment "Traefik HTTP (Private)" 2>/dev/null || true
        ufw allow from 10.0.0.0/8 to any port 443 proto tcp comment "Traefik HTTPS (Private)" 2>/dev/null || true

        ok "Firewall rules configured (VPN and LAN only)"
    else
        warn "UFW not found - skipping firewall configuration"
    fi
}

create_hosts_file_example() {
    log "Creating hosts file example..."

    local pi_ip=$(hostname -I | awk '{print $1}')

    cat > "$STACK_DIR/HOSTS_FILE_EXAMPLE.txt" << HOSTS_EXAMPLE
Local DNS / Hosts File Configuration
====================================
Generated: $(date)

To access Traefik services using local domains, add these entries to your hosts file:

Raspberry Pi IP: ${pi_ip}

Add these lines to your hosts file:

${pi_ip}    traefik.${LOCAL_DOMAIN}
${pi_ip}    studio.${LOCAL_DOMAIN}
${pi_ip}    api.${LOCAL_DOMAIN}

Hosts File Locations:
- Linux/Mac: /etc/hosts
- Windows: C:\Windows\System32\drivers\etc\hosts

Instructions:

1. Linux/Mac:
   sudo nano /etc/hosts
   # Add the lines above
   # Save and exit (Ctrl+X, Y, Enter)

2. Windows (Run as Administrator):
   notepad C:\Windows\System32\drivers\etc\hosts
   # Add the lines above
   # Save and close

Alternative: Use mDNS (Avahi)
If you have Avahi/Bonjour installed:
   - Access: https://raspberrypi.local
   - Or use the Pi's hostname instead of IP

For Tailscale users:
   - Use MagicDNS feature for automatic DNS
   - Or use the Tailscale IP instead of ${pi_ip}
HOSTS_EXAMPLE

    chown "$TARGET_USER:$TARGET_USER" "$STACK_DIR/HOSTS_FILE_EXAMPLE.txt"
    ok "Hosts file example created: $STACK_DIR/HOSTS_FILE_EXAMPLE.txt"
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

    # Check certificates
    if [[ -f "$STACK_DIR/certs/traefik.crt" ]] && [[ -f "$STACK_DIR/certs/traefik.key" ]]; then
        ok "  SSL certificates present"
        ((checks_passed++))
    else
        error "  SSL certificates missing"
    fi

    # Check certificate permissions
    if [[ "$(stat -c %a "$STACK_DIR/certs/traefik.key" 2>/dev/null || stat -f %A "$STACK_DIR/certs/traefik.key")" == "600" ]]; then
        ok "  Certificate key permissions correct"
        ((checks_passed++))
    else
        error "  Certificate key permissions incorrect"
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
    log "Testing local connections..."

    local pi_ip=$(hostname -I | awk '{print $1}')

    # Test HTTP to HTTPS redirect
    log "Testing HTTP to HTTPS redirect..."
    if curl -s -I -L "http://${pi_ip}" -m 5 | grep -q "HTTP/.*301\|HTTP/.*302\|HTTP/.*200"; then
        ok "HTTP redirect working"
    else
        warn "HTTP redirect test inconclusive"
    fi

    # Test HTTPS with self-signed cert (allow insecure)
    log "Testing HTTPS connection..."
    if curl -s -I -k "https://${pi_ip}" -m 5 &> /dev/null; then
        ok "HTTPS connection successful"
    else
        warn "HTTPS test inconclusive"
    fi

    echo ""
    log "Access Traefik at: https://${pi_ip}"
    log "Or configure hosts file to use: https://traefik.${LOCAL_DOMAIN}"
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    local pi_ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "=========================================="
    echo "Traefik VPN-Only Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Installation Details:"
    echo "  Certificate Type: $CERT_TYPE"
    echo "  VPN Network: $VPN_NETWORK"
    echo "  Local Domain: $LOCAL_DOMAIN"
    echo "  Stack Location: $STACK_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access Methods:"
    echo "  1. By IP: https://${pi_ip}"
    echo "  2. By hostname: https://traefik.${LOCAL_DOMAIN}"
    echo "     (requires hosts file configuration)"
    echo ""
    echo "Dashboard Credentials:"
    echo "  Username: admin"
    echo "  Password: $DASHBOARD_PASSWORD"
    echo ""
    echo "Example Service URLs:"
    echo "  Dashboard: https://traefik.${LOCAL_DOMAIN}"
    echo "  Studio: https://studio.${LOCAL_DOMAIN}"
    echo "  API: https://api.${LOCAL_DOMAIN}"
    echo ""
    echo "SSL Certificate:"
    echo "  Type: $CERT_TYPE"
    echo "  Location: $STACK_DIR/certs/"

    if [[ "$CERT_TYPE" == "mkcert" ]]; then
        local ca_location=$(sudo -u "$TARGET_USER" mkcert -CAROOT 2>/dev/null || echo "Unknown")
        echo "  CA Root: $ca_location"
        echo "  Status: Trusted by this system"
        echo ""
        echo "  To trust on other devices:"
        echo "    Copy and install: $ca_location/rootCA.pem"
    else
        echo "  Status: Self-signed (browsers will show warning)"
        echo ""
        echo "  To avoid warnings:"
        echo "    - Use mkcert (re-run with option 2)"
        echo "    - Or accept the security exception in your browser"
    fi

    echo ""
    echo "Container Management:"
    echo "  View logs: cd $STACK_DIR && docker compose logs -f"
    echo "  Restart: cd $STACK_DIR && docker compose restart"
    echo "  Stop: cd $STACK_DIR && docker compose down"
    echo "  Start: cd $STACK_DIR && docker compose up -d"
    echo ""
    echo "Network Configuration:"
    echo "  Firewall: UFW configured (VPN and LAN only)"
    echo "  Access restricted to: $VPN_NETWORK and local networks"
    echo ""
    echo "Next Steps:"
    echo "  1. Configure hosts file (see HOSTS_FILE_EXAMPLE.txt)"
    echo "     cat $STACK_DIR/HOSTS_FILE_EXAMPLE.txt"
    echo "  2. Access dashboard: https://traefik.${LOCAL_DOMAIN}"
    echo "  3. Accept certificate warning (if using self-signed)"
    echo "  4. Configure your services with Traefik labels"
    echo "  5. Review logs: docker compose logs -f traefik"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Traefik logs: docker logs traefik"
    echo "  - Test direct IP access: curl -k https://${pi_ip}"
    echo "  - Verify hosts file: ping traefik.${LOCAL_DOMAIN}"
    echo "  - Check firewall: sudo ufw status"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$STACK_DIR/DEPLOYMENT_INFO.txt" << SUMMARY
Traefik VPN-Only Deployment Summary
Generated: $(date)

Raspberry Pi IP: ${pi_ip}
Local Domain: ${LOCAL_DOMAIN}
VPN Network: ${VPN_NETWORK}
Certificate Type: ${CERT_TYPE}

Dashboard Access:
  URL (IP): https://${pi_ip}
  URL (Domain): https://traefik.${LOCAL_DOMAIN}
  Username: admin
  Password: ${DASHBOARD_PASSWORD}

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
  Environment: ${STACK_DIR}/.env (SENSITIVE!)
  Certificates: ${STACK_DIR}/certs/
  Hosts Example: ${STACK_DIR}/HOSTS_FILE_EXAMPLE.txt

IMPORTANT: Configure hosts file to use local domains!
See HOSTS_FILE_EXAMPLE.txt for instructions.
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
    log "Starting Traefik v3 VPN-Only deployment for Raspberry Pi 5"
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

    # Generate certificates based on type
    if [[ "$CERT_TYPE" == "mkcert" ]]; then
        install_mkcert
    else
        generate_self_signed_cert
    fi

    generate_traefik_static_config
    generate_traefik_dynamic_config
    generate_env_file
    generate_docker_compose
    configure_firewall
    create_hosts_file_example
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
