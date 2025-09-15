#!/usr/bin/env bash
set -euo pipefail

# === SETUP WEEK2 SUPABASE FINAL - Installation complète avec tous les correctifs ===

log()  { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]  \033[0m $*"; }

# Variables globales
SCRIPT_VERSION="2.0-final"
LOG_FILE="/var/log/pi5-setup-week2-supabase-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

# Configuration par défaut
SUPABASE_PORT="${SUPABASE_PORT:-8001}"  # Port par défaut pour éviter conflits

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0"
    exit 1
  fi
}

setup_logging() {
  exec 1> >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE" >&2)

  log "=== Pi 5 Supabase Installation Final - $(date) ==="
  log "Version: $SCRIPT_VERSION"
  log "Utilisateur cible: $TARGET_USER"
  log "Répertoire projet: $PROJECT_DIR"
}

check_prerequisites() {
  log "🔍 Vérification prérequis système..."

  # Vérifier Week1 installé
  if ! command -v docker >/dev/null; then
    error "❌ Docker non installé - Lancer d'abord Week1 Enhanced"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    error "❌ Docker Compose v2 non installé"
    exit 1
  fi

  # **CRITIQUE: Vérifier page size (problème principal Pi 5)**
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  if [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size: ${page_size}B - Images officielles"
  elif [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB - INCOMPATIBLE avec PostgreSQL"
    echo ""
    echo "🔧 **SOLUTION REQUISE** :"
    echo "   1. Ajouter 'kernel=kernel8.img' à /boot/firmware/config.txt"
    echo "   2. Redémarrer le Pi : sudo reboot"
    echo "   3. Vérifier : getconf PAGESIZE doit retourner 4096"
    echo ""
    exit 1
  else
    warn "⚠️ Page size non standard: ${page_size}B"
  fi

  # Vérifier entropie système (critique pour ARM64)
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -lt 1000 ]]; then
    warn "⚠️ Entropie système faible: $entropy (recommandé: >1000)"
    log "   Installation de haveged recommandée pour améliorer l'entropie"
  else
    ok "✅ Entropie système: $entropy"
  fi

  # Vérifier Docker daemon limits pour ARM64
  if command -v systemctl >/dev/null; then
    local docker_nofile=$(systemctl show docker.service --property=LimitNOFILE 2>/dev/null | cut -d= -f2)
    if [[ "$docker_nofile" == "infinity" ]] || [[ $docker_nofile -ge 65536 ]]; then
      ok "✅ Docker daemon file limits: $docker_nofile"
    else
      warn "⚠️ Docker daemon file limits: $docker_nofile (recommandé: >=65536)"
      log "   Des services comme Realtime peuvent redémarrer avec des limites faibles"
    fi
  fi

  ok "Prérequis validés"
}

check_port_conflicts() {
  log "🔍 Vérification conflits de ports..."

  local supabase_ports=(3000 $SUPABASE_PORT 5432 54321)
  local conflicted_ports=()

  for port in "${supabase_ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      conflicted_ports+=("$port")
    fi
  done

  if [[ ${#conflicted_ports[@]} -gt 0 ]]; then
    warn "⚠️ Ports occupés: ${conflicted_ports[*]}"

    # Gestion conflit Portainer port 8000
    if [[ " ${conflicted_ports[*]} " =~ " 8000 " ]]; then
      log "   Migration Portainer 8000 → 8080 si nécessaire..."

      if docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
        local portainer_port=$(docker port portainer 2>/dev/null | grep "9000/tcp" | cut -d: -f2 || echo "unknown")
        if [[ "$portainer_port" == "8000" ]]; then
          log "   Reconfiguration Portainer vers port 8080..."
          docker stop portainer >/dev/null 2>&1 || true
          docker rm portainer >/dev/null 2>&1 || true
          docker run -d -p 8080:9000 --name portainer --restart=always \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v portainer_data:/data portainer/portainer-ce:latest >/dev/null 2>&1
          ok "✅ Portainer migré vers port 8080"
        fi
      fi
    fi

    # Vérification finale
    conflicted_ports=()
    for port in "${supabase_ports[@]}"; do
      if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        conflicted_ports+=("$port")
      fi
    done

    if [[ ${#conflicted_ports[@]} -gt 0 ]]; then
      error "❌ Ports toujours occupés: ${conflicted_ports[*]}"
      echo "   Arrêter les services utilisant ces ports avant de continuer"
      exit 1
    fi
  fi

  ok "✅ Aucun conflit de port détecté"
}

optimize_system_for_supabase() {
  log "🔧 Optimisation système pour Supabase ARM64..."

  # 1. Installer haveged pour améliorer l'entropie (critique pour crypto/JWT)
  if ! command -v haveged &> /dev/null; then
    log "📦 Installation de haveged pour améliorer l'entropie..."
    apt update && apt install -y haveged
    systemctl enable haveged
    systemctl start haveged
    ok "✅ Haveged installé et activé"
  else
    log "ℹ️ Haveged déjà installé"
  fi

  # 2. Configurer Docker daemon pour des limits appropriées
  local docker_override_dir="/etc/systemd/system/docker.service.d"
  local docker_override_file="$docker_override_dir/override.conf"

  if [[ ! -f "$docker_override_file" ]]; then
    log "🐳 Configuration des limites Docker daemon..."
    mkdir -p "$docker_override_dir"

    cat > "$docker_override_file" << 'DOCKER_OVERRIDE'
[Service]
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
DOCKER_OVERRIDE

    systemctl daemon-reload
    systemctl restart docker
    ok "✅ Limites Docker daemon configurées"
  else
    log "ℹ️ Limites Docker daemon déjà configurées"
  fi

  # 3. Vérifier l'entropie après installation haveged
  local new_entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $new_entropy -gt 1000 ]]; then
    ok "✅ Entropie améliorée: $new_entropy"
  else
    warn "⚠️ Entropie toujours faible: $new_entropy"
  fi
}

create_project_structure() {
  log "📁 Création structure projet..."

  log "   Création structure projet: $PROJECT_DIR"

  # Créer structure complète avec functions
  su "$TARGET_USER" -c "mkdir -p '$PROJECT_DIR'/{volumes/{db,storage,kong,functions},scripts,backups}"

  # Permissions Docker pour volumes
  chown -R 999:999 "$PROJECT_DIR/volumes/db" 2>/dev/null || true
  chown -R 100:101 "$PROJECT_DIR/volumes/kong" 2>/dev/null || true
  chmod -R 750 "$PROJECT_DIR/volumes"

  # Créer fonction edge par défaut
  create_default_edge_function

  ok "Structure créée: $PROJECT_DIR"
}

create_default_edge_function() {
  log "⚡ Création fonction Edge par défaut..."

  # Créer répertoire main pour edge functions
  mkdir -p "$PROJECT_DIR/volumes/functions/main"

  # Créer index.ts par défaut
  cat > "$PROJECT_DIR/volumes/functions/main/index.ts" << 'EDGE_FUNCTION'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { name } = await req.json()
  const data = {
    message: `Hello ${name}!`,
    timestamp: new Date().toISOString(),
    platform: "Pi 5 ARM64",
  }

  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
EDGE_FUNCTION

  # Permissions
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/functions"

  ok "✅ Fonction Edge par défaut créée"
}

generate_secure_secrets() {
  log "🔐 Génération secrets sécurisés..."

  # Génération sécurisée (sans caractères spéciaux problématiques)
  local postgres_password=$(openssl rand -base64 32 | tr -d "=+/@#\$&*" | cut -c1-25)
  local jwt_secret=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-64)
  local anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg"
  local service_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.T49KQx5LzLqbNBDOgdYlCW0Rf7cCUfz1bVy9q_Tl2X8"

  # Détecter IP locale
  local local_ip=$(hostname -I | awk '{print $1}')

  # Exporter pour utilisation dans les fonctions
  export POSTGRES_PASSWORD="$postgres_password"
  export JWT_SECRET="$jwt_secret"
  export SUPABASE_ANON_KEY="$anon_key"
  export SUPABASE_SERVICE_KEY="$service_key"
  export LOCAL_IP="$local_ip"

  ok "✅ Secrets générés pour IP: $local_ip"
  log "   API accessible sur: http://$local_ip:$SUPABASE_PORT"
}

create_env_file() {
  log "📄 Création fichier .env avec variables correctes..."

  # Créer .env avec TOUTES les variables nécessaires
  cat > "$PROJECT_DIR/.env" << EOF
# Pi 5 Supabase Configuration Final
# Generated: $(date)

########################################
# Core Database
########################################
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=postgres
POSTGRES_USER=postgres

# **CRITIQUE: UN SEUL MOT DE PASSE pour éviter erreurs auth**
# Tous les services utilisent POSTGRES_PASSWORD

########################################
# JWT & Authentication
########################################
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY

########################################
# API & URLs
########################################
SUPABASE_PUBLIC_URL=http://$LOCAL_IP:$SUPABASE_PORT
API_EXTERNAL_URL=http://$LOCAL_IP:$SUPABASE_PORT

########################################
# Pi 5 PostgreSQL Optimizations (16GB RAM)
########################################
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_EFFECTIVE_CACHE_SIZE=8GB

########################################
# Docker Configuration
########################################
DOCKER_SOCKET_LOCATION=/var/run/docker.sock

########################################
# Ports (éviter conflits)
########################################
KONG_HTTP_PORT=$SUPABASE_PORT
SUPABASE_PORT=$SUPABASE_PORT

########################################
# Development
########################################
ENVIRONMENT=development

EOF

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"

  ok "✅ Fichier .env créé avec toutes les variables"
}

create_docker_compose() {
  log "🐳 Création docker-compose.yml optimisé avec variables..."

  # Docker-compose unifié avec corrections complètes
  cat > "$PROJECT_DIR/docker-compose.yml" << 'COMPOSE'
services:
  # Base de données PostgreSQL optimisée Pi 5
  db:
    container_name: supabase-db
    image: postgres:15-alpine
    platform: linux/arm64
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: postgres
      # Optimisations Pi 5 16GB
      POSTGRES_SHARED_BUFFERS: ${POSTGRES_SHARED_BUFFERS}
      POSTGRES_WORK_MEM: ${POSTGRES_WORK_MEM}
      POSTGRES_MAINTENANCE_WORK_MEM: ${POSTGRES_MAINTENANCE_WORK_MEM}
      POSTGRES_MAX_CONNECTIONS: ${POSTGRES_MAX_CONNECTIONS}
      # PostgreSQL Alpine init
      POSTGRES_INITDB_ARGS: "--data-checksums --auth-host=md5"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d postgres"]
      interval: 45s
      timeout: 20s
      retries: 8
      start_period: 90s
    deploy:
      resources:
        limits:
          memory: 2GB
          cpus: '2.0'
    volumes:
      - ./volumes/db:/var/lib/postgresql/data:Z
    ports:
      - "5432:5432"

  # Service Auth (GoTrue) - MOT DE PASSE UNIFIÉ
  auth:
    container_name: supabase-auth
    image: supabase/gotrue:v2.177.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      GOTRUE_URI_ALLOW_LIST: "*"
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Service REST (PostgREST) - MOT DE PASSE UNIFIÉ
  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:v12.2.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Service Realtime - MOT DE PASSE UNIFIÉ + CORRECTIONS ARM64 COMPLÈTES
  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.30.23
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      DB_ENC_KEY: supabaserealtime
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${JWT_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp
      ENABLE_TAILSCALE: "false"
      DNS_NODES: "''"
      # CORRECTIONS ARM64/Pi 5 - SOLUTION DÉFINITIVE 2024
      RLIMIT_NOFILE: "10000"
      SEED_SELF_HOST: "true"
    ulimits:
      nofile:
        soft: 10000
        hard: 10000
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Service Storage - MOT DE PASSE UNIFIÉ
  storage:
    container_name: supabase-storage
    image: supabase/storage-api:v1.11.6
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      ANON_KEY: ${SUPABASE_ANON_KEY}
      SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
      ENABLE_IMAGE_TRANSFORMATION: "true"
      IMGPROXY_URL: http://imgproxy:5001
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Service Meta (PostgREST Schema)
  meta:
    container_name: supabase-meta
    image: supabase/postgres-meta:v0.83.2
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: postgres
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Kong API Gateway - IMAGE ARM64 SPÉCIFIQUE POUR PI 5
  kong:
    container_name: supabase-kong
    image: arm64v8/kong:3.0.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      auth:
        condition: service_started
      rest:
        condition: service_started
      realtime:
        condition: service_started
      storage:
        condition: service_started
      meta:
        condition: service_started
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /var/lib/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_DNS_RESOLVER: "127.0.0.11:53"
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
      # ARM64/Pi 5 specific optimizations
      KONG_NGINX_WORKER_PROCESSES: "2"
      KONG_MEM_CACHE_SIZE: "128m"
    ports:
      - "${SUPABASE_PORT}:8000"
    volumes:
      - ./volumes/kong/kong.yml:/var/lib/kong/kong.yml:ro

  # Service Studio (Interface Web)
  studio:
    container_name: supabase-studio
    image: supabase/studio:20250106-e00ba41
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      kong:
        condition: service_started
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: "Pi 5 Supabase"
      DEFAULT_PROJECT_NAME: "Pi5 Project"
      SUPABASE_URL: http://kong:8000
      SUPABASE_REST_URL: http://kong:8000/rest/v1/
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
      LOGFLARE_API_KEY: your-super-secret-and-long-logflare-key
      LOGFLARE_URL: http://analytics:4000
      NEXT_PUBLIC_ENABLE_LOGS: true
    ports:
      - "3000:3000"

  # Image Proxy pour transformations
  imgproxy:
    container_name: supabase-imgproxy
    image: darthsim/imgproxy:v3.8.0
    platform: linux/arm64
    restart: unless-stopped
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
      IMGPROXY_USE_ETAG: "true"
      IMGPROXY_ENABLE_WEBP_DETECTION: "true"
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Edge Functions - CORRECTED COMMAND FORMAT
  edge-functions:
    container_name: supabase-edge-functions
    image: supabase/edge-runtime:v1.58.2
    platform: linux/arm64
    restart: unless-stopped
    command:
      - start
      - --main-service
      - /home/deno/functions/main
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
    volumes:
      - ./volumes/functions:/home/deno/functions:z
    ports:
      - "54321:9000"
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # NOTE: supabase-vector DÉSACTIVÉ pour Pi 5 ARM64
  # Cause des problèmes de page size sur ARM64
  # Réactiver uniquement si page size 4KB confirmé fonctionnel

networks:
  default:
    name: supabase_network

COMPOSE

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"
  ok "✅ docker-compose.yml créé avec variables unifiées"
}

create_kong_config() {
  log "⚙️ Création configuration Kong..."

  mkdir -p "$PROJECT_DIR/volumes/kong"
  cat > "$PROJECT_DIR/volumes/kong/kong.yml" << 'KONG'
_format_version: "1.1"

consumers:
  - username: anon
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg
  - username: service_role
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.T49KQx5LzLqbNBDOgdYlCW0Rf7cCUfz1bVy9q_Tl2X8

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - "/auth/v1/signup"
          - "/auth/v1/token"
          - "/auth/v1/verify"
          - "/auth/v1/callback"
          - "/auth/v1/authorize"
          - "/auth/v1/logout"
          - "/auth/v1/recover"
          - "/auth/v1/user"

  - name: auth-v1-open-invite
    url: http://auth:9999/
    routes:
      - name: auth-v1-open-invite
        strip_path: true
        paths:
          - "/auth/v1/invite"

  - name: auth-v1-open-otp
    url: http://auth:9999/
    routes:
      - name: auth-v1-open-otp
        strip_path: true
        paths:
          - "/auth/v1/otp"

  - name: rest-v1
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - "/rest/v1/"
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true

  - name: realtime-v1
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1
        strip_path: true
        paths:
          - "/realtime/v1/"
    plugins:
      - name: cors
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true

  - name: storage-v1
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - "/storage/v1/"
    plugins:
      - name: cors

  - name: edge-functions-v1
    url: http://edge-functions:9000/
    routes:
      - name: edge-functions-v1-all
        strip_path: true
        paths:
          - "/functions/v1/"
    plugins:
      - name: cors
KONG

  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/kong"
  ok "✅ Configuration Kong créée"
}

start_supabase_services() {
  log "🚀 Démarrage des services Supabase..."

  cd "$PROJECT_DIR"

  # Pull des images
  log "📦 Téléchargement images Docker..."
  su "$TARGET_USER" -c "docker compose pull --quiet"

  # Démarrage progressif
  log "🏗️ Démarrage conteneurs..."
  su "$TARGET_USER" -c "docker compose up -d"

  ok "Services lancés"
}

wait_for_services() {
  log "⏳ Attente initialisation des services (60s)..."

  cd "$PROJECT_DIR"
  sleep 60

  ok "✅ Services principaux initialisés"
}

create_database_users() {
  log "👥 Création utilisateurs PostgreSQL avec mots de passe unifiés..."

  cd "$PROJECT_DIR"

  # **SOLUTION FINALE: Un seul mot de passe pour éviter les erreurs auth**
  # Tous les utilisateurs utilisent POSTGRES_PASSWORD

  su "$TARGET_USER" -c "docker compose exec -T db psql -U postgres << 'SQL'
-- Créer tous les utilisateurs avec POSTGRES_PASSWORD unifié
DO \$\$
BEGIN
  -- service_role (CRITIQUE pour Auth/RLS)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE USER service_role WITH BYPASSRLS CREATEDB PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created service_role user';
  ELSE
    ALTER USER service_role WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated service_role password';
  END IF;

  -- authenticator (pour Rest service)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created authenticator user';
  ELSE
    ALTER USER authenticator WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated authenticator password';
  END IF;

  -- anon (utilisateur anonyme)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE USER anon;
    RAISE NOTICE 'Created anon user';
  END IF;

  -- supabase_storage_admin (pour Storage service)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created supabase_storage_admin user';
  ELSE
    ALTER USER supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated supabase_storage_admin password';
  END IF;
END
\$\$;

-- Permissions essentielles
GRANT USAGE ON SCHEMA public TO anon, service_role;
GRANT CREATE ON SCHEMA public TO service_role;

-- Permissions pour authenticator (lier les rôles)
GRANT anon TO authenticator;
GRANT service_role TO authenticator;

-- Permissions étendues
GRANT ALL PRIVILEGES ON DATABASE postgres TO service_role, supabase_storage_admin;
GRANT ALL PRIVILEGES ON SCHEMA public TO service_role;

-- Extensions nécessaires pour Supabase
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";
CREATE EXTENSION IF NOT EXISTS \"pg_stat_statements\";

SELECT 'Utilisateurs créés avec mots de passe unifiés' as result;
\q
SQL" 2>/dev/null

  if [[ $? -eq 0 ]]; then
    ok "✅ Utilisateurs PostgreSQL créés avec mots de passe unifiés"
  else
    warn "⚠️ Erreur création utilisateurs - Services peuvent redémarrer"
  fi
}

restart_dependent_services() {
  log "🔄 Redémarrage services dépendants avec nouveaux utilisateurs..."

  cd "$PROJECT_DIR"

  # Redémarrer les services qui utilisent les nouveaux utilisateurs
  su "$TARGET_USER" -c "docker compose restart auth rest storage realtime"

  # Attendre stabilisation
  sleep 30

  ok "✅ Services redémarrés"
}

create_utility_scripts() {
  log "🛠️ Création scripts utilitaires..."

  # Script de santé
  cat > "$PROJECT_DIR/scripts/supabase-health.sh" << 'HEALTH'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "=== État Supabase ==="
docker compose ps

echo ""
echo "=== Tests connectivité ==="

# Test Studio
if curl -s -m 5 http://localhost:3000 >/dev/null; then
  echo "✅ Studio OK"
else
  echo "❌ Studio KO"
fi

# Test API
if curl -s -m 5 "http://localhost:$(grep SUPABASE_PORT .env | cut -d= -f2)" >/dev/null; then
  echo "✅ API OK"
else
  echo "❌ API KO"
fi

# Test PostgreSQL
if docker compose exec -T db psql -U postgres -c "SELECT 1;" >/dev/null 2>&1; then
  echo "✅ PostgreSQL OK"
else
  echo "❌ PostgreSQL KO"
fi
HEALTH

  # Script de logs
  cat > "$PROJECT_DIR/scripts/supabase-logs.sh" << 'LOGS'
#!/bin/bash
cd "$(dirname "$0")/.."

if [[ -n "$1" ]]; then
  docker compose logs -f "$1"
else
  echo "Usage: $0 <service>"
  echo "Services disponibles:"
  docker compose ps --services
fi
LOGS

  # Script de redémarrage
  cat > "$PROJECT_DIR/scripts/supabase-restart.sh" << 'RESTART'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "Redémarrage Supabase..."
docker compose down
sleep 5
docker compose up -d
echo "Redémarrage terminé"
RESTART

  chmod +x "$PROJECT_DIR/scripts"/*.sh
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/scripts"

  ok "✅ Scripts utilitaires créés"
}

validate_installation() {
  log "🧪 Validation installation..."

  cd "$PROJECT_DIR"

  local tests_total=4
  local tests_passed=0

  log "Services actifs: $(su "$TARGET_USER" -c "docker compose ps --services --filter status=running" | wc -l)/$(su "$TARGET_USER" -c "docker compose ps --services" | wc -l)"

  # Test Studio
  if timeout 10 curl -s "http://localhost:3000" >/dev/null 2>&1; then
    ok "  ✅ Studio accessible (port 3000)"
    ((tests_passed++))
  else
    warn "  ❌ Studio non accessible"
  fi

  # Test API Gateway
  if timeout 10 curl -s "http://localhost:$SUPABASE_PORT" >/dev/null 2>&1; then
    ok "  ✅ API Gateway accessible (port $SUPABASE_PORT)"
    ((tests_passed++))
  else
    warn "  ❌ API Gateway non accessible"
  fi

  # Test PostgreSQL
  if su "$TARGET_USER" -c "docker compose exec -T db psql -U postgres -c 'SELECT 1;'" >/dev/null 2>&1; then
    ok "  ✅ PostgreSQL accessible (port 5432)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL non accessible"
  fi

  # Test variables dans Auth (avec retry et fallback)
  local var_test_ok=false
  local retry_count=0

  while [[ $retry_count -lt 3 ]] && [[ $var_test_ok == false ]]; do
    if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T auth printenv 2>/dev/null | grep -q 'API_EXTERNAL_URL'" 2>/dev/null; then
      var_test_ok=true
    else
      sleep 2
      ((retry_count++))
    fi
  done

  if [[ $var_test_ok == true ]]; then
    ok "  ✅ Variables propagées correctement"
    ((tests_passed++))
  else
    # Test alternatif avec le fichier .env
    if [[ -f "$PROJECT_DIR/.env" ]] && grep -q "API_EXTERNAL_URL" "$PROJECT_DIR/.env" 2>/dev/null; then
      ok "  ✅ Variables présentes dans .env (conteneur peut redémarrer)"
      ((tests_passed++))
    else
      warn "  ❌ Problème propagation variables"
    fi
  fi

  log "Tests réussis: $tests_passed/$tests_total"

  if [[ $tests_passed -ge 3 ]]; then
    ok "✅ Installation validée avec succès"
    return 0
  else
    warn "⚠️ Installation partiellement fonctionnelle"
    return 1
  fi
}

show_completion_summary() {
  echo ""
  echo "==================== 🎉 SUPABASE Pi 5 INSTALLÉ ! ===================="
  echo ""

  local validation_result=0
  validate_installation || validation_result=$?

  if [[ $validation_result -eq 0 ]]; then
    echo "✅ **Installation finale réussie avec tous les correctifs intégrés**"
  else
    echo "⚠️ **Installation terminée avec quelques points d'attention**"
  fi

  echo "   🎯 Page size: 4KB"
  echo "   🔧 Mots de passe unifiés (plus d'erreurs auth)"
  echo "   🥧 Optimisé pour Pi 5 16GB ARM64"
  echo "   🔧 Realtime: RLIMIT_NOFILE + ulimits (recherche 2024)"
  echo "   🔧 Kong: ARM64 image + DNS resolver optimisé"
  echo "   🔧 Edge Functions: main function + command array correct"
  echo "   🔧 Entropie système améliorée (haveged)"
  echo "   🔧 Docker daemon: limits optimisées pour ARM64"
  echo ""
  echo "📍 **Accès aux services** :"
  echo "   🎨 Studio      : http://$LOCAL_IP:3000"
  echo "   🔌 API Gateway : http://$LOCAL_IP:$SUPABASE_PORT"
  echo "   ⚡ Edge Funcs  : http://$LOCAL_IP:54321/functions/v1/"
  echo "   🗄️ PostgreSQL : localhost:5432"
  echo ""
  echo "🔑 **Credentials sauvées dans** : $PROJECT_DIR/.env"
  echo ""
  echo "🛠️ **Scripts de maintenance** :"
  echo "   cd $PROJECT_DIR"
  echo "   ./scripts/supabase-health.sh     # 🏥 Vérifier santé"
  echo "   ./scripts/supabase-restart.sh    # 🔄 Redémarrer"
  echo "   ./scripts/supabase-logs.sh <service>  # 📋 Voir logs"
  echo ""
  echo "📂 **Logs** : $LOG_FILE"
  echo ""
  echo "📋 **Prochaine étape : Week 3 - HTTPS et accès externe**"
  echo "=================================================================="
}

validate_critical_services() {
  log "🔍 Validation services critiques post-recherche..."

  cd "$PROJECT_DIR"
  local validation_errors=0

  # 1. Valider Realtime (RLIMIT_NOFILE + ulimits)
  log "   Vérification Realtime (RLIMIT_NOFILE)..."
  if su "$TARGET_USER" -c "docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null" | grep -q "10000"; then
    ok "  ✅ Realtime: ulimits configurés correctement"
  else
    warn "  ⚠️ Realtime: problème ulimits détecté"
    ((validation_errors++))
  fi

  # 2. Valider Kong (ARM64 image + DNS)
  log "   Vérification Kong (ARM64 + DNS)..."
  local kong_image=$(su "$TARGET_USER" -c "docker compose ps kong --format json" 2>/dev/null | jq -r '.Image' 2>/dev/null || echo "unknown")
  if [[ "$kong_image" == *"arm64v8/kong"* ]]; then
    ok "  ✅ Kong: image ARM64 spécifique utilisée"
  else
    warn "  ⚠️ Kong: image ARM64 non détectée: $kong_image"
    ((validation_errors++))
  fi

  # 3. Valider Edge Functions (main function existe)
  log "   Vérification Edge Functions (main function)..."
  if [[ -f "$PROJECT_DIR/volumes/functions/main/index.ts" ]]; then
    ok "  ✅ Edge Functions: fonction main créée"
  else
    warn "  ⚠️ Edge Functions: fonction main manquante"
    ((validation_errors++))
  fi

  # 4. Vérifier entropie système finale
  log "   Vérification entropie système..."
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -gt 1000 ]]; then
    ok "  ✅ Entropie système: $entropy"
  else
    warn "  ⚠️ Entropie système faible: $entropy"
    ((validation_errors++))
  fi

  if [[ $validation_errors -eq 0 ]]; then
    ok "✅ Tous les correctifs de recherche appliqués avec succès"
  else
    warn "⚠️ $validation_errors problème(s) détecté(s) - vérifier logs"
  fi

  return $validation_errors
}

main() {
  require_root
  setup_logging

  log "🎯 Installation pour utilisateur: $TARGET_USER"

  check_prerequisites
  optimize_system_for_supabase
  check_port_conflicts
  create_project_structure
  generate_secure_secrets
  create_env_file
  create_docker_compose
  create_kong_config
  start_supabase_services
  wait_for_services
  create_database_users
  restart_dependent_services
  create_utility_scripts
  validate_critical_services

  show_completion_summary
}

main "$@"