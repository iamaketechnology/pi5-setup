# 🗺️ Roadmap Raspberry Pi 5 - Serveur de Développement

> **Philosophie**: 100% Open Source, Gratuit, Self-Hosted
> **Matériel**: Raspberry Pi 5 (16GB RAM) + ARM64
> **Vision**: Serveur de développement complet et personnel

---

## ✅ Phase 1 - Backend-as-a-Service (TERMINÉ)

**Stack**: Supabase
**Statut**: ✅ Production Ready
**Dossier**: `pi5-supabase-stack/`

### Réalisations
- [x] PostgreSQL 15 (ARM64 optimisé - page size 4KB)
- [x] Auth (GoTrue), REST API (PostgREST), Realtime, Storage
- [x] Supabase Studio UI
- [x] Scripts d'installation automatisés (01-prerequisites, 02-deploy)
- [x] Documentation complète (commands/, docs/, maintenance/)
- [x] Scripts de maintenance (backup, healthcheck, logs, restore, update)
- [x] Installation SSH directe (curl/wget)

### Ce qui fonctionne
```bash
# Installation
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
# (reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

### Prochaines améliorations Phase 1
- [x] ✅ Scripts de maintenance complets (backup, healthcheck, logs, restore, update, scheduler)
- [x] ✅ Documentation DevOps (common-scripts/ + maintenance/)
- [x] ✅ Guide débutant pédagogique (500+ lignes)
- [x] ✅ Intégration avec Traefik (Phase 2 terminée)

**Amélioration continue** :
- [ ] Activer sauvegardes automatiques par défaut dans script 02-deploy
- [ ] Ajouter backup offsite (rclone → R2/B2) - Voir Phase 6
- [ ] Dashboard Supabase metrics (Grafana) - Voir Phase 3

---

## ✅ Phase 2 - Reverse Proxy + HTTPS (TERMINÉ)

**Stack**: Traefik
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-traefik-stack/`
**Temps installation**: 15-30 min selon scénario

### Réalisations
- [x] ✅ Traefik v3 avec 3 scénarios d'installation
- [x] ✅ Scénario 1 (DuckDNS): Gratuit, path-based routing, HTTP-01 challenge
- [x] ✅ Scénario 2 (Cloudflare): Domaine perso, subdomain routing, DNS-01 wildcard
- [x] ✅ Scénario 3 (VPN): Tailscale/WireGuard, certificats auto-signés, sécurité max
- [x] ✅ Dashboard Traefik sécurisé (auth htpasswd)
- [x] ✅ Intégration Supabase automatique (script 02-integrate-supabase.sh)
- [x] ✅ Documentation complète (7 fichiers, ~4000 lignes)
- [x] ✅ Guide débutant pédagogique (1023 lignes)
- [x] ✅ Installation SSH directe (curl/wget)

### Ce qui fonctionne

**Scénario 1 (DuckDNS)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```
→ Résultat : `https://monpi.duckdns.org/studio`

**Scénario 2 (Cloudflare)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```
→ Résultat : `https://studio.mondomaine.fr`

**Scénario 3 (VPN)** :
```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```
→ Résultat : `https://studio.pi.local` (via VPN)

### Technologies Utilisées (100% Open Source & Gratuit)
- **Traefik** v3.3 (reverse proxy moderne)
- **Let's Encrypt** (certificats SSL gratuits, renouvellement auto)
- **DuckDNS** (DNS dynamique gratuit, scénario 1)
- **Cloudflare** (DNS + CDN + DDoS protection gratuit, scénario 2)
- **Tailscale** (VPN mesh gratuit 100 devices, scénario 3)
- **WireGuard** (VPN self-hosted, scénario 3 alternatif)
- **mkcert** (certificats locaux valides, scénario 3 optionnel)

### Prochaines améliorations Phase 2
- [x] ✅ Homepage (portail d'accueil) - Terminé Phase 2b
- [ ] Authelia/Authentik (SSO + 2FA) - Voir Phase 9
- [ ] Rate limiting avancé personnalisable
- [ ] Cloudflare Tunnel automatisé (CGNAT bypass) - Déjà documenté manuellement

---

## ✅ Phase 2b - Dashboard Homepage (TERMINÉ)

**Stack**: Homepage
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-homepage-stack/`
**Temps installation**: 3-5 min

### Réalisations
- [x] ✅ Homepage deployment automatisé (script 01-homepage-deploy.sh)
- [x] ✅ Auto-détection scénario Traefik (DuckDNS, Cloudflare, VPN)
- [x] ✅ Auto-détection services installés (Supabase, Portainer, Grafana, etc.)
- [x] ✅ Génération config YAML personnalisée (services, widgets, settings, bookmarks)
- [x] ✅ Widgets système (CPU, RAM, disk, température, uptime, Docker)
- [x] ✅ Intégration Traefik (labels dynamiques selon scénario)
- [x] ✅ Documentation complète (GUIDE-DEBUTANT 1233 lignes)
- [x] ✅ 100+ intégrations API supportées (Sonarr, Radarr, Pi-hole, etc.)

### Ce qui fonctionne

**Installation unique** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
```

**Résultat selon scénario** :
- **DuckDNS**: `https://monpi.duckdns.org` (chemin racine `/`)
- **Cloudflare**: `https://monpi.fr` ou `https://home.monpi.fr` (au choix)
- **VPN**: `https://pi.local` ou `https://home.pi.local`

### Technologies Utilisées (100% Open Source & Gratuit)
- **Homepage** latest (ARM64 compatible)
- **Docker API** (auto-discovery containers)
- **YAML** configuration (services, widgets, settings, bookmarks)
- **Traefik** integration (labels dynamiques)

### Fonctionnalités Clés
- 📊 **Auto-détection services** : Supabase, Traefik, Portainer, Grafana
- 📈 **Widgets système** : CPU, RAM, disk, température, uptime, Docker stats
- 🎨 **Thèmes** : 10+ thèmes (dark, light, nord, catppuccin, dracula, etc.)
- 🔖 **Bookmarks** : Documentation, GitHub, Docker Hub
- 🔌 **Intégrations** : 100+ services (Sonarr, Radarr, Pi-hole, Proxmox, etc.)
- ⚡ **Léger** : ~50-80 MB RAM
- 🔄 **Live reload** : Config YAML rechargée automatiquement (30s)

### Configuration Générée Automatiquement
```
/home/pi/stacks/homepage/config/
├── services.yaml      # Services détectés + URLs correctes
├── widgets.yaml       # Stats système + search + date/time
├── settings.yaml      # Theme dark + layout responsive
└── bookmarks.yaml     # Docs + développement + communauté
```

### Prochaines améliorations Phase 2b
- [ ] Intégrations API avancées (Prometheus metrics, etc.)
- [ ] Thèmes personnalisés additionnels
- [ ] Backup automatique config YAML

---

## ✅ Phase 3 - Observabilité & Monitoring (TERMINÉ)

**Stack**: Prometheus + Grafana + Node Exporter + cAdvisor
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-monitoring-stack/`
**Temps installation**: 2-3 min

### Réalisations
- [x] ✅ Prometheus (time-series DB, rétention 30j, scrape interval 15s)
- [x] ✅ Grafana (interface moderne, 3 dashboards pré-configurés)
- [x] ✅ Node Exporter (métriques système: CPU, RAM, température, disque, network, load)
- [x] ✅ cAdvisor (métriques containers Docker en temps réel)
- [x] ✅ postgres_exporter (métriques PostgreSQL si Supabase détecté)
- [x] ✅ Auto-détection Traefik (scénario DuckDNS/Cloudflare/VPN)
- [x] ✅ Auto-détection Supabase (activation postgres_exporter + DSN auto-configuré)
- [x] ✅ 3 dashboards Grafana JSON (Raspberry Pi, Docker, PostgreSQL)
- [x] ✅ Intégration Traefik (labels HTTPS selon scénario)
- [x] ✅ Documentation complète (README, INSTALL, GUIDE-DEBUTANT)

### Ce qui fonctionne

**Installation unique** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
```

**Résultat selon scénario Traefik** :
- **DuckDNS**: `https://monpi.duckdns.org/grafana` + `https://monpi.duckdns.org/prometheus`
- **Cloudflare**: `https://grafana.monpi.fr` + `https://prometheus.monpi.fr`
- **VPN**: `http://raspberrypi.local:3002` + `http://raspberrypi.local:9090`
- **Sans Traefik**: `http://raspberrypi.local:3002` + `http://raspberrypi.local:9090`

### Technologies Utilisées (100% Open Source & Gratuit)
- **Prometheus** 2.x (time-series database)
- **Grafana** 11.x (dashboards & alerting)
- **Node Exporter** 1.x (métriques système Linux/ARM64)
- **cAdvisor** latest (Container Advisor)
- **postgres_exporter** latest (métriques PostgreSQL)

### Dashboards Pré-Configurés

**Dashboard 1: Raspberry Pi 5 - Système** (`raspberry-pi-dashboard.json`)
- CPU Usage (%) avec seuils 🟢<70% / 🟠70-80% / 🔴>80%
- CPU Temperature (°C) avec seuils 🟢<60°C / 🟠60-70°C / 🔴>70°C
- Memory Usage (%) avec seuils 🟢<70% / 🟠70-85% / 🔴>85%
- Disk Usage (/) avec seuils 🟢<70% / 🟠70-85% / 🔴>85%
- Network Traffic (RX/TX MB/s)
- System Load (1m, 5m, 15m)
- Uptime

**Dashboard 2: Docker Containers** (`docker-containers-dashboard.json`)
- Top 10 CPU Usage (table triée)
- Top 10 Memory Usage (table triée)
- CPU Over Time (multi-lignes par container)
- Memory Over Time (multi-lignes par container)
- Network I/O (RX/TX par container)
- Disk I/O (Read/Write par container)

**Dashboard 3: Supabase PostgreSQL** (`supabase-postgres-dashboard.json`)
- Active Connections (stat + graph)
- Database Size (MB)
- Cache Hit Ratio (%) avec seuils 🟢>95% / 🟠85-95% / 🔴<85%
- Transaction Rate (txn/s)
- Query Duration (P50/P95/P99 percentiles)
- Locks Count
- WAL Size

### Documentation Complète
- **README.md** (4800+ lignes) : Documentation technique complète
- **INSTALL.md** (3200+ lignes) : Guide d'installation détaillé étape par étape
- **GUIDE-DEBUTANT.md** (5000+ lignes) : Guide pédagogique pour novices avec analogies

### Prochaines améliorations Phase 3
- [ ] Loki + Promtail (logs centralisés) - Phase 3b
- [ ] Alertes email/Slack/Discord (Grafana alerting)
- [ ] Exporter métriques custom depuis apps (Prometheus client libs)
- [ ] Dashboards additionnels (Nginx, Redis, etc. selon stacks installés)

---

## 🔜 Phase 4 - Accès Sécurisé VPN

**Stack**: Tailscale (recommandé) OU WireGuard
**Priorité**: Moyenne (sécurité)
**Effort**: Faible (~1h)
**Dossier**: `pi5-vpn-stack/` (à créer)

### Objectifs
- [ ] VPN pour accès distant sécurisé
- [ ] Pas besoin d'exposer ports au public (sauf 80/443 pour Traefik)
- [ ] Accès au réseau local depuis n'importe où
- [ ] Multi-device (téléphone, laptop)

### Technologies (100% Open Source & Gratuit)

#### Option A: Tailscale (RECOMMANDÉ)
- **Avantages**:
  - Setup ultra-simple (5 min)
  - Gratuit jusqu'à 100 devices
  - Mesh VPN (peer-to-peer)
  - Apps mobile/desktop
  - NAT traversal automatique
- **Inconvénients**:
  - Service tiers (coordination servers)
  - Limite 100 devices (suffisant pour usage personnel)

#### Option B: WireGuard
- **Avantages**:
  - 100% self-hosted
  - Plus léger que Tailscale
  - Contrôle total
- **Inconvénients**:
  - Config manuelle (clés, peers)
  - Pas de NAT traversal auto
  - Besoin port forwarding UDP

### Structure à créer
```
pi5-vpn-stack/
├── README.md
├── scripts/
│   └── 01-tailscale-deploy.sh (ou 01-wireguard-deploy.sh)
├── compose/
│   └── docker-compose.yml (si WireGuard)
└── docs/
    ├── Client-Setup-Android.md
    ├── Client-Setup-iOS.md
    └── Client-Setup-Desktop.md
```

### Recommandation
**Tailscale** pour simplicité + fonctionnalités avancées gratuites.

---

## 🔜 Phase 5 - Git Self-Hosted + CI/CD

**Stack**: Gitea + Gitea Actions
**Priorité**: Moyenne (DevOps)
**Effort**: Moyen (~3h)
**RAM**: ~300-500 MB
**Dossier**: `pi5-gitea-stack/` (à créer)

### Objectifs
- [ ] Serveur Git privé (repos illimités)
- [ ] Interface web GitHub-like
- [ ] Issues, Pull Requests, Wiki
- [ ] CI/CD avec Gitea Actions (compatible GitHub Actions)
- [ ] Runners pour build containers
- [ ] Registry Docker intégré (optionnel)

### Technologies (100% Open Source & Gratuit)
- **Gitea** (Git hosting, léger)
- **Gitea Actions** (CI/CD natif depuis v1.19)
- **Act Runner** (exécution des jobs)

### Use Cases
- Héberger code privé (Edge Functions Supabase, apps personnelles)
- CI/CD pour build/test/deploy automatique
- Backup de repos GitHub (miroirs)
- Collaboration équipe (si besoin)

### Structure à créer
```
pi5-gitea-stack/
├── README.md
├── scripts/
│   ├── 01-gitea-deploy.sh
│   └── 02-runners-setup.sh
├── compose/
│   └── docker-compose.yml
└── docs/
    ├── Configuration.md
    ├── CI-CD-Examples.md
    └── Integration-Supabase.md
```

### Script d'installation prévu
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash
```

### Résultat attendu
- `https://git.mondomaine.com` → Gitea UI
- CI/CD pour build Edge Functions
- Registry Docker (optionnel): `registry.mondomaine.com`

---

## ✅ Phase 6 - Sauvegardes Offsite (TERMINÉ)

**Stack**: rclone + Cloudflare R2 / Backblaze B2
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-backup-offsite-stack/`
**Temps installation**: 10-15 min

### Réalisations
- [x] ✅ rclone installation & configuration automatique
- [x] ✅ Support multi-provider (R2, B2, S3-compatible, Local Disk)
- [x] ✅ 3 scripts complets (setup, enable, restore)
- [x] ✅ Intégration transparente avec backups existants (RCLONE_REMOTE)
- [x] ✅ Encrypted backups support (rclone crypt)
- [x] ✅ GFS rotation sync automatique (7/4/6)
- [x] ✅ Disaster recovery testé (restore complet)
- [x] ✅ Documentation complète (README, INSTALL, GUIDE-DEBUTANT 1861 lignes)

### Ce qui fonctionne

**Installation en 3 étapes** :

```bash
# Étape 1: Configurer rclone avec provider (R2/B2/S3/Local)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/01-rclone-setup.sh | sudo bash

# Étape 2: Activer backups offsite pour Supabase (ou autre stack)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/02-enable-offsite-backups.sh | sudo bash

# Étape 3: Tester la restauration (dry-run)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-backup-offsite-stack/scripts/03-restore-from-offsite.sh | sudo bash --dry-run
```

**Résultat** :
- Backups locaux continuent normalement
- Backups automatiquement uploadés vers cloud après chaque sauvegarde
- Rotation GFS synchronisée (7 daily / 4 weekly / 6 monthly)
- Restauration complète testée et documentée

### Technologies Utilisées (100% Open Source & Gratuit)

#### Stockage Cloud (Free Tier Disponible)
| Provider | Free Tier | Tarif Payant | Performance | Recommandation |
|----------|-----------|--------------|-------------|----------------|
| **Cloudflare R2** | 10 GB | $0.015/GB/mois | Excellent | ⭐ Recommandé (no egress fees) |
| **Backblaze B2** | 10 GB | $0.006/GB/mois | Bon | ⭐ Plus économique |
| **S3-compatible** | Varie | Varie | Varie | Utilisateurs avancés |
| **Local Disk/USB** | Illimité | $0 | Excellent | Testing/NAS |

#### Outil
- **rclone** (sync vers 40+ providers, chiffrement intégré, open source)

### Scripts Créés

**01-rclone-setup.sh** (850 lignes)
- Wizard interactif pour choisir provider (R2/B2/S3/Local)
- Configuration automatisée (mode --yes avec env vars)
- Tests complets (upload, list, download, verify, cleanup)
- Validation credentials avant sauvegarde config

**02-enable-offsite-backups.sh** (750 lignes)
- Auto-détection stacks installés (Supabase, Gitea, Nextcloud)
- Modification schedulers (systemd timers + cron jobs)
- Test backup immédiat avec vérification remote
- Rollback automatique si test échoue

**03-restore-from-offsite.sh** (750 lignes)
- Liste backups disponibles (date, taille, age)
- Download avec progress bar
- Extraction et inspection archive
- Restore PostgreSQL + volumes
- Safety backup pré-restore
- Healthcheck post-restore

### Stratégie de Backup (3-2-1 Rule)

- **3 copies** : Original + Local backup + Offsite backup
- **2 supports** : SD card (original) + Disk local + Cloud
- **1 offsite** : Cloud storage (R2/B2)

**Rotation GFS** :
- **Daily** : 7 jours (local + cloud sync)
- **Weekly** : 4 semaines (cloud)
- **Monthly** : 6 mois (cloud)

### Use Cases Réels

1. **Disaster Recovery** : Pi perdu/volé/détruit → Restauration complète sur nouveau Pi
2. **Migration Hardware** : Pi 4 → Pi 5 en 2h (au lieu de 10h rebuild)
3. **Corruption SD** : Restaurer depuis backup cloud sain
4. **Testing** : Valider backups mensuellement (dry-run restore)
5. **Multi-Site** : Plusieurs Pi → Même bucket cloud (séparation par path)

### Documentation Complète

- **README.md** : Vue d'ensemble, architecture, providers comparison
- **INSTALL.md** : Installation step-by-step avec screenshots descriptions
- **GUIDE-DEBUTANT.md** (1861 lignes) : Guide pédagogique avec analogies et scénarios réels

### Prochaines améliorations Phase 6
- [ ] Monitoring backups offsite (Grafana dashboard)
- [ ] Alertes email/ntfy si backup échoue
- [ ] Multi-cloud redundancy (R2 + B2 simultané)
- [ ] Backup encryption avec GPG (alternative à rclone crypt)
- [ ] Bandwidth throttling automatique (détection usage réseau)

---

## 🔜 Phase 7 - Stockage Cloud Personnel (Optionnel)

**Stack**: Nextcloud OU FileBrowser
**Priorité**: Basse (confort)
**Effort**: Moyen (~2h)
**RAM**: ~500 MB (Nextcloud) / ~50 MB (FileBrowser)
**Dossier**: `pi5-storage-stack/` (à créer)

### Objectifs
- [ ] Synchronisation fichiers (Dropbox-like)
- [ ] Partage de fichiers
- [ ] Accès web + apps mobile
- [ ] Intégration calendrier/contacts (Nextcloud)

### Technologies (100% Open Source & Gratuit)

#### Option A: Nextcloud (complet)
- **Avantages**: Suite complète (fichiers, calendrier, contacts, notes, photos)
- **Inconvénients**: Lourd (~500 MB RAM), complexe

#### Option B: FileBrowser (léger)
- **Avantages**: Ultra-léger (~50 MB RAM), simple, rapide
- **Inconvénients**: Juste gestionnaire fichiers (pas de sync auto)

### Recommandation
**FileBrowser** si juste besoin partage fichiers web.
**Nextcloud** si besoin suite complète (remplacer Google Drive/Calendar).

---

## 🔜 Phase 8 - Média & Divertissement (Optionnel)

**Stack**: Jellyfin + *arr (Radarr, Sonarr, Prowlarr)
**Priorité**: Basse (loisirs)
**Effort**: Moyen (~3h)
**RAM**: ~800 MB
**Dossier**: `pi5-media-stack/` (à créer)

### Objectifs
- [ ] Serveur média (films, séries, musique)
- [ ] Transcodage matériel (GPU Pi5)
- [ ] Apps mobiles/TV
- [ ] Gestion collection automatisée

### Technologies (100% Open Source & Gratuit)
- **Jellyfin** (serveur média, alternative Plex)
- **Radarr** (gestion films)
- **Sonarr** (gestion séries)
- **Prowlarr** (indexer)
- **qBittorrent** (client torrent)

### Note
GPU Pi5 (VideoCore VII) supporte transcodage H.264 matériel.

---

## 🔜 Phase 9 - Authentification Centralisée (Optionnel)

**Stack**: Authelia OU Authentik
**Priorité**: Basse (confort)
**Effort**: Moyen (~2h)
**Dossier**: `pi5-auth-stack/` (à créer)

### Objectifs
- [ ] SSO (Single Sign-On) pour toutes les apps
- [ ] 2FA/MFA centralisé
- [ ] Protection des dashboards sensibles

### Technologies (100% Open Source & Gratuit)

#### Option A: Authelia (léger)
- Middleware Traefik
- TOTP, WebAuthn, Push notifications
- Léger (~100 MB RAM)

#### Option B: Authentik (complet)
- SAML, OAuth2, LDAP
- UI moderne
- Plus lourd (~300 MB RAM)

### Recommandation
**Authelia** si juste besoin protéger dashboards.
**Authentik** si besoin SSO avancé (SAML, LDAP).

---

## 📊 Calendrier Prévisionnel

| Phase | Nom | Priorité | Effort | RAM | Statut |
|-------|-----|----------|--------|-----|--------|
| 1 | Supabase | ✅ Haute | 6h | 2 GB | ✅ Terminé (v1.0) |
| 2 | Traefik + HTTPS | 🔥 Haute | 4h | 100 MB | ✅ Terminé (v1.0) |
| 2b | Homepage | 🔥 Haute | 1h | 80 MB | ✅ Terminé (v1.0) |
| 3 | Monitoring | 🔥 Haute | 3h | 1.2 GB | ✅ Terminé (v1.0) |
| 6 | Backups Offsite | Moyenne | 1h | - | ✅ Terminé (v1.0) |
| 4 | VPN (Tailscale) | Moyenne | 1h | 50 MB | 🔜 Prochaine |
| 5 | Gitea + CI/CD | Moyenne | 3h | 500 MB | 🔜 Q1 2025 |
| 7 | Nextcloud/FileBrowser | Basse | 2h | 500 MB | 🔜 Q2 2025 |
| 8 | Jellyfin + *arr | Basse | 3h | 800 MB | 🔜 Q2 2025 |
| 9 | Authelia/Authentik | Basse | 2h | 100 MB | 🔜 Q2 2025 |

### Estimation RAM Totale (toutes phases actives)
- **Actuellement déployé** (Phases 1-3, 2b): ~3.4 GB / 16 GB (21%)
- **Minimum recommandé** (+ Phase 4-6): ~3.5 GB / 16 GB (22%)
- **Complet** (Phases 1-9): ~6-7 GB / 16 GB (40-45%)
- **Marge disponible**: ~12.6 GB pour apps utilisateur

### Progression Globale
- ✅ **5 phases terminées** : Supabase, Traefik, Homepage, Monitoring, Backups Offsite
- 🔜 **5 phases restantes** : VPN, Gitea, Storage, Media, Auth
- 📊 **Avancement** : 50% (5/10 phases)

---

## 🎯 Prochaines Actions Immédiates

### Phase 4 - VPN (Tailscale) - PROCHAINE ÉTAPE RECOMMANDÉE

**Pourquoi maintenant ?**
- ✅ Infrastructure de base complète (Supabase, Traefik, Monitoring, Backups)
- ✅ Simple et rapide (~1h d'effort)
- ✅ Améliore sécurité sans risque de casser l'existant
- ✅ Complète Phase 2 scénario VPN (alternative plus simple)

**Ce qui sera créé** :
```bash
pi5-vpn-stack/
├── scripts/
│   └── 01-tailscale-setup.sh (installation + config)
├── docs/
│   ├── CLIENT-SETUP-ANDROID.md
│   ├── CLIENT-SETUP-IOS.md
│   └── CLIENT-SETUP-DESKTOP.md
└── README.md, INSTALL.md, GUIDE-DEBUTANT.md
```

**Installation prévue** :
```bash
# Installer Tailscale sur Pi
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-vpn-stack/scripts/01-tailscale-setup.sh | sudo bash

# Résultat : Accès sécurisé depuis n'importe où
# Pi accessible via: http://raspberrypi.tailscale-name.ts.net
```

### Alternatives (si VPN pas souhaité maintenant)

**Option B : Phase 5 - Gitea** (Git self-hosted + CI/CD)
- Plus complexe (~3h)
- Très utile pour développement
- Héberger code privé, CI/CD automatisé

**Option C : Phase 7 - FileBrowser** (Stockage fichiers)
- Simple (~1h)
- Alternative légère à Nextcloud
- Partage fichiers web facile

### Documentation Globale
- [x] ✅ ROADMAP.md complet avec 5 phases terminées
- [ ] Mettre à jour README.md principal avec progression
- [ ] Créer CONTRIBUTING.md pour contributions externes
- [ ] Créer CHANGELOG.md pour historique versions

---

## 🤝 Contribution

Ce projet est 100% open source. Contributions bienvenues !

### Comment contribuer
1. Fork le repo
2. Créer une branche feature (`git checkout -b feature/amazing-stack`)
3. Commit (`git commit -m 'Add amazing stack'`)
4. Push (`git push origin feature/amazing-stack`)
5. Ouvrir une Pull Request

### Guidelines
- Respecter la structure existante (`pi5-*-stack/`)
- Scripts doivent wrapper `common-scripts/` quand possible
- Documentation complète (README + INSTALL.md)
- Tester sur Raspberry Pi 5 ARM64

---

## 📚 Resources

### Communautés
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/raspberry_pi](https://reddit.com/r/raspberry_pi)
- [Awesome-Selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted)

### Documentation
- [Raspberry Pi 5 Docs](https://www.raspberrypi.com/documentation/computers/raspberry-pi-5.html)
- [Docker ARM64](https://docs.docker.com/engine/install/debian/#install-using-the-repository)
- [Traefik Docs](https://doc.traefik.io/traefik/)

---

**Dernière mise à jour**: 2025-10-04
**Version**: 3.24
**Mainteneur**: [@iamaketechnology](https://github.com/iamaketechnology)
