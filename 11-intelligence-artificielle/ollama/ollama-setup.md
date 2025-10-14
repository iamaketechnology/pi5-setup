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

2.  **Téléchargez votre premier modèle** :
    ```bash
    docker exec ollama ollama pull phi3:3.8b
    ```
    Ceci télécharge le modèle phi3 (2.3 GB, ~5-10 min).

3.  **Ouvrez l'interface Open WebUI** avec l'URL ci-dessus.

4.  **Créez un compte administrateur** : La première fois, il vous sera demandé de créer un compte admin. Ce compte est pour l'interface web seulement.

5.  **Sélectionnez le modèle** : En haut de l'interface, cliquez sur le menu déroulant et sélectionnez `phi3:3.8b`.

6.  **Commencez à chatter !**

---

## 🧠 Gérer les Modèles de Langage

L'interface web vous permet de discuter avec les modèles, mais la gestion (ajout/suppression) se fait en ligne de commande.

### Télécharger un Nouveau Modèle

1.  Trouvez un modèle sur la [bibliothèque Ollama](https://ollama.com/library) (ex: `llama3:8b`).
2.  Exécutez la commande suivante sur votre Pi :

```bash
docker exec ollama ollama pull llama3:8b
```

### Lister les Modèles

```bash
docker exec ollama ollama list
```

### Changer de Modèle dans l'Interface Web

En haut de l'interface de chat, cliquez sur le nom du modèle actuel pour en sélectionner un autre parmi ceux que vous avez téléchargés.

---

## 📚 Documentation Complète

- **[ollama-guide.md](ollama-guide.md)** - Pour apprendre à utiliser l'interface et à choisir les bons modèles.
- **[README.md](README.md)** - Vue d'ensemble technique du stack Ollama.
