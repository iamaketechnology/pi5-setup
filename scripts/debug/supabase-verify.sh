#!/usr/bin/env bash
set -euo pipefail

# Supabase Quick Verify for Pi 5
# - Checks container status, Studio/API reachability, DB user detection, DB connectivity
# - Defaults to stack dir: ~/stacks/supabase (override with --dir <path>)

log()   { echo -e "\033[1;36m[VERIFY]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

STACK_DIR="${SUPABASE_DIR:-${HOME}/stacks/supabase}"

while [[ ${1:-} == --* ]]; do
  case "$1" in
    --dir)
      STACK_DIR="$2"; shift 2 ;;
    *)
      error "Option inconnue: $1"; exit 2 ;;
  esac
done

main() {
  echo ""; log "🔎 Vérification Supabase (dir: ${STACK_DIR})"
  if [[ ! -d "$STACK_DIR" ]]; then
    error "Répertoire introuvable: $STACK_DIR"
    exit 1
  fi
  cd "$STACK_DIR"

  if [[ ! -f docker-compose.yml ]]; then
    error "docker-compose.yml manquant dans $(pwd)"
    exit 1
  fi

  # Charger .env s'il existe pour récupérer des ports personnalisés
  if [[ -f .env ]]; then
    set -a
    source .env
    set +a
  fi

  LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
  [[ -z "${LOCAL_IP:-}" ]] && LOCAL_IP="127.0.0.1"

  echo ""; echo "==================== ÉTAT CONTENEURS ====================="
  if command -v docker >/dev/null 2>&1; then
    sudo docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}" || true
  else
    error "Docker non installé ou indisponible"
  fi

  # Déterminer ports (par défaut si non définis)
  local STUDIO_PORT="${STUDIO_PORT:-3000}"
  local API_PORT="${API_PORT:-8001}"

  echo ""; echo "==================== TESTS CONNECTIVITÉ ==================="
  check_http "Studio"             "http://localhost:${STUDIO_PORT}/"             acceptable "200 301 302 307"    
  check_http "API REST"           "http://localhost:${API_PORT}/rest/v1/"    reachable  "200 401 404"    
  check_http "Auth"               "http://localhost:${API_PORT}/auth/v1/"    reachable  "200 401 404"    
  check_http "Realtime"           "http://localhost:${API_PORT}/realtime/v1/" reachable  "200 426"       
  check_http "Storage"            "http://localhost:${API_PORT}/storage/v1/" reachable  "200 401 404"    
  check_http "Edge Functions"     "http://localhost:54321/"            reachable  "200 404"       

  echo ""; echo "==================== BASE DE DONNÉES ======================"
  detect_db_user
  test_db_connect

  echo ""; echo "==================== RÉSUMÉ ACCÈS ========================"
  echo "🎨 Studio      : http://${LOCAL_IP}:${STUDIO_PORT}"
  echo "🔌 API Gateway : http://${LOCAL_IP}:${API_PORT}/rest/v1/"
  echo "⚡ Edge Funcs  : http://${LOCAL_IP}:54321/functions/v1/"
  echo ""
  ok "Terminé. Si un service est KO, consulte: 'docker compose logs <service>'"
}

check_http() {
  local name="$1" url="$2" mode="$3" ok_codes="$4"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" 2>/dev/null || echo "000")

  case "$mode" in
    acceptable)
      if echo " $ok_codes " | grep -q " $code "; then
        ok "${name} OK (HTTP ${code})"
      else
        error "${name} KO (HTTP ${code}) → $url"
      fi ;;
    reachable)
      if [[ "$code" != "000" ]]; then
        ok "${name} joignable (HTTP ${code})"
      else
        error "${name} injoignable (HTTP ${code}) → $url"
      fi ;;
    *) warn "Mode inconnu pour $name" ;;
  esac
}

detect_db_user() {
  DB_USER=""
  # 1) Essayer via variables d'env du conteneur
  if sudo docker compose exec -T db env >/dev/null 2>&1; then
    DB_USER=$(sudo docker compose exec -T db env | awk -F= '/^POSTGRES_USER=/{print $2}' | tr -d '\r' || true)
  fi

  # 2) Sinon, tester quelques utilisateurs connus
  if [[ -z "${DB_USER}" ]]; then
    local candidates=("supabase_admin" "postgres" "supabase" "root")
    for u in "${candidates[@]}"; do
      if sudo docker compose exec -T db pg_isready -U "$u" >/dev/null 2>&1; then
        DB_USER="$u"; break
      fi
      if sudo docker compose exec -T db psql -U "$u" -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
        DB_USER="$u"; break
      fi
    done
  fi

  if [[ -n "${DB_USER}" ]]; then
    ok "Utilisateur DB détecté: ${DB_USER}"
  else
    warn "Impossible de détecter l'utilisateur DB. Essaye: supabase_admin"
    DB_USER="supabase_admin"
  fi
}

test_db_connect() {
  if sudo docker compose exec -T db pg_isready -U "$DB_USER" >/dev/null 2>&1; then
    ok "PostgreSQL prêt (pg_isready)"
  else
    error "PostgreSQL non prêt pour l'utilisateur '$DB_USER'"
  fi

  if sudo docker compose exec -T db psql -U "$DB_USER" -d postgres -c "SELECT current_user, version();" >/dev/null 2>&1; then
    ok "Requête SQL OK en tant que '$DB_USER'"
  else
    error "Échec requête SQL avec '$DB_USER'"
  fi

  echo ""
  log "Rôles (extrait):"
  sudo docker compose exec -T db psql -U "$DB_USER" -d postgres -c "\\du" 2>/dev/null | head -20 || warn "Impossible d'afficher les rôles"
}

main "$@"
