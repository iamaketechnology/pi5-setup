#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="mqtt"
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
Usage: 03-mqtt-deploy.sh [options]

Déploie Mosquitto - MQTT Broker pour IoT.

Fonctionnalités :
- ✅ Mosquitto MQTT Broker
- ✅ Port 1883 (MQTT)
- ✅ Port 9001 (WebSocket)
- ✅ Persistence données
- ✅ Logs
- ✅ Essential pour appareils IoT (ESP32, Sonoff, Tasmota)

Temps installation : ~2 min
RAM : ~30 MB

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
log_info "📡 MQTT Broker (Mosquitto) Deployment"
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
run_cmd mkdir -p "${STACK_DIR}"/{data,log}

log_success "Répertoire créé"
echo ""

# Create mosquitto.conf
log_info "Création configuration Mosquitto..."

cat > "${STACK_DIR}/mosquitto.conf" <<'CONF'
# Mosquitto Configuration
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type all

# WebSocket listener
listener 9001
protocol websockets
CONF

log_success "Configuration créée"
echo ""

# Create docker-compose.yml
log_info "Création docker-compose.yml..."

cat > "${STACK_DIR}/docker-compose.yml" <<'COMPOSE'
version: '3.8'

services:
  mosquitto:
    image: eclipse-mosquitto:latest
    container_name: mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto.conf:/mosquitto/config/mosquitto.conf
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
    environment:
      - TZ=Europe/Paris
COMPOSE

log_success "docker-compose.yml créé"
echo ""

# Pull and start
log_info "Téléchargement et démarrage Mosquitto..."
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" pull
run_cmd docker compose -f "${STACK_DIR}/docker-compose.yml" up -d

log_success "Mosquitto démarré"
echo ""

# Wait for Mosquitto
sleep 3

# Test MQTT
log_info "Test connexion MQTT..."

if command -v mosquitto_pub >/dev/null 2>&1; then
  if mosquitto_pub -h localhost -t "test/topic" -m "Hello MQTT" 2>/dev/null; then
    log_success "MQTT fonctionne !"
  fi
else
  log_warn "mosquitto-clients pas installé, impossible de tester"
  log_info "Pour tester : sudo apt-get install -y mosquitto-clients"
fi
echo ""

# Summary
log_info "═══════════════════════════════════════════════════════"
log_success "📡 MQTT Broker Déployé avec Succès !"
log_info "═══════════════════════════════════════════════════════"
echo ""
log_info "📍 Ports :"
log_info "  • MQTT       : 1883"
log_info "  • WebSocket  : 9001"
echo ""
log_info "🔧 Configuration :"
log_info "  • Config : ${STACK_DIR}/mosquitto.conf"
log_info "  • Data   : ${STACK_DIR}/data"
log_info "  • Logs   : ${STACK_DIR}/log/mosquitto.log"
echo ""
log_info "🧪 Tester MQTT :"
log_info "  # Installer clients"
log_info "  sudo apt-get install -y mosquitto-clients"
echo ""
log_info "  # Publier message"
log_info "  mosquitto_pub -h localhost -t \"test/topic\" -m \"Hello\""
echo ""
log_info "  # Souscrire à topic"
log_info "  mosquitto_sub -h localhost -t \"test/topic\""
echo ""
log_info "🏠 Intégration Home Assistant :"
log_info "  • Menu → Paramètres → Intégrations → MQTT"
log_info "  • Serveur : mosquitto (ou raspberrypi.local)"
log_info "  • Port : 1883"
log_info "  • User/Password : (laisser vide si allow_anonymous)"
echo ""
log_info "📚 Documentation : https://mosquitto.org/documentation/"
echo ""
log_success "Installation terminée ! 🎉"
