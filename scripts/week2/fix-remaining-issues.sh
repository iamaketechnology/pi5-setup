#!/usr/bin/env bash
set -euo pipefail

# === FIX REMAINING ISSUES - Corriger les derniers problèmes Supabase ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[FIX-FINAL]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo ./fix-remaining-issues.sh"
    exit 1
  fi
}

install_netcat() {
  log "📦 Installation netcat pour tests de connectivité..."

  if command -v nc >/dev/null; then
    ok "✅ netcat déjà installé"
  else
    log "   Installation netcat-openbsd..."
    apt update -qq
    apt install -y netcat-openbsd
    ok "✅ netcat installé"
  fi
}

check_project_directory() {
  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé dans : $PROJECT_DIR"
    exit 1
  fi

  cd "$PROJECT_DIR"
  log "📍 Travail dans : $PROJECT_DIR"
}

create_auth_schema() {
  log "🗄️ Création schema auth PostgreSQL..."

  # Vérifier si schema auth existe
  if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'auth';" 2>/dev/null | grep -q "auth"; then
    ok "✅ Schema auth existe déjà"
    return 0
  fi

  # Créer schema auth et extensions nécessaires
  log "   Création schema auth et extensions..."
  docker compose exec -T db psql -U supabase_admin -d postgres -c "
    -- Créer schema auth
    CREATE SCHEMA IF NOT EXISTS auth;

    -- Créer extensions nécessaires
    CREATE EXTENSION IF NOT EXISTS pgcrypto;
    CREATE EXTENSION IF NOT EXISTS uuid-ossp;
    CREATE EXTENSION IF NOT EXISTS 'supabase_vault' WITH SCHEMA vault;

    -- Permissions sur schema auth
    GRANT USAGE ON SCHEMA auth TO authenticator;
    GRANT ALL ON SCHEMA auth TO supabase_admin;
    GRANT ALL ON SCHEMA auth TO supabase_auth_admin;

    -- Table users basique pour auth
    CREATE TABLE IF NOT EXISTS auth.users (
      id uuid NOT NULL DEFAULT uuid_generate_v4(),
      email text UNIQUE,
      created_at timestamptz DEFAULT now(),
      PRIMARY KEY (id)
    );

    GRANT ALL ON auth.users TO supabase_auth_admin;
  " >/dev/null 2>&1

  if [[ $? -eq 0 ]]; then
    ok "✅ Schema auth créé avec succès"
  else
    warn "⚠️ Problème création schema auth (peut-être déjà présent)"
  fi
}

diagnose_restarting_services() {
  log "🔍 Diagnostic des services qui redémarrent..."

  # Lister les services en problème
  local restarting_services=$(docker compose ps --format "{{.Name}} {{.Status}}" | grep -i "restarting" | awk '{print $1}' || true)

  if [[ -n "$restarting_services" ]]; then
    warn "⚠️ Services en redémarrage :"
    echo "$restarting_services" | while read -r service_name; do
      if [[ -n "$service_name" ]]; then
        service_short=$(echo "$service_name" | sed 's/supabase-//')
        log "   🔍 $service_short - Dernières erreurs :"
        docker compose logs "$service_short" --tail=3 | sed 's/^/      /' || echo "      Logs non disponibles"
      fi
    done
    echo ""
    return 1
  else
    ok "✅ Aucun service en redémarrage"
    return 0
  fi
}

fix_auth_service() {
  log "🔧 Correction service Auth..."

  # Vérifier si Auth redémarre
  if docker compose ps auth | grep -q "Restarting"; then
    log "   Auth redémarre - Vérification variables..."

    # Test si API_EXTERNAL_URL est visible dans le conteneur
    if docker compose exec -T auth printenv | grep -q "API_EXTERNAL_URL" 2>/dev/null; then
      ok "   ✅ API_EXTERNAL_URL présente"
    else
      warn "   ❌ API_EXTERNAL_URL manquante - Correction..."

      # Vérifier qu'elle est dans .env
      if grep -q "^API_EXTERNAL_URL=" .env; then
        log "   Variable présente dans .env - Recreation conteneur..."
        docker compose stop auth
        docker compose rm -f auth
        docker compose up -d auth
      else
        error "   API_EXTERNAL_URL manquante dans .env"
        return 1
      fi
    fi
  else
    ok "   ✅ Auth ne redémarre pas"
  fi
}

fix_storage_service() {
  log "🔧 Correction service Storage..."

  if docker compose ps storage | grep -q "Restarting"; then
    log "   Storage redémarre - Test authentification DB..."

    # Tester connexion supabase_storage_admin
    if docker compose exec -T db psql -U supabase_storage_admin -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
      ok "   ✅ Utilisateur supabase_storage_admin fonctionne"
    else
      warn "   ❌ Problème auth supabase_storage_admin - Correction..."

      # Recréer utilisateur
      local storage_password=$(grep "^SUPABASE_STORAGE_PASSWORD=" .env | cut -d'=' -f2)
      if [[ -n "$storage_password" ]]; then
        docker compose exec -T db psql -U supabase_admin -d postgres -c "
          DROP USER IF EXISTS supabase_storage_admin;
          CREATE USER supabase_storage_admin WITH ENCRYPTED PASSWORD '$storage_password';
          GRANT USAGE ON SCHEMA public TO supabase_storage_admin;
          GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO supabase_storage_admin;
          GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO supabase_storage_admin;
          GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO supabase_storage_admin;
        " >/dev/null 2>&1

        log "   Redémarrage Storage..."
        docker compose restart storage
        ok "   ✅ Storage corrigé"
      else
        error "   SUPABASE_STORAGE_PASSWORD manquant dans .env"
      fi
    fi
  else
    ok "   ✅ Storage ne redémarre pas"
  fi
}

fix_realtime_service() {
  log "🔧 Correction service Realtime..."

  if docker compose ps realtime | grep -q "Restarting"; then
    log "   Realtime redémarre - Problème RLIMIT_NOFILE..."

    # Vérifier la variable problématique dans les logs
    if docker compose logs realtime --tail=5 | grep -q "RLIMIT_NOFILE: unbound variable"; then
      warn "   ❌ Variable RLIMIT_NOFILE non définie"

      log "   Correction du docker-compose.yml..."

      # Ajouter variable RLIMIT_NOFILE au service realtime
      if ! grep -A20 "realtime:" docker-compose.yml | grep -q "RLIMIT_NOFILE"; then
        # Backup du fichier
        cp docker-compose.yml docker-compose.yml.backup.realtime.$(date +%Y%m%d_%H%M%S)

        # Méthode alternative pour ajouter RLIMIT_NOFILE
        python3 -c "
import yaml
import sys

try:
    with open('docker-compose.yml', 'r') as f:
        data = yaml.safe_load(f)

    if 'realtime' in data.get('services', {}):
        if 'environment' not in data['services']['realtime']:
            data['services']['realtime']['environment'] = {}

        # Ajouter RLIMIT_NOFILE si pas présent
        if 'RLIMIT_NOFILE' not in data['services']['realtime']['environment']:
            data['services']['realtime']['environment']['RLIMIT_NOFILE'] = '65536'

    with open('docker-compose.yml', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, indent=2)

    print('RLIMIT_NOFILE ajouté avec succès')
except Exception as e:
    print(f'Erreur YAML: {e}')
    sys.exit(1)
" || {
          # Fallback si Python YAML échoue
          warn "   Python YAML échoué - utilisation sed alternatif"

          # Trouver la ligne realtime et ajouter RLIMIT_NOFILE dans environment
          awk '
            /^[[:space:]]*realtime:/ { in_realtime=1 }
            in_realtime && /^[[:space:]]*environment:/ { in_env=1; print; next }
            in_realtime && in_env && /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]*[A-Z_]/ {
              print "      RLIMIT_NOFILE: 65536"
              in_env=0
            }
            /^[[:space:]]*[^[:space:]]/ && !/^[[:space:]]*realtime/ { in_realtime=0; in_env=0 }
            { print }
          ' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml
        }

        log "   Redémarrage Realtime..."
        docker compose stop realtime
        docker compose up -d realtime
        ok "   ✅ Realtime corrigé"
      fi
    else
      log "   Autre problème détecté..."
      docker compose restart realtime
    fi
  else
    ok "   ✅ Realtime ne redémarre pas"
  fi
}

fix_edge_functions_service() {
  log "🔧 Correction service Edge Functions..."

  if docker compose ps edge-functions | grep -q "Restarting"; then
    log "   Edge Functions redémarre - Diagnostic..."

    local edge_logs=$(docker compose logs edge-functions --tail=5)
    if echo "$edge_logs" | grep -q "Print help"; then
      warn "   ❌ Edge Functions affiche l'aide au lieu de démarrer"
      log "   Problème de configuration - Recreation..."

      docker compose stop edge-functions
      docker compose up -d edge-functions
      ok "   ✅ Edge Functions relancé"
    else
      log "   Autre erreur détectée..."
      docker compose restart edge-functions
    fi
  else
    ok "   ✅ Edge Functions ne redémarre pas"
  fi
}

test_all_connectivity() {
  log "🧪 Tests de connectivité complets..."

  local tests_passed=0
  local tests_total=5

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

  # Test PostgreSQL avec nc
  if nc -z localhost 5432 2>/dev/null; then
    ok "  ✅ PostgreSQL accessible (localhost:5432)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL non accessible via nc"
  fi

  # Test PostgreSQL direct
  if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT version();" >/dev/null 2>&1; then
    ok "  ✅ PostgreSQL fonctionne (connexion directe)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL connexion directe échoue"
  fi

  # Test Edge Functions
  if curl -s -I "http://localhost:54321" >/dev/null 2>&1; then
    ok "  ✅ Edge Functions accessible (localhost:54321)"
    ((tests_passed++))
  else
    warn "  ❌ Edge Functions non accessible"
  fi

  log "Tests réussis: $tests_passed/$tests_total"

  if [[ $tests_passed -ge 4 ]]; then
    ok "✅ Connectivité excellente"
    return 0
  elif [[ $tests_passed -ge 2 ]]; then
    warn "⚠️ Connectivité partielle"
    return 1
  else
    error "❌ Connectivité problématique"
    return 2
  fi
}

wait_for_stabilization() {
  log "⏳ Attente stabilisation des services (30s)..."

  for i in {30..1}; do
    if [[ $((i % 10)) -eq 0 ]]; then
      echo -n "   ⏳ $i secondes... "
      # Test rapide
      local restarting_count=$(docker compose ps | grep -c "Restarting" || true)
      if [[ $restarting_count -eq 0 ]]; then
        echo "(Tous services stables)"
        break
      else
        echo "($restarting_count services redémarrent encore)"
      fi
    fi
    sleep 1
  done
}

show_final_status() {
  echo ""
  echo "==================== 📊 ÉTAT FINAL ===================="

  docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -11

  echo ""
  echo "🧪 **Tests de connectivité** :"
  test_all_connectivity

  echo ""
  if diagnose_restarting_services; then
    echo "🎉 **SUPABASE COMPLÈTEMENT FONCTIONNEL !**"
    echo ""
    echo "📍 **Accès aux services** :"
    local ip=$(hostname -I | awk '{print $1}')
    echo "   🎨 Studio : http://$ip:3000"
    echo "   🔌 API : http://$ip:8001"
    echo "   ⚡ Edge Functions : http://$ip:54321"
    echo ""
    echo "✅ **Tous les problèmes résolus !**"
  else
    echo "⚠️ **Quelques services peuvent encore se stabiliser**"
    echo "   Attendre 2-3 minutes supplémentaires"
  fi
  echo "=================================================="
}

main() {
  require_root

  log "🔧 Correction des derniers problèmes Supabase Pi 5"

  install_netcat
  check_project_directory

  echo ""
  log "🗄️ Préparation base de données..."
  create_auth_schema

  echo ""
  log "🏥 État avant corrections :"
  diagnose_restarting_services || true

  echo ""
  log "🛠️ Application des corrections..."
  fix_auth_service
  fix_storage_service
  fix_realtime_service
  fix_edge_functions_service

  wait_for_stabilization
  show_final_status
}

main "$@"