# 🎓 Guide Débutant : Traefik

> **Pour qui ?** : Débutants en auto-hébergement, pas de prérequis réseau

---

## 📖 C'est Quoi Traefik ?

### Analogie Simple

Imaginez que votre Raspberry Pi est un grand hôtel et que chaque application que vous hébergez (Supabase, Gitea, Homepage) est une chambre. Quand un visiteur arrive sur Internet, comment sait-il dans quelle chambre aller ?

**Traefik est le réceptionniste de votre hôtel numérique.**

1.  **Un seul point d'entrée** : Tous les visiteurs arrivent à la même adresse (votre adresse IP publique).
2.  **Il demande le nom** : Le visiteur dit "Je veux aller à `studio.mondomaine.com`".
3.  **Il consulte son registre** : Traefik regarde sa configuration et voit que `studio.mondomaine.com` correspond à la chambre 3000 (le port de votre application Supabase Studio).
4.  **Il dirige le visiteur** : Traefik guide le visiteur de manière transparente vers la bonne chambre, sans que le visiteur ait à connaître le numéro de la chambre.
5.  **Il fournit la sécurité** : En chemin, Traefik donne au visiteur une clé sécurisée (un certificat HTTPS), garantissant que la conversation entre le visiteur et la chambre est privée et sécurisée. Il s'occupe même de renouveler ces clés automatiquement !

En bref, Traefik est un **reverse proxy** intelligent qui simplifie l'accès à vos applications et le sécurise automatiquement.

### En Termes Techniques

Traefik est un reverse proxy et un répartiteur de charge (load balancer) moderne, conçu pour les architectures microservices. Ses principales fonctionnalités sont :

*   **Découverte automatique de services** : Traefik peut écouter le "Docker socket" et détecter automatiquement les nouvelles applications (conteneurs) que vous lancez, en lisant leurs "labels" pour savoir comment les router.
*   **HTTPS automatique (ACME)** : Il s'intègre avec des autorités de certification comme Let's Encrypt pour obtenir et renouveler automatiquement des certificats SSL/TLS, vous offrant le HTTPS sans effort.
*   **Configuration dynamique** : Sa configuration peut être mise à jour à chaud, sans avoir besoin de redémarrer le service.
*   **Middlewares** : Il dispose d'un système de middlewares pour ajouter des fonctionnalités à vos routes (authentification, rate limiting, modification des en-têtes, etc.).

---

## 🔒 Pourquoi l'HTTPS Automatique est-il si Important ?

*   **Confiance** : Le petit cadenas vert dans le navigateur rassure vos visiteurs. Il prouve que votre site est bien celui qu'il prétend être.
*   **Confidentialité** : HTTPS chiffre les données échangées entre le visiteur et votre serveur. Sans cela, n'importe qui sur le réseau (votre FAI, un pirate sur un Wi-Fi public) pourrait lire les informations, y compris les mots de passe.
*   **Intégrité** : Il garantit que les données n'ont pas été modifiées pendant le transport.
*   **Référencement (SEO)** : Google et les autres moteurs de recherche favorisent les sites en HTTPS.

Avant Traefik, obtenir un certificat SSL était un processus manuel, complexe et souvent payant. Traefik et Let's Encrypt ont rendu ce processus gratuit et entièrement automatisé.

---

## 🌐 Les 3 Scénarios Expliqués

Cette stack vous propose trois manières d'exposer vos services au monde, chacune avec ses avantages et ses inconvénients.

### Scénario 1 : DuckDNS (Facile et Gratuit)
*   **Principe** : Vous utilisez un nom de domaine gratuit fourni par DuckDNS (ex: `mon-pi.duckdns.org`). Traefik utilise le challenge `HTTP-01` : Let's Encrypt demande à votre serveur de prouver qu'il contrôle bien ce domaine en plaçant un fichier temporaire accessible publiquement.
*   **Idéal pour** : Les débutants, les tests, les projets personnels où le nom de domaine n'est pas important.

### Scénario 2 : Domaine Personnel + Cloudflare (Production)
*   **Principe** : Vous achetez votre propre nom de domaine (ex: `mondomaine.com`) et vous le gérez via Cloudflare. Traefik utilise le challenge `DNS-01` : il prouve qu'il contrôle le domaine en ajoutant un enregistrement DNS temporaire via l'API de Cloudflare. Cela permet d'obtenir des certificats "wildcard" (`*.mondomaine.com`).
*   **Idéal pour** : Les projets sérieux, les applications en production, quand vous voulez des sous-domaines propres (`studio.mondomaine.com`, `api.mondomaine.com`).

### Scénario 3 : VPN + Certificats Locaux (Sécurité Maximale)
*   **Principe** : Rien n'est exposé sur Internet. Vous devez d'abord vous connecter à un réseau privé virtuel (VPN) pour accéder à vos services. Traefik utilise des certificats auto-signés car les services ne sont pas publics.
*   **Idéal pour** : Les services sensibles (dashboards d'administration, bases de données), les utilisateurs paranoïaques de la sécurité, ou ceux qui n'ont pas d'adresse IP publique fixe.

---

## 📊 Tableau Comparatif des Scénarios

| Critère | 🟢 DuckDNS | 🔵 Cloudflare | 🟡 VPN |
| :--- | :--- | :--- | :--- |
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐ Avancé |
| **Coût** | Gratuit | ~8€/an (domaine) | Gratuit |
| **HTTPS Valide** | ✅ Oui | ✅ Oui | ❌ Auto-signé (warning) |
| **Sous-domaines** | ❌ Non (chemins) | ✅ Illimités | ✅ Illimités (locaux) |
| **Exposition Publique**| ✅ Oui | ✅ Oui | ❌ Non |
| **Ports à Ouvrir** | 80, 443 | 80, 443 | Aucun (ou port VPN) |
| **Fonctionne si CGNAT**| ❌ Non | ✅ (avec Tunnel) | ✅ Oui |
| **Recommandé pour** | Débutants, tests | Production, projets sérieux | Sécurité, accès privé |

---

## 🎯 Cas d'Usage (Quel scénario pour quel besoin ?)

*   **"Je veux juste tester l'auto-hébergement et accéder à mes services depuis l'extérieur facilement et gratuitement."**
    *   ➡️ **Scénario 1 (DuckDNS)** est parfait pour vous.

*   **"Je lance un projet de SaaS et j'ai besoin d'une URL professionnelle et de plusieurs sous-domaines pour mon API, mon app et mon blog."**
    *   ➡️ **Scénario 2 (Cloudflare)** est la seule option viable.

*   **"J'héberge des données très sensibles et je veux que seuls moi et ma famille puissions y accéder, même à distance."**
    *   ➡️ **Scénario 3 (VPN)** est le plus sécurisé.

*   **"Je veux un blog public, mais je veux que mon dashboard d'administration ne soit accessible que par moi."**
    *   ➡️ **Configuration Hybride (Cloudflare + VPN)** : Exposez le blog publiquement via Cloudflare et routez le dashboard d'administration sur un domaine local accessible uniquement via VPN.

---

## 🚀 Premiers Pas

La première étape est de choisir le scénario qui vous convient le mieux et de suivre le guide d'installation correspondant.

➡️ **[Consulter le Guide d'Installation de Traefik](traefik-setup.md)**

Une fois Traefik installé, le premier test est d'accéder à son tableau de bord.

*   **Avec DuckDNS** : `https://mon-pi.duckdns.org/traefik`
*   **Avec Cloudflare** : `https://traefik.mondomaine.com`
*   **Avec VPN** : `https://traefik.pi.local`

Vous devriez voir une interface web avec la liste des "routers" et "services" que Traefik a détectés.

---

## 🎛️ Le Dashboard Traefik

Le tableau de bord est votre tour de contrôle. Il vous permet de voir en temps réel :

*   **Routers** : Les "règles" qui définissent comment le trafic est dirigé (ex: `Host("studio.mondomaine.com")`).
*   **Services** : Les applications finales vers lesquelles le trafic est envoyé (ex: le conteneur Docker de Supabase Studio).
*   **Middlewares** : Les traitements intermédiaires appliqués (authentification, redirections, etc.).
*   **EntryPoints** : Les portes d'entrée de votre trafic (généralement les ports 80 et 443).

C'est l'outil indispensable pour déboguer vos configurations de routage.

---

## 🐛 Dépannage Débutants

### Problème 1 : Erreur 404 Not Found
*   **Symptôme** : Vous essayez d'accéder à votre service, mais Traefik affiche une page 404.
*   **Cause** : Traefik a bien reçu la requête, mais aucun "router" ne correspond au domaine que vous avez demandé.
*   **Solution** : Vérifiez les labels Docker de votre application. Le label `traefik.http.routers.mon-app.rule=Host("app.mondomaine.com")` doit correspondre exactement à l'URL que vous utilisez.

### Problème 2 : Erreur 502 Bad Gateway
*   **Symptôme** : Traefik trouve bien un router, mais ne parvient pas à joindre l'application derrière.
*   **Cause** : L'application est peut-être arrêtée, ou Traefik et l'application ne sont pas dans le même réseau Docker.
*   **Solution** : Assurez-vous que le conteneur de votre application est bien démarré (`docker ps`). Vérifiez que les deux conteneurs (Traefik et votre app) partagent un réseau Docker commun.

### Problème 3 : Le site n'est pas sécurisé (pas de HTTPS)
*   **Symptôme** : Vous n'avez pas le cadenas vert, ou le navigateur affiche un avertissement de sécurité.
*   **Cause** : Traefik n'a pas réussi à obtenir un certificat SSL de Let's Encrypt.
*   **Solution** : Regardez les logs de Traefik (`docker logs traefik`). Les erreurs les plus courantes sont :
    *   **HTTP-01 Challenge** : Vos ports 80 et 443 ne sont pas correctement ouverts et redirigés vers votre Pi.
    *   **DNS-01 Challenge** : Votre token d'API Cloudflare est incorrect ou n'a pas les bonnes permissions.

### Problème 4 : Le dashboard Traefik est inaccessible (DuckDNS)
*   **Symptôme** : `ERR_CONNECTION_REFUSED` quand vous essayez d'accéder à `http://localhost:8081/dashboard/` depuis votre ordinateur.
*   **Cause** : Le dashboard est accessible uniquement depuis le Pi lui-même (localhost). Traefik v3 ne supporte pas le path-based routing (`/traefik`) pour son dashboard.
*   **Solution** : Créez un tunnel SSH depuis votre ordinateur :
    ```bash
    ssh -L 8081:localhost:8081 pi@<IP_DU_PI>
    ```
    Gardez ce terminal ouvert, puis ouvrez `http://localhost:8081/dashboard/` dans votre navigateur.
*   **Alternative** : Utilisez Portainer (`http://<IP_DU_PI>:8080`) pour gérer vos containers avec une interface graphique complète.

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de Traefik](https://doc.traefik.io/traefik/)
*   [Traefik 101 (Vidéo)](https://www.youtube.com/watch?v=2m7PO7qJkL8) : Une excellente introduction en vidéo.
*   [Awesome Traefik](https://github.com/search?q=awesome-traefik) : Une liste de ressources et d'exemples.
*   [Communauté Traefik (Forum)](https://community.traefik.io/)
