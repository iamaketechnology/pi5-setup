#!/usr/bin/env bash
#
# Script de Migration pi5-setup v4.x → v5.0
# Migre l'ancienne structure (pi5-*-stack/) vers nouvelle structure par catégories
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/migrate-to-v5.sh | bash
#   ou
#   ./migrate-to-v5.sh

set -euo pipefail

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions helper
log_info() {
    echo -e "${BLUE}ℹ️  ${1}${NC}"
}

log_success() {
    echo -e "${GREEN}✅ ${1}${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  ${1}${NC}"
}

log_error() {
    echo -e "${RED}❌ ${1}${NC}"
}

# Vérifier si ancien format existe
check_old_structure() {
    local old_dirs=(
        "$HOME/pi5-setup/pi5-supabase-stack"
        "$HOME/pi5-setup/pi5-traefik-stack"
        "$HOME/pi5-setup/pi5-homepage-stack"
    )

    for dir in "${old_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            return 0  # Ancienne structure détectée
        fi
    done

    return 1  # Nouvelle structure déjà en place
}

# Fonction principale
main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  🔄 Migration pi5-setup v4.x → v5.0                       ║"
    echo "║  Réorganisation par catégories                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Vérifier si migration nécessaire
    if ! check_old_structure; then
        log_success "Aucune migration nécessaire - vous utilisez déjà la v5.0 !"
        exit 0
    fi

    log_info "Ancienne structure détectée - migration requise"
    echo ""

    # Confirmation utilisateur
    log_warn "Cette migration va :"
    echo "  1. Mettre à jour le repo pi5-setup vers v5.0"
    echo "  2. Créer des symlinks de compatibilité (aucune interruption service)"
    echo "  3. Mettre à jour Homepage si installé"
    echo ""
    echo "❓ Vos données et services NE SERONT PAS affectés."
    echo ""
    read -p "Continuer la migration ? (y/N) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Migration annulée"
        exit 0
    fi

    echo ""
    log_info "Démarrage migration..."

    # Étape 1 : Backup de sécurité
    log_info "Étape 1/5 : Création backup de sécurité..."
    BACKUP_DIR="$HOME/pi5-setup-backup-$(date +%Y%m%d-%H%M%S)"

    if [[ -d "$HOME/pi5-setup/.git" ]]; then
        log_info "Backup Git config..."
        cp -r "$HOME/pi5-setup/.git" "$BACKUP_DIR.git"
        log_success "Backup créé : $BACKUP_DIR.git"
    fi

    # Étape 2 : Pull dernière version
    log_info "Étape 2/5 : Mise à jour vers v5.0..."
    cd "$HOME/pi5-setup" || exit 1

    # Sauvegarder changements locaux si présents
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        log_warn "Changements locaux détectés - création stash..."
        git stash push -m "Pre-migration stash $(date +%Y%m%d-%H%M%S)"
    fi

    git fetch origin
    git pull origin main
    log_success "Repo mis à jour vers v5.0"

    # Étape 3 : Créer symlinks de compatibilité
    log_info "Étape 3/5 : Création symlinks de compatibilité..."

    declare -A SYMLINKS=(
        ["pi5-supabase-stack"]="01-infrastructure/supabase"
        ["pi5-traefik-stack"]="01-infrastructure/traefik"
        ["pi5-vpn-stack"]="01-infrastructure/vpn-wireguard"
        ["pi5-auth-stack"]="02-securite/authelia"
        ["pi5-monitoring-stack"]="03-monitoring/prometheus-grafana"
        ["pi5-gitea-stack"]="04-developpement/gitea"
        ["pi5-storage-stack"]="05-stockage/filebrowser-nextcloud"
        ["pi5-media-stack"]="06-media/jellyfin-arr"
        ["pi5-homeassistant-stack"]="07-domotique/homeassistant"
        ["pi5-homepage-stack"]="08-interface/homepage"
        ["pi5-backup-offsite-stack"]="09-backups/restic-offsite"
    )

    for old_name in "${!SYMLINKS[@]}"; do
        new_path="${SYMLINKS[$old_name]}"

        if [[ -d "$HOME/pi5-setup/$new_path" ]] && [[ ! -L "$HOME/pi5-setup/$old_name" ]]; then
            ln -sf "$new_path" "$HOME/pi5-setup/$old_name"
            log_success "Symlink créé : $old_name → $new_path"
        fi
    done

    # Étape 4 : Mettre à jour Homepage si installé
    log_info "Étape 4/5 : Vérification Homepage..."

    HOMEPAGE_CONFIG="$HOME/stacks/homepage/config/services.yaml"

    if [[ -f "$HOMEPAGE_CONFIG" ]]; then
        log_info "Homepage détecté - mise à jour automatique..."

        # Backup config
        cp "$HOMEPAGE_CONFIG" "${HOMEPAGE_CONFIG}.backup-$(date +%Y%m%d-%H%M%S)"

        # Note: Homepage utilise des URLs, pas des chemins fichiers, donc pas de mise à jour nécessaire
        log_success "Homepage vérifié - aucune modification requise (utilise URLs)"
    else
        log_info "Homepage non installé - skip"
    fi

    # Étape 5 : Vérification finale
    log_info "Étape 5/5 : Vérification finale..."

    # Tester que les symlinks fonctionnent
    for old_name in "${!SYMLINKS[@]}"; do
        if [[ -L "$HOME/pi5-setup/$old_name" ]]; then
            target=$(readlink "$HOME/pi5-setup/$old_name")
            if [[ -d "$HOME/pi5-setup/$target" ]]; then
                log_success "✓ $old_name → $target"
            else
                log_error "Symlink cassé : $old_name"
            fi
        fi
    done

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ✅ Migration v5.0 Terminée avec Succès !                ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    log_success "Nouvelle structure :"
    echo ""
    echo "  📁 01-infrastructure/     (Supabase, Traefik, VPN)"
    echo "  📁 02-securite/           (Authelia)"
    echo "  📁 03-monitoring/         (Prometheus, Grafana)"
    echo "  📁 04-developpement/      (Gitea)"
    echo "  📁 05-stockage/           (FileBrowser, Nextcloud)"
    echo "  📁 06-media/              (Jellyfin, *arr)"
    echo "  📁 07-domotique/          (Home Assistant)"
    echo "  📁 08-interface/          (Homepage)"
    echo "  📁 09-backups/            (Restic Offsite)"
    echo ""

    log_info "Compatibilité :"
    echo "  ✅ Symlinks créés - anciens chemins fonctionnent toujours"
    echo "  ✅ Services Docker non affectés"
    echo "  ✅ Données préservées"
    echo ""

    log_info "Nouveautés v5.0 :"
    echo "  📖 README.md dans chaque catégorie"
    echo "  🗂️ Organisation claire par fonction"
    echo "  📊 Documentation améliorée"
    echo ""

    log_warn "Prochaines étapes (optionnel) :"
    echo "  1. Lire les nouveaux README : ls ~/pi5-setup/*/README.md"
    echo "  2. Mettre à jour vos scripts personnels pour utiliser nouveaux chemins"
    echo "  3. Dans 30 jours, les symlinks pourront être supprimés"
    echo ""

    log_success "Migration terminée ! 🎉"
    echo ""
}

# Exécution
main "$@"
