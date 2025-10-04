#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 07-logs-collect.sh [options]

Collecte les journaux système et Docker dans une archive tar.gz.

Variables:
  OUTPUT_DIR             Dossier de sortie (défaut: /opt/reports)
  DOCKER_COMPOSE_DIRS    Dossiers docker compose (séparés par des virgules)
  INCLUDE_SYSTEMD        1 pour inclure journal systemd (défaut: 1)
  INCLUDE_DMESG          1 pour inclure dmesg (défaut: 1)
  TAIL_LINES             Nombre de lignes de logs (défaut: 1000)

Options:
  --dry-run        Simule
  --yes, -y        Confirme
  --verbose, -v    Verbosité
  --quiet, -q      Silencieux
  --no-color       Sans couleurs
  --help, -h       Aide
USAGE
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

OUTPUT_DIR=${OUTPUT_DIR:-/opt/reports}
DOCKER_COMPOSE_DIRS=${DOCKER_COMPOSE_DIRS:-/home/${USER}/stacks/supabase}
INCLUDE_SYSTEMD=${INCLUDE_SYSTEMD:-1}
INCLUDE_DMESG=${INCLUDE_DMESG:-1}
TAIL_LINES=${TAIL_LINES:-1000}

ensure_dir "${OUTPUT_DIR}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
WORK_DIR="${OUTPUT_DIR}/logs-${TIMESTAMP}"
ARCHIVE_PATH="${OUTPUT_DIR}/logs-${TIMESTAMP}.tar.gz"

ensure_dir "${WORK_DIR}"

IFS=',' read -r -a COMPOSE_DIR_ARRAY <<< "${DOCKER_COMPOSE_DIRS}"

collect_system_info() {
  log_info "Infos système"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] system info"
    return
  fi
  uname -a >"${WORK_DIR}/uname.txt"
  lsb_release -a 2>/dev/null || true
  lsb_release -a 2>/dev/null >"${WORK_DIR}/lsb-release.txt" || true
  df -h >"${WORK_DIR}/disk-usage.txt"
  free -h >"${WORK_DIR}/memory.txt"
}

collect_systemd() {
  [[ ${INCLUDE_SYSTEMD} -eq 1 ]] || return 0
  log_info "Collecte journal systemd"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] journalctl"
    return
  fi
  journalctl -xe --no-pager -n "${TAIL_LINES}" >"${WORK_DIR}/journalctl.txt" || true
}

collect_dmesg() {
  [[ ${INCLUDE_DMESG} -eq 1 ]] || return 0
  log_info "Collecte dmesg"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] dmesg"
    return
  fi
  dmesg -T | tail -n "${TAIL_LINES}" >"${WORK_DIR}/dmesg.txt" || true
}

collect_docker_logs() {
  log_info "Collecte logs Docker"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] docker logs"
    return
  fi
  docker ps --format '{{.Names}}' >"${WORK_DIR}/docker-containers.txt"
  while read -r name; do
    [[ -z ${name} ]] && continue
    docker logs --tail "${TAIL_LINES}" "${name}" >"${WORK_DIR}/docker-${name}.log" 2>&1 || true
  done <"${WORK_DIR}/docker-containers.txt"
}

collect_compose_logs() {
  log_info "Collecte logs Compose"
  local dir
  for dir in "${COMPOSE_DIR_ARRAY[@]}"; do
    [[ -z ${dir} ]] && continue
    if [[ ! -d ${dir} ]]; then
      log_warn "${dir} introuvable"
      continue
    fi
    local sanitized=$(echo "${dir}" | tr '/' '_')
    local outfile="${WORK_DIR}/compose${sanitized}.log"
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_info "[DRY-RUN] docker compose logs ${dir}"
    else
      local cwd="${PWD}"
      cd "${dir}"
      docker compose logs --tail "${TAIL_LINES}" >"${outfile}" 2>&1 || true
      cd "${cwd}"
    fi
  done
}

create_archive() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] tar czf ${ARCHIVE_PATH}"
    return
  fi
  local cwd="${PWD}"
  cd "${OUTPUT_DIR}"
  tar -czf "${ARCHIVE_PATH}" "$(basename "${WORK_DIR}")"
  cd "${cwd}"
}

cleanup_tmp() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] rm -rf ${WORK_DIR}"
    return
  fi
  rm -rf "${WORK_DIR}"
}

register_cleanup cleanup_tmp

main() {
  collect_system_info
  collect_systemd
  collect_dmesg
  collect_docker_logs
  collect_compose_logs
  create_archive
  log_success "Logs collectés: ${ARCHIVE_PATH}"
}

main "$@"
