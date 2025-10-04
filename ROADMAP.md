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
- [ ] Homepage (portail d'accueil avec liens vers services)
- [ ] Authelia/Authentik (SSO + 2FA) - Voir Phase 9
- [ ] Rate limiting avancé personnalisable
- [ ] Cloudflare Tunnel automatisé (CGNAT bypass) - Déjà documenté manuellement

---

## 🔜 Phase 3 - Observabilité & Monitoring

**Stack**: Prometheus + Grafana + Node Exporter + cAdvisor
**Priorité**: 🔥 Haute (visibilité système)
**Effort**: Moyen (~3h)
**RAM**: ~1-1.2 GB (OK sur 16GB)
**Dossier**: `pi5-monitoring-stack/` (à créer)

### Objectifs
- [ ] Monitoring CPU, RAM, Disk, Network (Node Exporter)
- [ ] Monitoring containers Docker (cAdvisor)
- [ ] Dashboards Grafana pré-configurés
- [ ] Alertes basiques (disk > 85%, RAM > 90%)
- [ ] Métriques Supabase PostgreSQL (optionnel)

### Technologies (100% Open Source & Gratuit)
- **Prometheus** (time-series DB)
- **Grafana** (dashboards)
- **Node Exporter** (métriques OS)
- **cAdvisor** (métriques containers)
- **Loki** (logs - optionnel Phase 3b)

### Structure à créer
```
pi5-monitoring-stack/
├── README.md
├── scripts/
│   └── 01-monitoring-deploy.sh (wrapper → common-scripts/monitoring-bootstrap.sh)
├── compose/
│   └── docker-compose.yml
├── config/
│   ├── prometheus/
│   │   └── prometheus.yml
│   └── grafana/
│       ├── dashboards/
│       │   ├── raspberry-pi.json
│       │   ├── docker-containers.json
│       │   └── supabase-postgres.json
│       └── datasources/
│           └── prometheus.yml
└── docs/
    └── Dashboards-Guide.md
```

### Script d'installation prévu
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
```

### Résultat attendu
- `https://grafana.mondomaine.com` → Dashboards
- `https://prometheus.mondomaine.com` → Métriques (optionnel, peut rester interne)
- Dashboards: Pi5 system, Docker, Supabase

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

## 🔜 Phase 6 - Sauvegardes Offsite

**Stack**: rclone + Backblaze B2 / Cloudflare R2
**Priorité**: Moyenne (résilience)
**Effort**: Faible (~1h)
**Dossier**: Intégré dans chaque stack

### Objectifs
- [ ] Sauvegardes automatiques vers stockage cloud
- [ ] Rotation GFS (Grandfather-Father-Son)
- [ ] Chiffrement des backups
- [ ] Restauration testée

### Technologies (100% Open Source & Gratuit)

#### Stockage Cloud (choix)
| Provider | Gratuit | Tarif payant | Recommandation |
|----------|---------|--------------|----------------|
| **Cloudflare R2** | 10 GB | $0.015/GB/mois | ⭐ Meilleur rapport |
| **Backblaze B2** | 10 GB | $0.005/GB/mois | Économique |
| **Scaleway Glacier** | - | $0.002/GB/mois | Très économique |
| **S3-compatible local** | Illimité | Disque USB | Self-hosted total |

#### Outil
- **rclone** (sync vers 40+ providers, chiffrement intégré)

### Implémentation
Utilise `common-scripts/04-backup-rotate.sh` déjà existant:

```bash
# Config rclone
rclone config

# Backup Supabase vers R2
sudo RCLONE_REMOTE=r2:mon-bucket/supabase \
  ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh

# Automatiser
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-scheduler.sh
```

### Stratégie de backup
- **Daily**: 7 jours (local + offsite)
- **Weekly**: 4 semaines (offsite)
- **Monthly**: 12 mois (offsite)

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
| 1 | Supabase | ✅ Haute | 6h | 2 GB | ✅ Terminé |
| 2 | Traefik + HTTPS | 🔥 Haute | 4h | 100 MB | 🔜 Q1 2025 |
| 3 | Monitoring | 🔥 Haute | 3h | 1.2 GB | 🔜 Q1 2025 |
| 4 | VPN (Tailscale) | Moyenne | 1h | 50 MB | 🔜 Q1 2025 |
| 5 | Gitea + CI/CD | Moyenne | 3h | 500 MB | 🔜 Q2 2025 |
| 6 | Backups Offsite | Moyenne | 1h | - | 🔜 Q1 2025 |
| 7 | Nextcloud/FileBrowser | Basse | 2h | 500 MB | 🔜 Q2 2025 |
| 8 | Jellyfin + *arr | Basse | 3h | 800 MB | 🔜 Q3 2025 |
| 9 | Authelia/Authentik | Basse | 2h | 100 MB | 🔜 Q3 2025 |

### Estimation RAM Totale (toutes phases actives)
- **Minimum** (Phases 1-4): ~3.5 GB / 16 GB (22%)
- **Complet** (Phases 1-9): ~6-7 GB / 16 GB (40-45%)
- **Marge**: ~9 GB disponibles pour apps utilisateur

---

## 🎯 Prochaines Actions Immédiates

### 1. Finaliser Phase 1
```bash
# Activer automations Supabase
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-scheduler.sh

# Vérifier
systemctl list-timers | grep supabase
journalctl -u supabase-backup.timer -f
```

### 2. Préparer Phase 2
- [ ] Choix domaine (personnel ou DuckDNS)
- [ ] Config DNS (Cloudflare recommandé)
- [ ] Créer structure `pi5-traefik-stack/`
- [ ] Script `01-traefik-deploy.sh`
- [ ] Config Traefik pour Supabase

### 3. Documentation
- [ ] Mettre à jour README.md principal avec lien vers ROADMAP.md
- [ ] Créer CONTRIBUTING.md (pour futures contributions)

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
