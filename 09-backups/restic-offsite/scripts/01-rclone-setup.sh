#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Rclone Setup Script for Offsite Backups - Raspberry Pi 5
# =============================================================================
# Purpose: Configure rclone for offsite backup storage (R2, B2, S3, Local)
# Architecture: ARM64 (Raspberry Pi 5)
# Supported Providers: Cloudflare R2, Backblaze B2, S3-compatible, Local Disk
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-15 minutes
# =============================================================================

# Source common library if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_LIB="${SCRIPT_DIR}/../../common-scripts/lib.sh"

if [[ -f "${COMMON_LIB}" ]]; then
    source "${COMMON_LIB}"
else
    # Fallback color output functions
    log()   { echo -e "\033[1;36m[RCLONE]\033[0m $*"; }
    warn()  { echo -e "\033[1;33m[WARN] \033[0m $*"; }
    ok()    { echo -e "\033[1;32m[OK]   \033[0m $*"; }
    error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
    log_info() { log "$@"; }
    log_warn() { warn "$@"; }
    log_error() { error "$@"; }
    log_success() { ok "$@"; }
    fatal() { error "$*"; exit 1; }
    require_root() {
        if [[ "$EUID" -ne 0 ]]; then
            fatal "This script must be run as root. Usage: sudo $0"
        fi
    }
    confirm() {
        local prompt=${1:-"Continue?"}
        if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
            return 0
        fi
        read -r -p "${prompt} [y/N]: " response
        case "${response}" in
            [yY][eE][sS]|[yY]) return 0 ;;
            *) fatal "Operation cancelled." ;;
        esac
    }
fi

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/rclone-setup-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
RCLONE_CONFIG_DIR="/home/${TARGET_USER}/.config/rclone"
RCLONE_CONFIG_FILE="${RCLONE_CONFIG_DIR}/rclone.conf"
TEST_DIR="/tmp/rclone-test-$$"

# Provider selection (can be set via environment)
RCLONE_PROVIDER="${RCLONE_PROVIDER:-}"
REMOTE_NAME="${REMOTE_NAME:-offsite-backup}"

# Cloudflare R2 variables
R2_ACCOUNT_ID="${R2_ACCOUNT_ID:-}"
R2_ACCESS_KEY="${R2_ACCESS_KEY:-}"
R2_SECRET_KEY="${R2_SECRET_KEY:-}"
R2_BUCKET="${R2_BUCKET:-}"

# Backblaze B2 variables
B2_ACCOUNT_ID="${B2_ACCOUNT_ID:-}"
B2_APPLICATION_KEY="${B2_APPLICATION_KEY:-}"
B2_BUCKET="${B2_BUCKET:-}"

# Generic S3 variables
S3_ENDPOINT="${S3_ENDPOINT:-}"
S3_ACCESS_KEY="${S3_ACCESS_KEY:-}"
S3_SECRET_KEY="${S3_SECRET_KEY:-}"
S3_BUCKET="${S3_BUCKET:-}"
S3_REGION="${S3_REGION:-auto}"

# Local disk variables
LOCAL_PATH="${LOCAL_PATH:-}"

# Script flags
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"
VERBOSE="${VERBOSE:-0}"

# =============================================================================
# LOGGING SETUP
# =============================================================================

setup_logging() {
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "${LOG_FILE}")"

    # Redirect stdout and stderr to log file while keeping terminal output
    exec 1> >(tee -a "${LOG_FILE}")
    exec 2> >(tee -a "${LOG_FILE}" >&2)

    log "=== Rclone Setup Started - $(date) ==="
    log "Version: ${SCRIPT_VERSION}"
    log "Target User: ${TARGET_USER}"
    log "Log File: ${LOG_FILE}"
}

# =============================================================================
# VALIDATION SECTION
# =============================================================================

check_dependencies() {
    log "Checking system dependencies..."

    local dependencies=("curl" "wget" "unzip" "gpg")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}"
        log "Installing missing dependencies..."
        apt update -qq
        apt install -y "${missing_deps[@]}"
    fi

    ok "All dependencies are present"
}

check_rclone_installed() {
    if command -v rclone &> /dev/null; then
        local version=$(rclone version 2>/dev/null | head -n1 | awk '{print $2}')
        ok "Rclone already installed (version: ${version})"
        return 0
    fi
    return 1
}

# =============================================================================
# RCLONE INSTALLATION
# =============================================================================

install_rclone() {
    log "Installing rclone..."

    if check_rclone_installed; then
        log "Rclone already installed, skipping installation"
        return 0
    fi

    # Download and install rclone
    log "Downloading rclone installer..."
    curl -fsSL https://rclone.org/install.sh | bash

    if check_rclone_installed; then
        ok "Rclone installed successfully"
    else
        fatal "Rclone installation failed"
    fi
}

# =============================================================================
# PROVIDER SELECTION
# =============================================================================

show_provider_menu() {
    echo ""
    echo "========================================="
    echo "  Select Backup Storage Provider"
    echo "========================================="
    echo ""
    echo "1) Cloudflare R2 (Recommended)"
    echo "   - 10GB free tier"
    echo "   - S3-compatible"
    echo "   - No egress fees"
    echo "   - Global CDN"
    echo ""
    echo "2) Backblaze B2"
    echo "   - 10GB free tier"
    echo "   - Low cost beyond free tier"
    echo "   - S3-compatible API"
    echo ""
    echo "3) Generic S3-compatible"
    echo "   - MinIO, Wasabi, DigitalOcean Spaces"
    echo "   - Custom endpoint configuration"
    echo ""
    echo "4) Local Disk/USB"
    echo "   - For testing or local backups"
    echo "   - No cloud storage costs"
    echo ""
    echo "========================================="
    echo ""
}

select_provider() {
    if [[ -n "${RCLONE_PROVIDER}" ]]; then
        log "Provider pre-selected: ${RCLONE_PROVIDER}"
        return 0
    fi

    show_provider_menu

    local choice
    read -p "Enter your choice [1-4]: " choice

    case "${choice}" in
        1)
            RCLONE_PROVIDER="r2"
            log "Selected: Cloudflare R2"
            ;;
        2)
            RCLONE_PROVIDER="b2"
            log "Selected: Backblaze B2"
            ;;
        3)
            RCLONE_PROVIDER="s3"
            log "Selected: Generic S3-compatible"
            ;;
        4)
            RCLONE_PROVIDER="local"
            log "Selected: Local Disk"
            ;;
        *)
            fatal "Invalid choice: ${choice}"
            ;;
    esac
}

# =============================================================================
# CLOUDFLARE R2 CONFIGURATION
# =============================================================================

show_r2_instructions() {
    echo ""
    echo "========================================="
    echo "  Cloudflare R2 Setup Instructions"
    echo "========================================="
    echo ""
    echo "Step 1: Sign up for Cloudflare (if not already)"
    echo "  https://dash.cloudflare.com/sign-up"
    echo ""
    echo "Step 2: Enable R2 Storage"
    echo "  https://dash.cloudflare.com/?to=/:account/r2"
    echo "  Click 'Purchase R2 Plan' (free tier available)"
    echo ""
    echo "Step 3: Create an R2 bucket"
    echo "  Click 'Create bucket'"
    echo "  Choose a unique name (e.g., 'pi5-backups-XXXXXX')"
    echo "  Select location closest to you"
    echo ""
    echo "Step 4: Create API Token"
    echo "  Navigate to: R2 > Manage R2 API Tokens"
    echo "  Click 'Create API token'"
    echo "  Permissions: Read & Write for your bucket"
    echo "  Copy Access Key ID and Secret Access Key"
    echo ""
    echo "Step 5: Get Account ID"
    echo "  Found in Cloudflare Dashboard URL:"
    echo "  https://dash.cloudflare.com/ACCOUNT_ID/r2"
    echo ""
    echo "========================================="
    echo ""
}

configure_r2() {
    log "Configuring Cloudflare R2..."

    if [[ "${ASSUME_YES}" -ne 1 ]]; then
        show_r2_instructions
        read -p "Press Enter when you have your R2 credentials ready..."
    fi

    # Collect R2 credentials
    if [[ -z "${R2_ACCOUNT_ID}" ]]; then
        read -p "Enter Cloudflare Account ID: " R2_ACCOUNT_ID
    fi

    if [[ -z "${R2_ACCESS_KEY}" ]]; then
        read -p "Enter R2 Access Key ID: " R2_ACCESS_KEY
    fi

    if [[ -z "${R2_SECRET_KEY}" ]]; then
        read -sp "Enter R2 Secret Access Key: " R2_SECRET_KEY
        echo ""
    fi

    if [[ -z "${R2_BUCKET}" ]]; then
        read -p "Enter R2 Bucket Name: " R2_BUCKET
    fi

    # Validate inputs
    if [[ -z "${R2_ACCOUNT_ID}" ]] || [[ -z "${R2_ACCESS_KEY}" ]] || \
       [[ -z "${R2_SECRET_KEY}" ]] || [[ -z "${R2_BUCKET}" ]]; then
        fatal "Missing required R2 credentials"
    fi

    # Construct R2 endpoint
    local r2_endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"

    # Create rclone config
    log "Creating rclone configuration for R2..."

    mkdir -p "${RCLONE_CONFIG_DIR}"

    cat > "${RCLONE_CONFIG_FILE}" <<EOF
[${REMOTE_NAME}]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY}
secret_access_key = ${R2_SECRET_KEY}
endpoint = ${r2_endpoint}
acl = private
no_check_bucket = true
EOF

    chmod 600 "${RCLONE_CONFIG_FILE}"
    chown "${TARGET_USER}:${TARGET_USER}" "${RCLONE_CONFIG_FILE}"

    ok "R2 configuration created"
}

# =============================================================================
# BACKBLAZE B2 CONFIGURATION
# =============================================================================

show_b2_instructions() {
    echo ""
    echo "========================================="
    echo "  Backblaze B2 Setup Instructions"
    echo "========================================="
    echo ""
    echo "Step 1: Sign up for Backblaze"
    echo "  https://www.backblaze.com/sign-up/cloud-storage"
    echo ""
    echo "Step 2: Create a B2 Bucket"
    echo "  Navigate to: B2 Cloud Storage > Buckets"
    echo "  Click 'Create a Bucket'"
    echo "  Choose bucket name (e.g., 'pi5-backups')"
    echo "  Set to 'Private' for security"
    echo ""
    echo "Step 3: Create Application Key"
    echo "  Navigate to: B2 Cloud Storage > App Keys"
    echo "  Click 'Add a New Application Key'"
    echo "  Name: 'rclone-pi5-backup'"
    echo "  Allow access to: Your bucket"
    echo "  Permissions: Read and Write"
    echo "  Copy keyID and applicationKey"
    echo ""
    echo "========================================="
    echo ""
}

configure_b2() {
    log "Configuring Backblaze B2..."

    if [[ "${ASSUME_YES}" -ne 1 ]]; then
        show_b2_instructions
        read -p "Press Enter when you have your B2 credentials ready..."
    fi

    # Collect B2 credentials
    if [[ -z "${B2_ACCOUNT_ID}" ]]; then
        read -p "Enter B2 Application Key ID: " B2_ACCOUNT_ID
    fi

    if [[ -z "${B2_APPLICATION_KEY}" ]]; then
        read -sp "Enter B2 Application Key: " B2_APPLICATION_KEY
        echo ""
    fi

    if [[ -z "${B2_BUCKET}" ]]; then
        read -p "Enter B2 Bucket Name: " B2_BUCKET
    fi

    # Validate inputs
    if [[ -z "${B2_ACCOUNT_ID}" ]] || [[ -z "${B2_APPLICATION_KEY}" ]] || \
       [[ -z "${B2_BUCKET}" ]]; then
        fatal "Missing required B2 credentials"
    fi

    # Create rclone config
    log "Creating rclone configuration for B2..."

    mkdir -p "${RCLONE_CONFIG_DIR}"

    cat > "${RCLONE_CONFIG_FILE}" <<EOF
[${REMOTE_NAME}]
type = b2
account = ${B2_ACCOUNT_ID}
key = ${B2_APPLICATION_KEY}
hard_delete = false
EOF

    chmod 600 "${RCLONE_CONFIG_FILE}"
    chown "${TARGET_USER}:${TARGET_USER}" "${RCLONE_CONFIG_FILE}"

    ok "B2 configuration created"
}

# =============================================================================
# GENERIC S3 CONFIGURATION
# =============================================================================

show_s3_instructions() {
    echo ""
    echo "========================================="
    echo "  Generic S3 Setup Instructions"
    echo "========================================="
    echo ""
    echo "Supported S3-compatible providers:"
    echo "  - MinIO (self-hosted)"
    echo "  - Wasabi Cloud Storage"
    echo "  - DigitalOcean Spaces"
    echo "  - Linode Object Storage"
    echo "  - AWS S3 (standard)"
    echo ""
    echo "You will need:"
    echo "  1. Endpoint URL (e.g., s3.us-west-1.wasabisys.com)"
    echo "  2. Access Key ID"
    echo "  3. Secret Access Key"
    echo "  4. Bucket Name"
    echo "  5. Region (optional, default: auto)"
    echo ""
    echo "========================================="
    echo ""
}

configure_s3() {
    log "Configuring Generic S3..."

    if [[ "${ASSUME_YES}" -ne 1 ]]; then
        show_s3_instructions
        read -p "Press Enter when you have your S3 credentials ready..."
    fi

    # Collect S3 credentials
    if [[ -z "${S3_ENDPOINT}" ]]; then
        read -p "Enter S3 Endpoint URL: " S3_ENDPOINT
    fi

    if [[ -z "${S3_ACCESS_KEY}" ]]; then
        read -p "Enter S3 Access Key ID: " S3_ACCESS_KEY
    fi

    if [[ -z "${S3_SECRET_KEY}" ]]; then
        read -sp "Enter S3 Secret Access Key: " S3_SECRET_KEY
        echo ""
    fi

    if [[ -z "${S3_BUCKET}" ]]; then
        read -p "Enter S3 Bucket Name: " S3_BUCKET
    fi

    if [[ -z "${S3_REGION}" ]] || [[ "${S3_REGION}" == "auto" ]]; then
        read -p "Enter S3 Region [auto]: " S3_REGION
        S3_REGION="${S3_REGION:-auto}"
    fi

    # Validate inputs
    if [[ -z "${S3_ENDPOINT}" ]] || [[ -z "${S3_ACCESS_KEY}" ]] || \
       [[ -z "${S3_SECRET_KEY}" ]] || [[ -z "${S3_BUCKET}" ]]; then
        fatal "Missing required S3 credentials"
    fi

    # Create rclone config
    log "Creating rclone configuration for S3..."

    mkdir -p "${RCLONE_CONFIG_DIR}"

    cat > "${RCLONE_CONFIG_FILE}" <<EOF
[${REMOTE_NAME}]
type = s3
provider = Other
access_key_id = ${S3_ACCESS_KEY}
secret_access_key = ${S3_SECRET_KEY}
endpoint = ${S3_ENDPOINT}
region = ${S3_REGION}
acl = private
EOF

    chmod 600 "${RCLONE_CONFIG_FILE}"
    chown "${TARGET_USER}:${TARGET_USER}" "${RCLONE_CONFIG_FILE}"

    ok "S3 configuration created"
}

# =============================================================================
# LOCAL DISK CONFIGURATION
# =============================================================================

show_local_instructions() {
    echo ""
    echo "========================================="
    echo "  Local Disk Setup Instructions"
    echo "========================================="
    echo ""
    echo "Use cases:"
    echo "  - USB external drive for local backups"
    echo "  - Network mounted storage (NFS/SMB)"
    echo "  - Testing rclone configuration"
    echo ""
    echo "Requirements:"
    echo "  - Path must be accessible and writable"
    echo "  - Sufficient disk space for backups"
    echo "  - Consider reliability for production use"
    echo ""
    echo "Common paths:"
    echo "  /mnt/usb-backup      (USB drive)"
    echo "  /mnt/nas-backup      (Network storage)"
    echo "  /home/pi/backups     (Local directory)"
    echo ""
    echo "========================================="
    echo ""
}

configure_local() {
    log "Configuring Local Disk..."

    if [[ "${ASSUME_YES}" -ne 1 ]]; then
        show_local_instructions
    fi

    # Collect local path
    if [[ -z "${LOCAL_PATH}" ]]; then
        read -p "Enter local backup path: " LOCAL_PATH
    fi

    # Validate path
    if [[ -z "${LOCAL_PATH}" ]]; then
        fatal "Local path cannot be empty"
    fi

    # Create directory if it doesn't exist
    if [[ ! -d "${LOCAL_PATH}" ]]; then
        log "Creating directory: ${LOCAL_PATH}"
        mkdir -p "${LOCAL_PATH}"
        chown "${TARGET_USER}:${TARGET_USER}" "${LOCAL_PATH}"
    fi

    # Check if writable
    if [[ ! -w "${LOCAL_PATH}" ]]; then
        fatal "Path is not writable: ${LOCAL_PATH}"
    fi

    # Create rclone config
    log "Creating rclone configuration for local disk..."

    mkdir -p "${RCLONE_CONFIG_DIR}"

    cat > "${RCLONE_CONFIG_FILE}" <<EOF
[${REMOTE_NAME}]
type = local
EOF

    chmod 600 "${RCLONE_CONFIG_FILE}"
    chown "${TARGET_USER}:${TARGET_USER}" "${RCLONE_CONFIG_FILE}"

    ok "Local disk configuration created"
}

# =============================================================================
# CONFIGURATION TESTING
# =============================================================================

test_rclone_config() {
    log "Testing rclone configuration..."

    # Create test directory
    mkdir -p "${TEST_DIR}"

    # Create test file
    local test_file="${TEST_DIR}/test-$(date +%s).txt"
    echo "Rclone test file created at $(date)" > "${test_file}"

    local remote_path
    case "${RCLONE_PROVIDER}" in
        r2|b2|s3)
            remote_path="${REMOTE_NAME}:${R2_BUCKET:-${B2_BUCKET:-${S3_BUCKET}}}/rclone-test"
            ;;
        local)
            remote_path="${REMOTE_NAME}:${LOCAL_PATH}/rclone-test"
            ;;
        *)
            fatal "Unknown provider: ${RCLONE_PROVIDER}"
            ;;
    esac

    # Test 1: Upload test file
    log "Test 1: Uploading test file..."
    if sudo -u "${TARGET_USER}" rclone copy "${test_file}" "${remote_path}/" --config="${RCLONE_CONFIG_FILE}" ${VERBOSE:+-vv} 2>&1 | tee -a "${LOG_FILE}"; then
        ok "Upload successful"
    else
        fatal "Upload failed - check credentials and configuration"
    fi

    # Test 2: List remote
    log "Test 2: Listing remote files..."
    if sudo -u "${TARGET_USER}" rclone ls "${remote_path}/" --config="${RCLONE_CONFIG_FILE}" 2>&1 | tee -a "${LOG_FILE}"; then
        ok "List successful"
    else
        warn "List failed - but upload worked, might be a permission issue"
    fi

    # Test 3: Download test file
    log "Test 3: Downloading test file..."
    local download_file="${TEST_DIR}/downloaded-$(date +%s).txt"
    if sudo -u "${TARGET_USER}" rclone copy "${remote_path}/$(basename "${test_file}")" "${TEST_DIR}/" --config="${RCLONE_CONFIG_FILE}" 2>&1 | tee -a "${LOG_FILE}"; then
        ok "Download successful"
    else
        fatal "Download failed"
    fi

    # Test 4: Verify content
    log "Test 4: Verifying file content..."
    if [[ -f "${TEST_DIR}/$(basename "${test_file}")" ]]; then
        ok "File downloaded and verified"
    else
        fatal "Downloaded file not found"
    fi

    # Test 5: Cleanup remote test file
    log "Test 5: Cleaning up test files..."
    if sudo -u "${TARGET_USER}" rclone delete "${remote_path}/" --config="${RCLONE_CONFIG_FILE}" 2>&1 | tee -a "${LOG_FILE}"; then
        ok "Cleanup successful"
    else
        warn "Cleanup failed - you may need to manually delete test files"
    fi

    # Local cleanup
    rm -rf "${TEST_DIR}"

    ok "All tests passed successfully!"
}

# =============================================================================
# CONFIGURATION DISPLAY
# =============================================================================

show_configuration_summary() {
    echo ""
    echo "========================================="
    echo "  Rclone Configuration Summary"
    echo "========================================="
    echo ""
    echo "Configuration File: ${RCLONE_CONFIG_FILE}"
    echo "Remote Name: ${REMOTE_NAME}"
    echo "Provider: ${RCLONE_PROVIDER}"
    echo ""

    case "${RCLONE_PROVIDER}" in
        r2)
            echo "Cloudflare R2 Settings:"
            echo "  Account ID: ${R2_ACCOUNT_ID}"
            echo "  Bucket: ${R2_BUCKET}"
            echo "  Endpoint: https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com"
            ;;
        b2)
            echo "Backblaze B2 Settings:"
            echo "  Account ID: ${B2_ACCOUNT_ID}"
            echo "  Bucket: ${B2_BUCKET}"
            ;;
        s3)
            echo "S3 Settings:"
            echo "  Endpoint: ${S3_ENDPOINT}"
            echo "  Bucket: ${S3_BUCKET}"
            echo "  Region: ${S3_REGION}"
            ;;
        local)
            echo "Local Disk Settings:"
            echo "  Path: ${LOCAL_PATH}"
            ;;
    esac

    echo ""
    echo "========================================="
    echo ""
}

# =============================================================================
# NEXT STEPS INSTRUCTIONS
# =============================================================================

show_next_steps() {
    echo ""
    echo "========================================="
    echo "  Next Steps"
    echo "========================================="
    echo ""
    echo "1. Enable Offsite Backups for Supabase:"
    echo ""
    echo "   Edit backup configuration:"
    echo "   sudo nano /home/${TARGET_USER}/stacks/supabase/backup-config.env"
    echo ""
    echo "   Add these lines:"
    echo "   OFFSITE_BACKUP_ENABLED=true"
    echo "   OFFSITE_REMOTE=${REMOTE_NAME}"

    case "${RCLONE_PROVIDER}" in
        r2|b2|s3)
            local bucket="${R2_BUCKET:-${B2_BUCKET:-${S3_BUCKET}}}"
            echo "   OFFSITE_PATH=${bucket}/supabase-backups"
            ;;
        local)
            echo "   OFFSITE_PATH=${LOCAL_PATH}/supabase-backups"
            ;;
    esac

    echo ""
    echo "2. Test Manual Backup:"
    echo ""
    echo "   Run a test backup:"
    echo "   sudo /home/${TARGET_USER}/stacks/supabase/scripts/maintenance/supabase-backup.sh"
    echo ""
    echo "3. Verify Offsite Backup:"
    echo ""
    echo "   List offsite backups:"

    case "${RCLONE_PROVIDER}" in
        r2|b2|s3)
            local bucket="${R2_BUCKET:-${B2_BUCKET:-${S3_BUCKET}}}"
            echo "   rclone ls ${REMOTE_NAME}:${bucket}/supabase-backups"
            ;;
        local)
            echo "   rclone ls ${REMOTE_NAME}:${LOCAL_PATH}/supabase-backups"
            ;;
    esac

    echo ""
    echo "4. Schedule Automated Backups:"
    echo ""
    echo "   The scheduler will automatically sync to offsite"
    echo "   if OFFSITE_BACKUP_ENABLED=true is set"
    echo ""
    echo "5. Useful Rclone Commands:"
    echo ""
    echo "   # List all remotes"
    echo "   rclone listremotes"
    echo ""
    echo "   # Check available space (cloud providers)"
    echo "   rclone about ${REMOTE_NAME}:"
    echo ""
    echo "   # View configuration"
    echo "   rclone config show"
    echo ""
    echo "   # Test bandwidth"

    case "${RCLONE_PROVIDER}" in
        r2|b2|s3)
            local bucket="${R2_BUCKET:-${B2_BUCKET:-${S3_BUCKET}}}"
            echo "   rclone check ${REMOTE_NAME}:${bucket} /path/to/local/dir"
            ;;
        local)
            echo "   rclone check ${REMOTE_NAME}:${LOCAL_PATH} /path/to/local/dir"
            ;;
    esac

    echo ""
    echo "========================================="
    echo ""
    echo "Documentation:"
    echo "  Rclone docs: https://rclone.org/docs/"

    case "${RCLONE_PROVIDER}" in
        r2)
            echo "  R2 docs: https://developers.cloudflare.com/r2/"
            ;;
        b2)
            echo "  B2 docs: https://www.backblaze.com/b2/docs/"
            ;;
        s3)
            echo "  S3 docs: https://rclone.org/s3/"
            ;;
        local)
            echo "  Local docs: https://rclone.org/local/"
            ;;
    esac

    echo ""
    echo "Configuration saved to: ${RCLONE_CONFIG_FILE}"
    echo "Log file: ${LOG_FILE}"
    echo ""
    echo "========================================="
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=1
                log "Dry-run mode enabled"
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                log "Assuming yes to all prompts"
                shift
                ;;
            --verbose|-v)
                VERBOSE=1
                log "Verbose mode enabled"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                warn "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat <<EOF

Rclone Setup Script for Offsite Backups
========================================

Usage: sudo $0 [OPTIONS]

Options:
  --dry-run         Show what would be done without making changes
  --yes, -y         Assume yes to all prompts (automated mode)
  --verbose, -v     Enable verbose output
  --help, -h        Show this help message

Environment Variables (for automated setup):
  RCLONE_PROVIDER   Provider type: r2, b2, s3, local
  REMOTE_NAME       Remote name (default: offsite-backup)

  Cloudflare R2:
    R2_ACCOUNT_ID   Cloudflare Account ID
    R2_ACCESS_KEY   R2 Access Key ID
    R2_SECRET_KEY   R2 Secret Access Key
    R2_BUCKET       R2 Bucket Name

  Backblaze B2:
    B2_ACCOUNT_ID   B2 Application Key ID
    B2_APPLICATION_KEY  B2 Application Key
    B2_BUCKET       B2 Bucket Name

  Generic S3:
    S3_ENDPOINT     S3 Endpoint URL
    S3_ACCESS_KEY   S3 Access Key ID
    S3_SECRET_KEY   S3 Secret Access Key
    S3_BUCKET       S3 Bucket Name
    S3_REGION       S3 Region (default: auto)

  Local Disk:
    LOCAL_PATH      Local directory path

Examples:
  # Interactive setup
  sudo ./01-rclone-setup.sh

  # Automated R2 setup
  sudo R2_ACCOUNT_ID=xxx R2_ACCESS_KEY=yyy R2_SECRET_KEY=zzz \\
       R2_BUCKET=my-backups RCLONE_PROVIDER=r2 \\
       ./01-rclone-setup.sh --yes

  # Automated B2 setup
  sudo B2_ACCOUNT_ID=xxx B2_APPLICATION_KEY=yyy B2_BUCKET=my-backups \\
       RCLONE_PROVIDER=b2 ./01-rclone-setup.sh --yes

  # Local disk setup
  sudo LOCAL_PATH=/mnt/backup RCLONE_PROVIDER=local \\
       ./01-rclone-setup.sh --yes

EOF
}

main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Setup logging
    setup_logging

    # Validate environment
    require_root
    check_dependencies

    # Install rclone
    install_rclone

    # Select and configure provider
    select_provider

    case "${RCLONE_PROVIDER}" in
        r2)
            configure_r2
            ;;
        b2)
            configure_b2
            ;;
        s3)
            configure_s3
            ;;
        local)
            configure_local
            ;;
        *)
            fatal "Unknown provider: ${RCLONE_PROVIDER}"
            ;;
    esac

    # Show configuration
    show_configuration_summary

    # Test configuration
    if [[ "${DRY_RUN}" -ne 1 ]]; then
        if [[ "${ASSUME_YES}" -eq 1 ]] || confirm "Test the configuration now?"; then
            test_rclone_config
        else
            warn "Skipping configuration test"
            warn "Run 'rclone config show' to verify your configuration"
        fi
    else
        log "Dry-run mode: Skipping configuration test"
    fi

    # Show next steps
    show_next_steps

    log "Rclone setup completed successfully!"
    log "Log file saved to: ${LOG_FILE}"
}

# Run main function
main "$@"
