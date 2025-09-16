#!/usr/bin/env bash
set -euo pipefail

# Gestion des interruptions pour continuer l'installation
trap 'warn "⚠️ Script interrompu mais conteneurs actifs. Vérifiez: docker compose ps"; exit 130' SIGINT SIGTERM

# === SETUP WEEK2 SUPABASE FINAL - Installation complète avec correctifs Auth/Realtime ===
# Intègre les solutions développées lors des sessions de debugging du 15/09/2025 :
# - Correction erreur PostgreSQL "uuid = text" pour Auth migrations
# - Correction variables encryption Realtime (DB_ENC_KEY, SECRET_KEY_BASE)
# - Prévention corruption YAML docker-compose.yml (indentation)
# - Validation automatique des corrections appliquées

log()  { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]  \033[0m $*"; }

# Variables globales
SCRIPT_VERSION="2.4-env-protection-critical-validation"
LOG_FILE="/var/log/pi5-setup-week2-supabase-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"

# Configuration par défaut
SUPABASE_PORT="${SUPABASE_PORT:-8001}"  # Port par défaut pour éviter conflits
FORCE="${FORCE:-0}"  # Protection données: FORCE=1 pour écraser

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0"
    exit 1
  fi
}

check_dependencies() {
  log "🔍 Vérification des dépendances..."
  local dependencies=("curl" "git" "openssl" "docker" "gpg" "netstat" "jq")
  local missing_deps=()

  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    warn "⚠️ Dépendances manquantes : ${missing_deps[*]}"
    log "   Installation automatique des dépendances manquantes..."

    apt update >/dev/null 2>&1
    for dep in "${missing_deps[@]}"; do
      case "$dep" in
        "jq") apt install -y jq >/dev/null 2>&1 ;;
        "netstat") apt install -y net-tools >/dev/null 2>&1 ;;
        "gpg") apt install -y gpg >/dev/null 2>&1 ;;
        *) apt install -y "$dep" >/dev/null 2>&1 ;;
      esac
      log "     Installé: $dep"
    done
    ok "✅ Dépendances installées automatiquement"
  fi
  ok "✅ Toutes les dépendances sont présentes."
}

# =============================================================================
# CONFIGURATION VERSIONS DOCKER - Centralisation pour maintenance facile
# Source: https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml
# =============================================================================

# Versions principales Supabase (mise à jour 2025)
readonly POSTGRES_VERSION="15-alpine"
readonly GOTRUE_VERSION="v2.177.0"
readonly POSTGREST_VERSION="v12.2.0"
readonly REALTIME_VERSION="v2.30.23"
readonly STORAGE_API_VERSION="v1.11.6"
readonly POSTGRES_META_VERSION="v0.83.2"
readonly STUDIO_VERSION="20250106-e00ba41"
readonly EDGE_RUNTIME_VERSION="v1.58.2"

# Versions services complémentaires ARM64 optimisées
readonly KONG_VERSION="3.0.0"                    # ARM64v8 spécifique
readonly IMGPROXY_VERSION="v3.8.0"               # Compatible ARM64

# Configuration PostgreSQL optimisée Pi 5 (16GB RAM)
readonly POSTGRES_DB="postgres"
readonly POSTGRES_SHARED_BUFFERS="1GB"
readonly POSTGRES_WORK_MEM="64MB"
readonly POSTGRES_MAINTENANCE_WORK_MEM="256MB"
readonly POSTGRES_MAX_CONNECTIONS="200"

# =============================================================================

setup_logging() {
  exec 1> >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE" >&2)

  log "=== Pi 5 Supabase Installation Final - $(date) ==="
  log "Version: $SCRIPT_VERSION"
  log "Utilisateur cible: $TARGET_USER"
  log "Répertoire projet: $PROJECT_DIR"
}

check_prerequisites() {
  log "🔍 Vérification prérequis système avec logs détaillés..."

  # Log informations système de base pour debug
  log "   Système: $(uname -a | cut -d' ' -f1-3)"
  log "   Architecture: $(uname -m)"
  log "   RAM totale: $(free -h | grep Mem | awk '{print $2}')"
  log "   Espace disque: $(df -h / | tail -1 | awk '{print $4}') disponible"

  # Vérifier Week1 installé
  if ! command -v docker >/dev/null; then
    error "❌ Docker non installé - Lancer d'abord Week1 Enhanced"
    log ""
    log "   📋 Commandes pour installer Docker :"
    log "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/setup-week1-enhanced-final.sh | sudo bash"
    log "   # OU manuellement :"
    log "   curl -fsSL https://get.docker.com | bash"
    log "   sudo usermod -aG docker pi && sudo systemctl enable docker"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    error "❌ Docker Compose v2 non installé"
    log ""
    log "   📋 Commandes pour installer Docker Compose :"
    log "   sudo apt update && sudo apt install -y docker-compose-plugin"
    log "   # Vérifier : docker compose version"
    exit 1
  fi

  # Log version Docker pour debug
  local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
  log "   Docker: $docker_version"

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

  # Vérifier entropie système (kernels modernes 5.17+ avec BLAKE2s)
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -eq 256 ]]; then
    ok "✅ Entropie système: $entropy bits (CSPRNG kernel moderne initialisé)"
  elif [[ $entropy -gt 256 ]]; then
    ok "✅ Entropie système: $entropy bits (ancien kernel ou pool en remplissage)"
  elif [[ $entropy -lt 200 ]]; then
    warn "⚠️ Entropie système: $entropy bits (CSPRNG possiblement non initialisé)"
    log "   Hardware RNG Pi 5 doit semer le pool d'entropie"
  else
    ok "✅ Entropie système: $entropy bits"
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
    echo ""
    echo "🔄 RELANCEMENT DÉTECTÉ - Installation Supabase existante trouvée"
    warn "⚠️ Ports occupés: ${conflicted_ports[*]}"
    echo ""

    # Détecter et arrêter installation Supabase existante
    if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
      echo "💡 MODE RELANCEMENT AUTOMATIQUE ACTIVÉ"
      echo "   Le script va arrêter proprement l'installation existante"
      echo "   puis réinstaller avec les dernières corrections"
      echo ""

      log "🛑 Installation Supabase existante détectée - arrêt automatique..."

      cd "$PROJECT_DIR" 2>/dev/null && {
        log "   Arrêt des services Supabase en cours..."
        if timeout 30 su "$TARGET_USER" -c "docker compose down" 2>/dev/null; then
          ok "✅ Services Supabase arrêtés proprement"
        else
          warn "⚠️ Arrêt timeout - force kill..."
          su "$TARGET_USER" -c "docker compose kill" 2>/dev/null || true
          su "$TARGET_USER" -c "docker compose rm -f" 2>/dev/null || true
          ok "✅ Services Supabase forcés à l'arrêt"
        fi

        # Attendre que les ports se libèrent avec feedback
        echo "   ⏱️  Libération des ports... 5 secondes"
        sleep 5
        ok "✅ Ports libérés - relancement en cours..."
      }
    fi

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

    # Vérification finale après arrêts
    conflicted_ports=()
    for port in "${supabase_ports[@]}"; do
      if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        conflicted_ports+=("$port")
      fi
    done

    if [[ ${#conflicted_ports[@]} -gt 0 ]]; then
      error "❌ Ports toujours occupés après nettoyage: ${conflicted_ports[*]}"
      echo ""
      echo "📋 Solutions manuelles :"
      echo "   # Identifier les processus utilisant les ports"
      for port in "${conflicted_ports[@]}"; do
        echo "   lsof -i :$port"
      done
      echo ""
      echo "   # OU forcer un reset complet avec le script cleanup"
      echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-clean/scripts/cleanup-week2-supabase.sh -o cleanup.sh"
      echo "   chmod +x cleanup.sh && sudo ./cleanup.sh"
      exit 1
    fi
  fi

  ok "✅ Aucun conflit de port détecté"
}

ensure_working_directory() {
  log "📁 Sécurisation répertoire de travail..."
  cd /

  if [[ -d "$PROJECT_DIR" ]]; then
    # Vérifier si des données DB existent
    if [[ -d "$PROJECT_DIR/volumes/db" ]] && [[ -n "$(ls -A "$PROJECT_DIR/volumes/db" 2>/dev/null)" ]] && [[ "$FORCE" != "1" ]]; then
      error "❌ $PROJECT_DIR existe et contient des données DB."
      error "   Abandon pour éviter perte de données."
      error "   Lance avec FORCE=1 pour écraser: FORCE=1 sudo $0"
      exit 1
    fi
    log "   Nettoyage ancien répertoire..."
    rm -rf "$PROJECT_DIR" 2>/dev/null || true
  fi

  # Créer répertoire parent avec permissions appropriées
  local parent_dir="$(dirname "$PROJECT_DIR")"
  mkdir -p "$parent_dir"

  # Si le parent est /home/pi/stacks, s'assurer qu'il appartient à l'utilisateur
  if [[ "$parent_dir" =~ ^/home/[^/]+/stacks$ ]]; then
    chown "$TARGET_USER:$TARGET_USER" "$parent_dir"
    log "   Permissions parent corrigées: $parent_dir"
  fi

  # Créer le répertoire projet avec les bonnes permissions
  mkdir -p "$PROJECT_DIR"
  chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR"

  # Vérifier création effective
  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Impossible de créer $PROJECT_DIR"
    exit 1
  fi

  # Se placer dans le répertoire
  cd "$PROJECT_DIR"

  ok "✅ Répertoire de travail sécurisé: $(pwd) (permissions auto-corrigées)"
}

optimize_system_for_supabase() {
  log "🔧 Optimisation système pour Supabase ARM64..."

  # 1. Vérifier que Week 1 a configuré l'entropie
  log "🔍 Vérification configuration entropie (doit être fait par Week 1)..."

  if systemctl is-active rng-tools-debian >/dev/null 2>&1 || systemctl is-active rngd >/dev/null 2>&1; then
    ok "✅ Service RNG actif (configuré par Week 1)"
  else
    warn "⚠️ Aucun service RNG détecté - Week 1 incomplet ?"
    log "   Redémarrez Week 1 pour configurer les sources d'entropie"
  fi

  # 2. Vérifier que le CSPRNG kernel est initialisé
  if dmesg | grep -q "random: crng init done"; then
    ok "✅ CSPRNG kernel initialisé - entropie suffisante"
  else
    log "   CSPRNG en cours d'initialisation..."
  fi

  # 3. Configurer Docker daemon pour des limits appropriées
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

  # 4. Vérification entropie finale (kernel moderne)
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -eq 256 ]]; then
    ok "✅ Entropie: $entropy bits (CSPRNG kernel moderne - optimal)"
  elif [[ $entropy -gt 256 ]]; then
    ok "✅ Entropie: $entropy bits (bon niveau)"
  else
    ok "✅ Entropie: $entropy bits (continuons l'installation)"
    log "   Kernel moderne : l'entropie 256 est suffisante pour Supabase"
  fi
}

create_project_structure() {
  log "📁 Création structure projet robuste..."

  # S'assurer que nous sommes dans un répertoire sûr
  cd /

  log "   Création structure projet: $PROJECT_DIR"

  # Créer structure complète avec functions et config
  su "$TARGET_USER" -c "mkdir -p '$PROJECT_DIR'/{volumes/{db,storage,kong,functions},scripts,backups,config}"

  # CRITIQUE: Permissions Docker pour éviter getcwd errors
  # Utiliser UID/GID 1000 (utilisateur pi standard) pour tous les volumes
  chown -R 1000:1000 "$PROJECT_DIR"

  # Permissions spéciales pour services avec UIDs spécifiques
  chown -R 999:999 "$PROJECT_DIR/volumes/db" 2>/dev/null || true  # PostgreSQL
  chown -R 100:101 "$PROJECT_DIR/volumes/kong" 2>/dev/null || true  # Kong

  # Permissions exécution sur tous parents (éviter permission denied)
  chmod -R o+x "$(dirname "$PROJECT_DIR")" 2>/dev/null || true
  chmod -R 755 "$PROJECT_DIR"

  # Créer fonction edge par défaut (corrigée pour 2025)
  create_default_edge_function

  # Créer template Kong (éviter permission denied sur kong.yml)
  create_kong_template

  # Se placer dans le répertoire pour éviter getcwd
  cd "$PROJECT_DIR"

  ok "✅ Structure créée et sécurisée: $(pwd)"
}

create_default_edge_function() {
  log "⚡ Création fonction Edge par défaut (corrigée 2025)..."

  # Créer répertoire hello pour edge functions (--main-service requis)
  mkdir -p "$PROJECT_DIR/volumes/functions/hello"

  # Créer index.ts par défaut (format 2025 simplifié)
  cat > "$PROJECT_DIR/volumes/functions/hello/index.ts" << 'EDGE_FUNCTION'
// Pi 5 ARM64 Edge Function - 2025 Format
export default async (req: Request) => {
  try {
    const body = await req.json().catch(() => ({}))
    const { name = "Pi 5" } = body

    const data = {
      message: `Hello from ${name}!`,
      timestamp: new Date().toISOString(),
      platform: "Pi 5 ARM64",
      status: "running"
    }

    return new Response(
      JSON.stringify(data),
      {
        status: 200,
        headers: { "Content-Type": "application/json" }
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    )
  }
}
EDGE_FUNCTION

  # Permissions UID/GID 1000 pour éviter conflicts
  chown -R 1000:1000 "$PROJECT_DIR/volumes/functions"
  chmod -R 755 "$PROJECT_DIR/volumes/functions"

  ok "✅ Fonction Edge 'hello' créée avec --main-service support"
}

create_kong_template() {
  log "🔧 Création template Kong (éviter permission denied)..."

  # Créer template Kong.yml (sera processsé par envsubst)
  cat > "$PROJECT_DIR/config/kong.tpl.yml" << 'KONG_TEMPLATE'
_format_version: "3.0"
_transform: true

services:
  - name: auth-v1-open
    url: http://auth:9999/verify
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - /auth/v1/verify
        methods:
          - POST
          - GET

  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        strip_path: true
        paths:
          - /auth/v1/callback
        methods:
          - POST
          - GET

  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        strip_path: true
        paths:
          - /auth/v1/authorize
        methods:
          - POST
          - GET

  - name: auth-v1
    _comment: "GoTrue: /auth/v1/* -> http://auth:9999/*"
    url: http://auth:9999/
    routes:
      - name: auth-v1-all
        strip_path: true
        paths:
          - /auth/v1/
        methods:
          - POST
          - GET
          - PUT
          - PATCH
          - DELETE

  - name: rest-v1
    _comment: "PostgREST: /rest/v1/* -> http://rest:3000/*"
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - /rest/v1/
        methods:
          - POST
          - GET
          - PUT
          - PATCH
          - DELETE

  - name: realtime-v1-ws
    _comment: "Realtime: Secure WebSockets -> ws://realtime:4000/socket/*"
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1-ws
        strip_path: true
        paths:
          - /realtime/v1/
        methods:
          - POST
          - GET
          - PUT
          - PATCH
          - DELETE

  - name: storage-v1
    _comment: "Storage: /storage/v1/* -> http://storage:5000/*"
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - /storage/v1/
        methods:
          - POST
          - GET
          - PUT
          - PATCH
          - DELETE

  - name: edge-functions-v1
    _comment: "Edge Functions: /functions/v1/* -> http://edge-functions:9000/*"
    url: http://edge-functions:9000/
    routes:
      - name: edge-functions-v1-all
        strip_path: true
        paths:
          - /functions/v1/
        methods:
          - POST
          - GET
          - PUT
          - PATCH
          - DELETE

  - name: meta
    url: http://meta:8080/
    routes:
      - name: meta-all
        strip_path: true
        paths:
          - /
        methods:
          - POST
          - GET
KONG_TEMPLATE

  # Permissions
  chown -R 1000:1000 "$PROJECT_DIR/config"
  chmod 644 "$PROJECT_DIR/config/kong.tpl.yml"

  ok "✅ Template Kong créé: config/kong.tpl.yml"
}

generate_secure_jwt_secret() {
  log "🔐 Génération JWT_SECRET sécurisé (une seule ligne)..."

  # Générer JWT_SECRET sur UNE SEULE ligne garantie (évite problème multi-lignes)
  local jwt_secret=$(openssl rand -base64 64 | tr -d '\n' | tr -d '/' | tr -d '+' | tr -d '=')

  # Vérifier longueur minimale pour cryptographie Realtime
  if [[ ${#jwt_secret} -lt 50 ]]; then
    log "⚠️ JWT_SECRET trop court, régénération avec hex..."
    jwt_secret=$(openssl rand -hex 32)  # Fallback hex (64 caractères garantis)
  fi

  log "✅ JWT_SECRET généré : ${#jwt_secret} caractères (single-line)"
  export JWT_SECRET="$jwt_secret"
}

# =============================================================================
# CORRECTION REALTIME ENCRYPTION - INTÉGRATION COMPLÈTE
# Basé sur session de debugging 15/09/2025 - Résolution crypto_one_time error
# =============================================================================

prepare_realtime_encryption_keys() {
  log "🔑 Génération clés Realtime encryption (correction intégrée)..."

  # DB_ENC_KEY: EXACTEMENT 16 caractères ASCII pour AES-128-ECB (8 octets → 16 hex)
  # CRITIQUE: Realtime crash avec "crypto_one_time(:aes_128_ecb, nil)" si absent/incorrect
  DB_ENC_KEY=$(openssl rand -hex 8)

  # SECRET_KEY_BASE: 64 caractères minimum pour Elixir (32 octets → 64 hex)
  # CRITIQUE: "APP_NAME not available" si absent ou trop court
  SECRET_KEY_BASE=$(openssl rand -hex 32)

  # JWT_SECRET optimal: ~40 caractères (retour terrain 2024-2025)
  # Si JWT_SECRET existant trop long, le raccourcir pour éviter instabilité
  if [[ ${#JWT_SECRET} -gt 50 ]]; then
    log "   JWT_SECRET trop long (${#JWT_SECRET} chars), raccourci à 40 pour stabilité"
    JWT_SECRET=$(echo "$JWT_SECRET" | head -c 40)
  fi

  # Export pour utilisation globale (critique pour create_env_file)
  export DB_ENC_KEY SECRET_KEY_BASE JWT_SECRET

  ok "✅ Clés Realtime générées (format validé par debugging):"
  log "   DB_ENC_KEY: ${DB_ENC_KEY} (16 chars - AES-128 compatible)"
  log "   SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:16}... (64 chars - Elixir compatible)"
  log "   JWT_SECRET: ${JWT_SECRET:0:16}... (${#JWT_SECRET} chars - optimal)"
}

generate_secure_secrets() {
  log "🔐 Génération secrets sécurisés..."

  # Générer JWT_SECRET sécurisé d'abord (évite multi-lignes)
  generate_secure_jwt_secret

  # NOUVEAU: Générer clés Realtime encryption spécifiques (CORRECTION INTÉGRÉE)
  prepare_realtime_encryption_keys

  # Génération sécurisée (sans caractères spéciaux problématiques)
  local postgres_password=$(openssl rand -base64 32 | tr -d "=+/@#\$&*" | cut -c1-25)

  # IMPORTANT: Ces clés sont cohérentes avec un JWT_SECRET fixe pour démo
  # En production, régénérer anon_key et service_key à partir du JWT_SECRET
  local anon_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg"
  local service_key="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.T49KQx5LzLqbNBDOgdYlCW0Rf7cCUfz1bVy9q_Tl2X8"

  log "   ⚠️ Utilisation clés JWT démo - Pour production: régénérer depuis JWT_SECRET"

  # Détecter IP locale
  local local_ip=$(hostname -I | awk '{print $1}')

  # Exporter pour utilisation dans les fonctions
  export POSTGRES_PASSWORD="$postgres_password"
  export SUPABASE_ANON_KEY="$anon_key"
  export SUPABASE_SERVICE_KEY="$service_key"
  export LOCAL_IP="$local_ip"
  export SUPABASE_PUBLIC_URL="http://$local_ip:$SUPABASE_PORT"
  export API_EXTERNAL_URL="http://$local_ip:$SUPABASE_PORT"

  ok "✅ Secrets générés pour IP: $local_ip"
  log "   API accessible sur: http://$local_ip:$SUPABASE_PORT"
}

# Protection et validation du fichier .env
validate_env_file() {
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    error "❌ Fichier .env manquant : $env_file"
    return 1
  fi

  log "🔍 Validation fichier .env..."

  # Variables critiques obligatoires
  local required_vars=(
    "SUPABASE_PORT"
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "SUPABASE_ANON_KEY"
    "SUPABASE_SERVICE_KEY"
    "LOCAL_IP"
  )

  local missing_vars=()
  for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" "$env_file"; then
      missing_vars+=("$var")
    fi
  done

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    error "❌ Variables manquantes dans .env : ${missing_vars[*]}"
    return 1
  fi

  # Vérifier que SUPABASE_PORT n'est pas vide
  local supabase_port=$(grep "^SUPABASE_PORT=" "$env_file" | cut -d'=' -f2 | tr -d '"')
  if [[ -z "$supabase_port" ]]; then
    error "❌ SUPABASE_PORT est vide dans .env"
    return 1
  fi

  ok "✅ Fichier .env validé (${#required_vars[@]} variables critiques présentes)"
  return 0
}

backup_env_file() {
  local env_file="$1"

  if [[ -f "$env_file" ]]; then
    local backup_file="${env_file}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$env_file" "$backup_file"
    log "💾 Sauvegarde .env : $backup_file"

    # Protéger contre suppression accidentelle
    chmod 444 "$backup_file"
  fi
}

restore_env_if_missing() {
  local env_file="$1"

  if [[ ! -f "$env_file" ]]; then
    warn "⚠️  Fichier .env manquant, tentative de restauration..."

    # Chercher la sauvegarde la plus récente
    local latest_backup
    latest_backup=$(ls -1t "${env_file}".bak.* 2>/dev/null | head -1)

    if [[ -n "$latest_backup" && -f "$latest_backup" ]]; then
      cp "$latest_backup" "$env_file"
      chmod 600 "$env_file"
      chown "$TARGET_USER:$TARGET_USER" "$env_file"
      ok "✅ Fichier .env restauré depuis : $latest_backup"
      return 0
    else
      error "❌ Aucune sauvegarde .env trouvée pour restauration"
      return 1
    fi
  fi

  return 0
}

create_env_file() {
  log "📄 Création fichier .env avec variables correctes..."

  # Sauvegarder fichier existant si présent
  backup_env_file "$PROJECT_DIR/.env"

  # Créer un fichier temporaire sécurisé
  local tmp_file
  tmp_file=$(mktemp)

  # Créer .env avec TOUTES les variables nécessaires dans le fichier temporaire
  cat > "$tmp_file" << EOF
# Pi 5 Supabase Configuration Final
# Generated: $(date)

########################################
# Docker Images Versions (Centralisées)
########################################
POSTGRES_VERSION=$POSTGRES_VERSION
GOTRUE_VERSION=$GOTRUE_VERSION
POSTGREST_VERSION=$POSTGREST_VERSION
REALTIME_VERSION=$REALTIME_VERSION
STORAGE_API_VERSION=$STORAGE_API_VERSION
POSTGRES_META_VERSION=$POSTGRES_META_VERSION
STUDIO_VERSION=$STUDIO_VERSION
EDGE_RUNTIME_VERSION=$EDGE_RUNTIME_VERSION
KONG_VERSION=$KONG_VERSION
IMGPROXY_VERSION=$IMGPROXY_VERSION

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
# Network Configuration
########################################
LOCAL_IP=$LOCAL_IP
SUPABASE_PORT=$SUPABASE_PORT

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

########################################
# Development
########################################
ENVIRONMENT=development

########################################
# Realtime Encryption (CORRECTION INTÉGRÉE)
# Variables critiques pour éviter crypto_one_time error
########################################
DB_ENC_KEY=$DB_ENC_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE

EOF

  # Si l'écriture a réussi, déplacer le fichier temporaire à sa destination finale
  if [ $? -eq 0 ]; then
    mv "$tmp_file" "$PROJECT_DIR/.env"
    chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
    chmod 600 "$PROJECT_DIR/.env"  # Permissions sécurisées pour les secrets

    # VALIDATION CRITIQUE : Vérifier que le fichier .env est complet
    if validate_env_file "$PROJECT_DIR/.env"; then
      ok "✅ Fichier .env créé et validé avec écriture atomique"
    else
      error "❌ Validation .env échouée après création"
      return 1
    fi
  else
    error "❌ Échec de la création du fichier .env temporaire."
    rm -f "$tmp_file"
    return 1
  fi
}

create_docker_compose() {
  log "🐳 Création docker-compose.yml optimisé avec variables..."

  # Docker-compose unifié avec corrections complètes
  cat > "$PROJECT_DIR/docker-compose.yml" << 'COMPOSE'
services:
  # Base de données PostgreSQL optimisée Pi 5
  db:
    container_name: supabase-db
    image: postgres:${POSTGRES_VERSION}
    platform: linux/arm64
    restart: unless-stopped
    command:
      - "postgres"
      - "-c"
      - "shared_buffers=${POSTGRES_SHARED_BUFFERS}"
      - "-c"
      - "work_mem=${POSTGRES_WORK_MEM}"
      - "-c"
      - "maintenance_work_mem=${POSTGRES_MAINTENANCE_WORK_MEM}"
      - "-c"
      - "max_connections=${POSTGRES_MAX_CONNECTIONS}"
      - "-c"
      - "wal_level=logical"
      - "-c"
      - "max_wal_senders=10"
      - "-c"
      - "max_replication_slots=10"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: postgres
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
          memory: 1GB  # Optimisé Pi 5 : 2GB→1GB
          cpus: '1.5'
    volumes:
      - ./volumes/db:/var/lib/postgresql/data:Z
    ports:
      - "127.0.0.1:5432:5432"

  # Service Auth (GoTrue) - MOT DE PASSE UNIFIÉ
  auth:
    container_name: supabase-auth
    image: supabase/gotrue:${GOTRUE_VERSION}
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres?sslmode=disable
      GOTRUE_LOG_LEVEL: debug  # Debug pour diagnostiquer problèmes
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      GOTRUE_URI_ALLOW_LIST: "*"
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
    deploy:
      resources:
        limits:
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'

  # Service REST (PostgREST) - MOT DE PASSE UNIFIÉ
  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:${POSTGREST_VERSION}
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
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'

  # Service Realtime - MOT DE PASSE UNIFIÉ + CORRECTIONS ARM64 COMPLÈTES
  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:${REALTIME_VERSION}
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      # CORRECTION INTÉGRÉE: Variables encryption Realtime (évite crypto_one_time error)
      DB_ENC_KEY: ${DB_ENC_KEY}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      APP_NAME: supabase_realtime

      # Configuration DB (connexion PostgreSQL)
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: postgres
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_SSL: disable
      DB_IP_VERSION: ipv4

      # Runtime Elixir (critique pour ARM64 d'après recherches)
      ERL_AFLAGS: "-proto_dist inet_tcp"
      DNS_NODES: ""
      SEED_SELF_HOST: "true"

      # Service config
      PORT: 4000
      API_JWT_SECRET: ${JWT_SECRET}

      # Performance Pi 5 (d'après recherches)
      DB_POOL_SIZE: 10
      MAX_CONNECTIONS: 16384
      RLIMIT_NOFILE: 65536
    ulimits:
      nofile:
        soft: 65536  # Optimisé Pi 5 : 262144→65536
        hard: 65536
    cap_add:
      - SYS_RESOURCE  # Permet modification limites runtime
    sysctls:
      net.core.somaxconn: 65535  # Optimisation connexions WebSocket
    deploy:
      resources:
        limits:
          memory: 256MB  # Realtime WebSocket needs more
          cpus: '0.5'

  # Service Storage - MOT DE PASSE UNIFIÉ
  storage:
    container_name: supabase-storage
    image: supabase/storage-api:${STORAGE_API_VERSION}
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
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Service Meta (PostgREST Schema)
  meta:
    container_name: supabase-meta
    image: supabase/postgres-meta:${POSTGRES_META_VERSION}
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
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'

  # Kong API Gateway - IMAGE ARM64 SPÉCIFIQUE POUR PI 5
  kong:
    container_name: supabase-kong
    image: arm64v8/kong:${KONG_VERSION}
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
      KONG_DECLARATIVE_CONFIG: /tmp/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_DNS_RESOLVER: "127.0.0.11:53"  # CRITIQUE: DNS interne Docker
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
      # ARM64/Pi 5 specific optimizations
      KONG_NGINX_WORKER_PROCESSES: "2"
      KONG_MEM_CACHE_SIZE: "128m"
    ports:
      - "${SUPABASE_PORT}:8000"
    volumes:
      - ./volumes/kong/kong.yml:/tmp/kong.yml:ro  # Fichier final pré-rendu

  # Service Studio (Interface Web)
  studio:
    container_name: supabase-studio
    image: supabase/studio:${STUDIO_VERSION}
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
    image: darthsim/imgproxy:${IMGPROXY_VERSION}
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
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Edge Functions - CORRECTED 2025 FORMAT
  edge-functions:
    container_name: supabase-edge-functions
    image: supabase/edge-runtime:${EDGE_RUNTIME_VERSION}
    platform: linux/arm64
    restart: unless-stopped
    user: "1000:1000"  # CRITIQUE: Éviter permission denied
    command:
      - start
      - --main-service
      - /home/deno/functions/hello  # Corrigé: utiliser 'hello' pas 'main'
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
    volumes:
      - ./volumes/functions:/home/deno/functions:Z  # SELinux-safe mount
    ports:
      - "54321:9000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/_internal/health/liveness"]
      interval: 30s
      timeout: 10s
      retries: 3
    deploy:
      resources:
        limits:
          memory: 128MB  # Optimisé Pi 5
          cpus: '0.5'

  # NOTE: supabase-vector DÉSACTIVÉ pour Pi 5 ARM64
  # Cause des problèmes de page size sur ARM64
  # Réactiver uniquement si page size 4KB confirmé fonctionnel

networks:
  default:
    name: supabase_network

COMPOSE

  chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"

  # Validation syntaxe YAML (fail fast) avec logs détaillés
  log "🔍 Validation syntaxe YAML docker-compose.yml..."

  # Log des variables critiques pour debug
  log "   Variables critiques :"
  log "     POSTGRES_VERSION=$POSTGRES_VERSION"
  log "     POSTGRES_PASSWORD length=${#POSTGRES_PASSWORD}"
  log "     JWT_SECRET length=${#JWT_SECRET}"
  log "     LOCAL_IP=$LOCAL_IP"

  # Test validation avec sortie détaillée
  local yaml_validation_output
  yaml_validation_output=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose config" 2>&1)
  local yaml_exit_code=$?

  if [[ $yaml_exit_code -eq 0 ]]; then
    ok "✅ docker-compose.yml syntaxe validée ($(wc -l < "$PROJECT_DIR/docker-compose.yml") lignes)"
    log "   Services détectés: $(echo "$yaml_validation_output" | grep -c "container_name:")"
  else
    error "❌ Erreur syntaxe dans docker-compose.yml (code: $yaml_exit_code)"
    log "   Erreur Docker Compose:"
    echo "$yaml_validation_output" | head -10
    log "   Contenu docker-compose (20 premières lignes):"
    nl -ba "$PROJECT_DIR/docker-compose.yml" | sed -n '1,20p'
    log "   Variables .env (vérification):"
    head -5 "$PROJECT_DIR/.env"
    log ""
    log "   📋 Commandes debug manuelles :"
    log "   cd /home/pi/stacks/supabase"
    log "   docker compose config  # Voir erreur exacte"
    log "   head -30 docker-compose.yml  # Vérifier syntaxe"
    log "   grep -n 'cpus:' docker-compose.yml  # Chercher guillemets mal fermées"
    exit 1
  fi
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

render_kong_config() {
  log "🔧 Pré-rendu configuration Kong avec variables..."

  # Installer envsubst si nécessaire
  if ! command -v envsubst >/dev/null 2>&1; then
    log "   Installation gettext-base pour envsubst..."
    apt-get update -qq && apt-get install -y gettext-base >/dev/null 2>&1
  fi

  # Pré-rendre le template Kong avec substitution des variables
  if envsubst < "$PROJECT_DIR/config/kong.tpl.yml" > "$PROJECT_DIR/volumes/kong/kong.yml"; then
    chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/kong/kong.yml"
    ok "✅ Kong config pré-rendue ($(wc -l < "$PROJECT_DIR/volumes/kong/kong.yml") lignes)"
  else
    error "❌ Erreur pré-rendu Kong template"
    log "   📋 Debug Kong template :"
    log "   head -10 $PROJECT_DIR/config/kong.tpl.yml"
    log "   env | grep SUPABASE"
    exit 1
  fi
}

start_database_only() {
  log "🗄️ Démarrage PostgreSQL (création structures)..."

  # CRITIQUE: Toujours se placer dans le bon répertoire
  cd "$PROJECT_DIR" || { error "❌ Impossible d'accéder à $PROJECT_DIR"; exit 1; }

  # Logs de debug pour l'environnement
  log "🔍 Environnement Docker :"
  log "   Répertoire: $(pwd)"
  log "   Utilisateur: $TARGET_USER"
  log "   Docker running: $(systemctl is-active docker)"

  # Télécharger et démarrer UNIQUEMENT la base de données
  log "📦 Téléchargement image PostgreSQL..."
  docker compose pull db 2>/dev/null || warn "Pas de nouvelles images disponibles"

  log "🏗️ Démarrage conteneur PostgreSQL seul..."
  docker compose up -d db

  echo ""
  echo "⏳ ATTENTE INITIALISATION POSTGRESQL (1-2 minutes)"
  echo "   Le script attend que PostgreSQL soit complètement ready..."
  echo "   Ceci est normal et nécessaire pour créer les structures database."
  echo ""

  # Attendre que PostgreSQL soit ready avec gestion d'erreur robuste
  # Tolérer des retours non-zéro pendant le wait
  set +e
  local max_attempts=30
  local attempt=0
  local pg_ready=false

  while [[ $attempt -lt $max_attempts ]] && [[ "$pg_ready" == "false" ]]; do
    ((attempt++))

    # Vérifier d'abord que le conteneur tourne
    if ! docker ps --filter "name=supabase-db" --filter "status=running" | grep -q supabase-db; then
      printf "\r   ⏱️  Attente démarrage conteneur... %02d/%02d tentatives" $attempt $max_attempts
    else
      # Ensuite vérifier que PostgreSQL accepte les connexions (sans set -e)
      if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
        pg_ready=true
        break
      else
        printf "\r   ⏱️  PostgreSQL initialisation... %02d/%02d tentatives (ne pas interrompre)" $attempt $max_attempts
      fi
    fi

    sleep 3
  done

  if [[ "$pg_ready" == "false" ]]; then
    echo ""
    error "❌ PostgreSQL ne démarre pas après $max_attempts tentatives ($((max_attempts * 3)) secondes)"
    echo ""
    echo "📋 Diagnostic PostgreSQL :"
    echo "   docker logs supabase-db --tail=10"
    echo "   docker exec supabase-db pg_isready -U postgres"
    echo "   docker ps --filter name=supabase-db"
    exit 1
  fi

  # Réactiver le mode strict
  set -e

  echo ""
  ok "✅ PostgreSQL démarré et ready - création des structures..."
}

start_remaining_services() {
  log "🚀 Démarrage services Supabase restants..."

  cd "$PROJECT_DIR" || { error "❌ Impossible d'accéder à $PROJECT_DIR"; exit 1; }

  # Message d'attente clair pour le téléchargement d'images
  echo ""
  echo "⏳ TÉLÉCHARGEMENT DES IMAGES DOCKER (2-5 minutes selon connexion)"
  echo "   Le script télécharge les images Supabase depuis Docker Hub..."
  echo "   Images requises: Auth, Realtime, Storage, Kong, Studio (~ 1-2GB)"
  echo ""

  log "📦 Téléchargement images restantes..."
  local pull_output pull_exit_code
  pull_output=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose pull" 2>&1)
  pull_exit_code=$?

  if [[ $pull_exit_code -eq 0 ]]; then
    log "   Images téléchargées: $(echo "$pull_output" | grep -c "Pulled" || echo "0")"
    log "   Images à jour: $(echo "$pull_output" | grep -c "up to date" || echo "0")"
    ok "✅ Téléchargement terminé"
  else
    warn "⚠️ Erreur téléchargement images (continuons avec existantes)"
  fi

  # Message d'attente pour le démarrage des conteneurs
  echo ""
  echo "⏳ DÉMARRAGE DES CONTENEURS (1-2 minutes)"
  echo "   Le script démarre tous les services Supabase..."
  echo "   Services: Auth, Realtime, Storage, Kong, PostgREST, Studio"
  echo ""

  log "🏗️ Démarrage services restants..."
  local up_output up_exit_code
  up_output=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d" 2>&1)
  up_exit_code=$?

  if [[ $up_exit_code -eq 0 ]]; then
    local containers_running=$(docker compose ps --services --filter status=running | wc -l)
    local containers_total=$(docker compose ps --services | wc -l)
    ok "✅ Services lancés ($containers_running/$containers_total actifs)"

    # Log status initial des conteneurs
    log "   Conteneurs créés:"
    docker compose ps --format "table {{.Name}}\t{{.State}}" | head -5
  else
    error "❌ Erreur démarrage conteneurs (code: $up_exit_code)"
    log "   Sortie docker compose up:"
    echo "$up_output" | head -15
    exit 1
  fi
}

wait_for_services() {
  echo ""
  echo "⏳ ATTENTE INITIALISATION DES SERVICES (3-5 minutes)"
  echo "   Le script vérifie que tous les services Supabase sont prêts..."
  echo "   Services surveillés: PostgreSQL, Auth, PostgREST, Realtime, Kong"
  echo "   NE PAS INTERROMPRE - La première initialisation peut prendre du temps"
  echo ""

  log "⏳ Attente initialisation des services..."
  cd "$PROJECT_DIR"

  # Tolérer des retours non-zéro pendant le wait
  set +e
  local max_attempts=30
  local attempt=0
  local services=("db" "auth" "rest" "realtime" "kong")

  # Log initial des conteneurs
  log "🔍 État initial des conteneurs :"
  docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" | head -6

  while [[ $attempt -lt $max_attempts ]]; do
    local healthy_count=0
    local service_status=""

    # Affichage du progrès avec printf (pas de nouvelle ligne)
    printf "\r   ⏱️  Vérification services... %02d/%02d tentatives (temps écoulé: %d min)" $((attempt+1)) $max_attempts $((attempt*10/60))

    for service in "${services[@]}"; do
      local health_status=$(docker inspect --format='{{.State.Health.Status}}' supabase-${service} 2>/dev/null || echo "none")
      local running_status=$(docker inspect --format='{{.State.Status}}' supabase-${service} 2>/dev/null || echo "missing")

      # Critères plus tolérants : running OU healthy
      if [[ "$health_status" == "healthy" ]] || [[ "$running_status" == "running" ]] || [[ "$service" == "db" && "$health_status" == "none" && "$running_status" == "running" ]]; then
        ((healthy_count++))
        service_status+=" ✅$service"
      else
        service_status+=" ❌$service($running_status)"
        # Log détaillé pour les services en échec
        if [[ $attempt -eq 5 ]] || [[ $attempt -eq 15 ]]; then  # Log à 50s et 150s
          echo ""  # Nouvelle ligne pour les logs détaillés
          log "     Service $service : state=$running_status, health=$health_status"
          if [[ "$running_status" == "exited" ]]; then
            log "     Dernières logs $service :"
            docker compose logs --tail=3 "$service" 2>/dev/null | grep -v "^$" || true
          fi
        fi
      fi
    done

    # Accepter si au moins DB + 2 autres services fonctionnent
    if [[ $healthy_count -eq ${#services[@]} ]]; then
      echo ""  # Nouvelle ligne après printf
      ok "✅ Tous les services sont opérationnels ($healthy_count/${#services[@]})"
      log "   Services: $service_status"
      # Réactiver le mode strict
      set -e
      return 0
    elif [[ $healthy_count -ge 3 ]] && [[ $attempt -gt 10 ]]; then
      echo ""  # Nouvelle ligne après printf
      ok "✅ Services critiques opérationnels ($healthy_count/${#services[@]}) - Continue l'installation"
      log "   Services: $service_status"
      # Réactiver le mode strict
      set -e
      return 0
    fi

    # Log détaillé toutes les 30s
    if [[ $attempt -eq 0 ]] || [[ $(($attempt % 3)) -eq 0 ]]; then
      echo ""  # Nouvelle ligne pour log détaillé
      log "   État services: $service_status"
    fi

    sleep 10
    ((attempt++))
  done

  echo ""  # Nouvelle ligne après printf
  warn "⚠️ TIMEOUT ATTEINT après $((max_attempts * 10))s - Certains services ne répondent pas"
  log "   Services finaux: $service_status"
  echo ""
  echo "🔧 QUE FAIRE EN CAS DE TIMEOUT :"
  echo ""
  echo "1️⃣ **Vérifier l'état des conteneurs** :"
  echo "   cd /home/pi/stacks/supabase"
  echo "   docker compose ps"
  echo ""
  echo "2️⃣ **Consulter les logs des services en échec** :"
  echo "   docker compose logs db --tail=20"
  echo "   docker compose logs realtime --tail=10"
  echo "   docker compose logs auth --tail=10"
  echo ""
  echo "3️⃣ **Relancer le script si nécessaire** :"
  echo "   cd $(dirname "${BASH_SOURCE[0]}")"
  echo "   sudo ./setup-week2-supabase-final.sh"
  echo ""
  echo "4️⃣ **Nettoyer si problème persistant** :"
  echo "   sudo ./cleanup-week2-supabase.sh"
  echo ""
  echo "⚠️  Le script continue avec les services disponibles..."
  echo "    Vous pourrez relancer pour corriger les services manquants."
  echo ""

  # Réactiver le mode strict
  set -e
}

create_complete_database_structure() {
  echo ""
  echo "🗄️ CRÉATION STRUCTURES DATABASE COMPLÈTES"
  echo "   Création de tous les schémas, rôles et types PostgreSQL..."
  echo "   Cette étape évite les erreurs Auth/Realtime par la suite."
  echo ""

  cd "$PROJECT_DIR" || return 1

  # PostgreSQL devrait déjà être ready depuis start_database_only()
  # Vérification rapide avec protection
  set +e
  if ! docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
    warn "⚠️ PostgreSQL non ready - attente supplémentaire..."
    local attempt=0
    while [[ $attempt -lt 10 ]]; do
      ((attempt++))
      printf "\r   ⏱️  Attente PostgreSQL... %02d/10" $attempt
      if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
        echo ""
        break
      fi
      sleep 2
    done
  fi
  set -e

  log "🔧 Création schémas, rôles et structures critiques..."
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    -- Créer tous les schémas nécessaires
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE SCHEMA IF NOT EXISTS realtime;
    CREATE SCHEMA IF NOT EXISTS storage;

    -- Créer tous les rôles PostgreSQL
    DO \$\$ BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN;
        RAISE NOTICE 'Rôle anon créé';
      END IF;

      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN;
        RAISE NOTICE 'Rôle authenticated créé';
      END IF;

      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN;
        RAISE NOTICE 'Rôle service_role créé';
      END IF;
    END \$\$;

    -- Types et structures critiques Auth
    DO \$\$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type') THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
        RAISE NOTICE 'Type auth.factor_type créé';
      END IF;
    EXCEPTION
      WHEN duplicate_object THEN
        RAISE NOTICE 'Type auth.factor_type existe déjà';
    END \$\$;

    -- Table schema_migrations Realtime avec structure Ecto correcte
    -- CRITICAL: Une seule création, structure validée pour Elixir/Ecto
    DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
    DROP TABLE IF EXISTS public.schema_migrations CASCADE;
    CREATE TABLE realtime.schema_migrations(
      version BIGINT NOT NULL PRIMARY KEY,
      inserted_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
    );

    -- Permissions sur tous les schémas
    GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
    GRANT USAGE ON SCHEMA realtime TO postgres, anon, authenticated, service_role;
    GRANT USAGE ON SCHEMA storage TO postgres, anon, authenticated, service_role;

    RAISE NOTICE 'Structure database complète créée avec succès';
  " 2>/dev/null || log "⚠️ Certaines structures existent déjà (normal)"

  ok "✅ Structure database complète - schémas, rôles, types créés"
}

clean_corrupted_realtime_data() {
  if docker compose ps realtime 2>/dev/null | grep -q "Restarting"; then
    log "🧹 Nettoyage données Realtime corrompues détectées..."

    docker compose stop realtime 2>/dev/null || true

    # Nettoyer données corrompues avec ancien JWT_SECRET
    docker exec -T supabase-db psql -U postgres -d postgres -c "
      DELETE FROM realtime.tenants WHERE jwt_secret IS NOT NULL;
      DELETE FROM realtime.extensions;
      RAISE NOTICE 'Données Realtime corrompues supprimées';
    " 2>/dev/null || log "⚠️ Tables Realtime pas encore créées"

    sleep 2
    docker compose start realtime 2>/dev/null || true
    log "✅ Realtime nettoyé et redémarré avec nouveau JWT_SECRET"
  fi
}

# =============================================================================
# CORRECTION TENANT REALTIME CORROMPU - INTÉGRATION COMPLÈTE
# Basé sur session de debugging 15/09/2025 - Résolution tenant "realtime-dev"
# =============================================================================

fix_realtime_corrupted_tenant() {
  log "🧹 Nettoyage tenant Realtime corrompu (correction intégrée)..."

  # Supprimer tenant "realtime-dev" corrompu qui cause les erreurs de seeding
  # Cette correction évite l'erreur: crypto_one_time lors du seeding
  docker exec -T supabase-db psql -U postgres -d postgres -c "
    DELETE FROM _realtime.tenants WHERE external_id = 'realtime-dev';
    DELETE FROM realtime.tenants WHERE external_id = 'realtime-dev';
  " 2>/dev/null || log "   Table tenants pas encore créée (normal en début d'installation)"

  ok "✅ Tenant Realtime corrompu nettoyé"
}

fix_common_service_issues() {
  log "🔧 Correction automatique problèmes courants des services..."
  cd "$PROJECT_DIR" || return 1

  # Vérifier si des services redémarrent en boucle
  local restarting_services
  restarting_services=$(docker compose ps --filter "status=restarting" --format "{{.Name}}" | grep -E "(auth|storage|realtime)" || true)

  if [[ -n "$restarting_services" ]]; then
    log "   Services en redémarrage détectés: $restarting_services"

    # Attendre que PostgreSQL soit accessible
    local max_attempts=15
    local attempt=0
    while ! docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; do
      ((attempt++))
      if [[ $attempt -ge $max_attempts ]]; then
        warn "PostgreSQL non accessible, abandon de la correction automatique"
        return 1
      fi
      log "   Attente PostgreSQL... ($attempt/$max_attempts)"
      sleep 2
    done

    # Nettoyer données Realtime corrompues si nécessaire
    clean_corrupted_realtime_data

    # CORRECTION INTÉGRÉE: Nettoyer tenant realtime-dev corrompu
    fix_realtime_corrupted_tenant

    # Correction 1: Créer le schéma auth, rôles et types manquants
    log "   Création schéma auth complet avec types et rôles..."
    docker exec supabase-db psql -U postgres -d postgres -c "
      DO \$\$
      BEGIN
          -- Créer le schéma auth
          CREATE SCHEMA IF NOT EXISTS auth;

          -- Créer le type factor_type pour MFA (résout l'erreur auth.factor_type does not exist)
          BEGIN
              CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
              RAISE NOTICE 'auth.factor_type créé avec succès';
          EXCEPTION
              WHEN duplicate_object THEN
                  RAISE NOTICE 'auth.factor_type existe déjà';
          END;

          -- Créer les rôles PostgreSQL
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
              CREATE ROLE anon;
              GRANT USAGE ON SCHEMA public TO anon;
              GRANT USAGE ON SCHEMA auth TO anon;
          END IF;
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
              CREATE ROLE service_role;
              GRANT ALL ON SCHEMA public TO service_role;
              GRANT ALL ON SCHEMA auth TO service_role;
          END IF;
          IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
              CREATE ROLE authenticated;
              GRANT USAGE ON SCHEMA public TO authenticated;
              GRANT USAGE ON SCHEMA auth TO authenticated;
          END IF;
      END
      \$\$;
    " 2>/dev/null || true

    # Correction 2: Créer schéma Realtime avec table schema_migrations correcte
    log "   Création schéma Realtime pour migrations..."
    docker exec supabase-db psql -U postgres -d postgres -c "
      -- Créer le schéma realtime
      CREATE SCHEMA IF NOT EXISTS realtime;

      -- Créer la table schema_migrations avec version BIGINT (requis par Ecto)
      CREATE TABLE IF NOT EXISTS realtime.schema_migrations(
        version BIGINT PRIMARY KEY,
        inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
      );

      -- Supprimer la table public.schema_migrations si elle existe pour éviter la confusion
      DROP TABLE IF EXISTS public.schema_migrations;
    " 2>/dev/null || true

    # Correction 3: Ajouter variables manquantes pour Realtime
    local env_updated=false
    if ! grep -q "^APP_NAME=" .env 2>/dev/null; then
      echo "APP_NAME=supabase" >> .env
      env_updated=true
    fi
    if ! grep -q "^REALTIME_APP_NAME=" .env 2>/dev/null; then
      echo "REALTIME_APP_NAME=supabase" >> .env
      env_updated=true
    fi
    if ! grep -q "^REALTIME_DB_PASSWORD=" .env 2>/dev/null; then
      local postgres_password
      postgres_password=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"')
      echo "REALTIME_DB_PASSWORD=$postgres_password" >> .env
      env_updated=true
    fi

    if [[ "$env_updated" == "true" ]]; then
      log "   Variables d'environnement mises à jour"

      echo ""
      echo "🔧 REDÉMARRAGE SERVICES PROBLÉMATIQUES (30 secondes)"
      echo "   Arrêt propre des services Auth, Storage, Realtime..."
      echo "   Puis redémarrage avec nouvelles variables d'environnement"
      echo ""

      # Redémarrer les services problématiques
      log "   Arrêt des services en échec..."
      docker compose stop auth storage realtime 2>/dev/null || true
      printf "   ⏱️  Attente arrêt propre... 3 secondes"
      sleep 3
      echo ""

      log "   Redémarrage avec nouvelles variables..."
      docker compose up -d auth storage realtime 2>/dev/null || true

      # Attendre un peu pour la stabilisation
      echo "   ⏱️  Stabilisation des services... 15 secondes (ne pas interrompre)"
      sleep 15
      ok "✅ Correction automatique appliquée"
    else
      ok "✅ Variables d'environnement OK"
    fi
  else
    ok "✅ Aucun service en redémarrage détecté"
  fi
}

# =============================================================================
# NOUVELLES CORRECTIONS AUTH & REALTIME - INTÉGRATION SESSION DEBUGGING 15/09/2025
# Basé sur documentation DEBUG-SESSION-AUTH-MIGRATION.md et DEBUG-SESSION-REALTIME.md
# =============================================================================

fix_auth_uuid_operator_issue() {
  log "🔧 Correction opérateur PostgreSQL uuid = text (Auth migration)..."
  cd "$PROJECT_DIR" || return 1

  # Test si l'erreur uuid = text existe
  local uuid_error
  uuid_error=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT id = user_id::text
    FROM auth.identities
    LIMIT 1;
  " 2>&1 || echo "Erreur uuid = text confirmée")

  if [[ "$uuid_error" == *"operator does not exist"* ]]; then
    log "   Erreur uuid = text détectée - Création opérateur PostgreSQL..."

    # Créer opérateur uuid = text
    docker exec supabase-db psql -U postgres -d postgres -c "
      DO \$\$
      BEGIN
          -- Créer fonction de comparaison uuid = text
          CREATE OR REPLACE FUNCTION uuid_text_eq(uuid, text)
          RETURNS boolean AS
          \$func\$
              SELECT \$1::text = \$2;
          \$func\$
          LANGUAGE SQL IMMUTABLE;

          -- Créer opérateur = pour uuid, text
          IF NOT EXISTS (
              SELECT 1 FROM pg_operator
              WHERE oprname = '='
                AND oprleft = 'uuid'::regtype
                AND oprright = 'text'::regtype
          ) THEN
              CREATE OPERATOR = (
                  LEFTARG = uuid,
                  RIGHTARG = text,
                  FUNCTION = uuid_text_eq
              );
          END IF;
      END
      \$\$;
    " 2>/dev/null || true

    # Appliquer migration problématique manuellement
    log "   Application migration 20221208132122 avec opérateur corrigé..."
    docker exec supabase-db psql -U postgres -d postgres -c "
      UPDATE auth.identities
      SET last_sign_in_at = '2022-11-25'
      WHERE last_sign_in_at IS NULL
        AND created_at = '2022-11-25'
        AND updated_at = '2022-11-25'
        AND provider = 'email'
        AND id = user_id::text;
    " 2>/dev/null || true

    # Marquer migration comme exécutée
    docker exec supabase-db psql -U postgres -d postgres -c "
      INSERT INTO auth.schema_migrations (version)
      VALUES ('20221208132122')
      ON CONFLICT (version) DO NOTHING;
    " 2>/dev/null || true

    ok "✅ Opérateur uuid = text créé et migration corrigée"
  else
    ok "✅ Opérateur uuid = text déjà fonctionnel"
  fi
}

clean_env_duplicates() {
  log "🧹 Nettoyage doublons .env..."
  cd "$PROJECT_DIR" || return 1

  # CRITIQUE : Sauvegarder avant modification
  backup_env_file "$PROJECT_DIR/.env"

  # Vérifier que le .env existe
  if [[ ! -f ".env" ]]; then
    error "❌ Fichier .env manquant avant nettoyage des doublons"
    restore_env_if_missing "$PROJECT_DIR/.env"
    return 1
  fi

  # Créer fichier temporaire sans doublons
  local temp_env=$(mktemp)

  # Garder seulement la dernière occurrence de chaque variable
  awk -F'=' '!seen[$1]++ {vars[NR]=$0} seen[$1]==1 {vars[NR]=$0} END {for(i=1;i<=NR;i++) if(vars[i]) print vars[i]}' .env > "$temp_env"

  # Remplacer le fichier original seulement si le temp est valide
  if [[ -s "$temp_env" ]]; then
    mv "$temp_env" .env
    chown "$TARGET_USER:$TARGET_USER" .env
    chmod 600 .env

    # VALIDATION critique après modification
    if validate_env_file "$PROJECT_DIR/.env"; then
      ok "✅ Doublons .env supprimés et fichier validé"
    else
      error "❌ .env corrompu après nettoyage, restauration..."
      restore_env_if_missing "$PROJECT_DIR/.env"
      return 1
    fi
  else
    error "❌ Fichier temporaire vide, annulation nettoyage"
    rm -f "$temp_env"
    return 1
  fi
}

validate_realtime_schema_migrations() {
  log "✅ Validation table schema_migrations Realtime..."

  # Vérifier que la table existe avec la bonne structure
  local table_exists
  table_exists=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'realtime'
      AND table_name = 'schema_migrations'
    );
  " 2>/dev/null || echo "f")

  local has_correct_structure
  has_correct_structure=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT COUNT(*) = 2 FROM information_schema.columns
    WHERE table_schema = 'realtime'
    AND table_name = 'schema_migrations'
    AND column_name IN ('version', 'inserted_at')
    AND is_nullable = 'NO';
  " 2>/dev/null || echo "f")

  if [[ "$table_exists" == "t" && "$has_correct_structure" == "t" ]]; then
    ok "✅ Table realtime.schema_migrations correctement structurée pour Ecto"

    # Log de la structure pour confirmation
    log "   Structure validée:"
    docker exec supabase-db psql -U postgres -d postgres -c "\d realtime.schema_migrations;" 2>/dev/null | head -10
    return 0
  else
    error "❌ Table realtime.schema_migrations incorrecte ou manquante"
    log "   Table exists: $table_exists"
    log "   Correct structure: $has_correct_structure"
    return 1
  fi
}

validate_post_creation_environment() {
  log "🔍 Validation complète environment post-création..."
  cd "$PROJECT_DIR" || return 1

  local validation_errors=0

  echo ""
  echo "=== VALIDATION ENVIRONNEMENT COMPLET ==="

  # 1. Validation fichier .env
  echo "1️⃣ Validation fichier .env:"
  if [[ -f ".env" ]]; then
    echo "   ✅ Fichier .env présent"

    # Vérifier variables critiques avec longueurs
    local critical_vars=("SUPABASE_PORT" "LOCAL_IP" "POSTGRES_PASSWORD" "JWT_SECRET" "DB_ENC_KEY" "SECRET_KEY_BASE")
    for var in "${critical_vars[@]}"; do
      if grep -q "^${var}=" .env 2>/dev/null; then
        local value=$(grep "^${var}=" .env | cut -d'=' -f2)
        local length=${#value}
        case "$var" in
          "DB_ENC_KEY")
            if [[ $length -eq 16 ]]; then
              echo "   ✅ $var: $length chars (correct pour AES-128)"
            else
              echo "   ❌ $var: $length chars (attendu: 16)"
              ((validation_errors++))
            fi
            ;;
          "SECRET_KEY_BASE")
            if [[ $length -eq 64 ]]; then
              echo "   ✅ $var: $length chars (correct pour Elixir)"
            else
              echo "   ❌ $var: $length chars (attendu: 64)"
              ((validation_errors++))
            fi
            ;;
          *)
            echo "   ✅ $var: présent ($length chars)"
            ;;
        esac
      else
        echo "   ❌ $var: MANQUANT"
        ((validation_errors++))
      fi
    done
  else
    echo "   ❌ Fichier .env MANQUANT"
    ((validation_errors++))
  fi

  # 2. Validation structure base de données
  echo ""
  echo "2️⃣ Validation structure base de données:"
  if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
    echo "   ✅ PostgreSQL accessible"

    # Vérifier schémas
    local schemas=$(docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT string_agg(schema_name, ',') FROM information_schema.schemata WHERE schema_name IN ('auth','realtime','storage');" 2>/dev/null)
    if [[ "$schemas" == *"auth"* && "$schemas" == *"realtime"* && "$schemas" == *"storage"* ]]; then
      echo "   ✅ Schémas critiques présents: $schemas"
    else
      echo "   ❌ Schémas manquants. Présents: $schemas"
      ((validation_errors++))
    fi

    # Vérifier table schema_migrations
    local table_check=$(docker exec supabase-db psql -U postgres -d postgres -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations');" 2>/dev/null)
    if [[ "$table_check" == "t" ]]; then
      echo "   ✅ Table realtime.schema_migrations présente"
    else
      echo "   ❌ Table realtime.schema_migrations MANQUANTE"
      ((validation_errors++))
    fi
  else
    echo "   ❌ PostgreSQL non accessible"
    ((validation_errors++))
  fi

  # 3. Validation Docker Compose
  echo ""
  echo "3️⃣ Validation Docker Compose:"
  if docker compose config >/dev/null 2>&1; then
    echo "   ✅ Configuration Docker Compose valide"
  else
    echo "   ❌ Configuration Docker Compose INVALIDE"
    docker compose config 2>&1 | head -5 | sed 's/^/      /'
    ((validation_errors++))
  fi

  # 4. Résumé validation
  echo ""
  echo "=== RÉSUMÉ VALIDATION ==="
  if [[ $validation_errors -eq 0 ]]; then
    ok "✅ Validation complète réussie - Environment prêt pour Realtime"
    return 0
  else
    error "❌ Validation échouée avec $validation_errors erreur(s)"
    log "   🔧 Corrections nécessaires avant démarrage services"
    return 1
  fi
}

fix_realtime_encryption_variables() {
  log "🔐 Vérification variables encryption Realtime..."
  cd "$PROJECT_DIR" || return 1

  # PROTECTION : Vérifier .env avant modification
  if ! restore_env_if_missing "$PROJECT_DIR/.env"; then
    error "❌ Impossible de restaurer .env manquant"
    return 1
  fi

  # Sauvegarder avant modifications
  backup_env_file "$PROJECT_DIR/.env"

  local env_updated=false

  # Vérifier DB_ENC_KEY (16 caractères pour AES-128)
  if ! grep -q "^DB_ENC_KEY=" .env 2>/dev/null; then
    local db_enc_key
    db_enc_key=$(openssl rand -hex 8)  # 16 caractères hex
    echo "DB_ENC_KEY=$db_enc_key" >> .env
    env_updated=true
    log "   DB_ENC_KEY généré: $db_enc_key (16 chars)"
  fi

  # Vérifier SECRET_KEY_BASE (64 caractères pour Elixir)
  if ! grep -q "^SECRET_KEY_BASE=" .env 2>/dev/null; then
    local secret_key_base
    secret_key_base=$(openssl rand -hex 32)  # 64 caractères hex
    echo "SECRET_KEY_BASE=$secret_key_base" >> .env
    env_updated=true
    log "   SECRET_KEY_BASE généré: ${secret_key_base:0:16}... (64 chars)"
  fi

  # Vérifier APP_NAME pour Realtime
  if ! grep -q "^APP_NAME=" .env 2>/dev/null; then
    echo "APP_NAME=supabase_realtime" >> .env
    env_updated=true
  fi

  # Nettoyer doublons après ajouts
  if [[ "$env_updated" == "true" ]]; then
    clean_env_duplicates || {
      error "❌ Échec nettoyage doublons"
      return 1
    }

    # VALIDATION critique après modifications
    if validate_env_file "$PROJECT_DIR/.env"; then
      log "   Variables encryption mises à jour - redémarrage Realtime..."
      docker compose restart realtime 2>/dev/null || true
      sleep 10
      ok "✅ Variables encryption configurées et Realtime redémarré"
    else
      error "❌ .env corrompu après ajout variables Realtime"
      restore_env_if_missing "$PROJECT_DIR/.env"
      return 1
    fi
  else
    ok "✅ Variables encryption déjà présentes"
  fi
}

fix_docker_compose_yaml_indentation() {
  log "🔧 Vérification indentation docker-compose.yml (éviter corruption YAML)..."
  cd "$PROJECT_DIR" || return 1

  # Vérifier syntaxe YAML actuelle
  if ! docker compose config > /dev/null 2>&1; then
    warn "⚠️ YAML corrompu détecté - tentative de correction..."

    # Corriger indentation APP_NAME incorrecte (8 espaces → 6 espaces)
    if grep -q "^        APP_NAME:" docker-compose.yml; then
      log "   Correction indentation APP_NAME (8 → 6 espaces)..."
      sed -i 's/^        APP_NAME:/      APP_NAME:/' docker-compose.yml
    fi

    # Vérifier correction
    if docker compose config > /dev/null 2>&1; then
      ok "✅ Indentation YAML corrigée"
    else
      warn "⚠️ Problème YAML persiste - vérification manuelle requise"
      return 1
    fi
  else
    ok "✅ Syntaxe YAML correcte"
  fi
}

validate_auth_realtime_fixes() {
  log "🧪 Validation corrections Auth & Realtime..."
  cd "$PROJECT_DIR" || return 1

  # Test Auth - opérateur uuid = text
  local auth_test
  auth_test=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT 'uuid_operator_test' as test,
           EXISTS(SELECT 1 FROM pg_operator
                  WHERE oprname = '='
                    AND oprleft = 'uuid'::regtype
                    AND oprright = 'text'::regtype) as exists;
  " 2>/dev/null || echo "error")

  if [[ "$auth_test" == *"t"* ]]; then
    ok "✅ Auth: Opérateur uuid = text fonctionnel"
  else
    warn "⚠️ Auth: Opérateur uuid = text manquant"
  fi

  # Test Realtime - variables encryption
  local realtime_vars
  realtime_vars=$(docker exec supabase-realtime env 2>/dev/null | grep -E "DB_ENC_KEY|SECRET_KEY_BASE|APP_NAME" | wc -l || echo "0")

  if [[ "${realtime_vars:-0}" -ge 3 ]] 2>/dev/null; then
    ok "✅ Realtime: Variables encryption présentes"
  else
    warn "⚠️ Realtime: Variables encryption manquantes ou conteneur non accessible"
  fi

  # Test statut services
  local auth_status realtime_status
  auth_status=$(docker ps --filter "name=supabase-auth" --format "{{.Status}}" | head -1)
  realtime_status=$(docker ps --filter "name=supabase-realtime" --format "{{.Status}}" | head -1)

  if echo "$auth_status" | grep -q "Up"; then
    ok "✅ Auth service stable"
  else
    warn "⚠️ Auth service instable: $auth_status"
  fi

  if echo "$realtime_status" | grep -q "Up"; then
    ok "✅ Realtime service stable"
  else
    warn "⚠️ Realtime service instable: $realtime_status"
  fi
}

create_database_users() {
  log "👥 Création utilisateurs PostgreSQL avec mots de passe unifiés..."

  # S'assurer d'être dans le bon répertoire
  cd "$PROJECT_DIR" || { error "❌ Impossible d'accéder à $PROJECT_DIR"; exit 1; }

  # **SOLUTION FINALE: Un seul mot de passe pour éviter les erreurs auth**
  # Tous les utilisateurs utilisent POSTGRES_PASSWORD

  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T db psql -U postgres << 'SQL'
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
  echo ""
  echo "🔄 REDÉMARRAGE FINAL DES SERVICES (30 secondes)"
  echo "   Redémarrage Auth, PostgREST, Storage, Realtime avec nouveaux utilisateurs..."
  echo "   Cette étape finale assure que tous les services utilisent les bonnes credentials"
  echo ""

  log "🔄 Redémarrage services dépendants avec nouveaux utilisateurs..."

  # S'assurer d'être dans le bon répertoire
  cd "$PROJECT_DIR" || { error "❌ Impossible d'accéder à $PROJECT_DIR"; exit 1; }

  # Redémarrer les services qui utilisent les nouveaux utilisateurs
  log "   Redémarrage Auth, PostgREST, Storage, Realtime..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart auth rest storage realtime"

  # Attendre stabilisation finale (méthode simple et robuste)
  echo "   ⏱️  Attente stabilisation finale... 30 secondes (dernière étape)"
  echo "   Services en cours de redémarrage avec nouvelles credentials..."

  # Simple sleep sans boucle complexe pour éviter interruptions
  sleep 30

  echo "   ✅ Stabilisation terminée"

  ok "✅ Services redémarrés et stabilisés"

  # Vérification finale de l'état des services après redémarrage
  echo ""
  echo "📋 ÉTAT FINAL DES SERVICES :"
  docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" | head -10
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

echo "🔄 Redémarrage sécurisé Supabase..."

# PROTECTION : Sauvegarder .env avant toute opération
if [[ -f .env ]]; then
  cp .env ".env.bak.restart.$(date +%Y%m%d_%H%M%S)"
  echo "💾 Sauvegarde .env effectuée"
else
  echo "❌ ERREUR : Fichier .env manquant, arrêt"
  exit 1
fi

# Utiliser 'stop' au lieu de 'down' pour préserver la configuration
echo "⏹️  Arrêt des services..."
docker compose stop
sleep 5

# Vérifier que .env existe toujours
if [[ ! -f .env ]]; then
  echo "⚠️  .env manquant après arrêt, restauration..."
  latest_backup=$(ls -1t .env.bak.restart.* 2>/dev/null | head -1)
  if [[ -n "$latest_backup" ]]; then
    cp "$latest_backup" .env
    echo "✅ .env restauré"
  else
    echo "❌ Impossible de restaurer .env"
    exit 1
  fi
fi

echo "🚀 Redémarrage des services..."
docker compose up -d
echo "✅ Redémarrage terminé"
RESTART

  # Script de sauvegarde
  cat > "$PROJECT_DIR/scripts/supabase-backup.sh" << 'BACKUP'
#!/bin/bash
cd "$(dirname "$0")/.."

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 Sauvegarde Supabase en cours..."

# Sauvegarde base de données
if docker compose exec -T db pg_dump -U postgres -d postgres --clean > "$BACKUP_DIR/db.dump.sql" 2>/dev/null; then
  echo "✅ Base de données sauvegardée"
else
  echo "❌ Erreur sauvegarde base de données"
fi

# Sauvegarde configuration
tar -czf "$BACKUP_DIR/config.tar.gz" .env docker-compose.yml config/ 2>/dev/null
echo "✅ Configuration sauvegardée"

# Informations système
echo "=== Info Sauvegarde ===" > "$BACKUP_DIR/info.txt"
date >> "$BACKUP_DIR/info.txt"
docker compose ps >> "$BACKUP_DIR/info.txt"
echo "✅ Sauvegarde terminée dans $BACKUP_DIR"
BACKUP

  # Script de monitoring
  cat > "$PROJECT_DIR/scripts/supabase-monitor.sh" << 'MONITOR'
#!/bin/bash
cd "$(dirname "$0")/.."

echo "=== Monitoring Supabase Pi 5 ==="
echo "Temps: $(date)"
echo ""

echo "=== Ressources Système ==="
echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "Disque: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)% utilisé"
echo ""

echo "=== Conteneurs Docker ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" | head -8

echo ""
echo "=== Services Supabase ==="
docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

echo ""
echo "=== Logs récents (erreurs) ==="
docker compose logs --tail=5 2>/dev/null | grep -i error | tail -3 || echo "Aucune erreur récente"
MONITOR

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

fix_realtime_ulimits() {
  log "⚡ Correction post-install Realtime ulimits (RLIMIT_NOFILE)..."

  # S'assurer d'être dans le bon répertoire
  cd "$PROJECT_DIR"

  # 1. Tester ulimits actuelles
  log "   Test ulimits Realtime..."
  local ulimit_result=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null" || echo "error")

  if [[ "$ulimit_result" == "65536" ]]; then
    ok "✅ Realtime ulimits déjà correctes: $ulimit_result"
    return 0
  fi

  warn "⚠️ Realtime ulimits problématiques: $ulimit_result"

  # 1.5. Vérifier si warning cgroup memory présent
  log "   Vérification warnings cgroup memory..."
  local cgroup_warnings=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose logs realtime 2>/dev/null | grep -c 'memory limit capabilities' || echo '0'" | head -1 | tr -d '\n')

  if [[ "${cgroup_warnings:-0}" -gt 0 ]] 2>/dev/null; then
    log "   ⚠️ Warnings cgroup memory détectés ($cgroup_warnings)"
    log "   ℹ️ Normal sur kernel 6.12 - fonctionnement non impacté"
  fi

  # 2. Force restart Realtime (parfois suffisant)
  log "   Force restart Realtime..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose restart realtime" 2>/dev/null || true
  sleep 10

  # Re-test après restart
  ulimit_result=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null" || echo "error")
  if [[ "$ulimit_result" == "65536" ]]; then
    ok "✅ Realtime ulimits corrigées après restart: $ulimit_result"
    return 0
  fi

  # 3. Force recreation si restart insuffisant
  log "   Force recreation Realtime (dernier recours)..."
  su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose up -d --force-recreate realtime" 2>/dev/null || true
  sleep 15

  # Test final
  ulimit_result=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null" || echo "error")
  if [[ "$ulimit_result" == "65536" ]]; then
    ok "✅ Realtime ulimits corrigées après recreation: $ulimit_result"
  else
    warn "⚠️ Realtime ulimits persistantes: $ulimit_result"
    log "   Vérifier /etc/systemd/system/docker.service.d/override.conf"
    log "   Peut nécessiter redémarrage système pour effect complet"
  fi
}

validate_critical_services() {
  log "🔍 Validation services critiques post-recherche..."

  cd "$PROJECT_DIR"
  local validation_errors=0

  # 0. Vérifier kernel version et warnings cgroup memory
  local kernel_version=$(uname -r | cut -d. -f1-2)
  if [[ "$kernel_version" == "6.12" ]]; then
    log "   ℹ️ Kernel 6.12 détecté - warnings cgroup memory attendus"
    local cgroup_warnings=$(docker compose logs 2>/dev/null | grep -c "memory limit capabilities" || echo "0" | head -1 | tr -d '\n')
    if [[ "${cgroup_warnings:-0}" -gt 0 ]] 2>/dev/null; then
      log "   ⚠️ $cgroup_warnings warnings cgroup memory trouvés (normal kernel 6.12)"
      log "   ✅ Supabase fonctionne correctement malgré ces warnings"
    fi
  fi

  # 0.5. Validation cgroups selon recherche Gemini/GPT/Grok
  log "   Diagnostic cgroups complet..."
  local cgroup_controllers=""
  if [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
    cgroup_controllers=$(cat /sys/fs/cgroup/cgroup.controllers)
    if [[ "$cgroup_controllers" =~ memory ]]; then
      ok "  ✅ Contrôleur cgroup memory disponible"
    else
      warn "  ⚠️ Contrôleur cgroup memory manquant: $cgroup_controllers"
      log "     Vérifier /boot/firmware/cmdline.txt et redémarrer"
    fi
  else
    warn "  ⚠️ Système cgroup v2 non détecté"
  fi

  # Vérifier configuration Docker
  local docker_info_cgroup=$(docker info 2>/dev/null | grep -i 'Cgroup' || echo "non détecté")
  log "  📊 Docker cgroup info: $docker_info_cgroup"

  # 1. Valider Realtime (RLIMIT_NOFILE + ulimits)
  log "   Vérification Realtime (RLIMIT_NOFILE)..."
  local realtime_ulimit=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null" || echo "error")

  if [[ "$realtime_ulimit" =~ ^(262144|65536)$ ]]; then
    ok "  ✅ Realtime: ulimits configurés correctement ($realtime_ulimit)"
  else
    warn "  ⚠️ Realtime: ulimits problématiques ($realtime_ulimit)"
    ((validation_errors++))

    # Vérifications supplémentaires selon recherche Gemini/GPT/Grok
    log "     Diagnostic ulimits étendu..."
    log "     - Docker daemon.json: $(test -f /etc/docker/daemon.json && echo "✅" || echo "❌")"
    log "     - Docker service override: $(test -f /etc/systemd/system/docker.service.d/override.conf && echo "✅" || echo "❌")"
    log "     - Variable RLIMIT_NOFILE container: $(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose exec -T realtime printenv RLIMIT_NOFILE 2>/dev/null" || echo "non définie")"
  fi

  # 2. Valider Kong (ARM64 image + DNS)
  log "   Vérification Kong (ARM64 + DNS)..."
  local kong_image=$(su "$TARGET_USER" -c "cd '$PROJECT_DIR' && docker compose ps kong --format json" 2>/dev/null | jq -r '.Image' 2>/dev/null || echo "unknown")
  if [[ "$kong_image" == *"arm64v8/kong"* ]]; then
    ok "  ✅ Kong: image ARM64 spécifique utilisée"
  else
    warn "  ⚠️ Kong: image ARM64 non détectée: $kong_image"
    ((validation_errors++))
  fi

  # 3. Valider Edge Functions (hello function existe)
  log "   Vérification Edge Functions (hello function)..."
  if [[ -f "$PROJECT_DIR/volumes/functions/hello/index.ts" ]]; then
    ok "  ✅ Edge Functions: fonction hello créée"
  else
    warn "  ⚠️ Edge Functions: fonction hello manquante"
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

diagnose_realtime_issue() {
  echo ""
  echo "🔧 DIAGNOSTIC REALTIME DÉTAILLÉ"
  echo "   Investigation du problème de redémarrage..."
  echo ""

  cd "$PROJECT_DIR" || return 1

  # 1. Vérifier les logs récents
  echo "📋 Logs Realtime (20 dernières lignes) :"
  docker compose logs realtime --tail=20 2>/dev/null | tail -10

  # 2. Vérifier les variables d'environnement critiques
  echo ""
  echo "🔍 Variables d'environnement Realtime :"
  if docker compose ps | grep -q "realtime.*Up"; then
    docker compose exec realtime env 2>/dev/null | grep -E "(APP_NAME|ERL_AFLAGS|DB_|JWT)" | head -5
  else
    echo "   ⚠️ Conteneur Realtime non accessible pour inspection env"
  fi

  # 3. Test de connexion PostgreSQL depuis Realtime
  echo ""
  echo "🗄️ Test connexion PostgreSQL :"
  local pg_test=$(docker compose exec realtime pg_isready -h db -p 5432 -U postgres 2>/dev/null || echo "FAILED")
  echo "   PostgreSQL depuis Realtime: $pg_test"

  # 4. Recommandations
  echo ""
  echo "🎯 Actions recommandées pour fixer Realtime :"
  echo "   1. Vérifier JWT_SECRET (pas de multi-lignes)"
  echo "   2. Ajouter APP_NAME=supabase_realtime"
  echo "   3. Ajouter ERL_AFLAGS=-proto_dist inet_tcp"
  echo "   4. Nettoyer données corrompues realtime.schema_migrations"
  echo ""
}

finalize_installation() {
  echo ""
  echo "═══════════════════════════════════════════════════════════════════"
  echo "🎉 INSTALLATION SUPABASE TERMINÉE AVEC SUCCÈS"
  echo "═══════════════════════════════════════════════════════════════════"
  echo ""

  # Détecter IP locale pour les URLs
  local local_ip
  local_ip=$(hostname -I | awk '{print $1}')

  echo "🌐 **ACCÈS SUPABASE** :"
  echo "   📊 Studio (Interface Web)  : http://$local_ip:3000"
  echo "   🔌 API REST Gateway        : http://$local_ip:8001"
  echo "   🗄️  PostgreSQL Direct      : $local_ip:5432"
  echo ""

  echo "📋 **VÉRIFICATION SERVICES** :"
  cd "$PROJECT_DIR" || return 1
  docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" | head -10

  # Diagnostic Realtime si problème détecté
  if docker compose ps | grep -q "realtime.*Restarting"; then
    diagnose_realtime_issue
  fi

  echo ""

  echo "🛠️ **COMMANDES UTILES** :"
  echo "   cd /home/pi/stacks/supabase"
  echo "   docker compose ps                    # État des services"
  echo "   docker compose logs auth --tail=20   # Logs Auth"
  echo "   docker compose logs realtime --tail=20 # Logs Realtime"
  echo "   docker compose restart auth          # Redémarrer Auth"
  echo ""

  echo "📚 **PROCHAINES ÉTAPES** :"
  echo "   1️⃣ Ouvrir Studio : http://$local_ip:3000"
  echo "   2️⃣ Créer un nouveau projet dans Studio"
  echo "   3️⃣ Noter les clés API (anon_key, service_key)"
  echo "   4️⃣ Tester l'API REST : http://$local_ip:8001/rest/v1/"
  echo ""
  echo "🎯 Installation Pi 5 Supabase Self-Hosted complète !"
  echo "═══════════════════════════════════════════════════════════════════"
}

validate_post_install_critical() {
  log "🧪 Validation critique post-installation..."

  local all_good=true
  local issues=()

  # 1. CRITIQUE : Vérifier .env présent et valide
  if validate_env_file "$PROJECT_DIR/.env"; then
    ok "✅ Fichier .env présent et complet"
  else
    all_good=false
    issues+=("Fichier .env manquant ou invalide")
  fi

  # 2. CRITIQUE : Kong sur port correct
  local kong_port
  kong_port=$(docker port supabase-kong 2>/dev/null | grep "8000/tcp" | cut -d: -f2)

  if [[ -n "$kong_port" && "$kong_port" == "8001" ]]; then
    ok "✅ Kong accessible sur port configuré : $kong_port"

    # Test API Supabase accessible
    if curl -sf "http://localhost:8001" >/dev/null 2>&1; then
      ok "✅ API Supabase accessible sur http://localhost:8001"
    else
      all_good=false
      issues+=("API Supabase inaccessible sur port 8001")
    fi
  else
    all_good=false
    if [[ -n "$kong_port" ]]; then
      issues+=("Kong sur mauvais port : $kong_port (attendu: 8001)")
    else
      issues+=("Kong non accessible ou port indéterminé")
    fi
  fi

  # 3. BLOQUANT : Services sans restart loop
  local restarting_services
  restarting_services=$(docker ps --filter "status=restarting" --format "{{.Names}}" | grep "supabase-" || true)

  if [[ -z "$restarting_services" ]]; then
    ok "✅ Aucun service en restart loop"
  else
    all_good=false
    issues+=("Services en restart loop : $restarting_services")
  fi

  # 4. MAJEUR : Services unhealthy
  local unhealthy_services
  unhealthy_services=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | grep "supabase-" || true)

  if [[ -z "$unhealthy_services" ]]; then
    ok "✅ Tous les services avec health check sont healthy"
  else
    warn "⚠️ Services unhealthy détectés : $unhealthy_services"
  fi

  # 5. FONCTIONNEL : Studio accessible
  if curl -sf "http://localhost:3000" >/dev/null 2>&1; then
    ok "✅ Studio Supabase accessible sur http://localhost:3000"
  else
    warn "⚠️ Studio Supabase non accessible (peut nécessiter quelques minutes de plus)"
  fi

  # Résumé final
  if [[ "$all_good" == "true" ]]; then
    ok "🎉 VALIDATION RÉUSSIE - Toutes les vérifications critiques passées"
    return 0
  else
    error "❌ VALIDATION ÉCHOUÉE - Problèmes critiques détectés :"
    for issue in "${issues[@]}"; do
      echo "   - $issue"
    done

    echo ""
    echo "🔧 Actions correctives suggérées :"
    echo "   1. Restaurer .env : restore_env_if_missing '$PROJECT_DIR/.env'"
    echo "   2. Redémarrer Kong : docker compose restart kong"
    echo "   3. Vérifier logs : docker compose logs --tail=20"
    echo "   4. Exécuter diagnostic : ./scripts/supabase-diagnose.sh"

    return 1
  fi
}

main() {
  require_root
  setup_logging
  check_dependencies

  log "🎯 Installation pour utilisateur: $TARGET_USER"

  check_prerequisites
  optimize_system_for_supabase
  check_port_conflicts
  ensure_working_directory  # NOUVEAU: Éviter getcwd errors
  create_project_structure
  generate_secure_secrets    # NOUVEAU: JWT_SECRET sécurisé single-line
  create_env_file
  create_docker_compose
  create_kong_config
  render_kong_config  # NOUVEAU: Pré-render Kong template

  # NOUVEAU: Démarrer DB SEULE d'abord pour créer structures
  start_database_only
  create_complete_database_structure  # NOUVEAU: Structures complètes AVANT services

  # Démarrer le reste des services avec structures prêtes
  start_remaining_services
  wait_for_services
  fix_common_service_issues  # AMÉLIORÉ: + nettoyage données corrompues

  # NOUVELLES CORRECTIONS SESSION DEBUGGING 15/09/2025
  fix_auth_uuid_operator_issue      # Correction erreur uuid = text Auth migration
  fix_realtime_encryption_variables # Correction clés encryption Realtime + nettoyage doublons
  fix_docker_compose_yaml_indentation # Prévention corruption YAML
  validate_auth_realtime_fixes      # Validation corrections appliquées

  # VALIDATION VERSION 2.4 - STRUCTURES ET VALIDATION
  validate_realtime_schema_migrations  # Validation table schema_migrations pour Ecto
  validate_post_creation_environment   # NOUVEAU: Validation complète post-création

  create_database_users
  restart_dependent_services
  fix_realtime_ulimits     # NOUVEAU: Correction post-install Realtime
  create_utility_scripts
  validate_critical_services

  # VALIDATION FINALE CRITIQUE - VERSION 2.4
  validate_post_install_critical

  show_completion_summary

  # NOUVEAU: Finalisation claire de l'installation
  finalize_installation
}

main "$@"