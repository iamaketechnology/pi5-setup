#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: onboard-app.sh [options]

Prépare un nouveau service docker compose avec reverse proxy Traefik.

Variables/Options:
  --name NAME            Nom du service (obligatoire)
  --domain host.example  Domaine/sous-domaine (obligatoire)
  --template FILE        Modèle docker-compose (optionnel)
  --output-dir DIR       Répertoire cible (défaut: ~/stacks/<name>)
  --port 3000            Port interne exposé par le service (défaut: 3000)
  --dry-run              Simule
  --yes, -y              Confirme
  --verbose, -v          Verbosité
  --quiet, -q            Silencieux
  --no-color             Sans couleurs
  --help, -h             Aide
USAGE
}

NAME=""
DOMAIN=""
TEMPLATE=""
OUTPUT_DIR=""
PORT=3000

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        NAME=$2; shift 2 || fatal "--name requiert un argument"
        ;;
      --domain)
        DOMAIN=$2; shift 2 || fatal "--domain requiert un argument"
        ;;
      --template)
        TEMPLATE=$2; shift 2 || fatal "--template requiert un argument"
        ;;
      --output-dir)
        OUTPUT_DIR=$2; shift 2 || fatal "--output-dir requiert un argument"
        ;;
      --port)
        PORT=$2; shift 2 || fatal "--port requiert un argument"
        ;;
      --help|-h)
        SHOW_HELP=1; shift
        ;;
      *)
        COMMON_ARGS+=("$1"); shift
        ;;
    esac
  done
}

COMMON_ARGS=()
parse_common_args "$@"
parse_args "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

[[ -n ${NAME} ]] || fatal "--name requis"
[[ -n ${DOMAIN} ]] || fatal "--domain requis"

if [[ -z ${OUTPUT_DIR} ]]; then
  OUTPUT_DIR="${HOME}/stacks/${NAME}"
fi

ensure_dir "${OUTPUT_DIR}"

create_env_example() {
  local file="${OUTPUT_DIR}/.env.example"
  log_info "Création ${file}"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] écrire ${file}"
    return
  fi
  cat >"${file}" <<ENV
APP_NAME=${NAME}
APP_DOMAIN=${DOMAIN}
PORT=${PORT}
SUPABASE_URL=_REPLACE_
SUPABASE_ANON_KEY=_REPLACE_
SUPABASE_SERVICE_ROLE_KEY=_REPLACE_
ENV
}

create_compose_template() {
  local file="${OUTPUT_DIR}/docker-compose.yml"
  if [[ -n ${TEMPLATE} ]]; then
    log_info "Copie template ${TEMPLATE}"
    if [[ ${DRY_RUN} -eq 1 ]]; then
      log_info "[DRY-RUN] cp ${TEMPLATE} ${file}"
      return
    fi
    cp "${TEMPLATE}" "${file}"
    return
  fi
  log_info "Création docker-compose.yml"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] écrire docker-compose"
    return
  fi
  cat >"${file}" <<YAML
version: "3.9"

services:
  ${NAME}:
    image: ghcr.io/example/${NAME}:latest
    env_file: .env
    restart: unless-stopped
    ports:
      - "${PORT}:${PORT}"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.${NAME}.rule=Host(\"${DOMAIN}\")"
      - "traefik.http.routers.${NAME}.entrypoints=websecure"
      - "traefik.http.routers.${NAME}.tls.certresolver=letsencrypt"
      - "traefik.http.services.${NAME}.loadbalancer.server.port=${PORT}"
YAML
}

create_readme() {
  local file="${OUTPUT_DIR}/README.md"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] écrire README"
    return
  fi
  cat >"${file}" <<'DOC'
# Onboarding Service

## Étapes

1. Copier `.env.example` vers `.env` et remplir les valeurs.
2. Déployer via `docker compose up -d`.
3. Vérifier Traefik / certificats.
4. Configurer les backups/healthchecks si nécessaire.
DOC
}

main() {
  create_compose_template
  create_env_example
  create_readme
  log_success "Service ${NAME} initialisé dans ${OUTPUT_DIR}"
}

main "$@"
