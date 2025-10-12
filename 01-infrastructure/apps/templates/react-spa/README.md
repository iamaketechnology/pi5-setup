# Template React (SPA)

Ce template fournit une base optimisée pour le déploiement d'applications React à page unique (SPA), créées avec Vite ou Create React App, sur un Raspberry Pi 5.

## Dockerfile

Le `Dockerfile` utilise une construction multi-stage :

1.  **Étape `build`** : Installe les dépendances et construit l'application React pour la production.
2.  **Étape finale** : Utilise une image Nginx très légère (`nginx:alpine`) et copie les fichiers statiques générés à l'étape précédente. Le serveur Nginx est configuré pour servir l'application.

## nginx.conf

Le fichier `nginx.conf` est configuré pour :

*   Servir les fichiers statiques de l'application.
*   Gérer le routage côté client en redirigeant toutes les requêtes vers `index.html`.
*   Activer la compression Gzip pour des temps de chargement plus rapides.
*   Définir des en-têtes de cache appropriés.

## Variables d'environnement

Les variables d'environnement (commençant par `VITE_` pour Vite ou `REACT_APP_` pour Create React App) sont utilisées au moment de la construction (build-time).

## Déploiement

Utilisez le script `deploy-react-spa.sh` pour déployer une application basée sur ce template :

```bash
sudo bash /opt/pi5-apps-stack/scripts/deploy-react-spa.sh my-spa spa.mondomaine.com
```

## Consommation de RAM

Une application React SPA servie avec Nginx est extrêmement légère et ne consomme qu'environ **10-20Mo de RAM**.
