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

## ✅ Phase 4 - Accès Sécurisé VPN (TERMINÉ)

**Stack**: Tailscale
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-vpn-stack/`
**Temps installation**: 5-10 min

### Réalisations
- [x] ✅ Tailscale installation & configuration automatique
- [x] ✅ Zero-config mesh VPN (NAT traversal automatique)
- [x] ✅ MagicDNS (hostnames automatiques)
- [x] ✅ Subnet Router (accès réseau local via VPN)
- [x] ✅ Exit Node (routage Internet via Pi)
- [x] ✅ SSH via Tailscale (tailscale ssh)
- [x] ✅ Support multi-plateforme (Windows, macOS, Linux, iOS, Android)
- [x] ✅ ACLs (contrôle accès granulaire)
- [x] ✅ Documentation complète (README, INSTALL, GUIDE-DEBUTANT + 3 guides clients)

### Ce qui fonctionne

**Installation en 1 commande** :
```bash
# Installer Tailscale sur Pi
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-vpn-stack/scripts/01-tailscale-setup.sh | sudo bash
```

**Résultat** :
- Pi accessible depuis n'importe où via VPN sécurisé
- Hostname automatique : `raspberrypi.tailnet-name.ts.net`
- Accès services : `http://raspberrypi:3002` (Grafana), `http://raspberrypi:3000` (Homepage)
- SSH sans port forwarding : `ssh pi@raspberrypi`
- Fonctionne derrière CGNAT/firewall/NAT

### Technologies Utilisées (100% Open Source & Gratuit)

**Tailscale** (WireGuard-based)
- **Protocol** : WireGuard (moderne, ultra-rapide)
- **Free tier** : 100 devices (usage personnel)
- **NAT traversal** : Fonctionne partout (WiFi public, 4G, CGNAT)
- **Encryption** : ChaCha20-Poly1305 (end-to-end)
- **Open Source** : Client open source (coordination servers propriétaires)
- **Alternative self-hosted** : Headscale (100% open source)

### Fonctionnalités Clés

**Zero-Config VPN**:
- Pas de port forwarding
- Pas de configuration manuelle
- Pas de certificats à gérer
- Fonctionne en 2 minutes

**MagicDNS**:
- Hostnames automatiques : `raspberrypi`, `laptop`, `phone`
- Pas besoin de retenir IP
- Mis à jour automatiquement

**Subnet Router**:
- Accès réseau local complet (192.168.x.x/24)
- Imprimantes, NAS, IoT accessibles via VPN
- Pas besoin VPN sur chaque device

**Exit Node**:
- Route tout Internet via Pi
- Sécurise connexion WiFi public
- Combine avec Pi-hole → ad blocking global

**SSH via Tailscale**:
- `tailscale ssh raspberrypi` (pas besoin clés)
- Authentification Tailscale
- Logs d'audit centralisés

**ACLs (Access Control Lists)**:
- Contrôle granulaire (qui accède à quoi)
- Exemple : enfants accèdent Jellyfin, pas Grafana

### Scripts Créés

**01-tailscale-setup.sh** (1050 lignes)
- Installation Tailscale sur ARM64
- Configuration réseau (IP forwarding, UFW firewall)
- Auto-détection subnet local
- Features interactives : Subnet Router, Exit Node, MagicDNS
- Mode automatisé : `TAILSCALE_AUTHKEY=xxx ./01-tailscale-setup.sh --yes`
- Intégration stacks existants (Grafana, Homepage, Supabase)
- Summary complet avec URLs et commandes

### Documentation Complète

**README.md** (857 lignes)
- Architecture Tailscale (mesh network, coordination servers)
- Comparaisons : vs WireGuard, vs OpenVPN, vs Cloudflare Tunnel
- 6 use cases réels (SSH distant, Grafana mobile, WiFi public sécurisé)
- Configuration avancée (ACLs, SSH, Headscale)

**INSTALL.md** (754 lignes)
- Prérequis et vérifications
- Installation step-by-step (Pi + clients Windows/macOS/Linux/iOS/Android)
- 7 étapes détaillées avec screenshots descriptions
- Troubleshooting complet

**GUIDE-DEBUTANT.md** (1139 lignes, français)
- C'est quoi un VPN ? (analogies simples)
- Pourquoi Tailscale ? (vs alternatives)
- Comment ça marche ? (diagrammes ASCII)
- 4 cas d'usage réels (étudiant, freelance, famille)
- Installation pas-à-pas
- Questions fréquentes (sécurité, coût, batterie)
- Checklist maîtrise (beginner → advanced)

### Guides Clients (3 plateformes)

**CLIENT-SETUP-ANDROID.md** (12 KB)
- Installation Google Play Store
- Accès services Pi (Supabase, Grafana, Homepage)
- Use cases (monitoring mobile, SSH via Termux)
- Troubleshooting Android-specific

**CLIENT-SETUP-IOS.md** (22 KB)
- Installation App Store
- PWA (Progressive Web Apps) sur Home Screen
- Features iOS : Siri Shortcuts, Split View, Handoff
- SSH avec Termius/Blink Shell
- File transfer avec FE File Explorer

**CLIENT-SETUP-DESKTOP.md** (44 KB)
- **Windows** : GUI installer, winget, Chocolatey, PowerShell, PuTTY
- **macOS** : PKG, Homebrew, App Store, Terminal, iTerm2
- **Linux** : Ubuntu/Debian, Fedora, Arch, openSUSE, GUI clients (Trayscale)
- Tableau comparatif SSH/file transfer tools

### Use Cases Réels

1. **Accès distant sécurisé** : Grafana/Homepage/Supabase depuis travail/vacances
2. **SSH partout** : `tailscale ssh raspberrypi` (pas de port forwarding)
3. **WiFi public sécurisé** : Exit node route tout via Pi
4. **Partage famille** : ACLs pour contrôler accès (Jellyfin OK, Grafana non)
5. **Dev mobile** : App React avec backend Supabase local
6. **Exit node + Pi-hole** : Ad blocking global sur tous devices

### Comparaisons

| Feature | Tailscale | WireGuard | OpenVPN |
|---------|-----------|-----------|---------|
| **Setup** | 2 min | 30 min | 1h |
| **Config** | Zero | Manuelle | Complexe |
| **NAT traversal** | ✅ Auto | ❌ Port fwd | ❌ Port fwd |
| **MagicDNS** | ✅ | ❌ | ❌ |
| **Multi-platform** | ✅ | ✅ | ✅ |
| **Free tier** | 100 devices | Illimité | Illimité |
| **Performance** | Excellent | Excellent | Moyen |
| **Self-hosted** | Headscale | ✅ | ✅ |

### Prochaines améliorations Phase 4
- [ ] Headscale deployment (alternative 100% self-hosted)
- [ ] Monitoring Tailscale avec Grafana (connexions, latence)
- [ ] Automated Tailscale key rotation
- [ ] Pi-hole + Exit node automation
- [ ] Backup ACLs configuration

---

## ✅ Phase 5 - Git Self-Hosted + CI/CD (TERMINÉ)

**Stack**: Gitea + Gitea Actions + Act Runner
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-gitea-stack/`
**Temps installation**: 15-20 min

### Réalisations
- [x] ✅ Gitea latest + PostgreSQL 15 deployment
- [x] ✅ Interface web GitHub-like (repos, issues, PRs, wiki, projects)
- [x] ✅ Gitea Actions (CI/CD compatible GitHub Actions)
- [x] ✅ Act Runner (ARM64 optimized executor)
- [x] ✅ Auto-integration Traefik (DuckDNS/Cloudflare/VPN)
- [x] ✅ Package Registry (Docker, npm, PyPI, Maven, 15+ formats)
- [x] ✅ SSH port 222 (évite conflit avec SSH système)
- [x] ✅ Documentation complète (README, INSTALL, GUIDE-DEBUTANT 4894 lignes)
- [x] ✅ 5 workflow examples production-ready

### Ce qui fonctionne

**Installation en 2 commandes** :

```bash
# Étape 1: Installer Gitea + PostgreSQL
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/01-gitea-deploy.sh | sudo bash

# Étape 2: Installer CI/CD runner
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-gitea-stack/scripts/02-runners-setup.sh | sudo bash
```

**Résultat selon scénario Traefik** :
- **DuckDNS** : `https://monpi.duckdns.org/git` (path-based)
- **Cloudflare** : `https://git.mondomaine.com` (subdomain)
- **VPN** : `https://git.pi.local` (local domain)
- **Sans Traefik** : `http://raspberrypi.local:3000`

**Git SSH clone** :
- DuckDNS : `git@monpi.duckdns.org:222/user/repo.git`
- Cloudflare : `git@git.mondomaine.com:222/user/repo.git`
- Local : `git@raspberrypi.local:222/user/repo.git`

### Technologies Utilisées (100% Open Source & Gratuit)

**Gitea** (MIT License)
- Lightweight : 300-500 MB RAM (vs GitLab 4-8 GB)
- GitHub Actions compatible (95%+ syntaxe identique)
- All-in-one : Git + Issues + PRs + Wiki + CI/CD + Packages
- ARM64 optimized (perfect for Pi 5)

**PostgreSQL** 15-alpine
- Database robuste pour metadata (repos dans volumes)
- Optimisé ARM64

**Act Runner**
- Executor Gitea Actions (basé sur act/nektos)
- Supporte GitHub Actions workflows
- Docker-in-Docker pour builds
- ARM64 native

### Fonctionnalités Clés

**Git Hosting**:
- Repos privés illimités
- Repos publics illimités
- Organizations et teams
- Issues et Pull Requests
- Wiki intégré
- Projects (kanban boards)
- Code review avec comments
- Branch protection rules
- Webhooks (Discord, Slack, etc.)

**Gitea Actions (CI/CD)**:
- Syntaxe GitHub Actions (YAML)
- Workflows sur push, PR, schedule, manual
- Matrix builds (multi-versions)
- Artifacts upload/download
- Caching (npm, Docker, custom)
- Secrets management
- Notifications (Discord, ntfy, Gotify)
- Docker-in-Docker builds

**Package Registry** (15+ formats):
- Docker images
- npm packages
- Python (PyPI)
- Maven (Java)
- NuGet (.NET)
- Cargo (Rust)
- Go modules
- Composer (PHP)
- Helm charts
- Et 7+ autres formats

### Scripts Créés

**01-gitea-deploy.sh** (1251 lignes)
- Gitea + PostgreSQL deployment via Docker Compose
- Auto-détection scénario Traefik (DuckDNS/Cloudflare/VPN)
- Configuration initiale : admin user, SSH port, domain, Actions
- Homepage integration automatique
- Firewall UFW configuration
- Verification complète (6 tests)
- Summary avec URLs et exemples git clone

**02-runners-setup.sh** (1016 lignes)
- Act Runner binary download (ARM64)
- User dédié `gitea-runner` avec Docker access
- systemd service avec hardening
- Runner configuration : labels, cache, concurrency (2 jobs)
- Registration avec token Gitea
- Test workflow example
- Monitoring commands reference

### Exemples CI/CD (5 workflows, 1836 lignes)

**hello-world.yml** (121 lignes)
- Test basic Gitea Actions working
- System info (OS, CPU, memory, disk)
- Environment variables
- Artifacts example

**nodejs-app.yml** (220 lignes)
- Complete CI/CD for Node.js apps
- Matrix builds (Node 18 + 20)
- npm caching
- Lint + test + build
- Security audit
- Deployment example

**docker-build.yml** (245 lignes)
- Multi-arch Docker builds (ARM64 + AMD64)
- Docker Buildx setup
- Automatic tag generation (semver, SHA, latest)
- Push to Docker Hub or Gitea registry
- Image testing and vulnerability scanning (Trivy)

**supabase-edge-function.yml** (332 lignes)
- Auto-deploy Edge Functions sur push
- Deno environment setup
- Function validation et testing
- Deployment to Supabase
- Multi-function support (matrix strategy)
- Notifications (ntfy, Discord, Slack)

**backup-to-rclone.yml** (357 lignes)
- Scheduled backup (daily 2 AM)
- Git bundles creation
- Compression avec checksums
- Upload to rclone remote (R2/B2)
- 30-day retention cleanup
- Notifications multi-channel

### Documentation Complète (4894 lignes)

**README.md** (1686 lignes)
- Vue d'ensemble Gitea
- Architecture stack (Gitea + PostgreSQL + Runner)
- Comparaisons : vs GitHub, vs GitLab, vs Forgejo
- 6 use cases réels
- CI/CD avec examples
- Integration pi5-setup stacks
- Security best practices

**INSTALL.md** (2009 lignes)
- Prérequis et vérifications
- Installation step-by-step (10 étapes)
- SSH configuration (clés, port 222)
- Premier repo et premier commit
- Installation runner CI/CD
- Premier workflow
- Configuration secrets
- Activation Package Registry
- Troubleshooting complet
- Management commands reference

**GUIDE-DEBUTANT.md** (1199 lignes, français)
- C'est quoi Gitea ? (analogies simples)
- Pourquoi Gitea ? (vs GitHub, vs GitLab)
- Comment ça marche ? (diagrammes)
- CI/CD expliqué (robot qui teste code)
- Installation pas-à-pas
- Cas d'usage réels (freelance, startup, student, hobbyist)
- Premier repo walkthrough
- CI/CD simplifié
- Questions fréquentes (10 Q&A)
- Scénarios réels (4 histoires)
- Commandes Git utiles
- Workflows exemples
- Pour aller plus loin

### Use Cases Réels

1. **Repos privés illimités** : Projects personnels, clients, expériences (vs GitHub Free limité)
2. **GitHub backup/mirror** : Sync automatique repos GitHub (protection)
3. **Team collaboration** : Famille, startup, amis (issues, PRs, code review)
4. **CI/CD automation** : Test, build, deploy automatique (Edge Functions, Docker)
5. **Package hosting** : Docker images privées, npm packages, PyPI packages
6. **Documentation** : Wiki intégré pour docs projets

### Comparaisons

| Feature | Gitea | GitHub Free | GitLab CE | Forgejo |
|---------|-------|-------------|-----------|---------|
| **Self-hosted** | ✅ | ❌ | ✅ | ✅ |
| **RAM** | 300-500 MB | N/A | 4-8 GB | 300-500 MB |
| **Private repos** | ✅ Unlimited | ❌ Limited | ✅ Unlimited | ✅ Unlimited |
| **CI/CD** | ✅ Actions | ✅ Actions | ✅ Pipelines | ✅ Actions |
| **Packages** | ✅ 15+ types | ❌ Limited | ✅ Registry | ✅ 15+ types |
| **Setup** | 15 min | N/A | 1-2h | 15 min |
| **License** | MIT | Proprietary | MIT | MIT |

### Intégration Pi5-Setup Stacks

**Avec Supabase** :
- Workflow auto-deploy Edge Functions sur push
- Test automatique fonctions Deno
- Déploiement via Supabase CLI

**Avec Traefik** :
- Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- Labels dynamiques pour HTTPS
- Certificats Let's Encrypt automatiques

**Avec Backups Offsite** :
- Workflow backup quotidien vers R2/B2
- Git bundles compression
- Retention 30 jours

**Avec Monitoring** :
- Grafana metrics Gitea (repos, users, actions runs)
- Prometheus exporter disponible
- Runner stats monitoring

**Avec Homepage** :
- Widget auto-ajouté au dashboard
- Liens directs vers repos, actions, packages

### Prochaines améliorations Phase 5
- [ ] Gitea Packages metrics dans Grafana
- [ ] Automated Gitea backups (postgres + repos)
- [ ] GitHub Actions advanced features (environments, deployments)
- [ ] Docker Registry UI (Harbor alternative)
- [ ] Repository templates automatiques

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

## ✅ Phase 7 - Stockage Cloud Personnel (TERMINÉ)

**Stack**: FileBrowser + Nextcloud (2 options)
**Statut**: ✅ Production Ready v1.0
**Dossier**: `pi5-storage-stack/`
**Temps installation**: 10 min (FileBrowser) / 20 min (Nextcloud)

### Réalisations
- [x] ✅ 2 solutions déployables : FileBrowser (léger) + Nextcloud (complet)
- [x] ✅ Auto-détection Traefik (3 scénarios: DuckDNS/Cloudflare/VPN)
- [x] ✅ FileBrowser: Gestion fichiers web ultra-légère (~50 MB RAM)
- [x] ✅ Nextcloud: Suite complète + PostgreSQL + Redis (~500 MB RAM)
- [x] ✅ Optimisations performance Pi5 (Redis cache, APCu, opcache)
- [x] ✅ Apps Nextcloud recommandées (Calendar, Contacts, Collabora, Photos)
- [x] ✅ Widget Homepage automatique (2 options)
- [x] ✅ Documentation complète (6107 lignes, FRANÇAIS)
- [x] ✅ Guides pédagogiques avec analogies

### Ce qui fonctionne

**FileBrowser (Léger)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-storage-stack/scripts/01-filebrowser-deploy.sh | sudo bash
```
→ Résultat : Interface web de gestion fichiers en 10 minutes
- Upload/Download drag & drop
- Multi-utilisateurs avec permissions
- Partage par lien (expiration configurable)
- Intégration Traefik HTTPS automatique
- Stockage : `/home/pi/storage`

**Nextcloud (Complet)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-storage-stack/scripts/02-nextcloud-deploy.sh | sudo bash
```
→ Résultat : Suite cloud complète en 20 minutes
- Sync desktop (Windows/macOS/Linux)
- Apps mobiles natives (iOS/Android)
- Calendrier/Contacts (CalDAV/CardDAV)
- Édition documents en ligne (Collabora/OnlyOffice)
- Galerie photos + reconnaissance faciale
- 2FA/TOTP, chiffrement E2E
- +300 apps disponibles

### Technologies Utilisées (100% Open Source & Gratuit)

#### FileBrowser
- **FileBrowser** (interface web moderne)
- **SQLite** (base de données)
- **Docker** (conteneurisation)
- **Traefik** (HTTPS auto)

#### Nextcloud
- **Nextcloud** latest (suite cloud)
- **PostgreSQL 15** (base de données ARM64)
- **Redis 7** (cache performances)
- **Collabora/OnlyOffice** (office en ligne, optionnel)
- **Docker Compose** (orchestration)
- **Traefik** (reverse proxy HTTPS)

### Scripts Créés

**01-filebrowser-deploy.sh** (1004 lignes)
- Déploiement FileBrowser Docker
- Auto-détection Traefik (DuckDNS/Cloudflare/VPN/Standalone)
- Configuration stockage `/home/pi/storage`
- Génération credentials admin sécurisés
- Organisation dossiers (uploads, documents, media, archives)
- Config JSON française (locale, permissions)
- Homepage widget intégration
- Tests complets (health check, accessibility)

**02-nextcloud-deploy.sh** (1076 lignes)
- Déploiement stack Nextcloud + PostgreSQL + Redis
- Auto-détection Traefik (3 scénarios)
- Optimisations Pi5 (Redis cache, APCu, opcache, PHP 512M)
- Installation apps recommandées :
  - files_external, calendar, contacts, tasks, notes
  - photos (galerie), recognize (AI faciale)
- Configuration multi-utilisateurs
- Backup automatique avant installation
- OCC CLI setup (maintenance, apps, users)
- Homepage widget avec stats

### Documentation Complète (6107 lignes, FRANÇAIS)

**README.md** (810 lignes)
- Comparaison détaillée FileBrowser vs Nextcloud
- Tableaux de décision (Quand choisir quoi ?)
- Architecture technique (schémas)
- Intégration Traefik (3 scénarios)
- Ressources système (impact RAM)
- Cas d'usage concrets (famille, télétravail, backup)
- Maintenance (logs, backup, restauration)
- Comparaison vs Google Drive/Dropbox (économies 600-1200€/5ans)

**docs/INSTALL.md** (644 lignes)
- Installation FileBrowser step-by-step
- Curl one-liner + installation manuelle
- 3 scénarios Traefik (labels Docker complets)
- Gestion utilisateurs (CLI + Web)
- Configuration avancée (LDAP, limites upload, branding)
- Backup/Restore complet
- Troubleshooting (10+ problèmes courants)

**docs/INSTALL-NEXTCLOUD.md** (1548 lignes)
- Installation Nextcloud complète (3 services)
- Configuration PostgreSQL + Redis
- Commandes OCC CLI détaillées (50+ exemples)
- Apps recommandées avec installation
- Optimisations spécifiques Pi5
- Chiffrement E2E, 2FA/TOTP
- Backup PostgreSQL (pg_dump)
- Troubleshooting avancé (Trusted domains, connexions)

**docs/GUIDE-DEBUTANT.md** (1025 lignes)
- Guide pédagogique avec analogies quotidiennes
- "C'est quoi un cloud personnel ?" (coffre-fort analogie)
- Différence FileBrowser vs Nextcloud expliquée simplement
- Schémas ASCII art (flux données HTTPS)
- Aide à la décision (questionnaire interactif)
- Scénarios réels (famille vacances, télétravail, backup photos)
- Sécurité sans jargon (HTTPS, 2FA expliqués)
- 3 méthodes d'accès (DuckDNS, Cloudflare, VPN)
- Maintenance simplifiée (backup, restauration)
- Problèmes courants avec solutions étape par étape
- Apps mobiles + client desktop tutoriels

### Use Cases Réels

#### FileBrowser
1. **Partage fichiers famille** : Upload photos vacances, lien de partage 7 jours
2. **Accès backups web** : Consulter backups depuis navigateur
3. **Upload mobile** : Upload photos/vidéos depuis téléphone (web)
4. **Streaming médias** : Lecture vidéos/musique directe navigateur
5. **Gestion archives** : Organiser téléchargements et archives

#### Nextcloud
1. **Remplacer Google Workspace** : Drive + Calendar + Contacts + Docs
2. **Cloud familial** : Calendrier partagé, contacts, photos synchronisés
3. **Collaboration documents** : Édition simultanée (Collabora/OnlyOffice)
4. **Sync photos mobile auto** : Upload automatique comme Google Photos
5. **Sync desktop** : Documents, Desktop auto-sync sur tous appareils
6. **Client mail intégré** : Gérer emails (optionnel)
7. **Chat/Visio** : Nextcloud Talk pour communication

### Comparaisons

**FileBrowser vs Nextcloud** :

| Critère | FileBrowser | Nextcloud |
|---------|-------------|-----------|
| **RAM** | ~50 MB | ~500 MB |
| **Setup** | 10 min | 20 min |
| **Complexité** | Simple | Avancée |
| **Sync desktop** | ❌ | ✅ |
| **Apps mobiles** | ❌ | ✅ (natives) |
| **Calendrier** | ❌ | ✅ (CalDAV) |
| **Office en ligne** | ❌ | ✅ (Collabora) |
| **Multi-users** | ✅ (basique) | ✅ (avancé) |
| **Chiffrement** | ❌ | ✅ (E2E) |
| **Use case** | Partage simple | Suite complète |

**vs Google Drive / Dropbox** :

| Service | Coût | Stockage | Privacy | Apps |
|---------|------|----------|---------|------|
| **FileBrowser Pi5** | 0€/mois | Illimité (disque) | 100% privé | Web |
| **Nextcloud Pi5** | 0€/mois | Illimité (disque) | 100% privé | Natives |
| **Google Drive** | 10€/mois | 2 TB | Scanné par Google | Natives |
| **Dropbox** | 12€/mois | 2 TB | Privacy OK | Natives |

**Économies** :
- FileBrowser vs Google Drive : ~600€ sur 5 ans
- Nextcloud vs Dropbox+Office365 : ~1200€ sur 5 ans

### Intégration Pi5-Setup Stacks

**Avec Traefik** :
- Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- Labels Docker dynamiques
- Certificats Let's Encrypt automatiques
- 3 modes :
  - DuckDNS : `https://subdomain.duckdns.org/files` (path-based)
  - Cloudflare : `https://files.votredomaine.com` (subdomain)
  - VPN : `https://files.pi.local` (local via Tailscale)

**Avec Homepage** :
- Widget FileBrowser auto-ajouté (stockage utilisé, liens)
- Widget Nextcloud auto-ajouté (utilisateurs actifs, espace)

**Avec Backups Offsite** (Phase 6) :
- `/home/pi/storage` backupable via rclone
- `/home/pi/nextcloud-data` vers R2/B2
- PostgreSQL Nextcloud dump automatique

**Avec Monitoring** (Phase 3) :
- Nextcloud metrics Prometheus (utilisateurs, storage, apps)
- FileBrowser disk usage dans Grafana

### Prochaines améliorations Phase 7
- [ ] Nextcloud Office (Collabora) one-click install
- [ ] FileBrowser LDAP authentication (vs Authentik Phase 9)
- [ ] Nextcloud Talk (chat/vidéo) deployment guide
- [ ] Galerie photos reconnaissance faciale (Recognize app)
- [ ] Backup automatique Nextcloud vers R2/B2
- [ ] Nextcloud metrics dashboard Grafana
- [ ] Multi-tenancy Nextcloud (plusieurs instances)

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
| 1 | Supabase | ✅ Haute | 6h | 1.2 GB | ✅ Terminé (v1.0) |
| 2 | Traefik + HTTPS | 🔥 Haute | 4h | 100 MB | ✅ Terminé (v1.0) |
| 2b | Homepage | 🔥 Haute | 1h | 80 MB | ✅ Terminé (v1.0) |
| 3 | Monitoring | 🔥 Haute | 3h | 1.2 GB | ✅ Terminé (v1.0) |
| 4 | VPN (Tailscale) | Moyenne | 1h | 50 MB | ✅ Terminé (v1.0) |
| 5 | Gitea + CI/CD | Moyenne | 3h | 500 MB | ✅ Terminé (v1.0) |
| 6 | Backups Offsite | Moyenne | 1h | - | ✅ Terminé (v1.0) |
| 7 | Nextcloud/FileBrowser | Basse | 2h | 50-500 MB | ✅ Terminé (v1.0) |
| 8 | Jellyfin + *arr | Basse | 3h | 800 MB | 🔜 Prochaine |
| 9 | Authelia/Authentik | Basse | 2h | 100 MB | 🔜 Q1 2025 |

### Estimation RAM Totale (toutes phases actives)
- **Actuellement déployé** (Phases 1-7): ~3.2 GB / 16 GB (20%) avec FileBrowser
- **Actuellement déployé** (Phases 1-7): ~3.6 GB / 16 GB (22.5%) avec Nextcloud
- **Minimum infrastructure** : ~3.1 GB / 16 GB (backend + monitoring + CI/CD + VPN + storage)
- **Complet avec media/auth** (Phases 1-9): ~5-6 GB / 16 GB (31-37%)
- **Marge disponible**: ~12.8 GB (FileBrowser) ou ~12.4 GB (Nextcloud) pour apps utilisateur

### Progression Globale
- ✅ **8 phases terminées** : Supabase, Traefik, Homepage, Monitoring, VPN, Gitea, Backups Offsite, Storage
- 🔜 **2 phases restantes** : Media, Auth
- 📊 **Avancement** : 80% (8/10 phases)

---

## 🎯 Prochaines Actions Immédiates

### Phase 8 - Média & Divertissement (Jellyfin) - PROCHAINE ÉTAPE RECOMMANDÉE

**Pourquoi maintenant ?**
- ✅ Infrastructure complète (Supabase, Traefik, Monitoring, Storage, VPN, Backups)
- ✅ 80% du serveur déjà déployé
- ✅ Jellyfin utilise GPU Pi5 (transcodage matériel H.264/H.265)
- ✅ Alternative 100% gratuite et open source à Plex/Emby
- ✅ Stack *arr pour gestion automatisée collection

**Ce qui sera créé** :
```bash
pi5-media-stack/
├── scripts/
│   ├── 01-jellyfin-deploy.sh (serveur média + transcodage GPU)
│   ├── 02-arr-stack-deploy.sh (Radarr, Sonarr, Prowlarr)
│   └── 03-qbittorrent-setup.sh (client torrent avec VPN)
├── docs/
│   ├── GPU-TRANSCODING.md (config VideoCore VII)
│   ├── CLIENT-APPS.md (Android TV, iOS, Roku, etc.)
│   └── LIBRARY-ORGANIZATION.md (structure médias)
└── README.md, INSTALL.md, GUIDE-DEBUTANT.md
```

**Installation prévue** :
```bash
# Installer Jellyfin + GPU transcoding
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/01-jellyfin-deploy.sh | sudo bash

# Installer Radarr/Sonarr (optionnel)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-media-stack/scripts/02-arr-stack-deploy.sh | sudo bash

# Résultat : Netflix-like chez vous
# Accessible via: https://jellyfin.votredomaine.com (ou /jellyfin)
# Apps : Android TV, iOS, Roku, Fire TV, Samsung TV, LG WebOS
```

**Stack complet** :
- **Jellyfin** : Serveur média (films, séries, musique, photos)
- **Radarr** : Gestion automatique films
- **Sonarr** : Gestion automatique séries TV
- **Prowlarr** : Indexer centralisé (recherche torrents)
- **qBittorrent** : Client torrent (avec VPN optionnel)

**Fonctionnalités** :
- 🎬 Transcodage matériel GPU (H.264/H.265/AV1)
- 📱 Apps mobiles natives (iOS, Android)
- 📺 Apps TV (Android TV, Fire TV, Roku, Samsung, LG)
- 🔄 Sync progression multi-appareils
- 👥 Multi-utilisateurs avec profils
- 🌍 Sous-titres automatiques (OpenSubtitles)
- 📊 Statistiques visionnage

### Alternative : Phase 9 - Authentification Centralisée (SSO)

**Option B : Authelia/Authentik** (Sécurité avancée)
- Plus complexe (~2h)
- SSO pour toutes les apps
- 2FA/MFA centralisé
- Protection dashboards sensibles (Grafana, Traefik, etc.)

### Documentation Globale
- [x] ✅ ROADMAP.md complet avec 8 phases terminées (80% du projet)
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
**Version**: 3.25 - Phase 7 Storage (FileBrowser + Nextcloud) terminée 🎉
**Mainteneur**: [@iamaketechnology](https://github.com/iamaketechnology)
