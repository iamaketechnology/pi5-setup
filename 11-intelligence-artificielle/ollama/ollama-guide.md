# 🎓 Guide Débutant - Ollama : Votre ChatGPT Personnel sur Raspberry Pi

> **Pour qui ?** Toute personne curieuse de l'IA, souhaitant avoir son propre assistant intelligent privé, ou voulant expérimenter avec les modèles de langage sans frais.
> **Durée de lecture** : 15 minutes
> **Niveau** : Débutant

---

## 🤔 C'est quoi Ollama ?

### En une phrase
**Ollama est un outil qui installe et fait fonctionner des intelligences artificielles comme ChatGPT directement sur votre Raspberry Pi, de manière 100% privée et gratuite.**

### Analogie simple

Imaginez que les grands modèles d'IA (comme ceux de Google, OpenAI, etc.) sont des **chefs cuisiniers étoilés** qui travaillent dans des restaurants très chers et lointains (le cloud).

**Ollama**, c'est comme si vous aviez un de ces chefs étoilés qui venait cuisiner **directement dans votre cuisine** (votre Raspberry Pi). 

-   **C'est privé** : Personne ne sait ce que vous lui demandez de cuisiner.
-   **C'est gratuit** : Une fois le chef installé, vous pouvez lui demander autant de plats que vous voulez.
-   **C'est personnalisable** : Vous pouvez choisir votre chef (Llama 3, Mistral, Phi-3) et même lui apprendre de nouvelles recettes.

L'interface **Open WebUI** est le **menu interactif** qui vous permet de parler facilement avec votre chef cuisinier.

---

## 🎯 Pourquoi est-ce si puissant ?

-   **Confidentialité absolue** : Posez des questions sur des sujets sensibles, personnels ou professionnels, sans craindre que vos données soient utilisées pour entraîner de futurs modèles ou lues par une entreprise.
-   **Pas de facture surprise** : Expérimentez, posez des milliers de questions, générez des textes longs... C'est illimité et gratuit.
-   **Fonctionne sans Internet** : Une fois un modèle téléchargé, vous pouvez utiliser votre IA même si votre connexion internet est coupée.
-   **Explorez des modèles variés** : Accédez à une immense bibliothèque de modèles open-source, chacun avec sa propre personnalité et ses propres forces (créativité, codage, concision, etc.).

---

## 🚀 Premiers Pas avec Open WebUI

Après l'installation, vous accédez à une interface de chat qui ressemble beaucoup à ChatGPT.

### 1. Sélectionner un Modèle

En haut de l'interface, vous pouvez voir le modèle actuellement chargé (par défaut, `phi3:3.8b`). Si vous avez téléchargé d'autres modèles, vous pouvez basculer entre eux ici.

### 2. Démarrer une Conversation

C'est aussi simple que d'utiliser n'importe quel autre chatbot. Tapez votre question dans la zone de texte et appuyez sur Entrée.

**Idées de prompts pour commencer :**
-   `Explique-moi le concept de la blockchain comme si j'avais 10 ans.`
-   `Écris-moi un email professionnel pour demander une augmentation.`
-   `Donne-moi une recette de cuisine simple et rapide pour ce soir avec des pâtes, des tomates et du fromage.`
-   `Crée un script Python qui renomme tous les fichiers d'un dossier.`

### 3. Créer des "Personas"

Vous pouvez créer des assistants spécialisés. Par exemple, un "Expert en Marketing" ou un "Professeur d'Histoire".

1.  Cliquez sur votre profil en haut à droite → **Settings**.
2.  Allez dans **Prompts**.
3.  Créez un nouveau prompt avec un message système comme : `"Tu es un expert en marketing digital. Tes réponses doivent être concises, stratégiques et orientées résultats."`
4.  Maintenant, vous pouvez démarrer de nouvelles conversations avec cette personnalité.

---

## 🧠 Gérer les Modèles avec Ollama

La gestion des modèles se fait en ligne de commande, via SSH sur votre Pi.

### Lister les Modèles Installés

```bash
docker exec ollama ollama list
```
Cette commande vous montrera tous les modèles que vous avez téléchargés et l'espace qu'ils occupent.

### Télécharger un Nouveau Modèle

1.  Allez sur la [bibliothèque de modèles Ollama](https://ollama.com/library) pour voir ce qui est disponible.
2.  Choisissez un modèle qui vous intéresse. Les plus populaires sont souvent les meilleurs pour commencer (ex: `llama3`, `mistral`).
3.  Copiez le nom du modèle (ex: `llama3:8b`).
4.  Sur votre Pi, lancez la commande :

```bash
docker exec ollama ollama pull llama3:8b
```

Le téléchargement peut prendre du temps et de l'espace disque (plusieurs Gigaoctets).

### Discuter avec un Modèle en Ligne de Commande

Pour un test rapide sans passer par l'interface web :

```bash
docker exec -it ollama ollama run llama3:8b
```
Vous entrerez dans un mode de chat interactif directement dans votre terminal.

### Supprimer un Modèle

Si vous manquez d'espace, vous pouvez supprimer les modèles que vous n'utilisez pas :

```bash
docker exec ollama ollama rm nom-du-modele
```

---

## 💡 Astuces et Bonnes Pratiques

-   **Commencez petit** : Les modèles existent en plusieurs tailles (ex: 7 milliards de paramètres, 70 milliards...). Les plus petits sont plus rapides mais moins "intelligents". Pour le Raspberry Pi 5, les modèles entre 3 et 8 milliards de paramètres (`3b` à `8b`) sont un bon compromis.
-   **Soyez précis dans vos prompts** : Plus votre question est détaillée, meilleure sera la réponse. Donnez du contexte, un format de sortie attendu, etc.
-   **Utilisez l'API** : La vraie puissance d'Ollama est son API. Vous pouvez l'appeler depuis vos propres scripts ou d'autres applications (comme n8n) pour automatiser des tâches complexes.

---

Félicitations ! Vous avez maintenant votre propre IA privée, prête à répondre à toutes vos questions, à vous aider à écrire, à coder, et bien plus encore. Le champ des possibles est immense.
