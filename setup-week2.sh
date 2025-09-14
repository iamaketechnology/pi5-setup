#!/usr/bin/env bash
set -euo pipefail

# === ORCHESTRATEUR Week 2 - Support 16KB page size natif ===
MODE="${MODE:-beginner}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week2-orchestrator.log}"
PHASE_STATE_FILE="/tmp/pi5-supabase-phase.state"

log()  { echo -e "\033[1;36m[ORCHESTRATOR]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week2.sh"
    exit 1
  fi
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Supabase Orchestrator Week 2 - $(date) ==="
}

detect_current_phase() {
  log "🔍 Détection phase actuelle…"

  # Vérifier si Phase 1 déjà terminée
  if [[ -f "$PHASE_STATE_FILE" ]]; then
    SAVED_PHASE=$(cat "$PHASE_STATE_FILE")
    log "Phase sauvée détectée: $SAVED_PHASE"
  else
    SAVED_PHASE="none"
  fi

  # Vérifier page size
  CURRENT_PAGE_SIZE=$(getconf PAGE_SIZE)
  log "Page size détecté: $CURRENT_PAGE_SIZE (compatible)"

  # Vérifier si projet existe
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
  PROJECT_DIR="$HOME_DIR/stacks/supabase"
  PROJECT_EXISTS=false
  [[ -d "$PROJECT_DIR" ]] && PROJECT_EXISTS=true

  # Logique de détection - 16KB page size supporté nativement
  if [[ "$PROJECT_EXISTS" == false ]]; then
    DETECTED_PHASE="phase1"
    log "→ Phase 1 nécessaire: Page size ${CURRENT_PAGE_SIZE} (supporté) + projet absent"
  elif [[ "$PROJECT_EXISTS" == true ]] && [[ "$SAVED_PHASE" == "phase1_completed" ]]; then
    DETECTED_PHASE="phase2"
    log "→ Phase 2 nécessaire: Projet prêt + page size ${CURRENT_PAGE_SIZE} (compatible)"
  else
    DETECTED_PHASE="phase1"
    log "→ Phase 1 nécessaire: Configuration incomplète"
  fi

  ok "Phase détectée: $DETECTED_PHASE"
}

run_phase1() {
  log "🚀 Lancement Phase 1: Préparation système compatible 16KB…"

  # Télécharger et exécuter phase1
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2-phase1.sh -o /tmp/setup-week2-phase1.sh
  chmod +x /tmp/setup-week2-phase1.sh

  # Exécuter phase1 avec les mêmes variables d'environnement
  if MODE="$MODE" /tmp/setup-week2-phase1.sh; then
    # Sauvegarder l'état
    echo "phase1_completed" > "$PHASE_STATE_FILE"

    # Vérifier si reboot nécessaire
    NEW_PAGE_SIZE=$(getconf PAGE_SIZE)
    if [[ "$NEW_PAGE_SIZE" == "16384" ]]; then
      show_reboot_instructions
    else
      show_phase2_instructions
    fi
  else
    error "❌ Phase 1 échouée"
    exit 1
  fi
}

run_phase2() {
  log "🚀 Lancement Phase 2: Installation Supabase avec images compatibles 16KB…"

  # Télécharger et exécuter phase2
  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2-phase2.sh -o /tmp/setup-week2-phase2.sh
  chmod +x /tmp/setup-week2-phase2.sh

  # Exécuter phase2 avec les mêmes variables d'environnement
  if MODE="$MODE" /tmp/setup-week2-phase2.sh; then
    # Nettoyer l'état
    rm -f "$PHASE_STATE_FILE"
    show_completion_summary
  else
    error "❌ Phase 2 échouée"
    exit 1
  fi
}

show_reboot_instructions() {
  echo
  echo "==================== ⚠️  REDÉMARRAGE OBLIGATOIRE ===================="
  echo ""
  echo "🔴 **Page size configuré mais pas actif**"
  echo "   Page size actuel: $(getconf PAGE_SIZE) (doit être 4096)"
  echo "   Configuration ajoutée à /boot/firmware/cmdline.txt"
  echo ""
  echo "🚀 **Actions requises** :"
  echo "   1️⃣  sudo reboot"
  echo "   2️⃣  ssh pi@pi5.local"
  echo "   3️⃣  curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2.sh -o setup-week2.sh && chmod +x setup-week2.sh && sudo MODE=$MODE ./setup-week2.sh"
  echo ""
  echo "📋 **Après redémarrage, le script détectera automatiquement Phase 2**"
  echo ""
  read -p "Voulez-vous redémarrer maintenant ? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "Redémarrage automatique en 5 secondes…"
    sleep 5
    reboot
  else
    echo ""
    echo "⚡ **Commande de redémarrage** : sudo reboot"
    echo "⚡ **Après redémarrage** : sudo MODE=$MODE ./setup-week2.sh"
  fi
  echo "=================================================================="
}

show_phase2_instructions() {
  echo
  echo "==================== ✅ PHASE 1 TERMINÉE ===================="
  echo ""
  echo "🎯 **Phase 2 prête à démarrer**"
  echo "   Page size: $(getconf PAGE_SIZE) ✅ (Compatible natif)"
  echo "   Projet créé: ~/stacks/supabase ✅"
  echo ""
  echo "🚀 **Lancement automatique Phase 2 dans 3 secondes…**"
  echo ""

  # Countdown
  for i in {3..1}; do
    echo -n "⏳ Phase 2 dans $i secondes... "
    sleep 1
    echo ""
  done

  log "🚀 Démarrage automatique Phase 2"
}

show_reboot_detected() {
  echo
  echo "==================== 🔄 REDÉMARRAGE DÉTECTÉ ===================="
  echo ""
  echo "✅ **Page size corrigé** : $(getconf PAGE_SIZE) (era 16384)"
  echo "✅ **Projet préparé** : ~/stacks/supabase existe"
  echo ""
  echo "🚀 **Lancement automatique Phase 2 dans 3 secondes…**"
  echo ""

  for i in {3..1}; do
    echo -n "⏳ Phase 2 dans $i secondes... "
    sleep 1
    echo ""
  done
}

show_completion_summary() {
  local IP=$(hostname -I | awk '{print $1}')

  echo
  echo "==================== 🎉 SUPABASE Pi 5 INSTALLÉ ! ===================="
  echo ""
  echo "✅ **Installation complétée avec succès**"
  echo "   🎯 Page size: $(getconf PAGE_SIZE) - Images compatibles utilisées"
  echo ""
  echo "📍 **Accès aux services** :"
  echo "   🎨 Studio      : http://$IP:3000"
  echo "   🔌 API Gateway : http://$IP:8000"
  echo "   ⚡ Edge Funcs  : http://$IP:54321/functions/v1/"
  if [[ "$MODE" == "pro" ]]; then
    echo "   🔧 pgAdmin     : http://$IP:8080"
  fi
  echo ""
  echo "🛠️  **Scripts utilitaires** :"
  echo "   cd ~/stacks/supabase"
  echo "   ./scripts/supabase-health.sh     # 🏥 Vérifier santé"
  echo "   ./scripts/supabase-backup.sh     # 💾 Sauvegarder DB"
  echo ""
  echo "📋 **Prochaine étape : Week 3 - HTTPS et accès externe**"
  echo "=================================================================="
}

main() {
  require_root
  detect_current_phase

  case $DETECTED_PHASE in
    "phase1")
      run_phase1
      ;;
    "reboot_required")
      show_reboot_instructions
      ;;
    "phase2")
      show_reboot_detected
      run_phase2
      ;;
    *)
      error "Phase inconnue: $DETECTED_PHASE"
      exit 1
      ;;
  esac
}

main "$@"