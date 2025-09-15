# 🥧 Pi 5 Supabase Issues & Solutions Complètes

## 📊 Synthèse des Problèmes Identifiés

### 🔴 **Issues Critiques**

#### 1. **Page Size 16KB Incompatibilité** (Issue GitHub #30640)
- **Problème** : Pi 5 utilise page size 16KB par défaut, PostgreSQL attend 4KB
- **Erreur** : `docker compose up -d` échoue sur `supabase-db`
- **Impact** : Impossible de démarrer PostgreSQL/Supabase
- **Solution** :
  ```bash
  # Ajouter à /boot/firmware/config.txt
  kernel=kernel8.img
  # Redémarrer le Pi
  sudo reboot
  # Vérifier : getconf PAGESIZE doit retourner 4096
  ```

#### 2. **supabase-vector ARM64 Incompatibilité**
- **Problème** : `supabase-vector` ne supporte pas ARM64 avec 16KB pages
- **Erreur** : `Unsupported system page size memory allocation`
- **Impact** : Bloque le démarrage des autres services
- **Solutions** :
  - **Option A** : Désactiver supabase-vector dans docker-compose.yml
  - **Option B** : Changer page size système (voir solution #1)

#### 3. **Variables Mots de Passe Incohérentes**
- **Problème** : Docker-compose utilise des variables différentes pour chaque service
  ```yaml
  # Services utilisent des mots de passe différents :
  auth: postgres://supabase_admin:${POSTGRES_PASSWORD}@db
  rest: postgres://authenticator:${AUTHENTICATOR_PASSWORD}@db
  storage: postgres://supabase_storage_admin:${SUPABASE_STORAGE_PASSWORD}@db
  ```
- **Impact** : `password authentication failed for user`
- **Solution** : Unifier avec `POSTGRES_PASSWORD` unique

#### 4. **Volume Database Persistant**
- **Problème** : Volume `/volumes/db/data` garde ancienne config après changements
- **Impact** : Nouveaux mots de passe ignorés
- **Solution** : `rm -rf volumes/db/data` avant redémarrage

### 🟡 **Issues Performance**

#### 5. **Healthchecks ARM64 Inadaptés**
- **Problème** : Timeouts trop courts pour ARM64
- **Impact** : Services marqués unhealthy prématurément
- **Solution** : Augmenter timeouts et retries

#### 6. **Memory Limits Trop Basses**
- **Problème** : Pi 5 16GB limité à 256MB par service
- **Impact** : Performance dégradée
- **Solution** : Augmenter à 512MB-1GB

#### 7. **Docker Configuration Non-Optimisée**
- **Problème** : Configuration Docker générique
- **Impact** : Performance ARM64 sous-optimale
- **Solution** : Configuration spécifique ARM64

## 🛠️ **Solutions Détaillées**

### **Solution 1 : Page Size Fix (Obligatoire)**

```bash
# 1. Vérifier page size actuel
getconf PAGESIZE

# 2. Si 16384, modifier config.txt
sudo nano /boot/firmware/config.txt
# Ajouter : kernel=kernel8.img

# 3. Redémarrer
sudo reboot

# 4. Vérifier après redémarrage
getconf PAGESIZE  # Doit retourner 4096
```

### **Solution 2 : Docker-Compose Unifié**

```yaml
# Variables unifiées pour tous les services
auth:
  environment:
    GOTRUE_DB_DATABASE_URL: postgres://supabase_admin:${POSTGRES_PASSWORD}@db:5432/postgres

rest:
  environment:
    PGRST_DB_URI: postgres://authenticator:${POSTGRES_PASSWORD}@db:5432/postgres

storage:
  environment:
    DATABASE_URL: postgres://supabase_storage_admin:${POSTGRES_PASSWORD}@db:5432/postgres
```

### **Solution 3 : supabase-vector Désactivation**

```yaml
# Commenter ou supprimer section vector
# vector:
#   container_name: supabase-vector
#   image: timberio/vector:0.28.1-alpine
#   # ... reste de la config

# Supprimer dépendances vector dans autres services
# depends_on:
#   vector:
#     condition: service_healthy
```

### **Solution 4 : Optimisations ARM64**

```yaml
# Healthchecks optimisés
db:
  healthcheck:
    interval: 45s
    timeout: 20s
    retries: 8
    start_period: 90s

# Memory limits augmentées
auth:
  deploy:
    resources:
      limits:
        memory: 512MB
        cpus: '1.0'
```

## 📋 **Checklist Pré-Installation**

### **Système**
- [ ] Pi 5 avec Raspberry Pi OS 64-bit
- [ ] RAM 16GB disponible
- [ ] Page size = 4096 bytes (`getconf PAGESIZE`)
- [ ] Docker et Docker Compose installés
- [ ] Ports libres : 3000, 8000, 8001, 5432, 54321

### **Configuration**
- [ ] Variables `.env` avec `POSTGRES_PASSWORD` unique
- [ ] Docker-compose sans `supabase-vector` ou page size fixé
- [ ] Volume `volumes/db/data` supprimé si réinstallation
- [ ] Permissions Docker correctes pour utilisateur

## 🚨 **Erreurs Courantes & Solutions**

### **Erreur** : `password authentication failed for user "supabase_admin"`
```bash
# Solution
docker compose down
rm -rf volumes/db/data  # Reset volume
# Vérifier variables .env
# Redémarrer
docker compose up -d
```

### **Erreur** : `supabase-vector container is unhealthy`
```bash
# Solution A : Désactiver vector
# Commenter section vector dans docker-compose.yml

# Solution B : Fix page size
echo "kernel=kernel8.img" >> /boot/firmware/config.txt
sudo reboot
```

### **Erreur** : Services en boucle `Restarting`
```bash
# Solution
# 1. Vérifier logs
docker compose logs auth
# 2. Unifier mots de passe
# 3. Reset volume database
# 4. Augmenter healthcheck timeouts
```

## 🎯 **Configuration Recommandée Pi 5**

### **.env Optimisé**
```env
# Core
POSTGRES_PASSWORD=VotreMotDePasseSecurise123
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long

# Optimisations Pi 5 16GB
POSTGRES_SHARED_BUFFERS=1GB
POSTGRES_WORK_MEM=64MB
POSTGRES_MAINTENANCE_WORK_MEM=256MB
POSTGRES_MAX_CONNECTIONS=200
POSTGRES_EFFECTIVE_CACHE_SIZE=8GB

# URLs
SUPABASE_PUBLIC_URL=http://192.168.1.73:8001
API_EXTERNAL_URL=http://192.168.1.73:8001
```

### **Docker-Compose Optimisé**
- Memory limits : 512MB minimum par service

---

## 🔎 Deep‑Dive: Services qui redémarrent en boucle (Pi 5)

Cette section compile des causes récurrentes et correctifs éprouvés pour les services Realtime, Kong et Edge Functions qui restent en « Restarting » sur Raspberry Pi 5 (ARM64), basés sur la documentation officielle Supabase/Kong et retours de la communauté.

### 1) Realtime — RLIMIT_NOFILE et limites de descripteurs

- Symptômes typiques:
  - Logs: messages liés à `RLIMIT_NOFILE`, sockets/FD ou accept() échouant sous charge.
  - Le service démarre, puis redémarre lors de pics de connexions WebSocket.

- Causes probables:
  - Limites d’OS/daemon Docker trop basses (nofile), et/ou conteneur sans `ulimits` explicites.
  - L’ENV seule `RLIMIT_NOFILE` ne suffit pas si Docker n’autorise pas le relèvement.

- Vérifications rapides:
  - `docker compose exec -T realtime sh -lc 'ulimit -n; cat /proc/self/limits | grep -i files'`
  - Attendu: soft/hard ≥ 65536.

- Correctifs recommandés:
  1) Côté Docker daemon (hôte): élever les limites au niveau du service Docker.
     - Fichier: `/etc/systemd/system/docker.service.d/override.conf`
       ```ini
       [Service]
       LimitNOFILE=1048576
       ```
     - Appliquer: `systemctl daemon-reload && systemctl restart docker`

  2) Côté Compose (service `realtime`): fixer des `ulimits` et (si nécessaire) ajouter la capacité système.
     ```yaml
     realtime:
       ulimits:
         nofile:
           soft: 65536
           hard: 65536
       cap_add:
         - SYS_RESOURCE   # si le runtime a besoin d’élever des limites
     ```

  3) Paramètres complémentaires utiles:
     ```yaml
     realtime:
       environment:
         API_JWT_SECRET: ${JWT_SECRET}
         SECRET_KEY_BASE: ${JWT_SECRET}
       # (optionnel) sysctls réseau si forte charge
       sysctls:
         net.core.somaxconn: 65535
     ```

  4) Recréer le service après changement (relecture des limites):
     - `docker compose up -d --force-recreate realtime`

  5) Sanity‑check:
     - `curl -I http://localhost:${API_PORT:-8001}/realtime/v1/` → 426/200 (OK)

### 2) Kong — « permission denied » sur kong.yml et résolution DNS interne

- Symptômes typiques:
  - Logs: `permission denied` sur `/tmp/kong.yml` lors de l’entrypoint.
  - Logs: erreurs DNS `queryDns(): ... empty record received` pour `rest`, `auth`, etc.

- Causes probables:
  - Le fichier `kong.yml` est monté en lecture seule mais l’entrypoint essaie d’écrire au même chemin.
  - Résolveur DNS de Kong non fixé sur le DNS Docker (127.0.0.11) → échecs de résolution des noms de services Compose.

- Correctifs recommandés:
  1) Ne pas écrire dans le fichier monté RO. Utiliser un template .tpl en RO et générer un fichier RW distinct au démarrage.
     ```yaml
     kong:
       environment:
         KONG_DATABASE: 'off'
         KONG_DECLARATIVE_CONFIG: /tmp/kong.yml
         KONG_DNS_ORDER: LAST,A,CNAME
         KONG_DNS_RESOLVER: 127.0.0.11:53   # forcer DNS Docker interne
       volumes:
         - ./config/kong.yml:/tmp/kong.tpl.yml:ro
       entrypoint: >
         bash -lc 'command -v envsubst >/dev/null || apk add --no-cache gettext; envsubst < /tmp/kong.tpl.yml > /tmp/kong.yml && /docker-entrypoint.sh kong docker-start'
     ```

  2) Vérifier le réseau: Kong et les services `rest/auth/realtime/storage/meta` doivent partager le même réseau Compose (par défaut).
     - `docker compose ps` → tous sur `supabase_network`.

  3) Option alternative (simple): autoriser l’écriture (moins strict):
     ```yaml
     volumes:
       - ./config/kong.yml:/tmp/kong.yml    # sans :ro
     entrypoint: bash -lc 'cp /tmp/kong.yml /tmp/kong.run.yml && \ 
       /docker-entrypoint.sh kong docker-start'
     environment:
       KONG_DECLARATIVE_CONFIG: /tmp/kong.run.yml
     ```

  4) Recréer Kong: `docker compose up -d --force-recreate kong`
     - Tester: `curl -I http://localhost:${API_PORT:-8001}/rest/v1/`

### 3) Edge Functions — redémarrages dus au contenu et à la configuration

- Symptômes typiques:
  - Le conteneur `edge-runtime` démarre puis redémarre sans fin.
  - 404/503 via Kong sur `/functions/v1/…`.

- Causes fréquentes:
  - Aucun code de fonction présent au chemin attendu (`--main-service` inexistant).
  - Variables `SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY/JWT_SECRET` absentes.
  - Route/Upstream manquants dans Kong.

- Correctifs recommandés:
  1) S’assurer qu’un exemple minimal de fonction est présent.
     ```bash
     mkdir -p volumes/functions/hello
     cat > volumes/functions/hello/index.ts <<'TS'
     export default async (req: Request) => new Response('Hello from Pi5!', { status: 200 })
     TS
     ```

  2) Configurer correctement `edge-runtime` dans Compose.
     ```yaml
     edge-functions:
       image: supabase/edge-runtime:v1.58.2
       environment:
         JWT_SECRET: ${JWT_SECRET}
         SUPABASE_URL: http://kong:8000
         SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
         SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_KEY}
       ports:
         - "${FUNCTIONS_PORT:-54321}:9000"
       volumes:
         - ./volumes/functions:/home/deno/functions:Z
       command: [ "start", "--main-service", "/home/deno/functions/hello" ]
       restart: unless-stopped
       healthcheck:
         test: ["CMD", "wget", "--spider", "-q", "http://localhost:9000/_internal/health/liveness"]
         interval: 10s
         timeout: 3s
         retries: 5
     ```

  3) Ajouter le routage via Kong.
     ```yaml
     # kong.yml
     upstreams:
       - name: functions
         targets: [ { target: edge-functions:9000 } ]
     services:
       - name: functions
         url: http://functions
         routes:
           - name: functions
             paths: [ /functions/v1/ ]
     ```

  4) Recréer et tester:
     - `docker compose up -d --force-recreate edge-functions kong`
     - Direct: `curl -i http://localhost:54321/functions/v1/hello`
     - Via Kong: `curl -i http://localhost:${API_PORT:-8001}/functions/v1/hello`

  5) Si vous ne prévoyez pas d’utiliser Edge Functions immédiatement:
     - Désactiver temporairement le service pour stabiliser le stack, puis le réactiver une fois une fonction prête.

---

## 🔁 Procédure d’alignement rapide (quand plusieurs services bouclent)

1) DB prête et rôles cohérents:
   ```bash
   cd ~/stacks/supabase
   POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' .env | cut -d= -f2)
   AUTHENTICATOR_PASSWORD=$(grep '^AUTHENTICATOR_PASSWORD=' .env | cut -d= -f2)
   docker compose exec -T db psql -U supabase_admin -d postgres -c "ALTER USER supabase_admin WITH PASSWORD '${POSTGRES_PASSWORD}';"
   docker compose exec -T db psql -U supabase_admin -d postgres -c "ALTER USER authenticator WITH PASSWORD '${AUTHENTICATOR_PASSWORD}';"
   docker compose exec -T db psql -U supabase_admin -d postgres -c "ALTER USER supabase_storage_admin WITH PASSWORD '${POSTGRES_PASSWORD}';"
   ```

2) Recréer les services dépendants (relecture .env):
   ```bash
   docker compose up -d --force-recreate auth rest storage realtime kong studio
   ```

3) Spécifique Pi 5 (optionnel mais recommandé): activer cgroups mémoire pour retirer les warnings et améliorer l’isolation:
   - Ajouter dans `/boot/firmware/cmdline.txt` :
     `cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1`
   - Redémarrer la machine.

4) Vérifier:
   ```bash
   bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/debug/supabase-verify.sh)
   ```

---

## 📚 Références utiles (pour aller plus loin)

- Supabase — Self‑hosting & services: Auth, Realtime, Storage, Studio
- Kong Gateway — configuration déclarative, DNS interne Docker, plugins CORS
- Docker Compose — ulimits, cap_add, healthchecks, networks

Astuce: en environnement Docker, forcer `KONG_DNS_RESOLVER=127.0.0.11:53` ancre Kong sur le DNS interne, évitant des intermittences de résolution des noms de services Compose.
- CPU limits : 1.0 minimum
- Healthcheck intervals : 45s
- Timeouts : 20-30s
- Start period : 90s

## 📚 **Références**

### **GitHub Issues**
- [#30640](https://github.com/supabase/supabase/issues/30640) - Pi OS 64-bit compatibility
- [#18836](https://github.com/supabase/supabase/issues/18836) - Database password issues
- [#11957](https://github.com/supabase/supabase/issues/11957) - Auth admin password failed
- [#16777](https://github.com/supabase/supabase/issues/16777) - Vector container unhealthy

### **Solutions Communautaires**
- Page size fix confirmé par plusieurs utilisateurs
- Vector désactivation validée sur ARM64
- Variables mot de passe unifiées testées

### **Performance Pi 5**
- 16KB pages : +7% performance mémoire mais incompatibilité
- 4KB pages : Compatibilité PostgreSQL garantie
- RAM 16GB : Permet d'augmenter significativement les limites

---

**📝 Note** : Cette documentation consolide tous les problèmes identifiés et solutions validées pour installer Supabase sur Pi 5 en 2025.
