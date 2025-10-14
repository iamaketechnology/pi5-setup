#!/bin/bash
# =============================================================================
# Ollama + Open WebUI Deployment - Local LLM (ChatGPT Alternative)
# =============================================================================
# Version: 1.1.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash 01-ollama-deploy.sh
# =============================================================================
# Sources officielles :
# - Ollama: https://github.com/ollama/ollama
# - Open WebUI: https://github.com/open-webui/open-webui
# Ce script est IDEMPOTENT
# =============================================================================

set -euo pipefail

# === Logging functions ===
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }

# === Detect current user ===
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

# === Configuration ===
STACK_NAME="ollama"
STACK_DIR="${USER_HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"
MODELS_DIR="${USER_HOME}/data/ollama/models"

TRAEFIK_ENV="${USER_HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

# === Check root ===
if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être lancé avec sudo"
    exit 1
fi

#######################
# FONCTIONS
#######################

check_requirements() {
    log_info "Vérification configuration requise..."

    # Check RAM (minimum 8GB recommandé)
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 8 ]]; then
        log_warn "RAM détectée : ${total_ram}GB (recommandé: 8GB min)"
        log_warn "Utilisez des modèles légers (phi3:3.8b, tinyllama:1.1b)"
    else
        log_success "RAM : ${total_ram}GB ✓"
    fi

    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "${arch}" != "aarch64" ]] && [[ "${arch}" != "arm64" ]] && [[ "${arch}" != "x86_64" ]]; then
        log_error "Architecture non supportée : ${arch}"
        exit 1
    fi
    log_success "Architecture : ${arch} ✓"
}

detect_traefik_scenario() {
    [[ ! -f "${TRAEFIK_ENV}" ]] && return

    if grep -q "DUCKDNS_SUBDOMAIN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="duckdns"
        DUCKDNS_SUBDOMAIN=$(grep "^DUCKDNS_SUBDOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "CLOUDFLARE_API_TOKEN" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="cloudflare"
        DOMAIN=$(grep "^DOMAIN=" "${TRAEFIK_ENV}" | cut -d'=' -f2)
    elif grep -q "VPN_MODE" "${TRAEFIK_ENV}" 2>/dev/null; then
        TRAEFIK_SCENARIO="vpn"
    fi
}

create_env() {
    cat > "${ENV_FILE}" <<EOF
# Ollama + Open WebUI Configuration
# Généré le $(date)

# Ollama
OLLAMA_HOST=0.0.0.0:11434
OLLAMA_MODELS=${MODELS_DIR}

# Open WebUI
WEBUI_SECRET_KEY=$(openssl rand -hex 32)
WEBUI_NAME="Pi5 AI Chat"

# Timezone
TZ=Europe/Paris
EOF

    chmod 600 "${ENV_FILE}"
}

create_compose() {
    cat > "${COMPOSE_FILE}" <<'EOF'
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    volumes:
      - ${OLLAMA_MODELS}:/root/.ollama
    ports:
      - "11434:11434"
    environment:
      - OLLAMA_HOST=${OLLAMA_HOST}
    healthcheck:
      test: ["CMD", "ollama", "list"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    depends_on:
      - ollama
    ports:
      - "3000:8080"
    volumes:
      - ./data:/app/backend/data
    environment:
      - WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
      - WEBUI_NAME=${WEBUI_NAME}
      - OLLAMA_BASE_URL=http://ollama:11434
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF

    # Ajouter Traefik si détecté et réseau existe
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]] && docker network ls | grep -q "traefik_network"; then
        cat >> "${COMPOSE_FILE}" <<EOF
    networks:
      - default
      - traefik_network
    labels:
      - "traefik.enable=true"
      - "traefik.http.services.ollama-ui.loadbalancer.server.port=8080"
EOF

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.ollama-ui.rule=Host(\`ai.${DUCKDNS_SUBDOMAIN}.duckdns.org\`)"
      - "traefik.http.routers.ollama-ui.entrypoints=websecure"
      - "traefik.http.routers.ollama-ui.tls.certresolver=letsencrypt"
EOF
                ;;
            cloudflare)
                cat >> "${COMPOSE_FILE}" <<EOF
      - "traefik.http.routers.ollama-ui.rule=Host(\`ai.${DOMAIN}\`)"
      - "traefik.http.routers.ollama-ui.entrypoints=websecure"
      - "traefik.http.routers.ollama-ui.tls.certresolver=letsencrypt"
EOF
                ;;
        esac

        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  default:
    name: ollama_network
  traefik_network:
    external: true
EOF
    else
        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  default:
    name: ollama_network
EOF
    fi
}

download_recommended_models() {
    local model="${1:-phi3:3.8b}"

    log_info "Téléchargement modèle ${model}..."
    log_info "Ceci peut prendre 5-10 min selon modèle..."

    if docker exec ollama ollama pull "${model}"; then
        log_success "Modèle ${model} téléchargé !"
    else
        log_warn "Échec téléchargement. Téléchargez manuellement :"
        log_warn "  docker exec ollama ollama pull ${model}"
    fi
}

update_homepage() {
    local homepage_config="${USER_HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Ollama Chat:" "${homepage_config}"; then
        return
    fi

    log_info "Ajout Ollama au dashboard Homepage..."
    cat >> "${homepage_config}" <<EOF

- Intelligence Artificielle:
    - Ollama Chat:
        href: http://raspberrypi.local:3000
        description: LLM Local (ChatGPT alternative)
        icon: https://ollama.com/public/ollama.png
EOF

    docker restart homepage >/dev/null 2>&1 || true
    log_success "Ollama ajouté au dashboard"
}

create_usage_guide() {
    cat > "${STACK_DIR}/USAGE.md" <<EOF
# 🤖 Guide Ollama + Open WebUI

## Accès

**Interface Web** : http://raspberrypi.local:3000

Première connexion :
1. Créer compte admin
2. Choisir modèle dans menu déroulant
3. Commencer à chatter !

---

## 📥 Télécharger Modèles

### Via Interface Web
Settings → Models → Pull Model

### Via CLI
\`\`\`bash
docker exec -it ollama ollama pull <model-name>
\`\`\`

### Modèles Recommandés Pi 5

**Légers (< 1GB)** :
- \`tinyllama:1.1b\` - Questions simples, ultra-rapide
- \`deepseek-coder:1.3b\` - Code seulement

**Équilibrés (2-4GB)** :
- \`phi3:3.8b\` ⭐ - Meilleur rapport qualité/vitesse
- \`qwen2.5-coder:3b\` - Code + raisonnement

**Avancés (7GB+)** - Lent sur Pi 5
- \`llama3:7b\` - GPT-3.5 quality
- \`mistral:7b\` - Excellent français

---

## 💡 Exemples Prompts

### Génération Code
\`\`\`
Écris une fonction Python qui calcule la suite de Fibonacci
\`\`\`

### Résumé Documents
\`\`\`
Résume ce texte en 3 points clés : [coller texte]
\`\`\`

### Traduction
\`\`\`
Traduis en français : [texte anglais]
\`\`\`

### Debug Code
\`\`\`
Pourquoi ce code Python ne fonctionne pas ?
[coller code]
\`\`\`

---

## 🔧 Commandes Utiles

### Lister modèles installés
\`\`\`bash
docker exec ollama ollama list
\`\`\`

### Supprimer modèle
\`\`\`bash
docker exec ollama ollama rm <model-name>
\`\`\`

### Tester modèle en CLI
\`\`\`bash
docker exec -it ollama ollama run phi3:3.8b
\`\`\`

### Voir logs
\`\`\`bash
docker-compose logs -f ollama
docker-compose logs -f open-webui
\`\`\`

---

## 📊 Performance Pi 5

| Modèle | Taille | Tokens/sec | RAM Utilisée |
|--------|--------|------------|--------------|
| tinyllama:1.1b | 600MB | ~8-10 | ~1GB |
| phi3:3.8b | 2.3GB | ~3-5 | ~3GB |
| deepseek-coder:1.3b | 800MB | ~6-8 | ~1.5GB |
| llama3:7b | 4GB | ~1-2 | ~6GB |

---

## 🔗 API Ollama

L'API Ollama est compatible OpenAI :

\`\`\`bash
curl http://localhost:11434/api/generate -d '{
  "model": "phi3:3.8b",
  "prompt": "Pourquoi le ciel est bleu ?"
}'
\`\`\`

**Utiliser dans code** :
\`\`\`python
import requests

response = requests.post('http://localhost:11434/api/generate', json={
    'model': 'phi3:3.8b',
    'prompt': 'Explique Docker en 2 phrases'
})
\`\`\`

---

## 🚀 Intégrations

### Continue.dev (VSCode)
1. Installer extension Continue
2. Settings → Ollama
3. URL : http://localhost:11434
4. Modèle : phi3:3.8b

### n8n (Automatisation)
1. Node Ollama disponible
2. URL : http://ollama:11434
3. Créer workflows IA

---

## ⚠️ Troubleshooting

### Modèle ne répond pas
- Vérifier RAM disponible : \`free -h\`
- Redémarrer : \`docker-compose restart ollama\`

### Lent / Freeze
- Utiliser modèle plus léger
- Vérifier température CPU : \`vcgencmd measure_temp\`

### Erreur mémoire
- Limiter taille contexte dans Settings
- Fermer autres applications

---

## 📚 Ressources

- Modèles : https://ollama.com/library
- Documentation : https://github.com/ollama/ollama
- Open WebUI : https://docs.openwebui.com/
- Community : r/LocalLLaMA (Reddit)
EOF
}

#######################
# MAIN
#######################

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Ollama + Open WebUI - LLM Self-Hosted"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Vérifier si déjà installé (idempotent)
    if docker ps --format '{{.Names}}' | grep -q "^ollama$"; then
        log_success "Ollama déjà installé"
        docker ps --filter "name=ollama" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "🤖 Interface : http://raspberrypi.local:3000"
        echo "🔧 API : http://raspberrypi.local:11434"
        return 0
    fi

    check_requirements

    mkdir -p "${STACK_DIR}" "${MODELS_DIR}"
    cd "${STACK_DIR}"

    detect_traefik_scenario
    create_env
    create_compose

    log_info "Déploiement Ollama + Open WebUI..."
    log_warn "Images Docker (~3 GB) - Téléchargement en cours..."
    echo ""

    # Lancer en détaché
    docker compose up -d > /dev/null 2>&1 &

    log_success "Déploiement lancé en arrière-plan"
    log_info "Suivre progression :"
    log_info "  cd ${STACK_DIR} && docker compose logs -f"

    # Intégrations
    update_homepage
    create_usage_guide

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎉 OLLAMA + OPEN WEBUI EN COURS D'INSTALLATION"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "⏳ Les images Docker sont en cours de téléchargement (~3 GB)"
    echo "   Ceci peut prendre 10-20 min sur Raspberry Pi 5"
    echo ""
    echo "📊 Vérifier progression :"
    echo "   cd ${STACK_DIR}"
    echo "   docker compose logs -f"
    echo ""
    echo "🔍 Vérifier status :"
    echo "   docker ps"
    echo ""
    echo "🤖 Une fois prêt :"
    echo "   Interface : http://raspberrypi.local:3000"
    [[ "${TRAEFIK_SCENARIO}" == "duckdns" ]] && echo "   Public : https://ai.${DUCKDNS_SUBDOMAIN}.duckdns.org"
    [[ "${TRAEFIK_SCENARIO}" == "cloudflare" ]] && echo "   Public : https://ai.${DOMAIN}"
    echo "   API : http://raspberrypi.local:11434"
    echo ""
    echo "📋 Guide : ${STACK_DIR}/USAGE.md"
    echo ""
    echo "💡 Télécharger modèle (une fois Ollama UP) :"
    echo "   docker exec ollama ollama pull phi3:3.8b"
    echo "   Liste : https://ollama.com/library"
}

main "$@"
