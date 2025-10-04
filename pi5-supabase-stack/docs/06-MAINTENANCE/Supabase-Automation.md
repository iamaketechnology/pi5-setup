# Supabase – Automatisation & Maintenance

> Scripts dédiés pour sauvegarder, auditer et maintenir votre stack Supabase self-hosted sur Raspberry Pi 5.

---

## 🎯 Objectifs

- Sauvegardes régulières (Postgres + volumes Docker) avec rotation GFS.
- Restauration guidée et testée.
- Rapports de santé (Docker, endpoints HTTP, ressources).
- Mises à jour contrôlées avec rollback automatique.
- Collecte des journaux en un clic.
- Planification via systemd timers ou cron.

---

## 📂 Structure

- `common-scripts/` – Bibliothèque générique (préflight, hardening, docker, traefik, backup, healthcheck, update, logs, scheduler, monitoring, secrets, onboarding, benchmarks, mode incident).
- `pi5-supabase-stack/scripts/maintenance/` – Wrappers Supabase utilisant `common-scripts` avec valeurs par défaut (chemins, DSN, environnements).

Tous les scripts supportent : `--dry-run`, `--yes`, `--verbose`, `--quiet`, `--no-color` + variables d'environnement.

---

## 🔁 Sauvegarde & Restauration

### Sauvegarde

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-backup.sh \
  BACKUP_TARGET_DIR=/mnt/backups/supabase \
  KEEP_DAILY=7 KEEP_WEEKLY=4 KEEP_MONTHLY=6
```

- Dump Postgres (`pg_dump --format=custom`).
- Sauvegarde des volumes (répertoires dans `~/stacks/supabase/volumes`).
- Archive tar.gz + rotation GFS.
- Support rclone via `RCLONE_REMOTE=remote:bucket/path`.

### Restauration

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-restore.sh \
  /mnt/backups/supabase/supabase-20241004-120000.tar.gz \
  DATA_TARGETS=~/stacks/supabase/volumes
```

- Vérifie l’archive.
- Restaure Postgres via `pg_restore --clean`.
- Synchronise les volumes (rsync).
- Demande confirmation avant d’écraser.

---

## 🩺 Healthcheck & Reporting

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-healthcheck.sh \
  REPORT_DIR=~/stacks/supabase/reports \
  HTTP_ENDPOINTS=http://localhost:8000/health,http://localhost:54323/status
```

- Capture infos système, mémoire, disque.
- `docker info`, `docker compose ps`, tests HTTP avec temps de réponse.
- Génère `.txt` + `.md` horodatés.

---

## 🔄 Mise à jour & Rollback

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-update.sh update \
  COMPOSE_PROJECT_DIR=~/stacks/supabase \
  HEALTHCHECK_URL=http://localhost:8000/health \
  --yes
```

- Sauvegarde la liste des images (pour rollback).
- `docker compose pull && down && up -d`.
- Healthcheck HTTP optionnel.
- Rollback auto si healthcheck échoue et `ROLLBACK_ON_FAILURE=1`.

Rollback manuel :

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-update.sh rollback
```

---

## 🧾 Collecte de journaux

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-logs.sh \
  OUTPUT_DIR=~/stacks/supabase/reports \
  TAIL_LINES=4000
```

- Journaux Docker (`docker logs`), `docker compose logs`, `journalctl` (optionnel) et `dmesg`.
- Archive tar.gz prête à partager pour le support.

---

## ⏰ Planification (systemd timers)

```bash
sudo pi5-supabase-stack/scripts/maintenance/supabase-scheduler.sh \
  BACKUP_SCHEDULE=daily \
  HEALTHCHECK_SCHEDULE='*:0/30' \
  LOGS_SCHEDULE=weekly
```

- Crée `pi5-backup.timer`, `pi5-healthcheck.timer`, `pi5-logs.timer`.
- Pour cron : `SCHEDULER_MODE=cron` + expressions cron finales (ex: `0 2 * * *`).
- Scripts appelés : `supabase-backup.sh`, `supabase-healthcheck.sh`, `supabase-logs.sh`.

---

## 🛡️ Préflight & Durcissement (optionnel)

Avant toute installation/maintenance :

```bash
sudo common-scripts/00-preflight-checks.sh --verbose
sudo common-scripts/01-system-hardening.sh SSH_PORT=22 EXTRA_ALLOWED_PORTS=5432,8000
sudo common-scripts/02-docker-install-verify.sh
```

Déploiement reverse proxy / monitoring :

```bash
sudo TRAEFIK_DOMAIN=pi.mondomaine.com common-scripts/03-traefik-setup.sh
sudo common-scripts/monitoring-bootstrap.sh STACK_DIR=/opt/monitoring
```

---

## 🔐 Secrets & Onboarding

- Génération `.env` :

  ```bash
  sudo common-scripts/secrets-setup.sh --template .env.example --output .env
  ```

- Nouveau service (Traefik + compose) :

  ```bash
  sudo common-scripts/onboard-app.sh --name app --domain app.pi.local --port 3000
  ```

---

## 🧪 Benchmarks & Mode incident

```bash
sudo common-scripts/selftest-benchmark.sh --verbose
sudo common-scripts/incident-mode.sh enter NON_CRITICAL_COMPOSE_DIRS=/home/pi/stacks/monitoring
sudo common-scripts/incident-mode.sh exit
```

---

## ✅ Checklist rapide

- [ ] Préflight OK (`00-preflight-checks.sh`).
- [ ] Durcissement appliqué (`01-system-hardening.sh`).
- [ ] Backups programmés (`supabase-scheduler.sh`).
- [ ] Rapport healthcheck récent (`supabase-healthcheck.sh`).
- [ ] Processus d’update + rollback testés (`supabase-update.sh`).
- [ ] Docs à jour (`common-scripts/README.md`, `scripts/maintenance/README.md`).

---

## ❓ Support

- Logs collectés via `supabase-logs.sh`.
- Rapport healthcheck + versioning (`docker compose images`).
- Issues GitHub : inclure commandes, outputs, rapport.
