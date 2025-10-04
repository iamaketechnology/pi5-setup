#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

BACKUP_TARGET_DIR=${BACKUP_TARGET_DIR:-/home/${SUDO_USER:-$USER}/backups/supabase}
DATA_PATHS=${DATA_PATHS:-${SUPABASE_DIR}/volumes}

export BACKUP_TARGET_DIR BACKUP_NAME_PREFIX="supabase" POSTGRES_DSN="${SUPABASE_POSTGRES_DSN}" DATA_PATHS

exec "${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh" "$@"
