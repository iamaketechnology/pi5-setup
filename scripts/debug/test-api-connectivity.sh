#!/usr/bin/env bash
set -euo pipefail

# === TEST API CONNECTIVITY - Test tous les endpoints Supabase ===

log()  { echo -e "\033[1;36m[API-TEST]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

test_endpoint() {
    local endpoint="$1"
    local name="$2"
    local expected_status="${3:-200}"

    log "🧪 Test $name : $endpoint"

    if response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint" 2>/dev/null); then
        if [[ "$response" == "$expected_status" ]] || [[ "$response" == "404" && "$expected_status" == "200" ]]; then
            ok "  ✅ $name : HTTP $response"
            return 0
        else
            warn "  ⚠️  $name : HTTP $response (attendu $expected_status)"
            return 1
        fi
    else
        error "  ❌ $name : Non accessible"
        return 1
    fi
}

main() {
    log "🌐 Test connectivité de tous les endpoints Supabase"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]]; then
        error "❌ Pas dans le répertoire Supabase"
        echo "Exécute : cd ~/stacks/supabase && ./test-api-connectivity.sh"
        exit 1
    fi

    # Obtenir l'IP locale
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "📍 IP locale détectée : $LOCAL_IP"

    echo ""
    echo "==================== ENDPOINTS DE BASE ===================="

    # Test des endpoints principaux
    endpoints_basic=(
        "http://localhost:3000|Studio|200"
        "http://localhost:8001|Kong Gateway|200"
        "http://localhost:5432|PostgreSQL|000"  # PostgreSQL ne répond pas au HTTP
    )

    for endpoint_info in "${endpoints_basic[@]}"; do
        IFS='|' read -r endpoint name expected <<< "$endpoint_info"

        if [[ "$name" == "PostgreSQL" ]]; then
            # Test PostgreSQL avec pg_isready
            log "🧪 Test $name"
            if pg_isready -h localhost -p 5432 >/dev/null 2>&1; then
                ok "  ✅ $name : Accessible"
            elif nc -z localhost 5432 2>/dev/null; then
                ok "  ✅ $name : Port ouvert"
            else
                error "  ❌ $name : Non accessible"
            fi
        else
            test_endpoint "$endpoint" "$name" "$expected"
        fi
    done

    echo ""
    echo "==================== ENDPOINTS API SUPABASE ===================="

    # Test des endpoints API Supabase
    endpoints_api=(
        "http://localhost:8001/rest/v1/|API REST|404"
        "http://localhost:8001/auth/v1/|API Auth|404"
        "http://localhost:8001/realtime/v1/|API Realtime|404"
        "http://localhost:8001/storage/v1/|API Storage|404"
        "http://localhost:8001/functions/v1/|Edge Functions|404"
    )

    for endpoint_info in "${endpoints_api[@]}"; do
        IFS='|' read -r endpoint name expected <<< "$endpoint_info"
        test_endpoint "$endpoint" "$name" "$expected"
    done

    echo ""
    echo "==================== ENDPOINTS INTERNES ===================="

    # Test des services internes
    endpoints_internal=(
        "http://localhost:9000|Portainer|200"
        "http://localhost:54321/functions/v1/hello|Edge Functions Direct|404"
    )

    for endpoint_info in "${endpoints_internal[@]}"; do
        IFS='|' read -r endpoint name expected <<< "$endpoint_info"
        test_endpoint "$endpoint" "$name" "$expected"
    done

    echo ""
    echo "==================== TEST AVEC IP EXTERNE ===================="

    # Test avec IP externe pour accès réseau
    if [[ -n "$LOCAL_IP" ]]; then
        log "🌐 Test accès réseau externe avec IP $LOCAL_IP :"

        external_endpoints=(
            "http://$LOCAL_IP:3000|Studio (réseau)|200"
            "http://$LOCAL_IP:8001|API Gateway (réseau)|200"
        )

        for endpoint_info in "${external_endpoints[@]}"; do
            IFS='|' read -r endpoint name expected <<< "$endpoint_info"
            test_endpoint "$endpoint" "$name" "$expected"
        done
    fi

    echo ""
    echo "==================== ANALYSE DÉTAILLÉE ===================="

    # Test avec détail des réponses
    log "🔍 Analyse détaillée Kong Gateway :"
    if response=$(curl -s http://localhost:8001 2>/dev/null); then
        if echo "$response" | grep -q -i "kong\|api\|gateway"; then
            ok "  ✅ Kong répond avec contenu approprié"
        else
            warn "  ⚠️  Kong répond mais contenu inattendu"
            echo "  Réponse : $(echo "$response" | head -c 100)..."
        fi
    else
        error "  ❌ Kong ne répond pas"
    fi

    echo ""
    echo "==================== RÉSUMÉ ===================="

    # Compter les succès/échecs
    total_tests=0
    failed_tests=0

    # Retest rapide pour le résumé
    test_urls=(
        "http://localhost:3000"
        "http://localhost:8001"
        "http://localhost:8001/rest/v1/"
        "http://localhost:8001/auth/v1/"
    )

    for url in "${test_urls[@]}"; do
        ((total_tests++))
        if ! curl -s "$url" >/dev/null 2>&1; then
            ((failed_tests++))
        fi
    done

    successful_tests=$((total_tests - failed_tests))

    log "📊 Résultats : $successful_tests/$total_tests tests réussis"

    if [[ $failed_tests -eq 0 ]]; then
        ok "🎉 Tous les endpoints sont accessibles !"
        echo ""
        echo "✅ Supabase est opérationnel"
        echo "🌐 Studio : http://$LOCAL_IP:3000"
        echo "🔌 API : http://$LOCAL_IP:8001"
    else
        warn "⚠️  $failed_tests endpoint(s) inaccessible(s)"
        echo ""
        echo "🔧 Actions recommandées :"
        echo "  1. Vérifier état services : ./check-services-status.sh"
        echo "  2. Redémarrer si nécessaire : ./restart-supabase.sh"
        echo "  3. Vérifier logs : ./check-kong-logs.sh"
    fi

    echo "================================================================"
}

main "$@"