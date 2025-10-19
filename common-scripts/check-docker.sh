#!/bin/bash
# =============================================================================
# Docker Prerequisites Check - Helper function for deployment scripts
# =============================================================================
# Version: 1.0.0
# Usage: Source this file in deployment scripts
# =============================================================================

check_docker_prerequisites() {
    local missing_prereqs=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_prereqs+=("Docker")
    fi

    # Check Docker running
    if ! docker ps &> /dev/null 2>&1; then
        missing_prereqs+=("Docker daemon (not running)")
    fi

    # Check Docker Compose V2
    if ! docker compose version &> /dev/null 2>&1; then
        missing_prereqs+=("Docker Compose V2")
    fi

    # If any prerequisites missing, show helper message
    if [ ${#missing_prereqs[@]} -gt 0 ]; then
        echo -e "\033[0;31m[ERROR]\033[0m Prérequis manquants : ${missing_prereqs[*]}"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔧 Installation des prérequis requise"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Lancez d'abord le script de base pour installer Docker :"
        echo ""
        echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash"
        echo ""
        echo "Ce script installe :"
        echo "  ✅ Docker + Docker Compose"
        echo "  ✅ Portainer (interface Docker)"
        echo "  ✅ UFW Firewall"
        echo "  ✅ Fail2ban"
        echo "  ✅ Optimisations Pi 5"
        echo ""
        echo "Après redémarrage du Pi, relancez ce script."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi

    return 0
}

# Export function for sourcing
export -f check_docker_prerequisites 2>/dev/null || true
