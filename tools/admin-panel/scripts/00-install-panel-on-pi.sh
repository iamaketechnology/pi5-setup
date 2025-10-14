#!/bin/bash
# =============================================================================
# PI5 Control Center - Bootstrap Installation Script
# =============================================================================
# Installs the PI5 Admin Panel directly on the Raspberry Pi
# This should be the FIRST thing installed on a fresh Pi
# Version: 2.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: curl -fsSL https://raw.githubusercontent.com/.../00-install-panel-on-pi.sh | sudo bash
# =============================================================================

set -euo pipefail

# =============================================================================
# Logging Functions
# =============================================================================

log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warning() { echo -e "\033[0;33m[WARNING]\033[0m $*"; }

# =============================================================================
# Environment Detection
# =============================================================================

CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")
PANEL_DIR="${USER_HOME}/pi5-setup/tools/admin-panel"

# =============================================================================
# Pre-flight Checks
# =============================================================================

log_info "🚀 PI5 Control Center - Bootstrap Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run with sudo"
    exit 1
fi

# Check architecture
if ! uname -m | grep -qE 'aarch64|armv7l'; then
    log_warning "Not running on ARM architecture (Pi). Continuing anyway..."
fi

# =============================================================================
# Step 1: Clone pi5-setup repository
# =============================================================================

log_info "📦 Step 1: Cloning pi5-setup repository..."

if [[ -d "${USER_HOME}/pi5-setup/.git" ]]; then
    log_info "Repository already exists, pulling latest changes..."
    cd "${USER_HOME}/pi5-setup"
    sudo -u "${CURRENT_USER}" git pull origin main || log_warning "Failed to pull, continuing with existing version"
else
    log_info "Cloning fresh repository..."
    cd "${USER_HOME}"
    sudo -u "${CURRENT_USER}" git clone https://github.com/iamaketechnology/pi5-setup.git
fi

log_success "Repository ready at ${USER_HOME}/pi5-setup"

# =============================================================================
# Step 2: Install Docker (if not installed)
# =============================================================================

log_info "🐳 Step 2: Checking Docker installation..."

if ! command -v docker &> /dev/null; then
    log_info "Docker not found, installing..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker "${CURRENT_USER}"
    log_success "Docker installed successfully"
else
    log_success "Docker already installed ($(docker --version))"
fi

# Ensure Docker service is running
systemctl enable docker
systemctl start docker

# =============================================================================
# Step 3: Install Node.js (for local development/testing)
# =============================================================================

log_info "📦 Step 3: Checking Node.js installation..."

if ! command -v node &> /dev/null; then
    log_info "Node.js not found, installing via NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
    log_success "Node.js installed ($(node --version))"
else
    log_success "Node.js already installed ($(node --version))"
fi

# =============================================================================
# Step 4: Setup SSH keys (for localhost connection)
# =============================================================================

log_info "🔑 Step 4: Setting up SSH keys..."

if [[ ! -f "${USER_HOME}/.ssh/id_rsa" ]]; then
    log_info "Generating SSH key pair..."
    sudo -u "${CURRENT_USER}" ssh-keygen -t rsa -b 4096 -f "${USER_HOME}/.ssh/id_rsa" -N "" -C "pi5-admin-panel@localhost"
    log_success "SSH key generated"
else
    log_success "SSH key already exists"
fi

# Add public key to authorized_keys for localhost SSH
if ! grep -qF "$(cat ${USER_HOME}/.ssh/id_rsa.pub)" "${USER_HOME}/.ssh/authorized_keys" 2>/dev/null; then
    log_info "Adding public key to authorized_keys..."
    sudo -u "${CURRENT_USER}" mkdir -p "${USER_HOME}/.ssh"
    sudo -u "${CURRENT_USER}" cat "${USER_HOME}/.ssh/id_rsa.pub" >> "${USER_HOME}/.ssh/authorized_keys"
    sudo -u "${CURRENT_USER}" chmod 600 "${USER_HOME}/.ssh/authorized_keys"
    log_success "Authorized key added"
fi

# Test localhost SSH connection
log_info "Testing localhost SSH connection..."
if sudo -u "${CURRENT_USER}" ssh -o StrictHostKeyChecking=no -o BatchMode=yes localhost "echo 'SSH OK'" &> /dev/null; then
    log_success "Localhost SSH connection works"
else
    log_error "Localhost SSH connection failed. Check ~/.ssh/authorized_keys permissions"
    exit 1
fi

# =============================================================================
# Step 5: Install panel dependencies
# =============================================================================

log_info "📦 Step 5: Installing panel dependencies..."

cd "${PANEL_DIR}"

if [[ ! -d "node_modules" ]]; then
    log_info "Running npm install..."
    sudo -u "${CURRENT_USER}" npm install
    log_success "Dependencies installed"
else
    log_success "Dependencies already installed"
fi

# =============================================================================
# Step 6: Create production config
# =============================================================================

log_info "⚙️ Step 6: Creating production configuration..."

if [[ ! -f "${PANEL_DIR}/config.js" ]]; then
    log_info "Copying config.pi.js to config.js..."
    sudo -u "${CURRENT_USER}" cp "${PANEL_DIR}/config.pi.js" "${PANEL_DIR}/config.js"
    log_success "Configuration created"
else
    log_success "Configuration already exists"
fi

# =============================================================================
# Step 7: Build Docker image
# =============================================================================

log_info "🐳 Step 7: Building Docker image..."

cd "${PANEL_DIR}"
docker build -t pi5-admin-panel:2.0.0 . || {
    log_error "Docker build failed"
    exit 1
}

log_success "Docker image built successfully"

# =============================================================================
# Step 8: Deploy with Docker Compose
# =============================================================================

log_info "🚀 Step 8: Deploying with Docker Compose..."

# Stop existing container if running
if docker ps -a --format '{{.Names}}' | grep -q "^pi5-admin-panel$"; then
    log_info "Stopping existing container..."
    docker compose down
fi

# Start container
docker compose up -d || {
    log_error "Failed to start container"
    docker compose logs --tail 50
    exit 1
}

log_success "Container deployed successfully"

# =============================================================================
# Step 9: Wait for container to be healthy
# =============================================================================

log_info "⏳ Step 9: Waiting for container to be healthy..."

for i in {1..30}; do
    if docker ps --filter "name=pi5-admin-panel" --filter "status=running" | grep -q "pi5-admin-panel"; then
        log_success "Container is running"
        break
    fi

    if [[ $i -eq 30 ]]; then
        log_error "Container failed to start within 30 seconds"
        docker logs pi5-admin-panel --tail 50
        exit 1
    fi

    sleep 1
done

# Wait for HTTP server to respond
sleep 5

if curl -s http://localhost:4000/api/status &> /dev/null; then
    log_success "Admin panel is responding"
else
    log_warning "Admin panel not responding yet, check logs with: docker logs pi5-admin-panel"
fi

# =============================================================================
# Step 10: Get Pi IP address
# =============================================================================

log_info "🌐 Step 10: Detecting network configuration..."

# Get primary IP address
PI_IP=$(hostname -I | awk '{print $1}')

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ PI5 CONTROL CENTER INSTALLED SUCCESSFULLY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📍 Access URLs:"
echo "   • Local:    http://localhost:4000"
echo "   • Network:  http://${PI_IP}:4000"
echo "   • Hostname: http://$(hostname).local:4000"
echo ""
echo "🐳 Container Management:"
echo "   • Status:   docker ps | grep pi5-admin-panel"
echo "   • Logs:     docker logs -f pi5-admin-panel"
echo "   • Restart:  docker restart pi5-admin-panel"
echo "   • Stop:     docker stop pi5-admin-panel"
echo ""
echo "📂 Project Location:"
echo "   • Panel:    ${PANEL_DIR}"
echo "   • Scripts:  ${USER_HOME}/pi5-setup"
echo ""
echo "🔗 Next Steps:"
echo "   1. Open http://${PI_IP}:4000 in your browser"
echo "   2. Use the dashboard to deploy services"
echo "   3. All scripts are auto-discovered and ready to run"
echo ""
echo "💡 Tips:"
echo "   • Scripts execute via SSH to localhost"
echo "   • Real-time system monitoring every 5 seconds"
echo "   • Organized by: Deploy, Maintenance, Tests, Config"
echo "   • Terminal shows live execution logs"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# Optional: Add to .bashrc for easy access
# =============================================================================

if ! grep -q "alias admin-panel" "${USER_HOME}/.bashrc" 2>/dev/null; then
    log_info "Adding convenience aliases to .bashrc..."
    cat >> "${USER_HOME}/.bashrc" <<'EOF'

# PI5 Admin Panel shortcuts
alias admin-panel='cd ~/pi5-setup/tools/admin-panel'
alias admin-logs='docker logs -f pi5-admin-panel'
alias admin-restart='docker restart pi5-admin-panel'
EOF
    log_success "Aliases added. Run 'source ~/.bashrc' to activate"
fi

exit 0
