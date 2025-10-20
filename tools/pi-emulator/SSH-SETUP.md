# 🔑 Configuration SSH Mac → Linux Mint

Guide complet pour configurer l'accès SSH depuis ton Mac vers ton PC Linux Mint.

---

## 🚀 Quick Start (Automatique)

### Sur ton Mac

```bash
cd tools/pi-emulator
bash scripts/00-setup-ssh-access.sh
```

Le script va :
1. ✅ Créer/vérifier clé SSH sur Mac
2. ✅ Te guider pour configurer Linux Mint
3. ✅ Tester la connexion
4. ✅ Créer un alias SSH pratique

---

## 📋 Configuration Manuelle (Step-by-step)

### Étape 1️⃣ : Sur ton Linux Mint

#### A. Installer SSH Server

```bash
sudo apt update
sudo apt install -y openssh-server
```

#### B. Démarrer SSH

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl status ssh
```

Tu devrais voir : **`● ssh.service - OpenBSD Secure Shell server`** (vert/actif)

#### C. Trouver l'IP de ton Linux Mint

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

Note l'IP (ex: `192.168.1.100`)

#### D. Autoriser SSH dans le firewall

```bash
sudo ufw allow 22
sudo ufw status
```

---

### Étape 2️⃣ : Sur ton Mac

#### A. Créer clé SSH (si pas déjà fait)

```bash
# Vérifier si clé existe
ls -la ~/.ssh/id_rsa.pub

# Si non, créer
ssh-keygen -t rsa -b 4096 -C "mac-to-linux-mint"
# Appuyer ENTER 3x (pas de passphrase pour automation)
```

#### B. Copier la clé publique

```bash
# Afficher la clé
cat ~/.ssh/id_rsa.pub
```

**Copie tout le contenu** (commence par `ssh-rsa AAAA...`)

---

### Étape 3️⃣ : Retour sur Linux Mint

#### A. Créer répertoire .ssh

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
```

#### B. Ajouter la clé publique du Mac

```bash
nano ~/.ssh/authorized_keys
```

- **Colle** la clé publique du Mac (CTRL+SHIFT+V)
- **Sauvegarde** : CTRL+O, ENTER, CTRL+X

#### C. Fixer permissions

```bash
chmod 600 ~/.ssh/authorized_keys
```

---

### Étape 4️⃣ : Test depuis Mac

Remplace `USER` et `IP` :

```bash
ssh user@192.168.1.100
```

Si ça demande un password, c'est normal la première fois. Entre le password Linux Mint.

**Si ça marche sans password** → ✅ Configuré !

---

## 🎯 Alias SSH (Recommandé)

Sur ton **Mac**, édite `~/.ssh/config` :

```bash
nano ~/.ssh/config
```

Ajoute :

```
Host linux-mint
    HostName 192.168.1.100
    User ton-username
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
```

**Maintenant tu peux faire** :

```bash
ssh linux-mint
```

Au lieu de `ssh user@192.168.1.100` 🎉

---

## 🧪 Tester la connexion

```bash
# Test simple
ssh linux-mint 'echo "SSH fonctionne!" && uname -a'

# Test Docker
ssh linux-mint 'docker --version'

# Lancer Pi Emulator à distance
ssh linux-mint 'bash -s' < tools/pi-emulator/scripts/01-pi-emulator-deploy-linux.sh
```

---

## 🐛 Troubleshooting

### Problème : "Connection refused"

**Sur Linux Mint** :
```bash
sudo systemctl status ssh
# Si pas actif :
sudo systemctl start ssh
```

### Problème : "Permission denied (publickey)"

**Sur Linux Mint** :
```bash
# Vérifier permissions
ls -la ~/.ssh/
# Devrait être :
# drwx------  .ssh/
# -rw-------  authorized_keys

# Fixer si besoin
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

### Problème : "Host key verification failed"

**Sur Mac** :
```bash
ssh-keygen -R 192.168.1.100  # Remplace par ton IP
```

### Problème : Firewall bloque

**Sur Linux Mint** :
```bash
sudo ufw status
sudo ufw allow 22
sudo ufw reload
```

### Problème : SSH demande toujours password

**Sur Linux Mint**, vérifier config SSH :
```bash
sudo nano /etc/ssh/sshd_config
```

Assurer ces lignes :
```
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
```

Puis :
```bash
sudo systemctl restart ssh
```

---

## 🔐 Sécurité

### Désactiver password auth (après test clé SSH)

**Sur Linux Mint** :
```bash
sudo nano /etc/ssh/sshd_config
```

Modifier :
```
PasswordAuthentication no
```

Redémarrer :
```bash
sudo systemctl restart ssh
```

### Changer port SSH (optionnel)

**Sur Linux Mint** :
```bash
sudo nano /etc/ssh/sshd_config
```

```
Port 2222  # Au lieu de 22
```

Firewall :
```bash
sudo ufw allow 2222
sudo ufw delete allow 22
sudo systemctl restart ssh
```

**Sur Mac** (.ssh/config) :
```
Host linux-mint
    HostName 192.168.1.100
    Port 2222
    User ton-username
```

---

## 📊 Commandes Utiles

### Depuis Mac vers Linux Mint

```bash
# Copier fichier Mac → Linux
scp /path/file.txt linux-mint:~/

# Copier fichier Linux → Mac
scp linux-mint:~/file.txt /path/local/

# Exécuter commande à distance
ssh linux-mint 'docker ps'

# Exécuter script local sur Linux
ssh linux-mint 'bash -s' < local-script.sh

# Tunnel SSH (accéder service Linux depuis Mac)
ssh -L 8080:localhost:8080 linux-mint
# Accès: http://localhost:8080 sur Mac
```

---

## 🎯 Prochaine Étape : Pi Emulator

Une fois SSH configuré :

```bash
# Depuis ton Mac
cd tools/pi-emulator

# Lancer émulateur sur Linux à distance
ssh linux-mint 'bash -s' < scripts/01-pi-emulator-deploy-linux.sh

# OU se connecter et lancer manuellement
ssh linux-mint
cd /path/to/pi5-setup/tools/pi-emulator
bash scripts/01-pi-emulator-deploy-linux.sh
```

---

## 🔄 Multiple Linux PCs

Si tu as plusieurs Linux :

```bash
# ~/.ssh/config sur Mac
Host linux-mint-1
    HostName 192.168.1.100
    User user1

Host linux-mint-2
    HostName 192.168.1.101
    User user2
```

---

**Version** : 1.0.0
**Last Updated** : 2025-01-20
**Platform** : Linux Mint 21+ / macOS
