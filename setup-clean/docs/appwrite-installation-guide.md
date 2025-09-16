# Guide d'Installation Appwrite sur Raspberry Pi 5

## Vue d'Ensemble

Appwrite est une alternative complète à Supabase offrant une plateforme Backend-as-a-Service (BaaS) open-source. Ce guide détaille l'installation optimisée d'Appwrite sur Raspberry Pi 5, configurée pour coexister parfaitement avec une installation Supabase existante.

## Table des Matières

1. [Prérequis et Compatibilité](#prérequis-et-compatibilité)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Gestion des Services](#gestion-des-services)
5. [Coexistence avec Supabase](#coexistence-avec-supabase)
6. [Utilisation et Interface](#utilisation-et-interface)
7. [Maintenance et Monitoring](#maintenance-et-monitoring)
8. [Dépannage](#dépannage)
9. [Migration et Comparaison](#migration-et-comparaison)

## Prérequis et Compatibilité

### Configuration Système Requise

| Composant | Minimum | Recommandé | Pi 5 Status |
|-----------|---------|------------|-------------|
| **Architecture** | ARM64 | ARM64 | ✅ Native |
| **RAM** | 4GB | 8GB+ | ✅ 8-16GB |
| **OS** | Linux 64-bit | Raspberry Pi OS 64-bit | ✅ Compatible |
| **Docker** | 20.10+ | Latest | ✅ Via Week1 |
| **Docker Compose** | 2.0+ | Latest | ✅ Via Week1 |

### Validation Pré-Installation

```bash
# Vérifier architecture ARM64
uname -m  # Doit retourner 'aarch64'

# Vérifier RAM disponible
free -h  # Minimum 4GB recommandé

# Vérifier Docker
docker --version
docker-compose --version

# Vérifier OS 64-bit
getconf LONG_BIT  # Doit retourner '64'
```

### Comparaison vs Supabase

| Fonctionnalité | Appwrite | Supabase | Avantage |
|----------------|----------|----------|----------|
| **Installation** | Docker simple | Docker complexe | Appwrite |
| **Ressources** | Plus léger | Plus lourd | Appwrite |
| **API** | REST + GraphQL | REST + GraphQL | Égalité |
| **Auth** | Multi-provider | Multi-provider | Égalité |
| **Base de données** | MariaDB | PostgreSQL | Selon usage |
| **Temps réel** | WebSocket natif | PostgreSQL Listen | Appwrite |
| **Fonctions** | Multi-runtime | Edge Functions | Égalité |
| **Interface** | Console native | Studio web | Égalité |

## Installation

### Méthode Automatisée (Recommandée)

```bash
# Navigation vers le répertoire des scripts
cd /home/pi/pi5-setup/setup-clean/scripts

# Installation basique (ports par défaut)
sudo ./setup-appwrite-pi5.sh

# Installation avec port personnalisé
sudo ./setup-appwrite-pi5.sh --port=8082

# Installation avec domaine personnalisé
sudo ./setup-appwrite-pi5.sh --domain=appwrite.local --port=8081
```

### Options d'Installation

| Option | Description | Défaut | Exemple |
|--------|-------------|--------|---------|
| `--domain` | Domaine d'accès | localhost | `--domain=appwrite.local` |
| `--port` | Port HTTP | 8081 | `--port=8082` |
| `--https-port` | Port HTTPS | 8444 | `--https-port=8443` |

### Processus d'Installation Détaillé

1. **Validation Système**
   - Vérification architecture ARM64
   - Contrôle RAM minimum (4GB)
   - Test disponibilité ports
   - Validation Docker/Docker Compose

2. **Création Structure Projet**
   ```
   /home/pi/stacks/appwrite/
   ├── docker-compose.yml
   ├── .env
   ├── data/
   ├── uploads/
   ├── certificates/
   └── scripts de gestion/
   ```

3. **Génération Configuration Sécurisée**
   - Clés de chiffrement aléatoires (OpenSSL)
   - Mots de passe base de données sécurisés
   - JWT Secret unique
   - Variables d'environnement optimisées Pi 5

4. **Déploiement Services Docker**
   - MariaDB 10.7 (base de données)
   - Redis 7.0 (cache)
   - Appwrite 1.7.4 (application principale)

## Configuration

### Structure des Services

```yaml
# Architecture Docker Compose
services:
  appwrite:          # Application principale
    ports: 8081:80, 8444:443
    depends_on: [mariadb, redis]

  mariadb:           # Base de données
    volume: appwrite-mariadb

  redis:             # Cache et sessions
    volume: appwrite-redis
```

### Variables d'Environnement Clés

```bash
# Domaine et réseau
_APP_DOMAIN=localhost
_APP_DOMAIN_TARGET=localhost:8081

# Base de données
_APP_DB_HOST=mariadb
_APP_DB_SCHEMA=appwrite
_APP_DB_USER=appwrite

# Sécurité (générées automatiquement)
_APP_OPENSSL_KEY_V1=<32-char-hex>
_APP_JWT_SECRET=<64-char-secret>

# Limites optimisées Pi 5
_APP_STORAGE_LIMIT=30000000
_APP_FUNCTIONS_TIMEOUT=900
_APP_FUNCTIONS_MEMORY=1024
```

### Optimisations Spécifiques Pi 5

```json
// /etc/docker/daemon.json - Créé automatiquement
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "default-ulimits": {
    "nofile": {
      "Hard": 65536,
      "Soft": 65536
    }
  }
}
```

## Gestion des Services

### Scripts de Gestion Automatiques

| Script | Fonction | Usage |
|--------|----------|-------|
| `start-appwrite.sh` | Démarrer tous les services | `./start-appwrite.sh` |
| `stop-appwrite.sh` | Arrêter tous les services | `./stop-appwrite.sh` |
| `update-appwrite.sh` | Mettre à jour Appwrite | `./update-appwrite.sh` |
| `logs-appwrite.sh` | Afficher logs en temps réel | `./logs-appwrite.sh` |

### Commandes Docker Compose

```bash
# Navigation vers le projet
cd /home/pi/stacks/appwrite

# État des services
docker compose ps

# Logs spécifiques
docker compose logs appwrite
docker compose logs mariadb
docker compose logs redis

# Redémarrage service spécifique
docker compose restart appwrite

# Accès shell conteneur
docker compose exec appwrite /bin/sh
docker compose exec mariadb mysql -u root -p
```

### Gestion des Ressources

```bash
# Arrêter pour économiser ressources
cd /home/pi/stacks/appwrite && ./stop-appwrite.sh

# Redémarrer quand nécessaire
cd /home/pi/stacks/appwrite && ./start-appwrite.sh

# Monitoring ressources
docker stats
htop
```

## Coexistence avec Supabase

### Configuration des Ports

| Service | Supabase | Appwrite | Conflit |
|---------|----------|----------|---------|
| **Web Interface** | 3000 | 8081 | ❌ Aucun |
| **API Gateway** | 8001 | 8081 | ❌ Aucun |
| **Database** | 5432 | 3306 | ❌ Aucun |
| **HTTPS** | N/A | 8444 | ❌ Aucun |

### Utilisation Simultanée

```bash
# Démarrer Supabase
cd /home/pi/stacks/supabase
docker compose up -d

# Démarrer Appwrite
cd /home/pi/stacks/appwrite
./start-appwrite.sh

# Accès simultané
# Supabase: http://pi-ip:3000
# Appwrite: http://pi-ip:8081
```

### Gestion Ressources Partagées

```bash
# Surveiller utilisation mémoire
free -h
docker stats --no-stream

# Arrêter service non utilisé
cd /home/pi/stacks/supabase && docker compose down
# ou
cd /home/pi/stacks/appwrite && ./stop-appwrite.sh
```

## Utilisation et Interface

### Premier Accès

1. **Accès Console**
   ```bash
   # URL d'accès
   http://[IP_DU_PI]:8081

   # Exemple
   http://192.168.1.100:8081
   ```

2. **Configuration Initiale**
   - Créer compte administrateur
   - Configurer organisation
   - Créer premier projet

### Structure des Projets Appwrite

```
Projet Appwrite
├── Authentication
│   ├── Users
│   ├── Teams
│   └── Sessions
├── Databases
│   ├── Collections
│   ├── Documents
│   └── Indexes
├── Storage
│   ├── Buckets
│   └── Files
├── Functions
│   ├── Runtimes (Node.js, PHP, Python, Ruby)
│   └── Deployments
└── Settings
    ├── API Keys
    ├── Webhooks
    └── Domains
```

### API Endpoints

```bash
# Endpoint principal API
http://[IP_DU_PI]:8081/v1

# Exemples d'usage
curl http://192.168.1.100:8081/v1/health
curl -H "X-Appwrite-Project: [PROJECT_ID]" http://192.168.1.100:8081/v1/account
```

### SDKs Disponibles

- **Web** : JavaScript, TypeScript
- **Mobile** : Flutter, React Native, iOS, Android
- **Server** : Node.js, PHP, Python, Ruby, .NET, Go, Dart

## Maintenance et Monitoring

### Monitoring Santé Services

```bash
# Script de diagnostic automatique
cd /home/pi/stacks/appwrite

# Vérification santé API
curl -s http://localhost:8081/v1/health

# État base de données
docker compose exec mariadb mysqladmin ping

# État Redis
docker compose exec redis redis-cli ping

# Logs dernières erreurs
docker compose logs --tail=50
```

### Sauvegardes

```bash
# Sauvegarde base de données
docker compose exec mariadb mysqldump -u root -p[PASSWORD] appwrite > backup_$(date +%Y%m%d).sql

# Sauvegarde volumes Docker
docker run --rm -v appwrite_appwrite-uploads:/source -v $(pwd):/backup alpine tar czf /backup/uploads_backup.tar.gz -C /source .

# Sauvegarde configuration
cp .env .env.backup
cp docker-compose.yml docker-compose.yml.backup
```

### Mises à Jour

```bash
# Mise à jour automatique
./update-appwrite.sh

# Mise à jour manuelle
docker compose pull
docker compose up -d

# Vérification version
docker compose exec appwrite cat /usr/src/code/app/app.json | grep version
```

### Performance Pi 5

```bash
# Monitoring ressources
docker stats appwrite appwrite-mariadb appwrite-redis

# Température CPU
vcgencmd measure_temp

# Utilisation mémoire
free -h

# Espace disque
df -h
docker system df
```

## Dépannage

### Problèmes Communs

#### 1. Services Ne Démarrent Pas

```bash
# Diagnostic
docker compose ps
docker compose logs

# Solutions courantes
docker compose down
docker compose up -d

# Vérification ports
ss -tlnp | grep 8081
```

#### 2. Problèmes de Connectivité Base

```bash
# Test connexion MariaDB
docker compose exec mariadb mysql -u root -p -e "SHOW DATABASES;"

# Vérification réseau Docker
docker network ls
docker network inspect appwrite
```

#### 3. Erreurs de Permissions

```bash
# Correction propriétaire fichiers
sudo chown -R pi:pi /home/pi/stacks/appwrite

# Permissions volumes Docker
docker compose down
sudo chown -R 33:33 volumes/
docker compose up -d
```

#### 4. Manque de Mémoire

```bash
# Arrêter services non essentiels
cd /home/pi/stacks/supabase && docker compose down

# Optimiser configuration
# Éditer docker-compose.yml et réduire limits mémoire
```

### Logs et Debugging

```bash
# Logs détaillés par service
docker compose logs -f appwrite
docker compose logs -f mariadb
docker compose logs -f redis

# Logs système
tail -f /var/log/pi5-setup-appwrite.log

# Debug réseau
docker compose exec appwrite netstat -tlnp
```

### Recovery et Reset

```bash
# Reset complet (perte de données)
docker compose down -v
docker volume prune
rm -rf /home/pi/stacks/appwrite
# Puis réinstaller

# Reset configuration seulement
docker compose down
rm .env docker-compose.yml
# Puis relancer installation
```

## Migration et Comparaison

### Migration depuis Supabase

#### Données
- **PostgreSQL → MariaDB** : Export/Import via scripts SQL
- **Schema** : Adaptation manuelle des types de données
- **Relations** : Recréation dans Appwrite

#### Authentification
- **Utilisateurs** : Export CSV et import via API Appwrite
- **Providers OAuth** : Reconfiguration dans console Appwrite
- **Policies** : Recréation via système permissions Appwrite

#### Fichiers
- **Storage** : Transfert manuel via API
- **Buckets** : Recréation structure similaire

### Comparaison Fonctionnelle

| Fonctionnalité | Supabase | Appwrite | Notes Migration |
|----------------|----------|----------|-----------------|
| **Database** | PostgreSQL natif | MariaDB via console | Script conversion requis |
| **Real-time** | PostgreSQL Listen | WebSocket natif | Code client à adapter |
| **Auth** | GoTrue | Appwrite Auth | Configuration similaire |
| **Storage** | S3-compatible | Appwrite Storage | API différente |
| **Functions** | Deno Edge | Multi-runtime | Réécriture requise |
| **Dashboard** | Supabase Studio | Appwrite Console | Interface différente |

### Avantages/Inconvénients

#### Appwrite Avantages
✅ **Installation plus simple**
✅ **Moins de ressources système**
✅ **Interface utilisateur intuitive**
✅ **Multi-runtime functions**
✅ **WebSocket temps réel natif**
✅ **Gestion équipes intégrée**

#### Appwrite Inconvénients
❌ **Moins de flexibilité SQL**
❌ **Écosystème plus petit**
❌ **MariaDB vs PostgreSQL**
❌ **Moins de extensions**

### Stratégie de Test

```bash
# 1. Installer Appwrite en parallèle
sudo ./setup-appwrite-pi5.sh

# 2. Créer projet test
# Via console http://pi-ip:8081

# 3. Tester fonctionnalités clés
# - Authentification
# - Base de données
# - Storage
# - Functions

# 4. Comparer performances
# - Temps de réponse API
# - Utilisation ressources
# - Facilité développement

# 5. Décision migration
# Garder les deux ou migrer selon résultats
```

## Ressources et Documentation

### Documentation Officielle
- **Site Principal** : https://appwrite.io
- **Documentation** : https://appwrite.io/docs
- **GitHub** : https://github.com/appwrite/appwrite
- **Discord Community** : https://discord.gg/GSeTUeA

### Guides Spécialisés
- **Quick Start** : https://appwrite.io/docs/quick-starts
- **Self-Hosting** : https://appwrite.io/docs/advanced/self-hosting
- **API Reference** : https://appwrite.io/docs/references
- **SDKs** : https://appwrite.io/docs/sdks

### Ressources Pi 5
- **Pi 5 Installation Guide** : Documentation dans ce repository
- **Docker ARM64** : https://docs.docker.com/engine/install/raspberry-pi-os/
- **Performance Monitoring** : Scripts inclus dans installation

---

*Documentation générée automatiquement lors de l'installation Appwrite Pi 5*
*Dernière mise à jour : 16 Septembre 2025*