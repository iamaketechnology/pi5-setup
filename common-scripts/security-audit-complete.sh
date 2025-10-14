#!/bin/bash
# =============================================================================
# PI5-SETUP GLOBAL SECURITY AUDIT
# =============================================================================
# Purpose: Comprehensive security audit for ALL installed stacks on Pi5
# Version: 1.0.0
# Author: PI5-SETUP Project
# Usage: sudo bash security-audit-complete.sh
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Auto-detect environment
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")
STACKS_DIR="${USER_HOME}/stacks"
# Global variables
REPORT_FILE="/var/log/pi5-security-audit-$(date +%Y%m%d_%H%M%S).log"
CRITICAL_ISSUES=0
WARNINGS=0
PASSED_CHECKS=0

# =============================================================================
# Logging Functions
# =============================================================================

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_section() {
    echo -e "${CYAN}▶ $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARNINGS++))
}

log_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((CRITICAL_ISSUES++))
}

log_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# =============================================================================
# System Information
# =============================================================================

gather_system_info() {
    print_header "🖥️  SYSTEM INFORMATION"

    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}OS:${NC} $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo -e "${CYAN}Kernel:${NC} $(uname -r)"
    echo -e "${CYAN}Architecture:${NC} $(uname -m)"
    echo -e "${CYAN}IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo -e "${CYAN}Uptime:${NC} $(uptime -p)"
    echo -e "${CYAN}Date:${NC} $(date)"
    echo ""
}

# =============================================================================
# 1. DOCKER STACK DETECTION
# =============================================================================

detect_installed_stacks() {
    print_header "📦 DETECTING INSTALLED STACKS"

    STACKS_DIR="${STACKS_DIR}"
    DETECTED_STACKS=()

    if [[ ! -d "$STACKS_DIR" ]]; then
        log_warn "No stacks directory found at $STACKS_DIR"
        return
    fi

    for stack_dir in "$STACKS_DIR"/*; do
        if [[ -d "$stack_dir" ]]; then
            stack_name=$(basename "$stack_dir")
            if docker ps --format '{{.Names}}' | grep -qi "$stack_name"; then
                DETECTED_STACKS+=("$stack_name")
                log_info "Found: $stack_name (running)"
            elif [[ -f "$stack_dir/docker-compose.yml" ]]; then
                DETECTED_STACKS+=("$stack_name")
                log_warn "Found: $stack_name (not running)"
            fi
        fi
    done

    echo ""
    echo -e "${GREEN}Detected ${#DETECTED_STACKS[@]} stack(s):${NC} ${DETECTED_STACKS[*]}"
    echo ""
}

# =============================================================================
# 2. NETWORK EXPOSURE AUDIT (ALL SERVICES)
# =============================================================================

audit_network_exposure() {
    print_header "🌐 NETWORK EXPOSURE AUDIT"

    print_section "Public Ports (0.0.0.0 - Internet accessible)"

    # Get all public listening ports
    public_ports=$(sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0" | awk '{print $4, $7}' | sort -u)

    if [[ -z "$public_ports" ]]; then
        log_pass "No public ports detected (very secure, but may break functionality)"
    else
        echo "$public_ports" | while read -r line; do
            port=$(echo "$line" | awk -F: '{print $2}' | awk '{print $1}')
            process=$(echo "$line" | awk '{print $2}')

            # Whitelist known safe public services
            case "$port" in
                22)
                    log_info "SSH (22) - $process [EXPECTED, ensure strong auth]"
                    ;;
                80|443)
                    log_pass "HTTP/HTTPS ($port) - $process [EXPECTED for web services]"
                    ;;
                8000|8001)
                    log_pass "Kong API ($port) - $process [EXPECTED for Supabase]"
                    ;;
                54321)
                    log_pass "Edge Functions ($port) - $process [EXPECTED for Supabase]"
                    ;;
                3000)
                    log_fail "Studio/Frontend ($port) PUBLIC - $process [SECURITY RISK if admin interface]"
                    ;;
                5432)
                    log_fail "PostgreSQL ($port) PUBLIC - $process [CRITICAL SECURITY RISK!]"
                    ;;
                6379)
                    log_fail "Redis ($port) PUBLIC - $process [CRITICAL SECURITY RISK!]"
                    ;;
                27017)
                    log_fail "MongoDB ($port) PUBLIC - $process [CRITICAL SECURITY RISK!]"
                    ;;
                9000)
                    log_warn "MinIO/Storage ($port) PUBLIC - $process [Verify if intended]"
                    ;;
                *)
                    log_info "Port $port - $process [Review if exposure is necessary]"
                    ;;
            esac
        done
    fi

    echo ""
    print_section "Localhost-Only Services (127.0.0.1 - Secured)"

    localhost_ports=$(sudo netstat -tlnp 2>/dev/null | grep "127.0.0.1" | awk '{print $4, $7}' | sort -u)

    if [[ -z "$localhost_ports" ]]; then
        log_warn "No localhost-only services found"
    else
        echo "$localhost_ports" | while read -r line; do
            port=$(echo "$line" | awk -F: '{print $2}' | awk '{print $1}')
            process=$(echo "$line" | awk '{print $2}')

            case "$port" in
                5432)
                    log_pass "PostgreSQL ($port) - LOCALHOST ONLY [SECURED]"
                    ;;
                3000)
                    log_pass "Studio/Admin ($port) - LOCALHOST ONLY [SECURED]"
                    ;;
                6379)
                    log_pass "Redis ($port) - LOCALHOST ONLY [SECURED]"
                    ;;
                *)
                    log_info "Port $port - $process [Localhost only]"
                    ;;
            esac
        done
    fi

    echo ""
}

# =============================================================================
# 3. DOCKER CONTAINER SECURITY
# =============================================================================

audit_docker_security() {
    print_header "🐳 DOCKER CONTAINER SECURITY"

    print_section "Running Containers"

    if ! docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' &>/dev/null; then
        log_fail "Docker is not running or not accessible"
        return
    fi

    docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    echo ""

    print_section "Privileged Containers (Security Risk)"

    privileged=$(docker ps --filter "label=com.docker.compose.privileged=true" --format '{{.Names}}' 2>/dev/null)
    if [[ -z "$privileged" ]]; then
        log_pass "No privileged containers detected"
    else
        log_warn "Privileged containers found: $privileged"
        echo "   Consider running without --privileged if possible"
    fi

    echo ""

    print_section "Containers Running as Root"

    root_containers=0
    for container in $(docker ps --format '{{.Names}}'); do
        user=$(docker inspect "$container" --format '{{.Config.User}}' 2>/dev/null)
        if [[ -z "$user" ]] || [[ "$user" == "0" ]] || [[ "$user" == "root" ]]; then
            log_warn "Container '$container' runs as root"
            ((root_containers++))
        fi
    done

    if [[ $root_containers -eq 0 ]]; then
        log_pass "All containers run as non-root users"
    else
        echo "   $root_containers container(s) run as root (common but not ideal)"
    fi

    echo ""
}

# =============================================================================
# 4. FIREWALL & SSH SECURITY
# =============================================================================

audit_firewall_ssh() {
    print_header "🔥 FIREWALL & SSH SECURITY"

    print_section "Firewall Status (UFW/iptables)"

    if command -v ufw &>/dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            log_pass "UFW firewall is active"
            sudo ufw status numbered | head -10
        else
            log_warn "UFW is installed but inactive"
            echo "   Enable with: sudo ufw enable"
        fi
    else
        log_info "UFW not installed (using iptables)"
        rules_count=$(sudo iptables -L INPUT -n | grep -c "ACCEPT\|DROP\|REJECT" || echo "0")
        if [[ $rules_count -gt 5 ]]; then
            log_pass "Custom iptables rules detected ($rules_count rules)"
        else
            log_warn "Few or no firewall rules detected"
            echo "   Consider installing UFW: sudo apt install ufw"
        fi
    fi

    echo ""

    print_section "SSH Security"

    ssh_config="/etc/ssh/sshd_config"

    # Check root login
    if grep -qE "^PermitRootLogin\s+(no|prohibit-password)" "$ssh_config"; then
        log_pass "SSH root login disabled"
    else
        log_fail "SSH root login is ENABLED (security risk)"
        echo "   Fix: Set 'PermitRootLogin no' in $ssh_config"
    fi

    # Check password authentication
    if grep -qE "^PasswordAuthentication\s+no" "$ssh_config"; then
        log_pass "SSH password authentication disabled (key-only)"
    else
        log_warn "SSH password authentication enabled"
        echo "   Consider: Set 'PasswordAuthentication no' for key-only auth"
    fi

    # Check SSH port
    ssh_port=$(grep -E "^Port\s+" "$ssh_config" | awk '{print $2}')
    if [[ -z "$ssh_port" ]] || [[ "$ssh_port" == "22" ]]; then
        log_info "SSH on default port 22 (consider changing to non-standard port)"
    else
        log_pass "SSH on custom port $ssh_port (reduces automated attacks)"
    fi

    # Check fail2ban
    if systemctl is-active --quiet fail2ban; then
        log_pass "Fail2ban is active (brute-force protection)"
    else
        log_warn "Fail2ban not installed/active"
        echo "   Install: sudo apt install fail2ban"
    fi

    echo ""
}

# =============================================================================
# 5. FILE PERMISSIONS & SECRETS
# =============================================================================

audit_file_permissions() {
    print_header "🔐 FILE PERMISSIONS & SECRETS"

    print_section "Sensitive Files Permissions"

    # Check .env files
    env_files=$(find ${STACKS_DIR} -name ".env" 2>/dev/null || true)

    if [[ -z "$env_files" ]]; then
        log_info "No .env files found"
    else
        while IFS= read -r env_file; do
            perms=$(stat -c "%a" "$env_file" 2>/dev/null || stat -f "%Lp" "$env_file" 2>/dev/null)
            if [[ "$perms" == "600" ]] || [[ "$perms" == "400" ]]; then
                log_pass "$env_file: $perms (secured)"
            else
                log_fail "$env_file: $perms (should be 600 or 400)"
                echo "   Fix: chmod 600 $env_file"
            fi
        done <<< "$env_files"
    fi

    echo ""

    print_section "Docker Compose Files"

    compose_files=$(find ${STACKS_DIR} -name "docker-compose.yml" 2>/dev/null || true)

    if [[ -z "$compose_files" ]]; then
        log_info "No docker-compose.yml files found"
    else
        while IFS= read -r compose_file; do
            # Check for plaintext secrets
            if grep -qE "(PASSWORD|SECRET|KEY|TOKEN)=[\'\"]?[a-zA-Z0-9]{8,}" "$compose_file"; then
                log_warn "$compose_file: Contains plaintext secrets (consider env vars)"
            else
                log_pass "$compose_file: No obvious plaintext secrets"
            fi
        done <<< "$compose_files"
    fi

    echo ""
}

# =============================================================================
# 6. SUPABASE-SPECIFIC CHECKS (if installed)
# =============================================================================

audit_supabase_security() {
    if ! echo "${DETECTED_STACKS[*]}" | grep -qi "supabase"; then
        return
    fi

    print_header "🗄️  SUPABASE SECURITY CHECKS"

    print_section "PostgreSQL Exposure"

    if sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:5432" | grep -v "127.0.0.1" >/dev/null 2>&1; then
        log_fail "PostgreSQL is PUBLIC (0.0.0.0:5432) - CRITICAL RISK!"
        echo "   Fix: Bind to 127.0.0.1 in docker-compose.yml"
    else
        log_pass "PostgreSQL is localhost-only (secured)"
    fi

    print_section "Supabase Studio Exposure"

    if sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:3000" | grep -v "127.0.0.1" >/dev/null 2>&1; then
        log_fail "Supabase Studio is PUBLIC (0.0.0.0:3000) - HIGH RISK!"
        echo "   Fix: Bind to 127.0.0.1 in docker-compose.yml"
    else
        log_pass "Supabase Studio is localhost-only (secured)"
    fi

    print_section "JWT Secrets"

    env_file="${STACKS_DIR}/supabase/.env"
    if [[ -f "$env_file" ]]; then
        jwt_secret=$(grep "^JWT_SECRET=" "$env_file" | cut -d= -f2 | tr -d '"')
        anon_key=$(grep "^ANON_KEY=" "$env_file" | cut -d= -f2 | tr -d '"')

        if [[ ${#jwt_secret} -ge 32 ]]; then
            log_pass "JWT_SECRET is strong (${#jwt_secret} chars)"
        else
            log_fail "JWT_SECRET is weak (${#jwt_secret} chars, minimum 32 recommended)"
        fi

        if [[ ${#anon_key} -ge 100 ]]; then
            log_pass "ANON_KEY is properly formatted JWT"
        else
            log_warn "ANON_KEY seems short (${#anon_key} chars)"
        fi
    else
        log_warn "Supabase .env file not found"
    fi

    echo ""
}

# =============================================================================
# 7. TRAEFIK-SPECIFIC CHECKS (if installed)
# =============================================================================

audit_traefik_security() {
    if ! echo "${DETECTED_STACKS[*]}" | grep -qi "traefik"; then
        return
    fi

    print_header "🚦 TRAEFIK SECURITY CHECKS"

    print_section "Dashboard Exposure"

    if sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:8080" >/dev/null 2>&1; then
        log_warn "Traefik dashboard may be public (port 8080)"
        echo "   Ensure it's password-protected or localhost-only"
    else
        log_pass "Traefik dashboard not publicly exposed"
    fi

    print_section "HTTPS Configuration"

    if docker logs traefik 2>/dev/null | grep -q "acme"; then
        log_pass "ACME/Let's Encrypt detected (HTTPS enabled)"
    else
        log_info "Cannot verify HTTPS status from logs"
    fi

    echo ""
}

# =============================================================================
# 8. SYSTEM SECURITY CHECKS
# =============================================================================

audit_system_security() {
    print_header "🖥️  SYSTEM-LEVEL SECURITY"

    print_section "Unattended Upgrades"

    if dpkg -l | grep -q unattended-upgrades; then
        if systemctl is-enabled unattended-upgrades &>/dev/null; then
            log_pass "Automatic security updates enabled"
        else
            log_warn "unattended-upgrades installed but not enabled"
        fi
    else
        log_warn "Automatic security updates not configured"
        echo "   Install: sudo apt install unattended-upgrades"
    fi

    print_section "Package Updates"

    updates=$(apt list --upgradable 2>/dev/null | grep -c "upgradable" || echo "0")
    if [[ $updates -eq 0 ]]; then
        log_pass "System is up-to-date"
    else
        log_warn "$updates package updates available"
        echo "   Update: sudo apt update && sudo apt upgrade"
    fi

    print_section "User Security"

    # Check for users with empty passwords
    empty_pass=$(sudo awk -F: '($2 == "" ) { print $1 }' /etc/shadow 2>/dev/null || true)
    if [[ -z "$empty_pass" ]]; then
        log_pass "No users with empty passwords"
    else
        log_fail "Users with empty passwords: $empty_pass"
    fi

    echo ""
}

# =============================================================================
# 9. FINAL REPORT & RECOMMENDATIONS
# =============================================================================

generate_final_report() {
    print_header "📊 SECURITY AUDIT SUMMARY"

    echo -e "${CYAN}Audit Date:${NC} $(date)"
    echo -e "${CYAN}Hostname:${NC} $(hostname)"
    echo -e "${CYAN}IP Address:${NC} $(hostname -I | awk '{print $1}')"
    echo ""

    echo -e "${GREEN}✅ Passed Checks: $PASSED_CHECKS${NC}"
    echo -e "${YELLOW}⚠️  Warnings: $WARNINGS${NC}"
    echo -e "${RED}❌ Critical Issues: $CRITICAL_ISSUES${NC}"
    echo ""

    # Security score
    total_checks=$((PASSED_CHECKS + WARNINGS + CRITICAL_ISSUES))
    if [[ $total_checks -eq 0 ]]; then
        total_checks=1  # Avoid division by zero
    fi

    score=$((PASSED_CHECKS * 100 / total_checks))

    echo -e "${CYAN}Overall Security Score: ${NC}"
    if [[ $score -ge 80 ]]; then
        echo -e "${GREEN}█████████░ $score% - EXCELLENT${NC}"
    elif [[ $score -ge 60 ]]; then
        echo -e "${YELLOW}███████░░░ $score% - GOOD${NC}"
    elif [[ $score -ge 40 ]]; then
        echo -e "${YELLOW}█████░░░░░ $score% - NEEDS IMPROVEMENT${NC}"
    else
        echo -e "${RED}███░░░░░░░ $score% - CRITICAL${NC}"
    fi

    echo ""

    print_section "Priority Actions"

    if [[ $CRITICAL_ISSUES -gt 0 ]]; then
        echo -e "${RED}🚨 ADDRESS CRITICAL ISSUES IMMEDIATELY:${NC}"
        echo "   1. Secure public database ports (PostgreSQL, MongoDB, Redis)"
        echo "   2. Move admin interfaces to localhost (Studio, dashboards)"
        echo "   3. Fix file permissions on .env files (chmod 600)"
        echo ""
    fi

    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  RECOMMENDED IMPROVEMENTS:${NC}"
        echo "   1. Enable firewall (UFW) if not already active"
        echo "   2. Install fail2ban for brute-force protection"
        echo "   3. Enable automatic security updates"
        echo "   4. Use SSH keys instead of passwords"
        echo ""
    fi

    if [[ $CRITICAL_ISSUES -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}🎉 CONGRATULATIONS!${NC}"
        echo "   Your Pi5-Setup security posture is excellent!"
        echo "   Continue monitoring and keep systems updated."
        echo ""
    fi

    echo -e "${CYAN}Full report saved to: $REPORT_FILE${NC}"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Check root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi

    # Redirect output to log file
    exec > >(tee -a "$REPORT_FILE")
    exec 2>&1

    print_header "🛡️  PI5-SETUP COMPREHENSIVE SECURITY AUDIT"
    echo -e "${CYAN}Starting security audit...${NC}"
    echo ""

    gather_system_info
    detect_installed_stacks
    audit_network_exposure
    audit_docker_security
    audit_firewall_ssh
    audit_file_permissions
    audit_supabase_security
    audit_traefik_security
    audit_system_security
    generate_final_report

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Audit completed successfully!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Run main function
main "$@"
