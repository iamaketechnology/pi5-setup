# ⚡ Installation Rapide via SSH

> **Installation directe depuis GitHub - Aucun clonage requis**

---

## 🚀 Installation en 3 Commandes

### Prérequis
- Raspberry Pi 5 avec Pi OS 64-bit (Bookworm)
- Connexion SSH active
- Connexion Internet

---

## 📥 Étape 1 : Prérequis & Infrastructure

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
```

**Ou avec wget :**
```bash
wget -qO- https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
```

**Ce qui sera installé :**
- ✅ Docker + Docker Compose
- ✅ Portainer (port 8080)
- ✅ Sécurité (UFW, Fail2ban)
- ✅ Page size fix 16KB → 4KB
- ✅ Optimisations Pi 5

**Durée :** ~15-30 minutes

**⚠️ REDÉMARRAGE OBLIGATOIRE :**
```bash
sudo reboot
```

---

## 📥 Étape 2 : Déploiement Supabase

**Après le reboot, se reconnecter en SSH et lancer :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

**Ou avec wget :**
```bash
wget -qO- https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ PostgreSQL 15 + extensions
- ✅ Auth, REST, Realtime, Storage
- ✅ Studio UI (port 3000)
- ✅ Kong API Gateway (port 8000)
- ✅ Edge Functions

**Durée :** ~8-12 minutes

---

## ✅ Vérification Installation

### Vérifier Page Size (CRITIQUE)
```bash
getconf PAGESIZE
# Doit afficher : 4096
```

### Vérifier Services
```bash
cd ~/stacks/supabase
docker compose ps
# Tous les services doivent être "healthy"
```

### Accéder à Supabase Studio
```
http://<IP-DU-PI>:3000
```

**Récupérer votre IP :**
```bash
hostname -I | awk '{print $1}'
```

---

## 🔑 Récupérer les API Keys

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/get-supabase-info.sh | sudo bash
```

Affiche :
- URLs d'accès
- Anon key (client-side)
- Service role key (server-side, secret!)
- JWT secret

---

## 🛠️ Scripts Utilitaires

### Diagnostic Complet
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/diagnostic-supabase-complet.sh | sudo bash
```

### Nettoyage (conserve données)
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/clean-supabase-complete.sh | sudo bash
```

### Reset Complet (⚠️ DESTRUCTIF - perte données)
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/pi5-complete-reset.sh | sudo bash
```

---

## 🆘 Troubleshooting

### Page Size Toujours 16384 Après Reboot

```bash
# Vérifier
getconf PAGESIZE

# Si 16384, fixer manuellement :
sudo nano /boot/firmware/cmdline.txt
# Ajouter "pagesize=4k" au DÉBUT de la ligne
# Sauvegarder (Ctrl+O, Enter, Ctrl+X)

sudo reboot

# Vérifier après reboot
getconf PAGESIZE  # Doit être 4096
```

### Services Unhealthy

```bash
cd ~/stacks/supabase
docker compose logs -f
# Observer les erreurs

# Redémarrage propre
docker compose down
sleep 10
docker compose up -d
```

### Réinstallation Complète

```bash
# 1. Reset complet
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/pi5-complete-reset.sh | sudo bash

# 2. Relancer Étape 1
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# 3. Relancer Étape 2
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

---

## 📚 Documentation Complète

**Pour aller plus loin :**

- [README Principal](README.md) - Vue d'ensemble
- [Guide Installation Détaillé](docs/INSTALLATION-GUIDE.md) - Pas-à-pas complet
- [Commands Reference](commands/All-Commands-Reference.md) - Toutes les commandes
- [Troubleshooting](docs/04-TROUBLESHOOTING/) - Résolution problèmes

**Cloner le repository complet (optionnel) :**
```bash
git clone https://github.com/iamaketechnology/pi5-setup.git
cd pi5-setup/pi5-supabase-stack
```

---

## 🎯 Installation Complète en Une Session

**Copy-paste toutes les commandes (attention au reboot entre 1 et 2) :**

```bash
# Étape 1 - Prérequis
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash

# Reboot OBLIGATOIRE
sudo reboot

# ⏸️  ATTENDRE REBOOT (1-2 min) puis se reconnecter SSH

# Étape 2 - Déploiement Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash

# Récupérer les infos
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/utils/get-supabase-info.sh | sudo bash
```

---

## ⚡ Alternative : Installation Locale

Si problème avec curl/wget, télécharger et exécuter localement :

```bash
# Télécharger Étape 1
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/01-prerequisites-setup.sh
chmod +x 01-prerequisites-setup.sh
sudo ./01-prerequisites-setup.sh
sudo reboot

# Après reboot, télécharger Étape 2
wget https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-setup/pi5-supabase-stack/scripts/02-supabase-deploy.sh
chmod +x 02-supabase-deploy.sh
sudo ./02-supabase-deploy.sh
```

---

<p align="center">
  <strong>🚀 Installation Terminée en ~45 Minutes ! 🚀</strong>
</p>

<p align="center">
  <sub>Stack Supabase complète déployée et prête à l'emploi</sub>
</p>
