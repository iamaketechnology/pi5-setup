#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: 09-stack-manager.sh [commande] [options]

Gère facilement les stacks Docker installés (start/stop/status/ram).

Commandes:
  status           Affiche l'état de tous les stacks installés
  list             Liste tous les stacks disponibles avec RAM
  start <stack>    Démarre un stack spécifique
  stop <stack>     Arrête un stack spécifique
  restart <stack>  Redémarre un stack spécifique
  enable <stack>   Active démarrage automatique au boot
  disable <stack>  Désactive démarrage automatique au boot
  ram              Affiche consommation RAM par stack
  interactive      Mode interactif (TUI)

Exemples:
  # Voir l'état de tous les stacks
  sudo ./09-stack-manager.sh status

  # Arrêter Jellyfin pour libérer RAM
  sudo ./09-stack-manager.sh stop jellyfin

  # Démarrer Supabase
  sudo ./09-stack-manager.sh start supabase

  # Mode interactif (recommandé)
  sudo ./09-stack-manager.sh interactive

Options:
  --dry-run        Simule
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

# Dossier base des stacks
STACKS_BASE_DIR="${STACKS_BASE_DIR:-/home/pi/stacks}"

# Detect all installed stacks
detect_installed_stacks() {
  local -a stacks=()

  if [[ -d "${STACKS_BASE_DIR}/supabase" ]]; then
    stacks+=("supabase")
  fi
  if [[ -d "${STACKS_BASE_DIR}/traefik" ]]; then
    stacks+=("traefik")
  fi
  if [[ -d "${STACKS_BASE_DIR}/homepage" ]]; then
    stacks+=("homepage")
  fi
  if [[ -d "${STACKS_BASE_DIR}/monitoring" ]]; then
    stacks+=("monitoring")
  fi
  if [[ -d "${STACKS_BASE_DIR}/gitea" ]]; then
    stacks+=("gitea")
  fi
  if [[ -d "${STACKS_BASE_DIR}/storage" ]]; then
    stacks+=("storage")
  fi
  if [[ -d "${STACKS_BASE_DIR}/nextcloud" ]]; then
    stacks+=("nextcloud")
  fi
  if [[ -d "${STACKS_BASE_DIR}/jellyfin" ]]; then
    stacks+=("jellyfin")
  fi
  if [[ -d "${STACKS_BASE_DIR}/arr-stack" ]]; then
    stacks+=("arr-stack")
  fi
  if [[ -d "${STACKS_BASE_DIR}/authelia" ]]; then
    stacks+=("authelia")
  fi
  if [[ -d "/home/pi/portainer" ]]; then
    stacks+=("portainer")
  fi

  echo "${stacks[@]}"
}

# Get stack directory
get_stack_dir() {
  local stack=$1
  if [[ "${stack}" == "portainer" ]]; then
    echo "/home/pi/portainer"
  else
    echo "${STACKS_BASE_DIR}/${stack}"
  fi
}

# Get stack status (running, stopped, partial)
get_stack_status() {
  local stack=$1
  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    echo "not-installed"
    return
  fi

  if [[ ! -f "${stack_dir}/docker-compose.yml" ]] && [[ ! -f "${stack_dir}/docker-compose.yaml" ]]; then
    echo "no-compose"
    return
  fi

  pushd "${stack_dir}" >/dev/null 2>&1 || return

  local total_services running_services
  total_services=$(docker compose ps -a --format json 2>/dev/null | jq -s 'length' 2>/dev/null || echo 0)
  running_services=$(docker compose ps --format json 2>/dev/null | jq -s '[.[] | select(.State == "running")] | length' 2>/dev/null || echo 0)

  popd >/dev/null 2>&1 || true

  if [[ ${total_services} -eq 0 ]]; then
    echo "stopped"
  elif [[ ${running_services} -eq ${total_services} ]]; then
    echo "running"
  elif [[ ${running_services} -gt 0 ]]; then
    echo "partial"
  else
    echo "stopped"
  fi
}

# Get stack RAM usage (in MB)
get_stack_ram() {
  local stack=$1
  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    echo "0"
    return
  fi

  pushd "${stack_dir}" >/dev/null 2>&1 || return

  local ram_mb
  ram_mb=$(docker compose ps -q 2>/dev/null | xargs docker stats --no-stream --format "{{.MemUsage}}" 2>/dev/null | awk -F'[/ ]' '{
    if ($2 ~ /GiB/) {
      sum += $1 * 1024
    } else if ($2 ~ /MiB/) {
      sum += $1
    } else if ($2 ~ /KiB/) {
      sum += $1 / 1024
    }
  } END {print int(sum)}')

  popd >/dev/null 2>&1 || true

  echo "${ram_mb:-0}"
}

# Get stack container count
get_stack_containers() {
  local stack=$1
  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    echo "0"
    return
  fi

  pushd "${stack_dir}" >/dev/null 2>&1 || return

  local count
  count=$(docker compose ps -q 2>/dev/null | wc -l | tr -d ' ')

  popd >/dev/null 2>&1 || true

  echo "${count:-0}"
}

# Check if stack is enabled at boot (systemd service)
is_stack_enabled() {
  local stack=$1

  # Check if systemd service exists
  if systemctl list-unit-files 2>/dev/null | grep -q "docker-compose-${stack}.service"; then
    if systemctl is-enabled "docker-compose-${stack}.service" 2>/dev/null | grep -q "enabled"; then
      echo "enabled"
      return
    fi
  fi

  echo "disabled"
}

# Command: status
cmd_status() {
  log_info "État des stacks Docker installés:"
  echo ""

  local stacks
  read -ra stacks <<< "$(detect_installed_stacks)"

  if [[ ${#stacks[@]} -eq 0 ]]; then
    log_warn "Aucun stack installé trouvé dans ${STACKS_BASE_DIR}"
    return
  fi

  printf "%-15s %-12s %-10s %-8s %-10s\n" "STACK" "STATUS" "CONTAINERS" "RAM (MB)" "BOOT"
  printf "%-15s %-12s %-10s %-8s %-10s\n" "─────" "──────" "──────────" "────────" "────"

  local total_ram=0
  for stack in "${stacks[@]}"; do
    local status containers ram boot
    status=$(get_stack_status "${stack}")
    containers=$(get_stack_containers "${stack}")
    ram=$(get_stack_ram "${stack}")
    boot=$(is_stack_enabled "${stack}")

    total_ram=$((total_ram + ram))

    local status_symbol
    case "${status}" in
      running)  status_symbol="${GREEN}✓ running${NC}" ;;
      stopped)  status_symbol="${YELLOW}○ stopped${NC}" ;;
      partial)  status_symbol="${YELLOW}◐ partial${NC}" ;;
      *)        status_symbol="${RED}✗ ${status}${NC}" ;;
    esac

    local boot_symbol
    if [[ "${boot}" == "enabled" ]]; then
      boot_symbol="${GREEN}enabled${NC}"
    else
      boot_symbol="${DIM}disabled${NC}"
    fi

    printf "%-15s %-12b %-10s %-8s %-10b\n" "${stack}" "${status_symbol}" "${containers}" "${ram}" "${boot_symbol}"
  done

  echo ""
  log_info "RAM totale utilisée: ${total_ram} MB"

  # System RAM info
  local total_system_ram used_system_ram available_system_ram
  if command -v free >/dev/null 2>&1; then
    total_system_ram=$(free -m | awk '/^Mem:/ {print $2}')
    used_system_ram=$(free -m | awk '/^Mem:/ {print $3}')
    available_system_ram=$(free -m | awk '/^Mem:/ {print $7}')

    local percent_used=$((used_system_ram * 100 / total_system_ram))
    log_info "RAM système: ${used_system_ram} MB / ${total_system_ram} MB (${percent_used}% utilisé, ${available_system_ram} MB disponible)"
  fi
}

# Command: list
cmd_list() {
  cmd_status
}

# Command: ram
cmd_ram() {
  log_info "Consommation RAM par stack:"
  echo ""

  local stacks
  read -ra stacks <<< "$(detect_installed_stacks)"

  if [[ ${#stacks[@]} -eq 0 ]]; then
    log_warn "Aucun stack installé trouvé"
    return
  fi

  # Array to store stack + RAM for sorting
  declare -A stack_ram_map

  for stack in "${stacks[@]}"; do
    local status ram
    status=$(get_stack_status "${stack}")

    if [[ "${status}" == "running" ]] || [[ "${status}" == "partial" ]]; then
      ram=$(get_stack_ram "${stack}")
      stack_ram_map["${stack}"]=${ram}
    fi
  done

  # Sort by RAM (descending)
  for stack in $(for k in "${!stack_ram_map[@]}"; do echo "$k ${stack_ram_map[$k]}"; done | sort -k2 -rn | awk '{print $1}'); do
    local ram=${stack_ram_map[${stack}]}
    printf "%-20s %8s MB\n" "${stack}" "${ram}"
  done
}

# Command: start
cmd_start() {
  local stack=$1

  if [[ -z "${stack}" ]]; then
    fatal "Usage: $0 start <stack>"
  fi

  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    fatal "Stack '${stack}' non trouvé (${stack_dir})"
  fi

  log_info "Démarrage stack '${stack}'..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] docker compose -f ${stack_dir}/docker-compose.yml up -d"
    return
  fi

  pushd "${stack_dir}" >/dev/null || fatal "Impossible d'accéder à ${stack_dir}"

  run_cmd docker compose up -d

  popd >/dev/null || true

  log_success "Stack '${stack}' démarré"

  # Show new RAM usage
  sleep 2
  local ram
  ram=$(get_stack_ram "${stack}")
  log_info "RAM utilisée: ${ram} MB"
}

# Command: stop
cmd_stop() {
  local stack=$1

  if [[ -z "${stack}" ]]; then
    fatal "Usage: $0 stop <stack>"
  fi

  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    fatal "Stack '${stack}' non trouvé (${stack_dir})"
  fi

  log_info "Arrêt stack '${stack}'..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] docker compose -f ${stack_dir}/docker-compose.yml down"
    return
  fi

  pushd "${stack_dir}" >/dev/null || fatal "Impossible d'accéder à ${stack_dir}"

  run_cmd docker compose down

  popd >/dev/null || true

  log_success "Stack '${stack}' arrêté"
}

# Command: restart
cmd_restart() {
  local stack=$1

  if [[ -z "${stack}" ]]; then
    fatal "Usage: $0 restart <stack>"
  fi

  cmd_stop "${stack}"
  sleep 1
  cmd_start "${stack}"
}

# Command: enable (boot)
cmd_enable() {
  local stack=$1

  if [[ -z "${stack}" ]]; then
    fatal "Usage: $0 enable <stack>"
  fi

  local stack_dir
  stack_dir=$(get_stack_dir "${stack}")

  if [[ ! -d "${stack_dir}" ]]; then
    fatal "Stack '${stack}' non trouvé (${stack_dir})"
  fi

  log_info "Création service systemd pour '${stack}'..."

  local service_file="/etc/systemd/system/docker-compose-${stack}.service"

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Création ${service_file}"
    return
  fi

  cat > "${service_file}" <<SERVICE
[Unit]
Description=Docker Compose for ${stack}
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${stack_dir}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
SERVICE

  run_cmd systemctl daemon-reload
  run_cmd systemctl enable "docker-compose-${stack}.service"

  log_success "Stack '${stack}' activé au démarrage"
}

# Command: disable (boot)
cmd_disable() {
  local stack=$1

  if [[ -z "${stack}" ]]; then
    fatal "Usage: $0 disable <stack>"
  fi

  local service_file="/etc/systemd/system/docker-compose-${stack}.service"

  if [[ ! -f "${service_file}" ]]; then
    log_warn "Service systemd pour '${stack}' non trouvé"
    return
  fi

  log_info "Désactivation démarrage auto pour '${stack}'..."

  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] systemctl disable docker-compose-${stack}.service"
    return
  fi

  run_cmd systemctl disable "docker-compose-${stack}.service"

  log_success "Stack '${stack}' désactivé au démarrage"
}

# Command: interactive (TUI mode)
cmd_interactive() {
  if ! command -v whiptail >/dev/null 2>&1 && ! command -v dialog >/dev/null 2>&1; then
    log_warn "whiptail ou dialog non installé, installation..."
    apt-get update >/dev/null 2>&1
    apt-get install -y whiptail >/dev/null 2>&1
  fi

  local DIALOG_CMD="whiptail"
  if ! command -v whiptail >/dev/null 2>&1; then
    DIALOG_CMD="dialog"
  fi

  while true; do
    local stacks
    read -ra stacks <<< "$(detect_installed_stacks)"

    if [[ ${#stacks[@]} -eq 0 ]]; then
      ${DIALOG_CMD} --title "Stack Manager" --msgbox "Aucun stack installé trouvé" 8 50
      return
    fi

    # Build menu items
    local menu_items=()
    for stack in "${stacks[@]}"; do
      local status
      status=$(get_stack_status "${stack}")
      local status_text
      case "${status}" in
        running)  status_text="[RUNNING]" ;;
        stopped)  status_text="[STOPPED]" ;;
        partial)  status_text="[PARTIAL]" ;;
        *)        status_text="[${status}]" ;;
      esac
      menu_items+=("${stack}" "${status_text}")
    done

    menu_items+=("" "")
    menu_items+=("ram" "Voir consommation RAM")
    menu_items+=("status" "Voir état détaillé")
    menu_items+=("quit" "Quitter")

    local choice
    choice=$(${DIALOG_CMD} --title "Stack Manager" --menu "Choisir un stack:" 20 60 12 "${menu_items[@]}" 3>&1 1>&2 2>&3) || break

    if [[ "${choice}" == "quit" ]]; then
      break
    elif [[ "${choice}" == "ram" ]]; then
      local ram_output
      ram_output=$(cmd_ram 2>&1 | head -20)
      ${DIALOG_CMD} --title "Consommation RAM" --msgbox "${ram_output}" 20 60
    elif [[ "${choice}" == "status" ]]; then
      local status_output
      status_output=$(cmd_status 2>&1 | head -30)
      ${DIALOG_CMD} --title "État des Stacks" --msgbox "${status_output}" 25 80
    elif [[ -n "${choice}" ]]; then
      # Stack selected, show actions
      local stack_status
      stack_status=$(get_stack_status "${choice}")

      local action_items=()
      if [[ "${stack_status}" == "running" ]] || [[ "${stack_status}" == "partial" ]]; then
        action_items+=("stop" "Arrêter le stack")
        action_items+=("restart" "Redémarrer le stack")
      else
        action_items+=("start" "Démarrer le stack")
      fi

      local boot_status
      boot_status=$(is_stack_enabled "${choice}")
      if [[ "${boot_status}" == "enabled" ]]; then
        action_items+=("disable" "Désactiver démarrage auto")
      else
        action_items+=("enable" "Activer démarrage auto")
      fi

      action_items+=("back" "Retour")

      local action
      action=$(${DIALOG_CMD} --title "${choice} - ${stack_status}" --menu "Action:" 15 60 6 "${action_items[@]}" 3>&1 1>&2 2>&3) || continue

      case "${action}" in
        start)
          cmd_start "${choice}" 2>&1 | tail -5 > /tmp/stack-manager-output.txt
          ${DIALOG_CMD} --title "Résultat" --textbox /tmp/stack-manager-output.txt 10 60
          ;;
        stop)
          cmd_stop "${choice}" 2>&1 | tail -5 > /tmp/stack-manager-output.txt
          ${DIALOG_CMD} --title "Résultat" --textbox /tmp/stack-manager-output.txt 10 60
          ;;
        restart)
          cmd_restart "${choice}" 2>&1 | tail -10 > /tmp/stack-manager-output.txt
          ${DIALOG_CMD} --title "Résultat" --textbox /tmp/stack-manager-output.txt 15 60
          ;;
        enable)
          cmd_enable "${choice}" 2>&1 | tail -5 > /tmp/stack-manager-output.txt
          ${DIALOG_CMD} --title "Résultat" --textbox /tmp/stack-manager-output.txt 10 60
          ;;
        disable)
          cmd_disable "${choice}" 2>&1 | tail -5 > /tmp/stack-manager-output.txt
          ${DIALOG_CMD} --title "Résultat" --textbox /tmp/stack-manager-output.txt 10 60
          ;;
        back)
          continue
          ;;
      esac
    fi
  done

  clear
  log_success "Stack Manager terminé"
}

# Main logic
COMMAND="${1:-status}"

case "${COMMAND}" in
  status)
    cmd_status
    ;;
  list)
    cmd_list
    ;;
  ram)
    cmd_ram
    ;;
  start)
    shift
    cmd_start "$@"
    ;;
  stop)
    shift
    cmd_stop "$@"
    ;;
  restart)
    shift
    cmd_restart "$@"
    ;;
  enable)
    shift
    cmd_enable "$@"
    ;;
  disable)
    shift
    cmd_disable "$@"
    ;;
  interactive)
    cmd_interactive
    ;;
  *)
    fatal "Commande inconnue: ${COMMAND}. Utilisez --help pour voir les commandes disponibles."
    ;;
esac
