#!/usr/bin/env bash
#
# Immich Deployment Script - Phase 13
# Google Photos Alternative avec AI (reconnaissance faciale, objets)
#
# Source officielle : https://github.com/immich-app/immich
# Documentation : https://immich.app/docs/install/docker-compose/
#
# Ce script est IDEMPOTENT : peut être exécuté plusieurs fois sans problème
#
# Note: Immich nécessite ~2GB RAM minimum (avec ML). Pour Pi 5 8GB, recommandé désactiver ML.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COMMON_SCRIPTS_DIR="${PROJECT_ROOT}/common-scripts"

if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
    source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
    echo "❌ Erreur : ${COMMON_SCRIPTS_DIR}/lib.sh introuvable"
    exit 1
fi

STACK_NAME="immich"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"
UPLOAD_DIR="${HOME}/data/immich/upload"
LIBRARY_DIR="${HOME}/data/immich/library"

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

create_immich_env() {
    local db_password
    local jwt_secret

    if [[ -f "${ENV_FILE}" ]] && grep -q "^DB_PASSWORD=" "${ENV_FILE}"; then
        db_password=$(grep "^DB_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)
        jwt_secret=$(grep "^JWT_SECRET=" "${ENV_FILE}" | cut -d'=' -f2)
    else
        db_password=$(openssl rand -base64 32 | tr -d '/+=')
        jwt_secret=$(openssl rand -base64 48)
    fi

    cat > "${ENV_FILE}" <<EOF
# Immich Configuration
# Généré le $(date)

# Database
DB_PASSWORD=${db_password}
DB_USERNAME=postgres
DB_DATABASE_NAME=immich

# Immich Version
IMMICH_VERSION=release

# Upload Directory
UPLOAD_LOCATION=${UPLOAD_DIR}

# Machine Learning (désactiver pour économiser RAM sur Pi)
# true = AI activé (~1.5GB RAM), false = désactivé (~500MB RAM)
ML_ENABLED=false

# JWT Secret
JWT_SECRET=${jwt_secret}

# Log Level
LOG_LEVEL=log

# Public URL
PUBLIC_URL=http://raspberrypi.local:2283
EOF

    chmod 600 "${ENV_FILE}"
    log_success "Configuration créée"
}

create_docker_compose() {
    cat > "${COMPOSE_FILE}" <<'EOF'
version: '3.8'

services:
  immich-server:
    container_name: immich-server
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    command: ['start.sh', 'immich']
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    ports:
      - 2283:3001
    depends_on:
      - redis
      - database
    restart: unless-stopped

  immich-microservices:
    container_name: immich-microservices
    image: ghcr.io/immich-app/immich-server:${IMMICH_VERSION:-release}
    command: ['start.sh', 'microservices']
    volumes:
      - ${UPLOAD_LOCATION}:/usr/src/app/upload
      - /etc/localtime:/etc/localtime:ro
    env_file:
      - .env
    depends_on:
      - redis
      - database
    restart: unless-stopped

  redis:
    container_name: immich-redis
    image: redis:7-alpine
    restart: unless-stopped

  database:
    container_name: immich-postgres
    image: tensorchord/pgvecto-rs:pg14-v0.2.0
    env_file:
      - .env
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_USER: ${DB_USERNAME}
      POSTGRES_DB: ${DB_DATABASE_NAME}
    volumes:
      - ./postgres:/var/lib/postgresql/data
    restart: unless-stopped
EOF

    # Ajouter ML si activé
    if grep -q "ML_ENABLED=true" "${ENV_FILE}"; then
        cat >> "${COMPOSE_FILE}" <<'EOF'

  immich-machine-learning:
    container_name: immich-machine-learning
    image: ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION:-release}
    volumes:
      - ./model-cache:/cache
    env_file:
      - .env
    restart: unless-stopped
EOF
    fi

    # Traefik
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  default:
    name: immich-network
  traefik-network:
    external: true
EOF

        # Ajouter labels selon scénario
        sed -i '' '/immich-server:/a\
    networks:\
      - default\
      - traefik-network\
    labels:\
      - "traefik.enable=true"\
      - "traefik.http.services.immich.loadbalancer.server.port=3001"
' "${COMPOSE_FILE}"

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                sed -i '' '/traefik.http.services.immich/a\
      - "traefik.http.routers.immich.rule=Host(`photos.'"${DUCKDNS_SUBDOMAIN}"'.duckdns.org`)"\
      - "traefik.http.routers.immich.entrypoints=websecure"\
      - "traefik.http.routers.immich.tls.certresolver=letsencrypt"
' "${COMPOSE_FILE}"
                ;;
            cloudflare)
                sed -i '' '/traefik.http.services.immich/a\
      - "traefik.http.routers.immich.rule=Host(`photos.'"${DOMAIN}"'`)"\
      - "traefik.http.routers.immich.entrypoints=websecure"\
      - "traefik.http.routers.immich.tls.certresolver=letsencrypt"
' "${COMPOSE_FILE}"
                ;;
        esac
    fi

    log_success "docker-compose.yml créé"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Immich:" "${homepage_config}"; then
        return
    fi

    cat >> "${homepage_config}" <<EOF

- Productivité:
    - Immich:
        href: http://raspberrypi.local:2283
        description: Photos (Google Photos alternative)
        icon: immich.png
EOF

    docker restart homepage >/dev/null 2>&1 || true
}

main() {
    print_header "Immich - Google Photos Alternative avec AI"

    log_info "Installation Immich Phase 13..."
    echo ""

    # Check RAM
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 4 ]]; then
        log_error "Immich nécessite minimum 4GB RAM"
        log_warn "Votre système : ${total_ram}GB"
        exit 1
    fi

    mkdir -p "${STACK_DIR}" "${UPLOAD_DIR}" "${LIBRARY_DIR}"
    cd "${STACK_DIR}" || exit 1

    detect_traefik_scenario
    create_immich_env
    create_docker_compose

    log_info "Déploiement Immich (ceci peut prendre 2-3 minutes)..."
    docker-compose up -d

    log_info "Attente démarrage Immich (60s)..."
    sleep 60

    if docker ps | grep -q "immich-server"; then
        log_success "Immich démarré !"
    else
        log_error "Échec démarrage"
        docker-compose logs
        exit 1
    fi

    update_homepage

    echo ""
    print_section "Immich Installé !"
    echo ""
    echo "📸 Accès :"
    echo "  URL : http://raspberrypi.local:2283"
    echo ""
    echo "📱 Apps Mobiles :"
    echo "  - iOS : https://apps.apple.com/app/immich/id1613945652"
    echo "  - Android : https://play.google.com/store/apps/details?id=app.alextran.immich"
    echo ""
    echo "⚙️  Configuration Apps :"
    echo "  Server URL : http://raspberrypi.local:2283"
    echo ""
    echo "📊 Ressources :"
    echo "  RAM : ~500MB (ML désactivé) ou ~2GB (ML activé)"
    echo "  Stockage : ${UPLOAD_DIR}"
    echo ""
    echo "🔧 Activer ML (reconnaissance faciale) :"
    echo "  1. Éditer ${ENV_FILE}"
    echo "  2. ML_ENABLED=true"
    echo "  3. docker-compose up -d"
    echo ""

    log_success "Installation terminée !"
}

main "$@"
