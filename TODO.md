# 📋 TODO - Roadmap PI5-SETUP

> **Suivi des phases de développement et déploiement**
> Dernière mise à jour : 2025-10-12

---

## 📊 État Global

**Pi Production** : `pi@192.168.1.74`
**Architecture** : Raspberry Pi 5 (16GB RAM, 64GB SD)
**OS** : Raspberry Pi OS Bookworm 64-bit

**Ressources Actuelles** :
- RAM : 1.5 GB / 16 GB (9% utilisé)
- Stockage : 9 GB / 57 GB (17% utilisé)
- Containers actifs : 14 (Supabase: 10, Traefik: 1, DuckDNS: 1, Portainer: 1, Homepage: 1)

---

## ✅ PHASES COMPLÉTÉES

### Phase 1 : Backend (Supabase) ✅ TERMINÉ
**Status** : Déployé et opérationnel (10 containers healthy)
**Déployé le** : Oct 2024
**Services** :
- [x] PostgreSQL 15 + extensions
- [x] Auth (GoTrue)
- [x] REST API (PostgREST)
- [x] Realtime (WebSocket)
- [x] Storage (S3-compatible)
- [x] Studio UI
- [x] Edge Functions (Deno)
- [x] Kong API Gateway

**Accès** :
- Studio : https://pimaketechnology.duckdns.org/project/default (via Traefik)
- Studio (direct) : http://192.168.1.74:3000
- API : https://pimaketechnology.duckdns.org/api (via Traefik)
- API (direct) : http://192.168.1.74:8001
- PostgreSQL : 192.168.1.74:5432

**Documentation** :
- [x] supabase-guide.md (créé par Gemini - à valider)
- [x] supabase-setup.md (créé par Gemini - à valider)

---

### Phase 2 : Reverse Proxy (Traefik + DuckDNS) ✅ TERMINÉ
**Status** : Déployé et opérationnel (2 containers healthy)
**Déployé le** : Oct 2024
**Scénario** : DuckDNS (gratuit)

**Services** :
- [x] Traefik v3.3 (reverse proxy)
- [x] DuckDNS (DNS auto-update)
- [x] Certificats SSL Let's Encrypt (HTTP-01)
- [x] Routing path-based (/home, /project, /api)

**Fix appliqués** : 2025-10-12
- [x] Healthcheck Traefik (ping activé)
- [x] Healthcheck DuckDNS (log path corrigé)
- [x] Dashboard localhost-only (PathPrefix non supporté par Traefik v3)

**Accès** :
- Dashboard Traefik : http://localhost:8081/dashboard/ (localhost only, SSH tunnel required)
- HTTP : Port 80
- HTTPS : Port 443

**Documentation** :
- [x] traefik-guide.md (mis à jour v4.1.3 - dashboard localhost limitation)
- [x] traefik-setup.md (mis à jour v4.1.3 - SSH tunnel instructions)
- [x] SCENARIOS-COMPARISON.md (existe)

---

### Phase 8 : Interface Docker (Portainer) ✅ TERMINÉ
**Status** : Déployé et opérationnel (1 container)
**Déployé le** : Oct 2024

**Services** :
- [x] Portainer CE (Community Edition)

**Accès** :
- UI : http://192.168.1.74:8080 ⚠️ **Port correct : 8080** (pas 9000)
- Note : Port 8080 mappé vers port interne 9000

**Scripts créés** :
- [x] reset-portainer-password.sh (2025-10-12)

**Documentation** :
- [ ] portainer-guide.md (TODO)
- [ ] portainer-setup.md (TODO)

---

## 🚧 PHASES EN COURS

### Phase 0 : Infrastructure Email ⚠️ SCRIPTS PRÊTS
**Status** : Scripts créés, non déployé
**Location** : `01-infrastructure/email/`

**Scripts disponibles** :
- [x] 01-roundcube-deploy-external.sh (Gmail/Outlook/Proton)
- [x] 01-roundcube-deploy-full.sh (serveur mail complet)
- [x] Compose files (external + full)
- [x] Config templates

**Documentation** :
- [x] email-guide.md
- [x] email-setup.md
- [x] GUIDE-EMAIL-CHOICES.md
- [x] QUICK-START.md

**À faire** :
- [ ] Décider scénario (externe vs complet)
- [ ] Déployer sur le Pi
- [ ] Tester envoi/réception emails
- [ ] Intégrer avec Traefik (HTTPS)

**Estimation déploiement** : 10-15 minutes

---

### Phase 0b : Déploiement Apps (React/Next.js) ⚠️ SCRIPTS PRÊTS
**Status** : Stack créée, non déployée
**Location** : `01-infrastructure/apps/`

**Scripts disponibles** :
- [x] 01-apps-setup.sh (initialisation)
- [x] deploy-nextjs-app.sh
- [x] deploy-react-spa.sh
- [x] Templates Docker (Next.js SSR, React SPA, Node API)
- [x] Gitea Actions workflows

**Documentation** :
- [x] apps-guide.md ⭐ EXCELLENT
- [x] apps-setup.md

**À faire** :
- [ ] Initialiser structure /opt/apps/
- [ ] Déployer première app de test
- [ ] Tester intégration Supabase
- [ ] Tester intégration Traefik

**Estimation déploiement** : 15-20 minutes

---

## 📅 PHASES À VENIR (Priorité)

### Phase 2b : Homepage Dashboard ✅ TERMINÉ
**Status** : Déployé et opérationnel (1 container)
**Déployé le** : 2025-10-12
**Location** : `08-interface/homepage/`

**Objectif** : Dashboard visuel pour tous les services

**Services** :
- [x] Homepage (gethomepage.dev)
- [x] Auto-détection Supabase, Traefik, Portainer
- [x] Widgets monitoring léger
- [x] Intégration Traefik (HTTPS)

**Accès** :
- URL : http://192.168.1.74:3001 (accès direct local)
- Note : Pas d'accès via Traefik (Next.js incompatible avec path-based routing + stripprefix)

**Fixes appliqués** :
- [x] YAML backticks escaping (v1.0.1)
- [x] Port 3000 conflict avec Supabase Studio (changed to 3001)
- [x] Healthcheck IPv4 (`127.0.0.1` + `/api/healthcheck`)
- [x] Removed Traefik integration (Next.js base path incompatibility)

**Documentation existante** :
- [x] homepage-guide.md ⭐ TRÈS BON
- [ ] homepage-setup.md (TODO)

**Script** :
- [x] 01-homepage-deploy.sh (testé et corrigé)

---

### Phase 3 : Monitoring (Prometheus + Grafana) 🎯 PRIORITÉ HAUTE
**Status** : Non déployé
**Location** : `03-monitoring-observabilite/monitoring/`
**Estimation** : 10-15 minutes

**Objectif** : Surveillance complète système et containers

**Services** :
- [ ] Prometheus (métriques)
- [ ] Grafana (dashboards)
- [ ] Node Exporter (métriques système)
- [ ] cAdvisor (métriques Docker)
- [ ] Dashboards pré-configurés :
  - [ ] Raspberry Pi (CPU, RAM, température, disque)
  - [ ] Docker containers (consommation ressources)
  - [ ] Supabase PostgreSQL (connexions, queries)

**Documentation existante** :
- [x] monitoring-guide.md (créé par Gemini - à valider)
- [x] monitoring-setup.md (créé par Gemini - à valider)

**Pourquoi maintenant ?** :
- Établir baseline performance (9% RAM actuel)
- Alertes proactives (container down, RAM >80%, disque >90%)
- Visualiser tendances long terme

**Prochaines actions** :
1. [ ] Vérifier script de déploiement
2. [ ] Déployer stack monitoring
3. [ ] Configurer dashboards
4. [ ] Tester alertes
5. [ ] Intégrer avec Traefik (HTTPS)

**Consommation estimée** : ~400 MB RAM

---

### Phase 6 : Backups Offsite 🎯 PRIORITÉ MOYENNE
**Status** : Non déployé
**Location** : `06-sauvegarde/backup-offsite/`
**Estimation** : 15-20 minutes

**Objectif** : Sauvegardes automatiques cloud

**Services** :
- [ ] rclone (outil sync cloud)
- [ ] Configuration Cloudflare R2 (gratuit 10GB)
- [ ] Rotation GFS (Grandfather-Father-Son)
- [ ] Cron automatique (daily/weekly/monthly)

**Sauvegardes** :
- [ ] Base de données Supabase
- [ ] Volumes Docker (storage, auth, etc.)
- [ ] Configurations (/home/pi/stacks/)
- [ ] Logs critiques

**Documentation existante** :
- [x] backup-guide.md (créé par Gemini - à valider)
- [x] backup-setup.md (créé par Gemini - à valider)

**Pourquoi maintenant ?** :
- Data importante dans Supabase
- Prévention perte de données (SD card corruption)
- Stratégie 3-2-1 (3 copies, 2 médias, 1 offsite)

**Prochaines actions** :
1. [ ] Créer compte Cloudflare R2
2. [ ] Configurer rclone
3. [ ] Tester backup manuel
4. [ ] Configurer cron automatique
5. [ ] Tester restauration

**Consommation estimée** : ~50 MB RAM, variable stockage

---

### Phase 4 : VPN (Tailscale) 🎯 PRIORITÉ BASSE
**Status** : Non déployé
**Location** : `01-infrastructure/vpn-wireguard/`
**Estimation** : 5-10 minutes

**Objectif** : Accès sécurisé depuis l'extérieur

**Services** :
- [ ] Tailscale (VPN zero-config)
- [ ] Alternative WireGuard (si préféré)

**Documentation existante** :
- [x] vpn-guide.md (créé par Gemini - à valider)
- [x] vpn-setup.md (créé par Gemini - à valider)

**Pourquoi plus tard ?** :
- DuckDNS + HTTPS déjà fonctionnel
- Pas urgent si accès local suffit
- Utile si besoin accès mobile sécurisé

**Prochaines actions** :
1. [ ] Créer compte Tailscale
2. [ ] Installer sur Pi
3. [ ] Installer clients (Android, iOS, Desktop)
4. [ ] Tester connexion distante

**Consommation estimée** : ~30 MB RAM

---

### Phase 5 : Git Self-Hosted (Gitea) 🎯 PRIORITÉ BASSE
**Status** : Non déployé
**Location** : `04-developpement/gitea/`
**Estimation** : 15-20 minutes

**Objectif** : Git + CI/CD self-hosted

**Services** :
- [ ] Gitea (Git server)
- [ ] PostgreSQL (database)
- [ ] Gitea Actions (CI/CD runners)

**Documentation existante** :
- [x] gitea-guide.md (créé par Gemini - à valider)

**Pourquoi plus tard ?** :
- GitHub fonctionne bien actuellement
- CI/CD optionnel pour début
- Consomme ressources (300 MB RAM)

**Prochaines actions** :
1. [ ] Décider si nécessaire (vs GitHub)
2. [ ] Déployer Gitea + PostgreSQL
3. [ ] Créer repository test
4. [ ] Configurer runner CI/CD
5. [ ] Tester workflow (build, deploy)

**Consommation estimée** : ~300 MB RAM

---

## 🔮 PHASES FUTURES (Roadmap Long Terme)

### Phase 7 : Stockage Cloud (Nextcloud/FileBrowser)
**Status** : Planifié
**Location** : `05-stockage/`

**Options** :
- [ ] Nextcloud (full featured, ~1.5 GB RAM)
- [ ] FileBrowser (léger, ~50 MB RAM)

**Pourquoi plus tard ?** : Besoin de définir use case

---

### Phase 9 : Média Server (Jellyfin + *arr)
**Status** : Planifié
**Location** : `07-multimedia/`

**Services** :
- [ ] Jellyfin (média server)
- [ ] Sonarr (TV shows)
- [ ] Radarr (movies)
- [ ] Bazarr (subtitles)
- [ ] Prowlarr (indexer)
- [ ] Transmission (torrent)

**Documentation existante** :
- [x] jellyfin-guide.md (créé par Gemini - à valider)
- [x] jellyfin-setup.md (créé par Gemini - à valider)

**Pourquoi plus tard ?** : Consomme beaucoup de ressources (~2-3 GB RAM)

---

### Phase 10 : Domotique (Home Assistant)
**Status** : Planifié
**Location** : `02-domotique/`

**Services** :
- [ ] Home Assistant
- [ ] ESPHome
- [ ] Zigbee2MQTT
- [ ] Node-RED
- [ ] MQTT Broker

**Pourquoi plus tard ?** : Nécessite matériel IoT

---

### Phase 11 : Analytics (Plausible/Matomo)
**Status** : Planifié
**Location** : `09-analytics-seo/`

**Pourquoi plus tard ?** : Nécessite sites web/apps déployés d'abord

---

### Phase 12 : Marketing (Listmonk)
**Status** : Planifié
**Location** : `10-marketing-commerce/`

**Pourquoi plus tard ?** : Use case spécifique

---

### Phase 13 : AI Local (Ollama)
**Status** : Planifié
**Location** : `11-intelligence-artificielle/`

**Services** :
- [ ] Ollama (LLM local)

**Limitations** :
- Pi 5 ARM64 = performances limitées
- Modèles légers seulement (Llama 3.2 3B)
- Consommation RAM élevée (~4-8 GB)

**Pourquoi plus tard ?** : Consomme 50% de la RAM disponible

---

## 🛠️ TÂCHES TECHNIQUES TRANSVERSALES

### Documentation (En Cours)
**Status** : Gemini a généré 15 fichiers, à valider

**Fichiers générés** :
- [x] supabase-guide.md + supabase-setup.md
- [x] traefik-guide.md + traefik-setup.md
- [x] monitoring-guide.md + monitoring-setup.md
- [x] vpn-guide.md + vpn-setup.md
- [x] pihole-guide.md + pihole-setup.md
- [x] jellyfin-guide.md + jellyfin-setup.md
- [x] backup-guide.md + backup-setup.md
- [x] gitea-guide.md

**À faire** :
- [ ] Valider contenu (erreurs, incohérences)
- [ ] Corriger architecture issues
- [ ] Vérifier liens internes
- [ ] Tester instructions déploiement
- [ ] Compléter fichiers manquants (19 stacks restants)

**Plan complet** : Voir [PLAN-DOCUMENTATION-GEMINI.md](PLAN-DOCUMENTATION-GEMINI.md)

---

### Scripts & Maintenance
**Status** : À améliorer

**Scripts existants** :
- [x] common-scripts/ (DevOps réutilisables)
- [x] Wrappers maintenance (backup, healthcheck, logs, update)

**À faire** :
- [ ] Créer wrappers pour stacks manquants
- [ ] Tester idempotence de tous les scripts
- [ ] Documenter workflow maintenance

---

### Architecture & Cohérence
**Status** : v4.0 (réorganisation terminée 2025-10-12)

**Achevé** :
- [x] Migration pi5-*-stack/ → catégories numérotées
- [x] Renommage GUIDE-DEBUTANT.md → <stack>-guide.md
- [x] Renommage INSTALL.md → <stack>-setup.md
- [x] Agent architecture-guardian créé
- [x] ARCHITECTURE.md créé
- [x] CLAUDE.md v4.0

**Audit actuel** :
- Conformité : 37% (11/30 stacks)
- Target : 100%

**À faire** :
- [ ] Relancer architecture-guardian après docs Gemini validées
- [ ] Viser 100% conformité

---

## 📊 PROCHAINES ACTIONS IMMÉDIATES

### Sprint 1 : Visibilité & Monitoring (Recommandé)
**Durée estimée** : 1 heure
**Impact** : Haute amélioration UX

1. [ ] Déployer Homepage Dashboard
   - Script : `08-interface/homepage/scripts/01-homepage-deploy.sh`
   - Test : http://192.168.1.74:[port]
   - Configurer widgets (Supabase, Traefik, Portainer)

2. [ ] Déployer Monitoring Stack
   - Script : `03-monitoring-observabilite/monitoring/scripts/01-monitoring-deploy.sh`
   - Test : Grafana http://192.168.1.74:[port]
   - Vérifier dashboards (Pi, Docker, Supabase)

3. [ ] Configurer Backups
   - Script : `06-sauvegarde/backup-offsite/scripts/01-rclone-setup.sh`
   - Cloudflare R2 account
   - Test backup manuel
   - Cron automatique

**Résultat attendu** : Visibilité complète + sauvegardes automatiques

---

### Sprint 2 : Déploiement Apps (Optionnel)
**Durée estimée** : 30 minutes
**Impact** : Dépend de ton besoin apps

1. [ ] Initialiser Apps Stack
   - Script : `01-infrastructure/apps/scripts/01-apps-setup.sh`

2. [ ] Déployer première app test
   - Next.js SSR ou React SPA
   - Test intégration Supabase
   - Test routing Traefik

**Résultat attendu** : Infrastructure prête pour héberger apps

---

### Sprint 3 : Email (Optionnel)
**Durée estimée** : 15 minutes
**Impact** : Si besoin emails

1. [ ] Choisir scénario (externe vs complet)
2. [ ] Déployer Roundcube
3. [ ] Tester envoi/réception
4. [ ] Intégrer Traefik

**Résultat attendu** : Webmail fonctionnel

---

## 📝 Notes & Décisions

### Décisions Architecture
- **2025-10-12** : Réorganisation v4.0 (catégories numérotées)
- **2025-10-12** : Fix healthchecks Traefik/DuckDNS
- **2025-10-12** : Script reset Portainer créé
- **2025-10-12** : Plan documentation Gemini créé

### Décisions Techniques
- **DuckDNS** : Choisi pour scénario gratuit (vs Cloudflare)
- **Path-based routing** : /home, /studio, /api (vs subdomains)
- **Traefik Dashboard** : Localhost-only (limitation PathPrefix Traefik v3)
- **Portainer** : Interface Docker choisie (vs autre)
- **Homepage** : Port 3000 désactivé (conflit Supabase Studio)

### Questions en Suspens
- [ ] Email : Scénario externe ou complet ?
- [ ] Gitea : Nécessaire ou GitHub suffit ?
- [ ] Nextcloud vs FileBrowser : Quel besoin stockage ?
- [ ] VPN : Utilité réelle si DuckDNS fonctionne ?

---

## 🎯 Objectif Final

**Vision 2026** : Serveur Pi 5 complet, self-hosted, 100% fonctionnel

**Services cibles** :
- ✅ Backend (Supabase) - https://domain/project/default
- ✅ Reverse Proxy (Traefik + DuckDNS) - https://domain
- ✅ Dashboard (Homepage) - http://IP:3001 (local only)
- ✅ Interface Docker (Portainer) - http://IP:8080
- 🚧 Monitoring (Prometheus/Grafana)
- 🚧 Backups (rclone)
- 📅 VPN (Tailscale)
- 📅 Git (Gitea)
- 📅 Apps (React/Next.js)
- 📅 Email (Roundcube)
- 📅 Stockage (Nextcloud/FileBrowser)
- 📅 Média (Jellyfin)
- 📅 Domotique (Home Assistant)

**Philosophie** : 1 curl = 1 action, documentation pédagogique, scripts idempotents

---

**Dernière modification** : 2025-10-12 19:45
**Prochaine révision** : Après déploiement Monitoring
**Maintainer** : [@iamaketechnology](https://github.com/iamaketechnology)
