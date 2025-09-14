#!/usr/bin/env bash
set -euo pipefail

# === FIX SUPABASE USERS - Script autonome de réparation ===

log()  { echo -e "\033[1;36m[FIX]    \033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

detect_supabase_directory() {
  local current_dir="$PWD"

  # Essayer répertoires courants possibles
  local possible_dirs=(
    "$current_dir"
    "/home/pi/stacks/supabase"
    "/home/$(whoami)/stacks/supabase"
    "$HOME/stacks/supabase"
  )

  for dir in "${possible_dirs[@]}"; do
    if [[ -f "$dir/.env" ]] && [[ -f "$dir/docker-compose.yml" ]]; then
      echo "$dir"
      return 0
    fi
  done

  return 1
}

fix_postgresql_users() {
  log "🔧 Réparation automatique utilisateurs PostgreSQL Supabase..."

  # Détecter automatiquement le répertoire Supabase
  local supabase_dir
  if supabase_dir=$(detect_supabase_directory); then
    ok "✅ Répertoire Supabase détecté : $supabase_dir"
    cd "$supabase_dir"
  else
    error "❌ Répertoire Supabase non trouvé"
    echo "   Script cherche dans : /home/pi/stacks/supabase, \$HOME/stacks/supabase, répertoire courant"
    exit 1
  fi

  # Charger automatiquement les variables
  if [[ -f ".env" ]]; then
    set -a  # export automatique des variables
    source .env
    set +a
    ok "✅ Variables d'environnement chargées automatiquement"
  else
    error "❌ Fichier .env manquant"
    exit 1
  fi

  # Vérifier que les variables essentielles existent
  if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    error "❌ Variable POSTGRES_PASSWORD manquante dans .env"
    exit 1
  fi

  # Arrêter services dépendants
  log "   Arrêt des services dépendants..."
  docker compose stop auth rest storage realtime edge-functions || true

  # S'assurer que PostgreSQL fonctionne
  log "🗄️ Vérification PostgreSQL..."
  docker compose up -d db >/dev/null 2>&1

  # Détection intelligente de l'utilisateur PostgreSQL
  local pg_user="supabase_admin"
  local db_ready=false
  local retry_count=0

  log "   Détection automatique utilisateur PostgreSQL..."

  while [[ $retry_count -lt 30 ]] && [[ $db_ready == false ]]; do
    # Essayer supabase_admin en premier
    if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
      pg_user="supabase_admin"
      db_ready=true
    # Fallback vers postgres si supabase_admin n'existe pas
    elif docker compose exec -T db psql -U postgres -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
      pg_user="postgres"
      db_ready=true
    else
      sleep 2
      ((retry_count++))
    fi
  done

  if [[ $db_ready == false ]]; then
    error "❌ PostgreSQL non accessible après $retry_count tentatives"
    log "Tentative de redémarrage..."
    docker compose restart db
    sleep 10
    if ! docker compose exec -T db pg_isready >/dev/null 2>&1; then
      error "❌ Impossible de réparer PostgreSQL"
      return 1
    fi
    pg_user="postgres"  # Après restart, utiliser postgres par défaut
  fi

  ok "✅ PostgreSQL accessible avec utilisateur: $pg_user"

  # Diagnostic des utilisateurs existants
  log "   Diagnostic utilisateurs existants..."
  docker compose exec -T db psql -U "$pg_user" -d postgres -c "SELECT rolname FROM pg_roles WHERE rolname IN ('supabase_admin', 'authenticator', 'anon', 'service_role', 'supabase_storage_admin');" -t 2>/dev/null || true

  # Script de réparation intelligent
  log "   Application corrections automatiques..."

  docker compose exec -T db psql -U "$pg_user" -d postgres << SQL
-- Créer tous les utilisateurs manquants et synchroniser les mots de passe
DO \$\$
BEGIN
  -- service_role (CRITIQUE pour Auth/RLS)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE USER service_role WITH BYPASSRLS CREATEDB PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created service_role user';
  ELSE
    -- S'assurer que le mot de passe est correct
    ALTER USER service_role WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated service_role password';
  END IF;

  -- supabase_admin (CRITIQUE - synchroniser mot de passe)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE USER supabase_admin WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created supabase_admin user';
  ELSE
    -- IMPORTANT: Synchroniser le mot de passe avec la variable d environnement
    ALTER USER supabase_admin WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Synchronized supabase_admin password with POSTGRES_PASSWORD';
  END IF;

  -- authenticator
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created authenticator user';
  ELSE
    ALTER USER authenticator WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated authenticator password';
  END IF;

  -- anon (pas de mot de passe)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE USER anon;
    RAISE NOTICE 'Created anon user';
  END IF;

  -- supabase_storage_admin
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Created supabase_storage_admin user';
  ELSE
    ALTER USER supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';
    RAISE NOTICE 'Updated supabase_storage_admin password';
  END IF;
END
\$\$;

-- Permissions essentielles (toujours réappliquer pour corriger les problèmes)
GRANT USAGE ON SCHEMA public TO anon, service_role;
GRANT CREATE ON SCHEMA public TO service_role;

-- Permissions pour authenticator (lier les rôles)
GRANT anon TO authenticator;
GRANT service_role TO authenticator;

-- Permissions étendues pour service_role
GRANT ALL PRIVILEGES ON DATABASE postgres TO service_role;
GRANT ALL PRIVILEGES ON SCHEMA public TO service_role;

-- Permissions pour supabase_admin et storage
GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_admin, supabase_storage_admin;

-- Extensions nécessaires pour Supabase
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

SELECT 'Réparation automatique terminée' as result;
\q
SQL

  if [[ $? -eq 0 ]]; then
    ok "✅ Utilisateurs PostgreSQL créés avec succès"
  else
    error "❌ Erreur lors de la création des utilisateurs"
    return 1
  fi

  # Redémarrer tous les services
  log "   Redémarrage des services..."
  docker compose up -d

  # Test rapide de connexion Auth après réparation
  log "   Test connexion supabase_admin..."
  sleep 5

  if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT 'Connexion OK' as test;" >/dev/null 2>&1; then
    ok "✅ Connexion supabase_admin confirmée"
  else
    warn "⚠️ Problème de connexion supabase_admin persistant"
  fi

  # Redémarrer spécifiquement les services Auth/Rest/Storage
  log "   Redémarrage forcé des services critiques..."
  docker compose restart auth rest storage realtime

  # Attendre que les services redémarrent
  log "   Attente stabilisation des services (30s)..."
  sleep 30

  # Vérifier l'état final
  local healthy_services=0
  local total_services=0

  while IFS= read -r line; do
    if [[ $line == *"supabase-"* ]]; then
      ((total_services++))
      if [[ $line == *"Up"* ]] && [[ $line != *"Restarting"* ]]; then
        ((healthy_services++))
      fi
    fi
  done < <(docker compose ps --format "table {{.Name}}\t{{.Status}}" | tail -n +2)

  ok "✅ Services actifs : $healthy_services/$total_services"

  if [[ $healthy_services -ge 6 ]]; then
    ok "🎉 Réparation réussie ! Supabase devrait maintenant fonctionner"
    echo ""
    echo "🌐 **Accès aux services** :"
    echo "   Studio      : http://$(hostname -I | awk '{print $1}'):3000"
    echo "   API Gateway : http://$(hostname -I | awk '{print $1}'):8001"
    echo ""
    echo "🔍 **Vérifier l'état** :"
    echo "   ./scripts/supabase-health.sh"
  else
    warn "⚠️ Certains services redémarrent encore - Attendre quelques minutes"
    echo ""
    echo "🔍 **Surveiller les logs** :"
    echo "   ./scripts/supabase-logs.sh auth"
    echo "   ./scripts/supabase-logs.sh rest"
  fi
}

main() {
  echo "==================== 🔧 RÉPARATION SUPABASE ===================="
  log "🩺 Réparation des utilisateurs PostgreSQL pour Supabase"
  echo ""

  # Vérifier qu'on est dans le bon répertoire
  if [[ "$(basename "$PWD")" != "supabase" ]]; then
    error "❌ Lancer depuis le répertoire /home/pi/stacks/supabase"
    echo "   cd /home/pi/stacks/supabase"
    echo "   ./scripts/fix-supabase-users.sh"
    exit 1
  fi

  fix_postgresql_users

  echo ""
  echo "==============================================================="
}

main "$@"