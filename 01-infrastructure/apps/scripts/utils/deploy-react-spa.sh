#!/usr/bin/env bash
#==============================================================================
# PI5-APPS-STACK - DEPLOY REACT SPA
#==============================================================================
# Deploy a React SPA (static build) with Nginx + Traefik
#
# Usage:
#   deploy-react-spa.sh <app-name> <domain> [git-repo]
#
# Examples:
#   deploy-react-spa.sh landing landing.domain.com https://github.com/user/landing.git
#   deploy-react-spa.sh portfolio portfolio.me (uses existing dir)
#==============================================================================

set -euo pipefail

readonly APPS_DIR="/opt/apps"
readonly APPS_STACK_DIR="/opt/pi5-apps-stack"
readonly CONFIG_FILE="${APPS_STACK_DIR}/config/apps.conf"

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

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
    CERT_RESOLVER="letsencrypt"
fi

# Clone or pull repo
if [[ -n "$GIT_REPO" ]]; then
    if [[ -d "$APP_DIR" ]]; then
        log "Pulling latest changes..."
        cd "$APP_DIR" && git pull
    else
        log "Cloning repository..."
        git clone "$GIT_REPO" "$APP_DIR"
    fi
elif [[ ! -d "$APP_DIR" ]]; then
    error "App directory ${APP_DIR} does not exist and no git repo provided"
fi

cd "$APP_DIR"

# Copy templates
if [[ ! -f "Dockerfile" ]]; then
    log "Copying Dockerfile template..."
    cp "${APPS_STACK_DIR}/templates/react-spa/Dockerfile" ./
fi

if [[ ! -f "docker-compose.yml" ]]; then
    log "Copying docker-compose.yml template..."
    cp "${APPS_STACK_DIR}/templates/react-spa/docker-compose.yml" ./
fi

if [[ ! -f "nginx.conf" ]]; then
    log "Copying nginx.conf template..."
    cp "${APPS_STACK_DIR}/templates/react-spa/nginx.conf" ./
fi

# Generate build-time .env (for Vite/CRA)
log "Generating .env file..."
cat > .env <<EOF
# Build-time environment variables
VITE_SUPABASE_URL=${SUPABASE_URL:-}
VITE_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}

# For Create React App, use REACT_APP_ prefix instead
# REACT_APP_SUPABASE_URL=${SUPABASE_URL:-}
# REACT_APP_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
EOF

# Generate docker-compose .env
cat > .env.docker <<EOF
APP_NAME=${APP_NAME}
APP_DOMAIN=${APP_DOMAIN}
CERT_RESOLVER=${CERT_RESOLVER}
EOF

# Build and deploy
log "Building and deploying ${APP_NAME}..."
docker-compose --env-file .env.docker up -d --build

sleep 5

if docker ps --filter "name=${APP_NAME}" | grep -q "${APP_NAME}"; then
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║             REACT SPA DEPLOYED SUCCESSFULLY                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🚀 App:       ${APP_NAME}"
    echo "🌐 URL:       https://${APP_DOMAIN}"
    echo "📂 Directory: ${APP_DIR}"
    echo "📦 Type:      Static SPA (Nginx)"
    echo ""
    echo "🔧 Manage:"
    echo "   Logs:    docker logs -f ${APP_NAME}"
    echo "   Restart: docker restart ${APP_NAME}"
    echo "   Remove:  sudo bash ${APPS_STACK_DIR}/scripts/utils/remove-app.sh ${APP_NAME}"
    echo ""
else
    error "Deployment failed. Check logs: docker logs ${APP_NAME}"
fi
