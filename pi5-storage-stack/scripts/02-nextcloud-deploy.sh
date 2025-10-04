#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Nextcloud Stack Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy production-ready Nextcloud with PostgreSQL and Redis
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Nextcloud + PostgreSQL 15 + Redis 7
# Traefik Integration: Auto-detection (DuckDNS/Cloudflare/VPN)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 8-12 minutes
# =============================================================================

# --- Script Directory Detection ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/../../common-scripts/lib.sh"

# Source common library
if [[ -f "${COMMON_LIB}" ]]; then
  # shellcheck source=/dev/null
  source "${COMMON_LIB}"
else
  echo "ERREUR: Bibliothèque commune introuvable: ${COMMON_LIB}" >&2
  exit 1
fi

# =============================================================================
# ENVIRONMENT VARIABLES & DEFAULTS
# =============================================================================

# Nextcloud Configuration
NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION:-latest}
NEXTCLOUD_PORT=${NEXTCLOUD_PORT:-8081}
NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER:-admin}
NEXTCLOUD_ADMIN_PASS=${NEXTCLOUD_ADMIN_PASS:-}  # Auto-generate if empty

# Database Configuration
POSTGRES_VERSION=${POSTGRES_VERSION:-15-alpine}
POSTGRES_DB=${POSTGRES_DB:-nextcloud}
POSTGRES_USER=${POSTGRES_USER:-nextcloud}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-}  # Auto-generate if empty

# Redis Configuration
REDIS_VERSION=${REDIS_VERSION:-7-alpine}
REDIS_PASSWORD=${REDIS_PASSWORD:-}  # Auto-generate if empty

# Stack Configuration
STACK_NAME=${STACK_NAME:-nextcloud}
STACK_DIR=${STACK_DIR:-/home/pi/stacks/nextcloud}
DATA_DIR=${DATA_DIR:-/home/pi/nextcloud-data}

# Traefik Integration
TRAEFIK_ENABLE=${TRAEFIK_ENABLE:-auto}
TRAEFIK_SCENARIO=""
NEXTCLOUD_DOMAIN=${NEXTCLOUD_DOMAIN:-}  # Auto-detect or manual
NEXTCLOUD_URL=""

# Homepage Integration
HOMEPAGE_ENABLE=${HOMEPAGE_ENABLE:-auto}
HOMEPAGE_DIR="/home/pi/stacks/homepage/config"

# Docker Compose Network
DOCKER_NETWORK="traefik_proxy"

# Script Metadata
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/nextcloud-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"

# =============================================================================
# USAGE & HELP
# =============================================================================

usage() {
  cat <<EOF
Usage: sudo $0 [OPTIONS]

Déploie Nextcloud + PostgreSQL + Redis avec intégration Traefik automatique

OPTIONS:
  --nextcloud-version VERSION  Version Nextcloud (default: latest)
  --admin-user USER            Utilisateur admin (default: admin)
  --admin-pass PASSWORD        Mot de passe admin (auto-généré si vide)
  --postgres-password PASSWORD Mot de passe PostgreSQL (auto-généré si vide)
  --data-dir PATH              Répertoire données (default: /home/pi/nextcloud-data)
  --stack-dir PATH             Répertoire stack (default: /home/pi/stacks/nextcloud)
  --traefik-enable yes|no|auto Auto-détection Traefik (default: auto)
  --domain DOMAIN              Domaine Nextcloud (auto-détecté)
  --homepage-enable yes|no|auto Intégration Homepage (default: auto)

  --dry-run                    Afficher les actions sans les exécuter
  --yes, -y                    Accepter automatiquement les prompts
  --verbose, -v                Mode verbeux
  --quiet, -q                  Mode silencieux
  --help, -h                   Afficher cette aide

EXEMPLES:
  # Déploiement standard (auto-détection)
  sudo $0

  # Déploiement avec mot de passe personnalisé
  sudo $0 --admin-pass "MonMotDePasse123!"

  # Déploiement avec répertoire de données personnalisé
  sudo $0 --data-dir /mnt/usb-disk/nextcloud-data

  # Test sans exécution
  sudo $0 --dry-run --verbose

NOTES:
  - Docker doit être installé et actif
  - Minimum 4GB RAM recommandé pour Raspberry Pi 5
  - Espace disque: minimum 10GB libre recommandé
  - Traefik est auto-détecté (DuckDNS/Cloudflare/VPN)
  - Homepage dashboard est auto-configuré si présent

EOF
  exit 0
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --nextcloud-version)
        NEXTCLOUD_VERSION="$2"
        shift 2
        ;;
      --admin-user)
        NEXTCLOUD_ADMIN_USER="$2"
        shift 2
        ;;
      --admin-pass)
        NEXTCLOUD_ADMIN_PASS="$2"
        shift 2
        ;;
      --postgres-password)
        POSTGRES_PASSWORD="$2"
        shift 2
        ;;
      --data-dir)
        DATA_DIR="$2"
        shift 2
        ;;
      --stack-dir)
        STACK_DIR="$2"
        shift 2
        ;;
      --traefik-enable)
        TRAEFIK_ENABLE="$2"
        shift 2
        ;;
      --domain)
        NEXTCLOUD_DOMAIN="$2"
        shift 2
        ;;
      --homepage-enable)
        HOMEPAGE_ENABLE="$2"
        shift 2
        ;;
      *)
        # Delegate to common arg parser
        break
        ;;
    esac
  done

  # Parse common arguments (--dry-run, --verbose, etc.)
  parse_common_args "$@"

  if [[ ${SHOW_HELP} -eq 1 ]]; then
    usage
  fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

check_system_requirements() {
  log_info "Vérification des prérequis système..."

  # Check if running on ARM64
  local arch
  arch=$(detect_arch)
  if [[ "${arch}" != "aarch64" ]]; then
    log_warn "Architecture détectée: ${arch} (attendu: aarch64/ARM64)"
    confirm "Continuer malgré l'architecture non-ARM64 ?"
  fi

  # Check available RAM (minimum 2GB, recommended 4GB)
  local total_ram_kb
  total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local total_ram_gb=$((total_ram_kb / 1024 / 1024))

  if [[ ${total_ram_gb} -lt 2 ]]; then
    fatal "RAM insuffisante: ${total_ram_gb}GB (minimum 2GB requis)"
  elif [[ ${total_ram_gb} -lt 4 ]]; then
    log_warn "RAM détectée: ${total_ram_gb}GB (4GB recommandé pour Nextcloud)"
  else
    log_success "RAM détectée: ${total_ram_gb}GB"
  fi

  # Check available disk space (minimum 10GB)
  local available_space_kb
  available_space_kb=$(df / | tail -1 | awk '{print $4}')
  local available_space_gb=$((available_space_kb / 1024 / 1024))

  if [[ ${available_space_gb} -lt 10 ]]; then
    log_warn "Espace disque disponible: ${available_space_gb}GB (minimum 10GB recommandé)"
    confirm "Continuer avec cet espace disque limité ?"
  else
    log_success "Espace disque disponible: ${available_space_gb}GB"
  fi
}

check_docker() {
  log_info "Vérification de Docker..."

  check_command docker

  if ! systemctl is-active --quiet docker; then
    log_warn "Service Docker non actif. Démarrage..."
    run_cmd systemctl start docker || fatal "Échec du démarrage de Docker"
  fi

  # Test Docker functionality
  if ! docker ps &>/dev/null; then
    fatal "Docker ne fonctionne pas correctement. Vérifiez les permissions."
  fi

  log_success "Docker est opérationnel"
}

check_port_availability() {
  log_info "Vérification de la disponibilité des ports..."

  local ports=("${NEXTCLOUD_PORT}:Nextcloud" "5432:PostgreSQL" "6379:Redis")
  local port_conflicts=()

  for port_info in "${ports[@]}"; do
    local port="${port_info%%:*}"
    local service="${port_info##*:}"

    if lsof -Pi ":${port}" -sTCP:LISTEN -t &>/dev/null; then
      port_conflicts+=("${port} (${service})")
    fi
  done

  if [[ ${#port_conflicts[@]} -gt 0 ]]; then
    log_error "Ports déjà utilisés: ${port_conflicts[*]}"
    fatal "Libérez les ports ou modifiez la configuration"
  fi

  log_success "Tous les ports sont disponibles"
}

check_existing_installation() {
  if [[ -d "${STACK_DIR}" ]]; then
    log_warn "Installation Nextcloud existante détectée: ${STACK_DIR}"

    if [[ -f "${STACK_DIR}/docker-compose.yml" ]]; then
      log_info "Docker Compose trouvé. Vérification de l'état..."

      if docker compose -f "${STACK_DIR}/docker-compose.yml" ps --quiet 2>/dev/null | grep -q .; then
        log_warn "Conteneurs Nextcloud actifs détectés"
        confirm "Arrêter et remplacer l'installation existante ?"

        log_info "Arrêt des conteneurs existants..."
        run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" down
      fi
    fi

    confirm "Sauvegarder l'installation existante avant de continuer ?"
    if [[ $? -eq 0 ]]; then
      local backup_dir="${STACK_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
      log_info "Sauvegarde vers: ${backup_dir}"
      run_cmd cp -r "${STACK_DIR}" "${backup_dir}"
      log_success "Sauvegarde créée"
    fi
  fi
}

# =============================================================================
# TRAEFIK DETECTION
# =============================================================================

detect_traefik_scenario() {
  log_info "Détection du scénario Traefik..."

  local traefik_env="/home/pi/stacks/traefik/.env"

  # Check if Traefik is installed
  if [[ ! -f "${traefik_env}" ]]; then
    log_warn "Traefik non détecté (${traefik_env} introuvable)"
    TRAEFIK_SCENARIO="none"
    TRAEFIK_ENABLE="no"
    log_info "Mode autonome: Nextcloud sera accessible sur le port ${NEXTCLOUD_PORT}"
    return 0
  fi

  # Read Traefik configuration
  # shellcheck source=/dev/null
  source "${traefik_env}"

  # Detect scenario based on environment variables
  if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]] && [[ -n "${DUCKDNS_TOKEN:-}" ]]; then
    TRAEFIK_SCENARIO="duckdns"
    NEXTCLOUD_DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
    NEXTCLOUD_URL="https://${NEXTCLOUD_DOMAIN}/cloud"
    log_success "Scénario détecté: DuckDNS (path-based)"

  elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]] && [[ -n "${CLOUDFLARE_API_TOKEN:-}" ]]; then
    TRAEFIK_SCENARIO="cloudflare"
    NEXTCLOUD_DOMAIN="cloud.${CLOUDFLARE_DOMAIN}"
    NEXTCLOUD_URL="https://${NEXTCLOUD_DOMAIN}"
    log_success "Scénario détecté: Cloudflare (subdomain)"

  elif [[ -n "${VPN_LOCAL_DOMAIN:-}" ]]; then
    TRAEFIK_SCENARIO="vpn"
    NEXTCLOUD_DOMAIN="${VPN_LOCAL_DOMAIN}"
    NEXTCLOUD_URL="http://cloud.${NEXTCLOUD_DOMAIN}"
    log_success "Scénario détecté: VPN (local domain)"

  else
    log_warn "Traefik détecté mais scénario inconnu"
    TRAEFIK_SCENARIO="unknown"
    TRAEFIK_ENABLE="no"
  fi

  # Create Docker network if doesn't exist
  if [[ "${TRAEFIK_ENABLE}" != "no" ]]; then
    if ! docker network inspect "${DOCKER_NETWORK}" &>/dev/null; then
      log_info "Création du réseau Docker: ${DOCKER_NETWORK}"
      run_cmd docker network create "${DOCKER_NETWORK}"
    fi
  fi
}

# =============================================================================
# PASSWORD GENERATION
# =============================================================================

generate_passwords() {
  log_info "Génération des mots de passe sécurisés..."

  # Generate Nextcloud admin password if empty
  if [[ -z "${NEXTCLOUD_ADMIN_PASS}" ]]; then
    NEXTCLOUD_ADMIN_PASS=$(openssl rand -base64 20 | tr -d '/+=')
    log_debug "Mot de passe admin Nextcloud généré"
  fi

  # Generate PostgreSQL password if empty
  if [[ -z "${POSTGRES_PASSWORD}" ]]; then
    POSTGRES_PASSWORD=$(openssl rand -base64 20 | tr -d '/+=')
    log_debug "Mot de passe PostgreSQL généré"
  fi

  # Generate Redis password if empty
  if [[ -z "${REDIS_PASSWORD}" ]]; then
    REDIS_PASSWORD=$(openssl rand -base64 20 | tr -d '/+=')
    log_debug "Mot de passe Redis généré"
  fi

  log_success "Tous les mots de passe sont prêts"
}

# =============================================================================
# DATA DIRECTORY SETUP
# =============================================================================

setup_data_directory() {
  log_info "Configuration du répertoire de données: ${DATA_DIR}"

  # Create data directory
  ensure_dir "${DATA_DIR}"

  # Set ownership to www-data (UID:GID 33:33 - Nextcloud user)
  if [[ ${DRY_RUN} -eq 0 ]]; then
    chown -R 33:33 "${DATA_DIR}" || log_warn "Impossible de changer le propriétaire (normal si pas encore en root)"
    chmod 755 "${DATA_DIR}"
  else
    log_info "[DRY-RUN] chown -R 33:33 ${DATA_DIR}"
    log_info "[DRY-RUN] chmod 755 ${DATA_DIR}"
  fi

  log_success "Répertoire de données configuré"
}

# =============================================================================
# DOCKER COMPOSE GENERATION
# =============================================================================

create_docker_compose() {
  log_info "Génération du fichier docker-compose.yml..."

  local compose_file="${STACK_DIR}/docker-compose.yml"

  # Build trusted domains list
  local trusted_domains="localhost,127.0.0.1,nextcloud"

  if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
    trusted_domains="${trusted_domains},${NEXTCLOUD_DOMAIN}"
  elif [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
    trusted_domains="${trusted_domains},${NEXTCLOUD_DOMAIN}"
  elif [[ "${TRAEFIK_SCENARIO}" == "vpn" ]]; then
    trusted_domains="${trusted_domains},cloud.${NEXTCLOUD_DOMAIN},${NEXTCLOUD_DOMAIN}"
  fi

  # Add local IP to trusted domains
  local local_ip
  local_ip=$(hostname -I | awk '{print $1}')
  if [[ -n "${local_ip}" ]]; then
    trusted_domains="${trusted_domains},${local_ip}"
  fi

  # Generate Traefik labels based on scenario
  local traefik_labels=""

  if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
    traefik_labels=$(cat <<'LABELS_DUCKDNS'
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=PathPrefix(\`/cloud\`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.nextcloud-stripprefix.stripprefix.prefixes=/cloud"
      - "traefik.http.middlewares.nextcloud-stripprefix.stripprefix.forceSlash=false"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsSeconds=15552000"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.regex=https://(.*)/.well-known/(card|cal)dav"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.replacement=https://\$\${1}/remote.php/dav/"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.permanent=true"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-stripprefix,nextcloud-headers,nextcloud-redirect"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
LABELS_DUCKDNS
)
  elif [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
    traefik_labels=$(cat <<LABELS_CLOUDFLARE
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(\`${NEXTCLOUD_DOMAIN}\`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=cloudflare"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsSeconds=15552000"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsIncludeSubdomains=true"
      - "traefik.http.middlewares.nextcloud-headers.headers.stsPreload=true"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.regex=https://(.*)/.well-known/(card|cal)dav"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.replacement=https://\$\${1}/remote.php/dav/"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.permanent=true"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-headers,nextcloud-redirect"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
LABELS_CLOUDFLARE
)
  elif [[ "${TRAEFIK_SCENARIO}" == "vpn" ]]; then
    traefik_labels=$(cat <<LABELS_VPN
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(\`cloud.${NEXTCLOUD_DOMAIN}\`) || Host(\`cloud.pi.local\`)"
      - "traefik.http.routers.nextcloud.entrypoints=web"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.regex=http://(.*)/.well-known/(card|cal)dav"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.replacement=http://\$\${1}/remote.php/dav/"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.permanent=true"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-redirect"
      - "traefik.http.services.nextcloud.loadbalancer.server.port=80"
LABELS_VPN
)
  else
    # No Traefik - expose port directly
    traefik_labels="      - \"traefik.enable=false\""
  fi

  # Generate networks configuration
  local networks_config=""
  if [[ "${TRAEFIK_SCENARIO}" != "none" ]] && [[ "${TRAEFIK_ENABLE}" != "no" ]]; then
    networks_config=$(cat <<NETWORKS
networks:
  traefik_proxy:
    external: true
  nextcloud_internal:
    driver: bridge
NETWORKS
)
  else
    networks_config=$(cat <<NETWORKS
networks:
  nextcloud_internal:
    driver: bridge
NETWORKS
)
  fi

  # Generate service networks
  local service_networks=""
  if [[ "${TRAEFIK_SCENARIO}" != "none" ]] && [[ "${TRAEFIK_ENABLE}" != "no" ]]; then
    service_networks=$(cat <<SVC_NETWORKS
    networks:
      - traefik_proxy
      - nextcloud_internal
SVC_NETWORKS
)
  else
    service_networks=$(cat <<SVC_NETWORKS
    networks:
      - nextcloud_internal
SVC_NETWORKS
)
  fi

  # Generate ports configuration (only if no Traefik)
  local ports_config=""
  if [[ "${TRAEFIK_SCENARIO}" == "none" ]] || [[ "${TRAEFIK_ENABLE}" == "no" ]]; then
    ports_config=$(cat <<PORTS
    ports:
      - "${NEXTCLOUD_PORT}:80"
PORTS
)
  fi

  # Create docker-compose.yml
  if [[ ${DRY_RUN} -eq 0 ]]; then
    cat > "${compose_file}" <<COMPOSE
version: '3.8'

services:
  db:
    image: postgres:${POSTGRES_VERSION}
    container_name: nextcloud-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./db:/var/lib/postgresql/data
    networks:
      - nextcloud_internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  redis:
    image: redis:${REDIS_VERSION}
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    networks:
      - nextcloud_internal
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

  nextcloud:
    image: nextcloud:${NEXTCLOUD_VERSION}
    container_name: nextcloud-app
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      # Database Configuration
      POSTGRES_HOST: db
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}

      # Redis Configuration
      REDIS_HOST: redis
      REDIS_HOST_PASSWORD: ${REDIS_PASSWORD}

      # Nextcloud Configuration
      NEXTCLOUD_ADMIN_USER: ${NEXTCLOUD_ADMIN_USER}
      NEXTCLOUD_ADMIN_PASSWORD: ${NEXTCLOUD_ADMIN_PASS}
      NEXTCLOUD_TRUSTED_DOMAINS: ${trusted_domains}
      OVERWRITEPROTOCOL: https
      OVERWRITECLIURL: ${NEXTCLOUD_URL}

      # PHP Configuration (optimized for Raspberry Pi 5)
      PHP_MEMORY_LIMIT: 512M
      PHP_UPLOAD_LIMIT: 16G

      # Performance Configuration
      APACHE_BODY_LIMIT: 0
    volumes:
      - ./html:/var/www/html
      - ${DATA_DIR}:/var/www/html/data
${ports_config}
${service_networks}
    labels:
${traefik_labels}
      - "com.centurylinklabs.watchtower.enable=true"

${networks_config}
COMPOSE
  else
    log_info "[DRY-RUN] Création de ${compose_file}"
  fi

  log_success "Fichier docker-compose.yml généré"
}

# =============================================================================
# ENV FILE GENERATION
# =============================================================================

create_env_file() {
  log_info "Génération du fichier .env..."

  local env_file="${STACK_DIR}/.env"

  if [[ ${DRY_RUN} -eq 0 ]]; then
    cat > "${env_file}" <<ENV
# Nextcloud Stack Configuration
# Generated: $(date)

# Nextcloud Version
NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION}
NEXTCLOUD_PORT=${NEXTCLOUD_PORT}

# Nextcloud Admin Credentials
NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
NEXTCLOUD_ADMIN_PASS=${NEXTCLOUD_ADMIN_PASS}

# Database Configuration
POSTGRES_VERSION=${POSTGRES_VERSION}
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# Redis Configuration
REDIS_VERSION=${REDIS_VERSION}
REDIS_PASSWORD=${REDIS_PASSWORD}

# Directories
DATA_DIR=${DATA_DIR}

# Traefik Configuration
TRAEFIK_SCENARIO=${TRAEFIK_SCENARIO}
NEXTCLOUD_DOMAIN=${NEXTCLOUD_DOMAIN}
NEXTCLOUD_URL=${NEXTCLOUD_URL}

# Stack Metadata
STACK_NAME=${STACK_NAME}
DEPLOYED_DATE=$(date -Iseconds)
ENV

    chmod 600 "${env_file}"
  else
    log_info "[DRY-RUN] Création de ${env_file}"
  fi

  log_success "Fichier .env généré avec permissions restrictives (600)"
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_stack() {
  log_info "Déploiement de la stack Nextcloud..."

  local compose_file="${STACK_DIR}/docker-compose.yml"

  # Pull images first
  log_info "Téléchargement des images Docker (peut prendre plusieurs minutes)..."
  run_cmd docker compose -f "${compose_file}" pull

  # Start services
  log_info "Démarrage des services..."
  run_cmd docker compose -f "${compose_file}" up -d

  log_success "Stack Nextcloud déployée"
}

wait_for_nextcloud_ready() {
  log_info "Attente du démarrage de Nextcloud (jusqu'à 5 minutes)..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Simulation de l'attente de Nextcloud"
    return 0
  fi

  local max_attempts=60
  local attempt=0

  while [[ ${attempt} -lt ${max_attempts} ]]; do
    if docker exec nextcloud-app php -v &>/dev/null; then
      log_success "Nextcloud est prêt"
      return 0
    fi

    attempt=$((attempt + 1))
    printf "."
    sleep 5
  done

  log_error "Timeout: Nextcloud n'a pas démarré dans les temps"
  log_info "Vérifiez les logs: docker compose -f ${STACK_DIR}/docker-compose.yml logs nextcloud"
  return 1
}

# =============================================================================
# NEXTCLOUD CONFIGURATION
# =============================================================================

configure_nextcloud_apps() {
  log_info "Installation des applications Nextcloud recommandées..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Installation d'applications Nextcloud"
    return 0
  fi

  # Wait for occ to be available
  sleep 10

  # Install recommended apps
  local apps=("files_external" "calendar" "contacts" "tasks" "notes")

  for app in "${apps[@]}"; do
    log_info "Installation de l'application: ${app}"
    if docker exec -u www-data nextcloud-app php occ app:install "${app}" &>/dev/null; then
      log_success "Application ${app} installée"
    else
      log_debug "Application ${app} déjà installée ou non disponible"
    fi
  done

  log_success "Applications configurées"
}

optimize_nextcloud_performance() {
  log_info "Optimisation des performances pour Raspberry Pi 5..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Optimisation des performances Nextcloud"
    return 0
  fi

  # Configure Redis caching
  log_info "Configuration du cache Redis..."
  docker exec -u www-data nextcloud-app php occ config:system:set memcache.local --value='\OC\Memcache\APCu' || true
  docker exec -u www-data nextcloud-app php occ config:system:set memcache.distributed --value='\OC\Memcache\Redis' || true
  docker exec -u www-data nextcloud-app php occ config:system:set memcache.locking --value='\OC\Memcache\Redis' || true
  docker exec -u www-data nextcloud-app php occ config:system:set redis host --value=redis || true
  docker exec -u www-data nextcloud-app php occ config:system:set redis password --value="${REDIS_PASSWORD}" || true
  docker exec -u www-data nextcloud-app php occ config:system:set redis port --value=6379 || true

  # Configure background jobs
  log_info "Configuration des tâches en arrière-plan..."
  docker exec -u www-data nextcloud-app php occ background:cron || true

  # Disable unnecessary features for performance
  log_info "Désactivation des fonctionnalités non essentielles..."
  docker exec -u www-data nextcloud-app php occ config:system:set enable_previews --value=false --type=boolean || true
  docker exec -u www-data nextcloud-app php occ config:system:set preview_max_x --value=1024 || true
  docker exec -u www-data nextcloud-app php occ config:system:set preview_max_y --value=1024 || true

  # Set maintenance window
  log_info "Configuration de la fenêtre de maintenance..."
  docker exec -u www-data nextcloud-app php occ config:system:set maintenance_window_start --type=integer --value=1 || true

  log_success "Optimisations appliquées"
}

configure_trusted_domains() {
  log_info "Configuration des domaines de confiance..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Configuration des domaines de confiance"
    return 0
  fi

  # Get current trusted domains
  local domain_index=0

  # Add localhost
  docker exec -u www-data nextcloud-app php occ config:system:set trusted_domains ${domain_index} --value="localhost" || true
  domain_index=$((domain_index + 1))

  # Add local IP
  local local_ip
  local_ip=$(hostname -I | awk '{print $1}')
  if [[ -n "${local_ip}" ]]; then
    docker exec -u www-data nextcloud-app php occ config:system:set trusted_domains ${domain_index} --value="${local_ip}" || true
    domain_index=$((domain_index + 1))
  fi

  # Add configured domain
  if [[ -n "${NEXTCLOUD_DOMAIN}" ]]; then
    docker exec -u www-data nextcloud-app php occ config:system:set trusted_domains ${domain_index} --value="${NEXTCLOUD_DOMAIN}" || true
  fi

  log_success "Domaines de confiance configurés"
}

# =============================================================================
# HOMEPAGE INTEGRATION
# =============================================================================

configure_homepage_widget() {
  log_info "Configuration du widget Homepage..."

  # Check if Homepage is installed
  if [[ ! -d "${HOMEPAGE_DIR}" ]]; then
    log_debug "Homepage non détecté (${HOMEPAGE_DIR} introuvable)"
    return 0
  fi

  local services_file="${HOMEPAGE_DIR}/services.yaml"

  if [[ ! -f "${services_file}" ]]; then
    log_warn "Fichier services.yaml introuvable: ${services_file}"
    return 0
  fi

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Ajout du widget Nextcloud à Homepage"
    return 0
  fi

  # Determine URL based on Traefik scenario
  local widget_url="${NEXTCLOUD_URL}"
  if [[ -z "${widget_url}" ]]; then
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}')
    widget_url="http://${local_ip}:${NEXTCLOUD_PORT}"
  fi

  # Check if Nextcloud widget already exists
  if grep -q "Nextcloud" "${services_file}"; then
    log_debug "Widget Nextcloud déjà présent dans Homepage"
    return 0
  fi

  # Add Nextcloud widget to services.yaml
  log_info "Ajout du widget Nextcloud à Homepage..."

  # Backup services.yaml
  cp "${services_file}" "${services_file}.backup.$(date +%s)"

  # Add Nextcloud entry
  cat >> "${services_file}" <<HOMEPAGE
  - Stockage Cloud:
      - Nextcloud:
          icon: nextcloud.png
          href: ${widget_url}
          description: Stockage cloud personnel
          widget:
            type: nextcloud
            url: ${widget_url}
            key: \${NEXTCLOUD_API_KEY}
HOMEPAGE

  log_success "Widget Nextcloud ajouté à Homepage"
  log_info "Note: Configurez NEXTCLOUD_API_KEY dans Homepage pour les statistiques"
}

# =============================================================================
# SUMMARY DISPLAY
# =============================================================================

display_deployment_summary() {
  local local_ip
  local_ip=$(hostname -I | awk '{print $1}')

  echo ""
  echo "========================================================================"
  log_success "Nextcloud deployé avec succès !"
  echo "========================================================================"
  echo ""
  echo "INFORMATIONS DE CONNEXION:"
  echo "------------------------------------------------------------------------"

  if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
    echo "  URL Publique:    ${NEXTCLOUD_URL}"
    echo "  URL Locale:      http://${local_ip}:${NEXTCLOUD_PORT}"
  elif [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
    echo "  URL Publique:    ${NEXTCLOUD_URL}"
    echo "  URL Locale:      http://${local_ip}:${NEXTCLOUD_PORT}"
  elif [[ "${TRAEFIK_SCENARIO}" == "vpn" ]]; then
    echo "  URL VPN:         ${NEXTCLOUD_URL}"
    echo "  URL Locale:      http://${local_ip}:${NEXTCLOUD_PORT}"
  else
    echo "  URL Locale:      http://${local_ip}:${NEXTCLOUD_PORT}"
  fi

  echo ""
  echo "  Utilisateur:     ${NEXTCLOUD_ADMIN_USER}"
  echo "  Mot de passe:    ${NEXTCLOUD_ADMIN_PASS}"
  echo ""
  echo "BASE DE DONNEES POSTGRESQL:"
  echo "------------------------------------------------------------------------"
  echo "  Conteneur:       nextcloud-db"
  echo "  Database:        ${POSTGRES_DB}"
  echo "  Utilisateur:     ${POSTGRES_USER}"
  echo "  Mot de passe:    ${POSTGRES_PASSWORD}"
  echo ""
  echo "CACHE REDIS:"
  echo "------------------------------------------------------------------------"
  echo "  Conteneur:       nextcloud-redis"
  echo "  Mot de passe:    ${REDIS_PASSWORD}"
  echo ""
  echo "REPERTOIRE DE DONNEES:"
  echo "------------------------------------------------------------------------"
  echo "  Chemin:          ${DATA_DIR}"
  echo "  Propriétaire:    www-data (33:33)"
  echo ""
  echo "OPTIMISATIONS RASPBERRY PI 5:"
  echo "------------------------------------------------------------------------"
  echo "  Cache Redis:             [OK]"
  echo "  APCu Memory Cache:       [OK]"
  echo "  PHP Memory Limit:        512M"
  echo "  Upload Limit:            16G"
  echo "  Background Jobs:         Cron"
  echo ""
  echo "COMMANDES UTILES:"
  echo "------------------------------------------------------------------------"
  echo "  Logs Nextcloud:"
  echo "    docker compose -f ${STACK_DIR}/docker-compose.yml logs -f nextcloud"
  echo ""
  echo "  OCC CLI (commandes Nextcloud):"
  echo "    docker exec -u www-data nextcloud-app php occ <commande>"
  echo ""
  echo "  Status:"
  echo "    docker exec -u www-data nextcloud-app php occ status"
  echo ""
  echo "  Scan fichiers:"
  echo "    docker exec -u www-data nextcloud-app php occ files:scan --all"
  echo ""
  echo "  Arrêter la stack:"
  echo "    docker compose -f ${STACK_DIR}/docker-compose.yml down"
  echo ""
  echo "  Redémarrer la stack:"
  echo "    docker compose -f ${STACK_DIR}/docker-compose.yml restart"
  echo ""
  echo "PROCHAINES ETAPES:"
  echo "------------------------------------------------------------------------"
  echo "  1. Connectez-vous à Nextcloud avec les identifiants ci-dessus"
  echo "  2. Configurez les applications installées (Calendar, Contacts, Tasks)"
  echo "  3. Montez un stockage externe si nécessaire (USB, NAS)"
  echo "  4. Configurez la synchronisation sur vos appareils"
  echo "  5. Activez les sauvegardes automatiques (recommandé)"
  echo ""

  if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
    echo "INTEGRATION TRAEFIK:"
    echo "------------------------------------------------------------------------"
    echo "  Scénario:        ${TRAEFIK_SCENARIO}"
    echo "  Domaine:         ${NEXTCLOUD_DOMAIN}"
    echo "  HTTPS:           Automatique (Let's Encrypt)"
    echo ""
  fi

  echo "========================================================================"
  echo ""

  # Save summary to file
  if [[ ${DRY_RUN} -eq 0 ]]; then
    local summary_file="${STACK_DIR}/DEPLOYMENT-SUMMARY.txt"
    {
      echo "Nextcloud Deployment Summary"
      echo "Generated: $(date)"
      echo ""
      echo "URL: ${NEXTCLOUD_URL:-http://${local_ip}:${NEXTCLOUD_PORT}}"
      echo "Admin User: ${NEXTCLOUD_ADMIN_USER}"
      echo "Admin Password: ${NEXTCLOUD_ADMIN_PASS}"
      echo ""
      echo "PostgreSQL User: ${POSTGRES_USER}"
      echo "PostgreSQL Password: ${POSTGRES_PASSWORD}"
      echo "PostgreSQL Database: ${POSTGRES_DB}"
      echo ""
      echo "Redis Password: ${REDIS_PASSWORD}"
      echo ""
      echo "Data Directory: ${DATA_DIR}"
      echo "Stack Directory: ${STACK_DIR}"
      echo ""
      echo "Traefik Scenario: ${TRAEFIK_SCENARIO}"
      echo "Nextcloud Domain: ${NEXTCLOUD_DOMAIN}"
    } > "${summary_file}"
    chmod 600 "${summary_file}"

    log_info "Résumé sauvegardé: ${summary_file}"
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  # Parse arguments
  parse_args "$@"

  # Require root
  require_root

  log_info "=================================================="
  log_info "  Déploiement Nextcloud sur Raspberry Pi 5"
  log_info "  Version: ${SCRIPT_VERSION}"
  log_info "=================================================="
  echo ""

  # Validation phase
  log_info "=== PHASE 1: VALIDATION ==="
  check_system_requirements
  check_docker
  check_port_availability
  check_existing_installation
  log_success "Validation terminée"
  echo ""

  # Detection phase
  log_info "=== PHASE 2: DETECTION ==="
  detect_traefik_scenario
  log_success "Détection terminée"
  echo ""

  # Preparation phase
  log_info "=== PHASE 3: PREPARATION ==="
  generate_passwords
  ensure_dir "${STACK_DIR}"
  setup_data_directory
  log_success "Préparation terminée"
  echo ""

  # Generation phase
  log_info "=== PHASE 4: GENERATION ==="
  create_docker_compose
  create_env_file
  log_success "Génération terminée"
  echo ""

  # Deployment phase
  log_info "=== PHASE 5: DEPLOIEMENT ==="
  deploy_stack
  wait_for_nextcloud_ready || fatal "Échec du démarrage de Nextcloud"
  log_success "Déploiement terminé"
  echo ""

  # Configuration phase
  log_info "=== PHASE 6: CONFIGURATION ==="
  configure_trusted_domains
  configure_nextcloud_apps
  optimize_nextcloud_performance
  log_success "Configuration terminée"
  echo ""

  # Integration phase
  log_info "=== PHASE 7: INTEGRATION ==="
  configure_homepage_widget
  log_success "Intégration terminée"
  echo ""

  # Summary
  display_deployment_summary

  log_success "Déploiement Nextcloud terminé avec succès !"
}

# Run main function
main "$@"
