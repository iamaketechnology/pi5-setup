#!/usr/bin/env bash
#
# Immich Deployment Script - Official Wrapper
# Utilise le script officiel Immich + intégration Pi5-setup
#
# Source officielle : https://github.com/immich-app/immich
# Script install.sh : https://raw.githubusercontent.com/immich-app/immich/main/install.sh
#
# Ce script :
# 1. Utilise le script officiel Immich (ARM64 testé upstream)
# 2. Ajoute l'intégration Traefik (HTTPS)
# 3. Ajoute à Homepage
# 4. Configure les backups
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COMMON_SCRIPTS_DIR="${PROJECT_ROOT}/common-scripts"

if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
    source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
    echo "❌ Erreur : ${COMMON_SCRIPTS_DIR}/lib.sh introuvable"
    exit 1
fi

STACK_NAME="immich"
IMMICH_INSTALL_DIR="${HOME}/immich-app"
TRAEFIK_ENV="${HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

detect_traefik_scenario() {
    [[ ! -f "${TRAEFIK_ENV}" ]] && return

    if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="duckdns"
        export DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="cloudflare"
        export DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "VPN_MODE" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="vpn"
    fi
}

run_official_installer() {
    log_info "Téléchargement script officiel Immich..."

    cd "${HOME}" || exit 1

    # Utiliser le script officiel Immich (ARM64 compatible)
    if command -v curl &> /dev/null; then
        curl -o- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash
    elif command -v wget &> /dev/null; then
        wget -qO- https://raw.githubusercontent.com/immich-app/immich/main/install.sh | bash
    else
        log_error "curl ou wget requis"
        exit 1
    fi

    log_success "Installation officielle terminée"
}

integrate_traefik() {
    [[ "${TRAEFIK_SCENARIO}" == "none" ]] && return

    log_info "Intégration Traefik (scénario: ${TRAEFIK_SCENARIO})..."

    local compose_file="${IMMICH_INSTALL_DIR}/docker-compose.yml"
    [[ ! -f "${compose_file}" ]] && {
        log_warn "docker-compose.yml introuvable, skip Traefik"
        return
    }

    # Backup
    cp "${compose_file}" "${compose_file}.bak"

    # Ajouter réseau Traefik
    if ! grep -q "traefik-network" "${compose_file}"; then
        cat >> "${compose_file}" <<'EOF'

networks:
  default:
    name: immich-network
  traefik-network:
    external: true
EOF
    fi

    # Ajouter labels Traefik au service immich-server
    if ! grep -q "traefik.enable" "${compose_file}"; then
        # Détecter la ligne du service immich-server
        local server_line
        server_line=$(grep -n "^  immich-server:" "${compose_file}" | cut -d: -f1)

        if [[ -n "${server_line}" ]]; then
            # Ajouter networks et labels après le service
            sed -i '' "${server_line}a\\
    networks:\\
      - default\\
      - traefik-network\\
    labels:\\
      - \"traefik.enable=true\"\\
      - \"traefik.http.services.immich.loadbalancer.server.port=3001\"
" "${compose_file}"

            case "${TRAEFIK_SCENARIO}" in
                duckdns)
                    sed -i '' '/traefik.http.services.immich/a\
      - "traefik.http.routers.immich.rule=Host(\`photos.'"${DUCKDNS_SUBDOMAIN}"'.duckdns.org\`)"\\
      - "traefik.http.routers.immich.entrypoints=websecure"\\
      - "traefik.http.routers.immich.tls.certresolver=letsencrypt"
' "${compose_file}"
                    log_success "URL HTTPS: https://photos.${DUCKDNS_SUBDOMAIN}.duckdns.org"
                    ;;
                cloudflare)
                    sed -i '' '/traefik.http.services.immich/a\
      - "traefik.http.routers.immich.rule=Host(\`photos.'"${DOMAIN}"'\`)"\\
      - "traefik.http.routers.immich.entrypoints=websecure"\\
      - "traefik.http.routers.immich.tls.certresolver=letsencrypt"
' "${compose_file}"
                    log_success "URL HTTPS: https://photos.${DOMAIN}"
                    ;;
                vpn)
                    log_info "Mode VPN: Accès via http://raspberrypi.local:2283"
                    ;;
            esac
        fi
    fi

    # Restart Immich avec nouvelle config
    cd "${IMMICH_INSTALL_DIR}" || exit 1
    docker-compose up -d

    log_success "Intégration Traefik terminée"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Immich:" "${homepage_config}"; then
        log_info "Immich déjà dans Homepage"
        return
    fi

    log_info "Ajout à Homepage..."

    local immich_url="http://raspberrypi.local:2283"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            immich_url="https://photos.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            immich_url="https://photos.${DOMAIN}"
            ;;
    esac

    cat >> "${homepage_config}" <<EOF

- Productivité:
    - Immich:
        href: ${immich_url}
        description: Photos (Google Photos alternative)
        icon: immich.png
        widget:
          type: immich
          url: ${immich_url}
          key: {{HOMEPAGE_VAR_IMMICH_API_KEY}}
EOF

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Ajouté à Homepage"
}

configure_backups() {
    log_info "Configuration backups Immich..."

    local backup_script="${HOME}/bin/backup-immich.sh"
    mkdir -p "${HOME}/bin"

    cat > "${backup_script}" <<'BACKUP_SCRIPT'
#!/bin/bash
# Backup Immich - GFS rotation

set -euo pipefail

BACKUP_DIR="${HOME}/backups/immich"
IMMICH_DIR="${HOME}/immich-app"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "${BACKUP_DIR}"/{daily,weekly,monthly}

# Backup config + database
cd "${IMMICH_DIR}" || exit 1

# Stop containers temporairement
docker-compose stop

# Backup PostgreSQL
docker exec immich-postgres pg_dumpall -U postgres > "${BACKUP_DIR}/daily/immich_db_${TIMESTAMP}.sql"

# Backup docker-compose + env
tar -czf "${BACKUP_DIR}/daily/immich_config_${TIMESTAMP}.tar.gz" \
    docker-compose.yml .env

# Restart containers
docker-compose start

# GFS Rotation
find "${BACKUP_DIR}/daily" -name "*.sql" -mtime +7 -delete
find "${BACKUP_DIR}/daily" -name "*.tar.gz" -mtime +7 -delete

# Copy to weekly (dimanche)
if [[ $(date +%u) -eq 7 ]]; then
    cp "${BACKUP_DIR}/daily/immich_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/weekly/"
    cp "${BACKUP_DIR}/daily/immich_config_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/weekly/"
fi

# Copy to monthly (1er du mois)
if [[ $(date +%d) -eq 01 ]]; then
    cp "${BACKUP_DIR}/daily/immich_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/monthly/"
    cp "${BACKUP_DIR}/daily/immich_config_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/monthly/"
fi

echo "✅ Backup Immich terminé: ${TIMESTAMP}"
BACKUP_SCRIPT

    chmod +x "${backup_script}"

    # Ajouter cron (2h du matin)
    (crontab -l 2>/dev/null || true; echo "0 2 * * * ${backup_script}") | crontab -

    log_success "Backups configurés (daily 2h)"
}

main() {
    print_header "Immich - Installation Officielle + Intégration"

    log_info "Ce script utilise le script officiel Immich (ARM64 testé)"
    log_info "puis ajoute l'intégration Traefik + Homepage + Backups"
    echo ""

    # Check RAM
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 4 ]]; then
        log_error "Immich nécessite minimum 4GB RAM"
        log_warn "Votre système : ${total_ram}GB"
        exit 1
    fi

    # Détection Traefik
    detect_traefik_scenario
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        log_info "Traefik détecté: ${TRAEFIK_SCENARIO}"
    fi

    echo ""
    log_warn "L'installation peut prendre 5-10 minutes (téléchargement images ARM64)"
    read -p "Continuer? (y/n): " -n 1 -r
    echo ""
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

    # 1. Installation officielle
    print_section "Étape 1/4: Installation Officielle"
    run_official_installer

    # 2. Intégration Traefik
    print_section "Étape 2/4: Intégration Traefik"
    integrate_traefik

    # 3. Ajout Homepage
    print_section "Étape 3/4: Ajout Homepage"
    update_homepage

    # 4. Configuration backups
    print_section "Étape 4/4: Configuration Backups"
    configure_backups

    echo ""
    print_section "✅ Installation Immich Terminée !"
    echo ""
    echo "📸 Accès :"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            echo "  URL : https://photos.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            echo "  URL : https://photos.${DOMAIN}"
            ;;
        *)
            echo "  URL : http://raspberrypi.local:2283"
            ;;
    esac

    echo ""
    echo "📱 Apps Mobiles :"
    echo "  - iOS : https://apps.apple.com/app/immich/id1613945652"
    echo "  - Android : https://play.google.com/store/apps/details?id=app.alextran.immich"
    echo ""
    echo "💾 Backups :"
    echo "  - Automatiques : Daily 2h (GFS rotation)"
    echo "  - Emplacement : ~/backups/immich/"
    echo "  - Manuel : ~/bin/backup-immich.sh"
    echo ""
    echo "📂 Installation :"
    echo "  - Dossier : ${IMMICH_INSTALL_DIR}"
    echo "  - Config : ${IMMICH_INSTALL_DIR}/docker-compose.yml"
    echo ""
    echo "🔧 Commandes :"
    echo "  cd ${IMMICH_INSTALL_DIR}"
    echo "  docker-compose logs -f    # Logs"
    echo "  docker-compose restart    # Redémarrer"
    echo "  docker-compose down       # Arrêter"
    echo ""

    log_success "Installation terminée ! 🎉"
}

main "$@"
