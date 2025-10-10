#!/usr/bin/env bash
# =============================================================================
# Edge Functions Deployment Script for Supabase Pi 5
# =============================================================================
#
# Purpose: Deploy Edge Functions from local project to self-hosted Supabase
#
# Author: Claude Code Assistant
# Version: 2.0.0 - Fat Router Support
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

check_router_exists() {
    local functions_dir="$1"

    log "🔍 Checking for Fat Router..."

    if [ -f "$functions_dir/_router/index.ts" ]; then
        ok "Fat Router found: _router/index.ts"
        return 0
    elif [ -f "$functions_dir/main/index.ts" ]; then
        warn "Found main/index.ts (legacy structure)"
        return 0
    else
        error ""
        error "❌ Fat Router NOT found!"
        error ""
        error "Self-hosted Edge Runtime requires a Fat Router pattern."
        error "Expected: $functions_dir/_router/index.ts"
        error ""
        error "The self-hosted Edge Runtime Docker container can only load ONE function."
        error "You need a router that dispatches to all your functions."
        error ""
        error "See documentation:"
        error "  - docs/edge-functions-router.md"
        error "  - docs/troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md"
        error ""
        error "Quick fix:"
        error "  1. Copy template:"
        error "     cp scripts/templates/edge-functions-router-template.ts \\"
        error "        $functions_dir/_router/index.ts"
        error ""
        error "  2. Implement your function handlers in the router"
        error "  3. Run this script again"
        error ""
        exit 1
    fi
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

    log "📦 Deploying Edge Functions with Fat Router..."

    # Determine router source
    local router_source=""
    if [ -f "$functions_dir/_router/index.ts" ]; then
        router_source="$functions_dir/_router/index.ts"
        log "   Using router: _router/index.ts"
    elif [ -f "$functions_dir/main/index.ts" ]; then
        router_source="$functions_dir/main/index.ts"
        warn "   Using legacy main/index.ts (consider migrating to _router/)"
    fi

    # Deploy router as main function
    log "🚀 Deploying Fat Router as main function..."
    ssh "$pi_host" "mkdir -p '$supabase_dir/volumes/functions/main'"
    scp "$router_source" "$pi_host:$supabase_dir/volumes/functions/main/index.ts"
    ok "Router deployed to main/index.ts"

    # Deploy other functions for reference/documentation
    local functions=($(find "$functions_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;))
    local other_funcs=()

    for func in "${functions[@]}"; do
        # Skip _router and main (already deployed)
        if [ "$func" != "_router" ] && [ "$func" != "main" ] && [ "$func" != "_shared" ]; then
            other_funcs+=("$func")
        fi
    done

    if [ ${#other_funcs[@]} -gt 0 ]; then
        log "📁 Deploying individual functions (for reference)..."
        for func in "${other_funcs[@]}"; do
            echo "   - $func"
            ssh "$pi_host" "mkdir -p '$supabase_dir/volumes/functions/$func'"
            rsync -az --delete \
                --exclude='node_modules' \
                --exclude='.git' \
                "$functions_dir/$func/" \
                "$pi_host:$supabase_dir/volumes/functions/$func/" 2>/dev/null || true
        done
        ok "Individual functions deployed"
    fi

    # Deploy _shared if exists
    if [ -d "$functions_dir/_shared" ]; then
        log "📚 Deploying shared utilities..."
        ssh "$pi_host" "mkdir -p '$supabase_dir/volumes/functions/_shared'"
        rsync -az --delete \
            "$functions_dir/_shared/" \
            "$pi_host:$supabase_dir/volumes/functions/_shared/"
        ok "Shared utilities deployed"
    fi

    # Set proper permissions
    log "🔐 Setting permissions..."
    ssh "$pi_host" "
        sudo chown -R 1000:1000 '$supabase_dir/volumes/functions'
        sudo chmod -R 755 '$supabase_dir/volumes/functions'
    "

    ok "Permissions set"
}

verify_docker_compose_config() {
    local pi_host="$1"
    local supabase_dir="$2"

    log "🔍 Verifying docker-compose configuration..."

    # Check if docker-compose points to /main
    local config_check=$(ssh "$pi_host" "grep -A 2 '\\-\\- start' '$supabase_dir/docker-compose.yml' | grep '/main' || echo 'MISSING'")

    if echo "$config_check" | grep -q "MISSING"; then
        warn "docker-compose.yml does not point to /main directory"
        log "   Fixing configuration..."

        ssh "$pi_host" "cd '$supabase_dir' && \
            sed -i.backup-\$(date +%Y%m%d-%H%M%S) \
            's|/home/deno/functions\$|/home/deno/functions/main|' docker-compose.yml"

        ok "docker-compose.yml updated to use /main"
    else
        ok "docker-compose configuration correct"
    fi
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

    log "🧪 Testing Fat Router deployment..."

    # Test router with a simple request
    local response
    local http_code
    local body

    response=$(ssh "$pi_host" "curl -s -w '\n%{http_code}' \
        'http://localhost:8001/functions/v1/test-function' \
        -X POST \
        -H 'Content-Type: application/json' \
        -d '{\"test\":\"data\"}' 2>/dev/null" || echo -e "error\n000")

    body=$(echo "$response" | head -n -1)
    http_code=$(echo "$response" | tail -1)

    echo ""
    log "Router Test Results:"
    echo "   HTTP Status: $http_code"
    echo "   Response: $body"
    echo ""

    # Check if router is working
    if echo "$body" | grep -q "Hello undefined"; then
        error "❌ Router NOT loaded - still using test function"
        error ""
        error "The Edge Functions container is returning the default test function."
        error "This means the Fat Router was not loaded correctly."
        error ""
        error "Troubleshooting:"
        error "  1. Check if main/index.ts exists on Pi:"
        error "     ssh $pi_host 'ls -la ~/stacks/supabase/volumes/functions/main/'"
        error ""
        error "  2. Check Edge Functions logs:"
        error "     ssh $pi_host 'docker logs supabase-edge-functions --tail 50'"
        error ""
        error "  3. Verify docker-compose points to /main:"
        error "     ssh $pi_host 'grep -A 2 \"-- start\" ~/stacks/supabase/docker-compose.yml'"
        error ""
        return 1
    elif echo "$body" | grep -qE '"(success|error)"'; then
        ok "✅ Router is working correctly!"
        ok "   Received structured JSON response (not 'Hello undefined!')"
        log ""
        log "   The router successfully:"
        log "   - Received the request"
        log "   - Parsed the URL"
        log "   - Dispatched to a handler"
        log "   - Returned a structured response"
        log ""
        return 0
    else
        warn "⚠️  Unexpected response from router"
        warn "   HTTP $http_code: $body"
        warn ""
        warn "   The router may be working, but returned an unexpected format."
        warn "   Check the logs to verify:"
        warn "     ssh $pi_host 'docker logs supabase-edge-functions --tail 50'"
        warn ""
        return 0
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
    check_router_exists "$functions_dir"
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

    # Configuration phase
    log "=== Phase 4: Configuration ==="
    verify_docker_compose_config "$pi_host" "$supabase_dir"
    echo ""

    # Restart phase
    log "=== Phase 5: Restart ==="
    restart_edge_functions "$pi_host" "$supabase_dir"
    echo ""

    # Testing phase
    log "=== Phase 6: Testing ==="
    test_edge_functions "$pi_host" "$functions_dir"
    echo ""

    # Summary
    show_deployment_summary "$functions_dir" "$pi_host"

    log "🎉 Deployment completed successfully!"
}

# Execute main function
main "$@"

exit 0
