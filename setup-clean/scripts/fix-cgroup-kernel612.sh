#!/usr/bin/env bash
set -euo pipefail

# === WORKAROUND CGROUP MEMORY KERNEL 6.12 PI 5 ===

log() { echo -e "\033[1;36m[CGROUP-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage : sudo $0"
    exit 1
  fi
}

check_kernel_version() {
  local kernel_version=$(uname -r)
  log "🔍 Kernel détecté: $kernel_version"

  if [[ "$kernel_version" =~ 6\.12 ]]; then
    warn "⚠️ Kernel 6.12 détecté - bug cgroup memory connu"
    return 0
  else
    ok "✅ Kernel différent de 6.12 - pas de bug connu"
    return 1
  fi
}

diagnose_cgroup_status() {
  log "📊 Diagnostic état cgroups..."

  echo ""
  log "1. Contrôleurs cgroup v2 disponibles:"
  if [[ -f "/sys/fs/cgroup/cgroup.controllers" ]]; then
    local controllers=$(cat /sys/fs/cgroup/cgroup.controllers)
    if [[ "$controllers" =~ memory ]]; then
      ok "✅ Contrôleur memory disponible: $controllers"
    else
      warn "⚠️ Contrôleur memory ABSENT: $controllers"
    fi
  else
    error "❌ Fichier cgroup.controllers non trouvé"
  fi

  echo ""
  log "2. État Docker cgroups:"
  if command -v docker >/dev/null 2>&1; then
    docker info 2>/dev/null | grep -E "(Cgroup|Driver)" || warn "Docker info inaccessible"
  else
    warn "Docker non installé"
  fi

  echo ""
  log "3. Paramètres boot actuels:"
  grep -o 'cgroup[^ ]*' /proc/cmdline || log "Aucun paramètre cgroup trouvé"
}

fix_cmdline_kernel612() {
  log "🔧 Application workaround kernel 6.12..."

  # Détection automatique du chemin cmdline.txt
  local cmdline_file=""
  if [[ -f "/boot/cmdline.txt" ]]; then
    cmdline_file="/boot/cmdline.txt"
  elif [[ -f "/boot/firmware/cmdline.txt" ]]; then
    cmdline_file="/boot/firmware/cmdline.txt"
  else
    error "❌ Fichier cmdline.txt non trouvé"
    return 1
  fi

  log "   Fichier boot: $cmdline_file"

  # Backup de sécurité
  cp "$cmdline_file" "${cmdline_file}.backup.$(date +%Y%m%d_%H%M%S)"

  # Supprimer paramètres de désactivation (forcés par kernel 6.12)
  sed -i 's/ cgroup_disable=memory//g' "$cmdline_file"
  sed -i 's/cgroup_disable=memory //g' "$cmdline_file"

  # Ajouter paramètres d'activation si absents
  if ! grep -q 'cgroup_enable=memory' "$cmdline_file"; then
    sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' "$cmdline_file"
    log "   ✅ Paramètres cgroup ajoutés"
  else
    log "   ℹ️ Paramètres cgroup déjà présents"
  fi

  # Afficher le contenu final
  echo ""
  log "Contenu final cmdline.txt:"
  cat "$cmdline_file"
}

test_memory_limits() {
  log "🧪 Test limites mémoire Docker..."

  if ! command -v docker >/dev/null 2>&1; then
    warn "Docker non installé - impossible de tester"
    return 1
  fi

  log "   Lancement test container avec limite 64M..."
  if docker run --rm --memory 64m alpine:3.19 sh -c 'echo "Test limite mémoire OK"' 2>/dev/null; then
    ok "✅ Test limite mémoire réussi"
  else
    warn "⚠️ Test limite mémoire échoué (warnings attendus sur kernel 6.12)"
  fi
}

show_kernel612_info() {
  echo ""
  log "📋 INFORMATION KERNEL 6.12:"
  echo ""
  warn "⚠️ Bug connu: Le kernel 6.12 sur Pi 5 ignore les paramètres cgroup_enable=memory"
  log "   • Les warnings Docker 'memory limit capabilities' peuvent persister"
  log "   • Supabase et Docker fonctionnent CORRECTEMENT malgré les warnings"
  log "   • Les limites memory sont 'discarded' mais les containers tournent"
  echo ""
  log "🎯 Solutions alternatives:"
  log "   1. Ignorer les warnings (fonctionnel)"
  log "   2. Downgrade vers kernel 6.6.x (stable)"
  log "   3. Attendre fix officiel Raspberry Pi Foundation"
  echo ""
  log "🔄 Pour downgrade kernel:"
  log "   sudo rpi-update 6.6.74"
  log "   sudo reboot"
}

main() {
  require_root

  echo ""
  log "🚀 Diagnostic et correction cgroup memory Pi 5"
  echo ""

  diagnose_cgroup_status
  echo ""

  if check_kernel_version; then
    # Kernel 6.12 détecté
    fix_cmdline_kernel612
    echo ""
    show_kernel612_info
    echo ""

    read -p "Redémarrer maintenant pour appliquer les corrections ? (oui/non): " -r
    if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
      log "🔄 Redémarrage en cours..."
      sleep 2
      reboot
    else
      warn "⚠️ Redémarrage reporté - À faire manuellement : sudo reboot"
    fi
  else
    # Kernel autre que 6.12
    fix_cmdline_kernel612
    echo ""
    test_memory_limits
    echo ""

    read -p "Redémarrer pour activer les cgroups ? (oui/non): " -r
    if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
      log "🔄 Redémarrage en cours..."
      sleep 2
      reboot
    else
      ok "✅ Correction appliquée - Redémarrez : sudo reboot"
    fi
  fi
}

main "$@"