# 🔧 CHANGELOG - Kong Configuration v3.31

> **Date** : 2025-10-10
> **Version** : v3.31
> **Type** : Fix Critique + Amélioration Majeure

---

## 🎯 Problème Résolu

### Symptôme
Endpoints `/auth/v1/token`, `/auth/v1/signup` retournaient **404 Not Found** malgré :
- ✅ Kong healthy
- ✅ Clés API correctes (v3.29)
- ✅ CORS headers ajoutés (v3.30)

```bash
curl -X POST http://192.168.1.74:8001/auth/v1/signup
# Résultat: 404 page not found
```

### Cause Racine

Notre configuration Kong personnalisée était **structurellement incorrecte** par rapport à la configuration officielle Supabase.

**❌ Notre Config (INCORRECTE)** :
```yaml
services:
  - name: auth-v1-open
    url: http://auth:9999/  # ❌ URL générique
    routes:
      - name: auth-v1-open
        paths:
          - /auth/v1/signup  # ❌ Plusieurs paths dans un service
          - /auth/v1/token
          - /auth/v1/verify
          - /auth/v1/callback
          # ... tous ensemble
```

**Problème** : Kong 2.8 avec `format_version: 2.1` ne gère PAS correctement plusieurs paths auth spécifiques dans un seul service avec `strip_path: true`.

**✅ Config Officielle Supabase (CORRECTE)** :
```yaml
services:
  # Endpoints publics spécifiques
  - name: auth-v1-open
    url: http://auth:9999/verify  # ✅ URL spécifique
    routes:
      - name: auth-v1-open
        paths:
          - /auth/v1/verify  # ✅ Un seul path

  - name: auth-v1-open-callback
    url: http://auth:9999/callback
    routes:
      - name: auth-v1-open-callback
        paths:
          - /auth/v1/callback

  - name: auth-v1-open-authorize
    url: http://auth:9999/authorize
    routes:
      - name: auth-v1-open-authorize
        paths:
          - /auth/v1/authorize

  # Service générique pour endpoints sécurisés
  - name: auth-v1
    url: http://auth:9999/  # ✅ URL générique
    routes:
      - name: auth-v1-all
        paths:
          - /auth/v1/  # ✅ Path préfixe avec key-auth
    plugins:
      - name: key-auth  # ✅ Auth requise
      - name: acl
```

**Conclusion** : La configuration officielle utilise des **services séparés** pour chaque endpoint public spécifique + un service générique avec authentification pour `/auth/v1/` qui gère signup, token, etc.

---

## ✅ Solution Implémentée

### Changement dans `02-supabase-deploy.sh`

Au lieu de générer une configuration personnalisée hardcodée, le script **télécharge maintenant la configuration officielle Supabase** et injecte les clés.

**Avant (v3.30)** : Ligne 1028-1254 (227 lignes)
```bash
create_kong_configuration() {
    cat > "$PROJECT_DIR/volumes/kong/kong.yml" << 'KONG_EOF'
_format_version: "2.1"
consumers:
  - username: anon
    keyauth_credentials:
      - key: ${SUPABASE_ANON_KEY}  # ❌ Hardcodé inline
# ... 220 lignes de config manuelle
KONG_EOF
}
```

**Après (v3.31)** : Ligne 1028-1045 (18 lignes effectives)
```bash
create_kong_configuration() {
    # Télécharger configuration officielle Supabase
    curl -fsSL https://raw.githubusercontent.com/supabase/supabase/master/docker/volumes/api/kong.yml \
        -o "$PROJECT_DIR/volumes/kong/kong.yml"

    # Remplacer les variables d'environnement
    sed -i.backup "s|\\\$SUPABASE_ANON_KEY|${SUPABASE_ANON_KEY}|g" "$PROJECT_DIR/volumes/kong/kong.yml"
    sed -i.backup "s|\\\$SUPABASE_SERVICE_KEY|${SUPABASE_SERVICE_KEY}|g" "$PROJECT_DIR/volumes/kong/kong.yml"
    sed -i.backup "s|\\\$DASHBOARD_USERNAME|dashboard|g" "$PROJECT_DIR/volumes/kong/kong.yml"
    sed -i.backup "s|\\\$DASHBOARD_PASSWORD|supabase|g" "$PROJECT_DIR/volumes/kong/kong.yml"

    rm -f "$PROJECT_DIR/volumes/kong/kong.yml.backup"
}
```

**Avantages** :
1. ✅ **Toujours à jour** : Suit automatiquement les mises à jour Supabase
2. ✅ **Moins de code** : 18 lignes au lieu de 227
3. ✅ **Moins de bugs** : Configuration testée par Supabase
4. ✅ **Maintenance simplifiée** : Pas de sync manuelle

---

## 📊 Services Kong Configurés

### Configuration Officielle Utilisée

| Service | URL | Path | Auth | Usage |
|---------|-----|------|------|-------|
| `auth-v1-open` | `http://auth:9999/verify` | `/auth/v1/verify` | ❌ Public | Vérification email |
| `auth-v1-open-callback` | `http://auth:9999/callback` | `/auth/v1/callback` | ❌ Public | OAuth callback |
| `auth-v1-open-authorize` | `http://auth:9999/authorize` | `/auth/v1/authorize` | ❌ Public | OAuth authorize |
| `auth-v1` | `http://auth:9999/` | `/auth/v1/` | ✅ key-auth | signup, token, logout, etc. |
| `rest-v1` | `http://rest:3000/` | `/rest/v1/` | ✅ key-auth | PostgREST API |
| `graphql-v1` | `http://rest:3000/rpc/graphql` | `/graphql/v1` | ✅ key-auth | GraphQL API |
| `realtime-v1-ws` | `ws://realtime:4000/socket` | `/realtime/v1/` | ✅ key-auth | WebSocket |
| `realtime-v1-rest` | `http://realtime:4000/api` | `/realtime/v1/api` | ✅ key-auth | Realtime REST |
| `storage-v1` | `http://storage:5000/` | `/storage/v1/` | ❌ Self-auth | Storage S3 |
| `functions-v1` | `http://functions:9000/` | `/functions/v1/` | ❌ Self-auth | Edge Functions |
| `analytics-v1` | `http://analytics:4000/` | `/analytics/v1/` | ✅ key-auth | Analytics |
| `meta` | `http://meta:8080/` | `/pg/` | ✅ Admin only | Meta API |

**Total** : 12+ services configurés automatiquement

---

## 🧪 Tests de Validation

### Test 1 : Endpoints Auth

```bash
# Signup (avant: 404, après: fonctionne)
curl -X POST -H "Content-Type: application/json" \
  -H "apikey: <ANON_KEY>" \
  -d '{"email":"test@example.com","password":"testpass123"}' \
  http://192.168.1.74:8001/auth/v1/signup

# Résultat attendu: {"message":"Invalid authentication credentials"} ou réponse signup
# PAS 404 !
```

### Test 2 : REST API

```bash
curl -H "apikey: <ANON_KEY>" http://192.168.1.74:8001/rest/v1/
# Résultat: JSON OpenAPI spec
```

### Test 3 : Vérifier Services Kong

```bash
ssh pi@192.168.1.74 "grep 'name: auth-v1' ~/stacks/supabase/volumes/kong/kong.yml"
```

**Résultat attendu** : Plusieurs services auth-v1 (open, open-callback, open-authorize, générique)

---

## 📁 Fichiers Modifiés

| Fichier | Changement | Lignes |
|---------|-----------|--------|
| `02-supabase-deploy.sh` | Fonction `create_kong_configuration()` remplacée | 1022-1208 |
| `02-supabase-deploy.sh` | Ancienne config commentée (référence) | 1053-1203 |
| `CHANGELOG-KONG-V3.31.md` | Ce fichier | - |

**Diff résumé** :
```diff
- Génération config Kong personnalisée (227 lignes)
+ Téléchargement config officielle + injection clés (18 lignes)
```

---

## 🔄 Migration Installations Existantes

### Pour installations v3.29/v3.30

Votre Pi utilise déjà la configuration officielle (appliquée manuellement le 2025-10-10).

**Aucune action requise** ✅

Le script corrigé `/tmp/fix-kong-official-config.sh` a déjà été exécuté.

### Pour nouvelles installations (après v3.31)

Le script `02-supabase-deploy.sh` génère automatiquement la configuration officielle.

**Commande** :
```bash
curl -fsSL https://raw.githubusercontent.com/.../02-supabase-deploy.sh | sudo bash
```

---

## 🎯 Impact

### Avant v3.31 (Problèmes)
- ❌ 404 sur `/auth/v1/signup`, `/auth/v1/token`
- ❌ Applications ne peuvent pas s'authentifier
- ❌ Configuration custom à maintenir manuellement
- ❌ Désynchronisation possible avec Supabase officiel

### Après v3.31 (Solutions)
- ✅ Tous endpoints auth fonctionnent
- ✅ Applications se connectent correctement
- ✅ Configuration auto-sync avec Supabase
- ✅ Moins de code, moins de bugs
- ✅ Futures améliorations Supabase appliquées automatiquement

---

## 📚 Historique Corrections Kong

| Version | Date | Problème | Solution |
|---------|------|----------|----------|
| v3.29 | 2025-10-10 | Clés hardcodées 2022 | Utilisation clés dynamiques depuis .env |
| v3.30 | 2025-10-10 | Header `x-supabase-api-version` manquant | Ajout header dans CORS |
| **v3.31** | **2025-10-10** | **Config structurellement incorrecte** | **Utilisation config officielle Supabase** |

---

## 🔗 Références

- **Config Officielle** : https://github.com/supabase/supabase/blob/master/docker/volumes/api/kong.yml
- **Kong Documentation** : https://docs.konghq.com/gateway/latest/
- **Supabase Self-Hosting** : https://supabase.com/docs/guides/self-hosting/docker

---

## ✅ Checklist Validation

- [x] Script 02-supabase-deploy.sh modifié
- [x] Syntaxe bash validée (`bash -n`)
- [x] Configuration officielle téléchargeable
- [x] Injection clés testée
- [x] Endpoints auth fonctionnels (test manuel)
- [x] CHANGELOG créé
- [x] Ancienne config conservée en commentaire (référence)

---

**Status** : ✅ Corrigé et testé
**Version** : v3.31
**Date** : 2025-10-10
**Auteur** : Claude Code

**🎉 Kong utilise maintenant la configuration officielle Supabase !**
