#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: secrets-setup.sh [options] --template <.env.example> --output <.env>

Génère un fichier .env à partir d'un template en remplissant les valeurs manquantes.

Options:
  --template PATH   Fichier .env.example (obligatoire)
  --output PATH     Fichier .env généré (obligatoire)
  --force           Écrase si le fichier existe
  --dry-run         Simule
  --yes, -y         Confirme
  --verbose, -v     Verbosité
  --quiet, -q       Silencieux
  --no-color        Sans couleurs
  --help, -h        Aide
USAGE
}

FORCE=0
TEMPLATE=""
OUTPUT=""

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --template)
        TEMPLATE=$2; shift 2 || fatal "Argument manquant pour --template"
        ;;
      --output)
        OUTPUT=$2; shift 2 || fatal "Argument manquant pour --output"
        ;;
      --force)
        FORCE=1; shift
        ;;
      --help|-h)
        SHOW_HELP=1; shift
        ;;
      *)
        COMMON_ARGS+=("$1"); shift
        ;;
    esac
  done
}

COMMON_ARGS=()
parse_common_args "$@"
parse_args "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

[[ -n ${TEMPLATE} ]] || fatal "--template requis"
[[ -n ${OUTPUT} ]] || fatal "--output requis"

if [[ ! -f ${TEMPLATE} ]]; then
  fatal "Template introuvable: ${TEMPLATE}"
fi

if [[ -f ${OUTPUT} && ${FORCE} -ne 1 ]]; then
  fatal "${OUTPUT} existe déjà. Utilisez --force pour écraser."
fi

generate_secret() {
  local length=${1:-32}
  head -c 2048 /dev/urandom | tr -dc 'A-Za-z0-9_-' | head -c "${length}"
}

generate_env() {
  log_info "Génération ${OUTPUT}"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] copier ${TEMPLATE}"
    return
  fi

  while IFS= read -r line; do
    if [[ ${line} =~ ^[A-Za-z0-9_]+=_RANDOM_[0-9]+$ ]]; then
      local key=${line%%=*}
      local marker=${line#*=}
      local length=${marker#_RANDOM_}
      printf '%s=%s\n' "${key}" "$(generate_secret "${length}")"
    else
      printf '%s\n' "${line}"
    fi
  done <"${TEMPLATE}" >"${OUTPUT}"
  chmod 600 "${OUTPUT}"
}

main() {
  generate_env
  log_success "Secrets générés dans ${OUTPUT}"
}

main "$@"
