# 🚀 Guide du Débutant pour le Déploiement d'Applications Web

Bienvenue dans le guide du débutant pour `pi5-apps-stack`. Ce guide va vous apprendre à déployer vos propres applications web sur votre Raspberry Pi 5, même si vous n'êtes pas un expert de Docker ou de l'administration système.

## Analogies simples pour comprendre

*   **Une application React (SPA)**, c'est comme un **site web statique et interactif**. Imaginez une brochure ou un dépliant que vous téléchargez une seule fois, et ensuite vous pouvez naviguer entre les pages sans avoir à redemander quoi que ce soit au serveur. C'est rapide et léger.
*   **Une application Next.js (SSR)**, c'est comme un **site web dynamique**. Chaque fois que vous demandez une page, le serveur la construit spécialement pour vous avec les informations les plus à jour. C'est idéal pour les blogs, les sites d'actualités ou les boutiques en ligne.

## Cas d'utilisation

*   **Portfolio personnel** : Une application React (SPA) est parfaite pour présenter vos projets. C'est rapide, efficace et ne consomme que très peu de ressources.
*   **Blog avec backend** : Une application Next.js avec Supabase vous permet de créer un blog où vous pouvez facilement ajouter, modifier et supprimer des articles.
*   **Application SaaS** : Avec Next.js et l'authentification Supabase, vous pouvez construire une application complète avec des comptes utilisateurs, des données personnalisées, etc.
*   **API backend** : Une API Node.js avec une base de données PostgreSQL (fournie par Supabase) est la base de nombreuses applications web et mobiles.

## Concepts expliqués

*   **SSR vs SPA vs Statique** :
    *   **SPA (Single Page Application)** : L'application est chargée une seule fois dans le navigateur, et la navigation se fait ensuite côté client. Rapide après le chargement initial.
    *   **SSR (Server-Side Rendering)** : Chaque page est générée sur le serveur au moment de la demande. Idéal pour le référencement (SEO) et les contenus dynamiques.
    *   **Statique** : Les pages sont générées à l'avance et servies telles quelles. Très rapide, mais pas de contenu dynamique.
*   **Docker multi-stage builds** : C'est une technique qui permet de créer des images Docker plus petites et plus sécurisées. On utilise une première "étape" pour construire l'application (avec toutes les dépendances de développement), puis on copie uniquement le résultat final dans une deuxième "étape" beaucoup plus légère.
*   **Reverse Proxy (Traefik)** : C'est un serveur qui se place devant vos applications. Il reçoit toutes les requêtes et les redirige vers la bonne application en fonction du nom de domaine. C'est lui qui gère les certificats SSL pour le HTTPS.
*   **Variables d'environnement build-time vs runtime** :
    *   **Build-time** : Ces variables sont utilisées au moment de la construction de l'image Docker. Elles sont "cuites" dans l'application.
    *   **Runtime** : Ces variables sont injectées au moment où l'application démarre. Elles permettent de configurer l'application sans avoir à la reconstruire.

## Tutoriel : Déployer votre première application Next.js

1.  **Installation du setup** :
    ```bash
    curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-apps-stack/scripts/01-apps-setup.sh | sudo bash
    ```

2.  **Créer une application Next.js en local** (sur votre ordinateur de développement) :
    ```bash
    npx create-next-app@latest my-next-app
    ```

3.  **Poussez votre code sur un dépôt Git** (Gitea, GitHub, etc.).

4.  **Déployez l'application sur votre Raspberry Pi** :
    ```bash
    sudo bash /opt/pi5-apps-stack/scripts/deploy-nextjs-app.sh my-next-app app.votredomaine.com https://github.com/votre-utilisateur/my-next-app.git
    ```

5.  **Accédez à votre application** via `https://app.votredomaine.com`. Traefik s'occupe automatiquement du HTTPS.

## Dépannage pour les débutants

| Erreur | Cause probable | Solution |
| :--- | :--- | :--- |
| **"Container unhealthy"** | L'application n'a pas démarré correctement. | Vérifiez les logs de l'application avec `sudo bash /opt/pi5-apps-stack/scripts/logs-app.sh <nom-app>`. |
| **"502 Bad Gateway"** | Traefik n'arrive pas à joindre votre application. | Vérifiez les labels Docker dans votre `docker-compose.yml` et assurez-vous que l'application est bien démarrée. |
| **"Build failed"** | Erreur lors de la construction de l'image Docker. | Vérifiez votre `Dockerfile` et les dépendances de votre application. |

## Checklist de progression

**Niveau Débutant** ✅
- [ ] Installer le setup `pi5-apps-stack`.
- [ ] Déployer une application React depuis un template.
- [ ] Comprendre la différence entre SSR et SPA.

**Niveau Intermédiaire** 🔄
- [ ] Déployer une application Next.js depuis un dépôt Git.
- [ ] Connecter une application à Supabase.
- [ ] Mettre en place le CI/CD avec Gitea Actions.

**Niveau Avancé** 🚀
- [ ] Créer votre propre template Dockerfile.
- [ ] Contribuer à la stack `pi5-apps-stack`.

## Ressources

*   [Tutoriels Docker](https://docs.docker.com/get-started/)
*   [Documentation Next.js](https://nextjs.org/docs)
*   [Documentation React](https://react.dev/)
*   [Documentation Traefik](https://doc.traefik.io/traefik/)
