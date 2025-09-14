# 🔧 Supabase Docker Errors & Solutions - Documentation Complète

## 📋 Résumé des Problèmes Identifiés

Suite aux recherches web approfondies, voici les solutions documentées pour les erreurs Supabase sur Pi 5 :

---

## 1. 🔴 Auth : Migrations échouent - "type auth.factor_type does not exist"

### Erreur Complète
```
ERROR: type "auth.factor_type" does not exist (SQLSTATE 42704)
error executing migrations/20240729123726_add_mfa_phone_config.up.sql
```

### Causes Principales
- **Schéma modifié** : Modifications dans le schéma `auth` (colonnes, tables, RLS)
- **Problèmes de propriété** : Le rôle `supabase_auth_admin` a perdu ses privilèges
- **Modifications personnalisées** : Ajout de RLS ou modifications manuelles du schéma
- **Bug de migration** : Issue GitHub #1729 (août 2024) avec MFA phone configuration

### Solutions

#### Solution 1 : Créer le schéma auth complet
```sql
-- Créer le schéma auth et les types nécessaires
CREATE SCHEMA IF NOT EXISTS auth;

-- Créer le type factor_type
CREATE TYPE auth.factor_type AS ENUM ('totp', 'webauthn');

-- Créer les tables auth nécessaires
CREATE TABLE IF NOT EXISTS auth.users (...);
CREATE TABLE IF NOT EXISTS auth.mfa_factors (...);
CREATE TABLE IF NOT EXISTS auth.mfa_challenges (...);
```

#### Solution 2 : Restaurer les privilèges
```sql
-- Restaurer les privilèges pour supabase_auth_admin
GRANT ALL ON SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL TABLES IN SCHEMA auth TO supabase_auth_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA auth TO supabase_auth_admin;
```

#### Solution 3 : Supprimer les modifications personnalisées
- Supprimer toute RLS ajoutée manuellement
- Restaurer le schéma auth à sa forme originale
- Éviter l'utilisation d'ORMs externes (Prisma) sur le schéma auth

---

## 2. 🔴 Kong : Permission denied sur kong.yml

### Erreur Complète
```
nginx: [error] init_by_lua error: /usr/local/share/lua/5.1/kong/init.lua:568:
error parsing declarative config file /var/lib/kong/kong.yml: Permission denied
```

### Causes Principales
- **Permissions de fichier** : docker-entrypoint.sh manque de permissions d'exécution
- **Permissions de répertoire** : /usr/local/kong a des permissions incorrectes
- **ARM64 compatibility** : Problèmes spécifiques à l'architecture ARM64
- **Version Kong** : Versions < 1.3 ne supportent pas ARM64

### Solutions

#### Solution 1 : Corriger les permissions
```bash
# Permissions pour kong.yml
sudo chown -R 100:101 volumes/kong/
sudo chmod 644 volumes/kong/kong.yml

# Permissions pour le conteneur
docker exec supabase-kong chmod +x /docker-entrypoint.sh
docker exec supabase-kong chown -R kong:kong /usr/local/kong
```

#### Solution 2 : Monter le volume correctement
```yaml
kong:
  volumes:
    - ./volumes/kong:/var/lib/kong:ro  # Read-only pour éviter les problèmes
    - ./kong.yml:/usr/local/kong/kong.yml:ro
```

#### Solution 3 : Utiliser l'image ARM64
```yaml
kong:
  image: arm64v8/kong:3.0.0  # Image spécifique ARM64
  # ou
  image: kong:3.0.0
  platform: linux/arm64
```

---

## 3. 🔴 Realtime : Variable RLIMIT_NOFILE manquante

### Erreur Complète
```
/app/run.sh: line 6: RLIMIT_NOFILE: unbound variable
```

### Cause
Le script `run.sh` de Realtime essaie d'utiliser la variable `RLIMIT_NOFILE` qui n'est pas définie

### Solutions Validées

#### Solution 1 : Ajouter la variable d'environnement (RECOMMANDÉ)
```yaml
realtime:
  environment:
    # ... autres variables ...
    RLIMIT_NOFILE: "10000"  # Valeur recommandée
    SEED_SELF_HOST: true    # Important pour self-hosted
```

#### Solution 2 : Configuration Docker daemon globale
```json
// /etc/docker/daemon.json
{
  "default-ulimits": {
    "nofile": {
      "Hard": 64000,
      "Name": "nofile",
      "Soft": 64000
    }
  }
}
```
Puis redémarrer Docker : `sudo systemctl restart docker`

#### Solution 3 : Docker Compose avec ulimits
```yaml
realtime:
  ulimits:
    nofile:
      soft: 10000
      hard: 10000
```

---

## 4. 🔴 Storage : "role authenticated does not exist"

### Erreur Complète
```
Migration failed. Reason: An error occurred running 's3-multipart-uploads'.
Rolled back this migration. Reason: role "authenticated" does not exist
```

### Causes
- Rôles PostgreSQL non créés lors de l'initialisation
- Ordre de création des services incorrect
- Scripts d'initialisation non exécutés

### Solutions

#### Solution 1 : Créer les rôles manquants
```sql
-- Créer les rôles nécessaires
CREATE ROLE authenticated NOLOGIN NOINHERIT;
CREATE ROLE anon NOLOGIN NOINHERIT;
CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;

-- Accorder les permissions
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated, anon, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated, anon, service_role;
```

#### Solution 2 : Assurer l'ordre de démarrage
```yaml
storage:
  depends_on:
    db:
      condition: service_healthy
    auth:
      condition: service_started  # Auth doit démarrer avant Storage
```

---

## 5. 🔴 Edge Functions : Affiche le menu d'aide au lieu de démarrer

### Erreur
Le conteneur edge-functions affiche le menu d'aide au lieu de démarrer le service

### Cause
Mauvais format de la commande dans docker-compose.yml

### Solutions

#### Solution 1 : Corriger le format de commande
```yaml
edge-functions:
  image: supabase/edge-runtime:v1.58.2
  command:
    - start
    - --main-service
    - /home/deno/functions/main
  # OU en une ligne
  command: ["start", "--main-service", "/home/deno/functions/main"]
```

#### Solution 2 : Configuration complète
```yaml
edge-functions:
  container_name: supabase-edge-functions
  image: supabase/edge-runtime:v1.58.2
  restart: unless-stopped
  environment:
    JWT_SECRET: ${JWT_SECRET}
    SUPABASE_URL: http://kong:8000
    SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
    SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
  volumes:
    - ./volumes/functions:/home/deno/functions:z
  command:
    - start
    - --main-service
    - /home/deno/functions/main
  ports:
    - "54321:9000"
```

---

## 6. 🟡 Problème d'Entropie Système (Bonus)

### Symptôme
```
⚠️ Entropie système faible (256) - peut causer blocages
```

### Solution
```bash
# Installer haveged pour augmenter l'entropie
sudo apt update
sudo apt install -y haveged
sudo systemctl enable haveged
sudo systemctl start haveged

# Vérifier l'entropie
cat /proc/sys/kernel/random/entropy_avail  # Doit être > 1000
```

---

## 🎯 Script de Correction Global

```bash
#!/bin/bash
# fix-all-supabase-issues.sh

# 1. Arrêter tous les services
docker compose down

# 2. Nettoyer les volumes problématiques
sudo rm -rf volumes/db/data

# 3. Corriger les permissions
sudo chown -R 100:101 volumes/kong/
sudo chmod 644 volumes/kong/kong.yml

# 4. Corriger docker-compose.yml
# - Ajouter RLIMIT_NOFILE: "10000" à realtime
# - Corriger command edge-functions
# - Vérifier tous les environment variables

# 5. Redémarrer avec initialisation propre
docker compose up -d db
sleep 30

# 6. Créer les rôles manquants
docker compose exec -T db psql -U postgres << SQL
CREATE SCHEMA IF NOT EXISTS auth;
CREATE ROLE IF NOT EXISTS authenticated NOLOGIN;
CREATE ROLE IF NOT EXISTS anon NOLOGIN;
CREATE ROLE IF NOT EXISTS service_role NOLOGIN BYPASSRLS;
GRANT USAGE ON SCHEMA public TO authenticated, anon, service_role;
SQL

# 7. Démarrer tous les services
docker compose up -d
```

---

## 📚 Références

- **GitHub Issues** :
  - [Auth migrations #1729](https://github.com/supabase/auth/issues/1729)
  - [Password auth failed #18836](https://github.com/supabase/supabase/issues/18836)
  - [Kong ARM support #39](https://github.com/Kong/docker-kong/issues/39)
  - [Realtime RLIMIT discussion #18228](https://github.com/orgs/supabase/discussions/18228)

- **Articles** :
  - [Medium: Fix Supabase Realtime Restarting](https://medium.com/@wdedweliwaththa/how-to-fix-supabase-realtime-service-restarting-issue-in-self-hosted-environments-788d2768588c)
  - [Supabase Self-Hosting Docs](https://supabase.com/docs/guides/self-hosting/docker)

---

**📝 Note** : Ces solutions sont basées sur les recherches web et les problèmes connus de la communauté Supabase pour les installations self-hosted sur ARM64/Pi 5.