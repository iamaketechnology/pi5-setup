#!/usr/bin/env bash
#
# n8n Workflow Automation + IA - Phase 22
# Automatisation no-code avec intégrations IA
#
# Source officielle : https://github.com/n8n-io/n8n
# Documentation : https://docs.n8n.io/
#
# Ce script est IDEMPOTENT

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${PROJECT_ROOT}/common-scripts/lib.sh"

STACK_NAME="n8n"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
DATA_DIR="${HOME}/data/n8n"

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
    fi
}

create_env() {
    local encryption_key=$(openssl rand -hex 32)
    local webhook_url="http://raspberrypi.local:5678"

    [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]] && webhook_url="https://n8n.${DUCKDNS_SUBDOMAIN}.duckdns.org"
    [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]] && webhook_url="https://n8n.${DOMAIN}"

    cat > "${STACK_DIR}/.env" <<EOF
# n8n Configuration
N8N_ENCRYPTION_KEY=${encryption_key}
N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -hex 32)
WEBHOOK_URL=${webhook_url}

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
version: '3.8'

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

    # Traefik
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${STACK_DIR}/docker-compose.yml" <<'EOF'
    networks:
      - default
      - traefik-network
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
    name: n8n-network
  traefik-network:
    external: true
EOF
    fi
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if ! grep -q "n8n:" "${homepage_config}"; then
        cat >> "${homepage_config}" <<EOF

- Intelligence Artificielle:
    - n8n:
        href: http://raspberrypi.local:5678
        description: Automatisation workflows + IA
        icon: n8n.png
EOF
        docker restart homepage >/dev/null 2>&1 || true
    fi
}

main() {
    print_header "n8n - Workflow Automation + IA"

    mkdir -p "${STACK_DIR}" "${DATA_DIR}"
    cd "${STACK_DIR}"

    detect_traefik_scenario
    create_env
    create_compose

    log_info "Déploiement n8n..."
    docker-compose up -d

    sleep 30

    echo ""
    log_success "n8n installé !"
    echo ""
    echo "🔧 Accès : http://raspberrypi.local:5678"
    echo ""
    echo "👤 Première connexion :"
    echo "   - Créer compte propriétaire"
    echo "   - Configurer email"
    echo ""
    echo "💡 Workflows exemples :"
    echo "   - Templates disponibles dans l'interface"
    echo "   - Intégrations : Ollama, OpenAI, webhooks"
    echo ""
    echo "📊 RAM : ~200 MB"
}

main "$@"
