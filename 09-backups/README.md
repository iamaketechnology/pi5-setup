# 💾 Sauvegardes & Disaster Recovery

> **Catégorie** : Backups automatiques chiffrés offsite

---

## 📦 Stacks Inclus

### 1. [Restic Offsite Backups](restic-offsite/)
**Backups Chiffrés Automatiques vers Cloud**

#### ✨ Fonctionnalités

- 🔐 **Chiffrement** : AES-256 (vos données sont illisibles sur le cloud)
- ☁️ **Stockage cloud** : Cloudflare R2, Backblaze B2, AWS S3, etc.
- 🔄 **Automatique** : Cron jobs quotidiens/hebdomadaires
- 📦 **Déduplication** : Ne sauvegarde que les changements (économise bande passante)
- ⚡ **Compression** : Réduction taille backups
- 🎯 **Rétention** : Garde 7 sauvegardes quotidiennes, 4 hebdomadaires, 6 mensuelles
- 🔙 **Restore facile** : Un script pour restaurer

**RAM** : Minime (s'exécute ponctuellement)
**Stockage requis** : Selon données à sauvegarder

---

## ☁️ Fournisseurs Cloud Supportés

| Fournisseur | Prix | Stockage | Recommandation |
|-------------|------|----------|----------------|
| **Cloudflare R2** | 💚 **0€** (10 GB gratuit) | 10 GB gratuit | ⭐ **Meilleur** (gratuit + rapide) |
| **Backblaze B2** | 💚 0.005$/GB | 10 GB gratuit | ⭐ Excellent (pas cher) |
| **AWS S3** | 💰 0.023$/GB | Payant dès 1er GB | Cher |
| **Local (USB)** | 💚 0€ | Selon disque | OK mais pas offsite |

**Recommandation** : **Cloudflare R2** (10 GB gratuit, 0€/mois)

---

## 🚀 Installation

**Étape 1 : Configurer rclone (cloud)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
```

Suit le wizard interactif pour :
- Choisir fournisseur (R2 / B2 / S3)
- Entrer credentials API
- Tester connexion

**Étape 2 : Activer backups** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

Configure :
- Quoi sauvegarder (Supabase, Gitea, configs, etc.)
- Quand (quotidien 2h du matin par défaut)
- Mot de passe chiffrement

---

## 📁 Données Sauvegardées

Par défaut, le script sauvegarde :

```
✅ /home/pi/stacks/supabase/volumes/db/data/  # PostgreSQL
✅ /home/pi/stacks/gitea/data/                 # Repos Git
✅ /home/pi/stacks/homepage/config/            # Config Homepage
✅ /home/pi/stacks/monitoring/grafana/         # Dashboards Grafana
✅ /home/pi/data/storage/                      # FileBrowser/Nextcloud
✅ /home/pi/.env                               # Variables d'environnement
```

**Personnalisable** dans `/home/pi/backups/backup-script.sh`

---

## 🔄 Fréquence Backups

**Défaut** :
- 📅 **Quotidien** : 2h du matin
- 🗑️ **Rétention** : 7 jours, 4 semaines, 6 mois

**Personnaliser** :
```bash
# Éditer cron
sudo crontab -e

# Exemples
0 2 * * * /home/pi/backups/backup-script.sh   # Quotidien 2h
0 3 * * 0 /home/pi/backups/backup-script.sh   # Hebdomadaire dimanche 3h
```

---

## 🔙 Restauration

**Lister backups disponibles** :
```bash
sudo ~/pi5-setup/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh --list
```

**Restaurer dernière sauvegarde** :
```bash
sudo ~/pi5-setup/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh --latest
```

**Restaurer sauvegarde spécifique** :
```bash
sudo ~/pi5-setup/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh --snapshot abc123def
```

**Dry-run (tester sans restaurer)** :
```bash
sudo ~/pi5-setup/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh --dry-run
```

---

## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 |
| **RAM** | Minime (exécution ponctuelle) |
| **Complexité** | ⭐⭐ (Modérée) |
| **Priorité** | 🔴 **CRITIQUE** (données irremplaçables) |
| **Ordre installation** | Phase 6 (après infrastructure) |
| **Coût cloud** | 💚 0€/mois (Cloudflare R2 10 GB gratuit) |

---

## 🎯 Cas d'Usage

### Scénario 1 : Disaster Recovery
**Raspberry Pi détruit (incendie, vol, panne)** :
1. Acheter nouveau Raspberry Pi 5
2. Installer pi5-setup
3. Exécuter script restore
4. Toutes vos données sont récupérées ✅

### Scénario 2 : Migration vers nouveau Pi
1. Backup ancien Pi
2. Setup nouveau Pi
3. Restore backup sur nouveau Pi
4. Changement transparent

### Scénario 3 : Erreur utilisateur
**Suppression accidentelle fichiers** :
1. Lister snapshots disponibles
2. Restaurer version d'hier
3. Fichiers récupérés ✅

---

## 🔐 Sécurité

- ✅ **Chiffrement AES-256** : Vos données sont illisibles sur le cloud
- ✅ **Mot de passe** : Seul vous pouvez déchiffrer
- ✅ **Aucune fuite** : Même si cloud compromis, données sécurisées
- ⚠️ **IMPORTANT** : **Ne perdez JAMAIS votre mot de passe backup !**

**Stockez mot de passe dans** :
- Gestionnaire mots de passe (Vaultwarden, Bitwarden)
- Coffre-fort physique
- Endroit sûr offline

---

## 💡 Notes

- **Backups offsite** = protection contre perte matériel (incendie, vol, etc.)
- **Cloudflare R2** offre 10 GB gratuit (parfait pour configs + DB)
- Si bibliothèque média volumineuse, backuper sur disque dur externe USB séparé
- Tester restauration régulièrement (1 fois/mois) pour vérifier intégrité
