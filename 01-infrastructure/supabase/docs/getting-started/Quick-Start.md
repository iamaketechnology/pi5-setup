# 🚀 Guide de Démarrage Rapide - Supabase sur Raspberry Pi 5

> **Installation complète en 30 minutes avec commandes copy-paste**

---

## ⚡ TL;DR - Installation Rapide

```bash
# ÉTAPE 1 : Week 1 (Docker + Base)
sudo ./scripts/01-prerequisites-setup.sh

# ÉTAPE 2 : Redémarrage OBLIGATOIRE
sudo reboot

# ÉTAPE 3 : Week 2 (Supabase Stack)
sudo ./scripts/02-supabase-deploy.sh

# ÉTAPE 4 : Vérification
docker compose ps
curl http://localhost:3000  # Studio
```

**Temps total : ~30 minutes** (15min script + 5min reboot + 10min installation)

---

## 📋 Prérequis (5 min)

### Vérifications Système

```bash
# 1. Version OS (doit être 64-bit)
cat /etc/os-release
# Attendu: Raspberry Pi OS (64-bit) ou Debian Bookworm

# 2. RAM disponible (16GB recommandé)
free -h
# Attendu: Mem total ≥ 16GB

# 3. Espace disque (minimum 20GB libres)
df -h
# Attendu: Avail ≥ 20G sur /

# 4. Architecture (doit être ARM64)
uname -m
# Attendu: aarch64
```

### Si Prérequis Manquants

❌ **OS 32-bit** → Réinstaller Raspberry Pi OS 64-bit
❌ **RAM < 8GB** → Installation possible mais limitée
❌ **Espace < 20GB** → Libérer de l'espace ou utiliser disque externe
❌ **Architecture != aarch64** → Mauvais OS installé

📖 **Guide détaillé** : [00-Prerequisites.md](00-Prerequisites.md)

---

## 🔧 Installation Week 1 - Docker & Base (15 min)

### Téléchargement du Projet

```bash
# Se placer dans le répertoire home
cd ~

# Cloner le projet (ou télécharger depuis GitHub)
git clone https://github.com/VOTRE-REPO/pi5-setup-clean.git
cd pi5-setup-clean

# Rendre scripts exécutables
chmod +x scripts/*.sh utils/**/*.sh
```

### Lancement Week 1

```bash
# Exécuter le script Week 1
sudo ./scripts/01-prerequisites-setup.sh
```

### Ce que fait le script Week 1

✅ Installe **Docker + Docker Compose**
✅ Configure **Portainer** (interface web Docker)
✅ Active **UFW Firewall** avec règles sécurisées
✅ Installe **Fail2ban** (protection brute-force)
✅ **Corrige page size 16KB → 4KB** (critique Pi 5!)
✅ Optimise mémoire pour Pi 5 (16GB)
✅ Installe outils monitoring (htop, iotop, etc.)

### Durée d'Exécution

- Installation packages : **~5-7 minutes**
- Configuration système : **~2-3 minutes**
- Tests & validations : **~2 minutes**

**Total Week 1 : ~15 minutes**

### Validation Week 1

```bash
# Docker installé et fonctionnel
docker --version
# Attendu: Docker version 27.x+

docker compose version
# Attendu: Docker Compose version v2.x+

# Docker fonctionne sans sudo
docker run --rm hello-world
# Attendu: "Hello from Docker!"

# Portainer accessible
curl -I http://localhost:8080
# Attendu: HTTP/1.1 200 OK

# Page size corrigé (CRITIQUE)
getconf PAGESIZE
# Attendu: 4096 (si 16384, reboot nécessaire)
```

---

## 🔄 Redémarrage OBLIGATOIRE (1 min)

⚠️ **Le redémarrage est OBLIGATOIRE pour activer le fix page size**

```bash
# Redémarrer le Raspberry Pi
sudo reboot
```

### Après Redémarrage

```bash
# Se reconnecter en SSH
ssh pi@pi5.local
# ou
ssh pi@IP-DU-PI

# Vérifier que page size est maintenant 4096
getconf PAGESIZE
# DOIT afficher: 4096

# Si affiche encore 16384, vérifier config
cat /boot/firmware/cmdline.txt
# Doit contenir: pagesize=4k
```

---

## 🗄️ Installation Week 2 - Supabase Stack (10 min)

### Lancement Week 2

```bash
# Retourner dans le répertoire du projet
cd ~/pi5-setup-clean

# Exécuter le script Week 2
sudo ./scripts/02-supabase-deploy.sh
```

### Ce que fait le script Week 2

✅ Crée répertoire `/home/pi/stacks/supabase`
✅ Génère **secrets JWT** et mots de passe sécurisés
✅ Configure **docker-compose.yml** optimisé ARM64
✅ Télécharge **images Docker** compatibles ARM64
✅ Applique **correctifs Auth/Realtime** automatiquement
✅ Crée **utilisateurs PostgreSQL** requis
✅ Démarre **stack Supabase complet**
✅ Génère **scripts utilitaires** (backup, santé, etc.)

### Services Installés

| Service | Port | Description |
|---------|------|-------------|
| **Studio** | 3000 | Interface web Supabase |
| **API Gateway (Kong)** | 8000 | API publique |
| **PostgreSQL** | 5432 | Base de données |
| **Auth (GoTrue)** | - | Authentification |
| **REST (PostgREST)** | - | API REST automatique |
| **Realtime** | - | WebSockets/subscriptions |
| **Storage** | - | Stockage fichiers |
| **Edge Functions** | 54321 | Runtime Deno |

### Durée d'Exécution

- Génération configuration : **~1 minute**
- Téléchargement images Docker : **~5-7 minutes** (varie selon connexion)
- Démarrage services : **~2-3 minutes**

**Total Week 2 : ~10 minutes**

### Validation Week 2

```bash
# Aller dans le répertoire Supabase
cd ~/stacks/supabase

# Vérifier que tous les services sont UP
docker compose ps
# Tous doivent afficher "Up" ou "Up (healthy)"

# Tester l'API Gateway
curl -I http://localhost:8000
# Attendu: HTTP/1.1 200 OK

# Tester Studio
curl -I http://localhost:3000
# Attendu: HTTP/1.1 200 OK

# Tester Edge Functions
curl -I http://localhost:54321
# Attendu: HTTP/1.1 404 (normal si aucune fonction déployée)

# Tester PostgreSQL
docker compose exec db psql -U postgres -c "SELECT version();"
# Attendu: PostgreSQL 15.x

# Vérifier santé complète
./scripts/supabase-health.sh
```

---

## 🎉 Accès aux Services

### Obtenir l'IP du Raspberry Pi

```bash
# Méthode 1
hostname -I | awk '{print $1}'

# Méthode 2
ip addr show | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | cut -d/ -f1
```

### URLs d'Accès

Remplacer `IP-PI5` par l'IP obtenue ci-dessus :

```
📊 Supabase Studio    : http://IP-PI5:3000
🔌 API Gateway        : http://IP-PI5:8000
⚡ Edge Functions     : http://IP-PI5:54321
🐳 Portainer          : http://IP-PI5:8080
```

### Première Connexion Studio

1. Ouvrir navigateur → `http://IP-PI5:3000`
2. Cliquer **"Start a new project"**
3. Remplir :
   - **Project name** : pi5-supabase
   - **Database URL** : `postgresql://supabase_admin:VOTRE_PASSWORD@IP-PI5:5432/postgres`
4. Password → voir fichier `.env` :

```bash
# Récupérer le mot de passe PostgreSQL
cd ~/stacks/supabase
cat .env | grep POSTGRES_PASSWORD
```

### Récupérer les Clés API

```bash
cd ~/stacks/supabase

# Clé publique (ANON_KEY) - pour clients frontend
cat .env | grep ANON_KEY

# Clé service (SERVICE_ROLE_KEY) - pour backend/admin
cat .env | grep SERVICE_ROLE_KEY

# Secret JWT
cat .env | grep JWT_SECRET
```

---

## ✅ Checklist Post-Installation

### Système

- [ ] Page size = 4096 bytes (`getconf PAGESIZE`)
- [ ] Docker fonctionne sans sudo
- [ ] Portainer accessible (http://IP:8080)
- [ ] Firewall UFW actif (`sudo ufw status`)

### Services Supabase

- [ ] Studio accessible (http://IP:3000)
- [ ] API Gateway répond (http://IP:8000)
- [ ] PostgreSQL connecté
- [ ] Tous conteneurs "healthy" (`docker compose ps`)

### Validation Complète

```bash
cd ~/stacks/supabase

# Script de validation santé
./scripts/supabase-health.sh

# Si tout est vert, installation réussie ! 🎉
```

---

## 🆘 Problèmes Courants

### ❌ Page size encore 16384 après reboot

```bash
# Vérifier configuration boot
cat /boot/firmware/cmdline.txt | grep pagesize

# Si absent, ajouter manuellement
sudo nano /boot/firmware/cmdline.txt
# Ajouter à la fin: pagesize=4k

# Redémarrer
sudo reboot
```

### ❌ Services en restart loop

```bash
cd ~/stacks/supabase

# Voir les logs du service problématique
docker compose logs auth --tail=50
docker compose logs realtime --tail=50

# Redémarrer proprement
docker compose down
docker compose up -d
```

### ❌ "password authentication failed"

```bash
cd ~/stacks/supabase

# Reset volume database
docker compose down
sudo rm -rf volumes/db/data

# Redémarrer (recrée la DB avec bons mots de passe)
docker compose up -d
```

### ❌ API Gateway retourne 502 Bad Gateway

```bash
# Attendre que tous les services soient healthy
docker compose ps

# Kong démarre parfois avant les autres services
# Redémarrer uniquement Kong
docker compose restart kong

# Attendre 30s et retester
sleep 30
curl http://localhost:8000
```

📖 **Dépannage complet** : [../04-TROUBLESHOOTING/Quick-Fixes.md](../04-TROUBLESHOOTING/Quick-Fixes.md)

---

## 📊 Ressources Système Attendues

Après installation complète, utilisation typique :

```
CPU  : 5-15% idle, pics à 40% lors des requêtes
RAM  : ~4GB / 16GB utilisés (25%)
Disk : ~8GB utilisés pour images + volumes
Swap : 0-100MB (peu utilisé si 16GB RAM)
```

Vérifier :

```bash
# Utilisation mémoire par conteneur
docker stats --no-stream

# Espace disque
df -h

# Charge système
htop
```

---

## 🚀 Prochaines Étapes

### Après Installation Réussie

1. **Créer première table de test**
   ```bash
   cd ~/stacks/supabase
   docker compose exec db psql -U postgres -c "
   CREATE TABLE test (
     id SERIAL PRIMARY KEY,
     name TEXT,
     created_at TIMESTAMP DEFAULT NOW()
   );
   INSERT INTO test (name) VALUES ('Hello Pi5!');
   SELECT * FROM test;"
   ```

2. **Tester API REST**
   ```bash
   # Récupérer ANON_KEY
   ANON_KEY=$(cat ~/stacks/supabase/.env | grep ANON_KEY | cut -d'=' -f2)

   # Requête API
   curl http://localhost:8000/rest/v1/test \
     -H "apikey: $ANON_KEY"
   ```

3. **Configurer Backup Automatique**
   ```bash
   # Backup hebdomadaire (dimanche 3h)
   echo "0 3 * * 0 /home/pi/stacks/supabase/scripts/supabase-backup.sh" | crontab -
   ```

4. **Sécuriser pour Production**
   📖 Lire : [../05-CONFIGURATION/Security-Hardening.md](../05-CONFIGURATION/Security-Hardening.md)

---

## 📚 Documentation Complémentaire

- **Architecture détaillée** : [02-Architecture-Overview.md](02-Architecture-Overview.md)
- **Variables environnement** : [../05-CONFIGURATION/Environment-Variables.md](../05-CONFIGURATION/Environment-Variables.md)
- **Optimisations Pi 5** : [../03-PI5-SPECIFIC/Memory-Optimization.md](../03-PI5-SPECIFIC/Memory-Optimization.md)
- **Backup & Maintenance** : [../06-MAINTENANCE/](../06-MAINTENANCE/)

---

## 💡 Astuces Productivité

### Alias Utiles

Ajouter à `~/.bashrc` :

```bash
# Alias Supabase
alias sup-status='cd ~/stacks/supabase && docker compose ps'
alias sup-logs='cd ~/stacks/supabase && docker compose logs -f'
alias sup-health='cd ~/stacks/supabase && ./scripts/supabase-health.sh'
alias sup-restart='cd ~/stacks/supabase && docker compose restart'
alias sup-backup='cd ~/stacks/supabase && ./scripts/supabase-backup.sh'
```

Recharger :

```bash
source ~/.bashrc
```

Utiliser :

```bash
sup-status   # Voir statut services
sup-health   # Vérifier santé
sup-backup   # Lancer backup manuel
```

---

## 🎯 Résumé Temps d'Installation

| Étape | Durée | Cumulé |
|-------|-------|--------|
| Vérifications prérequis | 5min | 5min |
| Week 1 - Docker & Base | 15min | 20min |
| Redémarrage | 1min | 21min |
| Week 2 - Supabase Stack | 10min | 31min |
| Validation finale | 4min | 35min |

**Total : ~35 minutes** pour installation complète automatisée ! 🎉

---

<p align="center">
  <strong>✅ Installation terminée ! Votre Supabase Pi 5 est prêt ! ✅</strong>
</p>

<p align="center">
  <a href="../README.md">← Retour Index</a> •
  <a href="02-Architecture-Overview.md">Architecture →</a>
</p>
