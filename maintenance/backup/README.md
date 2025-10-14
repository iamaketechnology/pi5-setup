# 🔄 Backup & Restore - Scripts Génériques

Scripts de sauvegarde et restauration avec rotation GFS (Grandfather-Father-Son).

---

## 📜 Scripts

### `generic-backup-rotate.sh`

Crée une sauvegarde compressée (PostgreSQL + volumes Docker) avec rotation automatique.

**Variables** :
```bash
BACKUP_TARGET_DIR=/opt/backups          # Dossier de destination
BACKUP_NAME_PREFIX=pi5                  # Préfixe du fichier (pi5-20250114-153045.tar.gz)
POSTGRES_DSN=postgres://user:pass@host:5432/db  # Optionnel
DATA_PATHS=/path1,/path2                # Chemins à sauvegarder (séparés par ,)
RCLONE_REMOTE=remote:backup             # Upload cloud (optionnel)
KEEP_DAILY=7                            # Backups quotidiens
KEEP_WEEKLY=4                           # Backups hebdomadaires
KEEP_MONTHLY=6                          # Backups mensuels
```

**Exemples** :

```bash
# Backup Supabase complet
export BACKUP_NAME_PREFIX=supabase
export POSTGRES_DSN="postgres://postgres:yourpass@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
sudo bash generic-backup-rotate.sh

# Backup sans PostgreSQL (volumes seulement)
export BACKUP_NAME_PREFIX=traefik
export DATA_PATHS="/home/pi/stacks/traefik/letsencrypt,/home/pi/stacks/traefik/logs"
sudo bash generic-backup-rotate.sh

# Dry-run (test sans exécution)
sudo bash generic-backup-rotate.sh --dry-run
```

**Rotation GFS** :
- **Daily** : 7 derniers jours (1 backup/jour)
- **Weekly** : 4 dernières semaines (1 backup/semaine)
- **Monthly** : 6 derniers mois (1 backup/mois)

Les anciens backups sont automatiquement supprimés.

---

### `generic-restore.sh`

Restaure une sauvegarde créée avec `generic-backup-rotate.sh`.

**Variables** :
```bash
RESTORE_TARGET_DIR=/opt/backups/tmp-restore    # Dossier temporaire extraction
POSTGRES_DSN=postgres://user:pass@host:5432/db # Connexion PostgreSQL
DATA_TARGETS=/path1,/path2                     # Chemins de destination
```

**Exemples** :

```bash
# Restaurer backup Supabase
export POSTGRES_DSN="postgres://postgres:yourpass@localhost:54322/postgres"
export DATA_TARGETS="/home/pi/stacks/supabase/volumes"
sudo bash generic-restore.sh /opt/backups/supabase-20250114-153045.tar.gz

# Restaurer uniquement les fichiers (sans DB)
export DATA_TARGETS="/home/pi/stacks/traefik/letsencrypt,/home/pi/stacks/traefik/logs"
sudo bash generic-restore.sh /opt/backups/traefik-20250114-153045.tar.gz

# Mode interactif (confirmation à chaque étape)
sudo bash generic-restore.sh /opt/backups/backup.tar.gz
```

**⚠️ Attention** :
- Restauration PostgreSQL utilise `--clean` (DROP tables existantes)
- Toujours tester sur environnement de dev avant production
- Arrêter les services Docker avant restauration

---

## 🔗 Automation

### Backup quotidien (systemd timer)

1. Créer script wrapper :
```bash
sudo tee /usr/local/bin/backup-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
export BACKUP_TARGET_DIR=/opt/backups
export BACKUP_NAME_PREFIX=supabase
export POSTGRES_DSN="postgres://postgres:yourpass@localhost:54322/postgres"
export DATA_PATHS="/home/pi/stacks/supabase/volumes"
/home/pi/pi5-setup/maintenance/backup/generic-backup-rotate.sh
EOF
sudo chmod +x /usr/local/bin/backup-supabase.sh
```

2. Configurer timer :
```bash
BACKUP_SCRIPT=/usr/local/bin/backup-supabase.sh \
BACKUP_SCHEDULE=daily \
sudo bash ../management/generic-scheduler-setup.sh
```

3. Vérifier :
```bash
systemctl list-timers | grep pi5-backup
sudo journalctl -u pi5-backup.service -f
```

---

## 📊 Monitoring

### Vérifier backups existants

```bash
ls -lh /opt/backups/
du -sh /opt/backups/*
```

### Tester intégrité

```bash
# Extraire sans restaurer
tar -tzf /opt/backups/backup.tar.gz | head -20

# Vérifier PostgreSQL dump
tar -xzf /opt/backups/backup.tar.gz postgres.sql
pg_restore --list postgres.sql
```

### Espace disque

```bash
df -h /opt/backups
```

---

## 🔐 Bonnes Pratiques

1. **Tester régulièrement** : Restaurer sur environnement de test
2. **Rotation** : Adapter KEEP_* selon besoins (espace disque vs historique)
3. **Offsite** : Utiliser RCLONE_REMOTE pour backup cloud (GDrive, S3, etc.)
4. **Alertes** : Intégrer avec monitoring (voir ../monitoring/)
5. **Secrets** : Jamais stocker mots de passe en clair, utiliser variables env

---

## 🆘 Troubleshooting

### Erreur "disk space"
```bash
# Nettoyer anciens backups manuellement
sudo rm /opt/backups/old-backup-*.tar.gz

# Vérifier rotation
ls -lt /opt/backups/ | head -20
```

### Erreur PostgreSQL "permission denied"
```bash
# Vérifier connexion
psql "$POSTGRES_DSN" -c "\l"

# Vérifier pg_dump disponible
which pg_dump
```

### Backup incomplet
```bash
# Vérifier logs
sudo journalctl -u pi5-backup.service -n 50

# Test dry-run
sudo bash generic-backup-rotate.sh --dry-run --verbose
```

---

**Version** : 1.0.0
