#!/bin/bash
# =============================================================================
# Pi Emulator Deploy - macOS
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash 01-pi-emulator-deploy-mac.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
EMULATOR_DIR="${PROJECT_ROOT}/tools/pi-emulator"
COMPOSE_FILE="${EMULATOR_DIR}/compose/docker-compose.yml"

log_info "Pi Emulator Deploy - macOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Warnings macOS
log_warning "⚠️  Limitations macOS:"
echo "   - Performance réduite (VM Docker Desktop)"
echo "   - Docker-in-Docker limité"
echo "   - Pour tests complets, utiliser Linux"
echo ""

# Vérifier Docker Desktop
if ! command -v docker &> /dev/null; then
    log_error "Docker Desktop non installé"
    echo "Installer: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Vérifier si Docker Desktop tourne
if ! docker info &> /dev/null; then
    log_error "Docker Desktop non démarré. Lancer l'application Docker."
    exit 1
fi

# Vérifier Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose V2 non disponible"
    exit 1
fi

# Vérifier si déjà lancé
if docker ps --format '{{.Names}}' | grep -q "^pi-emulator-test$"; then
    log_info "Pi Emulator déjà en cours d'exécution"

    read -p "Redémarrer? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Arrêt de l'émulateur..."
        docker compose -f "${COMPOSE_FILE}" down
    else
        log_success "Émulateur actif"
        exit 0
    fi
fi

# Lancer Docker Compose
log_info "Lancement de l'émulateur Pi..."
cd "${EMULATOR_DIR}"
docker compose -f "${COMPOSE_FILE}" up -d

# Attendre démarrage SSH (plus long sur Mac)
log_info "Attente démarrage SSH (45s - VM overhead)..."
sleep 45

# Vérifier SSH
if docker exec pi-emulator-test pgrep sshd > /dev/null 2>&1; then
    log_success "SSH actif"
else
    log_error "SSH non démarré"
    docker logs pi-emulator-test --tail 50
    exit 1
fi

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 PI EMULATOR LANCÉ (macOS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Connexion SSH:"
echo "   ssh pi@localhost -p 2222"
echo "   Password: raspberry"
echo ""
echo "📌 Depuis Admin Panel (tools/admin-panel/config.js):"
echo "   {"
echo "     hostname: 'localhost',"
echo "     port: 2222,"
echo "     username: 'pi',"
echo "     password: 'raspberry'"
echo "   }"
echo ""
echo "⚠️  Limitations macOS:"
echo "   - Docker-in-Docker peut échouer (Supabase, etc.)"
echo "   - Performance réduite vs Linux"
echo "   - Pour production-like, utiliser Linux"
echo ""
echo "📌 Commandes utiles:"
echo "   docker logs pi-emulator-test -f"
echo "   docker exec -it pi-emulator-test bash"
echo "   docker compose -f compose/docker-compose.yml down"
echo ""
echo "📌 Test basique admin panel:"
echo "   cd tools/admin-panel"
echo "   npm install"
echo "   node server.js"
echo "   # Configurer config.js avec localhost:2222"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
