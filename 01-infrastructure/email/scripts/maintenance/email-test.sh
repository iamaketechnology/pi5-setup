#!/bin/bash
# =============================================================================
# EMAIL TEST SCRIPT - Universal Email Configuration Tester
# =============================================================================
#
# Purpose: Test email sending capabilities regardless of configuration
#          (SMTP, Resend, or Mailu). Auto-detects setup and provides
#          diagnostic information.
#
# Author: PI5-SETUP Project
# Version: 1.0.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 1-2 minutes
#
# Features:
# - Auto-detects email configuration (SMTP/Resend/Mailu)
# - Sends test emails
# - Validates configuration
# - Provides troubleshooting guidance
#
# Usage:
#   sudo bash 99-email-test.sh [OPTIONS] [EMAIL]
#
# Options:
#   --verbose, -v      Verbose output
#   --smtp             Force SMTP test
#   --resend           Force Resend test
#   --mailu            Force Mailu test
#
# Examples:
#   sudo bash 99-email-test.sh test@example.com
#   sudo bash 99-email-test.sh --verbose --smtp user@gmail.com
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMAIL_DIR="$(dirname "$SCRIPT_DIR")"
COMMON_SCRIPTS_DIR="$(cd "$EMAIL_DIR/../../common-scripts" && pwd)"
LOG_DIR="/var/log/pi5-setup"
LOG_FILE="${LOG_DIR}/email-test-$(date +%Y%m%d-%H%M%S).log"
SUPABASE_DIR="/home/pi/stacks/supabase"
MAILU_DIR="/home/pi/stacks/mailu"

# Source common library
if [ -f "$COMMON_SCRIPTS_DIR/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SCRIPTS_DIR/lib.sh"
else
    echo "ERROR: lib.sh not found"
    exit 1
fi

# Options
TEST_EMAIL=""
FORCE_METHOD=""

mkdir -p "$LOG_DIR"

# =============================================================================
# LOGGING
# =============================================================================

log() { log_info "$*"; echo "[$(date +'%H:%M:%S')] $*" >> "$LOG_FILE"; }
warn() { log_warn "$*"; echo "[$(date +'%H:%M:%S')] WARN: $*" >> "$LOG_FILE"; }
ok() { log_success "$*"; echo "[$(date +'%H:%M:%S')] SUCCESS: $*" >> "$LOG_FILE"; }
error() { log_error "$*"; echo "[$(date +'%H:%M:%S')] ERROR: $*" >> "$LOG_FILE"; exit 1; }
section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_info "$*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# =============================================================================
# EMAIL CONFIGURATION DETECTION
# =============================================================================

detect_email_config() {
    section "🔍 DÉTECTION DE LA CONFIGURATION EMAIL"

    local methods=()

    # Check SMTP (Supabase Auth)
    if [ -f "$SUPABASE_DIR/.env" ]; then
        if grep -q "^GOTRUE_SMTP_HOST=" "$SUPABASE_DIR/.env" 2>/dev/null; then
            methods+=("smtp")
            ok "SMTP configuré (Supabase Auth)"
        fi
    fi

    # Check Resend (Edge Functions)
    if [ -d "$SUPABASE_DIR/functions/send-email" ]; then
        if [ -f "$SUPABASE_DIR/functions/send-email/index.ts" ]; then
            if grep -q "Resend\|RESEND" "$SUPABASE_DIR/functions/send-email/index.ts" 2>/dev/null; then
                methods+=("resend")
                ok "Resend configuré (Edge Functions)"
            fi
        fi
    fi

    # Check Mailu
    if [ -d "$MAILU_DIR" ]; then
        if [ -f "$MAILU_DIR/docker-compose.yml" ]; then
            methods+=("mailu")
            ok "Mailu installé"
        fi
    fi

    if [ ${#methods[@]} -eq 0 ]; then
        warn "Aucune configuration email détectée"
        echo ""
        echo "Configurez d'abord une solution email :"
        echo "  sudo bash $(dirname "$SCRIPT_DIR")/00-email-setup-wizard.sh"
        echo ""
        exit 1
    fi

    echo ""
    log "Méthodes disponibles : ${methods[*]}"

    # Use forced method if specified
    if [ -n "$FORCE_METHOD" ]; then
        if [[ " ${methods[*]} " =~ " ${FORCE_METHOD} " ]]; then
            DETECTED_METHOD="$FORCE_METHOD"
            log "Méthode forcée : $FORCE_METHOD"
        else
            error "Méthode $FORCE_METHOD non disponible (disponibles: ${methods[*]})"
        fi
    else
        # Use first available method
        DETECTED_METHOD="${methods[0]}"
        log "Méthode sélectionnée : $DETECTED_METHOD"
    fi
}

# =============================================================================
# GET TEST EMAIL
# =============================================================================

get_test_email() {
    if [ -n "$TEST_EMAIL" ]; then
        return
    fi

    echo ""
    read -p "$(echo -e "\033[1;33m❓ Entrez l'adresse email de test:\033[0m ") " email

    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        error "Email invalide : $email"
    fi

    TEST_EMAIL="$email"
    ok "Email de test : $TEST_EMAIL"
}

# =============================================================================
# SMTP TEST
# =============================================================================

test_smtp() {
    section "📧 TEST SMTP (SUPABASE AUTH)"

    if [ ! -f "$SUPABASE_DIR/.env" ]; then
        error "Fichier .env Supabase non trouvé"
    fi

    # Extract SMTP config
    local smtp_host=$(grep "^GOTRUE_SMTP_HOST=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')
    local smtp_port=$(grep "^GOTRUE_SMTP_PORT=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')
    local smtp_user=$(grep "^GOTRUE_SMTP_USER=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')
    local smtp_pass=$(grep "^GOTRUE_SMTP_PASS=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')
    local smtp_from=$(grep "^GOTRUE_SMTP_ADMIN_EMAIL=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')

    if [ -z "$smtp_host" ] || [ -z "$smtp_port" ]; then
        error "Configuration SMTP incomplète"
    fi

    log "Configuration SMTP :"
    log "  Host : $smtp_host"
    log "  Port : $smtp_port"
    log "  User : $smtp_user"
    log "  From : $smtp_from"

    # Check if swaks is installed
    if ! command -v swaks &> /dev/null; then
        log "Installation de swaks..."
        apt-get update -qq && apt-get install -y -qq swaks libnet-ssleay-perl
    fi

    # Send test email
    log "Envoi d'email de test via SMTP..."

    if swaks --to "$TEST_EMAIL" \
             --from "$smtp_from" \
             --server "$smtp_host:$smtp_port" \
             --auth LOGIN \
             --auth-user "$smtp_user" \
             --auth-password "$smtp_pass" \
             --tls \
             --header "Subject: Test Email from PI5-SETUP" \
             --body "Ceci est un email de test envoyé depuis votre Raspberry Pi 5.

Configuration : SMTP via Supabase Auth
Date : $(date)
Host : $smtp_host

Si vous recevez cet email, votre configuration SMTP fonctionne correctement !

---
PI5-SETUP Email Test System" \
             2>&1 | tee -a "$LOG_FILE"; then
        ok "Email envoyé avec succès !"
        echo ""
        echo "✅ Vérifiez votre boîte mail : $TEST_EMAIL"
        echo ""
        return 0
    else
        error "Échec de l'envoi SMTP (voir logs ci-dessus)"
    fi
}

# =============================================================================
# RESEND TEST
# =============================================================================

test_resend() {
    section "📧 TEST RESEND API (EDGE FUNCTIONS)"

    # Check Edge Functions
    if ! docker ps | grep -q "edge-functions"; then
        warn "Service Edge Functions non démarré"
        log "Démarrage d'Edge Functions..."
        docker compose -f "$SUPABASE_DIR/docker-compose.yml" up -d edge-functions
        sleep 10
    fi

    # Get anon key
    local anon_key=$(grep "^ANON_KEY=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "")
    if [ -z "$anon_key" ]; then
        error "ANON_KEY non trouvé dans $SUPABASE_DIR/.env"
    fi

    # Get Resend config
    local resend_from=""
    if [ -f "$SUPABASE_DIR/functions/.env" ]; then
        resend_from=$(grep "^RESEND_FROM_EMAIL=" "$SUPABASE_DIR/functions/.env" | cut -d= -f2 || echo "noreply@example.com")
    fi

    log "Configuration Resend :"
    log "  From     : $resend_from"
    log "  Endpoint : http://localhost:8000/functions/v1/send-email"

    # Send test email
    log "Envoi d'email de test via Resend API..."

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:8000/functions/v1/send-email" \
        -H "Authorization: Bearer $anon_key" \
        -H "Content-Type: application/json" \
        -d "{
            \"to\": \"$TEST_EMAIL\",
            \"subject\": \"Test Email from PI5-SETUP (Resend)\",
            \"html\": \"<html><body><h1>🎉 Test Email</h1><p>Ceci est un email de test envoyé depuis votre Raspberry Pi 5 via Resend API.</p><p><strong>Configuration :</strong> Resend via Supabase Edge Functions</p><p><strong>Date :</strong> $(date)</p><hr/><p><small>PI5-SETUP Email Test System</small></p></body></html>\"
        }" 2>&1) || true

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)

    log_debug "HTTP Code: $http_code"
    log_debug "Response: $body"

    echo ""
    echo "Réponse API :"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    echo ""

    if [ "$http_code" = "200" ]; then
        ok "Email envoyé avec succès !"
        echo ""
        echo "✅ Vérifiez votre boîte mail : $TEST_EMAIL"
        echo "📊 Analytics : https://resend.com/emails"
        echo ""
        return 0
    else
        error "Échec de l'envoi Resend (HTTP $http_code)"
    fi
}

# =============================================================================
# MAILU TEST
# =============================================================================

test_mailu() {
    section "📧 TEST MAILU"

    if [ ! -d "$MAILU_DIR" ]; then
        error "Mailu non installé dans $MAILU_DIR"
    fi

    # Check Mailu services
    local services_ok=true
    for service in front admin smtp; do
        if ! docker ps | grep -q "mailu.*$service"; then
            warn "Service Mailu $service non démarré"
            services_ok=false
        fi
    done

    if [ "$services_ok" = false ]; then
        warn "Certains services Mailu ne sont pas démarrés"
        if confirm "Démarrer les services Mailu ?"; then
            docker compose -f "$MAILU_DIR/docker-compose.yml" up -d
            sleep 15
        fi
    fi

    ok "Services Mailu actifs"

    # Get Mailu domain
    local mailu_domain=$(grep "^DOMAIN=" "$MAILU_DIR/mailu.env" | cut -d= -f2 || echo "unknown")

    log "Configuration Mailu :"
    log "  Domain  : $mailu_domain"
    log "  Webmail : https://mail.$mailu_domain/webmail"

    echo ""
    echo "Pour tester Mailu :"
    echo "  1. Connectez-vous au webmail : https://mail.$mailu_domain/webmail"
    echo "  2. Envoyez un email à : $TEST_EMAIL"
    echo "  3. Vérifiez la réception"
    echo ""
    echo "Ou utilisez swaks :"
    echo "  swaks --to $TEST_EMAIL \\"
    echo "    --from admin@$mailu_domain \\"
    echo "    --server mail.$mailu_domain:587 \\"
    echo "    --auth LOGIN \\"
    echo "    --auth-user admin@$mailu_domain \\"
    echo "    --auth-password YOUR_PASSWORD \\"
    echo "    --tls"
    echo ""

    warn "Test manuel requis pour Mailu"
}

# =============================================================================
# DIAGNOSTIC
# =============================================================================

display_diagnostic() {
    section "🔍 DIAGNOSTIC"

    log "Configuration système :"

    # Docker status
    if docker ps >/dev/null 2>&1; then
        ok "Docker accessible"
    else
        warn "Docker non accessible"
    fi

    # Supabase services
    if [ -d "$SUPABASE_DIR" ]; then
        log "Services Supabase :"
        docker ps --filter "name=supabase" --format "  {{.Names}}: {{.Status}}" | tee -a "$LOG_FILE"
    fi

    # Network connectivity
    log "Test de connectivité réseau :"
    if curl -s -o /dev/null -w "%{http_code}" https://api.resend.com --max-time 5 | grep -q "200\|401"; then
        ok "Internet accessible (Resend API OK)"
    else
        warn "Problème de connectivité réseau"
    fi

    echo ""
    log "Log complet : $LOG_FILE"
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_script_args() {
    parse_common_args "$@"
    set -- "${COMMON_POSITIONAL_ARGS[@]}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --smtp) FORCE_METHOD="smtp"; shift ;;
            --resend) FORCE_METHOD="resend"; shift ;;
            --mailu) FORCE_METHOD="mailu"; shift ;;
            *)
                if [[ "$1" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                    TEST_EMAIL="$1"
                else
                    warn "Argument inconnu : $1"
                fi
                shift
                ;;
        esac
    done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    section "📬 TEST DE CONFIGURATION EMAIL"

    log "Email test script v1.0.0"
    log "Log file: $LOG_FILE"

    detect_email_config
    get_test_email

    case "$DETECTED_METHOD" in
        smtp)
            test_smtp
            ;;
        resend)
            test_resend
            ;;
        mailu)
            test_mailu
            ;;
        *)
            error "Méthode inconnue : $DETECTED_METHOD"
            ;;
    esac

    display_diagnostic

    ok "Test terminé !"
}

parse_script_args "$@"
main
