cat <<'EOF' > setup-week1.sh
#!/usr/bin/env bash
set -euo pipefail

# === Configuration ===
MODE="${MODE:-beginner}"   # beginner | pro
SSH_PORT="${SSH_PORT:-22}"
ALLOW_PORTAINER="${ALLOW_PORTAINER:-yes}"
ALLOW_HTTP_HTTPS="${ALLOW_HTTP_HTTPS:-yes}"
TZ_DEFAULT="${TZ_DEFAULT:-Europe/Paris}"
LOG_FILE="${LOG_FILE:-/var/log/pi5-setup-week1.log}"

# === Pi 5 Optimizations ===
GPU_MEM_SPLIT="${GPU_MEM_SPLIT:-128}"
ENABLE_I2C="${ENABLE_I2C:-no}"
ENABLE_SPI="${ENABLE_SPI:-no}"

log()  { echo -e "\033[1;36m[SETUP]\033[0m $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*" | tee -a "$LOG_FILE"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*" | tee -a "$LOG_FILE"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" | tee -a "$LOG_FILE"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week1.sh"
    exit 1
  fi
  # Initialiser le fichier de log
  touch "$LOG_FILE"
  chmod 644 "$LOG_FILE"
  log "=== Pi 5 Setup Week 1 - $(date) ==="
}

check_pi5_compatibility() {
  log "Vérification compatibilité Pi 5…"

  # Vérification architecture ARM64
  if [[ "$(uname -m)" != "aarch64" ]]; then
    warn "Architecture détectée: $(uname -m). Ce script est optimisé pour ARM64/Pi 5."
  fi

  # Vérification RAM (doit être ≥ 4GB pour un setup serveur optimal)
  RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  RAM_GB=$((RAM_KB / 1024 / 1024))
  if [[ $RAM_GB -ge 8 ]]; then
    ok "RAM détectée: ${RAM_GB}GB - Excellent pour un serveur"
  elif [[ $RAM_GB -ge 4 ]]; then
    ok "RAM détectée: ${RAM_GB}GB - Suffisant pour un serveur basique"
  else
    warn "RAM détectée: ${RAM_GB}GB - Limité pour un serveur complet"
  fi

  # Vérification espace disque
  DISK_AVAIL=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $DISK_AVAIL -ge 20 ]]; then
    ok "Espace disque: ${DISK_AVAIL}GB disponibles"
  else
    warn "Espace disque faible: ${DISK_AVAIL}GB. Recommandé: ≥20GB"
  fi
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
}

apt_base() {
  log "MAJ système + paquets utiles pour Pi 5…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y

  # Paquets de base + outils monitoring Pi 5
  apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    htop iotop ncdu tree \
    git vim nano \
    rpi-update

  # Configuration timezone
  timedatectl set-timezone "$TZ_DEFAULT" || true

  # Optimisations Pi 5 spécifiques
  optimize_pi5_config

  ok "Base système à jour avec optimisations Pi 5."
}

optimize_pi5_config() {
  log "Application des optimisations Pi 5…"

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

  # Optimisation swap pour serveur (réduction swappiness)
  echo "vm.swappiness=10" > /etc/sysctl.d/99-pi5-server.conf

  # Configuration limite fichiers ouverts pour Docker
  echo "* soft nofile 65536" >> /etc/security/limits.conf
  echo "* hard nofile 65536" >> /etc/security/limits.conf

  ok "Optimisations Pi 5 appliquées"
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

  log "Installation Docker CE + Compose v2 optimisé Pi 5…"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  # Configuration Docker pour Pi 5
  configure_docker_pi5

  systemctl enable --now docker
  usermod -aG docker "$TARGET_USER" || true
  ok "Docker installé avec optimisations Pi 5. (Reconnexion requise pour utiliser docker sans sudo.)"
}

configure_docker_pi5() {
  log "Configuration Docker pour Pi 5…"

  # Configuration daemon.json pour Pi 5
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
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
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 3
}
JSON

  # Création répertoire systemd override
  mkdir -p /etc/systemd/system/docker.service.d

  # Optimisation mémoire pour Pi 5
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
  ok "Configuration Docker Pi 5 appliquée"
}

run_portainer() {
  [[ "${ALLOW_PORTAINER}" != "yes" ]] && { warn "Portainer désactivé."; return; }
  if docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
    ok "Portainer déjà démarré."
    return
  fi
  log "Déploiement Portainer CE…"
  docker volume create portainer_data >/dev/null
  docker run -d \
    -p 8000:8000 -p 9000:9000 \
    --name portainer \
    --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  ok "Portainer prêt."
}

setup_ufw() {
  log "Pare-feu UFW…"
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  ufw limit "${SSH_PORT}"/tcp
  [[ "${ALLOW_PORTAINER}" == "yes" ]] && ufw allow 9000/tcp
  if [[ "${ALLOW_HTTP_HTTPS}" == "yes" ]]; then
    ufw allow 80/tcp
    ufw allow 443/tcp
  fi
  ufw --force enable
  ok "UFW activé."
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

summary() {
  IP="$(hostname -I | awk '{print $1}')"
  echo
  echo "==================== Résumé Pi 5 ===================="
  echo "Système         : $(uname -m) - $(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)"GB RAM"}')"
  echo "Docker          : $(docker --version 2>/dev/null || echo 'installé (vérifie après reconnexion)')"
  echo "Compose v2      : $(docker compose version 2>/dev/null || echo 'via plugin docker-compose-plugin')"
  echo "Portainer       : ${ALLOW_PORTAINER} → http://${IP}:9000"
  echo "UFW             : activé (SSH ${SSH_PORT}, ${ALLOW_PORTAINER:+9000} ${ALLOW_HTTP_HTTPS:+80/443})"
  echo "Fail2ban        : actif (jail sshd)"
  echo "MAJ auto        : activées"
  echo "Mode            : ${MODE}"
  echo "GPU Memory      : ${GPU_MEM_SPLIT}MB"
  echo "I2C/SPI         : I2C:${ENABLE_I2C} | SPI:${ENABLE_SPI}"
  echo "Log file        : ${LOG_FILE}"
  echo ""
  echo "🔥 Pi 5 optimisé pour serveur ! Redémarrage recommandé."
  echo ""
  echo "📋 **PROCHAINES COMMANDES** :"
  echo "   # Redémarrage recommandé pour optimisations système"
  echo "   sudo reboot"
  echo ""
  echo "   # Après redémarrage, lancer Week 2 (Supabase)"
  echo "   ssh pi@pi5.local"
  echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2.sh -o setup-week2.sh \\\\"
  echo "   && chmod +x setup-week2.sh \\\\"
  echo "   && sudo MODE=beginner ./setup-week2.sh"
  echo "=================================================="
}

main() {
  require_root
  detect_user
  check_pi5_compatibility
  apt_base
  install_docker
  run_portainer
  setup_ufw
  setup_fail2ban
  enable_unattended_upgrades
  harden_ssh_if_pro
  summary
}
main
EOF

chmod +x setup-week1.sh
sudo MODE=beginner ./setup-week1.sh
