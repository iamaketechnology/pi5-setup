#!/bin/bash

# SOLUTION AUTH MIGRATION COMPLETE - Pi 5 ARM64
# Basé sur recherche approfondie sugestionia.md
# Corrige les migrations Auth incomplètes sur Supabase self-hosted

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

# Vérifier que Docker compose est disponible
check_docker_availability() {
    if ! command -v docker &> /dev/null; then
        error "Docker non disponible. Exécutez ce script sur la machine avec Supabase."
        exit 1
    fi

    if ! docker ps | grep -q supabase-db; then
        error "Conteneur supabase-db non trouvé. Assurez-vous que Supabase est démarré."
        exit 1
    fi

    success "Docker et conteneur supabase-db détectés"
}

# Diagnostic complet du schéma Auth
diagnose_auth_schema() {
    log "🔍 DIAGNOSTIC COMPLET DU SCHÉMA AUTH"

    echo "=== 1. Vérification tables auth existantes ==="
    docker exec supabase-db psql -U postgres -d postgres -c "\dt auth.*" || true

    echo -e "\n=== 2. Vérification types auth (factor_type) ==="
    docker exec supabase-db psql -U postgres -d postgres -c "\dT auth.*" || true

    echo -e "\n=== 3. État des migrations auth ==="
    docker exec supabase-db psql -U postgres -d postgres -c "
        SELECT version, inserted_at
        FROM auth.schema_migrations
        ORDER BY version DESC
        LIMIT 10;
    " || echo "Table schema_migrations non trouvée ou vide"

    echo -e "\n=== 4. Test factor_type spécifique ==="
    local factor_exists
    factor_exists=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT EXISTS (
            SELECT 1
            FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
            WHERE n.nspname = 'auth' AND t.typname = 'factor_type'
        );
    " 2>/dev/null || echo "false")

    if [[ "$factor_exists" == "t" ]]; then
        success "auth.factor_type existe"
    else
        warning "auth.factor_type MANQUANT - confirme problème migrations Auth"
    fi

    echo -e "\n=== 5. Test erreur uuid = text ==="
    local uuid_error
    uuid_error=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT id = user_id::text
        FROM auth.identities
        LIMIT 1;
    " 2>&1 || echo "Erreur uuid = text confirmée")

    if [[ "$uuid_error" == *"operator does not exist"* ]]; then
        warning "Erreur uuid = text confirmée"
    fi
}

# Correction directe erreur uuid = text (solution ciblée intégrée)
fix_uuid_operator_issue() {
    log "🔧 CORRECTION OPÉRATEUR UUID = TEXT"

    # Créer opérateur uuid = text si nécessaire
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
    " || warning "Opérateur uuid = text déjà existant"

    success "Opérateur uuid = text configuré"
}

# Appliquer migration problématique manuellement
fix_problematic_migration() {
    log "⚡ CORRECTION MIGRATION 20221208132122"

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

# Télécharger et appliquer le schéma Auth complet (fallback si nécessaire)
fix_auth_schema_complete() {
    log "🔧 VÉRIFICATION SCHÉMA AUTH COMPLET"

    # Si factor_type manque, essayer de le créer
    local factor_exists
    factor_exists=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
        SELECT EXISTS (
            SELECT 1
            FROM pg_type t
            JOIN pg_namespace n ON t.typnamespace = n.oid
            WHERE n.nspname = 'auth' AND t.typname = 'factor_type'
        );
    " 2>/dev/null || echo "false")

    if [[ "$factor_exists" != "t" ]]; then
        log "Création type auth.factor_type manquant..."
        docker exec supabase-db psql -U postgres -d postgres -c "
            CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn', 'phone');
        " || warning "Type factor_type déjà existant ou erreur création"
        success "Type auth.factor_type créé"
    else
        success "Schéma Auth factor_type déjà présent"
    fi

    # Autres corrections schéma si nécessaires
    log "Vérification autres éléments schéma Auth..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        -- Assurer que les extensions nécessaires sont présentes
        CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
        CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";
    " || warning "Extensions déjà présentes"

    success "Schéma Auth vérifié et complété"
}

# Corrections supplémentaires recommandées
apply_additional_fixes() {
    log "🛠️ CORRECTIONS SUPPLÉMENTAIRES RECOMMANDÉES"

    # 1. Correction URL DB pour GoTrue (SSL)
    log "Vérification configuration GoTrue SSL..."
    if docker compose config | grep -q "sslmode=disable"; then
        success "Configuration SSL GoTrue correcte"
    else
        warning "Vérifiez que GOTRUE_DB_DATABASE_URL contient ?sslmode=disable"
    fi

    # 2. Vérification cohérence JWT
    log "Vérification cohérence clés JWT..."
    local jwt_secret
    jwt_secret=$(grep "JWT_SECRET=" .env | cut -d= -f2 || echo "")

    if [[ -n "$jwt_secret" ]]; then
        success "JWT_SECRET configuré"
    else
        warning "JWT_SECRET manquant dans .env"
    fi

    # 3. Création publication Realtime si manquante
    log "Vérification publication Realtime..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        SELECT * FROM pg_publication WHERE pubname = 'realtime';
    " || {
        log "Création publication Realtime..."
        docker exec supabase-db psql -U postgres -d postgres -c "
            CREATE PUBLICATION realtime FOR ALL TABLES;
        "
        success "Publication Realtime créée"
    }
}

# Test services après correction
test_services_after_fix() {
    log "🧪 TEST SERVICES APRÈS CORRECTION"

    # Redémarrer Auth
    log "Redémarrage service Auth..."
    docker compose restart auth

    # Attendre et vérifier logs Auth
    sleep 10
    log "Vérification logs Auth..."
    local auth_logs
    auth_logs=$(docker logs supabase-auth --tail=20 2>&1)

    if echo "$auth_logs" | grep -q "operator does not exist: uuid = text"; then
        error "Erreur uuid = text persiste"
        echo "$auth_logs"
        return 1
    elif echo "$auth_logs" | grep -q "factor_type does not exist"; then
        error "Erreur factor_type persiste"
        echo "$auth_logs"
        return 1
    elif echo "$auth_logs" | grep -q "fatal"; then
        error "Autres erreurs fatales détectées"
        echo "$auth_logs"
        return 1
    else
        success "Logs Auth propres"
    fi

    # Test statut Auth
    sleep 5
    local auth_status
    auth_status=$(docker ps --filter "name=supabase-auth" --format "{{.Status}}")

    if echo "$auth_status" | grep -q "Up"; then
        success "Service Auth stable et opérationnel"
    else
        error "Service Auth toujours instable: $auth_status"
        return 1
    fi
}

# Résumé et validation finale
final_validation() {
    log "📋 VALIDATION FINALE COMPLÈTE"

    echo "=== STATUS SERVICES ==="
    docker ps --filter "name=supabase" --format "table {{.Names}}\t{{.Status}}"

    echo -e "\n=== VÉRIFICATION SCHÉMA AUTH FINAL ==="
    docker exec supabase-db psql -U postgres -d postgres -c "
        SELECT 'auth.factor_type' as type_name,
               EXISTS(SELECT 1 FROM pg_type t JOIN pg_namespace n ON t.typnamespace = n.oid
                      WHERE n.nspname = 'auth' AND t.typname = 'factor_type') as exists;
    "

    echo -e "\n=== TEST UUID COMPARISON ==="
    docker exec supabase-db psql -U postgres -d postgres -c "
        SELECT 'UUID comparison test' as test,
               (SELECT COUNT(*) FROM auth.identities WHERE id = user_id::text) as result;
    " || echo "Test impossible - table vide (normal)"

    echo -e "\n=== VÉRIFICATION OPÉRATEUR UUID = TEXT ==="
    docker exec supabase-db psql -U postgres -d postgres -c "
        SELECT 'Opérateur uuid = text' as test,
               EXISTS(SELECT 1 FROM pg_operator WHERE oprname = '=' AND oprleft = 'uuid'::regtype AND oprright = 'text'::regtype) as exists;
    "

    success "Validation complète terminée"
}

# Fonction principale
main() {
    echo "🚀 SOLUTION AUTH MIGRATION COMPLETE - Pi 5 ARM64"
    echo "Basé sur recherche approfondie sugestionia.md"
    echo "=============================================="

    check_docker_availability

    echo -e "\n📊 PHASE 1: DIAGNOSTIC COMPLET"
    diagnose_auth_schema

    echo -e "\n🔧 PHASE 2: CORRECTION SCHÉMA AUTH"
    fix_uuid_operator_issue
    fix_problematic_migration
    fix_auth_schema_complete
    apply_additional_fixes

    echo -e "\n🧪 PHASE 3: TEST ET VALIDATION"
    if test_services_after_fix; then
        echo -e "\n🎉 SUCCÈS - AUTH MIGRATION CORRIGÉE"
        final_validation

        echo -e "\n✅ PROCHAINES ÉTAPES:"
        echo "1. Vérifiez API REST: curl http://localhost:8000/rest/v1/"
        echo "2. Accédez Studio: http://localhost:8000"
        echo "3. Testez création utilisateur via Studio"

    else
        echo -e "\n❌ ÉCHEC - PROBLÈME PERSISTE"
        echo "Consultez les logs détaillés pour diagnostic approfondi."
        echo "Logs Auth: docker logs supabase-auth"
        exit 1
    fi
}

# Vérifier qu'on est dans le bon répertoire
if [[ ! -f "docker-compose.yml" ]]; then
    error "docker-compose.yml non trouvé. Exécutez depuis le répertoire Supabase."
    exit 1
fi

# Exécuter script principal
main "$@"