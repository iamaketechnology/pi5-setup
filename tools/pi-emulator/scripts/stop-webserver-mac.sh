#!/bin/bash
# =============================================================================
# Stop Web Server - Mac
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash stop-webserver-mac.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

log_info "Arrêt Serveur Web"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Chercher PID sauvegardé
if [[ -f /tmp/webserver-pi-emulator.pid ]]; then
    SERVER_PID=$(cat /tmp/webserver-pi-emulator.pid)

    if ps -p ${SERVER_PID} > /dev/null 2>&1; then
        log_info "Arrêt du serveur (PID: ${SERVER_PID})..."
        kill ${SERVER_PID}
        rm /tmp/webserver-pi-emulator.pid
        log_success "Serveur arrêté"
    else
        log_info "Serveur déjà arrêté (PID obsolète)"
        rm /tmp/webserver-pi-emulator.pid
    fi
else
    # Chercher processus python http.server sur port 8000
    log_info "Recherche du serveur en cours d'exécution..."

    SERVER_PID=$(lsof -ti:8000 2>/dev/null || echo "")

    if [[ -n "$SERVER_PID" ]]; then
        log_info "Serveur trouvé (PID: ${SERVER_PID})"
        kill ${SERVER_PID}
        log_success "Serveur arrêté"
    else
        log_info "Aucun serveur actif trouvé"
    fi
fi

# Nettoyer fichiers temporaires
rm -f /tmp/webserver-pi-emulator.log

echo ""
log_success "Nettoyage terminé"
