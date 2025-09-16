# SESSION DE DEBUGGING POST-INSTALL - 15 SEPTEMBRE 2025

## CONTEXTE
Après installation réussie Week2 v2.3-yaml-duplicates-fix, plusieurs services présentent des problèmes malgré l'absence d'erreurs bloquantes during installation.

## ÉTAT POST-INSTALLATION

### ✅ SERVICES OPÉRATIONNELS
- **PostgreSQL**: `Up 6 minutes (healthy)` - Base de données fonctionnelle
- **Kong**: `Up 5 minutes (healthy)` - Gateway actif mais problème port
- **Auth**: `Up 2 minutes` - Service auth démarré
- **Storage**: `Up 2 minutes` - API storage active
- **Rest**: `Up 2 minutes` - PostgREST fonctionnel
- **Meta**: `Up 5 minutes (healthy)` - Métadonnées PostgreSQL
- **ImgProxy**: `Up 5 minutes` - Transformation images

### ❌ SERVICES PROBLÉMATIQUES
- **Realtime**: `Restarting (1) Less than a second ago` - Restart loop
- **Studio**: `Up 5 minutes (unhealthy)` - Interface web instable
- **Edge Functions**: `Up 5 minutes (unhealthy)` - Runtime Deno problématique

## PROBLÈME 1: KONG PORT MAPPING INCORRECT

### 🔍 SYMPTÔMES
```bash
docker ps | grep kong
# 0.0.0.0:32768->8000/tcp  ← PORT ALÉATOIRE au lieu de 8001
```

### 📋 ANALYSE TECHNIQUE

**Port attendu vs réel:**
- **Configuré**: `SUPABASE_PORT=8001` → `8001->8000`
- **Réel**: Port aléatoire `32768->8000`

**Cause probable:**
1. Variable `SUPABASE_PORT` non définie dans .env au moment du démarrage Kong
2. Docker Compose assigne port aléatoire quand variable vide
3. Warnings observés: `"SUPABASE_PORT" variable is not set. Defaulting to a blank string.`

**Template docker-compose.yml:**
```yaml
kong:
  ports:
    - "${SUPABASE_PORT}:8000"  # Si SUPABASE_PORT vide → ":8000" → port aléatoire
```

### 🎯 IMPACT FONCTIONNEL
- **API Supabase non accessible** sur port attendu 8001
- **URLs configuration incorrectes** dans autres services
- **Studio potentiellement non connecté** à l'API

---

## PROBLÈME 2: REALTIME RESTART LOOP PERSISTANT

### 🔍 SYMPTÔMES
```bash
docker ps | grep realtime
# Restarting (1) Less than a second ago
```

### 📋 ANALYSE À APPROFONDIR

**Corrections déjà appliquées:**
- ✅ DB_ENC_KEY généré (16 chars)
- ✅ SECRET_KEY_BASE généré (64 chars)
- ✅ APP_NAME configuré
- ✅ Opérateur uuid = text créé
- ✅ Schema realtime créé
- ✅ RLIMIT_NOFILE configuré (65536)

**Diagnostic requis:**
```bash
# Logs Realtime détaillés
docker logs supabase-realtime --tail=20

# Variables environment dans conteneur
docker exec supabase-realtime env | grep -E "DB_|SECRET_|APP_"

# Test connectivité DB depuis Realtime
docker exec supabase-realtime pg_isready -h db -p 5432
```

**Hypothèses:**
1. Problème connectivité base de données
2. Variables environment manquantes ou incorrectes
3. Permission database insuffisantes
4. Configuration Elixir/Erlang incompatible ARM64

---

## PROBLÈME 3: STUDIO UNHEALTHY

### 🔍 SYMPTÔMES
```bash
docker ps | grep studio
# Up 5 minutes (unhealthy)
```

### 📋 ANALYSE TECHNIQUE

**Service Studio dependencies:**
- **Kong**: Doit être accessible sur port configuré
- **Meta**: Doit exposer API PostgreSQL métadonnées
- **Database**: Connexion PostgreSQL directe

**Configuration Studio:**
```yaml
environment:
  STUDIO_PG_META_URL: http://meta:8080
  SUPABASE_URL: http://kong:8000        # ← Problème si Kong mal configuré
  SUPABASE_REST_URL: http://kong:8000/rest/v1/
```

**Healthcheck Studio probable:**
- Test connexion vers Meta API
- Test connexion vers Kong gateway
- Vérification JWT tokens

### 🎯 IMPACT
- **Interface web Supabase inaccessible**
- **Gestion database via UI impossible**
- **Développement ralenti**

---

## PROBLÈME 4: EDGE FUNCTIONS UNHEALTHY

### 🔍 SYMPTÔMES
```bash
docker ps | grep edge
# Up 5 minutes (unhealthy)
```

### 📋 ANALYSE TECHNIQUE

**Configuration Edge Functions:**
```yaml
command:
  - start
  - --main-service
  - /home/deno/functions/hello
environment:
  JWT_SECRET: ${JWT_SECRET}
  SUPABASE_URL: http://kong:8000       # ← Dépend de Kong
```

**Healthcheck probable:**
- Test fonction hello accessible
- Validation JWT_SECRET
- Connexion vers Supabase API

**Fonction créée:**
```javascript
// /home/deno/functions/hello/index.ts
export default async function handler(req) {
  const data = {
    message: `Hello from ${name}!`,
    timestamp: new Date().toISOString(),
    platform: "Pi 5 ARM64",
    status: "running"
  }
  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" }
  })
}
```

---

## PROBLÈME 5: VARIABLES ENVIRONMENT INCOHÉRENTES

### 🔍 SYMPTÔMES OBSERVÉS

**Warnings durant installation:**
```
time="2025-09-15T22:49:38+02:00" level=warning msg="The \"SUPABASE_PORT\" variable is not set. Defaulting to a blank string."
```

**Répétition multiple:**
- Pendant démarrage PostgreSQL
- Pendant démarrage services restants
- Pendant redémarrages

### 📋 ANALYSE TIMING

**Séquence problématique:**
1. **Génération .env** avec variables correctes
2. **Validation YAML** passe (variables présentes)
3. **Démarrage services** → Warnings variables manquantes
4. **Kong** démarre avec port aléatoire

**Hypothèse timing:**
- Variables ajoutées au .env APRÈS création docker-compose.yml
- Services démarrés avant finalisation .env
- Cache Docker Compose des variables

---

## MÉTHODE DE RÉSOLUTION SYSTÉMATIQUE

### 📋 ORDRE PRIORITAIRE

#### 1. **SUPABASE_PORT (CRITIQUE)**
- Impact: API inaccessible
- Prérequis: Autres services
- Correction: Simple restart Kong

#### 2. **REALTIME (BLOQUANT)**
- Impact: Fonctionnalité temps réel
- Diagnostic: Logs détaillés requis
- Correction: Dépend diagnostic

#### 3. **STUDIO (UX)**
- Impact: Interface utilisateur
- Prérequis: Kong corrigé
- Correction: Probable auto-résolution

#### 4. **EDGE FUNCTIONS (OPTIONNEL)**
- Impact: Fonctions serverless
- Prérequis: Kong + Auth
- Correction: Probable auto-résolution

### 🔧 APPROCHE DIAGNOSTIC

Pour chaque problème:
1. **Collecter logs détaillés**
2. **Identifier cause racine**
3. **Appliquer correction ciblée**
4. **Valider résolution**
5. **Documenter pour intégration script**

---

## PRÉPARATION CORRECTIONS

### 📋 COMMANDES DIAGNOSTIC À EXÉCUTER

```bash
# === PROBLÈME 1: KONG PORT ===
echo "=== KONG PORT DIAGNOSTIC ==="
grep SUPABASE_PORT .env
docker port supabase-kong
curl -s http://localhost:32768 | head -5  # Port actuel
curl -s http://localhost:8001 | head -5   # Port attendu

# === PROBLÈME 2: REALTIME LOGS ===
echo "=== REALTIME DIAGNOSTIC ==="
docker logs supabase-realtime --tail=30
docker exec supabase-realtime env | grep -E "DB_|SECRET_|APP_|JWT_"

# === PROBLÈME 3: STUDIO HEALTH ===
echo "=== STUDIO DIAGNOSTIC ==="
docker logs supabase-studio --tail=20
curl -s http://localhost:3000 | head -10

# === PROBLÈME 4: EDGE FUNCTIONS ===
echo "=== EDGE FUNCTIONS DIAGNOSTIC ==="
docker logs supabase-edge-functions --tail=20
curl -s http://localhost:54321 | head -10

# === PROBLÈME 5: VARIABLES ENVIRONMENT ===
echo "=== ENVIRONMENT VARIABLES ==="
docker compose config | grep -A5 -B5 "SUPABASE_PORT"
```

### 🎯 OBJECTIFS POST-CORRECTION

1. **Kong accessible sur port 8001**
2. **Realtime en état running stable**
3. **Studio healthy et accessible**
4. **Edge Functions healthy**
5. **API complète fonctionnelle**

---

## INTÉGRATION PRÉVENTIVE SCRIPT

### 🔧 AMÉLIORATIONS À INTÉGRER

#### 1. **Validation variables avant démarrage services**
```bash
validate_env_before_start() {
  local required_vars=("SUPABASE_PORT" "JWT_SECRET" "DB_ENC_KEY" "SECRET_KEY_BASE")
  for var in "${required_vars[@]}"; do
    if ! grep -q "^${var}=" .env; then
      error "Variable $var manquante dans .env"
      return 1
    fi
  done
}
```

#### 2. **Post-install validation**
```bash
validate_post_install() {
  log "🧪 Validation post-installation..."

  # Test port Kong correct
  local kong_port=$(docker port supabase-kong | grep "8000/tcp" | cut -d: -f2)
  if [[ "$kong_port" != "8001" ]]; then
    warn "Kong port incorrect: $kong_port (attendu: 8001)"
    return 1
  fi

  # Test services healthy
  local unhealthy=$(docker ps --filter "health=unhealthy" --format "{{.Names}}" | grep supabase | wc -l)
  if [[ "$unhealthy" -gt 0 ]]; then
    warn "$unhealthy services unhealthy détectés"
  fi
}
```

#### 3. **Diagnostic automatique problèmes courants**
```bash
diagnose_common_issues() {
  log "🔍 Diagnostic automatique problèmes post-install..."

  # Check Realtime restart loop
  if docker ps | grep supabase-realtime | grep -q "Restarting"; then
    log "❌ Realtime restart loop détecté"
    docker logs supabase-realtime --tail=10
  fi

  # Check Kong port mapping
  local kong_port=$(docker port supabase-kong | grep "8000/tcp" | cut -d: -f2)
  if [[ "$kong_port" != "8001" ]]; then
    log "❌ Kong port mapping incorrect: $kong_port"
  fi
}
```

### 📊 VERSION CIBLE

**Script Week2 v2.4:**
- Validation variables avant démarrage
- Diagnostic post-install automatique
- Correction automatique problèmes courants
- Rapport final détaillé

---

## PROCHAINES ÉTAPES

1. **Exécuter diagnostic complet** (commandes préparées ci-dessus)
2. **Corriger problèmes dans l'ordre de priorité**
3. **Valider résolutions une par une**
4. **Documenter corrections appliquées**
5. **Intégrer améliorations dans script Week2**

**Session continue...**