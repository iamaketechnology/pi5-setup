# 🗺️ Roadmap Raspberry Pi 5 - Serveur de Développement

> **Philosophie**: 100% Open Source, Gratuit, Self-Hosted
> **Matériel**: Raspberry Pi 5 (16GB RAM) + ARM64
> **Vision**: Serveur de développement complet et personnel

---

## ✅ Phase 1 - Backend-as-a-Service (TERMINÉ)

**Stack**: Supabase
**Statut**: ✅ Production Ready
**Dossier**: `01-infrastructure/supabase/`

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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
# (reboot)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
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
**Dossier**: `01-infrastructure/traefik/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```
→ Résultat : `https://monpi.duckdns.org/studio`

**Scénario 2 (Cloudflare)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```
→ Résultat : `https://studio.mondomaine.fr`

**Scénario 3 (VPN)** :
```bash
curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
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
**Dossier**: `08-interface/homepage/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
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
**Dossier**: `03-monitoring/prometheus-grafana/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
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

---

## 🔭 Apps Natives Populaires (Planifiées)

> Sélection d’applications très utilisées sur Raspberry Pi (ARM64) à intégrer avec notre base de scripts (Traefik, backups, healthchecks, scheduler). Ordonnées par valeur/empreinte.

### 🎯 À quoi ça sert
- Regrouper les services “add‑on” les plus utiles d’un homelab Pi 5 (supervision, DNS filtrant, stockage objet, recherche full‑text, etc.).
- Offrir un cadre d’intégration standard (Traefik/HTTPS, backups, healthchecks, planification) identique aux autres phases.

### ✅ Exemple (Uptime Kuma)
```bash
# 1) Générer un squelette de service avec Traefik
sudo common-scripts/onboard-app.sh --name kuma \
  --domain kuma.mondomaine.com --port 3001

# 2) Remplacer l'image par Uptime Kuma et démarrer
cd ~/stacks/kuma
sed -i 's|ghcr.io/example/.\+:latest|louislam/uptime-kuma:latest|' docker-compose.yml
docker compose up -d

# 3) Ajouter un check Supabase
# Depuis l'UI Kuma: http://kuma.mondomaine.com → New Monitor → URL http://<IP>:8000/health
```

- [ ] Uptime Kuma (supervision simple)
  - ARM64: officiel. RAM ~150–300 MB. Exposé via Traefik (`/kuma` ou `kuma.domaine`), checks pour Supabase/Traefik/Grafana/Portainer.
  - Intégration: labels Traefik, hook `healthcheck-report`, backup config.

- [ ] Pi-hole ou AdGuard Home (DNS filtrant réseau)
  - ARM64: officiel. Léger. Configure DNS LAN, option Exit Node Tailscale.
  - Intégration: exposition locale (pas public), widget Homepage.

- [ ] Vaultwarden (Bitwarden-compatible)
  - ARM64: officiel. RAM ~100–200 MB. Secrets critiques (.env + volumes chiffrés recommandé).
  - Intégration: Traefik + HTTPS, backups réguliers, healthcheck HTTP.

- [ ] Syncthing (sync P2P)
  - ARM64: officiel. Léger. Synchronisation multi-devices.
  - Intégration: Traefik (optionnel), scheduler de backups de config.

- [ ] MinIO (S3 local)
  - ARM64: officiel. RAM ~200–400 MB. Utile pour backups/applications.
  - Intégration: Traefik + HTTPS, policies, hooks backup/rotate.

- [ ] Meilisearch ou Typesense (recherche full‑text)
  - ARM64: officiel. RAM ~300–800 MB selon corpus. Idéal pour apps.
  - Intégration: Traefik, healthchecks, snapshots/backup index.

- [ ] Paperless‑ngx (GED)
  - ARM64: images LinuxServer. RAM moyenne. OCR possible.
  - Intégration: Traefik, backups (DB + media + config), scheduler.

- [ ] Miniflux ou FreshRSS (RSS)
  - ARM64: officiel. Léger. DB Postgres optionnelle.
  - Intégration: Traefik, backups DB/config, healthcheck.

- [ ] code‑server (VS Code Web)
  - ARM64: officiel. RAM moyenne. Accès privé via VPN/SSO (Authelia).
  - Intégration: Traefik + Authelia, backups config/extensions.

- [ ] Loki + Promtail (logs centralisés)
  - ARM64: officiel. Complémente Prometheus/Grafana déjà en place.
  - Intégration: compose dédié, rétention, dashboard Grafana.

- [ ] Unbound / DoH (cloudflared)
  - ARM64: très léger. DNS récursif/DoH local pour privacy.
  - Intégration: avec Pi‑hole/AdGuard en amont.

### Principes d’intégration communs
- Exposition: via Traefik (sous-domaines ou chemins) + certificats.
- Sécurité: Authelia (SSO/2FA) pour UIs critiques quand public.
- Backups: `common-scripts/04*` (rotation GFS), offsite possible (rclone).
- Santé: `common-scripts/05-healthcheck-report.sh` + Uptime Kuma.
- Mises à jour: `common-scripts/06-update-and-rollback.sh`.
- Planification: `common-scripts/08-scheduler-setup.sh` (timers systemd).

---

## 🧭 Améliorations Transverses (Planifiées)

> Initiatives utiles à fort impact pour fiabiliser, sécuriser et opérer le serveur au quotidien.

### Priorisation de l'Idempotence des Scripts

> **Objectif**: Améliorer la robustesse des scripts pour permettre des ré-exécutions sûres sans effets de bord, en se concentrant sur les points à plus fort impact.

- [ ] **Priorité Haute : Scripts de Configuration Système (`common-scripts`)**
  - **Pourquoi**: Ils modifient la configuration de base du système d'exploitation. Une non-idempotence ici est la plus risquée.
  - **Tâches**:
    - [ ] **`01-system-hardening.sh`**: Doit vérifier si une configuration (`sysctl`, etc.) existe avant de l'ajouter pour éviter les doublons ou les erreurs.
    - [ ] **`02-docker-install-verify.sh`**: Doit modifier les fichiers de configuration (ex: `/etc/docker/daemon.json`) de manière non-destructive au lieu de les écraser.

- [ ] **Priorité Moyenne : Scripts de Déploiement d'Application (`pi5-*-stack/scripts/`)**
  - **Pourquoi**: Le risque principal est d'écraser les configurations personnalisées par l'utilisateur (ex: `.env`, `config.yml`). Les commandes `mkdir -p` et `docker compose up` sont déjà idempotentes.
  - **Tâche**:
    - [ ] **Pour tous les scripts de déploiement**: S'assurer que la génération des fichiers de configuration initiaux vérifie si le fichier existe déjà avant de le créer. Ne pas écraser par défaut.

- [ ] **Priorité Basse : Scripts d'Opération (Backups, Healthchecks)**
  - **Pourquoi**: Ces scripts sont par nature conçus pour être exécutés de manière répétée (backups) ou ne modifient pas l'état du système (healthchecks). Ils ne nécessitent généralement pas de modifications.

### 🎯 À quoi ça sert
- Renforcer la fiabilité (backups offsite + tests de restauration), la sécurité (SSO/2FA, secrets), et la visibilité (alerting, logs).
- Standardiser les opérations (timers systemd, runbooks, Makefile) pour des procédures reproductibles.

### ✅ Exemples rapides
```bash
# Offsite backups (restic + rclone)
# 1) Configurer le remote
sudo 09-backups/restic-offsite/scripts/01-rclone-setup.sh

# 2) Activer sauvegardes automatiques (daily) pour Supabase
sudo 09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh \
  BACKUP_SOURCE=~/stacks/supabase \
  RCLONE_REMOTE=remote:pi5/backups/supabase
```

```bash
# SSO/2FA (Authelia) devant les UIs sensibles
sudo 02-securite/authelia/scripts/01-authelia-deploy.sh \
  DOMAIN=mondomaine.com EMAIL=admin@mondomaine.com
# Puis appliquer les middlewares Traefik fournis pour Grafana/Portainer/Studio
```

### Sauvegardes & Restauration
- [ ] Backups offsite chiffrés (restic + rclone)
  - Snapshots dédupliqués, chiffrés vers S3/R2/B2; rotation et vérif d’intégrité.
- [ ] Exercices de restauration (“fire drills”)
  - Restauration de test automatique sur backup le plus récent + rapport.

### Sécurité & Secrets
- [ ] SSO/2FA Authelia sur toutes les UIs sensibles (Studio, Portainer, Grafana)
  - Middlewares Traefik, groupes d’accès, politique par service.
- [ ] Gestion de secrets via sops + age
  - `.env` chiffrés versionnés; cibles `make encrypt/decrypt`.

### Observabilité & Alerting
- [ ] Alerting Grafana/Alertmanager (email/Discord/Telegram)
  - Seuils CPU/RAM/disk, services Supabase, certificats.
- [ ] Logs centralisés (Loki + Promtail)
  - Ingestion Docker/systemd, rétention 7–14 jours, dashboards Grafana.

### Réseau & Accès
- [ ] Tunnels Cloudflare (bypass CGNAT) ou accès privé VPN‑only (Tailscale)
  - Provision auto du tunnel et DNS, ou verrouillage strict par VPN.
- [ ] DNS privé Unbound/DoH (cloudflared)
  - Résolveur local + privacy, amont de Pi‑hole/AdGuard.

### DevOps & Pipelines
- [ ] CI/CD Gitea Actions (apps + Edge Functions Supabase)
  - Runners ARM64, workflows build/publish, déploiement compose/SSH.

### Base de Données & Données
- [ ] Anonymisation/masquage des jeux de données
  - Routines SQL pour dumps partageables sans données sensibles.
- [ ] Snapshots DB fréquents + archives WAL (si RPO serré)
  - Objectif RPO < 1h si nécessaire.

### Fiabilité & Énergie
- [ ] Auto‑récupération: watchdogs + redémarrage ciblé
  - Timers healthcheck agressifs, policies `restart: on-failure`.
- [ ] Suivi thermique/énergie
  - Température, throttling, alertes Grafana.

### Productivité & Recherche
- [ ] code‑server (VS Code Web) protégé SSO/VPN
  - Dev direct sur le Pi; sauvegarde config/extensions.
- [ ] Typesense/Meilisearch (full‑text)
  - Compose + snapshots index + healthcheck dédiés.

### Documentation & Opérations
- [ ] Runbooks d’incident (checklists)
  - “Service down?”, “DB pleine?”, “cert expiré?” avec actions rapides.
- [ ] Makefile/Taskfile unifié
  - `make preflight/backup/update/rollback/health` mappés vers common‑scripts.
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
**Dossier**: `01-infrastructure/vpn-wireguard/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
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
**Dossier**: `04-developpement/gitea/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# Étape 2: Installer CI/CD runner
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
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
**Dossier**: `09-backups/restic-offsite/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash

# Étape 2: Activer backups offsite pour Supabase (ou autre stack)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash

# Étape 3: Tester la restauration (dry-run)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/03-restore-from-offsite.sh | sudo bash --dry-run
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
**Dossier**: `05-stockage/filebrowser-nextcloud/`
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
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash
```
→ Résultat : Interface web de gestion fichiers en 10 minutes
- Upload/Download drag & drop
- Multi-utilisateurs avec permissions
- Partage par lien (expiration configurable)
- Intégration Traefik HTTPS automatique
- Stockage : `/home/pi/storage`

**Nextcloud (Complet)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash
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

## ✅ Phase 8 - Média & Divertissement (TERMINÉ)

**Stack**: Jellyfin + *arr Stack (Radarr, Sonarr, Prowlarr)
**Statut**: ✅ Production Ready v1.0
**Dossier**: `06-media/jellyfin-arr/`
**Temps installation**: 10 min (Jellyfin) + 10 min (*arr)

### Réalisations
- [x] ✅ Jellyfin Media Server avec GPU transcoding (VideoCore VII)
- [x] ✅ *arr Stack complet (Radarr + Sonarr + Prowlarr)
- [x] ✅ Auto-détection Traefik (3 scénarios : DuckDNS/Cloudflare/VPN)
- [x] ✅ GPU transcoding Pi5 (H.264/H.265 hardware decode/encode)
- [x] ✅ Apps mobiles natives (Android TV, iOS, Fire TV, Roku, Samsung, LG)
- [x] ✅ Workflow automatisé complet (recherche → download → organisation → Jellyfin)
- [x] ✅ Widget Homepage (Jellyfin + 3 widgets *arr)
- [x] ✅ Documentation complète (2344 lignes, FRANÇAIS)
- [x] ✅ Guides pédagogiques avec analogies

### Ce qui fonctionne

**Jellyfin (Serveur Média)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash
```
→ Résultat : Netflix-like personnel en 10 minutes
- Interface type Netflix (affiches, métadonnées, résumés)
- GPU transcoding (VideoCore VII H.264/H.265)
- Apps mobiles (Android TV, iOS, Android, Fire TV, Roku, Samsung TV, LG WebOS)
- Multi-utilisateurs avec profils
- Sous-titres automatiques (OpenSubtitles)
- Sync progression multi-appareils
- Bibliothèques : Films, Séries, Musique, Photos
- 4K playback avec hardware decode
- ~300 MB RAM

***arr Stack (Automatisation)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash
```
→ Résultat : Gestion automatisée films/séries
- **Prowlarr** : Indexers centralisés (YTS, 1337x, The Pirate Bay)
- **Radarr** : Gestion films (recherche, download, organisation)
- **Sonarr** : Gestion séries TV (tracking épisodes, download auto)
- Workflow automatisé :
  1. Ajouter film/série → Recherche indexers
  2. Download automatique via client torrent
  3. Renommage + organisation fichiers
  4. Import Jellyfin → Apparaît dans bibliothèque
- ~500 MB RAM (3 services)

### Technologies Utilisées (100% Open Source & Gratuit)

#### Jellyfin
- **Jellyfin** latest (serveur média)
- **VideoCore VII** GPU (Raspberry Pi 5)
- **Docker** (conteneurisation)
- **Traefik** (HTTPS auto)

#### *arr Stack
- **Prowlarr** (indexer manager)
- **Radarr** (movies automation)
- **Sonarr** (TV shows automation)
- **LinuxServer images** (ARM64 optimisés)

### Scripts Créés

**01-jellyfin-deploy.sh** (741 lignes)
- Déploiement Jellyfin Docker
- Configuration GPU VideoCore VII (devices /dev/dri, /dev/vchiq)
- User groups management (video, render)
- Auto-détection Traefik (3 scénarios)
- Configuration bibliothèques (/media/movies, /media/tv, /media/music, /media/photos)
- Homepage widget integration
- Apps clientes links (Android TV, iOS, etc.)
- Performance optimization Pi5

**02-arr-stack-deploy.sh** (1278 lignes)
- Déploiement Radarr + Sonarr + Prowlarr
- Configuration paths (media + downloads)
- Prowlarr indexer sync setup
- Integration Jellyfin (same media paths)
- Auto-détection Traefik (3 scénarios)
- Homepage widgets (3 services avec API)
- Configuration instructions (step-by-step)
- Workflow automation explanation

### Documentation Complète (2344 lignes, FRANÇAIS)

**README.md** (1140 lignes)
- Architecture technique (Jellyfin + *arr)
- GPU transcoding VideoCore VII expliqué
- Workflow automatisé détaillé (schémas)
- Apps clientes avec liens directs (iOS, Android TV, Fire TV, Roku, etc.)
- Comparaison vs Plex/Emby/Netflix (économies 60€/an)
- Ressources système (~800 MB RAM total)
- Intégration Traefik/Homepage/VPN
- Cas d'usage concrets (famille, séries, voyage, enfants)
- Maintenance et troubleshooting

**docs/GUIDE-DEBUTANT.md** (1204 lignes)
- Guide pédagogique avec analogies quotidiennes
- "C'est quoi un serveur média ?" (Netflix chez vous, robot bibliothécaire)
- Différence Jellyfin vs *arr expliquée simplement
- Workflow complet avec schémas ASCII art
- GPU transcoding expliqué sans jargon (traducteur simultané)
- 4 scénarios réels (collection DVD, séries TV, voyage hors ligne, profils enfants)
- Configuration première fois (Jellyfin + Prowlarr → Radarr/Sonarr)
- Utilisation quotidienne (ajouter films/séries, regarder)
- Troubleshooting débutant (solutions pas à pas)

### GPU Transcoding (Raspberry Pi 5 VideoCore VII)

**Support matériel** :
- H.264 hardware decode ✅
- H.265/HEVC hardware decode ✅
- H.264 hardware encode ✅ (limité)
- 4K playback (avec decode matériel)
- 1080p transcoding : 2-3 streams simultanés

**Performances** :
- 4K → 1080p : ~30-40 FPS (matériel)
- 1080p → 720p : ~60+ FPS (matériel)
- CPU fallback si codec non supporté
- Économie énergie (5-10x moins consommation vs CPU)

**Configuration automatique** :
- User 'pi' ajouté groupes 'video' et 'render'
- Devices /dev/dri et /dev/vchiq montés dans conteneur
- Jellyfin configuré pour hardware acceleration
- Tests GPU avant déploiement

### Use Cases Réels

**Jellyfin** :
1. **Bibliothèque familiale** : Rip DVD → Jellyfin → Streaming TV salon
2. **Photos vacances** : Upload /media/photos → Galerie Jellyfin
3. **Musique** : Collection MP3/FLAC → Lecteur audio Jellyfin
4. **Streaming mobile** : App iOS → Films hors ligne (download)
5. **Multi-profils** : Enfants (contrôle parental), Parents (tout accès)

***arr Stack** :
1. **Film automatique** : Radarr → Ajouter "Inception" → Download + Import Jellyfin
2. **Série tracking** : Sonarr → Track "Breaking Bad" → Download 5 saisons auto
3. **Nouveaux épisodes** : Sonarr surveille → Nouvel épisode sort → Download auto
4. **Qualité profiles** : Radarr 1080p BluRay uniquement (filtrage qualité)
5. **Prowlarr sync** : Ajouter indexer → Sync Radarr/Sonarr automatique

### Comparaisons

**Jellyfin vs Plex/Emby** :

| Feature | Jellyfin (Pi5) | Plex Pass | Emby Premiere |
|---------|----------------|-----------|---------------|
| **Coût** | 0€/mois | 5€/mois (60€/an) | 5€/mois (60€/an) |
| **Stockage** | Illimité (disque) | Limité cloud | Limité cloud |
| **Privacy** | 100% local | Tracking Plex | Tracking limité |
| **GPU transcoding** | ✅ Gratuit | ✅ Payant (Pass) | ✅ Payant (Premiere) |
| **Apps mobiles** | ✅ Toutes | ✅ Toutes | ✅ Toutes |
| **Open Source** | ✅ MIT | ❌ Proprietary | ❌ Proprietary |
| **Metadata** | ✅ TMDb/TVDb | ✅ Plex DB | ✅ TMDb/TVDb |

**Économies** : ~60€/an vs Plex Pass / Emby Premiere

### Intégration Pi5-Setup Stacks

**Avec Traefik** :
- Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- Labels Docker dynamiques
- Certificats Let's Encrypt automatiques
- URLs :
  * DuckDNS : https://subdomain.duckdns.org/jellyfin
  * Cloudflare : https://jellyfin.votredomaine.com
  * VPN : https://jellyfin.pi.local

**Avec Homepage** :
- Widget Jellyfin (films count, séries count, stats visionnage)
- Widget Radarr (films monitored, queue)
- Widget Sonarr (séries tracked, épisodes queue)
- Widget Prowlarr (indexers count, health)

**Avec VPN (Tailscale)** :
- Streaming sécurisé depuis n'importe où
- Pas d'exposition Internet public
- Apps mobiles via VPN

**Avec Backups Offsite** (Phase 6) :
- /home/pi/media backupable via rclone
- Jellyfin config backup automatique
- *arr configurations sauvegardées

### Applications Clientes

**Jellyfin Apps disponibles** :
- **Android TV** : https://play.google.com/store/apps/details?id=org.jellyfin.androidtv (recommandé TV)
- **iOS/iPadOS** : https://apps.apple.com/app/jellyfin-mobile/id1480192618
- **Android** : https://play.google.com/store/apps/details?id=org.jellyfin.mobile
- **Fire TV** : Amazon Store
- **Roku** : Roku Channel Store
- **Samsung TV** : Samsung App Store
- **LG WebOS** : LG Content Store
- **Web** : Navigateur (tous appareils)

### Prochaines améliorations Phase 8
- [ ] qBittorrent deployment script (client torrent avec VPN)
- [ ] Jellyfin plugins (Trakt, Intro Skipper, Playback Reporting)
- [ ] Automatic library scans (inotify-based)
- [ ] Jellyfin metrics dashboard Grafana
- [ ] *arr stack metrics (Prometheus exporters)
- [ ] Bazarr deployment (subtitles automation)
- [ ] Lidarr deployment (music automation)

---

## ✅ Phase 9 - Authentification Centralisée (TERMINÉ) 🏆

**Stack**: Authelia + Redis
**Statut**: ✅ Production Ready v1.0 - **PROJET 100% TERMINÉ !** 🎉
**Dossier**: `02-securite/authelia/`
**Temps installation**: 10 min

### Réalisations
- [x] ✅ Authelia SSO + 2FA (TOTP)
- [x] ✅ Redis session storage
- [x] ✅ Auto-détection Traefik (3 scénarios)
- [x] ✅ Génération secrets sécurisés (JWT, session, storage)
- [x] ✅ Argon2id password hashing
- [x] ✅ Traefik middleware (forwardAuth)
- [x] ✅ Access control rules (bypass, one_factor, two_factor)
- [x] ✅ Bruteforce protection (3 tentatives/2min, ban 5min)
- [x] ✅ Documentation complète (1891 lignes, FRANÇAIS)
- [x] ✅ Guide pédagogique avec analogies

### Ce qui fonctionne

**Authelia (SSO + 2FA)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash
```
→ Résultat : Authentification centralisée en 10 minutes
- SSO (Single Sign-On) : 1 login pour tous les services
- 2FA/TOTP : Google Authenticator, Authy, 1Password
- Protection dashboards sensibles (Grafana, Portainer, Traefik)
- Session management Redis (encrypted)
- Bruteforce protection
- Access control rules granulaires
- ~150 MB RAM (Authelia 100 + Redis 50)

### Technologies Utilisées (100% Open Source & Gratuit)

- **Authelia** latest (SSO + 2FA)
- **Redis 7** (session storage)
- **Argon2id** (password hashing)
- **TOTP** (Google Authenticator, Authy)
- **Traefik middleware** (forwardAuth)

### Scripts Créés

**01-authelia-deploy.sh** (1192 lignes)
- Déploiement Authelia + Redis
- Auto-détection Traefik (DuckDNS/Cloudflare/VPN)
- Génération secrets (JWT, session, storage encryption)
- Users database avec Argon2id hashing
- Configuration TOTP/2FA
- Access control rules (bypass public, two_factor dashboards)
- Traefik middleware (forwardAuth)
- Protection services (Grafana, Portainer, Traefik, Prometheus)
- Session Redis (expiration 1h, inactivity 5min)
- Bruteforce protection (max 3 retries/2min, ban 5min)

### Documentation Complète (1891 lignes, FRANÇAIS)

**README.md** (1560 lignes)
- Architecture SSO + 2FA détaillée
- Flux d'authentification (schémas ASCII)
- Configuration 2FA (Google Authenticator/Authy step-by-step)
- Intégration Traefik (3 scénarios)
- Protection services (Grafana, Portainer, Prometheus, Traefik Dashboard)
- Gestion utilisateurs (Argon2id hashing, add/remove/reset)
- Règles d'accès avancées (ACLs par service, groupe, domaine)
- Comparaison Authelia vs Authentik vs Keycloak
- 6 cas d'usage concrets (dashboards, multi-users, audit, compliance)
- Maintenance (backup, rotation secrets, mise à jour)
- Ressources système (~150 MB RAM)
- Troubleshooting (7 problèmes courants avec solutions)

**docs/GUIDE-DEBUTANT.md** (331 lignes)
- Guide pédagogique SSO + 2FA
- "C'est quoi ?" (analogies : portier boîte de nuit, badge+PIN)
- Pourquoi Authelia ? (sécurité dashboards sensibles)
- Comment ça marche ? (workflow schémas ASCII)
- Configuration première fois (2FA setup Google Authenticator)
- 3 scénarios réels (protéger Grafana, Portainer, multi-utilisateurs)
- Troubleshooting débutant (2FA ne marche pas, service bloqué, reset password)

### Fonctionnalités Clés

**SSO (Single Sign-On)** :
- 1 seul login pour tous les services protégés
- Session centralisée (Redis encrypted)
- Cookie domain-wide
- Expiration configurable (1h + inactivity 5min)
- Remember me (1 mois optionnel)

**2FA/TOTP** :
- Google Authenticator, Authy, 1Password, Microsoft Authenticator
- Codes 6 chiffres (30 secondes validity)
- QR code enrollment
- Backup codes (optionnel)
- WebAuthn support (YubiKey, Touch ID)

**Protection Services** :
- Middleware Traefik (forwardAuth)
- Access control rules par service/domaine/groupe
- Bypass pour services publics (Homepage)
- One-factor pour services semi-sensibles
- Two-factor pour dashboards critiques (Grafana, Portainer, Prometheus, Traefik)

**Sécurité** :
- Argon2id password hashing (memory-hard, GPU-resistant)
- Bruteforce protection (max 3 tentatives/2min, ban 5min)
- Session Redis (encrypted, ephemeral)
- JWT secrets rotation
- Storage encryption key
- HTTPS only (Traefik enforced)

### Services Protégés (Exemples)

**Grafana** (Monitoring Dashboard) :
- Policy: two_factor
- Group: admins
- Métriques serveur sensibles

**Portainer** (Docker Management) :
- Policy: two_factor
- Group: admins
- Gestion Docker (accès critique)

**Traefik Dashboard** (Reverse Proxy) :
- Policy: two_factor
- Group: admins
- Configuration réseau

**Prometheus** (Metrics Database) :
- Policy: one_factor ou two_factor
- Group: admins, dev
- Données métriques brutes

**Homepage** (Dashboard Public) :
- Policy: bypass
- Accès public (pas de login)

### Use Cases Réels

1. **Protéger dashboards sensibles** : Grafana, Prometheus, Traefik → Two-factor obligatoire
2. **Multi-utilisateurs** : Famille/équipe avec groupes (admins, dev, users) et règles différentes
3. **Audit logs** : Qui accède à quoi, quand (Authelia logs + Grafana dashboard)
4. **Compliance** : 2FA obligatoire pour services critiques (RGPD, ISO 27001)
5. **SSO centralisé** : 1 password pour tous les services (vs password partout)
6. **Zero-trust security** : Deny-all par défaut, whitelist explicite

### Comparaisons

**Authelia vs Authentik vs Keycloak** :

| Feature | Authelia | Authentik | Keycloak |
|---------|----------|-----------|----------|
| **RAM** | ~150 MB | ~300 MB | ~500 MB |
| **Complexité** | Simple | Moyenne | Avancée |
| **Setup** | 10 min | 20 min | 30 min |
| **SSO** | ✅ | ✅ | ✅ |
| **2FA/TOTP** | ✅ | ✅ | ✅ |
| **WebAuthn** | ✅ | ✅ | ✅ |
| **LDAP** | ✅ (readonly) | ✅ (full) | ✅ (full) |
| **OAuth2** | ❌ | ✅ | ✅ |
| **SAML** | ❌ | ✅ | ✅ |
| **File-based users** | ✅ | ❌ | ❌ |
| **Traefik integration** | ✅ Native | ⚠️ Manual | ⚠️ Manual |
| **ARM64 support** | ✅ | ✅ | ⚠️ Limited |

**Recommandation Pi5** : **Authelia** (léger, simple, Traefik-native, ARM64 optimized)

### Intégration Pi5-Setup Stacks

**Avec Traefik** :
- Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- Middleware automatique (authelia@file)
- ForwardAuth configuration
- URLs :
  * DuckDNS : https://auth.subdomain.duckdns.org
  * Cloudflare : https://auth.votredomaine.com
  * VPN : https://auth.pi.local

**Avec Homepage** :
- Widget Authelia (users count, active sessions)
- Protected services badge
- Login status indicator

**Avec Monitoring** (Phase 3) :
- Authelia metrics Prometheus (login attempts, sessions actives)
- Dashboard Grafana SSO stats
- Alerts (bruteforce détection, failed logins)

**Avec tous les stacks** :
- Protection granulaire par service
- Groupes users (admins, dev, users)
- Access control rules centralisées

### Prochaines améliorations Phase 9
- [ ] Authentik deployment (alternative SAML/OAuth2 full)
- [ ] LDAP backend integration (vs file-based users)
- [ ] Email notifier (SMTP vs file-based)
- [ ] WebAuthn enrollment guide (YubiKey, Touch ID)
- [ ] Authelia metrics dashboard Grafana
- [ ] Automated user provisioning (API)
- [ ] Multi-domain support (plusieurs sites)

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
| 8 | Jellyfin + *arr | Basse | 3h | 800 MB | ✅ Terminé (v1.0) |
| 9 | Authelia + 2FA | Basse | 2h | 150 MB | ✅ Terminé (v1.0) 🏆 |

### Estimation RAM Totale (toutes phases actives)
- **PROJET COMPLET** (Phases 1-9): ~4.2 GB / 16 GB (26%) avec FileBrowser
- **PROJET COMPLET** (Phases 1-9): ~4.6 GB / 16 GB (29%) avec Nextcloud
- **Infrastructure complète** : ~4.2 GB / 16 GB (backend + monitoring + CI/CD + VPN + storage + media + auth)
- **Marge disponible**: ~11.8 GB (FileBrowser) ou ~11.4 GB (Nextcloud) pour apps utilisateur
- **Serveur production-ready** : ✅ Toutes fonctionnalités déployées !

### Progression Globale
- ✅ **10/10 phases terminées** : Supabase, Traefik, Homepage, Monitoring, VPN, Gitea, Backups Offsite, Storage, Media, Auth
- 🏆 **PROJET 100% TERMINÉ !** 🎉🎊
- 📊 **Avancement** : 100% (10/10 phases) - **MISSION ACCOMPLIE !**

---

## 🏆 PROJET TERMINÉ À 100% ! 🎉

### Ce qui a été construit

**10 phases complètes** déployées et documentées :

1. ✅ **Supabase** (Backend-as-a-Service) - PostgreSQL + Auth + REST API + Realtime
2. ✅ **Traefik** (Reverse Proxy + HTTPS) - 3 scénarios (DuckDNS/Cloudflare/VPN)
3. ✅ **Homepage** (Dashboard) - Portail centralisé avec widgets
4. ✅ **Monitoring** (Prometheus + Grafana) - 8 dashboards pré-configurés
5. ✅ **VPN** (Tailscale) - Accès sécurisé distant + subnet router
6. ✅ **Gitea** (Git + CI/CD) - GitHub-like self-hosted + Actions
7. ✅ **Backups Offsite** (rclone) - R2/B2 avec rotation GFS
8. ✅ **Storage** (FileBrowser + Nextcloud) - Cloud personnel + sync
9. ✅ **Media** (Jellyfin + *arr) - Netflix-like + GPU transcoding Pi5
10. ✅ **Auth** (Authelia) - SSO + 2FA pour tous les services

### Statistiques Finales

**Code créé** :
- **~50,000 lignes** de scripts bash + docker-compose
- **~40,000 lignes** de documentation française
- **Total : ~90,000 lignes** de code production-ready

**Documentation** :
- 10 README.md complets (architecture + comparaisons)
- 10 GUIDE-DEBUTANT.md pédagogiques (analogies + schémas)
- Installation guides détaillés
- Troubleshooting exhaustifs

**Ressources système** :
- RAM : 4.2-4.6 GB / 16 GB (26-29%)
- Marge : ~12 GB disponible pour apps utilisateur
- CPU : <30% en moyenne (idle ~5-10%)
- Stockage : ~10 GB (stacks + configs)

### Installation Complète (Ordre Recommandé)

```bash
# Phase 1 : Backend (Supabase)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
# Reboot
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash

# Phase 2 : Reverse Proxy (Traefik - choisir scénario)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# Phase 2b : Dashboard (Homepage)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash

# Phase 3 : Monitoring (Prometheus + Grafana)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# Phase 4 : VPN (Tailscale)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash

# Phase 5 : Git + CI/CD (Gitea)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# Phase 6 : Backups Offsite (rclone)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash

# Phase 7 : Storage Cloud (FileBrowser ou Nextcloud)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash

# Phase 8 : Media Server (Jellyfin + *arr)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash

# Phase 9 : Auth Centralisée (Authelia)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash

# Bonus : Portainer (gestion Docker)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/portainer-stack/install.sh | sudo bash
```

**Temps total installation** : ~2-3h (dépend téléchargements Docker)

### Philosophie 100% Respectée

✅ **100% Open Source** : Aucun logiciel propriétaire
✅ **100% Gratuit** : 0€/mois (vs ~50-100€/mois services cloud équivalents)
✅ **100% Self-Hosted** : Toutes données chez vous
✅ **100% Production-Ready** : Scripts testés, idempotents, dry-run support
✅ **100% Documenté** : Français + anglais, guides débutants, troubleshooting
✅ **100% ARM64** : Optimisé Raspberry Pi 5

### Économies Annuelles vs Cloud

| Service | Coût Cloud | Pi5 Self-Hosted | Économie/an |
|---------|------------|-----------------|-------------|
| Supabase Pro | 25€/mois | 0€ | 300€ |
| GitHub Actions | 10€/mois | 0€ (Gitea) | 120€ |
| Nextcloud | 10€/mois | 0€ | 120€ |
| Jellyfin vs Plex Pass | 5€/mois | 0€ | 60€ |
| Grafana Cloud | 15€/mois | 0€ | 180€ |
| Tailscale Teams | 5€/mois | 0€ (100 devices free) | 0€ |
| **TOTAL** | **~70€/mois** | **0€/mois** | **~840€/an** 💰 |

**Retour sur investissement** : Pi5 (100€) amorti en 1.5 mois !

### Améliorations Post-Lancement

- [x] ✅ **Stack Manager** (common-scripts/09-stack-manager.sh) - Gestion facile des stacks Docker
  - Interface interactive (TUI) pour start/stop stacks
  - Monitoring RAM par stack
  - Configuration démarrage automatique au boot
  - Optimisation consommation RAM selon usage

## ✅ Phase 10 - Domotique & Maison Connectée (TERMINÉ) 🏠

**Stack**: Home Assistant + Node-RED + MQTT + Zigbee2MQTT
**Statut**: ✅ Production Ready v1.0
**Dossier**: `07-domotique/homeassistant/`
**Temps installation**: 10 min (configuration minimale)

### Réalisations

- [x] ✅ **Script 01-homeassistant-deploy.sh** - Home Assistant deployment (600+ lignes)
- [x] ✅ **Script 02-nodered-deploy.sh** - Node-RED deployment (250+ lignes)
- [x] ✅ **Script 03-mqtt-deploy.sh** - MQTT Broker Mosquitto (250+ lignes)
- [x] ✅ **Script 04-zigbee2mqtt-deploy.sh** - Zigbee2MQTT deployment (350+ lignes)
- [x] ✅ Auto-détection Traefik (3 scénarios)
- [x] ✅ Intégration Homepage automatique (widgets)
- [x] ✅ Documentation complète (README, guide complet)

### Ce qui fonctionne

**Installation configuration minimale** :
```bash
# Home Assistant + MQTT + Node-RED (~630 MB RAM)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/01-homeassistant-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/03-mqtt-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/02-nodered-deploy.sh | sudo bash
```

**Installation complète (avec Zigbee)** :
```bash
# Toutes les apps (~710 MB RAM) - Nécessite dongle Zigbee USB
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/04-zigbee2mqtt-deploy.sh | sudo bash
```

**Résultat selon scénario Traefik** :
- **DuckDNS**: `https://monpi.duckdns.org/homeassistant`
- **Cloudflare**: `https://home.mondomaine.com`
- **VPN**: `https://home.pi.local`
- **Sans Traefik**: `http://raspberrypi.local:8123`

### Technologies Utilisées (100% Open Source & Gratuit)

**Home Assistant** (MIT License)
- Hub domotique #1 mondial
- 2000+ intégrations (Philips Hue, Xiaomi, Sonoff, Google Home, Alexa, etc.)
- Interface moderne + mobile apps
- Automatisations visuelles
- Commande vocale
- 100% local (privacy)

**Node-RED** (Apache 2.0)
- Automatisations visuelles (drag & drop)
- Pas de code requis
- Intégrations : MQTT, HTTP, Webhooks, DB

**Mosquitto** (EPL/EDL)
- MQTT Broker standard IoT
- Léger (~30 MB RAM)
- Protocol pub/sub

**Zigbee2MQTT** (GPL 3.0)
- Passerelle Zigbee sans hub propriétaire
- 2000+ appareils Zigbee compatibles
- Philips Hue, IKEA, Xiaomi sans leurs hubs

### Fonctionnalités Clés

**Home Assistant** :
- Dashboard personnalisable
- Automatisations ("si ... alors ...")
- Graphiques historiques
- Notifications (mobile, email, Discord, Telegram)
- Commande vocale (Google, Alexa, Siri)
- Apps mobiles natives (iOS, Android)

**Node-RED** :
- Interface drag & drop
- Automatisations complexes visuelles
- Complémentaire à Home Assistant

**MQTT** :
- Communication IoT (ESP32, Tasmota, Sonoff)
- Protocole standard
- Intégration Home Assistant automatique

**Zigbee2MQTT** :
- Contrôler Philips Hue sans Hue Bridge
- IKEA Tradfri sans passerelle IKEA
- Xiaomi Aqara sans hub Xiaomi
- Économie : ~100-200€ (pas besoin de hubs)

### Scripts Créés

**01-homeassistant-deploy.sh** (600+ lignes)
- Déploiement Home Assistant Docker
- Auto-détection Traefik (labels dynamiques)
- Configuration initiale guidée
- Intégration Homepage automatique
- Attente démarrage (healthcheck)

**02-nodered-deploy.sh** (250+ lignes)
- Déploiement Node-RED Docker
- Permissions utilisateur (1000:1000)
- Volumes data persistants
- Widget Homepage automatique

**03-mqtt-deploy.sh** (250+ lignes)
- Déploiement Mosquitto MQTT Broker
- Configuration mosquitto.conf
- Ports 1883 (MQTT) + 9001 (WebSocket)
- Persistence + logs
- Test clients MQTT

**04-zigbee2mqtt-deploy.sh** (350+ lignes)
- Auto-détection dongle Zigbee USB
- Configuration Zigbee2MQTT
- Network mode host (discovery)
- Intégration MQTT automatique
- Intégration Home Assistant via MQTT Discovery

### Matériel Optionnel

**Pour Zigbee2MQTT** :
- **Dongle Zigbee USB** (~20€) : [Sonoff Dongle Plus](https://itead.cc/product/sonoff-zigbee-3-0-usb-dongle-plus/) (recommandé)
- Alternatives : CC2531 (~15€), ConBee II (~40€)

**Pour DIY** :
- **ESP32/ESP8266** (~5€) : Créer capteurs custom avec ESPHome

**Appareils compatibles** :
- Ampoules : Philips Hue (~10-30€), IKEA Tradfri (~10-15€), Yeelight (~15-25€)
- Capteurs : Xiaomi Aqara (température, mouvement, porte) (~10-20€)
- Interrupteurs : Sonoff, Shelly (~10-20€)

### Use Cases Réels

1. **Allumer lumières au coucher du soleil** : Automatisation Home Assistant
2. **Notification mouvement détecté** : Capteur → Home Assistant → Push mobile
3. **Contrôle vocal** : "Ok Google, allume le salon" → Home Assistant → Lumières
4. **Dashboard température** : Capteurs Xiaomi → MQTT → Home Assistant → Graphiques
5. **Automatisation complexe** : Node-RED → Si temp > 25°C → Envoyer notification Telegram
6. **Contrôler Philips Hue sans hub** : Zigbee2MQTT → Économie ~80€ (pas de Hue Bridge)
7. **ESP32 DIY** : Capteur température custom → MQTT → Home Assistant

### Comparaison vs Solutions Cloud

| Feature | Home Assistant Pi5 | Google Home | Apple HomeKit | Amazon Alexa |
|---------|-------------------|-------------|---------------|--------------|
| **Coût** | 0€/mois | Gratuit | Gratuit | Gratuit |
| **Privacy** | 100% local | ⚠️ Cloud Google | ⚠️ Cloud Apple | ⚠️ Cloud Amazon |
| **Intégrations** | 2000+ | ~1000 | ~500 | ~1500 |
| **Automatisations** | ✅ Illimitées | ❌ Basiques | ⚠️ Limitées | ⚠️ Limitées |
| **Graphiques** | ✅ Complets | ❌ | ❌ | ❌ |
| **Contrôle offline** | ✅ | ❌ | ⚠️ Partiel | ❌ |
| **Custom** | ✅ Total | ❌ | ❌ | ❌ |

**Économies** : Home Assistant Pi5 = 0€/mois vs abonnements futurs assistants cloud

### Intégration Pi5-Setup Stacks

**Avec Traefik** :
- Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- Labels Docker dynamiques
- Certificats HTTPS automatiques

**Avec Homepage** :
- Widget Home Assistant auto-ajouté
- Widget Node-RED auto-ajouté
- Section "Domotique" créée automatiquement

**Avec Stack Manager** :
- Start/stop stacks domotique
- Monitoring RAM (~630 MB configuration minimale)
- Configuration boot automatique

### Prochaines améliorations Phase 10
- [ ] ESPHome deployment script (firmware ESP32 custom)
- [ ] Scrypted deployment script (NVR caméras IP)
- [ ] Home Assistant Supervisor (addons management)
- [ ] Grafana dashboard Home Assistant metrics
- [ ] Backup automatique Home Assistant config

---

### Améliorations Futures (Optionnelles)

- [ ] Nextcloud Office (Collabora) one-click deploy
- [x] ✅ qBittorrent (Phase 16 - terminé)
- [ ] Authentik (alternative Authelia avec OAuth2/SAML)
- [x] ✅ Pi-hole (Phase 11 - DNS ad-blocking, terminé)
- [x] ✅ Vaultwarden (Phase 12 - password manager, terminé)
- [x] ✅ Immich (Phase 13 - Google Photos alternative, terminé)
- [x] ✅ Paperless-ngx (Phase 14 - document management, terminé)

### Documentation Globale
- [x] ✅ ROADMAP.md complet avec 23 phases terminées (100%)
- [x] ✅ REORGANISATION-PLAN.md (v5.0 - structure par catégories)
- [x] ✅ APPLICATIONS-IA-RECOMMANDEES.md (recherche AI pour Pi 5)
- [x] ✅ DOCUMENTATION-GUIDE-GEMINI.md (guide documentation)
- [x] ✅ HEBERGER-SITE-WEB.md (guide hébergement applications web)
- [ ] README.md principal avec progression finale
- [ ] CONTRIBUTING.md pour contributions externes
- [ ] CHANGELOG.md pour historique versions

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

**Dernière mise à jour**: 2025-10-05
**Version**: 5.0 - 🎉 23 PHASES TERMINÉES ! 🏆
**Mainteneur**: [@iamaketechnology](https://github.com/iamaketechnology)

---

## ✅ Phase 11 - Pi-hole (TERMINÉ)

**Stack**: Pi-hole
**Statut**: ✅ Production Ready
**Dossier**: `01-infrastructure/pihole/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Bloqueur de publicités réseau
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide DNS configuration

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/pihole/scripts/01-pihole-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Pi-hole** (bloqueur DNS)
- **Docker** (containerisation)
- **Port 53** (DNS)

### Statistiques
- **RAM** : ~50 MB
- **Temps installation** : 5 min
- **Use case** : Bloquer pubs sur tout le réseau

---
## ✅ Phase 12 - Vaultwarden (TERMINÉ)

**Stack**: Vaultwarden
**Statut**: ✅ Production Ready
**Dossier**: `02-securite/passwords/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Password manager (Bitwarden self-hosted)
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Vaultwarden** (serveur Bitwarden)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~50 MB
- **Temps installation** : 3 min
- **Use case** : Remplacer LastPass/1Password

---
## ✅ Phase 13 - Immich (TERMINÉ)

**Stack**: Immich
**Statut**: ✅ Production Ready
**Dossier**: `10-productivity/immich/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Google Photos alternative avec AI
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/immich/scripts/01-immich-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Immich** (photo management)
- **Docker** (containerisation)
- **PostgreSQL** (database)

### Statistiques
- **RAM** : ~500 MB
- **Temps installation** : 10 min
- **Use case** : Backup photos + reconnaissance faciale

---
## ✅ Phase 14 - Paperless-ngx (TERMINÉ)

**Stack**: Paperless-ngx
**Statut**: ✅ Production Ready
**Dossier**: `10-productivity/paperless-ngx/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Gestion documents avec OCR
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/paperless-ngx/scripts/01-paperless-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Paperless-ngx** (document management)
- **Docker** (containerisation)
- **Redis** (cache)

### Statistiques
- **RAM** : ~300 MB
- **Temps installation** : 5 min
- **Use case** : Scanner → OCR → Archivage

---
## ✅ Phase 15 - Uptime Kuma (TERMINÉ)

**Stack**: Uptime Kuma
**Statut**: ✅ Production Ready
**Dossier**: `03-monitoring/uptime-kuma/`
**Priorité**: 🔴 HAUTE

### Réalisations
- [x] Monitoring uptime services
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Uptime Kuma** (monitoring)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~100 MB
- **Temps installation** : 3 min
- **Use case** : Notifications si service down

---
## ✅ Phase 16 - qBittorrent (TERMINÉ)

**Stack**: qBittorrent
**Statut**: ✅ Production Ready
**Dossier**: `06-media/qbittorrent/`
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Client torrent avec WebUI
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/qbittorrent/scripts/01-qbittorrent-deploy.sh | sudo bash
```

### Technologies Utilisées
- **qBittorrent** (client torrent)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~150 MB
- **Temps installation** : 3 min
- **Use case** : Complémentaire Radarr/Sonarr

---
## ✅ Phase 17 - Joplin Server (TERMINÉ)

**Stack**: Joplin Server
**Statut**: ✅ Production Ready
**Dossier**: `10-productivity/joplin/`
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Serveur de notes synchronisées
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/10-productivity/joplin/scripts/01-joplin-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Joplin Server** (notes sync)
- **Docker** (containerisation)
- **PostgreSQL** (database)

### Statistiques
- **RAM** : ~100 MB
- **Temps installation** : 5 min
- **Use case** : Alternative Evernote

---
## ✅ Phase 18 - Syncthing (TERMINÉ)

**Stack**: Syncthing
**Statut**: ✅ Production Ready
**Dossier**: `05-stockage/syncthing/`
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Sync fichiers P2P
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/syncthing/scripts/01-syncthing-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Syncthing** (file sync)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~80 MB
- **Temps installation** : 3 min
- **Use case** : Alternative Dropbox sync

---
## ✅ Phase 19 - Calibre-Web (TERMINÉ)

**Stack**: Calibre-Web
**Statut**: ✅ Production Ready
**Dossier**: `06-media/calibre-web/`
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Bibliothèque ebooks
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/calibre-web/scripts/01-calibre-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Calibre-Web** (ebook library)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~100 MB
- **Temps installation** : 3 min
- **Use case** : Alternative Kindle

---
## ✅ Phase 20 - Navidrome (TERMINÉ)

**Stack**: Navidrome
**Statut**: ✅ Production Ready
**Dossier**: `06-media/navidrome/`
**Priorité**: 🟡 Moyenne

### Réalisations
- [x] Serveur streaming musical
- [x] Script idempotent complet
- [x] Détection Traefik (DuckDNS/Cloudflare/VPN)
- [x] Intégration Homepage automatique
- [x] Guide de démarrage

### Ce qui fonctionne
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/navidrome/scripts/01-navidrome-deploy.sh | sudo bash
```

### Technologies Utilisées
- **Navidrome** (music streaming)
- **Docker** (containerisation)

### Statistiques
- **RAM** : ~100 MB
- **Temps installation** : 3 min
- **Use case** : Alternative Spotify self-hosted

---

## ✅ Phase 21 - Ollama + Open WebUI (TERMINÉ) 🤖

**Stack**: Ollama + Open WebUI
**Statut**: ✅ Production Ready
**Dossier**: `11-intelligence-artificielle/ollama/`
**Priorité**: 🔴 HAUTE
**Temps installation**: 15-20 min (+ 5-10 min téléchargement modèle)

### Réalisations

- [x] ✅ **Script 01-ollama-deploy.sh** - LLM Self-Hosted complet (500+ lignes)
- [x] ✅ Ollama (serveur LLM) + Open WebUI (interface type ChatGPT)
- [x] ✅ Vérification RAM (minimum 8GB recommandé)
- [x] ✅ Vérification architecture ARM64
- [x] ✅ Menu interactif choix modèle (TinyLlama, Phi-3, DeepSeek-Coder)
- [x] ✅ Auto-détection Traefik (3 scénarios)
- [x] ✅ Intégration Homepage automatique
- [x] ✅ Guide d'utilisation complet (USAGE.md - 400+ lignes)
- [x] ✅ API compatible OpenAI

### Ce qui fonctionne

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/ollama/scripts/01-ollama-deploy.sh | sudo bash
```

**Résultat selon scénario Traefik** :
- **DuckDNS**: `https://ai.monpi.duckdns.org`
- **Cloudflare**: `https://ai.mondomaine.com`
- **VPN**: `https://ai.pi.local`
- **Sans Traefik**: `http://raspberrypi.local:3000`

**API Ollama** : Port 11434

### Technologies Utilisées (100% Open Source & Gratuit)

**Ollama** (MIT License)
- Serveur LLM local (type ChatGPT)
- 100% ARM64 compatible (natif Raspberry Pi 5)
- API compatible OpenAI
- Quantization Q4/Q5 pour performance Pi

**Open WebUI** (MIT License)
- Interface Web moderne (ChatGPT-like)
- Multi-utilisateurs
- Historique conversations
- Import/export chats
- Markdown + code syntax highlighting

### Modèles Recommandés Pi 5

**Légers (< 1GB)** - Ultra-rapide :
- `tinyllama:1.1b` (600MB) → Questions simples, 8-10 tokens/sec
- `deepseek-coder:1.3b` (800MB) → Spécialisé code, 6-8 tokens/sec

**Équilibrés (2-4GB)** - Meilleur rapport qualité/vitesse ⭐ :
- `phi3:3.8b` (2.3GB) → Usage général, 3-5 tokens/sec
- `qwen2.5-coder:3b` (2GB) → Code + raisonnement

**Avancés (7GB+)** - Lent sur Pi 5 :
- `llama3:7b` (4GB) → Qualité GPT-3.5, 1-2 tokens/sec
- `mistral:7b` (4GB) → Excellent français

### Fonctionnalités Clés

**Ollama** :
- API REST compatible OpenAI
- Multi-modèles simultanés
- Streaming responses
- Context window configurable
- Téléchargement modèles on-demand

**Open WebUI** :
- Interface drag & drop upload documents
- RAG (Retrieval Augmented Generation)
- Code execution
- Image generation (DALL-E compatible)
- Voice input (Speech-to-Text)
- Plugins & extensions
- Dark/Light mode

### Use Cases Réels

1. **Chat privé local** : Alternative ChatGPT sans cloud, privacy 100%
2. **Génération code** : Prompt → code Python/JS/bash
3. **Debug code** : Coller erreur → explication + fix
4. **Résumé documents** : Upload PDF → résumé 3 points clés
5. **Traduction** : Texte anglais → français
6. **Q&A sur docs** : RAG sur documentation locale
7. **Brainstorming** : Idées projet, noms variables, architecture

### Performance Raspberry Pi 5

| Modèle | Taille | Tokens/sec | RAM Utilisée | Use Case |
|--------|--------|------------|--------------|----------|
| tinyllama:1.1b | 600MB | 8-10 | ~1GB | Questions simples, rapide |
| phi3:3.8b | 2.3GB | 3-5 | ~3GB | Usage général ⭐ |
| deepseek-coder:1.3b | 800MB | 6-8 | ~1.5GB | Code seulement |
| llama3:7b | 4GB | 1-2 | ~6GB | Qualité maximale, lent |

### API Ollama

**Compatible OpenAI** :
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "phi3:3.8b",
  "prompt": "Pourquoi le ciel est bleu ?"
}'
```

**Intégration Python** :
```python
import requests

response = requests.post('http://localhost:11434/api/generate', json={
    'model': 'phi3:3.8b',
    'prompt': 'Explique Docker en 2 phrases'
})
```

### Intégrations Possibles

**VSCode (Continue.dev)** :
- Extension Continue
- Connexion Ollama local
- Autocomplétion code IA

**n8n (Phase 22)** :
- Node Ollama disponible
- Workflows automatisés + IA

**Python/JS** :
- API REST standard
- Libraries : `ollama-python`, `ollama-js`

### Scripts Créés

**01-ollama-deploy.sh** (500+ lignes)
- Vérification RAM (8GB min)
- Vérification architecture ARM64
- Déploiement Ollama + Open WebUI Docker
- Menu interactif choix modèle
- Auto-détection Traefik (labels dynamiques)
- Téléchargement modèle recommandé
- Intégration Homepage automatique
- Création guide USAGE.md

### Statistiques
- **RAM** : ~2-4 GB (selon modèle chargé)
- **Stockage** : 600MB - 7GB (selon modèles)
- **CPU** : ARM Cortex-A76 (Pi 5)
- **Temps réponse** : 3-10s (selon modèle + longueur)

### Prochaines améliorations Phase 21
- [ ] Automatic1111 (Stable Diffusion images - très lent Pi 5)
- [ ] LocalAI (alternative Ollama multi-modal)
- [ ] Tabby (code completion server)
- [ ] Integration avec Continue.dev (VSCode extension)

---

## ✅ Phase 22 - n8n Workflow Automation (TERMINÉ) 🔄

**Stack**: n8n
**Statut**: ✅ Production Ready
**Dossier**: `11-intelligence-artificielle/n8n/`
**Priorité**: 🔴 HAUTE
**Temps installation**: 5-10 min

### Réalisations

- [x] ✅ **Script 01-n8n-deploy.sh** - Automatisation workflows + IA (300+ lignes)
- [x] ✅ n8n + PostgreSQL backend
- [x] ✅ Auto-détection Traefik (3 scénarios)
- [x] ✅ Intégration Homepage automatique
- [x] ✅ Génération encryption key sécurisée
- [x] ✅ Configuration webhook URL automatique
- [x] ✅ User management JWT secret

### Ce qui fonctionne

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/11-intelligence-artificielle/n8n/scripts/01-n8n-deploy.sh | sudo bash
```

**Résultat selon scénario Traefik** :
- **DuckDNS**: `https://n8n.monpi.duckdns.org`
- **Cloudflare**: `https://n8n.mondomaine.com`
- **VPN**: `https://n8n.pi.local`
- **Sans Traefik**: `http://raspberrypi.local:5678`

### Technologies Utilisées (100% Open Source & Gratuit)

**n8n** (Sustainable Use License)
- Automatisation workflows no-code
- 500+ intégrations natives
- Drag & drop interface
- Self-hosted (alternative Zapier/Make)

**PostgreSQL** (PostgreSQL License)
- Base de données workflows
- Historique executions
- Credentials sécurisés

### Fonctionnalités Clés

**Workflows Visuels** :
- Interface drag & drop
- 500+ nodes (API, services, IA)
- Conditions (if/else)
- Loops & iterations
- Error handling
- Retry logic

**Intégrations IA Natives** :
- **OpenAI** (GPT-4, DALL-E, Whisper)
- **Anthropic** (Claude)
- **Ollama** (local - Phase 21)
- **Hugging Face** (modèles open source)
- **Pinecone** (vector database)
- **Qdrant** (vector search)

**Intégrations Populaires** :
- **Notifications** : Discord, Slack, Telegram, Email, Webhooks
- **Cloud** : Google Drive, Dropbox, OneDrive
- **Databases** : PostgreSQL, MySQL, MongoDB, Redis, Supabase
- **Calendars** : Google Calendar, Outlook
- **CRM** : Airtable, Notion
- **Home Assistant** (Phase 10)

### Use Cases Réels

1. **OCR + Résumé IA** :
   - Webhook reçoit image → OCR → Ollama résumé → Email

2. **Monitoring automatisé** :
   - Cron → Check URL → Si erreur → Notification Discord + Telegram

3. **Traitement documents** :
   - Google Drive nouveau PDF → OCR → Extraction données → PostgreSQL

4. **Chatbot personnalisé** :
   - Webhook → Ollama/OpenAI → Réponse personnalisée → Discord/Slack

5. **ETL avec IA** :
   - Source API → Transform (Ollama enrichissement) → Load PostgreSQL

6. **Automatisation domotique** :
   - MQTT sensor → Condition → Home Assistant action → Notification

7. **Backup automatique** :
   - Cron → Export Supabase → Encrypt → Upload Cloudflare R2

### Workflows Templates Disponibles

- **Telegram Bot** : Bot IA conversationnel
- **RSS → Email** : Veille automatisée
- **Image OCR** : Extraction texte images
- **Sentiment Analysis** : Analyse sentiment textes
- **Data Pipeline** : ETL automatisé
- **API Monitoring** : Health checks services
- **Content Generation** : Blog posts IA

### Performance Raspberry Pi 5

| Workflow Type | RAM | CPU | Temps Execution |
|--------------|-----|-----|-----------------|
| Simple (2-3 nodes) | ~200MB | Low | <1s |
| Moyen (5-10 nodes) | ~250MB | Medium | 1-5s |
| Complexe (20+ nodes) | ~300MB | High | 5-30s |
| Avec Ollama | +2GB | High | +3-10s (LLM) |

### Scripts Créés

**01-n8n-deploy.sh** (300+ lignes)
- Déploiement n8n + PostgreSQL Docker
- Génération encryption key (openssl rand)
- Génération JWT secret sécurisé
- Configuration webhook URL automatique (selon Traefik)
- Auto-détection Traefik (labels dynamiques)
- Health check PostgreSQL
- Intégration Homepage automatique
- Variables environnement sécurisées (.env chmod 600)

### Statistiques
- **RAM** : ~200 MB (n8n) + ~50 MB (PostgreSQL)
- **Stockage** : ~500 MB
- **CPU** : Faible (sauf workflows complexes)
- **Ports** : 5678 (WebUI)

### Prochaines améliorations Phase 22
- [ ] Templates workflows pré-configurés (Ollama, Home Assistant, Backup)
- [ ] Integration Cloudflare R2 backup automatique
- [ ] Workflow monitoring dashboard (Grafana)
- [ ] n8n CLI setup automatisé

---

## ✅ Phase 23 - Voice Assistant Whisper + Piper (TERMINÉ) 🎤

**Stack**: Whisper + Piper (Wyoming Protocol)
**Statut**: ✅ Production Ready
**Dossier**: `07-domotique/homeassistant/`
**Priorité**: 🔴 HAUTE (si domotique installée)
**Temps installation**: 5 min
**Pré-requis**: Phase 10 (Home Assistant)

### Réalisations

- [x] ✅ **Script 05-voice-assistant-deploy.sh** - Voice assistant addon (250+ lignes)
- [x] ✅ Whisper (Speech-to-Text) optimisé Pi 5
- [x] ✅ Piper (Text-to-Speech) voix française naturelle
- [x] ✅ Vérification Home Assistant installé
- [x] ✅ Ajout services au docker-compose.yml existant
- [x] ✅ Guide configuration Home Assistant (VOICE-ASSISTANT-SETUP.md)
- [x] ✅ 100% local (privacy)

### Ce qui fonctionne

**Pré-requis** : Phase 10 (Home Assistant) déjà installée

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/05-voice-assistant-deploy.sh | sudo bash
```

**Configuration Home Assistant** :
1. Settings → Devices & Services → Add Integration
2. Rechercher "Wyoming Protocol"
3. Ajouter Whisper (host: `whisper`, port: 10300)
4. Ajouter Piper (host: `piper`, port: 10200)
5. Settings → Voice Assistants → Add Assistant
6. Configurer STT (Whisper) + TTS (Piper)

### Technologies Utilisées (100% Open Source & Gratuit)

**Whisper** (MIT License - OpenAI)
- Speech-to-Text (reconnaissance vocale)
- Modèles optimisés ARM64
- Français natif
- Précision excellente

**Piper** (MIT License)
- Text-to-Speech (synthèse vocale)
- Voix françaises naturelles
- Qualité studio
- Rapide (<2s audio/sec)

**Wyoming Protocol** (MIT License)
- Protocole standard Home Assistant
- Communication STT/TTS
- Intégration native

### Fonctionnalités Clés

**Whisper (STT)** :
- Reconnaissance vocale locale
- Multi-langues (français prioritaire)
- Modèles tiny/base/small
- Précision ~95%+ (modèle base)

**Piper (TTS)** :
- Voix françaises naturelles
- Qualité studio
- Génération temps réel
- Voix masculine/féminine disponibles

**Integration Home Assistant** :
- Commandes vocales ("Allume salon")
- Réponses vocales
- Automatisations avec TTS
- Micro interface Home Assistant

### Modèles Disponibles

**Whisper (STT)** :
- `tiny` ⭐ - Rapide (~8s sur Pi 5), français correct
- `base` - Plus précis (~15s), meilleur français
- `small` - Très précis, très lent Pi 5 (non recommandé)

**Piper (TTS)** :
- `fr_FR-siwis-medium` ⭐ - Voix féminine naturelle
- `fr_FR-upmc-medium` - Voix masculine
- `fr_FR-siwis-low` - Plus rapide, qualité moindre

### Use Cases Réels

1. **Commande vocale domotique** :
   - "Allume le salon" → Whisper → Home Assistant → Lumières

2. **Notifications vocales** :
   - Mouvement détecté → Automation → Piper → "Mouvement détecté salon"

3. **Assistant vocal complet** :
   - Question vocale → Whisper → Home Assistant → Réponse → Piper

4. **Transcription audio** :
   - Audio → Whisper → Texte stocké

5. **Annonces maison** :
   - Automation → TTS → "La porte d'entrée est ouverte"

### Performance Raspberry Pi 5

| Service | Modèle | Temps Traitement | RAM Utilisée |
|---------|--------|------------------|--------------|
| Whisper | tiny | ~8s | ~200MB |
| Whisper | base | ~15s | ~400MB |
| Piper | medium | ~1.6s/sec audio | ~100MB |
| **Total** | tiny+medium | ~9.6s | ~300MB |

### Matériel Optionnel - ESPHome Satellite

**Pour micro/haut-parleur physique** :
- ESP32-S3 (~10€)
- Micro INMP441
- Haut-parleur MAX98357A
- Flasher ESPHome voice config
- Assistant vocal physique dans chaque pièce !

**Guide officiel** : [13$ Voice Remote](https://www.home-assistant.io/voice_control/thirteen-usd-voice-remote/)

### Scripts Créés

**05-voice-assistant-deploy.sh** (250+ lignes)
- Vérification Home Assistant installé
- Ajout services Whisper + Piper au docker-compose.yml existant
- Backup docker-compose.yml automatique
- Redémarrage stack Home Assistant
- Création guide configuration (VOICE-ASSISTANT-SETUP.md)
- Instructions intégration Wyoming Protocol
- Liste modèles disponibles
- Troubleshooting guide

### Statistiques
- **RAM** : ~300 MB (Whisper tiny + Piper medium)
- **Stockage** : ~1.5 GB (modèles)
- **Ports** : 10300 (Whisper), 10200 (Piper)
- **Temps réponse** : ~10s total (reconnaissance + synthèse)

### Prochaines améliorations Phase 23
- [ ] Speech-to-Phrase (alternative Whisper, <1s)
- [ ] Wake word detection (Hey Assistant)
- [ ] ESPHome satellite script automatisé
- [ ] Multi-room audio synchronisé

---

**Dernière mise à jour**: 2025-10-05
**Version**: 5.0 - 🎉 23 PHASES TERMINÉES ! 🏆
**Mainteneur**: [@iamaketechnology](https://github.com/iamaketechnology)
