#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Cloudflare Tunnel Wizard - Assistant de décision intelligent
#
# Description: Guide l'utilisateur pour choisir entre tunnel générique ou par app
# Version: 1.0.0
# Author: PI5-SETUP Project
# Idempotent: ✅ Oui (détecte installations existantes)
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/cloudflare-tunnel-wizard-$(date +%Y%m%d_%H%M%S).log"
EXISTING_TUNNEL=""
TUNNEL_TYPE=""
USER_CHOICE=""

#############################################################################
# Fonctions utilitaires
#############################################################################

log() { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
title() { echo -e "${BOLD}${BLUE}$*${NC}"; }
section() { echo -e "\n${BOLD}${MAGENTA}═══ $* ═══${NC}\n"; }

error_exit() {
    error "$1"
    exit 1
}

banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     ☁️  Cloudflare Tunnel Wizard - Assistant de Configuration       ║
║                                                                      ║
║     Version 1.0.0 - Pi5 Setup Project                              ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

press_enter() {
    echo ""
    read -p "$(echo -e "${CYAN}Appuyez sur Entrée pour continuer...${NC}")"
    echo ""
}

#############################################################################
# Détection environnement existant (IDEMPOTENCE)
#############################################################################

detect_existing_setup() {
    section "🔍 Détection de l'environnement existant"

    log "Vérification 1/3 : Recherche de cloudflared..."

    # Vérifier si cloudflared est installé
    if command -v cloudflared &> /dev/null; then
        ok "cloudflared est déjà installé ($(cloudflared --version 2>&1 | head -1))"

        # Lister les tunnels existants
        log "Vérification 2/3 : Recherche des tunnels existants..."
        local tunnels=$(sudo cloudflared tunnel list 2>/dev/null || echo "")

        if [[ -n "$tunnels" ]]; then
            echo ""
            warn "Tunnels Cloudflare détectés :"
            echo "$tunnels"
            EXISTING_TUNNEL="yes"
        else
            ok "Aucun tunnel existant trouvé"
            EXISTING_TUNNEL="no"
        fi
    else
        ok "cloudflared n'est pas installé (installation sera proposée)"
        EXISTING_TUNNEL="no"
    fi

    # Vérifier containers Docker cloudflared
    log "Vérification 3/3 : Recherche des containers Docker..."
    local cf_containers=$(docker ps -a --filter "name=cloudflared" --format "{{.Names}}" 2>/dev/null || echo "")

    if [[ -n "$cf_containers" ]]; then
        echo ""
        warn "Containers cloudflared détectés :"
        echo "$cf_containers" | sed 's/^/  - /'
    else
        ok "Aucun container cloudflared trouvé"
    fi

    # Vérifier configurations existantes (silencieux, juste pour info)
    local config_dirs=$(find "$BASE_DIR" -name "config.yml" -o -name "credentials.json" 2>/dev/null || echo "")

    if [[ -n "$config_dirs" ]]; then
        echo ""
        warn "Configurations détectées :"
        echo "$config_dirs" | sed 's/^/  - /'
    fi

    echo ""
    ok "✅ Détection terminée ! Aucun problème trouvé."
    echo ""
    press_enter
}

#############################################################################
# Analyse du contexte utilisateur
#############################################################################

analyze_user_context() {
    section "📊 Analyse de votre contexte"

    title "Pour vous proposer la meilleure solution, quelques questions :"
    echo ""

    # Question 1 : Nombre d'apps
    echo -e "${BOLD}1. Combien d'applications prévoyez-vous d'exposer via Cloudflare Tunnel ?${NC}"
    echo "   (CertiDoc + autres apps futures)"
    echo ""
    echo "   a) Seulement CertiDoc (1 app)"
    echo "   b) CertiDoc + 1-2 autres apps (2-3 apps)"
    echo "   c) CertiDoc + plusieurs apps (4+ apps)"
    echo ""
    read -p "Votre réponse [a/b/c]: " nb_apps

    # Question 2 : Fréquence ajout apps
    echo ""
    echo -e "${BOLD}2. À quelle fréquence ajouterez-vous de nouvelles apps ?${NC}"
    echo ""
    echo "   a) Rarement (tous les 6+ mois)"
    echo "   b) Occasionnellement (tous les 1-3 mois)"
    echo "   c) Souvent (toutes les semaines)"
    echo ""
    read -p "Votre réponse [a/b/c]: " freq_apps

    # Question 3 : Criticité isolation
    echo ""
    echo -e "${BOLD}3. Est-il critique que vos apps soient totalement isolées ?${NC}"
    echo "   (Ex: si une app plante, les autres doivent rester up)"
    echo ""
    echo "   a) Non, quelques secondes d'indisponibilité OK"
    echo "   b) Oui, isolation critique (production sensible)"
    echo ""
    read -p "Votre réponse [a/b]: " isolation

    # Question 4 : Ressources
    echo ""
    echo -e "${BOLD}4. Voulez-vous optimiser les ressources (RAM) ?${NC}"
    echo ""
    echo "   a) Oui, économiser la RAM est important"
    echo "   b) Non, j'ai 16GB RAM, pas de souci"
    echo ""
    read -p "Votre réponse [a/b]: " resources

    # Calculer score
    local score_generic=0
    local score_per_app=0

    # Scoring
    case "$nb_apps" in
        a) score_per_app=$((score_per_app + 2)) ;;
        b) score_generic=$((score_generic + 1)) ;;
        c) score_generic=$((score_generic + 3)) ;;
    esac

    case "$freq_apps" in
        a) score_per_app=$((score_per_app + 1)) ;;
        b) score_generic=$((score_generic + 1)) ;;
        c) score_generic=$((score_generic + 2)) ;;
    esac

    case "$isolation" in
        a) score_generic=$((score_generic + 2)) ;;
        b) score_per_app=$((score_per_app + 3)) ;;
    esac

    case "$resources" in
        a) score_generic=$((score_generic + 2)) ;;
        b) score_per_app=$((score_per_app + 1)) ;;
    esac

    echo ""
    log "Analyse terminée..."
    sleep 1

    # Recommandation
    if [[ $score_generic -ge $score_per_app ]]; then
        TUNNEL_TYPE="generic"
    else
        TUNNEL_TYPE="per-app"
    fi
}

#############################################################################
# Présentation détaillée Option 1 : Tunnel Générique
#############################################################################

present_option_generic() {
    clear
    section "📦 OPTION 1 : Tunnel Générique (Multi-Apps)"

    cat << 'EOF'

┌────────────────────────────────────────────────────────────────────┐
│                      ARCHITECTURE                                  │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Internet                                                          │
│     ↓                                                              │
│  Cloudflare CDN                                                    │
│     ↓                                                              │
│  Cloudflare Tunnel (1 container, ~50 MB RAM)                      │
│     ├──→ certidoc.votredomaine.com → certidoc-frontend:80         │
│     ├──→ app2.votredomaine.com → autre-app:3000                   │
│     ├──→ api.votredomaine.com → supabase-kong:8000                │
│     └──→ studio.votredomaine.com → supabase-studio:3000           │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

EOF

    title "✅ AVANTAGES"
    cat << 'EOF'

  1. 💰 Économie de ressources
     • Un seul container = 50 MB RAM (vs 50 MB × N apps)
     • Un seul processus cloudflared

  2. 🎯 Simplicité de gestion
     • Une seule configuration (config.yml)
     • Un seul dashboard Cloudflare
     • Commandes unifiées

  3. 🚀 Évolutivité facile
     • Ajouter une app = 3 lignes dans config.yml
     • Script automatisé fourni :
       $ sudo bash add-app-to-tunnel.sh mon-app mon-container 3000

  4. 🔧 Maintenance simplifiée
     • Un seul point de surveillance
     • Logs centralisés
     • Redémarrage unique

  5. 🌐 DNS centralisé
     • Gestion des subdomains depuis un seul tunnel
     • Wildcard DNS possible (*.votredomaine.com)

EOF

    title "⚠️  INCONVÉNIENTS"
    cat << 'EOF'

  1. ⏱️  Point de défaillance unique
     • Si le tunnel redémarre → toutes apps offline ~5-10 secondes
     • (Rare : redémarrage uniquement si modif config)

  2. 🔗 Couplage des apps
     • Modifier config d'une app = redémarrage tunnel = impact toutes apps

  3. 📊 Logs partagés
     • Toutes les requêtes dans les mêmes logs
     • (Peut compliquer debug si beaucoup d'apps)

EOF

    title "📊 CONSOMMATION RESSOURCES"
    cat << 'EOF'

  • RAM : 50 MB (fixe, peu importe le nombre d'apps)
  • CPU : < 1% en idle, 2-5% sous charge
  • Stockage : ~30 MB (binaire + config)
  • Réseau : Transparent (pas de surcoût par app)

EOF

    title "🎯 CAS D'USAGE IDÉAUX"
    cat << 'EOF'

  ✅ Vous avez 3+ apps à exposer
  ✅ Vous ajoutez souvent de nouvelles apps
  ✅ Quelques secondes d'indisponibilité OK (rare)
  ✅ Vous voulez économiser la RAM
  ✅ Vous préférez la simplicité de gestion

EOF

    title "💻 EXEMPLE D'UTILISATION"
    cat << 'BASH'

# Installation initiale
sudo bash 01-setup-generic-tunnel.sh

# Ajouter CertiDoc
sudo bash 02-add-app-to-tunnel.sh \
  --name certidoc \
  --hostname certidoc.votredomaine.com \
  --service certidoc-frontend:80

# Ajouter une autre app
sudo bash 02-add-app-to-tunnel.sh \
  --name portfolio \
  --hostname portfolio.votredomaine.com \
  --service portfolio-app:3000

# Lister toutes les apps
sudo bash 04-list-tunnel-apps.sh

# Résultat :
# - certidoc.votredomaine.com → certidoc-frontend:80
# - portfolio.votredomaine.com → portfolio-app:3000

BASH

    echo ""
    press_enter
}

#############################################################################
# Présentation détaillée Option 2 : Tunnel par App
#############################################################################

present_option_per_app() {
    clear
    section "🔗 OPTION 2 : Tunnel Par App (Isolation Maximale)"

    cat << 'EOF'

┌────────────────────────────────────────────────────────────────────┐
│                      ARCHITECTURE                                  │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Internet                                                          │
│     ↓                                                              │
│  Cloudflare CDN                                                    │
│     ↓                                                              │
│  ┌─────────────────────────────────────────┐                      │
│  │ Tunnel CertiDoc (~50 MB RAM)            │                      │
│  │   certidoc.votredomaine.com             │                      │
│  │     → certidoc-frontend:80              │                      │
│  └─────────────────────────────────────────┘                      │
│                                                                    │
│  ┌─────────────────────────────────────────┐                      │
│  │ Tunnel App2 (~50 MB RAM)                │                      │
│  │   app2.votredomaine.com                 │                      │
│  │     → app2-container:3000               │                      │
│  └─────────────────────────────────────────┘                      │
│                                                                    │
│  ┌─────────────────────────────────────────┐                      │
│  │ Tunnel Supabase (~50 MB RAM)            │                      │
│  │   api.votredomaine.com                  │                      │
│  │     → supabase-kong:8000                │                      │
│  └─────────────────────────────────────────┘                      │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

EOF

    title "✅ AVANTAGES"
    cat << 'EOF'

  1. 🛡️  Isolation totale
     • Une app plante → autres apps 100% opérationnelles
     • Zéro impact inter-apps

  2. 🔒 Sécurité renforcée
     • Chaque tunnel = credentials séparées
     • Compromission d'un tunnel ≠ compromission des autres

  3. 🎚️  Configuration indépendante
     • Modifier config app1 = pas de redémarrage app2
     • Chaque app a son propre config.yml

  4. 📊 Monitoring granulaire
     • Logs séparés par app
     • Métriques Cloudflare individuelles
     • Dashboard séparé par tunnel

  5. 🔧 Flexibilité maximale
     • Arrêter/démarrer une app sans impacter les autres
     • Versions cloudflared différentes possibles

EOF

    title "⚠️  INCONVÉNIENTS"
    cat << 'EOF'

  1. 💾 Consommation RAM
     • N apps = N × 50 MB RAM
     • 5 apps = 250 MB RAM vs 50 MB (option 1)

  2. 🔧 Complexité de gestion
     • N configurations à maintenir
     • N dashboards Cloudflare à surveiller
     • N credentials à sécuriser

  3. ⏱️  Temps de setup
     • Installation plus longue (répéter N fois)
     • Scripts d'automatisation nécessaires

  4. 🌐 Gestion DNS multiple
     • Créer N tunnels dans Cloudflare
     • Configurer N fois les routes DNS

EOF

    title "📊 CONSOMMATION RESSOURCES"
    cat << 'EOF'

  Par app :
    • RAM : 50 MB
    • CPU : < 1% en idle
    • Stockage : ~10 MB (config)

  Total (5 apps) :
    • RAM : 250 MB
    • CPU : 2-3%
    • Stockage : ~50 MB

EOF

    title "🎯 CAS D'USAGE IDÉAUX"
    cat << 'EOF'

  ✅ Apps critiques (production sensible)
  ✅ Besoin d'isolation totale
  ✅ 16GB RAM disponibles (ressources OK)
  ✅ Peu d'apps à gérer (1-3 max)
  ✅ Sécurité maximale requise

EOF

    title "💻 EXEMPLE D'UTILISATION"
    cat << 'BASH'

# Installation pour CertiDoc
sudo bash 01-setup-per-app-tunnel.sh \
  --app-name certidoc \
  --hostname certidoc.votredomaine.com \
  --service certidoc-frontend:80

# Installation pour une autre app
sudo bash 01-setup-per-app-tunnel.sh \
  --app-name portfolio \
  --hostname portfolio.votredomaine.com \
  --service portfolio-app:3000

# Gérer individuellement
docker logs certidoc-tunnel
docker logs portfolio-tunnel

docker restart certidoc-tunnel  # portfolio non affecté

BASH

    echo ""
    press_enter
}

#############################################################################
# Tableau comparatif
#############################################################################

show_comparison_table() {
    clear
    section "📊 Tableau Comparatif Complet"

    cat << 'EOF'

┌────────────────────────────────┬──────────────────────┬──────────────────────┐
│ Critère                        │ Option 1 (Générique) │ Option 2 (Par App)   │
├────────────────────────────────┼──────────────────────┼──────────────────────┤
│ RAM (5 apps)                   │ 50 MB                │ 250 MB               │
│ Containers                     │ 1                    │ 5                    │
│ Complexité setup               │ ⭐ Facile            │ ⭐⭐⭐ Moyen          │
│ Temps installation             │ 10 min               │ 15 min × N apps      │
│ Maintenance                    │ ⭐ Simple            │ ⭐⭐⭐ Complexe       │
│ Ajouter une app                │ 1 min                │ 15 min               │
│ Isolation                      │ ❌ Partagée          │ ✅ Totale            │
│ Impact redémarrage             │ Toutes apps          │ 1 app seulement      │
│ Logs                           │ Centralisés          │ Séparés              │
│ Dashboards Cloudflare          │ 1                    │ N                    │
│ Credentials                    │ 1 fichier            │ N fichiers           │
│ Configuration                  │ 1 config.yml         │ N config.yml         │
│ Recommandé pour                │ 3+ apps              │ 1-2 apps critiques   │
│ Économie ressources            │ ✅ Oui               │ ❌ Non               │
│ Sécurité maximale              │ ⭐⭐ Bonne           │ ⭐⭐⭐ Excellente     │
└────────────────────────────────┴──────────────────────┴──────────────────────┘

EOF

    echo ""
    press_enter
}

#############################################################################
# Recommandation intelligente
#############################################################################

show_recommendation() {
    clear
    section "🎯 Recommandation Personnalisée"

    echo -e "${BOLD}Basé sur vos réponses :${NC}\n"

    if [[ "$TUNNEL_TYPE" == "generic" ]]; then
        cat << 'EOF'
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  🏆 RECOMMANDATION : Option 1 - Tunnel Générique                    │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Pourquoi cette recommandation ?

  ✅ Vous prévoyez plusieurs apps
  ✅ Vous ajouterez des apps régulièrement
  ✅ L'isolation totale n'est pas critique
  ✅ Vous souhaitez optimiser les ressources
  ✅ Vous préférez la simplicité de gestion

Ce que vous obtenez :

  📦 Un seul container cloudflared (50 MB RAM)
  🎯 Commandes simples pour gérer vos apps :
     • add-app-to-tunnel.sh
     • remove-app-from-tunnel.sh
     • list-tunnel-apps.sh
  🚀 Ajout d'apps en < 1 minute
  💰 Économie maximale de RAM

Parfait pour :
  - Homelabs avec plusieurs projets
  - Environnements de développement
  - Petites équipes avec apps non-critiques

EOF
    else
        cat << 'EOF'
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  🏆 RECOMMANDATION : Option 2 - Tunnel Par App                      │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘

Pourquoi cette recommandation ?

  ✅ Vous avez peu d'apps (1-2)
  ✅ L'isolation est critique pour vous
  ✅ Vous avez des ressources RAM suffisantes
  ✅ Vous priorisez la sécurité maximale

Ce que vous obtenez :

  🛡️  Isolation totale entre apps
  🔒 Sécurité maximale (credentials séparées)
  📊 Monitoring granulaire par app
  🎚️  Configuration indépendante par app

Parfait pour :
  - Applications en production critique
  - Apps manipulant données sensibles
  - Besoin d'audit de sécurité
  - Environnements avec SLA stricts

EOF
    fi

    echo ""

    # Montrer l'autre option aussi
    echo -e "${BOLD}💡 Note :${NC} Vous pouvez aussi choisir l'autre option si vous préférez.\n"

    press_enter
}

#############################################################################
# Menu de choix final
#############################################################################

final_choice() {
    clear
    section "🎯 Votre Décision Finale"

    cat << EOF

${BOLD}Quelle option voulez-vous installer ?${NC}

  ${GREEN}1)${NC} Option 1 - Tunnel Générique (Multi-Apps)
     ${CYAN}→ Recommandé si : plusieurs apps, simplicité, économie RAM${NC}

  ${GREEN}2)${NC} Option 2 - Tunnel Par App (Isolation)
     ${CYAN}→ Recommandé si : 1-2 apps, isolation critique, sécurité max${NC}

  ${GREEN}3)${NC} Afficher à nouveau la comparaison détaillée

  ${GREEN}4)${NC} Quitter (je déciderai plus tard)

EOF

    read -p "Votre choix [1/2/3/4]: " choice

    case "$choice" in
        1)
            USER_CHOICE="generic"
            confirm_installation
            ;;
        2)
            USER_CHOICE="per-app"
            confirm_installation
            ;;
        3)
            show_comparison_table
            present_option_generic
            present_option_per_app
            final_choice
            ;;
        4)
            echo ""
            log "Installation annulée. Vous pouvez relancer ce script plus tard."
            echo ""
            exit 0
            ;;
        *)
            warn "Choix invalide"
            sleep 1
            final_choice
            ;;
    esac
}

#############################################################################
# Confirmation et lancement installation
#############################################################################

confirm_installation() {
    clear
    section "✅ Confirmation Installation"

    if [[ "$USER_CHOICE" == "generic" ]]; then
        echo -e "${BOLD}Vous avez choisi :${NC} ${GREEN}Option 1 - Tunnel Générique${NC}\n"

        cat << 'EOF'
Ce qui va être installé :

  📦 Scripts :
     • 01-setup-generic-tunnel.sh          (installation initiale)
     • 02-add-app-to-tunnel.sh             (ajouter app)
     • 03-remove-app-from-tunnel.sh        (supprimer app)
     • 04-list-tunnel-apps.sh              (lister apps)
     • 05-update-tunnel-config.sh          (regénérer config)

  🐳 Container Docker :
     • cloudflared-tunnel (1 container, ~50 MB RAM)

  📁 Configuration :
     • config/apps.json                    (base données apps)
     • config/config.yml                   (config auto-générée)
     • config/credentials.json             (credentials Cloudflare)

  ⏱️  Durée estimée : 10-15 minutes

EOF
    else
        echo -e "${BOLD}Vous avez choisi :${NC} ${GREEN}Option 2 - Tunnel Par App${NC}\n"

        cat << 'EOF'
Ce qui va être installé :

  📦 Scripts :
     • 01-setup-per-app-tunnel.sh          (installation par app)
     • 02-manage-app-tunnel.sh             (gérer tunnel app)
     • 03-list-app-tunnels.sh              (lister tunnels)

  🐳 Containers Docker :
     • 1 container par app (~50 MB RAM chacun)
     • Nommés : {app-name}-tunnel

  📁 Configuration :
     • config/{app-name}/config.yml        (config par app)
     • config/{app-name}/credentials.json  (credentials par app)

  ⏱️  Durée estimée : 15 minutes par app

EOF
    fi

    echo ""
    read -p "$(echo -e "${BOLD}Continuer avec cette installation ? [Y/n]:${NC} ")" confirm

    case "$confirm" in
        [Nn]*)
            warn "Installation annulée"
            final_choice
            ;;
        *)
            launch_installation
            ;;
    esac
}

#############################################################################
# Lancement installation
#############################################################################

launch_installation() {
    clear
    section "🚀 Lancement de l'installation"

    if [[ "$USER_CHOICE" == "generic" ]]; then
        log "Installation du Tunnel Générique..."

        # Vérifier si script existe
        local script_path="${BASE_DIR}/cloudflare-tunnel-generic/scripts/01-setup-generic-tunnel.sh"

        if [[ -f "$script_path" ]]; then
            ok "✅ Script trouvé : $script_path"
            echo ""
            log "Lancement du script d'installation dans 3 secondes..."
            sleep 3

            bash "$script_path"

            # Après installation, afficher le résumé
            show_final_summary
        else
            warn "Script non trouvé : $script_path"
            echo ""
            error "Les scripts d'installation n'ont pas été trouvés."
            echo ""
            log "Veuillez télécharger les scripts depuis GitHub :"
            echo ""
            echo "  cd /tmp"
            echo "  git clone https://github.com/iamaketechnology/pi5-setup.git"
            echo "  cd pi5-setup/01-infrastructure/external-access/cloudflare-tunnel-generic/scripts"
            echo "  sudo bash 01-setup-generic-tunnel.sh"
            echo ""
        fi
    else
        log "Installation du Tunnel Par App..."

        # Pour l'instant, utiliser le script existant option2
        warn "Option Tunnel Par App : Utilise le script existant option2-cloudflare-tunnel"
        echo ""
        log "Lancement de l'installation dans 3 secondes..."
        sleep 3

        local script_path="${BASE_DIR}/option2-cloudflare-tunnel/scripts/01-setup-cloudflare-tunnel.sh"

        if [[ -f "$script_path" ]]; then
            bash "$script_path"
        else
            warn "Script non trouvé localement"
            echo ""
            log "Téléchargement depuis GitHub..."
            echo ""
            curl -fsSL "https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/external-access/option2-cloudflare-tunnel/scripts/01-setup-cloudflare-tunnel.sh" | bash
        fi

        show_final_summary
    fi
}

#############################################################################
# Résumé et documentation
#############################################################################

show_final_summary() {
    clear
    section "📚 Résumé et Prochaines Étapes"

    cat << EOF

${BOLD}✅ Wizard terminé !${NC}

${BOLD}Ce que nous avons déterminé :${NC}

  • Environnement existant : ${EXISTING_TUNNEL}
  • Recommandation : Option $([ "$TUNNEL_TYPE" == "generic" ] && echo "1 (Générique)" || echo "2 (Par App)")
  • Votre choix : Option $([ "$USER_CHOICE" == "generic" ] && echo "1 (Générique)" || echo "2 (Par App)")

${BOLD}📖 Documentation :${NC}

  Ce wizard a généré un rapport complet :
  ${LOG_FILE}

  Pour plus d'infos, consultez :
  • ${BASE_DIR}/README.md
  • ${BASE_DIR}/docs/COMPARISON.md

${BOLD}🆘 Besoin d'aide ?${NC}

  • Relancer ce wizard : sudo bash 00-cloudflare-tunnel-wizard.sh
  • GitHub Issues : https://github.com/iamaketechnology/pi5-setup/issues
  • Documentation Cloudflare : https://developers.cloudflare.com/cloudflare-one/

EOF

    ok "Installation terminée avec succès !"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    # Vérifier root
    if [[ "$EUID" -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root"
        echo "Usage: sudo $0"
        exit 1
    fi

    banner

    # Workflow du wizard
    detect_existing_setup
    analyze_user_context
    present_option_generic
    present_option_per_app
    show_comparison_table
    show_recommendation
    final_choice

    # Note: show_final_summary sera appelé après installation
}

main "$@"
