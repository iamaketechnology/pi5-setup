#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Nginx Web Server Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy Nginx web server with PHP-FPM support
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Nginx + PHP-FPM (optional)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[NGINX]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/nginx-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
INSTALL_DIR="/home/${TARGET_USER}/stacks/webserver"
BACKUP_DIR="${INSTALL_DIR}/backups"

# Configuration variables
NGINX_PORT="${NGINX_PORT:-8080}"
ENABLE_PHP="${ENABLE_PHP:-yes}"
SITE_NAME="${SITE_NAME:-mysite}"

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
        echo "  NGINX_PORT=8080    # Port for Nginx (default: 8080)"
        echo "  ENABLE_PHP=yes     # Enable PHP-FPM (default: yes)"
        echo "  SITE_NAME=mysite   # Site name (default: mysite)"
        echo ""
        echo "Example: sudo NGINX_PORT=9000 ENABLE_PHP=no $0"
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
        warn "Nginx requires at least 500MB of free RAM"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled by user"
        fi
    else
        ok "Available RAM: ${ram_mb}MB"
    fi
}

check_port() {
    log "Checking if port $NGINX_PORT is available..."

    if ss -tuln | grep -q ":${NGINX_PORT} "; then
        error_exit "Port $NGINX_PORT is already in use. Please choose a different port or stop the service using it."
    fi

    ok "Port $NGINX_PORT is available"
}

# =============================================================================
# SETUP SECTION
# =============================================================================

setup_directories() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "${INSTALL_DIR}"/{html,logs,config,ssl}
    mkdir -p "${BACKUP_DIR}"

    # Create site directory
    mkdir -p "${INSTALL_DIR}/sites/${SITE_NAME}"

    # Set ownership
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
    <title>Nginx sur Raspberry Pi 5</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
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
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
        }
        .info-box strong {
            color: #667eea;
        }
        .btn {
            display: inline-block;
            padding: 15px 40px;
            background: #667eea;
            color: white;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            transition: all 0.3s;
        }
        .btn:hover {
            background: #764ba2;
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>Nginx fonctionne !</h1>
        <p>Votre serveur web Nginx est maintenant opérationnel sur votre Raspberry Pi 5.</p>

        <div class="info-box">
            <strong>📁 Dossier racine :</strong> /home/pi/stacks/webserver/sites/mysite<br>
            <strong>📝 Fichier actuel :</strong> index.html<br>
            <strong>🔧 Configuration :</strong> /home/pi/stacks/webserver/config/nginx.conf
        </div>

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

create_nginx_config() {
    log "Creating Nginx configuration..."

    local php_config=""
    if [[ "$ENABLE_PHP" == "yes" ]]; then
        php_config='
        location ~ \.php$ {
            fastcgi_pass php:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            include fastcgi_params;
        }
'
    fi

    cat > "${INSTALL_DIR}/config/nginx.conf" <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    server {
        listen 80;
        server_name _;

        root /usr/share/nginx/html;
        index index.html index.htm index.php;

        location / {
            try_files \$uri \$uri/ =404;
        }
${php_config}
        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        location ~ /\.ht {
            deny all;
        }
    }
}
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/config/nginx.conf"
    ok "Nginx configuration created"
}

create_docker_compose() {
    log "Creating Docker Compose configuration..."

    local php_service=""
    local php_volume=""

    if [[ "$ENABLE_PHP" == "yes" ]]; then
        php_service='
  php:
    image: php:8.3-fpm-alpine
    container_name: webserver-php
    restart: unless-stopped
    networks:
      - webserver_network
    volumes:
      - ./sites/'${SITE_NAME}':/usr/share/nginx/html:ro
    environment:
      - TZ=Europe/Paris
    healthcheck:
      test: ["CMD", "pidof", "php-fpm"]
      interval: 30s
      timeout: 10s
      retries: 3
'
    fi

    cat > "${INSTALL_DIR}/docker-compose.yml" <<EOF
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: webserver-nginx
    restart: unless-stopped
    ports:
      - "${NGINX_PORT}:80"
    networks:
      - webserver_network
    volumes:
      - ./sites/${SITE_NAME}:/usr/share/nginx/html:ro
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs:/var/log/nginx
    environment:
      - TZ=Europe/Paris
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s
${php_service}
networks:
  webserver_network:
    name: webserver_network
    driver: bridge
EOF

    chown "${TARGET_USER}:${TARGET_USER}" "${INSTALL_DIR}/docker-compose.yml"
    ok "Docker Compose configuration created"
}

create_env_file() {
    log "Creating environment file..."

    cat > "${INSTALL_DIR}/.env" <<EOF
# Nginx Web Server Configuration
# Generated: $(date)

NGINX_PORT=${NGINX_PORT}
ENABLE_PHP=${ENABLE_PHP}
SITE_NAME=${SITE_NAME}
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
    log "Starting Nginx services..."

    cd "${INSTALL_DIR}"
    su - "${TARGET_USER}" -c "cd ${INSTALL_DIR} && docker compose up -d"

    # Wait for services to be healthy
    log "Waiting for services to be ready..."
    sleep 5

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker ps | grep -q "webserver-nginx.*healthy"; then
            ok "Nginx is healthy"
            break
        fi

        attempt=$((attempt + 1))
        if [ $attempt -eq $max_attempts ]; then
            error_exit "Nginx failed to start properly"
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

    # Check containers
    if ! docker ps | grep -q "webserver-nginx"; then
        error_exit "Nginx container is not running"
    fi

    if [[ "$ENABLE_PHP" == "yes" ]]; then
        if ! docker ps | grep -q "webserver-php"; then
            error_exit "PHP-FPM container is not running"
        fi
    fi

    # Check web server response
    local response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${NGINX_PORT} || echo "000")
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

    cat <<EOF

╔════════════════════════════════════════════════════════════════════════════╗
║                    NGINX DEPLOYMENT SUCCESSFUL                             ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 Installation Summary:
  ✓ Nginx version: $(docker exec webserver-nginx nginx -v 2>&1 | cut -d/ -f2)
  ✓ PHP-FPM: ${ENABLE_PHP}
  ✓ Port: ${NGINX_PORT}
  ✓ Site name: ${SITE_NAME}

🌐 Access URLs:
  • Local: http://localhost:${NGINX_PORT}
  • Network: http://${ip_address}:${NGINX_PORT}
  • Hostname: http://$(hostname).local:${NGINX_PORT}

📁 Important Paths:
  • Site files: ${INSTALL_DIR}/sites/${SITE_NAME}/
  • Configuration: ${INSTALL_DIR}/config/nginx.conf
  • Logs: ${INSTALL_DIR}/logs/
  • Docker Compose: ${INSTALL_DIR}/docker-compose.yml

🔧 Quick Commands:
  # View logs
  docker logs -f webserver-nginx

  # Restart services
  cd ${INSTALL_DIR} && docker compose restart

  # Stop services
  cd ${INSTALL_DIR} && docker compose down

  # Reload Nginx config
  docker exec webserver-nginx nginx -s reload

📝 Next Steps:
  1. Upload your website files to: ${INSTALL_DIR}/sites/${SITE_NAME}/
  2. Install Traefik for HTTPS:
     curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash
  3. Integrate with Traefik:
     curl -fsSL https://raw.githubusercontent.com/.../02-integrate-webserver.sh | sudo bash

📖 Documentation: https://github.com/iamaketechnology/pi5-setup

EOF

    log "Installation log saved to: $LOG_FILE"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    log "=== Nginx Web Server Deployment v${SCRIPT_VERSION} ==="
    log "Starting at: $(date)"

    # Setup logging
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    # Validation
    require_root
    check_dependencies
    check_architecture
    check_ram
    check_port

    # Setup
    setup_directories
    create_default_site
    create_nginx_config
    create_docker_compose
    create_env_file

    # Deployment
    pull_images
    start_services

    # Verification
    verify_installation

    # Summary
    print_summary

    ok "Nginx deployment completed successfully!"
}

main "$@"
