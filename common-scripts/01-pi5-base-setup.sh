#!/usr/bin/env bash
# =============================================================================
# Pi 5 Base Setup - Prerequisites for All Stacks
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-20
# Author: PI5-SETUP Project
# Usage: curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-pi5-base-setup.sh | sudo bash
# =============================================================================
# Description:
#   Script générique de préparation Pi 5 pour Docker, sécurité et optimisations.
#   Compatible avec tous les stacks (Supabase, PocketBase, Nginx, etc.)
#
# Installe:
#   - Docker + Docker Compose + Portainer
#   - UFW Firewall (SSH, HTTP, HTTPS)
#   - Fail2ban anti-bruteforce
#   - Optimisations Pi 5 (page size 4KB, cgroups, ulimits)
#   - Outils monitoring (htop, iotop, ncdu)
# =============================================================================

set -euo pipefail

log()  { echo -e "\033[1;36m[SETUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN] \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]   \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Variables globales
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/pi5-base-setup-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"
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

check_dependencies() {
  log "🔍 Vérification des dépendances..."
  local dependencies=("curl" "git" "openssl" "gpg" "apt" "systemctl" "ufw")
  local missing_deps=()

  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [ ${#missing_deps[@]} -gt 0 ]; then
    error "❌ Dépendances manquantes : ${missing_deps[*]}. Veuillez les installer."
    log "   Suggestion: sudo apt update && sudo apt install -y curl git openssl gpg ufw"
    exit 1
  fi
  ok "✅ Toutes les dépendances sont présentes."
}

setup_logging() {
  exec 1> >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE" >&2)

  log "=== Pi 5 Base Setup - $(date) ==="
  log "Version: $SCRIPT_VERSION"
  log "Mode: $MODE"
  log "Utilisateur cible: $TARGET_USER"
  log "Log file: $LOG_FILE"
}

check_pi5_compatibility() {
  log "🔍 Vérification compatibilité Pi 5..."

  # Vérifier architecture
  local arch=$(uname -m)
  if [[ "$arch" != "aarch64" ]]; then
    error "❌ Architecture $arch non supportée (Pi 5 requis: aarch64)"
    exit 1
  fi

  # Vérifier RAM
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  if [[ $ram_gb -ge 15 ]]; then
    ok "RAM détectée: ${ram_gb}GB - Excellent pour services Docker"
  elif [[ $ram_gb -ge 8 ]]; then
    ok "RAM détectée: ${ram_gb}GB - Suffisant pour la plupart des stacks"
  else
    warn "RAM détectée: ${ram_gb}GB - Minimum requis, limiter le nombre de services"
  fi

  # Vérifier espace disque
  local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $disk_gb -ge 20 ]]; then
    ok "Espace disque: ${disk_gb}GB disponibles - Excellent"
  else
    warn "Espace disque: ${disk_gb}GB - Attention, minimum 20GB recommandé"
  fi

  # **CRITIQUE: Vérifier page size (problème principal Pi 5)**
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  log "Page size kernel : $page_size bytes"

  if [[ "$page_size" == "16384" ]]; then
    warn "⚠️ Page size 16KB détectée - INCOMPATIBLE avec PostgreSQL"
    log "   Configuration automatique kernel 4KB..."

    # Correction automatique page size
    fix_page_size_pi5
  elif [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL et autres DB"
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
      echo "# Kernel 4KB pour compatibilité PostgreSQL (Pi5 Base Setup)" >> "$config_file"
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

  # Créer un fichier temporaire sécurisé
  local tmp_file
  tmp_file=$(mktemp)

  # Écrire la configuration dans le fichier temporaire
  cat > "$tmp_file" << 'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
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

  # Si l'écriture a réussi, déplacer le fichier temporaire à sa destination finale
  if [ $? -eq 0 ]; then
    # Sauvegarder l'ancienne configuration
    [ -f /etc/docker/daemon.json ] && mv /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%Y%m%d_%H%M%S)
    mv "$tmp_file" /etc/docker/daemon.json
    chmod 644 /etc/docker/daemon.json
    ok "✅ Configuration Docker optimisée (écriture atomique, ulimits 262144)"
  else
    error "❌ Échec de la création du fichier de configuration Docker temporaire."
    rm -f "$tmp_file" # Nettoyer
    return 1
  fi
}

install_portainer() {
  log "🎛️ Installation Portainer (interface Docker)..."

  # Port 8080 (standard alternatif pour éviter conflits avec autres services)
  local portainer_port=8080

  log "   Port Portainer: $portainer_port"

  # Créer volume Portainer
  docker volume create portainer_data 2>/dev/null || true

  # Arrêter ancien conteneur s'il existe
  docker stop portainer 2>/dev/null || true
  docker rm portainer 2>/dev/null || true

  # Télécharger la dernière version
  log "   Téléchargement dernière version Portainer..."
  docker pull portainer/portainer-ce:latest

  # Lancer Portainer sur port correct (LOCALHOST ONLY pour sécurité)
  docker run -d \
    --name portainer \
    --restart=always \
    -p "127.0.0.1:${portainer_port}:9000" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest

  local ip=$(hostname -I | awk '{print $1}')
  log "   Interface Portainer: http://localhost:${portainer_port} (localhost only)"
  log "   Accès distant: ssh -L ${portainer_port}:localhost:${portainer_port} $(whoami)@${ip}"

  ok "✅ Portainer installé (port $portainer_port, localhost only)"
}

configure_firewall() {
  log "🔥 Configuration pare-feu UFW (intelligent & idempotent)..."

  # Désactiver temporairement si actif (éviter lockout pendant reset)
  if ufw status | grep -q "Status: active"; then
    log "   UFW actuellement actif, désactivation temporaire..."
    ufw --force disable >/dev/null 2>&1
  fi

  # Reset et configuration par défaut
  ufw --force reset >/dev/null 2>&1
  ufw default deny incoming >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1

  # SSH (CRITIQUE - toujours en premier)
  log "   Autorisation SSH (port $SSH_PORT) avec rate limiting..."
  ufw allow "$SSH_PORT"/tcp comment "SSH" >/dev/null 2>&1
  ufw limit "$SSH_PORT"/tcp >/dev/null 2>&1

  # Ports web standards (pour serveurs web, reverse proxies, etc.)
  log "   Autorisation HTTP/HTTPS..."
  ufw allow 80/tcp comment "HTTP" >/dev/null 2>&1
  ufw allow 443/tcp comment "HTTPS" >/dev/null 2>&1

  # Note: Ports spécifiques aux services (Supabase, PocketBase, etc.)
  # seront ouverts par les scripts de déploiement respectifs

  # Activer UFW
  log "   Activation UFW..."
  echo "y" | ufw enable >/dev/null 2>&1

  # Vérification critique SSH
  if ! ufw status | grep -qE "$SSH_PORT.*ALLOW|$SSH_PORT.*LIMIT"; then
    error "❌ ALERTE: SSH (port $SSH_PORT) non autorisé dans UFW!"
    ufw allow "$SSH_PORT"/tcp comment "SSH" >/dev/null 2>&1
  fi

  ok "✅ Pare-feu UFW configuré (SSH protégé, HTTP/HTTPS autorisés)"
}

configure_fail2ban() {
  log "🛡️ Configuration Fail2ban anti-bruteforce..."

  # Créer un fichier temporaire sécurisé
  local tmp_file
  tmp_file=$(mktemp)

  # Écrire la configuration dans le fichier temporaire
  cat > "$tmp_file" << EOF
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

  # Si l'écriture a réussi, déplacer le fichier temporaire à sa destination finale
  if [ $? -eq 0 ]; then
    # Sauvegarder l'ancienne configuration
    [ -f /etc/fail2ban/jail.local ] && mv /etc/fail2ban/jail.local /etc/fail2ban/jail.local.bak.$(date +%Y%m%d_%H%M%S)
    mv "$tmp_file" /etc/fail2ban/jail.local
    chmod 644 /etc/fail2ban/jail.local

    systemctl enable fail2ban
    systemctl restart fail2ban
    ok "✅ Configuration Fail2ban avec écriture atomique"
  else
    error "❌ Échec de la création du fichier de configuration Fail2ban temporaire."
    rm -f "$tmp_file"
    return 1
  fi

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

configure_entropy_sources() {
  log "🎲 Configuration sources d'entropie Pi 5..."

  # Préférer rng-tools sur Pi 5 (recommandation 2025 pour HWRNG)
  log "   Installation rng-tools pour hardware RNG..."
  apt update && apt install -y rng-tools-debian 2>/dev/null || apt install -y rng-tools

  # Configuration explicite pour Pi 5 HWRNG
  if [[ -f "/etc/default/rng-tools-debian" ]]; then
    echo 'HRNGDEVICE=/dev/hwrng' > /etc/default/rng-tools-debian
    log "   Configuré pour utiliser /dev/hwrng Pi 5"
  fi

  # Test performance HWRNG
  log "   Test hardware RNG..."
  if [[ -c "/dev/hwrng" ]] && timeout 5 dd if=/dev/hwrng of=/dev/null bs=1 count=1024 2>/dev/null; then
    ok "✅ Hardware RNG fonctionnel"
    # Désactiver haveged si présent
    if systemctl is-enabled haveged >/dev/null 2>&1; then
      log "   Désactivation haveged (HWRNG prioritaire)"
      systemctl disable --now haveged 2>/dev/null || true
    fi
    # Démarrer rng-tools
    if [[ -f "/etc/init.d/rng-tools-debian" ]]; then
      /etc/init.d/rng-tools-debian start 2>/dev/null || true
      update-rc.d rng-tools-debian enable 2>/dev/null || true
    else
      systemctl enable --now rngd.service 2>/dev/null || true
    fi
  else
    warn "⚠️ /dev/hwrng non fonctionnel - fallback haveged"
    apt install -y haveged
    systemctl enable --now haveged 2>/dev/null
    ok "✅ Haveged activé comme fallback"
  fi

  # Vérifier entropie finale
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -ge 1000 ]]; then
    ok "✅ Entropie système: $entropy bits (optimal)"
  elif [[ $entropy -ge 256 ]]; then
    ok "✅ Entropie système: $entropy bits (suffisant)"
  else
    warn "⚠️ Entropie faible: $entropy bits - peut affecter JWT"
  fi

  # Vérifier que le hardware RNG est disponible
  if [[ -c "/dev/hwrng" ]]; then
    ok "✅ Hardware RNG Pi 5 configuré et accessible"
  else
    warn "⚠️ /dev/hwrng non accessible - vérifier le kernel"
  fi
}

configure_cgroup_memory() {
  log "🎛️ Configuration cgroups memory pour Docker..."

  # Détection automatique du chemin cmdline.txt (2025-ready)
  local cmdline_file=""
  if [[ -f "/boot/cmdline.txt" ]]; then
    cmdline_file="/boot/cmdline.txt"
  elif [[ -f "/boot/firmware/cmdline.txt" ]]; then
    cmdline_file="/boot/firmware/cmdline.txt"
  else
    warn "⚠️ Fichier cmdline.txt non trouvé - cgroups non configurés"
    return 1
  fi

  log "   Fichier boot: $cmdline_file"

  # Vérifier kernel version pour bug 6.12
  local kernel_version=$(uname -r | cut -d. -f1-2)
  if [[ "$kernel_version" == "6.12" ]]; then
    warn "⚠️ Kernel 6.12 détecté - bug cgroup memory connu"
    log "   Les warnings Docker peuvent persister (fonctionnel malgré tout)"
  fi

  # Supprimer paramètres de désactivation (si présents)
  sed -i 's/ cgroup_disable=memory//g' "$cmdline_file"

  # Ajouter paramètres cgroup si absents (sur même ligne)
  if ! grep -q 'cgroup_enable=memory' "$cmdline_file"; then
    sed -i 's/$/ cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1/' "$cmdline_file"
    log "   Paramètres cgroup ajoutés à cmdline.txt"
  else
    log "   Paramètres cgroup déjà présents"
    # Vérifier si cpuset est manquant (ajout récent)
    if ! grep -q 'cgroup_enable=cpuset' "$cmdline_file"; then
      sed -i 's/cgroup_enable=memory/cgroup_enable=cpuset cgroup_enable=memory/' "$cmdline_file"
      log "   Paramètre cpuset ajouté aux cgroups existants"
    fi
  fi

  # Configuration Docker daemon pour cgroups v2 + ulimits optimales
  local docker_daemon="/etc/docker/daemon.json"
  if [[ ! -f "$docker_daemon" ]]; then
    cat > "$docker_daemon" << 'DOCKER_DAEMON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Soft": 262144,
      "Hard": 262144
    }
  }
}
DOCKER_DAEMON
    log "   Configuration Docker daemon créée avec ulimits optimisées"
  else
    # Merger les ulimits si daemon.json existe déjà
    if ! grep -q "default-ulimits" "$docker_daemon"; then
      log "   Ajout ulimits à daemon.json existant..."
      # Backup
      cp "$docker_daemon" "${docker_daemon}.backup.$(date +%Y%m%d_%H%M%S)"
      # Ajouter les ulimits avant la dernière }
      sed -i 's/}$/  ,"default-ulimits": {\n    "nofile": {\n      "Name": "nofile",\n      "Soft": 262144,\n      "Hard": 262144\n    }\n  }\n}/' "$docker_daemon"
      log "   Ulimits ajoutées au daemon.json existant"
    fi
  fi

  ok "✅ Cgroups memory configurés (redémarrage requis)"

  # Note importante sur le redémarrage
  if [[ "$kernel_version" == "6.12" ]]; then
    log "   ⚠️ Note kernel 6.12: Les warnings Docker peuvent persister"
    log "   ⚠️ Les services Docker fonctionneront correctement malgré les warnings"
  fi
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

  # Vérifier si clés SSH existent
  if [[ ! -f "/home/$TARGET_USER/.ssh/authorized_keys" ]] || [[ ! -s "/home/$TARGET_USER/.ssh/authorized_keys" ]]; then
    warn "⚠️ Aucune clé SSH configurée pour $TARGET_USER"
    log "   Configurez une clé SSH avant de durcir :"
    log "   1. Sur votre machine locale : ssh-copy-id $TARGET_USER@$(hostname -I | awk '{print $1}')"
    log "   2. Vérifiez : cat /home/$TARGET_USER/.ssh/authorized_keys"
    log "   Durcissement SSH ignoré pour éviter blocage"
    return 1
  fi

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
    ok "✅ Installation Base Setup réussie"
  else
    error "❌ Problèmes détectés"
    return 1
  fi
}

show_summary() {
  local ip=$(hostname -I | awk '{print $1}')
  local page_size=$(getconf PAGESIZE)

  echo ""
  echo "==================== 🎉 PI5 BASE SETUP TERMINÉ ===================="
  echo ""
  echo "✅ **Installation réussie** :"
  echo "   🐳 Docker + Docker Compose : OK"
  echo "   🎛️ Portainer : http://$ip:8080"
  echo "   🔥 UFW Firewall : Configuré (SSH, HTTP, HTTPS)"
  echo "   🛡️ Fail2ban : Actif"
  echo "   📊 Monitoring : htop, iotop, ncdu"
  echo ""

  if [[ "$page_size" == "4096" ]]; then
    echo "✅ **Page size** : 4KB (compatible PostgreSQL & autres DB)"
  else
    echo "⚠️ **Page size** : $page_size - REDÉMARRAGE REQUIS"
    echo "   Commande : sudo reboot"
  fi

  echo ""
  echo "🎯 **Optimisations Pi 5** :"
  echo "   ⚡ RAM optimisée pour services Docker"
  echo "   🔧 Limites système augmentées"
  echo "   🐳 Docker configuré ARM64"
  echo "   🎮 GPU memory : ${GPU_MEM_SPLIT}MB"
  echo ""

  echo "🚀 **Prochaines étapes - Déployer vos services** :"
  echo ""
  echo "   Exemples de stacks disponibles :"
  echo ""
  echo "   📦 Supabase (PostgreSQL + Auth + Storage) :"
  echo "      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash"
  echo ""
  echo "   📦 PocketBase (Backend léger) :"
  echo "      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pocketbase/scripts/01-pocketbase-deploy.sh | sudo bash"
  echo ""
  echo "   🌐 Nginx (Reverse Proxy) :"
  echo "      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-nginx-deploy.sh | sudo bash"
  echo ""
  echo "   🔒 Vaultwarden (Gestionnaire de mots de passe) :"
  echo "      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vaultwarden/scripts/01-vaultwarden-deploy.sh | sudo bash"
  echo ""

  echo "📚 **Documentation complète :**"
  echo "   https://github.com/iamaketechnology/pi5-setup"
  echo ""
  echo "📋 **Log complet** : $LOG_FILE"
  echo "==============================================================="
  echo ""

  if [[ "$TARGET_USER" != "root" ]]; then
    log "💡 Redémarrer la session utilisateur pour groupe docker"
  fi

  # Demander confirmation de redémarrage (toujours requis pour cgroups)
  echo ""
  echo -e "\033[1;33m⚠️  REDÉMARRAGE REQUIS POUR FINALISER L'INSTALLATION\033[0m"
  echo ""
  if [[ "$page_size" != "4096" ]]; then
    echo "   🔧 Activation noyau 4KB pour PostgreSQL"
  fi
  echo "   🎛️  Activation cgroups memory pour Docker"
  echo "   ⚡ Finalisation optimisations Pi 5"
  echo ""
  read -p "Voulez-vous redémarrer maintenant ? [y/N] : " -n 1 -r
  echo ""
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔄 Redémarrage en cours..."
    sleep 3
    reboot
  else
    echo "⏸️  Redémarrage reporté. N'oubliez pas de redémarrer avec : sudo reboot"
    echo "   Puis déploiez vos services après reconnexion."
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
  check_dependencies

  echo ""
  log "🚀 Démarrage installation Pi 5 Base Setup"
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

  configure_entropy_sources
  echo ""

  configure_cgroup_memory
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

# =============================================================================
# PROCHAINES ÉTAPES
# =============================================================================
#
# 1. Redémarrer le Pi : sudo reboot
#
# 2. Après redémarrage, déployer vos services :
#
#    - Supabase :
#      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
#
#    - PocketBase :
#      curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pocketbase/scripts/01-pocketbase-deploy.sh | sudo bash
#
#    - Autres stacks : voir https://github.com/iamaketechnology/pi5-setup
#
# =============================================================================

main "$@"