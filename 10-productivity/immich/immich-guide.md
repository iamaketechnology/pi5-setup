# 📚 Guide Débutant - Immich

> **Pour qui ?** Celles et ceux qui veulent une alternative privée à Google Photos ou Apple Photos.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Immich ?

### En une phrase
**Immich = Votre propre Google Photos, hébergé sur votre Raspberry Pi, qui sauvegarde et organise automatiquement les photos et vidéos de votre téléphone.**

### Analogie simple
Imaginez que Google Photos est un service de stockage de photos public où vous louez un casier. C'est pratique, mais l'entreprise peut regarder dans votre casier, changer les règles ou augmenter le loyer.

**Immich**, c'est comme si vous construisiez votre propre chambre forte, chez vous. Vous avez le contrôle total, personne d'autre n'y a accès, et il n'y a pas de frais mensuels. Vous pouvez y mettre autant de photos que votre disque dur peut en contenir.

---

## 🎯 Pourquoi utiliser Immich ?

Si vous utilisez Google Photos ou iCloud Photos, vous vous êtes peut-être posé ces questions :
- "Où sont réellement stockées mes photos ?"
- "Est-ce que Google/Apple analyse mes photos pour me vendre de la publicité ?"
- "Que se passera-t-il si je ne paie plus mon abonnement ?"

### Les avantages d'Immich

-   ✅ **Confidentialité Totale** : Vos photos sont stockées chez vous, sur votre Pi. Personne d'autre ne peut y accéder.
-   ✅ **Pas d'abonnement** : C'est gratuit. La seule limite est la taille de votre disque dur.
-   ✅ **Sauvegarde Automatique** : L'application mobile sauvegarde automatiquement les nouvelles photos de votre téléphone, comme le font les services commerciaux.
-   ✅ **Fonctionnalités Modernes** : Immich n'est pas juste un simple stockage. Il inclut des fonctionnalités très puissantes.

---

## ✨ Fonctionnalités Clés

Immich reproduit la plupart des fonctionnalités que vous aimez dans Google Photos :

-   **Reconnaissance d'objets et de scènes (IA)** : Tapez "plage", "chat" ou "voiture" et Immich trouvera les photos correspondantes.
-   **Reconnaissance de visages** : Il regroupe automatiquement les photos par personne. Vous pouvez ensuite nommer les visages pour retrouver facilement les photos de vos amis ou de votre famille.
-   **Vue Carte** : Affichez vos photos sur une carte du monde, regroupées par lieu de prise de vue (si vos photos ont des données GPS).
-   **Albums Partagés** : Créez des albums et partagez-les avec votre famille et vos amis via un simple lien.
-   **Souvenirs** : Immich vous remonte des souvenirs, comme "Il y a un an jour pour jour...".

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Installer l'application mobile

C'est le cœur de l'expérience Immich. Allez sur l'App Store (iOS) ou le Google Play Store (Android) et téléchargez l'application "Immich".

### Étape 2 : Connecter l'app à votre serveur

1.  Ouvrez l'application.
2.  Elle vous demandera l'**URL de votre serveur** (`Server Endpoint URL`).
3.  Entrez l'adresse de votre instance Immich (celle affichée à la fin de l'installation, ex: `https://immich.votre-domaine.com`).
4.  Connectez-vous avec l'email et le mot de passe que vous avez créés lors de la première configuration web.

### Étape 3 : Lancer la première sauvegarde

1.  Une fois connecté, l'application vous proposera de sauvegarder vos photos.
2.  Appuyez sur l'icône en forme de nuage ☁️.
3.  Vous pouvez choisir quels dossiers de votre téléphone vous souhaitez sauvegarder (ex: "Appareil photo", "WhatsApp Images", "Screenshots").
4.  Appuyez sur **"Start Backup"**.

La première sauvegarde peut être très longue si vous avez beaucoup de photos. Laissez votre téléphone branché et connecté en Wi-Fi.

### Étape 4 : Explorer vos photos

Une fois les photos uploadées, la magie opère. Attendez un peu que le serveur "indexe" vos photos (c'est là que l'IA travaille).

-   **Onglet "Recherche" 🔍** : Essayez de taper des noms d'objets, de lieux ou de personnes.
-   **Onglet "Partage"** : Créez votre premier album partagé.
-   **Interface Web** : Connectez-vous via votre ordinateur pour une vue plus confortable, idéale pour trier et gérer vos albums.

---

## 💡 Astuces

-   **Stockage externe** : La carte SD de votre Pi n'est pas idéale pour stocker des milliers de photos. Pensez à brancher un disque dur externe USB 3.0 à votre Pi et à configurer Immich pour qu'il l'utilise comme espace de stockage principal.
-   **Machine Learning (IA)** : Les tâches de reconnaissance faciale et d'objets peuvent consommer pas mal de ressources. Soyez patient, surtout sur un Raspberry Pi. Le traitement se fait en arrière-plan.
-   **Multi-utilisateurs** : Vous pouvez créer des comptes pour les membres de votre famille. Chacun aura son propre espace privé pour ses photos.

---

## 🆘 Problèmes Courants

### "L'upload est très lent"

-   **Vérifiez votre connexion Wi-Fi**. L'upload se fait de votre téléphone vers votre Pi. Assurez-vous d'être sur le même réseau local pour une vitesse maximale.
-   La première sauvegarde est toujours la plus longue. Les suivantes ne synchroniseront que les nouvelles photos.

### "La reconnaissance faciale ne marche pas"

-   Les tâches d'IA peuvent prendre du temps. Après un gros import, laissez le serveur tourner tranquillement pendant plusieurs heures, voire une nuit.
-   Assurez-vous que les services "machine-learning" sont bien en cours d'exécution (`docker compose ps` dans le dossier `~/stacks/immich`).

### "L'application mobile ne se connecte pas"

-   **Vérifiez l'URL du serveur**. Assurez-vous qu'elle est accessible depuis votre téléphone. Si vous utilisez une URL locale (ex: `http://192.168.1.100:2283`), votre téléphone doit être sur le même réseau Wi-Fi. Si vous utilisez une URL publique avec Traefik, elle doit être accessible depuis n'importe où.
-   N'oubliez pas le `http://` ou `https://` au début de l'adresse.

---

Félicitations ! Vous êtes maintenant le seul maître de vos souvenirs numériques.
