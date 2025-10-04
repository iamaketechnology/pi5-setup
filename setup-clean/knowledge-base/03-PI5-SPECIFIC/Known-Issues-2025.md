# 🐛 Known Issues 2025 - Supabase ARM64 Raspberry Pi 5

> Issues documentées, vérifiées sur sources officielles et community-tested
> Dernière mise à jour : Octobre 2025

---

## 📊 Vue d'Ensemble

Ce document consolide :
- ✅ **Issues GitHub officielles** Supabase (2024-2025)
- ✅ **Recherches web** récentes (Reddit, Forums, Stack Overflow)
- ✅ **Solutions testées** par la communauté Pi 5
- ✅ **Workarounds** documentés et validés

---

## 🔴 ISSUES CRITIQUES (Bloquantes)

### 1. Page Size 16KB Incompatibilité PostgreSQL ⚠️ **CRITIQUE**

Référence principale :
- Issue GitHub Supabase: [#30640](https://github.com/supabase/supabase/issues/30640) — Unable to run self-hosted Supabase on Raspberry Pi OS (64-bit)
- Kernel Pi 5 (BCM2712) par défaut en 16KB: `CONFIG_ARM64_16K_PAGES=y` dans le defconfig officiel (preuve compile-time) — voir `bcm2712_defconfig` [rpi-6.6.y](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.6.y/arch/arm64/configs/bcm2712_defconfig)

#### Symptômes

```
ERROR: page size mismatch: expected 4096, got 16384
FATAL: database files are incompatible with server
```

ou

```
<jemalloc>: Unsupported system page size: 16384
docker: Error response from daemon: failed to create task for container: failed to create shim task
```

#### Cause racine (vérifiée)

- Raspberry Pi OS pour Pi 5 utilise par défaut un noyau ARM64 avec pages mémoire de 16KB (CONFIG ARM64_16K_PAGES activée).
- La majorité des binaires/containers (PostgreSQL, jemalloc utilisée par certains services) sont construits pour 4KB et échouent quand la page = 16KB.
- Conséquence: `supabase-db` (Postgres) et d’autres services peuvent ne pas démarrer (erreurs pagesize/jemalloc dans #30640).

#### Impact

- 🔴 **Installation impossible** sans ce fix
- 🔴 **Service `supabase-db` en crash loop**
- 🔴 **Tous les services dépendants échouent**

#### Solutions viables (vérifiées) et validations

Important: La taille de page mémoire est un paramètre de compilation du noyau (compile-time), pas un simple paramètre `cmdline.txt`. Il n’existe pas d’option runtime générique `pagesize=4k` pour forcer 4KB. Preuve: le defconfig Pi 5 active `CONFIG_ARM64_16K_PAGES=y` [bcm2712_defconfig](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.6.y/arch/arm64/configs/bcm2712_defconfig).

- Option A (recommandée): Utiliser un noyau 4KB pour Pi 5
  - Installer/démarrer un noyau ARM64 Pi 5 compilé avec `CONFIG_ARM64_4K_PAGES`. Cela peut nécessiter l’installation d’une variante 4KB du noyau Raspberry Pi OS ou l’utilisation d’une distribution qui fournit un noyau 4KB par défaut sur Pi 5.
  - Alternative pratique: utiliser Ubuntu/Debian arm64 récents sur Pi 5 (généralement 4KB par défaut). Vérifier avec `getconf PAGESIZE`.
- Option B: Compiler soi‑même un noyau Pi 5 avec pages 4KB (avancé)
  - Partir du repo `raspberrypi/linux` (branche rpi-6.6.y) et activer `CONFIG_ARM64_4K_PAGES` plutôt que `ARM64_16K_PAGES`.
- Option C: Contournements partiels
  - Désactiver certains services sensibles à 16KB (ex: `vector`, cf. Issue 2) ne règle pas Postgres. Utile seulement si Postgres fonctionne déjà en 4KB.

Validation après reboot (quelle que soit la méthode):
```bash
getconf PAGESIZE  # doit retourner 4096
```

#### Notes & références communauté

- Discussion forum Raspberry Pi: [Why to run 16k page size for RPi5?](https://forums.raspberrypi.com/viewtopic.php?t=361390) — gain perf ~7% avec 16KB vs compatibilité logicielle bien meilleure en 4KB.
- Issue Supabase: [#30640](https://github.com/supabase/supabase/issues/30640) — captures/rapports confirment erreurs 16KB.

#### Statut 2025

- 🟡 Issue ouverte côté Supabase (comportements liés au 16KB non supportés dans de multiples images).
- 🟢 Workaround stable: exécuter un noyau 4KB (distro ou kernel alternatif) — Postgres et services dependants démarrent.
- 🔴 Support 16KB côté binaires tiers (jemalloc/Postgres/alpine) non généralisé.

---

### 2. supabase-vector (Vector) incompatible 16KB

Références:
- Issue liée: [#30640](https://github.com/supabase/supabase/issues/30640)

#### Symptômes

```
supabase-vector | <jemalloc>: Unsupported system page size
supabase-vector | Segmentation fault (core dumped)
```

#### Cause

- Le container `vector` (timberio/vector) utilise `jemalloc` construit pour 4KB.
- Avec un noyau 16KB, `jemalloc` échoue (`Unsupported system page size`) et le processus crash.

#### Solutions

**Option A** : Fix page size (voir Issue #1) → Résout aussi vector

**Option B** : Désactiver vector dans docker-compose.yml

```yaml
# Commenter section complète
# vector:
#   container_name: supabase-vector
#   image: timberio/vector:0.28.1-alpine
#   ...

# Supprimer dépendances vector dans autres services
services:
  analytics:
    depends_on:
      # vector:  # ← COMMENTER
      #   condition: service_healthy
```

**Option C** : Image alternative (non officiel) — à éviter en prod, préférer 4KB côté OS.

#### Recommandation

🎯 **Fixer page size à 4KB** → Résout vector ET PostgreSQL ensemble

---

## 🟡 ISSUES MAJEURES (Fréquentes)

### 3. Auth Service – erreur de cast UUID/Text (cas observé)

Référence migrations Auth:
- `20221208132122_backfill_email_last_sign_in_at.up.sql` (Supabase Auth) — voir le repo officiel: [migrations](https://github.com/supabase/auth/tree/master/migrations)

#### Symptômes

```
ERROR: operator does not exist: uuid = text (SQLSTATE 42883)
HINT: No operator matches the given name and argument types
FILE: /migrations/20221208132122_backfill_email_last_sign_in_at.up.sql
```

Service `supabase-auth` en restart loop.

#### Cause possible

- Selon certaines installations, des migrations ou requêtes custom peuvent comparer `uuid` et `text` sans cast explicite, ce qui peut déclencher `operator does not exist: uuid = text` (SQLSTATE 42883) selon la configuration.
- Les migrations officielles récentes utilisent généralement un cast côté `text` (ex: `id = user_id::text`). Problème surtout observé dans environnements divergents ou versions antérieures.

#### Pistes de contournement (si l’erreur apparaît)

Préférer corriger la requête fautive avec des casts explicites (`::text` ou `::uuid`) plutôt que d’ajouter un opérateur global `uuid = text`.

Exemples utiles:
```sql
-- Comparer en text côté gauche/droite de façon explicite
-- (à adapter à la requête réelle qui échoue)
... WHERE identities.id = identities.user_id::text;
-- ou
... WHERE identities.id::uuid = identities.user_id;
```

Si nécessaire, appliquer la migration incriminée manuellement après correction, puis redémarrer `auth`.

#### Solution Manuelle (si besoin)

```bash
cd ~/stacks/supabase

# Exécuter le SQL fix
docker compose exec db psql -U postgres -d postgres <<'EOF'
CREATE OR REPLACE FUNCTION uuid_text_eq(uuid, text) RETURNS boolean AS
$func$ SELECT $1::text = $2; $func$ LANGUAGE SQL IMMUTABLE;
CREATE OPERATOR = (LEFTARG = uuid, RIGHTARG = text, FUNCTION = uuid_text_eq);
EOF

# Redémarrer auth
docker compose restart auth
```

#### Statut 2025

- 🟡 Problème non systématique; dépend des versions et des requêtes.
- ✅ Solution: utiliser des casts explicites dans les requêtes/migrations affectées.

---

### 4. Realtime – variables d’environnement manquantes (encryption/clé)

Références officielles:
- README Realtime (liste des env vars): [supabase/realtime](https://github.com/supabase/realtime/blob/main/README.md)

#### Symptômes

```
[error] Erlang error: {:badarg, {~c"api_ng.c", 228}, ~c"Bad key"}
[error] crypto_one_time(:aes_128_ecb, nil, ...)
[error] Realtime.Tenants.Encrypt.decrypt/2
```

Service `supabase-realtime` crash au démarrage.

#### Cause

- Realtime s’appuie sur des variables telles que `DB_ENC_KEY`, `SECRET_KEY_BASE`, `JWT_SECRET`, etc. Si `DB_ENC_KEY` est requis pour chiffrer/déchiffrer des champs (tenants/extensions) et n’est pas défini, certaines opérations peuvent échouer.

#### Recommandations

- Définir des valeurs sûres et persistantes:
  - `DB_ENC_KEY`: clé utilisée pour chiffrer certains champs internes. Recommandation: 16 caractères (cf. README Realtime), pas nécessairement hexadécimal.
  - `SECRET_KEY_BASE`: secret Phoenix pour signer les cookies. Recommandation: ~64 caractères.
  - `JWT_SECRET`/`API_JWT_SECRET`: cohérents avec votre configuration JWT.
  - `APP_NAME`: optionnel (nom d’instance).

#### Exemple de configuration (.env / compose)

```yaml
realtime:
  environment:
    DB_HOST: "db"
    DB_PORT: "5432"
    DB_USER: "supabase_admin"
    DB_PASSWORD: "${POSTGRES_PASSWORD}"
    DB_NAME: "postgres"
    DB_SSL: "disable"

    DB_ENC_KEY: "${DB_ENC_KEY}"          # 16 caractères recommandés
    SECRET_KEY_BASE: "${SECRET_KEY_BASE}" # ~64 caractères recommandés

    JWT_SECRET: "${JWT_SECRET}"
    SLOT_NAME: "supabase_realtime_slot"
    PUBLICATIONS: '["supabase_realtime"]'
    REPLICATION_MODE: "RLS"
    APP_NAME: "supabase_realtime"
    PORT: "4000"
```

#### Statut 2025

- 🟢 Bien documenté dans le README Realtime; certaines variables sont nécessaires selon les fonctionnalités activées.
- 🟡 Les templates `.env` génériques peuvent omettre ces clés — ajouter manuellement.

---

### 5. Docker Compose YAML Corruption – Indentation

**Issue** : Corruption silencieuse lors de sed/awk dans scripts

#### Symptômes

```
yaml: line 95: did not find expected key
Error response from daemon: invalid compose project
```

#### Cause

- Scripts utilisent `sed` pour injecter variables
- Indentation YAML cassée (espaces vs tabs)
- `APP_NAME` souvent mal indenté (8 espaces au lieu de 6)

#### Solution Préventive (Scripts)

```bash
# Utiliser sed avec contexte d'indentation
sed -i '/environment:/a\      APP_NAME: "supabase_realtime"' docker-compose.yml
#                             ^^^^^^ 6 espaces exactement

# Validation post-modification
docker compose config > /dev/null
if [ $? -ne 0 ]; then
  echo "ERROR: YAML invalide détecté"
  exit 1
fi
```

#### Fix manuel

```bash
cd ~/stacks/supabase

# Valider YAML
docker compose config

# Si erreur, vérifier indentation
nano docker-compose.yml
# Chercher "APP_NAME" et vérifier 6 espaces avant

# Alternative : régénérer docker-compose.yml
sudo ./scripts/setup-week2-supabase-final.sh
```

---

## ✅ ISSUES RÉSOLUES (Octobre 2025)

### 6. Studio Healthcheck 404 Error ✅ **RÉSOLU v3.21**

Référence:
- GitHub Issue [#8721](https://github.com/supabase/supabase/issues/8721) - API calls fail (404) in self-hosted studio
- GitHub Discussion [#12768](https://github.com/orgs/supabase/discussions/12768) - Studio docker issues

#### Symptômes

```bash
[15:04:18] ⏳ Waiting for Studio service to be healthy...
--- Healthcheck Diagnostic (60s elapsed) ---
Healthcheck command:
["CMD","node","-e","fetch('http://studio:3000/api/platform/profile')..."]

Last healthcheck output:
[0x40000fe190 0x40000fe1e0 0x40000fe230]

Manual healthcheck test:
HTTP Status: 404

Recent logs:
  ▲ Next.js 14.2.15
  - Network: http://0.0.0.0:3000
 ✓ Ready in 812ms
```

#### Cause Racine

- Endpoint `/api/platform/profile` est **cloud-only** (Supabase.com)
- N'existe pas dans l'application Next.js self-hosted
- Utilisé pour billing, permissions org, etc. (features cloud uniquement)
- Healthcheck échoue avec 404 malgré Studio fonctionnel

#### Solution (v3.21)

```yaml
# AVANT (v3.18-v3.20) - ÉCHOUE
healthcheck:
  test: ["CMD", "node", "-e", "fetch('http://studio:3000/api/platform/profile')..."]

# APRÈS (v3.21) - FONCTIONNE ✅
healthcheck:
  test: ["CMD", "node", "-e", "fetch('http://localhost:3000/').then((r) => {if (r.status !== 200) throw new Error(r.status)}).catch((e) => {console.error(e); process.exit(1)})"]
  interval: 5s
  timeout: 10s
  retries: 3
  start_period: 60s
```

**Changements:**
1. `/api/platform/profile` → `/` (root path vérifie juste que Next.js répond)
2. `http://studio:3000` → `http://localhost:3000` (healthcheck s'exécute dans le container)
3. Ajout `.catch()` pour gestion propre des erreurs

#### Vérification

```bash
# Test root path (devrait retourner 200)
docker exec supabase-studio node -e "fetch('http://localhost:3000/').then(r => console.log(r.status))"
# Output: 200 ✅

# Test cloud endpoint (404 attendu)
docker exec supabase-studio node -e "fetch('http://localhost:3000/api/platform/profile').then(r => console.log(r.status))"
# Output: 404 (normal - endpoint cloud-only)
```

#### Statut 2025

- ✅ **RÉSOLU** dans script v3.21
- ✅ Studio devient healthy en ~10 secondes
- ✅ Aucune intervention manuelle requise

---

### 7. Edge Functions Crash Loop ✅ **RÉSOLU v3.22**

Référence:
- Official [docker-compose.yml](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml)
- Blog [Edge Runtime Self-hosted](https://supabase.com/blog/edge-runtime-self-hosted-deno-functions)

#### Symptômes

```bash
NAMES                     STATUS                          PORTS
supabase-edge-functions   Restarting (2) 12 seconds ago

Recent logs:
  bundle    Creates an 'eszip' file...
  unbundle  Unbundles an .eszip file...
  help      Print this message or the help of the given subcommand(s)

Options:
  -v, --verbose     Use verbose output
  -h, --help        Print help
  -V, --version     Print version
```

#### Cause Racine

- Image `supabase/edge-runtime` a pour entrypoint le CLI binaire
- Sans `command` override, exécute `edge-runtime` sans args → help text → exit code 2
- Pas de volume `/home/deno/functions` → runtime ne trouve pas les fonctions
- Variables d'environnement manquantes (`SUPABASE_DB_URL`, `VERIFY_JWT`)

#### Solution (v3.22)

```yaml
# AVANT (v3.18-v3.21) - CRASH LOOP
edge-functions:
  image: supabase/edge-runtime:v1.58.2
  environment:
    JWT_SECRET: ${JWT_SECRET}
    SUPABASE_URL: http://kong:8000
  # PAS de command → help text
  # PAS de volumes → fonctions introuvables

# APRÈS (v3.22) - FONCTIONNE ✅
edge-functions:
  image: supabase/edge-runtime:v1.58.2
  platform: linux/arm64
  command:
    - start
    - --main-service
    - /home/deno/functions/main
  volumes:
    - ./volumes/functions:/home/deno/functions:Z
  environment:
    JWT_SECRET: ${JWT_SECRET}
    SUPABASE_URL: http://kong:8000
    SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
    SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
    SUPABASE_DB_URL: postgresql://postgres:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}
    VERIFY_JWT: "true"
  healthcheck:
    test: ["CMD", "sh", "-c", "pidof edge-runtime >/dev/null 2>&1 || pidof deno >/dev/null 2>&1"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 60s
```

**Création Auto du Répertoire:**

Script crée automatiquement:
```bash
./volumes/functions/main/index.ts  # Fonction d'exemple Hello World
```

#### Vérification

```bash
# Container devrait démarrer normalement
docker logs supabase-edge-functions
# Devrait montrer: "Edge Runtime starting..." au lieu de help text

# Tester la fonction
curl -X POST http://localhost:54321/functions/v1/main \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"name":"Pi5"}'
```

#### Statut 2025

- ✅ **RÉSOLU** dans script v3.22
- ✅ Edge Functions devient healthy en ~10 secondes
- ✅ Exemple de fonction créé automatiquement
- ✅ ARM64 fully supported (images multi-arch disponibles)

---

## 🟢 ISSUES MINEURES (Connues)

### 8. Healthchecks Timeouts sur ARM64

#### Symptômes

```
supabase-db    | Up 2 minutes (health: starting)
supabase-auth  | Up 3 minutes (unhealthy)
```

Services fonctionnels mais marqués unhealthy.

#### Cause

- Healthchecks configurés pour x86 (plus rapide)
- ARM64 Pi 5 plus lent → timeouts prématurés

#### Solution

Augmenter timeouts dans docker-compose.yml :

```yaml
db:
  healthcheck:
    interval: 45s      # au lieu de 30s
    timeout: 20s       # au lieu de 10s
    retries: 8         # au lieu de 5
    start_period: 90s  # au lieu de 60s
```

---

### 7. Memory limits trop bas pour Pi 5 16GB

#### Symptômes

```
OOMKilled
Container exceeded memory limit
```

#### Cause

- Limits mémoire configurés pour 4-8GB RAM
- Pi 5 avec 16GB peut gérer plus

#### Solution

```yaml
services:
  db:
    deploy:
      resources:
        limits:
          memory: 2G      # au lieu de 1G
  auth:
    deploy:
      resources:
        limits:
          memory: 512M    # au lieu de 256M
```

---

## 📈 Issues résolues (historique)

### ✅ ARM64 Images Indisponibles (2021-2023)

**Issue GitHub** : [#2954](https://github.com/supabase/supabase/issues/2954) - Support aarch64 for Compose setup

**Statut 2025** : 🟢 Résolu
- Toutes les images core disponibles en ARM64
- Tags multi-arch supportés
- Supabase CLI ARM64 disponible

---

### ✅ Docker daemon: recommandations logs (2024–2025)

Suggestion (générique) pour limiter la taille des logs conteneurs:

```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

(Ne pas annoncer de dépréciation non vérifiée; se référer aux release notes Docker 27 si nécessaire.)

---

## 🔍 Références vérifiées

- Supabase — Issue Pi 5 / 16KB: https://github.com/supabase/supabase/issues/30640
- Raspberry Pi Linux — defconfig Pi 5 (16KB pages): https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.6.y/arch/arm64/configs/bcm2712_defconfig
- Supabase Realtime — variables d’environnement: https://github.com/supabase/realtime/blob/main/README.md
- Supabase — ARM64 / multi-arch (historique): https://github.com/supabase/supabase/issues/2954
- Raspberry Pi Forums — 16KB vs 4KB: https://forums.raspberrypi.com/viewtopic.php?t=361390

---

## 📊 Notes et conseils pratiques

- Toujours valider `getconf PAGESIZE` avant d’investiguer des erreurs Postgres/jemalloc.
- Préférer SSD/NVMe via USB 3 pour de meilleures perfs I/O; éviter les cartes SD lentes pour des bases de données.
- Sur Pi 5 8–16GB, ajuster les healthchecks/ressources (voir sections 6–7) pour limiter les faux « unhealthy ».

---

## 🛠️ Outil de diagnostic rapide

### Script Validation Pi 5 (Community)

```bash
#!/bin/bash
# pi5-supabase-check.sh - Community diagnostic tool

echo "=== Raspberry Pi 5 Supabase Compatibility Check ==="

# Page size
PAGESIZE=$(getconf PAGESIZE)
if [ "$PAGESIZE" = "4096" ]; then
  echo "✅ Page size: 4096 (OK)"
else
  echo "❌ Page size: $PAGESIZE (FAIL - must be 4096)"
fi

# RAM
RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$RAM" -ge 8 ]; then
  echo "✅ RAM: ${RAM}GB (OK)"
else
  echo "⚠️  RAM: ${RAM}GB (WARNING - 8GB+ recommended)"
fi

# Docker
if command -v docker &> /dev/null; then
  echo "✅ Docker installed"
else
  echo "❌ Docker NOT installed"
fi

# Architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  echo "✅ Architecture: ARM64 (OK)"
else
  echo "❌ Architecture: $ARCH (FAIL - must be aarch64)"
fi
```

---

## 🔮 Roadmap & points d’attention

- Suivre le [changelog Supabase](https://supabase.com/changelog) et les issues liées au self-hosting ARM64.
- Le support 16KB côté écosystème container reste limité; privilégier 4KB pour compatibilité.

---

## 📚 Ressources Externes

### Issues GitHub actives

- [#30640](https://github.com/supabase/supabase/issues/30640) - Pi OS 64-bit issues (🔴 Ouvert)
- [#2954](https://github.com/supabase/supabase/issues/2954) - ARM64 support (🟢 Fermé)
- [#4887](https://github.com/supabase/supabase/issues/4887) - Docker images arch (🟢 Fermé)

### Forums & communautés

- [r/Supabase](https://reddit.com/r/Supabase) - Subreddit actif
- [Raspberry Pi Forums](https://forums.raspberrypi.com) - Section Docker
- [Supabase Discord](https://discord.supabase.com) - Canal #self-hosting

### Docs officielles

- [Self-Hosting Docker](https://supabase.com/docs/guides/self-hosting/docker)
- [Realtime Configuration](https://supabase.com/docs/reference/self-hosting-realtime)
- [Auth (GoTrue) Docs](https://supabase.com/docs/reference/self-hosting-auth)

---

## 💡 Conseils Généraux

### Avant de Débuter

1. ✅ **Lire** ce document entièrement
2. ✅ **Fixer page size** avant toute installation
3. ✅ **Utiliser** scripts automatisés testés
4. ✅ **Sauvegarder** `.env` et config initiales

### Pendant Installation

1. ⏱️ **Patienter** : ARM64 plus lent pour télécharger images
2. 📊 **Monitorer** : `docker stats` pour voir progression
3. 📝 **Logger** : Sauvegarder outputs scripts

### Après Installation

1. ✅ **Valider** : Script `supabase-health.sh`
2. 💾 **Backup** : Premier backup immédiatement
3. 📖 **Documenter** : Vos spécificités/modifications

---

<p align="center">
  <strong>📌 Document mis à jour régulièrement avec nouvelles issues/solutions</strong>
</p>

<p align="center">
  <a href="../README.md">← Retour Index</a> •
  <a href="Page-Size-Fix.md">Fix Page Size →</a>
</p>
