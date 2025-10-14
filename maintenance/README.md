# 🛠️ Maintenance Scripts - PI5-SETUP

Scripts de maintenance génériques réutilisables pour toutes les stacks Docker.

---

## 📂 Structure

```
maintenance/
├── backup/              # Sauvegarde et restauration
├── monitoring/          # Surveillance santé et logs
├── management/          # Gestion stacks Docker
└── security/            # Sécurité et audits
```

---

## 🔄 Backup (backup/)

| Script | Description | Usage |
|--------|-------------|-------|
| `generic-backup-rotate.sh` | Backup + rotation GFS (Daily/Weekly/Monthly) | `sudo bash backup/generic-backup-rotate.sh` |
| `generic-restore.sh` | Restauration depuis backup | `sudo bash backup/generic-restore.sh archive.tar.gz` |

**Variables** :
```bash
BACKUP_TARGET_DIR=/opt/backups
BACKUP_NAME_PREFIX=pi5
POSTGRES_DSN=postgres://user:pass@host:5432/db  # Optionnel
DATA_PATHS=/path1,/path2                         # Optionnel
KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6
```

---

## 📊 Monitoring (monitoring/)

| Script | Description | Usage |
|--------|-------------|-------|
| `generic-healthcheck.sh` | Rapport santé (Docker + HTTP + ressources) | `sudo bash monitoring/generic-healthcheck.sh` |
| `generic-logs-collect.sh` | Collecte logs système + Docker | `sudo bash monitoring/generic-logs-collect.sh` |

**Variables** :
```bash
# Healthcheck
REPORT_DIR=/opt/reports
HTTP_ENDPOINTS=http://localhost:8000,http://localhost:9000
DOCKER_COMPOSE_DIRS=/path/to/stack1,/path/to/stack2

# Logs
OUTPUT_DIR=/opt/reports
TAIL_LINES=1000
INCLUDE_SYSTEMD=1
INCLUDE_DMESG=1
```

---

## 🎛️ Management (management/)

| Script | Description | Usage |
|--------|-------------|-------|
| `docker-stack-manager.sh` | Gestion stacks (start/stop/status/RAM) | `sudo bash management/docker-stack-manager.sh status` |
| `generic-update-rollback.sh` | Mise à jour Docker Compose + rollback auto | `sudo bash management/generic-update-rollback.sh update` |
| `generic-scheduler-setup.sh` | Configuration cron/systemd timers | `sudo bash management/generic-scheduler-setup.sh` |

**Exemples** :
```bash
# Stack Manager
sudo bash management/docker-stack-manager.sh status
sudo bash management/docker-stack-manager.sh stop jellyfin
sudo bash management/docker-stack-manager.sh interactive  # TUI

# Update + Rollback
COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase \
HEALTHCHECK_URL=http://localhost:8000/health \
sudo bash management/generic-update-rollback.sh update
```

---

## 🔒 Security (security/)

| Script | Description | Usage |
|--------|-------------|-------|
| `fix-portainer-localhost.sh` | Migration Portainer vers localhost only | `sudo bash security/fix-portainer-localhost.sh` |

---

## ⚙️ Utilisation

### 1️⃣ Backup quotidien automatique

```bash
# Configuration
export BACKUP_TARGET_DIR=/opt/backups
export BACKUP_NAME_PREFIX=pi5-supabase
export POSTGRES_DSN="postgres://postgres:yourpass@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"

# Test manuel
sudo bash maintenance/backup/generic-backup-rotate.sh

# Automatiser (systemd timer)
BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh \
BACKUP_SCHEDULE=daily \
sudo bash maintenance/management/generic-scheduler-setup.sh
```

### 2️⃣ Healthcheck toutes les heures

```bash
# Configuration
export REPORT_DIR=/opt/reports
export HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:54323/status"
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"

# Test manuel
sudo bash maintenance/monitoring/generic-healthcheck.sh

# Automatiser
HEALTHCHECK_SCRIPT=/usr/local/bin/healthcheck-supabase.sh \
HEALTHCHECK_SCHEDULE=hourly \
sudo bash maintenance/management/generic-scheduler-setup.sh
```

### 3️⃣ Gestion RAM

```bash
# Voir consommation par stack
sudo bash maintenance/management/docker-stack-manager.sh ram

# Arrêter stack pour libérer RAM
sudo bash maintenance/management/docker-stack-manager.sh stop jellyfin

# Mode interactif (TUI)
sudo bash maintenance/management/docker-stack-manager.sh interactive
```

---

## 📋 Scripts Spécifiques par Stack

Chaque stack a ses propres wrappers dans :
```
01-infrastructure/<stack>/scripts/maintenance/
```

**Exemples** :
- `01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh`
- `01-infrastructure/email/scripts/maintenance/email-healthcheck.sh`

Ces wrappers appellent les scripts génériques avec la bonne configuration.

---

## 🔗 Scripts Connexes

| Catégorie | Scripts | Localisation |
|-----------|---------|--------------|
| **Installation** | Preflight checks, Docker install | `common-scripts/00-*.sh` |
| **Configuration** | Traefik setup, Secrets | `common-scripts/03-*.sh` |
| **Développement** | Onboard app, Monitoring bootstrap | `common-scripts/onboard-app.sh` |

---

## 📝 Conventions

### Nommage
- **generic-*.sh** : Scripts génériques réutilisables (variables)
- **docker-*.sh** : Scripts spécifiques Docker
- **fix-*.sh** : Scripts de correction/migration

### Variables d'environnement
Tous les scripts supportent :
```bash
--dry-run        # Simulation
--yes, -y        # Pas de confirmation
--verbose, -v    # Mode verbeux
--quiet, -q      # Mode silencieux
--no-color       # Sans couleurs
--help, -h       # Aide
```

---

## 🚀 Quick Start

```bash
# 1. Santé système
sudo bash maintenance/monitoring/generic-healthcheck.sh

# 2. Backup maintenant
BACKUP_NAME_PREFIX=pi5-all \
DATA_PATHS=/home/pi/stacks \
sudo bash maintenance/backup/generic-backup-rotate.sh

# 3. Gérer stacks
sudo bash maintenance/management/docker-stack-manager.sh interactive
```

---

**Version** : 1.0.0
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
