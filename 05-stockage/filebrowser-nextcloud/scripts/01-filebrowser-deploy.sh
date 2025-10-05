#!/usr/bin/env bash
#
# FileBrowser Deployment Script for Raspberry Pi 5
# Purpose: Deploy FileBrowser with Docker, Traefik integration, and Homepage widget
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (ARM64), Ubuntu 22.04+ ARM64
# Estimated Runtime: 2-5 minutes
#
# Usage:
#   sudo ./01-filebrowser-deploy.sh [OPTIONS]
#
# Options:
#   --dry-run              Show what would be executed without making changes
#   -y, --yes              Skip confirmation prompts
#   -v, --verbose          Enable verbose output
#   -q, --quiet            Suppress non-error output
#   --no-color             Disable colored output
#   -h, --help             Display this help message
#
# Environment Variables:
#   FILEBROWSER_VERSION    FileBrowser version (default: latest)
#   FILEBROWSER_PORT       External port for FileBrowser (default: 8080)
#   STORAGE_DIR            Root storage directory (default: /home/pi/storage)
#   FILEBROWSER_ADMIN_USER Admin username (default: admin)
#   FILEBROWSER_ADMIN_PASS Admin password (auto-generated if empty)
#   STACK_NAME             Stack name (default: storage)
#   STACK_DIR              Stack directory (default: /home/pi/stacks/filebrowser)
#   TRAEFIK_ENABLE         Traefik integration (auto/yes/no, default: auto)
#   FILEBROWSER_DOMAIN     Custom domain for FileBrowser (auto-detected)
#   HOMEPAGE_ENABLE        Homepage integration (auto/yes/no, default: auto)
#
# Examples:
#   # Basic deployment with auto-detection
#   sudo ./01-filebrowser-deploy.sh
#
#   # Custom storage directory
#   STORAGE_DIR=/mnt/external sudo ./01-filebrowser-deploy.sh
#
#   # Disable Traefik integration
#   TRAEFIK_ENABLE=no sudo ./01-filebrowser-deploy.sh
#
#   # Dry-run with verbose output
#   sudo ./01-filebrowser-deploy.sh --dry-run --verbose

set -euo pipefail

# --- Script Directory Detection ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../common-scripts" && pwd)"

# Source common library
if [[ ! -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
  echo "ERREUR: Impossible de trouver lib.sh dans ${COMMON_SCRIPTS_DIR}" >&2
  exit 1
fi

# shellcheck source=../../common-scripts/lib.sh
source "${COMMON_SCRIPTS_DIR}/lib.sh"

# --- Configuration Variables ---

# FileBrowser Configuration
FILEBROWSER_VERSION=${FILEBROWSER_VERSION:-latest}
FILEBROWSER_PORT=${FILEBROWSER_PORT:-8080}
STORAGE_DIR=${STORAGE_DIR:-/home/pi/storage}
FILEBROWSER_ADMIN_USER=${FILEBROWSER_ADMIN_USER:-admin}
FILEBROWSER_ADMIN_PASS=${FILEBROWSER_ADMIN_PASS:-}  # Auto-generate if empty

# Stack Configuration
STACK_NAME=${STACK_NAME:-storage}
STACK_DIR=${STACK_DIR:-/home/pi/stacks/filebrowser}

# Traefik Integration
TRAEFIK_ENABLE=${TRAEFIK_ENABLE:-auto}  # auto/yes/no
FILEBROWSER_DOMAIN=${FILEBROWSER_DOMAIN:-}  # Auto-detect or manual

# Homepage Integration
HOMEPAGE_ENABLE=${HOMEPAGE_ENABLE:-auto}

# Internal Variables
TRAEFIK_SCENARIO=""
FILEBROWSER_URL=""
TRAEFIK_DIR="/home/pi/stacks/traefik"
HOMEPAGE_DIR="/home/pi/stacks/homepage"
CONTAINER_NAME="filebrowser"
CREDENTIALS_FILE="${STACK_DIR}/.credentials"

# --- Usage Function ---
usage() {
  cat <<EOF
FileBrowser Deployment Script for Raspberry Pi 5

Usage:
  sudo ${0##*/} [OPTIONS]

Options:
  --dry-run              Show what would be executed without making changes
  -y, --yes              Skip confirmation prompts
  -v, --verbose          Enable verbose output
  -q, --quiet            Suppress non-error output
  --no-color             Disable colored output
  -h, --help             Display this help message

Environment Variables:
  FILEBROWSER_VERSION    FileBrowser version (default: latest)
  FILEBROWSER_PORT       External port (default: 8080)
  STORAGE_DIR            Root storage directory (default: /home/pi/storage)
  FILEBROWSER_ADMIN_USER Admin username (default: admin)
  FILEBROWSER_ADMIN_PASS Admin password (auto-generated if empty)
  STACK_NAME             Stack name (default: storage)
  STACK_DIR              Stack directory (default: /home/pi/stacks/filebrowser)
  TRAEFIK_ENABLE         Traefik integration (auto/yes/no, default: auto)
  FILEBROWSER_DOMAIN     Custom domain (auto-detected)
  HOMEPAGE_ENABLE        Homepage integration (auto/yes/no, default: auto)

Examples:
  # Basic deployment
  sudo ./01-filebrowser-deploy.sh

  # Custom storage directory
  STORAGE_DIR=/mnt/external sudo ./01-filebrowser-deploy.sh

  # Disable Traefik
  TRAEFIK_ENABLE=no sudo ./01-filebrowser-deploy.sh

  # Dry-run
  sudo ./01-filebrowser-deploy.sh --dry-run --verbose

EOF
  exit 0
}

# --- Helper Functions ---

# Detect Traefik scenario from configuration
detect_traefik_scenario() {
  log_info "Detection du scenario Traefik..."

  # Check if Traefik is disabled
  if [[ "${TRAEFIK_ENABLE}" == "no" ]]; then
    TRAEFIK_SCENARIO="none"
    log_info "Traefik desactive (TRAEFIK_ENABLE=no)"
    return 0
  fi

  # Check if Traefik stack exists
  if [[ ! -d "${TRAEFIK_DIR}" ]]; then
    if [[ "${TRAEFIK_ENABLE}" == "yes" ]]; then
      fatal "Traefik requis (TRAEFIK_ENABLE=yes) mais absent dans ${TRAEFIK_DIR}"
    fi
    TRAEFIK_SCENARIO="none"
    log_info "Traefik non detecte, deploiement sans reverse proxy"
    return 0
  fi

  # Read Traefik .env file
  local traefik_env="${TRAEFIK_DIR}/.env"
  if [[ ! -f "${traefik_env}" ]]; then
    if [[ "${TRAEFIK_ENABLE}" == "yes" ]]; then
      fatal "Fichier ${traefik_env} introuvable"
    fi
    TRAEFIK_SCENARIO="none"
    log_warn "Fichier ${traefik_env} absent, deploiement sans Traefik"
    return 0
  fi

  # Detect scenario from SCENARIO variable
  local scenario_var
  scenario_var=$(grep -E '^SCENARIO=' "${traefik_env}" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")

  if [[ -n "${scenario_var}" ]]; then
    TRAEFIK_SCENARIO="${scenario_var}"
    log_success "Scenario Traefik detecte: ${TRAEFIK_SCENARIO}"
  else
    # Fallback: detect from configuration patterns
    if grep -q "DUCKDNS_TOKEN" "${traefik_env}"; then
      TRAEFIK_SCENARIO="duckdns"
    elif grep -q "CF_API_EMAIL" "${traefik_env}"; then
      TRAEFIK_SCENARIO="cloudflare"
    elif grep -q "VPN_NETWORK" "${traefik_env}"; then
      TRAEFIK_SCENARIO="vpn"
    else
      TRAEFIK_SCENARIO="none"
      log_warn "Impossible de determiner le scenario Traefik, deploiement sans reverse proxy"
      return 0
    fi
    log_success "Scenario Traefik detecte (fallback): ${TRAEFIK_SCENARIO}"
  fi

  # Set domain based on scenario
  if [[ -z "${FILEBROWSER_DOMAIN}" ]]; then
    case "${TRAEFIK_SCENARIO}" in
      duckdns)
        # Path-based routing, extract domain from .env
        local duckdns_domain
        duckdns_domain=$(grep -E '^DUCKDNS_DOMAIN=' "${traefik_env}" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        if [[ -n "${duckdns_domain}" ]]; then
          FILEBROWSER_DOMAIN="${duckdns_domain}"
          FILEBROWSER_URL="https://${duckdns_domain}/files"
        else
          log_warn "DUCKDNS_DOMAIN introuvable dans ${traefik_env}"
          FILEBROWSER_URL="https://your-domain.duckdns.org/files"
        fi
        ;;
      cloudflare)
        # Subdomain-based routing
        local cf_domain
        cf_domain=$(grep -E '^DOMAIN=' "${traefik_env}" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
        if [[ -n "${cf_domain}" ]]; then
          FILEBROWSER_DOMAIN="files.${cf_domain}"
          FILEBROWSER_URL="https://files.${cf_domain}"
        else
          log_warn "DOMAIN introuvable dans ${traefik_env}"
          FILEBROWSER_URL="https://files.example.com"
        fi
        ;;
      vpn)
        # Local domain
        FILEBROWSER_DOMAIN="files.pi.local"
        FILEBROWSER_URL="http://files.pi.local"
        ;;
      *)
        FILEBROWSER_URL="http://$(hostname -I | awk '{print $1}'):${FILEBROWSER_PORT}"
        ;;
    esac
  else
    # Manual domain specified
    FILEBROWSER_URL="https://${FILEBROWSER_DOMAIN}"
  fi

  log_debug "Traefik scenario: ${TRAEFIK_SCENARIO}"
  log_debug "FileBrowser URL: ${FILEBROWSER_URL}"
}

# Generate secure admin password
generate_admin_password() {
  if [[ -n "${FILEBROWSER_ADMIN_PASS}" ]]; then
    log_debug "Mot de passe admin fourni par variable d'environnement"
    return 0
  fi

  log_info "Generation d'un mot de passe administrateur securise..."

  # Check if openssl is available
  if ! command -v openssl >/dev/null 2>&1; then
    fatal "openssl requis pour generer un mot de passe securise"
  fi

  FILEBROWSER_ADMIN_PASS=$(openssl rand -base64 20 | tr -d '/+=' | head -c 20)

  if [[ -z "${FILEBROWSER_ADMIN_PASS}" ]]; then
    fatal "Echec de generation du mot de passe"
  fi

  log_success "Mot de passe genere: ${FILEBROWSER_ADMIN_PASS}"
}

# Setup storage directory with proper permissions
setup_storage_directory() {
  log_info "Configuration du repertoire de stockage: ${STORAGE_DIR}..."

  # Create main storage directory
  if [[ ! -d "${STORAGE_DIR}" ]]; then
    run_cmd mkdir -p "${STORAGE_DIR}"
    log_success "Repertoire ${STORAGE_DIR} cree"
  else
    log_debug "Repertoire ${STORAGE_DIR} existe deja"
  fi

  # Create subdirectories
  local subdirs=("uploads" "documents" "media" "archives" "shared")
  for subdir in "${subdirs[@]}"; do
    local full_path="${STORAGE_DIR}/${subdir}"
    if [[ ! -d "${full_path}" ]]; then
      run_cmd mkdir -p "${full_path}"
      log_debug "Sous-repertoire cree: ${subdir}"
    fi
  done

  # Set ownership (use SUDO_USER if available, otherwise pi)
  local owner="${SUDO_USER:-pi}"
  if id "${owner}" >/dev/null 2>&1; then
    run_cmd chown -R "${owner}:${owner}" "${STORAGE_DIR}"
    log_success "Propriete configuree: ${owner}:${owner}"
  else
    log_warn "Utilisateur ${owner} introuvable, permission inchangee"
  fi

  # Set permissions
  run_cmd chmod -R 755 "${STORAGE_DIR}"
  log_success "Permissions configurees: 755"

  # Create .filebrowser hidden directory for metadata
  local fb_meta="${STORAGE_DIR}/.filebrowser"
  if [[ ! -d "${fb_meta}" ]]; then
    run_cmd mkdir -p "${fb_meta}"
    run_cmd chmod 700 "${fb_meta}"
    if id "${owner}" >/dev/null 2>&1; then
      run_cmd chown "${owner}:${owner}" "${fb_meta}"
    fi
    log_debug "Repertoire metadata cree: .filebrowser"
  fi

  log_success "Repertoire de stockage configure avec succes"
}

# Generate docker-compose.yml
create_docker_compose() {
  log_info "Generation du fichier docker-compose.yml..."

  local compose_file="${STACK_DIR}/docker-compose.yml"
  local traefik_labels=""
  local traefik_network=""

  # Generate Traefik labels based on scenario
  if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
    case "${TRAEFIK_SCENARIO}" in
      duckdns)
        # Path-based routing with strip prefix
        traefik_labels=$(cat <<EOF
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=PathPrefix(\`/files\`)"
      - "traefik.http.routers.filebrowser.entrypoints=websecure"
      - "traefik.http.routers.filebrowser.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.filebrowser-stripprefix.stripprefix.prefixes=/files"
      - "traefik.http.middlewares.filebrowser-stripprefix.stripprefix.forceslash=false"
      - "traefik.http.routers.filebrowser.middlewares=filebrowser-stripprefix"
      - "traefik.http.services.filebrowser.loadbalancer.server.port=80"
EOF
        )
        traefik_network="traefik"
        ;;
      cloudflare)
        # Subdomain-based routing
        traefik_labels=$(cat <<EOF
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host(\`files.\${DOMAIN}\`)"
      - "traefik.http.routers.filebrowser.entrypoints=websecure"
      - "traefik.http.routers.filebrowser.tls.certresolver=cloudflare"
      - "traefik.http.services.filebrowser.loadbalancer.server.port=80"
EOF
        )
        traefik_network="traefik"
        ;;
      vpn)
        # Local domain
        traefik_labels=$(cat <<EOF
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host(\`files.pi.local\`)"
      - "traefik.http.routers.filebrowser.entrypoints=web"
      - "traefik.http.services.filebrowser.loadbalancer.server.port=80"
EOF
        )
        traefik_network="traefik"
        ;;
    esac
  fi

  # Generate networks section
  local networks_section=""
  if [[ -n "${traefik_network}" ]]; then
    networks_section=$(cat <<EOF

networks:
  traefik:
    external: true
    name: traefik
EOF
    )
  fi

  # Generate ports section (only if no Traefik)
  local ports_section=""
  if [[ "${TRAEFIK_SCENARIO}" == "none" ]]; then
    ports_section=$(cat <<EOF
    ports:
      - "\${FILEBROWSER_PORT}:80"
EOF
    )
  fi

  # Generate networks for service
  local service_networks=""
  if [[ -n "${traefik_network}" ]]; then
    service_networks=$(cat <<EOF
    networks:
      - traefik
EOF
    )
  fi

  # Create docker-compose.yml
  cat > "${compose_file}" <<EOF
version: "3.8"

services:
  filebrowser:
    image: filebrowser/filebrowser:\${FILEBROWSER_VERSION:-latest}
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Paris
    volumes:
      - \${STORAGE_DIR}:/srv
      - ./database.db:/database.db
      - ./filebrowser.json:/.filebrowser.json
      - ./branding:/branding
${ports_section}
${service_networks}
    labels:
${traefik_labels}
      - "com.centurylinklabs.watchtower.enable=true"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:80/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
${networks_section}
EOF

  if [[ ${DRY_RUN} -eq 0 ]]; then
    log_success "Fichier docker-compose.yml cree: ${compose_file}"
  else
    log_info "[DRY-RUN] Fichier docker-compose.yml genere"
  fi
}

# Create FileBrowser configuration file
create_filebrowser_config() {
  log_info "Creation du fichier de configuration FileBrowser..."

  local config_file="${STACK_DIR}/filebrowser.json"

  cat > "${config_file}" <<EOF
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database.db",
  "root": "/srv",
  "signup": false,
  "createUserDir": false,
  "defaults": {
    "scope": "/srv",
    "locale": "fr",
    "viewMode": "list",
    "sorting": {
      "by": "name",
      "asc": true
    },
    "perm": {
      "admin": false,
      "execute": true,
      "create": true,
      "rename": true,
      "modify": true,
      "delete": true,
      "share": true,
      "download": true
    },
    "commands": [],
    "hideDotfiles": false,
    "dateFormat": false
  },
  "commands": {
    "after_copy": [],
    "after_delete": [],
    "after_rename": [],
    "after_save": [],
    "before_copy": [],
    "before_delete": [],
    "before_rename": [],
    "before_save": []
  },
  "shell": [
    "/bin/sh",
    "-c"
  ],
  "rules": [],
  "branding": {
    "name": "FileBrowser Pi5",
    "files": "/branding",
    "disableExternal": false,
    "disableUsedPercentage": false
  },
  "tus": {
    "chunkSize": 10485760,
    "retryCount": 5
  }
}
EOF

  if [[ ${DRY_RUN} -eq 0 ]]; then
    log_success "Configuration FileBrowser creee: ${config_file}"
  fi
}

# Create branding directory
create_branding_directory() {
  log_info "Creation du repertoire de branding..."

  local branding_dir="${STACK_DIR}/branding"
  run_cmd mkdir -p "${branding_dir}"

  # Create a simple README
  cat > "${branding_dir}/README.md" <<EOF
# FileBrowser Branding

Place custom branding files here:
- \`logo.svg\` - Custom logo (displayed in header)
- \`favicon.ico\` - Custom favicon
- \`img/\` - Additional images

For more information:
https://filebrowser.org/configuration/branding
EOF

  log_success "Repertoire branding cree: ${branding_dir}"
}

# Generate .env file
create_env_file() {
  log_info "Generation du fichier .env..."

  local env_file="${STACK_DIR}/.env"

  cat > "${env_file}" <<EOF
# FileBrowser Configuration
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

# Version
FILEBROWSER_VERSION=${FILEBROWSER_VERSION}

# Network
FILEBROWSER_PORT=${FILEBROWSER_PORT}

# Storage
STORAGE_DIR=${STORAGE_DIR}

# Traefik Integration (for cloudflare scenario)
DOMAIN=${FILEBROWSER_DOMAIN#files.}

# Stack
STACK_NAME=${STACK_NAME}
EOF

  # Secure .env file
  run_cmd chmod 600 "${env_file}"

  if [[ ${DRY_RUN} -eq 0 ]]; then
    log_success "Fichier .env cree: ${env_file}"
  fi
}

# Save credentials securely
save_credentials() {
  log_info "Sauvegarde des identifiants..."

  cat > "${CREDENTIALS_FILE}" <<EOF
# FileBrowser Credentials
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# WARNING: Keep this file secure!

ADMIN_USER=${FILEBROWSER_ADMIN_USER}
ADMIN_PASS=${FILEBROWSER_ADMIN_PASS}

# Access URL
FILEBROWSER_URL=${FILEBROWSER_URL}
EOF

  # Secure credentials file
  run_cmd chmod 600 "${CREDENTIALS_FILE}"

  log_success "Identifiants sauvegardes: ${CREDENTIALS_FILE}"
}

# Initialize FileBrowser with admin user
init_filebrowser_config() {
  log_info "Initialisation de FileBrowser avec l'utilisateur administrateur..."

  # Wait for container to be healthy
  log_info "Attente du demarrage du conteneur..."
  local max_wait=60
  local waited=0
  while [[ ${waited} -lt ${max_wait} ]]; do
    if docker ps --filter "name=${CONTAINER_NAME}" --filter "health=healthy" | grep -q "${CONTAINER_NAME}"; then
      log_success "Conteneur demarré et pret"
      break
    fi
    sleep 2
    waited=$((waited + 2))
    if [[ $((waited % 10)) -eq 0 ]]; then
      log_debug "Attente... ${waited}s/${max_wait}s"
    fi
  done

  if [[ ${waited} -ge ${max_wait} ]]; then
    log_warn "Timeout atteint, tentative de configuration malgre tout..."
  fi

  # Create admin user via CLI
  log_info "Creation de l'utilisateur administrateur: ${FILEBROWSER_ADMIN_USER}..."

  if [[ ${DRY_RUN} -eq 0 ]]; then
    # Use docker exec to create admin user
    if docker exec "${CONTAINER_NAME}" filebrowser users add "${FILEBROWSER_ADMIN_USER}" "${FILEBROWSER_ADMIN_PASS}" \
        --perm.admin 2>/dev/null; then
      log_success "Utilisateur administrateur cree avec succes"
    else
      # User might already exist, try to update password
      log_warn "Utilisateur existe peut-etre deja, tentative de mise a jour du mot de passe..."
      if docker exec "${CONTAINER_NAME}" filebrowser users update "${FILEBROWSER_ADMIN_USER}" \
          --password "${FILEBROWSER_ADMIN_PASS}" --perm.admin 2>/dev/null; then
        log_success "Mot de passe administrateur mis a jour"
      else
        log_error "Impossible de creer/mettre a jour l'utilisateur administrateur"
        log_error "Vous devrez le creer manuellement via l'interface web"
        log_error "Utilisateur par defaut: admin / admin (a changer!)"
      fi
    fi
  else
    log_info "[DRY-RUN] Creation utilisateur admin: ${FILEBROWSER_ADMIN_USER}"
  fi
}

# Configure Homepage widget
configure_homepage_widget() {
  # Check if Homepage integration is disabled
  if [[ "${HOMEPAGE_ENABLE}" == "no" ]]; then
    log_info "Integration Homepage desactivee (HOMEPAGE_ENABLE=no)"
    return 0
  fi

  # Check if Homepage stack exists
  if [[ ! -d "${HOMEPAGE_DIR}" ]]; then
    if [[ "${HOMEPAGE_ENABLE}" == "yes" ]]; then
      log_warn "Homepage requis (HOMEPAGE_ENABLE=yes) mais absent dans ${HOMEPAGE_DIR}"
    else
      log_info "Homepage non detecte, widget non ajoute"
    fi
    return 0
  fi

  log_info "Configuration du widget Homepage..."

  local services_file="${HOMEPAGE_DIR}/config/services.yaml"

  if [[ ! -f "${services_file}" ]]; then
    log_warn "Fichier ${services_file} introuvable, widget non ajoute"
    return 0
  fi

  # Check if FileBrowser widget already exists
  if grep -q "FileBrowser" "${services_file}" 2>/dev/null; then
    log_info "Widget FileBrowser deja present dans Homepage"
    return 0
  fi

  # Determine widget URL based on scenario
  local widget_url="${FILEBROWSER_URL}"
  local widget_icon="filebrowser"
  local widget_description="Gestionnaire de fichiers web"

  # Backup services.yaml
  if [[ ${DRY_RUN} -eq 0 ]]; then
    cp "${services_file}" "${services_file}.backup.$(date +%Y%m%d-%H%M%S)"
  fi

  # Add FileBrowser widget to Storage section
  local widget_config=$(cat <<EOF

  - Stockage:
      - FileBrowser:
          icon: ${widget_icon}
          href: ${widget_url}
          description: ${widget_description}
          widget:
            type: filebrowser
            url: http://filebrowser:80
            username: ${FILEBROWSER_ADMIN_USER}
            password: ${FILEBROWSER_ADMIN_PASS}
EOF
  )

  if [[ ${DRY_RUN} -eq 0 ]]; then
    # Check if "Stockage" section exists
    if grep -q "Stockage:" "${services_file}"; then
      log_info "Section 'Stockage' existe, ajout du widget..."
      # Add widget to existing section (complex YAML manipulation)
      log_warn "Section Stockage existe, ajout manuel requis:"
      echo "${widget_config}"
    else
      # Add new section
      echo "${widget_config}" >> "${services_file}"
      log_success "Widget FileBrowser ajoute a Homepage"
    fi

    # Restart Homepage to apply changes
    if docker ps --filter "name=homepage" --format "{{.Names}}" | grep -q "homepage"; then
      log_info "Redemarrage de Homepage pour appliquer les changements..."
      docker restart homepage >/dev/null 2>&1 || log_warn "Impossible de redemarrer Homepage"
    fi
  else
    log_info "[DRY-RUN] Ajout widget Homepage:"
    echo "${widget_config}"
  fi

  log_success "Configuration Homepage terminee"
}

# Validate prerequisites
validate_prerequisites() {
  log_info "Validation des prerequis..."

  # Check if running as root
  require_root

  # Check Docker
  check_command docker
  if ! docker info >/dev/null 2>&1; then
    fatal "Docker n'est pas en cours d'execution. Demarrez Docker avec: sudo systemctl start docker"
  fi
  log_success "Docker operationnel"

  # Check Docker Compose
  if ! docker compose version >/dev/null 2>&1; then
    fatal "Docker Compose introuvable. Installez-le avec: sudo apt install docker-compose-plugin"
  fi
  log_success "Docker Compose disponible"

  # Check port availability (only if no Traefik)
  if [[ "${TRAEFIK_SCENARIO}" == "none" ]]; then
    if ss -tuln | grep -q ":${FILEBROWSER_PORT} "; then
      log_warn "Port ${FILEBROWSER_PORT} deja utilise"
      if [[ ${ASSUME_YES} -eq 0 ]]; then
        confirm "Continuer malgre tout ? Le deploiement pourrait echouer."
      fi
    else
      log_success "Port ${FILEBROWSER_PORT} disponible"
    fi
  fi

  # Check available disk space
  local storage_parent
  storage_parent=$(dirname "${STORAGE_DIR}")
  local available_space
  available_space=$(df -BG "${storage_parent}" | tail -1 | awk '{print $4}' | tr -d 'G')

  if [[ ${available_space} -lt 5 ]]; then
    log_warn "Espace disque faible: ${available_space}G disponible"
    log_warn "Recommandation: au moins 5G pour ${STORAGE_DIR}"
  else
    log_success "Espace disque suffisant: ${available_space}G disponible"
  fi

  log_success "Tous les prerequis sont valides"
}

# Deploy FileBrowser stack
deploy_stack() {
  log_info "Deploiement de la stack FileBrowser..."

  cd "${STACK_DIR}" || fatal "Impossible d'acceder a ${STACK_DIR}"

  if [[ ${DRY_RUN} -eq 0 ]]; then
    # Pull images first
    log_info "Telechargement de l'image FileBrowser..."
    docker compose pull || log_warn "Echec du pull, tentative de deploiement..."

    # Deploy stack
    log_info "Demarrage des conteneurs..."
    if docker compose up -d; then
      log_success "Stack deployee avec succes"
    else
      fatal "Echec du deploiement de la stack"
    fi

    # Wait for health check
    log_info "Verification de la sante du conteneur..."
    sleep 5
    if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${CONTAINER_NAME}"; then
      log_success "Conteneur ${CONTAINER_NAME} en cours d'execution"
    else
      log_error "Conteneur ${CONTAINER_NAME} non demarre"
      log_error "Logs:"
      docker logs "${CONTAINER_NAME}" 2>&1 | tail -20
      fatal "Deploiement echoue"
    fi
  else
    log_info "[DRY-RUN] docker compose up -d"
  fi
}

# Test FileBrowser accessibility
test_accessibility() {
  log_info "Test d'accessibilite de FileBrowser..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Test d'accessibilite skipped"
    return 0
  fi

  # Test internal container health
  log_info "Test de la sante interne du conteneur..."
  local max_attempts=10
  local attempt=0
  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if docker exec "${CONTAINER_NAME}" wget --quiet --tries=1 --spider http://localhost:80/health 2>/dev/null; then
      log_success "Conteneur repond aux requetes de sante"
      break
    fi
    attempt=$((attempt + 1))
    if [[ ${attempt} -lt ${max_attempts} ]]; then
      log_debug "Tentative ${attempt}/${max_attempts}..."
      sleep 3
    else
      log_warn "Le conteneur ne repond pas aux health checks (non bloquant)"
    fi
  done

  # Test external accessibility (if no Traefik, test direct port)
  if [[ "${TRAEFIK_SCENARIO}" == "none" ]]; then
    log_info "Test de l'acces externe sur le port ${FILEBROWSER_PORT}..."
    if curl -f -s -o /dev/null "http://localhost:${FILEBROWSER_PORT}" 2>/dev/null; then
      log_success "FileBrowser accessible sur http://localhost:${FILEBROWSER_PORT}"
    else
      log_warn "FileBrowser non accessible sur le port ${FILEBROWSER_PORT} (peut necesiter quelques secondes)"
    fi
  fi

  log_success "Tests d'accessibilite termines"
}

# Display deployment summary
display_deployment_summary() {
  echo ""
  echo "=========================================="
  echo " FileBrowser - Deploiement Termine"
  echo "=========================================="
  echo ""
  log_success "FileBrowser deploye avec succes !"
  echo ""
  echo "Informations de connexion :"
  echo "-------------------------------------------"
  echo "  URL d'acces    : ${FILEBROWSER_URL}"
  echo "  Utilisateur    : ${FILEBROWSER_ADMIN_USER}"
  echo "  Mot de passe   : ${FILEBROWSER_ADMIN_PASS}"
  echo ""
  echo "Configuration du stockage :"
  echo "-------------------------------------------"
  echo "  Repertoire     : ${STORAGE_DIR}"
  echo "  Sous-dossiers  : uploads/, documents/, media/, archives/, shared/"
  echo ""
  echo "Configuration Traefik :"
  echo "-------------------------------------------"
  echo "  Scenario       : ${TRAEFIK_SCENARIO}"
  if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
    echo "  Integration    : Activee"
    echo "  Domaine        : ${FILEBROWSER_DOMAIN}"
  else
    echo "  Integration    : Desactivee"
    echo "  Port direct    : ${FILEBROWSER_PORT}"
  fi
  echo ""
  echo "Fichiers de configuration :"
  echo "-------------------------------------------"
  echo "  Stack dir      : ${STACK_DIR}"
  echo "  Compose        : ${STACK_DIR}/docker-compose.yml"
  echo "  Config         : ${STACK_DIR}/filebrowser.json"
  echo "  Database       : ${STACK_DIR}/database.db"
  echo "  Credentials    : ${CREDENTIALS_FILE}"
  echo ""
  echo "Commandes utiles :"
  echo "-------------------------------------------"
  echo "  Logs           : docker compose -f ${STACK_DIR}/docker-compose.yml logs -f"
  echo "  Restart        : docker compose -f ${STACK_DIR}/docker-compose.yml restart"
  echo "  Stop           : docker compose -f ${STACK_DIR}/docker-compose.yml down"
  echo "  Status         : docker ps --filter name=${CONTAINER_NAME}"
  echo ""
  echo "Prochaines etapes :"
  echo "-------------------------------------------"
  echo "  1. Connectez-vous a ${FILEBROWSER_URL}"
  echo "  2. Utilisez les identifiants ci-dessus"
  echo "  3. Changez le mot de passe (recommande)"
  echo "  4. Configurez les utilisateurs supplementaires si necessaire"
  echo "  5. Explorez les sous-dossiers dans ${STORAGE_DIR}"
  echo ""
  if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
    echo "Note DuckDNS :"
    echo "  - Acces via path /files"
    echo "  - URL complete: ${FILEBROWSER_URL}"
    echo ""
  fi
  if [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
    echo "Note Cloudflare :"
    echo "  - Verifiez que le sous-domaine 'files' pointe vers votre Pi"
    echo "  - Le certificat SSL sera genere automatiquement"
    echo ""
  fi
  echo "Documentation :"
  echo "-------------------------------------------"
  echo "  FileBrowser    : https://filebrowser.org/configuration"
  echo "  PI5-SETUP      : ${STACK_DIR}/../README.md"
  echo ""
  echo "=========================================="
}

# Cleanup function (called on script exit)
cleanup_on_error() {
  local exit_code=$?
  if [[ ${exit_code} -ne 0 ]] && [[ ${DRY_RUN} -eq 0 ]]; then
    log_error "Deploiement interrompu (code: ${exit_code})"
    log_info "Les fichiers partiellement crees sont dans: ${STACK_DIR}"
    log_info "Pour nettoyer: docker compose -f ${STACK_DIR}/docker-compose.yml down -v"
  fi
}

# --- Main Function ---
main() {
  # Parse common arguments
  parse_common_args "$@"

  # Show help if requested
  if [[ ${SHOW_HELP} -eq 1 ]]; then
    usage
  fi

  # Register cleanup handler
  trap cleanup_on_error EXIT

  # Display banner
  echo ""
  echo "=========================================="
  echo " FileBrowser Deployment"
  echo " Raspberry Pi 5 ARM64"
  echo "=========================================="
  echo ""

  # Step 1: Validate prerequisites
  log_info "Etape 1/10: Validation des prerequis"
  validate_prerequisites

  # Step 2: Detect Traefik scenario
  log_info "Etape 2/10: Detection de l'environnement Traefik"
  detect_traefik_scenario

  # Step 3: Generate admin password
  log_info "Etape 3/10: Generation des identifiants"
  generate_admin_password

  # Step 4: Create stack directory
  log_info "Etape 4/10: Creation du repertoire de la stack"
  ensure_dir "${STACK_DIR}"
  log_success "Repertoire stack: ${STACK_DIR}"

  # Step 5: Setup storage directory
  log_info "Etape 5/10: Configuration du repertoire de stockage"
  setup_storage_directory

  # Step 6: Create FileBrowser configuration
  log_info "Etape 6/10: Creation de la configuration FileBrowser"
  create_filebrowser_config
  create_branding_directory

  # Step 7: Generate docker-compose.yml
  log_info "Etape 7/10: Generation du docker-compose.yml"
  create_docker_compose

  # Step 8: Generate .env file
  log_info "Etape 8/10: Generation du fichier .env"
  create_env_file
  save_credentials

  # Step 9: Deploy stack
  log_info "Etape 9/10: Deploiement de la stack Docker"
  deploy_stack

  # Step 10: Initialize FileBrowser
  log_info "Etape 10/10: Initialisation de FileBrowser"
  init_filebrowser_config

  # Step 11: Configure Homepage widget
  log_info "Etape 11/10: Integration Homepage (bonus)"
  configure_homepage_widget

  # Step 12: Test accessibility
  log_info "Etape 12/10: Tests d'accessibilite"
  test_accessibility

  # Display summary
  display_deployment_summary

  # Final success message
  log_success "Deploiement termine avec succes !"

  exit 0
}

# Execute main function
main "$@"
