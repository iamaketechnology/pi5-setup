#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Portainer API Token Generator for Raspberry Pi 5
# =============================================================================
# Purpose: Create API access token for Portainer (for Homepage widget integration)
# Architecture: ARM64 (Raspberry Pi 5)
# Author: PI5-SETUP Project
# Compatibility: Raspberry Pi OS Bookworm (64-bit)
# Estimated Runtime: 10 seconds
# =============================================================================
#
# USAGE:
#   sudo bash create-portainer-token.sh
#
# REQUIREMENTS:
#   - Portainer container running
#   - jq installed
#   - Valid Portainer admin credentials
#
# OUTPUT:
#   - Generates API token
#   - Optionally updates Homepage config
#   - Restarts Homepage container
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[PORTAINER]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]    \033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]      \033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]   \033[0m $*"; exit 1; }

# =============================================================================
# CONFIGURATION
# =============================================================================

PORTAINER_URL="http://localhost:8080"
HOMEPAGE_CONFIG="/home/pi/stacks/homepage/config/services.yaml"

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

check_requirements() {
    log "Vérification des prérequis..."

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        error "jq n'est pas installé. Installation: sudo apt-get install -y jq"
    fi

    # Check if Portainer is running
    if ! docker ps --format '{{.Names}}' | grep -q '^portainer$'; then
        error "Container Portainer non trouvé. Est-il déployé ?"
    fi

    # Check if Portainer API is accessible
    if ! curl -s -f "${PORTAINER_URL}/api/status" > /dev/null; then
        error "API Portainer non accessible sur ${PORTAINER_URL}"
    fi

    ok "Tous les prérequis sont satisfaits"
}

# =============================================================================
# TOKEN GENERATION
# =============================================================================

prompt_credentials() {
    log "Entrez vos identifiants Portainer"
    echo

    # Prompt for username
    read -p "Username [maketech]: " USERNAME
    USERNAME=${USERNAME:-maketech}

    # Prompt for password (hidden)
    echo -n "Password: "
    read -s PASSWORD
    echo

    if [[ -z "$PASSWORD" ]]; then
        error "Le mot de passe ne peut pas être vide"
    fi

    echo
}

authenticate_portainer() {
    log "Authentification..."

    # Authenticate and get JWT token
    AUTH_RESPONSE=$(curl -s -X POST "${PORTAINER_URL}/api/auth" \
        -H "Content-Type: application/json" \
        -d "{\"Username\":\"${USERNAME}\",\"Password\":\"${PASSWORD}\"}")

    JWT=$(echo "$AUTH_RESPONSE" | jq -r '.jwt // empty')

    if [[ -z "$JWT" || "$JWT" == "null" ]]; then
        error "Authentification échouée. Vérifiez vos identifiants."
    fi

    ok "Authentification réussie"
}

get_user_id() {
    log "Récupération des informations utilisateur..."

    USER_ID=$(curl -s "${PORTAINER_URL}/api/users" \
        -H "Authorization: Bearer ${JWT}" | jq -r '.[0].Id // empty')

    if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
        error "Impossible de récupérer l'ID utilisateur"
    fi

    ok "User ID: ${USER_ID}"
}

create_api_token() {
    log "Création du token API..."

    TOKEN_RESPONSE=$(curl -s -X POST "${PORTAINER_URL}/api/users/${USER_ID}/tokens" \
        -H "Authorization: Bearer ${JWT}" \
        -H "Content-Type: application/json" \
        -d "{\"description\":\"homepage-widget\",\"password\":\"${PASSWORD}\"}")

    ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.rawAPIKey // empty')

    if [[ -z "$ACCESS_TOKEN" || "$ACCESS_TOKEN" == "null" ]]; then
        error "Échec de la création du token: $(echo "$TOKEN_RESPONSE" | jq -r '.message // "Unknown error"')"
    fi

    ok "Token créé avec succès"
}

# =============================================================================
# HOMEPAGE INTEGRATION
# =============================================================================

update_homepage_config() {
    if [[ ! -f "$HOMEPAGE_CONFIG" ]]; then
        warn "Configuration Homepage non trouvée: ${HOMEPAGE_CONFIG}"
        warn "Vous devrez ajouter le token manuellement"
        return
    fi

    log "Mise à jour de la configuration Homepage..."

    # Get Portainer endpoint ID
    ENDPOINT_ID=$(curl -s "${PORTAINER_URL}/api/endpoints" \
        -H "X-API-Key: ${ACCESS_TOKEN}" | jq -r '.[0].Id // 1')

    # Backup config
    cp "${HOMEPAGE_CONFIG}" "${HOMEPAGE_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"

    # Check if Portainer widget section exists
    if grep -q "type: portainer" "${HOMEPAGE_CONFIG}"; then
        # Update existing widget configuration
        sed -i "/type: portainer/,/key:/s|key:.*|key: ${ACCESS_TOKEN}|" "${HOMEPAGE_CONFIG}"
        sed -i "/type: portainer/,/env:/s|env:.*|env: ${ENDPOINT_ID}|" "${HOMEPAGE_CONFIG}"
        ok "Configuration Homepage mise à jour"
    else
        warn "Widget Portainer non trouvé dans la configuration"
        warn "Ajoutez manuellement le widget avec ce token"
    fi

    # Restart Homepage if container exists
    if docker ps --format '{{.Names}}' | grep -q '^homepage$'; then
        log "Redémarrage du container Homepage..."
        docker restart homepage > /dev/null 2>&1
        ok "Homepage redémarré"
    fi
}

# =============================================================================
# DISPLAY RESULTS
# =============================================================================

display_token() {
    echo
    log "==================================================================="
    log "  ✅ TOKEN API CRÉÉ AVEC SUCCÈS"
    log "==================================================================="
    echo
    ok "Token API:"
    echo
    echo "  ${ACCESS_TOKEN}"
    echo
    ok "Utilisez ce token pour:"
    echo
    echo "  • Widget Homepage (automatiquement configuré)"
    echo "  • API calls directs (Header: X-API-Key)"
    echo "  • Automation scripts"
    echo

    if [[ -f "$HOMEPAGE_CONFIG" ]] && grep -q "$ACCESS_TOKEN" "$HOMEPAGE_CONFIG"; then
        ok "Configuration Homepage:"
        echo
        echo "  📍 URL: http://$(hostname -I | awk '{print $1}'):3001"
        echo "  🔄 Rechargez la page pour voir le widget Portainer"
        echo
    fi

    log "==================================================================="
}

# =============================================================================
# MAIN SCRIPT
# =============================================================================

main() {
    log "==================================================================="
    log "  Générateur de Token API Portainer"
    log "==================================================================="
    echo

    check_requirements
    echo

    prompt_credentials
    authenticate_portainer
    echo

    get_user_id
    echo

    create_api_token
    echo

    update_homepage_config

    display_token
}

# Run main function
main "$@"
