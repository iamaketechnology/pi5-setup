#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - REMOVE APP
#==============================================================================
# Remove a deployed app (with confirmation)
#
# Usage:
#   remove-app.sh <app-name> [--force]
#==============================================================================

set -euo pipefail

readonly APPS_DIR="/opt/apps"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

if [[ $# -lt 1 ]]; then
    error "Usage: $0 <app-name> [--force]"
fi

APP_NAME="$1"
FORCE="${2:-}"
APP_DIR="${APPS_DIR}/${APP_NAME}"

if [[ ! -d "$APP_DIR" ]]; then
    error "App ${APP_NAME} not found in ${APPS_DIR}"
fi

# Confirmation
if [[ "$FORCE" != "--force" ]]; then
    warn "This will remove app '${APP_NAME}' and all its data."
    read -p "Are you sure? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Stop and remove container
if docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
    log "Stopping and removing container..."
    cd "$APP_DIR"
    docker-compose down -v 2>/dev/null || docker rm -f "$APP_NAME" 2>/dev/null || true
fi

# Remove directory
log "Removing app directory..."
rm -rf "$APP_DIR"

echo ""
echo "✅ App '${APP_NAME}' removed successfully"
echo ""
