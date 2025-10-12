#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - BACKUP WRAPPER
#==============================================================================
# Wrapper script that delegates to common-scripts/04-backup-rotate.sh
# Backs up Roundcube DB, mail DB, and mail data with GFS rotation
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_email-common.sh"

# Export backup-specific variables
export BACKUP_SOURCES=(
    "docker:${ROUNDCUBE_DB_CONTAINER}:postgres:roundcube:/var/lib/postgresql/data"
    "docker:${MAIL_DB_CONTAINER}:postgres:mailserver:/var/lib/postgresql/data"
    "volume:dovecot-data"
    "volume:postfix-queue"
    "directory:${EMAIL_CONFIG_DIR}"
)

# Delegate to common backup script
exec "${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh" "$@"
