#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# RESET COMPLET - Nettoyage total du Pi avant réinstallation
# =============================================================================
# Version: 1.0.0
# Usage: ssh pi@IP_DU_PI 'bash -s' < RESET-COMPLET.sh
# =============================================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC}  $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC}  $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }

echo ""
echo -e "${RED}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║                                                    ║${NC}"
echo -e "${RED}║        🧹 RESET COMPLET - SUPPRESSION TOTALE       ║${NC}"
echo -e "${RED}║                                                    ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
echo ""

log_warning "⚠️  Cette opération va SUPPRIMER:"
echo "  • Tous les conteneurs Docker (Supabase, Traefik, etc.)"
echo "  • Tous les volumes Docker (bases de données, fichiers)"
echo "  • Toutes les configurations (/home/pi/stacks/)"
echo "  • Docker et Docker Compose"
echo ""
log_error "⚠️  LES DONNÉES SERONT PERDUES DE MANIÈRE IRRÉVERSIBLE"
echo ""

read -p "Êtes-vous ABSOLUMENT sûr ? (tapez 'OUI EFFACER TOUT'): " CONFIRM

if [ "$CONFIRM" != "OUI EFFACER TOUT" ]; then
    log_warning "Opération annulée (confirmation incorrecte)"
    exit 0
fi

echo ""
log_info "🗑️  Démarrage du nettoyage complet..."
echo ""

# =============================================================================
# ÉTAPE 1 : Arrêter et supprimer tous les conteneurs Docker
# =============================================================================

log_info "1️⃣  Arrêt de tous les conteneurs Docker..."

if command -v docker &> /dev/null; then
    # Arrêter tous les conteneurs
    RUNNING_CONTAINERS=$(docker ps -q)
    if [ -n "$RUNNING_CONTAINERS" ]; then
        docker stop $RUNNING_CONTAINERS 2>/dev/null || true
        log_success "Conteneurs arrêtés"
    fi

    # Supprimer tous les conteneurs
    ALL_CONTAINERS=$(docker ps -aq)
    if [ -n "$ALL_CONTAINERS" ]; then
        docker rm -f $ALL_CONTAINERS 2>/dev/null || true
        log_success "Conteneurs supprimés"
    fi

    # Supprimer tous les volumes
    log_info "Suppression des volumes Docker (données)..."
    docker volume prune -af 2>/dev/null || true
    log_success "Volumes supprimés"

    # Supprimer tous les réseaux
    docker network prune -f 2>/dev/null || true

    # Supprimer toutes les images
    log_info "Suppression des images Docker (peut prendre 1-2 min)..."
    docker image prune -af 2>/dev/null || true
    log_success "Images supprimées"

    log_success "✅ Docker nettoyé"
else
    log_info "Docker non installé (skip)"
fi

# =============================================================================
# ÉTAPE 2 : Supprimer Docker et Docker Compose
# =============================================================================

log_info "2️⃣  Désinstallation Docker..."

if command -v docker &> /dev/null; then
    # Arrêter le service Docker
    sudo systemctl stop docker 2>/dev/null || true
    sudo systemctl disable docker 2>/dev/null || true

    # Supprimer les paquets Docker
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true

    # Supprimer les fichiers Docker
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/docker
    sudo rm -rf /usr/local/bin/docker-compose

    log_success "✅ Docker désinstallé"
else
    log_info "Docker déjà désinstallé (skip)"
fi

# =============================================================================
# ÉTAPE 3 : Supprimer tous les dossiers de configuration
# =============================================================================

log_info "3️⃣  Suppression des configurations..."

# Supprimer le dossier stacks complet
if [ -d "/home/pi/stacks" ]; then
    sudo rm -rf /home/pi/stacks
    log_success "Dossier ~/stacks supprimé"
fi

# Supprimer les anciennes installations
sudo rm -rf /home/pi/supabase 2>/dev/null || true
sudo rm -rf /home/pi/traefik 2>/dev/null || true
sudo rm -rf /home/pi/monitoring 2>/dev/null || true

# Supprimer les logs
sudo rm -f /var/log/supabase*.log 2>/dev/null || true
sudo rm -f /var/log/pi5-setup*.log 2>/dev/null || true

log_success "✅ Configurations supprimées"

# =============================================================================
# ÉTAPE 4 : Supprimer Portainer
# =============================================================================

log_info "4️⃣  Suppression Portainer..."

if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q portainer; then
    docker stop portainer 2>/dev/null || true
    docker rm portainer 2>/dev/null || true
    docker volume rm portainer_data 2>/dev/null || true
    log_success "Portainer supprimé"
else
    log_info "Portainer déjà supprimé (skip)"
fi

# =============================================================================
# ÉTAPE 5 : Nettoyer UFW et Fail2ban (optionnel)
# =============================================================================

log_info "5️⃣  Réinitialisation pare-feu..."

if command -v ufw &> /dev/null; then
    sudo ufw --force reset 2>/dev/null || true
    log_success "UFW réinitialisé"
fi

if command -v fail2ban-client &> /dev/null; then
    sudo systemctl stop fail2ban 2>/dev/null || true
    sudo systemctl disable fail2ban 2>/dev/null || true
    log_success "Fail2ban désactivé"
fi

# =============================================================================
# RÉSUMÉ
# =============================================================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                    ║${NC}"
echo -e "${GREEN}║           ✅ NETTOYAGE TERMINÉ                     ║${NC}"
echo -e "${GREEN}║                                                    ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""

log_success "Le Pi est maintenant complètement nettoyé"
echo ""
log_info "📋 Étapes suivantes:"
echo "  1️⃣  Redémarrer le Pi: sudo reboot"
echo "  2️⃣  Relancer l'installation complète dans l'ordre"
echo ""
log_info "🚀 Installation complète (dans l'ordre):"
echo ""
echo "  # Phase 1: Prérequis"
echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash"
echo "  sudo reboot"
echo ""
echo "  # Phase 2: Supabase"
echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash"
echo ""
echo "  # Phase 3: Migration (si nécessaire)"
echo "  bash 01-migrate-cloud-to-pi.sh"
echo "  node 03-post-migration-storage.js"
echo ""
echo "  # Phase 4: Traefik"
echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash"
echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash"
echo ""

log_warning "⚠️  Pensez à noter vos credentials actuels si besoin avant reboot!"
echo ""
