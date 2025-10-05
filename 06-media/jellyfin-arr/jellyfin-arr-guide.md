# 📚 Guide Débutant - Jellyfin & la stack *Arr

> **Pour qui ?** Toute personne souhaitant créer son propre Netflix/Spotify personnel et automatiser le téléchargement de contenu.
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant / Intermédiaire

---

## 🤔 C'est quoi cette stack ?

### En une phrase
**Jellyfin = Votre serveur de streaming personnel pour films, séries, et musique.**
***Arr (Radarr, Sonarr, etc.) = Des robots qui cherchent et téléchargent automatiquement le contenu que vous voulez.**

### Analogie simple
- **Jellyfin** : C'est votre propre magasin de location de vidéos et de CD, mais tout est numérique et accessible depuis n'importe où. Vous êtes le propriétaire et le seul client (ou vous invitez vos amis/famille).
- **La stack *Arr** : C'est votre assistant personnel. Vous lui donnez une liste de courses ("Je veux tous les épisodes de cette série en 1080p", "Je veux ce film dès qu'il sort en Blu-ray"). L'assistant va alors surveiller les magasins (sites de torrents/usenet) et achètera (téléchargera) les articles pour vous dès qu'ils sont disponibles.

---

## 🎯 À quoi ça sert concrètement ?

### Use Cases

#### 1. **Créer votre propre Netflix**
Vous avez une collection de films et de séries sur un disque dur et vous voulez y accéder facilement depuis votre TV, tablette ou téléphone, avec des jaquettes, des résumés et des bandes-annonces.
```
La stack fait :
✅ Jellyfin scanne vos fichiers et organise tout dans une belle interface.
✅ Il transcode la vidéo à la volée pour qu'elle soit compatible avec l'appareil que vous utilisez.
✅ Vous pouvez reprendre la lecture là où vous l'aviez laissée, sur n'importe quel appareil.
```

#### 2. **Automatiser le téléchargement de vos séries TV préférées**
Vous suivez plusieurs séries et vous voulez que les nouveaux épisodes soient téléchargés automatiquement dès leur diffusion.
```
La stack fait :
✅ Sonarr surveille les calendriers de diffusion.
✅ Dès qu'un nouvel épisode est disponible, il l'envoie à votre client de téléchargement (qBittorrent, Usenet).
✅ Une fois le téléchargement terminé, il renomme et déplace le fichier dans le dossier de votre bibliothèque Jellyfin.
✅ Jellyfin l'ajoute automatiquement à votre collection.
```

--- 

## 🧩 Les Composants (Expliqués simplement)

### 1. **Jellyfin** - Le Cinéma
**C'est quoi ?** Le serveur multimédia. C'est l'interface que vous et vos utilisateurs verrez. Il lit vos fichiers et les présente de manière élégante.

### 2. **Sonarr** - Le Spécialiste des Séries TV
**C'est quoi ?** Un gestionnaire de séries. Vous lui dites quelles séries vous suivez, et il s'occupe de trouver les épisodes (nouveaux et anciens).

### 3. **Radarr** - Le Spécialiste des Films
**C'est quoi ?** Comme Sonarr, mais pour les films. Vous lui donnez une liste de films que vous voulez, et il les cherche pour vous.

### 4. **Prowlarr** - L'Annuaire
**C'est quoi ?** Il gère la connexion entre Sonarr/Radarr et les sites où ils cherchent le contenu (les "indexers"). Au lieu de configurer chaque site dans Sonarr ET dans Radarr, vous le faites une seule fois dans Prowlarr.

### 5. **qBittorrent (ou autre)** - Le Livreur
**C'est quoi ?** Le client de téléchargement. C'est lui qui effectue réellement le téléchargement des fichiers que Sonarr et Radarr ont trouvés.

**Flux de travail typique :**
1. Vous ajoutez un film à **Radarr**.
2. **Radarr** demande à **Prowlarr** de chercher ce film sur les sites configurés.
3. **Prowlarr** trouve le film et envoie le lien à **Radarr**.
4. **Radarr** envoie le lien de téléchargement à **qBittorrent**.
5. **qBittorrent** télécharge le fichier.
6. Une fois terminé, **Radarr** récupère le fichier, le renomme et le place dans votre dossier de films.
7. **Jellyfin** détecte le nouveau fichier et l'ajoute à votre bibliothèque.

---

## 🚀 Comment l'utiliser ?

### Étape 1 : Configurer les chemins
- La partie la plus cruciale est de s'assurer que tous les conteneurs Docker voient les dossiers de la même manière.
- Par exemple, `/data/media/movies` doit pointer vers le même dossier physique pour Radarr, qBittorrent et Jellyfin.

### Étape 2 : Ajouter un film dans Radarr
1. Allez dans l'interface de Radarr.
2. Cherchez un film et cliquez sur "Add".
3. Choisissez le profil de qualité souhaité et le dossier racine.
4. Cliquez sur "Add Movie". Vous pouvez cocher "Start search for missing movie" pour lancer la recherche immédiatement.

### Étape 3 : Regarder sur Jellyfin
- Une fois le processus terminé, le film apparaîtra comme "récemment ajouté" sur l'écran d'accueil de Jellyfin. Cliquez et profitez !

---

## 📚 Ressources

- **Wiki TRaSH Guides** : [https://trash-guides.info/](https://trash-guides.info/) - La référence absolue pour configurer correctement cette stack.
- **Subreddit r/selfhosted** : [https://www.reddit.com/r/selfhosted/](https://www.reddit.com/r/selfhosted/) - Pour des exemples et de l'aide.

🎉 **Bon visionnage !**
