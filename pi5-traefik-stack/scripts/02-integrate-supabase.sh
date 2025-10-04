#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Supabase-Traefik Integration Script for Raspberry Pi 5
# =============================================================================
# Purpose: Integrate existing Supabase installation with Traefik reverse proxy
# Architecture: ARM64 (Raspberry Pi 5)
# Services: Supabase Kong (API) + Studio (UI)
# Scenarios: DuckDNS (path-based), Cloudflare (subdomain), VPN (local)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 2-5 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[SUPABASE]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]   \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/supabase-traefik-integration-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
SUPABASE_COMPOSE_FILE="${SUPABASE_DIR}/docker-compose.yml"
BACKUP_DIR="${SUPABASE_DIR}/backups"

# Traefik scenario detection
TRAEFIK_SCENARIO=""
DOMAIN=""
API_DOMAIN=""
STUDIO_DOMAIN=""

# User-provided variables
USER_DOMAIN=""
API_SUBDOMAIN=""
STUDIO_SUBDOMAIN=""

# Error handling
error_exit() {
    error "$1"
    exit 1
}

# Trap errors
trap 'error_exit "Script failed at line $LINENO"' ERR

# =============================================================================
# VALIDATION SECTION
# =============================================================================

require_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    log "Checking system dependencies..."

    local dependencies=("docker" "yq")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}"

        # Try to install missing dependencies
        log "Attempting to install missing dependencies..."
        apt update -qq

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker)
                    error_exit "Docker not found. Please install Docker first."
                    ;;
                yq)
                    log "Installing yq for YAML processing..."
                    # Install yq for ARM64
                    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_arm64"
                    chmod +x /usr/local/bin/yq
                    ok "yq installed successfully"
                    ;;
                *)
                    apt install -y "$dep"
                    ;;
            esac
        done
    fi

    ok "All dependencies are present"
}

check_traefik_installation() {
    log "Checking for Traefik installation..."

    # Check if Traefik container is running
    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        error_exit "Traefik container is not running. Please deploy Traefik first using one of the 01-traefik-deploy-*.sh scripts"
    fi

    # Check if Traefik directory exists
    if [[ ! -d "$TRAEFIK_DIR" ]]; then
        error_exit "Traefik directory not found at $TRAEFIK_DIR"
    fi

    # Check if Traefik .env file exists
    if [[ ! -f "$TRAEFIK_DIR/.env" ]]; then
        error_exit "Traefik .env file not found. Cannot detect deployment scenario."
    fi

    ok "Traefik is installed and running"
}

check_supabase_installation() {
    log "Checking for Supabase installation..."

    # Check if Supabase directory exists
    if [[ ! -d "$SUPABASE_DIR" ]]; then
        error_exit "Supabase directory not found at $SUPABASE_DIR. Please install Supabase first."
    fi

    # Check if docker-compose.yml exists
    if [[ ! -f "$SUPABASE_COMPOSE_FILE" ]]; then
        error_exit "Supabase docker-compose.yml not found at $SUPABASE_COMPOSE_FILE"
    fi

    # Check if Supabase containers are running
    local supabase_containers=$(docker ps --filter "name=supabase" --format '{{.Names}}' | wc -l)
    if [[ $supabase_containers -lt 5 ]]; then
        warn "Supabase containers may not be fully running (found $supabase_containers containers)"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled by user"
        fi
    fi

    ok "Supabase installation found"
}

check_traefik_network() {
    log "Checking for Traefik network..."

    if ! docker network ls --format '{{.Name}}' | grep -q '^traefik_network$'; then
        error_exit "Traefik network 'traefik_network' not found. Please ensure Traefik is properly deployed."
    fi

    ok "Traefik network exists"
}

detect_traefik_scenario() {
    log "Detecting Traefik deployment scenario..."

    # Read Traefik .env file to determine scenario
    source "$TRAEFIK_DIR/.env"

    if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="duckdns"
        DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        ok "Detected scenario: DuckDNS (path-based routing)"
        log "Base domain: $DOMAIN"
    elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN="${CLOUDFLARE_DOMAIN}"
        ok "Detected scenario: Cloudflare (subdomain-based routing)"
        log "Base domain: $DOMAIN"
    elif [[ -n "${VPN_DOMAIN:-}" ]]; then
        TRAEFIK_SCENARIO="vpn"
        DOMAIN="${VPN_DOMAIN}"
        ok "Detected scenario: VPN (local .pi.local domains)"
        log "Base domain: $DOMAIN"
    else
        error_exit "Could not detect Traefik deployment scenario from .env file"
    fi
}

check_existing_labels() {
    log "Checking for existing Traefik labels in Supabase configuration..."

    if grep -q "traefik.enable" "$SUPABASE_COMPOSE_FILE"; then
        warn "Existing Traefik labels found in Supabase docker-compose.yml"
        read -p "Do you want to overwrite them? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Integration cancelled by user"
        fi
        log "Will overwrite existing labels"
    else
        ok "No existing Traefik labels found"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting domain configuration..."
    echo ""
    echo "=========================================="
    echo "Supabase-Traefik Integration Configuration"
    echo "=========================================="
    echo ""
    echo "Detected Scenario: $TRAEFIK_SCENARIO"
    echo "Base Domain: $DOMAIN"
    echo ""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing - use same domain with different paths
            API_DOMAIN="$DOMAIN"
            STUDIO_DOMAIN="$DOMAIN"

            log "Using path-based routing:"
            echo "  API Gateway: https://${API_DOMAIN}/api"
            echo "  Studio UI: https://${STUDIO_DOMAIN}/studio"
            ;;

        cloudflare)
            # Subdomain-based routing
            echo "Enter subdomains for Supabase services:"
            echo "(These will be created as subdomains of $DOMAIN)"
            echo ""

            # API subdomain
            read -p "Enter subdomain for API Gateway (e.g., 'api' for api.$DOMAIN): " API_SUBDOMAIN
            if [[ -z "$API_SUBDOMAIN" ]]; then
                API_SUBDOMAIN="api"
                log "Using default: api"
            fi
            API_DOMAIN="${API_SUBDOMAIN}.${DOMAIN}"

            # Studio subdomain
            read -p "Enter subdomain for Studio UI (e.g., 'studio' for studio.$DOMAIN): " STUDIO_SUBDOMAIN
            if [[ -z "$STUDIO_SUBDOMAIN" ]]; then
                STUDIO_SUBDOMAIN="studio"
                log "Using default: studio"
            fi
            STUDIO_DOMAIN="${STUDIO_SUBDOMAIN}.${DOMAIN}"

            echo ""
            log "Configured domains:"
            echo "  API Gateway: https://${API_DOMAIN}"
            echo "  Studio UI: https://${STUDIO_DOMAIN}"
            ;;

        vpn)
            # Local .pi.local domains
            echo "Enter local domains for Supabase services:"
            echo "(Use .pi.local suffix for VPN scenario)"
            echo ""

            # API domain
            read -p "Enter domain for API Gateway (e.g., 'api.pi.local'): " API_SUBDOMAIN
            if [[ -z "$API_SUBDOMAIN" ]]; then
                API_SUBDOMAIN="api.pi.local"
                log "Using default: api.pi.local"
            fi
            API_DOMAIN="$API_SUBDOMAIN"

            # Studio domain
            read -p "Enter domain for Studio UI (e.g., 'studio.pi.local'): " STUDIO_SUBDOMAIN
            if [[ -z "$STUDIO_SUBDOMAIN" ]]; then
                STUDIO_SUBDOMAIN="studio.pi.local"
                log "Using default: studio.pi.local"
            fi
            STUDIO_DOMAIN="$STUDIO_SUBDOMAIN"

            echo ""
            log "Configured domains:"
            echo "  API Gateway: https://${API_DOMAIN}"
            echo "  Studio UI: https://${STUDIO_DOMAIN}"
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Scenario: $TRAEFIK_SCENARIO"
    echo "API Gateway: https://${API_DOMAIN}$([ "$TRAEFIK_SCENARIO" = "duckdns" ] && echo "/api" || echo "")"
    echo "Studio UI: https://${STUDIO_DOMAIN}$([ "$TRAEFIK_SCENARIO" = "duckdns" ] && echo "/studio" || echo "")"
    echo "=========================================="
    echo ""

    read -p "Proceed with this configuration? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error_exit "Integration cancelled by user"
    fi
}

# =============================================================================
# MAIN EXECUTION SECTION
# =============================================================================

setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    log "=== Supabase-Traefik Integration - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_backup() {
    log "Creating backup of Supabase docker-compose.yml..."

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Create timestamped backup
    local backup_file="${BACKUP_DIR}/docker-compose.yml.backup-$(date +%Y%m%d_%H%M%S)"
    cp "$SUPABASE_COMPOSE_FILE" "$backup_file"

    # Set ownership
    chown "$TARGET_USER:$TARGET_USER" "$backup_file"

    ok "Backup created: $backup_file"
}

add_traefik_labels_to_service() {
    local service_name="$1"
    local router_name="$2"
    local domain="$3"
    local port="$4"
    local path_prefix="${5:-}"  # Optional path prefix for DuckDNS scenario

    log "Adding Traefik labels to service: $service_name"

    # Start building the labels array
    local labels=""

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing with strip prefix middleware
            labels="
      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${domain}\`) && PathPrefix(\`${path_prefix}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls.certresolver=letsencrypt\"
      - \"traefik.http.services.${router_name}.loadbalancer.server.port=${port}\"
      - \"traefik.http.middlewares.${router_name}-stripprefix.stripprefix.prefixes=${path_prefix}\"
      - \"traefik.http.routers.${router_name}.middlewares=${router_name}-stripprefix\""
            ;;

        cloudflare)
            # Subdomain-based routing
            labels="
      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${domain}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls.certresolver=cloudflare\"
      - \"traefik.http.services.${router_name}.loadbalancer.server.port=${port}\""
            ;;

        vpn)
            # VPN local routing
            labels="
      - \"traefik.enable=true\"
      - \"traefik.http.routers.${router_name}.rule=Host(\`${domain}\`)\"
      - \"traefik.http.routers.${router_name}.entrypoints=websecure\"
      - \"traefik.http.routers.${router_name}.tls=true\"
      - \"traefik.http.services.${router_name}.loadbalancer.server.port=${port}\""
            ;;
    esac

    # Use yq to add labels to the service
    # First, check if service has labels section
    if yq eval ".services.${service_name}.labels" "$SUPABASE_COMPOSE_FILE" | grep -q "null"; then
        # No labels section exists, create it
        yq eval -i ".services.${service_name}.labels = []" "$SUPABASE_COMPOSE_FILE"
    else
        # Labels exist, remove any traefik-related ones first
        yq eval -i "del(.services.${service_name}.labels[] | select(. == \"*traefik*\"))" "$SUPABASE_COMPOSE_FILE" 2>/dev/null || true
    fi

    # Add each label using yq
    while IFS= read -r label; do
        if [[ -n "$label" ]]; then
            # Remove leading/trailing whitespace and quotes
            label=$(echo "$label" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^- "//' -e 's/"$//')
            if [[ -n "$label" ]]; then
                yq eval -i ".services.${service_name}.labels += [\"${label}\"]" "$SUPABASE_COMPOSE_FILE"
            fi
        fi
    done <<< "$labels"

    ok "Labels added to $service_name service"
}

add_traefik_network() {
    log "Adding Traefik network to Supabase services..."

    # Check if networks section exists
    if yq eval '.networks' "$SUPABASE_COMPOSE_FILE" | grep -q "null"; then
        log "Creating networks section..."
        yq eval -i '.networks = {}' "$SUPABASE_COMPOSE_FILE"
    fi

    # Add traefik network as external
    yq eval -i '.networks.traefik.external = true' "$SUPABASE_COMPOSE_FILE"
    yq eval -i '.networks.traefik.name = "traefik_network"' "$SUPABASE_COMPOSE_FILE"

    # Add traefik network to kong service
    if yq eval '.services.kong.networks' "$SUPABASE_COMPOSE_FILE" | grep -q "null"; then
        yq eval -i '.services.kong.networks = []' "$SUPABASE_COMPOSE_FILE"
    fi
    yq eval -i '.services.kong.networks += ["traefik"]' "$SUPABASE_COMPOSE_FILE"

    # Add traefik network to studio service
    if yq eval '.services.studio.networks' "$SUPABASE_COMPOSE_FILE" | grep -q "null"; then
        yq eval -i '.services.studio.networks = []' "$SUPABASE_COMPOSE_FILE"
    fi
    yq eval -i '.services.studio.networks += ["traefik"]' "$SUPABASE_COMPOSE_FILE"

    ok "Traefik network added to services"
}

modify_supabase_compose() {
    log "Modifying Supabase docker-compose.yml..."

    # Add Traefik network configuration
    add_traefik_network

    # Add labels based on scenario
    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing
            add_traefik_labels_to_service "kong" "supabase-api" "$API_DOMAIN" "8000" "/api"
            add_traefik_labels_to_service "studio" "supabase-studio" "$STUDIO_DOMAIN" "3000" "/studio"
            ;;

        cloudflare|vpn)
            # Subdomain-based or VPN routing (no path prefix)
            add_traefik_labels_to_service "kong" "supabase-api" "$API_DOMAIN" "8000"
            add_traefik_labels_to_service "studio" "supabase-studio" "$STUDIO_DOMAIN" "3000"
            ;;
    esac

    ok "Supabase docker-compose.yml modified successfully"
}

validate_yaml_syntax() {
    log "Validating YAML syntax..."

    if ! yq eval '.' "$SUPABASE_COMPOSE_FILE" > /dev/null 2>&1; then
        error "YAML syntax validation failed!"
        warn "Restoring from backup..."

        # Find the most recent backup
        local latest_backup=$(ls -t "$BACKUP_DIR"/docker-compose.yml.backup-* 2>/dev/null | head -n1)
        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" "$SUPABASE_COMPOSE_FILE"
            ok "Restored from backup: $latest_backup"
        fi

        error_exit "YAML validation failed. Please check the configuration."
    fi

    ok "YAML syntax is valid"
}

restart_supabase_services() {
    log "Restarting Supabase services..."

    # Change to Supabase directory
    cd "$SUPABASE_DIR"

    # Stop the services
    log "Stopping Supabase services..."
    sudo -u "$TARGET_USER" docker compose down

    # Wait a moment
    sleep 3

    # Start the services
    log "Starting Supabase services with new configuration..."
    sudo -u "$TARGET_USER" docker compose up -d

    # Wait for services to start
    log "Waiting for services to initialize..."
    sleep 15

    ok "Supabase services restarted"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_integration() {
    log "Verifying integration..."

    local checks_passed=0
    local total_checks=6

    # Check kong container
    if docker ps | grep -q 'supabase.*kong'; then
        ok "  Kong container is running"
        ((checks_passed++))
    else
        error "  Kong container is not running"
    fi

    # Check studio container
    if docker ps | grep -q 'supabase.*studio'; then
        ok "  Studio container is running"
        ((checks_passed++))
    else
        error "  Studio container is not running"
    fi

    # Check if kong is on traefik network
    if docker inspect $(docker ps --filter "name=kong" --format '{{.Names}}' | head -n1) 2>/dev/null | grep -q "traefik_network"; then
        ok "  Kong connected to Traefik network"
        ((checks_passed++))
    else
        error "  Kong not connected to Traefik network"
    fi

    # Check if studio is on traefik network
    if docker inspect $(docker ps --filter "name=studio" --format '{{.Names}}' | head -n1) 2>/dev/null | grep -q "traefik_network"; then
        ok "  Studio connected to Traefik network"
        ((checks_passed++))
    else
        error "  Studio not connected to Traefik network"
    fi

    # Check Traefik can see the services
    sleep 5
    local traefik_routers=$(docker exec traefik wget -qO- http://localhost:8080/api/http/routers 2>/dev/null | grep -c "supabase" || echo "0")
    if [[ $traefik_routers -ge 2 ]]; then
        ok "  Traefik detected Supabase routers ($traefik_routers found)"
        ((checks_passed++))
    else
        warn "  Traefik may not have detected all routers yet (found $traefik_routers)"
    fi

    # Check backup was created
    if [[ -d "$BACKUP_DIR" ]] && [[ $(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l) -gt 0 ]]; then
        ok "  Backup created successfully"
        ((checks_passed++))
    else
        error "  Backup not found"
    fi

    echo ""
    log "Verification: $checks_passed/$total_checks checks passed"

    if [[ $checks_passed -ge 4 ]]; then
        ok "Integration verification successful"
        return 0
    else
        error "Some verification checks failed"
        return 1
    fi
}

test_connectivity() {
    log "Testing connectivity to Supabase services..."

    # Wait for SSL certificates (only for first-time setup)
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        log "Waiting 30 seconds for SSL certificate generation..."
        sleep 30
    fi

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Test API endpoint
            log "Testing API Gateway: https://${API_DOMAIN}/api/..."
            if curl -s -k -m 10 "https://${API_DOMAIN}/api" &> /dev/null; then
                ok "API Gateway accessible"
            else
                warn "API Gateway test failed (may need DNS propagation time)"
            fi

            # Test Studio endpoint
            log "Testing Studio UI: https://${STUDIO_DOMAIN}/studio/..."
            if curl -s -k -m 10 "https://${STUDIO_DOMAIN}/studio" &> /dev/null; then
                ok "Studio UI accessible"
            else
                warn "Studio UI test failed (may need DNS propagation time)"
            fi
            ;;

        cloudflare)
            # Test API subdomain
            log "Testing API Gateway: https://${API_DOMAIN}/..."
            if curl -s -k -m 10 "https://${API_DOMAIN}" &> /dev/null; then
                ok "API Gateway accessible"
            else
                warn "API Gateway test failed (DNS propagation may take time)"
            fi

            # Test Studio subdomain
            log "Testing Studio UI: https://${STUDIO_DOMAIN}/..."
            if curl -s -k -m 10 "https://${STUDIO_DOMAIN}" &> /dev/null; then
                ok "Studio UI accessible"
            else
                warn "Studio UI test failed (DNS propagation may take time)"
            fi
            ;;

        vpn)
            # Test local domains
            log "Testing API Gateway: https://${API_DOMAIN}/..."
            if curl -s -k -m 10 "https://${API_DOMAIN}" &> /dev/null; then
                ok "API Gateway accessible"
            else
                warn "API Gateway test failed (ensure VPN is connected and DNS is configured)"
            fi

            # Test Studio local domain
            log "Testing Studio UI: https://${STUDIO_DOMAIN}/..."
            if curl -s -k -m 10 "https://${STUDIO_DOMAIN}" &> /dev/null; then
                ok "Studio UI accessible"
            else
                warn "Studio UI test failed (ensure VPN is connected and DNS is configured)"
            fi
            ;;
    esac
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "Supabase-Traefik Integration Complete"
    echo "=========================================="
    echo ""
    echo "Integration Details:"
    echo "  Scenario: $TRAEFIK_SCENARIO"
    echo "  Supabase Directory: $SUPABASE_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access URLs:"

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            echo "  API Gateway: https://${API_DOMAIN}/api"
            echo "  Studio UI: https://${STUDIO_DOMAIN}/studio"
            ;;
        cloudflare|vpn)
            echo "  API Gateway: https://${API_DOMAIN}"
            echo "  Studio UI: https://${STUDIO_DOMAIN}"
            ;;
    esac

    echo ""
    echo "Backup Information:"
    echo "  Backup Directory: $BACKUP_DIR"
    echo "  Latest Backup: $(ls -t "$BACKUP_DIR"/docker-compose.yml.backup-* 2>/dev/null | head -n1)"
    echo ""
    echo "Container Management:"
    echo "  View logs: cd $SUPABASE_DIR && docker compose logs -f"
    echo "  Restart: cd $SUPABASE_DIR && docker compose restart kong studio"
    echo "  Stop: cd $SUPABASE_DIR && docker compose down"
    echo "  Start: cd $SUPABASE_DIR && docker compose up -d"
    echo ""
    echo "Traefik Dashboard:"

    case "$TRAEFIK_SCENARIO" in
        duckdns)
            echo "  URL: https://${DOMAIN}/traefik"
            ;;
        cloudflare)
            echo "  URL: https://traefik.${DOMAIN}"
            ;;
        vpn)
            echo "  URL: https://traefik.pi.local"
            ;;
    esac

    echo ""
    echo "Important Notes:"

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "  - DNS propagation may take 5-15 minutes"
        echo "  - SSL certificates will be issued automatically"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "  - Ensure DNS records for subdomains are created:"
        echo "    * ${API_SUBDOMAIN}.${DOMAIN} -> Your Pi's IP"
        echo "    * ${STUDIO_SUBDOMAIN}.${DOMAIN} -> Your Pi's IP"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "vpn" ]]; then
        echo "  - Ensure VPN DNS is configured for .pi.local domains"
        echo "  - Access only works when connected to VPN"
    fi

    echo "  - Original docker-compose.yml backed up"
    echo "  - Services are now behind Traefik reverse proxy"
    echo "  - Direct port access (3000, 8000) may be blocked by firewall"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Traefik logs: docker logs traefik"
    echo "  - Check Kong logs: cd $SUPABASE_DIR && docker compose logs kong"
    echo "  - Check Studio logs: cd $SUPABASE_DIR && docker compose logs studio"
    echo "  - View Traefik routers: docker exec traefik wget -qO- http://localhost:8080/api/http/routers"

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "  - Verify DNS: nslookup ${API_DOMAIN}"
    fi

    echo "  - Test locally: curl -I -k https://${API_DOMAIN}$([ "$TRAEFIK_SCENARIO" = "duckdns" ] && echo "/api" || echo "")"
    echo ""
    echo "Rollback (if needed):"
    echo "  1. Stop services: cd $SUPABASE_DIR && docker compose down"
    echo "  2. Restore backup: cp $BACKUP_DIR/docker-compose.yml.backup-* $SUPABASE_COMPOSE_FILE"
    echo "  3. Start services: cd $SUPABASE_DIR && docker compose up -d"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$SUPABASE_DIR/TRAEFIK_INTEGRATION_INFO.txt" << SUMMARY
Supabase-Traefik Integration Summary
Generated: $(date)

Scenario: ${TRAEFIK_SCENARIO}
$([ "$TRAEFIK_SCENARIO" = "duckdns" ] && echo "
API Gateway: https://${API_DOMAIN}/api
Studio UI: https://${STUDIO_DOMAIN}/studio
" || echo "
API Gateway: https://${API_DOMAIN}
Studio UI: https://${STUDIO_DOMAIN}
")

Backup Directory: ${BACKUP_DIR}
Latest Backup: $(ls -t "$BACKUP_DIR"/docker-compose.yml.backup-* 2>/dev/null | head -n1)

Modified Services:
  - kong (API Gateway) - Port 8000
  - studio (Supabase Studio UI) - Port 3000

Traefik Network: traefik_network

Container Commands:
  cd ${SUPABASE_DIR}
  docker compose logs -f kong studio    # View logs
  docker compose restart kong studio    # Restart services
  docker compose down                   # Stop all services
  docker compose up -d                  # Start all services

Rollback Instructions:
  cd ${SUPABASE_DIR}
  docker compose down
  cp ${BACKUP_DIR}/docker-compose.yml.backup-* docker-compose.yml
  docker compose up -d

Configuration File: ${SUPABASE_COMPOSE_FILE}
Log File: ${LOG_FILE}
SUMMARY

    chmod 600 "$SUPABASE_DIR/TRAEFIK_INTEGRATION_INFO.txt"
    chown "$TARGET_USER:$TARGET_USER" "$SUPABASE_DIR/TRAEFIK_INTEGRATION_INFO.txt"

    ok "Integration information saved to $SUPABASE_DIR/TRAEFIK_INTEGRATION_INFO.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root
    setup_logging

    echo ""
    log "Starting Supabase-Traefik integration for Raspberry Pi 5"
    echo ""

    # Validation
    check_dependencies
    check_traefik_installation
    check_supabase_installation
    check_traefik_network
    detect_traefik_scenario
    check_existing_labels
    echo ""

    # User input
    prompt_user_input
    echo ""

    # Main execution
    create_backup
    modify_supabase_compose
    validate_yaml_syntax
    echo ""

    # Restart services
    restart_supabase_services
    echo ""

    # Verification
    verify_integration
    test_connectivity
    echo ""

    # Summary
    show_summary
}

main "$@"
