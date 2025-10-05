# Installation Guide - Gitea Git Self-Hosted + CI/CD

**Phase 5 : Git Self-Hosted + CI/CD avec Gitea Actions**

> Guide d'installation détaillé pour déployer Gitea sur Raspberry Pi 5 avec support CI/CD complet

---

## Table des Matières

1. [Prérequis](#1-prérequis)
2. [Étape 1 : Installation de Gitea](#2-étape-1--installation-de-gitea)
3. [Étape 2 : Première Connexion](#3-étape-2--première-connexion)
4. [Étape 3 : Configuration SSH](#4-étape-3--configuration-ssh)
5. [Étape 4 : Premier Repository](#5-étape-4--premier-repository)
6. [Étape 5 : Installation du Runner CI/CD](#6-étape-5--installation-du-runner-cicd)
7. [Étape 6 : Premier Workflow](#7-étape-6--premier-workflow)
8. [Étape 7 : Configuration des Secrets](#8-étape-7--configuration-des-secrets)
9. [Étape 8 : (Optionnel) Activer les Packages](#9-étape-8--optionnel-activer-les-packages)
10. [Dépannage](#10-dépannage)
11. [Commandes de Gestion](#11-commandes-de-gestion)

---

## 1. Prérequis

### Matériel Requis

- **Raspberry Pi 5** (8GB RAM recommandé)
- Carte SD/SSD avec minimum **10 GB d'espace libre**
- Connexion Internet stable

### Logiciels Requis

- **Raspberry Pi OS Bookworm (64-bit)**
- **Docker** + Docker Compose installés
- **Git** installé localement (sur votre machine de développement)

### Optionnel (Recommandé)

- **Traefik** déployé (pour HTTPS automatique)
  - Scénario DuckDNS (gratuit, facile)
  - Scénario Cloudflare (domaine perso)
  - Scénario VPN (Tailscale/WireGuard)
- **Nom de domaine ou sous-domaine**
  - Exemple : `git.example.com` ou `example.duckdns.org`

### Vérification des Prérequis

```bash
# Vérifier Docker
docker --version
docker compose version

# Vérifier l'espace disque
df -h

# Vérifier la RAM
free -h

# Vérifier l'architecture (doit être aarch64)
uname -m
```

**Sortie attendue :**
```
Docker version 24.0.0+
Docker Compose version v2.20.0+
Filesystem      Size  Used Avail Use% Mounted on
/dev/mmcblk0p2   58G   12G   44G  22% /
               total        used        free
Mem:           7.8Gi       2.1Gi       4.2Gi
aarch64
```

---

## 2. Étape 1 : Installation de Gitea

### Mode Interactif (Recommandé pour Débutants)

Le script vous posera des questions pour configurer Gitea selon vos besoins.

```bash
# Télécharger et exécuter le script d'installation
curl -fsSL https://raw.githubusercontent.com/username/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash
```

### Mode Automatisé (Avec Variables d'Environnement)

Pour une installation sans interaction, définissez les variables avant d'exécuter :

```bash
# Configuration de base
export GITEA_ADMIN_USER="admin"
export GITEA_ADMIN_PASSWORD="VotreMotDePasseSecurise123"
export GITEA_ADMIN_EMAIL="admin@example.com"
export GITEA_APP_NAME="Mon Serveur Git"

# Configuration de sécurité
export GITEA_DISABLE_REGISTRATION="true"       # Désactiver l'inscription publique
export GITEA_REQUIRE_SIGNIN_VIEW="false"       # Autoriser la lecture sans connexion
export GITEA_ENABLE_ACTIONS="true"             # Activer Gitea Actions (CI/CD)

# Configuration SSH
export GITEA_SSH_PORT="222"                    # Port SSH (éviter 22)
export GITEA_HTTP_PORT="3000"                  # Port HTTP interne

# Lancer l'installation
curl -fsSL https://raw.githubusercontent.com/username/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash
```

### Déroulement de l'Installation Interactive

Le script vous guidera à travers les étapes suivantes :

#### 1. Détection de Traefik

Si Traefik est installé, le script détectera automatiquement le scénario :

```
[GITEA] Checking for Traefik installation...
[OK]    Traefik is installed and running
[GITEA] Detecting Traefik deployment scenario...
[OK]    Detected scenario: DuckDNS (path-based routing)
[GITEA] Base domain: example.duckdns.org
```

**Options selon le scénario :**

- **DuckDNS** : Gitea accessible via `https://example.duckdns.org/git`
- **Cloudflare** : Choix entre subdomain (`https://git.example.com`) ou path-based
- **VPN** : Domaine local comme `git.pi.local`
- **Sans Traefik** : Accès local uniquement via `http://IP:3000`

#### 2. Configuration du Compte Administrateur

```
==========================================
Admin Account Configuration
==========================================

Enter admin username (default: admin): admin
Generated secure password: Xk9mP2nR5tQ8wL3v
IMPORTANT: Save this password securely!

Press Enter to continue or type a custom password:
Enter admin email: admin@example.com
```

**⚠️ Important :** Notez bien le mot de passe généré ou saisissez-en un personnalisé !

#### 3. Configuration Gitea Actions (CI/CD)

```
==========================================
Gitea Actions (CI/CD) Configuration
==========================================

Enable Gitea Actions (CI/CD)? [Y/n]: Y
```

Répondez **Y** pour activer les workflows automatisés (recommandé).

#### 4. Paramètres de Sécurité

```
==========================================
Security Settings
==========================================

Disable public registration (admin creates users)? [Y/n]: Y
Require sign-in to view content? [y/N]: N
```

**Recommandations :**
- **Désactiver l'inscription publique** : Oui (vous créez les comptes)
- **Exiger connexion pour voir** : Non (permet de partager des repos publics)

#### 5. Configuration SSH

```
==========================================
SSH Configuration
==========================================

Current SSH port: 222 (default: 222)
Change SSH port? [y/N]: N
```

Le port **222** est utilisé par défaut pour éviter les conflits avec SSH système (port 22).

#### 6. Résumé de la Configuration

```
==========================================
Configuration Summary:
==========================================
Gitea URL: https://example.duckdns.org/git
Traefik Scenario: duckdns
Admin User: admin
Admin Email: admin@example.com
Admin Password: Xk9mP2nR5tQ8wL3v
SSH Port: 222
HTTP Port: 3000
Gitea Actions: true
Public Registration: Disabled
Require Sign-in: No
==========================================

Proceed with this configuration? [y/N]: y
```

Vérifiez attentivement, puis tapez **y** pour continuer.

### Sortie Attendue de l'Installation

```
[GITEA] Creating directory structure...
[OK]    Directory structure created at /home/pi/stacks/gitea
[GITEA] Generating environment file...
[OK]    Environment file created with restricted permissions
[GITEA] Generating docker-compose.yml...
[OK]    Docker Compose configuration generated
[GITEA] Deploying Gitea stack...
[GITEA] Pulling Docker images (this may take a few minutes)...
[GITEA] Starting Gitea stack...
[GITEA] Waiting for containers to start (this may take up to 2 minutes)...
[OK]    Gitea stack deployed successfully
[GITEA] Creating admin user...
[OK]    Admin user created successfully

==========================================
Gitea Deployment Complete
==========================================

Access Information:
  Web Interface: https://example.duckdns.org/git
  Admin Username: admin
  Admin Password: Xk9mP2nR5tQ8wL3v
  Admin Email: admin@example.com

Git SSH Access:
  SSH Port: 222
  Clone URL: git@example.duckdns.org:222/username/repo.git

Features:
  Gitea Actions (CI/CD): Enabled
  Public Registration: Disabled
  Require Sign-in: No
  Git LFS: Enabled

Next Steps:
  1. Access Gitea at: https://example.duckdns.org/git
  2. Login with admin credentials shown above
  3. Configure your SSH key in User Settings
  4. Install Gitea Actions Runner: ./02-runners-setup.sh
  5. Create your first repository
  6. Clone and start developing!
```

### Fichiers Créés

L'installation crée la structure suivante :

```
/home/pi/stacks/gitea/
├── .env                          # Variables d'environnement (SENSIBLE!)
├── docker-compose.yml            # Configuration Docker
├── config/
│   └── app.ini.template         # Template de configuration
├── data/                        # Données Gitea (repos, uploads)
├── postgres/                    # Base de données PostgreSQL
├── backups/                     # Répertoire pour sauvegardes
└── DEPLOYMENT_INFO.txt          # Résumé de l'installation (SENSIBLE!)
```

**⚠️ Sécurité :** Les fichiers `.env` et `DEPLOYMENT_INFO.txt` contiennent des mots de passe. Ne les partagez jamais !

---

## 3. Étape 2 : Première Connexion

### Accéder à l'Interface Web

1. **Ouvrez votre navigateur**

2. **Accédez à l'URL de Gitea**
   - Avec Traefik : `https://votre-domaine/git` ou `https://git.votre-domaine.com`
   - Sans Traefik : `http://IP-DU-PI:3000`

3. **Connexion**
   - Utilisateur : `admin` (ou celui configuré)
   - Mot de passe : celui noté lors de l'installation

### Page d'Accueil Gitea

Après connexion, vous verrez :

```
┌─────────────────────────────────────────────┐
│  Mon Serveur Git                    [admin]▼│
├─────────────────────────────────────────────┤
│  Dashboard                                   │
│                                              │
│  📁 My Repositories                          │
│  No repositories yet                         │
│                                              │
│  [+ Create Repository]                       │
│                                              │
│  📋 My Organizations                         │
│  No organizations yet                        │
│                                              │
└─────────────────────────────────────────────┘
```

### Configurer le Profil

1. **Cliquez sur votre avatar** en haut à droite
2. **Sélectionnez "Settings"**
3. **Complétez votre profil** :
   - Nom complet
   - Avatar (optionnel)
   - Langue (Français disponible)

### Premier Aperçu

**Navigation principale :**
- **Dashboard** : Vue d'ensemble de vos repos
- **Issues** : Système de tickets
- **Pull Requests** : Revues de code
- **Explore** : Découvrir des repos publics
- **Site Administration** : (Admin uniquement) Gestion globale

---

## 4. Étape 3 : Configuration SSH

Pour cloner et pousser du code via Git, configurez l'accès SSH.

### Sur Votre Machine Locale

#### 1. Générer une Clé SSH (Si Vous N'en Avez Pas)

```bash
# Générer une paire de clés SSH
ssh-keygen -t ed25519 -C "votre-email@example.com"

# Appuyez sur Entrée pour accepter l'emplacement par défaut
# (~/.ssh/id_ed25519)

# Entrez une passphrase sécurisée (recommandé)
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

**Sortie attendue :**
```
Generating public/private ed25519 key pair.
Your identification has been saved in /home/user/.ssh/id_ed25519
Your public key has been saved in /home/user/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:xyz123... votre-email@example.com
```

#### 2. Afficher la Clé Publique

```bash
# Linux/macOS
cat ~/.ssh/id_ed25519.pub

# Windows (PowerShell)
type $env:USERPROFILE\.ssh\id_ed25519.pub
```

**Sortie (exemple) :**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAbCdEfGhIjKlMnOpQrStUvWxYz... votre-email@example.com
```

**Copiez** toute cette ligne.

### Dans Gitea

#### 1. Accéder aux Paramètres SSH

1. **Cliquez sur votre avatar** → **Settings**
2. **Dans le menu latéral**, cliquez sur **SSH / GPG Keys**
3. **Cliquez sur le bouton vert** "Add Key"

#### 2. Ajouter la Clé SSH

```
┌─────────────────────────────────────────────┐
│  Add SSH Key                                 │
├─────────────────────────────────────────────┤
│  Key Name:                                   │
│  ┌─────────────────────────────────────────┐│
│  │ Mon Ordinateur Principal                ││
│  └─────────────────────────────────────────┘│
│                                              │
│  Content:                                    │
│  ┌─────────────────────────────────────────┐│
│  │ ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...││
│  │                                         ││
│  └─────────────────────────────────────────┘│
│                                              │
│         [Cancel]  [Add Key]                  │
└─────────────────────────────────────────────┘
```

**Champs :**
- **Key Name** : Un nom descriptif (ex: "Laptop Bureau", "Serveur CI")
- **Content** : Collez la clé publique copiée précédemment

Cliquez sur **Add Key**.

#### 3. Vérification

Vous devriez voir :

```
✓ Key added successfully
```

La clé apparaît maintenant dans la liste avec :
- Nom de la clé
- Empreinte (fingerprint)
- Date d'ajout
- Dernier usage

### Tester la Connexion SSH

#### Configuration du Port SSH Personnalisé

Si Gitea utilise le port **222** (défaut), configurez SSH :

**Option 1 : Spécifier le port dans chaque commande**

```bash
git clone ssh://git@votre-domaine:222/username/repo.git
```

**Option 2 : Configurer SSH globalement (Recommandé)**

Éditez `~/.ssh/config` :

```bash
# Linux/macOS
nano ~/.ssh/config

# Windows
notepad $env:USERPROFILE\.ssh\config
```

Ajoutez :

```ssh-config
Host gitea
    HostName votre-domaine.com
    User git
    Port 222
    IdentityFile ~/.ssh/id_ed25519

# Ou pour une IP directe
Host gitea-pi
    HostName 192.168.1.100
    User git
    Port 222
    IdentityFile ~/.ssh/id_ed25519
```

**Sauvegardez** et fermez l'éditeur.

#### Test de Connexion

```bash
# Test avec domaine (si configuré dans ~/.ssh/config)
ssh -T gitea

# Test direct avec port
ssh -T -p 222 git@votre-domaine.com

# Ou avec IP
ssh -T -p 222 git@192.168.1.100
```

**Sortie attendue :**
```
Hi there, admin! You've successfully authenticated, but Gitea does not provide shell access.
```

✅ Si vous voyez ce message, la connexion SSH fonctionne !

### Dépannage SSH Courant

#### Erreur : "Permission denied (publickey)"

**Cause :** Clé SSH non reconnue

**Solution :**
```bash
# Vérifier que la clé est chargée
ssh-add -l

# Si vide, ajouter la clé
ssh-add ~/.ssh/id_ed25519

# Vérifier que la clé publique est bien dans Gitea
# Settings → SSH / GPG Keys
```

#### Erreur : "Connection refused"

**Cause :** Port incorrect ou firewall

**Solution :**
```bash
# Vérifier que le port 222 est ouvert
sudo ufw status

# Si UFW est actif, autoriser le port
sudo ufw allow 222/tcp

# Tester la connectivité réseau
telnet votre-domaine.com 222
# ou
nc -zv votre-domaine.com 222
```

#### Erreur : "Host key verification failed"

**Cause :** Empreinte SSH inconnue

**Solution :**
```bash
# Accepter la nouvelle empreinte
ssh-keyscan -p 222 votre-domaine.com >> ~/.ssh/known_hosts
```

---

## 5. Étape 4 : Premier Repository

### Créer un Nouveau Repository

#### Via l'Interface Web

1. **Cliquez sur le bouton vert** "+" en haut à droite → **New Repository**

2. **Remplissez le formulaire** :

```
┌─────────────────────────────────────────────┐
│  Create New Repository                       │
├─────────────────────────────────────────────┤
│  Owner: [admin ▼]                            │
│                                              │
│  Repository Name: *                          │
│  ┌─────────────────────────────────────────┐│
│  │ mon-premier-projet                      ││
│  └─────────────────────────────────────────┘│
│                                              │
│  Description:                                │
│  ┌─────────────────────────────────────────┐│
│  │ Mon premier projet avec Gitea           ││
│  └─────────────────────────────────────────┘│
│                                              │
│  Visibility:                                 │
│  ○ Public   ● Private                        │
│                                              │
│  Initialize Repository:                      │
│  ☑ Add .gitignore: [None ▼]                 │
│  ☑ Add README.md                             │
│  ☑ Add License: [MIT ▼]                      │
│                                              │
│         [Cancel]  [Create Repository]        │
└─────────────────────────────────────────────┘
```

**Champs importants :**
- **Repository Name** : Nom du projet (lettres, chiffres, tirets)
- **Description** : Courte description (optionnel)
- **Visibility** :
  - **Public** : Visible par tous (selon config "Require Sign-in")
  - **Private** : Visible uniquement par vous et les collaborateurs
- **Initialize** :
  - **README** : Recommandé (fichier de présentation)
  - **.gitignore** : Selon le langage (Node, Python, Go, etc.)
  - **License** : MIT, GPL, Apache, etc.

3. **Cliquez sur "Create Repository"**

### Cloner le Repository en Local

#### Obtenir l'URL de Clone

Sur la page du repository, vous verrez :

```
┌─────────────────────────────────────────────┐
│  admin / mon-premier-projet           [⭐0] │
├─────────────────────────────────────────────┤
│  📋 Clone                                    │
│  ┌─────────────────────────────────────────┐│
│  │ SSH: git@votre-domaine:222/admin/mon-p...││
│  │ [📋 Copy]                               ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

#### Cloner via SSH

```bash
# Si vous avez configuré ~/.ssh/config avec alias "gitea"
git clone gitea:admin/mon-premier-projet.git

# Ou avec l'URL complète
git clone ssh://git@votre-domaine.com:222/admin/mon-premier-projet.git

# Ou avec IP
git clone ssh://git@192.168.1.100:222/admin/mon-premier-projet.git
```

**Sortie attendue :**
```
Cloning into 'mon-premier-projet'...
remote: Enumerating objects: 3, done.
remote: Counting objects: 100% (3/3), done.
remote: Compressing objects: 100% (2/2), done.
remote: Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
Receiving objects: 100% (3/3), done.
```

### Premier Commit et Push

```bash
# Entrer dans le répertoire
cd mon-premier-projet

# Créer un nouveau fichier
echo "# Mon Premier Projet Gitea" > test.md
echo "Ceci est un test de Gitea sur Raspberry Pi 5" >> test.md

# Voir les changements
git status

# Ajouter le fichier à l'index
git add test.md

# Créer le commit
git commit -m "Ajout du fichier de test"

# Pousser vers Gitea
git push origin main
```

**Sortie attendue du push :**
```
Enumerating objects: 4, done.
Counting objects: 100% (4/4), done.
Delta compression using up to 4 threads
Compressing objects: 100% (2/2), done.
Writing objects: 100% (3/3), 345 bytes | 345.00 KiB/s, done.
Total 3 (delta 0), reused 0 (delta 0), pack-reused 0
remote: . Processing 1 references
remote: Processed 1 references in total
To ssh://votre-domaine.com:222/admin/mon-premier-projet.git
   a1b2c3d..e4f5g6h  main -> main
```

### Vérifier dans l'Interface Web

1. **Rechargez la page du repository** dans votre navigateur
2. **Vous devriez voir** :
   - Le nouveau fichier `test.md`
   - Le commit "Ajout du fichier de test"
   - La date et l'auteur du commit

```
┌─────────────────────────────────────────────┐
│  admin / mon-premier-projet           [⭐0] │
├─────────────────────────────────────────────┤
│  📁 Files                                    │
│                                              │
│  Ajout du fichier de test        2 min ago  │
│  admin                                       │
│                                              │
│  📄 README.md                                │
│  📄 test.md                      ← Nouveau! │
│                                              │
│  2 commits   1 branch   0 tags              │
└─────────────────────────────────────────────┘
```

✅ **Félicitations !** Vous avez créé votre premier repository et effectué votre premier commit.

---

## 6. Étape 5 : Installation du Runner CI/CD

Pour exécuter des workflows automatisés (tests, builds, déploiements), installez le **Gitea Actions Runner**.

### Qu'est-ce qu'un Runner ?

Un **runner** est un service qui :
- Surveille Gitea pour détecter de nouveaux workflows
- Exécute les jobs définis dans les fichiers `.gitea/workflows/*.yml`
- Rapporte les résultats à Gitea

**Analogie :** C'est comme un employé qui attend des tâches et les exécute automatiquement.

### Installation du Runner

#### Mode Interactif (Recommandé)

```bash
# Télécharger et exécuter le script d'installation
curl -fsSL https://raw.githubusercontent.com/username/pi5-setup/main/pi5-gitea-stack/scripts/02-runners-setup.sh | sudo bash
```

Le script vous guidera à travers les étapes :

#### 1. Obtenir le Token d'Enregistrement

Le script vous demandera un **token d'enregistrement** :

```
[RUNNER] To register the runner, you need a registration token from Gitea

Steps to get the token:
  1. Open Gitea in your browser: https://votre-domaine/git
  2. Login as admin
  3. Navigate to: Site Administration > Actions > Runners
     Direct URL: https://votre-domaine/git/admin/actions/runners
  4. Click 'Create new Runner'
  5. Copy the registration token

Enter registration token:
```

**Comment obtenir le token :**

1. **Dans Gitea**, cliquez sur **Site Administration** (icône engrenage)
2. **Dans le menu latéral**, cliquez sur **Actions** → **Runners**
3. **Cliquez sur "Create new Runner"** (bouton vert)
4. **Copiez le token** affiché (40 caractères)

```
┌─────────────────────────────────────────────┐
│  Create New Runner                           │
├─────────────────────────────────────────────┤
│  Registration Token:                         │
│  ┌─────────────────────────────────────────┐│
│  │ a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0││
│  │                                  [Copy] ││
│  └─────────────────────────────────────────┘│
│                                              │
│  This token is valid for 1 hour             │
└─────────────────────────────────────────────┘
```

5. **Collez le token** dans le terminal et appuyez sur **Entrée**

#### 2. Déroulement de l'Installation

```
[RUNNER] Starting Gitea Actions Runner setup...
[RUNNER] Configuration:
  Runner Name: pi5-runner-01
  Max Concurrent Jobs: 2
  Gitea URL: https://votre-domaine/git
  Interactive Mode: yes

[RUNNER] Checking dependencies...
[OK]    All dependencies satisfied

[RUNNER] Detecting system architecture...
[OK]    Architecture: ARM64 (Raspberry Pi 5 compatible)

==> Creating dedicated runner user...
[RUNNER] Creating user gitea-runner...
[OK]    User gitea-runner created
[RUNNER] Adding gitea-runner to docker group...
[OK]    User gitea-runner added to docker group

==> Setting up runner directories...
[RUNNER] Creating directory: /var/lib/gitea-runner
[OK]    Runner directories configured

==> Downloading Act Runner v0.2.10...
[RUNNER] Download URL: https://gitea.com/gitea/act_runner/releases/...
[OK]    Act Runner downloaded to /usr/local/bin/act_runner

==> Generating runner configuration...
[OK]    Runner configuration generated
[RUNNER] Config location: /var/lib/gitea-runner/config.yaml

==> Registering runner with Gitea...
[RUNNER] Registering runner...
  Instance: https://votre-domaine/git
  Name: pi5-runner-01
[OK]    Runner registered successfully

==> Creating systemd service...
[OK]    Systemd service created

==> Enabling and starting runner service...
[RUNNER] Reloading systemd daemon...
[RUNNER] Enabling gitea-runner service...
[RUNNER] Starting gitea-runner service...
[OK]    Gitea runner service is running

==> Verifying runner status...
● gitea-runner.service - Gitea Actions Runner
     Loaded: loaded (/etc/systemd/system/gitea-runner.service; enabled)
     Active: active (running) since ...
[OK]    Runner service is active and running
```

### Mode Automatisé

Pour une installation scriptée (CI/CD, Ansible, etc.) :

```bash
# Définir les variables d'environnement
export RUNNER_TOKEN="a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
export RUNNER_NAME="pi5-runner-01"
export MAX_CONCURRENT_JOBS="2"
export GITEA_URL="https://votre-domaine/git"

# Installation non-interactive
curl -fsSL https://raw.githubusercontent.com/username/pi5-setup/main/pi5-gitea-stack/scripts/02-runners-setup.sh | sudo bash -s -- --non-interactive
```

### Vérifier le Runner dans Gitea

1. **Retournez dans Gitea** → **Site Administration** → **Actions** → **Runners**
2. **Vous devriez voir le runner** :

```
┌─────────────────────────────────────────────┐
│  Runners                                     │
├─────────────────────────────────────────────┤
│  Name          Status  Labels    Last Seen  │
│                                              │
│  pi5-runner-01 🟢 Idle ubuntu... Just now   │
│                       self-hosted            │
│                       arm64                  │
│                       linux                  │
└─────────────────────────────────────────────┘
```

**États possibles :**
- 🟢 **Idle** : Prêt à accepter des jobs (parfait !)
- 🔴 **Offline** : Runner arrêté ou inaccessible
- 🟡 **Running** : Exécution d'un job en cours

### Configuration du Runner

Le fichier de configuration se trouve à :
```
/var/lib/gitea-runner/config.yaml
```

**Contenu (exemple) :**

```yaml
log:
  level: info

runner:
  name: pi5-runner-01
  capacity: 2
  timeout: 3h
  labels:
    - ubuntu-latest:docker://node:16-bullseye
    - self-hosted:host
    - arm64:host
    - linux:host

cache:
  enabled: true
  dir: /var/lib/gitea-runner/cache
  max_size: 5GB

container:
  network: bridge
  privileged: false
  docker_host: unix:///var/run/docker.sock

host:
  workdir_parent: /var/lib/gitea-runner/workspace
```

**Paramètres clés :**
- **capacity** : Nombre de jobs parallèles (2 recommandé pour Pi 5)
- **timeout** : Durée max d'un job (3h par défaut)
- **labels** : Tags pour cibler ce runner dans les workflows
- **cache.max_size** : Taille max du cache (5GB par défaut)

---

## 7. Étape 6 : Premier Workflow

Créons un workflow simple pour tester le runner.

### Qu'est-ce qu'un Workflow ?

Un **workflow** est un fichier YAML qui définit :
- **Quand** exécuter (push, pull request, schedule, etc.)
- **Quoi** exécuter (commandes, tests, builds)
- **Où** exécuter (quel runner utiliser)

**Analogie :** C'est comme une recette de cuisine automatisée que le runner suit étape par étape.

### Structure d'un Workflow

Les workflows sont stockés dans :
```
.gitea/workflows/*.yml
```

**Exemple minimal :**

```yaml
name: Mon Premier Workflow
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Hello World
        run: echo "Hello from Gitea Actions!"
```

### Créer un Workflow de Test

#### 1. Dans Votre Repository Local

```bash
# Aller dans le repository
cd mon-premier-projet

# Créer le répertoire des workflows
mkdir -p .gitea/workflows

# Créer le fichier workflow
nano .gitea/workflows/test.yml
```

#### 2. Ajouter le Contenu du Workflow

Copiez-collez ce workflow de test complet :

```yaml
name: Test CI/CD Pipeline

on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:  # Permet déclenchement manuel

jobs:
  test-runner:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Hello from Gitea Actions
        run: |
          echo "======================================"
          echo "✓ Gitea Actions is working!"
          echo "======================================"
          echo "Runner: ${{ runner.name }}"
          echo "Repository: ${{ github.repository }}"
          echo "Branch: ${{ github.ref_name }}"
          echo "Commit: ${{ github.sha }}"

      - name: Show System Info
        run: |
          echo "=== System Information ==="
          echo "OS: $(uname -s)"
          echo "Architecture: $(uname -m)"
          echo "Kernel: $(uname -r)"
          echo ""
          echo "=== CPU Info ==="
          lscpu | grep -E "Architecture|CPU|Model name" || true
          echo ""
          echo "=== Memory ==="
          free -h

      - name: Test Docker Access
        run: |
          echo "=== Docker Version ==="
          docker --version
          echo ""
          echo "=== Docker Info ==="
          docker info | head -15

      - name: Success Message
        run: |
          echo "======================================"
          echo "✓ All tests passed successfully!"
          echo "✓ CI/CD pipeline is ready!"
          echo "======================================"
```

**Sauvegardez** (`Ctrl+O`, `Entrée`, `Ctrl+X` dans nano).

#### 3. Pousser le Workflow vers Gitea

```bash
# Ajouter les fichiers
git add .gitea/workflows/test.yml

# Créer le commit
git commit -m "Ajout du workflow de test CI/CD"

# Pousser vers Gitea
git push origin main
```

**Sortie attendue :**
```
Enumerating objects: 6, done.
Counting objects: 100% (6/6), done.
Delta compression using up to 4 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (5/5), 678 bytes | 678.00 KiB/s, done.
Total 5 (delta 0), reused 0 (delta 0), pack-reused 0
remote: . Processing 1 references
remote: Processed 1 references in total
To ssh://votre-domaine.com:222/admin/mon-premier-projet.git
   e4f5g6h..i7j8k9l  main -> main
```

### Voir le Workflow en Action

#### Dans l'Interface Gitea

1. **Retournez dans le repository** sur Gitea
2. **Cliquez sur l'onglet "Actions"**
3. **Vous devriez voir le workflow en cours d'exécution** :

```
┌─────────────────────────────────────────────┐
│  Actions                                     │
├─────────────────────────────────────────────┤
│  All Workflows     [Refresh]                 │
│                                              │
│  🔄 Test CI/CD Pipeline                      │
│     #1 · main · Ajout du workflow...         │
│     Started 5 seconds ago                    │
│     🟡 Running                                │
│                                              │
│  Jobs:                                       │
│    🟡 test-runner (in progress)              │
└─────────────────────────────────────────────┘
```

4. **Cliquez sur le workflow** pour voir les détails en temps réel

#### Vue Détaillée du Job

```
┌─────────────────────────────────────────────┐
│  test-runner                                 │
├─────────────────────────────────────────────┤
│  ✓ Set up job              3s                │
│  ✓ Checkout Repository     2s                │
│  🔄 Hello from Gitea Actions (running...)    │
│  ⏸ Show System Info        (queued)          │
│  ⏸ Test Docker Access      (queued)          │
│  ⏸ Success Message         (queued)          │
└─────────────────────────────────────────────┘
```

5. **Une fois terminé** (après ~30 secondes) :

```
┌─────────────────────────────────────────────┐
│  ✓ Test CI/CD Pipeline                       │
│    #1 · main · Ajout du workflow...          │
│    Completed in 42 seconds                   │
│    🟢 Success                                 │
│                                              │
│  Jobs:                                       │
│    ✓ test-runner (42s)                       │
└─────────────────────────────────────────────┘
```

#### Voir les Logs

Cliquez sur une étape pour voir les logs détaillés :

```
▼ Hello from Gitea Actions (2s)
  ======================================
  ✓ Gitea Actions is working!
  ======================================
  Runner: pi5-runner-01
  Repository: admin/mon-premier-projet
  Branch: main
  Commit: i7j8k9l1m2n3o4p5q6r7s8t9u0v1w2x3y4z5a6b7
```

✅ **Félicitations !** Votre premier workflow CI/CD fonctionne !

### Déclencher Manuellement un Workflow

Pour les workflows avec `workflow_dispatch`, vous pouvez les lancer manuellement :

1. **Onglet Actions** du repository
2. **Sélectionnez le workflow** dans la liste
3. **Cliquez sur "Run workflow"** (bouton en haut à droite)
4. **Sélectionnez la branche** (main)
5. **Cliquez sur "Run workflow"** (bouton vert)

### Workflows Plus Avancés

Consultez les exemples dans le repository pour des cas d'usage avancés :

```
pi5-gitea-stack/examples/workflows/
├── hello-world.yml              # Test basique
├── nodejs-app.yml               # Build app Node.js
├── docker-build.yml             # Build et push image Docker
├── supabase-edge-function.yml   # Déployer function Supabase
└── backup-to-rclone.yml         # Backup automatique
```

**Pour les utiliser :**

```bash
# Copier un exemple
cp /chemin/vers/pi5-gitea-stack/examples/workflows/nodejs-app.yml .gitea/workflows/

# Adapter à votre projet
nano .gitea/workflows/nodejs-app.yml

# Commit et push
git add .gitea/workflows/nodejs-app.yml
git commit -m "Ajout workflow Node.js"
git push origin main
```

---

## 8. Étape 7 : Configuration des Secrets

Les **secrets** permettent de stocker des données sensibles (mots de passe, tokens API) de manière sécurisée pour les utiliser dans les workflows.

### Types de Secrets

1. **Repository Secrets** : Spécifiques à un repository
2. **Organization Secrets** : Partagés entre tous les repos d'une organisation

### Ajouter un Secret au Repository

#### Via l'Interface Web

1. **Dans le repository**, cliquez sur **Settings** (icône engrenage)
2. **Dans le menu latéral**, cliquez sur **Secrets**
3. **Cliquez sur "Add Secret"**

```
┌─────────────────────────────────────────────┐
│  Add Secret                                  │
├─────────────────────────────────────────────┤
│  Name: *                                     │
│  ┌─────────────────────────────────────────┐│
│  │ DOCKER_HUB_TOKEN                        ││
│  └─────────────────────────────────────────┘│
│                                              │
│  Value: *                                    │
│  ┌─────────────────────────────────────────┐│
│  │ ****************************************││
│  │                                         ││
│  └─────────────────────────────────────────┘│
│                                              │
│         [Cancel]  [Add Secret]               │
└─────────────────────────────────────────────┘
```

**Règles de nommage :**
- Lettres majuscules, chiffres et underscores seulement
- Exemple : `API_KEY`, `DB_PASSWORD`, `SLACK_WEBHOOK`

4. **Cliquez sur "Add Secret"**

### Utiliser un Secret dans un Workflow

```yaml
name: Deploy with Secrets

on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Login to Docker Hub
        env:
          DOCKER_TOKEN: ${{ secrets.DOCKER_HUB_TOKEN }}
        run: |
          echo "$DOCKER_TOKEN" | docker login -u myuser --password-stdin

      - name: Deploy to Production
        env:
          API_KEY: ${{ secrets.API_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          # Utiliser les variables d'environnement
          curl -H "Authorization: Bearer $API_KEY" https://api.example.com/deploy
```

**⚠️ Sécurité :**
- Les secrets sont **masqués** dans les logs (affichés comme `***`)
- Ne jamais faire `echo $SECRET` directement
- Utiliser `env` pour passer les secrets aux commandes

### Secrets d'Organisation

Pour partager des secrets entre plusieurs repositories :

1. **Site Administration** → **Organizations**
2. **Sélectionnez votre organisation** (ou créez-en une)
3. **Settings** → **Secrets**
4. **Ajoutez les secrets** de la même manière

**Utilisation dans un workflow :**
```yaml
env:
  SHARED_SECRET: ${{ secrets.ORG_SECRET_NAME }}
```

### Exemples de Secrets Courants

```yaml
# Secrets Docker
DOCKER_USERNAME: votre-username
DOCKER_PASSWORD: votre-token-docker-hub

# Secrets Cloud
AWS_ACCESS_KEY_ID: AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Secrets API
SLACK_WEBHOOK: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX
TELEGRAM_BOT_TOKEN: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz

# Secrets Database
DATABASE_URL: postgres://user:pass@host:5432/db
REDIS_URL: redis://user:pass@host:6379

# Secrets SSH
SSH_PRIVATE_KEY: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
  ...
  -----END OPENSSH PRIVATE KEY-----
```

### Workflow avec Secrets Multiples

```yaml
name: Full Stack Deploy

on:
  push:
    branches: [main]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    env:
      DOCKER_USER: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_PASS: ${{ secrets.DOCKER_PASSWORD }}
      DEPLOY_HOST: ${{ secrets.DEPLOY_HOST }}
      DEPLOY_USER: ${{ secrets.DEPLOY_USER }}
      DEPLOY_KEY: ${{ secrets.SSH_PRIVATE_KEY }}

    steps:
      - uses: actions/checkout@v4

      - name: Build Docker Image
        run: |
          echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
          docker build -t myapp:latest .
          docker push myapp:latest

      - name: Deploy to Server
        run: |
          echo "$DEPLOY_KEY" > deploy_key
          chmod 600 deploy_key
          ssh -i deploy_key "$DEPLOY_USER@$DEPLOY_HOST" "docker pull myapp:latest && docker-compose up -d"
          rm deploy_key
```

---

## 9. Étape 8 : (Optionnel) Activer les Packages

Gitea peut héberger des **packages** (Docker images, NPM, Maven, etc.) comme un registry privé.

### Activer le Package Registry

#### Via l'Interface Web

1. **Site Administration** → **Configuration** → **Packages**
2. **Activer** : `Enable Package Registry`
3. **Sauvegarder**

#### Via docker-compose.yml

Si ce n'est pas déjà activé, ajoutez dans votre `docker-compose.yml` :

```yaml
services:
  gitea:
    environment:
      - GITEA__packages__ENABLED=true
```

Puis redémarrez :

```bash
cd /home/pi/stacks/gitea
docker compose up -d
```

### Configurer le Docker Registry

#### 1. Configuration Gitea

Par défaut, Gitea expose le registry Docker sur le même domaine.

**URL du registry :**
- Avec Traefik : `https://votre-domaine/git/api/packages/{owner}/docker`
- Sans Traefik : `http://IP:3000/api/packages/{owner}/docker`

#### 2. Login au Registry Docker

```bash
# Avec domaine
docker login votre-domaine -u admin -p votre-mot-de-passe

# Ou créer un token d'accès (recommandé)
# Settings → Applications → Generate New Token (scopes: package:read, package:write)
docker login votre-domaine -u admin -p <TOKEN>
```

#### 3. Push d'une Image Docker

```bash
# Tag l'image
docker tag mon-image:latest votre-domaine/admin/mon-image:latest

# Push vers Gitea
docker push votre-domaine/admin/mon-image:latest
```

#### 4. Voir le Package dans Gitea

1. **Dans votre profil**, cliquez sur **Packages**
2. **Vous verrez** :

```
┌─────────────────────────────────────────────┐
│  Packages                                    │
├─────────────────────────────────────────────┤
│  🐳 Docker                                   │
│                                              │
│  admin/mon-image                             │
│  latest                                      │
│  Pushed 2 minutes ago                        │
│  Size: 45.2 MB                               │
└─────────────────────────────────────────────┘
```

### Configurer le NPM Registry

#### 1. Configuration NPM

```bash
# Configurer le registry
npm config set registry https://votre-domaine/api/packages/{owner}/npm/

# Login
npm login --registry=https://votre-domaine/api/packages/admin/npm/
```

#### 2. Publier un Package

```bash
# Dans votre projet Node.js
npm publish --registry=https://votre-domaine/api/packages/admin/npm/
```

#### 3. Installer depuis Gitea

```bash
npm install mon-package --registry=https://votre-domaine/api/packages/admin/npm/
```

### Autres Types de Packages Supportés

Gitea supporte également :

- **Maven** (Java)
- **NuGet** (.NET)
- **Composer** (PHP)
- **PyPI** (Python)
- **Cargo** (Rust)
- **Go Modules**
- **Generic** (fichiers binaires)

Consultez la documentation Gitea pour les détails de configuration :
https://docs.gitea.com/usage/packages/overview

---

## 10. Dépannage

### Problème : Git Push Échoue (SSH)

#### Symptômes

```bash
git push origin main
# ssh: connect to host votre-domaine.com port 222: Connection refused
# fatal: Could not read from remote repository.
```

#### Causes Possibles

1. **Port SSH incorrect**
2. **Firewall bloque le port**
3. **Gitea n'est pas démarré**
4. **Configuration SSH incorrecte**

#### Solutions

**Vérifier que Gitea est en cours d'exécution :**

```bash
# Sur le Raspberry Pi
docker ps | grep gitea
```

Devrait afficher :
```
gitea        Up 3 hours   0.0.0.0:222->22/tcp, 0.0.0.0:3000->3000/tcp
```

**Vérifier le port SSH :**

```bash
# Tester la connectivité
telnet votre-domaine.com 222
# ou
nc -zv votre-domaine.com 222
```

**Ouvrir le port dans le firewall :**

```bash
sudo ufw allow 222/tcp
sudo ufw reload
```

**Vérifier la configuration SSH locale :**

```bash
cat ~/.ssh/config
```

Devrait contenir :
```
Host gitea
    HostName votre-domaine.com
    User git
    Port 222
```

**Router/Box Internet :**

Si vous accédez depuis l'extérieur, **redirigez le port 222** dans votre box :
- Connexion : Externe Port 222 → Interne IP-du-Pi:222

### Problème : Workflow Ne Se Déclenche Pas

#### Symptômes

- Push du code réussi
- Aucun workflow ne démarre
- Onglet "Actions" vide

#### Causes Possibles

1. **Gitea Actions désactivé**
2. **Runner offline**
3. **Fichier workflow mal placé**
4. **Erreur de syntaxe YAML**

#### Solutions

**Vérifier que Gitea Actions est activé :**

```bash
# Sur le Raspberry Pi
docker exec gitea cat /data/gitea/conf/app.ini | grep -A 5 '\[actions\]'
```

Devrait afficher :
```
[actions]
ENABLED = true
```

Si `false`, éditez `.env` et changez :
```bash
GITEA_ENABLE_ACTIONS=true
```

Puis redémarrez :
```bash
cd /home/pi/stacks/gitea
docker compose up -d
```

**Vérifier le statut du runner :**

```bash
sudo systemctl status gitea-runner
```

Devrait afficher :
```
● gitea-runner.service - Gitea Actions Runner
     Active: active (running)
```

Si `inactive` :
```bash
sudo systemctl start gitea-runner
```

**Vérifier dans Gitea :**

Site Administration → Actions → Runners

Le runner doit apparaître avec statut **Idle** (vert).

Si **Offline** (rouge) :
```bash
# Voir les logs du runner
sudo journalctl -u gitea-runner -n 50

# Redémarrer le runner
sudo systemctl restart gitea-runner
```

**Vérifier l'emplacement du workflow :**

Le fichier DOIT être dans :
```
.gitea/workflows/nom-du-workflow.yml
```

Pas dans `.github/workflows/` (GitHub) ou `.gitlab-ci.yml` (GitLab).

**Valider la syntaxe YAML :**

```bash
# Installer yamllint si nécessaire
pip install yamllint

# Valider le fichier
yamllint .gitea/workflows/test.yml
```

Ou en ligne : https://www.yamllint.com/

### Problème : Runner Offline

#### Symptômes

Dans Gitea → Actions → Runners :
```
pi5-runner-01   🔴 Offline   Last seen: 10 minutes ago
```

#### Solutions

**Vérifier le service :**

```bash
sudo systemctl status gitea-runner
```

**Voir les logs :**

```bash
sudo journalctl -u gitea-runner -n 100 --no-pager
```

**Erreurs courantes dans les logs :**

**1. "Connection refused"**

Gitea n'est pas accessible. Vérifier :
```bash
docker ps | grep gitea
curl http://localhost:3000
```

**2. "Token invalid"**

Le runner n'est plus enregistré. Re-enregistrer :
```bash
sudo systemctl stop gitea-runner
sudo rm -f /var/lib/gitea-runner/.runner/.runner
sudo -u gitea-runner /usr/local/bin/act_runner register \
  --instance https://votre-domaine/git \
  --token NOUVEAU_TOKEN \
  --name pi5-runner-01 \
  --labels ubuntu-latest,self-hosted,arm64,linux \
  --config /var/lib/gitea-runner/config.yaml \
  --no-interactive
sudo systemctl start gitea-runner
```

**3. "Permission denied" (Docker)**

L'utilisateur gitea-runner n'est pas dans le groupe docker :
```bash
sudo usermod -aG docker gitea-runner
sudo systemctl restart gitea-runner
```

### Problème : Erreurs de Connexion à la Base de Données

#### Symptômes

```bash
docker logs gitea
# Error: database connection failed
# pq: password authentication failed for user "gitea"
```

#### Solutions

**Vérifier que PostgreSQL fonctionne :**

```bash
docker ps | grep gitea-db
```

**Tester la connexion :**

```bash
docker exec gitea-db pg_isready -U gitea
```

Devrait afficher :
```
/var/run/postgresql:5432 - accepting connections
```

**Vérifier le mot de passe :**

```bash
cd /home/pi/stacks/gitea
cat .env | grep POSTGRES_PASSWORD
```

**Redémarrer les conteneurs dans l'ordre :**

```bash
cd /home/pi/stacks/gitea
docker compose down
docker compose up -d gitea-db
# Attendre 10 secondes
sleep 10
docker compose up -d gitea
```

**Si le problème persiste, réinitialiser la base :**

```bash
# ⚠️ ATTENTION : Cela supprime toutes les données!
cd /home/pi/stacks/gitea
docker compose down -v
rm -rf postgres/*
docker compose up -d
```

### Problème : Intégration Traefik Ne Fonctionne Pas

#### Symptômes

- Accès direct par IP fonctionne (`http://IP:3000`)
- Accès par domaine échoue (timeout ou 404)

#### Solutions

**Vérifier que Traefik fonctionne :**

```bash
docker ps | grep traefik
curl http://localhost:8080/api/http/routers
```

**Vérifier les labels Docker :**

```bash
docker inspect gitea | grep -A 20 Labels
```

Devrait contenir :
```json
"traefik.enable": "true",
"traefik.http.routers.gitea.rule": "Host(`votre-domaine.com`) && PathPrefix(`/git`)",
```

**Vérifier le réseau :**

```bash
docker network inspect traefik_network | grep gitea
```

Gitea doit être connecté au réseau `traefik_network`.

**Si absent, reconnecter :**

```bash
docker network connect traefik_network gitea
docker restart traefik
```

**Vérifier les logs Traefik :**

```bash
docker logs traefik | grep gitea
```

**Re-générer la configuration :**

Si nécessaire, relancer le script d'intégration :

```bash
curl -fsSL https://raw.githubusercontent.com/username/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-gitea.sh | sudo bash
```

---

## 11. Commandes de Gestion

### Gestion des Conteneurs

```bash
# Aller dans le répertoire Gitea
cd /home/pi/stacks/gitea

# Voir les logs en temps réel
docker compose logs -f

# Voir les logs de Gitea uniquement
docker compose logs -f gitea

# Voir les logs de PostgreSQL
docker compose logs -f gitea-db

# Redémarrer les services
docker compose restart

# Arrêter les services
docker compose down

# Démarrer les services
docker compose up -d

# Mettre à jour Gitea (télécharge la dernière image)
docker compose pull
docker compose up -d
```

### Gestion du Runner

```bash
# Voir le statut du runner
sudo systemctl status gitea-runner

# Voir les logs en direct
sudo journalctl -u gitea-runner -f

# Voir les 100 dernières lignes de logs
sudo journalctl -u gitea-runner -n 100

# Redémarrer le runner
sudo systemctl restart gitea-runner

# Arrêter le runner
sudo systemctl stop gitea-runner

# Démarrer le runner
sudo systemctl start gitea-runner

# Désactiver le runner au démarrage
sudo systemctl disable gitea-runner

# Activer le runner au démarrage
sudo systemctl enable gitea-runner
```

### Gestion des Utilisateurs Gitea

```bash
# Lister tous les utilisateurs
docker exec gitea gitea admin user list

# Créer un nouvel utilisateur
docker exec gitea gitea admin user create \
  --username nouvel-user \
  --password MotDePasse123 \
  --email user@example.com

# Changer le mot de passe d'un utilisateur
docker exec gitea gitea admin user change-password \
  --username admin \
  --password NouveauMotDePasse123

# Promouvoir un utilisateur en admin
docker exec gitea gitea admin user change-password \
  --username user \
  --admin

# Supprimer un utilisateur
docker exec gitea gitea admin user delete --username user
```

### Sauvegardes

#### Sauvegarde Manuelle

```bash
# Créer le répertoire de backup
cd /home/pi/stacks/gitea
mkdir -p backups

# Backup complet (base de données + données)
DATE=$(date +%Y%m%d_%H%M%S)

# Backup PostgreSQL
docker exec gitea-db pg_dump -U gitea gitea > backups/gitea-db-${DATE}.sql

# Backup des données (repos, uploads, etc.)
sudo tar czf backups/gitea-data-${DATE}.tar.gz data/

# Backup de la configuration
cp .env backups/gitea-env-${DATE}.env
cp docker-compose.yml backups/docker-compose-${DATE}.yml

echo "Backup créé : backups/gitea-backup-${DATE}"
```

#### Restauration

```bash
# Arrêter Gitea
cd /home/pi/stacks/gitea
docker compose down

# Restaurer la base de données
docker compose up -d gitea-db
sleep 10
cat backups/gitea-db-YYYYMMDD_HHMMSS.sql | docker exec -i gitea-db psql -U gitea gitea

# Restaurer les données
rm -rf data/
tar xzf backups/gitea-data-YYYYMMDD_HHMMSS.tar.gz

# Redémarrer
docker compose up -d
```

### Nettoyage

```bash
# Nettoyer les images Docker inutilisées
docker image prune -a

# Nettoyer le cache du runner
sudo rm -rf /var/lib/gitea-runner/cache/*

# Nettoyer les logs anciens
sudo journalctl --vacuum-time=7d

# Nettoyer les workflows anciens (dans Gitea UI)
# Site Administration → Actions → Cleanup
```

### Mise à Jour de Gitea

```bash
cd /home/pi/stacks/gitea

# Sauvegarder avant mise à jour
./scripts/backup.sh  # Si vous avez un script

# Télécharger la dernière version
docker compose pull

# Redémarrer avec la nouvelle version
docker compose up -d

# Vérifier les logs
docker compose logs -f gitea
```

### Surveillance

```bash
# Utilisation des ressources
docker stats gitea gitea-db

# Espace disque
du -sh /home/pi/stacks/gitea/*

# Santé des conteneurs
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Test de santé Gitea
curl -I http://localhost:3000/api/healthz
```

---

## Ressources Supplémentaires

### Documentation Officielle

- **Gitea Documentation** : https://docs.gitea.com/
- **Gitea Actions** : https://docs.gitea.com/usage/actions/overview
- **Act Runner** : https://gitea.com/gitea/act_runner
- **Workflow Syntax** : https://docs.gitea.com/usage/actions/quickstart

### Exemples de Workflows

Consultez les exemples fournis dans :
```
pi5-gitea-stack/examples/workflows/
```

Ou en ligne : https://gitea.com/gitea/act_runner#examples

### Communauté

- **Forum Gitea** : https://discourse.gitea.io/
- **Discord** : https://discord.gg/Gitea
- **GitHub Issues** : https://github.com/go-gitea/gitea/issues

### Guides Complémentaires

- **[Guide Débutant](gitea-guide.md)** : Introduction complète pour débutants
- **README.md** : Vue d'ensemble du stack Gitea
- **ROADMAP.md** : Évolution du projet PI5-SETUP

---

## Conclusion

Vous avez maintenant un serveur Git complet avec CI/CD sur Raspberry Pi 5 !

**Ce que vous pouvez faire maintenant :**

✅ Héberger vos projets Git en privé
✅ Collaborer avec d'autres développeurs
✅ Automatiser tests et déploiements via CI/CD
✅ Publier des packages (Docker, NPM, etc.)
✅ Intégrer avec d'autres services (Slack, Discord, etc.)

**Prochaines étapes suggérées :**

1. **Créer une organisation** pour regrouper vos projets
2. **Configurer des webhooks** pour notifier d'autres services
3. **Explorer les workflows avancés** (tests, builds multi-arch, déploiements)
4. **Ajouter des collaborateurs** et gérer les permissions
5. **Intégrer avec votre IDE** (VS Code, IntelliJ, etc.)

**Besoin d'aide ?**

- Consultez la section [Dépannage](#10-dépannage)
- Vérifiez les logs : `docker compose logs -f`
- Demandez sur le forum Gitea : https://discourse.gitea.io/

Bon développement ! 🚀
