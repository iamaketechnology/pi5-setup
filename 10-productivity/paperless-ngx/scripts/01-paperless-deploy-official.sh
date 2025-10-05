#!/usr/bin/env bash
#
# Paperless-ngx Deployment Script - Official Wrapper
# Utilise le script officiel Paperless-ngx + intégration Pi5-setup
#
# Source officielle : https://github.com/paperless-ngx/paperless-ngx
# Script install : https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/install-paperless-ngx.sh
#
# Ce script :
# 1. Utilise le script officiel Paperless-ngx (ARM64 testé upstream)
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

STACK_NAME="paperless-ngx"
PAPERLESS_INSTALL_DIR="${HOME}/paperless-ngx"
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
    log_info "Téléchargement script officiel Paperless-ngx..."

    cd "${HOME}" || exit 1

    # Utiliser le script officiel Paperless-ngx (ARM64 compatible)
    if command -v bash &> /dev/null; then
        bash -c "$(curl -L https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/install-paperless-ngx.sh)"
    else
        log_error "bash requis"
        exit 1
    fi

    log_success "Installation officielle terminée"
}

integrate_traefik() {
    [[ "${TRAEFIK_SCENARIO}" == "none" ]] && return

    log_info "Intégration Traefik (scénario: ${TRAEFIK_SCENARIO})..."

    local compose_file="${PAPERLESS_INSTALL_DIR}/docker-compose.yml"
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
    name: paperless-network
  traefik-network:
    external: true
EOF
    fi

    # Ajouter labels Traefik au service webserver
    if ! grep -q "traefik.enable" "${compose_file}"; then
        local server_line
        server_line=$(grep -n "^  webserver:" "${compose_file}" | cut -d: -f1)

        if [[ -n "${server_line}" ]]; then
            sed -i '' "${server_line}a\\
    networks:\\
      - default\\
      - traefik-network\\
    labels:\\
      - \"traefik.enable=true\"\\
      - \"traefik.http.services.paperless.loadbalancer.server.port=8000\"
" "${compose_file}"

            case "${TRAEFIK_SCENARIO}" in
                duckdns)
                    sed -i '' '/traefik.http.services.paperless/a\
      - "traefik.http.routers.paperless.rule=Host(\`docs.'"${DUCKDNS_SUBDOMAIN}"'.duckdns.org\`)"\\
      - "traefik.http.routers.paperless.entrypoints=websecure"\\
      - "traefik.http.routers.paperless.tls.certresolver=letsencrypt"
' "${compose_file}"
                    log_success "URL HTTPS: https://docs.${DUCKDNS_SUBDOMAIN}.duckdns.org"
                    ;;
                cloudflare)
                    sed -i '' '/traefik.http.services.paperless/a\
      - "traefik.http.routers.paperless.rule=Host(\`docs.'"${DOMAIN}"'\`)"\\
      - "traefik.http.routers.paperless.entrypoints=websecure"\\
      - "traefik.http.routers.paperless.tls.certresolver=letsencrypt"
' "${compose_file}"
                    log_success "URL HTTPS: https://docs.${DOMAIN}"
                    ;;
                vpn)
                    log_info "Mode VPN: Accès via http://raspberrypi.local:8000"
                    ;;
            esac
        fi
    fi

    # Restart Paperless avec nouvelle config
    cd "${PAPERLESS_INSTALL_DIR}" || exit 1
    docker-compose up -d

    log_success "Intégration Traefik terminée"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Paperless-ngx:" "${homepage_config}"; then
        log_info "Paperless-ngx déjà dans Homepage"
        return
    fi

    log_info "Ajout à Homepage..."

    local paperless_url="http://raspberrypi.local:8000"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            paperless_url="https://docs.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            paperless_url="https://docs.${DOMAIN}"
            ;;
    esac

    cat >> "${homepage_config}" <<EOF

- Productivité:
    - Paperless-ngx:
        href: ${paperless_url}
        description: Gestion documents + OCR
        icon: paperless.png
        widget:
          type: paperlessngx
          url: ${paperless_url}
          username: {{HOMEPAGE_VAR_PAPERLESS_USER}}
          password: {{HOMEPAGE_VAR_PAPERLESS_PASS}}
EOF

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Ajouté à Homepage"
}

configure_backups() {
    log_info "Configuration backups Paperless-ngx..."

    local backup_script="${HOME}/bin/backup-paperless.sh"
    mkdir -p "${HOME}/bin"

    cat > "${backup_script}" <<'BACKUP_SCRIPT'
#!/bin/bash
# Backup Paperless-ngx - GFS rotation

set -euo pipefail

BACKUP_DIR="${HOME}/backups/paperless"
PAPERLESS_DIR="${HOME}/paperless-ngx"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "${BACKUP_DIR}"/{daily,weekly,monthly}

# Backup via Paperless export command
cd "${PAPERLESS_DIR}" || exit 1

# Document exporter (intégré Paperless-ngx)
docker-compose exec -T webserver document_exporter ../export/backup_${TIMESTAMP}

# Backup database
docker-compose exec -T db pg_dump -U paperless paperless > "${BACKUP_DIR}/daily/paperless_db_${TIMESTAMP}.sql"

# Backup docker-compose + env
tar -czf "${BACKUP_DIR}/daily/paperless_config_${TIMESTAMP}.tar.gz" \
    docker-compose.yml docker-compose.env

# GFS Rotation
find "${BACKUP_DIR}/daily" -name "*.sql" -mtime +7 -delete
find "${BACKUP_DIR}/daily" -name "*.tar.gz" -mtime +7 -delete

# Copy to weekly (dimanche)
if [[ $(date +%u) -eq 7 ]]; then
    cp "${BACKUP_DIR}/daily/paperless_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/weekly/"
    cp "${BACKUP_DIR}/daily/paperless_config_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/weekly/"
fi

# Copy to monthly (1er du mois)
if [[ $(date +%d) -eq 01 ]]; then
    cp "${BACKUP_DIR}/daily/paperless_db_${TIMESTAMP}.sql" "${BACKUP_DIR}/monthly/"
    cp "${BACKUP_DIR}/daily/paperless_config_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/monthly/"
fi

echo "✅ Backup Paperless-ngx terminé: ${TIMESTAMP}"
BACKUP_SCRIPT

    chmod +x "${backup_script}"

    # Ajouter cron (3h du matin)
    (crontab -l 2>/dev/null || true; echo "0 3 * * * ${backup_script}") | crontab -

    log_success "Backups configurés (daily 3h)"
}

get_credentials() {
    local env_file="${PAPERLESS_INSTALL_DIR}/docker-compose.env"
    [[ ! -f "${env_file}" ]] && return

    local admin_user
    local admin_pass

    admin_user=$(grep "PAPERLESS_ADMIN_USER=" "${env_file}" 2>/dev/null | cut -d'=' -f2 || echo "admin")
    admin_pass=$(grep "PAPERLESS_ADMIN_PASSWORD=" "${env_file}" 2>/dev/null | cut -d'=' -f2 || echo "[voir ${env_file}]")

    echo "${admin_user}:${admin_pass}"
}

main() {
    print_header "Paperless-ngx - Installation Officielle + Intégration"

    log_info "Ce script utilise le script officiel Paperless-ngx (ARM64 testé)"
    log_info "puis ajoute l'intégration Traefik + Homepage + Backups"
    echo ""

    # Check RAM
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 2 ]]; then
        log_error "Paperless-ngx nécessite minimum 2GB RAM"
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
    log_warn "Note: OCR sur ARM64 est plus lent que x86_64 (performances acceptables)"
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

    # Get credentials
    local creds
    creds=$(get_credentials)
    local admin_user="${creds%%:*}"
    local admin_pass="${creds##*:}"

    echo ""
    print_section "✅ Installation Paperless-ngx Terminée !"
    echo ""
    echo "📄 Accès :"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            echo "  URL : https://docs.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            echo "  URL : https://docs.${DOMAIN}"
            ;;
        *)
            echo "  URL : http://raspberrypi.local:8000"
            ;;
    esac

    echo ""
    echo "👤 Credentials :"
    echo "  Username : ${admin_user}"
    echo "  Password : ${admin_pass}"
    echo ""
    echo "📂 Dossiers :"
    echo "  - Consommation : ${PAPERLESS_INSTALL_DIR}/consume/"
    echo "  - Médias : ${PAPERLESS_INSTALL_DIR}/media/"
    echo "  - Export : ${PAPERLESS_INSTALL_DIR}/export/"
    echo ""
    echo "💡 Utilisation :"
    echo "  1. Déposer PDF/images dans consume/"
    echo "  2. Paperless détecte automatiquement"
    echo "  3. OCR + extraction métadonnées"
    echo "  4. Archivage avec tags/correspondants"
    echo ""
    echo "💾 Backups :"
    echo "  - Automatiques : Daily 3h (GFS rotation)"
    echo "  - Emplacement : ~/backups/paperless/"
    echo "  - Manuel : ~/bin/backup-paperless.sh"
    echo ""
    echo "📂 Installation :"
    echo "  - Dossier : ${PAPERLESS_INSTALL_DIR}"
    echo "  - Config : ${PAPERLESS_INSTALL_DIR}/docker-compose.yml"
    echo ""
    echo "🔧 Commandes :"
    echo "  cd ${PAPERLESS_INSTALL_DIR}"
    echo "  docker-compose logs -f webserver  # Logs"
    echo "  docker-compose restart            # Redémarrer"
    echo "  docker-compose down               # Arrêter"
    echo ""
    echo "⚠️  Performance OCR :"
    echo "  ARM64 : ~20-30s par page (acceptable)"
    echo "  x86_64 : ~5-10s par page (référence)"
    echo ""

    log_success "Installation terminée ! 🎉"
}

main "$@"
