#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

BACKUP_SCRIPT=${BACKUP_SCRIPT:-${ROOT_DIR}/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh}
HEALTHCHECK_SCRIPT=${HEALTHCHECK_SCRIPT:-${ROOT_DIR}/pi5-supabase-stack/scripts/maintenance/supabase-healthcheck.sh}
LOGS_SCRIPT=${LOGS_SCRIPT:-${ROOT_DIR}/pi5-supabase-stack/scripts/maintenance/supabase-logs.sh}

export BACKUP_SCRIPT HEALTHCHECK_SCRIPT LOGS_SCRIPT

exec "${COMMON_SCRIPTS_DIR}/08-scheduler-setup.sh" "$@"
