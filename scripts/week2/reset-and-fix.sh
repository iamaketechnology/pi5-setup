#!/usr/bin/env bash
set -euo pipefail

# === RESET AND FIX - Réinitialisation complète et correction Supabase ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[RESET-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo ./reset-and-fix.sh"
    exit 1
  fi
}

install_entropy_fix() {
  log "🎲 Installation correctif entropie..."

  # Vérifier entropie actuelle
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")

  if [[ $entropy -lt 1000 ]]; then
    warn "⚠️ Entropie faible ($entropy) - Installation haveged..."

    if ! command -v haveged >/dev/null; then
      apt update -qq
      apt install -y haveged
      systemctl enable haveged
      systemctl start haveged
      ok "✅ haveged installé et démarré"
    else
      ok "✅ haveged déjà installé"
    fi

    # Attendre amélioration entropie
    sleep 3
    local new_entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
    echo "   Entropie après fix : $new_entropy bits"
  else
    ok "✅ Entropie suffisante ($entropy)"
  fi
}

phase1_complete_cleanup() {
  log "🧹 PHASE 1 : Nettoyage complet..."

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé : $PROJECT_DIR"
    exit 1
  fi

  cd "$PROJECT_DIR"

  # Arrêter tous les conteneurs
  log "   Arrêt de tous les services..."
  su "$TARGET_USER" -c "docker compose down --volumes --remove-orphans" 2>/dev/null || true

  # Nettoyer volumes PostgreSQL corrompus
  log "   Suppression données PostgreSQL corrompues..."
  if [[ -d "volumes/db/data" ]]; then
    rm -rf volumes/db/data/*
    ok "   ✅ Données PostgreSQL supprimées"
  fi

  # Nettoyer erreurs YAML
  log "   Nettoyage docker-compose.yml..."
  if [[ -f "docker-compose.yml" ]]; then
    # Backup
    cp docker-compose.yml "docker-compose.yml.backup.reset.$(date +%Y%m%d_%H%M%S)"

    # Supprimer RLIMIT_NOFILE mal placé
    sed -i '/^[[:space:]]*RLIMIT_NOFILE:/d' docker-compose.yml

    # Valider YAML
    if su "$TARGET_USER" -c "docker compose config >/dev/null 2>&1"; then
      ok "   ✅ docker-compose.yml valide"
    else
      error "   ❌ docker-compose.yml invalide"
      return 1
    fi
  fi

  ok "✅ PHASE 1 terminée"
}

phase2_postgresql_reset() {
  log "🗄️ PHASE 2 : Réinitialisation PostgreSQL..."

  cd "$PROJECT_DIR"

  # Créer répertoire data vide avec bonnes permissions
  log "   Préparation volume PostgreSQL..."
  mkdir -p volumes/db/data
  chown -R 70:70 volumes/db/data  # UID/GID postgres dans conteneur
  chmod 700 volumes/db/data

  # Démarrer uniquement PostgreSQL
  log "   Démarrage PostgreSQL seul..."
  su "$TARGET_USER" -c "docker compose up -d db"

  # Attendre initialisation complète (critique !)
  log "   Attente initialisation PostgreSQL (45s)..."
  local wait_time=45
  local check_interval=5

  for ((i=0; i<$wait_time; i+=$check_interval)); do
    if su "$TARGET_USER" -c "docker compose exec -T db pg_isready -U postgres" >/dev/null 2>&1; then
      sleep $check_interval  # Laisser plus de temps même si prêt
      echo -n "."
    else
      echo -n "x"
    fi
    sleep $check_interval
  done
  echo ""

  # Vérification finale
  if ! su "$TARGET_USER" -c "docker compose exec -T db pg_isready -U postgres" >/dev/null 2>&1; then
    error "❌ PostgreSQL pas prêt après $wait_time secondes"
    return 1
  fi

  ok "✅ PostgreSQL initialisé"

  # Créer utilisateurs manquants manuellement
  log "   Création utilisateurs PostgreSQL..."

  local passwords
  passwords=(
    "POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d'=' -f2)"
    "SUPABASE_AUTH_PASSWORD=$(grep '^SUPABASE_AUTH_PASSWORD=' .env | cut -d'=' -f2)"
    "AUTHENTICATOR_PASSWORD=$(grep '^AUTHENTICATOR_PASSWORD=' .env | cut -d'=' -f2)"
    "SUPABASE_STORAGE_PASSWORD=$(grep '^SUPABASE_STORAGE_PASSWORD=' .env | cut -d'=' -f2)"
  )

  # Charger mots de passe
  for pwd_line in "${passwords[@]}"; do
    export "$pwd_line"
  done

  # Script SQL pour créer tous les utilisateurs
  local create_users_sql="
-- Utilisateur administrateur Supabase
CREATE USER IF NOT EXISTS supabase_admin WITH SUPERUSER CREATEDB CREATEROLE REPLICATION BYPASSRLS LOGIN PASSWORD '${POSTGRES_PASSWORD}';

-- Utilisateur pour Auth service
CREATE USER IF NOT EXISTS supabase_auth_admin WITH CREATEDB CREATEROLE LOGIN PASSWORD '${SUPABASE_AUTH_PASSWORD}';

-- Utilisateur pour API (PostgREST)
CREATE USER IF NOT EXISTS authenticator WITH LOGIN PASSWORD '${AUTHENTICATOR_PASSWORD}';

-- Utilisateur pour Storage service
CREATE USER IF NOT EXISTS supabase_storage_admin WITH LOGIN PASSWORD '${SUPABASE_STORAGE_PASSWORD}';

-- Rôles pour JWT
CREATE ROLE IF NOT EXISTS anon NOLOGIN NOINHERIT;
CREATE ROLE IF NOT EXISTS authenticated NOLOGIN NOINHERIT;
CREATE ROLE IF NOT EXISTS service_role NOLOGIN NOINHERIT BYPASSRLS;

-- Accorder rôles à authenticator
GRANT anon TO authenticator;
GRANT authenticated TO authenticator;
GRANT service_role TO authenticator;
"

  # Exécuter création utilisateurs
  if su "$TARGET_USER" -c "echo \"$create_users_sql\" | docker compose exec -T db psql -U postgres"; then
    ok "   ✅ Utilisateurs créés"
  else
    warn "   ⚠️ Erreur création utilisateurs (peut-être déjà existants)"
  fi

  ok "✅ PHASE 2 terminée"
}

phase3_auth_configuration() {
  log "🔐 PHASE 3 : Configuration Auth..."

  cd "$PROJECT_DIR"

  # Créer schema auth avec bonnes permissions
  log "   Création schema auth..."

  local auth_sql="
-- Créer schema auth
CREATE SCHEMA IF NOT EXISTS auth;

-- Extensions nécessaires
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

-- Permissions schema auth
GRANT USAGE ON SCHEMA auth TO authenticator;
GRANT ALL ON SCHEMA auth TO supabase_admin;
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;

-- Schema realtime si pas présent
CREATE SCHEMA IF NOT EXISTS realtime;
GRANT USAGE ON SCHEMA realtime TO authenticator;

-- Schema storage si pas présent
CREATE SCHEMA IF NOT EXISTS storage;
GRANT USAGE ON SCHEMA storage TO authenticator;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin;

-- Schema extensions
CREATE SCHEMA IF NOT EXISTS extensions;
GRANT USAGE ON SCHEMA extensions TO authenticator;
"

  # Utiliser docker exec direct pour éviter les blocages
  local container_id=$(su "$TARGET_USER" -c "docker compose ps -q db")

  if [[ -n "$container_id" ]]; then
    if su "$TARGET_USER" -c "echo \"$auth_sql\" | docker exec -i \"$container_id\" psql -U postgres"; then
      ok "   ✅ Schemas configurés"
    else
      warn "   ⚠️ Erreur configuration schemas"
    fi
  else
    error "   ❌ Conteneur PostgreSQL introuvable"
    return 1
  fi

  ok "✅ PHASE 3 terminée"
}

phase4_progressive_startup() {
  log "🚀 PHASE 4 : Démarrage progressif des services..."

  cd "$PROJECT_DIR"

  local services=("auth" "rest" "realtime" "storage" "meta" "kong" "studio" "edge-functions")

  for service in "${services[@]}"; do
    log "   Démarrage $service..."
    su "$TARGET_USER" -c "docker compose up -d $service"

    # Attendre que le service soit stable
    sleep 10

    # Vérifier que le service n'est pas en restart
    if su "$TARGET_USER" -c "docker compose ps $service" | grep -q "Up"; then
      ok "   ✅ $service démarré"
    else
      warn "   ⚠️ $service instable - continuer quand même"
    fi
  done

  ok "✅ PHASE 4 terminée"
}

wait_for_stabilization() {
  log "⏳ Attente stabilisation finale (30s)..."

  cd "$PROJECT_DIR"

  for i in {30..1}; do
    if [[ $((i % 10)) -eq 0 ]]; then
      echo -n "   ⏳ $i secondes... "

      local restarting_count=$(su "$TARGET_USER" -c "docker compose ps" | grep -c "Restarting" || true)

      if [[ $restarting_count -eq 0 ]]; then
        echo "(Tous services stables)"
        break
      else
        echo "($restarting_count services redémarrent encore)"
      fi
    fi
    sleep 1
  done

  ok "✅ Stabilisation terminée"
}

show_final_status() {
  cd "$PROJECT_DIR"

  echo ""
  echo "==================== 🎉 RÉSULTAT FINAL ===================="

  su "$TARGET_USER" -c "docker compose ps --format \"table {{.Name}}\\t{{.Status}}\"" | head -12

  echo ""
  log "🧪 Tests de connectivité..."

  local tests_passed=0
  local tests_total=4

  # Test Studio
  if curl -s -I "http://localhost:3000" >/dev/null 2>&1; then
    ok "  ✅ Studio accessible (localhost:3000)"
    ((tests_passed++))
  else
    warn "  ❌ Studio non accessible"
  fi

  # Test API Gateway
  if curl -s -I "http://localhost:8001" >/dev/null 2>&1; then
    ok "  ✅ API Gateway accessible (localhost:8001)"
    ((tests_passed++))
  else
    warn "  ❌ API Gateway non accessible"
  fi

  # Test PostgreSQL
  if nc -z localhost 5432 2>/dev/null; then
    ok "  ✅ PostgreSQL accessible (localhost:5432)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL non accessible"
  fi

  # Test Edge Functions
  if curl -s -I "http://localhost:54321" >/dev/null 2>&1; then
    ok "  ✅ Edge Functions accessible (localhost:54321)"
    ((tests_passed++))
  else
    warn "  ❌ Edge Functions non accessible"
  fi

  echo ""
  local success_rate=$((tests_passed * 100 / tests_total))

  if [[ $success_rate -ge 90 ]]; then
    ok "🎉 SUCCÈS COMPLET ($success_rate%) - Supabase opérationnel !"
  elif [[ $success_rate -ge 70 ]]; then
    ok "🟡 SUCCÈS PARTIEL ($success_rate%) - La plupart des services fonctionnent"
  else
    warn "🔴 ÉCHEC ($success_rate%) - Problèmes persistants"
  fi

  echo ""
  local ip=$(hostname -I | awk '{print $1}')
  echo "🌐 **URLs d'accès** :"
  echo "   🎨 Studio : http://$ip:3000"
  echo "   🔌 API : http://$ip:8001"
  echo "   ⚡ Edge Functions : http://$ip:54321"
  echo "=============================================================="
}

main() {
  require_root

  echo "==================== 🔄 RESET AND FIX SUPABASE ===================="
  log "🚀 Réinitialisation complète et correction Supabase Pi 5"
  echo ""

  install_entropy_fix
  echo ""

  phase1_complete_cleanup
  echo ""

  phase2_postgresql_reset
  echo ""

  phase3_auth_configuration
  echo ""

  phase4_progressive_startup
  echo ""

  wait_for_stabilization

  show_final_status
}

main "$@"