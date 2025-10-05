#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

DATA_TARGETS=${DATA_TARGETS:-${SUPABASE_DIR}/volumes}

export POSTGRES_DSN="${SUPABASE_POSTGRES_DSN}" DATA_TARGETS

exec "${COMMON_SCRIPTS_DIR}/04b-restore-from-backup.sh" "$@"
