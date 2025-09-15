Yes — on va droit au but. Tes logs Realtime montrent :

** (DBConnection.EncodeError) Postgrex expected a binary, got 20210706140551


Ça survient pendant l’étape “Running migrations” juste après CreateTenants. En Ecto/Postgrex, ce message apparaît typiquement quand la colonne cible est de type texte (binary) alors que le code tente d’insérer un entier. Pour les migrations Ecto, la table des migrations s’appelle schema_migrations et la colonne version est censée être un BIGINT (entier 64 bits). Si elle est en text, on obtient exactement ce mismatch. Les docs d’Ecto confirment que la colonne version est en bigint par défaut, avec une note spéciale pour les projets qui auraient historiquement stocké la version en texte. 
hexdocs.pm
+1

En self-hosted Supabase, Realtime tient son propre registre de migrations dans le schéma realtime (ex. realtime.schema_migrations), et crée aussi ses tables (realtime.tenants, etc.). Plusieurs fils (CLI/StackOverflow/Discord) montrent que si ce schéma/table n’existent pas ou ont un mauvais type, Realtime boucle au démarrage. 
Stack Overflow
+2
GitHub
+2

La page “Realtime Self-hosting Config” donne la liste complète des variables à fournir (PORT, DB_*, SLOT_NAME, PUBLICATIONS, RLIMIT_NOFILE, etc.) — on s’en est déjà occupé, mais je la cite pour référence. 
Supabase

Fix ciblé (2 étapes)
1) Vérifier et corriger la table realtime.schema_migrations

Exécute ces commandes pour voir le type réel de la colonne version :

# 1) Le schéma realtime existe-t-il ?
docker exec -it supabase-db psql -U postgres -d postgres -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name='realtime';"

# 2) La table schema_migrations (dans le schéma realtime) et le type de colonnes
docker exec -it supabase-db psql -U postgres -d postgres -c "
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema='realtime' AND table_name='schema_migrations'
ORDER BY ordinal_position;
"

Si la table n’existe pas (ou est en mauvais type)

Crée/répare-la en BIGINT comme attendu par Ecto :

docker exec -i supabase-db psql -U postgres -d postgres <<'SQL'
CREATE SCHEMA IF NOT EXISTS realtime;

-- S'il existe déjà une table en text, on la renomme pour audit
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema='realtime' AND table_name='schema_migrations'
  ) THEN
    -- Vérifier le type; si text, on renomme puis on recrée proprement
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='realtime' AND table_name='schema_migrations'
        AND column_name='version' AND data_type IN ('text','character varying')
    ) THEN
      ALTER TABLE realtime.schema_migrations RENAME TO schema_migrations_backup_textver;
    END IF;
  END IF;
END$$;

-- Table au format attendu par Ecto (version = BIGINT)
CREATE TABLE IF NOT EXISTS realtime.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE
);
SQL


Contexte : Ecto écrit des entiers (timestamps numériques) dans schema_migrations. Si la colonne est text, Postgrex hurle “expected a binary, got 202107…”. Les docs Ecto décrivent bien ce mécanisme et la préférence BIGINT pour version. 
hexdocs.pm
+1

Ensuite redémarre Realtime :

docker compose restart realtime
docker compose logs realtime --tail=80


Tu dois voir la séquence “Running migrations” puis le conteneur rester Up.

2) Vérifier que les tables Realtime sont bien dans le schéma realtime

Tes logs montrent create table tenants mais n’indiquent pas le schéma dans la sortie. Realtime moderne est multi-tenant, attend une table realtime.tenants, et utilise realtime.schema_migrations. Si, par un décalage de search_path, les objets se créent dans public, ça peut créer des incohérences.

Vérifie :

# Quelles tables dans le schéma realtime ?
docker exec -it supabase-db psql -U postgres -d postgres -c "
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema='realtime'
ORDER BY table_name;
"

# Et dans public (au cas où) :
docker exec -it supabase-db psql -U postgres -d postgres -c "
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema='public' AND table_name IN ('tenants','schema_migrations')
ORDER BY table_name;
"


Si tu trouves public.tenants : supprime-la (ou renomme-la) et laisse Realtime la régénérer dans realtime, ou bien déplace-la :

-- à n'utiliser que si une mauvaise table a été créée dans public par erreur
docker exec -i supabase-db psql -U postgres -d postgres <<'SQL'
ALTER TABLE IF EXISTS public.tenants SET SCHEMA realtime;
SQL


Puis :

docker compose restart realtime


Indice : des fils récents confirment les erreurs “tenant not found”/“tenants does not exist” si la structure multi-tenant n’est pas là dans le bon schéma. 
Supabase
+1

Checks complémentaires (rapides)

Publication et réplication logique (Realtime)
Assure-toi que la publication mentionnée dans PUBLICATIONS existe et que Postgres est en wal_level=logical. Les prérequis et variables obligatoires sont listés dans la doc “Realtime Self-hosting Config”. 
Supabase

RLIMIT_NOFILE et ulimits
Tu as déjà un ulimit -n 65536 dans les logs (bien). Conserve ulimits.nofile côté compose et la variable RLIMIT_NOFILE côté Realtime pour éviter les boucles dues aux FDs, un problème remonté en self-hosted. 
Supabase

Auth / JWT
Garde JWT_SECRET cohérent avec ANON_KEY/SERVICE_ROLE_KEY pour ne pas faire planter Storage/Auth qui valident les JWT. Les guides Supabase et discussions migration le rappellent. 
Supabase

Pourquoi je suis confiant que c’est bien ça

Le message “expected a binary, got 20210706140551” colle à un mismatch “text vs bigint” sur la table de migrations Ecto. Les docs Ecto confirment le BIGINT attendu pour version. 
hexdocs.pm

Les threads Supabase montrent que Realtime gère ses migrations dans son propre schéma et échoue si ce schéma/table n’existent pas (ou sont “cassés”). 
Stack Overflow
+1

Ta requête SELECT * FROM schema_migrations a listé uniquement public.schema_migrations — donc on ne voit pas realtime.schema_migrations chez toi, ce qui explique la boucle et/ou la recréation partielle puis l’erreur au moment d’enregistrer la version.

Si jamais ça bloque encore (rare)

Envoie-moi la sortie de :

docker exec -it supabase-db psql -U postgres -d postgres -c "\d+ realtime.schema_migrations"
docker exec -it supabase-db psql -U postgres -d postgres -c "\d+ realtime.tenants"
docker compose logs realtime --tail=120


Je te ferai un patch SQL minimal selon l’état (ex. conversion de type version → BIGINT, déplacement de tables, etc.), puis on verrouille ça dans ton script semaine 2 (création du schéma realtime + table schema_migrations en BIGINT avant de lancer le conteneur), pour que ce bug ne revienne plus.

—

Réfs utiles :
• Realtime – Self-hosting Config (env obligatoires). 
Supabase

• Ecto SQL – schema_migrations.version en BIGINT (et compat string via :migration_cast_version_column). 
hexdocs.pm
+1

• Issues/threads Supabase sur realtime.schema_migrations / tables Realtime créées/supprimées. 
Stack Overflow
+1

• Concept multi-tenant Realtime (tenants requis). 
Supabase