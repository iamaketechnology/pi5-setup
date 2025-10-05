# ⚡ Pocketbase - Backend Ultra-Léger en 1 Fichier

> **Backend-as-a-Service (BaaS) complet dans un seul exécutable Go. Idéal pour le prototypage rapide, les applications simples et les projets personnels.**

[![Version](https://img.shields.io/badge/version-0.22-blue.svg)](https://github.com/pocketbase/pocketbase/releases)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Pocketbase](https://img.shields.io/badge/Pocketbase-Latest-lightgrey.svg)](https://pocketbase.io/)

---

## 🎯 Vue d'Ensemble

**Pocketbase** est une solution backend open-source unique qui regroupe une base de données, une authentification et une API de fichiers dans un seul et même fichier exécutable. Écrit en Go, il est incroyablement rapide, léger et portable.

### 🤔 Pourquoi Pocketbase ?

- **🚀 Simplicité Radicale** : Pas de Docker, pas de dépendances complexes. Juste un seul fichier à exécuter.
- **⚡ Performances Élevées** : Construit en Go avec une base de données SQLite, il est extrêmement rapide et consomme très peu de ressources.
- **💻 Dashboard Intégré** : Une interface d'administration complète est incluse pour gérer votre base de données, vos utilisateurs et vos fichiers.
- **🔒 Authentification Prête à l'Emploi** : Gestion des utilisateurs, fournisseurs OAuth2 (Google, GitHub, etc.) inclus.
- **✅ API Temps Réel** : Abonnements en temps réel à n'importe quel enregistrement de la base de données.

---

## 🏗️ Architecture

L'approche de Pocketbase est fondamentalement différente des autres stacks de ce projet.

- **Pas de Docker (pour le service principal)** : Le script télécharge le binaire `pocketbase` et le lance en tant que service `systemd`.
- **Base de Données Intégrée** : Utilise SQLite, ce qui signifie que votre base de données entière est un simple fichier (`pb_data/data.db`).
- **Proxy Traefik** : Pour l'intégration HTTPS, un conteneur `whoami` minimaliste est utilisé comme proxy pour rediriger le trafic de Traefik vers le service Pocketbase local.

```
┌─────────────────────────────────────────────────────────────┐
│                    RASPBERRY PI 5                           │
│                                                             │
│  ┌─────────────────┐      ┌───────────────────────────┐   │
│  │ Traefik         │ ───▶ │ pocketbase-proxy (Docker) │   │
│  │ (Reverse Proxy) │      │ (port 8090)               │   │
│  └─────────────────┘      └────────────┬──────────────┘   │
│                                        │ (proxy pass)        │
│                                        ▼                     │
│                            ┌───────────────────────────┐   │
│                            │ pocketbase (systemd service)│   │
│                            │ (binaire Go, port 8090)     │   │
│                            └───────────────────────────┘   │
│                                        │                     │
│                                        ▼                     │
│                            ┌───────────────────────────┐   │
│                            │ pb_data/data.db (SQLite)  │   │
│                            └───────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚡ Installation

L'installation est gérée par un script qui automatise le téléchargement, la configuration et le lancement de Pocketbase.

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pocketbase/scripts/01-pocketbase-deploy.sh | sudo bash
```

Pour des instructions détaillées, consultez le guide d'installation :
- **[📄 pocketbase-setup.md](pocketbase-setup.md)**

---

## 🆚 Pocketbase vs Supabase vs Appwrite

| Caractéristique | Pocketbase | Appwrite | Supabase |
|---|---|---|---|
| **Architecture** | Binaire unique | Microservices Docker | Stack PostgreSQL |
| **Base de Données** | SQLite | NoSQL (MariaDB) | PostgreSQL |
| **Ressources (RAM)** | **~30 MB** | ~2 GB | ~1.2 GB |
| **Installation** | ⭐⭐⭐⭐⭐ (Ultra simple) | ⭐⭐⭐ (Compose) | ⭐⭐⭐⭐ (Compose) |
| **Scalabilité** | Verticale (limité) | Horizontale | Horizontale |
| **Fonctions Cloud** | ✅ (Go, JS) | ✅ (Multi-langage) | ✅ (Deno/TS) |

**Choisissez Pocketbase si :**
- Vous avez besoin d'un backend pour un petit projet, un prototype ou un outil interne.
- La légèreté et la simplicité sont vos priorités absolues.
- Vous êtes à l'aise avec le fait que votre base de données soit un simple fichier.

---

## 📚 Documentation

- **[Pocketbase Docs](https://pocketbase.io/docs/)** : Documentation officielle très claire et complète.
