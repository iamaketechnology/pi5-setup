#!/bin/bash
# =============================================================================
# Setup SSH Access Mac → Linux
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: bash 00-setup-ssh-access.sh
# =============================================================================

set -euo pipefail

# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

log_info "Configuration SSH Mac → Linux"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Fonction scan réseau
scan_network() {
    log_info "Scan du réseau local..."
    echo ""

    # Obtenir l'IP du Mac et le subnet
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")

    if [[ -z "$LOCAL_IP" ]]; then
        log_warning "Impossible de détecter l'IP locale"
        return 1
    fi

    # Extraire le subnet (ex: 192.168.1)
    SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3)

    log_info "Subnet détecté: ${SUBNET}.0/24"
    log_info "Scan des machines SSH (port 22)..."
    echo ""

    # Scanner le réseau (nmap si dispo, sinon nc)
    if command -v nmap &> /dev/null; then
        nmap -p 22 --open "${SUBNET}.0/24" 2>/dev/null | grep -B 4 "open" | grep "Nmap scan report" | awk '{print $5}'
    else
        # Fallback: scan rapide avec nc
        log_info "Installation de nmap recommandée: brew install nmap"
        log_info "Scan basique en cours (plus lent)..."
        for i in {1..254}; do
            (timeout 0.2 bash -c "echo >/dev/tcp/${SUBNET}.${i}/22" 2>/dev/null && echo "${SUBNET}.${i}") &
        done
        wait
    fi

    echo ""
}

# Proposer scan auto
echo "Options:"
echo "  1) Scanner le réseau automatiquement"
echo "  2) Entrer l'IP manuellement"
echo ""
read -p "Choix (1/2): " SCAN_CHOICE

LINUX_IP=""
LINUX_USER=""

if [[ "$SCAN_CHOICE" == "1" ]]; then
    echo ""
    FOUND_IPS=$(scan_network 2>/dev/null)

    if [[ -n "$FOUND_IPS" ]]; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Machines SSH trouvées:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$FOUND_IPS" | nl
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        read -p "Entrer l'IP choisie: " LINUX_IP
    else
        log_warning "Aucune machine SSH trouvée"
        read -p "IP de ton PC Linux (ex: 192.168.1.100): " LINUX_IP
    fi
else
    read -p "IP de ton PC Linux (ex: 192.168.1.100): " LINUX_IP
fi

read -p "Username sur Linux (ex: user): " LINUX_USER

echo ""
log_info "Configuration:"
echo "   IP: ${LINUX_IP}"
echo "   User: ${LINUX_USER}"
echo ""

# Étape 1: Vérifier clé SSH locale
log_info "1/5 Vérification clé SSH locale..."

if [[ -f ~/.ssh/id_rsa.pub ]]; then
    log_success "Clé SSH existante trouvée"
    SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
else
    log_warning "Aucune clé SSH trouvée. Création..."

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -C "mac-to-linux"

    if [[ -f ~/.ssh/id_rsa.pub ]]; then
        log_success "Clé SSH créée"
        SSH_KEY=$(cat ~/.ssh/id_rsa.pub)
    else
        log_error "Échec création clé SSH"
        exit 1
    fi
fi

echo ""
log_info "2/5 Test connexion SSH au Linux..."

# Tester connexion
if ssh -o ConnectTimeout=5 -o BatchMode=yes "${LINUX_USER}@${LINUX_IP}" exit 2>/dev/null; then
    log_success "Connexion SSH déjà configurée !"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ SSH DÉJÀ OPÉRATIONNEL"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Test: ssh ${LINUX_USER}@${LINUX_IP} 'uname -a'"
    ssh "${LINUX_USER}@${LINUX_IP}" 'uname -a'
    exit 0
fi

log_warning "Connexion SSH non configurée. Configuration requise..."

echo ""
log_info "3/5 Copie de la clé SSH sur le Linux..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 ACTIONS MANUELLES REQUISES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "SUR TON PC LINUX, exécute ces commandes:"
echo ""
echo "1️⃣  Installer SSH server (si pas déjà fait):"
echo "    sudo apt update && sudo apt install -y openssh-server"
echo "    sudo systemctl enable ssh"
echo "    sudo systemctl start ssh"
echo ""
echo "2️⃣  Créer répertoire .ssh:"
echo "    mkdir -p ~/.ssh"
echo "    chmod 700 ~/.ssh"
echo ""
echo "3️⃣  Ajouter ta clé publique (copie cette ligne):"
echo ""
echo "cat >> ~/.ssh/authorized_keys <<'EOF'"
echo "${SSH_KEY}"
echo "EOF"
echo ""
echo "4️⃣  Fixer permissions:"
echo "    chmod 600 ~/.ssh/authorized_keys"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

read -p "Appuie sur ENTER quand c'est fait sur le Linux..."

echo ""
log_info "4/5 Test de la connexion SSH..."

if ssh -o ConnectTimeout=10 "${LINUX_USER}@${LINUX_IP}" exit 2>/dev/null; then
    log_success "Connexion SSH opérationnelle !"
else
    log_error "Connexion SSH échouée"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Vérifier que SSH server tourne sur Linux: sudo systemctl status ssh"
    echo "  2. Vérifier IP: ping ${LINUX_IP}"
    echo "  3. Vérifier firewall: sudo ufw allow 22"
    echo "  4. Tester avec password: ssh ${LINUX_USER}@${LINUX_IP}"
    exit 1
fi

echo ""
log_info "5/5 Configuration alias SSH (optionnel)..."

# Ajouter alias dans ~/.ssh/config
if ! grep -q "Host linux-pi-emulator" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config <<EOF

# Linux PC for Pi Emulator
Host linux-pi-emulator
    HostName ${LINUX_IP}
    User ${LINUX_USER}
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
EOF

    chmod 600 ~/.ssh/config
    log_success "Alias SSH créé"
else
    log_info "Alias SSH déjà existant"
fi

# Résumé
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SSH CONFIGURÉ MAC → LINUX"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Connexions disponibles:"
echo "   ssh ${LINUX_USER}@${LINUX_IP}"
echo "   ssh linux-pi-emulator  (alias)"
echo ""
echo "📌 Test:"
echo "   ssh ${LINUX_USER}@${LINUX_IP} 'uname -a'"
echo ""

ssh "${LINUX_USER}@${LINUX_IP}" 'echo "✅ SSH fonctionne!" && uname -a'

echo ""
echo "📌 Prochaine étape - Lancer Pi Emulator:"
echo "   ssh ${LINUX_USER}@${LINUX_IP} 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh"
echo ""
echo "   OU avec alias:"
echo "   ssh linux-pi-emulator 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
