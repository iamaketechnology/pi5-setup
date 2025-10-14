#!/bin/bash
# =============================================================================
# PI5 Dashboard - Deployment Script
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 01-dashboard-deploy.sh
# Description: Deploy real-time n8n workflow monitoring dashboard
# =============================================================================

set -euo pipefail

# =============================================================================
# Logging Functions
# =============================================================================

log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# =============================================================================
# Configuration
# =============================================================================

CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")
STACK_DIR="${USER_HOME}/stacks/dashboard"
PROJECT_NAME="pi5-dashboard"

# =============================================================================
# Validation
# =============================================================================

if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo"
    exit 1
fi

log_info "Déploiement Dashboard pour utilisateur: ${CURRENT_USER}"

# =============================================================================
# Check Dependencies
# =============================================================================

check_dependencies() {
    log_info "Vérification des dépendances..."

    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé"
        exit 1
    fi

    # Check Traefik network
    if ! docker network ls | grep -q "traefik_network"; then
        log_error "Réseau traefik_network introuvable"
        log_error "Déployez Traefik d'abord: 01-infrastructure/traefik/scripts/01-traefik-deploy.sh"
        exit 1
    fi

    log_success "Dépendances OK"
}

# =============================================================================
# Check Existing Installation
# =============================================================================

check_existing() {
    if docker ps --format '{{.Names}}' | grep -q "^${PROJECT_NAME}$"; then
        log_info "Dashboard déjà installé et en cours d'exécution"

        read -p "Voulez-vous redéployer? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Déploiement annulé"
            exit 0
        fi

        log_info "Arrêt du conteneur existant..."
        docker stop "${PROJECT_NAME}" || true
        docker rm "${PROJECT_NAME}" || true
    fi
}

# =============================================================================
# Setup Directory Structure
# =============================================================================

setup_directories() {
    log_info "Création de la structure de répertoires..."

    mkdir -p "${STACK_DIR}"/{compose,src/{server,public/{css,js}}}

    log_success "Structure créée: ${STACK_DIR}"
}

# =============================================================================
# Copy Files
# =============================================================================

copy_files() {
    log_info "Copie des fichiers de configuration..."

    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local source_dir="$(dirname "${script_dir}")"

    # Copy docker-compose.yml
    cp "${source_dir}/compose/docker-compose.yml" "${STACK_DIR}/compose/"

    # Copy source files
    cp -r "${source_dir}/src/"* "${STACK_DIR}/src/"

    # Set permissions
    chown -R "${CURRENT_USER}:${CURRENT_USER}" "${STACK_DIR}"

    log_success "Fichiers copiés et permissions définies"
}

# =============================================================================
# Deploy Stack
# =============================================================================

deploy_stack() {
    log_info "Déploiement du dashboard..."

    cd "${STACK_DIR}/compose"

    # Pull image
    docker pull node:22-alpine

    # Start container
    docker compose up -d

    log_success "Container démarré"
}

# =============================================================================
# Health Check
# =============================================================================

health_check() {
    log_info "Vérification du démarrage (30s max)..."

    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker ps --filter "name=${PROJECT_NAME}" --filter "status=running" | grep -q "${PROJECT_NAME}"; then
            sleep 2  # Wait for server to be ready

            if curl -sf http://localhost:3000/health > /dev/null 2>&1; then
                log_success "Dashboard opérationnel!"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        sleep 1
    done

    log_error "Le dashboard n'a pas démarré correctement"
    log_error "Logs du conteneur:"
    docker logs "${PROJECT_NAME}" --tail 50
    exit 1
}

# =============================================================================
# Display Summary
# =============================================================================

display_summary() {
    local ip_address=$(hostname -I | awk '{print $1}')

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 DASHBOARD INSTALLÉ AVEC SUCCÈS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📊 Accès Interface Web:"
    echo "   • Local:    http://localhost:3100"
    echo "   • Réseau:   http://${ip_address}:3100"
    echo "   • Traefik:  http://dashboard.pi5.local (si DNS configuré)"
    echo ""
    echo "🔗 Webhook n8n:"
    echo "   URL: http://${ip_address}:3100/api/webhook"
    echo "   Méthode: POST"
    echo "   Body: {\"workflow\": \"nom\", \"status\": \"success\", \"message\": \"...\"}"
    echo ""
    echo "📝 Commandes utiles:"
    echo "   • Logs:     docker logs ${PROJECT_NAME} -f"
    echo "   • Restart:  docker restart ${PROJECT_NAME}"
    echo "   • Stop:     docker stop ${PROJECT_NAME}"
    echo ""
    echo "📁 Répertoire: ${STACK_DIR}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    log_info "Début du déploiement PI5 Dashboard v1.0.0"

    check_dependencies
    check_existing
    setup_directories
    copy_files
    deploy_stack
    health_check
    display_summary

    log_success "Déploiement terminé!"
}

main "$@"
