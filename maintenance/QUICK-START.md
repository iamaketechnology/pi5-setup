# 🚀 Quick Start - Curl One-Liners

Lancer directement depuis GitHub (remplacer `main` par le commit/tag voulu).

---

## 🔄 BACKUP

```bash
# Backup Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/04-backup-rotate.sh | \
BACKUP_NAME_PREFIX=supabase \
POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres" \
DATA_PATHS="/home/pi/stacks/supabase/volumes" \
sudo bash
```

---

## 📊 MONITORING

```bash
# Healthcheck système
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/05-healthcheck-report.sh | \
HTTP_ENDPOINTS="http://localhost:8000/health" \
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
sudo bash

# Collecter logs
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/07-logs-collect.sh | \
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
sudo bash
```

---

## 🎛️ MANAGEMENT

```bash
# Stack Manager (TUI)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/09-stack-manager.sh | \
sudo bash -s interactive

# Status
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/09-stack-manager.sh | \
sudo bash -s status

# RAM usage
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/09-stack-manager.sh | \
sudo bash -s ram
```

---

## 🔒 SECURITY

```bash
# Fix Portainer localhost
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/common-scripts/fix-portainer-localhost.sh | \
sudo bash
```

---

## 📥 Si repo cloné localement

```bash
cd /home/pi/pi5-setup

# Backup
sudo bash maintenance/backup/generic-backup-rotate.sh

# Healthcheck
sudo bash maintenance/monitoring/generic-healthcheck.sh

# Stack Manager
sudo bash maintenance/management/docker-stack-manager.sh interactive

# Fix Portainer
sudo bash maintenance/security/fix-portainer-localhost.sh
```

---

📚 **Doc complète** : `maintenance/README.md`
