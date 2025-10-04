#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: monitoring-bootstrap.sh [options]

Déploie un stack de monitoring (Prometheus + Grafana + node_exporter + cAdvisor).

Variables:
  STACK_DIR             Répertoire d'installation (défaut: /opt/monitoring)
  PROMETHEUS_RETENTION  Durée de rétention Prometheus (défaut: 15d)
  GRAFANA_PORT          Port Grafana (défaut: 3001)

Options:
  --dry-run        Simule
  --yes, -y        Confirme
  --verbose, -v    Verbosité
  --quiet, -q      Silencieux
  --no-color       Sans couleurs
  --help, -h       Aide
USAGE
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

require_root

STACK_DIR=${STACK_DIR:-/opt/monitoring}
PROMETHEUS_RETENTION=${PROMETHEUS_RETENTION:-15d}
GRAFANA_PORT=${GRAFANA_PORT:-3001}

CONFIG_DIR="${STACK_DIR}/config"
DATA_DIR="${STACK_DIR}/data"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

ensure_dir "${STACK_DIR}"
ensure_dir "${CONFIG_DIR}"
ensure_dir "${DATA_DIR}/grafana"
ensure_dir "${DATA_DIR}/prometheus"

create_prometheus_config() {
  local file="${CONFIG_DIR}/prometheus.yml"
  log_info "Écriture Prometheus config"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] ${file}"
    return
  fi
  cat >"${file}" <<'PROM'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['prometheus:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
PROM
}

create_compose() {
  log_info "Création docker-compose.yml"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] ${COMPOSE_FILE}"
    return
  fi
  cat >"${COMPOSE_FILE}" <<YAML
version: "3.9"

services:
  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    volumes:
      - "./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro"
      - "./data/prometheus:/prometheus"
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.retention.time=${PROMETHEUS_RETENTION}"
      - "--web.enable-lifecycle"
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    environment:
      - "GF_SECURITY_ADMIN_USER=admin"
      - "GF_SECURITY_ADMIN_PASSWORD=admin"
      - "GF_SERVER_DOMAIN=localhost"
    volumes:
      - "./data/grafana:/var/lib/grafana"
    depends_on:
      - prometheus
    ports:
      - "${GRAFANA_PORT}:3000"

  node-exporter:
    image: prom/node-exporter:latest
    restart: unless-stopped
    pid: host
    network_mode: host
    command:
      - "--path.rootfs=/host"
    volumes:
      - "/:/host:ro,rslave"

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    restart: unless-stopped
    privileged: true
    devices:
      - "/dev/kmsg:/dev/kmsg"
    volumes:
      - "/:/rootfs:ro"
      - "/var/run:/var/run:ro"
      - "/sys:/sys:ro"
      - "/var/lib/docker/:/var/lib/docker:ro"
    ports:
      - "8080:8080"
YAML
}

deploy_stack() {
  log_info "Déploiement monitoring"
  local cwd="${PWD}"
  cd "${STACK_DIR}"
  run_cmd docker compose pull
  run_cmd docker compose up -d
  cd "${cwd}"
}

post_info() {
  log_success "Monitoring déployé"
  log_info "Prometheus → http://<IP>:9090"
  log_info "Grafana → http://<IP>:${GRAFANA_PORT} (admin/admin)"
}

main() {
  create_prometheus_config
  create_compose
  deploy_stack
  post_info
}

main "$@"
