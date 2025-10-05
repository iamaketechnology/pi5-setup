#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="homeassistant"
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
Usage: 01-homeassistant-deploy.sh [options]

Déploie Home Assistant - Hub domotique tout-en-un.

Fonctionnalités :
- ✅ Home Assistant latest (ARM64)
- ✅ 2000+ intégrations (Philips Hue, Xiaomi, Sonoff, etc.)
- ✅ Interface web moderne + mobile
- ✅ Automatisations visuelles
- ✅ Commande vocale (Google Home, Alexa)
- ✅ Intégration Traefik automatique (HTTPS)
- ✅ Widget Homepage automatique

Temps installation : ~5 min
RAM : ~500 MB

Options:
  --dry-run        Simule sans exécuter
  --yes, -y        Mode non-interactif
  --verbose, -v    Logs détaillés
  --quiet, -q      Minimal output
  --no-color       Sans couleurs
  --help, -h       Aide

Exemples:
  # Installation normale
  sudo ./01-homeassistant-deploy.sh

  # Mode automatisé
  sudo ./01-homeassistant-deploy.sh --yes

  # Test sans installation
  sudo ./01-homeassistant-deploy.sh --dry-run --verbose
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
log_info "🏠 Home Assistant Deployment"
log_info "═══════════════════════════════════════════════════════"
echo ""

# Check prerequisites
log_info "Vérification prérequis..."

if ! command -v docker >/dev/null 2>&1; then
  fatal "Docker non installé. Exécutez d'abord Phase 1 (01-prerequisites-setup.sh)"
fi

if ! command -v docker compose >/dev/null 2>&1; then
  fatal "Docker Compose non installé. Exécutez d'abord Phase 1 (01-prerequisites-setup.sh)"
fi

log_success "Prérequis OK"
echo ""

# Detect Traefik scenario
TRAEFIK_SCENARIO="none"
TRAEFIK_DIR="/home/pi/stacks/traefik"
TRAEFIK_ENV="${TRAEFIK_DIR}/.env"

if [[ -f "${TRAEFIK_ENV}" ]]; then
  if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
    TRAEFIK_SCENARIO="duckdns"
    DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
  elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
    TRAEFIK_SCENARIO="cloudflare"
    DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
  elif grep -q "VPN_NETWORK" "${TRAEFIK_ENV}" 2>/dev/null; then
    TRAEFIK_SCENARIO="vpn"
    LOCAL_DOMAIN=$(grep "^LOCAL_DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2 || echo "pi.local")
  fi
  log_info "Traefik détecté : scénario ${TRAEFIK_SCENARIO}"
else
  log_warn "Traefik non détecté. Home Assistant sera accessible uniquement en local (port 8123)"
fi
echo ""

# Confirm installation
if [[ ${YES_MODE} -eq 0 ]]; then
  log_info "Configuration :"
  log_info "  Stack : Home Assistant"
  log_info "  Répertoire : ${STACK_DIR}"
  log_info "  RAM : ~500 MB"
  log_info "  Scénario Traefik : ${TRAEFIK_SCENARIO}"

  case "${TRAEFIK_SCENARIO}" in
    duckdns)
      log_info "  URL : https://${DUCKDNS_SUBDOMAIN}.duckdns.org/homeassistant"
      ;;
    cloudflare)
      log_info "  URL : https://home.${DOMAIN}"
      ;;
    vpn)
      log_info "  URL : https://home.${LOCAL_DOMAIN}"
      ;;
    *)
      log_info "  URL : http://raspberrypi.local:8123"
      ;;
  esac

  echo ""
  read -p "Continuer l'installation ? (y/n): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Installation annulée"
    exit 0
  fi
fi
echo ""

# Create stack directory
log_info "Création répertoire stack..."

if [[ -d "${STACK_DIR}" ]]; then
  log_warn "Répertoire ${STACK_DIR} existe déjà"

  if [[ ${YES_MODE} -eq 0 ]]; then
    read -p "Écraser la configuration existante ? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      fatal "Installation annulée (répertoire existe)"
    fi
  fi

  log_info "Sauvegarde de la configuration existante..."
  run_cmd mv "${STACK_DIR}" "${STACK_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
fi

run_cmd mkdir -p "${STACK_DIR}"
run_cmd mkdir -p "${STACK_DIR}/config"

log_success "Répertoire créé"
echo ""

# Create docker-compose.yml
log_info "Création docker-compose.yml..."

COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

# Generate Traefik labels based on scenario
TRAEFIK_LABELS=""

case "${TRAEFIK_SCENARIO}" in
  duckdns)
    TRAEFIK_LABELS=$(cat <<'LABELS'
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=PathPrefix(\`/homeassistant\`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=letsencrypt"
      - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
      - "traefik.http.middlewares.homeassistant-strip.stripprefix.prefixes=/homeassistant"
      - "traefik.http.routers.homeassistant.middlewares=homeassistant-strip"
LABELS
)
    ;;
  cloudflare)
    TRAEFIK_LABELS=$(cat <<LABELS
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(\\\`home.${DOMAIN}\\\`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls.certresolver=cloudflare"
      - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
LABELS
)
    ;;
  vpn)
    TRAEFIK_LABELS=$(cat <<LABELS
      - "traefik.enable=true"
      - "traefik.http.routers.homeassistant.rule=Host(\\\`home.${LOCAL_DOMAIN}\\\`)"
      - "traefik.http.routers.homeassistant.entrypoints=websecure"
      - "traefik.http.routers.homeassistant.tls=true"
      - "traefik.http.services.homeassistant.loadbalancer.server.port=8123"
LABELS
)
    ;;
  *)
    # No Traefik, expose port 8123 directly
    TRAEFIK_LABELS=""
    ;;
esac

# Create docker-compose.yml
cat > "${COMPOSE_FILE}" <<COMPOSE
version: '3.8'

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    privileged: true
    network_mode: host
    volumes:
      - ${STACK_DIR}/config:/config
      - /etc/localtime:/etc/localtime:ro
    environment:
      - TZ=Europe/Paris
COMPOSE

# Add Traefik labels if applicable
if [[ -n "${TRAEFIK_LABELS}" ]]; then
  cat >> "${COMPOSE_FILE}" <<COMPOSE
    labels:
${TRAEFIK_LABELS}
COMPOSE
fi

log_success "docker-compose.yml créé"
echo ""

# Pull image
log_info "Téléchargement image Home Assistant (peut prendre 5-10 min)..."
run_cmd docker compose -f "${COMPOSE_FILE}" pull

log_success "Image téléchargée"
echo ""

# Start Home Assistant
log_info "Démarrage Home Assistant..."
run_cmd docker compose -f "${COMPOSE_FILE}" up -d

log_success "Home Assistant démarré"
echo ""

# Wait for Home Assistant to be ready
log_info "Attente démarrage complet (peut prendre 2-3 min)..."

MAX_WAIT=180
WAITED=0
while [[ ${WAITED} -lt ${MAX_WAIT} ]]; do
  if curl -s http://localhost:8123 >/dev/null 2>&1; then
    log_success "Home Assistant prêt !"
    break
  fi
  sleep 5
  WAITED=$((WAITED + 5))
  echo -n "."
done
echo ""

if [[ ${WAITED} -ge ${MAX_WAIT} ]]; then
  log_warn "Timeout atteint, vérifiez les logs : docker logs homeassistant -f"
fi
echo ""

# Integrate with Homepage if installed
HOMEPAGE_DIR="/home/pi/stacks/homepage"
if [[ -d "${HOMEPAGE_DIR}" ]]; then
  log_info "Intégration Homepage détectée..."

  HOMEPAGE_SERVICES="${HOMEPAGE_DIR}/config/services.yaml"

  if [[ -f "${HOMEPAGE_SERVICES}" ]]; then
    # Check if already integrated
    if ! grep -q "Home Assistant" "${HOMEPAGE_SERVICES}" 2>/dev/null; then
      log_info "Ajout widget Homepage..."

      # Add Domotique section if not exists
      if ! grep -q "Domotique:" "${HOMEPAGE_SERVICES}" 2>/dev/null; then
        cat >> "${HOMEPAGE_SERVICES}" <<HOMEPAGE

- Domotique:
    - Home Assistant:
        href: http://raspberrypi.local:8123
        description: Hub domotique
        icon: home-assistant.png
HOMEPAGE
      else
        # Append to existing Domotique section
        sed -i '/^- Domotique:/a\    - Home Assistant:\n        href: http://raspberrypi.local:8123\n        description: Hub domotique\n        icon: home-assistant.png' "${HOMEPAGE_SERVICES}"
      fi

      # Restart Homepage
      if docker ps | grep -q homepage; then
        run_cmd docker restart homepage
        log_success "Widget Homepage ajouté"
      fi
    else
      log_info "Widget Homepage déjà configuré"
    fi
  fi
fi
echo ""

# Summary
log_info "═══════════════════════════════════════════════════════"
log_success "🏠 Home Assistant Déployé avec Succès !"
log_info "═══════════════════════════════════════════════════════"
echo ""

log_info "📍 URLs d'Accès :"
case "${TRAEFIK_SCENARIO}" in
  duckdns)
    log_info "  • HTTPS (Traefik) : https://${DUCKDNS_SUBDOMAIN}.duckdns.org/homeassistant"
    log_info "  • Local          : http://raspberrypi.local:8123"
    ;;
  cloudflare)
    log_info "  • HTTPS (Traefik) : https://home.${DOMAIN}"
    log_info "  • Local          : http://raspberrypi.local:8123"
    ;;
  vpn)
    log_info "  • HTTPS (VPN)     : https://home.${LOCAL_DOMAIN}"
    log_info "  • Local          : http://raspberrypi.local:8123"
    ;;
  *)
    log_info "  • Local          : http://raspberrypi.local:8123"
    ;;
esac
echo ""

log_info "🎯 Premier Démarrage :"
log_info "  1. Ouvrir http://raspberrypi.local:8123"
log_info "  2. Créer compte administrateur"
log_info "  3. Configurer localisation (France)"
log_info "  4. Home Assistant va découvrir automatiquement vos appareils"
echo ""

log_info "📦 Ajouter Intégrations :"
log_info "  • Menu → Paramètres → Appareils et services → Ajouter intégration"
log_info "  • Rechercher : Philips Hue, Xiaomi, Sonoff, MQTT, etc."
echo ""

log_info "📊 RAM Utilisée : ~500 MB"
echo ""

log_info "🔧 Commandes Utiles :"
log_info "  # Voir logs"
log_info "  docker logs homeassistant -f"
echo ""
log_info "  # Redémarrer"
log_info "  docker restart homeassistant"
echo ""
log_info "  # Arrêter (libérer RAM)"
log_info "  sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop homeassistant"
echo ""
log_info "  # Configuration"
log_info "  nano ${STACK_DIR}/config/configuration.yaml"
echo ""

log_info "📚 Documentation :"
log_info "  • Home Assistant : https://www.home-assistant.io/docs/"
log_info "  • Phase 10 Guide  : ~/pi5-setup/PHASE-10-DOMOTIQUE.md"
log_info "  • Community FR    : https://forum.hacf.fr/"
echo ""

log_success "Installation terminée ! Profitez de votre hub domotique ! 🎉"
