#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - LIST DEPLOYED APPS
#==============================================================================
# List all deployed apps with status and URLs
#==============================================================================

set -euo pipefail

readonly APPS_DIR="/opt/apps"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                   DEPLOYED APPS                                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

if [[ ! -d "$APPS_DIR" ]] || [[ -z "$(ls -A "$APPS_DIR" 2>/dev/null)" ]]; then
    echo "No apps deployed yet."
    echo ""
    echo "Deploy your first app:"
    echo "  sudo bash /opt/pi5-apps-stack/scripts/utils/deploy-nextjs-app.sh myapp app.domain.com"
    exit 0
fi

printf "%-20s %-30s %-15s %-10s\n" "APP NAME" "DOMAIN" "STATUS" "MEMORY"
printf "%-20s %-30s %-15s %-10s\n" "--------" "------" "------" "------"

for app_dir in "$APPS_DIR"/*; do
    if [[ ! -d "$app_dir" ]]; then
        continue
    fi

    app_name=$(basename "$app_dir")

    # Try to get domain from .env or docker-compose.yml
    domain="N/A"
    if [[ -f "${app_dir}/.env" ]]; then
        domain=$(grep "APP_DOMAIN=" "${app_dir}/.env" | cut -d= -f2 || echo "N/A")
    fi

    # Get container status
    if docker ps --format '{{.Names}}' | grep -q "^${app_name}$"; then
        status="✅ Running"

        # Get memory usage
        memory=$(docker stats --no-stream --format "{{.MemUsage}}" "$app_name" 2>/dev/null | awk '{print $1}' || echo "N/A")
    elif docker ps -a --format '{{.Names}}' | grep -q "^${app_name}$"; then
        status="⏸  Stopped"
        memory="N/A"
    else
        status="❌ No container"
        memory="N/A"
    fi

    printf "%-20s %-30s %-15s %-10s\n" "$app_name" "$domain" "$status" "$memory"
done

echo ""
echo "Total apps: $(find "$APPS_DIR" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')"
echo ""
echo "Commands:"
echo "  View logs:    docker logs -f <app-name>"
echo "  Deploy new:   sudo bash /opt/pi5-apps-stack/scripts/utils/deploy-nextjs-app.sh <name> <domain>"
echo "  Remove app:   sudo bash /opt/pi5-apps-stack/scripts/utils/remove-app.sh <name>"
echo ""
