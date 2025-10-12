# 🎓 Guide Débutant : Jellyfin

> **Pour qui ?** : Toute personne souhaitant créer sa propre plateforme de streaming, comme Netflix, mais avec ses propres films et séries.

---

## 📖 C'est Quoi Jellyfin ?

### Analogie Simple

Imaginez que vous avez une grande collection de DVD et de Blu-ray. Pour regarder un film, vous devez trouver le bon disque, l'insérer dans un lecteur, etc. C'est fastidieux.

**Jellyfin transforme votre collection de fichiers vidéo en un service de streaming personnel.**

C'est comme si vous aviez votre propre **Netflix ou Spotify privé** :

*   **Votre contenu** : Vous y mettez vos propres films, séries, musiques et photos.
*   **Accessible partout** : Vous pouvez regarder votre contenu sur votre TV, votre tablette, votre téléphone, n'importe où chez vous (et même à l'extérieur avec un VPN).
*   **Interface élégante** : Jellyfin organise tout automatiquement avec des jaquettes, des résumés, des bandes-annonces et des notes.
*   **Gratuit et Open Source** : Pas d'abonnement, pas de publicités, pas de suivi de vos habitudes. Vous contrôlez tout.

### En Termes Techniques

Jellyfin est un serveur multimédia qui scanne vos fichiers vidéo, musicaux et photo, télécharge les métadonnées correspondantes sur Internet, et les présente dans une interface web conviviale. Il peut diffuser le contenu en "direct play" (si votre appareil est compatible) ou le "transcoder" à la volée (convertir le format vidéo en temps réel) pour assurer une lecture fluide sur n'importe quel appareil.

---

## 🎯 Cas d'Usage Concrets

### Scénario 1 : Votre Cinéma à la Maison
*   **Contexte** : Vous avez une collection de films sur un disque dur et vous voulez les regarder confortablement sur votre grande TV de salon.
*   **Solution** : Installez Jellyfin sur votre Pi et l'application Jellyfin sur votre Smart TV (Android TV, LG WebOS, Samsung Tizen). Vous pouvez parcourir votre collection avec une télécommande, voir les bandes-annonces, et lancer un film en un clic.

### Scénario 2 : Des Dessins Animés pour les Enfants
*   **Contexte** : Vous voulez que vos enfants aient accès à une sélection de dessins animés et de films familiaux, sans qu'ils ne tombent sur votre collection de films d'horreur.
*   **Solution** : Créez un compte utilisateur pour vos enfants dans Jellyfin et ne leur donnez accès qu'à la bibliothèque "Dessins Animés". Vous pouvez même définir des restrictions par âge.

### Scénario 3 : Écouter votre Musique Partout
*   **Contexte** : Vous avez une grande collection de musique en format FLAC ou MP3 et vous voulez l'écouter sur votre téléphone pendant vos déplacements.
*   **Solution** : Jellyfin organise votre musique par artiste et album. L'application mobile Jellyfin vous permet de streamer votre musique ou même de la télécharger sur votre téléphone pour une écoute hors ligne.

---

## 🚀 Premiers Pas

### Installation

Pour installer Jellyfin, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation de Jellyfin](jellyfin-setup.md)**

### Organiser sa bibliothèque

La clé d'une bonne expérience Jellyfin est une organisation de fichiers propre. Avant de lancer Jellyfin, organisez vos fichiers comme ceci :

```
/media/
├── movies/
│   ├── Inception (2010)/
│   │   └── Inception (2010).mkv
│   └── The Matrix (1999)/
│       └── The Matrix (1999).mp4
├── tv/
│   ├── Breaking Bad/
│   │   ├── Season 01/
│   │   │   └── Breaking Bad - S01E01 - Pilot.mkv
│   │   └── Season 02/
│   │       └── Breaking Bad - S02E01 - Seven Thirty-Seven.mkv
```

### Ajouter une bibliothèque dans Jellyfin

1.  Connectez-vous à l'interface web de Jellyfin.
2.  Allez dans le `Tableau de bord` > `Bibliothèques`.
3.  Cliquez sur `Ajouter une bibliothèque multimédia`.
4.  Choisissez le type de contenu (`Films`, `Séries`, etc.).
5.  Ajoutez le chemin vers votre dossier (ex: `/media/movies`).
6.  Laissez les autres paramètres par défaut et validez.

Jellyfin va maintenant scanner vos fichiers et télécharger toutes les informations. Cela peut prendre un certain temps pour une grande bibliothèque.

---

##  transcoding-arm64

Le Raspberry Pi 5 est équipé d'un processeur graphique (GPU) capable d'accélérer le transcodage, ce qui est essentiel pour une expérience fluide.

*   **Qu'est-ce que le transcodage ?** C'est le processus de conversion d'un fichier vidéo d'un format à un autre en temps réel. Par exemple, si votre film est en 4K H.265 mais que votre téléphone ne peut lire que du 720p H.264, Jellyfin le convertira à la volée.
*   **Accélération matérielle (GPU)** : Utilise le GPU du Pi pour faire cette conversion. C'est très efficace et consomme peu de CPU.
*   **Accélération logicielle (CPU)** : Utilise le processeur principal. C'est beaucoup plus lent et peut provoquer des saccades si le CPU est surchargé.

Grâce à l'accélération matérielle, votre Raspberry Pi 5 peut gérer **2 à 3 flux transcodés en 1080p simultanément** sans problème.

---

## 📱 Applications Clientes

Pour profiter de Jellyfin, vous devez installer une application cliente sur vos appareils. Il en existe pour presque toutes les plateformes :

*   **TV** : Android TV, Google TV, LG WebOS, Samsung Tizen, Apple TV (via Swiftfin), Amazon Fire TV.
*   **Mobile** : Android, iOS.
*   **Ordinateur** : Application web (directement dans votre navigateur), Jellyfin Media Player (Windows, macOS, Linux).

---

## 🐛 Dépannage Débutants

### Problème 1 : Un film ou une série n'a pas la bonne jaquette/information
*   **Cause** : Le fichier est probablement mal nommé.
*   **Solution** : Renommez le fichier et le dossier pour correspondre au nom et à l'année du film/de la série (ex: `Le Seigneur des Anneaux - La Communauté de l'Anneau (2001)`). Ensuite, dans Jellyfin, cliquez sur les trois points du film et choisissez `Identifier` pour relancer la recherche.

### Problème 2 : La lecture est saccadée (buffering)
*   **Cause** : Jellyfin est probablement en train de transcoder en utilisant le CPU, qui n'est pas assez puissant.
*   **Solution** : 
    1.  Vérifiez que l'accélération matérielle est bien activée dans le tableau de bord de Jellyfin (`Lecture` > `Transcodage`).
    2.  Assurez-vous que votre appareil client est capable de lire le format original de la vidéo pour privilégier le "Direct Play" (lecture directe sans transcodage).

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de Jellyfin](https://jellyfin.org/docs/)
*   [Subreddit Jellyfin](https://www.reddit.com/r/jellyfin/) : Pour de l'aide et des exemples de configurations.
