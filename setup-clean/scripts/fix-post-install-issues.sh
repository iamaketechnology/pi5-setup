#!/usr/bin/env bash
set -euo pipefail

# === FIX POST-INSTALL ISSUES - Corrections après installation Week2 ===

log()  { echo -e "\033[1;36m[FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]  \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

PROJECT_DIR="/home/pi/stacks/supabase"

show_banner() {
  echo ""
  echo "╔══════════════════════════════════════════════════════════════════╗"
  echo "║                     🔧 POST-INSTALL FIXES                       ║"
  echo "║                                                                  ║"
  echo "║  Corrections des problèmes détectés après installation Week2    ║"
  echo "╚══════════════════════════════════════════════════════════════════╝"
  echo ""
}

fix_working_directory() {
  log "📁 Correction répertoire de travail..."

  # S'assurer que le répertoire existe et y aller
  mkdir -p "$PROJECT_DIR"
  cd "$PROJECT_DIR"

  ok "✅ Répertoire de travail corrigé: $(pwd)"
}

fix_entropy() {
  log "🎲 Correction entropie système..."

  # Redémarrer haveged
  systemctl restart haveged
  sleep 2

  # Vérifier entropie
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail)
  if [[ $entropy -gt 1000 ]]; then
    ok "✅ Entropie améliorée: $entropy"
  else
    warn "⚠️ Entropie toujours faible: $entropy"

    # Installer rng-tools en complément
    log "   Installation rng-tools pour améliorer l'entropie..."
    apt update && apt install -y rng-tools
    systemctl enable rng-tools
    systemctl start rng-tools

    sleep 3
    local new_entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    log "   Nouvelle entropie: $new_entropy"
  fi
}

fix_realtime_ulimits() {
  log "⚡ Correction ulimits Realtime..."

  cd "$PROJECT_DIR"

  # Redémarrer Realtime avec force
  docker compose restart realtime
  sleep 10

  # Tester ulimits
  local ulimit_result=$(docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null || echo "error")

  if [[ "$ulimit_result" == "10000" ]]; then
    ok "✅ Realtime ulimits corrigés: $ulimit_result"
  else
    warn "⚠️ Problème ulimits persistant: $ulimit_result"

    # Force recreation
    log "   Force recreation du conteneur Realtime..."
    docker compose up -d --force-recreate realtime
    sleep 15

    # Re-test
    local new_result=$(docker compose exec -T realtime sh -c 'ulimit -n' 2>/dev/null || echo "error")
    log "   Nouveau résultat ulimits: $new_result"
  fi
}

check_cgroups() {
  log "🔍 Vérification cgroups..."

  if grep -q "cgroup_memory=1" /boot/firmware/cmdline.txt; then
    ok "✅ Cgroups mémoire activés"
  else
    warn "⚠️ Cgroups mémoire non activés"
    echo ""
    echo "🔧 Pour activer les limites mémoire Docker :"
    echo "   1. Éditer : sudo nano /boot/firmware/cmdline.txt"
    echo "   2. Ajouter à la fin : cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1"
    echo "   3. Redémarrer : sudo reboot"
    echo ""
  fi
}

verify_services() {
  log "🔍 Vérification services..."

  cd "$PROJECT_DIR"

  # État général
  echo ""
  echo "📊 État des services :"
  docker compose ps

  echo ""
  echo "🧪 Tests de connectivité :"

  # Test Studio
  if timeout 5 curl -s http://localhost:3000 >/dev/null; then
    ok "  ✅ Studio accessible (port 3000)"
  else
    warn "  ⚠️ Studio non accessible"
  fi

  # Test API Gateway
  if timeout 5 curl -s http://localhost:8001 >/dev/null; then
    ok "  ✅ API Gateway accessible (port 8001)"
  else
    warn "  ⚠️ API Gateway non accessible"
  fi

  # Test Edge Functions
  if timeout 5 curl -s http://localhost:54321 >/dev/null; then
    ok "  ✅ Edge Functions accessible (port 54321)"
  else
    warn "  ⚠️ Edge Functions non accessible"
  fi
}

show_next_steps() {
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
  echo "🎯 CORRECTIONS APPLIQUÉES - PROCHAINES ÉTAPES"
  echo "════════════════════════════════════════════════════════════════════"
  echo ""
  echo "1️⃣ **Vérifier les services** :"
  echo "   cd $PROJECT_DIR"
  echo "   docker compose ps"
  echo "   ./scripts/supabase-health.sh"
  echo ""
  echo "2️⃣ **Accéder aux interfaces** :"
  echo "   🎨 Studio : http://192.168.1.73:3000"
  echo "   🔌 API    : http://192.168.1.73:8001"
  echo "   ⚡ Edge   : http://192.168.1.73:54321"
  echo ""
  echo "3️⃣ **Si problèmes persistent** :"
  echo "   docker compose logs -f <service>"
  echo "   docker compose restart <service>"
  echo ""
  echo "4️⃣ **Pour les limites mémoire** :"
  echo "   sudo nano /boot/firmware/cmdline.txt"
  echo "   Ajouter : cgroup_enable=memory cgroup_memory=1"
  echo "   sudo reboot"
  echo ""
  echo "════════════════════════════════════════════════════════════════════"
}

main() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0"
    exit 1
  fi

  show_banner

  fix_working_directory
  fix_entropy
  fix_realtime_ulimits
  check_cgroups
  verify_services

  show_next_steps
}

main "$@"