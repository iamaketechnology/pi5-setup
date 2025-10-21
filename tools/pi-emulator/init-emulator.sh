#!/bin/bash
# =============================================================================
# Émulateur Pi - Script d'Initialisation Automatique
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-10-20
# Author: PI5-SETUP Project
# Usage: Exécuté automatiquement lors de la création d'un émulateur
# =============================================================================
# Description:
#   Prépare un conteneur émulateur Debian pour être utilisé comme Pi5
#   - Installe Docker + Docker Compose
#   - Installe les dépendances système requises
#   - Configure l'environnement pour les scripts pi5-setup
# =============================================================================

set -euo pipefail

# =============================================================================
# Fonctions Logging
# =============================================================================

log_info() { echo -e "\033[0;34m[EMULATOR-INIT]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# =============================================================================
# Configuration
# =============================================================================

EMULATOR_NAME="${1:-pi-emulator}"
LOG_FILE="/var/log/emulator-init.log"

log_info "🚀 Initialisation de l'émulateur: $EMULATOR_NAME"

# Créer le fichier de log
mkdir -p "$(dirname "$LOG_FILE")"
exec &> >(tee -a "$LOG_FILE")

# =============================================================================
# 1. Mise à jour du système
# =============================================================================

log_info "📦 Mise à jour des paquets système..."
apt-get update -qq
apt-get upgrade -y -qq

# =============================================================================
# 2. Installation des dépendances de base
# =============================================================================

log_info "📦 Installation des dépendances de base..."
apt-get install -y -qq \
    curl \
    git \
    openssl \
    gpg \
    gnupg \
    ca-certificates \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    sudo \
    wget \
    ufw \
    htop \
    net-tools \
    iputils-ping

log_success "✅ Dépendances de base installées"

# =============================================================================
# 3. Installation de Docker
# =============================================================================

log_info "🐳 Installation de Docker..."

# Vérifier si Docker est déjà installé
if command -v docker &> /dev/null; then
    log_info "Docker déjà installé ($(docker --version))"
else
    # Ajouter la clé GPG officielle de Docker
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Ajouter le dépôt Docker
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | \
        tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Installer Docker
    apt-get update -qq
    apt-get install -y -qq \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    log_success "✅ Docker installé: $(docker --version)"
fi

# =============================================================================
# 4. Configuration de Docker
# =============================================================================

log_info "⚙️ Configuration de Docker..."

# Démarrer le service Docker
service docker start

# Vérifier que Docker fonctionne
if docker ps &> /dev/null; then
    log_success "✅ Docker fonctionne correctement"
else
    log_error "❌ Docker ne démarre pas"
    exit 1
fi

# =============================================================================
# 5. Création de la structure de répertoires
# =============================================================================

log_info "📁 Création de la structure de répertoires..."

mkdir -p /root/stacks
mkdir -p /root/backups
mkdir -p /root/logs
mkdir -p /tmp

log_success "✅ Répertoires créés"

# =============================================================================
# 6. Vérification finale
# =============================================================================

log_info "🔍 Vérification de l'installation..."

CHECKS_PASSED=0
CHECKS_TOTAL=0

# Check Docker
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if docker --version &> /dev/null; then
    log_success "✓ Docker installé"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ Docker manquant"
fi

# Check Docker Compose
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if docker compose version &> /dev/null; then
    log_success "✓ Docker Compose installé"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ Docker Compose manquant"
fi

# Check curl
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if command -v curl &> /dev/null; then
    log_success "✓ curl installé"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ curl manquant"
fi

# Check git
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if command -v git &> /dev/null; then
    log_success "✓ git installé"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ git manquant"
fi

# Check gpg
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if command -v gpg &> /dev/null; then
    log_success "✓ gpg installé"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ gpg manquant"
fi

# Check ~/stacks
CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
if [ -d /root/stacks ]; then
    log_success "✓ Répertoire ~/stacks existe"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "✗ Répertoire ~/stacks manquant"
fi

# =============================================================================
# Résumé
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 INITIALISATION ÉMULATEUR TERMINÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Vérifications : $CHECKS_PASSED/$CHECKS_TOTAL réussies"
echo "📍 Nom : $EMULATOR_NAME"
echo "🐳 Docker : $(docker --version)"
echo "📦 Docker Compose : $(docker compose version)"
echo "📂 Stacks : /root/stacks"
echo "📝 Log : $LOG_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$CHECKS_PASSED" -eq "$CHECKS_TOTAL" ]; then
    log_success "✅ Émulateur prêt pour PI5 Control Center"
    exit 0
else
    log_error "⚠️ Certaines vérifications ont échoué"
    exit 1
fi
