#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="nodered"
STACK_DIR="/home/pi/stacks/${STACK_NAME}"

# Source common library
COMMON_SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../../common-scripts" && pwd)"
if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
  source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
  echo "ERROR: Cannot find common-scripts/lib.sh"
  exit 1
fi

usage() {
  cat <<'USAGE'
Usage: 02-nodered-deploy.sh [options]

Déploie Node-RED - Automatisations visuelles par flux (drag & drop).

Fonctionnalités :
- ✅ Node-RED latest (ARM64)
- ✅ Interface drag & drop (pas de code)
- ✅ Intégrations : MQTT, HTTP, Webhooks, Base de données
- ✅ Complémentaire à Home Assistant
- ✅ Automatisations complexes visuelles
- ✅ Intégration Traefik automatique (HTTPS)

Temps installation : ~3 min
RAM : ~100 MB

Options:
  --dry-run        Simule sans exécuter
  --yes, -y        Mode non-interactif
  --verbose, -v    Logs détaillés
  --help, -h       Aide
USAGE
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

require_root

log_info "═══════════════════════════════════════════════════════"
log_info "🔀 Node-RED Deployment"
log_info "═══════════════════════════════════════════════════════"
echo ""

# Check prerequisites
log_info "Vérification prérequis..."

if ! command -v docker >/dev/null 2>&1; then
  fatal "Docker non installé"
fi

log_success "Prérequis OK"
echo ""

# Create stack directory
log_info "Création répertoire stack..."
run_cmd mkdir -p "${STACK_DIR}/data"
run_cmd chown -R 1000:1000 "${STACK_DIR}/data"

log_success "Répertoire créé"
echo ""

# Create docker-compose.yml
log_info "Création docker-compose.yml..."

cat > "${STACK_DIR}/docker-compose.yml" <<'COMPOSE'
version: '3.8'

services:
  nodered:
    image: nodered/node-red:latest
    container_name: nodered
    restart: unless-stopped
    ports:
      - "1880:1880"
    volumes:
      - ./data:/data
    environment:
      - TZ=Europe/Paris
    user: "1000:1000"
COMPOSE

log_success "docker-compose.yml créé"
echo ""

# Pull and start
log_info "Téléchargement et démarrage Node-RED..."
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" pull
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" up -d

log_success "Node-RED démarré"
echo ""

# Wait for Node-RED
log_info "Attente démarrage..."
sleep 10

if curl -s http://localhost:1880 >/dev/null 2>&1; then
  log_success "Node-RED prêt !"
else
  log_warn "Node-RED prend du temps à démarrer, vérifiez : docker logs nodered -f"
fi
echo ""

# Integrate Homepage
HOMEPAGE_DIR="/home/pi/stacks/homepage"
if [[ -d "${HOMEPAGE_DIR}" ]] && [[ -f "${HOMEPAGE_DIR}/config/services.yaml" ]]; then
  if ! grep -q "Node-RED" "${HOMEPAGE_DIR}/config/services.yaml" 2>/dev/null; then
    log_info "Ajout widget Homepage..."

    if grep -q "Domotique:" "${HOMEPAGE_DIR}/config/services.yaml"; then
      sed -i '/^- Domotique:/a\    - Node-RED:\n        href: http://raspberrypi.local:1880\n        description: Automatisations visuelles\n        icon: node-red.png' "${HOMEPAGE_DIR}/config/services.yaml"
    else
      cat >> "${HOMEPAGE_DIR}/config/services.yaml" <<HOMEPAGE

- Domotique:
    - Node-RED:
        href: http://raspberrypi.local:1880
        description: Automatisations visuelles
        icon: node-red.png
HOMEPAGE
    fi

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Widget Homepage ajouté"
  fi
fi
echo ""

# Summary
log_info "═══════════════════════════════════════════════════════"
log_success "🔀 Node-RED Déployé avec Succès !"
log_info "═══════════════════════════════════════════════════════"
echo ""
log_info "📍 URL : http://raspberrypi.local:1880"
echo ""
log_info "🎯 Premiers Pas :"
log_info "  1. Glisser-déposer nœuds depuis palette gauche"
log_info "  2. Connecter nœuds (lignes)"
log_info "  3. Deploy (bouton rouge en haut)"
echo ""
log_info "📦 Installer Modules (optionnel) :"
log_info "  • Menu → Manage palette → Install"
log_info "  • node-red-contrib-home-assistant-websocket"
log_info "  • node-red-dashboard"
echo ""
log_info "📚 Documentation : https://nodered.org/docs/"
echo ""
log_success "Installation terminée ! 🎉"
