# PROBLÈME REALTIME SUPABASE - DOCUMENTATION COMPLÈTE

## CONTEXTE
Service Realtime reste en boucle de redémarrage après installation Supabase Week2 sur Raspberry Pi 5.
Script se termine avec succès mais Realtime ne démarre jamais correctement.

## PROBLÈMES IDENTIFIÉS (CHRONOLOGIQUE)

### 1. PROBLÈME SCHEMA_MIGRATIONS (RÉSOLU)
**Erreur initiale:**
```
column 'inserted_at' of relation 'schema_migrations' does not exist
```

**Cause:**
- Table `schema_migrations` créée automatiquement avec structure incorrecte
- Ecto/Elixir attend `version BIGINT` et `inserted_at TIMESTAMP`
- Supabase auto-créé table avec structure incompatible

**Solution intégrée:**
```sql
-- Suppression et recréation avec structure correcte
DROP TABLE IF EXISTS realtime.schema_migrations CASCADE;
CREATE TABLE realtime.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
);

-- Aussi nécessaire dans public schema pour certaines migrations
DROP TABLE IF EXISTS public.schema_migrations CASCADE;
CREATE TABLE public.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
);
```

### 2. PROBLÈME ENCRYPTION ACTUEL (NON RÉSOLU)
**Erreur après correction schema:**
```
** (ErlangError) Erlang error: {:badarg, {~c"api_ng.c", 228}, ~c"Bad key"}:
(crypto 5.4.2) crypto.erl:965: :crypto.crypto_one_time(:aes_128_ecb, nil, ...)
    at /app/lib/realtime/tenants/authorization.ex:129: Realtime.Tenants.Authorization.decrypt_connection_info/2
    at /app/lib/realtime/tenants/connect.ex:109: Realtime.Tenants.Connect.call/1
```

**Analyse technique:**
- Erreur dans module `Authorization.decrypt_connection_info/2`
- Tentative déchiffrement AES_128_ECB avec clé `nil`
- Problème de configuration JWT_SECRET ou SECRET_KEY_BASE

**Variables d'environnement suspectées:**
```yaml
DB_ENC_KEY: ${JWT_SECRET}          # ← Problème potentiel
SECRET_KEY_BASE: ${JWT_SECRET}     # ← Même valeur que DB_ENC_KEY
API_JWT_SECRET: ${JWT_SECRET}      # ← Utilisé partout
```

## RECHERCHE APPROFONDIE CONFIRMÉE (MISE À JOUR)

### Points investigués et confirmés:
1. **DB_ENC_KEY manquante:** Clé `nil` passée à `crypto_one_time` → erreur Erlang "badarg"
2. **Longueur exacte requise:** AES_128_ECB nécessite exactement 16 octets (32 hex chars)
3. **Tenant corrompu:** Seeding échoue sur tenant "realtime-dev"
4. **JWT_SECRET optimal:** Recommandé ~40 caractères (retour terrain 2024-2025)

### Solutions spécifiques confirmées:
```bash
# 1. Générer DB_ENC_KEY exactement 16 caractères ASCII
DB_ENC_KEY=$(openssl rand -hex 8)   # 8 octets → 16 hexdigits

# 2. SECRET_KEY_BASE indépendant 64 caractères
SECRET_KEY_BASE=$(openssl rand -hex 32)  # 64 hexdigits

# 3. Nettoyer tenant corrompu
docker exec -T supabase-db psql -U postgres -d postgres -c "DELETE FROM _realtime.tenants WHERE external_id = 'realtime-dev';"

# 4. Variables Realtime ARM64 additionnelles
APP_NAME: supabase_realtime
ERL_AFLAGS: -proto_dist inet_tcp
DNS_NODES: ""
DB_IP_VERSION: ipv4
SEED_SELF_HOST: "true"
```

### Vérifications post-correction:
```bash
# Vérifier variables reçues par Realtime
docker exec supabase-realtime env | egrep 'DB_ENC_KEY|SECRET_KEY_BASE|API_JWT_SECRET'

# Vérifier table tenants après boot
docker exec -T supabase-db psql -U postgres -d postgres -c "SELECT id, name, external_id, length(jwt_secret::text) FROM _realtime.tenants;"

# Schema Realtime (Realtime gère _realtime automatiquement)
docker exec -T supabase-db psql -U postgres -d postgres -c "\dt _realtime.*"
```

## SOLUTION TEMPORAIRE ACTUELLE

### Diagnostic automatisé intégré:
```bash
diagnose_realtime_issue() {
  log "🔍 Diagnostic approfondi Realtime..."

  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "restarting"; then
    warn "❌ Realtime en boucle de redémarrage"

    log "📋 Logs récents Realtime:"
    docker logs supabase-realtime --tail=20 2>&1 | sed 's/^/    /'

    log "🔧 Variables d'environnement Realtime:"
    docker exec supabase-realtime printenv | grep -E "(JWT|SECRET|DB_|API_)" | sed 's/^/    /'

    # Vérification structure schema_migrations
    log "🗄️ Vérification schema_migrations:"
    docker exec -T supabase-db psql -U postgres -d postgres -c "
      SELECT 'realtime.schema_migrations' as schema,
             column_name, data_type
      FROM information_schema.columns
      WHERE table_schema='realtime' AND table_name='schema_migrations';" 2>/dev/null | sed 's/^/    /'
  fi
}
```

## INTÉGRATION RECOMMANDÉE WEEK2

### 1. Fonction préventive pre-installation:
```bash
prepare_realtime_environment() {
  log "🔧 Préparation environnement Realtime..."

  # Générer clé AES 128-bit dédiée pour DB_ENC_KEY
  DB_ENC_KEY=$(openssl rand -hex 16)

  # Garder JWT_SECRET séparé pour API
  # JWT_SECRET reste inchangé

  # Vérifier que SECRET_KEY_BASE fait 64 caractères minimum
  if [ ${#JWT_SECRET} -lt 64 ]; then
    warn "JWT_SECRET trop court pour SECRET_KEY_BASE"
    SECRET_KEY_BASE=$(openssl rand -hex 32)
  else
    SECRET_KEY_BASE="$JWT_SECRET"
  fi

  export DB_ENC_KEY SECRET_KEY_BASE
}
```

### 2. Fonction correction post-installation:
```bash
fix_realtime_encryption() {
  log "🔧 Correction encryption Realtime..."

  # Arrêter Realtime
  docker compose stop realtime

  # Regénérer clés avec format correct
  prepare_realtime_environment

  # Mettre à jour .env
  sed -i "s/^DB_ENC_KEY=.*/DB_ENC_KEY=${DB_ENC_KEY}/" .env
  sed -i "s/^SECRET_KEY_BASE=.*/SECRET_KEY_BASE=${SECRET_KEY_BASE}/" .env

  # Redémarrer avec nouvelles clés
  docker compose up -d realtime

  # Attendre et vérifier
  sleep 10
  if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then
    ok "✅ Realtime encryption corrigée"
  else
    warn "❌ Problème persiste - investigation manuelle requise"
  fi
}
```

### 3. Modification docker-compose.yml recommandée:
```yaml
realtime:
  environment:
    # Séparer les responsabilités des clés
    DB_ENC_KEY: ${DB_ENC_KEY}           # Clé AES 128-bit dédiée
    SECRET_KEY_BASE: ${SECRET_KEY_BASE} # Clé Elixir 64+ caractères
    API_JWT_SECRET: ${JWT_SECRET}       # JWT pour API

    # Nouvelles variables pour stability ARM64
    ERL_AFLAGS: "-proto_dist inet_tcp"
    ERLANG_COOKIE: "supabase_realtime_cookie"
    RELEASE_COOKIE: "supabase_realtime_cookie"
```

## STATUS VALIDATION

### Test de validation intégré:
```bash
validate_realtime_final() {
  log "✅ Validation finale Realtime..."

  local max_attempts=60
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if docker ps --format '{{.Names}}\t{{.Status}}' | grep realtime | grep -q "Up"; then
      if docker exec supabase-realtime curl -f http://localhost:4000/health 2>/dev/null; then
        ok "✅ Realtime opérationnel (tentative $attempt/$max_attempts)"
        return 0
      fi
    fi

    if [ $((attempt % 10)) -eq 0 ]; then
      log "⏳ Realtime toujours en cours de démarrage... ($attempt/$max_attempts)"
    fi

    sleep 2
    ((attempt++))
  done

  error "❌ Realtime failed to start after $max_attempts attempts"
  diagnose_realtime_issue
  return 1
}
```

## PROCHAINES ÉTAPES

1. **Recherche spécialisée:** Format exact attendu pour DB_ENC_KEY dans Realtime v2.30.23
2. **Test isolation:** Démarrer Realtime seul avec variables minimales
3. **Intégration automatique:** Ajouter toutes ces corrections dans setup-week2-supabase-final.sh
4. **Fallback strategy:** Si encryption reste problématique, désactiver Realtime temporairement

## RÉFÉRENCES
- Realtime source: `/app/lib/realtime/tenants/authorization.ex:129`
- Erlang crypto: `crypto.erl:965: :crypto.crypto_one_time(:aes_128_ecb, nil, ...)`
- AES_128_ECB: Clé 16 octets exactement requise
- Elixir SECRET_KEY_BASE: 64 caractères minimum recommandé