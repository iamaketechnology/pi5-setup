# 🦆 Pi5 Gitea Stack - Self-Hosted Git + CI/CD

> **GitHub alternatif auto-hébergé avec Git, Issues, PRs, Wiki, Actions et Packages Registry**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%205-red.svg)](https://www.raspberrypi.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![Gitea](https://img.shields.io/badge/Gitea-Latest-609926.svg)](https://gitea.io/)

---

## 📖 Table des Matières

- [Vue d'Ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Installation Rapide](#-installation-rapide)
- [Architecture](#-architecture)
- [Gitea vs Alternatives](#-gitea-vs-alternatives)
- [Cas d'Usage](#-cas-dusage)
- [Configuration](#-configuration)
- [CI/CD avec Gitea Actions](#-cicd-avec-gitea-actions)
- [Intégration Pi5-Setup](#-intégration-pi5-setup)
- [Sécurité](#-sécurité)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)

---

## 🎯 Vue d'Ensemble

**Pi5-Gitea-Stack** est une solution complète de **Git self-hosted** pour Raspberry Pi 5, basée sur **Gitea**, une alternative légère et open-source à GitHub/GitLab.

### Qu'est-ce que Gitea ?

**Gitea** = GitHub auto-hébergé sur votre Pi

- ✅ **Hébergement Git illimité** - Repos privés/publics sans limites
- ✅ **Interface moderne** - Clone de GitHub (Issues, PRs, Wiki)
- ✅ **Gitea Actions** - CI/CD compatible GitHub Actions (même syntaxe YAML)
- ✅ **Packages Registry** - Docker, npm, Maven, PyPI, etc.
- ✅ **Ultra-léger** - 300-500 MB RAM (vs GitLab 4-8 GB)
- ✅ **ARM64 optimisé** - Builds officiels pour Raspberry Pi 5
- ✅ **100% Open Source** - Licence MIT

### Pourquoi Self-Host Git ?

**Sans Gitea (GitHub Free)** :
```
Vous → ❌ Repos privés limités (3 collaborateurs max)
     → ❌ CI/CD limité (2000 min/mois)
     → ❌ Packages limités (500 MB)
     → ❌ Dépendance à GitHub (rate limits, outages)
     → ❌ Code sur serveurs tiers
```

**Avec Gitea (Self-Hosted)** :
```
Vous → ✅ Repos privés illimités
     → ✅ CI/CD illimité (votre CPU)
     → ✅ Packages illimités (votre stockage)
     → ✅ Indépendance totale
     → ✅ Code sur votre Pi (contrôle total)
     → ✅ Backup/Mirror de vos repos GitHub
```

---

## 🚀 Fonctionnalités

### Core Features

- 📦 **Hébergement Git** - Repos publics/privés, branches, tags, releases
- 🐛 **Issue Tracker** - Issues, labels, milestones, assignees
- 🔀 **Pull Requests** - Code review, merge strategies, approvals
- 📚 **Wiki** - Documentation Markdown par repo
- 🎯 **Projects** - Kanban boards (GitHub Projects clone)
- 🔔 **Notifications** - Email, webhooks, RSS
- 👥 **Organisations** - Teams, permissions granulaires
- 🔐 **SSO** - OAuth2, LDAP, SAML (optionnel)

### Gitea Actions (CI/CD)

**Compatible GitHub Actions** - Même syntaxe `.github/workflows/*.yml` !

- ✅ **Act Runner** - Exécute jobs localement (ARM64)
- ✅ **Matrix builds** - Tester plusieurs versions
- ✅ **Artifacts** - Upload/download entre jobs
- ✅ **Secrets** - Variables sécurisées
- ✅ **Cron jobs** - Workflows planifiés
- ✅ **Self-hosted runners** - Plusieurs runners parallèles

**Exemples workflows** :
- 🐳 Build images Docker ARM64
- 🧪 Tests automatiques (pytest, jest, go test)
- 📦 Publish packages (npm, PyPI, Docker Registry)
- 🚀 Deploy Supabase Edge Functions
- 📊 Génération rapports (coverage, benchmarks)

### Packages Registry

Supporte **15+ package managers** :

| Type | Commande Publish | Commande Install |
|------|------------------|------------------|
| **Docker** | `docker push git.monpi.fr/user/image` | `docker pull git.monpi.fr/user/image` |
| **npm** | `npm publish --registry=http://git.monpi.fr/...` | `npm install --registry=...` |
| **PyPI** | `twine upload --repository-url=...` | `pip install --index-url=...` |
| **Maven** | `mvn deploy` | `<repository>` config |
| **Go** | `GOPROXY=...` | Auto-détection |
| **Composer** | `composer config repositories...` | Auto |
| **NuGet** | `dotnet nuget push` | `dotnet add source` |

**Use case** : Centraliser tous vos packages sur le Pi

---

## ⚡ Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec Raspberry Pi OS 64-bit
- ✅ Docker + Docker Compose installés ([01-prerequisites-setup.sh](../common-scripts/01-prerequisites-setup.sh))
- ✅ **(Optionnel)** Traefik pour HTTPS automatique
- ✅ **(Recommandé)** Domaine ou DuckDNS configuré

### Installation Simple (Curl One-Liner)

```bash
# Étape 1 : Déployer Gitea + PostgreSQL
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash

# Étape 2 : Configurer Gitea Actions (CI/CD)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/02-runners-setup.sh | sudo bash
```

**Durée totale** : ~5 minutes

### Ce que font les Scripts

**Script 01-gitea-deploy.sh** :
1. ✅ Détecte Traefik (scénario duckdns/cloudflare/vpn)
2. ✅ Crée répertoire `~/stacks/gitea/`
3. ✅ Génère Docker Compose (Gitea + PostgreSQL)
4. ✅ Configure domaine/HTTPS (si Traefik)
5. ✅ Démarre les containers
6. ✅ Affiche URL d'accès et instructions setup

**Script 02-runners-setup.sh** :
1. ✅ Télécharge Act Runner (ARM64)
2. ✅ Enregistre runner auprès de Gitea
3. ✅ Configure Docker-in-Docker (DinD)
4. ✅ Démarre runner en service systemd
5. ✅ Affiche status et exemples de workflows

### Accéder à Gitea

**URL selon scénario** :
- Sans Traefik : `http://raspberrypi.local:3001`
- DuckDNS : `https://votresubdomain.duckdns.org/git`
- Cloudflare : `https://git.votredomaine.com`
- VPN + Traefik : `http://raspberrypi.local:3001`

**Premier lancement** :
1. Ouvrir l'URL Gitea
2. Compléter formulaire installation (auto-rempli)
3. Créer compte admin
4. Commencer à créer repos !

---

## 🏗️ Architecture

### Stack Docker Compose

```
gitea/
├── gitea            # Serveur Gitea (port 3001, 2222)
├── gitea-db         # PostgreSQL 15 (port 5432)
└── act-runner       # Gitea Actions runner (optionnel)
```

### Flux de Données

```
┌──────────────────────────────────────────────────────┐
│                    Internet                          │
└────────────────────┬─────────────────────────────────┘
                     │
         ┌───────────▼──────────┐
         │   Traefik (HTTPS)    │  ← Reverse proxy
         │   git.monpi.fr       │
         └───────────┬──────────┘
                     │
         ┌───────────▼──────────┐
         │   Gitea (3001)       │  ← Interface web + Git HTTP(S)
         │   - Web UI           │
         │   - Git operations   │
         │   - Webhooks         │
         └──────┬────────┬──────┘
                │        │
    ┌───────────▼──┐  ┌─▼──────────────┐
    │ PostgreSQL   │  │  Act Runner    │  ← CI/CD
    │ (gitea DB)   │  │  (workflows)   │
    └──────────────┘  └────────────────┘
```

### Ports Utilisés

| Service | Port Internal | Port External | Description |
|---------|---------------|---------------|-------------|
| **Gitea Web** | 3001 | 3001 ou via Traefik | Interface web, Git HTTP |
| **Gitea SSH** | 2222 | 2222 | Git SSH (git clone ssh://...) |
| **PostgreSQL** | 5432 | - (interne) | Base de données Gitea |
| **Act Runner** | - | - (interne) | Exécute CI/CD jobs |

### Arborescence Fichiers

```
~/stacks/gitea/
├── docker-compose.yml              # Stack Gitea + PostgreSQL
├── .env                            # Variables environnement
├── config/
│   └── app.ini                     # Configuration Gitea
├── data/
│   ├── git/                        # Repos Git (bare)
│   │   └── repositories/
│   ├── gitea/                      # Avatars, attachments
│   ├── ssh/                        # Clés SSH
│   └── lfs/                        # Git LFS objects
├── db/
│   └── data/                       # PostgreSQL data
└── runners/
    ├── act-runner-1/
    │   └── .runner                 # Config runner
    └── act-runner-2/               # (optionnel) Runner #2
```

---

## 📊 Gitea vs Alternatives

### Comparaison Complète

| Fonctionnalité | Gitea | GitHub Free | GitLab CE | Forgejo | Gogs |
|----------------|-------|-------------|-----------|---------|------|
| **Self-hosted** | ✅ Oui | ❌ Non | ✅ Oui | ✅ Oui | ✅ Oui |
| **Légèreté** | ✅ 300-500MB RAM | N/A | ❌ 4-8GB RAM | ✅ 300-500MB | ✅ 200-300MB |
| **CI/CD** | ✅ Actions | ✅ Actions | ✅ Pipelines | ✅ Actions | ❌ Absent |
| **Repos privés** | ✅ Illimités | ⚠️ Limité (3 collab) | ✅ Illimités | ✅ Illimités | ✅ Illimités |
| **Packages Registry** | ✅ 15+ types | ✅ Inclus | ✅ Inclus | ✅ 15+ types | ❌ Absent |
| **Wiki** | ✅ Markdown | ✅ Inclus | ✅ Inclus | ✅ Markdown | ✅ Basique |
| **Pull Requests** | ✅ Complet | ✅ Complet | ✅ Merge Requests | ✅ Complet | ✅ Basique |
| **Projects/Kanban** | ✅ Inclus | ✅ Inclus | ✅ Issue Boards | ✅ Inclus | ❌ Absent |
| **API** | ✅ REST + Webhooks | ✅ REST + GraphQL | ✅ REST + GraphQL | ✅ REST + Webhooks | ✅ REST |
| **SSO/OAuth** | ✅ Oui | ✅ Oui | ✅ Oui | ✅ Oui | ⚠️ Limité |
| **Coût** | Gratuit | Gratuit | Gratuit | Gratuit | Gratuit |
| **Licence** | MIT | Proprietary | MIT | MIT | MIT |
| **ARM64 Support** | ✅ Officiel | N/A | ⚠️ Communautaire | ✅ Officiel | ⚠️ Communautaire |
| **Complexité Setup** | ⭐ Facile | N/A | ⭐⭐⭐ Complexe | ⭐ Facile | ⭐ Très facile |

### Pourquoi Gitea plutôt que GitLab ?

**GitLab CE** est excellent mais **trop lourd pour Pi 5** :

| Critère | Gitea | GitLab CE |
|---------|-------|-----------|
| **RAM minimum** | 512 MB | 4 GB |
| **RAM recommandée** | 2 GB | 8 GB |
| **Setup** | 5 min | 30+ min |
| **Boot time** | 10-15 sec | 2-5 min |
| **CI/CD syntax** | GitHub Actions (YAML) | GitLab CI (YAML) |
| **Popularité syntax** | ⭐⭐⭐⭐⭐ (standard) | ⭐⭐⭐ (GitLab-specific) |

**Verdict** : Gitea est **parfait pour Pi 5**, GitLab nécessite serveur dédié.

### Pourquoi Gitea plutôt que Forgejo ?

**Forgejo** = Fork communautaire de Gitea (2022)

| Critère | Gitea | Forgejo |
|---------|-------|---------|
| **Origine** | Gitea Ltd (société) | Communauté (Codeberg) |
| **Gouvernance** | Company-backed | 100% communautaire |
| **Features** | Identiques | Identiques (+privacy focus) |
| **Updates** | Fréquentes | Fréquentes |
| **Ecosystem** | Plus large | En croissance |
| **Documentation** | ⭐⭐⭐⭐ Excellente | ⭐⭐⭐ Bonne |

**Les deux sont excellents !** Gitea est choisi ici pour :
- Documentation plus mature
- Communauté plus large
- Ecosystem d'intégrations plus riche

**Note** : Vous pouvez facilement migrer Gitea ↔ Forgejo (compatibles).

### Pourquoi Gitea plutôt que Gogs ?

**Gogs** = Ancêtre de Gitea (Gitea est un fork de Gogs 2016)

Gitea a **dépassé Gogs** :
- ✅ CI/CD intégré (Gogs n'a pas)
- ✅ Packages Registry (Gogs n'a pas)
- ✅ Projects/Kanban (Gogs n'a pas)
- ✅ Développement actif (Gogs ralenti)

**Verdict** : Utilisez Gitea, pas Gogs.

---

## 🎯 Cas d'Usage

### 1. Repos Privés Illimités

**Problème** : GitHub Free limite à 3 collaborateurs pour repos privés

**Solution Gitea** :
```bash
# Créer organisation "MonEntreprise"
# Inviter 10 développeurs
# Créer 50 repos privés
# → 100% gratuit, aucune limite !
```

**Use case** :
- Startup/PME avec petite équipe
- Projets personnels (dotfiles, notes, scripts)
- Code sensible (ne doit pas être sur GitHub)

### 2. Backup/Mirror de Repos GitHub

**Problème** : GitHub outage ou compte banni = perte d'accès

**Solution Gitea** :
```bash
# Sur Gitea : New Migration
# URL : https://github.com/user/repo
# Mirror automatique toutes les heures
# → Backup toujours à jour sur votre Pi !
```

**Use case** :
- Backup de tous vos repos GitHub
- Mirror d'un repo populaire (pour contributions offline)
- Archive de projets abandonnés

### 3. CI/CD Illimité (GitHub Actions Clone)

**Problème** : GitHub Actions limité à 2000 min/mois (plan Free)

**Solution Gitea Actions** :
```yaml
# .gitea/workflows/tests.yml (même syntaxe GitHub Actions !)
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: arm64  # Votre runner local
    steps:
      - uses: actions/checkout@v3
      - run: npm test
      - run: npm run build
# → Illimité, tourne sur votre Pi !
```

**Use case** :
- Tests automatiques sur chaque push
- Build Docker images ARM64
- Deploy Supabase Edge Functions
- Génération documentation

### 4. Packages Registry Privé

**Problème** : npm/Docker Hub public = code visible par tous

**Solution Gitea Packages** :
```bash
# Docker
docker tag myapp:latest git.monpi.fr/user/myapp:latest
docker push git.monpi.fr/user/myapp:latest

# npm
npm publish --registry=http://git.monpi.fr/api/packages/user/npm

# PyPI
twine upload --repository-url=http://git.monpi.fr/api/packages/user/pypi
```

**Use case** :
- Bibliothèques internes d'entreprise
- Packages non-publiés (WIP)
- Images Docker privées

### 5. Git pour Famille/Amis

**Problème** : Ami veut apprendre Git mais GitHub intimidant

**Solution Gitea** :
```
1. Créer compte pour ami sur votre Gitea
2. Créer organisation "Projets Famille"
3. Interface simple, française (traduction dispo)
4. Pas de distractions (trending, explore, etc.)
```

**Use case** :
- Apprendre Git dans environnement safe
- Partager code entre amis (pas public)
- Projets collaboratifs famille

### 6. Développement Mobile avec Supabase Local

**Problème** : Tester app mobile avec backend Supabase sur Pi

**Solution Gitea + Actions** :
```yaml
# .gitea/workflows/deploy-edge-function.yml
name: Deploy to Supabase
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3
      - name: Deploy Edge Function
        run: |
          supabase functions deploy my-function \
            --project-ref local \
            --token ${{ secrets.SUPABASE_TOKEN }}
```

**Use case** :
- Push code → Auto-deploy Edge Functions
- Tests E2E mobile app + backend
- Environnement dev isolé

---

## ⚙️ Configuration

### Variables d'Environnement

**Fichier** : `~/stacks/gitea/.env`

| Variable | Défaut | Description |
|----------|--------|-------------|
| `GITEA_DOMAIN` | Auto-détecté | Domaine Gitea (ex: `git.monpi.fr`) |
| `GITEA_ROOT_URL` | `http://localhost:3001` | URL racine Gitea |
| `GITEA_SSH_PORT` | `2222` | Port SSH externe |
| `POSTGRES_PASSWORD` | Auto-généré | Mot de passe PostgreSQL |
| `GITEA_ADMIN_USER` | Créé au 1er lancement | Username admin |
| `GITEA_ADMIN_PASSWORD` | Créé au 1er lancement | Password admin |
| `GITEA_SECRET_KEY` | Auto-généré | Clé secrète (JWT, cookies) |

**Modifier après installation** :

```bash
cd ~/stacks/gitea
nano .env
docker compose up -d  # Redémarrer
```

### Configurer Domaine et HTTPS

**Si Traefik installé** : Détection automatique par le script

**Manuellement** (sans Traefik) :

```bash
cd ~/stacks/gitea
nano .env
```

Modifier :
```bash
GITEA_DOMAIN=git.monpi.fr
GITEA_ROOT_URL=https://git.monpi.fr
```

Redémarrer :
```bash
docker compose up -d
```

### Configurer Git SSH (Port 2222)

**Par défaut** : Git SSH sur port 2222 (port 22 réservé pour SSH système)

**Cloner via SSH** :
```bash
git clone ssh://git@git.monpi.fr:2222/user/repo.git
```

**Simplifier avec config SSH** :

```bash
nano ~/.ssh/config
```

Ajouter :
```
Host git.monpi.fr
    Port 2222
    User git
```

Maintenant :
```bash
git clone git@git.monpi.fr:user/repo.git  # Port 2222 automatique !
```

**Ouvrir port sur box** (si accès externe) :
```
Port externe : 2222
Port interne : 2222
Protocole    : TCP
IP           : <IP_PI>
```

### Configurer Actions (CI/CD)

**Activer Actions dans Gitea** :

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[actions]` :
```ini
[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = https://gitea.com
```

Redémarrer :
```bash
docker compose restart gitea
```

**Enregistrer runner** (fait par script 02-runners-setup.sh) :

```bash
# Obtenir registration token
# Interface Gitea → Site Administration → Actions → Runners → Create new Runner

# Enregistrer runner
./act_runner register \
  --instance http://gitea:3001 \
  --token <REGISTRATION_TOKEN> \
  --name runner-1 \
  --labels arm64:docker://node:18,arm64:docker://python:3.11

# Démarrer runner
./act_runner daemon
```

### Configurer Packages Registry

**Activer Packages** :

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[packages]` :
```ini
[packages]
ENABLED = true
```

**Publier package Docker** :

```bash
# Login
docker login git.monpi.fr -u <USER>

# Tag
docker tag myapp:latest git.monpi.fr/<USER>/myapp:latest

# Push
docker push git.monpi.fr/<USER>/myapp:latest
```

**Publier package npm** :

```bash
# .npmrc
registry=http://git.monpi.fr/api/packages/<USER>/npm/

# Publier
npm publish
```

**Publier package PyPI** :

```bash
# .pypirc
[distutils]
index-servers = gitea

[gitea]
repository = http://git.monpi.fr/api/packages/<USER>/pypi
username = <USER>
password = <PASSWORD>

# Publier
python setup.py sdist
twine upload -r gitea dist/*
```

### Configurer Webhooks

**Use case** : Déclencher action externe sur push/PR

**Exemple : Webhook Discord** :

1. Gitea → Repo → Settings → Webhooks → Add Webhook
2. Type : Discord
3. Payload URL : `https://discord.com/api/webhooks/...`
4. Events : Push, Pull Request
5. Active : ✅

**Exemple : Webhook Custom (Supabase Edge Function)** :

1. Créer Edge Function qui reçoit payload Gitea
2. Gitea → Repo → Webhooks → Add Webhook (Gitea)
3. URL : `https://api.monpi.fr/functions/v1/git-webhook`
4. Secret : `<TOKEN>`
5. Events : Push
6. Content Type : `application/json`

**Payload exemple** :
```json
{
  "ref": "refs/heads/main",
  "commits": [
    {
      "id": "abc123",
      "message": "Fix bug",
      "author": {"name": "User", "email": "user@example.com"}
    }
  ]
}
```

### Configurer Organisations

**Créer organisation** :

1. Interface Gitea → + (top right) → New Organization
2. Nom : `MonEntreprise`
3. Visibility : Private
4. Create Organization

**Ajouter membres** :

1. Organisation → Teams → Owners
2. Add Team Member → Sélectionner user
3. Rôle : Owner / Admin / Member

**Créer repos dans organisation** :

1. Organisation → Repositories → New Repository
2. Owner : MonEntreprise (auto-sélectionné)
3. Visibility : Private
4. Create Repository

### Configurer Email (SMTP)

**Pour notifications** : Issues, PRs, mentions

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[mailer]` :
```ini
[mailer]
ENABLED = true
SMTP_ADDR = smtp.gmail.com
SMTP_PORT = 587
FROM = gitea@monpi.fr
USER = votre-email@gmail.com
PASSWD = mot-de-passe-application
```

**Tester** :
1. Gitea → Site Administration → Configuration → Send Testing Email
2. Vérifier inbox

---

## 🤖 CI/CD avec Gitea Actions

### Comment ça fonctionne ?

**Gitea Actions** = Clone de GitHub Actions

```
1. Développeur push code
        ↓
2. Gitea détecte .gitea/workflows/*.yml
        ↓
3. Gitea envoie job au runner
        ↓
4. Act Runner pull images Docker (node, python, etc.)
        ↓
5. Act Runner exécute steps dans container
        ↓
6. Act Runner renvoie logs/status à Gitea
        ↓
7. Développeur voit résultat dans UI
```

### Syntaxe Workflow

**Identique à GitHub Actions !**

**Exemple 1 : Tests automatiques**

```yaml
# .gitea/workflows/tests.yml
name: Tests
on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    runs-on: arm64  # Label du runner
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test

      - name: Upload coverage
        uses: actions/upload-artifact@v3
        with:
          name: coverage
          path: coverage/
```

**Exemple 2 : Build Docker ARM64**

```yaml
# .gitea/workflows/docker.yml
name: Docker Build
on:
  push:
    tags:
      - 'v*'

jobs:
  docker:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3

      - name: Login to Gitea Registry
        run: |
          echo "${{ secrets.GITEA_TOKEN }}" | \
            docker login git.monpi.fr -u ${{ github.actor }} --password-stdin

      - name: Build and Push
        run: |
          docker build -t git.monpi.fr/${{ github.repository }}:${{ github.ref_name }} .
          docker push git.monpi.fr/${{ github.repository }}:${{ github.ref_name }}
```

**Exemple 3 : Deploy Supabase Edge Function**

```yaml
# .gitea/workflows/deploy.yml
name: Deploy Edge Function
on:
  push:
    branches: [main]
    paths:
      - 'functions/**'

jobs:
  deploy:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3

      - name: Setup Deno
        uses: denoland/setup-deno@v1
        with:
          deno-version: v1.x

      - name: Deploy to Supabase
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_TOKEN }}
        run: |
          deno install --allow-all --global supabase
          supabase functions deploy my-function --project-ref local
```

**Exemple 4 : Matrix builds**

```yaml
# .gitea/workflows/matrix.yml
name: Matrix Tests
on: [push]

jobs:
  test:
    runs-on: arm64
    strategy:
      matrix:
        node-version: [16, 18, 20]
        os: [ubuntu-latest]

    steps:
      - uses: actions/checkout@v3

      - name: Setup Node ${{ matrix.node-version }}
        uses: actions/setup-node@v3
        with:
          node-version: ${{ matrix.node-version }}

      - run: npm ci
      - run: npm test
```

### Actions Disponibles

**Actions officielles GitHub** (compatibles) :

- `actions/checkout@v3` - Clone repo
- `actions/setup-node@v3` - Setup Node.js
- `actions/setup-python@v4` - Setup Python
- `actions/upload-artifact@v3` - Upload artifacts
- `actions/download-artifact@v3` - Download artifacts
- `actions/cache@v3` - Cache dependencies
- `docker/login-action@v2` - Docker login
- `docker/build-push-action@v4` - Docker build/push

**Actions custom** :

Créer vos propres actions dans Gitea (ex: `user/action-name`) :

```yaml
# action.yml
name: My Action
description: Custom action
inputs:
  myInput:
    description: 'Input description'
    required: true
runs:
  using: 'docker'
  image: 'Dockerfile'
```

### Gestion Runners

**Lister runners actifs** :

Interface Gitea → Site Administration → Actions → Runners

**Ajouter runner supplémentaire** :

```bash
# Sur le Pi
cd ~/stacks/gitea/runners
mkdir act-runner-2

# Enregistrer
./act_runner register \
  --instance http://gitea:3001 \
  --token <TOKEN> \
  --name runner-2

# Démarrer
./act_runner daemon --config act-runner-2/.runner
```

**Labels runners** :

```bash
# Runner avec plusieurs labels
./act_runner register \
  --labels arm64:docker://node:18 \
  --labels arm64:docker://python:3.11 \
  --labels arm64:docker://golang:1.21
```

**Utiliser dans workflow** :

```yaml
jobs:
  build-node:
    runs-on: arm64  # Utilise runner avec label arm64

  build-python:
    runs-on: ubuntu-latest  # Cherche runner avec ce label
```

### Secrets

**Créer secrets** :

1. Repo → Settings → Secrets → Actions
2. Add Secret
3. Name : `SUPABASE_TOKEN`
4. Value : `<TOKEN>`
5. Add

**Utiliser dans workflow** :

```yaml
steps:
  - name: Deploy
    env:
      SUPABASE_TOKEN: ${{ secrets.SUPABASE_TOKEN }}
    run: |
      echo "Token: $SUPABASE_TOKEN"
```

**Secrets au niveau organisation** :

Organisation → Settings → Secrets → Actions

**Hérités par tous les repos de l'organisation !**

### Artifacts

**Upload artifact** :

```yaml
- name: Build
  run: npm run build

- name: Upload dist
  uses: actions/upload-artifact@v3
  with:
    name: build-output
    path: dist/
```

**Download dans autre job** :

```yaml
deploy:
  needs: build
  steps:
    - name: Download artifact
      uses: actions/download-artifact@v3
      with:
        name: build-output
        path: dist/

    - name: Deploy
      run: rsync -av dist/ server:/var/www/
```

### Cron Jobs

**Workflow planifié** :

```yaml
# .gitea/workflows/nightly.yml
name: Nightly Build
on:
  schedule:
    - cron: '0 2 * * *'  # Tous les jours à 2h00

jobs:
  build:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3
      - run: npm run build
      - run: npm run test:e2e
```

**Syntaxe cron** :
```
*    *    *    *    *
│    │    │    │    │
│    │    │    │    └─ Jour semaine (0-6, 0=Dimanche)
│    │    │    └────── Mois (1-12)
│    │    └─────────── Jour mois (1-31)
│    └──────────────── Heure (0-23)
└───────────────────── Minute (0-59)
```

**Exemples** :
```yaml
- cron: '0 2 * * *'      # Tous les jours à 2h00
- cron: '0 */6 * * *'    # Toutes les 6 heures
- cron: '0 0 * * 0'      # Tous les dimanches à minuit
- cron: '30 5 1 * *'     # 1er du mois à 5h30
```

---

## 🔗 Intégration Pi5-Setup

### Intégration avec Supabase

**Use case** : Auto-deploy Edge Functions depuis Gitea

**Workflow** :

```yaml
# .gitea/workflows/supabase.yml
name: Deploy to Supabase
on:
  push:
    branches: [main]
    paths:
      - 'supabase/functions/**'

jobs:
  deploy:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3

      - name: Setup Supabase CLI
        run: |
          curl -fsSL https://raw.githubusercontent.com/.../supabase-cli-install.sh | bash

      - name: Deploy Edge Functions
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_TOKEN }}
          SUPABASE_PROJECT_ID: local
        run: |
          cd supabase/functions
          for func in */; do
            supabase functions deploy ${func%/} --project-ref local
          done

      - name: Run Migrations
        run: |
          supabase db push --project-ref local
```

**Secrets à configurer** :
- `SUPABASE_TOKEN` : Token d'accès Supabase
- `SUPABASE_URL` : `http://raspberrypi:8000` (si VPN)

### Intégration avec Docker Builds

**Use case** : Build images Docker ARM64 pour vos apps

**Workflow** :

```yaml
# .gitea/workflows/docker-build.yml
name: Build Docker ARM64
on:
  push:
    tags: ['v*']

jobs:
  docker:
    runs-on: arm64
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Gitea Registry
        uses: docker/login-action@v2
        with:
          registry: git.monpi.fr
          username: ${{ github.actor }}
          token: ${{ secrets.GITEA_TOKEN }}

      - name: Build and Push
        uses: docker/build-push-action@v4
        with:
          context: .
          platforms: linux/arm64
          push: true
          tags: |
            git.monpi.fr/${{ github.repository }}:latest
            git.monpi.fr/${{ github.repository }}:${{ github.ref_name }}
```

### Intégration avec Backups (rclone)

**Use case** : Backup repos Git vers Cloudflare R2 / Backblaze B2

**Workflow** :

```yaml
# .gitea/workflows/backup.yml
name: Backup to R2
on:
  schedule:
    - cron: '0 3 * * *'  # Tous les jours à 3h00

jobs:
  backup:
    runs-on: arm64
    steps:
      - name: Backup Gitea data
        run: |
          sudo tar -czf /tmp/gitea-backup-$(date +%Y%m%d).tar.gz \
            /home/pi/stacks/gitea/data/git/repositories/

      - name: Upload to R2
        env:
          RCLONE_CONFIG_R2_TYPE: s3
          RCLONE_CONFIG_R2_PROVIDER: Cloudflare
          RCLONE_CONFIG_R2_ACCESS_KEY_ID: ${{ secrets.R2_ACCESS_KEY }}
          RCLONE_CONFIG_R2_SECRET_ACCESS_KEY: ${{ secrets.R2_SECRET_KEY }}
          RCLONE_CONFIG_R2_ENDPOINT: ${{ secrets.R2_ENDPOINT }}
        run: |
          rclone copy /tmp/gitea-backup-*.tar.gz r2:backups/gitea/
          rm /tmp/gitea-backup-*.tar.gz
```

### Intégration avec Monitoring (Grafana)

**Use case** : Métriques Gitea dans Grafana

**Activer métriques Gitea** :

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[metrics]` :
```ini
[metrics]
ENABLED = true
TOKEN = <SECRET_TOKEN>
```

**Ajouter target Prometheus** :

```bash
cd ~/stacks/monitoring
nano config/prometheus/prometheus.yml
```

Ajouter :
```yaml
scrape_configs:
  - job_name: 'gitea'
    bearer_token: '<SECRET_TOKEN>'
    static_configs:
      - targets: ['gitea:3001']
```

**Métriques disponibles** :
- `gitea_organizations` - Nombre d'organisations
- `gitea_repositories` - Nombre de repos
- `gitea_users` - Nombre d'utilisateurs
- `gitea_issues` - Nombre d'issues
- `gitea_pulls` - Nombre de PRs

### Intégration avec Homepage

**Use case** : Lien rapide vers Gitea dans Homepage

**Éditer config Homepage** :

```yaml
# ~/stacks/homepage/config/services.yaml
- Git:
    - Gitea:
        href: https://git.monpi.fr
        description: Git self-hosted
        icon: gitea
        widget:
          type: gitea
          url: http://gitea:3001
          key: <API_TOKEN>
```

**Obtenir API token** :
1. Gitea → Settings → Applications → Generate New Token
2. Scopes : `read:repository`, `read:user`
3. Copier token dans config Homepage

---

## 🔐 Sécurité

### Bonnes Pratiques

✅ **Activées par défaut** :
- HTTPS automatique (si Traefik)
- Repos privés par défaut
- Rate limiting (API, Git)
- CSRF protection
- XSS protection

✅ **Recommandées** :
- Activer 2FA pour tous les comptes
- Utiliser SSH keys (pas password)
- Configurer Fail2ban (bruteforce protection)
- Activer email verification
- Limiter enregistrements publics (si besoin)

✅ **Pour production** :
- Backups automatiques quotidiens
- Monitoring métriques Gitea
- Webhooks sécurisés (secrets)
- ACLs réseau (firewall)
- Audit logs activés

❌ **À éviter** :
- Exposer port PostgreSQL (5432) publiquement
- Désactiver HTTPS
- Autoriser anonymous access (sauf repos publics)
- Utiliser mot de passe faible admin

### Activer 2FA

**Pour utilisateur** :

1. Gitea → Settings → Security
2. Two-Factor Authentication → Enable
3. Scanner QR code avec app (Google Authenticator, Authy)
4. Sauvegarder recovery codes

**Forcer 2FA pour organisation** :

1. Organisation → Settings → Security
2. Require two-factor authentication → Enable

### Configurer SSH Keys

**Générer clé SSH** :

```bash
ssh-keygen -t ed25519 -C "votre-email@example.com"
# Fichier: ~/.ssh/id_ed25519
```

**Ajouter à Gitea** :

1. Gitea → Settings → SSH / GPG Keys
2. Add Key
3. Coller contenu de `~/.ssh/id_ed25519.pub`
4. Add Key

**Tester** :

```bash
ssh -T git@git.monpi.fr -p 2222
# Hi user! You've successfully authenticated...
```

**Cloner avec SSH** :

```bash
git clone ssh://git@git.monpi.fr:2222/user/repo.git
```

### Configurer Fail2ban

**Protection bruteforce SSH Gitea** :

```bash
# Installer Fail2ban
sudo apt install fail2ban

# Créer jail Gitea
sudo nano /etc/fail2ban/jail.d/gitea.conf
```

Contenu :
```ini
[gitea]
enabled = true
port = 2222
logpath = /var/log/gitea/gitea.log
maxretry = 5
findtime = 600
bantime = 3600
```

Redémarrer :
```bash
sudo systemctl restart fail2ban
```

### Limiter Enregistrements

**Désactiver enregistrements publics** :

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[service]` :
```ini
[service]
DISABLE_REGISTRATION = true
```

**Whitelist domaines email** :

```ini
[service]
EMAIL_DOMAIN_WHITELIST = example.com,monentreprise.fr
```

**Require admin approval** :

```ini
[service]
REGISTER_MANUAL_CONFIRM = true
```

### Configurer Webhooks Sécurisés

**Ajouter secret webhook** :

1. Repo → Settings → Webhooks → Add Webhook
2. Secret : `<RANDOM_SECRET>`
3. Payload URL : `https://...`

**Vérifier signature côté serveur** (Node.js) :

```javascript
const crypto = require('crypto');

function verifyWebhook(req, secret) {
  const signature = req.headers['x-gitea-signature'];
  const payload = JSON.stringify(req.body);
  const hmac = crypto.createHmac('sha256', secret);
  const digest = 'sha256=' + hmac.update(payload).digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(digest)
  );
}
```

### Configurer Audit Logs

**Activer logs** :

```bash
cd ~/stacks/gitea
nano config/app.ini
```

Section `[log]` :
```ini
[log]
MODE = file
LEVEL = Info
ROOT_PATH = /data/gitea/log
```

**Consulter logs** :

```bash
cd ~/stacks/gitea
tail -f data/gitea/log/gitea.log
```

**Logs disponibles** :
- Connexions/déconnexions
- Création/suppression repos
- Modifications permissions
- Webhooks triggered
- Actions exécutées

---

## 🆘 Troubleshooting

### Gitea ne démarre pas

**Symptôme** : Container `gitea` en status `Exited`

**Solutions** :

1. **Vérifier logs** :
   ```bash
   cd ~/stacks/gitea
   docker compose logs gitea
   ```

2. **Vérifier PostgreSQL** :
   ```bash
   docker compose ps
   # gitea-db doit être Up

   # Si Down :
   docker compose up -d gitea-db
   docker compose logs gitea-db
   ```

3. **Vérifier permissions** :
   ```bash
   ls -la ~/stacks/gitea/data/
   # Doit appartenir à user:group du container (git:git ou 1000:1000)

   # Si mauvais propriétaire :
   sudo chown -R 1000:1000 ~/stacks/gitea/data/
   docker compose restart gitea
   ```

### Git Clone échoue (SSH)

**Symptôme** : `ssh: connect to host git.monpi.fr port 2222: Connection refused`

**Solutions** :

1. **Vérifier port SSH ouvert** :
   ```bash
   sudo ufw status | grep 2222

   # Si absent :
   sudo ufw allow 2222/tcp
   ```

2. **Vérifier container Gitea** :
   ```bash
   docker compose ps
   # Port mapping : 0.0.0.0:2222->22/tcp
   ```

3. **Tester connexion SSH** :
   ```bash
   ssh -T git@git.monpi.fr -p 2222 -v
   # Debug verbeux
   ```

4. **Vérifier clé SSH ajoutée** :
   Gitea → Settings → SSH Keys → Vérifier présence

### Actions ne se lancent pas

**Symptôme** : Workflow reste en "pending", aucun runner

**Solutions** :

1. **Vérifier runner actif** :
   ```bash
   # Si systemd
   sudo systemctl status act-runner

   # Si Docker
   docker ps | grep act-runner

   # Si manuel
   ps aux | grep act_runner
   ```

2. **Vérifier enregistrement runner** :
   Interface Gitea → Site Administration → Actions → Runners

   Doit afficher runner avec status "idle" ou "running"

3. **Vérifier labels workflow vs runner** :
   ```yaml
   # Workflow demande :
   runs-on: arm64

   # Runner doit avoir label "arm64"
   ```

4. **Relancer runner** :
   ```bash
   sudo systemctl restart act-runner
   # Ou
   docker compose restart act-runner
   ```

### Packages Registry ne fonctionne pas

**Symptôme** : `docker push` échoue avec 404

**Solutions** :

1. **Vérifier packages activés** :
   ```bash
   cd ~/stacks/gitea
   grep -A2 "\[packages\]" config/app.ini
   # ENABLED = true
   ```

2. **Login Docker** :
   ```bash
   docker login git.monpi.fr
   Username: <USER>
   Password: <PASSWORD_OR_TOKEN>
   ```

3. **Vérifier URL registry** :
   ```bash
   # Format correct :
   git.monpi.fr/<owner>/<package-name>:<tag>

   # Exemple :
   git.monpi.fr/user/myapp:latest
   ```

4. **Vérifier permissions** :
   Repo Settings → Packages → Enable package publishing

### Migration GitHub échoue

**Symptôme** : "Migration failed: API rate limit exceeded"

**Solutions** :

1. **Utiliser token GitHub** :
   - GitHub → Settings → Developer settings → Personal access tokens
   - Generate token (scope: `repo`)
   - Gitea → New Migration → URL : `https://<TOKEN>@github.com/user/repo`

2. **Attendre rate limit** :
   GitHub Free : 60 req/h sans token, 5000 req/h avec token

3. **Mirror au lieu de migration complète** :
   - Migration complète = issues + PRs + releases
   - Mirror = juste code Git (plus rapide)

### Webhook ne se déclenche pas

**Symptôme** : Push code, mais webhook pas appelé

**Solutions** :

1. **Vérifier webhook actif** :
   Repo → Settings → Webhooks → Recent Deliveries

   Doit afficher tentatives de delivery

2. **Vérifier URL accessible** :
   ```bash
   # Depuis le Pi
   curl -X POST https://votre-webhook-url.com/endpoint
   ```

3. **Vérifier logs Gitea** :
   ```bash
   docker compose logs gitea | grep webhook
   ```

4. **Tester manuellement** :
   Repo → Settings → Webhooks → [Your webhook] → Test Delivery

### Base de données pleine

**Symptôme** : "ERROR: could not extend file... No space left on device"

**Solutions** :

1. **Vérifier espace disque** :
   ```bash
   df -h
   # / ou partition contenant ~/stacks/gitea
   ```

2. **Nettoyer vieux repos** :
   Gitea → Unadopted Repositories → Delete

3. **Compresser repos** :
   ```bash
   cd ~/stacks/gitea/data/git/repositories
   find . -name "*.git" -exec du -sh {} \;

   # Garbage collect gros repos
   cd user/big-repo.git
   git gc --aggressive --prune=now
   ```

4. **Augmenter stockage** :
   - Ajouter disque externe USB/SSD
   - Monter sur `/mnt/gitea-data`
   - Migrer `~/stacks/gitea/data/` → `/mnt/gitea-data/`

---

## 📚 Documentation

### Guides Disponibles

- **[Guide Débutant](gitea-guide.md)** - Guide pédagogique complet pour novices
- **[Installation](gitea-setup.md)** - Installation détaillée étape par étape
- **[WORKFLOWS-EXAMPLES.md](examples/workflows/README.md)** - 20+ exemples de workflows
- **[ROADMAP.md](../ROADMAP.md)** - Plan de développement Pi5-Setup

### Documentation Externe

- **[Gitea Docs](https://docs.gitea.io/)** - Documentation officielle Gitea
- **[Gitea Actions](https://docs.gitea.io/en-us/usage/actions/overview/)** - Documentation CI/CD
- **[Act Runner](https://gitea.com/gitea/act_runner)** - Runner officiel Gitea
- **[Gitea API](https://docs.gitea.io/en-us/api-usage/)** - REST API complète

### Exemples Workflows

**Disponibles dans** : `examples/workflows/`

| Workflow | Description | Fichier |
|----------|-------------|---------|
| **Node.js Tests** | Tests npm + coverage | `nodejs-tests.yml` |
| **Python Tests** | pytest + lint | `python-tests.yml` |
| **Docker Build** | Build image ARM64 | `docker-build.yml` |
| **Supabase Deploy** | Deploy Edge Functions | `supabase-deploy.yml` |
| **Static Site** | Build + deploy site | `static-site.yml` |
| **Database Backup** | Backup PostgreSQL | `db-backup.yml` |
| **Security Scan** | Trivy + dependency check | `security-scan.yml` |
| **Release** | Auto-create release | `release.yml` |

### Communautés

- **[Gitea Discord](https://discord.gg/gitea)** - Support officiel
- **[r/Gitea](https://reddit.com/r/Gitea)** - Reddit community
- **[Gitea Forum](https://discourse.gitea.io/)** - Forum officiel
- **[GitHub Discussions](https://github.com/go-gitea/gitea/discussions)** - Discussions

### Ressources Apprentissage

**Tutoriels vidéo** :
- [Gitea Setup Tutorial](https://www.youtube.com/results?search_query=gitea+self+hosted) - YouTube
- [GitHub Actions Tutorial](https://www.youtube.com/results?search_query=github+actions+tutorial) - Syntaxe identique

**Articles** :
- [Why Self-Host Git?](https://news.ycombinator.com/item?id=gitea) - HN discussions
- [Gitea vs GitLab](https://stackshare.io/stackups/gitea-vs-gitlab) - Comparaison détaillée

---

## 🎯 Prochaines Étapes

Une fois Gitea installé :

1. **Créer premier repo** et pousser code
2. **Configurer SSH keys** pour clone/push facile
3. **Tester Gitea Actions** avec workflow simple
4. **(Optionnel) Migrer repos GitHub** en mode mirror
5. **(Optionnel) Activer Packages Registry** pour Docker/npm
6. **Intégrer avec Homepage** → Lien rapide vers Gitea
7. **Configurer backups automatiques** → Phase 6 Roadmap

**Prochaine phase** : [Phase 6 - Backups Offsite](../ROADMAP.md#phase-6)

---

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](../CONTRIBUTING.md).

**Besoin d'aide ?** Ouvrir une issue sur le repo principal ou rejoindre Discord.

---

## 📄 Licence

MIT License - Voir [LICENSE](../LICENSE)

---

<p align="center">
  <strong>🦆 Git Self-Hosted Production-Ready pour Raspberry Pi 5 🦆</strong>
</p>

<p align="center">
  <sub>Gitea • PostgreSQL • Gitea Actions • Packages Registry • ARM64 • CI/CD • GitHub Actions Compatible</sub>
</p>
