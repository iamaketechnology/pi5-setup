#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Monitoring Stack Deployment for Raspberry Pi 5
# =============================================================================
# Purpose: Deploy complete monitoring solution with Prometheus, Grafana, and exporters
# Architecture: ARM64 (Raspberry Pi 5)
# Stack Components:
#   - Prometheus: Metrics storage and querying
#   - Grafana: Visualization dashboards
#   - Node Exporter: OS/hardware metrics (CPU, RAM, disk, network, temperature)
#   - cAdvisor: Docker container metrics
#   - Postgres Exporter: Supabase PostgreSQL metrics (optional, auto-detected)
# Auto-Detection: Traefik scenario (DuckDNS, Cloudflare, VPN)
# Auto-Detection: Existing Supabase installation
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 5-8 minutes
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[MONITORING]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]      \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]        \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]     \033[0m $*"; }

# Global variables
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/monitoring-deploy-$(date +%Y%m%d_%H%M%S).log"
TARGET_USER="${SUDO_USER:-pi}"
MONITORING_DIR="/home/${TARGET_USER}/stacks/monitoring"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
CONFIG_DIR="${MONITORING_DIR}/config"
COMPOSE_FILE="${MONITORING_DIR}/docker-compose.yml"

# Traefik scenario detection
TRAEFIK_SCENARIO=""
DOMAIN=""
GRAFANA_URL=""
GRAFANA_SUBDOMAIN=""
PROMETHEUS_SUBDOMAIN=""

# Service detection
HAS_SUPABASE=false
HAS_TRAEFIK=false
SUPABASE_DB_PASSWORD=""

# User configuration
GRAFANA_ADMIN_PASSWORD=""
PROMETHEUS_RETENTION="15d"

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

    local dependencies=("docker" "curl" "openssl")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        warn "Missing dependencies: ${missing_deps[*]}"
        log "Attempting to install missing dependencies..."
        apt update -qq

        for dep in "${missing_deps[@]}"; do
            case "$dep" in
                docker)
                    error_exit "Docker not found. Please install Docker first."
                    ;;
                *)
                    apt install -y "$dep"
                    ;;
            esac
        done
    fi

    ok "All dependencies are present"
}

check_docker() {
    log "Verifying Docker installation..."

    if ! systemctl is-active --quiet docker; then
        warn "Docker service is not running. Starting Docker..."
        systemctl start docker || error_exit "Failed to start Docker"
    fi

    if ! docker info &> /dev/null; then
        error_exit "Docker is not functioning correctly"
    fi

    if ! docker compose version &> /dev/null; then
        error_exit "Docker Compose plugin not found. Please install docker-compose-plugin"
    fi

    ok "Docker is installed and running"
}

check_traefik_installation() {
    log "Checking for Traefik installation..."

    if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
        error_exit "Traefik container is not running. Please deploy Traefik first using one of the 01-traefik-deploy-*.sh scripts"
    fi

    if [[ ! -d "$TRAEFIK_DIR" ]]; then
        error_exit "Traefik directory not found at $TRAEFIK_DIR"
    fi

    if [[ ! -f "$TRAEFIK_DIR/.env" ]]; then
        error_exit "Traefik .env file not found. Cannot detect deployment scenario."
    fi

    HAS_TRAEFIK=true
    ok "Traefik is installed and running"
}

check_traefik_network() {
    log "Checking for Traefik network..."

    if ! docker network ls --format '{{.Name}}' | grep -q '^traefik_network$'; then
        error_exit "Traefik network 'traefik_network' not found. Please ensure Traefik is properly deployed."
    fi

    ok "Traefik network exists"
}

check_existing_monitoring() {
    log "Checking for existing Monitoring installation..."

    local existing_containers=()

    if docker ps -a --format '{{.Names}}' | grep -q '^prometheus$'; then
        existing_containers+=("prometheus")
    fi

    if docker ps -a --format '{{.Names}}' | grep -q '^grafana$'; then
        existing_containers+=("grafana")
    fi

    if [ ${#existing_containers[@]} -gt 0 ]; then
        warn "Existing monitoring containers found: ${existing_containers[*]}"
        read -p "Do you want to remove them and continue? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Stopping and removing existing monitoring containers..."
            cd "$MONITORING_DIR" 2>/dev/null && docker compose down 2>/dev/null || true
            for container in "${existing_containers[@]}"; do
                docker stop "$container" 2>/dev/null || true
                docker rm "$container" 2>/dev/null || true
            done
            ok "Existing containers removed"
        else
            error_exit "Installation cancelled by user"
        fi
    fi
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

detect_supabase_installation() {
    log "Detecting Supabase installation..."

    if [[ -d "$SUPABASE_DIR" ]] && docker ps --format '{{.Names}}' | grep -q 'supabase-db'; then
        HAS_SUPABASE=true
        ok "Supabase installation detected"

        # Extract PostgreSQL password from Supabase .env
        if [[ -f "$SUPABASE_DIR/.env" ]]; then
            SUPABASE_DB_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$SUPABASE_DIR/.env" | cut -d'=' -f2)
            if [[ -n "$SUPABASE_DB_PASSWORD" ]]; then
                ok "Supabase database credentials found"
            else
                warn "Could not extract Supabase database password"
            fi
        fi
    else
        log "Supabase not found (optional - postgres_exporter will be skipped)"
    fi
}

check_system_resources() {
    log "Checking system resources..."

    # Check architecture
    local arch=$(uname -m)
    if [[ "$arch" != "aarch64" ]]; then
        error_exit "Architecture $arch not supported (ARM64 required)"
    fi
    ok "Architecture: ARM64 (aarch64)"

    # Check RAM
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    if [[ $ram_gb -lt 2 ]]; then
        warn "Low RAM detected: ${ram_gb}GB (minimum 2GB recommended for monitoring stack)"
    else
        ok "RAM: ${ram_gb}GB"
    fi

    # Check disk space
    local disk_gb=$(df "$MONITORING_DIR" 2>/dev/null | awk 'NR==2 {print int($4/1024/1024)}' || df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt 2 ]]; then
        error_exit "Insufficient disk space: ${disk_gb}GB available (minimum 2GB required for monitoring data)"
    else
        ok "Disk space: ${disk_gb}GB available"
    fi
}

check_port_availability() {
    log "Checking port availability..."

    local ports_to_check=("3000" "9090" "9100" "8080")
    local ports_in_use=()

    for port in "${ports_to_check[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} " || ss -tuln 2>/dev/null | grep -q ":${port} "; then
            # Check if it's used by our monitoring stack (which is OK)
            if ! docker ps --format '{{.Names}} {{.Ports}}' | grep -E "(prometheus|grafana|node_exporter|cadvisor)" | grep -q ":${port}"; then
                ports_in_use+=("$port")
            fi
        fi
    done

    if [ ${#ports_in_use[@]} -gt 0 ]; then
        warn "The following ports are in use: ${ports_in_use[*]}"
        warn "Monitoring stack requires ports: 3000 (Grafana), 9090 (Prometheus), 9100 (Node Exporter), 8080 (cAdvisor)"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error_exit "Installation cancelled due to port conflicts"
        fi
    else
        ok "All required ports are available"
    fi
}

# =============================================================================
# USER INPUT SECTION
# =============================================================================

prompt_user_input() {
    log "Collecting Monitoring Stack configuration..."
    echo ""
    echo "=========================================="
    echo "Monitoring Stack Configuration"
    echo "=========================================="
    echo ""
    echo "Detected Scenario: $TRAEFIK_SCENARIO"
    echo "Base Domain: $DOMAIN"
    [[ "$HAS_SUPABASE" == true ]] && echo "Supabase: Detected (postgres_exporter will be included)"
    echo ""

    # Grafana admin password
    echo "Grafana Admin Password:"
    log "Generating secure admin password..."
    GRAFANA_ADMIN_PASSWORD=$(openssl rand -base64 16)
    ok "Password generated: $GRAFANA_ADMIN_PASSWORD"
    echo ""
    read -p "Use this password or enter your own (press Enter to use generated): " custom_password
    if [[ -n "$custom_password" ]]; then
        GRAFANA_ADMIN_PASSWORD="$custom_password"
        ok "Using custom password"
    fi
    echo ""
    warn "IMPORTANT: Save this password securely!"
    echo ""

    # Prometheus data retention
    echo "Prometheus Data Retention:"
    echo "  Default: 15 days (recommended for Raspberry Pi)"
    echo "  Longer retention requires more disk space (~100MB/day)"
    echo ""
    read -p "Enter retention period in days (default: 15): " retention_input
    if [[ -n "$retention_input" ]] && [[ "$retention_input" =~ ^[0-9]+$ ]]; then
        PROMETHEUS_RETENTION="${retention_input}d"
        ok "Using retention: $PROMETHEUS_RETENTION"
    else
        ok "Using default retention: $PROMETHEUS_RETENTION"
    fi
    echo ""

    # Grafana URL based on scenario
    case "$TRAEFIK_SCENARIO" in
        duckdns)
            log "DuckDNS scenario: Using path-based routing"
            echo "Grafana will be accessible at: https://${DOMAIN}/grafana"
            echo "Prometheus (internal): https://prometheus.pi.local"
            GRAFANA_URL="https://${DOMAIN}/grafana"
            GRAFANA_SUBDOMAIN="N/A"
            PROMETHEUS_SUBDOMAIN="prometheus.pi.local"
            ;;

        cloudflare)
            echo "Cloudflare scenario: Subdomain-based routing"
            echo ""
            read -p "Enter subdomain for Grafana (default: grafana): " grafana_sub
            if [[ -z "$grafana_sub" ]]; then
                GRAFANA_SUBDOMAIN="grafana"
                log "Using default: grafana"
            else
                GRAFANA_SUBDOMAIN="$grafana_sub"
            fi
            GRAFANA_URL="https://${GRAFANA_SUBDOMAIN}.${DOMAIN}"
            PROMETHEUS_SUBDOMAIN="prometheus.pi.local"

            echo ""
            log "Grafana URL: $GRAFANA_URL"
            log "Prometheus (internal): https://$PROMETHEUS_SUBDOMAIN"
            ;;

        vpn)
            echo "VPN scenario: Local domain routing"
            echo ""
            read -p "Enter local domain for Grafana (default: grafana.pi.local): " grafana_domain
            if [[ -z "$grafana_domain" ]]; then
                GRAFANA_SUBDOMAIN="grafana.pi.local"
                log "Using default: grafana.pi.local"
            else
                GRAFANA_SUBDOMAIN="$grafana_domain"
            fi
            GRAFANA_URL="https://${GRAFANA_SUBDOMAIN}"
            PROMETHEUS_SUBDOMAIN="prometheus.pi.local"

            echo ""
            log "Grafana URL: $GRAFANA_URL"
            log "Prometheus (internal): https://$PROMETHEUS_SUBDOMAIN"
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "Configuration Summary:"
    echo "=========================================="
    echo "Scenario: $TRAEFIK_SCENARIO"
    echo "Grafana URL: $GRAFANA_URL"
    echo "Grafana Admin Password: $GRAFANA_ADMIN_PASSWORD"
    echo "Prometheus Retention: $PROMETHEUS_RETENTION"
    echo "Components:"
    echo "  - Prometheus (metrics storage)"
    echo "  - Grafana (dashboards)"
    echo "  - Node Exporter (system metrics)"
    echo "  - cAdvisor (container metrics)"
    [[ "$HAS_SUPABASE" == true ]] && echo "  - Postgres Exporter (Supabase DB metrics)"
    echo "=========================================="
    echo ""

    read -p "Proceed with this configuration? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error_exit "Installation cancelled by user"
    fi
}

# =============================================================================
# MAIN EXECUTION SECTION
# =============================================================================

setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    log "=== Monitoring Stack Deployment - $(date) ==="
    log "Version: $SCRIPT_VERSION"
    log "Target User: $TARGET_USER"
    log "Log File: $LOG_FILE"
}

create_directory_structure() {
    log "Creating directory structure..."

    # Create main directories
    mkdir -p "$MONITORING_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$CONFIG_DIR/prometheus"
    mkdir -p "$CONFIG_DIR/grafana/provisioning/datasources"
    mkdir -p "$CONFIG_DIR/grafana/provisioning/dashboards"
    mkdir -p "$CONFIG_DIR/grafana/dashboards"

    # Create backup directory
    mkdir -p "${MONITORING_DIR}/backups"

    # Set ownership
    chown -R "$TARGET_USER:$TARGET_USER" "$MONITORING_DIR"

    ok "Directory structure created at $MONITORING_DIR"
}

generate_prometheus_config() {
    log "Generating Prometheus configuration..."

    local prometheus_config="global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'raspberry-pi-5'
    instance: '$(hostname)'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          service: 'prometheus'

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node_exporter:9100']
        labels:
          service: 'node_exporter'
          type: 'system'

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
        labels:
          service: 'cadvisor'
          type: 'docker'
"

    # Add postgres_exporter if Supabase detected
    if [[ "$HAS_SUPABASE" == true ]]; then
        prometheus_config+="
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres_exporter:9187']
        labels:
          service: 'postgres_exporter'
          type: 'database'
          database: 'supabase'
"
    fi

    cat > "$CONFIG_DIR/prometheus/prometheus.yml" << EOF
# Prometheus Configuration for Raspberry Pi 5 Monitoring
# Generated: $(date)
# Auto-detection: Traefik scenario ($TRAEFIK_SCENARIO)
# Auto-detection: Supabase ($([ "$HAS_SUPABASE" = true ] && echo "enabled" || echo "disabled"))

$prometheus_config
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/prometheus/prometheus.yml"
    ok "Prometheus configuration generated"
}

generate_grafana_datasource() {
    log "Generating Grafana datasource configuration..."

    cat > "$CONFIG_DIR/grafana/provisioning/datasources/prometheus.yml" << 'EOF'
# Grafana Datasource Configuration
# Auto-provisioned Prometheus datasource

apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
    jsonData:
      timeInterval: 15s
      httpMethod: POST
    version: 1
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/grafana/provisioning/datasources/prometheus.yml"
    ok "Grafana datasource configuration generated"
}

generate_grafana_dashboard_provisioning() {
    log "Generating Grafana dashboard provisioning configuration..."

    cat > "$CONFIG_DIR/grafana/provisioning/dashboards/default.yml" << 'EOF'
# Grafana Dashboard Provisioning Configuration
# Auto-load dashboards from /var/lib/grafana/dashboards

apiVersion: 1

providers:
  - name: 'Raspberry Pi Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

    chown "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/grafana/provisioning/dashboards/default.yml"
    ok "Grafana dashboard provisioning configuration generated"
}

generate_grafana_dashboards() {
    log "Generating pre-configured Grafana dashboards..."

    # Dashboard 1: Raspberry Pi 5 System Dashboard
    cat > "$CONFIG_DIR/grafana/dashboards/raspberry-pi-system.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "uid": "raspberry-pi-5-system",
    "title": "Raspberry Pi 5 - System Metrics",
    "tags": ["raspberry-pi", "system", "hardware"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 1,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "title": "CPU Usage",
        "targets": [
          {
            "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
            "legendFormat": "CPU Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent", "min": 0, "max": 100},
          {"format": "short"}
        ]
      },
      {
        "id": 2,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "graph",
        "title": "Memory Usage",
        "targets": [
          {
            "expr": "100 * (1 - ((node_memory_MemAvailable_bytes) / (node_memory_MemTotal_bytes)))",
            "legendFormat": "Memory Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent", "min": 0, "max": 100},
          {"format": "short"}
        ]
      },
      {
        "id": 3,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "type": "graph",
        "title": "Disk Usage",
        "targets": [
          {
            "expr": "100 - ((node_filesystem_avail_bytes{mountpoint=\"/\",fstype!=\"rootfs\"} * 100) / node_filesystem_size_bytes{mountpoint=\"/\",fstype!=\"rootfs\"})",
            "legendFormat": "Disk Usage %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent", "min": 0, "max": 100},
          {"format": "short"}
        ]
      },
      {
        "id": 4,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "type": "graph",
        "title": "CPU Temperature",
        "targets": [
          {
            "expr": "node_hwmon_temp_celsius",
            "legendFormat": "Temperature °C",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "celsius", "min": 0},
          {"format": "short"}
        ]
      },
      {
        "id": 5,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 16},
        "type": "graph",
        "title": "Network Traffic",
        "targets": [
          {
            "expr": "irate(node_network_receive_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "Receive - {{device}}",
            "refId": "A"
          },
          {
            "expr": "irate(node_network_transmit_bytes_total{device!=\"lo\"}[5m])",
            "legendFormat": "Transmit - {{device}}",
            "refId": "B"
          }
        ],
        "yaxes": [
          {"format": "Bps"},
          {"format": "short"}
        ]
      },
      {
        "id": 6,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 16},
        "type": "stat",
        "title": "System Uptime",
        "targets": [
          {
            "expr": "node_time_seconds - node_boot_time_seconds",
            "refId": "A"
          }
        ],
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"]
          }
        },
        "fieldConfig": {
          "defaults": {
            "unit": "s"
          }
        }
      }
    ]
  }
}
EOF

    # Dashboard 2: Docker Containers Dashboard
    cat > "$CONFIG_DIR/grafana/dashboards/docker-containers.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "uid": "docker-containers",
    "title": "Docker Containers - Resource Usage",
    "tags": ["docker", "containers"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 1,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "title": "Container CPU Usage",
        "targets": [
          {
            "expr": "sum(rate(container_cpu_usage_seconds_total{name!=\"\"}[5m])) by (name) * 100",
            "legendFormat": "{{name}}",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent"},
          {"format": "short"}
        ]
      },
      {
        "id": 2,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "graph",
        "title": "Container Memory Usage",
        "targets": [
          {
            "expr": "sum(container_memory_usage_bytes{name!=\"\"}) by (name)",
            "legendFormat": "{{name}}",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "bytes"},
          {"format": "short"}
        ]
      },
      {
        "id": 3,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "type": "graph",
        "title": "Container Network I/O",
        "targets": [
          {
            "expr": "sum(rate(container_network_receive_bytes_total{name!=\"\"}[5m])) by (name)",
            "legendFormat": "RX - {{name}}",
            "refId": "A"
          },
          {
            "expr": "sum(rate(container_network_transmit_bytes_total{name!=\"\"}[5m])) by (name)",
            "legendFormat": "TX - {{name}}",
            "refId": "B"
          }
        ],
        "yaxes": [
          {"format": "Bps"},
          {"format": "short"}
        ]
      },
      {
        "id": 4,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "type": "stat",
        "title": "Running Containers",
        "targets": [
          {
            "expr": "count(container_last_seen{name!=\"\"})",
            "refId": "A"
          }
        ],
        "options": {
          "reduceOptions": {
            "values": false,
            "calcs": ["lastNotNull"]
          }
        }
      }
    ]
  }
}
EOF

    # Dashboard 3: Supabase PostgreSQL Dashboard (only if Supabase detected)
    if [[ "$HAS_SUPABASE" == true ]]; then
        cat > "$CONFIG_DIR/grafana/dashboards/supabase-postgres.json" << 'EOF'
{
  "dashboard": {
    "id": null,
    "uid": "supabase-postgres",
    "title": "Supabase PostgreSQL - Database Metrics",
    "tags": ["postgresql", "supabase", "database"],
    "timezone": "browser",
    "schemaVersion": 16,
    "version": 1,
    "refresh": "30s",
    "panels": [
      {
        "id": 1,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
        "type": "graph",
        "title": "Database Connections",
        "targets": [
          {
            "expr": "pg_stat_database_numbackends{datname=\"postgres\"}",
            "legendFormat": "Active Connections",
            "refId": "A"
          }
        ]
      },
      {
        "id": 2,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
        "type": "graph",
        "title": "Transactions per Second",
        "targets": [
          {
            "expr": "rate(pg_stat_database_xact_commit{datname=\"postgres\"}[5m])",
            "legendFormat": "Commits/sec",
            "refId": "A"
          },
          {
            "expr": "rate(pg_stat_database_xact_rollback{datname=\"postgres\"}[5m])",
            "legendFormat": "Rollbacks/sec",
            "refId": "B"
          }
        ]
      },
      {
        "id": 3,
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
        "type": "graph",
        "title": "Cache Hit Ratio",
        "targets": [
          {
            "expr": "100 * (sum(pg_stat_database_blks_hit{datname=\"postgres\"}) / (sum(pg_stat_database_blks_hit{datname=\"postgres\"}) + sum(pg_stat_database_blks_read{datname=\"postgres\"})))",
            "legendFormat": "Cache Hit %",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "percent", "min": 0, "max": 100},
          {"format": "short"}
        ]
      },
      {
        "id": 4,
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
        "type": "graph",
        "title": "Database Size",
        "targets": [
          {
            "expr": "pg_database_size_bytes{datname=\"postgres\"}",
            "legendFormat": "Database Size",
            "refId": "A"
          }
        ],
        "yaxes": [
          {"format": "bytes"},
          {"format": "short"}
        ]
      }
    ]
  }
}
EOF
        ok "Supabase PostgreSQL dashboard generated"
    fi

    chown -R "$TARGET_USER:$TARGET_USER" "$CONFIG_DIR/grafana/dashboards/"
    ok "Grafana dashboards generated ($(ls -1 "$CONFIG_DIR/grafana/dashboards/" | wc -l) dashboards)"
}

generate_env_file() {
    log "Generating environment file..."

    cat > "$MONITORING_DIR/.env" << EOF
# Monitoring Stack Environment Variables
# Generated: $(date)

# Grafana Configuration
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
GRAFANA_ROOT_URL=${GRAFANA_URL}

# Prometheus Configuration
PROMETHEUS_RETENTION=${PROMETHEUS_RETENTION}

# Traefik Scenario
TRAEFIK_SCENARIO=${TRAEFIK_SCENARIO}
DOMAIN=${DOMAIN}
GRAFANA_SUBDOMAIN=${GRAFANA_SUBDOMAIN}

# Supabase Integration
HAS_SUPABASE=${HAS_SUPABASE}
EOF

    if [[ "$HAS_SUPABASE" == true ]]; then
        cat >> "$MONITORING_DIR/.env" << EOF
POSTGRES_PASSWORD=${SUPABASE_DB_PASSWORD}
DATA_SOURCE_NAME=postgresql://postgres:${SUPABASE_DB_PASSWORD}@supabase-db:5432/postgres?sslmode=disable
EOF
    fi

    chmod 600 "$MONITORING_DIR/.env"
    chown "$TARGET_USER:$TARGET_USER" "$MONITORING_DIR/.env"
    ok "Environment file generated"
}

generate_docker_compose() {
    log "Generating docker-compose.yml..."

    local grafana_traefik_labels=""
    local prometheus_traefik_labels=""

    # Generate Traefik labels based on scenario
    case "$TRAEFIK_SCENARIO" in
        duckdns)
            # Path-based routing for Grafana
            grafana_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.grafana.rule=Host(\\\`${DOMAIN}\\\`) && PathPrefix(\\\`/grafana\\\`)\"
      - \"traefik.http.routers.grafana.entrypoints=websecure\"
      - \"traefik.http.routers.grafana.tls.certresolver=letsencrypt\"
      - \"traefik.http.middlewares.grafana-stripprefix.stripprefix.prefixes=/grafana\"
      - \"traefik.http.routers.grafana.middlewares=grafana-stripprefix\"
      - \"traefik.http.services.grafana.loadbalancer.server.port=3000\""

            # Prometheus internal only
            prometheus_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.prometheus.rule=Host(\\\`prometheus.pi.local\\\`)\"
      - \"traefik.http.routers.prometheus.entrypoints=websecure\"
      - \"traefik.http.routers.prometheus.tls=true\"
      - \"traefik.http.services.prometheus.loadbalancer.server.port=9090\""
            ;;

        cloudflare)
            # Subdomain-based routing for Grafana
            grafana_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.grafana.rule=Host(\\\`${GRAFANA_SUBDOMAIN}.${DOMAIN}\\\`)\"
      - \"traefik.http.routers.grafana.entrypoints=websecure\"
      - \"traefik.http.routers.grafana.tls.certresolver=cloudflare\"
      - \"traefik.http.services.grafana.loadbalancer.server.port=3000\""

            # Prometheus internal only
            prometheus_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.prometheus.rule=Host(\\\`prometheus.pi.local\\\`)\"
      - \"traefik.http.routers.prometheus.entrypoints=websecure\"
      - \"traefik.http.routers.prometheus.tls=true\"
      - \"traefik.http.services.prometheus.loadbalancer.server.port=9090\""
            ;;

        vpn)
            # Local domain routing for Grafana
            grafana_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.grafana.rule=Host(\\\`${GRAFANA_SUBDOMAIN}\\\`)\"
      - \"traefik.http.routers.grafana.entrypoints=websecure\"
      - \"traefik.http.routers.grafana.tls=true\"
      - \"traefik.http.services.grafana.loadbalancer.server.port=3000\""

            # Prometheus internal
            prometheus_traefik_labels="      - \"traefik.enable=true\"
      - \"traefik.http.routers.prometheus.rule=Host(\\\`prometheus.pi.local\\\`)\"
      - \"traefik.http.routers.prometheus.entrypoints=websecure\"
      - \"traefik.http.routers.prometheus.tls=true\"
      - \"traefik.http.services.prometheus.loadbalancer.server.port=9090\""
            ;;
    esac

    # Base docker-compose content
    cat > "$COMPOSE_FILE" << EOF
# Monitoring Stack Docker Compose Configuration
# Generated: $(date)
# Scenario: ${TRAEFIK_SCENARIO}

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    user: "65534:65534"  # nobody user for security
    volumes:
      - ./config/prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${PROMETHEUS_RETENTION}'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--web.enable-admin-api'
    networks:
      - monitoring
      - traefik_network
    labels:
${prometheus_traefik_labels}
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    user: "472:472"  # grafana user
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=\${GRAFANA_ROOT_URL}
      - GF_INSTALL_PLUGINS=
      - GF_ANALYTICS_REPORTING_ENABLED=false
      - GF_ANALYTICS_CHECK_FOR_UPDATES=false
    networks:
      - monitoring
      - traefik_network
    depends_on:
      - prometheus
    labels:
${grafana_traefik_labels}
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  node_exporter:
    image: prom/node-exporter:latest
    container_name: node_exporter
    restart: unless-stopped
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
      - '--collector.hwmon'
      - '--collector.thermal_zone'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring
    labels:
      - "traefik.enable=false"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9100/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /dev/disk:/dev/disk:ro
    networks:
      - monitoring
    labels:
      - "traefik.enable=false"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF

    # Add postgres_exporter if Supabase detected
    if [[ "$HAS_SUPABASE" == true ]]; then
        cat >> "$COMPOSE_FILE" << 'EOF'

  postgres_exporter:
    image: prometheuscommunity/postgres-exporter:latest
    container_name: postgres_exporter
    restart: unless-stopped
    environment:
      - DATA_SOURCE_NAME=${DATA_SOURCE_NAME}
    networks:
      - monitoring
      - supabase_network
    labels:
      - "traefik.enable=false"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9187/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
EOF
    fi

    # Add volumes and networks
    cat >> "$COMPOSE_FILE" << EOF

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

networks:
  monitoring:
    name: monitoring_network
    driver: bridge
  traefik_network:
    external: true
    name: traefik_network
EOF

    # Add supabase network if needed
    if [[ "$HAS_SUPABASE" == true ]]; then
        cat >> "$COMPOSE_FILE" << 'EOF'
  supabase_network:
    external: true
    name: supabase_network_default
EOF
    fi

    chown "$TARGET_USER:$TARGET_USER" "$COMPOSE_FILE"
    ok "docker-compose.yml generated"
}

create_backup() {
    if [[ -f "$CONFIG_DIR/prometheus/prometheus.yml" ]] || [[ -f "$COMPOSE_FILE" ]]; then
        log "Creating backup of existing configuration..."

        local backup_dir="${MONITORING_DIR}/backups"
        local backup_file="${backup_dir}/monitoring-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

        mkdir -p "$backup_dir"

        tar -czf "$backup_file" -C "$MONITORING_DIR" \
            $(ls "$CONFIG_DIR" 2>/dev/null | sed 's|^|config/|' || true) \
            $(basename "$COMPOSE_FILE" 2>/dev/null || true) \
            $(basename "$MONITORING_DIR/.env" 2>/dev/null || true) 2>/dev/null || true

        if [[ -f "$backup_file" ]]; then
            chown "$TARGET_USER:$TARGET_USER" "$backup_file"
            ok "Backup created: $backup_file"
        fi
    fi
}

deploy_monitoring_stack() {
    log "Deploying Monitoring Stack..."

    # Change to monitoring directory
    cd "$MONITORING_DIR"

    # Pull images first
    log "Pulling Docker images (this may take a few minutes)..."
    sudo -u "$TARGET_USER" docker compose pull

    # Start the stack
    log "Starting Monitoring Stack..."
    sudo -u "$TARGET_USER" docker compose up -d

    # Wait for containers to start
    log "Waiting for containers to start..."
    sleep 15

    ok "Monitoring Stack deployed successfully"
}

# =============================================================================
# VERIFICATION SECTION
# =============================================================================

verify_deployment() {
    log "Verifying deployment..."

    local checks_passed=0
    local total_checks=7

    if [[ "$HAS_SUPABASE" == true ]]; then
        total_checks=8
    fi

    # Check Prometheus container
    if docker ps | grep -q 'prometheus'; then
        ok "  Prometheus container is running"
        ((checks_passed++))
    else
        error "  Prometheus container is not running"
    fi

    # Check Grafana container
    if docker ps | grep -q 'grafana'; then
        ok "  Grafana container is running"
        ((checks_passed++))
    else
        error "  Grafana container is not running"
    fi

    # Check Node Exporter container
    if docker ps | grep -q 'node_exporter'; then
        ok "  Node Exporter container is running"
        ((checks_passed++))
    else
        error "  Node Exporter container is not running"
    fi

    # Check cAdvisor container
    if docker ps | grep -q 'cadvisor'; then
        ok "  cAdvisor container is running"
        ((checks_passed++))
    else
        error "  cAdvisor container is not running"
    fi

    # Check Postgres Exporter if Supabase detected
    if [[ "$HAS_SUPABASE" == true ]]; then
        if docker ps | grep -q 'postgres_exporter'; then
            ok "  Postgres Exporter container is running"
            ((checks_passed++))
        else
            warn "  Postgres Exporter container is not running"
        fi
    fi

    # Check Prometheus health
    sleep 5
    if docker exec prometheus wget -q --tries=1 --spider http://localhost:9090/-/healthy &> /dev/null; then
        ok "  Prometheus health check passed"
        ((checks_passed++))
    else
        warn "  Prometheus health check failed (may need more time)"
    fi

    # Check Grafana health
    if docker exec grafana wget -q --tries=1 --spider http://localhost:3000/api/health &> /dev/null; then
        ok "  Grafana health check passed"
        ((checks_passed++))
    else
        warn "  Grafana health check failed (may need more time)"
    fi

    # Check networks
    if docker inspect prometheus 2>/dev/null | grep -q "monitoring_network" && \
       docker inspect prometheus 2>/dev/null | grep -q "traefik_network"; then
        ok "  Containers connected to required networks"
        ((checks_passed++))
    else
        error "  Network connectivity issues detected"
    fi

    echo ""
    log "Verification: $checks_passed/$total_checks checks passed"

    if [[ $checks_passed -ge $(($total_checks - 1)) ]]; then
        ok "Deployment verification successful"
        return 0
    else
        error "Some verification checks failed"
        return 1
    fi
}

verify_prometheus_targets() {
    log "Verifying Prometheus scrape targets..."

    sleep 10

    # Check Prometheus targets API
    local targets_json=$(docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets 2>/dev/null || echo "{}")

    if echo "$targets_json" | grep -q '"status":"success"'; then
        ok "  Prometheus targets API accessible"

        # Count active targets
        local active_targets=$(echo "$targets_json" | grep -o '"health":"up"' | wc -l)
        log "  Active targets: $active_targets"

        if [[ $active_targets -ge 3 ]]; then
            ok "  Prometheus is scraping metrics successfully"
        else
            warn "  Some targets may not be ready yet"
        fi
    else
        warn "  Could not verify Prometheus targets (may need more time)"
    fi
}

test_grafana_access() {
    log "Testing Grafana accessibility..."

    # Wait for SSL certificates (only for first-time setup)
    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        log "Waiting 30 seconds for SSL certificate generation..."
        sleep 30
    fi

    # Test Grafana endpoint
    log "Testing Grafana: $GRAFANA_URL"
    if curl -s -k -m 10 "$GRAFANA_URL" &> /dev/null; then
        ok "Grafana accessible via Traefik"
    else
        warn "Grafana test failed (DNS propagation may take time)"
    fi
}

# =============================================================================
# SUMMARY SECTION
# =============================================================================

show_summary() {
    echo ""
    echo "=========================================="
    echo "Monitoring Stack Deployment Complete"
    echo "=========================================="
    echo ""
    echo "Installation Details:"
    echo "  Stack Location: $MONITORING_DIR"
    echo "  Config Directory: $CONFIG_DIR"
    echo "  Log File: $LOG_FILE"
    echo ""
    echo "Access Information:"
    echo "  Grafana URL: $GRAFANA_URL"
    echo "  Grafana Username: admin"
    echo "  Grafana Password: $GRAFANA_ADMIN_PASSWORD"
    echo ""
    echo "  Prometheus (internal): https://$PROMETHEUS_SUBDOMAIN"
    echo ""
    echo "Components:"
    echo "  - Prometheus: Metrics storage and querying"
    echo "  - Grafana: Visualization dashboards"
    echo "  - Node Exporter: System metrics (CPU, RAM, disk, temperature)"
    echo "  - cAdvisor: Docker container metrics"
    [[ "$HAS_SUPABASE" == true ]] && echo "  - Postgres Exporter: Supabase database metrics"
    echo ""
    echo "Configuration:"
    echo "  Prometheus Retention: $PROMETHEUS_RETENTION"
    echo "  Traefik Scenario: $TRAEFIK_SCENARIO"
    echo "  Domain: $DOMAIN"
    echo ""
    echo "Pre-configured Dashboards:"
    echo "  1. Raspberry Pi 5 - System Metrics"
    echo "     - CPU usage, memory, disk, temperature, network"
    echo "  2. Docker Containers - Resource Usage"
    echo "     - Container CPU, memory, network I/O"
    [[ "$HAS_SUPABASE" == true ]] && echo "  3. Supabase PostgreSQL - Database Metrics"
    [[ "$HAS_SUPABASE" == true ]] && echo "     - Connections, transactions, cache hit ratio, size"
    echo ""
    echo "Container Management:"
    echo "  View logs: cd $MONITORING_DIR && docker compose logs -f"
    echo "  Restart: cd $MONITORING_DIR && docker compose restart"
    echo "  Stop: cd $MONITORING_DIR && docker compose down"
    echo "  Start: cd $MONITORING_DIR && docker compose up -d"
    echo ""
    echo "Prometheus Queries:"
    echo "  View targets: http://$PROMETHEUS_SUBDOMAIN/targets"
    echo "  Query metrics: http://$PROMETHEUS_SUBDOMAIN/graph"
    echo ""

    if [[ "$TRAEFIK_SCENARIO" == "duckdns" ]] || [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "Important Notes:"
        echo "  - DNS propagation may take 5-15 minutes"
        echo "  - SSL certificate will be issued automatically"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "cloudflare" ]]; then
        echo "  - Ensure DNS record for ${GRAFANA_SUBDOMAIN}.${DOMAIN} points to your Pi's IP"
    fi

    if [[ "$TRAEFIK_SCENARIO" == "vpn" ]]; then
        echo "Important Notes:"
        echo "  - Ensure VPN DNS is configured for .pi.local domains"
        echo "  - Access only works when connected to VPN"
    fi

    echo ""
    echo "Grafana Dashboard Setup:"
    echo "  1. Login to Grafana: $GRAFANA_URL"
    echo "  2. Navigate to Dashboards → Browse"
    echo "  3. Pre-configured dashboards are already loaded"
    echo "  4. Customize dashboards as needed"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check Prometheus: docker logs prometheus"
    echo "  - Check Grafana: docker logs grafana"
    echo "  - Check targets: docker exec prometheus wget -qO- http://localhost:9090/api/v1/targets"
    echo "  - Check Traefik: docker logs traefik"
    echo "  - Test locally: curl -I -k $GRAFANA_URL"
    echo ""
    echo "Security Notes:"
    echo "  - Prometheus is only accessible internally (not exposed publicly)"
    echo "  - Grafana requires login (admin credentials above)"
    echo "  - Change Grafana password after first login (recommended)"
    echo ""
    echo "Data Retention:"
    echo "  - Prometheus data is retained for $PROMETHEUS_RETENTION"
    echo "  - Estimated disk usage: ~100MB per day"
    echo "  - Data location: $MONITORING_DIR/prometheus_data/"
    echo ""
    echo "Next Steps:"
    echo "  1. Access Grafana and verify dashboards are loading"
    echo "  2. Explore system metrics in Raspberry Pi dashboard"
    echo "  3. Monitor Docker containers in container dashboard"
    [[ "$HAS_SUPABASE" == true ]] && echo "  4. Check Supabase database metrics"
    echo ""
    echo "=========================================="

    # Save summary to file
    cat > "$MONITORING_DIR/DEPLOYMENT_INFO.txt" << SUMMARY
Monitoring Stack Deployment Summary
Generated: $(date)

Grafana URL: ${GRAFANA_URL}
Grafana Username: admin
Grafana Password: ${GRAFANA_ADMIN_PASSWORD}

Prometheus URL (internal): https://${PROMETHEUS_SUBDOMAIN}

Scenario: ${TRAEFIK_SCENARIO}
Domain: ${DOMAIN}

Stack Directory: ${MONITORING_DIR}
Config Directory: ${CONFIG_DIR}
Log File: ${LOG_FILE}

Components:
  - Prometheus (metrics storage)
  - Grafana (dashboards)
  - Node Exporter (system metrics)
  - cAdvisor (container metrics)
$([ "$HAS_SUPABASE" = true ] && echo "  - Postgres Exporter (database metrics)")

Configuration:
  Prometheus Retention: ${PROMETHEUS_RETENTION}
  Supabase Integration: $([ "$HAS_SUPABASE" = true ] && echo "Enabled" || echo "Disabled")

Pre-configured Dashboards:
  1. Raspberry Pi 5 - System Metrics
  2. Docker Containers - Resource Usage
$([ "$HAS_SUPABASE" = true ] && echo "  3. Supabase PostgreSQL - Database Metrics")

Container Commands:
  cd ${MONITORING_DIR}
  docker compose logs -f          # View logs
  docker compose restart          # Restart services
  docker compose down             # Stop services
  docker compose up -d            # Start services

Prometheus Queries:
  http://${PROMETHEUS_SUBDOMAIN}/targets
  http://${PROMETHEUS_SUBDOMAIN}/graph

Security:
  - Prometheus: Internal access only
  - Grafana: Login required
  - Change Grafana password after first login

Data Retention:
  ${PROMETHEUS_RETENTION} (approximately $(echo $PROMETHEUS_RETENTION | sed 's/d/ days/'))
  Estimated disk usage: ~100MB per day

Docker Compose: ${COMPOSE_FILE}
Environment File: ${MONITORING_DIR}/.env
SUMMARY

    chmod 600 "$MONITORING_DIR/DEPLOYMENT_INFO.txt"
    chown "$TARGET_USER:$TARGET_USER" "$MONITORING_DIR/DEPLOYMENT_INFO.txt"

    ok "Deployment information saved to $MONITORING_DIR/DEPLOYMENT_INFO.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    require_root
    setup_logging

    echo ""
    log "Starting Monitoring Stack deployment for Raspberry Pi 5"
    echo ""

    # Validation
    check_dependencies
    check_docker
    check_traefik_installation
    check_traefik_network
    check_existing_monitoring
    check_system_resources
    check_port_availability
    detect_traefik_scenario
    detect_supabase_installation
    echo ""

    # User input
    prompt_user_input
    echo ""

    # Main execution
    create_directory_structure
    create_backup
    generate_prometheus_config
    generate_grafana_datasource
    generate_grafana_dashboard_provisioning
    generate_grafana_dashboards
    generate_env_file
    generate_docker_compose
    echo ""

    # Deployment
    deploy_monitoring_stack
    echo ""

    # Verification
    verify_deployment
    verify_prometheus_targets
    test_grafana_access
    echo ""

    # Summary
    show_summary
}

main "$@"
