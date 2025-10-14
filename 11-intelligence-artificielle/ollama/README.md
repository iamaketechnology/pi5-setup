# 🤖 Ollama + Open WebUI - LLM Local sur Raspberry Pi 5

> **Hébergez vos propres modèles de langage (LLM) et une interface de chat de type ChatGPT, 100% en local sur votre Pi.**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Ollama](https://img.shields.io/badge/Ollama-Latest-green.svg)](https://ollama.ai/)

---

## 🎯 Vue d'Ensemble

Ce stack déploie **Ollama**, un serveur de modèles de langage (LLM) léger et puissant, ainsi que **Open WebUI**, une interface de chat conviviale et réactive. Ensemble, ils offrent une expérience similaire à ChatGPT, mais entièrement auto-hébergée, privée et sans frais.

### 🤔 Pourquoi héberger son propre LLM ?

- **Confidentialité Totale** : Vos conversations avec l'IA ne quittent jamais votre Raspberry Pi. Aucune donnée n'est envoyée à OpenAI, Google ou toute autre entreprise.
- **Pas de Censure** : Utilisez des modèles non censurés pour des réponses plus directes et créatives.
- **Gratuit et Illimité** : Pas de frais par requête, pas de limite d'utilisation. La seule limite est la puissance de votre Pi.
- **Personnalisation** : Accédez à des centaines de modèles open-source (Llama 3, Mistral, Phi-3, etc.) et créez des versions personnalisées.
- **Accès API** : Utilisez l'API compatible OpenAI d'Ollama pour intégrer l'IA dans vos propres applications et scripts.

---

## 🏗️ Architecture

Le stack est composé de deux services principaux :

```
ollama/
├── ollama         # Le serveur principal qui fait tourner les LLMs
└── open-webui     # L'interface de chat web qui communique avec Ollama
```

- **Ollama** écoute sur le port `11434` et expose une API pour charger, décharger et interroger les modèles.
- **Open WebUI** écoute sur le port `3002` (ajusté pour éviter conflit avec Supabase Studio) et fournit l'interface utilisateur.

---

## 🚀 Installation

L'installation est entièrement automatisée via un script shell.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/01-ollama-deploy.sh | sudo bash
```

Pour des instructions détaillées, consultez le guide d'installation :
- **[📄 ollama-setup.md](ollama-setup.md)**

---

## ⚙️ Configuration

### Modèles de Langage

Le script d'installation configure Ollama mais **ne télécharge pas automatiquement de modèle**. Utilisez le script de téléchargement intelligent pour obtenir les meilleurs modèles pour votre Pi 5.

#### 🎯 Téléchargement Intelligent (Recommandé)

**Script interactif avec 11 modèles optimisés pour Pi 5 16GB** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/02-download-models.sh | sudo bash
```

**Fonctionnalités** :
- ✅ Menu interactif avec descriptions et benchmarks
- ✅ 3 packs pré-configurés (Recommandé, Développeur, Multilingue)
- ✅ Sélection multiple de modèles
- ✅ Idempotent (skip si déjà installé)
- ✅ Modèles optimisés pour performances Pi 5 (8-10 tok/s)

**Modèles disponibles** :
- **Chat rapide** : gemma2:2b (8-10 tok/s), llama3.2:3b
- **Code** : qwen2.5-coder:1.5b, deepseek-coder-v2:16b
- **Multilingue** : aya-expanse:8b (100+ langues)
- **Vision** : llava:7b (analyse d'images)
- **Multitâche** : phi3:3.8b, mistral:7b

#### 🔄 Mise à Jour Automatique

**Script de mise à jour avec support cron** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/03-update-models.sh | sudo bash
```

**Planifier les mises à jour hebdomadaires** :
```bash
# Exécuter le script avec --setup-cron
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/03-update-models.sh | sudo bash -s -- --setup-cron
```

#### 🛠️ Gestion Manuelle

Pour gérer les modèles manuellement :

```bash
# Lister les modèles installés
docker exec ollama ollama list

# Télécharger un nouveau modèle (ex: Llama 3)
docker exec ollama ollama pull llama3

# Supprimer un modèle
docker exec ollama ollama rm phi3:3.8b
```

Une liste complète des modèles disponibles se trouve sur la [bibliothèque Ollama](https://ollama.com/library).

### Accès à l'API

L'API d'Ollama est accessible sur le port `11434` et est compatible avec l'API d'OpenAI, ce qui facilite l'intégration avec des outils existants.

```bash
curl http://localhost:11434/api/generate -d '{ "model": "phi3:3.8b", "prompt": "Pourquoi le ciel est-il bleu ?" }'
```

---

## 🎓 Pour Commencer

Pour apprendre à utiliser l'interface, à gérer les modèles et à créer des workflows IA, consultez notre guide pour débutants :
- **[🎓 ollama-guide.md](ollama-guide.md)**
