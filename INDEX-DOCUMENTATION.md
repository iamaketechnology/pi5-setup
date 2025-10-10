# 📚 Index Documentation - PI5-SETUP

> **Navigation rapide vers tous les guides et documentations du projet**

---

## 🚀 Démarrage Rapide

### Installation Initiale

| Guide | Description | Liens |
|-------|-------------|-------|
| 🎯 **Installation Complète** | Parcours complet depuis Pi neuf jusqu'à serveur fonctionnel | [INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md) |
| ⚡ **Quick Start Supabase** | Installation Supabase en 2 commandes | [pi5-supabase-stack](01-infrastructure/supabase/) |
| 🌐 **Quick Start Accès Externe** | Exposer Supabase sur Internet en 1 commande | [external-access/QUICK-START.md](01-infrastructure/external-access/QUICK-START.md) |

---

## 🏗️ Infrastructure

### 1. Supabase Stack

| Document | Description |
|----------|-------------|
| [README Principal](01-infrastructure/supabase/README.md) | Vue d'ensemble et architecture |
| [Quick Start](01-infrastructure/supabase/docs/getting-started/Quick-Start.md) | Installation en 2 étapes |
| [Guide Débutant](01-infrastructure/supabase/GUIDE-DEBUTANT.md) | Comprendre Supabase de A à Z |
| [Guide Commandes](01-infrastructure/supabase/commands/README.md) | Référence des commandes supabase-cli |
| [Troubleshooting](01-infrastructure/supabase/docs/troubleshooting/) | Résolution problèmes courants |

### 2. Accès Externe

| Document | Description |
|----------|-------------|
| [README Getting Started](01-infrastructure/external-access/README-GETTING-STARTED.md) | Guide pour débutants avec quiz |
| [Quick Start](01-infrastructure/external-access/QUICK-START.md) | Installation en 1 commande |
| [Comparaison Options](01-infrastructure/external-access/COMPARISON.md) | Tableau comparatif détaillé |
| [User Journey](01-infrastructure/external-access/USER-JOURNEY-SIMULATION.md) | Simulation parcours utilisateur |

#### Option 1 : Port Forwarding

| Document | Description |
|----------|-------------|
| [README](01-infrastructure/external-access/option1-port-forwarding/README.md) | Documentation complète |
| [Guide IP Full-Stack Free](01-infrastructure/external-access/option1-port-forwarding/docs/FREE-IP-FULLSTACK-GUIDE.md) | Débloquer ports pour Freebox |
| [Script Installation](01-infrastructure/external-access/option1-port-forwarding/scripts/01-setup-port-forwarding.sh) | Script automatisé |

#### Option 2 : Cloudflare Tunnel

| Document | Description |
|----------|-------------|
| [README](01-infrastructure/external-access/option2-cloudflare-tunnel/README.md) | Documentation complète |
| [Script Installation](01-infrastructure/external-access/option2-cloudflare-tunnel/scripts/01-setup-cloudflare-tunnel.sh) | Script automatisé |

#### Option 3 : Tailscale VPN

| Document | Description |
|----------|-------------|
| [README](01-infrastructure/external-access/option3-tailscale-vpn/README.md) | Documentation complète |
| [Script Installation](01-infrastructure/external-access/option3-tailscale-vpn/scripts/01-setup-tailscale.sh) | Script automatisé |

#### Configuration Hybride

| Document | Description |
|----------|-------------|
| [README](01-infrastructure/external-access/hybrid-setup/README.md) | Combiner Port Forwarding + Tailscale |
| [Installation Détaillée](01-infrastructure/external-access/hybrid-setup/docs/INSTALLATION-COMPLETE-STEP-BY-STEP.md) | Guide pas-à-pas avec timing |
| [CHANGELOG](01-infrastructure/external-access/hybrid-setup/CHANGELOG.md) | Historique corrections (bug Traefik) |
| [Script Installation](01-infrastructure/external-access/hybrid-setup/scripts/01-setup-hybrid-access.sh) | Script automatisé |

### 3. Traefik Stack

| Document | Description |
|----------|-------------|
| [README](01-infrastructure/traefik/README.md) | Reverse proxy + HTTPS automatique |
| [Guide Débutant](01-infrastructure/traefik/GUIDE-DEBUTANT.md) | Comprendre Traefik |
| [Scénario DuckDNS](01-infrastructure/traefik/docs/SCENARIO-DUCKDNS.md) | Configuration DNS gratuit |
| [Scénario Cloudflare](01-infrastructure/traefik/docs/SCENARIO-CLOUDFLARE.md) | Configuration domaine perso |
| [Scénario VPN](01-infrastructure/traefik/docs/SCENARIO-VPN.md) | Configuration accès privé |
| [Comparaison Scénarios](01-infrastructure/traefik/docs/SCENARIOS-COMPARISON.md) | Aide au choix |

---

## 🔌 Après Installation

### Connecter votre Application

| Document | Description |
|----------|-------------|
| [🔌 Guide Connexion Application](CONNEXION-APPLICATION-SUPABASE-PI.md) | **GUIDE PRINCIPAL** - Connecter React, Vue, Next.js, etc. |
| [Connexion Application (ancien)](CONNEXION-APPLICATION.md) | Version alternative |

**Contenu du guide principal** :
- ✅ Configuration React/Vite
- ✅ Configuration Next.js (App Router + Pages Router)
- ✅ Configuration Vue.js
- ✅ Configuration Node.js Backend
- ✅ Configuration Lovable.ai
- ✅ Variables d'environnement selon contexte (local/prod/VPN)
- ✅ Différence ANON_KEY vs SERVICE_KEY
- ✅ Tests de connexion
- ✅ Troubleshooting (CORS, timeouts, etc.)

---

## 🎓 Documentation Pédagogique

### Guides Débutants

| Stack | Guide |
|-------|-------|
| Supabase | [GUIDE-DEBUTANT.md](01-infrastructure/supabase/GUIDE-DEBUTANT.md) |
| Traefik | [GUIDE-DEBUTANT.md](01-infrastructure/traefik/GUIDE-DEBUTANT.md) |
| Homepage | [GUIDE-DEBUTANT.md](01-infrastructure/homepage/GUIDE-DEBUTANT.md) |
| Monitoring | [GUIDE-DEBUTANT.md](01-infrastructure/monitoring/GUIDE-DEBUTANT.md) |
| Backup Offsite | [GUIDE-DEBUTANT.md](01-infrastructure/backup-offsite/GUIDE-DEBUTANT.md) |
| VPN | [GUIDE-DEBUTANT.md](01-infrastructure/vpn/GUIDE-DEBUTANT.md) |
| Gitea | [GUIDE-DEBUTANT.md](01-infrastructure/gitea/GUIDE-DEBUTANT.md) |

### Templates

| Template | Usage |
|----------|-------|
| [GUIDE-DEBUTANT-TEMPLATE](. templates/GUIDE-DEBUTANT-TEMPLATE.md) | Créer nouveaux guides débutants |
| [README Template](.templates/README.md) | Standards documentation |

---

## 🛠️ Scripts DevOps

### Common Scripts

| Script | Description |
|--------|-------------|
| [lib.sh](common-scripts/lib.sh) | Bibliothèque partagée (fonctions réutilisables) |
| [00-preflight-checks.sh](common-scripts/00-preflight-checks.sh) | Vérifications pré-installation |
| [01-system-hardening.sh](common-scripts/01-system-hardening.sh) | Sécurisation système |
| [02-docker-install-verify.sh](common-scripts/02-docker-install-verify.sh) | Installation Docker |
| [04-backup-rotate.sh](common-scripts/04-backup-rotate.sh) | Sauvegarde avec rotation GFS |
| [04b-restore-from-backup.sh](common-scripts/04b-restore-from-backup.sh) | Restauration depuis backup |
| [05-healthcheck-report.sh](common-scripts/05-healthcheck-report.sh) | Rapport état système |
| [06-update-and-rollback.sh](common-scripts/06-update-and-rollback.sh) | Mise à jour avec rollback |

**Documentation complète** : [common-scripts/README.md](common-scripts/README.md) (389 lignes)

---

## 📋 Guides Spécialisés

### Migration

| Document | Description |
|----------|-------------|
| [Guide Migration Simple](01-infrastructure/supabase/migration/docs/GUIDE-MIGRATION-SIMPLE.md) | Migrer Cloud → Pi |
| [Migration Cloud to Pi](01-infrastructure/supabase/migration/docs/MIGRATION-CLOUD-TO-PI.md) | Migration complète avec Auth |
| [Post-Migration](01-infrastructure/supabase/migration/docs/POST-MIGRATION.md) | Étapes après migration |
| [Workflow Développement](01-infrastructure/supabase/migration/docs/WORKFLOW-DEVELOPPEMENT.md) | Développement avec instance Pi |

### Troubleshooting

| Document | Description |
|----------|-------------|
| [PostgREST Healthcheck Fix](01-infrastructure/supabase/docs/troubleshooting/PostgREST-Healthcheck-Fix.md) | Corriger erreur healthcheck |
| [Known Issues 2025](01-infrastructure/supabase/docs/troubleshooting/Known-Issues-2025.md) | Problèmes connus sur Pi5 |
| [CORS Fix](01-infrastructure/supabase/scripts/fix-cors-complete.sh) | Corriger erreurs CORS |

### Debug Sessions (Archives)

| Document | Description |
|----------|-------------|
| [Studio + Edge Functions Fix](01-infrastructure/supabase/docs/reference/debug-sessions/Studio-Edge-Functions-Fix.md) | Fix affichage Studio |
| [Auth Migration Debug](01-infrastructure/supabase/docs/reference/debug-sessions/Debug-Auth-Migration.md) | Debug migration Auth |
| [Realtime Debug](01-infrastructure/supabase/docs/reference/debug-sessions/Debug-Realtime.md) | Debug WebSockets |

---

## 🗺️ Roadmap

### Phases Terminées

- ✅ **Phase 1** : Supabase Stack (PostgreSQL + Auth + Storage + Edge Functions)
- ✅ **Phase 2** : Traefik Stack (Reverse proxy + HTTPS)
- ✅ **Phase 2b** : Homepage Stack (Dashboard services)
- ✅ **Phase 3** : Monitoring Stack (Prometheus + Grafana)
- ✅ **Phase 4** : VPN Stack (Tailscale)
- ✅ **Phase 5** : Gitea Stack (Git + CI/CD)
- ✅ **Phase 6** : Backup Offsite Stack (rclone → R2/B2/S3)

### Phases Futures

- 🔜 **Phase 7** : Nextcloud/FileBrowser (stockage cloud perso)
- 🔜 **Phase 8** : Jellyfin + *arr (média)
- 🔜 **Phase 9** : Authelia/Authentik (SSO)

**Voir** : [ROADMAP.md](ROADMAP.md) pour détails complets

---

## 🔧 Maintenance

### Commandes Supabase

```bash
# Backup
supabase-backup

# Healthcheck
supabase-healthcheck

# Logs
supabase-logs

# Mise à jour
supabase-update

# Reset
supabase-reset

# Info
supabase-info
```

**Documentation complète** : [commands/README.md](01-infrastructure/supabase/commands/README.md)

---

## ⚠️ Problèmes Connus

### Supabase sur Pi5

1. **Page Size 16KB** → Fix kernel 4KB requis
   - Solution : [01-prerequisites-setup.sh](01-infrastructure/supabase/scripts/01-prerequisites-setup.sh) applique automatiquement

2. **Console Errors 404** → Normal sur self-hosted
   - Détails : [Known-Issues-2025.md](01-infrastructure/supabase/docs/troubleshooting/Known-Issues-2025.md)

3. **Studio Path-Based Routing** → Redirection /project/default échoue
   - Solution : Utiliser port 3000 direct pour Studio UI
   - Détails : [CHANGELOG Hybrid](01-infrastructure/external-access/hybrid-setup/CHANGELOG.md)

### Freebox (FAI Free)

1. **Port 80/443 bloqués** → IP partagée par défaut
   - Solution : Demander IP Full-Stack (gratuit)
   - Guide : [FREE-IP-FULLSTACK-GUIDE.md](01-infrastructure/external-access/option1-port-forwarding/docs/FREE-IP-FULLSTACK-GUIDE.md)

---

## 📊 Résumés

### Installation Complète - Résumé

| Document | Description |
|----------|-------------|
| [DOCUMENTATION-FINALE-RESUME.md](DOCUMENTATION-FINALE-RESUME.md) | Résumé installation et docs |
| [NOUVELLES-STACKS-RESUME.md](NOUVELLES-STACKS-RESUME.md) | Résumé stacks ajoutées |

---

## 🤖 Pour Claude (AI Assistant)

**Fichier de contexte** : [CLAUDE.md](CLAUDE.md) (Vue d'ensemble complète du projet)

**Points clés pour les AI assistants** :
- ✅ Philosophie : Installation série (curl one-liners)
- ✅ Scripts idempotents obligatoires
- ✅ Documentation pédagogique en français
- ✅ Guides débutants systématiques
- ✅ Wrapper pattern pour maintenance
- ✅ Templates dans `.templates/`

---

## 📞 Support

### Liens Utiles

- [Issues GitHub](https://github.com/VOTRE-REPO/pi5-setup/issues)
- [Discussions](https://github.com/VOTRE-REPO/pi5-setup/discussions)
- [Wiki](https://github.com/VOTRE-REPO/pi5-setup/wiki)

### Communautés

- [Supabase Discord](https://discord.supabase.com)
- [Traefik Community Forum](https://community.traefik.io)
- [r/selfhosted](https://reddit.com/r/selfhosted)
- [r/raspberry_pi](https://reddit.com/r/raspberry_pi)

---

## 📖 Structure Repository

```
pi5-setup/
├── README.md                              # Vue d'ensemble projet
├── INDEX-DOCUMENTATION.md                 # Ce fichier (index complet)
├── INSTALLATION-COMPLETE.md               # Guide installation complète
├── ROADMAP.md                             # Plan 9 phases 2025-2026
├── CLAUDE.md                              # Guide pour AI assistants
├── CONNEXION-APPLICATION-SUPABASE-PI.md   # Guide connexion apps ⭐
│
├── .templates/                            # Templates pour nouvelles stacks
│   ├── GUIDE-DEBUTANT-TEMPLATE.md
│   └── README.md
│
├── common-scripts/                        # Scripts DevOps réutilisables
│   ├── README.md (389 lignes)
│   ├── lib.sh
│   └── [12 scripts DevOps]
│
└── 01-infrastructure/
    ├── supabase/                          # Phase 1 ✅
    ├── traefik/                           # Phase 2 ✅
    ├── homepage/                          # Phase 2b ✅
    ├── monitoring/                        # Phase 3 ✅
    ├── vpn/                               # Phase 4 ✅
    ├── gitea/                             # Phase 5 ✅
    ├── backup-offsite/                    # Phase 6 ✅
    ├── external-access/                   # Accès externe
    │   ├── option1-port-forwarding/
    │   ├── option2-cloudflare-tunnel/
    │   ├── option3-tailscale-vpn/
    │   └── hybrid-setup/                  # ⭐ Combinaison optimale
    ├── email/                             # Email stack
    └── webserver/                         # Nginx/Apache stack
```

---

## 🎯 Navigation Rapide par Besoin

### "Je débute, je veux installer Supabase sur mon Pi"
1. [INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md)
2. [Quick Start Supabase](01-infrastructure/supabase/docs/getting-started/Quick-Start.md)

### "J'ai Supabase installé, je veux y accéder depuis Internet"
1. [Quick Start Accès Externe](01-infrastructure/external-access/QUICK-START.md)
2. [Guide Débutants Accès Externe](01-infrastructure/external-access/README-GETTING-STARTED.md)

### "Je veux connecter mon app React à mon Supabase"
1. [Guide Connexion Application](CONNEXION-APPLICATION-SUPABASE-PI.md) ⭐

### "J'ai Freebox et port 80 bloqué"
1. [Guide IP Full-Stack Free](01-infrastructure/external-access/option1-port-forwarding/docs/FREE-IP-FULLSTACK-GUIDE.md)

### "Je veux migrer depuis Supabase Cloud"
1. [Guide Migration Simple](01-infrastructure/supabase/migration/docs/GUIDE-MIGRATION-SIMPLE.md)

### "J'ai un problème, ça ne marche pas"
1. [Troubleshooting Supabase](01-infrastructure/supabase/docs/troubleshooting/)
2. [Known Issues 2025](01-infrastructure/supabase/docs/troubleshooting/Known-Issues-2025.md)

### "Je veux créer une nouvelle stack"
1. [CLAUDE.md](CLAUDE.md) - Section "Créer une Nouvelle Stack"
2. [Templates](.templates/)

---

**Version** : 1.0
**Date** : 2025-10-10
**Projet** : PI5-SETUP - Raspberry Pi 5 Development Server
**Licence** : MIT

**⭐ Ce fichier INDEX est maintenu à jour - bookmarkez-le !**
