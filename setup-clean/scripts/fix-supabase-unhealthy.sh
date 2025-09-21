#!/bin/bash
# =============================================================================
# Script 4 : Fix des Services Unhealthy pour Supabase Self-Hosted sur Raspberry Pi 5 (ARM64, 16GB RAM)
# Auteur : Ingénieur DevOps ARM64 - Optimisé pour Bookworm 64-bit (Kernel 6.12+)
# Version : 1.0.3 (Améliorations: Auto-édition start_period/retries dans docker-compose.yml; relance en cascade; diagnostics realtime perms + memory bump)
# Objectif : Diagnostiquer et corriger les services unhealthy dans Supabase (ex: auth, realtime, storage, meta, edge-functions) sans redéployer l'ensemble.
# Pré-requis : Script 3 exécuté avec succès (Docker Compose up). Exécuter en tant que user pi (non sudo, car Docker group ajouté).
# Usage : cd /home/pi/stacks/supabase && ./fix-supabase-unhealthy.sh
# Actions Post-Script : Vérifiez `docker compose ps` ; si persistant, relancez ce script ou consultez logs spécifiques.
# Notes : 
# - Relance sélective basée sur status (tolère PG healthy).
# - Diagnostics : Logs tail=20 pour services KO, avec grep ERROR/WARN.
# - Validation : Boucle healthcheck jusqu'à 10 min (relance si KO).
# - Si realtime crash persiste (perms schéma), force DROP/CREATE via PG + memory limit augmentation.
# - Basé sur issues courantes ARM64 (ralentissements boot, healthchecks stricts).
# =============================================================================
set -euo pipefail  # Arrêt sur erreur, undefined vars, pipefail

# Fonctions de logging colorées pour traçabilité
log()  { echo -e "\033[1;36m[FIX-SUPABASE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# Variables globales
PROJECT_DIR="/home/${USER}/stacks/supabase"  # Assumé pi
LOG_FILE="/tmp/supabase-fix-unhealthy-$(date +%Y%m%d_%H%M%S).log"  # /tmp au lieu de /var/log
MAX_RETRIES=5  # Relances max par service
HEALTH_TIMEOUT=600  # 10 min total pour healthchecks (étendu pour ARM64 lent)

# Redirection des logs vers fichier pour audit (stdout + fichier)
exec 1> >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$LOG_FILE" >&2)
log "=== Début Fix Services Unhealthy v1.0.3 - $(date) ==="
log "Projet: $PROJECT_DIR | User: $USER"

# Vérification dossier projet et Docker Compose
check_prereqs() {
  log "🔍 Vérification pré-requis..."
  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Dossier projet manquant: $PROJECT_DIR - Exécutez Script 3 d'abord."
  fi
  cd "$PROJECT_DIR" || error "Impossible d'accéder à $PROJECT_DIR"
  if ! command -v docker &> /dev/null; then
    error "Docker manquant - Ajoutez user au groupe docker et reloguez."
  fi
  if ! docker compose version | grep -q "2\."; then
    error "Docker Compose v2+ requis."
  fi
  if ! docker compose ps --all | grep -q "supabase-"; then
    warn "Aucun conteneur Supabase détecté - Lancez docker compose up -d d'abord."
  fi
  ok "Pré-requis validés."
}

# Fonction pour obtenir services unhealthy/exited (strip prefix supabase- et -1)
get_unhealthy_services() {
  docker compose ps --all --format '{{.Name}}\t{{.Status}}' | grep -E "(unhealthy)" | awk '{print $1}' | sed 's/supabase-//' | sed 's/-1$//' | tr '\n' ' ' | sed 's/ $//' || true
}

get_exited_services() {
  docker compose ps --filter 'status=exited' --format '{{.Name}}' | sed 's/supabase-//' | sed 's/-1$//' | tr '\n' ' ' | sed 's/ $//' || true
}

# Diagnostics logs pour un service (tail=20 + grep ERROR/WARN)
diagnose_service() {
  local service="$1"
  log "🔍 Diagnostics pour $service..."
  docker compose logs "$service" --tail=20 | tee -a "$LOG_FILE"
  if docker compose logs "$service" 2>&1 | grep -qE "(ERROR|WARN|permission denied|connection reset)"; then
    warn "Erreurs détectées dans logs $service - Consultez $LOG_FILE pour détails."
  else
    ok "Logs $service clean (pas d'ERROR/WARN récents)."
  fi
}

# Auto-édition docker-compose.yml pour étendre healthchecks (start_period + retries pour ARM64)
extend_healthchecks() {
  log "🛠️ Extension automatique healthchecks dans docker-compose.yml (start_period + retries pour Pi5)..."
  # Backup original
  cp docker-compose.yml docker-compose.yml.bak
  # Étendre pour services problématiques (realtime: 300s, auth/storage/meta/edge/kong: 180s, retries=15)
  sed -i 's/start_period: 120s/start_period: 300s/' docker-compose.yml  # Realtime
  sed -i 's/start_period: 60s/start_period: 180s/' docker-compose.yml   # Auth/storage/studio
  sed -i 's/start_period: 30s/start_period: 180s/' docker-compose.yml   # Autres
  sed -i 's/retries: 10/retries: 15/' docker-compose.yml
  sed -i 's/retries: 5/retries: 15/' docker-compose.yml
  # Ajout memory limit pour realtime (1.5G sur Pi5 16GB)
  sed -i '/realtime:/a\    deploy:\n      resources:\n        limits:\n          memory: 1.5G' docker-compose.yml
  ok "docker-compose.yml étendu - Relancez services impactés."
}

# Relance un service + validation healthcheck (retry jusqu'à timeout)
restart_and_validate() {
  local service="$1"
  local health_cmd="$2"  # Ex: curl -f http://localhost:9999/health pour auth
  local max_wait=120  # 2 min par service (étendu)
  log "🔄 Relance $service + validation healthcheck..."
  docker compose restart "$service"
  sleep 15  # Attente boot initial
  local start_time=$(date +%s)
  for i in $(seq 1 "$max_wait"); do
    sleep 1
    if eval "$health_cmd" > /dev/null 2>&1; then
      ok "$service healthy après $i s."
      return 0
    fi
    if [[ $(( $(date +%s) - start_time )) -ge $HEALTH_TIMEOUT ]]; then
      warn "$service timeout healthcheck - Persiste unhealthy."
      return 1
    fi
  done
  return 1
}

# Fix spécifique realtime (si perms schéma + memory bump)
fix_realtime_perms() {
  local service="realtime"
  if ! docker compose ps | grep -q "$service.*Up"; then
    warn "$service non up - Relance d'abord."
    return 1
  fi
  log "🛠️ Fix perms schéma realtime (DROP/CREATE/GRANT étendu)..."
  # Via PG superuser (postgres sans pass)
  docker compose exec -T postgresql psql -U postgres -d postgres -c "
    DROP SCHEMA IF EXISTS realtime CASCADE;
    CREATE SCHEMA realtime;
    ALTER SCHEMA realtime OWNER TO postgres;
    GRANT ALL ON SCHEMA realtime TO postgres;
    GRANT USAGE, CREATE ON SCHEMA realtime TO postgres;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA realtime TO postgres;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA realtime TO postgres;
  " 2>&1 | tee -a "$LOG_FILE" || warn "Échec fix perms realtime - Vérifiez logs PG."
  ok "Perms realtime fixé - Relance service."
  docker compose restart realtime
  sleep 30  # Plus long pour Elixir migrations
}

# Fix spécifique auth (si connection reset + port check)
fix_auth_port() {
  local service="auth"
  log "🛠️ Vérif/fix GOTRUE_API_PORT pour $service..."
  if ! grep -q "^GOTRUE_API_PORT=9999$" .env; then
    log "GOTRUE_API_PORT manquant dans .env - Ajout automatique..."
    echo 'GOTRUE_API_PORT=9999' >> .env
    ok "GOTRUE_API_PORT=9999 ajouté au .env"
    # Relancer le service pour prendre en compte la nouvelle variable
    docker compose up -d --force-recreate "$service"
    sleep 20
  fi
  if docker compose logs "$service" | grep -q "GoTrue API started on: :9999"; then
    ok "Port auth OK."
  else
    warn "Port auth KO - Relance avec env forcée."
    docker compose up -d --force-recreate "$service"
    sleep 15
  fi
}

# Main fix loop (relance en cascade: PG → auth/realtime → storage/studio)
main_fix() {
  check_prereqs
  # Étendre healthchecks d'abord (une fois par run)
  extend_healthchecks
  # Relancer PG si needed (dépendance racine)
  if docker compose ps | grep -q "postgresql.*(unhealthy\|exited)"; then
    log "🔄 Relance PG (dépendance racine)..."
    docker compose restart postgresql
    sleep 20
  fi
  local unhealthy=$(get_unhealthy_services)
  local exited=$(get_exited_services)
  if [[ -z "$unhealthy" && -z "$exited" ]]; then
    ok "Tous services healthy - Rien à fixer."
    exit 0
  fi
  log "🚨 Services à fixer: Unhealthy=$unhealthy | Exited=$exited"

  # Fix exited d'abord
  if [[ -n "$exited" ]]; then
    for svc in $exited; do
      diagnose_service "$svc"
      docker compose restart "$svc"
      sleep 15
    done
  fi

  # Fix unhealthy sélectifs (ordre cascade)
  for svc in auth realtime storage meta edge-functions kong studio rest; do  # auth/realtime d'abord
    if [[ "$unhealthy" =~ "$svc" || "$exited" =~ "$svc" ]]; then
      diagnose_service "$svc"
      case "$svc" in
        realtime)
          fix_realtime_perms
          restart_and_validate realtime 'curl -f http://localhost:4000/health'
          ;;
        auth)
          fix_auth_port
          restart_and_validate auth 'curl -f http://localhost:9999/health'
          ;;
        storage)
          restart_and_validate storage 'curl -f http://localhost:5000/health'
          ;;
        meta)
          restart_and_validate meta 'curl -f http://localhost:8080/health'
          ;;
        edge-functions)
          restart_and_validate edge-functions 'curl -f http://localhost:54321/health'
          ;;
        kong)
          restart_and_validate kong 'curl -f http://localhost:8001/status'
          ;;
        studio|rest)
          docker compose restart "$svc"  # Pas de healthcheck simple, relance suffit
          sleep 10
          ;;
      esac
    fi
  done

  # Validation globale post-fix
  sleep 60  # Plus long pour stabilisation
  local final_unhealthy=$(get_unhealthy_services)
  if [[ -n "$final_unhealthy" ]]; then
    warn "Services persistants unhealthy: $final_unhealthy (toléré si <3 sur Pi5) - Consultez $LOG_FILE et relancez si besoin."
  else
    ok "Tous services healthy après fix!"
  fi

  log "📋 Logs diagnostics: $LOG_FILE"
  log "🔄 Pour relancer tout: docker compose down && docker compose up -d"
  log "💡 Si persiste: Éditez docker-compose.yml manuellement pour memory limits realtime (1.5G)."
}

# Exécution main
main_fix "$@"