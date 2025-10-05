# 📚 Guide Débutant - qBittorrent

> **Pour qui ?** Celles et ceux qui téléchargent des fichiers et qui veulent le faire depuis une interface web centralisée.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant / Intermédiaire

---

## 🤔 C'est quoi qBittorrent ?

### En une phrase
**qBittorrent = Un gestionnaire de téléchargement pour les fichiers torrent, avec une interface web qui vous permet de le contrôler depuis n'importe quel appareil.**

### Analogie simple
Imaginez que vous commandez des meubles en kit chez IKEA. Au lieu de les faire livrer par un seul camion (téléchargement direct), le protocole BitTorrent divise les meubles en centaines de petites boîtes. Il vous envoie un plan (le fichier `.torrent`) qui sait où se trouvent toutes ces boîtes, stockées chez des milliers d'autres personnes qui ont déjà commandé les mêmes meubles. Votre client BitTorrent (qBittorrent) est l'assistant qui va chercher un petit bout de meuble chez chaque personne pour reconstituer le meuble complet chez vous.

Le fait d'avoir une **interface web (Web UI)** signifie que vous pouvez lancer et gérer vos téléchargements sur votre Raspberry Pi depuis votre téléphone, votre ordinateur portable au travail, ou n'importe où, sans avoir à installer de logiciel sur ces appareils.

---

## ⚠️ Avertissement Légal et sur la Sécurité

Le téléchargement de contenu via BitTorrent n'est pas illégal en soi, mais **télécharger du contenu protégé par des droits d'auteur l'est dans la plupart des pays.**

De plus, votre adresse IP est visible par toutes les personnes qui téléchargent ou partagent le même fichier. Pour protéger votre vie privée et sécuriser votre connexion, il est **TRÈS FORTEMENT RECOMMANDÉ** d'utiliser un **VPN**.

Ce guide n'encourage pas le piratage. Utilisez cet outil de manière responsable et légale.

---

## 🚀 Comment l'utiliser ?

### Étape 1 : Accéder à l'interface web

Ouvrez l'URL de qBittorrent qui a été fournie à la fin de l'installation (ex: `http://<IP-DU-PI>:8080`). Connectez-vous avec les identifiants par défaut (`admin`/`adminadmin`) et **changez le mot de passe immédiatement**.

### Étape 2 : Ajouter un torrent

Il y a deux manières principales d'ajouter un téléchargement :

1.  **Avec un fichier `.torrent`**
    -   Cliquez sur l'icône "Fichier" > "Ajouter un lien torrent".
    -   Cliquez sur l'icône de dossier pour sélectionner le fichier `.torrent` que vous avez téléchargé sur votre ordinateur.

2.  **Avec un lien Magnet** (recommandé)
    -   Un lien Magnet est un type d'hyperlien qui contient toutes les informations nécessaires pour démarrer le téléchargement.
    -   Cliquez sur l'icône "Ajouter un lien torrent" (ressemble à une chaîne 🔗).
    -   Collez le lien Magnet.
    -   Cliquez sur "Télécharger".

### Étape 3 : Gérer vos téléchargements

L'interface est assez intuitive :
-   Vous pouvez voir la progression, la vitesse de téléchargement et d'envoi.
-   Vous pouvez mettre en pause, reprendre ou supprimer des torrents.
-   Une fois terminé, le fichier sera déplacé dans le dossier `/home/pi/data/downloads/completed`.

---

## 🤖 Intégration avec Radarr & Sonarr (*arr stack)

La vraie puissance de qBittorrent se révèle quand on l'associe à **Radarr** (pour les films) et **Sonarr** (pour les séries TV). C'est le cœur de l'automatisation de votre médiathèque.

**Le workflow est le suivant :**

1.  **Vous** : "Je veux voir le film 'Inception'" → Vous l'ajoutez dans Radarr.
2.  **Radarr** : "OK, je cherche 'Inception' sur mes sites de référence (indexers)."
3.  **Radarr** : "Trouvé ! J'envoie la demande de téléchargement à qBittorrent."
4.  **qBittorrent** : "Reçu ! Je télécharge le film."
5.  **qBittorrent** : "Téléchargement terminé !"
6.  **Radarr** : "Parfait. Je vais maintenant renommer le fichier proprement, le déplacer dans le dossier des films (`/media/movies`), et dire à Jellyfin qu'un nouveau film est disponible."
7.  **Vous** : Vous vous installez dans votre canapé, ouvrez Jellyfin, et le film 'Inception' est là, prêt à être regardé.

### Comment configurer l'intégration ?

-   **Dans Radarr/Sonarr** : Allez dans `Settings` > `Download Clients` > `+` > `qBittorrent`.
-   **Remplissez les informations** :
    -   `Host` : `qbittorrent` (c'est le nom du service Docker).
    -   `Port` : `8080`.
    -   `Username` et `Password` : Ceux que vous avez configurés dans qBittorrent.

Testez la connexion, et voilà ! Vos applications sont maintenant connectées.

---

## 💡 Astuces

-   **Limiter la vitesse** : Si qBittorrent sature votre connexion internet, vous pouvez limiter les vitesses de téléchargement et d'envoi dans les options (icône ⚙️).
-   **Ratio de partage** : Le principe de BitTorrent est le partage. Essayez de garder un ratio (ce que vous avez envoyé / ce que vous avez reçu) d'au moins 1.0 pour être un bon membre de la communauté. Vous pouvez configurer qBittorrent pour qu'il arrête de partager un torrent une fois un certain ratio atteint.

---

Utilisé correctement, qBittorrent est un outil incroyablement puissant pour automatiser et gérer votre médiathèque.
