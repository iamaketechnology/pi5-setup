#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Caddy Web Server Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Caddy web server with automatic HTTPS
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Caddy (standalone with auto-HTTPS)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[CADDY]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/caddy-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
INSTALL_DIR="/home/${TARGET_USER}/stacks/caddy"
BACKUP_DIR="${INSTALL_DIR}/backups"

# Configuration variables
CADDY_PORT="${CADDY_PORT:-8080}"
SITE_NAME="${SITE_NAME:-mysite}"
DOMAIN="${DOMAIN:-}"
EMAIL="${EMAIL:-}"

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
        echo "Optional environment variables:"
        echo "  CADDY_PORT=8080       # Port for Caddy (default: 8080, use 80/443 for auto-HTTPS)"
        echo "  SITE_NAME=mysite      # Site name (default: mysite)"
        echo "  DOMAIN=example.com    # Domain for auto-HTTPS (optional)"
        echo "  EMAIL=you@email.com   # Email for Let's Encrypt (required if DOMAIN set)"
        echo ""
        echo "Examples:"
        echo "  # Simple local server:"
        echo "  sudo CADDY_PORT=9000 $0"
        echo ""
        echo "  # With automatic HTTPS:"
        echo "  sudo DOMAIN=mysite.com EMAIL=me@email.com $0"
        exit 1
    fi
}

check_dependencies() {
    log "Checking system dependencies..."

    local dependencies=("docker" "docker compose")
    local missing_deps=()

    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    if ! docker compose version &> /dev/null 2>&1; then
        missing_deps+=("docker-compose")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error_exit "Missing dependencies: ${missing_deps[*]}. Please install Docker first."
    fi

    ok "All dependencies are present"
}

check_architecture() {
    log "Checking system architecture..."

    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        error_exit "Architecture $arch not supported. This script requires ARM64 (aarch64)"
    fi

    ok "Architecture: ARM64 (aarch64)"
}

check_ram() {
    log "Checking available RAM..."

    local ram_mb=$(free -m | awk '/^Mem:/{print $7}')
    if [[ $ram_mb -lt 500 ]]; then
        warn "Available RAM: ${ram_mb}MB - Low memory detected"
        warn "Caddy requires at least 500MB of free RAM"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled by user"
        fi
    else
        ok "Available RAM: ${ram_mb}MB"
    fi
}

check_domain_config() {
    log "Checking domain configuration..."

    if [[ -n "$DOMAIN" ]]; then
        if [[ -z "$EMAIL" ]]; then
            error_exit "EMAIL is required when DOMAIN is set (for Let's Encrypt)"
        fi

        log "Auto-HTTPS enabled for domain: $DOMAIN"
        log "Let's Encrypt email: $EMAIL"

        # Override ports for HTTPS
        CADDY_PORT="80:80"
        CADDY_HTTPS_PORT="443:443"

        warn "Note: Ports 80 and 443 must be accessible from the internet for Let's Encrypt"
    else
        log "No domain configured - running in HTTP-only mode on port $CADDY_PORT"
        CADDY_HTTPS_PORT=""
    fi
}

check_port() {
    if [[ -z "$DOMAIN" ]]; then
        log "Checking if port $CADDY_PORT is available..."

        if ss -tuln | grep -q ":${CADDY_PORT} "; then
            error_exit "Port $CADDY_PORT is already in use. Please choose a different port or stop the service using it."
        fi

        ok "Port $CADDY_PORT is available"
    else
        log "Checking if ports 80 and 443 are available..."

        if ss -tuln | grep -q ":80 "; then
            error_exit "Port 80 is already in use. Required for Let's Encrypt."
        fi

        if ss -tuln | grep -q ":443 "; then
            error_exit "Port 443 is already in use. Required for HTTPS."
        fi

        ok "Ports 80 and 443 are available"
    fi
}

# =============================================================================
# SETUP SECTION
# =============================================================================

setup_directories() {
    log "Creating directory structure..."

    mkdir -p "${INSTALL_DIR}"/{sites,data,config,logs}
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "${INSTALL_DIR}/sites/${SITE_NAME}"

    chown -R "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}"

    ok "Directory structure created"
}

create_default_site() {
    log "Creating default site..."

    cat > "${INSTALL_DIR}/sites/${SITE_NAME}/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Caddy sur Raspberry Pi 5</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3a8a 0%, #3b82f6 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 60px;
            max-width: 800px;
            text-align: center;
        }
        h1 {
            color: #333;
            font-size: 3em;
            margin-bottom: 20px;
        }
        .logo {
            font-size: 5em;
            margin-bottom: 20px;
        }
        p {
            color: #666;
            font-size: 1.2em;
            line-height: 1.8;
            margin-bottom: 30px;
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #3b82f6;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
        }
        .info-box strong {
            color: #1e3a8a;
        }
        .feature {
            display: inline-block;
            background: #e0f2fe;
            padding: 10px 20px;
            margin: 5px;
            border-radius: 20px;
            color: #1e3a8a;
            font-weight: bold;
        }
        .btn {
            display: inline-block;
            padding: 15px 40px;
            background: #3b82f6;
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            transition: all 0.3s;
            margin-top: 20px;
        }
        .btn:hover {
            background: #1e3a8a;
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">⚡</div>
        <h1>Caddy fonctionne !</h1>
        <p>Votre serveur web Caddy est maintenant opérationnel sur votre Raspberry Pi 5.</p>

        <div class="info-box">
            <strong>📁 Dossier racine :</strong> /home/pi/stacks/caddy/sites/mysite<br>
            <strong>📝 Fichier actuel :</strong> index.html<br>
            <strong>🔧 Configuration :</strong> /home/pi/stacks/caddy/config/Caddyfile
        </div>

        <p><strong>Fonctionnalités Caddy :</strong></p>
        <div class="feature">🔒 HTTPS Automatique</div>
        <div class="feature">⚙️ Configuration Simple</div>
        <div class="feature">🚀 Performances Élevées</div>
        <div class="feature">🔄 HTTP/2 & HTTP/3</div>

        <p>Remplacez ce fichier par vos propres pages web pour commencer !</p>

        <a href="https://github.com/iamaketechnology/pi5-setup" class="btn">
            Documentation PI5-SETUP
        </a>
    </div>
</body>
</html>
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/sites/${SITE_NAME}/index.html"
    ok "Default site created"
}

create_caddyfile() {
    log "Creating Caddyfile configuration..."

    if [[ -n "$DOMAIN" ]]; then
        # HTTPS mode with automatic Let's Encrypt
        cat > "${INSTALL_DIR}/config/Caddyfile" <<EOF
{
    email ${EMAIL}
    # Enable automatic HTTPS
    auto_https on
}

${DOMAIN} {
    # Root directory for website files
    root * /srv

    # Enable compression
    encode gzip zstd

    # Static file server
    file_server

    # Logs
    log {
        output file /var/log/caddy/access.log
        format json
    }

    # Headers for security
    header {
        # Enable HSTS
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        # Prevent clickjacking
        X-Frame-Options "SAMEORIGIN"
        # Prevent MIME sniffing
        X-Content-Type-Options "nosniff"
        # Enable XSS protection
        X-XSS-Protection "1; mode=block"
        # Referrer policy
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
    else
        # HTTP-only mode
        cat > "${INSTALL_DIR}/config/Caddyfile" <<EOF
{
    # HTTP-only configuration (no domain specified)
    auto_https off
}

:80 {
    # Root directory for website files
    root * /srv

    # Enable compression
    encode gzip zstd

    # Static file server
    file_server

    # Logs
    log {
        output file /var/log/caddy/access.log
        format json
    }

    # Basic headers
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
    }
}
EOF
    fi

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/config/Caddyfile"
    ok "Caddyfile created"
}

create_docker_compose() {
    log "Creating Docker Compose configuration..."

    local port_mapping=""
    if [[ -n "$DOMAIN" ]]; then
        port_mapping="      - \"80:80\"
      - \"443:443\"
      - \"443:443/udp\"  # HTTP/3"
    else
        port_mapping="      - \"${CADDY_PORT}:80\""
    fi

    cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: caddy-webserver
    restart: unless-stopped
    ports:
${port_mapping}
    networks:
      - caddy_network
    volumes:
      - ./sites/${SITE_NAME}:/srv:ro
      - ./config/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./data:/data
      - ./logs:/var/log/caddy
    environment:
      - TZ=Europe/Paris
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:2019/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  caddy_network:
    name: caddy_network
    driver: bridge
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/docker-compose.yml"
    ok "Docker Compose configuration created"
}

create_env_file() {
    log "Creating environment file..."

    cat > "${INSTALL_DIR}/.env" <<EOF
# Caddy Web Server Configuration
# Generated: $(date)

CADDY_PORT=${CADDY_PORT}
SITE_NAME=${SITE_NAME}
DOMAIN=${DOMAIN}
EMAIL=${EMAIL}
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/.env"
    chmod 600 "${INSTALL_DIR}/.env"
    ok "Environment file created"
}

# =============================================================================
# DEPLOYMENT SECTION
# =============================================================================

pull_images() {
    log "Pulling Docker images..."

    cd "${INSTALL_DIR}"
    su - "${TARGET_USER}" -c "cd ${INSTALL_DIR} && docker compose pull"

    ok "Docker images pulled"
}

start_services() {
    log "Starting Caddy services..."

    cd "${INSTALL_DIR}"
    su - "${TARGET_USER}" -c "cd ${INSTALL_DIR} && docker compose up -d"

    log "Waiting for services to be ready..."
    sleep 5

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker ps | grep -q "caddy-webserver.*healthy"; then
            ok "Caddy is healthy"
            break
        fi

        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            error_exit "Caddy failed to start properly"
        fi

        sleep 2
    done

    ok "Services started successfully"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_installation() {
    log "Verifying installation..."

    if ! docker ps | grep -q "caddy-webserver"; then
        error_exit "Caddy container is not running"
    fi

    # Check web server response
    local test_port
    if [[ -n "$DOMAIN" ]]; then
        test_port="80"
    else
        test_port="${CADDY_PORT}"
    fi

    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${test_port} || echo "000")
    if [[ "$response" != "200" ]]; then
        warn "Web server returned status code: $response"
    else
        ok "Web server is responding correctly"
    fi

    ok "Installation verified"
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

print_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')
    local access_urls=""

    if [[ -n "$DOMAIN" ]]; then
        access_urls="  • Public HTTPS: https://${DOMAIN} (after DNS configuration)
  • Local HTTP: http://${ip_address}"
    else
        access_urls="  • Local: http://localhost:${CADDY_PORT}
  • Network: http://${ip_address}:${CADDY_PORT}
  • Hostname: http://$(hostname).local:${CADDY_PORT}"
    fi

    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                    CADDY DEPLOYMENT SUCCESSFUL                             ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 Installation Summary:
  ✓ Caddy version: $(docker exec caddy-webserver caddy version | head -1)
  ✓ HTTPS mode: $([ -n "$DOMAIN" ] && echo "Enabled (automatic)" || echo "Disabled")
  ✓ Port: $([ -n "$DOMAIN" ] && echo "80, 443" || echo "$CADDY_PORT")
  ✓ Site name: ${SITE_NAME}
  $([ -n "$DOMAIN" ] && echo "✓ Domain: ${DOMAIN}" || echo "")

🌐 Access URLs:
${access_urls}

📁 Important Paths:
  • Site files: ${INSTALL_DIR}/sites/${SITE_NAME}/
  • Caddyfile: ${INSTALL_DIR}/config/Caddyfile
  • SSL data: ${INSTALL_DIR}/data/ (Let's Encrypt certificates)
  • Logs: ${INSTALL_DIR}/logs/
  • Docker Compose: ${INSTALL_DIR}/docker-compose.yml

🔧 Quick Commands:
  # View logs
  docker logs -f caddy-webserver

  # Restart services
  cd ${INSTALL_DIR} && docker compose restart

  # Stop services
  cd ${INSTALL_DIR} && docker compose down

  # Reload Caddyfile
  docker exec caddy-webserver caddy reload --config /etc/caddy/Caddyfile

📝 Next Steps:
  1. Upload your website files to: ${INSTALL_DIR}/sites/${SITE_NAME}/
  $([ -n "$DOMAIN" ] && echo "2. Configure DNS A record: ${DOMAIN} -> ${ip_address}" || echo "")
  $([ -n "$DOMAIN" ] && echo "3. Wait for Let's Encrypt (automatic, ~2 minutes)" || echo "")
  $([ -z "$DOMAIN" ] && echo "2. For HTTPS, set DOMAIN and EMAIL variables and redeploy" || echo "")

📖 Documentation: https://github.com/iamaketechnology/pi5-setup

EOF

    log "Installation log saved to: $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "=== Caddy Web Server Deployment v${SCRIPT_VERSION} ==="
    log "Starting at: $(date)"

    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    # Validation
    require_root
    check_dependencies
    check_architecture
    check_ram
    check_domain_config
    check_port

    # Setup
    setup_directories
    create_default_site
    create_caddyfile
    create_docker_compose
    create_env_file

    # Deployment
    pull_images
    start_services

    # Verification
    verify_installation

    # Summary
    print_summary

    ok "Caddy deployment completed successfully!"
}

main "$@"
