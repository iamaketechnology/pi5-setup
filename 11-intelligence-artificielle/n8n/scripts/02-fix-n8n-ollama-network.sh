#!/bin/bash
# =============================================================================
# Fix n8n <-> Ollama Network Connectivity
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 02-fix-n8n-ollama-network.sh
# Description: Ensures n8n can communicate with Ollama via Docker networks
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
N8N_CONTAINER="n8n"

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
echo "🔧 FIX N8N <-> OLLAMA NETWORK CONNECTIVITY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Check containers exist
log_info "Vérification des containers..."
check_container_exists "$N8N_CONTAINER" || exit 1
check_container_exists "ollama" || exit 1
log_success "Containers n8n et ollama sont démarrés"

# Step 2: Check network exists
log_info "Vérification du réseau Ollama..."
check_network_exists "$OLLAMA_NETWORK" || exit 1
log_success "Réseau '$OLLAMA_NETWORK' existe"

# Step 3: Check if n8n is already connected
log_info "Vérification de la connexion réseau..."
if is_container_connected "$N8N_CONTAINER" "$OLLAMA_NETWORK"; then
    log_success "n8n est déjà connecté au réseau Ollama"

    # Test connectivity anyway
    if test_connectivity "$N8N_CONTAINER" "ollama"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✅ TOUT EST OK - AUCUNE ACTION NÉCESSAIRE"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📌 URL Ollama dans n8n : http://ollama:11434"
        echo ""
        exit 0
    else
        log_warn "Connecté mais ping échoue, tentative de reconnexion..."
        docker network disconnect "$OLLAMA_NETWORK" "$N8N_CONTAINER" 2>/dev/null || true
    fi
fi

# Step 4: Connect n8n to ollama network
connect_container_to_network "$N8N_CONTAINER" "$OLLAMA_NETWORK" || exit 1

# Step 5: Test connectivity
if ! test_connectivity "$N8N_CONTAINER" "ollama"; then
    log_error "Connectivité échouée après connexion au réseau"
    log_info "Vérifiez que le container Ollama fonctionne : docker logs ollama"
    exit 1
fi

# ==================== Summary ====================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 CONNECTIVITÉ N8N <-> OLLAMA RESTAURÉE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ n8n peut maintenant communiquer avec Ollama"
echo ""
echo "📌 Configuration dans n8n :"
echo "   - URL Ollama : http://ollama:11434"
echo "   - Modèles disponibles : docker exec ollama ollama list"
echo ""
echo "🔗 Test manuel depuis n8n container :"
echo "   docker exec n8n curl -s http://ollama:11434/api/tags"
echo ""
