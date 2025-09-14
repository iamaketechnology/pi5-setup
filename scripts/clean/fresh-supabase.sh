#!/usr/bin/env bash
set -euo pipefail

# Fresh Supabase install on Pi 5 (clean reset + install)
# - Removes prior Supabase containers/volumes (data loss!)
# - Generates .env, docker-compose.yml, Kong config
# - Starts services and creates required DB users
# - Verifies Studio/API reachability
#
# Usage (recommended one-liner):
#   sudo bash pi5-setup/scripts/clean/fresh-supabase.sh
#
# Options:
#   ENV VARS:
#     SUPABASE_STACK_DIR=stacks/supabase   # relative to /home/<user>
#     NON_INTERACTIVE=1                    # skip confirmation prompts (DANGEROUS)
#     API_PORT=8001 STUDIO_PORT=3000 POSTGRES_PORT=5432  # override ports
#
# Notes:
# - Requires Docker + Compose v2 (installed by Week1 or system)
# - Keeps things ARM64-friendly and Pi‑compatible

log()  { echo -e "\033[1;36m[FRESH]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*"; }

require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo "Exécute: sudo $0"; exit 1;
  fi
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
}

defaults() {
  API_PORT="${API_PORT:-8001}"
  STUDIO_PORT="${STUDIO_PORT:-3000}"
  POSTGRES_PORT="${POSTGRES_PORT:-5432}"
  SUPABASE_STACK_DIR="${SUPABASE_STACK_DIR:-stacks/supabase}"
  PROJECT_DIR="$HOME_DIR/$SUPABASE_STACK_DIR"
  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "${LOCAL_IP:-}" ]] && LOCAL_IP="127.0.0.1"
}

check_prereqs() {
  log "Vérification prérequis…"
  if ! command -v docker >/dev/null 2>&1; then
    err "Docker absent. Exécute d'abord Week1 (installe Docker)."; exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    err "Docker Compose v2 absent (docker compose)."; exit 1
  fi
  PAGESIZE=$(getconf PAGESIZE 2>/dev/null || echo 0)
  if [[ "$PAGESIZE" == "16384" ]]; then
    err "Page size 16KB détectée. Configure kernel 4KB (kernel=kernel8.img) puis reboot."
    exit 1
  fi
  ok "Prérequis OK (page size: ${PAGESIZE}B)"
}

confirm_destroy() {
  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
    return
  fi
  echo
  warn "Cette opération VA SUPPRIMER les données Supabase existantes (volumes DB)."
  read -r -p "Continuer et tout réinitialiser ? (oui/non): " ans
  case "$ans" in
    oui|OUI|yes|YES|y|Y) ;; 
    *) err "Annulé par l'utilisateur."; exit 1 ;;
  esac
}

stop_and_nuke_previous() {
  log "Arrêt et suppression des ressources existantes…"
  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    (cd "$PROJECT_DIR" && su "$TARGET_USER" -c "docker compose down -v || true") || true
  fi
  # Supprimer conteneurs supabase-* orphelins
  ids=$(docker ps -aq --filter name='^supabase-') || ids=""
  if [[ -n "$ids" ]]; then
    docker rm -f $ids >/dev/null 2>&1 || true
  fi
  # Sauvegarder .env si présent
  if [[ -f "$PROJECT_DIR/.env" ]]; then
    cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup.$(date +%Y%m%d_%H%M%S)" || true
  fi
  # Purge des données DB
  rm -rf "$PROJECT_DIR/volumes/db/data" || true
  ok "Ancienne stack supprimée (si présente)."
}

create_structure() {
  log "Création structure $PROJECT_DIR…"
  mkdir -p "$PROJECT_DIR"/{config,volumes/{db/data,storage},scripts,logs}
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
  chmod 700 "$PROJECT_DIR/volumes/db/data"
  ok "Structure prête."
}

gen_secret() { # length
  local n=${1:-25}
  # base64 sans =+/ puis tronqué
  openssl rand -base64 48 | tr -d '=+/' | cut -c1-${n}
}

generate_env() {
  log "Génération .env…"
  local POSTGRES_PASSWORD=$(gen_secret 25)
  local AUTHENTICATOR_PASSWORD=$(gen_secret 25)
  local JWT_SECRET=$(openssl rand -hex 32)
  local ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg"
  local SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.OgkOPBjHiLl7u5_hVT7R0g2M1tSfr2sn4g8pGYKIqg4"

  cat > "$PROJECT_DIR/.env" <<EOF
# Auto-généré le $(date)

# Ports
API_PORT=$API_PORT
STUDIO_PORT=$STUDIO_PORT
POSTGRES_PORT=$POSTGRES_PORT

# URLs
API_EXTERNAL_URL=http://$LOCAL_IP:$API_PORT
SUPABASE_PUBLIC_URL=http://$LOCAL_IP:$API_PORT
SUPABASE_URL=http://kong:8000

# DB
POSTGRES_DB=postgres
POSTGRES_USER=supabase_admin
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Mots de passe rôles
AUTHENTICATOR_PASSWORD=$AUTHENTICATOR_PASSWORD
SUPABASE_STORAGE_PASSWORD=$POSTGRES_PASSWORD

# JWT/Keys
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY

# Tuning léger
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_EFFECTIVE_CACHE_SIZE=2GB
POSTGRES_WORK_MEM=32MB
POSTGRES_MAINTENANCE_WORK_MEM=128MB
POSTGRES_MAX_CONNECTIONS=100
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
  chmod 600 "$PROJECT_DIR/.env"
  ok ".env créé."
}

write_compose() {
  log "Écriture docker-compose.yml…"
  cat > "$PROJECT_DIR/docker-compose.yml" <<'EOF'
name: supabase

services:
  db:
    container_name: supabase-db
    image: postgres:15-alpine
    restart: unless-stopped
    ports:
      - "${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--data-checksums --auth-host=md5"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 20s
    volumes:
      - ./volumes/db/data:/var/lib/postgresql/data:Z

  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:v12.2.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://authenticator:${AUTHENTICATOR_PASSWORD}@db:5432/${POSTGRES_DB}
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
    restart: unless-stopped

  auth:
    container_name: supabase-auth
    image: supabase/gotrue:v2.177.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://supabase_admin:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
    restart: unless-stopped

  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.25.50
    depends_on:
      db:
        condition: service_healthy
    environment:
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: supabase_admin
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB}
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${JWT_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp
    restart: unless-stopped

  storage:
    container_name: supabase-storage
    image: supabase/storage-api:v1.11.6
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_started
    environment:
      ANON_KEY: ${SUPABASE_ANON_KEY}
      SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
    volumes:
      - ./volumes/storage:/var/lib/storage:z
    restart: unless-stopped

  imgproxy:
    container_name: supabase-imgproxy
    image: darthsim/imgproxy:v3.8.0
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
      IMGPROXY_USE_ETAG: "true"
      IMGPROXY_ENABLE_WEBP_DETECTION: "true"
    volumes:
      - ./volumes/storage:/var/lib/storage:z
    restart: unless-stopped

  meta:
    container_name: supabase-meta
    image: supabase/postgres-meta:v0.68.0
    depends_on:
      db:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: ${POSTGRES_DB}
      PG_META_DB_USER: supabase_admin
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    restart: unless-stopped

  kong:
    container_name: supabase-kong
    image: kong:3.0.0
    restart: unless-stopped
    entrypoint: bash -c 'eval "echo \"$$(cat /tmp/kong.yml)\"" > /tmp/kong.yml && /docker-entrypoint.sh kong docker-start'
    environment:
      KONG_DATABASE: 'off'
      KONG_DECLARATIVE_CONFIG: /tmp/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors
    volumes:
      - ./config/kong.yml:/tmp/kong.yml:ro
    ports:
      - "${API_PORT}:8000/tcp"

  studio:
    container_name: supabase-studio
    image: supabase/studio:20240101
    depends_on:
      auth:
        condition: service_started
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      SUPABASE_URL: http://kong:8000
      SUPABASE_REST_URL: ${SUPABASE_REST_URL:-http://kong:8000/rest/v1/}
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
    ports:
      - "${STUDIO_PORT}:3000"
    restart: unless-stopped

volumes:
  db_data:
  storage_data:

networks:
  default:
    name: supabase_network
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"
  ok "docker-compose.yml écrit."
}

write_kong_config() {
  log "Écriture config Kong…"
  cat > "$PROJECT_DIR/config/kong.yml" <<'EOF'
_format_version: "2.1"

upstreams:
  - name: auth
    targets:
      - target: auth:9999
  - name: rest
    targets:
      - target: rest:3000
  - name: realtime
    targets:
      - target: realtime:4000
  - name: storage
    targets:
      - target: storage:5000
  - name: meta
    targets:
      - target: meta:8080

services:
  - name: auth
    url: http://auth/
    routes:
      - name: auth
        paths: [ /auth/v1/ ]

  - name: rest
    url: http://rest/
    routes:
      - name: rest
        paths: [ /rest/v1/ ]

  - name: realtime
    url: http://realtime/
    routes:
      - name: realtime
        paths: [ /realtime/v1/ ]

  - name: storage
    url: http://storage/
    routes:
      - name: storage
        paths: [ /storage/v1/ ]

  - name: meta
    url: http://meta/
    routes:
      - name: meta
        paths: [ /pg/ ]

plugins:
  - name: cors
    config:
      origins: ["*"]
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"]
      headers: ["Accept", "Accept-Version", "Content-Length", "Content-MD5", "Content-Type", "Date", "X-Auth-Token", "Authorization", "X-Requested-With"]
      exposed_headers: ["X-Auth-Token"]
      credentials: true
      max_age: 3600
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/config/kong.yml"
  ok "Kong config écrite."
}

compose_up() {
  log "Démarrage des services…"
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --quiet-pull --force-recreate"
  ok "Conteneurs lancés."
}

wait_db_ready() {
  log "Attente DB prête…"
  local i=0
  while ! su "$TARGET_USER" -c "docker compose exec -T db pg_isready -U supabase_admin >/dev/null 2>&1"; do
    sleep 2; i=$((i+1)); [[ $i -gt 90 ]] && { err "Timeout DB"; exit 1; }
  done
  ok "DB prête."
}

create_db_users() {
  log "Création rôles DB…"
  local POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$PROJECT_DIR/.env" | cut -d= -f2)
  local AUTHENTICATOR_PASSWORD=$(grep '^AUTHENTICATOR_PASSWORD=' "$PROJECT_DIR/.env" | cut -d= -f2)

  su "$TARGET_USER" -c "docker compose exec -T db psql -U supabase_admin -d postgres <<SQL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '${AUTHENTICATOR_PASSWORD}';
  ELSE
    ALTER USER authenticator WITH PASSWORD '${AUTHENTICATOR_PASSWORD}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
    CREATE USER anon NOINHERIT LOGIN PASSWORD '${AUTHENTICATOR_PASSWORD}';
  ELSE
    ALTER USER anon WITH PASSWORD '${AUTHENTICATOR_PASSWORD}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '${POSTGRES_PASSWORD}';
  ELSE
    ALTER USER supabase_storage_admin WITH PASSWORD '${POSTGRES_PASSWORD}';
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO authenticator;
GRANT USAGE ON SCHEMA public TO anon;
SQL" >/dev/null
  ok "Rôles créés/mis à jour."
}

restart_dependents() {
  log "Redémarrage services dépendants…"
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --force-recreate auth rest storage realtime kong studio"
}

verify_health() {
  echo; log "Vérification santé…"
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'"
  local code_studio=$(curl -s -o /dev/null -w "%{http_code}" -I "http://localhost:${STUDIO_PORT}/" || echo 000)
  local code_api=$(curl -s -o /dev/null -w "%{http_code}" -I "http://localhost:${API_PORT}/rest/v1/" || echo 000)
  if [[ "$code_studio" != "000" ]]; then ok "Studio: HTTP $code_studio"; else warn "Studio injoignable"; fi
  if [[ "$code_api" != "000" ]]; then ok "API: HTTP $code_api"; else warn "API injoignable"; fi
}

summary() {
  echo
  echo "==================== 🎉 SUPABASE PRÊT ===================="
  echo "Studio      : http://${LOCAL_IP}:${STUDIO_PORT}"
  echo "API (REST)  : http://${LOCAL_IP}:${API_PORT}/rest/v1/"
  echo "Edge Funcs  : http://${LOCAL_IP}:54321/functions/v1/ (si ajouté)"
  echo "DB          : localhost:${POSTGRES_PORT} (user: supabase_admin)"
  echo "Env file    : ${PROJECT_DIR}/.env"
  echo "=========================================================="
}

main() {
  require_root
  detect_user
  defaults
  log "Installation fraîche Supabase pour $TARGET_USER → $PROJECT_DIR"
  check_prereqs
  confirm_destroy
  stop_and_nuke_previous
  create_structure
  generate_env
  write_compose
  write_kong_config
  compose_up
  wait_db_ready
  create_db_users
  restart_dependents
  verify_health
  summary
}

main "$@"

