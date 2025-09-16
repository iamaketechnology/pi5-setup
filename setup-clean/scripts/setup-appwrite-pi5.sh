#!/usr/bin/env bash
set -euo pipefail

# ========================================================================
# APPWRITE INSTALLATION SCRIPT FOR RASPBERRY PI 5
# ========================================================================
# Alternative backend à Supabase - Installation optimisée ARM64
# Compatible avec installation Supabase existante (ports différents)
#
# Version: 1.0.0-pi5-optimized
# Date: 16 Sept 2025
# Tested: Raspberry Pi 5 (8GB/16GB) - ARM64 - Pi OS 64-bit
# Appwrite Version: 1.7.4 (latest stable)
#
# Usage:
#   sudo ./setup-appwrite-pi5.sh
#   sudo ./setup-appwrite-pi5.sh --domain=appwrite.local --port=8081
#
# Post-installation:
#   http://[PI_IP]:8081 - Appwrite Console
#   Coexiste avec Supabase (ports 3000, 8001, etc.)
# ========================================================================

# === CONFIGURATION VARIABLES ===
SCRIPT_VERSION="1.0.0-pi5-optimized"
APPWRITE_VERSION="1.7.4"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/appwrite"
LOG_FILE="/var/log/pi5-setup-appwrite.log"

# Ports configuration (éviter conflits avec Supabase)
HTTP_PORT="${APPWRITE_HTTP_PORT:-8081}"
HTTPS_PORT="${APPWRITE_HTTPS_PORT:-8444}"
DOMAIN="${APPWRITE_DOMAIN:-localhost}"

# Database configuration
DB_ROOT_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
DB_NAME="appwrite"
DB_USER="appwrite"
DB_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

# Security keys
OPENSSL_KEY=$(openssl rand -hex 32)
JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)

# === LOGGING FUNCTIONS ===
log()  { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;36m[APPWRITE]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;33m[WARN]   \033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;32m[OK]     \033[0m $*" | tee -a "$LOG_FILE"; }
error() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - \033[1;31m[ERROR]  \033[0m $*" | tee -a "$LOG_FILE"; }

# === SYSTEM VALIDATION ===
require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0 [options]"
    echo "Options:"
    echo "  --domain=DOMAIN    Domain name (default: localhost)"
    echo "  --port=PORT        HTTP port (default: 8081)"
    echo "  --https-port=PORT  HTTPS port (default: 8444)"
    exit 1
  fi
}

validate_pi5_compatibility() {
  log "🔍 Validation compatibilité Raspberry Pi 5..."

  # Vérifier architecture ARM64
  if [[ "$(uname -m)" != "aarch64" ]]; then
    error "❌ Appwrite nécessite ARM64. Architecture détectée: $(uname -m)"
    exit 1
  fi

  # Vérifier RAM minimum (4GB requis)
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  if [[ $ram_gb -lt 4 ]]; then
    error "❌ Appwrite nécessite minimum 4GB RAM. Détecté: ${ram_gb}GB"
    exit 1
  fi

  # Vérifier OS 64-bit
  if [[ "$(getconf LONG_BIT)" != "64" ]]; then
    error "❌ Appwrite nécessite un OS 64-bit"
    exit 1
  fi

  ok "✅ Pi 5 compatible: ARM64, ${ram_gb}GB RAM, OS 64-bit"
}

check_docker_installed() {
  log "🐳 Vérification Docker..."

  if ! command -v docker &> /dev/null; then
    error "❌ Docker non installé. Installez d'abord avec Week 1 setup"
    exit 1
  fi

  if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    error "❌ Docker Compose non installé"
    exit 1
  fi

  # Vérifier que l'utilisateur peut utiliser Docker
  if ! sudo -u "$TARGET_USER" docker ps &> /dev/null; then
    log "   Ajout utilisateur $TARGET_USER au groupe docker..."
    usermod -aG docker "$TARGET_USER"
    warn "⚠️ Déconnexion/reconnexion nécessaire pour Docker"
  fi

  ok "✅ Docker installé et fonctionnel"
}

check_port_availability() {
  log "🔌 Vérification disponibilité ports..."

  local ports_to_check=("$HTTP_PORT" "$HTTPS_PORT")
  local blocked_ports=()

  for port in "${ports_to_check[@]}"; do
    if ss -tlnp | grep -q ":$port "; then
      blocked_ports+=("$port")
    fi
  done

  if [[ ${#blocked_ports[@]} -gt 0 ]]; then
    error "❌ Ports occupés: ${blocked_ports[*]}"
    log "   Ports Supabase utilisés: 3000, 8001, 5432, 54321"
    log "   Suggestion: Utilisez --port=8082 si 8081 est occupé"
    exit 1
  fi

  ok "✅ Ports disponibles: HTTP:$HTTP_PORT, HTTPS:$HTTPS_PORT"
}

# === INSTALLATION FUNCTIONS ===
create_project_structure() {
  log "📁 Création structure projet Appwrite..."

  # Créer répertoires
  sudo -u "$TARGET_USER" mkdir -p "$PROJECT_DIR"
  sudo -u "$TARGET_USER" mkdir -p "$PROJECT_DIR/data"
  sudo -u "$TARGET_USER" mkdir -p "$PROJECT_DIR/uploads"
  sudo -u "$TARGET_USER" mkdir -p "$PROJECT_DIR/certificates"

  ok "✅ Structure projet créée: $PROJECT_DIR"
}

generate_environment_file() {
  log "🔧 Génération fichier environnement..."

  cat > "$PROJECT_DIR/.env" << EOF
# Appwrite Configuration for Raspberry Pi 5
# Generated: $(date)
# Version: Appwrite $APPWRITE_VERSION

# === CORE CONFIGURATION ===
_APP_ENV=production
_APP_LOCALE=fr
_APP_CONSOLE_WHITELIST_ROOT=enabled
_APP_CONSOLE_WHITELIST_EMAILS=
_APP_CONSOLE_WHITELIST_IPS=
_APP_SYSTEM_EMAIL_NAME=Appwrite
_APP_SYSTEM_EMAIL_ADDRESS=team@appwrite.io
_APP_SYSTEM_SECURITY_EMAIL_ADDRESS=security@appwrite.io
_APP_SYSTEM_RESPONSE_FORMAT=

# === NETWORK & DOMAIN ===
_APP_DOMAIN=$DOMAIN
_APP_DOMAIN_TARGET=$DOMAIN:$HTTP_PORT
_APP_DOMAIN_FUNCTIONS=$DOMAIN:$HTTP_PORT
_APP_OPTIONS_ABUSE=enabled
_APP_OPTIONS_FORCE_HTTPS=disabled
_APP_OPENSSL_KEY_V1=$OPENSSL_KEY

# === DATABASE CONFIGURATION ===
_APP_DB_HOST=mariadb
_APP_DB_PORT=3306
_APP_DB_SCHEMA=$DB_NAME
_APP_DB_USER=$DB_USER
_APP_DB_PASS=$DB_PASSWORD
_APP_DB_ROOT_PASS=$DB_ROOT_PASSWORD

# === REDIS CONFIGURATION ===
_APP_REDIS_HOST=redis
_APP_REDIS_PORT=6379
_APP_REDIS_USER=
_APP_REDIS_PASS=

# === SECURITY ===
_APP_JWT_SECRET=$JWT_SECRET
_APP_USAGE_STATS=enabled

# === STORAGE LIMITS (PI 5 OPTIMIZED) ===
_APP_STORAGE_LIMIT=30000000
_APP_STORAGE_PREVIEW_LIMIT=20000000
_APP_STORAGE_ANTIVIRUS=disabled
_APP_STORAGE_ANTIVIRUS_HOST=clamav
_APP_STORAGE_ANTIVIRUS_PORT=3310

# === FUNCTIONS (PI 5 OPTIMIZED) ===
_APP_FUNCTIONS_SIZE_LIMIT=30000000
_APP_FUNCTIONS_TIMEOUT=900
_APP_FUNCTIONS_BUILD_TIMEOUT=900
_APP_FUNCTIONS_CONTAINERS=10
_APP_FUNCTIONS_CPUS=2
_APP_FUNCTIONS_MEMORY=1024
_APP_FUNCTIONS_MEMORY_SWAP=1024
_APP_FUNCTIONS_RUNTIMES=node-18.0,php-8.1,python-3.10,ruby-3.1

# === LOGGING ===
_APP_LOGGING_PROVIDER=
_APP_LOGGING_CONFIG=

# === PORTS CONFIGURATION ===
HTTP_PORT=$HTTP_PORT
HTTPS_PORT=$HTTPS_PORT

# === MAINTENANCE ===
_APP_MAINTENANCE_INTERVAL=86400
_APP_MAINTENANCE_RETENTION_EXECUTION=1209600
_APP_MAINTENANCE_RETENTION_CACHE=2592000
_APP_MAINTENANCE_RETENTION_ABUSE=86400
_APP_MAINTENANCE_RETENTION_AUDIT=1209600
EOF

  # Sécuriser le fichier
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
  chmod 600 "$PROJECT_DIR/.env"

  ok "✅ Fichier .env généré avec clés sécurisées"
}

create_docker_compose() {
  log "🐳 Création configuration Docker Compose..."

  cat > "$PROJECT_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  appwrite:
    image: appwrite/appwrite:1.7.4
    container_name: appwrite
    restart: unless-stopped
    networks:
      - appwrite
    volumes:
      - appwrite-uploads:/storage/uploads:rw
      - appwrite-cache:/storage/cache:rw
      - appwrite-config:/storage/config:rw
      - appwrite-certificates:/storage/certificates:rw
      - appwrite-functions:/storage/functions:rw
    depends_on:
      - mariadb
      - redis
    environment:
      - _APP_ENV
      - _APP_LOCALE
      - _APP_CONSOLE_WHITELIST_ROOT
      - _APP_CONSOLE_WHITELIST_EMAILS
      - _APP_CONSOLE_WHITELIST_IPS
      - _APP_SYSTEM_EMAIL_NAME
      - _APP_SYSTEM_EMAIL_ADDRESS
      - _APP_SYSTEM_SECURITY_EMAIL_ADDRESS
      - _APP_SYSTEM_RESPONSE_FORMAT
      - _APP_DOMAIN
      - _APP_DOMAIN_TARGET
      - _APP_DOMAIN_FUNCTIONS
      - _APP_OPTIONS_ABUSE
      - _APP_OPTIONS_FORCE_HTTPS
      - _APP_OPENSSL_KEY_V1
      - _APP_DB_HOST
      - _APP_DB_PORT
      - _APP_DB_SCHEMA
      - _APP_DB_USER
      - _APP_DB_PASS
      - _APP_DB_ROOT_PASS
      - _APP_REDIS_HOST
      - _APP_REDIS_PORT
      - _APP_REDIS_USER
      - _APP_REDIS_PASS
      - _APP_JWT_SECRET
      - _APP_USAGE_STATS
      - _APP_STORAGE_LIMIT
      - _APP_STORAGE_PREVIEW_LIMIT
      - _APP_STORAGE_ANTIVIRUS
      - _APP_STORAGE_ANTIVIRUS_HOST
      - _APP_STORAGE_ANTIVIRUS_PORT
      - _APP_FUNCTIONS_SIZE_LIMIT
      - _APP_FUNCTIONS_TIMEOUT
      - _APP_FUNCTIONS_BUILD_TIMEOUT
      - _APP_FUNCTIONS_CONTAINERS
      - _APP_FUNCTIONS_CPUS
      - _APP_FUNCTIONS_MEMORY
      - _APP_FUNCTIONS_MEMORY_SWAP
      - _APP_FUNCTIONS_RUNTIMES
      - _APP_LOGGING_PROVIDER
      - _APP_LOGGING_CONFIG
      - _APP_MAINTENANCE_INTERVAL
      - _APP_MAINTENANCE_RETENTION_EXECUTION
      - _APP_MAINTENANCE_RETENTION_CACHE
      - _APP_MAINTENANCE_RETENTION_ABUSE
      - _APP_MAINTENANCE_RETENTION_AUDIT
    ports:
      - "${HTTP_PORT}:80"
      - "${HTTPS_PORT}:443"

  mariadb:
    image: mariadb:10.7
    container_name: appwrite-mariadb
    restart: unless-stopped
    networks:
      - appwrite
    volumes:
      - appwrite-mariadb:/var/lib/mysql:rw
    environment:
      - MYSQL_ROOT_PASSWORD=${_APP_DB_ROOT_PASS}
      - MYSQL_DATABASE=${_APP_DB_SCHEMA}
      - MYSQL_USER=${_APP_DB_USER}
      - MYSQL_PASSWORD=${_APP_DB_PASS}
    command: 'mysqld --innodb-flush-method=fsync'

  redis:
    image: redis:7.0-alpine
    container_name: appwrite-redis
    restart: unless-stopped
    networks:
      - appwrite
    volumes:
      - appwrite-redis:/data:rw
    command: redis-server --appendonly yes --replica-read-only no --requirepass ${_APP_REDIS_PASS}

networks:
  appwrite:
    name: appwrite

volumes:
  appwrite-mariadb:
  appwrite-redis:
  appwrite-cache:
  appwrite-uploads:
  appwrite-certificates:
  appwrite-config:
  appwrite-functions:
EOF

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"

  ok "✅ Configuration Docker Compose créée"
}

optimize_for_pi5() {
  log "⚡ Optimisations spécifiques Raspberry Pi 5..."

  # Créer configuration Docker daemon si nécessaire
  if [[ ! -f /etc/docker/daemon.json ]]; then
    cat > /etc/docker/daemon.json << 'EOF'
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
EOF
    systemctl restart docker
    ok "   ✅ Docker daemon optimisé pour Pi 5"
  fi

  # Optimisations mémoire pour Pi 5
  cat > "$PROJECT_DIR/pi5-optimizations.conf" << 'EOF'
# Pi 5 Optimizations for Appwrite
# Add to docker-compose.yml under appwrite service if needed

deploy:
  resources:
    limits:
      cpus: '3.0'
      memory: 2G
    reservations:
      cpus: '1.0'
      memory: 512M
EOF

  ok "✅ Optimisations Pi 5 appliquées"
}

# === INSTALLATION PROCESS ===
install_appwrite() {
  log "🚀 Démarrage services Appwrite..."

  cd "$PROJECT_DIR"

  # Exporter variables d'environnement
  set -a
  source .env
  set +a

  # Démarrer les services
  log "   Démarrage MariaDB et Redis..."
  sudo -u "$TARGET_USER" docker compose up -d mariadb redis

  # Attendre que la base soit prête
  log "   Attente initialisation base de données..."
  for i in {1..30}; do
    if sudo -u "$TARGET_USER" docker compose exec -T mariadb mysqladmin ping -h localhost --silent; then
      break
    fi
    sleep 2
  done

  # Démarrer Appwrite
  log "   Démarrage Appwrite (peut prendre quelques minutes)..."
  sudo -u "$TARGET_USER" docker compose up -d appwrite

  # Attendre que le service soit prêt
  log "   Vérification santé des services..."
  for i in {1..60}; do
    if curl -s "http://localhost:$HTTP_PORT/v1/health" | grep -q "OK"; then
      break
    fi
    sleep 3
  done

  ok "✅ Appwrite démarré avec succès"
}

create_management_scripts() {
  log "📜 Création scripts de gestion..."

  # Script de démarrage
  cat > "$PROJECT_DIR/start-appwrite.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Démarrage Appwrite..."
docker compose up -d
echo "✅ Appwrite démarré. Console: http://localhost:8081"
EOF

  # Script d'arrêt
  cat > "$PROJECT_DIR/stop-appwrite.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "🛑 Arrêt Appwrite..."
docker compose down
echo "✅ Appwrite arrêté"
EOF

  # Script de mise à jour
  cat > "$PROJECT_DIR/update-appwrite.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "⬇️ Mise à jour Appwrite..."
docker compose pull
docker compose up -d
echo "✅ Appwrite mis à jour"
EOF

  # Script de logs
  cat > "$PROJECT_DIR/logs-appwrite.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "📊 Logs Appwrite..."
docker compose logs -f --tail=100
EOF

  # Rendre exécutables
  chmod +x "$PROJECT_DIR"/*.sh
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"/*.sh

  ok "✅ Scripts de gestion créés"
}

# === FIREWALL CONFIGURATION ===
configure_firewall() {
  log "🔥 Configuration pare-feu..."

  # Vérifier si UFW est installé et actif
  if command -v ufw &> /dev/null; then
    ufw allow "$HTTP_PORT/tcp" comment "Appwrite HTTP"
    ufw allow "$HTTPS_PORT/tcp" comment "Appwrite HTTPS"
    ufw reload
    ok "   ✅ Ports $HTTP_PORT et $HTTPS_PORT ouverts"
  else
    warn "   ⚠️ UFW non installé - Configurez manuellement le pare-feu"
  fi

  ok "✅ Configuration pare-feu terminée"
}

# === VALIDATION & HEALTH CHECKS ===
run_health_checks() {
  log "🏥 Vérification santé installation..."

  local checks_passed=0
  local total_checks=4

  # Test 1: Services Docker actifs
  if sudo -u "$TARGET_USER" docker compose ps | grep -q "Up"; then
    ok "   ✅ Services Docker actifs"
    ((checks_passed++))
  else
    warn "   ⚠️ Problème services Docker"
  fi

  # Test 2: Base de données accessible
  if sudo -u "$TARGET_USER" docker compose exec -T mariadb mysqladmin ping -h localhost --silent; then
    ok "   ✅ Base de données accessible"
    ((checks_passed++))
  else
    warn "   ⚠️ Base de données inaccessible"
  fi

  # Test 3: API Appwrite répond
  if curl -s "http://localhost:$HTTP_PORT/v1/health" | grep -q "OK"; then
    ok "   ✅ API Appwrite répond"
    ((checks_passed++))
  else
    warn "   ⚠️ API Appwrite ne répond pas"
  fi

  # Test 4: Console accessible
  if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HTTP_PORT" | grep -q "200"; then
    ok "   ✅ Console Appwrite accessible"
    ((checks_passed++))
  else
    warn "   ⚠️ Console Appwrite inaccessible"
  fi

  if [[ $checks_passed -eq $total_checks ]]; then
    ok "✅ Installation réussie ($checks_passed/$total_checks tests passés)"
    return 0
  else
    warn "⚠️ Installation partielle ($checks_passed/$total_checks tests passés)"
    return 1
  fi
}

# === BANNER & SUMMARY ===
show_banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                    🚀 APPWRITE PI 5 INSTALLER                   ║"
  echo "║                                                                  ║"
  echo "║     Alternative backend à Supabase - Optimisé Raspberry Pi 5    ║"
  echo "║                     Version: $SCRIPT_VERSION                     ║"
  echo "║                   Appwrite Version: $APPWRITE_VERSION                        ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
}

show_installation_summary() {
  local pi_ip=$(hostname -I | awk '{print $1}')

  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "🎉 INSTALLATION APPWRITE TERMINÉE"
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
  echo "📋 **Accès aux services** :"
  echo ""
  echo "🌐 **Appwrite Console** :"
  echo "   http://localhost:$HTTP_PORT"
  echo "   http://$pi_ip:$HTTP_PORT"
  echo ""
  echo "🔗 **API Endpoint** :"
  echo "   http://localhost:$HTTP_PORT/v1"
  echo "   http://$pi_ip:$HTTP_PORT/v1"
  echo ""
  echo "📁 **Répertoire installation** :"
  echo "   $PROJECT_DIR"
  echo ""
  echo "🔧 **Scripts de gestion** :"
  echo "   ./start-appwrite.sh    - Démarrer Appwrite"
  echo "   ./stop-appwrite.sh     - Arrêter Appwrite"
  echo "   ./update-appwrite.sh   - Mettre à jour"
  echo "   ./logs-appwrite.sh     - Voir les logs"
  echo ""
  echo "⚙️ **Gestion Docker** :"
  echo "   cd $PROJECT_DIR"
  echo "   docker compose ps      - État des services"
  echo "   docker compose logs -f - Logs en temps réel"
  echo "   docker compose down    - Arrêter tous les services"
  echo "   docker compose up -d   - Démarrer tous les services"
  echo ""
  echo "🔒 **Informations sécurité** :"
  echo "   - Database password: Généré aléatoirement (voir .env)"
  echo "   - JWT Secret: Généré aléatoirement"
  echo "   - OpenSSL Key: Généré aléatoirement"
  echo ""
  echo "🔗 **Coexistence avec Supabase** :"
  echo "   - Appwrite: Ports $HTTP_PORT, $HTTPS_PORT"
  echo "   - Supabase: Ports 3000, 8001, 5432, 54321"
  echo "   - Pas de conflit de ports"
  echo ""
  echo "🏠 **Premier usage** :"
  echo "   1. Ouvrir http://$pi_ip:$HTTP_PORT"
  echo "   2. Créer votre compte administrateur"
  echo "   3. Créer votre premier projet"
  echo "   4. Configurer vos collections et authentification"
  echo ""
  echo "📚 **Documentation** :"
  echo "   - Documentation officielle: https://appwrite.io/docs"
  echo "   - Guides de démarrage: https://appwrite.io/docs/quick-starts"
  echo "   - Console API: http://$pi_ip:$HTTP_PORT/console"
  echo ""
  echo "💡 **Arrêt/Démarrage pour économiser ressources** :"
  echo "   cd $PROJECT_DIR && ./stop-appwrite.sh"
  echo "   cd $PROJECT_DIR && ./start-appwrite.sh"
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
}

# === ARGUMENT PARSING ===
parse_arguments() {
  for arg in "$@"; do
    case $arg in
      --domain=*)
        DOMAIN="${arg#*=}"
        shift
        ;;
      --port=*)
        HTTP_PORT="${arg#*=}"
        shift
        ;;
      --https-port=*)
        HTTPS_PORT="${arg#*=}"
        shift
        ;;
      *)
        # Option inconnue
        ;;
    esac
  done
}

# === MAIN FUNCTION ===
main() {
  require_root
  parse_arguments "$@"
  show_banner

  log "🎯 Installation Appwrite pour: $TARGET_USER"
  log "   Domain: $DOMAIN"
  log "   HTTP Port: $HTTP_PORT"
  log "   HTTPS Port: $HTTPS_PORT"
  log "   Project Dir: $PROJECT_DIR"

  # Validations système
  validate_pi5_compatibility
  check_docker_installed
  check_port_availability

  # Installation
  create_project_structure
  generate_environment_file
  create_docker_compose
  optimize_for_pi5
  configure_firewall
  install_appwrite
  create_management_scripts

  # Vérifications finales
  if run_health_checks; then
    show_installation_summary

    # Retour au répertoire utilisateur
    cd "/home/$TARGET_USER" 2>/dev/null || true

    ok "🎉 Installation Appwrite terminée avec succès!"
    log "📊 Logs d'installation sauvegardés: $LOG_FILE"
  else
    error "❌ Installation terminée avec des problèmes"
    log "🔍 Consultez les logs: $LOG_FILE"
    log "🔍 Debug: cd $PROJECT_DIR && docker compose logs"
    exit 1
  fi
}

main "$@"