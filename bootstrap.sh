#!/bin/bash
# =============================================================================
# PI5-SETUP Bootstrap Script - One-liner installation
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
#
# Usage: curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/bootstrap.sh | sudo bash
# =============================================================================

set -euo pipefail

# =============================================================================
# Logging Functions
# =============================================================================

log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# =============================================================================
# Banner
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 PI5 SETUP - Bootstrap Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Installing PI5 Control Center..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# Variables
# =============================================================================

CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")
INSTALL_DIR="${USER_HOME}/pi5-control-center"
REPO_URL="https://github.com/iamaketechnology/pi5-setup.git"
CONTROL_CENTER_PORT=4000

# =============================================================================
# Validation
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être lancé avec sudo"
    exit 1
fi

# =============================================================================
# Step 1: Install Docker (if not already installed)
# =============================================================================

log_info "Vérification de Docker..."

if command -v docker &> /dev/null; then
    log_success "Docker déjà installé ($(docker --version))"
else
    log_info "Installation de Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "${CURRENT_USER}"
    systemctl enable docker
    systemctl start docker
    log_success "Docker installé avec succès"
fi

# =============================================================================
# Step 2: Clone repository
# =============================================================================

log_info "Clonage du repository pi5-setup..."

if [[ -d "${INSTALL_DIR}" ]]; then
    log_info "Le répertoire existe déjà, mise à jour..."
    cd "${INSTALL_DIR}"
    sudo -u "${CURRENT_USER}" git pull
else
    sudo -u "${CURRENT_USER}" git clone "${REPO_URL}" "${INSTALL_DIR}"
fi

cd "${INSTALL_DIR}"
log_success "Repository cloné/mis à jour"

# =============================================================================
# Step 3: Setup Control Center
# =============================================================================

log_info "Configuration du Control Center..."

cd "${INSTALL_DIR}/tools/admin-panel"

# Generate SSH key if not exists
if [[ ! -f "${USER_HOME}/.ssh/id_rsa" ]]; then
    log_info "Génération de la clé SSH..."
    sudo -u "${CURRENT_USER}" ssh-keygen -t rsa -b 4096 -f "${USER_HOME}/.ssh/id_rsa" -N "" -q
    log_success "Clé SSH générée"
fi

# Create config.js from example
if [[ ! -f config.js ]]; then
    log_info "Création de la configuration..."

    # Get Pi IP address
    PI_IP=$(hostname -I | awk '{print $1}')

    # Copy and customize config
    cp config.example.js config.js

    # Update config with Pi IP and localhost SSH
    sed -i "s/192.168.1.118/127.0.0.1/g" config.js
    sed -i "s/Pi Production/Pi Local/g" config.js

    log_success "Configuration créée"
fi

# Create data directory
mkdir -p data
chown -R "${CURRENT_USER}:${CURRENT_USER}" data

# Install dependencies
log_info "Installation des dépendances npm..."
sudo -u "${CURRENT_USER}" npm install --silent

log_success "Control Center configuré"

# =============================================================================
# Step 4: Create systemd service
# =============================================================================

log_info "Création du service systemd..."

cat > /etc/systemd/system/pi5-control-center.service <<EOF
[Unit]
Description=PI5 Control Center
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${INSTALL_DIR}/tools/admin-panel
ExecStart=/usr/bin/node ${INSTALL_DIR}/tools/admin-panel/server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pi5-control-center

Environment=NODE_ENV=production
Environment=PORT=${CONTROL_CENTER_PORT}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable pi5-control-center.service
systemctl start pi5-control-center.service

log_success "Service systemd créé et démarré"

# =============================================================================
# Step 5: Wait for service to start
# =============================================================================

log_info "Attente du démarrage du service..."
sleep 5

# Check if service is running
if systemctl is-active --quiet pi5-control-center.service; then
    log_success "Service démarré avec succès"
else
    log_error "Échec du démarrage du service"
    journalctl -u pi5-control-center.service --no-pager -n 20
    exit 1
fi

# =============================================================================
# Final Summary
# =============================================================================

PI_IP=$(hostname -I | awk '{print $1}')
PI_HOSTNAME=$(hostname)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 PI5 CONTROL CENTER INSTALLÉ AVEC SUCCÈS !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Accès local :"
echo "   http://${PI_IP}:${CONTROL_CENTER_PORT}"
echo "   http://${PI_HOSTNAME}.local:${CONTROL_CENTER_PORT}"
echo ""
echo "📋 Commandes utiles :"
echo "   sudo systemctl status pi5-control-center    # Statut"
echo "   sudo systemctl restart pi5-control-center   # Redémarrer"
echo "   sudo journalctl -u pi5-control-center -f    # Logs"
echo ""
echo "📂 Installation :"
echo "   ${INSTALL_DIR}"
echo ""
echo "🎬 Prochaines étapes :"
echo "   1. Ouvrir l'URL dans votre navigateur"
echo "   2. Suivre le Setup Wizard"
echo "   3. Configurer vos services"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
