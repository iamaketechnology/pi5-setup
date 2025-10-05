#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Pi5 Gitea Stack - Phase 5: CI/CD with Gitea Actions Runner Setup
# ============================================================================
# Description: Installs and configures Act Runner for Gitea Actions
# Version: 1.0.0
# Requirements: Docker, Gitea already installed
# ============================================================================

# --- Color & Logging Functions ---
log()  { echo -e "\033[1;36m[RUNNER]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]  \033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]    \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR] \033[0m $*"; exit 1; }
step() { echo -e "\n\033[1;35m==>\033[0m \033[1m$*\033[0m\n"; }

# --- Script Configuration ---
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/gitea-runner-setup-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"

# --- Act Runner Configuration ---
ACT_RUNNER_VERSION="${ACT_RUNNER_VERSION:-0.2.10}"
ACT_RUNNER_BINARY="/usr/local/bin/act_runner"
RUNNER_USER="gitea-runner"
RUNNER_HOME="/var/lib/gitea-runner"
RUNNER_CONFIG="${RUNNER_HOME}/config.yaml"
RUNNER_DATA="${RUNNER_HOME}/.runner"
RUNNER_CACHE="${RUNNER_HOME}/cache"

# --- Gitea Configuration ---
GITEA_URL="${GITEA_URL:-http://localhost:3000}"
GITEA_INSTANCE_URL="${GITEA_INSTANCE_URL:-${GITEA_URL}}"

# --- Runner Settings (Customizable via Environment Variables) ---
RUNNER_NAME="${RUNNER_NAME:-pi5-runner-01}"
RUNNER_TOKEN="${RUNNER_TOKEN:-}"
MAX_CONCURRENT_JOBS="${MAX_CONCURRENT_JOBS:-2}"
RUNNER_CAPACITY="${RUNNER_CAPACITY:-${MAX_CONCURRENT_JOBS}}"
DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
RUNNER_LABELS="${RUNNER_LABELS:-ubuntu-latest,self-hosted,arm64,linux}"
CACHE_MAX_SIZE="${CACHE_MAX_SIZE:-5GB}"
RUNNER_TIMEOUT="${RUNNER_TIMEOUT:-3h}"

# --- Interactive Mode ---
INTERACTIVE="${INTERACTIVE:-yes}"
DRY_RUN="${DRY_RUN:-no}"
SKIP_REGISTRATION="${SKIP_REGISTRATION:-no}"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo $0"
  fi
}

setup_logging() {
  exec 1> >(tee -a "$LOG_FILE")
  exec 2> >(tee -a "$LOG_FILE" >&2)

  log "=== Gitea Actions Runner Setup - $(date) ==="
  log "Version: $SCRIPT_VERSION"
  log "Target User: $TARGET_USER"
  log "Log File: $LOG_FILE"
  log "Dry Run: $DRY_RUN"
}

check_dependencies() {
  log "Checking dependencies..."

  local deps=("curl" "docker" "systemctl" "getconf")
  local missing=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing dependencies: ${missing[*]}"
  fi

  # Check Docker is running
  if ! systemctl is-active --quiet docker; then
    error "Docker is not running. Please start Docker first."
  fi

  ok "All dependencies satisfied"
}

check_gitea_available() {
  log "Checking Gitea availability..."

  if ! curl -fsS "${GITEA_URL}" >/dev/null 2>&1; then
    warn "Gitea not accessible at ${GITEA_URL}"
    warn "Please ensure Gitea is running before registering the runner"
    warn "You can still install the runner and register it later"
    return 1
  fi

  ok "Gitea is accessible at ${GITEA_URL}"
  return 0
}

confirm() {
  if [[ "$INTERACTIVE" != "yes" ]]; then
    return 0
  fi

  local prompt="${1:-Continue?}"
  read -rp "${prompt} [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      warn "Operation cancelled by user"
      exit 1
      ;;
  esac
}

run_cmd() {
  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] $*"
    return 0
  fi

  "$@"
}

# ============================================================================
# ARCHITECTURE DETECTION
# ============================================================================

detect_architecture() {
  log "Detecting system architecture..."

  local arch
  arch="$(uname -m)"

  case "$arch" in
    aarch64|arm64)
      ACT_RUNNER_ARCH="arm64"
      ok "Architecture: ARM64 (Raspberry Pi 5 compatible)"
      ;;
    x86_64|amd64)
      ACT_RUNNER_ARCH="amd64"
      ok "Architecture: AMD64"
      ;;
    armv7l|armhf)
      ACT_RUNNER_ARCH="armv7"
      warn "Architecture: ARMv7 (not recommended for Gitea Actions)"
      ;;
    *)
      error "Unsupported architecture: $arch"
      ;;
  esac
}

# ============================================================================
# USER & DIRECTORY SETUP
# ============================================================================

create_runner_user() {
  step "Creating dedicated runner user..."

  if id "$RUNNER_USER" &>/dev/null; then
    ok "User $RUNNER_USER already exists"
  else
    log "Creating user $RUNNER_USER..."
    run_cmd useradd --system --home-dir "$RUNNER_HOME" --create-home \
      --shell /bin/bash "$RUNNER_USER"
    ok "User $RUNNER_USER created"
  fi

  # Add runner user to docker group for Docker-in-Docker support
  if ! groups "$RUNNER_USER" | grep -q docker; then
    log "Adding $RUNNER_USER to docker group..."
    run_cmd usermod -aG docker "$RUNNER_USER"
    ok "User $RUNNER_USER added to docker group"
  fi
}

setup_runner_directories() {
  step "Setting up runner directories..."

  local dirs=(
    "$RUNNER_HOME"
    "$RUNNER_DATA"
    "$RUNNER_CACHE"
    "${RUNNER_HOME}/logs"
  )

  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      log "Creating directory: $dir"
      run_cmd mkdir -p "$dir"
    fi
  done

  log "Setting ownership to $RUNNER_USER..."
  run_cmd chown -R "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_HOME"

  ok "Runner directories configured"
}

# ============================================================================
# ACT RUNNER INSTALLATION
# ============================================================================

download_act_runner() {
  step "Downloading Act Runner v${ACT_RUNNER_VERSION}..."

  local download_url="https://gitea.com/gitea/act_runner/releases/download/v${ACT_RUNNER_VERSION}/act_runner-${ACT_RUNNER_VERSION}-linux-${ACT_RUNNER_ARCH}"

  log "Download URL: $download_url"

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would download from: $download_url"
    return 0
  fi

  local temp_binary="/tmp/act_runner-${ACT_RUNNER_VERSION}"

  if ! curl -fsSL "$download_url" -o "$temp_binary"; then
    error "Failed to download Act Runner. Check version ${ACT_RUNNER_VERSION} exists for ${ACT_RUNNER_ARCH}"
  fi

  chmod +x "$temp_binary"
  mv "$temp_binary" "$ACT_RUNNER_BINARY"

  ok "Act Runner downloaded to $ACT_RUNNER_BINARY"
}

verify_act_runner() {
  log "Verifying Act Runner installation..."

  if [[ ! -f "$ACT_RUNNER_BINARY" ]]; then
    error "Act Runner binary not found at $ACT_RUNNER_BINARY"
  fi

  if [[ "$DRY_RUN" == "yes" ]]; then
    ok "[DRY-RUN] Would verify Act Runner binary"
    return 0
  fi

  local version_output
  version_output=$("$ACT_RUNNER_BINARY" --version 2>&1 || true)

  log "Act Runner version: $version_output"
  ok "Act Runner binary verified"
}

# ============================================================================
# RUNNER CONFIGURATION
# ============================================================================

generate_runner_config() {
  step "Generating runner configuration..."

  log "Config file: $RUNNER_CONFIG"

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would generate config at: $RUNNER_CONFIG"
    return 0
  fi

  # Parse labels into proper format
  local label_configs=""
  IFS=',' read -ra LABELS <<< "$RUNNER_LABELS"

  for label in "${LABELS[@]}"; do
    label=$(echo "$label" | xargs) # trim whitespace

    # Determine execution mode for label
    case "$label" in
      ubuntu-latest|ubuntu-*|debian-*|node-*|alpine-*)
        # Container-based execution
        label_configs="${label_configs}    - ${label}:docker://node:16-bullseye\n"
        ;;
      self-hosted|arm64|linux|aarch64)
        # Host-based execution
        label_configs="${label_configs}    - ${label}:host\n"
        ;;
      *)
        # Default to host
        label_configs="${label_configs}    - ${label}:host\n"
        ;;
    esac
  done

  cat > "$RUNNER_CONFIG" <<EOF
# Gitea Actions Runner Configuration
# Generated by pi5-gitea-stack setup script v${SCRIPT_VERSION}
# $(date)

log:
  level: info

runner:
  name: ${RUNNER_NAME}
  capacity: ${RUNNER_CAPACITY}
  timeout: ${RUNNER_TIMEOUT}
  labels:
$(echo -e "$label_configs")

cache:
  enabled: true
  dir: ${RUNNER_CACHE}
  max_size: ${CACHE_MAX_SIZE}

container:
  # Docker configuration
  network: bridge
  privileged: false
  options:
  valid_volumes:
    - ${RUNNER_CACHE}
  docker_host: ${DOCKER_HOST}

host:
  workdir_parent: ${RUNNER_HOME}/workspace
EOF

  chown "${RUNNER_USER}:${RUNNER_USER}" "$RUNNER_CONFIG"
  chmod 600 "$RUNNER_CONFIG"

  ok "Runner configuration generated"
  log "Config location: $RUNNER_CONFIG"
}

# ============================================================================
# RUNNER REGISTRATION
# ============================================================================

register_runner() {
  step "Registering runner with Gitea..."

  # Check if already registered
  if [[ -f "${RUNNER_DATA}/.runner" ]]; then
    warn "Runner appears to be already registered"
    warn "Data file exists: ${RUNNER_DATA}/.runner"
    confirm "Re-register runner (this will replace existing registration)?"
    run_cmd rm -f "${RUNNER_DATA}/.runner"
  fi

  # Get registration token
  if [[ -z "$RUNNER_TOKEN" ]]; then
    if [[ "$INTERACTIVE" == "yes" ]]; then
      get_registration_token_interactive
    else
      error "RUNNER_TOKEN environment variable not set and not in interactive mode"
    fi
  else
    log "Using RUNNER_TOKEN from environment variable"
  fi

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would register runner with:"
    log "  Instance: $GITEA_INSTANCE_URL"
    log "  Name: $RUNNER_NAME"
    log "  Labels: $RUNNER_LABELS"
    return 0
  fi

  log "Registering runner..."
  log "  Instance: $GITEA_INSTANCE_URL"
  log "  Name: $RUNNER_NAME"

  # Run registration as runner user
  if ! sudo -u "$RUNNER_USER" "$ACT_RUNNER_BINARY" register \
    --instance "$GITEA_INSTANCE_URL" \
    --token "$RUNNER_TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" \
    --config "$RUNNER_CONFIG" \
    --no-interactive; then
    error "Runner registration failed"
  fi

  ok "Runner registered successfully"

  # Clear token from memory (security)
  RUNNER_TOKEN=""
}

get_registration_token_interactive() {
  echo ""
  log "To register the runner, you need a registration token from Gitea"
  log ""
  log "Steps to get the token:"
  log "  1. Open Gitea in your browser: ${GITEA_URL}"
  log "  2. Login as admin"
  log "  3. Navigate to: Site Administration > Actions > Runners"
  log "     Direct URL: ${GITEA_URL}/admin/actions/runners"
  log "  4. Click 'Create new Runner'"
  log "  5. Copy the registration token"
  log ""

  read -rp "Enter registration token: " RUNNER_TOKEN

  if [[ -z "$RUNNER_TOKEN" ]]; then
    error "Registration token cannot be empty"
  fi

  log "Token received (length: ${#RUNNER_TOKEN} chars)"
}

# ============================================================================
# SYSTEMD SERVICE
# ============================================================================

create_systemd_service() {
  step "Creating systemd service..."

  local service_file="/etc/systemd/system/gitea-runner.service"

  log "Service file: $service_file"

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would create systemd service at: $service_file"
    return 0
  fi

  cat > "$service_file" <<EOF
[Unit]
Description=Gitea Actions Runner
Documentation=https://docs.gitea.com/usage/actions/overview
After=docker.service
Wants=docker.service

[Service]
Type=simple
User=${RUNNER_USER}
Group=${RUNNER_USER}
WorkingDirectory=${RUNNER_HOME}
ExecStart=${ACT_RUNNER_BINARY} daemon --config ${RUNNER_CONFIG}
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=append:${RUNNER_HOME}/logs/runner.log
StandardError=append:${RUNNER_HOME}/logs/runner-error.log

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${RUNNER_HOME}

# Resource limits
LimitNOFILE=65536
TasksMax=4096

[Install]
WantedBy=multi-user.target
EOF

  ok "Systemd service created"
}

enable_and_start_service() {
  step "Enabling and starting runner service..."

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would enable and start gitea-runner.service"
    return 0
  fi

  log "Reloading systemd daemon..."
  systemctl daemon-reload

  log "Enabling gitea-runner service..."
  systemctl enable gitea-runner.service

  log "Starting gitea-runner service..."
  if ! systemctl start gitea-runner.service; then
    error "Failed to start gitea-runner service. Check logs: journalctl -u gitea-runner -n 50"
  fi

  # Wait a moment for service to initialize
  sleep 2

  if systemctl is-active --quiet gitea-runner.service; then
    ok "Gitea runner service is running"
  else
    error "Gitea runner service failed to start. Check logs: journalctl -u gitea-runner"
  fi
}

# ============================================================================
# VERIFICATION & TESTING
# ============================================================================

verify_runner_status() {
  step "Verifying runner status..."

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would verify runner status"
    return 0
  fi

  log "Service status:"
  systemctl status gitea-runner.service --no-pager -l || true

  echo ""
  log "Recent logs:"
  journalctl -u gitea-runner -n 20 --no-pager || true

  echo ""
  if systemctl is-active --quiet gitea-runner.service; then
    ok "Runner service is active and running"
  else
    warn "Runner service is not active"
    return 1
  fi
}

check_runner_in_gitea() {
  step "Checking runner registration in Gitea..."

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would check runner in Gitea"
    return 0
  fi

  log "Please verify the runner appears in Gitea:"
  log "  URL: ${GITEA_URL}/admin/actions/runners"
  log "  Runner name: ${RUNNER_NAME}"
  log "  Status should show: Idle (ready to accept jobs)"

  if [[ "$INTERACTIVE" == "yes" ]]; then
    read -rp "Press Enter to continue..."
  fi
}

create_test_workflow() {
  step "Creating test workflow example..."

  local workflow_dir="${RUNNER_HOME}/example-workflow"
  local workflow_file="${workflow_dir}/.gitea/workflows/test.yml"

  if [[ "$DRY_RUN" == "yes" ]]; then
    log "[DRY-RUN] Would create example workflow"
    return 0
  fi

  mkdir -p "$(dirname "$workflow_file")"

  cat > "$workflow_file" <<'EOF'
name: Test Gitea Actions Runner
on:
  push:
    branches: [main, master]
  pull_request:
  workflow_dispatch:

jobs:
  test-runner:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Hello from Gitea Actions
        run: |
          echo "Hello from Gitea Actions on Raspberry Pi 5!"
          echo "Runner: ${{ runner.name }}"
          echo "OS: ${{ runner.os }}"
          echo "Architecture: ${{ runner.arch }}"

      - name: Show system info
        run: |
          echo "=== System Information ==="
          uname -a
          echo ""
          echo "=== CPU Info ==="
          lscpu | grep -E "Architecture|CPU|Model name"
          echo ""
          echo "=== Memory Info ==="
          free -h

      - name: Test Docker availability
        run: |
          echo "=== Docker Version ==="
          docker --version
          echo ""
          echo "=== Docker Info ==="
          docker info | head -20

      - name: Success message
        run: |
          echo "✅ Gitea Actions runner is working correctly!"
          echo "🎉 CI/CD pipeline is ready to use!"
EOF

  chown -R "${RUNNER_USER}:${RUNNER_USER}" "$workflow_dir"

  ok "Example workflow created at: $workflow_file"
  log "Copy this to your repository's .gitea/workflows/ directory"
}

# ============================================================================
# MONITORING & MAINTENANCE
# ============================================================================

show_monitoring_info() {
  step "Monitoring & Maintenance Information"

  cat <<EOF

${_c_blue}Runner Management Commands:${_c_reset}

  # Check runner status
  sudo systemctl status gitea-runner

  # View live logs
  sudo journalctl -u gitea-runner -f

  # View recent logs
  sudo journalctl -u gitea-runner -n 100

  # Restart runner
  sudo systemctl restart gitea-runner

  # Stop runner
  sudo systemctl stop gitea-runner

  # Start runner
  sudo systemctl start gitea-runner

${_c_blue}Log Files:${_c_reset}
  • Runner logs: ${RUNNER_HOME}/logs/runner.log
  • Error logs: ${RUNNER_HOME}/logs/runner-error.log
  • System logs: journalctl -u gitea-runner

${_c_blue}Configuration Files:${_c_reset}
  • Runner config: ${RUNNER_CONFIG}
  • Runner data: ${RUNNER_DATA}
  • Cache directory: ${RUNNER_CACHE}
  • Service file: /etc/systemd/system/gitea-runner.service

${_c_blue}Useful Runner Commands:${_c_reset}
  # Check runner version
  ${ACT_RUNNER_BINARY} --version

  # Validate configuration
  sudo -u ${RUNNER_USER} ${ACT_RUNNER_BINARY} verify --config ${RUNNER_CONFIG}

  # Re-register runner (if needed)
  sudo systemctl stop gitea-runner
  sudo rm -f ${RUNNER_DATA}/.runner
  sudo -u ${RUNNER_USER} ${ACT_RUNNER_BINARY} register --config ${RUNNER_CONFIG}
  sudo systemctl start gitea-runner

${_c_blue}Performance Tuning:${_c_reset}
  • Max concurrent jobs: ${MAX_CONCURRENT_JOBS}
  • Cache size limit: ${CACHE_MAX_SIZE}
  • Job timeout: ${RUNNER_TIMEOUT}

  To modify these, edit: ${RUNNER_CONFIG}
  Then restart: sudo systemctl restart gitea-runner

${_c_blue}Troubleshooting:${_c_reset}
  1. Runner not accepting jobs
     → Check runner appears in Gitea: ${GITEA_URL}/admin/actions/runners
     → Verify status is "Idle" not "Offline"
     → Check logs: journalctl -u gitea-runner -n 50

  2. Jobs failing with "container not found"
     → Ensure Docker is running: systemctl status docker
     → Check runner user in docker group: groups ${RUNNER_USER}
     → Verify Docker socket: ls -l /var/run/docker.sock

  3. Permission errors
     → Check file ownership: ls -la ${RUNNER_HOME}
     → Fix if needed: sudo chown -R ${RUNNER_USER}:${RUNNER_USER} ${RUNNER_HOME}

  4. Out of disk space
     → Check cache size: du -sh ${RUNNER_CACHE}
     → Clean old cache: sudo rm -rf ${RUNNER_CACHE}/*
     → Reduce CACHE_MAX_SIZE in config

EOF
}

# ============================================================================
# INTEGRATION HELPERS
# ============================================================================

show_integration_info() {
  step "Integration with Other Services"

  cat <<EOF

${_c_blue}Adding Runner Metrics to Homepage Dashboard:${_c_reset}

Add this to your Homepage services.yaml:

  - Gitea Runner:
      icon: gitea
      href: ${GITEA_URL}/admin/actions/runners
      description: CI/CD Runner Status
      widget:
        type: customapi
        url: http://localhost:3000/api/v1/admin/runners
        method: GET
        headers:
          Authorization: token YOUR_GITEA_TOKEN
        mappings:
          - field: data
            label: Active Runners
            format: number

${_c_blue}Adding to Grafana Monitoring:${_c_reset}

Install Prometheus Node Exporter for runner metrics:
  # Add these labels to your monitoring
  job: gitea-runner
  instance: ${RUNNER_NAME}
  host: $(hostname)

Useful metrics to monitor:
  • Runner uptime: process_uptime_seconds
  • Active jobs: gitea_runner_active_jobs
  • Job success rate: gitea_runner_jobs_success_total / gitea_runner_jobs_total
  • Cache usage: disk_used_bytes{path="${RUNNER_CACHE}"}

${_c_blue}Backup Recommendations:${_c_reset}

Add to your backup script:
  # Runner configuration
  ${RUNNER_CONFIG}

  # Runner registration data (contains credentials)
  ${RUNNER_DATA}/.runner

  # Optionally exclude cache (can be large)
  # ${RUNNER_CACHE}/*

Example backup command:
  sudo tar czf gitea-runner-backup-\$(date +%Y%m%d).tar.gz \\
    ${RUNNER_CONFIG} \\
    ${RUNNER_DATA}/.runner \\
    --exclude=${RUNNER_CACHE}

${_c_blue}Security Hardening:${_c_reset}

1. Limit Docker privileges (edit ${RUNNER_CONFIG}):
   container:
     privileged: false
     capabilities: []

2. Network isolation (if using Docker network):
   container:
     network: gitea-runner-net

3. Resource limits (edit /etc/systemd/system/gitea-runner.service):
   [Service]
   MemoryLimit=4G
   CPUQuota=200%

4. Firewall rules:
   # Runner doesn't need incoming connections
   # Only outgoing to Gitea instance
   sudo ufw allow out to ${GITEA_URL}

EOF
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

show_final_summary() {
  step "Installation Complete!"

  cat <<EOF

${_c_green}✅ Gitea Actions Runner Successfully Installed${_c_reset}

${_c_blue}Runner Information:${_c_reset}
  • Name: ${RUNNER_NAME}
  • Labels: ${RUNNER_LABELS}
  • Capacity: ${RUNNER_CAPACITY} concurrent jobs
  • Timeout: ${RUNNER_TIMEOUT}
  • Status: $(systemctl is-active gitea-runner 2>/dev/null || echo "not started")

${_c_blue}Access Points:${_c_reset}
  • Gitea Runners Admin: ${GITEA_URL}/admin/actions/runners
  • Service Status: systemctl status gitea-runner
  • Live Logs: journalctl -u gitea-runner -f

${_c_blue}Next Steps:${_c_reset}

1. Verify runner in Gitea:
   • Open: ${GITEA_URL}/admin/actions/runners
   • Look for: ${RUNNER_NAME}
   • Status should be: Idle (ready)

2. Create your first workflow:
   • In any Gitea repository, create: .gitea/workflows/test.yml
   • Example workflow created at: ${RUNNER_HOME}/example-workflow/.gitea/workflows/test.yml
   • Copy this file to your repository

3. Test the runner:
   • Push code to trigger the workflow
   • Or manually trigger from Gitea UI
   • Check job execution in Gitea Actions tab

4. Configure monitoring:
   • Add runner to Homepage dashboard
   • Set up Grafana alerts for failed jobs
   • Monitor cache usage: du -sh ${RUNNER_CACHE}

${_c_blue}Example Workflow:${_c_reset}

Create .gitea/workflows/ci.yml in your repository:

---
name: CI Pipeline
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: echo "Add your test commands here"
---

${_c_blue}Documentation:${_c_reset}
  • Gitea Actions: https://docs.gitea.com/usage/actions/overview
  • Act Runner: https://gitea.com/gitea/act_runner
  • Workflow Syntax: https://docs.gitea.com/usage/actions/quickstart

${_c_blue}Support:${_c_reset}
  • Check logs: sudo journalctl -u gitea-runner -n 50
  • Runner status: systemctl status gitea-runner
  • Test registration: sudo -u ${RUNNER_USER} ${ACT_RUNNER_BINARY} verify

${_c_yellow}Log file saved to: ${LOG_FILE}${_c_reset}

Happy CI/CD! 🚀

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

show_banner() {
  cat <<'EOF'

   ╔═══════════════════════════════════════════════════════╗
   ║                                                       ║
   ║       Gitea Actions Runner Setup for Pi 5            ║
   ║       Phase 5: CI/CD with Gitea Actions              ║
   ║                                                       ║
   ║       Automated runner installation and              ║
   ║       configuration for ARM64                        ║
   ║                                                       ║
   ╚═══════════════════════════════════════════════════════╝

EOF
}

main() {
  show_banner

  require_root
  setup_logging

  log "Starting Gitea Actions Runner setup..."
  log "Configuration:"
  log "  Runner Name: ${RUNNER_NAME}"
  log "  Max Concurrent Jobs: ${MAX_CONCURRENT_JOBS}"
  log "  Gitea URL: ${GITEA_URL}"
  log "  Interactive Mode: ${INTERACTIVE}"

  # Pre-flight checks
  check_dependencies
  detect_architecture

  # Check if Gitea is available (non-fatal)
  GITEA_AVAILABLE=no
  if check_gitea_available; then
    GITEA_AVAILABLE=yes
  fi

  # Installation steps
  create_runner_user
  setup_runner_directories
  download_act_runner
  verify_act_runner
  generate_runner_config

  # Registration (optional if Gitea not available)
  if [[ "$SKIP_REGISTRATION" != "yes" ]]; then
    if [[ "$GITEA_AVAILABLE" == "yes" ]] || [[ -n "$RUNNER_TOKEN" ]]; then
      register_runner
    else
      warn "Skipping registration - Gitea not available and no token provided"
      warn "You can register later with:"
      warn "  sudo systemctl stop gitea-runner"
      warn "  sudo -u ${RUNNER_USER} ${ACT_RUNNER_BINARY} register --config ${RUNNER_CONFIG}"
      warn "  sudo systemctl start gitea-runner"
    fi
  else
    log "Skipping registration (SKIP_REGISTRATION=yes)"
  fi

  # Service setup
  create_systemd_service

  if [[ "$SKIP_REGISTRATION" != "yes" ]] && [[ -f "${RUNNER_DATA}/.runner" ]]; then
    enable_and_start_service
    sleep 2
    verify_runner_status
    check_runner_in_gitea
  else
    log "Skipping service start - runner not registered yet"
  fi

  # Post-installation
  create_test_workflow
  show_monitoring_info
  show_integration_info
  show_final_summary

  ok "Setup completed successfully!"
}

# ============================================================================
# SCRIPT ENTRY POINT
# ============================================================================

# Color codes for summary (if not set by log functions)
_c_blue="\033[1;36m"
_c_green="\033[1;32m"
_c_yellow="\033[1;33m"
_c_reset="\033[0m"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=yes
      shift
      ;;
    --non-interactive)
      INTERACTIVE=no
      shift
      ;;
    --skip-registration)
      SKIP_REGISTRATION=yes
      shift
      ;;
    --help|-h)
      cat <<EOF
Usage: sudo $0 [OPTIONS]

Options:
  --dry-run              Show what would be done without making changes
  --non-interactive      Run without user prompts (requires RUNNER_TOKEN)
  --skip-registration    Install but don't register runner
  --help, -h             Show this help message

Environment Variables:
  RUNNER_TOKEN           Registration token from Gitea
  RUNNER_NAME            Name for this runner (default: pi5-runner-01)
  MAX_CONCURRENT_JOBS    Max parallel jobs (default: 2)
  GITEA_URL              Gitea instance URL (default: http://localhost:3000)
  RUNNER_LABELS          Comma-separated labels (default: ubuntu-latest,self-hosted,arm64,linux)
  ACT_RUNNER_VERSION     Act Runner version to install (default: 0.2.10)
  CACHE_MAX_SIZE         Cache size limit (default: 5GB)
  RUNNER_TIMEOUT         Job timeout (default: 3h)

Examples:
  # Interactive installation
  sudo ./02-runners-setup.sh

  # Automated installation
  sudo RUNNER_TOKEN=xxx RUNNER_NAME=pi5-runner-01 ./02-runners-setup.sh --non-interactive

  # Dry run to see what would happen
  sudo ./02-runners-setup.sh --dry-run

  # Install without registering (register later)
  sudo ./02-runners-setup.sh --skip-registration

For more information, see the Gitea Actions documentation:
https://docs.gitea.com/usage/actions/overview

EOF
      exit 0
      ;;
    *)
      error "Unknown option: $1. Use --help for usage information."
      ;;
  esac
done

# Run main function
main

exit 0
