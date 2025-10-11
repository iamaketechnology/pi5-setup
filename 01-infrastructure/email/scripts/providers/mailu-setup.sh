#!/bin/bash
# =============================================================================
# MAILU WRAPPER SCRIPT - Deploy Mailu Email Server with Pre-checks
# =============================================================================
#
# Purpose: Wrapper around Mailu deployment script with additional validations,
#          DNS guidance, and intelligent prerequisites checking
#
# Author: PI5-SETUP Project
# Version: 1.0.0
# Target: Raspberry Pi 5 ARM64
# Estimated Runtime: 20-30 minutes
#
# Features:
# - Pre-deployment validation (RAM, disk, ports)
# - DNS configuration guidance
# - Domain verification
# - Wrapper to existing 01-mailu-deploy.sh
# - **IDEMPOTENT** (safe to run multiple times)
# - **INTELLIGENT DEBUG** (auto-capture errors with context)
#
# Usage:
#   sudo bash 03-mailu-wrapper.sh [OPTIONS]
#
# Options:
#   --dry-run          Show what would be done
#   --yes, -y          Skip confirmations
#   --verbose, -v      Verbose output
#   --skip-dns-check   Skip DNS validation
#
# Environment variables (optional):
#   MAILU_DOMAIN=yourdomain.com
#   MAILU_ADMIN_EMAIL=admin@yourdomain.com
#   MAILU_ADMIN_PASSWORD=SecurePassword123!
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
LOG_FILE="${LOG_DIR}/mailu-wrapper-$(date +%Y%m%d-%H%M%S).log"
MAILU_DEPLOY_SCRIPT="$SCRIPT_DIR/01-mailu-deploy.sh"

# Source common library
if [ -f "$COMMON_SCRIPTS_DIR/lib.sh" ]; then
    # shellcheck source=/dev/null
    source "$COMMON_SCRIPTS_DIR/lib.sh"
else
    echo "ERROR: lib.sh not found at $COMMON_SCRIPTS_DIR/lib.sh"
    exit 1
fi

# Script options
SKIP_DNS_CHECK=0

mkdir -p "$LOG_DIR"

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
        echo "🔴 ERREUR DÉTECTÉE - MAILU WRAPPER"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📍 Erreur : Ligne $line_num"
        echo "📁 Domain : ${MAILU_DOMAIN:-non défini}"
        echo "📝 Log    : $LOG_FILE"
        echo ""
        echo "💡 Actions :"
        echo "   1. Vérifier les prérequis (RAM, domaine, DNS)"
        echo "   2. Consulter : cat $LOG_FILE"
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
}

# =============================================================================
# PREREQUISITES VALIDATION
# =============================================================================

validate_system_requirements() {
    section "✅ VALIDATION DES EXIGENCES SYSTÈME"

    require_root

    # Check RAM (8GB minimum recommended)
    local ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    local ram_gb=$((ram_mb / 1024))

    if [ "$ram_gb" -ge 8 ]; then
        ok "RAM : ${ram_gb} GB (suffisant)"
    elif [ "$ram_gb" -ge 4 ]; then
        warn "RAM : ${ram_gb} GB (limité, 8GB recommandé)"
        log "Mailu peut fonctionner mais sera limité"
        if ! confirm "Continuer quand même ?"; then
            exit 0
        fi
    else
        error "RAM insuffisante : ${ram_gb} GB (minimum 4GB, recommandé 8GB)"
    fi

    # Check disk space (10GB minimum)
    local disk_free_gb=$(df -BG /home | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_free_gb" -ge 10 ]; then
        ok "Espace disque : ${disk_free_gb} GB libre"
    else
        error "Espace disque insuffisant : ${disk_free_gb} GB (minimum 10GB)"
    fi

    # Check Docker
    if ! docker ps >/dev/null 2>&1; then
        error "Docker non accessible"
    fi
    ok "Docker accessible"

    # Check if Mailu already installed
    if [ -d "/home/pi/stacks/mailu" ]; then
        warn "Mailu déjà installé dans /home/pi/stacks/mailu"
        if ! confirm "Reconfigurer Mailu ?"; then
            exit 0
        fi
    fi
}

# =============================================================================
# DOMAIN CONFIGURATION
# =============================================================================

configure_domain() {
    section "🌐 CONFIGURATION DU DOMAINE"

    echo "Mailu nécessite un nom de domaine valide."
    echo ""
    echo "Prérequis :"
    echo "  ✓ Posséder un domaine (acheté sur Namecheap, OVH, etc.)"
    echo "  ✓ Accès aux paramètres DNS du domaine"
    echo "  ✓ Capacité à créer des records MX, A, TXT"
    echo ""

    if [ -z "${MAILU_DOMAIN:-}" ]; then
        while true; do
            read -p "$(echo -e "\033[1;33m❓ Entrez votre domaine (ex: example.com):\033[0m ") " domain
            if [[ "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
                MAILU_DOMAIN="$domain"
                break
            else
                echo "Domaine invalide. Format attendu : example.com"
            fi
        done
    fi

    ok "Domaine : $MAILU_DOMAIN"

    # Admin email
    if [ -z "${MAILU_ADMIN_EMAIL:-}" ]; then
        read -p "$(echo -e "\033[1;33m❓ Email administrateur (défaut: admin@$MAILU_DOMAIN):\033[0m ") " admin_email
        MAILU_ADMIN_EMAIL="${admin_email:-admin@$MAILU_DOMAIN}"
    fi

    ok "Admin : $MAILU_ADMIN_EMAIL"

    # Admin password
    if [ -z "${MAILU_ADMIN_PASSWORD:-}" ]; then
        while true; do
            read -s -p "$(echo -e "\033[1;33m❓ Mot de passe admin (min 12 caractères):\033[0m ") " password1
            echo ""
            read -s -p "$(echo -e "\033[1;33m❓ Confirmer le mot de passe:\033[0m ") " password2
            echo ""

            if [ "$password1" = "$password2" ] && [ ${#password1} -ge 12 ]; then
                MAILU_ADMIN_PASSWORD="$password1"
                break
            else
                echo "Les mots de passe ne correspondent pas ou sont trop courts"
            fi
        done
    fi

    ok "Mot de passe configuré"
}

# =============================================================================
# DNS GUIDANCE
# =============================================================================

display_dns_guidance() {
    section "📋 CONFIGURATION DNS REQUISE"

    echo "Avant de déployer Mailu, vous DEVEZ configurer ces DNS records :"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1️⃣  A Record (IPv4)"
    echo "   Type : A"
    echo "   Nom  : mail.$MAILU_DOMAIN"
    echo "   Valeur : $(curl -s ifconfig.me || echo "[VOTRE_IP_PUBLIQUE]")"
    echo ""
    echo "2️⃣  MX Record (Mail Exchange)"
    echo "   Type : MX"
    echo "   Nom  : $MAILU_DOMAIN"
    echo "   Valeur : mail.$MAILU_DOMAIN"
    echo "   Priority : 10"
    echo ""
    echo "3️⃣  SPF Record (Sender Policy Framework)"
    echo "   Type : TXT"
    echo "   Nom  : $MAILU_DOMAIN"
    echo "   Valeur : v=spf1 mx ~all"
    echo ""
    echo "4️⃣  DKIM Record (généré après installation)"
    echo "   Type : TXT"
    echo "   Nom  : dkim._domainkey.$MAILU_DOMAIN"
    echo "   Valeur : [sera fournie après installation]"
    echo ""
    echo "5️⃣  DMARC Record"
    echo "   Type : TXT"
    echo "   Nom  : _dmarc.$MAILU_DOMAIN"
    echo "   Valeur : v=DMARC1; p=quarantine; rua=mailto:$MAILU_ADMIN_EMAIL"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⏱️  Propagation DNS : 5 minutes à 48 heures (généralement < 1 heure)"
    echo ""

    if ! confirm "Avez-vous configuré les DNS records ?"; then
        log "Configuration DNS requise avant de continuer"
        log "Guide détaillé : $EMAIL_DIR/docs/DNS-SETUP.md"
        exit 0
    fi
}

# =============================================================================
# DNS VALIDATION
# =============================================================================

check_dns_records() {
    section "🔍 VALIDATION DES DNS"

    if [ "$SKIP_DNS_CHECK" -eq 1 ]; then
        warn "Vérification DNS ignorée (--skip-dns-check)"
        return
    fi

    local dns_ok=true

    # Check A record
    log "Vérification A record pour mail.$MAILU_DOMAIN..."
    if dig +short "mail.$MAILU_DOMAIN" A | grep -q .; then
        ok "A record trouvé"
    else
        warn "A record non trouvé pour mail.$MAILU_DOMAIN"
        dns_ok=false
    fi

    # Check MX record
    log "Vérification MX record pour $MAILU_DOMAIN..."
    if dig +short "$MAILU_DOMAIN" MX | grep -q .; then
        ok "MX record trouvé"
    else
        warn "MX record non trouvé pour $MAILU_DOMAIN"
        dns_ok=false
    fi

    # Check SPF record
    log "Vérification SPF record pour $MAILU_DOMAIN..."
    if dig +short "$MAILU_DOMAIN" TXT | grep -q "spf1"; then
        ok "SPF record trouvé"
    else
        warn "SPF record non trouvé pour $MAILU_DOMAIN"
        dns_ok=false
    fi

    if [ "$dns_ok" = false ]; then
        warn "Certains DNS records sont manquants"
        echo ""
        echo "Mailu peut être installé, mais l'envoi/réception d'emails ne fonctionnera pas"
        echo "avant que les DNS soient correctement configurés."
        echo ""

        if ! confirm "Continuer quand même ?"; then
            exit 0
        fi
    else
        ok "Tous les DNS records de base sont configurés"
    fi
}

# =============================================================================
# PORT VALIDATION
# =============================================================================

check_required_ports() {
    section "🔌 VÉRIFICATION DES PORTS"

    local ports=(25 465 587 993)
    local ports_ok=true

    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            warn "Port $port déjà utilisé"
            ports_ok=false
        else
            ok "Port $port disponible"
        fi
    done

    if [ "$ports_ok" = false ]; then
        warn "Certains ports sont déjà utilisés"
        if ! confirm "Continuer ?"; then
            exit 0
        fi
    fi
}

# =============================================================================
# DEPLOY MAILU
# =============================================================================

deploy_mailu() {
    section "🚀 DÉPLOIEMENT MAILU"

    if [ ! -f "$MAILU_DEPLOY_SCRIPT" ]; then
        error "Script Mailu non trouvé : $MAILU_DEPLOY_SCRIPT"
    fi

    log "Lancement de 01-mailu-deploy.sh..."
    log "Cela peut prendre 15-20 minutes..."

    # Export variables for mailu-deploy script
    export MAILU_DOMAIN
    export MAILU_ADMIN_EMAIL
    export MAILU_ADMIN_PASSWORD

    # Run Mailu deployment script
    if bash "$MAILU_DEPLOY_SCRIPT" 2>&1 | tee -a "$LOG_FILE"; then
        ok "Déploiement Mailu réussi"
    else
        error "Échec du déploiement Mailu (voir logs ci-dessus)"
    fi
}

# =============================================================================
# POST-INSTALL GUIDANCE
# =============================================================================

display_post_install() {
    section "✅ INSTALLATION TERMINÉE"

    echo -e "\033[1;32m🎉 Mailu installé avec succès !\033[0m"
    echo ""
    echo "🌐 Interfaces Web :"
    echo "  Admin Panel : https://mail.$MAILU_DOMAIN/admin"
    echo "  Webmail     : https://mail.$MAILU_DOMAIN/webmail"
    echo ""
    echo "🔑 Credentials :"
    echo "  Email    : $MAILU_ADMIN_EMAIL"
    echo "  Password : [défini lors de l'installation]"
    echo ""
    echo "📝 ÉTAPE CRITIQUE : Configuration DKIM"
    echo ""
    echo "  Récupérer la clé DKIM :"
    echo "    cd /home/pi/stacks/mailu"
    echo "    docker compose exec admin flask mailu config-export --format=dkim"
    echo ""
    echo "  Puis ajouter dans vos DNS :"
    echo "    Type : TXT"
    echo "    Nom  : dkim._domainkey.$MAILU_DOMAIN"
    echo "    Valeur : [sortie de la commande ci-dessus]"
    echo ""
    echo "🧪 Tester l'installation :"
    echo "  → https://www.mail-tester.com (objectif: 10/10)"
    echo "  → https://mxtoolbox.com"
    echo ""
    echo "📚 Documentation :"
    echo "  → Guide DNS : $EMAIL_DIR/docs/DNS-SETUP.md"
    echo "  → README Mailu : $EMAIL_DIR/README.md"
    echo ""
    echo "📝 Log complet : $LOG_FILE"
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
            --skip-dns-check) SKIP_DNS_CHECK=1; shift ;;
            *) warn "Argument inconnu : $1"; shift ;;
        esac
    done
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    section "📧 INSTALLATION MAILU EMAIL SERVER"

    log "Mailu wrapper v1.0.0"
    log "Log file: $LOG_FILE"

    validate_system_requirements
    configure_domain
    display_dns_guidance
    check_dns_records
    check_required_ports

    echo ""
    warn "⚠️  L'installation Mailu va commencer"
    warn "   Durée estimée : 15-30 minutes"
    warn "   Téléchargement : ~2GB d'images Docker"
    echo ""

    if ! confirm "Lancer l'installation Mailu ?"; then
        log "Installation annulée"
        exit 0
    fi

    deploy_mailu
    display_post_install

    ok "Wrapper terminé avec succès !"
}

parse_script_args "$@"
main
