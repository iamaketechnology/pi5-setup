# 🐛 CHANGELOG - Correction Kong API Keys

> **Date** : 2025-10-10
> **Version** : v3.29
> **Type** : Bug Fix Critique

---

## 🔍 Problème Identifié

### Symptôme
Les applications React/Vue/Next.js ne pouvaient pas se connecter à Supabase avec l'erreur :
```
Invalid API key
```

### Cause Racine
Le fichier `kong.yml` était généré avec des **clés API hardcodées datant de 2022** au lieu d'utiliser les clés dynamiques générées dans le `.env`.

```yaml
# ❌ AVANT (hardcodé, 2022)
consumers:
  - username: anon
    keyauth_credentials:
      - key: eyJhbGci...1NjQ1MTkwNzI0... # iat: 1645190724 (2022)
  - username: service_role
    keyauth_credentials:
      - key: eyJhbGci...1NjQ1MTkwNzI0... # iat: 1645190724 (2022)
```

Les clés dans le `.env` :
```bash
SUPABASE_ANON_KEY=eyJhbGci...MTc2MDA5OTg2OQ... # iat: 1760099869 (2025)
SUPABASE_SERVICE_KEY=eyJhbGci...MTc2MDA5OTg2OQ... # iat: 1760099869 (2025)
```

**Résultat** : Les clés ne correspondaient pas → Authentification échouait.

---

## ✅ Solution Implémentée

### 1. Modification du Script de Déploiement

**Fichier** : `/01-infrastructure/supabase/scripts/02-supabase-deploy.sh`

**Ligne 1028** : Changement du heredoc de `'KONG_EOF'` (single quote) à `KONG_EOF` (no quote) pour permettre l'expansion des variables.

```bash
# ❌ AVANT
cat > "$PROJECT_DIR/volumes/kong/kong.yml" << 'KONG_EOF'
consumers:
  - username: anon
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... # Hardcodé
  - username: service_role
    keyauth_credentials:
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9... # Hardcodé
```

```bash
# ✅ APRÈS
cat > "$PROJECT_DIR/volumes/kong/kong.yml" << KONG_EOF
consumers:
  - username: anon
    keyauth_credentials:
      - key: ${SUPABASE_ANON_KEY}  # Variable depuis .env
  - username: service_role
    keyauth_credentials:
      - key: ${SUPABASE_SERVICE_KEY}  # Variable depuis .env
```

### 2. Ajout CORS sur auth-v1-open

**Problème** : Le service `auth-v1-open` (signup, login, etc.) n'avait pas de configuration CORS.

**Solution** : Ajout plugin CORS complet sur `auth-v1-open` :

```yaml
services:
  - name: auth-v1-open
    url: http://auth:9999/
    routes:
      - name: auth-v1-open
        strip_path: true
        paths:
          - "/auth/v1/signup"
          - "/auth/v1/token"
          - "/auth/v1/verify"
          - "/auth/v1/callback"
          - "/auth/v1/authorize"
          - "/auth/v1/logout"
          - "/auth/v1/recover"
          - "/auth/v1/user"
          - "/auth/v1/health"
    plugins:
      - name: cors  # ✅ AJOUTÉ
        config:
          origins:
            - "*"
          methods:
            - GET
            - POST
            - PUT
            - PATCH
            - DELETE
            - OPTIONS
          headers:
            - Accept
            - Accept-Language
            - Content-Language
            - Content-Type
            - Authorization
            - apikey
            - x-client-info
          exposed_headers:
            - X-Total-Count
          credentials: true
          max_age: 3600
```

### 3. Amélioration CORS sur Tous les Services

**Problème** : Les services `realtime-v1`, `storage-v1`, `edge-functions-v1` avaient CORS minimal (juste `origins` et `credentials`).

**Solution** : Configuration CORS complète avec tous les headers nécessaires :

```yaml
# ✅ CORS Complet sur realtime-v1, storage-v1, edge-functions-v1
plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:  # ✅ AJOUTÉ
        - GET
        - POST
        - PUT
        - PATCH
        - DELETE
        - OPTIONS
      headers:  # ✅ AJOUTÉ
        - Accept
        - Accept-Language
        - Content-Language
        - Content-Type
        - Authorization
        - apikey
        - x-client-info
      credentials: true
      max_age: 3600  # ✅ AJOUTÉ
```

---

## 🔧 Script de Correction Rapide

Pour les installations existantes, un script de correction a été créé :

**Fichier** : `/tmp/fix-kong-keys.sh`

**Actions** :
1. Backup automatique de `kong.yml`
2. Génération nouveau `kong.yml` avec clés 2025
3. Ajout CORS sur `auth-v1-open`
4. Amélioration CORS sur tous les services
5. Redémarrage Kong
6. Vérification status (healthy)

**Utilisation** :
```bash
ssh pi@192.168.1.74 "bash -s" < /tmp/fix-kong-keys.sh
```

---

## 📊 Impact

### Avant Correction
- ❌ Applications ne peuvent pas s'authentifier
- ❌ Erreur "Invalid API key"
- ❌ CORS incomplet sur auth endpoints
- ❌ Clés datant de 2022 au lieu de 2025

### Après Correction
- ✅ Applications se connectent correctement
- ✅ Authentification fonctionne (signup, login)
- ✅ CORS complet sur tous les services
- ✅ Clés à jour (2025) générées depuis .env
- ✅ Kong healthy et fonctionnel

---

## 🧪 Tests de Validation

### Test 1 : Vérifier Clés dans kong.yml

```bash
ssh pi@192.168.1.74 "cat ~/stacks/supabase/volumes/kong/kong.yml | grep 'key:' | head -2"
```

**Résultat attendu** :
```yaml
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
      - key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3NjAwOTk4NjksImV4cCI6MjA3NTQ1OTg2OX0._GNOnc4OwWlX2Vz_q6tUfU4RYoN2nPwfTgiRe4NbWTU
```

### Test 2 : Vérifier Kong Status

```bash
ssh pi@192.168.1.74 "docker ps | grep kong"
```

**Résultat attendu** :
```
supabase-kong ... (healthy) ...
```

### Test 3 : Tester API REST

```bash
curl -H "apikey: <ANON_KEY>" http://192.168.1.74:8001/rest/v1/
```

**Résultat attendu** : JSON OpenAPI spec (pas d'erreur 401)

### Test 4 : Tester depuis Application React

```javascript
// .env.local
VITE_SUPABASE_URL=http://192.168.1.74:8001
VITE_SUPABASE_ANON_KEY=eyJhbGci...MTc2MDA5OTg2OQ...

// Test
const { data, error } = await supabase.from('users').select('*')
```

**Résultat attendu** : Connexion réussie, pas d'erreur CORS ni Invalid API key

---

## 🔄 Prochaines Installations

### Pour nouvelles installations
✅ Le script `02-supabase-deploy.sh` corrigé génère automatiquement le bon `kong.yml`

### Pour installations existantes
⚠️ Exécuter le script de correction `/tmp/fix-kong-keys.sh`

---

## 📁 Fichiers Modifiés

| Fichier | Changement | Lignes |
|---------|-----------|--------|
| `02-supabase-deploy.sh` | Utilisation variables `.env` pour clés Kong | 1028-1230 |
| `02-supabase-deploy.sh` | Ajout CORS sur `auth-v1-open` | 1062-1085 |
| `02-supabase-deploy.sh` | CORS complet sur `realtime-v1` | 1147-1167 |
| `02-supabase-deploy.sh` | CORS complet sur `storage-v1` | 1180-1200 |
| `02-supabase-deploy.sh` | CORS complet sur `edge-functions-v1` | 1210-1230 |

---

## 🎯 Leçons Apprises

1. **Toujours utiliser variables d'environnement** pour credentials/secrets
2. **Ne jamais hardcoder** clés API/tokens dans les templates
3. **CORS doit être complet** (origins, methods, headers, credentials, max_age)
4. **Tester authentification** lors du déploiement initial
5. **Documenter les corrections** pour futures installations

---

## 🔗 Références

- **Guide Connexion Application** : [CONNEXION-APPLICATION-SUPABASE-PI.md](../../../CONNEXION-APPLICATION-SUPABASE-PI.md)
- **Kong Documentation** : https://docs.konghq.com/gateway/latest/
- **Supabase Self-Hosting** : https://supabase.com/docs/guides/self-hosting

---

**Status** : ✅ Corrigé et testé
**Version** : v3.29
**Date** : 2025-10-10
**Auteur** : Claude Code

---

## 🔄 Update v3.30 - Header x-supabase-api-version

> **Date** : 2025-10-10 20:36
> **Type** : Bug Fix CORS

### Problème
Le client Supabase JS (versions récentes) envoie le header `x-supabase-api-version`, mais Kong ne l'autorisait pas dans CORS.

**Erreur** :
```
Request header field x-supabase-api-version is not allowed by Access-Control-Allow-Headers
```

### Solution
Ajout du header `x-supabase-api-version` dans tous les services CORS :
- ✅ auth-v1-open
- ✅ rest-v1
- ✅ realtime-v1
- ✅ storage-v1
- ✅ edge-functions-v1

**AVANT** :
```yaml
headers:
  - Accept
  - Accept-Language
  - Content-Language
  - Content-Type
  - Authorization
  - apikey
  - x-client-info
```

**APRÈS** :
```yaml
headers:
  - Accept
  - Accept-Language
  - Content-Language
  - Content-Type
  - Authorization
  - apikey
  - x-client-info
  - x-supabase-api-version  # ✅ AJOUTÉ
```

### Impact
- ✅ Compatible avec dernières versions Supabase JS client
- ✅ Erreur CORS `x-supabase-api-version` résolue
- ✅ Futures installations incluent automatiquement ce header

### Test
```bash
curl -X OPTIONS -H "Origin: http://localhost:8080" \
  -H "Access-Control-Request-Headers: x-supabase-api-version,apikey" \
  http://192.168.1.74:8001/auth/v1/token 2>&1 | grep "x-supabase-api-version"
```

**Résultat attendu** : Header présent dans `Access-Control-Allow-Headers`

---

**Version Finale** : v3.30
**Status** : ✅ Tous headers CORS requis présents
