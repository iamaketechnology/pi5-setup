#!/usr/bin/env bash
#==============================================================================
# PI5-EMAIL-STACK - UPDATE WRAPPER
#==============================================================================
# Wrapper script that delegates to common-scripts/06-update-and-rollback.sh
# Updates email stack with automatic rollback on failure
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/_email-common.sh"

# Delegate to common update script
exec "${COMMON_SCRIPTS_DIR}/06-update-and-rollback.sh" "$@"
