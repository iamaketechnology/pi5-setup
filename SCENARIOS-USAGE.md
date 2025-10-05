# 🎯 Scénarios d'Usage - Configurations Prêtes à l'Emploi

> **Guide pratique** : Configurations Pi 5 optimisées par cas d'usage avec scripts dans l'ordre

---

## 📋 Table des Matières

1. [Scénario 1 : Développeur Full-Stack](#-scénario-1--développeur-full-stack)
2. [Scénario 2 : Homelab Personnel](#-scénario-2--homelab-personnel)
3. [Scénario 3 : Startup/Freelance MVP](#-scénario-3--startupfreelance-mvp)
4. [Scénario 4 : Media Server Familial](#-scénario-4--media-server-familial)
5. [Scénario 5 : Smart Home (Domotique)](#-scénario-5--smart-home-domotique)
6. [Scénario 6 : Serveur de Productivité](#-scénario-6--serveur-de-productivité)
7. [Scénario 7 : Serveur d'Apprentissage DevOps](#-scénario-7--serveur-dapprentissage-devops)
8. [Scénario 8 : Serveur Cloud Privé](#-scénario-8--serveur-cloud-privé)

---

## 🚀 Scénario 1 : Développeur Full-Stack

### 👤 Profil
- Développeur web/mobile cherchant backend gratuit
- Besoin Git privé + CI/CD
- Apps Next.js/React/Vue à héberger
- Monitoring et logs essentiels

### 🎯 Objectif
Remplacer Firebase/Supabase Cloud/Vercel/Heroku par serveur maison

### 💰 Économies
~**250€/mois** vs Firebase Pro + Vercel Pro + GitHub Teams

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Supabase** | Backend (DB + Auth + API) | 2.5 GB |
| **Traefik** | Reverse proxy HTTPS | 100 MB |
| **Gitea** | Git + CI/CD | 450 MB |
| **Prometheus/Grafana** | Monitoring | 1.1 GB |
| **Homepage** | Dashboard | 50 MB |
| **Uptime Kuma** | Monitoring uptime | 100 MB |

**Total RAM** : ~4.3 GB / 16 GB (27%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure Base (~1h)
```bash
# 1. Prérequis (Docker, sécurité, firewall)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# 2. Backend Supabase (après reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# 3. Reverse Proxy HTTPS (choisir selon besoin)
# Option A : DuckDNS (gratuit)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# Option B : Cloudflare (domaine perso)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# 4. Intégrer Supabase avec Traefik
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

#### Phase 2 : Développement (~30 min)
```bash
# 5. Git Self-Hosted + CI/CD
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
```

#### Phase 3 : Monitoring (~20 min)
```bash
# 6. Métriques + Dashboards
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# 7. Monitoring uptime
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash

# 8. Dashboard centralisé
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

#### Phase 4 : Backups (~10 min)
```bash
# 9. Backups automatiques locaux
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-scheduler.sh

# 10. Backups cloud (optionnel)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Services
```
Backend Supabase  : https://studio.monpi.duckdns.org
Git Gitea         : https://git.monpi.duckdns.org
Grafana           : https://grafana.monpi.duckdns.org
Uptime Kuma       : https://uptime.monpi.duckdns.org
Homepage          : https://home.monpi.duckdns.org
```

#### Workflow Développement
```bash
# 1. Créer projet Gitea
# 2. Push code → CI/CD auto
# 3. Build → Deploy sur Pi
# 4. Monitoring Grafana
# 5. Backups quotidiens
```

---

## 🏠 Scénario 2 : Homelab Personnel

### 👤 Profil
- Passionné tech cherchant alternatives cloud
- Contrôle total des données personnelles
- Famille (photos, docs, media)
- Budget limité

### 🎯 Objectif
Remplacer Google Photos + Drive + Netflix + Dropbox

### 💰 Économies
~**400€/mois** vs Google One + Dropbox + Netflix + Spotify

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Immich** | Photos (Google Photos alt.) | 500 MB |
| **Nextcloud** | Cloud storage + Office | 500 MB |
| **Jellyfin** | Media server | 300 MB |
| **Paperless-ngx** | Documents + OCR | 300 MB |
| **Navidrome** | Streaming musical | 100 MB |
| **Vaultwarden** | Password manager | 50 MB |
| **Traefik** | HTTPS | 100 MB |
| **Homepage** | Dashboard | 50 MB |

**Total RAM** : ~1.9 GB / 16 GB (12%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure (~30 min)
```bash
# 1. Prérequis
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. Reverse Proxy VPN (sécurité max, pas de ports ouverts)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

#### Phase 2 : Stockage & Photos (~20 min)
```bash
# 3. Google Photos alternative
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy-official.sh | sudo bash

# 4. Cloud storage
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash

# 5. Documents + OCR
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy-official.sh | sudo bash
```

#### Phase 3 : Media (~20 min)
```bash
# 6. Media server (films/séries)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash

# 7. Streaming musical
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```

#### Phase 4 : Sécurité & Interface (~10 min)
```bash
# 8. Password manager
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash

# 9. Dashboard
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Services (via Tailscale VPN)
```
Dashboard    : https://raspberrypi:3030
Photos       : https://raspberrypi:2283
Cloud        : https://raspberrypi:8080
Docs         : https://raspberrypi:8010
Media        : https://raspberrypi:8096
Musique      : https://raspberrypi:4533
Passwords    : https://raspberrypi:8222
```

#### Apps Mobiles
- Immich (iOS/Android) : Backup photos auto
- Nextcloud (iOS/Android) : Sync fichiers
- Jellyfin (iOS/Android) : Streaming media
- Bitwarden (iOS/Android) : Passwords (Vaultwarden)

---

## 🚀 Scénario 3 : Startup/Freelance MVP

### 👤 Profil
- Entrepreneur/Freelance lançant MVP
- Besoin backend rapidement
- Budget limité (<500€/mois)
- Besoin scalabilité future

### 🎯 Objectif
Lancer MVP sans frais cloud initiaux

### 💰 Économies
~**500€/mois** vs AWS/Firebase/Auth0/Vercel

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Supabase** | Backend complet | 2.5 GB |
| **Traefik** | HTTPS professionnel | 100 MB |
| **Authelia** | SSO + 2FA | 150 MB |
| **Uptime Kuma** | Monitoring uptime | 100 MB |
| **Grafana** | Métriques business | 1.1 GB |
| **Homepage** | Dashboard admin | 50 MB |

**Total RAM** : ~4 GB / 16 GB (25%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Backend Production (~1h)
```bash
# 1. Prérequis optimisés
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# 2. Supabase avec optimisations
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# 3. HTTPS Cloudflare (domaine pro)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

#### Phase 2 : Sécurité & Auth (~20 min)
```bash
# 4. SSO + 2FA pour admin
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash
```

#### Phase 3 : Monitoring Business (~20 min)
```bash
# 5. Monitoring production
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash

# 6. Dashboard admin
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

#### Phase 4 : Backups Critiques (~15 min)
```bash
# 7. Backups offsite (R2/B2 recommandé)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Production
```
Backend API      : https://api.startup.com
Auth             : https://auth.startup.com
Admin Dashboard  : https://admin.startup.com
Monitoring       : https://metrics.startup.com
Uptime           : https://status.startup.com
```

#### Features Disponibles
- ✅ PostgreSQL 15 (relationnel performant)
- ✅ Auth complète (email, OAuth, magic links)
- ✅ API REST auto-générée
- ✅ Realtime subscriptions
- ✅ Storage fichiers S3-compatible
- ✅ Edge Functions (serverless)
- ✅ SSL professionnel (Let's Encrypt)
- ✅ Monitoring 24/7
- ✅ Backups automatiques cloud

---

## 🎬 Scénario 4 : Media Server Familial

### 👤 Profil
- Famille cherchant alternative Netflix/Spotify
- Collection films/séries/musique
- Partage avec amis/famille
- Qualité streaming importante

### 🎯 Objectif
Netflix/Spotify/Plex maison avec gestion automatique

### 💰 Économies
~**150€/mois** vs Netflix + Spotify + Disney+ + Prime Video

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Jellyfin** | Media server | 300 MB |
| **Radarr** | Films auto | 150 MB |
| **Sonarr** | Séries auto | 150 MB |
| **Prowlarr** | Indexer manager | 100 MB |
| **qBittorrent** | Client torrent | 150 MB |
| **Navidrome** | Streaming musical | 100 MB |
| **Traefik** | HTTPS | 100 MB |
| **Homepage** | Dashboard | 50 MB |

**Total RAM** : ~1.1 GB / 16 GB (7%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure (~20 min)
```bash
# 1. Docker + Base
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. HTTPS (DuckDNS gratuit)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

#### Phase 2 : Media Server (~30 min)
```bash
# 3. Jellyfin (serveur media principal)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash

# 4. Stack *arr (automatisation films/séries)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash

# 5. Client torrent
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/qbittorrent/scripts/01-qbittorrent-deploy.sh | sudo bash

# 6. Streaming musical
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```

#### Phase 3 : Interface (~5 min)
```bash
# 7. Dashboard
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Services
```
Media (Jellyfin)  : https://media.monpi.duckdns.org
Films (Radarr)    : https://movies.monpi.duckdns.org
Séries (Sonarr)   : https://tv.monpi.duckdns.org
Torrents          : https://torrents.monpi.duckdns.org
Musique           : https://music.monpi.duckdns.org
Dashboard         : https://home.monpi.duckdns.org
```

#### Apps Compatibles
- Jellyfin (iOS/Android/TV/Roku/Kodi)
- Navidrome → subsonic apps (DSub, Symfonium, etc.)
- Accès navigateur web

#### Workflow Automatique
```
1. Ajouter film dans Radarr
2. Radarr cherche → Prowlarr
3. Prowlarr trouve → qBittorrent
4. qBittorrent télécharge
5. Radarr organise fichiers
6. Jellyfin scanne → Disponible !
```

---

## 🏡 Scénario 5 : Smart Home (Domotique)

### 👤 Profil
- Propriétaire avec objets connectés
- Besoin centralisation contrôle
- Automatisations complexes
- Privacy (pas de cloud externe)

### 🎯 Objectif
Hub domotique central avec automatisations

### 💰 Économies
~**100€/mois** vs Hubitat + SmartThings + abonnements

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Home Assistant** | Hub domotique | 400 MB |
| **Node-RED** | Automatisations visuelles | 150 MB |
| **MQTT** | Broker IoT | 50 MB |
| **Zigbee2MQTT** | Contrôle Zigbee | 80 MB |
| **Traefik** | HTTPS | 100 MB |
| **Grafana** | Dashboards capteurs | 1.1 GB |
| **Homepage** | Dashboard | 50 MB |

**Total RAM** : ~1.9 GB / 16 GB (12%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure (~20 min)
```bash
# 1. Docker + Base
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. VPN sécurisé (Tailscale)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

#### Phase 2 : Domotique (~40 min)
```bash
# 3. Home Assistant (hub principal)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/01-homeassistant-deploy.sh | sudo bash

# 4. Node-RED (automatisations)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/02-nodered-deploy.sh | sudo bash

# 5. MQTT Broker
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/03-mqtt-deploy.sh | sudo bash

# 6. Zigbee (si devices Zigbee)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/04-zigbee2mqtt-deploy.sh | sudo bash
```

#### Phase 3 : Monitoring (~20 min)
```bash
# 7. Dashboards capteurs
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# 8. Interface centralisée
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Services (Tailscale VPN)
```
Home Assistant : https://raspberrypi:8123
Node-RED       : https://raspberrypi:1880
Zigbee2MQTT    : https://raspberrypi:8456
Grafana        : https://raspberrypi:3001
Dashboard      : https://raspberrypi:3030
```

#### Intégrations Disponibles (2000+)
- Philips Hue, IKEA Tradfri
- Sonos, Spotify, Apple Music
- Nest, Ecobee, Tado
- Ring, Arlo, UniFi Protect
- Tesla, Renault ZE
- Google Home, Alexa, Siri
- Et 2000+ autres...

#### Exemples Automatisations
```yaml
# Node-RED : Lumières automatiques
Si soleil couché
  ET mouvement détecté
  ET personne à la maison
→ Allumer lumières entrée

# Home Assistant : Chauffage intelligent
Si température < 19°C
  ET heure > 18h
  ET quelqu'un présent
→ Activer chauffage mode confort
```

---

## 📝 Scénario 6 : Serveur de Productivité

### 👤 Profil
- Travailleur indépendant/Équipe
- Besoin outils collaboratifs
- Gestion documents/notes/projets
- Alternative Google Workspace

### 🎯 Objectif
Suite bureautique complète self-hosted

### 💰 Économies
~**200€/mois** vs Google Workspace + Notion + Slack

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Nextcloud** | Suite Office + Cloud | 500 MB |
| **Paperless-ngx** | GED + OCR | 300 MB |
| **Joplin Server** | Notes collaboratives | 100 MB |
| **Gitea** | Gestion code/docs | 450 MB |
| **n8n** | Automatisations | 300 MB |
| **Vaultwarden** | Passwords équipe | 50 MB |
| **Traefik** | HTTPS | 100 MB |

**Total RAM** : ~1.8 GB / 16 GB (11%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure (~30 min)
```bash
# 1. Base système
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. HTTPS Cloudflare (domaine entreprise)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

#### Phase 2 : Suite Office (~30 min)
```bash
# 3. Nextcloud (Office + Cloud)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash

# 4. Documents + OCR
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy-official.sh | sudo bash

# 5. Notes collaboratives
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/joplin/scripts/01-joplin-deploy.sh | sudo bash
```

#### Phase 3 : Collaboration (~20 min)
```bash
# 6. Git + Wiki + Issues
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# 7. Automatisations workflows (IFTTT-like)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash

# 8. Password manager équipe
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

---

### ✅ Résultat Final

#### Accès Services
```
Office/Cloud     : https://cloud.entreprise.fr
Documents (GED)  : https://docs.entreprise.fr
Notes            : https://notes.entreprise.fr
Git/Wiki         : https://git.entreprise.fr
Workflows        : https://automate.entreprise.fr
Passwords        : https://vault.entreprise.fr
```

#### Fonctionnalités
- ✅ **Nextcloud** : Office collaboratif (Docs, Sheets, Slides)
- ✅ **Paperless** : Scan factures → OCR → Classement auto
- ✅ **Joplin** : Notes Markdown synchronisées
- ✅ **Gitea** : Wiki interne + Documentation
- ✅ **n8n** : Automatisations (Slack → Notion → Email)
- ✅ **Vaultwarden** : Coffre-fort mots de passe

---

## 🎓 Scénario 7 : Serveur d'Apprentissage DevOps

### 👤 Profil
- Étudiant/Junior apprenant DevOps
- Besoin pratique hands-on
- Budget étudiant limité
- Apprentissage Docker/K8s/CI-CD

### 🎯 Objectif
Lab complet pour apprendre infrastructure moderne

### 💰 Économies
~**300€/mois** vs AWS/GCP learning labs

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Supabase** | Database management | 2.5 GB |
| **Traefik** | Reverse proxy | 100 MB |
| **Gitea** | Git + CI/CD | 450 MB |
| **Prometheus/Grafana** | Observability | 1.1 GB |
| **Portainer** | Docker GUI | 100 MB |
| **Homepage** | Dashboard | 50 MB |

**Total RAM** : ~4.3 GB / 16 GB (27%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Fondations (~1h)
```bash
# 1. Hardening + Docker
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/01-system-hardening.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. Supabase (apprendre PostgreSQL + migrations)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# 3. Reverse proxy (apprendre networking)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

#### Phase 2 : CI/CD (~30 min)
```bash
# 4. Git + Pipelines
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
```

#### Phase 3 : Observability (~30 min)
```bash
# 5. Monitoring stack complet
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# 6. Portainer (GUI Docker)
~/pi5-setup/portainer-stack/install.sh

# 7. Dashboard
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

---

### ✅ Résultat Final - Lab Complet

#### Compétences Acquises
- ✅ **Docker** : Containers, networks, volumes, compose
- ✅ **Networking** : Reverse proxy, SSL/TLS, DNS
- ✅ **Databases** : PostgreSQL, migrations, backups
- ✅ **CI/CD** : Pipelines, runners, déploiements
- ✅ **Monitoring** : Métriques, logs, alerting
- ✅ **Security** : Firewall, fail2ban, secrets management
- ✅ **IaC** : Scripts bash, automation

#### Exercices Pratiques
```bash
# 1. Déployer nouvelle app
# 2. Créer pipeline CI/CD
# 3. Configurer monitoring
# 4. Setup backups automatiques
# 5. Simuler incidents (chaos engineering)
# 6. Optimiser ressources (RAM/CPU)
```

---

## ☁️ Scénario 8 : Serveur Cloud Privé

### 👤 Profil
- Utilisateur cherchant indépendance cloud
- Famille/Amis à héberger
- Sync multi-devices
- Privacy important

### 🎯 Objectif
Alternative complète à Google Drive + iCloud

### 💰 Économies
~**250€/mois** vs Google One (2TB) + iCloud+ (2TB)

---

### 📦 Stack Recommandée

| Service | Usage | RAM |
|---------|-------|-----|
| **Nextcloud** | Cloud complet | 500 MB |
| **Syncthing** | Sync P2P | 80 MB |
| **Immich** | Photos | 500 MB |
| **FileBrowser** | Gestionnaire fichiers | 50 MB |
| **Paperless-ngx** | Documents | 300 MB |
| **Vaultwarden** | Passwords | 50 MB |
| **Traefik** | HTTPS | 100 MB |

**Total RAM** : ~1.6 GB / 16 GB (10%)

---

### 🔧 Installation (Ordre des Scripts)

#### Phase 1 : Infrastructure (~20 min)
```bash
# 1. Base
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/02-docker-install-verify.sh | sudo bash
sudo reboot

# 2. VPN Tailscale (accès famille sécurisé)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

#### Phase 2 : Stockage (~30 min)
```bash
# 3. Nextcloud (suite complète)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash

# 4. Sync P2P (alternative)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/syncthing/scripts/01-syncthing-deploy.sh | sudo bash

# 5. FileBrowser (simple & rapide)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash
```

#### Phase 3 : Photos & Docs (~20 min)
```bash
# 6. Photos (Google Photos alt.)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy-official.sh | sudo bash

# 7. Documents + OCR
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy-official.sh | sudo bash

# 8. Passwords
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

---

### ✅ Résultat Final

#### Services Disponibles (Tailscale)
```
Nextcloud      : https://raspberrypi:8080
Syncthing      : https://raspberrypi:8384
FileBrowser    : https://raspberrypi:8095
Photos (Immich): https://raspberrypi:2283
Documents      : https://raspberrypi:8010
Passwords      : https://raspberrypi:8222
```

#### Apps Mobiles (Famille)
- **Nextcloud** : Sync auto fichiers + calendrier + contacts
- **Immich** : Backup photos/vidéos automatique
- **Bitwarden** : Passwords (via Vaultwarden)
- **Syncthing** : Sync dossiers spécifiques

#### Utilisateurs
```bash
# Créer utilisateurs Nextcloud
# Admin : https://raspberrypi:8080
# Settings → Users → Add user
# Partager via Tailscale (inviter famille)
```

---

## 📊 Comparaison des Scénarios

| Scénario | RAM | Temps | Niveau | Services | Économies/mois |
|----------|-----|-------|--------|----------|----------------|
| **1. Développeur** | 4.3 GB | 2h | ⭐⭐⭐ | 7 | ~250€ |
| **2. Homelab** | 1.9 GB | 1.5h | ⭐⭐ | 8 | ~400€ |
| **3. Startup** | 4 GB | 2h | ⭐⭐⭐⭐ | 6 | ~500€ |
| **4. Media** | 1.1 GB | 1h | ⭐⭐ | 8 | ~150€ |
| **5. Domotique** | 1.9 GB | 1.5h | ⭐⭐⭐ | 7 | ~100€ |
| **6. Productivité** | 1.8 GB | 1.5h | ⭐⭐⭐ | 7 | ~200€ |
| **7. DevOps** | 4.3 GB | 2h | ⭐⭐⭐⭐ | 6 | ~300€ |
| **8. Cloud Privé** | 1.6 GB | 1.5h | ⭐⭐ | 7 | ~250€ |

---

## 🔄 Scripts Manquants - Roadmap Proposée

### Scripts à Créer (Priorités)

#### 🔴 Haute Priorité
1. **Script Combo "Développeur"** - Installation 1-click des 7 services
   ```bash
   # À créer : scenarios/01-developer-stack.sh
   ```

2. **Script Combo "Homelab"** - Installation 1-click configuration familiale
   ```bash
   # À créer : scenarios/02-homelab-stack.sh
   ```

3. **Script Combo "Startup MVP"** - Stack production optimisé
   ```bash
   # À créer : scenarios/03-startup-mvp-stack.sh
   ```

#### 🟡 Moyenne Priorité
4. **Script "Media Complete"** - Jellyfin + *arr stack + configuration
   ```bash
   # À créer : scenarios/04-media-complete-stack.sh
   ```

5. **Script "Smart Home Complete"** - Home Assistant + intégrations
   ```bash
   # À créer : scenarios/05-smart-home-stack.sh
   ```

6. **Script "Productivity Suite"** - Alternative Google Workspace
   ```bash
   # À créer : scenarios/06-productivity-stack.sh
   ```

#### 🟢 Basse Priorité
7. **Script "DevOps Learning"** - Lab automatisé
   ```bash
   # À créer : scenarios/07-devops-learning-stack.sh
   ```

8. **Script "Private Cloud"** - Cloud familial complet
   ```bash
   # À créer : scenarios/08-private-cloud-stack.sh
   ```

---

### Services à Ajouter (Roadmap Produit)

#### Communication (Q2 2025)
- [ ] **Matrix** - Chat self-hosted (Slack alt.)
- [ ] **Mattermost** - Teams collaboration
- [ ] **Jitsi Meet** - Visio conférence

#### Business/E-commerce (Q2 2025)
- [ ] **WooCommerce** - E-commerce WordPress
- [ ] **PrestaShop** - Alternative Shopify
- [ ] **Invoice Ninja** - Facturation

#### Knowledge Base (Q1 2025)
- [ ] **BookStack** - Wiki documentation
- [ ] **WikiJS** - Wiki moderne
- [ ] **Outline** - Notion alternative

#### Analytics (Q1 2025)
- [ ] **Plausible** - Analytics privacy-first
- [ ] **Matomo** - Google Analytics alt.
- [ ] **Umami** - Analytics simple

---

## 🚀 Prochaines Étapes

### Pour Commencer

1. **Choisissez votre scénario** selon votre profil
2. **Copiez-collez les commandes** dans l'ordre
3. **Attendez l'installation** (temps indiqué)
4. **Accédez à vos services** (URLs fournies)
5. **Configurez selon besoins** (guides README)

### Personnalisation

**Combiner plusieurs scénarios** :
```bash
# Exemple : Développeur + Media
# 1. Installer scénario 1 (Développeur)
# 2. Ajouter services média du scénario 4
# RAM totale : 4.3 + 1.1 = 5.4 GB (34% de 16GB)
```

**Optimiser RAM** :
```bash
# Stack Manager : Arrêter services non utilisés
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive
```

---

## 📚 Ressources

### Documentation
- [README.md](README.md) - Vue d'ensemble
- [GUIDE-DEPLOIEMENT-WEB.md](GUIDE-DEPLOIEMENT-WEB.md) - Guide web détaillé
- [INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md) - Installation pas-à-pas
- [SCRIPTS-STRATEGY.md](SCRIPTS-STRATEGY.md) - Stratégie scripts

### Guides par Service
Chaque service a son README dans :
```
pi5-setup/
├── 01-infrastructure/[service]/README.md
├── 02-securite/[service]/README.md
├── 03-monitoring/[service]/README.md
└── ... (10 catégories)
```

---

<p align="center">
  <strong>🎯 Choisissez votre scénario et lancez-vous ! 🚀</strong>
</p>

<p align="center">
  <sub>Questions ? <a href="https://github.com/iamaketechnology/pi5-setup/issues">GitHub Issues</a></sub>
</p>
