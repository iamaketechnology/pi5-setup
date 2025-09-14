#!/usr/bin/env bash
set -euo pipefail

# One-shot Pi 5 Supabase reset + install
# - Installs Docker if missing, configures basics
# - Fixes page size and cgroups flags (reboot if needed)
# - NUKES previous Supabase data/containers (optionally entire Docker)
# - Deploys a clean Supabase stack and verifies health
#
# Usage (recommended):
#   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/clean/one-shot-supabase.sh | sudo NON_INTERACTIVE=1 bash
#
# Options via env vars:
#   NON_INTERACTIVE=1         # skip prompts (dangerous but convenient)
#   DESTROY_ALL_DOCKER=1      # docker system prune -af --volumes (very destructive)
#   REBOOT_IF_NEEDED=1        # auto-reboot if kernel flags changed
#   API_PORT=8001 STUDIO_PORT=3000 POSTGRES_PORT=5432 SUPABASE_STACK_DIR=stacks/supabase

log()  { echo -e "\033[1;36m[ONE-SHOT]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[1;31m[ERR]\033[0m $*"; }

require_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { echo "Exécute: sudo $0"; exit 1; }; }
detect_user()  { TARGET_USER="${SUDO_USER:-$USER}"; [[ "$TARGET_USER" == "root" ]] && HOME_DIR=/root || HOME_DIR=/home/$TARGET_USER; }
defaults() {
  API_PORT="${API_PORT:-8001}"; STUDIO_PORT="${STUDIO_PORT:-3000}"; POSTGRES_PORT="${POSTGRES_PORT:-5432}";
  SUPABASE_STACK_DIR="${SUPABASE_STACK_DIR:-stacks/supabase}"; PROJECT_DIR="$HOME_DIR/$SUPABASE_STACK_DIR";
  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}') || true; [[ -z "${LOCAL_IP:-}" ]] && LOCAL_IP=127.0.0.1;
}

ensure_base_packages() {
  log "Paquets de base + haveged…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y -qq
  apt-get install -y -qq ca-certificates curl gnupg lsb-release net-tools wget openssl haveged || true
  systemctl enable --now haveged 2>/dev/null || true
}

install_docker_if_missing() {
  if command -v docker >/dev/null 2>&1; then ok "Docker déjà installé"; return; fi
  log "Installation Docker CE + compose-plugin…"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"; arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {"max-size": "100m", "max-file": "3"},
  "storage-driver": "overlay2",
  "default-ulimits": {"nofile": {"Name": "nofile", "Hard": 65536, "Soft": 65536}}
}
JSON
  systemctl daemon-reload
  systemctl enable --now docker
  usermod -aG docker "$TARGET_USER" || true
  ok "Docker installé"
}

configure_kernel_flags() {
  local reboot_needed=0
  # Page size check
  local PAGESIZE=$(getconf PAGESIZE 2>/dev/null || echo 0)
  if [[ "$PAGESIZE" == "16384" ]]; then
    warn "Page size 16KB détectée → ajout kernel=kernel8.img"
    if [[ -f /boot/firmware/config.txt ]] && ! grep -q '^kernel=kernel8.img' /boot/firmware/config.txt; then
      echo "" >> /boot/firmware/config.txt
      echo "# Forcer kernel 4KB pagesize pour PostgreSQL/Supabase" >> /boot/firmware/config.txt
      echo "kernel=kernel8.img" >> /boot/firmware/config.txt
      reboot_needed=1
    fi
  fi
  # cgroups memory flags (optional but removes warnings)
  if [[ -f /boot/firmware/cmdline.txt ]] && ! grep -q 'cgroup_enable=memory' /boot/firmware/cmdline.txt; then
    warn "Activation cgroups mémoire dans cmdline.txt"
    sed -i '1 s/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
    reboot_needed=1
  fi
  if [[ $reboot_needed -eq 1 ]]; then
    if [[ "${REBOOT_IF_NEEDED:-0}" == "1" ]]; then
      warn "Redémarrage automatique dans 3s…"; sleep 3; reboot
    else
      err "Reboot requis. Redémarre puis relance la commande one-shot."
      exit 21
    fi
  fi
}

confirm_destroy() {
  if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then return; fi
  echo; warn "Cette procédure efface la stack Supabase et ses données (DB)."
  read -r -p "Continuer ? (oui/non): " ans; case "$ans" in oui|OUI|y|Y|yes|YES) ;; *) err "Annulé"; exit 1;; esac
}

nuke_previous() {
  log "Arrêt et purge Supabase…"
  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then (cd "$PROJECT_DIR" && su "$TARGET_USER" -c "docker compose down -v || true"); fi
  # Kill stray containers
  ids=$(docker ps -aq --filter name='^supabase-') || ids=""; [[ -n "$ids" ]] && docker rm -f $ids >/dev/null 2>&1 || true
  # Remove network
  docker network rm supabase_network >/dev/null 2>&1 || true
  # Optional full Docker wipe
  if [[ "${DESTROY_ALL_DOCKER:-0}" == "1" ]]; then
    warn "Docker prune total (images/volumes)…"
    docker system prune -af --volumes || true
  fi
  rm -rf "$PROJECT_DIR/volumes/db/data" || true
  ok "Purge effectuée"
}

create_structure() { mkdir -p "$PROJECT_DIR"/{config,volumes/{db/data,storage},scripts,logs}; chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"; chmod 700 "$PROJECT_DIR/volumes/db/data"; }

gen_secret() { openssl rand -base64 48 | tr -d '=+/' | cut -c1-${1:-25}; }

generate_env() {
  log "Génération .env…"
  local POSTGRES_PASSWORD=$(gen_secret 25)
  local AUTHENTICATOR_PASSWORD=$(gen_secret 25)
  local JWT_SECRET=$(openssl rand -hex 32)
  local ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg"
  local SERVICE_ROLE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.OgkOPBjHiLl7u5_hVT7R0g2M1tSfr2sn4g8pGYKIqg4"
  cat > "$PROJECT_DIR/.env" <<EOF
# Auto-généré le $(date)
API_PORT=$API_PORT
STUDIO_PORT=$STUDIO_PORT
POSTGRES_PORT=$POSTGRES_PORT
API_EXTERNAL_URL=http://$LOCAL_IP:$API_PORT
SUPABASE_PUBLIC_URL=http://$LOCAL_IP:$API_PORT
SUPABASE_URL=http://kong:8000
POSTGRES_DB=postgres
POSTGRES_USER=supabase_admin
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
AUTHENTICATOR_PASSWORD=$AUTHENTICATOR_PASSWORD
SUPABASE_STORAGE_PASSWORD=$POSTGRES_PASSWORD
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY
POSTGRES_SHARED_BUFFERS=512MB
POSTGRES_EFFECTIVE_CACHE_SIZE=2GB
POSTGRES_WORK_MEM=32MB
POSTGRES_MAINTENANCE_WORK_MEM=128MB
POSTGRES_MAX_CONNECTIONS=100
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"; chmod 600 "$PROJECT_DIR/.env"
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
}

write_kong() {
  cat > "$PROJECT_DIR/config/kong.yml" <<'EOF'
_format_version: "2.1"

upstreams:
  - name: auth
    targets: [ { target: auth:9999 } ]
  - name: rest
    targets: [ { target: rest:3000 } ]
  - name: realtime
    targets: [ { target: realtime:4000 } ]
  - name: storage
    targets: [ { target: storage:5000 } ]
  - name: meta
    targets: [ { target: meta:8080 } ]

services:
  - name: auth
    url: http://auth/
    routes: [ { name: auth, paths: [ /auth/v1/ ] } ]
  - name: rest
    url: http://rest/
    routes: [ { name: rest, paths: [ /rest/v1/ ] } ]
  - name: realtime
    url: http://realtime/
    routes: [ { name: realtime, paths: [ /realtime/v1/ ] } ]
  - name: storage
    url: http://storage/
    routes: [ { name: storage, paths: [ /storage/v1/ ] } ]
  - name: meta
    url: http://meta/
    routes: [ { name: meta, paths: [ /pg/ ] } ]

plugins:
  - name: cors
    config:
      origins: ["*"]
      methods: ["GET","POST","PUT","PATCH","DELETE","OPTIONS","HEAD"]
      headers: ["Accept","Content-Type","Authorization","X-Requested-With"]
      credentials: true
      max_age: 3600
EOF
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/config/kong.yml"
}

compose_up()       { su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --quiet-pull --force-recreate"; }
wait_db_ready()    { log "Attente DB…"; for i in {1..90}; do su "$TARGET_USER" -c "docker compose exec -T db pg_isready -U supabase_admin" >/dev/null 2>&1 && { ok "DB prête"; return; }; sleep 2; done; err "Timeout DB"; exit 2; }
create_roles() {
  log "Création/MAJ rôles…"
  local PWD=$(grep '^POSTGRES_PASSWORD=' "$PROJECT_DIR/.env" | cut -d= -f2)
  local AUTH=$(grep '^AUTHENTICATOR_PASSWORD=' "$PROJECT_DIR/.env" | cut -d= -f2)
  su "$TARGET_USER" -c "docker compose exec -T db psql -U supabase_admin -d postgres <<SQL
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '${AUTH}';
  ELSE
    ALTER USER authenticator WITH PASSWORD '${AUTH}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN
    CREATE USER anon NOINHERIT LOGIN PASSWORD '${AUTH}';
  ELSE
    ALTER USER anon WITH PASSWORD '${AUTH}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '${PWD}';
  ELSE
    ALTER USER supabase_storage_admin WITH PASSWORD '${PWD}';
  END IF;
END $$;
GRANT USAGE ON SCHEMA public TO authenticator;
GRANT USAGE ON SCHEMA public TO anon;
SQL" >/dev/null
}

recreate_dependents() { su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --force-recreate auth rest storage realtime kong studio"; }

verify() {
  echo; log "Vérification santé…"
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps --format 'table {{.Name}}\t{{.Status}}\t{{.Ports}}'"
  local a=$(curl -s -o /dev/null -w '%{http_code}' -I http://localhost:${API_PORT}/rest/v1/ || echo 000)
  local s=$(curl -s -o /dev/null -w '%{http_code}' -I http://localhost:${STUDIO_PORT}/ || echo 000)
  [[ "$a" != 000 ]] && ok "API: HTTP $a" || warn "API injoignable"
  [[ "$s" =~ ^(200|301|302|307)$ ]] && ok "Studio: HTTP $s" || warn "Studio injoignable (HTTP $s)"
}

summary() {
  echo
  echo "==================== 🎉 SUPABASE PRÊT ===================="
  echo "Studio      : http://${LOCAL_IP}:${STUDIO_PORT}"
  echo "API (REST)  : http://${LOCAL_IP}:${API_PORT}/rest/v1/"
  echo "DB          : localhost:${POSTGRES_PORT} (user: supabase_admin)"
  echo "Env file    : ${PROJECT_DIR}/.env"
  echo "Relancer si besoin: docker compose up -d --force-recreate"
  echo "=========================================================="
}

main() {
  require_root; detect_user; defaults
  log "One-shot Supabase pour $TARGET_USER → $PROJECT_DIR"
  ensure_base_packages
  install_docker_if_missing
  configure_kernel_flags
  confirm_destroy
  nuke_previous
  create_structure
  generate_env
  write_compose
  write_kong
  compose_up
  wait_db_ready
  create_roles
  recreate_dependents
  verify
  summary
}

main "$@"

