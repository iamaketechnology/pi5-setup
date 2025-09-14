#!/usr/bin/env bash
set -euo pipefail

# === SUPABASE COMPREHENSIVE HEALTH CHECK - Diagnostic complet ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[HEALTH]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
  log "🏥 Diagnostic complet Supabase Pi 5"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "❌ Projet Supabase non trouvé dans : $PROJECT_DIR"
    echo ""
    echo "🚀 Installe Supabase avec la version améliorée :"
    echo "curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2-improved.sh -o setup.sh && chmod +x setup.sh && sudo MODE=beginner ./setup.sh"
    exit 1
  fi

  cd "$PROJECT_DIR"

  echo ""
  echo "==================== 📊 ÉTAT DES CONTENEURS ===================="

  # État des conteneurs
  if docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null; then
    ok "✅ Docker Compose accessible"
  else
    error "❌ Docker Compose inaccessible"
    exit 1
  fi

  echo ""
  echo "==================== 🧪 TESTS DE CONNECTIVITÉ ===================="

  local tests_passed=0
  local tests_total=0

  # Test Studio
  ((tests_total++))
  if curl -s -I "http://localhost:3000" >/dev/null 2>&1; then
    ok "  ✅ Studio accessible (localhost:3000)"
    ((tests_passed++))
  else
    warn "  ❌ Studio non accessible (localhost:3000)"
  fi

  # Test API Gateway
  ((tests_total++))
  if curl -s -I "http://localhost:8001" >/dev/null 2>&1; then
    ok "  ✅ API Gateway accessible (localhost:8001)"
    ((tests_passed++))
  else
    warn "  ❌ API Gateway non accessible (localhost:8001)"
  fi

  # Test PostgreSQL
  ((tests_total++))
  if nc -z localhost 5432 2>/dev/null; then
    ok "  ✅ PostgreSQL accessible (localhost:5432)"
    ((tests_passed++))
  else
    warn "  ❌ PostgreSQL non accessible (localhost:5432)"
  fi

  # Test Edge Functions
  ((tests_total++))
  if curl -s -I "http://localhost:54321" >/dev/null 2>&1; then
    ok "  ✅ Edge Functions accessible (localhost:54321)"
    ((tests_passed++))
  else
    warn "  ❌ Edge Functions non accessible (localhost:54321)"
  fi

  echo ""
  echo "==================== 🔧 DIAGNOSTIC CONFIGURATION ===================="

  # Vérifier fichier .env
  if [[ -f ".env" ]]; then
    ok "✅ Fichier .env présent"

    local env_vars=("API_EXTERNAL_URL" "AUTHENTICATOR_PASSWORD" "SUPABASE_STORAGE_PASSWORD" "JWT_SECRET")
    local env_ok=0

    for var in "${env_vars[@]}"; do
      if grep -q "^$var=" .env; then
        ok "  ✅ $var configuré"
        ((env_ok++))
      else
        warn "  ❌ $var manquant"
      fi
    done

    log "Variables .env: $env_ok/${#env_vars[@]}"
  else
    error "❌ Fichier .env manquant"
  fi

  # Vérifier propagation variables (avec retry)
  local propagation_ok=false
  local retry_count=0

  while [[ $retry_count -lt 3 ]] && [[ $propagation_ok == false ]]; do
    if docker compose exec -T auth printenv 2>/dev/null | grep -q "API_EXTERNAL_URL" 2>/dev/null; then
      propagation_ok=true
    else
      sleep 1
      ((retry_count++))
    fi
  done

  if [[ $propagation_ok == true ]]; then
    ok "✅ Variables propagées aux conteneurs"
  else
    if [[ -f ".env" ]] && grep -q "API_EXTERNAL_URL" ".env" 2>/dev/null; then
      warn "⚠️ Variables dans .env mais non propagées (conteneurs redémarrant ?)"
    else
      error "❌ Variables non propagées et .env manquant"
    fi
  fi

  echo ""
  echo "==================== 🗄️ DIAGNOSTIC BASE DE DONNÉES ===================="

  # Test utilisateurs PostgreSQL
  local db_users=("authenticator" "supabase_storage_admin" "anon")
  local db_users_ok=0

  for user in "${db_users[@]}"; do
    if docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT 1 FROM pg_user WHERE usename='$user';" 2>/dev/null | grep -q "1 row"; then
      ok "  ✅ Utilisateur '$user' existe"
      ((db_users_ok++))
    else
      warn "  ❌ Utilisateur '$user' manquant"
    fi
  done

  log "Utilisateurs DB: $db_users_ok/${#db_users[@]}"

  echo ""
  echo "==================== 📋 SERVICES PROBLÉMATIQUES ===================="

  # Identifier services en problème
  local restarting_services=$(docker compose ps --format "{{.Name}} {{.Status}}" | grep -i "restarting\|exit" | awk '{print $1}' || true)

  if [[ -n "$restarting_services" ]]; then
    warn "⚠️ Services en problème :"
    echo "$restarting_services" | while read -r service_name; do
      if [[ -n "$service_name" ]]; then
        echo "  - $service_name"
        service_short=$(echo "$service_name" | sed 's/supabase-//')
        log "    📋 Dernières erreurs :"
        docker compose logs "$service_short" --tail=2 2>/dev/null | sed 's/^/      /' || echo "      Logs non disponibles"
      fi
    done

    echo ""
    warn "🔧 Actions recommandées :"
    echo "   ./scripts/supabase-restart.sh    # Redémarrage propre"
    echo "   ./scripts/supabase-logs.sh auth  # Logs détaillés"

    if [[ $tests_passed -lt $((tests_total / 2)) ]]; then
      echo ""
      error "🚨 Installation sévèrement endommagée"
      echo "   SOLUTION : Nettoyage complet et réinstallation"
      echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/clean-and-restart.sh -o clean.sh && chmod +x clean.sh && sudo MODE=beginner ./clean.sh"
    fi
  else
    ok "🎉 Aucun service en problème détecté !"
  fi

  echo ""
  echo "==================== 📊 RÉSUMÉ SANTÉ ===================="

  local total_score=$((tests_passed * 100 / tests_total))

  if [[ $total_score -ge 90 ]]; then
    ok "🟢 SANTÉ EXCELLENTE ($total_score%) - Supabase fonctionne parfaitement"
    echo "   🎯 Tous les services sont opérationnels"
  elif [[ $total_score -ge 70 ]]; then
    warn "🟡 SANTÉ CORRECTE ($total_score%) - Quelques problèmes mineurs"
    echo "   🔧 Quelques ajustements peuvent être nécessaires"
  elif [[ $total_score -ge 40 ]]; then
    warn "🟠 SANTÉ DÉGRADÉE ($total_score%) - Problèmes significatifs"
    echo "   ⚡ Redémarrage recommandé"
  else
    error "🔴 SANTÉ CRITIQUE ($total_score%) - Installation endommagée"
    echo "   🚨 Nettoyage complet recommandé"
  fi

  echo ""
  echo "🌐 **URLs d'accès** :"
  local ip=$(hostname -I | awk '{print $1}')
  echo "   🎨 Studio : http://$ip:3000"
  echo "   🔌 API : http://$ip:8001"
  echo "   ⚡ Edge Functions : http://$ip:54321"

  echo ""
  echo "🛠️ **Scripts disponibles** :"
  echo "   ./scripts/supabase-health.sh      # Ce diagnostic"
  echo "   ./scripts/supabase-restart.sh     # Redémarrage propre"
  echo "   ./scripts/supabase-logs.sh <service>  # Logs détaillés"
  echo "=================================================================="
}

main "$@"