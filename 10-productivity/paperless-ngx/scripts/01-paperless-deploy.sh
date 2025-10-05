#!/usr/bin/env bash
# Paperless-ngx - Phase 14
# Gestion documents avec OCR automatique
# Source: https://github.com/paperless-ngx/paperless-ngx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${PROJECT_ROOT}/common-scripts/lib.sh"

STACK_NAME="paperless"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
DATA_DIR="${HOME}/data/paperless"

create_env() {
    local secret_key=$(openssl rand -base64 32)
    local admin_user="admin"
    local admin_pass=$(openssl rand -base64 16)

    cat > "${STACK_DIR}/.env" <<EOF
PAPERLESS_SECRET_KEY=${secret_key}
PAPERLESS_ADMIN_USER=${admin_user}
PAPERLESS_ADMIN_PASSWORD=${admin_pass}
PAPERLESS_TIME_ZONE=Europe/Paris
PAPERLESS_OCR_LANGUAGE=fra+eng
PAPERLESS_URL=http://raspberrypi.local:8000
EOF
    chmod 600 "${STACK_DIR}/.env"
}

create_compose() {
    cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  broker:
    image: redis:7-alpine
    container_name: paperless-redis
    restart: unless-stopped
    volumes:
      - ./redis:/data

  db:
    image: postgres:15-alpine
    container_name: paperless-db
    restart: unless-stopped
    volumes:
      - ./pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: paperless
      POSTGRES_USER: paperless
      POSTGRES_PASSWORD: paperless

  webserver:
    image: ghcr.io/paperless-ngx/paperless-ngx:latest
    container_name: paperless-ngx
    restart: unless-stopped
    depends_on:
      - db
      - broker
    ports:
      - "8000:8000"
    volumes:
      - ./data:/usr/src/paperless/data
      - ./media:/usr/src/paperless/media
      - ./export:/usr/src/paperless/export
      - ./consume:/usr/src/paperless/consume
    env_file: .env
    environment:
      PAPERLESS_REDIS: redis://broker:6379
      PAPERLESS_DBHOST: db
      PAPERLESS_DBUSER: paperless
      PAPERLESS_DBPASS: paperless
      PAPERLESS_DBNAME: paperless
EOF
}

main() {
    print_header "Paperless-ngx - Gestion Documents + OCR"

    mkdir -p "${STACK_DIR}" "${DATA_DIR}"/{data,media,export,consume}
    cd "${STACK_DIR}"

    create_env
    create_compose

    log_info "Déploiement Paperless-ngx..."
    docker-compose up -d

    sleep 30

    echo ""
    log_success "Paperless-ngx installé !"
    echo ""
    echo "📄 Accès : http://raspberrypi.local:8000"
    echo "👤 Login : $(grep ADMIN_USER .env | cut -d= -f2)"
    echo "🔑 Pass  : $(grep ADMIN_PASSWORD .env | cut -d= -f2)"
    echo ""
    echo "📂 Dossier documents à scanner :"
    echo "   ${DATA_DIR}/consume/"
    echo ""
    echo "💡 Déposer PDF/images → OCR automatique → Archivage"
}

main "$@"
