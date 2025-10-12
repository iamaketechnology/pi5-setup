# 🚀 Installation Gitea

> **Installation automatisée d'un serveur Git auto-hébergé avec CI/CD.**

---

## 📋 Prérequis

### Système
*   Raspberry Pi 5 (4 Go de RAM minimum, 8 Go recommandé).
*   Raspberry Pi OS 64-bit.
*   Docker et Docker Compose installés.

### Ressources
*   **RAM** : ~500 Mo - 1 Go
*   **Stockage** : ~1 Go pour l'installation, plus l'espace nécessaire pour vos dépôts.
*   **Ports** : 3001 (HTTP), 2222 (SSH).

### Dépendances (Optionnel)
*   **Traefik** : Pour un accès HTTPS externe.

---

## 🚀 Installation

L'installation se fait en deux étapes : le déploiement de Gitea lui-même, puis la configuration du runner pour le CI/CD.

### Étape 1 : Déployer Gitea

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash
```

**Durée** : ~3-5 minutes

### Étape 2 : Configurer le Runner Gitea Actions (CI/CD)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
```

**Durée** : ~2 minutes

Ce script vous demandera un "registration token" que vous devrez générer depuis votre interface Gitea (Administration du site > Actions > Runners > Créer un nouveau Runner).

---

## 📊 Ce Que Fait le Script

*   **`01-gitea-deploy.sh`** :
    1.  Détecte la présence de Traefik pour configurer l'accès externe.
    2.  Crée la structure de dossiers dans `/opt/stacks/gitea`.
    3.  Génère un `docker-compose.yml` avec Gitea et une base de données PostgreSQL.
    4.  Démarre les conteneurs.
*   **`02-runners-setup.sh`** :
    1.  Télécharge `act_runner`, le runner officiel de Gitea.
    2.  Vous guide pour enregistrer le runner auprès de votre instance Gitea.
    3.  Configure le runner pour qu'il puisse lancer des jobs Docker (Docker-in-Docker).
    4.  Crée un service `systemd` pour que le runner tourne en permanence en arrière-plan.

---

## 🔧 Configuration Post-Installation

### Premier Lancement

1.  Accédez à l'URL de Gitea (`http://<IP_DU_PI>:3001` ou `https://git.mondomaine.com`).
2.  Sur la page d'installation, la plupart des champs sont déjà pré-remplis. Vous devez simplement **créer votre compte administrateur**.
3.  Une fois l'installation terminée, connectez-vous avec votre compte admin.

### Configurer SSH

Pour pouvoir `push` et `pull` via SSH, ajoutez votre clé SSH publique à votre compte Gitea :

1.  Copiez votre clé publique (`cat ~/.ssh/id_ed25519.pub`).
2.  Dans Gitea, allez dans `Paramètres` > `Clés SSH / GPG`.
3.  Cliquez sur `Ajouter une clé` et collez votre clé.

---

## 🔗 Intégration Traefik

Si Traefik est détecté, le script d'installation configure automatiquement les labels Docker pour exposer Gitea via HTTPS. Aucune configuration manuelle n'est nécessaire.

---

## ✅ Validation Installation

**Test 1** : Vérifier que les conteneurs Gitea sont en cours d'exécution.

```bash
cd /opt/stacks/gitea
docker compose ps
```

**Résultat attendu** : Les conteneurs `gitea` et `gitea-db` doivent être `Up`.

**Test 2** : Vérifier que le runner est actif.

```bash
sudo systemctl status act-runner
```

**Résultat attendu** : Le service doit être `active (running)`.

**Test 3** : Lancer un premier workflow.

1.  Créez un nouveau dépôt sur Gitea.
2.  Ajoutez un fichier `.gitea/workflows/test.yml` avec un contenu simple.
3.  Poussez vos changements.
4.  Vérifiez l'onglet "Actions" dans Gitea pour voir le workflow s'exécuter.

---

## 🛠️ Maintenance

### Mettre à jour Gitea

```bash
cd /opt/stacks/gitea
docker compose pull
docker compose up -d
```

### Sauvegarder Gitea

Une sauvegarde complète inclut la base de données et les fichiers (dépôts, pièces jointes).

```bash
# Script de sauvegarde (à créer ou utiliser un outil comme restic)
sudo tar -czf ~/gitea_backup.tar.gz -C /opt/stacks/gitea .
```

---

## 🐛 Troubleshooting

### Problème 1 : Le runner est "offline" dans Gitea
*   **Symptôme** : Les workflows ne se lancent pas.
*   **Solution** : Vérifiez le statut du service runner avec `sudo systemctl status act-runner`. S'il est inactif, redémarrez-le avec `sudo systemctl restart act-runner`. Consultez les logs avec `sudo journalctl -u act-runner` pour plus de détails.

### Problème 2 : Erreur de permission en poussant via SSH
*   **Symptôme** : `Permission denied (publickey)`.
*   **Solution** : Assurez-vous que votre clé SSH publique est bien ajoutée à votre compte Gitea et que votre client SSH local est configuré pour l'utiliser.

---

## 🗑️ Désinstallation

```bash
# Arrêter et supprimer les conteneurs et volumes
cd /opt/stacks/gitea
docker-compose down -v

# Arrêter et désactiver le service du runner
sudo systemctl stop act-runner
sudo systemctl disable act-runner

# Supprimer les fichiers
cd /opt/stacks
sudo rm -rf gitea
sudo rm /etc/systemd/system/act-runner.service
```

---

## 📊 Consommation Ressources

*   **RAM utilisée** : ~500 Mo - 1 Go (Gitea + PostgreSQL).
*   **Stockage** : ~1 Go + la taille de vos dépôts.

---

## 🔗 Liens Utiles

*   [Guide Débutant](gitea-guide.md)
*   [Exemples de Workflows](examples/workflows/README.md)
*   [Documentation Officielle de Gitea](https://docs.gitea.io/)