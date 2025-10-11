# 📚 Schémas Supabase - Lesquels sont nécessaires ?

> Guide pour comprendre les schémas système de Supabase

---

## 🎯 Réponse rapide

### ✅ Schémas OBLIGATOIRES (ne supprimez jamais)

| Schéma | Utilisé pour | Conséquence si supprimé |
|--------|--------------|-------------------------|
| **auth** | Authentification, login, sessions | ❌ **Login impossible** |
| **storage** | Stockage fichiers (images, PDF, etc.) | ❌ **Upload/Download bloqués** |
| **public** | Schéma par défaut PostgreSQL | ❌ **Erreurs système** |

### 🟡 Schémas OPTIONNELS (selon vos besoins)

| Schéma | Utilisé pour | Vous en avez besoin si... |
|--------|--------------|---------------------------|
| **realtime** | Notifications temps réel (WebSocket) | Vous utilisez `.on('INSERT')`, chat, dashboard live |
| **_realtime** | Config interne Realtime | Vous utilisez Realtime |
| **vault** | Secrets chiffrés dans la DB | Vous stockez des clés API, tokens OAuth dans Postgres |

### 🔵 Schémas INUTILISÉS (peuvent rester vides)

| Schéma | Utilisé pour | État actuel |
|--------|--------------|-------------|
| **extensions** | Extensions PostgreSQL (pgvector, etc.) | Vide - utilisé si besoin |
| **graphql** | API GraphQL (alternative à REST) | Vide - pas activé |
| **graphql_public** | GraphQL public | Vide - pas activé |
| **supabase_functions** | Edge Functions (Deno) | Vide - pas de fonctions déployées |
| **supabase_migrations** | Historique migrations | 2 tables - tracking automatique |

---

## 📊 Votre situation actuelle

Voici l'état de vos schémas sur le Pi:

```
✅ ACTIFS (avec données)
├── auth (17 tables) - 11 utilisateurs
├── storage (9 tables) - Configuration fichiers
├── certidoc (16 tables) - Votre application
├── realtime (3 tables) - Si vous utilisez subscriptions
├── _realtime (3 tables) - Config Realtime
├── vault (1 table) - Secrets (probablement vide)
└── supabase_migrations (2 tables) - Historique

❌ VIDES (prêts à l'emploi si besoin)
├── extensions - Prêt pour pgvector, etc.
├── graphql - API GraphQL (non activée)
├── graphql_public - GraphQL public
└── supabase_functions - Edge Functions
```

---

## 🔍 Analyse détaillée

### 1. **auth** (17 tables) - ✅ OBLIGATOIRE

**Fonction**: Gère toute l'authentification Supabase

**Tables principales**:
- `users` - Comptes utilisateurs (11 users chez vous)
- `sessions` - Sessions actives
- `refresh_tokens` - Tokens JWT
- `identities` - OAuth providers (Google, GitHub)

**Si supprimé**:
- ❌ Login/Signup bloqués
- ❌ API Auth non fonctionnelle
- ❌ Toutes vos apps crashent

**Verdict**: **NE JAMAIS SUPPRIMER**

---

### 2. **storage** (9 tables) - ✅ OBLIGATOIRE (si vous stockez des fichiers)

**Fonction**: Stockage S3-compatible pour fichiers

**Tables principales**:
- `buckets` - Conteneurs (public, private)
- `objects` - Métadonnées fichiers
- `migrations` - Versions Storage

**Utilisé pour**: Images, PDF, vidéos, documents

**Si supprimé**:
- ❌ Upload/Download fichiers bloqué
- ❌ Storage API 404

**Votre cas**: Vous avez `documents.storage_key` dans certidoc → **vous utilisez Storage**

**Verdict**: **GARDER**

---

### 3. **realtime** + **_realtime** (3+3 tables) - 🟡 OPTIONNEL

**Fonction**: Notifications temps réel via WebSocket

**Exemples d'usage**:
```javascript
// Écouter nouveaux documents
supabase
  .channel('documents')
  .on('postgres_changes', {
    event: 'INSERT',
    schema: 'certidoc',
    table: 'documents'
  }, payload => {
    console.log('Nouveau document!', payload)
  })
  .subscribe()
```

**Si supprimé**:
- ❌ Subscriptions WebSocket bloquées
- ✅ REST API fonctionne toujours
- ✅ Polling manuel possible

**Comment savoir si vous l'utilisez**:
```bash
# Chercher dans votre code
grep -r "\.on('postgres_changes'" your-app/
grep -r "\.channel(" your-app/
grep -r "subscribe()" your-app/
```

**Verdict**: **GARDER si vous utilisez `.on()` ou WebSocket**

---

### 4. **vault** (1 table) - 🟡 OPTIONNEL

**Fonction**: Stockage sécurisé de secrets dans PostgreSQL

**Exemples d'usage**:
- Clés API tierces (Stripe, SendGrid)
- Tokens OAuth
- Credentials internes

**Alternative**: Variables d'environnement (`.env`)

**Si supprimé**:
- ❌ Fonctions `vault.secrets()` bloquées
- ✅ Auth/Storage/REST fonctionnent

**Verdict**: **GARDER (léger, peut servir plus tard)**

---

### 5. **extensions** (0 table) - 🔵 INUTILISÉ

**Fonction**: Schéma pour extensions PostgreSQL

**Extensions populaires**:
- `pgvector` - Recherche sémantique (AI/embeddings)
- `pg_cron` - Jobs planifiés
- `pg_stat_statements` - Monitoring requêtes

**Si supprimé**: Rien, il est déjà vide

**Verdict**: **GARDER (utile pour extensions futures)**

---

### 6. **graphql** + **graphql_public** (0 table) - 🔵 INUTILISÉ

**Fonction**: API GraphQL (alternative à REST)

**État actuel**: Non activé

**Pour activer**: Dashboard Supabase → API Settings → GraphQL

**Si supprimé**:
- ❌ API GraphQL bloquée (si activée un jour)
- ✅ REST API fonctionne

**Verdict**: **PEUT RESTER VIDE** (prêt si besoin)

---

### 7. **supabase_functions** (0 table) - 🔵 INUTILISÉ

**Fonction**: Edge Functions (code Deno serverless)

**Exemples**:
- Webhooks
- Background jobs
- API custom

**État**: Aucune fonction déployée

**Si supprimé**:
- ❌ Edge Functions bloquées
- ✅ Database/Auth/Storage fonctionnent

**Verdict**: **PEUT RESTER VIDE**

---

### 8. **supabase_migrations** (2 tables) - 🟡 SYSTÈME

**Fonction**: Historique des migrations appliquées

**Tables**:
- `schema_migrations` - Versions appliquées
- `seed_files` - Seeds exécutés

**Si supprimé**:
- ❌ Tracking migrations perdu
- ❌ `supabase db reset` peut casser

**Verdict**: **GARDER** (léger, utile pour maintenance)

---

## 🎯 Recommandations pour votre projet Certidoc

### ✅ Schémas à GARDER absolument

```
auth              - Vous avez 11 utilisateurs → OBLIGATOIRE
storage           - Vos documents ont storage_key → OBLIGATOIRE
certidoc          - Votre application → OBLIGATOIRE
public            - Schéma système → OBLIGATOIRE
supabase_migrations - Tracking → UTILE
```

### 🟡 Schémas à VÉRIFIER (selon usage)

**Vérifiez si vous utilisez Realtime**:
```bash
# Dans votre code
grep -r "\.on('postgres_changes'" your-certidoc-app/
```

**Si OUI** → Garder `realtime` + `_realtime`
**Si NON** → Peuvent être supprimés (mais ça ne gêne pas)

### 🔵 Schémas VIDES (aucun impact)

```
extensions        - 0 table - Ne gêne pas, prêt si besoin
graphql           - 0 table - Ne gêne pas
graphql_public    - 0 table - Ne gêne pas
supabase_functions - 0 table - Ne gêne pas
vault             - 1 table (probablement vide) - Léger
```

**Verdict**: Les schémas vides ne consomment quasi rien, autant les garder

---

## 🗑️ Comment supprimer un schéma (si vraiment nécessaire)

> ⚠️ **DANGER**: Ne faites ceci que si vous êtes SÛR de ne pas en avoir besoin

### Étape 1: Backup complet

```bash
ssh pi@192.168.1.74
cd ~/stacks/supabase
docker-compose exec postgres pg_dumpall -U postgres > /tmp/full_backup.sql
```

### Étape 2: Supprimer le schéma

```sql
-- Connexion
PGPASSWORD=your_password psql -h localhost -U postgres -d postgres

-- Supprimer (exemple: graphql)
DROP SCHEMA IF EXISTS graphql CASCADE;
DROP SCHEMA IF EXISTS graphql_public CASCADE;
```

### Étape 3: Tester

```bash
# Tester login
curl http://localhost:8000/auth/v1/health

# Tester REST API
curl http://localhost:8000/rest/v1/
```

---

## 📊 Consommation espace disque

Vérifions combien d'espace prennent les schémas:

```bash
ssh pi@192.168.1.74 "PGPASSWORD=\$(cat ~/stacks/supabase/.env | grep POSTGRES_PASSWORD | cut -d'=' -f2) psql -h localhost -U postgres -p 5432 -d postgres -c \"
SELECT
  schemaname,
  pg_size_pretty(SUM(pg_total_relation_size(schemaname || '.' || tablename))) as size
FROM pg_tables
WHERE schemaname IN ('auth', 'storage', 'realtime', '_realtime', 'vault', 'certidoc')
GROUP BY schemaname
ORDER BY SUM(pg_total_relation_size(schemaname || '.' || tablename)) DESC;
\""
```

**Résultat attendu**: Probablement < 10 MB pour les schémas système

---

## 🎓 Résumé pour débutants

### Question: "Puis-je supprimer les schémas vides ?"

**Réponse courte**: Oui, mais ce n'est pas nécessaire

**Pourquoi**:
1. Ils ne prennent quasi pas de place (< 1 MB)
2. Supabase peut en avoir besoin plus tard
3. Risque de casser des migrations futures

### Question: "Quels schémas sont vraiment utilisés ?"

**Pour Certidoc**:
- ✅ `certidoc` - Vos 16 tables
- ✅ `auth` - Vos 11 utilisateurs
- ✅ `storage` - Vos fichiers
- 🟡 `realtime` - Si vous utilisez subscriptions
- ❌ `graphql`, `extensions`, `supabase_functions` - Non utilisés

### Question: "Ça ralentit mon Pi d'avoir ces schémas vides ?"

**Non**. Un schéma vide = juste un nom dans un catalogue système.
Impact mémoire: < 1 KB par schéma vide.

---

## 📚 Ressources

- [Supabase Schemas Documentation](https://supabase.com/docs/guides/database/schemas)
- [PostgreSQL Schemas](https://www.postgresql.org/docs/current/ddl-schemas.html)
- [Supabase Realtime Guide](https://supabase.com/docs/guides/realtime)

---

**Version**: 1.0.0
**Dernière mise à jour**: 2025-10-06
**Auteur**: [@iamaketechnology](https://github.com/iamaketechnology)
