#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage: 01-system-hardening.sh [options]

Sécurise le Raspberry Pi (UFW, Fail2ban, SSH, mises à jour automatiques).

Variables optionnelles:
  SSH_PORT            Port SSH à autoriser (défaut: 22)
  EXTRA_ALLOWED_PORTS Ports supplémentaires séparés par des virgules (ex: "5432,8000")
  ENABLE_PASSWORDLESS_SSH=1   Force le login SSH par clé uniquement

Options:
  --dry-run        Simule sans appliquer
  --yes, -y        Confirme automatiquement
  --verbose, -v    Verbosité accrue
  --quiet, -q      Mode silencieux
  --no-color       Sans couleurs
  --help, -h       Aide
EOF
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

require_root

SSH_PORT=${SSH_PORT:-22}
EXTRA_ALLOWED_PORTS=${EXTRA_ALLOWED_PORTS:-}
ENABLE_PASSWORDLESS_SSH=${ENABLE_PASSWORDLESS_SSH:-0}

IFS=',' read -r -a EXTRA_PORT_LIST <<< "${EXTRA_ALLOWED_PORTS}"

APT_ENV=("DEBIAN_FRONTEND=noninteractive" "APT_LISTCHANGES_FRONTEND=none")

log_info "Sécurisation du système..."

update_packages() {
  log_info "Mise à jour des paquets"
  run_cmd "${APT_ENV[@]}" apt-get update
  run_cmd "${APT_ENV[@]}" apt-get -y upgrade
}

ensure_packages() {
  local packages=("ufw" "fail2ban" "unattended-upgrades" "needrestart")
  log_info "Installation des paquets requis: ${packages[*]}"
  run_cmd "${APT_ENV[@]}" apt-get install -y "${packages[@]}"
}

configure_unattended_upgrades() {
  log_info "Configuration des mises à jour automatiques"
  run_cmd dpkg-reconfigure --priority=low unattended-upgrades
}

configure_ufw() {
  log_info "Configuration UFW"
  run_cmd ufw --force reset
  run_cmd ufw default deny incoming
  run_cmd ufw default allow outgoing
  run_cmd ufw allow "${SSH_PORT}/tcp"
  local port
  for port in "80" "443" "3000" "8000" "8080"; do
    run_cmd ufw allow "${port}/tcp"
  done
  for port in "${EXTRA_PORT_LIST[@]}"; do
    [[ -z ${port} ]] && continue
    run_cmd ufw allow "${port}/tcp"
  done
  run_cmd ufw --force enable
}

configure_fail2ban() {
  log_info "Configuration Fail2ban"
  local jail_local=/etc/fail2ban/jail.local
  if [[ ! -f ${jail_local} ]]; then
    run_cmd tee "${jail_local}" >/dev/null <<'JAIL'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
JAIL
  fi
  run_cmd systemctl enable --now fail2ban
}

harden_ssh() {
  local sshd_config=/etc/ssh/sshd_config
  local backup="${sshd_config}.bak.$(date +%Y%m%d%H%M%S)"

  confirm "Modifier la configuration SSH (${sshd_config}) ?" || return 0

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Sauvegarde ${sshd_config} -> ${backup}"
  else
    cp "${sshd_config}" "${backup}"
  fi
  log_info "Sauvegarde créée: ${backup}"

  run_cmd sed -i "s/^#\?Port .*/Port ${SSH_PORT}/" "${sshd_config}"
  run_cmd sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "${sshd_config}"
  run_cmd sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "${sshd_config}"
  run_cmd sed -i 's/^#\?UsePAM .*/UsePAM yes/' "${sshd_config}"

  if [[ ${ENABLE_PASSWORDLESS_SSH} -eq 1 ]]; then
    run_cmd sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' "${sshd_config}"
  fi

  run_cmd systemctl restart ssh  # service sshd pour Debian/Raspbian
}

enable_needrestart_auto() {
  local conf=/etc/needrestart/needrestart.conf
  if [[ -f ${conf} ]]; then
    run_cmd sed -i 's/^#\?\$nrconf{restart}.*/$nrconf{restart} = "a";/' "${conf}"
  fi
}

main() {
  update_packages
  ensure_packages
  configure_unattended_upgrades
  configure_ufw
  configure_fail2ban
  harden_ssh
  enable_needrestart_auto
  log_success "Sécurisation terminée"
}

main "$@"
