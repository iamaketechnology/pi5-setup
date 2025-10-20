#!/bin/bash
# =============================================================================
# Test SSH Connection Mac → Linux
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash test-ssh.sh [user@ip or ssh-alias]
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Variables
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
    log_error "Usage: bash test-ssh.sh [user@ip or ssh-alias]"
    echo ""
    echo "Exemples:"
    echo "  bash test-ssh.sh user@192.168.1.100"
    echo "  bash test-ssh.sh linux-mint"
    exit 1
fi

log_info "Test SSH Connection: ${TARGET}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Test 1: Connexion basique
log_info "Test 1/5: Connexion basique..."
if ssh -o ConnectTimeout=5 "${TARGET}" exit 2>/dev/null; then
    log_success "Connexion SSH OK"
else
    log_error "Connexion SSH échouée"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Vérifier IP/alias: ssh ${TARGET}"
    echo "  2. Vérifier SSH server sur Linux: sudo systemctl status ssh"
    echo "  3. Vérifier clé SSH: ls -la ~/.ssh/"
    exit 1
fi

echo ""

# Test 2: Commande simple
log_info "Test 2/5: Exécution commande..."
RESULT=$(ssh "${TARGET}" 'echo "Hello from Linux"' 2>/dev/null)
if [[ "$RESULT" == "Hello from Linux" ]]; then
    log_success "Exécution commande OK"
else
    log_error "Exécution commande échouée"
    exit 1
fi

echo ""

# Test 3: Info système
log_info "Test 3/5: Info système..."
ssh "${TARGET}" 'uname -a && echo "" && cat /etc/os-release | grep "PRETTY_NAME"' 2>/dev/null
log_success "Info système récupérée"

echo ""

# Test 4: Docker disponible
log_info "Test 4/5: Docker disponible..."
if ssh "${TARGET}" 'command -v docker &> /dev/null' 2>/dev/null; then
    DOCKER_VERSION=$(ssh "${TARGET}" 'docker --version' 2>/dev/null)
    log_success "Docker: ${DOCKER_VERSION}"
else
    log_error "Docker non installé sur Linux"
    echo "Installer: curl -fsSL https://get.docker.com | sh"
fi

echo ""

# Test 5: Permissions Docker
log_info "Test 5/5: Permissions Docker..."
if ssh "${TARGET}" 'docker ps &> /dev/null' 2>/dev/null; then
    log_success "Permissions Docker OK"
else
    log_error "Permissions Docker insuffisantes"
    REMOTE_USER=$(ssh "${TARGET}" 'whoami')
    echo "Fixer: ssh ${TARGET} 'sudo usermod -aG docker ${REMOTE_USER} && newgrp docker'"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ TESTS SSH TERMINÉS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_success "SSH opérationnel vers ${TARGET}"
echo ""
echo "📌 Prochaine étape - Lancer Pi Emulator:"
echo "   ssh ${TARGET} 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh"
echo ""
