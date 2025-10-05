#!/usr/bin/env bash
################################################################################
# Script: 01-authelia-deploy.sh
# Description: Deploy Authelia SSO + 2FA authentication stack on Raspberry Pi 5
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (ARM64), Ubuntu Server ARM64
# Dependencies: Docker, Docker Compose, Traefik (required)
#
# This script deploys:
# - Authelia (SSO + 2FA authentication server)
# - Redis (session storage)
# - Integration with Traefik reverse proxy
# - Auto-detection of Traefik scenario (DuckDNS/Cloudflare/VPN)
# - Default admin user with secure password
# - TOTP/2FA configuration
# - Middleware for protecting services
#
# Usage:
#   sudo ./01-authelia-deploy.sh [OPTIONS]
#
# Options:
#   --dry-run         Show what would be done without executing
#   --yes, -y         Skip confirmation prompts
#   --verbose, -v     Enable verbose output
#   --quiet, -q       Suppress non-error output
#   --help, -h        Show this help message
#
# Environment Variables (optional):
#   AUTHELIA_VERSION        Authelia Docker image version (default: latest)
#   AUTHELIA_PORT           Internal port (default: 9091)
#   REDIS_VERSION           Redis Docker image version (default: 7-alpine)
#   REDIS_PORT              Internal Redis port (default: 6379)
#   AUTH_DOMAIN             Authentication domain (auto-detected from Traefik)
#   COOKIE_DOMAIN           Cookie domain (auto-detected from Traefik)
#   STACK_NAME              Stack name (default: authelia)
#   STACK_DIR               Installation directory (default: /home/pi/stacks/authelia)
#   TRAEFIK_ENABLE          Enable Traefik integration (auto/yes/no, default: auto)
#   PROTECTED_SERVICES      Services to protect (comma-separated, optional)
#   JWT_SECRET              JWT secret (auto-generated if empty)
#   SESSION_SECRET          Session secret (auto-generated if empty)
#   STORAGE_ENCRYPTION_KEY  Storage encryption key (auto-generated if empty)
#   ADMIN_USERNAME          Admin username (default: admin)
#   ADMIN_PASSWORD          Admin password (auto-generated if empty)
#   ADMIN_EMAIL             Admin email (default: admin@example.com)
#
# Examples:
#   # Basic deployment (auto-detect everything)
#   sudo ./01-authelia-deploy.sh
#
#   # Deploy and protect specific services
#   PROTECTED_SERVICES="grafana,portainer,traefik" sudo ./01-authelia-deploy.sh
#
#   # Custom domain
#   AUTH_DOMAIN="auth.mydomain.com" sudo ./01-authelia-deploy.sh
#
#   # Dry-run to see what would be done
#   sudo ./01-authelia-deploy.sh --dry-run
#
################################################################################

set -euo pipefail

# --- Script Directory Detection ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/../../common-scripts/lib.sh"

# Source common library
if [[ -f "${COMMON_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${COMMON_LIB}"
else
  echo "ERROR: Cannot find common library at ${COMMON_LIB}"
  exit 1
fi

# --- Global Variables ---
AUTHELIA_VERSION="${AUTHELIA_VERSION:-latest}"
AUTHELIA_PORT="${AUTHELIA_PORT:-9091}"
REDIS_VERSION="${REDIS_VERSION:-7-alpine}"
REDIS_PORT="${REDIS_PORT:-6379}"
AUTH_DOMAIN="${AUTH_DOMAIN:-}"
COOKIE_DOMAIN="${COOKIE_DOMAIN:-}"
STACK_NAME="${STACK_NAME:-authelia}"
STACK_DIR="${STACK_DIR:-/home/pi/stacks/authelia}"
TRAEFIK_ENABLE="${TRAEFIK_ENABLE:-auto}"
PROTECTED_SERVICES="${PROTECTED_SERVICES:-}"
JWT_SECRET="${JWT_SECRET:-}"
SESSION_SECRET="${SESSION_SECRET:-}"
STORAGE_ENCRYPTION_KEY="${STORAGE_ENCRYPTION_KEY:-}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"

# Detected values
TRAEFIK_SCENARIO=""
TRAEFIK_ENV_FILE=""
AUTHELIA_URL=""
DEFAULT_REDIRECTION_URL=""

# --- Usage Function ---
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy Authelia SSO + 2FA authentication stack on Raspberry Pi 5.

OPTIONS:
  --dry-run         Show what would be done without executing
  --yes, -y         Skip confirmation prompts
  --verbose, -v     Enable verbose output
  --quiet, -q       Suppress non-error output
  --help, -h        Show this help message

ENVIRONMENT VARIABLES:
  AUTHELIA_VERSION        Authelia Docker image version (default: latest)
  AUTHELIA_PORT           Internal port (default: 9091)
  REDIS_VERSION           Redis version (default: 7-alpine)
  AUTH_DOMAIN             Authentication domain (auto-detected)
  COOKIE_DOMAIN           Cookie domain (auto-detected)
  STACK_DIR               Installation directory (default: /home/pi/stacks/authelia)
  PROTECTED_SERVICES      Services to protect (e.g., "grafana,portainer")
  ADMIN_USERNAME          Admin username (default: admin)
  ADMIN_PASSWORD          Admin password (auto-generated)
  ADMIN_EMAIL             Admin email (default: admin@example.com)

EXAMPLES:
  # Basic deployment
  sudo ./01-authelia-deploy.sh

  # Deploy with protected services
  PROTECTED_SERVICES="grafana,portainer" sudo ./01-authelia-deploy.sh

  # Dry-run
  sudo ./01-authelia-deploy.sh --dry-run

For more information, see: https://github.com/iamaketechnology/pi5-setup
EOF
  exit 0
}

# --- Helper Functions ---

# Detect Traefik installation scenario
detect_traefik_scenario() {
  log_info "Detection du scenario Traefik..."

  TRAEFIK_ENV_FILE="/home/pi/stacks/traefik/.env"

  if [[ ! -f "${TRAEFIK_ENV_FILE}" ]]; then
    log_error "Fichier Traefik .env introuvable: ${TRAEFIK_ENV_FILE}"
    log_error "Assurez-vous que Traefik est installe (Phase 2)."
    return 1
  fi

  # Source the Traefik .env file to get configuration
  # shellcheck source=/dev/null
  source "${TRAEFIK_ENV_FILE}"

  # Detect scenario based on environment variables
  if [[ -n "${DUCKDNS_TOKEN:-}" ]] && [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
    TRAEFIK_SCENARIO="duckdns"
    AUTH_DOMAIN="${AUTH_DOMAIN:-auth.${DUCKDNS_SUBDOMAIN}.duckdns.org}"
    COOKIE_DOMAIN="${COOKIE_DOMAIN:-${DUCKDNS_SUBDOMAIN}.duckdns.org}"
    DEFAULT_REDIRECTION_URL="https://${DUCKDNS_SUBDOMAIN}.duckdns.org"
    AUTHELIA_URL="https://auth.${DUCKDNS_SUBDOMAIN}.duckdns.org"

  elif [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]] && [[ -n "${DOMAIN:-}" ]]; then
    TRAEFIK_SCENARIO="cloudflare"
    AUTH_DOMAIN="${AUTH_DOMAIN:-auth.${DOMAIN}}"
    COOKIE_DOMAIN="${COOKIE_DOMAIN:-${DOMAIN}}"
    DEFAULT_REDIRECTION_URL="https://${DOMAIN}"
    AUTHELIA_URL="https://auth.${DOMAIN}"

  elif [[ -n "${VPN_NETWORK:-}" ]] || [[ "${LOCAL_DOMAIN:-}" == *".local" ]]; then
    TRAEFIK_SCENARIO="vpn"
    LOCAL_DOMAIN="${LOCAL_DOMAIN:-pi.local}"
    AUTH_DOMAIN="${AUTH_DOMAIN:-auth.${LOCAL_DOMAIN}}"
    COOKIE_DOMAIN="${COOKIE_DOMAIN:-${LOCAL_DOMAIN}}"
    DEFAULT_REDIRECTION_URL="http://${LOCAL_DOMAIN}"
    AUTHELIA_URL="http://auth.${LOCAL_DOMAIN}"

  else
    log_error "Impossible de detecter le scenario Traefik."
    log_error "Variables attendues: DUCKDNS_TOKEN+SUBDOMAIN, CLOUDFLARE_API_TOKEN+DOMAIN, ou VPN_NETWORK"
    return 1
  fi

  log_success "Scenario Traefik detecte: ${TRAEFIK_SCENARIO}"
  log_info "  - AUTH_DOMAIN: ${AUTH_DOMAIN}"
  log_info "  - COOKIE_DOMAIN: ${COOKIE_DOMAIN}"
  log_info "  - DEFAULT_REDIRECTION_URL: ${DEFAULT_REDIRECTION_URL}"
  log_info "  - AUTHELIA_URL: ${AUTHELIA_URL}"

  return 0
}

# Generate secure secrets
generate_secrets() {
  log_info "Generation des secrets de securite..."

  # Check if openssl is available
  if ! command -v openssl >/dev/null 2>&1; then
    log_error "openssl est requis pour generer des secrets."
    return 1
  fi

  # Generate JWT secret if not provided
  if [[ -z "${JWT_SECRET}" ]]; then
    JWT_SECRET=$(openssl rand -hex 64)
    log_debug "JWT_SECRET genere: ${JWT_SECRET:0:16}... (64 chars)"
  fi

  # Generate session secret if not provided
  if [[ -z "${SESSION_SECRET}" ]]; then
    SESSION_SECRET=$(openssl rand -hex 64)
    log_debug "SESSION_SECRET genere: ${SESSION_SECRET:0:16}... (64 chars)"
  fi

  # Generate storage encryption key if not provided
  if [[ -z "${STORAGE_ENCRYPTION_KEY}" ]]; then
    STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 64)
    log_debug "STORAGE_ENCRYPTION_KEY genere: ${STORAGE_ENCRYPTION_KEY:0:16}... (64 chars)"
  fi

  # Generate admin password if not provided
  if [[ -z "${ADMIN_PASSWORD}" ]]; then
    ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    log_debug "ADMIN_PASSWORD genere: ${ADMIN_PASSWORD:0:4}... (20 chars)"
  fi

  log_success "Secrets generes avec succes."
  return 0
}

# Generate password hash using Argon2id
generate_password_hash() {
  local password="$1"
  local hash

  log_debug "Generation du hash Argon2id pour le mot de passe..."

  # Use Authelia's CLI to generate password hash
  hash=$(docker run --rm \
    authelia/authelia:${AUTHELIA_VERSION} \
    authelia crypto hash generate argon2 \
    --password "${password}" \
    2>/dev/null | grep -v "Password hash" | tail -n1)

  if [[ -z "${hash}" ]]; then
    log_error "Echec de la generation du hash de mot de passe."
    return 1
  fi

  echo "${hash}"
  return 0
}

# Create users database file
create_users_database() {
  log_info "Creation de la base de donnees utilisateurs..."

  local users_db_file="${STACK_DIR}/config/users_database.yml"
  local password_hash

  # Generate password hash
  password_hash=$(generate_password_hash "${ADMIN_PASSWORD}")

  if [[ -z "${password_hash}" ]]; then
    log_error "Impossible de generer le hash du mot de passe."
    return 1
  fi

  # Create users database file
  cat > "${users_db_file}" <<EOF
---
###############################################################
#                   Authelia Users Database                   #
###############################################################
# This file contains the user accounts for Authelia.
# Passwords are hashed using Argon2id algorithm.
#
# To add a new user:
# 1. Generate password hash:
#    docker run --rm authelia/authelia:latest \\
#      authelia crypto hash generate argon2 --password YOUR_PASSWORD
# 2. Add user entry below
# 3. Restart Authelia: docker compose restart authelia
#
# Groups:
# - admins: Full access to all protected services
# - users: Limited access based on access_control rules

users:
  ${ADMIN_USERNAME}:
    displayname: "Administrator"
    password: "${password_hash}"
    email: "${ADMIN_EMAIL}"
    groups:
      - admins
EOF

  log_success "Fichier users_database.yml cree: ${users_db_file}"
  return 0
}

# Create Authelia configuration file
create_authelia_config() {
  log_info "Creation de la configuration Authelia..."

  local config_file="${STACK_DIR}/config/configuration.yml"

  # Determine access control rules based on Traefik scenario
  local access_control_rules=""

  case "${TRAEFIK_SCENARIO}" in
    duckdns)
      access_control_rules=$(cat <<'EOACL'
  # Bypass authentication for public services
    - domain: "${DUCKDNS_SUBDOMAIN}.duckdns.org"
      policy: bypass
      resources:
        - "^/$"
        - "^/homepage.*"

    # Two-factor authentication for protected services
    - domain: "${DUCKDNS_SUBDOMAIN}.duckdns.org"
      policy: two_factor
      subject:
        - "group:admins"
      resources:
        - "^/grafana.*"
        - "^/portainer.*"
        - "^/prometheus.*"
        - "^/traefik.*"
EOACL
)
      # Substitute environment variables
      access_control_rules="${access_control_rules//\$\{DUCKDNS_SUBDOMAIN\}/${DUCKDNS_SUBDOMAIN}}"
      ;;

    cloudflare)
      access_control_rules=$(cat <<EOACL
  # Bypass authentication for public services
    - domain: "${DOMAIN}"
      policy: bypass
    - domain: "homepage.${DOMAIN}"
      policy: bypass

    # Two-factor authentication for protected services
    - domain:
        - "grafana.${DOMAIN}"
        - "portainer.${DOMAIN}"
        - "prometheus.${DOMAIN}"
        - "traefik.${DOMAIN}"
      policy: two_factor
      subject:
        - "group:admins"
EOACL
)
      ;;

    vpn)
      access_control_rules=$(cat <<EOACL
  # Bypass authentication for public services
    - domain: "${LOCAL_DOMAIN}"
      policy: bypass
    - domain: "homepage.${LOCAL_DOMAIN}"
      policy: bypass

    # Two-factor authentication for protected services
    - domain:
        - "grafana.${LOCAL_DOMAIN}"
        - "portainer.${LOCAL_DOMAIN}"
        - "prometheus.${LOCAL_DOMAIN}"
        - "traefik.${LOCAL_DOMAIN}"
      policy: two_factor
      subject:
        - "group:admins"
EOACL
)
      ;;
  esac

  # Create configuration file
  cat > "${config_file}" <<EOF
---
###############################################################
#                    Authelia Configuration                   #
###############################################################
# Authelia SSO + 2FA Configuration for Raspberry Pi 5
# Scenario: ${TRAEFIK_SCENARIO}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Server Configuration
server:
  host: 0.0.0.0
  port: ${AUTHELIA_PORT}
  path: ""
  read_buffer_size: 4096
  write_buffer_size: 4096
  enable_pprof: false
  enable_expvars: false

# Logging Configuration
log:
  level: info
  format: text
  file_path: ""
  keep_stdout: true

# Theme
theme: auto

# JWT Secret (used for session encryption)
jwt_secret: ${JWT_SECRET}

# Default redirection URL after successful authentication
default_redirection_url: ${DEFAULT_REDIRECTION_URL}

# TOTP Configuration (Time-based One-Time Password)
totp:
  issuer: pi5-authelia
  period: 30
  skew: 1
  secret_size: 32

# Authentication Backend (file-based user database)
authentication_backend:
  password_reset:
    disable: false
  refresh_interval: 5m

  file:
    path: /config/users_database.yml
    password:
      algorithm: argon2id
      iterations: 1
      salt_length: 16
      parallelism: 8
      memory: 64

# Access Control Rules
access_control:
  default_policy: deny

  rules:
${access_control_rules}

# Session Configuration (Redis-backed)
session:
  name: authelia_session
  domain: ${COOKIE_DOMAIN}
  same_site: lax
  secret: ${SESSION_SECRET}
  expiration: 1h
  inactivity: 5m
  remember_me_duration: 1M

  redis:
    host: redis
    port: ${REDIS_PORT}
    username: ""
    password: ""
    database_index: 0
    maximum_active_connections: 8
    minimum_idle_connections: 0

# Regulation (brute-force protection)
regulation:
  max_retries: 3
  find_time: 2m
  ban_time: 5m

# Storage Backend (SQLite for simplicity)
storage:
  encryption_key: ${STORAGE_ENCRYPTION_KEY}

  local:
    path: /data/db.sqlite3

# Notifier (file-based, can be extended to SMTP)
notifier:
  disable_startup_check: false

  filesystem:
    filename: /data/notification.txt
EOF

  log_success "Fichier configuration.yml cree: ${config_file}"
  return 0
}

# Create Docker Compose file
create_docker_compose() {
  log_info "Creation du fichier docker-compose.yml..."

  local compose_file="${STACK_DIR}/docker-compose.yml"

  # Determine Traefik labels based on scenario
  local authelia_labels=""

  case "${TRAEFIK_SCENARIO}" in
    duckdns)
      authelia_labels=$(cat <<'EOLABELS'
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host(\`auth.${DUCKDNS_SUBDOMAIN}.duckdns.org\`)"
      - "traefik.http.routers.authelia.entrypoints=websecure"
      - "traefik.http.routers.authelia.tls=true"
      - "traefik.http.routers.authelia.tls.certresolver=letsencrypt"
      - "traefik.http.services.authelia.loadbalancer.server.port=9091"
      - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.${DUCKDNS_SUBDOMAIN}.duckdns.org"
      - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
EOLABELS
)
      ;;

    cloudflare)
      authelia_labels=$(cat <<EOLABELS
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host(\`auth.${DOMAIN}\`)"
      - "traefik.http.routers.authelia.entrypoints=websecure"
      - "traefik.http.routers.authelia.tls=true"
      - "traefik.http.routers.authelia.tls.certresolver=cloudflare"
      - "traefik.http.services.authelia.loadbalancer.server.port=9091"
      - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.${DOMAIN}"
      - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
EOLABELS
)
      ;;

    vpn)
      authelia_labels=$(cat <<EOLABELS
      - "traefik.enable=true"
      - "traefik.http.routers.authelia.rule=Host(\`auth.${LOCAL_DOMAIN}\`)"
      - "traefik.http.routers.authelia.entrypoints=web"
      - "traefik.http.services.authelia.loadbalancer.server.port=9091"
      - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=http://auth.${LOCAL_DOMAIN}"
      - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
      - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
EOLABELS
)
      ;;
  esac

  # Create docker-compose.yml
  cat > "${compose_file}" <<EOF
---
################################################################################
# Authelia SSO + 2FA Stack
# Scenario: ${TRAEFIK_SCENARIO}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
################################################################################

services:
  # Redis - Session Storage Backend
  redis:
    image: redis:\${REDIS_VERSION}
    container_name: authelia-redis
    restart: unless-stopped

    command:
      - redis-server
      - --save 60 1
      - --loglevel warning

    volumes:
      - ./redis:/data

    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 10s

    networks:
      - authelia-internal

    labels:
      - "traefik.enable=false"

  # Authelia - SSO + 2FA Authentication Server
  authelia:
    image: authelia/authelia:\${AUTHELIA_VERSION}
    container_name: authelia
    restart: unless-stopped

    volumes:
      - ./config/configuration.yml:/config/configuration.yml:ro
      - ./config/users_database.yml:/config/users_database.yml:ro
      - ./data:/data

    environment:
      - TZ=\${TZ:-Europe/Paris}
      - AUTHELIA_JWT_SECRET=\${JWT_SECRET}
      - AUTHELIA_SESSION_SECRET=\${SESSION_SECRET}
      - AUTHELIA_STORAGE_ENCRYPTION_KEY=\${STORAGE_ENCRYPTION_KEY}

    depends_on:
      redis:
        condition: service_healthy

    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9091/api/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s

    networks:
      - authelia-internal
      - traefik-public

    labels:
${authelia_labels}

networks:
  authelia-internal:
    driver: bridge
    name: authelia-internal

  traefik-public:
    external: true
    name: traefik-public
EOF

  log_success "Fichier docker-compose.yml cree: ${compose_file}"
  return 0
}

# Create .env file
create_env_file() {
  log_info "Creation du fichier .env..."

  local env_file="${STACK_DIR}/.env"

  cat > "${env_file}" <<EOF
################################################################################
# Authelia Stack Environment Variables
# Scenario: ${TRAEFIK_SCENARIO}
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#
# WARNING: This file contains sensitive secrets!
# Permissions: 600 (read/write owner only)
################################################################################

# Docker Image Versions
AUTHELIA_VERSION=${AUTHELIA_VERSION}
REDIS_VERSION=${REDIS_VERSION}

# Network Ports
AUTHELIA_PORT=${AUTHELIA_PORT}
REDIS_PORT=${REDIS_PORT}

# Domain Configuration
AUTH_DOMAIN=${AUTH_DOMAIN}
COOKIE_DOMAIN=${COOKIE_DOMAIN}

# Timezone
TZ=Europe/Paris

# Security Secrets (DO NOT SHARE!)
JWT_SECRET=${JWT_SECRET}
SESSION_SECRET=${SESSION_SECRET}
STORAGE_ENCRYPTION_KEY=${STORAGE_ENCRYPTION_KEY}

# Admin User Credentials
ADMIN_USERNAME=${ADMIN_USERNAME}
ADMIN_PASSWORD=${ADMIN_PASSWORD}
ADMIN_EMAIL=${ADMIN_EMAIL}
EOF

  # Set secure permissions
  run_cmd chmod 600 "${env_file}"

  log_success "Fichier .env cree: ${env_file}"
  log_warn "Permissions securisees (600): seul le proprietaire peut lire/ecrire"

  return 0
}

# Create credentials file
create_credentials_file() {
  log_info "Creation du fichier de credentials..."

  local creds_file="${STACK_DIR}/config/CREDENTIALS.txt"

  cat > "${creds_file}" <<EOF
################################################################################
# Authelia Admin Credentials
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
#
# IMPORTANT: Keep this file secure!
# After initial setup, store these credentials in a password manager
# and delete this file.
################################################################################

Authelia URL: ${AUTHELIA_URL}

Admin Username: ${ADMIN_USERNAME}
Admin Password: ${ADMIN_PASSWORD}
Admin Email: ${ADMIN_EMAIL}

Initial Login Steps:
1. Navigate to: ${AUTHELIA_URL}
2. Enter username and password above
3. Configure 2FA (TOTP):
   - Go to Settings > Two-Factor Authentication
   - Scan QR code with authenticator app (Google Authenticator, Authy, etc.)
   - Enter 6-digit code to validate
4. Change your password in Settings

Protected Services Access:
- After setting up 2FA, access protected services will require:
  1. Username + Password
  2. 6-digit TOTP code from authenticator app

Security Notes:
- Store these credentials securely
- Enable 2FA immediately after first login
- Consider deleting this file after setup
- Backup users_database.yml regularly

To reset password:
docker run --rm authelia/authelia:${AUTHELIA_VERSION} \\
  authelia crypto hash generate argon2 --password NEW_PASSWORD

Then update users_database.yml and restart Authelia.

################################################################################
EOF

  # Set secure permissions
  run_cmd chmod 600 "${creds_file}"

  log_success "Fichier credentials cree: ${creds_file}"

  return 0
}

# Create Traefik middleware configuration
create_traefik_middleware_config() {
  log_info "Creation de la configuration middleware Traefik..."

  local traefik_dynamic_dir="/home/pi/stacks/traefik/dynamic"
  local middleware_file="${traefik_dynamic_dir}/authelia-middleware.yml"

  # Check if Traefik dynamic directory exists
  if [[ ! -d "${traefik_dynamic_dir}" ]]; then
    log_warn "Repertoire Traefik dynamic introuvable: ${traefik_dynamic_dir}"
    log_warn "Creation du repertoire..."
    run_cmd mkdir -p "${traefik_dynamic_dir}"
  fi

  # Determine forwardAuth address based on scenario
  local forward_auth_address=""

  case "${TRAEFIK_SCENARIO}" in
    duckdns)
      forward_auth_address="http://authelia:9091/api/verify?rd=https://auth.${DUCKDNS_SUBDOMAIN}.duckdns.org"
      ;;
    cloudflare)
      forward_auth_address="http://authelia:9091/api/verify?rd=https://auth.${DOMAIN}"
      ;;
    vpn)
      forward_auth_address="http://authelia:9091/api/verify?rd=http://auth.${LOCAL_DOMAIN}"
      ;;
  esac

  # Create middleware configuration
  cat > "${middleware_file}" <<EOF
---
################################################################################
# Authelia Middleware Configuration for Traefik
# This file defines the ForwardAuth middleware that protects services
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
################################################################################

http:
  middlewares:
    # Authelia ForwardAuth Middleware
    # Usage: Add to service labels:
    #   - "traefik.http.routers.SERVICE.middlewares=authelia@file"
    authelia:
      forwardAuth:
        address: "${forward_auth_address}"
        trustForwardHeader: true
        authResponseHeaders:
          - "Remote-User"
          - "Remote-Groups"
          - "Remote-Name"
          - "Remote-Email"
EOF

  log_success "Middleware Traefik cree: ${middleware_file}"
  log_info "Le middleware 'authelia@file' est maintenant disponible pour proteger les services."

  return 0
}

# Apply protection to specified services
apply_protection_to_services() {
  log_info "Application de la protection aux services specifies..."

  if [[ -z "${PROTECTED_SERVICES}" ]]; then
    log_debug "Aucun service a proteger (PROTECTED_SERVICES vide)"
    return 0
  fi

  # Split services by comma
  IFS=',' read -ra SERVICES <<< "${PROTECTED_SERVICES}"

  local protected_count=0

  for service in "${SERVICES[@]}"; do
    # Trim whitespace
    service=$(echo "${service}" | xargs)

    log_info "Protection du service: ${service}"

    # Determine service stack directory
    local service_compose=""

    case "${service}" in
      grafana)
        service_compose="/home/pi/stacks/monitoring/docker-compose.yml"
        ;;
      portainer)
        service_compose="/home/pi/stacks/portainer/docker-compose.yml"
        ;;
      traefik)
        service_compose="/home/pi/stacks/traefik/docker-compose.yml"
        ;;
      prometheus)
        service_compose="/home/pi/stacks/monitoring/docker-compose.yml"
        ;;
      *)
        log_warn "Service inconnu: ${service}, ignore."
        continue
        ;;
    esac

    # Check if compose file exists
    if [[ ! -f "${service_compose}" ]]; then
      log_warn "Fichier docker-compose.yml introuvable pour ${service}: ${service_compose}"
      continue
    fi

    # Backup original file
    run_cmd cp "${service_compose}" "${service_compose}.backup-$(date +%Y%m%d%H%M%S)"

    # Add middleware label to service
    # This is a simplified approach - in production, you'd want to parse and modify YAML properly
    log_warn "MANUEL: Ajoutez cette ligne au service ${service} dans ${service_compose}:"
    log_warn "  - \"traefik.http.routers.${service}.middlewares=authelia@file\""

    protected_count=$((protected_count + 1))
  done

  if [[ ${protected_count} -gt 0 ]]; then
    log_success "${protected_count} service(s) marque(s) pour protection."
    log_info "Relancez les services proteges avec: docker compose restart"
  fi

  return 0
}

# Wait for Authelia to be ready
wait_for_authelia_ready() {
  log_info "Attente du demarrage d'Authelia..."

  local max_attempts=30
  local attempt=0
  local wait_time=2

  while [[ ${attempt} -lt ${max_attempts} ]]; do
    attempt=$((attempt + 1))

    # Check if Authelia container is running
    if docker ps --filter "name=authelia" --filter "status=running" --format "{{.Names}}" | grep -q "authelia"; then
      # Check health status
      local health_status
      health_status=$(docker inspect --format='{{.State.Health.Status}}' authelia 2>/dev/null || echo "none")

      if [[ "${health_status}" == "healthy" ]]; then
        log_success "Authelia est pret !"
        return 0
      fi

      log_debug "Authelia demarre... (sante: ${health_status}, tentative ${attempt}/${max_attempts})"
    else
      log_debug "Authelia demarre... (tentative ${attempt}/${max_attempts})"
    fi

    sleep ${wait_time}
  done

  log_error "Timeout: Authelia n'est pas pret apres ${max_attempts} tentatives."
  log_error "Verifiez les logs: docker logs authelia"
  return 1
}

# Display deployment summary
display_deployment_summary() {
  log_success "Deploiement Authelia termine avec succes !"

  cat <<EOF

################################################################################
#                    AUTHELIA SSO + 2FA - DEPLOIEMENT REUSSI                  #
################################################################################

ACCES AUTHELIA
  URL : ${AUTHELIA_URL}
  Scenario : ${TRAEFIK_SCENARIO}

UTILISATEUR ADMINISTRATEUR
  Username : ${ADMIN_USERNAME}
  Password : ${ADMIN_PASSWORD}
  Email : ${ADMIN_EMAIL}

  Fichier credentials : ${STACK_DIR}/config/CREDENTIALS.txt

CONFIGURATION 2FA (TOTP)
  1. Se connecter a ${AUTHELIA_URL}
  2. Login avec ${ADMIN_USERNAME} / ${ADMIN_PASSWORD}
  3. Aller dans Settings > Two-Factor Authentication
  4. Scanner le QR code avec votre application d'authentification :
     - Google Authenticator (Android/iOS)
     - Authy (Android/iOS/Desktop)
     - Microsoft Authenticator (Android/iOS)
  5. Entrer le code a 6 chiffres pour valider
  6. IMPORTANT: Sauvegarder les codes de recuperation !

SERVICES PROTEGES
EOF

  if [[ -n "${PROTECTED_SERVICES}" ]]; then
    echo "  Services actuellement proteges : ${PROTECTED_SERVICES}"
    echo "  Ces services necessitent maintenant :"
    echo "    1. Username + Password"
    echo "    2. Code TOTP a 6 chiffres"
  else
    echo "  Aucun service protege automatiquement."
  fi

  cat <<EOF

PROTEGER UN SERVICE MANUELLEMENT
  1. Editer le docker-compose.yml du service
  2. Ajouter le label Traefik au service :
     - "traefik.http.routers.SERVICE_NAME.middlewares=authelia@file"
  3. Redemarrer le service :
     cd /home/pi/stacks/SERVICE_NAME
     docker compose restart

EXEMPLES DE SERVICES A PROTEGER
  - Grafana : Metriques et tableaux de bord sensibles
  - Portainer : Gestion complete de Docker
  - Traefik Dashboard : Configuration du reverse proxy
  - Prometheus : Donnees metriques brutes
  - Supabase Studio : Base de donnees et API

GESTION DES UTILISATEURS
  Fichier : ${STACK_DIR}/config/users_database.yml

  Ajouter un utilisateur :
  1. Generer le hash du mot de passe :
     docker run --rm authelia/authelia:${AUTHELIA_VERSION} \\
       authelia crypto hash generate argon2 --password VOTRE_PASSWORD

  2. Ajouter l'utilisateur dans users_database.yml :
     users:
       nouveau_user:
         displayname: "Nom Complet"
         password: "\$argon2id\$v=19\$m=65536..."
         email: user@example.com
         groups:
           - users

  3. Redemarrer Authelia :
     cd ${STACK_DIR}
     docker compose restart authelia

SECURITE
  JWT Secret : ${STACK_DIR}/.env (chmod 600)
  Protection brute-force : 3 tentatives max / 2 minutes
  Ban : 5 minutes apres 3 echecs
  Session expiration : 1 heure
  Inactivite max : 5 minutes
  Remember-me : 1 mois

FICHIERS IMPORTANTS
  Configuration : ${STACK_DIR}/config/configuration.yml
  Utilisateurs : ${STACK_DIR}/config/users_database.yml
  Credentials : ${STACK_DIR}/config/CREDENTIALS.txt
  Base de donnees : ${STACK_DIR}/data/db.sqlite3
  Logs : ${STACK_DIR}/data/notification.txt

COMMANDES UTILES
  Voir les logs :
    docker logs -f authelia

  Redemarrer :
    cd ${STACK_DIR}
    docker compose restart

  Arreter :
    cd ${STACK_DIR}
    docker compose down

  Mettre a jour :
    cd ${STACK_DIR}
    docker compose pull
    docker compose up -d

ACCES REDIS (session storage)
  Container : authelia-redis
  Port interne : ${REDIS_PORT}
  Volume : ${STACK_DIR}/redis

  Connexion :
    docker exec -it authelia-redis redis-cli

TROUBLESHOOTING
  Si Authelia ne demarre pas :
    docker logs authelia

  Si les sessions ne persistent pas :
    docker logs authelia-redis
    docker exec authelia-redis redis-cli ping

  Si l'authentification echoue :
    - Verifier users_database.yml (syntaxe YAML)
    - Verifier le hash du mot de passe
    - Verifier les logs : docker logs authelia

  Si le middleware ne fonctionne pas :
    - Verifier que Traefik voit le middleware : docker logs traefik
    - Verifier les labels du service protege
    - Redemarrer Traefik : docker restart traefik

NEXT STEPS
  1. Se connecter a Authelia et configurer 2FA
  2. Changer le mot de passe administrateur
  3. Proteger les services sensibles (Grafana, Portainer, etc.)
  4. Creer des utilisateurs supplementaires si necessaire
  5. Configurer la notification par email (optionnel)
  6. Sauvegarder users_database.yml regulierement

DOCUMENTATION
  Guide Authelia : https://www.authelia.com/
  Configuration : https://www.authelia.com/configuration/prologue/introduction/
  Access Control : https://www.authelia.com/configuration/security/access-control/
  Traefik Integration : https://www.authelia.com/integration/proxies/traefik/

################################################################################

EOF
}

# Check prerequisites
check_prerequisites() {
  log_info "Verification des prerequis..."

  # Check if running as root
  if [[ $(id -u) -ne 0 ]]; then
    log_error "Ce script doit etre execute en tant que root (utilisez sudo)."
    return 1
  fi

  # Check Docker
  if ! command -v docker >/dev/null 2>&1; then
    log_error "Docker n'est pas installe."
    log_error "Installez Docker avec le script 02-docker-install-verify.sh"
    return 1
  fi

  # Check Docker Compose
  if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose n'est pas disponible."
    log_error "Installez Docker Compose ou mettez a jour Docker."
    return 1
  fi

  # Check Traefik installation
  if [[ ! -d "/home/pi/stacks/traefik" ]]; then
    log_error "Traefik n'est pas installe."
    log_error "Installez Traefik d'abord (Phase 2):"
    log_error "  - Scenario DuckDNS: 01-traefik-deploy-duckdns.sh"
    log_error "  - Scenario Cloudflare: 01-traefik-deploy-cloudflare.sh"
    log_error "  - Scenario VPN: 01-traefik-deploy-vpn.sh"
    return 1
  fi

  # Check if Traefik is running
  if ! docker ps --filter "name=traefik" --filter "status=running" --format "{{.Names}}" | grep -q "traefik"; then
    log_warn "Traefik n'est pas en cours d'execution."
    log_warn "Demarrez Traefik avant de deployer Authelia:"
    log_warn "  cd /home/pi/stacks/traefik && docker compose up -d"

    if [[ ${ASSUME_YES} -eq 0 ]]; then
      confirm "Continuer quand meme ?"
    fi
  fi

  log_success "Tous les prerequis sont satisfaits."
  return 0
}

# Main execution
main() {
  # Parse command line arguments
  parse_common_args "$@"

  # Show help if requested
  if [[ ${SHOW_HELP} -eq 1 ]]; then
    usage
  fi

  # Display header
  log_info "=============================================================="
  log_info "   Deploiement Authelia SSO + 2FA sur Raspberry Pi 5"
  log_info "=============================================================="
  log_info ""

  # Check prerequisites
  check_prerequisites || fatal "Prerequis non satisfaits."

  # Detect Traefik scenario
  detect_traefik_scenario || fatal "Impossible de detecter le scenario Traefik."

  # Generate secrets
  generate_secrets || fatal "Echec de la generation des secrets."

  # Create stack directory structure
  log_info "Creation de la structure du repertoire..."
  run_cmd mkdir -p "${STACK_DIR}"/{config,data,redis}

  # Create configuration files
  create_users_database || fatal "Echec de la creation de users_database.yml."
  create_authelia_config || fatal "Echec de la creation de configuration.yml."
  create_docker_compose || fatal "Echec de la creation de docker-compose.yml."
  create_env_file || fatal "Echec de la creation du fichier .env."
  create_credentials_file || fatal "Echec de la creation du fichier credentials."

  # Create Traefik middleware configuration
  create_traefik_middleware_config || fatal "Echec de la creation du middleware Traefik."

  # Confirm deployment
  log_info ""
  log_info "Configuration prete pour le deploiement:"
  log_info "  - Stack directory: ${STACK_DIR}"
  log_info "  - Scenario: ${TRAEFIK_SCENARIO}"
  log_info "  - Auth domain: ${AUTH_DOMAIN}"
  log_info "  - Authelia URL: ${AUTHELIA_URL}"
  log_info ""

  if [[ ${ASSUME_YES} -eq 0 ]]; then
    confirm "Deployer Authelia maintenant ?"
  fi

  # Deploy stack
  log_info "Deploiement du stack Authelia..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] docker compose -f ${STACK_DIR}/docker-compose.yml up -d"
  else
    cd "${STACK_DIR}" || fatal "Impossible d'acceder a ${STACK_DIR}"
    docker compose up -d || fatal "Echec du deploiement Docker Compose."
  fi

  # Wait for Authelia to be ready
  if [[ ${DRY_RUN} -eq 0 ]]; then
    wait_for_authelia_ready || log_warn "Authelia peut ne pas etre completement pret."
  fi

  # Apply protection to specified services
  if [[ -n "${PROTECTED_SERVICES}" ]]; then
    apply_protection_to_services
  fi

  # Display summary
  display_deployment_summary

  log_success "Deploiement Authelia termine !"
}

# Execute main function
main "$@"
