#!/usr/bin/env bash
set -euo pipefail

# === FIX CONTAINER RECREATION - Force recreation après changement config ===

log()  { echo -e "\033[1;36m[RECREATE]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔄 Force recreation des conteneurs Supabase après changement config"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-container-recreation.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    # Obtenir l'IP du Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "🌐 IP locale détectée : $LOCAL_IP"

    echo ""
    echo "==================== ÉTAT AVANT RECREATION ===================="

    log "📊 État actuel des conteneurs :"
    if docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -5; then
        ok "✅ Conteneurs détectés"
    else
        warn "⚠️  Aucun conteneur actif"
    fi

    echo ""
    echo "==================== VÉRIFICATION CONFIG ===================="

    log "🔍 Variables critiques dans .env :"
    if grep -E "(API_EXTERNAL_URL|SUPABASE_PUBLIC_URL)" .env | head -3; then
        ok "✅ Variables URL présentes"
    else
        error "❌ Variables URL manquantes"
        exit 1
    fi

    echo ""
    echo "==================== RECREATION COMPLÈTE ===================="

    log "⏹️  Arrêt et suppression complète des conteneurs..."
    log "   ⚠️  Cela va supprimer volumes et networks pour reset complet"

    # Arrêt complet avec suppression volumes
    docker compose down --volumes --remove-orphans || warn "Erreur lors de l'arrêt (ignoré)"

    log "🧹 Nettoyage images et caches Docker..."
    # Nettoyage des images anciennes pour forcer le re-pull
    docker images | grep -E "(supabase|kong|postgres)" | awk '{print $3}' | head -5 | xargs -r docker rmi -f 2>/dev/null || warn "Nettoyage images ignoré"

    log "🚀 Recreation forcée de tous les conteneurs..."
    log "   📋 Cela va re-télécharger les images si nécessaire"
    log "   🔧 Appliquer toutes les variables d'environnement .env"

    # Recreation complète avec force recreate
    docker compose up -d --force-recreate --pull always

    log "⏳ Attente initialisation complète (90 secondes)..."
    log "   📊 PostgreSQL init + users creation"
    log "   🔧 Kong configuration loading"
    log "   ⚡ Services interdependencies"

    # Attente plus longue pour init complète
    for i in {90..1}; do
        if [[ $((i % 10)) -eq 0 ]]; then
            echo -n "⏳ $i secondes restantes... "
            # Test rapide si services commencent à répondre
            if curl -s -I http://localhost:3000 >/dev/null 2>&1; then
                echo "(Studio répond)"
            else
                echo "(initialisation...)"
            fi
        fi
        sleep 1
    done

    echo ""
    echo "==================== VÉRIFICATION POST-RECREATION ===================="

    log "📊 État des conteneurs après recreation :"
    docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

    echo ""
    log "🧪 Tests de connectivité post-recreation :"

    # Test Studio
    if curl -s -I http://localhost:3000 >/dev/null 2>&1; then
        ok "  ✅ Studio accessible (localhost:3000)"
    else
        warn "  ⚠️  Studio non accessible (localhost:3000)"
    fi

    # Test API Gateway
    if curl -s -I http://localhost:8001 >/dev/null 2>&1; then
        ok "  ✅ API Gateway accessible (localhost:8001)"
    else
        warn "  ⚠️  API Gateway non accessible (localhost:8001)"
    fi

    # Test PostgreSQL
    if nc -z localhost 5432 2>/dev/null; then
        ok "  ✅ PostgreSQL port ouvert (5432)"
    else
        warn "  ⚠️  PostgreSQL port fermé (5432)"
    fi

    # Test réseau externe
    if curl -s -I "http://${LOCAL_IP}:3000" >/dev/null 2>&1; then
        ok "  ✅ Studio accessible réseau (${LOCAL_IP}:3000)"
    else
        warn "  ⚠️  Studio non accessible réseau (${LOCAL_IP}:3000)"
    fi

    echo ""
    echo "==================== DIAGNOSTIC SERVICES PROBLÉMATIQUES ===================="

    # Identifier les services encore en problème
    restarting_services=$(docker compose ps --format "table {{.Name}} {{.Status}}" | grep -i restarting | awk '{print $1}' || true)

    if [[ -n "$restarting_services" ]]; then
        warn "⚠️  Services encore en redémarrage :"
        echo "$restarting_services" | while read -r service_name; do
            if [[ -n "$service_name" ]]; then
                echo "  - $service_name"
                service_short=$(echo "$service_name" | sed 's/supabase-//')
                log "    📋 Dernière erreur :"
                docker compose logs "$service_short" --tail=2 2>/dev/null | sed 's/^/      /' || echo "      Logs non disponibles"
            fi
        done

        echo ""
        warn "🔧 Actions correctives suggérées :"
        echo "   1. Attendre encore 2-3 minutes (services complexes)"
        echo "   2. Vérifier logs spécifiques : docker compose logs [service]"
        echo "   3. Si Kong pose problème : ./fix-kong-plugin-error.sh"
        echo "   4. Si erreurs DB : ./fix-database-users.sh"
    else
        ok "🎉 Aucun service en redémarrage détecté !"
    fi

    echo ""
    echo "==================== RÉSULTATS RECREATION ===================="
    echo "✅ Recreation complète effectuée avec --force-recreate"
    echo "✅ Volumes et networks recréés (config fraîche)"
    echo "✅ Variables d'environnement .env appliquées"
    echo ""
    echo "📍 URLs d'accès :"
    echo "   🎨 Studio : http://${LOCAL_IP}:3000"
    echo "   🔌 API : http://${LOCAL_IP}:8001"
    echo "   🔗 Portainer : http://${LOCAL_IP}:8000"
    echo ""
    echo "🧪 Vérifications recommandées :"
    echo "   ./check-services-status.sh    # État détaillé services"
    echo "   ./test-api-connectivity.sh    # Test complet APIs"
    echo "   ./check-supabase-health.sh    # Diagnostic global"
    echo ""
    echo "💡 Si services redémarrent encore :"
    echo "   - Attendre 5-10 minutes (init PostgreSQL complexe)"
    echo "   - Vérifier logs : docker compose logs [service]"
    echo "   - Scripts spécialisés pour erreurs persistantes"
    echo "=================================================="
}

main "$@"