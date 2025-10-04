#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 05-healthcheck-report.sh [options]

Génère un rapport de santé (Docker, services HTTP, ressources) en texte et Markdown.

Variables:
  REPORT_DIR           Dossier de sortie (défaut: /opt/reports)
  REPORT_PREFIX        Préfixe (défaut: healthcheck)
  HTTP_ENDPOINTS       URLs à tester (séparées par des virgules)
  DOCKER_COMPOSE_DIRS  Dossiers docker compose à vérifier (séparés par des virgules)

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

REPORT_DIR=${REPORT_DIR:-/opt/reports}
REPORT_PREFIX=${REPORT_PREFIX:-healthcheck}
HTTP_ENDPOINTS=${HTTP_ENDPOINTS:-http://localhost:8000/health}
DOCKER_COMPOSE_DIRS=${DOCKER_COMPOSE_DIRS:-/home/${USER}/stacks/supabase}

ensure_dir "${REPORT_DIR}"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_TXT="${REPORT_DIR}/${REPORT_PREFIX}-${TIMESTAMP}.txt"
REPORT_MD="${REPORT_DIR}/${REPORT_PREFIX}-${TIMESTAMP}.md"

IFS=',' read -r -a HTTP_ENDPOINT_ARRAY <<< "${HTTP_ENDPOINTS}"
IFS=',' read -r -a COMPOSE_DIR_ARRAY <<< "${DOCKER_COMPOSE_DIRS}"

write_txt() { printf '%s\n' "$*" >>"${REPORT_TXT}"; }
write_md() { printf '%s\n' "$*" >>"${REPORT_MD}"; }

capture_system_info() {
  log_info "Collecte informations système"
  local hostname=$(hostname)
  local os=$(detect_pretty_os)
  local kernel=$(uname -r)
  local uptime=$(uptime -p)
  local load=$(cat /proc/loadavg)

  write_txt "=== System ==="
  write_txt "Host: ${hostname}"
  write_txt "OS: ${os}"
  write_txt "Kernel: ${kernel}"
  write_txt "Uptime: ${uptime}"
  write_txt "Load: ${load}"

  write_md "# Rapport de santé (${TIMESTAMP})"
  write_md "## Système"
  write_md "- Hôte : ${hostname}"
  write_md "- OS : ${os}"
  write_md "- Kernel : ${kernel}"
  write_md "- Uptime : ${uptime}"
  write_md "- Load : ${load}"
}

capture_resources() {
  log_info "Analyse ressources"
  local mem=$(free -h)
  local disk=$(df -h /)

  write_txt "\n=== Ressources ==="
  write_txt "Mémoire:\n${mem}"
  write_txt "Disque (/):\n${disk}"

  write_md "\n## Ressources"
  write_md "### Mémoire"
  write_md '```
'"${mem}"'
```
'
  write_md "### Disque (/)
```
${disk}
```
"
}

check_docker() {
  log_info "Vérification Docker"
  local info
  if info=$(docker info 2>&1); then
    write_txt "\n=== Docker ==="
    write_txt "$(docker info | grep -E 'Server Version|Storage Driver|Logging Driver')"
    write_md "\n## Docker"
    write_md "- Status : OK"
    write_md '```
'"$(docker info | grep -E 'Server Version|Storage Driver|Logging Driver')"'
```'
  else
    write_txt "\n=== Docker ==="
    write_txt "KO: ${info}"
    write_md "\n## Docker"
    write_md "- Status : KO"
    write_md '```
'"${info}"'
```
'
  fi
}

check_compose_projects() {
  write_txt "\n=== Docker Compose ==="
  write_md "\n## Docker Compose"
  local dir
  for dir in "${COMPOSE_DIR_ARRAY[@]}"; do
    [[ -z ${dir} ]] && continue
    if [[ ! -d ${dir} ]]; then
      write_txt "${dir}: introuvable"
      write_md "- ${dir} : introuvable"
      continue
    fi
    local cwd="${PWD}"
    cd "${dir}"
    local status
    status=$(docker compose ps --format 'table {{.Name}}\t{{.State}}' 2>&1 || true)
    cd "${cwd}"
    write_txt "--- ${dir} ---\n${status}"
    write_md "### ${dir}
```
${status}
```
"
  done
}

check_http_endpoints() {
  write_txt "\n=== HTTP Endpoints ==="
  write_md "\n## HTTP Endpoints"
  local url
  for url in "${HTTP_ENDPOINT_ARRAY[@]}"; do
    [[ -z ${url} ]] && continue
    local status
    status=$(curl -sk -o /dev/null -w '%{http_code} %{time_total}' "${url}" 2>/dev/null || echo "000 0")
    write_txt "${url} -> ${status}"
    write_md "- ${url} → ${status}"
  done
}

summary_console() {
  log_info "Rapport généré"
  log_success "TXT: ${REPORT_TXT}"
  log_success "MD : ${REPORT_MD}"
}

main() {
  capture_system_info
  capture_resources
  check_docker
  check_compose_projects
  check_http_endpoints
  summary_console
}

main "$@"
