#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - VIEW APP LOGS
#==============================================================================
# View logs for a deployed app
#
# Usage:
#   logs-app.sh <app-name> [--follow] [--tail N]
#==============================================================================

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <app-name> [--follow] [--tail N]"
    exit 1
fi

APP_NAME="$1"
shift

# Check if container exists
if ! docker ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
    echo "Error: Container '${APP_NAME}' not found"
    echo ""
    echo "Available apps:"
    docker ps --format "  - {{.Names}}" | grep -v '^traefik$\|^postgres\|^kong'
    exit 1
fi

# Forward all additional arguments to docker logs
docker logs "$APP_NAME" "$@"
