#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage: 02-docker-install-verify.sh [options]

Installe Docker + Compose et réalise des vérifications (hello-world, ressources).

Variables optionnelles:
  DOCKER_COMPOSE_VERSION   Version spécifique de docker compose plugin (ex: v2.29.7)
  INSTALL_ROOTLESS=1       Installe la configuration rootless pour l'utilisateur actuel

Options:
  --dry-run        Simule les actions
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

APT_ENV=("DEBIAN_FRONTEND=noninteractive")
DOCKER_COMPOSE_VERSION=${DOCKER_COMPOSE_VERSION:-latest}
INSTALL_ROOTLESS=${INSTALL_ROOTLESS:-0}

ensure_dependencies() {
  log_info "Installation des dépendances Docker"
  run_cmd "${APT_ENV[@]}" apt-get update
  run_cmd "${APT_ENV[@]}" apt-get install -y ca-certificates curl gnupg lsb-release
}

add_docker_repo() {
  log_info "Ajout du dépôt Docker officiel"

  run_cmd install -m 0755 -d /etc/apt/keyrings
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Téléchargement clé GPG Docker"
  else
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  local codename
  codename=$(lsb_release -cs)
  local repo="deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Ajout dépôt: ${repo}"
  else
    echo "${repo}" >/etc/apt/sources.list.d/docker.list
  fi
  run_cmd "${APT_ENV[@]}" apt-get update
}

install_docker() {
  log_info "Installation de Docker Engine"
  run_cmd "${APT_ENV[@]}" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

configure_daemon() {
  local daemon_json=/etc/docker/daemon.json
  log_info "Configuration du daemon Docker (${daemon_json})"

  run_cmd mkdir -p /etc/docker
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Écriture configuration daemon"
    return
  fi

  cat <<'JSON' >/etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "dns": ["1.1.1.1", "8.8.8.8"],
  "live-restore": true
}
JSON
}

restart_docker() {
  log_info "Redémarrage du service Docker"
  run_cmd systemctl enable --now docker
  run_cmd systemctl restart docker
}

hello_world() {
  log_info "Test hello-world"
  run_cmd docker run --rm hello-world
}

verify_info() {
  log_info "Informations Docker"
  run_cmd docker info
  run_cmd docker version
}

install_compose_cli() {
  if [[ ${DOCKER_COMPOSE_VERSION} == "latest" ]]; then
    log_info "Plugin docker compose déjà installé via apt"
    return
  fi
  local release=${DOCKER_COMPOSE_VERSION}
  local url="https://github.com/docker/compose/releases/download/${release}/docker-compose-linux-aarch64"
  log_info "Téléchargement docker compose ${release}"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] curl -L ${url}"
  else
    curl -SL "${url}" -o /usr/libexec/docker/cli-plugins/docker-compose
    chmod +x /usr/libexec/docker/cli-plugins/docker-compose
  fi
}

setup_rootless() {
  [[ ${INSTALL_ROOTLESS} -eq 1 ]] || return 0
  local user=${SUDO_USER:-root}
  if [[ ${user} == "root" ]]; then
    log_warn "Rootless demandé mais utilisateur root actif. Ignoré."
    return 0
  fi
  log_info "Configuration Docker rootless pour ${user}"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] dockerd-rootless-setuptool.sh"
    return
  fi
  sudo -u "${user}" sh -c 'export XDG_RUNTIME_DIR=/run/user/$(id -u); dockerd-rootless-setuptool.sh install'
}

post_checks() {
  if ! docker info >/dev/null 2>&1; then
    fatal "docker info a échoué. Vérifiez le service."
  fi
  if ! docker compose version >/dev/null 2>&1; then
    fatal "docker compose non fonctionnel"
  fi
  log_success "Docker prêt à l'emploi"
}

main() {
  ensure_dependencies
  add_docker_repo
  install_docker
  configure_daemon
  restart_docker
  install_compose_cli
  hello_world
  verify_info
  setup_rootless
  post_checks
}

main "$@"
