#!/bin/bash
# =============================================================================
# Ollama Models Downloader - Raspberry Pi 5 Optimized
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 02-download-models.sh
# =============================================================================
# Télécharge modèles LLM optimisés pour Pi5 16GB par catégorie d'usage
# Basé sur benchmarks 2025 (tokens/sec, RAM, qualité)
# =============================================================================

set -euo pipefail

# === Logging functions ===
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }

# === Check Ollama running ===
if ! docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
    log_error "Ollama n'est pas démarré"
    log_info "Démarrez-le avec : cd ~/stacks/ollama && docker compose up -d"
    exit 1
fi

log_success "Ollama détecté"

# === Modèles disponibles (optimisés Pi5 16GB) ===
declare -A MODELS

# Catégorie: Usage Général (rapides, polyvalents)
MODELS[1_name]="gemma2:2b"
MODELS[1_cat]="⚡ Ultra-Rapide"
MODELS[1_desc]="Google Gemma 2B - Excellent rapport vitesse/qualité (8-10 tok/s)"
MODELS[1_ram]="~2 GB"
MODELS[1_size]="1.6 GB"

MODELS[2_name]="phi3:3.8b"
MODELS[2_cat]="🎯 Équilibré"
MODELS[2_desc]="Microsoft Phi3 - Meilleur équilibre perf/qualité (3-5 tok/s)"
MODELS[2_ram]="~3 GB"
MODELS[2_size]="2.3 GB"

MODELS[3_name]="llama3.2:3b"
MODELS[3_cat]="🎯 Équilibré"
MODELS[3_desc]="Meta Llama 3.2 - Excellent pour conversations (3-4 tok/s)"
MODELS[3_ram]="~3 GB"
MODELS[3_size]="2.0 GB"

# Catégorie: Code & DevOps
MODELS[4_name]="qwen2.5-coder:1.5b"
MODELS[4_cat]="💻 Code"
MODELS[4_desc]="Alibaba Qwen Coder - Spécialisé code (rapide, 6-8 tok/s)"
MODELS[4_ram]="~2 GB"
MODELS[4_size]="984 MB"

MODELS[5_name]="qwen2.5-coder:3b"
MODELS[5_cat]="💻 Code"
MODELS[5_desc]="Qwen Coder 3B - Code + raisonnement (4-5 tok/s)"
MODELS[5_ram]="~3 GB"
MODELS[5_size]="1.9 GB"

MODELS[6_name]="deepseek-coder:1.3b"
MODELS[6_cat]="💻 Code"
MODELS[6_desc]="DeepSeek Coder - Ultra-rapide pour snippets (7-9 tok/s)"
MODELS[6_ram]="~1.5 GB"
MODELS[6_size]="776 MB"

# Catégorie: Multilingue & Maths
MODELS[7_name]="qwen2.5:3b"
MODELS[7_cat]="🌍 Multilingue"
MODELS[7_desc]="Qwen 2.5 - 29 langues, excellent maths (4-5 tok/s)"
MODELS[7_ram]="~3 GB"
MODELS[7_size]="1.9 GB"

MODELS[8_name]="qwen2.5:7b"
MODELS[8_cat]="🌍 Multilingue"
MODELS[8_desc]="Qwen 2.5 7B - Raisonnement avancé (2-3 tok/s)"
MODELS[8_ram]="~6 GB"
MODELS[8_size]="4.7 GB"

# Catégorie: Haute Qualité (lent mais précis)
MODELS[9_name]="mistral:7b"
MODELS[9_cat]="🏆 Qualité"
MODELS[9_desc]="Mistral 7B - Excellent français, moins répétitif (1-2 tok/s)"
MODELS[9_ram]="~6 GB"
MODELS[9_size]="4.1 GB"

MODELS[10_name]="llama3:8b"
MODELS[10_cat]="🏆 Qualité"
MODELS[10_desc]="Meta Llama 3 8B - Qualité GPT-3.5 (1-2 tok/s)"
MODELS[10_ram]="~7 GB"
MODELS[10_size]="4.7 GB"

# Catégorie: Vision (multimodal)
MODELS[11_name]="llava:7b"
MODELS[11_cat]="👁️ Vision"
MODELS[11_desc]="LLaVA - Analyse d'images (lent, ~1 tok/s)"
MODELS[11_ram]="~8 GB"
MODELS[11_size]="4.7 GB"

# === Afficher menu ===
show_menu() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 Modèles LLM Optimisés Raspberry Pi 5 (16 GB)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Catégories disponibles :"
    echo ""
    echo "  [1-3]   ⚡ Usage Général (rapides, polyvalents)"
    echo "  [4-6]   💻 Code & DevOps"
    echo "  [7-8]   🌍 Multilingue & Maths"
    echo "  [9-10]  🏆 Haute Qualité (lent mais précis)"
    echo "  [11]    👁️ Vision (analyse d'images)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    for i in {1..11}; do
        local name="${MODELS[${i}_name]}"
        local cat="${MODELS[${i}_cat]}"
        local desc="${MODELS[${i}_desc]}"
        local ram="${MODELS[${i}_ram]}"
        local size="${MODELS[${i}_size]}"

        printf "  [%2d] %s\n" "$i" "$cat"
        printf "       📦 %-25s | RAM: %-7s | Size: %s\n" "$name" "$ram" "$size"
        printf "       %s\n\n" "$desc"
    done

    echo "  [12] 🎁 Pack Recommandé (gemma2:2b + phi3:3.8b + qwen2.5-coder:1.5b)"
    echo "  [13] 🚀 Pack Performance (gemma2:2b + llama3.2:3b + deepseek-coder:1.3b)"
    echo "  [14] 💪 Pack Complet (tous les modèles < 4GB)"
    echo ""
    echo "  [0]  ❌ Quitter"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# === Liste modèles déjà installés ===
list_installed() {
    echo ""
    log_info "Modèles déjà installés :"
    docker exec ollama ollama list 2>/dev/null || echo "Aucun"
}

# === Télécharger modèle ===
download_model() {
    local model=$1
    local name=$(echo "$model" | cut -d':' -f1)

    log_info "Vérification si $model existe déjà..."

    # Check si déjà installé (idempotent)
    if docker exec ollama ollama list 2>/dev/null | grep -q "^${model}"; then
        log_success "$model déjà installé (skip)"
        return 0
    fi

    log_info "Téléchargement $model..."
    log_warn "Ceci peut prendre 2-10 min selon la taille"
    echo ""

    if docker exec ollama ollama pull "$model"; then
        log_success "$model téléchargé !"
    else
        log_error "Échec téléchargement $model"
        return 1
    fi
}

# === Télécharger pack ===
download_pack() {
    local pack_name=$1
    shift
    local models=("$@")

    log_info "Téléchargement $pack_name..."
    echo ""

    for model in "${models[@]}"; do
        download_model "$model"
    done

    log_success "Pack $pack_name installé !"
}

# === Main ===
main() {
    list_installed

    while true; do
        show_menu

        read -p "Sélectionnez un modèle [0-14] : " choice

        case $choice in
            0)
                log_info "Au revoir !"
                exit 0
                ;;
            [1-9]|1[0-1])
                local model_name="${MODELS[${choice}_name]}"
                download_model "$model_name"
                list_installed
                ;;
            12)
                download_pack "Pack Recommandé" "gemma2:2b" "phi3:3.8b" "qwen2.5-coder:1.5b"
                list_installed
                ;;
            13)
                download_pack "Pack Performance" "gemma2:2b" "llama3.2:3b" "deepseek-coder:1.3b"
                list_installed
                ;;
            14)
                download_pack "Pack Complet" "gemma2:2b" "phi3:3.8b" "llama3.2:3b" \
                    "qwen2.5-coder:1.5b" "qwen2.5-coder:3b" "deepseek-coder:1.3b" "qwen2.5:3b"
                list_installed
                ;;
            *)
                log_error "Choix invalide"
                ;;
        esac

        echo ""
        read -p "Télécharger un autre modèle ? (y/N) " again
        [[ ! "$again" =~ ^[Yy]$ ]] && break
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ TÉLÉCHARGEMENT TERMINÉ"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "Accédez à Open WebUI : http://pi5.local:3002"
    log_info "Sélectionnez un modèle dans le menu déroulant"
}

main "$@"
