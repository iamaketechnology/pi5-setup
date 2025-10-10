#!/usr/bin/env bash
# =============================================================================
# Edge Functions Deployment Script for Supabase Pi 5
# =============================================================================
#
# Purpose: Deploy Edge Functions from local project to self-hosted Supabase
#
# Author: Claude Code Assistant
# Version: 1.0.0
# Target: Raspberry Pi 5 ARM64, Self-hosted Supabase
#
# Usage:
#   # Deploy from local supabase/functions directory
#   sudo bash deploy-edge-functions.sh /path/to/your-app/supabase/functions
#
#   # Deploy with custom Pi host
#   sudo bash deploy-edge-functions.sh /path/to/functions pi@192.168.1.100
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Default values
DEFAULT_PI_HOST="pi@192.168.1.74"
DEFAULT_SUPABASE_DIR="/home/pi/stacks/supabase"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    echo -e "${CYAN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

ok() {
    echo -e "${GREEN}✅ $*${NC}"
}

warn() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

error() {
    echo -e "${RED}❌ ERROR: $*${NC}" >&2
}

error_exit() {
    error "$1"
    exit 1
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_functions_directory() {
    local functions_dir="$1"

    if [ ! -d "$functions_dir" ]; then
        error_exit "Functions directory not found: $functions_dir"
    fi

    # Check if directory contains at least one function
    local function_count=$(find "$functions_dir" -mindepth 1 -maxdepth 1 -type d | wc -l)
    if [ "$function_count" -eq 0 ]; then
        error_exit "No functions found in: $functions_dir"
    fi

    ok "Found $function_count function(s) to deploy"
}

check_pi_connectivity() {
    local pi_host="$1"

    log "🔌 Testing connection to $pi_host..."

    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$pi_host" "echo 'Connection OK'" >/dev/null 2>&1; then
        error_exit "Cannot connect to $pi_host. Check SSH keys and network."
    fi

    ok "SSH connection successful"
}

check_supabase_running() {
    local pi_host="$1"

    log "🔍 Checking Supabase Edge Functions container..."

    local container_status
    container_status=$(ssh "$pi_host" "docker inspect -f '{{.State.Status}}' supabase-edge-functions 2>/dev/null" || echo "not_found")

    if [ "$container_status" = "not_found" ]; then
        error_exit "Edge Functions container not found. Is Supabase deployed?"
    fi

    if [ "$container_status" != "running" ]; then
        warn "Edge Functions container status: $container_status"
        error_exit "Edge Functions container is not running"
    fi

    ok "Edge Functions container is running"
}

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

backup_existing_functions() {
    local pi_host="$1"
    local supabase_dir="$2"
    local backup_timestamp="$(date +%Y%m%d-%H%M%S)"

    log "💾 Creating backup of existing functions..."

    ssh "$pi_host" "
        if [ -d '$supabase_dir/volumes/functions' ]; then
            mkdir -p '$supabase_dir/backups/functions'
            cp -r '$supabase_dir/volumes/functions' '$supabase_dir/backups/functions/functions-$backup_timestamp'
            echo 'Backup created: $supabase_dir/backups/functions/functions-$backup_timestamp'
        else
            echo 'No existing functions to backup'
        fi
    "

    ok "Backup complete"
}

deploy_functions() {
    local functions_dir="$1"
    local pi_host="$2"
    local supabase_dir="$3"

    log "📦 Deploying Edge Functions..."

    # Get list of functions to deploy
    local functions=($(find "$functions_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

    log "📋 Functions to deploy:"
    for func in "${functions[@]}"; do
        echo "   - $func"
    done
    echo ""

    # Rsync functions to Pi (preserves symlinks, permissions)
    log "🔄 Syncing functions to Pi..."
    rsync -avz --delete \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='*.log' \
        "$functions_dir/" \
        "$pi_host:$supabase_dir/volumes/functions/"

    ok "Functions synced to Pi"

    # Set proper permissions
    log "🔐 Setting permissions..."
    ssh "$pi_host" "
        sudo chown -R 1000:1000 '$supabase_dir/volumes/functions'
        sudo chmod -R 755 '$supabase_dir/volumes/functions'
    "

    ok "Permissions set"
}

restart_edge_functions() {
    local pi_host="$1"
    local supabase_dir="$2"

    log "🔄 Restarting Edge Functions container..."

    ssh "$pi_host" "cd '$supabase_dir' && docker compose restart edge-functions"

    # Wait for container to be healthy
    log "⏳ Waiting for Edge Functions to be healthy..."

    local max_wait=60
    local elapsed=0
    local health_status=""

    while [ $elapsed -lt $max_wait ]; do
        health_status=$(ssh "$pi_host" "docker inspect -f '{{.State.Health.Status}}' supabase-edge-functions 2>/dev/null" || echo "none")

        if [ "$health_status" = "healthy" ]; then
            ok "Edge Functions container is healthy"
            return 0
        fi

        if [ $((elapsed % 10)) -eq 0 ] && [ $elapsed -gt 0 ]; then
            log "   Still waiting... ($elapsed/${max_wait}s, status: $health_status)"
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    warn "Health check timeout reached (status: $health_status)"
    warn "Container may still be starting up"
}

# =============================================================================
# TESTING FUNCTIONS
# =============================================================================

test_edge_functions() {
    local pi_host="$1"
    local functions_dir="$2"

    log "🧪 Testing deployed Edge Functions..."

    # Get list of deployed functions
    local functions=($(find "$functions_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))

    local success_count=0
    local fail_count=0

    # Get Pi IP from hostname
    local pi_ip=$(ssh "$pi_host" "hostname -I | awk '{print \$1}'")

    # Test each function
    for func in "${functions[@]}"; do
        echo ""
        log "Testing function: $func"

        # Try to call the function (expect 401 or 200, not 503)
        local response
        local http_code

        response=$(ssh "$pi_host" "curl -s -w '\n%{http_code}' http://localhost:8001/functions/v1/$func -X POST -H 'Content-Type: application/json' 2>/dev/null" || echo "error")
        http_code=$(echo "$response" | tail -1)

        if [ "$http_code" = "503" ] || [ "$http_code" = "error" ]; then
            error "   ❌ $func - Service Unavailable (HTTP $http_code)"
            ((fail_count++))
        elif [ "$http_code" = "401" ] || [ "$http_code" = "200" ]; then
            ok "   ✅ $func - Accessible (HTTP $http_code)"
            ((success_count++))
        else
            warn "   ⚠️  $func - Unexpected status (HTTP $http_code)"
            ((success_count++))
        fi
    done

    echo ""
    log "📊 Test Results:"
    echo "   ✅ Success: $success_count"
    echo "   ❌ Failed: $fail_count"

    if [ $fail_count -eq 0 ]; then
        ok "All functions deployed successfully!"
    else
        warn "Some functions failed to deploy. Check logs: docker logs supabase-edge-functions"
    fi
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

show_deployment_summary() {
    local functions_dir="$1"
    local pi_host="$2"
    local pi_ip=$(ssh "$pi_host" "hostname -I | awk '{print \$1}'")

    echo ""
    echo "======================================================================="
    echo "✅ Edge Functions Deployment Complete"
    echo "======================================================================="
    echo ""
    echo "📦 **Deployed Functions:**"

    local functions=($(find "$functions_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
    for func in "${functions[@]}"; do
        echo "   - $func"
        echo "     http://$pi_ip:8001/functions/v1/$func"
    done

    echo ""
    echo "🔧 **Management Commands:**"
    echo "   # View Edge Functions logs"
    echo "   ssh $pi_host 'docker logs supabase-edge-functions --tail 50'"
    echo ""
    echo "   # Restart Edge Functions"
    echo "   ssh $pi_host 'cd /home/pi/stacks/supabase && docker compose restart edge-functions'"
    echo ""
    echo "   # Test a function"
    echo "   curl -X POST http://$pi_ip:8001/functions/v1/your-function-name \\"
    echo "     -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"test\": \"data\"}'"
    echo ""
    echo "📚 **Documentation:**"
    echo "   - Supabase Edge Functions: https://supabase.com/docs/guides/functions"
    echo "   - Deno Runtime: https://deno.land/manual"
    echo ""
    echo "======================================================================="
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo ""
    echo "======================================================================="
    echo "🚀 Edge Functions Deployment for Supabase Pi 5"
    echo "======================================================================="
    echo ""

    # Parse arguments
    local functions_dir="${1:-}"
    local pi_host="${2:-$DEFAULT_PI_HOST}"
    local supabase_dir="${3:-$DEFAULT_SUPABASE_DIR}"

    # Validate arguments
    if [ -z "$functions_dir" ]; then
        error "Usage: $0 <functions-directory> [pi-host] [supabase-dir]"
        echo ""
        echo "Example:"
        echo "  $0 /path/to/your-app/supabase/functions"
        echo "  $0 /path/to/functions pi@192.168.1.100"
        echo ""
        exit 1
    fi

    # Convert to absolute path
    functions_dir="$(cd "$functions_dir" && pwd)"

    log "📋 Configuration:"
    echo "   Functions Directory: $functions_dir"
    echo "   Pi Host: $pi_host"
    echo "   Supabase Directory: $supabase_dir"
    echo ""

    # Validation phase
    log "=== Phase 1: Validation ==="
    validate_functions_directory "$functions_dir"
    check_pi_connectivity "$pi_host"
    check_supabase_running "$pi_host"
    echo ""

    # Backup phase
    log "=== Phase 2: Backup ==="
    backup_existing_functions "$pi_host" "$supabase_dir"
    echo ""

    # Deployment phase
    log "=== Phase 3: Deployment ==="
    deploy_functions "$functions_dir" "$pi_host" "$supabase_dir"
    echo ""

    # Restart phase
    log "=== Phase 4: Restart ==="
    restart_edge_functions "$pi_host" "$supabase_dir"
    echo ""

    # Testing phase
    log "=== Phase 5: Testing ==="
    test_edge_functions "$pi_host" "$functions_dir"
    echo ""

    # Summary
    show_deployment_summary "$functions_dir" "$pi_host"

    log "🎉 Deployment completed successfully!"
}

# Execute main function
main "$@"

exit 0
