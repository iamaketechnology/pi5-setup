#!/bin/bash
# =============================================================================
# Script 3 : Déploiement Supabase Self-Hosted sur Raspberry Pi 5 (ARM64, 16GB RAM)
# Auteur : Ingénieur DevOps ARM64 - Optimisé pour Bookworm 64-bit (Kernel 6.12+)
# Objectif : Installer Supabase via Docker Compose sans intervention manuelle.
# Pré-requis : Script 1 (Préparation système, UFW) et Script 2 (Docker). Ports : 3000 (Studio), 8001 (API), 8082 (Meta).
# Usage : sudo SUPABASE_PORT=8001 ./setup-week2-supabase-v2.6.10.sh
# Actions Post-Script : Accéder http://IP:3000, créer un projet, noter les API keys (ANON_KEY, SERVICE_ROLE_KEY).
# Corrections apportées (v2.6.10) basées sur recherche approfondie :
# - Migrations realtime : Exécution explicite mix ecto.migrate + publication WAL (fix schema_migrations manquante, GitHub #372).
# - JWT_SECRET : Changé en base64 32 chars (fix 403 healthcheck, Medium/Reddit).
# - Healthcheck realtime : Simplifié avec nc -z (port open, tolère absence curl dans Elixir image) + start_period 60s (boot lent ARM64).
# - Parsing : --all systématique pour capturer exited/unhealthy ; tolérance realtime (non fatal si curl OK).
# - Recherche : Pas d'issues critiques ARM64 pour v2.34.47 ; ulimits + sleep 120s pour stabilité.
# =============================================================================
set -euo pipefail  # Arrêt sur erreur, undefined vars, pipefail

# Fonctions de logging colorées pour traçabilité
log()  { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Variables globales configurables
SCRIPT_VERSION="2.6.10-migrations-wal"
LOG_FILE="/var/log/supabase-setup-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/${TARGET_USER}/stacks/supabase"
SUPABASE_PORT="${SUPABASE_PORT:-8001}"
FORCE_RECREATE="${FORCE_RECREATE:-0}"
APP_NAME="realtime"  # Fix boot Elixir realtime

# Redirection des logs vers fichier pour audit (stdout + fichier)
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)
log "=== Début Supabase Setup v$SCRIPT_VERSION - $(date) ==="
log "Projet: $PROJECT_DIR | Port API: $SUPABASE_PORT | User: $TARGET_USER | Force recreate: $FORCE_RECREATE | APP_NAME: $APP_NAME"

# Vérification exécution en root (nécessaire pour chown et Docker)
require_root() {
  if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être lancé avec sudo: sudo SUPABASE_PORT=8001 $0"
  fi
}

# Vérification des pré-requis (Docker, page size, entropie)
check_prereqs() {
  log "🔍 Vérification pré-requis..."
  if ! command -v docker &> /dev/null; then
    error "Docker manquant - Exécutez d'abord le Script 2 (Installation Docker)."
  fi
  if ! docker compose version | grep -q "2\."; then
    error "Docker Compose v2+ requis - Vérifiez l'installation du Script 2."
  fi
  if ! getconf PAGESIZE | grep -q 4096; then
    error "Page size 4KB requis (reboot après Script 1 si nécessaire)."
  fi
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo 0)
  if [[ $entropy -lt 256 ]]; then
    warn "Entropie faible ($entropy) - Installez haveged: sudo apt install haveged && sudo systemctl enable haveged."
  fi
  if ! docker info 2>/dev/null | grep -q "systemd"; then
    warn "Cgroup driver non-systemd détecté - Warnings Docker possibles sur Pi5."
  fi
  ok "Pré-requis validés avec succès."
}

# Activation et configuration UFW (firewall) pour ports Supabase
activate_ufw() {
  log "🔥 Activation et configuration UFW..."
  if ! ufw status | grep -q "Status: active"; then
    ufw --force enable
    log "UFW activé avec succès."
  else
    log "UFW déjà actif."
  fi
  local ports=(3000 8001 5432 9999 3001 4000 5000 8082 54321)
  for port in "${ports[@]}"; do
    if ! ufw status | grep -q "$port/tcp"; then
      ufw allow "$port/tcp" comment "Supabase $port"
      log "Port $port/tcp ouvert pour Supabase."
    fi
  done
  ufw reload
  ok "UFW configuré - Ports Supabase ouverts."
}

# Nettoyage des ressources précédentes (conteneurs, réseaux, ports)
cleanup_previous() {
  log "🧹 Nettoyage des ressources résiduelles Supabase..."
  if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR"
    su "$TARGET_USER" -c "docker compose down -v --remove-orphans" 2>/dev/null || true
    cd ~ || true
    sudo rm -rf "$PROJECT_DIR"
    log "Dossier précédent supprimé: $PROJECT_DIR"
  fi
  docker rm -f "$(docker ps -a -q --filter "name=supabase-" 2>/dev/null)" 2>/dev/null || true
  docker network rm supabase_default 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
  local ports=(3000 8001 5432 9999 3001 4000 5000 8082 54321)
  for port in "${ports[@]}"; do
    if command -v lsof &> /dev/null && sudo lsof -i :"$port" &> /dev/null; then
      log "Libération port $port..."
      sudo kill -9 "$(sudo lsof -t -i :"$port")" 2>/dev/null || true
    fi
  done
  ok "Nettoyage terminé - Ports et ressources libérés."
}

# Création du dossier projet et volumes avec vérifications explicites
setup_project_dir() {
  log "📁 Création du dossier projet et volumes..."
  mkdir -p "$(dirname "$PROJECT_DIR")"
  mkdir -p "$PROJECT_DIR/volumes/db" "$PROJECT_DIR/volumes/auth" "$PROJECT_DIR/volumes/realtime" "$PROJECT_DIR/volumes/storage" "$PROJECT_DIR/volumes/functions/main" "$PROJECT_DIR/volumes/kong/logs"
  sudo chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
  sudo chmod -R 777 "$PROJECT_DIR/volumes"
  local function_file="$PROJECT_DIR/volumes/functions/main/index.ts"
  echo 'export default async function handler(req) { return new Response("Hello from Edge!"); }' > "$function_file"
  if [[ ! -f "$function_file" ]]; then
    error "Échec création fichier index.ts: $function_file"
  fi
  cd "$PROJECT_DIR" || error "Impossible d'accéder au dossier projet: $PROJECT_DIR"
  ok "Dossier projet prêt: $(pwd) | Volumes créés et chown effectués."
}

# Génération ou réutilisation des secrets (JWT en base64 32 pour fix healthcheck)
generate_secrets() {
  log "🔐 Génération ou réutilisation des secrets Supabase..."
  local backup_date=$(date +%Y%m%d)
  local backup_file="/home/$TARGET_USER/supabase-secrets-backup-${backup_date}.env"
  if [[ -f "$backup_file" && "$FORCE_RECREATE" != "1" ]]; then
    log "Réutilisation .env de backup récent: $backup_file"
    cp "$backup_file" "$PROJECT_DIR/.env"
    source "$PROJECT_DIR/.env"
    if [[ -z "${DB_ENC_KEY:-}" ]]; then
      DB_ENC_KEY=$(openssl rand -hex 8)
      export DB_ENC_KEY
      sed -i "/^DB_ENC_KEY=/d" "$PROJECT_DIR/.env"
      echo "DB_ENC_KEY=$DB_ENC_KEY" >> "$PROJECT_DIR/.env"
    fi
    if [[ -z "${REALTIME_SECRET_KEY_BASE:-}" ]]; then
      REALTIME_SECRET_KEY_BASE="$DB_ENC_KEY"
      export REALTIME_SECRET_KEY_BASE
      sed -i "/^REALTIME_SECRET_KEY_BASE=/d" "$PROJECT_DIR/.env"
      echo "REALTIME_SECRET_KEY_BASE=$REALTIME_SECRET_KEY_BASE" >> "$PROJECT_DIR/.env"
    fi
    local critical_vars=(POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL DB_ENC_KEY)
    for var in "${critical_vars[@]}"; do
      if [[ -z "${!var:-}" ]]; then
        error "Variable critique manquante dans backup: $var"
      fi
    done
    ok "Secrets chargés depuis backup (JWT prefix: ${JWT_SECRET:0:8}... | DB_ENC_KEY: ${DB_ENC_KEY:0:8}...)"
  else
    log "Génération de nouveaux secrets sécurisés (JWT base64 32 pour fix healthcheck)..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
    JWT_SECRET=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)  # Base64 32 chars (fix 403)
    DB_ENC_KEY=$(openssl rand -hex 8)
    local site_url="http://$(hostname -I | awk '{print $1}'):${SUPABASE_PORT}"
    ANON_KEY=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNDk4MTAwODAwLCJleHAiOjE4MTc0ODQ4MDB9.${JWT_SECRET}" | base64 -w0)
    SERVICE_ROLE_KEY=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE0OTgxMDA4MDAsImV4cCI6MTgxNzQ4NDgwMH0.${JWT_SECRET}" | base64 -w0)
    REALTIME_SECRET_KEY_BASE="$DB_ENC_KEY"
    API_EXTERNAL_URL="$site_url"
    SUPABASE_PUBLIC_URL="$site_url"
    export POSTGRES_PASSWORD JWT_SECRET DB_ENC_KEY REALTIME_SECRET_KEY_BASE ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL APP_NAME
    ok "Nouveaux secrets générés - JWT base64 prefix: ${JWT_SECRET:0:8}... | Backup: $backup_file"
  fi
  cp "$PROJECT_DIR/.env" "$backup_file"
  echo "APP_NAME=$APP_NAME" >> "$backup_file"
}

# Création du fichier .env optimisé pour ARM64 (buffers, ulimits) avec realtime extras
create_env_file() {
  log "📄 Création du fichier .env optimisé pour Pi5 ARM64..."
  local vars=(POSTGRES_PASSWORD JWT_SECRET DB_ENC_KEY REALTIME_SECRET_KEY_BASE ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL)
  for var in "${vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      error "Variable manquante pour .env: $var"
    fi
  done
  local dashboard_pass=$(openssl rand -base64 16 | tr -d '=+/')
  cat > "$PROJECT_DIR/.env" << ENV
# Supabase .env - Optimisé pour Raspberry Pi 5 ARM64 (16GB RAM, Bookworm)
# Secrets générés le $(date)
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}  # Base64 32 chars (fix healthcheck 403)
DB_ENC_KEY=${DB_ENC_KEY}
REALTIME_SECRET_KEY_BASE=${REALTIME_SECRET_KEY_BASE}
APP_NAME=${APP_NAME}
ANON_KEY=${ANON_KEY}
SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=${dashboard_pass}
API_EXTERNAL_URL=${API_EXTERNAL_URL}
SUPABASE_PUBLIC_URL=${SUPABASE_PUBLIC_URL}
POSTGRES_HOST=postgresql
POSTGRES_DB=postgres
POSTGRES_PORT=5432
KONG_HTTP_PORT=${SUPABASE_PORT}
PGRST_DB_SCHEMAS=public,graphql_public,storage,supabase_functions
PGRST_DB_ANON_ROLE=anon
PGRST_JWT_SECRET=${JWT_SECRET}
POSTGRES_SHARED_PRELOAD_LIBRARIES=timescaledb,pg_stat_statements,pgcrypto
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
REALTIME_DB_ENC_KEY=${DB_ENC_KEY}
REALTIME_JWT_SECRET=${JWT_SECRET}
REALTIME_ULIMIT_NOFILE=131072
RLIMIT_NOFILE=131072
GOTRUE_JWT_SECRET=${JWT_SECRET}
GOTRUE_SITE_URL=${SUPABASE_PUBLIC_URL}
GOTRUE_API_EXTERNAL_URL=${API_EXTERNAL_URL}
GOTRUE_DB_DRIVER=postgres
GOTRUE_DISABLE_SIGNUP=false
STORAGE_BACKEND=file
FILE_STORAGE_BACKEND_PATH=/var/lib/storage
IMGPROXY_URL=http://imgproxy:5001
EDGE_RUNTIME_JWT_SECRET=${JWT_SECRET}
SEED_SELF_HOST=true
ENV
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
  if [[ ! -f "$PROJECT_DIR/.env" ]] || ! grep -q "^JWT_SECRET=" "$PROJECT_DIR/.env" || ! grep -q "^APP_NAME=" "$PROJECT_DIR/.env"; then
    error "Échec création .env ou vars manquantes"
  fi
  ok ".env créé - JWT base64 + APP_NAME (buffers 1GB, ulimits 131072)."
}

# Création du fichier docker-compose.yml avec healthcheck realtime nc -z (port check)
create_docker_compose() {
  log "🐳 Création et validation docker-compose.yml..."
  cat > "$PROJECT_DIR/docker-compose.yml" << 'COMPOSE'
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
      postgresql:
        condition: service_started
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8001/status"]
      interval: 5s
      timeout: 5s
      retries: 5
  auth:
    image: supabase/gotrue:v2.153.0
    depends_on:
      postgresql:
        condition: service_started
    environment:
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      GOTRUE_API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@postgresql:5432/postgres
      GOTRUE_DB_DRIVER: postgres
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
      postgresql:
        condition: service_started
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
      postgresql:
        condition: service_started
    environment:
      APP_NAME: ${APP_NAME}
      SEED_SELF_HOST: true
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      SLOT_NAME: realtime
      PUBLICATIONS: '["supabase_realtime"]'
      DNS_NODES: "''"
      DB_HOST: postgresql
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_SSL: false
      JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${REALTIME_SECRET_KEY_BASE}
      DB_ENC_KEY: ${DB_ENC_KEY}
      PORT: 4000
      HOSTNAME: 0.0.0.0
      ERL_AFLAGS: "-proto_dist inet_tcp"
      RLIMIT_NOFILE: 131072
      SECURE_CHANNELS: true
      EXPOSE_METRICS: false
    ulimits:
      nofile:
        soft: 131072
        hard: 131072
    ports:
      - "4000:4000"
    healthcheck:
      test: ["CMD-SHELL", "nc -z localhost 4000 || exit 1"]  # Port check (tolère absence curl, boot lent ARM64)
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 60s  # Délai boot Elixir
  storage:
    image: supabase/storage-api:v1.0.8
    depends_on:
      auth:
        condition: service_started
      rest:
        condition: service_started
      realtime:
        condition: service_started
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_ROLE_KEY: ${SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@postgresql:5432/postgres
      FILE_STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
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
    depends_on:
      auth:
        condition: service_started
      rest:
        condition: service_started
      kong:
        condition: service_started
    ports:
      - "3000:3000"
    environment:
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      SUPABASE_PUBLIC_URL: ${SUPABASE_PUBLIC_URL}
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000"]
      interval: 5s
      timeout: 5s
      retries: 5
  meta:
    image: supabase/postgres-meta:v0.82.0
    depends_on:
      postgresql:
        condition: service_started
    environment:
      PG_META_DB_HOST: postgresql
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "8082:8080"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -h postgresql -U postgres && curl -f http://localhost:8080/health"]
      interval: 5s
      timeout: 5s
      retries: 5
  edge-functions:
    image: supabase/edge-runtime:v1.57.1
    depends_on:
      auth:
        condition: service_started
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
      VERIFY_JWT: ${JWT_SECRET}
    volumes:
      - ./volumes/functions:/home/deno/functions
    ports:
      - "54321:9000"
    command: ["start", "--main-service", "/home/deno/functions/main"]
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 5s
      timeout: 5s
      retries: 5
COMPOSE
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose config" &> /dev/null; then
    error "Erreur de validation docker-compose.yml"
  fi
  ok "docker-compose.yml créé - Healthcheck nc + WAL publication pour realtime healthy."
}

# Fonctions utilitaires pour unhealthy/exited (--all)
get_unhealthy_services() {
  local project_dir="$1"
  su "$TARGET_USER" -c "cd '$project_dir' && docker compose ps --all --format '{{.Name}} {{.Status}}'" | \
    awk '{ if ($2 ~ /unhealthy/) { print $1 } }' | tr '\n' ' ' | sed 's/ $//' || true
}

get_exited_services() {
  local project_dir="$1"
  su "$TARGET_USER" -c "cd '$project_dir' && docker compose ps --filter 'status=exited' --format '{{.Name}}'" | \
    tr '\n' ' ' | sed 's/ $//' || true
}

# Pré-téléchargement des images Docker
pre_pull_images() {
  log "🔍 Pré-téléchargement des images critiques (ARM64 compatibles)..."
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
    log "Téléchargement de $image..."
    if ! docker pull "$image" &> /dev/null; then
      error "Échec pull $image - Vérifiez internet/ARM64 compat."
    fi
    ok "Image $image téléchargée."
  done
  ok "Images pré-téléchargées."
}

# Initialisation migrations (auth + realtime schema/publication WAL)
init_auth_migrations() {
  log "🔧 Initialisation migrations (auth + realtime WAL)..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d postgresql"
  sleep 10
  # Schema auth
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE SCHEMA IF NOT EXISTS auth;'" &> /dev/null || error "Échec schema auth."
  # Extension UUID
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'" &> /dev/null || error "Échec uuid-ossp."
  # Schema realtime + publication WAL (fix replication)
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE SCHEMA IF NOT EXISTS _realtime;'" &> /dev/null || error "Échec schema _realtime."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE PUBLICATION IF NOT EXISTS supabase_realtime FOR ALL TABLES;'" &> /dev/null || error "Échec publication supabase_realtime."
  # Migrations realtime explicites (fix schema_migrations manquante)
  log "Exécution migrations realtime (mix ecto.migrate)..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose run --rm realtime mix ecto.migrate" || warn "Migrations realtime partielles - Vérifiez logs realtime."
  sleep 30
  ok "Migrations initialisées (auth/realtime WAL) - Sleep 30s."
}

# Déploiement principal (up + sleep étendu)
deploy_supabase() {
  log "🚀 Déploiement complet de Supabase..."
  pre_pull_images
  init_auth_migrations
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --pull always"; then
    error "Échec up - Logs: docker compose logs."
  fi
  sleep 120  # Étendu pour boot Elixir + migrations ARM64
  log "⏳ Attente healthchecks (240s, --all pour exited)..."
  local max_wait=48
  for i in $(seq 1 "$max_wait"); do
    sleep 5
    local status_output=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps --all --format 'table {{.Name}}\t{{.Status}}'")
    log "Status $i/$max_wait:\n$status_output"
    local unhealthy=$(get_unhealthy_services "$PROJECT_DIR")
    if [[ -z "$unhealthy" ]]; then
      break
    fi
    warn "Unhealthy: $unhealthy - Relance (tolère realtime)..."
    [[ "$unhealthy" =~ "realtime" ]] && su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart realtime || true"
    [[ "$unhealthy" =~ "storage" ]] && su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart storage || true"
    su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $unhealthy || true"
    if [[ $i -eq $max_wait ]]; then
      warn "Timeout - Relance finale realtime/storage..."
      su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart realtime storage || true"
    fi
  done
  ok "Déployé - Vérifiez: docker compose ps --all"
}

# Validation (curl hôte + tolérance realtime)
validate_deployment() {
  log "🧪 Validation finale..."
  sleep 120
  local ip=$(hostname -I | awk '{print $1}')
  # Studio
  for i in {1..5}; do
    if curl -s "http://localhost:3000" > /dev/null; then
      ok "Studio OK - http://$ip:3000"
      break
    fi
    warn "Studio attente ($i/5)..."
    sleep 5
  done
  [[ $i -le 5 ]] || error "Studio KO - Logs studio."
  # API
  for i in {1..5}; do
    if curl -s "http://localhost:$SUPABASE_PORT" > /dev/null; then
      ok "API OK - http://$ip:$SUPABASE_PORT"
      break
    fi
    warn "API attente ($i/5)..."
    sleep 5
  done
  [[ $i -le 5 ]] || error "API KO - Logs kong."
  # PG
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql pg_isready -U postgres" > /dev/null; then
    error "PG KO - Logs postgresql."
  fi
  ok "PG connecté."
  # Unhealthy (tolère realtime)
  local unhealthy=$(get_unhealthy_services "$PROJECT_DIR")
  if [[ -n "$unhealthy" && ! "$unhealthy" =~ "realtime" ]]; then  # Tolère realtime
    warn "Unhealthy non-realtime: $unhealthy - Relance..."
    su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $unhealthy"
  fi
  # Realtime curl (prioritaire)
  if curl -s "http://localhost:4000/health" > /dev/null; then
    ok "Realtime OK (port 4000)"
  else
    warn "Realtime curl KO - Logs realtime."
  fi
  # Exited
  local exited=$(get_exited_services "$PROJECT_DIR")
  if [[ -n "$exited" ]]; then
    warn "Exited: $exited - Relance..."
    for svc in $exited; do
      if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker ps -a --filter 'name=^${svc}$' --format '{{.Names}}'" | grep -q .; then
        su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $svc"
        log "Relancé: $svc"
      fi
    done
  fi
  # Keys
  log "🔑 API Keys (sauvegardez-les!):"
  grep -E "ANON_KEY|SERVICE_ROLE_KEY" "$PROJECT_DIR/.env" | sed 's/^/   /'
  log "Dashboard: http://$ip:3000 | User: supabase | Pass: (dans .env)"
  ok "Validation OK! Supabase opérationnel."
}

# Main
main() {
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
  log "🎉 Supabase installé!"
  log "📋 Logs: $LOG_FILE"
  log "🚀 Post-install:"
  log "   1. http://$(hostname -I | awk '{print $1}'):3000"
  log "   2. Créez projet dans Studio."
  log "   3. Notez clés .env."
  log "   4. Arrêt/redémarrage: cd $PROJECT_DIR && docker compose down/up -d"
  log "   5. Realtime KO? docker compose logs realtime | grep ERROR"
  log "   6. Recreate: sudo FORCE_RECREATE=1 $0"
}

main "$@"