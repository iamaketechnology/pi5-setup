#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Ajouter une App au Cloudflare Tunnel Générique
#
# Description: Ajoute une app au tunnel existant (idempotent)
# Version: 1.0.0
# Usage: sudo bash 02-add-app-to-tunnel.sh --name certidoc --hostname certidoc.example.com --service certidoc-frontend:80
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
APP_HOSTNAME=""
APP_SERVICE=""
APP_NO_TLS_VERIFY="false"

#############################################################################
# Parse arguments
#############################################################################

usage() {
    cat << EOF
Usage: sudo bash $0 --name APP_NAME --hostname HOSTNAME --service SERVICE [OPTIONS]

Options:
  --name NAME              Nom de l'app (ex: certidoc)
  --hostname HOSTNAME      Hostname complet (ex: certidoc.example.com)
  --service SERVICE        Service Docker (ex: certidoc-frontend:80)
  --no-tls-verify          Désactiver vérification TLS (défaut: false)
  --help                   Afficher cette aide

Exemples:
  # Ajouter CertiDoc
  sudo bash $0 \\
    --name certidoc \\
    --hostname certidoc.example.com \\
    --service certidoc-frontend:80

  # Ajouter Supabase Studio
  sudo bash $0 \\
    --name studio \\
    --hostname studio.example.com \\
    --service supabase-studio:3000

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
            --hostname)
                APP_HOSTNAME="$2"
                shift 2
                ;;
            --service)
                APP_SERVICE="$2"
                shift 2
                ;;
            --no-tls-verify)
                APP_NO_TLS_VERIFY="true"
                shift
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

    # Validation
    if [[ -z "$APP_NAME" ]] || [[ -z "$APP_HOSTNAME" ]] || [[ -z "$APP_SERVICE" ]]; then
        error "Arguments manquants"
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

    if [[ ! -f "$TUNNEL_CONFIG" ]]; then
        error_exit "Configuration tunnel non trouvée: ${TUNNEL_CONFIG}"
    fi

    ok "Tunnel existant trouvé"
}

check_app_exists() {
    if jq -e ".apps[] | select(.name == \"$APP_NAME\")" "$APPS_DB" > /dev/null 2>&1; then
        warn "App '${APP_NAME}' existe déjà dans la base de données"

        read -p "$(echo -e "${YELLOW}Voulez-vous mettre à jour sa configuration ? [y/N]:${NC} ")" confirm

        case "$confirm" in
            [Yy]*)
                log "Mise à jour de l'app '${APP_NAME}'..."
                remove_app_from_db
                ;;
            *)
                error_exit "Opération annulée"
                ;;
        esac
    fi
}

#############################################################################
# Ajout de l'app
#############################################################################

remove_app_from_db() {
    log "Suppression de l'ancienne configuration..."

    jq "del(.apps[] | select(.name == \"$APP_NAME\"))" "$APPS_DB" > "${APPS_DB}.tmp"
    mv "${APPS_DB}.tmp" "$APPS_DB"

    ok "Ancienne configuration supprimée"
}

add_app_to_database() {
    log "Ajout de l'app '${APP_NAME}' à la base de données..."

    local new_app=$(cat <<EOF
{
  "name": "$APP_NAME",
  "hostname": "$APP_HOSTNAME",
  "service": "$APP_SERVICE",
  "no_tls_verify": $APP_NO_TLS_VERIFY,
  "added_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

    jq ".apps += [$new_app]" "$APPS_DB" > "${APPS_DB}.tmp"
    mv "${APPS_DB}.tmp" "$APPS_DB"

    ok "App ajoutée à la base de données"
}

regenerate_tunnel_config() {
    log "Regénération de la configuration tunnel..."

    # Sauvegarder l'ancienne config
    cp "$TUNNEL_CONFIG" "${TUNNEL_CONFIG}.backup-$(date +%Y%m%d_%H%M%S)"

    # Extraire header
    local tunnel_id=$(jq -r '.tunnel_name' "$APPS_DB" 2>/dev/null || echo "")
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

    # Ajouter toutes les apps depuis la DB
    jq -r '.apps[] | "  - hostname: \(.hostname)\n    service: http://\(.service)\n    originRequest:\n      noTLSVerify: \(.no_tls_verify)"' "$APPS_DB" >> "$TUNNEL_CONFIG"

    # Ajouter catch-all
    cat >> "$TUNNEL_CONFIG" << 'EOF'

  # Catch-all rule (obligatoire)
  - service: http_status:404
EOF

    ok "Configuration tunnel regénérée"
}

restart_tunnel() {
    log "Redémarrage du tunnel pour appliquer les changements..."

    cd "$BASE_DIR"

    if docker compose restart cloudflared 2>/dev/null; then
        sleep 3

        if docker ps --filter "name=cloudflared-tunnel" --format "{{.Names}}" | grep -q "cloudflared-tunnel"; then
            ok "✅ Tunnel redémarré avec succès"
        else
            error "Le tunnel ne s'est pas redémarré correctement"
            log "Logs:"
            docker logs cloudflared-tunnel --tail 20
            error_exit "Consultez les logs ci-dessus"
        fi
    else
        error_exit "Échec du redémarrage du tunnel"
    fi
}

show_summary() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     ✅ App Ajoutée au Tunnel !                              ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📦 Configuration :"
    echo "   • Nom : ${APP_NAME}"
    echo "   • URL : https://${APP_HOSTNAME}"
    echo "   • Service : ${APP_SERVICE}"
    echo ""
    echo "🌐 Configuration DNS requise :"
    echo ""
    echo "   Ajoutez un record DNS A dans Cloudflare :"
    echo ""
    echo "   Type : A"
    echo "   Name : $(echo "$APP_HOSTNAME" | sed "s/.$(jq -r '.domain' "$APPS_DB")//")"
    echo "   Content : $(curl -s ifconfig.me || echo "VOTRE_IP_PUBLIQUE")"
    echo "   Proxy : DNS only (gris)"
    echo "   TTL : Auto"
    echo ""
    echo "🧪 Test de l'app :"
    echo ""
    echo "   # Attendre 5-10 minutes (propagation DNS)"
    echo "   curl -I https://${APP_HOSTNAME}"
    echo ""
    echo "📊 Voir toutes les apps :"
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

    log "Ajout de l'app '${APP_NAME}' au tunnel Cloudflare..."
    echo ""

    check_tunnel_exists
    check_app_exists
    add_app_to_database
    regenerate_tunnel_config
    restart_tunnel
    show_summary
}

main "$@"
