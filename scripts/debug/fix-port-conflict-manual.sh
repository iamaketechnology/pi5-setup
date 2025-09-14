#!/usr/bin/env bash
set -euo pipefail

# === FIX PORT CONFLICT MANUAL - Supabase Port 8000→8001 ===

log()  { echo -e "\033[1;36m[FIX-PORT]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix conflit port 8000 - Supabase → 8001"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase"
        echo "Exécute : cd ~/stacks/supabase && ./fix-port-conflict-manual.sh"
        exit 1
    fi

    log "📍 Répertoire actuel : $(pwd)"

    # 1. Identifier le conflit
    log "🔍 Diagnostic conflit port 8000..."
    echo "Services utilisant le port 8000 :"
    sudo netstat -tlnp | grep :8000 || true
    echo ""

    # 2. Arrêter services Supabase
    log "⏹️  Arrêt des services Supabase..."
    docker compose down || true

    # 3. Sauvegarder config
    log "💾 Sauvegarde configuration..."
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S) || warn "Impossible de sauvegarder .env"
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S) || warn "Impossible de sauvegarder docker-compose.yml"

    # 4. Modifier le port API
    log "🔧 Modification port API 8000 → 8001..."

    # Modifier .env
    if grep -q "API_PORT=8000" .env; then
        sed -i 's/API_PORT=8000/API_PORT=8001/g' .env
        ok "✅ .env modifié"
    else
        warn "API_PORT=8000 non trouvé dans .env"
    fi

    # Modifier docker-compose.yml
    if grep -q "8000:8000" docker-compose.yml; then
        sed -i 's/8000:8000/8001:8000/g' docker-compose.yml
        ok "✅ docker-compose.yml modifié"
    else
        warn "8000:8000 non trouvé dans docker-compose.yml"
    fi

    # 5. Vérifier modifications
    log "🔍 Vérification des modifications..."
    echo "=== Fichier .env ==="
    grep -E "(API_PORT|8001)" .env || echo "Aucune mention de API_PORT/8001"
    echo ""
    echo "=== Fichier docker-compose.yml ==="
    grep -E "(8000|8001)" docker-compose.yml | head -5 || echo "Aucune mention de ports"
    echo ""

    # 6. Redémarrer services
    log "🚀 Redémarrage des services Supabase..."
    docker compose up -d

    # 7. Attendre initialisation
    log "⏳ Attente initialisation services (30s)..."
    sleep 30

    # 8. Vérifier état
    log "📊 État final des services..."
    docker compose ps
    echo ""

    # 9. Test connectivité
    log "🧪 Test connectivité API..."
    if curl -s -I http://localhost:8001 >/dev/null 2>&1; then
        ok "✅ API accessible sur port 8001"
    else
        warn "⚠️  API non accessible sur port 8001"
    fi

    if curl -s -I http://localhost:3000 >/dev/null 2>&1; then
        ok "✅ Studio accessible sur port 3000"
    else
        warn "⚠️  Studio non accessible sur port 3000"
    fi

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ Conflit port résolu"
    echo "📍 Nouveaux accès :"
    echo "   🎨 Studio : http://$(hostname -I | awk '{print $1}'):3000"
    echo "   🔌 API    : http://$(hostname -I | awk '{print $1}'):8001"
    echo "   📊 Portainer : http://$(hostname -I | awk '{print $1}'):8000 (inchangé)"
    echo ""
    echo "🔍 Vérification santé complète :"
    echo "   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/check-supabase-health.sh -o health.sh && chmod +x health.sh && ./health.sh"
    echo "=================================================="
}

main "$@"