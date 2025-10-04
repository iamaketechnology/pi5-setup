#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_supabase-common.sh"

HTTP_ENDPOINTS=${HTTP_ENDPOINTS:-http://localhost:8000/health,http://localhost:54323/status}
DOCKER_COMPOSE_DIRS=${DOCKER_COMPOSE_DIRS:-${SUPABASE_DIR}}
REPORT_DIR=${REPORT_DIR:-${SUPABASE_DIR}/reports}
REPORT_PREFIX=${REPORT_PREFIX:-supabase-health}

export HTTP_ENDPOINTS DOCKER_COMPOSE_DIRS REPORT_DIR REPORT_PREFIX

exec "${COMMON_SCRIPTS_DIR}/05-healthcheck-report.sh" "$@"
