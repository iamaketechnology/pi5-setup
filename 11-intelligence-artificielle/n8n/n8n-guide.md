# 🎓 Guide Débutant - n8n : Votre Couteau Suisse pour l'Automatisation et l'IA

> **Pour qui ?** Toute personne souhaitant automatiser des tâches répétitives, connecter des applications entre elles, ou expérimenter avec l'IA sans être un développeur expert.
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi n8n ?

### En une phrase
**n8n est un outil qui vous permet de connecter différentes applications et de créer des chaînes d'actions automatiques, comme un jeu de LEGO pour vos services en ligne.**

### Analogie simple

Imaginez que vous voulez préparer un café :

1.  Vous prenez du café en grains (`Application A`).
2.  Vous le moulez (`Action 1`).
3.  Vous faites passer de l'eau chaude à travers (`Action 2`).
4.  Vous versez le résultat dans une tasse (`Application B`).

**n8n**, c'est la machine à café programmable qui fait tout ça pour vous. Vous lui dites une fois comment faire, et elle le refera à l'infini, à chaque fois que vous appuierez sur un bouton (ou à une heure précise, ou quand un événement se produit).

Dans le monde numérique, cela pourrait être :
1.  Quand un **nouvel email arrive sur Gmail** (`Application A`).
2.  **Extraire la pièce jointe** (`Action 1`).
3.  **La sauvegarder sur votre Nextcloud** (`Action 2`).
4.  **Envoyer une notification sur Discord** pour vous prévenir (`Application B`).

---

## 🎯 Pourquoi utiliser n8n ?

-   **Gagner du temps** : Automatisez les tâches ennuyeuses et répétitives.
-   **Connecter l'inconnectable** : Faites communiquer des applications qui n'ont pas d'intégration native entre elles.
-   **Devenir plus intelligent** : Intégrez de l'IA dans vos processus quotidiens sans effort.
-   **Garder le contrôle** : Puisque n8n est hébergé sur votre Pi, vos données et vos clés d'API restent chez vous.

---

## ✨ Concepts Clés de n8n

L'interface de n8n est un grand canevas blanc où vous connectez des "nœuds" (nodes).

1.  **Nœud (Node)** : C'est une brique de base qui représente une application ou une action. Exemples : `Gmail`, `Google Sheets`, `OpenAI`, `Discord`, `HTTP Request`.

2.  **Workflow** : C'est l'ensemble de votre chaîne de nœuds, votre "recette" d'automatisation.

3.  **Trigger (Déclencheur)** : C'est le premier nœud du workflow, celui qui démarre tout. Exemples : `Cron` (toutes les heures), `Webhook` (quand une autre application l'appelle), `On new email`.

4.  **Credentials (Identifiants)** : Pour que n8n puisse se connecter à vos comptes (Google, Discord, etc.), vous devez lui fournir des clés d'API ou l'autoriser via OAuth2. n8n les stocke de manière sécurisée et chiffrée.

---

## 🚀 Votre Premier Workflow : "Bonjour le Monde de l'IA"

Créons un workflow simple qui demande à une IA de nous raconter une blague et la publie sur Discord.

### Étape 1 : Créer un nouveau workflow

1.  Connectez-vous à votre interface n8n.
2.  Cliquez sur **"Add Workflow"**.

### Étape 2 : Le Nœud de Démarrage (Trigger)

Par défaut, vous avez un nœud **"Start"**. C'est un déclencheur manuel. Parfait pour tester.

### Étape 3 : Ajouter un Nœud OpenAI

1.  Cliquez sur le `+` après le nœud "Start".
2.  Dans la barre de recherche, tapez `OpenAI` et sélectionnez-le.
3.  **Credentials** : Vous devrez ajouter une clé d'API OpenAI. Vous pouvez en obtenir une sur le [site d'OpenAI](https://platform.openai.com/api-keys).
4.  **Resource** : Choisissez `Chat Model`.
5.  **Model** : Choisissez `gpt-3.5-turbo` (ou un autre modèle disponible).
6.  Dans la section **"Messages"**, pour le rôle `User`, écrivez le prompt : `Raconte-moi une blague courte sur les ordinateurs.`

### Étape 4 : Ajouter un Nœud Discord

1.  Cliquez sur le `+` après le nœud OpenAI.
2.  Cherchez et sélectionnez `Discord`.
3.  **Credentials** : Vous devrez créer un "Webhook" dans les paramètres de votre serveur Discord (Paramètres du serveur > Intégrations > Webhooks > Nouveau Webhook). Copiez l'URL du webhook et collez-la ici.
4.  Dans le champ **"Content"**, nous allons utiliser le résultat du nœud précédent. Cliquez sur l'icône `{=}` à droite du champ, et naviguez pour trouver la réponse de l'IA. Cela ressemblera à quelque chose comme `{{ $json["choices"][0]["message"]["content"] }}`.

### Étape 5 : Tester !

1.  En bas de l'écran, cliquez sur **"Test Workflow"**.
2.  n8n va exécuter chaque nœud l'un après l'autre. Vous verrez des coches vertes apparaître.
3.  Vérifiez votre salon Discord : la blague devrait y être !

### Étape 6 : Activer le Workflow

En haut à droite, basculez le bouton de **"Inactive"** à **"Active"**. Votre workflow est maintenant prêt à être déclenché.

---

## 🧠 Exemples de Workflows avec IA

-   **Résumé de Réunions** : Connectez n8n à votre calendrier. Quand une réunion se termine, récupérez la transcription (si disponible), envoyez-la à une IA pour un résumé, et postez le résumé dans un salon Slack.
-   **Tri d'Emails** : Analysez les emails entrants. Si un email semble être une facture, extrayez les informations (montant, date, fournisseur) avec une IA et ajoutez une ligne à un Google Sheet.
-   **Génération d'Images** : Créez un workflow qui, chaque jour, génère une image avec DALL-E sur un thème précis et la poste sur votre compte Instagram.
-   **Veille Concurrentielle** : Surveillez les flux RSS de vos concurrents. Quand un nouvel article est publié, demandez à une IA de le résumer et de vous envoyer les points clés par email.

Les possibilités sont infinies. Si vous pouvez le décomposer en étapes logiques, vous pouvez probablement l'automatiser avec n8n.
