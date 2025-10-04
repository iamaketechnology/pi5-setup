# ☁️ Pi5 Backup Offsite Stack - Cloud Backup Automation

> **Sauvegardes automatiques cryptées vers le cloud - Protection contre les sinistres**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%205-red.svg)](https://www.raspberrypi.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)

---

## 📖 Table des Matières

- [Vue d'Ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Installation Rapide](#-installation-rapide)
- [Providers Supportés](#-providers-supportés)
- [Architecture](#-architecture)
- [Scripts](#-scripts)
- [Scénarios d'Utilisation](#-scénarios-dutilisation)
- [Configuration](#-configuration)
- [Maintenance](#-maintenance)
- [Documentation](#-documentation)
- [Contribution](#-contribution)
- [Licence](#-licence)

---

## 🎯 Vue d'Ensemble

**Pi5-Backup-Offsite-Stack** est une solution complète de sauvegarde cloud pour Raspberry Pi 5, basée sur **rclone**, permettant de répliquer automatiquement vos backups locaux vers des stockages cloud externes (R2, B2, S3, NAS).

### Pourquoi ce Stack ?

- ✅ **Complète les backups locaux** - S'intègre avec le système GFS existant (04-backup-rotate.sh)
- ✅ **Aucune modification requise** - Fonctionne avec vos scripts de backup actuels
- ✅ **Multi-providers** - Supporte R2, B2, S3, stockage local/NAS
- ✅ **Tier gratuit disponible** - 10GB gratuits chez R2 et B2
- ✅ **Chiffrement supporté** - Backups cryptés avec rclone crypt
- ✅ **Rotation automatique** - Hérite du système GFS (7 jours / 4 semaines / 6 mois)
- ✅ **Disaster recovery testé** - Scripts de restauration inclus
- ✅ **Installation en 3 étapes** - Configuration guidée interactive

### Que Sauvegarde-t-on ?

Le stack offsite **réplique** les backups locaux créés par `common-scripts/04-backup-rotate.sh` :

| Contenu | Source | Destination Cloud |
|---------|--------|-------------------|
| **PostgreSQL dumps** | `/opt/backups/*.tar.gz` | `remote:pi5-backups/` |
| **Volumes Docker** | Inclus dans tar.gz | Idem |
| **Configs (.env)** | Inclus dans tar.gz | Idem |
| **Rotation GFS** | Appliquée localement | Synchronisée vers cloud |

**Fréquence** : Quotidienne (via cron/systemd timer), après backup local

---

## 🚀 Fonctionnalités

### Core Features

- 📤 **Upload automatique** - Copie les backups locaux vers cloud après création
- 🔄 **Synchronisation GFS** - Rotation cloud suit rotation locale (7/4/6)
- 🔐 **Chiffrement rclone** - Cryptage AES-256 transparent (optionnel)
- 🌐 **Multi-cloud** - R2, B2, S3, Wasabi, local disk/NAS
- ⚡ **Bandwidth throttling** - Limite bande passante (ne sature pas connexion)
- 📊 **Logs détaillés** - Journaux d'upload vers `/var/log/`
- 🧪 **Dry-run mode** - Test sans upload réel
- 🔙 **Restauration guidée** - Script interactif de récupération

### Intégration avec Backups Locaux

**Le système actuel** (`common-scripts/04-backup-rotate.sh`) :
```bash
# Déjà en place - pas de modification
1. Dump PostgreSQL
2. Archive volumes Docker
3. Compression .tar.gz
4. Rotation GFS locale
```

**Ce que ajoute ce stack** (optionnel, activé après config) :
```bash
5. Upload automatique vers cloud (si RCLONE_REMOTE défini)
6. Rotation cloud (synchronisée)
```

**Activation** :
```bash
# Dans votre wrapper de backup Supabase
export RCLONE_REMOTE="offsite-backup:pi5-backups"
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh
```

---

## ⚡ Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec **backups locaux déjà configurés** ([Phase 1](../pi5-supabase-stack/))
- ✅ Connexion Internet stable
- ✅ Compte cloud provider (R2/B2/S3) OU disque local/USB/NAS
- ✅ Credentials API (access key, secret key)

### Installation en 3 Étapes

#### 1️⃣ Configurer rclone Remote

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash
```

**Ce que fait ce script** :
- ✅ Installe rclone (si absent)
- ✅ Configuration interactive du remote
- ✅ Test de connexion avec upload/download
- ✅ Configuration chiffrement (optionnel)
- ✅ Génère fichier `~/.config/rclone/rclone.conf`

**Durée** : 5-15 minutes (selon provider)

#### 2️⃣ Activer Backups Offsite

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash
```

**Ce que fait ce script** :
- ✅ Détecte stacks installées (Supabase, Traefik, etc.)
- ✅ Ajoute `RCLONE_REMOTE` aux wrappers de backup
- ✅ Configure cron/timer pour upload post-backup
- ✅ Effectue premier backup de test
- ✅ Affiche configuration finale

**Durée** : 2-3 minutes

#### 3️⃣ Tester Restauration (Recommandé)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo bash
```

**Ce que fait ce script** :
- ✅ Liste backups disponibles sur cloud
- ✅ Télécharge backup sélectionné
- ✅ Vérifie intégrité (checksum)
- ✅ Extrait et restaure (optionnel)
- ✅ Guide étape par étape

**Durée** : 5-10 minutes (selon taille backup)

---

## 📦 Providers Supportés

### Comparaison des Providers

| Provider | Free Tier | Prix Stockage | Prix Téléchargement | Performance | Facilité | Recommandation |
|----------|-----------|---------------|---------------------|-------------|----------|----------------|
| **Cloudflare R2** | 10 GB | $0.015/GB/mois | **Gratuit** | Excellent (CDN mondial) | Facile (S3-compatible) | ⭐⭐⭐ **Best overall** |
| **Backblaze B2** | 10 GB | $0.005/GB/mois | $0.01/GB (1GB gratuit/jour) | Bon | Facile (API native rclone) | ⭐⭐ **Cheapest storage** |
| **AWS S3** | 5 GB (12 mois) | $0.023/GB/mois | $0.09/GB | Excellent | Moyen (config IAM) | ⭐ Production avec budget |
| **S3-compatible** | Varie | Varie | Varie | Varie | Moyen | Pour utilisateurs avancés |
| **Local Disk/USB** | Illimité | $0 (coût matériel) | $0 | Excellent (LAN) | Très facile | ⭐⭐⭐ **Testing/NAS** |

### Détails par Provider

#### 🟦 Cloudflare R2 (Recommandé)

**Avantages** :
- ✅ **Pas de frais d'egress** (téléchargement gratuit)
- ✅ 10 GB gratuits/mois
- ✅ API S3-compatible (rclone intégré)
- ✅ Performance CDN mondiale
- ✅ Dashboard Cloudflare simple

**Coût** (exemple 50 GB backups) :
```
Stockage: 40 GB × $0.015 = $0.60/mois
Egress:   Illimité × $0    = $0
Total:    ~$0.60/mois (~7€/an)
```

**Setup** :
1. Créer compte Cloudflare (gratuit)
2. R2 > Create bucket > Générer API token
3. Lancer `01-rclone-setup.sh`, choisir "Cloudflare R2"

#### 🟧 Backblaze B2

**Avantages** :
- ✅ Stockage le moins cher ($0.005/GB)
- ✅ 10 GB gratuits/mois
- ✅ 1 GB egress gratuit/jour
- ✅ API native rclone

**Coût** (exemple 50 GB backups) :
```
Stockage: 40 GB × $0.005 = $0.20/mois
Egress:   ~1 GB/mois × $0.01 = $0.01/mois (sous quota gratuit)
Total:    ~$0.21/mois (~2.50€/an)
```

**Setup** :
1. Créer compte B2 (gratuit)
2. Buckets > Create > App Keys > Generate
3. Lancer `01-rclone-setup.sh`, choisir "Backblaze B2"

#### ⚙️ S3-Compatible (Wasabi, MinIO, etc.)

**Avantages** :
- ✅ Flexibilité provider
- ✅ Self-hosted possible (MinIO)
- ✅ Pas de lock-in

**Setup** :
- Lancer `01-rclone-setup.sh`, choisir "S3-compatible"
- Fournir endpoint, access key, secret key

#### 💾 Local Disk/USB/NAS

**Avantages** :
- ✅ 100% gratuit (après achat disque)
- ✅ Pas de limite quota
- ✅ Performance LAN excellente
- ✅ Contrôle total

**Use cases** :
- Backup vers NAS Synology/QNAP
- Disque USB externe
- Partition dédiée
- Répertoire réseau (SMB/NFS)

**Setup** :
- Lancer `01-rclone-setup.sh`, choisir "Local Disk"
- Fournir chemin (ex: `/mnt/usb-backups` ou `/mnt/nas/pi5-backups`)

---

## 🏗️ Architecture

### Flux de Backup Complet

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. BACKUP LOCAL (04-backup-rotate.sh)                          │
│                                                                  │
│  ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐   │
│  │ PostgreSQL  │───→│ Dump + Compress│───→│ /opt/backups/   │   │
│  │   (DB)      │    │   (tar.gz)     │    │ pi5-YYYYMMDD.gz │   │
│  └─────────────┘    └──────────────┘    └─────────────────┘   │
│                                                    │             │
│  ┌─────────────┐                                   │             │
│  │Docker Volumes│──────────────────────────────────┘             │
│  │ (data)      │                                                 │
│  └─────────────┘                                                 │
│                                                                  │
│  ↓                                                               │
│                                                                  │
│  ┌──────────────────────────────────────────────┐              │
│  │ Rotation GFS (local)                          │              │
│  │ - Daily: 7 derniers jours                     │              │
│  │ - Weekly: 4 dernières semaines                │              │
│  │ - Monthly: 6 derniers mois                    │              │
│  └──────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                           │
                           │ (si RCLONE_REMOTE défini)
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. UPLOAD OFFSITE (rclone copy)                                │
│                                                                  │
│  /opt/backups/*.tar.gz ──→ rclone ──→ Cloud Provider           │
│                                                                  │
│  Options:                        ┌────────────────────┐        │
│  - Bandwidth limit               │ Cloudflare R2      │        │
│  - Encryption (crypt)            │ Backblaze B2       │        │
│  - Retry/Resume                  │ AWS S3             │        │
│  - Checksum verify               │ Local Disk/NAS     │        │
│                                  └────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                           │
                           ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. ROTATION CLOUD (synchronisée)                               │
│                                                                  │
│  remote:pi5-backups/                                            │
│  ├── pi5-20251004.tar.gz  (Daily)                              │
│  ├── pi5-20251003.tar.gz  (Daily)                              │
│  ├── pi5-20250927.tar.gz  (Weekly)                             │
│  └── pi5-20250901.tar.gz  (Monthly)                            │
│                                                                  │
│  Rotation suit GFS local (7/4/6)                               │
└─────────────────────────────────────────────────────────────────┘
```

### Intégration avec Stacks Existantes

```
pi5-supabase-stack/
├── scripts/maintenance/
│   └── supabase-backup.sh          # Wrapper existant
│       ├── Source: _supabase-common.sh
│       ├── Exec: ../../common-scripts/04-backup-rotate.sh
│       └── Variables:
│           ├── POSTGRES_DSN=...
│           ├── DATA_PATHS=...
│           └── RCLONE_REMOTE=offsite-backup:pi5-backups  ← Ajouté
│
common-scripts/
└── 04-backup-rotate.sh              # Script de backup
    ├── Crée backup local
    ├── Applique rotation GFS
    └── Si RCLONE_REMOTE défini:
        └── Upload automatique        ← Extension offsite
```

**Aucune modification du code** - L'upload offsite est **optionnel** via variable d'environnement.

---

## 📜 Scripts

### 01-rclone-setup.sh

**Objectif** : Configuration initiale du remote rclone

**Fonctionnalités** :
- 🔧 Installation rclone (si absent)
- ⚙️ Configuration interactive par provider
- 🔐 Setup chiffrement (optionnel)
- ✅ Test connexion (upload/download/delete)
- 📝 Génère `~/.config/rclone/rclone.conf`

**Usage** :
```bash
# Installation standard
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash

# Avec variables d'environnement (non-interactif)
sudo RCLONE_PROVIDER=r2 \
     R2_ACCOUNT_ID=xxx \
     R2_ACCESS_KEY=xxx \
     R2_SECRET_KEY=xxx \
     R2_BUCKET=pi5-backups \
     ./01-rclone-setup.sh --yes
```

**Providers supportés** :
1. Cloudflare R2
2. Backblaze B2
3. S3-compatible (AWS, Wasabi, MinIO)
4. Local Disk/USB/NAS

**Output** :
```
✅ rclone installé (v1.64.0)
✅ Remote "offsite-backup" configuré (Cloudflare R2)
✅ Test upload: OK (125ms)
✅ Test download: OK (89ms)
✅ Test delete: OK
✅ Configuration sauvegardée: /home/pi/.config/rclone/rclone.conf

Prochaine étape:
  sudo ./02-enable-offsite-backups.sh
```

---

### 02-enable-offsite-backups.sh

**Objectif** : Activer backups offsite pour stacks installées

**Fonctionnalités** :
- 🔍 Détecte stacks avec backups (Supabase, Traefik, etc.)
- 📝 Ajoute `RCLONE_REMOTE` aux wrappers
- ⏰ Configure cron/timer (optionnel)
- 🧪 Premier backup de test
- 📊 Résumé configuration

**Usage** :
```bash
# Activation automatique
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash

# Dry-run (simulation)
sudo ./02-enable-offsite-backups.sh --dry-run

# Spécifier remote personnalisé
sudo RCLONE_REMOTE=my-backup:custom-path ./02-enable-offsite-backups.sh
```

**Détection stacks** :
```bash
if [[ -f ~/stacks/supabase/docker-compose.yml ]]; then
  # Ajoute RCLONE_REMOTE à supabase-backup.sh
fi

if [[ -f ~/stacks/traefik/docker-compose.yml ]]; then
  # Ajoute RCLONE_REMOTE à traefik-backup.sh
fi
```

**Modification wrapper** (exemple Supabase) :
```bash
# Avant
export POSTGRES_DSN="postgresql://..."
export DATA_PATHS="/home/pi/stacks/supabase/volumes"

# Après (ligne ajoutée)
export POSTGRES_DSN="postgresql://..."
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
export RCLONE_REMOTE="offsite-backup:pi5-backups"  ← AJOUTÉ
```

**Output** :
```
✅ Stack détectée: Supabase (/home/pi/stacks/supabase)
✅ RCLONE_REMOTE ajouté: offsite-backup:pi5-backups
✅ Premier backup test: OK (250 MB uploadé en 45s)
✅ Configuration offsite active

Backups automatiques:
  Local:   /opt/backups/ (rotation 7/4/6)
  Offsite: offsite-backup:pi5-backups/ (synchronisé)

Tester restauration:
  sudo ./03-restore-from-offsite.sh
```

---

### 03-restore-from-offsite.sh

**Objectif** : Restauration guidée depuis cloud

**Fonctionnalités** :
- 📋 Liste backups disponibles (cloud)
- 📥 Téléchargement sélectif
- ✅ Vérification intégrité (checksum)
- 🔄 Extraction et restauration
- 🛡️ Backup pré-restauration (sécurité)

**Usage** :
```bash
# Restauration interactive
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo bash

# Restauration non-interactive
sudo RESTORE_BACKUP=pi5-20251004.tar.gz \
     RESTORE_TARGET=/home/pi/stacks/supabase \
     ./03-restore-from-offsite.sh --yes
```

**Flux interactif** :
```
1. Liste backups cloud
   → pi5-20251004.tar.gz (250 MB) - Il y a 1 jour
   → pi5-20251003.tar.gz (248 MB) - Il y a 2 jours
   → pi5-20250927.tar.gz (245 MB) - Il y a 1 semaine

2. Sélection backup
   Backup à restaurer: [1] ▊

3. Téléchargement
   ✅ pi5-20251004.tar.gz téléchargé (250 MB en 32s)
   ✅ Checksum vérifié: OK

4. Extraction
   Contenu:
   - postgres.sql (180 MB)
   - volumes/auth/ (25 MB)
   - volumes/storage/ (45 MB)

5. Restauration
   ⚠️  Backup actuel sauvegardé: /opt/backups/pre-restore-20251005.tar.gz
   ✅ PostgreSQL restauré
   ✅ Volumes Docker restaurés
   ✅ Services redémarrés

✅ Restauration complète
```

**Options** :
- `--list-only` : Affiche backups sans restaurer
- `--download-only` : Télécharge sans restaurer
- `--dry-run` : Simulation

---

## 🎯 Scénarios d'Utilisation

### 1. Disaster Recovery (Sinistre Complet)

**Problème** : Raspberry Pi détruit (incendie, vol, carte SD corrompue)

**Solution** :
```bash
# Sur nouveau Raspberry Pi 5
1. Installer OS + Docker
   curl ... 01-prerequisites-setup.sh | sudo bash && sudo reboot

2. Configurer rclone avec même remote
   curl ... 01-rclone-setup.sh | sudo bash
   # Utiliser mêmes credentials R2/B2

3. Restaurer dernier backup
   curl ... 03-restore-from-offsite.sh | sudo bash
   # Sélectionner backup le plus récent

4. Redéployer stacks
   curl ... 02-supabase-deploy.sh | sudo bash
   # Les données sont déjà restaurées

✅ Serveur opérationnel en ~1h
```

**Données récupérées** :
- ✅ PostgreSQL complet (utilisateurs, tables, auth)
- ✅ Storage files (avatars, uploads)
- ✅ Configurations (.env, secrets)
- ✅ Certificats SSL (si backupés)

---

### 2. Migration vers Nouveau Pi

**Problème** : Upgrade Pi 4 → Pi 5 ou changement hardware

**Solution** :
```bash
# Sur ancien Pi (Pi 4)
1. Backup final
   sudo ~/stacks/supabase/scripts/maintenance/supabase-backup.sh
   # Upload automatique vers cloud

2. Vérifier upload
   rclone ls offsite-backup:pi5-backups

# Sur nouveau Pi (Pi 5)
1. Installation base
   curl ... 01-prerequisites-setup.sh | sudo bash

2. Restaurer config rclone
   curl ... 01-rclone-setup.sh | sudo bash

3. Restaurer données
   curl ... 03-restore-from-offsite.sh | sudo bash

4. Redéployer
   curl ... 02-supabase-deploy.sh | sudo bash

✅ Migration complète
```

---

### 3. Test de Restauration Régulier

**Problème** : Vérifier que backups sont valides

**Solution** (tous les mois) :
```bash
# Test sur environnement staging
1. Créer VM/conteneur test
   docker run -it ubuntu:22.04 /bin/bash

2. Installer rclone
   curl ... 01-rclone-setup.sh | sudo bash

3. Télécharger backup aléatoire
   sudo ./03-restore-from-offsite.sh --download-only

4. Vérifier intégrité
   tar -tzf pi5-20251004.tar.gz
   # Lister contenu sans extraire

5. Test extraction
   tar -xzf pi5-20251004.tar.gz -C /tmp/test
   ls -lah /tmp/test

✅ Backup valide
```

---

### 4. Backup Multi-Sites

**Problème** : Plusieurs Raspberry Pi à sauvegarder

**Solution** :
```bash
# Pi 1 (maison)
BACKUP_NAME_PREFIX=pi-home
RCLONE_REMOTE=offsite-backup:backups/home

# Pi 2 (bureau)
BACKUP_NAME_PREFIX=pi-office
RCLONE_REMOTE=offsite-backup:backups/office

# Pi 3 (parents)
BACKUP_NAME_PREFIX=pi-parents
RCLONE_REMOTE=offsite-backup:backups/parents

# Structure cloud:
offsite-backup:backups/
├── home/
│   ├── pi-home-20251004.tar.gz
│   └── pi-home-20251003.tar.gz
├── office/
│   ├── pi-office-20251004.tar.gz
│   └── pi-office-20251003.tar.gz
└── parents/
    ├── pi-parents-20251004.tar.gz
    └── pi-parents-20251003.tar.gz
```

---

## ⚙️ Configuration

### Variables d'Environnement

**Fichier** : Ajoutées aux wrappers de backup (ex: `supabase-backup.sh`)

| Variable | Défaut | Description |
|----------|--------|-------------|
| `RCLONE_REMOTE` | - | Remote rclone (format: `remote:path`) |
| `RCLONE_BANDWIDTH_LIMIT` | - | Limite upload (ex: `10M` = 10 MB/s) |
| `RCLONE_TRANSFERS` | `4` | Nombre de transferts parallèles |
| `RCLONE_CHECKERS` | `8` | Nombre de checksums parallèles |
| `BACKUP_TARGET_DIR` | `/opt/backups` | Répertoire backups locaux |
| `BACKUP_NAME_PREFIX` | `pi5` | Préfixe nom fichiers |

### Configuration rclone Avancée

**Fichier** : `~/.config/rclone/rclone.conf`

#### Exemple R2 avec Chiffrement

```ini
[offsite-backup]
type = s3
provider = Cloudflare
access_key_id = xxx
secret_access_key = xxx
endpoint = https://xxx.r2.cloudflarestorage.com
acl = private

[offsite-backup-crypt]
type = crypt
remote = offsite-backup:pi5-backups-encrypted
password = xxx  # rclone obscure
password2 = xxx # salt
```

**Utilisation** :
```bash
# Upload crypté
export RCLONE_REMOTE="offsite-backup-crypt:"
sudo ./scripts/maintenance/supabase-backup.sh
```

#### Limite Bande Passante

**Problème** : Upload sature connexion Internet

**Solution** :
```bash
# Wrapper backup
export RCLONE_BANDWIDTH_LIMIT="5M"  # 5 MB/s max
export RCLONE_REMOTE="offsite-backup:pi5-backups"
```

Ou dans `rclone.conf` :
```ini
[offsite-backup]
type = s3
...
bandwidth_limit = 10M  # Global limit
```

### Personnalisation Upload

**Script** : `02-enable-offsite-backups.sh`

**Options** :
```bash
# Changer remote par défaut
sudo RCLONE_REMOTE=backup-r2:custom-bucket ./02-enable-offsite-backups.sh

# Activer pour stack spécifique uniquement
sudo ENABLE_SUPABASE=1 ENABLE_TRAEFIK=0 ./02-enable-offsite-backups.sh

# Configurer retention cloud différente
sudo RCLONE_KEEP_DAILY=14 \
     RCLONE_KEEP_WEEKLY=8 \
     RCLONE_KEEP_MONTHLY=12 \
     ./02-enable-offsite-backups.sh
```

---

## 🛠️ Maintenance

### Vérifier Backups Cloud

```bash
# Lister backups
rclone ls offsite-backup:pi5-backups

# Avec tailles
rclone size offsite-backup:pi5-backups

# Avec détails
rclone lsl offsite-backup:pi5-backups | sort -k2,2
```

**Output** :
```
262144000 2025/10/04 02:15:23 pi5-20251004-021523.tar.gz
260046848 2025/10/03 02:15:18 pi5-20251003-021518.tar.gz
258048000 2025/09/27 02:15:12 pi5-20250927-021512.tar.gz
```

### Tester Connexion Remote

```bash
# Test upload
echo "test" | rclone rcat offsite-backup:test.txt

# Test download
rclone cat offsite-backup:test.txt

# Test delete
rclone delete offsite-backup:test.txt

# Vérifier suppression
rclone ls offsite-backup:
```

### Nettoyer Anciens Backups Cloud

**La rotation GFS s'applique automatiquement**, mais pour forcer :

```bash
# Dry-run (simulation)
rclone delete offsite-backup:pi5-backups \
  --min-age 90d \
  --dry-run \
  --verbose

# Suppression réelle (>90 jours)
rclone delete offsite-backup:pi5-backups \
  --min-age 90d
```

### Monitoring Upload

**Logs** : `/var/log/backup-rotate-*.log`

```bash
# Derniers uploads
grep "Upload rclone" /var/log/backup-rotate-*.log | tail -20

# Erreurs upload
grep -i "error" /var/log/backup-rotate-*.log | grep -i rclone

# Stats upload
grep "Transferred:" /var/log/backup-rotate-*.log | tail -5
```

**Output** :
```
2025-10-04 02:16:45 Upload rclone -> offsite-backup:pi5-backups
2025-10-04 02:17:32 Transferred: 250.000 MB / 250.000 MB, 100%, 5.555 MB/s, ETA 0s
```

### Troubleshooting Upload Échoué

**Problème** : Backup local OK, upload échoué

**Diagnostic** :
```bash
# Test manuel
rclone copy /opt/backups/pi5-latest.tar.gz offsite-backup:pi5-backups/ \
  --verbose \
  --progress

# Vérifier credentials
rclone config show offsite-backup

# Test bandwidth
rclone test bandwidth offsite-backup:test-bandwidth
```

**Solutions** :
1. **Credentials expirés** : Régénérer API key, relancer `01-rclone-setup.sh`
2. **Quota dépassé** : Vérifier usage cloud, augmenter plan
3. **Réseau instable** : Activer `--retries 10` dans rclone config
4. **Bucket supprimé** : Recréer bucket, mettre à jour config

---

## 📚 Documentation

### Guides Disponibles

- **Installation** : Ce README (section Installation Rapide)
- **Scripts** : Ce README (section Scripts détaillée)
- **Troubleshooting** : [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- **Best Practices** : [docs/BEST-PRACTICES.md](docs/BEST-PRACTICES.md)

### Documentation Externe

- **[rclone Docs](https://rclone.org/docs/)** - Documentation officielle
- **[Cloudflare R2 Docs](https://developers.cloudflare.com/r2/)** - Setup R2
- **[Backblaze B2 Docs](https://www.backblaze.com/b2/docs/)** - Setup B2
- **[AWS S3 Docs](https://docs.aws.amazon.com/s3/)** - Setup S3

### Ressources Communautaires

- **[r/rclone](https://reddit.com/r/rclone)** - Communauté rclone
- **[rclone Forum](https://forum.rclone.org/)** - Support officiel
- **[Pi5-Setup Discussions](https://github.com/iamaketechnology/pi5-setup/discussions)** - Questions projet

---

## 🔄 Fréquence Recommandée

### Backups Quotidiens (Production)

**Configuration** :
```bash
# Cron (méthode 1)
0 2 * * * /home/pi/stacks/supabase/scripts/maintenance/supabase-backup.sh

# Systemd timer (méthode 2, recommandée)
sudo systemctl enable --now supabase-backup.timer
```

**Rotation automatique** :
- Daily: 7 derniers jours (local + cloud)
- Weekly: 4 dernières semaines (local + cloud)
- Monthly: 6 derniers mois (local + cloud)

### Tests Restauration

**Fréquence recommandée** :
- 🔵 **Mensuel** : Test téléchargement + vérification intégrité
- 🟢 **Trimestriel** : Restauration complète sur environnement test
- 🔴 **Annuel** : Disaster recovery drill (Pi neuf)

**Checklist test** :
- [ ] Télécharger backup cloud
- [ ] Vérifier checksum
- [ ] Extraire contenu
- [ ] Vérifier fichiers critiques présents
- [ ] (Optionnel) Restaurer sur staging
- [ ] Documenter résultats

---

## 🔐 Sécurité

### Bonnes Pratiques

✅ **Recommandé** :
- Activer chiffrement rclone (crypt) pour données sensibles
- Utiliser API keys avec permissions minimales (write-only pour upload)
- Rotation credentials tous les 90 jours
- Vérifier intégrité backups régulièrement (checksums)
- Tester restauration trimestriellement

✅ **Avancé** :
- 2FA sur comptes cloud (R2, B2)
- Bucket versioning (récupérer fichiers supprimés)
- Object Lock (protection suppression accidentelle)
- Logs d'accès cloud (audit trail)

❌ **À éviter** :
- Stocker credentials en clair (utiliser `rclone obscure`)
- Utiliser root credentials (créer service accounts)
- Désactiver SSL/TLS
- Backups non testés (syndrome Schrödinger)

### Chiffrement Données

**Méthode 1** : rclone crypt (transparent)
```bash
# Configuration lors du 01-rclone-setup.sh
Would you like to encrypt backups? [y/N]: y
Enter encryption password: ****
Enter salt password: ****

✅ Remote "offsite-backup-crypt" créé
```

**Méthode 2** : Chiffrement pré-upload (GPG)
```bash
# Dans wrapper backup
tar -czf - . | gpg -c --batch --passphrase-file /root/.backup-key > backup.tar.gz.gpg
rclone copy backup.tar.gz.gpg offsite-backup:encrypted/
```

---

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](../CONTRIBUTING.md).

### Ajouter Support Nouveau Provider

1. Fork repo
2. Modifier `01-rclone-setup.sh` :
   ```bash
   case "${RCLONE_PROVIDER}" in
     ...
     "nouveau-provider")
       configure_nouveau_provider
       ;;
   esac
   ```
3. Ajouter doc dans README (section Providers)
4. Tester sur Pi 5 ARM64
5. Submit PR

---

## 📄 Licence

MIT License - Voir [LICENSE](../LICENSE)

---

## 🎯 Prochaines Étapes

Après configuration backups offsite :

1. ✅ **Tester restauration** → `./03-restore-from-offsite.sh`
2. ✅ **Configurer monitoring** → [Phase 3 Monitoring](../pi5-monitoring-stack/)
3. ✅ **Planifier DR drills** → Tests trimestriels
4. ✅ **Documenter procédure** → Runbook équipe

---

<p align="center">
  <strong>☁️ Vos données sont en sécurité, même en cas de sinistre ☁️</strong>
</p>

<p align="center">
  <sub>Backups testés • Restauration prouvée • Disaster Recovery Ready</sub>
</p>
