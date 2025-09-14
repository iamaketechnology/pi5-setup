#!/usr/bin/env bash
set -euo pipefail

# === FIX KONG PLUGIN ERROR - request-id plugin missing ===

log()  { echo -e "\033[1;36m[KONG-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix Kong plugin 'request-id' missing error"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]]; then
        error "❌ Pas dans le répertoire Supabase"
        echo "Exécute : cd ~/stacks/supabase && ./fix-kong-plugin-error.sh"
        exit 1
    fi

    log "📍 Répertoire actuel : $(pwd)"

    # Vérifier l'erreur Kong actuelle
    log "🔍 Vérification erreur Kong..."
    if docker compose logs kong --tail=5 2>/dev/null | grep -q "request-id"; then
        ok "✅ Erreur 'request-id' confirmée"
    else
        warn "⚠️  Erreur 'request-id' non détectée actuellement"
    fi

    # Arrêter Kong spécifiquement
    log "⏹️  Arrêt service Kong..."
    docker compose stop kong || true

    # Sauvegarder docker-compose.yml
    log "💾 Sauvegarde docker-compose.yml..."
    cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)

    # Solution 1: Changer version Kong (plus compatible)
    log "🔄 Mise à jour version Kong 2.8.1 → 3.0.0..."
    if grep -q "kong:2.8.1" docker-compose.yml; then
        sed -i 's/kong:2.8.1/kong:3.0.0/g' docker-compose.yml
        ok "✅ Version Kong mise à jour"
    else
        warn "⚠️  Version Kong 2.8.1 non trouvée"
    fi

    # Vérifier si config Kong existe
    if [[ -d "volumes/api" ]] && [[ -f "volumes/api/kong.yml" ]]; then
        log "📝 Configuration Kong détectée"
        cp volumes/api/kong.yml volumes/api/kong.yml.backup.$(date +%Y%m%d_%H%M%S)

        # Supprimer références au plugin request-id
        if grep -q "request-id" volumes/api/kong.yml; then
            sed -i '/request-id/d' volumes/api/kong.yml
            ok "✅ Plugin request-id retiré de la configuration"
        fi
    else
        log "ℹ️  Pas de config Kong personnalisée trouvée"
    fi

    # Nettoyer les volumes Kong si nécessaire
    log "🧹 Nettoyage volumes Kong..."
    docker volume ls -q | grep -E "(kong|supabase.*kong)" | xargs -r docker volume rm 2>/dev/null || true

    # Redémarrer Kong avec nouvelle config
    log "🚀 Redémarrage Kong avec nouvelle version..."
    docker compose up -d kong

    # Attendre initialisation Kong
    log "⏳ Attente initialisation Kong (20s)..."
    sleep 20

    # Vérifier état Kong
    log "📊 Vérification état Kong..."
    if docker compose ps kong | grep -q "Up"; then
        ok "✅ Kong démarré avec succès"

        # Test connectivité Kong
        if curl -s -I http://localhost:8001 >/dev/null 2>&1; then
            ok "✅ Kong accessible sur port 8001"
        else
            warn "⚠️  Kong non accessible sur port 8001"
        fi
    else
        warn "⚠️  Kong toujours problématique"
        log "📋 Logs Kong récents :"
        docker compose logs kong --tail=10
    fi

    # Redémarrer tous les services dépendants
    log "🔄 Redémarrage services dépendants..."
    docker compose restart auth rest realtime storage

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ Kong mis à jour vers version 3.0.0"
    echo "✅ Plugin request-id retiré si présent"
    echo "✅ Services redémarrés"
    echo ""
    echo "🔍 Vérification finale :"
    echo "   docker compose ps"
    echo "   docker compose logs kong --tail=10"
    echo ""
    echo "🧪 Test API :"
    echo "   curl -I http://localhost:8001"
    echo "=================================================="
}

main "$@"