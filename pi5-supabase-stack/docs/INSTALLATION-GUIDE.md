# 📋 Guide d'Installation Pi 5 Supabase - Pas à Pas

> **Guide complet détaillé pour transformer un Raspberry Pi 5 en serveur Supabase self-hosted**

---

## 🎯 Objectif

Transformer un Raspberry Pi 5 (8GB ou 16GB) en serveur de développement/production avec stack Supabase complet :
- PostgreSQL 15 + extensions
- Auth, REST, Realtime, Storage
- Studio UI & Edge Functions
- Monitoring et outils de diagnostic

---

## ✅ Prérequis

### Matériel

| Composant | Minimum | Recommandé |
|-----------|---------|------------|
| **Raspberry Pi** | Pi 5 (8GB) | Pi 5 (16GB) ⭐ |
| **Storage** | microSD 32GB Class 10 | NVMe SSD 64GB+ via HAT |
| **Alimentation** | USB-C 27W officielle | USB-C 27W officielle |
| **Réseau** | WiFi | Ethernet Gigabit ⭐ |
| **Refroidissement** | Passif | Ventilateur actif ⭐ |

### Système

- ✅ **Raspberry Pi OS 64-bit** (Bookworm 2024+)
- ✅ **Utilisateur** avec privilèges sudo
- ✅ **SSH activé** (recommandé)
- ✅ **IP statique** configurée (recommandé)

### Accès Réseau

- ✅ Connexion Internet stable (download images Docker)
- ✅ Ports disponibles : 3000, 5432, 8000, 8080, 54321

---

## 📥 Étape 1 : Préparation du Système

### 1.1 Vérification Système

```bash
# Version OS (doit être Bookworm 64-bit)
cat /etc/os-release

# Architecture (doit être aarch64)
uname -m

# RAM disponible
free -h

# Page size ACTUEL (sera fixé à 4096)
getconf PAGESIZE

# Espace disque (minimum 30GB libre)
df -h

# IP du Pi
hostname -I
```

**Résultats attendus :**
```
OS: Debian GNU/Linux 12 (bookworm)
Architecture: aarch64
RAM: 15Gi (pour Pi 16GB) ou 7Gi (pour Pi 8GB)
Page Size: 16384 (sera corrigé à 4096)
Disk: >30GB disponible
```

### 1.2 Mise à Jour Système

**⚠️ Toujours faire cette étape avant installation !**

```bash
# Mettre à jour la liste des paquets
sudo apt update

# Mettre à jour tous les paquets installés
sudo apt full-upgrade -y

# Nettoyer les paquets obsolètes
sudo apt autoremove -y
sudo apt autoclean
```

**Durée estimée :** 10-30 minutes selon connexion

**Si kernel mis à jour, redémarrer :**
```bash
sudo reboot
```

### 1.3 Download du Projet

```bash
# Se placer dans le répertoire home
cd ~

# Cloner le repository GitHub
git clone https://github.com/iamaketechnology/pi5-setup.git

# Naviguer vers le stack Supabase
cd pi5-supabase-stack

# Rendre tous les scripts exécutables
chmod +x scripts/*.sh scripts/utils/*.sh
```

**Vérifier le téléchargement :**
```bash
ls -la scripts/
# Doit afficher :
# 01-prerequisites-setup.sh
# 02-supabase-deploy.sh
# utils/...
```

---

## 🔧 Étape 2 : Étape 1 - Fondations Système & Docker

### 2.1 Lancement du Script Étape 1

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/01-prerequisites-setup.sh
```

**Durée estimée :** 15-30 minutes

### 2.2 Ce qui Sera Installé

**Infrastructure :**
- ✅ **Docker Engine** (dernière version)
- ✅ **Docker Compose V2**
- ✅ **Portainer** (port 8080) - Interface web Docker

**Sécurité :**
- ✅ **UFW Firewall** configuré (ports essentiels)
- ✅ **Fail2ban** anti-brute force SSH

**Optimisations Pi 5 :**
- ✅ **Page size fix** 16KB → 4KB (critique pour PostgreSQL)
- ✅ **Memory limits** optimisés pour 16GB RAM
- ✅ **Kernel parameters** tuning

**Outils Monitoring :**
- ✅ htop, iotop, nethogs
- ✅ net-tools, curl, wget
- ✅ Git, vim, nano

### 2.3 Vérifications Post-Étape 1

**Docker :**
```bash
# Version Docker
docker --version

# Test fonctionnel
docker run --rm hello-world

# Docker Compose
docker compose version
```

**Portainer :**
```bash
# Test HTTP
curl -I http://localhost:8080

# Doit retourner : HTTP/1.1 200 OK
```

**Page Size :**
```bash
getconf PAGESIZE

# Doit afficher : 4096
# Si encore 16384, le reboot va corriger
```

**Services Système :**
```bash
# Docker daemon
sudo systemctl status docker

# UFW firewall
sudo ufw status

# Fail2ban
sudo systemctl status fail2ban
```

### 2.4 ⚠️ REDÉMARRAGE OBLIGATOIRE

**Le script Étape 1 modifie `/boot/firmware/cmdline.txt` pour fixer le page size.**

**Ce changement ne prend effet qu'après redémarrage !**

```bash
sudo reboot
```

**Attendre 1-2 minutes, puis se reconnecter :**
```bash
ssh pi@<IP-DU-PI>
```

**Vérifier que le page size est corrigé :**
```bash
getconf PAGESIZE
# DOIT afficher : 4096
```

**❌ Si toujours 16384, ne PAS continuer ! Voir section Dépannage.**

---

## 🗄️ Étape 3 : Étape 2 - Stack Supabase Complet

### 3.1 Lancement du Script Étape 2

**Après le reboot obligatoire :**

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/02-supabase-deploy.sh
```

**Durée estimée :** 8-12 minutes

### 3.2 Ce qui Sera Installé

**Base de Données :**
- ✅ **PostgreSQL 15** ARM64 optimisé (supabase/postgres:15.8.1.060)
- ✅ **Extensions** : pgvector, pgjwt, uuid-ossp, pg_net, pgsodium
- ✅ **Schemas** : auth, storage, realtime, extensions, _realtime

**Services Supabase :**
- ✅ **Auth (GoTrue)** - Authentification JWT
- ✅ **REST (PostgREST)** - API REST automatique
- ✅ **Realtime** - WebSockets et subscriptions
- ✅ **Storage** - Gestion fichiers/images
- ✅ **Studio** - Interface d'administration web
- ✅ **Kong** - API Gateway & routing
- ✅ **Edge Functions** - Runtime Deno serverless
- ✅ **Meta** - Metadata service
- ✅ **ImgProxy** - Optimisation images

**Configuration Automatique :**
- Variables d'environnement unifiées
- Mots de passe PostgreSQL synchronisés (SCRAM-SHA-256)
- Utilisateurs DB : postgres, authenticator, supabase_admin, etc.
- Healthchecks optimisés ARM64 (pas de `nc`, `wget` natif)
- Memory limits adaptées (512MB-1GB par service)
- Network interne Docker (`supabase_network`)

### 3.3 Pendant l'Exécution

Le script affiche :
1. ✅ Vérifications pré-installation
2. 📦 Génération JWT secrets uniques
3. 🔐 Génération mots de passe forts
4. 📝 Création .env et docker-compose.yml
5. 🚀 Lancement services (docker compose up -d)
6. ⏳ Attente initialisation (2-3 min)
7. ✅ Vérification santé services

**À la fin, vous verrez :**
```
🎉 INSTALLATION TERMINÉE !

📊 Accès Services :
   Studio    : http://<IP>:3000
   API       : http://<IP>:8000
   Portainer : http://<IP>:8080

🔑 API Keys :
   anon_key        : eyJ... (pour client-side)
   service_role_key: eyJ... (pour server-side, SECRET!)

💾 Configuration : ~/stacks/supabase/.env
```

**⚠️ SAUVEGARDER CES CLÉS IMMÉDIATEMENT !**

### 3.4 Vérifications Post-Étape 2

**État des Services :**
```bash
cd ~/stacks/supabase
docker compose ps
```

**Résultat attendu :**
```
NAME                STATUS
supabase-db         Up (healthy)
supabase-auth       Up (healthy)
supabase-rest       Up (healthy)
supabase-realtime   Up (healthy)
supabase-storage    Up (healthy)
supabase-studio     Up (healthy)
supabase-kong       Up (healthy)
supabase-functions  Up (healthy)
supabase-meta       Up (healthy)
```

**Tests de Connectivité :**
```bash
# Studio (interface web)
curl -I http://localhost:3000
# → HTTP/1.1 200 OK

# API Gateway
curl http://localhost:8000
# → {"msg":"welcome to kong"}

# Auth endpoint
curl http://localhost:8000/auth/v1/health
# → {"date":"...","description":"GoTrue is a user..."}

# REST API
curl http://localhost:8000/rest/v1/
# → {"paths":[...]}

# Realtime
curl http://localhost:4000/api/health
# → {"status":"ok"}
```

**PostgreSQL :**
```bash
# Connexion psql
cd ~/stacks/supabase
docker compose exec db psql -U postgres

# Dans psql :
SELECT version();
SHOW block_size;  -- Doit être 8192
\dx                -- Lister extensions
\dn                -- Lister schémas
\q                 -- Quitter
```

---

## 🎉 Étape 4 : Accès aux Services

### 4.1 URLs d'Accès

**Remplacer `<IP-PI5>` par l'IP de votre Raspberry Pi :**

```bash
# Obtenir l'IP
hostname -I | awk '{print $1}'
```

**Services Accessibles :**

| Service | URL | Description |
|---------|-----|-------------|
| **Supabase Studio** | `http://<IP-PI5>:3000` | Interface d'administration complète |
| **API Gateway** | `http://<IP-PI5>:8000` | Point d'entrée REST/Auth/Realtime |
| **Portainer** | `http://<IP-PI5>:8080` | Gestion Docker (UI web) |
| **PostgreSQL** | `<IP-PI5>:5432` | Connexion directe DB |

### 4.2 Première Connexion Studio

1. **Ouvrir** `http://<IP-PI5>:3000` dans votre navigateur

2. **Aucun login** nécessaire (self-hosted, pas de cloud)

3. **Explorer l'interface :**
   - Table Editor : Gérer tables
   - SQL Editor : Exécuter SQL
   - Auth : Gérer utilisateurs
   - Storage : Fichiers
   - Database : Schemas, extensions, etc.

### 4.3 Configuration Client Supabase

**JavaScript/TypeScript :**
```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://<IP-PI5>:8000'
const supabaseAnonKey = 'eyJ...'  // Anon key de l'installation

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Python :**
```python
from supabase import create_client, Client

url: str = "http://<IP-PI5>:8000"
key: str = "eyJ..."  # Anon key

supabase: Client = create_client(url, key)
```

---

## 🔑 Étape 5 : Récupérer les API Keys

### 5.1 Si Clés Perdues

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/utils/get-supabase-info.sh
```

**Affiche :**
- URLs d'accès
- Anon key (client-side, public OK)
- Service role key (server-side, **garder secret !**)
- JWT secret (ne jamais partager)

### 5.2 Stockage Sécurisé

**Les clés sont dans :**
```bash
~/stacks/supabase/.env
```

**Backup recommandé :**
```bash
# Backup .env (contient tous les secrets)
cp ~/stacks/supabase/.env ~/backups/.env.supabase.$(date +%Y%m%d)

# Permissions restrictives
chmod 600 ~/backups/.env.supabase.*
```

---

## 🆘 Étape 6 : Dépannage

### 6.1 Page Size Toujours 16384 Après Reboot

**Vérifier :**
```bash
getconf PAGESIZE
```

**Si toujours 16384 :**

```bash
# 1. Vérifier cmdline.txt
cat /boot/firmware/cmdline.txt

# Doit contenir "pagesize=4k" au début
# Exemple : pagesize=4k console=serial0,115200 ...

# 2. Si absent, ajouter manuellement :
sudo nano /boot/firmware/cmdline.txt

# Ajouter "pagesize=4k" au DÉBUT de la ligne
# Sauvegarder : Ctrl+O, Enter, Ctrl+X

# 3. Redémarrer à nouveau
sudo reboot

# 4. Vérifier après reboot
getconf PAGESIZE  # DOIT être 4096
```

### 6.2 Services en Restart Loop

**Diagnostic :**
```bash
cd ~/stacks/supabase
docker compose ps
docker compose logs -f
```

**Causes fréquentes :**

**Auth en restart :**
```bash
# Logs Auth
docker compose logs auth --tail=50

# Si erreur "uuid = text operator"
# → Extension uuid-ossp manquante (normalement installée par script)
docker compose exec db psql -U postgres -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
docker compose restart auth
```

**Realtime en restart :**
```bash
# Logs Realtime
docker compose logs realtime --tail=50

# Si "crypto_one_time bad key"
# → Variables encryption manquantes
# Vérifier .env contient :
# VAULT_ENC_KEY, VAULT_KEYRING_PRIVATE_KEY, VAULT_KEYRING_PUBLIC_KEY
```

**PostgreSQL ne démarre pas :**
```bash
# Logs DB
docker compose logs db --tail=50

# Si "page size mismatch"
# → Page size encore 16KB, voir section 6.1

# Si "data directory not empty"
# → Reset volume (PERTE DONNÉES)
docker compose down
sudo rm -rf ~/stacks/supabase/volumes/db/data
docker compose up -d
```

### 6.3 Diagnostic Automatique

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/utils/diagnostic-supabase-complet.sh
```

Affiche :
- ✅ Status système (page size, RAM, disk)
- ✅ Status Docker daemon
- ✅ Status tous services Supabase
- ✅ Logs récents si erreurs
- ✅ Recommandations fixes

### 6.4 Nettoyage (Conserve Données)

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/utils/clean-supabase-complete.sh
```

Nettoie :
- Containers arrêtés
- Images inutilisées
- Networks orphelins
- **Volumes préservés** (données OK)

### 6.5 Reset Complet (⚠️ DESTRUCTIF)

**⚠️ ATTENTION : Supprime TOUTES les données !**

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/utils/pi5-complete-reset.sh
```

Supprime :
- Tous containers
- Toutes images
- Tous volumes (DATA LOSS)
- Tous networks
- Configuration

**Après reset, réinstaller :**
```bash
sudo ./scripts/01-prerequisites-setup.sh
sudo reboot
sudo ./scripts/02-supabase-deploy.sh
```

---

## ✅ Étape 7 : Validation Finale

### 7.1 Checklist Complète

- [ ] ✅ Page size = 4096 bytes (`getconf PAGESIZE`)
- [ ] ✅ Docker fonctionne (`docker ps`)
- [ ] ✅ Portainer accessible (`http://<IP>:8080`)
- [ ] ✅ Supabase Studio accessible (`http://<IP>:3000`)
- [ ] ✅ API Gateway répond (`http://<IP>:8000`)
- [ ] ✅ PostgreSQL connecté (`docker compose exec db psql -U postgres`)
- [ ] ✅ Tous services Docker "healthy" (`docker compose ps`)
- [ ] ✅ API Keys sauvegardées (anon + service_role)
- [ ] ✅ Backup .env effectué

### 7.2 Script de Validation

```bash
cd ~/pi5-supabase-stack
sudo ./scripts/utils/diagnostic-supabase-complet.sh > ~/validation.txt
cat ~/validation.txt
```

**Résultat attendu :**
```
✅ Page Size: 4096 bytes
✅ Docker: Running
✅ All Supabase services: Healthy (9/9)
✅ Studio accessible
✅ API Gateway accessible
```

---

## 🚀 Étape 8 : Prochaines Étapes

### 8.1 Configuration Première Application

1. **Créer une table dans Studio**
   - Ouvrir Table Editor
   - Create new table
   - Ajouter colonnes

2. **Activer Row Level Security (RLS)**
   - Enable RLS sur table
   - Créer policies

3. **Tester Auth**
   - Créer utilisateur test
   - Tester login/signup

### 8.2 Sécurisation Production

- [ ] Changer les secrets par défaut
- [ ] Configurer SSL/TLS (reverse proxy)
- [ ] Limiter accès réseau (UFW rules spécifiques)
- [ ] Setup backups automatiques

**Guide complet :** [docs/05-CONFIGURATION/Security-Hardening.md](05-CONFIGURATION/)

### 8.3 Backups Automatiques

```bash
# Créer script backup quotidien
cat > ~/backup-supabase.sh <<'EOF'
#!/bin/bash
BACKUP_DIR=~/backups/supabase
mkdir -p $BACKUP_DIR
cd ~/stacks/supabase
docker compose exec -T db pg_dump -U postgres postgres | gzip > $BACKUP_DIR/db-$(date +%Y%m%d).sql.gz
# Garder 7 derniers jours
ls -t $BACKUP_DIR/db-*.sql.gz | tail -n +8 | xargs rm -f
EOF

chmod +x ~/backup-supabase.sh

# Ajouter cron (backup 3h du matin)
echo "0 3 * * * ~/backup-supabase.sh" | crontab -
```

**Guide complet :** [docs/06-MAINTENANCE/Backup-Strategies.md](06-MAINTENANCE/)

### 8.4 Monitoring Continu

```bash
# Température CPU
vcgencmd measure_temp

# RAM usage
free -h

# Docker stats
docker stats --no-stream

# Services status
cd ~/stacks/supabase && docker compose ps
```

---

## 📚 Documentation Complémentaire

### Guides Détaillés

- [README Principal](../README.md) - Vue d'ensemble projet
- [Quick Start](01-GETTING-STARTED/01-Quick-Start.md) - Installation rapide
- [Commands Reference](../commands/All-Commands-Reference.md) - Toutes les commandes

### Troubleshooting

- [Known Issues Pi 5](03-PI5-SPECIFIC/Known-Issues-2025.md) - Issues ARM64 spécifiques
- [Auth Issues](04-TROUBLESHOOTING/) - Problèmes Auth/GoTrue
- [Realtime Issues](04-TROUBLESHOOTING/) - Problèmes Realtime
- [Database Issues](04-TROUBLESHOOTING/) - Problèmes PostgreSQL

### Configuration Avancée

- [Environment Variables](05-CONFIGURATION/) - Variables .env expliquées
- [Docker Compose](05-CONFIGURATION/) - Anatomie docker-compose.yml
- [Performance Tuning](05-CONFIGURATION/) - Optimisations Pi 5

---

## 📞 Support

### En Cas de Problème

1. **Consulter documentation**
   - [Troubleshooting](04-TROUBLESHOOTING/)
   - [Known Issues](03-PI5-SPECIFIC/Known-Issues-2025.md)

2. **Lancer diagnostic**
   ```bash
   sudo ./scripts/utils/diagnostic-supabase-complet.sh > diagnostic.txt
   ```

3. **Ouvrir GitHub Issue**
   - Inclure `diagnostic.txt`
   - Inclure logs (`docker compose logs`)
   - Préciser étape qui a échoué

### Ressources Externes

- [Supabase Docs](https://supabase.com/docs)
- [Supabase Self-Hosting](https://supabase.com/docs/guides/self-hosting)
- [Raspberry Pi Forums](https://forums.raspberrypi.com)

---

<p align="center">
  <strong>🎯 Installation Complète Réussie ! 🎯</strong>
</p>

<p align="center">
  <sub>Votre stack Supabase est prête pour le développement et la production</sub>
</p>

<p align="center">
  <sub>⭐ Pensez à sauvegarder vos clés API et configurer les backups ! ⭐</sub>
</p>
