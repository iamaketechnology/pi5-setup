#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - DEPLOY NEXT.JS APP
#==============================================================================
# Deploy a Next.js SSR app with automatic Traefik + Supabase integration
#
# Usage:
#   deploy-nextjs-app.sh <app-name> <domain> [git-repo]
#
# Examples:
#   deploy-nextjs-app.sh myapp app.domain.com https://github.com/user/myapp.git
#   deploy-nextjs-app.sh blog blog.domain.com (uses existing /opt/apps/blog/)
#==============================================================================

set -euo pipefail

# Configuration
readonly APPS_DIR="/opt/apps"
readonly APPS_STACK_DIR="/opt/pi5-apps-stack"
readonly CONFIG_FILE="${APPS_STACK_DIR}/config/apps.conf"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# Check arguments
if [[ $# -lt 2 ]]; then
    error "Usage: $0 <app-name> <domain> [git-repo]"
fi

APP_NAME="$1"
APP_DOMAIN="$2"
GIT_REPO="${3:-}"

APP_DIR="${APPS_DIR}/${APP_NAME}"

# Load global config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    warn "Global config not found, using defaults"
    CERT_RESOLVER="letsencrypt"
fi

# Check if app directory exists or needs to be cloned
if [[ -n "$GIT_REPO" ]]; then
    if [[ -d "$APP_DIR" ]]; then
        log "App directory exists, pulling latest changes..."
        cd "$APP_DIR" && git pull
    else
        log "Cloning repository..."
        git clone "$GIT_REPO" "$APP_DIR"
    fi
elif [[ ! -d "$APP_DIR" ]]; then
    error "App directory ${APP_DIR} does not exist and no git repo provided"
fi

cd "$APP_DIR"

# Copy Next.js template files if they don't exist
if [[ ! -f "Dockerfile" ]]; then
    log "Copying Dockerfile template..."
    cp "${APPS_STACK_DIR}/templates/nextjs-ssr/Dockerfile" ./
fi

if [[ ! -f "docker-compose.yml" ]]; then
    log "Copying docker-compose.yml template..."
    cp "${APPS_STACK_DIR}/templates/nextjs-ssr/docker-compose.yml" ./
fi

if [[ ! -f "next.config.js" ]] && [[ ! -f "next.config.mjs" ]]; then
    warn "next.config.js not found, copying optimized template..."
    cp "${APPS_STACK_DIR}/templates/nextjs-ssr/next.config.js" ./
fi

# Generate .env file
log "Generating .env file..."
cat > .env <<EOF
# App Configuration
APP_NAME=${APP_NAME}
APP_DOMAIN=${APP_DOMAIN}

# Traefik
CERT_RESOLVER=${CERT_RESOLVER}

# Supabase (auto-injected)
SUPABASE_URL=${SUPABASE_URL:-https://your-supabase-url.com}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-your-anon-key}
SUPABASE_SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY:-your-service-role-key}

# Node.js
NODE_ENV=production
EOF

# Build and deploy
log "Building and deploying ${APP_NAME}..."
docker-compose up -d --build

# Wait for health check
log "Waiting for app to become healthy..."
sleep 10

if docker ps --filter "name=${APP_NAME}" --filter "health=healthy" | grep -q "${APP_NAME}"; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║             NEXT.JS APP DEPLOYED SUCCESSFULLY                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🚀 App:       ${APP_NAME}"
    echo "🌐 URL:       https://${APP_DOMAIN}"
    echo "📂 Directory: ${APP_DIR}"
    echo ""
    echo "🔧 Manage:"
    echo "   Logs:    docker logs -f ${APP_NAME}"
    echo "   Restart: docker-compose -f ${APP_DIR}/docker-compose.yml restart"
    echo "   Stop:    docker-compose -f ${APP_DIR}/docker-compose.yml stop"
    echo "   Remove:  sudo bash ${APPS_STACK_DIR}/scripts/utils/remove-app.sh ${APP_NAME}"
    echo ""
else
    warn "App deployed but not healthy yet. Check logs: docker logs ${APP_NAME}"
fi
