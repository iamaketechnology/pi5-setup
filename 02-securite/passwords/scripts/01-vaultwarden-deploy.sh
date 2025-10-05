#!/usr/bin/env bash
#
# Vaultwarden Deployment Script - Phase 12
# Password Manager Self-Hosted (Bitwarden alternative)
#
# Source officielle : https://github.com/dani-garcia/vaultwarden
# Docker Hub : https://hub.docker.com/r/vaultwarden/server
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
STACK_NAME="vaultwarden"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"
DATA_DIR="${STACK_DIR}/data"

# Détection Traefik
TRAEFIK_ENV="${HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

#######################
# FONCTIONS
#######################

detect_traefik_scenario() {
    if [[ ! -f "${TRAEFIK_ENV}" ]]; then
        log_warn "Traefik non détecté - Installation sans HTTPS"
        log_warn "⚠️  Vaultwarden NÉCESSITE HTTPS pour fonctionner correctement"
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

create_vaultwarden_env() {
    local admin_token
    local domain_url

    log_info "Configuration Vaultwarden..."

    # Générer admin token si non existant
    if [[ -f "${ENV_FILE}" ]] && grep -q "^ADMIN_TOKEN=" "${ENV_FILE}"; then
        admin_token=$(grep "^ADMIN_TOKEN=" "${ENV_FILE}" | cut -d'=' -f2)
        log_info "Admin token existant conservé"
    else
        admin_token=$(openssl rand -base64 48)
        log_success "Admin token généré"
    fi

    # Déterminer DOMAIN selon scénario Traefik
    case "${TRAEFIK_SCENARIO}" in
        duckdns)
            domain_url="https://vault.${DUCKDNS_SUBDOMAIN}.duckdns.org"
            ;;
        cloudflare)
            domain_url="https://vault.${DOMAIN}"
            ;;
        vpn)
            domain_url="https://vault.pi.local"
            ;;
        *)
            domain_url="http://raspberrypi.local:8200"
            log_warn "⚠️  HTTPS non configuré - fonctionnalités limitées"
            ;;
    esac

    cat > "${ENV_FILE}" <<EOF
# Vaultwarden Configuration
# Généré le $(date)

# Domain URL (HTTPS FORTEMENT RECOMMANDÉ)
DOMAIN=${domain_url}

# Admin panel token (pour /admin)
# Généré aléatoirement - À CONSERVER PRÉCIEUSEMENT
ADMIN_TOKEN=${admin_token}

# Signup (création de comptes)
# true = ouvert, false = invitations seulement
SIGNUPS_ALLOWED=true

# Invitations
INVITATIONS_ALLOWED=true

# Web Vault (interface web)
WEB_VAULT_ENABLED=true

# WebSocket (pour sync temps réel)
WEBSOCKET_ENABLED=true
WEBSOCKET_PORT=3012

# Logs
LOG_LEVEL=info
EXTENDED_LOGGING=true

# Email (optionnel - pour invitations/vérification)
# Décommenter et configurer si besoin
# SMTP_HOST=smtp.gmail.com
# SMTP_PORT=587
# SMTP_SECURITY=starttls
# SMTP_FROM=vaultwarden@example.com
# SMTP_USERNAME=your-email@gmail.com
# SMTP_PASSWORD=your-app-password

# Database (SQLite par défaut)
DATABASE_URL=/data/db.sqlite3

# Rocket (serveur web)
ROCKET_PORT=80
EOF

    chmod 600 "${ENV_FILE}"
    log_success "Fichier .env créé : ${ENV_FILE}"
}

create_docker_compose() {
    log_info "Génération docker-compose.yml..."

    cat > "${COMPOSE_FILE}" <<'EOF'
version: '3.8'

services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    hostname: vaultwarden
    restart: unless-stopped
    environment:
      DOMAIN: ${DOMAIN}
      ADMIN_TOKEN: ${ADMIN_TOKEN}
      SIGNUPS_ALLOWED: ${SIGNUPS_ALLOWED:-true}
      INVITATIONS_ALLOWED: ${INVITATIONS_ALLOWED:-true}
      WEB_VAULT_ENABLED: ${WEB_VAULT_ENABLED:-true}
      WEBSOCKET_ENABLED: ${WEBSOCKET_ENABLED:-true}
      LOG_LEVEL: ${LOG_LEVEL:-info}
      EXTENDED_LOGGING: ${EXTENDED_LOGGING:-true}
      DATABASE_URL: ${DATABASE_URL}
      ROCKET_PORT: ${ROCKET_PORT:-80}
    volumes:
      - ${DATA_DIR:-./data}:/data
    ports:
      - "8200:80"       # Web Vault
      - "3012:3012"     # WebSocket
EOF

    # Ajouter labels Traefik si détecté
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${COMPOSE_FILE}" <<'EOF'
    networks:
      - traefik-network
    labels:
      - "traefik.enable=true"

      # HTTP Router
      - "traefik.http.services.vaultwarden.loadbalancer.server.port=80"
EOF

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.vaultwarden.rule=Host(\`vault.${DUCKDNS_SUBDOMAIN}.duckdns.org\`)"
      - "traefik.http.routers.vaultwarden.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden.tls.certresolver=letsencrypt"

      # WebSocket
      - "traefik.http.routers.vaultwarden-ws.rule=Host(\`vault.${DUCKDNS_SUBDOMAIN}.duckdns.org\`) && Path(\`/notifications/hub\`)"
      - "traefik.http.routers.vaultwarden-ws.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden-ws.tls.certresolver=letsencrypt"
      - "traefik.http.routers.vaultwarden-ws.service=vaultwarden-ws"
      - "traefik.http.services.vaultwarden-ws.loadbalancer.server.port=3012"
EOF
                ;;
            cloudflare)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.vaultwarden.rule=Host(\`vault.${DOMAIN}\`)"
      - "traefik.http.routers.vaultwarden.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden.tls.certresolver=letsencrypt"

      # WebSocket
      - "traefik.http.routers.vaultwarden-ws.rule=Host(\`vault.${DOMAIN}\`) && Path(\`/notifications/hub\`)"
      - "traefik.http.routers.vaultwarden-ws.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden-ws.tls.certresolver=letsencrypt"
      - "traefik.http.routers.vaultwarden-ws.service=vaultwarden-ws"
      - "traefik.http.services.vaultwarden-ws.loadbalancer.server.port=3012"
EOF
                ;;
            vpn)
                cat >> "${COMPOSE_FILE}" <<'EOF'
      - "traefik.http.routers.vaultwarden.rule=Host(`vault.pi.local`)"
      - "traefik.http.routers.vaultwarden.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden.tls=true"

      # WebSocket
      - "traefik.http.routers.vaultwarden-ws.rule=Host(`vault.pi.local`) && Path(`/notifications/hub`)"
      - "traefik.http.routers.vaultwarden-ws.entrypoints=websecure"
      - "traefik.http.routers.vaultwarden-ws.tls=true"
      - "traefik.http.routers.vaultwarden-ws.service=vaultwarden-ws"
      - "traefik.http.services.vaultwarden-ws.loadbalancer.server.port=3012"
EOF
                ;;
        esac

        # Ajouter network externe Traefik
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

    # Vérifier si Vaultwarden déjà présent
    if grep -q "Vaultwarden:" "${homepage_config}"; then
        log_info "Vaultwarden déjà dans Homepage"
        return
    fi

    # Ajouter Vaultwarden
    cat >> "${homepage_config}" <<EOF

- Sécurité:
    - Vaultwarden:
        href: ${DOMAIN}
        description: Password Manager (Bitwarden)
        icon: bitwarden.png
EOF

    # Redémarrer Homepage
    if docker ps --format '{{.Names}}' | grep -q "^homepage$"; then
        docker restart homepage >/dev/null 2>&1
        log_success "Homepage mis à jour"
    fi
}

create_usage_guide() {
    cat > "${STACK_DIR}/USAGE-GUIDE.md" <<EOF
# 🔐 Guide d'Utilisation Vaultwarden

## Accès

**Interface Web** : ${DOMAIN}
**Admin Panel** : ${DOMAIN}/admin

**Admin Token** :
\`\`\`
$(grep ADMIN_TOKEN ${ENV_FILE} | cut -d'=' -f2)
\`\`\`

⚠️ **CONSERVEZ CE TOKEN EN LIEU SÛR** - Nécessaire pour accéder à /admin

---

## 🚀 Premiers Pas

### 1. Créer Votre Compte

1. Ouvrir : ${DOMAIN}
2. Cliquer "Create Account"
3. Email + Master Password (FORT et MÉMORISÉ)
4. Confirmer email (si SMTP configuré)

### 2. Installer Apps Clientes

#### 📱 Mobile
- **Android** : https://play.google.com/store/apps/details?id=com.x8bit.bitwarden
- **iOS** : https://apps.apple.com/app/bitwarden-password-manager/id1137397744

Configuration :
- Server URL : \`${DOMAIN}\`
- Email + Master Password

#### 🖥️ Desktop
- **Windows/Mac/Linux** : https://bitwarden.com/download/

Configuration identique.

#### 🌐 Extensions Navigateur
- **Chrome** : https://chrome.google.com/webstore/detail/bitwarden/nngceckbapebfimnlniiiahkandclblb
- **Firefox** : https://addons.mozilla.org/firefox/addon/bitwarden-password-manager/

---

## 📋 Fonctionnalités

### Coffre-Fort
- **Logins** : Sites web + apps
- **Cartes bancaires** : Chiffrement AES-256
- **Identités** : Infos personnelles
- **Notes sécurisées** : Texte chiffré

### Générateur Mots de Passe
- Longueur personnalisable
- Caractères spéciaux
- Passphrases

### Auto-Fill
- Extensions navigateur
- Apps mobiles (Android/iOS)

### Partage Sécurisé
- Organizations (équipes)
- Collections
- Permissions granulaires

---

## 🔧 Admin Panel (/admin)

Accès : ${DOMAIN}/admin
Token : Voir ci-dessus

**Fonctionnalités Admin** :
- Gérer utilisateurs
- Invitations
- Diagnostics
- Configuration avancée

---

## 🔐 Sécurité

### Master Password
- **CRUCIAL** : Seul vous le connaissez
- **Perte = IMPOSSIBLE de récupérer**
- Recommandations :
  - 16+ caractères
  - Mélange majuscules/minuscules/chiffres/symboles
  - Unique (pas réutilisé ailleurs)

### 2FA (Two-Factor Auth)
1. Settings → Two-step Login
2. Activer Authenticator App (Google Auth, Authy)
3. Scanner QR code
4. Sauvegarder recovery code

### Backup
\`\`\`bash
# Backup manuel
cd ${STACK_DIR}
tar -czf vaultwarden-backup-\$(date +%Y%m%d).tar.gz data/

# Copier ailleurs (disque externe, cloud)
\`\`\`

---

## 🔄 Migration depuis Bitwarden/LastPass/1Password

1. Exporter depuis ancien service (format JSON/CSV)
2. Vaultwarden → Tools → Import Data
3. Sélectionner format + fichier
4. Import

---

## 📊 Statistiques Typiques

- **RAM** : ~50 MB
- **Stockage** : ~10 MB (base SQLite)
- **Utilisateurs** : 1-100+ supportés
- **Coffre** : Illimité

---

## ⚠️ Troubleshooting

### "HTTPS requis"
Vaultwarden NÉCESSITE HTTPS sauf localhost.
→ Installer Traefik (Phase 2) ou utiliser VPN

### Sync ne fonctionne pas
Vérifier WebSocket (port 3012) accessible.

### Mot de passe oublié
**IMPOSSIBLE de récupérer** - Master password jamais stocké.
→ Créer nouveau compte (coffre précédent perdu)

---

## 🔗 Ressources

- Documentation : https://github.com/dani-garcia/vaultwarden/wiki
- Bitwarden Help : https://bitwarden.com/help/
- Community : https://vaultwarden.discourse.group/
EOF

    log_success "Guide d'utilisation créé : ${STACK_DIR}/USAGE-GUIDE.md"
}

#######################
# MAIN
#######################

main() {
    print_header "Vaultwarden - Password Manager Self-Hosted"

    log_info "Installation Vaultwarden Phase 12..."
    echo ""

    # Créer répertoires
    mkdir -p "${STACK_DIR}" "${DATA_DIR}"
    cd "${STACK_DIR}" || exit 1

    # Détection Traefik
    detect_traefik_scenario

    if [[ "${TRAEFIK_SCENARIO}" == "none" ]]; then
        echo ""
        log_error "⚠️  ATTENTION : HTTPS FORTEMENT RECOMMANDÉ"
        echo ""
        echo "Vaultwarden fonctionne en HTTP uniquement en local."
        echo "Pour accès externe, HTTPS est OBLIGATOIRE."
        echo ""
        echo "Solutions :"
        echo "  1. Installer Traefik Phase 2 (recommandé)"
        echo "  2. Configurer reverse proxy externe"
        echo "  3. Utiliser VPN uniquement"
        echo ""
        read -p "Continuer sans HTTPS ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_warn "Installation annulée"
            exit 0
        fi
    fi

    # Générer configuration
    create_vaultwarden_env
    create_docker_compose

    # Déployer
    log_info "Déploiement Vaultwarden..."
    docker-compose up -d

    # Attendre démarrage
    log_info "Attente démarrage Vaultwarden (30s)..."
    sleep 30

    # Vérifier container running
    if docker ps | grep -q "vaultwarden"; then
        log_success "Vaultwarden démarré avec succès !"
    else
        log_error "Vaultwarden n'a pas démarré"
        docker-compose logs vaultwarden
        exit 1
    fi

    # Intégrations
    update_homepage_config
    create_usage_guide

    # Afficher résumé
    echo ""
    print_section "Vaultwarden Installé !"
    echo ""

    local domain_url
    domain_url=$(grep "^DOMAIN=" "${ENV_FILE}" | cut -d'=' -f2)
    local admin_token
    admin_token=$(grep "^ADMIN_TOKEN=" "${ENV_FILE}" | cut -d'=' -f2)

    echo "🔐 Accès Vaultwarden :"
    echo "  Interface : ${domain_url}"
    echo "  Admin     : ${domain_url}/admin"
    echo ""
    echo "🔑 Admin Token (À CONSERVER) :"
    echo "  ${admin_token}"
    echo ""
    echo "📱 Apps Clientes :"
    echo "  - Mobile : Play Store / App Store (Bitwarden)"
    echo "  - Desktop : https://bitwarden.com/download/"
    echo "  - Extensions : Chrome, Firefox, Safari, Edge"
    echo ""
    echo "⚙️  Configuration Apps :"
    echo "  Server URL : ${domain_url}"
    echo ""
    echo "📋 Guide complet :"
    echo "  cat ${STACK_DIR}/USAGE-GUIDE.md"
    echo ""
    echo "📊 Statistiques :"
    echo "  RAM : ~50 MB"
    echo "  Stockage : ~10 MB"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "  docker-compose logs vaultwarden     # Logs"
    echo "  docker-compose restart vaultwarden  # Redémarrer"
    echo ""

    log_success "Installation terminée !"
    echo ""
    log_warn "⚠️  IMPORTANT : Sauvegardez votre Admin Token et Master Password"
    log_warn "    Perte = impossible de récupérer votre coffre"
}

# Exécution
main "$@"
