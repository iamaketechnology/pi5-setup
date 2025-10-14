#!/bin/bash
# =============================================================================
# n8n Deployment - Workflow Automation with AI Integration
# =============================================================================
# Version: 1.1.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 01-n8n-deploy.sh
# =============================================================================
# Automatisation no-code avec intégrations IA (Ollama, OpenAI, webhooks)
# Source officielle : https://github.com/n8n-io/n8n
# Documentation : https://docs.n8n.io/
# Ce script est IDEMPOTENT
# =============================================================================

set -euo pipefail

# === Logging functions ===
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# === Detect current user ===
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

# === Configuration ===
STACK_NAME="n8n"
STACK_DIR="${USER_HOME}/stacks/${STACK_NAME}"
DATA_DIR="${USER_HOME}/data/n8n"

TRAEFIK_ENV="${USER_HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

# === Check root ===
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être lancé avec sudo"
    exit 1
fi

detect_traefik_scenario() {
    [[ ! -f "${TRAEFIK_ENV}" ]] && return
    if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="duckdns"
        DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    fi
}

create_env() {
    local encryption_key=$(openssl rand -hex 32)
    local webhook_url="http://raspberrypi.local:5678"
    local secure_cookie="false"

    if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
        webhook_url="https://n8n.${DUCKDNS_SUBDOMAIN}.duckdns.org"
        secure_cookie="true"
    elif [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
        webhook_url="https://n8n.${DOMAIN}"
        secure_cookie="true"
    fi

    cat > "${STACK_DIR}/.env" <<EOF
# n8n Configuration
N8N_ENCRYPTION_KEY=${encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -hex 32)
WEBHOOK_URL=${webhook_url}
N8N_SECURE_COOKIE=${secure_cookie}

# PostgreSQL
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$(openssl rand -base64 24)
POSTGRES_DB=n8n

# Timezone
GENERIC_TIMEZONE=Europe/Paris
TZ=Europe/Paris
EOF
    chmod 600 "${STACK_DIR}/.env"
}

create_compose() {
    cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - ./postgres:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -h localhost -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 10

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "5678:5678"
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_USER_MANAGEMENT_JWT_SECRET=${N8N_USER_MANAGEMENT_JWT_SECRET}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - TZ=${TZ}
      - N8N_LOG_LEVEL=info
    volumes:
      - ./data:/home/node/.n8n
      - ./files:/files
EOF

    # Traefik (vérifier que le réseau existe)
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]] && docker network ls | grep -q "traefik_network"; then
        cat >> "${STACK_DIR}/docker-compose.yml" <<'EOF'
    networks:
      - default
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"
EOF

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                echo "      - \"traefik.http.routers.n8n.rule=Host(\`n8n.${DUCKDNS_SUBDOMAIN}.duckdns.org\`)\"" >> "${STACK_DIR}/docker-compose.yml"
                ;;
            cloudflare)
                echo "      - \"traefik.http.routers.n8n.rule=Host(\`n8n.${DOMAIN}\`)\"" >> "${STACK_DIR}/docker-compose.yml"
                ;;
        esac

        cat >> "${STACK_DIR}/docker-compose.yml" <<'EOF'
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"

networks:
  default:
    name: n8n_network
  traefik_network:
    external: true
EOF
    else
        cat >> "${STACK_DIR}/docker-compose.yml" <<'EOF'

networks:
  default:
    name: n8n_network
EOF
    fi
}

update_homepage() {
    local homepage_config="${USER_HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if ! grep -q "n8n:" "${homepage_config}"; then
        log_info "Ajout n8n au dashboard Homepage..."
        cat >> "${homepage_config}" <<EOF

- Intelligence Artificielle:
    - n8n:
        href: http://raspberrypi.local:5678
        description: Automatisation workflows + IA
        icon: n8n.png
EOF
        docker restart homepage >/dev/null 2>&1 || true
        log_success "n8n ajouté au dashboard"
    fi
}

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  n8n - Workflow Automation + IA"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Vérifier si déjà installé (idempotent)
    if docker ps --format '{{.Names}}' | grep -q "^n8n$"; then
        log_success "n8n déjà installé"
        docker ps --filter "name=n8n" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "🔧 Accès : http://raspberrypi.local:5678"
        return 0
    fi

    mkdir -p "${STACK_DIR}" "${DATA_DIR}"
    cd "${STACK_DIR}"

    detect_traefik_scenario
    create_env
    create_compose

    log_info "Déploiement n8n..."
    docker compose up -d

    # FIX: Corriger permissions volumes (UID 1000 = user node dans container)
    log_info "Configuration permissions..."
    chown -R 1000:1000 "${STACK_DIR}/data" "${STACK_DIR}/files" 2>/dev/null || true

    log_info "Attente démarrage (30s)..."
    sleep 30

    # Vérifier healthcheck
    if ! docker ps --filter "name=n8n" --filter "status=running" | grep -q "n8n"; then
        log_error "n8n n'a pas démarré correctement"
        docker logs n8n --tail 50
        return 1
    fi

    update_homepage

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 N8N INSTALLÉ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔧 Accès local : http://raspberrypi.local:5678"
    [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]] && echo "🌐 Accès public : https://n8n.${DUCKDNS_SUBDOMAIN}.duckdns.org"
    [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]] && echo "🌐 Accès public : https://n8n.${DOMAIN}"
    echo ""
    echo "👤 Première connexion :"
    echo "   - Créer compte propriétaire"
    echo "   - Configurer email"
    echo ""
    echo "💡 Workflows exemples :"
    echo "   - Templates disponibles dans l'interface"
    echo "   - Intégrations : Ollama, OpenAI, webhooks"
    echo ""
    echo "📊 RAM utilisée : ~200 MB"
    echo "📁 Config : ${STACK_DIR}"
    echo "💾 Données : ${STACK_DIR}/data"
}

main "$@"
