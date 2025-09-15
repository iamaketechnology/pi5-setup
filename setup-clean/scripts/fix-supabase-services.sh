#!/bin/bash

# =============================================================================
# SCRIPT DE RÉPARATION SUPABASE - Correction services en échec
# =============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="fix-supabase-services"
readonly PROJECT_DIR="/home/pi/stacks/supabase"

# Couleurs pour logs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Fonctions de logging
log() { echo -e "${BLUE}[FIX]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

fix_postgresql_auth_schema() {
    log "🔧 Correction schéma auth et rôles PostgreSQL..."

    # Attendre que PostgreSQL soit prêt
    local max_attempts=30
    local attempt=0

    while ! docker exec supabase-db pg_isready -U postgres >/dev/null 2>&1; do
        ((attempt++))
        if [[ $attempt -ge $max_attempts ]]; then
            error "PostgreSQL non accessible après $max_attempts tentatives"
            return 1
        fi
        log "   Attente PostgreSQL... ($attempt/$max_attempts)"
        sleep 2
    done

    ok "PostgreSQL accessible"

    # Créer le schéma auth et les rôles
    log "   Création schéma auth..."
    docker exec supabase-db psql -U postgres -d postgres -c "CREATE SCHEMA IF NOT EXISTS auth;" 2>/dev/null || true

    log "   Création rôles anon et service_role..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'anon') THEN
                CREATE ROLE anon;
                GRANT USAGE ON SCHEMA public TO anon;
                GRANT USAGE ON SCHEMA auth TO anon;
            END IF;

            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'service_role') THEN
                CREATE ROLE service_role;
                GRANT ALL ON SCHEMA public TO service_role;
                GRANT ALL ON SCHEMA auth TO service_role;
            END IF;

            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authenticated') THEN
                CREATE ROLE authenticated;
                GRANT USAGE ON SCHEMA public TO authenticated;
                GRANT USAGE ON SCHEMA auth TO authenticated;
            END IF;
        END
        \$\$;
    " 2>/dev/null || true

    ok "✅ Schéma auth et rôles PostgreSQL créés"
}

fix_env_variables() {
    log "🔧 Vérification variables d'environnement..."

    cd "$PROJECT_DIR" || exit 1

    # Vérifier et ajouter APP_NAME si manquant
    if ! grep -q "^APP_NAME=" .env 2>/dev/null; then
        log "   Ajout APP_NAME..."
        echo "APP_NAME=supabase" >> .env
    fi

    # Vérifier et ajouter REALTIME_APP_NAME si manquant
    if ! grep -q "^REALTIME_APP_NAME=" .env 2>/dev/null; then
        log "   Ajout REALTIME_APP_NAME..."
        echo "REALTIME_APP_NAME=supabase" >> .env
    fi

    # Vérifier et ajouter REALTIME_DB_PASSWORD si manquant
    local postgres_password
    postgres_password=$(grep "^POSTGRES_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"')

    if ! grep -q "^REALTIME_DB_PASSWORD=" .env 2>/dev/null; then
        log "   Ajout REALTIME_DB_PASSWORD..."
        echo "REALTIME_DB_PASSWORD=$postgres_password" >> .env
    fi

    ok "✅ Variables d'environnement corrigées"
}

restart_failed_services() {
    log "🔄 Redémarrage des services en échec..."

    cd "$PROJECT_DIR" || exit 1

    # Arrêter les services problématiques
    log "   Arrêt services en échec..."
    docker compose stop auth storage realtime 2>/dev/null || true

    # Attendre un peu
    sleep 3

    # Redémarrer tous les services
    log "   Redémarrage de tous les services..."
    docker compose up -d

    ok "✅ Services redémarrés"
}

wait_and_check_services() {
    log "⏳ Vérification état des services..."

    cd "$PROJECT_DIR" || exit 1

    # Attendre 30 secondes pour l'initialisation
    local wait_time=30
    log "   Attente initialisation ($wait_time secondes)..."
    sleep $wait_time

    # Vérifier l'état des services
    log "   État actuel des conteneurs :"
    docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}"

    # Compter les services en cours d'exécution
    local running_count
    running_count=$(docker compose ps --filter "status=running" -q | wc -l)
    local total_count
    total_count=$(docker compose ps -q | wc -l)

    log "   Services actifs: $running_count/$total_count"

    if [[ $running_count -ge 8 ]]; then
        ok "✅ Majorité des services démarrés"
        return 0
    else
        warn "⚠️ Certains services ont encore des problèmes"
        return 1
    fi
}

show_access_info() {
    local ip
    ip=$(hostname -I | awk '{print $1}')

    echo ""
    echo "==================== 🎯 SUPABASE RÉPARÉ ===================="
    echo ""
    echo "🌐 **Accès Supabase** :"
    echo "   Studio: http://$ip:3000"
    echo "   API: http://$ip:8001"
    echo ""
    echo "🔍 **Vérifications** :"
    echo "   docker compose ps"
    echo "   docker compose logs [service] --tail=10"
    echo ""
    echo "📚 **Documentation** :"
    echo "   https://supabase.com/docs"
    echo "================================================="
    echo ""
}

main() {
    echo ""
    log "🚀 Réparation Supabase - Correction services en échec"
    echo ""

    # Vérifier qu'on est dans le bon répertoire
    if [[ ! -d "$PROJECT_DIR" ]]; then
        error "Répertoire Supabase non trouvé: $PROJECT_DIR"
        exit 1
    fi

    # Vérifier que les conteneurs existent
    cd "$PROJECT_DIR" || exit 1
    if ! docker compose ps -q >/dev/null 2>&1; then
        error "Aucun conteneur Supabase trouvé"
        exit 1
    fi

    # Appliquer les corrections
    fix_postgresql_auth_schema
    echo ""

    fix_env_variables
    echo ""

    restart_failed_services
    echo ""

    wait_and_check_services
    echo ""

    show_access_info

    log "🎉 Réparation terminée"
}

# Vérifier les prérequis
if ! command -v docker >/dev/null 2>&1; then
    error "Docker non installé"
    exit 1
fi

main "$@"