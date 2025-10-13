#!/usr/bin/env bash
# shellcheck disable=SC2034

set -euo pipefail

# --- Couleurs ---
if command -v tput >/dev/null 2>&1 && [[ -t 1 ]]; then
  _c_reset="$(tput sgr0)"
  _c_blue="$(tput setaf 4)"
  _c_green="$(tput setaf 2)"
  _c_yellow="$(tput setaf 3)"
  _c_red="$(tput setaf 1)"
  _c_magenta="$(tput setaf 5)"
else
  _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
fi

# --- Variables globales par défaut ---
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
VERBOSE=${VERBOSE:-0}
QUIET=${QUIET:-0}
NO_COLOR=${NO_COLOR:-0}
SHOW_HELP=0
COMMON_POSITIONAL_ARGS=()

if [[ "${NO_COLOR}" -eq 1 ]]; then
  _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
fi

# --- Fonctions de log ---
log_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
  [[ ${QUIET} -eq 1 ]] && return 0
  printf '%s %sℹ%s %s\n' "$(log_ts)" "${_c_blue}" "${_c_reset}" "$*"
}

log_warn() {
  printf '%s %s⚠%s %s\n' "$(log_ts)" "${_c_yellow}" "${_c_reset}" "$*" >&2
}

log_error() {
  printf '%s %s✖%s %s\n' "$(log_ts)" "${_c_red}" "${_c_reset}" "$*" >&2
}

log_success() {
  [[ ${QUIET} -eq 1 ]] && return 0
  printf '%s %s✔%s %s\n' "$(log_ts)" "${_c_green}" "${_c_reset}" "$*"
}

log_debug() {
  [[ ${VERBOSE} -lt 1 ]] && return 0
  printf '%s %s◎%s %s\n' "$(log_ts)" "${_c_magenta}" "${_c_reset}" "$*"
}

fatal() {
  log_error "$*"
  exit 1
}

# --- Parsing des options communes ---
parse_common_args() {
  COMMON_POSITIONAL_ARGS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      --yes|-y)
        ASSUME_YES=1
        ;;
      --verbose|-v)
        VERBOSE=$((VERBOSE + 1))
        ;;
      --quiet|-q)
        QUIET=1
        ;;
      --no-color)
        NO_COLOR=1
        _c_reset=""; _c_blue=""; _c_green=""; _c_yellow=""; _c_red=""; _c_magenta=""
        ;;
      --help|-h)
        SHOW_HELP=1
        ;;
      --)
        shift
        COMMON_POSITIONAL_ARGS+=("$@")
        break
        ;;
      -*)
        fatal "Option inconnue: $1"
        ;;
      *)
        COMMON_POSITIONAL_ARGS+=("$1")
        ;;
    esac
    shift || true
  done
}

require_root() {
  if [[ $(id -u) -ne 0 ]]; then
    fatal "Ce script doit être exécuté en root (utilisez sudo)."
  fi
}

confirm() {
  local prompt=${1:-"Continuer ?"}
  if [[ ${ASSUME_YES} -eq 1 ]]; then
    log_debug "Confirmation automatique (--yes) pour: ${prompt}"
    return 0
  fi

  read -r -p "${prompt} [y/N]: " response
  case "${response}" in
    [yY][eE][sS]|[yY])
      return 0
      ;;
    *)
      log_error "Opération annulée."
      exit 1
      ;;
  esac
}

run_cmd() {
  local cmd=("$@")
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] ${cmd[*]}"
    return 0
  fi

  log_debug "Exécution: ${cmd[*]}"
  "${cmd[@]}"
}

run_cmd_sudo() {
  local cmd=("$@")
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] sudo ${cmd[*]}"
    return 0
  fi
  log_debug "Exécution sudo: ${cmd[*]}"
  sudo "${cmd[@]}"
}

check_command() {
  local name=$1
  if ! command -v "${name}" >/dev/null 2>&1; then
    fatal "Commande requise introuvable: ${name}"
  fi
}

retry() {
  local attempts=$1; shift
  local delay=${1:-5}; shift || true
  local cmd=("$@")
  local count=0
  until "${cmd[@]}"; do
    count=$((count + 1))
    if (( count >= attempts )); then
      fatal "Commande échouée après ${attempts} tentatives: ${cmd[*]}"
    fi
    log_warn "Tentative ${count}/${attempts} échouée. Nouvelle tentative dans ${delay}s..."
    sleep "${delay}"
  done
}

detect_os() {
  awk -F= '/^ID=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"'
}

detect_pretty_os() {
  awk -F= '/^PRETTY_NAME=/{print $2}' /etc/os-release 2>/dev/null | tr -d '"'
}

detect_arch() {
  uname -m
}

ensure_dir() {
  local dir=$1
  if [[ ! -d ${dir} ]]; then
    run_cmd mkdir -p "${dir}"
  fi
}

# ============================================================================
# DEPLOYMENT UTILITIES (Remote Operations)
# ============================================================================
# Fonctions pour déploiement intelligent et idempotent d'applications
# Extraites de certidoc-proof/deployment-pi/DEPLOY-TO-PI.sh
# ============================================================================

# Vérifier la connexion SSH vers un hôte distant
# Usage: check_ssh_connection "user@host" || exit 1
check_ssh_connection() {
  local host="$1"
  local timeout="${2:-5}"

  log_info "Vérification de la connexion SSH vers $host..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] SSH connection check"
    return 0
  fi

  if ssh -o ConnectTimeout="$timeout" -o BatchMode=yes "$host" "echo 'Connected'" > /dev/null 2>&1; then
    log_success "Connexion SSH établie"
    return 0
  else
    log_error "Impossible de se connecter à $host"
    log_info "Vérifiez que:"
    log_info "  - Le serveur est allumé"
    log_info "  - Vous êtes sur le même réseau"
    log_info "  - SSH est activé sur le serveur"
    log_info "  - Les clés SSH sont configurées (ssh-copy-id $host)"
    return 1
  fi
}

# Vérifier si Docker est installé sur un hôte distant
# Usage: check_remote_docker "user@host" || exit 1
check_remote_docker() {
  local host="$1"

  log_info "Vérification de Docker sur le serveur distant..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Docker check"
    return 0
  fi

  if ssh "$host" "command -v docker &> /dev/null"; then
    local docker_version
    docker_version=$(ssh "$host" "docker --version")
    log_success "Docker installé: $docker_version"
    return 0
  else
    log_error "Docker n'est pas installé sur le serveur distant"
    log_info "Installez Docker: curl -fsSL https://get.docker.com | sh"
    return 1
  fi
}

# Vérifier si un port est disponible sur un hôte distant (idempotent)
# Retourne 0 si le port est libre OU utilisé par Docker (notre conteneur)
# Usage: check_port_available "user@host" 9000 || exit 1
check_port_available() {
  local host="$1"
  local port="$2"

  log_info "Vérification du port $port sur le serveur distant..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Port check: $port"
    return 0
  fi

  if ssh "$host" "sudo netstat -tlnp 2>/dev/null | grep -q ':$port '" || \
     ssh "$host" "command -v ss &>/dev/null && sudo ss -tlnp 2>/dev/null | grep -q ':$port '"; then

    local process
    process=$(ssh "$host" "sudo netstat -tlnp 2>/dev/null | grep ':$port ' | awk '{print \$7}' || sudo ss -tlnp 2>/dev/null | grep ':$port ' | grep -oP 'users:\\(\\(\"[^\"]+\"' | cut -d'\"' -f2")

    log_warn "Port $port est déjà utilisé par: ${process:-unknown}"

    # Vérifier si c'est notre conteneur Docker (idempotent)
    if echo "$process" | grep -q "docker"; then
      log_info "Le port est utilisé par Docker (probablement notre conteneur)"
      return 0
    fi
    return 1
  else
    log_success "Port $port disponible"
    return 0
  fi
}

# Trouver un port disponible sur un hôte distant
# Usage: APP_PORT=$(find_available_port "user@host" 9000 9100)
find_available_port() {
  local host="$1"
  local start_port="${2:-9000}"
  local end_port="${3:-9100}"

  log_info "Recherche d'un port disponible entre $start_port et $end_port..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Port detection: returning $start_port"
    echo "$start_port"
    return 0
  fi

  for port in $(seq "$start_port" "$end_port"); do
    if ! ssh "$host" "sudo netstat -tlnp 2>/dev/null | grep -q ':$port '" && \
       ! ssh "$host" "command -v ss &>/dev/null && sudo ss -tlnp 2>/dev/null | grep -q ':$port '"; then
      log_success "Port disponible trouvé: $port"
      echo "$port"
      return 0
    fi
  done

  log_error "Aucun port disponible trouvé entre $start_port et $end_port"
  return 1
}

# Créer un répertoire distant (idempotent)
# Usage: create_remote_dir "user@host" "/path/to/dir" || exit 1
create_remote_dir() {
  local host="$1"
  local dir="$2"

  log_info "Création du répertoire distant: $dir"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] mkdir -p $dir"
    return 0
  fi

  if ssh "$host" "[ -d $dir ]"; then
    log_debug "Répertoire existe déjà: $dir"
    log_success "Répertoire prêt: $dir"
    return 0
  fi

  if ssh "$host" "mkdir -p $dir"; then
    log_success "Répertoire créé: $dir"
    return 0
  else
    log_error "Impossible de créer le répertoire: $dir"
    return 1
  fi
}

# Copier un fichier vers un hôte distant (idempotent avec vérification checksum)
# Usage: smart_copy_file "local/file.txt" "user@host" "/remote/dir" || log_warn "Copy failed"
smart_copy_file() {
  local src="$1"
  local host="$2"
  local dst="$3"
  local filename
  filename=$(basename "$src")

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] scp $src $host:$dst"
    return 0
  fi

  # Vérifier si le fichier source existe
  if [[ ! -f "$src" ]]; then
    log_warn "Fichier source introuvable: $src"
    return 1
  fi

  # Calculer le checksum local (compatible macOS et Linux)
  local local_checksum
  if command -v md5 &>/dev/null; then
    local_checksum=$(md5 -q "$src" 2>/dev/null)
  elif command -v md5sum &>/dev/null; then
    local_checksum=$(md5sum "$src" | awk '{print $1}')
  else
    log_warn "md5/md5sum non disponible, copie forcée"
    scp -q "$src" "$host:$dst/" && log_success "  ✓ $filename" && return 0
    log_error "Échec de copie: $filename"
    return 1
  fi

  # Vérifier si le fichier distant existe et comparer les checksums
  if ssh "$host" "[ -f $dst/$filename ]"; then
    local remote_checksum
    remote_checksum=$(ssh "$host" "md5sum $dst/$filename 2>/dev/null | awk '{print \$1}'")

    if [[ "$local_checksum" == "$remote_checksum" ]]; then
      log_debug "Fichier identique, copie ignorée: $filename"
      return 0
    else
      log_debug "Fichier modifié, copie nécessaire: $filename"
    fi
  fi

  # Copier le fichier
  if scp -q "$src" "$host:$dst/"; then
    log_success "  ✓ $filename"
    return 0
  else
    log_error "Échec de copie: $filename"
    return 1
  fi
}

# Copier un dossier vers un hôte distant (idempotent avec rsync)
# Usage: smart_copy_dir "local/dir" "user@host" "/remote/parent" || exit 1
smart_copy_dir() {
  local src="$1"
  local host="$2"
  local dst="$3"
  local dirname
  dirname=$(basename "$src")

  log_info "Synchronisation du dossier: $dirname"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] rsync $src $host:$dst"
    return 0
  fi

  if [[ ! -d "$src" ]]; then
    log_warn "Dossier source introuvable: $src"
    return 1
  fi

  # Utiliser rsync pour une synchronisation intelligente (idempotent)
  if rsync -az --delete \
      --exclude='node_modules' \
      --exclude='dist' \
      --exclude='build' \
      --exclude='.git' \
      --exclude='.env.local' \
      --exclude='.DS_Store' \
      "$src" "$host:$dst/" 2>&1 | grep -v "^$"; then
    log_success "  ✓ $dirname"
    return 0
  else
    log_error "Échec de synchronisation: $dirname"
    return 1
  fi
}

# Créer un fichier .env distant de manière robuste (idempotent)
# Usage: create_remote_env_file "user@host" "/remote/dir" "KEY1=value1" "KEY2=value2"
create_remote_env_file() {
  local host="$1"
  local dir="$2"
  shift 2
  local env_vars=("$@")

  log_info "Création/mise à jour du fichier .env distant..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Create .env with ${#env_vars[@]} variables"
    return 0
  fi

  # Générer le contenu du .env
  local env_content=""
  for var in "${env_vars[@]}"; do
    env_content="${env_content}${var}"$'\n'
  done

  # Vérifier si le .env existe déjà et est identique
  local needs_update=false

  if ssh "$host" "[ -f $dir/.env ]"; then
    local remote_checksum
    remote_checksum=$(ssh "$host" "md5sum $dir/.env 2>/dev/null | awk '{print \$1}'")
    local local_checksum
    local_checksum=$(echo -n "$env_content" | md5sum | awk '{print $1}')

    if [[ "$remote_checksum" != "$local_checksum" ]]; then
      needs_update=true
      log_debug "Configuration modifiée, mise à jour nécessaire"
    else
      log_debug "Configuration identique, pas de mise à jour nécessaire"
    fi
  else
    needs_update=true
    log_debug "Fichier .env absent, création nécessaire"
  fi

  if [[ "$needs_update" == "true" ]]; then
    # Créer le fichier .env sur le serveur distant (méthode robuste)
    if ssh "$host" bash <<ENVSCRIPT
set -e
cd $dir
cat > .env.tmp <<'ENVEOF'
$env_content
ENVEOF
chmod 600 .env.tmp
mv .env.tmp .env
ENVSCRIPT
    then
      log_success "Fichier .env créé/mis à jour"
    else
      log_error "Échec de la création du fichier .env"
      return 1
    fi

    # Vérification finale
    if ! ssh "$host" "[ -f $dir/.env ] && [ -s $dir/.env ]"; then
      log_error "Le fichier .env n'a pas été créé correctement"
      return 1
    fi
  else
    log_success "Fichier .env déjà à jour"
  fi

  return 0
}

# Vérifier si un réseau Docker existe sur un hôte distant
# Usage: check_docker_network "user@host" "supabase_network" || exit 1
check_docker_network() {
  local host="$1"
  local network="$2"

  log_info "Vérification du réseau Docker: $network"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Docker network check: $network"
    return 0
  fi

  if ssh "$host" "docker network ls | grep -q '$network'"; then
    log_success "Réseau Docker trouvé: $network"
    return 0
  else
    log_error "Réseau Docker introuvable: $network"
    log_info "Vérifiez les réseaux disponibles: docker network ls"
    return 1
  fi
}

# Détecter les fichiers de configuration de build (Vite/React/Next.js)
# Usage: detect_build_config_files "/path/to/project"
# Retourne: tableau des fichiers trouvés
detect_build_config_files() {
  local project_dir="$1"
  local found_files=()

  log_info "Détection des fichiers de configuration de build..."

  # Liste des fichiers de configuration communs
  local config_files=(
    "package.json"
    "package-lock.json"
    "tsconfig.json"
    "tsconfig.app.json"
    "tsconfig.node.json"
    "vite.config.ts"
    "vite.config.js"
    "tailwind.config.ts"
    "tailwind.config.js"
    "postcss.config.js"
    "postcss.config.cjs"
    "components.json"
    "next.config.js"
    "next.config.mjs"
    ".babelrc"
    ".eslintrc"
    ".prettierrc"
  )

  for file in "${config_files[@]}"; do
    if [[ -f "$project_dir/$file" ]]; then
      found_files+=("$file")
      log_debug "  ✓ $file"
    fi
  done

  if [[ ${#found_files[@]} -eq 0 ]]; then
    log_warn "Aucun fichier de configuration trouvé dans $project_dir"
    return 1
  fi

  log_success "Fichiers de configuration détectés: ${#found_files[@]}"

  # Retourner les fichiers trouvés (un par ligne)
  printf '%s\n' "${found_files[@]}"
  return 0
}

ensure_file_owner() {
  local path=$1 owner=$2
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] chown ${owner} ${path}"
    return 0
  fi
  chown "${owner}" "${path}"
}

register_cleanup() {
  local fn=$1
  CLEANUP_CALLBACKS+=("${fn}")
}

CLEANUP_CALLBACKS=()

_run_cleanup() {
  local status=$?
  if [[ ${#CLEANUP_CALLBACKS[@]} -gt 0 ]]; then
    log_debug "Exécution des ${#CLEANUP_CALLBACKS[@]} hooks de nettoyage"
    for cb in "${CLEANUP_CALLBACKS[@]}"; do
      if declare -f "${cb}" >/dev/null 2>&1; then
        "${cb}" || log_warn "Nettoyage '${cb}' a échoué"
      else
        log_warn "Hook '${cb}' introuvable"
      fi
    done
  fi
  exit ${status}
}

trap _run_cleanup EXIT

export DRY_RUN ASSUME_YES VERBOSE QUIET NO_COLOR SHOW_HELP
