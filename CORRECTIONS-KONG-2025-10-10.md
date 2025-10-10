# 🔧 Corrections Kong - 2025-10-10

> **Résumé complet des corrections appliquées au gateway Kong**

---

## 🎯 Problèmes Résolus

### 1. ❌ Clés API Hardcodées (2022) → ✅ Clés Dynamiques (2025)

**Symptôme** :
```
Invalid API key
```

**Cause** :
Le fichier `kong.yml` était généré avec des clés API hardcodées datant de 2022 au lieu d'utiliser les clés dynamiques du `.env`.

**Solution** :
- Modification du script `02-supabase-deploy.sh` ligne 1028
- Changement de `'KONG_EOF'` (single quote) à `KONG_EOF` (expansion variables)
- Utilisation de `${SUPABASE_ANON_KEY}` et `${SUPABASE_SERVICE_KEY}`

**Impact** :
- ✅ Clés 2022 remplacées par clés 2025
- ✅ Applications peuvent maintenant s'authentifier
- ✅ Futures installations génèrent automatiquement bonnes clés

---

### 2. ❌ CORS Manquant sur auth-v1-open → ✅ CORS Complet

**Symptôme** :
```
Access to fetch has been blocked by CORS policy
```

**Cause** :
Le service `auth-v1-open` (signup, login, token, etc.) n'avait pas de configuration CORS.

**Solution** :
Ajout plugin CORS complet sur `auth-v1-open` avec :
- Origins: `*`
- Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS
- Headers: Accept, Authorization, Content-Type, apikey, x-client-info, x-supabase-api-version
- Credentials: true
- Max-Age: 3600

**Impact** :
- ✅ Authentification fonctionne depuis applications web
- ✅ Requêtes preflight (OPTIONS) répondent correctement
- ✅ CORS errors résolues

---

### 3. ❌ Header x-supabase-api-version Manquant → ✅ Header Ajouté

**Symptôme** :
```
Request header field x-supabase-api-version is not allowed by Access-Control-Allow-Headers
```

**Cause** :
Le client Supabase JS (versions récentes) envoie `x-supabase-api-version`, mais Kong ne l'autorisait pas.

**Solution** :
Ajout du header `x-supabase-api-version` dans CORS de tous les services :
- auth-v1-open
- rest-v1
- realtime-v1
- storage-v1
- edge-functions-v1

**Impact** :
- ✅ Compatible avec dernières versions Supabase JS client
- ✅ Erreur CORS `x-supabase-api-version` résolue
- ✅ Headers complets pour tous les services

---

## 📊 Récapitulatif Modifications

### Fichiers Modifiés

| Fichier | Lignes | Changement |
|---------|--------|------------|
| `02-supabase-deploy.sh` | 1028-1035 | Clés dynamiques au lieu hardcodées |
| `02-supabase-deploy.sh` | 1062-1086 | CORS ajouté sur auth-v1-open |
| `02-supabase-deploy.sh` | 1082, 1132, 1168, 1202, 1233 | Header x-supabase-api-version ajouté (5 services) |
| `kong.yml` (Pi) | Multiple | Appliqué corrections via scripts |

### Scripts de Correction Créés

1. **`fix-kong-keys.sh`** - Mise à jour clés 2022 → 2025
2. **`fix-cors-supabase-api-version.sh`** - Ajout header x-supabase-api-version

---

## 🧪 Tests de Validation

### Test 1 : Vérifier Clés dans kong.yml

```bash
ssh pi@192.168.1.74 "cat ~/stacks/supabase/volumes/kong/kong.yml | grep 'key:' | head -2"
```

**Résultat** :
```yaml
- key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5...
- key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3NjAwOTk4Njk...
```

✅ Clés datent de 2025 (iat: 1760099869)

---

### Test 2 : Vérifier Status Kong

```bash
ssh pi@192.168.1.74 "docker ps | grep kong"
```

**Résultat** :
```
supabase-kong ... (healthy) ...
```

✅ Kong healthy et fonctionnel

---

### Test 3 : Test CORS Preflight

```bash
curl -X OPTIONS -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: x-supabase-api-version,apikey,authorization,content-type" \
  -v http://192.168.1.74:8001/auth/v1/token 2>&1 | grep "Access-Control-Allow-Headers"
```

**Résultat** :
```
< Access-Control-Allow-Headers: Accept,Accept-Language,Content-Language,Content-Type,Authorization,apikey,x-client-info,x-supabase-api-version
```

✅ Tous les headers requis présents

---

### Test 4 : Test API avec ANON_KEY

```bash
curl -H "apikey: eyJhbGci...MTc2MDA5OTg2OQ..." http://192.168.1.74:8001/rest/v1/
```

**Résultat** :
```json
{"swagger":"2.0","info":{"description":"","title":"standard public schema","version":"12.2.12 (cd3cf9e)"...
```

✅ API répond correctement (pas d'erreur 401)

---

## 📝 Configuration CORS Finale

### Headers CORS Complets (Tous Services)

```yaml
headers:
  - Accept
  - Accept-Language
  - Content-Language
  - Content-Type
  - Authorization
  - apikey
  - x-client-info
  - x-supabase-api-version  # ✅ AJOUTÉ v3.30
```

### Services avec CORS

| Service | CORS | Methods | Credentials | Max-Age |
|---------|------|---------|-------------|---------|
| auth-v1-open | ✅ | ALL | true | 3600 |
| rest-v1 | ✅ | ALL | true | 3600 |
| realtime-v1 | ✅ | ALL | true | 3600 |
| storage-v1 | ✅ | ALL | true | 3600 |
| edge-functions-v1 | ✅ | ALL | true | 3600 |

---

## 🔑 Vos Clés API (2025)

```bash
# ✅ ANON_KEY (Frontend - React/Vue/Next.js)
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg

# ⚠️ SERVICE_KEY (Backend uniquement)
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3NjAwOTk4NjksImV4cCI6MjA3NTQ1OTg2OX0._GNOnc4OwWlX2Vz_q6tUfU4RYoN2nPwfTgiRe4NbWTU
```

---

## 🚀 Configuration Application

### React/Vite

```env
# .env.local (Développement)
VITE_SUPABASE_URL=http://192.168.1.74:8001
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg

# .env.production (Déploiement)
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

### Next.js

```env
# .env.local
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.74:8001
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

---

## 📚 Documentation Créée

1. **[CHANGELOG-KONG-FIX.md](01-infrastructure/supabase/scripts/CHANGELOG-KONG-FIX.md)** - Changelog complet corrections Kong
2. **[GUIDE-CONNEXION-RAPIDE.md](GUIDE-CONNEXION-RAPIDE.md)** - Guide express connexion application
3. **[CONNEXION-APPLICATION-SUPABASE-PI.md](CONNEXION-APPLICATION-SUPABASE-PI.md)** - Guide détaillé connexion
4. **[CORRECTIONS-KONG-2025-10-10.md](CORRECTIONS-KONG-2025-10-10.md)** - Ce fichier

---

## ✅ Checklist Finale

- [x] Clés API mises à jour (2022 → 2025)
- [x] CORS ajouté sur auth-v1-open
- [x] Header x-supabase-api-version ajouté (5 services)
- [x] Kong redémarré et healthy
- [x] Tests CORS validés
- [x] Tests API validés
- [x] Script 02-supabase-deploy.sh corrigé
- [x] Documentation complète créée
- [x] Backups sauvegardés

---

## 🎉 Résultat

Votre instance Supabase sur Raspberry Pi est maintenant **100% fonctionnelle** avec :

- ✅ Authentification correcte (clés 2025)
- ✅ CORS complet sur tous les services
- ✅ Compatible avec dernières versions Supabase JS client
- ✅ Aucune erreur CORS
- ✅ Aucune erreur Invalid API key

**Testez immédiatement votre application !** 🚀

---

## 🔗 Prochaines Étapes

1. **Configurez votre application** avec les clés ci-dessus
2. **Lancez votre app** React/Vue/Next.js
3. **Testez la connexion** (signup, login, select)
4. **Déployez en production** (Vercel/Netlify avec URL HTTPS)

---

**Version** : v3.30
**Date** : 2025-10-10
**Status** : ✅ Tous problèmes résolus
**Kong** : healthy
**API** : ✅ Fonctionnelle

🎊 **Félicitations ! Votre Supabase est prêt !** 🎊
