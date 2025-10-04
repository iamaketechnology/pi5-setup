# 🥧 Pi5 Supabase Stack - Production-Ready Deployment

> **Complete Supabase self-hosted stack optimized for Raspberry Pi 5 (ARM64, 16GB RAM)**

[![Version](https://img.shields.io/badge/version-3.36-blue.svg)](CHANGELOG-v3.8.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![ARM64](https://img.shields.io/badge/arch-ARM64-green.svg)](https://www.arm.com/)
[![Supabase](https://img.shields.io/badge/Supabase-Self--Hosted-3ECF8E.svg)](https://supabase.com/)
[![Status](https://img.shields.io/badge/Services-9%2F9%20Healthy-brightgreen.svg)](https://supabase.com/)

---

## 🎯 Overview

This repository provides **production-ready automated scripts** to deploy a complete Supabase stack on Raspberry Pi 5, with **all critical ARM64 compatibility issues resolved**.

### ✅ What's Included

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

**Includes:**
- ✅ PostgreSQL with extensions (pgvector, pgjwt, uuid-ossp)
- ✅ All Supabase services (Auth, REST, Realtime, Storage, Studio)
- ✅ Kong API Gateway configuration
- ✅ Edge Functions runtime
- ✅ Production-ready health checks
- ✅ Automatic schema initialization

**Runtime**: 8-12 minutes

---

**📖 Documentation complète :** [INSTALL.md](INSTALL.md) | [Guide Détaillé](commands/01-Installation-Quick-Start.md) | [Guide Connexion App](docs/02-CONNECTING/01-Guide-Connexion-Application.md)

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

### 🎓 Pour Débutants - Commencer ici !

👉 **[GUIDE DÉBUTANT](GUIDE-DEBUTANT.md)** - Tout savoir sur Supabase en 15 minutes
- C'est quoi Supabase ? (expliqué simplement avec analogies)
- À quoi ça sert concrètement ? (exemples d'applications)
- Comment l'utiliser pas-à-pas (tutoriels interactifs)
- Exemples de projets complets (To-Do, Blog, Chat)
- Ressources d'apprentissage (vidéos, docs, communautés)

### 🟢 Getting Started

- [Quick Start Guide](docs/01-GETTING-STARTED/01-Quick-Start.md)
- [Architecture Overview](docs/README.md)

### 🥧 Pi 5 Specific Issues

- [ARM64 Compatibility](docs/03-PI5-SPECIFIC/Known-Issues-2025.md)
- [Page Size Fix (Critical)](docs/03-PI5-SPECIFIC/Known-Issues-2025.md)
- [Memory Optimizations](docs/03-PI5-SPECIFIC/Known-Issues-2025.md)

### 🛠️ Troubleshooting

- [Auth Issues](docs/04-TROUBLESHOOTING/)
- [Realtime Issues](docs/04-TROUBLESHOOTING/)
- [Docker Issues](docs/04-TROUBLESHOOTING/)
- [Database Issues](docs/04-TROUBLESHOOTING/)

### ⚙️ Configuration & Maintenance

- [Environment Variables](docs/05-CONFIGURATION/)
- [Security Hardening](docs/05-CONFIGURATION/)
- [Backup Strategies](docs/06-MAINTENANCE/)
- [Update Procedures](docs/06-MAINTENANCE/)

### 📖 Complete Knowledge Base

See [docs/README.md](docs/README.md) for the full documentation index.

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

### v3.36 (Current) - Skip Redundant SQL Init
- Fixed duplicate SQL execution (already done by docker-entrypoint-initdb.d)

### v3.23 - Security Advisor Fix
- Extensions in dedicated schema (fixes warning 0014)

### v3.22 - Edge Functions Fixed
- Complete fix for crash loop (command, volumes, env vars)

### v3.21 - Studio Healthcheck Fixed
- Uses `/` root endpoint instead of cloud-only `/api/platform/profile`

### v3.8 - Healthchecks Overhaul
- Replaced all `nc` with `wget` (ARM64 compatibility)

See [CHANGELOG-v3.8.md](CHANGELOG-v3.8.md) for complete history.

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
