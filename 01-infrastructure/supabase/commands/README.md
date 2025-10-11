# 📟 Terminal Commands Reference

> **Complete terminal command reference for Raspberry Pi 5 & Supabase deployment**

---

## 📚 Documentation Structure

This directory contains all terminal commands needed from initial Raspberry Pi setup through Supabase deployment and maintenance.

### 📖 Available Guides

| File | Description | When to Use |
|------|-------------|-------------|
| [00-Initial-Raspberry-Pi-Setup.md](00-Initial-Raspberry-Pi-Setup.md) | **Complete Raspberry Pi OS initial setup** | First boot, before any installation |
| [01-Installation-Quick-Start.md](01-Installation-Quick-Start.md) | **Quick installation guide with copy-paste commands** | Ready to install Supabase stack |
| [CLEANUP-RESET.md](CLEANUP-RESET.md) | **🆕 Nettoyage et réinitialisation** | Nettoyer, revenir en arrière, réinstaller |
| [All-Commands-Reference.md](All-Commands-Reference.md) | **Complete command reference** | Quick lookup during operation |

### 🎯 New in v3.48 - Multi-Scenario Support

The installation script now supports **3 different scenarios**:

| Scenario | Description | Best For |
|----------|-------------|----------|
| **1. Vanilla** | Fresh Supabase installation | New projects from scratch |
| **2. Migration** | Cloud → Pi migration with auto-generated scripts | Migrating from Supabase Cloud |
| **3. Multi-App** | Multiple isolated instances on same Pi | Dev/staging/prod or multi-tenant |

📖 See [../CHANGELOG-MULTI-SCENARIO-v3.48.md](../CHANGELOG-MULTI-SCENARIO-v3.48.md) for complete documentation.

---

## 🚀 Quick Navigation

### 🆕 New Raspberry Pi Setup

**Starting from scratch?** Follow this order:

1. **[Initial Setup →](00-Initial-Raspberry-Pi-Setup.md)**
   - Flash Raspberry Pi OS
   - Configure system basics
   - Setup SSH security
   - Fix page size (critical!)
   - Network configuration
   - Install essential tools

2. **[Installation Étape 1 →](../scripts/01-prerequisites-setup.sh)**
   - Run the automated script
   - Docker installation
   - Security hardening

3. **[Installation Étape 2 →](../scripts/02-supabase-deploy.sh)**
   - Run the automated script
   - Supabase stack deployment

---

## 🔍 Command Categories

### System & Hardware
- OS information and kernel checks
- RAM and disk monitoring
- Temperature and voltage monitoring
- Page size verification

### Docker Management
- Container lifecycle (start/stop/restart)
- Image management
- Volume operations
- Logs and diagnostics
- Docker Compose operations

### Supabase Services
- Service health checks
- Database operations
- API testing
- Backup and restore

### Security
- UFW firewall configuration
- Fail2ban management
- SSH hardening
- Certificate management

### Networking
- Port checks
- Connectivity tests
- Docker networks
- DNS configuration

### Troubleshooting
- Complete system reset
- Service-specific fixes
- Log analysis
- Performance diagnostics

---

## 📋 Quick Access Commands

### Most Used Commands

```bash
# System health check
getconf PAGESIZE              # Must be 4096
free -h                       # RAM usage
df -h                         # Disk space
vcgencmd measure_temp         # CPU temperature

# Docker status
docker ps                     # Running containers
docker compose ps             # Supabase services status
docker stats --no-stream      # Resource usage snapshot

# Supabase operations
cd ~/stacks/supabase
docker compose up -d          # Start all services
docker compose down           # Stop all services
docker compose logs -f        # Follow all logs
docker compose restart auth   # Restart specific service

# Quick diagnostics
sudo systemctl status docker  # Docker daemon status
sudo ufw status              # Firewall status
sudo netstat -tulpn          # Listening ports
```

---

## 🎯 Common Tasks Quick Links

### Installation
- [Flash Raspberry Pi OS](00-Initial-Raspberry-Pi-Setup.md#installation-raspberry-pi-os)
- [First SSH Connection](00-Initial-Raspberry-Pi-Setup.md#premier-démarrage)
- [Page Size Fix](00-Initial-Raspberry-Pi-Setup.md#1-page-size-fix-critique-pour-postgresql)

### Configuration
- [Static IP Setup](00-Initial-Raspberry-Pi-Setup.md#ip-statique-recommandé-pour-serveur)
- [SSH Key Authentication](00-Initial-Raspberry-Pi-Setup.md#sécurité-ssh)
- [System Optimizations](00-Initial-Raspberry-Pi-Setup.md#optimisations-pi-5)

### Operations
- [Docker Management](All-Commands-Reference.md#docker-management)
- [Supabase Services Control](All-Commands-Reference.md#supabase-services)
- [PostgreSQL Database](All-Commands-Reference.md#postgresql-database)

### Troubleshooting
- [Reset Supabase](All-Commands-Reference.md#reset-complet-supabase)
- [Fix Docker Permissions](All-Commands-Reference.md#fix-permissions-docker)
- [Diagnostic Script](All-Commands-Reference.md#diagnostic-complet)

### Backup & Maintenance
- [Database Backup](All-Commands-Reference.md#backup-database)
- [Automated Backups](All-Commands-Reference.md#automatisation-backup)
- [System Monitoring](All-Commands-Reference.md#monitoring-système)

---

## 🔧 Utility Scripts Location

Pre-built scripts available in `../scripts/utils/`:

```bash
# Diagnostic tools
../scripts/utils/diagnostic-supabase-complet.sh

# Get connection info and API keys
../scripts/utils/get-supabase-info.sh

# Clean installation (keeps data)
../scripts/utils/clean-supabase-complete.sh

# Complete system reset (destroys data)
../scripts/utils/pi5-complete-reset.sh
```

---

## 💡 Tips

### Copy-Paste Friendly

All commands in these guides are:
- ✅ **Tested** on Raspberry Pi 5 ARM64
- ✅ **Copy-paste ready** (no syntax errors)
- ✅ **Commented** for clarity
- ✅ **Safe** (destructive commands clearly marked)

### Command Format

```bash
# ℹ️ This is a comment explaining what the command does
command --flags arguments

# ⚠️ Destructive commands are marked with warning
# DANGEROUS: This will delete data
dangerous-command --force
```

### Variables

When you see placeholders, replace with your values:

```bash
# Replace CONTAINER_NAME with actual name
docker logs CONTAINER_NAME

# Example:
docker logs supabase-auth
```

---

## 📱 Mobile/Tablet Access

For SSH access from mobile devices:

**iOS:** [Termius](https://apps.apple.com/app/termius/id549039908)
**Android:** [JuiceSSH](https://play.google.com/store/apps/details?id=com.sonelli.juicessh)

Both support:
- SSH key authentication
- Session management
- Port forwarding
- Snippet library (save frequently used commands)

---

## 🆘 Emergency Commands

### System Won't Boot
1. Connect monitor and keyboard directly
2. Enter recovery mode (hold Shift during boot)
3. Remove `pagesize=4k` from `/boot/firmware/cmdline.txt`
4. Reboot and troubleshoot

### SSH Locked Out
1. Connect monitor and keyboard
2. Login locally
3. Check `/etc/ssh/sshd_config`
4. Restart SSH: `sudo systemctl restart ssh`

### Docker Issues
```bash
# Complete Docker reset (last resort)
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker
```

---

## 🔗 Related Documentation

- [Main README](../README.md) - Project overview
- [Installation Scripts](../scripts/) - Automated setup scripts
- [Knowledge Base](../docs/) - Detailed technical documentation
- [Troubleshooting](../docs/04-TROUBLESHOOTING/) - Problem-specific guides

---

<p align="center">
  <strong>📟 Master Your Pi with Terminal Commands 📟</strong>
</p>

<p align="center">
  <sub>All commands tested and verified on Raspberry Pi 5 ARM64</sub>
</p>
