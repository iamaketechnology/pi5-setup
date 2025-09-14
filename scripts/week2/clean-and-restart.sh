#!/usr/bin/env bash
set -euo pipefail

# === CLEAN AND RESTART - Nettoyage complet pour redémarrage propre ===

MODE="${MODE:-beginner}"
TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[CLEAN]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=$MODE ./clean-and-restart.sh"
    exit 1
  fi
}

confirm_cleanup() {
  echo "==================== ⚠️  NETTOYAGE COMPLET SUPABASE ===================="
  echo ""
  echo "🗑️  **Cette action va :**"
  echo "   ❌ Arrêter tous les conteneurs Supabase"
  echo "   ❌ Supprimer tous les volumes (DONNÉES PERDUES)"
  echo "   ❌ Supprimer toute la configuration"
  echo "   ❌ Nettoyer les images Docker"
  echo "   ❌ Supprimer le répertoire : $PROJECT_DIR"
  echo ""
  echo "✅ **Puis installer automatiquement :**"
  echo "   🚀 Version améliorée avec tous les fixes"
  echo "   🔧 Configuration optimisée Pi 5"
  echo "   🛡️  Tous les problèmes précédents évités"
  echo ""

  read -p "Veux-tu continuer ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Nettoyage annulé"
    exit 0
  fi

  echo ""
  read -p "Confirmes-tu la suppression DÉFINITIVE des données ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Nettoyage annulé"
    exit 0
  fi
}

stop_and_remove_containers() {
  log "🛑 Arrêt et suppression conteneurs Supabase..."

  if [[ -d "$PROJECT_DIR" ]]; then
    cd "$PROJECT_DIR"

    # Arrêter et supprimer avec l'utilisateur correct
    if su "$TARGET_USER" -c "docker compose down --volumes --remove-orphans" 2>/dev/null; then
      ok "✅ Conteneurs supprimés"
    else
      warn "⚠️ Erreur lors de l'arrêt (ignoré)"
    fi
  else
    warn "⚠️ Répertoire $PROJECT_DIR non trouvé"
  fi
}

cleanup_docker_resources() {
  log "🧹 Nettoyage ressources Docker Supabase..."

  # Supprimer images Supabase
  local images_to_remove=(
    "supabase/gotrue"
    "supabase/studio"
    "supabase/storage-api"
    "supabase/postgres-meta"
    "supabase/realtime"
    "supabase/edge-runtime"
    "postgrest/postgrest"
    "darthsim/imgproxy"
    "kong:2.8.1"
    "kong:3.0.0"
    "postgres:15-alpine"
  )

  for image in "${images_to_remove[@]}"; do
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "^$image"; then
      log "   Suppression image: $image"
      docker rmi -f $(docker images "$image" -q) 2>/dev/null || warn "Image $image non supprimée"
    fi
  done

  # Nettoyage général
  docker system prune -f >/dev/null 2>&1 || true
  docker volume prune -f >/dev/null 2>&1 || true

  ok "✅ Ressources Docker nettoyées"
}

remove_project_directory() {
  log "🗂️ Suppression répertoire projet..."

  if [[ -d "$PROJECT_DIR" ]]; then
    # Sauvegarder .env si existant
    if [[ -f "$PROJECT_DIR/.env" ]]; then
      cp "$PROJECT_DIR/.env" "/tmp/supabase-env-backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
      log "   Sauvegarde .env dans /tmp/"
    fi

    rm -rf "$PROJECT_DIR"
    ok "✅ Répertoire supprimé: $PROJECT_DIR"
  else
    ok "✅ Répertoire déjà absent"
  fi
}

install_improved_version() {
  log "🚀 Installation version améliorée..."

  # Télécharger et exécuter script amélioré
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2-improved.sh -o /tmp/setup-week2-improved.sh
  chmod +x /tmp/setup-week2-improved.sh

  log "🎯 Lancement installation optimisée..."
  MODE="$MODE" /tmp/setup-week2-improved.sh
}

main() {
  require_root

  log "🔄 Nettoyage complet et redémarrage Supabase Pi 5"

  confirm_cleanup
  stop_and_remove_containers
  cleanup_docker_resources
  remove_project_directory

  echo ""
  echo "==================== 🚀 INSTALLATION AMÉLIORÉE ===================="
  echo ""

  install_improved_version
}

main "$@"