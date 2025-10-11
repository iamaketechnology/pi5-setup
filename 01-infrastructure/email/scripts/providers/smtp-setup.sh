#!/bin/bash
# =============================================================================
# SMTP SETUP SCRIPT - Configure SMTP for Supabase Auth
# =============================================================================
#
# Purpose: Configure SMTP (Gmail, SendGrid, Mailgun, or custom) for Supabase
#          authentication emails (signup, password reset, etc.)
#
# Author: PI5-SETUP Project
# Version: 1.1.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 5-10 minutes
#
# Features:
# - Support for Gmail, SendGrid, Mailgun, and custom SMTP
# - Automatic credential validation
# - Backup before configuration changes
# - Test email sending
# - **IDEMPOTENT** (safe to run multiple times)
# - **INTELLIGENT DEBUG** (auto-capture errors with context)
#
# Usage:
#   sudo bash 01-smtp-setup.sh [OPTIONS]
#
# Options:
#   --dry-run          Show what would be done without making changes
#   --yes, -y          Skip confirmation prompts
#   --verbose, -v      Verbose output (use -vv for more details)
#   --quiet, -q        Minimal output
#   --skip-test        Skip SMTP connection test
#   --force            Force reconfiguration even if already configured
#
# Environment variables (optional):
#   SMTP_PROVIDER=gmail|sendgrid|mailgun|custom
#   SMTP_HOST=smtp.gmail.com
#   SMTP_PORT=587
#   SMTP_USER=your-email@gmail.com
#   SMTP_PASS=your-app-password
#   SMTP_FROM=noreply@yourdomain.com
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL_DIR="$(dirname "$SCRIPT_DIR")"
COMMON_SCRIPTS_DIR="$(cd "$EMAIL_DIR/../../common-scripts" && pwd)"
TEMPLATES_DIR="${EMAIL_DIR}/templates"
LOG_DIR="/var/log/pi5-setup"
LOG_FILE="${LOG_DIR}/smtp-setup-$(date +%Y%m%d-%H%M%S).log"
SUPABASE_DIR="/home/pi/stacks/supabase"
BACKUP_DIR="/home/pi/backups/supabase"

# Source common library
if [ -f "$COMMON_SCRIPTS_DIR/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SCRIPTS_DIR/lib.sh"
else
    echo "ERROR: lib.sh not found at $COMMON_SCRIPTS_DIR/lib.sh"
    exit 1
fi

# Script-specific options
SKIP_TEST=0
FORCE_RECONFIG=0

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# =============================================================================
# ERROR HANDLING WITH CONTEXT
# =============================================================================

# Trap errors and provide context
trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

handle_error() {
    local exit_code=$1
    local line_num=$2
    local command=$3

    log_error "Erreur ligne $line_num: $command (code: $exit_code)"

    # Capture diagnostic context
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "🔴 ERREUR DÉTECTÉE - RAPPORT DE DIAGNOSTIC"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📍 Erreur :"
        echo "   Ligne   : $line_num"
        echo "   Commande: $command"
        echo "   Code    : $exit_code"
        echo ""
        echo "📁 Contexte :"
        echo "   Script  : $0"
        echo "   Provider: ${SMTP_PROVIDER:-non défini}"
        echo "   Host    : ${SMTP_HOST:-non défini}"
        echo ""
        echo "🔍 État du système :"
        echo ""
        if [ -d "$SUPABASE_DIR" ]; then
            echo "   ✓ Supabase directory exists"
            if docker ps | grep -q "supabase-auth"; then
                echo "   ✓ Auth service running"
            else
                echo "   ✗ Auth service NOT running"
            fi
        else
            echo "   ✗ Supabase directory NOT found"
        fi
        echo ""
        echo "📝 Logs complets : $LOG_FILE"
        echo ""
        echo "💡 Actions suggérées :"
        echo "   1. Vérifier les logs : cat $LOG_FILE"
        echo "   2. Vérifier config : cat $SUPABASE_DIR/.env | grep SMTP"
        echo "   3. Tester manuellement SMTP avec swaks"
        echo "   4. Relancer avec --verbose : bash $0 --verbose"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } | tee -a "$LOG_FILE"

    exit "$exit_code"
}

# =============================================================================
# LOGGING FUNCTIONS (Enhanced with file logging)
# =============================================================================

log() {
    log_info "$*"
    echo "[$(date +'%H:%M:%S')] INFO: $*" >> "$LOG_FILE"
}

warn() {
    log_warn "$*"
    echo "[$(date +'%H:%M:%S')] WARN: $*" >> "$LOG_FILE"
}

ok() {
    log_success "$*"
    echo "[$(date +'%H:%M:%S')] SUCCESS: $*" >> "$LOG_FILE"
}

error() {
    log_error "$*"
    echo "[$(date +'%H:%M:%S')] ERROR: $*" >> "$LOG_FILE"
    exit 1
}

section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "$*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "[$(date +'%H:%M:%S')] ===== $* =====" >> "$LOG_FILE"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

ask_yes_no() {
    local question="$1"
    local default="${2:-y}"
    if [[ "$default" == "y" ]]; then local prompt="[Y/n]"; else local prompt="[y/N]"; fi
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

ask_input() {
    local question="$1"
    local default="${2:-}"
    local secret="${3:-false}"
    if [ -n "$default" ]; then local prompt="(défaut: $default)"; else local prompt=""; fi
    while true; do
        if [ "$secret" == "true" ]; then
            read -s -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
            echo ""
        else
            read -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
        fi
        answer="${answer:-$default}"
        if [ -n "$answer" ]; then echo "$answer"; return 0; fi
        echo "Valeur requise."
    done
}

# =============================================================================
# IDEMPOTENCY CHECK
# =============================================================================

check_existing_config() {
    section "🔍 VÉRIFICATION CONFIGURATION EXISTANTE"

    local smtp_configured=false
    local config_valid=false

    if [ -f "$SUPABASE_DIR/.env" ]; then
        if grep -q "^GOTRUE_SMTP_HOST=" "$SUPABASE_DIR/.env" 2>/dev/null; then
            smtp_configured=true

            # Extract existing config
            local existing_host=$(grep "^GOTRUE_SMTP_HOST=" "$SUPABASE_DIR/.env" | cut -d= -f2-)
            local existing_port=$(grep "^GOTRUE_SMTP_PORT=" "$SUPABASE_DIR/.env" | cut -d= -f2-)
            local existing_user=$(grep "^GOTRUE_SMTP_USER=" "$SUPABASE_DIR/.env" | cut -d= -f2-)
            local existing_from=$(grep "^GOTRUE_SMTP_ADMIN_EMAIL=" "$SUPABASE_DIR/.env" | cut -d= -f2-)

            warn "Configuration SMTP existante détectée"
            log "   Host : $existing_host"
            log "   Port : $existing_port"
            log "   User : $existing_user"
            log "   From : $existing_from"

            # Check if config seems valid
            if [ -n "$existing_host" ] && [ -n "$existing_port" ] && [ -n "$existing_user" ]; then
                config_valid=true
                log_debug "Configuration existante semble valide"
            else
                warn "Configuration existante incomplète"
            fi
        fi
    fi

    if [ "$smtp_configured" == "true" ] && [ "$config_valid" == "true" ]; then
        if [ "$FORCE_RECONFIG" -eq 1 ]; then
            warn "Flag --force détecté : reconfiguration forcée"
            return 1
        fi

        echo ""
        echo "Une configuration SMTP valide existe déjà."
        echo ""
        echo "Options :"
        echo "  1) Garder la configuration actuelle (quitter)"
        echo "  2) Reconfigurer (remplacer)"
        echo "  3) Voir la configuration actuelle"
        echo ""

        if [ "$ASSUME_YES" -eq 1 ]; then
            log "Mode --yes : conservation de la config existante"
            return 0
        fi

        while true; do
            read -p "Choix [1-3]: " choice
            case "$choice" in
                1)
                    ok "Configuration existante conservée"
                    exit 0
                    ;;
                2)
                    log "Reconfiguration demandée"
                    return 1
                    ;;
                3)
                    echo ""
                    echo "Configuration actuelle :"
                    grep "^GOTRUE_SMTP_" "$SUPABASE_DIR/.env" | sed 's/^GOTRUE_SMTP_PASS=.*/GOTRUE_SMTP_PASS=***HIDDEN***/'
                    echo ""
                    ;;
                *)
                    echo "Choix invalide"
                    ;;
            esac
        done
    fi

    ok "Pas de configuration existante, on continue"
    return 1
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_prerequisites() {
    section "✅ VALIDATION DES PRÉREQUIS"

    # Check root
    require_root

    # Check Supabase installation
    if [ ! -d "$SUPABASE_DIR" ]; then
        error "Supabase non installé dans $SUPABASE_DIR"
    fi
    ok "Supabase trouvé : $SUPABASE_DIR"

    # Check docker-compose.yml
    if [ ! -f "$SUPABASE_DIR/docker-compose.yml" ]; then
        error "docker-compose.yml non trouvé"
    fi
    ok "docker-compose.yml trouvé"

    # Check if Auth service exists
    if ! docker compose -f "$SUPABASE_DIR/docker-compose.yml" config 2>/dev/null | grep -q "supabase-auth"; then
        error "Service Auth non trouvé dans docker-compose.yml"
    fi
    ok "Service Auth détecté"

    # Check if .env exists
    if [ ! -f "$SUPABASE_DIR/.env" ]; then
        warn ".env non trouvé, sera créé"
        run_cmd touch "$SUPABASE_DIR/.env"
    fi
    ok ".env accessible"

    # Check Docker is running
    if ! docker ps >/dev/null 2>&1; then
        error "Docker n'est pas accessible. Vérifiez que Docker est démarré."
    fi
    ok "Docker accessible"
}

# =============================================================================
# SMTP PROVIDER SELECTION
# =============================================================================

select_smtp_provider() {
    section "📧 SÉLECTION DU PROVIDER SMTP"

    if [ -n "${SMTP_PROVIDER:-}" ]; then
        log "Provider défini par variable d'environnement : $SMTP_PROVIDER"
        return
    fi

    echo "Choisissez votre provider SMTP :"
    echo ""
    echo "  1) Gmail (gratuit, 500 emails/jour)"
    echo "     - Facile à configurer"
    echo "     - Nécessite app password"
    echo "     - Parfait pour débuter"
    echo ""
    echo "  2) SendGrid (gratuit, 100 emails/jour)"
    echo "     - API key simple"
    echo "     - Bonne délivrabilité"
    echo "     - Dashboard analytics"
    echo ""
    echo "  3) Mailgun (gratuit, 1000 emails/mois les 3 premiers mois)"
    echo "     - Flexible"
    echo "     - API + SMTP"
    echo ""
    echo "  4) Autre (SMTP personnalisé)"
    echo "     - Provider existant"
    echo "     - Configuration manuelle"
    echo ""

    while true; do
        read -p "$(echo -e "\033[1;33mChoix [1-4]:\033[0m ") " choice
        case "$choice" in
            1) SMTP_PROVIDER="gmail"; break ;;
            2) SMTP_PROVIDER="sendgrid"; break ;;
            3) SMTP_PROVIDER="mailgun"; break ;;
            4) SMTP_PROVIDER="custom"; break ;;
            *) echo "Choix invalide" ;;
        esac
    done

    ok "Provider sélectionné : $SMTP_PROVIDER"
}

# =============================================================================
# PROVIDER-SPECIFIC CONFIGURATION
# =============================================================================

configure_gmail() {
    section "📧 CONFIGURATION GMAIL"

    echo "Configuration Gmail nécessite :"
    echo ""
    echo "  1. Activer l'authentification à 2 facteurs"
    echo "  2. Créer un 'App Password' (mot de passe d'application)"
    echo ""
    echo "Guide rapide :"
    echo "  → Aller sur : https://myaccount.google.com/apppasswords"
    echo "  → Sélectionner 'App' : Mail"
    echo "  → Sélectionner 'Device' : Other (Supabase)"
    echo "  → Générer et copier le mot de passe (16 caractères)"
    echo ""

    if ! ask_yes_no "Avez-vous créé l'app password ?" "y"; then
        log "Configuration annulée. Créez d'abord l'app password."
        exit 0
    fi

    SMTP_HOST="smtp.gmail.com"
    SMTP_PORT="587"
    SMTP_USER=$(ask_input "Entrez votre email Gmail" "${SMTP_USER:-}")
    SMTP_PASS=$(ask_input "Entrez l'app password (16 caractères, sans espaces)" "" "true")
    SMTP_FROM=$(ask_input "Adresse expéditeur" "${SMTP_USER}")

    # Remove spaces from app password
    SMTP_PASS="${SMTP_PASS// /}"

    ok "Gmail configuré"
}

configure_sendgrid() {
    section "📧 CONFIGURATION SENDGRID"

    echo "Configuration SendGrid nécessite :"
    echo ""
    echo "  1. Créer un compte sur https://sendgrid.com"
    echo "  2. Vérifier votre email"
    echo "  3. Créer une API Key"
    echo ""
    echo "Guide rapide :"
    echo "  → Dashboard → Settings → API Keys"
    echo "  → Create API Key"
    echo "  → Nom : 'Supabase Auth'"
    echo "  → Permissions : 'Full Access' ou 'Mail Send'"
    echo "  → Copier la clé (commence par SG.)"
    echo ""

    if ! ask_yes_no "Avez-vous créé l'API key ?" "y"; then
        log "Configuration annulée. Créez d'abord l'API key."
        exit 0
    fi

    SMTP_HOST="smtp.sendgrid.net"
    SMTP_PORT="587"
    SMTP_USER="apikey"  # SendGrid utilise toujours 'apikey' comme username
    SMTP_PASS=$(ask_input "Entrez l'API key SendGrid" "" "true")
    SMTP_FROM=$(ask_input "Adresse expéditeur (doit être vérifiée sur SendGrid)" "${SMTP_FROM:-noreply@yourdomain.com}")

    ok "SendGrid configuré"
}

configure_mailgun() {
    section "📧 CONFIGURATION MAILGUN"

    echo "Configuration Mailgun nécessite :"
    echo ""
    echo "  1. Créer un compte sur https://mailgun.com"
    echo "  2. Vérifier votre domaine (ou utiliser sandbox)"
    echo "  3. Récupérer les credentials SMTP"
    echo ""
    echo "Guide rapide :"
    echo "  → Dashboard → Sending → Domain settings"
    echo "  → Section 'SMTP credentials'"
    echo "  → Créer un nouveau user SMTP"
    echo ""

    if ! ask_yes_no "Avez-vous les credentials SMTP ?" "y"; then
        log "Configuration annulée. Configurez d'abord Mailgun."
        exit 0
    fi

    SMTP_HOST=$(ask_input "Serveur SMTP Mailgun" "smtp.mailgun.org")
    SMTP_PORT=$(ask_input "Port SMTP" "587")
    SMTP_USER=$(ask_input "Username SMTP (format: postmaster@...)")
    SMTP_PASS=$(ask_input "Password SMTP" "" "true")
    SMTP_FROM=$(ask_input "Adresse expéditeur" "${SMTP_USER}")

    ok "Mailgun configuré"
}

configure_custom() {
    section "📧 CONFIGURATION SMTP PERSONNALISÉ"

    echo "Entrez les informations de votre serveur SMTP :"
    echo ""

    SMTP_HOST=$(ask_input "Serveur SMTP (ex: smtp.example.com)")
    SMTP_PORT=$(ask_input "Port SMTP" "587")
    SMTP_USER=$(ask_input "Username SMTP")
    SMTP_PASS=$(ask_input "Password SMTP" "" "true")
    SMTP_FROM=$(ask_input "Adresse expéditeur" "${SMTP_USER}")

    ok "SMTP personnalisé configuré"
}

# =============================================================================
# TEST SMTP CONNECTION
# =============================================================================

test_smtp_connection() {
    section "🔍 TEST DE CONNEXION SMTP"

    log "Test de connexion à $SMTP_HOST:$SMTP_PORT..."

    # Install swaks if not present (SMTP testing tool)
    if ! command -v swaks &> /dev/null; then
        log "Installation de swaks (outil de test SMTP)..."
        apt-get update -qq && apt-get install -y -qq swaks libnet-ssleay-perl 2>&1 | tee -a "$LOG_FILE"
    fi

    # Test SMTP connection
    if swaks --to "$SMTP_FROM" \
             --from "$SMTP_FROM" \
             --server "$SMTP_HOST:$SMTP_PORT" \
             --auth LOGIN \
             --auth-user "$SMTP_USER" \
             --auth-password "$SMTP_PASS" \
             --tls \
             --header "Subject: Test SMTP Supabase" \
             --body "Test de connexion SMTP réussi" \
             2>&1 | tee -a "$LOG_FILE"; then
        ok "Connexion SMTP réussie !"
    else
        error "Échec de connexion SMTP. Vérifiez vos credentials."
    fi
}

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

backup_configuration() {
    section "💾 SAUVEGARDE DE LA CONFIGURATION"

    local backup_file="${BACKUP_DIR}/docker-compose-$(date +%Y%m%d-%H%M%S).yml"
    local env_backup="${BACKUP_DIR}/.env-$(date +%Y%m%d-%H%M%S)"

    if [ -f "$SUPABASE_DIR/docker-compose.yml" ]; then
        cp "$SUPABASE_DIR/docker-compose.yml" "$backup_file"
        ok "docker-compose.yml sauvegardé : $backup_file"
    fi

    if [ -f "$SUPABASE_DIR/.env" ]; then
        cp "$SUPABASE_DIR/.env" "$env_backup"
        ok ".env sauvegardé : $env_backup"
    fi
}

# =============================================================================
# UPDATE CONFIGURATION
# =============================================================================

update_supabase_config() {
    section "⚙️  MISE À JOUR DE LA CONFIGURATION SUPABASE"

    # Update .env file
    log "Mise à jour de .env..."

    # Remove old SMTP config if exists
    sed -i.bak '/^GOTRUE_SMTP_/d' "$SUPABASE_DIR/.env" 2>/dev/null || true

    # Add new SMTP config
    cat >> "$SUPABASE_DIR/.env" <<EOF

# SMTP Configuration (added by smtp-setup.sh on $(date))
GOTRUE_SMTP_HOST=${SMTP_HOST}
GOTRUE_SMTP_PORT=${SMTP_PORT}
GOTRUE_SMTP_USER=${SMTP_USER}
GOTRUE_SMTP_PASS=${SMTP_PASS}
GOTRUE_SMTP_ADMIN_EMAIL=${SMTP_FROM}
GOTRUE_SMTP_MAX_FREQUENCY=1s
GOTRUE_MAILER_AUTOCONFIRM=false
EOF

    ok ".env mis à jour"

    # Update docker-compose.yml to reference .env
    log "Vérification de docker-compose.yml..."

    if ! grep -q "GOTRUE_SMTP_HOST" "$SUPABASE_DIR/docker-compose.yml"; then
        log "Ajout des variables SMTP au service auth..."

        # Find auth service and add env vars
        sed -i.bak '/supabase-auth:/,/^  [^ ]/ {
            /environment:/a\
      GOTRUE_SMTP_HOST: ${GOTRUE_SMTP_HOST}\
      GOTRUE_SMTP_PORT: ${GOTRUE_SMTP_PORT}\
      GOTRUE_SMTP_USER: ${GOTRUE_SMTP_USER}\
      GOTRUE_SMTP_PASS: ${GOTRUE_SMTP_PASS}\
      GOTRUE_SMTP_ADMIN_EMAIL: ${GOTRUE_SMTP_ADMIN_EMAIL}\
      GOTRUE_SMTP_MAX_FREQUENCY: ${GOTRUE_SMTP_MAX_FREQUENCY:-1s}\
      GOTRUE_MAILER_AUTOCONFIRM: ${GOTRUE_MAILER_AUTOCONFIRM:-false}
        }' "$SUPABASE_DIR/docker-compose.yml"

        ok "docker-compose.yml mis à jour"
    else
        ok "Variables SMTP déjà présentes dans docker-compose.yml"
    fi
}

# =============================================================================
# RESTART SERVICES
# =============================================================================

restart_services() {
    section "🔄 REDÉMARRAGE DES SERVICES"

    log "Arrêt du service Auth..."
    docker compose -f "$SUPABASE_DIR/docker-compose.yml" stop auth 2>&1 | tee -a "$LOG_FILE"

    log "Démarrage du service Auth..."
    docker compose -f "$SUPABASE_DIR/docker-compose.yml" up -d auth 2>&1 | tee -a "$LOG_FILE"

    log "Attente de la disponibilité du service (10 secondes)..."
    sleep 10

    # Check if auth is running
    if docker ps | grep -q "supabase-auth"; then
        ok "Service Auth redémarré avec succès"
    else
        error "Échec du redémarrage du service Auth"
    fi

    # Show logs
    log "Derniers logs du service Auth :"
    docker compose -f "$SUPABASE_DIR/docker-compose.yml" logs --tail=20 auth | tee -a "$LOG_FILE"
}

# =============================================================================
# FINAL TEST
# =============================================================================

test_email_sending() {
    section "📬 TEST D'ENVOI D'EMAIL"

    echo "Le service Auth est maintenant configuré pour envoyer des emails."
    echo ""
    echo "Pour tester :"
    echo "  1. Créer un compte dans votre application"
    echo "  2. Utiliser la fonction 'reset password'"
    echo "  3. Vérifier la réception de l'email"
    echo ""

    if ask_yes_no "Voulez-vous voir les logs en temps réel ?" "n"; then
        log "Affichage des logs (Ctrl+C pour quitter)..."
        docker compose -f "$SUPABASE_DIR/docker-compose.yml" logs -f auth
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================

display_summary() {
    section "✅ CONFIGURATION SMTP TERMINÉE"

    echo -e "\033[1;32m🎉 SMTP configuré avec succès !\033[0m"
    echo ""
    echo "📧 Configuration :"
    echo "  Provider : $SMTP_PROVIDER"
    echo "  Serveur  : $SMTP_HOST:$SMTP_PORT"
    echo "  From     : $SMTP_FROM"
    echo ""
    echo "📁 Fichiers modifiés :"
    echo "  → $SUPABASE_DIR/.env"
    echo "  → $SUPABASE_DIR/docker-compose.yml"
    echo ""
    echo "💾 Sauvegardes dans : $BACKUP_DIR"
    echo ""
    echo "🧪 Pour tester l'envoi :"
    echo "  → Créer un compte : Supabase Auth signup"
    echo "  → Reset password : Utiliser la fonction dans votre app"
    echo "  → Voir logs : docker compose -f $SUPABASE_DIR/docker-compose.yml logs -f auth"
    echo ""
    echo "📚 Documentation :"
    echo "  → Guide email : $EMAIL_DIR/GUIDE-EMAIL-CHOICES.md"
    echo ""
    echo "📝 Log complet : $LOG_FILE"
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_script_args() {
    # Parse common args first
    parse_common_args "$@"
    set -- "${COMMON_POSITIONAL_ARGS[@]}"

    # Parse script-specific args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-test)
                SKIP_TEST=1
                shift
                ;;
            --force)
                FORCE_RECONFIG=1
                shift
                ;;
            *)
                warn "Argument inconnu ignoré : $1"
                shift
                ;;
        esac
    done
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    section "📧 CONFIGURATION SMTP POUR SUPABASE"

    log "Script SMTP setup v1.1.0"
    log "Log file: $LOG_FILE"
    log_debug "DRY_RUN=$DRY_RUN, VERBOSE=$VERBOSE, FORCE=$FORCE_RECONFIG"

    # Step 1: Validate prerequisites
    validate_prerequisites

    # Step 2: Check existing config (idempotency)
    if check_existing_config; then
        # Config exists and user chose to keep it
        exit 0
    fi

    # Step 3: Select provider
    select_smtp_provider

    # Step 4: Configure based on provider
    case "$SMTP_PROVIDER" in
        gmail) configure_gmail ;;
        sendgrid) configure_sendgrid ;;
        mailgun) configure_mailgun ;;
        custom) configure_custom ;;
        *) error "Provider invalide : $SMTP_PROVIDER" ;;
    esac

    # Step 5: Test connection (unless skipped)
    if [ "$SKIP_TEST" -eq 0 ]; then
        test_smtp_connection
    else
        warn "Test SMTP ignoré (--skip-test)"
    fi

    # Step 6: Backup existing config
    backup_configuration

    # Step 7: Update Supabase configuration
    update_supabase_config

    # Step 8: Restart services
    restart_services

    # Step 9: Test email sending
    test_email_sending

    # Step 10: Display summary
    display_summary

    ok "Script terminé avec succès !"
}

# Parse arguments
parse_script_args "$@"

# Run main
main
