#!/usr/bin/env bash
set -euo pipefail

# === PI5 OPTIMIZATIONS - Optimisations spécifiques Raspberry Pi 5 ===

log()  { echo -e "\033[1;36m[PI5-OPT]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo ./pi5-optimizations.sh"
    exit 1
  fi
}

check_raspberry_pi() {
  log "🥧 Détection Raspberry Pi 5..."

  if [[ -f /proc/device-tree/model ]]; then
    local model=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0')
    echo "   Modèle détecté : $model"

    if [[ "$model" == *"Raspberry Pi 5"* ]]; then
      ok "✅ Raspberry Pi 5 confirmé"
      return 0
    else
      warn "⚠️ Modèle différent - optimisations peuvent ne pas s'appliquer"
      return 1
    fi
  else
    warn "⚠️ Impossible de détecter le modèle"
    return 1
  fi
}

check_page_size() {
  log "📏 Vérification page size..."

  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "unknown")
  echo "   Page size actuelle : $page_size bytes"

  if [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB - Incompatible avec PostgreSQL/Supabase"
    echo ""
    echo "🛠️ **Solutions pour corriger le page size** :"
    echo ""
    echo "**Option 1 : Kernel avec 4KB pages (RECOMMANDÉ)**"
    echo "   1. Éditer /boot/firmware/config.txt :"
    echo "      echo 'kernel=kernel8.img' >> /boot/firmware/config.txt"
    echo ""
    echo "   2. Télécharger kernel 4KB :"
    echo "      wget https://github.com/raspberrypi/firmware/raw/master/boot/kernel8.img -O /boot/firmware/kernel8-4k.img"
    echo "      sed -i 's/kernel=kernel8.img/kernel=kernel8-4k.img/' /boot/firmware/config.txt"
    echo ""
    echo "   3. Redémarrer : sudo reboot"
    echo ""
    echo "**Option 2 : Utiliser postgres:15-alpine**"
    echo "   - Modifier docker-compose.yml pour utiliser postgres:15-alpine"
    echo "   - Moins d'optimisations Supabase mais compatible 16KB"
    echo ""
    return 1
  elif [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL"
    return 0
  else
    warn "⚠️ Page size non standard ($page_size) - À surveiller"
    return 2
  fi
}

install_entropy_tools() {
  log "🎲 Installation outils entropie..."

  # Vérifier entropie actuelle
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  echo "   Entropie actuelle : $entropy bits"

  if [[ $entropy -lt 2000 ]]; then
    log "   Installation haveged pour améliorer entropie..."

    if ! command -v haveged >/dev/null; then
      apt update -qq
      apt install -y haveged
      ok "✅ haveged installé"
    else
      ok "✅ haveged déjà présent"
    fi

    # Configurer et démarrer
    systemctl enable haveged >/dev/null 2>&1
    systemctl start haveged >/dev/null 2>&1

    # Attendre amélioration
    sleep 3
    local new_entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
    echo "   Nouvelle entropie : $new_entropy bits"

    if [[ $new_entropy -gt $entropy ]]; then
      ok "✅ Entropie améliorée (+$((new_entropy - entropy)) bits)"
    else
      warn "⚠️ Pas d'amélioration visible (peut prendre du temps)"
    fi
  else
    ok "✅ Entropie déjà suffisante"
  fi
}

optimize_docker_daemon() {
  log "🐳 Optimisation Docker pour Pi 5..."

  local docker_config="/etc/docker/daemon.json"
  local backup_config="${docker_config}.backup.$(date +%Y%m%d_%H%M%S)"

  # Backup configuration existante
  if [[ -f "$docker_config" ]]; then
    cp "$docker_config" "$backup_config"
    log "   Sauvegarde : $backup_config"
  fi

  # Configuration optimisée pour Pi 5
  cat > "$docker_config" << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "runc"
    }
  },
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  },
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3,
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF

  ok "✅ Configuration Docker optimisée"

  # Redémarrer Docker
  log "   Redémarrage service Docker..."
  systemctl restart docker

  # Attendre que Docker soit prêt
  local retry_count=0
  while ! docker info >/dev/null 2>&1 && [[ $retry_count -lt 30 ]]; do
    sleep 1
    ((retry_count++))
  done

  if docker info >/dev/null 2>&1; then
    ok "✅ Docker redémarré avec succès"
  else
    error "❌ Erreur redémarrage Docker"
    return 1
  fi
}

configure_system_limits() {
  log "⚙️ Configuration limites système..."

  # Augmenter limites pour PostgreSQL/Supabase
  local limits_config="/etc/security/limits.conf"
  local limits_backup="${limits_config}.backup.$(date +%Y%m%d_%H%M%S)"

  cp "$limits_config" "$limits_backup"

  # Ajouter limites si pas déjà présentes
  if ! grep -q "# Supabase optimizations" "$limits_config"; then
    cat >> "$limits_config" << 'EOF'

# Supabase optimizations for Raspberry Pi 5
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
root soft nofile 65536
root hard nofile 65536
postgres soft nofile 65536
postgres hard nofile 65536
EOF
    ok "✅ Limites système configurées"
  else
    ok "✅ Limites déjà configurées"
  fi

  # Configuration sysctl
  local sysctl_config="/etc/sysctl.d/99-supabase-pi5.conf"

  cat > "$sysctl_config" << 'EOF'
# Supabase optimizations for Raspberry Pi 5

# Memory management
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5

# Network optimizations
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000

# File system
fs.file-max=2097152
fs.inotify.max_user_watches=524288

# PostgreSQL optimizations
kernel.shmmax=68719476736
kernel.shmall=4294967296
EOF

  sysctl -p "$sysctl_config" >/dev/null 2>&1
  ok "✅ Paramètres kernel configurés"
}

optimize_memory_usage() {
  log "🧠 Optimisation utilisation mémoire..."

  # Configuration swap pour Pi 5 16GB
  local total_mem=$(free -m | awk '/^Mem:/{print $2}')
  echo "   Mémoire totale : ${total_mem}MB"

  if [[ $total_mem -gt 8000 ]]; then
    log "   Configuration pour Pi 5 16GB..."

    # Réduire swap (16GB RAM = moins besoin swap)
    if [[ -f /etc/dphys-swapfile ]]; then
      sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
      systemctl restart dphys-swapfile >/dev/null 2>&1 || true
      ok "   ✅ Swap réduit à 1GB"
    fi

    # Optimiser paramètres mémoire
    echo 'vm.overcommit_memory=2' >> /etc/sysctl.d/99-supabase-pi5.conf
    echo 'vm.overcommit_ratio=80' >> /etc/sysctl.d/99-supabase-pi5.conf

    sysctl vm.overcommit_memory=2 >/dev/null 2>&1
    sysctl vm.overcommit_ratio=80 >/dev/null 2>&1

    ok "   ✅ Gestion mémoire optimisée pour 16GB"
  else
    warn "   ⚠️ Mémoire < 8GB - Optimisations standards appliquées"
  fi
}

create_monitoring_script() {
  log "📊 Création script de monitoring..."

  local monitoring_script="/usr/local/bin/supabase-monitor-pi5"

  cat > "$monitoring_script" << 'EOF'
#!/bin/bash

# Monitoring Supabase sur Raspberry Pi 5

echo "==================== MONITORING SUPABASE PI5 ===================="
echo "📅 $(date)"
echo ""

# Température CPU
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
  temp=$(cat /sys/class/thermal/thermal_zone0/temp)
  temp_c=$((temp / 1000))
  echo "🌡️ Température CPU : ${temp_c}°C"
  if [[ $temp_c -gt 70 ]]; then
    echo "   ⚠️ Température élevée - surveillez le refroidissement"
  fi
fi

# Utilisation mémoire
echo ""
echo "🧠 Utilisation mémoire :"
free -h | grep -E "Mem:|Swap:"

# Entropie
entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
echo ""
echo "🎲 Entropie système : $entropy bits"
if [[ $entropy -lt 1000 ]]; then
  echo "   ⚠️ Entropie faible - considérez installer haveged"
fi

# État Docker
echo ""
echo "🐳 Conteneurs actifs :"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker non accessible"

# Page size
page_size=$(getconf PAGESIZE 2>/dev/null || echo "unknown")
echo ""
echo "📏 Page size : $page_size bytes"
if [[ "$page_size" == "16384" ]]; then
  echo "   ⚠️ 16KB - Peut causer des problèmes PostgreSQL"
fi

echo "=============================================================="
EOF

  chmod +x "$monitoring_script"
  ok "✅ Script monitoring créé : $monitoring_script"

  # Créer alias pratique
  if ! grep -q "alias supabase-monitor" ~/.bashrc 2>/dev/null; then
    echo "alias supabase-monitor='$monitoring_script'" >> ~/.bashrc
    echo "alias supabase-monitor='$monitoring_script'" >> "/home/$SUDO_USER/.bashrc" 2>/dev/null || true
  fi

  ok "✅ Alias 'supabase-monitor' créé"
}

main() {
  require_root

  echo "==================== 🥧 OPTIMISATIONS PI5 ===================="
  log "🚀 Optimisations spécifiques Raspberry Pi 5 pour Supabase"
  echo ""

  check_raspberry_pi
  echo ""

  check_page_size
  page_size_status=$?
  echo ""

  install_entropy_tools
  echo ""

  optimize_docker_daemon
  echo ""

  configure_system_limits
  echo ""

  optimize_memory_usage
  echo ""

  create_monitoring_script

  # Résumé
  echo ""
  echo "==================== 📊 RÉSUMÉ OPTIMISATIONS ===================="

  if [[ $page_size_status -eq 0 ]]; then
    ok "🟢 Pi 5 optimisé et compatible"
    echo ""
    echo "🚀 **Prochaines étapes** :"
    echo "   1. Redémarrer le système : sudo reboot"
    echo "   2. Installer Supabase avec setup-week2-improved.sh"
    echo "   3. Utiliser 'supabase-monitor' pour surveillance"
  elif [[ $page_size_status -eq 1 ]]; then
    warn "🔴 Page size 16KB détecté - Action requise"
    echo ""
    echo "⚠️ **IMPORTANT** : Corriger le page size avant d'installer Supabase"
    echo "   Voir les solutions affichées plus haut"
  else
    ok "🟡 Optimisations appliquées - À tester"
  fi

  echo "=============================================================="
}

main "$@"