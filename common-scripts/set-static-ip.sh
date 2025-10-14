#!/bin/bash
# =============================================================================
# Set Static IP - Universal & Idempotent
# =============================================================================
# Purpose: Configure static IP on Raspberry Pi (NetworkManager or dhcpcd)
# Version: 1.0.0
# Author: PI5-SETUP Project
# Usage: sudo bash set-static-ip.sh [STATIC_IP] [GATEWAY] [DNS]
# Example: sudo bash set-static-ip.sh 192.168.1.100 192.168.1.254 8.8.8.8
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# Logging
# =============================================================================

log()   { echo -e "${BLUE}[STATIC-IP]${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*"; }
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }

# =============================================================================
# Root Check
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être lancé en root"
    echo "Usage: sudo $0 [STATIC_IP] [GATEWAY] [DNS]"
    echo "Example: sudo $0 192.168.1.100 192.168.1.254 8.8.8.8"
    exit 1
fi

# =============================================================================
# Auto-Detection
# =============================================================================

detect_current_config() {
    log "🔍 Détection configuration réseau actuelle..."
    echo ""

    # Interface active (eth0 ou wlan0)
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$INTERFACE" ]]; then
        error "Interface réseau non détectée"
        exit 1
    fi
    info "Interface: $INTERFACE"

    # IP actuelle
    CURRENT_IP=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    info "IP actuelle: $CURRENT_IP"

    # Gateway actuelle
    CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -1)
    info "Gateway actuelle: $CURRENT_GATEWAY"

    # DNS actuel
    CURRENT_DNS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | head -1)
    info "DNS actuel: $CURRENT_DNS"

    # Méthode de gestion réseau
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        NETWORK_MANAGER="NetworkManager"
        info "Gestionnaire: NetworkManager"
    elif [[ -f /etc/dhcpcd.conf ]]; then
        NETWORK_MANAGER="dhcpcd"
        info "Gestionnaire: dhcpcd"
    else
        NETWORK_MANAGER="systemd-networkd"
        info "Gestionnaire: systemd-networkd"
    fi

    echo ""
}

# =============================================================================
# Validate Input
# =============================================================================

validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

get_user_input() {
    log "📝 Configuration IP statique"
    echo ""

    # Si paramètres fournis, les utiliser
    if [[ $# -ge 3 ]]; then
        STATIC_IP="$1"
        GATEWAY="$2"
        DNS="$3"
    else
        # Sinon, demander interactivement
        read -p "IP statique souhaitée [$CURRENT_IP]: " STATIC_IP
        STATIC_IP=${STATIC_IP:-$CURRENT_IP}

        read -p "Gateway [$CURRENT_GATEWAY]: " GATEWAY
        GATEWAY=${GATEWAY:-$CURRENT_GATEWAY}

        read -p "DNS [$CURRENT_DNS]: " DNS
        DNS=${DNS:-$CURRENT_DNS}
    fi

    # Validation
    if ! validate_ip "$STATIC_IP"; then
        error "IP invalide: $STATIC_IP"
        exit 1
    fi

    if ! validate_ip "$GATEWAY"; then
        error "Gateway invalide: $GATEWAY"
        exit 1
    fi

    if ! validate_ip "$DNS"; then
        error "DNS invalide: $DNS"
        exit 1
    fi

    echo ""
    info "Configuration à appliquer:"
    echo "  Interface: $INTERFACE"
    echo "  IP statique: $STATIC_IP/24"
    echo "  Gateway: $GATEWAY"
    echo "  DNS: $DNS"
    echo ""

    read -p "Continuer? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "Annulé par l'utilisateur"
        exit 0
    fi
}

# =============================================================================
# Configure NetworkManager
# =============================================================================

configure_networkmanager() {
    log "⚙️  Configuration NetworkManager..."

    # Obtenir nom de la connexion
    local connection_name=$(nmcli -t -f NAME,DEVICE connection show --active | grep "$INTERFACE" | cut -d: -f1)

    if [[ -z "$connection_name" ]]; then
        error "Connexion NetworkManager non trouvée pour $INTERFACE"
        exit 1
    fi

    info "Connexion: $connection_name"

    # Backup configuration actuelle
    local backup_dir="/root/network-backup"
    mkdir -p "$backup_dir"
    nmcli connection show "$connection_name" > "$backup_dir/nmcli-$(date +%Y%m%d_%H%M%S).txt" 2>/dev/null || true

    # Configurer IP statique
    log "Application configuration..."

    nmcli connection modify "$connection_name" \
        ipv4.method manual \
        ipv4.addresses "$STATIC_IP/24" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS" || {
            error "Échec configuration NetworkManager"
            exit 1
        }

    # Redémarrer connexion
    log "Redémarrage connexion..."
    nmcli connection down "$connection_name" >/dev/null 2>&1 || true
    sleep 2
    nmcli connection up "$connection_name" >/dev/null 2>&1 || {
        error "Échec redémarrage connexion"
        warn "Tentative de restauration..."
        nmcli connection modify "$connection_name" ipv4.method auto
        nmcli connection up "$connection_name"
        exit 1
    }

    ok "NetworkManager configuré"
}

# =============================================================================
# Configure dhcpcd
# =============================================================================

configure_dhcpcd() {
    log "⚙️  Configuration dhcpcd..."

    # Backup
    cp /etc/dhcpcd.conf "/etc/dhcpcd.conf.bak.$(date +%Y%m%d_%H%M%S)"

    # Supprimer ancienne config pour cette interface (idempotent)
    sed -i "/^interface $INTERFACE$/,/^$/d" /etc/dhcpcd.conf

    # Ajouter nouvelle config
    cat >> /etc/dhcpcd.conf <<EOF

# Static IP configuration (added by set-static-ip.sh)
interface $INTERFACE
static ip_address=$STATIC_IP/24
static routers=$GATEWAY
static domain_name_servers=$DNS
EOF

    # Redémarrer dhcpcd
    systemctl restart dhcpcd || {
        error "Échec redémarrage dhcpcd"
        exit 1
    }

    ok "dhcpcd configuré"
}

# =============================================================================
# Configure systemd-networkd
# =============================================================================

configure_systemd_networkd() {
    log "⚙️  Configuration systemd-networkd..."

    # Backup
    local config_dir="/etc/systemd/network"
    mkdir -p "$config_dir"

    local config_file="$config_dir/10-$INTERFACE.network"

    if [[ -f "$config_file" ]]; then
        cp "$config_file" "$config_file.bak.$(date +%Y%m%d_%H%M%S)"
    fi

    # Créer configuration
    cat > "$config_file" <<EOF
[Match]
Name=$INTERFACE

[Network]
Address=$STATIC_IP/24
Gateway=$GATEWAY
DNS=$DNS
EOF

    # Redémarrer service
    systemctl restart systemd-networkd || {
        error "Échec redémarrage systemd-networkd"
        exit 1
    }

    ok "systemd-networkd configuré"
}

# =============================================================================
# Verify Configuration
# =============================================================================

verify_config() {
    log "🔍 Vérification configuration..."
    sleep 3

    # Vérifier IP
    local new_ip=$(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")

    if [[ "$new_ip" == "$STATIC_IP" ]]; then
        ok "IP configurée: $new_ip"
    else
        warn "IP actuelle: $new_ip (attendue: $STATIC_IP)"
        warn "La configuration peut prendre quelques secondes..."
    fi

    # Vérifier gateway
    local new_gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ "$new_gateway" == "$GATEWAY" ]]; then
        ok "Gateway configurée: $new_gateway"
    else
        warn "Gateway actuelle: $new_gateway (attendue: $GATEWAY)"
    fi

    # Test connectivité
    log "Test connectivité Internet..."
    if ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        ok "Connectivité Internet OK"
    else
        warn "Pas de connectivité Internet"
    fi

    echo ""
}

# =============================================================================
# Show Summary
# =============================================================================

show_summary() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 IP STATIQUE CONFIGURÉE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Configuration:"
    echo "  Interface: $INTERFACE"
    echo "  IP statique: $STATIC_IP"
    echo "  Gateway: $GATEWAY"
    echo "  DNS: $DNS"
    echo "  Méthode: $NETWORK_MANAGER"
    echo ""
    echo "🔗 Nouvelles commandes SSH:"
    echo "  ssh pi@$STATIC_IP"
    echo "  ssh pi@pi5.local  (via mDNS, toujours fonctionnel)"
    echo ""
    echo "📋 Commandes utiles:"
    echo "  - Vérifier IP: ip addr show $INTERFACE"
    echo "  - Vérifier routes: ip route"
    echo "  - Tester DNS: nslookup google.com"
    echo ""
    echo "⚠️  IMPORTANT:"
    echo "  - Vérifie que cette IP ($STATIC_IP) n'est pas utilisée ailleurs"
    echo "  - Configure ta box pour NE PAS attribuer cette IP en DHCP"
    echo "  - Garde pi5.local comme backup (mDNS indépendant de l'IP)"
    echo ""

    if [[ "$NETWORK_MANAGER" == "NetworkManager" ]]; then
        echo "🔄 Pour revenir en DHCP:"
        echo "  sudo nmcli connection modify \"$connection_name\" ipv4.method auto"
        echo "  sudo nmcli connection up \"$connection_name\""
    elif [[ "$NETWORK_MANAGER" == "dhcpcd" ]]; then
        echo "🔄 Pour revenir en DHCP:"
        echo "  Supprimer la section 'interface $INTERFACE' dans /etc/dhcpcd.conf"
        echo "  sudo systemctl restart dhcpcd"
    fi

    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    log "🌐 Configuration IP Statique - Universal & Idempotent"
    echo ""

    # Détection
    detect_current_config

    # Input utilisateur
    get_user_input "$@"

    # Configuration selon gestionnaire réseau
    case "$NETWORK_MANAGER" in
        NetworkManager)
            configure_networkmanager
            ;;
        dhcpcd)
            configure_dhcpcd
            ;;
        systemd-networkd)
            configure_systemd_networkd
            ;;
        *)
            error "Gestionnaire réseau non supporté: $NETWORK_MANAGER"
            exit 1
            ;;
    esac

    # Vérification
    verify_config

    # Résumé
    show_summary
}

# =============================================================================
# Execute
# =============================================================================

main "$@"
