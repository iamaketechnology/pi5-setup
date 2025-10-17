#!/bin/bash
# =============================================================================
# Supabase Schema Installation Script
# =============================================================================
# Version: 4.0.0
# Description: Install control_center schema on Supabase PostgreSQL
# Usage: bash install.sh
# =============================================================================

set -euo pipefail

# Logging functions
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PostgreSQL connection info
PI_HOST="${PI_HOST:-pi5.local}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-RGm4e181qnFue5TG9XooHo3nNW7tPXiK}"
POSTGRES_USER="postgres"
POSTGRES_DB="postgres"
POSTGRES_PORT="5432"

log_info "PI5 Control Center - Supabase Schema Installation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if psql is available
if ! command -v psql &> /dev/null; then
    log_error "psql not found. Install PostgreSQL client:"
    echo "  macOS: brew install postgresql"
    echo "  Linux: sudo apt install postgresql-client"
    exit 1
fi

# Test SSH connection to Pi
log_info "Testing SSH connection to $PI_HOST..."
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 pi@"$PI_HOST" "exit" 2>/dev/null; then
    log_error "Cannot connect to $PI_HOST via SSH"
    log_error "Make sure:"
    log_error "  1. Pi is powered on"
    log_error "  2. SSH key is configured"
    log_error "  3. Hostname is correct (try: ssh pi@$PI_HOST)"
    exit 1
fi
log_success "SSH connection OK"

# Create SSH tunnel to PostgreSQL
log_info "Creating SSH tunnel to PostgreSQL (port 5432)..."
ssh -f -N -L 15432:localhost:5432 pi@"$PI_HOST" 2>/dev/null || {
    # Tunnel might already exist, try to use it
    log_info "SSH tunnel may already exist, continuing..."
}

# Wait for tunnel to be ready
sleep 2

# Test PostgreSQL connection
log_info "Testing PostgreSQL connection..."
if ! PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p 15432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1" &>/dev/null; then
    log_error "Cannot connect to PostgreSQL"
    log_error "Check Supabase container status:"
    log_error "  ssh pi@$PI_HOST 'docker ps | grep supabase-db'"
    exit 1
fi
log_success "PostgreSQL connection OK"

# Execute SQL scripts
log_info "Executing SQL scripts..."
echo ""

execute_sql() {
    local file=$1
    local name=$2

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Executing: $name"
    if PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p 15432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$file" &>/dev/null; then
        log_success "$name executed successfully"
    else
        log_error "$name failed"
        return 1
    fi
}

# Execute in order
execute_sql "$SCRIPT_DIR/schema.sql" "schema.sql (tables, indexes, views)"
execute_sql "$SCRIPT_DIR/policies.sql" "policies.sql (RLS security)"
execute_sql "$SCRIPT_DIR/seed.sql" "seed.sql (migrate pi5)"

# Verify installation
log_info "Verifying installation..."
PI_COUNT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p 15432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT COUNT(*) FROM control_center.pis;" 2>/dev/null | xargs)

if [[ "$PI_COUNT" -ge 1 ]]; then
    log_success "Installation successful! $PI_COUNT Pi(s) configured"
else
    log_error "Installation verification failed"
    exit 1
fi

# Show migrated Pi
echo ""
log_info "Migrated Pi:"
PGPASSWORD="$POSTGRES_PASSWORD" psql -h localhost -p 15432 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
SELECT
    name,
    hostname,
    status,
    tags,
    created_at
FROM control_center.pis
ORDER BY created_at DESC
LIMIT 5;
"

echo ""
log_success "✅ Supabase schema installed successfully!"
echo ""
log_info "Next steps:"
echo "  1. Update tools/admin-panel/.env with Supabase credentials"
echo "  2. Install @supabase/supabase-js: cd tools/admin-panel && npm install @supabase/supabase-js"
echo "  3. Create lib/supabase-client.js"
echo ""

# Cleanup: Kill SSH tunnel
pkill -f "ssh.*15432:localhost:5432" 2>/dev/null || true
log_info "SSH tunnel closed"
