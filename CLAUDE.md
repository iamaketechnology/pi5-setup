# 🤖 Notes pour Claude (AI Assistant)

> **Ce fichier aide les futurs assistants AI à comprendre rapidement ce repository**

---

## 📋 Vue d'Ensemble du Projet

**Nom** : PI5-SETUP - Raspberry Pi 5 Development Server Setup
**But** : Installation automatisée et documentée d'un serveur de développement complet sur Raspberry Pi 5
**Philosophie** : **Installation en série - Une commande curl par étape, aucun git clone requis**
**Public** : Débutants à intermédiaires en self-hosting
**Architecture** : ARM64 (Raspberry Pi 5 spécifique)

---

## 🎯 Objectif Principal

Permettre à un utilisateur **novice** d'installer un serveur complet en copiant-collant des commandes dans le terminal, **étape par étape**, avec:
- ✅ Documentation pédagogique (analogies simples)
- ✅ Scripts idempotents (exécution multiple safe)
- ✅ Installation via SSH directe (curl/wget one-liners)
- ✅ Guides débutants systématiques
- ✅ 100% Open Source & Gratuit (quand possible)

---

## 🏗️ Architecture du Repository

### Structure par Catégories Numérotées

```
pi5-setup/
│
├── 📄 README.md                       # Vue d'ensemble + liens catégories
├── 📄 CLAUDE.md                       # Ce fichier (instructions AI)
├── 📄 ARCHITECTURE.md                 # Guide architecture pour contributeurs
├── 📄 ROADMAP.md                      # Vision 2025-2026
├── 📄 INSTALLATION-COMPLETE.md        # Parcours complet Pi neuf
│
├── 🔧 common-scripts/                 # Scripts DevOps réutilisables
│   ├── README.md
│   ├── lib.sh                         # Fonctions partagées
│   ├── 00-preflight-checks.sh
│   ├── 01-system-hardening.sh
│   ├── 02-docker-install-verify.sh
│   ├── 04-backup-rotate.sh            # GFS rotation
│   ├── 04b-restore-from-backup.sh
│   ├── 05-healthcheck-report.sh
│   ├── 06-update-and-rollback.sh
│   ├── 07-logs-collect.sh
│   ├── 08-scheduler-setup.sh
│   └── [autres scripts DevOps]
│
├── 📋 .templates/                     # Templates pour nouveaux stacks
│   ├── GUIDE-DEBUTANT-TEMPLATE.md
│   └── README.md
│
├── 🏗️ 01-infrastructure/              # Infrastructure de base
│   ├── README.md                      # Index stacks infra
│   ├── supabase/                      # Backend-as-a-Service (PostgreSQL + Auth + API)
│   ├── traefik/                       # Reverse proxy + HTTPS auto
│   ├── email/                         # Roundcube webmail (externe ou complet)
│   ├── apps/                          # Déploiement React/Next.js
│   ├── webserver/                     # Nginx/Apache
│   ├── vpn-wireguard/                 # Tailscale ou WireGuard
│   ├── pihole/                        # DNS ad-blocker
│   ├── external-access/               # Cloudflare Tunnel, ngrok
│   ├── appwrite/                      # Alternative Supabase
│   └── pocketbase/                    # BaaS léger
│
├── 🔐 02-securite/                    # Sécurité & authentification
│   ├── README.md
│   ├── authelia/                      # SSO + 2FA
│   └── passwords/                     # Vaultwarden (password manager)
│
├── 📊 03-monitoring/                  # Monitoring & observabilité
│   ├── README.md
│   ├── prometheus-grafana/            # Metrics + dashboards
│   └── uptime-kuma/                   # Uptime monitoring
│
├── 💻 04-developpement/               # Outils dev
│   ├── README.md
│   └── gitea/                         # Git self-hosted + CI/CD
│
├── 💾 05-stockage/                    # Stockage cloud
│   ├── README.md
│   ├── filebrowser-nextcloud/         # Cloud storage
│   └── syncthing/                     # Sync fichiers P2P
│
├── 🎬 06-media/                       # Serveurs média
│   ├── README.md
│   ├── jellyfin-arr/                  # Media server + automation
│   ├── navidrome/                     # Music server
│   ├── calibre-web/                   # eBooks
│   └── qbittorrent/                   # Torrent client
│
├── 🏠 07-domotique/                   # Home automation
│   ├── README.md
│   └── homeassistant/                 # Domotique centrale
│
├── 🖥️ 08-interface/                   # Dashboards & UI
│   ├── README.md
│   ├── homepage/                      # Dashboard centralisé
│   └── portainer/                     # Gestion Docker web
│
├── 💾 09-backups/                     # Sauvegardes
│   ├── README.md
│   └── restic-offsite/                # Backups cloud (rclone)
│
├── 📝 10-productivity/                # Productivité
│   ├── README.md
│   ├── immich/                        # Photos Google alternative
│   ├── paperless-ngx/                 # Gestion documents
│   └── joplin/                        # Notes
│
└── 🤖 11-intelligence-artificielle/   # AI & automation
    ├── README.md
    ├── n8n/                           # Workflow automation
    └── ollama/                        # LLM local
```

---

## 📐 Principes Architecture

### 1. **Structure Standard par Stack**

Chaque stack suit cette structure obligatoire :

```
<categorie>/<stack-name>/
├── README.md                   # Vue d'ensemble (français)
├── GUIDE-DEBUTANT.md           # Tutoriel pédagogique (analogies simples)
├── INSTALL.md                  # Instructions installation détaillées
├── scripts/
│   ├── 01-<stack>-deploy.sh    # Script principal (curl one-liner)
│   ├── 02-...sh                # Scripts complémentaires (optionnel)
│   ├── maintenance/            # Wrappers vers common-scripts
│   │   ├── _<stack>-common.sh  # Config wrapper
│   │   ├── <stack>-backup.sh
│   │   ├── <stack>-healthcheck.sh
│   │   ├── <stack>-update.sh
│   │   └── <stack>-logs.sh
│   └── utils/                  # Scripts utilitaires spécifiques
├── compose/                    # Docker Compose files
│   └── docker-compose.yml
├── config/                     # Templates configuration
└── docs/                       # Documentation supplémentaire (optionnel)
```

### 2. **Naming Convention**

✅ **BON** :
- `01-infrastructure/supabase/`
- `01-infrastructure/email/`
- `08-interface/portainer/`

❌ **MAUVAIS** (ancien, ne plus utiliser) :
- `pi5-supabase-stack/`
- `pi5-email-stack/`
- `portainer-stack/`

### 3. **Scripts Numérotés**

- `01-<stack>-deploy.sh` : Script principal déploiement
- `02-<action>.sh` : Scripts complémentaires
- Préfixe `_` pour scripts internes : `_<stack>-common.sh`

### 4. **Wrapper Pattern (Maintenance)**

Les scripts de maintenance délèguent à `common-scripts/` :

```bash
# 01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh
source _supabase-common.sh  # Config variables
exec ${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh "$@"
```

---

## 🔑 Stacks Principales (État Actuel)

### ✅ **01-infrastructure/** (CRITIQUE)

#### Supabase
- PostgreSQL 15 + Auth + API REST + Realtime + Storage
- RAM : ~1.2 GB
- Scripts : `01-prerequisites-setup.sh` → reboot → `02-supabase-deploy.sh`

#### Traefik
- Reverse proxy + HTTPS auto
- 3 scénarios : DuckDNS / Cloudflare / VPN
- RAM : ~100 MB
- Scripts : `01-traefik-deploy-duckdns.sh` (ou cloudflare/vpn)

#### Email
- Roundcube webmail
- 2 scénarios : Externe (Gmail/Outlook) ou Complet (Postfix+Dovecot+Rspamd)
- RAM : ~800 MB (externe) / ~1.5 GB (complet)
- Scripts : `01-roundcube-deploy-external.sh` ou `01-roundcube-deploy-full.sh`

#### Apps
- Déploiement React/Next.js/Node.js
- Templates Docker optimisés ARM64
- Intégration Traefik + Supabase automatique
- RAM : ~100-150 MB/app Next.js, ~10-20 MB/app React SPA
- Capacité Pi 5 16GB : 10-15 apps Next.js ou 20-30 React SPA
- Scripts : `01-apps-setup.sh` puis `deploy-nextjs-app.sh` / `deploy-react-spa.sh`

### ✅ **03-monitoring/** (RECOMMANDÉ)

#### Prometheus + Grafana
- Métriques système + Docker + apps
- Dashboards : Raspberry Pi, Containers, Supabase
- RAM : ~500 MB
- Script : `01-monitoring-deploy.sh`

### ✅ **08-interface/** (RECOMMANDÉ)

#### Homepage
- Dashboard centralisé auto-détection services
- Widgets système (CPU, RAM, température)
- RAM : ~80 MB
- Script : `01-homepage-deploy.sh`

#### Portainer
- Gestion Docker via web UI
- RAM : ~100 MB
- Script : `01-portainer-deploy.sh`

### ✅ **04-developpement/**

#### Gitea
- Git self-hosted + CI/CD (Gitea Actions)
- RAM : ~200 MB
- Script : `01-gitea-deploy.sh`

### ✅ **09-backups/**

#### Restic Offsite
- Backups cloud (rclone) : Cloudflare R2, Backblaze B2, AWS S3
- Rotation GFS automatique
- RAM : ~100 MB pendant backup
- Scripts : `01-rclone-setup.sh` → `02-enable-offsite-backups.sh`

---

## 🎓 Philosophie Documentation

### Guide Débutant Obligatoire

**Chaque stack DOIT avoir** : `GUIDE-DEBUTANT.md`

**Template** : `.templates/GUIDE-DEBUTANT-TEMPLATE.md`

**Contenu obligatoire** :
- **Analogies simples** (ex: reverse proxy = réceptionniste d'hôtel)
- **Use cases concrets** (3-5 exemples utilisation)
- **Tutoriels pas-à-pas** (captures écran décrites)
- **Exemples code complets** (copier-coller ready)
- **Troubleshooting débutants** (erreurs courantes)
- **Checklist progression** (débutant → intermédiaire → avancé)
- **Ressources apprentissage** (vidéos, docs, communautés)

**Style** : Français, pédagogique, ~500-1500 lignes

---

## 🔧 Scripts Production-Ready

**Chaque script DOIT** :
- ✅ Être **idempotent** (exécution multiple safe)
- ✅ Utiliser `set -euo pipefail`
- ✅ Error handling avec numéros de ligne
- ✅ Logging vers `/var/log/`
- ✅ Validation complète (Docker, ports, ressources)
- ✅ Backups avant modification
- ✅ Rollback automatique si échec
- ✅ Afficher résumé final avec URLs/credentials
- ✅ Être bien commenté (français ou anglais)

**Fonctions standard** (voir `common-scripts/lib.sh`) :
```bash
log()    # Info messages (cyan)
warn()   # Warnings (yellow)
ok()     # Success (green)
error()  # Errors (red) + exit
```

---

## 🚀 Installation Typique (Ordre Recommandé)

### Phase 1 : Infrastructure de base
```bash
# 1. Prérequis + Docker (avec reboot)
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
sudo reboot

# 2. Supabase (backend)
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash

# 3. Traefik (reverse proxy + HTTPS)
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

### Phase 2 : Interface & Monitoring
```bash
# 4. Homepage (dashboard)
curl -fsSL https://raw.githubusercontent.com/.../08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash

# 5. Monitoring (Grafana)
curl -fsSL https://raw.githubusercontent.com/.../03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
```

### Phase 3 : Développement
```bash
# 6. Gitea (Git + CI/CD)
curl -fsSL https://raw.githubusercontent.com/.../04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash
```

### Phase 4 : Apps & Services (selon besoins)
```bash
# Email (optionnel)
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/email/scripts/01-roundcube-deploy-external.sh | sudo bash

# Apps React/Next.js
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/apps/scripts/01-apps-setup.sh | sudo bash

# Backups offsite
curl -fsSL https://raw.githubusercontent.com/.../09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
```

---

## 🛠️ Tâches Courantes pour Claude

### Créer une Nouvelle Stack

1. **Déterminer catégorie** : Infrastructure / Sécurité / Monitoring / Dev / Stockage / Media / Domotique / Interface / Backups / Productivité / IA
2. **Créer dossier** : `<numero-categorie>/<nom-stack>/`
3. **Utiliser template** : `.templates/GUIDE-DEBUTANT-TEMPLATE.md`
4. **Structure obligatoire** :
   ```
   <categorie>/<nom-stack>/
   ├── README.md
   ├── GUIDE-DEBUTANT.md
   ├── INSTALL.md
   ├── scripts/
   │   ├── 01-<stack>-deploy.sh
   │   ├── maintenance/
   │   └── utils/
   ├── compose/
   ├── config/
   └── docs/
   ```
5. **Scripts** : Suivre pattern scripts existants (idempotent, error handling, logging)
6. **Documentation** : Pédagogique, analogies simples, français
7. **Tester** : Sur Pi 5 ARM64 réel si possible
8. **Mettre à jour** :
   - `<categorie>/README.md` (ajouter stack)
   - `ROADMAP.md` (si nouvelle phase)
   - `CLAUDE.md` (ce fichier)

### Déplacer/Réorganiser Stack

**SI** une stack est mal placée (ex: `pi5-xyz-stack/` à la racine) :

1. **Identifier catégorie** correcte (01-11)
2. **Déplacer** : `mv pi5-xyz-stack/ <numero-categorie>/xyz/`
3. **Mettre à jour** `<categorie>/README.md`
4. **Mettre à jour** tous les liens dans docs
5. **Mettre à jour** `CLAUDE.md`

### Débugger un Script

**Checklist** :
1. Le script est-il idempotent ?
2. Y a-t-il `set -euo pipefail` ?
3. Les chemins sont-ils absolus ?
4. Les variables sont-elles quotées (`"$VAR"`) ?
5. Les erreurs sont-elles catchées ?
6. Y a-t-il un backup avant modification ?
7. Le résumé final affiche-t-il les URLs/credentials ?

### Améliorer Documentation

**Checklist Guide Débutant** :
- [ ] Analogies simples (monde réel)
- [ ] Exemples concrets (3+ use cases)
- [ ] Code copier-coller ready
- [ ] Captures d'écran décrites
- [ ] Troubleshooting débutants
- [ ] Ressources apprentissage
- [ ] Checklist progression

---

## 📚 Ressources Importantes

### Fichiers à Lire en Priorité

1. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Guide architecture complet pour contributeurs
2. **[INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md)** - Parcours complet Pi neuf
3. **[ROADMAP.md](ROADMAP.md)** - Vision globale projet
4. **[common-scripts/README.md](common-scripts/README.md)** - Scripts réutilisables
5. **[.templates/](. templates/)** - Templates pour nouvelles stacks

### Exemples de Référence

**Guide Débutant exemplaire** :
- [01-infrastructure/supabase/GUIDE-DEBUTANT.md](01-infrastructure/supabase/GUIDE-DEBUTANT.md)
- [01-infrastructure/traefik/GUIDE-DEBUTANT.md](01-infrastructure/traefik/GUIDE-DEBUTANT.md)
- [08-interface/homepage/GUIDE-DEBUTANT.md](08-interface/homepage/GUIDE-DEBUTANT.md)

**Scripts production-ready** :
- [01-infrastructure/supabase/scripts/01-prerequisites-setup.sh](01-infrastructure/supabase/scripts/01-prerequisites-setup.sh)
- [01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh](01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh)
- [01-infrastructure/apps/scripts/01-apps-setup.sh](01-infrastructure/apps/scripts/01-apps-setup.sh)

**Documentation multi-scénarios** :
- [01-infrastructure/traefik/docs/SCENARIOS-COMPARISON.md](01-infrastructure/traefik/docs/SCENARIOS-COMPARISON.md)
- [01-infrastructure/email/docs/SCENARIOS-COMPARISON.md](01-infrastructure/email/docs/SCENARIOS-COMPARISON.md)

---

## ⚠️ Points d'Attention

### Ce qu'il NE FAUT PAS faire

❌ **Git clone requis** pour installer
❌ **Configuration manuelle** complexe
❌ **Compilation depuis source** (sauf si ARM64 unavailable)
❌ **Scripts non-idempotents** (exécution multiple = erreurs)
❌ **Documentation technique** sans analogies
❌ **Anglais** dans guides débutants (français obligatoire)
❌ **Création de fichiers .md** proactifs (sauf si demandé)
❌ **Stacks à la racine** (`pi5-xyz-stack/`) - utiliser catégories numérotées
❌ **Naming inconsistant** - toujours `<categorie>/<nom-court>/`

### Ce qu'il FAUT faire

✅ **Installation curl/wget** one-liner
✅ **Scripts idempotents** (safe re-run)
✅ **Analogies simples** dans guides
✅ **Français** pour documentation utilisateur
✅ **Validation complète** avant exécution
✅ **Backups automatiques** avant modifications
✅ **Résumé final** avec URLs/credentials
✅ **Logging détaillé** vers `/var/log/`
✅ **Architecture par catégories** (01-11)
✅ **Structure standard** par stack
✅ **Agent architecture-guardian** pour cohérence

---

## 🎯 Objectif Final (Vision 2026)

**Un utilisateur novice doit pouvoir** :

1. **Flasher** une carte SD (Raspberry Pi Imager)
2. **Booter** le Pi
3. **Copier-coller** ~10-15 commandes curl (une par stack)
4. **Obtenir** :
   - ✅ Serveur Supabase (backend complet)
   - ✅ HTTPS automatique (Traefik)
   - ✅ Git self-hosted + CI/CD (Gitea)
   - ✅ Monitoring (Grafana)
   - ✅ Email self-hosted (Roundcube)
   - ✅ Apps React/Next.js déployables
   - ✅ Dashboard centralisé (Homepage)
   - ✅ Sauvegardes automatiques cloud
   - ✅ VPN (Tailscale)

**Le tout** :
- 100% Open Source
- Gratuit (ou ~10-20€/an pour domaine)
- Documentation pédagogique complète
- Sans compétences DevOps avancées
- Architecture cohérente et maintenable

---

## 🤖 Agent Architecture Guardian

Un agent spécialisé (`.claude/agents/architecture-guardian.md`) garantit la cohérence :

**Rôles** :
- ✅ Valider structure avant commits
- ✅ Proposer réorganisation si incohérence
- ✅ Vérifier naming conventions
- ✅ Assurer présence README + GUIDE-DEBUTANT
- ✅ Mettre à jour CLAUDE.md automatiquement

**Consulter l'agent** quand :
- Création nouvelle stack
- Réorganisation fichiers
- Doute sur placement catégorie
- Mise à jour architecture

---

## 📝 Conventions de Nommage

### Fichiers
- Guides : `GUIDE-DEBUTANT.md`, `README.md`, `INSTALL.md` (majuscules)
- Docs techniques : `ARCHITECTURE.md`, `ROADMAP.md` (majuscules)
- Docs spécifiques : `PascalCase.md` ou `kebab-case.md`

### Scripts
- Déploiement : `01-<stack>-deploy.sh` (numéroté)
- Complémentaires : `02-<action>.sh`, `03-<action>.sh`
- Maintenance : `<stack>-<action>.sh` (ex: `supabase-backup.sh`)
- Wrappers internes : `_<stack>-common.sh` (préfixe underscore)

### Dossiers
- Catégories : `01-infrastructure/`, `02-securite/`, etc. (numérotées)
- Stacks : `<nom-court>/` (kebab-case, minuscules)
- Sous-dossiers : `scripts/`, `docs/`, `config/`, `compose/` (minuscules)

---

## 🤝 Contribution

**Si tu améliores ce repo** :

1. Respecter la philosophie (installation série, pédagogie, architecture numérotée)
2. Suivre les templates (`.templates/`)
3. Tester sur Pi 5 ARM64 (si possible)
4. Documenter en français (guides débutants)
5. Scripts idempotents + error handling
6. Placer stack dans bonne catégorie (01-11)
7. Mettre à jour `<categorie>/README.md`
8. Mettre à jour `CLAUDE.md` (ce fichier)
9. Consulter `architecture-guardian` agent si doute

---

**Version** : 4.0 (Architecture réorganisée)
**Dernière mise à jour** : 2025-01-12
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)

---

**Note pour Claude** : Ce fichier est vivant, mets-le à jour si tu apportes des changements majeurs ! 🤖

**Architecture Guardian** : Consulter `.claude/agents/architecture-guardian.md` pour validation structure.
