#!/usr/bin/env bash
set -euo pipefail

# === CHECK SERVICES STATUS - Supabase All Services ===

log()  { echo -e "\033[1;36m[STATUS]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "📊 Vérification état de tous les services Supabase"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]]; then
        error "❌ Pas dans le répertoire Supabase"
        echo "Exécute : cd ~/stacks/supabase && ./check-services-status.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"
    echo ""

    echo "==================== ÉTAT DES SERVICES ===================="

    # État général des conteneurs
    log "🐳 État des conteneurs Docker :"
    if docker compose ps 2>/dev/null; then
        ok "✅ Docker Compose accessible"
    else
        error "❌ Impossible d'accéder à Docker Compose"
        exit 1
    fi

    echo ""
    echo "==================== ANALYSE DÉTAILLÉE ===================="

    # Analyser chaque service individuellement
    services=("db" "kong" "auth" "rest" "realtime" "storage" "meta" "studio" "imgproxy" "edge-functions")

    for service in "${services[@]}"; do
        log "🔍 Service: $service"

        # Vérifier si le conteneur existe et son état
        if docker compose ps "$service" 2>/dev/null | grep -q "$service"; then
            status=$(docker compose ps "$service" --format "table {{.Status}}" | tail -n +2)

            if echo "$status" | grep -q "Up"; then
                ok "  ✅ $service : $status"
            elif echo "$status" | grep -q "Restarting"; then
                warn "  ⚠️  $service : $status"
            else
                error "  ❌ $service : $status"
            fi
        else
            error "  ❌ $service : Non trouvé"
        fi
    done

    echo ""
    echo "==================== SERVICES PROBLÉMATIQUES ===================="

    # Identifier les services qui redémarrent
    restarting_services=$(docker compose ps --format "table {{.Name}} {{.Status}}" | grep -i restarting | awk '{print $1}' || true)

    if [[ -n "$restarting_services" ]]; then
        warn "🔄 Services en redémarrage :"
        echo "$restarting_services" | while read -r service_name; do
            if [[ -n "$service_name" ]]; then
                echo "  - $service_name"
            fi
        done

        echo ""
        log "📋 Logs des services problématiques :"
        echo "$restarting_services" | while read -r service_name; do
            if [[ -n "$service_name" ]]; then
                service_short=$(echo "$service_name" | sed 's/supabase-//')
                echo ""
                echo "--- Logs $service_short (5 dernières lignes) ---"
                docker compose logs "$service_short" --tail=5 2>/dev/null || echo "Impossible de lire les logs"
            fi
        done
    else
        ok "✅ Aucun service en redémarrage"
    fi

    echo ""
    echo "==================== CONNECTIVITÉ RÉSEAU ===================="

    # Test des ports principaux
    ports=("3000:Studio" "8001:API Gateway" "5432:PostgreSQL")

    for port_info in "${ports[@]}"; do
        port=$(echo "$port_info" | cut -d: -f1)
        name=$(echo "$port_info" | cut -d: -f2)

        if curl -s -I "http://localhost:$port" >/dev/null 2>&1; then
            ok "  ✅ Port $port ($name) : Accessible"
        else
            warn "  ⚠️  Port $port ($name) : Non accessible"
        fi
    done

    echo ""
    echo "==================== RESSOURCES SYSTÈME ===================="

    # Utilisation mémoire des conteneurs
    log "💾 Utilisation mémoire :"
    docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.CPUPerc}}" | grep supabase || warn "Aucun conteneur Supabase trouvé"

    echo ""
    echo "==================== RECOMMANDATIONS ===================="

    # Recommandations basées sur l'état
    if [[ -n "$restarting_services" ]]; then
        echo "🔧 Actions suggérées :"
        echo "  1. Vérifier logs détaillés : docker compose logs [service] --tail=50"
        echo "  2. Redémarrer services problématiques : docker compose restart [service]"
        echo "  3. Si Kong pose problème : ./fix-kong-plugin-error.sh"
        echo "  4. Test API complet : ./test-supabase-api.sh"
    else
        echo "✅ Tous les services semblent fonctionnels"
        echo "🧪 Test API recommandé : ./test-supabase-api.sh"
    fi

    echo ""
    echo "🔍 Scripts disponibles :"
    echo "  ./check-supabase-health.sh    # Diagnostic complet"
    echo "  ./test-supabase-api.sh        # Test toutes les APIs"
    echo "  ./fix-kong-plugin-error.sh    # Fix problème Kong"
    echo "  ./restart-supabase.sh         # Redémarrage propre"
    echo "================================================================"
}

main "$@"