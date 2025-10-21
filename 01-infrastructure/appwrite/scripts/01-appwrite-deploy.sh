#!/usr/bin/env bash
#
# Appwrite Deployment Script - Alternative Backend-as-a-Service
# Alternative/Complément à Supabase pour Raspberry Pi 5
#
# Source officielle : https://github.com/appwrite/appwrite
# Documentation : https://appwrite.io/docs/advanced/self-hosting
#
# Appwrite fournit :
# - Auth (Email, OAuth, Anonymous, Phone, Magic URL)
# - Database (NoSQL document-based avec relations)
# - Storage (S3-compatible)
# - Functions (Serverless - multiple runtimes)
# - Realtime (WebSockets)
# - Messaging (Email, SMS, Push)
#
# Avantages vs Supabase sur Pi 5 :
# - Plus léger : 1.5-2GB RAM vs 4-6GB
# - ARM64 natif parfait (aucun problème page size)
# - NoSQL flexible (vs PostgreSQL strict)
# - Installation simple
#
# Ce script est IDEMPOTENT : peut être exécuté plusieurs fois

set -euo pipefail

# Détection automatique de lib.sh (support émulateur + Pi physique)
if [[ -f "/tmp/common-scripts/lib.sh" ]]; then
    # Mode uploadé (émulateur ou Pi via PI5 Control Center)
    source "/tmp/common-scripts/lib.sh"
elif [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    # Mode local (clonage direct du repo)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
    source "${PROJECT_ROOT}/common-scripts/lib.sh"
else
    echo "❌ Erreur : lib.sh introuvable"
    exit 1
fi

STACK_NAME="appwrite"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"

TRAEFIK_ENV="${HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

detect_traefik_scenario() {
    [[ ! -f "${TRAEFIK_ENV}" ]] && return

    if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="duckdns"
        DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "VPN_MODE" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="vpn"
    fi
}

generate_secrets() {
    local secret_key=$(openssl rand -hex 32)
    local executor_secret=$(openssl rand -hex 32)

    echo "${secret_key}:${executor_secret}"
}

create_appwrite_env() {
    log_info "Génération configuration Appwrite..."

    local secrets
    local secret_key
    local executor_secret
    local hostname

    if [[ -f "${ENV_FILE}" ]] && grep -q "^_APP_SYSTEM_SECURITY_EMAIL_ADDRESS=" "${ENV_FILE}"; then
        log_info "Configuration existante détectée, préservation secrets..."
        secret_key=$(grep "^_APP_OPENSSL_KEY_V1=" "${ENV_FILE}" | cut -d'=' -f2)
        executor_secret=$(grep "^_APP_EXECUTOR_SECRET=" "${ENV_FILE}" | cut -d'=' -f2)
    else
        secrets=$(generate_secrets)
        secret_key="${secrets%%:*}"
        executor_secret="${secrets##*:}"
    fi

    # Déterminer hostname selon scénario Traefik
    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            hostname="appwrite.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            hostname="appwrite.${DOMAIN}"
            ;;
        *)
            hostname="raspberrypi.local"
            ;;
    esac

    cat > "${ENV_FILE}" <<EOF
# Appwrite Configuration
# Généré le $(date)

# System
_APP_ENV=production
_APP_WORKER_PER_CORE=6
_APP_LOCALE=fr
_APP_OPTIONS_ABUSE=enabled
_APP_OPTIONS_FORCE_HTTPS=disabled

# Endpoint
_APP_DOMAIN=${hostname}
_APP_DOMAIN_TARGET=${hostname}
_APP_SYSTEM_SECURITY_EMAIL_ADDRESS=admin@${hostname}

# Redis
_APP_REDIS_HOST=redis
_APP_REDIS_PORT=6379

# MariaDB
_APP_DB_HOST=mariadb
_APP_DB_PORT=3306
_APP_DB_SCHEMA=appwrite
_APP_DB_USER=appwrite
_APP_DB_PASS=$(openssl rand -base64 32 | tr -d '/+=')

# InfluxDB (Metrics)
_APP_INFLUXDB_HOST=influxdb
_APP_INFLUXDB_PORT=8086

# Secrets
_APP_OPENSSL_KEY_V1=${secret_key}
_APP_EXECUTOR_SECRET=${executor_secret}

# Storage
_APP_STORAGE_LIMIT=30000000000
_APP_STORAGE_PREVIEW_LIMIT=20000000
_APP_STORAGE_ANTIVIRUS=disabled
_APP_STORAGE_ANTIVIRUS_HOST=clamav
_APP_STORAGE_ANTIVIRUS_PORT=3310

# Functions
_APP_FUNCTIONS_SIZE_LIMIT=30000000
_APP_FUNCTIONS_TIMEOUT=900
_APP_FUNCTIONS_BUILD_TIMEOUT=900
_APP_FUNCTIONS_CONTAINERS=10
_APP_FUNCTIONS_CPUS=1
_APP_FUNCTIONS_MEMORY=512
_APP_FUNCTIONS_MEMORY_SWAP=512
_APP_FUNCTIONS_RUNTIMES=node-18.0,php-8.2,python-3.11,ruby-3.1,deno-1.40

# Executor
_APP_EXECUTOR_RUNTIME_NETWORK=appwrite-runtimes

# Maintenance
_APP_MAINTENANCE_INTERVAL=86400
_APP_MAINTENANCE_RETENTION_EXECUTION=1209600
_APP_MAINTENANCE_RETENTION_CACHE=2592000
_APP_MAINTENANCE_RETENTION_ABUSE=86400
_APP_MAINTENANCE_RETENTION_AUDIT=1209600

# Usage Stats
_APP_USAGE_STATS=enabled

# Logging
_APP_LOGGING_PROVIDER=
_APP_LOGGING_CONFIG=
EOF

    chmod 600 "${ENV_FILE}"
    log_success "Configuration créée"
}

create_docker_compose() {
    log_info "Création docker-compose.yml..."

    # Télécharger docker-compose officiel Appwrite
    curl -fsSL https://appwrite.io/install/compose -o "${COMPOSE_FILE}"

    # Modifier pour ARM64 et intégration Traefik
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        log_info "Configuration intégration Traefik..."

        # Ajouter réseau Traefik
        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  gateway:
    external: true
    name: traefik-network
  appwrite:
    name: appwrite
EOF

        # Ajouter labels Traefik au service appwrite (port 80)
        # Note: Appwrite expose déjà port 80 et 443 en interne
        local hostname
        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                hostname="appwrite.${DUCKDNS_SUBDOMAIN}.duckdns.org"
                ;;
            cloudflare)
                hostname="appwrite.${DOMAIN}"
                ;;
        esac

        # On va créer un override pour ajouter les labels
        cat > "${STACK_DIR}/docker-compose.override.yml" <<EOF
version: '3'

services:
  appwrite:
    networks:
      - appwrite
      - gateway
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.appwrite.loadbalancer.server.port=80"
      - "traefik.http.routers.appwrite.rule=Host(\\\`${hostname}\\\`)"
      - "traefik.http.routers.appwrite.entrypoints=websecure"
      - "traefik.http.routers.appwrite.tls.certresolver=letsencrypt"
EOF
    fi

    log_success "docker-compose.yml créé"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Appwrite:" "${homepage_config}"; then
        log_info "Appwrite déjà dans Homepage"
        return
    fi

    log_info "Ajout à Homepage..."

    local appwrite_url
    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            appwrite_url="https://appwrite.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            appwrite_url="https://appwrite.${DOMAIN}"
            ;;
        *)
            appwrite_url="http://raspberrypi.local:80"
            ;;
    esac

    cat >> "${homepage_config}" <<EOF

- Infrastructure:
    - Appwrite:
        href: ${appwrite_url}
        description: Backend-as-a-Service (Alternative Supabase)
        icon: appwrite.png
EOF

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Ajouté à Homepage"
}

configure_backups() {
    log_info "Configuration backups Appwrite..."

    local backup_script="${HOME}/bin/backup-appwrite.sh"
    mkdir -p "${HOME}/bin"

    cat > "${backup_script}" <<'BACKUP_SCRIPT'
#!/bin/bash
# Backup Appwrite - GFS rotation

set -euo pipefail

BACKUP_DIR="${HOME}/backups/appwrite"
STACK_DIR="${HOME}/stacks/appwrite"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "${BACKUP_DIR}"/{daily,weekly,monthly}

cd "${STACK_DIR}" || exit 1

# Stop containers temporairement
docker-compose stop

# Backup MariaDB
docker-compose exec -T mariadb mysqldump -u appwrite -p"$(grep DB_PASS .env | cut -d'=' -f2)" appwrite > "${BACKUP_DIR}/daily/appwrite_db_${TIMESTAMP}.sql"

# Backup volumes (uploads, cache, config, certificates)
tar -czf "${BACKUP_DIR}/daily/appwrite_volumes_${TIMESTAMP}.tar.gz" \
    appwrite-mariadb \
    appwrite-redis \
    appwrite-cache \
    appwrite-uploads \
    appwrite-certificates \
    appwrite-functions \
    appwrite-builds \
    appwrite-influxdb \
    appwrite-config 2>/dev/null || true

# Backup config
tar -czf "${BACKUP_DIR}/daily/appwrite_config_${TIMESTAMP}.tar.gz" \
    docker-compose.yml .env

# Restart containers
docker-compose start

# GFS Rotation
find "${BACKUP_DIR}/daily" -name "*.sql" -mtime +7 -delete
find "${BACKUP_DIR}/daily" -name "*.tar.gz" -mtime +7 -delete

# Copy to weekly (dimanche)
if [[ $(date +%u) -eq 7 ]]; then
    cp "${BACKUP_DIR}/daily/appwrite_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/weekly/" || true
    cp "${BACKUP_DIR}/daily/appwrite_volumes_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/weekly/" || true
fi

# Copy to monthly (1er du mois)
if [[ $(date +%d) -eq 01 ]]; then
    cp "${BACKUP_DIR}/daily/appwrite_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/monthly/" || true
    cp "${BACKUP_DIR}/daily/appwrite_volumes_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/monthly/" || true
fi

echo "✅ Backup Appwrite terminé: ${TIMESTAMP}"
BACKUP_SCRIPT

    chmod +x "${backup_script}"

    # Ajouter cron (4h du matin)
    (crontab -l 2>/dev/null || true; echo "0 4 * * * ${backup_script}") | crontab -

    log_success "Backups configurés (daily 4h)"
}

main() {
    print_header "Appwrite - Alternative Backend-as-a-Service"

    echo ""
    log_info "📦 Appwrite vs Supabase :"
    echo "  ✅ Plus léger : 1.5-2GB RAM vs 4-6GB"
    echo "  ✅ ARM64 parfait (aucun problème)"
    echo "  ✅ NoSQL flexible + Relations"
    echo "  ✅ Auth + DB + Storage + Functions + Realtime"
    echo ""
    log_info "💡 Peut cohabiter avec Supabase !"
    echo ""

    # Check RAM
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 4 ]]; then
        log_error "Appwrite nécessite minimum 4GB RAM"
        log_warn "Votre système : ${total_ram}GB"
        exit 1
    fi

    local available_ram
    available_ram=$(free -g | awk '/^Mem:/{print $7}')

    if [[ ${available_ram} -lt 2 ]]; then
        log_warn "RAM disponible faible : ${available_ram}GB"
        log_warn "Appwrite nécessite ~2GB RAM"
        read -p "Continuer quand même? (y/n): " -n 1 -r
        echo ""
        [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi

    mkdir -p "${STACK_DIR}"
    cd "${STACK_DIR}" || exit 1

    detect_traefik_scenario
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        log_info "Traefik détecté: ${TRAEFIK_SCENARIO}"
    fi

    create_appwrite_env
    create_docker_compose

    log_info "Téléchargement images Docker ARM64 (5-10 min)..."
    log_warn "Appwrite va télécharger ~15 images Docker, patience..."

    docker-compose pull

    log_info "Démarrage Appwrite..."
    docker-compose up -d

    log_info "Attente initialisation (90s)..."
    sleep 90

    # Vérifier démarrage
    if docker ps | grep -q "appwrite"; then
        log_success "Appwrite démarré !"
    else
        log_error "Échec démarrage Appwrite"
        log_info "Vérifier logs : docker-compose -f ${COMPOSE_FILE} logs"
        exit 1
    fi

    update_homepage
    configure_backups

    echo ""
    print_section "✅ Appwrite Installé !"
    echo ""
    echo "🌐 Accès Console :"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            echo "  URL : https://appwrite.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            echo "  URL : https://appwrite.${DOMAIN}"
            ;;
        *)
            echo "  URL : http://raspberrypi.local"
            ;;
    esac

    echo ""
    echo "👤 Premier accès :"
    echo "  1. Créer compte admin (premier utilisateur = admin)"
    echo "  2. Créer projet"
    echo "  3. Obtenir API keys dans Settings → API Keys"
    echo ""
    echo "📚 Documentation :"
    echo "  - Quick Start : https://appwrite.io/docs/quick-starts"
    echo "  - SDKs : Web, Flutter, iOS, Android, React Native"
    echo "  - API Reference : https://appwrite.io/docs/references"
    echo ""
    echo "💾 Backups :"
    echo "  - Automatiques : Daily 4h (GFS rotation)"
    echo "  - Emplacement : ~/backups/appwrite/"
    echo "  - Manuel : ~/bin/backup-appwrite.sh"
    echo ""
    echo "📂 Installation :"
    echo "  - Dossier : ${STACK_DIR}"
    echo "  - Config : ${ENV_FILE}"
    echo ""
    echo "🔧 Commandes :"
    echo "  cd ${STACK_DIR}"
    echo "  docker-compose logs -f        # Logs"
    echo "  docker-compose restart        # Redémarrer"
    echo "  docker-compose down           # Arrêter"
    echo ""
    echo "📊 Ressources :"
    echo "  RAM : ~1.5-2GB"
    echo "  Stockage : ~/stacks/appwrite/"
    echo ""
    echo "🔄 Cohabitation avec Supabase :"
    echo "  ✅ Ports différents (aucun conflit)"
    echo "  ✅ Supabase : SQL relationnel"
    echo "  ✅ Appwrite : NoSQL + features rapides"
    echo ""

    log_success "Installation terminée ! 🎉"
}

main "$@"
