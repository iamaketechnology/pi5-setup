-- ============================================================
-- Fix Storage RLS Policies pour service_role
-- ============================================================
-- Ce script permet au service_role d'accéder à Storage
-- via l'API (nécessaire pour migration Cloud → Pi)
-- ============================================================

\echo ''
\echo '╔════════════════════════════════════════════════════╗'
\echo '║  🔧 Fix Storage RLS pour service_role             ║'
\echo '╚════════════════════════════════════════════════════╝'
\echo ''

BEGIN;

\echo '📋 Étape 1/4: Attribution des privilèges...'

-- 1. Donner tous les privilèges à service_role sur le schéma storage
GRANT USAGE ON SCHEMA storage TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA storage TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA storage TO service_role;

\echo '✅ Privilèges accordés'
\echo ''
\echo '📋 Étape 2/4: Nettoyage policies existantes...'

-- 2. Supprimer les policies existantes pour service_role (éviter les doublons)
DROP POLICY IF EXISTS "service_role_all_buckets" ON storage.buckets;
DROP POLICY IF EXISTS "service_role_all_objects" ON storage.objects;
DROP POLICY IF EXISTS "service_role_all_migrations" ON storage.migrations;

\echo '✅ Anciennes policies supprimées'
\echo ''
\echo '📋 Étape 3/4: Création nouvelles policies...'

-- 3. Créer des policies permissives pour service_role

-- Policy pour storage.buckets (liste, création, modification)
CREATE POLICY "service_role_all_buckets"
ON storage.buckets
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy pour storage.objects (fichiers)
CREATE POLICY "service_role_all_objects"
ON storage.objects
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy pour storage.migrations (si la table existe)
DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_tables
        WHERE schemaname = 'storage'
        AND tablename = 'migrations'
    ) THEN
        -- Vérifier si la policy existe déjà
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies
            WHERE schemaname = 'storage'
            AND tablename = 'migrations'
            AND policyname = 'service_role_all_migrations'
        ) THEN
            EXECUTE 'CREATE POLICY "service_role_all_migrations"
                     ON storage.migrations
                     FOR ALL TO service_role
                     USING (true) WITH CHECK (true)';
        END IF;
    END IF;
END $$;

-- 4. Vérifier que RLS est bien activé sur les tables (mais pas pour service_role)
-- RLS doit être ON pour protéger les autres rôles, mais service_role bypass tout

-- 5. Afficher résumé
SELECT
    schemaname,
    tablename,
    COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'storage'
  AND 'service_role' = ANY(roles)
GROUP BY schemaname, tablename
ORDER BY tablename;

COMMIT;

-- Message de confirmation
\echo '✅ Policies Storage configurées pour service_role'
\echo '📋 Le service_role peut maintenant accéder à Storage via API'
