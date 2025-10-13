#!/usr/bin/env bash
set -euo pipefail

#############################################################################
# Migration Tunnel Gratuit → Tunnel avec Domaine Custom
#
# Description: Migre un tunnel Quick Tunnel (*.trycloudflare.com) vers un tunnel avec domaine personnalisé
# Version: 1.0.0
# Author: PI5-SETUP Project
# Idempotent: ✅ Oui
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Variables
LOG_FILE="/var/log/cloudflare-migrate-to-domain-$(date +%Y%m%d_%H%M%S).log"
APP_NAME=""
TUNNEL_DIR=""
CUSTOM_DOMAIN=""
TUNNEL_NAME=""
TUNNEL_ID=""
BACKUP_DIR=""

#############################################################################
# Fonctions utilitaires
#############################################################################

log() { echo -e "${CYAN}[INFO]${NC} $*" | tee -a "$LOG_FILE"; }
ok() { echo -e "${GREEN}[OK]${NC} $*" | tee -a "$LOG_FILE"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"; }
error() { echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2; }
title() { echo -e "${BOLD}${BLUE}$*${NC}"; }
section() { echo -e "\n${BOLD}${MAGENTA}═══ $* ═══${NC}\n"; }

error_exit() {
    error "$1"
    exit 1
}

banner() {
    clear
    echo -e "${BLUE}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     🔄 Migration vers Domaine Custom                                ║
║                                                                      ║
║     Tunnel Gratuit → Tunnel avec Domaine Personnalisé              ║
║     Version 1.0.0                                                   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
}

#############################################################################
# Vérifications
#############################################################################

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_cloudflared() {
    section "🔍 Vérification cloudflared"

    if ! command -v cloudflared &> /dev/null; then
        error_exit "cloudflared n'est pas installé. Installez-le d'abord."
    fi

    ok "cloudflared installé ($(cloudflared --version 2>&1 | head -1))"
    echo ""
}

#############################################################################
# Détection tunnel existant
#############################################################################

detect_existing_tunnel() {
    section "🔍 Détection du tunnel existant"

    log "Recherche des tunnels Quick Tunnel..."

    # Lister les dossiers de tunnels
    local tunnel_dirs=$(find /home/*/tunnels -maxdepth 1 -type d 2>/dev/null || echo "")

    if [[ -z "$tunnel_dirs" ]]; then
        error_exit "Aucun tunnel trouvé dans /home/*/tunnels/"
    fi

    # Afficher les tunnels trouvés
    echo -e "${BOLD}Tunnels trouvés :${NC}"
    echo ""

    local index=1
    declare -a tunnel_array

    while IFS= read -r dir; do
        if [[ -f "$dir/docker-compose.yml" ]]; then
            local app_name=$(basename "$dir")
            echo "  ${index}) ${app_name} (${dir})"
            tunnel_array[$index]="$dir"
            ((index++))
        fi
    done <<< "$tunnel_dirs"

    echo ""

    # Sélection
    if [[ ${#tunnel_array[@]} -eq 0 ]]; then
        error_exit "Aucun tunnel valide trouvé"
    elif [[ ${#tunnel_array[@]} -eq 1 ]]; then
        TUNNEL_DIR="${tunnel_array[1]}"
        APP_NAME=$(basename "$TUNNEL_DIR")
        ok "Tunnel détecté automatiquement : ${APP_NAME}"
    else
        read -p "Sélectionnez le tunnel à migrer [1-$((index-1))]: " selection

        if [[ -z "${tunnel_array[$selection]:-}" ]]; then
            error_exit "Sélection invalide"
        fi

        TUNNEL_DIR="${tunnel_array[$selection]}"
        APP_NAME=$(basename "$TUNNEL_DIR")
        ok "Tunnel sélectionné : ${APP_NAME}"
    fi

    echo ""

    # Extraire infos existantes
    log "Analyse de la configuration existante..."

    if [[ ! -f "${TUNNEL_DIR}/docker-compose.yml" ]]; then
        error_exit "Fichier docker-compose.yml non trouvé dans ${TUNNEL_DIR}"
    fi

    ok "Configuration trouvée"
    echo ""
}

#############################################################################
# Configuration domaine
#############################################################################

prompt_domain_info() {
    section "🌐 Configuration du Domaine"

    cat << 'EOF'
Pour migrer vers un tunnel avec domaine personnalisé, vous avez besoin de :

✅ Un domaine (ex: certidoc.fr, app.certidoc.fr, certidoc.com)
✅ Le domaine doit être configuré dans Cloudflare
✅ Accès au Cloudflare Dashboard

Si vous n'avez pas encore de domaine :
  • OVH : https://www.ovh.com/fr/domaines/
  • Namecheap : https://www.namecheap.com
  • Porkbun : https://porkbun.com

Après achat, ajoutez-le à Cloudflare :
  • https://dash.cloudflare.com
  • Cliquez sur "Add a Site"
  • Suivez les instructions

EOF

    read -p "Avez-vous déjà configuré votre domaine dans Cloudflare ? [y/N]: " has_domain

    if [[ ! $has_domain =~ ^[Yy]$ ]]; then
        error_exit "Configurez d'abord votre domaine dans Cloudflare, puis relancez ce script."
    fi

    echo ""

    # Demander le domaine
    while [[ -z "$CUSTOM_DOMAIN" ]]; do
        read -p "Entrez votre domaine complet (ex: certidoc.fr ou app.certidoc.fr): " CUSTOM_DOMAIN

        if [[ -z "$CUSTOM_DOMAIN" ]]; then
            warn "Le domaine ne peut pas être vide"
        elif [[ ! "$CUSTOM_DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            warn "Format de domaine invalide"
            CUSTOM_DOMAIN=""
        fi
    done

    ok "Domaine : ${CUSTOM_DOMAIN}"

    # Nom du tunnel
    TUNNEL_NAME="${APP_NAME}-prod"

    echo ""
    echo -e "${BOLD}Configuration de la migration :${NC}"
    echo "  • Application : ${APP_NAME}"
    echo "  • Tunnel actuel : Quick Tunnel (gratuit)"
    echo "  • Nouveau tunnel : ${TUNNEL_NAME}"
    echo "  • Domaine : ${CUSTOM_DOMAIN}"
    echo ""

    read -p "Confirmer la migration ? [Y/n]: " confirm
    confirm=${confirm:-Y}

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error_exit "Migration annulée"
    fi

    echo ""
}

#############################################################################
# Backup
#############################################################################

create_backup() {
    section "💾 Sauvegarde de la configuration actuelle"

    BACKUP_DIR="/home/${SUDO_USER:-pi}/tunnels/${APP_NAME}-backup-$(date +%Y%m%d_%H%M%S)"

    log "Création du backup dans ${BACKUP_DIR}..."

    cp -r "$TUNNEL_DIR" "$BACKUP_DIR"
    chown -R "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "$BACKUP_DIR"

    ok "Backup créé : ${BACKUP_DIR}"
    echo ""
}

#############################################################################
# Arrêt du tunnel actuel
#############################################################################

stop_current_tunnel() {
    section "🛑 Arrêt du tunnel actuel"

    cd "$TUNNEL_DIR"

    log "Arrêt du Quick Tunnel..."

    if docker compose down 2>&1 | tee -a "$LOG_FILE"; then
        ok "Tunnel arrêté"
    else
        warn "Le tunnel était peut-être déjà arrêté"
    fi

    echo ""
}

#############################################################################
# Authentification Cloudflare
#############################################################################

authenticate_cloudflare() {
    section "🔐 Authentification Cloudflare"

    # Vérifier si déjà authentifié
    if [[ -f "/root/.cloudflared/cert.pem" ]]; then
        ok "Déjà authentifié auprès de Cloudflare"
        echo ""
        return 0
    fi

    log "Authentification requise..."
    echo ""

    cat << 'EOF'
📋 Instructions :

1. Une URL va s'afficher dans le terminal
2. Ouvrez cette URL dans votre navigateur
3. Connectez-vous à Cloudflare
4. Sélectionnez votre domaine
5. Autorisez l'accès

Appuyez sur Entrée pour continuer...
EOF

    read

    if cloudflared tunnel login; then
        ok "Authentification réussie"
    else
        error_exit "Échec de l'authentification"
    fi

    echo ""
}

#############################################################################
# Création nouveau tunnel
#############################################################################

create_new_tunnel() {
    section "🆕 Création du nouveau tunnel"

    log "Création du tunnel '${TUNNEL_NAME}'..."

    # Vérifier si tunnel existe déjà
    if cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
        warn "Tunnel '${TUNNEL_NAME}' existe déjà"

        read -p "Voulez-vous le supprimer et le recréer ? [y/N]: " recreate

        if [[ $recreate =~ ^[Yy]$ ]]; then
            log "Suppression du tunnel existant..."
            cloudflared tunnel delete "$TUNNEL_NAME" 2>/dev/null || true
        else
            error_exit "Migration annulée"
        fi
    fi

    # Créer le tunnel
    if cloudflared tunnel create "$TUNNEL_NAME" 2>&1 | tee -a "$LOG_FILE"; then
        ok "Tunnel créé avec succès"
    else
        error_exit "Échec de la création du tunnel"
    fi

    # Extraire l'ID
    TUNNEL_ID=$(cloudflared tunnel list 2>/dev/null | grep "$TUNNEL_NAME" | awk '{print $1}' | head -1)

    if [[ -z "$TUNNEL_ID" ]]; then
        error_exit "Impossible d'extraire l'ID du tunnel"
    fi

    ok "Tunnel ID : ${TUNNEL_ID}"
    echo ""
}

#############################################################################
# Configuration DNS
#############################################################################

configure_dns() {
    section "🌐 Configuration DNS"

    log "Configuration de la route DNS..."

    if cloudflared tunnel route dns "$TUNNEL_NAME" "$CUSTOM_DOMAIN" 2>&1 | tee -a "$LOG_FILE"; then
        ok "Route DNS créée avec succès"
    else
        warn "Échec de la création DNS automatique"
        echo ""
        echo -e "${YELLOW}Configuration DNS manuelle requise :${NC}"
        echo ""
        echo "1. Allez sur https://dash.cloudflare.com"
        echo "2. Sélectionnez votre domaine"
        echo "3. DNS → Records → Add Record"
        echo "4. Type: CNAME"
        echo "5. Name: $(echo "$CUSTOM_DOMAIN" | cut -d'.' -f1)"
        echo "6. Target: ${TUNNEL_ID}.cfargotunnel.com"
        echo "7. Proxy: Proxied (orange cloud)"
        echo ""
        read -p "Appuyez sur Entrée après avoir configuré le DNS..."
    fi

    echo ""
}

#############################################################################
# Copie credentials
#############################################################################

copy_credentials() {
    section "🔑 Configuration des credentials"

    log "Copie des credentials..."

    local cred_source="/root/.cloudflared/${TUNNEL_ID}.json"
    local cred_dest="${TUNNEL_DIR}/credentials.json"

    if [[ ! -f "$cred_source" ]]; then
        error_exit "Credentials non trouvées : ${cred_source}"
    fi

    cp "$cred_source" "$cred_dest"
    chmod 600 "$cred_dest"
    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "$cred_dest"

    ok "Credentials copiées"
    echo ""
}

#############################################################################
# Génération nouvelle config
#############################################################################

generate_new_config() {
    section "⚙️  Génération de la nouvelle configuration"

    log "Création config.yml..."

    # Extraire service de l'ancienne config
    local service=$(grep "command: tunnel --url" "${TUNNEL_DIR}/docker-compose.yml" | sed 's/.*http:\/\///' | tr -d ' ')

    if [[ -z "$service" ]]; then
        error_exit "Impossible d'extraire le service de l'ancienne configuration"
    fi

    ok "Service détecté : ${service}"

    # Créer config.yml
    cat > "${TUNNEL_DIR}/config.yml" << EOF
# Cloudflare Tunnel - ${APP_NAME} (Production)
# Généré le : $(date)
# Tunnel ID : ${TUNNEL_ID}
# Domaine : ${CUSTOM_DOMAIN}

tunnel: ${TUNNEL_ID}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  # ${APP_NAME}
  - hostname: ${CUSTOM_DOMAIN}
    service: http://${service}
    originRequest:
      noTLSVerify: false
      connectTimeout: 30s
      tlsTimeout: 10s

  # Catch-all rule (obligatoire)
  - service: http_status:404
EOF

    chmod 600 "${TUNNEL_DIR}/config.yml"
    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "${TUNNEL_DIR}/config.yml"

    ok "config.yml créé"
    echo ""
}

#############################################################################
# Mise à jour docker-compose
#############################################################################

update_docker_compose() {
    section "🐳 Mise à jour docker-compose.yml"

    log "Génération nouveau docker-compose.yml..."

    # Extraire réseau de l'ancienne config
    local network=$(grep "name:" "${TUNNEL_DIR}/docker-compose.yml" | tail -1 | awk '{print $2}')

    if [[ -z "$network" ]]; then
        network="bridge"
    fi

    # Créer nouveau docker-compose.yml
    cat > "${TUNNEL_DIR}/docker-compose.yml" << EOF
# Cloudflare Tunnel - ${APP_NAME} (Production avec Domaine)
# Généré le : $(date)

version: '3.8'

services:
  ${APP_NAME}-tunnel:
    image: cloudflare/cloudflared:latest
    container_name: ${APP_NAME}-tunnel
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml:ro
      - ./credentials.json:/etc/cloudflared/credentials.json:ro
    networks:
      - ${network}
    # Healthcheck désactivé: cloudflared utilise une image distroless sans shell
    # restart: unless-stopped assure le redémarrage automatique en cas de crash

networks:
  ${network}:
    external: true
    name: ${network}
EOF

    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "${TUNNEL_DIR}/docker-compose.yml"

    ok "docker-compose.yml mis à jour"
    echo ""
}

#############################################################################
# Démarrage nouveau tunnel
#############################################################################

start_new_tunnel() {
    section "🚀 Démarrage du nouveau tunnel"

    cd "$TUNNEL_DIR"

    log "Démarrage du tunnel avec domaine personnalisé..."

    if docker compose up -d 2>&1 | tee -a "$LOG_FILE"; then
        sleep 5

        if docker ps --filter "name=${APP_NAME}-tunnel" --format "{{.Names}}" | grep -q "${APP_NAME}-tunnel"; then
            ok "✅ Tunnel démarré avec succès !"
        else
            error "Le tunnel n'a pas démarré correctement"
            log "Logs :"
            docker logs "${APP_NAME}-tunnel" --tail 20
            error_exit "Consultez les logs ci-dessus"
        fi
    else
        error_exit "Échec du démarrage du tunnel"
    fi

    echo ""
}

#############################################################################
# Mise à jour scripts
#############################################################################

update_helper_scripts() {
    section "📝 Mise à jour des scripts utilitaires"

    # Mettre à jour get-url.sh
    cat > "${TUNNEL_DIR}/get-url.sh" << EOF
#!/bin/bash
echo "🌐 URL publique (domaine custom) :"
echo "https://${CUSTOM_DOMAIN}"
EOF

    # Mettre à jour status.sh
    cat > "${TUNNEL_DIR}/status.sh" << 'EOF'
#!/bin/bash
echo "═══ Status Tunnel ${APP_NAME} (Production) ═══"
echo ""

# Container status
if docker ps --filter "name=${APP_NAME}-tunnel" --format "{{.Names}}" | grep -q "${APP_NAME}-tunnel"; then
    health=$(docker inspect ${APP_NAME}-tunnel --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
    echo "✅ Container: UP ($health)"

    # URL
    echo ""
    echo "🌐 URL publique (PERMANENTE):"
    echo "https://${CUSTOM_DOMAIN}"

    # RAM
    echo ""
    echo "💾 RAM:"
    docker stats --no-stream --format "  {{.MemUsage}}" ${APP_NAME}-tunnel
else
    echo "❌ Container: DOWN"
    echo ""
    echo "Pour démarrer:"
    echo "  cd ${TUNNEL_DIR}"
    echo "  docker compose up -d"
fi
EOF

    # Remplacer variables
    sed -i "s/\${APP_NAME}/${APP_NAME}/g" "${TUNNEL_DIR}/status.sh"
    sed -i "s/\${CUSTOM_DOMAIN}/${CUSTOM_DOMAIN}/g" "${TUNNEL_DIR}/status.sh"
    sed -i "s|\${TUNNEL_DIR}|${TUNNEL_DIR}|g" "${TUNNEL_DIR}/status.sh"

    chmod +x "${TUNNEL_DIR}/get-url.sh"
    chmod +x "${TUNNEL_DIR}/status.sh"

    chown "${SUDO_USER:-pi}:${SUDO_USER:-pi}" "${TUNNEL_DIR}"/*.sh

    ok "Scripts mis à jour"
    echo ""
}

#############################################################################
# Test connectivité
#############################################################################

test_new_tunnel() {
    section "🧪 Test de connectivité"

    log "Attente de la propagation DNS (30 secondes)..."
    sleep 30

    log "Test de l'URL : https://${CUSTOM_DOMAIN}"

    if curl -sf -o /dev/null --max-time 10 "https://${CUSTOM_DOMAIN}"; then
        ok "✅ Le tunnel avec domaine custom est accessible !"
    else
        warn "⚠️  Le tunnel ne répond pas encore"
        echo ""
        echo "Cela peut prendre 5-10 minutes (propagation DNS)"
        echo ""
        echo "Testez manuellement avec :"
        echo "  curl -I https://${CUSTOM_DOMAIN}"
    fi

    echo ""
}

#############################################################################
# Résumé final
#############################################################################

show_summary() {
    section "📊 Migration Terminée"

    cat << EOF
╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║     ✅ Migration Réussie !                                          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝

📦 Configuration :
   • Application : ${APP_NAME}
   • Tunnel : ${TUNNEL_NAME}
   • Tunnel ID : ${TUNNEL_ID}
   • Dossier : ${TUNNEL_DIR}

🌐 URL PERMANENTE :
   https://${CUSTOM_DOMAIN}

   ✅ Cette URL ne change PLUS jamais !
   ✅ Certificat SSL automatique (Let's Encrypt via Cloudflare)
   ✅ Protection DDoS Cloudflare incluse

💾 Backup :
   L'ancienne configuration a été sauvegardée dans :
   ${BACKUP_DIR}

📝 Commandes Utiles :

   Obtenir l'URL :
   └─ bash ${TUNNEL_DIR}/get-url.sh

   Voir le status :
   └─ bash ${TUNNEL_DIR}/status.sh

   Voir les logs :
   └─ docker logs -f ${APP_NAME}-tunnel

   Redémarrer le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose restart

   Arrêter le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose down

   Démarrer le tunnel :
   └─ cd ${TUNNEL_DIR} && docker compose up -d

🔧 Fichiers de configuration :
   • ${TUNNEL_DIR}/config.yml
   • ${TUNNEL_DIR}/credentials.json
   • ${TUNNEL_DIR}/docker-compose.yml

🆘 Troubleshooting :

   Si l'URL ne fonctionne pas :
   1. Attendre 5-10 minutes (propagation DNS)
   2. Vérifier DNS : dig ${CUSTOM_DOMAIN}
   3. Vérifier logs : docker logs ${APP_NAME}-tunnel
   4. Vérifier Cloudflare Dashboard : https://dash.cloudflare.com

📚 Documentation :
   • Log complet : ${LOG_FILE}
   • Backup : ${BACKUP_DIR}

EOF

    ok "Migration terminée avec succès !"
    echo ""
}

#############################################################################
# Main
#############################################################################

main() {
    banner
    check_root
    check_cloudflared
    detect_existing_tunnel
    prompt_domain_info
    create_backup
    stop_current_tunnel
    authenticate_cloudflare
    create_new_tunnel
    configure_dns
    copy_credentials
    generate_new_config
    update_docker_compose
    update_helper_scripts
    start_new_tunnel
    test_new_tunnel
    show_summary
}

main "$@"
