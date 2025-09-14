#!/usr/bin/env bash
set -euo pipefail

# === SETUP WEEK1 ENHANCED - Version améliorée avec préparation Week2 ===

# === Configuration ===
MODE="${MODE:-beginner}"   # beginner | pro
SSH_PORT="${SSH_PORT:-22}"
ALLOW_PORTAINER="${ALLOW_PORTAINER:-yes}"
PORTAINER_PORT="${PORTAINER_PORT:-8080}"  # Changé de 9000 pour éviter conflit
ALLOW_HTTP_HTTPS="${ALLOW_HTTP_HTTPS:-yes}"
TZ_DEFAULT="${TZ_DEFAULT:-Europe/Paris}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week1.log}"

# === Pi 5 Optimizations ===
GPU_MEM_SPLIT="${GPU_MEM_SPLIT:-128}"
ENABLE_I2C="${ENABLE_I2C:-no}"
ENABLE_SPI="${ENABLE_SPI:-no}"
FIX_PAGE_SIZE="${FIX_PAGE_SIZE:-auto}"  # auto | yes | no

log()  { echo -e "\033[1;36m[SETUP]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week1-enhanced.sh"
    exit 1
  fi
  # Initialiser le fichier de log
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Setup Week 1 Enhanced - $(date) ==="
}

check_pi5_compatibility() {
  log "Vérification compatibilité Pi 5 et préparation Week2…"

  # Vérification architecture ARM64
  if [[ "$(uname -m)" != "aarch64" ]]; then
    warn "Architecture détectée: $(uname -m). Ce script est optimisé pour ARM64/Pi 5."
  fi

  # Vérification RAM (doit être ≥ 4GB pour un setup serveur optimal)
  RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  RAM_GB=$((RAM_KB / 1024 / 1024))
  if [[ $RAM_GB -ge 16 ]]; then
    ok "RAM détectée: ${RAM_GB}GB - Excellent pour Supabase + serveur"
  elif [[ $RAM_GB -ge 8 ]]; then
    ok "RAM détectée: ${RAM_GB}GB - Très bien pour Supabase + serveur"
  elif [[ $RAM_GB -ge 4 ]]; then
    ok "RAM détectée: ${RAM_GB}GB - Suffisant pour un serveur basique"
  else
    warn "RAM détectée: ${RAM_GB}GB - Limité pour Supabase + serveur complet"
  fi

  # Vérification espace disque
  DISK_AVAIL=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $DISK_AVAIL -ge 30 ]]; then
    ok "Espace disque: ${DISK_AVAIL}GB disponibles - Excellent pour Supabase"
  elif [[ $DISK_AVAIL -ge 20 ]]; then
    ok "Espace disque: ${DISK_AVAIL}GB disponibles - Suffisant pour Supabase"
  else
    warn "Espace disque faible: ${DISK_AVAIL}GB. Recommandé: ≥20GB pour Supabase"
  fi

  # Vérification page size (critique pour PostgreSQL)
  check_page_size_compatibility
}

check_page_size_compatibility() {
  local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
  log "Page size kernel : $page_size bytes"

  if [[ "$page_size" == "16384" ]]; then
    error "❌ Page size 16KB détecté - Incompatible avec PostgreSQL/Supabase"
    echo "   💡 Correction automatique du kernel pour compatibilité Week2"

    if [[ "$FIX_PAGE_SIZE" == "auto" || "$FIX_PAGE_SIZE" == "yes" ]]; then
      fix_page_size_automatically
    else
      warn "   Configuration manuelle requise : kernel=kernel8.img dans /boot/firmware/config.txt"
    fi

  elif [[ "$page_size" == "4096" ]]; then
    ok "✅ Page size 4KB - Compatible avec PostgreSQL/Supabase"
  else
    warn "Page size non standard ($page_size) - À surveiller avec Supabase"
  fi
}

fix_page_size_automatically() {
  log "Correction automatique du page size..."

  local config_file="/boot/firmware/config.txt"
  if [[ -f "$config_file" ]]; then
    # Backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

    # Ajouter kernel 4KB si pas présent
    if ! grep -q "^kernel=kernel8.img" "$config_file"; then
      echo "" >> "$config_file"
      echo "# Kernel 4KB pour compatibilité PostgreSQL/Supabase Week2" >> "$config_file"
      echo "kernel=kernel8.img" >> "$config_file"

      ok "✅ Kernel 4KB configuré - Redémarrage requis après installation"
      REBOOT_REQUIRED=true
    else
      ok "✅ Kernel 4KB déjà configuré"
    fi
  else
    warn "Fichier $config_file non trouvé - Configuration manuelle nécessaire"
  fi
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
}

apt_base() {
  log "MAJ système + paquets utiles pour Pi 5 + préparation Week2…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y

  # Paquets de base + outils monitoring Pi 5 + outils Week2
  apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    htop iotop ncdu tree \
    git vim nano \
    rpi-update \
    haveged \
    python3-yaml \
    netcat-openbsd

  # Démarrer haveged pour améliorer l'entropie (critique pour Docker/PostgreSQL)
  systemctl enable haveged
  systemctl start haveged
  ok "haveged démarré - Entropie améliorée pour Docker/PostgreSQL"

  # Configuration timezone
  timedatectl set-timezone "$TZ_DEFAULT" || true

  # Optimisations Pi 5 spécifiques
  optimize_pi5_config

  ok "Base système à jour avec optimisations Pi 5 + préparation Week2."
}

optimize_pi5_config() {
  log "Application des optimisations Pi 5 + préparation Week2…"

  # Configuration GPU memory split
  if ! grep -q "gpu_mem=" /boot/firmware/config.txt 2>/dev/null; then
    echo "gpu_mem=${GPU_MEM_SPLIT}" >> /boot/firmware/config.txt
    ok "GPU memory split configuré à ${GPU_MEM_SPLIT}MB"
  fi

  # Activation I2C si demandé
  if [[ "${ENABLE_I2C}" == "yes" ]]; then
    if ! grep -q "dtparam=i2c_arm=on" /boot/firmware/config.txt 2>/dev/null; then
      echo "dtparam=i2c_arm=on" >> /boot/firmware/config.txt
      echo "i2c-dev" >> /etc/modules
      ok "I2C activé"
    fi
  fi

  # Activation SPI si demandé
  if [[ "${ENABLE_SPI}" == "yes" ]]; then
    if ! grep -q "dtparam=spi=on" /boot/firmware/config.txt 2>/dev/null; then
      echo "dtparam=spi=on" >> /boot/firmware/config.txt
      ok "SPI activé"
    fi
  fi

  # Optimisations système pour serveur + PostgreSQL
  configure_system_optimizations

  ok "Optimisations Pi 5 appliquées"
}

configure_system_optimizations() {
  log "Configuration système avancée…"

  # Optimisation swap pour serveur + base de données
  cat > /etc/sysctl.d/99-pi5-server.conf << 'EOF'
# Pi 5 Server optimizations + PostgreSQL preparation

# Mémoire
vm.swappiness=1
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=2
vm.overcommit_ratio=80

# PostgreSQL shared memory (préparation Week2)
kernel.shmmax=68719476736
kernel.shmall=4294967296

# Fichiers et réseau
fs.file-max=2097152
net.core.somaxconn=65535
net.core.netdev_max_backlog=5000
EOF

  # Configuration limites fichiers pour Docker + PostgreSQL
  if ! grep -q "# Pi5 Server limits" /etc/security/limits.conf; then
    cat >> /etc/security/limits.conf << 'EOF'

# Pi5 Server limits + PostgreSQL preparation
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
postgres soft nofile 65536
postgres hard nofile 65536
EOF
  fi

  ok "Optimisations système configurées"
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    ok "Docker déjà installé."
    return
  fi
  log "Dépôt Docker officiel pour Pi 5…"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list

  log "Installation Docker CE + Compose v2 optimisé Pi 5 + Supabase…"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Configuration Docker pour Pi 5 + Supabase
  configure_docker_pi5_enhanced

  systemctl enable --now docker
  usermod -aG docker "$TARGET_USER" || true
  ok "Docker installé avec optimisations Pi 5 + Supabase. (Reconnexion requise pour utiliser docker sans sudo.)"
}

configure_docker_pi5_enhanced() {
  log "Configuration Docker pour Pi 5 + Supabase…"

  # Configuration daemon.json optimisée pour Supabase
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<'JSON'
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

  # Création répertoire systemd override
  mkdir -p /etc/systemd/system/docker.service.d

  # Optimisation mémoire pour Pi 5 + PostgreSQL
  cat > /etc/systemd/system/docker.service.d/override.conf <<'OVERRIDE'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TasksMax=infinity
OVERRIDE

  systemctl daemon-reload
  ok "Configuration Docker Pi 5 + Supabase appliquée"
}

run_portainer() {
  [[ "${ALLOW_PORTAINER}" != "yes" ]] && { warn "Portainer désactivé."; return; }
  if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
    ok "Portainer déjà démarré."
    return
  fi
  log "Déploiement Portainer CE sur port ${PORTAINER_PORT} (évite conflit Supabase port 8000)…"
  docker volume create portainer_data >/dev/null
  docker run -d \
    -p "${PORTAINER_PORT}:9000" \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  ok "Portainer prêt sur port ${PORTAINER_PORT}."
}

setup_ufw() {
  log "Pare-feu UFW (ports optimisés pour Week2)…"
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw limit "${SSH_PORT}"/tcp
  [[ "${ALLOW_PORTAINER}" == "yes" ]] && ufw allow "${PORTAINER_PORT}"/tcp
  if [[ "${ALLOW_HTTP_HTTPS}" == "yes" ]]; then
    ufw allow 80/tcp
    ufw allow 443/tcp
  fi

  # Préparer règles pour Supabase Week2 (commentées pour l'instant)
  # ufw allow 3000/tcp  # Supabase Studio
  # ufw allow 8001/tcp  # Supabase API Gateway
  # ufw allow 54321/tcp # Supabase Edge Functions

  ufw --force enable
  ok "UFW activé avec ports préparés pour Week2."
}

setup_fail2ban() {
  log "Fail2ban (sshd)…"
  mkdir -p /etc/fail2ban
  cat >/etc/fail2ban/jail.local <<'JAIL'
[DEFAULT]
bantime = 12h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
JAIL
  systemctl enable --now fail2ban
  systemctl restart fail2ban
  ok "Fail2ban configuré."
}

enable_unattended_upgrades() {
  log "MAJ sécurité automatiques…"
  systemctl enable --now unattended-upgrades
  cat >/etc/apt/apt.conf.d/20auto-upgrades <<'CONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
CONF
  ok "Unattended-upgrades activé."
}

harden_ssh_if_pro() {
  [[ "$MODE" != "pro" ]] && { warn "Mode beginner : pas de durcissement SSH."; return; }
  log "Durcissement SSH (clé requise si présente)…"
  AUTH_FILE="$HOME_DIR/.ssh/authorized_keys"
  if [[ -f "$AUTH_FILE" && -s "$AUTH_FILE" ]]; then
    mkdir -p /etc/ssh/sshd_config.d
    cat >/etc/ssh/sshd_config.d/10-hardening.conf <<CONF
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
CONF
    if sshd -t 2>/dev/null; then
      systemctl reload ssh || systemctl reload sshd || true
      ok "SSH durci (auth par clé uniquement)."
    else
      warn "Config SSH invalide, on annule."
      rm -f /etc/ssh/sshd_config.d/10-hardening.conf
    fi
  else
    warn "Pas de clé SSH détectée → on ne désactive PAS le mot de passe (anti-lockout)."
  fi
}

check_week2_readiness() {
  log "Vérification compatibilité Week2…"

  local issues=0

  # Vérifier entropie
  local entropy=$(cat /proc/sys/kernel/random/entropy_avail 2>/dev/null || echo "0")
  if [[ $entropy -ge 1000 ]]; then
    ok "✅ Entropie suffisante pour Docker/PostgreSQL ($entropy bits)"
  else
    warn "⚠️ Entropie faible ($entropy bits) - haveged installé"
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
    ok "✅ Ports Supabase libres"
  else
    warn "⚠️ Ports occupés : ${blocked_ports[*]}"
    ((issues++))
  fi

  if [[ $issues -eq 0 ]]; then
    ok "🎉 Système prêt pour Supabase Week2 !"
  else
    warn "⚠️ $issues problème(s) détecté(s) - Utilise prepare-week2.sh pour correction"
  fi
}

summary() {
  IP="$(hostname -I | awk '{print $1}')"
  echo
  echo "==================== Résumé Pi 5 Enhanced ===================="
  echo "Système         : $(uname -m) - $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)"GB RAM"}')"
  echo "Docker          : $(docker --version 2>/dev/null || echo 'installé (vérifie après reconnexion)')"
  echo "Compose v2      : $(docker compose version 2>/dev/null || echo 'via plugin docker-compose-plugin')"
  echo "Portainer       : ${ALLOW_PORTAINER} → http://${IP}:${PORTAINER_PORT}"
  echo "UFW             : activé (SSH ${SSH_PORT}, Portainer ${PORTAINER_PORT})"
  echo "Fail2ban        : actif (jail sshd)"
  echo "MAJ auto        : activées"
  echo "Mode            : ${MODE}"
  echo "GPU Memory      : ${GPU_MEM_SPLIT}MB"
  echo "I2C/SPI         : I2C:${ENABLE_I2C} | SPI:${ENABLE_SPI}"
  echo "Entropie        : $(cat /proc/sys/kernel/random/entropy_avail || echo 'N/A') bits"
  echo "Page Size       : $(getconf PAGESIZE || echo 'unknown') bytes"
  echo "Log file        : ${LOG_FILE}"
  echo ""

  if [[ "${REBOOT_REQUIRED:-false}" == "true" ]]; then
    warn "⚠️ REDÉMARRAGE REQUIS pour correction page size"
    echo ""
    echo "🔄 Après redémarrage :"
    echo "   - Page size sera 4KB (compatible PostgreSQL)"
    echo "   - Entropie améliorée par haveged"
    echo "   - Système prêt pour Supabase Week2"
    echo ""
    echo "📋 **Vérifications post-redémarrage :**"
    echo "   # Vérifier page size et entropie"
    echo "   echo \"📏 Page size: \$(getconf PAGESIZE) bytes\""
    echo "   echo \"🎲 Entropie: \$(cat /proc/sys/kernel/random/entropy_avail) bits\""
    echo ""
    echo "🚀 **Installation Supabase Week2 :**"
    echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2-improved.sh -o supabase.sh"
    echo "   chmod +x supabase.sh"
    echo "   sudo ./supabase.sh"
  else
    echo "🔥 Pi 5 optimisé pour serveur + Supabase Week2 !"
    echo ""
    echo "📋 **Vérifications système :**"
    echo "   # Vérifier page size et entropie"
    echo "   echo \"📏 Page size: \$(getconf PAGESIZE) bytes\""
    echo "   echo \"🎲 Entropie: \$(cat /proc/sys/kernel/random/entropy_avail) bits\""
    echo ""
    echo "🚀 **Installation Supabase Week2 :**"
    echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2-improved.sh -o supabase.sh"
    echo "   chmod +x supabase.sh"
    echo "   sudo ./supabase.sh"
  fi
  echo "=============================================================="

  # Afficher information redémarrage
  if [[ "${REBOOT_REQUIRED:-false}" == "true" ]]; then
    echo ""
    read -p "Redémarrer maintenant pour activer le kernel 4KB ? (oui/non): " -r
    if [[ $REPLY =~ ^(oui|OUI|yes|YES|y|Y)$ ]]; then
      log "Redémarrage pour activation kernel 4KB..."
      reboot
    fi
  fi
}

main() {
  require_root
  detect_user

  log "=== DÉBUT SETUP PI 5 ENHANCED ==="

  check_pi5_compatibility
  apt_base
  install_docker
  run_portainer
  setup_ufw
  setup_fail2ban
  enable_unattended_upgrades
  harden_ssh_if_pro
  check_week2_readiness

  summary
}

main "$@"