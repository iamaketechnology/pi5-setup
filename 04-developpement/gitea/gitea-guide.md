# 🎓 Guide Débutant : Gitea

> **Pour qui ?** : Développeurs, hobbyistes, et toute personne souhaitant héberger son propre code avec un contrôle total.

---

## 📖 C'est Quoi Gitea ?

### Analogie Simple

Imaginez que **GitHub** est un immense service de stockage de documents en ligne, comme Google Drive, mais spécialisé pour le code. C'est pratique, mais vos documents sont sur les serveurs de quelqu'un d'autre, avec leurs règles et leurs limites.

**Gitea, c'est comme avoir votre propre serveur de documents personnel et surpuissant à la maison.**

*   **Votre propre bibliothèque** : Vous pouvez y stocker autant de projets (documents) que vous voulez, sans limite.
*   **100% privé** : Seules les personnes que vous invitez peuvent y accéder. Vos secrets de fabrication restent chez vous.
*   **Votre propre robot assistant (CI/CD)** : Vous pouvez lui donner des recettes pour qu'il teste, compile et organise vos documents automatiquement chaque fois que vous en modifiez un.

En bref, Gitea est une alternative à GitHub que vous installez sur votre propre matériel (votre Raspberry Pi), vous donnant un contrôle total, une confidentialité absolue et des fonctionnalités illimitées, le tout gratuitement.

### En Termes Techniques

Gitea est un service de forge logicielle, léger et auto-hébergé. Il est écrit en Go et est conçu pour être extrêmement performant avec une faible consommation de ressources, ce qui le rend parfait pour un Raspberry Pi. Il inclut :

*   Un serveur Git pour héberger les dépôts.
*   Une interface web pour la gestion des projets, des `Issues` et des `Pull Requests`.
*   Un moteur de CI/CD intégré, **Gitea Actions**, compatible avec la syntaxe des GitHub Actions.
*   Un registre de paquets (Docker, npm, etc.).

---

## 🎯 Cas d'Usage Concrets

### Scénario 1 : Le développeur freelance
*   **Contexte** : Vous gérez des projets pour plusieurs clients et vous ne pouvez pas héberger leur code sur une plateforme publique.
*   **Solution** : Vous créez une organisation par client sur votre Gitea. Chaque projet est un dépôt privé. Vous pouvez même donner un accès limité à vos clients pour qu'ils suivent l'avancement via les `Issues`.

### Scénario 2 : L'étudiant en informatique
*   **Contexte** : Vous avez des dizaines de projets scolaires et personnels. Vous voulez un endroit pour les archiver et montrer votre travail à de futurs employeurs.
*   **Solution** : Gitea vous sert de portfolio de code. Pour chaque projet, vous avez un historique complet. Le workflow CI/CD peut même compiler automatiquement vos projets et déployer les démos en ligne.

### Scénario 3 : Le passionné de domotique
*   **Contexte** : Vous avez des dizaines de scripts et de fichiers de configuration pour votre installation Home Assistant.
*   **Solution** : Vous stockez toute votre configuration sur Gitea. Quand vous modifiez une automatisation, vous `push` le changement. Un workflow Gitea Actions valide la syntaxe de votre configuration et, si tout est bon, redémarre automatiquement votre Home Assistant.

---

## 🤖 CI/CD avec Gitea Actions

C'est la fonctionnalité la plus puissante de Gitea. Le CI/CD (Intégration Continue / Déploiement Continu) est votre robot personnel qui travaille pour vous.

**Exemple de workflow :**

1.  Vous modifiez le code de votre blog et vous `push` les changements sur Gitea.
2.  **Gitea Actions se réveille** et suit la recette que vous avez écrite dans un fichier `.gitea/workflows/deploy.yml`.
3.  **Le robot** :
    *   Lance les tests pour s'assurer que vous n'avez rien cassé.
    *   Si les tests sont OK, il "construit" votre blog (génère les fichiers HTML statiques).
    *   Il se connecte ensuite à votre serveur web et y copie les nouveaux fichiers.
4.  Vous recevez une notification sur Discord : "✅ Blog déployé avec succès !".

Tout cela se passe en quelques minutes, sans aucune intervention manuelle. Vous pouvez ainsi déployer des mises à jour plusieurs fois par jour sans effort.

### Exemples de Workflows

*   **Tester votre code** : À chaque `push`, lancez `npm test` ou `pytest`.
*   **Construire une image Docker** : Quand vous taguez une nouvelle version (`v1.2.0`), construisez l'image Docker et poussez-la sur le registre de Gitea ou sur Docker Hub.
*   **Déployer un site web** : À chaque `push` sur la branche `main`, déployez le site sur votre serveur de production.
*   **Sauvegarder vos données** : Tous les soirs à 3h du matin, un workflow peut se lancer pour sauvegarder la base de données de Gitea sur un cloud externe.

---

## 🚀 Premiers Pas

### Installation

Pour installer Gitea, suivez le guide d'installation détaillé :

➡️ **[Consulter le Guide d'Installation de Gitea](gitea-setup.md)**

### Créer votre premier projet

1.  **Connectez-vous** à votre interface Gitea.
2.  Cliquez sur le `+` en haut à droite, puis sur **Nouveau Dépôt**.
3.  Donnez un nom à votre projet, rendez-le privé si vous le souhaitez, et cochez "Initialiser le dépôt avec un README".
4.  Cliquez sur **Créer le dépôt**.
5.  Suivez les instructions affichées pour cloner le dépôt sur votre ordinateur et y pousser votre premier commit.

---

## 🐛 Dépannage Débutants

### Problème 1 : `git push` échoue avec une erreur "Permission denied"
*   **Symptôme** : Vous ne pouvez pas pousser votre code vers Gitea.
*   **Cause** : Votre clé SSH n'est pas correctement configurée.
*   **Solution** : Assurez-vous d'avoir bien ajouté la clé SSH **publique** de votre ordinateur dans les paramètres de votre compte Gitea. Vérifiez aussi que vous utilisez la bonne URL de clonage (celle en `ssh://`).

### Problème 2 : Mon workflow ne se lance pas
*   **Symptôme** : Vous poussez du code, mais rien ne se passe dans l'onglet "Actions".
*   **Cause** : Le fichier de workflow est peut-être mal placé ou contient une erreur de syntaxe.
*   **Solution** : 
    1.  Vérifiez que votre fichier de workflow se trouve bien dans le dossier `.gitea/workflows/` (et non `.github/workflows/`).
    2.  Vérifiez la syntaxe de votre fichier YAML avec un validateur en ligne.
    3.  Assurez-vous que le "runner" Gitea Actions est bien en cours d'exécution (voir le guide d'installation).

---

## 📚 Ressources d'Apprentissage

*   [Documentation Officielle de Gitea](https://docs.gitea.io/)
*   [Documentation sur Gitea Actions](https://docs.gitea.io/en-us/usage/actions/overview/)
*   [Exemples de workflows pour Gitea Actions](examples/workflows/README.md)
