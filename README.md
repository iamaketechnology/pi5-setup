# 🖥️ Raspberry Pi 5 - Serveur Auto-hébergé Complet

> **Transformez votre Raspberry Pi 5 en serveur de développement et personnel tout-en-un**

[![Version](https://img.shields.io/badge/version-5.0-blue.svg)](https://github.com/iamaketechnology/pi5-setup)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-ARM64-orange.svg)](https://www.raspberrypi.com/products/raspberry-pi-5/)
[![OS](https://img.shields.io/badge/OS-Raspberry%20Pi%20OS%2064--bit-red.svg)](https://www.raspberrypi.com/software/)

**Vision** : Un serveur unique pour tous vos besoins de développement, hébergement personnel et services en ligne.

---

## 🌟 Pourquoi ce Projet ?

### Le Problème
- Cloud coûte cher pour side-projects (100-500€/mois)
- Vendor lock-in (AWS, GCP, Azure)
- Données personnelles sur serveurs tiers
- Complexité setup multi-services

### La Solution : Pi5-Setup
- **Un Pi 5 = Un serveur complet** 🚀
- Scripts automatisés, installation en 1 ligne
- Documentation exhaustive (guides débutants → avancés)
- **100% Open Source & Gratuit**
- Économies : **~840€/an** vs services cloud équivalents

### Ce que vous obtenez
✅ **Backend-as-a-Service** (Supabase) - PostgreSQL + Auth + API + Storage
✅ **HTTPS automatique** (Traefik + Let's Encrypt)
✅ **Monitoring** (Prometheus + Grafana + 8 dashboards)
✅ **Git Self-hosted** (Gitea + CI/CD)
✅ **Cloud Storage** (Nextcloud ou FileBrowser)
✅ **Media Server** (Jellyfin + *arr stack)
✅ **VPN** (Tailscale - accès distant sécurisé)
✅ **Domotique** (Home Assistant - 2000+ intégrations)
✅ **Backups automatiques** (local + cloud offsite)
✅ **Et bien plus...** (20 stacks disponibles)

---

## 🚀 Installation Rapide (Pi Neuf → Serveur en 2h)

### 👉 [GUIDE INSTALLATION COMPLÈTE](pi5-setup/INSTALLATION-COMPLETE.md)

**Installation pas-à-pas depuis zéro** - Parfait pour débutants !

**Temps total** : ~2-3h | **Niveau** : Débutant → Avancé

```bash
# ═══════════════════════════════════════
# PHASE 1 : Supabase Stack (~40 min)
# ═══════════════════════════════════════

# Étape 1 : Prérequis (Docker, sécurité, firewall)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# Étape 2 : Déploiement Supabase (après reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# Résultat : http://IP:8000 → Supabase Studio ✅

# ═══════════════════════════════════════
# PHASE 2 : Traefik + HTTPS (~30 min)
# ═══════════════════════════════════════

# Scénario 1 (DuckDNS - Gratuit, débutants)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash

# Résultat : https://monpi.duckdns.org/studio accessible depuis partout ! 🎉

# OU

# Scénario 2 (Cloudflare - Domaine perso ~8€/an)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash

# Résultat : https://studio.mondomaine.fr ✅
```

**🎉 Félicitations !** Vous avez maintenant un serveur complet avec :
- Backend Supabase (PostgreSQL + Auth + API + Storage)
- HTTPS automatique (Let's Encrypt)
- Accès depuis partout (ou VPN)
- Sauvegardes automatiques

---

## 📦 Stacks Disponibles (20+ Services)

### 🛡️ Infrastructure & Réseau

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Supabase](pi5-setup/01-infrastructure/supabase/)** - Backend-as-a-Service | ✅ Production | ~2.5 GB | 40 min |
| **[Traefik](pi5-setup/01-infrastructure/traefik/)** - Reverse Proxy + HTTPS | ✅ Production | ~50 MB | 15-30 min |
| **[Homepage](pi5-setup/08-interface/homepage/)** - Dashboard centralisé | ✅ Production | ~50 MB | 5 min |
| **[VPN Tailscale](pi5-setup/01-infrastructure/vpn-wireguard/)** - Accès distant sécurisé | ✅ Production | ~50 MB | 10 min |
| **[Pi-hole](pi5-setup/01-infrastructure/pihole/)** - Bloqueur publicités réseau | ✅ Production | ~50 MB | 5 min |

### 📊 Monitoring & Observabilité

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Prometheus + Grafana](pi5-setup/03-monitoring/prometheus-grafana/)** - Métriques + Dashboards | ✅ Production | ~1.1 GB | 5 min |
| **[Uptime Kuma](pi5-setup/03-monitoring/uptime-kuma/)** - Monitoring uptime | ✅ Production | ~100 MB | 3 min |

### 🔒 Sécurité & Auth

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Authelia](pi5-setup/02-securite/authelia/)** - SSO + 2FA | ✅ Production | ~150 MB | 10 min |
| **[Vaultwarden](pi5-setup/02-securite/passwords/)** - Password manager | ✅ Production | ~50 MB | 3 min |

### 🐙 Développement & Git

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Gitea](pi5-setup/04-developpement/gitea/)** - Git + CI/CD self-hosted | ✅ Production | ~450 MB | 20 min |

### 💾 Stockage & Cloud

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[FileBrowser](pi5-setup/05-stockage/filebrowser-nextcloud/)** - Gestionnaire fichiers léger | ✅ Production | ~50 MB | 15 min |
| **[Nextcloud](pi5-setup/05-stockage/filebrowser-nextcloud/)** - Cloud storage complet | ✅ Production | ~500 MB | 15 min |
| **[Syncthing](pi5-setup/05-stockage/syncthing/)** - Sync fichiers P2P | ✅ Production | ~80 MB | 3 min |

### 🎬 Media & Divertissement

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Jellyfin](pi5-setup/06-media/jellyfin-arr/)** - Media server (Netflix-like) | ✅ Production | ~300 MB | 20 min |
| **[*arr Stack](pi5-setup/06-media/jellyfin-arr/)** - Radarr + Sonarr + Prowlarr | ✅ Production | ~500 MB | 20 min |
| **[qBittorrent](pi5-setup/06-media/qbittorrent/)** - Client torrent WebUI | ✅ Production | ~150 MB | 3 min |
| **[Navidrome](pi5-setup/06-media/navidrome/)** - Streaming musical | ✅ Production | ~100 MB | 3 min |
| **[Calibre-Web](pi5-setup/06-media/calibre-web/)** - Bibliothèque ebooks | ✅ Production | ~100 MB | 3 min |

### 🏠 Domotique

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Home Assistant](pi5-setup/07-domotique/homeassistant/)** - Hub domotique | ✅ Production | ~400 MB | 10 min |
| **[Node-RED](pi5-setup/07-domotique/homeassistant/)** - Automatisations visuelles | ✅ Production | ~150 MB | 10 min |
| **[MQTT](pi5-setup/07-domotique/homeassistant/)** - Broker IoT | ✅ Production | ~50 MB | 10 min |
| **[Zigbee2MQTT](pi5-setup/07-domotique/homeassistant/)** - Contrôle Zigbee | ✅ Production | ~80 MB | 10 min |

### 📝 Productivité

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Immich](pi5-setup/10-productivity/immich/)** - Google Photos alternative | ✅ Production | ~500 MB | 10 min |
| **[Paperless-ngx](pi5-setup/10-productivity/paperless-ngx/)** - Gestion documents + OCR | ✅ Production | ~300 MB | 5 min |
| **[Joplin Server](pi5-setup/10-productivity/joplin/)** - Serveur de notes | ✅ Production | ~100 MB | 5 min |

### 💾 Backups

| Stack | Statut | RAM | Installation |
|-------|--------|-----|--------------|
| **[Restic Offsite](pi5-setup/09-backups/restic-offsite/)** - Backups cloud (R2/B2) | ✅ Production | ~50 MB | 15 min |

---

## 🎛️ Nouveau : Stack Manager (Gestion RAM/Boot)

**Gérez facilement vos stacks Docker** pour optimiser la RAM :

```bash
# Interface interactive (menus)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive

# Voir état + RAM de tous les stacks
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Start/stop stacks
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start jellyfin

# Gérer démarrage auto au boot
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable nextcloud
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh enable nextcloud
```

**Fonctionnalités** :
- ✅ Start/stop stacks en 1 commande
- ✅ Monitoring RAM en temps réel
- ✅ Configuration démarrage auto au boot
- ✅ Interface interactive (TUI)

**Documentation** : [common-scripts/STACK-MANAGER.md](pi5-setup/common-scripts/STACK-MANAGER.md)

---

## 📊 Estimation Ressources

### Configuration par Niveau

| Configuration | Stacks | RAM Utilisée | RAM Disponible | Temps Installation |
|---------------|--------|--------------|----------------|-------------------|
| **Minimal** (Backend) | Supabase + Traefik + Homepage | ~2.5 GB | ~13.5 GB | ~2h |
| **Standard** (+ Monitoring) | + Prometheus/Grafana + VPN | ~3.6 GB | ~12.4 GB | ~2.5h |
| **Complet** (10 phases) | Toutes phases sauf domotique | ~4.5 GB | ~11.5 GB | ~4-6h |
| **Full Stack** (Tout) | 20 stacks | ~6-8 GB | ~8-10 GB | ~8-10h |

**Pi 5 16GB RAM** recommandé pour configuration complète.

**Astuce** : Utilisez le **Stack Manager** pour arrêter les stacks non utilisés et libérer de la RAM !

---

## 🛠️ Matériel Recommandé

### Configuration Minimale

| Composant | Spécification |
|-----------|---------------|
| **SBC** | Raspberry Pi 5 (8GB RAM) |
| **OS** | Raspberry Pi OS 64-bit (Bookworm) |
| **Storage** | microSD 32GB Class 10 |
| **Réseau** | WiFi ou Ethernet |
| **Alimentation** | USB-C 27W officielle |

**Use Case** : Développement, apprentissage, 3-5 stacks

### Configuration Recommandée (Production)

| Composant | Spécification |
|-----------|---------------|
| **SBC** | Raspberry Pi 5 (16GB RAM) ⭐ |
| **OS** | Raspberry Pi OS 64-bit (Bookworm) |
| **Storage** | NVMe SSD 128GB+ (HAT PCIe) ⭐ |
| **Réseau** | Ethernet Gigabit ⭐ |
| **Alimentation** | USB-C 27W officielle |
| **Refroidissement** | Ventilateur actif ⭐ |

**Use Case** : Serveur multi-stack, production, homelab complet

---

## 🗺️ Roadmap & Phases

### ✅ Phases Terminées

- **✅ Phase 0** : Préparation Pi (flashage, SSH, sécurité)
- **✅ Phase 1** : Supabase Stack (Backend-as-a-Service)
- **✅ Phase 2** : Traefik + HTTPS (3 scénarios)
- **✅ Phase 2b** : Homepage (Dashboard)
- **✅ Phase 3** : Monitoring (Prometheus + Grafana)
- **✅ Phase 4** : VPN (Tailscale)
- **✅ Phase 5** : Gitea + CI/CD
- **✅ Phase 6** : Backups Offsite (rclone → R2/B2)
- **✅ Phase 7** : Storage Cloud (FileBrowser/Nextcloud)
- **✅ Phase 8** : Media Server (Jellyfin + *arr)
- **✅ Phase 9** : Auth SSO (Authelia)
- **✅ Phase 10** : Domotique (Home Assistant)

### 🔜 Phases Futures (Q1-Q2 2025)

- **🔜 Phase 11** : Intelligence Artificielle (Ollama + Open WebUI)
- **🔜 Phase 12** : Communication (Matrix/Mattermost)
- **🔜 Phase 13** : E-commerce (WooCommerce/PrestaShop)
- **🔜 Phase 14** : Wiki & Knowledge Base (BookStack/WikiJS)
- **🔜 Phase 15** : Analytics (Plausible/Matomo)

**Voir** : [ROADMAP complète](pi5-setup/ROADMAP.md) pour tous les détails

---

## 📚 Documentation

### 🎯 Guides Principaux

| Guide | Description | Public |
|-------|-------------|--------|
| **[INSTALLATION-COMPLETE.md](pi5-setup/INSTALLATION-COMPLETE.md)** | Installation pas-à-pas depuis Pi neuf | 🟢 Débutants |
| **[README.md](pi5-setup/README.md)** | Vue d'ensemble du projet | 🟢 Tous |
| **[ROADMAP.md](pi5-setup/ROADMAP.md)** | Planification détaillée 2025-2026 | 🔵 Contributeurs |
| **[PROJET-COMPLET-RESUME.md](pi5-setup/PROJET-COMPLET-RESUME.md)** | Résumé exécutif du projet | 🟢 Décideurs |

### 📖 Guides par Catégorie

- **Infrastructure** : [Supabase](pi5-setup/01-infrastructure/supabase/README.md), [Traefik](pi5-setup/01-infrastructure/traefik/README.md), [VPN](pi5-setup/01-infrastructure/vpn-wireguard/)
- **Sécurité** : [Authelia](pi5-setup/02-securite/authelia/), [Vaultwarden](pi5-setup/02-securite/passwords/)
- **Monitoring** : [Prometheus/Grafana](pi5-setup/03-monitoring/prometheus-grafana/), [Uptime Kuma](pi5-setup/03-monitoring/uptime-kuma/)
- **Développement** : [Gitea](pi5-setup/04-developpement/gitea/)
- **Stockage** : [FileBrowser/Nextcloud](pi5-setup/05-stockage/filebrowser-nextcloud/), [Syncthing](pi5-setup/05-stockage/syncthing/)
- **Media** : [Jellyfin](pi5-setup/06-media/jellyfin-arr/), [qBittorrent](pi5-setup/06-media/qbittorrent/)
- **Domotique** : [Home Assistant](pi5-setup/07-domotique/homeassistant/)
- **Backups** : [Restic Offsite](pi5-setup/09-backups/restic-offsite/)
- **Productivité** : [Immich](pi5-setup/10-productivity/immich/), [Paperless-ngx](pi5-setup/10-productivity/paperless-ngx/), [Joplin](pi5-setup/10-productivity/joplin/)

### 🎯 Stratégie d'Installation

**[📋 SCRIPTS-STRATEGY.md](pi5-setup/SCRIPTS-STRATEGY.md)** - Pourquoi nos scripts custom sont supérieurs

Ce projet utilise une **approche hybride** :
- **12 stacks** : Scripts custom optimisés ARM64/Pi5 (Supabase, Traefik, etc.)
- **3 stacks** : Scripts officiels + wrappers d'intégration (Tailscale, Immich, Paperless-ngx)

**Avantages scripts custom** :
- ✅ **Gain temps 80%** : 2-3h vs 10-25h (installation complète)
- ✅ **Optimisation ARM64** : Fixes page size 16KB, images correctes, RAM
- ✅ **Production-ready** : Backups, rollback, healthchecks, monitoring
- ✅ **Intégration intelligente** : Auto-détection Traefik, Homepage, services

Voir [SCRIPTS-STRATEGY.md](pi5-setup/SCRIPTS-STRATEGY.md) pour l'analyse détaillée.

### 🆘 Troubleshooting

- [Problèmes courants](pi5-setup/INSTALLATION-COMPLETE.md#🆘-problèmes-courants)
- [Scripts de diagnostic](pi5-setup/01-infrastructure/supabase/scripts/utils/)
- [Stack Manager](pi5-setup/common-scripts/STACK-MANAGER.md)

---

## 💡 Use Cases Réels

### 👨‍💻 Développeur Full-Stack
- Backend Supabase pour apps web/mobile
- Git privé avec Gitea + CI/CD
- Monitoring en temps réel (Grafana)
- **Économies** : ~200€/mois vs Vercel/Heroku/Firebase

### 🏠 Homelab Enthusiast
- Tous services cloud en local
- Contrôle total des données
- Apprentissage DevOps/Infrastructure
- **Économies** : ~300€/mois vs Google Workspace/Dropbox/Netflix

### 🚀 Startup MVP
- Backend complet clé-en-main (Supabase)
- Auth + DB + API + Storage + Realtime
- HTTPS professionnel (Traefik)
- **Économies** : ~500€/mois vs AWS/Firebase/Auth0

### 🎓 Étudiant / Apprentissage
- Apprendre Docker, networking, databases
- Infrastructure as Code
- DevOps hands-on
- **Coût** : ~300€ (Pi 5 16GB) + 10€/mois élec.

---

## 🔧 Automatisation & Maintenance

### Scripts Communs ([common-scripts/](pi5-setup/common-scripts/))

- **09-stack-manager.sh** - Gestion stacks (start/stop/RAM/boot)
- **01-preflight.sh** - Vérifications pré-installation
- **02-hardening.sh** - Durcissement sécurité
- **03-docker-install.sh** - Installation Docker optimisée Pi 5
- **04-reverse-proxy-traefik.sh** - Intégration Traefik
- **05-backup-gfs.sh** - Sauvegardes GFS (rotation)
- **06-healthcheck.sh** - Healthchecks automatiques
- **07-update-and-rollback.sh** - Mises à jour safe
- **08-log-collection.sh** - Collecte centralisée logs

**Documentation** : [common-scripts/README.md](pi5-setup/common-scripts/README.md)

### Maintenance Supabase

- **supabase-backup.sh** - Backup PostgreSQL + volumes
- **supabase-restore.sh** - Restore complet
- **supabase-healthcheck.sh** - Vérification santé
- **supabase-update.sh** - Mise à jour version
- **supabase-scheduler.sh** - Configuration crons

**Documentation** : [supabase/scripts/maintenance/README.md](pi5-setup/01-infrastructure/supabase/scripts/maintenance/README.md)

---

## 🤝 Contribution

Ce projet est **open-source** et accueille les contributions !

### Comment Contribuer ?

1. **Tester sur Pi 5 réel** - Valider les scripts ARM64
2. **Reporter bugs** - Ouvrir [issues GitHub](https://github.com/iamaketechnology/pi5-setup/issues)
3. **Améliorer docs** - Clarifications, traductions, exemples
4. **Proposer stacks** - Nouveaux services à ajouter
5. **Partager use cases** - Vos configurations réelles

### Guidelines

- ✅ Tester sur Raspberry Pi 5 ARM64
- ✅ Documenter issues ARM64 spécifiques
- ✅ Scripts automatisés et reproductibles
- ✅ Documentation claire (FR/EN)
- ✅ Commits descriptifs

**Rejoignez-nous** : [Discussions GitHub](https://github.com/iamaketechnology/pi5-setup/discussions)

---

## 🎯 Philosophie du Projet

### Pourquoi Self-Hosted sur Pi 5 ?

- 🔒 **Contrôle Total** - Vos données, votre infrastructure
- 💰 **Économique** - Pas d'abonnements mensuels cloud (~840€/an économisés)
- ⚡ **Performant** - Pi 5 16GB = 40% plus rapide que Pi 4
- 🌱 **Écologique** - Consommation ~10W (vs serveur cloud 100-500W)
- 📚 **Éducatif** - Apprenez DevOps, infrastructure, Docker
- 🔓 **Pas de Lock-in** - 100% open source, migration facile
- 🛡️ **Privacy** - Vos données restent chez vous

### Architecture Cible

```
Raspberry Pi 5 (16GB ARM64)
├── 🗄️  Backend-as-a-Service (Supabase)
│   ├── PostgreSQL 15 + pgvector + extensions
│   ├── Auth (GoTrue) - JWT + OAuth
│   ├── REST API (PostgREST) - Auto-generated
│   ├── Realtime - WebSockets + subscriptions
│   ├── Storage - Fichiers + images + CDN
│   ├── Edge Functions - Deno serverless
│   └── Studio UI - Admin interface
│
├── 🌐 Reverse Proxy + HTTPS (Traefik)
│   ├── Let's Encrypt SSL auto
│   ├── 3 scénarios (DuckDNS/Cloudflare/VPN)
│   ├── Rate limiting + DDoS protection
│   └── Dashboard monitoring
│
├── 📊 Monitoring (Prometheus + Grafana)
│   ├── 8 dashboards pré-configurés
│   ├── Métriques Pi 5 / Docker / PostgreSQL
│   └── Alerting (email/Slack/Discord)
│
├── 🐙 Git Self-Hosted (Gitea)
│   ├── Repos privés illimités
│   ├── Pull requests + issues + wiki
│   └── CI/CD intégré (Gitea Actions)
│
├── 💾 Cloud Storage (Nextcloud/FileBrowser)
│   ├── Sync multi-devices
│   ├── Partage de fichiers
│   └── Apps (calendrier, contacts, notes)
│
├── 🔐 VPN + Security
│   ├── Tailscale - Mesh VPN
│   ├── Vaultwarden - Password manager
│   ├── Authelia - SSO + 2FA
│   └── Pi-hole - DNS ad-blocking
│
├── 🎬 Media Server (Jellyfin + *arr)
│   ├── Jellyfin - Netflix-like
│   ├── Radarr/Sonarr - Automatisation
│   └── Prowlarr - Indexer manager
│
├── 🏠 Domotique (Home Assistant)
│   ├── 2000+ intégrations
│   ├── Node-RED - Automatisations visuelles
│   ├── MQTT - Broker IoT
│   └── Zigbee2MQTT - Contrôle Zigbee
│
├── 📝 Productivité
│   ├── Immich - Google Photos alternative
│   ├── Paperless-ngx - DMS + OCR
│   └── Joplin - Serveur de notes
│
└── 💾 Backups
    ├── Local - GFS rotation (7d/4w/12m)
    └── Offsite - Restic → R2/B2/S3
```

---

## 📜 Licenses

### Code & Scripts
- **MIT License** - Scripts d'installation, configurations
- Libre utilisation, modification, distribution

### Services Déployés
- **Supabase** - Apache 2.0 License
- **Docker** - Apache 2.0 License
- **Traefik** - MIT License
- Voir licenses individuelles par stack

---

## 🙏 Remerciements

### Projets Open-Source
- [Raspberry Pi Foundation](https://www.raspberrypi.com) - Hardware incroyable
- [Supabase](https://supabase.com) - Firebase alternative open-source
- [Traefik](https://traefik.io) - Reverse proxy moderne
- [Docker](https://www.docker.com) - Containerization
- [Grafana](https://grafana.com) - Visualisation de données
- [Home Assistant](https://www.home-assistant.io) - Domotique open-source
- Communauté ARM64/aarch64

### Contributors
- Tous ceux qui testent, reportent bugs, améliorent docs
- Communauté Raspberry Pi francophone
- Communauté self-hosting

---

## 🆘 Support & Communauté

- 🐛 **Bug Reports** : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- 💬 **Discussions** : [GitHub Discussions](https://github.com/iamaketechnology/pi5-setup/discussions)
- 📖 **Wiki** : [GitHub Wiki](https://github.com/iamaketechnology/pi5-setup/wiki)
- ⭐ **Star le projet** : [GitHub Repo](https://github.com/iamaketechnology/pi5-setup)

---

## 📈 Statistiques du Projet

- **20+ stacks** disponibles
- **100% open source & gratuit**
- **~840€/an économisés** vs cloud
- **Scripts 100% automatisés** (installation en 1 ligne)
- **Documentation 15,000+ lignes**
- **Compatible ARM64 Pi 5** (testé en production)

---

<p align="center">
  <strong>🚀 Transformez votre Pi 5 en Serveur Pro ! 🚀</strong>
</p>

<p align="center">
  <sub>Made with ❤️ for developers, homelabbers, and self-hosting enthusiasts</sub>
</p>

<p align="center">
  <sub>⭐ Star le projet si il vous aide ! ⭐</sub>
</p>

<p align="center">
  <a href="https://github.com/iamaketechnology/pi5-setup">
    <img src="https://img.shields.io/github/stars/iamaketechnology/pi5-setup?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/iamaketechnology/pi5-setup/fork">
    <img src="https://img.shields.io/github/forks/iamaketechnology/pi5-setup?style=social" alt="GitHub forks">
  </a>
  <a href="https://github.com/iamaketechnology/pi5-setup/watchers">
    <img src="https://img.shields.io/github/watchers/iamaketechnology/pi5-setup?style=social" alt="GitHub watchers">
  </a>
</p>
