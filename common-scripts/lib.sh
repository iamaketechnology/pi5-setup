#!/usr/bin/env bash
# shellcheck disable=SC2034

set -euo pipefail

# --- Couleurs ---
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  _c_reset="$(tput sgr0)"
  _c_blue="$(tput setaf 4)"
  _c_green="$(tput setaf 2)"
  _c_yellow="$(tput setaf 3)"
  _c_red="$(tput setaf 1)"
  _c_magenta="$(tput setaf 5)"
else
  _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
fi

# --- Variables globales par défaut ---
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
NO_COLOR=${NO_COLOR:-0}
SHOW_HELP=0
COMMON_POSITIONAL_ARGS=()

if [[ "${NO_COLOR}" -eq 1 ]]; then
  _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
fi

# --- Fonctions de log ---
log_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
  [[ ${QUIET} -eq 1 ]] && return 0
  printf '%s %sℹ%s %s\n' "$(log_ts)" "${_c_blue}" "${_c_reset}" "$*"
}

log_warn() {
  printf '%s %s⚠%s %s\n' "$(log_ts)" "${_c_yellow}" "${_c_reset}" "$*" >&2
}

log_error() {
  printf '%s %s✖%s %s\n' "$(log_ts)" "${_c_red}" "${_c_reset}" "$*" >&2
}

log_success() {
  [[ ${QUIET} -eq 1 ]] && return 0
  printf '%s %s✔%s %s\n' "$(log_ts)" "${_c_green}" "${_c_reset}" "$*"
}

log_debug() {
  [[ ${VERBOSE} -lt 1 ]] && return 0
  printf '%s %s◎%s %s\n' "$(log_ts)" "${_c_magenta}" "${_c_reset}" "$*"
}

fatal() {
  log_error "$*"
  exit 1
}

# --- Parsing des options communes ---
parse_common_args() {
  COMMON_POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --yes|-y)
        ASSUME_YES=1
        ;;
      --verbose|-v)
        VERBOSE=$((VERBOSE + 1))
        ;;
      --quiet|-q)
        QUIET=1
        ;;
      --no-color)
        NO_COLOR=1
        _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
        ;;
      --help|-h)
        SHOW_HELP=1
        ;;
      --)
        shift
        COMMON_POSITIONAL_ARGS+=("$@")
        break
        ;;
      -*)
        fatal "Option inconnue: $1"
        ;;
      *)
        COMMON_POSITIONAL_ARGS+=("$1")
        ;;
    esac
    shift || true
  done
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    fatal "Ce script doit être exécuté en root (utilisez sudo)."
  fi
}

confirm() {
  local prompt=${1:-"Continuer ?"}
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    log_debug "Confirmation automatique (--yes) pour: ${prompt}"
    return 0
  fi

  read -r -p "${prompt} [y/N]: " response
  case "${response}" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      log_error "Opération annulée."
      exit 1
      ;;
  esac
}

run_cmd() {
  local cmd=("$@")
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] ${cmd[*]}"
    return 0
  fi

  log_debug "Exécution: ${cmd[*]}"
  "${cmd[@]}"
}

run_cmd_sudo() {
  local cmd=("$@")
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] sudo ${cmd[*]}"
    return 0
  fi
  log_debug "Exécution sudo: ${cmd[*]}"
  sudo "${cmd[@]}"
}

check_command() {
  local name=$1
  if ! command -v "${name}" >/dev/null 2>&1; then
    fatal "Commande requise introuvable: ${name}"
  fi
}

retry() {
  local attempts=$1; shift
  local delay=${1:-5}; shift || true
  local cmd=("$@")
  local count=0
  until "${cmd[@]}"; do
    count=$((count + 1))
    if (( count >= attempts )); then
      fatal "Commande échouée après ${attempts} tentatives: ${cmd[*]}"
    fi
    log_warn "Tentative ${count}/${attempts} échouée. Nouvelle tentative dans ${delay}s..."
    sleep "${delay}"
  done
}

detect_os() {
  awk -F= '/^ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"'
}

detect_pretty_os() {
  awk -F= '/^PRETTY_NAME=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"'
}

detect_arch() {
  uname -m
}

ensure_dir() {
  local dir=$1
  if [[ ! -d ${dir} ]]; then
    run_cmd mkdir -p "${dir}"
  fi
}

ensure_file_owner() {
  local path=$1 owner=$2
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] chown ${owner} ${path}"
    return 0
  fi
  chown "${owner}" "${path}"
}

register_cleanup() {
  local fn=$1
  CLEANUP_CALLBACKS+=("${fn}")
}

CLEANUP_CALLBACKS=()

_run_cleanup() {
  local status=$?
  if [[ ${#CLEANUP_CALLBACKS[@]} -gt 0 ]]; then
    log_debug "Exécution des ${#CLEANUP_CALLBACKS[@]} hooks de nettoyage"
    for cb in "${CLEANUP_CALLBACKS[@]}"; do
      if declare -f "${cb}" >/dev/null 2>&1; then
        "${cb}" || log_warn "Nettoyage '${cb}' a échoué"
      else
        log_warn "Hook '${cb}' introuvable"
      fi
    done
  fi
  exit ${status}
}

trap _run_cleanup EXIT

export DRY_RUN ASSUME_YES VERBOSE QUIET NO_COLOR SHOW_HELP
