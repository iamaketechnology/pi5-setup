#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - LOGS COLLECTION WRAPPER
#==============================================================================
# Wrapper script that delegates to common-scripts/07-logs-collect.sh
# Collects and rotates logs from all email services
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_email-common.sh"

# Export log collection variables
export LOG_CONTAINERS=(
    "${ROUNDCUBE_CONTAINER}"
    "${ROUNDCUBE_DB_CONTAINER}"
    "${POSTFIX_CONTAINER}"
    "${DOVECOT_CONTAINER}"
    "${RSPAMD_CONTAINER}"
)

# Delegate to common logs script
exec "${COMMON_SCRIPTS_DIR}/07-logs-collect.sh" "$@"
