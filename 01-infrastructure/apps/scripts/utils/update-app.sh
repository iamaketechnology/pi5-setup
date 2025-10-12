#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - UPDATE APP
#==============================================================================
# Pull latest code and rebuild app
#
# Usage:
#   update-app.sh <app-name>
#==============================================================================

set -euo pipefail

readonly APPS_DIR="/opt/apps"
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

if [[ $# -lt 1 ]]; then
    error "Usage: $0 <app-name>"
fi

APP_NAME="$1"
APP_DIR="${APPS_DIR}/${APP_NAME}"

if [[ ! -d "$APP_DIR" ]]; then
    error "App ${APP_NAME} not found"
fi

cd "$APP_DIR"

# Pull latest changes if git repo
if [[ -d ".git" ]]; then
    log "Pulling latest changes..."
    git pull
else
    log "Not a git repository, skipping pull"
fi

# Rebuild and restart
log "Rebuilding and restarting ${APP_NAME}..."
docker-compose up -d --build --force-recreate

log "Waiting for app to become healthy..."
sleep 10

if docker ps --filter "name=${APP_NAME}" | grep -q "${APP_NAME}"; then
    echo ""
    echo "✅ App '${APP_NAME}' updated successfully"
    echo "   Logs: docker logs -f ${APP_NAME}"
    echo ""
else
    error "Update failed. Check logs: docker logs ${APP_NAME}"
fi
