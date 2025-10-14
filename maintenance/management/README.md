# 🎛️ Management - Scripts Génériques

Scripts de gestion des stacks Docker (start/stop, mise à jour, scheduling).

---

## 📜 Scripts

### `docker-stack-manager.sh`

Gère facilement les stacks Docker (start/stop/status/RAM) avec TUI interactif.

**Commandes** :
```bash
status           # Affiche état de tous les stacks
list             # Alias pour status
ram              # Consommation RAM par stack (triée)
start <stack>    # Démarre un stack
stop <stack>     # Arrête un stack
restart <stack>  # Redémarre un stack
enable <stack>   # Active démarrage auto (systemd)
disable <stack>  # Désactive démarrage auto
interactive      # Mode TUI (recommandé)
```

**Variables** :
```bash
STACKS_BASE_DIR=/home/pi/stacks    # Dossier base des stacks
```

**Exemples** :

```bash
# Voir état global
sudo bash docker-stack-manager.sh status

# Consommation RAM (triée par usage)
sudo bash docker-stack-manager.sh ram

# Arrêter Jellyfin pour libérer RAM
sudo bash docker-stack-manager.sh stop jellyfin

# Redémarrer Supabase
sudo bash docker-stack-manager.sh restart supabase

# Activer démarrage auto au boot
sudo bash docker-stack-manager.sh enable supabase

# Mode interactif (TUI)
sudo bash docker-stack-manager.sh interactive
```

**Output status** :
```
STACK           STATUS       CONTAINERS  RAM (MB)  BOOT
─────           ──────       ──────────  ────────  ────
supabase        ✓ running    12          1847      enabled
traefik         ✓ running    1           24        enabled
jellyfin        ○ stopped    0           0         disabled
monitoring      ✓ running    3           156       enabled

RAM totale utilisée: 2027 MB
RAM système: 3456 MB / 8192 MB (42% utilisé, 4200 MB disponible)
```

**Mode TUI** :
- Navigation avec flèches
- Sélection stack → Actions (start/stop/enable/disable)
- Affichage RAM en temps réel

---

### `generic-update-rollback.sh`

Met à jour un stack Docker Compose avec rollback automatique si échec.

**Variables** :
```bash
COMPOSE_PROJECT_DIR=/path/to/stack          # Dossier docker-compose.yml (obligatoire)
HEALTHCHECK_URL=http://localhost:8000       # URL à tester après MAJ (optionnel)
BACKUP_IMAGES=1                             # Sauvegarder images actuelles (0/1)
ROLLBACK_ON_FAILURE=1                       # Rollback auto si healthcheck échoue (0/1)
```

**Commandes** :
```bash
update           # Mise à jour du stack
rollback         # Revenir à la version précédente
```

**Exemples** :

```bash
# Mise à jour Supabase avec rollback auto
export COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase
export HEALTHCHECK_URL=http://localhost:8000/health
sudo bash generic-update-rollback.sh update

# Mise à jour sans healthcheck (pas de rollback auto)
export COMPOSE_PROJECT_DIR=/home/pi/stacks/traefik
export ROLLBACK_ON_FAILURE=0
sudo bash generic-update-rollback.sh update

# Rollback manuel
export COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase
sudo bash generic-update-rollback.sh rollback

# Dry-run (test sans exécution)
sudo bash generic-update-rollback.sh update --dry-run
```

**Process** :
1. Sauvegarde images actuelles
2. `docker compose pull` (télécharge nouvelles images)
3. `docker compose down` (arrêt)
4. `docker compose up -d` (redémarrage)
5. Healthcheck HTTP
6. Si échec → Rollback automatique

**⚠️ Sécurité** :
- Images précédentes sauvegardées dans `.compose-backup/images.txt`
- Rollback restaure exactement les mêmes versions
- Toujours tester sur environnement dev avant prod

---

### `generic-scheduler-setup.sh`

Configure des tâches planifiées (systemd timers ou cron) pour backup/healthcheck/logs.

**Variables** :
```bash
SCHEDULER_MODE=systemd                       # systemd (défaut) ou cron
BACKUP_SCRIPT=/usr/local/bin/backup.sh       # Script backup
HEALTHCHECK_SCRIPT=/usr/local/bin/health.sh  # Script healthcheck
LOGS_SCRIPT=/usr/local/bin/logs.sh           # Script logs
BACKUP_SCHEDULE=daily                        # daily, hourly, weekly, monthly
HEALTHCHECK_SCHEDULE=hourly                  # ou cron expression (systemd)
LOGS_SCHEDULE=weekly                         # ou cron expression (systemd)
```

**Exemples** :

```bash
# Configuration complète
export BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh
export HEALTHCHECK_SCRIPT=/usr/local/bin/healthcheck-supabase.sh
export LOGS_SCRIPT=/usr/local/bin/logs-collect.sh
export BACKUP_SCHEDULE=daily
export HEALTHCHECK_SCHEDULE=hourly
export LOGS_SCHEDULE=weekly
sudo bash generic-scheduler-setup.sh

# Vérifier timers
systemctl list-timers | grep pi5

# Voir logs
sudo journalctl -u pi5-backup.service -n 50
sudo journalctl -u pi5-healthcheck.service -f

# Tester manuellement
sudo systemctl start pi5-backup.service
```

**Systemd timers créés** :
- `/etc/systemd/system/pi5-backup.service`
- `/etc/systemd/system/pi5-backup.timer`
- `/etc/systemd/system/pi5-healthcheck.service`
- `/etc/systemd/system/pi5-healthcheck.timer`
- `/etc/systemd/system/pi5-logs.service`
- `/etc/systemd/system/pi5-logs.timer`

**Schedules possibles** (systemd) :
- `daily` : Tous les jours à minuit
- `hourly` : Toutes les heures
- `weekly` : Tous les lundis à minuit
- `monthly` : Premier jour du mois
- `*-*-* 02:00:00` : Tous les jours à 2h du matin
- `Mon,Wed,Fri *-*-* 12:00:00` : Lundi/Mercredi/Vendredi à midi

---

## 🔗 Workflows Complets

### Setup complet maintenance Supabase

```bash
# 1. Créer wrappers
sudo tee /usr/local/bin/backup-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export BACKUP_TARGET_DIR=/opt/backups
export BACKUP_NAME_PREFIX=supabase
export POSTGRES_DSN="postgres://postgres:yourpass@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
/home/pi/pi5-setup/maintenance/backup/generic-backup-rotate.sh
EOF

sudo tee /usr/local/bin/healthcheck-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:54323/status"
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
/home/pi/pi5-setup/maintenance/monitoring/generic-healthcheck.sh
EOF

sudo tee /usr/local/bin/logs-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
export TAIL_LINES=2000
/home/pi/pi5-setup/maintenance/monitoring/generic-logs-collect.sh
EOF

sudo chmod +x /usr/local/bin/{backup,healthcheck,logs}-supabase.sh

# 2. Configurer scheduling
export BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh
export HEALTHCHECK_SCRIPT=/usr/local/bin/healthcheck-supabase.sh
export LOGS_SCRIPT=/usr/local/bin/logs-supabase.sh
export BACKUP_SCHEDULE=daily
export HEALTHCHECK_SCHEDULE=hourly
export LOGS_SCHEDULE=weekly
sudo bash generic-scheduler-setup.sh

# 3. Activer démarrage auto
sudo bash docker-stack-manager.sh enable supabase

# 4. Vérifier
systemctl list-timers | grep pi5
sudo bash docker-stack-manager.sh status
```

---

### Mise à jour sécurisée

```bash
# 1. Backup avant MAJ
sudo /usr/local/bin/backup-supabase.sh

# 2. Mise à jour avec rollback auto
export COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase
export HEALTHCHECK_URL=http://localhost:8000/health
sudo bash generic-update-rollback.sh update

# 3. Si problème, rollback manuel
sudo bash generic-update-rollback.sh rollback

# 4. Vérifier santé
sudo bash docker-stack-manager.sh status
curl http://localhost:8000/health
```

---

## 📊 Monitoring

### Vérifier timers systemd

```bash
# Liste tous les timers
systemctl list-timers

# Dernière exécution
systemctl status pi5-backup.timer
systemctl status pi5-healthcheck.timer

# Logs en temps réel
sudo journalctl -u pi5-backup.service -f
sudo journalctl -u pi5-healthcheck.service -f
```

### Désactiver timer

```bash
sudo systemctl stop pi5-backup.timer
sudo systemctl disable pi5-backup.timer
```

### Modifier schedule

```bash
# Éditer timer
sudo systemctl edit --full pi5-backup.timer

# Modifier ligne OnCalendar
# OnCalendar=daily          → OnCalendar=*-*-* 03:00:00

# Recharger
sudo systemctl daemon-reload
sudo systemctl restart pi5-backup.timer
```

---

## 🆘 Troubleshooting

### Stack Manager erreur "jq not found"

```bash
sudo apt update
sudo apt install -y jq
```

### Update échoue avec rollback

```bash
# Voir logs
docker logs supabase-kong --tail 50

# Tester healthcheck manuellement
curl -v http://localhost:8000/health

# Rollback manuel
export COMPOSE_PROJECT_DIR=/home/pi/stacks/supabase
sudo bash generic-update-rollback.sh rollback
```

### Timer ne s'exécute pas

```bash
# Vérifier script existe
ls -la /usr/local/bin/backup-supabase.sh

# Tester manuellement
sudo /usr/local/bin/backup-supabase.sh

# Vérifier timer enabled
systemctl is-enabled pi5-backup.timer

# Forcer exécution
sudo systemctl start pi5-backup.service
```

---

**Version** : 1.0.0
