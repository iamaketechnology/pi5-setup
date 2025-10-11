# 🥧 Pi5 Supabase Stack - Production-Ready Deployment

> **Complete Supabase self-hosted stack optimized for Raspberry Pi 5 (ARM64, 16GB RAM)**

[![Version](https://img.shields.io/badge/version-3.50-blue.svg)](VERSIONS.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![ARM64](https://img.shields.io/badge/arch-ARM64-green.svg)](https://www.arm.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Self--Hosted-3ECF8E.svg)](https://supabase.com/)
[![Status](https://img.shields.io/badge/Services-9%2F9%20Healthy-brightgreen.svg)](https://supabase.com/)

---

## 🎯 Overview

This repository provides **production-ready automated scripts** to deploy a complete Supabase stack on Raspberry Pi 5, with **all critical ARM64 compatibility issues resolved**.

### ✅ What's Included

- **3 Installation Scenarios**: Vanilla setup, Cloud migration, or Multi-app deployment
- **Automated Installation**: Two-step deployment (Prerequisites + Deployment)
- **ARM64 Optimized**: All images tested and working on Raspberry Pi 5
- **Page Size Fix**: Automatic 16KB → 4KB kernel reconfiguration
- **Security Hardening**: UFW firewall, Fail2ban, SSH keys, strong passwords
- **Production Features**: Health checks, monitoring, diagnostics, reset tools
- **Complete Documentation**: 35+ markdown files covering all aspects

### 🚀 Services Deployed

- ✅ **PostgreSQL 15** - Main database with pgvector support
- ✅ **Auth (GoTrue)** - JWT authentication with email/password
- ✅ **REST (PostgREST)** - Auto-generated REST API
- ✅ **Realtime** - WebSocket subscriptions and presence
- ✅ **Storage** - File and image storage
- ✅ **Studio** - Web administration interface
- ✅ **Kong** - API Gateway with routing
- ✅ **Edge Functions** - Deno serverless runtime
- ✅ **Portainer** - Docker container management

---

## 📁 Structure du Projet

```
01-infrastructure/supabase/
├── README.md                    # Ce fichier
├── VERSIONS.md                  # Historique complet des versions
├── docs/                        # Documentation complète (35+ fichiers)
│   ├── README.md               # Hub documentation
│   ├── supabase-guide.md       # Guide débutant
│   ├── supabase-setup.md       # Guide installation
│   ├── getting-started/        # Guides de démarrage
│   ├── guides/                 # Guides thématiques
│   ├── troubleshooting/        # Résolution problèmes
│   ├── maintenance/            # Documentation maintenance
│   └── reference/              # Références techniques
├── scripts/                     # Scripts production
│   ├── 01-prerequisites-setup.sh
│   ├── 02-supabase-deploy.sh
│   ├── maintenance/            # Scripts maintenance (wrappers)
│   ├── utils/                  # Outils diagnostic/RLS/Edge Functions
│   └── templates/              # Templates (Edge Functions Router)
├── cloud-migration/             # Outils migration Cloud → Pi
│   ├── README.md               # Guide migration
│   ├── docs/                   # Documentation migration
│   ├── scripts/                # Scripts automatisés
│   ├── manifests/              # Manifests générés (exemple)
│   └── tools/                  # Outils diagnostic
├── commands/                    # Commandes quick-reference
│   ├── README.md
│   ├── 00-Initial-Raspberry-Pi-Setup.md
│   ├── 01-Installation-Quick-Start.md
│   └── All-Commands-Reference.md
└── archive/                     # ⚠️ Fichiers historiques
    ├── README.md               # Explication archive
    ├── changelogs/             # Historique v3.8-v3.48
    ├── deprecated-scripts/     # Scripts obsolètes (v3.46)
    ├── old-docs/               # Documentation temporaire
    └── app-specific/           # Fichiers spécifiques applications
```

**Note** : L'archive contient les fichiers historiques (CHANGELOGs, scripts de correctifs ponctuels) qui ne sont plus nécessaires dans les versions récentes (v3.50+). Tous les correctifs sont maintenant intégrés automatiquement dans le script de déploiement.

---

## 📦 Quick Start

### Prerequisites

- **Hardware**: Raspberry Pi 5 (8GB or 16GB RAM recommended)
- **OS**: Raspberry Pi OS 64-bit (Bookworm)
- **Network**: Static IP or reserved DHCP lease
- **Time**: ~2 hours for complete installation

### ⚡ Installation Express (Recommandée)

**Installation directe via SSH - Aucun clonage requis :**

#### 1️⃣ Step 1 - Prerequisites & Infrastructure

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/01-prerequisites-setup.sh | sudo bash
```

**Includes:**
- ✅ System updates and security hardening (UFW, Fail2ban)
- ✅ Docker + Docker Compose installation
- ✅ Portainer deployment (port 8080)
- ✅ Kernel page size fix (16KB → 4KB)
- ✅ RAM optimizations for Pi 5

**⚠️ REQUIRED: Reboot after Step 1**

```bash
sudo reboot
```

#### 2️⃣ Step 2 - Supabase Stack Deployment

**Après reboot, se reconnecter en SSH :**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/02-supabase-deploy.sh | sudo bash
```

**🎯 Interactive Installation Menu** (v3.48+):

The script now offers **3 installation scenarios**:

```
1) 📦 Installation vierge (nouvelle application)
   → Complete Supabase ready for any application
   → Empty database, no pre-deployed Edge Functions
   → Ideal for starting a new project

2) 🔄 Migration depuis Supabase Cloud
   → Installs Supabase + prepares migration environment
   → Auto-generates migration scripts (DB, Storage, Users, Functions)
   → Step-by-step guide for migrating Cloud → Pi data

3) 🏢 Multi-applications (advanced)
   → Multiple Supabase applications on same Pi
   → Separate ports and directories per instance
   → Automatic Traefik routing configuration
```

**Standard Installation (Option 1) includes:**
- ✅ PostgreSQL with extensions (pgvector, pgjwt, uuid-ossp)
- ✅ All Supabase services (Auth, REST, Realtime, Storage, Studio)
- ✅ Kong API Gateway configuration
- ✅ Edge Functions runtime
- ✅ Production-ready health checks
- ✅ Automatic schema initialization

**Runtime**: 8-12 minutes

---

**📖 Documentation complète :**
- **[📚 Documentation Hub](docs/README.md)** - Navigation complète (⭐ START HERE)
- [Installation Quick Start](commands/01-Installation-Quick-Start.md)
- [Guide Connexion App](docs/guides/Connexion-Application.md)
- [Historique Versions](VERSIONS.md) - Changelog complet

---

## 🎯 Installation Scenarios (v3.48+)

### Scenario 1: Installation Vierge (Vanilla)

**For**: Starting a new project from scratch

**What you get**:
- Complete Supabase installation
- Empty PostgreSQL database
- All services running (Auth, Storage, Realtime, Edge Functions runtime)
- Studio accessible immediately

**Usage**: Simply select **Option 1** when prompted during installation.

---

### Scenario 2: Migration Cloud → Pi

**For**: Migrating an existing Supabase Cloud project to your Pi

**What you get**:
- Complete Supabase installation
- 5 auto-generated migration scripts:
  - `migrate-database.sh` - PostgreSQL data migration (pg_dump/pg_restore)
  - `migrate-storage.sh` - S3 Storage file migration (rclone)
  - `migrate-users.sh` - Auth users migration (API-based)
  - `migrate-edge-functions.sh` - Edge Functions deployment
  - `migrate-complete.sh` - All-in-one orchestrator
- Comprehensive migration guide: `/opt/supabase/migration/MIGRATION-GUIDE.md`

**Usage**:
```bash
# 1. Select Option 2 during installation
# 2. Follow the generated guide
cat /opt/supabase/migration/MIGRATION-GUIDE.md

# 3. Run automated migration
cd /opt/supabase/migration
sudo bash migrate-complete.sh

# Or manual step-by-step:
sudo bash migrate-database.sh
sudo bash migrate-storage.sh
sudo bash migrate-users.sh
sudo bash migrate-edge-functions.sh
```

---

### Scenario 3: Multi-Applications

**For**: Running multiple isolated Supabase instances on the same Pi

**What you get**:
- Multiple independent Supabase installations
- Automatic port allocation (8001, 8011, 8021, etc.)
- Separate directories: `/opt/supabase-{app-name}/`
- Automatic Traefik routing configuration
- Isolated databases and configurations

**Use cases**:
- Multiple environments (dev/staging/prod)
- Different applications on same Pi
- Multi-tenant SaaS setup
- Client-specific instances

**Usage**:
```bash
# First application
curl ... | sudo bash
# Select Option 3, enter name: certidoc
# Result: Port 8001, https://certidoc.domain.com

# Second application
curl ... | sudo bash
# Select Option 3, enter name: myapp
# Result: Port 8011, https://myapp.domain.com

# Third application
curl ... | sudo bash
# Select Option 3, enter name: blog
# Result: Port 8021, https://blog.domain.com
```

**Architecture**:
```
/opt/
├── supabase-certidoc/    # Port 8001, Studio 8101
├── supabase-myapp/       # Port 8011, Studio 8111
└── supabase-blog/        # Port 8021, Studio 8121

/opt/traefik/config/dynamic/
├── supabase-certidoc.yml
├── supabase-myapp.yml
└── supabase-blog.yml
```

**Requirements**:
- Raspberry Pi 5 with 16GB RAM recommended for 3+ instances
- Traefik must be installed for HTTPS routing
- 128GB+ storage for multiple instances

**📖 Complete guide**: See [archive/changelogs/CHANGELOG-MULTI-SCENARIO-v3.48.md](archive/changelogs/CHANGELOG-MULTI-SCENARIO-v3.48.md) for detailed documentation.

---

## 🔗 Access Your Services

After successful installation:

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| **Supabase Studio** | `http://<PI5-IP>:3000` | See output after install |
| **API Gateway** | `http://<PI5-IP>:8000` | Use anon/service_role keys |
| **Portainer** | `http://<PI5-IP>:8080` | Set during first access |
| **PostgreSQL** | `<PI5-IP>:5432` | Generated strong password |

> 🔑 **API Keys**: Displayed at the end of installation. Save them securely!

---

## 📚 Documentation

### 📖 Navigation Documentation

👉 **[📚 Documentation Hub](docs/README.md)** - ⭐ **Commencez ici !**

La documentation complète vous permet de :
- **Naviguer par parcours** (Getting Started, Troubleshooting, Maintenance)
- **Rechercher par problème** (Edge Functions, RLS, Storage, Kong)
- **Explorer par type** (Guides, Scripts, Références)
- **Voir toute la structure** (35+ documents organisés)

---

### 🎓 Pour Débutants - Commencer ici !

👉 **[GUIDE DÉBUTANT](docs/supabase-guide.md)** - Tout savoir sur Supabase en 15 minutes
- C'est quoi Supabase ? (expliqué simplement avec analogies)
- À quoi ça sert concrètement ? (exemples d'applications)
- Comment l'utiliser pas-à-pas (tutoriels interactifs)
- Exemples de projets complets (To-Do, Blog, Chat)
- Ressources d'apprentissage (vidéos, docs, communautés)

### 🚀 Développement & Migration

#### Workflow Développement
👉 **[Connexion-Application.md](docs/guides/Connexion-Application.md)** - Développer avec Supabase Pi
- Configuration client Supabase (Next.js, React, Vue)
- Variables d'environnement (dev vs prod)
- Tests rapides (Auth, DB, Realtime, Storage)
- Troubleshooting connexion
- Best practices performance & sécurité

#### Migration Cloud → Pi
👉 **[cloud-migration/](cloud-migration/)** - Tous les outils de migration ⚡

**Guides :**
- **[GUIDE-MIGRATION-SIMPLE.md](cloud-migration/docs/guides/GUIDE-MIGRATION-SIMPLE.md)** - Pour débutants (10 min)
- **[MIGRATION-RAPIDE.md](cloud-migration/docs/guides/MIGRATION-RAPIDE.md)** - Quick start (5 min)
- **[MIGRATION-CLOUD-TO-PI.md](cloud-migration/docs/guides/MIGRATION-CLOUD-TO-PI.md)** - Guide technique complet
- **[POST-MIGRATION.md](cloud-migration/docs/post-migration/POST-MIGRATION.md)** - Après migration (passwords, storage)

**Scripts :**
- `01-migrate-cloud-to-pi.sh` - Migration automatique base de données
- `03-post-migration-storage.js` - Migration fichiers Storage (génère manifests JSON)

### 🟢 Getting Started

- [Quick Start Guide](docs/getting-started/Quick-Start.md)
- [Installation Guide](docs/INSTALLATION-GUIDE.md)

### 🥧 Pi 5 Specific Issues

- [Known Issues Pi5](docs/troubleshooting/Known-Issues-Pi5.md)
- [PostgREST Fix](docs/troubleshooting/PostgREST-Fix.md)
- [Kong DNS Resolution](docs/troubleshooting/Kong-DNS-Resolution-Failed.md)

### 🛠️ Troubleshooting

- [Edge Functions FAT Router](docs/troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md)
- [Kong DNS Issues](docs/troubleshooting/Kong-DNS-Resolution-Failed.md)
- [PostgREST Problems](docs/troubleshooting/PostgREST-Fix.md)

### ⚙️ Configuration & Maintenance

- [Automation Scripts](docs/maintenance/Automation.md)
- [Commands Reference](commands/README.md)
- [Maintenance Scripts](scripts/maintenance/README.md)

### 🗂️ Archive

Historical documents and deprecated scripts:
- [archive/changelogs/](archive/changelogs/) - Version history (v3.8-v3.48)
- [archive/deprecated-scripts/](archive/deprecated-scripts/) - Old fix scripts
- [archive/old-docs/](archive/old-docs/) - Historical documentation

See [archive/README.md](archive/README.md) for details.

---

## 🔄 Maintenance Automatisée

- **Scripts dédiés** (`scripts/maintenance/`) : wrappers prêts à l'emploi construits sur `common-scripts/` (backup/restore via `04*`, healthcheck via `05`, update/rollback via `06`, collecte de logs via `07`, planification via `08`).
- **Usage type** : `sudo ./scripts/maintenance/supabase-backup.sh --verbose`, `sudo ./scripts/maintenance/supabase-healthcheck.sh REPORT_DIR=~/stacks/supabase/reports`, `sudo ./scripts/maintenance/supabase-update.sh update --yes`.
- **Documentation** : [docs/06-MAINTENANCE/Supabase-Automation.md](docs/06-MAINTENANCE/Supabase-Automation.md) et `scripts/maintenance/README.md`.

Tous les scripts acceptent `--dry-run`, `--yes`, `--verbose`, `--quiet` ainsi que des variables d'environnement (`SUPABASE_DIR`, `BACKUP_TARGET_DIR`, etc.).

---

## 🛠️ Utility Scripts

Located in `scripts/utils/`:

### Diagnostics

```bash
# Complete system diagnostic
sudo ./scripts/utils/diagnostic-supabase-complet.sh

# Get Supabase connection info and keys
sudo ./scripts/utils/get-supabase-info.sh
```

### 🔐 RLS (Row Level Security) Tools **[NEW]**

**Suite complète pour gérer les policies de sécurité PostgreSQL :**

```bash
# 1. Diagnostic - Analyser l'état RLS de vos tables
./scripts/utils/diagnose-rls.sh                    # Toutes les tables
./scripts/utils/diagnose-rls.sh users              # Table spécifique

# 2. Génération - Créer des templates de policies
./scripts/utils/generate-rls-template.sh users --basic          # User-based
./scripts/utils/generate-rls-template.sh posts --public-read    # Lecture publique
./scripts/utils/generate-rls-template.sh teams --team           # Team-based
./scripts/utils/generate-rls-template.sh docs --custom          # Custom

# 3. Application - Appliquer les policies
./scripts/utils/setup-rls-policies.sh                           # Mode interactif
./scripts/utils/setup-rls-policies.sh --table users             # Table spécifique
./scripts/utils/setup-rls-policies.sh --custom my-policies.sql  # Fichier SQL
./scripts/utils/setup-rls-policies.sh --list                    # Lister policies
```

**📖 Documentation complète** : [scripts/utils/RLS-TOOLS-README.md](scripts/utils/RLS-TOOLS-README.md)

**Cas d'usage typiques** :
- Erreur `403 Forbidden` / `permission denied for table` → RLS policies manquantes
- Isoler les données par utilisateur (`user_id = auth.uid()`)
- Lectures publiques, écritures privées (blogs, forums)
- Multi-tenant / SaaS (team-based policies)
- Role-based access (admin/manager/user)

### Maintenance

```bash
# Clean Supabase installation (keep data)
sudo ./scripts/utils/clean-supabase-complete.sh

# Complete system reset (WARNING: destroys all data)
sudo ./scripts/utils/pi5-complete-reset.sh
```

---

## ⚡ Common Commands

### Docker Management

```bash
# View all containers
docker ps -a

# View Supabase services
docker compose ps

# View logs (all services)
docker compose logs -f

# View logs (specific service)
docker compose logs -f supabase-auth

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v
```

### System Health

```bash
# Check page size (must be 4096)
getconf PAGESIZE

# Check RAM usage
free -h

# Check Docker status
systemctl status docker

# Check firewall rules
sudo ufw status verbose
```

---

## 🔥 Critical Fixes Implemented

This deployment includes fixes for **all known Pi 5 ARM64 issues**:

### ✅ PostgreSQL
- Page size 16KB → 4KB kernel reconfiguration
- SCRAM-SHA-256 authentication (not deprecated MD5)
- ARM64-compatible postgres:15.8.1.060 image
- Inter-container network configuration

### ✅ Auth (GoTrue)
- Healthcheck using `/health` endpoint (not `/`)
- UUID operator extensions pre-loaded
- Migration schema initialization

### ✅ Realtime
- RLIMIT_NOFILE=10000 (fixes crash loop)
- Pre-created `_realtime` schema
- Encryption variables correctly set

### ✅ Studio
- HOSTNAME=0.0.0.0 binding (fixes ECONNREFUSED)
- Root endpoint healthcheck (cloud-only endpoints removed)
- 5s healthcheck interval (optimal for ARM64)

### ✅ Edge Functions
- Correct Deno command and volume mounts
- Environment variables for Supabase integration
- pidof-based healthcheck (no wget/curl dependency)

### ✅ All Services
- No `nc` (netcat) in healthchecks (not available in minimal images)
- Optimized memory limits (512MB-1GB per service)
- Dependency chains (auth → postgres, kong → rest, etc.)

---

## 📊 System Requirements

### Minimum
- Raspberry Pi 5 (8GB RAM)
- 32GB microSD card (Class 10 / UHS-I)
- Raspberry Pi OS 64-bit (Bookworm)

### Recommended
- Raspberry Pi 5 (16GB RAM) ⭐
- 64GB+ NVMe SSD via PCIe HAT
- Active cooling (fan or heatsink)
- Gigabit Ethernet connection

### Expected Resource Usage
- **RAM**: ~4-6GB (out of 16GB)
- **Storage**: ~8-10GB for Docker images + data
- **CPU**: Idle ~5%, Peak ~40% during setup

---

## 🆘 Troubleshooting Quick Links

### Installation Fails

1. **Check prerequisites**: Run diagnostic script first
   ```bash
   sudo ./scripts/utils/diagnostic-supabase-complet.sh
   ```

2. **Page size not 4096**: Reboot required after Week 1
   ```bash
   getconf PAGESIZE  # Must show 4096
   sudo reboot
   ```

3. **Services unhealthy**: Wait 2-3 minutes for initialization
   ```bash
   docker compose ps
   docker compose logs -f
   ```

### Service-Specific Issues

- **PostgreSQL won't start**: [Database Issues](docs/04-TROUBLESHOOTING/)
- **Auth restart loop**: [Auth Issues](docs/04-TROUBLESHOOTING/)
- **Realtime crashes**: [Realtime Issues](docs/04-TROUBLESHOOTING/)
- **Studio 404/ECONNREFUSED**: [Known Issues 2025](docs/03-PI5-SPECIFIC/Known-Issues-2025.md)

### Need Help?

1. Run complete diagnostic:
   ```bash
   sudo ./scripts/utils/diagnostic-supabase-complet.sh > diagnostic.txt
   ```

2. Check logs:
   ```bash
   docker compose logs > logs.txt
   ```

3. Open GitHub issue with both files attached

---

## 📈 Project Stats

- **Scripts**: 6 production scripts + 4 utilities
- **Documentation**: 35+ markdown files
- **Critical Fixes**: 12+ ARM64-specific issues resolved
- **Installation Time**: ~2 hours (automated)
- **Services**: 12 Docker containers
- **Production Ready**: ✅ Yes

---

## 🔄 Version History

### v3.48 (Current) - Multi-Scenario Support 🎯
- **New**: Interactive installation menu with 3 scenarios
- **New**: Cloud → Pi migration script auto-generation
- **New**: Multi-application support with automatic port allocation
- **New**: Traefik integration for multi-app routing
- **100% backwards compatible** - Non-interactive mode preserved
- See [CHANGELOG-MULTI-SCENARIO-v3.48.md](CHANGELOG-MULTI-SCENARIO-v3.48.md) for complete details

### v3.47 - Edge Functions Network Fix
- Fixed Kong 503 errors by adding network alias 'functions' to edge-functions service
- No Kong config changes needed (uses official Supabase configuration)

### v3.46 - RLS Configuration Fix
- Complete Row Level Security setup with public.uid() wrapper
- Granted table permissions to authenticated role
- Fixed infinite recursion in document sharing policies

### v3.45 - PostgREST Schemas Fix
- Fixed PostgREST schema configuration to include auth and storage schemas
- Resolved 403 Forbidden errors on authenticated requests

### v3.36 - Skip Redundant SQL Init
- Fixed duplicate SQL execution (already done by docker-entrypoint-initdb.d)

### v3.23 - Security Advisor Fix
- Extensions in dedicated schema (fixes warning 0014)

### v3.22 - Edge Functions Fixed
- Complete fix for crash loop (command, volumes, env vars)

### v3.21 - Studio Healthcheck Fixed
- Uses `/` root endpoint instead of cloud-only `/api/platform/profile`

### v3.8 - Healthchecks Overhaul
- Replaced all `nc` with `wget` (ARM64 compatibility)

See [CHANGELOG-v3.8.md](CHANGELOG-v3.8.md) for older version history.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test on real Pi 5 hardware
4. Submit PR with clear description

### Reporting Issues

Include in your issue:
- Raspberry Pi model and RAM
- OS version (`uname -a`)
- Page size (`getconf PAGESIZE`)
- Output of diagnostic script
- Relevant logs

---

## 📜 License

This project is provided **AS-IS** for educational and development purposes.

Supabase is licensed under Apache 2.0.
Scripts and documentation in this repository are MIT licensed.

---

## 🙏 Acknowledgments

- [Supabase](https://supabase.com) - Amazing open-source Firebase alternative
- [Raspberry Pi Foundation](https://www.raspberrypi.com) - Incredible hardware
- Community contributors who documented ARM64 issues

---

## 🚀 Next Steps

After successful installation:

1. ✅ **Secure your installation**: [Security Hardening Guide](docs/05-CONFIGURATION/)
2. ✅ **Setup backups**: [Backup Strategies](docs/06-MAINTENANCE/)
3. ✅ **Monitor services**: [Monitoring Guide](docs/06-MAINTENANCE/)
4. ✅ **Start building**: [Supabase Documentation](https://supabase.com/docs)

---

<p align="center">
  <strong>🎉 Happy Building with Supabase on Raspberry Pi 5! 🎉</strong>
</p>

<p align="center">
  <sub>Made with ❤️ for the Raspberry Pi & Supabase communities</sub>
</p>
