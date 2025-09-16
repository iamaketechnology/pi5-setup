#!/usr/bin/env bash
set -euo pipefail

# === CLEANUP WEEK2 SUPABASE - Nettoyage complet avant nouvelle installation ===

log()  { echo -e "\033[1;36m[CLEANUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

# Variables
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0 [--force]"
    echo "  --force : Nettoyage sans confirmation (pour automatisation)"
    exit 1
  fi
}

# Parse arguments
FORCE_MODE=false
for arg in "$@"; do
  case $arg in
    --force)
      FORCE_MODE=true
      shift
      ;;
    *)
      ;;
  esac
done

show_cleanup_banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                    🧹 SUPABASE WEEK2 CLEANUP                    ║"
  echo "║                                                                  ║"
  echo "║  Nettoyage complet avant installation avec nouveaux correctifs  ║"
  if [[ "$FORCE_MODE" == "true" ]]; then
    echo "║                     🤖 MODE AUTOMATIQUE                         ║"
  else
    echo "║               💡 Utilisez --force pour mode auto               ║"
  fi
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
}

check_existing_installation() {
  log "🔍 Vérification installation existante..."

  if [[ -d "$PROJECT_DIR" ]]; then
    ok "✅ Installation Supabase détectée: $PROJECT_DIR"

    # Afficher résumé de ce qui sera nettoyé
    show_cleanup_summary

    # Vérifier services actifs
    if cd "$PROJECT_DIR" 2>/dev/null && su "$TARGET_USER" -c "docker compose ps --services" 2>/dev/null | grep -q "db\|kong\|auth"; then
      warn "⚠️ Services Supabase actifs détectés"
      return 0
    else
      log "ℹ️ Aucun service actif détecté"
      return 1
    fi
  else
    log "ℹ️ Aucune installation Supabase trouvée"
    return 1
  fi
}

show_cleanup_summary() {
  echo ""
  log "📋 Résumé de ce qui sera nettoyé:"

  # Conteneurs Docker
  local containers=$(docker ps -a --filter "name=supabase" --format "{{.Names}}" 2>/dev/null | wc -l)
  if [[ $containers -gt 0 ]]; then
    log "   🐳 $containers conteneur(s) Supabase"
  fi

  # Images Docker
  local images=$(docker images --filter "reference=supabase/*" --filter "reference=*kong*" --filter "reference=postgrest/*" --format "{{.Repository}}" 2>/dev/null | wc -l)
  if [[ $images -gt 0 ]]; then
    log "   📦 $images image(s) Docker liées"
  fi

  # Répertoire projet
  if [[ -d "$PROJECT_DIR" ]]; then
    local size=$(du -sh "$PROJECT_DIR" 2>/dev/null | cut -f1)
    log "   📁 Répertoire projet: $size"

    if [[ -d "$PROJECT_DIR/volumes/db" ]]; then
      local db_size=$(du -sh "$PROJECT_DIR/volumes/db" 2>/dev/null | cut -f1)
      log "   🗄️ Données PostgreSQL: $db_size"
    fi

    if [[ -d "$PROJECT_DIR/volumes/storage" ]]; then
      local storage_size=$(du -sh "$PROJECT_DIR/volumes/storage" 2>/dev/null | cut -f1)
      log "   💾 Données Storage: $storage_size"
    fi
  fi

  echo ""
}

stop_supabase_services() {
  log "🛑 Arrêt des services Supabase..."

  if [[ -d "$PROJECT_DIR" ]] && [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    cd "$PROJECT_DIR"

    # Arrêter avec timeout
    if timeout 60 su "$TARGET_USER" -c "docker compose down" 2>/dev/null; then
      ok "✅ Services arrêtés normalement"
    else
      warn "⚠️ Timeout - Force l'arrêt..."
      su "$TARGET_USER" -c "docker compose kill" 2>/dev/null || true
      su "$TARGET_USER" -c "docker compose rm -f" 2>/dev/null || true
    fi

    # Vérifier arrêt complet
    local remaining=$(su "$TARGET_USER" -c "docker compose ps -q" 2>/dev/null | wc -l)
    if [[ $remaining -eq 0 ]]; then
      ok "✅ Tous les conteneurs arrêtés"
    else
      warn "⚠️ $remaining conteneur(s) encore actif(s)"
    fi
  else
    log "ℹ️ Aucun docker-compose.yml trouvé"
  fi
}

cleanup_docker_resources() {
  log "🐳 Nettoyage ressources Docker..."

  # Supprimer conteneurs Supabase orphelins
  log "   Suppression conteneurs Supabase..."
  docker ps -a --filter "name=supabase" --format "{{.Names}}" | while read -r container; do
    if [[ -n "$container" ]]; then
      docker rm -f "$container" 2>/dev/null && log "     ✅ Supprimé: $container" || true
    fi
  done

  # Supprimer images Supabase locales (pour forcer téléchargement nouvelles versions)
  log "   Suppression images Supabase obsolètes..."
  docker images --filter "reference=supabase/*" --filter "reference=*kong*" --filter "reference=postgrest/*" --format "{{.Repository}}:{{.Tag}}" | while read -r image; do
    if [[ -n "$image" && "$image" != "<none>:<none>" ]]; then
      docker rmi "$image" 2>/dev/null && log "     ✅ Image supprimée: $image" || true
    fi
  done

  # Nettoyer volumes et réseaux
  log "   Nettoyage volumes et réseaux..."
  docker volume prune -f >/dev/null 2>&1
  docker network prune -f >/dev/null 2>&1

  # Supprimer réseau Supabase spécifique
  docker network rm supabase_network 2>/dev/null || true
  docker network rm supabase_default 2>/dev/null || true

  # Nettoyage système général
  log "   Nettoyage système Docker..."
  docker system prune -f >/dev/null 2>&1

  ok "✅ Ressources Docker nettoyées"
}

cleanup_project_directory() {
  log "📁 Nettoyage répertoire projet..."

  if [[ -d "$PROJECT_DIR" ]]; then
    # Sauvegarder les fichiers .env s'ils existent
    if [[ -f "$PROJECT_DIR/.env" ]]; then
      log "   Sauvegarde .env existant..."
      cp "$PROJECT_DIR/.env" "/tmp/supabase-env-backup-$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi

    # Supprimer volumes de données (critique pour éviter conflits)
    if [[ -d "$PROJECT_DIR/volumes/db" ]]; then
      log "   Suppression données PostgreSQL..."
      rm -rf "$PROJECT_DIR/volumes/db/data" 2>/dev/null || true
      ok "     ✅ Données PostgreSQL supprimées"
    fi

    if [[ -d "$PROJECT_DIR/volumes/storage" ]]; then
      log "   Suppression données Storage..."
      rm -rf "$PROJECT_DIR/volumes/storage"/* 2>/dev/null || true
      ok "     ✅ Données Storage supprimées"
    fi

    # Option: Suppression complète (demander confirmation sauf en mode force)
    if [[ "$FORCE_MODE" == "true" ]]; then
      log "   Mode force: Suppression complète du projet..."
      rm -rf "$PROJECT_DIR"
      ok "✅ Projet supprimé complètement: $PROJECT_DIR"
    else
      echo ""
      read -p "🗑️ Supprimer complètement le répertoire projet? [y/N]: " -n 1 -r
      echo ""

      if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "   Suppression complète du projet..."
        rm -rf "$PROJECT_DIR"
        ok "✅ Projet supprimé: $PROJECT_DIR"
      else
        log "   Conservation du répertoire projet"
        # Nettoyer seulement les fichiers de configuration
        rm -f "$PROJECT_DIR/docker-compose.yml" 2>/dev/null || true
        rm -f "$PROJECT_DIR/.env" 2>/dev/null || true
        ok "✅ Fichiers de configuration supprimés"
      fi
    fi
  else
    log "ℹ️ Aucun répertoire projet à nettoyer"
  fi
}

verify_cleanup() {
  log "🔍 Vérification nettoyage..."

  local issues=0

  # Vérifier conteneurs Supabase
  local containers=$(docker ps -a --filter "name=supabase" --format "{{.Names}}" | wc -l)
  if [[ $containers -eq 0 ]]; then
    ok "  ✅ Aucun conteneur Supabase restant"
  else
    warn "  ⚠️ $containers conteneur(s) Supabase encore présent(s)"
    ((issues++))
  fi

  # Vérifier réseaux
  if docker network ls | grep -q "supabase"; then
    warn "  ⚠️ Réseaux Supabase encore présents"
    ((issues++))
  else
    ok "  ✅ Réseaux Supabase supprimés"
  fi

  # Vérifier état final
  if [[ $issues -eq 0 ]]; then
    ok "✅ Nettoyage complet réussi"
  else
    warn "⚠️ $issues élément(s) nécessitent attention manuelle"
  fi

  return $issues
}

show_next_steps() {
  echo ""
  echo "══════════════════════════════════════════════════════════════════"
  echo "🎉 NETTOYAGE TERMINÉ - PRÊT POUR NOUVELLE INSTALLATION"
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
  echo "📋 **Prochaines étapes** :"
  echo ""
  echo "1️⃣ **Lancer le script Week2 amélioré** :"
  echo "   cd $SCRIPT_DIR"
  echo "   sudo ./setup-week2-supabase-final.sh"
  echo ""
  echo "2️⃣ **Nouveautés dans cette version** :"
  echo "   🔧 Realtime: RLIMIT_NOFILE + ulimits ARM64"
  echo "   🔧 Kong: Image ARM64 spécifique + DNS optimisé"
  echo "   🔧 Edge Functions: Main function + command array"
  echo "   🔧 Entropie: Installation automatique haveged"
  echo "   🔧 Docker: Limites optimisées pour Pi 5"
  echo ""
  echo "3️⃣ **Surveillance recommandée** :"
  echo "   📊 Logs: docker compose logs -f <service>"
  echo "   📊 Santé: ./scripts/supabase-health.sh"
  echo ""
  echo "🎯 Cette installation intègre toutes les découvertes de recherche 2024"
  echo "══════════════════════════════════════════════════════════════════"
  echo ""
  echo "💡 **Usage du script de nettoyage** :"
  echo "   • Mode interactif: sudo ./cleanup-week2-supabase.sh"
  echo "   • Mode automatique: sudo ./cleanup-week2-supabase.sh --force"
  echo ""
}

main() {
  require_root
  show_cleanup_banner

  log "🎯 Nettoyage pour utilisateur: $TARGET_USER"

  # Vérifier si nettoyage nécessaire
  if ! check_existing_installation; then
    log "✅ Aucun nettoyage nécessaire - système propre"
    echo ""
    echo "🚀 Vous pouvez directement lancer:"
    echo "   cd $SCRIPT_DIR"
    echo "   sudo ./setup-week2-supabase-final.sh"
    exit 0
  fi

  # Demander confirmation (sauf en mode force)
  if [[ "$FORCE_MODE" == "true" ]]; then
    log "🤖 Mode force activé - Nettoyage automatique en cours..."
  else
    echo ""
    warn "⚠️ ATTENTION: Cette opération va supprimer l'installation Supabase existante"
    warn "   - Tous les conteneurs et volumes seront supprimés"
    warn "   - Les données PostgreSQL seront perdues"
    warn "   - Une sauvegarde .env sera créée si elle existe"
    echo ""
    read -p "🤔 Continuer avec le nettoyage? [y/N]: " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      log "❌ Nettoyage annulé par l'utilisateur"
      exit 0
    fi
  fi

  # Exécuter nettoyage
  stop_supabase_services
  cleanup_docker_resources
  cleanup_project_directory
  verify_cleanup

  show_next_steps
}

main "$@"