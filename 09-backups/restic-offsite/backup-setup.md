# 🚀 Installation Sauvegardes Offsite

> **Installation automatisée des sauvegardes cloud avec rclone.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5 avec au moins une stack (Supabase, Gitea, etc.) déjà installée et configurée pour les backups locaux.
*   Connexion Internet.

### Fournisseur Cloud
*   Un compte chez un fournisseur de stockage objet. Nous recommandons :
    *   **Cloudflare R2** (10 Go gratuits, pas de frais de sortie)
    *   **Backblaze B2** (10 Go gratuits, stockage le moins cher)
*   Vos clés d'API (Access Key ID, Secret Access Key, etc.) prêtes à être utilisées.

---

## 🚀 Installation

L'installation se fait en deux étapes principales : la configuration de l'outil de synchronisation (rclone), puis l'activation de l'upload automatique.

### Étape 1 : Configurer rclone

Ce script vous guidera pour connecter rclone à votre fournisseur cloud.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
```

Le script vous demandera de choisir un fournisseur, puis de copier-coller vos clés d'API.

### Étape 2 : Activer les Sauvegardes Offsite

Ce script modifie vos scripts de sauvegarde existants pour y ajouter l'étape d'upload vers le cloud.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

---

## 📊 Ce Que Fait le Script

*   **`01-rclone-setup.sh`** :
    1.  Installe rclone s'il n'est pas présent.
    2.  Lance un assistant interactif pour configurer une nouvelle "remote" (une connexion à votre cloud).
    3.  Teste la connexion en uploadant, listant, puis supprimant un fichier de test.
    4.  Sauvegarde la configuration dans `~/.config/rclone/rclone.conf`.
*   **`02-enable-offsite-backups.sh`** :
    1.  Détecte les stacks déjà installées qui supportent les sauvegardes (Supabase, Gitea, etc.).
    2.  Ajoute la commande `rclone copy` à la fin des scripts de sauvegarde existants.
    3.  Lance un premier backup de test pour vérifier que tout fonctionne.

---

## 🔧 Configuration Post-Installation

Une fois les scripts exécutés, les sauvegardes offsite sont actives. Par défaut, chaque fois qu'un backup local est créé (généralement la nuit), il sera automatiquement copié vers votre stockage cloud.

Vous pouvez personnaliser le comportement en modifiant les scripts de maintenance de chaque stack (ex: `/opt/stacks/supabase/scripts/maintenance/supabase-backup.sh`).

---

## ✅ Validation Installation

**Test 1** : Lister les fichiers sur votre espace de stockage cloud.

```bash
# Remplacez "remote" par le nom que vous avez donné à votre connexion rclone
rclone ls remote:votre-bucket
```

**Résultat attendu** : Vous devriez voir le ou les fichiers de sauvegarde qui ont été uploadés lors du test d'installation.

**Test 2** : Lancer un backup manuel et vérifier l'upload.

```bash
# Lancez un backup pour une stack, par exemple Supabase
sudo bash /opt/stacks/supabase/scripts/maintenance/supabase-backup.sh

# Vérifiez les logs pour voir l'étape rclone
# Puis relancez la commande rclone ls pour voir le nouveau fichier
```

---

## 🛠️ Maintenance

### Tester une restauration

Il est CRUCIAL de tester régulièrement que vous pouvez bien restaurer vos données depuis le cloud.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh | sudo bash
```

Ce script vous guidera pour lister les sauvegardes disponibles, en télécharger une, et la restaurer.

---

## 🐛 Troubleshooting

### Problème 1 : Erreur "remote not found"
*   **Symptôme** : rclone se plaint de ne pas trouver la configuration.
*   **Solution** : Assurez-vous d'avoir bien exécuté le script `01-rclone-setup.sh` et que le fichier `~/.config/rclone/rclone.conf` existe et contient la configuration de votre remote.

### Problème 2 : Erreur "Access Denied" lors de l'upload
*   **Symptôme** : rclone n'arrive pas à écrire dans le bucket.
*   **Solution** : Vos clés d'API sont probablement incorrectes ou n'ont pas les bonnes permissions. Vérifiez sur l'interface de votre fournisseur cloud que la clé a bien les droits d'écriture, et reconfigurez rclone si nécessaire.

---

## 🗑️ Désinstallation

Pour désactiver les sauvegardes offsite, vous devez manuellement éditer les scripts de maintenance de chaque stack pour enlever la ligne `rclone copy ...`.

Pour désinstaller rclone :

```bash
sudo apt remove rclone
rm -rf ~/.config/rclone
```

---

## 📊 Consommation Ressources

*   **RAM / CPU** : rclone est très léger et ne consomme des ressources que pendant l'upload.
*   **Réseau** : L'impact dépend de la taille de vos sauvegardes et de la vitesse de votre connexion Internet. L'upload se faisant la nuit, il ne devrait pas gêner votre usage quotidien.

---

## 🔗 Liens Utiles

*   [Guide Débutant](backup-guide.md)
*   [Documentation Officielle de rclone](https://rclone.org/)
