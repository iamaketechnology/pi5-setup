# 📚 Guide Débutant - Calibre-Web

> **Pour qui ?** Les lecteurs avides qui ont une collection d'e-books et qui veulent y accéder de partout.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant / Intermédiaire

---

## 🤔 C'est quoi Calibre-Web ?

### En une phrase
**Calibre-Web = Une interface web magnifique et conviviale pour votre bibliothèque d'e-books Calibre, la rendant accessible depuis n'importe quel navigateur.**

### Analogie simple
Imaginez que **Calibre** (l'application de bureau) est votre **bibliothécaire personnel**. C'est un expert pour organiser, convertir et cataloguer méticuleusement tous vos livres numériques. Il travaille dans une bibliothèque physique (le dossier sur votre ordinateur).

**Calibre-Web**, c'est le **portail en ligne de cette bibliothèque**. Il ne range pas les livres lui-même, mais il vous donne un catalogue en ligne magnifique, avec les couvertures, les résumés, et un moteur de recherche. Il vous permet de consulter votre collection et de télécharger un livre depuis votre téléphone, votre tablette ou n'importe quel ordinateur, sans avoir à déranger le bibliothécaire.

**Point important :** Calibre-Web a besoin d'une bibliothèque créée et gérée par l'application Calibre pour fonctionner. Il ne peut pas créer une bibliothèque de zéro.

---

## 🎯 Pourquoi utiliser Calibre-Web ?

-   ✅ **Accès Universel** : Accédez à votre collection de livres depuis n'importe quel appareil disposant d'un navigateur web.
-   ✅ **Interface Agréable** : Une présentation visuelle bien plus jolie que l'interface un peu austère de Calibre, avec les couvertures des livres mises en avant.
-   ✅ **Lecture en Ligne** : Lisez vos e-books (formats ePub, etc.) directement dans votre navigateur, sans avoir à télécharger le fichier.
-   ✅ **Gestion des utilisateurs** : Créez des comptes pour votre famille, avec des permissions différentes si nécessaire.
-   ✅ **Envoi vers la liseuse** : Intégration pour envoyer des livres directement vers votre Kindle ou autre liseuse par email.

---

## 🚀 Comment l'utiliser ?

### Étape 1 : Préparer votre bibliothèque avec Calibre

C'est le prérequis indispensable.

1.  **Téléchargez et installez Calibre** (l'application de bureau) sur votre ordinateur depuis le [site officiel](https://calibre-ebook.com/).
2.  **Créez une nouvelle bibliothèque** ou utilisez celle par défaut.
3.  **Ajoutez vos e-books** (fichiers .epub, .mobi, .pdf, etc.) dans Calibre. Glissez-déposez les fichiers dans la fenêtre de Calibre.
4.  **Éditez les métadonnées** : C'est le plus important ! Pour une belle expérience dans Calibre-Web, assurez-vous que vos livres ont une couverture, un auteur, un résumé, etc. Calibre peut télécharger ces informations pour vous (clic droit sur un livre > "Éditer les métadonnées" > "Télécharger les métadonnées").
5.  Une fois votre bibliothèque prête, **copiez l'intégralité du dossier** de la bibliothèque sur votre Raspberry Pi (voir le guide [d'installation](calibre-web-setup.md)).

### Étape 2 : Explorer votre bibliothèque en ligne

Une fois Calibre-Web configuré, connectez-vous. Vous verrez une interface qui ressemble à une librairie en ligne, mais avec vos propres livres.

-   **Naviguez** par auteur, série ou tags.
-   **Utilisez la barre de recherche** pour trouver un livre par titre ou auteur.
-   **Cliquez sur un livre** pour voir ses détails, son résumé, et les formats disponibles.

### Étape 3 : Lire ou télécharger un livre

Sur la page d'un livre, vous avez plusieurs options :

-   **"Lire"** : Ouvre le lecteur intégré dans votre navigateur. Parfait pour une lecture rapide sur votre ordinateur ou tablette.
-   **"Télécharger"** : Télécharge le fichier de l'e-book (ex: le `.epub`) sur votre appareil. Vous pouvez ensuite l'ouvrir avec votre application de lecture préférée.

---

## 💡 Astuces

-   **Gestion des utilisateurs** : Dans le menu Admin, vous pouvez créer de nouveaux utilisateurs. C'est pratique pour partager votre bibliothèque avec votre famille sans qu'ils puissent modifier les paramètres.
-   **Étagères personnalisées** : Créez des "étagères" virtuelles pour regrouper des livres (ex: "À lire cet été", "Livres de science-fiction préférés").
-   **Synchronisation avec une liseuse** : Si votre liseuse a une adresse email (comme les Kindle), vous pouvez configurer Calibre-Web pour y envoyer des livres directement depuis l'interface web. (Admin > Edit Basic Configuration > Feature Configuration).

---

## 🆘 Problèmes Courants

### "Calibre-Web dit que ma base de données est invalide"

-   **Vérifiez le chemin** : Assurez-vous que le chemin vers votre bibliothèque Calibre que vous avez fourni lors de la configuration est absolument correct.
-   **Vérifiez les permissions** : Le conteneur Docker de Calibre-Web doit avoir les droits de lecture (et d'écriture si vous autorisez les modifications) sur le dossier de la bibliothèque. La commande `sudo chown -R pi:pi /home/pi/data/calibre-library` peut aider.
-   **Vérifiez la présence de `metadata.db`** : Le dossier doit contenir un fichier nommé `metadata.db`. Si ce n'est pas le cas, ce n'est pas un dossier de bibliothèque Calibre valide.

### "Les modifications que je fais dans Calibre-Web n'apparaissent pas dans l'application Calibre (et vice-versa)"

C'est normal. Calibre-Web et Calibre lisent la même base de données, mais ils ne se parlent pas en temps réel. Si vous ajoutez un livre avec Calibre, vous devrez peut-être redémarrer Calibre-Web pour qu'il le voie. Il est généralement conseillé de faire toutes les modifications majeures (ajout de livres, édition de métadonnées en masse) avec l'application de bureau Calibre, et d'utiliser Calibre-Web principalement pour la consultation et le téléchargement.

---

Profitez de votre bibliothèque personnelle, accessible partout dans le monde !
