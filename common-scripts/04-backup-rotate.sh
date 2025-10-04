#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 04-backup-rotate.sh [options]

Crée une sauvegarde compressée (DB + volumes) et applique une rotation GFS.

Variables:
  BACKUP_TARGET_DIR       Répertoire local de sauvegarde (défaut: /opt/backups)
  BACKUP_NAME_PREFIX      Préfixe du nom (défaut: pi5)
  POSTGRES_DSN            Connexion Postgres (ex: postgres://user:pass@host:5432/db)
  DATA_PATHS              Chemins supplémentaires (séparés par des virgules) à archiver
  RCLONE_REMOTE           Remote rclone (optionnel)
  KEEP_DAILY              Nombre de backups quotidiens à conserver (défaut: 7)
  KEEP_WEEKLY             Nombre de backups hebdomadaires (défaut: 4)
  KEEP_MONTHLY            Nombre de backups mensuels (défaut: 6)

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

BACKUP_TARGET_DIR=${BACKUP_TARGET_DIR:-/opt/backups}
BACKUP_NAME_PREFIX=${BACKUP_NAME_PREFIX:-pi5}
POSTGRES_DSN=${POSTGRES_DSN:-}
DATA_PATHS=${DATA_PATHS:-}
RCLONE_REMOTE=${RCLONE_REMOTE:-}
KEEP_DAILY=${KEEP_DAILY:-7}
KEEP_WEEKLY=${KEEP_WEEKLY:-4}
KEEP_MONTHLY=${KEEP_MONTHLY:-6}

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="${BACKUP_TARGET_DIR}/${TIMESTAMP}"
ARCHIVE_NAME="${BACKUP_NAME_PREFIX}-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${BACKUP_TARGET_DIR}/${ARCHIVE_NAME}"

IFS=',' read -r -a DATA_PATH_ARRAY <<< "${DATA_PATHS}"

ensure_dir "${BACKUP_TARGET_DIR}"
ensure_dir "${BACKUP_DIR}"

pg_dump_backup() {
  [[ -n ${POSTGRES_DSN} ]] || return 0
  log_info "Dump Postgres"
  local outfile="${BACKUP_DIR}/postgres.sql"
  local cmd=(pg_dump "${POSTGRES_DSN}" -Fc -f "${outfile}")
  run_cmd "${cmd[@]}"
}

copy_data_paths() {
  local path
  for path in "${DATA_PATH_ARRAY[@]}"; do
    [[ -z ${path} ]] && continue
    local dest="${BACKUP_DIR}$(echo "${path}" | sed 's#/##')"
    log_info "Copie ${path}"
    run_cmd rsync -aH --delete "${path}" "${BACKUP_DIR}/"
  done
}

create_archive() {
  log_info "Compression ${ARCHIVE_NAME}"
  local cwd="${PWD}"
  cd "${BACKUP_DIR}"
  run_cmd tar -czf "${ARCHIVE_PATH}" .
  cd "${cwd}"
}

upload_rclone() {
  [[ -n ${RCLONE_REMOTE} ]] || return 0
  log_info "Upload rclone -> ${RCLONE_REMOTE}"
  run_cmd rclone copy "${ARCHIVE_PATH}" "${RCLONE_REMOTE}"
}

apply_rotation() {
  log_info "Rotation GFS"
  local list
  mapfile -t list < <(find "${BACKUP_TARGET_DIR}" -maxdepth 1 -type f -name "${BACKUP_NAME_PREFIX}-*.tar.gz" | sort)
  local now_epoch=$(date +%s)
  local keep=()
  local daily_count=0 weekly_count=0 monthly_count=0
  local file
  for file in "${list[@]}"; do
    local base=$(basename "${file}")
    local stamp=${base#${BACKUP_NAME_PREFIX}-}
    stamp=${stamp%.tar.gz}
    local file_date=$(date -d "${stamp:0:8}" +%s 2>/dev/null || echo 0)
    local age_days=$(( (now_epoch - file_date) / 86400 ))
    if (( age_days <= 7 && daily_count < KEEP_DAILY )); then
      keep+=("${file}")
      ((daily_count++))
    elif (( age_days <= 31 && weekly_count < KEEP_WEEKLY )); then
      keep+=("${file}")
      ((weekly_count++))
    elif (( monthly_count < KEEP_MONTHLY )); then
      keep+=("${file}")
      ((monthly_count++))
    fi
  done

  local to_delete=()
  for file in "${list[@]}"; do
    local skip=0
    local k
    for k in "${keep[@]}"; do
      [[ ${file} == "${k}" ]] && skip=1 && break
    done
    if (( skip == 0 )); then
      to_delete+=("${file}")
    fi
  done

  local f
  for f in "${to_delete[@]}"; do
    log_info "Suppression ancienne sauvegarde ${f}"
    run_cmd rm -f "${f}"
  done
}

cleanup_tmp() {
  [[ -d ${BACKUP_DIR} ]] || return
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] rm -rf ${BACKUP_DIR}"
    return
  fi
  rm -rf "${BACKUP_DIR}"
}

register_cleanup cleanup_tmp

main() {
  pg_dump_backup
  copy_data_paths
  create_archive
  upload_rclone
  apply_rotation
  log_success "Backup créé: ${ARCHIVE_PATH}"
}

main "$@"
