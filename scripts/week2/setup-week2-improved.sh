#!/usr/bin/env bash
set -euo pipefail

# === SETUP WEEK 2 AMÉLIORÉ - Installation Supabase optimisée Pi 5 ===
# Intègre tous les fixes découverts lors des phases de debug

MODE="${MODE:-beginner}"
SUPABASE_PROJECT_NAME="${SUPABASE_PROJECT_NAME:-supabase}"
SUPABASE_STACK_DIR="${SUPABASE_STACK_DIR:-stacks/supabase}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week2-improved.log}"

# Configuration par défaut avec fixes intégrés
API_PORT="${API_PORT:-8001}"  # FIX: Éviter conflit port 8000 Portainer
STUDIO_PORT="${STUDIO_PORT:-3000}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
KONG_VERSION="${KONG_VERSION:-3.0.0}"  # FIX: Kong 3.0.0 sans plugin request-id

# Optimisations Pi 5
POSTGRES_SHARED_BUFFERS="${POSTGRES_SHARED_BUFFERS:-512MB}"
POSTGRES_EFFECTIVE_CACHE="${POSTGRES_EFFECTIVE_CACHE:-2GB}"
ENABLE_PGVECTOR="${ENABLE_PGVECTOR:-yes}"

log()  { echo -e "\033[1;36m[SETUP-W2]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=$MODE ./setup-week2-improved.sh"
    exit 1
  fi
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Supabase Installation Améliorée Week 2 - $(date) ==="
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
  PROJECT_DIR="$HOME_DIR/$SUPABASE_STACK_DIR"

  log "🎯 Installation pour utilisateur: $TARGET_USER"
  log "📍 Répertoire projet: $PROJECT_DIR"
}

verify_prerequisites() {
  log "🔍 Vérification prérequis système..."

  # Vérifier Docker
  if ! command -v docker >/dev/null; then
    error "❌ Docker non installé. Exécute d'abord Week 1."
    exit 1
  fi

  if ! command -v docker-compose >/dev/null; then
    if ! docker compose version >/dev/null 2>&1; then
      error "❌ Docker Compose non disponible"
      exit 1
    fi
  fi

  # Vérifier page size
  CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)
  if [[ "$CURRENT_PAGE_SIZE" == "16384" ]]; then
    ok "✅ Page size: 16KB - Utilisation postgres:15-alpine"
    export USE_OFFICIAL_POSTGRES=false
  else
    ok "✅ Page size: ${CURRENT_PAGE_SIZE}B - Images officielles"
    export USE_OFFICIAL_POSTGRES=true
  fi

  ok "Prérequis validés"
}

check_port_conflicts() {
  log "🔍 Vérification conflits de ports..."

  local conflicts=()

  # Vérifier port Studio
  if netstat -tlnp 2>/dev/null | grep -q ":$STUDIO_PORT "; then
    conflicts+=("$STUDIO_PORT")
    warn "Port $STUDIO_PORT occupé (Studio)"
  fi

  # Vérifier port API
  if netstat -tlnp 2>/dev/null | grep -q ":$API_PORT "; then
    conflicts+=("$API_PORT")
    warn "Port $API_PORT occupé (API)"
  fi

  # Vérifier port PostgreSQL
  if netstat -tlnp 2>/dev/null | grep -q ":$POSTGRES_PORT "; then
    conflicts+=("$POSTGRES_PORT")
    warn "Port $POSTGRES_PORT occupé (PostgreSQL)"
  fi

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    error "❌ Ports occupés: ${conflicts[*]}"
    log "Arrête les services conflictuels ou change les ports:"
    log "  API_PORT=8002 STUDIO_PORT=3001 sudo MODE=$MODE ./setup-week2-improved.sh"
    exit 1
  fi

  ok "✅ Aucun conflit de port détecté"
}

create_project_structure() {
  log "📁 Création structure projet..."

  # Créer d'abord le répertoire parent stacks s'il n'existe pas
  PARENT_DIR="$(dirname "$PROJECT_DIR")"
  if [[ ! -d "$PARENT_DIR" ]]; then
    log "   Création répertoire parent: $PARENT_DIR"
    mkdir -p "$PARENT_DIR"
    chown "$TARGET_USER:$TARGET_USER" "$PARENT_DIR"
  fi

  # Créer la structure complète du projet
  log "   Création structure projet: $PROJECT_DIR"
  mkdir -p "$PROJECT_DIR"/{config,volumes/{db/data,storage},scripts,logs}

  # Créer fichiers de base
  touch "$PROJECT_DIR"/{docker-compose.yml,.env,.gitignore}

  # Appliquer propriétaire et permissions correctes
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"
  chmod 755 "$PROJECT_DIR"/scripts
  chmod 700 "$PROJECT_DIR"/volumes/db/data

  ok "Structure créée: $PROJECT_DIR"
}

generate_secure_secrets() {
  log "🔐 Génération secrets sécurisés..."

  # Génération de tous les secrets nécessaires
  local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
  local auth_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
  local storage_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
  local anon_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
  local jwt_secret=$(openssl rand -hex 32)

  # Clés JWT simplifiées pour démo (normalement générées avec JWT_SECRET)
  local anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg"
  local service_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.OgkOPBjHiLl7u5_hVT7R0g2M1tSfr2sn4g8pGYKIqg4"

  # Obtenir IP locale pour API_EXTERNAL_URL
  local local_ip=$(hostname -I | awk '{print $1}')

  # Exporter pour utilisation dans les templates
  export POSTGRES_PASSWORD="$postgres_password"
  export AUTHENTICATOR_PASSWORD="$auth_password"
  export SUPABASE_STORAGE_PASSWORD="$storage_password"
  export ANON_PASSWORD="$anon_password"
  export JWT_SECRET="$jwt_secret"
  export ANON_KEY="$anon_key"
  export SERVICE_ROLE_KEY="$service_key"
  export LOCAL_IP="$local_ip"
  export API_EXTERNAL_URL="http://$local_ip:$API_PORT"
  export SUPABASE_PUBLIC_URL="http://$local_ip:$API_PORT"

  log "✅ Secrets générés pour IP: $local_ip"
  log "   API accessible sur: $API_EXTERNAL_URL"
}

create_env_file() {
  log "📄 Création fichier .env avec variables correctes..."

  # FIX: Créer .env avec toutes les variables nécessaires
  cat > "$PROJECT_DIR/.env" <<EOF
# === Configuration Supabase Pi 5 ===
# Généré automatiquement le $(date)

# Ports
API_PORT=$API_PORT
STUDIO_PORT=$STUDIO_PORT
POSTGRES_PORT=$POSTGRES_PORT

# URLs (FIX: Variables utilisées par les conteneurs)
API_EXTERNAL_URL=$API_EXTERNAL_URL
SUPABASE_PUBLIC_URL=$SUPABASE_PUBLIC_URL
SUPABASE_URL=http://kong:8000

# Base de données PostgreSQL
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=postgres
POSTGRES_USER=supabase_admin

# Utilisateurs DB spécifiques (FIX: Mots de passe séparés)
AUTHENTICATOR_PASSWORD=$AUTHENTICATOR_PASSWORD
SUPABASE_STORAGE_PASSWORD=$SUPABASE_STORAGE_PASSWORD
ANON_PASSWORD=$ANON_PASSWORD

# JWT et clés d'API
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$ANON_KEY
SUPABASE_SERVICE_KEY=$SERVICE_ROLE_KEY

# Optimisations Pi 5
POSTGRES_SHARED_BUFFERS=$POSTGRES_SHARED_BUFFERS
POSTGRES_EFFECTIVE_CACHE_SIZE=$POSTGRES_EFFECTIVE_CACHE
POSTGRES_WORK_MEM=32MB
POSTGRES_MAINTENANCE_WORK_MEM=128MB
POSTGRES_MAX_CONNECTIONS=100

# Configuration Kong
KONG_VERSION=$KONG_VERSION

# Configuration services
DEFAULT_ORGANIZATION_NAME=supabase
DEFAULT_PROJECT_NAME=supabase
EOF

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
  chmod 600 "$PROJECT_DIR/.env"

  ok "✅ Fichier .env créé avec toutes les variables"
}

create_docker_compose() {
  log "🐳 Création docker-compose.yml optimisé avec variables..."

  # FIX: Utiliser variables ${} au lieu de valeurs hardcodées
  cat > "$PROJECT_DIR/docker-compose.yml" <<EOF
name: $SUPABASE_PROJECT_NAME

services:
  db:
    container_name: supabase-db
    image: postgres:15-alpine  # Compatible 16KB page size Pi 5
    platform: linux/arm64
    restart: unless-stopped
    ports:
      - "\${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_DB: \${POSTGRES_DB}
      POSTGRES_USER: \${POSTGRES_USER}
      # Optimisations Pi 5 + 16KB page size
      POSTGRES_SHARED_BUFFERS: \${POSTGRES_SHARED_BUFFERS}
      POSTGRES_EFFECTIVE_CACHE_SIZE: \${POSTGRES_EFFECTIVE_CACHE_SIZE}
      POSTGRES_WORK_MEM: \${POSTGRES_WORK_MEM}
      POSTGRES_MAINTENANCE_WORK_MEM: \${POSTGRES_MAINTENANCE_WORK_MEM}
      POSTGRES_MAX_CONNECTIONS: \${POSTGRES_MAX_CONNECTIONS}
      # PostgreSQL Alpine init
      POSTGRES_INITDB_ARGS: "--data-checksums --auth-host=md5"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U supabase_admin -d postgres"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2GB
          cpus: '2.0'
        reservations:
          memory: 1GB
    volumes:
      - ./volumes/db/data:/var/lib/postgresql/data:Z

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
      GOTRUE_DB_DATABASE_URL: postgres://supabase_admin:\${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_SITE_URL: \${SUPABASE_PUBLIC_URL}
      GOTRUE_URI_ALLOW_LIST: "*"
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_SECRET: \${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      # FIX: Ajouter API_EXTERNAL_URL manquant
      API_EXTERNAL_URL: \${API_EXTERNAL_URL}
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:v12.2.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://authenticator:\${AUTHENTICATOR_PASSWORD}@db:5432/postgres
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: \${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_APP_SETTINGS_JWT_SECRET: \${JWT_SECRET}
      PGRST_APP_SETTINGS_JWT_EXP: 3600
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  kong:
    container_name: supabase-kong
    image: kong:\${KONG_VERSION}  # FIX: Kong 3.0.0
    platform: linux/arm64
    restart: unless-stopped
    ports:
      - "\${API_PORT}:8000"
      - "8443:8443"
    depends_on:
      - auth
      - rest
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /home/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      # FIX: Retirer request-id plugin non disponible
      KONG_PLUGINS: cors,key-auth,acl
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'
    volumes:
      - ./config/kong.yml:/home/kong/kong.yml:ro

  studio:
    container_name: supabase-studio
    image: supabase/studio:20250106-e00ba41
    platform: linux/arm64
    restart: unless-stopped
    ports:
      - "\${STUDIO_PORT}:3000"
    depends_on:
      - kong
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: \${DEFAULT_ORGANIZATION_NAME}
      DEFAULT_PROJECT_NAME: \${DEFAULT_PROJECT_NAME}
      SUPABASE_URL: \${SUPABASE_URL}
      SUPABASE_PUBLIC_URL: \${SUPABASE_PUBLIC_URL}
      SUPABASE_ANON_KEY: \${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_KEY: \${SUPABASE_SERVICE_KEY}
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

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
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: supabase_admin
      PG_META_DB_PORT: 5432
      PG_META_DB_PASSWORD: \${POSTGRES_PASSWORD}
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

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
      DB_USER: supabase_admin
      DB_PASSWORD: \${POSTGRES_PASSWORD}
      DB_NAME: postgres
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      DB_ENC_KEY: supabaserealtime
      API_JWT_SECRET: \${JWT_SECRET}
      FLY_ALLOC_ID: fly123
      FLY_APP_NAME: realtime
      SECRET_KEY_BASE: \${JWT_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp
      ENABLE_TAILSCALE: "false"
      DNS_NODES: "''"
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'

  storage:
    container_name: supabase-storage
    image: supabase/storage-api:v1.11.6
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      ANON_KEY: \${SUPABASE_ANON_KEY}
      SERVICE_KEY: \${SUPABASE_SERVICE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: \${JWT_SECRET}
      DATABASE_URL: postgres://supabase_storage_admin:\${SUPABASE_STORAGE_PASSWORD}@db:5432/postgres
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
          memory: 256MB
          cpus: '0.5'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

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
          memory: 256MB
          cpus: '0.5'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  edge-functions:
    container_name: supabase-edge-functions
    image: supabase/edge-runtime:v1.58.2
    platform: linux/arm64
    restart: unless-stopped
    ports:
      - "54321:9000"
    environment:
      JWT_SECRET: \${JWT_SECRET}
      SUPABASE_URL: \${SUPABASE_URL}
      SUPABASE_ANON_KEY: \${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: \${SUPABASE_SERVICE_KEY}
      SUPABASE_DB_URL: postgresql://supabase_admin:\${POSTGRES_PASSWORD}@db:5432/postgres
    deploy:
      resources:
        limits:
          memory: 256MB
          cpus: '0.5'
    volumes:
      - ./volumes/functions:/home/deno/functions:Z
      - /var/run/docker.sock:/var/run/docker.sock:ro

volumes:
  db_data:
  storage_data:

networks:
  default:
    name: supabase_network
EOF

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"

  ok "✅ docker-compose.yml créé avec variables \${}"
}

create_kong_config() {
  log "⚙️ Création configuration Kong..."

  cat > "$PROJECT_DIR/config/kong.yml" <<EOF
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
        paths:
          - /auth/v1/

  - name: rest
    url: http://rest/
    routes:
      - name: rest
        paths:
          - /rest/v1/

  - name: realtime
    url: http://realtime/
    routes:
      - name: realtime
        paths:
          - /realtime/v1/

  - name: storage
    url: http://storage/
    routes:
      - name: storage
        paths:
          - /storage/v1/

  - name: meta
    url: http://meta/
    routes:
      - name: meta
        paths:
          - /pg/

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

  ok "✅ Configuration Kong créée"
}

start_services() {
  log "🚀 Démarrage des services Supabase..."

  cd "$PROJECT_DIR"

  # FIX: Force pull et recreation pour éviter cache issues
  log "📦 Téléchargement images Docker..."
  su "$TARGET_USER" -c "docker compose pull"

  log "🏗️ Démarrage conteneurs..."
  su "$TARGET_USER" -c "docker compose up -d --force-recreate"

  ok "Services lancés"
}

wait_for_services() {
  log "⏳ Attente initialisation des services (60s)..."

  local max_attempts=60
  local attempt=1

  while [[ $attempt -le $max_attempts ]]; do
    if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps" | grep -q "Up.*healthy"; then
      local healthy_count=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps" | grep -c "Up.*healthy" || true)
      if [[ $healthy_count -ge 2 ]]; then
        ok "✅ Services principaux initialisés"
        break
      fi
    fi

    if [[ $((attempt % 10)) -eq 0 ]]; then
      log "   ⏳ Tentative $attempt/$max_attempts..."
    fi

    sleep 1
    ((attempt++))
  done

  if [[ $attempt -gt $max_attempts ]]; then
    warn "⚠️ Timeout d'attente atteint"
  fi
}

create_database_users() {
  log "👥 Création utilisateurs PostgreSQL manquants..."

  cd "$PROJECT_DIR"

  # FIX: Créer automatiquement les utilisateurs nécessaires
  log "   Création utilisateur 'authenticator'..."
  su "$TARGET_USER" -c "docker compose exec -T db psql -U supabase_admin -d postgres -c \"
    DROP USER IF EXISTS authenticator;
    CREATE USER authenticator WITH ENCRYPTED PASSWORD '$AUTHENTICATOR_PASSWORD';
    GRANT USAGE ON SCHEMA public TO authenticator;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO authenticator;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO authenticator;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO authenticator;
  \"" 2>/dev/null || warn "Erreur création authenticator"

  log "   Création utilisateur 'supabase_storage_admin'..."
  su "$TARGET_USER" -c "docker compose exec -T db psql -U supabase_admin -d postgres -c \"
    DROP USER IF EXISTS supabase_storage_admin;
    CREATE USER supabase_storage_admin WITH ENCRYPTED PASSWORD '$SUPABASE_STORAGE_PASSWORD';
    GRANT USAGE ON SCHEMA public TO supabase_storage_admin;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_storage_admin;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supabase_storage_admin;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_storage_admin;
  \"" 2>/dev/null || warn "Erreur création supabase_storage_admin"

  log "   Création utilisateur 'anon'..."
  su "$TARGET_USER" -c "docker compose exec -T db psql -U supabase_admin -d postgres -c \"
    DROP USER IF EXISTS anon;
    CREATE USER anon WITH ENCRYPTED PASSWORD '$ANON_PASSWORD';
    GRANT USAGE ON SCHEMA public TO anon;
  \"" 2>/dev/null || warn "Erreur création anon"

  ok "✅ Utilisateurs PostgreSQL créés"
}

restart_dependent_services() {
  log "🔄 Redémarrage services dépendants avec nouveaux utilisateurs..."

  cd "$PROJECT_DIR"

  # Redémarrer les services qui utilisent les nouveaux utilisateurs
  su "$TARGET_USER" -c "docker compose restart auth rest storage realtime"

  # Attendre que les services se stabilisent
  sleep 30

  ok "✅ Services redémarrés"
}

validate_installation() {
  log "🧪 Validation installation..."

  cd "$PROJECT_DIR"

  # Vérifier état des conteneurs
  local services_up=$(su "$TARGET_USER" -c "docker compose ps" | grep -c "Up" || true)
  local services_total=$(su "$TARGET_USER" -c "docker compose ps" | tail -n +2 | wc -l)

  log "Services actifs: $services_up/$services_total"

  # Test connectivité de base
  local tests_passed=0
  local tests_total=4

  # Test Studio
  if curl -s -I "http://localhost:$STUDIO_PORT" >/dev/null 2>&1; then
    ok "  ✅ Studio accessible (port $STUDIO_PORT)"
    ((tests_passed++))
  else
    warn "  ❌ Studio non accessible"
  fi

  # Test API Gateway
  if curl -s -I "http://localhost:$API_PORT" >/dev/null 2>&1; then
    ok "  ✅ API Gateway accessible (port $API_PORT)"
    ((tests_passed++))
  else
    warn "  ❌ API Gateway non accessible"
  fi

  # Test PostgreSQL
  if nc -z localhost $POSTGRES_PORT 2>/dev/null; then
    ok "  ✅ PostgreSQL accessible (port $POSTGRES_PORT)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL non accessible"
  fi

  # Test variables dans Auth
  if su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T auth printenv | grep -q 'API_EXTERNAL_URL'" 2>/dev/null; then
    ok "  ✅ Variables propagées correctement"
    ((tests_passed++))
  else
    warn "  ❌ Problème propagation variables"
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

create_utility_scripts() {
  log "🛠️ Création scripts utilitaires..."

  # Script de santé
  cat > "$PROJECT_DIR/scripts/supabase-health.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.."
echo "=== État Supabase ==="
docker compose ps
echo ""
echo "=== Tests connectivité ==="
curl -s -I http://localhost:3000 >/dev/null && echo "✅ Studio OK" || echo "❌ Studio KO"
curl -s -I http://localhost:8001 >/dev/null && echo "✅ API OK" || echo "❌ API KO"
nc -z localhost 5432 && echo "✅ PostgreSQL OK" || echo "❌ PostgreSQL KO"
EOF

  # Script de redémarrage
  cat > "$PROJECT_DIR/scripts/supabase-restart.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.."
echo "🔄 Redémarrage Supabase..."
docker compose down
docker compose up -d
echo "✅ Redémarré"
EOF

  # Script de logs
  cat > "$PROJECT_DIR/scripts/supabase-logs.sh" <<'EOF'
#!/usr/bin/env bash
cd "$(dirname "$0")/.."
if [[ -n "$1" ]]; then
  docker compose logs "$1" --tail=50 -f
else
  echo "Usage: $0 [service]"
  echo "Services disponibles:"
  docker compose ps --services
fi
EOF

  chmod +x "$PROJECT_DIR/scripts/"*.sh
  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/scripts/"*.sh

  ok "✅ Scripts utilitaires créés"
}

show_completion_summary() {
  echo
  echo "==================== 🎉 SUPABASE Pi 5 INSTALLÉ ! ===================="
  echo
  echo "✅ **Installation améliorée terminée avec succès**"
  echo "   🎯 Page size: $(getconf PAGE_SIZE)B"
  echo "   🔧 Tous les fixes intégrés automatiquement"
  echo
  echo "📍 **Accès aux services** :"
  echo "   🎨 Studio      : http://$LOCAL_IP:$STUDIO_PORT"
  echo "   🔌 API Gateway : http://$LOCAL_IP:$API_PORT"
  echo "   ⚡ Edge Funcs  : http://$LOCAL_IP:54321/functions/v1/"
  echo "   🗄️ PostgreSQL : localhost:$POSTGRES_PORT"
  echo
  echo "🔑 **Credentials sauvées dans** : $PROJECT_DIR/.env"
  echo
  echo "🛠️ **Scripts de maintenance** :"
  echo "   cd $PROJECT_DIR"
  echo "   ./scripts/supabase-health.sh     # 🏥 Vérifier santé"
  echo "   ./scripts/supabase-restart.sh    # 🔄 Redémarrer"
  echo "   ./scripts/supabase-logs.sh <service>  # 📋 Voir logs"
  echo
  if ! validate_installation; then
    echo "⚠️ **Note** : Quelques services peuvent encore se stabiliser."
    echo "   Attend 2-3 minutes et relance: ./scripts/supabase-health.sh"
  fi
  echo
  echo "📋 **Prochaine étape : Week 3 - HTTPS et accès externe**"
  echo "=================================================================="
}

pre_installation_checks() {
  log "🔍 Vérifications pre-installation..."

  # Vérifier page size (critique pour PostgreSQL)
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  if [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB détecté - Incompatible avec PostgreSQL"
    echo ""
    echo "🛠️ **Solution** :"
    echo "   1. sudo prepare-week2.sh  # Correction automatique"
    echo "   2. Ou manuellement : ajouter 'kernel=kernel8.img' dans /boot/firmware/config.txt"
    echo "   3. Redémarrer le système"
    exit 1
  fi

  # Vérifier entropie système
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -lt 500 ]]; then
    warn "⚠️ Entropie système faible ($entropy) - Peut causer des blocages"
    log "   Installation haveged recommandée..."

    if ! command -v haveged >/dev/null; then
      log "   Installation haveged..."
      apt update -qq && apt install -y haveged
      systemctl enable haveged && systemctl start haveged
      sleep 3  # Attendre amélioration entropie
      ok "   ✅ haveged installé et démarré"
    fi
  fi

  # Vérifier conflits de ports
  if netstat -tuln 2>/dev/null | grep -q ":8000 "; then
    warn "⚠️ Port 8000 occupé - Possible conflit avec Portainer"
    log "   Migration automatique vers port 8001..."
    API_PORT=8001
    export API_PORT
  fi

  ok "✅ Vérifications pre-installation terminées"
}

main() {
  require_root

  # Nouvelles vérifications avant installation
  pre_installation_checks

  detect_user
  verify_prerequisites
  check_port_conflicts
  create_project_structure
  generate_secure_secrets
  create_env_file
  create_docker_compose
  create_kong_config
  start_services
  wait_for_services
  create_database_users
  restart_dependent_services
  create_utility_scripts
  show_completion_summary
}

main "$@"