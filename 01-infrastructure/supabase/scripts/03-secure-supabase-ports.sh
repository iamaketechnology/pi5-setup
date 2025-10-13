#!/usr/bin/env bash
#######################################################################################################
# Script de Sécurisation Ports Supabase - Binding Localhost Permanent
#######################################################################################################
# Description : Modifie docker-compose.yml pour binding localhost (127.0.0.1) sur ports sensibles
# Version     : 1.0.0
# Usage       : sudo bash 03-secure-supabase-ports.sh [--dry-run] [--rollback]
#
# Fonctionnalités :
#   - Backup automatique docker-compose.yml avant modification
#   - Modification ports PostgreSQL (5432) : 0.0.0.0 → 127.0.0.1
#   - Modification ports Studio (3000) : 0.0.0.0 → 127.0.0.1
#   - Validation syntaxe docker-compose après modification
#   - Redémarrage containers avec test fonctionnel
#   - Rollback automatique si échec
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
SUPABASE_DIR="/home/pi/stacks/supabase"
COMPOSE_FILE="${SUPABASE_DIR}/docker-compose.yml"
BACKUP_DIR="/home/pi/backups/supabase-security"
LOG_FILE="/var/log/supabase-secure-ports.log"

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

check_supabase() {
    log_info "Vérification installation Supabase..."

    if [[ ! -d "$SUPABASE_DIR" ]]; then
        fatal "Répertoire Supabase non trouvé : $SUPABASE_DIR"
    fi

    if [[ ! -f "$COMPOSE_FILE" ]]; then
        fatal "Fichier docker-compose.yml non trouvé : $COMPOSE_FILE"
    fi

    # Vérifier containers actifs
    if ! docker ps --format '{{.Names}}' | grep -q "supabase-db"; then
        log_warn "Container supabase-db non actif (sera démarré après modifications)"
    else
        log_success "Supabase actif"
    fi
}

check_bindings() {
    log_info "Analyse des bindings actuels..."

    local postgres_line
    local studio_line

    postgres_line=$(grep -E '^\s+-\s+"?5432:5432"?' "$COMPOSE_FILE" | head -1 | xargs)
    studio_line=$(grep -E '^\s+-\s+"?3000:3000"?' "$COMPOSE_FILE" | head -1 | xargs)

    log_info "PostgreSQL binding actuel : ${postgres_line:-non trouvé}"
    log_info "Studio binding actuel     : ${studio_line:-non trouvé}"

    # Vérifier si déjà sécurisé
    if echo "$postgres_line" | grep -q "127.0.0.1:5432" && echo "$studio_line" | grep -q "127.0.0.1:3000"; then
        log_success "Les bindings sont déjà sécurisés (127.0.0.1)"
        log_info "Aucune modification nécessaire"
        exit 0
    fi

    # Vérifier si bindings publics ou non spécifiés
    if echo "$postgres_line" | grep -qE '"5432:5432"|0\.0\.0\.0:5432' || echo "$studio_line" | grep -qE '"3000:3000"|0\.0\.0\.0:3000'; then
        log_warn "Bindings publics ou non spécifiés détectés - modification requise"
        return 0
    fi

    log_info "Analyse des bindings terminée"
}

#######################################################################################################
# Backup & Rollback
#######################################################################################################

create_backup() {
    log_info "Création backup docker-compose.yml..."

    mkdir -p "$BACKUP_DIR"

    local backup_file="${BACKUP_DIR}/docker-compose-$(date +%Y%m%d-%H%M%S).yml"
    cp "$COMPOSE_FILE" "$backup_file"

    log_success "Backup créé : $backup_file"
    echo "$backup_file" > "${BACKUP_DIR}/.last_backup"
}

rollback_compose() {
    log_warn "ROLLBACK : Restauration docker-compose.yml..."

    local last_backup
    last_backup=$(cat "${BACKUP_DIR}/.last_backup" 2>/dev/null)

    if [[ -z "$last_backup" ]] || [[ ! -f "$last_backup" ]]; then
        # Chercher le backup le plus récent
        last_backup=$(ls -t "${BACKUP_DIR}"/docker-compose-*.yml 2>/dev/null | head -1)
        if [[ -z "$last_backup" ]]; then
            log_error "Aucun backup trouvé"
            return 1
        fi
    fi

    cp "$last_backup" "$COMPOSE_FILE"
    log_success "docker-compose.yml restauré depuis $last_backup"

    # Redémarrer Supabase
    log_info "Redémarrage Supabase..."
    cd "$SUPABASE_DIR"
    docker compose down
    docker compose up -d

    log_success "Rollback terminé"
}

#######################################################################################################
# Modification Bindings
#######################################################################################################

secure_postgres_binding() {
    log_info "Sécurisation binding PostgreSQL..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "[DRY-RUN] Changerait : \"5432:5432\" → \"127.0.0.1:5432:5432\""
        return 0
    fi

    # Modifier binding PostgreSQL (tous les formats)
    sed -i.tmp 's/"0\.0\.0\.0:5432:5432"/"127.0.0.1:5432:5432"/g' "$COMPOSE_FILE"
    sed -i.tmp "s/'0\.0\.0\.0:5432:5432'/'127.0.0.1:5432:5432'/g" "$COMPOSE_FILE"
    sed -i.tmp 's/- 0\.0\.0\.0:5432:5432/- "127.0.0.1:5432:5432"/g' "$COMPOSE_FILE"

    # Format sans IP (shorthand) - le plus courant
    sed -i.tmp 's/"5432:5432"/"127.0.0.1:5432:5432"/g' "$COMPOSE_FILE"
    sed -i.tmp "s/'5432:5432'/'127.0.0.1:5432:5432'/g" "$COMPOSE_FILE"
    sed -i.tmp 's/- 5432:5432/- "127.0.0.1:5432:5432"/g' "$COMPOSE_FILE"

    # Nettoyer fichiers temporaires
    rm -f "${COMPOSE_FILE}.tmp"

    log_success "Binding PostgreSQL sécurisé : 127.0.0.1:5432"
}

secure_studio_binding() {
    log_info "Sécurisation binding Studio..."

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "[DRY-RUN] Changerait : \"3000:3000\" → \"127.0.0.1:3000:3000\""
        return 0
    fi

    # Modifier binding Studio (tous les formats)
    sed -i.tmp 's/"0\.0\.0\.0:3000:3000"/"127.0.0.1:3000:3000"/g' "$COMPOSE_FILE"
    sed -i.tmp "s/'0\.0\.0\.0:3000:3000'/'127.0.0.1:3000:3000'/g" "$COMPOSE_FILE"
    sed -i.tmp 's/- 0\.0\.0\.0:3000:3000/- "127.0.0.1:3000:3000"/g' "$COMPOSE_FILE"

    # Format sans IP (shorthand) - le plus courant
    sed -i.tmp 's/"3000:3000"/"127.0.0.1:3000:3000"/g' "$COMPOSE_FILE"
    sed -i.tmp "s/'3000:3000'/'127.0.0.1:3000:3000'/g" "$COMPOSE_FILE"
    sed -i.tmp 's/- 3000:3000/- "127.0.0.1:3000:3000"/g' "$COMPOSE_FILE"

    # Nettoyer fichiers temporaires
    rm -f "${COMPOSE_FILE}.tmp"

    log_success "Binding Studio sécurisé : 127.0.0.1:3000"
}

validate_compose() {
    log_info "Validation syntaxe docker-compose.yml..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Skip validation"
        return 0
    fi

    cd "$SUPABASE_DIR"
    if ! docker compose config > /dev/null 2>&1; then
        log_error "Syntaxe docker-compose.yml invalide !"
        return 1
    fi

    log_success "Syntaxe docker-compose.yml valide"
}

#######################################################################################################
# Redémarrage & Tests
#######################################################################################################

restart_supabase() {
    log_info "Redémarrage Supabase..."

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Skip redémarrage"
        return 0
    fi

    cd "$SUPABASE_DIR"

    log_debug "Arrêt containers..."
    docker compose down

    log_debug "Démarrage containers..."
    docker compose up -d

    log_info "Attente initialisation (30s)..."
    sleep 30

    log_success "Supabase redémarré"
}

test_services() {
    log_info "=== Tests des services ==="

    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Skip tests"
        return 0
    fi

    # Test 1 : PostgreSQL accessible localhost
    if docker exec supabase-db pg_isready -U postgres &>/dev/null; then
        log_success "PostgreSQL accessible (localhost)"
    else
        log_error "PostgreSQL non répondant"
        return 1
    fi

    # Test 2 : Auth API accessible
    if curl -s http://localhost:8001/auth/v1/health &>/dev/null; then
        log_success "Supabase Auth API accessible"
    else
        log_warn "Auth API non répondante (peut prendre plus de temps)"
    fi

    # Test 3 : Studio accessible localhost
    if curl -s http://localhost:3000/ &>/dev/null; then
        log_success "Studio accessible (localhost)"
    else
        log_warn "Studio non répondant (peut prendre plus de temps)"
    fi

    # Test 4 : Vérifier bindings effectifs
    log_info "Vérification bindings actifs..."
    if netstat -tulpn 2>/dev/null | grep -q "127.0.0.1:5432"; then
        log_success "PostgreSQL écoute sur 127.0.0.1:5432 ✓"
    else
        log_warn "PostgreSQL binding non détecté (container peut redémarrer)"
    fi

    if netstat -tulpn 2>/dev/null | grep -q "127.0.0.1:3000"; then
        log_success "Studio écoute sur 127.0.0.1:3000 ✓"
    else
        log_warn "Studio binding non détecté (container peut redémarrer)"
    fi
}

#######################################################################################################
# Rapport Final
#######################################################################################################

generate_report() {
    log_info ""
    log_info "============================================"
    log_info "  RAPPORT DE SÉCURISATION PORTS SUPABASE"
    log_info "============================================"
    log_info ""

    # Bindings actuels
    log_info "📌 BINDINGS SÉCURISÉS :"
    local pg_binding
    local studio_binding
    pg_binding=$(grep -A 2 "db:" "$COMPOSE_FILE" | grep "5432:5432" | grep -oP '"[^"]+:5432' | head -1 | tr -d '"')
    studio_binding=$(grep -A 20 "studio:" "$COMPOSE_FILE" | grep "3000:3000" | grep -oP '"[^"]+:3000' | head -1 | tr -d '"')

    log_info "  ✓ PostgreSQL : $pg_binding"
    log_info "  ✓ Studio     : $studio_binding"

    # Backup
    log_info ""
    log_info "📌 BACKUP CRÉÉ :"
    log_info "  📁 $BACKUP_DIR"
    ls -lh "$BACKUP_DIR" | tail -3 | awk '{print "    " $9 " (" $5 ")"}'

    # Accès
    log_info ""
    log_info "📌 ACCÈS AUX SERVICES :"
    log_info "  🔒 PostgreSQL : psql -h localhost -p 5432 -U postgres"
    log_info "  🔒 Studio     : http://localhost:3000 (SSH tunnel requis)"
    log_info ""
    log_info "  💡 SSH Tunnel depuis votre machine :"
    log_info "     ssh -L 3000:localhost:3000 -L 5432:localhost:5432 pi@$(hostname -I | awk '{print $1}')"
    log_info ""
    log_info "  💡 Ou installer Tailscale VPN :"
    log_info "     sudo bash 01-infrastructure/vpn-wireguard/scripts/01-setup-tailscale.sh"

    # Recommandations
    log_info ""
    log_info "📌 PROCHAINES ÉTAPES :"
    log_info "  1. Installer Tailscale VPN pour accès distant sécurisé"
    log_info "  2. Configurer rate limiting dans Traefik"
    log_info "  3. Installer Authelia (SSO + 2FA)"
    log_info ""
    log_info "============================================"
    log_info ""
}

#######################################################################################################
# Menu Principal
#######################################################################################################

show_help() {
    cat << EOF
Usage: sudo bash 03-secure-supabase-ports.sh [OPTIONS]

Script de sécurisation ports Supabase (binding localhost).

OPTIONS:
    --dry-run       Afficher les actions sans les exécuter
    --rollback      Restaurer docker-compose.yml depuis backup
    --verbose       Afficher les logs debug détaillés
    -h, --help      Afficher cette aide

EXEMPLES:
    # Test sans modifications
    sudo bash 03-secure-supabase-ports.sh --dry-run

    # Exécution normale
    sudo bash 03-secure-supabase-ports.sh

    # Rollback en cas de problème
    sudo bash 03-secure-supabase-ports.sh --rollback

ACTIONS:
    - Backup docker-compose.yml
    - PostgreSQL : 0.0.0.0:5432 → 127.0.0.1:5432
    - Studio     : 0.0.0.0:3000 → 127.0.0.1:3000
    - Validation syntaxe docker-compose
    - Redémarrage Supabase
    - Tests fonctionnels

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
    echo "║  🔒 SÉCURISATION PORTS SUPABASE - BINDING LOCALHOST      ║"
    echo "║     Version $SCRIPT_VERSION                                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Rollback mode
    if [[ "$ROLLBACK" == true ]]; then
        log_warn "MODE ROLLBACK ACTIVÉ"
        rollback_compose
        exit 0
    fi

    # Dry-run notification
    if [[ "$DRY_RUN" == true ]]; then
        log_warn "MODE DRY-RUN : Aucune modification ne sera appliquée"
        echo ""
    fi

    # Validations
    check_root
    check_supabase
    check_bindings

    echo ""

    # Backup
    if [[ "$DRY_RUN" == false ]]; then
        create_backup
        echo ""
    fi

    # Modifications
    secure_postgres_binding
    secure_studio_binding
    echo ""

    # Validation
    if [[ "$DRY_RUN" == false ]]; then
        if ! validate_compose; then
            log_error "Validation échouée - Rollback..."
            rollback_compose
            exit 1
        fi
        echo ""
    fi

    # Redémarrage
    if [[ "$DRY_RUN" == false ]]; then
        restart_supabase
        echo ""
    fi

    # Tests
    if [[ "$DRY_RUN" == false ]]; then
        if ! test_services; then
            log_warn "Certains tests ont échoué - Vérifier manuellement"
        fi
        echo ""
    fi

    # Rapport
    generate_report

    # Message final
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Aucune modification appliquée (dry-run)"
        log_info "Relancez sans --dry-run pour appliquer les changements"
    else
        log_success "✅ Sécurisation ports Supabase terminée avec succès"
        log_info "📋 Log complet : $LOG_FILE"
        log_info "💾 Backups : $BACKUP_DIR"
        log_info ""
        log_info "⚠️  En cas de problème, rollback disponible :"
        log_info "    sudo bash $0 --rollback"
    fi
}

# Exécution
main "$@"
