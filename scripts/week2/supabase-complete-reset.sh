#!/usr/bin/env bash
set -euo pipefail

# === SUPABASE COMPLETE RESET - Solution basée sur GitHub Issues ===

log()  { echo -e "\033[1;36m[RESET]  \033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]   \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]     \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; }

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

complete_reset() {
  log "🔄 RESET COMPLET SUPABASE - Solution basée sur les GitHub Issues"

  # Détecter automatiquement le répertoire Supabase
  local supabase_dir
  if supabase_dir=$(detect_supabase_directory); then
    ok "✅ Répertoire Supabase détecté : $supabase_dir"
    cd "$supabase_dir"
  else
    error "❌ Répertoire Supabase non trouvé"
    exit 1
  fi

  # Étape 1: Arrêt complet de tous les services
  log "⏹️ Arrêt complet de tous les services..."
  docker compose down --remove-orphans --volumes 2>/dev/null || true
  sleep 2

  # Étape 2: Suppression du volume database persistant (Solution GitHub #18836)
  log "🗑️ Suppression volume database persistant (solution GitHub)..."

  if [[ -d "volumes/db/data" ]]; then
    sudo rm -rf volumes/db/data
    ok "✅ Volume database supprimé"
  else
    ok "✅ Pas de volume database à supprimer"
  fi

  # Étape 3: Nettoyage Docker complet
  log "🧹 Nettoyage Docker complet..."

  # Supprimer containers Supabase
  docker ps -a --format "{{.Names}}" | grep "^supabase-" | xargs -r docker rm -f 2>/dev/null || true

  # Supprimer images Supabase uniquement (pas toutes)
  local supabase_images=$(docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(supabase|postgres.*alpine|kong|postgrest)" || true)
  if [[ -n "$supabase_images" ]]; then
    echo "$supabase_images" | xargs -r docker rmi -f 2>/dev/null || true
    ok "✅ Images Supabase supprimées"
  fi

  # Supprimer réseaux Supabase
  docker network ls --format "{{.Name}}" | grep "supabase" | xargs -r docker network rm 2>/dev/null || true

  # Étape 4: Vérification des variables d'environnement
  log "🔍 Vérification configuration .env..."

  if [[ -f ".env" ]]; then
    source .env

    # Vérifier que POSTGRES_PASSWORD n'a pas de caractères spéciaux problématiques (GitHub Issue)
    if [[ "$POSTGRES_PASSWORD" =~ [@\$\&\#] ]]; then
      warn "⚠️ Mot de passe contient des caractères spéciaux problématiques (@, \$, &, #)"
      warn "   Recommandation GitHub: utiliser seulement [a-zA-Z0-9_-]"
    fi

    ok "✅ Configuration .env validée"
  else
    error "❌ Fichier .env manquant"
    exit 1
  fi

  # Étape 5: Création répertoire volumes avec bonnes permissions
  log "📁 Recréation structure volumes..."

  mkdir -p volumes/db/data
  chmod 750 volumes/db/data

  # Sur Pi, s'assurer que les permissions Docker sont correctes
  if [[ $(id -u) != "0" ]]; then
    sudo chown -R 999:999 volumes/db/data 2>/dev/null || chown -R $(id -u):$(id -g) volumes/db/data
  fi

  ok "✅ Structure volumes recréée"

  # Étape 6: Pré-pull des images pour éviter timeouts
  log "📦 Téléchargement images Docker..."

  docker compose pull --quiet
  ok "✅ Images téléchargées"

  # Étape 7: Démarrage avec initialisation propre
  log "🚀 Démarrage avec initialisation complète..."

  # Démarrer d'abord la DB seule
  docker compose up -d db

  # Attendre que la DB soit vraiment prête
  local db_ready=false
  local retry_count=0

  while [[ $retry_count -lt 60 ]] && [[ $db_ready == false ]]; do
    if docker compose exec -T db pg_isready -U postgres >/dev/null 2>&1; then
      db_ready=true
    else
      sleep 2
      ((retry_count++))
    fi
  done

  if [[ $db_ready == false ]]; then
    error "❌ Database non accessible après 2 minutes"
    return 1
  fi

  ok "✅ Database initialisée et accessible"

  # Démarrer tous les autres services
  docker compose up -d

  log "⏳ Attente stabilisation complète (45 secondes)..."
  sleep 45

  # Vérification finale
  log "🏥 Vérification finale..."

  local services_up=0
  local services_total=0

  while IFS= read -r line; do
    if [[ $line =~ supabase- ]]; then
      ((services_total++))
      if [[ $line =~ Up ]] && [[ ! $line =~ Restarting ]]; then
        ((services_up++))
      fi
    fi
  done < <(docker compose ps --format "table {{.Name}}\t{{.Status}}" | tail -n +2)

  echo ""
  echo "==================== 🎉 RESET TERMINÉ ===================="
  ok "Services actifs : $services_up/$services_total"

  if [[ $services_up -ge 6 ]]; then
    echo ""
    echo "🎉 **RESET RÉUSSI !** Supabase devrait maintenant fonctionner"
    echo ""

    local ip_address=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    echo "🌐 **Accès aux services** :"
    echo "   🎨 Studio : http://$ip_address:3000"
    echo "   🔌 API    : http://$ip_address:8001"
    echo ""
    echo "🔍 **Vérification** :"
    echo "   ./scripts/supabase-health.sh"
    echo ""
    echo "📝 **Basé sur les solutions GitHub Issues** :"
    echo "   - #18836: Volume database reset"
    echo "   - #11957: Password authentication fix"
    echo "   - #30640: Pi ARM64 compatibility"

  else
    warn "⚠️ $services_up/$services_total services actifs - Attendre encore un peu"
    echo ""
    echo "🔍 **Actions si problèmes persistent** :"
    echo "   docker compose logs <service_name>"
    echo "   ./scripts/supabase-health.sh"
  fi

  echo "=============================================================="
}

main() {
  # Confirmation utilisateur
  echo "==================== ⚠️ RESET COMPLET SUPABASE ===================="
  echo ""
  echo "🗑️ **Cette action va :**"
  echo "   ❌ Arrêter tous les services Supabase"
  echo "   ❌ Supprimer TOUTES les données de la base"
  echo "   ❌ Supprimer le volume /volumes/db/data"
  echo "   ❌ Nettoyer images et containers Docker"
  echo "   ✅ Redémarrer avec une configuration propre"
  echo ""
  echo "📚 **Solution basée sur GitHub Issues** :"
  echo "   - supabase/supabase#18836 (volume reset)"
  echo "   - supabase/supabase#11957 (auth fix)"
  echo ""

  read -p "Confirmer le RESET COMPLET ? (oui/non): " -r
  if [[ ! $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "Reset annulé"
    exit 0
  fi

  complete_reset
}

main "$@"