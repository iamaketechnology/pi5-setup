#!/usr/bin/env bash
#
# Ollama + Open WebUI Deployment Script - Phase 21
# LLM Self-Hosted (ChatGPT alternative) avec interface Web
#
# Sources officielles :
# - Ollama: https://github.com/ollama/ollama
# - Open WebUI: https://github.com/open-webui/open-webui
#
# Ce script est IDEMPOTENT : peut être exécuté plusieurs fois sans problème

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
source "${PROJECT_ROOT}/common-scripts/lib.sh"

STACK_NAME="ollama"
STACK_DIR="${HOME}/stacks/${STACK_NAME}"
COMPOSE_FILE="${STACK_DIR}/docker-compose.yml"
ENV_FILE="${STACK_DIR}/.env"
MODELS_DIR="${HOME}/data/ollama/models"

TRAEFIK_ENV="${HOME}/stacks/traefik/.env"
TRAEFIK_SCENARIO="none"

#######################
# FONCTIONS
#######################

check_requirements() {
    log_info "Vérification configuration requise..."

    # Check RAM (minimum 8GB recommandé)
    local total_ram
    total_ram=$(free -g | awk '/^Mem:/{print $2}')

    if [[ ${total_ram} -lt 8 ]]; then
        log_warn "⚠️  RAM détectée : ${total_ram}GB"
        log_warn "   Recommandé : 8GB minimum pour LLM"
        echo ""
        echo "Vous pouvez continuer mais les performances seront limitées."
        echo "Utilisez des modèles légers (TinyLlama, Phi-2)."
        echo ""
        read -p "Continuer ? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    else
        log_success "RAM : ${total_ram}GB ✓"
    fi

    # Check architecture
    local arch
    arch=$(uname -m)
    if [[ "${arch}" != "aarch64" ]] && [[ "${arch}" != "arm64" ]]; then
        log_error "Architecture non supportée : ${arch}"
        log_warn "Ollama nécessite ARM64 (aarch64)"
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
version: '3.8'

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

    # Ajouter Traefik si détecté
    if [[ "${TRAEFIK_SCENARIO}" != "none" ]]; then
        cat >> "${COMPOSE_FILE}" <<'EOF'

networks:
  default:
    name: ollama-network
  traefik-network:
    external: true
EOF

        sed -i '' '/open-webui:/a\
    networks:\
      - default\
      - traefik-network\
    labels:\
      - "traefik.enable=true"\
      - "traefik.http.services.ollama-ui.loadbalancer.server.port=8080"
' "${COMPOSE_FILE}"

        case "${TRAEFIK_SCENARIO}" in
            duckdns)
                sed -i '' '/traefik.http.services.ollama-ui/a\
      - "traefik.http.routers.ollama-ui.rule=Host(`ai.'"${DUCKDNS_SUBDOMAIN}"'.duckdns.org`)"\
      - "traefik.http.routers.ollama-ui.entrypoints=websecure"\
      - "traefik.http.routers.ollama-ui.tls.certresolver=letsencrypt"
' "${COMPOSE_FILE}"
                ;;
            cloudflare)
                sed -i '' '/traefik.http.services.ollama-ui/a\
      - "traefik.http.routers.ollama-ui.rule=Host(`ai.'"${DOMAIN}"'`)"\
      - "traefik.http.routers.ollama-ui.entrypoints=websecure"\
      - "traefik.http.routers.ollama-ui.tls.certresolver=letsencrypt"
' "${COMPOSE_FILE}"
                ;;
        esac
    fi
}

download_recommended_models() {
    log_info "Téléchargement modèles recommandés pour Pi 5..."

    echo ""
    echo "Modèles disponibles :"
    echo "  1. tinyllama:1.1b    (600MB)  - Ultra-rapide, questions simples"
    echo "  2. phi3:3.8b         (2.3GB)  - Meilleur équilibre qualité/vitesse ⭐"
    echo "  3. deepseek-coder:1.3b (800MB) - Spécialisé code"
    echo "  4. Aucun (télécharger manuellement plus tard)"
    echo ""
    read -p "Choisir modèle à télécharger (1-4) [2]: " choice
    choice=${choice:-2}

    local model
    case ${choice} in
        1) model="tinyllama:1.1b" ;;
        2) model="phi3:3.8b" ;;
        3) model="deepseek-coder:1.3b" ;;
        4)
            log_info "Aucun modèle téléchargé"
            return
            ;;
        *)
            log_warn "Choix invalide, utilisation phi3:3.8b"
            model="phi3:3.8b"
            ;;
    esac

    log_info "Téléchargement ${model} (ceci peut prendre 5-10 min)..."
    docker exec ollama ollama pull "${model}"
    log_success "Modèle ${model} téléchargé !"
}

update_homepage() {
    local homepage_config="${HOME}/stacks/homepage/config/services.yaml"
    [[ ! -f "${homepage_config}" ]] && return

    if grep -q "Ollama:" "${homepage_config}"; then
        return
    fi

    cat >> "${homepage_config}" <<EOF

- Intelligence Artificielle:
    - Ollama Chat:
        href: http://raspberrypi.local:3000
        description: LLM Local (ChatGPT alternative)
        icon: https://ollama.com/public/ollama.png
EOF

    docker restart homepage >/dev/null 2>&1 || true
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
    print_header "Ollama + Open WebUI - LLM Self-Hosted"

    log_info "Installation Phase 21 - Intelligence Artificielle..."
    echo ""

    check_requirements

    mkdir -p "${STACK_DIR}" "${MODELS_DIR}"
    cd "${STACK_DIR}"

    detect_traefik_scenario
    create_env
    create_compose

    log_info "Déploiement Ollama + Open WebUI..."
    docker-compose up -d

    log_info "Attente démarrage services (60s)..."
    sleep 60

    if docker ps | grep -q "ollama"; then
        log_success "Ollama démarré !"
    else
        log_error "Échec démarrage Ollama"
        docker-compose logs
        exit 1
    fi

    # Télécharger modèle
    download_recommended_models

    # Intégrations
    update_homepage
    create_usage_guide

    echo ""
    print_section "Ollama + Open WebUI Installé !"
    echo ""
    echo "🤖 Accès Interface :"
    echo "   http://raspberrypi.local:3000"
    echo ""
    echo "🔧 API Ollama :"
    echo "   http://raspberrypi.local:11434"
    echo ""
    echo "📋 Guide complet :"
    echo "   cat ${STACK_DIR}/USAGE.md"
    echo ""
    echo "📊 Ressources :"
    echo "   RAM : ~2-4 GB (selon modèle chargé)"
    echo "   Modèles : ${MODELS_DIR}"
    echo ""
    echo "💡 Prochaines étapes :"
    echo "   1. Ouvrir http://raspberrypi.local:3000"
    echo "   2. Créer compte admin"
    echo "   3. Sélectionner modèle et commencer à chatter !"
    echo ""
    echo "🔧 Télécharger plus de modèles :"
    echo "   docker exec ollama ollama pull <model-name>"
    echo "   Liste : https://ollama.com/library"
    echo ""

    log_success "Installation terminée !"
}

main "$@"
