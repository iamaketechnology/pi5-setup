#!/bin/bash
# =============================================================================
# EMAIL PROVIDER CLEANUP SCRIPT - Clean email provider configuration
# =============================================================================
#
# Purpose: Remove email provider configuration from Supabase stack
#          Supports cleaning specific providers or all providers
#
# Author: PI5-SETUP Project
# Version: 1.1.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 1-2 minutes
#
# Features:
# - Selective cleanup (specific provider or all)
# - Cleanup legacy EMAIL_* generic variables
# - Automatic backups before cleanup
# - Docker compose variable cleanup
# - Optional stack restart
# - **SAFE** (always backs up before changes)
#
# Usage:
#   sudo bash 02-email-provider-cleanup.sh [OPTIONS]
#
# Options:
#   --provider <name>  Clean specific provider (resend|sendgrid|mailgun|legacy|all)
#   --all              Clean all email providers
#   --legacy           Clean only legacy EMAIL_* generic variables
#   --no-restart       Don't restart stack after cleanup
#   --dry-run          Show what would be done without making changes
#   --yes, -y          Skip confirmation prompts
#   --verbose, -v      Verbose output
#
# Examples:
#   # Clean only Resend
#   sudo bash 02-email-provider-cleanup.sh --provider resend
#
#   # Clean all providers
#   sudo bash 02-email-provider-cleanup.sh --all
#
#   # Clean only legacy EMAIL_* variables
#   sudo bash 02-email-provider-cleanup.sh --legacy
#
#   # Clean without restarting stack
#   sudo bash 02-email-provider-cleanup.sh --provider sendgrid --no-restart
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/var/log/pi5-setup"
LOG_FILE="${LOG_DIR}/email-cleanup-$(date +%Y%m%d-%H%M%S).log"
SUPABASE_DIR="/home/pi/stacks/supabase"
FUNCTIONS_DIR="$SUPABASE_DIR/functions"
BACKUP_DIR="/home/pi/backups/supabase"

# Script options
CLEAN_PROVIDER=""
CLEAN_ALL=0
NO_RESTART=0
DRY_RUN=0
ASSUME_YES=0
VERBOSE=0

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log_info() { echo -e "\033[1;36m[$(date +'%H:%M:%S')]\033[0m $*"; }
log_warn() { echo -e "\033[1;33m[$(date +'%H:%M:%S')]\033[0m ⚠️  $*"; }
log_error() { echo -e "\033[1;31m[$(date +'%H:%M:%S')]\033[0m ✗ $*"; }
log_success() { echo -e "\033[1;32m[$(date +'%H:%M:%S')]\033[0m ✓ $*"; }

log() { log_info "$*"; echo "[$(date +'%H:%M:%S')] INFO: $*" >> "$LOG_FILE"; }
warn() { log_warn "$*"; echo "[$(date +'%H:%M:%S')] WARN: $*" >> "$LOG_FILE"; }
ok() { log_success "$*"; echo "[$(date +'%H:%M:%S')] SUCCESS: $*" >> "$LOG_FILE"; }
error() { log_error "$*"; echo "[$(date +'%H:%M:%S')] ERROR: $*" >> "$LOG_FILE"; exit 1; }

section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "$*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "[$(date +'%H:%M:%S')] ===== $* =====" >> "$LOG_FILE"
}

ask_yes_no() {
    local question="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi

    if [[ ${ASSUME_YES:-0} -eq 1 ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    while true; do
        read -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Répondre 'y' ou 'n'" ;;
        esac
    done
}

require_root() {
    if [[ $(id -u) -ne 0 ]]; then
        error "Ce script doit être exécuté avec sudo"
    fi
}

# =============================================================================
# ERROR HANDLING
# =============================================================================

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

handle_error() {
    local exit_code=$1
    local line_num=$2
    local command=$3

    log_error "Erreur ligne $line_num: $command (code: $exit_code)"
    echo "📝 Log complet : $LOG_FILE"
    exit "$exit_code"
}

# =============================================================================
# DETECTION
# =============================================================================

detect_configured_providers() {
    local providers=()

    if [ -f "$SUPABASE_DIR/.env" ]; then
        grep -q "^RESEND_API_KEY=" "$SUPABASE_DIR/.env" 2>/dev/null && providers+=("resend")
        grep -q "^SENDGRID_API_KEY=" "$SUPABASE_DIR/.env" 2>/dev/null && providers+=("sendgrid")
        grep -q "^MAILGUN_API_KEY=" "$SUPABASE_DIR/.env" 2>/dev/null && providers+=("mailgun")
    fi

    echo "${providers[@]}"
}

# =============================================================================
# BACKUP
# =============================================================================

create_backup() {
    section "📦 CRÉATION DU BACKUP"

    local backup_timestamp="cleanup-$(date +%Y%m%d-%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_timestamp"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] Création backup dans: $backup_path"
        return 0
    fi

    mkdir -p "$backup_path"

    # Backup .env files
    if [ -f "$SUPABASE_DIR/.env" ]; then
        cp "$SUPABASE_DIR/.env" "$backup_path/supabase.env"
        ok "Supabase .env sauvegardé"
    fi

    if [ -f "$FUNCTIONS_DIR/.env" ]; then
        cp "$FUNCTIONS_DIR/.env" "$backup_path/functions.env"
        ok "Functions .env sauvegardé"
    fi

    if [ -f "$SUPABASE_DIR/docker-compose.yml" ]; then
        cp "$SUPABASE_DIR/docker-compose.yml" "$backup_path/docker-compose.yml"
        ok "docker-compose.yml sauvegardé"
    fi

    ok "Backup créé: $backup_path"
}

# =============================================================================
# CLEANUP FUNCTIONS
# =============================================================================

clean_env_files() {
    local provider="$1"
    section "🧹 NETTOYAGE DES FICHIERS .ENV"

    local patterns=()
    case "$provider" in
        resend)
            patterns=("^RESEND_")
            ;;
        sendgrid)
            patterns=("^SENDGRID_")
            ;;
        mailgun)
            patterns=("^MAILGUN_")
            ;;
        legacy)
            patterns=("^EMAIL_PROVIDER=" "^EMAIL_API_KEY=" "^EMAIL_FROM=" "^EMAIL_DOMAIN=")
            ;;
        all)
            patterns=("^RESEND_" "^SENDGRID_" "^MAILGUN_" "^EMAIL_")
            ;;
    esac

    # Clean supabase/.env
    if [ -f "$SUPABASE_DIR/.env" ]; then
        for pattern in "${patterns[@]}"; do
            if [ "$DRY_RUN" -eq 1 ]; then
                local count=$(grep -c "$pattern" "$SUPABASE_DIR/.env" 2>/dev/null || echo 0)
                log "[DRY-RUN] Suppression de $count variables $pattern dans supabase/.env"
            else
                sed -i.bak "/$pattern/d" "$SUPABASE_DIR/.env" 2>/dev/null || true
            fi
        done
        ok "Variables nettoyées dans supabase/.env"
    fi

    # Clean functions/.env
    if [ -f "$FUNCTIONS_DIR/.env" ]; then
        for pattern in "${patterns[@]}"; do
            if [ "$DRY_RUN" -eq 1 ]; then
                local count=$(grep -c "$pattern" "$FUNCTIONS_DIR/.env" 2>/dev/null || echo 0)
                log "[DRY-RUN] Suppression de $count variables $pattern dans functions/.env"
            else
                sed -i.bak "/$pattern/d" "$FUNCTIONS_DIR/.env" 2>/dev/null || true
            fi
        done
        ok "Variables nettoyées dans functions/.env"
    fi
}

clean_docker_compose() {
    local provider="$1"
    section "🐳 NETTOYAGE DOCKER COMPOSE"

    if [ ! -f "$SUPABASE_DIR/docker-compose.yml" ]; then
        warn "docker-compose.yml non trouvé"
        return 0
    fi

    local vars_to_remove=()
    case "$provider" in
        resend)
            vars_to_remove=("RESEND_API_KEY" "RESEND_FROM_EMAIL" "RESEND_DOMAIN")
            ;;
        sendgrid)
            vars_to_remove=("SENDGRID_API_KEY" "SENDGRID_FROM_EMAIL" "SENDGRID_DOMAIN")
            ;;
        mailgun)
            vars_to_remove=("MAILGUN_API_KEY" "MAILGUN_FROM_EMAIL" "MAILGUN_DOMAIN" "MAILGUN_REGION")
            ;;
        legacy)
            vars_to_remove=("EMAIL_PROVIDER" "EMAIL_API_KEY" "EMAIL_FROM" "EMAIL_DOMAIN")
            ;;
        all)
            vars_to_remove=("RESEND_API_KEY" "RESEND_FROM_EMAIL" "RESEND_DOMAIN"
                            "SENDGRID_API_KEY" "SENDGRID_FROM_EMAIL" "SENDGRID_DOMAIN"
                            "MAILGUN_API_KEY" "MAILGUN_FROM_EMAIL" "MAILGUN_DOMAIN" "MAILGUN_REGION"
                            "EMAIL_PROVIDER" "EMAIL_API_KEY" "EMAIL_FROM" "EMAIL_DOMAIN")
            ;;
    esac

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] Suppression des variables ${vars_to_remove[*]} de docker-compose.yml"
        return 0
    fi

    # Use Python to safely remove variables
    python3 <<PYTHON_SCRIPT
import sys

docker_compose_file = "$SUPABASE_DIR/docker-compose.yml"
vars_to_remove = [$(printf '"%s",' "${vars_to_remove[@]}" | sed 's/,$//')]

try:
    with open(docker_compose_file, 'r') as f:
        lines = f.readlines()

    new_lines = []
    for line in lines:
        # Check if line contains any variable to remove
        should_remove = False
        for var in vars_to_remove:
            if f"{var}:" in line or f"{var} :" in line:
                should_remove = True
                break

        if not should_remove:
            new_lines.append(line)

    with open(docker_compose_file, 'w') as f:
        f.writelines(new_lines)

    print("SUCCESS")

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        ok "Variables supprimées de docker-compose.yml"
    else
        warn "Suppression automatique échouée"
    fi
}

clean_edge_functions() {
    section "📂 NETTOYAGE EDGE FUNCTIONS"

    # Remove send-email function if exists
    if [ -d "$FUNCTIONS_DIR/send-email" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log "[DRY-RUN] Suppression de $FUNCTIONS_DIR/send-email/"
        else
            rm -rf "$FUNCTIONS_DIR/send-email"
            ok "Fonction send-email supprimée"
        fi
    else
        log "Fonction send-email non trouvée (skip)"
    fi

    # Remove email helper if exists
    if [ -f "$FUNCTIONS_DIR/_shared/email-helper.ts" ]; then
        if [ "$DRY_RUN" -eq 1 ]; then
            log "[DRY-RUN] Suppression de email-helper.ts"
        else
            rm -f "$FUNCTIONS_DIR/_shared/email-helper.ts"
            ok "Helper email supprimé"
        fi
    fi
}

# =============================================================================
# RESTART
# =============================================================================

restart_stack() {
    section "🔄 REDÉMARRAGE DU STACK"

    if [ "$NO_RESTART" -eq 1 ]; then
        warn "Flag --no-restart détecté, skip du redémarrage"
        warn "Redémarrez manuellement: cd $SUPABASE_DIR && docker compose down && docker compose up -d"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "[DRY-RUN] docker compose down && docker compose up -d"
        return 0
    fi

    log "Arrêt du stack..."
    cd "$SUPABASE_DIR"
    docker compose down >> "$LOG_FILE" 2>&1

    ok "Stack arrêté"

    log "Redémarrage..."
    docker compose up -d >> "$LOG_FILE" 2>&1

    ok "Stack redémarré"

    log "Attente de la disponibilité (30 secondes)..."
    sleep 30

    ok "Stack prêt"
}

# =============================================================================
# DISPLAY
# =============================================================================

display_summary() {
    section "✅ NETTOYAGE TERMINÉ"

    echo -e "\033[1;32m🎉 Configuration email nettoyée avec succès !\033[0m"
    echo ""

    if [ "$CLEAN_ALL" -eq 1 ]; then
        echo "🧹 Nettoyage : Tous les providers"
    else
        echo "🧹 Nettoyage : $CLEAN_PROVIDER"
    fi

    echo ""
    echo "📁 Fichiers modifiés :"
    echo "  → $SUPABASE_DIR/.env"
    echo "  → $FUNCTIONS_DIR/.env"
    echo "  → $SUPABASE_DIR/docker-compose.yml"
    echo ""

    if [ "$NO_RESTART" -eq 0 ]; then
        echo "🔄 Stack Supabase redémarré"
    else
        echo "⚠️  Stack non redémarré (--no-restart)"
        echo "   Pensez à redémarrer : docker compose down && up -d"
    fi

    echo ""
    echo "📦 Backup disponible dans: $BACKUP_DIR"
    echo "📝 Log complet : $LOG_FILE"
    echo ""

    # Show remaining providers
    local remaining=($(detect_configured_providers))
    if [ ${#remaining[@]} -gt 0 ]; then
        echo "📧 Providers encore configurés : ${remaining[*]}"
    else
        echo "✓ Aucun provider email configuré"
    fi
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                CLEAN_PROVIDER="$2"
                shift 2
                ;;
            --all)
                CLEAN_ALL=1
                CLEAN_PROVIDER="all"
                shift
                ;;
            --legacy)
                CLEAN_PROVIDER="legacy"
                shift
                ;;
            --no-restart)
                NO_RESTART=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --yes|-y)
                ASSUME_YES=1
                shift
                ;;
            --verbose|-v)
                VERBOSE=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --provider <name>  Clean specific provider (resend|sendgrid|mailgun|legacy|all)
  --all              Clean all email providers
  --legacy           Clean only legacy EMAIL_* generic variables
  --no-restart       Don't restart stack after cleanup
  --dry-run          Show what would be done
  --yes, -y          Skip confirmations
  --verbose, -v      Verbose output
  --help, -h         Show this help

Examples:
  sudo bash $0 --provider resend
  sudo bash $0 --all
  sudo bash $0 --provider sendgrid --no-restart

EOF
                exit 0
                ;;
            *)
                warn "Option inconnue: $1"
                shift
                ;;
        esac
    done
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_prerequisites() {
    section "✅ VALIDATION"

    require_root

    if [ ! -d "$SUPABASE_DIR" ]; then
        error "Supabase non installé dans $SUPABASE_DIR"
    fi
    ok "Supabase trouvé"

    # Detect configured providers
    local configured=($(detect_configured_providers))

    if [ ${#configured[@]} -eq 0 ]; then
        warn "Aucun provider email configuré"
        log "Rien à nettoyer"
        exit 0
    fi

    ok "Providers configurés: ${configured[*]}"

    # Validate provider selection
    if [ -z "$CLEAN_PROVIDER" ]; then
        echo ""
        echo "Providers disponibles à nettoyer:"
        for p in "${configured[@]}"; do
            echo "  • $p"
        done
        echo ""
        error "Spécifiez --provider <name> ou --all"
    fi

    if [ "$CLEAN_PROVIDER" != "all" ]; then
        local valid=0
        for p in "${configured[@]}"; do
            if [ "$p" = "$CLEAN_PROVIDER" ]; then
                valid=1
                break
            fi
        done

        if [ $valid -eq 0 ]; then
            error "Provider '$CLEAN_PROVIDER' non configuré (disponibles: ${configured[*]})"
        fi
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    section "🧹 NETTOYAGE EMAIL PROVIDER"

    log "Email Provider Cleanup v1.1.0"
    log "Log file: $LOG_FILE"

    validate_prerequisites

    # Confirm cleanup
    if [ "$CLEAN_ALL" -eq 1 ]; then
        echo "⚠️  Vous allez nettoyer TOUS les providers email configurés"
    else
        echo "⚠️  Vous allez nettoyer la configuration: $CLEAN_PROVIDER"
    fi

    echo ""

    if ! ask_yes_no "Continuer avec le nettoyage ?" "n"; then
        log "Nettoyage annulé"
        exit 0
    fi

    create_backup
    clean_env_files "$CLEAN_PROVIDER"
    clean_docker_compose "$CLEAN_PROVIDER"
    clean_edge_functions
    restart_stack
    display_summary

    ok "Nettoyage terminé avec succès !"
}

parse_args "$@"
main
