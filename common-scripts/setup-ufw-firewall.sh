#!/bin/bash
# =============================================================================
# Setup UFW Firewall - Intelligent & Idempotent
# =============================================================================
# Purpose: Install and configure UFW firewall with smart port detection
# Version: 1.0.0
# Author: PI5-SETUP Project
# Usage: sudo bash setup-ufw-firewall.sh
# Features:
#   - Auto-detects running services and their ports
#   - Idempotent (safe to re-run)
#   - Preserves SSH access
#   - Smart defaults based on detected stacks
# =============================================================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variables
CURRENT_USER="${SUDO_USER:-$(logname 2>/dev/null || echo pi)}"
SSH_PORT="${SSH_PORT:-22}"
DRY_RUN="${DRY_RUN:-no}"

# =============================================================================
# Logging Functions
# =============================================================================

log()   { echo -e "${BLUE}[UFW-SETUP]${NC} $*"; }
ok()    { echo -e "${GREEN}✅${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠️${NC}  $*"; }
error() { echo -e "${RED}❌${NC} $*"; }
info()  { echo -e "${CYAN}ℹ️${NC}  $*"; }

# =============================================================================
# Check Root
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    error "Ce script doit être lancé en root"
    echo "Usage: sudo $0"
    echo "   ou: sudo SSH_PORT=2222 $0  (si SSH sur port custom)"
    exit 1
fi

# =============================================================================
# Functions
# =============================================================================

detect_ssh_port() {
    log "🔍 Détection port SSH..."

    # Tenter de détecter depuis sshd_config
    local detected_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo "")

    if [[ -n "$detected_port" ]] && [[ "$detected_port" =~ ^[0-9]+$ ]]; then
        SSH_PORT="$detected_port"
        info "Port SSH détecté depuis config: $SSH_PORT"
    else
        # Vérifier netstat
        if command -v netstat &>/dev/null; then
            local listening_ssh=$(sudo netstat -tlnp 2>/dev/null | grep "sshd" | grep -oE ":[0-9]+" | cut -d: -f2 | head -1)
            if [[ -n "$listening_ssh" ]]; then
                SSH_PORT="$listening_ssh"
                info "Port SSH détecté depuis netstat: $SSH_PORT"
            else
                warn "Port SSH non détecté, utilisation par défaut: $SSH_PORT"
            fi
        else
            warn "netstat non disponible, utilisation port par défaut: $SSH_PORT"
        fi
    fi

    ok "Port SSH: $SSH_PORT"
}

detect_services() {
    log "🔍 Détection services actifs..."
    echo ""

    # Utiliser array associatif pour éviter les doublons
    declare -A services_map
    local services_found=()

    # Détecter via Docker
    if command -v docker &>/dev/null && docker ps &>/dev/null 2>&1; then
        info "Docker détecté, analyse des containers..."

        # Supabase
        if docker ps --format '{{.Names}}' | grep -q "supabase"; then
            services_map["supabase"]=1
            info "  - Supabase (Kong API:8001, Edge Functions:54321)"
        fi

        # Traefik
        if docker ps --format '{{.Names}}' | grep -q "traefik"; then
            services_map["traefik"]=1
            info "  - Traefik (HTTP:80, HTTPS:443)"
        fi

        # Homepage
        if docker ps --format '{{.Names}}' | grep -q "homepage"; then
            services_map["homepage"]=1
            info "  - Homepage"
        fi

        # Grafana/Prometheus
        if docker ps --format '{{.Names}}' | grep -qE "grafana|prometheus"; then
            services_map["monitoring"]=1
            info "  - Monitoring (Grafana/Prometheus)"
        fi
    fi

    # Détecter services système
    if systemctl is-active --quiet apache2 2>/dev/null; then
        services_map["apache"]=1
        info "  - Apache (HTTP:80, HTTPS:443)"
    fi

    if systemctl is-active --quiet nginx 2>/dev/null; then
        services_map["nginx"]=1
        info "  - Nginx (HTTP:80, HTTPS:443)"
    fi

    # Convertir map en array
    for service in "${!services_map[@]}"; do
        services_found+=("$service")
    done

    echo ""

    if [[ ${#services_found[@]} -eq 0 ]]; then
        warn "Aucun service spécifique détecté"
        info "Configuration UFW minimale (SSH seulement)"
    else
        ok "Services détectés: ${services_found[*]}"
    fi

    echo "${services_found[@]}"
}

install_ufw() {
    if command -v ufw &>/dev/null; then
        ok "UFW déjà installé"
        return 0
    fi

    log "📦 Installation UFW..."

    if [[ "$DRY_RUN" == "yes" ]]; then
        info "[DRY-RUN] apt install ufw"
        return 0
    fi

    apt update -qq || { error "Échec apt update"; exit 1; }
    apt install -y ufw || { error "Échec installation UFW"; exit 1; }

    ok "UFW installé"
}

configure_ufw() {
    local services=("$@")

    log "⚙️  Configuration UFW..."
    echo ""

    if [[ "$DRY_RUN" == "yes" ]]; then
        info "[DRY-RUN] Configuration UFW simulée"
        echo ""
        info "Règles qui seraient ajoutées :"
        echo "  - SSH ($SSH_PORT/tcp)"
        for service in "${services[@]}"; do
            case "$service" in
                supabase)
                    echo "  - Kong API (8001/tcp)"
                    echo "  - Edge Functions (54321/tcp)"
                    ;;
                traefik|apache|nginx)
                    echo "  - HTTP (80/tcp)"
                    echo "  - HTTPS (443/tcp)"
                    ;;
            esac
        done
        return 0
    fi

    # Désactiver temporairement si actif (pour éviter lockout)
    if ufw status | grep -q "Status: active"; then
        info "UFW actuellement actif, désactivation temporaire..."
        ufw --force disable >/dev/null 2>&1
    fi

    # Reset et configuration par défaut
    log "Configuration politiques par défaut..."
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming >/dev/null 2>&1
    ufw default allow outgoing >/dev/null 2>&1
    ok "Politiques par défaut configurées"

    # SSH (CRITIQUE - toujours en premier)
    log "Ajout règle SSH (port $SSH_PORT)..."
    ufw allow "$SSH_PORT"/tcp comment "SSH" >/dev/null 2>&1
    ok "SSH autorisé (port $SSH_PORT)"

    # Rate limiting SSH (protection brute-force)
    log "Activation rate limiting SSH..."
    ufw limit "$SSH_PORT"/tcp >/dev/null 2>&1
    ok "Rate limiting SSH activé"

    # Services détectés
    for service in "${services[@]}"; do
        case "$service" in
            supabase)
                log "Configuration ports Supabase..."
                ufw allow 8001/tcp comment "Supabase Kong API" >/dev/null 2>&1
                ufw allow 54321/tcp comment "Supabase Edge Functions" >/dev/null 2>&1
                ok "Supabase configuré (Kong:8001, Edge Functions:54321)"
                ;;

            traefik|apache|nginx)
                log "Configuration ports web..."
                ufw allow 80/tcp comment "HTTP" >/dev/null 2>&1
                ufw allow 443/tcp comment "HTTPS" >/dev/null 2>&1
                ok "Web configuré (HTTP:80, HTTPS:443)"
                ;;

            monitoring)
                # Monitoring généralement interne ou via Traefik, pas de ports publics
                info "Monitoring détecté (pas de ports publics requis)"
                ;;
        esac
    done

    # Activer UFW
    log "Activation UFW..."
    echo "y" | ufw enable >/dev/null 2>&1
    ok "UFW activé"

    echo ""
}

show_summary() {
    log "📊 Statut UFW :"
    echo ""

    ufw status verbose | while read line; do
        if echo "$line" | grep -q "Status: active"; then
            echo -e "  ${GREEN}✅${NC} $line"
        elif echo "$line" | grep -q "ALLOW"; then
            echo -e "  ${GREEN}→${NC} $line"
        elif echo "$line" | grep -q "DENY"; then
            echo -e "  ${RED}→${NC} $line"
        else
            echo "  $line"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 UFW FIREWALL CONFIGURÉ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🔒 Politique par défaut :"
    echo "  ✅ Trafic entrant: DENY (bloquer tout par défaut)"
    echo "  ✅ Trafic sortant: ALLOW (autoriser tout)"
    echo ""
    echo "🔓 Ports autorisés :"
    echo "  ✅ SSH (port $SSH_PORT) avec rate limiting"

    ufw status | grep -E "ALLOW|LIMIT" | while read rule; do
        echo "  ✅ $rule"
    done

    echo ""
    echo "📋 Commandes utiles :"
    echo "  - Voir règles : sudo ufw status numbered"
    echo "  - Ajouter port : sudo ufw allow 1234/tcp comment 'Mon service'"
    echo "  - Supprimer règle : sudo ufw delete <numero>"
    echo "  - Désactiver : sudo ufw disable"
    echo ""
}

verify_ssh_access() {
    log "🔍 Vérification accès SSH..."

    # Vérifier que SSH est bien autorisé
    if ! ufw status | grep -qE "$SSH_PORT.*ALLOW|$SSH_PORT.*LIMIT"; then
        error "SSH (port $SSH_PORT) n'est PAS autorisé dans UFW !"
        error "Risque de perte d'accès distant"
        warn "Ajout manuel de la règle SSH..."
        ufw allow "$SSH_PORT"/tcp comment "SSH" >/dev/null 2>&1
        ok "Règle SSH ajoutée"
    else
        ok "SSH autorisé dans UFW (port $SSH_PORT)"
    fi

    # Vérifier que SSH est actif
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        ok "Service SSH actif"
    else
        warn "Service SSH non actif"
    fi
}

# =============================================================================
# Main
# =============================================================================

main() {
    log "🛡️  Setup UFW Firewall - Intelligent & Idempotent"
    echo ""

    # Détection port SSH
    detect_ssh_port
    echo ""

    # Détection services
    services=$(detect_services)
    echo ""

    # Installation UFW
    install_ufw
    echo ""

    # Configuration
    configure_ufw $services
    echo ""

    # Vérification critique SSH
    verify_ssh_access
    echo ""

    # Afficher résumé
    show_summary
}

# =============================================================================
# Execute
# =============================================================================

main "$@"
