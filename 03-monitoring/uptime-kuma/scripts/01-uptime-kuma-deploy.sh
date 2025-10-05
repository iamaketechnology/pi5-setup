#!/usr/bin/env bash
# Uptime Kuma - Phase 15
# Monitoring uptime services
# Source: https://github.com/louislam/uptime-kuma

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${PROJECT_ROOT}/common-scripts/lib.sh"

STACK_NAME="uptime-kuma"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"

create_compose() {
    cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
EOF
}

main() {
    print_header "Uptime Kuma - Monitoring Uptime"

    mkdir -p "${STACK_DIR}"
    cd "${STACK_DIR}"

    create_compose

    log_info "Déploiement Uptime Kuma..."
    docker-compose up -d

    sleep 20

    echo ""
    log_success "Uptime Kuma installé !"
    echo ""
    echo "📊 Accès : http://raspberrypi.local:3001"
    echo ""
    echo "💡 Première connexion :"
    echo "   - Créer compte admin"
    echo "   - Ajouter monitors (HTTP, Ping, Docker, etc.)"
    echo "   - Configurer notifications (Email, Discord, Slack)"
    echo ""
    echo "🔔 Notifications disponibles : 90+ services"
}

main "$@"
