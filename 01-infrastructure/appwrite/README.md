# 🚀 Appwrite - Alternative Open-Source à Firebase

> **Plateforme Backend-as-a-Service (BaaS) auto-hébergée pour construire rapidement des applications web, mobiles et Flutter.**

[![Version](https://img.shields.io/badge/version-1.5-blue.svg)](https://appwrite.io/docs/changelog)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Appwrite](https://img.shields.io/badge/Appwrite-Latest-ff69b4.svg)](https://appwrite.io/)

---

## 🎯 Vue d'Ensemble

**Appwrite** est une solution backend complète qui abstrait la complexité des tâches de développement courantes derrière un ensemble d'API REST simples à utiliser. C'est une alternative directe à Google Firebase ou à Supabase, mais avec une philosophie "privacy-first" et la flexibilité de l'auto-hébergement.

### 🤔 Pourquoi Appwrite ?

- **🚀 Développement Accéléré** : Concentrez-vous sur le frontend de votre application, Appwrite s'occupe du backend.
- **🔒 Confidentialité** : Vos données utilisateurs et votre logique métier restent sur votre propre infrastructure.
- **💰 Économique** : Pas de frais mensuels basés sur l'usage. La seule limite est la capacité de votre Raspberry Pi.
- **🌐 Universel** : SDKs pour Web, Flutter, Apple, Android, Node.js, et plus encore.
- **✨ Complet** : Authentification, base de données, stockage, fonctions cloud, tout est inclus.

---

## 🏗️ Architecture

Appwrite est architecturé comme un ensemble de microservices Docker, ce qui le rend modulaire et scalable.

```
appwrite/
├── appwrite           # Point d'entrée principal et API
├── appwrite-mariadb   # Base de données MariaDB pour les métadonnées
├── appwrite-redis     # Cache et file d'attente
├── appwrite-influxdb  # Métriques d'utilisation
├── appwrite-functions # Exécution des fonctions cloud
└── ... (et une dizaine d'autres microservices)
```

Le script de déploiement de ce projet télécharge et configure automatiquement la dernière version stable de `docker-compose.yml` fournie par l'équipe Appwrite.

---

## ⚡ Installation

L'installation est entièrement automatisée via le script fourni.

**Prérequis :**
- Raspberry Pi 5 avec au moins 4GB de RAM.
- Docker et Docker Compose installés.
- (Optionnel) Traefik pour l'accès HTTPS.

**Commande d'installation :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/appwrite/scripts/01-appwrite-deploy.sh | sudo bash
```

Le script détectera automatiquement votre configuration Traefik et exposera Appwrite sur un sous-domaine sécurisé (ex: `https://appwrite.votre-domaine.com`).

---

## 🆚 Appwrite vs Supabase

| Caractéristique | Appwrite | Supabase |
|---|---|---|
| **Philosophie** | Backend complet et simple | Alternative à Firebase basée sur PostgreSQL |
| **Base de Données** | NoSQL (MariaDB en interne) | PostgreSQL |
| **Facilité d'utilisation** | ⭐⭐⭐⭐⭐ (Très simple) | ⭐⭐⭐⭐ (Nécessite des connaissances SQL) |
| **Fonctions Cloud** | ✅ (Multi-langages) | ✅ (Deno/TypeScript) |
| **Ressources** | ~2GB RAM | ~1.2GB RAM |
| **API** | REST & Realtime | REST, GraphQL & Realtime |

**Choisissez Appwrite si :**
- Vous préférez une approche NoSQL simple.
- Vous voulez une expérience très proche de Firebase.
- Vous développez principalement des applications mobiles ou web grand public.

**Choisissez Supabase si :**
- Vous êtes à l'aise avec SQL et la puissance de PostgreSQL.
- Vous avez besoin de la flexibilité de GraphQL.
- Vous voulez un contrôle granulaire sur votre schéma de base de données.

---

## 📚 Documentation

- **[Appwrite Docs](https://appwrite.io/docs)** : Documentation officielle complète.
- **[Tutoriels de Démarrage Rapide](https://appwrite.io/docs/quick-starts)** : Pour commencer avec votre framework préféré.