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
- ✅ Le modèle par défaut `phi3:3.8b` sera téléchargé et prêt à l'emploi.

**Durée :** ~10-15 minutes (le téléchargement du modèle initial est volumineux).

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
- **Avec Traefik (Cloudflare)** : `https://ai.VOTRE-DOMAINE.com`
- **Avec Traefik (DuckDNS)** : `https://ai.VOTRE-SOUS-DOMAINE.duckdns.org`
- **Sans Traefik** : `http://<IP-DU-PI>:8080`

L'URL exacte est affichée à la fin du script d'installation.

---

## 👤 Configuration Initiale

1.  **Ouvrez l'interface Open WebUI** avec l'URL ci-dessus.
2.  La première fois, il vous sera demandé de **créer un compte administrateur** pour l'interface de chat. Ce n'est pas lié à Ollama lui-même, mais à l'interface web.
3.  Une fois connecté, vous pouvez commencer à discuter avec l'IA immédiatement.

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
