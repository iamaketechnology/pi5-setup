#!/usr/bin/env bash
set -euo pipefail

# === FIX ENV VARIABLES - Synchronise les variables d'environnement ===

log()  { echo -e "\033[1;36m[ENV-FIX]\033[0m $*"; }
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

fix_env_variables() {
  log "🔧 Correction des variables d'environnement Supabase"

  # Détecter automatiquement le répertoire Supabase
  local supabase_dir
  if supabase_dir=$(detect_supabase_directory); then
    ok "✅ Répertoire Supabase détecté : $supabase_dir"
    cd "$supabase_dir"
  else
    error "❌ Répertoire Supabase non trouvé"
    exit 1
  fi

  # Backup du .env existant
  cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
  ok "✅ Backup .env créé"

  # Charger les variables existantes
  source .env

  # Identifier les variables manquantes pour les connexions database
  log "🔍 Analyse des variables manquantes..."

  local missing_vars=()

  # Vérifier AUTHENTICATOR_PASSWORD (pour service rest)
  if [[ -z "${AUTHENTICATOR_PASSWORD:-}" ]]; then
    missing_vars+=("AUTHENTICATOR_PASSWORD")
  fi

  # Vérifier SUPABASE_STORAGE_PASSWORD (pour service storage)
  if [[ -z "${SUPABASE_STORAGE_PASSWORD:-}" ]]; then
    missing_vars+=("SUPABASE_STORAGE_PASSWORD")
  fi

  if [[ ${#missing_vars[@]} -gt 0 ]]; then
    warn "⚠️ Variables manquantes détectées : ${missing_vars[*]}"
    log "   Génération des variables manquantes..."

    # Générer des mots de passe sécurisés (sans caractères spéciaux problématiques)
    local new_auth_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    local new_storage_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)

    # Ajouter les variables manquantes au .env
    if [[ " ${missing_vars[*]} " =~ " AUTHENTICATOR_PASSWORD " ]]; then
      echo "" >> .env
      echo "# Generated for authenticator user (rest service)" >> .env
      echo "AUTHENTICATOR_PASSWORD=$new_auth_password" >> .env
      ok "✅ AUTHENTICATOR_PASSWORD générée"
    fi

    if [[ " ${missing_vars[*]} " =~ " SUPABASE_STORAGE_PASSWORD " ]]; then
      echo "" >> .env
      echo "# Generated for supabase_storage_admin user (storage service)" >> .env
      echo "SUPABASE_STORAGE_PASSWORD=$new_storage_password" >> .env
      ok "✅ SUPABASE_STORAGE_PASSWORD générée"
    fi

  else
    ok "✅ Toutes les variables requises présentes"
  fi

  # **OPTION ALTERNATIVE** : Simplifier en utilisant POSTGRES_PASSWORD partout
  echo ""
  log "💡 Option recommandée : Simplifier avec POSTGRES_PASSWORD unique"
  echo ""
  echo "   Au lieu de gérer plusieurs mots de passe, on peut utiliser"
  echo "   POSTGRES_PASSWORD pour tous les utilisateurs database."
  echo ""

  read -p "Utiliser POSTGRES_PASSWORD pour tous les services ? (oui/non): " -r
  if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
    log "🔄 Modification docker-compose.yml pour unifier les mots de passe..."

    # Backup docker-compose
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

    # Remplacer les variables dans docker-compose.yml
    sed -i.bak \
      -e 's/authenticator:${AUTHENTICATOR_PASSWORD}/authenticator:${POSTGRES_PASSWORD}/g' \
      -e 's/supabase_storage_admin:${SUPABASE_STORAGE_PASSWORD}/supabase_storage_admin:${POSTGRES_PASSWORD}/g' \
      docker-compose.yml

    ok "✅ Docker-compose unifié avec POSTGRES_PASSWORD"

    # Supprimer les variables redondantes du .env si elles existent
    grep -v -E "^(AUTHENTICATOR_PASSWORD|SUPABASE_STORAGE_PASSWORD)=" .env > .env.tmp || true
    mv .env.tmp .env

    ok "✅ Variables redondantes supprimées de .env"

  else
    ok "✅ Conservation des variables spécifiques"
  fi

  # Recharger et vérifier la configuration finale
  source .env

  log "📋 Configuration finale :"
  echo "   POSTGRES_PASSWORD=***${POSTGRES_PASSWORD: -4}"

  if [[ -n "${AUTHENTICATOR_PASSWORD:-}" ]]; then
    echo "   AUTHENTICATOR_PASSWORD=***${AUTHENTICATOR_PASSWORD: -4}"
  else
    echo "   AUTHENTICATOR_PASSWORD=<utilise POSTGRES_PASSWORD>"
  fi

  if [[ -n "${SUPABASE_STORAGE_PASSWORD:-}" ]]; then
    echo "   SUPABASE_STORAGE_PASSWORD=***${SUPABASE_STORAGE_PASSWORD: -4}"
  else
    echo "   SUPABASE_STORAGE_PASSWORD=<utilise POSTGRES_PASSWORD>"
  fi

  echo ""
  echo "==================== ✅ VARIABLES SYNCHRONISÉES ===================="
  echo ""
  echo "🎯 **Prochaines étapes** :"
  echo "   1. Lancer le reset complet : ./scripts/supabase-complete-reset.sh"
  echo "   2. Ou redémarrer services : docker compose down && docker compose up -d"
  echo ""
  echo "📁 **Sauvegardes créées** :"
  echo "   - .env.backup.[timestamp]"
  echo "   - docker-compose.yml.backup.[timestamp]"
  echo "=============================================================="
}

main() {
  echo "==================== 🔧 CORRECTION VARIABLES ENV ===================="
  log "🎯 Synchronisation des variables pour résoudre les erreurs d'authentification"
  echo ""

  fix_env_variables
}

main "$@"