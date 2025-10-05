# 📚 Guide Débutant - Syncthing

> **Pour qui ?** Celles et ceux qui veulent synchroniser des fichiers entre plusieurs appareils sans passer par un serveur central (comme Google Drive ou Dropbox).
> **Durée de lecture** : 10 minutes
> **Niveau** : Intermédiaire

---

## 🤔 C'est quoi Syncthing ?

### En une phrase
**Syncthing = Un service de synchronisation de fichiers qui permet à vos appareils de se parler directement, de manière sécurisée et privée, pour garder des dossiers identiques partout.**

### Analogie simple
Imaginez que Google Drive ou Dropbox sont des **entrepôts centraux**. Pour donner un fichier de votre ordinateur à votre téléphone, vous devez d'abord le déposer à l'entrepôt (upload), puis votre téléphone doit aller le chercher à l'entrepôt (download). L'entrepôt voit tout ce qui passe.

**Syncthing**, c'est comme si vous aviez un **téléporteur** magique. Vous mettez un fichier dans une boîte spéciale sur votre ordinateur, et il se matérialise instantanément dans une boîte identique sur votre téléphone. Il n'y a pas d'entrepôt ; la connexion est directe, privée et chiffrée.

---

## 🎯 Pourquoi utiliser Syncthing ?

-   ✅ **Confidentialité Absolue** : Il n'y a pas de serveur central. Vos fichiers ne sont jamais stockés sur un serveur tiers. Ils ne transitent que de votre appareil A à votre appareil B.
-   ✅ **Pas de Limites de Stockage (ou presque)** : La seule limite est la taille du disque dur de vos appareils. Pas d'abonnement pour plus d'espace.
-   ✅ **Efficacité sur Réseau Local** : Si votre ordinateur et votre téléphone sont sur le même Wi-Fi, la synchronisation est ultra-rapide car elle ne passe pas par Internet.
-   ✅ **Contrôle Total** : Vous décidez quels dossiers sont partagés, avec quels appareils, et dans quel sens (envoi seul, réception seule, ou les deux).
-   ✅ **Open Source** : Le code est transparent et vérifiable par tous.

### Quand choisir Syncthing plutôt que Nextcloud/FileBrowser ?

-   **Nextcloud** est une suite complète (fichiers, calendrier, contacts...). C'est l'entrepôt central que vous hébergez vous-même.
-   **Syncthing** ne fait qu'une seule chose : synchroniser des fichiers. Il ne propose pas d'interface web pour voir vos fichiers, pas de calendrier, etc. C'est le téléporteur.

Utilisez Syncthing si votre seul besoin est de garder des dossiers synchronisés entre plusieurs appareils de manière décentralisée.

---

## ✨ Concepts Clés

Pour comprendre Syncthing, il faut connaître deux choses :

1.  **L'ID d'Appareil (Device ID)** : C'est comme le numéro de téléphone de votre appareil. Chaque appareil Syncthing a un identifiant unique et long. Pour que deux appareils puissent se parler, ils doivent d'abord échanger leurs IDs.

2.  **Le Partage de Dossier (Folder Share)** : Une fois que deux appareils se connaissent, l'un peut proposer de partager un dossier. L'autre doit accepter le partage pour que la synchronisation commence.

---

## 🚀 Comment l'utiliser ? (Exemple : synchroniser des photos de votre téléphone vers votre Pi)

### Étape 1 : Connecter votre téléphone et votre Pi

(Cette étape est détaillée dans le guide [d'installation](syncthing-setup.md))

1.  Installez une application Syncthing sur votre téléphone (ex: Mobiussync sur Android).
2.  Ajoutez l'ID de votre Pi sur votre téléphone.
3.  Acceptez le nouvel appareil (votre téléphone) sur l'interface web de votre Pi.

### Étape 2 : Partager le dossier de photos depuis votre téléphone

1.  Dans l'application Syncthing sur votre téléphone, allez dans l'onglet "Dossiers".
2.  Cliquez sur `+` pour ajouter un dossier.
3.  Donnez-lui un nom (ex: "Photos de mon téléphone").
4.  Sélectionnez le chemin du dossier de l'appareil photo (souvent `/DCIM/Camera`).
5.  Allez dans l'onglet "Partage" et cochez la case correspondant à votre Raspberry Pi.
6.  Enregistrez.

### Étape 3 : Accepter le dossier sur votre Pi

1.  Sur l'interface web de Syncthing sur votre Pi, une notification apparaît : "Votre téléphone veut partager le dossier 'Photos de mon téléphone'".
2.  Cliquez sur **"Ajouter"**.
3.  **Choisissez le chemin de destination** sur votre Pi. C'est là que les photos seront copiées. Par exemple : `/home/pi/data/photos_telephone`.
4.  Enregistrez.

La synchronisation commence ! Toutes les photos de votre téléphone vont être copiées sur votre Pi. Chaque nouvelle photo que vous prendrez sera automatiquement envoyée sur le Pi.

---

## 💡 Astuces

-   **Type de Dossier** : Lors du partage, vous pouvez choisir le type :
    -   `Send & Receive` (par défaut) : Les changements sont synchronisés dans les deux sens.
    -   `Send Only` : L'appareil ne fait qu'envoyer les changements, il n'accepte pas ceux des autres.
    -   `Receive Only` : L'appareil ne fait que recevoir les changements. Utile pour un dossier de sauvegarde.
-   **Versioning de Fichiers** : Syncthing peut être configuré pour garder les anciennes versions d'un fichier au cas où vous feriez une erreur. (Dans les options du dossier > `File Versioning`).
-   **Ignore Patterns** : Vous pouvez dire à Syncthing d'ignorer certains fichiers ou sous-dossiers (comme les miniatures `.thumbnails`).

---

## 🆘 Problèmes Courants

### "Mes appareils ne se connectent pas"

-   Assurez-vous que les deux appareils sont bien allumés et que Syncthing est en cours d'exécution.
-   Vérifiez que vous n'avez pas fait d'erreur en copiant l'ID de l'appareil.
-   Si les appareils sont sur des réseaux différents (ex: l'un à la maison, l'autre en 4G), la connexion peut prendre plus de temps car elle doit passer par des serveurs relais publics. Soyez patient.

### "La synchronisation est bloquée à X%"

-   Cela arrive souvent quand des fichiers sont en cours d'utilisation sur l'un des appareils. Assurez-vous qu'aucun programme n'a verrouillé un fichier dans le dossier synchronisé.
-   Vérifiez les permissions des fichiers. Syncthing doit avoir le droit de lire et d'écrire dans les dossiers que vous partagez.

Syncthing est un outil incroyablement puissant pour ceux qui recherchent une solution de synchronisation de fichiers décentralisée et privée. Il demande un peu plus de configuration initiale que Dropbox, mais le gain en confidentialité et en contrôle est immense.
