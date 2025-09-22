#!/bin/bash

# Script pour corriger le problème de schéma auth dans Supabase
echo "🔧 Correction du schéma auth de Supabase..."

# 1. Arrêter le service auth qui plante
echo "📛 Arrêt du service auth..."
docker stop supabase-auth 2>/dev/null || true

# 2. Créer manuellement le schéma auth et les types nécessaires
echo "🏗️ Création du schéma auth et des types..."
docker exec supabase-db psql -U postgres -d postgres -c "
-- Créer le schéma auth s'il n'existe pas
CREATE SCHEMA IF NOT EXISTS auth;

-- Créer les types énumérés nécessaires
DO \$\$
BEGIN
    -- Créer le type factor_type s'il n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn');
    END IF;

    -- Créer le type factor_status s'il n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'factor_status' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
    END IF;

    -- Créer le type aal_level s'il n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'aal_level' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.aal_level AS ENUM ('aal1', 'aal2', 'aal3');
    END IF;

    -- Créer le type code_challenge_method s'il n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'code_challenge_method' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.code_challenge_method AS ENUM ('s256', 'plain');
    END IF;

    -- Créer le type one_time_token_type s'il n'existe pas
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'one_time_token_type' AND typnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'auth')) THEN
        CREATE TYPE auth.one_time_token_type AS ENUM (
            'confirmation_token',
            'reauthentication_token',
            'recovery_token',
            'email_change_token_new',
            'email_change_token_current',
            'phone_change_token'
        );
    END IF;
END
\$\$;

-- Accorder les permissions sur le schéma
GRANT ALL ON SCHEMA auth TO postgres;
GRANT USAGE ON SCHEMA auth TO authenticator;
GRANT ALL ON SCHEMA auth TO service_role;

-- Accorder les permissions sur les types
GRANT USAGE ON TYPE auth.factor_type TO authenticator, service_role;
GRANT USAGE ON TYPE auth.factor_status TO authenticator, service_role;
GRANT USAGE ON TYPE auth.aal_level TO authenticator, service_role;
GRANT USAGE ON TYPE auth.code_challenge_method TO authenticator, service_role;
GRANT USAGE ON TYPE auth.one_time_token_type TO authenticator, service_role;

-- Créer une extension nécessaire
CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";
"

if [ $? -eq 0 ]; then
    echo "✅ Schéma auth créé avec succès"
else
    echo "❌ Erreur lors de la création du schéma auth"
    exit 1
fi

# 3. Redémarrer le service auth
echo "🚀 Redémarrage du service auth..."
docker restart supabase-auth

# 4. Attendre quelques secondes et vérifier le statut
echo "⏳ Vérification du statut..."
sleep 5

# Vérifier si le service fonctionne
if docker logs supabase-auth --tail 10 2>&1 | grep -q "fatal\|ERROR"; then
    echo "❌ Le service auth a encore des erreurs"
    echo "📋 Logs du service auth:"
    docker logs supabase-auth --tail 20
else
    echo "✅ Service auth redémarré avec succès"
fi

# 5. Vérifier l'état des conteneurs
echo "📊 État des conteneurs Supabase:"
docker ps | grep supabase

echo "🏁 Script terminé"