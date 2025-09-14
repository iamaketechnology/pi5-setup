#!/usr/bin/env bash
set -euo pipefail

# === DIAGNOSTIC APPROFONDI PI 5 SUPABASE ===

log()  { echo -e "\033[1;36m[DIAG]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]  \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

PROJECT_DIR="${PROJECT_DIR:-$HOME/stacks/supabase}"
TARGET_USER="${SUDO_USER:-$USER}"

print_header() {
  echo "==================== 🔍 DIAGNOSTIC PI 5 SUPABASE ===================="
  echo "$(date)"
  echo "Utilisateur: $TARGET_USER"
  echo "======================================================================"
  echo ""
}

check_system_basics() {
  log "🖥️ Vérification système de base..."

  # Architecture
  local arch=$(uname -m)
  echo "   Architecture: $arch"

  # RAM
  local ram_total=$(free -h | awk '/^Mem:/{print $2}')
  local ram_used=$(free -h | awk '/^Mem:/{print $3}')
  local ram_available=$(free -h | awk '/^Mem:/{print $7}')
  echo "   RAM: $ram_used/$ram_total utilisée, $ram_available disponible"

  # Espace disque
  echo "   Espace disque:"
  df -h / | tail -1 | awk '{print "     Racine: " $3 "/" $2 " utilisé (" $5 ")"}'

  # Page size critique
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  if [[ "$page_size" == "4096" ]]; then
    ok "   Page size: ${page_size}B ✅ Compatible PostgreSQL"
  elif [[ "$page_size" == "16384" ]]; then
    error "   Page size: ${page_size}B ❌ INCOMPATIBLE PostgreSQL"
  else
    warn "   Page size: ${page_size}B ⚠️ Non standard"
  fi

  echo ""
}

check_docker_status() {
  log "🐳 État Docker..."

  if command -v docker >/dev/null; then
    local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    echo "   Version Docker: $docker_version"

    if systemctl is-active docker >/dev/null 2>&1; then
      ok "   Service Docker: Actif ✅"
    else
      error "   Service Docker: Inactif ❌"
    fi

    # Test fonctionnel Docker
    if docker info >/dev/null 2>&1; then
      ok "   Docker daemon: Accessible ✅"

      local containers_running=$(docker ps -q | wc -l)
      local containers_total=$(docker ps -aq | wc -l)
      echo "   Conteneurs: $containers_running actifs / $containers_total total"
    else
      error "   Docker daemon: Inaccessible ❌"
    fi

    # Docker Compose
    if command -v "docker compose" >/dev/null; then
      ok "   Docker Compose: Installé ✅"
    else
      error "   Docker Compose: Manquant ❌"
    fi
  else
    error "   Docker: Non installé ❌"
  fi

  echo ""
}

check_supabase_project() {
  log "📁 Projet Supabase..."

  if [[ -d "$PROJECT_DIR" ]]; then
    ok "   Répertoire: $PROJECT_DIR ✅"

    # Fichiers clés
    local key_files=(".env" "docker-compose.yml")
    for file in "${key_files[@]}"; do
      if [[ -f "$PROJECT_DIR/$file" ]]; then
        ok "   $file: Présent ✅"
      else
        error "   $file: Manquant ❌"
      fi
    done

    # Structure volumes
    if [[ -d "$PROJECT_DIR/volumes" ]]; then
      ok "   Volumes: Répertoire créé ✅"
      local volume_size=$(du -sh "$PROJECT_DIR/volumes" 2>/dev/null | cut -f1)
      echo "     Taille volumes: $volume_size"
    else
      warn "   Volumes: Répertoire manquant ⚠️"
    fi

  else
    error "   Répertoire projet: Manquant ❌"
    echo "     Attendu: $PROJECT_DIR"
  fi

  echo ""
}

check_supabase_services() {
  log "⚗️ Services Supabase..."

  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"

    # État global
    if docker compose ps >/dev/null 2>&1; then
      ok "   Docker Compose: Fonctionnel ✅"

      echo "   État des services:"
      docker compose ps --format "table {{.Name}}\t{{.Status}}" | while read -r line; do
        if [[ "$line" =~ "Up" ]] && [[ "$line" =~ "healthy" ]]; then
          echo "     ✅ $line"
        elif [[ "$line" =~ "Up" ]]; then
          echo "     ⚠️ $line"
        elif [[ "$line" =~ "Restarting" ]]; then
          echo "     🔄 $line"
        elif [[ "$line" =~ "Exit" ]]; then
          echo "     ❌ $line"
        else
          echo "     ℹ️ $line"
        fi
      done

    else
      error "   Docker Compose: Erreur configuration ❌"
    fi
  else
    warn "   Pas de docker-compose.yml trouvé ⚠️"
  fi

  echo ""
}

check_network_connectivity() {
  log "🌐 Connectivité réseau..."

  local services=(
    "3000:Supabase Studio"
    "8001:API Gateway"
    "5432:PostgreSQL"
    "54321:Edge Functions"
  )

  for service in "${services[@]}"; do
    local port=$(echo "$service" | cut -d: -f1)
    local name=$(echo "$service" | cut -d: -f2)

    if nc -z localhost "$port" 2>/dev/null; then
      ok "   $name (port $port): Accessible ✅"
    else
      error "   $name (port $port): Inaccessible ❌"
    fi
  done

  # Test externe
  local ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "inconnu")
  echo "   IP locale détectée: $ip"

  echo ""
}

check_database_connection() {
  log "🗄️ Base de données PostgreSQL..."

  if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"

    # Test conteneur DB
    local db_container=$(docker compose ps -q db 2>/dev/null || true)
    if [[ -n "$db_container" ]]; then
      if docker exec "$db_container" pg_isready -U postgres >/dev/null 2>&1; then
        ok "   PostgreSQL: Accessible ✅"

        # Test connexion complète
        if docker compose exec -T db psql -U postgres -c "SELECT version();" >/dev/null 2>&1; then
          ok "   Connexion SQL: Fonctionnelle ✅"

          # Utilisateurs importants
          local users_check=$(docker compose exec -T db psql -U postgres -t -c "SELECT rolname FROM pg_roles WHERE rolname IN ('postgres', 'authenticator', 'service_role', 'supabase_admin');" | tr -d ' ' | grep -v '^$' | wc -l)
          echo "   Utilisateurs PostgreSQL: $users_check/4 créés"

          # Schemas
          local schemas_check=$(docker compose exec -T db psql -U postgres -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('public', 'auth', 'storage');" | tr -d ' ' | grep -v '^$' | wc -l)
          echo "   Schemas: $schemas_check/3 créés"

        else
          error "   Connexion SQL: Échoue ❌"
        fi
      else
        error "   PostgreSQL: Inaccessible ❌"
      fi
    else
      error "   Conteneur DB: Introuvable ❌"
    fi
  fi

  echo ""
}

check_environment_variables() {
  log "🔧 Variables d'environnement..."

  if [[ -f "$PROJECT_DIR/.env" ]]; then
    cd "$PROJECT_DIR"

    # Variables critiques
    local critical_vars=(
      "POSTGRES_PASSWORD"
      "JWT_SECRET"
      "SUPABASE_ANON_KEY"
      "SUPABASE_SERVICE_KEY"
    )

    local vars_ok=0
    for var in "${critical_vars[@]}"; do
      if grep -q "^${var}=" .env; then
        local value=$(grep "^${var}=" .env | cut -d= -f2)
        if [[ -n "$value" && "$value" != "your-secret-here" ]]; then
          ok "   $var: Définie ✅"
          ((vars_ok++))
        else
          error "   $var: Vide ou par défaut ❌"
        fi
      else
        error "   $var: Manquante ❌"
      fi
    done

    echo "   Variables critiques: $vars_ok/${#critical_vars[@]} OK"
  else
    error "   Fichier .env: Manquant ❌"
  fi

  echo ""
}

check_logs_for_errors() {
  log "📋 Analyse des logs..."

  if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"

    echo "   Erreurs récentes détectées:"

    # Services principaux à vérifier
    local services=("db" "auth" "rest" "storage" "kong")

    local errors_found=false
    for service in "${services[@]}"; do
      if docker compose ps --format "{{.Name}}" | grep -q "$service"; then
        local recent_errors=$(docker compose logs "$service" --since="10m" 2>/dev/null | grep -i "error\|failed\|exception" | head -3)
        if [[ -n "$recent_errors" ]]; then
          echo "     🔴 $service:"
          echo "$recent_errors" | sed 's/^/       /'
          errors_found=true
        fi
      fi
    done

    if [[ "$errors_found" == false ]]; then
      ok "   Aucune erreur récente détectée ✅"
    fi
  fi

  echo ""
}

check_port_conflicts() {
  log "🚪 Conflits de ports..."

  local supabase_ports=(3000 8001 5432 54321)
  local conflicts=()

  for port in "${supabase_ports[@]}"; do
    local process=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d/ -f2 | head -1)
    if [[ -n "$process" ]]; then
      if [[ "$process" =~ docker ]]; then
        ok "   Port $port: Utilisé par Docker (normal) ✅"
      else
        warn "   Port $port: Utilisé par $process ⚠️"
        conflicts+=("$port:$process")
      fi
    else
      warn "   Port $port: Libre ⚠️"
    fi
  done

  if [[ ${#conflicts[@]} -gt 0 ]]; then
    echo "   Conflits détectés: ${#conflicts[@]}"
    for conflict in "${conflicts[@]}"; do
      echo "     - Port $(echo "$conflict" | cut -d: -f1): $(echo "$conflict" | cut -d: -f2)"
    done
  fi

  echo ""
}

generate_recommendations() {
  log "💡 Recommandations..."

  local issues=()

  # Vérifier page size
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  if [[ "$page_size" != "4096" ]]; then
    issues+=("Page size incompatible ($page_size): Ajouter 'kernel=kernel8.img' à /boot/firmware/config.txt et redémarrer")
  fi

  # Vérifier Docker
  if ! command -v docker >/dev/null; then
    issues+=("Docker manquant: Lancer setup-week1-enhanced-final.sh")
  fi

  # Vérifier projet
  if [[ ! -d "$PROJECT_DIR" ]]; then
    issues+=("Projet Supabase manquant: Lancer setup-week2-supabase-final.sh")
  fi

  # Services redémarrent
  if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"
    if docker compose ps 2>/dev/null | grep -q "Restarting"; then
      issues+=("Services en restart: Utiliser fix-remaining-issues.sh")
    fi
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    echo "   Actions recommandées:"
    for issue in "${issues[@]}"; do
      echo "     • $issue"
    done
  else
    ok "   Aucun problème majeur détecté ✅"
  fi

  echo ""
}

show_summary() {
  echo "==================== 📊 RÉSUMÉ DIAGNOSTIC ===================="
  echo ""

  # États principaux
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  local docker_ok=false
  local supabase_ok=false

  if command -v docker >/dev/null && systemctl is-active docker >/dev/null 2>&1; then
    docker_ok=true
  fi

  if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"
    if docker compose ps 2>/dev/null | grep -q "Up"; then
      supabase_ok=true
    fi
  fi

  echo "🖥️  Système Pi 5:"
  if [[ "$page_size" == "4096" ]]; then
    echo "   ✅ Page size compatible (4KB)"
  else
    echo "   ❌ Page size incompatible ($page_size)"
  fi

  echo ""
  echo "🐳 Docker:"
  if [[ "$docker_ok" == true ]]; then
    echo "   ✅ Installé et actif"
  else
    echo "   ❌ Non installé ou inactif"
  fi

  echo ""
  echo "⚗️  Supabase:"
  if [[ "$supabase_ok" == true ]]; then
    echo "   ✅ Services démarrés"

    local ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "IP-INCONNUE")
    echo ""
    echo "🔗 Accès services:"
    echo "   📊 Studio    : http://$ip:3000"
    echo "   🔌 API       : http://$ip:8001"
    echo "   ⚡ Functions : http://$ip:54321"
  else
    echo "   ❌ Non installé ou arrêté"
  fi

  echo ""
  echo "=================================================================="
}

main() {
  print_header

  check_system_basics
  check_docker_status
  check_supabase_project
  check_supabase_services
  check_network_connectivity
  check_database_connection
  check_environment_variables
  check_logs_for_errors
  check_port_conflicts
  generate_recommendations

  show_summary
}

main "$@"