# 🥧 Configuration Initiale Raspberry Pi 5

> **Commandes à exécuter dès la première installation du Raspberry Pi OS**

---

## 📋 Table des Matières

- [Matériel Requis](#matériel-requis)
- [Installation Raspberry Pi OS](#installation-raspberry-pi-os)
- [Premier Démarrage](#premier-démarrage)
- [Configuration Système de Base](#configuration-système-de-base)
- [Configuration Réseau](#configuration-réseau)
- [Sécurité SSH](#sécurité-ssh)
- [Mise à Jour Système](#mise-à-jour-système)
- [Installation Outils Essentiels](#installation-outils-essentiels)
- [Optimisations Pi 5](#optimisations-pi-5)
- [Vérifications Finales](#vérifications-finales)

---

## 💻 Matériel Requis

### Minimum
- **Raspberry Pi 5** (8GB RAM)
- **Carte microSD** 32GB+ (Class 10 / UHS-I)
- **Alimentation** officielle 27W USB-C
- **Câble Ethernet** (recommandé pour setup initial)

### Recommandé
- **Raspberry Pi 5** (16GB RAM) ⭐
- **NVMe SSD** 64GB+ via HAT PCIe
- **Ventilateur actif** ou heatsink
- **Boîtier** avec ventilation

---

## 💿 Installation Raspberry Pi OS

### 1. Télécharger Raspberry Pi Imager

**Sur Windows/macOS/Linux :**
```bash
# Télécharger depuis : https://www.raspberrypi.com/software/
```

### 2. Flasher la carte microSD

1. **Insérer** la carte microSD dans votre ordinateur
2. **Lancer** Raspberry Pi Imager
3. **Choisir OS** : Raspberry Pi OS (64-bit) - **Bookworm** recommandé
4. **Choisir Storage** : Sélectionner votre carte microSD
5. **Paramètres avancés** (⚙️) :
   - ✅ **Activer SSH** (avec authentification par mot de passe)
   - ✅ **Définir hostname** : `pi5-supabase`
   - ✅ **Configurer WiFi** (si pas d'Ethernet)
   - ✅ **Définir username/password** : `pi` / `votre_mot_de_passe`
   - ✅ **Timezone** : Votre fuseau horaire
   - ✅ **Keyboard layout** : Votre clavier
6. **Écrire** et attendre la fin du flash

### 3. Premier Boot

1. Insérer la microSD dans le Raspberry Pi 5
2. Connecter Ethernet (recommandé)
3. Brancher l'alimentation
4. Attendre ~2 minutes (première expansion du système)

---

## 🔌 Premier Démarrage

### Trouver l'adresse IP du Pi

**Depuis votre routeur :**
- Chercher un appareil nommé `pi5-supabase` ou `raspberrypi`

**Ou via scan réseau :**
```bash
# Sur macOS/Linux
arp -a | grep -i "b8:27:eb\|dc:a6:32\|e4:5f:01"

# Avec nmap
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"
```

### Connexion SSH

```bash
# Remplacer par votre IP
ssh pi@192.168.1.XXX

# Si erreur "Host key verification failed"
ssh-keygen -R 192.168.1.XXX
ssh pi@192.168.1.XXX
```

**Première connexion :**
- Accepter le fingerprint : `yes`
- Entrer le mot de passe défini lors du flash

---

## ⚙️ Configuration Système de Base

### 1. Configuration via raspi-config

```bash
# Lancer l'outil de configuration
sudo raspi-config
```

**Navigation dans raspi-config :**

#### 1. System Options
- **S3 Password** : Changer le mot de passe (sécurité)
- **S4 Hostname** : Définir hostname `pi5-supabase`
- **S5 Boot / Auto Login** : Console (pas de desktop)

#### 2. Interface Options
- **I2 SSH** : Enable (si pas déjà fait)
- **I3 VNC** : Disable (pas nécessaire pour serveur)

#### 3. Performance Options
- **P2 GPU Memory** : `128` (si 16GB RAM)
- **P4 Fan** : Configurer si ventilateur actif

#### 4. Localisation Options
- **L1 Locale** : Sélectionner `en_US.UTF-8` ou `fr_FR.UTF-8`
- **L2 Timezone** : Votre timezone (ex: `Europe/Paris`)
- **L3 Keyboard** : Votre layout clavier
- **L4 WLAN Country** : Votre pays

#### 5. Advanced Options
- **A1 Expand Filesystem** : (normalement déjà fait au 1er boot)

**Sauvegarder et redémarrer :**
- Sélectionner `<Finish>`
- `Yes` pour reboot

```bash
# Attendre redémarrage et se reconnecter
ssh pi@192.168.1.XXX
```

---

## 🌐 Configuration Réseau

### IP Statique (Recommandé pour serveur)

#### Méthode 1 : Via dhcpcd (Recommandé)

```bash
# Éditer configuration dhcpcd
sudo nano /etc/dhcpcd.conf

# Ajouter à la fin (adapter les IPs à votre réseau) :
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Sauvegarder : Ctrl+O, Enter, Ctrl+X
```

```bash
# Redémarrer service réseau
sudo systemctl restart dhcpcd

# Vérifier nouvelle IP
ip addr show eth0
```

#### Méthode 2 : Réservation DHCP (Alternative)

- Se connecter à l'interface admin de votre routeur
- Réserver l'IP actuelle du Pi basée sur son MAC address
- Avantage : Pas de config manuelle sur le Pi

### Tester Connectivité

```bash
# Ping Internet
ping -c 4 google.com

# Ping gateway local
ping -c 4 192.168.1.1

# Vérifier DNS
nslookup google.com

# Voir route par défaut
ip route show
```

---

## 🔐 Sécurité SSH

### 1. Générer Clé SSH (depuis votre ordinateur)

```bash
# Sur votre machine locale (pas le Pi)
ssh-keygen -t ed25519 -C "pi5-supabase"

# Accepter l'emplacement par défaut : ~/.ssh/id_ed25519
# Définir une passphrase (optionnel mais recommandé)
```

### 2. Copier Clé Publique vers Pi

```bash
# Depuis votre machine locale
ssh-copy-id pi@192.168.1.100

# Entrer le mot de passe du Pi une dernière fois
```

### 3. Tester Connexion par Clé

```bash
# Depuis votre machine locale
ssh pi@192.168.1.100

# Devrait se connecter sans demander de mot de passe
# (ou juste passphrase de la clé si définie)
```

### 4. Désactiver Authentification par Mot de Passe

**⚠️ IMPORTANT : Ne faire qu'APRÈS avoir testé la connexion par clé !**

```bash
# Sur le Pi
sudo nano /etc/ssh/sshd_config

# Modifier ces lignes :
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

# Sauvegarder et quitter
```

```bash
# Redémarrer SSH
sudo systemctl restart ssh

# Tester depuis votre machine locale
ssh pi@192.168.1.100
```

### 5. Optionnel : Changer Port SSH

```bash
# Éditer config SSH
sudo nano /etc/ssh/sshd_config

# Changer ligne :
Port 2222  # Au lieu de 22

# Sauvegarder et redémarrer
sudo systemctl restart ssh

# Connexion avec nouveau port :
ssh -p 2222 pi@192.168.1.100
```

---

## 🔄 Mise à Jour Système

### Première Mise à Jour Complète

```bash
# Mettre à jour liste paquets
sudo apt update

# Voir mises à jour disponibles
apt list --upgradable

# Mettre à jour tous paquets
sudo apt full-upgrade -y

# Nettoyer paquets obsolètes
sudo apt autoremove -y
sudo apt autoclean
```

**Durée estimée** : 10-30 minutes selon la connexion

```bash
# Redémarrer après mise à jour majeure
sudo reboot

# Attendre 1-2 min et se reconnecter
ssh pi@192.168.1.100
```

### Vérifier Version Système

```bash
# Version OS
cat /etc/os-release

# Version kernel
uname -r

# Doit afficher kernel 6.6+ pour Bookworm
```

---

## 🛠️ Installation Outils Essentiels

### Outils Système

```bash
# Installation outils de base
sudo apt install -y \
  git \
  curl \
  wget \
  htop \
  vim \
  nano \
  rsync \
  screen \
  tmux \
  tree \
  ncdu \
  iotop \
  nethogs
```

### Outils Réseau

```bash
# Outils diagnostic réseau
sudo apt install -y \
  net-tools \
  dnsutils \
  traceroute \
  nmap \
  iperf3 \
  tcpdump
```

### Outils Monitoring

```bash
# Monitoring avancé
sudo apt install -y \
  sysstat \
  lm-sensors \
  smartmontools
```

### Configuration Git (Si besoin)

```bash
# Configurer Git
git config --global user.name "Votre Nom"
git config --global user.email "votre@email.com"

# Vérifier config
git config --list
```

---

## ⚡ Optimisations Pi 5

### 1. Page Size Fix (CRITIQUE pour PostgreSQL)

```bash
# Vérifier page size actuel
getconf PAGESIZE

# Si 16384 (16KB), fixer à 4KB :
sudo nano /boot/firmware/cmdline.txt

# Ajouter au début de la ligne (avant tout) :
pagesize=4k

# Exemple complet :
# pagesize=4k console=serial0,115200 console=tty1 root=PARTUUID=... [reste inchangé]

# Sauvegarder : Ctrl+O, Enter, Ctrl+X
```

**⚠️ Redémarrage OBLIGATOIRE :**

```bash
sudo reboot

# Après reboot, vérifier :
getconf PAGESIZE
# Doit afficher : 4096
```

### 2. Désactiver Swap (Optionnel, si SSD NVMe)

```bash
# Vérifier swap actuel
free -h

# Désactiver swap
sudo dphys-swapfile swapoff
sudo systemctl disable dphys-swapfile

# Vérifier
free -h  # Swap doit être à 0
```

### 3. Optimisations Boot

```bash
# Éditer config.txt
sudo nano /boot/firmware/config.txt

# Ajouter à la fin :
# GPU memory (si 16GB RAM)
gpu_mem=128

# Activer ventilateur (si présent)
dtoverlay=gpio-fan,gpiopin=14,temp=60000

# Performance maximale (optionnel)
arm_boost=1

# Sauvegarder et redémarrer
sudo reboot
```

### 4. Limites Système (pour Docker)

```bash
# Augmenter limites fichiers ouverts
sudo nano /etc/security/limits.conf

# Ajouter :
* soft nofile 65536
* hard nofile 65536

# Sauvegarder et reboot
sudo reboot
```

---

## ✅ Vérifications Finales

### Script Diagnostic Complet

```bash
# Créer script de vérification
cat > ~/check-system.sh <<'EOF'
#!/bin/bash
echo "==================================="
echo "  RASPBERRY PI 5 - SYSTEM CHECK"
echo "==================================="
echo ""
echo "📋 OS Information:"
cat /etc/os-release | grep PRETTY_NAME
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""
echo "💻 Hardware:"
echo "Page Size: $(getconf PAGESIZE) bytes"
echo "CPU Cores: $(nproc)"
echo "RAM Total: $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk Space: $(df -h / | awk 'NR==2{print $4}') available"
echo ""
echo "🌡️ Temperature:"
vcgencmd measure_temp
echo ""
echo "🌐 Network:"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "Gateway: $(ip route | grep default | awk '{print $3}')"
echo ""
echo "🔐 SSH:"
echo "SSH Port: $(grep "^Port" /etc/ssh/sshd_config || echo "22 (default)")"
echo "Password Auth: $(grep "^PasswordAuthentication" /etc/ssh/sshd_config || echo "yes (default)")"
echo ""
echo "✅ All checks completed!"
echo "==================================="
EOF

chmod +x ~/check-system.sh
```

### Exécuter Vérifications

```bash
# Lancer le script
~/check-system.sh
```

**Résultats attendus :**
```
✅ OS: Debian GNU/Linux 12 (bookworm)
✅ Kernel: 6.6.x+
✅ Architecture: aarch64
✅ Page Size: 4096 bytes
✅ RAM: 15Gi (Pi 5 16GB)
✅ IP: 192.168.1.100
✅ SSH: Configured
```

### Vérifications Manuelles

```bash
# 1. Vérifier connexion Internet
ping -c 3 google.com

# 2. Vérifier page size (DOIT être 4096)
getconf PAGESIZE

# 3. Vérifier SSH fonctionne
sudo systemctl status ssh

# 4. Vérifier temps système
timedatectl

# 5. Vérifier espace disque
df -h

# 6. Vérifier RAM
free -h

# 7. Vérifier température
vcgencmd measure_temp
```

---

## 📝 Checklist Finale

Avant de passer à l'installation Supabase, vérifier :

- [ ] ✅ Raspberry Pi OS 64-bit Bookworm installé
- [ ] ✅ Système à jour (`sudo apt update && sudo apt full-upgrade`)
- [ ] ✅ **Page size = 4096** (`getconf PAGESIZE`)
- [ ] ✅ IP statique configurée
- [ ] ✅ Connexion SSH par clé fonctionnelle
- [ ] ✅ Authentification SSH par mot de passe désactivée
- [ ] ✅ Hostname configuré (`pi5-supabase`)
- [ ] ✅ Timezone correcte
- [ ] ✅ Outils essentiels installés (git, curl, htop, etc.)
- [ ] ✅ Ventilateur configuré (si présent)
- [ ] ✅ Connexion Internet stable
- [ ] ✅ Espace disque > 30GB disponible

---

## ➡️ Prochaine Étape

Votre Raspberry Pi 5 est maintenant prêt ! 🎉

**Continuer avec l'installation Supabase :**

```bash
# Cloner le repository
cd ~
git clone https://github.com/your-username/pi5-setup.git
cd pi5-setup/pi5-supabase-stack

# Lancer Étape 1 (Docker + Système)
sudo ./scripts/01-prerequisites-setup.sh
```

📖 **Voir la documentation complète** : [README.md](../README.md)

---

<p align="center">
  <strong>🚀 Votre Pi 5 est configuré et sécurisé ! 🚀</strong>
</p>

<p align="center">
  <sub>Configuration de base terminée - Passez à l'installation Supabase</sub>
</p>
