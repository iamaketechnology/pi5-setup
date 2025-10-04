# 🛠️ Common Scripts - Utilitaires DevOps Pi5

> **Bibliothèque de scripts réutilisables pour tous les stacks du serveur Pi5**

---

## 📋 Vue d'Ensemble

Ces scripts fournissent des **fonctionnalités DevOps** communes (backup, monitoring, sécurité, etc.) utilisables par **tous les stacks** du serveur (Supabase, Gitea, Monitoring, etc.).

### 🎯 Philosophie

- ✅ **Réutilisables** - Un seul script, plusieurs stacks
- ✅ **Standardisés** - Options communes (`--dry-run`, `--verbose`, etc.)
- ✅ **Testés** - Mode dry-run pour tout tester sans risque
- ✅ **Documentés** - Aide intégrée (`--help`)

### 🏗️ Architecture

```
common-scripts/                    # Scripts génériques
├── lib.sh                         # Bibliothèque partagée
└── [scripts numérotés]            # Outils DevOps

pi5-supabase-stack/
└── scripts/maintenance/           # Wrappers Supabase
    ├── _supabase-common.sh        # Config Supabase
    └── supabase-*.sh              # Appelle common-scripts/
```

**Les stacks n'implémentent PAS la logique** - Ils configurent et appellent `common-scripts/`.

---

## 📚 Scripts Disponibles

### 🔧 Infrastructure & Sécurité

| Script | Description | Quand l'utiliser | Exemple |
|--------|-------------|------------------|---------|
| **`00-preflight-checks.sh`** | Vérifications pré-installation | Avant déploiement nouveau stack | Check RAM, page size, arch |
| **`01-system-hardening.sh`** | Sécurisation système | Post-installation OS | UFW, Fail2ban, SSH keys |
| **`02-docker-install-verify.sh`** | Installation Docker | Setup initial serveur | Docker + Compose + tests |
| **`03-traefik-setup.sh`** | Reverse proxy SSL/TLS | Stack accessible en HTTPS | Traefik + Let's Encrypt |

### 💾 Backup & Restauration

| Script | Description | Quand l'utiliser | Exemple |
|--------|-------------|------------------|---------|
| **`04-backup-rotate.sh`** | Sauvegarde + rotation GFS | Backup automatique données | PostgreSQL, volumes Docker |
| **`04b-restore-from-backup.sh`** | Restauration guidée | Après incident/perte données | Restore depuis backup |

### 📊 Monitoring & Maintenance

| Script | Description | Quand l'utiliser | Exemple |
|--------|-------------|------------------|---------|
| **`05-healthcheck-report.sh`** | Rapport santé système | Vérification quotidienne | Status services, disk, RAM |
| **`06-update-and-rollback.sh`** | Mise à jour + rollback | Update stack avec sécurité | Pull images + rollback auto |
| **`07-logs-collect.sh`** | Collecte logs compressés | Debug problème | Archive logs tous services |
| **`08-scheduler-setup.sh`** | Automatisation tâches | Programmer backups/checks | Systemd timers ou cron |
| **`09-stack-manager.sh`** | Gestion stacks Docker | Contrôler RAM/boot | Start/stop stacks, RAM usage |

### 🚀 Stacks Avancés

| Script | Description | Quand l'utiliser | Exemple |
|--------|-------------|------------------|---------|
| **`monitoring-bootstrap.sh`** | Stack Prometheus/Grafana | Monitoring centralisé | Métriques tous stacks |
| **`secrets-setup.sh`** | Générateur `.env` sécurisé | Nouveau stack | Passwords forts auto |
| **`onboard-app.sh`** | Bootstrap nouveau service | Ajouter service au serveur | Config + Traefik routing |
| **`selftest-benchmark.sh`** | Benchmarks & baseline | Valider performances | CPU, I/O, réseau |
| **`incident-mode.sh`** | Mode incident | Problème critique serveur | Arrêt sélectif services |

### 📦 Bibliothèque

| Script | Description | Usage |
|--------|-------------|-------|
| **`lib.sh`** | Fonctions partagées | `source common-scripts/lib.sh` |

**Fonctions disponibles :**
- `log_info`, `log_warn`, `log_error`, `log_success`, `log_debug`
- `fatal` (erreur + exit)
- `parse_common_args` (parsing options)
- `require_root`, `run_cmd`
- Gestion couleurs automatique

---

## 🎛️ Options Communes

**Tous les scripts supportent ces options :**

| Option | Description | Exemple |
|--------|-------------|---------|
| `--dry-run` | Simule sans exécuter | Test avant déploiement |
| `--yes`, `-y` | Mode non-interactif | Scripts automatisés |
| `--verbose`, `-v` | Logs détaillés | Debug problème |
| `--quiet`, `-q` | Minimal output | Cron jobs |
| `--no-color` | Sans couleurs | Logs fichiers |
| `--help`, `-h` | Aide du script | Documentation |

---

## 💡 Exemples d'Utilisation

### 🔍 Vérification Pré-Installation

```bash
# Vérifier que le Pi5 est prêt pour un nouveau stack
sudo common-scripts/00-preflight-checks.sh --verbose

# Checklist attendue :
# ✅ Architecture ARM64
# ✅ Page size 4096
# ✅ RAM 16GB
# ✅ Espace disque >30GB
```

### 🔒 Sécuriser le Système

```bash
# Activer firewall, fail2ban, SSH keys
sudo common-scripts/01-system-hardening.sh --yes

# Options personnalisables :
sudo SSH_PORT=2222 UFW_RULES="22,80,443" common-scripts/01-system-hardening.sh
```

### 💾 Backup Automatique

```bash
# Backup manuel immédiat
sudo BACKUP_NAME_PREFIX=supabase \
     DATA_PATHS=/home/pi/stacks/supabase/volumes \
     POSTGRES_DSN="postgres://user:pass@localhost/db" \
     common-scripts/04-backup-rotate.sh

# Avec rotation GFS (Grandfather-Father-Son) :
# - 7 backups quotidiens
# - 4 backups hebdomadaires
# - 12 backups mensuels
```

### 📊 Healthcheck Quotidien

```bash
# Rapport santé complet
sudo HTTP_ENDPOINTS="http://localhost:3000,http://localhost:8000" \
     DOCKER_COMPOSE_DIRS=/home/pi/stacks/supabase \
     common-scripts/05-healthcheck-report.sh

# Génère rapport : /opt/healthcheck-YYYYMMDD-HHMMSS.txt
```

### ⏰ Automatiser les Tâches

```bash
# Configurer backups quotidiens + healthchecks horaires
sudo SCHEDULER_MODE=systemd \
     BACKUP_SCRIPT=/home/pi/stacks/supabase/scripts/maintenance/supabase-backup.sh \
     BACKUP_SCHEDULE=daily \
     HEALTHCHECK_SCRIPT=/home/pi/stacks/supabase/scripts/maintenance/supabase-healthcheck.sh \
     HEALTHCHECK_SCHEDULE=hourly \
     common-scripts/08-scheduler-setup.sh

# Vérifie timers :
systemctl list-timers
```

### 🎛️ Gérer les Stacks (RAM/Boot)

```bash
# Mode interactif (recommandé)
sudo common-scripts/09-stack-manager.sh interactive

# Voir état de tous les stacks + consommation RAM
sudo common-scripts/09-stack-manager.sh status

# Arrêter un stack pour libérer RAM
sudo common-scripts/09-stack-manager.sh stop jellyfin

# Démarrer un stack
sudo common-scripts/09-stack-manager.sh start jellyfin

# Désactiver démarrage auto d'un stack au boot
sudo common-scripts/09-stack-manager.sh disable gitea

# Voir consommation RAM par stack (trié)
sudo common-scripts/09-stack-manager.sh ram

# Documentation complète :
# common-scripts/STACK-MANAGER.md
```

---

## 🧪 Mode Dry-Run (Test sans Risque)

**Toujours tester avec `--dry-run` avant exécution réelle :**

```bash
# Simulation backup
sudo common-scripts/04-backup-rotate.sh --dry-run --verbose

# Affiche :
# [DRY-RUN] Création backup supabase-20251004.tar.gz
# [DRY-RUN] Sauvegarde PostgreSQL
# [DRY-RUN] Archive volumes/...
# [DRY-RUN] Rotation : garde 7 quotidiens, 4 hebdos, 12 mensuels
```

**Aucune modification système en mode dry-run !**

---

## 🔗 Intégration avec les Stacks

### Exemple : Supabase

**Structure :**
```
pi5-supabase-stack/scripts/maintenance/
├── _supabase-common.sh              # Config spécifique Supabase
├── supabase-backup.sh               # Wrapper → common-scripts/04-backup-rotate.sh
├── supabase-healthcheck.sh          # Wrapper → common-scripts/05-healthcheck-report.sh
└── supabase-scheduler.sh            # Wrapper → common-scripts/08-scheduler-setup.sh
```

**Comment ça marche :**

1. **L'utilisateur appelle** le script Supabase :
   ```bash
   sudo pi5-supabase-stack/scripts/maintenance/supabase-backup.sh
   ```

2. **Le wrapper configure** les variables Supabase :
   ```bash
   # supabase-backup.sh
   SUPABASE_DIR=/home/pi/stacks/supabase
   POSTGRES_DSN="postgres://postgres:xxxxx@localhost:5432/postgres"
   DATA_PATHS="${SUPABASE_DIR}/volumes"
   ```

3. **Le wrapper appelle** le script commun :
   ```bash
   exec common-scripts/04-backup-rotate.sh "$@"
   ```

4. **Le script commun** fait le travail avec la config Supabase

**Avantage :** Logique backup réutilisable pour Gitea, Nextcloud, etc. sans réécrire !

---

## 📖 Documentation par Stack

- **[Supabase Maintenance →](../pi5-supabase-stack/scripts/maintenance/README.md)** - Backup, healthcheck, scheduler
- **Gitea Maintenance** - À venir (Phase 3)
- **Monitoring Maintenance** - À venir (Phase 2)

---

## 🔧 Variables d'Environnement

### Communes à Tous Scripts

| Variable | Défaut | Description |
|----------|--------|-------------|
| `DRY_RUN` | `0` | Mode simulation (1=actif) |
| `ASSUME_YES` | `0` | Confirme tout (1=actif) |
| `VERBOSE` | `0` | Verbosité (0-2) |
| `QUIET` | `0` | Minimal output (1=actif) |
| `NO_COLOR` | `0` | Sans couleurs (1=actif) |

### Spécifiques par Script

Voir `--help` de chaque script pour la liste complète.

**Exemples :**
```bash
# 04-backup-rotate.sh
BACKUP_TARGET_DIR=/mnt/backups
BACKUP_NAME_PREFIX=myapp
POSTGRES_DSN="postgres://..."
DATA_PATHS=/path/to/volumes

# 05-healthcheck-report.sh
HTTP_ENDPOINTS="http://localhost:3000,http://localhost:8000"
DOCKER_COMPOSE_DIRS=/home/pi/stacks/supabase
REPORT_DIR=/var/reports

# 08-scheduler-setup.sh
SCHEDULER_MODE=systemd  # ou cron
BACKUP_SCHEDULE=daily
HEALTHCHECK_SCHEDULE=hourly
```

---

## 🆘 Troubleshooting

### Script ne trouve pas `lib.sh`

**Erreur :**
```
source: common-scripts/lib.sh: No such file or directory
```

**Solution :**
```bash
# Vérifier structure :
ls -la common-scripts/lib.sh

# Exécuter depuis la racine du repo :
cd /path/to/pi5-setup
sudo common-scripts/04-backup-rotate.sh
```

### Permissions Denied

**Erreur :**
```
Permission denied
```

**Solution :**
```bash
# La plupart des scripts nécessitent root :
sudo common-scripts/script.sh

# Ou rendre exécutable :
chmod +x common-scripts/*.sh
```

### Script ne fait rien (dry-run actif)

**Symptôme :**
```
[DRY-RUN] ...
```

**Solution :**
```bash
# Enlever --dry-run ou DRY_RUN=0 :
sudo common-scripts/script.sh  # Sans --dry-run
```

---

## 🚀 Roadmap

### Phase 1 : Fondations ✅
- [x] Bibliothèque `lib.sh`
- [x] Scripts infrastructure (00-02)
- [x] Scripts backup/restore (04-04b)
- [x] Scripts monitoring (05-07)
- [x] Scheduler (08)
- [x] Intégration Supabase

### Phase 2 : Stacks Avancés (Q1 2025)
- [ ] Traefik setup (03)
- [ ] Monitoring stack (Prometheus/Grafana)
- [ ] Intégration Gitea
- [ ] Secrets management

### Phase 3 : Production (Q2 2025)
- [ ] Incident mode
- [ ] Update/rollback automatique
- [ ] Benchmarks
- [ ] Alerting

---

## 🤝 Contribution

**Pour ajouter un nouveau script :**

1. Utiliser `lib.sh` pour logs et parsing
2. Supporter options communes (`--dry-run`, etc.)
3. Ajouter `usage()` avec exemples
4. Tester avec `--dry-run`
5. Documenter dans ce README

**Template script :**
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: mon-script.sh [options]
Description...
USAGE
}

parse_common_args "$@"
if [[ ${SHOW_HELP} -eq 1 ]]; then usage; exit 0; fi
require_root

# Votre logique ici
log_info "Démarrage..."
```

---

<p align="center">
  <strong>🛠️ Boîte à Outils DevOps pour Pi5 🛠️</strong>
</p>

<p align="center">
  <sub>Scripts réutilisables • Standards DevOps • Production-ready</sub>
</p>
