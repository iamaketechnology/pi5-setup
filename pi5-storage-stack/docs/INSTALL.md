# 📁 Guide d'Installation - FileBrowser

> **Gestionnaire de fichiers web léger pour Raspberry Pi 5**

---

## Table des Matières

1. [Prérequis](#prérequis)
2. [Installation Rapide](#installation-rapide)
3. [Installation Manuelle Détaillée](#installation-manuelle-détaillée)
4. [Configuration Avancée](#configuration-avancée)
5. [Premier Démarrage](#premier-démarrage)
6. [Gestion Utilisateurs](#gestion-utilisateurs)
7. [Intégration Traefik](#intégration-traefik)
8. [Intégration Homepage](#intégration-homepage)
9. [Maintenance](#maintenance)
10. [Troubleshooting](#troubleshooting)
11. [Désinstallation](#désinstallation)

---

## Prérequis

### Système Requis

- **Raspberry Pi 5** (4GB RAM minimum, 8GB recommandé)
- **Raspberry Pi OS 64-bit** (Bookworm ou supérieur)
- **Docker** + **Docker Compose** installés
- **50 MB RAM** disponible
- **10 GB espace disque** libre (pour stockage fichiers)

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

# Vérifier RAM disponible
free -h
```

---

## Installation Rapide

### Méthode 1 : Curl One-Liner (Recommandé)

Installation automatique avec détection Traefik :

```bash
curl -fsSL https://raw.githubusercontent.com/USER/pi5-setup/main/pi5-storage-stack/scripts/01-filebrowser-deploy.sh | sudo bash
```

### Méthode 2 : Depuis le Repo

```bash
# Cloner le repo (si pas déjà fait)
cd ~
git clone https://github.com/USER/pi5-setup.git
cd pi5-setup/pi5-storage-stack/scripts

# Lancer l'installation
sudo ./01-filebrowser-deploy.sh
```

---

## Installation Manuelle Détaillée

### Étape 1 : Préparation des Répertoires

```bash
# Créer répertoires
sudo mkdir -p /home/pi/stacks/filebrowser
sudo mkdir -p /home/pi/storage/{uploads,documents,media,archives,shared}

# Permissions
sudo chown -R pi:pi /home/pi/storage
sudo chmod 755 /home/pi/storage
```

### Étape 2 : Configuration Variables d'Environnement

```bash
# Définir variables d'environnement
export STORAGE_DIR=/home/pi/storage
export FILEBROWSER_ADMIN_USER=admin
export FILEBROWSER_ADMIN_PASS=$(openssl rand -base64 20)

# Sauvegarder credentials
echo "Admin: $FILEBROWSER_ADMIN_USER" > /home/pi/stacks/filebrowser/credentials.txt
echo "Password: $FILEBROWSER_ADMIN_PASS" >> /home/pi/stacks/filebrowser/credentials.txt
chmod 600 /home/pi/stacks/filebrowser/credentials.txt
```

### Étape 3 : Docker Compose (Scénario sans Traefik)

```bash
cat > /home/pi/stacks/filebrowser/docker-compose.yml <<'EOF'
version: '3.8'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser-app
    restart: unless-stopped
    ports:
      - "8080:80"
    volumes:
      - /home/pi/storage:/srv
      - ./filebrowser.db:/database.db
      - ./filebrowser.json:/.filebrowser.json
    environment:
      - FB_DATABASE=/database.db
      - FB_CONFIG=/.filebrowser.json
EOF
```

### Étape 4 : Configuration FileBrowser

```bash
cat > /home/pi/stacks/filebrowser/filebrowser.json <<'EOF'
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database.db",
  "root": "/srv",
  "locale": "fr",
  "signup": false,
  "createUserDir": true,
  "defaults": {
    "scope": "/srv",
    "locale": "fr",
    "perm": {
      "admin": false,
      "execute": true,
      "create": true,
      "rename": true,
      "modify": true,
      "delete": true,
      "share": true,
      "download": true
    }
  }
}
EOF
```

### Étape 5 : Démarrage du Service

```bash
cd /home/pi/stacks/filebrowser
docker compose up -d

# Attendre démarrage
sleep 5
```

### Étape 6 : Créer Utilisateur Admin

```bash
# Créer admin
docker exec filebrowser-app \
  filebrowser users add \
  "$FILEBROWSER_ADMIN_USER" \
  "$FILEBROWSER_ADMIN_PASS" \
  --perm.admin

# Vérifier
docker exec filebrowser-app filebrowser users ls
```

---

## Intégration Traefik

### Scénario 1 : DuckDNS (Path-based)

Ajouter les labels Traefik au fichier `docker-compose.yml` :

```yaml
version: '3.8'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - /home/pi/storage:/srv
      - ./filebrowser.db:/database.db
      - ./filebrowser.json:/.filebrowser.json
    environment:
      - FB_DATABASE=/database.db
      - FB_CONFIG=/.filebrowser.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=PathPrefix(`/files`)"
      - "traefik.http.routers.filebrowser.entrypoints=websecure"
      - "traefik.http.routers.filebrowser.tls.certresolver=letsencrypt"
      - "traefik.http.middlewares.filebrowser-stripprefix.stripprefix.prefixes=/files"
      - "traefik.http.routers.filebrowser.middlewares=filebrowser-stripprefix"

networks:
  traefik-network:
    external: true
```

**Accès** : `https://votresubdomain.duckdns.org/files`

### Scénario 2 : Cloudflare (Subdomain)

```yaml
version: '3.8'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - /home/pi/storage:/srv
      - ./filebrowser.db:/database.db
      - ./filebrowser.json:/.filebrowser.json
    environment:
      - FB_DATABASE=/database.db
      - FB_CONFIG=/.filebrowser.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host(`files.votredomaine.com`)"
      - "traefik.http.routers.filebrowser.entrypoints=websecure"
      - "traefik.http.routers.filebrowser.tls.certresolver=cloudflare"

networks:
  traefik-network:
    external: true
```

**Accès** : `https://files.votredomaine.com`

### Scénario 3 : VPN/Local

```yaml
version: '3.8'

services:
  filebrowser:
    image: filebrowser/filebrowser:latest
    container_name: filebrowser-app
    restart: unless-stopped
    networks:
      - traefik-network
    volumes:
      - /home/pi/storage:/srv
      - ./filebrowser.db:/database.db
      - ./filebrowser.json:/.filebrowser.json
    environment:
      - FB_DATABASE=/database.db
      - FB_CONFIG=/.filebrowser.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.filebrowser.rule=Host(`files.pi.local`)"
      - "traefik.http.routers.filebrowser.entrypoints=web"

networks:
  traefik-network:
    external: true
```

**Accès** : `http://files.pi.local` (via Tailscale/VPN)

---

## Intégration Homepage

### Ajouter le Widget FileBrowser

```bash
# Ajouter widget FileBrowser à Homepage
cat >> /home/pi/stacks/homepage/config/services.yaml <<'EOF'
- Stockage:
    - FileBrowser:
        icon: filebrowser
        href: https://votresubdomain.duckdns.org/files
        description: Gestionnaire de fichiers
        widget:
          type: filebrowser
          url: http://filebrowser-app:80
EOF

# Redémarrer Homepage
cd /home/pi/stacks/homepage
docker compose restart
```

---

## Configuration Avancée

### Personnalisation de l'Interface

Éditer le fichier `filebrowser.json` pour personnaliser l'interface :

```json
{
  "port": 80,
  "baseURL": "",
  "address": "",
  "log": "stdout",
  "database": "/database.db",
  "root": "/srv",
  "locale": "fr",
  "signup": false,
  "createUserDir": true,
  "branding": {
    "name": "Mon Cloud Pi5",
    "disableExternal": true,
    "files": "/srv"
  },
  "commands": [],
  "shell": ["/bin/sh"],
  "defaults": {
    "scope": "/srv",
    "locale": "fr",
    "perm": {
      "admin": false,
      "execute": true,
      "create": true,
      "rename": true,
      "modify": true,
      "delete": true,
      "share": true,
      "download": true
    }
  }
}
```

### Limites d'Upload

Configurer les limites d'upload dans `filebrowser.json` :

```json
{
  "defaults": {
    "perm": {
      "create": true,
      "modify": true
    }
  },
  "tus": {
    "chunkSize": 10485760
  }
}
```

### Authentification LDAP (Avancé)

```bash
# Installer plugin LDAP
docker exec filebrowser-app filebrowser config set --auth.method=ldap
docker exec filebrowser-app filebrowser config set --auth.ldap.host=ldap://ldap.pi.local
```

---

## Gestion Utilisateurs

### Créer des Utilisateurs

```bash
# Utilisateur avec permissions complètes
docker exec filebrowser-app filebrowser users add alice motdepasse123 --perm.admin=false

# Utilisateur lecture seule
docker exec filebrowser-app filebrowser users add bob motdepasse456 \
  --perm.create=false \
  --perm.modify=false \
  --perm.delete=false

# Lister utilisateurs
docker exec filebrowser-app filebrowser users ls
```

### Modifier les Permissions

```bash
# Donner droits admin
docker exec filebrowser-app filebrowser users update alice --perm.admin=true

# Retirer droits suppression
docker exec filebrowser-app filebrowser users update bob --perm.delete=false
```

### Supprimer un Utilisateur

```bash
docker exec filebrowser-app filebrowser users rm bob
```

---

## Premier Démarrage

### 1. Accéder à l'Interface

- **Sans Traefik** : `http://IP_PI:8080`
- **Avec Traefik** : Voir URL dans summary script

### 2. Se Connecter

```
Utilisateur : admin (ou votre FILEBROWSER_ADMIN_USER)
Mot de passe : Voir /home/pi/stacks/filebrowser/credentials.txt
```

### 3. Changer le Mot de Passe

- Settings (⚙️) → User Management → Edit Admin
- Change Password

### 4. Personnaliser

- Settings → Global Settings → Branding
- Changer nom, couleurs, logo

### 5. Créer des Utilisateurs

- Settings → User Management → New User

---

## Utilisation Quotidienne

### Upload de Fichiers

- Drag & Drop depuis explorateur
- Bouton Upload → Select Files
- Support multi-fichiers

### Partage de Fichiers

- Clic droit sur fichier → Share
- Générer lien de partage (avec expiration optionnelle)
- Copier lien et envoyer

### Recherche

- Barre de recherche en haut
- Recherche par nom, extension, date

### Prévisualisation

- Clic sur fichier pour aperçu
- Support : images, vidéos, PDFs, texte

---

## Maintenance

### Backup Configuration

```bash
# Backup complet
tar czf filebrowser-backup-$(date +%Y%m%d).tar.gz \
  /home/pi/stacks/filebrowser \
  /home/pi/storage

# Backup DB seulement
cp /home/pi/stacks/filebrowser/filebrowser.db \
   /home/pi/backups/filebrowser-db-$(date +%Y%m%d).db
```

### Restauration

```bash
# Arrêter service
cd /home/pi/stacks/filebrowser
docker compose down

# Restaurer backup
tar xzf filebrowser-backup-20251004.tar.gz -C /

# Redémarrer
docker compose up -d
```

### Mise à Jour

```bash
cd /home/pi/stacks/filebrowser

# Pull nouvelle image
docker compose pull

# Redémarrer avec nouvelle version
docker compose up -d

# Vérifier version
docker exec filebrowser-app filebrowser version
```

### Logs

```bash
# Voir logs en direct
docker compose logs -f

# Logs des 100 dernières lignes
docker compose logs --tail=100

# Logs d'une date
docker compose logs --since 2025-01-04T10:00:00
```

---

## Troubleshooting

### Problème : Port 8080 déjà utilisé

```bash
# Changer port dans docker-compose.yml
ports:
  - "8081:80"  # Au lieu de 8080

docker compose up -d
```

### Problème : Permissions Denied

```bash
# Corriger permissions storage
sudo chown -R pi:pi /home/pi/storage
sudo chmod -R 755 /home/pi/storage

# Redémarrer
docker compose restart
```

### Problème : Can't Login

```bash
# Reset mot de passe admin
docker exec filebrowser-app filebrowser users update admin --password=NouveauPass123
```

### Problème : Upload Échoue

```bash
# Vérifier espace disque
df -h /home/pi

# Augmenter limite upload (filebrowser.json)
{
  "tus": {
    "chunkSize": 52428800  // 50 MB chunks
  }
}

docker compose restart
```

### Problème : FileBrowser ne démarre pas

```bash
# Vérifier logs
docker logs filebrowser-app

# Vérifier config JSON
cat /home/pi/stacks/filebrowser/filebrowser.json | jq .

# Réinitialiser
docker compose down
rm /home/pi/stacks/filebrowser/filebrowser.db
docker compose up -d
```

---

## Désinstallation

### Désinstallation Complète

```bash
# Arrêter et supprimer conteneurs
cd /home/pi/stacks/filebrowser
docker compose down -v

# Supprimer stack (ATTENTION : perte config)
rm -rf /home/pi/stacks/filebrowser

# Garder fichiers utilisateur
# /home/pi/storage reste intact
```

### Désinstallation avec Suppression Données

```bash
# ATTENTION : Supprime TOUT y compris fichiers utilisateur
docker compose down -v
rm -rf /home/pi/stacks/filebrowser
rm -rf /home/pi/storage  # ⚠️ Perte définitive fichiers

# Retirer widget Homepage (si configuré)
# Éditer manuellement /home/pi/stacks/homepage/config/services.yaml
```

---

## Ressources Supplémentaires

- **Documentation officielle** : https://filebrowser.org/
- **Common Scripts** : [Backup automatique](../../common-scripts/README.md)
- **Homepage** : [Intégration dashboard](../../pi5-homepage-stack/README.md)
- **Traefik** : [Configuration HTTPS](../../pi5-traefik-stack/README.md)

---

<p align="center">
  <strong>📁 FileBrowser déployé avec succès sur votre Pi5 ! 📁</strong>
</p>

<p align="center">
  <sub>Léger • Rapide • Self-hosted • Privacy-first</sub>
</p>
