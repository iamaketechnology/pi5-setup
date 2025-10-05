# 📦 Stockage Cloud Personnel sur Raspberry Pi 5

> **Solutions self-hosted pour gérer vos fichiers : FileBrowser ou Nextcloud**

---

## 📋 Vue d'Ensemble

Ce stack propose **deux solutions** pour héberger votre propre cloud personnel sur Raspberry Pi 5 : **FileBrowser** (léger et simple) ou **Nextcloud** (complet et puissant).

### 🎯 Pourquoi Héberger Son Propre Cloud ?

- **🔒 Privacy First** - Vos données restent chez vous, pas sur les serveurs Google/Dropbox
- **💰 Économies** - Pas d'abonnement mensuel (Google Drive 2TB = 10€/mois = 120€/an)
- **♾️ Stockage Illimité** - Limité seulement par votre disque dur
- **🚀 Contrôle Total** - Vous décidez qui accède à quoi
- **🌐 Accessible Partout** - Via web, apps mobiles, ou sync desktop

### 📊 Deux Options Disponibles

Ce stack offre le choix entre deux solutions selon vos besoins :

| Critère | 📁 FileBrowser | ☁️ Nextcloud |
|---------|----------------|--------------|
| **RAM utilisée** | ~50 MB | ~500 MB |
| **Temps d'installation** | ~1h | ~2h |
| **Complexité** | Simple | Avancée |
| **Fonctionnalités** | Gestion fichiers de base | Suite bureautique complète |
| **Apps mobiles** | ❌ (web uniquement) | ✅ iOS + Android natifs |
| **Calendrier/Contacts** | ❌ | ✅ |
| **Office en ligne** | ❌ | ✅ (Collabora/OnlyOffice) |
| **Sync desktop** | ❌ | ✅ (client natif) |
| **Multi-utilisateurs** | ✅ (basique) | ✅ (avancé avec groupes) |
| **Chiffrement** | ❌ | ✅ (E2E disponible) |
| **Recommandé pour** | Partage fichiers simple | Suite collaborative complète |

---

## 🤔 Quand Choisir Quoi ?

### 📁 Choisir FileBrowser si...

- ✅ Vous voulez juste **partager des fichiers** simplement
- ✅ Vous cherchez une solution **ultra-légère** (50 MB RAM)
- ✅ Vous avez **peu de RAM disponible** sur votre Pi
- ✅ **Installation rapide** et simple est prioritaire (~1h)
- ✅ Vous accédez principalement **depuis le web**
- ✅ Vous n'avez **pas besoin** de calendrier/contacts/office

**Cas d'usage FileBrowser** :
- 📂 Partager des fichiers avec famille/amis
- 💾 Accéder à vos backups depuis le web
- 📸 Uploader photos/vidéos depuis mobile (web browser)
- 🎬 Streamer vos médias (lecture directe navigateur)
- 📦 Gérer archives/téléchargements

### ☁️ Choisir Nextcloud si...

- ✅ Vous voulez **remplacer Google Drive/Dropbox** complètement
- ✅ Vous avez besoin de **calendrier/contacts** synchronisés
- ✅ Vous voulez **éditer documents en ligne** (Word, Excel, etc.)
- ✅ **Apps mobiles natives** sont importantes pour vous
- ✅ **Sync automatique desktop** est nécessaire (dossiers Documents, Photos, etc.)
- ✅ Vous avez **assez de RAM** (~500 MB requis)
- ✅ Vous voulez une **suite collaborative** (partage, édition simultanée)

**Cas d'usage Nextcloud** :
- 🏢 Remplacer Google Workspace/Microsoft 365
- 👨‍👩‍👧 Cloud familial (calendrier partagé, contacts, photos)
- 📚 Collaboration documents (édition simultanée à plusieurs)
- 📱 Sync photos mobiles automatique (comme Google Photos)
- 🔄 Sync dossiers importants (Desktop/Documents auto-sync)
- 📧 Gérer emails (client mail intégré)
- 💬 Chat/Visio (apps Talk/Spreed disponibles)

---

## 🏗️ Architecture Technique

```
📦 Stack Stockage Cloud Personnel
│
├── 📁 Option 1 : FileBrowser (Léger)
│   │
│   ├── Services Docker
│   │   └── filebrowser/filebrowser:latest (50 MB RAM)
│   │
│   ├── Volumes
│   │   ├── /home/pi/storage → /srv (fichiers utilisateur)
│   │   └── ./filebrowser.db (base SQLite)
│   │
│   └── Ports
│       └── 8080:80 (interface web)
│
└── ☁️ Option 2 : Nextcloud (Complet)
    │
    ├── Services Docker
    │   ├── nextcloud:latest (~200 MB RAM)
    │   ├── postgres:15-alpine (~200 MB RAM)
    │   └── redis:7-alpine (~100 MB RAM)
    │
    ├── Volumes
    │   ├── /home/pi/nextcloud-data → /var/www/html/data
    │   ├── ./html → /var/www/html (apps Nextcloud)
    │   └── ./db → /var/lib/postgresql/data
    │
    └── Ports
        ├── 8081:80 (Nextcloud web)
        ├── 5432 (PostgreSQL interne)
        └── 6379 (Redis interne)
```

---

## 🔗 Intégration avec Pi5-Setup

### Détection Traefik Automatique

Les scripts détectent **automatiquement** votre configuration Traefik existante et configurent les URLs en conséquence :

#### Scénario 1 : DuckDNS (Path-based)
```
✅ Traefik avec DuckDNS détecté
→ FileBrowser : https://votresubdomain.duckdns.org/files
→ Nextcloud  : https://votresubdomain.duckdns.org/cloud
```

#### Scénario 2 : Cloudflare (Subdomain)
```
✅ Traefik avec Cloudflare détecté
→ FileBrowser : https://files.votredomaine.com
→ Nextcloud  : https://cloud.votredomaine.com
```

#### Scénario 3 : VPN/Local (Tailscale)
```
✅ Traefik en mode VPN détecté
→ FileBrowser : https://files.pi.local
→ Nextcloud  : https://cloud.pi.local
```

#### Scénario 4 : Sans Traefik
```
⚠️  Traefik non détecté (accès direct)
→ FileBrowser : http://IP_PI:8080
→ Nextcloud  : http://IP_PI:8081
```

### Intégration Homepage Dashboard

Si Homepage est installé, un **widget est automatiquement ajouté** :

**Widget FileBrowser** :
- 📊 Affichage espace disque utilisé
- 🔗 Lien direct vers l'interface
- 📁 Nombre de fichiers stockés

**Widget Nextcloud** :
- 📊 Utilisateurs actifs
- 💾 Stockage total/utilisé
- 🔗 Accès rapide calendrier/fichiers

---

## 💾 Ressources Système

### FileBrowser (Option Légère)

**Consommation** :
- **RAM** : ~50 MB (idle), ~80 MB (upload actif)
- **CPU** : <5% (idle), 10-15% (upload 100 Mbps)
- **Stockage** : 20 MB (binaire) + vos fichiers
- **Ports** : 8080

**Impact serveur Pi5 total** (après Phase 7 avec FileBrowser) :
```
Supabase        : ~1.2 GB
Traefik         : ~50 MB
Homepage        : ~30 MB
Monitoring      : ~800 MB
Gitea           : ~300 MB
VPN (Tailscale) : ~50 MB
FileBrowser     : ~50 MB
─────────────────────────
Total           : ~2.5 GB / 16 GB (15.6%)
Disponible      : ~13.5 GB pour apps utilisateur ✅
```

### Nextcloud (Option Complète)

**Consommation** :
- **RAM** : ~500 MB (Nextcloud 200 + PostgreSQL 200 + Redis 100)
- **CPU** : 5-10% (idle), 20-30% (sync actif)
- **Stockage** : 500 MB (apps) + vos fichiers
- **Ports** : 8081 (Nextcloud), 5432 (PostgreSQL), 6379 (Redis)

**Impact serveur Pi5 total** (après Phase 7 avec Nextcloud) :
```
Supabase        : ~1.2 GB
Traefik         : ~50 MB
Homepage        : ~30 MB
Monitoring      : ~800 MB
Gitea           : ~300 MB
VPN (Tailscale) : ~50 MB
Nextcloud       : ~500 MB
─────────────────────────
Total           : ~2.9 GB / 16 GB (18.1%)
Disponible      : ~13.1 GB pour apps utilisateur ✅
```

**Les deux options laissent largement assez de RAM pour les phases suivantes** (Media Server, Auth) 🎉

---

## 🚀 Installation Rapide

### Option 1 : FileBrowser (Recommandé pour Débuter)

#### Curl One-Liner (Installation Automatique)
```bash
curl -fsSL https://raw.githubusercontent.com/phrogg/pi5-setup/main/pi5-storage-stack/scripts/01-filebrowser-deploy.sh | sudo bash
```

#### Installation Manuelle
```bash
# Cloner le repo (si pas déjà fait)
cd ~
git clone https://github.com/phrogg/pi5-setup.git

# Lancer l'installation
cd pi5-setup/pi5-storage-stack/scripts
sudo ./01-filebrowser-deploy.sh
```

**Ce qui est installé** :
- ✅ FileBrowser en Docker
- ✅ Détection et intégration Traefik (si présent)
- ✅ Configuration HTTPS automatique
- ✅ Création utilisateur admin avec mot de passe sécurisé
- ✅ Widget Homepage (si présent)
- ✅ Répertoire de stockage `/home/pi/storage` organisé

**Temps d'installation** : ~10 minutes

### Option 2 : Nextcloud (Suite Complète)

#### Curl One-Liner (Installation Automatique)
```bash
curl -fsSL https://raw.githubusercontent.com/phrogg/pi5-setup/main/pi5-storage-stack/scripts/02-nextcloud-deploy.sh | sudo bash
```

#### Installation Manuelle
```bash
# Depuis le repo cloné
cd ~/pi5-setup/pi5-storage-stack/scripts
sudo ./02-nextcloud-deploy.sh
```

**Ce qui est installé** :
- ✅ Nextcloud + PostgreSQL + Redis (stack complet)
- ✅ Détection et intégration Traefik
- ✅ Configuration HTTPS automatique
- ✅ Optimisations performance Pi5 (cache Redis, APCu, opcache)
- ✅ Apps recommandées (Calendar, Contacts, Tasks, Notes)
- ✅ Utilisateur admin avec mot de passe sécurisé
- ✅ Widget Homepage

**Temps d'installation** : ~20 minutes (pull images + init PostgreSQL)

---

## 📚 Scripts Disponibles

| Script | Description | Utilisation | Durée |
|--------|-------------|-------------|-------|
| **01-filebrowser-deploy.sh** | Déploie FileBrowser (léger) | `sudo ./scripts/01-filebrowser-deploy.sh` | ~10 min |
| **02-nextcloud-deploy.sh** | Déploie Nextcloud complet | `sudo ./scripts/02-nextcloud-deploy.sh` | ~20 min |

### Options Communes

Tous les scripts supportent :
```bash
# Mode dry-run (simulation)
sudo ./01-filebrowser-deploy.sh --dry-run

# Mode verbose (logs détaillés)
sudo ./02-nextcloud-deploy.sh --verbose

# Mode non-interactif (CI/CD)
sudo ./01-filebrowser-deploy.sh --yes
```

---

## ✨ Fonctionnalités Clés

### 📁 FileBrowser

**Interface Web** :
- 📤 Upload/Download par **drag & drop**
- 🔍 **Recherche** de fichiers (nom, extension, date)
- 👁️ **Prévisualisation** images, vidéos, PDFs, texte
- 📋 **Gestion fichiers** : copier, déplacer, renommer, supprimer
- 🗂️ **Organisation** : créer dossiers, trier, filtrer
- 📱 **Interface responsive** (mobile-friendly)

**Utilisateurs** :
- 👥 **Multi-utilisateurs** (chacun son compte)
- 🔐 **Authentification** intégrée (user/password)
- 🔒 **Permissions granulaires** par utilisateur :
  - Lecture/Écriture/Suppression
  - Partage/Téléchargement
  - Upload/Modification

**Partage** :
- 🔗 **Liens de partage** (avec expiration optionnelle)
- 📧 Envoyer lien par email/chat
- 🔒 Protéger par mot de passe (optionnel)

### ☁️ Nextcloud

**Toutes les fonctionnalités FileBrowser PLUS** :

**Stockage & Sync** :
- 🔄 **Sync automatique** desktop (Windows/macOS/Linux)
- 📱 **Apps mobiles natives** (iOS + Android)
- 📸 **Upload photos automatique** depuis mobile
- 🗂️ **Versioning fichiers** (historique modifications)
- 🗑️ **Corbeille** (récupération fichiers supprimés)

**Collaboration** :
- 📝 **Édition documents en ligne** (Collabora/OnlyOffice)
  - Word, Excel, PowerPoint compatibles
  - Édition simultanée à plusieurs
- 💬 **Commentaires** sur fichiers
- 🔔 **Notifications** (activité, partages, mentions)

**Productivité** :
- 📅 **Calendrier** (CalDAV) - sync avec iOS/Android/Thunderbird
- 👤 **Contacts** (CardDAV) - sync avec tous vos appareils
- ✅ **Tâches** (listes TODO synchronisées)
- 📝 **Notes** (Markdown, sync multi-appareils)
- 📧 **Mail** (client intégré optionnel)

**Sécurité** :
- 🔐 **Authentification 2FA** (TOTP - Google Authenticator)
- 🔒 **Chiffrement côté serveur** (données au repos)
- 🔑 **Chiffrement E2E** (end-to-end, optionnel)
- 📊 **Audit logs** complets
- 🚨 **Détection activité suspecte**
- 🛡️ **Bruteforce protection**

**Apps & Extensions** :
- 📦 **+300 apps disponibles** dans l'App Store Nextcloud
- 📊 **Galerie photos** (avec reconnaissance faciale)
- 🎵 **Lecteur musique** (streaming)
- 🎬 **Lecteur vidéo** intégré
- 📚 **Lecteur ebooks**
- 💬 **Nextcloud Talk** (chat vidéo/audio)
- 📋 **Forms** (créer formulaires)
- 🗺️ **Maps** (geolocalisation photos)

---

## 🔧 Maintenance

### FileBrowser

#### Logs
```bash
# Logs en direct
docker compose -f /home/pi/stacks/filebrowser/docker-compose.yml logs -f

# Dernières 100 lignes
docker compose -f /home/pi/stacks/filebrowser/docker-compose.yml logs --tail=100
```

#### Backup
```bash
# Backup configuration + fichiers
tar czf filebrowser-backup-$(date +%Y%m%d).tar.gz \
  /home/pi/stacks/filebrowser \
  /home/pi/storage

# Backup DB seule
cp /home/pi/stacks/filebrowser/filebrowser.db \
   ~/backups/filebrowser-db-$(date +%Y%m%d).db
```

#### Restauration
```bash
# Arrêter service
cd /home/pi/stacks/filebrowser
docker compose down

# Restaurer backup
tar xzf filebrowser-backup-20251004.tar.gz -C /

# Redémarrer
docker compose up -d
```

#### Mise à Jour
```bash
cd /home/pi/stacks/filebrowser

# Pull nouvelle image
docker compose pull

# Redémarrer avec nouvelle version
docker compose up -d

# Vérifier version
docker exec filebrowser-app filebrowser version
```

### Nextcloud

#### Commandes OCC (Nextcloud CLI)
```bash
# Status général
docker exec -u www-data nextcloud-app php occ status

# Lister apps installées
docker exec -u www-data nextcloud-app php occ app:list

# Mode maintenance
docker exec -u www-data nextcloud-app php occ maintenance:mode --on
docker exec -u www-data nextcloud-app php occ maintenance:mode --off

# Scan nouveaux fichiers
docker exec -u www-data nextcloud-app php occ files:scan --all
```

#### Backup PostgreSQL
```bash
# Dump base de données
docker exec nextcloud-db pg_dump -U nextcloud nextcloud > \
  ~/backups/nextcloud-db-$(date +%Y%m%d).sql

# Backup données utilisateur
tar czf nextcloud-data-$(date +%Y%m%d).tar.gz /home/pi/nextcloud-data

# Backup config Nextcloud
tar czf nextcloud-config-$(date +%Y%m%d).tar.gz /home/pi/stacks/nextcloud
```

#### Restauration Nextcloud
```bash
# Arrêter services
cd /home/pi/stacks/nextcloud
docker compose down

# Restaurer BDD
cat nextcloud-db-20251004.sql | docker exec -i nextcloud-db \
  psql -U nextcloud nextcloud

# Restaurer données
tar xzf nextcloud-data-20251004.tar.gz -C /

# Redémarrer
docker compose up -d
```

#### Mise à Jour Nextcloud
```bash
cd /home/pi/stacks/nextcloud

# Mode maintenance ON
docker exec -u www-data nextcloud-app php occ maintenance:mode --on

# Pull nouvelle image
docker compose pull nextcloud

# Redémarrer
docker compose up -d

# Upgrade (automatique au démarrage)
docker exec -u www-data nextcloud-app php occ upgrade

# Mode maintenance OFF
docker exec -u www-data nextcloud-app php occ maintenance:mode --off
```

#### Installer Apps Nextcloud
```bash
# Installer app depuis l'App Store
docker exec -u www-data nextcloud-app php occ app:install calendar
docker exec -u www-data nextcloud-app php occ app:install contacts
docker exec -u www-data nextcloud-app php occ app:install tasks
docker exec -u www-data nextcloud-app php occ app:install notes

# Activer app déjà téléchargée
docker exec -u www-data nextcloud-app php occ app:enable calendar
```

---

## 🆘 Troubleshooting Rapide

### FileBrowser

#### Problème : Port 8080 déjà utilisé
```bash
# Solution 1 : Changer port dans docker-compose.yml
nano /home/pi/stacks/filebrowser/docker-compose.yml
# Modifier : ports: - "8081:80"

docker compose up -d
```

#### Problème : Permissions Denied
```bash
# Corriger permissions répertoire stockage
sudo chown -R pi:pi /home/pi/storage
sudo chmod -R 755 /home/pi/storage

# Redémarrer FileBrowser
docker compose -f /home/pi/stacks/filebrowser/docker-compose.yml restart
```

#### Problème : Can't Login
```bash
# Reset mot de passe admin
docker exec filebrowser-app filebrowser users update admin --password=NouveauPass123

# Vérifier utilisateurs
docker exec filebrowser-app filebrowser users ls
```

### Nextcloud

#### Problème : "Trusted Domain" Error
```bash
# Ajouter domaine de confiance
docker exec -u www-data nextcloud-app php occ config:system:set \
  trusted_domains 1 --value=cloud.votredomaine.com

# Voir domaines actuels
docker exec -u www-data nextcloud-app php occ config:system:get trusted_domains
```

#### Problème : Connexion PostgreSQL Failed
```bash
# Vérifier PostgreSQL
docker exec nextcloud-db psql -U nextcloud -c "SELECT version();"

# Vérifier mot de passe dans .env
cat /home/pi/stacks/nextcloud/.env | grep POSTGRES_PASSWORD

# Redémarrer BDD
docker compose -f /home/pi/stacks/nextcloud/docker-compose.yml restart db
```

#### Problème : Redis Connection Error
```bash
# Vérifier Redis
docker exec nextcloud-redis redis-cli ping
# Doit retourner : PONG

# Redémarrer Redis
docker compose -f /home/pi/stacks/nextcloud/docker-compose.yml restart redis
```

#### Problème : Nextcloud Bloqué en Maintenance Mode
```bash
# Forcer sortie maintenance
docker exec -u www-data nextcloud-app php occ maintenance:mode --off

# Vérifier status
docker exec -u www-data nextcloud-app php occ status
```

---

## 📖 Documentation Complète

### Guides d'Installation

- **[📁 Installation FileBrowser](docs/INSTALL.md)** - Guide complet FileBrowser (étape par étape)
- **[☁️ Installation Nextcloud](docs/INSTALL-NEXTCLOUD.md)** - Guide complet Nextcloud (étape par étape)
- **[🎓 Guide Débutant](docs/GUIDE-DEBUTANT.md)** - Explications pédagogiques pour débutants

### Autres Stacks

- **[Common Scripts](../common-scripts/README.md)** - Scripts réutilisables (backup, monitoring, etc.)
- **[Homepage Dashboard](../pi5-homepage-stack/README.md)** - Dashboard centralisé
- **[Traefik Reverse Proxy](../pi5-traefik-stack/README.md)** - HTTPS automatique
- **[Monitoring Stack](../pi5-monitoring-stack/README.md)** - Prometheus + Grafana

---

## 🔐 Sécurité & Privacy

### FileBrowser

**Sécurité de base** :
- 🔐 Authentification par user/password
- 🔒 HTTPS via Traefik (chiffrement TLS)
- 👥 Permissions granulaires par utilisateur
- 📝 Sessions sécurisées (cookies httpOnly)

**Recommandations** :
- Utiliser mots de passe forts (20+ caractères)
- Limiter accès réseau (firewall UFW)
- Backups réguliers de la config

### Nextcloud

**Sécurité avancée** :
- 🔐 **2FA/MFA** : Authentification deux facteurs (TOTP)
- 🔒 **Chiffrement serveur** : Données chiffrées au repos
- 🔑 **Chiffrement E2E** : End-to-end pour dossiers sensibles
- 📊 **Audit complet** : Logs de toutes les actions
- 🚨 **Détection intrusion** : Bruteforce protection + blocage IP
- 🛡️ **Headers sécurité** : HSTS, CSP, X-Frame-Options

**Compliance** :
- ✅ RGPD compliant (données en Europe, chez vous)
- ✅ ISO 27001 practices
- ✅ Hébergement souverain (France/Europe)

---

## 🚀 Prochaines Étapes

### Après Installation FileBrowser

1. **✅ Première connexion** :
   ```bash
   # Récupérer credentials
   cat /home/pi/stacks/filebrowser/credentials.txt
   # Accéder via URL affichée (HTTPS)
   ```

2. **✅ Changer mot de passe admin** :
   - Settings ⚙️ → User Management → Edit Admin
   - Change Password → Nouveau mot de passe fort

3. **✅ Créer utilisateurs** :
   - Settings → User Management → New User
   - Définir permissions (lecture/écriture/suppression)

4. **✅ Personnaliser interface** :
   - Settings → Global Settings → Branding
   - Changer nom, couleurs, logo

5. **✅ Tester upload** :
   - Drag & drop fichier depuis PC
   - Vérifier dans `/home/pi/storage`

### Après Installation Nextcloud

1. **✅ Première connexion** :
   ```bash
   # Récupérer credentials
   cat /home/pi/stacks/nextcloud/.env | grep ADMIN
   # Accéder via URL affichée
   ```

2. **✅ Installer apps recommandées** :
   ```bash
   docker exec -u www-data nextcloud-app php occ app:install calendar
   docker exec -u www-data nextcloud-app php occ app:install contacts
   docker exec -u www-data nextcloud-app php occ app:install tasks
   docker exec -u www-data nextcloud-app php occ app:install notes
   docker exec -u www-data nextcloud-app php occ app:install files_external
   ```

3. **✅ Configurer apps mobiles** :
   - **iOS** : https://apps.apple.com/app/nextcloud/id1125420102
   - **Android** : https://play.google.com/store/apps/details?id=com.nextcloud.client
   - Se connecter avec URL + credentials

4. **✅ Activer 2FA (sécurité)** :
   - Settings → Security → Two-Factor Authentication
   - Scanner QR code avec Google Authenticator/Authy

5. **✅ Configurer sync desktop** :
   - Télécharger client : https://nextcloud.com/install/#install-clients
   - Configurer dossiers à synchroniser

6. **✅ Personnaliser** :
   - Settings → Theming → Couleurs, logo, nom
   - Settings → Administration → Background jobs (Cron)

### Automatiser Backups

```bash
# Utiliser common-scripts pour backups automatiques
sudo ~/pi5-setup/common-scripts/04-backup-rotate.sh \
  --prefix filebrowser \
  --paths /home/pi/stacks/filebrowser,/home/pi/storage

# Programmer backup quotidien (cron)
crontab -e
# Ajouter :
0 3 * * * /home/pi/pi5-setup/common-scripts/04-backup-rotate.sh --yes --prefix filebrowser
```

---

## 📊 Comparaison avec Solutions Cloud

### FileBrowser vs Google Drive

| Caractéristique | FileBrowser (Self-hosted) | Google Drive |
|-----------------|---------------------------|--------------|
| **Coût** | Gratuit (hardware uniquement) | 10€/mois (2TB) = 120€/an |
| **Stockage** | Illimité (selon disque) | 2 TB max (payant) |
| **Privacy** | 100% privé (chez vous) | Données scannées par Google |
| **Apps mobiles** | Web uniquement | Apps natives iOS/Android |
| **Sync desktop** | ❌ | ✅ |
| **Partage** | ✅ (par lien) | ✅ (par lien + permissions) |

**Économies sur 5 ans** : ~600€ (avec Google Drive 2TB)

### Nextcloud vs Dropbox + Office 365

| Caractéristique | Nextcloud (Self-hosted) | Dropbox + Office 365 |
|-----------------|-------------------------|----------------------|
| **Coût** | Gratuit (hardware) | 20€/mois = 240€/an |
| **Stockage** | Illimité (selon disque) | 2 TB Dropbox + 1 TB OneDrive |
| **Privacy** | 100% privé (chez vous) | Données US (Dropbox) + MS |
| **Office en ligne** | ✅ (Collabora/OnlyOffice) | ✅ (Office 365) |
| **Apps mobiles** | ✅ (natives) | ✅ (natives) |
| **Calendrier/Contacts** | ✅ (CalDAV/CardDAV) | ✅ (Exchange) |
| **Email** | ✅ (optionnel) | ✅ (Exchange) |

**Économies sur 5 ans** : ~1200€ (avec Dropbox Business + Office 365)

---

## 🌟 Fonctionnalités Avancées (Nextcloud)

### Collabora Online (Office en Ligne)

```bash
# Installer Collabora (édition Word/Excel/PowerPoint)
docker exec -u www-data nextcloud-app php occ app:install richdocuments

# Ou OnlyOffice (alternative)
docker exec -u www-data nextcloud-app php occ app:install onlyoffice
```

### Sync Photos Mobile Automatique

1. Installer app Nextcloud mobile (iOS/Android)
2. Settings → Auto Upload
3. Sélectionner dossier Nextcloud (ex: `/Photos`)
4. Photos uploadées automatiquement

### Partage Sécurisé avec Expiration

```bash
# Via interface web :
# Clic droit sur fichier → Share → Set expiration date
# Ou par CLI :
docker exec -u www-data nextcloud-app php occ sharing:expiration --days=7
```

### Galerie Photos avec AI

```bash
# Installer Recognize (reconnaissance faciale/objets)
docker exec -u www-data nextcloud-app php occ app:install recognize

# Installer Memories (galerie moderne type Google Photos)
docker exec -u www-data nextcloud-app php occ app:install memories
```

---

## 🔗 Liens Utiles

### FileBrowser
- **Site officiel** : https://filebrowser.org/
- **Documentation** : https://filebrowser.org/configuration
- **GitHub** : https://github.com/filebrowser/filebrowser

### Nextcloud
- **Site officiel** : https://nextcloud.com/
- **Documentation** : https://docs.nextcloud.com/
- **App Store** : https://apps.nextcloud.com/
- **Apps mobiles** :
  - iOS : https://apps.apple.com/app/nextcloud/id1125420102
  - Android : https://play.google.com/store/apps/details?id=com.nextcloud.client
- **Clients desktop** : https://nextcloud.com/install/#install-clients

### Pi5-Setup
- **Common Scripts** : [Backup, monitoring, etc.](../common-scripts/README.md)
- **Homepage** : [Dashboard centralisé](../pi5-homepage-stack/README.md)
- **Traefik** : [Reverse proxy HTTPS](../pi5-traefik-stack/README.md)
- **Monitoring** : [Prometheus + Grafana](../pi5-monitoring-stack/README.md)
- **VPN** : [Tailscale](../pi5-vpn-stack/README.md)
- **Git/CI** : [Gitea + Actions](../pi5-gitea-stack/README.md)

---

<p align="center">
  <strong>📦 Votre Cloud Personnel sur Raspberry Pi 5 📦</strong>
</p>

<p align="center">
  <sub>FileBrowser léger • Nextcloud complet • 100% self-hosted • Privacy-first • 0€/mois</sub>
</p>

<p align="center">
  <em>Économisez 600-1200€ sur 5 ans vs Google Drive / Dropbox + Office 365</em>
</p>
