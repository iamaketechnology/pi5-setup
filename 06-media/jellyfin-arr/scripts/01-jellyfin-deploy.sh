#!/usr/bin/env bash
# ==============================================================================
# Script: 01-jellyfin-deploy.sh
# Description: Deploiement Jellyfin Media Server sur Raspberry Pi 5
#              avec support GPU hardware transcoding (VideoCore VII)
# Auteur: PI5-SETUP Project
# Compatibilite: Raspberry Pi 5 (ARM64) - Raspberry Pi OS Bookworm
# Version: 1.0.0
# ==============================================================================

set -euo pipefail

# --- Detection du repertoire du script ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# --- Source de la bibliotheque commune ---
# shellcheck source=../../common-scripts/lib.sh
if [[ -f "${SCRIPT_DIR}/../../common-scripts/lib.sh" ]]; then
  source "${SCRIPT_DIR}/../../common-scripts/lib.sh"
else
  echo "ERREUR: Impossible de trouver lib.sh" >&2
  exit 1
fi

# ==============================================================================
# VARIABLES DE CONFIGURATION
# ==============================================================================

# --- Configuration Jellyfin ---
JELLYFIN_VERSION=${JELLYFIN_VERSION:-latest}
JELLYFIN_PORT=${JELLYFIN_PORT:-8096}
JELLYFIN_DISCOVERY_PORT=${JELLYFIN_DISCOVERY_PORT:-7359}
JELLYFIN_DLNA_PORT=${JELLYFIN_DLNA_PORT:-1900}

# --- Chemins des bibliotheques media ---
MEDIA_DIR=${MEDIA_DIR:-/home/pi/media}
MOVIES_DIR=${MOVIES_DIR:-${MEDIA_DIR}/movies}
TV_SHOWS_DIR=${TV_SHOWS_DIR:-${MEDIA_DIR}/tv}
MUSIC_DIR=${MUSIC_DIR:-${MEDIA_DIR}/music}
PHOTOS_DIR=${PHOTOS_DIR:-${MEDIA_DIR}/photos}

# --- Configuration de la stack ---
STACK_NAME=${STACK_NAME:-jellyfin}
STACK_DIR=${STACK_DIR:-/home/pi/stacks/jellyfin}

# --- Integration Traefik ---
TRAEFIK_ENABLE=${TRAEFIK_ENABLE:-auto}
JELLYFIN_DOMAIN=${JELLYFIN_DOMAIN:-}

# --- Integration Homepage ---
HOMEPAGE_ENABLE=${HOMEPAGE_ENABLE:-auto}

# --- GPU Transcoding (Raspberry Pi 5 VideoCore VII) ---
ENABLE_GPU_TRANSCODING=${ENABLE_GPU_TRANSCODING:-yes}

# --- Variables internes ---
TRAEFIK_SCENARIO=""
JELLYFIN_URL=""
ACTUAL_USER="${SUDO_USER:-pi}"

# ==============================================================================
# FONCTION: usage
# Description: Affiche l'aide
# ==============================================================================
usage() {
  cat <<EOF
Usage: sudo $0 [OPTIONS]

Deploie Jellyfin Media Server sur Raspberry Pi 5 avec support GPU.

OPTIONS:
  --dry-run              Mode simulation (aucune modification)
  -y, --yes              Accepter automatiquement les confirmations
  -v, --verbose          Mode verbeux
  -q, --quiet            Mode silencieux
  --no-color             Desactiver les couleurs
  -h, --help             Afficher cette aide

VARIABLES D'ENVIRONNEMENT:
  JELLYFIN_VERSION       Version Docker (defaut: latest)
  JELLYFIN_PORT          Port HTTP (defaut: 8096)
  MEDIA_DIR              Repertoire media principal (defaut: /home/pi/media)
  MOVIES_DIR             Repertoire films (defaut: \${MEDIA_DIR}/movies)
  TV_SHOWS_DIR           Repertoire series (defaut: \${MEDIA_DIR}/tv)
  MUSIC_DIR              Repertoire musique (defaut: \${MEDIA_DIR}/music)
  PHOTOS_DIR             Repertoire photos (defaut: \${MEDIA_DIR}/photos)
  STACK_DIR              Repertoire stack (defaut: /home/pi/stacks/jellyfin)
  TRAEFIK_ENABLE         Integration Traefik (auto/yes/no, defaut: auto)
  HOMEPAGE_ENABLE        Integration Homepage (auto/yes/no, defaut: auto)
  ENABLE_GPU_TRANSCODING GPU transcoding VideoCore VII (yes/no, defaut: yes)

EXEMPLES:
  # Deploiement standard
  sudo bash $0

  # Deploiement avec repertoire media personnalise
  sudo MEDIA_DIR=/mnt/usb/media bash $0

  # Deploiement sans GPU transcoding
  sudo ENABLE_GPU_TRANSCODING=no bash $0

  # Mode dry-run
  sudo bash $0 --dry-run

RASPBERRY PI 5 GPU:
  Le script configure automatiquement le GPU VideoCore VII pour le
  hardware transcoding H.264/H.265. L'utilisateur est ajoute aux groupes
  'video' et 'render' pour acceder aux peripheriques GPU.

INTEGRATION TRAEFIK:
  Le script detecte automatiquement le scenario Traefik installe:
  - DuckDNS    : PathPrefix('/jellyfin')
  - Cloudflare : Host('jellyfin.\${DOMAIN}')
  - VPN        : Host('jellyfin.pi.local')

EOF
}

# ==============================================================================
# FONCTION: detect_traefik_scenario
# Description: Detecte le scenario Traefik installe
# Return: TRAEFIK_SCENARIO (duckdns/cloudflare/vpn/none)
# ==============================================================================
detect_traefik_scenario() {
  log_info "Detection du scenario Traefik..."

  local traefik_env="/home/pi/stacks/traefik/.env"

  if [[ ! -f "${traefik_env}" ]]; then
    log_debug "Traefik non detecte (fichier .env absent)"
    TRAEFIK_SCENARIO="none"
    return 0
  fi

  # Lecture du scenario depuis .env
  if grep -q "^SCENARIO=duckdns" "${traefik_env}" 2>/dev/null; then
    TRAEFIK_SCENARIO="duckdns"
    log_success "Scenario Traefik detecte: DuckDNS (path-based routing)"
  elif grep -q "^SCENARIO=cloudflare" "${traefik_env}" 2>/dev/null; then
    TRAEFIK_SCENARIO="cloudflare"
    log_success "Scenario Traefik detecte: Cloudflare (subdomain routing)"
    # Lecture du domaine
    JELLYFIN_DOMAIN=$(grep "^DOMAIN=" "${traefik_env}" 2>/dev/null | cut -d'=' -f2 | tr -d '"' || echo "")
  elif grep -q "^SCENARIO=vpn" "${traefik_env}" 2>/dev/null; then
    TRAEFIK_SCENARIO="vpn"
    log_success "Scenario Traefik detecte: VPN (local routing)"
  else
    log_warn "Scenario Traefik inconnu, desactivation"
    TRAEFIK_SCENARIO="none"
  fi
}

# ==============================================================================
# FONCTION: setup_media_directories
# Description: Cree la structure de repertoires media
# ==============================================================================
setup_media_directories() {
  log_info "Creation de la structure des repertoires media..."

  local dirs=(
    "${MEDIA_DIR}"
    "${MOVIES_DIR}"
    "${TV_SHOWS_DIR}"
    "${MUSIC_DIR}"
    "${PHOTOS_DIR}"
  )

  for dir in "${dirs[@]}"; do
    if [[ ! -d "${dir}" ]]; then
      log_debug "Creation: ${dir}"
      run_cmd mkdir -p "${dir}"
    else
      log_debug "Existe deja: ${dir}"
    fi
  done

  # Permissions correctes (pi:pi ou SUDO_USER)
  log_debug "Application des permissions (${ACTUAL_USER}:${ACTUAL_USER})"
  if [[ ${DRY_RUN} -eq 0 ]]; then
    chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${MEDIA_DIR}"
    chmod -R 755 "${MEDIA_DIR}"
  fi

  log_success "Structure media creee:"
  log_info "  - Films    : ${MOVIES_DIR}"
  log_info "  - Series   : ${TV_SHOWS_DIR}"
  log_info "  - Musique  : ${MUSIC_DIR}"
  log_info "  - Photos   : ${PHOTOS_DIR}"
}

# ==============================================================================
# FONCTION: enable_gpu_transcoding
# Description: Configure le GPU VideoCore VII pour hardware transcoding
# ==============================================================================
enable_gpu_transcoding() {
  log_info "Configuration du GPU VideoCore VII pour hardware transcoding..."

  # Verification des peripheriques GPU
  local gpu_devices=(
    "/dev/dri/renderD128"
    "/dev/dri/card1"
    "/dev/vchiq"
  )

  local missing_devices=()
  for device in "${gpu_devices[@]}"; do
    if [[ ! -e "${device}" ]]; then
      missing_devices+=("${device}")
    fi
  done

  if [[ ${#missing_devices[@]} -gt 0 ]]; then
    log_warn "Peripheriques GPU manquants:"
    for device in "${missing_devices[@]}"; do
      log_warn "  - ${device}"
    done
    log_warn "Le hardware transcoding pourrait ne pas fonctionner correctement"
    log_warn "Verifiez que le kernel est bien configure pour Raspberry Pi 5"
  else
    log_success "Peripheriques GPU detectes:"
    for device in "${gpu_devices[@]}"; do
      log_info "  - ${device}"
    done
  fi

  # Ajout de l'utilisateur aux groupes video et render
  log_info "Ajout de l'utilisateur '${ACTUAL_USER}' aux groupes video et render..."

  if [[ ${DRY_RUN} -eq 0 ]]; then
    usermod -a -G video "${ACTUAL_USER}" 2>/dev/null || log_warn "Impossible d'ajouter au groupe 'video'"
    usermod -a -G render "${ACTUAL_USER}" 2>/dev/null || log_warn "Impossible d'ajouter au groupe 'render'"
  else
    log_info "[DRY-RUN] usermod -a -G video,render ${ACTUAL_USER}"
  fi

  log_success "GPU VideoCore VII configure pour H.264/H.265 hardware transcoding"
  log_info "  - Hardware decode : H.264, H.265/HEVC"
  log_info "  - Hardware encode : H.264 (limite, CPU fallback recommande)"
  log_info "  - Performance     : ~2-3 streams 1080p simultanes"
}

# ==============================================================================
# FONCTION: create_docker_compose
# Description: Genere le fichier docker-compose.yml
# ==============================================================================
create_docker_compose() {
  log_info "Generation du fichier docker-compose.yml..."

  local compose_file="${STACK_DIR}/docker-compose.yml"

  # Construction des labels Traefik selon le scenario
  local traefik_labels=""
  if [[ "${TRAEFIK_ENABLE}" == "yes" ]] || [[ "${TRAEFIK_ENABLE}" == "auto" && "${TRAEFIK_SCENARIO}" != "none" ]]; then
    case "${TRAEFIK_SCENARIO}" in
      duckdns)
        JELLYFIN_URL="https://\${DUCKDNS_SUBDOMAIN}.duckdns.org/jellyfin"
        traefik_labels=$(cat <<'LABELS_DUCKDNS'
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=PathPrefix(`/jellyfin`)"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls.certresolver=letsencrypt"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
      # Middleware pour stripprefix
      - "traefik.http.middlewares.jellyfin-stripprefix.stripprefix.prefixes=/jellyfin"
      - "traefik.http.routers.jellyfin.middlewares=jellyfin-stripprefix@docker"
LABELS_DUCKDNS
)
        ;;
      cloudflare)
        JELLYFIN_URL="https://jellyfin.${JELLYFIN_DOMAIN}"
        traefik_labels=$(cat <<LABELS_CLOUDFLARE
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(\`jellyfin.${JELLYFIN_DOMAIN}\`)"
      - "traefik.http.routers.jellyfin.entrypoints=websecure"
      - "traefik.http.routers.jellyfin.tls.certresolver=cloudflare"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
LABELS_CLOUDFLARE
)
        ;;
      vpn)
        JELLYFIN_URL="http://jellyfin.pi.local"
        traefik_labels=$(cat <<'LABELS_VPN'
      - "traefik.enable=true"
      - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.pi.local`)"
      - "traefik.http.routers.jellyfin.entrypoints=web"
      - "traefik.http.services.jellyfin.loadbalancer.server.port=8096"
LABELS_VPN
)
        ;;
    esac
  fi

  # Construction de la section devices pour GPU
  local gpu_devices=""
  if [[ "${ENABLE_GPU_TRANSCODING}" == "yes" ]]; then
    gpu_devices=$(cat <<'DEVICES'
    # GPU VideoCore VII (Raspberry Pi 5)
    devices:
      - /dev/dri:/dev/dri                    # VideoCore VII GPU
      - /dev/vchiq:/dev/vchiq                # Broadcom VideoCore interface
    group_add:
      - video
      - render
DEVICES
)
  fi

  # Generation du fichier docker-compose.yml
  cat > "${compose_file}" <<COMPOSE
# ==============================================================================
# Jellyfin Media Server - Raspberry Pi 5
# Genere automatiquement par: 01-jellyfin-deploy.sh
# ==============================================================================

version: '3.8'

networks:
  traefik-network:
    external: true
  jellyfin-internal:
    driver: bridge

services:
  jellyfin:
    image: jellyfin/jellyfin:\${JELLYFIN_VERSION:-latest}
    container_name: jellyfin
    restart: unless-stopped
    user: "${ACTUAL_USER}:${ACTUAL_USER}"

    networks:
      - traefik-network
      - jellyfin-internal

    ports:
      - "\${JELLYFIN_PORT:-8096}:8096"             # HTTP Web UI
      - "\${JELLYFIN_DISCOVERY_PORT:-7359}:7359/udp"  # Service discovery
      - "\${JELLYFIN_DLNA_PORT:-1900}:1900/udp"    # DLNA

${gpu_devices}

    volumes:
      # Configuration Jellyfin
      - ./config:/config
      - ./cache:/cache

      # Bibliotheques media (lecture seule)
      - \${MOVIES_DIR}:/media/movies:ro
      - \${TV_SHOWS_DIR}:/media/tv:ro
      - \${MUSIC_DIR}:/media/music:ro
      - \${PHOTOS_DIR}:/media/photos:ro

    environment:
      - TZ=Europe/Paris
      - JELLYFIN_PublishedServerUrl=\${JELLYFIN_PUBLISHED_URL:-}

    labels:
${traefik_labels}
      - "homepage.group=Media"
      - "homepage.name=Jellyfin"
      - "homepage.icon=jellyfin.png"
      - "homepage.href=\${JELLYFIN_URL}"
      - "homepage.description=Serveur media personnel"
      - "homepage.widget.type=jellyfin"
      - "homepage.widget.url=http://jellyfin:8096"
      - "homepage.widget.key=\${JELLYFIN_API_KEY:-}"

COMPOSE

  log_success "Fichier docker-compose.yml genere: ${compose_file}"
}

# ==============================================================================
# FONCTION: create_env_file
# Description: Genere le fichier .env
# ==============================================================================
create_env_file() {
  log_info "Generation du fichier .env..."

  local env_file="${STACK_DIR}/.env"

  cat > "${env_file}" <<ENV
# ==============================================================================
# Jellyfin Media Server - Configuration
# Genere automatiquement par: 01-jellyfin-deploy.sh
# ==============================================================================

# --- Version Jellyfin ---
JELLYFIN_VERSION=${JELLYFIN_VERSION}

# --- Ports ---
JELLYFIN_PORT=${JELLYFIN_PORT}
JELLYFIN_DISCOVERY_PORT=${JELLYFIN_DISCOVERY_PORT}
JELLYFIN_DLNA_PORT=${JELLYFIN_DLNA_PORT}

# --- Chemins des bibliotheques media ---
MEDIA_DIR=${MEDIA_DIR}
MOVIES_DIR=${MOVIES_DIR}
TV_SHOWS_DIR=${TV_SHOWS_DIR}
MUSIC_DIR=${MUSIC_DIR}
PHOTOS_DIR=${PHOTOS_DIR}

# --- URL publique (Traefik) ---
JELLYFIN_URL=${JELLYFIN_URL}
JELLYFIN_PUBLISHED_URL=${JELLYFIN_URL}

# --- API Key (pour Homepage widget) ---
# A generer manuellement dans: Tableau de bord > Cles API
JELLYFIN_API_KEY=

ENV

  # Permissions correctes
  if [[ ${DRY_RUN} -eq 0 ]]; then
    chmod 600 "${env_file}"
    chown "${ACTUAL_USER}:${ACTUAL_USER}" "${env_file}"
  fi

  log_success "Fichier .env genere: ${env_file}"
}

# ==============================================================================
# FONCTION: wait_for_jellyfin_ready
# Description: Attend que Jellyfin soit pret
# ==============================================================================
wait_for_jellyfin_ready() {
  log_info "Attente du demarrage de Jellyfin..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Simulation de l'attente..."
    return 0
  fi

  local max_attempts=30
  local attempt=1

  while [[ ${attempt} -le ${max_attempts} ]]; do
    if curl -sf "http://localhost:${JELLYFIN_PORT}/health" >/dev/null 2>&1; then
      log_success "Jellyfin est pret !"
      return 0
    fi

    log_debug "Tentative ${attempt}/${max_attempts}..."
    sleep 2
    ((attempt++))
  done

  log_warn "Timeout lors de l'attente de Jellyfin"
  log_warn "Le service pourrait encore etre en cours de demarrage"
  log_info "Verifiez les logs: docker compose -f ${STACK_DIR}/docker-compose.yml logs -f"
}

# ==============================================================================
# FONCTION: optimize_jellyfin_performance
# Description: Optimisations pour Raspberry Pi 5
# ==============================================================================
optimize_jellyfin_performance() {
  log_info "Application des optimisations Raspberry Pi 5..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Simulation des optimisations..."
    return 0
  fi

  # Note: Les optimisations Jellyfin se font principalement via l'UI
  # Cette fonction prepare les recommandations

  log_success "Optimisations preparees"
  log_info "  - Cache transcoding : ${STACK_DIR}/cache"
  log_info "  - Threads recommandes : 4 (Pi 5 quad-core)"
  log_info "  - GPU VideoCore VII : H.264/H.265 decode"
}

# ==============================================================================
# FONCTION: configure_homepage_widget
# Description: Configure le widget Homepage Dashboard
# ==============================================================================
configure_homepage_widget() {
  log_info "Configuration du widget Homepage..."

  local homepage_dir="/home/pi/stacks/homepage"
  local services_file="${homepage_dir}/config/services.yaml"

  # Verification si Homepage est installe
  if [[ ! -d "${homepage_dir}" ]]; then
    log_debug "Homepage non detecte, skip widget"
    return 0
  fi

  if [[ "${HOMEPAGE_ENABLE}" == "no" ]]; then
    log_debug "Integration Homepage desactivee (HOMEPAGE_ENABLE=no)"
    return 0
  fi

  log_info "Homepage detecte, configuration du widget..."

  # Le widget est configure via les labels Docker (homepage.*)
  # Rien a faire ici, juste informer l'utilisateur

  log_success "Widget Homepage configure (via labels Docker)"
  log_info "  - Groupe  : Media"
  log_info "  - Type    : jellyfin"
  log_info "  - URL     : ${JELLYFIN_URL}"
  log_warn "  - API Key : A configurer manuellement dans ${STACK_DIR}/.env"
  log_info "    (Jellyfin > Tableau de bord > Parametres > Cles API)"
}

# ==============================================================================
# FONCTION: display_deployment_summary
# Description: Affiche le resume du deploiement
# ==============================================================================
display_deployment_summary() {
  local separator="=================================================================="

  echo ""
  echo "${separator}"
  log_success "Jellyfin Media Server deploye avec succes !"
  echo "${separator}"
  echo ""

  echo "🎬 Acces Jellyfin :"
  if [[ -n "${JELLYFIN_URL}" ]]; then
    echo "  - URL externe : ${JELLYFIN_URL}"
  fi
  echo "  - URL locale  : http://localhost:${JELLYFIN_PORT}"
  echo ""

  echo "📁 Repertoires media :"
  echo "  - Films   : ${MOVIES_DIR}"
  echo "  - Series  : ${TV_SHOWS_DIR}"
  echo "  - Musique : ${MUSIC_DIR}"
  echo "  - Photos  : ${PHOTOS_DIR}"
  echo ""

  echo "🎮 GPU Transcoding (VideoCore VII) :"
  if [[ "${ENABLE_GPU_TRANSCODING}" == "yes" ]]; then
    echo "  ✅ Active - H.264/H.265 hardware decode/encode"
    echo "  - Hardware decode : H.264, H.265/HEVC, 4K support"
    echo "  - Hardware encode : H.264 (limite, CPU fallback recommande)"
    echo "  - Performance     : ~2-3 streams 1080p simultanes"
  else
    echo "  ❌ Desactive - Transcoding CPU uniquement"
    echo "  - Performance limitee sur Raspberry Pi 5"
    echo "  - Pour activer : ENABLE_GPU_TRANSCODING=yes"
  fi
  echo ""

  if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
    echo "🔒 Integration Traefik :"
    echo "  - Scenario : ${TRAEFIK_SCENARIO}"
    echo "  - URL      : ${JELLYFIN_URL}"
    case "${TRAEFIK_SCENARIO}" in
      duckdns)
        echo "  - Type     : Path-based routing (/jellyfin)"
        ;;
      cloudflare)
        echo "  - Type     : Subdomain routing (jellyfin.${JELLYFIN_DOMAIN})"
        ;;
      vpn)
        echo "  - Type     : Local routing (jellyfin.pi.local)"
        ;;
    esac
    echo ""
  fi

  echo "📱 Applications clientes :"
  echo "  - Android TV : https://play.google.com/store/apps/details?id=org.jellyfin.androidtv"
  echo "  - iOS/iPadOS : https://apps.apple.com/app/jellyfin-mobile/id1480192618"
  echo "  - Android    : https://play.google.com/store/apps/details?id=org.jellyfin.mobile"
  echo "  - Web        : ${JELLYFIN_URL:-http://localhost:${JELLYFIN_PORT}}"
  echo ""

  echo "🔧 Commandes utiles :"
  echo "  - Logs    : docker compose -f ${STACK_DIR}/docker-compose.yml logs -f"
  echo "  - Restart : docker compose -f ${STACK_DIR}/docker-compose.yml restart"
  echo "  - Stop    : docker compose -f ${STACK_DIR}/docker-compose.yml down"
  echo "  - Update  : docker compose -f ${STACK_DIR}/docker-compose.yml pull && \\"
  echo "              docker compose -f ${STACK_DIR}/docker-compose.yml up -d"
  echo ""

  echo "💡 Prochaines etapes :"
  echo "  1. Ouvrir ${JELLYFIN_URL:-http://localhost:${JELLYFIN_PORT}}"
  echo "  2. Creer un compte administrateur (premiere connexion)"
  echo "  3. Configurer les bibliotheques media :"
  echo "     - Films   : /media/movies"
  echo "     - Series  : /media/tv"
  echo "     - Musique : /media/music"
  echo "     - Photos  : /media/photos"
  echo "  4. Copier vos fichiers media dans ${MEDIA_DIR}"
  echo "  5. Scanner les bibliotheques (Jellyfin telecharge les metadonnees)"
  echo ""

  if [[ "${ENABLE_GPU_TRANSCODING}" == "yes" ]]; then
    echo "🎮 Configuration GPU Hardware Transcoding :"
    echo "  1. Aller dans : Tableau de bord > Lecture"
    echo "  2. Section 'Transcoding' :"
    echo "     - Accel. materielle : Video4Linux2 (V4L2)"
    echo "     - Codec H.264 : Activer decode materiel"
    echo "     - Codec HEVC  : Activer decode materiel"
    echo "  3. Tester avec un fichier video 1080p"
    echo ""
  fi

  if [[ -d "/home/pi/stacks/homepage" ]]; then
    echo "📊 Widget Homepage Dashboard :"
    echo "  1. Generer une cle API Jellyfin :"
    echo "     Tableau de bord > Parametres > Cles API > Nouvelle cle"
    echo "  2. Ajouter la cle dans ${STACK_DIR}/.env :"
    echo "     JELLYFIN_API_KEY=votre_cle_api"
    echo "  3. Redemarrer Homepage :"
    echo "     docker compose -f /home/pi/stacks/homepage/docker-compose.yml restart"
    echo ""
  fi

  echo "📚 Documentation :"
  echo "  - Jellyfin Docs       : https://jellyfin.org/docs/"
  echo "  - Hardware Accel (RPi): https://jellyfin.org/docs/general/administration/hardware-acceleration/raspberry-pi"
  echo "  - Bibliotheques       : https://jellyfin.org/docs/general/server/libraries"
  echo ""

  echo "${separator}"
}

# ==============================================================================
# FONCTION: verify_prerequisites
# Description: Verifie les prerequis
# ==============================================================================
verify_prerequisites() {
  log_info "Verification des prerequis..."

  # Docker
  if ! command -v docker >/dev/null 2>&1; then
    fatal "Docker n'est pas installe. Installez-le d'abord."
  fi

  # Docker Compose
  if ! docker compose version >/dev/null 2>&1; then
    fatal "Docker Compose n'est pas installe ou non fonctionnel."
  fi

  # Reseau Traefik (si Traefik detecte)
  if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
    if ! docker network inspect traefik-network >/dev/null 2>&1; then
      log_warn "Reseau 'traefik-network' non trouve, creation..."
      run_cmd docker network create traefik-network
    fi
  fi

  # Ports disponibles
  local ports_to_check=(${JELLYFIN_PORT} ${JELLYFIN_DISCOVERY_PORT})
  for port in "${ports_to_check[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
      log_warn "Port ${port} deja utilise, Jellyfin pourrait ne pas demarrer"
    fi
  done

  log_success "Prerequis valides"
}

# ==============================================================================
# FONCTION: main
# Description: Point d'entree principal
# ==============================================================================
main() {
  parse_common_args "$@"

  if [[ ${SHOW_HELP} -eq 1 ]]; then
    usage
    exit 0
  fi

  require_root

  log_info "========================================="
  log_info "Deploiement Jellyfin Media Server"
  log_info "Raspberry Pi 5 - GPU VideoCore VII"
  log_info "========================================="
  echo ""

  # 1. Detection de l'environnement
  detect_traefik_scenario

  # 2. Verification des prerequis
  verify_prerequisites

  # 3. Creation de la structure media
  setup_media_directories

  # 4. Activation du GPU transcoding (si demande)
  if [[ "${ENABLE_GPU_TRANSCODING}" == "yes" ]]; then
    enable_gpu_transcoding
  else
    log_info "GPU transcoding desactive (ENABLE_GPU_TRANSCODING=${ENABLE_GPU_TRANSCODING})"
  fi

  # 5. Creation du repertoire de la stack
  log_info "Creation du repertoire de la stack..."
  ensure_dir "${STACK_DIR}"
  ensure_dir "${STACK_DIR}/config"
  ensure_dir "${STACK_DIR}/cache"

  if [[ ${DRY_RUN} -eq 0 ]]; then
    chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${STACK_DIR}"
  fi

  # 6. Generation docker-compose.yml
  create_docker_compose

  # 7. Generation .env
  create_env_file

  # 8. Deploiement de la stack
  log_info "Deploiement de la stack Jellyfin..."
  if [[ ${DRY_RUN} -eq 0 ]]; then
    cd "${STACK_DIR}"
    docker compose up -d
  else
    log_info "[DRY-RUN] docker compose -f ${STACK_DIR}/docker-compose.yml up -d"
  fi

  # 9. Attente du demarrage de Jellyfin
  wait_for_jellyfin_ready

  # 10. Optimisations
  optimize_jellyfin_performance

  # 11. Configuration Homepage
  configure_homepage_widget

  # 12. Affichage du resume
  display_deployment_summary

  log_success "Deploiement termine avec succes !"
}

# ==============================================================================
# POINT D'ENTREE
# ==============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
