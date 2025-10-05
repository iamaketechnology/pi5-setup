#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../../" && pwd)"
COMMON_SCRIPTS_DIR="${ROOT_DIR}/common-scripts"

source "${COMMON_SCRIPTS_DIR}/lib.sh"

SUPABASE_DIR=${SUPABASE_DIR:-/home/${SUDO_USER:-$USER}/stacks/supabase}
COMPOSE_PROJECT_DIR=${COMPOSE_PROJECT_DIR:-${SUPABASE_DIR}}
SUPABASE_ENV_FILE=${SUPABASE_ENV_FILE:-${SUPABASE_DIR}/.env}
SUPABASE_POSTGRES_DSN=${SUPABASE_POSTGRES_DSN:-postgres://postgres:$(grep -m1 POSTGRES_PASSWORD "${SUPABASE_ENV_FILE}" 2>/dev/null | cut -d= -f2)@localhost:5432/postgres}

if [[ ! -d ${SUPABASE_DIR} ]]; then
  log_warn "Répertoire Supabase (${SUPABASE_DIR}) introuvable. Ajustez SUPABASE_DIR."
fi
