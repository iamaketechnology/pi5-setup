#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Cloudflare Tunnel - Installation Générique (Multi-Apps)
#
# Description: Installe un tunnel Cloudflare unique pour gérer plusieurs apps
# Version: 1.0.0
# Author: PI5-SETUP Project
# Idempotent: ✅ Oui (détecte installations existantes)
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

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${BASE_DIR}/config"
COMPOSE_FILE="${BASE_DIR}/docker-compose.yml"
APPS_DB="${CONFIG_DIR}/apps.json"
TUNNEL_CONFIG="${CONFIG_DIR}/config.yml"
CREDENTIALS_FILE="${CONFIG_DIR}/credentials.json"
LOG_FILE="/var/log/cloudflare-tunnel-generic-$(date +%Y%m%d_%H%M%S).log"

TUNNEL_NAME="pi5-generic-tunnel"
CF_DOMAIN=""
CF_TUNNEL_ID=""
SETUP_METHOD=""

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
║     ☁️  Cloudflare Tunnel - Installation Générique                  ║
║                                                                      ║
║     Version 1.0.0 - Multi-Apps                                      ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

#############################################################################
# Vérifications prérequis
#############################################################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    section "🔍 Vérification des prérequis"

    log "Vérification 1/3 : Docker..."
    if ! command -v docker &> /dev/null; then
        error_exit "Docker n'est pas installé. Installez-le d'abord."
    fi
    ok "Docker installé"

    log "Vérification 2/3 : Docker Compose..."
    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin manquant"
    fi
    ok "Docker Compose installé"

    log "Vérification 3/3 : jq (pour JSON)..."
    if ! command -v jq &> /dev/null; then
        log "Installation de jq..."
        apt-get update -qq && apt-get install -y jq
    fi
    ok "jq installé"

    echo ""
}

check_existing_installation() {
    section "🔍 Détection installation existante"

    # Vérifier si tunnel déjà configuré
    if [[ -f "$TUNNEL_CONFIG" ]] && [[ -f "$CREDENTIALS_FILE" ]]; then
        warn "Configuration tunnel existante détectée !"
        echo ""
        cat << EOF
Fichiers trouvés :
  • ${TUNNEL_CONFIG}
  • ${CREDENTIALS_FILE}

EOF
        read -p "$(echo -e "${YELLOW}Voulez-vous réinstaller ? (cela écrasera la config) [y/N]:${NC} ")" confirm

        case "$confirm" in
            [Yy]*)
                warn "Réinstallation demandée"
                ;;
            *)
                error_exit "Installation annulée. Configuration existante conservée."
                ;;
        esac
    else
        ok "Aucune installation existante trouvée"
    fi

    # Vérifier container actif
    if docker ps --filter "name=cloudflared-tunnel" --format "{{.Names}}" | grep -q "cloudflared-tunnel"; then
        warn "Container cloudflared-tunnel déjà actif"
        read -p "$(echo -e "${YELLOW}Voulez-vous le recréer ? [y/N]:${NC} ")" confirm

        case "$confirm" in
            [Yy]*)
                log "Arrêt du container existant..."
                cd "$BASE_DIR" 2>/dev/null || true
                docker compose down 2>/dev/null || true
                ok "Container arrêté"
                ;;
            *)
                error_exit "Installation annulée"
                ;;
        esac
    fi

    echo ""
}

#############################################################################
# Installation cloudflared
#############################################################################

install_cloudflared() {
    section "📦 Installation de cloudflared"

    if command -v cloudflared &> /dev/null; then
        ok "cloudflared déjà installé ($(cloudflared --version 2>&1 | head -1))"
        return 0
    fi

    log "Détection architecture..."
    local arch=$(uname -m)
    local cloudflared_arch=""

    case "$arch" in
        aarch64|arm64)
            cloudflared_arch="arm64"
            ;;
        armv7l|armhf)
            cloudflared_arch="arm"
            ;;
        x86_64|amd64)
            cloudflared_arch="amd64"
            ;;
        *)
            error_exit "Architecture non supportée: $arch"
            ;;
    esac

    ok "Architecture: ${arch} → cloudflared-${cloudflared_arch}"

    log "Téléchargement de cloudflared..."
    local download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cloudflared_arch}"

    if curl -fsSL "$download_url" -o /usr/local/bin/cloudflared; then
        chmod +x /usr/local/bin/cloudflared
        ok "cloudflared installé avec succès"
    else
        error_exit "Échec du téléchargement de cloudflared"
    fi

    echo ""
}

#############################################################################
# Configuration interactive
#############################################################################

prompt_setup_method() {
    section "🎯 Méthode d'installation"

    cat << 'EOF'
Deux méthodes sont disponibles :

┌─────────────────────────────────────────────────────────────────────┐
│ Méthode A : Configuration automatique (RECOMMANDÉ)                  │
├─────────────────────────────────────────────────────────────────────┤
│ • Connexion via navigateur                                          │
│ • Cloudflared crée le tunnel automatiquement                        │
│ • Configuration DNS automatique                                     │
│ • Plus simple et rapide                                             │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ Méthode B : Configuration manuelle (Token)                          │
├─────────────────────────────────────────────────────────────────────┤
│ • Créer le tunnel dans Cloudflare Dashboard                         │
│ • Copier-coller le token                                            │
│ • Plus de contrôle                                                  │
└─────────────────────────────────────────────────────────────────────┘

EOF

    read -p "Choisissez votre méthode [A/B] (défaut: A): " method
    method=$(echo "${method:-A}" | tr '[:lower:]' '[:upper:]')

    case "$method" in
        A|"")
            SETUP_METHOD="automatic"
            setup_automatic
            ;;
        B)
            SETUP_METHOD="manual"
            setup_manual
            ;;
        *)
            warn "Choix invalide, utilisation de la méthode A"
            SETUP_METHOD="automatic"
            setup_automatic
            ;;
    esac
}

#############################################################################
# Setup automatique (OAuth)
#############################################################################

setup_automatic() {
    section "🚀 Configuration automatique"

    cat << 'EOF'
📋 Instructions :

1. Une URL va s'afficher dans le terminal
2. Ouvrez cette URL dans votre navigateur
3. Connectez-vous à Cloudflare
4. Autorisez l'accès
5. Le tunnel sera créé automatiquement

Appuyez sur Entrée pour continuer...
EOF

    read

    log "Lancement authentification Cloudflare..."
    if ! cloudflared tunnel login; then
        error_exit "Échec de l'authentification Cloudflare"
    fi
    ok "Authentification réussie"

    log "Création du tunnel '${TUNNEL_NAME}'..."
    if ! cloudflared tunnel create "$TUNNEL_NAME" 2>&1 | tee -a "$LOG_FILE"; then
        error_exit "Échec de la création du tunnel"
    fi

    # Extraire l'ID du tunnel
    CF_TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}' | head -1)

    if [[ -z "$CF_TUNNEL_ID" ]]; then
        error_exit "Impossible d'extraire l'ID du tunnel"
    fi

    ok "Tunnel créé avec ID: ${CF_TUNNEL_ID}"

    # Demander le domaine
    echo ""
    read -p "Entrez votre domaine (ex: example.com): " CF_DOMAIN

    if [[ -z "$CF_DOMAIN" ]]; then
        error_exit "Domaine requis"
    fi

    ok "Domaine configuré: ${CF_DOMAIN}"

    # Copier les credentials
    if [[ -f "/root/.cloudflared/${CF_TUNNEL_ID}.json" ]]; then
        mkdir -p "$CONFIG_DIR"
        cp "/root/.cloudflared/${CF_TUNNEL_ID}.json" "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
        ok "Credentials copiées"
    else
        warn "Credentials non trouvées dans /root/.cloudflared/"
    fi

    echo ""
}

#############################################################################
# Setup manuel (Token)
#############################################################################

setup_manual() {
    section "🔧 Configuration manuelle"

    cat << 'EOF'
📋 Instructions :

1. Accédez à : https://one.dash.cloudflare.com/
2. Sélectionnez votre compte
3. Allez dans : Networks → Tunnels
4. Cliquez sur "Create a tunnel"
5. Choisissez "Cloudflared"
6. Donnez un nom (ex: pi5-generic-tunnel)
7. Copiez le TOKEN qui commence par "eyJ..."

Appuyez sur Entrée quand prêt...
EOF

    read

    # Demander le token
    read -sp "Collez votre Cloudflare Tunnel Token: " CF_TOKEN
    echo ""

    if [[ -z "$CF_TOKEN" ]]; then
        error_exit "Token requis"
    fi

    if [[ ! "$CF_TOKEN" =~ ^eyJ ]]; then
        error_exit "Format de token invalide (doit commencer par 'eyJ')"
    fi

    ok "Token reçu"

    # Extraire tunnel ID
    CF_TUNNEL_ID=$(echo "$CF_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.t' 2>/dev/null || echo "")

    if [[ -z "$CF_TUNNEL_ID" ]]; then
        read -p "Entrez manuellement l'ID du tunnel: " CF_TUNNEL_ID
    fi

    # Demander le domaine
    read -p "Entrez votre domaine (ex: example.com): " CF_DOMAIN

    if [[ -z "$CF_DOMAIN" ]]; then
        error_exit "Domaine requis"
    fi

    ok "Configuration manuelle complète"

    # Sauvegarder token
    mkdir -p "$CONFIG_DIR"
    echo "$CF_TOKEN" > "${CONFIG_DIR}/tunnel-token.txt"
    chmod 600 "${CONFIG_DIR}/tunnel-token.txt"

    echo ""
}

#############################################################################
# Création structure configuration
#############################################################################

create_directory_structure() {
    section "📁 Création de la structure"

    mkdir -p "$CONFIG_DIR"
    mkdir -p "${BASE_DIR}/logs"

    ok "Structure créée"
    echo ""
}

initialize_apps_database() {
    section "🗄️  Initialisation base de données apps"

    cat > "$APPS_DB" << 'EOF'
{
  "tunnel_name": "pi5-generic-tunnel",
  "domain": "",
  "apps": []
}
EOF

    # Mettre à jour avec les vraies valeurs
    jq --arg domain "$CF_DOMAIN" '.domain = $domain' "$APPS_DB" > "${APPS_DB}.tmp" && mv "${APPS_DB}.tmp" "$APPS_DB"

    chmod 600 "$APPS_DB"
    ok "Base de données initialisée: ${APPS_DB}"
    echo ""
}

#############################################################################
# Génération config tunnel
#############################################################################

generate_tunnel_config() {
    section "⚙️  Génération configuration tunnel"

    cat > "$TUNNEL_CONFIG" << EOF
# Cloudflare Tunnel - Configuration Générique
# Généré le: $(date)
# Tunnel ID: ${CF_TUNNEL_ID}
# Domaine: ${CF_DOMAIN}

tunnel: ${CF_TUNNEL_ID}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  # Les apps seront ajoutées ici via add-app-to-tunnel.sh
  # Exemple:
  # - hostname: app.${CF_DOMAIN}
  #   service: http://app-container:80

  # Catch-all rule (obligatoire, toujours en dernier)
  - service: http_status:404
EOF

    chmod 600 "$TUNNEL_CONFIG"
    ok "Configuration générée: ${TUNNEL_CONFIG}"
    echo ""
}

#############################################################################
# Génération Docker Compose
#############################################################################

generate_docker_compose() {
    section "🐳 Génération docker-compose.yml"

    if [[ "$SETUP_METHOD" == "manual" ]]; then
        # Mode token
        local token=$(cat "${CONFIG_DIR}/tunnel-token.txt")

        cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${token}
    networks:
      - traefik_network
      - supabase_network
    # Healthcheck désactivé: cloudflared utilise une image distroless sans shell
    # restart: unless-stopped assure le redémarrage automatique en cas de crash

networks:
  traefik_network:
    external: true
    name: traefik_network
  supabase_network:
    external: true
    name: supabase_network
EOF
    else
        # Mode config file
        cat > "$COMPOSE_FILE" << EOF
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./config/config.yml:/etc/cloudflared/config.yml:ro
      - ./config/credentials.json:/etc/cloudflared/credentials.json:ro
    networks:
      - traefik_network
      - supabase_network
    # Healthcheck désactivé: cloudflared utilise une image distroless sans shell
    # restart: unless-stopped assure le redémarrage automatique en cas de crash

networks:
  traefik_network:
    external: true
    name: traefik_network
  supabase_network:
    external: true
    name: supabase_network
EOF
    fi

    ok "docker-compose.yml généré"
    echo ""
}

#############################################################################
# Démarrage tunnel
#############################################################################

start_tunnel() {
    section "🚀 Démarrage du tunnel"

    cd "$BASE_DIR"

    log "Pull de l'image cloudflare/cloudflared..."
    docker compose pull

    log "Démarrage du container..."
    docker compose up -d

    sleep 5

    if docker ps --filter "name=cloudflared-tunnel" --format "{{.Names}}" | grep -q "cloudflared-tunnel"; then
        ok "✅ Tunnel démarré avec succès !"
    else
        error "Le tunnel n'a pas démarré correctement"
        log "Logs du container:"
        docker logs cloudflared-tunnel --tail 20
        error_exit "Consultez les logs ci-dessus"
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
║     ✅ Cloudflare Tunnel Générique Installé !                       ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📦 Configuration :
   • Tunnel ID : ${CF_TUNNEL_ID}
   • Domaine : ${CF_DOMAIN}
   • Base de données apps : ${APPS_DB}
   • Config tunnel : ${TUNNEL_CONFIG}

🎯 Prochaines étapes :

1. Ajouter votre première app (CertiDoc par exemple) :

   sudo bash ${SCRIPT_DIR}/02-add-app-to-tunnel.sh \\
     --name certidoc \\
     --hostname certidoc.${CF_DOMAIN} \\
     --service certidoc-frontend:80

2. Lister les apps configurées :

   sudo bash ${SCRIPT_DIR}/04-list-tunnel-apps.sh

3. Voir les logs :

   cd ${BASE_DIR}
   docker logs -f cloudflared-tunnel

🆘 Gestion du tunnel :

   Arrêter :  cd ${BASE_DIR} && docker compose down
   Démarrer : cd ${BASE_DIR} && docker compose up -d
   Logs :     docker logs -f cloudflared-tunnel

📚 Documentation :
   ${BASE_DIR}/README.md

EOF

    ok "Installation terminée avec succès !"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    banner
    check_root
    check_dependencies
    check_existing_installation
    install_cloudflared
    prompt_setup_method
    create_directory_structure
    initialize_apps_database
    generate_tunnel_config
    generate_docker_compose
    start_tunnel
    show_summary
}

main "$@"
