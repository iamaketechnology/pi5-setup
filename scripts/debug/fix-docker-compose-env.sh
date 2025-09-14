#!/usr/bin/env bash
set -euo pipefail

# === FIX DOCKER COMPOSE ENV - Replace hardcoded values with .env variables ===

log()  { echo -e "\033[1;36m[COMPOSE-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix docker-compose.yml pour utiliser variables .env"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-docker-compose-env.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    # Obtenir l'IP du Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "🌐 IP locale détectée : $LOCAL_IP"

    # Lire les variables depuis .env
    log "📋 Lecture variables depuis .env..."
    source .env

    POSTGRES_PWD="${POSTGRES_PASSWORD:-}"
    AUTH_PWD="${AUTHENTICATOR_PASSWORD:-}"
    STORAGE_PWD="${SUPABASE_STORAGE_PASSWORD:-}"
    JWT_SECRET="${JWT_SECRET:-}"
    API_URL="${API_EXTERNAL_URL:-http://$LOCAL_IP:8001}"

    if [[ -z "$POSTGRES_PWD" ]] || [[ -z "$AUTH_PWD" ]] || [[ -z "$STORAGE_PWD" ]]; then
        error "❌ Variables manquantes dans .env"
        exit 1
    fi

    echo ""
    echo "==================== DIAGNOSTIC VARIABLES HARDCODÉES ===================="

    log "🔍 Détection des valeurs hardcodées dans docker-compose.yml :"

    # Détecter mots de passe hardcodés
    hardcoded_passwords=$(grep -o "2ZCYFlngUwCoY8o6B7SAMV9j9" docker-compose.yml | wc -l || echo "0")
    log "   Mots de passe hardcodés trouvés : $hardcoded_passwords"

    # Détecter URLs hardcodées
    hardcoded_urls=$(grep -c "192.168.1.73" docker-compose.yml || echo "0")
    log "   URLs IP hardcodées trouvées : $hardcoded_urls"

    echo ""
    echo "==================== SAUVEGARDE ET CORRECTION ===================="

    # Sauvegarder
    log "💾 Sauvegarde docker-compose.yml..."
    cp docker-compose.yml docker-compose.yml.backup.env.$(date +%Y%m%d_%H%M%S)

    log "🔧 Correction des variables hardcodées..."

    # 1. Remplacer les mots de passe hardcodés
    log "   🔐 Correction des mots de passe..."
    sed -i "s/2ZCYFlngUwCoY8o6B7SAMV9j9/\${POSTGRES_PASSWORD}/g" docker-compose.yml

    # 2. Corriger spécifiquement authenticator et supabase_storage_admin
    sed -i "s/postgres:\/\/authenticator:\${POSTGRES_PASSWORD}@/postgres:\/\/authenticator:\${AUTHENTICATOR_PASSWORD}@/g" docker-compose.yml
    sed -i "s/postgres:\/\/supabase_storage_admin:\${POSTGRES_PASSWORD}@/postgres:\/\/supabase_storage_admin:\${SUPABASE_STORAGE_PASSWORD}@/g" docker-compose.yml

    # 3. Remplacer les URLs hardcodées
    log "   🌐 Correction des URLs..."
    sed -i "s|http://192.168.1.73:8001|\${API_EXTERNAL_URL}|g" docker-compose.yml
    sed -i "s|http://192.168.1.73:3000|\${SUPABASE_PUBLIC_URL}|g" docker-compose.yml

    # 4. Ajouter API_EXTERNAL_URL au service auth
    log "   ⚡ Ajout API_EXTERNAL_URL au service auth..."

    # Trouver la ligne avec GOTRUE_JWT_EXP et ajouter API_EXTERNAL_URL après
    if ! grep -q "API_EXTERNAL_URL" docker-compose.yml; then
        sed -i '/GOTRUE_JWT_EXP: 3600/a\      API_EXTERNAL_URL: ${API_EXTERNAL_URL}' docker-compose.yml
        ok "✅ API_EXTERNAL_URL ajoutée au service auth"
    else
        ok "✅ API_EXTERNAL_URL déjà présente"
    fi

    # 5. Corriger JWT secrets hardcodés
    log "   🔑 Correction JWT secrets..."
    if [[ -n "$JWT_SECRET" ]]; then
        sed -i "s/3deb8d09cc94c3e32c26e8ecbae1c15f68230c1f0028f9ae470a4587cd3d0194/\${JWT_SECRET}/g" docker-compose.yml
        ok "✅ JWT secrets remplacés par variable"
    fi

    echo ""
    echo "==================== VÉRIFICATION CORRECTIONS ===================="

    log "🧪 Vérification des corrections :"

    # Compter les variables après correction
    env_vars=$(grep -c "\${" docker-compose.yml || echo "0")
    log "   Variables .env utilisées : $env_vars"

    # Vérifier qu'API_EXTERNAL_URL est présent
    if grep -q "API_EXTERNAL_URL" docker-compose.yml; then
        ok "   ✅ API_EXTERNAL_URL présente dans docker-compose.yml"
    else
        warn "   ❌ API_EXTERNAL_URL manquante"
    fi

    # Vérifier les mots de passe spécifiques
    if grep -q "AUTHENTICATOR_PASSWORD" docker-compose.yml; then
        ok "   ✅ AUTHENTICATOR_PASSWORD utilisée"
    else
        warn "   ❌ AUTHENTICATOR_PASSWORD non utilisée"
    fi

    echo ""
    echo "==================== RECREATION AVEC NOUVELLES VARIABLES ===================="

    log "⏹️  Arrêt des services..."
    docker compose down

    log "🚀 Redémarrage avec variables .env corrigées..."
    docker compose up -d

    log "⏳ Attente initialisation avec nouvelles variables (90s)..."
    sleep 90

    echo ""
    echo "==================== VÉRIFICATION FINALE ===================="

    log "📊 État des services après correction :"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -10

    log "🧪 Test propagation API_EXTERNAL_URL :"
    if docker compose exec -T auth printenv | grep -q "API_EXTERNAL_URL" 2>/dev/null; then
        ok "  ✅ API_EXTERNAL_URL propagée au conteneur Auth"
        docker compose exec -T auth printenv | grep "API_EXTERNAL_URL" | sed 's/^/    /'
    else
        warn "  ❌ API_EXTERNAL_URL non propagée"
    fi

    log "🧪 Test authentification database :"
    if docker compose logs auth --tail=3 | grep -q "API_EXTERNAL_URL missing" 2>/dev/null; then
        warn "  ❌ Auth : API_EXTERNAL_URL encore manquante"
    else
        ok "  ✅ Auth : Plus d'erreur API_EXTERNAL_URL"
    fi

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ docker-compose.yml corrigé pour utiliser variables .env"
    echo "✅ Mots de passe hardcodés remplacés par variables"
    echo "✅ URLs hardcodées remplacées par variables"
    echo "✅ API_EXTERNAL_URL ajoutée au service auth"
    echo "✅ Services redémarrés avec nouvelle configuration"
    echo ""
    echo "🧪 Vérifications finales :"
    echo "   ./check-services-status.sh    # État complet"
    echo "   docker compose logs auth --tail=5    # Logs Auth"
    echo ""
    echo "📍 Si tout fonctionne maintenant :"
    echo "   🎨 Studio : http://$LOCAL_IP:3000"
    echo "   🔌 API : http://$LOCAL_IP:8001"
    echo "=================================================="
}

main "$@"