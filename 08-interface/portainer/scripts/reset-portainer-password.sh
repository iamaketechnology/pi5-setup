#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Portainer Password Reset Script for Raspberry Pi 5
# =============================================================================
# Purpose: Reset Portainer admin password
# Architecture: ARM64 (Raspberry Pi 5)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 1 minute
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[PORTAINER]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]   \033[0m $*"; exit 1; }

# =============================================================================
# VALIDATION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

check_portainer_running() {
    if ! docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
        error "Container Portainer non trouvé. Est-il déployé ?"
    fi
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    log "==================================================================="
    log "  Réinitialisation Mot de Passe Portainer"
    log "==================================================================="
    echo

    require_root
    check_portainer_running

    # Get container info
    PORTAINER_VOLUME=$(docker inspect portainer --format '{{range .Mounts}}{{if eq .Destination "/data"}}{{.Source}}{{end}}{{end}}')

    if [[ -z "$PORTAINER_VOLUME" ]]; then
        error "Impossible de trouver le volume Portainer /data"
    fi

    log "Volume Portainer trouvé: $PORTAINER_VOLUME"
    echo

    # Check if admin password file exists
    if [[ ! -f "$PORTAINER_VOLUME/admin.password" ]]; then
        warn "Aucun fichier admin.password trouvé"
        warn "Le mot de passe n'a peut-être jamais été défini"
        echo
        read -p "Voulez-vous continuer quand même ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Opération annulée"
            exit 0
        fi
    fi

    # Confirmation
    warn "Cette opération va:"
    warn "  1. Arrêter le container Portainer"
    warn "  2. Supprimer le fichier admin.password"
    warn "  3. Redémarrer Portainer"
    warn "  4. Vous devrez créer un nouveau mot de passe via l'UI"
    echo
    read -p "Continuer ? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Opération annulée"
        exit 0
    fi
    echo

    # Stop Portainer
    log "Arrêt du container Portainer..."
    docker stop portainer
    ok "Container arrêté"
    echo

    # Backup admin.password if exists
    if [[ -f "$PORTAINER_VOLUME/admin.password" ]]; then
        log "Sauvegarde de l'ancien fichier admin.password..."
        cp "$PORTAINER_VOLUME/admin.password" "$PORTAINER_VOLUME/admin.password.backup.$(date +%Y%m%d_%H%M%S)"
        ok "Sauvegarde créée"
        echo
    fi

    # Remove admin.password
    log "Suppression du fichier admin.password..."
    rm -f "$PORTAINER_VOLUME/admin.password"
    ok "Fichier supprimé"
    echo

    # Start Portainer
    log "Redémarrage du container Portainer..."
    docker start portainer
    ok "Container redémarré"
    echo

    # Wait for Portainer to be ready
    log "Attente de la disponibilité de Portainer (10 secondes)..."
    sleep 10
    echo

    # Check status
    PORTAINER_STATUS=$(docker ps --filter 'name=portainer' --format '{{.Status}}')
    if [[ "$PORTAINER_STATUS" =~ "Up" ]]; then
        ok "Portainer est en cours d'exécution"
    else
        error "Portainer n'a pas démarré correctement"
    fi

    # Get access URLs
    PORTAINER_PORT=$(docker port portainer 9000 2>/dev/null | head -1 | cut -d: -f2)
    if [[ -z "$PORTAINER_PORT" ]]; then
        PORTAINER_PORT="8080"  # Default from common setup
    fi

    echo
    log "==================================================================="
    log "  ✅ MOT DE PASSE RÉINITIALISÉ AVEC SUCCÈS"
    log "==================================================================="
    echo
    ok "Prochaines étapes:"
    echo
    echo "1. Accédez à Portainer dans votre navigateur:"
    echo "   🌐 http://raspberrypi.local:$PORTAINER_PORT"
    echo "   🌐 http://$(hostname -I | awk '{print $1}'):$PORTAINER_PORT"
    echo
    echo "2. Vous verrez la page de création de compte admin"
    echo
    echo "3. Créez un nouveau mot de passe:"
    echo "   - Username: admin"
    echo "   - Password: [votre nouveau mot de passe]"
    echo "   - Confirm: [confirmation]"
    echo
    echo "4. Cliquez sur 'Create user'"
    echo
    warn "⚠️  IMPORTANT: Faites-le dans les 5 minutes suivant ce reset"
    warn "    sinon Portainer se verrouillera à nouveau"
    echo
    log "==================================================================="
}

# Run main function
main "$@"
