#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Lister toutes les apps du Cloudflare Tunnel
#
# Description: Affiche toutes les apps configurées dans le tunnel
# Version: 1.0.0
#############################################################################

# Couleurs
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${BASE_DIR}/config"
APPS_DB="${CONFIG_DIR}/apps.json"

#############################################################################
# Vérifications
#############################################################################

if [[ ! -f "$APPS_DB" ]]; then
    echo -e "${YELLOW}[WARN]${NC} Base de données apps non trouvée: ${APPS_DB}"
    echo "Le tunnel n'est peut-être pas encore configuré."
    exit 1
fi

#############################################################################
# Affichage
#############################################################################

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                  ║${NC}"
echo -e "${BOLD}${CYAN}║     ☁️  Apps Cloudflare Tunnel                                  ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                  ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Informations tunnel
TUNNEL_NAME=$(jq -r '.tunnel_name // "N/A"' "$APPS_DB")
DOMAIN=$(jq -r '.domain // "N/A"' "$APPS_DB")
NB_APPS=$(jq '.apps | length' "$APPS_DB")

echo -e "${BOLD}📊 Informations Tunnel :${NC}"
echo "   • Nom : ${TUNNEL_NAME}"
echo "   • Domaine : ${DOMAIN}"
echo "   • Nombre d'apps : ${NB_APPS}"
echo ""

# Liste des apps
if [[ $NB_APPS -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  Aucune app configurée${NC}"
    echo ""
    echo "Pour ajouter une app :"
    echo "  sudo bash ${SCRIPT_DIR}/02-add-app-to-tunnel.sh \\"
    echo "    --name mon-app \\"
    echo "    --hostname mon-app.${DOMAIN} \\"
    echo "    --service mon-container:80"
    echo ""
else
    echo -e "${BOLD}📱 Apps configurées :${NC}"
    echo ""

    # Format tableau
    printf "%-15s %-35s %-30s %-10s\n" "NOM" "HOSTNAME" "SERVICE" "NO_TLS"
    printf "%-15s %-35s %-30s %-10s\n" "───────────────" "───────────────────────────────────" "──────────────────────────────" "──────────"

    jq -r '.apps[] | "\(.name)|\(.hostname)|\(.service)|\(.no_tls_verify)"' "$APPS_DB" | while IFS='|' read -r name hostname service no_tls; do
        printf "%-15s %-35s %-30s %-10s\n" "$name" "$hostname" "$service" "$no_tls"
    done

    echo ""
    echo -e "${GREEN}✅ ${NB_APPS} app(s) active(s)${NC}"
    echo ""
fi

# Status tunnel
echo -e "${BOLD}🐳 Status Container :${NC}"

if docker ps --filter "name=cloudflared-tunnel" --format "{{.Names}}: {{.Status}}" | grep -q "cloudflared-tunnel"; then
    docker ps --filter "name=cloudflared-tunnel" --format "   • {{.Names}}: {{.Status}}" | sed "s/cloudflared-tunnel/${GREEN}cloudflared-tunnel${NC}/"
    echo ""
    echo -e "${GREEN}✅ Tunnel actif${NC}"
else
    echo -e "${YELLOW}⚠️  Tunnel non actif${NC}"
    echo ""
    echo "Pour démarrer le tunnel :"
    echo "  cd ${BASE_DIR} && docker compose up -d"
fi

echo ""

# URLs d'accès
if [[ $NB_APPS -gt 0 ]]; then
    echo -e "${BOLD}🌐 URLs d'accès :${NC}"
    echo ""

    jq -r '.apps[] | "   https://\(.hostname)"' "$APPS_DB"

    echo ""
fi

# Commandes utiles
echo -e "${BOLD}💻 Commandes utiles :${NC}"
echo ""
echo "   Ajouter une app :"
echo "   └─ sudo bash ${SCRIPT_DIR}/02-add-app-to-tunnel.sh --help"
echo ""
echo "   Supprimer une app :"
echo "   └─ sudo bash ${SCRIPT_DIR}/03-remove-app-from-tunnel.sh --name NOM_APP"
echo ""
echo "   Logs du tunnel :"
echo "   └─ docker logs -f cloudflared-tunnel"
echo ""
echo "   Redémarrer le tunnel :"
echo "   └─ cd ${BASE_DIR} && docker compose restart"
echo ""
