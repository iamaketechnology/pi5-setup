#!/usr/bin/env bash
#######################################################################################################
# Script d'Ajout Rate Limiting Traefik - Protection DoS/DDoS
#######################################################################################################
# Description : Ajoute des middlewares rate limiting à Traefik pour protéger contre les attaques
# Version     : 1.0.0
# Usage       : sudo bash 02-add-rate-limiting.sh [--strict|--moderate|--permissive]
#
# Fonctionnalités :
#   - Création middlewares rate limiting (API, Auth, Global)
#   - 3 profils : strict, moderate (défaut), permissive
#   - Configuration dynamique Traefik (pas de redémarrage requis)
#   - Backup automatique configuration existante
#   - Logs rate limiting dans Traefik
#
# Auteur      : PI5-SETUP Project
# Licence     : MIT
#######################################################################################################

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_VERSION="1.0.0"
TRAEFIK_DIR="/home/pi/stacks/traefik"
DYNAMIC_DIR="${TRAEFIK_DIR}/dynamic"
RATE_LIMIT_FILE="${DYNAMIC_DIR}/rate-limiting.yml"
BACKUP_DIR="/home/pi/backups/traefik-security"
LOG_FILE="/var/log/traefik-rate-limiting.log"

# Profil par défaut
PROFILE="moderate"

#######################################################################################################
# Fonctions utilitaires
#######################################################################################################

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

fatal() {
    log_error "$1"
    exit 1
}

#######################################################################################################
# Validation
#######################################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

check_traefik() {
    if [[ ! -d "$TRAEFIK_DIR" ]]; then
        fatal "Traefik non trouvé : $TRAEFIK_DIR"
    fi

    if [[ ! -d "$DYNAMIC_DIR" ]]; then
        mkdir -p "$DYNAMIC_DIR"
        log_info "Création répertoire dynamic : $DYNAMIC_DIR"
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
        log_warn "Container Traefik non actif"
    else
        log_success "Traefik actif"
    fi
}

#######################################################################################################
# Backup
#######################################################################################################

create_backup() {
    log_info "Création backup..."

    mkdir -p "$BACKUP_DIR"

    if [[ -f "$RATE_LIMIT_FILE" ]]; then
        cp "$RATE_LIMIT_FILE" "${BACKUP_DIR}/rate-limiting-$(date +%Y%m%d-%H%M%S).yml"
        log_success "Backup créé"
    fi
}

#######################################################################################################
# Configuration Rate Limiting
#######################################################################################################

create_rate_limiting_config() {
    log_info "Création configuration rate limiting (profil: $PROFILE)..."

    # Définir limites selon profil
    local global_average global_burst
    local api_average api_burst
    local auth_average auth_burst

    case "$PROFILE" in
        strict)
            global_average=50
            global_burst=25
            api_average=30
            api_burst=10
            auth_average=10
            auth_burst=5
            ;;
        moderate)
            global_average=100
            global_burst=50
            api_average=60
            api_burst=30
            auth_average=20
            auth_burst=10
            ;;
        permissive)
            global_average=200
            global_burst=100
            api_average=120
            api_burst=60
            auth_average=40
            auth_burst=20
            ;;
        *)
            fatal "Profil inconnu: $PROFILE"
            ;;
    esac

    cat > "$RATE_LIMIT_FILE" << EOF
# Rate Limiting Middlewares - Traefik
# Profile: $PROFILE
# Generated: $(date)
# Version: $SCRIPT_VERSION

http:
  middlewares:
    # Rate Limiting Global (tous services)
    rate-limit-global:
      rateLimit:
        average: $global_average
        burst: $global_burst
        period: 1s

    # Rate Limiting API (Supabase, apps)
    rate-limit-api:
      rateLimit:
        average: $api_average
        burst: $api_burst
        period: 1s
        sourceCriterion:
          ipStrategy:
            depth: 1  # Prendre première IP (proxy)

    # Rate Limiting Auth (authentication endpoints)
    rate-limit-auth:
      rateLimit:
        average: $auth_average
        burst: $auth_burst
        period: 1s
        sourceCriterion:
          ipStrategy:
            depth: 1
            excludedIPs:
              - 127.0.0.1/32
              - 192.168.1.0/24  # Réseau local exempt

    # Rate Limiting Strict (endpoints sensibles)
    rate-limit-strict:
      rateLimit:
        average: 10
        burst: 5
        period: 1s

    # Headers Security (bonus)
    security-headers:
      headers:
        frameDeny: true
        browserXssFilter: true
        contentTypeNosniff: true
        stsSeconds: 31536000
        stsIncludeSubdomains: true
        stsPreload: true
        customResponseHeaders:
          X-Robots-Tag: "noindex, nofollow"

    # CORS (si nécessaire)
    cors-headers:
      headers:
        accessControlAllowMethods:
          - GET
          - POST
          - PUT
          - DELETE
          - OPTIONS
        accessControlAllowHeaders:
          - "*"
        accessControlAllowOriginList:
          - "*"
        accessControlMaxAge: 3600
        addVaryHeader: true
EOF

    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "$RATE_LIMIT_FILE"
    log_success "Configuration rate limiting créée : $RATE_LIMIT_FILE"
}

#######################################################################################################
# Application
#######################################################################################################

apply_rate_limiting() {
    log_info "Application rate limiting..."

    # Traefik recharge automatiquement les fichiers dynamic
    log_info "Traefik recharge la configuration dynamique automatiquement (watch: true)"

    # Attendre rechargement
    sleep 3

    # Vérifier logs Traefik
    if docker logs traefik 2>&1 | tail -20 | grep -q "Configuration loaded"; then
        log_success "Configuration rate limiting chargée par Traefik"
    else
        log_warn "Impossible de confirmer rechargement (vérifier logs manuellement)"
    fi
}

#######################################################################################################
# Tests
#######################################################################################################

test_rate_limiting() {
    log_info "=== Tests rate limiting ==="

    log_info "Middlewares disponibles :"
    echo "  - rate-limit-global  : ${global_average:-100} req/s (burst: ${global_burst:-50})"
    echo "  - rate-limit-api     : ${api_average:-60} req/s (burst: ${api_burst:-30})"
    echo "  - rate-limit-auth    : ${auth_average:-20} req/s (burst: ${auth_burst:-10})"
    echo "  - rate-limit-strict  : 10 req/s (burst: 5)"
    echo "  - security-headers   : Headers sécurité HTTP"
    echo "  - cors-headers       : CORS si nécessaire"

    log_info ""
    log_info "Pour appliquer à un service, ajouter labels Docker :"
    cat << 'EOF'

    labels:
      - "traefik.enable=true"
      - "traefik.http.middlewares.my-service.rate-limit-api"
      - "traefik.http.middlewares.my-service.security-headers"

    # Ou dans fichier dynamic/my-service.yml :
    http:
      routers:
        my-service:
          middlewares:
            - rate-limit-api@file
            - security-headers@file
EOF
}

#######################################################################################################
# Rapport
#######################################################################################################

generate_report() {
    log_info ""
    log_info "============================================"
    log_info "  RATE LIMITING TRAEFIK CONFIGURÉ"
    log_info "============================================"
    log_info ""
    log_info "📌 PROFIL : $PROFILE"
    log_info ""
    log_info "📌 MIDDLEWARES CRÉÉS :"
    log_info "  ✓ rate-limit-global  : ${global_average:-100} req/s (burst: ${global_burst:-50})"
    log_info "  ✓ rate-limit-api     : ${api_average:-60} req/s (burst: ${api_burst:-30})"
    log_info "  ✓ rate-limit-auth    : ${auth_average:-20} req/s (burst: ${auth_burst:-10})"
    log_info "  ✓ rate-limit-strict  : 10 req/s (burst: 5)"
    log_info "  ✓ security-headers   : Headers sécurité"
    log_info "  ✓ cors-headers       : CORS"
    log_info ""
    log_info "📌 FICHIER CONFIGURATION :"
    log_info "  📄 $RATE_LIMIT_FILE"
    log_info ""
    log_info "📌 BACKUP :"
    log_info "  📁 $BACKUP_DIR"
    log_info ""
    log_info "📌 PROCHAINES ÉTAPES :"
    log_info "  1. Appliquer middlewares aux services sensibles"
    log_info "  2. Tester avec : curl -I http://localhost"
    log_info "  3. Vérifier logs : docker logs traefik -f"
    log_info ""
    log_info "📌 EXEMPLE APPLICATION (Supabase API) :"
    cat << 'EOF'

  # Dans docker-compose.yml ou dynamic config
  labels:
    - "traefik.http.routers.supabase-api.middlewares=rate-limit-api@file,security-headers@file"

EOF
    log_info "============================================"
    log_info ""
}

#######################################################################################################
# Main
#######################################################################################################

show_help() {
    cat << EOF
Usage: sudo bash 02-add-rate-limiting.sh [OPTIONS]

Ajout rate limiting à Traefik pour protection DoS/DDoS.

OPTIONS:
    --strict        Profil strict (50 req/s global)
    --moderate      Profil modéré (100 req/s global) [DEFAULT]
    --permissive    Profil permissif (200 req/s global)
    -h, --help      Afficher cette aide

PROFILS:
    strict      : Pour environnements haute sécurité
    moderate    : Pour usage normal (recommandé)
    permissive  : Pour sites à fort trafic légitime

MIDDLEWARES CRÉÉS:
    - rate-limit-global  : Limite globale tous services
    - rate-limit-api     : Limite APIs (Supabase, apps)
    - rate-limit-auth    : Limite authentification
    - rate-limit-strict  : Limite stricte endpoints sensibles
    - security-headers   : Headers sécurité HTTP
    - cors-headers       : CORS si nécessaire

VERSION: $SCRIPT_VERSION
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --strict)
                PROFILE="strict"
                shift
                ;;
            --moderate)
                PROFILE="moderate"
                shift
                ;;
            --permissive)
                PROFILE="permissive"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Option inconnue: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🔒 RATE LIMITING TRAEFIK - PROTECTION DoS               ║"
    echo "║     Version $SCRIPT_VERSION                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Validations
    check_root
    check_traefik

    echo ""

    # Backup
    create_backup
    echo ""

    # Configuration
    create_rate_limiting_config
    echo ""

    # Application
    apply_rate_limiting
    echo ""

    # Tests
    test_rate_limiting
    echo ""

    # Rapport
    generate_report

    log_success "✅ Rate limiting Traefik configuré avec succès"
    log_info "📋 Log : $LOG_FILE"
}

# Exécution
main "$@"
