# Template Next.js (SSR)

Ce template fournit une base optimisée pour le déploiement d'applications Next.js en rendu côté serveur (SSR) sur un Raspberry Pi 5.

## Dockerfile

Le `Dockerfile` utilise une construction multi-stage pour créer une image légère et sécurisée.

1.  **Étape `builder`** : Installe les dépendances et construit l'application Next.js.
2.  **Étape `runner`** : Copie uniquement les fichiers nécessaires depuis l'étape `builder` (le dossier `.next/standalone`) et installe les dépendances de production. L'application est lancée avec un utilisateur non-root pour plus de sécurité.

## next.config.js

Le fichier `next.config.js` est configuré avec `output: 'standalone'` pour générer une version autonome de l'application qui peut être déployée sans avoir à installer `node_modules`.

## Variables d'environnement

Vous pouvez passer des variables d'environnement à votre application via le fichier `docker-compose.yml`.

## Déploiement

Utilisez le script `deploy-nextjs-app.sh` pour déployer une application basée sur ce template :

```bash
sudo bash /opt/pi5-apps-stack/scripts/deploy-nextjs-app.sh my-app app.mondomaine.com
```

## Consommation de RAM

Une application Next.js SSR consomme environ **100-150Mo de RAM**.

## Healthcheck

Un healthcheck est intégré au `Dockerfile` pour s'assurer que l'application est bien démarrée et fonctionne correctement.
