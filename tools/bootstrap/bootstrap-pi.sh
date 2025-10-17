#!/bin/bash
# =============================================================================
# PI5 Bootstrap Script - Add New Pi to Control Center
# =============================================================================
# Version: 1.0.0
# Description: Configure a fresh Raspberry Pi for Control Center management
# Usage: curl -fsSL https://raw.../bootstrap-pi.sh | sudo bash -s -- <CONTROL_CENTER_URL>
# Example: curl -fsSL https://raw.../bootstrap-pi.sh | sudo bash -s -- http://192.168.1.100:4000
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get Control Center URL from argument
CONTROL_CENTER_URL="${1:-}"

if [[ -z "$CONTROL_CENTER_URL" ]]; then
    log_error "Control Center URL is required"
    echo "Usage: sudo bash bootstrap-pi.sh <CONTROL_CENTER_URL>"
    echo "Example: sudo bash bootstrap-pi.sh http://192.168.1.100:4000"
    exit 1
fi

# Detect user (non-root)
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

log_info "PI5 Bootstrap - Add Pi to Control Center"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Control Center: $CONTROL_CENTER_URL"
echo "User: $CURRENT_USER"
echo "Home: $USER_HOME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# Step 1: Generate unique token
# =============================================================================

log_info "Step 1/6: Generating unique token..."

# Generate UUID-based token (8 chars)
TOKEN=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)
TOKEN_SHORT="${TOKEN:0:4}-${TOKEN:4:4}-${TOKEN:8:4}"

log_success "Token generated: $TOKEN_SHORT"

# =============================================================================
# Step 2: Get Pi information
# =============================================================================

log_info "Step 2/6: Collecting Pi information..."

PI_HOSTNAME=$(hostname)
PI_IP=$(hostname -I | awk '{print $1}')
PI_MAC=$(cat /sys/class/net/$(ip route show default | awk '/default/ {print $5}')/address 2>/dev/null || echo "unknown")
PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' || echo "Raspberry Pi")
PI_OS=$(lsb_release -ds 2>/dev/null || echo "Unknown")
PI_ARCH=$(uname -m)

log_success "Hostname: $PI_HOSTNAME"
log_success "IP: $PI_IP"
log_success "MAC: $PI_MAC"
log_success "Model: $PI_MODEL"

# =============================================================================
# Step 3: Install dependencies
# =============================================================================

log_info "Step 3/6: Installing dependencies..."

# Update package list
apt-get update -qq

# Install avahi (mDNS) for auto-discovery
if ! command -v avahi-daemon &> /dev/null; then
    log_info "Installing avahi-daemon..."
    apt-get install -y -qq avahi-daemon avahi-utils libnss-mdns
    systemctl enable avahi-daemon
    systemctl restart avahi-daemon
    log_success "avahi-daemon installed"
else
    log_success "avahi-daemon already installed"
fi

# Install qrencode for QR code display
if ! command -v qrencode &> /dev/null; then
    log_info "Installing qrencode..."
    apt-get install -y -qq qrencode
    log_success "qrencode installed"
else
    log_success "qrencode already installed"
fi

# =============================================================================
# Step 4: Configure SSH for Control Center
# =============================================================================

log_info "Step 4/6: Configuring SSH access..."

# Ensure SSH is enabled
systemctl enable ssh
systemctl start ssh

# Create .ssh directory if not exists
SSH_DIR="$USER_HOME/.ssh"
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Fetch Control Center public key
log_info "Fetching Control Center public key..."
CONTROL_CENTER_PUBKEY_URL="${CONTROL_CENTER_URL}/api/bootstrap/pubkey"

if curl -fsSL "$CONTROL_CENTER_PUBKEY_URL" -o /tmp/control_center_pubkey 2>/dev/null; then
    # Add public key to authorized_keys
    AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
    touch "$AUTHORIZED_KEYS"

    # Check if key already exists
    if grep -Fq "$(cat /tmp/control_center_pubkey)" "$AUTHORIZED_KEYS" 2>/dev/null; then
        log_success "Control Center key already authorized"
    else
        cat /tmp/control_center_pubkey >> "$AUTHORIZED_KEYS"
        chmod 600 "$AUTHORIZED_KEYS"
        log_success "Control Center key added to authorized_keys"
    fi

    rm -f /tmp/control_center_pubkey
else
    log_warning "Could not fetch Control Center public key automatically"
    log_info "You may need to manually add SSH key later"
fi

# Fix ownership
chown -R "$CURRENT_USER:$CURRENT_USER" "$SSH_DIR"

# =============================================================================
# Step 5: Register Pi with Control Center
# =============================================================================

log_info "Step 5/6: Registering Pi with Control Center..."

# Prepare registration data
REGISTER_URL="${CONTROL_CENTER_URL}/api/bootstrap/register"
REGISTER_DATA=$(cat <<EOF
{
  "token": "$TOKEN_SHORT",
  "hostname": "$PI_HOSTNAME",
  "ip_address": "$PI_IP",
  "mac_address": "$PI_MAC",
  "metadata": {
    "model": "$PI_MODEL",
    "os": "$PI_OS",
    "arch": "$PI_ARCH"
  }
}
EOF
)

# Send registration request
if curl -fsSL -X POST "$REGISTER_URL" \
    -H "Content-Type: application/json" \
    -d "$REGISTER_DATA" \
    -o /tmp/register_response 2>/dev/null; then

    RESPONSE=$(cat /tmp/register_response)

    if echo "$RESPONSE" | grep -q '"success":true'; then
        log_success "Pi registered successfully!"
    else
        log_warning "Registration response received (may require manual pairing)"
    fi

    rm -f /tmp/register_response
else
    log_warning "Could not auto-register with Control Center"
    log_info "Manual pairing required using token: $TOKEN_SHORT"
fi

# =============================================================================
# Step 6: Save token locally
# =============================================================================

log_info "Step 6/6: Saving configuration..."

# Save token to local file
TOKEN_FILE="/etc/pi5-control-center.conf"
cat > "$TOKEN_FILE" <<EOF
# PI5 Control Center Configuration
# Generated: $(date)

TOKEN=$TOKEN_SHORT
CONTROL_CENTER_URL=$CONTROL_CENTER_URL
HOSTNAME=$PI_HOSTNAME
IP=$PI_IP
MAC=$PI_MAC
EOF

chmod 600 "$TOKEN_FILE"
log_success "Configuration saved to $TOKEN_FILE"

# =============================================================================
# Final Summary
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Pi Bootstrap Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}🔑 Pairing Token:${NC} ${YELLOW}${TOKEN_SHORT}${NC}"
echo ""
echo -e "${BLUE}📱 Next Steps:${NC}"
echo "   1. Open Control Center: $CONTROL_CENTER_URL"
echo "   2. Go to 'Add Pi' section"
echo "   3. Enter token: $TOKEN_SHORT"
echo "   4. Start managing this Pi!"
echo ""
echo -e "${BLUE}📊 Pi Information:${NC}"
echo "   Hostname: $PI_HOSTNAME"
echo "   IP: $PI_IP"
echo "   mDNS: ${PI_HOSTNAME}.local"
echo "   MAC: $PI_MAC"
echo ""

# Generate QR code for easy mobile scanning
QR_DATA="pi5cc://${TOKEN_SHORT}@${CONTROL_CENTER_URL}"
echo -e "${BLUE}📱 QR Code (scan with mobile):${NC}"
qrencode -t ANSIUTF8 "$QR_DATA" 2>/dev/null || echo "   (qrencode not available)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Save token display for later reference
cat > "$USER_HOME/pi5-bootstrap-token.txt" <<EOF
PI5 Control Center - Bootstrap Token
=====================================

Token: $TOKEN_SHORT
Control Center: $CONTROL_CENTER_URL

Open Control Center and enter this token to pair.

Generated: $(date)
EOF

chown "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/pi5-bootstrap-token.txt"
log_info "Token saved to: $USER_HOME/pi5-bootstrap-token.txt"

log_success "Bootstrap complete! This Pi is ready to be added to Control Center."
