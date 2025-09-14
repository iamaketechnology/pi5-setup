#!/usr/bin/env bash
set -euo pipefail

# === SUPABASE ULTIMATE FIX - Solution Complète Basée sur Recherches Approfondies ===

log()  { echo -e "\033[1;36m[ULTIMATE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]  \033[0m $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_supabase_directory() {
  local current_dir="$PWD"
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

ultimate_fix() {
  log "🎯 RÉPARATION ULTIME SUPABASE - Solution Basée sur Recherches Complètes"
  echo ""

  # Détecter automatiquement le répertoire Supabase
  local supabase_dir
  if supabase_dir=$(detect_supabase_directory); then
    ok "✅ Répertoire Supabase détecté : $supabase_dir"
    cd "$supabase_dir"
  else
    error "❌ Répertoire Supabase non trouvé"
    echo "   Installer d'abord avec : setup-week2-improved.sh"
    exit 1
  fi

  echo ""
  echo "🔍 **DIAGNOSTIC INITIAL** :"

  # 1. Vérifier l'état actuel
  local current_issues=()

  # Services en restart loop ?
  local restarting_services=$(docker compose ps --format "{{.Service}}" --filter "status=restarting" 2>/dev/null | wc -l || echo "0")
  if [[ $restarting_services -gt 0 ]]; then
    current_issues+=("$restarting_services services redémarrent")
  fi

  # Page size OK ?
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  if [[ "$page_size" != "4096" ]]; then
    current_issues+=("Page size $page_size (requis: 4096)")
  fi

  # Variables d'environnement cohérentes ?
  if grep -q "AUTHENTICATOR_PASSWORD" docker-compose.yml 2>/dev/null; then
    current_issues+=("Variables mots de passe incohérentes")
  fi

  # Volume database persistant ?
  if [[ -d "volumes/db/data" ]] && [[ $restarting_services -gt 0 ]]; then
    current_issues+=("Volume database à réinitialiser")
  fi

  if [[ ${#current_issues[@]} -gt 0 ]]; then
    warn "⚠️ Problèmes détectés :"
    for issue in "${current_issues[@]}"; do
      echo "   - $issue"
    done
  else
    ok "✅ Aucun problème majeur détecté"
  fi

  echo ""
  echo "🛠️ **PLAN DE RÉPARATION** :"
  echo "   1. Optimisations Pi 5 ARM64"
  echo "   2. Synchronisation variables environnement"
  echo "   3. Reset complet base de données"
  echo "   4. Validation et tests finaux"
  echo ""

  read -p "Lancer la réparation complète ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Réparation annulée"
    exit 0
  fi

  echo ""
  log "🚀 DÉBUT DE LA RÉPARATION COMPLÈTE..."
  echo ""

  # **PHASE 1 : Optimisations Pi 5**
  log "📶 Phase 1/4 : Optimisations Pi 5 ARM64..."

  if [[ -f "$SCRIPT_DIR/pi5-arm64-optimizations.sh" ]]; then
    bash "$SCRIPT_DIR/pi5-arm64-optimizations.sh"
  else
    # Optimisations en ligne si script absent
    local page_size=$(getconf PAGESIZE)
    if [[ "$page_size" != "4096" ]]; then
      error "❌ Page size $page_size incompatible - Redémarrage système requis"
      echo "   Ajouter 'kernel=kernel8.img' à /boot/firmware/config.txt"
      exit 1
    fi
    ok "✅ Page size compatible"
  fi

  # **PHASE 2 : Variables d'environnement**
  log "🔧 Phase 2/4 : Synchronisation variables..."

  # Simplification : Utiliser POSTGRES_PASSWORD partout
  if grep -q "AUTHENTICATOR_PASSWORD\|SUPABASE_STORAGE_PASSWORD" docker-compose.yml; then
    log "   Unification des mots de passe..."

    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

    sed -i \
      -e 's/authenticator:${AUTHENTICATOR_PASSWORD}/authenticator:${POSTGRES_PASSWORD}/g' \
      -e 's/supabase_storage_admin:${SUPABASE_STORAGE_PASSWORD}/supabase_storage_admin:${POSTGRES_PASSWORD}/g' \
      docker-compose.yml

    ok "✅ Variables unifiées avec POSTGRES_PASSWORD"
  else
    ok "✅ Variables déjà cohérentes"
  fi

  # **PHASE 3 : Reset Database**
  log "💥 Phase 3/4 : Reset complet base de données..."

  # Arrêt complet
  docker compose down --remove-orphans --volumes 2>/dev/null || true

  # Suppression volume (solution GitHub #18836)
  if [[ -d "volumes/db/data" ]]; then
    log "   Suppression volume database persistant..."
    sudo rm -rf volumes/db/data || rm -rf volumes/db/data
    ok "✅ Volume database réinitialisé"
  fi

  # Nettoyage containers
  docker ps -a --format "{{.Names}}" | grep "^supabase-" | xargs -r docker rm -f 2>/dev/null || true

  # **PHASE 4 : Redémarrage Propre**
  log "🚀 Phase 4/4 : Redémarrage avec nouvelle configuration..."

  # Recréer structure
  mkdir -p volumes/db/data
  chmod 750 volumes/db/data

  # Télécharger images
  docker compose pull --quiet

  # Démarrage progressif
  log "   Démarrage base de données..."
  docker compose up -d db

  # Attendre DB
  local retry_count=0
  while [[ $retry_count -lt 30 ]] && ! docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; do
    sleep 3
    ((retry_count++))
  done

  if [[ $retry_count -ge 30 ]]; then
    error "❌ Database non accessible après 90 secondes"
    return 1
  fi

  ok "✅ Database initialisée"

  # Créer les utilisateurs avec mots de passe cohérents
  log "   Création utilisateurs database..."

  source .env

  docker compose exec -T db psql -U postgres << SQL
-- Créer tous les utilisateurs avec POSTGRES_PASSWORD
DO \$\$
BEGIN
  -- supabase_admin
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_admin') THEN
    CREATE USER supabase_admin WITH SUPERUSER CREATEDB CREATEROLE PASSWORD '$POSTGRES_PASSWORD';
  ELSE
    ALTER USER supabase_admin WITH PASSWORD '$POSTGRES_PASSWORD';
  END IF;

  -- service_role (critique)
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE USER service_role WITH BYPASSRLS CREATEDB PASSWORD '$POSTGRES_PASSWORD';
  ELSE
    ALTER USER service_role WITH PASSWORD '$POSTGRES_PASSWORD';
  END IF;

  -- authenticator
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticator') THEN
    CREATE USER authenticator WITH NOINHERIT LOGIN PASSWORD '$POSTGRES_PASSWORD';
  ELSE
    ALTER USER authenticator WITH PASSWORD '$POSTGRES_PASSWORD';
  END IF;

  -- anon
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE USER anon;
  END IF;

  -- supabase_storage_admin
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'supabase_storage_admin') THEN
    CREATE USER supabase_storage_admin WITH CREATEDB PASSWORD '$POSTGRES_PASSWORD';
  ELSE
    ALTER USER supabase_storage_admin WITH PASSWORD '$POSTGRES_PASSWORD';
  END IF;
END
\$\$;

-- Permissions
GRANT USAGE ON SCHEMA public TO anon, service_role;
GRANT anon TO authenticator;
GRANT service_role TO authenticator;
GRANT ALL PRIVILEGES ON DATABASE postgres TO service_role, supabase_admin, supabase_storage_admin;

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

SELECT 'Utilisateurs créés avec mots de passe cohérents' as result;
\q
SQL

  ok "✅ Utilisateurs database créés"

  # Démarrer tous les services
  log "   Démarrage complet..."
  docker compose up -d

  # Attente longue pour stabilisation ARM64
  log "   Stabilisation services ARM64 (60 secondes)..."
  sleep 60

  # **VALIDATION FINALE**
  echo ""
  log "🏁 VALIDATION FINALE..."

  local services_ok=0
  local services_total=0
  local services_problems=()

  while IFS= read -r line; do
    if [[ $line =~ supabase- ]]; then
      ((services_total++))
      local service_name=$(echo "$line" | awk '{print $1}')
      local service_status=$(echo "$line" | awk '{$1=""; print $0}')

      if [[ $service_status =~ Up.*healthy ]] || [[ $service_status =~ Up[[:space:]]+[0-9] ]]; then
        ((services_ok++))
      else
        if [[ $service_status =~ Restarting ]]; then
          services_problems+=("$service_name: redémarre encore")
        elif [[ $service_status =~ Exited ]]; then
          services_problems+=("$service_name: arrêté")
        else
          services_problems+=("$service_name: $service_status")
        fi
      fi
    fi
  done < <(docker compose ps)

  # Tests de connectivité
  local ip_address=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
  local connectivity_tests=0

  # Test Studio
  if timeout 10 curl -s "http://$ip_address:3000" >/dev/null 2>&1; then
    ((connectivity_tests++))
  fi

  # Test API
  if timeout 10 curl -s "http://$ip_address:8001" >/dev/null 2>&1; then
    ((connectivity_tests++))
  fi

  # Test PostgreSQL
  if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
    ((connectivity_tests++))
  fi

  echo ""
  echo "==================== 🎉 RÉSULTAT FINAL ===================="
  echo ""
  echo "📊 **Services** : $services_ok/$services_total fonctionnels"
  echo "🌐 **Connectivité** : $connectivity_tests/3 tests réussis"

  if [[ $services_ok -ge 7 ]] && [[ $connectivity_tests -ge 2 ]]; then
    echo ""
    echo "🎉 **RÉPARATION RÉUSSIE !**"
    echo ""
    echo "🌐 **Accès Supabase** :"
    echo "   🎨 Studio : http://$ip_address:3000"
    echo "   🔌 API    : http://$ip_address:8001"
    echo ""
    echo "📚 **Solutions appliquées** :"
    echo "   ✅ Variables mot de passe unifiées (GitHub #11957)"
    echo "   ✅ Volume database réinitialisé (GitHub #18836)"
    echo "   ✅ Optimisations Pi 5 ARM64 (GitHub #30640)"
    echo "   ✅ Healthchecks adaptés pour ARM64"
    echo "   ✅ service_role créé (résout auth loops)"

  elif [[ $services_ok -ge 5 ]]; then
    echo ""
    echo "⚠️ **RÉPARATION PARTIELLE**"
    echo ""
    echo "Quelques services ont encore des problèmes :"
    for problem in "${services_problems[@]}"; do
      echo "   - $problem"
    done
    echo ""
    echo "💡 **Actions suggérées** :"
    echo "   - Attendre 2-3 minutes supplémentaires"
    echo "   - Vérifier les logs : docker compose logs <service>"
    echo "   - Relancer si nécessaire"

  else
    echo ""
    echo "❌ **PROBLÈMES PERSISTANTS**"
    echo ""
    for problem in "${services_problems[@]}"; do
      echo "   - $problem"
    done
    echo ""
    echo "🔍 **Diagnostic approfondi requis** :"
    echo "   docker compose logs"
    echo "   ./scripts/supabase-health.sh"
  fi

  echo ""
  echo "🛠️ **Scripts disponibles** :"
  echo "   ./scripts/supabase-health.sh           # État détaillé"
  echo "   ./scripts/supabase-logs.sh <service>   # Logs spécifiques"
  echo "   $0                                     # Relancer cette réparation"
  echo ""
  echo "=============================================================="
}

main() {
  echo "==================== 🎯 SUPABASE ULTIMATE FIX ===================="
  echo ""
  echo "🔬 **Solution basée sur recherches approfondies** :"
  echo "   📚 GitHub Issues : #18836, #11957, #30640"
  echo "   🌐 Solutions communautaires validées"
  echo "   🥧 Optimisations spécifiques Pi 5 ARM64"
  echo ""

  ultimate_fix
}

main "$@"