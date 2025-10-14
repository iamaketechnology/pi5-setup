# 🚀 Quick Start - Maintenance Scripts

Commandes rapides pour lancer les scripts de maintenance.

---

## 📥 Installation (Curl One-Liner)

```bash
# Depuis GitHub (utiliser le bon commit/branch)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/maintenance/backup/generic-backup-rotate.sh | sudo bash
```

---

## 🔄 BACKUP

### Backup manuel

```bash
cd /home/pi/pi5-setup

# Backup Supabase
BACKUP_NAME_PREFIX=supabase \
POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres" \
DATA_PATHS="/home/pi/stacks/supabase/volumes" \
sudo bash maintenance/backup/generic-backup-rotate.sh

# Backup Traefik
BACKUP_NAME_PREFIX=traefik \
DATA_PATHS="/home/pi/stacks/traefik/letsencrypt,/home/pi/stacks/traefik/logs" \
sudo bash maintenance/backup/generic-backup-rotate.sh
```

### Restauration

```bash
# Restaurer backup
POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres" \
DATA_TARGETS="/home/pi/stacks/supabase/volumes" \
sudo bash maintenance/backup/generic-restore.sh /opt/backups/supabase-20250114-153045.tar.gz
```

---

## 📊 MONITORING

### Healthcheck

```bash
cd /home/pi/pi5-setup

# Healthcheck Supabase
HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:54323/status" \
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
sudo bash maintenance/monitoring/generic-healthcheck.sh

# Voir rapport
cat /opt/reports/healthcheck-*.md | tail -50
```

### Collecte logs

```bash
# Collecter logs
DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase" \
TAIL_LINES=2000 \
sudo bash maintenance/monitoring/generic-logs-collect.sh

# Extraire et analyser
cd /tmp && tar -xzf /opt/reports/logs-*.tar.gz
grep -i error logs-*/*.log
```

---

## 🎛️ MANAGEMENT

### Stack Manager (TUI)

```bash
cd /home/pi/pi5-setup

# Mode interactif (recommandé)
sudo bash maintenance/management/docker-stack-manager.sh interactive

# Commandes directes
sudo bash maintenance/management/docker-stack-manager.sh status
sudo bash maintenance/management/docker-stack-manager.sh ram
sudo bash maintenance/management/docker-stack-manager.sh stop jellyfin
sudo bash maintenance/management/docker-stack-manager.sh start supabase
```

### Update avec rollback

```bash
# Mise à jour Supabase
COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase \
HEALTHCHECK_URL=http://localhost:8000/health \
sudo bash maintenance/management/generic-update-rollback.sh update

# Rollback si problème
COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase \
sudo bash maintenance/management/generic-update-rollback.sh rollback
```

### Automation (systemd timers)

```bash
# 1. Créer wrapper backup
sudo tee /usr/local/bin/backup-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export BACKUP_TARGET_DIR=/opt/backups
export BACKUP_NAME_PREFIX=supabase
export POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
/home/pi/pi5-setup/maintenance/backup/generic-backup-rotate.sh
EOF
sudo chmod +x /usr/local/bin/backup-supabase.sh

# 2. Configurer timer quotidien
BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh \
BACKUP_SCHEDULE=daily \
sudo bash maintenance/management/generic-scheduler-setup.sh

# 3. Vérifier
systemctl list-timers | grep pi5-backup
```

---

## 🔒 SECURITY

### Fix Portainer (localhost only)

```bash
cd /home/pi/pi5-setup

# Migrer vers localhost
sudo bash maintenance/security/fix-portainer-localhost.sh

# Accès distant via SSH tunnel
ssh -L 8080:localhost:8080 pi@192.168.1.74
# Puis ouvrir : http://localhost:8080
```

---

## 📋 Workflows Complets

### Setup maintenance Supabase (tout automatiser)

```bash
cd /home/pi/pi5-setup

# 1. Backup quotidien
sudo tee /usr/local/bin/backup-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export BACKUP_NAME_PREFIX=supabase
export POSTGRES_DSN="postgres://postgres:VOTRE_PASSWORD@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
/home/pi/pi5-setup/maintenance/backup/generic-backup-rotate.sh
EOF

# 2. Healthcheck horaire
sudo tee /usr/local/bin/healthcheck-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export HTTP_ENDPOINTS="http://localhost:8000/health"
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
/home/pi/pi5-setup/maintenance/monitoring/generic-healthcheck.sh
EOF

# 3. Logs hebdomadaire
sudo tee /usr/local/bin/logs-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
/home/pi/pi5-setup/maintenance/monitoring/generic-logs-collect.sh
EOF

# 4. Permissions
sudo chmod +x /usr/local/bin/{backup,healthcheck,logs}-supabase.sh

# 5. Scheduler
BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh \
HEALTHCHECK_SCRIPT=/usr/local/bin/healthcheck-supabase.sh \
LOGS_SCRIPT=/usr/local/bin/logs-supabase.sh \
BACKUP_SCHEDULE=daily \
HEALTHCHECK_SCHEDULE=hourly \
LOGS_SCHEDULE=weekly \
sudo bash maintenance/management/generic-scheduler-setup.sh

# 6. Démarrage auto
sudo bash maintenance/management/docker-stack-manager.sh enable supabase

# 7. Vérifier
systemctl list-timers | grep pi5
sudo bash maintenance/management/docker-stack-manager.sh status
```

---

## 🔍 Vérifications Rapides

```bash
# Backups existants
ls -lh /opt/backups/

# Derniers rapports
ls -lt /opt/reports/ | head -10

# RAM par stack
sudo bash maintenance/management/docker-stack-manager.sh ram

# Timers actifs
systemctl list-timers | grep pi5

# Logs timer
sudo journalctl -u pi5-backup.service -n 20
```

---

## 📚 Documentation Complète

- **README.md** : Guide principal
- **backup/README.md** : Documentation backup/restore
- **monitoring/README.md** : Documentation healthcheck/logs
- **management/README.md** : Documentation stack manager
- **security/README.md** : Documentation sécurité

---

**Version** : 1.0.0
