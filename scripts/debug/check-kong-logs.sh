#!/usr/bin/env bash
set -euo pipefail

# === CHECK KONG LOGS - Diagnostic Kong spécifique ===

log()  { echo -e "\033[1;36m[KONG-LOGS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "📋 Vérification logs Kong détaillés"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]]; then
        error "❌ Pas dans le répertoire Supabase"
        echo "Exécute : cd ~/stacks/supabase && ./check-kong-logs.sh"
        exit 1
    fi

    echo "==================== ÉTAT KONG ===================="

    # État actuel de Kong
    if docker compose ps kong 2>/dev/null | grep -q "kong"; then
        status=$(docker compose ps kong --format "table {{.Status}}" | tail -n +2)
        log "🔍 État Kong : $status"

        if echo "$status" | grep -q "Up"; then
            ok "✅ Kong en fonctionnement"
        elif echo "$status" | grep -q "Restarting"; then
            warn "⚠️  Kong redémarre en boucle"
        else
            error "❌ Kong arrêté ou en erreur"
        fi
    else
        error "❌ Kong non trouvé"
        exit 1
    fi

    echo ""
    echo "==================== LOGS RÉCENTS ===================="

    # Logs récents (50 dernières lignes)
    log "📜 Logs Kong (50 dernières lignes) :"
    echo ""
    docker compose logs kong --tail=50 2>/dev/null || error "Impossible de lire les logs Kong"

    echo ""
    echo "==================== ANALYSE ERREURS ===================="

    # Rechercher des erreurs spécifiques
    log "🔍 Analyse des erreurs courantes :"

    # Vérifier erreur plugin
    if docker compose logs kong --tail=50 2>/dev/null | grep -q "plugin.*not installed\|plugin.*not found"; then
        error "❌ Erreur plugin détectée"
        echo "  → Solution : ./fix-kong-plugin-error.sh"
    else
        ok "✅ Pas d'erreur de plugin détectée"
    fi

    # Vérifier erreur de port
    if docker compose logs kong --tail=50 2>/dev/null | grep -q "bind.*failed\|address already in use"; then
        error "❌ Conflit de port détecté"
        echo "  → Solution : ./debug-port-conflict.sh"
    else
        ok "✅ Pas de conflit de port"
    fi

    # Vérifier erreur de base de données
    if docker compose logs kong --tail=50 2>/dev/null | grep -q "database.*error\|connection.*failed"; then
        error "❌ Erreur de connexion base de données"
        echo "  → Vérifier que PostgreSQL fonctionne"
    else
        ok "✅ Pas d'erreur de base de données"
    fi

    # Vérifier erreur de configuration
    if docker compose logs kong --tail=50 2>/dev/null | grep -q "configuration.*error\|invalid.*config"; then
        error "❌ Erreur de configuration détectée"
    else
        ok "✅ Configuration semble valide"
    fi

    echo ""
    echo "==================== TEST CONNECTIVITÉ ===================="

    # Test connectivité Kong
    log "🌐 Test connectivité Kong :"

    if curl -s -I http://localhost:8001 >/dev/null 2>&1; then
        ok "✅ Kong accessible sur port 8001"

        # Test endpoint de base
        response=$(curl -s http://localhost:8001 2>/dev/null || echo "ERROR")
        if [[ "$response" != "ERROR" ]]; then
            ok "✅ Kong répond correctement"
        else
            warn "⚠️  Kong accessible mais ne répond pas correctement"
        fi
    else
        error "❌ Kong non accessible sur port 8001"
        log "🔧 Diagnostic port :"
        netstat -tlnp | grep :8001 || echo "  Aucun service sur port 8001"
    fi

    echo ""
    echo "==================== RECOMMANDATIONS ===================="

    # Recommandations basées sur l'analyse
    if docker compose logs kong --tail=10 2>/dev/null | grep -q -E "(error|Error|ERROR)"; then
        echo "🔧 Kong présente des erreurs :"
        echo "  1. Vérifier logs complets : docker compose logs kong"
        echo "  2. Redémarrer Kong : docker compose restart kong"
        echo "  3. Fix plugin : ./fix-kong-plugin-error.sh"
        echo "  4. Si problème persiste : ./restart-supabase.sh"
    else
        echo "✅ Kong semble fonctionnel"
        echo "🧪 Test API complet : ./test-supabase-api.sh"
    fi

    echo ""
    echo "📋 Logs en temps réel :"
    echo "  docker compose logs kong -f"
    echo ""
    echo "🔄 Redémarrage Kong seul :"
    echo "  docker compose restart kong"
    echo "================================================================"
}

main "$@"