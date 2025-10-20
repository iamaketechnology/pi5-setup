#!/bin/bash
# =============================================================================
# Pi Emulator - Get Info
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash get-emulator-info.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 PI EMULATOR - INFORMATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Détecter si on est sur Mac ou Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="Mac"
    LINUX_IP=$(grep "Host linux-pi-emulator" ~/.ssh/config -A 1 2>/dev/null | grep "HostName" | awk '{print $2}' || echo "Non configuré")
else
    PLATFORM="Linux"
    LINUX_IP=$(hostname -I | awk '{print $1}')
fi

echo "🖥️  PLATEFORME: ${PLATFORM}"
echo ""

# Infos Linux
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📍 LINUX MINT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "IP       : ${LINUX_IP}"
echo "User     : didi"
echo "SSH      : Port 22"
echo ""

if [[ "$PLATFORM" == "Mac" ]]; then
    echo "Connexion depuis Mac:"
    echo "  ssh linux-pi-emulator"
    echo "  OU ssh didi@${LINUX_IP}"
fi

echo ""

# Vérifier si émulateur tourne
if [[ "$PLATFORM" == "Linux" ]]; then
    EMULATOR_STATUS=$(docker ps --filter "name=pi-emulator-test" --format "{{.Status}}" 2>/dev/null || echo "Non trouvé")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐋 ÉMULATEUR PI (Docker)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$EMULATOR_STATUS" != "Non trouvé" ]]; then
        log_success "Émulateur actif"
        echo "Status   : ${EMULATOR_STATUS}"

        # Ports exposés
        echo ""
        echo "Ports exposés:"
        docker port pi-emulator-test 2>/dev/null | sed 's/^/  /'

        echo ""
        echo "Connexion SSH à l'émulateur:"
        echo "  ssh pi@localhost -p 2222"
        echo "  Password: raspberry"
    else
        log_warning "Émulateur non trouvé"
        echo ""
        echo "Pour démarrer l'émulateur:"
        echo "  cd tools/pi-emulator"
        echo "  bash scripts/01-pi-emulator-deploy-linux.sh"
    fi
else
    # Sur Mac - vérifier via SSH
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🐋 ÉMULATEUR PI (sur Linux)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$LINUX_IP" != "Non configuré" ]]; then
        EMULATOR_STATUS=$(ssh -o ConnectTimeout=2 linux-pi-emulator 'docker ps --filter "name=pi-emulator-test" --format "{{.Status}}"' 2>/dev/null || echo "Non accessible")

        if [[ "$EMULATOR_STATUS" != "Non accessible" ]] && [[ -n "$EMULATOR_STATUS" ]]; then
            log_success "Émulateur actif sur Linux"
            echo "Status   : ${EMULATOR_STATUS}"
            echo ""
            echo "Connexion via tunnel SSH:"
            echo "  ssh -L 2222:localhost:2222 linux-pi-emulator"
            echo "  Puis: ssh pi@localhost -p 2222"
        else
            log_warning "Émulateur non accessible"
            echo "Vérifier SSH vers Linux: ssh linux-pi-emulator"
        fi
    else
        log_warning "SSH vers Linux non configuré"
        echo ""
        echo "Pour configurer:"
        echo "  cd tools/pi-emulator"
        echo "  bash scripts/00-setup-ssh-access.sh"
    fi
fi

echo ""

# Infos Admin Panel
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎛️  ADMIN PANEL - CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Pour ajouter l'émulateur dans l'admin panel:"
echo ""
echo "┌─────────────────────────────────────────────┐"
echo "│ Champ          │ Valeur                     │"
echo "├─────────────────────────────────────────────┤"
echo "│ Nom            │ Pi Emulator Test           │"
echo "│ Host           │ ${LINUX_IP}                │"
echo "│ Port SSH       │ 2222                       │"
echo "│ Username       │ pi                         │"
echo "│ Password       │ raspberry                  │"
echo "│ Tags           │ test, emulator, dev        │"
echo "│ Couleur        │ #8b5cf6 (violet)           │"
echo "└─────────────────────────────────────────────┘"
echo ""

# Vérifier si admin panel tourne
if lsof -i :4000 >/dev/null 2>&1; then
    log_success "Admin panel actif sur http://localhost:4000"
else
    log_warning "Admin panel non actif"
    echo ""
    echo "Pour démarrer:"
    echo "  cd tools/admin-panel"
    echo "  npm start"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📚 COMMANDES UTILES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$PLATFORM" == "Mac" ]]; then
    echo "# SSH vers Linux"
    echo "ssh linux-pi-emulator"
    echo ""
    echo "# Voir logs émulateur (depuis Mac)"
    echo "ssh linux-pi-emulator 'docker logs pi-emulator-test -f'"
    echo ""
    echo "# Redémarrer émulateur (depuis Mac)"
    echo "ssh linux-pi-emulator 'docker restart pi-emulator-test'"
else
    echo "# Voir logs émulateur"
    echo "docker logs pi-emulator-test -f"
    echo ""
    echo "# Redémarrer émulateur"
    echo "docker restart pi-emulator-test"
    echo ""
    echo "# Arrêter émulateur"
    echo "docker stop pi-emulator-test"
    echo ""
    echo "# Supprimer émulateur"
    echo "docker rm -f pi-emulator-test"
fi

echo ""
echo "# Se connecter à l'émulateur"
echo "ssh pi@localhost -p 2222"
echo "# Password: raspberry"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
