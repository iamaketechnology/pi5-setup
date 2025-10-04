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

### Structure Multi-Stack

```
pi5-setup/
├── README.md                     # Vue d'ensemble, liens vers stacks
├── ROADMAP.md                    # 9 phases 2025-2026
├── INSTALLATION-COMPLETE.md      # ⭐ Guide installation Pi neuf (étape par étape)
├── CLAUDE.md                     # Ce fichier
├── .markdownlint.json            # Désactive warnings VSCode
├── .templates/                   # Templates pour nouvelles stacks
│   ├── GUIDE-DEBUTANT-TEMPLATE.md
│   └── README.md
├── common-scripts/               # Scripts DevOps réutilisables
│   ├── README.md (389 lignes)
│   ├── lib.sh                    # Bibliothèque partagée
│   ├── 00-preflight-checks.sh
│   ├── 01-system-hardening.sh
│   ├── 02-docker-install-verify.sh
│   ├── 03-traefik-setup.sh
│   ├── 04-backup-rotate.sh       # GFS rotation
│   ├── 04b-restore-from-backup.sh
│   ├── 05-healthcheck-report.sh
│   ├── 06-update-and-rollback.sh
│   ├── 07-logs-collect.sh
│   ├── 08-scheduler-setup.sh
│   └── [autres scripts DevOps]
├── pi5-supabase-stack/           # ✅ Phase 1 (TERMINÉ)
│   ├── README.md
│   ├── GUIDE-DEBUTANT.md (500+ lignes)
│   ├── INSTALL.md
│   ├── scripts/
│   │   ├── 01-prerequisites-setup.sh
│   │   ├── 02-supabase-deploy.sh
│   │   ├── maintenance/          # Wrappers → common-scripts
│   │   └── utils/
│   ├── docs/ (8 dossiers, 35+ fichiers)
│   └── commands/
└── pi5-traefik-stack/            # ✅ Phase 2 (TERMINÉ)
    ├── README.md
    ├── GUIDE-DEBUTANT.md (1023 lignes)
    ├── INSTALL.md
    ├── scripts/
    │   ├── 01-traefik-deploy-duckdns.sh      # Scénario 1
    │   ├── 01-traefik-deploy-cloudflare.sh   # Scénario 2
    │   ├── 01-traefik-deploy-vpn.sh          # Scénario 3
    │   └── 02-integrate-supabase.sh
    └── docs/
        ├── SCENARIO-DUCKDNS.md
        ├── SCENARIO-CLOUDFLARE.md
        ├── SCENARIO-VPN.md
        └── SCENARIOS-COMPARISON.md
```

---

## 🎓 Philosophie de Documentation

### 1. Guide Débutant Systématique

**Chaque stack DOIT avoir** : `GUIDE-DEBUTANT.md`

**Template** : `.templates/GUIDE-DEBUTANT-TEMPLATE.md`

**Contenu obligatoire** :
- **Analogies simples** (ex: reverse proxy = réceptionniste d'hôtel)
- **Use cases concrets** (3-5 exemples d'utilisation)
- **Tutoriels pas-à-pas** (captures d'écran décrites)
- **Exemples code complets** (copier-coller ready)
- **Troubleshooting débutants** (erreurs courantes)
- **Checklist progression** (débutant → intermédiaire → avancé)
- **Ressources apprentissage** (vidéos, docs, communautés)

**Style** : Français, pédagogique, ~500-1000 lignes

---

### 2. Scripts Production-Ready

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

### 3. Installation en Série (CRUCIAL)

**L'utilisateur doit pouvoir** :
1. Flasher une carte SD
2. Booter le Pi
3. Copier-coller des commandes **une par une**
4. Avoir un serveur complet

**Exemple parcours** :
```bash
# Étape 1
curl -fsSL https://raw.githubusercontent.com/.../01-prerequisites-setup.sh | sudo bash
sudo reboot

# Étape 2
curl -fsSL https://raw.githubusercontent.com/.../02-supabase-deploy.sh | sudo bash

# Étape 3
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash

# Étape 4
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-supabase.sh | sudo bash
```

**PAS de** : `git clone` requis, configuration manuelle complexe, compilation source

---

## 🔑 Concepts Clés

### 1. Wrapper Pattern (Scripts Maintenance)

**Principe** : Les scripts de maintenance des stacks sont des **wrappers** vers `common-scripts/`

**Exemple** :
```bash
# pi5-supabase-stack/scripts/maintenance/supabase-backup.sh
source _supabase-common.sh  # Config variables
exec ${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh "$@"  # Délègue
```

**Avantages** :
- Réutilisation du code
- Maintenance centralisée
- Cohérence entre stacks

---

### 2. Multi-Scénarios (Traefik)

**Problème** : Différents besoins utilisateurs (débutant, production, sécurité)

**Solution** : **3 scénarios** avec scripts séparés

| Scénario | Public | Coût | Difficulté |
|----------|--------|------|------------|
| 🟢 DuckDNS | Débutants | Gratuit | ⭐ Facile |
| 🔵 Cloudflare | Production | ~8€/an | ⭐⭐ Moyen |
| 🟡 VPN | Sécurité | Gratuit | ⭐⭐⭐ Avancé |

**Implémentation** :
- 3 scripts déploiement : `01-traefik-deploy-{duckdns,cloudflare,vpn}.sh`
- 3 docs détaillés : `SCENARIO-{DUCKDNS,CLOUDFLARE,VPN}.md`
- 1 doc comparaison : `SCENARIOS-COMPARISON.md`
- Script intégration auto-détecte scénario

---

### 3. ARM64 Optimisations

**Spécificités Raspberry Pi 5** :
- **Page Size** : Kernel par défaut 16KB → Fix 4KB pour PostgreSQL
- **Images Docker** : Utiliser `arm64` tags explicites
- **RAM** : 8-16GB, optimiser consommation
- **SD Card** : Minimiser écritures (log rotation)

**Fix Page Size** (fait dans `01-prerequisites-setup.sh`) :
```bash
sudo rpi-update pulls/6198  # Kernel 4KB page size
sudo reboot
```

---

## 📊 État Actuel (v3.27)

### ✅ Phase 1 : Supabase Stack (Terminé)

**Services déployés** :
- PostgreSQL 15 + extensions (pgvector, pgjwt)
- Auth (GoTrue)
- REST API (PostgREST)
- Realtime (WebSockets)
- Storage (S3-compatible)
- Studio UI
- Edge Functions (Deno)
- Kong API Gateway

**Documentation** : 35+ fichiers, 8 dossiers

**Scripts** :
- `01-prerequisites-setup.sh` (sécurité, Docker, Portainer, fix page size)
- `02-supabase-deploy.sh` (déploiement complet)
- 6 scripts maintenance (backup, healthcheck, logs, restore, update, scheduler)
- 4 scripts utils (diagnostic, info, clean, reset)

**Installation** :
```bash
curl ... 01-prerequisites-setup.sh | sudo bash && sudo reboot
curl ... 02-supabase-deploy.sh | sudo bash
```

---

### ✅ Phase 2 : Traefik Stack (Terminé)

**Objectif** : Reverse proxy + HTTPS automatique

**3 Scénarios implémentés** :
1. **DuckDNS** : Gratuit, path-based (`/studio`, `/api`)
2. **Cloudflare** : Domaine perso, subdomain-based (`studio.domain.com`)
3. **VPN** : Tailscale/WireGuard, local domains (`.pi.local`)

**Documentation** : 7 fichiers (~4000 lignes)
- GUIDE-DEBUTANT.md (1023 lignes)
- 3 docs scénarios détaillés
- SCENARIOS-COMPARISON.md
- INSTALL.md

**Scripts** :
- `01-traefik-deploy-duckdns.sh` (22 KB)
- `01-traefik-deploy-cloudflare.sh` (25 KB)
- `01-traefik-deploy-vpn.sh` (29 KB)
- `02-integrate-supabase.sh` (auto-détection scénario)

**Installation** (exemple DuckDNS) :
```bash
curl ... 01-traefik-deploy-duckdns.sh | sudo bash
curl ... 02-integrate-supabase.sh | sudo bash
```

---

### 🔜 Phases Futures (Roadmap)

**Phase 3** : Monitoring (Prometheus + Grafana)
**Phase 4** : VPN (Tailscale/WireGuard)
**Phase 5** : Gitea + CI/CD
**Phase 6** : Backups offsite (rclone → R2/B2)
**Phase 7** : Nextcloud/FileBrowser (stockage cloud)
**Phase 8** : Jellyfin + *arr (média)
**Phase 9** : Authelia/Authentik (SSO)

**Voir** : [ROADMAP.md](ROADMAP.md)

---

## 🛠️ Tâches Courantes pour Claude

### Créer une Nouvelle Stack

1. **Créer dossier** : `pi5-[nom]-stack/`
2. **Utiliser template** : `.templates/GUIDE-DEBUTANT-TEMPLATE.md`
3. **Structure obligatoire** :
   ```
   pi5-[nom]-stack/
   ├── README.md
   ├── GUIDE-DEBUTANT.md
   ├── INSTALL.md
   ├── scripts/
   │   ├── 01-[nom]-deploy.sh
   │   ├── maintenance/
   │   └── utils/
   ├── compose/
   ├── config/
   ├── docs/
   └── commands/
   ```
4. **Scripts** : Suivre pattern des scripts existants
5. **Documentation** : Pédagogique, analogies simples, français
6. **Tester** : Sur Pi 5 ARM64 réel si possible
7. **Mettre à jour** : README.md principal, ROADMAP.md

---

### Débugger un Script

**Checklist** :
1. Le script est-il idempotent ?
2. Y a-t-il `set -euo pipefail` ?
3. Les chemins sont-ils absolus ?
4. Les variables sont-elles quotées (`"$VAR"`) ?
5. Les erreurs sont-elles catchées ?
6. Y a-t-il un backup avant modification ?
7. Le résumé final affiche-t-il les URLs/credentials ?

---

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

1. **[INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md)** - Parcours complet Pi neuf
2. **[ROADMAP.md](ROADMAP.md)** - Vision globale 9 phases
3. **[common-scripts/README.md](common-scripts/README.md)** - Scripts réutilisables
4. **[.templates/](. templates/)** - Templates pour nouvelles stacks

### Exemples de Référence

**Guide Débutant exemplaire** :
- [pi5-supabase-stack/GUIDE-DEBUTANT.md](pi5-supabase-stack/GUIDE-DEBUTANT.md)
- [pi5-traefik-stack/GUIDE-DEBUTANT.md](pi5-traefik-stack/GUIDE-DEBUTANT.md)

**Scripts production-ready** :
- [pi5-supabase-stack/scripts/01-prerequisites-setup.sh](pi5-supabase-stack/scripts/01-prerequisites-setup.sh)
- [pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh](pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh)

**Documentation multi-scénarios** :
- [pi5-traefik-stack/docs/SCENARIOS-COMPARISON.md](pi5-traefik-stack/docs/SCENARIOS-COMPARISON.md)

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

### Ce qu'il FAUT faire

✅ **Installation curl/wget** one-liner
✅ **Scripts idempotents** (safe re-run)
✅ **Analogies simples** dans guides
✅ **Français** pour documentation utilisateur
✅ **Validation complète** avant exécution
✅ **Backups automatiques** avant modifications
✅ **Résumé final** avec URLs/credentials
✅ **Logging détaillé** vers /var/log/

---

## 🎯 Objectif Final (Vision 2026)

**Un utilisateur novice doit pouvoir** :

1. **Flasher** une carte SD (Raspberry Pi Imager)
2. **Booter** le Pi
3. **Copier-coller** ~10 commandes curl (une par phase)
4. **Obtenir** :
   - ✅ Serveur Supabase (backend complet)
   - ✅ HTTPS automatique (Traefik)
   - ✅ Git self-hosted (Gitea)
   - ✅ Monitoring (Grafana)
   - ✅ VPN (Tailscale)
   - ✅ Sauvegardes automatiques
   - ✅ CI/CD (Gitea Actions)

**Le tout** :
- 100% Open Source
- Gratuit (ou ~10-20€/an pour domaine)
- Documentation pédagogique complète
- Sans compétences DevOps avancées

---

## 📝 Conventions de Nommage

### Fichiers
- Guides : `GUIDE-DEBUTANT.md` (majuscules)
- Installation : `INSTALL.md`, `README.md` (majuscules)
- Docs techniques : `PascalCase.md` ou `kebab-case.md`

### Scripts
- Déploiement : `01-[stack]-deploy.sh` (numéroté)
- Maintenance : `[stack]-[action].sh` (ex: `supabase-backup.sh`)
- Wrappers : `_[stack]-common.sh` (préfixe underscore)

### Dossiers
- Stacks : `pi5-[nom]-stack/` (kebab-case, minuscules)
- Sous-dossiers : `scripts/`, `docs/`, `config/` (minuscules)

---

## 🤝 Contribution

**Si tu améliores ce repo** :

1. Respecter la philosophie (installation série, pédagogie)
2. Suivre les templates (`.templates/`)
3. Tester sur Pi 5 ARM64 (si possible)
4. Documenter en français (guides débutants)
5. Scripts idempotents + error handling
6. Mettre à jour ROADMAP.md et README.md

---

**Version** : 3.27
**Dernière mise à jour** : 2025-10-04
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)

---

**Note pour Claude** : Ce fichier est vivant, mets-le à jour si tu apportes des changements majeurs ! 🤖
