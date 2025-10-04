#!/bin/bash
# =============================================================================
# Script: Récupération des Informations Supabase
# Description: Affiche toutes les informations importantes pour utiliser Supabase
# Usage: ./get-supabase-info.sh
# =============================================================================

set -euo pipefail

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"
ENV_FILE="$PROJECT_DIR/.env"

# Fonctions
print_header() {
    echo -e "${CYAN}=======================================================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${CYAN}=======================================================================${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "---"
}

check_file() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}❌ Erreur: Fichier .env introuvable à: $ENV_FILE${NC}"
        echo -e "${YELLOW}💡 Assurez-vous que Supabase est installé${NC}"
        exit 1
    fi
}

get_value() {
    local key="$1"
    grep "^${key}=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 || echo "N/A"
}

# Main
clear
print_header "🔐 INFORMATIONS SUPABASE - RASPBERRY PI 5"

check_file

# Section 1: URLs d'accès
print_section "🌐 URLs D'ACCÈS"
LOCAL_IP=$(hostname -I | awk '{print $1}')
SUPABASE_PORT=$(get_value "KONG_HTTP_PORT")
[[ "$SUPABASE_PORT" == "N/A" ]] && SUPABASE_PORT="8001"

echo -e "   ${GREEN}Studio UI:${NC}       http://${LOCAL_IP}:3000"
echo -e "   ${GREEN}API Gateway:${NC}     http://${LOCAL_IP}:${SUPABASE_PORT}"
echo -e "   ${GREEN}Edge Functions:${NC}  http://${LOCAL_IP}:54321"
echo -e "   ${GREEN}PostgreSQL:${NC}      ${LOCAL_IP}:5432"
echo -e "   ${GREEN}Realtime:${NC}        http://${LOCAL_IP}:4000"
echo ""

# Section 2: Clés API (CRITIQUE)
print_section "🔑 CLÉS API (SAUVEGARDEZ-LES!)"

ANON_KEY=$(get_value "SUPABASE_ANON_KEY")
SERVICE_KEY=$(get_value "SUPABASE_SERVICE_KEY")
JWT_SECRET=$(get_value "JWT_SECRET")

echo -e "   ${YELLOW}⚠️ ANON_KEY (Public - Utilisez dans votre frontend):${NC}"
if [[ "$ANON_KEY" != "N/A" ]]; then
    echo "      $ANON_KEY"
else
    echo -e "      ${RED}Non trouvée dans .env${NC}"
fi
echo ""

echo -e "   ${RED}🔒 SERVICE_ROLE_KEY (PRIVÉE - JAMAIS exposer au frontend!):${NC}"
if [[ "$SERVICE_KEY" != "N/A" ]]; then
    echo "      $SERVICE_KEY"
else
    echo -e "      ${RED}Non trouvée dans .env${NC}"
fi
echo ""

echo -e "   ${YELLOW}🎫 JWT_SECRET:${NC}"
if [[ "$JWT_SECRET" != "N/A" ]]; then
    echo "      ${JWT_SECRET:0:32}... (tronqué pour sécurité)"
else
    echo -e "      ${RED}Non trouvée dans .env${NC}"
fi
echo ""

# Section 3: Base de données
print_section "🗄️ CONNEXION BASE DE DONNÉES"

DB_PASSWORD=$(get_value "POSTGRES_PASSWORD")
DB_USER="postgres"
DB_NAME="postgres"
DB_PORT="5432"

echo -e "   ${GREEN}Host:${NC}            ${LOCAL_IP}"
echo -e "   ${GREEN}Port:${NC}            ${DB_PORT}"
echo -e "   ${GREEN}Database:${NC}        ${DB_NAME}"
echo -e "   ${GREEN}User:${NC}            ${DB_USER}"
echo -e "   ${GREEN}Password:${NC}        ${DB_PASSWORD:0:16}... (tronqué)"
echo ""
echo -e "   ${CYAN}📝 Connection String (PostgreSQL):${NC}"
echo "      postgresql://${DB_USER}:${DB_PASSWORD}@${LOCAL_IP}:${DB_PORT}/${DB_NAME}"
echo ""
echo -e "   ${CYAN}📝 Connection String (Supabase):${NC}"
echo "      postgres://postgres.[PROJECT-REF]:[PASSWORD]@db.${LOCAL_IP}.supabase.co:5432/postgres"
echo ""

# Section 4: Configuration Docker
print_section "🐳 CONFIGURATION DOCKER"

if [[ -d "$PROJECT_DIR" ]]; then
    echo -e "   ${GREEN}Répertoire projet:${NC}  $PROJECT_DIR"
    echo -e "   ${GREEN}Fichier .env:${NC}        $ENV_FILE"
    echo -e "   ${GREEN}Docker Compose:${NC}      $PROJECT_DIR/docker-compose.yml"
else
    echo -e "   ${RED}❌ Répertoire projet introuvable${NC}"
fi
echo ""

# Section 5: Status des services
print_section "📊 STATUS DES SERVICES"

if command -v docker &> /dev/null; then
    cd "$PROJECT_DIR" 2>/dev/null || true
    if docker compose ps &> /dev/null; then
        docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" | sed 's/^/   /'
    else
        echo -e "   ${YELLOW}⚠️ Impossible de récupérer le status Docker${NC}"
    fi
else
    echo -e "   ${RED}❌ Docker non installé${NC}"
fi
echo ""

# Section 6: Exemples d'utilisation
print_section "💡 EXEMPLES D'UTILISATION"

echo -e "${CYAN}1. Tester l'API avec curl:${NC}"
echo "   curl -X GET 'http://${LOCAL_IP}:${SUPABASE_PORT}/rest/v1/' \\"
echo "     -H \"apikey: ${ANON_KEY:0:50}...\" \\"
echo "     -H \"Authorization: Bearer ${ANON_KEY:0:50}...\""
echo ""

echo -e "${CYAN}2. Tester une Edge Function:${NC}"
echo "   curl -X POST 'http://${LOCAL_IP}:54321/functions/v1/main' \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -d '{\"name\":\"Pi5\"}'"
echo ""

echo -e "${CYAN}3. Se connecter à PostgreSQL:${NC}"
echo "   docker exec -it supabase-db psql -U postgres -d postgres"
echo ""

echo -e "${CYAN}4. Voir les logs d'un service:${NC}"
echo "   cd $PROJECT_DIR"
echo "   docker compose logs -f studio     # Studio UI"
echo "   docker compose logs -f auth       # Authentication"
echo "   docker compose logs -f realtime   # Realtime subscriptions"
echo ""

# Section 7: Commandes de gestion
print_section "🛠️ COMMANDES DE GESTION"

echo -e "${CYAN}Vérifier le status:${NC}"
echo "   cd $PROJECT_DIR && docker compose ps"
echo ""

echo -e "${CYAN}Redémarrer tous les services:${NC}"
echo "   cd $PROJECT_DIR && docker compose restart"
echo ""

echo -e "${CYAN}Redémarrer un service spécifique:${NC}"
echo "   cd $PROJECT_DIR && docker compose restart <service>"
echo "   Exemples: studio, auth, realtime, storage, edge-functions"
echo ""

echo -e "${CYAN}Arrêter Supabase:${NC}"
echo "   cd $PROJECT_DIR && docker compose down"
echo ""

echo -e "${CYAN}Démarrer Supabase:${NC}"
echo "   cd $PROJECT_DIR && docker compose up -d"
echo ""

echo -e "${CYAN}Voir tous les logs:${NC}"
echo "   cd $PROJECT_DIR && docker compose logs -f"
echo ""

# Section 8: Fichiers importants
print_section "📁 FICHIERS IMPORTANTS"

echo -e "   ${GREEN}.env${NC}                  Toutes les variables d'environnement"
echo -e "   ${GREEN}docker-compose.yml${NC}   Configuration des services Docker"
echo -e "   ${GREEN}kong.yml${NC}              Configuration API Gateway"
echo -e "   ${GREEN}volumes/db/${NC}           Données PostgreSQL"
echo -e "   ${GREEN}volumes/storage/${NC}      Fichiers uploadés"
echo -e "   ${GREEN}volumes/functions/${NC}    Edge Functions code"
echo ""

# Section 9: Sécurité
print_section "🔒 RAPPELS DE SÉCURITÉ"

echo -e "   ${RED}❌ JAMAIS exposer SERVICE_ROLE_KEY dans le frontend${NC}"
echo -e "   ${RED}❌ JAMAIS commiter le fichier .env dans Git${NC}"
echo -e "   ${RED}❌ JAMAIS partager vos clés API publiquement${NC}"
echo -e "   ${YELLOW}⚠️  Utilisez ANON_KEY pour les applications frontend${NC}"
echo -e "   ${YELLOW}⚠️  Utilisez SERVICE_ROLE_KEY uniquement côté serveur${NC}"
echo -e "   ${GREEN}✅ Activez RLS (Row Level Security) sur vos tables${NC}"
echo -e "   ${GREEN}✅ Configurez des politiques d'accès appropriées${NC}"
echo ""

# Section 10: Sauvegarde
print_section "💾 SAUVEGARDE DES INFORMATIONS"

BACKUP_FILE="/home/$TARGET_USER/supabase-info-$(date +%Y%m%d-%H%M%S).txt"

echo -e "${CYAN}Voulez-vous sauvegarder ces informations dans un fichier ?${NC}"
echo -e "Fichier: ${GREEN}$BACKUP_FILE${NC}"
echo ""
read -p "Sauvegarder? (o/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[OoYy]$ ]]; then
    {
        echo "==================================================================="
        echo "INFORMATIONS SUPABASE - Sauvegardé le $(date)"
        echo "==================================================================="
        echo ""
        echo "URLs:"
        echo "  Studio:         http://${LOCAL_IP}:3000"
        echo "  API Gateway:    http://${LOCAL_IP}:${SUPABASE_PORT}"
        echo "  Edge Functions: http://${LOCAL_IP}:54321"
        echo "  PostgreSQL:     ${LOCAL_IP}:5432"
        echo ""
        echo "CLÉS API:"
        echo "  ANON_KEY:         $ANON_KEY"
        echo "  SERVICE_ROLE_KEY: $SERVICE_KEY"
        echo "  JWT_SECRET:       $JWT_SECRET"
        echo ""
        echo "BASE DE DONNÉES:"
        echo "  Host:     ${LOCAL_IP}"
        echo "  Port:     ${DB_PORT}"
        echo "  Database: ${DB_NAME}"
        echo "  User:     ${DB_USER}"
        echo "  Password: ${DB_PASSWORD}"
        echo ""
        echo "Connection String:"
        echo "  postgresql://${DB_USER}:${DB_PASSWORD}@${LOCAL_IP}:${DB_PORT}/${DB_NAME}"
        echo ""
        echo "FICHIERS:"
        echo "  Projet: $PROJECT_DIR"
        echo "  .env:   $ENV_FILE"
        echo ""
    } > "$BACKUP_FILE"

    chmod 600 "$BACKUP_FILE"
    echo -e "${GREEN}✅ Informations sauvegardées dans: $BACKUP_FILE${NC}"
    echo -e "${YELLOW}⚠️  Ce fichier contient des informations sensibles - protégez-le!${NC}"
else
    echo -e "${BLUE}ℹ️  Sauvegarde annulée${NC}"
fi

echo ""
print_header "✅ INFORMATIONS AFFICHÉES AVEC SUCCÈS"

echo -e "${CYAN}💡 Astuce:${NC} Relancez ce script à tout moment avec:"
echo -e "   ${GREEN}./get-supabase-info.sh${NC}"
echo ""
