#!/bin/bash
# =============================================================================
# Pi 5 Prerequisites Checker - Vérifie si le base setup est installé
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash common-scripts/00-check-prerequisites.sh
# =============================================================================
# Returns:
#   - Exit 0 : Tous les prérequis sont installés
#   - Exit 1 : Prérequis manquants (doit lancer 01-pi5-base-setup.sh)
# =============================================================================

set -euo pipefail

# Compteurs
TOTAL_CHECKS=6
PASSED_CHECKS=0

# Codes de sortie
EXIT_COMPLETE=0
EXIT_MISSING=1

check_docker() {
    if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

check_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

check_portainer() {
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

check_ufw() {
    if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

check_fail2ban() {
    if systemctl is-active fail2ban >/dev/null 2>&1; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

check_page_size() {
    local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
    if [[ "$page_size" == "4096" ]]; then
        ((PASSED_CHECKS++))
        return 0
    fi
    return 1
}

# Exécution des vérifications (silencieux)
check_docker 2>/dev/null || true
check_docker_compose 2>/dev/null || true
check_portainer 2>/dev/null || true
check_ufw 2>/dev/null || true
check_fail2ban 2>/dev/null || true
check_page_size 2>/dev/null || true

# Déterminer le statut
if [[ $PASSED_CHECKS -ge 5 ]]; then
    # Prérequis complets (on tolère 1 échec)
    echo "COMPLETE"
    exit $EXIT_COMPLETE
else
    # Prérequis manquants
    echo "MISSING"
    exit $EXIT_MISSING
fi
