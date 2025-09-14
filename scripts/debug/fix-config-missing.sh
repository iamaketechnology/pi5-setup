#!/usr/bin/env bash
set -euo pipefail

# === FIX CONFIG MISSING - Variables Supabase manquantes ===

log()  { echo -e "\033[1;36m[CONFIG-FIX]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[OK]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

main() {
    log "🔧 Fix variables de configuration Supabase manquantes"

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -f "docker-compose.yml" ]] || [[ ! -f ".env" ]]; then
        error "❌ Pas dans le répertoire Supabase ou fichiers manquants"
        echo "Exécute : cd ~/stacks/supabase && ./fix-config-missing.sh"
        exit 1
    fi

    log "📍 Répertoire : $(pwd)"

    # Sauvegarder .env
    log "💾 Sauvegarde .env actuel..."
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)

    # Obtenir l'IP du Pi
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    log "🌐 IP locale détectée : $LOCAL_IP"

    echo ""
    echo "==================== ANALYSE CONFIG ACTUELLE ===================="

    # Vérifier variables critiques manquantes
    missing_vars=()

    # Vérifier API_EXTERNAL_URL
    if ! grep -q "API_EXTERNAL_URL=" .env; then
        missing_vars+=("API_EXTERNAL_URL")
        warn "❌ API_EXTERNAL_URL manquante"
    else
        ok "✅ API_EXTERNAL_URL présente"
    fi

    # Vérifier SUPABASE_PUBLIC_URL
    if ! grep -q "SUPABASE_PUBLIC_URL=" .env; then
        missing_vars+=("SUPABASE_PUBLIC_URL")
        warn "❌ SUPABASE_PUBLIC_URL manquante"
    else
        ok "✅ SUPABASE_PUBLIC_URL présente"
    fi

    # Vérifier mots de passe
    if ! grep -q "POSTGRES_PASSWORD=" .env; then
        missing_vars+=("POSTGRES_PASSWORD")
        warn "❌ POSTGRES_PASSWORD manquante"
    else
        ok "✅ POSTGRES_PASSWORD présente"
    fi

    if ! grep -q "SUPABASE_PASSWORD=" .env; then
        missing_vars+=("SUPABASE_PASSWORD")
        warn "❌ SUPABASE_PASSWORD manquante"
    else
        ok "✅ SUPABASE_PASSWORD présente"
    fi

    # Vérifier JWT secret
    if ! grep -q "JWT_SECRET=" .env; then
        missing_vars+=("JWT_SECRET")
        warn "❌ JWT_SECRET manquante"
    else
        ok "✅ JWT_SECRET présente"
    fi

    echo ""
    echo "==================== CORRECTION VARIABLES ===================="

    if [[ ${#missing_vars[@]} -eq 0 ]]; then
        ok "✅ Toutes les variables critiques sont présentes"
        log "🔍 Vérification des valeurs..."
    else
        log "🔧 Ajout des variables manquantes..."

        # Ajouter API_EXTERNAL_URL si manquante
        if [[ " ${missing_vars[@]} " =~ " API_EXTERNAL_URL " ]]; then
            echo "API_EXTERNAL_URL=http://$LOCAL_IP:8001" >> .env
            ok "✅ API_EXTERNAL_URL ajoutée"
        fi

        # Ajouter SUPABASE_PUBLIC_URL si manquante
        if [[ " ${missing_vars[@]} " =~ " SUPABASE_PUBLIC_URL " ]]; then
            echo "SUPABASE_PUBLIC_URL=http://$LOCAL_IP:8001" >> .env
            ok "✅ SUPABASE_PUBLIC_URL ajoutée"
        fi

        # Générer mot de passe sécurisé si manquant
        if [[ " ${missing_vars[@]} " =~ " POSTGRES_PASSWORD " ]]; then
            POSTGRES_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            echo "POSTGRES_PASSWORD=$POSTGRES_PWD" >> .env
            ok "✅ POSTGRES_PASSWORD générée"
        fi

        if [[ " ${missing_vars[@]} " =~ " SUPABASE_PASSWORD " ]]; then
            SUPABASE_PWD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
            echo "SUPABASE_PASSWORD=$SUPABASE_PWD" >> .env
            ok "✅ SUPABASE_PASSWORD générée"
        fi

        # Générer JWT secret si manquant
        if [[ " ${missing_vars[@]} " =~ " JWT_SECRET " ]]; then
            JWT_SECRET=$(openssl rand -base64 64 | tr -d "=+/" | cut -c1-60)
            echo "JWT_SECRET=$JWT_SECRET" >> .env
            ok "✅ JWT_SECRET générée"
        fi
    fi

    echo ""
    echo "==================== VÉRIFICATION FINALE ===================="

    log "📋 Variables critiques dans .env :"
    echo "--- URLs ---"
    grep -E "(API_EXTERNAL_URL|SUPABASE_PUBLIC_URL)" .env || warn "URLs manquantes"
    echo "--- Sécurité ---"
    grep -E "(POSTGRES_PASSWORD|JWT_SECRET)" .env | sed 's/=.*/=***/' || warn "Mots de passe manquants"

    echo ""
    echo "==================== REDÉMARRAGE SERVICES ===================="

    log "⏹️  Arrêt des services..."
    docker compose down

    log "🚀 Redémarrage avec nouvelle configuration..."
    docker compose up -d

    # Attendre initialisation
    log "⏳ Attente initialisation (30s)..."
    sleep 30

    # Vérification rapide
    log "🔍 Vérification rapide..."
    docker compose ps --format "table {{.Name}}\t{{.Status}}" | head -10

    echo ""
    echo "==================== RÉSULTATS ===================="
    echo "✅ Variables de configuration ajoutées/corrigées"
    echo "✅ Services redémarrés"
    echo ""
    echo "🧪 Vérifications recommandées :"
    echo "   1. État services : ./check-services-status.sh"
    echo "   2. Test API : ./test-api-connectivity.sh"
    echo "   3. Santé globale : ./check-supabase-health.sh"
    echo ""
    echo "📍 Accès Supabase :"
    echo "   🎨 Studio : http://$LOCAL_IP:3000"
    echo "   🔌 API : http://$LOCAL_IP:8001"
    echo "=================================================="
}

main "$@"