#!/usr/bin/env bash
# =============================================================================
# Script 3 : Déploiement Supabase Self-Hosted sur Raspberry Pi 5 (ARM64, 16GB RAM)
# Auteur : Ingénieur DevOps ARM64 - Optimisé pour Bookworm 64-bit (Kernel 6.12+)
# Objectif : Installer Supabase via Docker Compose sans intervention manuelle.
# Pré-requis : Week1 (Docker, page size 4KB, UFW). Ports : 3000 (Studio), 8001 (API), 8082 (Meta).
# Usage : sudo SUPABASE_PORT=8001 ./setup-week2-supabase.sh
# Actions Post-Script : Accéder http://IP:3000, créer projet, noter API keys.
# Corrections :
# - v2.6.0 : Nettoyage auto, UFW auto, ports libres, images ARM64.
# - v2.6.1 : Validation API renforcée (60s attente, 3 retries).
# - v2.6.2 : Attente 90s pour Kong, relance auto des unhealthy, healthchecks stricts.
# =============================================================================
set -euo pipefail

# Fonctions de logging
log()  { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Variables globales
SCRIPT_VERSION="2.6.2-full-auto"
LOG_FILE="/var/log/supabase-setup-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/${TARGET_USER}/stacks/supabase"
SUPABASE_PORT="${SUPABASE_PORT:-8001}"
FORCE_RECREATE="${FORCE:-0}"

# Redirection logs
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)
log "=== Début Supabase Setup v$SCRIPT_VERSION - $(date) ==="
log "Projet: $PROJECT_DIR | Port API: $SUPABASE_PORT | User: $TARGET_USER"

# Vérif root
require_root() {
  [[ $EUID -eq 0 ]] || error "Lance avec sudo: sudo SUPABASE_PORT=8001 $0"
}

# Vérif pré-requis
check_prereqs() {
  log "🔍 Vérification pré-requis..."
  command -v docker >/dev/null || error "Docker manquant - Relance Week1"
  docker compose version | grep -q "2\." || error "Docker Compose v2 requis"
  getconf PAGESIZE | grep -q 4096 || error "Page size 4KB requis (reboot après Week1)"
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail)
  [[ $entropy -ge 256 ]] || warn "Entropie faible ($entropy) - Peut affecter JWT"
  docker info | grep -q "systemd" || warn "Cgroup driver non-systemd - Warnings possibles"
  ok "Pré-requis validés"
}

# Activation UFW
activate_ufw() {
  log "🔥 Activation UFW si inactif..."
  if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
    log "UFW activé"
  else
    log "UFW déjà actif"
  fi
  for port in 3000 8001 5432 9999 3001 4000 5000 8082 54321; do
    if ! ufw status | grep -q "$port/tcp"; then
      ufw allow $port/tcp comment "Supabase $port"
    fi
  done
  ufw reload
  ok "UFW configuré - Ports Supabase ouverts"
}

# Nettoyage préalable
cleanup_previous() {
  log "🧹 Nettoyage ressources résiduelles..."
  if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    su "$TARGET_USER" -c "docker compose down -v --remove-orphans" 2>/dev/null || true
    cd ~
    sudo rm -rf "$PROJECT_DIR"
  fi
  docker rm -f $(docker ps -a -q --filter "name=supabase-") 2>/dev/null || true
  docker network rm supabase_default 2>/dev/null || true
  for port in 3000 8001 5432 9999 3001 4000 5000 8082 54321; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      log "Libération port $port..."
      local pids=$(lsof -t -i :$port 2>/dev/null || netstat -tuln | grep ":$port" | awk '{print $NF}' | sort -u)
      for pid in $pids; do
        sudo kill -9 $pid 2>/dev/null || true
      done
    fi
  done
  ok "Nettoyage terminé - Ports libres"
}

# Création dossier projet
setup_project_dir() {
  log "📁 Création dossier projet..."
  mkdir -p "$(dirname "$PROJECT_DIR")"
  mkdir -p "$PROJECT_DIR/volumes/{db,auth,realtime,storage,functions}"
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
  cd "$PROJECT_DIR"
  ok "Dossier prêt: $(pwd)"
}

# Réutilisation ou génération secrets
generate_secrets() {
  log "🔐 Gestion des secrets..."
  local backup_file="/home/$TARGET_USER/supabase-secrets-backup-20250920.env"
  if [ -f "$backup_file" ] && [ "$FORCE_RECREATE" != "1" ]; then
    log "Réutilisation .env de backup..."
    cp "$backup_file" "$PROJECT_DIR/.env"
    source "$PROJECT_DIR/.env"
    if [ -z "${DB_ENC_KEY:-}" ]; then
      log "Génération DB_ENC_KEY..."
      export DB_ENC_KEY=$(openssl rand -hex 8)
    fi
    if [ -z "${REALTIME_SECRET_KEY_BASE:-}" ]; then
      log "Génération REALTIME_SECRET_KEY_BASE..."
      export REALTIME_SECRET_KEY_BASE="$DB_ENC_KEY"
    fi
    for var in POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL; do
      if [ -z "${!var:-}" ]; then
        error "Variable $var manquante dans backup .env"
      fi
    done
    ok "Secrets chargés depuis backup (JWT: ${JWT_SECRET:0:8}...)"
  else
    log "Génération nouveaux secrets..."
    local postgres_pass=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
    local jwt_secret=$(openssl rand -hex 32)
    local db_enc_key=$(openssl rand -hex 8)
    local site_url="http://$(hostname -I | awk '{print $1}'):${SUPABASE_PORT}"
    local anon_key=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNDk4MTAwODAwLCJleHAiOjE4MTc0ODQ4MDB9.${jwt_secret}" | base64 -w0)
    local service_key=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE0OTgxMDA4MDAsImV4cCI6MTgxNzQ4NDgwMH0.${jwt_secret}" | base64 -w0)

    export POSTGRES_PASSWORD="$postgres_pass"
    export JWT_SECRET="$jwt_secret"
    export DB_ENC_KEY="$db_enc_key"
    export REALTIME_SECRET_KEY_BASE="$db_enc_key"
    export ANON_KEY="$anon_key"
    export SERVICE_ROLE_KEY="$service_key"
    export API_EXTERNAL_URL="$site_url"
    export SUPABASE_PUBLIC_URL="$site_url"
    ok "Secrets générés - JWT: ${jwt_secret:0:8}... | Pass: ${postgres_pass:0:8}..."
  fi
}

# Création .env
create_env_file() {
  log "📄 Création .env optimisé..."
  for var in POSTGRES_PASSWORD JWT_SECRET DB_ENC_KEY REALTIME_SECRET_KEY_BASE ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL; do
    if [ -z "${!var:-}" ]; then
      error "Variable $var manquante"
    fi
  done
  cat > .env << ENV
# Supabase .env - Optimisé ARM64 Pi5 16GB (Bookworm)
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/')
API_EXTERNAL_URL=${API_EXTERNAL_URL}
SUPABASE_PUBLIC_URL=${SUPABASE_PUBLIC_URL}
POSTGRES_HOST=postgresql
POSTGRES_DB=postgres
POSTGRES_PORT=5432
KONG_HTTP_PORT=$SUPABASE_PORT
PGRST_DB_SCHEMAS=public,graphql_public,storage,supabase_functions
PGRST_DB_ANON_ROLE=anon
PGRST_JWT_SECRET=${JWT_SECRET}
POSTGRES_SHARED_PRELOAD_LIBRARIES=timescaledb,pg_stat_statements,pgcrypto
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
REALTIME_SECRET_KEY_BASE=${REALTIME_SECRET_KEY_BASE}
REALTIME_DB_ENC_KEY=${DB_ENC_KEY}
REALTIME_JWT_SECRET=${JWT_SECRET}
REALTIME_ULIMIT_NOFILE=65536
GOTRUE_JWT_SECRET=${JWT_SECRET}
GOTRUE_SITE_URL=${SUPABASE_PUBLIC_URL}
GOTRUE_DISABLE_SIGNUP=false
STORAGE_BACKEND=file
IMGPROXY_URL=http://imgproxy:5001
EDGE_RUNTIME_JWT_SECRET=${JWT_SECRET}
ENV
  chown "$TARGET_USER:$TARGET_USER" .env
  ok ".env créé - Optimisé pour 16GB RAM"
}

# Création docker-compose.yml
create_docker_compose() {
  log "🐳 Création docker-compose.yml..."
  cat > docker-compose.yml << 'COMPOSE'
services:
  postgresql:
    image: supabase/postgres:15.1.0.147
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./volumes/db:/var/lib/postgresql/data
    command: postgres -c config_file=/etc/postgresql/postgresql.conf
    deploy:
      resources:
        limits:
          memory: 2G
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
  kong:
    image: kong:3.4.0
    ports:
      - "${KONG_HTTP_PORT:-8001}:8000"
    environment:
      KONG_DATABASE: off
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_PREFIX: /var/run/kong_prefix
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    volumes:
      - ./volumes/kong:/var/run/kong_prefix
    depends_on:
      - postgresql
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/status"]
      interval: 5s
      timeout: 5s
      retries: 5
  auth:
    image: supabase/gotrue:v2.153.0
    depends_on:
      - postgresql
    environment:
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@postgresql:5432/postgres
    ports:
      - "9999:9999"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9999/health"]
      interval: 5s
      timeout: 5s
      retries: 5
  rest:
    image: postgrest/postgrest:v12.0.2
    depends_on:
      - postgresql
    environment:
      PGRST_DB_URI: postgres://postgres:${POSTGRES_PASSWORD}@postgresql:5432/postgres
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_SCHEMAS: public,storage
    ports:
      - "3001:3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 5s
      timeout: 5s
      retries: 5
  realtime:
    image: supabase/realtime:v2.34.47
    depends_on:
      - postgresql
    environment:
      DB_HOST: postgresql
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${REALTIME_SECRET_KEY_BASE}
      DB_ENC_KEY: ${DB_ENC_KEY}
      PORT: 4000
      HOSTNAME: 0.0.0.0
      ERL_AFLAGS: "-proto_dist inet_tcp"
    ulimits:
      nofile: 65536
    ports:
      - "4000:4000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 5s
      timeout: 5s
      retries: 5
  storage:
    image: supabase/storage-api:v1.0.8
    depends_on:
      - auth
      - rest
      - realtime
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_ROLE_KEY: ${SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@postgresql:5432/postgres
      FILE_STORAGE_BACKEND: file
      STORAGE_BACKEND: file
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
    ports:
      - "5000:5000"
    volumes:
      - ./volumes/storage:/var/lib/storage
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 5s
      timeout: 5s
      retries: 5
  studio:
    image: supabase/studio:latest
    ports:
      - "3000:3000"
    environment:
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      SUPABASE_PUBLIC_URL: ${SUPABASE_PUBLIC_URL}
    depends_on:
      - auth
      - rest
      - kong
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 5s
      timeout: 5s
      retries: 5
  meta:
    image: supabase/postgres-meta:v0.82.0
    depends_on:
      - postgresql
    environment:
      PG_META_DB_HOST: postgresql
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "8082:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 5s
      timeout: 5s
      retries: 5
  edge-functions:
    image: supabase/edge-runtime:v1.57.1
    depends_on:
      - auth
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SERVICE_ROLE_KEY}
      VERIFY_JWT: ${JWT_SECRET}
    volumes:
      - ./volumes/functions:/home/deno/functions
    ports:
      - "54321:9000"
    command: ["start", "--main-service", "hello"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 5s
      timeout: 5s
      retries: 5
COMPOSE
  chown "$TARGET_USER:$TARGET_USER" docker-compose.yml
  log "Validation docker-compose.yml..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose config" >/dev/null || error "Invalid docker-compose.yml"
  ok "Compose YAML créé - Images ARM64 + ulimits Realtime"
}

# Pré-pull images
pre_pull_images() {
  log "🔍 Pré-pull images critiques..."
  local images=(
    "supabase/postgres:15.1.0.147"
    "kong:3.4.0"
    "supabase/gotrue:v2.153.0"
    "postgrest/postgrest:v12.0.2"
    "supabase/realtime:v2.34.47"
    "supabase/storage-api:v1.0.8"
    "supabase/studio:latest"
    "supabase/postgres-meta:v0.82.0"
    "supabase/edge-runtime:v1.57.1"
  )
  for image in "${images[@]}"; do
    log "Pulling $image..."
    docker pull "$image" >/dev/null || error "Échec pull image: $image"
  done
  ok "Images pullées avec succès"
}

# Lancement services
deploy_supabase() {
  log "🚀 Déploiement Supabase..."
  pre_pull_images
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --pull always" || error "Échec compose up"
  log "Attente healthchecks (120s max)..."
  for i in {1..24}; do
    sleep 5
    if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps" | grep -q "healthy\|Up"; then
      if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps" | grep -q "unhealthy"; then
        break
      fi
      # Relancer services unhealthy
      log "Relance services unhealthy ($i/24)..."
      su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps --filter 'health=unhealthy' --format '{{.Names}}' | xargs -r docker compose restart"
    fi
    if [ $i -eq 24 ]; then
      error "Timeout healthchecks - Vérifie logs"
    fi
  done
  ok "Services lancés - Vérif: docker compose ps"
}

# Validation finale
validate_deployment() {
  log "🧪 Validation services..."
  sleep 90  # Attente renforcée pour Kong
  # Test Studio
  for i in {1..3}; do
    if curl -s http://localhost:3000 >/dev/null; then
      ok "Studio OK (3000)"
      break
    fi
    warn "Studio en attente ($i/3)..."
    sleep 5
  done
  [ $i -le 3 ] || error "Studio KO - Vérifie logs"
  # Test API (Kong)
  for i in {1..3}; do
    if curl -s http://localhost:$SUPABASE_PORT >/dev/null; then
      ok "API OK ($SUPABASE_PORT)"
      break
    fi
    warn "API en attente ($i/3)..."
    sleep 5
  done
  [ $i -le 3 ] || error "API KO - Vérifie logs"
  # Test PostgreSQL
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql pg_isready" >/dev/null && ok "PG OK" || error "PG KO"
  # Vérif healthchecks
  if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps" | grep -q "unhealthy"; then
    error "Conteneurs unhealthy - Vérifie logs"
  fi
  log "🔑 API Keys (sauve-les!):"
  grep -E "ANON_KEY|SERVICE_ROLE_KEY" .env | sed 's/^/   /'
  ok "Validation OK - Accès: http://$(hostname -I | awk '{print $1}'):$SUPABASE_PORT"
}

# Main
require_root
check_prereqs
activate_ufw
cleanup_previous
setup_project_dir
generate_secrets
create_env_file
create_docker_compose
deploy_supabase
validate_deployment

log "🎉 Supabase installé! Logs: $LOG_FILE"
log "Action Post-Install: Ouvre http://$(hostname -I | awk '{print $1}'):3000, crée projet, note clés."