#!/usr/bin/env bash
set -euo pipefail

# === Supabase Self-Hosted Installation Script for Raspberry Pi 5 (16GB RAM) - 2025 ===
# This script installs all Supabase services except vector (not compatible with ARM64/Pi 5).
# Based on official Supabase docs and optimizations for Pi 5 ARM64.
# Includes fixes for auth schema init and realtime env vars.
# Prerequisites: Raspberry Pi OS 64-bit, sudo access.

log() { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Variables
PROJECT_DIR="/home/pi/supabase"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
LOG_FILE="/var/log/supabase-install-$(date +%Y%m%d_%H%M%S).log"

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    error "Run as sudo"
    exit 1
  fi
}

setup_logging() {
  exec > >(tee -a "$LOG_FILE") 2>&1
  log "Starting Supabase installation on Pi 5 - $(date)"
}

check_prerequisites() {
  log "Checking prerequisites..."
  
  # Architecture
  if [[ $(uname -m) != "aarch64" ]]; then
    error "Must be ARM64 (Raspberry Pi 5)"
    exit 1
  fi
  
  # Page size (must be 4096 for PostgreSQL compatibility)<grok-card data-id="45a778" data-type="citation_card"></grok-card>
  if [[ $(getconf PAGESIZE) != 4096 ]]; then
    warn "Page size is not 4096 - Incompatible with PostgreSQL"
    log "Fix: Add 'kernel=kernel8.img' to /boot/firmware/config.txt and reboot"
    exit 1
  fi
  ok "Page size OK"
  
  # Docker
  if ! command -v docker &> /dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | bash
    usermod -aG docker pi
    systemctl enable --now docker
  fi
  
  # Docker Compose
  if ! command -v docker-compose &> /dev/null; then
    apt update && apt install -y docker-compose
  fi
  
  # RAM check (16GB recommended)
  if [[ $(free -g | awk '/^Mem:/ {print $2}') -lt 15 ]]; then
    warn "Less than 16GB RAM - May have performance issues"
  fi
  ok "Prerequisites OK"
}

generate_env() {
  log "Generating .env file..."
  mkdir -p "$PROJECT_DIR"
  
  local postgres_password=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 25)
  local jwt_secret=$(openssl rand -base64 64 | tr -dc 'a-zA-Z0-9' | head -c 64)
  local db_enc_key=$(openssl rand -base64 32)
  local local_ip=$(hostname -I | awk '{print $1}')
  
  cat > "$ENV_FILE" << EOF
POSTGRES_PASSWORD=$postgres_password
JWT_SECRET=$jwt_secret
DB_ENC_KEY=$db_enc_key
API_EXTERNAL_URL=http://$local_ip:$SUPABASE_PORT
SITE_URL=http://$local_ip:3000
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.T49KQx5LzLqbNBDOgdYlCW0Rf7cCUfz1bVy9q_Tl2X8
EOF

  chown pi:pi "$ENV_FILE"
  chmod 600 "$ENV_FILE"
  ok ".env generated"
}

create_docker_compose() {
  log "Creating docker-compose.yml..."
  
  cat > "$COMPOSE_FILE" << 'EOF'
version: '3.8'

services:
  db:
    image: postgres:16.4
    platform: linux/arm64
    container_name: supabase-db
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      POSTGRES_INITDB_ARGS: --data-checksums,--auth-host=md5
    volumes:
      - ./volumes/db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    deploy:
      resources:
        limits:
          memory: 1GB
          cpus: '1.5'

  auth:
    image: supabase/gotrue:v2.180.0
    platform: linux/arm64
    container_name: supabase-auth
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_SITE_URL: ${SITE_URL}
      GOTRUE_JWT_EXP: 3600
    deploy:
      resources:
        limits:
          memory: 128MB
          cpus: '0.5'

  realtime:
    image: supabase/realtime:v2.31.5
    platform: linux/arm64
    container_name: supabase-realtime
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      APP_NAME: supabase_realtime
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_ENC_KEY: ${DB_ENC_KEY}
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${JWT_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp
      DNS_NODES: ""
      DB_IP_VERSION: ipv4
      SEED_SELF_HOST: "true"
      RLIMIT_NOFILE: 65536
      MAX_CONNECTIONS: 10000
      DB_POOL_SIZE: 10
      TENANT_MAX_BYTES_PER_SECOND: 100000
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
    cap_add:
      - SYS_RESOURCE
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  rest:
    image: supabase/postgrest:v13.2.0
    platform: linux/arm64
    container_name: supabase-rest
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      PGRST_DB_URI: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
    deploy:
      resources:
        limits:
          memory: 128MB
          cpus: '0.5'

  storage:
    image: supabase/storage-api:v1.0.0
    platform: linux/arm64
    container_name: supabase-storage
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      ANON_KEY: ${ANON_KEY}
      SERVICE_KEY: ${SERVICE_ROLE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      STORAGE_S3_BUCKET: supabase-storage
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
    volumes:
      - ./volumes/storage:/var/lib/storage
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  meta:
    image: supabase/postgres-meta:v0.83.2
    platform: linux/arm64
    container_name: supabase-meta
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      PG_META_DB_HOST: db
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
      PG_META_PORT: 8080
    deploy:
      resources:
        limits:
          memory: 128MB
          cpus: '0.25'

  studio:
    image: supabase/studio:20250106-e00ba41
    platform: linux/arm64
    container_name: supabase-studio
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    ports:
      - "3000:3000"
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  edge-functions:
    image: supabase/edge-runtime:v1.58.2
    platform: linux/arm64
    container_name: supabase-edge-functions
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SERVICE_ROLE_KEY}
    volumes:
      - ./volumes/functions:/home/deno/functions
    deploy:
      resources:
        limits:
          memory: 128MB
          cpus: '0.5'

  kong:
    image: kong:3.8
    platform: linux/arm64
    container_name: supabase-kong
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    ports:
      - "8001:8000"
      - "8443:8443"
      - "8002:8001"
      - "8444:8444"
    environment:
      KONG_DATABASE: "off"
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /dev/stderr
      KONG_ADMIN_ERROR_LOG: /dev/stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
      KONG_ADMIN_GUI_URL: http://localhost:8002
      KONG_PROXY_LISTEN: 0.0.0.0:8000
    volumes:
      - ./config/kong.yml:/usr/local/kong/declarative/kong.yml:ro
    command: ["kong", "docker-start"]
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  imgproxy:
    image: darrenbritten/imgproxy-arm64:v3.24
    platform: linux/arm64
    container_name: supabase-imgproxy
    restart: unless-stopped
    environment:
      IMGPROXY_BIND: :8080
      IMGPROXY_USE_S3: false
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
    deploy:
      resources:
        limits:
          memory: 128MB
          cpus: '0.25'

networks:
  default:
    driver: bridge

EOF

  chown pi:pi "$COMPOSE_FILE"
  ok "docker-compose.yml created"
}

init_schema() {
  log "Initializing Auth schema..."
  docker compose up db -d
  sleep 30  # Wait for DB ready
  
  docker exec -it supabase-db psql -U postgres -d postgres << 'SQL'
CREATE SCHEMA IF NOT EXISTS auth;
CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
-- Add more types/tables as needed from GoTrue migrations
SQL
  ok "Schema initialized"
}

start_services() {
  log "Starting services..."
  cd "$PROJECT_DIR"
  docker compose up -d
  sleep 60  # Wait for init
  docker compose ps
  ok "Services started"
}

main() {
  require_root
  setup_logging
  check_prerequisites
  generate_env
  create_docker_compose
  init_schema
  start_services
  log "Installation complete. Access Studio at http://$(hostname -I | awk '{print $1}'):3000"
  log "API at http://$(hostname -I | awk '{print $1}'):8001"
  log "Check logs with: cd $PROJECT_DIR && docker compose logs"
}

main
