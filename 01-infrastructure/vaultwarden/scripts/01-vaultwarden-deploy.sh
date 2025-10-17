#!/bin/bash
# =============================================================================
# Vaultwarden (Bitwarden) Deployment Script
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-17
# Author: PI5-SETUP Project
# Usage: sudo bash 01-vaultwarden-deploy.sh
# Description: Deploy self-hosted Bitwarden (Vaultwarden) password manager
# =============================================================================

set -euo pipefail

# Logging functions
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Auto-detect user
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être lancé avec sudo"
    exit 1
fi

# Variables
VAULTWARDEN_DIR="${USER_HOME}/stacks/vaultwarden"
VAULTWARDEN_DATA="${VAULTWARDEN_DIR}/data"
DOMAIN="${VAULTWARDEN_DOMAIN:-vaultwarden.local}"  # Configurable via env

log_info "Vaultwarden Deployment - Pi5 Setup"
log_info "User: ${CURRENT_USER}"
log_info "Installation path: ${VAULTWARDEN_DIR}"
log_info "Domain: ${DOMAIN}"

# =============================================================================
# Check if already installed
# =============================================================================

if docker ps --format '{{.Names}}' | grep -q "^vaultwarden$"; then
    log_success "Vaultwarden déjà installé et actif"
    docker ps --filter "name=vaultwarden" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    exit 0
fi

# =============================================================================
# Prerequisites
# =============================================================================

log_info "Vérification des prérequis..."

# Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker n'est pas installé. Exécuter d'abord le script Docker."
    exit 1
fi

# Check Docker Compose
if ! docker compose version &> /dev/null; then
    log_error "Docker Compose V2 n'est pas disponible"
    exit 1
fi

log_success "Prérequis OK"

# =============================================================================
# Create directory structure
# =============================================================================

log_info "Création de la structure de répertoires..."

mkdir -p "${VAULTWARDEN_DATA}"
mkdir -p "${VAULTWARDEN_DIR}/config"

# =============================================================================
# Generate admin token (secure)
# =============================================================================

log_info "Génération du token admin..."

# Generate strong admin token (argon2 hash)
ADMIN_TOKEN=$(openssl rand -base64 48)

log_info "📝 Token admin généré: ${ADMIN_TOKEN}"
log_info "⚠️  Sauvegardez ce token dans un endroit sûr!"
echo "${ADMIN_TOKEN}" > "${VAULTWARDEN_DIR}/admin-token.txt"
chmod 600 "${VAULTWARDEN_DIR}/admin-token.txt"

# =============================================================================
# Create Docker Compose file
# =============================================================================

log_info "Création du docker-compose.yml..."

cat > "${VAULTWARDEN_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped

    environment:
      # Domain configuration
      DOMAIN: "https://${DOMAIN}"

      # Admin panel access
      ADMIN_TOKEN: "${ADMIN_TOKEN}"

      # Database
      DATABASE_URL: "data/db.sqlite3"

      # Security
      SIGNUPS_ALLOWED: "true"  # Set to false after initial registration
      INVITATIONS_ALLOWED: "true"
      WEB_VAULT_ENABLED: "true"

      # SMTP (optional - configure for email)
      # SMTP_HOST: smtp.gmail.com
      # SMTP_FROM: your-email@gmail.com
      # SMTP_PORT: 587
      # SMTP_SECURITY: starttls
      # SMTP_USERNAME: your-email@gmail.com
      # SMTP_PASSWORD: your-app-password

      # Advanced
      LOG_LEVEL: "info"
      EXTENDED_LOGGING: "true"
      ROCKET_WORKERS: "10"

    volumes:
      - ./data:/data

    ports:
      - "8000:80"  # Web interface
      # - "8443:443"  # HTTPS (if using SSL)

    # Resource limits (optional)
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M

    networks:
      - vaultwarden

    # Healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/alive"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 30s

networks:
  vaultwarden:
    name: vaultwarden
    driver: bridge

EOF

log_success "docker-compose.yml créé"

# =============================================================================
# Create .env file
# =============================================================================

log_info "Création du fichier .env..."

cat > "${VAULTWARDEN_DIR}/.env" <<EOF
# Vaultwarden Configuration
DOMAIN=${DOMAIN}
ADMIN_TOKEN=${ADMIN_TOKEN}

# Change to 'false' after initial user registration
SIGNUPS_ALLOWED=true

# SMTP Configuration (optional)
# Uncomment and configure for email functionality
# SMTP_HOST=smtp.gmail.com
# SMTP_FROM=your-email@gmail.com
# SMTP_PORT=587
# SMTP_SECURITY=starttls
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password
EOF

chmod 600 "${VAULTWARDEN_DIR}/.env"
log_success ".env créé"

# =============================================================================
# Create backup script
# =============================================================================

log_info "Création du script de backup..."

cat > "${VAULTWARDEN_DIR}/backup.sh" <<'BACKUP_EOF'
#!/bin/bash
# Vaultwarden Backup Script

set -euo pipefail

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/vaultwarden-${TIMESTAMP}.tar.gz"

mkdir -p "${BACKUP_DIR}"

echo "🔄 Backing up Vaultwarden data..."

# Stop container briefly for consistent backup
docker compose stop vaultwarden

# Create backup
tar -czf "${BACKUP_FILE}" \
    --exclude='./backups' \
    --exclude='./data/icon_cache' \
    ./data/

# Restart container
docker compose start vaultwarden

# Keep only last 7 backups
ls -t "${BACKUP_DIR}"/vaultwarden-*.tar.gz | tail -n +8 | xargs -r rm --

echo "✅ Backup created: ${BACKUP_FILE}"
echo "📊 Backup size: $(du -h "${BACKUP_FILE}" | cut -f1)"
BACKUP_EOF

chmod +x "${VAULTWARDEN_DIR}/backup.sh"
log_success "Script de backup créé"

# =============================================================================
# Fix permissions
# =============================================================================

log_info "Configuration des permissions..."

chown -R "${CURRENT_USER}:${CURRENT_USER}" "${VAULTWARDEN_DIR}"

# =============================================================================
# Deploy
# =============================================================================

log_info "Déploiement de Vaultwarden..."

cd "${VAULTWARDEN_DIR}"

# Pull image
docker compose pull

# Start services
docker compose up -d

log_success "Vaultwarden déployé!"

# =============================================================================
# Wait for startup
# =============================================================================

log_info "Attente du démarrage (30s)..."
sleep 30

# =============================================================================
# Verify deployment
# =============================================================================

log_info "Vérification du déploiement..."

if docker ps --filter "name=vaultwarden" --filter "status=running" | grep -q "vaultwarden"; then
    log_success "✅ Vaultwarden est actif!"
else
    log_error "❌ Vaultwarden n'a pas démarré correctement"
    docker logs vaultwarden --tail 50
    exit 1
fi

# =============================================================================
# Display summary
# =============================================================================

CONTAINER_IP=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vaultwarden)
PI_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 VAULTWARDEN (BITWARDEN) INSTALLÉ AVEC SUCCÈS!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 ACCÈS WEB VAULT:"
echo "   • Local:         http://localhost:8000"
echo "   • Réseau local:  http://${PI_IP}:8000"
echo "   • Container IP:  http://${CONTAINER_IP}"
echo ""
echo "🔧 ADMIN PANEL:"
echo "   • URL:   http://${PI_IP}:8000/admin"
echo "   • Token: ${ADMIN_TOKEN}"
echo "   • Fichier: ${VAULTWARDEN_DIR}/admin-token.txt"
echo ""
echo "⚙️  CONFIGURATION:"
echo "   • Directory:  ${VAULTWARDEN_DIR}"
echo "   • Data:       ${VAULTWARDEN_DATA}"
echo "   • Config:     ${VAULTWARDEN_DIR}/.env"
echo "   • Logs:       docker logs vaultwarden"
echo ""
echo "📱 CLIENTS BITWARDEN:"
echo "   1. Télécharger app/extension Bitwarden officielle"
echo "   2. Lors de la connexion, cliquer \"Self-hosted\""
echo "   3. Server URL: http://${PI_IP}:8000"
echo "   4. Créer compte (ou se connecter si existant)"
echo ""
echo "🔒 SÉCURITÉ:"
echo "   ⚠️  IMPORTANT: Après avoir créé votre compte:"
echo "   1. Éditer ${VAULTWARDEN_DIR}/.env"
echo "   2. Changer SIGNUPS_ALLOWED=false"
echo "   3. Redémarrer: cd ${VAULTWARDEN_DIR} && docker compose restart"
echo ""
echo "💾 BACKUP:"
echo "   • Script:     ${VAULTWARDEN_DIR}/backup.sh"
echo "   • Commande:   cd ${VAULTWARDEN_DIR} && ./backup.sh"
echo "   • Location:   ${VAULTWARDEN_DIR}/backups/"
echo ""
echo "🔄 COMMANDES UTILES:"
echo "   • Status:     docker ps --filter name=vaultwarden"
echo "   • Logs:       docker logs -f vaultwarden"
echo "   • Restart:    cd ${VAULTWARDEN_DIR} && docker compose restart"
echo "   • Stop:       cd ${VAULTWARDEN_DIR} && docker compose stop"
echo "   • Update:     cd ${VAULTWARDEN_DIR} && docker compose pull && docker compose up -d"
echo ""
echo "🌐 ACCÈS DEPUIS MAC:"
echo "   • URL: http://${PI_IP}:8000"
echo "   • SSH Tunnel: ssh -L 8000:localhost:8000 pi@${PI_IP}"
echo "   • Puis ouvrir: http://localhost:8000"
echo ""
echo "📚 NEXT STEPS:"
echo "   1. Créer votre compte admin sur http://${PI_IP}:8000"
echo "   2. Configurer les apps Bitwarden (browser, mobile, desktop)"
echo "   3. Désactiver les inscriptions (SIGNUPS_ALLOWED=false)"
echo "   4. Configurer SMTP pour notifications email (optionnel)"
echo "   5. Configurer backups automatiques (cron)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
