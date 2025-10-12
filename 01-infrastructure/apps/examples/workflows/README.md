# Workflows Gitea Actions

Ces workflows sont des exemples de comment vous pouvez mettre en place une intégration et un déploiement continus (CI/CD) pour vos applications avec Gitea Actions.

## Workflows disponibles

*   **`nextjs-deploy.yml`**: Un workflow complet pour les applications Next.js. Il exécute les tests, construit l'image Docker, la pousse sur un registre (optionnel), et déploie l'application sur votre Raspberry Pi.
*   **`react-spa-deploy.yml`**: Similaire à `nextjs-deploy.yml`, mais pour les applications React (SPA).
*   **`docker-build-only.yml`**: Un workflow qui construit l'image Docker directement sur le Raspberry Pi. C'est plus rapide car cela évite d'avoir à émuler l'architecture ARM64.

## Configuration

1.  **Secrets Gitea** : Dans les paramètres de votre dépôt Gitea, vous devez configurer les secrets suivants pour permettre au workflow de se connecter à votre Raspberry Pi et de déployer l'application :
    *   `SSH_HOST`: L'adresse IP de votre Raspberry Pi.
    *   `SSH_USER`: L'utilisateur SSH.
    *   `SSH_PRIVATE_KEY`: La clé privée SSH pour se connecter.

2.  **Copiez le workflow** : Copiez le fichier de workflow approprié dans le dossier `.github/workflows` de votre dépôt.

## Bonnes pratiques CI/CD

*   **Utilisez des images Docker spécifiques** (par exemple, `node:18-alpine`) au lieu de `latest` pour des constructions reproductibles.
*   **Séparez les étapes de test, de construction et de déploiement** pour une meilleure lisibilité et un débogage plus facile.
*   **Ne stockez jamais de secrets en clair** dans vos fichiers de workflow. Utilisez toujours les secrets de Gitea.
