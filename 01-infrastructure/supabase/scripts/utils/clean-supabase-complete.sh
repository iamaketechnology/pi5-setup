#!/bin/bash
# =============================================================================
# CLEAN SUPABASE COMPLETE - Nettoyage Total Installation Supabase
# =============================================================================
# Version: 1.0.0
# Usage: sudo ./clean-supabase-complete.sh
# Description: Nettoie complètement une installation Supabase pour repartir à zéro
# =============================================================================

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}   🧹 NETTOYAGE COMPLET INSTALLATION SUPABASE          ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Vérification root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ Ce script doit être exécuté en tant que root (sudo)${NC}"
   exit 1
fi

echo -e "${YELLOW}⚠️  ATTENTION: Ce script va supprimer TOUTES les données Supabase !${NC}"
echo -e "${YELLOW}   - Tous les conteneurs Docker Supabase${NC}"
echo -e "${YELLOW}   - Tous les volumes (BASES DE DONNÉES INCLUSES)${NC}"
echo -e "${YELLOW}   - Tous les fichiers de configuration${NC}"
echo ""
read -p "Êtes-vous sûr de vouloir continuer ? (tapez 'oui' pour confirmer) : " confirm

if [[ "$confirm" != "oui" ]]; then
    echo -e "${GREEN}✅ Annulé. Aucune modification effectuée.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}[1/8]${NC} Arrêt des services Supabase..."

# Aller dans le répertoire Supabase si existe
cd /home/pi/stacks/supabase 2>/dev/null && {
    echo "   📁 Répertoire trouvé: /home/pi/stacks/supabase"

    # Arrêter avec docker compose
    if [ -f "docker-compose.yml" ]; then
        echo "   🛑 Arrêt via docker compose..."
        docker compose down -v --remove-orphans 2>/dev/null || true
        echo "   ✅ Services arrêtés"
    fi
} || {
    echo "   ℹ️  Répertoire Supabase non trouvé (peut-être déjà supprimé)"
}

cd ~

echo ""
echo -e "${BLUE}[2/8]${NC} Suppression des conteneurs Supabase..."

# Liste des conteneurs avant suppression
containers=$(docker ps -a -q --filter "name=supabase-" 2>/dev/null || true)
if [ -n "$containers" ]; then
    echo "   🔍 Conteneurs trouvés:"
    docker ps -a --filter "name=supabase-" --format "   - {{.Names}} ({{.Status}})"

    echo "   🗑️  Suppression forcée..."
    docker rm -f $(docker ps -a -q --filter "name=supabase-") 2>/dev/null || true
    echo "   ✅ Conteneurs supprimés"
else
    echo "   ℹ️  Aucun conteneur Supabase trouvé"
fi

echo ""
echo -e "${BLUE}[3/8]${NC} Suppression des volumes Supabase..."

# Liste des volumes avant suppression
volumes=$(docker volume ls -q | grep supabase 2>/dev/null || true)
if [ -n "$volumes" ]; then
    echo "   🔍 Volumes trouvés:"
    docker volume ls | grep supabase | sed 's/^/   - /'

    echo "   🗑️  Suppression des volumes..."
    docker volume rm $(docker volume ls -q | grep supabase) 2>/dev/null || true
    echo "   ✅ Volumes supprimés"
else
    echo "   ℹ️  Aucun volume Supabase trouvé"
fi

echo ""
echo -e "${BLUE}[4/8]${NC} Nettoyage des réseaux Docker..."

# Supprimer le réseau Supabase s'il existe
if docker network ls | grep -q "supabase_network"; then
    echo "   🔍 Réseau supabase_network trouvé"
    docker network rm supabase_network 2>/dev/null || true
    echo "   ✅ Réseau supprimé"
fi

# Nettoyage des réseaux orphelins
echo "   🧹 Nettoyage réseaux orphelins..."
docker network prune -f > /dev/null 2>&1
echo "   ✅ Réseaux nettoyés"

echo ""
echo -e "${BLUE}[5/8]${NC} Suppression des fichiers de configuration..."

if [ -d "/home/pi/stacks/supabase" ]; then
    echo "   📁 Suppression de /home/pi/stacks/supabase..."
    rm -rf /home/pi/stacks/supabase
    echo "   ✅ Répertoire supprimé"
else
    echo "   ℹ️  Répertoire déjà absent"
fi

# Supprimer aussi le dossier parent s'il est vide
if [ -d "/home/pi/stacks" ]; then
    if [ -z "$(ls -A /home/pi/stacks)" ]; then
        echo "   📁 Dossier /home/pi/stacks vide, suppression..."
        rmdir /home/pi/stacks
    fi
fi

echo ""
echo -e "${BLUE}[6/8]${NC} Libération des ports (3000, 8001, 5432)..."

# Tuer processus utilisant les ports Supabase
for port in 3000 8001 5432 54321 8080 4000 5000; do
    pids=$(lsof -ti :$port 2>/dev/null || true)
    if [ -n "$pids" ]; then
        echo "   🔫 Port $port utilisé, libération..."
        kill -9 $pids 2>/dev/null || true
    fi
done
echo "   ✅ Ports libérés"

echo ""
echo -e "${BLUE}[7/8]${NC} Nettoyage des logs..."

# Supprimer logs Supabase
logs_deleted=0
for log in /var/log/supabase-pi5-setup-*.log; do
    if [ -f "$log" ]; then
        rm -f "$log"
        ((logs_deleted++))
    fi
done

if [ $logs_deleted -gt 0 ]; then
    echo "   ✅ $logs_deleted fichier(s) log supprimé(s)"
else
    echo "   ℹ️  Aucun fichier log trouvé"
fi

echo ""
echo -e "${BLUE}[8/8]${NC} Nettoyage Docker global (optionnel)..."

# Nettoyage images non utilisées
echo "   🧹 Suppression des images Docker non utilisées..."
docker image prune -af > /dev/null 2>&1
echo "   ✅ Images nettoyées"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ NETTOYAGE COMPLET TERMINÉ !${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo -e "${YELLOW}📊 Vérification finale:${NC}"
echo ""

# Vérifier qu'il ne reste rien
echo "🔍 Conteneurs Supabase restants:"
remaining_containers=$(docker ps -a --filter "name=supabase-" --format "{{.Names}}" 2>/dev/null || true)
if [ -z "$remaining_containers" ]; then
    echo -e "   ${GREEN}✅ Aucun conteneur Supabase${NC}"
else
    echo -e "   ${RED}⚠️  Conteneurs restants:${NC}"
    echo "$remaining_containers" | sed 's/^/   - /'
fi

echo ""
echo "🔍 Volumes Supabase restants:"
remaining_volumes=$(docker volume ls -q | grep supabase 2>/dev/null || true)
if [ -z "$remaining_volumes" ]; then
    echo -e "   ${GREEN}✅ Aucun volume Supabase${NC}"
else
    echo -e "   ${RED}⚠️  Volumes restants:${NC}"
    echo "$remaining_volumes" | sed 's/^/   - /'
fi

echo ""
echo "🔍 Répertoire Supabase:"
if [ -d "/home/pi/stacks/supabase" ]; then
    echo -e "   ${RED}⚠️  Répertoire existe encore: /home/pi/stacks/supabase${NC}"
else
    echo -e "   ${GREEN}✅ Répertoire supprimé${NC}"
fi

echo ""
echo "🔍 Ports en écoute:"
ports_busy=""
for port in 3000 8001 5432 54321; do
    if lsof -i :$port > /dev/null 2>&1; then
        ports_busy="$ports_busy $port"
    fi
done

if [ -z "$ports_busy" ]; then
    echo -e "   ${GREEN}✅ Tous les ports Supabase sont libres${NC}"
else
    echo -e "   ${YELLOW}⚠️  Ports encore occupés:$ports_busy${NC}"
    echo "   💡 Redémarrez le Pi si nécessaire: sudo reboot"
fi

echo ""
echo -e "${GREEN}🎉 Système prêt pour une nouvelle installation Supabase !${NC}"
echo ""
echo -e "${BLUE}Prochaine étape:${NC}"
echo "  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-week2-supabase-finalfix.sh | sudo bash"
echo ""
