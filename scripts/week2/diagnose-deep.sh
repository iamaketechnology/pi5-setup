#!/usr/bin/env bash
set -euo pipefail

# === DIAGNOSTIC APPROFONDI - Analyse complète des problèmes Supabase ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[DEEP-DIAG]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

check_system_entropy() {
  log "🎲 Vérification entropie système..."

  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")

  echo "   Entropie actuelle : $entropy bits"

  if [[ $entropy -lt 1000 ]]; then
    error "❌ Entropie faible ($entropy < 1000) - Peut causer blocages Docker"
    echo "   💡 Solution : sudo apt install haveged"
    echo "   💡 Ou : echo 'GRUB_CMDLINE_LINUX=\"rng_core.default_quality=500\"' >> /etc/default/grub && update-grub"
    return 1
  elif [[ $entropy -lt 2000 ]]; then
    warn "⚠️ Entropie modérée ($entropy) - Surveillez les blocages"
    return 2
  else
    ok "✅ Entropie suffisante ($entropy)"
    return 0
  fi
}

check_raspberry_pi_specifics() {
  log "🥧 Vérifications spécifiques Raspberry Pi..."

  # Page size
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "unknown")
  echo "   Page size : $page_size bytes"

  if [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB - Incompatible avec PostgreSQL"
    echo "   💡 Solution : Reconfigurer kernel avec page size 4KB"
    echo "   💡 Ou : utiliser postgres:15-alpine au lieu de supabase/postgres"
  elif [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible"
  else
    warn "⚠️ Page size $page_size - Vérifiez compatibilité"
  fi

  # Architecture
  local arch=$(uname -m)
  echo "   Architecture : $arch"

  if [[ "$arch" == "aarch64" ]]; then
    ok "✅ Architecture ARM64 détectée"
  else
    warn "⚠️ Architecture $arch - Tests effectués sur ARM64"
  fi

  # Modèle Pi
  if [[ -f /proc/device-tree/model ]]; then
    local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    echo "   Modèle : $model"
  fi
}

test_docker_connection_methods() {
  log "🐳 Test différentes méthodes de connexion Docker..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé : $PROJECT_DIR"
    return 1
  fi

  cd "$PROJECT_DIR"

  local container_id=$(docker compose ps -q db 2>/dev/null || true)

  if [[ -z "$container_id" ]]; then
    error "❌ Conteneur PostgreSQL non trouvé"
    return 1
  fi

  echo "   ID conteneur : $container_id"

  # Test 1 : docker compose exec -T
  log "   Test 1: docker compose exec -T..."
  if timeout 5 docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; then
    ok "   ✅ docker compose exec -T fonctionne"
  else
    warn "   ❌ docker compose exec -T échoue ou bloque"
  fi

  # Test 2 : docker compose exec -it
  log "   Test 2: docker compose exec interactif..."
  if timeout 5 bash -c "echo 'SELECT 1;' | docker compose exec -i db psql -U postgres" >/dev/null 2>&1; then
    ok "   ✅ docker compose exec interactif fonctionne"
  else
    warn "   ❌ docker compose exec interactif échoue"
  fi

  # Test 3 : docker exec direct
  log "   Test 3: docker exec direct..."
  if timeout 5 docker exec "$container_id" pg_isready -U postgres >/dev/null 2>&1; then
    ok "   ✅ docker exec direct fonctionne"
  else
    warn "   ❌ docker exec direct échoue"
  fi

  # Test 4 : Connexion avec utilisateur spécifique
  log "   Test 4: Connexion avec supabase_admin..."
  if timeout 5 docker exec "$container_id" psql -U supabase_admin -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    ok "   ✅ Utilisateur supabase_admin accessible"
  else
    warn "   ❌ Utilisateur supabase_admin inaccessible"
  fi
}

check_postgresql_users() {
  log "👥 Vérification utilisateurs PostgreSQL..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé"
    return 1
  fi

  cd "$PROJECT_DIR"

  local container_id=$(docker compose ps -q db 2>/dev/null || true)

  if [[ -z "$container_id" ]]; then
    error "❌ Conteneur PostgreSQL non trouvé"
    return 1
  fi

  local required_users=(
    "postgres"
    "supabase_admin"
    "supabase_auth_admin"
    "authenticator"
    "supabase_storage_admin"
    "anon"
    "authenticated"
    "service_role"
  )

  local existing_users=()

  for user in "${required_users[@]}"; do
    if timeout 5 docker exec "$container_id" psql -U postgres -t -c "SELECT 1 FROM pg_user WHERE usename='$user';" 2>/dev/null | grep -q "1"; then
      ok "   ✅ Utilisateur '$user' existe"
      existing_users+=("$user")
    else
      error "   ❌ Utilisateur '$user' manquant"
    fi
  done

  echo "   Utilisateurs trouvés : ${#existing_users[@]}/${#required_users[@]}"

  if [[ ${#existing_users[@]} -lt ${#required_users[@]} ]]; then
    warn "⚠️ Utilisateurs manquants - Réinitialisation recommandée"
    return 1
  else
    ok "✅ Tous les utilisateurs présents"
    return 0
  fi
}

check_postgresql_schemas() {
  log "🗄️ Vérification schemas PostgreSQL..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé"
    return 1
  fi

  cd "$PROJECT_DIR"

  local container_id=$(docker compose ps -q db 2>/dev/null || true)

  if [[ -z "$container_id" ]]; then
    error "❌ Conteneur PostgreSQL non trouvé"
    return 1
  fi

  local required_schemas=(
    "public"
    "auth"
    "realtime"
    "storage"
    "extensions"
  )

  local existing_schemas=()

  for schema in "${required_schemas[@]}"; do
    if timeout 5 docker exec "$container_id" psql -U postgres -t -c "SELECT 1 FROM information_schema.schemata WHERE schema_name='$schema';" 2>/dev/null | grep -q "1"; then
      ok "   ✅ Schema '$schema' existe"
      existing_schemas+=("$schema")
    else
      warn "   ❌ Schema '$schema' manquant"
    fi
  done

  echo "   Schemas trouvés : ${#existing_schemas[@]}/${#required_schemas[@]}"

  return 0
}

check_init_scripts() {
  log "📋 Vérification scripts d'initialisation..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé"
    return 1
  fi

  cd "$PROJECT_DIR"

  local init_files=(
    "volumes/db/realtime.sql"
    "volumes/db/roles.sql"
    "volumes/db/jwt.sql"
    "volumes/db/webhooks.sql"
  )

  local found_files=0

  for file in "${init_files[@]}"; do
    if [[ -f "$file" ]]; then
      ok "   ✅ $file présent ($(wc -l < "$file") lignes)"
      ((found_files++))
    else
      warn "   ❌ $file manquant"
    fi
  done

  echo "   Scripts trouvés : $found_files/${#init_files[@]}"

  if [[ $found_files -lt ${#init_files[@]} ]]; then
    warn "⚠️ Scripts d'initialisation manquants"
    echo "   💡 Peut expliquer pourquoi les utilisateurs n'existent pas"
    return 1
  else
    ok "✅ Tous les scripts d'initialisation présents"
    return 0
  fi
}

check_docker_logs() {
  log "📋 Analyse logs Docker récents..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé"
    return 1
  fi

  cd "$PROJECT_DIR"

  local services=("db" "auth" "realtime" "storage" "edge-functions")

  for service in "${services[@]}"; do
    echo ""
    log "   📋 Logs $service (5 dernières lignes) :"
    docker compose logs "$service" --tail=5 2>/dev/null | sed 's/^/      /' || echo "      Pas de logs disponibles"
  done
}

main() {
  echo "==================== 🔍 DIAGNOSTIC APPROFONDI ===================="
  log "🏥 Analyse complète des problèmes Supabase Pi 5"
  echo ""

  # Tests système
  check_system_entropy
  entropy_status=$?
  echo ""

  check_raspberry_pi_specifics
  echo ""

  # Tests Docker
  test_docker_connection_methods
  echo ""

  # Tests PostgreSQL
  check_postgresql_users
  users_status=$?
  echo ""

  check_postgresql_schemas
  echo ""

  check_init_scripts
  scripts_status=$?
  echo ""

  check_docker_logs

  # Résumé
  echo ""
  echo "==================== 📊 RÉSUMÉ DIAGNOSTIC ===================="

  local critical_issues=0

  if [[ $entropy_status -eq 1 ]]; then
    error "🔴 CRITIQUE : Entropie système trop faible"
    ((critical_issues++))
  fi

  if [[ $users_status -eq 1 ]]; then
    error "🔴 CRITIQUE : Utilisateurs PostgreSQL manquants"
    ((critical_issues++))
  fi

  if [[ $scripts_status -eq 1 ]]; then
    error "🟠 IMPORTANT : Scripts d'initialisation manquants"
  fi

  echo ""
  if [[ $critical_issues -eq 0 ]]; then
    ok "🟢 Aucun problème critique détecté"
    echo "   ✨ Le blocage peut être temporaire ou lié au timing"
  else
    error "🔴 $critical_issues problème(s) critique(s) détecté(s)"
    echo ""
    echo "🛠️ **Actions recommandées** :"

    if [[ $entropy_status -eq 1 ]]; then
      echo "   1. sudo apt install haveged"
    fi

    if [[ $users_status -eq 1 ]] || [[ $scripts_status -eq 1 ]]; then
      echo "   2. Réinitialisation complète avec reset-and-fix.sh"
    fi
  fi

  echo "=============================================================="
}

main "$@"