#!/bin/bash
set -euo pipefail

#############################################################################
# Configuration Hybride : Port Forwarding + Tailscale VPN
#
# Description: Combine le meilleur des 2 mondes
# - Port Forwarding : Accès local rapide + HTTPS public
# - Tailscale VPN : Accès sécurisé depuis vos appareils personnels
#
# Avantages:
# ✅ Flexibilité maximale (3 méthodes d'accès)
# ✅ Performance optimale selon le contexte
# ✅ Sécurité adaptative
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
    clear
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║                                                                ║${NC}"
    echo -e "${MAGENTA}║     ${CYAN}🌐 Configuration Hybride - Accès Externe${MAGENTA}               ║${NC}"
    echo -e "${MAGENTA}║     ${YELLOW}Port Forwarding + Tailscale VPN${MAGENTA}                     ║${NC}"
    echo -e "${MAGENTA}║                                                                ║${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#############################################################################
# Variables globales
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
EXTERNAL_ACCESS_DIR="$(dirname "$BASE_DIR")"

OPTION1_SCRIPT="${EXTERNAL_ACCESS_DIR}/option1-port-forwarding/scripts/01-setup-port-forwarding.sh"
OPTION3_SCRIPT="${EXTERNAL_ACCESS_DIR}/option3-tailscale-vpn/scripts/01-setup-tailscale.sh"

LOCAL_IP=""
PUBLIC_IP=""
TAILSCALE_IP=""
DUCKDNS_DOMAIN=""

#############################################################################
# Prérequis
#############################################################################

check_prerequisites() {
    log "Vérification des prérequis..."

    # Vérifier si on est sur le Pi
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        warn "Ce script devrait être exécuté sur le Raspberry Pi"
        read -p "Continuer quand même ? [y/N]: " continue_anyway
        [[ "$continue_anyway" =~ ^[Yy]$ ]] || error_exit "Installation annulée"
    fi

    # Vérifier Supabase
    if ! docker ps --filter "name=supabase" --format "{{.Names}}" | grep -q "supabase"; then
        error_exit "Supabase ne semble pas être installé. Installez-le d'abord."
    fi

    ok "Prérequis vérifiés"
}

#############################################################################
# Présentation de la configuration hybride
#############################################################################

show_hybrid_presentation() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🎯 Configuration Hybride - Qu'est-ce que c'est ?${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cat << 'EOF'
La configuration hybride combine 2 méthodes d'accès complémentaires :

┌─────────────────────────────────────────────────────────────────┐
│ 🏠 Méthode 1 : Port Forwarding + Traefik                       │
├─────────────────────────────────────────────────────────────────┤
│ • Accès LOCAL ultra-rapide (0ms latence)                        │
│ • Accès PUBLIC via HTTPS (votre-domaine.duckdns.org)           │
│ • Performance maximale                                           │
│ • Nécessite ouverture ports 80/443 sur routeur                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 🔐 Méthode 2 : Tailscale VPN                                   │
├─────────────────────────────────────────────────────────────────┤
│ • Accès SÉCURISÉ depuis vos appareils personnels                │
│ • Chiffrement bout-en-bout (WireGuard)                          │
│ • Zéro configuration routeur                                    │
│ • Fonctionne partout dans le monde                              │
└─────────────────────────────────────────────────────────────────┘

📊 Cas d'usage selon votre situation :

  Depuis                    | Méthode recommandée     | Pourquoi
  ══════════════════════════╪═════════════════════════╪══════════════════════
  🏠 Réseau local (maison)  | Direct IP               | 0ms latence
  📱 Téléphone personnel    | Tailscale VPN           | Sécurisé + Facile
  💻 PC portable en voyage  | Tailscale VPN           | Fonctionne partout
  🌐 Partage avec un ami    | HTTPS public            | Pas d'installation
  🔐 Données sensibles      | Tailscale VPN           | Bout-en-bout chiffré

✨ Résultat : Vous aurez 3 URLs d'accès différentes !

  1. http://[IP-LOCALE]:3000              (local, ultra-rapide)
  2. https://[DOMAINE].duckdns.org        (public, HTTPS)
  3. http://100.x.x.x:3000                (VPN, sécurisé)

EOF

    echo ""
    read -p "Prêt à installer la configuration hybride ? [Y/n]: " ready
    ready=${ready:-Y}

    if [[ ! "$ready" =~ ^[Yy]$ ]]; then
        error_exit "Installation annulée par l'utilisateur"
    fi
}

#############################################################################
# Menu de sélection
#############################################################################

show_installation_menu() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📋 Quelle configuration souhaitez-vous ?${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cat << 'EOF'
  1) Installation complète (RECOMMANDÉ)
     → Port Forwarding + Tailscale
     → 3 méthodes d'accès

  2) Port Forwarding seulement
     → Accès local + public HTTPS
     → Nécessite configuration routeur

  3) Tailscale seulement
     → Accès VPN sécurisé uniquement
     → Zéro configuration routeur

  4) Annuler

EOF

    read -p "Votre choix [1-4]: " choice

    case $choice in
        1)
            INSTALL_PORTFORWARD=true
            INSTALL_TAILSCALE=true
            ok "Installation complète hybride sélectionnée"
            ;;
        2)
            INSTALL_PORTFORWARD=true
            INSTALL_TAILSCALE=false
            ok "Port Forwarding uniquement"
            ;;
        3)
            INSTALL_PORTFORWARD=false
            INSTALL_TAILSCALE=true
            ok "Tailscale uniquement"
            ;;
        4)
            log "Installation annulée"
            exit 0
            ;;
        *)
            error "Choix invalide"
            show_installation_menu
            ;;
    esac
}

#############################################################################
# Installation Port Forwarding
#############################################################################

install_port_forwarding() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${CYAN}Étape 1/3 : Configuration Port Forwarding${BLUE}                 ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log "Lancement du script Port Forwarding..."
    echo ""

    if [[ ! -f "$OPTION1_SCRIPT" ]]; then
        error_exit "Script Port Forwarding non trouvé: $OPTION1_SCRIPT"
    fi

    # Exécuter le script Option 1 (config routeur + tests)
    if bash "$OPTION1_SCRIPT"; then
        ok "✅ Port Forwarding configuré avec succès"

        # Extraire les infos pour le rapport
        if [[ -f "/tmp/port-forwarding-ips.txt" ]]; then
            source /tmp/port-forwarding-ips.txt
        fi
    else
        error "Échec de la configuration Port Forwarding"
        read -p "Continuer quand même ? [y/N]: " continue_install
        [[ "$continue_install" =~ ^[Yy]$ ]] || error_exit "Installation interrompue"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

install_traefik_integration() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${CYAN}Étape 2/3 : Déploiement Traefik + HTTPS${BLUE}                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    local TRAEFIK_DEPLOY_SCRIPT="${EXTERNAL_ACCESS_DIR}/../traefik/scripts/01-traefik-deploy-duckdns.sh"
    local TRAEFIK_INTEGRATE_SCRIPT="${EXTERNAL_ACCESS_DIR}/../traefik/scripts/02-integrate-supabase.sh"

    # Vérifier si Traefik est déjà déployé
    if docker ps --filter "name=traefik" --format "{{.Names}}" | grep -q "traefik"; then
        ok "Traefik déjà déployé, intégration avec Supabase..."
    else
        log "Déploiement de Traefik avec DuckDNS..."

        if [[ ! -f "$TRAEFIK_DEPLOY_SCRIPT" ]]; then
            error_exit "Script Traefik non trouvé: $TRAEFIK_DEPLOY_SCRIPT"
        fi

        # Déployer Traefik
        if bash "$TRAEFIK_DEPLOY_SCRIPT"; then
            ok "✅ Traefik déployé avec succès"
        else
            error "Échec du déploiement Traefik"
            return 1
        fi
    fi

    # Intégrer Supabase avec Traefik
    log "Intégration Supabase avec Traefik..."

    if [[ ! -f "$TRAEFIK_INTEGRATE_SCRIPT" ]]; then
        error_exit "Script d'intégration non trouvé: $TRAEFIK_INTEGRATE_SCRIPT"
    fi

    if bash "$TRAEFIK_INTEGRATE_SCRIPT"; then
        ok "✅ Supabase intégré avec Traefik"
    else
        error "Échec de l'intégration Supabase-Traefik"
        return 1
    fi

    # Attendre génération certificat Let's Encrypt
    log "Attente génération certificat SSL (Let's Encrypt)..."
    sleep 30

    # Vérifier certificat
    if sudo test -f /home/pi/stacks/traefik/acme/acme.json; then
        local cert_size=$(sudo stat -f%z /home/pi/stacks/traefik/acme/acme.json 2>/dev/null || sudo stat -c%s /home/pi/stacks/traefik/acme/acme.json 2>/dev/null)
        if [[ "$cert_size" -gt 1000 ]]; then
            ok "✅ Certificat SSL généré"
        else
            warn "Certificat SSL en cours de génération (peut prendre 1-2 minutes)"
        fi
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

#############################################################################
# Installation Tailscale
#############################################################################

install_tailscale() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${CYAN}Étape 3/3 : Installation Tailscale VPN${BLUE}                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log "Lancement du script Tailscale..."
    echo ""

    if [[ ! -f "$OPTION3_SCRIPT" ]]; then
        error_exit "Script Tailscale non trouvé: $OPTION3_SCRIPT"
    fi

    # Exécuter le script Option 3
    if bash "$OPTION3_SCRIPT"; then
        ok "✅ Tailscale installé avec succès"

        # Récupérer l'IP Tailscale
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    else
        error "Échec de l'installation Tailscale"
    fi

    echo ""
    read -p "Appuyez sur Entrée pour continuer..."
}

#############################################################################
# Détection des IPs et configuration
#############################################################################

detect_network_info() {
    log "Détection des informations réseau..."

    # IP locale
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    # IP publique
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "")

    # Domaine DuckDNS (si configuré)
    if [[ -f /home/pi/stacks/traefik/.env ]]; then
        DUCKDNS_DOMAIN=$(grep DUCKDNS_DOMAIN /home/pi/stacks/traefik/.env | cut -d= -f2 || echo "")
    fi

    # IP Tailscale (si installé)
    if command -v tailscale &> /dev/null; then
        TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "")
    fi

    ok "Informations réseau détectées"
}

#############################################################################
# Génération du guide utilisateur personnalisé
#############################################################################

generate_user_guide() {
    local guide_file="${BASE_DIR}/docs/HYBRID-ACCESS-GUIDE.md"

    mkdir -p "${BASE_DIR}/docs"

    log "Génération du guide utilisateur personnalisé..."

    cat > "$guide_file" << EOF
# 🌐 Guide d'Accès - Configuration Hybride

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Configuration**: Hybride (Port Forwarding + Tailscale)

---

## 📊 Vos URLs d'accès

Vous disposez maintenant de **3 méthodes d'accès** à votre instance Supabase :

EOF

    # Méthode 1 : Local
    cat >> "$guide_file" << EOF
### 🏠 Méthode 1 : Accès local (réseau domestique)

**Quand utiliser** : Vous êtes à la maison sur le même réseau WiFi

**URLs** :
- **Studio** : http://${LOCAL_IP}:3000
- **API** : http://${LOCAL_IP}:8000

**Avantages** :
- ✅ Latence 0ms (ultra-rapide)
- ✅ Aucune limite de bande passante
- ✅ Pas de transit Internet

**Inconvénient** :
- ❌ Fonctionne uniquement chez vous

---

EOF

    # Méthode 2 : HTTPS Public (si installé)
    if [[ "$INSTALL_PORTFORWARD" == "true" ]] && [[ -n "$DUCKDNS_DOMAIN" ]]; then
        cat >> "$guide_file" << EOF
### 🌍 Méthode 2 : Accès public HTTPS

**Quand utiliser** : Partage avec quelqu'un qui n'a pas Tailscale

**URLs** :
- **Studio** : https://${DUCKDNS_DOMAIN}/studio
- **API** : https://${DUCKDNS_DOMAIN}/api

**Avantages** :
- ✅ Accessible depuis n'importe où
- ✅ HTTPS sécurisé (Let's Encrypt)
- ✅ Aucune installation requise côté client

**Inconvénients** :
- ⚠️ IP publique exposée
- ⚠️ Ports 80/443 ouverts sur routeur

**⚠️ Configuration routeur requise** :
Assurez-vous d'avoir ouvert les ports 80 et 443 vers \`${LOCAL_IP}\`

---

EOF
    fi

    # Méthode 3 : Tailscale (si installé)
    if [[ "$INSTALL_TAILSCALE" == "true" ]] && [[ -n "$TAILSCALE_IP" ]]; then
        cat >> "$guide_file" << EOF
### 🔐 Méthode 3 : VPN Tailscale (RECOMMANDÉ pour accès externe)

**Quand utiliser** : Accès sécurisé depuis vos appareils personnels

**URLs** :
- **Studio** : http://${TAILSCALE_IP}:3000
- **API** : http://${TAILSCALE_IP}:8000

**Avantages** :
- ✅ Chiffrement bout-en-bout (WireGuard)
- ✅ Aucun port ouvert sur routeur
- ✅ Fonctionne partout (même en 4G/5G)
- ✅ Performance excellente (P2P direct)

**Prérequis** :
Installez Tailscale sur vos autres appareils :
- **iOS/Android** : App Store / Google Play → "Tailscale"
- **Windows/Mac** : https://tailscale.com/download
- **Linux** : \`curl -fsSL https://tailscale.com/install.sh | sh\`

Connectez-vous avec le même compte Tailscale sur tous vos appareils.

---

EOF
    fi

    # Tableau récapitulatif
    cat >> "$guide_file" << 'EOF'
## 📊 Tableau comparatif

| Critère | Local | HTTPS Public | Tailscale VPN |
|---------|-------|--------------|---------------|
| **Latence** | 0ms ⚡ | 20-50ms | 5-20ms |
| **Sécurité** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Simplicité** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Fonctionne partout** | ❌ | ✅ | ✅ |
| **Installation client** | ❌ | ❌ | ✅ Requis |
| **Config routeur** | ❌ | ✅ Requis | ❌ |

---

## 🎯 Recommandations d'usage

### 📱 Depuis votre téléphone
→ **Tailscale VPN** (installez l'app Tailscale)

### 💻 Depuis votre PC à la maison
→ **Accès local** (http://[IP-LOCALE]:3000 - ultra-rapide)

### 🌍 En déplacement (hôtel, café, etc.)
→ **Tailscale VPN** (sécurisé, fonctionne partout)

### 👥 Partager avec un ami/collègue
→ **HTTPS public** (pas d'installation requise)

### 🔒 Données sensibles
→ **Tailscale VPN** (chiffrement bout-en-bout)

---

## 🔧 Commandes utiles

### Vérifier status Tailscale
\`\`\`bash
tailscale status
\`\`\`

### Redémarrer Traefik (HTTPS)
\`\`\`bash
cd /home/pi/stacks/traefik
docker compose restart
\`\`\`

### Vérifier certificats SSL
\`\`\`bash
docker logs traefik | grep -i certificate
\`\`\`

### Status tous les services Supabase
\`\`\`bash
docker ps --filter "name=supabase"
\`\`\`

---

## 🆘 Troubleshooting

### "Je ne peux pas accéder en local (IP locale)"
1. Vérifiez que vous êtes sur le même réseau WiFi
2. Testez : \`ping [IP-LOCALE]\`
3. Vérifiez que Supabase tourne : \`docker ps\`

### "Le HTTPS public ne fonctionne pas"
1. Vérifiez les ports ouverts sur votre routeur (80 + 443)
2. Testez depuis l'extérieur : \`curl -I https://VOTRE_DOMAINE.duckdns.org\`
3. Vérifiez les logs Traefik : \`docker logs traefik --tail 50\`

### "Tailscale ne se connecte pas"
1. Vérifiez le status : \`tailscale status\`
2. Reconnectez : \`sudo tailscale up\`
3. Vérifiez que l'app Tailscale est active sur votre appareil client

---

## 📱 Installation Tailscale sur vos autres appareils

### iPhone / iPad
1. App Store → Rechercher "Tailscale"
2. Installer et ouvrir
3. Se connecter avec le même compte
4. Activer le VPN (toggle en haut)
5. Ouvrir Safari → http://100.x.x.x:3000

### Android
1. Google Play Store → "Tailscale"
2. Installer et ouvrir
3. Se connecter
4. Activer le VPN
5. Ouvrir Chrome → http://100.x.x.x:3000

### Windows
1. https://tailscale.com/download/windows
2. Installer l'application
3. Se connecter
4. Navigateur → http://100.x.x.x:3000

### macOS
1. https://tailscale.com/download/mac
2. Installer l'application
3. Se connecter (icône dans la barre de menu)
4. Navigateur → http://100.x.x.x:3000

---

## 📚 Documentation complète

- **Port Forwarding** : [Guide Option 1](../../option1-port-forwarding/)
- **Tailscale VPN** : [Guide Option 3](../../option3-tailscale-vpn/)
- **Comparaison détaillée** : [COMPARISON.md](../../COMPARISON.md)

---

**Généré par** : PI5-SETUP Hybrid Setup Script
**Support** : https://github.com/VOTRE-REPO/pi5-setup/issues
EOF

    ok "Guide utilisateur généré: ${guide_file}"
}

#############################################################################
# Résumé final
#############################################################################

show_final_summary() {
    detect_network_info

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║     ✅ Configuration Hybride Installée avec Succès !           ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${CYAN}🌐 Vos 3 méthodes d'accès :${NC}"
    echo ""

    # Local
    echo -e "${YELLOW}1. Accès Local (ultra-rapide)${NC}"
    echo -e "   Studio : ${BLUE}http://${LOCAL_IP}:3000${NC}"
    echo -e "   API    : ${BLUE}http://${LOCAL_IP}:8000${NC}"
    echo ""

    # Public HTTPS
    if [[ "$INSTALL_PORTFORWARD" == "true" ]] && [[ -n "$DUCKDNS_DOMAIN" ]]; then
        echo -e "${YELLOW}2. Accès Public HTTPS${NC}"
        echo -e "   Studio : ${BLUE}https://${DUCKDNS_DOMAIN}/studio${NC}"
        echo -e "   API    : ${BLUE}https://${DUCKDNS_DOMAIN}/api${NC}"
        echo ""
        warn "   ⚠️  Vérifiez que les ports 80/443 sont ouverts sur votre routeur"
        echo ""
    fi

    # Tailscale
    if [[ "$INSTALL_TAILSCALE" == "true" ]] && [[ -n "$TAILSCALE_IP" ]]; then
        echo -e "${YELLOW}3. Accès VPN Tailscale (sécurisé)${NC}"
        echo -e "   Studio : ${BLUE}http://${TAILSCALE_IP}:3000${NC}"
        echo -e "   API    : ${BLUE}http://${TAILSCALE_IP}:8000${NC}"
        echo ""
        log "   📱 Installez Tailscale sur vos autres appareils :"
        log "      https://tailscale.com/download"
        echo ""
    fi

    echo -e "${CYAN}📖 Guide utilisateur complet :${NC}"
    echo -e "   ${BASE_DIR}/docs/HYBRID-ACCESS-GUIDE.md"
    echo ""

    echo -e "${CYAN}🔧 Dashboard :${NC}"
    if [[ "$INSTALL_PORTFORWARD" == "true" ]]; then
        echo -e "   Traefik : http://${LOCAL_IP}:8080 (si activé)"
    fi
    if [[ "$INSTALL_TAILSCALE" == "true" ]]; then
        echo -e "   Tailscale : https://login.tailscale.com/admin/machines"
    fi
    echo ""

    echo -e "${GREEN}🎉 Profitez de votre configuration hybride !${NC}"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    banner
    check_prerequisites
    show_hybrid_presentation
    show_installation_menu

    # Installation selon le choix
    if [[ "$INSTALL_PORTFORWARD" == "true" ]]; then
        install_port_forwarding
        install_traefik_integration
    fi

    if [[ "$INSTALL_TAILSCALE" == "true" ]]; then
        install_tailscale
    fi

    # Génération du guide
    generate_user_guide

    # Résumé final
    show_final_summary
}

# Exécution
main "$@"
