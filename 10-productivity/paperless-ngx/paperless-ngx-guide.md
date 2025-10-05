# 📚 Guide Débutant - Paperless-ngx

> **Pour qui ?** Celles et ceux qui se noient sous la paperasse et rêvent d'un bureau numérique.
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Paperless-ngx ?

### En une phrase
**Paperless-ngx = Votre armoire à classeurs numérique et intelligente, qui scanne, lit et organise tous vos documents à votre place.**

### Analogie simple
Imaginez que vous avez une boîte à chaussures remplie de factures, de fiches de paie, de contrats et de courriers importants. Pour retrouver un document, c'est un cauchemar.

Maintenant, imaginez que vous avez un assistant personnel. Vous lui donnez un document, il le lit, surligne les informations importantes (date, expéditeur, montant), le range dans le bon classeur et colle une étiquette dessus. Pour retrouver une facture, il vous suffit de lui demander "Montre-moi toutes les factures d'électricité de 2023", et il vous les sort instantanément.

**Paperless-ngx est cet assistant.**

---

## 🎯 Pourquoi passer au "Zéro Papier" ?

-   ✅ **Recherche Instantanée** : Retrouvez n'importe quel document en quelques secondes grâce à la recherche plein texte. Tapez "garantie frigo" et il retrouvera la facture d'achat, même si le mot "garantie" n'est pas dans le nom du fichier.
-   ✅ **Organisation Automatique** : Paperless-ngx peut automatiquement ajouter des tags, des dates et des correspondants à vos documents.
-   ✅ **Gain de Place** : Dites adieu aux classeurs et aux piles de papier.
-   ✅ **Accès Partout** : Accédez à vos documents importants depuis votre ordinateur ou votre téléphone, où que vous soyez.
-   ✅ **Sécurité** : Vos documents sont stockés en toute sécurité chez vous, et non sur un cloud tiers.

---

## ✨ Fonctionnalités Clés

-   **OCR (Reconnaissance Optique de Caractères)** : C'est la magie de Paperless. Il transforme l'image de vos documents scannés en texte sélectionnable et consultable. Il lit vos documents pour vous.
-   **Tags, Correspondants, Types de documents** : Classez vos documents avec une flexibilité totale. (Tags: `facture`, `maison`, `urgent`; Correspondant: `EDF`, `Impots`; Type: `Contrat`, `Relevé bancaire`).
-   **Apprentissage Automatique (IA)** : Après avoir classé quelques documents, Paperless apprend. Quand vous ajouterez une nouvelle facture EDF, il proposera automatiquement le correspondant `EDF` et le tag `facture`.
-   **Consommation par Email** : Transférez un email avec une pièce jointe (comme une facture en PDF) à une adresse email dédiée, et Paperless l'importera automatiquement.
-   **Tableau de Bord Personnalisable** : Affichez les documents récents, les tâches à faire, et des statistiques.

---

## 🚀 Comment l'utiliser ? (Workflow typique)

### Étape 1 : Numériser un document

La première étape est de transformer votre document papier en fichier numérique (PDF de préférence).

-   **Avec un scanner de bureau** : Scannez vos documents et enregistrez-les dans un dossier sur votre ordinateur.
-   **Avec votre téléphone** : Utilisez une application de scan comme **Microsoft Lens**, **Adobe Scan** ou **Genius Scan**. Ces applications redressent l'image et améliorent la lisibilité, ce qui est idéal pour l'OCR.

### Étape 2 : Envoyer le document à Paperless

Paperless surveille un dossier spécial appelé `consume`. Tout ce que vous mettez dedans est automatiquement importé.

1.  **Accédez au dossier `consume`** sur votre Pi. Le chemin est `/home/pi/stacks/paperless-ngx/consume`.
2.  **Copiez votre PDF** dans ce dossier. Vous pouvez le faire via le réseau (partage de fichiers Samba) ou avec un outil comme FileZilla (SFTP).

Le fichier va disparaître du dossier `consume` après quelques secondes. C'est normal ! Cela signifie que Paperless l'a pris en charge.

### Étape 3 : Vérifier et classer le document

1.  **Retournez sur l'interface web** de Paperless-ngx.
2.  Votre nouveau document devrait apparaître sur le tableau de bord ou dans la vue "Documents".
3.  **Ouvrez-le.** Paperless a déjà effectué l'OCR. Vous pouvez voir le texte extrait dans l'onglet "Contenu".
4.  **Paperless a peut-être déjà suggéré des tags, un correspondant ou une date.** C'est l'IA en action ! Acceptez ou corrigez ses suggestions.
5.  Ajoutez manuellement les informations que vous souhaitez.
6.  **Sauvegardez.**

### Étape 4 : Retrouver votre document

C'est là que la puissance de Paperless se révèle.

-   **Barre de recherche** : Tapez n'importe quel mot présent dans le document. Le nom de l'entreprise, un montant, une référence de produit... Paperless le trouvera.
-   **Filtres** : Utilisez les filtres sur la gauche pour affiner par tag, correspondant, type de document, etc.

---

## 💡 Astuces pour bien démarrer

-   **Commencez petit** : Ne scannez pas 10 ans d'archives d'un coup. Commencez avec les nouveaux documents que vous recevez. Une fois que votre système de classement est en place, vous pourrez numériser les anciens documents par lots.
-   **La qualité du scan est primordiale** : Un scan propre, droit et bien éclairé donnera de bien meilleurs résultats à l'OCR.
-   **Pensez à votre structure de classement** : Quels tags et correspondants seront utiles pour vous ? Ne créez pas trop de tags au début. (Exemples : `finance`, `santé`, `voiture`, `maison`, `garanties`).
-   **Utilisez l'application mobile** : Il existe des applications tierces pour Paperless-ngx (comme `Paperless-App` sur Android) qui vous permettent de consulter vos documents et même d'uploader des scans directement depuis votre téléphone.

---

Félicitations, vous êtes sur la voie d'un bureau parfaitement organisé et sans papier !
