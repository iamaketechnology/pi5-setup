cat <<'EOF' > setup-week1.sh
#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-beginner}"   # beginner | pro
SSH_PORT="${SSH_PORT:-22}"
ALLOW_PORTAINER="${ALLOW_PORTAINER:-yes}"
ALLOW_HTTP_HTTPS="${ALLOW_HTTP_HTTPS:-yes}"
TZ_DEFAULT="${TZ_DEFAULT:-Europe/Paris}"

log()  { echo -e "\033[1;36m[SETUP]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Exécute : sudo MODE=beginner ./setup-week1.sh"
    exit 1
  fi
}

detect_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  [[ "$TARGET_USER" == "root" ]] && HOME_DIR="/root" || HOME_DIR="/home/$TARGET_USER"
}

apt_base() {
  log "MAJ système + paquets utiles…"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y ca-certificates curl gnupg lsb-release ufw fail2ban unattended-upgrades
  timedatectl set-timezone "$TZ_DEFAULT" || true
  ok "Base système à jour."
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    ok "Docker déjà installé."
    return
  fi
  log "Dépôt Docker officiel…"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  arch="$(dpkg --print-architecture)"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list

  log "Installation Docker CE + Compose v2…"
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  usermod -aG docker "$TARGET_USER" || true
  ok "Docker installé. (Reconnexion requise pour utiliser docker sans sudo.)"
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
  echo "==================== Résumé ===================="
  echo "Docker          : $(docker --version 2>/dev/null || echo 'installé (vérifie après reconnexion)')"
  echo "Compose v2      : $(docker compose version 2>/dev/null || echo 'via plugin docker-compose-plugin')"
  echo "Portainer       : ${ALLOW_PORTAINER} → http://${IP}:9000"
  echo "UFW             : activé (SSH ${SSH_PORT}, ${ALLOW_PORTAINER:+9000} ${ALLOW_HTTP_HTTPS:+80/443})"
  echo "Fail2ban        : actif (jail sshd)"
  echo "MAJ auto        : activées"
  echo "Mode            : ${MODE}"
  echo "================================================"
}

main() {
  require_root
  detect_user
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
