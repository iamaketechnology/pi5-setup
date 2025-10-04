#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="zigbee2mqtt"
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
Usage: 04-zigbee2mqtt-deploy.sh [options]

Déploie Zigbee2MQTT - Passerelle Zigbee sans hub propriétaire.

Fonctionnalités :
- ✅ Contrôle appareils Zigbee (Philips Hue, Xiaomi, IKEA, Sonoff)
- ✅ Pas besoin de hub propriétaire (Hue Bridge, etc.)
- ✅ Interface web moderne
- ✅ Intégration MQTT automatique
- ✅ Intégration Home Assistant automatique

Prérequis :
- ⚠️ Dongle Zigbee USB (Sonoff Dongle Plus ~20€, CC2531, ConBee II)
- ✅ MQTT Broker installé (script 03-mqtt-deploy.sh)

Temps installation : ~10 min
RAM : ~80 MB

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
log_info "📶 Zigbee2MQTT Deployment"
log_info "═══════════════════════════════════════════════════════"
echo ""

# Check prerequisites
log_info "Vérification prérequis..."

if ! command -v docker >/dev/null 2>&1; then
  fatal "Docker non installé"
fi

# Check for Zigbee dongle
log_info "Recherche dongle Zigbee USB..."

USB_DEVICES=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true)

if [[ -z "${USB_DEVICES}" ]]; then
  log_warn "⚠️  Aucun dongle USB détecté !"
  log_warn ""
  log_warn "Dongles compatibles :"
  log_warn "  • Sonoff Zigbee 3.0 USB Dongle Plus (~20€)"
  log_warn "  • CC2531 Sniffer (~15€)"
  log_warn "  • ConBee II (~40€)"
  log_warn ""
  log_warn "Branchez un dongle Zigbee et relancez ce script."
  echo ""

  if [[ ${YES_MODE} -eq 0 ]]; then
    read -p "Continuer quand même ? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 0
    fi
    ZIGBEE_PORT="/dev/ttyUSB0"  # Default
  else
    fatal "Dongle Zigbee requis"
  fi
else
  log_success "Dongle(s) détecté(s) :"
  for device in ${USB_DEVICES}; do
    log_info "  • ${device}"
  done
  echo ""

  # Select dongle
  if [[ $(echo "${USB_DEVICES}" | wc -l) -eq 1 ]]; then
    ZIGBEE_PORT="${USB_DEVICES}"
    log_info "Dongle sélectionné : ${ZIGBEE_PORT}"
  else
    log_info "Plusieurs dongles détectés"
    if [[ ${YES_MODE} -eq 0 ]]; then
      echo ""
      select port in ${USB_DEVICES}; do
        ZIGBEE_PORT="${port}"
        break
      done
      log_info "Dongle sélectionné : ${ZIGBEE_PORT}"
    else
      ZIGBEE_PORT=$(echo "${USB_DEVICES}" | head -1)
      log_info "Mode automatique, sélection : ${ZIGBEE_PORT}"
    fi
  fi
fi
echo ""

# Check MQTT
if ! docker ps | grep -q mosquitto; then
  log_warn "MQTT Broker (Mosquitto) non détecté"
  log_info "Installer d'abord : ./03-mqtt-deploy.sh"

  if [[ ${YES_MODE} -eq 0 ]]; then
    read -p "Continuer quand même ? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 0
    fi
  fi
fi

log_success "Prérequis OK"
echo ""

# Create stack directory
log_info "Création répertoire stack..."
run_cmd mkdir -p "${STACK_DIR}/data"

log_success "Répertoire créé"
echo ""

# Create configuration.yaml
log_info "Création configuration Zigbee2MQTT..."

cat > "${STACK_DIR}/data/configuration.yaml" <<CONFIG
homeassistant: true
permit_join: true
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883
frontend:
  port: 8080
serial:
  port: ${ZIGBEE_PORT}
advanced:
  log_level: info
  log_output:
    - console
  network_key: GENERATE
CONFIG

log_success "Configuration créée"
echo ""

# Create docker-compose.yml
log_info "Création docker-compose.yml..."

cat > "${STACK_DIR}/docker-compose.yml" <<COMPOSE
version: '3.8'

services:
  zigbee2mqtt:
    image: koenkk/zigbee2mqtt:latest
    container_name: zigbee2mqtt
    restart: unless-stopped
    ports:
      - "8081:8080"
    volumes:
      - ./data:/app/data
      - /run/udev:/run/udev:ro
    devices:
      - ${ZIGBEE_PORT}:${ZIGBEE_PORT}
    environment:
      - TZ=Europe/Paris
    network_mode: host
COMPOSE

log_success "docker-compose.yml créé"
echo ""

# Pull and start
log_info "Téléchargement et démarrage Zigbee2MQTT..."
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" pull
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" up -d

log_success "Zigbee2MQTT démarré"
echo ""

# Wait for Zigbee2MQTT
log_info "Attente démarrage (30 sec)..."
sleep 30

if curl -s http://localhost:8081 >/dev/null 2>&1; then
  log_success "Zigbee2MQTT prêt !"
else
  log_warn "Vérifiez logs : docker logs zigbee2mqtt -f"
fi
echo ""

# Summary
log_info "═══════════════════════════════════════════════════════"
log_success "📶 Zigbee2MQTT Déployé avec Succès !"
log_info "═══════════════════════════════════════════════════════"
echo ""
log_info "📍 URL : http://raspberrypi.local:8081"
echo ""
log_info "🎯 Appairer Appareils :"
log_info "  1. Ouvrir http://raspberrypi.local:8081"
log_info "  2. Cliquer 'Permit join' (mode appairage)"
log_info "  3. Appuyer sur bouton reset de l'appareil Zigbee"
log_info "  4. Appareil apparaît dans la liste"
echo ""
log_info "🏠 Intégration Home Assistant :"
log_info "  • Automatique via MQTT Discovery"
log_info "  • Les appareils appariés apparaissent dans Home Assistant"
echo ""
log_info "🔧 Configuration :"
log_info "  • Fichier : ${STACK_DIR}/data/configuration.yaml"
log_info "  • Dongle  : ${ZIGBEE_PORT}"
echo ""
log_info "📦 Appareils Compatibles :"
log_info "  • Philips Hue (ampoules, interrupteurs)"
log_info "  • IKEA Tradfri (ampoules, télécommandes)"
log_info "  • Xiaomi Aqara (capteurs, interrupteurs)"
log_info "  • Sonoff (relais, capteurs)"
log_info "  • 2000+ appareils : https://www.zigbee2mqtt.io/supported-devices/"
echo ""
log_info "📚 Documentation : https://www.zigbee2mqtt.io/"
echo ""
log_success "Installation terminée ! 🎉"
