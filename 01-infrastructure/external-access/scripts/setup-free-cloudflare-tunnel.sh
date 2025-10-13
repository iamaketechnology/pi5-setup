#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Cloudflare Quick Tunnel - Installation Gratuite (sans domaine)
#
# Description: Installe un tunnel Cloudflare gratuit avec URL *.trycloudflare.com
# Version: 1.0.0
# Author: PI5-SETUP Project
# Idempotent: ✅ Oui
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/cloudflare-free-tunnel-$(date +%Y%m%d_%H%M%S).log"
TUNNEL_DIR=""
APP_NAME=""
APP_SERVICE=""
CONTAINER_NAME=""

#############################################################################
# Fonctions utilitaires
#############################################################################

log() { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
title() { echo -e "${BOLD}${BLUE}$*${NC}"; }
section() { echo -e "\n${BOLD}${MAGENTA}═══ $* ═══${NC}\n"; }

error_exit() {
    error "$1"
    exit 1
}

banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     ☁️  Cloudflare Quick Tunnel - Installation Gratuite             ║
║                                                                      ║
║     URL gratuite : *.trycloudflare.com                              ║
║     Version 1.0.0                                                   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

#############################################################################
# Vérifications
#############################################################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_docker() {
    section "🔍 Vérification Docker"

    if ! command -v docker &> /dev/null; then
        error_exit "Docker n'est pas installé"
    fi
    ok "Docker installé"

    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin manquant"
    fi
    ok "Docker Compose installé"

    echo ""
}

#############################################################################
# Configuration interactive
#############################################################################

prompt_app_info() {
    section "📋 Configuration de l'application"

    cat << 'EOF'
Ce script va créer un tunnel Cloudflare gratuit pour votre application.

Vous obtiendrez une URL publique HTTPS gratuite comme :
  https://random-words-1234.trycloudflare.com

⚠️  LIMITATIONS :
  • L'URL change à chaque redémarrage du tunnel
  • Pas de domaine personnalisé
  • Idéal pour tests/démos, pas pour production

EOF

    # Nom de l'app
    echo -e "${BOLD}Nom de votre application :${NC}"
    echo "  (Exemples : certidoc, mon-app, api-backend)"
    echo ""
    read -p "Nom de l'app : " APP_NAME

    if [[ -z "$APP_NAME" ]]; then
        error_exit "Le nom de l'app est requis"
    fi

    # Valider le nom (alphanumeric + tirets)
    if [[ ! "$APP_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
        error_exit "Nom invalide. Utilisez uniquement lettres, chiffres et tirets"
    fi

    ok "Nom de l'app : ${APP_NAME}"
    echo ""

    # Service Docker
    echo -e "${BOLD}Service Docker à exposer :${NC}"
    echo "  Format : nom-container:port"
    echo "  Exemples :"
    echo "    - certidoc-frontend:80"
    echo "    - mon-app:3000"
    echo "    - api-backend:8080"
    echo ""

    # Détection automatique des containers
    log "Containers disponibles :"
    docker ps --format "  • {{.Names}} (ports: {{.Ports}})" | head -10

    echo ""
    read -p "Service Docker : " APP_SERVICE

    if [[ -z "$APP_SERVICE" ]]; then
        error_exit "Le service Docker est requis"
    fi

    # Extraire nom du container et port
    local container_name=$(echo "$APP_SERVICE" | cut -d: -f1)
    local container_port=$(echo "$APP_SERVICE" | cut -d: -f2)

    # Vérifier que le container existe
    if ! docker ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
        warn "Container '${container_name}' non trouvé en cours d'exécution"
        read -p "Continuer quand même ? [y/N] : " confirm
        if [[ ! $confirm =~ ^[Yy]$ ]]; then
            error_exit "Installation annulée"
        fi
    else
        ok "Container trouvé : ${container_name}"
    fi

    echo ""

    # Nom du container tunnel
    CONTAINER_NAME="${APP_NAME}-tunnel"
    TUNNEL_DIR="/home/${SUDO_USER:-pi}/tunnels/${APP_NAME}"

    # Résumé
    echo -e "${BOLD}Configuration :${NC}"
    echo "  • Nom app : ${APP_NAME}"
    echo "  • Service : ${APP_SERVICE}"
    echo "  • Container tunnel : ${CONTAINER_NAME}"
    echo "  • Dossier : ${TUNNEL_DIR}"
    echo ""

    read -p "Confirmer cette configuration ? [Y/n] : " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error_exit "Installation annulée"
    fi
}

#############################################################################
# Détection réseau Docker
#############################################################################

detect_docker_network() {
    section "🔍 Détection réseau Docker"

    local container_name=$(echo "$APP_SERVICE" | cut -d: -f1)

    log "Analyse du container ${container_name}..."

    # Obtenir le réseau du container
    local networks=$(docker inspect "$container_name" --format='{{range $key, $value := .NetworkSettings.Networks}}{{$key}} {{end}}' 2>/dev/null || echo "")

    if [[ -z "$networks" ]]; then
        warn "Impossible de détecter le réseau automatiquement"
        networks="bridge"
    fi

    # Prendre le premier réseau trouvé
    local primary_network=$(echo "$networks" | awk '{print $1}')

    ok "Réseau détecté : ${primary_network}"
    echo ""

    # Stocker dans variable globale
    DOCKER_NETWORK="$primary_network"
}

#############################################################################
# Création structure
#############################################################################

create_tunnel_structure() {
    section "📁 Création structure tunnel"

    log "Création du dossier ${TUNNEL_DIR}..."

    mkdir -p "$TUNNEL_DIR"
    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "$TUNNEL_DIR"

    ok "Structure créée"
    echo ""
}

#############################################################################
# Génération docker-compose.yml
#############################################################################

generate_docker_compose() {
    section "🐳 Génération docker-compose.yml"

    log "Création du fichier docker-compose.yml..."

    cat > "${TUNNEL_DIR}/docker-compose.yml" << EOF
# Cloudflare Quick Tunnel - ${APP_NAME}
# Généré le : $(date)
# URL gratuite : *.trycloudflare.com

version: '3.8'

services:
  ${APP_NAME}-tunnel:
    image: cloudflare/cloudflared:latest
    container_name: ${CONTAINER_NAME}
    restart: unless-stopped
    command: tunnel --url http://${APP_SERVICE}
    networks:
      - ${DOCKER_NETWORK}
    environment:
      - TUNNEL_METRICS=0.0.0.0:9090
    # Healthcheck désactivé: cloudflared utilise une image distroless sans shell
    # restart: unless-stopped assure le redémarrage automatique en cas de crash

networks:
  ${DOCKER_NETWORK}:
    external: true
    name: ${DOCKER_NETWORK}
EOF

    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "${TUNNEL_DIR}/docker-compose.yml"
    ok "docker-compose.yml créé"
    echo ""
}

#############################################################################
# Création script helper
#############################################################################

create_helper_scripts() {
    section "📝 Création scripts utilitaires"

    # Script pour obtenir l'URL
    cat > "${TUNNEL_DIR}/get-url.sh" << 'EOF'
#!/bin/bash
echo "🌐 URL publique du tunnel :"
docker logs ${CONTAINER_NAME} 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1
EOF

    # Script de monitoring
    cat > "${TUNNEL_DIR}/status.sh" << 'EOF'
#!/bin/bash
echo "═══ Status Tunnel ${APP_NAME} ═══"
echo ""

# Container status
if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${CONTAINER_NAME}"; then
    health=$(docker inspect ${CONTAINER_NAME} --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    echo "✅ Container: UP ($health)"

    # URL
    echo ""
    echo "🌐 URL publique:"
    docker logs ${CONTAINER_NAME} 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1

    # RAM
    echo ""
    echo "💾 RAM:"
    docker stats --no-stream --format "  {{.MemUsage}}" ${CONTAINER_NAME}
else
    echo "❌ Container: DOWN"
    echo ""
    echo "Pour démarrer:"
    echo "  cd ${TUNNEL_DIR}"
    echo "  docker compose up -d"
fi
EOF

    # Rendre exécutables
    chmod +x "${TUNNEL_DIR}/get-url.sh"
    chmod +x "${TUNNEL_DIR}/status.sh"

    # Remplacer variables
    sed -i "s/\${CONTAINER_NAME}/${CONTAINER_NAME}/g" "${TUNNEL_DIR}/get-url.sh"
    sed -i "s/\${CONTAINER_NAME}/${CONTAINER_NAME}/g" "${TUNNEL_DIR}/status.sh"
    sed -i "s/\${APP_NAME}/${APP_NAME}/g" "${TUNNEL_DIR}/status.sh"
    sed -i "s|\${TUNNEL_DIR}|${TUNNEL_DIR}|g" "${TUNNEL_DIR}/status.sh"

    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "${TUNNEL_DIR}"/*.sh

    ok "Scripts créés :"
    echo "  • ${TUNNEL_DIR}/get-url.sh"
    echo "  • ${TUNNEL_DIR}/status.sh"
    echo ""
}

#############################################################################
# Démarrage tunnel
#############################################################################

start_tunnel() {
    section "🚀 Démarrage du tunnel"

    cd "$TUNNEL_DIR"

    log "Pull de l'image cloudflare/cloudflared..."
    docker compose pull

    log "Démarrage du tunnel..."
    docker compose up -d

    sleep 5

    if docker ps --filter "name=${CONTAINER_NAME}" --format "{{.Names}}" | grep -q "${CONTAINER_NAME}"; then
        ok "✅ Tunnel démarré avec succès !"
    else
        error "Le tunnel n'a pas démarré correctement"
        log "Logs :"
        docker logs "$CONTAINER_NAME" --tail 20
        error_exit "Consultez les logs ci-dessus"
    fi

    echo ""
}

#############################################################################
# Récupération URL
#############################################################################

get_tunnel_url() {
    section "🌐 Récupération URL publique"

    log "Attente de la génération de l'URL (10-15 secondes)..."
    sleep 12

    local url=""
    local max_attempts=5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        url=$(docker logs "$CONTAINER_NAME" 2>&1 | grep -o 'https://.*\.trycloudflare\.com' | head -1)

        if [[ -n "$url" ]]; then
            break
        fi

        log "Tentative ${attempt}/${max_attempts}..."
        sleep 3
        ((attempt++))
    done

    if [[ -n "$url" ]]; then
        ok "URL générée avec succès !"
        echo ""
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${GREEN}  URL PUBLIQUE : ${url}${NC}"
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════${NC}"
        echo ""

        # Sauvegarder URL
        echo "$url" > "${TUNNEL_DIR}/current-url.txt"
        ok "URL sauvegardée dans ${TUNNEL_DIR}/current-url.txt"

        TUNNEL_URL="$url"
    else
        warn "Impossible de récupérer l'URL automatiquement"
        echo ""
        echo "Pour obtenir l'URL manuellement :"
        echo "  bash ${TUNNEL_DIR}/get-url.sh"
        echo ""
        echo "Ou consultez les logs :"
        echo "  docker logs ${CONTAINER_NAME} | grep trycloudflare"
    fi

    echo ""
}

#############################################################################
# Test connectivité
#############################################################################

test_tunnel() {
    section "🧪 Test de connectivité"

    if [[ -z "${TUNNEL_URL:-}" ]]; then
        warn "URL non disponible, test ignoré"
        return 0
    fi

    log "Test de l'URL : ${TUNNEL_URL}"

    if curl -sf -o /dev/null --max-time 10 "$TUNNEL_URL"; then
        ok "✅ Le tunnel est accessible depuis Internet !"
    else
        warn "⚠️  Le tunnel ne répond pas encore (peut prendre 1-2 minutes)"
        echo ""
        echo "Testez manuellement avec :"
        echo "  curl -I ${TUNNEL_URL}"
    fi

    echo ""
}

#############################################################################
# Résumé final
#############################################################################

show_summary() {
    section "📊 Installation Terminée"

    cat << EOF
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     ✅ Tunnel Cloudflare Gratuit Installé !                         ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📦 Configuration :
   • Application : ${APP_NAME}
   • Service : ${APP_SERVICE}
   • Container : ${CONTAINER_NAME}
   • Dossier : ${TUNNEL_DIR}

EOF

    if [[ -n "${TUNNEL_URL:-}" ]]; then
        cat << EOF
🌐 URL Publique :
   ${TUNNEL_URL}

   ⚠️  ATTENTION : Cette URL change à chaque redémarrage du tunnel !

EOF
    fi

    cat << EOF
📝 Commandes Utiles :

   Obtenir l'URL actuelle :
   └─ bash ${TUNNEL_DIR}/get-url.sh

   Voir le status :
   └─ bash ${TUNNEL_DIR}/status.sh

   Voir les logs :
   └─ docker logs -f ${CONTAINER_NAME}

   Redémarrer le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose restart

   Arrêter le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose down

   Démarrer le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose up -d

🆘 Troubleshooting :

   Si l'URL ne fonctionne pas :
   1. Vérifier que l'app tourne : docker ps | grep ${APP_SERVICE%%:*}
   2. Vérifier logs tunnel : docker logs ${CONTAINER_NAME}
   3. Tester en local : curl -I http://localhost:${APP_SERVICE##*:}

📚 Documentation :
   • Cloudflare Tunnel : https://developers.cloudflare.com/cloudflare-one/
   • Log complet : ${LOG_FILE}

EOF

    if [[ -z "${TUNNEL_URL:-}" ]]; then
        cat << EOF
⚠️  IMPORTANT :
   L'URL n'a pas pu être récupérée automatiquement.
   Utilisez : bash ${TUNNEL_DIR}/get-url.sh

EOF
    fi

    ok "Installation terminée avec succès !"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    banner
    check_root
    check_docker
    prompt_app_info
    detect_docker_network
    create_tunnel_structure
    generate_docker_compose
    create_helper_scripts
    start_tunnel
    get_tunnel_url
    test_tunnel
    show_summary
}

main "$@"
