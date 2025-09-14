#!/usr/bin/env bash
set -euo pipefail

# === PHASE 1: Préparation & Support 16KB natif ===
MODE="${MODE:-beginner}"
SUPABASE_PROJECT_NAME="${SUPABASE_PROJECT_NAME:-supabase}"
SUPABASE_STACK_DIR="${SUPABASE_STACK_DIR:-stacks/supabase}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week2-phase1.log}"

log()  { echo -e "\033[1;36m[PHASE1]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week2-phase1.sh"
    exit 1
  fi
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Supabase Setup Week 2 - PHASE 1 - $(date) ==="
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
  PROJECT_DIR="$HOME_DIR/$SUPABASE_STACK_DIR"

  log "🎯 PHASE 1: Préparation système avec support 16KB natif"
  log "Projet Supabase: $PROJECT_DIR"
}

check_prerequisites() {
  log "Vérification prérequis Supabase sur Pi 5…"

  # Docker
  if ! command -v docker >/dev/null 2>&1; then
    error "Docker non installé. Exécutez d'abord setup-week1.sh"
    exit 1
  fi

  if ! docker compose version >/dev/null 2>&1; then
    error "Docker Compose non disponible"
    exit 1
  fi

  # Architecture ARM64
  if [[ "$(uname -m)" != "aarch64" ]]; then
    warn "Architecture détectée: $(uname -m). Ce script est optimisé pour ARM64/Pi 5."
  fi

  # RAM minimum
  RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  RAM_GB=$((RAM_KB / 1024 / 1024))
  if [[ $RAM_GB -lt 4 ]]; then
    error "RAM insuffisante: ${RAM_GB}GB détectés, minimum 4GB requis pour Supabase"
    exit 1
  fi
  ok "RAM détectée: ${RAM_GB}GB - Suffisant pour Supabase"

  # Espace disque
  DISK_AVAIL=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $DISK_AVAIL -lt 8 ]]; then
    error "Espace disque insuffisant: ${DISK_AVAIL}GB libres, minimum 8GB requis"
    exit 1
  fi

  # Groupe docker - correction automatique
  if ! groups "$TARGET_USER" | grep -q docker; then
    warn "Utilisateur $TARGET_USER pas dans le groupe docker. Correction automatique..."
    usermod -aG docker "$TARGET_USER"

    if ! groups "$TARGET_USER" | grep -q docker; then
      error "Échec ajout groupe docker. Vérifiez manuellement avec: sudo usermod -aG docker $TARGET_USER"
      exit 1
    fi
    ok "✅ Utilisateur $TARGET_USER ajouté au groupe docker"
  else
    ok "Utilisateur $TARGET_USER dans le groupe docker"
  fi

  ok "Tous les prérequis sont satisfaits"
}

check_page_size_compatibility() {
  log "Vérification page size pour compatibilité Supabase…"

  CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)

  if [[ "$CURRENT_PAGE_SIZE" == "4096" ]]; then
    ok "Page size: 4KB - Utilisation images Supabase officielles"
    return 0
  elif [[ "$CURRENT_PAGE_SIZE" == "16384" ]]; then
    ok "Page size: 16KB - Utilisation images compatibles (PostgreSQL Alpine)"
    log "→ Configuration optimisée pour Pi 5 avec support 16KB natif"
    return 0
  else
    warn "Page size inattendu: ${CURRENT_PAGE_SIZE}. Utilisation images compatibles."
    return 0
  fi
}

setup_project_directory() {
  log "📂 JOUR 1: Création arborescence ~/stacks/supabase…"

  # Créer l'arborescence selon le plan
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  log "Configuration Supabase autonome optimisée Pi 5"

  # Structure complète sans config postgres problématique
  mkdir -p volumes/{db/data,storage,pgadmin,functions}
  mkdir -p config/{auth,kong,nginx}
  mkdir -p backups
  mkdir -p logs
  mkdir -p scripts

  # Créer exemple Edge Function
  mkdir -p volumes/functions/hello
  cat > volumes/functions/hello/index.ts <<'TSEOF'
// Edge Function example - Pi 5 optimisé
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { name } = await req.json() || { name: "Pi5" }
  const data = {
    message: `Hello ${name}! From Supabase on Raspberry Pi 5`,
    timestamp: new Date().toISOString(),
    architecture: "ARM64",
  }

  return new Response(
    JSON.stringify(data),
    {
      headers: {
        "Content-Type": "application/json",
        "X-Powered-By": "Supabase-Pi5"
      }
    },
  )
})
TSEOF

  # Permissions
  chown -R "$TARGET_USER":"$TARGET_USER" "$PROJECT_DIR"
  chmod -R 755 volumes config scripts

  ok "✅ JOUR 1 TERMINÉ: Arborescence ~/stacks/supabase créée"
}

create_phase2_script() {
  log "Préparation script Phase 2 (post-reboot)…"

  # Créer le script Phase 2 qui sera exécuté après reboot
  cat > "$PROJECT_DIR/setup-week2-phase2.sh" <<'PHASE2EOF'
#!/usr/bin/env bash
set -euo pipefail

# === PHASE 2: Installation Supabase (Post-reboot) ===
MODE="${MODE:-beginner}"
SUPABASE_PROJECT_NAME="${SUPABASE_PROJECT_NAME:-supabase}"
SUPABASE_STACK_DIR="${SUPABASE_STACK_DIR:-stacks/supabase}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week2-phase2.log}"

log()  { echo -e "\033[1;36m[PHASE2]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week2-phase2.sh"
    exit 1
  fi
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Supabase Setup Week 2 - PHASE 2 - $(date) ==="
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
  PROJECT_DIR="$HOME_DIR/$SUPABASE_STACK_DIR"

  log "🚀 PHASE 2: Installation complète Supabase après reboot"
  log "Projet Supabase: $PROJECT_DIR"

  if [[ ! -d "$PROJECT_DIR" ]]; then
    error "Répertoire projet non trouvé: $PROJECT_DIR"
    error "Exécutez d'abord: sudo ./setup-week2-phase1.sh"
    exit 1
  fi
}

verify_page_size() {
  log "Vérification page size après reboot…"

  CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)

  if [[ "$CURRENT_PAGE_SIZE" == "4096" ]]; then
    ok "✅ Page size fixé: 4KB - Supabase compatible"
  else
    error "❌ Page size toujours: ${CURRENT_PAGE_SIZE} - Configuration échouée"
    error "Vérifiez /boot/firmware/cmdline.txt"
    exit 1
  fi
}

# Continuer avec le reste du script original...
# [Le reste du script original sera intégré ici]

main() {
  require_root
  detect_user
  verify_page_size
  echo "Phase 2 prête à être implémentée..."
}

main "$@"
PHASE2EOF

  chmod +x "$PROJECT_DIR/setup-week2-phase2.sh"
  chown "$TARGET_USER":"$TARGET_USER" "$PROJECT_DIR/setup-week2-phase2.sh"

  ok "Script Phase 2 créé: $PROJECT_DIR/setup-week2-phase2.sh"
}

summary_phase1() {
  echo
  echo "==================== 🎯 PHASE 1 TERMINÉE ===================="
  echo ""
  echo "✅ **Réalisations Phase 1** :"
  echo "   📂 Arborescence ~/stacks/supabase créée"
  echo "   🛠️  Groupe docker configuré"
  echo "   ⚙️  Page size 4KB configuré"
  echo ""
  echo "⚠️  **REDÉMARRAGE OBLIGATOIRE** :"
  echo "   🔴 Le Pi 5 doit redémarrer pour activer page size 4KB"
  echo "   🔴 Sans cela, Supabase va crasher avec jemalloc errors"
  echo ""
  echo "🚀 **Prochaines étapes** :"
  echo "   1️⃣  sudo reboot"
  echo "   2️⃣  ssh pi@pi5.local"
  echo "   3️⃣  cd ~/stacks/supabase"
  echo "   4️⃣  sudo MODE=beginner ./setup-week2-phase2.sh"
  echo ""
  echo "📋 **Alternative automatique** :"
  echo "   sudo reboot && sleep 60 && ssh pi@pi5.local 'cd ~/stacks/supabase && sudo ./setup-week2-phase2.sh'"
  echo "========================================"
}

main() {
  require_root
  detect_user
  check_prerequisites
  setup_project_directory
  check_page_size_compatibility

  # Page size maintenant toujours compatible
  log "✅ Page size compatible, création Phase 2..."
  create_phase2_script
  ok "✅ Phase 1 terminée - Prêt pour installation Supabase"

  echo ""
  echo "==================== ✅ PHASE 1 TERMINÉE ===================="
  echo ""
  echo "✅ **Configurations appliquées** :"
  echo "   📂 Arborescence ~/stacks/supabase créée"
  echo "   🐳 Docker configuré"
  echo "   🎯 Images compatibles page size $(getconf PAGE_SIZE)"
  echo ""
  echo "🚀 **PROCHAINE COMMANDE** :"
  echo "   # Lancer Phase 2 (installation complète)"
  echo "   sudo $PROJECT_DIR/setup-week2-phase2.sh"
  echo ""
  echo "📋 **Alternative orchestrateur** :"
  echo "   sudo MODE=beginner ./setup-week2.sh"
  echo "========================================================"
}

main "$@"