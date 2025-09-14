# 📋 Référence des Commandes Pi 5 - Guide Complet

Ce document liste **toutes les commandes** nécessaires pour configurer votre Raspberry Pi 5 depuis l'installation jusqu'au projet opérationnel.

---

## 📚 Index par Étapes

- [🔧 Configuration Initiale Pi 5](#-configuration-initiale-pi-5)
- [📦 Week 1 - Base Docker](#-week-1---base-docker)
- [🗄️ Week 2 - Supabase](#️-week-2---supabase)
- [🌐 Week 3 - HTTPS & Accès Externe](#-week-3---https--accès-externe)
- [👥 Week 4 - Développement Collaboratif](#-week-4---développement-collaboratif)
- [☁️ Week 5 - Cloud Personnel](#️-week-5---cloud-personnel)
- [📺 Week 6 - Multimédia & IoT](#-week-6---multimédia--iot)
- [🛠️ Maintenance & Diagnostic](#️-maintenance--diagnostic)

---

## 🔧 Configuration Initiale Pi 5

### 📥 Préparation SD Card

```bash
# Télécharger Raspberry Pi Imager
# https://www.raspberrypi.com/software/

# Flasher Raspberry Pi OS Lite 64-bit sur SD
# Configurer SSH, Wi-Fi, utilisateur via Imager
```

**Status** : ⏳ À valider

### 🌐 Première Connexion SSH

```bash
# Trouver l'IP du Pi
ping pi5.local
# ou
nmap -sn 192.168.1.0/24

# Première connexion
ssh pi@pi5.local
# Mot de passe : testadmin

# Mettre à jour le système
sudo apt update && sudo apt upgrade -y
sudo reboot
```
**Status** : ⏳ À valider

### ⚙️ Configuration de Base
```bash
# Vérifier l'architecture (doit être aarch64)
uname -m

# Vérifier la RAM (doit être 16GB)
free -h

# Vérifier l'espace disque
df -h

# Configurer le fuseau horaire
sudo timedatectl set-timezone Europe/Paris

# Activer SSH de façon permanente
sudo systemctl enable ssh
```
**Status** : ⏳ À valider

---

## 📦 Week 1 - Base Docker

### 🚀 Installation Automatique Week 1
```bash
# Télécharger et exécuter le script Week 1
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week1.sh -o setup-week1.sh \
&& chmod +x setup-week1.sh \
&& sudo MODE=beginner ./setup-week1.sh
```
**Status** : ✅ **VALIDÉ** - Week 1 terminée avec succès

### 🔍 Vérification Week 1
```bash
# Vérifier Docker
docker --version
docker run --rm hello-world

# Vérifier Docker Compose
docker compose version

# Vérifier Portainer
curl -I http://localhost:9000

# Vérifier UFW (firewall)
sudo ufw status

# Vérifier Fail2ban
sudo fail2ban-client status
```
**Status** : ⏳ À valider

---

## 🗄️ Week 2 - Supabase

### 🧹 Nettoyage Installation Précédente (si nécessaire)
```bash
# Arrêter conteneurs Supabase
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker stop
sudo docker ps -a --filter 'name=supabase' -q | xargs -r sudo docker rm

# Nettoyer fichiers
cd ~ && rm -rf ~/stacks/supabase setup-week2*.sh 2>/dev/null || true
sudo rm -f /var/log/pi5-setup-week2*.log /tmp/pi5-supabase-phase.state 2>/dev/null || true

# Nettoyer Docker
sudo docker system prune -af
sudo docker volume prune -f
```
**Status** : ✅ **VALIDÉ**

### 🚀 Installation Automatique Week 2 - Orchestrateur Intelligent
```bash
# Installation complète avec support 16KB page size natif
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week2.sh -o setup-week2.sh \
&& chmod +x setup-week2.sh \
&& sudo MODE=beginner ./setup-week2.sh
```
**Status** : ✅ **VALIDÉ** - Support 16KB page size avec images compatibles

**🔧 Nouvelle approche** :
- ✅ Détection automatique page size (4KB ou 16KB)
- ✅ Images PostgreSQL Alpine pour 16KB
- ✅ Interface Supabase Studio identique
- ✅ API REST et fonctionnalités inchangées

### 🔄 Gestion des Phases (automatique)
```bash
# L'orchestrateur détecte automatiquement :
# - Page size 16KB + projet absent → Phase 1 (prep + fix + reboot)
# - Page size 16KB + projet existant → Instructions redémarrage
# - Page size 4KB + projet prêt → Phase 2 (installation complète)

# Si redémarrage nécessaire, après reboot :
ssh pi@pi5.local
sudo MODE=beginner ./setup-week2.sh  # Même commande !
```
**Status** : ⏳ À valider

### 🔍 Vérification Installation Supabase
```bash
cd ~/stacks/supabase

# État des services (tous doivent être "Up")
docker compose ps

# Test page size (doit être 4096)
getconf PAGE_SIZE

# Test API REST
curl -s http://localhost:8000/rest/v1/ | head -5

# Test santé complète
./scripts/supabase-health.sh

# Test pgvector (si installé)
docker compose exec -T db psql -U supabase_admin -d postgres -c "SELECT vector_dims('[1,2,3]'::vector);"
```
**Status** : ⏳ À valider

### 🌐 Accès aux Interfaces Supabase
```bash
# Obtenir l'IP du Pi
IP=$(hostname -I | awk '{print $1}')
echo "IP Pi5 : $IP"

# Accès web :
# Studio Supabase : http://192.168.X.XX:3000
# API Gateway : http://192.168.X.XX:8000
# pgAdmin (mode pro) : http://192.168.X.XX:8080
```
**Status** : ⏳ À valider

---

## 🌐 Week 3 - HTTPS & Accès Externe

### 🚀 Installation Week 3 (À VENIR)
```bash
# Commande future
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week3.sh -o setup-week3.sh
chmod +x setup-week3.sh
sudo ./setup-week3.sh
```
**Status** : 📋 Planifié

---

## 👥 Week 4 - Développement Collaboratif

### 🚀 Installation Week 4 (À VENIR)
```bash
# Commande future - Git, VS Code Server, CI/CD
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week4.sh -o setup-week4.sh
chmod +x setup-week4.sh
sudo ./setup-week4.sh
```
**Status** : 📋 Planifié

---

## ☁️ Week 5 - Cloud Personnel

### 🚀 Installation Week 5 (À VENIR)
```bash
# Commande future - NextCloud, Backups
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week5.sh -o setup-week5.sh
chmod +x setup-week5.sh
sudo ./setup-week5.sh
```
**Status** : 📋 Planifié

---

## 📺 Week 6 - Multimédia & IoT

### 🚀 Installation Week 6 (À VENIR)
```bash
# Commande future - Plex, DNS, Home Assistant
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/setup-week6.sh -o setup-week6.sh
chmod +x setup-week6.sh
sudo ./setup-week6.sh
```
**Status** : 📋 Planifié

---

## 🛠️ Maintenance & Diagnostic

### 📊 Surveillance Système
```bash
# Utilisation CPU/RAM en temps réel
htop

# Utilisation Docker
docker stats --no-stream

# Espace disque
df -h

# Température Pi 5
vcgencmd measure_temp

# Logs système
sudo journalctl -f
```
**Status** : ✅ **TOUJOURS UTILE**

### 🔧 Scripts Utilitaires (Week 2+)
```bash
cd ~/stacks/supabase

# Vérifier santé Supabase
./scripts/supabase-health.sh

# Sauvegarder base de données
./scripts/supabase-backup.sh

# Redémarrer proprement
./scripts/supabase-restart.sh

# Maintenance Pi 5
./scripts/pi5-maintenance.sh
```
**Status** : ⏳ À valider après Week 2

### 🧹 Nettoyage et Optimisation
```bash
# Nettoyer Docker
sudo docker system prune -af
sudo docker volume prune -f

# Nettoyer APT
sudo apt autoremove -y
sudo apt autoclean

# Vider les logs
sudo journalctl --vacuum-time=7d

# Vérifier intégrité SD
sudo fsck -f /dev/mmcblk0p2
```
**Status** : ✅ **TOUJOURS UTILE**

### 🔄 Redémarrage et Arrêt
```bash
# Redémarrage propre
sudo reboot

# Arrêt propre
sudo shutdown -h now

# Redémarrage avec attente
sudo reboot && sleep 60 && ssh pi@pi5.local
```
**Status** : ✅ **TOUJOURS UTILE**

---

## 🆘 Commandes d'Urgence

### 🚨 Récupération Système
```bash
# Si SSH ne répond plus - connexion directe écran/clavier
sudo systemctl restart ssh
sudo systemctl restart networking

# Si Docker plante
sudo systemctl restart docker

# Si plus d'espace disque
sudo docker system prune -af
sudo apt autoremove -y
sudo journalctl --vacuum-size=100M
```
**Status** : ✅ **TOUJOURS UTILE**

### 🔍 Diagnostic Réseau
```bash
# IP actuelle
ip addr show
hostname -I

# Test connectivité
ping google.com
ping pi5.local

# Ports ouverts
sudo netstat -tlnp | grep LISTEN

# Firewall status
sudo ufw status numbered
```
**Status** : ✅ **TOUJOURS UTILE**

---

## 📝 Légende des Status

- ✅ **VALIDÉ** : Commande testée et fonctionnelle
- ⏳ **À valider** : Commande prête, en attente de test
- 📋 **Planifié** : Commande future, pas encore implémentée
- ❌ **Problématique** : Commande qui pose des problèmes
- 🔧 **En cours** : Commande en développement

---

*Ce document est mis à jour au fur et à mesure de la validation des commandes à chaque étape.*