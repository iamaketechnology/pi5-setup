#!/bin/bash
set -euo pipefail

#############################################################################
# Option 2: Cloudflare Tunnel (Cloudflared)
#
# Description: Accès externe sécurisé sans ouvrir de ports
# Avantages: Sécurité maximale, protection DDoS, IP cachée, pas de config routeur
# Prérequis: Compte Cloudflare (gratuit), domaine (ou sous-domaine Cloudflare)
#############################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}ℹ️  $*${NC}"; }
ok() { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }

error_exit() {
    error "$1"
    exit 1
}

banner() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}║     ${CYAN}☁️  Option 2: Cloudflare Tunnel Setup${BLUE}                  ║${NC}"
    echo -e "${BLUE}║                                                                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#############################################################################
# Variables
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="${BASE_DIR}/config"
CLOUDFLARED_VERSION="latest"
TUNNEL_NAME="pi5-supabase"
CF_DOMAIN=""
CF_TUNNEL_ID=""
CF_TOKEN=""

#############################################################################
# Prérequis
#############################################################################

check_prerequisites() {
    log "Vérification des prérequis..."

    # Docker
    if ! command -v docker &> /dev/null; then
        error_exit "Docker n'est pas installé. Exécutez d'abord 01-prerequisites-setup.sh"
    fi

    # jq pour parsing JSON
    if ! command -v jq &> /dev/null; then
        log "Installation de jq..."
        sudo apt-get update -qq && sudo apt-get install -y jq
    fi

    ok "Prérequis vérifiés"
}

#############################################################################
# Installation Cloudflared
#############################################################################

install_cloudflared() {
    log "Installation de cloudflared..."

    # Détecter architecture
    local arch=$(uname -m)
    local cloudflared_arch=""

    case "$arch" in
        aarch64|arm64)
            cloudflared_arch="arm64"
            ;;
        armv7l|armhf)
            cloudflared_arch="arm"
            ;;
        x86_64|amd64)
            cloudflared_arch="amd64"
            ;;
        *)
            error_exit "Architecture non supportée: $arch"
            ;;
    esac

    log "Architecture détectée: ${arch} → cloudflared ${cloudflared_arch}"

    # Télécharger et installer
    local download_url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${cloudflared_arch}"

    log "Téléchargement depuis ${download_url}..."

    if ! sudo curl -fsSL "$download_url" -o /usr/local/bin/cloudflared; then
        error_exit "Échec du téléchargement de cloudflared"
    fi

    sudo chmod +x /usr/local/bin/cloudflared

    # Vérifier version
    local version=$(/usr/local/bin/cloudflared --version 2>&1 | head -1 || echo "unknown")
    ok "cloudflared installé: ${version}"
}

#############################################################################
# Configuration interactive
#############################################################################

interactive_setup() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}📝 Configuration Cloudflare Tunnel${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    cat << 'EOF'
Pour configurer Cloudflare Tunnel, vous avez 2 options :

┌─────────────────────────────────────────────────────────────────┐
│ Option A : Configuration automatique (RECOMMANDÉ)               │
├─────────────────────────────────────────────────────────────────┤
│ • Connexion interactive via navigateur                          │
│ • Cloudflared crée automatiquement le tunnel                    │
│ • Configuration DNS automatique                                 │
│ • Plus simple et plus rapide                                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ Option B : Configuration manuelle                               │
├─────────────────────────────────────────────────────────────────┤
│ • Créer le tunnel manuellement dans le dashboard Cloudflare    │
│ • Copier-coller le token                                        │
│ • Configuration DNS manuelle                                    │
│ • Plus de contrôle, mais plus complexe                          │
└─────────────────────────────────────────────────────────────────┘

EOF

    read -p "Choisissez votre méthode [A/B]: " method
    method=$(echo "$method" | tr '[:lower:]' '[:upper:]')

    case "$method" in
        A|"")
            setup_automatic
            ;;
        B)
            setup_manual
            ;;
        *)
            error "Choix invalide"
            interactive_setup
            ;;
    esac
}

#############################################################################
# Setup automatique (OAuth)
#############################################################################

setup_automatic() {
    echo ""
    log "🚀 Configuration automatique via OAuth..."
    echo ""

    cat << 'EOF'
📋 Instructions :

1. Une URL va s'afficher dans le terminal
2. Ouvrez cette URL dans votre navigateur
3. Connectez-vous à votre compte Cloudflare
4. Autorisez l'accès
5. Le tunnel sera créé automatiquement

Appuyez sur Entrée pour continuer...
EOF

    read

    # Authentification
    log "Lancement de l'authentification Cloudflare..."

    if ! sudo cloudflared tunnel login; then
        error_exit "Échec de l'authentification Cloudflare"
    fi

    ok "Authentification réussie !"

    # Créer le tunnel
    log "Création du tunnel '${TUNNEL_NAME}'..."

    if ! sudo cloudflared tunnel create "$TUNNEL_NAME" 2>&1 | tee /tmp/tunnel-create.log; then
        error "Échec de la création du tunnel"
        cat /tmp/tunnel-create.log
        error_exit "Vérifiez vos permissions Cloudflare"
    fi

    # Extraire l'ID du tunnel
    CF_TUNNEL_ID=$(sudo cloudflared tunnel list | grep "$TUNNEL_NAME" | awk '{print $1}' | head -1)

    if [[ -z "$CF_TUNNEL_ID" ]]; then
        error_exit "Impossible d'extraire l'ID du tunnel"
    fi

    ok "Tunnel créé avec ID: ${CF_TUNNEL_ID}"

    # Demander le domaine
    echo ""
    read -p "Entrez votre domaine (ex: example.com ou subdomain.example.com): " CF_DOMAIN

    if [[ -z "$CF_DOMAIN" ]]; then
        error_exit "Domaine requis"
    fi

    # Configurer DNS
    log "Configuration DNS pour ${CF_DOMAIN}..."

    sudo cloudflared tunnel route dns "$TUNNEL_NAME" "$CF_DOMAIN" || warn "Configuration DNS manuelle peut être requise"
    sudo cloudflared tunnel route dns "$TUNNEL_NAME" "*.${CF_DOMAIN}" || warn "Wildcard DNS peut ne pas être supporté"

    ok "Configuration DNS terminée"

    # Créer configuration
    create_tunnel_config
    create_docker_compose
}

#############################################################################
# Setup manuel (Token)
#############################################################################

setup_manual() {
    echo ""
    log "🔧 Configuration manuelle..."
    echo ""

    cat << 'EOF'
📋 Instructions manuelles :

1. Accédez au Cloudflare Zero Trust Dashboard :
   https://one.dash.cloudflare.com/

2. Sélectionnez votre compte

3. Allez dans : Networks → Tunnels

4. Cliquez sur "Create a tunnel"

5. Choisissez "Cloudflared" comme connector

6. Donnez un nom au tunnel (ex: pi5-supabase)

7. Copiez le TOKEN qui s'affiche (commence par "eyJ...")

8. Configurez les routes publiques :
   • Public hostname: studio.VOTRE_DOMAINE.COM
     Service: http://supabase-studio:3000

   • Public hostname: api.VOTRE_DOMAINE.COM
     Service: http://supabase-kong:8000

EOF

    read -p "Appuyez sur Entrée quand vous avez copié le token..."

    # Demander le token
    echo ""
    read -sp "Collez votre Cloudflare Tunnel Token: " CF_TOKEN
    echo ""

    if [[ -z "$CF_TOKEN" ]]; then
        error_exit "Token requis"
    fi

    # Valider format token
    if [[ ! "$CF_TOKEN" =~ ^eyJ ]]; then
        error_exit "Format de token invalide (doit commencer par 'eyJ')"
    fi

    ok "Token reçu"

    # Extraire tunnel ID du token
    CF_TUNNEL_ID=$(echo "$CF_TOKEN" | cut -d'.' -f2 | base64 -d 2>/dev/null | jq -r '.t' 2>/dev/null || echo "")

    if [[ -z "$CF_TUNNEL_ID" ]]; then
        warn "Impossible d'extraire l'ID du tunnel depuis le token"
        read -p "Entrez manuellement l'ID du tunnel: " CF_TUNNEL_ID
    fi

    # Demander le domaine
    read -p "Entrez votre domaine principal (ex: example.com): " CF_DOMAIN

    if [[ -z "$CF_DOMAIN" ]]; then
        error_exit "Domaine requis"
    fi

    ok "Configuration manuelle complète"

    # Créer configuration
    create_tunnel_config_manual
    create_docker_compose_manual
}

#############################################################################
# Génération configuration tunnel (auto)
#############################################################################

create_tunnel_config() {
    log "Création de la configuration du tunnel..."

    mkdir -p "$CONFIG_DIR"

    cat > "${CONFIG_DIR}/config.yml" << EOF
tunnel: ${CF_TUNNEL_ID}
credentials-file: /etc/cloudflared/credentials.json

ingress:
  # Supabase Studio
  - hostname: studio.${CF_DOMAIN}
    service: http://supabase-studio:3000
    originRequest:
      noTLSVerify: true

  # Supabase API (Kong)
  - hostname: api.${CF_DOMAIN}
    service: http://supabase-kong:8000
    originRequest:
      noTLSVerify: true

  # Catch-all rule (required)
  - service: http_status:404
EOF

    ok "Configuration créée: ${CONFIG_DIR}/config.yml"

    # Copier credentials
    if [[ -f "/root/.cloudflared/${CF_TUNNEL_ID}.json" ]]; then
        sudo cp "/root/.cloudflared/${CF_TUNNEL_ID}.json" "${CONFIG_DIR}/credentials.json"
        sudo chmod 600 "${CONFIG_DIR}/credentials.json"
        ok "Credentials copiées"
    else
        warn "Credentials non trouvées, configuration manuelle peut être requise"
    fi
}

#############################################################################
# Génération configuration tunnel (manuel)
#############################################################################

create_tunnel_config_manual() {
    log "Création de la configuration du tunnel (mode manuel)..."

    mkdir -p "$CONFIG_DIR"

    # Avec token, on n'a pas besoin de config.yml complexe
    # Docker compose utilisera directement le token

    cat > "${CONFIG_DIR}/tunnel-info.txt" << EOF
Tunnel ID: ${CF_TUNNEL_ID}
Domain: ${CF_DOMAIN}
Token: ${CF_TOKEN}
Created: $(date)
EOF

    chmod 600 "${CONFIG_DIR}/tunnel-info.txt"

    ok "Informations tunnel sauvegardées"
}

#############################################################################
# Création Docker Compose
#############################################################################

create_docker_compose() {
    log "Création du docker-compose.yml..."

    cat > "${BASE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel --config /etc/cloudflared/config.yml run
    volumes:
      - ./config/config.yml:/etc/cloudflared/config.yml:ro
      - ./config/credentials.json:/etc/cloudflared/credentials.json:ro
    networks:
      - supabase_network
      - traefik_network
    depends_on:
      - dummy-wait

  # Service factice pour attendre que Supabase soit ready
  dummy-wait:
    image: alpine:latest
    container_name: cloudflared-wait
    command: sleep 5
    networks:
      - supabase_network

networks:
  supabase_network:
    external: true
    name: supabase_network
  traefik_network:
    external: true
    name: traefik_network
EOF

    ok "docker-compose.yml créé"
}

create_docker_compose_manual() {
    log "Création du docker-compose.yml (mode token)..."

    cat > "${BASE_DIR}/docker-compose.yml" << EOF
version: '3.8'

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel --no-autoupdate run --token ${CF_TOKEN}
    networks:
      - supabase_network
      - traefik_network

networks:
  supabase_network:
    external: true
    name: supabase_network
  traefik_network:
    external: true
    name: traefik_network
EOF

    ok "docker-compose.yml créé (mode token)"
}

#############################################################################
# Démarrage du tunnel
#############################################################################

start_tunnel() {
    log "Démarrage du Cloudflare Tunnel..."

    cd "$BASE_DIR"

    # Vérifier que les réseaux Supabase existent
    if ! docker network ls | grep -q "supabase_network"; then
        warn "Réseau supabase_network non trouvé"
        warn "Le tunnel pourra démarrer mais ne pourra pas communiquer avec Supabase"
        read -p "Continuer quand même ? [y/N]: " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || error_exit "Installation annulée"
    fi

    docker compose up -d

    sleep 5

    # Vérifier status
    if docker ps | grep -q "cloudflared-tunnel"; then
        ok "Tunnel démarré avec succès !"
    else
        error "Le tunnel n'a pas démarré correctement"
        log "Vérification des logs..."
        docker logs cloudflared-tunnel --tail 20
        error_exit "Consultez les logs ci-dessus"
    fi
}

#############################################################################
# Tests et validation
#############################################################################

run_tests() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}🧪 Tests de connectivité${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Attendre que le tunnel se connecte
    log "Attente de la connexion au tunnel (30s)..."
    sleep 30

    # Test Studio
    log "Test accès Studio via Cloudflare..."
    if curl -sf -o /dev/null "https://studio.${CF_DOMAIN}" --max-time 10; then
        ok "✅ Studio accessible via https://studio.${CF_DOMAIN}"
    else
        warn "⚠️  Studio pas encore accessible (peut prendre quelques minutes)"
    fi

    # Test API
    log "Test accès API via Cloudflare..."
    if curl -sf -o /dev/null "https://api.${CF_DOMAIN}/rest/v1/" --max-time 10; then
        ok "✅ API accessible via https://api.${CF_DOMAIN}"
    else
        warn "⚠️  API pas encore accessible (peut prendre quelques minutes)"
    fi

    # Logs tunnel
    log "Logs du tunnel (dernières 10 lignes):"
    docker logs cloudflared-tunnel --tail 10

    echo ""
}

#############################################################################
# Rapport final
#############################################################################

generate_report() {
    local report_file="${BASE_DIR}/docs/cloudflare-tunnel-report.md"

    mkdir -p "${BASE_DIR}/docs"

    log "Génération du rapport..."

    cat > "$report_file" << EOF
# ☁️ Rapport Cloudflare Tunnel

**Date**: $(date '+%Y-%m-%d %H:%M:%S')
**Option**: 2 - Cloudflare Tunnel

---

## 📊 Configuration

| Paramètre | Valeur |
|-----------|--------|
| **Tunnel ID** | \`${CF_TUNNEL_ID}\` |
| **Tunnel Name** | \`${TUNNEL_NAME}\` |
| **Domaine** | \`${CF_DOMAIN}\` |
| **Container** | \`cloudflared-tunnel\` |

---

## 🌐 URLs d'accès

### Production (via Cloudflare)

- **Studio** : https://studio.${CF_DOMAIN}
- **API** : https://api.${CF_DOMAIN}/rest/v1/

### Local (direct)

- **Studio** : http://${LOCAL_IP}:3000
- **API** : http://${LOCAL_IP}:8000

---

## 🔒 Sécurité

✅ **Avantages Cloudflare Tunnel** :
- Aucun port ouvert sur votre routeur
- IP publique cachée derrière Cloudflare
- Protection DDoS gratuite
- Certificats SSL automatiques
- Logs et analytics dans le dashboard

⚠️ **Points d'attention** :
- Cloudflare proxy tout le trafic (pas de chiffrement bout-en-bout)
- Latence accrue depuis réseau local (+20-50ms)
- Dépendance au service Cloudflare

---

## 🛠️ Gestion du tunnel

### Démarrer le tunnel
\`\`\`bash
cd ${BASE_DIR}
docker compose up -d
\`\`\`

### Arrêter le tunnel
\`\`\`bash
docker compose down
\`\`\`

### Logs en temps réel
\`\`\`bash
docker logs -f cloudflared-tunnel
\`\`\`

### Status
\`\`\`bash
docker ps --filter "name=cloudflared"
\`\`\`

---

## 🔧 Troubleshooting

### Le tunnel ne démarre pas
1. Vérifier les logs : \`docker logs cloudflared-tunnel\`
2. Vérifier les credentials : \`ls -l ${CONFIG_DIR}/\`
3. Tester l'authentification : \`cloudflared tunnel info ${TUNNEL_NAME}\`

### Erreur 502 Bad Gateway
1. Vérifier que Supabase tourne : \`docker ps --filter "name=supabase"\`
2. Vérifier les réseaux Docker : \`docker network ls\`
3. Reconnecter cloudflared : \`docker compose restart\`

### DNS ne résout pas
1. Attendre 5-10 minutes (propagation DNS)
2. Vérifier dans Cloudflare Dashboard → DNS
3. Ajouter manuellement les entrées CNAME si besoin

---

## 📚 Ressources

- **Dashboard Cloudflare** : https://one.dash.cloudflare.com/
- **Documentation officielle** : https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
- **Status Cloudflare** : https://www.cloudflarestatus.com/

---

**Généré par**: pi5-setup External Access Option 2
EOF

    ok "Rapport généré: ${report_file}"
}

#############################################################################
# Main
#############################################################################

main() {
    banner

    check_prerequisites
    install_cloudflared
    interactive_setup
    start_tunnel
    run_tests
    generate_report

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}║     ✅ Cloudflare Tunnel configuré avec succès !               ║${NC}"
    echo -e "${GREEN}║                                                                ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}🌐 Accès via Cloudflare :${NC}"
    echo -e "   https://studio.${CF_DOMAIN}"
    echo -e "   https://api.${CF_DOMAIN}"
    echo ""
    echo -e "${CYAN}📖 Dashboard Cloudflare :${NC}"
    echo -e "   https://one.dash.cloudflare.com/"
    echo ""
    echo -e "${CYAN}📊 Rapport complet :${NC}"
    echo -e "   ${BASE_DIR}/docs/cloudflare-tunnel-report.md"
    echo ""
}

main "$@"
