#!/usr/bin/env bash
set -euo pipefail

# === FIX URL MISMATCH - localhost vers IP réelle ===

log()  { echo -e "\033[1;36m[URL-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix URLs localhost vers IP réelle dans configuration Supabase"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-url-mismatch.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    # Obtenir l'IP du Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "🌐 IP locale détectée : $LOCAL_IP"

    echo ""
    echo "==================== ANALYSE URLs ACTUELLES ===================="

    log "🔍 URLs dans .env :"
    grep -E "(API_EXTERNAL_URL|SUPABASE_PUBLIC_URL|localhost)" .env || warn "Pas d'URLs trouvées dans .env"

    log "🔍 URLs dans docker-compose.yml :"
    grep -E "(localhost:8000|localhost)" docker-compose.yml | head -5 || warn "Pas de localhost trouvé dans docker-compose.yml"

    echo ""
    echo "==================== CORRECTION URLs ===================="

    # Sauvegarder fichiers
    log "💾 Sauvegarde des fichiers de configuration..."
    cp .env .env.backup.urls.$(date +%Y%m%d_%H%M%S)
    cp docker-compose.yml docker-compose.yml.backup.urls.$(date +%Y%m%d_%H%M%S)

    # Corriger .env
    log "🔧 Correction des URLs dans .env..."

    # Remplacer localhost:8000 par IP:8001
    if grep -q "localhost:8000" .env; then
        sed -i "s/localhost:8000/${LOCAL_IP}:8001/g" .env
        ok "✅ localhost:8000 → ${LOCAL_IP}:8001 dans .env"
    fi

    # Remplacer localhost:8001 par IP:8001 (au cas où)
    if grep -q "localhost:8001" .env; then
        sed -i "s/localhost:8001/${LOCAL_IP}:8001/g" .env
        ok "✅ localhost:8001 → ${LOCAL_IP}:8001 dans .env"
    fi

    # Corriger docker-compose.yml
    log "🔧 Correction des URLs dans docker-compose.yml..."

    # Remplacer localhost:8000 par IP:8001
    if grep -q "localhost:8000" docker-compose.yml; then
        sed -i "s/localhost:8000/${LOCAL_IP}:8001/g" docker-compose.yml
        ok "✅ localhost:8000 → ${LOCAL_IP}:8001 dans docker-compose.yml"
    fi

    # Remplacer localhost:3000 par IP:3000
    if grep -q "localhost:3000" docker-compose.yml; then
        sed -i "s/localhost:3000/${LOCAL_IP}:3000/g" docker-compose.yml
        ok "✅ localhost:3000 → ${LOCAL_IP}:3000 dans docker-compose.yml"
    fi

    echo ""
    echo "==================== VÉRIFICATION CORRECTIONS ===================="

    log "📋 Nouvelles URLs dans .env :"
    grep -E "(API_EXTERNAL_URL|SUPABASE_PUBLIC_URL)" .env | head -5

    log "📋 Nouvelles URLs dans docker-compose.yml :"
    grep -E "${LOCAL_IP}:800[01]" docker-compose.yml | head -5 || warn "Pas d'URLs avec IP trouvées"

    echo ""
    echo "==================== REDÉMARRAGE SERVICES ===================="

    log "⏹️  Arrêt des services..."
    docker compose down

    log "🚀 Redémarrage avec URLs corrigées..."
    docker compose up -d

    # Attendre initialisation
    log "⏳ Attente initialisation des services (30s)..."
    sleep 30

    echo ""
    echo "==================== VÉRIFICATION FINALE ===================="

    log "🔍 État des services après correction :"
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -10

    # Test connectivité rapide
    log "🧪 Test connectivité rapide :"

    if curl -s -I "http://localhost:3000" >/dev/null 2>&1; then
        ok "  ✅ Studio accessible (localhost:3000)"
    else
        warn "  ⚠️  Studio non accessible (localhost:3000)"
    fi

    if curl -s -I "http://localhost:8001" >/dev/null 2>&1; then
        ok "  ✅ API Gateway accessible (localhost:8001)"
    else
        warn "  ⚠️  API Gateway non accessible (localhost:8001)"
    fi

    if curl -s -I "http://${LOCAL_IP}:3000" >/dev/null 2>&1; then
        ok "  ✅ Studio accessible depuis réseau (${LOCAL_IP}:3000)"
    else
        warn "  ⚠️  Studio non accessible depuis réseau (${LOCAL_IP}:3000)"
    fi

    if curl -s -I "http://${LOCAL_IP}:8001" >/dev/null 2>&1; then
        ok "  ✅ API Gateway accessible depuis réseau (${LOCAL_IP}:8001)"
    else
        warn "  ⚠️  API Gateway non accessible depuis réseau (${LOCAL_IP}:8001)"
    fi

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ URLs corrigées dans .env et docker-compose.yml"
    echo "✅ Services redémarrés avec nouvelle configuration"
    echo ""
    echo "📍 Nouvelles URLs d'accès :"
    echo "   🎨 Studio : http://${LOCAL_IP}:3000"
    echo "   🔌 API : http://${LOCAL_IP}:8001"
    echo ""
    echo "🧪 Vérifications recommandées :"
    echo "   ./check-services-status.sh    # État détaillé"
    echo "   ./test-api-connectivity.sh    # Test toutes APIs"
    echo "   ./check-supabase-health.sh    # Diagnostic complet"
    echo ""
    echo "🌐 Test dans navigateur :"
    echo "   http://${LOCAL_IP}:3000 (Studio)"
    echo "=================================================="
}

main "$@"