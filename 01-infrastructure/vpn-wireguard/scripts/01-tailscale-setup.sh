#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Tailscale VPN Setup for Raspberry Pi 5
# =============================================================================
# Purpose: Install and configure Tailscale VPN for secure remote access
# Architecture: ARM64 (Raspberry Pi 5)
# Network: WireGuard-based mesh VPN
# Features: Subnet router, exit node, MagicDNS, device sharing
# Use Case: Secure remote access, private mesh network, service exposure
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-10 minutes (+ user authentication time)
# Version: 1.0.0
# =============================================================================

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPTS_DIR="${SCRIPT_DIR}/../../common-scripts"

if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
    # shellcheck source=../../common-scripts/lib.sh
    source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
    # Fallback color functions
    log_info()    { echo -e "\033[1;36m[INFO]\033[0m $*"; }
    log_warn()    { echo -e "\033[1;33m[WARN]\033[0m $*"; }
    log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $*"; }
    log_success() { echo -e "\033[1;32m[OK]\033[0m $*"; }
    fatal()       { log_error "$*"; exit 1; }
    confirm()     { read -r -p "$1 [y/N]: " response; [[ "$response" =~ ^[Yy]$ ]]; }
fi

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/tailscale-setup-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
STACK_NAME="tailscale"

# Configuration variables (can be set via environment)
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"
ENABLE_SUBNET_ROUTER="${ENABLE_SUBNET_ROUTER:-}"
ENABLE_EXIT_NODE="${ENABLE_EXIT_NODE:-}"
ENABLE_MAGIC_DNS="${ENABLE_MAGIC_DNS:-yes}"
DISABLE_KEY_EXPIRY="${DISABLE_KEY_EXPIRY:-}"
ADVERTISE_ROUTES="${ADVERTISE_ROUTES:-}"
HOSTNAME_OVERRIDE="${HOSTNAME_OVERRIDE:-}"

# Detection flags
GRAFANA_DETECTED=0
HOMEPAGE_DETECTED=0
SUPABASE_DETECTED=0

# =============================================================================
# LOGGING SETUP
# =============================================================================

setup_logging() {
    # Create log file with proper permissions
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    # Redirect output to log file while keeping terminal output
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    log_info "=== Tailscale Setup Script v${SCRIPT_VERSION} ==="
    log_info "Started at: $(date)"
    log_info "Log file: $LOG_FILE"
    log_info "User: $TARGET_USER"
    echo ""
}

# =============================================================================
# VALIDATION SECTION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        fatal "This script must be run as root. Usage: sudo $0"
    fi
}

check_architecture() {
    log_info "Checking system architecture..."

    local arch
    arch=$(uname -m)

    if [[ "$arch" != "aarch64" ]]; then
        fatal "Unsupported architecture: $arch (ARM64/aarch64 required for Pi 5)"
    fi

    log_success "Architecture: ARM64 (aarch64) - Compatible"
}

check_system_resources() {
    log_info "Checking system resources..."

    # Check RAM
    local ram_gb
    ram_gb=$(free -g | awk '/^Mem:/{print $2}')

    if [[ $ram_gb -lt 1 ]]; then
        log_warn "Low RAM detected: ${ram_gb}GB (minimum 1GB recommended for Tailscale)"
    else
        log_success "RAM: ${ram_gb}GB - Sufficient"
    fi

    # Check disk space
    local disk_gb
    disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')

    if [[ $disk_gb -lt 1 ]]; then
        log_warn "Low disk space: ${disk_gb}GB available (minimum 1GB recommended)"
    else
        log_success "Disk space: ${disk_gb}GB available - Sufficient"
    fi

    # Check internet connectivity
    if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null; then
        fatal "No internet connectivity. Tailscale requires internet access for initial setup."
    fi
    log_success "Internet connectivity: OK"
}

check_kernel_modules() {
    log_info "Checking required kernel modules..."

    local required_modules=("tun" "wireguard")
    local missing_modules=()

    for module in "${required_modules[@]}"; do
        if ! lsmod | grep -q "^${module}"; then
            # Try to load the module
            if modprobe "$module" 2>/dev/null; then
                log_success "Loaded kernel module: $module"
            else
                missing_modules+=("$module")
            fi
        else
            log_success "Kernel module present: $module"
        fi
    done

    if [[ ${#missing_modules[@]} -gt 0 ]]; then
        log_warn "Some kernel modules could not be loaded: ${missing_modules[*]}"
        log_warn "Tailscale may still work using userspace networking (slower)"
    fi
}

detect_existing_vpns() {
    log_info "Detecting existing VPN installations..."

    local vpns_found=()

    # Check for WireGuard
    if command -v wg &>/dev/null || systemctl list-unit-files | grep -q wg-quick; then
        vpns_found+=("WireGuard")
    fi

    # Check for OpenVPN
    if command -v openvpn &>/dev/null || systemctl list-unit-files | grep -q openvpn; then
        vpns_found+=("OpenVPN")
    fi

    # Check for existing Tailscale
    if command -v tailscale &>/dev/null; then
        log_warn "Tailscale is already installed"

        # Check if it's running
        if systemctl is-active --quiet tailscaled; then
            log_warn "Tailscale daemon is running"

            # Get current status
            local ts_status
            ts_status=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

            if [[ "$ts_status" == "Running" ]]; then
                log_warn "Tailscale is already connected and running"

                if [[ "${ASSUME_YES}" -ne 1 ]]; then
                    if ! confirm "Tailscale is already running. Do you want to reconfigure it?"; then
                        fatal "Installation cancelled by user"
                    fi
                fi
            fi
        fi
    fi

    if [[ ${#vpns_found[@]} -gt 0 ]]; then
        log_warn "Other VPN software detected: ${vpns_found[*]}"
        log_warn "Multiple VPNs can coexist but may cause routing conflicts"
    fi
}

detect_existing_services() {
    log_info "Detecting existing services for integration..."

    # Check for Grafana
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q grafana; then
        GRAFANA_DETECTED=1
        log_info "Grafana detected - will provide integration tips"
    fi

    # Check for Homepage
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q homepage; then
        HOMEPAGE_DETECTED=1
        log_info "Homepage detected - will provide integration tips"
    fi

    # Check for Supabase
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q supabase; then
        SUPABASE_DETECTED=1
        log_info "Supabase detected - will provide integration tips"
    fi
}

# =============================================================================
# INSTALLATION SECTION
# =============================================================================

install_tailscale() {
    log_info "Installing Tailscale..."

    # Check if already installed
    if command -v tailscale &>/dev/null; then
        local installed_version
        installed_version=$(tailscale version | head -n1 | awk '{print $1}')
        log_warn "Tailscale already installed (version: $installed_version)"
        log_info "Checking for updates..."
    fi

    # Add Tailscale repository
    log_info "Adding Tailscale APT repository..."

    # Install prerequisites
    if ! command -v curl &>/dev/null; then
        log_info "Installing curl..."
        apt-get update -qq
        apt-get install -y curl
    fi

    if ! command -v gpg &>/dev/null; then
        log_info "Installing gnupg..."
        apt-get install -y gnupg
    fi

    # Add Tailscale's GPG key
    if [[ ! -f /usr/share/keyrings/tailscale-archive-keyring.gpg ]]; then
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | \
            tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
        log_success "Added Tailscale GPG key"
    fi

    # Add Tailscale repository
    if [[ ! -f /etc/apt/sources.list.d/tailscale.list ]]; then
        curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | \
            tee /etc/apt/sources.list.d/tailscale.list >/dev/null
        log_success "Added Tailscale repository"
    fi

    # Update package lists
    log_info "Updating package lists..."
    apt-get update -qq

    # Install Tailscale
    log_info "Installing Tailscale package..."
    if apt-get install -y tailscale; then
        log_success "Tailscale installed successfully"
    else
        fatal "Failed to install Tailscale"
    fi

    # Verify installation
    if ! command -v tailscale &>/dev/null; then
        fatal "Tailscale installation failed - command not found"
    fi

    local version
    version=$(tailscale version | head -n1)
    log_success "Tailscale version: $version"

    # Enable and start Tailscale daemon
    log_info "Enabling Tailscale daemon..."
    systemctl enable tailscaled
    systemctl start tailscaled

    # Wait for daemon to be ready
    sleep 2

    if systemctl is-active --quiet tailscaled; then
        log_success "Tailscale daemon is running"
    else
        fatal "Tailscale daemon failed to start"
    fi
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

configure_ip_forwarding() {
    log_info "Configuring IP forwarding for subnet router/exit node..."

    # Check current settings
    local ipv4_forward
    local ipv6_forward
    ipv4_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    ipv6_forward=$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null || echo "0")

    if [[ "$ipv4_forward" == "1" ]]; then
        log_info "IPv4 forwarding already enabled"
    else
        log_info "Enabling IPv4 forwarding..."

        # Enable for current session
        sysctl -w net.ipv4.ip_forward=1 >/dev/null

        # Make persistent
        if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi

        log_success "IPv4 forwarding enabled"
    fi

    if [[ "$ipv6_forward" == "1" ]]; then
        log_info "IPv6 forwarding already enabled"
    else
        log_info "Enabling IPv6 forwarding..."

        # Enable for current session
        sysctl -w net.ipv6.conf.all.forwarding=1 >/dev/null

        # Make persistent
        if ! grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf; then
            echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
        fi

        log_success "IPv6 forwarding enabled"
    fi

    # Reload sysctl
    sysctl -p >/dev/null 2>&1 || true
}

configure_firewall() {
    log_info "Configuring firewall for Tailscale..."

    # Check if UFW is installed and active
    if command -v ufw &>/dev/null; then
        if ufw status | grep -q "Status: active"; then
            log_info "UFW is active - configuring Tailscale rules..."

            # Allow Tailscale interface
            if ! ufw status | grep -q "Anywhere on tailscale0"; then
                ufw allow in on tailscale0 comment "Tailscale VPN" >/dev/null 2>&1 || true
                log_success "Added UFW rule for Tailscale interface"
            else
                log_info "UFW rule for Tailscale already exists"
            fi

            # Allow Tailscale UDP port (41641)
            if ! ufw status | grep -q "41641/udp"; then
                ufw allow 41641/udp comment "Tailscale" >/dev/null 2>&1 || true
                log_success "Allowed Tailscale UDP port 41641"
            fi

            # Reload UFW
            ufw reload >/dev/null 2>&1 || true
            log_success "UFW configured for Tailscale"
        else
            log_warn "UFW is installed but not active"
        fi
    else
        log_warn "UFW not installed - skipping firewall configuration"
        log_warn "Tailscale will work, but firewall rules are recommended"
    fi
}

detect_local_network() {
    log_info "Detecting local network configuration..."

    # Get default gateway interface
    local default_iface
    default_iface=$(ip route | grep default | awk '{print $5}' | head -n1)

    if [[ -z "$default_iface" ]]; then
        log_warn "Could not detect default network interface"
        return 1
    fi

    log_info "Default interface: $default_iface"

    # Get IP address and subnet
    local ip_info
    ip_info=$(ip -o -f inet addr show "$default_iface" | awk '{print $4}')

    if [[ -z "$ip_info" ]]; then
        log_warn "Could not detect IP address on $default_iface"
        return 1
    fi

    log_info "Local network: $ip_info"

    # Extract subnet
    local subnet
    subnet=$(echo "$ip_info" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+')

    # Convert to network address (e.g., 192.168.1.100/24 -> 192.168.1.0/24)
    local network
    network=$(echo "$subnet" | awk -F'/' '{
        split($1, ip, ".")
        cidr = $2
        if (cidr == 24) {
            printf "%d.%d.%d.0/%s\n", ip[1], ip[2], ip[3], cidr
        } else if (cidr == 16) {
            printf "%d.%d.0.0/%s\n", ip[1], ip[2], cidr
        } else if (cidr == 8) {
            printf "%d.0.0.0/%s\n", ip[1], cidr
        } else {
            print $0
        }
    }')

    log_success "Detected local network: $network"
    echo "$network"
}

# =============================================================================
# TAILSCALE CONFIGURATION
# =============================================================================

get_user_preferences() {
    log_info "Gathering configuration preferences..."
    echo ""

    # Skip prompts if running with --yes and environment variables are set
    if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
        log_info "Running in automated mode (--yes flag)"

        # Subnet router
        if [[ -z "$ENABLE_SUBNET_ROUTER" ]]; then
            ENABLE_SUBNET_ROUTER="no"
        fi

        # Exit node
        if [[ -z "$ENABLE_EXIT_NODE" ]]; then
            ENABLE_EXIT_NODE="no"
        fi

        # Key expiry
        if [[ -z "$DISABLE_KEY_EXPIRY" ]]; then
            DISABLE_KEY_EXPIRY="yes"
        fi

        log_info "Subnet router: $ENABLE_SUBNET_ROUTER"
        log_info "Exit node: $ENABLE_EXIT_NODE"
        log_info "Disable key expiry: $DISABLE_KEY_EXPIRY"
        echo ""
        return 0
    fi

    # Interactive mode - ask user preferences
    echo "==================================================================="
    echo "  Tailscale Configuration Options"
    echo "==================================================================="
    echo ""
    echo "1. Subnet Router:"
    echo "   Share your local network (192.168.x.x) with Tailscale devices"
    echo "   Example: Access other devices on your home network remotely"
    echo ""

    if confirm "   Enable subnet router?"; then
        ENABLE_SUBNET_ROUTER="yes"

        # Detect local network
        local detected_network
        detected_network=$(detect_local_network)

        if [[ -n "$detected_network" ]]; then
            echo ""
            echo "   Detected network: $detected_network"

            if confirm "   Use this network for subnet routing?"; then
                ADVERTISE_ROUTES="$detected_network"
            else
                read -r -p "   Enter network to advertise (e.g., 192.168.1.0/24): " ADVERTISE_ROUTES
            fi
        else
            read -r -p "   Enter network to advertise (e.g., 192.168.1.0/24): " ADVERTISE_ROUTES
        fi
    else
        ENABLE_SUBNET_ROUTER="no"
    fi

    echo ""
    echo "2. Exit Node:"
    echo "   Route all internet traffic through this device"
    echo "   Example: Use your home IP when traveling"
    echo ""

    if confirm "   Enable exit node?"; then
        ENABLE_EXIT_NODE="yes"
    else
        ENABLE_EXIT_NODE="no"
    fi

    echo ""
    echo "3. Key Expiry:"
    echo "   By default, Tailscale keys expire after 180 days"
    echo "   For always-on servers, it's recommended to disable expiry"
    echo ""

    if confirm "   Disable key expiry (recommended for servers)?"; then
        DISABLE_KEY_EXPIRY="yes"
    else
        DISABLE_KEY_EXPIRY="no"
    fi

    echo ""
    echo "4. Hostname:"
    echo "   Default: $(hostname)"
    echo ""

    if confirm "   Use custom hostname?"; then
        read -r -p "   Enter hostname: " HOSTNAME_OVERRIDE
    fi

    echo ""
    echo "==================================================================="
    echo ""
}

connect_tailscale() {
    log_info "Connecting to Tailscale network..."
    echo ""

    # Build tailscale up command
    local ts_args=()

    # Add authkey if provided (for automated setup)
    if [[ -n "$TAILSCALE_AUTHKEY" ]]; then
        log_info "Using provided auth key for unattended setup"
        ts_args+=("--authkey=$TAILSCALE_AUTHKEY")
    fi

    # Add advertise routes (subnet router)
    if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]] && [[ -n "$ADVERTISE_ROUTES" ]]; then
        log_info "Enabling subnet router for: $ADVERTISE_ROUTES"
        ts_args+=("--advertise-routes=$ADVERTISE_ROUTES")
    fi

    # Add exit node
    if [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
        log_info "Enabling exit node capability"
        ts_args+=("--advertise-exit-node")
    fi

    # Add hostname
    if [[ -n "$HOSTNAME_OVERRIDE" ]]; then
        log_info "Using custom hostname: $HOSTNAME_OVERRIDE"
        ts_args+=("--hostname=$HOSTNAME_OVERRIDE")
    fi

    # Accept routes (to use exit nodes/subnet routers from other devices)
    ts_args+=("--accept-routes")

    # Accept DNS (MagicDNS)
    if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
        log_info "Enabling MagicDNS"
        ts_args+=("--accept-dns")
    fi

    # SSH support (allows Tailscale SSH)
    ts_args+=("--ssh")

    echo ""
    log_info "Running: tailscale up ${ts_args[*]}"
    echo ""

    # Run tailscale up
    if tailscale up "${ts_args[@]}"; then
        log_success "Tailscale connection initiated successfully"
    else
        fatal "Failed to connect to Tailscale"
    fi

    echo ""

    # Wait for connection to establish
    log_info "Waiting for connection to establish..."
    sleep 3

    # Check connection status
    local max_wait=30
    local waited=0

    while [[ $waited -lt $max_wait ]]; do
        local status
        status=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "unknown")

        if [[ "$status" == "Running" ]]; then
            log_success "Connected to Tailscale!"
            break
        elif [[ "$status" == "NeedsLogin" ]]; then
            log_warn "Authentication required - waiting for user to authenticate..."
            sleep 5
            waited=$((waited + 5))
        else
            sleep 2
            waited=$((waited + 2))
        fi
    done

    # Disable key expiry if requested
    if [[ "$DISABLE_KEY_EXPIRY" == "yes" ]]; then
        echo ""
        log_warn "To disable key expiry, go to Tailscale admin console:"
        log_warn "  https://login.tailscale.com/admin/machines"
        log_warn "  Find this device and disable key expiry in settings"
        log_warn "  (This cannot be done via CLI for security reasons)"
    fi
}

verify_connection() {
    log_info "Verifying Tailscale connection..."

    # Get Tailscale status
    if ! tailscale status &>/dev/null; then
        log_warn "Could not get Tailscale status"
        return 1
    fi

    # Get Tailscale IP
    local ts_ip
    ts_ip=$(tailscale ip -4 2>/dev/null)

    if [[ -z "$ts_ip" ]]; then
        log_warn "No Tailscale IPv4 address assigned yet"
        return 1
    fi

    log_success "Tailscale IPv4: $ts_ip"

    # Get Tailscale IPv6 (optional)
    local ts_ip6
    ts_ip6=$(tailscale ip -6 2>/dev/null || echo "")

    if [[ -n "$ts_ip6" ]]; then
        log_success "Tailscale IPv6: $ts_ip6"
    fi

    # Check if subnet router is approved (if enabled)
    if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]]; then
        echo ""
        log_warn "Subnet router requires approval in Tailscale admin console"
        log_warn "  1. Go to: https://login.tailscale.com/admin/machines"
        log_warn "  2. Find this device: $(hostname)"
        log_warn "  3. Click 'Edit route settings'"
        log_warn "  4. Approve the advertised routes: $ADVERTISE_ROUTES"
    fi

    # Check if exit node is approved (if enabled)
    if [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
        echo ""
        log_warn "Exit node requires approval in Tailscale admin console"
        log_warn "  1. Go to: https://login.tailscale.com/admin/machines"
        log_warn "  2. Find this device: $(hostname)"
        log_warn "  3. Click 'Edit route settings'"
        log_warn "  4. Approve as exit node"
    fi

    return 0
}

# =============================================================================
# SERVICE INTEGRATION
# =============================================================================

show_integration_tips() {
    echo ""
    echo "==================================================================="
    echo "  Service Integration Tips"
    echo "==================================================================="
    echo ""

    local ts_ip
    ts_ip=$(tailscale ip -4 2>/dev/null || echo "TAILSCALE_IP")

    local ts_hostname
    ts_hostname=$(tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || hostname)

    if [[ $GRAFANA_DETECTED -eq 1 ]]; then
        echo "📊 Grafana Access via Tailscale:"
        echo "   http://$ts_ip:3001"
        if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
            echo "   http://$ts_hostname:3001"
        fi
        echo ""
    fi

    if [[ $HOMEPAGE_DETECTED -eq 1 ]]; then
        echo "🏠 Homepage Access via Tailscale:"
        echo "   http://$ts_ip:3000"
        if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
            echo "   http://$ts_hostname:3000"
        fi
        echo ""
    fi

    if [[ $SUPABASE_DETECTED -eq 1 ]]; then
        echo "🗄️ Supabase Access via Tailscale:"
        echo "   Studio: http://$ts_ip:8001"
        echo "   API:    http://$ts_ip:8000"
        if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
            echo "   Studio: http://$ts_hostname:8001"
            echo "   API:    http://$ts_hostname:8000"
        fi
        echo ""
    fi

    echo "💡 To add services to Homepage/Grafana:"
    echo "   Use Tailscale IPs or hostnames instead of local IPs"
    echo "   This allows access from anywhere via Tailscale"
    echo ""
    echo "==================================================================="
    echo ""
}

# =============================================================================
# SUMMARY AND NEXT STEPS
# =============================================================================

show_summary() {
    local ts_ip
    local ts_ip6
    local ts_hostname
    local ts_status

    ts_ip=$(tailscale ip -4 2>/dev/null || echo "Not assigned")
    ts_ip6=$(tailscale ip -6 2>/dev/null || echo "Not assigned")
    ts_hostname=$(tailscale status --json 2>/dev/null | grep -o '"HostName":"[^"]*"' | cut -d'"' -f4 || hostname)
    ts_status=$(tailscale status --json 2>/dev/null | grep -o '"BackendState":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")

    echo ""
    echo "==================================================================="
    echo "  🎉 Tailscale Setup Complete!"
    echo "==================================================================="
    echo ""
    echo "✅ Installation Summary:"
    echo "   Status:        $ts_status"
    echo "   IPv4 Address:  $ts_ip"
    echo "   IPv6 Address:  $ts_ip6"
    echo "   Hostname:      $ts_hostname"
    echo "   Device Name:   $(hostname)"
    echo ""

    if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]]; then
        echo "   Subnet Router: Enabled (awaiting approval)"
        echo "   Routes:        $ADVERTISE_ROUTES"
        echo ""
    fi

    if [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
        echo "   Exit Node:     Enabled (awaiting approval)"
        echo ""
    fi

    if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
        echo "   MagicDNS:      Enabled"
        echo ""
    fi

    echo "🔧 Tailscale Admin Console:"
    echo "   https://login.tailscale.com/admin/machines"
    echo ""

    if [[ "$ts_status" != "Running" ]]; then
        echo "⚠️  Current Status: $ts_status"
        echo ""
        echo "   If you need to authenticate:"
        echo "     tailscale up"
        echo ""
        echo "   Then visit the provided URL to authenticate"
        echo ""
    fi

    echo "📱 Install Tailscale Clients:"
    echo "   iOS:     https://apps.apple.com/app/tailscale/id1470499037"
    echo "   Android: https://play.google.com/store/apps/details?id=com.tailscale.ipn"
    echo "   macOS:   https://tailscale.com/download/mac"
    echo "   Windows: https://tailscale.com/download/windows"
    echo "   Linux:   https://tailscale.com/download/linux"
    echo ""

    echo "📋 Useful Commands:"
    echo "   tailscale status              # Show connection status"
    echo "   tailscale ip                  # Show Tailscale IPs"
    echo "   tailscale ping <device>       # Ping another device"
    echo "   tailscale up                  # Reconnect/reconfigure"
    echo "   tailscale down                # Disconnect"
    echo "   tailscale ssh <device>        # SSH to another device"
    echo ""

    echo "🔍 Testing Connection:"
    echo "   1. Install Tailscale on your phone/laptop"
    echo "   2. Sign in with the same account"
    echo "   3. Try accessing: http://$ts_ip:8080 (Portainer)"
    if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
        echo "   4. Or use hostname: http://$ts_hostname:8080"
    fi
    echo ""

    if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]] || [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
        echo "⚠️  Important: Approve Settings in Admin Console"
        echo "   1. Go to https://login.tailscale.com/admin/machines"
        echo "   2. Find device: $(hostname)"
        echo "   3. Click 'Edit route settings'"

        if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]]; then
            echo "   4. Approve subnet routes: $ADVERTISE_ROUTES"
        fi

        if [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
            echo "   5. Approve as exit node"
        fi
        echo ""
    fi

    if [[ $GRAFANA_DETECTED -eq 1 ]] || [[ $HOMEPAGE_DETECTED -eq 1 ]] || [[ $SUPABASE_DETECTED -eq 1 ]]; then
        show_integration_tips
    fi

    echo "📚 Documentation:"
    echo "   Tailscale Docs: https://tailscale.com/kb"
    echo "   Pi5-Setup Docs: https://github.com/iamaketechnology/pi5-setup"
    echo ""

    echo "📋 Log file: $LOG_FILE"
    echo "==================================================================="
    echo ""
}

# =============================================================================
# DRY RUN MODE
# =============================================================================

show_dry_run_summary() {
    echo ""
    echo "==================================================================="
    echo "  🔍 DRY RUN MODE - No Changes Made"
    echo "==================================================================="
    echo ""
    echo "The following actions would be performed:"
    echo ""
    echo "1. ✓ Install Tailscale from official repository"
    echo "2. ✓ Enable IP forwarding (IPv4 and IPv6)"
    echo "3. ✓ Configure UFW firewall rules"
    echo "4. ✓ Connect to Tailscale network with settings:"

    if [[ "$ENABLE_SUBNET_ROUTER" == "yes" ]]; then
        echo "     - Subnet router: $ADVERTISE_ROUTES"
    fi

    if [[ "$ENABLE_EXIT_NODE" == "yes" ]]; then
        echo "     - Exit node: enabled"
    fi

    if [[ "$ENABLE_MAGIC_DNS" == "yes" ]]; then
        echo "     - MagicDNS: enabled"
    fi

    echo ""
    echo "To perform actual installation, run without --dry-run flag"
    echo "==================================================================="
    echo ""
}

# =============================================================================
# CLEANUP
# =============================================================================

cleanup() {
    log_info "Cleaning up temporary files..."

    # Clean package cache
    apt-get clean >/dev/null 2>&1 || true

    log_success "Cleanup complete"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

show_help() {
    cat << EOF
Tailscale VPN Setup Script v${SCRIPT_VERSION}

Usage: sudo $0 [OPTIONS]

Options:
  --dry-run           Show what would be done without making changes
  --yes, -y           Skip confirmation prompts (use with env vars)
  --verbose, -v       Enable verbose output
  --quiet, -q         Minimize output
  --help, -h          Show this help message

Environment Variables:
  TAILSCALE_AUTHKEY         Pre-generated auth key for unattended setup
  ENABLE_SUBNET_ROUTER      Enable subnet router (yes/no)
  ENABLE_EXIT_NODE          Enable exit node (yes/no)
  ENABLE_MAGIC_DNS          Enable MagicDNS (yes/no, default: yes)
  DISABLE_KEY_EXPIRY        Disable key expiry (yes/no)
  ADVERTISE_ROUTES          Routes to advertise (e.g., 192.168.1.0/24)
  HOSTNAME_OVERRIDE         Custom hostname for Tailscale

Examples:
  # Interactive installation
  sudo ./01-tailscale-setup.sh

  # Automated installation with auth key
  sudo TAILSCALE_AUTHKEY=tskey-xxxxx ./01-tailscale-setup.sh --yes

  # Enable subnet router for home network
  sudo ENABLE_SUBNET_ROUTER=yes ADVERTISE_ROUTES=192.168.1.0/24 ./01-tailscale-setup.sh --yes

  # Enable as exit node
  sudo ENABLE_EXIT_NODE=yes ./01-tailscale-setup.sh --yes

  # Dry run to see what would happen
  sudo ./01-tailscale-setup.sh --dry-run

Documentation:
  https://github.com/iamaketechnology/pi5-setup/tree/main/pi5-vpn-stack

Tailscale Documentation:
  https://tailscale.com/kb

EOF
}

main() {
    # Parse common arguments
    if declare -f parse_common_args >/dev/null 2>&1; then
        parse_common_args "$@"
        set -- "${COMMON_POSITIONAL_ARGS[@]}"
    else
        # Fallback argument parsing
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --dry-run)
                    DRY_RUN=1
                    ;;
                --yes|-y)
                    ASSUME_YES=1
                    ;;
                --verbose|-v)
                    VERBOSE=1
                    ;;
                --quiet|-q)
                    QUIET=1
                    ;;
                --help|-h)
                    show_help
                    exit 0
                    ;;
                *)
                    echo "Unknown option: $1"
                    show_help
                    exit 1
                    ;;
            esac
            shift
        done
    fi

    # Show help if requested
    if [[ "${SHOW_HELP:-0}" -eq 1 ]]; then
        show_help
        exit 0
    fi

    # Setup logging
    setup_logging

    # Require root
    require_root

    # Banner
    echo ""
    log_info "==================================================================="
    log_info "  Tailscale VPN Setup for Raspberry Pi 5"
    log_info "  Version: $SCRIPT_VERSION"
    log_info "==================================================================="
    echo ""

    # Validation checks
    check_architecture
    check_system_resources
    check_kernel_modules
    detect_existing_vpns
    detect_existing_services
    echo ""

    # Get user preferences (unless running automated with env vars)
    get_user_preferences

    # Show dry run summary and exit
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
        show_dry_run_summary
        exit 0
    fi

    # Installation
    log_info "Starting Tailscale installation..."
    echo ""

    install_tailscale
    echo ""

    configure_ip_forwarding
    echo ""

    configure_firewall
    echo ""

    # Connect to Tailscale
    connect_tailscale
    echo ""

    # Verify connection
    verify_connection
    echo ""

    # Cleanup
    cleanup
    echo ""

    # Show summary
    show_summary

    log_success "Tailscale setup completed successfully!"
}

# Run main function
main "$@"
