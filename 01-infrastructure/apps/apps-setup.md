# 🔧 Guide d'Installation

Ce guide fournit des instructions détaillées pour installer et configurer `pi5-apps-stack`.

## Installation du setup

La manière la plus simple d'installer le setup est d'utiliser le script one-liner :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-apps-stack/scripts/01-apps-setup.sh | sudo bash
```

Ce script va créer la structure de dossiers suivante :

*   `/opt/pi5-apps-stack`: Contient les scripts et les templates.
*   `/opt/apps`: Le dossier où seront déployées vos applications.

## Déploiement d'applications

### Déploiement automatique (recommandé)

Utilisez les scripts fournis pour déployer vos applications. Ils s'occupent de tout : cloner le dépôt, créer les fichiers de configuration et démarrer l'application.

**Pour une application Next.js (SSR) :**
```bash
sudo bash /opt/pi5-apps-stack/scripts/deploy-nextjs-app.sh <nom> <domaine> [git-repo]
```
*   `<nom>`: Le nom de votre application (ex: `mon-blog`).
*   `<domaine>`: Le nom de domaine où l'application sera accessible (ex: `blog.mondomaine.com`).
*   `[git-repo]` (optionnel): L'URL de votre dépôt Git.

**Pour une application React (SPA) :**
```bash
sudo bash /opt/pi5-apps-stack/scripts/deploy-react-spa.sh <nom> <domaine> [git-repo]
```

### Déploiement manuel

1.  Créez un dossier pour votre application dans `/opt/apps`.
2.  Copiez le template approprié depuis `/opt/pi5-apps-stack/templates`.
3.  Créez un fichier `docker-compose.yml`.
4.  Lancez le déploiement avec `docker-compose up -d`.

## Intégration Supabase

Si vous avez déployé la stack Supabase, les scripts de déploiement détecteront automatiquement sa présence et injecteront les variables d'environnement nécessaires (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, etc.) dans vos applications.

## CI/CD avec Gitea Actions

1.  **Configurez les secrets dans votre dépôt Gitea** : Ajoutez les secrets nécessaires (par exemple, les identifiants de votre serveur) dans les paramètres de votre dépôt.
2.  **Copiez un workflow d'exemple** depuis `/opt/pi5-apps-stack/examples/workflows` dans le dossier `.github/workflows` de votre dépôt.
3.  Maintenant, à chaque `git push`, Gitea Actions va automatiquement tester, construire et déployer votre application sur votre Raspberry Pi.

## Gestion des applications

*   **Lister les applications** : `sudo bash /opt/pi5-apps-stack/scripts/list-apps.sh`
*   **Mettre à jour une application** : `sudo bash /opt/pi5-apps-stack/scripts/update-app.sh <nom-app>`
*   **Supprimer une application** : `sudo bash /opt/pi5-apps-stack/scripts/remove-app.sh <nom-app>`
*   **Voir les logs d'une application** : `sudo bash /opt/pi5-apps-stack/scripts/logs-app.sh <nom-app>`

## Monitoring

Si vous avez déployé la stack de monitoring, un tableau de bord Grafana pour vos applications est disponible. Il vous permet de suivre la consommation de RAM, le CPU, etc.

## Backups

L'intégration avec `restic` ou `rclone` est automatique si vous avez configuré les backups via les `common-scripts`.
