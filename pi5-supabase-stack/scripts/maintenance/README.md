# 🔧 Maintenance Supabase Pi5

> **Scripts de maintenance spécialisés pour le stack Supabase self-hosted**

---

## 📋 Vue d'Ensemble

Ces scripts **wrappers** configurent et appellent les **[common-scripts](../../../../common-scripts/)** avec des paramètres spécifiques à Supabase.

### 🎯 Pourquoi des Wrappers ?

**Au lieu de dupliquer la logique :**
- ❌ Créer un script backup spécifique Supabase
- ❌ Créer un script healthcheck spécifique Supabase
- ❌ Répéter le code pour chaque stack

**On réutilise les scripts communs :**
- ✅ Wrapper configure les variables Supabase
- ✅ Appelle le script commun avec bonne config
- ✅ Logique réutilisable pour tous les stacks (Gitea, Nextcloud, etc.)

---

## 📚 Scripts Disponibles

| Script | Description | Utilisation | Fréquence Recommandée |
|--------|-------------|-------------|------------------------|
| **`supabase-backup.sh`** | Backup PostgreSQL + volumes | Sauvegarder données | **Quotidien** (3h du matin) |
| **`supabase-restore.sh`** | Restauration depuis archive | Après incident | **À la demande** |
| **`supabase-healthcheck.sh`** | Rapport santé services | Vérifier status | **Horaire** (toutes les heures) |
| **`supabase-update.sh`** | Mise à jour stack | Update images Docker | **Hebdomadaire** ou **manuel** |
| **`supabase-logs.sh`** | Collecte logs compressés | Debug problème | **Hebdomadaire** ou **manuel** |
| **`supabase-scheduler.sh`** | Configure automatisation | Setup timers systemd | **Une fois** (post-install) |

### 📦 Configuration

| Fichier | Description | Usage |
|---------|-------------|-------|
| **`_supabase-common.sh`** | Variables & paths Supabase | Sourcé par tous les scripts |

---

## 🚀 Quick Start

### 1️⃣ Backup Manuel

```bash
# Backup immédiat de Supabase
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-backup.sh

# Ou depuis le répertoire :
cd ~/pi5-setup/pi5-supabase-stack/scripts/maintenance
sudo ./supabase-backup.sh
```

**Ce qui est sauvegardé :**
- ✅ Base de données PostgreSQL (pg_dump)
- ✅ Volumes Docker (`volumes/db/`, `volumes/storage/`, etc.)
- ✅ Fichiers config (`.env`, `docker-compose.yml`)

**Emplacement :**
- 📁 `/home/pi/backups/supabase/`
- 📦 Format : `supabase-YYYYMMDD-HHMMSS.tar.gz`

**Rotation automatique (GFS) :**
- 7 backups quotidiens
- 4 backups hebdomadaires
- 12 backups mensuels

### 2️⃣ Healthcheck Quotidien

```bash
# Rapport santé complet
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-healthcheck.sh --verbose
```

**Ce qui est vérifié :**
- ✅ Status containers Docker (`docker compose ps`)
- ✅ Endpoints HTTP (`http://localhost:3000`, `http://localhost:8000`)
- ✅ Connexion PostgreSQL
- ✅ Espace disque
- ✅ RAM disponible

**Sortie :**
- 📄 Rapport texte : `~/stacks/supabase/reports/supabase-health-YYYYMMDD.txt`
- 📊 Format : TXT ou MD

### 3️⃣ Automatiser avec Scheduler

```bash
# Configurer backups quotidiens + healthchecks horaires
sudo ~/pi5-setup/pi5-supabase-stack/scripts/maintenance/supabase-scheduler.sh

# Vérifier que les timers sont actifs
systemctl list-timers | grep supabase
```

**Timers créés :**
- ⏰ `pi5-supabase-backup.timer` - Quotidien (3h du matin)
- ⏰ `pi5-supabase-healthcheck.timer` - Horaire
- ⏰ `pi5-supabase-logs.timer` - Hebdomadaire

---

## 💡 Exemples d'Utilisation Avancés

### 🔍 Test sans Risque (Dry-Run)

```bash
# Simuler un backup sans l'exécuter
sudo ./supabase-backup.sh --dry-run --verbose

# Affiche ce qui serait fait :
# [DRY-RUN] Backup PostgreSQL vers /home/pi/backups/supabase/...
# [DRY-RUN] Archive volumes/db/...
# [DRY-RUN] Rotation : garde 7 quotidiens, 4 hebdos, 12 mensuels
```

### 💾 Backup Personnalisé

```bash
# Backup vers un emplacement spécifique
sudo BACKUP_TARGET_DIR=/mnt/external-hdd/supabase \
     ./supabase-backup.sh

# Backup avec préfixe custom
sudo BACKUP_NAME_PREFIX=supabase-prod \
     ./supabase-backup.sh
```

### 📊 Healthcheck avec Notification

```bash
# Générer rapport + envoyer par email (si configuré)
sudo REPORT_FORMAT=md \
     NOTIFY_EMAIL=admin@example.com \
     ./supabase-healthcheck.sh

# Ou enregistrer dans un fichier custom
sudo REPORT_DIR=/var/reports \
     REPORT_PREFIX=supabase-daily \
     ./supabase-healthcheck.sh
```

### 🔄 Restauration depuis Backup

```bash
# Lister backups disponibles
ls -lh /home/pi/backups/supabase/

# Restaurer depuis un backup spécifique
sudo BACKUP_FILE=/home/pi/backups/supabase/supabase-20251004-030000.tar.gz \
     ./supabase-restore.sh

# Mode interactif (choisir dans liste)
sudo ./supabase-restore.sh
```

### 📝 Collecte Logs pour Debug

```bash
# Collecter tous les logs Supabase
sudo ./supabase-logs.sh

# Archive créée : ~/stacks/supabase/logs/supabase-logs-YYYYMMDD.tar.gz
```

**Contient :**
- Logs Docker de tous les services
- Logs système (journalctl)
- Config files (`.env`, `docker-compose.yml`)
- Status containers

### 🔧 Mise à Jour Stack Supabase

```bash
# Vérifier mises à jour disponibles
sudo ./supabase-update.sh check

# Mettre à jour (avec backup automatique avant)
sudo ./supabase-update.sh update --yes

# Rollback si problème
sudo ./supabase-update.sh rollback
```

---

## ⚙️ Configuration Avancée

### Variables d'Environnement

**Définies dans `_supabase-common.sh` :**

| Variable | Défaut | Description |
|----------|--------|-------------|
| `SUPABASE_DIR` | `/home/pi/stacks/supabase` | Répertoire installation Supabase |
| `SUPABASE_ENV_FILE` | `${SUPABASE_DIR}/.env` | Fichier variables Supabase |
| `SUPABASE_POSTGRES_DSN` | Auto-détecté depuis `.env` | Connexion PostgreSQL |
| `BACKUP_TARGET_DIR` | `/home/pi/backups/supabase` | Destination backups |
| `REPORT_DIR` | `${SUPABASE_DIR}/reports` | Rapports healthcheck |

**Surcharger les variables :**

```bash
# Exemple : Backup vers NAS
sudo SUPABASE_DIR=/mnt/nas/supabase \
     BACKUP_TARGET_DIR=/mnt/nas/backups \
     ./supabase-backup.sh
```

### Personnaliser le Scheduler

**Modifier fréquences :**

```bash
# Backup 2x par jour + healthcheck toutes les 30min
sudo BACKUP_SCHEDULE="*-*-* 03,15:00:00" \
     HEALTHCHECK_SCHEDULE="*:0/30" \
     ./supabase-scheduler.sh
```

**Formats schedule (systemd OnCalendar) :**
- `hourly` - Toutes les heures
- `daily` - Quotidien (00:00)
- `weekly` - Hebdomadaire (Lundi 00:00)
- `*:0/30` - Toutes les 30 minutes
- `*-*-* 03:00:00` - Tous les jours à 3h du matin

**Format cron (si `SCHEDULER_MODE=cron`) :**
```bash
sudo SCHEDULER_MODE=cron \
     BACKUP_SCHEDULE="0 3 * * *" \
     ./supabase-scheduler.sh
```

---

## 🔗 Intégration avec Common-Scripts

### Comment ça fonctionne ?

**1. Le wrapper Supabase configure :**

```bash
# supabase-backup.sh
BACKUP_TARGET_DIR=/home/pi/backups/supabase
DATA_PATHS=/home/pi/stacks/supabase/volumes
POSTGRES_DSN="postgres://postgres:xxxxx@localhost:5432/postgres"
BACKUP_NAME_PREFIX="supabase"
```

**2. Puis appelle le script commun :**

```bash
exec common-scripts/04-backup-rotate.sh "$@"
```

**3. Le script commun fait le travail :**
- Backup PostgreSQL via `pg_dump`
- Archive volumes Docker
- Rotation GFS automatique
- Compression gzip

**Avantage :** Quand on ajoutera Gitea, Nextcloud, etc., on créera juste un wrapper qui configure les variables et appelle le même `04-backup-rotate.sh` !

### Architecture

```
pi5-setup/
├── common-scripts/                      # Logique générique
│   ├── lib.sh                           # Bibliothèque
│   ├── 04-backup-rotate.sh              # Backup GFS générique
│   ├── 05-healthcheck-report.sh         # Healthcheck générique
│   └── 08-scheduler-setup.sh            # Scheduler générique
│
└── pi5-supabase-stack/
    └── scripts/maintenance/             # Wrappers Supabase
        ├── _supabase-common.sh          # Config Supabase
        ├── supabase-backup.sh           # Configure + exec 04-backup-rotate.sh
        ├── supabase-healthcheck.sh      # Configure + exec 05-healthcheck-report.sh
        └── supabase-scheduler.sh        # Configure + exec 08-scheduler-setup.sh
```

---

## 🆘 Troubleshooting

### Backup Échoue

**Erreur :**
```
pg_dump: error: connection to database "postgres" failed
```

**Solutions :**
1. Vérifier que Supabase est démarré :
   ```bash
   cd ~/stacks/supabase
   docker compose ps
   ```

2. Vérifier connexion PostgreSQL :
   ```bash
   docker exec supabase-db psql -U postgres -c "SELECT version();"
   ```

3. Vérifier le DSN dans `.env` :
   ```bash
   grep POSTGRES_PASSWORD ~/stacks/supabase/.env
   ```

### Healthcheck Montre Services "Unhealthy"

**Solutions :**
1. Voir logs du service problématique :
   ```bash
   cd ~/stacks/supabase
   docker compose logs -f <service>
   # Exemples: auth, db, realtime, studio
   ```

2. Redémarrer le service :
   ```bash
   docker compose restart <service>
   ```

3. Vérifier ressources système :
   ```bash
   free -h  # RAM
   df -h    # Disk
   ```

### Timers Ne S'Exécutent Pas

**Vérifications :**

1. Lister les timers :
   ```bash
   systemctl list-timers | grep supabase
   ```

2. Voir statut timer :
   ```bash
   systemctl status pi5-supabase-backup.timer
   ```

3. Voir logs d'exécution :
   ```bash
   journalctl -u pi5-supabase-backup.service -n 50
   ```

4. Forcer exécution manuelle :
   ```bash
   systemctl start pi5-supabase-backup.service
   ```

---

## 📖 Documentation Complète

### Liens Utiles

- **[Common Scripts README](../../../../common-scripts/README.md)** - Documentation scripts génériques
- **[Supabase Stack README](../../README.md)** - Documentation installation Supabase
- **[Commands Reference](../../commands/All-Commands-Reference.md)** - Toutes les commandes

### Maintenance Recommandée

| Tâche | Fréquence | Script |
|-------|-----------|--------|
| **Backup** | Quotidien (3h) | `supabase-backup.sh` via timer |
| **Healthcheck** | Horaire | `supabase-healthcheck.sh` via timer |
| **Vérifier logs** | Hebdomadaire | `supabase-healthcheck.sh --verbose` |
| **Collecter logs** | Si problème | `supabase-logs.sh` |
| **Tester restore** | Mensuel | `supabase-restore.sh --dry-run` |
| **Mise à jour** | Mensuel ou selon besoin | `supabase-update.sh` |

---

## 🚀 Prochaines Étapes

Après avoir configuré la maintenance :

1. **✅ Configurer scheduler** :
   ```bash
   sudo ./supabase-scheduler.sh
   ```

2. **✅ Tester backup** :
   ```bash
   sudo ./supabase-backup.sh --dry-run --verbose
   sudo ./supabase-backup.sh
   ```

3. **✅ Vérifier healthcheck** :
   ```bash
   sudo ./supabase-healthcheck.sh --verbose
   ```

4. **✅ Tester restauration** :
   ```bash
   sudo ./supabase-restore.sh --dry-run
   ```

5. **✅ Monitorer timers** :
   ```bash
   systemctl list-timers
   journalctl -u pi5-supabase-backup.service -f
   ```

---

<p align="center">
  <strong>🔧 Maintenance Automatisée pour Supabase Pi5 🔧</strong>
</p>

<p align="center">
  <sub>Backups automatiques • Healthchecks • Monitoring • Production-ready</sub>
</p>
