# 🟢 Semaine 2 – Supabase Self-hosted sur Raspberry Pi 5

🎯 **Objectif** : Installer un **stack Supabase complet** sur Pi 5 (16 Go) avec **optimisations ARM64**, éviter les pièges connus, et obtenir une plateforme de développement complète.

---

## ✅ Prérequis

**Avant de commencer, vérifiez :**

- ✅ **Week 1 terminée** : Docker + Portainer + sécurité configurés
- ✅ **Pi 5 connecté** : SSH accessible, 16GB RAM détectés
- ✅ **Espace disque** : Minimum 15GB libres pour Supabase
- ✅ **Architecture** : ARM64 (`uname -m` = `aarch64`)

**Connexion et vérifications :**

```bash
ssh pi@pi5.local
docker --version        # Doit afficher 27.x+
docker compose version  # Doit afficher v2.x+
df -h                   # Vérifier espace libre
```

---

## 📋 Plan 7 Jours - Supabase Pi 5

Supabase sur Pi 5 nécessite une approche progressive pour éviter les incompatibilités ARM64 et optimiser les ressources limitées.

| **Jour** | **Objectif** | **Durée** |
|----------|--------------|-----------|
| **J1** | 📂 Arborescence & secrets | 30min |
| **J2** | 🐳 Configuration ARM64 | 45min |
| **J3** | 🚀 Démarrage & tests | 60min |
| **J4** | 🔒 Sécurité UFW | 30min |
| **J5** | 📁 Backup & maintenance | 45min |
| **J6-7** | 🔬 Extensions & validation | 90min |

---

## ✅ Installation Automatisée Complète

### 📥 Installation automatique complète

**🧹 Nettoyage installation précédente (si nécessaire) :**
```bash
# Arrêter containers précédents
cd ~/stacks/supabase 2>/dev/null && docker compose down && docker system prune -af || true

# Nettoyer fichiers
cd ~ && rm -rf ~/stacks/supabase setup-week2*.sh 2>/dev/null || true
sudo rm -f /var/log/pi5-setup-week2*.log /tmp/pi5-supabase-phase.state 2>/dev/null || true
```

**🚀 Installation complète avec orchestrateur intelligent :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/scripts/week2/setup-week2.sh -o setup-week2.sh \
&& chmod +x setup-week2.sh \
&& sudo MODE=beginner ./setup-week2.sh
```

**✨ L'orchestrateur détecte automatiquement :**
- **Page size** 16KB → Phase 1 (fix + reboot)
- **Après reboot** → Phase 2 (installation complète)
- **Continuation** intelligente entre phases

### 🎛️ Système orchestrateur intelligent

**🧠 Détection automatique de phase :**

L'orchestrateur analyse automatiquement l'état du système et détermine quelle phase exécuter :

- **Page size 16KB** + **Projet absent** → **Phase 1** (préparation + fix page size)
- **Page size 16KB** + **Projet existant** → **Redémarrage requis** (avec instructions précises)
- **Page size 4KB** + **Projet prêt** → **Phase 2** (installation complète)

**🚀 Utilisation simple - même commande toujours :**
```bash
# Première fois OU après redémarrage - même commande !
sudo MODE=beginner ./setup-week2.sh
```

**🎛️ Options avancées :**
```bash
# Mode pro avec pgAdmin
sudo MODE=pro ./setup-week2.sh

# Mode pro + analytics (gourmand)
sudo MODE=pro ENABLE_ANALYTICS=yes ./setup-week2.sh

# Désactiver pgvector si problèmes ARM64
sudo ENABLE_PGVECTOR=no ./setup-week2.sh
```

**✨ Avantages orchestrateur :**
- **Reprise intelligente** après redémarrage
- **Messages clairs** avec liens directs
- **Gestion erreurs** automatique
- **Continuité parfaite** entre phases

### 🔧 Variables de configuration

| Variable | Défaut | Description |
|----------|---------|-------------|
| `MODE` | `beginner` | `beginner` ou `pro` (+ pgAdmin) |
| `SUPABASE_STACK_DIR` | `stacks/supabase` | Répertoire d'installation |
| `ENABLE_PGVECTOR` | `yes` | Extension vectors (peut échouer ARM64) |
| `ENABLE_VECTOR_SERVICE` | `no` | Service vector (désactivé, instable Pi 5) |
| `ENABLE_ANALYTICS` | `no` | Service analytics (consomme +512MB) |
| `FIX_PAGE_SIZE` | `auto` | Correction page size 16KB→4KB |
| `POSTGRES_PORT` | `5432` | Port PostgreSQL |
| `STUDIO_PORT` | `3000` | Port Supabase Studio |
| `API_PORT` | `8000` | Port API Gateway |

---

## ✅ Phases d'installation automatique

### 📂 PHASE 1 - Préparation & Page Size Fix

**🎯 Exécutée automatiquement si détectée nécessaire**

**Ce que fait la Phase 1 :**
- **Vérification prérequis** : Docker, RAM, espace disque, architecture
- **Correction groupe docker** automatique si nécessaire
- **Fix page size critique** : 16KB → 4KB dans /boot/firmware/cmdline.txt
- **Création arborescence** `~/stacks/supabase` complète
- **Génération secrets** JWT, mots de passe sécurisés

**🔄 Si redémarrage nécessaire :**
```
==================== ⚠️  REDÉMARRAGE OBLIGATOIRE ====================

🔴 Page size configuré mais pas actif
   Page size actuel: 16384 (doit être 4096)
   Configuration ajoutée à /boot/firmware/cmdline.txt

🚀 Actions requises :
   1️⃣  sudo reboot
   2️⃣  ssh pi@pi5.local
   3️⃣  sudo MODE=beginner ./setup-week2.sh

📋 Après redémarrage, le script détectera automatiquement Phase 2
```

### 🚀 PHASE 2 - Installation complète Supabase

**🎯 Exécutée automatiquement après reboot (page size 4KB)**

**Ce que fait la Phase 2 :**
- **Vérification page size** post-reboot (doit être 4KB)
- **Docker Compose ARM64** optimisé Pi 5
- **Images taguées** explicitement ARM64
- **Service vector DÉSACTIVÉ** (évite crash jemalloc)
- **Démarrage services** avec attente initialisation Pi 5
- **Tests connectivité** automatiques complets
- **Scripts utilitaires** backup, santé, maintenance

### 📊 Services déployés

**Services essentiels** (obligatoires) :
- ✅ **db** - PostgreSQL 15 optimisé Pi 5
- ✅ **auth** - GoTrue authentification
- ✅ **rest** - PostgREST API REST
- ✅ **kong** - API Gateway
- ✅ **studio** - Interface web Supabase
- ✅ **meta** - Métadonnées PostgreSQL

**Services avancés** (inclus) :
- ✅ **realtime** - WebSockets/subscriptions
- ✅ **storage** - Gestion fichiers/images
- ✅ **imgproxy** - Traitement images ARM64
- ✅ **edge-functions** - Runtime Deno serverless

**Services optionnels** :
- ⚠️ **analytics** - Logflare (si ENABLE_ANALYTICS=yes)
- ⚠️ **pgadmin** - Interface DB (si MODE=pro)

### ✅ Vérification installation

**Après installation complète automatique :**

```bash
cd ~/stacks/supabase

# État des services
docker compose ps
# Tous les services doivent être "Up"

# Test connectivité API
curl -s http://localhost:8000/rest/v1/ | head -5
# Doit retourner du JSON sans erreur

# Vérification santé complète
./scripts/supabase-health.sh

# Page size vérifié
getconf PAGE_SIZE
# Doit afficher: 4096
```

---

## ✅ Scripts utilitaires créés automatiquement

### 🛠️ Scripts disponibles dans ~/stacks/supabase/scripts/

```bash
cd ~/stacks/supabase

# 🏥 Vérifier santé complète
./scripts/supabase-health.sh

# 💾 Sauvegarder DB + config
./scripts/supabase-backup.sh

# 🔄 Redémarrer proprement
./scripts/supabase-restart.sh

# 🛠️ Maintenance Pi 5 spécifique
./scripts/pi5-maintenance.sh
```

**🔬 Tests fonctionnalités avancées :**

```bash
# Tester pgvector si installé
docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT vector_dims('[1,2,3]'::vector);"

# Tester Edge Function exemple
curl -X POST http://localhost:54321/functions/v1/hello \
  -H "Content-Type: application/json" \
  -d '{"name": "Pi5"}'

# Si analytics activé (mode pro)
curl http://localhost:4000
```

---

## ✅ Accès aux Interfaces

### 🎨 Supabase Studio

**URL** : http://192.168.X.XX:3000

**Première connexion** :
1. Ouvrir Studio dans navigateur
2. **Database URL** : `postgresql://supabase_admin:MOT_DE_PASSE@192.168.X.XX:5432/postgres`
3. Créer première table de test

### 🔧 pgAdmin (Mode Pro)

**URL** : http://192.168.X.XX:8080

**Connexion** :
- Email : `admin@supabase.local`
- Password : (même que PostgreSQL)

### 🔌 API Gateway

**Base URL** : http://192.168.X.XX:8000

**Endpoints principaux** :
- `/rest/v1/` - API REST
- `/auth/v1/` - Authentification
- `/realtime/v1/` - WebSockets
- `/storage/v1/` - Stockage fichiers
- `/functions/v1/` - Edge Functions

---

## ✅ Tests de Validation End-to-End

### 🧪 Test 1 : Base de données

```bash
cd ~/stacks/supabase

# Créer table test
docker compose exec -T db psql -U supabase_admin -d postgres -c "
CREATE TABLE IF NOT EXISTS test_pi5 (
  id SERIAL PRIMARY KEY,
  name TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO test_pi5 (name) VALUES ('Raspberry Pi 5'), ('Supabase ARM64');
SELECT * FROM test_pi5;
"
```

### 🧪 Test 2 : API REST

```bash
# Test GET via API
curl -H "apikey: YOUR_ANON_KEY" http://localhost:8000/rest/v1/test_pi5

# Test POST via API
curl -X POST http://localhost:8000/rest/v1/test_pi5 \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test API Pi5"}'
```

### 🧪 Test 3 : Storage

```bash
# Upload test file
echo "Hello from Pi5" > test_file.txt
curl -X POST http://localhost:8000/storage/v1/object/test/test_file.txt \
  -H "Authorization: Bearer YOUR_SERVICE_KEY" \
  -T test_file.txt
```

---

## ✅ Résultats Attendus

**À la fin de la Semaine 2, vous devez avoir :**

✅ **Stack Supabase complète**
- PostgreSQL 15 optimisé Pi 5
- Studio accessible et fonctionnel
- API REST complètement opérationnelle
- Auth, Realtime, Storage fonctionnels

✅ **Configuration ARM64 stable**
- Aucun crash vector ou jemalloc
- Toutes images ARM64 natives
- Page size 4KB configuré

✅ **Sécurité et maintenance**
- UFW avec règles restrictives
- Scripts backup automatiques
- Monitoring Pi 5 spécifique

✅ **Performances optimisées**
- Mémoire adaptée 16GB
- PostgreSQL paramétré Pi 5
- Services essentiels < 4GB RAM total

---

## 🛠️ Dépannage Pi 5 Spécifique

### **Problème : Page Size Error**

**Erreur** : `<jemalloc>: Unsupported system page size`

**Solution** :
```bash
# Vérifier page size actuel
getconf PAGE_SIZE

# Si 16384, le script corrige automatiquement
sudo reboot  # OBLIGATOIRE après correction

# Re-vérifier après reboot
getconf PAGE_SIZE  # Doit afficher 4096
```

### **Problème : Services ne démarrent pas**

**Diagnostic** :
```bash
cd ~/stacks/supabase
docker compose logs db
docker compose logs kong
```

**Solutions courantes** :
```bash
# Redémarrage propre
./scripts/supabase-restart.sh

# Vérification ressources
docker stats --no-stream

# Nettoyage si espace insuffisant
docker system prune -af
```

### **Problème : API inaccessible**

**Vérifications** :
```bash
# Ports ouverts
sudo netstat -tlnp | grep :8000

# UFW autorisé
sudo ufw status | grep 8000

# Kong fonctionne
curl -I http://localhost:8000
```

### **Problème : Studio inaccessible**

**Solutions** :
```bash
# Redémarrer uniquement studio
docker compose restart studio

# Vérifier logs studio
docker compose logs studio

# Test port direct
curl -I http://localhost:3000
```

### **Problème : RAM insuffisante**

**Monitoring** :
```bash
# Utilisation mémoire temps réel
./scripts/supabase-health.sh

# Identifier service gourmand
docker stats --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

**Optimisations** :
```bash
# Désactiver analytics si activé
sudo MODE=beginner ENABLE_ANALYTICS=no ./setup-week2.sh

# Réduire workers PostgreSQL
# Modifier docker-compose.yml : POSTGRES_MAX_CONNECTIONS=50
```

### **Problème : pgvector échec**

**Diagnostic** :
```bash
docker compose exec -T db psql -U supabase_admin -d postgres -c "\dx"
# Chercher "vector" dans la liste
```

**Solution** :
```bash
# Désactiver pgvector
sudo ENABLE_PGVECTOR=no ./setup-week2.sh

# Alternative: Milvus Lite pour vectors
pip install pymilvus
```

---

## 📊 Surveillance & Maintenance

### 🔍 Monitoring quotidien

**Script santé automatique** :
```bash
# Ajouter à crontab pour monitoring quotidien
echo "0 8 * * * /home/pi/stacks/supabase/scripts/supabase-health.sh" | crontab -
```

**Métriques importantes** :
- CPU < 60% en moyenne
- RAM < 12GB utilisés
- Espace disque > 5GB libre
- Tous services "Up"

### 💾 Backup automatique

**Script backup hebdomadaire** :
```bash
# Backup automatique dimanche 3h
echo "0 3 * * 0 /home/pi/stacks/supabase/scripts/supabase-backup.sh" | crontab -
```

### 🧹 Maintenance mensuelle

**Nettoyage Docker** :
```bash
# Premier dimanche du mois
echo "0 2 1-7 * 0 /home/pi/stacks/supabase/scripts/pi5-maintenance.sh" | crontab -
```

---

## 🚀 Prochaines Étapes

**Semaine 3 : Accès Externe & HTTPS**
- Configuration domaine/DNS
- Reverse proxy Caddy/Nginx
- Certificats SSL automatiques
- Cloudflare Tunnel ou DynDNS

**Extensions Week 2+** :
- Connexion app frontend (React/Vue)
- Webhook intégrations
- Backup cloud (S3/B2)
- Monitoring Grafana/Prometheus

```bash
# Prochaine commande (semaine 3)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week3.sh -o setup-week3.sh && chmod +x setup-week3.sh && sudo ./setup-week3.sh
```

---

## 📚 Documentation Technique

**Architecture déployée** :
```
Internet → UFW → Kong Gateway → Services Internes
                      ↓
          ┌─── auth (GoTrue)
          ├─── rest (PostgREST)
          ├─── realtime (Phoenix)
          ├─── storage (FastAPI)
          ├─── meta (Node.js)
          └─── db (PostgreSQL)
```

**Ressources consommées** (estimation) :
- PostgreSQL: ~1.5GB RAM
- Kong + Services: ~1.5GB RAM
- Studio + Edge: ~1GB RAM
- **Total**: ~4GB / 16GB disponibles

**Fichiers critiques** :
- `~/stacks/supabase/.env` - Secrets (SAUVEGARDER)
- `~/stacks/supabase/docker-compose.yml` - Configuration
- `~/stacks/supabase/volumes/db/data/` - Base données
- `/boot/firmware/cmdline.txt` - Page size fix

Cette configuration Supabase Pi 5 vous donne une plateforme complète pour développer des applications modernes avec authentification, base de données temps réel, stockage et fonctions serverless, le tout hébergé sur votre infrastructure ! 🎯