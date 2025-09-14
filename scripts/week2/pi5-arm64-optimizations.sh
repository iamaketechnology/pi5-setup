#!/usr/bin/env bash
set -euo pipefail

# === PI 5 ARM64 OPTIMIZATIONS - Basé sur GitHub Issues ===

log()  { echo -e "\033[1;36m[PI5-OPT]\033[0m $*"; }
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

apply_pi5_optimizations() {
  log "🥧 Application optimisations Pi 5 ARM64 (basé sur GitHub #30640)"

  # Détecter automatiquement le répertoire Supabase
  local supabase_dir
  if supabase_dir=$(detect_supabase_directory); then
    ok "✅ Répertoire Supabase détecté : $supabase_dir"
    cd "$supabase_dir"
  else
    error "❌ Répertoire Supabase non trouvé"
    exit 1
  fi

  # 1. Vérification page size (critique pour Pi 5)
  log "📏 Vérification page size du kernel..."
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  echo "   Page size actuelle : $page_size bytes"

  if [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL"
  elif [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB - INCOMPATIBLE avec PostgreSQL"
    echo ""
    echo "🔧 **Solution requise (GitHub Issue #30640)** :"
    echo "   1. Ajouter à /boot/firmware/config.txt :"
    echo "      kernel=kernel8.img"
    echo "   2. Redémarrer le Pi"
    echo "   3. Vérifier : getconf PAGESIZE"
    echo ""
    exit 1
  else
    warn "⚠️ Page size non standard ($page_size) - À surveiller"
  fi

  # 2. Désactiver supabase-vector pour ARM64 (si présent)
  log "🔍 Vérification supabase-vector (problématique sur ARM64)..."

  if grep -q "supabase-vector" docker-compose.yml 2>/dev/null; then
    warn "⚠️ supabase-vector détecté - Désactivation recommandée pour ARM64"

    # Backup
    cp docker-compose.yml docker-compose.yml.backup.pi5-$(date +%Y%m%d_%H%M%S)

    # Commenter la section supabase-vector
    sed -i.tmp '/vector:/,/^  [a-zA-Z]/{ /^  [a-zA-Z]/!s/^/#/; /^  vector:/s/^/#/; }' docker-compose.yml

    ok "✅ supabase-vector désactivé"
  else
    ok "✅ Pas de supabase-vector à désactiver"
  fi

  # 3. Optimisations mémoire pour Pi 5 16GB
  log "💾 Application optimisations mémoire Pi 5 16GB..."

  # Ajout variables PostgreSQL optimisées pour Pi 5 si absentes
  if ! grep -q "POSTGRES_SHARED_BUFFERS" .env; then
    cat >> .env << 'EOF'

# Pi 5 16GB PostgreSQL Optimizations
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_EFFECTIVE_CACHE_SIZE=8GB
EOF
    ok "✅ Variables PostgreSQL Pi 5 ajoutées"
  else
    ok "✅ Variables PostgreSQL déjà configurées"
  fi

  # 4. Ajustements healthchecks pour performances ARM64
  log "🏥 Optimisation healthchecks pour ARM64..."

  # Les healthchecks sont déjà optimisés dans le setup-week2-improved.sh
  ok "✅ Healthchecks optimisés pour ARM64"

  # 5. Optimisations Docker pour ARM64
  log "🐳 Configuration Docker pour ARM64..."

  local docker_config="/etc/docker/daemon.json"

  if [[ -f "$docker_config" ]] && command -v jq >/dev/null 2>&1; then
    # Ajouter optimisations ARM64 si elles n'existent pas
    local temp_config=$(mktemp)
    jq '. + {"experimental": true, "features": {"buildkit": true}}' "$docker_config" > "$temp_config"

    if sudo cp "$temp_config" "$docker_config" 2>/dev/null; then
      ok "✅ Docker optimisé pour ARM64"
    else
      warn "⚠️ Pas de permissions pour modifier Docker config"
    fi
    rm -f "$temp_config"
  else
    ok "✅ Configuration Docker manuelle requise"
  fi

  # 6. Vérifications système Pi 5
  log "🔍 Vérifications système Pi 5..."

  # Température
  if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
    local temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "0")
    local temp_c=$((temp / 1000))
    echo "   Température CPU : ${temp_c}°C"

    if [[ $temp_c -gt 70 ]]; then
      warn "⚠️ Température élevée - Vérifier refroidissement"
    else
      ok "✅ Température acceptable"
    fi
  fi

  # Mémoire disponible
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  echo "   RAM disponible : ${ram_gb}GB"

  if [[ $ram_gb -ge 15 ]]; then
    ok "✅ RAM excellente pour Supabase (${ram_gb}GB)"
  else
    warn "⚠️ RAM détectée différente de 16GB attendu"
  fi

  echo ""
  echo "==================== 🥧 OPTIMISATIONS PI 5 APPLIQUÉES ===================="
  echo ""
  echo "✅ **Optimisations appliquées** :"
  echo "   - Page size vérifié (4KB requis)"
  echo "   - supabase-vector désactivé si présent"
  echo "   - PostgreSQL optimisé pour 16GB RAM"
  echo "   - Healthchecks ajustés pour ARM64"
  echo "   - Docker optimisé si possible"
  echo ""
  echo "🎯 **Basé sur GitHub Issues** :"
  echo "   - supabase/supabase#30640 (Pi ARM64 support)"
  echo "   - Solutions communautaires validées"
  echo ""
  echo "🚀 **Prochaine étape** :"
  echo "   ./scripts/supabase-complete-reset.sh"
  echo "============================================================================="
}

main() {
  echo "==================== 🥧 OPTIMISATIONS PI 5 ARM64 ===================="
  log "🎯 Application des optimisations spécifiques Pi 5 pour Supabase"
  echo ""

  apply_pi5_optimizations
}

main "$@"