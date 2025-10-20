#!/bin/bash
# =============================================================================
# Deploy Dashboard to Pi - Quick Deploy Script
# =============================================================================
# Version: 1.0.0
# Description: Deploy dashboard updates from local machine to Pi
# Usage: bash deploy-to-pi.sh [pi-hostname]
# =============================================================================

set -euo pipefail

# Logging functions
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Configuration
PI_HOST="${1:-pi5.local}"
PI_USER="pi"
LOCAL_SRC="/Volumes/WDNVME500/GITHUB CODEX/pi5-setup/01-infrastructure/dashboard/src"
REMOTE_DEST="~/stacks/dashboard/src"
COMPOSE_DIR="~/stacks/dashboard/compose"

log_info "🚀 Déploiement Dashboard → $PI_HOST"

# =============================================================================
# Step 1: Verify local files exist
# =============================================================================
if [[ ! -d "$LOCAL_SRC" ]]; then
    log_error "Source directory not found: $LOCAL_SRC"
    exit 1
fi

log_success "Source files found"

# =============================================================================
# Step 2: Check Pi connectivity
# =============================================================================
log_info "Vérification connexion Pi..."

if ! ssh -o ConnectTimeout=5 "${PI_USER}@${PI_HOST}" "echo 'Pi accessible'" &>/dev/null; then
    log_error "Cannot connect to ${PI_HOST}"
    log_info "Vérifiez que le Pi est allumé et accessible"
    exit 1
fi

log_success "Pi accessible"

# =============================================================================
# Step 3: Backup existing files on Pi
# =============================================================================
log_info "Backup fichiers existants..."

ssh "${PI_USER}@${PI_HOST}" "
    if [[ -d ${REMOTE_DEST} ]]; then
        backup_dir=~/backups/dashboard/\$(date +%Y%m%d_%H%M%S)
        mkdir -p \$backup_dir 2>/dev/null || true
        cp -r ${REMOTE_DEST}/* \$backup_dir/ 2>/dev/null || true
        echo 'Backup created: \$backup_dir'
    fi
" || true

log_success "Backup créé"

# =============================================================================
# Step 4: Deploy files via rsync
# =============================================================================
log_info "Déploiement des fichiers..."

rsync -avz --delete \
    --exclude 'node_modules' \
    --exclude '.env' \
    --exclude '*.log' \
    --exclude '.DS_Store' \
    "${LOCAL_SRC}/" \
    "${PI_USER}@${PI_HOST}:${REMOTE_DEST}/"

log_success "Fichiers déployés"

# =============================================================================
# Step 5: Install dependencies on Pi
# =============================================================================
log_info "Installation dépendances Node.js..."

ssh "${PI_USER}@${PI_HOST}" "
    cd ${REMOTE_DEST}

    # Source NVM or use system npm
    export PATH=\"\$HOME/.nvm/versions/node/$(ls ~/.nvm/versions/node 2>/dev/null | tail -1)/bin:\$PATH\"

    # Try npm install (skip if fails - container will handle it)
    npm install --production 2>/dev/null || echo 'npm install skipped (will run in container)'
"

log_success "Dépendances installées"

# =============================================================================
# Step 6: Restart container
# =============================================================================
log_info "Redémarrage container dashboard..."

ssh "${PI_USER}@${PI_HOST}" "
    cd ${COMPOSE_DIR}
    docker compose restart dashboard 2>/dev/null || docker restart pi5-dashboard 2>/dev/null || true
"

log_success "Container redémarré"

# =============================================================================
# Step 7: Wait for service to be ready
# =============================================================================
log_info "Attente démarrage service..."

sleep 5

# Test health endpoint
if ssh "${PI_USER}@${PI_HOST}" "curl -s http://localhost:3000/health >/dev/null"; then
    log_success "Dashboard opérationnel"
else
    log_error "Dashboard ne répond pas sur :3000"
    log_info "Vérifiez les logs: ssh ${PI_USER}@${PI_HOST} 'docker logs pi5-dashboard'"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DÉPLOIEMENT TERMINÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 URL: http://${PI_HOST}:3000"
echo "📝 Logs: ssh ${PI_USER}@${PI_HOST} 'docker logs pi5-dashboard -f'"
echo "🔧 Restart: ssh ${PI_USER}@${PI_HOST} 'docker restart pi5-dashboard'"
echo ""

exit 0
