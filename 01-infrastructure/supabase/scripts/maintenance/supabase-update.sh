#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

HEALTHCHECK_URL=${HEALTHCHECK_URL:-http://localhost:8000/health}

export COMPOSE_PROJECT_DIR="${COMPOSE_PROJECT_DIR}" HEALTHCHECK_URL

exec "${COMMON_SCRIPTS_DIR}/06-update-and-rollback.sh" "$@"
