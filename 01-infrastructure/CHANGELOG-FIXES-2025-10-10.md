# 🔧 CHANGELOG - Corrections du 2025-10-10

**Résumé** : Corrections critiques pour DNS Docker Compose et PostgreSQL `shared_preload_libraries`

---

## 🎯 Problèmes identifiés et corrigés

### 1. ❌ DNS Docker Compose - Services multi-réseaux sans alias

**Symptôme** :
- Studio ne pouvait pas résoudre `kong`, `meta`, etc.
- Erreurs 404 sur `/api/platform/pg-meta/default/query`
- `docker exec supabase-studio getent hosts kong` → échouait

**Cause racine** :
Quand un service Docker Compose utilise une **liste simple de réseaux** :
```yaml
networks:
  - default
  - traefik
```
Docker Compose **ne crée PAS d'alias DNS automatiques** sur le réseau `default`.

**Solution appliquée** :
Utiliser la **forme longue avec aliases explicites** :
```yaml
networks:
  default:
    aliases:
      - kong  # ou studio
  traefik: {}
```

**Fichiers modifiés** :
- ✅ `01-infrastructure/traefik/scripts/02-integrate-supabase.sh` (lignes 422-440)
  - Fonction `add_traefik_network()` réécrite
  - Utilise `yq eval -i 'del(.services.kong.networks)'` puis recrée avec aliases
  - Kong et Studio ont maintenant les alias DNS `kong` et `studio`

**Test de validation** :
```bash
docker exec supabase-studio getent hosts kong
# Output attendu: 172.18.0.10  kong
```

---

### 2. ❌ PostgreSQL `shared_preload_libraries` manquant

**Symptôme** :
- Erreurs dans logs Meta : `pg_stat_statements must be loaded via shared_preload_libraries`
- Erreurs 400 dans console navigateur sur requêtes Meta
- Fonctionnalités de monitoring/stats PostgreSQL non disponibles

**Cause racine** :
La commande PostgreSQL dans `docker-compose.yml` ne spécifiait pas `-c shared_preload_libraries=...`.

Le fichier `/etc/postgresql/postgresql.conf` contient bien la directive, **mais elle est ignorée** car la commande Docker override les paramètres.

**Solution appliquée** :
Ajouter la directive dans la commande PostgreSQL du docker-compose.yml :

```yaml
command: >
  postgres
  -c listen_addresses=*
  -c shared_preload_libraries='pg_stat_statements,pgaudit,plpgsql,plpgsql_check,pg_cron,pg_net,pgsodium,timescaledb,auto_explain,pg_tle,plan_filter,supabase_vault'
  -c shared_buffers=${POSTGRES_SHARED_BUFFERS}
  # ... autres paramètres
```

**Fichiers modifiés** :
- ✅ `01-infrastructure/supabase/scripts/02-supabase-deploy.sh` (ligne 685)
  - Template docker-compose.yml généré avec `shared_preload_libraries`

**Test de validation** :
```bash
docker exec -e PGPASSWORD=xxx supabase-db psql -U postgres -c 'SHOW shared_preload_libraries;'
# Output attendu: pg_stat_statements,pgaudit,plpgsql,...
```

---

### 3. ✅ Confirmation automatique pour scénario DuckDNS

**Problème** :
Script `02-integrate-supabase.sh` bloquait sur `read -p "Proceed..."` quand exécuté via pipe (`curl | bash`).

**Solution** :
Auto-confirmation pour le scénario DuckDNS (toutes les infos sont auto-détectées) :

```bash
if [[ "$TRAEFIK_SCENARIO" = "duckdns" ]]; then
    ok "Auto-confirming for DuckDNS scenario (fully auto-detected)"
else
    read -p "Proceed with this configuration? [y/N]: " -n 1 -r
    # ...
fi
```

**Fichier modifié** :
- ✅ `01-infrastructure/traefik/scripts/02-integrate-supabase.sh` (lignes 297-306)

---

## 📊 Récapitulatif des fichiers modifiés

| Fichier | Modification | Impact |
|---------|-------------|--------|
| `traefik/scripts/02-integrate-supabase.sh` | Réseaux avec aliases DNS + auto-confirm | ✅ Critique |
| `supabase/scripts/02-supabase-deploy.sh` | Commande PostgreSQL avec `shared_preload_libraries` | ✅ Critique |

---

## 🔍 Tests de validation recommandés

### Test 1 : Installation fraîche complète
```bash
# Sur Pi vierge
curl -fsSL https://raw.githubusercontent.com/.../01-prerequisites-setup.sh | sudo bash
sudo reboot

# Après reboot
curl -fsSL https://raw.githubusercontent.com/.../02-supabase-deploy.sh | sudo bash

# Vérifier PostgreSQL
docker exec -e PGPASSWORD=$(grep POSTGRES_PASSWORD /home/pi/stacks/supabase/.env | cut -d= -f2) \
  supabase-db psql -U postgres -c 'SHOW shared_preload_libraries;'

# Doit afficher: pg_stat_statements,pgaudit,...

# Installer Traefik
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash
# [Entrer credentials DuckDNS]

# Intégrer Supabase (DOIT être autonome, sans prompt)
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-supabase.sh | sudo bash

# Vérifier DNS
docker exec supabase-studio getent hosts kong
# Doit résoudre: 172.18.0.x  kong
```

### Test 2 : Logs sans erreurs
```bash
# Aucune erreur pg_stat_statements dans Meta
docker logs supabase-meta --since 5m 2>&1 | grep -i 'pg_stat_statements'
# Output attendu: (vide)

# Tous les services healthy
docker ps --filter 'name=supabase' --format '{{.Names}}\t{{.Status}}' | grep -v 'healthy'
# Output attendu: (vide ou seulement warnings bénins)
```

### Test 3 : Studio fonctionnel
- Accéder à `http://192.168.1.74:3000/project/default`
- Onglet "Table Editor" doit afficher les tables
- Onglet "SQL Editor" doit fonctionner
- Console navigateur : **404 sur `/api/v1/projects/default/api-keys` est NORMAL** (API Cloud uniquement)

---

## 📝 Erreurs console attendues (NORMALES)

Ces erreurs sont **bénignes** en self-hosted et n'empêchent pas le fonctionnement :

### ✅ Erreur 404 API Keys
```
GET /api/v1/projects/default/api-keys 404 (Not Found)
```
**Raison** : Cette API fait partie du management Supabase Cloud, pas disponible en self-hosted.
**Impact** : Aucun, les clés sont dans `.env`

### ✅ Erreur crypto.randomUUID
```
TypeError: crypto.randomUUID is not a function
```
**Raison** : Fonction HTTP seulement (fonctionne en HTTPS)
**Impact** : Mineur, certaines fonctionnalités UI peuvent être limitées

### ✅ Warnings Stripe
```
You may test your Stripe.js integration over HTTP...
```
**Raison** : Stripe nécessite HTTPS en production
**Impact** : Aucun (billing désactivé en self-hosted)

### ✅ Multiple GoTrueClient instances
```
Multiple GoTrueClient instances detected...
```
**Raison** : Warning informatif
**Impact** : Aucun

---

## 🚀 Prochaine installation

Pour une installation complète sur Pi vierge :

```bash
# 1. Prérequis (avec reboot)
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# 2. Supabase (avec fix shared_preload_libraries)
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# 3. Traefik DuckDNS
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
# [Entrer DUCKDNS_SUBDOMAIN et TOKEN]

# 4. Intégration (100% autonome maintenant!)
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

**Résultat attendu** :
- ✅ Tous les services healthy
- ✅ Studio accessible en local (`http://192.168.1.74:3000`)
- ✅ API accessible via HTTPS (`https://votre-domaine.duckdns.org/api/...`)
- ✅ Logs sans erreurs critiques
- ✅ DNS interne fonctionnel (`kong`, `studio`, `meta`, etc.)

---

## 🔗 Références

**Documentation Docker Compose réseaux** :
- [Networks top-level element](https://docs.docker.com/compose/compose-file/06-networks/)
- [Network configuration reference](https://docs.docker.com/compose/compose-file/compose-file-v3/#networks)

**Issue GitHub similaire** :
- [Docker Compose - Aliases not created with multiple networks](https://github.com/docker/compose/issues/xxxx)

**PostgreSQL shared_preload_libraries** :
- [PostgreSQL documentation](https://www.postgresql.org/docs/15/runtime-config-client.html#GUC-SHARED-PRELOAD-LIBRARIES)
- [pg_stat_statements extension](https://www.postgresql.org/docs/15/pgstatstatements.html)

---

**Version** : 1.0
**Date** : 2025-10-10
**Testeur** : @iamaketechnology
**Status** : ✅ Validé sur Raspberry Pi 5 (ARM64)
