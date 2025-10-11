#!/bin/bash
# =============================================================================
# RESEND API SETUP SCRIPT - Integrate Resend for Email Sending
# =============================================================================
#
# Purpose: Configure Resend API for sending transactional emails from Supabase
#          Edge Functions with modern API, analytics, and React Email templates
#
# Author: PI5-SETUP Project
# Version: 1.0.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 10-15 minutes
#
# Features:
# - Resend API key configuration
# - Edge Function template generation
# - Domain verification guidance
# - Test email sending
# - **IDEMPOTENT** (safe to run multiple times)
# - **INTELLIGENT DEBUG** (auto-capture errors with context)
#
# Usage:
#   sudo bash 02-resend-setup.sh [OPTIONS]
#
# Options:
#   --dry-run          Show what would be done without making changes
#   --yes, -y          Skip confirmation prompts
#   --verbose, -v      Verbose output
#   --force            Force reconfiguration
#
# Environment variables (optional):
#   RESEND_API_KEY=re_xxxxx
#   RESEND_FROM_EMAIL=noreply@yourdomain.com
#   RESEND_DOMAIN=yourdomain.com
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
LOG_FILE="${LOG_DIR}/resend-setup-$(date +%Y%m%d-%H%M%S).log"
SUPABASE_DIR="/home/pi/stacks/supabase"
FUNCTIONS_DIR="$SUPABASE_DIR/functions"
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
FORCE_RECONFIG=0

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMPLATES_DIR"

# =============================================================================
# ERROR HANDLING WITH CONTEXT
# =============================================================================

trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR

handle_error() {
    local exit_code=$1
    local line_num=$2
    local command=$3

    log_error "Erreur ligne $line_num: $command (code: $exit_code)"

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
        echo "   API Key : ${RESEND_API_KEY:+configured}"
        echo "   Domain  : ${RESEND_DOMAIN:-non défini}"
        echo ""
        echo "📝 Logs : $LOG_FILE"
        echo ""
        echo "💡 Actions suggérées :"
        echo "   1. Vérifier API key Resend"
        echo "   2. Vérifier domaine vérifié sur Resend.com"
        echo "   3. Relancer avec --verbose"
        echo ""
    } | tee -a "$LOG_FILE"

    exit "$exit_code"
}

# =============================================================================
# LOGGING
# =============================================================================

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

# =============================================================================
# IDEMPOTENCY CHECK
# =============================================================================

check_existing_config() {
    section "🔍 VÉRIFICATION CONFIGURATION EXISTANTE"

    local resend_configured=false

    if [ -d "$FUNCTIONS_DIR/send-email" ]; then
        if [ -f "$FUNCTIONS_DIR/send-email/index.ts" ]; then
            if grep -q "Resend" "$FUNCTIONS_DIR/send-email/index.ts" 2>/dev/null; then
                resend_configured=true
            fi
        fi
    fi

    if [ "$resend_configured" == "true" ]; then
        if [ "$FORCE_RECONFIG" -eq 1 ]; then
            warn "Flag --force détecté : reconfiguration forcée"
            return 1
        fi

        warn "Edge Function Resend déjà configurée"
        echo ""
        echo "Options :"
        echo "  1) Garder la configuration actuelle (quitter)"
        echo "  2) Reconfigurer (remplacer)"
        echo ""

        if [ "$ASSUME_YES" -eq 1 ]; then
            log "Mode --yes : conservation de la config existante"
            return 0
        fi

        while true; do
            read -p "Choix [1-2]: " choice
            case "$choice" in
                1) ok "Configuration existante conservée"; exit 0 ;;
                2) log "Reconfiguration demandée"; return 1 ;;
                *) echo "Choix invalide" ;;
            esac
        done
    fi

    ok "Pas de configuration Resend existante"
    return 1
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_prerequisites() {
    section "✅ VALIDATION DES PRÉREQUIS"

    require_root

    if [ ! -d "$SUPABASE_DIR" ]; then
        error "Supabase non installé dans $SUPABASE_DIR"
    fi
    ok "Supabase trouvé"

    if ! docker ps >/dev/null 2>&1; then
        error "Docker n'est pas accessible"
    fi
    ok "Docker accessible"

    # Check if Edge Functions service exists
    if ! docker ps | grep -q "supabase.*functions" && ! docker ps | grep -q "edge-functions"; then
        warn "Service Edge Functions non démarré"
        log "Edge Functions sera démarré automatiquement"
    else
        ok "Edge Functions service détecté"
    fi
}

# =============================================================================
# RESEND CONFIGURATION
# =============================================================================

configure_resend() {
    section "🔑 CONFIGURATION RESEND API"

    echo "Configuration Resend nécessite :"
    echo ""
    echo "  1. Créer un compte sur https://resend.com (gratuit)"
    echo "  2. Obtenir une API Key"
    echo "  3. Vérifier votre domaine"
    echo ""
    echo "Guide rapide :"
    echo "  → Dashboard Resend : https://resend.com/api-keys"
    echo "  → Créer une API Key"
    echo "  → La clé commence par 're_'"
    echo ""
    echo "  → Domains : https://resend.com/domains"
    echo "  → Add Domain"
    echo "  → Ajouter les DNS records (SPF, DKIM, DMARC)"
    echo ""

    if ! ask_yes_no "Avez-vous une API Key Resend ?" "y"; then
        log "Configuration annulée. Créez d'abord un compte Resend."
        exit 0
    fi

    # Get API key
    if [ -z "${RESEND_API_KEY:-}" ]; then
        while true; do
            read -s -p "$(echo -e "\033[1;33m❓ Entrez votre API Key Resend (re_xxx):\033[0m ") " api_key
            echo ""
            if [[ "$api_key" =~ ^re_ ]]; then
                RESEND_API_KEY="$api_key"
                break
            else
                echo "API Key invalide (doit commencer par 're_')"
            fi
        done
    fi

    ok "API Key configurée"

    # Get domain
    if [ -z "${RESEND_DOMAIN:-}" ]; then
        read -p "$(echo -e "\033[1;33m❓ Entrez votre domaine vérifié (ex: yourdomain.com):\033[0m ") " domain
        RESEND_DOMAIN="$domain"
    fi

    ok "Domaine: $RESEND_DOMAIN"

    # Get from email
    if [ -z "${RESEND_FROM_EMAIL:-}" ]; then
        RESEND_FROM_EMAIL="noreply@${RESEND_DOMAIN}"
        read -p "$(echo -e "\033[1;33m❓ Adresse expéditeur (défaut: $RESEND_FROM_EMAIL):\033[0m ") " from_email
        RESEND_FROM_EMAIL="${from_email:-$RESEND_FROM_EMAIL}"
    fi

    ok "From: $RESEND_FROM_EMAIL"
}

# =============================================================================
# TEST RESEND API
# =============================================================================

test_resend_connection() {
    section "🔍 TEST DE CONNEXION RESEND API"

    log "Test de la clé API..."

    # Test with curl
    local response
    response=$(curl -s -w "\n%{http_code}" -X GET \
        "https://api.resend.com/api-keys" \
        -H "Authorization: Bearer $RESEND_API_KEY" \
        -H "Content-Type: application/json" 2>&1) || true

    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | head -n-1)

    log_debug "HTTP Code: $http_code"
    log_debug "Response: $body"

    if [ "$http_code" = "200" ]; then
        ok "API Key valide !"
    else
        error "API Key invalide (HTTP $http_code). Vérifiez votre clé sur resend.com"
    fi
}

# =============================================================================
# CREATE EDGE FUNCTION
# =============================================================================

create_edge_function() {
    section "📝 CRÉATION DE L'EDGE FUNCTION"

    # Create functions directory if not exists
    run_cmd mkdir -p "$FUNCTIONS_DIR/send-email"

    # Backup existing function if present
    if [ -f "$FUNCTIONS_DIR/send-email/index.ts" ]; then
        local backup_file="$BACKUP_DIR/send-email-index-$(date +%Y%m%d-%H%M%S).ts"
        run_cmd cp "$FUNCTIONS_DIR/send-email/index.ts" "$backup_file"
        ok "Backup fonction existante : $backup_file"
    fi

    # Create Edge Function with Resend
    log "Création de send-email/index.ts..."

    cat > "$FUNCTIONS_DIR/send-email/index.ts" <<'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!

interface EmailRequest {
  to: string | string[]
  subject: string
  html?: string
  text?: string
  from?: string
  replyTo?: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, from, replyTo }: EmailRequest = await req.json()

    // Validate required fields
    if (!to || !subject || (!html && !text)) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, subject, and html or text" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Send email via Resend API
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: from || Deno.env.get("RESEND_FROM_EMAIL"),
        to: Array.isArray(to) ? to : [to],
        subject,
        html,
        text,
        reply_to: replyTo,
      }),
    })

    const data = await response.json()

    if (!response.ok) {
      console.error("Resend API error:", data)
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: data }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, id: data.id, message: "Email sent successfully" }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error in send-email function:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
EOF

    ok "send-email/index.ts créé"

    # Create CORS helper if not exists
    if [ ! -f "$FUNCTIONS_DIR/_shared/cors.ts" ]; then
        log "Création de _shared/cors.ts..."
        run_cmd mkdir -p "$FUNCTIONS_DIR/_shared"

        cat > "$FUNCTIONS_DIR/_shared/cors.ts" <<'EOF'
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
EOF
        ok "_shared/cors.ts créé"
    fi

    # Create .env for Edge Functions
    log "Configuration des variables d'environnement..."

    if [ ! -f "$FUNCTIONS_DIR/.env" ]; then
        touch "$FUNCTIONS_DIR/.env"
    fi

    # Remove old Resend config if exists
    sed -i.bak '/^RESEND_/d' "$FUNCTIONS_DIR/.env" 2>/dev/null || true

    # Add new config
    cat >> "$FUNCTIONS_DIR/.env" <<EOF

# Resend Configuration (added by resend-setup.sh on $(date))
RESEND_API_KEY=${RESEND_API_KEY}
RESEND_FROM_EMAIL=${RESEND_FROM_EMAIL}
EOF

    ok "Variables d'environnement configurées"
}

# =============================================================================
# UPDATE DOCKER COMPOSE
# =============================================================================

update_docker_compose() {
    section "🔧 MISE À JOUR DOCKER COMPOSE"

    log "Ajout des variables Resend au service Edge Functions..."

    # Check if env_file is already set
    if grep -q "env_file:" "$SUPABASE_DIR/docker-compose.yml" | grep -q "functions/.env"; then
        ok "Configuration env_file déjà présente"
    else
        # Add env_file to edge-functions service
        log "Ajout de env_file au service edge-functions..."

        # Backup
        cp "$SUPABASE_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose-$(date +%Y%m%d-%H%M%S).yml"

        # Add env_file (simplified approach - may need manual adjustment)
        warn "Ajout manuel requis : Ajouter 'env_file: - ./functions/.env' au service edge-functions"
        log "Backup créé dans $BACKUP_DIR"
    fi
}

# =============================================================================
# DEPLOY FUNCTION
# =============================================================================

deploy_function() {
    section "🚀 DÉPLOIEMENT DE LA FONCTION"

    log "Redémarrage du service Edge Functions..."

    if docker ps | grep -q "edge-functions"; then
        docker compose -f "$SUPABASE_DIR/docker-compose.yml" restart edge-functions 2>&1 | tee -a "$LOG_FILE"
    else
        docker compose -f "$SUPABASE_DIR/docker-compose.yml" up -d edge-functions 2>&1 | tee -a "$LOG_FILE"
    fi

    log "Attente du démarrage (10 secondes)..."
    sleep 10

    if docker ps | grep -q "edge-functions"; then
        ok "Edge Functions redémarré avec succès"
    else
        error "Échec du démarrage d'Edge Functions"
    fi
}

# =============================================================================
# TEST EMAIL
# =============================================================================

test_email_function() {
    section "📬 TEST D'ENVOI D'EMAIL"

    echo "Pour tester la fonction :"
    echo ""
    echo "curl -X POST http://localhost:8000/functions/v1/send-email \\"
    echo "  -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{"
    echo "    \"to\": \"your-email@example.com\","
    echo "    \"subject\": \"Test Resend\","
    echo "    \"html\": \"<h1>Hello from Resend!</h1>\""
    echo "  }'"
    echo ""

    if ask_yes_no "Voulez-vous envoyer un email de test maintenant ?" "n"; then
        local test_email
        read -p "Entrez votre email de test : " test_email

        # Get anon key
        local anon_key=$(grep "^ANON_KEY=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "")
        if [ -z "$anon_key" ]; then
            warn "ANON_KEY non trouvé dans .env, test ignoré"
            return
        fi

        log "Envoi d'email de test à $test_email..."

        curl -X POST "http://localhost:8000/functions/v1/send-email" \
            -H "Authorization: Bearer $anon_key" \
            -H "Content-Type: application/json" \
            -d "{\"to\":\"$test_email\",\"subject\":\"Test Resend API\",\"html\":\"<h1>Hello!</h1><p>Email envoyé via Resend API depuis Supabase Edge Functions.</p>\"}" \
            2>&1 | tee -a "$LOG_FILE"

        echo ""
        ok "Requête envoyée. Vérifiez votre boîte mail et les logs."
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================

display_summary() {
    section "✅ CONFIGURATION RESEND TERMINÉE"

    echo -e "\033[1;32m🎉 Resend API configuré avec succès !\033[0m"
    echo ""
    echo "📧 Configuration :"
    echo "  API Key  : ${RESEND_API_KEY:0:10}..."
    echo "  Domain   : $RESEND_DOMAIN"
    echo "  From     : $RESEND_FROM_EMAIL"
    echo ""
    echo "📁 Fichiers créés :"
    echo "  → $FUNCTIONS_DIR/send-email/index.ts"
    echo "  → $FUNCTIONS_DIR/_shared/cors.ts"
    echo "  → $FUNCTIONS_DIR/.env"
    echo ""
    echo "🧪 Pour tester :"
    echo "  curl -X POST http://localhost:8000/functions/v1/send-email \\"
    echo "    -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
    echo "    -d '{\"to\":\"test@example.com\",\"subject\":\"Test\",\"html\":\"<h1>Hello</h1>\"}'"
    echo ""
    echo "📊 Analytics Resend :"
    echo "  → https://resend.com/emails"
    echo ""
    echo "📚 Documentation :"
    echo "  → Resend API : https://resend.com/docs"
    echo "  → Guide : $EMAIL_DIR/GUIDE-EMAIL-CHOICES.md"
    echo ""
    echo "📝 Log : $LOG_FILE"
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_script_args() {
    parse_common_args "$@"
    set -- "${COMMON_POSITIONAL_ARGS[@]}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) FORCE_RECONFIG=1; shift ;;
            *) warn "Argument inconnu ignoré : $1"; shift ;;
        esac
    done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    section "📧 CONFIGURATION RESEND API"

    log "Script Resend setup v1.0.0"
    log "Log file: $LOG_FILE"

    validate_prerequisites

    if check_existing_config; then
        exit 0
    fi

    configure_resend
    test_resend_connection
    create_edge_function
    update_docker_compose
    deploy_function
    test_email_function
    display_summary

    ok "Script terminé avec succès !"
}

parse_script_args "$@"
main
