# 📚 Guide Débutant - Navidrome

> **Pour qui ?** Les passionnés de musique qui possèdent leur propre collection de fichiers MP3/FLAC et qui veulent leur propre service de streaming.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Navidrome ?

### En une phrase
**Navidrome = Votre propre Spotify ou Apple Music personnel, hébergé sur votre Raspberry Pi, qui vous permet d'écouter votre collection musicale de n'importe où.**

### Analogie simple
Imaginez que votre collection de CD ou de vinyles est stockée dans une grande armoire à la maison. C'est super, mais vous ne pouvez l'écouter que lorsque vous êtes chez vous.

**Navidrome** est un **jukebox magique connecté à Internet**. Vous mettez toute votre musique numérique (fichiers MP3, FLAC, etc.) dedans. Ensuite, depuis votre téléphone au bureau, votre ordinateur portable en vacances, ou votre tablette dans le jardin, vous pouvez vous connecter à ce jukebox, parcourir toute votre collection et écouter n'importe quelle chanson, comme si vous utilisiez Spotify.

---

## 🎯 Pourquoi utiliser Navidrome ?

-   ✅ **Propriété de votre musique** : Vous écoutez VOS fichiers. Pas de risque qu'un artiste disparaisse d'une plateforme ou qu'un service ferme.
-   ✅ **Pas d'abonnement, pas de publicités** : C'est votre service. Profitez de votre musique sans interruption et sans frais mensuels.
-   ✅ **Haute Qualité** : Si vous avez des fichiers de haute qualité (comme le FLAC), vous pouvez les écouter sans compression, contrairement à la plupart des services de streaming.
-   ✅ **Accès Universel** : Grâce à l'interface web et aux applications mobiles compatibles, votre musique vous suit partout.
-   ✅ **Léger et Rapide** : Navidrome est conçu pour être très efficace et fonctionne parfaitement sur un Raspberry Pi.

---

## ✨ Fonctionnalités Clés

-   **Interface Web Moderne** : Une interface propre et rapide pour parcourir votre musique par artiste, album ou chanson.
-   **Playlists** : Créez et gérez vos propres playlists.
-   **Favoris** : Marquez vos chansons, albums et artistes préférés pour un accès rapide.
-   **Transcodage à la volée** : Si vous êtes en 4G et que vous ne voulez pas utiliser trop de données, Navidrome peut automatiquement réduire la qualité d'un fichier FLAC en un MP3 plus léger pendant la lecture, sans modifier le fichier original.
-   **Multi-utilisateurs** : Créez des comptes pour les membres de votre famille. Chacun peut avoir ses propres playlists et favoris.
-   **Compatible Subsonic** : C'est le point le plus important pour l'usage mobile. Navidrome "parle" le langage Subsonic, ce qui le rend compatible avec des dizaines d'applications mobiles.

---

## 🚀 Comment l'utiliser ?

### Étape 1 : Préparez votre musique

Navidrome ne fournit pas de musique. Il organise et diffuse la vôtre.

1.  Rassemblez tous vos fichiers musicaux (MP3, M4A, FLAC, etc.) dans un seul dossier.
2.  **Assurez-vous que vos fichiers sont bien "tagués" !** C'est crucial. Navidrome se base sur les métadonnées (tags ID3) de vos fichiers pour construire sa bibliothèque (nom de l'artiste, titre de l'album, numéro de piste, pochette...).
    -   Utilisez un logiciel comme **MusicBrainz Picard** ou **Mp3tag** sur votre ordinateur pour nettoyer et organiser vos tags avant de les copier sur le Pi.
3.  Copiez votre dossier de musique sur votre Pi, dans `/home/pi/data/music`.

### Étape 2 : Laissez Navidrome scanner votre bibliothèque

Après la première connexion, Navidrome commence à scanner votre dossier de musique. Ce processus peut être long si vous avez beaucoup de fichiers. Soyez patient. Vous pouvez suivre l'avancement dans le menu **"Activity"** de l'interface web.

### Étape 3 : Explorez et écoutez

-   Utilisez l'interface web pour découvrir votre bibliothèque sous un nouveau jour.
-   Créez votre première playlist en ajoutant des chansons.
-   Mettez des albums en favori.

### Étape 4 : Connectez une application mobile (le plus important !)

Pour écouter en déplacement, vous avez besoin d'une application compatible Subsonic.

1.  Téléchargez une application comme **substreamer** (iOS) ou **DSub** (Android).
2.  Ouvrez les paramètres de l'application pour ajouter un nouveau serveur.
3.  Entrez les informations de votre serveur Navidrome :
    -   **URL du serveur** : L'adresse complète de votre Navidrome (ex: `https://music.votre-domaine.com`).
    -   **Utilisateur** : Votre nom d'utilisateur.
    -   **Mot de passe** : Votre mot de passe.
4.  L'application va se synchroniser. Vous pouvez maintenant parcourir toute votre bibliothèque, créer des playlists, et même **télécharger des albums pour une écoute hors ligne** (parfait pour l'avion ou le métro).

---

## 🆘 Problèmes Courants

### "Ma musique n'apparaît pas ou est mal classée"

C'est presque toujours un **problème de métadonnées (tags)**.
-   Assurez-vous que vos fichiers sont correctement tagués, en particulier les champs "Artiste", "Album", "Titre" et "Artiste de l'album".
-   Le nom du fichier lui-même n'est pas très important pour Navidrome, il se fie aux tags internes.
-   Après avoir corrigé vos tags avec un outil externe, vous devrez peut-être lancer un "Rescan complet" dans les paramètres de Navidrome.

### "L'application mobile ne se connecte pas"

-   Vérifiez l'URL du serveur. Elle doit être accessible depuis votre téléphone. N'oubliez pas le `https://`.
-   Assurez-vous que le nom d'utilisateur et le mot de passe sont corrects.
-   Certaines applications plus anciennes peuvent nécessiter que vous ajoutiez `/server/xml.server` à la fin de l'URL, mais ce n'est généralement plus le cas.

---

Avec Navidrome, vous avez le meilleur des deux mondes : la commodité du streaming et le contrôle total sur votre collection musicale.
