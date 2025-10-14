#!/bin/bash
# =============================================================================
# Ollama Models Auto-Updater - Raspberry Pi 5
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 03-update-models.sh [--cron]
# =============================================================================
# Met à jour automatiquement tous les modèles Ollama installés
# Idempotent : Ne re-télécharge que si nouvelle version disponible
# Peut être ajouté au cron pour mises à jour automatiques
# =============================================================================

set -euo pipefail

# === Logging functions ===
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }

# === Configuration ===
CRON_MODE=false
LOG_FILE="${HOME}/ollama-updates.log"

# === Parse arguments ===
if [[ "${1:-}" == "--cron" ]]; then
    CRON_MODE=true
    exec >> "$LOG_FILE" 2>&1
fi

# === Check Ollama running ===
check_ollama() {
    if ! docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
        log_error "Ollama n'est pas démarré"
        exit 1
    fi
}

# === Get installed models ===
get_installed_models() {
    docker exec ollama ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | grep -v '^$'
}

# === Check for updates ===
check_update() {
    local model=$1

    log_info "Vérification $model..."

    # Ollama pull retourne 0 si déjà à jour, télécharge sinon
    if docker exec ollama ollama pull "$model" 2>&1 | tee /tmp/ollama_pull.log | grep -q "Already up to date"; then
        log_success "$model déjà à jour"
        return 1
    else
        if grep -q "success" /tmp/ollama_pull.log; then
            log_success "$model mis à jour !"
            return 0
        else
            log_warn "$model : Échec mise à jour"
            return 1
        fi
    fi
}

# === Main update loop ===
update_all_models() {
    local models
    models=$(get_installed_models)

    if [[ -z "$models" ]]; then
        log_warn "Aucun modèle installé"
        exit 0
    fi

    local updated_count=0
    local total_count=0

    echo ""
    log_info "Recherche de mises à jour pour $(echo "$models" | wc -l) modèle(s)..."
    echo ""

    while IFS= read -r model; do
        [[ -z "$model" ]] && continue
        ((total_count++))

        if check_update "$model"; then
            ((updated_count++))
        fi

        echo ""
    done <<< "$models"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 RÉSUMÉ MIS À JOUR"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total modèles : $total_count"
    echo "Mis à jour    : $updated_count"
    echo "Déjà à jour   : $((total_count - updated_count))"
    echo ""
}

# === Cleanup old models ===
cleanup_old_models() {
    log_info "Nettoyage anciennes versions..."

    # Ollama garde automatiquement les versions, on supprime les anciennes
    docker exec ollama ollama rm $(docker exec ollama ollama list | grep '<none>' | awk '{print $1}') 2>/dev/null || true

    log_success "Nettoyage terminé"
}

# === Show space usage ===
show_space() {
    local models_dir="${HOME}/data/ollama/models"

    if [[ ! -d "$models_dir" ]]; then
        return
    fi

    local size=$(du -sh "$models_dir" 2>/dev/null | awk '{print $1}')

    echo "💾 Espace utilisé : $size"
    echo "📁 Emplacement : $models_dir"
}

# === Setup cron ===
setup_cron() {
    local script_path=$(realpath "$0")
    local cron_line="0 3 * * 0 ${script_path} --cron"

    log_info "Configuration cron pour mises à jour automatiques..."
    log_info "Fréquence : Tous les dimanches à 3h du matin"

    # Check si déjà dans cron
    if crontab -l 2>/dev/null | grep -q "$script_path"; then
        log_success "Cron déjà configuré"
        return
    fi

    # Ajouter au cron
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -

    log_success "Cron configuré ! Logs : $LOG_FILE"
    echo ""
    echo "Pour désactiver : crontab -e (puis supprimer la ligne)"
}

# === Main ===
main() {
    [[ "$CRON_MODE" == true ]] && echo "===  $(date) ===" >> "$LOG_FILE"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  🔄 Ollama Models Auto-Updater"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_ollama

    # Liste modèles installés
    local models=$(get_installed_models | wc -l)
    log_info "$models modèle(s) installé(s)"

    # Mise à jour
    update_all_models

    # Nettoyage
    cleanup_old_models

    # Espace disque
    show_space

    # Setup cron si demandé
    if [[ "$CRON_MODE" == false ]]; then
        echo ""
        read -p "Activer mises à jour automatiques hebdomadaires ? (y/N) " setup_auto
        if [[ "$setup_auto" =~ ^[Yy]$ ]]; then
            setup_cron
        fi
    fi

    echo ""
    log_success "Mise à jour terminée !"
}

main "$@"
