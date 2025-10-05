# 📚 Guide Débutant - Joplin & Joplin Server

> **Pour qui ?** Les étudiants, développeurs, écrivains, et toute personne qui veut organiser ses pensées et ses connaissances de manière privée et sécurisée.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Joplin ?

### En une phrase
**Joplin = Votre carnet de notes numérique personnel, open source et privé, qui fonctionne sur tous vos appareils, comme Evernote ou Notion, mais où vous contrôlez vos données.**

### Analogie simple
Imaginez que vous avez un journal intime ou un carnet de recherche. Vous pouvez y écrire vos pensées, coller des articles, dessiner des schémas. C'est personnel et précieux.

Les services comme Evernote ou Notion sont comme des carnets que vous louez. C'est pratique, mais l'entreprise qui les fabrique peut potentiellement lire ce qu'il y a dedans, ou pire, perdre votre carnet.

**Joplin** est un carnet que vous possédez. **Joplin Server**, que vous avez installé sur votre Pi, est votre propre service de livraison privé et sécurisé qui s'assure que si vous écrivez quelque chose dans le carnet sur votre ordinateur, la même page apparaît comme par magie dans le carnet sur votre téléphone.

---

## 🎯 Pourquoi utiliser Joplin ?

-   ✅ **Confidentialité et Contrôle** : Vos notes sont à vous. Avec Joplin Server, elles sont stockées sur votre Pi. Personne d'autre ne peut y accéder. Vous pouvez même activer le **chiffrement de bout en bout (E2EE)**, ce qui signifie que même votre serveur ne peut pas lire vos notes.
-   ✅ **Open Source et Gratuit** : Pas d'abonnement, pas de fonctionnalités premium payantes. Tout est disponible.
-   ✅ **Multi-plateforme** : Fonctionne partout : Windows, macOS, Linux, Android, iOS, et même en ligne de commande !
-   ✅ **Format Markdown** : Permet de formater le texte de manière simple et standard, idéal pour les listes, le code, les tableaux, etc.
-   ✅ **Web Clipper** : Sauvegardez des articles ou des pages web directement dans vos notes depuis votre navigateur, sans les publicités.

---

## ✨ Fonctionnalités Clés

-   **Organisation** : Les notes sont organisées en **carnets** et sous-carnets. Vous pouvez aussi ajouter des **tags** à vos notes pour les retrouver facilement.
-   **Éditeur Markdown** : Écrivez en texte brut et voyez le résultat formaté à côté. Parfait pour la documentation technique, les listes de tâches ou simplement pour structurer vos pensées.
-   **Support des pièces jointes** : Attachez des images, des PDF, et d'autres fichiers directement dans vos notes.
-   **Listes de tâches (To-Do)** : Créez des listes de tâches avec des cases à cocher.
-   **Recherche puissante** : Retrouvez rapidement ce que vous cherchez dans toutes vos notes.
-   **Historique des notes** : Joplin sauvegarde les versions précédentes de vos notes, vous pouvez donc revenir en arrière si vous faites une erreur.

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Installer les applications Joplin

Le serveur seul ne sert à rien. Vous avez besoin des applications "clientes".

-   **Sur votre ordinateur** : Allez sur le [site officiel de Joplin](https://joplinapp.org/) et téléchargez la version pour votre système d'exploitation (Windows, macOS, Linux).
-   **Sur votre téléphone** : Cherchez "Joplin" sur l'App Store (iOS) ou le Google Play Store (Android).

### Étape 2 : Configurer la synchronisation

C'est l'étape la plus importante pour lier vos applications à votre serveur personnel.

1.  Ouvrez l'application Joplin sur votre ordinateur.
2.  Allez dans le menu **Outils > Options** (ou `Joplin > Préférences` sur Mac).
3.  Allez dans la section **Synchronisation**.
4.  Dans la liste déroulante "Cible de synchronisation", choisissez **Joplin Server**.
5.  Remplissez les 3 champs :
    -   `URL du serveur Joplin` : L'adresse de votre serveur (ex: `https://joplin.votre-domaine.com`).
    -   `Email` : L'email de l'utilisateur que vous utilisez sur le serveur (par défaut `admin@localhost`).
    -   `Mot de passe` : Le mot de passe de cet utilisateur.
6.  Cliquez sur **"Vérifier la configuration de la synchronisation"**. Un message de succès devrait apparaître.
7.  Cliquez sur **Appliquer**.

Faites la même chose sur votre application mobile. La première synchronisation peut prendre un peu de temps.

### Étape 3 : Créer votre première note

-   Cliquez sur "Nouvelle note" ou "Nouveau carnet".
-   Donnez un titre à votre note.
-   Commencez à écrire dans l'éditeur. Essayez la syntaxe Markdown :
    -   `# Titre 1`
    -   `## Sous-titre`
    -   `- [ ] Une tâche à faire`
    -   `- [x] Une tâche terminée`
    -   `**Texte en gras**`
    -   `*Texte en italique*`
-   Attendez quelques instants, et la note apparaîtra sur vos autres appareils connectés !

---

## 💡 Astuces

-   **Installez le Web Clipper** : C'est une extension de navigateur (pour Chrome ou Firefox) qui vous permet de sauvegarder des articles ou des pages web en un clic. C'est extrêmement pratique pour la recherche et la veille.
-   **Activez le chiffrement (E2EE)** : Dans les options de synchronisation, vous pouvez activer le chiffrement. Vous devrez définir un mot de passe de chiffrement. **ATTENTION : si vous perdez ce mot de passe, vos notes seront illisibles et irrécupérables.** Notez-le en lieu sûr (par exemple, dans votre gestionnaire de mots de passe Vaultwarden !).
-   **Personnalisez l'apparence** : Joplin supporte les thèmes et le CSS personnalisé pour adapter l'éditeur à votre goût.

---

Joplin est un outil incroyablement flexible. Que ce soit pour prendre des notes de cours, écrire un roman, documenter un projet de code ou simplement gérer votre vie, il peut s'adapter à vos besoins tout en garantissant que vos données restent les vôtres.
