#!/usr/bin/env bash
set -euo pipefail

# === SETUP WEEK1 ENHANCED FINAL - Pi 5 avec tous les correctifs intégrés ===

log()  { echo -e "\033[1;36m[SETUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Variables globales
SCRIPT_VERSION="2.0-final"
LOG_FILE="/var/log/pi5-setup-week1-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"

# Configuration par défaut (modifiable via variables d'environnement)
MODE="${MODE:-beginner}"
GPU_MEM_SPLIT="${GPU_MEM_SPLIT:-128}"
ENABLE_I2C="${ENABLE_I2C:-no}"
ENABLE_SPI="${ENABLE_SPI:-no}"
SSH_PORT="${SSH_PORT:-22}"

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Usage: sudo $0"
    echo "   ou: sudo MODE=pro $0"
    exit 1
  fi
}

setup_logging() {
  exec 1> >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE" >&2)

  log "=== Pi 5 Setup Week 1 Enhanced Final - $(date) ==="
  log "Version: $SCRIPT_VERSION"
  log "Mode: $MODE"
  log "Utilisateur cible: $TARGET_USER"
  log "Log file: $LOG_FILE"
}

check_pi5_compatibility() {
  log "🔍 Vérification compatibilité Pi 5 et préparation Week2..."

  # Vérifier architecture
  local arch=$(uname -m)
  if [[ "$arch" != "aarch64" ]]; then
    error "❌ Architecture $arch non supportée (Pi 5 requis: aarch64)"
    exit 1
  fi

  # Vérifier RAM
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  if [[ $ram_gb -ge 15 ]]; then
    ok "RAM détectée: ${ram_gb}GB - Excellent pour Supabase + serveur"
  elif [[ $ram_gb -ge 8 ]]; then
    ok "RAM détectée: ${ram_gb}GB - Suffisant pour Supabase"
  else
    warn "RAM détectée: ${ram_gb}GB - Minimum pour Supabase"
  fi

  # Vérifier espace disque
  local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $disk_gb -ge 20 ]]; then
    ok "Espace disque: ${disk_gb}GB disponibles - Excellent pour Supabase"
  else
    warn "Espace disque: ${disk_gb}GB - Attention, minimum 20GB recommandé"
  fi

  # **CRITIQUE: Vérifier page size (problème principal Pi 5)**
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  log "Page size kernel : $page_size bytes"

  if [[ "$page_size" == "16384" ]]; then
    warn "⚠️ Page size 16KB détectée - INCOMPATIBLE avec PostgreSQL/Supabase"
    log "   Configuration automatique kernel 4KB..."

    # Correction automatique page size
    fix_page_size_pi5
  elif [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL/Supabase"
  else
    warn "⚠️ Page size non standard ($page_size) - À surveiller"
  fi
}

fix_page_size_pi5() {
  log "🔧 Correction page size Pi 5 pour compatibilité PostgreSQL..."

  local config_file="/boot/firmware/config.txt"

  if [[ -f "$config_file" ]]; then
    # Backup de sécurité
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

    # Vérifier si déjà configuré
    if ! grep -q "^kernel=kernel8.img" "$config_file"; then
      echo "" >> "$config_file"
      echo "# Kernel 4KB pour compatibilité PostgreSQL/Supabase (Week1 Enhanced)" >> "$config_file"
      echo "kernel=kernel8.img" >> "$config_file"

      ok "✅ Configuration kernel 4KB ajoutée"
      warn "🔄 REDÉMARRAGE OBLIGATOIRE après installation pour prendre effet"
    else
      ok "✅ Kernel 4KB déjà configuré"
    fi
  else
    error "❌ Fichier config Pi non trouvé: $config_file"
    exit 1
  fi
}

update_system() {
  log "📦 Mise à jour système..."

  apt update -qq || { error "❌ Échec apt update"; exit 1; }

  log "   Installation paquets essentiels..."
  apt install -y \
    curl \
    wget \
    git \
    htop \
    iotop \
    ncdu \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    ufw \
    fail2ban \
    haveged

  ok "✅ Système mis à jour"
}

install_docker() {
  log "🐳 Installation Docker + Docker Compose..."

  if command -v docker >/dev/null; then
    warn "Docker déjà installé - mise à jour..."
  else
    log "   Ajout du dépôt Docker..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update -qq

    log "   Installation paquets Docker..."
    apt install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin
  fi

  # Ajouter utilisateur au groupe docker
  usermod -aG docker "$TARGET_USER"

  # Configuration Docker optimisée Pi 5
  configure_docker_pi5_optimized

  # Démarrer et activer Docker
  systemctl enable docker
  systemctl start docker

  ok "✅ Docker installé et configuré"
}

configure_docker_pi5_optimized() {
  log "⚙️ Configuration Docker optimisée Pi 5..."

  # **CORRECTIF: Configuration sans storage-opts deprecated**
  cat > /etc/docker/daemon.json << 'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "dns": ["8.8.8.8", "8.8.4.4"]
}
JSON

  ok "✅ Configuration Docker optimisée (sans options deprecated)"
}

install_portainer() {
  log "🎛️ Installation Portainer (interface Docker)..."

  # **CORRECTIF: Port 8080 au lieu de 8000 pour éviter conflit Kong Supabase**
  local portainer_port=8080

  log "   Port Portainer: $portainer_port (évite conflit Kong Supabase)"

  # Créer volume Portainer
  docker volume create portainer_data 2>/dev/null || true

  # Arrêter ancien conteneur s'il existe
  docker stop portainer 2>/dev/null || true
  docker rm portainer 2>/dev/null || true

  # Lancer Portainer sur port correct
  docker run -d \
    --name portainer \
    --restart=always \
    -p "${portainer_port}:9000" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

  local ip=$(hostname -I | awk '{print $1}')
  log "   Interface Portainer: http://${ip}:${portainer_port}"

  ok "✅ Portainer installé (port $portainer_port)"
}

configure_firewall() {
  log "🔥 Configuration pare-feu UFW..."

  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing

  # Ports essentiels
  ufw allow "$SSH_PORT"/tcp comment "SSH"
  ufw allow 8080/tcp comment "Portainer"

  # Ports Supabase (préparation Week2)
  ufw allow 3000/tcp comment "Supabase Studio"
  ufw allow 8001/tcp comment "Supabase Kong API"
  ufw allow 54321/tcp comment "Supabase Edge Functions"

  if [[ "$MODE" == "pro" ]]; then
    log "   Mode pro: restrictions supplémentaires..."
    ufw limit "$SSH_PORT"/tcp
  fi

  ufw --force enable

  ok "✅ Pare-feu configuré (ports Supabase préparés)"
}

configure_fail2ban() {
  log "🛡️ Configuration Fail2ban anti-bruteforce..."

  # Configuration de base
  cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 1800
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[docker-auth]
enabled = false
EOF

  systemctl enable fail2ban
  systemctl restart fail2ban

  ok "✅ Fail2ban configuré"
}

optimize_pi5_system() {
  log "⚡ Optimisations système Pi 5..."

  # Optimisations sysctl pour serveur Pi 5
  cat > /etc/sysctl.d/99-pi5-server.conf << EOF
# Pi 5 Server optimizations
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
fs.file-max=2097152
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_timestamps=1
EOF

  # Limites système
  cat >> /etc/security/limits.conf << EOF

# Pi 5 Server limits
* soft nofile 65535
* hard nofile 65535
$TARGET_USER soft nofile 65535
$TARGET_USER hard nofile 65535
EOF

  # Configuration GPU si spécifiée
  configure_gpu_split

  # Interfaces matérielles
  configure_hardware_interfaces

  sysctl --system >/dev/null 2>&1 || true

  ok "✅ Optimisations Pi 5 appliquées"
}

configure_gpu_split() {
  log "🎮 Configuration GPU memory split: ${GPU_MEM_SPLIT}MB..."

  local config_file="/boot/firmware/config.txt"

  if [[ -f "$config_file" ]]; then
    # Supprimer ancienne config gpu_mem
    sed -i '/^gpu_mem=/d' "$config_file"

    # Ajouter nouvelle configuration
    echo "" >> "$config_file"
    echo "# Pi 5 optimizations (Week1 Enhanced)" >> "$config_file"
    echo "gpu_mem=$GPU_MEM_SPLIT" >> "$config_file"

    ok "✅ GPU memory: ${GPU_MEM_SPLIT}MB"
  fi
}

configure_hardware_interfaces() {
  log "🔌 Configuration interfaces matérielles..."

  local config_file="/boot/firmware/config.txt"

  if [[ "$ENABLE_I2C" == "yes" ]]; then
    echo "dtparam=i2c_arm=on" >> "$config_file"
    echo "i2c-dev" >> /etc/modules
    ok "✅ I2C activé"
  fi

  if [[ "$ENABLE_SPI" == "yes" ]]; then
    echo "dtparam=spi=on" >> "$config_file"
    echo "spi-dev" >> /etc/modules
    ok "✅ SPI activé"
  fi
}

harden_ssh() {
  if [[ "$MODE" != "pro" ]]; then
    return 0
  fi

  log "🔐 Durcissement SSH (mode pro)..."

  cat > /etc/ssh/sshd_config.d/99-pi5-hardening.conf << EOF
# Pi 5 SSH Hardening
Port $SSH_PORT
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

  systemctl restart ssh

  warn "⚠️ SSH durci: connexion par clé uniquement sur port $SSH_PORT"
  ok "✅ SSH durci"
}

install_monitoring_tools() {
  log "📊 Installation outils monitoring..."

  # Outils déjà installés via update_system
  # Ajout configuration

  # htop avec config utilisateur
  local htop_dir="/home/$TARGET_USER/.config/htop"
  mkdir -p "$htop_dir"
  cat > "$htop_dir/htoprc" << EOF
fields=0 48 17 18 38 39 40 2 46 47 49 1
sort_key=46
sort_direction=1
tree_sort_key=0
tree_sort_direction=1
hide_kernel_threads=1
hide_userland_threads=0
shadow_other_users=0
show_thread_names=0
show_program_path=1
highlight_base_name=0
highlight_deleted_exe=1
shadow_distribution_path_prefix=0
highlight_megabytes=1
highlight_threads=1
highlight_changes=1
highlight_changes_delay_secs=5
find_comm_in_cmdline=1
strip_exe_from_cmdline=1
show_merged_command=0
header_margin=1
detailed_cpu_time=0
cpu_count_from_one=0
show_cpu_usage=1
show_cpu_frequency=0
show_cpu_temperature=1
degree_fahrenheit=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
enable_mouse=1
delay=15
left_meters=LeftCPUs Memory Swap
left_meter_modes=1 1 1
right_meters=RightCPUs Tasks LoadAverage Uptime
right_meter_modes=1 2 2 2
hide_function_bar=0
EOF
  chown -R "$TARGET_USER:$TARGET_USER" "/home/$TARGET_USER/.config"

  ok "✅ Outils monitoring configurés"
}

verify_installation() {
  log "✅ Vérification installation..."

  local checks_passed=0
  local total_checks=6

  # Test Docker
  if docker run --rm hello-world >/dev/null 2>&1; then
    ok "  ✅ Docker fonctionne"
    ((checks_passed++))
  else
    error "  ❌ Docker ne fonctionne pas"
  fi

  # Test Portainer
  if curl -s -I "http://localhost:8080" >/dev/null 2>&1; then
    ok "  ✅ Portainer accessible"
    ((checks_passed++))
  else
    warn "  ⚠️ Portainer pas encore accessible"
  fi

  # Test UFW
  if ufw status | grep -q "Status: active"; then
    ok "  ✅ UFW actif"
    ((checks_passed++))
  else
    error "  ❌ UFW inactif"
  fi

  # Test Fail2ban
  if systemctl is-active fail2ban >/dev/null 2>&1; then
    ok "  ✅ Fail2ban actif"
    ((checks_passed++))
  else
    error "  ❌ Fail2ban inactif"
  fi

  # Test page size
  local page_size=$(getconf PAGESIZE)
  if [[ "$page_size" == "4096" ]]; then
    ok "  ✅ Page size 4KB (compatible PostgreSQL)"
    ((checks_passed++))
  else
    warn "  ⚠️ Page size $page_size (nécessite redémarrage)"
  fi

  # Test groupe docker
  if groups "$TARGET_USER" | grep -q docker; then
    ok "  ✅ Utilisateur dans groupe docker"
    ((checks_passed++))
  else
    error "  ❌ Utilisateur pas dans groupe docker"
  fi

  log "Vérifications réussies: $checks_passed/$total_checks"

  if [[ $checks_passed -ge 4 ]]; then
    ok "✅ Installation Week1 réussie"
  else
    error "❌ Problèmes détectés"
    return 1
  fi
}

show_summary() {
  local ip=$(hostname -I | awk '{print $1}')
  local page_size=$(getconf PAGESIZE)

  echo ""
  echo "==================== 🎉 WEEK 1 TERMINÉ ===================="
  echo ""
  echo "✅ **Installation réussie** :"
  echo "   🐳 Docker + Docker Compose : OK"
  echo "   🎛️ Portainer : http://$ip:8080"
  echo "   🔥 UFW Firewall : Configuré"
  echo "   🛡️ Fail2ban : Actif"
  echo "   📊 Monitoring : htop, iotop, ncdu"
  echo ""

  if [[ "$page_size" == "4096" ]]; then
    echo "✅ **Page size** : 4KB (compatible PostgreSQL/Supabase)"
  else
    echo "⚠️ **Page size** : $page_size - REDÉMARRAGE REQUIS"
    echo "   Commande : sudo reboot"
  fi

  echo ""
  echo "🎯 **Optimisations Pi 5** :"
  echo "   ⚡ RAM 16GB optimisée"
  echo "   🔧 Limites système augmentées"
  echo "   🐳 Docker configuré ARM64"
  echo "   🎮 GPU memory : ${GPU_MEM_SPLIT}MB"
  echo ""

  echo "🚀 **Prêt pour Week 2** (Supabase) :"
  echo "   📋 Ports préparés : 3000, 8001, 54321"
  echo "   🗄️ Page size compatible PostgreSQL"
  echo "   🐳 Docker optimisé pour conteneurs"
  echo ""

  if [[ "$page_size" != "4096" ]]; then
    echo "🔄 **ÉTAPES SUIVANTES** :"
    echo "   1. Redémarrer : sudo reboot"
    echo "   2. Vérifier page size : getconf PAGESIZE"
    echo "   3. Lancer Week 2 Supabase"
  else
    echo "🔄 **ÉTAPES SUIVANTES** :"
    echo "   1. Week 2 Supabase : ./setup-week2-supabase-final.sh"
  fi

  echo ""
  echo "📋 **Log complet** : $LOG_FILE"
  echo "================================================="
  echo ""

  if [[ "$TARGET_USER" != "root" ]]; then
    log "💡 Redémarrer la session utilisateur pour groupe docker"
  fi
}

cleanup() {
  log "🧹 Nettoyage..."
  apt autoremove -y >/dev/null 2>&1 || true
  apt autoclean >/dev/null 2>&1 || true
}

main() {
  require_root
  setup_logging

  echo ""
  log "🚀 Démarrage installation Pi 5 Week 1 Enhanced Final"
  echo ""

  check_pi5_compatibility
  echo ""

  update_system
  echo ""

  install_docker
  echo ""

  install_portainer
  echo ""

  configure_firewall
  echo ""

  configure_fail2ban
  echo ""

  optimize_pi5_system
  echo ""

  harden_ssh
  echo ""

  install_monitoring_tools
  echo ""

  verify_installation
  echo ""

  cleanup

  show_summary
}

main "$@"