# 📊 Supabase Versions - PI5-SETUP

> **Dernière mise à jour** : 2025-10-05
> **Script version** : v3.42-stable-versions-upgrade

---

## 🎯 Vue d'ensemble

Ce document liste les versions de tous les composants Supabase utilisés dans le script d'installation PI5-SETUP, comparées avec les versions officielles du repo Supabase.

---

## 📦 Versions des Composants

| Composant | Version PI5-SETUP | Version Officielle Supabase | Statut | Notes |
|-----------|-------------------|----------------------------|--------|-------|
| **PostgreSQL** | `15.8.1.060` | `15.8.1.060` | ✅ **À jour** | Optimisé pour ARM64, inclut pgjwt |
| **GoTrue (Auth)** | `v2.177.0` | `v2.177.0` | ✅ **À jour** | Service d'authentification |
| **PostgREST (REST API)** | `v12.2.12` | `v12.2.12` | ✅ **À jour** | Génération automatique API REST |
| **Realtime** | `v2.34.47` | `v2.34.47` | ✅ **À jour** | WebSockets + Broadcast + Presence |
| **Storage API** | `v1.27.6` | `v1.25.7` | ⚡ **Plus récent** | Bug fix search_path (v1.11.6 → v1.27.6) |
| **Kong (API Gateway)** | `2.8.1` | `2.8.1` | ✅ **À jour** | Reverse proxy + rate limiting |
| **Studio (UI)** | `2025.06.30-sha-6f5982d` | `2025.06.30-sha-6f5982d` | ✅ **À jour** | Interface d'administration web |
| **postgres-meta** | `v0.83.2` | *(non vérifié)* | ℹ️ **Stable** | Métadonnées PostgreSQL |
| **Edge Runtime** | `v1.58.2` | *(non vérifié)* | ℹ️ **Stable** | Fonctions serverless Deno |

---

## 📝 Notes Importantes

### Storage API v1.27.6 (Plus récent que l'officiel)

**Pourquoi ?** Bug critique dans v1.11.6 et v1.25.7 :
- ❌ **v1.11.6** : Ignore TOUS les paramètres `search_path` (DATABASE_URL, PGOPTIONS, etc.)
- ❌ **v1.25.7** : Bug potentiellement présent (non testé)
- ✅ **v1.27.6** : Bug corrigé, fonctionne nativement avec `search_path=storage,public`

**Impact** :
- Avec v1.11.6 : Nécessite workaround (copie tables `storage.*` → `public.*`)
- Avec v1.27.6 : Fonctionne nativement, pas de workaround nécessaire

**Documentation** : [STORAGE-BUG-REPORT.md](STORAGE-BUG-REPORT.md)

---

### Kong 2.8.1 (Downgrade depuis 3.0.0)

**Pourquoi ?** Alignement avec la version officielle Supabase :
- Version officielle testée et validée par Supabase
- Meilleure compatibilité avec l'écosystème
- Évite les problèmes de breaking changes de Kong 3.x

**⚠️ IMPORTANT** : Kong 2.8.1 nécessite `_format_version: "2.1"` dans kong.yml
- ❌ Kong 2.8.x ne supporte PAS `_format_version: "3.0"` (crash loop)
- ✅ Kong 2.8.x supporte : `"1.1"` et `"2.1"` uniquement
- ✅ Fix appliqué dans v3.43 : `_format_version: "2.1"`

---

## 🔄 Historique des Mises à Jour

### v3.43 (2025-10-05) - Fix Kong 2.8.1 format_version

**Changement critique** :
- 🔧 Kong : `_format_version: "3.0"` → `"2.1"` (requis pour Kong 2.8.x)

**Résolution** :
- ❌ Kong 2.8.1 crashait avec `_format_version: "3.0"` (format Kong 3.x uniquement)
- ✅ Fix : Utilisation de `_format_version: "2.1"` (compatible Kong 2.8.x)
- ✅ Test validé : Tous les services healthy (10/10)

---

### v3.42 (2025-10-05) - Alignement versions officielles

**Mises à jour** :
- ⬆️ PostgREST : `v12.2.0` → `v12.2.12`
- ⬆️ Realtime : `v2.30.23` → `v2.34.47`
- ⬇️ Kong : `3.0.0` → `2.8.1` (downgrade intentionnel)
- ⬆️ Studio : `20250106-e00ba41` → `2025.06.30-sha-6f5982d`
- ⬆️ Storage API : `v1.11.6` → `v1.27.6` (fix bug search_path)

**Objectifs** :
- ✅ Alignement avec versions officielles Supabase
- ✅ Correction bug Storage API search_path
- ✅ Stabilité et compatibilité maximales

---

### v3.41 (2025-10-04) - Fix init scripts PostgreSQL

**Changements** :
- ✅ Correction timing d'initialisation PostgreSQL
- ✅ Détection dynamique des tables Storage
- ✅ Workaround Storage conditionnel (v1.11.6 uniquement)

---

### v3.27 (2025-09-15) - Version initiale stable

**Versions initiales** :
- PostgreSQL : `15.8.1.060`
- GoTrue : `v2.177.0`
- PostgREST : `v12.2.0`
- Realtime : `v2.30.23`
- Storage API : `v1.11.6`
- Kong : `3.0.0`
- Studio : `20250106-e00ba41`

---

## 🔍 Comment Vérifier les Versions

### Sur le Raspberry Pi

```bash
# Vérifier toutes les versions installées
cd ~/stacks/supabase
docker compose ps --format "table {{.Service}}\t{{.Image}}"

# Vérifier une image spécifique
docker inspect supabase-rest | grep Image

# Logs d'un service pour voir sa version
docker logs supabase-rest 2>&1 | head -20
```

---

### Versions Officielles Supabase

**Source** : [github.com/supabase/supabase/blob/master/docker/docker-compose.yml](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml)

**Docker Hub** : [hub.docker.com/u/supabase](https://hub.docker.com/u/supabase)

**Fréquence de mise à jour** :
- Supabase met à jour les versions ~1 fois par mois
- Les versions sont "pinnées" dans le docker-compose.yml officiel

---

## ⚠️ Compatibilité ARM64

**TOUS les composants sont testés sur Raspberry Pi 5 (ARM64)** :
- ✅ Images multi-arch natives (linux/arm64)
- ✅ Performances optimisées pour ARM
- ✅ Aucune compilation requise (images pré-buildées)

**Note** : Certaines images tierces (Kong, PostgREST) supportent officiellement ARM64 depuis plusieurs versions.

---

## 🚀 Mise à Jour Manuelle

Si tu veux tester une version plus récente :

```bash
# 1. Éditer le docker-compose.yml
cd ~/stacks/supabase
nano docker-compose.yml

# 2. Modifier la ligne image: du service
# Exemple pour PostgREST :
#   image: postgrest/postgrest:v12.2.15  # (nouvelle version)

# 3. Redémarrer le service
docker compose pull postgrest
docker compose up -d postgrest

# 4. Vérifier les logs
docker logs supabase-rest --tail 50

# 5. Tester l'API REST
curl http://localhost:3000/
```

---

## 📚 Références

- **Repo officiel Supabase** : [github.com/supabase/supabase](https://github.com/supabase/supabase)
- **Docker Compose officiel** : [docker/docker-compose.yml](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml)
- **Changelog Supabase** : [supabase.com/changelog](https://supabase.com/changelog)
- **Bug Storage API** : [STORAGE-BUG-REPORT.md](STORAGE-BUG-REPORT.md)
- **Guide Migration** : [GUIDE-MIGRATION-SIMPLE.md](migration/GUIDE-MIGRATION-SIMPLE.md)

---

## ✅ Checklist de Compatibilité

Avant de mettre à jour une version, vérifier :

- [ ] L'image existe pour `linux/arm64` sur Docker Hub
- [ ] Pas de breaking changes dans le CHANGELOG du composant
- [ ] Les variables d'environnement sont compatibles
- [ ] Les health checks fonctionnent avec la nouvelle version
- [ ] Les dépendances inter-services sont respectées

---

**Version de ce document** : 1.0
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
**License** : MIT
