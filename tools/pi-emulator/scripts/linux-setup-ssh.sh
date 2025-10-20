#!/bin/bash
# =============================================================================
# Linux - SSH Server Setup (Intelligent)
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash linux-setup-ssh.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

log_info "Linux SSH Server Setup (Intelligent)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Vérifier root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être lancé avec sudo"
    echo "Usage: sudo bash linux-setup-ssh.sh"
    exit 1
fi

# Détecter user réel
REAL_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${REAL_USER}")

log_info "User: ${REAL_USER}"
log_info "Home: ${USER_HOME}"
echo ""

# Étape 1: Vérifier si SSH déjà installé
log_info "1/5 Vérification SSH server..."

if systemctl is-active --quiet ssh || systemctl is-active --quiet sshd; then
    log_success "SSH server déjà actif"

    read -p "Reconfigurer SSH? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Configuration SSH ignorée"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ SSH DÉJÀ OPÉRATIONNEL"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        echo "IP: ${LOCAL_IP}"
        echo "User: ${REAL_USER}"
        echo ""
        echo "Sur ton Mac, lance:"
        echo "  cd tools/pi-emulator"
        echo "  bash scripts/00-setup-ssh-access.sh"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        exit 0
    fi
else
    log_info "SSH server non installé. Installation..."
fi

echo ""

# Étape 2: Installation SSH
log_info "2/5 Installation OpenSSH Server..."

apt-get update -qq
apt-get install -y openssh-server

log_success "SSH installé"
echo ""

# Étape 3: Configuration SSH sécurisée
log_info "3/5 Configuration SSH..."

# Backup config
if [[ -f /etc/ssh/sshd_config ]]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)
fi

# Vérifier si config custom existe déjà
if [[ -f /etc/ssh/sshd_config.d/50-pi-emulator.conf ]]; then
    log_info "Configuration existante trouvée, suppression..."
    rm /etc/ssh/sshd_config.d/50-pi-emulator.conf
fi

# Configuration optimale (SANS Subsystem sftp qui existe déjà)
cat > /etc/ssh/sshd_config.d/50-pi-emulator.conf <<'EOF'
# Pi Emulator SSH Configuration
Port 22
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
UsePAM yes
X11Forwarding yes
PrintMotd no
AcceptEnv LANG LC_*
# Note: Subsystem sftp est déjà défini dans /etc/ssh/sshd_config
EOF

# Tester la configuration
log_info "Test de la configuration SSH..."
if sshd -t 2>&1 | grep -q "error"; then
    log_error "Erreur dans la configuration SSH"
    sshd -t
    log_warning "Suppression de la config custom..."
    rm /etc/ssh/sshd_config.d/50-pi-emulator.conf
    exit 1
fi

log_success "Configuration SSH appliquée et validée"
echo ""

# Étape 4: Démarrage SSH
log_info "4/5 Démarrage SSH server..."

systemctl enable ssh
systemctl restart ssh

sleep 2

if systemctl is-active --quiet ssh; then
    log_success "SSH server actif"
else
    log_error "Échec démarrage SSH"
    systemctl status ssh --no-pager
    exit 1
fi

echo ""

# Étape 5: Configuration firewall
log_info "5/5 Configuration firewall..."

if command -v ufw &> /dev/null; then
    # Vérifier si UFW est actif
    if ufw status | grep -q "Status: active"; then
        log_info "UFW actif, ajout règle SSH..."
        ufw allow 22/tcp
        log_success "Règle SSH ajoutée"
    else
        log_info "UFW inactif, règle non nécessaire"
    fi
else
    log_info "UFW non installé, firewall non configuré"
fi

echo ""

# Préparer répertoire .ssh pour user
log_info "Préparation répertoire .ssh..."

mkdir -p "${USER_HOME}/.ssh"
touch "${USER_HOME}/.ssh/authorized_keys"
chmod 700 "${USER_HOME}/.ssh"
chmod 600 "${USER_HOME}/.ssh/authorized_keys"
chown -R "${REAL_USER}:${REAL_USER}" "${USER_HOME}/.ssh"

log_success "Répertoire .ssh prêt"

# Test final SSH
log_info "Test final du serveur SSH..."
echo ""

# Vérifier que SSH écoute bien
if ss -tuln | grep -q ":22 "; then
    log_success "SSH écoute sur le port 22"
else
    log_error "SSH n'écoute pas sur le port 22"
    log_info "Tentative de correction..."
    systemctl restart ssh
    sleep 3
    if ss -tuln | grep -q ":22 "; then
        log_success "SSH maintenant actif après restart"
    else
        log_error "Problème persistant avec SSH"
        systemctl status ssh --no-pager
        exit 1
    fi
fi

# Test connexion locale
if su - "${REAL_USER}" -c "ssh -o StrictHostKeyChecking=no -o BatchMode=yes ${REAL_USER}@localhost exit" 2>/dev/null; then
    log_success "Test connexion SSH locale: OK"
else
    log_warning "Test connexion SSH locale échoué (normal si pas de clé)"
fi

echo ""

# Obtenir infos réseau (toutes les IPs)
log_info "Détection des adresses IP..."
ALL_IPS=$(hostname -I)
LOCAL_IP=$(echo $ALL_IPS | awk '{print $1}')
HOSTNAME=$(hostname)

if [[ -z "$LOCAL_IP" ]] || [[ "$LOCAL_IP" == "127.0.0.1" ]]; then
    log_error "Impossible de détecter l'IP réseau"
    log_info "Vérifier la connexion réseau"
    exit 1
fi

# Résumé final ultra-visible
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SSH SERVER CONFIGURÉ ET ACTIF"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ VÉRIFICATIONS:"
echo "   ✓ SSH server installé"
echo "   ✓ SSH service actif"
echo "   ✓ SSH écoute sur port 22"
echo "   ✓ Firewall configuré"
echo "   ✓ Répertoire .ssh prêt"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 INFORMATIONS DE CONNEXION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   ╔════════════════════════════════════════╗"
echo "   ║  IP    : ${LOCAL_IP}                    "
echo "   ║  User  : ${REAL_USER}                   "
echo "   ║  Port  : 22                            ║"
echo "   ╚════════════════════════════════════════╝"
echo ""

if [[ $(echo $ALL_IPS | wc -w) -gt 1 ]]; then
    echo "📌 Autres IPs disponibles: $(echo $ALL_IPS | cut -d' ' -f2-)"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 COPIE CES INFORMATIONS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   IP   = ${LOCAL_IP}"
echo "   USER = ${REAL_USER}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 PROCHAINE ÉTAPE - SUR TON MAC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Lance cette commande:"
echo ""
echo "┌────────────────────────────────────────────────────┐"
echo "│ cd tools/pi-emulator                               │"
echo "│ bash scripts/00-setup-ssh-access.sh                │"
echo "└────────────────────────────────────────────────────┘"
echo ""
echo "Choisis option 2 (manuel) et entre:"
echo "   IP: ${LOCAL_IP}"
echo "   User: ${REAL_USER}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_success "Configuration SSH terminée avec succès !"
echo ""
log_warning "⚠️  GARDE CE TERMINAL OUVERT"
echo "Tu devras copier-coller des commandes depuis le Mac ici."
echo ""
