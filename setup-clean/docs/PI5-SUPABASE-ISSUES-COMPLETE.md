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