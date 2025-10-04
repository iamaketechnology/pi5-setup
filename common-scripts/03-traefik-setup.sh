#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 03-traefik-setup.sh [options]

Déploie Traefik en reverse proxy avec certificats Let's Encrypt.

Variables requises:
  TRAEFIK_DOMAIN          Domaine principal (ex: example.com)

Variables optionnelles:
  TRAEFIK_EMAIL           Email pour Let's Encrypt
  TRAEFIK_DNS_PROVIDER    Fournisseur DNS pour challenge DNS-01 (ex: cloudflare)
  TRAEFIK_DNS_API_TOKEN   Token API pour DNS-01 (selon provider)
  TRAEFIK_ACME_CA_SERVER  URL ACME custom (staging ou prod) (défaut: prod)
  TRAEFIK_DASHBOARD_AUTH  Identifiants htpasswd pour le dashboard (ex: user:hash)
  STACK_DIR               Répertoire d'installation (défaut: /opt/traefik)

Options:
  --dry-run        Simule
  --yes, -y        Confirme automatiquement
  --verbose, -v    Verbosité accrue
  --quiet, -q      Mode silencieux
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

TRAEFIK_DOMAIN=${TRAEFIK_DOMAIN:-}
TRAEFIK_EMAIL=${TRAEFIK_EMAIL:-admin@${TRAEFIK_DOMAIN}}
TRAEFIK_DNS_PROVIDER=${TRAEFIK_DNS_PROVIDER:-}
TRAEFIK_DNS_API_TOKEN=${TRAEFIK_DNS_API_TOKEN:-}
TRAEFIK_ACME_CA_SERVER=${TRAEFIK_ACME_CA_SERVER:-"https://acme-v02.api.letsencrypt.org/directory"}
TRAEFIK_DASHBOARD_AUTH=${TRAEFIK_DASHBOARD_AUTH:-}
STACK_DIR=${STACK_DIR:-/opt/traefik}

if [[ -z ${TRAEFIK_DOMAIN} ]]; then
  fatal "TRAEFIK_DOMAIN est requis"
fi

CONFIG_DIR="${STACK_DIR}/config"
DATA_DIR="${STACK_DIR}/data"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"

ensure_dir "${STACK_DIR}"
ensure_dir "${CONFIG_DIR}"
ensure_dir "${DATA_DIR}"

create_static_config() {
  local file="${CONFIG_DIR}/traefik.yml"
  log_info "Écriture configuration statique"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] cat > ${file}"
    return
  fi
  {
    cat <<STATIC
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"
certificatesResolvers:
  letsencrypt:
    acme:
      email: "${TRAEFIK_EMAIL}"
      storage: "/letsencrypt/acme.json"
      caServer: "${TRAEFIK_ACME_CA_SERVER}"
STATIC
    if [[ -n ${TRAEFIK_DNS_PROVIDER} ]]; then
      cat <<DNS
      dnsChallenge:
        provider: ${TRAEFIK_DNS_PROVIDER}
DNS
    else
      cat <<HTTP
      httpChallenge:
        entryPoint: web
HTTP
    fi
    cat <<'REST'
api:
  dashboard: true
providers:
  file:
    filename: "/etc/traefik/dynamic.yml"
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
log:
  level: INFO
accessLog: {}
REST
  } >"${file}"
}

create_dynamic_config() {
  local file="${CONFIG_DIR}/dynamic.yml"
  log_info "Écriture configuration dynamique"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] cat > ${file}"
    return
  fi
  {
    cat <<'BASE'
http:
  middlewares:
    redirect-to-https:
      redirectScheme:
        scheme: https
    dashboard-auth:
      basicAuth:
        users:
BASE
    if [[ -n ${TRAEFIK_DASHBOARD_AUTH} ]]; then
      printf '          - "%s"\n' "${TRAEFIK_DASHBOARD_AUTH}"
    else
      printf '          - "admin:$$apr1$$7YmH5pF6$$ClkY6RLMG9JLYJD9jx1zk/"\n'
    fi
    cat <<DASH
  routers:
    traefik-dashboard:
      rule: "Host(\"traefik.${TRAEFIK_DOMAIN}\")"
      service: api@internal
      entryPoints: ["websecure"]
      middlewares: ["dashboard-auth"]
DASH
  } >"${file}"
}

create_compose() {
  log_info "Création docker-compose.yml"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] cat > ${COMPOSE_FILE}"
    return
  fi
  cat >"${COMPOSE_FILE}" <<'YAML'
version: "3.9"

services:
  traefik:
    image: traefik:v3.1
    container_name: traefik
    restart: unless-stopped
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--providers.file.filename=/etc/traefik/dynamic.yml"
      - "--log.level=INFO"
      - "--api.dashboard=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${TRAEFIK_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
YAML
  if [[ -n ${TRAEFIK_DNS_PROVIDER} ]]; then
    cat >>"${COMPOSE_FILE}" <<YAML
      - "--certificatesresolvers.letsencrypt.acme.dnschallenge.provider=${TRAEFIK_DNS_PROVIDER}"
YAML
  else
    cat >>"${COMPOSE_FILE}" <<YAML
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
YAML
  fi
  cat >>"${COMPOSE_FILE}" <<'YAML'
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./config/traefik.yml:/etc/traefik/traefik.yml:ro"
      - "./config/dynamic.yml:/etc/traefik/dynamic.yml:ro"
      - "./data:/letsencrypt"
    environment:
      - "TZ=Etc/UTC"
YAML
  if [[ -n ${TRAEFIK_DNS_PROVIDER} ]]; then
    cat >>"${COMPOSE_FILE}" <<YAML
      - "${TRAEFIK_DNS_PROVIDER^^}_API_TOKEN=${TRAEFIK_DNS_API_TOKEN}"
YAML
  fi
}

protect_files() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] chmod 600 ${DATA_DIR}/acme.json"
    return
  fi
  touch "${DATA_DIR}/acme.json"
  chmod 600 "${DATA_DIR}/acme.json"
}

deploy_stack() {
  log_info "Déploiement du stack Traefik"
  local cwd="${PWD}"
  cd "${STACK_DIR}"
  run_cmd docker compose pull
  run_cmd docker compose up -d
  cd "${cwd}"
}

post_checks() {
  log_info "Vérifications Traefik"
  if ! docker ps --format '{{.Names}}' | grep -q '^traefik$'; then
    fatal "Conteneur Traefik non démarré"
  fi
  log_success "Traefik opérationnel. Consultez https://traefik.${TRAEFIK_DOMAIN}/"
}

main() {
  create_static_config
  create_dynamic_config
  create_compose
  protect_files
  deploy_stack
  post_checks
}

main "$@"
