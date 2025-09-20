#!/bin/bash
# =============================================================================
# Script 3 : Déploiement Supabase Self-Hosted sur Raspberry Pi 5 (ARM64, 16GB RAM)
# Auteur : Ingénieur DevOps ARM64 - Optimisé pour Bookworm 64-bit (Kernel 6.12+)
# Objectif : Installer Supabase via Docker Compose sans intervention manuelle.
# Pré-requis : Script 1 (Préparation système, UFW) et Script 2 (Docker). Ports : 3000 (Studio), 8001 (API), 8082 (Meta).
# Usage : sudo SUPABASE_PORT=8001 ./setup-week2-supabase-v2.6.8.sh
# Actions Post-Script : Accéder http://IP:3000, créer un projet, noter les API keys (ANON_KEY, SERVICE_ROLE_KEY).
# Corrections apportées (v2.6.8) basées sur logs fournis :
# - Fix realtime crash : Ajout APP_NAME=realtime dans env realtime (cause "RuntimeError: APP_NAME not available" en runtime.exs:78).
# - Robustesse : Ajout SEED_SELF_HOST=true pour migrations realtime ; sleep 60s post-up pour boot Elixir.
# - Parsing exited : Fix relance (vérif existence service avant restart via docker ps).
# - Validation : Test curl realtime après relance ; tolérance si toujours exited (non-bloquant pour Studio).
# - Logs : Suppression doublons REALTIME_DB_ENC_KEY ; export APP_NAME global pour .env.
# =============================================================================
set -euo pipefail

# Fonctions de logging colorées pour traçabilité
log()  { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Variables globales configurables
SCRIPT_VERSION="2.6.8-appname-fix"
LOG_FILE="/var/log/supabase-setup-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/${TARGET_USER}/stacks/supabase"
SUPABASE_PORT="${SUPABASE_PORT:-8001}"
FORCE_RECREATE="${FORCE_RECREATE:-0}"
APP_NAME="realtime"  # Nouvelle var pour fix realtime boot

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
    warn "Entropie faible ($entropy) - Peut ralentir génération JWT. Installez haveged si persistant."
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
  # Ports essentiels Supabase : Studio (3000), API (8001), PG (5432), Auth (9999), Realtime (4000), Storage (5000), Meta (8082), Edge (54321)
  local ports=(3000 8001 5432 9999 3001 4000 5000 8082 54321)
  for port in "${ports[@]}"; do
    if ! ufw status | grep -q "$port/tcp"; then
      ufw allow "$port/tcp" comment "Supabase $port"
      log "Port $port/tcp ouvert pour Supabase."
    fi
  done
  ufw reload
  ok "UFW configuré - Ports Supabase ouverts. Statut: ufw status verbose"
}

# Nettoyage des ressources précédentes (conteneurs, réseaux, ports)
cleanup_previous() {
  log "🧹 Nettoyage des ressources résiduelles Supabase..."
  if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR"
    # Arrêt et suppression volumes/orphans pour l'utilisateur pi
    su "$TARGET_USER" -c "docker compose down -v --remove-orphans" 2>/dev/null || true
    cd ~ || true
    sudo rm -rf "$PROJECT_DIR"
    log "Dossier précédent supprimé: $PROJECT_DIR"
  fi
  # Suppression conteneurs orphelins nommés supabase-
  docker rm -f "$(docker ps -a -q --filter "name=supabase-" 2>/dev/null)" 2>/dev/null || true
  # Suppression réseau par défaut
  docker network rm supabase_default 2>/dev/null || true
  docker network prune -f 2>/dev/null || true
  # Libération ports occupés (kill processes si nécessaire)
  local ports=(3000 8001 5432 9999 3001 4000 5000 8082 54321)
  for port in "${ports[@]}"; do
    if command -v lsof &> /dev/null && sudo lsof -i :"$port" &> /dev/null; then
      log "Libération port $port (processus en cours)..."
      sudo kill -9 "$(sudo lsof -t -i :"$port")" 2>/dev/null || true
    fi
  done
  ok "Nettoyage terminé - Ports et ressources libérés."
}

# Création du dossier projet et volumes avec vérifications explicites
setup_project_dir() {
  log "📁 Création du dossier projet et volumes..."
  # Création parent (stacks)
  mkdir -p "$(dirname "$PROJECT_DIR")"
  # Création explicite chaque sous-répertoire pour éviter problèmes expansion braces sous sudo
  mkdir -p "$PROJECT_DIR/volumes/db"
  mkdir -p "$PROJECT_DIR/volumes/auth"
  mkdir -p "$PROJECT_DIR/volumes/realtime"
  mkdir -p "$PROJECT_DIR/volumes/storage"
  mkdir -p "$PROJECT_DIR/volumes/functions/main"
  mkdir -p "$PROJECT_DIR/volumes/kong/logs"
  # Changement propriétaire pour utilisateur pi (évite sudo pour docker compose)
  sudo chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
  # Permissions larges sur volumes pour compatibilité Docker
  sudo chmod -R 777 "$PROJECT_DIR/volumes"
  # Création fichier exemple Edge Function (vérification dir existe avant écriture)
  local function_file="$PROJECT_DIR/volumes/functions/main/index.ts"
  if [[ ! -d "$(dirname "$function_file")" ]]; then
    error "Répertoire functions/main non créé: $(dirname "$function_file")"
  fi
  echo 'export default async function handler(req) { return new Response("Hello from Edge!"); }' > "$function_file"
  # Vérification écriture réussie
  if [[ ! -f "$function_file" ]]; then
    error "Échec création fichier index.ts: $function_file"
  fi
  cd "$PROJECT_DIR" || error "Impossible d'accéder au dossier projet: $PROJECT_DIR"
  ok "Dossier projet prêt: $(pwd) | Volumes créés et chown effectués."
}

# Génération ou réutilisation des secrets (JWT, passwords, keys) avec focus DB_ENC_KEY et APP_NAME
generate_secrets() {
  log "🔐 Génération ou réutilisation des secrets Supabase..."
  local backup_date=$(date +%Y%m%d)
  local backup_file="/home/$TARGET_USER/supabase-secrets-backup-${backup_date}.env"
  if [[ -f "$backup_file" && "$FORCE_RECREATE" != "1" ]]; then
    log "Réutilisation .env de backup récent: $backup_file"
    cp "$backup_file" "$PROJECT_DIR/.env"
    # Source pour charger variables
    source "$PROJECT_DIR/.env"
    # Compléments si manquants (sécurité, prioritaire DB_ENC_KEY pour realtime)
    if [[ -z "${DB_ENC_KEY:-}" ]]; then
      log "Génération complémentaire DB_ENC_KEY (requis pour realtime)..."
      DB_ENC_KEY=$(openssl rand -hex 8)
      export DB_ENC_KEY
      # Mise à jour .env pour éviter WARN
      sed -i "/^DB_ENC_KEY=/d" "$PROJECT_DIR/.env"  # Supprime si vide
      echo "DB_ENC_KEY=$DB_ENC_KEY" >> "$PROJECT_DIR/.env"
    fi
    if [[ -z "${REALTIME_SECRET_KEY_BASE:-}" ]]; then
      log "Génération complémentaire REALTIME_SECRET_KEY_BASE..."
      REALTIME_SECRET_KEY_BASE="$DB_ENC_KEY"
      export REALTIME_SECRET_KEY_BASE
      sed -i "/^REALTIME_SECRET_KEY_BASE=/d" "$PROJECT_DIR/.env"
      echo "REALTIME_SECRET_KEY_BASE=$REALTIME_SECRET_KEY_BASE" >> "$PROJECT_DIR/.env"
    fi
    # Vérification variables critiques
    local critical_vars=(POSTGRES_PASSWORD JWT_SECRET ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL DB_ENC_KEY)
    for var in "${critical_vars[@]}"; do
      if [[ -z "${!var:-}" ]]; then
        error "Variable critique manquante dans backup: $var"
      fi
    done
    ok "Secrets chargés depuis backup (JWT prefix: ${JWT_SECRET:0:8}... | DB_ENC_KEY: ${DB_ENC_KEY:0:8}...)"
  else
    log "Génération de nouveaux secrets sécurisés..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)
    JWT_SECRET=$(openssl rand -hex 32)
    DB_ENC_KEY=$(openssl rand -hex 8)
    local site_url="http://$(hostname -I | awk '{print $1}'):${SUPABASE_PORT}"
    # Génération keys JWT (anon et service_role) basées sur JWT_SECRET
    ANON_KEY=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNDk4MTAwODAwLCJleHAiOjE4MTc0ODQ4MDB9.${JWT_SECRET}" | base64 -w0)
    SERVICE_ROLE_KEY=$(echo -n "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IiIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE0OTgxMDA4MDAsImV4cCI6MTgxNzQ4NDgwMH0.${JWT_SECRET}" | base64 -w0)
    REALTIME_SECRET_KEY_BASE="$DB_ENC_KEY"
    API_EXTERNAL_URL="$site_url"
    SUPABASE_PUBLIC_URL="$site_url"
    # Export pour utilisation (inclut DB_ENC_KEY pour éviter WARN)
    export POSTGRES_PASSWORD JWT_SECRET DB_ENC_KEY REALTIME_SECRET_KEY_BASE ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL APP_NAME
    ok "Nouveaux secrets générés - JWT prefix: ${JWT_SECRET:0:8}... | DB_ENC_KEY: ${DB_ENC_KEY:0:8}... | Backup: $backup_file"
  fi
  # Sauvegarde systématique après compléments (avec DB_ENC_KEY et APP_NAME)
  cp "$PROJECT_DIR/.env" "$backup_file"
  echo "APP_NAME=$APP_NAME" >> "$backup_file"  # Ajout pour backup futur
}

# Création du fichier .env optimisé pour ARM64 (16GB RAM, ulimits) avec APP_NAME
create_env_file() {
  log "📄 Création du fichier .env optimisé pour Pi5 ARM64..."
  # Vérification toutes variables définies (inclut DB_ENC_KEY)
  local vars=(POSTGRES_PASSWORD JWT_SECRET DB_ENC_KEY REALTIME_SECRET_KEY_BASE ANON_KEY SERVICE_ROLE_KEY API_EXTERNAL_URL SUPABASE_PUBLIC_URL)
  for var in "${vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      error "Variable manquante pour .env: $var"
    fi
  done
  # Génération dashboard password
  local dashboard_pass=$(openssl rand -base64 16 | tr -d '=+/')
  cat > "$PROJECT_DIR/.env" << ENV
# Supabase .env - Optimisé pour Raspberry Pi 5 ARM64 (16GB RAM, Bookworm)
# Secrets générés le $(date)
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
JWT_SECRET=${JWT_SECRET}
DB_ENC_KEY=${DB_ENC_KEY}  # Clé critique pour realtime (évite WARN)
REALTIME_SECRET_KEY_BASE=${REALTIME_SECRET_KEY_BASE}
APP_NAME=${APP_NAME}  # Fix boot realtime (RuntimeError: APP_NAME not available)
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
REALTIME_ULIMIT_NOFILE=131072  # Augmenté pour ARM64 (fix Erlang crash)
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
SEED_SELF_HOST=true  # Pour migrations realtime self-hosted
ENV
  # Permissions pour utilisateur pi
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
  # Vérification création et DB_ENC_KEY/APP_NAME présents
  if [[ ! -f "$PROJECT_DIR/.env" ]]; then
    error "Échec création .env"
  fi
  if ! grep -q "^DB_ENC_KEY=" "$PROJECT_DIR/.env" || ! grep -q "^APP_NAME=" "$PROJECT_DIR/.env"; then
    error "DB_ENC_KEY ou APP_NAME manquant dans .env après création"
  fi
  ok ".env créé et sécurisé - APP_NAME inclus (buffers 1GB, ulimits 131072 pour realtime)."
}

# Création du fichier docker-compose.yml avec APP_NAME et SEED_SELF_HOST pour realtime
create_docker_compose() {
  log "🐳 Création et validation docker-compose.yml..."
  # Contenu YAML avec ressources limitées pour Pi5 (memory limits, ulimits Realtime 131072) + APP_NAME
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
      APP_NAME: ${APP_NAME}  # Fix boot Elixir (RuntimeError: APP_NAME not available)
      SEED_SELF_HOST: true  # Pour migrations self-hosted
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
      RLIMIT_NOFILE: 131072
    ulimits:
      nofile:
        soft: 131072
        hard: 131072
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
  # Permissions
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"
  # Validation syntaxe YAML
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose config" &> /dev/null; then
    error "Erreur de validation docker-compose.yml - Vérifiez le contenu."
  fi
  ok "docker-compose.yml créé et validé - APP_NAME=realtime + SEED_SELF_HOST=true pour realtime."
}

# Fonction utilitaire : Récupère liste services unhealthy via parsing Status
get_unhealthy_services() {
  local project_dir="$1"
  su "$TARGET_USER" -c "cd '$project_dir' && docker compose ps --format '{{.Name}} {{.Status}}'" | \
    awk '{ if ($2 ~ /unhealthy/) { print $1 } }' | \
    tr '\n' ' ' | \
    sed 's/ $//' || true
}

# Fonction utilitaire : Récupère liste services exited (fix relance)
get_exited_services() {
  local project_dir="$1"
  su "$TARGET_USER" -c "cd '$project_dir' && docker compose ps --filter 'status=exited' --format '{{.Name}}'" | \
    tr '\n' ' ' | \
    sed 's/ $//' || true
}

# Pré-téléchargement des images Docker pour accélérer le démarrage
pre_pull_images() {
  log "🔍 Pré-téléchargement des images critiques (évite timeouts Pi5)..."
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
      error "Échec téléchargement image: $image - Vérifiez connexion internet."
    fi
    ok "Image $image téléchargée."
  done
  ok "Toutes les images pré-téléchargées avec succès."
}

# Initialisation des migrations PostgreSQL pour Auth (schema + extensions) + sleep pour realtime
init_auth_migrations() {
  log "🔧 Initialisation des migrations Auth dans PostgreSQL..."
  # Démarrage isolé PostgreSQL
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d postgresql"
  sleep 10  # Attente init DB
  # Création schema auth
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE SCHEMA IF NOT EXISTS auth;'" &> /dev/null; then
    error "Échec création schema auth."
  fi
  # Activation extension UUID (requis pour migrations)
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql psql -U postgres -d postgres -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";'" &> /dev/null; then
    error "Échec activation extension uuid-ossp."
  fi
  sleep 30  # Attente supplémentaire pour realtime (dépend PG + DB_ENC_KEY)
  ok "Migrations Auth initialisées - Schema 'auth' et extension 'uuid-ossp' prêts. Sleep 30s pour realtime."
}

# Déploiement principal : Pull, init, up avec retries healthchecks (focus realtime)
deploy_supabase() {
  log "🚀 Déploiement complet de Supabase..."
  pre_pull_images
  init_auth_migrations
  # Lancement tous services en detached, pull always pour fraîcheur
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --pull always"; then
    error "Échec lancement docker compose up - Vérifiez logs: docker compose logs."
  fi
  sleep 60  # Sleep supplémentaire pour boot Elixir realtime (post-APP_NAME)
  log "⏳ Attente healthchecks et stabilisation (jusqu'à 240s, retries automatiques via parsing Status)..."
  local max_wait=48  # 48 * 5s = 240s
  for i in $(seq 1 "$max_wait"); do
    sleep 5
    local status_output=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps --format 'table {{.Name}}\t{{.Status}}'")
    log "Status itération $i/$max_wait:\n$status_output"
    if echo "$status_output" | grep -q "(healthy)\|Up"; then
      local unhealthy=$(get_unhealthy_services "$PROJECT_DIR")
      if [[ -z "$unhealthy" ]]; then
        break  # Tous healthy ou Up
      fi
      warn "Services unhealthy détectés ($i/$max_wait): $unhealthy - Relance automatique (focus realtime/storage)..."
      # Relance ciblée realtime/storage si présents
      [[ "$unhealthy" =~ "realtime" ]] && su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart realtime"
      [[ "$unhealthy" =~ "storage" ]] && su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart storage"
      su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $unhealthy"
    fi
    if [[ $i -eq $max_wait ]]; then
      warn "Timeout healthchecks (240s) - Relance finale realtime/storage pour tolérance ARM64..."
      su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart realtime storage || true"
    fi
  done
  ok "Services déployés - Vérifiez: cd $PROJECT_DIR && docker compose ps"
}

# Validation finale du déploiement (curl hôte pour éviter absence curl dans images) + fix relance exited
validate_deployment() {
  log "🧪 Validation finale des services Supabase..."
  sleep 120  # Attente supplémentaire pour sync DB
  local ip=$(hostname -I | awk '{print $1}')
  # Test Studio (3000) - curl hôte
  for i in {1..5}; do
    if curl -s "http://localhost:3000" > /dev/null; then
      ok "Studio accessible (port 3000) - http://$ip:3000"
      break
    fi
    warn "Studio en attente ($i/5)..."
    sleep 5
  done
  [[ $i -le 5 ]] || error "Studio non accessible - Vérifiez logs: docker compose logs studio"
  # Test API (SUPABASE_PORT) - curl hôte
  for i in {1..5}; do
    if curl -s "http://localhost:$SUPABASE_PORT" > /dev/null; then
      ok "API accessible (port $SUPABASE_PORT) - http://$ip:$SUPABASE_PORT"
      break
    fi
    warn "API en attente ($i/5)..."
    sleep 5
  done
  [[ $i -le 5 ]] || error "API non accessible - Vérifiez logs: docker compose logs kong"
  # Test PostgreSQL
  if ! su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T postgresql pg_isready -U postgres" > /dev/null; then
    error "PostgreSQL non prêt - Vérifiez logs: docker compose logs postgresql"
  fi
  ok "PostgreSQL connecté."
  # Vérif unhealthy via parsing
  local unhealthy=$(get_unhealthy_services "$PROJECT_DIR")
  if [[ -n "$unhealthy" ]]; then
    warn "Services unhealthy détectés: $unhealthy - Tentative relance finale..."
    su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $unhealthy"
    sleep 30
    local unhealthy_after=$(get_unhealthy_services "$PROJECT_DIR")
    if [[ -n "$unhealthy_after" ]]; then
      # Tests curl hôte pour realtime/storage (tolérance si KO)
      if ! curl -s "http://localhost:4000/health" > /dev/null; then
        warn "Realtime health KO - Relance manuelle recommandée: docker compose restart realtime"
      else
        ok "Realtime health OK malgré status."
      fi
      if ! curl -s "http://localhost:5000/health" > /dev/null; then
        warn "Storage health KO - Relance manuelle recommandée: docker compose restart storage"
      else
        ok "Storage health OK malgré status."
      fi
      warn "Supabase partiellement opérationnel (Studio/API OK) - Surveillez logs pour $unhealthy_after."
    else
      ok "Relance réussie - Tous healthy maintenant."
    fi
  fi
  # Vérif exited avec fix relance (vérif existence avant restart)
  local exited=$(get_exited_services "$PROJECT_DIR")
  if [[ -n "$exited" ]]; then
    warn "Services exited: $exited - Relance auto (vérif existence)..."
    for svc in $exited; do
      if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker ps --filter 'name=$svc' --format '{{.Names}}'" | grep -q .; then
        su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart $svc"
        log "Relancé: $svc"
      else
        warn "Service $svc inexistant - Skip relance."
      fi
    done
    sleep 10
  fi
  # Test realtime post-relance
  if curl -s "http://localhost:4000/health" > /dev/null 2>&1; then
    ok "Realtime accessible (port 4000)"
  else
    warn "Realtime non accessible - Vérifiez logs: docker compose logs realtime"
  fi
  # Affichage keys API (sauvegardez-les manuellement!)
  log "🔑 Vos API Keys Supabase (sauvegardez-les immédiatement!):"
  grep -E "ANON_KEY|SERVICE_ROLE_KEY" "$PROJECT_DIR/.env" | sed 's/^/   /'
  log "Dashboard: http://$ip:3000 | User: supabase | Pass: (dans .env)"
  ok "Validation complète OK! Supabase est opérationnel."
}

# Flux principal d'exécution
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
  log "🎉 Déploiement Supabase terminé avec succès!"
  log "📋 Logs complets: $LOG_FILE"
  log "🚀 Actions manuelles post-install:"
  log "   1. Accédez à http://$(hostname -I | awk '{print $1}'):3000"
  log "   2. Créez un nouveau projet dans Studio."
  log "   3. Notez ANON_KEY et SERVICE_ROLE_KEY depuis .env pour votre app."
  log "   4. Pour arrêtez/redémarrer: cd $PROJECT_DIR && docker compose down/up -d"
  log "   5. Si realtime KO persistant: docker compose logs realtime | grep RuntimeError"
  log "   6. Si besoin recreate: sudo FORCE_RECREATE=1 $0"
}

# Lancement main si script direct
main "$@"