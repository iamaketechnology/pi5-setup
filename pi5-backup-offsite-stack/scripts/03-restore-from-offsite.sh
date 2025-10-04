#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_SCRIPTS_DIR="${SCRIPT_DIR}/../../common-scripts"
source "${COMMON_SCRIPTS_DIR}/lib.sh"

# === Script Metadata ===
SCRIPT_VERSION="1.0.0"
SCRIPT_NAME="03-restore-from-offsite.sh"
LOG_FILE="/var/log/pi5-offsite-restore-$(date +%Y%m%d_%H%M%S).log"

usage() {
  cat <<'USAGE'
Usage: 03-restore-from-offsite.sh [options]

Restaure une sauvegarde depuis un stockage offsite (rclone).

Ce script permet de:
  1. Lister toutes les sauvegardes disponibles sur le remote offsite
  2. Télécharger la sauvegarde sélectionnée
  3. Vérifier l'intégrité de l'archive
  4. Restaurer PostgreSQL et/ou volumes Docker
  5. Vérifier l'état des services après restauration

Variables d'environnement:
  RCLONE_REMOTE          Remote rclone (ex: r2:my-backups/supabase)
  BACKUP_FILE            Nom du fichier à restaurer (optionnel, mode non-interactif)
  RESTORE_TARGET_DIR     Dossier de téléchargement (défaut: /tmp/offsite-restore)
  POSTGRES_DSN           Connexion Postgres pour restauration
  DATA_TARGETS           Chemins de destination volumes (séparés par virgules)
  SERVICE_NAME           Nom du service à redémarrer (défaut: supabase)
  COMPOSE_DIR            Répertoire docker-compose du service
  PRE_RESTORE_BACKUP     Créer backup de sécurité avant restauration (défaut: yes)
  HEALTHCHECK_SCRIPT     Script de healthcheck à exécuter après restauration

Modes de restauration:
  RESTORE_MODE           all|postgres|volumes (défaut: all)
    - all:      Restaure base de données ET volumes
    - postgres: Restaure uniquement la base de données
    - volumes:  Restaure uniquement les volumes Docker

Options:
  --dry-run              Simule sans exécuter (affiche les commandes)
  --yes, -y              Mode automatique (pas de confirmation)
  --verbose, -v          Mode verbeux (affiche détails)
  --quiet, -q            Mode silencieux
  --no-color             Désactive les couleurs
  --list-only            Liste uniquement les backups disponibles (ne restaure pas)
  --skip-backup          Ne pas créer de backup de sécurité avant restauration
  --skip-healthcheck     Ne pas exécuter le healthcheck après restauration
  --help, -h             Affiche cette aide

Exemples:
  # Mode interactif (recommandé pour débutants)
  sudo RCLONE_REMOTE=r2:my-backups/supabase ./03-restore-from-offsite.sh

  # Mode automatique (restauration spécifique)
  sudo RCLONE_REMOTE=r2:my-backups/supabase \
       BACKUP_FILE=supabase-20251004-120000.tar.gz \
       ./03-restore-from-offsite.sh --yes

  # Restaurer uniquement PostgreSQL
  sudo RCLONE_REMOTE=r2:my-backups/supabase \
       RESTORE_MODE=postgres \
       ./03-restore-from-offsite.sh

  # Lister les backups disponibles
  sudo RCLONE_REMOTE=r2:my-backups/supabase \
       ./03-restore-from-offsite.sh --list-only

  # Dry-run (voir ce qui serait fait)
  sudo RCLONE_REMOTE=r2:my-backups/supabase \
       BACKUP_FILE=supabase-20251004-120000.tar.gz \
       ./03-restore-from-offsite.sh --dry-run

Notes de sécurité:
  - Un backup de sécurité est créé automatiquement avant toute restauration
  - Les services sont arrêtés pendant la restauration
  - Une vérification de santé est effectuée après restauration
  - En cas d'échec, le backup de sécurité peut être utilisé pour rollback

USAGE
}

# === Options parsing ===
LIST_ONLY=0
SKIP_BACKUP=0
SKIP_HEALTHCHECK=0

parse_custom_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list-only)
        LIST_ONLY=1
        shift
        ;;
      --skip-backup)
        SKIP_BACKUP=1
        shift
        ;;
      --skip-healthcheck)
        SKIP_HEALTHCHECK=1
        shift
        ;;
      *)
        # Let parse_common_args handle it
        break
        ;;
    esac
  done

  # Parse remaining common args
  parse_common_args "$@"
}

parse_custom_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

require_root

# === Configuration ===
RCLONE_REMOTE=${RCLONE_REMOTE:-}
BACKUP_FILE=${BACKUP_FILE:-}
RESTORE_TARGET_DIR=${RESTORE_TARGET_DIR:-/tmp/offsite-restore}
POSTGRES_DSN=${POSTGRES_DSN:-}
DATA_TARGETS=${DATA_TARGETS:-}
SERVICE_NAME=${SERVICE_NAME:-supabase}
COMPOSE_DIR=${COMPOSE_DIR:-}
PRE_RESTORE_BACKUP=${PRE_RESTORE_BACKUP:-yes}
HEALTHCHECK_SCRIPT=${HEALTHCHECK_SCRIPT:-}
RESTORE_MODE=${RESTORE_MODE:-all}

# === Validation ===
validate_config() {
  log_info "Validation de la configuration..."

  # Vérifier rclone
  if ! command -v rclone >/dev/null 2>&1; then
    fatal "rclone n'est pas installé. Installez-le avec: curl https://rclone.org/install.sh | sudo bash"
  fi

  # Vérifier RCLONE_REMOTE
  if [[ -z ${RCLONE_REMOTE} ]]; then
    fatal "RCLONE_REMOTE est requis. Exemple: RCLONE_REMOTE=r2:my-backups/supabase"
  fi

  # Tester la connexion rclone
  log_info "Test de connexion à ${RCLONE_REMOTE}..."
  if ! rclone lsd "${RCLONE_REMOTE}" >/dev/null 2>&1; then
    fatal "Impossible de se connecter à ${RCLONE_REMOTE}. Vérifiez votre configuration rclone."
  fi
  log_success "Connexion à ${RCLONE_REMOTE} OK"

  # Vérifier mode de restauration
  case "${RESTORE_MODE}" in
    all|postgres|volumes)
      log_debug "Mode de restauration: ${RESTORE_MODE}"
      ;;
    *)
      fatal "RESTORE_MODE invalide: ${RESTORE_MODE}. Valeurs possibles: all, postgres, volumes"
      ;;
  esac

  # Vérifier postgres si nécessaire
  if [[ ${RESTORE_MODE} == "all" || ${RESTORE_MODE} == "postgres" ]]; then
    if [[ -z ${POSTGRES_DSN} ]]; then
      fatal "POSTGRES_DSN est requis pour la restauration de la base de données"
    fi
    if ! command -v pg_restore >/dev/null 2>&1; then
      fatal "pg_restore n'est pas installé. Installez postgresql-client."
    fi
  fi

  # Vérifier docker si nécessaire
  if [[ ${RESTORE_MODE} == "all" || ${RESTORE_MODE} == "volumes" ]]; then
    if ! command -v docker >/dev/null 2>&1; then
      fatal "docker n'est pas installé"
    fi
  fi
}

# === Logging setup ===
setup_logging() {
  exec 1> >(tee -a "${LOG_FILE}")
  exec 2> >(tee -a "${LOG_FILE}" >&2)

  log_info "=== Restauration depuis offsite - $(date) ==="
  log_info "Version: ${SCRIPT_VERSION}"
  log_info "Remote: ${RCLONE_REMOTE}"
  log_info "Mode: ${RESTORE_MODE}"
  log_info "Log file: ${LOG_FILE}"
}

# === List backups ===
list_backups() {
  log_info "Récupération de la liste des sauvegardes depuis ${RCLONE_REMOTE}..."

  local list_file="${RESTORE_TARGET_DIR}/backups-list.txt"
  ensure_dir "${RESTORE_TARGET_DIR}"

  # Liste tous les fichiers .tar.gz
  if ! rclone lsf --files-only "${RCLONE_REMOTE}" | grep '\.tar\.gz$' > "${list_file}"; then
    fatal "Aucune sauvegarde trouvée sur ${RCLONE_REMOTE}"
  fi

  local backup_count=$(wc -l < "${list_file}")
  if [[ ${backup_count} -eq 0 ]]; then
    fatal "Aucune sauvegarde (.tar.gz) trouvée sur ${RCLONE_REMOTE}"
  fi

  log_success "${backup_count} sauvegarde(s) trouvée(s)"
  echo "${list_file}"
}

display_backups() {
  local list_file=$1

  log_info "Sauvegardes disponibles:"
  echo ""
  printf "%-4s %-40s %-12s %-12s %-10s\n" "ID" "FICHIER" "TAILLE" "DATE" "AGE"
  printf "%-4s %-40s %-12s %-12s %-10s\n" "----" "----------------------------------------" "------------" "------------" "----------"

  local idx=1
  local now_epoch=$(date +%s)

  while IFS= read -r filename; do
    # Récupérer la taille du fichier
    local size_bytes=$(rclone size --json "${RCLONE_REMOTE}/${filename}" 2>/dev/null | grep -o '"bytes":[0-9]*' | cut -d':' -f2 || echo "0")
    local size_mb=$((size_bytes / 1024 / 1024))
    local size_display="${size_mb}MB"

    # Extraire la date du nom de fichier (format: prefix-YYYYMMDD-HHMMSS.tar.gz)
    local datepart=""
    if [[ ${filename} =~ -([0-9]{8})-([0-9]{6})\.tar\.gz$ ]]; then
      local datestamp="${BASH_REMATCH[1]}"
      local timestamp="${BASH_REMATCH[2]}"
      datepart="${datestamp:0:4}-${datestamp:4:2}-${datestamp:6:2}"

      # Calculer l'âge
      local file_epoch=$(date -d "${datepart}" +%s 2>/dev/null || echo "0")
      if [[ ${file_epoch} -gt 0 ]]; then
        local age_seconds=$((now_epoch - file_epoch))
        local age_days=$((age_seconds / 86400))
        local age_display="${age_days}j"

        if [[ ${age_days} -eq 0 ]]; then
          local age_hours=$((age_seconds / 3600))
          age_display="${age_hours}h"
        fi
      else
        age_display="N/A"
      fi
    else
      datepart="N/A"
      age_display="N/A"
    fi

    printf "%-4s %-40s %-12s %-12s %-10s\n" "${idx}" "${filename}" "${size_display}" "${datepart}" "${age_display}"
    ((idx++))
  done < "${list_file}"

  echo ""
}

select_backup() {
  local list_file=$1

  # Si BACKUP_FILE est défini, l'utiliser
  if [[ -n ${BACKUP_FILE} ]]; then
    if grep -q "^${BACKUP_FILE}$" "${list_file}"; then
      log_info "Utilisation du backup spécifié: ${BACKUP_FILE}"
      echo "${BACKUP_FILE}"
      return 0
    else
      fatal "Le fichier ${BACKUP_FILE} n'existe pas dans ${RCLONE_REMOTE}"
    fi
  fi

  # Mode interactif
  local backup_count=$(wc -l < "${list_file}")

  echo ""
  read -r -p "Sélectionnez le numéro du backup à restaurer (1-${backup_count}) ou 'q' pour quitter: " selection

  if [[ ${selection} == "q" || ${selection} == "Q" ]]; then
    log_info "Opération annulée par l'utilisateur"
    exit 0
  fi

  if ! [[ ${selection} =~ ^[0-9]+$ ]] || [[ ${selection} -lt 1 ]] || [[ ${selection} -gt ${backup_count} ]]; then
    fatal "Sélection invalide: ${selection}"
  fi

  local selected_file=$(sed -n "${selection}p" "${list_file}")
  log_info "Backup sélectionné: ${selected_file}"
  echo "${selected_file}"
}

# === Download backup ===
download_backup() {
  local backup_file=$1
  local local_path="${RESTORE_TARGET_DIR}/${backup_file}"

  log_info "Téléchargement de ${backup_file}..."
  log_info "Destination: ${local_path}"

  # Vérifier si déjà téléchargé
  if [[ -f ${local_path} ]]; then
    log_warn "Le fichier existe déjà localement"
    confirm "Utiliser le fichier existant (si non, il sera re-téléchargé) ?"
    if [[ $? -eq 0 ]]; then
      log_info "Utilisation du fichier existant"
      echo "${local_path}"
      return 0
    else
      log_info "Suppression et re-téléchargement..."
      rm -f "${local_path}"
    fi
  fi

  # Télécharger avec barre de progression
  if [[ ${QUIET} -eq 0 ]]; then
    run_cmd rclone copy --progress "${RCLONE_REMOTE}/${backup_file}" "${RESTORE_TARGET_DIR}/"
  else
    run_cmd rclone copy "${RCLONE_REMOTE}/${backup_file}" "${RESTORE_TARGET_DIR}/"
  fi

  if [[ ! -f ${local_path} ]]; then
    fatal "Échec du téléchargement de ${backup_file}"
  fi

  log_success "Téléchargement terminé: ${local_path}"
  echo "${local_path}"
}

# === Verify integrity ===
verify_backup_integrity() {
  local archive_path=$1

  log_info "Vérification de l'intégrité de l'archive..."

  # Test de l'archive tar
  if ! tar -tzf "${archive_path}" >/dev/null 2>&1; then
    fatal "L'archive est corrompue: ${archive_path}"
  fi

  log_success "Archive valide"

  # Vérifier checksum si fichier .sha256 existe
  local checksum_file="${archive_path}.sha256"
  local remote_checksum_file="${RCLONE_REMOTE}/$(basename "${checksum_file}")"

  if rclone ls "${remote_checksum_file}" >/dev/null 2>&1; then
    log_info "Fichier checksum trouvé, vérification..."
    rclone copy "${remote_checksum_file}" "${RESTORE_TARGET_DIR}/"

    if [[ -f ${checksum_file} ]]; then
      local expected_sum=$(cat "${checksum_file}" | cut -d' ' -f1)
      local actual_sum=$(sha256sum "${archive_path}" | cut -d' ' -f1)

      if [[ ${expected_sum} == "${actual_sum}" ]]; then
        log_success "Checksum validé"
      else
        fatal "Checksum invalide! Attendu: ${expected_sum}, Obtenu: ${actual_sum}"
      fi
    fi
  else
    log_warn "Pas de fichier checksum disponible, vérification ignorée"
  fi
}

# === Extract and inspect ===
extract_backup() {
  local archive_path=$1
  local extract_dir="${RESTORE_TARGET_DIR}/extracted"

  log_info "Extraction de l'archive..."
  ensure_dir "${extract_dir}"

  run_cmd tar -xzf "${archive_path}" -C "${extract_dir}"

  log_success "Archive extraite dans: ${extract_dir}"

  # Lister le contenu
  log_info "Contenu de l'archive:"
  ls -lh "${extract_dir}/"

  echo "${extract_dir}"
}

inspect_backup_contents() {
  local extract_dir=$1

  log_info "Inspection du contenu de la sauvegarde..."
  echo ""

  local has_postgres=0
  local has_volumes=0

  if [[ -f ${extract_dir}/postgres.sql ]]; then
    has_postgres=1
    local pg_size=$(du -h "${extract_dir}/postgres.sql" | cut -f1)
    log_success "PostgreSQL dump trouvé (${pg_size})"
  else
    log_warn "Pas de dump PostgreSQL trouvé"
  fi

  if [[ -d ${extract_dir}/volumes ]] || ls -d "${extract_dir}"/*/ >/dev/null 2>&1; then
    has_volumes=1
    log_success "Volumes trouvés:"
    ls -d "${extract_dir}"/*/ 2>/dev/null | while read -r vol; do
      local vol_name=$(basename "${vol}")
      local vol_size=$(du -sh "${vol}" | cut -f1)
      echo "  - ${vol_name} (${vol_size})"
    done
  else
    log_warn "Pas de volumes trouvés"
  fi

  echo ""

  # Vérifier compatibilité avec mode de restauration
  if [[ ${RESTORE_MODE} == "postgres" && ${has_postgres} -eq 0 ]]; then
    fatal "Mode postgres sélectionné mais pas de dump PostgreSQL dans l'archive"
  fi

  if [[ ${RESTORE_MODE} == "volumes" && ${has_volumes} -eq 0 ]]; then
    fatal "Mode volumes sélectionné mais pas de volumes dans l'archive"
  fi
}

# === Pre-restore backup ===
create_pre_restore_backup() {
  if [[ ${SKIP_BACKUP} -eq 1 ]] || [[ ${PRE_RESTORE_BACKUP} != "yes" ]]; then
    log_warn "Backup de sécurité désactivé (risqué!)"
    return 0
  fi

  log_info "Création d'un backup de sécurité avant restauration..."

  local backup_script="${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh"
  if [[ ! -f ${backup_script} ]]; then
    log_warn "Script de backup non trouvé: ${backup_script}"
    confirm "Continuer sans backup de sécurité (risqué!) ?"
    return 0
  fi

  local pre_backup_dir="/opt/backups/pre-restore-safety"
  ensure_dir "${pre_backup_dir}"

  log_info "Exécution du backup de sécurité..."

  export BACKUP_TARGET_DIR="${pre_backup_dir}"
  export BACKUP_NAME_PREFIX="${SERVICE_NAME}-safety"
  export POSTGRES_DSN="${POSTGRES_DSN}"

  if run_cmd bash "${backup_script}" --yes; then
    log_success "Backup de sécurité créé dans: ${pre_backup_dir}"
    log_info "En cas de problème, vous pouvez restaurer ce backup"
  else
    log_error "Échec du backup de sécurité"
    confirm "Continuer malgré l'échec du backup de sécurité (très risqué!) ?"
  fi
}

# === Stop services ===
stop_services() {
  log_info "Arrêt des services pour la restauration..."

  # Arrêter docker-compose si COMPOSE_DIR est défini
  if [[ -n ${COMPOSE_DIR} && -f ${COMPOSE_DIR}/docker-compose.yml ]]; then
    log_info "Arrêt de docker-compose dans ${COMPOSE_DIR}..."
    run_cmd docker compose -f "${COMPOSE_DIR}/docker-compose.yml" down
    log_success "Services arrêtés"
  else
    log_warn "COMPOSE_DIR non défini ou docker-compose.yml non trouvé"
    log_info "Tentative d'arrêt des conteneurs ${SERVICE_NAME}*..."

    # Arrêter tous les conteneurs correspondant au service
    local containers=$(docker ps -q --filter "name=${SERVICE_NAME}" 2>/dev/null || echo "")
    if [[ -n ${containers} ]]; then
      run_cmd docker stop ${containers}
      log_success "Conteneurs arrêtés"
    else
      log_warn "Aucun conteneur ${SERVICE_NAME} en cours d'exécution"
    fi
  fi
}

# === Restore PostgreSQL ===
restore_postgres() {
  local extract_dir=$1

  if [[ ${RESTORE_MODE} != "all" && ${RESTORE_MODE} != "postgres" ]]; then
    log_debug "Restauration PostgreSQL ignorée (mode: ${RESTORE_MODE})"
    return 0
  fi

  local dump_file="${extract_dir}/postgres.sql"
  if [[ ! -f ${dump_file} ]]; then
    log_warn "Pas de dump PostgreSQL trouvé dans l'archive"
    return 0
  fi

  log_info "Restauration de PostgreSQL..."
  log_info "DSN: ${POSTGRES_DSN}"

  confirm "ATTENTION: La base de données existante sera écrasée. Continuer ?"

  log_info "Exécution de pg_restore..."

  # pg_restore avec options standard
  if run_cmd pg_restore --clean --if-exists --no-owner --no-acl -d "${POSTGRES_DSN}" "${dump_file}"; then
    log_success "Base de données restaurée avec succès"
  else
    local exit_code=$?
    log_error "Échec de pg_restore (code: ${exit_code})"
    log_warn "Certaines erreurs peuvent être normales (objets déjà supprimés avec --clean)"
    confirm "Continuer malgré les erreurs de restauration ?"
  fi
}

# === Restore volumes ===
restore_volumes() {
  local extract_dir=$1

  if [[ ${RESTORE_MODE} != "all" && ${RESTORE_MODE} != "volumes" ]]; then
    log_debug "Restauration volumes ignorée (mode: ${RESTORE_MODE})"
    return 0
  fi

  if [[ -z ${DATA_TARGETS} ]]; then
    log_warn "DATA_TARGETS non défini, restauration de volumes ignorée"
    return 0
  fi

  IFS=',' read -r -a DATA_TARGET_ARRAY <<< "${DATA_TARGETS}"

  log_info "Restauration des volumes Docker..."

  local idx=0
  for target in "${DATA_TARGET_ARRAY[@]}"; do
    [[ -z ${target} ]] && continue

    local basename=$(basename "${target}")
    local source="${extract_dir}/${basename}"

    if [[ ! -d ${source} ]]; then
      log_warn "Volume ${basename} non trouvé dans l'archive (${source})"
      ((idx++))
      continue
    fi

    log_info "Restauration: ${source} -> ${target}"

    confirm "Restaurer le volume ${basename} ? (cible: ${target})"

    ensure_dir "${target}"

    # Utiliser rsync pour copier
    if run_cmd rsync -aH --delete "${source}/" "${target}/"; then
      log_success "Volume ${basename} restauré"
    else
      log_error "Échec de la restauration du volume ${basename}"
      confirm "Continuer malgré l'erreur ?"
    fi

    ((idx++))
  done

  log_success "Restauration des volumes terminée"
}

# === Start services ===
start_services() {
  log_info "Démarrage des services..."

  # Démarrer docker-compose si COMPOSE_DIR est défini
  if [[ -n ${COMPOSE_DIR} && -f ${COMPOSE_DIR}/docker-compose.yml ]]; then
    log_info "Démarrage de docker-compose dans ${COMPOSE_DIR}..."
    run_cmd docker compose -f "${COMPOSE_DIR}/docker-compose.yml" up -d
    log_success "Services démarrés"
  else
    log_warn "COMPOSE_DIR non défini, démarrage manuel requis"
  fi

  # Attendre que les services soient prêts
  log_info "Attente du démarrage des services (30s)..."
  sleep 30
}

# === Post-restore verification ===
run_healthcheck() {
  if [[ ${SKIP_HEALTHCHECK} -eq 1 ]]; then
    log_warn "Healthcheck ignoré (--skip-healthcheck)"
    return 0
  fi

  log_info "Vérification de l'état des services..."

  # Si script de healthcheck spécifié
  if [[ -n ${HEALTHCHECK_SCRIPT} && -f ${HEALTHCHECK_SCRIPT} ]]; then
    log_info "Exécution du healthcheck: ${HEALTHCHECK_SCRIPT}"
    if run_cmd bash "${HEALTHCHECK_SCRIPT}"; then
      log_success "Healthcheck OK"
    else
      log_error "Healthcheck a échoué"
      log_warn "Vérifiez les logs des services"
    fi
    return 0
  fi

  # Healthcheck basique
  log_info "Healthcheck basique..."

  # Vérifier conteneurs docker
  if command -v docker >/dev/null 2>&1; then
    log_info "Statut des conteneurs:"
    docker ps --filter "name=${SERVICE_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    # Compter les conteneurs en erreur
    local unhealthy=$(docker ps -a --filter "name=${SERVICE_NAME}" --filter "health=unhealthy" --format "{{.Names}}" | wc -l)
    if [[ ${unhealthy} -gt 0 ]]; then
      log_error "${unhealthy} conteneur(s) en mauvaise santé"
    fi
  fi

  # Vérifier PostgreSQL si DSN fourni
  if [[ -n ${POSTGRES_DSN} ]] && command -v psql >/dev/null 2>&1; then
    log_info "Test connexion PostgreSQL..."
    if psql "${POSTGRES_DSN}" -c "SELECT version();" >/dev/null 2>&1; then
      log_success "PostgreSQL répond"
    else
      log_error "PostgreSQL ne répond pas"
    fi
  fi
}

display_summary() {
  log_success "=== Restauration terminée ==="
  echo ""
  log_info "Résumé:"
  log_info "  - Mode: ${RESTORE_MODE}"
  log_info "  - Service: ${SERVICE_NAME}"
  log_info "  - Fichier: ${BACKUP_FILE:-[sélection interactive]}"
  log_info "  - Log: ${LOG_FILE}"
  echo ""

  if [[ -n ${COMPOSE_DIR} ]]; then
    log_info "Pour vérifier l'état des services:"
    echo "  docker compose -f ${COMPOSE_DIR}/docker-compose.yml ps"
    echo "  docker compose -f ${COMPOSE_DIR}/docker-compose.yml logs -f"
  fi

  echo ""
  log_info "Pour consulter les logs détaillés:"
  echo "  cat ${LOG_FILE}"

  echo ""
  log_warn "N'oubliez pas de vérifier que tous les services fonctionnent correctement!"
}

# === Cleanup ===
cleanup_tmp() {
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] Nettoyage: rm -rf ${RESTORE_TARGET_DIR}"
    return 0
  fi

  if confirm "Supprimer les fichiers temporaires dans ${RESTORE_TARGET_DIR} ?"; then
    run_cmd rm -rf "${RESTORE_TARGET_DIR}"
    log_success "Fichiers temporaires nettoyés"
  else
    log_info "Fichiers conservés dans: ${RESTORE_TARGET_DIR}"
  fi
}

# === Main workflow ===
main() {
  setup_logging
  validate_config

  # Liste des backups
  local list_file=$(list_backups)
  display_backups "${list_file}"

  # Mode list-only
  if [[ ${LIST_ONLY} -eq 1 ]]; then
    log_info "Mode --list-only, arrêt ici"
    exit 0
  fi

  # Sélection du backup
  local selected_backup=$(select_backup "${list_file}")
  BACKUP_FILE="${selected_backup}"

  # Téléchargement
  local archive_path=$(download_backup "${selected_backup}")

  # Vérification intégrité
  verify_backup_integrity "${archive_path}"

  # Extraction
  local extract_dir=$(extract_backup "${archive_path}")

  # Inspection
  inspect_backup_contents "${extract_dir}"

  # Confirmation finale
  echo ""
  log_warn "=== ATTENTION ==="
  log_warn "Vous êtes sur le point de restaurer une sauvegarde."
  log_warn "Les données actuelles seront écrasées!"
  log_warn "Mode de restauration: ${RESTORE_MODE}"
  echo ""
  confirm "Êtes-vous ABSOLUMENT SÛR de vouloir continuer ?"

  # Backup de sécurité
  create_pre_restore_backup

  # Arrêt des services
  stop_services

  # Restauration
  restore_postgres "${extract_dir}"
  restore_volumes "${extract_dir}"

  # Démarrage des services
  start_services

  # Vérification
  run_healthcheck

  # Résumé
  display_summary

  # Nettoyage
  cleanup_tmp

  log_success "=== Restauration complète ==="
}

main "$@"
