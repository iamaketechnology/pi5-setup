# 📚 Guide Débutant - Backups Offsite (Sauvegardes Cloud)

> **Pour qui ?** Débutants en sauvegardes automatiques et stockage cloud
> **Durée de lecture** : 20 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est Quoi les Backups Offsite ?

### En une phrase
**Backups Offsite = Envoyer automatiquement des copies de tes données importantes dans un coffre-fort numérique situé ailleurs que chez toi.**

### Analogie simple

Imagine que tu as des **documents importants** (photos de famille, papiers administratifs, etc.).

**Backup Local** (ce que tu as déjà) :
```
Documents originaux → Photocopies dans le même bâtiment
📄 Bureau principal   → 📋 Armoire de secours (même maison)

Si le bâtiment brûle ? 🔥
→ Tu perds TOUT (original + copies)
```

**Backup Offsite** (ce qu'on va installer) :
```
Documents originaux → Copies dans un coffre-fort à la banque
📄 Bureau principal   → 🏦 Coffre-fort en ville

Si ta maison brûle ? 🔥
→ Original perdu, mais copies en sécurité à la banque ✅
```

**En informatique** :
- **Backup local** : Copie sur le Pi (carte SD, disque USB branché)
- **Backup offsite** : Copie dans le cloud (Cloudflare, Backblaze, etc.)

**C'est comme** :
- Avoir une clé de secours chez un voisin (backup local)
- ET une clé chez tes parents dans une autre ville (backup offsite)

---

## 🚨 Pourquoi C'est Important ?

### Scénarios où le backup local ne suffit PAS

#### 1. 💧 **Dégât des eaux**
```
Problème : Fuite d'eau, inondation
→ Raspberry Pi HS
→ Disque USB de backup HS
→ Tout est perdu 😱

Avec backup offsite :
→ Pi et backup local détruits
→ Mais copies saines dans le cloud ✅
→ Tu récupères tout !
```

#### 2. 🔥 **Incendie**
```
Problème : Incendie électrique
→ Pi et tous les disques fondus
→ Années de données perdues

Avec backup offsite :
→ Données en sécurité ailleurs
→ Tu achètes un nouveau Pi
→ Tu restaures tout en 1h ✅
```

#### 3. 🦹 **Vol / Cambriolage**
```
Problème : Vol du Pi + disques de backup
→ Données ET matériel volés
→ Aucun moyen de récupérer

Avec backup offsite :
→ Le voleur a le matériel
→ Mais TES données sont dans le cloud
→ Tu restaures sur un nouveau Pi ✅
```

#### 4. 💾 **Corruption de carte SD**
```
Problème : Carte SD défectueuse (très courant sur Pi)
→ Pi ne démarre plus
→ Backup local inaccessible (sur la SD)

Avec backup offsite :
→ Nouvelle carte SD
→ Restauration depuis le cloud
→ Retour en ligne en 2h ✅
```

#### 5. ⚡ **Surtension électrique**
```
Problème : Orage, surtension
→ Pi + disques USB grillés

Avec backup offsite :
→ Cloud non affecté
→ Tu remplaces le matériel
→ Tu récupères tes données ✅
```

### La Règle 3-2-1 (Standard Professionnel)

**Toutes les entreprises suivent cette règle** :

```
3 = Trois copies de tes données
    ├─ 1 copie originale (ton Pi en production)
    ├─ 1 copie locale (backup sur disque USB)
    └─ 1 copie offsite (backup dans le cloud)

2 = Sur deux supports différents
    ├─ Carte SD (original)
    └─ Cloud (backup offsite)

1 = Une copie hors site (offsite)
    └─ Stockage cloud (Cloudflare, Backblaze, etc.)
```

**Exemple concret avec Supabase** :
```
Original  : Base de données Supabase sur ton Pi (carte SD)
Backup 1  : Dump SQL quotidien dans ~/backups/ (même Pi)
Backup 2  : Copie automatique dans Cloudflare R2 (cloud) ✅
```

---

## 💰 Combien Ça Coûte ?

### Comparaison des Fournisseurs Cloud

| Fournisseur | Gratuit | Payant | Avantages | Inconvénients |
|-------------|---------|--------|-----------|---------------|
| **🟠 Cloudflare R2** | 10 GB | $0.015/GB/mois | ✅ Pas de frais de sortie<br>✅ Réseau mondial<br>✅ S3-compatible | ❌ Carte bancaire requise |
| **🔵 Backblaze B2** | 10 GB | $0.006/GB/mois | ✅ Le moins cher<br>✅ Fiable depuis 2015<br>✅ S3-compatible | ❌ Frais de téléchargement |
| **💾 Disque USB Local** | Illimité | Prix du disque | ✅ Rapide<br>✅ Pas d'internet requis<br>✅ Pour tester | ❌ PAS un vrai offsite<br>❌ Vulnérable aux sinistres |

### 💡 Calcul pour un Pi typique

**Exemple de données à sauvegarder** :
```
Supabase (base de données)   : 2 GB
Gitea (dépôts Git)            : 3 GB
Nextcloud (fichiers)          : 5 GB
-------------------------------------------
Total                         : 10 GB
```

**Coût mensuel** :
- **Cloudflare R2** : 0€ (dans le tier gratuit 10 GB) 🎉
- **Backblaze B2** : 0€ (dans le tier gratuit 10 GB) 🎉

**Si tu dépasses 10 GB (exemple : 50 GB)** :
- **Cloudflare R2** : (50 - 10) × $0.015 = **$0.60/mois** (50 centimes !)
- **Backblaze B2** : (50 - 10) × $0.006 = **$0.24/mois** (20 centimes !)

**C'est moins cher qu'un café ☕ par mois !**

---

## ☁️ Les Fournisseurs de Stockage Cloud

### 🟠 Cloudflare R2 (Recommandé pour débutants)

**C'est quoi ?** Un service de stockage S3-compatible de Cloudflare (entreprise sécurisant 20% d'Internet).

**Pourquoi c'est bien ?**
- ✅ **Pas de frais de sortie** : Tu peux télécharger tes backups gratuitement (les autres facturent)
- ✅ **Réseau mondial** : Tes backups sont répliqués automatiquement dans plusieurs pays
- ✅ **10 GB gratuits** : Parfait pour démarrer
- ✅ **Interface simple** : Dashboard clair pour débutants

**Pourquoi c'est moins bien ?**
- ❌ **Carte bancaire requise** : Même pour le tier gratuit (mais tu ne seras pas facturé si < 10 GB)

**Idéal si** :
- Tu veux la solution la plus moderne et rapide
- Tu as une carte bancaire à donner (zéro débit si < 10 GB)
- Tu veux restaurer souvent (pas de frais de téléchargement)

**Création compte (5 min)** :
1. Va sur [cloudflare.com](https://cloudflare.com) → Inscription gratuite
2. Vérifie ton email
3. Va dans "R2" (menu gauche)
4. "Create Bucket" → Nom : `pi5-backups`
5. "Manage R2 API Tokens" → "Create API Token"
6. Note bien : **Account ID**, **Access Key**, **Secret Key** (tu en auras besoin)

---

### 🔵 Backblaze B2 (Le moins cher)

**C'est quoi ?** Un service de stockage cloud spécialisé dans les backups depuis 2015.

**Pourquoi c'est bien ?**
- ✅ **Le moins cher** : $0.006/GB/mois (moitié prix de R2 au-delà du gratuit)
- ✅ **Fiable** : Entreprise spécialisée backups depuis 15 ans
- ✅ **10 GB gratuits** : Même tier gratuit que R2
- ✅ **S3-compatible** : Fonctionne avec tous les outils standards

**Pourquoi c'est moins bien ?**
- ❌ **Frais de téléchargement** : $0.01/GB pour restaurer (gratuit jusqu'à 3× la taille stockée)
- ❌ **Interface moins moderne** : Un peu vieillotte

**Idéal si** :
- Tu veux le prix le plus bas possible
- Tu ne restaures qu'en cas d'urgence (pas souvent)
- Tu stockes beaucoup (> 50 GB)

**Création compte (5 min)** :
1. Va sur [backblaze.com/b2](https://www.backblaze.com/b2/cloud-storage.html) → Sign Up
2. Vérifie ton email
3. "Buckets" → "Create a Bucket" → Nom : `pi5-backups`
4. "App Keys" → "Add a New Application Key"
5. Note bien : **Key ID**, **Application Key** (tu en auras besoin)

---

### 💾 Disque USB Local (Pour tester)

**C'est quoi ?** Un disque dur externe USB branché sur ton Pi.

**Pourquoi c'est bien ?**
- ✅ **Gratuit** (si tu as déjà un disque)
- ✅ **Rapide** : Pas de limite de bande passante
- ✅ **Pas d'internet requis** : Fonctionne même hors ligne
- ✅ **Parfait pour tester** : Comprendre le système avant de passer au cloud

**Pourquoi c'est moins bien ?**
- ❌ **PAS un vrai offsite** : Toujours chez toi (vulnérable aux sinistres)
- ❌ **Capacité limitée** : Taille du disque
- ❌ **Peut tomber en panne** : Disque mécanique = pièce mobile = usure

**Idéal si** :
- Tu veux tester le système avant de payer quoi que ce soit
- Tu as un vieux disque USB qui traîne
- Tu veux un backup ultra-rapide (transfert local)

**Configuration (2 min)** :
1. Branche un disque USB sur ton Pi
2. Crée un dossier : `mkdir -p /mnt/usb-backup`
3. Monte le disque : `sudo mount /dev/sda1 /mnt/usb-backup`
4. Utilise ce chemin dans rclone : `/mnt/usb-backup/pi5-backups`

⚠️ **Important** : Ce n'est PAS un vrai backup offsite ! Utilise-le uniquement pour :
- Tester le système
- Backup temporaire en attendant de configurer le cloud
- Complément (3ème copie locale en plus du cloud)

---

## 🛠️ Comment Ça Marche ?

### Architecture Globale

```
┌─────────────────────────────────────────────────────────────┐
│                    RASPBERRY PI 5                           │
│                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │  Supabase    │   │    Gitea     │   │  Nextcloud   │  │
│  │  (Postgres)  │   │  (dépôts Git)│   │  (fichiers)  │  │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘  │
│         │                  │                  │            │
│         └──────────────────┼──────────────────┘            │
│                            │                               │
│                    ┌───────▼────────┐                      │
│                    │  Backup Local  │                      │
│                    │  ~/backups/    │                      │
│                    │  (carte SD)    │                      │
│                    └───────┬────────┘                      │
│                            │                               │
│                    ┌───────▼────────┐                      │
│                    │     rclone     │                      │
│                    │  (sync cloud)  │                      │
│                    └───────┬────────┘                      │
└────────────────────────────┼──────────────────────────────┘
                             │ 🌐 Internet (crypté)
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐         ┌────▼─────┐        ┌────▼─────┐
   │Cloudflare│         │Backblaze │        │  Disque  │
   │    R2    │         │    B2    │        │USB Local │
   │  (cloud) │         │  (cloud) │        │ (local)  │
   └──────────┘         └──────────┘        └──────────┘
```

### Flux Automatique (Chaque Nuit)

```
1. 🕐 02:00 → Backup local déclenché automatiquement
              (timer systemd)

2. 📦 02:05 → Supabase : Dump SQL créé
              → ~/backups/supabase/2025-10-04_020500.sql.gz

3. 🔄 02:10 → rclone sync démarre
              → Détecte nouveau backup
              → Crypte les données 🔒
              → Upload vers le cloud ☁️

4. ✅ 02:15 → Backup offsite terminé
              → Email de confirmation (si configuré)

5. 🗑️ 02:20 → Rotation GFS appliquée
              → Garde les backups selon la règle :
                - Quotidiens : 7 derniers jours
                - Hebdomadaires : 4 dernières semaines
                - Mensuels : 12 derniers mois
```

### Chiffrement (Sécurité)

**Tes données sont-elles en sécurité dans le cloud ?**

**OUI !** Voici comment rclone protège tes données :

```
┌─────────────────────────────────────────────────────────┐
│  SUR TON PI (données en clair)                          │
│                                                          │
│  fichier: supabase-backup-2025-10-04.sql                │
│  contenu: CREATE TABLE users (                          │
│            id INT,                                       │
│            email VARCHAR(100),                           │
│            password_hash VARCHAR(200)                    │
│           );                                             │
└─────────────────┬───────────────────────────────────────┘
                  │
                  │ rclone crypte avec mot de passe
                  │
                  ▼
┌─────────────────────────────────────────────────────────┐
│  DANS LE CLOUD (données cryptées) 🔒                    │
│                                                          │
│  fichier: a8f3k2m9p1q5r7t4u6v8w0x2y4z6.bin             │
│  contenu: 8f2a9d5e7c3b1a6f4d8e2c0b5a9f3d7e1c4b8a6f2d9  │
│           3e7a1c5b9f2d6a8e4c0b7d5a3e1c9f7b5a3d1e9c7a  │
│           (illisible sans ton mot de passe)             │
└─────────────────────────────────────────────────────────┘
```

**Même si** :
- ❌ Cloudflare est hacké
- ❌ Un employé consulte tes fichiers
- ❌ Une agence gouvernementale demande tes données

**Ils ne verront QUE** :
- Des fichiers avec des noms aléatoires
- Du contenu totalement crypté
- Inutilisable sans TON mot de passe (que TU SEUL connais)

**C'est comme** :
- Mettre tes documents dans un coffre-fort (cryptage)
- Puis déposer le coffre-fort à la banque (cloud)
- Seul toi as la combinaison (mot de passe rclone)

---

### Rotation GFS (Grandfather-Father-Son)

**C'est quoi ?** Une stratégie de rotation qui garde :
- Des backups récents (quotidiens)
- Des backups moyens (hebdomadaires)
- Des backups anciens (mensuels)

**Exemple concret sur 1 an** :

```
Aujourd'hui : 4 octobre 2025

Backups QUOTIDIENS (7 derniers jours) :
✅ 2025-10-04 (aujourd'hui)
✅ 2025-10-03
✅ 2025-10-02
✅ 2025-10-01
✅ 2025-09-30
✅ 2025-09-29
✅ 2025-09-28
❌ 2025-09-27 (supprimé, trop vieux)

Backups HEBDOMADAIRES (4 dernières semaines) :
✅ 2025-09-27 (dimanche dernier)
✅ 2025-09-20
✅ 2025-09-13
✅ 2025-09-06
❌ 2025-08-30 (supprimé, trop vieux)

Backups MENSUELS (12 derniers mois) :
✅ 2025-09-01 (septembre)
✅ 2025-08-01 (août)
✅ 2025-07-01 (juillet)
...
✅ 2024-11-01 (novembre dernier)
✅ 2024-10-01 (octobre dernier)
❌ 2024-09-01 (supprimé, trop vieux)
```

**Pourquoi c'est bien ?**
- ✅ **Espace optimisé** : Pas de backups en doublon
- ✅ **Récupération flexible** :
  - Erreur hier ? → Backup quotidien
  - Erreur il y a 2 semaines ? → Backup hebdomadaire
  - Erreur il y a 6 mois ? → Backup mensuel
- ✅ **Coût maîtrisé** : Taille stable (environ 23 backups au total)

**Calcul de l'espace** :
```
Taille d'un backup Supabase : 500 MB

Espace total :
- 7 quotidiens × 500 MB   = 3.5 GB
- 4 hebdomadaires × 500 MB = 2.0 GB
- 12 mensuels × 500 MB     = 6.0 GB
------------------------------------------
Total                      = 11.5 GB

→ Ça rentre dans le tier gratuit (10 GB) ou presque !
```

---

## 🚀 Installation Pas-à-Pas

### Prérequis

Avant de commencer, assure-toi d'avoir :
- ✅ Un Raspberry Pi 5 avec Raspberry Pi OS installé
- ✅ Une stack déjà installée (Supabase, Gitea, ou Nextcloud)
- ✅ Accès internet (pour télécharger rclone et contacter le cloud)
- ✅ Un compte cloud créé (Cloudflare R2 ou Backblaze B2) OU un disque USB

---

### Étape 1 : Créer un Compte Cloud

#### Option A : Cloudflare R2 (Recommandé)

1. **Inscription** :
   ```
   → Va sur https://dash.cloudflare.com/sign-up
   → Entre ton email et crée un mot de passe
   → Vérifie ton email
   ```

2. **Créer un Bucket** :
   ```
   → Dashboard Cloudflare → Menu gauche → "R2"
   → Clic "Create Bucket"
   → Nom du bucket : "pi5-backups" (minuscules, pas d'espaces)
   → Location : "Automatic" (Cloudflare choisit le meilleur)
   → Clic "Create Bucket"
   ```

3. **Obtenir les Clés API** :
   ```
   → R2 → "Manage R2 API Tokens"
   → Clic "Create API Token"
   → Permissions : "Object Read & Write"
   → Clic "Create API Token"

   → IMPORTANT : Note ces 3 valeurs (tu ne les reverras plus !) :
     ✏️ Account ID       : abc123def456...
     ✏️ Access Key ID    : f1e2d3c4b5a6...
     ✏️ Secret Access Key: a1b2c3d4e5f6...
   ```

4. **Récupérer l'Account ID** :
   ```
   → R2 Dashboard → En haut à droite
   → "Account ID" : abc123def456...
   → Note cette valeur aussi
   ```

---

#### Option B : Backblaze B2

1. **Inscription** :
   ```
   → Va sur https://www.backblaze.com/b2/sign-up.html
   → Entre ton email et crée un mot de passe
   → Vérifie ton email
   ```

2. **Créer un Bucket** :
   ```
   → Dashboard B2 → "Buckets" → "Create a Bucket"
   → Bucket Name : "pi5-backups"
   → Files in Bucket : "Private"
   → Clic "Create a Bucket"
   ```

3. **Obtenir les Clés API** :
   ```
   → Menu "App Keys"
   → Clic "Add a New Application Key"
   → Name : "Pi5 Backups"
   → Bucket Access : "pi5-backups" (ton bucket)
   → Clic "Create New Key"

   → IMPORTANT : Note ces 2 valeurs :
     ✏️ keyID        : 0012abc345def...
     ✏️ applicationKey: K001abc234def...
   ```

---

#### Option C : Disque USB Local (Pour tester)

1. **Brancher le disque** :
   ```bash
   # Branche ton disque USB sur le Pi
   # Attends 5 secondes
   ```

2. **Identifier le disque** :
   ```bash
   lsblk

   # Tu verras quelque chose comme :
   # NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
   # sda      8:0    0 500.0G  0 disk
   # └─sda1   8:1    0 500.0G  0 part

   # Le disque est : /dev/sda1
   ```

3. **Créer le point de montage** :
   ```bash
   sudo mkdir -p /mnt/usb-backup
   sudo mount /dev/sda1 /mnt/usb-backup

   # Vérifier
   df -h | grep usb-backup
   ```

4. **Créer le dossier backup** :
   ```bash
   sudo mkdir -p /mnt/usb-backup/pi5-backups
   sudo chown -R $USER:$USER /mnt/usb-backup/pi5-backups
   ```

---

### Étape 2 : Installer et Configurer rclone

**Commande unique (installation + configuration guidée)** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash
```

**Le script va te guider** :

1. **Installation de rclone** :
   ```
   [RCLONE] Installation de rclone...
   [OK] Rclone installé avec succès (version 1.64.0)
   ```

2. **Choix du fournisseur** :
   ```
   =========================================
     Select Backup Storage Provider
   =========================================

   1) Cloudflare R2 (Recommended)
   2) Backblaze B2
   3) Generic S3-compatible
   4) Local Disk/USB

   =========================================

   Entrez votre choix [1-4]:
   ```
   → **Tape 1** (pour R2) ou **2** (pour B2) ou **4** (pour USB)

3. **Configuration Cloudflare R2** (si choix 1) :
   ```
   → Account ID: [colle ton Account ID]
   → Access Key ID: [colle ton Access Key]
   → Secret Access Key: [colle ton Secret Key]
   → Bucket Name: pi5-backups
   → Enable encryption? [y/N]: y
   → Encryption password: [entre un mot de passe FORT]
   → Confirm password: [même mot de passe]
   ```

   ⚠️ **IMPORTANT** : Note bien ton mot de passe de chiffrement !
   - Sans lui, tu ne pourras JAMAIS récupérer tes backups
   - Garde-le dans un gestionnaire de mots de passe (Bitwarden, 1Password, etc.)

4. **Configuration Backblaze B2** (si choix 2) :
   ```
   → Account ID (keyID): [colle ton keyID]
   → Application Key: [colle ton applicationKey]
   → Bucket Name: pi5-backups
   → Enable encryption? [y/N]: y
   → Encryption password: [entre un mot de passe FORT]
   → Confirm password: [même mot de passe]
   ```

5. **Configuration USB Local** (si choix 4) :
   ```
   → Path to backup directory: /mnt/usb-backup/pi5-backups
   → Enable encryption? [y/N]: y
   → Encryption password: [entre un mot de passe FORT]
   → Confirm password: [même mot de passe]
   ```

6. **Test de connexion** :
   ```
   [RCLONE] Testing connection...
   [OK] Successfully created test file
   [OK] Successfully listed remote files
   [OK] Successfully deleted test file

   ✅ Rclone configured successfully!

   Remote name: offsite-backup
   Type: s3 (or local)
   Encryption: enabled
   ```

---

### Étape 3 : Activer les Backups Offsite

**Commande unique** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash
```

**Le script va** :

1. **Détecter tes stacks installées** :
   ```
   [INFO] Détection des stacks installées...
   [OK] ✓ supabase trouvé: /home/pi/stacks/supabase
   [OK] ✓ gitea trouvé: /home/pi/stacks/gitea
   ```

2. **Te demander quelle stack configurer** :
   ```
   Stacks disponibles:
     1) supabase
     2) gitea
     3) all (configurer toutes les stacks)

   Sélectionnez une stack [1-3]:
   ```
   → **Tape 1** (pour Supabase seul) ou **3** (pour tout)

3. **Sélectionner le remote rclone** :
   ```
   Remotes rclone disponibles:
     1) offsite-backup: (type: s3)

   Numéro du remote [1-1]: 1
   ```

4. **Définir le chemin de destination** :
   ```
   Chemin dans le bucket [pi5-backups/supabase]:
   → (appuie sur Entrée pour accepter le défaut)
   ```

5. **Configuration automatique** :
   ```
   [INFO] Configuration backup offsite pour: supabase
   [OK] ✓ Script de sync créé: /etc/cron.daily/offsite-backup-supabase
   [OK] ✓ Backup offsite activé (quotidien à 03:00)
   ```

6. **Test optionnel** :
   ```
   Tester la sauvegarde maintenant? [y/N]: y

   [INFO] Exécution backup test...
   [INFO] Backup local: supabase-2025-10-04_120000.sql.gz (2.3 MB)
   [INFO] Upload vers: offsite-backup:pi5-backups/supabase/
   [INFO] Transfert: 2.3 MB (100%)
   [OK] ✓ Backup offsite réussi !
   ```

**Résumé final** :
```
╔══════════════════════════════════════════════════════════════╗
║           Backup Offsite Activé avec Succès !               ║
╚══════════════════════════════════════════════════════════════╝

Stack:     supabase
Remote:    offsite-backup (Cloudflare R2)
Chemin:    pi5-backups/supabase/
Fréquence: Quotidien (03:00)
Chiffré:   Oui 🔒

Prochaines étapes:
→ Les backups locaux seront automatiquement uploadés chaque nuit
→ Vérifie les logs: sudo journalctl -u offsite-backup-supabase
→ Liste les backups cloud: rclone ls offsite-backup:pi5-backups/supabase/

⚠️ N'oublie PAS ton mot de passe de chiffrement !
```

---

### Étape 4 : Vérifier les Backups

**Lister les fichiers dans le cloud** :

```bash
# Voir tous les backups
rclone ls offsite-backup:pi5-backups/supabase/

# Résultat :
# 2457123 supabase-2025-10-04_030000.sql.gz
# 2391847 supabase-2025-10-03_030000.sql.gz
# 2412098 supabase-2025-10-02_030000.sql.gz
```

**Vérifier la taille totale** :

```bash
rclone size offsite-backup:pi5-backups/

# Résultat :
# Total objects: 23
# Total size: 52.3 MiB (54831104 bytes)
```

**Voir l'arborescence** :

```bash
rclone tree offsite-backup:pi5-backups/

# Résultat :
# pi5-backups/
# ├── supabase/
# │   ├── daily/
# │   │   ├── supabase-2025-10-04.sql.gz
# │   │   ├── supabase-2025-10-03.sql.gz
# │   │   └── ...
# │   ├── weekly/
# │   │   └── supabase-2025-09-27.sql.gz
# │   └── monthly/
# │       └── supabase-2025-09-01.sql.gz
# └── gitea/
#     └── daily/
#         └── gitea-2025-10-04.tar.gz
```

---

## 🔄 Tester la Restauration

### Pourquoi Tester ?

**Un backup non testé = Pas de backup !**

```
😱 Scénario cauchemar :
1. Tu configures les backups offsite
2. Tout semble fonctionner (fichiers uploadés)
3. 6 mois plus tard → Catastrophe (Pi cassé)
4. Tu essaies de restaurer → ❌ ERREUR
5. Tu découvres que :
   - Le mot de passe de chiffrement était faux
   - Les fichiers sont corrompus
   - La configuration était incomplète

→ TU AS PERDU 6 MOIS DE DONNÉES 😭
```

**La règle d'or** : **Teste ta restauration AU MOINS une fois par mois !**

---

### Restauration en Mode Dry-Run (Sans Risque)

**Dry-run = Simulation** : Le script montre ce qu'il ferait SANS rien modifier.

```bash
# Test restauration (simulation)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo bash -s -- --dry-run

# Le script va :
# 1. Lister les backups disponibles dans le cloud
# 2. Te demander lequel restaurer
# 3. Simuler le téléchargement et la restauration
# 4. Afficher ce qu'il ferait (SANS rien faire)
```

**Exemple d'output** :
```
[DRY-RUN] Les actions suivantes seraient effectuées:

1. Téléchargement depuis cloud:
   Source: offsite-backup:pi5-backups/supabase/supabase-2025-10-04.sql.gz
   Destination: /tmp/restore/supabase-2025-10-04.sql.gz
   Taille: 2.3 MB

2. Déchiffrement:
   Mot de passe: [demandé interactivement]

3. Arrêt des services:
   → docker compose stop (dans /home/pi/stacks/supabase)

4. Restauration base de données:
   → psql < supabase-2025-10-04.sql

5. Redémarrage services:
   → docker compose start

⚠️ Mode DRY-RUN : Aucune modification effectuée
```

---

### Restauration Réelle (En Cas d'Urgence)

⚠️ **ATTENTION** : Cette commande va ÉCRASER tes données actuelles !

**Étapes** :

1. **Sauvegarder l'état actuel** (au cas où) :
   ```bash
   cd ~/stacks/supabase
   docker compose exec db pg_dumpall > /tmp/backup-avant-restore.sql
   ```

2. **Lancer la restauration** :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo bash
   ```

3. **Sélectionner la stack** :
   ```
   Stacks disponibles:
     1) supabase
     2) gitea

   Quelle stack restaurer? [1-2]: 1
   ```

4. **Choisir le backup** :
   ```
   Backups disponibles (supabase):
     1) 2025-10-04 03:00 (2.3 MB) [AUJOURD'HUI]
     2) 2025-10-03 03:00 (2.3 MB) [HIER]
     3) 2025-10-02 03:00 (2.4 MB)
     4) 2025-09-27 03:00 (2.2 MB) [Hebdomadaire]
     5) 2025-09-01 03:00 (2.1 MB) [Mensuel]

   Quel backup restaurer? [1-5]: 2
   ```

5. **Confirmer** :
   ```
   ⚠️  ATTENTION ⚠️
   Cette action va REMPLACER les données actuelles de Supabase
   par le backup du 2025-10-03 03:00.

   Êtes-vous SÛR ? [yes/NO]: yes
   ```

6. **Entrer le mot de passe de chiffrement** :
   ```
   Mot de passe de déchiffrement: [entre ton mot de passe]
   ```

7. **Restauration** :
   ```
   [INFO] Téléchargement: supabase-2025-10-03.sql.gz (2.3 MB)
   [INFO] Déchiffrement...
   [INFO] Arrêt des services Supabase...
   [INFO] Restauration de la base de données...
   [INFO] Redémarrage des services...
   [OK] ✅ Restauration terminée avec succès !

   Vérifications:
   → Supabase Studio : http://192.168.1.100:8000
   → Connecte-toi et vérifie tes données
   ```

8. **Vérifier** :
   - Ouvre Supabase Studio
   - Vérifie que tes tables sont là
   - Vérifie quelques données
   - Teste une requête API

---

### Calendrier de Test (Recommandé)

**Automatise tes tests de restauration** :

```
Chaque mois (1er du mois) :
→ Test dry-run d'une restauration
→ 15 minutes
→ Vérifie que les backups sont accessibles

Chaque trimestre (1er janvier, avril, juillet, octobre) :
→ Restauration RÉELLE sur un Pi de test (si tu en as un)
→ OU restauration dans un container Docker temporaire
→ 1 heure
→ Prouve que tu peux vraiment récupérer tes données

Chaque année (1er janvier) :
→ Restauration complète sur un nouveau Pi
→ Simule un sinistre total
→ 1 demi-journée
→ Documente le processus et le temps nécessaire
```

---

## ❓ Questions Fréquentes

### 🔒 Mes données sont-elles en sécurité dans le cloud ?

**OUI**, grâce au chiffrement rclone :

1. **Tes données sont chiffrées AVANT l'upload** :
   ```
   Pi → Chiffrement (avec TON mot de passe) → Cloud
   ```

2. **Personne ne peut les lire sans ton mot de passe** :
   - Pas Cloudflare / Backblaze
   - Pas un hacker qui pirate le cloud
   - Pas une agence gouvernementale

3. **Le chiffrement est militaire** :
   - Algorithme : AES-256 (même niveau que les banques)
   - Taille clé : 256 bits (2^256 combinaisons possibles)
   - Impossible à casser par force brute

**C'est comme** :
- Mettre tes documents dans un coffre-fort en titane
- Puis déposer le coffre-fort chez quelqu'un
- Même si cette personne est malveillante, elle ne peut rien lire

⚠️ **PAR CONTRE** : Si TU perds ton mot de passe → Tes backups sont PERDUS à jamais !

**Recommandation** :
```bash
# Sauvegarde ton mot de passe dans un gestionnaire de mots de passe
# Exemples gratuits :
- Bitwarden (open source, self-hostable)
- KeePassXC (offline, portable)
- 1Password (payant, excellent)

# ET écris-le sur papier dans un coffre-fort physique
# (pour le scénario apocalypse où tu perds tout)
```

---

### 💵 Combien ça coûte vraiment ?

**Tier gratuit (10 GB)** :
```
Cloudflare R2 : 0€ / mois
Backblaze B2  : 0€ / mois

Tant que tu restes sous 10 GB → GRATUIT À VIE
```

**Au-delà du gratuit (exemple : 50 GB)** :
```
Stockage (50 GB) :
├─ Cloudflare R2 : (50-10) × $0.015 = $0.60 / mois
└─ Backblaze B2  : (50-10) × $0.006 = $0.24 / mois

Opérations (Class A - uploads) :
├─ Cloudflare R2 : 1000 uploads/jour = 30k/mois → $0.45
└─ Backblaze B2  : 1000 uploads/jour = 30k/mois → $0.00 (gratuit)

Téléchargements (si tu restaures tout) :
├─ Cloudflare R2 : 50 GB téléchargés = $0.00 (gratuit !)
└─ Backblaze B2  : 50 GB téléchargés = $0.50

Total mensuel :
├─ Cloudflare R2 : ~$1.05 / mois ($12.60 / an)
└─ Backblaze B2  : ~$0.24 / mois (si pas de restore)
                    ~$0.74 / mois (si restore 1×/mois)
```

**C'est moins cher qu'un café ☕ !**

---

### 🌐 Et si je n'ai pas Internet ?

**Deux options** :

#### Option A : Backup USB Local (Complément)

```bash
# Configure DEUX remotes :
1. Cloud (Cloudflare R2)     → Backup offsite quand Internet OK
2. USB (/mnt/usb-backup)      → Backup local toujours dispo

# Si Internet coupé :
→ Backup cloud échoue (erreur loggée)
→ Backup USB réussit
→ Tu peux restaurer depuis l'USB

# Quand Internet revient :
→ rclone rattrape automatiquement les backups manqués
```

#### Option B : Mode Dégradé (Backup Local Uniquement)

```bash
# Si Internet coupé pendant longtemps :
→ Les backups locaux continuent (~/backups/)
→ Rotation GFS locale fonctionne
→ Tu as quand même 7-30 jours de sauvegardes

# Risque :
→ Pas de protection contre sinistre local
→ Mais mieux que rien !
```

**Recommandation** : **Combine cloud + USB local** pour la redondance maximale.

---

### ⏱️ Combien de temps ça prend ?

**Ça dépend de ta connexion Internet** :

```
Exemple : Backup Supabase = 2 GB

Upload (envoi vers le cloud) :
├─ ADSL (1 Mbps up)     : 2 GB ÷ 1 Mbps   = ~4h30
├─ VDSL (5 Mbps up)     : 2 GB ÷ 5 Mbps   = ~55 min
├─ Fibre (20 Mbps up)   : 2 GB ÷ 20 Mbps  = ~14 min
└─ Fibre (100 Mbps up)  : 2 GB ÷ 100 Mbps = ~3 min

Download (restauration depuis cloud) :
├─ ADSL (8 Mbps down)   : 2 GB ÷ 8 Mbps   = ~35 min
├─ VDSL (20 Mbps down)  : 2 GB ÷ 20 Mbps  = ~14 min
├─ Fibre (100 Mbps down): 2 GB ÷ 100 Mbps = ~3 min
└─ Fibre (1 Gbps down)  : 2 GB ÷ 1 Gbps   = ~17 sec
```

**Le backup tourne la nuit (03:00)** :
- Tu ne le vois jamais
- Pas d'impact sur ta connexion en journée
- Terminé avant ton réveil ☕

**Optimisations** :
```bash
# Compression activée par défaut
→ Réduit la taille de ~70% (ex: 2 GB → 600 MB)

# Incremental sync (rclone)
→ N'upload que les fichiers modifiés
→ Backup suivant = quelques MB seulement
```

---

### 🤖 C'est automatique ?

**OUI, 100% automatique après activation !**

```
Tu configures UNE FOIS :
→ curl ... 01-rclone-setup.sh
→ curl ... 02-enable-offsite-backups.sh

Ensuite, CHAQUE NUIT :
├─ 02:00 → Backup local (Supabase dump SQL)
├─ 03:00 → Sync cloud (rclone upload)
├─ 03:30 → Rotation GFS (suppression vieux backups)
└─ 04:00 → Email confirmation (si configuré)

Tu n'as RIEN à faire !
```

**Surveillance** :
```bash
# Vérifier les logs
sudo journalctl -u offsite-backup-supabase -f

# Vérifier les backups cloud
rclone ls offsite-backup:pi5-backups/supabase/

# Email quotidien (optionnel)
→ Configure dans : /etc/cron.daily/offsite-backup-supabase
→ Reçois un email chaque matin : "Backup OK" ou "Backup FAILED"
```

---

### 🛡️ Que se passe-t-il si le cloud disparaît ?

**Scénarios** :

#### 1. Cloudflare / Backblaze fait faillite

```
Probabilité : Très faible (entreprises multi-milliards $)

Plan B :
→ Les données sont S3-compatible
→ Tu peux exporter vers un autre cloud en quelques heures
→ Exemple : Cloudflare → AWS S3
   rclone sync cloudflare:bucket/ aws:bucket/
```

#### 2. Ton compte est suspendu

```
Probabilité : Faible (si tu paies et respectes les TOS)

Plan B :
→ Support client (généralement réactif)
→ Export des données avant fermeture (délai de 30 jours)
→ Backup local toujours présent (~/backups/)
```

#### 3. Cyberattaque massive / Panne

```
Probabilité : Moyenne (ça arrive)

Plan B :
→ Backup local disponible (~/backups/)
→ Backup USB (si configuré)
→ Attendre le rétablissement du cloud (généralement < 24h)
```

**Recommandation** : **Stratégie 3-2-1 complète** :
```
3 copies :
├─ 1 sur le Pi (production)
├─ 1 sur USB local (backup rapide)
└─ 1 dans le cloud (backup offsite)

2 supports :
├─ Carte SD + USB (localement)
└─ Cloud (offsite)

1 hors site :
└─ Cloud (Cloudflare R2)
```

---

### 🔐 Quelqu'un peut-il voir mes données ?

**NON, personne ne peut lire tes données chiffrées !**

**Qui a accès à quoi** :

```
┌─────────────────────────────────────────────────────────┐
│  TOI (propriétaire)                                     │
│  ✅ Mot de passe de chiffrement rclone                  │
│  ✅ Peut lire les fichiers backups                      │
│  ✅ Peut restaurer les données                          │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  CLOUDFLARE / BACKBLAZE (hébergeur cloud)               │
│  ❌ Voit uniquement des fichiers chiffrés               │
│  ❌ Noms de fichiers : randomisés (a8f3k2m9.bin)        │
│  ❌ Contenu : illisible (AES-256)                       │
│  ❌ Ne peut PAS restaurer tes données                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  HACKER (si piratage du cloud)                          │
│  ❌ Télécharge des fichiers chiffrés                    │
│  ❌ Ne peut PAS les déchiffrer (besoin mot de passe)    │
│  ❌ Cassage AES-256 = impossible (même NSA)             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  GOUVERNEMENT (avec warrant légal)                      │
│  ❌ Cloudflare donne les fichiers chiffrés              │
│  ❌ Mais ne peut PAS les déchiffrer                     │
│  ❌ Aucune backdoor (chiffrement open source)           │
└─────────────────────────────────────────────────────────┘
```

**Même dans le pire scénario** :
```
Hacker compromet Cloudflare ET ton compte
→ Il télécharge tes backups
→ Il voit : a8f3k2m9.bin, b7d9e1f0.bin, etc.
→ Il essaye de déchiffrer :
   - Sans mot de passe : IMPOSSIBLE
   - Avec force brute : 2^256 combinaisons = plusieurs milliards d'années
→ Tes données restent en sécurité 🔒
```

---

## 🎬 Scénarios Réels (Retours d'Expérience)

### Scénario 1 : "Mon Pi est tombé dans l'eau" 💧

**Contexte** :
```
Utilisateur : Marie, développeuse web
Setup : Raspberry Pi 5 avec Supabase (8 GB de données)
Incident : Chat renverse un verre d'eau sur le Pi
Résultat : Pi complètement HS, carte SD corrompue
```

**Sans backup offsite** :
```
❌ Pi détruit
❌ Carte SD illisible
❌ Backup USB (branché sur le Pi) aussi mouillé
❌ 8 GB de données perdues (6 mois de travail)
→ Marie pleure 😭
```

**Avec backup offsite** :
```
✅ Pi détruit (mais c'est juste du matériel)
✅ Backup cloud intact (Cloudflare R2)
✅ Marie achète un nouveau Pi (50€)
✅ Flashe une carte SD (10 min)
✅ Installe Supabase (curl ... | sudo bash)
✅ Restaure depuis le cloud (1h30)
→ Marie récupère 100% de ses données ✅
→ Perte : 50€ + 2h de temps
→ Au lieu de : 6 mois de travail
```

**Timeline de restauration** :
```
J+0 (incident) : 20h00
├─ 20h05 : Commande nouveau Pi sur Amazon (livraison J+1)
└─ 20h15 : Marie va dormir (stressée mais confiante)

J+1 : 18h00
├─ 18h00 : Réception du Pi
├─ 18h10 : Flash carte SD + boot
├─ 18h30 : Installation Supabase (scripts automatiques)
├─ 19h00 : Restauration depuis cloud (backup d'hier soir)
├─ 19h30 : Vérifications (tout est là !)
└─ 20h00 : Marie est de retour en prod ✅

Perte totale : 24h de downtime
             : 50€ de matériel
             : 0€ de données perdues
```

---

### Scénario 2 : "Carte SD corrompue" 💾

**Contexte** :
```
Utilisateur : Thomas, étudiant en informatique
Setup : Raspberry Pi 5 avec Gitea (35 projets Git)
Incident : Carte SD Samsung bas de gamme → corruption sectorielle
Symptôme : Pi ne boote plus, fsck impossible
```

**Sans backup offsite** :
```
❌ Carte SD morte
❌ 35 dépôts Git perdus
❌ 2 ans de code (projets étudiants)
❌ Backup local sur la même SD corrompue
→ Thomas abandonne l'informatique 😭
```

**Avec backup offsite** :
```
✅ Carte SD morte (10€ pour la remplacer)
✅ Backup cloud intact (Backblaze B2)
✅ Thomas achète une nouvelle SD SanDisk (meilleure qualité)
✅ Réinstalle Gitea (30 min)
✅ Restaure les 35 dépôts depuis le cloud (2h)
→ 0 ligne de code perdue ✅
→ Perte : 10€ + 2h30
```

**Leçons apprises** :
```
1. Cartes SD bas de gamme = risque élevé de corruption
   → Investir dans SanDisk Extreme (20€) ou Samsung EVO (15€)

2. Backup offsite = filet de sécurité absolu
   → Même si tout le matériel local meurt, tes données survivent

3. Tester la restauration régulièrement
   → Thomas fait maintenant un test tous les mois
```

---

### Scénario 3 : "Migration vers nouveau Pi" 🚀

**Contexte** :
```
Utilisateur : Sophie, self-hoster passionnée
Setup : Raspberry Pi 4 (4 GB RAM) avec Supabase + Nextcloud
Besoin : Upgrader vers Pi 5 (8 GB RAM) pour meilleures performances
```

**Méthode traditionnelle (sans backup offsite)** :
```
1. Backup manuel sur USB : 2h
2. Configuration nouveau Pi : 1h
3. Installation stacks : 1h
4. Restauration données : 3h
5. Vérifications : 1h
6. Debug problèmes : 2h (toujours des surprises)
→ Total : 10h de travail stressant
```

**Méthode avec backup offsite** :
```
1. Nouveau Pi : Flash carte SD + boot (15 min)
2. Installation automatique : curl ... scripts (30 min)
3. Restauration cloud : curl ... restore (1h30)
4. Vérifications : (30 min)
→ Total : 2h45 de travail relax ✅

Bonus :
→ Ancien Pi reste fonctionnel (backup de backup)
→ Rollback facile si problème sur nouveau Pi
→ Zéro stress
```

**Timeline** :
```
Samedi 10h00 : Début migration
├─ 10h00 : Flash nouvelle SD pour Pi 5
├─ 10h15 : Boot + config réseau
├─ 10h30 : curl ... Supabase deploy
├─ 11h00 : curl ... restore from offsite
├─ 11h30 : Vérifications Supabase OK
├─ 11h45 : curl ... Nextcloud deploy
├─ 12h15 : curl ... restore Nextcloud
└─ 12h45 : TERMINÉ ✅

Samedi 13h00 : Sophie déjeune tranquille
               → Ancien Pi 4 encore allumé (au cas où)
               → Nouveau Pi 5 en prod
               → Migration parfaite
```

---

### Scénario 4 : "Erreur humaine (DROP TABLE)" 🤦

**Contexte** :
```
Utilisateur : Lucas, dev backend débutant
Setup : Supabase sur Pi 5
Incident : Connexion production au lieu de dev
          → Exécute "DROP TABLE users;" par erreur
          → 10,000 utilisateurs supprimés
Heure : 15h30 (mardi après-midi)
```

**Sans backup offsite** :
```
❌ Table users disparue
❌ Backup local = ce matin (0h00) → 15h30 de données perdues
❌ Utilisateurs créés aujourd'hui = perdus
→ Lucas panique et démissionne 😱
```

**Avec backup offsite (rotation GFS)** :
```
✅ Backups disponibles :
   ├─ Daily : Aujourd'hui 03h00 (15h30 - 3h00 = 12h30 de perte max)
   ├─ Daily : Hier 03h00
   └─ Hourly : 14h00 (1h30 de perte) ← SI backup horaire activé

✅ Lucas restaure le backup de 14h00
✅ Perte : 1h30 de données (100 utilisateurs)
✅ Contact les 100 derniers → inscription manuelle
→ Crise évitée ✅
```

**Amélioration post-incident** :
```bash
# Lucas active les backups horaires en journée
→ Backup toutes les heures (9h-18h)
→ Perte max = 1h de données

# Configuration cron :
0 */1 * * * /home/pi/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh
```

**Leçon** :
```
→ Backup fréquent = Recovery Point Objective (RPO) faible
→ RPO = Combien de données tu peux perdre max
→ Daily backup = RPO 24h
→ Hourly backup = RPO 1h
→ Choisir selon criticité des données
```

---

## 🛠️ Commandes Utiles

### Lister les Backups

**Dans le cloud** :
```bash
# Liste simple
rclone ls offsite-backup:pi5-backups/supabase/

# Arborescence
rclone tree offsite-backup:pi5-backups/

# Taille totale
rclone size offsite-backup:pi5-backups/

# Détails avec dates
rclone lsl offsite-backup:pi5-backups/supabase/ | sort
```

---

### Télécharger un Backup

**Télécharger sans restaurer** :
```bash
# Créer dossier temporaire
mkdir -p ~/temp-restore

# Télécharger un backup spécifique
rclone copy offsite-backup:pi5-backups/supabase/supabase-2025-10-03.sql.gz ~/temp-restore/

# Déchiffrer (si chiffrement activé)
rclone decrypt offsite-backup:pi5-backups/supabase/supabase-2025-10-03.sql.gz ~/temp-restore/supabase-2025-10-03.sql.gz

# Décompresser
gunzip ~/temp-restore/supabase-2025-10-03.sql.gz

# Inspecter (sans restaurer)
head -n 50 ~/temp-restore/supabase-2025-10-03.sql
```

---

### Vérifier la Taille et Coût

**Calculer l'espace utilisé** :
```bash
# Taille par stack
rclone size offsite-backup:pi5-backups/supabase/
rclone size offsite-backup:pi5-backups/gitea/

# Taille totale
rclone size offsite-backup:pi5-backups/

# Exemple output :
# Total objects: 23
# Total size: 8.7 GiB (9331343360 bytes)
```

**Calculer le coût** :
```bash
# Si 8.7 GB sur Cloudflare R2 :
# → Sous le tier gratuit (10 GB) → 0€

# Si 8.7 GB sur Backblaze B2 :
# → Sous le tier gratuit (10 GB) → 0€

# Si 15 GB sur Cloudflare R2 :
# → (15 - 10) × $0.015 = $0.075/mois = 7 centimes !
```

---

### Forcer une Sauvegarde Manuelle

**Déclencher backup immédiat** :
```bash
# Backup local
sudo /home/pi/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh

# Sync cloud immédiat
sudo rclone sync ~/backups/supabase/ offsite-backup:pi5-backups/supabase/ \
  --progress \
  --log-file=/var/log/manual-offsite-sync.log

# Vérifier
rclone ls offsite-backup:pi5-backups/supabase/ | tail -5
```

---

### Tester la Connexion Cloud

**Vérifier que rclone fonctionne** :
```bash
# Liste les remotes configurés
rclone listremotes

# Teste la connexion (crée fichier test)
echo "Test backup offsite" > /tmp/test.txt
rclone copy /tmp/test.txt offsite-backup:pi5-backups/test/
rclone ls offsite-backup:pi5-backups/test/
rclone delete offsite-backup:pi5-backups/test/test.txt
rm /tmp/test.txt

# Si tout fonctionne → OK ✅
```

---

### Voir les Logs

**Logs des backups offsite** :
```bash
# Logs temps réel
sudo journalctl -u offsite-backup-supabase -f

# Logs des 24 dernières heures
sudo journalctl -u offsite-backup-supabase --since "1 day ago"

# Logs d'un jour spécifique
sudo journalctl -u offsite-backup-supabase --since "2025-10-03" --until "2025-10-04"

# Chercher les erreurs
sudo journalctl -u offsite-backup-supabase | grep -i error
```

---

### Restaurer un Fichier Spécifique

**Restaurer UNE table (pas tout)** :
```bash
# 1. Télécharger le backup
rclone copy offsite-backup:pi5-backups/supabase/supabase-2025-10-03.sql.gz ~/temp/

# 2. Décompresser
gunzip ~/temp/supabase-2025-10-03.sql.gz

# 3. Extraire UNE table
grep -A 1000 "CREATE TABLE todos" ~/temp/supabase-2025-10-03.sql > ~/temp/todos-only.sql

# 4. Restaurer juste cette table
docker compose -f ~/stacks/supabase/docker-compose.yml exec -T db \
  psql -U postgres < ~/temp/todos-only.sql
```

---

## 🎓 Pour Aller Plus Loin

### Multiple Remotes (Redondance Cloud)

**Pourquoi ?** Si Cloudflare a une panne, tu as Backblaze en backup.

**Configuration** :
```bash
# Configurer 2 remotes
rclone config  # Créer "cloudflare-r2"
rclone config  # Créer "backblaze-b2"

# Script de sync vers les DEUX
#!/bin/bash
rclone sync ~/backups/supabase/ cloudflare-r2:pi5-backups/supabase/
rclone sync ~/backups/supabase/ backblaze-b2:pi5-backups/supabase/
```

**Avantages** :
- ✅ Redondance cloud (si un cloud meurt, l'autre survit)
- ✅ Diversification géographique (R2 = global, B2 = US/EU)
- ✅ Exit strategy facile (pas de lock-in)

**Inconvénient** :
- ❌ Double le coût (mais toujours < 2€/mois)

---

### Backup Encryption avec GPG (Alternative)

**Si tu veux utiliser GPG au lieu de rclone crypt** :

```bash
# Générer une clé GPG
gpg --gen-key

# Backup avec chiffrement GPG
tar -czf - ~/backups/supabase/ | gpg --encrypt --recipient ton-email@example.com > backup.tar.gz.gpg

# Upload vers cloud
rclone copy backup.tar.gz.gpg offsite-backup:pi5-backups/

# Restaurer
rclone copy offsite-backup:pi5-backups/backup.tar.gz.gpg ~/temp/
gpg --decrypt ~/temp/backup.tar.gz.gpg | tar -xzf - -C ~/restore/
```

**Avantage** :
- ✅ Standard crypto (GPG = gold standard)
- ✅ Compatible avec d'autres outils

**Inconvénient** :
- ❌ Plus complexe (gestion clés GPG)
- ❌ Moins transparent que rclone crypt

---

### Rotation Personnalisée (Adapter GFS)

**Modifier la rotation selon tes besoins** :

```bash
# Fichier : /etc/cron.daily/offsite-backup-supabase

# Rotation actuelle (GFS standard) :
# - 7 quotidiens
# - 4 hebdomadaires
# - 12 mensuels

# Rotation personnalisée (exemple: SaaS en production) :
# - 30 quotidiens (1 mois)
# - 12 hebdomadaires (3 mois)
# - 24 mensuels (2 ans)

# Éditer :
sudo nano /etc/cron.daily/offsite-backup-supabase

# Trouver la section rotation et modifier :
DAILY_KEEP=30
WEEKLY_KEEP=12
MONTHLY_KEEP=24
```

**Use cases** :
```
Blog personnel :
→ 7 daily, 4 weekly, 6 monthly (économique)

SaaS en production :
→ 30 daily, 12 weekly, 24 monthly (paranoia mode)

Données critiques (finance, santé) :
→ 90 daily, 52 weekly, 60 monthly (compliance)
```

---

### Alertes Email si Backup Échoue

**Recevoir un email en cas d'erreur** :

```bash
# Installer msmtp (client email léger)
sudo apt install msmtp msmtp-mta mailutils

# Configurer Gmail (exemple)
sudo nano /etc/msmtprc

# Contenu :
account default
host smtp.gmail.com
port 587
from ton-email@gmail.com
user ton-email@gmail.com
password ton-mot-de-passe-application
auth on
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/msmtp.log

# Tester
echo "Test email backup" | mail -s "Test Pi5 Backups" ton-email@gmail.com

# Modifier le script backup pour envoyer email si erreur :
sudo nano /etc/cron.daily/offsite-backup-supabase

# Ajouter à la fin :
if [ $? -ne 0 ]; then
  echo "Backup offsite FAILED at $(date)" | \
    mail -s "❌ Pi5 Backup Failed" ton-email@gmail.com
else
  echo "Backup offsite OK at $(date)" | \
    mail -s "✅ Pi5 Backup Success" ton-email@gmail.com
fi
```

**Résultat** :
- ✅ Email quotidien "✅ Backup OK" (confirmation)
- ❌ Email immédiat "❌ Backup FAILED" (alerte)

---

### Monitoring avec Healthchecks.io

**Alternative aux emails : Monitoring SaaS** :

```bash
# S'inscrire sur healthchecks.io (gratuit : 20 checks)
# Créer un check : "Pi5 Supabase Offsite Backup"
# Récupérer l'URL : https://hc-ping.com/abc123...

# Modifier le script backup :
sudo nano /etc/cron.daily/offsite-backup-supabase

# Ajouter à la fin :
if [ $? -eq 0 ]; then
  curl -fsS --retry 3 https://hc-ping.com/abc123... > /dev/null
fi

# Si backup OK → Healthchecks reçoit un ping
# Si backup échoue (pas de ping) → Healthchecks t'alerte
```

**Avantages** :
- ✅ Dashboard centralisé (tous tes checks)
- ✅ Notifications : Email, SMS, Slack, Discord, etc.
- ✅ Graphiques historiques
- ✅ Gratuit (tier 20 checks)

---

## ✅ Checklist Maîtrise Backups Offsite

### Niveau Débutant

- [ ] Je comprends la différence entre backup local et offsite
- [ ] J'ai créé un compte cloud (Cloudflare R2 ou Backblaze B2)
- [ ] J'ai installé et configuré rclone
- [ ] J'ai activé les backups offsite pour au moins une stack
- [ ] J'ai vérifié que mes backups apparaissent dans le cloud
- [ ] Je sais lister mes backups cloud (rclone ls)

### Niveau Intermédiaire

- [ ] J'ai testé une restauration en dry-run
- [ ] Je comprends le chiffrement rclone (et j'ai sauvegardé mon mot de passe)
- [ ] J'ai configuré les backups offsite pour toutes mes stacks
- [ ] Je connais la rotation GFS (daily/weekly/monthly)
- [ ] J'ai calculé mon coût mensuel cloud
- [ ] Je vérifie mes logs régulièrement

### Niveau Avancé

- [ ] J'ai effectué une restauration réelle (test complet)
- [ ] J'ai configuré des alertes email en cas d'échec
- [ ] J'utilise multiple remotes (redondance cloud)
- [ ] J'ai personnalisé la rotation GFS selon mes besoins
- [ ] Je monitore mes backups (Healthchecks.io ou équivalent)
- [ ] Je teste la restauration tous les mois (calendrier)
- [ ] J'ai documenté ma procédure de disaster recovery

---

## 📚 Ressources pour Débutants

### Documentation Officielle

- **[Rclone Docs](https://rclone.org/docs/)** - Documentation complète
- **[Cloudflare R2 Docs](https://developers.cloudflare.com/r2/)** - Guide R2
- **[Backblaze B2 Docs](https://www.backblaze.com/b2/docs/)** - Guide B2
- **[3-2-1 Backup Rule](https://www.backblaze.com/blog/the-3-2-1-backup-strategy/)** - Explication détaillée

### Vidéos YouTube

- "Rclone Tutorial for Beginners" - TechHut (15 min)
- "Why You NEED Offsite Backups" - Linus Tech Tips (10 min)
- "Setting up Cloudflare R2" - NetworkChuck (20 min)

### Communautés

- [r/DataHoarder](https://reddit.com/r/DataHoarder) - Reddit backups/archivage
- [r/selfhosted](https://reddit.com/r/selfhosted) - Reddit self-hosting
- [Rclone Forum](https://forum.rclone.org/) - Support officiel rclone

### Outils Complémentaires

- **[Restic](https://restic.net/)** - Alternative à rclone (snapshots)
- **[Duplicati](https://www.duplicati.com/)** - GUI pour backups
- **[BorgBackup](https://www.borgbackup.org/)** - Backups déduplication

---

## 🎯 Prochaines Étapes

Une fois à l'aise avec les backups offsite :

1. **Automatiser les tests de restauration** :
   ```bash
   # Cron mensuel : test dry-run automatique
   0 0 1 * * /home/pi/pi5-setup/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh --dry-run
   ```

2. **Monitoring avancé** → [Phase 3 : Monitoring Stack](../../03-monitoring/prometheus-grafana/prometheus-grafana-guide.md)
   - Dashboard Grafana avec métriques backups
   - Alertes Prometheus si backup échoue
   - Graphiques taille/durée backups

3. **High Availability** → [Phase 7 : HA Stack](../ROADMAP.md)
   - Réplication multi-Pi
   - Failover automatique
   - Zero-downtime restores

4. **Compliance** → [Phase 9 : Security Stack](../ROADMAP.md)
   - Audit trail (qui a restauré quoi ?)
   - Immutable backups (WORM storage)
   - Retention policies (RGPD, HIPAA, etc.)

---

## 🆘 Besoin d'Aide ?

**Problème avec rclone** :
- Consulte : [Rclone Forum](https://forum.rclone.org/)
- FAQ : [Rclone FAQ](https://rclone.org/faq/)

**Problème avec ton cloud** :
- Cloudflare : [Support R2](https://developers.cloudflare.com/r2/get-started/)
- Backblaze : [Support B2](https://help.backblaze.com/)

**Problème avec ce guide** :
- Ouvre une issue : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- Discord : [Pi5-Setup Community](https://discord.gg/pi5setup)

---

**🎉 Félicitations !**

Tu as maintenant un système de backup offsite professionnel, automatique, et sécurisé !

Tes données sont protégées contre :
- ✅ Sinistres (feu, eau, vol)
- ✅ Pannes matérielles (SD, USB)
- ✅ Erreurs humaines (suppression accidentelle)
- ✅ Cyberattaques (ransomware)

**Dors tranquille, tes données sont en sécurité !** 😴🔒☁️
