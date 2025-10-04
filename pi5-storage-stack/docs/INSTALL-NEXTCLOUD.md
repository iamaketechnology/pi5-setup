# ☁️ Guide d'Installation - Nextcloud

> **Plateforme cloud collaborative auto-hébergée pour Raspberry Pi 5**

---

## Table des Matières

1. [Prérequis](#prérequis)
2. [Installation Rapide](#installation-rapide)
3. [Installation Manuelle Détaillée](#installation-manuelle-détaillée)
4. [Intégration Traefik](#intégration-traefik)
5. [Intégration Homepage](#intégration-homepage)
6. [Configuration Avancée](#configuration-avancée)
7. [Gestion Utilisateurs](#gestion-utilisateurs)
8. [Premier Démarrage](#premier-démarrage)
9. [Apps Recommandées](#apps-recommandées)
10. [Optimisations Performance Pi5](#optimisations-performance-pi5)
11. [Utilisation Quotidienne](#utilisation-quotidienne)
12. [Maintenance](#maintenance)
13. [Troubleshooting](#troubleshooting)
14. [Désinstallation](#désinstallation)

---

## Prérequis

### Système Requis

- **Raspberry Pi 5** (8GB RAM recommandé pour performance optimale)
- **Raspberry Pi OS 64-bit** (Bookworm ou supérieur)
- **Docker** + **Docker Compose** installés
- **2 GB RAM** minimum disponible (3 services : Nextcloud + PostgreSQL + Redis)
- **50 GB espace disque** libre (pour stockage utilisateur)
- **Connexion stable** (installation images Docker ~800 MB)

### Stacks Optionnels (détection automatique)

- **Traefik** (pour HTTPS automatique)
- **Homepage** (pour widget dashboard)

### Vérification Système

Avant de commencer, vérifiez que votre système répond aux exigences :

```bash
# Vérifier Docker
docker --version
docker compose version

# Vérifier espace disque
df -h /home/pi

# Vérifier RAM disponible (min 2 GB)
free -h

# Vérifier connectivité
ping -c 3 8.8.8.8
```

---

## Installation Rapide

### Méthode 1 : Curl One-Liner (Recommandé)

Installation automatique avec détection Traefik :

```bash
curl -fsSL https://raw.githubusercontent.com/USER/pi5-setup/main/pi5-storage-stack/scripts/02-nextcloud-deploy.sh | sudo bash
```

### Méthode 2 : Depuis le Repo

```bash
# Cloner le repo (si pas déjà fait)
cd ~
git clone https://github.com/USER/pi5-setup.git
cd pi5-setup/pi5-storage-stack/scripts

# Lancer l'installation
sudo ./02-nextcloud-deploy.sh
```

---

## Installation Manuelle Détaillée

### Étape 1 : Préparation des Répertoires

```bash
# Créer répertoires
sudo mkdir -p /home/pi/stacks/nextcloud
sudo mkdir -p /home/pi/nextcloud-data

# Permissions
sudo chown -R www-data:www-data /home/pi/nextcloud-data
sudo chmod 750 /home/pi/nextcloud-data
```

### Étape 2 : Configuration Variables d'Environnement

```bash
# Créer fichier .env
cat > /home/pi/stacks/nextcloud/.env <<EOF
# PostgreSQL
POSTGRES_DB=nextcloud
POSTGRES_USER=nextcloud
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Redis
REDIS_PASSWORD=$(openssl rand -base64 24)

# Nextcloud Admin
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASS=$(openssl rand -base64 20)

# Domaine (modifier selon votre configuration)
NEXTCLOUD_DOMAIN=nextcloud.votredomaine.com

# Trusted Domains (ajouter votre IP locale)
NEXTCLOUD_TRUSTED_DOMAINS=localhost,$(hostname -I | awk '{print $1}')
EOF

# Sécuriser fichier
chmod 600 /home/pi/stacks/nextcloud/.env

# Sauvegarder credentials
cat > /home/pi/stacks/nextcloud/credentials.txt <<EOF
=== NEXTCLOUD CREDENTIALS ===
Admin User: admin
Admin Password: $(grep NEXTCLOUD_ADMIN_PASS /home/pi/stacks/nextcloud/.env | cut -d'=' -f2)

PostgreSQL User: nextcloud
PostgreSQL Password: $(grep POSTGRES_PASSWORD /home/pi/stacks/nextcloud/.env | cut -d'=' -f2)

Redis Password: $(grep REDIS_PASSWORD /home/pi/stacks/nextcloud/.env | cut -d'=' -f2)
EOF

chmod 600 /home/pi/stacks/nextcloud/credentials.txt
```

### Étape 3 : Docker Compose (3 Services)

```bash
cat > /home/pi/stacks/nextcloud/docker-compose.yml <<'EOF'
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 30s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 30s
      timeout: 10s
      retries: 5

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud-app
    restart: unless-stopped
    ports:
      - "8081:80"
    volumes:
      - ./html:/var/www/html
      - /home/pi/nextcloud-data:/var/www/html/data
      - ./config:/var/www/html/config
      - ./custom_apps:/var/www/html/custom_apps
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASS}
      - NEXTCLOUD_TRUSTED_DOMAINS=${NEXTCLOUD_TRUSTED_DOMAINS}
      - OVERWRITEPROTOCOL=https
      - OVERWRITECLIURL=https://${NEXTCLOUD_DOMAIN}
      - PHP_MEMORY_LIMIT=512M
      - PHP_UPLOAD_LIMIT=10G
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
EOF
```

### Étape 4 : Configuration Nextcloud (config.php)

Le fichier `config.php` sera auto-généré au premier démarrage. Voici les optimisations à appliquer après installation :

```bash
# Ce fichier sera créé automatiquement dans ./config/config.php
# Les optimisations seront appliquées à l'étape 7
```

### Étape 5 : Démarrage de la Stack

```bash
cd /home/pi/stacks/nextcloud

# Charger variables
source .env

# Démarrer services
docker compose up -d

# Attendre démarrage complet (2-3 minutes)
echo "⏳ Démarrage de Nextcloud en cours..."
sleep 120

# Vérifier statut
docker compose ps
```

### Étape 6 : Installation Apps Recommandées

```bash
# Attendre que Nextcloud soit complètement initialisé
sleep 30

# Installer apps essentielles via OCC CLI
docker exec -u www-data nextcloud-app php occ app:install calendar
docker exec -u www-data nextcloud-app php occ app:install contacts
docker exec -u www-data nextcloud-app php occ app:install tasks
docker exec -u www-data nextcloud-app php occ app:install notes

# Apps productivité
docker exec -u www-data nextcloud-app php occ app:install files_external
docker exec -u www-data nextcloud-app php occ app:install files_versions
docker exec -u www-data nextcloud-app php occ app:install photos

# Vérifier apps installées
docker exec -u www-data nextcloud-app php occ app:list
```

### Étape 7 : Optimisations Performance Pi5

```bash
# Activer caching Redis
docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.local --value='\OC\Memcache\APCu'

docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.distributed --value='\OC\Memcache\Redis'

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis host --value=redis

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis port --value=6379 --type=integer

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis password --value="${REDIS_PASSWORD}"

# Activer file locking via Redis
docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.locking --value='\OC\Memcache\Redis'

# Optimiser opcache PHP
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.enable' --value=1 --type=integer

docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.memory_consumption' --value=128 --type=integer

# Configurer cron (background jobs)
docker exec -u www-data nextcloud-app php occ background:cron

# Ajouter tâche cron (exécution toutes les 5 min)
(crontab -l 2>/dev/null; echo "*/5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php") | crontab -

# Optimiser base de données
docker exec -u www-data nextcloud-app php occ db:add-missing-indices
docker exec -u www-data nextcloud-app php occ db:convert-filecache-bigint

# Vérifier configuration
docker exec -u www-data nextcloud-app php occ config:list system
```

---

## Intégration Traefik

### Scénario 1 : DuckDNS (Path-based)

Modifier le fichier `docker-compose.yml` :

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 30s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - ./html:/var/www/html
      - /home/pi/nextcloud-data:/var/www/html/data
      - ./config:/var/www/html/config
      - ./custom_apps:/var/www/html/custom_apps
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASS}
      - NEXTCLOUD_TRUSTED_DOMAINS=${NEXTCLOUD_TRUSTED_DOMAINS}
      - OVERWRITEPROTOCOL=https
      - OVERWRITECLIURL=https://${NEXTCLOUD_DOMAIN}/cloud
      - OVERWRITEWEBROOT=/cloud
      - PHP_MEMORY_LIMIT=512M
      - PHP_UPLOAD_LIMIT=10G
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=PathPrefix(`/cloud`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.nextcloud-stripprefix.stripprefix.prefixes=/cloud"
      - "traefik.http.middlewares.nextcloud-headers.headers.customRequestHeaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.regex=https://(.*)/.well-known/(card|cal)dav"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.replacement=https://$$1/cloud/remote.php/dav/"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-stripprefix,nextcloud-headers,nextcloud-redirect"

networks:
  traefik-network:
    external: true
```

**Accès** : `https://votresubdomain.duckdns.org/cloud`

### Scénario 2 : Cloudflare (Subdomain)

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 30s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - ./html:/var/www/html
      - /home/pi/nextcloud-data:/var/www/html/data
      - ./config:/var/www/html/config
      - ./custom_apps:/var/www/html/custom_apps
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASS}
      - NEXTCLOUD_TRUSTED_DOMAINS=cloud.votredomaine.com
      - OVERWRITEPROTOCOL=https
      - OVERWRITECLIURL=https://cloud.votredomaine.com
      - PHP_MEMORY_LIMIT=512M
      - PHP_UPLOAD_LIMIT=10G
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`cloud.votredomaine.com`)"
      - "traefik.http.routers.nextcloud.entrypoints=websecure"
      - "traefik.http.routers.nextcloud.tls.certresolver=cloudflare"
      - "traefik.http.middlewares.nextcloud-headers.headers.customRequestHeaders.X-Forwarded-Proto=https"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.regex=https://(.*)/.well-known/(card|cal)dav"
      - "traefik.http.middlewares.nextcloud-redirect.redirectregex.replacement=https://$$1/remote.php/dav/"
      - "traefik.http.routers.nextcloud.middlewares=nextcloud-headers,nextcloud-redirect"

networks:
  traefik-network:
    external: true
```

**Accès** : `https://cloud.votredomaine.com`

### Scénario 3 : VPN/Local

```yaml
version: '3.8'

services:
  db:
    image: postgres:15-alpine
    container_name: nextcloud-db
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nextcloud"]
      interval: 30s
      timeout: 10s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: nextcloud-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}

  nextcloud:
    image: nextcloud:latest
    container_name: nextcloud-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - ./html:/var/www/html
      - /home/pi/nextcloud-data:/var/www/html/data
      - ./config:/var/www/html/config
      - ./custom_apps:/var/www/html/custom_apps
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_HOST_PASSWORD=${REDIS_PASSWORD}
      - NEXTCLOUD_ADMIN_USER=${NEXTCLOUD_ADMIN_USER}
      - NEXTCLOUD_ADMIN_PASSWORD=${NEXTCLOUD_ADMIN_PASS}
      - NEXTCLOUD_TRUSTED_DOMAINS=cloud.pi.local
      - OVERWRITEPROTOCOL=http
      - OVERWRITECLIURL=http://cloud.pi.local
      - PHP_MEMORY_LIMIT=512M
      - PHP_UPLOAD_LIMIT=10G
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.nextcloud.rule=Host(`cloud.pi.local`)"
      - "traefik.http.routers.nextcloud.entrypoints=web"

networks:
  traefik-network:
    external: true
```

**Accès** : `http://cloud.pi.local` (via Tailscale/VPN)

---

## Intégration Homepage

### Ajouter le Widget Nextcloud

```bash
# Ajouter widget Nextcloud à Homepage
cat >> /home/pi/stacks/homepage/config/services.yaml <<'EOF'
- Cloud:
    - Nextcloud:
        icon: nextcloud
        href: https://cloud.votredomaine.com
        description: Plateforme cloud collaborative
        widget:
          type: nextcloud
          url: http://nextcloud-app:80
          username: admin
          password: ${NEXTCLOUD_ADMIN_PASS}
EOF

# Redémarrer Homepage
cd /home/pi/stacks/homepage
docker compose restart
```

---

## Configuration Avancée

### Collabora Online (Office en Ligne)

Ajouter service Collabora au `docker-compose.yml` :

```yaml
  collabora:
    image: collabora/code:latest
    container_name: nextcloud-collabora
    restart: unless-stopped
    networks:
      - traefik-network
    environment:
      - domain=cloud\\.votredomaine\\.com
      - username=admin
      - password=${COLLABORA_PASSWORD}
      - extra_params=--o:ssl.enable=false --o:ssl.termination=true
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.collabora.rule=Host(`office.votredomaine.com`)"
      - "traefik.http.routers.collabora.entrypoints=websecure"
      - "traefik.http.routers.collabora.tls.certresolver=cloudflare"
      - "traefik.http.services.collabora.loadbalancer.server.port=9980"
```

Configuration dans Nextcloud :

```bash
# Installer app Collabora
docker exec -u www-data nextcloud-app php occ app:install richdocuments

# Configurer URL serveur Collabora
docker exec -u www-data nextcloud-app php occ config:app:set richdocuments wopi_url --value="https://office.votredomaine.com"
```

### OnlyOffice (Alternative à Collabora)

```yaml
  onlyoffice:
    image: onlyoffice/documentserver:latest
    container_name: nextcloud-onlyoffice
    restart: unless-stopped
    networks:
      - traefik-network
    environment:
      - JWT_SECRET=${ONLYOFFICE_JWT_SECRET}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.onlyoffice.rule=Host(`office.votredomaine.com`)"
      - "traefik.http.routers.onlyoffice.entrypoints=websecure"
      - "traefik.http.routers.onlyoffice.tls.certresolver=cloudflare"
      - "traefik.http.services.onlyoffice.loadbalancer.server.port=80"
```

Configuration :

```bash
# Installer app OnlyOffice
docker exec -u www-data nextcloud-app php occ app:install onlyoffice

# Configurer
docker exec -u www-data nextcloud-app php occ config:app:set onlyoffice DocumentServerUrl --value="https://office.votredomaine.com/"
docker exec -u www-data nextcloud-app php occ config:app:set onlyoffice jwt_secret --value="${ONLYOFFICE_JWT_SECRET}"
```

### Authentification 2FA (TOTP)

```bash
# Installer app TOTP
docker exec -u www-data nextcloud-app php occ app:install twofactor_totp

# Activer pour admin
docker exec -u www-data nextcloud-app php occ twofactorauth:enforce --on

# Utilisateur configure via Settings → Security → Two-Factor Authentication
```

### Chiffrement End-to-End (E2E)

```bash
# Installer app encryption
docker exec -u www-data nextcloud-app php occ app:install end_to_end_encryption

# Activer encryption
docker exec -u www-data nextcloud-app php occ encryption:enable

# Activer encryption par défaut
docker exec -u www-data nextcloud-app php occ encryption:encrypt-all
```

### External Storage (SMB, S3, etc.)

```bash
# Activer app files_external
docker exec -u www-data nextcloud-app php occ app:install files_external

# Ajouter stockage SMB/CIFS (exemple)
docker exec -u www-data nextcloud-app php occ files_external:create \
  /external-smb smb \
  password::password \
  --config host=192.168.1.100 \
  --config share=shared \
  --config user=username \
  --config password=password

# Ajouter stockage S3 (exemple)
docker exec -u www-data nextcloud-app php occ files_external:create \
  /external-s3 amazons3 \
  amazons3::accesskey \
  --config bucket=mybucket \
  --config region=us-east-1 \
  --config key=AKIAIOSFODNN7EXAMPLE \
  --config secret=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# Lister stockages externes
docker exec -u www-data nextcloud-app php occ files_external:list
```

---

## Gestion Utilisateurs

### Créer des Utilisateurs via OCC CLI

```bash
# Créer utilisateur avec mot de passe manuel
docker exec -u www-data nextcloud-app php occ user:add alice

# Créer utilisateur avec mot de passe depuis variable
export USER_PASS=$(openssl rand -base64 16)
echo "$USER_PASS" | docker exec -i -u www-data nextcloud-app php occ user:add bob --password-from-env

# Lister utilisateurs
docker exec -u www-data nextcloud-app php occ user:list

# Infos utilisateur
docker exec -u www-data nextcloud-app php occ user:info alice
```

### Modifier Utilisateurs

```bash
# Changer mot de passe
docker exec -u www-data nextcloud-app php occ user:resetpassword alice

# Activer/Désactiver utilisateur
docker exec -u www-data nextcloud-app php occ user:disable alice
docker exec -u www-data nextcloud-app php occ user:enable alice

# Définir quota
docker exec -u www-data nextcloud-app php occ user:setting alice files quota "10 GB"

# Ajouter utilisateur à un groupe
docker exec -u www-data nextcloud-app php occ group:adduser developers alice
```

### Groupes

```bash
# Créer groupe
docker exec -u www-data nextcloud-app php occ group:add developers

# Lister groupes
docker exec -u www-data nextcloud-app php occ group:list

# Lister membres d'un groupe
docker exec -u www-data nextcloud-app php occ group:list developers
```

---

## Premier Démarrage

### 1. Accéder à l'Interface Web

- **Sans Traefik** : `http://IP_PI:8081`
- **Avec Traefik** : Voir URL dans résumé du script d'installation

### 2. Se Connecter

```
Utilisateur : admin
Mot de passe : Voir /home/pi/stacks/nextcloud/credentials.txt
```

```bash
# Afficher credentials
cat /home/pi/stacks/nextcloud/credentials.txt
```

### 3. Assistant de Configuration Initial

Si l'installation automatique échoue, l'assistant web vous guidera :

1. **Compte Admin** : Créer utilisateur administrateur
2. **Base de données** :
   - Type : PostgreSQL
   - Utilisateur : `nextcloud`
   - Mot de passe : Voir `credentials.txt`
   - Base : `nextcloud`
   - Hôte : `db:5432`
3. **Répertoire de données** : `/var/www/html/data` (pré-configuré)
4. **Apps recommandées** : Installer Calendar, Contacts, Talk, Mail

### 4. Vérifier Status

```bash
# Status système
docker exec -u www-data nextcloud-app php occ status

# Vérifier configuration
docker exec -u www-data nextcloud-app php occ config:list system

# Vérifier apps installées
docker exec -u www-data nextcloud-app php occ app:list --shipped=false
```

### 5. Changer le Mot de Passe Admin

```bash
# Via CLI (recommandé)
docker exec -u www-data nextcloud-app php occ user:resetpassword admin

# Via Web : Settings → Personal → Security
```

---

## Apps Recommandées

### Productivité

```bash
# Calendar (CalDAV)
docker exec -u www-data nextcloud-app php occ app:install calendar

# Contacts (CardDAV)
docker exec -u www-data nextcloud-app php occ app:install contacts

# Tasks (gestionnaire de tâches)
docker exec -u www-data nextcloud-app php occ app:install tasks

# Notes (prise de notes Markdown)
docker exec -u www-data nextcloud-app php occ app:install notes

# Deck (Kanban boards)
docker exec -u www-data nextcloud-app php occ app:install deck
```

### Fichiers

```bash
# External Storage (SMB, S3, FTP, etc.)
docker exec -u www-data nextcloud-app php occ app:install files_external

# Files Versions (historique versions)
docker exec -u www-data nextcloud-app php occ app:install files_versions

# Files Trashbin (corbeille)
docker exec -u www-data nextcloud-app php occ app:install files_trashbin

# Files Automated Tagging (tags automatiques)
docker exec -u www-data nextcloud-app php occ app:install files_automatedtagging
```

### Médias

```bash
# Photos (galerie intelligente)
docker exec -u www-data nextcloud-app php occ app:install photos

# Recognize (reconnaissance IA : visages, objets)
docker exec -u www-data nextcloud-app php occ app:install recognize

# Memories (galerie photos avec timeline)
docker exec -u www-data nextcloud-app php occ app:install memories

# Music (lecteur audio)
docker exec -u www-data nextcloud-app php occ app:install music
```

### Communication

```bash
# Mail (client email)
docker exec -u www-data nextcloud-app php occ app:install mail

# Talk (chat + vidéoconférence)
docker exec -u www-data nextcloud-app php occ app:install spreed

# Notifications (centre de notifications)
docker exec -u www-data nextcloud-app php occ app:install notifications
```

### Collaboration

```bash
# Collabora Online (office en ligne)
docker exec -u www-data nextcloud-app php occ app:install richdocuments

# OnlyOffice (alternative Collabora)
docker exec -u www-data nextcloud-app php occ app:install onlyoffice

# Forms (création de formulaires)
docker exec -u www-data nextcloud-app php occ app:install forms

# Polls (sondages/votes)
docker exec -u www-data nextcloud-app php occ app:install polls
```

### Sécurité

```bash
# Two-Factor TOTP (2FA via app mobile)
docker exec -u www-data nextcloud-app php occ app:install twofactor_totp

# End-to-End Encryption
docker exec -u www-data nextcloud-app php occ app:install end_to_end_encryption

# Suspicious Login (détection connexions suspectes)
docker exec -u www-data nextcloud-app php occ app:install suspicious_login

# Brute Force Protection (protection attaques)
docker exec -u www-data nextcloud-app php occ app:install bruteforcesettings
```

---

## Optimisations Performance Pi5

### Redis Caching (CRUCIAL pour Pi5)

```bash
# Configurer Redis pour caching local (APCu)
docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.local --value='\OC\Memcache\APCu'

# Configurer Redis pour caching distribué
docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.distributed --value='\OC\Memcache\Redis'

# Configurer Redis pour file locking
docker exec -u www-data nextcloud-app php occ config:system:set \
  memcache.locking --value='\OC\Memcache\Redis'

# Configuration connexion Redis
docker exec -u www-data nextcloud-app php occ config:system:set \
  redis host --value=redis

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis port --value=6379 --type=integer

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis password --value="VOTRE_REDIS_PASSWORD"

docker exec -u www-data nextcloud-app php occ config:system:set \
  redis timeout --value=1.5 --type=float
```

### PHP OpCache

```bash
# Activer opcache
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.enable' --value=1 --type=integer

# Memory pour opcache (128 MB recommandé pour Pi5)
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.memory_consumption' --value=128 --type=integer

# Interned strings buffer
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.interned_strings_buffer' --value=16 --type=integer

# Max accelerated files
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.max_accelerated_files' --value=10000 --type=integer

# Revalidation
docker exec -u www-data nextcloud-app php occ config:system:set \
  'opcache.revalidate_freq' --value=60 --type=integer
```

### Memory Limits (512M pour Pi5)

```bash
# Memory limit PHP
docker exec -u www-data nextcloud-app php occ config:system:set \
  'memory_limit' --value='512M'

# Upload max filesize
docker exec -u www-data nextcloud-app php occ config:system:set \
  'upload_max_filesize' --value='10G'

# Post max size
docker exec -u www-data nextcloud-app php occ config:system:set \
  'post_max_size' --value='10G'
```

### Cron Jobs (Background Jobs)

```bash
# Configurer cron mode (plus performant que AJAX)
docker exec -u www-data nextcloud-app php occ background:cron

# Ajouter tâche cron système (exécution toutes les 5 min)
(crontab -l 2>/dev/null; echo "*/5 * * * * docker exec -u www-data nextcloud-app php -f /var/www/html/cron.php") | crontab -

# Vérifier dernière exécution cron
docker exec -u www-data nextcloud-app php occ config:app:get core lastcron
```

### Base de Données PostgreSQL

```bash
# Ajouter indices manquants (améliore performance)
docker exec -u www-data nextcloud-app php occ db:add-missing-indices

# Convertir en BIGINT (support >4 milliards de fichiers)
docker exec -u www-data nextcloud-app php occ db:convert-filecache-bigint

# Optimiser colonnes
docker exec -u www-data nextcloud-app php occ db:add-missing-columns

# Optimiser primary keys
docker exec -u www-data nextcloud-app php occ db:add-missing-primary-keys
```

### Previews (Aperçus)

```bash
# Activer génération previews
docker exec -u www-data nextcloud-app php occ config:system:set \
  'enable_previews' --value=true --type=boolean

# Taille max preview
docker exec -u www-data nextcloud-app php occ config:system:set \
  'preview_max_x' --value=2048 --type=integer

docker exec -u www-data nextcloud-app php occ config:system:set \
  'preview_max_y' --value=2048 --type=integer

# Pré-générer previews (long, exécuter en arrière-plan)
docker exec -u www-data nextcloud-app php occ preview:generate-all &
```

---

## Utilisation Quotidienne

### Upload de Fichiers

#### Via Interface Web

1. Ouvrir application Files
2. Cliquer bouton **+** → **Upload file**
3. Sélectionner fichiers ou glisser-déposer
4. Suivre progression dans notification

#### Via WebDAV (Desktop)

```bash
# Monter Nextcloud comme lecteur réseau
# Windows : \\cloud.votredomaine.com@SSL\remote.php\dav\files\username
# macOS/Linux : https://cloud.votredomaine.com/remote.php/dav/files/username
```

#### Via Client Desktop Sync

Télécharger client officiel :
- **Windows/macOS/Linux** : https://nextcloud.com/install/#install-clients
- Configuration : URL serveur + identifiants

### Sync Desktop (Windows/macOS/Linux)

```bash
# Installation client Nextcloud Desktop
# Windows : Télécharger .exe depuis https://nextcloud.com/install/
# macOS : brew install nextcloud
# Linux (Ubuntu/Debian) :
sudo add-apt-repository ppa:nextcloud-devs/client
sudo apt update
sudo apt install nextcloud-desktop

# Configuration
# 1. Lancer Nextcloud Desktop
# 2. Server Address : https://cloud.votredomaine.com
# 3. Login : username + password
# 4. Choisir dossiers à synchroniser
# 5. Sync démarre automatiquement
```

### Apps Mobiles

#### Android

```
1. Google Play Store : Rechercher "Nextcloud"
2. Installer app officielle
3. Configuration :
   - Server Address : https://cloud.votredomaine.com
   - Username + Password
4. Activer auto-upload photos (optionnel)
```

#### iOS

```
1. App Store : Rechercher "Nextcloud"
2. Installer app officielle
3. Configuration :
   - Server Address : https://cloud.votredomaine.com
   - Username + Password
4. Activer auto-upload photos (optionnel)
```

### Calendrier/Contacts (CalDAV/CardDAV)

#### Configuration Thunderbird (Desktop)

```bash
# Calendrier
1. Thunderbird → Calendar → New Calendar
2. Type : On the Network
3. Format : CalDAV
4. Location : https://cloud.votredomaine.com/remote.php/dav/calendars/USERNAME/personal
5. Username + Password

# Contacts
1. Thunderbird → Address Book → New Address Book
2. Type : CardDAV
3. Location : https://cloud.votredomaine.com/remote.php/dav/addressbooks/users/USERNAME/contacts
4. Username + Password
```

#### Smartphone (Android/iOS)

**Android** : Installer DAVx⁵ depuis Play Store
```
1. Ouvrir DAVx⁵
2. Add Account → Login with URL
3. Base URL : https://cloud.votredomaine.com
4. Username + Password
5. Sélectionner Calendars + Contacts à synchroniser
```

**iOS** : Configuration native
```
Settings → Mail → Accounts → Add Account
→ Other → Add CalDAV Account / Add CardDAV Account
Server : cloud.votredomaine.com
Username + Password
```

### Édition Documents en Ligne

#### Collabora Online

```bash
# Depuis Files
1. Cliquer sur document (.docx, .xlsx, .pptx)
2. S'ouvre automatiquement dans Collabora
3. Édition collaborative en temps réel
4. Sauvegarde auto
```

#### OnlyOffice

```bash
# Depuis Files
1. Cliquer sur document
2. Choose Editor → OnlyOffice
3. Édition + collaboration
4. Export PDF/DOCX/etc.
```

---

## Maintenance

### Backup PostgreSQL

```bash
# Backup complet base de données
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > nextcloud-backup-$(date +%Y%m%d).sql

# Backup avec compression
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | gzip > nextcloud-backup-$(date +%Y%m%d).sql.gz

# Automatiser backup quotidien (cron)
cat > /home/pi/scripts/nextcloud-db-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/home/pi/backups/nextcloud"
mkdir -p "$BACKUP_DIR"
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | gzip > "$BACKUP_DIR/nextcloud-db-$(date +%Y%m%d-%H%M%S).sql.gz"
# Rotation : garder 7 jours
find "$BACKUP_DIR" -name "nextcloud-db-*.sql.gz" -mtime +7 -delete
EOF

chmod +x /home/pi/scripts/nextcloud-db-backup.sh

# Ajouter au cron (quotidien 2h du matin)
(crontab -l 2>/dev/null; echo "0 2 * * * /home/pi/scripts/nextcloud-db-backup.sh") | crontab -
```

### Backup Données Utilisateur

```bash
# Backup complet données (/home/pi/nextcloud-data)
tar czf nextcloud-data-backup-$(date +%Y%m%d).tar.gz /home/pi/nextcloud-data

# Backup incrémental (rsync)
rsync -avz --delete /home/pi/nextcloud-data /mnt/backup/nextcloud-data

# Backup vers stockage externe (rclone)
rclone sync /home/pi/nextcloud-data remote:nextcloud-data
```

### Backup Configuration Nextcloud

```bash
# Backup config.php + apps + docker-compose
tar czf nextcloud-config-backup-$(date +%Y%m%d).tar.gz \
  /home/pi/stacks/nextcloud/config \
  /home/pi/stacks/nextcloud/custom_apps \
  /home/pi/stacks/nextcloud/docker-compose.yml \
  /home/pi/stacks/nextcloud/.env
```

### Restauration Complète

```bash
# 1. Arrêter services
cd /home/pi/stacks/nextcloud
docker compose down

# 2. Restaurer PostgreSQL
gunzip < nextcloud-backup-20251004.sql.gz | docker exec -i nextcloud-db psql -U nextcloud nextcloud

# 3. Restaurer données
tar xzf nextcloud-data-backup-20251004.tar.gz -C /

# 4. Restaurer configuration
tar xzf nextcloud-config-backup-20251004.tar.gz -C /

# 5. Redémarrer services
docker compose up -d

# 6. Vérifier status
docker exec -u www-data nextcloud-app php occ status

# 7. Scanner fichiers restaurés
docker exec -u www-data nextcloud-app php occ files:scan --all
```

### Mise à Jour Nextcloud

```bash
# Méthode 1 : Via OCC CLI (recommandé)
cd /home/pi/stacks/nextcloud

# Activer mode maintenance
docker exec -u www-data nextcloud-app php occ maintenance:mode --on

# Backup avant mise à jour
docker exec nextcloud-db pg_dump -U nextcloud nextcloud | gzip > nextcloud-backup-pre-update-$(date +%Y%m%d).sql.gz

# Pull nouvelle image
docker compose pull

# Redémarrer avec nouvelle version
docker compose up -d

# Lancer mise à jour
docker exec -u www-data nextcloud-app php occ upgrade

# Désactiver mode maintenance
docker exec -u www-data nextcloud-app php occ maintenance:mode --off

# Vérifier version
docker exec -u www-data nextcloud-app php occ status
```

```bash
# Méthode 2 : Via Interface Web
# Settings → Administration → Overview
# Si mise à jour disponible, cliquer "Open updater"
# Suivre assistant
```

### Mise à Jour Apps

```bash
# Lister apps avec mises à jour disponibles
docker exec -u www-data nextcloud-app php occ app:update --all --showonly

# Mettre à jour toutes les apps
docker exec -u www-data nextcloud-app php occ app:update --all

# Mettre à jour app spécifique
docker exec -u www-data nextcloud-app php occ app:update calendar
```

### Logs

```bash
# Logs Docker Compose
cd /home/pi/stacks/nextcloud
docker compose logs -f

# Logs Nextcloud seulement
docker compose logs -f nextcloud

# Logs PostgreSQL
docker compose logs -f db

# Logs Redis
docker compose logs -f redis

# Logs Nextcloud (fichier interne)
docker exec nextcloud-app tail -f /var/www/html/data/nextcloud.log

# Export logs vers fichier
docker compose logs --since 24h > nextcloud-logs-$(date +%Y%m%d).log

# Logs depuis date spécifique
docker compose logs --since 2025-10-04T10:00:00
```

### Nettoyage et Optimisation

```bash
# Nettoyer fichiers temporaires
docker exec -u www-data nextcloud-app php occ trashbin:cleanup --all-users

# Nettoyer versions anciennes (garder dernières versions)
docker exec -u www-data nextcloud-app php occ versions:cleanup

# Scanner et réparer fichiers
docker exec -u www-data nextcloud-app php occ files:scan --all
docker exec -u www-data nextcloud-app php occ files:scan-app-data

# Réindexer recherche
docker exec -u www-data nextcloud-app php occ fulltextsearch:index

# Optimiser base de données
docker exec -u www-data nextcloud-app php occ db:add-missing-indices
docker exec nextcloud-db psql -U nextcloud -c "VACUUM ANALYZE;"
```

---

## Troubleshooting

### Problème : Trusted Domain Error

**Symptôme** : "Access through untrusted domain"

**Solution** :
```bash
# Ajouter domaine à la liste trusted
docker exec -u www-data nextcloud-app php occ config:system:set \
  trusted_domains 1 --value=cloud.votredomaine.com

docker exec -u www-data nextcloud-app php occ config:system:set \
  trusted_domains 2 --value=192.168.1.100

# Lister trusted domains
docker exec -u www-data nextcloud-app php occ config:system:get trusted_domains
```

### Problème : PostgreSQL Connection Failed

**Symptôme** : "SQLSTATE[08006] could not connect to server"

**Solution** :
```bash
# Vérifier PostgreSQL est démarré
docker ps | grep nextcloud-db

# Vérifier logs PostgreSQL
docker logs nextcloud-db

# Tester connexion depuis Nextcloud
docker exec nextcloud-app ping -c 3 db

# Vérifier credentials dans .env
cat /home/pi/stacks/nextcloud/.env | grep POSTGRES

# Recréer container DB si nécessaire
cd /home/pi/stacks/nextcloud
docker compose down
docker compose up -d db
sleep 10
docker compose up -d nextcloud
```

### Problème : Redis Connection Error

**Symptôme** : "Redis server went away"

**Solution** :
```bash
# Vérifier Redis est démarré
docker ps | grep nextcloud-redis

# Tester connexion Redis
docker exec nextcloud-redis redis-cli -a "$REDIS_PASSWORD" ping

# Vérifier config Redis dans Nextcloud
docker exec -u www-data nextcloud-app php occ config:system:get redis

# Recharger config Redis
docker compose restart redis
docker compose restart nextcloud
```

### Problème : Nextcloud Bloqué en Maintenance Mode

**Symptôme** : "Nextcloud is in maintenance mode"

**Solution** :
```bash
# Désactiver mode maintenance
docker exec -u www-data nextcloud-app php occ maintenance:mode --off

# Si échec, éditer config.php manuellement
docker exec nextcloud-app sed -i "s/'maintenance' => true/'maintenance' => false/" /var/www/html/config/config.php

# Redémarrer
docker compose restart nextcloud
```

### Problème : Upload Échoue (Limites PHP)

**Symptôme** : "The uploaded file exceeds the upload_max_filesize directive"

**Solution** :
```bash
# Augmenter limites dans .env
cat >> /home/pi/stacks/nextcloud/.env <<EOF
PHP_UPLOAD_LIMIT=20G
PHP_MEMORY_LIMIT=1024M
EOF

# Redémarrer
docker compose up -d

# Vérifier limites PHP
docker exec nextcloud-app php -i | grep -E 'upload_max_filesize|post_max_size|memory_limit'

# Alternative : Modifier config.php
docker exec -u www-data nextcloud-app php occ config:system:set \
  'upload_max_filesize' --value='20G'
```

### Problème : Apps Ne S'installent Pas

**Symptôme** : "Could not install app" ou timeout

**Solution** :
```bash
# Vérifier connectivité internet
docker exec nextcloud-app ping -c 3 apps.nextcloud.com

# Installer manuellement via OCC
docker exec -u www-data nextcloud-app php occ app:install NOM_APP

# Télécharger .tar.gz manuellement
wget https://github.com/nextcloud/NOM_APP/releases/download/vX.X.X/NOM_APP.tar.gz
tar xzf NOM_APP.tar.gz -C /home/pi/stacks/nextcloud/custom_apps/
docker exec -u www-data nextcloud-app php occ app:enable NOM_APP

# Vérifier permissions
docker exec nextcloud-app chown -R www-data:www-data /var/www/html/custom_apps
```

### Problème : Performance Lente

**Symptôme** : Interface web lente, chargement long

**Solution** :
```bash
# Vérifier Redis caching actif
docker exec -u www-data nextcloud-app php occ config:system:get memcache.distributed

# Activer opcache
docker exec -u www-data nextcloud-app php occ config:system:set 'opcache.enable' --value=1 --type=integer

# Optimiser DB
docker exec -u www-data nextcloud-app php occ db:add-missing-indices
docker exec nextcloud-db psql -U nextcloud -c "VACUUM ANALYZE;"

# Vérifier logs erreurs
docker exec -u www-data nextcloud-app php occ log:file

# Monitorer ressources
docker stats nextcloud-app nextcloud-db nextcloud-redis
```

### Problème : CalDAV/CardDAV Ne Fonctionne Pas

**Symptôme** : Sync calendrier/contacts échoue

**Solution** :
```bash
# Vérifier URLs correctes
# CalDAV : https://cloud.votredomaine.com/remote.php/dav/calendars/USERNAME/personal
# CardDAV : https://cloud.votredomaine.com/remote.php/dav/addressbooks/users/USERNAME/contacts

# Tester depuis terminal
curl -u username:password https://cloud.votredomaine.com/remote.php/dav/calendars/USERNAME/

# Vérifier redirect .well-known
docker exec -u www-data nextcloud-app php occ config:system:get overwrite.cli.url

# Ajouter redirect si manquant (voir labels Traefik dans docker-compose)
```

---

## Désinstallation

### Désinstallation Complète

```bash
# 1. Arrêter et supprimer conteneurs
cd /home/pi/stacks/nextcloud
docker compose down -v

# 2. Supprimer stack (ATTENTION : perte config)
rm -rf /home/pi/stacks/nextcloud

# 3. Garder données utilisateur
# /home/pi/nextcloud-data reste intact
```

### Désinstallation avec Suppression Données

```bash
# ATTENTION : Supprime TOUT y compris données utilisateur
cd /home/pi/stacks/nextcloud
docker compose down -v

rm -rf /home/pi/stacks/nextcloud
rm -rf /home/pi/nextcloud-data  # ⚠️ Perte définitive fichiers

# Retirer tâche cron
crontab -l | grep -v nextcloud | crontab -

# Retirer widget Homepage (si configuré)
# Éditer manuellement /home/pi/stacks/homepage/config/services.yaml
```

### Désinstallation Partielle (Garder Données)

```bash
# Arrêter services mais garder données
docker compose down

# Supprimer uniquement config Docker
rm /home/pi/stacks/nextcloud/docker-compose.yml
rm /home/pi/stacks/nextcloud/.env

# Données préservées dans :
# - /home/pi/nextcloud-data (fichiers utilisateur)
# - /home/pi/stacks/nextcloud/db (base PostgreSQL)
```

---

## Ressources Supplémentaires

- **Documentation officielle** : https://docs.nextcloud.com/
- **Apps Store** : https://apps.nextcloud.com/
- **Forum** : https://help.nextcloud.com/
- **Common Scripts** : [Backup automatique](../../common-scripts/README.md)
- **Homepage** : [Intégration dashboard](../../pi5-homepage-stack/README.md)
- **Traefik** : [Configuration HTTPS](../../pi5-traefik-stack/README.md)

---

<p align="center">
  <strong>☁️ Nextcloud déployé avec succès sur votre Pi5 ! ☁️</strong>
</p>

<p align="center">
  <sub>Collaboratif • Performant • Self-hosted • Privacy-first</sub>
</p>
