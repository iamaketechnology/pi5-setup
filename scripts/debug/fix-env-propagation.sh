#!/usr/bin/env bash
set -euo pipefail

# === FIX ENV PROPAGATION - Variables .env non propagées aux conteneurs ===

log()  { echo -e "\033[1;36m[ENV-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix propagation variables .env vers conteneurs Supabase"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-env-propagation.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    # Obtenir l'IP du Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "🌐 IP locale détectée : $LOCAL_IP"

    echo ""
    echo "==================== DIAGNOSTIC VARIABLES ENV ===================="

    log "🔍 Variables critiques dans .env :"
    if grep -E "(API_EXTERNAL_URL|AUTHENTICATOR_PASSWORD|SUPABASE_STORAGE_PASSWORD)" .env; then
        ok "✅ Variables présentes dans .env"
    else
        warn "❌ Variables manquantes dans .env"
    fi

    echo ""
    log "🔍 Variables dans docker-compose.yml :"
    if grep -q "API_EXTERNAL_URL" docker-compose.yml; then
        ok "✅ API_EXTERNAL_URL référencée dans docker-compose.yml"
    else
        warn "❌ API_EXTERNAL_URL non référencée dans docker-compose.yml"
    fi

    echo ""
    echo "==================== TEST VARIABLES EN COURS ===================="

    log "🧪 Test variables dans conteneur Auth :"
    if docker compose exec -T auth printenv | grep -E "(API_EXTERNAL_URL)" | head -2; then
        ok "✅ Variables propagées au conteneur Auth"
    else
        warn "❌ Variables NON propagées au conteneur Auth"
        log "🔧 Recreation nécessaire pour propager les variables"
    fi

    echo ""
    echo "==================== CORRECTION PROPAGATION ===================="

    # Sauvegarder fichiers
    log "💾 Sauvegarde des fichiers..."
    cp .env .env.backup.propagation.$(date +%Y%m%d_%H%M%S)
    cp docker-compose.yml docker-compose.yml.backup.propagation.$(date +%Y%m%d_%H%M%S)

    # Vérifier et corriger les variables manquantes dans .env
    log "🔧 Vérification et correction variables .env..."

    if ! grep -q "^API_EXTERNAL_URL=" .env; then
        echo "API_EXTERNAL_URL=http://$LOCAL_IP:8001" >> .env
        ok "✅ API_EXTERNAL_URL ajoutée"
    fi

    if ! grep -q "^SUPABASE_PUBLIC_URL=" .env; then
        echo "SUPABASE_PUBLIC_URL=http://$LOCAL_IP:8001" >> .env
        ok "✅ SUPABASE_PUBLIC_URL ajoutée"
    fi

    # S'assurer que les mots de passe sont présents
    if ! grep -q "^AUTHENTICATOR_PASSWORD=" .env; then
        AUTH_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
        echo "AUTHENTICATOR_PASSWORD=$AUTH_PWD" >> .env
        ok "✅ AUTHENTICATOR_PASSWORD générée"
    fi

    if ! grep -q "^SUPABASE_STORAGE_PASSWORD=" .env; then
        STORAGE_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
        echo "SUPABASE_STORAGE_PASSWORD=$STORAGE_PWD" >> .env
        ok "✅ SUPABASE_STORAGE_PASSWORD générée"
    fi

    echo ""
    echo "==================== RECREATION FORCÉE POUR PROPAGATION ===================="

    log "⏹️  Arrêt complet avec suppression volumes..."
    docker compose down --volumes --remove-orphans

    log "🧹 Nettoyage cache Docker pour forcer re-pull..."
    docker system prune -f >/dev/null 2>&1 || true

    log "🚀 Recreation avec propagation forcée des variables..."
    docker compose up -d --force-recreate --pull missing

    log "⏳ Attente propagation variables et initialisation (2 minutes)..."
    for i in {120..1}; do
        if [[ $((i % 20)) -eq 0 ]]; then
            echo -n "⏳ $i secondes restantes... "
            # Test si variables sont propagées
            if docker compose exec -T auth printenv | grep -q "API_EXTERNAL_URL" 2>/dev/null; then
                echo "(Variables propagées)"
            else
                echo "(propagation...)"
            fi
        fi
        sleep 1
    done

    echo ""
    echo "==================== VÉRIFICATION PROPAGATION ===================="

    log "🧪 Test propagation variables dans conteneurs :"

    # Test Auth
    if docker compose exec -T auth printenv | grep -E "(API_EXTERNAL_URL)" >/dev/null 2>&1; then
        ok "  ✅ Auth : Variables propagées"
        docker compose exec -T auth printenv | grep -E "(API_EXTERNAL_URL)" | head -1 | sed 's/^/    /'
    else
        warn "  ❌ Auth : Variables NON propagées"
    fi

    # Test Storage
    if docker compose exec -T storage printenv | grep -E "(SUPABASE_STORAGE_PASSWORD|API_EXTERNAL_URL)" >/dev/null 2>&1; then
        ok "  ✅ Storage : Variables propagées"
    else
        warn "  ❌ Storage : Variables NON propagées"
    fi

    # Test Rest
    if docker compose exec -T rest printenv | grep -E "(AUTHENTICATOR_PASSWORD)" >/dev/null 2>&1; then
        ok "  ✅ Rest : Variables propagées"
    else
        warn "  ❌ Rest : Variables NON propagées"
    fi

    echo ""
    log "📊 État final des conteneurs :"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -10

    echo ""
    echo "==================== RÉSULTATS PROPAGATION ===================="
    echo "✅ Variables .env vérifiées et corrigées"
    echo "✅ Recreation forcée avec --force-recreate"
    echo "✅ Propagation des variables d'environnement"
    echo ""
    echo "🧪 Vérifications finales :"
    echo "   ./check-services-status.sh    # État complet services"
    echo "   docker compose logs auth --tail=5      # Logs Auth"
    echo "   docker compose logs storage --tail=5   # Logs Storage"
    echo ""
    echo "📍 Si services fonctionnent maintenant :"
    echo "   🎨 Studio : http://$LOCAL_IP:3000"
    echo "   🔌 API : http://$LOCAL_IP:8001"
    echo "=================================================="
}

main "$@"