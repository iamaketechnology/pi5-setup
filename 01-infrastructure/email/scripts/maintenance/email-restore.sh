#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - RESTORE WRAPPER
#==============================================================================
# Wrapper script that delegates to common-scripts/04b-restore-from-backup.sh
# Restores email stack from backup
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_email-common.sh"

# Delegate to common restore script
exec "${COMMON_SCRIPTS_DIR}/04b-restore-from-backup.sh" "$@"
