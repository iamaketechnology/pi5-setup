# 🚀 Quick Start - Commandes Maintenance

---

## 🔄 BACKUP

```bash
# Backup Supabase
cd /home/pi/pi5-setup
BACKUP_NAME_PREFIX=supabase \
POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres" \
DATA_PATHS="/home/pi/stacks/supabase/volumes" \
sudo bash maintenance/backup/generic-backup-rotate.sh

# Restaurer
POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres" \
DATA_TARGETS="/home/pi/stacks/supabase/volumes" \
sudo bash maintenance/backup/generic-restore.sh /opt/backups/supabase-*.tar.gz
```

---

## 📊 MONITORING

```bash
# Healthcheck
cd /home/pi/pi5-setup
HTTP_ENDPOINTS="http://localhost:8000/health" \
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
sudo bash maintenance/monitoring/generic-healthcheck.sh

# Collecter logs
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
sudo bash maintenance/monitoring/generic-logs-collect.sh
```

---

## 🎛️ MANAGEMENT

```bash
# Stack Manager (TUI)
cd /home/pi/pi5-setup
sudo bash maintenance/management/docker-stack-manager.sh interactive

# Commandes rapides
sudo bash maintenance/management/docker-stack-manager.sh status
sudo bash maintenance/management/docker-stack-manager.sh ram
sudo bash maintenance/management/docker-stack-manager.sh stop jellyfin

# Update + rollback auto
COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase \
HEALTHCHECK_URL=http://localhost:8000/health \
sudo bash maintenance/management/generic-update-rollback.sh update
```

---

## 🔒 SECURITY

```bash
# Fix Portainer localhost
cd /home/pi/pi5-setup
sudo bash maintenance/security/fix-portainer-localhost.sh
```

---

📚 **Doc complète** : `maintenance/README.md`
