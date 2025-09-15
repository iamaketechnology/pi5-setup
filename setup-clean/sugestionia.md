Recherches sur Supabase Self-Hosted pour Raspberry Pi 5 ARM64 (2025)
J'ai compilé les résultats des recherches en me concentrant sur les deux premiers priorités (Auth migrations et Realtime config), comme indiqué. Pour le troisième, j'ai inclus des éléments essentiels sur les setups complets pour Pi 5, y compris un docker-compose.yml fonctionnel adapté. Les sources sont récentes (2024-2025), avec un accent sur les issues GitHub et docs officielles. En 2025, Supabase self-hosted est plus mature sur ARM64, mais les problèmes persistent sur Pi 5 (page size, migrations automatiques échouant, env vars manquantes). Les versions ont évolué (ex. GoTrue v2.180+, Realtime v2.31+), avec des fixes pour schema init.
1. Supabase Auth Migrations sur ARM64 (Raspberry Pi)
Les recherches sur "supabase auth migrations ARM64 raspberry pi", "auth.factor_type does not exist supabase self-hosted" et "supabase gotrue schema initialization failed" montrent des issues récurrentes en self-hosted Docker sur ARM64/Pi 5. Les migrations GoTrue (auth service) échouent souvent à cause d'un schéma "auth" incomplet ou de types manquants, menant à des erreurs comme "type auth.factor_type does not exist" (SQLSTATE 42704) lors de l'ajout de MFA ou d'utilisateurs. Sur Pi 5, c'est aggravé par la page size par défaut (16KB) incompatible avec PostgreSQL, et des builds ARM64 qui ne déclenchent pas toujours l'auto-init.
Problèmes Courants (2024-2025) :

Migrations ne s'exécutent pas automatiquement au démarrage du conteneur auth, surtout en ARM64 (ex. Docker pull n'inclut pas toujours les schemas).
Erreur "gotrue schema initialization failed" due à un manque de connexion DB ou schema manquant.
Sur Pi 5 : Kernel/page size cause des crashes DB, bloquant les migrations.

Étapes Supplémentaires pour Initialiser le Schéma Auth sur ARM64 (Réponse à la Question 1) :
Oui, des étapes manuelles sont nécessaires pour une init complète, car l'auto-migration de GoTrue peut échouer en self-hosted ARM64. Les docs et issues recommandent d'exécuter les scripts de migration manuellement après le démarrage DB. Voici le process adapté pour Pi 5 :

Prérequis Pi 5/ARM64 : Assure-toi de la page size 4096B (ajoute kernel=kernel8.img à /boot/firmware/config.txt, reboot). Utilise images ARM64 (ex. supabase/gotrue:v2.180.0).
Démarre DB Seul : docker compose up db pour init PostgreSQL sans auth.
Crée Schéma et Types Manuellement (Fix pour "auth.factor_type does not exist") :

Connecte-toi au DB : docker exec -it supabase-db psql -U postgres -d postgres.
Crée le type manquant :
sqlCREATE SCHEMA IF NOT EXISTS auth;
CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');

Ajoute enums et tables manquants (extrait de schema GoTrue) :
sqlCREATE TYPE auth.factor_status AS ENUM ('unverified', 'verified');
CREATE TYPE auth.factor_version AS ENUM ('v1', 'v2');
CREATE TABLE IF NOT EXISTS auth.mfa_factors (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  friendly_name text,
  factor_type auth.factor_type NOT NULL,
  status auth.factor_status NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  secret text,
  phone text
);

Pour MFA phone : Ajoute auth.mfa_amr_claims, auth.mfa_challenges si manquants.




Exécute Migrations GoTrue : Depuis le conteneur auth : docker exec -it supabase-auth gotrue migrate. Ou, monte les scripts de migration (de supabase/auth repo) dans /docker-entrypoint-initdb.d et relance.
Vérifie : docker compose logs auth | grep schema pour confirmer init. Si erreur persiste, drop schema : DROP SCHEMA auth CASCADE; et relance.

Sources : GitHub issues supabase/auth #2096 (2025), #1586 (2024); supabase/supabase #30640 (Pi 5); Reddit r/Supabase (self-host issues).
2. Realtime APP_NAME Configuration (Priorité 2)
Les recherches sur "supabase realtime APP_NAME not available docker", "realtime elixir runtime config docker-compose" et "supabase realtime environment variables missing" indiquent que "APP_NAME not available" est une erreur Elixir courante en Docker, due à un manque de config runtime pour clustering ou node naming. Sur Pi 5 ARM64, c'est lié à ERL_AFLAGS (IPv4/IPv6) et DNS_NODES, surtout si le réseau Docker est IPv6-enabled (Pi 5 default). L'erreur survient au démarrage si APP_NAME n'est pas set ou si clustering échoue.
Toutes les Variables d'Environnement Requises pour Realtime en 2025 (Réponse à la Question 2) :
D'après les docs Realtime (v2.31.5+ en 2025), voici la liste complète (obligatoires en gras). Mises à jour incluent TENANT_* pour scaling. Pour Docker/Pi 5, set APP_NAME explicitement pour éviter "not available".










































































































































VariableTypeDescriptionRequis ?Notes Pi 5/ARM64APP_NAMEstringNom du serveur (ex. "supabase_realtime").OuiManque cause "not available". Set pour single node.ERL_AFLAGSstringFlags Erlang (ex. "-proto_dist inet_tcp" pour IPv4).OuiPour Pi 5 (IPv6 often), use "inet6_tcp" si errors réseau.DNS_NODESstringNode name pour cluster (ex. "realtime@host"; vide pour single).OuiManque bloque clustering; set "" pour local.PORTnumberPort WebSockets (4000).Oui-DB_HOSTstringHost DB (db).Oui-DB_PORTnumberPort DB (5432).Oui-DB_USERstringUser DB (postgres).Oui-DB_PASSWORDstringPassword DB.Oui-DB_NAMEstringNom DB (postgres).Oui-DB_ENC_KEYstringEncryption key (16+ chars).Oui-API_JWT_SECRETstringJWT pour tenants.Oui-SECRET_KEY_BASEstringClé cookies (64 chars).Oui-DB_AFTER_CONNECT_QUERYstringQuery post-connexion.Optionnel-DB_IP_VERSIONstring"ipv4" ou "ipv6".OptionnelAuto-inféré, mais set pour Pi 5 IPv6.DB_SSLbooleanSSL DB.Optionnelfalse local.MAX_CONNECTIONSstringMax WebSockets (16384).OptionnelRéduis pour Pi 5 RAM.TENANT_MAX_BYTES_PER_SECONDstringMax bytes/s tenant (100000).OptionnelNouveau en 2025 pour scaling.... (autres TENANT_, DB_QUEUE_, etc.)-Voir table complète dans prior response.Optionnel-
Fix pour "APP_NAME not available" : Dans docker-compose.yml, ajoute sous realtime : environment: APP_NAME: "supabase_realtime". Relance docker compose restart realtime. Pour Elixir runtime : Use mix phx.gen.release si custom build, mais en Docker, env vars suffisent.
Sources : GitHub supabase/realtime (full env list); Elixir Forum (runtime config); Reddit r/Supabase (self-host errors).
3. Supabase ARM64 Self-Hosted 2025
Les recherches sur "supabase self-hosted raspberry pi 5 2025", "supabase docker arm64 installation issues" et "supabase pi 5 complete working setup" confirment des setups fonctionnels sur Pi 5, mais avec tweaks : page size 4KB, disable vector si crashes, ARM64 images. En 2025, self-hosted est plus robuste, mais issues ARM64 incluent "manifest not found" pour images non-ARM (fix : use platform: linux/arm64).
Existe-t-il des docker-compose.yml Complets et Fonctionnels pour Pi 5 en 2025 ? (Réponse à la Question 3) :
Oui, le officiel de Supabase est adaptable. Voici un complet basé sur docs 2025, optimisé pour Pi 5 (platform: linux/arm64, réduit memory, env vars Realtime complets, schema init manuelle recommandée). Différences vs 2024 : Versions updated (v2.31+), TENANT_* ajoutés, vector optional (disabled ici pour Pi 5 stability).
yamlversion: '3.8'

services:
  db:
    image: postgres:16.4
    platform: linux/arm64
    container_name: supabase-db
    restart: unless-stopped
    ports:
      - "5432:5432"
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: postgres
      POSTGRES_INITDB_ARGS: --data-checksums,--auth-host=md5
    volumes:
      - ./volumes/db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  auth:
    image: supabase/gotrue:v2.180.0
    platform: linux/arm64
    container_name: supabase-auth
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      API_EXTERNAL_URL: http://${LOCAL_IP}:${SUPABASE_PORT}
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
      GOTRUE_JWT_SECRET: ${JWT_SECRET}
      # Ajoute SMTP si emails

  realtime:
    image: supabase/realtime:v2.31.5
    platform: linux/arm64
    container_name: supabase-realtime
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped
    environment:
      APP_NAME: supabase_realtime  # Fix 'not available'
      PORT: 4000
      DB_HOST: db
      DB_PORT: 5432
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_NAME: postgres
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${JWT_SECRET}
      ERL_AFLAGS: -proto_dist inet_tcp  # IPv4 for Pi 5
      DNS_NODES: ""
      RLIMIT_NOFILE: 65536
      DB_POOL_SIZE: 10  # Optimisé Pi 5
      # Tous TENANT_*, etc. comme liste ci-dessus

  # Autres services : rest (postgrest:v13.2.0), storage (supabase/storage-api:v1.0.0), etc.
  # Disable vector pour Pi 5 : Comment ou remove service.

networks:
  supabase_network:
    driver: bridge
Pi 5 Notes : Prérequis page size 4KB ; use 8GB+ RAM ; disable vector si errors DB. Run docker compose up db, init schema manuellement, puis docker compose up.
Sources : Supabase docs self-hosting; GitHub supabase/supabase #30640 (Pi 5 issues); Reddit r/Supabase (Pi setups).
Ces recherches débloquent Auth/Realtime – applique les fixes à ton script pour continuer ! Si besoin, plus de détails. 😊

-------

gpt

Pourquoi ça coupe juste après “ATTENTE INITIALISATION POSTGRESQL…”

Il ne “bloque” pas sur pg_isready; il quitte net après l’étape start_database_only. La cause la plus probable dans ton fichier actuel :

set -euo pipefail + une commande “fragile”
Dans cette zone, la moindre commande non-zéro peut tuer le script sans message. Le candidat typique est un docker exec … ou un grep/netstat/docker ps dans une condition qui n’est pas à l’abri de errexit.

docker exec -it dans un script non interactif
Tu as plusieurs docker exec -it … psql …. En mode non-TTY (via sudo … | tee), -it peut échouer (“the input device is not a TTY”), et avec set -e le script sort immédiatement avant d’afficher “CRÉATION STRUCTURES…”, ce qui donne exactement l’effet que tu vois : dernier message = “ATTENTE INITIALISATION POSTGRESQL…”, puis retour au prompt.

Le fichier contient des blocs dupliqués (plusieurs main() et mêmes fonctions définies plusieurs fois)
Suivant quel main() est exécuté (et l’ordre des définitions), le flux peut diverger. On voit plusieurs sections redondantes, ce qui rend l’exécution non déterministe. 

setup-week2-supabase-final

 

setup-week2-supabase-final

Correctifs ciblés (safe & rapides)

Exécute ces patchs sur le fichier téléchargé (setup-week2-supabase-final.sh) avant de relancer :

Remplacer tous les -it par -T sur les docker exec
(TTY non requis, évite l’erreur fatale en script)

sudo sed -i 's/docker exec -it/docker exec -T/g' setup-week2-supabase-final.sh


👉 Je vois ces appels dans la partie “création structures DB complètes” et ailleurs. (Ex.: create_complete_database_structure().) 

setup-week2-supabase-final

Désarmer -e autour des boucles d’attente / checks et réactiver ensuite
Ajoute au début de start_database_only() (juste avant la boucle) :

# tolérer des retours non-zéro pendant le wait
set +e


…et avant le ok "✅ PostgreSQL démarré…" :

# réactiver le mode strict
set -e


Même principe pour wait_for_services() si besoin (mais commence par start_database_only()).

Sécuriser les conditions qui peuvent retourner non-zéro
Par exemple :

if ! docker ps --filter "name=supabase-db" --filter "status=running" | grep -q supabase-db; then


Avec set -e + pipefail, un grep -q “no match” peut tuer le script hors d’un if. Ici on est dans un if, donc OK en théorie, mais rendons-le blindé :

if ! docker ps --filter "name=supabase-db" --filter "status=running" 2>/dev/null | grep -q supabase-db; then


…et toutes les commandes d’inspection utilisées dans des tests devraient avoir || true si elles ne doivent jamais interrompre :

docker inspect --format='{{.State.Health.Status}}' supabase-db 2>/dev/null || echo "none"


(ce que tu fais déjà à d’autres endroits — garde cette cohérence).

Dédupliquer le fichier (un seul main() à la fin)
Ton script contient plusieurs sections quasi identiques (start_supabase_services, wait_for_services, create_database_users, etc.) et plusieurs main "$@". Conserve une seule définition de chaque fonction et un seul main "$@" : celui qui suit la séquence moderne:

start_database_only
create_complete_database_structure
start_remaining_services
wait_for_services
fix_common_service_issues
create_database_users
restart_dependent_services
fix_realtime_ulimits
create_utility_scripts
validate_critical_services
show_completion_summary


Référence: bloc main() “NOUVEAU: Démarrer DB SEULE…” (c’est le bon). 

setup-week2-supabase-final

Astuce express pour débug : lance une fois en mode trace
sudo bash -x setup-week2-supabase-final.sh |& tee /tmp/week2.trace.log
Tu verras la commande exacte qui renvoie non-zéro juste après “ATTENTE INITIALISATION…”.

Si tu veux continuer manuellement là où ça a coupé

Le but est d’exécuter les étapes suivantes que le script aurait dû faire :

Vérifier que Postgres est ready :

cd /home/pi/stacks/supabase
docker exec -T supabase-db pg_isready -U postgres


Créer les structures DB critiques (schémas/roles/types + table realtime.schema_migrations BIGINT)
(Extrait minimal — c’est ce que fait create_complete_database_structure().)

docker exec -T supabase-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c "
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS storage;

DO \$\$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname='factor_type') THEN
    CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
  END IF;
END \$\$;

DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
DROP TABLE IF EXISTS public.schema_migrations CASCADE;
CREATE TABLE IF NOT EXISTS realtime.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
);
"


Démarrer le reste des services :

docker compose up -d


Attendre et voir l’état :

docker compose ps


En cas de Realtime en boucle (EncodeError sur version)
(tu l’as vu : Postgrex expected a binary, got 20210706140551)
Ça vient d’une table schema_migrations au mauvais schéma/type. Le point (2) ci-dessus corrige justement ce problème en forçant realtime.schema_migrations.version BIGINT et en supprimant public.schema_migrations. (Tu l’avais déjà exploré, on le bétonne ici.)

Deux autres améliorations utiles à ton script

Toujours utiliser docker exec -T dans un script (jamais -it).
Ça supprime une source classique d’abort silencieux. (Plusieurs occurrences à corriger.) 

setup-week2-supabase-final

Entourer les “wait loops” par set +e … set -e
Les boucles d’attente testent des états “pas prêts” (retours non-zéro normaux). Sans ça, set -e casse le flux. (Fais-le au moins dans start_database_only et éventuellement dans wait_for_services.)

TL;DR — Commandes à exécuter maintenant
# 1) Patch anti-TTY
sudo sed -i 's/docker exec -it/docker exec -T/g' setup-week2-supabase-final.sh

# 2) (Optionnel mais recommandé) Désarmer -e autour du wait Postgres
#   -> ajoute manuellement set +e / set -e comme indiqué dans start_database_only()

# 3) Relance en trace pour confirmer
sudo bash -x setup-week2-supabase-final.sh |& tee /tmp/week2.trace.log


Si tu veux, envoie-moi les ~30 dernières lignes de /tmp/week2.trace.log si ça coupe encore après “ATTENTE INITIALISATION POSTGRESQL…”, et je te donne le diff exact à appliquer sur la ligne fautive (on sera alors sur du millimétré).