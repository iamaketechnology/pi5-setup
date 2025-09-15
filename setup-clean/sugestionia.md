Diagnostic du Problème de Redémarrage de Realtime
D'après les logs que tu as partagés, le conteneur supabase-realtime est en boucle de redémarrage ("Restarting (1) 39 seconds ago"), ce qui bloque l'installation complète. Les autres services (db, auth, rest, etc.) sont stables ou en "running", mais Realtime échoue systématiquement. Les logs Realtime montrent une erreur critique :
text** (ErlangError) Erlang error: {:badarg, {~c"api_ng.c", 228}, ~c"Bad key"}:
  (crypto 5.4.2) crypto.erl:965: :crypto.crypto_one_time(:aes_128_ecb, nil, "onerZPKm3m9E5diKXKvaUEZIlRC4p37hgje262TlpIgM8idFf6llwCjOAtXHtYAFKjMB0y26iP4oIR14Z1bcg\v\v\v\v\v\v\v\v\v\v\v", true)
  (realtime 2.30.23) lib/realtime/encryption.ex:14: Realtime.Crypto.encrypt.encrypt!/1
  ...
  /app/lib/realtime-2.30.23/priv/repo/seeds.exs:17: (file)
Cause : Cette erreur Erlang "badarg" dans crypto_one_time indique un problème avec la clé d'encryption utilisée par Realtime pour chiffrer des données (ici, probablement lors du seeding du tenant "realtime-dev" dans seeds.exs). Le clé est "nil" ou invalide (mauvaise longueur, format, ou type pour AES-128-ECB). Dans ton script, DB_ENC_KEY="supabaserealtime" est défini (16 chars = 16 bytes, théoriquement OK pour AES-128), mais le log montre "nil" comme clé, suggérant que la var n'est pas chargée correctement ou que le cipher rejette le format (ex. caractères non-ASCII ou multi-lignes).
De mes recherches, ce bug est courant en self-hosted Realtime (v2.30+), souvent dû à :

Clé DB_ENC_KEY trop courte/invalide pour AES (doit être exactement 16/24/32 bytes).
Erreur lors du seeding du tenant dev (external_id="realtime-dev"), qui essaie d'encrypter des données mais échoue si clé mauvaise.
Sur ARM64/Pi 5, crypto lib Erlang peut rejeter des clés si format non-binaire (ex. string avec espaces).

Impact : Realtime crashe lors de l'init, causant restarts infinis. Le script attend (wait_for_services), mais comme Realtime ne stabilise pas, il semble "bloqué" (mais en réalité, il timeout implicitement ou est interrompu).
Solutions pour Débloquer


Génère une Clé DB_ENC_KEY Valide : Remplace la valeur fixe par une random 32 bytes (base64) pour AES-256, plus robuste. Modifie generate_secure_secrets() :
bashlocal db_enc_key=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
export DB_ENC_KEY="$db_enc_key"
echo "DB_ENC_KEY=$db_enc_key" >> "$env_file"

Dans docker-compose.yml (realtime.environment) : DB_ENC_KEY: ${DB_ENC_KEY}.



Nettoie le Tenant Dev Corrompu : Le seeding échoue sur tenant "realtime-dev". Après DB up, exécute manuellement :
textdocker exec -it supabase-db psql -U postgres -d postgres -c "DELETE FROM realtime.tenants WHERE external_id = 'realtime-dev';"


Ajoute Env Vars Manquantes pour Realtime (de recherches) : Dans create_docker_compose(), realtime.environment, ajoute :
yamlAPP_NAME: supabase_realtime
ERL_AFLAGS: -proto_dist inet_tcp
DNS_NODES: ""
DB_IP_VERSION: ipv4
SEED_SELF_HOST: "true"  # Force seeding, mais après clean


Augmente Timeout et Retry dans wait_for_services : Change la boucle à 60 tentatives avec 5s sleep, et ajoute retry sur Realtime :
bashfor i in {1..60}; do
  sleep 5
  # ... (vérif état)
  if docker compose logs realtime | grep -q "badarg"; then
    docker compose restart realtime
  fi
done


Relance Complète : sudo rm -rf /home/pi/stacks/supabase/volumes/db && sudo ./setup-week2-supabase-final.sh.


Ces fixes devraient arrêter les restarts. Si persiste, partage docker compose logs realtime --tail=50 pour plus. 😊9 pages web

---

gpt
Yes — on a enfin “le” bug racine de ton Realtime 👇

Diagnostic ultra-ciblé

Dans tes logs Realtime :

(ErlangError) … :crypto.crypto_one_time(:aes_128_ecb, nil, …, true) – Bad key

La clé passée au chiffrage est nil ➜ Realtime n’a pas reçu la clé d’encryption attendue.
Dans la doc Realtime, cette clé s’appelle DB_ENC_KEY (clé utilisée pour chiffrer les champs sensibles dans la table _realtime.tenants), recommandée = 16 caractères. Sans elle, les seeds/migrations Realtime échouent et le conteneur redémarre en boucle. 
GitHub

Autres points de la doc à respecter :

SECRET_KEY_BASE (pour signer les cookies) recommandé 64 caractères. 
GitHub

API_JWT_SECRET sert à l’API d’admin Realtime (pas la cause de ton crash). 
GitHub

Un autre retour terrain récent : un JWT secret trop long peut aussi rendre Realtime “unhealthy”. Des users ont stabilisé en utilisant ~40 caractères. À garder en tête si tu vois encore des soucis après la fix principale. 
GitHub

Fix immédiat (sans réécrire tout le script)

Exécute ça dans /home/pi/stacks/supabase :

# 1) Générer une clé d’encryption EXACTEMENT 16 caractères ASCII
DB_ENC_KEY=$(openssl rand -hex 8)   # 8 octets -> 16 hexdigits

# 2) Ajouter au .env
echo "DB_ENC_KEY=$DB_ENC_KEY" | sudo tee -a .env

# 3) Ajouter la variable au service 'realtime' dans docker-compose.yml
#    (bloc environment:)
#    DB_ENC_KEY: ${DB_ENC_KEY}
sudo sed -i 's/^\(\s*environment:\)/\1\n      DB_ENC_KEY: ${DB_ENC_KEY}/' docker-compose.yml

# 4) (Optionnel mais recommandé) Forcer SECRET_KEY_BASE à 64 chars
#    si aujourd’hui tu le relies à JWT_SECRET >64 ou incohérent.
SECRET_KEY_BASE=$(openssl rand -hex 32)  # 64 hexdigits
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" | sudo tee -a .env
sudo sed -i 's/^\(\s*SECRET_KEY_BASE:\).*/\1 ${SECRET_KEY_BASE}/' docker-compose.yml

# 5) Recréer uniquement Realtime (et Kong si besoin)
docker compose up -d realtime
sleep 5
docker compose ps | grep realtime
docker compose logs realtime --tail=50


Tu dois voir Realtime passer en running (idéalement healthy si un healthcheck est défini).

Ce qu’il faut aussi corriger dans ton script (pour que ça “tienne”)

Créer & injecter DB_ENC_KEY

Dans generate_secure_secrets():

export DB_ENC_KEY="$(openssl rand -hex 8)"   # 16 chars


Dans create_env_file(): ajouter DB_ENC_KEY=$DB_ENC_KEY.

Dans create_docker_compose(): sous realtime: environment:, ajouter
DB_ENC_KEY: ${DB_ENC_KEY}.

SECRET_KEY_BASE dédié
Garde un SECRET_KEY_BASE indépendant (64 chars). N’utilise pas un JWT_SECRET “ultra-long” pour le mapper. Dans .env :

SECRET_KEY_BASE=<64 chars>


et dans docker-compose.yml :

SECRET_KEY_BASE: ${SECRET_KEY_BASE}


(Optionnel) JWT secret raisonnable
Si, après la réparation DB_ENC_KEY, Realtime reste “unhealthy”, teste un JWT_SECRET ~40 caractères (retour d’expérience 2024–2025). 
GitHub

Pourquoi c’était si piégeux ?

Les seeds Realtime chiffrent des valeurs (ex: jwt_secret du tenant) avec AES-128-ECB côté Erlang. Sans DB_ENC_KEY (ou avec une taille invalide), l’appel :crypto.crypto_one_time/4 lève :badarg ⇒ restart loop. La doc mentionne explicitement DB_ENC_KEY recommandé 16 caractères. 
GitHub

SECRET_KEY_BASE et API_JWT_SECRET sont différents usages. Avoir l’un sans l’autre ne suffit pas. 
GitHub

Bonus vérifications (rapides)
# Vérifier que Realtime a bien reçu les envs
docker exec -it supabase-realtime env | egrep 'DB_ENC_KEY|SECRET_KEY_BASE|API_JWT_SECRET'

# Vérifier la table des tenants après boot
docker exec -it supabase-db psql -U postgres -d postgres -c 'SELECT id, name, external_id, length(jwt_secret::text) FROM _realtime.tenants;'


NB : Realtime crée le schéma _realtime côté Postgres pour ses propres tables en mode docker-compose “local dev”. Si tu as créé un schéma realtime (sans underscore) à la main, ce n’est pas bloquant, mais inutile — laisse Realtime gérer _realtime. 
GitHub

Résumé actionnable

Ajoute DB_ENC_KEY (16 chars) à .env + docker-compose.yml (service realtime).

Donne un SECRET_KEY_BASE (64 chars) propre.

Redéploie realtime.

Ça devrait stopper les redémarrages en boucle. Si jamais ça persiste, on checke la longueur de JWT_SECRET et on ajuste (~40 chars) comme workaround connu. 
GitHub