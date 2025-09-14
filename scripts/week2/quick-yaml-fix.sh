#!/usr/bin/env bash
set -euo pipefail

# === QUICK YAML FIX - Correction rapide erreur RLIMIT_NOFILE ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[YAML-QUICK]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

fix_misplaced_rlimit() {
  log "🔧 Correction RLIMIT_NOFILE mal placé..."

  if [[ ! -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    error "❌ docker-compose.yml non trouvé"
    exit 1
  fi

  cd "$PROJECT_DIR"

  # Backup
  cp docker-compose.yml "docker-compose.yml.backup.rlimit.$(date +%Y%m%d_%H%M%S)"

  log "📋 Problème détecté: RLIMIT_NOFILE dans section volumes au lieu de environment"

  # Supprimer la ligne RLIMIT_NOFILE mal placée
  sed -i '/^[[:space:]]*RLIMIT_NOFILE:/d' docker-compose.yml

  log "✅ Ligne RLIMIT_NOFILE supprimée de l'endroit incorrect"

  # Ajouter RLIMIT_NOFILE au bon endroit dans realtime service
  if grep -A10 "realtime:" docker-compose.yml | grep -q "environment:"; then
    log "📝 Ajout RLIMIT_NOFILE dans environment de realtime..."

    # Trouver la section environment de realtime et ajouter RLIMIT_NOFILE
    awk '
      /^[[:space:]]*realtime:/ { in_realtime=1; print; next }
      in_realtime && /^[[:space:]]*environment:/ {
        in_env=1
        print
        getline
        print
        print "      RLIMIT_NOFILE: 65536"
        next
      }
      /^[[:space:]]*[a-z-]+:/ && !/^[[:space:]]*realtime:/ {
        in_realtime=0
        in_env=0
      }
      { print }
    ' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml

    ok "✅ RLIMIT_NOFILE ajouté dans environment de realtime"
  else
    log "📝 Création section environment pour realtime..."

    # Ajouter environment si pas présent
    awk '
      /^[[:space:]]*realtime:/ {
        in_realtime=1
        print
        next
      }
      in_realtime && /^[[:space:]]*restart:/ {
        print
        print "    environment:"
        print "      RLIMIT_NOFILE: 65536"
        in_realtime=0
        next
      }
      /^[[:space:]]*[a-z-]+:/ && !/^[[:space:]]*realtime:/ {
        in_realtime=0
      }
      { print }
    ' docker-compose.yml > docker-compose.yml.tmp && mv docker-compose.yml.tmp docker-compose.yml

    ok "✅ Section environment créée avec RLIMIT_NOFILE"
  fi
}

validate_yaml() {
  log "🧪 Validation docker-compose.yml..."

  # Test avec docker compose
  if docker compose config >/dev/null 2>&1; then
    ok "✅ docker-compose.yml maintenant valide !"
    return 0
  else
    error "❌ YAML encore invalide"
    log "📋 Erreurs restantes :"
    docker compose config 2>&1 | head -5
    return 1
  fi
}

main() {
  log "🚀 Correction rapide erreur YAML RLIMIT_NOFILE"

  fix_misplaced_rlimit

  if validate_yaml; then
    echo ""
    ok "🎉 Correction réussie !"
    echo ""
    echo "🚀 Tu peux maintenant relancer :"
    echo "   sudo ./fix.sh"
  else
    echo ""
    error "❌ Correction partielle - inspection manuelle requise"
    echo ""
    echo "🔍 Vérifie manuellement avec :"
    echo "   docker compose config"
  fi
}

main "$@"