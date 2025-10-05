#!/usr/bin/env bash
#
# Pi-hole Deployment Script - Phase 11
# Bloque publicités sur TOUT le réseau (PC, mobile, TV, IoT)
#
# Source officielle : https://github.com/pi-hole/docker-pi-hole
# Documentation : https://docs.pi-hole.net/docker/
#
# Ce script est IDEMPOTENT : peut être exécuté plusieurs fois sans problème

set -euo pipefail

#######################
# VARIABLES & CHEMINS
#######################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
COMMON_SCRIPTS_DIR="${PROJECT_ROOT}/common-scripts"

# Charger bibliothèque commune
if [[ -f "${COMMON_SCRIPTS_DIR}/lib.sh" ]]; then
    source "${COMMON_SCRIPTS_DIR}/lib.sh"
else
    echo "❌ Erreur : ${COMMON_SCRIPTS_DIR}/lib.sh introuvable"
    exit 1
fi

# Configuration
STACK_NAME="pihole"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"

# Détection Traefik
TRAEFIK_ENV="${HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

#######################
# FONCTIONS
#######################

detect_traefik_scenario() {
    if [[ ! -f "${TRAEFIK_ENV}" ]]; then
        log_warn "Traefik non détecté - Installation sans reverse proxy"
        return
    fi

    if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="duckdns"
        DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
        log_info "Traefik DuckDNS détecté : ${DUCKDNS_SUBDOMAIN}"
    elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
        log_info "Traefik Cloudflare détecté : ${DOMAIN}"
    elif grep -q "VPN_MODE" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="vpn"
        log_info "Traefik VPN détecté"
    fi
}

get_raspberry_ip() {
    # Récupérer IP locale du Raspberry Pi
    hostname -I | awk '{print $1}'
}

create_pihole_env() {
    local admin_password
    local timezone
    local server_ip

    server_ip=$(get_raspberry_ip)
    timezone=$(timedatectl show -p Timezone --value 2>/dev/null || echo "Europe/Paris")

    log_info "Configuration Pi-hole..."

    # Générer mot de passe admin si non existant
    if [[ -f "${ENV_FILE}" ]] && grep -q "^PIHOLE_PASSWORD=" "${ENV_FILE}"; then
        admin_password=$(grep "^PIHOLE_PASSWORD=" "${ENV_FILE}" | cut -d'=' -f2)
        log_info "Mot de passe existant conservé"
    else
        admin_password=$(openssl rand -base64 16)
        log_success "Mot de passe admin généré : ${admin_password}"
    fi

    cat > "${ENV_FILE}" <<EOF
# Pi-hole Configuration
# Généré le $(date)

# Mot de passe interface admin
PIHOLE_PASSWORD=${admin_password}

# Timezone
TZ=${timezone}

# IP serveur (pour config DNS)
SERVER_IP=${server_ip}

# Ports (modifiables si conflit)
HTTP_PORT=8888
HTTPS_PORT=8889

# DNS upstream (Cloudflare par défaut)
PIHOLE_DNS_=1.1.1.1;1.0.0.1

# Interface web
WEBPASSWORD=${admin_password}
VIRTUAL_HOST=pihole.local
EOF

    chmod 600 "${ENV_FILE}"
    log_success "Fichier .env créé : ${ENV_FILE}"
}

create_docker_compose() {
    log_info "Génération docker-compose.yml..."

    local http_port="${HTTP_PORT:-8888}"
    local https_port="${HTTPS_PORT:-8889}"

    cat > "${COMPOSE_FILE}" <<'EOF'
version: '3.8'

services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    hostname: pihole
    ports:
      - "53:53/tcp"      # DNS
      - "53:53/udp"      # DNS
      - "${HTTP_PORT:-8888}:80/tcp"    # Interface HTTP
      - "${HTTPS_PORT:-8889}:443/tcp"  # Interface HTTPS (optionnel)
    environment:
      TZ: ${TZ}
      WEBPASSWORD: ${PIHOLE_PASSWORD}
      FTLCONF_webserver_api_password: ${PIHOLE_PASSWORD}
      FTLCONF_dns_listeningMode: 'all'
      PIHOLE_DNS_: ${PIHOLE_DNS_}
      VIRTUAL_HOST: ${VIRTUAL_HOST:-pihole.local}
      ServerIP: ${SERVER_IP}
    volumes:
      - ./etc-pihole:/etc/pihole
      - ./etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
      - SYS_TIME
      - SYS_NICE
    restart: unless-stopped
    dns:
      - 127.0.0.1
      - 1.1.1.1
    healthcheck:
      test: ["CMD", "dig", "+short", "pi.hole", "@127.0.0.1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
EOF

    # Ajouter labels Traefik si détecté
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${COMPOSE_FILE}" <<'EOF'
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.pihole.loadbalancer.server.port=80"
EOF

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.pihole.rule=PathPrefix(\`/admin\`) || Host(\`pihole.${DUCKDNS_SUBDOMAIN}.duckdns.org\`)"
      - "traefik.http.routers.pihole.entrypoints=websecure"
      - "traefik.http.routers.pihole.tls.certresolver=letsencrypt"
EOF
                ;;
            cloudflare)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.pihole.rule=Host(\`pihole.${DOMAIN}\`)"
      - "traefik.http.routers.pihole.entrypoints=websecure"
      - "traefik.http.routers.pihole.tls.certresolver=letsencrypt"
EOF
                ;;
            vpn)
                cat >> "${COMPOSE_FILE}" <<'EOF'
      - "traefik.http.routers.pihole.rule=Host(`pihole.pi.local`)"
      - "traefik.http.routers.pihole.entrypoints=websecure"
      - "traefik.http.routers.pihole.tls=true"
EOF
                ;;
        esac
    fi

    # Ajouter network externe Traefik
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  traefik-network:
    external: true
EOF
    fi

    log_success "docker-compose.yml créé"
}

update_homepage_config() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"

    if [[ ! -f "${homepage_config}" ]]; then
        log_warn "Homepage non installé - skip intégration"
        return
    fi

    log_info "Intégration Homepage..."

    # Vérifier si Pi-hole déjà présent
    if grep -q "Pi-hole:" "${homepage_config}"; then
        log_info "Pi-hole déjà dans Homepage"
        return
    fi

    # Ajouter widget Pi-hole
    cat >> "${homepage_config}" <<EOF

- Réseau & Sécurité:
    - Pi-hole:
        href: http://raspberrypi.local:${HTTP_PORT:-8888}/admin
        description: Bloqueur de publicités réseau
        icon: pi-hole.png
        widget:
          type: pihole
          url: http://pihole:80
          key: ${PIHOLE_PASSWORD}
EOF

    # Redémarrer Homepage pour appliquer
    if docker ps --format '{{.Names}}' | grep -q "^homepage$"; then
        docker restart homepage >/dev/null 2>&1
        log_success "Homepage mis à jour"
    fi
}

configure_dns_instructions() {
    local server_ip
    server_ip=$(get_raspberry_ip)

    cat > "${STACK_DIR}/DNS-SETUP.md" <<EOF
# 📡 Configuration DNS pour Pi-hole

## Option 1 : Appareil par Appareil

### 🖥️ Windows
1. Paramètres → Réseau → Propriétés de la connexion
2. Modifier DNS : \`${server_ip}\`

### 🍎 macOS
1. Préférences Système → Réseau → Avancé
2. DNS → Ajouter : \`${server_ip}\`

### 📱 Android
1. Paramètres → Wi-Fi → Modifier réseau
2. DNS : \`${server_ip}\`

### 🍏 iOS
1. Réglages → Wi-Fi → (i) → Configurer DNS
2. Manuel → Ajouter serveur : \`${server_ip}\`

---

## Option 2 : Router (RECOMMANDÉ - Tout le réseau)

### Configuration Router
1. Accéder interface admin router (ex: 192.168.1.1)
2. Section DHCP/DNS
3. DNS primaire : \`${server_ip}\`
4. DNS secondaire : \`1.1.1.1\` (backup)
5. Sauvegarder et redémarrer

**Avantage** : Tous les appareils sont protégés automatiquement

---

## Tester Pi-hole

\`\`\`bash
# Vérifier résolution DNS
nslookup google.com ${server_ip}

# Tester blocage pub (devrait être bloqué)
nslookup doubleclick.net ${server_ip}
\`\`\`

---

## Interface Admin

- **URL** : http://raspberrypi.local:${HTTP_PORT:-8888}/admin
- **Mot de passe** : \`${PIHOLE_PASSWORD}\`

---

## Notes Importantes

⚠️ **Port 53 requis** : Pi-hole utilise port 53 (DNS standard)
⚠️ **Pas de conflit** : Vérifier qu'aucun autre service n'utilise port 53
⚠️ **Redémarrer appareils** : Après config DNS, redémarrer pour appliquer
EOF

    log_success "Guide DNS créé : ${STACK_DIR}/DNS-SETUP.md"
}

#######################
# MAIN
#######################

main() {
    print_header "Pi-hole - Bloqueur de Publicités Réseau"

    log_info "Installation Pi-hole Phase 11..."
    echo ""

    # Créer répertoire stack
    mkdir -p "${STACK_DIR}"
    cd "${STACK_DIR}" || exit 1

    # Détection Traefik
    detect_traefik_scenario

    # Vérifier port 53 disponible
    if netstat -tuln 2>/dev/null | grep -q ":53 "; then
        log_error "Port 53 déjà utilisé !"
        log_warn "Pi-hole nécessite le port 53 pour DNS"
        echo ""
        echo "Solutions :"
        echo "  1. Arrêter service utilisant port 53 : sudo systemctl stop systemd-resolved"
        echo "  2. Configurer Pi-hole sur port alternatif (non recommandé)"
        exit 1
    fi

    # Générer configuration
    create_pihole_env
    create_docker_compose

    # Déployer
    log_info "Déploiement Pi-hole..."
    docker-compose up -d

    # Attendre démarrage
    log_info "Attente démarrage Pi-hole (60s)..."
    sleep 10

    # Vérifier healthcheck
    if wait_for_healthy "pihole" 120; then
        log_success "Pi-hole démarré avec succès !"
    else
        log_error "Pi-hole n'a pas démarré correctement"
        docker-compose logs pihole
        exit 1
    fi

    # Intégrations
    update_homepage_config
    configure_dns_instructions

    # Afficher résumé
    echo ""
    print_section "Pi-hole Installé !"
    echo ""

    local server_ip
    server_ip=$(get_raspberry_ip)

    echo "📡 Configuration DNS :"
    echo "  IP serveur DNS : ${server_ip}"
    echo "  Port DNS       : 53"
    echo ""
    echo "🌐 Interface Admin :"

    if [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]]; then
        echo "  URL : https://pihole.${DUCKDNS_SUBDOMAIN}.duckdns.org/admin"
    elif [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]]; then
        echo "  URL : https://pihole.${DOMAIN}/admin"
    elif [[ "${TRAEFIK_SCENARIO}" == "vpn" ]]; then
        echo "  URL : https://pihole.pi.local/admin"
    else
        echo "  URL : http://raspberrypi.local:${HTTP_PORT:-8888}/admin"
    fi

    echo "  Mot de passe : $(grep PIHOLE_PASSWORD ${ENV_FILE} | cut -d'=' -f2)"
    echo ""
    echo "📋 Guide configuration DNS :"
    echo "  cat ${STACK_DIR}/DNS-SETUP.md"
    echo ""
    echo "📊 Statistiques :"
    echo "  RAM : ~50 MB"
    echo "  Stockage : ~100 MB"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "  docker-compose logs pihole      # Voir logs"
    echo "  docker-compose restart pihole   # Redémarrer"
    echo "  docker exec pihole pihole -up   # Update gravity"
    echo ""

    log_success "Installation terminée !"
    echo ""
    log_warn "⚠️  IMPORTANT : Configurer DNS sur vos appareils ou router"
    log_warn "    Voir guide : ${STACK_DIR}/DNS-SETUP.md"
}

# Exécution
main "$@"
