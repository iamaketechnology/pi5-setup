#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: incident-mode.sh [options] <enter|exit>

Active ou désactive le mode incident (réduction des services non critiques).

Variables:
  CRITICAL_COMPOSE_DIRS    Répertoires docker compose à maintenir (liste séparée par des virgules)
  NON_CRITICAL_COMPOSE_DIRS Répertoires à suspendre

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

ACTION=${1:-}
if [[ -z ${ACTION} ]]; then
  fatal "Action requise: enter ou exit"
fi

CRITICAL_COMPOSE_DIRS=${CRITICAL_COMPOSE_DIRS:-/home/${USER}/stacks/supabase}
NON_CRITICAL_COMPOSE_DIRS=${NON_CRITICAL_COMPOSE_DIRS:-}

IFS=',' read -r -a CRITICAL_ARRAY <<< "${CRITICAL_COMPOSE_DIRS}"
IFS=',' read -r -a NON_CRITICAL_ARRAY <<< "${NON_CRITICAL_COMPOSE_DIRS}"

scale_services() {
  local dirs_string=$1
  local state=$2
  IFS=',' read -r -a dirs_array <<< "${dirs_string}"
  local dir
  for dir in "${dirs_array[@]}"; do
    [[ -z ${dir} ]] && continue
    if [[ ! -d ${dir} ]]; then
      log_warn "${dir} introuvable"
      continue
    fi
    local cwd="${PWD}"
    cd "${dir}"
    if [[ ${state} == "down" ]]; then
      run_cmd docker compose down
    else
      run_cmd docker compose up -d
    fi
    cd "${cwd}"
  done
}

enter_incident() {
  log_info "Activation mode incident"
  scale_services "${NON_CRITICAL_COMPOSE_DIRS}" down
  log_success "Services non critiques arrêtés"
}

exit_incident() {
  log_info "Sortie mode incident"
  scale_services "${CRITICAL_COMPOSE_DIRS}" up
  scale_services "${NON_CRITICAL_COMPOSE_DIRS}" up
  log_success "Services restaurés"
}

case "${ACTION}" in
  enter)
    enter_incident
    ;;
  exit)
    exit_incident
    ;;
  *)
    fatal "Action invalide: ${ACTION}"
    ;;
 esac
