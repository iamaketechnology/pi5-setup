#!/bin/bash
# =============================================================================
# EMAIL SETUP WIZARD - Interactive Email Configuration System
# =============================================================================
#
# Purpose: Guide users through choosing and configuring the best email solution
#          for their needs (SMTP, Resend API, or Mailu self-hosted)
#
# Author: PI5-SETUP Project
# Version: 1.0.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 5-30 minutes (depending on choice)
#
# Features:
# - Automatic environment detection (Supabase, Traefik, RAM, etc.)
# - Interactive questionnaire with intelligent recommendations
# - Three configuration paths: SMTP (simple), Resend (modern), Mailu (advanced)
# - Automatic configuration and testing
# - Idempotent and safe (backup before changes)
#
# Usage:
#   sudo bash 00-email-setup-wizard.sh
#
# Or one-liner:
#   curl -fsSL https://raw.githubusercontent.com/.../00-email-setup-wizard.sh | sudo bash
#
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="${SCRIPT_DIR}/scripts"
TEMPLATES_DIR="${SCRIPT_DIR}/templates"
LOG_DIR="/var/log/pi5-setup"
LOG_FILE="${LOG_DIR}/email-wizard-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

log() {
    echo -e "\033[1;36m[$(date +'%H:%M:%S')]\033[0m $*" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "\033[1;33m[$(date +'%H:%M:%S')]\033[0m ⚠️  $*" | tee -a "$LOG_FILE"
}

ok() {
    echo -e "\033[1;32m[$(date +'%H:%M:%S')]\033[0m ✓ $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "\033[1;31m[$(date +'%H:%M:%S')]\033[0m ✗ ERROR: $*" | tee -a "$LOG_FILE"
    exit 1
}

section() {
    echo "" | tee -a "$LOG_FILE"
    echo -e "\033[1;35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a "$LOG_FILE"
    echo -e "\033[1;35m $*\033[0m" | tee -a "$LOG_FILE"
    echo -e "\033[1;35m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Ask yes/no question
ask_yes_no() {
    local question="$1"
    local default="${2:-y}"

    if [[ "$default" == "y" ]]; then
        local prompt="[Y/n]"
    else
        local prompt="[y/N]"
    fi

    while true; do
        read -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
        answer="${answer:-$default}"

        case "$answer" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) echo "Veuillez répondre 'y' ou 'n'" ;;
        esac
    done
}

# Ask multiple choice question
ask_choice() {
    local question="$1"
    shift
    local options=("$@")

    echo ""
    echo -e "\033[1;33m❓ $question\033[0m"

    for i in "${!options[@]}"; do
        echo "   $((i+1))) ${options[$i]}"
    done

    while true; do
        read -p "$(echo -e "\033[1;33mChoix [1-${#options[@]}]:\033[0m ") " choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $((choice - 1))
        else
            echo "Choix invalide. Entrez un nombre entre 1 et ${#options[@]}"
        fi
    done
}

# Ask for text input
ask_input() {
    local question="$1"
    local default="${2:-}"
    local secret="${3:-false}"

    if [ -n "$default" ]; then
        local prompt="(défaut: $default)"
    else
        local prompt=""
    fi

    while true; do
        if [ "$secret" == "true" ]; then
            read -s -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
            echo ""
        else
            read -p "$(echo -e "\033[1;33m❓ $question $prompt:\033[0m ") " answer
        fi

        answer="${answer:-$default}"

        if [ -n "$answer" ]; then
            echo "$answer"
            return 0
        else
            echo "Cette valeur est requise."
        fi
    done
}

# =============================================================================
# ENVIRONMENT DETECTION
# =============================================================================

detect_environment() {
    section "🔍 DÉTECTION DE L'ENVIRONNEMENT"

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "Ce script doit être exécuté avec sudo ou en tant que root"
    fi

    # Detect Supabase installation
    if [ -d "/home/pi/stacks/supabase" ] && [ -f "/home/pi/stacks/supabase/docker-compose.yml" ]; then
        SUPABASE_INSTALLED=true
        SUPABASE_DIR="/home/pi/stacks/supabase"
        ok "Supabase installé : OUI"

        # Get Supabase version
        if [ -f "$SUPABASE_DIR/.env" ]; then
            SUPABASE_VERSION=$(grep -E "^# Version:" "$SUPABASE_DIR/docker-compose.yml" | head -1 | awk '{print $3}' || echo "unknown")
            log "   Version: $SUPABASE_VERSION"
        fi

        # Check if Auth service is running
        if docker ps | grep -q "supabase-auth"; then
            ok "   Service Auth : actif"
            AUTH_RUNNING=true
        else
            warn "   Service Auth : arrêté"
            AUTH_RUNNING=false
        fi
    else
        SUPABASE_INSTALLED=false
        warn "Supabase installé : NON"
        log "   Certaines options email nécessitent Supabase"
    fi

    # Detect Traefik installation
    if [ -d "/home/pi/stacks/traefik" ] && [ -f "/home/pi/stacks/traefik/docker-compose.yml" ]; then
        TRAEFIK_INSTALLED=true
        TRAEFIK_DIR="/home/pi/stacks/traefik"
        ok "Traefik installé : OUI"

        # Detect scenario
        if [ -f "$TRAEFIK_DIR/.env" ]; then
            if grep -q "CLOUDFLARE_EMAIL" "$TRAEFIK_DIR/.env" 2>/dev/null; then
                TRAEFIK_SCENARIO="cloudflare"
                log "   Scénario: Cloudflare"
            elif grep -q "DUCKDNS_TOKEN" "$TRAEFIK_DIR/.env" 2>/dev/null; then
                TRAEFIK_SCENARIO="duckdns"
                log "   Scénario: DuckDNS"
            else
                TRAEFIK_SCENARIO="vpn"
                log "   Scénario: VPN/Local"
            fi
        fi
    else
        TRAEFIK_INSTALLED=false
        warn "Traefik installé : NON"
        TRAEFIK_SCENARIO="none"
    fi

    # Detect domain
    if [ "$TRAEFIK_INSTALLED" == "true" ] && [ -f "$TRAEFIK_DIR/.env" ]; then
        DOMAIN=$(grep "^DOMAIN=" "$TRAEFIK_DIR/.env" | cut -d= -f2 | tr -d '"' || echo "")
        if [ -n "$DOMAIN" ]; then
            ok "Domaine détecté : $DOMAIN"
        else
            warn "Domaine non configuré"
            DOMAIN=""
        fi
    else
        DOMAIN=""
    fi

    # Check RAM
    TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))

    if [ "$TOTAL_RAM_GB" -ge 8 ]; then
        ok "RAM disponible : ${TOTAL_RAM_GB} GB (suffisant pour toutes options)"
        RAM_SUFFICIENT_MAILU=true
    elif [ "$TOTAL_RAM_GB" -ge 4 ]; then
        ok "RAM disponible : ${TOTAL_RAM_GB} GB (suffisant pour SMTP/Resend)"
        warn "   RAM limitée pour Mailu (8GB+ recommandé)"
        RAM_SUFFICIENT_MAILU=false
    else
        warn "RAM disponible : ${TOTAL_RAM_GB} GB (limitée)"
        log "   Mailu non recommandé avec moins de 4GB"
        RAM_SUFFICIENT_MAILU=false
    fi

    # Check disk space
    DISK_FREE_GB=$(df -BG /home | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_FREE_GB" -ge 10 ]; then
        ok "Espace disque libre : ${DISK_FREE_GB} GB"
    else
        warn "Espace disque libre : ${DISK_FREE_GB} GB (limité)"
    fi

    # Check if email already configured
    if [ "$SUPABASE_INSTALLED" == "true" ] && [ -f "$SUPABASE_DIR/.env" ]; then
        if grep -q "GOTRUE_SMTP_HOST" "$SUPABASE_DIR/.env" 2>/dev/null; then
            EMAIL_CONFIGURED=true
            CURRENT_SMTP_HOST=$(grep "GOTRUE_SMTP_HOST=" "$SUPABASE_DIR/.env" | cut -d= -f2 | tr -d '"')
            warn "Configuration email existante détectée"
            log "   SMTP Host: $CURRENT_SMTP_HOST"
        else
            EMAIL_CONFIGURED=false
            ok "Pas de configuration email existante"
        fi
    else
        EMAIL_CONFIGURED=false
    fi

    echo ""
}

# =============================================================================
# RECOMMENDATION ENGINE
# =============================================================================

calculate_recommendation() {
    local use_case="$1"
    local volume="$2"
    local expertise="$3"

    # Scoring system
    local smtp_score=0
    local resend_score=0
    local mailu_score=0

    # Use case scoring
    case "$use_case" in
        1) # Auth only
            smtp_score=$((smtp_score + 3))
            resend_score=$((resend_score + 2))
            mailu_score=$((mailu_score + 0))
            ;;
        2) # Transactional + notifications
            smtp_score=$((smtp_score + 1))
            resend_score=$((resend_score + 3))
            mailu_score=$((mailu_score + 2))
            ;;
        3) # Full email server
            smtp_score=$((smtp_score + 0))
            resend_score=$((resend_score + 0))
            mailu_score=$((mailu_score + 3))
            ;;
    esac

    # Volume scoring
    case "$volume" in
        1) # < 1000
            smtp_score=$((smtp_score + 3))
            resend_score=$((resend_score + 2))
            mailu_score=$((mailu_score + 1))
            ;;
        2) # 1000-10000
            smtp_score=$((smtp_score + 1))
            resend_score=$((resend_score + 3))
            mailu_score=$((mailu_score + 2))
            ;;
        3) # > 10000
            smtp_score=$((smtp_score + 0))
            resend_score=$((resend_score + 1))
            mailu_score=$((mailu_score + 3))
            ;;
    esac

    # Expertise scoring
    case "$expertise" in
        1) # Beginner
            smtp_score=$((smtp_score + 3))
            resend_score=$((resend_score + 2))
            mailu_score=$((mailu_score + 0))
            ;;
        2) # Intermediate
            smtp_score=$((smtp_score + 2))
            resend_score=$((resend_score + 3))
            mailu_score=$((mailu_score + 1))
            ;;
        3) # Advanced
            smtp_score=$((smtp_score + 1))
            resend_score=$((resend_score + 2))
            mailu_score=$((mailu_score + 3))
            ;;
    esac

    # Environment penalties
    if [ "$SUPABASE_INSTALLED" != "true" ]; then
        smtp_score=$((smtp_score - 5))
    fi

    if [ "$RAM_SUFFICIENT_MAILU" != "true" ]; then
        mailu_score=$((mailu_score - 5))
    fi

    if [ -z "$DOMAIN" ]; then
        mailu_score=$((mailu_score - 3))
    fi

    # Determine recommendation
    if [ "$smtp_score" -ge "$resend_score" ] && [ "$smtp_score" -ge "$mailu_score" ]; then
        echo "smtp"
    elif [ "$resend_score" -ge "$mailu_score" ]; then
        echo "resend"
    else
        echo "mailu"
    fi
}

# =============================================================================
# QUESTIONNAIRE
# =============================================================================

run_questionnaire() {
    section "📋 QUESTIONNAIRE"

    log "Répondez à quelques questions pour déterminer la meilleure option email pour vous."
    echo ""

    # Question 1: Use case
    ask_choice "Quel est votre cas d'usage principal ?" \
        "Emails authentification uniquement (signup, reset password)" \
        "Emails transactionnels + notifications (auth + app features)" \
        "Serveur email complet (boîtes mail personnelles)"
    USE_CASE=$?

    # Question 2: Volume
    ask_choice "Combien d'emails par mois estimez-vous envoyer ?" \
        "Moins de 1 000 emails/mois (usage léger)" \
        "Entre 1 000 et 10 000 emails/mois (usage modéré)" \
        "Plus de 10 000 emails/mois (usage intensif)"
    VOLUME=$?

    # Question 3: Expertise
    ask_choice "Quel est votre niveau technique ?" \
        "Débutant (je veux la solution la plus simple)" \
        "Intermédiaire (je peux configurer SMTP/API)" \
        "Avancé (je veux un contrôle total)"
    EXPERTISE=$?

    # Calculate recommendation
    RECOMMENDATION=$(calculate_recommendation "$USE_CASE" "$VOLUME" "$EXPERTISE")

    echo ""
}

# =============================================================================
# DISPLAY RECOMMENDATION
# =============================================================================

display_recommendation() {
    section "📊 RECOMMANDATION"

    case "$RECOMMENDATION" in
        smtp)
            echo -e "\033[1;32m✅ Option recommandée : SMTP (Gmail/SendGrid)\033[0m"
            echo ""
            echo "Pourquoi ?"
            echo "  ✓ Gratuit (jusqu'à 500 emails/jour avec Gmail)"
            echo "  ✓ Installation très rapide (5-10 minutes)"
            echo "  ✓ Parfait pour emails d'authentification"
            echo "  ✓ Pas de configuration DNS complexe"
            echo "  ✓ Fonctionne immédiatement"
            echo ""
            echo "Inconvénients :"
            echo "  ✗ Limité en volume (quotas providers)"
            echo "  ✗ Dépendance à un service externe"
            echo ""
            echo "Alternatives :"
            echo "  → Resend si vous avez besoin de plus de flexibilité"
            echo "  → Mailu si vous voulez un serveur complet"
            ;;
        resend)
            echo -e "\033[1;32m✅ Option recommandée : Resend API\033[0m"
            echo ""
            echo "Pourquoi ?"
            echo "  ✓ API moderne et simple"
            echo "  ✓ Gratuit jusqu'à 3000 emails/mois"
            echo "  ✓ Excellent pour transactionnel + notifications"
            echo "  ✓ Dashboard analytics intégré"
            echo "  ✓ Templates React Email natifs"
            echo "  ✓ Très bonne délivrabilité"
            echo ""
            echo "Inconvénients :"
            echo "  ✗ Payant au-delà de 3000 emails/mois (\$20/mois)"
            echo "  ✗ Nécessite vérification domaine"
            echo ""
            echo "Alternatives :"
            echo "  → SMTP si budget zéro strict"
            echo "  → Mailu si > 10 000 emails/mois"
            ;;
        mailu)
            echo -e "\033[1;32m✅ Option recommandée : Mailu (Self-hosted)\033[0m"
            echo ""
            echo "Pourquoi ?"
            echo "  ✓ Contrôle total de vos données"
            echo "  ✓ Gratuit (sauf domaine ~10€/an)"
            echo "  ✓ Volume illimité"
            echo "  ✓ Serveur email complet (boîtes mail)"
            echo "  ✓ Interface admin + webmail"
            echo ""
            echo "Inconvénients :"
            echo "  ✗ Configuration DNS complexe (MX, SPF, DKIM, DMARC)"
            echo "  ✗ Nécessite 8GB+ RAM"
            echo "  ✗ Maintenance régulière requise"
            echo "  ✗ Risque de blacklist si mal configuré"
            echo ""
            echo "Alternatives :"
            echo "  → SMTP/Resend si vous voulez plus simple"
            ;;
    esac

    echo ""
}

# =============================================================================
# MANUAL CHOICE
# =============================================================================

choose_option() {
    if ask_yes_no "Continuer avec l'option recommandée ($RECOMMENDATION) ?" "y"; then
        CHOSEN_OPTION="$RECOMMENDATION"
    else
        echo ""
        ask_choice "Quelle option voulez-vous installer ?" \
            "SMTP (Gmail/SendGrid) - Simple et rapide" \
            "Resend API - Moderne et flexible" \
            "Mailu - Self-hosted complet"
        choice=$?

        case "$choice" in
            0) CHOSEN_OPTION="smtp" ;;
            1) CHOSEN_OPTION="resend" ;;
            2) CHOSEN_OPTION="mailu" ;;
        esac
    fi

    log "Option choisie : $CHOSEN_OPTION"
    echo ""
}

# =============================================================================
# INSTALLATION DISPATCH
# =============================================================================

run_installation() {
    section "🚀 INSTALLATION : $(echo $CHOSEN_OPTION | tr '[:lower:]' '[:upper:]')"

    case "$CHOSEN_OPTION" in
        smtp)
            if [ ! -f "$SCRIPTS_DIR/providers/smtp-setup.sh" ]; then
                error "Script SMTP non trouvé : $SCRIPTS_DIR/providers/smtp-setup.sh"
            fi

            log "Lancement du script SMTP..."
            bash "$SCRIPTS_DIR/providers/smtp-setup.sh"
            ;;
        resend)
            if [ ! -f "$SCRIPTS_DIR/providers/resend-setup.sh" ]; then
                error "Script Resend non trouvé : $SCRIPTS_DIR/providers/resend-setup.sh"
            fi

            log "Lancement du script Resend..."
            bash "$SCRIPTS_DIR/providers/resend-setup.sh"
            ;;
        mailu)
            if [ ! -f "$SCRIPTS_DIR/providers/mailu-setup.sh" ]; then
                error "Script Mailu non trouvé : $SCRIPTS_DIR/providers/mailu-setup.sh"
            fi

            log "Lancement du script Mailu..."
            bash "$SCRIPTS_DIR/providers/mailu-setup.sh"
            ;;
        *)
            error "Option invalide : $CHOSEN_OPTION"
            ;;
    esac
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================

display_summary() {
    section "✅ INSTALLATION TERMINÉE"

    echo -e "\033[1;32m🎉 Configuration email complétée avec succès !\033[0m"
    echo ""

    case "$CHOSEN_OPTION" in
        smtp)
            echo "📧 Configuration SMTP active"
            echo ""
            echo "Prochaines étapes :"
            echo "  1. Tester l'envoi d'email (signup/reset password dans votre app)"
            echo "  2. Vérifier les logs : docker compose -f $SUPABASE_DIR/docker-compose.yml logs auth"
            echo "  3. Script de test : bash $SCRIPTS_DIR/maintenance/email-test.sh"
            ;;
        resend)
            echo "📧 Resend API configuré"
            echo ""
            echo "Prochaines étapes :"
            echo "  1. Vérifier votre domaine sur Resend.com"
            echo "  2. Tester avec : bash $SCRIPTS_DIR/maintenance/email-test.sh"
            echo "  3. Consulter analytics sur https://resend.com/emails"
            ;;
        mailu)
            echo "📧 Serveur Mailu déployé"
            echo ""
            echo "Prochaines étapes :"
            echo "  1. Configurer DNS (MX, SPF, DKIM, DMARC)"
            echo "  2. Admin UI : https://mail.$DOMAIN/admin"
            echo "  3. Webmail : https://mail.$DOMAIN/webmail"
            echo "  4. Guide DNS : $SCRIPT_DIR/docs/DNS-SETUP.md"
            ;;
    esac

    echo ""
    echo "📚 Documentation :"
    echo "  - Guide complet : $SCRIPT_DIR/GUIDE-EMAIL-CHOICES.md"
    echo "  - Troubleshooting : $SCRIPT_DIR/docs/TROUBLESHOOTING.md"
    echo ""
    echo "📝 Log complet : $LOG_FILE"
    echo ""
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    clear

    section "🧙 ASSISTANT DE CONFIGURATION EMAIL"

    echo "Bienvenue dans l'assistant de configuration email pour PI5-SETUP !"
    echo ""
    echo "Cet assistant vous aidera à choisir et configurer la meilleure"
    echo "solution email pour votre Raspberry Pi 5."
    echo ""
    echo "Options disponibles :"
    echo "  • SMTP (Gmail/SendGrid) - Simple, gratuit, rapide"
    echo "  • Resend API - Moderne, flexible, analytics"
    echo "  • Mailu - Self-hosted, contrôle total, illimité"
    echo ""

    if ! ask_yes_no "Commencer l'installation ?" "y"; then
        log "Installation annulée par l'utilisateur"
        exit 0
    fi

    # Step 1: Detect environment
    detect_environment

    # Step 2: Run questionnaire
    run_questionnaire

    # Step 3: Display recommendation
    display_recommendation

    # Step 4: Let user choose
    choose_option

    # Step 5: Confirm installation
    if ! ask_yes_no "Lancer l'installation de $CHOSEN_OPTION ?" "y"; then
        log "Installation annulée par l'utilisateur"
        exit 0
    fi

    # Step 6: Run installation
    run_installation

    # Step 7: Display summary
    display_summary

    ok "Wizard terminé avec succès !"
}

# Run main function
main "$@"
