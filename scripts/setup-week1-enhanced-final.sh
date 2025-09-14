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

      ok "✅ Kernel 4KB configuré"

      # Marquer redémarrage requis
      touch /tmp/pi5-reboot-required
      export REBOOT_REQUIRED=true

    else
      ok "✅ Kernel 4KB déjà configuré"
    fi
  else
    error "❌ Fichier $config_file non trouvé"
    exit 1
  fi
}

update_system() {
  log "📦 MAJ système + paquets utiles pour Pi 5 + préparation Week2..."

  apt update
  apt upgrade -y

  # Paquets essentiels pour serveur + développement
  local essential_packages=(
    # Base système
    "ca-certificates"
    "curl"
    "gnupg"
    "lsb-release"

    # Sécurité
    "ufw"
    "fail2ban"
    "unattended-upgrades"

    # Monitoring et diagnostic
    "htop"
    "iotop"
    "ncdu"
    "tree"

    # Développement
    "git"
    "vim"
    "nano"

    # Pi spécifique
    "rpi-update"

    # Préparation Week2 Supabase
    "haveged"         # Améliore entropie pour Docker/PostgreSQL
    "python3-yaml"    # Pour scripts de configuration
    "netcat-openbsd"  # Tests connectivité
  )

  apt install -y "${essential_packages[@]}"

  # Démarrer haveged immédiatement (critique pour Docker)
  systemctl enable haveged
  systemctl start haveged
  ok "haveged démarré - Entropie améliorée pour Docker/PostgreSQL"
}

apply_system_optimizations() {
  log "⚙️ Application des optimisations Pi 5 + préparation Week2..."

  # Optimisations sysctl pour serveur Pi 5
  cat > /etc/sysctl.d/99-pi5-server.conf << 'EOF'
# Pi 5 Server Optimizations

# Réseau optimisé pour serveur
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000
net.ipv4.tcp_max_syn_backlog=30000
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_keepalive_intvl=60
net.ipv4.tcp_keepalive_probes=3

# Mémoire optimisée pour 16GB Pi 5
vm.swappiness=10
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.vfs_cache_pressure=50

# File descriptors pour serveur/Docker
fs.file-max=2097152
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=256

# Optimisations pour containers Docker
kernel.keys.maxkeys=2000
kernel.keys.maxbytes=2000000
EOF

  # Limites utilisateur pour Docker/PostgreSQL
  cat > /etc/security/limits.d/99-pi5-server.conf << 'EOF'
# Pi 5 Server limits

# Limits pour Docker et PostgreSQL
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768

# Limits spécifiques utilisateur pi
pi soft nofile 65536
pi hard nofile 65536
EOF

  # Appliquer immédiatement
  sysctl --system >/dev/null 2>&1 || true

  ok "Optimisations système configurées"

  # Configuration Pi 5 matériel
  configure_pi5_hardware
}

configure_pi5_hardware() {
  log "🥧 Configuration matérielle Pi 5..."

  local config_file="/boot/firmware/config.txt"

  if [[ -f "$config_file" ]]; then
    # Backup si pas déjà fait
    [[ ! -f "${config_file}.backup.$(date +%Y%m%d)" ]] && cp "$config_file" "${config_file}.backup.$(date +%Y%m%d)"

    # Ajouter optimisations Pi 5 si pas présentes
    if ! grep -q "# Pi 5 optimizations Week1" "$config_file"; then
      cat >> "$config_file" << EOF

# Pi 5 optimizations Week1 Enhanced
gpu_mem=$GPU_MEM_SPLIT
EOF
    fi

    # I2C si demandé
    if [[ "$ENABLE_I2C" == "yes" ]]; then
      if ! grep -q "dtparam=i2c_arm=on" "$config_file"; then
        echo "dtparam=i2c_arm=on" >> "$config_file"
        echo "i2c-dev" >> /etc/modules
      fi
      ok "I2C activé"
    fi

    # SPI si demandé
    if [[ "$ENABLE_SPI" == "yes" ]]; then
      if ! grep -q "dtparam=spi=on" "$config_file"; then
        echo "dtparam=spi=on" >> "$config_file"
      fi
      ok "SPI activé"
    fi

    ok "Optimisations Pi 5 appliquées"
  fi
}

install_docker() {
  log "🐳 Installation Docker CE + Compose v2 optimisé Pi 5 + Supabase..."

  if command -v docker >/dev/null 2>&1; then
    ok "Docker déjà installé."
    return
  fi

  # Ajout dépôt Docker officiel
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  local codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  local arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list

  apt update
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # **CRITIQUE: Configuration Docker corrigée (sans options dépréciées)**
  configure_docker_pi5_optimized

  # Démarrage et permissions
  systemctl enable --now docker
  usermod -aG docker "$TARGET_USER" || true

  ok "Docker installé avec optimisations Pi 5 + Supabase. (Reconnexion requise pour utiliser docker sans sudo.)"
}

configure_docker_pi5_optimized() {
  log "🔧 Configuration Docker optimisée Pi 5 + Supabase (sans options dépréciées)..."

  # Configuration daemon.json CORRIGÉE (problème principal identifié)
  mkdir -p /etc/docker
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

  # Configuration systemd pour Pi 5
  mkdir -p /etc/systemd/system/docker.service.d
  cat > /etc/systemd/system/docker.service.d/override.conf << 'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
LimitNOFILE=1048576
LimitNPROC=1048576
TasksMax=infinity
OOMScoreAdjust=-500
OVERRIDE

  systemctl daemon-reload

  ok "✅ Docker configuré sans options dépréciées"
}

deploy_portainer() {
  log "🎛️ Déploiement Portainer CE sur port 8080 (évite conflit Supabase port 8000)..."

  # Vérifier si Docker est accessible
  if ! docker info >/dev/null 2>&1; then
    warn "Docker non accessible immédiatement - Attente 10s..."
    sleep 10
  fi

  # Créer volume si nécessaire
  docker volume create portainer_data >/dev/null 2>&1 || true

  # Déployer Portainer sur port 8080 (évite conflit port 8000 avec Supabase)
  if ! docker ps --format "{{.Names}}" | grep -q "^portainer$"; then
    docker run -d \
      -p 8080:9000 \
      --name portainer \
      --restart=always \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v portainer_data:/data \
      portainer/portainer-ce:latest

    ok "Portainer déployé sur port 8080"
    log "   Accès: http://$(hostname -I | awk '{print $1}'):8080"
  else
    ok "Portainer déjà déployé."
  fi
}

configure_firewall() {
  log "🔥 Pare-feu UFW (ports optimisés pour Week2)..."

  # Configuration UFW pour serveur
  ufw --force reset

  # Règles par défaut
  ufw default deny incoming
  ufw default allow outgoing

  # SSH (port configurable)
  ufw allow $SSH_PORT/tcp comment "SSH"

  # **PORTS PRÉPARÉS POUR WEEK2 SUPABASE**
  ufw allow 3000/tcp comment "Supabase Studio"
  ufw allow 8000/tcp comment "Supabase API (Kong)"
  ufw allow 8001/tcp comment "Supabase API Alt"
  ufw allow 54321/tcp comment "Supabase Edge Functions"

  # Portainer (port 8080 pour éviter conflit)
  ufw allow 8080/tcp comment "Portainer"

  # Services système
  ufw allow 80/tcp comment "HTTP"
  ufw allow 443/tcp comment "HTTPS"

  # Activer UFW
  ufw --force enable

  ok "UFW activé avec ports préparés pour Week2."
}

configure_fail2ban() {
  log "🛡️ Fail2ban (sshd)..."

  # Configuration fail2ban pour SSH
  cat > /etc/fail2ban/jail.local << 'F2B'
[DEFAULT]
bantime = 600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800
F2B

  # Redémarrer fail2ban
  systemctl enable fail2ban
  systemctl restart fail2ban

  ok "Fail2ban configuré."
}

setup_auto_updates() {
  log "🔄 MAJ sécurité automatiques..."

  # Configuration unattended-upgrades
  cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'UNATT'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}:${distro_codename}-updates";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UNATT

  systemctl enable unattended-upgrades

  ok "Unattended-upgrades activé."
}

setup_ssh_hardening() {
  if [[ "$MODE" == "pro" ]]; then
    log "🔐 Durcissement SSH (mode pro)..."

    # Vérifier présence de clés SSH
    local ssh_keys_present=false
    if [[ -d "/home/$TARGET_USER/.ssh" ]]; then
      local key_files=("/home/$TARGET_USER/.ssh"/*.pub)
      if [[ -f "${key_files[0]}" ]]; then
        ssh_keys_present=true
      fi
    fi

    if [[ "$ssh_keys_present" == true ]]; then
      # Configuration SSH durcie
      cat > /etc/ssh/sshd_config.d/10-hardening.conf << 'SSH'
# SSH Hardening Pi 5
Port 22
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
SSH

      systemctl restart ssh

      ok "SSH durci (auth par clé uniquement)."
    else
      warn "Pas de clé SSH détectée → on ne désactive PAS le mot de passe (anti-lockout)."
    fi
  else
    log "Mode beginner : pas de durcissement SSH."
  fi
}

check_week2_readiness() {
  log "🔍 Vérification compatibilité Week2..."

  local issues=0

  # Vérifier entropie (critique pour PostgreSQL)
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -ge 1000 ]]; then
    ok "✅ Entropie suffisante pour Docker/PostgreSQL ($entropy bits)"
  else
    warn "⚠️ Entropie faible ($entropy bits) - haveged installé pour amélioration"
    ((issues++))
  fi

  # Vérifier page size si pas de redémarrage requis
  if [[ "${REBOOT_REQUIRED:-false}" != "true" ]]; then
    local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
    if [[ "$page_size" == "4096" ]]; then
      ok "✅ Page size compatible PostgreSQL"
    else
      warn "⚠️ Page size $page_size - Redémarrage requis pour correction"
      ((issues++))
    fi
  fi

  # Vérifier Docker
  if docker info >/dev/null 2>&1; then
    ok "✅ Docker configuré et fonctionnel"
  else
    warn "⚠️ Docker non accessible (reconnexion utilisateur requise)"
    ((issues++))
  fi

  # Vérifier ports libres pour Supabase
  local supabase_ports=(3000 8000 8001 5432 54321)
  local blocked_ports=()

  for port in "${supabase_ports[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
      blocked_ports+=("$port")
    fi
  done

  if [[ ${#blocked_ports[@]} -eq 0 ]]; then
    ok "✅ Tous les ports Supabase libres"
  else
    warn "⚠️ Ports occupés: ${blocked_ports[*]} - Vérifier avant Week2"
    ((issues++))
  fi

  return $issues
}

show_completion_summary() {
  echo ""
  echo "==================== 🎉 SETUP WEEK1 TERMINÉ ===================="

  local issues=0
  check_week2_readiness || issues=$?

  echo ""
  if [[ "$issues" -eq 0 ]]; then
    ok "🎉 Pi 5 parfaitement configuré pour Week2 !"
  else
    warn "⚠️ $issues point(s) d'attention pour Week2"
  fi

  echo ""
  echo "📋 **État du système** :"
  echo "   🥧 Pi 5 optimisé pour serveur"
  echo "   🐳 Docker + Compose v2 installés"
  echo "   🎛️ Portainer disponible"
  echo "   🔥 UFW configuré"
  echo "   🛡️ Fail2ban actif"
  echo "   🔄 MAJ automatiques activées"

  if [[ "$MODE" == "pro" ]]; then
    echo "   🔐 SSH durci (mode pro)"
  fi

  echo ""
  echo "🌐 **Accès services** :"
  local ip_address=$(hostname -I | awk '{print $1}')
  echo "   Portainer : http://$ip_address:8080"

  echo ""
  echo "📂 **Logs** : $LOG_FILE"

  # Vérifier si redémarrage requis
  if [[ "${REBOOT_REQUIRED:-false}" == "true" ]] || [[ -f /tmp/pi5-reboot-required ]]; then
    echo ""
    echo "🔄 **REDÉMARRAGE REQUIS** pour finaliser configuration :"
    echo "   - Page size 4KB (critique pour PostgreSQL)"
    echo "   - Configuration kernel optimisée"
    echo ""
    echo "Commande : sudo reboot"
    echo ""
    echo "🚀 **Après redémarrage** : Lancer Week2"
    echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/setup-week2-supabase-final.sh -o week2.sh"
    echo "   chmod +x week2.sh && sudo ./week2.sh"
  else
    echo ""
    echo "🚀 **Prêt pour Week2 Supabase** :"
    echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/setup-week2-supabase-final.sh -o week2.sh"
    echo "   chmod +x week2.sh && sudo ./week2.sh"
  fi

  echo ""
  echo "================================================================"
}

main() {
  require_root
  setup_logging

  log "=== DÉBUT SETUP PI 5 ENHANCED FINAL ==="

  check_pi5_compatibility
  update_system
  apply_system_optimizations

  ok "Base système à jour avec optimisations Pi 5 + préparation Week2."

  install_docker
  deploy_portainer
  configure_firewall
  configure_fail2ban
  setup_auto_updates
  setup_ssh_hardening

  show_completion_summary
}

main "$@"