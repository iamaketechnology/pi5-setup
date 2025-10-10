#!/bin/bash
set -euo pipefail

#############################################################################
# Option 3: Tailscale VPN (Solution hybride optimale)
#
# Description: VPN privé avec chiffrement bout-en-bout
# Avantages: Sécurité max, vie privée, performance, pas de config routeur
# Prérequis: Compte Tailscale (gratuit jusqu'à 100 appareils)
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log() { echo -e "${CYAN}ℹ️  $*${NC}"; }
ok() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }

error_exit() {
    error "$1"
    exit 1
}

banner() {
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                ║${NC}"
    echo -e "${MAGENTA}║     ${CYAN}🔐 Option 3: Tailscale VPN Setup${MAGENTA}                      ║${NC}"
    echo -e "${MAGENTA}║                                                                ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#############################################################################
# Variables
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
TAILSCALE_VERSION="latest"
PI_HOSTNAME=$(hostname)
TAILSCALE_IP=""

#############################################################################
# Prérequis
#############################################################################

check_prerequisites() {
    log "Vérification des prérequis..."

    # Vérifier si on est sur le Pi
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        warn "Ce script doit être exécuté sur le Raspberry Pi"
    fi

    ok "Prérequis vérifiés"
}

#############################################################################
# Installation Tailscale
#############################################################################

install_tailscale() {
    log "Installation de Tailscale..."

    # Vérifier si déjà installé
    if command -v tailscale &> /dev/null; then
        local version=$(tailscale version | head -1)
        ok "Tailscale déjà installé: ${version}"
        return 0
    fi

    # Installation via script officiel
    log "Téléchargement du script d'installation officiel..."

    if ! curl -fsSL https://tailscale.com/install.sh | sh; then
        error_exit "Échec de l'installation de Tailscale"
    fi

    ok "Tailscale installé avec succès"

    # Vérifier version
    local version=$(tailscale version | head -1 || echo "unknown")
    log "Version installée: ${version}"
}

#############################################################################
# Authentification Tailscale
#############################################################################

authenticate_tailscale() {
    echo ""
    log "🔐 Authentification Tailscale..."
    echo ""

    cat << 'EOF'
📋 Authentification requise :

1. Une URL va s'afficher dans le terminal
2. Ouvrez cette URL dans votre navigateur
3. Connectez-vous avec votre compte Tailscale (ou créez-en un)
   • Options: Google, Microsoft, GitHub, Email
4. Autorisez l'appareil
5. Le Pi rejoindra automatiquement votre réseau Tailscale

💡 Création de compte Tailscale (si nécessaire) :
   • Gratuit jusqu'à 100 appareils
   • Pas de carte bancaire requise
   • URL: https://login.tailscale.com/start

Appuyez sur Entrée pour continuer...
EOF

    read

    # Démarrer Tailscale en mode authentification
    log "Démarrage de l'authentification..."

    if ! sudo tailscale up --hostname="${PI_HOSTNAME}" --accept-routes --accept-dns=false; then
        error_exit "Échec de l'authentification Tailscale"
    fi

    ok "Authentification réussie !"

    # Attendre que l'IP soit assignée
    log "Attente de l'attribution d'une IP Tailscale..."
    sleep 5

    # Récupérer l'IP Tailscale
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")

    if [[ -z "$TAILSCALE_IP" ]]; then
        error_exit "Impossible de récupérer l'IP Tailscale"
    fi

    ok "IP Tailscale attribuée: ${TAILSCALE_IP}"
}

#############################################################################
# Configuration Tailscale avancée
#############################################################################

configure_tailscale() {
    echo ""
    log "⚙️  Configuration avancée Tailscale..."
    echo ""

    # Proposer MagicDNS
    cat << 'EOF'
🪄 MagicDNS (DNS automatique)

MagicDNS vous permet d'accéder au Pi par son nom au lieu de son IP.

Exemple:
  • Sans MagicDNS : http://100.x.x.x:3000
  • Avec MagicDNS  : http://pi5:3000 ou http://pi5.tail-scale.ts.net

Voulez-vous activer MagicDNS ?
EOF

    read -p "Activer MagicDNS ? [Y/n]: " enable_magic_dns
    enable_magic_dns=${enable_magic_dns:-Y}

    if [[ "$enable_magic_dns" =~ ^[Yy]$ ]]; then
        log "Activation de MagicDNS..."

        if sudo tailscale set --accept-dns=true; then
            ok "MagicDNS activé"
        else
            warn "MagicDNS nécessite une configuration dans le dashboard Tailscale"
            warn "Visitez: https://login.tailscale.com/admin/dns"
        fi
    fi

    # Proposer subnet routing (partage réseau local)
    echo ""
    cat << 'EOF'
🌐 Subnet Router (partage réseau local)

Permet d'accéder à TOUS les appareils de votre réseau local (192.168.1.x)
depuis n'importe où via Tailscale.

Exemple:
  • Accès à 192.168.1.1 (routeur) depuis l'extérieur
  • Accès à d'autres Pis ou serveurs locaux

⚠️  Nécessite approbation dans le dashboard Tailscale après activation.

Voulez-vous partager votre réseau local via Tailscale ?
EOF

    read -p "Activer Subnet Router ? [y/N]: " enable_subnet
    enable_subnet=${enable_subnet:-N}

    if [[ "$enable_subnet" =~ ^[Yy]$ ]]; then
        log "Activation du Subnet Router..."

        # Activer IP forwarding
        sudo sysctl -w net.ipv4.ip_forward=1
        sudo sysctl -w net.ipv6.conf.all.forwarding=1

        # Rendre permanent
        echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
        echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf

        # Redémarrer Tailscale avec advertising routes
        local_subnet=$(ip route | grep -oP '192\.168\.\d+\.0/\d+' | head -1 || echo "192.168.1.0/24")

        sudo tailscale up --advertise-routes="${local_subnet}" --accept-routes

        ok "Subnet Router activé pour ${local_subnet}"
        warn "⚠️  IMPORTANT: Allez approuver les routes dans le dashboard:"
        warn "   https://login.tailscale.com/admin/machines"
        warn "   → Cliquez sur votre Pi → Edit route settings → Approve subnet"
    fi

    # Activer au démarrage
    log "Activation de Tailscale au démarrage..."
    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled

    ok "Tailscale configuré pour démarrer automatiquement"
}

#############################################################################
# Configuration Nginx local (optionnel)
#############################################################################

setup_nginx_reverse_proxy() {
    echo ""
    log "🔧 Configuration Nginx (reverse proxy local optionnel)..."
    echo ""

    cat << 'EOF'
📦 Nginx Reverse Proxy local

Configure Nginx pour exposer Supabase sur des ports standards via Tailscale:
  • Studio : http://TAILSCALE_IP/ (port 80)
  • API    : http://TAILSCALE_IP/api (port 80)

Au lieu de :
  • Studio : http://TAILSCALE_IP:3000
  • API    : http://TAILSCALE_IP:8000

Voulez-vous installer Nginx ?
EOF

    read -p "Installer Nginx ? [y/N]: " install_nginx
    install_nginx=${install_nginx:-N}

    if [[ "$install_nginx" =~ ^[Yy]$ ]]; then
        log "Installation de Nginx..."
        sudo apt-get update -qq
        sudo apt-get install -y nginx

        # Créer configuration
        cat << EOF | sudo tee /etc/nginx/sites-available/supabase-tailscale > /dev/null
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${PI_HOSTNAME} ${TAILSCALE_IP};

    # Studio (root)
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    # API (Kong)
    location /api {
        rewrite ^/api/(.*) /\$1 break;
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

        # Activer la configuration
        sudo ln -sf /etc/nginx/sites-available/supabase-tailscale /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default

        # Tester et recharger
        if sudo nginx -t; then
            sudo systemctl restart nginx
            ok "Nginx configuré et démarré"
        else
            error "Erreur de configuration Nginx"
        fi
    fi
}

#############################################################################
# Tests et validation
#############################################################################

run_tests() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🧪 Tests de connectivité${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Status Tailscale
    log "Status Tailscale:"
    sudo tailscale status | head -10

    echo ""

    # Test ping
    log "Test de connectivité..."
    if ping -c 1 -W 2 "${TAILSCALE_IP}" > /dev/null 2>&1; then
        ok "✅ Pi accessible via Tailscale (${TAILSCALE_IP})"
    else
        warn "⚠️  Test ping échoué (peut être normal si ICMP désactivé)"
    fi

    # Test HTTP Studio
    log "Test accès Studio..."
    if curl -sf -o /dev/null "http://${TAILSCALE_IP}:3000" --max-time 5; then
        ok "✅ Studio accessible via http://${TAILSCALE_IP}:3000"
    else
        warn "⚠️  Studio pas accessible (vérifiez que Supabase tourne)"
    fi

    # Test HTTP API
    log "Test accès API..."
    if curl -sf -o /dev/null "http://${TAILSCALE_IP}:8000" --max-time 5; then
        ok "✅ API accessible via http://${TAILSCALE_IP}:8000"
    else
        warn "⚠️  API pas accessible (vérifiez que Supabase tourne)"
    fi
}

#############################################################################
# Guide d'installation clients
#############################################################################

show_client_guide() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${CYAN}📱 Installation Tailscale sur vos appareils${BLUE}                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    cat << 'EOF'
Pour accéder à votre Pi depuis d'autres appareils :

┌─────────────────────────────────────────────────────────────────┐
│ 💻 Windows / macOS / Linux                                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Téléchargez Tailscale : https://tailscale.com/download      │
│ 2. Installez l'application                                      │
│ 3. Connectez-vous avec le même compte                           │
│ 4. Accédez au Pi via son IP Tailscale ou nom (si MagicDNS)     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 📱 iPhone / iPad (iOS)                                          │
├─────────────────────────────────────────────────────────────────┤
│ 1. App Store → "Tailscale"                                      │
│ 2. Installez et ouvrez l'app                                    │
│ 3. Connectez-vous                                                │
│ 4. Activez le VPN (toggle en haut)                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 🤖 Android                                                       │
├─────────────────────────────────────────────────────────────────┤
│ 1. Google Play Store → "Tailscale"                              │
│ 2. Installez et ouvrez l'app                                    │
│ 3. Connectez-vous                                                │
│ 4. Activez le VPN                                                │
└─────────────────────────────────────────────────────────────────┘

🌐 URLs d'accès (depuis n'importe quel appareil sur Tailscale) :

EOF

    if [[ -n "$TAILSCALE_IP" ]]; then
        echo -e "   ${CYAN}Studio${NC} : http://${TAILSCALE_IP}:3000"
        echo -e "   ${CYAN}API${NC}    : http://${TAILSCALE_IP}:8000"

        if systemctl is-active --quiet nginx 2>/dev/null; then
            echo ""
            echo "   ${CYAN}Avec Nginx (ports standards)${NC} :"
            echo -e "   ${CYAN}Studio${NC} : http://${TAILSCALE_IP}/"
            echo -e "   ${CYAN}API${NC}    : http://${TAILSCALE_IP}/api"
        fi
    fi

    echo ""
}

#############################################################################
# Génération rapport
#############################################################################

generate_report() {
    local report_file="${BASE_DIR}/docs/tailscale-setup-report.md"

    mkdir -p "${BASE_DIR}/docs"

    log "Génération du rapport..."

    local tailscale_name=$(tailscale status | grep "$(hostname)" | awk '{print $2}' || echo "${PI_HOSTNAME}")

    cat > "$report_file" << EOF
# 🔐 Rapport Tailscale VPN

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Option**: 3 - Tailscale VPN (Solution optimale)

---

## 📊 Configuration

| Paramètre | Valeur |
|-----------|--------|
| **Hostname** | \`${PI_HOSTNAME}\` |
| **Tailscale Name** | \`${tailscale_name}\` |
| **IP Tailscale** | \`${TAILSCALE_IP}\` |
| **Version** | \`$(tailscale version | head -1)\` |

---

## 🌐 URLs d'accès (via Tailscale)

### Direct (ports spécifiques)
- **Studio** : http://${TAILSCALE_IP}:3000
- **API** : http://${TAILSCALE_IP}:8000

### Avec Nginx (si installé)
- **Studio** : http://${TAILSCALE_IP}/
- **API** : http://${TAILSCALE_IP}/api

### Avec MagicDNS (si activé)
- **Studio** : http://${tailscale_name}:3000
- **API** : http://${tailscale_name}:8000

---

## ✅ Avantages Tailscale

- ✅ **Chiffrement bout-en-bout** (WireGuard)
- ✅ **Zéro configuration routeur** (fonctionne partout)
- ✅ **Pas de ports exposés** publiquement
- ✅ **Performance excellente** (connexion P2P quand possible)
- ✅ **IP privée stable** (${TAILSCALE_IP})
- ✅ **Gratuit** jusqu'à 100 appareils
- ✅ **Multiplateforme** (Windows, Mac, Linux, iOS, Android)

---

## 🛠️ Commandes utiles

### Status du réseau
\`\`\`bash
tailscale status
\`\`\`

### IP Tailscale
\`\`\`bash
tailscale ip -4
\`\`\`

### Redémarrer Tailscale
\`\`\`bash
sudo systemctl restart tailscaled
\`\`\`

### Se déconnecter
\`\`\`bash
sudo tailscale down
\`\`\`

### Se reconnecter
\`\`\`bash
sudo tailscale up
\`\`\`

### Logs
\`\`\`bash
sudo journalctl -u tailscaled -f
\`\`\`

---

## 📱 Installation clients

### Desktop (Windows / macOS / Linux)
Téléchargez depuis : https://tailscale.com/download

### Mobile (iOS / Android)
Installez l'app "Tailscale" depuis l'App Store ou Google Play Store

### Connexion
Utilisez le même compte Tailscale sur tous vos appareils.

---

## 🔧 Dashboard Tailscale

Gérez votre réseau Tailscale :
- **URL** : https://login.tailscale.com/admin/machines
- **Appareils** : Liste de tous les appareils connectés
- **ACLs** : Contrôle d'accès avancé
- **DNS** : Configuration MagicDNS
- **Subnet routes** : Approbation des routes partagées

---

## 🔐 Sécurité recommandée

### ACLs (Access Control Lists)
Définissez qui peut accéder à quoi dans le dashboard Tailscale.

Exemple ACL restrictive :
\`\`\`json
{
  "acls": [
    {
      "action": "accept",
      "users": ["autogroup:member"],
      "ports": [
        "${PI_HOSTNAME}:3000",  // Studio
        "${PI_HOSTNAME}:8000"   // API
      ]
    }
  ]
}
\`\`\`

### Authentification multi-facteur (MFA)
Activez la 2FA sur votre compte Tailscale :
https://login.tailscale.com/admin/settings/keys

---

## 🌍 Accès hybride (recommandé)

### Depuis le réseau local
Utilisez l'IP locale pour performance maximale :
- Studio : http://${LOCAL_IP}:3000
- API : http://${LOCAL_IP}:8000

### Depuis l'extérieur
Utilisez Tailscale pour accès sécurisé :
- Studio : http://${TAILSCALE_IP}:3000
- API : http://${TAILSCALE_IP}:8000

---

## 📚 Ressources

- **Documentation officielle** : https://tailscale.com/kb/
- **Status Tailscale** : https://status.tailscale.com/
- **Support** : https://tailscale.com/contact/support
- **Community** : https://forum.tailscale.com/

---

**Généré par**: pi5-setup External Access Option 3
EOF

    ok "Rapport généré: ${report_file}"
}

#############################################################################
# Main
#############################################################################

main() {
    banner

    check_prerequisites
    install_tailscale
    authenticate_tailscale
    configure_tailscale
    setup_nginx_reverse_proxy
    run_tests
    show_client_guide
    generate_report

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║     ✅ Tailscale VPN configuré avec succès !                   ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🔐 Votre Pi est accessible via Tailscale !${NC}"
    echo ""
    echo -e "${CYAN}📱 Installez Tailscale sur vos autres appareils :${NC}"
    echo -e "   https://tailscale.com/download"
    echo ""
    echo -e "${CYAN}🌐 Accès via Tailscale :${NC}"
    echo -e "   http://${TAILSCALE_IP}:3000  (Studio)"
    echo -e "   http://${TAILSCALE_IP}:8000  (API)"
    echo ""
    echo -e "${CYAN}📊 Dashboard Tailscale :${NC}"
    echo -e "   https://login.tailscale.com/admin/machines"
    echo ""
    echo -e "${CYAN}📖 Rapport complet :${NC}"
    echo -e "   ${BASE_DIR}/docs/tailscale-setup-report.md"
    echo ""
}

main "$@"
