#!/usr/bin/env bash
set -euo pipefail

# === DIAGNOSTIC YAML ERROR - Identifier et corriger erreur YAML ===

TARGET_USER="${SUDO_USER:-$USER}"
[[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
PROJECT_DIR="$HOME_DIR/stacks/supabase"

log()  { echo -e "\033[1;36m[YAML-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

diagnose_yaml_error() {
  log "🔍 Diagnostic erreur YAML ligne 36..."

  if [[ ! -f "$PROJECT_DIR/docker-compose.yml" ]]; then
    error "❌ docker-compose.yml non trouvé"
    exit 1
  fi

  cd "$PROJECT_DIR"

  # Afficher ligne 36 et contexte
  log "📋 Contenu autour de la ligne 36 :"
  echo "===================="
  sed -n '30,40p' docker-compose.yml | nl -v30
  echo "===================="

  # Test validation YAML
  if python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
    ok "✅ YAML syntaxiquement valide avec Python"
  else
    warn "❌ YAML invalide selon Python"
    python3 -c "import yaml; yaml.safe_load(open('docker-compose.yml'))" 2>&1 | head -5
  fi

  # Test avec docker compose
  if docker compose config >/dev/null 2>&1; then
    ok "✅ docker-compose.yml valide"
  else
    warn "❌ docker-compose.yml invalide selon Docker"
    docker compose config 2>&1 | head -5
  fi
}

fix_yaml_indentation() {
  log "🔧 Correction indentation YAML..."

  # Backup
  cp docker-compose.yml "docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"

  # Rechercher problèmes d'indentation courants
  if grep -n "^[[:space:]]*-[[:space:]]*[^[:space:]]" docker-compose.yml; then
    warn "⚠️ Problèmes d'indentation détectés avec les listes"

    # Corriger indentation des listes
    sed -i 's/^[[:space:]]*-[[:space:]]*\([^[:space:]]\)/      - \1/' docker-compose.yml
    ok "✅ Indentation des listes corrigée"
  fi

  # Vérifier espaces/tabs mélangés
  if grep -P "\t" docker-compose.yml; then
    warn "⚠️ Tabs détectés - conversion en espaces..."
    sed -i 's/\t/  /g' docker-compose.yml
    ok "✅ Tabs convertis en espaces"
  fi
}

recreate_clean_compose() {
  log "🚀 Recréation docker-compose.yml propre..."

  # Télécharger version propre depuis GitHub
  curl -fsSL "https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/files/week2/docker-compose-clean.yml" -o docker-compose.yml.new

  if [[ -f "docker-compose.yml.new" ]]; then
    # Copier variables depuis .env
    if [[ -f ".env" ]]; then
      log "📋 Variables .env détectées - substitution..."

      # Remplacer variables hardcodées par références .env
      API_PORT=$(grep "^API_PORT=" .env | cut -d'=' -f2 || echo "8001")
      STUDIO_PORT=$(grep "^STUDIO_PORT=" .env | cut -d'=' -f2 || echo "3000")

      sed -i "s/8001:8000/$API_PORT:8000/g" docker-compose.yml.new
      sed -i "s/3000:3000/$STUDIO_PORT:3000/g" docker-compose.yml.new
    fi

    mv docker-compose.yml.new docker-compose.yml
    ok "✅ docker-compose.yml recréé"

    # Test validation
    if docker compose config >/dev/null 2>&1; then
      ok "✅ Nouveau docker-compose.yml valide"
    else
      error "❌ Nouveau docker-compose.yml invalide"
      return 1
    fi
  else
    error "❌ Impossible de télécharger docker-compose.yml propre"
    return 1
  fi
}

main() {
  log "🔧 Diagnostic et correction erreur YAML docker-compose"

  diagnose_yaml_error

  echo ""
  log "🛠️ Tentative correction..."

  fix_yaml_indentation

  # Re-test après correction
  if docker compose config >/dev/null 2>&1; then
    ok "🎉 YAML corrigé avec succès !"
  else
    warn "⚠️ Correction simple échouée - recréation complète..."
    recreate_clean_compose
  fi

  echo ""
  log "✅ Validation finale :"
  if docker compose config >/dev/null 2>&1; then
    ok "🎉 docker-compose.yml maintenant valide !"
    echo ""
    echo "🚀 Tu peux maintenant relancer :"
    echo "   sudo ./fix.sh"
  else
    error "❌ Problème persiste - inspection manuelle requise"
    echo ""
    echo "🔍 Examine la sortie de :"
    echo "   docker compose config"
  fi
}

main "$@"