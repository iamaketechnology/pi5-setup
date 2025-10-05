# 📚 Guide Débutant - Vaultwarden

> **Pour qui ?** Toute personne utilisant des mots de passe (donc, tout le monde !).
> **Durée de lecture** : 10 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Vaultwarden ?

### En une phrase
**Vaultwarden = Votre coffre-fort numérique personnel et ultra-sécurisé pour tous vos mots de passe, hébergé chez vous.**

C'est une version légère et auto-hébergeable du populaire gestionnaire de mots de passe **Bitwarden**.

### Analogie simple
Imaginez que vous avez des dizaines de clés pour votre maison, votre voiture, votre bureau, votre casier, etc. Au lieu de les avoir en vrac dans votre poche, vous les mettez dans un **coffre-fort** dont vous seul connaissez la combinaison.

Vaultwarden est ce coffre-fort. Vos "clés" sont vos mots de passe pour Google, Facebook, Amazon, etc. Vous n'avez besoin de retenir qu'**une seule combinaison** : votre **mot de passe maître**.

---

## 🎯 Pourquoi utiliser un gestionnaire de mots de passe ?

Le problème : nous avons des dizaines de comptes en ligne. La plupart des gens font une ou plusieurs de ces erreurs :
- **Utiliser le même mot de passe partout.** (Si un site est piraté, tous vos comptes sont en danger).
- **Utiliser des mots de passe faibles.** (`azerty123`, `doudou`, le nom de votre chat...).
- **Les noter sur un post-it** ou dans un fichier texte non sécurisé.

### La solution : Vaultwarden

1.  **Génère des mots de passe uniques et forts** pour chaque site (ex: `k$p#Z8@v!Lq7&J*r`).
2.  **Les sauvegarde de manière chiffrée** dans votre coffre-fort sur votre Raspberry Pi.
3.  **Remplit automatiquement** les identifiants et mots de passe quand vous vous connectez à un site.

**Bénéfices :**
- ✅ **Sécurité maximale** : Chaque compte a un mot de passe différent et complexe.
- ✅ **Simplicité** : Vous n'avez qu'un seul mot de passe à retenir.
- ✅ **Contrôle total** : Vos données sont chez vous, pas sur les serveurs d'une entreprise tierce.
- ✅ **Gratuit** : Toutes les fonctionnalités premium de Bitwarden (partage, etc.) sont gratuites avec Vaultwarden.

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Étape 1 : Créer votre compte

C'est la première chose à faire après l'installation. Voir le guide [d'installation](passwords-setup.md).

### Étape 2 : Installer les clients Bitwarden

Le gros avantage de Vaultwarden est qu'il utilise les applications officielles de Bitwarden, qui sont excellentes.

-   **Extension de navigateur (INDISPENSABLE)** : Allez sur le store de votre navigateur (Chrome, Firefox, Edge, Safari) et cherchez "Bitwarden".
-   **Application mobile** : Cherchez "Bitwarden" sur l'App Store (iOS) ou le Google Play Store (Android).
-   **Application de bureau** : Pour Windows, macOS et Linux, disponible sur le site de Bitwarden.

### Étape 3 : Configurer le client pour utiliser VOTRE serveur

C'est l'étape cruciale pour connecter l'application Bitwarden à votre Vaultwarden.

1.  Ouvrez l'application Bitwarden que vous venez d'installer.
2.  **Avant de taper votre email**, cherchez une icône d'engrenage ⚙️ ou un lien "Paramètres" / "Se connecter sur un serveur auto-hébergé".
3.  Dans le champ **"URL du serveur"** (ou "Server URL"), entrez l'adresse de votre instance Vaultwarden. (Celle qui s'est affichée à la fin de l'installation, ex: `https://vault.mon-domaine.com`).
4.  Sauvegardez ce paramètre.
5.  Maintenant, vous pouvez vous connecter avec votre email et votre mot de passe maître.

### Étape 4 : Ajouter votre premier mot de passe

**Option A : Manuellement**
1.  Dans l'extension ou l'application, cliquez sur "Ajouter un élément".
2.  Remplissez les champs : nom (ex: "Google"), identifiant (votre email), mot de passe.
3.  Sauvegardez.

**Option B : Automatiquement (recommandé)**
1.  Allez sur la page de connexion d'un site où vous avez un compte.
2.  Connectez-vous comme d'habitude.
3.  Bitwarden va afficher une petite barre en haut de la page vous demandant : **"Voulez-vous ajouter cette connexion à votre coffre-fort ?"**
4.  Cliquez sur "Oui, sauvegarder maintenant".

### Étape 5 : Utiliser le remplissage automatique

La prochaine fois que vous irez sur ce site, l'icône de Bitwarden dans les champs de connexion affichera un petit chiffre. Cliquez dessus, puis sur le nom du compte, et Bitwarden remplira tout pour vous !

---

## 🔄 Importer vos mots de passe existants

Vous utilisiez le gestionnaire de mots de passe de votre navigateur (Chrome, Firefox) ou un autre service (LastPass, Dashlane) ? Vous pouvez tout importer !

1.  **Exportez vos mots de passe** depuis votre ancien gestionnaire. Cherchez une option "Exporter" dans les paramètres. Choisissez le format `.csv`.
2.  **Connectez-vous à l'interface WEB** de votre Vaultwarden.
3.  Allez dans **Outils > Importer des données**.
4.  Choisissez le format de fichier (ex: "Chrome (csv)", "LastPass (csv)").
5.  Sélectionnez votre fichier `.csv` et cliquez sur "Importer les données".

⚠️ **Supprimez le fichier `.csv` de votre ordinateur après l'importation, car il contient tous vos mots de passe en clair !**

---

## 💡 Astuces de Pro

-   **Utilisez le générateur de mots de passe** de Bitwarden pour créer de nouveaux mots de passe ultra-robustes.
-   **Activez l'authentification à deux facteurs (2FA)** sur votre compte Vaultwarden pour une sécurité maximale. (Dans l'interface web : Paramètres > Sécurité > Authentification à deux facteurs).
-   **Stockez plus que des mots de passe** : cartes d'identité, cartes bancaires, notes sécurisées...
-   **Utilisez les "Organisations"** pour partager en toute sécurité des mots de passe avec votre famille ou vos collègues.

---

Félicitations ! Vous avez fait un grand pas pour sécuriser votre vie numérique.
