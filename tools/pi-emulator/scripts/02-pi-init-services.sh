#!/bin/bash
# =============================================================================
# Pi Emulator - Initialize Base Services
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash 02-pi-init-services.sh [supabase|traefik|all]
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Variables
SERVICE="${1:-all}"
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

log_info "Pi Emulator - Initialize Services: ${SERVICE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_error "Lancer avec sudo"
    exit 1
fi

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker non installé"
    exit 1
fi

# Fonction install Supabase
install_supabase() {
    log_info "Installation Supabase (simulé)..."

    mkdir -p "${USER_HOME}/stacks/supabase"
    cd "${USER_HOME}/stacks/supabase"

    cat > docker-compose.yml <<'EOF'
services:
  postgres:
    image: supabase/postgres:15.1.1.54
    container_name: supabase-db-test
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: your-super-secret-and-long-postgres-password
      POSTGRES_DB: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data

volumes:
  postgres-data:
EOF

    chown -R "${CURRENT_USER}:${CURRENT_USER}" "${USER_HOME}/stacks/supabase"

    log_info "Démarrage Supabase DB..."
    docker compose up -d

    sleep 5

    if docker ps | grep -q "supabase-db-test"; then
        log_success "Supabase DB installé"
    else
        log_error "Échec installation Supabase"
        exit 1
    fi
}

# Fonction install Traefik
install_traefik() {
    log_info "Installation Traefik (simulé)..."

    mkdir -p "${USER_HOME}/stacks/traefik"
    cd "${USER_HOME}/stacks/traefik"

    cat > docker-compose.yml <<'EOF'
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik-test
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    command:
      - --api.insecure=true
      - --providers.docker=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
EOF

    chown -R "${CURRENT_USER}:${CURRENT_USER}" "${USER_HOME}/stacks/traefik"

    log_info "Démarrage Traefik..."
    docker compose up -d

    sleep 5

    if docker ps | grep -q "traefik-test"; then
        log_success "Traefik installé"
    else
        log_error "Échec installation Traefik"
        exit 1
    fi
}

# Installation selon choix
case "${SERVICE}" in
    supabase)
        install_supabase
        ;;
    traefik)
        install_traefik
        ;;
    all)
        install_supabase
        install_traefik
        ;;
    *)
        log_error "Service inconnu: ${SERVICE}"
        echo "Usage: bash 02-pi-init-services.sh [supabase|traefik|all]"
        exit 1
        ;;
esac

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SERVICES INITIALISÉS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "📌 Commandes utiles:"
echo "   docker ps"
echo "   docker logs [container-name]"
echo "   docker compose -f ~/stacks/[service]/docker-compose.yml down"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
