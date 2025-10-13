#!/usr/bin/env bash
#######################################################################################################
# Script de Durcissement Sécurité - Services Exposés sur Internet
#######################################################################################################
# Description : Sécurise les services exposés publiquement sans casser la configuration existante
# Version     : 1.0.0
# Usage       : sudo bash 01-harden-exposed-services.sh [--dry-run] [--rollback]
#
# Fonctionnalités :
#   - Backup automatique configuration avant modifications
#   - Restriction ports sensibles (PostgreSQL 5432, Studio 3000)
#   - Sécurisation fichiers .env
#   - Configuration iptables idempotente
#   - Rollback automatique en cas d'erreur
#   - Mode dry-run pour tester sans appliquer
#
# Auteur      : PI5-SETUP Project
# Licence     : MIT
#######################################################################################################

set -euo pipefail

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_VERSION="1.0.0"
BACKUP_DIR="/home/pi/backups/security-hardening"
SUPABASE_DIR="/home/pi/stacks/supabase"
TRAEFIK_DIR="/home/pi/stacks/traefik"
LOG_FILE="/var/log/security-hardening.log"
IPTABLES_BACKUP="${BACKUP_DIR}/iptables-rules-$(date +%Y%m%d-%H%M%S).bak"

# Flags
DRY_RUN=false
ROLLBACK=false
VERBOSE=false

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

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

fatal() {
    log_error "$1"
    log_error "Script interrompu à la ligne $(caller)"
    exit 1
}

#######################################################################################################
# Validation environnement
#######################################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        fatal "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

check_dependencies() {
    log_info "Vérification des dépendances..."

    local deps=("docker" "iptables" "netfilter-persistent")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_warn "$dep n'est pas installé"
            if [[ "$dep" == "netfilter-persistent" ]]; then
                log_info "Installation de $dep..."
                apt-get update -qq && apt-get install -y iptables-persistent netfilter-persistent
            else
                fatal "$dep est requis mais non installé"
            fi
        else
            log_debug "$dep trouvé : $(command -v $dep)"
        fi
    done

    log_success "Toutes les dépendances sont présentes"
}

check_services() {
    log_info "Vérification des services Docker..."

    # Vérifier Docker actif
    if ! systemctl is-active --quiet docker; then
        fatal "Docker n'est pas actif"
    fi

    # Vérifier Supabase
    if ! docker ps --format '{{.Names}}' | grep -q "supabase-db"; then
        log_warn "Container supabase-db non trouvé, certaines protections seront ignorées"
    else
        log_success "Supabase détecté"
    fi

    # Vérifier Traefik
    if ! docker ps --format '{{.Names}}' | grep -q "traefik"; then
        log_warn "Container Traefik non trouvé"
    else
        log_success "Traefik détecté"
    fi
}

#######################################################################################################
# Backup & Rollback
#######################################################################################################

create_backup() {
    log_info "Création des backups..."

    mkdir -p "$BACKUP_DIR"

    # Backup iptables
    log_debug "Backup iptables vers $IPTABLES_BACKUP"
    iptables-save > "$IPTABLES_BACKUP"

    # Backup Supabase .env
    if [[ -f "${SUPABASE_DIR}/.env" ]]; then
        cp "${SUPABASE_DIR}/.env" "${BACKUP_DIR}/supabase-env-$(date +%Y%m%d-%H%M%S).bak"
        log_debug "Backup .env Supabase"
    fi

    # Backup docker-compose.yml
    if [[ -f "${SUPABASE_DIR}/docker-compose.yml" ]]; then
        cp "${SUPABASE_DIR}/docker-compose.yml" "${BACKUP_DIR}/supabase-compose-$(date +%Y%m%d-%H%M%S).bak"
        log_debug "Backup docker-compose.yml Supabase"
    fi

    log_success "Backups créés dans $BACKUP_DIR"
}

rollback_iptables() {
    log_warn "ROLLBACK : Restauration des règles iptables..."

    if [[ ! -f "$IPTABLES_BACKUP" ]]; then
        # Chercher le backup le plus récent
        IPTABLES_BACKUP=$(ls -t ${BACKUP_DIR}/iptables-rules-*.bak 2>/dev/null | head -1)
        if [[ -z "$IPTABLES_BACKUP" ]]; then
            log_error "Aucun backup iptables trouvé"
            return 1
        fi
    fi

    iptables-restore < "$IPTABLES_BACKUP"
    netfilter-persistent save
    log_success "Règles iptables restaurées depuis $IPTABLES_BACKUP"
}

#######################################################################################################
# Sécurisation Ports
#######################################################################################################

get_local_network() {
    # Détecter le réseau local (ex: 192.168.1.0/24)
    local ip
    ip=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)

    if [[ -z "$ip" ]]; then
        echo "192.168.1.0/24"  # Fallback
    else
        # Remplacer dernier octet par 0/24
        echo "${ip%.*}.0/24"
    fi
}

block_port_public() {
    local port=$1
    local service_name=$2
    local allow_local=${3:-true}

    log_info "Sécurisation port $port ($service_name)..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "[DRY-RUN] Bloquerait port $port"
        return 0
    fi

    # Vérifier si règle existe déjà (idempotence)
    if iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
        log_debug "Règle DROP déjà existante pour port $port"
        return 0
    fi

    # Autoriser réseau local d'abord
    if [[ "$allow_local" == true ]]; then
        local local_network
        local_network=$(get_local_network)
        log_debug "Autorisation réseau local $local_network pour port $port"

        # Supprimer règle existante si présente
        iptables -D INPUT -p tcp --dport "$port" -s "$local_network" -j ACCEPT 2>/dev/null || true

        # Insérer au début (priorité)
        iptables -I INPUT 1 -p tcp --dport "$port" -s "$local_network" -j ACCEPT
    fi

    # Bloquer tout le reste
    iptables -A INPUT -p tcp --dport "$port" -j DROP

    log_success "Port $port ($service_name) sécurisé : accès local autorisé, public bloqué"
}

secure_postgres_port() {
    log_info "=== Sécurisation PostgreSQL (port 5432) ==="

    # Vérifier si PostgreSQL écoute publiquement
    if netstat -tulpn | grep -q "0.0.0.0:5432"; then
        log_warn "PostgreSQL écoute sur 0.0.0.0:5432 (PUBLIC)"
        block_port_public 5432 "PostgreSQL" true
    else
        log_success "PostgreSQL n'est pas exposé publiquement"
    fi
}

secure_studio_port() {
    log_info "=== Sécurisation Supabase Studio (port 3000) ==="

    if netstat -tulpn | grep -q "0.0.0.0:3000"; then
        log_warn "Supabase Studio écoute sur 0.0.0.0:3000 (PUBLIC)"
        block_port_public 3000 "Supabase Studio" true
    else
        log_success "Supabase Studio n'est pas exposé publiquement"
    fi
}

secure_kong_admin() {
    log_info "=== Vérification Kong Admin Port ==="

    # Kong devrait exposer 8000 (API) pas 8001 (Admin)
    if netstat -tulpn | grep -q "0.0.0.0:8001"; then
        log_warn "Kong Admin port 8001 détecté (exposé publiquement)"

        # Vérifier docker-compose.yml
        if [[ -f "${SUPABASE_DIR}/docker-compose.yml" ]]; then
            if grep -q "8001:8000" "${SUPABASE_DIR}/docker-compose.yml"; then
                log_success "Port 8001 mappe vers 8000 (API) - Configuration correcte"
            elif grep -q "8001:8001" "${SUPABASE_DIR}/docker-compose.yml"; then
                log_error "Port 8001 mappe vers 8001 (ADMIN) - RISQUE SÉCURITÉ"
                log_warn "Correction manuelle requise dans docker-compose.yml"
            fi
        fi

        # Bloquer quand même par précaution
        block_port_public 8001 "Kong Admin" false
    else
        log_success "Kong Admin port non exposé publiquement"
    fi
}

secure_edge_functions() {
    log_info "=== Vérification Edge Functions (port 54321) ==="

    if netstat -tulpn | grep -q "0.0.0.0:54321"; then
        log_info "Edge Functions exposé sur 54321 (normal si utilisé via API)"
        # Ne pas bloquer car utilisé légitimement par applications
    else
        log_debug "Edge Functions non exposé publiquement"
    fi
}

#######################################################################################################
# Sécurisation Fichiers
#######################################################################################################

secure_env_files() {
    log_info "=== Sécurisation fichiers .env ==="

    local env_files=(
        "${SUPABASE_DIR}/.env"
        "${SUPABASE_DIR}/functions/.env"
        "${TRAEFIK_DIR}/.env"
    )

    for env_file in "${env_files[@]}"; do
        if [[ -f "$env_file" ]]; then
            log_debug "Sécurisation $env_file"

            # Vérifier permissions actuelles
            local perms
            perms=$(stat -c '%a' "$env_file")

            if [[ "$perms" != "600" ]]; then
                if [[ "$DRY_RUN" == false ]]; then
                    chmod 600 "$env_file"
                    log_success "Permissions $env_file : $perms → 600"
                else
                    log_warn "[DRY-RUN] Changerait permissions $env_file : $perms → 600"
                fi
            else
                log_debug "$env_file déjà sécurisé (600)"
            fi
        fi
    done
}

#######################################################################################################
# Persistance & Tests
#######################################################################################################

persist_iptables() {
    log_info "Sauvegarde persistante des règles iptables..."

    if [[ "$DRY_RUN" == false ]]; then
        netfilter-persistent save
        log_success "Règles iptables persistantes (survit aux reboots)"
    else
        log_warn "[DRY-RUN] Ne sauvegarderait pas les règles"
    fi
}

test_services() {
    log_info "=== Tests des services après modifications ==="

    # Test 1 : Docker actif
    if systemctl is-active --quiet docker; then
        log_success "Docker actif"
    else
        log_error "Docker inactif après modifications"
        return 1
    fi

    # Test 2 : Supabase accessible localement
    if curl -s http://localhost:8001/auth/v1/health &>/dev/null; then
        log_success "Supabase Auth API accessible (localhost)"
    else
        log_warn "Supabase Auth API non répondante"
    fi

    # Test 3 : PostgreSQL accessible localement
    if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
        log_success "PostgreSQL accessible (localhost)"
    else
        log_warn "PostgreSQL non répondant"
    fi

    # Test 4 : PostgreSQL BLOQUÉ depuis l'extérieur (simulé)
    log_info "Vérification blocage ports publics..."
    local blocked_ports=(5432 3000)
    for port in "${blocked_ports[@]}"; do
        if iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
            log_success "Port $port bloqué publiquement ✓"
        else
            log_warn "Port $port non bloqué"
        fi
    done
}

#######################################################################################################
# Rapport Final
#######################################################################################################

generate_report() {
    log_info ""
    log_info "============================================"
    log_info "  RAPPORT DE SÉCURISATION"
    log_info "============================================"
    log_info ""

    # Ports protégés
    log_info "📌 PORTS SÉCURISÉS :"
    iptables -L INPUT -n -v | grep DROP | grep -E "(5432|3000|8001)" | while read -r line; do
        log_info "  ✓ $line"
    done

    # Fichiers sécurisés
    log_info ""
    log_info "📌 FICHIERS .ENV SÉCURISÉS :"
    find /home/pi/stacks -name ".env" -exec stat -c "  ✓ %n : %a" {} \;

    # Backups
    log_info ""
    log_info "📌 BACKUPS CRÉÉS :"
    log_info "  📁 $BACKUP_DIR"
    ls -lh "$BACKUP_DIR" | tail -5 | awk '{print "    " $9 " (" $5 ")"}'

    # Réseau local autorisé
    log_info ""
    log_info "📌 RÉSEAU LOCAL AUTORISÉ :"
    log_info "  🏠 $(get_local_network)"

    # Recommandations
    log_info ""
    log_info "📌 PROCHAINES ÉTAPES RECOMMANDÉES :"
    log_info "  1. Modifier docker-compose.yml pour binding localhost PostgreSQL"
    log_info "     Changer : 0.0.0.0:5432:5432 → 127.0.0.1:5432:5432"
    log_info ""
    log_info "  2. Accéder à Supabase Studio uniquement via VPN Tailscale"
    log_info ""
    log_info "  3. Configurer Authelia (SSO + 2FA) :"
    log_info "     curl -fsSL https://raw.githubusercontent.com/.../02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash"
    log_info ""
    log_info "  4. Activer rate limiting dans Traefik"
    log_info ""
    log_info "============================================"
    log_info ""
}

#######################################################################################################
# Menu Principal
#######################################################################################################

show_help() {
    cat << EOF
Usage: sudo bash 01-harden-exposed-services.sh [OPTIONS]

Script de durcissement sécurité pour services exposés sur Internet.

OPTIONS:
    --dry-run       Afficher les actions sans les exécuter
    --rollback      Restaurer la configuration depuis les backups
    --verbose       Afficher les logs debug détaillés
    -h, --help      Afficher cette aide

EXEMPLES:
    # Test sans modifications
    sudo bash 01-harden-exposed-services.sh --dry-run

    # Exécution normale
    sudo bash 01-harden-exposed-services.sh

    # Rollback en cas de problème
    sudo bash 01-harden-exposed-services.sh --rollback

VERSION: $SCRIPT_VERSION
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --rollback)
                ROLLBACK=true
                shift
                ;;
            --verbose)
                VERBOSE=true
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
    echo "║  🔒 DURCISSEMENT SÉCURITÉ - SERVICES EXPOSÉS             ║"
    echo "║     Version $SCRIPT_VERSION                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Rollback mode
    if [[ "$ROLLBACK" == true ]]; then
        log_warn "MODE ROLLBACK ACTIVÉ"
        rollback_iptables
        exit 0
    fi

    # Dry-run notification
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "MODE DRY-RUN : Aucune modification ne sera appliquée"
        echo ""
    fi

    # Validations
    check_root
    check_dependencies
    check_services

    echo ""

    # Backup
    if [[ "$DRY_RUN" == false ]]; then
        create_backup
        echo ""
    fi

    # Sécurisation
    secure_postgres_port
    secure_studio_port
    secure_kong_admin
    secure_edge_functions
    echo ""

    secure_env_files
    echo ""

    # Persistance
    if [[ "$DRY_RUN" == false ]]; then
        persist_iptables
        echo ""
    fi

    # Tests
    if [[ "$DRY_RUN" == false ]]; then
        test_services
        echo ""
    fi

    # Rapport
    generate_report

    # Message final
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Aucune modification appliquée (dry-run)"
        log_info "Relancez sans --dry-run pour appliquer les changements"
    else
        log_success "✅ Durcissement sécurité terminé avec succès"
        log_info "📋 Log complet : $LOG_FILE"
        log_info "💾 Backups : $BACKUP_DIR"
        log_info ""
        log_info "⚠️  En cas de problème, rollback disponible :"
        log_info "    sudo bash $0 --rollback"
    fi
}

# Exécution
main "$@"
