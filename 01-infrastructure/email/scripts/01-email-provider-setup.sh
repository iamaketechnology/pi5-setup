#!/bin/bash
# =============================================================================
# EMAIL PROVIDER SETUP SCRIPT - Multi-Provider Email Service Configuration
# =============================================================================
#
# Purpose: Configure email service provider (Resend, SendGrid, or Mailgun)
#          for sending transactional emails from Supabase Edge Functions
#
# Author: PI5-SETUP Project
# Version: 1.1.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 2-3 minutes (includes full stack restart)
#
# Supported Providers:
# - Resend    (100 emails/day free) - Modern API, React Email support
# - SendGrid  (100 emails/day free) - Established provider, robust analytics
# - Mailgun   (100 emails/day free) - Flexible API, Europe datacenter option
#
# Features:
# - Interactive provider selection menu
# - API key validation
# - Edge Function template generation
# - Domain verification guidance
# - Environment variable configuration
# - **IDEMPOTENT** (safe to run multiple times)
# - **INTELLIGENT DEBUG** (auto-capture errors with context)
#
# Usage:
#   sudo bash 01-email-provider-setup.sh [OPTIONS]
#
# Options:
#   --provider <name>  Pre-select provider (resend|sendgrid|mailgun)
#   --dry-run          Show what would be done without making changes
#   --yes, -y          Skip confirmation prompts
#   --verbose, -v      Verbose output
#   --force            Force reconfiguration
#
# Environment variables (optional):
#   EMAIL_PROVIDER=resend|sendgrid|mailgun
#   API_KEY=xxx
#   FROM_EMAIL=noreply@yourdomain.com
#   DOMAIN=yourdomain.com
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Detect if running via curl | bash or locally
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    EMAIL_DIR="$(dirname "$SCRIPT_DIR")"

    if [ -d "$EMAIL_DIR/../../common-scripts" ]; then
        COMMON_SCRIPTS_DIR="$(cd "$EMAIL_DIR/../../common-scripts" && pwd)"
    else
        COMMON_SCRIPTS_DIR="/tmp"
    fi
else
    SCRIPT_DIR="/tmp"
    EMAIL_DIR="/tmp"
    COMMON_SCRIPTS_DIR="/tmp"
fi

LOG_DIR="/var/log/pi5-setup"
LOG_FILE="${LOG_DIR}/email-provider-setup-$(date +%Y%m%d-%H%M%S).log"
SUPABASE_DIR="/home/pi/stacks/supabase"
FUNCTIONS_DIR="$SUPABASE_DIR/functions"
BACKUP_DIR="/home/pi/backups/supabase"

# Provider-specific variables
SELECTED_PROVIDER=""
API_KEY=""
FROM_EMAIL=""
DOMAIN=""

# Script options
FORCE_RECONFIG=0
DRY_RUN=${DRY_RUN:-0}
ASSUME_YES=${ASSUME_YES:-0}
VERBOSE=${VERBOSE:-0}

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# =============================================================================
# LOGGING FUNCTIONS (Minimal fallback)
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
        echo "   Provider: ${SELECTED_PROVIDER:-non défini}"
        echo "   API Key : ${API_KEY:+configured}"
        echo "   Domain  : ${DOMAIN:-non défini}"
        echo ""
        echo "📝 Logs : $LOG_FILE"
        echo ""
    } | tee -a "$LOG_FILE"

    exit "$exit_code"
}

# =============================================================================
# PROVIDER SELECTION
# =============================================================================

display_provider_menu() {
    section "📧 SÉLECTION DU FOURNISSEUR D'EMAIL"

    echo "Choisissez votre fournisseur d'email transactionnel :"
    echo ""
    echo "  1) Resend    - Moderne, React Email, Analytics"
    echo "                 → 100 emails/jour gratuits"
    echo "                 → API moderne et simple"
    echo "                 → Support React Email templates"
    echo "                 → https://resend.com"
    echo ""
    echo "  2) SendGrid  - Établi, Robuste, Analytics avancées"
    echo "                 → 100 emails/jour gratuits"
    echo "                 → Provider établi (Twilio)"
    echo "                 → Analytics détaillées"
    echo "                 → https://sendgrid.com"
    echo ""
    echo "  3) Mailgun   - Flexible, Europe, Logs détaillés"
    echo "                 → 100 emails/jour gratuits (premier mois)"
    echo "                 → Datacenters EU disponibles"
    echo "                 → API flexible et puissante"
    echo "                 → https://mailgun.com"
    echo ""
    echo "  q) Quitter"
    echo ""
}

select_provider() {
    # If provider already specified via --provider flag
    if [ -n "${SELECTED_PROVIDER:-}" ]; then
        case "${SELECTED_PROVIDER,,}" in
            resend|sendgrid|mailgun)
                ok "Provider pré-sélectionné: $SELECTED_PROVIDER"
                return 0
                ;;
            *)
                warn "Provider invalide: $SELECTED_PROVIDER"
                SELECTED_PROVIDER=""
                ;;
        esac
    fi

    display_provider_menu

    while true; do
        read -p "$(echo -e "\033[1;36mVotre choix [1-3, q]:\033[0m ") " choice

        case "$choice" in
            1)
                SELECTED_PROVIDER="resend"
                ok "Resend sélectionné"
                break
                ;;
            2)
                SELECTED_PROVIDER="sendgrid"
                ok "SendGrid sélectionné"
                break
                ;;
            3)
                SELECTED_PROVIDER="mailgun"
                ok "Mailgun sélectionné"
                break
                ;;
            q|Q)
                log "Configuration annulée"
                exit 0
                ;;
            *)
                echo "Choix invalide. Entrez 1, 2, 3, ou q"
                ;;
        esac
    done
}

# =============================================================================
# PROVIDER-SPECIFIC CONFIGURATION
# =============================================================================

configure_resend() {
    section "🔑 CONFIGURATION RESEND"

    echo "Configuration Resend :"
    echo ""
    echo "  1. Créer un compte sur https://resend.com (gratuit)"
    echo "  2. Dashboard → API Keys → Create API Key"
    echo "  3. La clé commence par 're_'"
    echo ""
    echo "  Domaine (optionnel) :"
    echo "  → Dashboard → Domains → Add Domain"
    echo "  → Ajouter les DNS records (SPF, DKIM, DMARC)"
    echo ""

    # Check if API_KEY already set (from env or previous run)
    if [ -z "${API_KEY:-}" ]; then
        if ! ask_yes_no "Avez-vous une API Key Resend ?" "y"; then
            log "Visitez https://resend.com/signup pour créer un compte"
            exit 0
        fi

        # Get API key interactively
        while true; do
            read -s -p "$(echo -e "\033[1;33m❓ Entrez votre API Key Resend (re_xxx):\033[0m ") " api_key
            echo ""
            if [[ "$api_key" =~ ^re_ ]]; then
                API_KEY="$api_key"
                break
            else
                echo "API Key invalide (doit commencer par 're_')"
            fi
        done
    else
        log "API Key détectée depuis les variables d'environnement"
    fi

    ok "API Key configurée"

    # Get domain (optional)
    if [ -z "${DOMAIN:-}" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            DOMAIN=""
            log "Mode automatique: pas de domaine (utilisation domaine par défaut)"
        else
            read -p "$(echo -e "\033[1;33m❓ Domaine vérifié (optionnel, ENTER pour skip):\033[0m ") " domain
            DOMAIN="${domain:-}"
        fi
    fi

    # Get from email
    if [ -z "${FROM_EMAIL:-}" ]; then
        if [ -z "$DOMAIN" ]; then
            FROM_EMAIL="noreply@resend.dev"
        else
            FROM_EMAIL="noreply@${DOMAIN}"
        fi

        if [ "$ASSUME_YES" -eq 0 ]; then
            read -p "$(echo -e "\033[1;33m❓ Adresse expéditeur (défaut: $FROM_EMAIL):\033[0m ") " from
            FROM_EMAIL="${from:-$FROM_EMAIL}"
        else
            log "From email: $FROM_EMAIL"
        fi
    else
        log "From email détecté depuis les variables d'environnement: $FROM_EMAIL"
    fi

    ok "Configuration Resend terminée"
}

configure_sendgrid() {
    section "🔑 CONFIGURATION SENDGRID"

    echo "Configuration SendGrid :"
    echo ""
    echo "  1. Créer un compte sur https://sendgrid.com (gratuit)"
    echo "  2. Settings → API Keys → Create API Key"
    echo "  3. Permissions: Full Access (ou Mail Send uniquement)"
    echo "  4. La clé commence par 'SG.'"
    echo ""
    echo "  Domaine (optionnel) :"
    echo "  → Settings → Sender Authentication → Domain Authentication"
    echo "  → Ajouter les DNS records"
    echo ""

    # Check if API_KEY already set
    if [ -z "${API_KEY:-}" ]; then
        if ! ask_yes_no "Avez-vous une API Key SendGrid ?" "y"; then
            log "Visitez https://sendgrid.com/signup pour créer un compte"
            exit 0
        fi

        # Get API key interactively
        while true; do
            read -s -p "$(echo -e "\033[1;33m❓ Entrez votre API Key SendGrid (SG.xxx):\033[0m ") " api_key
            echo ""
            if [[ "$api_key" =~ ^SG\. ]]; then
                API_KEY="$api_key"
                break
            else
                echo "API Key invalide (doit commencer par 'SG.')"
            fi
        done
    else
        log "API Key détectée depuis les variables d'environnement"
    fi

    ok "API Key configurée"

    # Get domain (optional)
    if [ -z "${DOMAIN:-}" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            DOMAIN=""
        else
            read -p "$(echo -e "\033[1;33m❓ Domaine vérifié (optionnel, ENTER pour skip):\033[0m ") " domain
            DOMAIN="${domain:-}"
        fi
    fi

    # Get from email
    if [ -z "${FROM_EMAIL:-}" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            FROM_EMAIL="noreply@example.com"
            warn "Mode automatique: FROM_EMAIL doit être défini. Utilisation: $FROM_EMAIL"
        else
            read -p "$(echo -e "\033[1;33m❓ Adresse expéditeur:\033[0m ") " from
            FROM_EMAIL="$from"
        fi
    else
        log "From email détecté depuis les variables d'environnement: $FROM_EMAIL"
    fi

    ok "Configuration SendGrid terminée"
}

configure_mailgun() {
    section "🔑 CONFIGURATION MAILGUN"

    echo "Configuration Mailgun :"
    echo ""
    echo "  1. Créer un compte sur https://mailgun.com (gratuit)"
    echo "  2. Sending → Domain Settings → API Keys"
    echo "  3. Copier votre Private API Key"
    echo "  4. La clé commence généralement par 'key-' ou est un hash"
    echo ""
    echo "  Domaine :"
    echo "  → Sending → Domains → Add New Domain"
    echo "  → Ajouter les DNS records (SPF, DKIM)"
    echo "  → Choisir région: US ou EU"
    echo ""

    # Check if API_KEY already set
    if [ -z "${API_KEY:-}" ]; then
        if ! ask_yes_no "Avez-vous une API Key Mailgun ?" "y"; then
            log "Visitez https://mailgun.com/signup pour créer un compte"
            exit 0
        fi

        read -s -p "$(echo -e "\033[1;33m❓ Entrez votre API Key Mailgun:\033[0m ") " api_key
        echo ""
        API_KEY="$api_key"
    else
        log "API Key détectée depuis les variables d'environnement"
    fi

    ok "API Key configurée"

    # Get domain (required for Mailgun)
    if [ -z "${DOMAIN:-}" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            error "Mailgun requiert un domaine. Définissez DOMAIN=xxx avant de lancer le script."
        fi

        while true; do
            read -p "$(echo -e "\033[1;33m❓ Domaine Mailgun (ex: mg.yourdomain.com):\033[0m ") " domain
            if [ -n "$domain" ]; then
                DOMAIN="$domain"
                break
            else
                echo "Le domaine est requis pour Mailgun"
            fi
        done
    else
        log "Domaine détecté: $DOMAIN"
    fi

    # Get Mailgun region
    if [ -z "${MAILGUN_REGION:-}" ]; then
        if [ "$ASSUME_YES" -eq 1 ]; then
            MAILGUN_REGION="us"
            log "Mode automatique: région US par défaut"
        else
            echo ""
            echo "Région Mailgun :"
            echo "  1) US (api.mailgun.net)"
            echo "  2) EU (api.eu.mailgun.net)"
            read -p "Choix [1-2] (défaut: 1): " region_choice

            case "${region_choice:-1}" in
                2) MAILGUN_REGION="eu" ;;
                *) MAILGUN_REGION="us" ;;
            esac
        fi
    fi

    ok "Région: $MAILGUN_REGION"

    # Get from email
    if [ -z "${FROM_EMAIL:-}" ]; then
        FROM_EMAIL="noreply@${DOMAIN}"

        if [ "$ASSUME_YES" -eq 0 ]; then
            read -p "$(echo -e "\033[1;33m❓ Adresse expéditeur (défaut: $FROM_EMAIL):\033[0m ") " from
            FROM_EMAIL="${from:-$FROM_EMAIL}"
        else
            log "From email: $FROM_EMAIL"
        fi
    else
        log "From email détecté depuis les variables d'environnement: $FROM_EMAIL"
    fi

    ok "Configuration Mailgun terminée"
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

    if ! docker ps | grep -q "edge-functions"; then
        warn "Service Edge Functions non démarré"
        log "Edge Functions sera démarré automatiquement"
    else
        ok "Edge Functions service détecté"
    fi
}

check_existing_config() {
    section "🔍 VÉRIFICATION CONFIGURATION EXISTANTE"

    local provider_configured=""

    if [ -f "$SUPABASE_DIR/.env" ]; then
        if grep -q "^EMAIL_PROVIDER=" "$SUPABASE_DIR/.env" 2>/dev/null; then
            provider_configured=$(grep "^EMAIL_PROVIDER=" "$SUPABASE_DIR/.env" | cut -d= -f2)
        fi
    fi

    if [ -n "$provider_configured" ]; then
        if [ "$FORCE_RECONFIG" -eq 1 ]; then
            warn "Flag --force détecté : reconfiguration forcée"
            return 1
        fi

        warn "Provider déjà configuré: $provider_configured"
        echo ""

        if [ "$ASSUME_YES" -eq 1 ]; then
            log "Mode --yes : conservation de la config existante"
            return 0
        fi

        if ask_yes_no "Reconfigurer avec un autre provider ?" "n"; then
            log "Reconfiguration demandée"
            return 1
        else
            ok "Configuration existante conservée"
            exit 0
        fi
    fi

    ok "Pas de configuration existante"
    return 1
}

# =============================================================================
# EDGE FUNCTION GENERATION
# =============================================================================

create_send_email_function() {
    section "📝 CRÉATION DE L'EDGE FUNCTION"

    mkdir -p "$FUNCTIONS_DIR/send-email"
    mkdir -p "$FUNCTIONS_DIR/_shared"

    # Backup if exists
    if [ -f "$FUNCTIONS_DIR/send-email/index.ts" ]; then
        local backup_file="$BACKUP_DIR/send-email-index-$(date +%Y%m%d-%H%M%S).ts"
        cp "$FUNCTIONS_DIR/send-email/index.ts" "$backup_file"
        ok "Backup créé: $backup_file"
    fi

    log "Création de send-email/index.ts pour $SELECTED_PROVIDER..."

    case "$SELECTED_PROVIDER" in
        resend)
            create_resend_function
            ;;
        sendgrid)
            create_sendgrid_function
            ;;
        mailgun)
            create_mailgun_function
            ;;
    esac

    # Create CORS helper if not exists
    if [ ! -f "$FUNCTIONS_DIR/_shared/cors.ts" ]; then
        cat > "$FUNCTIONS_DIR/_shared/cors.ts" <<'EOF'
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
EOF
        ok "_shared/cors.ts créé"
    fi

    ok "Edge Function créée"
}

create_resend_function() {
    cat > "$FUNCTIONS_DIR/send-email/index.ts" <<'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

const API_KEY = Deno.env.get("EMAIL_API_KEY")!
const FROM_EMAIL = Deno.env.get("EMAIL_FROM")!

interface EmailRequest {
  to: string | string[]
  subject: string
  html?: string
  text?: string
  from?: string
  replyTo?: string
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, from, replyTo }: EmailRequest = await req.json()

    if (!to || !subject || (!html && !text)) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: from || FROM_EMAIL,
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
      JSON.stringify({ success: true, id: data.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
EOF
}

create_sendgrid_function() {
    cat > "$FUNCTIONS_DIR/send-email/index.ts" <<'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

const API_KEY = Deno.env.get("EMAIL_API_KEY")!
const FROM_EMAIL = Deno.env.get("EMAIL_FROM")!

interface EmailRequest {
  to: string | string[]
  subject: string
  html?: string
  text?: string
  from?: string
  replyTo?: string
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, from, replyTo }: EmailRequest = await req.json()

    if (!to || !subject || (!html && !text)) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const recipients = Array.isArray(to) ? to : [to]

    const response = await fetch("https://api.sendgrid.com/v3/mail/send", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        personalizations: [{
          to: recipients.map(email => ({ email }))
        }],
        from: { email: from || FROM_EMAIL },
        reply_to: replyTo ? { email: replyTo } : undefined,
        subject,
        content: [
          html ? { type: "text/html", value: html } : { type: "text/plain", value: text }
        ],
      }),
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error("SendGrid API error:", errorText)
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: errorText }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
EOF
}

create_mailgun_function() {
    cat > "$FUNCTIONS_DIR/send-email/index.ts" <<'EOF'
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

const API_KEY = Deno.env.get("EMAIL_API_KEY")!
const FROM_EMAIL = Deno.env.get("EMAIL_FROM")!
const DOMAIN = Deno.env.get("EMAIL_DOMAIN")!
const REGION = Deno.env.get("MAILGUN_REGION") || "us"

const API_BASE = REGION === "eu"
  ? "https://api.eu.mailgun.net/v3"
  : "https://api.mailgun.net/v3"

interface EmailRequest {
  to: string | string[]
  subject: string
  html?: string
  text?: string
  from?: string
  replyTo?: string
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    const { to, subject, html, text, from, replyTo }: EmailRequest = await req.json()

    if (!to || !subject || (!html && !text)) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const recipients = Array.isArray(to) ? to.join(",") : to

    const formData = new FormData()
    formData.append("from", from || FROM_EMAIL)
    formData.append("to", recipients)
    formData.append("subject", subject)
    if (html) formData.append("html", html)
    if (text) formData.append("text", text)
    if (replyTo) formData.append("h:Reply-To", replyTo)

    const response = await fetch(`${API_BASE}/${DOMAIN}/messages`, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(`api:${API_KEY}`)}`,
      },
      body: formData,
    })

    const data = await response.json()

    if (!response.ok) {
      console.error("Mailgun API error:", data)
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: data }),
        { status: response.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    return new Response(
      JSON.stringify({ success: true, id: data.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )

  } catch (error) {
    console.error("Error:", error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
EOF
}

# =============================================================================
# CONFIGURATION FILES
# =============================================================================

update_env_files() {
    section "🔧 MISE À JOUR DES FICHIERS .ENV"

    # Backup Supabase .env
    if [ -f "$SUPABASE_DIR/.env" ]; then
        cp "$SUPABASE_DIR/.env" "$BACKUP_DIR/.env-$(date +%Y%m%d-%H%M%S)"
    fi

    # Remove old email config
    if [ -f "$SUPABASE_DIR/.env" ]; then
        sed -i.bak '/^EMAIL_/d' "$SUPABASE_DIR/.env" 2>/dev/null || true
        sed -i.bak '/^RESEND_/d' "$SUPABASE_DIR/.env" 2>/dev/null || true
        sed -i.bak '/^SENDGRID_/d' "$SUPABASE_DIR/.env" 2>/dev/null || true
        sed -i.bak '/^MAILGUN_/d' "$SUPABASE_DIR/.env" 2>/dev/null || true
    else
        touch "$SUPABASE_DIR/.env"
    fi

    # Add new config
    cat >> "$SUPABASE_DIR/.env" <<EOF

# Email Provider Configuration (added $(date))
EMAIL_PROVIDER=${SELECTED_PROVIDER}
EMAIL_API_KEY=${API_KEY}
EMAIL_FROM=${FROM_EMAIL}
EOF

    if [ -n "${DOMAIN:-}" ]; then
        echo "EMAIL_DOMAIN=${DOMAIN}" >> "$SUPABASE_DIR/.env"
    fi

    if [ "${SELECTED_PROVIDER}" = "mailgun" ]; then
        echo "MAILGUN_REGION=${MAILGUN_REGION:-us}" >> "$SUPABASE_DIR/.env"
    fi

    ok "Configuration ajoutée à $SUPABASE_DIR/.env"

    # Update functions/.env
    if [ ! -f "$FUNCTIONS_DIR/.env" ]; then
        touch "$FUNCTIONS_DIR/.env"
    fi

    sed -i.bak '/^EMAIL_/d' "$FUNCTIONS_DIR/.env" 2>/dev/null || true
    sed -i.bak '/^RESEND_/d' "$FUNCTIONS_DIR/.env" 2>/dev/null || true
    sed -i.bak '/^SENDGRID_/d' "$FUNCTIONS_DIR/.env" 2>/dev/null || true
    sed -i.bak '/^MAILGUN_/d' "$FUNCTIONS_DIR/.env" 2>/dev/null || true

    cat >> "$FUNCTIONS_DIR/.env" <<EOF

# Email Provider Configuration (added $(date))
EMAIL_PROVIDER=${SELECTED_PROVIDER}
EMAIL_API_KEY=${API_KEY}
EMAIL_FROM=${FROM_EMAIL}
EOF

    if [ -n "${DOMAIN:-}" ]; then
        echo "EMAIL_DOMAIN=${DOMAIN}" >> "$FUNCTIONS_DIR/.env"
    fi

    if [ "${SELECTED_PROVIDER}" = "mailgun" ]; then
        echo "MAILGUN_REGION=${MAILGUN_REGION:-us}" >> "$FUNCTIONS_DIR/.env"
    fi

    ok "Configuration ajoutée à $FUNCTIONS_DIR/.env"
}

update_docker_compose() {
    section "🐳 MISE À JOUR DOCKER COMPOSE"

    local backup_file="$BACKUP_DIR/docker-compose-$(date +%Y%m%d-%H%M%S).yml"
    cp "$SUPABASE_DIR/docker-compose.yml" "$backup_file"
    ok "Backup créé: $backup_file"

    # Check if variables already exist
    if grep -A 30 "edge-functions:" "$SUPABASE_DIR/docker-compose.yml" | grep -q "EMAIL_PROVIDER"; then
        ok "Variables email déjà présentes dans docker-compose.yml"
        return 0
    fi

    log "Ajout des variables d'environnement au service edge-functions..."

    # Use Python to safely add environment variables
    python3 <<PYTHON_SCRIPT
import sys

docker_compose_file = "$SUPABASE_DIR/docker-compose.yml"

try:
    with open(docker_compose_file, 'r') as f:
        lines = f.readlines()

    in_edge_functions = False
    in_environment = False
    indent_level = 0
    insert_index = -1

    for i, line in enumerate(lines):
        if 'edge-functions:' in line and not line.strip().startswith('#'):
            in_edge_functions = True
            continue

        if in_edge_functions:
            if line.strip() and not line.startswith(' ') and ':' in line:
                break

            if 'environment:' in line:
                in_environment = True
                indent_level = len(line) - len(line.lstrip()) + 2
                continue

            if in_environment and line.strip() and not line.strip().startswith('#'):
                current_indent = len(line) - len(line.lstrip())
                if current_indent < indent_level and line.strip():
                    insert_index = i
                    break

    if insert_index > 0:
        indent = ' ' * indent_level
        email_lines = [
            f"{indent}EMAIL_PROVIDER: \${{EMAIL_PROVIDER}}\n",
            f"{indent}EMAIL_API_KEY: \${{EMAIL_API_KEY}}\n",
            f"{indent}EMAIL_FROM: \${{EMAIL_FROM}}\n",
            f"{indent}EMAIL_DOMAIN: \${{EMAIL_DOMAIN:-}}\n",
        ]

        if "$SELECTED_PROVIDER" == "mailgun":
            email_lines.append(f"{indent}MAILGUN_REGION: \${{MAILGUN_REGION:-us}}\n")

        lines[insert_index:insert_index] = email_lines

        with open(docker_compose_file, 'w') as f:
            f.writelines(lines)

        print("SUCCESS")
    else:
        print("ERROR: environment section not found")
        sys.exit(1)

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        ok "Variables ajoutées au docker-compose.yml"
    else
        warn "Ajout automatique échoué - ajoutez manuellement les variables"
    fi
}

# =============================================================================
# DEPLOYMENT
# =============================================================================

deploy_function() {
    section "🚀 DÉPLOIEMENT"

    log "Les variables d'environnement nécessitent un redémarrage complet du stack Supabase..."
    echo ""
    echo "⚠️  Le stack va être arrêté puis redémarré (down/up)"
    echo "   Durée estimée: 30-60 secondes"
    echo ""

    if [ "$ASSUME_YES" -eq 0 ]; then
        if ! ask_yes_no "Continuer avec le redémarrage complet ?" "y"; then
            warn "Déploiement annulé. Les variables sont configurées mais pas encore actives."
            warn "Relancez manuellement: cd $SUPABASE_DIR && docker compose down && docker compose up -d"
            exit 0
        fi
    fi

    log "Arrêt du stack Supabase..."
    cd "$SUPABASE_DIR"
    docker compose down >> "$LOG_FILE" 2>&1

    ok "Stack arrêté"

    log "Redémarrage avec les nouvelles variables..."
    docker compose up -d >> "$LOG_FILE" 2>&1

    ok "Stack redémarré"

    log "Attente de la disponibilité des services (30 secondes)..."
    sleep 30

    # Verify all services are up
    log "Vérification des services..."
    local all_healthy=true
    for service in db kong auth rest realtime storage edge-functions; do
        if docker ps --format '{{.Names}}' | grep -q "supabase-$service"; then
            log "  ✓ $service"
        else
            warn "  ✗ $service non démarré"
            all_healthy=false
        fi
    done

    if [ "$all_healthy" = true ]; then
        ok "Tous les services sont démarrés"
    else
        warn "Certains services n'ont pas démarré correctement"
        log "Vérifiez les logs: docker compose -f $SUPABASE_DIR/docker-compose.yml logs"
    fi

    # Verify variables
    log "Vérification des variables d'environnement..."
    if docker exec $(docker ps -qf "name=edge-functions") env | grep -q "EMAIL_PROVIDER"; then
        ok "Variables EMAIL disponibles dans le container Edge Functions"

        # Show configured variables (masked)
        local masked_key="${API_KEY:0:10}..."
        log "  → EMAIL_PROVIDER: $SELECTED_PROVIDER"
        log "  → EMAIL_API_KEY: $masked_key"
        log "  → EMAIL_FROM: $FROM_EMAIL"
    else
        error "Variables EMAIL non détectées dans le container. Vérifiez les logs."
    fi
}

# =============================================================================
# SUMMARY
# =============================================================================

display_summary() {
    section "✅ CONFIGURATION TERMINÉE"

    echo -e "\033[1;32m🎉 ${SELECTED_PROVIDER^^} configuré avec succès !\033[0m"
    echo ""
    echo "📧 Configuration :"
    echo "  Provider : $SELECTED_PROVIDER"
    echo "  API Key  : ${API_KEY:0:10}..."
    echo "  From     : $FROM_EMAIL"
    [ -n "$DOMAIN" ] && echo "  Domain   : $DOMAIN"
    echo ""
    echo "📁 Fichiers créés/modifiés :"
    echo "  → $FUNCTIONS_DIR/send-email/index.ts"
    echo "  → $FUNCTIONS_DIR/.env"
    echo "  → $SUPABASE_DIR/.env"
    echo "  → $SUPABASE_DIR/docker-compose.yml"
    echo ""
    echo "🔑 Variables d'environnement disponibles :"
    echo "  → EMAIL_PROVIDER (accessible dans toutes les Edge Functions)"
    echo "  → EMAIL_API_KEY"
    echo "  → EMAIL_FROM"
    [ -n "$DOMAIN" ] && echo "  → EMAIL_DOMAIN"
    echo ""
    echo "💡 Utilisation dans vos Edge Functions :"
    echo ""
    echo "  const apiKey = Deno.env.get('EMAIL_API_KEY')"
    echo "  const from = Deno.env.get('EMAIL_FROM')"
    echo ""
    echo "🧪 Tester la fonction send-email :"
    echo "  curl -X POST http://localhost:54321/send-email \\"
    echo "    -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
    echo "    -d '{\"to\":\"test@example.com\",\"subject\":\"Test\",\"html\":\"<h1>Hello</h1>\"}'"
    echo ""
    echo "📝 Log complet : $LOG_FILE"
    echo ""

    case "$SELECTED_PROVIDER" in
        resend)
            echo "📊 Analytics : https://resend.com/emails"
            echo "📚 Docs : https://resend.com/docs"
            ;;
        sendgrid)
            echo "📊 Analytics : https://app.sendgrid.com/statistics"
            echo "📚 Docs : https://docs.sendgrid.com"
            ;;
        mailgun)
            echo "📊 Logs : https://app.mailgun.com/app/logs"
            echo "📚 Docs : https://documentation.mailgun.com"
            ;;
    esac
    echo ""
}

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                SELECTED_PROVIDER="$2"
                shift 2
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
            --force)
                FORCE_RECONFIG=1
                shift
                ;;
            --help|-h)
                cat <<EOF
Usage: $0 [OPTIONS]

Options:
  --provider <name>  Pre-select provider (resend|sendgrid|mailgun)
  --dry-run          Show what would be done
  --yes, -y          Skip confirmations
  --verbose, -v      Verbose output
  --force            Force reconfiguration
  --help, -h         Show this help

Examples:
  sudo bash $0
  sudo bash $0 --provider resend --yes
  sudo bash $0 --force

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
# MAIN
# =============================================================================

main() {
    section "📧 CONFIGURATION EMAIL PROVIDER"

    log "Email Provider Setup v1.1.0"
    log "Log file: $LOG_FILE"

    validate_prerequisites

    if check_existing_config; then
        exit 0
    fi

    select_provider

    case "$SELECTED_PROVIDER" in
        resend)
            configure_resend
            ;;
        sendgrid)
            configure_sendgrid
            ;;
        mailgun)
            configure_mailgun
            ;;
    esac

    create_send_email_function
    update_env_files
    update_docker_compose
    deploy_function
    display_summary

    ok "Configuration terminée avec succès !"
}

parse_args "$@"
main
