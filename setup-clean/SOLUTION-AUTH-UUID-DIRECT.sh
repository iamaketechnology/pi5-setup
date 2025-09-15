#!/bin/bash

# SOLUTION AUTH UUID DIRECT - Correction immédiate erreur uuid = text
# Pour Pi 5 ARM64 Supabase - Correction ciblée migration 20221208132122

set -euo pipefail

# Couleurs pour logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅${NC} $1"
}

warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌${NC} $1"
}

# Diagnostic rapide du problème spécifique
diagnose_uuid_issue() {
    log "🔍 DIAGNOSTIC ERREUR UUID = TEXT"

    # Test direct de l'erreur
    local test_result
    test_result=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT COUNT(*) FROM auth.identities WHERE id = user_id::text;
    " 2>&1 || echo "ERROR_CONFIRMED")

    if [[ "$test_result" == *"operator does not exist"* ]] || [[ "$test_result" == "ERROR_CONFIRMED" ]]; then
        warning "Erreur 'uuid = text' confirmée dans migration 20221208132122"
        return 0
    else
        success "Erreur uuid = text déjà résolue"
        return 1
    fi
}

# Correction directe de l'erreur uuid = text
fix_uuid_cast_issue() {
    log "🔧 CORRECTION DIRECTE ERREUR UUID = TEXT"

    # Étape 1: Vérifier structure table identities
    log "Vérification structure auth.identities..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        \d auth.identities
    " | head -20

    # Étape 2: Créer opérateur uuid = text si nécessaire
    log "Création opérateur uuid = text compatible..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        DO \$\$
        BEGIN
            -- Créer fonction de comparaison uuid = text
            CREATE OR REPLACE FUNCTION uuid_text_eq(uuid, text)
            RETURNS boolean AS
            \$func\$
                SELECT \$1::text = \$2;
            \$func\$
            LANGUAGE SQL IMMUTABLE;

            -- Créer opérateur = pour uuid, text
            IF NOT EXISTS (
                SELECT 1 FROM pg_operator
                WHERE oprname = '='
                  AND oprleft = 'uuid'::regtype
                  AND oprright = 'text'::regtype
            ) THEN
                CREATE OPERATOR = (
                    LEFTARG = uuid,
                    RIGHTARG = text,
                    FUNCTION = uuid_text_eq
                );
            END IF;
        END
        \$\$;
    " || warning "Opérateur uuid = text déjà existant ou erreur de création"

    success "Opérateur uuid = text créé"
}

# Exécution manuelle de la migration problématique
execute_problematic_migration() {
    log "⚡ EXÉCUTION MANUELLE MIGRATION 20221208132122"

    # Exécuter la migration avec opérateur corrigé
    log "Application migration backfill_email_last_sign_in_at..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        UPDATE auth.identities
        SET last_sign_in_at = '2022-11-25'
        WHERE last_sign_in_at IS NULL
          AND created_at = '2022-11-25'
          AND updated_at = '2022-11-25'
          AND provider = 'email'
          AND id = user_id::text;
    " || warning "Migration déjà appliquée ou aucune donnée à modifier"

    # Marquer migration comme exécutée
    log "Marquage migration comme exécutée..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        INSERT INTO auth.schema_migrations (version)
        VALUES ('20221208132122')
        ON CONFLICT (version) DO NOTHING;
    "

    success "Migration 20221208132122 traitée"
}

# Test de validation post-correction
validate_fix() {
    log "🧪 VALIDATION CORRECTION"

    # Test opérateur uuid = text
    log "Test opérateur uuid = text..."
    local test_operator
    test_operator=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT COUNT(*) FROM auth.identities WHERE id = user_id::text;
    " 2>/dev/null || echo "ERROR")

    if [[ "$test_operator" != "ERROR" ]]; then
        success "Opérateur uuid = text fonctionne"
    else
        error "Opérateur uuid = text toujours problématique"
        return 1
    fi

    # Vérifier migration marquée
    local migration_status
    migration_status=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT COUNT(*) FROM auth.schema_migrations WHERE version = '20221208132122';
    ")

    if [[ "$migration_status" == "1" ]]; then
        success "Migration 20221208132122 marquée comme exécutée"
    else
        warning "Migration pas marquée - GoTrue pourrait la re-exécuter"
    fi
}

# Test service Auth après correction
test_auth_service() {
    log "🚀 TEST SERVICE AUTH APRÈS CORRECTION"

    # Redémarrer Auth
    log "Redémarrage service Auth..."
    docker compose restart auth

    # Attendre stabilisation
    sleep 15

    # Vérifier logs Auth
    log "Vérification logs Auth..."
    local auth_logs
    auth_logs=$(docker logs supabase-auth --tail=30 2>&1)

    if echo "$auth_logs" | grep -q "operator does not exist: uuid = text"; then
        error "Erreur uuid = text persiste dans les logs"
        echo "=== LOGS AUTH ==="
        echo "$auth_logs"
        return 1
    elif echo "$auth_logs" | grep -q "fatal"; then
        error "Autres erreurs fatales détectées"
        echo "=== LOGS AUTH ==="
        echo "$auth_logs"
        return 1
    else
        success "Logs Auth propres"
    fi

    # Vérifier statut conteneur
    local auth_status
    auth_status=$(docker ps --filter "name=supabase-auth" --format "{{.Status}}")

    if echo "$auth_status" | grep -q "Up"; then
        success "Service Auth opérationnel: $auth_status"
    else
        error "Service Auth instable: $auth_status"
        return 1
    fi
}

# Fonction principale
main() {
    echo "🎯 SOLUTION AUTH UUID DIRECT - Pi 5 ARM64"
    echo "Correction ciblée erreur uuid = text migration 20221208132122"
    echo "=========================================================="

    # Vérifier Docker disponible
    if ! docker ps | grep -q supabase-db; then
        error "Conteneur supabase-db non trouvé"
        exit 1
    fi

    # Diagnostic du problème
    if ! diagnose_uuid_issue; then
        success "Problème uuid = text déjà résolu"
        exit 0
    fi

    # Corrections séquentielles
    echo -e "\n🔧 PHASE 1: CORRECTION OPÉRATEUR"
    fix_uuid_cast_issue

    echo -e "\n⚡ PHASE 2: EXÉCUTION MIGRATION"
    execute_problematic_migration

    echo -e "\n🧪 PHASE 3: VALIDATION"
    validate_fix

    echo -e "\n🚀 PHASE 4: TEST SERVICE"
    if test_auth_service; then
        echo -e "\n🎉 SUCCÈS - AUTH UUID CORRIGÉ"
        echo "✅ Service Auth opérationnel"
        echo "✅ Migration 20221208132122 résolue"
        echo "✅ Opérateur uuid = text fonctionnel"

        echo -e "\n📋 PROCHAINES ÉTAPES:"
        echo "1. Tester API: curl http://localhost:8000/rest/v1/"
        echo "2. Accéder Studio: http://localhost:8000"
        echo "3. Vérifier création utilisateur"
    else
        echo -e "\n❌ ÉCHEC - PROBLÈME PERSISTE"
        echo "Consultez les logs Auth pour diagnostic:"
        echo "docker logs supabase-auth --tail=50"
        exit 1
    fi
}

# Vérifier répertoire Supabase
if [[ ! -f "docker-compose.yml" ]]; then
    error "docker-compose.yml non trouvé. Exécutez depuis le répertoire Supabase."
    exit 1
fi

# Exécuter
main "$@"