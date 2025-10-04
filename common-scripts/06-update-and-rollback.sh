#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 06-update-and-rollback.sh [options]

Met à jour un projet docker compose et permet un rollback automatique.

Variables:
  COMPOSE_PROJECT_DIR   Répertoire docker compose (obligatoire)
  HEALTHCHECK_URL       URL à tester après mise à jour (optionnel)
  BACKUP_IMAGES         1 pour sauvegarder les images actuelles (défaut: 1)
  ROLLBACK_ON_FAILURE   1 pour rollback si healthcheck échoue (défaut: 1)

Options:
  --dry-run        Simule
  --yes, -y        Confirme
  --verbose, -v    Verbosité
  --quiet, -q      Silencieux
  --no-color       Sans couleurs
  --help, -h       Aide
  update           Effectuer une mise à jour
  rollback         Revenir à la sauvegarde précédente
USAGE
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

ACTION=${1:-update}
shift || true

COMPOSE_PROJECT_DIR=${COMPOSE_PROJECT_DIR:-}
HEALTHCHECK_URL=${HEALTHCHECK_URL:-}
BACKUP_IMAGES=${BACKUP_IMAGES:-1}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-1}

if [[ -z ${COMPOSE_PROJECT_DIR} ]]; then
  fatal "COMPOSE_PROJECT_DIR est requis"
fi

if [[ ! -d ${COMPOSE_PROJECT_DIR} ]]; then
  fatal "Répertoire ${COMPOSE_PROJECT_DIR} introuvable"
fi

BACKUP_DIR="${COMPOSE_PROJECT_DIR}/.compose-backup"
IMAGES_FILE="${BACKUP_DIR}/images.txt"

ensure_dir "${BACKUP_DIR}"

backup_images() {
  [[ ${BACKUP_IMAGES} -eq 1 ]] || return 0
  log_info "Sauvegarde des images actuelles"
  local cwd="${PWD}"
  cd "${COMPOSE_PROJECT_DIR}"
  local images
  images=$(docker compose ps --format '{{.Image}}' | sort -u)
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] enregistrer images -> ${IMAGES_FILE}"
  else
    printf '%s\n' "${images}" >"${IMAGES_FILE}"
  fi
  cd "${cwd}"
}

update_stack() {
  log_info "Mise à jour docker compose"
  local cwd="${PWD}"
  cd "${COMPOSE_PROJECT_DIR}"
  run_cmd docker compose pull
  run_cmd docker compose down
  run_cmd docker compose up -d
  cd "${cwd}"
}

healthcheck() {
  [[ -n ${HEALTHCHECK_URL} ]] || return 0
  log_info "Healthcheck ${HEALTHCHECK_URL}"
  local status
  status=$(curl -sk -o /dev/null -w '%{http_code}' "${HEALTHCHECK_URL}" 2>/dev/null || echo "000")
  if [[ ${status} != 2* && ${status} != 3* ]]; then
    log_warn "Healthcheck KO (${status})"
    return 1
  fi
  log_success "Healthcheck OK (${status})"
}

restore_images() {
  [[ -f ${IMAGES_FILE} ]] || { log_warn "Aucune sauvegarde d'images"; return 0; }
  log_info "Rollback des images"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] docker pull depuis ${IMAGES_FILE}"
    return
  fi
  while read -r image; do
    [[ -z ${image} ]] && continue
    docker pull "${image}" || log_warn "Pull ${image} échoué"
  done <"${IMAGES_FILE}"
}

rollback_stack() {
  log_info "Rollback docker compose"
  local cwd="${PWD}"
  cd "${COMPOSE_PROJECT_DIR}"
  run_cmd docker compose down
  if [[ -f ${IMAGES_FILE} ]]; then
    while read -r image; do
      [[ -z ${image} ]] && continue
      run_cmd docker pull "${image}"
    done <"${IMAGES_FILE}"
  fi
  run_cmd docker compose up -d
  cd "${cwd}"
  log_success "Rollback terminé"
}

main_update() {
  backup_images
  update_stack
  if ! healthcheck; then
    if [[ ${ROLLBACK_ON_FAILURE} -eq 1 ]]; then
      log_warn "Rollback automatique en cours"
      rollback_stack
      fatal "Mise à jour échouée, rollback effectué"
    else
      fatal "Mise à jour échouée (healthcheck)"
    fi
  fi
  log_success "Mise à jour réussie"
}

main_rollback() {
  rollback_stack
}

case "${ACTION}" in
  update)
    main_update
    ;;
  rollback)
    main_rollback
    ;;
  *)
    fatal "Action inconnue: ${ACTION}"
    ;;
 esac
