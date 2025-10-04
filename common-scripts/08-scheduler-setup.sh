#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 08-scheduler-setup.sh [options]

Configure des tâches planifiées (systemd timers) pour backups, healthchecks, logs.

Variables:
  SCHEDULER_MODE          systemd (défaut) ou cron
  BACKUP_SCRIPT           Script backup (défaut: /usr/local/bin/backup.sh)
  HEALTHCHECK_SCRIPT      Script healthcheck (défaut: /usr/local/bin/healthcheck.sh)
  LOGS_SCRIPT             Script collecte logs (défaut: /usr/local/bin/logs.sh)
  BACKUP_SCHEDULE         Expression timer (défaut: daily)
  HEALTHCHECK_SCHEDULE    Déclencheur (défaut: hourly)
  LOGS_SCHEDULE           Déclencheur (défaut: weekly)

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

require_root

SCHEDULER_MODE=${SCHEDULER_MODE:-systemd}
BACKUP_SCRIPT=${BACKUP_SCRIPT:-/usr/local/bin/backup.sh}
HEALTHCHECK_SCRIPT=${HEALTHCHECK_SCRIPT:-/usr/local/bin/healthcheck.sh}
LOGS_SCRIPT=${LOGS_SCRIPT:-/usr/local/bin/logs.sh}
BACKUP_SCHEDULE=${BACKUP_SCHEDULE:-daily}
HEALTHCHECK_SCHEDULE=${HEALTHCHECK_SCHEDULE:-hourly}
LOGS_SCHEDULE=${LOGS_SCHEDULE:-weekly}

create_systemd_unit() {
  local name=$1; shift
  local script=$1; shift
  local schedule=$1; shift
  local service_unit="/etc/systemd/system/${name}.service"
  local timer_unit="/etc/systemd/system/${name}.timer"

  log_info "Création service ${service_unit}"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] service ${name} -> ${script}"
  else
    cat >"${service_unit}" <<SERVICE
[Unit]
Description=${name} task

[Service]
Type=oneshot
ExecStart=${script}
SERVICE
  fi

  log_info "Création timer ${timer_unit} (${schedule})"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] timer ${name}"
  else
    cat >"${timer_unit}" <<TIMER
[Unit]
Description=${name} schedule

[Timer]
OnCalendar=${schedule}
Persistent=true

[Install]
WantedBy=timers.target
TIMER
    run_cmd systemctl daemon-reload
    run_cmd systemctl enable --now "${name}.timer"
  fi
}

create_cron_job() {
  local schedule=$1; shift
  local script=$1; shift
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Ajouter cron '${schedule} ${script}'"
    return
  fi
  local cron_file="/etc/cron.d/pi5-${script##*/}"
  echo "${schedule} root ${script}" >"${cron_file}"
}

main_systemd() {
  create_systemd_unit "pi5-backup" "${BACKUP_SCRIPT}" "${BACKUP_SCHEDULE}"
  create_systemd_unit "pi5-healthcheck" "${HEALTHCHECK_SCRIPT}" "${HEALTHCHECK_SCHEDULE}"
  create_systemd_unit "pi5-logs" "${LOGS_SCRIPT}" "${LOGS_SCHEDULE}"
  log_success "Timers systemd configurés"
}

main_cron() {
  create_cron_job "${BACKUP_SCHEDULE}" "${BACKUP_SCRIPT}"
  create_cron_job "${HEALTHCHECK_SCHEDULE}" "${HEALTHCHECK_SCRIPT}"
  create_cron_job "${LOGS_SCHEDULE}" "${LOGS_SCRIPT}"
  log_success "Cron jobs configurés"
}

case "${SCHEDULER_MODE}" in
  systemd)
    main_systemd
    ;;
  cron)
    main_cron
    ;;
  *)
    fatal "SCHEDULER_MODE doit être systemd ou cron"
    ;;
 esac
