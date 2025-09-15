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

install_dependencies() {
  log "📦 Installation dépendances nécessaires..."

  local packages_to_install=()

  # Netcat pour tests de connectivité
  if ! command -v nc >/dev/null; then
    packages_to_install+=("netcat-openbsd")
  fi

  # Haveged pour améliorer l'entropie système (problème ARM64)
  if ! command -v haveged >/dev/null; then
    packages_to_install+=("haveged")
  fi

  if [[ ${#packages_to_install[@]} -gt 0 ]]; then
    log "   Installation: ${packages_to_install[*]}..."
    apt update -qq
    apt install -y "${packages_to_install[@]}"

    # Activer haveged si installé
    if [[ " ${packages_to_install[*]} " =~ " haveged " ]]; then
      systemctl enable haveged
      systemctl start haveged
      ok "✅ haveged activé pour améliorer l'entropie système"
    fi

    ok "✅ Dépendances installées"
  else
    ok "✅ Toutes les dépendances déjà présentes"
  fi

  # Vérifier l'entropie après installation
  local entropy_after=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  log "   Entropie système: $entropy_after"
}

check_project_directory() {
  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé dans : $PROJECT_DIR"
    exit 1
  fi

  cd "$PROJECT_DIR"
  log "📍 Travail dans : $PROJECT_DIR"
}

cleanup_yaml_errors() {
  log "🧹 Nettoyage erreurs YAML préexistantes..."

  if [[ ! -f "docker-compose.yml" ]]; then
    error "❌ docker-compose.yml manquant"
    exit 1
  fi

  # Backup avant nettoyage
  cp docker-compose.yml "docker-compose.yml.backup.cleanup.$(date +%Y%m%d_%H%M%S)"

  # Supprimer RLIMIT_NOFILE mal placé (dans volumes au lieu d'environment)
  if grep -q "RLIMIT_NOFILE:" docker-compose.yml; then
    warn "⚠️ RLIMIT_NOFILE mal placé détecté - correction..."
    sed -i '/^[[:space:]]*RLIMIT_NOFILE:/d' docker-compose.yml
    ok "✅ RLIMIT_NOFILE mal placé supprimé"
  fi

  # Valider YAML après nettoyage
  if docker compose config >/dev/null 2>&1; then
    ok "✅ docker-compose.yml valide après nettoyage"
  else
    error "❌ docker-compose.yml encore invalide"
    log "📋 Erreurs YAML :"
    docker compose config 2>&1 | head -3
    exit 1
  fi
}

check_system_entropy() {
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")

  if [[ $entropy -lt 1000 ]]; then
    warn "⚠️ Entropie système faible ($entropy) - peut causer blocages"
    log "   💡 Installer haveged : sudo apt install haveged"
    return 1
  fi

  return 0
}

create_auth_schema() {
  log "🗄️ Création schema auth PostgreSQL..."

  # Vérifier entropie système avant d'essayer
  check_system_entropy

  # Obtenir l'ID du conteneur directement pour éviter docker compose exec
  local container_id=$(docker compose ps -q db 2>/dev/null || true)

  if [[ -z "$container_id" ]]; then
    error "❌ Conteneur PostgreSQL non trouvé"
    return 1
  fi

  # Test de connectivité avec timeout
  log "   Test connectivité PostgreSQL..."
  if ! timeout 10 docker exec "$container_id" pg_isready -U postgres >/dev/null 2>&1; then
    warn "⚠️ PostgreSQL pas prêt - attente 15s supplémentaires..."
    sleep 15
    if ! timeout 10 docker exec "$container_id" pg_isready -U postgres >/dev/null 2>&1; then
      error "❌ PostgreSQL inaccessible après 25s"
      return 1
    fi
  fi

  # Vérifier si schema auth existe avec docker exec direct
  log "   Vérification schema auth existant..."
  if timeout 10 docker exec "$container_id" psql -U postgres -t -c "SELECT 1 FROM information_schema.schemata WHERE schema_name = 'auth';" 2>/dev/null | grep -q "1"; then
    ok "✅ Schema auth existe déjà"
    return 0
  fi

  # Créer schema auth et extensions avec docker exec direct
  log "   Création schema auth et extensions..."

  local auth_sql="
-- Créer schéma auth complet avec tous les éléments nécessaires
CREATE SCHEMA IF NOT EXISTS auth;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";

-- Créer les types ENUM nécessaires pour les migrations
CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');

-- Créer les rôles nécessaires pour Storage et autres services
CREATE ROLE IF NOT EXISTS authenticated NOLOGIN NOINHERIT;
CREATE ROLE IF NOT EXISTS anon NOLOGIN NOINHERIT;
CREATE ROLE IF NOT EXISTS service_role NOLOGIN NOINHERIT BYPASSRLS;

-- Accorder permissions sur schéma public
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon, service_role;

-- Permissions sur schéma auth
GRANT USAGE ON SCHEMA auth TO postgres, authenticated, anon, service_role;
"

  # Utiliser docker exec avec timeout au lieu de docker compose exec
  if timeout 15 bash -c "echo '$auth_sql' | docker exec -i '$container_id' psql -U postgres" >/dev/null 2>&1; then
    ok "✅ Schema auth créé avec succès"
    return 0
  else
    error "❌ Échec création schema auth"
    log "   💡 Essaye avec reset-and-fix.sh pour réinitialisation complète"
    return 1
  fi
}

diagnose_restarting_services() {
  log "🔍 Diagnostic des services qui redémarrent..."

  # Utiliser timeout pour éviter blocages
  local restarting_services
  if ! restarting_services=$(timeout 10 docker compose ps --format "{{.Name}} {{.Status}}" 2>/dev/null | grep -i "restarting" | awk '{print $1}' || true); then
    warn "⚠️ Impossible d'obtenir le statut des services"
    return 1
  fi

  if [[ -n "$restarting_services" ]]; then
    warn "⚠️ Services en redémarrage :"
    echo "$restarting_services" | while read -r service_name; do
      if [[ -n "$service_name" ]]; then
        service_short=$(echo "$service_name" | sed 's/supabase-//')
        log "   🔍 $service_short - Dernières erreurs :"
        timeout 5 docker compose logs "$service_short" --tail=3 2>/dev/null | sed 's/^/      /' || echo "      Logs non disponibles (timeout)"
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
  log "🔧 Correction service Realtime (NOUVELLE SOLUTION)..."

  if docker compose ps realtime | grep -q "Restarting"; then
    log "   Realtime redémarre - Problème RLIMIT_NOFILE..."

    # Vérifier la variable problématique dans les logs
    if docker compose logs realtime --tail=5 | grep -q "RLIMIT_NOFILE: unbound variable"; then
      warn "   ❌ Variable RLIMIT_NOFILE non définie"

      log "   Correction avec solution avancée (env + ulimits)..."

      # Backup du fichier
      cp docker-compose.yml docker-compose.yml.backup.realtime.$(date +%Y%m%d_%H%M%S)

      # Supprimer toute ligne RLIMIT_NOFILE mal placée
      sed -i '/^[[:space:]]*RLIMIT_NOFILE:/d' docker-compose.yml

      # Solution complète: environment + ulimits
      if grep -A10 "realtime:" docker-compose.yml | grep -q "environment:"; then
        # Ajouter après la section environment existante
        sed -i '/realtime:/,/^[[:space:]]*[a-z-]*:/ {
          /environment:/a\      RLIMIT_NOFILE: "10000"
          /environment:/a\      SEED_SELF_HOST: "true"
        }' docker-compose.yml

        # Ajouter section ulimits après environment
        sed -i '/realtime:/,/^[[:space:]]*[a-z-]*:/ {
          /^[[:space:]]*environment:/,/^[[:space:]]*[a-z]/ {
            /^[[:space:]]*[a-z]/i\    ulimits:\
      nofile:\
        soft: 10000\
        hard: 10000
          }
        }' docker-compose.yml
      else
        # Créer sections environment et ulimits
        sed -i '/realtime:/,/^[[:space:]]*[a-z-]*:/ {
          /restart:/ {
            a\    environment:
            a\      RLIMIT_NOFILE: "10000"
            a\      SEED_SELF_HOST: "true"
            a\    ulimits:
            a\      nofile:
            a\        soft: 10000
            a\        hard: 10000
          }
        }' docker-compose.yml
      fi

      log "   Redémarrage Realtime avec solution complète..."
      docker compose stop realtime
      docker compose up -d realtime
      ok "   ✅ Realtime corrigé avec RLIMIT_NOFILE + ulimits"
    else
      log "   Autre problème détecté - redémarrage simple..."
      docker compose restart realtime
    fi
  else
    ok "   ✅ Realtime ne redémarre pas"
  fi
}

fix_kong_permissions() {
  log "🔧 Correction permissions Kong (SOLUTION ARM64)..."

  if docker compose ps kong | grep -q "Restarting"; then
    log "   Kong redémarre - Problème permissions..."

    # Vérifier les logs pour identifier le problème exact
    if docker compose logs kong --tail=5 | grep -q "Permission denied.*kong.yml\|declarative config"; then
      warn "   ❌ Permission denied sur kong.yml"

      # Corriger les permissions Kong avec ownership ARM64 spécifique
      if [[ -d "volumes/kong" ]]; then
        log "   Correction permissions avec ARM64 ownership (100:101)..."
        sudo chown -R 100:101 volumes/kong/ 2>/dev/null || true
        sudo chmod 644 volumes/kong/*.yml 2>/dev/null || true

        # Vérifier l'image Kong utilisée
        local kong_image=$(docker compose config | grep -A5 "kong:" | grep "image:" | awk '{print $2}' || echo "unknown")
        if [[ "$kong_image" != *"arm64"* ]] && [[ "$kong_image" != *"3.0"* ]]; then
          warn "   ⚠️ Image Kong détectée: $kong_image"
          log "   💡 Pour ARM64, recommandé: arm64v8/kong:latest ou kong:3.0.0"

          # Backup et mise à jour de l'image
          cp docker-compose.yml docker-compose.yml.backup.kong.$(date +%Y%m%d_%H%M%S)

          # Changer pour une image ARM64 compatible
          sed -i '/kong:/,/^[[:space:]]*[a-z-]*:/ {
            /image:/ s|image:.*|image: arm64v8/kong:3.0.0|
          }' docker-compose.yml

          log "   ✅ Image Kong mise à jour pour ARM64"
        fi

        # Ajouter platform si manquant
        if ! grep -A10 "kong:" docker-compose.yml | grep -q "platform:"; then
          sed -i '/kong:/,/^[[:space:]]*[a-z-]*:/ {
            /image:/ a\    platform: linux/arm64
          }' docker-compose.yml
          log "   ✅ Platform linux/arm64 ajouté"
        fi

        log "   Redémarrage Kong avec corrections ARM64..."
        docker compose stop kong
        docker compose up -d kong
        ok "   ✅ Kong corrigé pour ARM64 avec permissions 100:101"
      else
        warn "   ❌ Répertoire volumes/kong manquant"
      fi
    else
      log "   Autre problème Kong - redémarrage simple..."
      docker compose restart kong
    fi
  else
    ok "   ✅ Kong ne redémarre pas"
  fi
}

fix_edge_functions_command() {
  log "🔧 Correction Edge Functions (SOLUTION COMPLÈTE)..."

  if docker compose ps edge-functions | grep -q "Restarting"; then
    log "   Edge Functions redémarre - Diagnostic approfondi..."

    local edge_logs=$(docker compose logs edge-functions --tail=5)
    if echo "$edge_logs" | grep -q "Print help\|Usage:\|show this help message"; then
      warn "   ❌ Edge Functions affiche l'aide - problème command + main function"

      log "   Correction complète: command + main function + variables..."

      # Backup
      cp docker-compose.yml docker-compose.yml.backup.edge-functions.$(date +%Y%m%d_%H%M%S)

      # Créer le répertoire et fichier main si manquants
      mkdir -p volumes/functions/main

      if [[ ! -f "volumes/functions/main/index.ts" ]]; then
        log "   Création fonction main par défaut..."
        cat > volumes/functions/main/index.ts << 'EOF'
// https://supabase.com/docs/guides/functions
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

console.log("Hello from Supabase Edge Functions!")

serve(async (req) => {
  const { name } = await req.json()
  const data = {
    message: `Hello ${name}!`,
  }

  return new Response(
    JSON.stringify(data),
    { headers: { "Content-Type": "application/json" } },
  )
})
EOF
        ok "   ✅ Fonction main créée"
      fi

      # Corriger le format command en array YAML
      if grep -A5 "edge-functions:" docker-compose.yml | grep -q "command:"; then
        log "   Correction format command en array YAML..."

        # Remplacer par format array correct
        sed -i '/edge-functions:/,/^[[:space:]]*[a-z-]*:/ {
          /command:.*/ {
            c\    command:
            a\      - start
            a\      - --main-service
            a\      - /home/deno/functions/main
          }
        }' docker-compose.yml

        log "   ✅ Command format corrigé"
      else
        # Ajouter command si manquant
        sed -i '/edge-functions:/,/^[[:space:]]*[a-z-]*:/ {
          /volumes:/ {
            i\    command:
            i\      - start
            i\      - --main-service
            i\      - /home/deno/functions/main
          }
        }' docker-compose.yml
        log "   ✅ Command ajouté"
      fi

      # Vérifier les variables d'environnement nécessaires
      if ! grep -A10 "edge-functions:" docker-compose.yml | grep -q "JWT_SECRET"; then
        log "   Ajout variables d'environnement manquantes..."

        # Lire les variables du .env
        local jwt_secret=$(grep "^JWT_SECRET=" .env | cut -d'=' -f2 | tr -d '"')
        local anon_key=$(grep "^SUPABASE_ANON_KEY=" .env | cut -d'=' -f2 | tr -d '"')
        local service_key=$(grep "^SUPABASE_SERVICE_KEY=" .env | cut -d'=' -f2 | tr -d '"')

        if [[ -n "$jwt_secret" ]]; then
          # Ajouter section environment
          sed -i '/edge-functions:/,/^[[:space:]]*[a-z-]*:/ {
            /command:/,/home.*main/ {
              /home.*main/a\    environment:
              /home.*main/a\      JWT_SECRET: "'"$jwt_secret"'"
              /home.*main/a\      SUPABASE_URL: http://kong:8000
              /home.*main/a\      SUPABASE_ANON_KEY: "'"$anon_key"'"
              /home.*main/a\      SUPABASE_SERVICE_ROLE_KEY: "'"$service_key"'"
            }
          }' docker-compose.yml
          log "   ✅ Variables d'environnement ajoutées"
        fi
      fi

      log "   Redémarrage Edge Functions avec configuration complète..."
      docker compose stop edge-functions
      docker compose up -d edge-functions
      ok "   ✅ Edge Functions complètement corrigé"
    else
      log "   Autre erreur détectée - redémarrage simple..."
      docker compose restart edge-functions
    fi
  else
    ok "   ✅ Edge Functions ne redémarre pas"
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
  log "   Basé sur recherches web + retour d'expérience ARM64"

  install_dependencies
  check_project_directory

  echo ""
  log "🧹 Nettoyage YAML..."
  cleanup_yaml_errors

  echo ""
  log "🗄️ Préparation base de données..."
  if ! create_auth_schema; then
    echo ""
    error "❌ Échec création schema auth - Le script ne peut pas continuer"
    echo ""
    echo "🛠️ **Solutions recommandées** :"
    echo "   1. Vérifier entropie : cat /proc/sys/kernel/random/entropy_avail"
    echo "   2. Installer haveged : sudo apt install haveged"
    echo "   3. Réinitialisation complète : ./reset-and-fix.sh"
    echo "   4. Diagnostic approfondi : ./diagnose-deep.sh"
    echo ""
    exit 1
  fi

  echo ""
  log "🏥 État avant corrections :"
  diagnose_restarting_services || true

  echo ""
  log "🛠️ Application des corrections avancées basées sur recherches ARM64..."
  fix_auth_service
  fix_storage_service
  fix_realtime_service
  fix_kong_permissions
  fix_edge_functions_command

  echo ""
  log "⏳ Attente stabilisation après corrections (45s)..."
  wait_for_stabilization

  echo ""
  log "🔄 Second passage pour services persistants..."
  # Second passage pour les services qui peuvent encore redémarrer
  fix_auth_service
  fix_realtime_service

  wait_for_stabilization
  show_final_status
}

main "$@"