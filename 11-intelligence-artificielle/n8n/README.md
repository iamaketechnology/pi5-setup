# 🤖 n8n - Automatisation de Workflows IA sur Raspberry Pi 5

> **Alternative open-source et auto-hébergée à Zapier/Make pour l'automatisation de tâches et l'intégration d'IA.**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![n8n](https://img.shields.io/badge/n8n-Latest-green.svg)](https://n8n.io/)

---

## 🎯 Vue d'Ensemble

**n8n** est une plateforme d'automatisation de workflows "low-code" qui permet de connecter différentes applications et services pour créer des processus automatisés complexes, avec un accent particulier sur les intégrations d'intelligence artificielle.

### 🤔 Pourquoi n8n ?

**Sans n8n** :
```
Tâche : "Quand un nouveau fichier est ajouté à mon Google Drive, le résumer avec OpenAI et envoyer le résumé sur Discord."

→ Écrire un script Python/Node.js complexe
→ Gérer l'authentification OAuth2 pour Google Drive, Discord, OpenAI
→ Héberger et maintenir le script
→ Gérer les erreurs et les nouvelles tentatives
→ Temps de développement : plusieurs heures/jours
```

**Avec n8n** :
```
Workflow visuel :
[Google Drive Trigger] → [OpenAI Node] → [Discord Node]

→ Glisser-déposer 3 nœuds
→ Configurer les connexions via interface web
→ Temps de développement : 15 minutes
```

### Avantages de n8n sur Pi5-Setup

- ✅ **Contrôle des données** : Vos workflows et vos données d'authentification restent sur votre Pi.
- ✅ **Pas de limites** : Exécutez autant de workflows et de tâches que votre Pi peut supporter, sans les limites des plans gratuits des services cloud.
- ✅ **Extensibilité** : Plus de 350 intégrations natives, et la possibilité de créer vos propres nœuds.
- ✅ **Intégration IA** : Nœuds dédiés pour OpenAI, Hugging Face, Cohere, et d'autres modèles de langage.
- ✅ **Économique** : Pas de frais mensuels récurrents.

---

## 🏗️ Architecture

### Stack Docker Compose

Le stack `n8n` est composé de deux services principaux :

```
n8n/
├── n8n              # Le serveur n8n principal (Node.js)
└── n8n-postgres     # Base de données PostgreSQL pour stocker les workflows et les credentials
```

### Flux de Données d'un Workflow

```
┌─────────────────┐      ┌──────────────────┐      ┌──────────────────┐
│   Trigger       │ ────▶│   Étape 1        │ ────▶│   Étape 2        │
│ (ex: Cron, Webhook) │      │ (ex: Lire un      │      │ (ex: Appeler API │
└─────────────────┘      │      fichier)        │      │      OpenAI)       │
                         └──────────────────┘      └──────────────────┘
```

---

## 🚀 Installation

L'installation est gérée par un script unique qui configure tout automatiquement.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash
```

Pour des instructions détaillées, consultez le guide d'installation :
- **[📄 n8n-setup.md](n8n-setup.md)**

---

## ⚙️ Configuration

### Variables d'Environnement

La configuration principale se fait via des variables d'environnement dans le fichier `.env` du stack.

| Variable | Description |
|----------|-------------|
| `N8N_ENCRYPTION_KEY` | Clé secrète pour chiffrer les credentials. **Ne la perdez pas !** |
| `N8N_USER_MANAGEMENT_JWT_SECRET` | Secret pour les sessions utilisateur. |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Identifiants pour la base de données PostgreSQL. |
| `WEBHOOK_URL` | URL publique pour les webhooks, détectée automatiquement par le script. |

### Accès Web

- **Sans Traefik (local)** : `http://pi5.local:5678`
- **Avec Traefik (DuckDNS)** : `https://n8n.VOTRE-SOUS-DOMAINE.duckdns.org`
- **Avec Traefik (Cloudflare)** : `https://n8n.VOTRE-DOMAINE.com`

**Note** : Pour accès local sans erreur "secure cookie", utilisez `http://localhost:5678` via tunnel SSH.

---

## 🧠 Cas d'Usage avec l'IA

- **Automatisation de contenu** : Générer des articles de blog, des tweets ou des descriptions de produits avec OpenAI et les publier automatiquement.
- **Analyse de sentiments** : Analyser les nouveaux commentaires sur votre site ou les mentions sur les réseaux sociaux et les classer par sentiment (positif, négatif, neutre).
- **OCR et traitement de documents** : Extraire le texte de PDFs scannés (factures, reçus) avec un service d'OCR, puis le structurer avec une IA.
- **Chatbots personnalisés** : Créer un chatbot Discord ou Slack qui répond à des questions en se basant sur votre propre base de connaissances (via des embeddings).

Pour des exemples concrets, consultez le guide débutant :
- **[🎓 n8n-guide.md](n8n-guide.md)**
