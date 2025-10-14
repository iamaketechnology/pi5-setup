#!/bin/bash
# =============================================================================
# Fix Portainer - Bind to Localhost Only (Security Fix)
# =============================================================================
# Purpose: Reconfigure existing Portainer installation to bind localhost only
# Version: 1.0.0
# Author: PI5-SETUP Project
# Usage: sudo bash fix-portainer-localhost.sh
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
PORTAINER_CONTAINER="portainer"
PORTAINER_PORT="${PORTAINER_PORT:-8080}"
PORTAINER_IMAGE="portainer/portainer-ce:latest"

# =============================================================================
# Logging Functions
# =============================================================================

log()   { echo -e "${BLUE}[FIX-PORTAINER]${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*"; }

# =============================================================================
# Check Root
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être lancé en root"
    echo "Usage: sudo $0"
    exit 1
fi

# =============================================================================
# Main Script
# =============================================================================

main() {
    log "🔒 Sécurisation Portainer - Migration localhost..."
    echo ""

    # Vérifier si Portainer existe
    if ! docker ps -a --format '{{.Names}}' | grep -q "^${PORTAINER_CONTAINER}$"; then
        warn "Portainer n'est pas installé (container '$PORTAINER_CONTAINER' introuvable)"
        echo ""
        echo "Si Portainer est sous un autre nom, spécifiez :"
        echo "  PORTAINER_CONTAINER=mon_portainer sudo $0"
        exit 1
    fi

    # Afficher config actuelle
    log "📊 Configuration actuelle :"
    echo ""
    local current_ports=$(docker port "$PORTAINER_CONTAINER" 2>/dev/null || echo "N/A")
    echo "  Container: $PORTAINER_CONTAINER"
    echo "  Ports: $current_ports"
    echo ""

    # Vérifier si déjà localhost
    if echo "$current_ports" | grep -q "127.0.0.1:${PORTAINER_PORT}"; then
        ok "Portainer est déjà configuré en localhost only"
        echo ""
        echo "Accès via SSH tunnel :"
        echo "  ssh -L ${PORTAINER_PORT}:localhost:${PORTAINER_PORT} \$(whoami)@\$(hostname -I | awk '{print \$1}')"
        echo "  Puis ouvrir : http://localhost:${PORTAINER_PORT}"
        exit 0
    fi

    # Vérifier si port public
    if echo "$current_ports" | grep -q "0.0.0.0:${PORTAINER_PORT}"; then
        warn "Portainer est PUBLIC (0.0.0.0:${PORTAINER_PORT}) - RISQUE SÉCURITÉ"
        echo ""
    fi

    # Demander confirmation
    echo "🔄 Ce script va :"
    echo "  1. Arrêter le container Portainer actuel"
    echo "  2. Supprimer le container (les données sont préservées)"
    echo "  3. Recréer Portainer avec bind localhost (127.0.0.1:${PORTAINER_PORT})"
    echo ""
    read -p "Continuer ? [y/N] : " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Annulé par l'utilisateur"
        exit 0
    fi

    echo ""
    log "🛠️  Reconfiguration en cours..."
    echo ""

    # Étape 1 : Arrêter container
    log "1/4 - Arrêt du container..."
    docker stop "$PORTAINER_CONTAINER" >/dev/null 2>&1 || true
    ok "Container arrêté"

    # Étape 2 : Supprimer container (volume préservé)
    log "2/4 - Suppression du container (données préservées)..."
    docker rm "$PORTAINER_CONTAINER" >/dev/null 2>&1 || true
    ok "Container supprimé"

    # Étape 3 : Vérifier volume
    log "3/4 - Vérification du volume de données..."
    if docker volume ls | grep -q "portainer_data"; then
        ok "Volume portainer_data trouvé (données préservées)"
    else
        warn "Volume portainer_data introuvable (nouveau Portainer = nouvelle config)"
    fi

    # Étape 4 : Recréer avec localhost binding
    log "4/4 - Création nouveau container (localhost only)..."

    docker run -d \
        --name "$PORTAINER_CONTAINER" \
        --restart=always \
        -p "127.0.0.1:${PORTAINER_PORT}:9000" \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v portainer_data:/data \
        "$PORTAINER_IMAGE" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        ok "Container recréé avec succès"
    else
        error "Échec création container"
        exit 1
    fi

    # Vérifier nouvelle config
    echo ""
    log "🔍 Vérification nouvelle configuration..."
    sleep 2

    local new_ports=$(docker port "$PORTAINER_CONTAINER" 2>/dev/null)
    echo "  Ports: $new_ports"
    echo ""

    if echo "$new_ports" | grep -q "127.0.0.1:${PORTAINER_PORT}"; then
        ok "✅ SUCCÈS - Portainer est maintenant localhost only"
        echo ""

        # Netstat verification
        if command -v netstat &>/dev/null; then
            log "📊 Vérification netstat :"
            local netstat_result=$(sudo netstat -tlnp 2>/dev/null | grep ":${PORTAINER_PORT} " || echo "N/A")
            echo "$netstat_result" | while read line; do
                if echo "$line" | grep -q "127.0.0.1:${PORTAINER_PORT}"; then
                    echo -e "  ${GREEN}✅${NC} $line"
                elif echo "$line" | grep -q "0.0.0.0:${PORTAINER_PORT}"; then
                    echo -e "  ${RED}❌${NC} $line"
                else
                    echo "  $line"
                fi
            done
            echo ""
        fi

        # Instructions accès
        local pi_ip=$(hostname -I | awk '{print $1}')
        local pi_user=$(logname 2>/dev/null || echo "pi")

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🎉 PORTAINER SÉCURISÉ !"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📍 Accès LOCAL (depuis le Pi) :"
        echo "   http://localhost:${PORTAINER_PORT}"
        echo ""
        echo "📍 Accès DISTANT (depuis votre Mac/PC) :"
        echo ""
        echo "   1. Créer tunnel SSH :"
        echo "      ssh -L ${PORTAINER_PORT}:localhost:${PORTAINER_PORT} ${pi_user}@${pi_ip}"
        echo ""
        echo "   2. Ouvrir navigateur :"
        echo "      http://localhost:${PORTAINER_PORT}"
        echo ""
        echo "   3. (Optionnel) Tunnel permanent :"
        echo "      ssh -f -N -L ${PORTAINER_PORT}:localhost:${PORTAINER_PORT} ${pi_user}@${pi_ip}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🔒 Sécurité :"
        echo "  ✅ Portainer accessible UNIQUEMENT depuis le Pi"
        echo "  ✅ Impossible d'y accéder directement depuis Internet"
        echo "  ✅ Accès distant via SSH tunnel chiffré"
        echo ""
        echo "📚 Documentation SSH Tunneling :"
        echo "  docs/SSH-TUNNELING-GUIDE.md"
        echo ""
    else
        error "Configuration incorrecte après recréation"
        echo "Ports détectés : $new_ports"
        echo ""
        echo "Essayez manuellement :"
        echo "  docker stop $PORTAINER_CONTAINER"
        echo "  docker rm $PORTAINER_CONTAINER"
        echo "  docker run -d --name $PORTAINER_CONTAINER --restart=always -p 127.0.0.1:${PORTAINER_PORT}:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data $PORTAINER_IMAGE"
        exit 1
    fi
}

# =============================================================================
# Execute
# =============================================================================

main "$@"
