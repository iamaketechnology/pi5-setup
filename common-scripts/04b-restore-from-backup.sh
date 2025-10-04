#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 04b-restore-from-backup.sh [options] <archive>

Restaure une sauvegarde créée avec 04-backup-rotate.

Arguments:
  archive    Fichier tar.gz de sauvegarde ou dossier (si déjà extrait)

Variables:
  RESTORE_TARGET_DIR      Dossier temporaire (défaut: /opt/backups/tmp-restore)
  POSTGRES_DSN            Connexion Postgres pour restauration
  DATA_TARGETS            Chemins de destination (correspondants à DATA_PATHS, séparés par des virgules)

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

if [[ $# -lt 1 ]]; then
  fatal "Archive de sauvegarde requise"
fi

ARCHIVE=$1
shift || true

require_root

RESTORE_TARGET_DIR=${RESTORE_TARGET_DIR:-/opt/backups/tmp-restore}
POSTGRES_DSN=${POSTGRES_DSN:-}
DATA_TARGETS=${DATA_TARGETS:-}
IFS=',' read -r -a DATA_TARGET_ARRAY <<< "${DATA_TARGETS}"

ensure_dir "${RESTORE_TARGET_DIR}"

extract_archive() {
  if [[ -d ${ARCHIVE} ]]; then
    RESTORE_DIR=${ARCHIVE}
    log_info "Utilisation du répertoire existant ${RESTORE_DIR}"
    return
  fi
  RESTORE_DIR="${RESTORE_TARGET_DIR}/$(basename "${ARCHIVE}" .tar.gz)"
  ensure_dir "${RESTORE_DIR}"
  log_info "Extraction ${ARCHIVE}"
  run_cmd tar -xzf "${ARCHIVE}" -C "${RESTORE_DIR}"
}

restore_postgres() {
  [[ -n ${POSTGRES_DSN} ]] || return 0
  local dump_file="${RESTORE_DIR}/postgres.sql"
  if [[ ! -f ${dump_file} ]]; then
    log_warn "Dump Postgres absent (${dump_file}). Ignoré."
    return 0
  fi
  confirm "Restauration Postgres vers ${POSTGRES_DSN}. Continuer ?"
  log_info "Restauration Postgres"
  run_cmd pg_restore --clean --no-owner --if-exists -d "${POSTGRES_DSN}" "${dump_file}"
}

restore_data_paths() {
  local idx=0
  local target
  for target in "${DATA_TARGET_ARRAY[@]}"; do
    [[ -z ${target} ]] && continue
    local basename
    basename=$(basename "${target}")
    local source="${RESTORE_DIR}/${basename}"
    if [[ ! -d ${source} ]]; then
      log_warn "Répertoire ${source} introuvable dans la sauvegarde."
      ((idx++))
      continue
    fi
    confirm "Restaurer ${source} -> ${target} ?" || true
    ensure_dir "${target}"
    run_cmd rsync -aH "${source}/" "${target}/"
    ((idx++))
  done
}

cleanup_tmp() {
  [[ -d ${RESTORE_TARGET_DIR} ]] || return
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] rm -rf ${RESTORE_TARGET_DIR}"
    return
  fi
  rm -rf "${RESTORE_TARGET_DIR}"
}

register_cleanup cleanup_tmp

main() {
  extract_archive
  restore_postgres
  restore_data_paths
  log_success "Restauration terminée"
}

main "$@"
