# 📦 Installation Pi5-Backup-Offsite-Stack

> **Guide détaillé d'installation des sauvegardes offsite avec rclone pour Raspberry Pi 5**

---

## 📋 Table des Matières

- [Prérequis](#-prérequis)
- [Étape 1 : Créer un Compte Cloud](#-étape-1--créer-un-compte-cloud)
- [Étape 2 : Obtenir les Credentials API](#-étape-2--obtenir-les-credentials-api)
- [Étape 3 : Installer et Configurer rclone](#-étape-3--installer-et-configurer-rclone)
- [Étape 4 : Activer les Sauvegardes Offsite](#-étape-4--activer-les-sauvegardes-offsite)
- [Étape 5 : Vérifier la Configuration](#-étape-5--vérifier-la-configuration)
- [Étape 6 : Tester la Restauration](#-étape-6--tester-la-restauration)
- [Dépannage](#-dépannage)
- [Prochaines Étapes](#-prochaines-étapes)

---

## ✅ Prérequis

### Matériel et Logiciels

- **Raspberry Pi 5** avec au moins une stack installée :
  - ✅ **Supabase** (recommandé - données critiques)
  - ✅ **Gitea** (optionnel - code source)
  - ✅ **Nextcloud** (optionnel - fichiers utilisateurs)
- **Connexion Internet** stable
- **Docker** et **Docker Compose** installés

### Compte Fournisseur Cloud

**Choisir UN des fournisseurs suivants** :

| Fournisseur | Coût | Stockage Inclus | Avantages |
|-------------|------|-----------------|-----------|
| **Cloudflare R2** ⭐ | **Gratuit** 10GB | 10GB/mois | Zéro frais sortie, rapide, S3-compatible |
| **Backblaze B2** | **10GB gratuit** | 10GB puis 0.005$/GB | Économique, fiable |
| **AWS S3** | Variable | Pay-as-you-go | Robuste mais coûteux |
| **Disque Local** | Gratuit | Illimité (disque externe) | Offline, aucun cloud |

**💡 Recommandation** : **Cloudflare R2** pour la plupart des utilisateurs (gratuit jusqu'à 10GB, pas de frais de sortie)

---

## 🌩️ Étape 1 : Créer un Compte Cloud

### Option A : Cloudflare R2 (Recommandé)

#### 1.1 Créer un Compte Cloudflare

1. Aller sur [dash.cloudflare.com](https://dash.cloudflare.com/sign-up)
2. **Créer un compte** :
   - Email : votre@email.com
   - Mot de passe : (sécurisé, min. 8 caractères)
   - Cliquer **Sign Up**
3. **Vérifier l'email** (cliquer lien dans inbox)

#### 1.2 Activer R2

1. **Se connecter** sur [dash.cloudflare.com](https://dash.cloudflare.com)
2. Dans le menu de gauche → **R2 Object Storage**
3. **Cliquer "Purchase R2 Plan"** :
   - Plan : **Free** (10GB inclus)
   - Confirmer
4. **Attendre activation** (~30 secondes)

#### 1.3 Créer un Bucket

1. Dans **R2** → Cliquer **Create bucket**
2. **Nom du bucket** : `pi5-backups` (minuscules, pas d'espaces)
3. **Location** : Automatic (ou choisir région proche)
4. **Cliquer Create bucket**

**✅ Résultat** : Bucket `pi5-backups` créé et visible dans la liste

---

### Option B : Backblaze B2

#### 1.1 Créer un Compte B2

1. Aller sur [backblaze.com/b2/sign-up](https://www.backblaze.com/b2/sign-up.html)
2. **Remplir formulaire** :
   - Email, mot de passe
   - Cliquer **Sign Up**
3. **Vérifier email** et confirmer compte

#### 1.2 Créer un Bucket

1. **Se connecter** sur [secure.backblaze.com](https://secure.backblaze.com/user_signin.htm)
2. Menu **Buckets** → **Create a Bucket**
3. **Configuration** :
   - Bucket Name : `pi5-backups`
   - Files in Bucket : **Private**
   - Default Encryption : **Disable** (rclone gérera)
4. **Cliquer Create a Bucket**

**✅ Résultat** : Bucket créé, noter le **Bucket ID** affiché

---

### Option C : Disque Local (Offline)

**Pour tester ou backup local uniquement** :

1. **Brancher disque externe USB** (recommandé : USB 3.0, min. 64GB)
2. **Vérifier montage** :
   ```bash
   lsblk
   # Exemple sortie :
   # sda           8:0    0 119.2G  0 disk
   # └─sda1        8:1    0 119.2G  0 part /media/pi/backup-disk
   ```

3. **Créer répertoire backup** :
   ```bash
   sudo mkdir -p /media/pi/backup-disk/pi5-backups
   sudo chown -R pi:pi /media/pi/backup-disk/pi5-backups
   ```

**✅ Résultat** : Répertoire `/media/pi/backup-disk/pi5-backups` prêt

---

## 🔑 Étape 2 : Obtenir les Credentials API

### Option A : Cloudflare R2

#### 2.1 Créer un API Token

1. Dans **Cloudflare Dashboard** → **R2** → onglet **Manage R2 API Tokens**
2. **Cliquer "Create API Token"**
3. **Configuration** :
   - **Token name** : `pi5-rclone`
   - **Permissions** :
     - ✅ Object Read & Write
   - **TTL** : Forever (ou définir expiration)
   - **Specify bucket(s)** : Sélectionner `pi5-backups`
4. **Cliquer "Create API Token"**

#### 2.2 Copier les Credentials

**L'écran affiche** :

```
Access Key ID:     a1b2c3d4e5f6g7h8i9j0
Secret Access Key: X1Y2Z3A4B5C6D7E8F9G0H1I2J3K4L5M6N7O8P9Q0
```

**⚠️ IMPORTANT** :
- **Copier et sauvegarder** ces valeurs immédiatement
- Le **Secret Key** ne sera plus affiché après fermeture
- Stocker dans gestionnaire de mots de passe sécurisé

#### 2.3 Trouver l'Account ID

1. Dans **Cloudflare Dashboard** → **R2** → onglet **Overview**
2. **Copier "Account ID"** (ex: `abcdef1234567890`)
3. **Copier "Jurisdiction"** endpoint (ex: `https://abcdef1234567890.r2.cloudflarestorage.com`)

**✅ Résultat** : Vous avez 3 valeurs :
- ✅ Access Key ID
- ✅ Secret Access Key
- ✅ Account ID

---

### Option B : Backblaze B2

#### 2.1 Créer Application Key

1. Dans **Backblaze** → **App Keys** (menu gauche)
2. **Cliquer "Add a New Application Key"**
3. **Configuration** :
   - **Name** : `pi5-rclone`
   - **Allow access to Bucket(s)** : Sélectionner `pi5-backups`
   - **Type of Access** : Read and Write
   - **Allow List All Bucket Names** : ✅ (cocher)
4. **Cliquer "Create New Key"**

#### 2.2 Copier les Credentials

**L'écran affiche** :

```
keyID:              0015a1b2c3d4e5f6000000001
applicationKey:     K0015pZqXYZ123456789abcdefghijklm
```

**⚠️ IMPORTANT** : Copier immédiatement, ne sera plus affiché !

**✅ Résultat** : Vous avez 2 valeurs :
- ✅ keyID (Account ID)
- ✅ applicationKey (Application Key)

---

### Bonnes Pratiques Sécurité

**Pour TOUS les fournisseurs** :

1. ✅ **Privilège minimum** : Ne donner que permissions nécessaires (Read/Write sur bucket spécifique)
2. ✅ **Rotation régulière** : Changer API keys tous les 90 jours
3. ✅ **Stockage sécurisé** : Utiliser gestionnaire de mots de passe (Bitwarden, 1Password, KeePassXC)
4. ✅ **Pas de commit Git** : Ne jamais committer les credentials dans Git
5. ✅ **Monitoring** : Activer alertes d'usage anormal dans dashboard cloud

---

## 🔧 Étape 3 : Installer et Configurer rclone

### 3.1 Installation Interactive (Recommandé)

**Copier-coller dans terminal SSH** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash
```

**Ou avec wget** :

```bash
wget -qO- https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash
```

**Durée** : ~5-10 minutes

---

### 3.2 Walkthrough Mode Interactif

**Le script va demander** :

#### A) Choix du Fournisseur

```
[RCLONE] Choisissez votre provider de stockage cloud :

1) Cloudflare R2 (recommandé - gratuit 10GB)
2) Backblaze B2 (10GB gratuit)
3) AWS S3 / Compatible
4) Disque local (offline)

Entrez le numéro [1-4]:
```

**Taper** : `1` (pour R2) puis **Enter**

---

#### B) Cloudflare R2 - Configuration

```
[RCLONE] Configuration Cloudflare R2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Cloudflare R2 Account ID (ex: abcdef1234567890) :
```

**Coller** : Votre Account ID (Ctrl+V) puis **Enter**

```
R2 Access Key ID (ex: a1b2c3d4...) :
```

**Coller** : Votre Access Key ID puis **Enter**

```
R2 Secret Access Key (masqué) :
```

**Coller** : Votre Secret Key (ne s'affiche pas - normal) puis **Enter**

```
R2 Bucket Name (ex: pi5-backups) :
```

**Taper** : `pi5-backups` puis **Enter**

```
Nom du remote rclone [offsite-backup] :
```

**Taper** : `r2` (ou laisser défaut) puis **Enter**

---

#### C) Test de Connexion

```
[RCLONE] Test de connexion au remote "r2"...

✓ Connexion réussie !
✓ Bucket "pi5-backups" accessible
✓ Test d'écriture OK (fichier test créé)
✓ Test de lecture OK (fichier test lu)
✓ Test de suppression OK (fichier test supprimé)

[SUCCESS] Configuration rclone terminée !
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📁 Config : /home/pi/.config/rclone/rclone.conf
🔍 Remote : r2
🪣 Bucket : pi5-backups
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**✅ Résultat** : rclone configuré et testé avec succès !

---

### 3.3 Mode Automatisé (Variables d'Environnement)

**Pour Cloudflare R2** :

```bash
sudo R2_ACCOUNT_ID=abcdef1234567890 \
     R2_ACCESS_KEY=a1b2c3d4e5f6g7h8i9j0 \
     R2_SECRET_KEY=X1Y2Z3A4B5C6D7E8F9G0H1I2J3K4L5M6 \
     R2_BUCKET=pi5-backups \
     REMOTE_NAME=r2 \
     RCLONE_PROVIDER=r2 \
     ASSUME_YES=1 \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh)
```

**Pour Backblaze B2** :

```bash
sudo B2_ACCOUNT_ID=0015a1b2c3d4e5f6000000001 \
     B2_APPLICATION_KEY=K0015pZqXYZ123456789abcdefghijklm \
     B2_BUCKET=pi5-backups \
     REMOTE_NAME=b2 \
     RCLONE_PROVIDER=b2 \
     ASSUME_YES=1 \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh)
```

---

### 3.4 Vérifier Configuration rclone

```bash
# Lister les remotes configurés
rclone listremotes
# Sortie : r2:

# Lister contenu bucket
rclone lsd r2:pi5-backups
# Sortie : (vide pour l'instant)

# Afficher config (masque secrets)
rclone config show r2
```

**✅ Si pas d'erreur** → rclone configuré correctement !

---

## 💾 Étape 4 : Activer les Sauvegardes Offsite

### 4.1 Lancer le Script d'Activation

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash
```

**Durée** : ~3-5 minutes

---

### 4.2 Walkthrough Mode Interactif

#### A) Détection des Stacks

```
[INFO] Détection des stacks installées...

✓ supabase trouvé : /home/pi/stacks/supabase
✓ gitea trouvé : /home/pi/stacks/gitea

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stacks disponibles :
  1) supabase (2.3 GB)
  2) gitea (850 MB)
  3) all (configurer toutes les stacks)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Quelle stack voulez-vous sauvegarder offsite ? [1-3]:
```

**Taper** : `1` (pour Supabase) puis **Enter**

---

#### B) Configuration du Remote

```
[INFO] Configuration backup offsite pour : supabase

Remotes rclone disponibles :
  - r2

Remote à utiliser (ex: r2:pi5-backups/supabase) :
```

**Taper** : `r2:pi5-backups/supabase` puis **Enter**

**💡 Format** : `<remote>:<bucket>/<path>`
- `r2` : nom du remote configuré à l'étape 3
- `pi5-backups` : nom du bucket
- `supabase` : sous-répertoire (organisé par stack)

---

#### C) Confirmation et Application

```
[INFO] Configuration à appliquer :

Stack       : supabase
Remote      : r2:pi5-backups/supabase
Scheduler   : /etc/systemd/system/pi5-supabase-backup.service
Script      : /home/pi/stacks/supabase/scripts/maintenance/supabase-backup.sh

Voulez-vous continuer ? [y/N]:
```

**Taper** : `y` puis **Enter**

---

#### D) Modification et Test

```
[INFO] Modification du script de backup...

✓ Ajout configuration rclone
✓ Ajout upload automatique après backup local
✓ Ajout nettoyage offsite (rotation 7 jours)

[INFO] Test de backup...

[BACKUP] Création backup Supabase...
✓ PostgreSQL dump créé (1.2 GB)
✓ Volumes Docker archivés (950 MB)
✓ Archive créée : /backups/supabase-20251004-153022.tar.gz (2.1 GB)

[OFFSITE] Upload vers r2:pi5-backups/supabase...
Transferred:        2.150 GiB / 2.150 GiB, 100%, 45 MiB/s, ETA 0s
✓ Upload terminé en 48s

[SUCCESS] Backup offsite configuré avec succès !

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📦 Stack         : supabase
🌐 Remote        : r2:pi5-backups/supabase
📅 Fréquence     : Quotidienne (2h du matin)
🔄 Rétention     : 7 jours local, 30 jours offsite
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Prochain backup programmé : demain 02:00
```

**✅ Résultat** : Sauvegardes offsite activées pour Supabase !

---

### 4.3 Mode Automatisé

**Configuration Supabase vers R2** :

```bash
sudo SELECTED_STACK=supabase \
     RCLONE_REMOTE=r2:pi5-backups/supabase \
     TEST_BACKUP=yes \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh) --yes
```

**Configuration toutes les stacks** :

```bash
sudo SELECTED_STACK=all \
     RCLONE_REMOTE=r2:pi5-backups \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh) --yes
```

---

## ✅ Étape 5 : Vérifier la Configuration

### 5.1 Lister Fichiers sur le Remote

```bash
# Lister tous les fichiers dans le bucket
rclone ls r2:pi5-backups

# Sortie exemple :
# 2147483648 supabase/supabase-20251004-153022.tar.gz
#  890123456 gitea/gitea-20251004-160045.tar.gz
```

**Commandes utiles** :

```bash
# Lister avec dates
rclone ls r2:pi5-backups/supabase -vv

# Lister hiérarchie
rclone tree r2:pi5-backups

# Tailles des répertoires
rclone size r2:pi5-backups
# Total objects: 2
# Total size: 2.9 GiB
```

---

### 5.2 Vérifier Taille des Fichiers

```bash
# Vérifier backup spécifique
rclone lsl r2:pi5-backups/supabase/supabase-20251004-153022.tar.gz

# Sortie :
# 2147483648 2025-10-04 15:30:22.000000000 supabase-20251004-153022.tar.gz
```

**Comparer avec backup local** :

```bash
ls -lh /backups/supabase-20251004-153022.tar.gz
# -rw-r--r-- 1 pi pi 2.1G Oct  4 15:30 supabase-20251004-153022.tar.gz
```

**✅ Les tailles doivent correspondre !**

---

### 5.3 Vérifier Encryption (Si Activée)

**Si vous avez activé le chiffrement rclone** :

```bash
# Télécharger fichier test
rclone copy r2:pi5-backups/supabase/supabase-20251004-153022.tar.gz /tmp/test-download/

# Vérifier que c'est une archive valide
tar -tzf /tmp/test-download/supabase-20251004-153022.tar.gz | head -5

# Sortie :
# postgres-dump/
# postgres-dump/supabase.sql
# volumes/
# volumes/storage/
# ...
```

**Si encryption activée**, fichier sera automatiquement déchiffré par rclone.

---

### 5.4 Tester Téléchargement Complet

```bash
# Télécharger backup complet
mkdir -p ~/test-restore
rclone copy r2:pi5-backups/supabase/supabase-20251004-153022.tar.gz ~/test-restore/ -P

# Vérifier intégrité
tar -tzf ~/test-restore/supabase-20251004-153022.tar.gz > /dev/null

# Si aucune erreur :
echo "✅ Archive intègre !"

# Nettoyer
rm -rf ~/test-restore
```

---

### 5.5 Vérifier Rotation Automatique

```bash
# Lister backups avec dates (plus ancien → plus récent)
rclone ls r2:pi5-backups/supabase --max-age 30d

# Vérifier qu'il n'y a pas de fichiers > 30 jours
# (la rotation devrait les avoir supprimés)
```

---

## 🔄 Étape 6 : Tester la Restauration

### 6.1 Dry-Run (Simulation)

**Recommandé avant première restauration réelle** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo RCLONE_REMOTE=r2:pi5-backups/supabase bash -s -- --dry-run --list-only
```

**Sortie** :

```
[INFO] Listing backups disponibles sur r2:pi5-backups/supabase

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# | Fichier                              | Taille  | Date
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1 | supabase-20251004-153022.tar.gz      | 2.1 GB  | 2025-10-04 15:30
2 | supabase-20251003-020015.tar.gz      | 2.0 GB  | 2025-10-03 02:00
3 | supabase-20251002-020010.tar.gz      | 1.9 GB  | 2025-10-02 02:00
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[DRY-RUN] Aucune restauration effectuée (mode --list-only)
```

---

### 6.2 Simuler Restauration Complète

```bash
sudo RCLONE_REMOTE=r2:pi5-backups/supabase \
     BACKUP_FILE=supabase-20251004-153022.tar.gz \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh) --dry-run --yes
```

**Sortie** :

```
[INFO] Mode DRY-RUN : Aucune modification ne sera effectuée

[1/8] Téléchargement backup...
[DRY-RUN] rclone copy r2:pi5-backups/supabase/supabase-20251004-153022.tar.gz /tmp/offsite-restore/

[2/8] Vérification intégrité...
[DRY-RUN] tar -tzf /tmp/offsite-restore/supabase-20251004-153022.tar.gz

[3/8] Création backup de sécurité...
[DRY-RUN] /home/pi/stacks/supabase/scripts/maintenance/supabase-backup.sh

[4/8] Arrêt services...
[DRY-RUN] docker compose -f /home/pi/stacks/supabase/docker-compose.yml down

[5/8] Restauration PostgreSQL...
[DRY-RUN] docker exec supabase-db psql -U postgres -f /tmp/postgres-restore.sql

[6/8] Restauration volumes Docker...
[DRY-RUN] tar -xzf /tmp/offsite-restore/supabase-20251004-153022.tar.gz -C /home/pi/stacks/supabase/

[7/8] Redémarrage services...
[DRY-RUN] docker compose -f /home/pi/stacks/supabase/docker-compose.yml up -d

[8/8] Healthcheck...
[DRY-RUN] /home/pi/stacks/supabase/scripts/maintenance/supabase-healthcheck.sh

[SUCCESS] DRY-RUN terminé sans erreurs !
```

**✅ Si aucune erreur** → Procédure de restauration OK !

---

### 6.3 Test Restauration Réelle (Environnement Test)

**⚠️ DANGER : Ne pas faire sur production sans backup !**

**Créer environnement test** :

```bash
# Cloner stack Supabase
sudo mkdir -p /home/pi/stacks/supabase-test
sudo cp -r /home/pi/stacks/supabase/* /home/pi/stacks/supabase-test/

# Modifier ports (éviter conflits)
cd /home/pi/stacks/supabase-test
sudo nano docker-compose.yml
# Changer 3000 → 3001, 8000 → 8001, 5432 → 5433, etc.

# Démarrer
sudo docker compose up -d
```

**Tester restauration** :

```bash
sudo RCLONE_REMOTE=r2:pi5-backups/supabase \
     BACKUP_FILE=supabase-20251004-153022.tar.gz \
     COMPOSE_DIR=/home/pi/stacks/supabase-test \
     SERVICE_NAME=supabase-test \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh) --yes
```

**Vérifier** :

```bash
# Vérifier services
cd /home/pi/stacks/supabase-test
docker compose ps
# Tous doivent être "Up"

# Tester accès Studio
curl -I http://localhost:3001
# HTTP/1.1 200 OK

# Tester données restaurées
docker exec supabase-test-db psql -U postgres -c "SELECT COUNT(*) FROM auth.users;"
```

**Nettoyer** :

```bash
cd /home/pi/stacks/supabase-test
sudo docker compose down -v
sudo rm -rf /home/pi/stacks/supabase-test
```

---

### 6.4 Documenter la Procédure

**Créer documentation de restauration** :

```bash
cat > ~/RESTORE-PROCEDURE.md << 'EOF'
# Procédure de Restauration d'Urgence

## En cas de perte de données Supabase

### 1. Lister backups disponibles
```bash
rclone ls r2:pi5-backups/supabase
```

### 2. Choisir backup à restaurer
```bash
BACKUP_FILE=supabase-YYYYMMDD-HHMMSS.tar.gz
```

### 3. Restaurer (AUTOMATIQUE)
```bash
sudo RCLONE_REMOTE=r2:pi5-backups/supabase \
     BACKUP_FILE=$BACKUP_FILE \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh) --yes
```

### 4. Vérifier services
```bash
cd ~/stacks/supabase
docker compose ps
```

### 5. Tester accès
```
http://raspberrypi.local:3000
```

## Contacts d'Urgence
- Admin : votre@email.com
- Support Pi5-Setup : https://github.com/iamaketechnology/pi5-setup/issues
EOF
```

**✅ Résultat** : Documentation de restauration prête !

---

## 🆘 Dépannage

### Problème 1 : "Remote not found"

**Erreur** :

```
Failed to create file system for "r2:pi5-backups": didn't find section in config file
```

**Cause** : Remote rclone non configuré

**Solution** :

```bash
# Vérifier remotes
rclone listremotes
# Si vide → Relancer Étape 3

# Vérifier config
cat ~/.config/rclone/rclone.conf
# Doit contenir [r2]
```

---

### Problème 2 : "Access Denied"

**Erreur** :

```
ERROR : Failed to copy: AccessDenied: Access Denied
```

**Causes possibles** :

1. **Credentials invalides** :
   ```bash
   # Re-tester connexion
   rclone lsd r2:pi5-backups -vv
   ```

2. **Permissions insuffisantes** :
   - Vérifier dans dashboard cloud que API key a permissions Read/Write
   - Recréer API key avec bonnes permissions

3. **Bucket inexistant** :
   ```bash
   # Vérifier bucket
   rclone lsd r2:
   # Doit lister "pi5-backups"
   ```

---

### Problème 3 : Upload Très Lent

**Symptôme** : Upload < 1 MB/s

**Solutions** :

1. **Vérifier bande passante** :
   ```bash
   # Test vitesse upload
   rclone check /backups/ r2:pi5-backups/supabase --one-way -P
   ```

2. **Activer multi-threading** :
   ```bash
   # Éditer script backup
   nano ~/stacks/supabase/scripts/maintenance/supabase-backup.sh

   # Modifier ligne rclone copy :
   rclone copy --transfers=8 --checkers=16 ...
   ```

3. **Compresser davantage** :
   ```bash
   # Utiliser compression maximale
   tar -czf - ... | pigz -9 > backup.tar.gz
   ```

---

### Problème 4 : Quota Dépassé

**Erreur** :

```
ERROR : Failed to copy: QuotaExceeded: You have exceeded your storage quota
```

**Solutions** :

1. **Vérifier usage** :
   ```bash
   rclone size r2:pi5-backups
   ```

2. **Réduire rétention offsite** :
   ```bash
   # Éditer script
   nano ~/stacks/supabase/scripts/maintenance/supabase-backup.sh

   # Changer :
   rclone delete r2:pi5-backups/supabase --min-age 15d  # Au lieu de 30d
   ```

3. **Nettoyer vieux backups** :
   ```bash
   # Supprimer backups > 7 jours
   rclone delete r2:pi5-backups/supabase --min-age 7d --dry-run
   # Si OK :
   rclone delete r2:pi5-backups/supabase --min-age 7d
   ```

4. **Upgrader plan cloud** (si nécessaire)

---

### Problème 5 : Restauration Échoue

**Erreur** :

```
[ERROR] Failed to restore PostgreSQL: psql: FATAL: password authentication failed
```

**Causes possibles** :

1. **Mauvais DSN PostgreSQL** :
   ```bash
   # Vérifier mot de passe
   grep POSTGRES_PASSWORD ~/stacks/supabase/.env

   # Tester connexion
   docker exec supabase-db psql -U postgres -c "SELECT version();"
   ```

2. **Services pas arrêtés** :
   ```bash
   # Arrêter manuellement
   cd ~/stacks/supabase
   docker compose down

   # Re-tester restauration
   ```

3. **Archive corrompue** :
   ```bash
   # Vérifier intégrité
   tar -tzf /tmp/offsite-restore/supabase-*.tar.gz > /dev/null

   # Si erreur → Télécharger à nouveau
   rclone copy r2:pi5-backups/supabase/supabase-*.tar.gz /tmp/test/ --checksum
   ```

---

### Problème 6 : Backup Pas Uploadé

**Symptôme** : Backup créé localement mais pas sur cloud

**Vérifier logs** :

```bash
# Logs systemd
sudo journalctl -u pi5-supabase-backup.service -n 50

# Logs script
tail -f /var/log/supabase-backup-*.log
```

**Causes courantes** :

1. **Remote non configuré dans script** :
   ```bash
   grep rclone ~/stacks/supabase/scripts/maintenance/supabase-backup.sh
   # Doit contenir ligne "rclone copy"
   ```

2. **Erreur réseau temporaire** :
   ```bash
   # Tester upload manuel
   rclone copy /backups/supabase-latest.tar.gz r2:pi5-backups/supabase/ -P
   ```

3. **Re-exécuter Étape 4** :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash
   ```

---

## 📚 Prochaines Étapes

### 1. Automatiser Monitoring

**Créer alerte si backup échoue** :

```bash
# Créer script vérification
cat > ~/check-offsite-backups.sh << 'EOF'
#!/bin/bash
LAST_BACKUP=$(rclone lsl r2:pi5-backups/supabase | tail -1 | awk '{print $2, $3}')
LAST_BACKUP_DATE=$(date -d "$LAST_BACKUP" +%s)
NOW=$(date +%s)
DIFF=$(( ($NOW - $LAST_BACKUP_DATE) / 86400 ))

if [ $DIFF -gt 2 ]; then
  echo "⚠️ WARNING: Dernier backup offsite : il y a $DIFF jours !" | mail -s "ALERTE Backup" votre@email.com
fi
EOF

chmod +x ~/check-offsite-backups.sh

# Ajouter cron (tous les jours à 8h)
crontab -e
# 0 8 * * * /home/pi/check-offsite-backups.sh
```

---

### 2. Configurer Notifications

**Installer ntfy pour notifications push** :

```bash
# Installer ntfy
curl -sSL https://ntfy.sh/install.sh | sudo bash

# Modifier script backup pour notifier
nano ~/stacks/supabase/scripts/maintenance/supabase-backup.sh

# Ajouter après upload :
curl -d "Backup Supabase uploadé : $BACKUP_FILE" https://ntfy.sh/votre-topic-secret
```

---

### 3. Tester Restauration Régulièrement

**Créer rappel mensuel** :

```bash
# Ajouter dans crontab
crontab -e

# Tester restauration 1er de chaque mois à 3h
0 3 1 * * /home/pi/test-restore-monthly.sh

# Créer script test
cat > ~/test-restore-monthly.sh << 'EOF'
#!/bin/bash
LOG=/var/log/restore-test-$(date +\%Y\%m).log

echo "=== Test Restauration $(date) ===" >> $LOG

# Dry-run restauration
sudo RCLONE_REMOTE=r2:pi5-backups/supabase \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh) \
     --dry-run --yes 2>&1 | tee -a $LOG

# Notifier
curl -d "Test restauration OK" https://ntfy.sh/votre-topic-secret
EOF

chmod +x ~/test-restore-monthly.sh
```

---

### 4. Documentation Équipe

**Créer guide pour collègues** :

1. Partager `~/RESTORE-PROCEDURE.md`
2. Documenter credentials (KeePass partagé)
3. Créer runbook incidents
4. Former admin backup

---

### 5. Améliorer Sécurité

**Activer encryption rclone** :

```bash
# Re-configurer remote avec encryption
rclone config

# Choisir "Add encryption"
# Définir password
# Tous les fichiers uploadés seront chiffrés
```

**Activer versioning bucket** (si provider supporte) :

- **Cloudflare R2** : Activer dans dashboard (bientôt disponible)
- **Backblaze B2** : Lifecycle Settings → Keep all versions
- **AWS S3** : Enable Versioning

---

### 6. Multi-Cloud Backup (Redondance)

**Synchroniser vers 2ème cloud** :

```bash
# Configurer 2ème remote (ex: B2)
rclone config
# Créer remote "b2-backup"

# Synchroniser R2 → B2
rclone sync r2:pi5-backups b2-backup:pi5-backups-mirror -P

# Automatiser (cron quotidien)
crontab -e
# 0 4 * * * rclone sync r2:pi5-backups b2-backup:pi5-backups-mirror
```

---

## 🔗 Documentation Complémentaire

- **[README.md](README.md)** - Vue d'ensemble stack backups offsite
- **[Guide Débutant](restic-offsite-guide.md)** - Guide pédagogique rclone
- **[ROADMAP.md](../ROADMAP.md)** - Plan global Pi5-Setup
- **[rclone Documentation](https://rclone.org/docs/)** - Documentation officielle rclone
- **[Cloudflare R2 Docs](https://developers.cloudflare.com/r2/)** - Documentation R2
- **[Backblaze B2 Docs](https://www.backblaze.com/b2/docs/)** - Documentation B2

---

<p align="center">
  <strong>☁️ Sauvegardes Offsite Configurées ! ☁️</strong>
</p>

<p align="center">
  <sub>Protection contre sinistre • Restauration automatisée • Production-ready</sub>
</p>
