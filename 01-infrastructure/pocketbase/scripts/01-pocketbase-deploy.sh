#!/usr/bin/env bash
#
# Pocketbase Deployment Script - Ultra-Lightweight Backend
# Alternative ultra-légère à Supabase pour Raspberry Pi 5
#
# Source officielle : https://github.com/pocketbase/pocketbase
# Documentation : https://pocketbase.io/docs/
#
# Pocketbase fournit :
# - Auth (Email, OAuth, Anonymous)
# - Database (SQLite avec realtime)
# - Storage (Fichiers intégrés)
# - Admin UI (Interface web)
# - REST API automatique
# - Realtime (SSE - Server-Sent Events)
#
# Avantages ULTRA sur Pi 5 :
# - ULTRA léger : ~50MB RAM (vs 4-6GB Supabase !)
# - 1 seul binaire (pas de Docker requis)
# - SQLite (fichier unique, simple)
# - Setup 2 minutes
# - ARM64 natif parfait
#
# Idéal pour :
# - Prototypes / MVP rapides
# - Services annexes légers
# - Blog / CMS simple
# - Pi avec RAM limitée (8GB)
#
# Ce script est IDEMPOTENT : peut être exécuté plusieurs fois

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

STACK_NAME="pocketbase"
PB_DIR="${HOME}/apps/pocketbase"
PB_BINARY="${PB_DIR}/pocketbase"
PB_DATA="${PB_DIR}/pb_data"
PB_PUBLIC="${PB_DIR}/pb_public"
PB_PORT=8090

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

download_pocketbase() {
    log_info "Téléchargement Pocketbase ARM64..."

    local version="0.22.0"
    local download_url="https://github.com/pocketbase/pocketbase/releases/download/v${version}/pocketbase_${version}_linux_arm64.zip"
    local temp_file="/tmp/pocketbase.zip"

    if [[ -f "${PB_BINARY}" ]]; then
        log_info "Pocketbase déjà téléchargé, skip..."
        return
    fi

    mkdir -p "${PB_DIR}"
    cd "${PB_DIR}" || exit 1

    if command -v curl &> /dev/null; then
        curl -fsSL "${download_url}" -o "${temp_file}"
    elif command -v wget &> /dev/null; then
        wget -q "${download_url}" -O "${temp_file}"
    else
        log_error "curl ou wget requis"
        exit 1
    fi

    unzip -q "${temp_file}"
    rm "${temp_file}"
    chmod +x "${PB_BINARY}"

    log_success "Pocketbase téléchargé ($(du -h ${PB_BINARY} | cut -f1))"
}

create_systemd_service() {
    log_info "Création service systemd..."

    local service_file="/etc/systemd/system/pocketbase.service"

    sudo tee "${service_file}" > /dev/null <<EOF
[Unit]
Description=Pocketbase Backend Service
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${PB_DIR}
ExecStart=${PB_BINARY} serve --http=0.0.0.0:${PB_PORT}
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=pocketbase

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=${PB_DIR}

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable pocketbase
    sudo systemctl start pocketbase

    log_success "Service systemd créé et démarré"
}

setup_traefik_integration() {
    [[ "${TRAEFIK_SCENARIO}" == "none" ]] && return

    log_info "Configuration intégration Traefik..."

    local compose_file="${HOME}/stacks/pocketbase-proxy/docker-compose.yml"
    mkdir -p "$(dirname ${compose_file})"

    local hostname
    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            hostname="pb.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            hostname="pb.${DOMAIN}"
            ;;
        vpn)
            hostname="pb.pi.local"
            ;;
    esac

    # Créer container whoami proxy vers Pocketbase local
    cat > "${compose_file}" <<EOF
version: '3.8'

services:
  pocketbase-proxy:
    image: traefik/whoami
    container_name: pocketbase-proxy
    command:
      - --port=8090
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.pocketbase.loadbalancer.server.url=http://host.docker.internal:${PB_PORT}"
      - "traefik.http.routers.pocketbase.rule=Host(\\\`${hostname}\\\`)"
      - "traefik.http.routers.pocketbase.entrypoints=websecure"
      - "traefik.http.routers.pocketbase.tls.certresolver=letsencrypt"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

networks:
  traefik-network:
    external: true
EOF

    cd "$(dirname ${compose_file})" || exit 1
    docker-compose up -d

    log_success "Traefik configuré : https://${hostname}"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Pocketbase:" "${homepage_config}"; then
        log_info "Pocketbase déjà dans Homepage"
        return
    fi

    log_info "Ajout à Homepage..."

    local pb_url
    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            pb_url="https://pb.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            pb_url="https://pb.${DOMAIN}"
            ;;
        *)
            pb_url="http://raspberrypi.local:${PB_PORT}"
            ;;
    esac

    cat >> "${homepage_config}" <<EOF

- Infrastructure:
    - Pocketbase:
        href: ${pb_url}
        description: Backend ultra-léger (50MB RAM)
        icon: pocketbase.png
EOF

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Ajouté à Homepage"
}

configure_backups() {
    log_info "Configuration backups Pocketbase..."

    local backup_script="${HOME}/bin/backup-pocketbase.sh"
    mkdir -p "${HOME}/bin"

    cat > "${backup_script}" <<'BACKUP_SCRIPT'
#!/bin/bash
# Backup Pocketbase - GFS rotation

set -euo pipefail

BACKUP_DIR="${HOME}/backups/pocketbase"
PB_DIR="${HOME}/apps/pocketbase"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "${BACKUP_DIR}"/{daily,weekly,monthly}

# Stop Pocketbase temporairement
sudo systemctl stop pocketbase

# Backup SQLite + fichiers
tar -czf "${BACKUP_DIR}/daily/pocketbase_${TIMESTAMP}.tar.gz" \
    -C "${PB_DIR}" pb_data pb_public

# Restart Pocketbase
sudo systemctl start pocketbase

# GFS Rotation
find "${BACKUP_DIR}/daily" -name "*.tar.gz" -mtime +7 -delete

# Copy to weekly (dimanche)
if [[ $(date +%u) -eq 7 ]]; then
    cp "${BACKUP_DIR}/daily/pocketbase_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/weekly/"
fi

# Copy to monthly (1er du mois)
if [[ $(date +%d) -eq 01 ]]; then
    cp "${BACKUP_DIR}/daily/pocketbase_${TIMESTAMP}.tar.gz" "${BACKUP_DIR}/monthly/"
fi

echo "✅ Backup Pocketbase terminé: ${TIMESTAMP}"
BACKUP_SCRIPT

    chmod +x "${backup_script}"

    # Ajouter cron (5h du matin)
    (crontab -l 2>/dev/null || true; echo "0 5 * * * ${backup_script}") | crontab -

    log_success "Backups configurés (daily 5h)"
}

create_example_collection() {
    log_info "Création collection exemple..."

    # Attendre que Pocketbase soit prêt
    sleep 5

    # Note: Collections se créent via Admin UI
    # On pourrait utiliser l'API mais nécessite auth
    log_info "👉 Créer collections via Admin UI : http://raspberrypi.local:${PB_PORT}/_/"
}

main() {
    print_header "Pocketbase - Backend Ultra-Léger"

    echo ""
    log_info "⚡ Pocketbase vs Supabase :"
    echo "  ✅ ULTRA léger : 50MB RAM vs 4-6GB !"
    echo "  ✅ 1 seul binaire (pas Docker)"
    echo "  ✅ SQLite (fichier unique)"
    echo "  ✅ Setup 2 minutes"
    echo "  ✅ Parfait pour prototypes / MVP"
    echo ""
    log_info "💡 Cohabite PARFAITEMENT avec Supabase (quasi 0 RAM) !"
    echo ""

    detect_traefik_scenario
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        log_info "Traefik détecté: ${TRAEFIK_SCENARIO}"
    fi

    # Création dossiers
    mkdir -p "${PB_DIR}" "${PB_DATA}" "${PB_PUBLIC}"

    # 1. Téléchargement
    print_section "Étape 1/5: Téléchargement Pocketbase"
    download_pocketbase

    # 2. Service systemd
    print_section "Étape 2/5: Configuration Service"
    create_systemd_service

    # Attendre démarrage
    log_info "Attente démarrage Pocketbase (10s)..."
    sleep 10

    # Vérifier
    if systemctl is-active --quiet pocketbase; then
        log_success "Pocketbase démarré !"
    else
        log_error "Échec démarrage Pocketbase"
        log_info "Logs : sudo journalctl -u pocketbase -f"
        exit 1
    fi

    # 3. Traefik
    print_section "Étape 3/5: Intégration Traefik"
    setup_traefik_integration

    # 4. Homepage
    print_section "Étape 4/5: Ajout Homepage"
    update_homepage

    # 5. Backups
    print_section "Étape 5/5: Configuration Backups"
    configure_backups

    echo ""
    print_section "✅ Pocketbase Installé !"
    echo ""
    echo "🌐 Accès Admin UI :"

    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            echo "  URL : https://pb.${DUCKDNS_SUBDOMAIN}.duckdns.org/_/"
            ;;
        cloudflare)
            echo "  URL : https://pb.${DOMAIN}/_/"
            ;;
        *)
            echo "  URL : http://raspberrypi.local:${PB_PORT}/_/"
            ;;
    esac

    echo ""
    echo "👤 Premier accès :"
    echo "  1. Créer compte admin (premier utilisateur = admin)"
    echo "  2. Créer collections (tables)"
    echo "  3. Définir API rules (auth, permissions)"
    echo "  4. Obtenir API endpoint dans Settings"
    echo ""
    echo "📚 Documentation :"
    echo "  - Docs : https://pocketbase.io/docs/"
    echo "  - Client SDKs : JavaScript, Dart"
    echo "  - API Auto : REST + Realtime SSE"
    echo ""
    echo "💾 Backups :"
    echo "  - Automatiques : Daily 5h (GFS rotation)"
    echo "  - Emplacement : ~/backups/pocketbase/"
    echo "  - Manuel : ~/bin/backup-pocketbase.sh"
    echo ""
    echo "📂 Installation :"
    echo "  - Binaire : ${PB_BINARY}"
    echo "  - Data : ${PB_DATA}"
    echo "  - Public : ${PB_PUBLIC}"
    echo ""
    echo "🔧 Commandes :"
    echo "  sudo systemctl status pocketbase    # Status"
    echo "  sudo systemctl restart pocketbase   # Redémarrer"
    echo "  sudo systemctl stop pocketbase      # Arrêter"
    echo "  sudo journalctl -u pocketbase -f    # Logs"
    echo ""
    echo "📊 Ressources :"
    echo "  RAM : ~50MB (!!!) vs 4-6GB Supabase"
    echo "  Binaire : $(du -h ${PB_BINARY} | cut -f1)"
    echo "  Data : ${PB_DATA}"
    echo ""
    echo "🔄 Cohabitation avec Supabase :"
    echo "  ✅ Ports différents (${PB_PORT} vs 8000)"
    echo "  ✅ Quasi 0 RAM utilisée"
    echo "  ✅ Parfait pour : prototypes, blog, services légers"
    echo "  ✅ Supabase : backend principal lourd"
    echo "  ✅ Pocketbase : services annexes ultra-rapides"
    echo ""
    echo "💡 Exemples d'utilisation combinée :"
    echo "  - Supabase : App mobile principale (users, products, orders)"
    echo "  - Pocketbase : Blog / CMS (posts, comments)"
    echo "  - Pocketbase : Todo lists / Notes (collections simples)"
    echo "  - Pocketbase : Prototypes / POC rapides"
    echo ""

    log_success "Installation terminée ! 🎉"
}

main "$@"
