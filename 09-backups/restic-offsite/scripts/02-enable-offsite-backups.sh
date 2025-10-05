#!/usr/bin/env bash

set -euo pipefail

# === Phase 6 - Enable Offsite Backups ===
# Ce script configure les sauvegardes offsite via rclone pour les stacks installées

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../../" && pwd)"
COMMON_SCRIPTS_DIR="${ROOT_DIR}/common-scripts"

source "${COMMON_SCRIPTS_DIR}/lib.sh"

# === VARIABLES GLOBALES ===
SCRIPT_VERSION="1.0.0"
LOG_FILE="/var/log/pi5-offsite-backups-$(date +%Y%m%d_%H%M%S).log"
RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
SELECTED_STACK="${SELECTED_STACK:-}"
RCLONE_REMOTE="${RCLONE_REMOTE:-}"
TEST_BACKUP="${TEST_BACKUP:-}"
BACKUP_SUMMARY=()

# === DÉTECTION DES STACKS ===
declare -A STACK_INFO=(
    ["supabase"]="/home/${SUDO_USER:-$USER}/stacks/supabase"
    ["gitea"]="/home/${SUDO_USER:-$USER}/stacks/gitea"
    ["nextcloud"]="/home/${SUDO_USER:-$USER}/stacks/nextcloud"
)

declare -A STACK_SCHEDULER=(
    ["supabase"]="/etc/systemd/system/pi5-supabase-backup.service"
    ["gitea"]="/etc/systemd/system/pi5-gitea-backup.service"
    ["nextcloud"]="/etc/systemd/system/pi5-nextcloud-backup.service"
)

declare -A STACK_BACKUP_SCRIPT=(
    ["supabase"]="${ROOT_DIR}/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh"
    ["gitea"]="${ROOT_DIR}/pi5-gitea-stack/scripts/maintenance/gitea-backup.sh"
    ["nextcloud"]="${ROOT_DIR}/pi5-nextcloud-stack/scripts/maintenance/nextcloud-backup.sh"
)

# === FONCTIONS UTILITAIRES ===

usage() {
  cat <<'USAGE'
Usage: 02-enable-offsite-backups.sh [options]

Configure les sauvegardes offsite via rclone pour les stacks Pi5 installées.

Variables d'environnement:
  SELECTED_STACK      Stack à configurer (supabase, gitea, nextcloud, all)
  RCLONE_REMOTE       Remote rclone au format remote:bucket/path
  TEST_BACKUP         yes/no - Tester la sauvegarde immédiatement (défaut: ask)

Options:
  --dry-run           Simule les modifications
  --yes, -y           Confirme automatiquement
  --verbose, -v       Mode verbeux
  --quiet, -q         Mode silencieux
  --no-color          Sans couleurs
  --help, -h          Affiche cette aide
  --stack=NAME        Stack à configurer (supabase, gitea, nextcloud, all)
  --remote=REMOTE     Remote rclone (ex: r2:my-backups/supabase)
  --test              Teste la sauvegarde après configuration

Exemples:
  # Mode interactif
  sudo ./02-enable-offsite-backups.sh

  # Configuration automatique Supabase vers Cloudflare R2
  sudo RCLONE_REMOTE=r2:my-backups/supabase ./02-enable-offsite-backups.sh --yes --stack=supabase

  # Configuration de toutes les stacks
  sudo ./02-enable-offsite-backups.sh --yes --stack=all --remote=r2:backups/pi5

  # Test uniquement (dry-run)
  sudo ./02-enable-offsite-backups.sh --dry-run --stack=supabase --remote=r2:backups/supabase

USAGE
}

setup_logging() {
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)

    log_info "=== Pi5 Offsite Backups Setup - $(date) ==="
    log_info "Version: ${SCRIPT_VERSION}"
    log_info "Log file: ${LOG_FILE}"
}

detect_installed_stacks() {
    log_info "Détection des stacks installées..."
    local installed=()

    for stack in "${!STACK_INFO[@]}"; do
        local stack_dir="${STACK_INFO[$stack]}"
        if [[ -d "$stack_dir" ]]; then
            installed+=("$stack")
            log_success "✓ ${stack} trouvé: ${stack_dir}"
        else
            log_debug "✗ ${stack} non installé"
        fi
    done

    if [[ ${#installed[@]} -eq 0 ]]; then
        fatal "Aucune stack compatible trouvée. Installez d'abord une stack (Supabase, Gitea, etc.)"
    fi

    printf '%s\n' "${installed[@]}"
}

check_rclone() {
    log_info "Vérification rclone..."

    if ! command -v rclone >/dev/null 2>&1; then
        fatal "rclone n'est pas installé. Exécutez d'abord: sudo ./01-rclone-setup.sh"
    fi

    log_success "✓ rclone installé: $(rclone version | head -1)"

    if [[ ! -f "$RCLONE_CONF" ]]; then
        fatal "Configuration rclone introuvable: ${RCLONE_CONF}\nExécutez: rclone config"
    fi

    log_success "✓ Configuration trouvée: ${RCLONE_CONF}"
}

list_rclone_remotes() {
    log_info "Remotes rclone disponibles:"
    local remotes
    mapfile -t remotes < <(rclone listremotes 2>/dev/null || true)

    if [[ ${#remotes[@]} -eq 0 ]]; then
        fatal "Aucun remote rclone configuré.\nExécutez: rclone config"
    fi

    local i=1
    for remote in "${remotes[@]}"; do
        # Afficher le type de remote
        local remote_type=$(rclone config show "${remote%:}" 2>/dev/null | awk '/^type =/{print $3}')
        printf "  %s${_c_green}%d${_c_reset}) %s${_c_blue}%s${_c_reset} (type: %s)\n" "" "$i" "" "${remote}" "${remote_type}"
        ((i++))
    done

    printf '%s\n' "${remotes[@]}"
}

select_stack_interactive() {
    local -a installed
    mapfile -t installed < <(detect_installed_stacks)

    if [[ ${#installed[@]} -eq 1 ]]; then
        SELECTED_STACK="${installed[0]}"
        log_info "Une seule stack détectée: ${SELECTED_STACK}"
        return
    fi

    printf "\n%sStacks disponibles:%s\n" "${_c_blue}" "${_c_reset}"
    local i=1
    for stack in "${installed[@]}"; do
        printf "  %s%d%s) %s\n" "${_c_green}" "$i" "${_c_reset}" "$stack"
        ((i++))
    done
    printf "  %s%d%s) all (configurer toutes les stacks)\n" "${_c_green}" "$i" "${_c_reset}"

    local choice
    read -r -p "Sélectionnez une stack [1-${i}]: " choice

    if [[ "$choice" == "$i" ]]; then
        SELECTED_STACK="all"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice < i )); then
        SELECTED_STACK="${installed[$((choice-1))]}"
    else
        fatal "Choix invalide: $choice"
    fi

    log_success "Stack sélectionnée: ${SELECTED_STACK}"
}

select_remote_interactive() {
    local -a remotes
    mapfile -t remotes < <(list_rclone_remotes)

    printf "\n%sSélection du remote rclone:%s\n" "${_c_blue}" "${_c_reset}"

    local choice
    read -r -p "Numéro du remote [1-${#remotes[@]}]: " choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#remotes[@]} )); then
        fatal "Choix invalide: $choice"
    fi

    local selected_remote="${remotes[$((choice-1))]}"

    # Demander le chemin dans le bucket
    local default_path="pi5-backups"
    if [[ "$SELECTED_STACK" != "all" ]]; then
        default_path="pi5-backups/${SELECTED_STACK}"
    fi

    read -r -p "Chemin dans le bucket [${default_path}]: " bucket_path
    bucket_path="${bucket_path:-$default_path}"

    RCLONE_REMOTE="${selected_remote}${bucket_path}"
    log_success "Remote configuré: ${RCLONE_REMOTE}"
}

backup_service_file() {
    local service_file=$1
    local backup_file="${service_file}.backup.$(date +%Y%m%d_%H%M%S)"

    if [[ -f "$service_file" ]]; then
        if [[ ${DRY_RUN} -eq 1 ]]; then
            log_info "[DRY-RUN] cp ${service_file} ${backup_file}"
        else
            cp "$service_file" "$backup_file"
            log_success "Backup créé: ${backup_file}"
        fi
    fi
}

update_systemd_service() {
    local stack=$1
    local service_file="${STACK_SCHEDULER[$stack]}"
    local remote=$2

    if [[ ! -f "$service_file" ]]; then
        log_warn "Service systemd non trouvé pour ${stack}: ${service_file}"
        log_info "Utilisation probable de cron. Vérifiez /etc/cron.d/"
        return 1
    fi

    log_info "Mise à jour service ${stack}: ${service_file}"

    # Backup du fichier
    backup_service_file "$service_file"

    # Vérifier si RCLONE_REMOTE existe déjà
    if grep -q "Environment=.*RCLONE_REMOTE=" "$service_file"; then
        log_info "RCLONE_REMOTE déjà configuré, mise à jour..."
        if [[ ${DRY_RUN} -eq 1 ]]; then
            log_info "[DRY-RUN] Mise à jour RCLONE_REMOTE=${remote}"
        else
            sed -i "s|Environment=.*RCLONE_REMOTE=.*|Environment=\"RCLONE_REMOTE=${remote}\"|" "$service_file"
        fi
    else
        log_info "Ajout RCLONE_REMOTE au service..."
        if [[ ${DRY_RUN} -eq 1 ]]; then
            log_info "[DRY-RUN] Ajout Environment=\"RCLONE_REMOTE=${remote}\""
        else
            # Ajouter après la ligne [Service]
            sed -i "/^\[Service\]/a Environment=\"RCLONE_REMOTE=${remote}\"" "$service_file"
        fi
    fi

    # Recharger systemd
    if [[ ${DRY_RUN} -eq 0 ]]; then
        systemctl daemon-reload
        log_success "Service ${stack} mis à jour avec succès"
    else
        log_info "[DRY-RUN] systemctl daemon-reload"
    fi

    return 0
}

update_cron_job() {
    local stack=$1
    local remote=$2
    local cron_file="/etc/cron.d/pi5-${stack}-backup"

    if [[ ! -f "$cron_file" ]]; then
        log_warn "Cron job non trouvé: ${cron_file}"
        return 1
    fi

    log_info "Mise à jour cron job ${stack}: ${cron_file}"

    # Backup du fichier
    backup_service_file "$cron_file"

    if [[ ${DRY_RUN} -eq 1 ]]; then
        log_info "[DRY-RUN] Ajout RCLONE_REMOTE=${remote} au cron job"
        return 0
    fi

    # Modifier le cron job pour inclure RCLONE_REMOTE
    sed -i "s|root \(.*\)|root RCLONE_REMOTE='${remote}' \1|" "$cron_file"
    log_success "Cron job ${stack} mis à jour avec succès"
}

configure_stack_offsite() {
    local stack=$1
    local remote=$2

    log_info "Configuration sauvegarde offsite pour ${stack}..."

    # Essayer systemd en premier, puis cron
    if ! update_systemd_service "$stack" "$remote"; then
        update_cron_job "$stack" "$remote" || {
            log_error "Impossible de configurer ${stack} (ni systemd ni cron trouvé)"
            return 1
        }
    fi

    BACKUP_SUMMARY+=("${stack}: ${remote}")
    return 0
}

test_backup_run() {
    local stack=$1
    local remote=$2

    log_info "Test de sauvegarde pour ${stack}..."

    local backup_script="${STACK_BACKUP_SCRIPT[$stack]}"

    if [[ ! -f "$backup_script" ]]; then
        log_warn "Script de backup non trouvé: ${backup_script}"
        return 1
    fi

    log_info "Exécution manuelle de la sauvegarde..."

    if [[ ${DRY_RUN} -eq 1 ]]; then
        log_info "[DRY-RUN] RCLONE_REMOTE='${remote}' ${backup_script}"
        return 0
    fi

    # Exécuter le backup avec RCLONE_REMOTE
    if RCLONE_REMOTE="${remote}" bash "$backup_script"; then
        log_success "✓ Backup ${stack} réussi"

        # Vérifier la présence du fichier dans le remote
        local remote_name="${remote%%:*}"
        local remote_path="${remote#*:}"

        log_info "Vérification des fichiers dans ${remote}..."
        local files
        files=$(rclone ls "${remote}" 2>/dev/null | tail -5 || echo "")

        if [[ -n "$files" ]]; then
            log_success "Fichiers récents dans ${remote}:"
            echo "$files" | while read -r size file; do
                printf "  - %s (%s bytes)\n" "$file" "$size"
            done
        else
            log_warn "Aucun fichier trouvé dans ${remote}"
        fi

        return 0
    else
        log_error "✗ Échec du backup ${stack}"
        return 1
    fi
}

rollback_service() {
    local stack=$1
    local service_file="${STACK_SCHEDULER[$stack]}"
    local backup_file=$(ls -t "${service_file}.backup."* 2>/dev/null | head -1)

    if [[ -n "$backup_file" ]]; then
        log_warn "Rollback du service ${stack}..."
        cp "$backup_file" "$service_file"
        systemctl daemon-reload
        log_success "Service restauré depuis: ${backup_file}"
    fi
}

display_summary() {
    printf "\n%s╔══════════════════════════════════════════════════════════════╗%s\n" "${_c_green}" "${_c_reset}"
    printf "%s║  RÉSUMÉ - Sauvegardes Offsite Configurées                   ║%s\n" "${_c_green}" "${_c_reset}"
    printf "%s╚══════════════════════════════════════════════════════════════╝%s\n\n" "${_c_green}" "${_c_reset}"

    if [[ ${#BACKUP_SUMMARY[@]} -eq 0 ]]; then
        printf "  %sAucune stack configurée%s\n\n" "${_c_yellow}" "${_c_reset}"
        return
    fi

    printf "  %sStacks configurées:%s\n" "${_c_blue}" "${_c_reset}"
    for item in "${BACKUP_SUMMARY[@]}"; do
        printf "    ✓ %s\n" "$item"
    done

    printf "\n  %sCommandes utiles:%s\n" "${_c_blue}" "${_c_reset}"
    printf "    # Vérifier les timers systemd\n"
    printf "    systemctl list-timers | grep pi5\n\n"

    printf "    # Déclencher manuellement un backup\n"
    for item in "${BACKUP_SUMMARY[@]}"; do
        local stack="${item%%:*}"
        printf "    sudo RCLONE_REMOTE='%s' %s\n" "${item#*: }" "${STACK_BACKUP_SCRIPT[$stack]}"
    done

    printf "\n    # Lister les fichiers dans le remote\n"
    for item in "${BACKUP_SUMMARY[@]}"; do
        local remote="${item#*: }"
        printf "    rclone ls '%s'\n" "$remote"
    done

    printf "\n  %sRestauration depuis offsite:%s\n" "${_c_blue}" "${_c_reset}"
    printf "    # Télécharger une sauvegarde\n"
    for item in "${BACKUP_SUMMARY[@]}"; do
        local stack="${item%%:*}"
        local remote="${item#*: }"
        printf "    rclone copy '%s/latest-backup.tar.gz' /tmp/\n" "$remote"
        break  # Un seul exemple
    done

    printf "\n    # Restaurer (voir documentation de la stack)\n"
    printf "    sudo bash restore-script.sh /tmp/latest-backup.tar.gz\n\n"

    printf "  %sDocumentation:%s\n" "${_c_blue}" "${_c_reset}"
    printf "    ${ROOT_DIR}/pi5-backup-offsite-stack/docs/RESTORE.md\n\n"

    printf "  %sLog:%s %s\n\n" "${_c_blue}" "${_c_reset}" "${LOG_FILE}"
}

# === PARSING DES ARGUMENTS ===

parse_script_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --stack=*)
                SELECTED_STACK="${1#*=}"
                ;;
            --remote=*)
                RCLONE_REMOTE="${1#*=}"
                ;;
            --test)
                TEST_BACKUP="yes"
                ;;
            *)
                # Les arguments communs sont gérés par parse_common_args
                ;;
        esac
        shift || true
    done
}

# === MAIN ===

main() {
    parse_common_args "$@"
    parse_script_args "${COMMON_POSITIONAL_ARGS[@]:-}"

    if [[ ${SHOW_HELP} -eq 1 ]]; then
        usage
        exit 0
    fi

    require_root
    setup_logging

    log_info "=== Phase 6: Configuration Sauvegardes Offsite ==="

    # 1. Vérifier rclone
    check_rclone

    # 2. Détecter les stacks
    local -a installed
    mapfile -t installed < <(detect_installed_stacks)

    # 3. Sélection de la stack (si non spécifié)
    if [[ -z "$SELECTED_STACK" ]]; then
        select_stack_interactive
    fi

    # Valider la stack
    if [[ "$SELECTED_STACK" != "all" ]] && [[ ! " ${installed[@]} " =~ " ${SELECTED_STACK} " ]]; then
        fatal "Stack invalide: ${SELECTED_STACK}. Disponibles: ${installed[*]}"
    fi

    # 4. Sélection du remote (si non spécifié)
    if [[ -z "$RCLONE_REMOTE" ]]; then
        select_remote_interactive
    else
        log_info "Remote spécifié: ${RCLONE_REMOTE}"
        # Valider que le remote existe
        local remote_name="${RCLONE_REMOTE%%:*}"
        if ! rclone listremotes | grep -q "^${remote_name}:$"; then
            fatal "Remote rclone introuvable: ${remote_name}"
        fi
    fi

    # 5. Configuration
    if [[ "$SELECTED_STACK" == "all" ]]; then
        log_info "Configuration de toutes les stacks avec ${RCLONE_REMOTE}..."

        for stack in "${installed[@]}"; do
            local stack_remote="${RCLONE_REMOTE}/${stack}"
            configure_stack_offsite "$stack" "$stack_remote" || {
                log_error "Échec configuration ${stack}"
                rollback_service "$stack"
            }
        done
    else
        configure_stack_offsite "$SELECTED_STACK" "$RCLONE_REMOTE" || {
            log_error "Échec configuration ${SELECTED_STACK}"
            rollback_service "$SELECTED_STACK"
            fatal "Configuration échouée"
        }
    fi

    # 6. Test optionnel
    if [[ -z "$TEST_BACKUP" ]] && [[ ${ASSUME_YES} -eq 0 ]]; then
        if confirm "Voulez-vous tester la sauvegarde maintenant ?"; then
            TEST_BACKUP="yes"
        fi
    fi

    if [[ "$TEST_BACKUP" == "yes" ]]; then
        if [[ "$SELECTED_STACK" == "all" ]]; then
            for stack in "${installed[@]}"; do
                local stack_remote="${RCLONE_REMOTE}/${stack}"
                test_backup_run "$stack" "$stack_remote" || log_warn "Test échoué pour ${stack}"
            done
        else
            test_backup_run "$SELECTED_STACK" "$RCLONE_REMOTE" || {
                log_warn "Test échoué, rollback..."
                rollback_service "$SELECTED_STACK"
                fatal "Test de backup échoué"
            }
        fi
    fi

    # 7. Résumé final
    display_summary

    log_success "Configuration des sauvegardes offsite terminée avec succès!"

    if [[ ${DRY_RUN} -eq 0 ]]; then
        log_info "Les prochaines sauvegardes automatiques incluront l'upload vers le remote rclone"
    else
        log_info "[DRY-RUN] Aucune modification réelle effectuée"
    fi
}

main "$@"
