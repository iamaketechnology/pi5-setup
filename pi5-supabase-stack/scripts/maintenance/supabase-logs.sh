#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

OUTPUT_DIR=${OUTPUT_DIR:-${SUPABASE_DIR}/reports}
DOCKER_COMPOSE_DIRS=${DOCKER_COMPOSE_DIRS:-${SUPABASE_DIR}}
TAIL_LINES=${TAIL_LINES:-2000}

export OUTPUT_DIR DOCKER_COMPOSE_DIRS TAIL_LINES

exec "${COMMON_SCRIPTS_DIR}/07-logs-collect.sh" "$@"
