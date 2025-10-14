# ⚡ Installation Rapide - Ollama + Open WebUI

> **Installation directe via SSH pour héberger votre propre IA de chat.**

---

## 🚀 Installation en 1 Commande

**Copier-coller cette commande dans votre terminal SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/01-ollama-deploy.sh | sudo bash
```

**Ce qui sera déployé :**
- ✅ **Ollama** : Le serveur qui fait tourner les modèles de langage.
- ✅ **Open WebUI** : L'interface de chat web, similaire à ChatGPT.

**Durée :**
- Images Docker : ~10-15 min (téléchargement en arrière-plan)
- Modèle IA (manuel) : ~5-10 min supplémentaires

**Note** : Le script lance l'installation en arrière-plan et termine immédiatement. Suivez la progression avec `docker compose logs -f`.

---

## ✅ Vérification de l'Installation

### Vérifier les services

```bash
cd ~/stacks/ollama
docker compose ps
```
Les services `ollama` et `open-webui` doivent être en état `Up` ou `Up (healthy)`.

### Accéder à l'Interface Web

L'URL dépend de votre configuration Traefik :
- **Avec Traefik (DuckDNS)** : `https://ai.VOTRE-SOUS-DOMAINE.duckdns.org`
- **Avec Traefik (Cloudflare)** : `https://ai.VOTRE-DOMAINE.com`
- **Sans Traefik (local)** : `http://pi5.local:3002` ou `http://<IP-DU-PI>:3002`

⚠️ **Note** : Le port par défaut est **3002** (pas 3000) pour éviter les conflits avec Supabase Studio.

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Vérifiez que les services sont UP** :
    ```bash
    docker ps | grep ollama
    ```
    Attendez que les deux containers (`ollama` et `open-webui`) soient en état `Up`.

2.  **Téléchargez vos premiers modèles** :

    **Option A : Script Intelligent (Recommandé)**
    ```bash
    curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/02-download-models.sh | sudo bash
    ```
    - Menu interactif avec 11 modèles optimisés Pi 5
    - Sélection multiple ou packs pré-configurés
    - Pack Recommandé : gemma2:2b + phi3:3.8b + qwen2.5-coder:1.5b

    **Option B : Manuel (un seul modèle)**
    ```bash
    docker exec ollama ollama pull phi3:3.8b
    ```
    - Télécharge phi3 uniquement (2.3 GB, ~5-10 min)

3.  **Ouvrez l'interface Open WebUI** avec l'URL ci-dessus.

4.  **Créez un compte administrateur** : La première fois, il vous sera demandé de créer un compte admin. Ce compte est pour l'interface web seulement.

5.  **Sélectionnez le modèle** : En haut de l'interface, cliquez sur le menu déroulant et sélectionnez un modèle (ex: `gemma2:2b`).

6.  **Commencez à chatter !**

---

## 🧠 Gérer les Modèles de Langage

### 🎯 Téléchargement Intelligent (Recommandé)

**Menu interactif avec modèles optimisés** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/02-download-models.sh | sudo bash
```

**Modèles disponibles** :
- **Chat rapide** : gemma2:2b (8-10 tok/s), llama3.2:3b
- **Code** : qwen2.5-coder:1.5b, deepseek-coder-v2:16b
- **Multilingue** : aya-expanse:8b (100+ langues)
- **Vision** : llava:7b (analyse d'images)
- **Multitâche** : phi3:3.8b, mistral:7b

**Packs pré-configurés** :
- **Pack Recommandé** : gemma2:2b + phi3:3.8b + qwen2.5-coder:1.5b
- **Pack Développeur** : qwen2.5-coder:1.5b + deepseek-coder-v2:16b + phi3:3.8b
- **Pack Multilingue** : aya-expanse:8b + gemma2:2b

### 🔄 Mise à Jour Automatique

**Mettre à jour tous les modèles installés** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/03-update-models.sh | sudo bash
```

**Planifier les mises à jour hebdomadaires** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/03-update-models.sh | sudo bash -s -- --setup-cron
```

### 🛠️ Gestion Manuelle

**Télécharger un modèle spécifique** :
1. Trouvez un modèle sur la [bibliothèque Ollama](https://ollama.com/library) (ex: `llama3:8b`)
2. Exécutez :
```bash
docker exec ollama ollama pull llama3:8b
```

**Lister les modèles installés** :
```bash
docker exec ollama ollama list
```

**Supprimer un modèle** :
```bash
docker exec ollama ollama rm phi3:3.8b
```

### 🎨 Changer de Modèle dans l'Interface Web

En haut de l'interface de chat, cliquez sur le nom du modèle actuel pour en sélectionner un autre parmi ceux que vous avez téléchargés.

---

## 📚 Documentation Complète

- **[ollama-guide.md](ollama-guide.md)** - Pour apprendre à utiliser l'interface et à choisir les bons modèles.
- **[README.md](README.md)** - Vue d'ensemble technique du stack Ollama.
