#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Supprimer une App du Cloudflare Tunnel
#
# Description: Retire une app du tunnel (idempotent)
# Version: 1.0.0
# Usage: sudo bash 03-remove-app-from-tunnel.sh --name certidoc
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

error_exit() {
    error "$1"
    exit 1
}

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${BASE_DIR}/config"
APPS_DB="${CONFIG_DIR}/apps.json"
TUNNEL_CONFIG="${CONFIG_DIR}/config.yml"

APP_NAME=""

#############################################################################
# Parse arguments
#############################################################################

usage() {
    cat << EOF
Usage: sudo bash $0 --name APP_NAME

Options:
  --name NAME       Nom de l'app à supprimer
  --help            Afficher cette aide

Exemple:
  sudo bash $0 --name certidoc

EOF
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                APP_NAME="$2"
                shift 2
                ;;
            --help)
                usage
                ;;
            *)
                error "Argument invalide: $1"
                usage
                ;;
        esac
    done

    if [[ -z "$APP_NAME" ]]; then
        error "Argument manquant: --name"
        usage
    fi
}

#############################################################################
# Vérifications
#############################################################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error_exit "Ce script doit être exécuté en tant que root"
    fi
}

check_tunnel_exists() {
    if [[ ! -f "$APPS_DB" ]]; then
        error_exit "Base de données apps non trouvée: ${APPS_DB}"
    fi
}

check_app_exists() {
    if ! jq -e ".apps[] | select(.name == \"$APP_NAME\")" "$APPS_DB" > /dev/null 2>&1; then
        error_exit "App '${APP_NAME}' non trouvée dans la base de données"
    fi

    ok "App '${APP_NAME}' trouvée"
}

#############################################################################
# Suppression
#############################################################################

remove_app() {
    log "Suppression de l'app '${APP_NAME}' de la base de données..."

    jq "del(.apps[] | select(.name == \"$APP_NAME\"))" "$APPS_DB" > "${APPS_DB}.tmp"
    mv "${APPS_DB}.tmp" "$APPS_DB"

    ok "App supprimée de la base de données"
}

regenerate_tunnel_config() {
    log "Regénération de la configuration tunnel..."

    # Sauvegarder
    cp "$TUNNEL_CONFIG" "${TUNNEL_CONFIG}.backup-$(date +%Y%m%d_%H%M%S)"

    # Extraire infos
    local domain=$(jq -r '.domain' "$APPS_DB")

    # Recréer config
    cat > "$TUNNEL_CONFIG" << EOF
# Cloudflare Tunnel - Configuration Générique
# Regénéré le: $(date)
# Domaine: ${domain}

tunnel: $(grep '^tunnel:' "${TUNNEL_CONFIG}.backup-"* | tail -1 | cut -d' ' -f2)
credentials-file: /etc/cloudflared/credentials.json

ingress:
EOF

    # Ajouter apps restantes
    jq -r '.apps[] | "  - hostname: \(.hostname)\n    service: http://\(.service)\n    originRequest:\n      noTLSVerify: \(.no_tls_verify)"' "$APPS_DB" >> "$TUNNEL_CONFIG"

    # Catch-all
    cat >> "$TUNNEL_CONFIG" << 'EOF'

  # Catch-all rule (obligatoire)
  - service: http_status:404
EOF

    ok "Configuration regénérée"
}

restart_tunnel() {
    log "Redémarrage du tunnel..."

    cd "$BASE_DIR"

    if docker compose restart cloudflared 2>/dev/null; then
        sleep 3
        ok "✅ Tunnel redémarré"
    else
        warn "Échec du redémarrage (peut-être déjà arrêté)"
    fi
}

show_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ✅ App Supprimée du Tunnel !                            ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 App supprimée : ${APP_NAME}"
    echo ""
    echo "📊 Voir les apps restantes :"
    echo ""
    echo "   sudo bash ${SCRIPT_DIR}/04-list-tunnel-apps.sh"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    check_root
    parse_args "$@"

    log "Suppression de l'app '${APP_NAME}'..."
    echo ""

    check_tunnel_exists
    check_app_exists
    remove_app
    regenerate_tunnel_config
    restart_tunnel
    show_summary
}

main "$@"
