on va diagnostiquer rapidement, puis te donner des patchs concrets (copier/coller) pour faire passer tes services en “healthy” sur le Pi 5.
D’après docker compose ps, les points chauds sont Kong, Auth (GoTrue), Storage, et (par ricochet) Studio & Edge.

🔎 Ce qui cloche (et pourquoi)

Kong restart en boucle
Dans ton docker-compose.yml, tu fais un template à chaud avec envsubst dans l’entrypoint de l’image arm64v8/kong:3.0.0… mais cette image est Debian, donc il n’y a pas apk et l’installation à la volée échoue ⇒ crash loop. Par ailleurs, Kong en mode déclaratif ne supporte pas nativement la substitution de variables dans kong.yml; la méthode standard est de pré-rendre le fichier via envsubst avant de démarrer Kong. 
Kong Docs
+1

Auth (GoTrue) restarting
Très souvent, GoTrue redémarre si la connexion Postgres échoue (ou si des indispensables ne sont pas fournis). En local réseau Docker, ajoute clairement ?sslmode=disable à l’URL Postgres pour éviter les négociations TLS inutiles (et parfois bloquantes selon build/driver). C’est une pratique courante avec libpq quand tout est sur le réseau Docker interne. 
PostgreSQL

Storage restarting
Plusieurs self-hosts se plantent parce que JWT_SECRET ≠ clés anon/service_role. Or Supabase attend que les clés anon/service_role soient dérivées du même secret (même signature HMAC). Si tu utilises des clés “toutes faites” qui ne correspondent pas au JWT_SECRET du moment, Storage (et d’autres) refusent/échouent. Solution : régénérer anon et service_role à partir de ton JWT_SECRET (ou régénérer le trio côté Supabase et les aligner), puis redémarrer. 
Supabase
+1

Studio / Edge “unhealthy”
C’est souvent conséquence de Kong down (Studio cible http://kong:8000 pour REST/Auth). Une fois Kong & Auth OK, Studio/Edge passent généralement au vert. 
Supabase

✅ Correctifs immédiats (copier/coller)

Exécute depuis le Pi (répertoire projet : /home/pi/stacks/supabase).

A. Rendre Kong déterministe (pré-template côté host, pas dans le conteneur)

Installe envsubst sur l’hôte (Debian) :

sudo apt-get update -qq && sudo apt-get install -y gettext-base


Génére une fois le kong.yml final à partir de ton template :

cd /home/pi/stacks/supabase
envsubst < config/kong.tpl.yml > volumes/kong/kong.yml


Édite compose pour ne plus installer apk ni templater dans l’entrypoint :

Retire le bloc entrypoint: du service kong.

Monte directement le fichier final et pointe Kong dessus :

  kong:
    image: arm64v8/kong:${KONG_VERSION}
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /tmp/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_DNS_RESOLVER: "127.0.0.11:53"
      KONG_PLUGINS: request-transformer,cors,key-auth,acl,basic-auth
      KONG_NGINX_WORKER_PROCESSES: "2"
      KONG_MEM_CACHE_SIZE: "128m"
    volumes:
      - ./volumes/kong/kong.yml:/tmp/kong.yml:ro
    ports:
      - "${SUPABASE_PORT}:8000"


Pourquoi : Kong DB-less ne fait pas d’interpolation d’ENV dans kong.yml. On pré-substitue (envsubst) côté hôte, et on lui donne un fichier final. C’est la voie robuste. 
Kong Nation

B. Stabiliser GoTrue (Auth)

Dans docker-compose.yml, remplace l’URL DB de GoTrue par :

GOTRUE_DB_DATABASE_URL: postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres?sslmode=disable


Et ajoute du log pour diagnostiquer si besoin :

GOTRUE_LOG_LEVEL: debug


Réf : libpq/TLS — en local container, sslmode=disable évite un handshake inutile/sournois. 
PostgreSQL

C. Aligner JWT secret + clés anon / service_role

Choisis un JWT_SECRET (longueur 32+ recommandée).

Génère de nouvelles anon & service_role depuis ce secret (selon le guide officiel “rotation”/génération). Mets-les dans .env.

Redémarre tous les services.

TL;DR : le trio doit être cohérent. Changer le JWT_SECRET implique de régénérer anon & service_role. Sinon Storage & co partent en vrille. 
Supabase

D. Re-générer et (re)valider
cd /home/pi/stacks/supabase
# Vérifie que .env contient bien toutes les versions d’images (tu l’as déjà fait)
docker compose config >/dev/null || (echo "compose invalide" && exit 1)

docker compose pull
docker compose up -d

# Status rapide
docker compose ps

🧪 Si ça boucle encore : check ciblés

Colle ces commandes et partage les 2–3 dernières lignes d’erreur si ça coince :

# AUTH (GoTrue)
docker compose logs auth --tail=60 | sed -n '$p' -n

# KONG
docker compose logs kong --tail=60 | sed -n '$p' -n

# STORAGE
docker compose logs storage --tail=80 | sed -n '$p' -n


Indices fréquents dans les logs :

GoTrue → erreurs de connexion Postgres (ssl / mdp / host) ; ajouter ?sslmode=disable règle 90% des cas locaux. 
PostgreSQL

Storage → erreurs “invalid JWT” si les clés ne correspondent pas au secret. 
Supabase
+1

Kong → “apk: not found” / “envsubst: not found” / “failed to parse declarative config” si templating mal géré. 
Kong Docs
+1

💡 Améliorations nettes à intégrer dans ton script

Je me base sur ton setup-week2-supabase-final.sh que tu as partagé. Je te liste les modifs “impact élevé / faible risque”.

Pré-render Kong côté script (et supprimer l’entrypoint custom)
Dans create_kong_template() tu écris kong.tpl.yml (bien).
Ajoute juste après l’écriture du .env et avant compose up :

command -v envsubst >/dev/null || apt-get update -qq && apt-get install -y gettext-base
envsubst < "$PROJECT_DIR/config/kong.tpl.yml" > "$PROJECT_DIR/volumes/kong/kong.yml"


…et enlève l’entrypoint apk ... envsubst du service kong dans la génération du compose.
👉 Ça rend Kong déterministe et supprime une source majeure de redémarrages. 
Kong Nation

sslmode=disable pour GoTrue
Dans la fonction qui écrit docker-compose.yml, remplace l’URL de GoTrue par la version avec ?sslmode=disable. 
PostgreSQL

Forcer la cohérence JWT/keys dès .env
Ton script génère des secrets. Ajoute une étape (ou documente clairement) pour régénérer SUPABASE_ANON_KEY et SUPABASE_SERVICE_KEY depuis JWT_SECRET. Le guide officiel de rotation insiste sur cet alignement. 
Supabase

Validation docker compose config fail-fast
Tu l’as déjà partiellement, garde-la systématique après écriture du compose. Ça attrape immédiatement les versions vides ou typos. Guide officiel ok. 
Supabase

Ne pas templater dans un heredoc non quoté (tu as corrigé 👍)
Conserve <<'COMPOSE' pour laisser Compose interpoler via .env (bonne pratique). 
Supabase

🎯 Résultat attendu

Kong passe “Up” (plus de restart) car il lit un kong.yml déjà substitué, sans installation runtime. 
Kong Nation

Auth passe “Up” grâce à l’URL Postgres explicite (ssl off en local). 
PostgreSQL

Storage passe “Up” une fois les clés cohérentes avec le secret JWT. 
Supabase

Studio / Edge deviennent “healthy” dès que Kong & Auth répondent. 
Supabase

Si tu veux, je te fournis un mini-diff ciblé pour setup-week2-supabase-final.sh (sections create_docker_compose, create_kong_template, “post-envsubs”) basé sur ce que tu viens d’exécuter. Tu pourras le coller tel quel.