#!/bin/bash
# =============================================================================
# Fix n8n <-> Ollama <-> Supabase Network Connectivity
# =============================================================================
# Version: 2.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 02-fix-n8n-connectivity.sh
# Description: Ensures n8n can communicate with Ollama and Supabase via Docker networks
# =============================================================================

set -euo pipefail

# ==================== Logging Functions ====================
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }

# ==================== Root Check ====================
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo"
    exit 1
fi

# ==================== Constants ====================
OLLAMA_NETWORK="ollama_network"
SUPABASE_NETWORK="supabase_network"
N8N_CONTAINER="n8n"
SUPABASE_KONG_CONTAINER="supabase-kong"

# ==================== Functions ====================

check_container_exists() {
    local container=$1
    if ! docker ps -q -f name="^${container}$" | grep -q .; then
        log_error "Container '$container' n'existe pas ou n'est pas démarré"
        return 1
    fi
    return 0
}

check_network_exists() {
    local network=$1
    if ! docker network ls --format '{{.Name}}' | grep -q "^${network}$"; then
        log_error "Network '$network' n'existe pas"
        return 1
    fi
    return 0
}

is_container_connected() {
    local container=$1
    local network=$2

    # Get container ID
    local container_id
    container_id=$(docker ps -q -f name="^${container}$")

    # Check if container is in network
    if docker network inspect "$network" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "$container"; then
        return 0
    fi
    return 1
}

connect_container_to_network() {
    local container=$1
    local network=$2

    log_info "Connexion de '$container' au réseau '$network'..."
    if docker network connect "$network" "$container" 2>/dev/null; then
        log_success "Container connecté au réseau"
        return 0
    else
        log_error "Échec de la connexion au réseau"
        return 1
    fi
}

test_connectivity() {
    local from_container=$1
    local to_container=$2

    log_info "Test de connectivité: $from_container -> $to_container..."

    if docker exec "$from_container" ping -c 2 "$to_container" >/dev/null 2>&1; then
        log_success "Connectivité OK ($from_container peut joindre $to_container)"
        return 0
    else
        log_error "Connectivité ÉCHEC ($from_container ne peut pas joindre $to_container)"
        return 1
    fi
}

# ==================== Main Logic ====================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 FIX N8N <-> OLLAMA <-> SUPABASE NETWORK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check n8n container exists
log_info "Vérification du container n8n..."
check_container_exists "$N8N_CONTAINER" || exit 1
log_success "Container n8n est démarré"

# Step 2: Check and connect to Ollama network
log_info "═══ OLLAMA ═══"
OLLAMA_AVAILABLE=false
if check_container_exists "ollama" 2>/dev/null; then
    log_success "Container Ollama trouvé"

    if check_network_exists "$OLLAMA_NETWORK"; then
        log_success "Réseau '$OLLAMA_NETWORK' existe"

        # Check/connect n8n to ollama network
        if is_container_connected "$N8N_CONTAINER" "$OLLAMA_NETWORK"; then
            log_success "n8n déjà connecté au réseau Ollama"
        else
            connect_container_to_network "$N8N_CONTAINER" "$OLLAMA_NETWORK" || {
                log_error "Échec connexion au réseau Ollama"
            }
        fi

        # Test connectivity
        if test_connectivity "$N8N_CONTAINER" "ollama"; then
            OLLAMA_AVAILABLE=true
        fi
    else
        log_warn "Réseau Ollama introuvable (normal si Ollama non installé)"
    fi
else
    log_warn "Container Ollama non trouvé (non installé ou arrêté)"
fi

# Step 3: Check and connect to Supabase network
log_info "═══ SUPABASE ═══"
SUPABASE_AVAILABLE=false
if check_container_exists "$SUPABASE_KONG_CONTAINER" 2>/dev/null; then
    log_success "Container Supabase Kong trouvé"

    if check_network_exists "$SUPABASE_NETWORK" 2>/dev/null; then
        log_success "Réseau '$SUPABASE_NETWORK' existe"

        # Check/connect n8n to supabase network
        if is_container_connected "$N8N_CONTAINER" "$SUPABASE_NETWORK"; then
            log_success "n8n déjà connecté au réseau Supabase"
        else
            connect_container_to_network "$N8N_CONTAINER" "$SUPABASE_NETWORK" || {
                log_error "Échec connexion au réseau Supabase"
            }
        fi

        # Test connectivity
        if test_connectivity "$N8N_CONTAINER" "$SUPABASE_KONG_CONTAINER"; then
            SUPABASE_AVAILABLE=true
        fi
    else
        log_warn "Réseau Supabase introuvable (normal si Supabase non installé)"
    fi
else
    log_warn "Container Supabase Kong non trouvé (non installé ou arrêté)"
fi

# Check if at least one service is available
if [[ "$OLLAMA_AVAILABLE" == "false" && "$SUPABASE_AVAILABLE" == "false" ]]; then
    log_error "Aucun service (Ollama/Supabase) n'est accessible depuis n8n"
    log_info "Installez Ollama et/ou Supabase puis relancez ce script"
    exit 1
fi

# ==================== Summary ====================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 CONNECTIVITÉ N8N CONFIGURÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Display available services
if [[ "$OLLAMA_AVAILABLE" == "true" ]]; then
    echo "✅ Ollama accessible depuis n8n"
    echo "   📌 URL dans n8n : http://ollama:11434"
    echo "   🧠 Modèles installés : docker exec ollama ollama list"
    echo "   🔗 Test : docker exec n8n curl -s http://ollama:11434/api/tags"
    echo ""
fi

if [[ "$SUPABASE_AVAILABLE" == "true" ]]; then
    echo "✅ Supabase accessible depuis n8n"
    echo "   📌 URL API dans n8n : http://supabase-kong:8000"
    echo "   📌 URL REST : http://supabase-kong:8000/rest/v1"
    echo "   🔗 Test : docker exec n8n curl -s http://supabase-kong:8000/rest/v1/"
    echo ""
fi

echo "📚 Guide workflows n8n :"
echo "   - Ollama + Supabase : ~/stacks/n8n/README.md"
echo ""
