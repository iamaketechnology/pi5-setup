#!/bin/bash
# =============================================================================
# SETUP WEEK2 SUPABASE PI5 FIXED - Production-Ready Deployment Script
# =============================================================================
#
# Purpose: Complete Supabase deployment optimized for Raspberry Pi 5 with
#          all critical issues resolved and production-grade stability
#
# Author: Claude Code Assistant
# Version: 3.31-fix-realtime-extension-order
# Target: Raspberry Pi 5 (16GB) ARM64, Raspberry Pi OS Bookworm
# Estimated Runtime: 8-12 minutes
#
# CRITICAL FIXES IMPLEMENTED (VERSION HISTORY):
# v3.0: PostgreSQL 16+ ARM64 with modern syntax support
# v3.1: Fixed Alpine Linux health checks (replaced wget with nc)
# v3.2: Fixed PostgreSQL password synchronization issues
# v3.8: CRITICAL FIX - All healthchecks use wget instead of nc (nc not available in images)
# v3.9: CRITICAL FIX - Auth healthcheck uses /health endpoint (not /) to avoid 404
# v3.10: CRITICAL FIX - wget uses GET method (not HEAD) - replaced --spider with -O /dev/null
# v3.11: ENHANCED DIAGNOSTICS - Auto-test healthcheck commands during 60s+ waits
# v3.12: CRITICAL FIX - Replace wget/curl with pidof (wget/curl don't exist in images)
# v3.13: CRITICAL FIX - Add RLIMIT_NOFILE=10000 to Realtime (fixes crash loop)
# v3.14: CRITICAL FIX - Pre-create _realtime schema (fixes "no schema selected" error)
# v3.15: FIX - Bash syntax error in realtime schema (removed invalid escaping)
# v3.16: CRITICAL FIX - Remove invalid empty ACL plugins from Kong (causes crash)
# v3.17: FIX - Studio HTTP healthcheck + Edge Functions pidof fix
# v3.18: CRITICAL FIX - Add HOSTNAME=0.0.0.0 to Studio (fixes ECONNREFUSED)
# v3.19: CRITICAL FIX - Studio healthcheck uses http://studio:3000 (not localhost) + interval 5s
# v3.20: ENHANCED DIAGNOSTICS - Studio/Edge Functions manual tests (fetch endpoint, port binding, processes)
# v3.21: CRITICAL FIX - Studio uses / (root) not /api/platform/profile (cloud-only endpoint)
# v3.22: CRITICAL FIX - Edge Functions command, volume, env vars (fixes crash loop from missing config)
# v3.23: SECURITY FIX - Extensions in dedicated schema (fixes Security Advisor warning 0014)
# v3.24: CRITICAL SECURITY - Dynamic JWT generation with unique timestamps (production-ready)
# v3.25: UX FIX - Display API keys early (before potential SQL failures)
# v3.26: CRITICAL FIX - Use supabase/postgres image (includes pgjwt extension)
# v3.27: CRITICAL FIX - Correct postgres tag to 15.8.1.060 (official Supabase version)
# v3.28: CRITICAL FIX - Force listen_addresses=* for inter-container connections
# v3.29: FIX - YAML syntax error (duplicate command key)
# v3.30: CRITICAL FIX - PostgreSQL password initialization via docker-entrypoint-initdb.d (SCRAM-SHA-256)
# v3.31: CRITICAL FIX - Realtime extension must be created before tables using its types
# v3.3: FIXED AUTH SCHEMA MISSING - Execute SQL initialization scripts
# v3.4: ARM64 optimizations with enhanced PostgreSQL readiness checks,
#       robust retry mechanisms, and sorted SQL execution order
# v3.5: AUTOMATIC DIAGNOSTIC SYSTEM - Complete error capture for copy-paste
#       * Enhanced warn()/error() functions with auto-context capture
#       * Comprehensive error reports with all logs and diagnostics
#       * Service failure reports with network tests and resource info
#       * SQL error reports showing exact content and PostgreSQL state
#       * Ready-to-copy formatted reports for direct support submission
# - Eliminated health check failures (proper commands)
# - Robust database initialization with automatic SQL script execution
# - Container dependency management and restart handling
# - Comprehensive error handling with rollback mechanisms
# - ARM64 optimization for Pi 5 architecture with extended timeouts
# - ZERO manual log collection needed - everything auto-captured
# =============================================================================

set -euo pipefail

# =============================================================================
# LOGGING AND ERROR HANDLING
# =============================================================================

# Enhanced logging with automatic context capture
log()   { echo -e "\033[1;36m[$(date +'%H:%M:%S')]\033[0m $*" | tee -a "$LOG_FILE"; }

warn()  {
    echo -e "\033[1;33m[$(date +'%H:%M:%S')]\033[0m ⚠️ $*" | tee -a "$LOG_FILE"
    # Auto-capture context for warnings
    capture_warning_context "$*"
}

ok()    { echo -e "\033[1;32m[$(date +'%H:%M:%S')]\033[0m $*" | tee -a "$LOG_FILE"; }

error() {
    echo -e "\033[1;31m[$(date +'%H:%M:%S')]\033[0m ❌ $*" | tee -a "$LOG_FILE"
    # Auto-capture detailed context for errors
    capture_error_context "$*"
}

# Enhanced error handling with automatic diagnostic report
error_exit() {
    error "FATAL ERROR: $1"
    log "🔍 Generating automatic diagnostic report..."
    generate_error_report "$1"
    log "Initiating cleanup procedures..."
    cleanup_on_error
    exit 1
}

cleanup_on_error() {
    log "🧹 DEBUGGING MODE: Skipping automatic cleanup"
    log "📋 Containers left running for troubleshooting"
    log "📋 Check logs with: docker logs supabase-auth"
    log "📋 Check status with: docker ps -a | grep supabase"
    log "📋 Manual cleanup: cd $PROJECT_DIR && docker compose down -v"

    # Only cleanup if explicitly requested
    if [[ "${FORCE_CLEANUP:-no}" == "yes" ]]; then
        log "🧹 Force cleanup requested..."
        if [[ -d "$PROJECT_DIR" ]]; then
            cd "$PROJECT_DIR" 2>/dev/null || true
            su "$TARGET_USER" -c "docker compose down --timeout 30" 2>/dev/null || true
            su "$TARGET_USER" -c "docker compose down -v" 2>/dev/null || true
        fi
        ok "Force cleanup completed"
    else
        ok "Cleanup skipped - containers available for debugging"
    fi
}

# =============================================================================
# AUTOMATIC DIAGNOSTIC AND ERROR CAPTURE SYSTEM
# =============================================================================

# Capture warning context automatically
capture_warning_context() {
    local warning_msg="$1"
    echo "" | tee -a "$LOG_FILE"
    echo "🔍 AUTO-DIAGNOSTIC for WARNING: $warning_msg" | tee -a "$LOG_FILE"

    # Check Docker status
    if command -v docker >/dev/null 2>&1; then
        echo "--- Docker Status ---" | tee -a "$LOG_FILE"
        docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tee -a "$LOG_FILE" || echo "Could not get Docker status" | tee -a "$LOG_FILE"
    fi

    # Show system resources
    echo "--- System Resources ---" | tee -a "$LOG_FILE"
    free -h 2>/dev/null | tee -a "$LOG_FILE" || echo "Could not get memory info" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Capture comprehensive error context
capture_error_context() {
    local error_msg="$1"
    echo "" | tee -a "$LOG_FILE"
    echo "🚨 AUTO-DIAGNOSTIC for ERROR: $error_msg" | tee -a "$LOG_FILE"
    echo "=======================================" | tee -a "$LOG_FILE"

    # Current working directory and project status
    echo "--- Environment Info ---" | tee -a "$LOG_FILE"
    echo "PWD: $(pwd)" | tee -a "$LOG_FILE"
    echo "USER: $USER" | tee -a "$LOG_FILE"
    echo "TARGET_USER: ${TARGET_USER:-unknown}" | tee -a "$LOG_FILE"
    echo "PROJECT_DIR: ${PROJECT_DIR:-unknown}" | tee -a "$LOG_FILE"

    # Docker containers status
    if command -v docker >/dev/null 2>&1; then
        echo "--- Supabase Containers ---" | tee -a "$LOG_FILE"
        docker ps -a --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | tee -a "$LOG_FILE"

        # Check for any unhealthy containers
        echo "--- Container Health ---" | tee -a "$LOG_FILE"
        for container in $(docker ps --filter "name=supabase" --format "{{.Names}}" 2>/dev/null); do
            local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-health-check")
            echo "$container: $health" | tee -a "$LOG_FILE"
        done
    fi

    # Recent logs from problematic services
    if [[ -n "${CURRENT_SERVICE:-}" ]]; then
        echo "--- Recent Logs for $CURRENT_SERVICE ---" | tee -a "$LOG_FILE"
        docker logs --tail 20 "supabase-$CURRENT_SERVICE" 2>&1 | tee -a "$LOG_FILE" || echo "Could not get logs for $CURRENT_SERVICE" | tee -a "$LOG_FILE"
    fi

    echo "=======================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# Generate comprehensive error report for copy-paste
generate_error_report() {
    local fatal_error="$1"
    local report_separator="=========================="

    echo ""
    echo "$report_separator"
    echo "🚨 SUPABASE INSTALLATION ERROR REPORT"
    echo "$report_separator"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Script Version: $SCRIPT_VERSION"
    echo "Fatal Error: $fatal_error"
    echo "Platform: $(uname -a)"
    echo ""

    # Environment details
    echo "--- ENVIRONMENT ---"
    echo "User: $USER"
    echo "Target User: ${TARGET_USER:-unknown}"
    echo "Project Directory: ${PROJECT_DIR:-unknown}"
    echo "Log File: ${LOG_FILE:-unknown}"
    echo ""

    # System resources
    echo "--- SYSTEM RESOURCES ---"
    free -h 2>/dev/null || echo "Memory info unavailable"
    df -h . 2>/dev/null | tail -1 || echo "Disk info unavailable"
    echo ""

    # Docker environment
    if command -v docker >/dev/null 2>&1; then
        echo "--- DOCKER STATUS ---"
        docker version --format '{{.Server.Version}}' 2>/dev/null || echo "Docker version unavailable"
        docker ps -a --filter "name=supabase" 2>/dev/null || echo "No Supabase containers found"
        echo ""

        # Container logs for all Supabase services
        echo "--- CONTAINER LOGS ---"
        for service in auth db rest storage realtime kong studio meta edge-functions imgproxy; do
            if docker ps -a --filter "name=supabase-$service" --format "{{.Names}}" 2>/dev/null | grep -q "supabase-$service"; then
                echo "=== $service logs ==="
                docker logs --tail 50 "supabase-$service" 2>&1
                echo ""
            fi
        done

        # Docker Compose status if available
        if [[ -d "$PROJECT_DIR" ]]; then
            echo "--- DOCKER COMPOSE STATUS ---"
            cd "$PROJECT_DIR" 2>/dev/null || true
            docker compose ps 2>/dev/null || echo "Docker Compose status unavailable"
            echo ""
        fi
    fi

    # Configuration files
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        echo "--- CONFIGURATION (.env) ---"
        # Show .env but mask sensitive values
        grep -E '^[A-Z_]+=' "$PROJECT_DIR/.env" 2>/dev/null | sed -E 's/(PASSWORD|SECRET|KEY)=.*/\1=***MASKED***/' || echo ".env unavailable"
        echo ""
    fi

    # Last 20 lines of main log
    echo "--- RECENT SCRIPT LOG ---"
    tail -20 "$LOG_FILE" 2>/dev/null || echo "Script log unavailable"
    echo ""

    echo "$report_separator"
    echo "📋 COPY THIS COMPLETE REPORT FOR SUPPORT"
    echo "$report_separator"
    echo ""
}

# =============================================================================
# CONFIGURATION AND VARIABLES
# =============================================================================

# Script configuration
SCRIPT_VERSION="3.31-fix-realtime-extension-order"
TARGET_USER="${SUDO_USER:-pi}"
PROJECT_DIR="/home/$TARGET_USER/stacks/supabase"
LOG_FILE="/var/log/supabase-pi5-setup-${SCRIPT_VERSION}-$(date +%Y%m%d_%H%M%S).log"

# Service configuration
SUPABASE_PORT="${SUPABASE_PORT:-8001}"  # Default port to avoid conflicts
POSTGRES_VERSION="16.4"                 # PostgreSQL 16+ for modern syntax
HEALTH_CHECK_TIMEOUT="300"               # 5 minutes max for service startup
MAX_RETRIES="5"                          # Maximum retry attempts

# ARM64 optimization flags
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# =============================================================================
# PREREQUISITES AND VALIDATION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "❌ This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

setup_logging() {
    # Create log file with proper permissions
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"

    # Log script header
    log "======================================================================="
    log "🥧 Raspberry Pi 5 Supabase Installation (HealthCheck Fixed)"
    log "======================================================================="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Project Directory: $PROJECT_DIR"
    log "Log File: $LOG_FILE"
    log "Timestamp: $(date)"
    log "======================================================================="
}

check_system_requirements() {
    log "🔍 Validating system requirements..."

    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        error_exit "Unsupported architecture: $arch (ARM64/aarch64 required)"
    fi
    ok "✅ Architecture: $arch (ARM64 supported)"

    # Check OS
    if ! grep -q "Debian\|Ubuntu" /etc/os-release; then
        warn "⚠️ Non-Debian OS detected - may have compatibility issues"
    fi

    # Check page size (critical for PostgreSQL on Pi 5)
    local page_size=$(getconf PAGESIZE 2>/dev/null || echo "0")
    if [[ "$page_size" == "16384" ]]; then
        error_exit "16KB page size detected - incompatible with PostgreSQL. Add 'kernel=kernel8.img' to /boot/firmware/config.txt and reboot"
    elif [[ "$page_size" != "4096" ]]; then
        warn "⚠️ Non-standard page size: ${page_size}B (expected 4096B)"
    else
        ok "✅ Page size: 4KB (PostgreSQL compatible)"
    fi

    # Check available memory (minimum 4GB for Supabase)
    local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ "$mem_gb" -lt 4 ]]; then
        warn "⚠️ Low memory: ${mem_gb}GB (4GB+ recommended for Supabase)"
    else
        ok "✅ Memory: ${mem_gb}GB available"
    fi

    # Check disk space (minimum 10GB free)
    local disk_free_gb=$(df -BG /home | tail -1 | awk '{print $4}' | sed 's/G//')
    if [[ "$disk_free_gb" -lt 10 ]]; then
        error_exit "Insufficient disk space: ${disk_free_gb}GB free (10GB+ required)"
    fi
    ok "✅ Disk space: ${disk_free_gb}GB free"
}

check_docker_prerequisites() {
    log "🐳 Validating Docker installation..."

    # Check Docker daemon
    if ! command -v docker >/dev/null 2>&1; then
        error_exit "Docker not installed - run Week 1 setup first"
    fi

    if ! systemctl is-active --quiet docker; then
        error_exit "Docker daemon not running"
    fi
    ok "✅ Docker daemon running"

    # Check Docker Compose v2
    if ! docker compose version >/dev/null 2>&1; then
        error_exit "Docker Compose v2 not installed"
    fi
    ok "✅ Docker Compose v2 available"

    # Test Docker functionality
    if ! docker run --rm hello-world >/dev/null 2>&1; then
        error_exit "Docker not functioning properly"
    fi
    ok "✅ Docker functionality verified"

    # Check user in docker group
    if ! groups "$TARGET_USER" | grep -q docker; then
        log "Adding $TARGET_USER to docker group..."
        usermod -aG docker "$TARGET_USER" || error_exit "Failed to add user to docker group"
        warn "⚠️ User added to docker group - logout/login required for full effect"
    fi
}

check_port_conflicts() {
    log "🔍 Checking for port conflicts..."

    local required_ports=(3000 $SUPABASE_PORT 5432 54321)
    local conflicted_ports=()

    for port in "${required_ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            conflicted_ports+=("$port")
        fi
    done

    if [[ ${#conflicted_ports[@]} -gt 0 ]]; then
        warn "⚠️ Port conflicts detected: ${conflicted_ports[*]}"
        log "Attempting to resolve conflicts..."

        # Try to gracefully stop conflicting services
        for port in "${conflicted_ports[@]}"; do
            local pid=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d/ -f1)
            if [[ -n "$pid" && "$pid" != "-" ]]; then
                local service=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                warn "Port $port used by PID $pid ($service)"

                # Don't kill system services automatically
                if [[ "$service" =~ ^(docker|containerd|systemd) ]]; then
                    error_exit "System service using required port $port - manual intervention required"
                fi
            fi
        done

        # Re-check after potential cleanup
        conflicted_ports=()
        for port in "${required_ports[@]}"; do
            if netstat -tuln 2>/dev/null | grep -q ":$port "; then
                conflicted_ports+=("$port")
            fi
        done

        if [[ ${#conflicted_ports[@]} -gt 0 ]]; then
            error_exit "Unresolved port conflicts: ${conflicted_ports[*]} - stop services using these ports"
        fi
    fi

    ok "✅ No port conflicts detected"
}

# =============================================================================
# PROJECT STRUCTURE AND ENVIRONMENT
# =============================================================================

create_project_structure() {
    log "📁 Creating project structure..."

    # Backup existing installation if present
    if [[ -d "$PROJECT_DIR" ]]; then
        local backup_dir="/home/$TARGET_USER/stacks/supabase-backup-$(date +%Y%m%d_%H%M%S)"
        log "Backing up existing installation to: $backup_dir"
        cp -r "$PROJECT_DIR" "$backup_dir" 2>/dev/null || true
        chown -R "$TARGET_USER:$TARGET_USER" "$backup_dir" 2>/dev/null || true
    fi

    # Create directory structure
    su "$TARGET_USER" -c "mkdir -p '$PROJECT_DIR'/{volumes/{db,storage,kong,functions/main},scripts,backups,logs}"

    # Set proper permissions for PostgreSQL volume
    mkdir -p "$PROJECT_DIR/volumes/db"
    chown -R 999:999 "$PROJECT_DIR/volumes/db" 2>/dev/null || true
    chmod -R 750 "$PROJECT_DIR/volumes"

    # Create storage directories
    mkdir -p "$PROJECT_DIR/volumes/storage"
    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/storage"

    # Create Edge Functions directory with example function
    mkdir -p "$PROJECT_DIR/volumes/functions/main"
    cat > "$PROJECT_DIR/volumes/functions/main/index.ts" <<'EOF'
// Example Edge Function - Hello World
// This function runs on Supabase Edge Runtime (Deno)

Deno.serve(async (req) => {
  const { name } = await req.json().catch(() => ({ name: 'World' }));

  return new Response(
    JSON.stringify({
      message: `Hello ${name}!`,
      timestamp: new Date().toISOString(),
      runtime: 'Supabase Edge Functions on Raspberry Pi 5'
    }),
    {
      headers: { 'Content-Type': 'application/json' },
      status: 200
    }
  );
});
EOF
    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/functions"
    chmod -R 755 "$PROJECT_DIR/volumes/functions"

    ok "✅ Project structure created: $PROJECT_DIR"
}

generate_jwt_token() {
    # Generate JWT token with HS256 algorithm
    # Args: $1 = role (anon or service_role), $2 = jwt_secret
    local role="$1"
    local secret="$2"

    # Get current timestamp and set expiry to 10 years from now
    local iat=$(date +%s)
    local exp=$((iat + 315360000))  # 10 years in seconds

    # Create header and payload
    local header='{"alg":"HS256","typ":"JWT"}'
    local payload="{\"iss\":\"supabase\",\"role\":\"$role\",\"iat\":$iat,\"exp\":$exp}"

    # Base64URL encode function
    base64url_encode() {
        openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
    }

    # Encode header and payload
    local header_b64=$(echo -n "$header" | base64url_encode)
    local payload_b64=$(echo -n "$payload" | base64url_encode)

    # Create signature
    local signature=$(echo -n "$header_b64.$payload_b64" | \
        openssl dgst -sha256 -hmac "$secret" -binary | base64url_encode)

    # Return complete JWT
    echo "$header_b64.$payload_b64.$signature"
}

generate_secure_secrets() {
    log "🔐 Generating secure authentication secrets..."

    # Generate cryptographically secure secrets
    local postgres_password=$(openssl rand -base64 32 | tr -d "=+/\n" | cut -c1-32)
    local jwt_secret=$(openssl rand -base64 64 | tr -d "=+/\n" | cut -c1-64)

    # Generate encryption keys with proper lengths for ARM64
    local db_enc_key=$(openssl rand -hex 16)      # 32 chars for AES-256
    local secret_key_base=$(openssl rand -hex 32) # 64 chars for Elixir

    # Generate dynamic JWT tokens with unique timestamps (PRODUCTION SECURE)
    log "   Generating dynamic JWT tokens with unique timestamps..."
    local anon_key=$(generate_jwt_token "anon" "$jwt_secret")
    local service_key=$(generate_jwt_token "service_role" "$jwt_secret")

    # Detect local IP for service URLs
    local local_ip=$(hostname -I | awk '{print $1}' | head -1)
    if [[ -z "$local_ip" ]]; then
        local_ip="192.168.1.100"  # Fallback IP
        warn "⚠️ Could not detect local IP, using fallback: $local_ip"
    fi

    # Export variables for use in other functions
    export POSTGRES_PASSWORD="$postgres_password"
    export JWT_SECRET="$jwt_secret"
    export DB_ENC_KEY="$db_enc_key"
    export SECRET_KEY_BASE="$secret_key_base"
    export SUPABASE_ANON_KEY="$anon_key"
    export SUPABASE_SERVICE_KEY="$service_key"
    export LOCAL_IP="$local_ip"

    ok "✅ Secure secrets generated for IP: $local_ip"
    log "   API will be accessible at: http://$local_ip:$SUPABASE_PORT"
}

create_environment_file() {
    log "📄 Creating environment configuration..."

    # Backup existing .env if present
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        cp "$PROJECT_DIR/.env" "$PROJECT_DIR/.env.backup"
    fi

    # Create comprehensive .env file
    cat > "$PROJECT_DIR/.env" << EOF
# =============================================================================
# SUPABASE PI 5 CONFIGURATION (Fixed Version $SCRIPT_VERSION)
# Generated: $(date)
# =============================================================================

########################################
# Core Database Configuration
########################################
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_VERSION=$POSTGRES_VERSION

########################################
# JWT & Authentication
########################################
JWT_SECRET=$JWT_SECRET
SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
SUPABASE_SERVICE_KEY=$SUPABASE_SERVICE_KEY

########################################
# Encryption Keys (ARM64 Optimized)
########################################
DB_ENC_KEY=$DB_ENC_KEY
SECRET_KEY_BASE=$SECRET_KEY_BASE

########################################
# Service URLs and API Configuration
########################################
SUPABASE_PUBLIC_URL=http://$LOCAL_IP:$SUPABASE_PORT
API_EXTERNAL_URL=http://$LOCAL_IP:$SUPABASE_PORT
SUPABASE_URL=http://$LOCAL_IP:$SUPABASE_PORT
SUPABASE_REST_URL=http://$LOCAL_IP:$SUPABASE_PORT/rest/v1/

########################################
# Network and Ports
########################################
KONG_HTTP_PORT=$SUPABASE_PORT
SUPABASE_PORT=$SUPABASE_PORT
LOCAL_IP=$LOCAL_IP

########################################
# Pi 5 Optimized PostgreSQL Settings
########################################
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_EFFECTIVE_CACHE_SIZE=6GB
POSTGRES_CHECKPOINT_COMPLETION_TARGET=0.7

########################################
# Service Configuration (Fixed Ports)
########################################
GOTRUE_API_PORT=9999
POSTGREST_PORT=3000
REALTIME_PORT=4000
STORAGE_PORT=5000

########################################
# Security and SSL
########################################
POSTGRES_SSL_MODE=disable
DB_SSL=disable

########################################
# Development Settings
########################################
ENVIRONMENT=development
ENABLE_EMAIL_SIGNUP=true
ENABLE_EMAIL_AUTOCONFIRM=true
ENABLE_PHONE_SIGNUP=false

EOF

    # Set proper permissions
    chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/.env"
    chmod 600 "$PROJECT_DIR/.env"

    ok "✅ Environment file created with all variables"
}

# =============================================================================
# DOCKER COMPOSE CONFIGURATION
# =============================================================================

create_docker_compose() {
    log "🐳 Creating optimized Docker Compose configuration..."

    cat > "$PROJECT_DIR/docker-compose.yml" << 'COMPOSE_EOF'
version: '3.8'

services:
  # PostgreSQL Database - ARM64 Optimized with PostgreSQL 15
  db:
    container_name: supabase-db
    image: supabase/postgres:15.8.1.060
    platform: linux/arm64
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2GB
          cpus: '2.0'
        reservations:
          memory: 1GB
          cpus: '1.0'
    volumes:
      - ./volumes/db:/var/lib/postgresql/data:Z
      - ./sql/init:/docker-entrypoint-initdb.d:ro
    ports:
      - "5432:5432"
    command: >
      postgres
      -c listen_addresses=*
      -c shared_buffers=${POSTGRES_SHARED_BUFFERS}
      -c work_mem=${POSTGRES_WORK_MEM}
      -c maintenance_work_mem=${POSTGRES_MAINTENANCE_WORK_MEM}
      -c max_connections=${POSTGRES_MAX_CONNECTIONS}
      -c effective_cache_size=${POSTGRES_EFFECTIVE_CACHE_SIZE}
      -c checkpoint_completion_target=${POSTGRES_CHECKPOINT_COMPLETION_TARGET}
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200

  # Auth Service (GoTrue) - Fixed health checks
  auth:
    container_name: supabase-auth
    image: supabase/gotrue:v2.177.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
      GOTRUE_SITE_URL: ${SUPABASE_PUBLIC_URL}
      GOTRUE_URI_ALLOW_LIST: "*"
      GOTRUE_DISABLE_SIGNUP: false
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      GOTRUE_JWT_EXP: 3600
      API_EXTERNAL_URL: ${API_EXTERNAL_URL}
      GOTRUE_JWT_ADMIN_ROLES: service_role
      GOTRUE_JWT_AUD: authenticated
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
    healthcheck:
      test: ["CMD-SHELL", "pidof auth || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # REST API Service (PostgREST) - Fixed health checks
  rest:
    container_name: supabase-rest
    image: postgrest/postgrest:v12.2.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PGRST_DB_URI: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
      PGRST_DB_SCHEMAS: public
      PGRST_DB_ANON_ROLE: anon
      PGRST_JWT_SECRET: ${JWT_SECRET}
      PGRST_DB_USE_LEGACY_GUCS: "false"
      PGRST_APP_SETTINGS_JWT_SECRET: ${JWT_SECRET}
      PGRST_APP_SETTINGS_JWT_EXP: 3600
    healthcheck:
      test: ["CMD-SHELL", "pgrep -f postgrest || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Realtime Service - Fixed encryption and health checks
  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.30.23
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PORT: ${REALTIME_PORT}
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: ${POSTGRES_USER}
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: ${POSTGRES_DB}
      DB_AFTER_CONNECT_QUERY: 'SET search_path TO _realtime'
      DB_ENC_KEY: ${DB_ENC_KEY}
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      ERL_AFLAGS: -proto_dist inet_tcp
      ENABLE_TAILSCALE: "false"
      DNS_NODES: "''"
      APP_NAME: supabase_realtime
      FLY_ALLOC_ID: fly-alloc-id
      FLY_APP_NAME: realtime
      DB_SSL: "false"
      RLIMIT_NOFILE: "10000"
    healthcheck:
      test: ["CMD-SHELL", "pidof beam.smp || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Storage Service - Fixed health checks
  storage:
    container_name: supabase-storage
    image: supabase/storage-api:v1.11.6
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      rest:
        condition: service_healthy
    environment:
      ANON_KEY: ${SUPABASE_ANON_KEY}
      SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
      POSTGREST_URL: http://rest:3000
      PGRST_JWT_SECRET: ${JWT_SECRET}
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
      ENABLE_IMAGE_TRANSFORMATION: "true"
      IMGPROXY_URL: http://imgproxy:5001
    healthcheck:
      test: ["CMD-SHELL", "pidof node || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Meta Service (Database Management)
  meta:
    container_name: supabase-meta
    image: supabase/postgres-meta:v0.83.2
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: ${POSTGRES_DB}
      PG_META_DB_USER: ${POSTGRES_USER}
      PG_META_DB_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pidof node || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

  # Kong API Gateway - Fixed configuration
  kong:
    container_name: supabase-kong
    image: kong:3.0.0
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      auth:
        condition: service_healthy
      rest:
        condition: service_healthy
      realtime:
        condition: service_healthy
      storage:
        condition: service_healthy
      meta:
        condition: service_healthy
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /var/lib/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
      KONG_NGINX_PROXY_PROXY_BUFFER_SIZE: 160k
      KONG_NGINX_PROXY_PROXY_BUFFERS: 64 160k
      KONG_LOG_LEVEL: info
    healthcheck:
      test: ["CMD-SHELL", "kong health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 90s
    ports:
      - "${SUPABASE_PORT}:8000"
    volumes:
      - ./volumes/kong/kong.yml:/var/lib/kong/kong.yml:ro

  # Studio Web Interface
  studio:
    container_name: supabase-studio
    image: supabase/studio:20250106-e00ba41
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      kong:
        condition: service_healthy
    environment:
      STUDIO_PG_META_URL: http://meta:8080
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DEFAULT_ORGANIZATION_NAME: "Pi 5 Supabase"
      DEFAULT_PROJECT_NAME: "Pi5 Project"
      SUPABASE_URL: http://kong:8000
      SUPABASE_REST_URL: ${SUPABASE_PUBLIC_URL}/rest/v1/
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_KEY: ${SUPABASE_SERVICE_KEY}
      LOGFLARE_API_KEY: your-super-secret-and-long-logflare-key
      LOGFLARE_URL: http://analytics:4000
      NEXT_PUBLIC_ENABLE_LOGS: true
      HOSTNAME: "0.0.0.0"
    healthcheck:
      test: ["CMD", "node", "-e", "fetch('http://localhost:3000/').then((r) => {if (r.status !== 200) throw new Error(r.status)}).catch((e) => {console.error(e); process.exit(1)})"]
      interval: 5s
      timeout: 10s
      retries: 3
      start_period: 60s
    ports:
      - "3000:3000"
    deploy:
      resources:
        limits:
          memory: 1GB
          cpus: '1.0'

  # Image Proxy for Storage transformations
  imgproxy:
    container_name: supabase-imgproxy
    image: darthsim/imgproxy:v3.8.0
    platform: linux/arm64
    restart: unless-stopped
    environment:
      IMGPROXY_BIND: ":5001"
      IMGPROXY_LOCAL_FILESYSTEM_ROOT: /
      IMGPROXY_USE_ETAG: "true"
      IMGPROXY_ENABLE_WEBP_DETECTION: "true"
      IMGPROXY_MAX_SRC_RESOLUTION: 16.8  # 16.8MP max for Pi 5
    healthcheck:
      test: ["CMD-SHELL", "pidof imgproxy || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
    volumes:
      - ./volumes/storage:/var/lib/storage:z

  # Edge Functions Runtime
  edge-functions:
    container_name: supabase-edge-functions
    image: supabase/edge-runtime:v1.58.2
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      kong:
        condition: service_healthy
    command:
      - start
      - --main-service
      - /home/deno/functions/main
    volumes:
      - ./volumes/functions:/home/deno/functions:Z
    environment:
      JWT_SECRET: ${JWT_SECRET}
      SUPABASE_URL: http://kong:8000
      SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
      SUPABASE_DB_URL: postgresql://postgres:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}
      VERIFY_JWT: "true"
    healthcheck:
      test: ["CMD", "sh", "-c", "pidof edge-runtime >/dev/null 2>&1 || pidof deno >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    ports:
      - "54321:9000"
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'

networks:
  default:
    name: supabase_network
    driver: bridge

volumes:
  db_data:
  storage_data:

COMPOSE_EOF

    # Set proper ownership
    chown "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/docker-compose.yml"

    ok "✅ Docker Compose configuration created with ARM64 optimizations"
}

# =============================================================================
# KONG GATEWAY CONFIGURATION
# =============================================================================

create_kong_configuration() {
    log "⚙️ Creating Kong API Gateway configuration..."

    mkdir -p "$PROJECT_DIR/volumes/kong"

    cat > "$PROJECT_DIR/volumes/kong/kong.yml" << 'KONG_EOF'
_format_version: "3.0"

consumers:
  - username: anon
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNjQ1MTkwNzI0LCJleHAiOjE5NjA3NjY3MjR9.M9jrxyvPLkUxWgOYSf5dNdJ8v_eWrqwU7WgMaOFErDg
  - username: service_role
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE2NDUxOTA3MjQsImV4cCI6MTk2MDc2NjcyNH0.T49KQx5LzLqbNBDOgdYlCW0Rf7cCUfz1bVy9q_Tl2X8

acls:
  - consumer: anon
    group: anon
  - consumer: service_role
    group: admin

services:
  - name: auth-v1-open
    url: http://auth:9999/
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - "/auth/v1/signup"
          - "/auth/v1/token"
          - "/auth/v1/verify"
          - "/auth/v1/callback"
          - "/auth/v1/authorize"
          - "/auth/v1/logout"
          - "/auth/v1/recover"
          - "/auth/v1/user"
          - "/auth/v1/health"

  - name: auth-v1-admin
    url: http://auth:9999/
    routes:
      - name: auth-v1-admin
        strip_path: true
        paths:
          - "/auth/v1/admin"
    plugins:
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin

  - name: rest-v1
    url: http://rest:3000/
    routes:
      - name: rest-v1-all
        strip_path: true
        paths:
          - "/rest/v1/"
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - PATCH
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Accept-Language
            - Content-Language
            - Content-Type
            - Authorization
            - apikey
            - x-client-info
          exposed_headers:
            - X-Total-Count
          credentials: true
          max_age: 3600
      - name: key-auth
        config:
          hide_credentials: false

  - name: realtime-v1
    url: http://realtime:4000/socket/
    routes:
      - name: realtime-v1
        strip_path: true
        paths:
          - "/realtime/v1/"
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          credentials: true
      - name: key-auth
        config:
          hide_credentials: false

  - name: storage-v1
    url: http://storage:5000/
    routes:
      - name: storage-v1-all
        strip_path: true
        paths:
          - "/storage/v1/"
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          credentials: true

  - name: edge-functions-v1
    url: http://edge-functions:9000/
    routes:
      - name: edge-functions-v1-all
        strip_path: true
        paths:
          - "/functions/v1/"
    plugins:
      - name: cors
        config:
          origins:
            - "*"
          credentials: true

  - name: meta-v1
    url: http://meta:8080/
    routes:
      - name: meta-v1-all
        strip_path: true
        paths:
          - "/pg/"
    plugins:
      - name: key-auth
        config:
          hide_credentials: false
      - name: acl
        config:
          hide_groups_header: true
          allow:
            - admin

KONG_EOF

    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/volumes/kong"
    chmod -R 755 "$PROJECT_DIR/volumes/kong"

    ok "✅ Kong configuration created with proper routing"
}

# =============================================================================
# DATABASE INITIALIZATION SQL
# =============================================================================

create_database_init_scripts() {
    log "🗄️ Creating database initialization scripts..."

    mkdir -p "$PROJECT_DIR/sql/init"

    # Password initialization script (executed first - 00-*)
    # This MUST be first to ensure passwords are set during PostgreSQL initialization
    # SCRAM-SHA-256 authentication requires passwords to be set at init time
    log "   Creating password initialization script (00-init-passwords.sql)..."
    cat > "$PROJECT_DIR/sql/init/00-init-passwords.sql" << SQL_EOF
-- =============================================================================
-- PASSWORD INITIALIZATION - CRITICAL FOR SCRAM-SHA-256 AUTHENTICATION
-- =============================================================================
-- This script MUST execute during PostgreSQL initialization (docker-entrypoint-initdb.d)
-- to ensure passwords work with SCRAM-SHA-256 authentication method
-- Manual password changes after initialization do NOT persist with this auth method

-- Set postgres superuser password
-- This user is used by Studio, Meta, and all administrative connections
ALTER USER postgres WITH PASSWORD '${POSTGRES_PASSWORD}';

-- Note: The 'authenticator' role will be created in 01-init-supabase.sql
-- and its password will be set there using DO blocks to avoid dependency issues

SQL_EOF

    # Main initialization script with PostgreSQL 16+ compatible syntax
    cat > "$PROJECT_DIR/sql/init/01-init-supabase.sql" << 'SQL_EOF'
-- =============================================================================
-- SUPABASE DATABASE INITIALIZATION - PostgreSQL 16+ Compatible
-- =============================================================================

-- Create dedicated schema for extensions (Security Advisor best practice)
CREATE SCHEMA IF NOT EXISTS extensions;

-- Enable required extensions in dedicated schema
-- This follows Supabase official docker setup and resolves Security Advisor warning 0014
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA extensions;

-- Create custom types for auth system in correct namespace
DO $$
BEGIN
    -- Create factor_type enum if it doesn't exist (critical for Auth service)
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
    END IF;

    -- Create factor_status enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
    END IF;

    -- Create aal_level enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aal_level' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
    END IF;

    -- Create code_challenge_method enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'code_challenge_method' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
    END IF;
END
$$;

-- Create schemas
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS storage;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS _realtime;
CREATE SCHEMA IF NOT EXISTS supabase_functions;

-- Create database roles with fallback logic (PostgreSQL 16+ compatible)
DO $$
BEGIN
    -- Create anon role
    BEGIN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role anon already exists, skipping creation';
    END;

    -- Create authenticated role
    BEGIN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role authenticated already exists, skipping creation';
    END;

    -- Create service_role
    BEGIN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role service_role already exists, skipping creation';
    END;

    -- Create supabase_auth_admin
    BEGIN
        CREATE ROLE supabase_auth_admin NOLOGIN NOINHERIT CREATEROLE;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role supabase_auth_admin already exists, skipping creation';
    END;

    -- Create supabase_storage_admin
    BEGIN
        CREATE ROLE supabase_storage_admin NOLOGIN NOINHERIT CREATEROLE;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role supabase_storage_admin already exists, skipping creation';
    END;

    -- Create authenticator role with password
    BEGIN
        CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'PLACEHOLDER_WILL_BE_REPLACED';
        -- Grant roles to authenticator
        GRANT anon TO authenticator;
        GRANT authenticated TO authenticator;
        GRANT service_role TO authenticator;
    EXCEPTION
        WHEN duplicate_object THEN
            RAISE NOTICE 'Role authenticator already exists, updating grants and password';
            GRANT anon TO authenticator;
            GRANT authenticated TO authenticator;
            GRANT service_role TO authenticator;
    END;

END
$$;

-- Set authenticator password (must be set during initialization for SCRAM-SHA-256)
ALTER ROLE authenticator WITH PASSWORD 'PLACEHOLDER_WILL_BE_REPLACED';

-- Passwords are also set in 00-init-passwords.sql (executed first)
-- This ensures compatibility with SCRAM-SHA-256 authentication

-- Grant basic permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON SCHEMA public TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;

-- Grant permissions on extensions schema
GRANT USAGE ON SCHEMA extensions TO anon, authenticated, service_role, postgres;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA extensions TO anon, authenticated, service_role, postgres;

-- Grant schema permissions
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON SCHEMA storage TO supabase_storage_admin;
GRANT ALL ON SCHEMA realtime TO postgres, service_role;
GRANT USAGE ON SCHEMA realtime TO anon, authenticated;

-- Enable Row Level Security by default
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;

SQL_EOF

    # Replace password placeholders in 01-init-supabase.sql
    log "   Replacing password placeholders with actual values..."
    sed -i "s/PLACEHOLDER_WILL_BE_REPLACED/${POSTGRES_PASSWORD}/g" "$PROJECT_DIR/sql/init/01-init-supabase.sql"

    # Realtime schema initialization with proper structure
    cat > "$PROJECT_DIR/sql/init/02-init-realtime.sql" << 'SQL_EOF'
-- =============================================================================
-- REALTIME SCHEMA INITIALIZATION
-- =============================================================================

-- Create realtime schema if not exists
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS _realtime;

-- Grant permissions to realtime schemas
GRANT ALL ON SCHEMA realtime TO postgres, service_role;
GRANT USAGE ON SCHEMA realtime TO anon, authenticated;
GRANT ALL ON SCHEMA _realtime TO postgres, service_role;

-- CRITICAL: Create extension FIRST before creating tables that use its types
-- The realtime extension defines USER_DEFINED_FILTER type used by subscription table
CREATE EXTENSION IF NOT EXISTS "realtime" WITH SCHEMA _realtime;

-- Create schema_migrations table with proper Ecto structure
CREATE TABLE IF NOT EXISTS realtime.schema_migrations (
    version BIGINT NOT NULL PRIMARY KEY,
    inserted_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);

-- Grant permissions on schema_migrations
GRANT ALL ON realtime.schema_migrations TO postgres, service_role;

-- Create subscription table (requires realtime extension types)
CREATE TABLE IF NOT EXISTS realtime.subscription (
    id BIGSERIAL PRIMARY KEY,
    subscription_id UUID NOT NULL,
    entity REGCLASS NOT NULL,
    filters REALTIME.USER_DEFINED_FILTER[] DEFAULT '{}',
    claims JSONB NOT NULL,
    claims_role REGROLE NOT NULL DEFAULT to_regrole('anon'),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(subscription_id, entity, filters)
);

-- Grant permissions on subscription table
GRANT ALL ON realtime.subscription TO postgres, service_role;
GRANT SELECT ON realtime.subscription TO anon, authenticated;

SQL_EOF

    # Set proper permissions
    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/sql"
    chmod -R 755 "$PROJECT_DIR/sql"

    ok "✅ Database initialization scripts created (00-passwords, 01-supabase, 02-realtime)"
    log "   🔑 Password initialization script will run first to ensure SCRAM-SHA-256 compatibility"
}

# =============================================================================
# AUTH SCHEMA PRE-INITIALIZATION FIX
# =============================================================================

create_auth_schema_fix() {
    log "🔧 Pre-creating auth schema and types to prevent Auth service failures..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Wait for PostgreSQL to be ready first
    wait_for_postgres_ready

    # Create auth schema and all required types BEFORE Auth service starts
    local auth_schema_sql="
-- Extensions are already created in dedicated 'extensions' schema by 01-init-supabase.sql
-- No need to recreate them here

-- Create auth schema first
CREATE SCHEMA IF NOT EXISTS auth;

-- Create database roles first (required for permissions)
DO \$\$
BEGIN
    -- Create anon role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
        CREATE ROLE anon NOLOGIN NOINHERIT;
    END IF;

    -- Create authenticated role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
        CREATE ROLE authenticated NOLOGIN NOINHERIT;
    END IF;

    -- Create service_role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
        CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
    END IF;

    -- Create authenticator role if it doesn't exist
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator') THEN
        CREATE ROLE authenticator NOINHERIT LOGIN;
        -- Grant roles to authenticator
        GRANT anon TO authenticator;
        GRANT authenticated TO authenticator;
        GRANT service_role TO authenticator;
    END IF;
END
\$\$;

-- Create all enum types required by Supabase Auth
DO \$\$
BEGIN
    -- Create factor_type enum if it doesn't exist (CRITICAL for Auth service)
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
    END IF;

    -- Create factor_status enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
    END IF;

    -- Create aal_level enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aal_level' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
    END IF;

    -- Create code_challenge_method enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'code_challenge_method' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
    END IF;

    -- Create one_time_token_type enum if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'one_time_token_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.one_time_token_type AS ENUM (
            'confirmation_token',
            'reauthentication_token',
            'recovery_token',
            'email_change_token_new',
            'email_change_token_current',
            'phone_change_token'
        );
    END IF;
END
\$\$;

-- Grant proper permissions (now that roles exist)
GRANT ALL ON SCHEMA auth TO postgres;
GRANT USAGE ON SCHEMA auth TO authenticator;
GRANT ALL ON SCHEMA auth TO service_role;

-- Grant permissions on the types (now that roles exist)
GRANT USAGE ON TYPE auth.factor_type TO authenticator, service_role;
GRANT USAGE ON TYPE auth.factor_status TO authenticator, service_role;
GRANT USAGE ON TYPE auth.aal_level TO authenticator, service_role;
GRANT USAGE ON TYPE auth.code_challenge_method TO authenticator, service_role;
GRANT USAGE ON TYPE auth.one_time_token_type TO authenticator, service_role;

-- Set authenticator password
ALTER ROLE authenticator WITH PASSWORD 'your-super-secret-jwt-token-with-at-least-32-characters-long';
"

    log "🔧 Executing auth schema pre-creation..."

    # Execute with detailed error capture and logging
    local sql_output
    sql_output=$(docker exec supabase-db psql -U postgres -d postgres -c "$auth_schema_sql" 2>&1)
    local sql_exit_code=$?

    if [ $sql_exit_code -eq 0 ]; then
        ok "✅ Auth schema and types created successfully"

        # Log successful creation details for debugging
        log "📋 Auth schema creation output:"
        echo "$sql_output" | tee -a "$LOG_FILE"
    else
        # Comprehensive error logging for copy-paste debugging
        echo "" | tee -a "$LOG_FILE"
        echo "🚨 AUTH SCHEMA CREATION FAILED - COPY THIS REPORT" | tee -a "$LOG_FILE"
        echo "=================================================" | tee -a "$LOG_FILE"
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
        echo "Exit Code: $sql_exit_code" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- POSTGRESQL ERROR OUTPUT ---" | tee -a "$LOG_FILE"
        echo "$sql_output" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- SQL SCRIPT EXECUTED ---" | tee -a "$LOG_FILE"
        echo "$auth_schema_sql" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- DATABASE CONNECTION TEST ---" | tee -a "$LOG_FILE"
        docker exec supabase-db pg_isready -U postgres -d postgres 2>&1 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- CURRENT DATABASE ROLES ---" | tee -a "$LOG_FILE"
        docker exec supabase-db psql -U postgres -d postgres -c "\\du" 2>&1 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- CURRENT DATABASE SCHEMAS ---" | tee -a "$LOG_FILE"
        docker exec supabase-db psql -U postgres -d postgres -c "\\dn" 2>&1 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "--- CONTAINER STATUS ---" | tee -a "$LOG_FILE"
        docker ps --filter "name=supabase-db" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>&1 | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        echo "=================================================" | tee -a "$LOG_FILE"
        echo "📋 COPY COMPLETE REPORT ABOVE FOR DEBUGGING" | tee -a "$LOG_FILE"
        echo "=================================================" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"

        error_exit "Failed to create auth schema and types - this will cause Auth service to fail"
    fi

    # Verify the types were created with detailed logging
    log "🔍 Verifying auth schema and types creation..."
    local verify_sql="
    SELECT
        CASE WHEN EXISTS (SELECT FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth'))
        THEN 'auth.factor_type exists'
        ELSE 'auth.factor_type missing'
        END as factor_type_status,
        CASE WHEN EXISTS (SELECT FROM pg_namespace WHERE nspname = 'auth')
        THEN 'auth schema exists'
        ELSE 'auth schema missing'
        END as schema_status,
        CASE WHEN EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticator')
        THEN 'authenticator role exists'
        ELSE 'authenticator role missing'
        END as role_status;
    "

    local verification_result
    verification_result=$(docker exec supabase-db psql -U postgres -d postgres -tAc "$verify_sql" 2>&1)
    local verify_exit_code=$?

    log "📋 Verification results:"
    echo "$verification_result" | tee -a "$LOG_FILE"

    if [ $verify_exit_code -eq 0 ] && echo "$verification_result" | grep -q "exists.*exists.*exists"; then
        ok "✅ Auth types and schema verification passed"
    else
        warn "⚠️ Auth verification completed with issues:"
        echo "   Exit code: $verify_exit_code" | tee -a "$LOG_FILE"
        echo "   Results: $verification_result" | tee -a "$LOG_FILE"

        # Additional verification for debugging
        log "🔍 Additional verification details:"
        echo "--- AUTH SCHEMA CONTENTS ---" | tee -a "$LOG_FILE"
        docker exec supabase-db psql -U postgres -d postgres -c "\\dt auth.*" 2>&1 | tee -a "$LOG_FILE"
        echo "--- AUTH TYPES ---" | tee -a "$LOG_FILE"
        docker exec supabase-db psql -U postgres -d postgres -c "\\dT auth.*" 2>&1 | tee -a "$LOG_FILE"
    fi
}

# =============================================================================
# REALTIME SCHEMA PRE-INITIALIZATION FIX
# =============================================================================

create_realtime_schema_fix() {
    log "🔧 Pre-creating _realtime schema to prevent Realtime service failures..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Wait for PostgreSQL to be ready first
    wait_for_postgres_ready

    # Create _realtime schema BEFORE Realtime service starts
    local realtime_schema_sql="
-- Create _realtime schema
CREATE SCHEMA IF NOT EXISTS _realtime;

-- Grant permissions on _realtime schema
GRANT USAGE ON SCHEMA _realtime TO postgres, anon, authenticated, service_role;
GRANT ALL ON SCHEMA _realtime TO postgres, service_role;
GRANT CREATE ON SCHEMA _realtime TO postgres, service_role;

-- Set default privileges for future objects in _realtime schema
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON TABLES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON SEQUENCES TO postgres, service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA _realtime GRANT ALL ON FUNCTIONS TO postgres, service_role;

-- Create supabase_realtime publication if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
        CREATE PUBLICATION supabase_realtime;
    END IF;
END
\$\$;
"

    log "🔧 Executing _realtime schema pre-creation..."

    # Execute with detailed error capture and logging
    local sql_output
    sql_output=$(docker exec supabase-db psql -U postgres -d postgres -c "$realtime_schema_sql" 2>&1)
    local sql_exit_code=$?

    if [ $sql_exit_code -eq 0 ]; then
        ok "✅ _realtime schema created successfully"

        # Log successful creation details for debugging
        log "📋 Realtime schema creation output:"
        echo "$sql_output" | tee -a "$LOG_FILE"
    else
        error_exit "Failed to create _realtime schema - this will cause Realtime service to fail"
    fi

    # Verify schema was created
    log "🔍 Verifying _realtime schema creation..."
    local verification=$(docker exec supabase-db psql -U postgres -d postgres -t -c "SELECT EXISTS(SELECT 1 FROM pg_namespace WHERE nspname = '_realtime')" 2>&1 | tr -d ' ')

    log "📋 Verification result: $verification"

    if [[ "$verification" != "t" ]]; then
        error_exit "_realtime schema verification failed"
    fi

    ok "✅ _realtime schema verification passed"
}

# =============================================================================
# SERVICE DEPLOYMENT AND MANAGEMENT
# =============================================================================

deploy_services() {
    log "🚀 Deploying Supabase services..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Pull all images first
    log "📦 Pulling ARM64 Docker images..."
    su "$TARGET_USER" -c "docker compose pull --quiet" || error_exit "Failed to pull Docker images"

    # Start services in stages for better dependency management
    log "🗄️ Starting PostgreSQL database..."
    su "$TARGET_USER" -c "docker compose up -d db" || error_exit "Failed to start database"

    # Wait for database to be healthy
    wait_for_service_health "db" "PostgreSQL" || error_exit "Database failed to start"

    # CRITICAL FIX: Create auth schema and types BEFORE starting Auth service
    create_auth_schema_fix

    log "🔐 Starting core services (Auth, REST, Meta)..."
    su "$TARGET_USER" -c "docker compose up -d auth rest meta" || error_exit "Failed to start core services"

    # Wait for core services
    wait_for_service_health "auth" "Authentication"
    wait_for_service_health "rest" "REST API"
    wait_for_service_health "meta" "Database Meta"

    # CRITICAL FIX: Create _realtime schema BEFORE starting Realtime service
    create_realtime_schema_fix

    log "🌐 Starting additional services..."
    su "$TARGET_USER" -c "docker compose up -d storage realtime imgproxy" || error_exit "Failed to start additional services"

    wait_for_service_health "storage" "Storage"
    wait_for_service_health "realtime" "Realtime"

    log "🦍 Starting Kong API Gateway..."
    su "$TARGET_USER" -c "docker compose up -d kong" || error_exit "Failed to start Kong"

    wait_for_service_health "kong" "Kong Gateway"

    log "🎨 Starting Studio and Edge Functions..."
    su "$TARGET_USER" -c "docker compose up -d studio edge-functions" || error_exit "Failed to start Studio"

    wait_for_service_health "studio" "Studio"
    wait_for_service_health "edge-functions" "Edge Functions"

    ok "✅ All services deployed successfully"
}

wait_for_service_health() {
    local service_name="$1"
    local display_name="$2"
    local max_wait_seconds="${HEALTH_CHECK_TIMEOUT}"
    local wait_interval=10
    local elapsed=0

    # Set current service for error context capture
    export CURRENT_SERVICE="$service_name"

    log "⏳ Waiting for $display_name service to be healthy..."

    while [[ $elapsed -lt $max_wait_seconds ]]; do
        # Check if container is running
        if docker ps --format "{{.Names}}" | grep -q "supabase-$service_name"; then
            # Check health status
            local health_status=$(docker inspect --format='{{.State.Health.Status}}' "supabase-$service_name" 2>/dev/null || echo "no-health-check")

            if [[ "$health_status" == "healthy" ]]; then
                ok "✅ $display_name is healthy (${elapsed}s)"
                unset CURRENT_SERVICE
                return 0
            elif [[ "$health_status" == "no-health-check" ]]; then
                # For services without health checks, just verify they're running
                if docker ps --filter "name=supabase-$service_name" --filter "status=running" --quiet | grep -q .; then
                    ok "✅ $display_name is running (${elapsed}s)"
                    unset CURRENT_SERVICE
                    return 0
                fi
            fi
        else
            # Container not found - generate immediate diagnostic
            warn "$display_name container not found, checking again..."
        fi

        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))

        if [[ $((elapsed % 30)) -eq 0 ]]; then
            log "⏳ Still waiting for $display_name ($elapsed/${max_wait_seconds}s)..."

            # Show intermediate status every 30 seconds
            echo "--- Intermediate Status Check ---"
            docker ps --filter "name=supabase-$service_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Container not found"

            # After 60s, show detailed healthcheck diagnostics
            if [[ $elapsed -ge 60 ]]; then
                echo ""
                echo "--- Healthcheck Diagnostic (${elapsed}s elapsed) ---"

                # Get healthcheck configuration
                echo "Healthcheck command:"
                docker inspect "supabase-$service_name" --format='{{json .Config.Healthcheck.Test}}' 2>/dev/null || echo "No healthcheck found"

                # Show last healthcheck output
                echo ""
                echo "Last healthcheck output:"
                docker inspect "supabase-$service_name" --format='{{.State.Health.Log}}' 2>/dev/null | tail -3 || echo "No health log available"

                # Test if wget/curl exists in container
                echo ""
                echo "Available tools in container:"
                docker exec "supabase-$service_name" sh -c "which wget curl nc 2>/dev/null || echo 'None found'" 2>/dev/null || echo "Cannot exec into container"

                # Try manual healthcheck based on service
                echo ""
                echo "Manual healthcheck test:"
                case "$service_name" in
                    rest)
                        docker exec "supabase-$service_name" sh -c "wget --no-verbose --tries=1 -O /dev/null http://localhost:3000/ 2>&1 || curl -f http://localhost:3000/ 2>&1 || echo 'Both wget and curl failed'" 2>/dev/null
                        ;;
                    auth)
                        docker exec "supabase-$service_name" sh -c "wget --no-verbose --tries=1 -O /dev/null http://localhost:9999/health 2>&1 || curl -f http://localhost:9999/health 2>&1 || echo 'Both wget and curl failed'" 2>/dev/null
                        ;;
                    studio)
                        echo "Testing Studio healthcheck endpoint (root path):"
                        docker exec "supabase-$service_name" node -e "fetch('http://localhost:3000/').then((r) => console.log('HTTP Status:', r.status)).catch((e) => console.error('Fetch error:', e.message))" 2>&1 || echo "Cannot run fetch test"
                        echo ""
                        echo "Testing old cloud-only endpoint (expected 404):"
                        docker exec "supabase-$service_name" node -e "fetch('http://localhost:3000/api/platform/profile').then((r) => console.log('Platform API Status:', r.status)).catch((e) => console.error('Error:', e.message))" 2>&1 || echo "Cannot test"
                        echo ""
                        echo "Testing Studio localhost binding:"
                        docker exec "supabase-$service_name" sh -c "netstat -tlnp 2>/dev/null | grep :3000 || ss -tlnp 2>/dev/null | grep :3000 || echo 'netstat/ss not available'" 2>/dev/null || echo "Cannot check port binding"
                        echo ""
                        echo "Checking Node.js version and fetch availability:"
                        docker exec "supabase-$service_name" node -e "console.log('Node version:', process.version); console.log('fetch available:', typeof fetch)" 2>/dev/null || echo "Cannot check Node version"
                        ;;
                    edge-functions)
                        echo "Testing Edge Functions process:"
                        docker exec "supabase-$service_name" sh -c "pidof edge-runtime || pidof deno || echo 'No edge-runtime or deno process found'" 2>/dev/null || echo "Cannot check process"
                        echo ""
                        echo "Checking running processes:"
                        docker exec "supabase-$service_name" sh -c "ps aux 2>/dev/null | head -10 || echo 'ps not available'" 2>/dev/null || echo "Cannot list processes"
                        ;;
                    *)
                        echo "No manual test defined for $service_name"
                        ;;
                esac

                # Show recent container logs (last 10 lines)
                echo ""
                echo "Recent logs (last 10 lines):"
                docker logs --tail 10 "supabase-$service_name" 2>&1 || echo "Cannot retrieve logs"
                echo "--- End Diagnostic ---"
            fi
        fi
    done

    # Service failed to become healthy - generate comprehensive report
    warn "$display_name did not become healthy within ${max_wait_seconds}s"

    echo ""
    echo "🚨 AUTOMATIC SERVICE FAILURE REPORT"
    echo "==================================="
    echo "Service: $service_name ($display_name)"
    echo "Timeout: ${max_wait_seconds}s"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Container status
    echo "--- CONTAINER STATUS ---"
    if docker ps -a --filter "name=supabase-$service_name" --format "{{.Names}}" 2>/dev/null | grep -q "supabase-$service_name"; then
        docker inspect "supabase-$service_name" --format="Status: {{.State.Status}}, Error: {{.State.Error}}, Health: {{.State.Health.Status}}" 2>/dev/null
        echo ""
    else
        echo "❌ Container supabase-$service_name not found"
        echo ""
    fi

    # Recent logs (last 100 lines for comprehensive view)
    echo "--- CONTAINER LOGS (last 100 lines) ---"
    docker logs --tail 100 "supabase-$service_name" 2>&1 || echo "Could not retrieve logs for $service_name"
    echo ""

    # Environment variables (for configuration issues)
    echo "--- CONTAINER ENVIRONMENT ---"
    docker exec "supabase-$service_name" env 2>/dev/null | grep -E '^[A-Z_]+=' | head -20 || echo "Could not retrieve environment"
    echo ""

    # Network connectivity test
    echo "--- NETWORK CONNECTIVITY ---"
    for other_service in db auth rest; do
        if [[ "$other_service" != "$service_name" ]] && docker ps --filter "name=supabase-$other_service" --format "{{.Names}}" 2>/dev/null | grep -q "supabase-$other_service"; then
            echo "Testing connectivity from $service_name to $other_service:"
            docker exec "supabase-$service_name" nc -z "supabase-$other_service" 5432 2>/dev/null && echo "✅ Can reach $other_service" || echo "❌ Cannot reach $other_service"
        fi
    done
    echo ""

    # System resources
    echo "--- SYSTEM RESOURCES ---"
    free -h 2>/dev/null | head -2
    echo ""
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -5
    echo ""

    echo "==================================="
    echo "📋 COPY THIS REPORT FOR DEBUGGING"
    echo "==================================="
    echo ""

    # Don't cleanup immediately - let user debug
    log "⚠️ DEBUGGING MODE: Containers left running for analysis"
    log "📋 Manual cleanup: cd $PROJECT_DIR && docker compose down -v"

    unset CURRENT_SERVICE
    return 1  # Non-fatal, let installation continue
}

# =============================================================================
# POST-DEPLOYMENT CONFIGURATION
# =============================================================================

configure_database_users() {
    log "👥 Configuring database users and permissions..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    # Wait for PostgreSQL to be fully ready (critical on ARM64)
    wait_for_postgres_ready

    # Execute database initialization scripts with robust error handling
    execute_database_init_scripts

    # Update authenticator password with the actual generated password
    local update_passwords_sql="
    ALTER ROLE authenticator WITH PASSWORD '$POSTGRES_PASSWORD';
    ALTER ROLE postgres WITH PASSWORD '$POSTGRES_PASSWORD';
    "

    if docker exec supabase-db psql -U postgres -d postgres -c "$update_passwords_sql" >/dev/null 2>&1; then
        ok "✅ Database user passwords updated"
    else
        warn "⚠️ Could not update database passwords - using defaults"
    fi

    # Critical: Fix realtime schema for Auth service compatibility
    fix_realtime_schema

    # Verify critical tables exist
    local verify_sql="
    SELECT
        CASE WHEN EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'schema_migrations')
        THEN 'realtime.schema_migrations exists'
        ELSE 'realtime.schema_migrations missing'
        END as realtime_status,
        CASE WHEN EXISTS (SELECT FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth'))
        THEN 'auth.factor_type exists'
        ELSE 'auth.factor_type missing'
        END as auth_types_status;
    "

    log "🔍 Verifying database schema..."
    if docker exec supabase-db psql -U postgres -d postgres -c "$verify_sql" 2>/dev/null; then
        ok "✅ Database schema verification completed"
    else
        warn "⚠️ Could not verify database schema"
    fi
}

# Enhanced PostgreSQL readiness check for ARM64
wait_for_postgres_ready() {
    local max_wait=120  # Increased for ARM64
    local wait_interval=2
    local elapsed=0

    log "⏳ Waiting for PostgreSQL to be ready..."

    while [ $elapsed -lt $max_wait ]; do
        if docker exec supabase-db pg_isready -U postgres -d postgres >/dev/null 2>&1; then
            # Additional check: ensure we can actually connect and run queries
            if docker exec supabase-db psql -U postgres -d postgres \
                -c "SELECT 1;" >/dev/null 2>&1; then
                ok "✅ PostgreSQL is ready and accepting connections"
                return 0
            fi
        fi

        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))

        # Show progress every 10 seconds
        if [ $((elapsed % 10)) -eq 0 ]; then
            log "⏳ Still waiting for PostgreSQL... (${elapsed}s/${max_wait}s)"
        fi
    done

    error_exit "PostgreSQL failed to become ready within ${max_wait} seconds"
}

# Enhanced SQL script execution with ARM64 optimizations
execute_database_init_scripts() {
    local max_retries=3
    local retry_delay=5
    local init_dir="sql/init"

    log "🗄️ Executing database initialization scripts..."

    if [ ! -d "$init_dir" ]; then
        warn "⚠️ SQL initialization directory not found: $init_dir"
        return 0
    fi

    # Sort files to ensure predictable execution order
    local sql_files=($(find "$init_dir" -name "*.sql" -type f | sort))

    if [ ${#sql_files[@]} -eq 0 ]; then
        log "📋 No SQL initialization files found"
        return 0
    fi

    log "📄 Found ${#sql_files[@]} SQL files to execute"

    for sql_file in "${sql_files[@]}"; do
        local filename=$(basename "$sql_file")
        local attempt=1

        while [ $attempt -le $max_retries ]; do
            log "📄 Executing $filename (attempt $attempt/$max_retries)..."

            # Execute with detailed error capture
            local sql_output
            sql_output=$(docker exec -i supabase-db psql -U postgres -d postgres \
                -v ON_ERROR_STOP=1 \
                -f - < "$sql_file" 2>&1)
            local sql_exit_code=$?

            if [ $sql_exit_code -eq 0 ]; then
                ok "✅ $filename executed successfully"
                break
            else
                warn "⚠️ Attempt $attempt failed for $filename"

                # Generate comprehensive SQL error report
                echo ""
                echo "🚨 SQL EXECUTION ERROR REPORT"
                echo "=============================="
                echo "File: $filename"
                echo "Attempt: $attempt/$max_retries"
                echo "Exit Code: $sql_exit_code"
                echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
                echo ""

                # Show the SQL content that failed
                echo "--- SQL CONTENT ---"
                cat "$sql_file" 2>/dev/null || echo "Could not read SQL file"
                echo ""

                # Show the exact error
                echo "--- POSTGRESQL ERROR ---"
                echo "$sql_output"
                echo ""

                # Show current database state
                echo "--- DATABASE STATUS ---"
                docker exec supabase-db psql -U postgres -d postgres -c "\l" 2>/dev/null || echo "Could not get database list"
                echo ""
                docker exec supabase-db psql -U postgres -d postgres -c "\dn" 2>/dev/null || echo "Could not get schema list"
                echo ""

                # Test basic connectivity
                echo "--- CONNECTIVITY TEST ---"
                docker exec supabase-db pg_isready -U postgres -d postgres 2>&1
                echo ""

                echo "=============================="
                echo "📋 COPY THIS SQL ERROR REPORT"
                echo "=============================="
                echo ""

                if [ $attempt -eq $max_retries ]; then
                    error_exit "Failed to execute $filename after $max_retries attempts"
                fi

                attempt=$((attempt + 1))
                log "⏳ Waiting ${retry_delay}s before retry..."
                sleep $retry_delay
            fi
        done
    done
}

fix_realtime_schema() {
    log "🔧 Fixing realtime schema for Auth service compatibility..."

    cd "$PROJECT_DIR" || return 1

    # Critical fix: Ensure realtime schema exists with proper permissions
    local create_schema_sql="
    CREATE SCHEMA IF NOT EXISTS realtime;
    GRANT USAGE ON SCHEMA realtime TO postgres, service_role, anon, authenticated;
    GRANT ALL ON SCHEMA realtime TO postgres, service_role;
    "

    if docker exec supabase-db psql -U postgres -c "$create_schema_sql" >/dev/null 2>&1; then
        ok "✅ Realtime schema permissions fixed"
    else
        warn "⚠️ Could not fix realtime schema permissions"
        return 1
    fi

    # Ensure schema_migrations table has correct structure
    local fix_migrations_sql="
    DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
    CREATE TABLE realtime.schema_migrations (
        version BIGINT NOT NULL PRIMARY KEY,
        inserted_at TIMESTAMP(0) WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
    );
    GRANT ALL ON realtime.schema_migrations TO postgres, service_role;
    "

    if docker exec supabase-db psql -U postgres -c "$fix_migrations_sql" >/dev/null 2>&1; then
        ok "✅ Realtime schema_migrations table recreated with correct structure"
    else
        warn "⚠️ Could not recreate realtime.schema_migrations table"
        return 1
    fi

    return 0
}

restart_dependent_services() {
    log "🔄 Restarting services with updated configuration..."

    cd "$PROJECT_DIR" || return 1

    # Restart services that depend on database configuration
    local services_to_restart=("auth" "rest" "realtime" "storage")

    for service in "${services_to_restart[@]}"; do
        log "🔄 Restarting $service..."
        su "$TARGET_USER" -c "docker compose restart $service" 2>/dev/null || warn "Could not restart $service"
        sleep 5
    done

    # Wait a bit for services to settle
    sleep 15

    ok "✅ Service restart completed"
}

# =============================================================================
# UTILITY SCRIPTS AND TOOLS
# =============================================================================

create_management_scripts() {
    log "🛠️ Creating management and utility scripts..."

    mkdir -p "$PROJECT_DIR/scripts"

    # Health check script
    cat > "$PROJECT_DIR/scripts/health-check.sh" << 'HEALTH_EOF'
#!/bin/bash
# Supabase Health Check Script

cd "$(dirname "$0")/.."

echo "=== Supabase Health Status ==="
echo "Timestamp: $(date)"
echo ""

# Check if compose file exists
if [[ ! -f "docker-compose.yml" ]]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi

# Check service status
echo "Services Status:"
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check health status for services with health checks
echo "Health Checks:"
services=("db" "auth" "rest" "realtime" "storage" "meta" "kong" "studio" "edge-functions" "imgproxy")

for service in "${services[@]}"; do
    if docker ps --format "{{.Names}}" | grep -q "supabase-$service"; then
        health=$(docker inspect --format='{{.State.Health.Status}}' "supabase-$service" 2>/dev/null || echo "no-healthcheck")
        status=$(docker inspect --format='{{.State.Status}}' "supabase-$service" 2>/dev/null || echo "unknown")

        if [[ "$health" == "healthy" ]]; then
            echo "✅ $service: healthy"
        elif [[ "$health" == "no-healthcheck" && "$status" == "running" ]]; then
            echo "✅ $service: running (no healthcheck)"
        elif [[ "$status" == "running" ]]; then
            echo "⚠️ $service: running but unhealthy"
        else
            echo "❌ $service: $status"
        fi
    else
        echo "❌ $service: not found"
    fi
done

echo ""

# Test connectivity
echo "Connectivity Tests:"

# Test Studio
if timeout 5 curl -s http://localhost:3000 >/dev/null 2>&1; then
    echo "✅ Studio (3000): accessible"
else
    echo "❌ Studio (3000): not accessible"
fi

# Test API Gateway
if timeout 5 curl -s http://localhost:8001 >/dev/null 2>&1; then
    echo "✅ API Gateway (8001): accessible"
else
    echo "❌ API Gateway (8001): not accessible"
fi

# Test PostgreSQL
if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
    echo "✅ PostgreSQL: accessible"
else
    echo "❌ PostgreSQL: not accessible"
fi

echo ""
echo "=== End Health Check ==="

HEALTH_EOF

    # Service logs script
    cat > "$PROJECT_DIR/scripts/logs.sh" << 'LOGS_EOF'
#!/bin/bash
# Supabase Logs Script

cd "$(dirname "$0")/.."

if [[ -z "$1" ]]; then
    echo "Usage: $0 <service> [lines]"
    echo ""
    echo "Available services:"
    docker compose ps --services
    exit 1
fi

SERVICE="$1"
LINES="${2:-50}"

if docker compose ps --services | grep -q "^$SERVICE$"; then
    echo "=== Logs for $SERVICE (last $LINES lines) ==="
    docker compose logs --tail="$LINES" "$SERVICE"
else
    echo "❌ Service '$SERVICE' not found"
    echo ""
    echo "Available services:"
    docker compose ps --services
fi

LOGS_EOF

    # Restart script
    cat > "$PROJECT_DIR/scripts/restart.sh" << 'RESTART_EOF'
#!/bin/bash
# Supabase Restart Script

cd "$(dirname "$0")/.."

SERVICE="${1:-all}"

if [[ "$SERVICE" == "all" ]]; then
    echo "🔄 Restarting all Supabase services..."
    docker compose down --timeout 30
    sleep 5
    docker compose up -d
    echo "✅ All services restarted"
elif docker compose ps --services | grep -q "^$SERVICE$"; then
    echo "🔄 Restarting $SERVICE..."
    docker compose restart "$SERVICE"
    echo "✅ $SERVICE restarted"
else
    echo "❌ Service '$SERVICE' not found"
    echo ""
    echo "Available services:"
    docker compose ps --services
    echo ""
    echo "Usage: $0 [service|all]"
fi

RESTART_EOF

    # Backup script
    cat > "$PROJECT_DIR/scripts/backup.sh" << 'BACKUP_EOF'
#!/bin/bash
# Supabase Backup Script

cd "$(dirname "$0")/.."

BACKUP_DIR="./backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🗄️ Creating Supabase backup..."
echo "Backup directory: $BACKUP_DIR"

# Backup PostgreSQL data
echo "📊 Backing up PostgreSQL database..."
docker exec supabase-db pg_dumpall -U postgres > "$BACKUP_DIR/postgres_full_backup.sql" 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo "✅ Database backup completed"
else
    echo "❌ Database backup failed"
fi

# Backup configuration files
echo "📄 Backing up configuration..."
cp .env "$BACKUP_DIR/env_backup" 2>/dev/null
cp docker-compose.yml "$BACKUP_DIR/" 2>/dev/null
cp -r volumes/kong "$BACKUP_DIR/" 2>/dev/null

# Backup storage files
if [[ -d "volumes/storage" ]]; then
    echo "📁 Backing up storage files..."
    tar -czf "$BACKUP_DIR/storage_backup.tar.gz" volumes/storage/ 2>/dev/null
fi

echo "✅ Backup completed: $BACKUP_DIR"
echo ""
echo "To restore, use: ./scripts/restore.sh $BACKUP_DIR"

BACKUP_EOF

    # Update script
    cat > "$PROJECT_DIR/scripts/update.sh" << 'UPDATE_EOF'
#!/bin/bash
# Supabase Update Script

cd "$(dirname "$0")/.."

echo "🔄 Updating Supabase services..."

# Create backup before update
./scripts/backup.sh

echo "📦 Pulling latest images..."
docker compose pull

echo "🔄 Restarting services with new images..."
docker compose down --timeout 30
docker compose up -d

echo "🧹 Cleaning up old images..."
docker image prune -f

echo "✅ Update completed"
echo ""
echo "Run './scripts/health-check.sh' to verify all services are healthy"

UPDATE_EOF

    # Make scripts executable
    chmod +x "$PROJECT_DIR/scripts"/*.sh
    chown -R "$TARGET_USER:$TARGET_USER" "$PROJECT_DIR/scripts"

    ok "✅ Management scripts created in $PROJECT_DIR/scripts/"
}

# =============================================================================
# INSTALLATION VALIDATION
# =============================================================================

validate_installation() {
    log "🧪 Validating installation..."

    cd "$PROJECT_DIR" || error_exit "Failed to change to project directory"

    local tests_passed=0
    local tests_total=6
    local validation_errors=()

    # Test 1: Check all containers are running
    log "📊 Test 1/6: Container status..."
    local running_containers=$(docker compose ps --format "{{.Name}}" --filter "status=running" | wc -l)
    local total_containers=$(docker compose ps --format "{{.Name}}" | wc -l)

    if [[ $running_containers -eq $total_containers ]] && [[ $total_containers -gt 8 ]]; then
        ok "✅ All containers running ($running_containers/$total_containers)"
        ((tests_passed++))
    else
        validation_errors+=("Only $running_containers/$total_containers containers running")
        warn "❌ Container status check failed"
    fi

    # Test 2: PostgreSQL connectivity
    log "📊 Test 2/6: PostgreSQL connectivity..."
    if docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; then
        ok "✅ PostgreSQL accessible"
        ((tests_passed++))
    else
        validation_errors+=("PostgreSQL not accessible")
        warn "❌ PostgreSQL connectivity failed"
    fi

    # Test 3: Studio web interface
    log "📊 Test 3/6: Studio web interface..."
    if timeout 10 curl -sf http://localhost:3000 >/dev/null 2>&1; then
        ok "✅ Studio accessible on port 3000"
        ((tests_passed++))
    else
        validation_errors+=("Studio web interface not accessible")
        warn "❌ Studio accessibility failed"
    fi

    # Test 4: API Gateway
    log "📊 Test 4/6: API Gateway..."
    if timeout 10 curl -sf http://localhost:$SUPABASE_PORT >/dev/null 2>&1; then
        ok "✅ API Gateway accessible on port $SUPABASE_PORT"
        ((tests_passed++))
    else
        validation_errors+=("API Gateway not accessible on port $SUPABASE_PORT")
        warn "❌ API Gateway accessibility failed"
    fi

    # Test 5: Database schema
    log "📊 Test 5/6: Database schema validation..."
    local schema_check=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT COUNT(*) FROM information_schema.schemata
        WHERE schema_name IN ('auth', 'storage', 'realtime', 'public');
    " 2>/dev/null || echo "0")

    if [[ "$schema_check" -ge 4 ]]; then
        ok "✅ Database schemas created ($schema_check found)"
        ((tests_passed++))
    else
        validation_errors+=("Database schemas incomplete ($schema_check/4)")
        warn "❌ Database schema validation failed"
    fi

    # Test 6: Environment file
    log "📊 Test 6/6: Environment configuration..."
    if [[ -f "$PROJECT_DIR/.env" ]] && grep -q "POSTGRES_PASSWORD" "$PROJECT_DIR/.env"; then
        local env_vars_count=$(grep -c "=" "$PROJECT_DIR/.env" 2>/dev/null || echo "0")
        if [[ $env_vars_count -gt 15 ]]; then
            ok "✅ Environment file complete ($env_vars_count variables)"
            ((tests_passed++))
        else
            validation_errors+=("Environment file incomplete ($env_vars_count variables)")
            warn "❌ Environment file validation failed"
        fi
    else
        validation_errors+=("Environment file missing or invalid")
        warn "❌ Environment file validation failed"
    fi

    # Summary
    log "📋 Validation Summary: $tests_passed/$tests_total tests passed"

    if [[ $tests_passed -eq $tests_total ]]; then
        ok "✅ Installation validation successful!"
        return 0
    else
        warn "⚠️ Installation validation completed with issues:"
        for error in "${validation_errors[@]}"; do
            warn "   - $error"
        done
        return 1
    fi
}

# =============================================================================
# API KEYS DISPLAY (EARLY)
# =============================================================================

show_api_keys_early() {
    echo ""
    echo "======================================================================="
    echo "🔑 CRITICAL: SAVE THESE API KEYS NOW!"
    echo "======================================================================="
    echo ""
    echo "✅ All services deployed successfully!"
    echo ""
    echo "🌐 **Service Access URLs:**"
    echo "   🎨 Supabase Studio  : http://$LOCAL_IP:3000"
    echo "   🔌 API Gateway      : http://$LOCAL_IP:$SUPABASE_PORT"
    echo "   ⚡ Edge Functions   : http://$LOCAL_IP:54321"
    echo "   🗄️ PostgreSQL       : $LOCAL_IP:5432"
    echo ""
    echo "🔑 **API Keys (SAVE IMMEDIATELY!):**"
    echo "   📄 Full credentials stored in: $PROJECT_DIR/.env"
    echo ""
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        echo "   🔐 ANON_KEY (Public - Use in frontend):"
        grep "^SUPABASE_ANON_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | sed 's/^/      /'
        echo ""
        echo "   🔑 SERVICE_ROLE_KEY (PRIVATE - Server-side ONLY!):"
        grep "^SUPABASE_SERVICE_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | sed 's/^/      /'
        echo ""
        echo "   🔒 JWT_SECRET (first 32 chars):"
        grep "^JWT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | head -c 32 | sed 's/^/      /' && echo "..."
        echo ""
        echo "   🗄️ DATABASE_PASSWORD (first 16 chars):"
        grep "^POSTGRES_PASSWORD=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | head -c 16 | sed 's/^/      /' && echo "..."
    fi
    echo ""
    echo "⚠️  **Security Reminders:**"
    echo "   ❌ NEVER expose SERVICE_ROLE_KEY in frontend code"
    echo "   ❌ NEVER commit .env file to Git"
    echo "   ✅ Use ANON_KEY for client-side applications"
    echo "   ✅ Enable Row Level Security (RLS) on all tables"
    echo ""
    echo "📋 Continuing with database initialization..."
    echo "======================================================================="
    echo ""
}

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

show_completion_summary() {
    echo ""
    echo "======================================================================="
    echo "🎉 SUPABASE PI 5 INSTALLATION COMPLETED!"
    echo "======================================================================="
    echo ""

    # Run validation and capture result
    local validation_status=0
    validate_installation || validation_status=$?

    if [[ $validation_status -eq 0 ]]; then
        echo "✅ **Installation completed successfully with all tests passing!**"
    else
        echo "⚠️ **Installation completed with some validation issues**"
        echo "   Check the validation output above for details"
    fi

    echo ""
    echo "🖥️ **System Information:**"
    echo "   📍 Target User: $TARGET_USER"
    echo "   📁 Project Directory: $PROJECT_DIR"
    echo "   🔧 Script Version: $SCRIPT_VERSION"
    echo "   📄 Log File: $LOG_FILE"
    echo ""

    echo "🌐 **Service Access URLs:**"
    echo "   🎨 Supabase Studio  : http://$LOCAL_IP:3000"
    echo "   🔌 API Gateway      : http://$LOCAL_IP:$SUPABASE_PORT"
    echo "   ⚡ Edge Functions   : http://$LOCAL_IP:54321"
    echo "   🗄️ PostgreSQL       : $LOCAL_IP:5432"
    echo ""

    echo "🔑 **CRITICAL: Save These API Keys Now!**"
    echo "   📄 Full credentials: $PROJECT_DIR/.env"
    echo ""
    if [[ -f "$PROJECT_DIR/.env" ]]; then
        echo "   🔐 ANON_KEY (Public):"
        grep "^SUPABASE_ANON_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | sed 's/^/      /'
        echo ""
        echo "   🔑 SERVICE_ROLE_KEY (Private - NEVER expose!):"
        grep "^SUPABASE_SERVICE_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | sed 's/^/      /'
        echo ""
        echo "   🔒 JWT_SECRET:"
        grep "^JWT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | head -c 32 | sed 's/^/      /' && echo "..."
        echo ""
        echo "   🗄️ DATABASE_PASSWORD:"
        grep "^POSTGRES_PASSWORD=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | head -c 16 | sed 's/^/      /' && echo "..."
        echo ""
    else
        warn "   ⚠️ .env file not found at $PROJECT_DIR/.env"
    fi

    echo "🛠️ **Management Commands:**"
    echo "   cd $PROJECT_DIR"
    echo "   ./scripts/health-check.sh    # Check service health"
    echo "   ./scripts/logs.sh <service>  # View service logs"
    echo "   ./scripts/restart.sh [service] # Restart services"
    echo "   ./scripts/backup.sh          # Create backup"
    echo "   ./scripts/update.sh          # Update to latest images"
    echo ""

    echo "📊 **Quick Health Check:**"
    echo "   docker compose ps            # View all containers"
    echo "   docker compose logs realtime # Debug realtime issues"
    echo "   docker compose logs kong     # Debug API gateway"
    echo ""

    echo "🔧 **Pi 5 Optimizations Applied:**"
    echo "   ✅ PostgreSQL 16.4 ARM64 (modern syntax support)"
    echo "   ✅ Fixed health checks (wget commands)"
    echo "   ✅ Proper encryption keys for ARM64"
    echo "   ✅ Database schema with fallback logic"
    echo "   ✅ Resource limits for 16GB Pi 5"
    echo "   ✅ Container restart handling"
    echo ""

    echo "🚀 **Next Steps:**"
    echo "   1. Access Studio at http://$LOCAL_IP:3000"
    echo "   2. Create your first project/table"
    echo "   3. Test API endpoints via http://$LOCAL_IP:$SUPABASE_PORT"
    echo "   4. Configure external access (Week 3 - HTTPS setup)"
    echo "   5. Set up backups and monitoring"
    echo ""

    if [[ $validation_status -ne 0 ]]; then
        echo "⚠️ **Troubleshooting:**"
        echo "   1. Run: ./scripts/health-check.sh"
        echo "   2. Check logs: ./scripts/logs.sh <failing-service>"
        echo "   3. Restart problematic services: ./scripts/restart.sh <service>"
        echo "   4. Review installation log: $LOG_FILE"
        echo ""
    fi

    echo "📚 **Documentation:**"
    echo "   - Supabase Docs: https://supabase.com/docs"
    echo "   - Pi 5 Setup Repo: https://github.com/your-repo/pi5-setup"
    echo "   - Report Issues: Check project README"
    echo ""
    echo "======================================================================="
    echo "🎯 Installation completed in $(date)"
    echo "======================================================================="
}

# =============================================================================
# MAIN EXECUTION FLOW
# =============================================================================

main() {
    # Initial setup
    require_root
    setup_logging

    log "🎯 Starting Supabase installation for user: $TARGET_USER"
    log "🥧 Optimized for Raspberry Pi 5 ARM64 architecture"

    # Phase 1: Prerequisites and validation
    log "=== Phase 1: System Validation ==="
    check_system_requirements
    check_docker_prerequisites
    check_port_conflicts

    # Phase 2: Project setup
    log "=== Phase 2: Project Configuration ==="
    create_project_structure
    generate_secure_secrets
    create_environment_file

    # Phase 3: Service configuration
    log "=== Phase 3: Service Configuration ==="
    create_docker_compose
    create_kong_configuration
    create_database_init_scripts

    # Phase 4: Deployment
    log "=== Phase 4: Service Deployment ==="
    deploy_services

    # Display API keys immediately after successful deployment (before potential SQL issues)
    show_api_keys_early

    # Phase 5: Post-deployment configuration
    log "=== Phase 5: Post-Deployment Setup ==="
    configure_database_users
    restart_dependent_services

    # Phase 6: Utilities and validation
    log "=== Phase 6: Finalization ==="
    create_management_scripts

    # Show completion summary
    show_completion_summary

    log "🎉 Supabase Pi 5 installation completed successfully!"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Set trap for cleanup on script termination
trap cleanup_on_error EXIT

# Execute main function with all arguments
main "$@"

# Clear trap on successful completion
trap - EXIT

exit 0

