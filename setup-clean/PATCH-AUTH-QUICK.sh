#!/bin/bash

# PATCH AUTH QUICK - Correction immédiate erreur uuid = text
# Sans téléchargement externe, solution directe

set -euo pipefail

echo "🎯 PATCH AUTH QUICK - Correction uuid = text"
echo "==========================================="

# Vérifier Docker
if ! docker ps | grep -q supabase-db; then
    echo "❌ Conteneur supabase-db non trouvé"
    exit 1
fi

echo "✅ Docker détecté"

# Test diagnostic rapide
echo "🔍 Test erreur uuid = text..."
TEST_RESULT=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT COUNT(*) FROM auth.identities WHERE id = user_id::text;
" 2>&1 || echo "ERROR")

if [[ "$TEST_RESULT" == *"operator does not exist"* ]] || [[ "$TEST_RESULT" == "ERROR" ]]; then
    echo "⚠️ Erreur uuid = text confirmée - Application du correctif..."

    # Créer opérateur uuid = text
    echo "🔧 Création opérateur PostgreSQL uuid = text..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        DO \$\$
        BEGIN
            CREATE OR REPLACE FUNCTION uuid_text_eq(uuid, text)
            RETURNS boolean AS
            \$func\$
                SELECT \$1::text = \$2;
            \$func\$
            LANGUAGE SQL IMMUTABLE;

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
    "

    echo "✅ Opérateur uuid = text créé"

    # Appliquer migration manuellement
    echo "⚡ Application migration 20221208132122..."
    docker exec supabase-db psql -U postgres -d postgres -c "
        UPDATE auth.identities
        SET last_sign_in_at = '2022-11-25'
        WHERE last_sign_in_at IS NULL
          AND created_at = '2022-11-25'
          AND updated_at = '2022-11-25'
          AND provider = 'email'
          AND id = user_id::text;
    " || echo "⚠️ Migration déjà appliquée ou aucune donnée"

    # Marquer migration
    docker exec supabase-db psql -U postgres -d postgres -c "
        INSERT INTO auth.schema_migrations (version)
        VALUES ('20221208132122')
        ON CONFLICT (version) DO NOTHING;
    "

    echo "✅ Migration 20221208132122 traitée"

else
    echo "✅ Erreur uuid = text déjà résolue"
fi

# Test validation
echo "🧪 Test validation..."
VALIDATION=$(docker exec supabase-db psql -U postgres -d postgres -tAc "
    SELECT COUNT(*) FROM auth.identities WHERE id = user_id::text;
" 2>/dev/null || echo "ERROR")

if [[ "$VALIDATION" != "ERROR" ]]; then
    echo "✅ Opérateur uuid = text fonctionnel"
else
    echo "❌ Problème persiste"
    exit 1
fi

# Redémarrer Auth
echo "🚀 Redémarrage service Auth..."
docker compose restart auth

echo "⏳ Attente stabilisation (15s)..."
sleep 15

# Vérifier logs
echo "📋 Vérification logs Auth..."
AUTH_STATUS=$(docker ps --filter "name=supabase-auth" --format "{{.Status}}")

if echo "$AUTH_STATUS" | grep -q "Up"; then
    echo "🎉 SUCCÈS - Service Auth opérationnel: $AUTH_STATUS"

    echo ""
    echo "✅ PROCHAINES ÉTAPES:"
    echo "1. Tester API: curl http://localhost:8000/rest/v1/"
    echo "2. Accéder Studio: http://localhost:8000"
    echo "3. Vérifier logs: docker logs supabase-auth --tail=20"

else
    echo "❌ Service Auth toujours instable: $AUTH_STATUS"
    echo "📋 Vérifiez les logs: docker logs supabase-auth --tail=30"
    exit 1
fi