#!/usr/bin/env bash
set -euo pipefail

# === FIX SUPABASE USERS - Répare les utilisateurs PostgreSQL ===

log()  { echo -e "\033[1;36m[FIX]    \033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
PROJECT_DIR="${SCRIPT_DIR}/../.."

fix_postgresql_users() {
  log "🔧 Réparation utilisateurs PostgreSQL Supabase..."

  # Vérifier si on est dans le bon répertoire
  if [[ ! -f ".env" ]]; then
    error "❌ Fichier .env non trouvé - Lancer depuis /home/pi/stacks/supabase"
    exit 1
  fi

  # Charger variables d'environnement
  source .env

  # Vérifier que les variables essentielles existent
  if [[ -z "${POSTGRES_PASSWORD:-}" ]]; then
    error "❌ Variable POSTGRES_PASSWORD manquante dans .env"
    exit 1
  fi

  # Arrêter services dépendants
  log "   Arrêt des services dépendants..."
  docker compose stop auth rest storage realtime edge-functions || true

  # Attendre que PostgreSQL soit prêt
  log "   Attente PostgreSQL..."
  local retry_count=0
  while ! docker compose exec -T db pg_isready -U supabase_admin >/dev/null 2>&1 && [[ $retry_count -lt 30 ]]; do
    sleep 1
    ((retry_count++))
  done

  if [[ $retry_count -ge 30 ]]; then
    error "❌ PostgreSQL non accessible"
    return 1
  fi

  ok "   ✅ PostgreSQL accessible"

  # Vérifier quels utilisateurs existent déjà
  log "   Vérification des utilisateurs existants..."

  local existing_users=$(docker compose exec -T db psql -U supabase_admin -d postgres -c "\du" -t | awk '{print $1}' | grep -v "^$" | tr '\n' ' ')
  echo "   Utilisateurs existants: $existing_users"

  # Créer/réparer seulement les utilisateurs manquants ou problématiques
  log "   Réparation des utilisateurs PostgreSQL..."

  docker compose exec -T db psql -U supabase_admin -d postgres << SQL
-- Créer service_role si manquant (critique pour Auth/RLS)
DROP USER IF EXISTS service_role;
CREATE USER service_role WITH
  BYPASSRLS
  CREATEDB
  PASSWORD '$POSTGRES_PASSWORD';

-- Vérifier et réparer authenticator
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD';
  END IF;
END
\$\$;

-- Vérifier et réparer anon
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE USER anon;
  END IF;
END
\$\$;

-- Vérifier et réparer supabase_storage_admin
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '$POSTGRES_PASSWORD';
  END IF;
END
\$\$;

-- Permissions essentielles (toujours réappliquer)
GRANT USAGE ON SCHEMA public TO anon, service_role;
GRANT CREATE ON SCHEMA public TO service_role, supabase_admin;

-- Permissions pour authenticator (lier les rôles)
GRANT anon TO authenticator;
GRANT service_role TO authenticator;

-- Permissions étendues pour service_role
GRANT ALL PRIVILEGES ON DATABASE postgres TO service_role;
GRANT ALL PRIVILEGES ON SCHEMA public TO service_role;

-- Permissions pour supabase_storage_admin
GRANT ALL PRIVILEGES ON DATABASE postgres TO supabase_storage_admin;

-- Créer extensions si manquantes
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

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

  # Attendre que les services redémarrent
  log "   Attente stabilisation des services..."
  sleep 10

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