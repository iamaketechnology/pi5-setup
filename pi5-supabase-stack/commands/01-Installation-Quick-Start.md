# 🚀 Installation Rapide - Pi 5 Supabase Stack

> **Guide d'installation rapide avec commandes copy-paste**

---

## 📋 Prérequis

- ✅ Raspberry Pi 5 (8GB ou 16GB RAM)
- ✅ Raspberry Pi OS 64-bit (Bookworm) installé
- ✅ **Page size = 4096** (voir [00-Initial-Raspberry-Pi-Setup.md](00-Initial-Raspberry-Pi-Setup.md))
- ✅ Connexion Internet stable
- ✅ Accès SSH configuré

---

## 🎯 Installation en 3 Étapes

### Étape 1 : Cloner le Repository

```bash
# Se placer dans le répertoire home
cd ~

# Cloner le repository
git clone https://github.com/iamaketechnology/pi5-setup.git

# Naviguer vers le stack Supabase
cd pi5-setup/pi5-supabase-stack

# Rendre les scripts exécutables
chmod +x scripts/*.sh scripts/utils/*.sh
```

---

### Étape 2 : Étape 1 - Docker & Système

**Ce script installe :**
- Docker + Docker Compose
- Portainer (interface web Docker)
- Sécurité (UFW, Fail2ban)
- Optimisations Pi 5

```bash
# Exécuter le script Étape 1
sudo ./scripts/01-prerequisites-setup.sh
```

**Durée estimée :** 15-30 minutes

**⚠️ IMPORTANT : Redémarrage obligatoire après Étape 1**

```bash
# Redémarrer le Pi
sudo reboot
```

**Attendre 1-2 minutes, puis se reconnecter :**

```bash
ssh pi@<IP-DU-PI>
cd ~/pi5-setup/pi5-supabase-stack
```

---

### Étape 3 : Étape 2 - Stack Supabase

**Ce script déploie :**
- PostgreSQL 15 + extensions
- Auth (GoTrue)
- REST API (PostgREST)
- Realtime
- Storage
- Studio UI
- Kong API Gateway
- Edge Functions

```bash
# Exécuter le script Étape 2
sudo ./scripts/02-supabase-deploy.sh
```

**Durée estimée :** 8-12 minutes

**À la fin du script, vous verrez :**
- ✅ URLs d'accès (Studio, API)
- 🔑 API Keys (anon, service_role)
- 📊 Status des services

---

## 🔗 Accès aux Services

Après installation réussie :

### Supabase Studio
```
http://<IP-DU-PI>:3000
```
Interface d'administration complète

### API Gateway (Kong)
```
http://<IP-DU-PI>:8000
```
Point d'entrée API REST/Auth/Realtime

### Portainer
```
http://<IP-DU-PI>:8080
```
Gestion Docker en interface web

### PostgreSQL
```
Host: <IP-DU-PI>
Port: 5432
User: postgres
Password: [voir sortie du script]
Database: postgres
```

---

## ✅ Vérifications Post-Installation

### 1. Vérifier Page Size (Critique)

```bash
getconf PAGESIZE
# Doit afficher : 4096
```

### 2. Vérifier Docker

```bash
# Version Docker
docker --version

# Docker Compose version
docker compose version

# Containers actifs
docker ps
```

### 3. Vérifier Services Supabase

```bash
# Aller dans le répertoire Supabase
cd ~/stacks/supabase

# Voir statut de tous les services
docker compose ps

# Tous les services doivent être "healthy"
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
```

### 4. Tester Connectivité

```bash
# Tester Studio
curl -I http://localhost:3000

# Tester API Gateway
curl http://localhost:8000

# Tester Auth
curl http://localhost:8000/auth/v1/health

# Tester Realtime
curl http://localhost:4000/api/health
```

---

## 🔑 Récupérer les API Keys

Si vous avez perdu les clés affichées à la fin de l'installation :

```bash
# Utiliser le script utilitaire
cd ~/pi5-setup/pi5-supabase-stack
sudo ./scripts/utils/get-supabase-info.sh
```

Cela affichera :
- URLs d'accès
- Anon key (client-side)
- Service role key (server-side, à garder secret!)
- JWT secret

---

## 🛠️ Scripts Utilitaires

### Diagnostic Complet

```bash
cd ~/pi5-setup/pi5-supabase-stack
sudo ./scripts/utils/diagnostic-supabase-complet.sh
```

Affiche :
- Status système (page size, RAM, disk)
- Status Docker
- Status tous les services Supabase
- Logs récents si erreurs

### Nettoyage (conserve les données)

```bash
cd ~/pi5-setup/pi5-supabase-stack
sudo ./scripts/utils/clean-supabase-complete.sh
```

Nettoie :
- Containers arrêtés
- Images inutilisées
- Réseaux orphelins
- **Conserve les volumes/données**

### Reset Complet (⚠️ DESTRUCTIF)

```bash
cd ~/pi5-setup/pi5-supabase-stack
sudo ./scripts/utils/pi5-complete-reset.sh
```

**⚠️ ATTENTION :** Supprime TOUT
- Containers
- Images
- Volumes (DONNÉES PERDUES)
- Réseaux
- Configuration

---

## 🔗 Liens GitHub Directs

### 📜 Scripts d'Installation

**Étape 1 - Système & Docker :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/01-prerequisites-setup.sh
```

**Étape 2 - Stack Supabase :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/02-supabase-deploy.sh
```

### 📚 Documentation

**README Principal :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/README.md
```

**Base de Connaissances :**
```
https://github.com/iamaketechnology/pi5-setup/tree/main/pi5-supabase-stack/docs
```

**Commandes Terminal :**
```
https://github.com/iamaketechnology/pi5-setup/tree/main/pi5-supabase-stack/commands
```

### 🛠️ Scripts Utilitaires

**Diagnostic :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/utils/diagnostic-supabase-complet.sh
```

**Get Supabase Info :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/utils/get-supabase-info.sh
```

**Clean :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/utils/clean-supabase-complete.sh
```

**Reset Complet :**
```
https://github.com/iamaketechnology/pi5-setup/blob/main/pi5-supabase-stack/scripts/utils/pi5-complete-reset.sh
```

---

## 🆘 Installation sans Git

Si problème avec `git clone`, téléchargement direct :

### Étape 1 Script

```bash
# Télécharger Étape 1
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/01-prerequisites-setup.sh

# Rendre exécutable
chmod +x 01-prerequisites-setup.sh

# Exécuter
sudo ./01-prerequisites-setup.sh

# Redémarrer
sudo reboot
```

### Étape 2 Script

```bash
# Télécharger Étape 2
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/02-supabase-deploy.sh

# Rendre exécutable
chmod +x 02-supabase-deploy.sh

# Exécuter
sudo ./02-supabase-deploy.sh
```

---

## 🐛 Problèmes Courants

### 1. Page Size 16KB (DB ne démarre pas)

**Erreur :**
```
PostgreSQL detected page size 16384
```

**Solution :**
```bash
# Vérifier
getconf PAGESIZE

# Si 16384, éditer :
sudo nano /boot/firmware/cmdline.txt

# Ajouter au début :
pagesize=4k

# Sauvegarder et redémarrer
sudo reboot

# Vérifier après reboot
getconf PAGESIZE  # Doit être 4096
```

### 2. Services Unhealthy

**Diagnostic :**
```bash
cd ~/stacks/supabase
docker compose ps
docker compose logs -f
```

**Solution :** Attendre 2-3 minutes (initialisation)

**Si toujours unhealthy après 5min :**
```bash
# Redémarrer proprement
docker compose down
sleep 10
docker compose up -d

# Vérifier logs
docker compose logs -f
```

### 3. Permission Denied Docker

**Erreur :**
```
permission denied while trying to connect to the Docker daemon
```

**Solution :**
```bash
# Ajouter user au groupe docker
sudo usermod -aG docker $USER

# Appliquer
newgrp docker

# Ou logout/login
```

### 4. Port Déjà Utilisé

**Erreur :**
```
port is already allocated
```

**Solution :**
```bash
# Voir processus utilisant port 3000 (exemple)
sudo lsof -i :3000

# Tuer processus
sudo fuser -k 3000/tcp

# Redémarrer services
docker compose up -d
```

---

## 📊 Monitoring Post-Installation

### Vérifier Ressources

```bash
# RAM usage
free -h

# Disk usage
df -h

# CPU temperature (Pi 5)
vcgencmd measure_temp

# Docker stats temps réel
docker stats
```

### Logs en Temps Réel

```bash
cd ~/stacks/supabase

# Tous les services
docker compose logs -f

# Service spécifique
docker compose logs -f supabase-auth
docker compose logs -f supabase-db
```

---

## 🎓 Prochaines Étapes

Après installation réussie :

1. **Sécuriser votre installation**
   - Changer mots de passe par défaut
   - Configurer UFW pour ports externes
   - Setup certificats SSL si exposition internet

2. **Configurer les backups**
   - [Backup Strategies](../docs/06-MAINTENANCE/)

3. **Tester votre stack**
   - Créer un projet test dans Studio
   - Tester Auth (signup/login)
   - Tester Realtime (subscriptions)

4. **Apprendre Supabase**
   - [Supabase Docs](https://supabase.com/docs)
   - [JavaScript Client](https://supabase.com/docs/reference/javascript)
   - [REST API](https://supabase.com/docs/guides/api)

---

## 📞 Besoin d'Aide ?

1. **Vérifier la documentation**
   - [README Principal](../README.md)
   - [Troubleshooting](../docs/04-TROUBLESHOOTING/)
   - [Known Issues](../docs/03-PI5-SPECIFIC/Known-Issues-2025.md)

2. **Lancer diagnostic**
   ```bash
   sudo ./scripts/utils/diagnostic-supabase-complet.sh > diagnostic.txt
   ```

3. **Ouvrir une issue GitHub**
   - Inclure sortie du diagnostic
   - Inclure logs (`docker compose logs`)
   - Préciser étape qui a échoué

---

<p align="center">
  <strong>🎉 Votre Stack Supabase est Prête ! 🎉</strong>
</p>

<p align="center">
  <sub>Installation complète en ~45min - Prêt pour production</sub>
</p>
