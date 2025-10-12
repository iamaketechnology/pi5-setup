#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - HEALTHCHECK WRAPPER
#==============================================================================
# Wrapper script that delegates to common-scripts/05-healthcheck-report.sh
# Monitors Roundcube, Postfix, Dovecot, Rspamd health
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_email-common.sh"

# Export healthcheck-specific variables
export HEALTHCHECK_SERVICES=(
    "${ROUNDCUBE_CONTAINER}:${ROUNDCUBE_HEALTH_URL}"
    "${ROUNDCUBE_DB_CONTAINER}:postgres"
    "${POSTFIX_CONTAINER}:smtp"
    "${DOVECOT_CONTAINER}:imap"
)

# Delegate to common healthcheck script
exec "${COMMON_SCRIPTS_DIR}/05-healthcheck-report.sh" "$@"
