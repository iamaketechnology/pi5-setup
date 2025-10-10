#!/bin/bash
set -euo pipefail

#############################################################################
# Option 1: Port Forwarding + Traefik + DuckDNS
#
# Description: Configure l'accès externe via ouverture de ports sur routeur
# Avantages: Gratuit, rapide, contrôle total, vie privée maximale
# Prérequis: Accès administrateur à votre box/routeur
#############################################################################

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║     ${CYAN}🌐 Option 1: Port Forwarding Setup${BLUE}                     ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#############################################################################
# Variables globales
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOCAL_IP=""
PUBLIC_IP=""
DUCKDNS_DOMAIN=""
ROUTER_IP=""

#############################################################################
# Fonctions de détection
#############################################################################

detect_local_ip() {
    log "Détection de l'IP locale du Raspberry Pi..."

    # Essayer plusieurs méthodes
    LOCAL_IP=$(hostname -I | awk '{print $1}')

    if [[ -z "$LOCAL_IP" ]]; then
        LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7; exit}')
    fi

    if [[ -z "$LOCAL_IP" ]]; then
        error_exit "Impossible de détecter l'IP locale"
    fi

    ok "IP locale détectée: ${LOCAL_IP}"
}

detect_public_ip() {
    log "Détection de votre IP publique..."

    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || curl -s https://ifconfig.me 2>/dev/null || echo "")

    if [[ -z "$PUBLIC_IP" ]]; then
        error_exit "Impossible de détecter l'IP publique"
    fi

    ok "IP publique détectée: ${PUBLIC_IP}"
}

detect_router_ip() {
    log "Détection de l'IP du routeur..."

    ROUTER_IP=$(ip route | grep default | awk '{print $3}' | head -1)

    if [[ -z "$ROUTER_IP" ]]; then
        ROUTER_IP="192.168.1.1"
        warn "IP routeur non détectée, utilisation par défaut: ${ROUTER_IP}"
    else
        ok "IP routeur détectée: ${ROUTER_IP}"
    fi
}

detect_isp() {
    log "Tentative de détection de votre FAI..."

    local isp_info=$(curl -s "https://ipapi.co/${PUBLIC_IP}/json/" 2>/dev/null || echo "{}")
    local org=$(echo "$isp_info" | jq -r '.org // "Inconnu"' 2>/dev/null || echo "Inconnu")

    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📡 Informations réseau détectées${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}IP locale (Pi)    :${NC} ${LOCAL_IP}"
    echo -e "${YELLOW}IP publique       :${NC} ${PUBLIC_IP}"
    echo -e "${YELLOW}IP routeur        :${NC} ${ROUTER_IP}"
    echo -e "${YELLOW}Opérateur détecté :${NC} ${org}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

#############################################################################
# Guide de configuration routeur par FAI
#############################################################################

show_router_guide() {
    local isp_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')

    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  ${CYAN}📝 Guide de configuration du routeur${BLUE}                       ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    case "$isp_lower" in
        *orange*)
            show_orange_guide
            ;;
        *free*)
            show_freebox_guide
            ;;
        *sfr*)
            show_sfr_guide
            ;;
        *bouygues*)
            show_bouygues_guide
            ;;
        *)
            show_generic_guide
            ;;
    esac
}

show_orange_guide() {
    cat << 'EOF'
🟠 Orange Livebox - Configuration NAT/PAT

1. Accéder à l'interface web:
   URL: http://192.168.1.1
   Login: admin
   Mot de passe: (voir sous la box ou sur l'étiquette)

2. Navigation:
   ▸ Cliquez sur "Configuration avancée"
   ▸ Entrez le mot de passe admin
   ▸ Menu "NAT/PAT" → "Créer une règle"

3. Configuration Port 80 (HTTP):
   • Application/Service: Traefik-HTTP
   • Port interne: 80
   • Port externe: 80
   • Protocole: TCP
   • Équipement: Sélectionnez votre Pi dans la liste
   • IP interne: (auto-rempli)
   • Cliquez "Créer"

4. Configuration Port 443 (HTTPS):
   • Répétez l'étape 3 avec:
     - Application: Traefik-HTTPS
     - Ports: 443

5. Sauvegarder et redémarrer la box (si demandé)

📖 Documentation officielle:
   https://assistance.orange.fr/livebox-modem/livebox

EOF
}

show_freebox_guide() {
    cat << 'EOF'
🔷 Freebox - Configuration redirection de ports

1. Accéder à l'interface web:
   URL: http://mafreebox.freebox.fr
   Ou: http://192.168.1.254
   Login: (sans mot de passe par défaut)

2. Navigation:
   ▸ Onglet "Paramètres de la Freebox"
   ▸ Section "Gestion des ports"

3. Configuration Port 80 (HTTP):
   • IP destination: Votre IP Pi (ex: 192.168.1.100)
   • IP source: Toutes
   • Port de début: 80
   • Port de fin: 80
   • Port de destination: 80
   • Protocole: TCP
   • Commentaire: Traefik-HTTP
   • Cliquez "Ajouter"

4. Configuration Port 443 (HTTPS):
   • Répétez avec Port 443

5. Cliquez "Sauvegarder"

📖 Documentation officielle:
   https://www.free.fr/assistance/

EOF
}

show_sfr_guide() {
    cat << 'EOF'
🔴 SFR Box - Configuration NAT/PAT

1. Accéder à l'interface web:
   URL: http://192.168.1.1
   Login: admin
   Mot de passe: (voir sur l'étiquette de la box)

2. Navigation:
   ▸ Onglet "Réseau"
   ▸ Section "NAT/PAT"
   ▸ Cliquez "Configurer"

3. Configuration Port 80 (HTTP):
   • Nom: Traefik-HTTP
   • Protocole: TCP
   • Port externe: 80
   • Équipement: Sélectionnez votre Pi
   • Port interne: 80
   • Cliquez "Ajouter"

4. Configuration Port 443 (HTTPS):
   • Répétez avec Port 443

5. Appliquer les modifications

📖 Documentation officielle:
   https://assistance.sfr.fr/

EOF
}

show_bouygues_guide() {
    cat << 'EOF'
🔵 Bouygues Bbox - Configuration redirection de ports

1. Accéder à l'interface web:
   URL: http://192.168.1.254
   Ou: http://mabbox.bytel.fr
   Login: admin
   Mot de passe: (voir sur l'étiquette)

2. Navigation:
   ▸ Onglet "Services avancés"
   ▸ Section "Redirections de ports"

3. Configuration Port 80 (HTTP):
   • Nom: Traefik-HTTP
   • Protocole: TCP
   • Port externe: 80
   • IP locale: Votre IP Pi
   • Port interne: 80
   • Activer la règle: Oui
   • Cliquez "Ajouter"

4. Configuration Port 443 (HTTPS):
   • Répétez avec Port 443

5. Sauvegarder

📖 Documentation officielle:
   https://www.assistance.bouyguestelecom.fr/

EOF
}

show_generic_guide() {
    cat << 'EOF'
🌐 Configuration générique (routeur non détecté)

1. Accéder à l'interface de votre routeur:
   • Essayez ces URLs dans votre navigateur:
     - http://192.168.1.1
     - http://192.168.0.1
     - http://192.168.1.254
   • Login: admin / admin (souvent par défaut)
   • Mot de passe: voir étiquette sous le routeur

2. Chercher la section:
   • "Port Forwarding" ou "NAT/PAT"
   • "Redirection de ports"
   • "Virtual Server"
   • "Applications and Gaming"

3. Créer 2 règles:

   Règle 1 - HTTP:
   ┌─────────────────────────────────────┐
   │ Nom          : Traefik-HTTP         │
   │ Protocole    : TCP                  │
   │ Port externe : 80                   │
   │ IP interne   : ${LOCAL_IP}          │
   │ Port interne : 80                   │
   │ Activer      : Oui                  │
   └─────────────────────────────────────┘

   Règle 2 - HTTPS:
   ┌─────────────────────────────────────┐
   │ Nom          : Traefik-HTTPS        │
   │ Protocole    : TCP                  │
   │ Port externe : 443                  │
   │ IP interne   : ${LOCAL_IP}          │
   │ Port interne : 443                  │
   │ Activer      : Oui                  │
   └─────────────────────────────────────┘

4. Sauvegarder et redémarrer le routeur si nécessaire

💡 Conseil:
   Recherchez sur Google: "port forwarding [MARQUE ROUTEUR]"
   Exemple: "port forwarding TP-Link Archer"

EOF

    # Remplacer %LOCAL_IP% par l'IP réelle
    sed -i.bak "s/%LOCAL_IP%/${LOCAL_IP}/g" /dev/stdout 2>/dev/null || true
}

#############################################################################
# Tests de connectivité
#############################################################################

test_port_open() {
    local port=$1
    local protocol=$2

    log "Test du port ${port} (${protocol}) depuis l'extérieur..."

    # Attendre 3 secondes pour laisser le temps au routeur
    sleep 3

    # Test avec timeout
    if timeout 10 bash -c "curl -s -o /dev/null -w '%{http_code}' http://${PUBLIC_IP}:${port}" > /dev/null 2>&1; then
        ok "Port ${port} accessible depuis Internet ✅"
        return 0
    else
        warn "Port ${port} non accessible (normal avant config routeur)"
        return 1
    fi
}

run_connectivity_tests() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🔍 Tests de connectivité${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Test DNS DuckDNS
    if [[ -n "$DUCKDNS_DOMAIN" ]]; then
        log "Test résolution DNS ${DUCKDNS_DOMAIN}..."
        local resolved_ip=$(getent hosts "${DUCKDNS_DOMAIN}" | awk '{print $1}' || echo "")

        if [[ "$resolved_ip" == "$PUBLIC_IP" ]]; then
            ok "DNS résout correctement vers ${PUBLIC_IP} ✅"
        else
            warn "DNS résout vers ${resolved_ip} au lieu de ${PUBLIC_IP}"
            warn "Attendez 1-2 minutes que DuckDNS se mette à jour"
        fi
    fi

    # Test port 80
    test_port_open 80 "HTTP"
    local http_status=$?

    # Test port 443
    test_port_open 443 "HTTPS"
    local https_status=$?

    echo ""

    if [[ $http_status -eq 0 ]] && [[ $https_status -eq 0 ]]; then
        ok "✅ Configuration réussie ! Tous les ports sont accessibles"
        return 0
    else
        warn "⚠️  Ports non accessibles - Configuration routeur requise"
        return 1
    fi
}

#############################################################################
# Génération du rapport de configuration
#############################################################################

generate_report() {
    local report_file="${BASE_DIR}/docs/port-forwarding-config-report.md"

    log "Génération du rapport de configuration..."

    cat > "$report_file" << EOF
# 📋 Rapport de configuration - Port Forwarding

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Option**: 1 - Port Forwarding + Traefik + DuckDNS

---

## 🌐 Informations réseau

| Paramètre | Valeur |
|-----------|--------|
| **IP locale (Pi)** | \`${LOCAL_IP}\` |
| **IP publique** | \`${PUBLIC_IP}\` |
| **IP routeur** | \`${ROUTER_IP}\` |
| **Domaine DuckDNS** | \`${DUCKDNS_DOMAIN}\` |

---

## ✅ Configuration requise sur le routeur

Vous devez créer **2 règles de redirection de ports** :

### Règle 1 : HTTP (Let's Encrypt Challenge)

\`\`\`
Nom          : Traefik-HTTP
Protocole    : TCP
Port externe : 80
IP interne   : ${LOCAL_IP}
Port interne : 80
État         : Activé
\`\`\`

### Règle 2 : HTTPS (Trafic sécurisé)

\`\`\`
Nom          : Traefik-HTTPS
Protocole    : TCP
Port externe : 443
IP interne   : ${LOCAL_IP}
Port interne : 443
État         : Activé
\`\`\`

---

## 🔗 Accès à votre routeur

**URL** : http://${ROUTER_IP}

Consultez le guide spécifique à votre FAI ci-dessus.

---

## 🧪 Vérification après configuration

Après avoir configuré votre routeur, testez l'accès :

\`\`\`bash
# Test port 80
curl -I http://${PUBLIC_IP}

# Test port 443
curl -I https://${PUBLIC_IP}

# Test domaine DuckDNS (après certificat Let's Encrypt)
curl -I https://${DUCKDNS_DOMAIN}
\`\`\`

---

## 📊 État actuel

EOF

    # Ajouter résultats des tests
    if test_port_open 80 "HTTP" >/dev/null 2>&1; then
        echo "- ✅ Port 80 : **Ouvert**" >> "$report_file"
    else
        echo "- ❌ Port 80 : **Fermé** (configuration routeur requise)" >> "$report_file"
    fi

    if test_port_open 443 "HTTPS" >/dev/null 2>&1; then
        echo "- ✅ Port 443 : **Ouvert**" >> "$report_file"
    else
        echo "- ❌ Port 443 : **Fermé** (configuration routeur requise)" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'

---

## 🔐 Sécurité recommandée

Après avoir ouvert les ports 80 et 443 :

1. **Firewall UFW** : Configuré automatiquement par le script prérequis
2. **Fail2ban** : Protection contre brute-force (déjà installé)
3. **Traefik** : Reverse proxy avec rate limiting
4. **Let's Encrypt** : Certificats SSL automatiques

---

## 📚 Prochaines étapes

1. Configurer le port forwarding sur votre routeur (voir guide ci-dessus)
2. Attendre 1-2 minutes que Let's Encrypt génère le certificat
3. Accéder à votre instance via HTTPS :
   - Studio : https://VOTRE_DOMAINE/studio
   - API : https://VOTRE_DOMAINE/api

---

**Généré par**: pi5-setup External Access Option 1
**Repository**: https://github.com/votre-repo/pi5-setup
EOF

    ok "Rapport généré: ${report_file}"
}

#############################################################################
# Menu interactif
#############################################################################

interactive_menu() {
    echo ""
    echo -e "${YELLOW}❓ Avez-vous déjà configuré le port forwarding sur votre routeur ?${NC}"
    echo ""
    echo "  1) Oui, tester la connectivité maintenant"
    echo "  2) Non, afficher le guide de configuration"
    echo "  3) Générer un rapport PDF de configuration"
    echo "  4) Quitter"
    echo ""
    read -p "Votre choix [1-4]: " choice

    case $choice in
        1)
            run_connectivity_tests
            if [[ $? -eq 0 ]]; then
                ok "✅ Configuration réussie !"
            else
                warn "Configuration routeur requise"
                interactive_menu
            fi
            ;;
        2)
            local org=$(curl -s "https://ipapi.co/${PUBLIC_IP}/json/" | jq -r '.org // "Inconnu"' 2>/dev/null || echo "Inconnu")
            show_router_guide "$org"
            read -p "Appuyez sur Entrée après avoir configuré votre routeur..."
            run_connectivity_tests
            ;;
        3)
            generate_report
            ok "Rapport généré dans ${BASE_DIR}/docs/"
            ;;
        4)
            log "Au revoir !"
            exit 0
            ;;
        *)
            error "Choix invalide"
            interactive_menu
            ;;
    esac
}

#############################################################################
# Main
#############################################################################

main() {
    banner

    # Vérifier si on est sur le Pi
    if [[ ! -f /proc/device-tree/model ]] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
        warn "Ce script doit être exécuté sur le Raspberry Pi"
    fi

    # Détection réseau
    detect_local_ip
    detect_public_ip
    detect_router_ip
    detect_isp

    # Demander domaine DuckDNS (si Traefik déjà configuré, lire depuis .env)
    if [[ -f /home/pi/stacks/traefik/.env ]]; then
        DUCKDNS_DOMAIN=$(grep DUCKDNS_DOMAIN /home/pi/stacks/traefik/.env | cut -d= -f2 || echo "")
    fi

    if [[ -z "$DUCKDNS_DOMAIN" ]]; then
        read -p "Votre domaine DuckDNS complet (ex: monpi.duckdns.org): " DUCKDNS_DOMAIN
    else
        ok "Domaine DuckDNS détecté: ${DUCKDNS_DOMAIN}"
    fi

    # Menu interactif
    interactive_menu

    # Génération rapport final
    generate_report

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║     ✅ Configuration Port Forwarding terminée                  ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}📖 Consultez le rapport détaillé :${NC}"
    echo -e "   ${BASE_DIR}/docs/port-forwarding-config-report.md"
    echo ""
    echo -e "${CYAN}🌐 Accès HTTPS :${NC}"
    echo -e "   https://${DUCKDNS_DOMAIN}/studio"
    echo ""
}

# Exécution
main "$@"
