# 📖 Référence Complète - Toutes les Commandes

> **Guide de référence rapide pour toutes les commandes bash/docker utilisées**

---

## 📑 Table des Matières

- [Système & Vérifications](#système--vérifications)
- [Docker Management](#docker-management)
- [Supabase Services](#supabase-services)
- [PostgreSQL Database](#postgresql-database)
- [Networking & Ports](#networking--ports)
- [Sécurité & Firewall](#sécurité--firewall)
- [Monitoring & Logs](#monitoring--logs)
- [Backup & Restore](#backup--restore)
- [Troubleshooting](#troubleshooting)

---

## 🖥️ Système & Vérifications

### Informations Système

```bash
# Version OS
cat /etc/os-release

# Architecture (doit être aarch64)
uname -m

# RAM totale
free -h

# Espace disque
df -h

# Page size (doit être 4096)
getconf PAGESIZE

# Kernel version
uname -r

# Hostname
hostname

# IP addresses
hostname -I
ip addr show
```

### Configuration Boot

```bash
# Voir config boot actuelle
cat /boot/firmware/cmdline.txt
cat /boot/firmware/config.txt

# Éditer cmdline (page size fix)
sudo nano /boot/firmware/cmdline.txt

# Éditer config
sudo nano /boot/firmware/config.txt

# Redémarrer
sudo reboot

# Redémarrage forcé (si SSH bloqué)
sudo reboot -f
```

### Gestion Utilisateurs

```bash
# Voir utilisateur courant
whoami

# Voir groupes
groups

# Ajouter utilisateur au groupe docker
sudo usermod -aG docker $USER

# Appliquer changements groupes (sans logout)
newgrp docker

# Voir membres groupe docker
getent group docker
```

---

## 🐳 Docker Management

### Installation & Version

```bash
# Installer Docker
curl -fsSL https://get.docker.com | sudo sh

# Version Docker
docker --version
docker version

# Version Docker Compose
docker compose version

# Info Docker système
docker info
```

### Gestion Containers

```bash
# Lister containers actifs
docker ps

# Lister TOUS les containers (même arrêtés)
docker ps -a

# Démarrer container
docker start CONTAINER_NAME

# Arrêter container
docker stop CONTAINER_NAME

# Redémarrer container
docker restart CONTAINER_NAME

# Supprimer container
docker rm CONTAINER_NAME

# Supprimer container forcé (si running)
docker rm -f CONTAINER_NAME
```

### Gestion Images

```bash
# Lister images locales
docker images

# Télécharger image
docker pull IMAGE_NAME:TAG

# Supprimer image
docker rmi IMAGE_NAME:TAG

# Supprimer images non utilisées
docker image prune -a

# Voir taille images
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### Gestion Volumes

```bash
# Lister volumes
docker volume ls

# Voir détails volume
docker volume inspect VOLUME_NAME

# Créer volume
docker volume create VOLUME_NAME

# Supprimer volume
docker volume rm VOLUME_NAME

# Supprimer volumes non utilisés
docker volume prune
```

### Nettoyage Docker

```bash
# Nettoyer containers arrêtés
docker container prune

# Nettoyer images non utilisées
docker image prune -a

# Nettoyer volumes non utilisés
docker volume prune

# Nettoyer networks non utilisés
docker network prune

# Nettoyer TOUT (dangereux!)
docker system prune -a --volumes

# Voir espace utilisé
docker system df
```

### Logs & Inspection

```bash
# Voir logs container
docker logs CONTAINER_NAME

# Suivre logs en temps réel
docker logs -f CONTAINER_NAME

# Dernières 50 lignes
docker logs --tail=50 CONTAINER_NAME

# Logs avec timestamps
docker logs -t CONTAINER_NAME

# Inspecter container
docker inspect CONTAINER_NAME

# Voir processus dans container
docker top CONTAINER_NAME

# Statistiques ressources temps réel
docker stats

# Stats sans stream (snapshot)
docker stats --no-stream
```

### Exécution dans Container

```bash
# Exécuter commande dans container
docker exec CONTAINER_NAME COMMAND

# Shell interactif dans container
docker exec -it CONTAINER_NAME bash
docker exec -it CONTAINER_NAME sh

# Exécuter en tant qu'utilisateur spécifique
docker exec -u USER CONTAINER_NAME COMMAND

# Exécuter avec variables d'environnement
docker exec -e VAR=value CONTAINER_NAME COMMAND
```

---

## 🗄️ Docker Compose

### Opérations de Base

```bash
# Démarrer services (background)
docker compose up -d

# Démarrer sans detach (voir logs)
docker compose up

# Arrêter services
docker compose down

# Redémarrer services
docker compose restart

# Pause services
docker compose pause

# Unpause services
docker compose unpause

# Arrêter + supprimer volumes (DANGEREUX)
docker compose down -v
```

### Gestion Services

```bash
# Voir statut services
docker compose ps

# Démarrer service spécifique
docker compose start SERVICE_NAME

# Arrêter service spécifique
docker compose stop SERVICE_NAME

# Redémarrer service spécifique
docker compose restart SERVICE_NAME

# Reconstruire service
docker compose build SERVICE_NAME

# Reconstruire + redémarrer
docker compose up -d --build SERVICE_NAME

# Scaler service (multiple instances)
docker compose up -d --scale SERVICE_NAME=3
```

### Logs Compose

```bash
# Tous les logs
docker compose logs

# Suivre tous les logs
docker compose logs -f

# Logs service spécifique
docker compose logs SERVICE_NAME

# Suivre logs service spécifique
docker compose logs -f SERVICE_NAME

# Dernières 100 lignes
docker compose logs --tail=100

# Logs multiples services
docker compose logs SERVICE1 SERVICE2
```

### Configuration & Validation

```bash
# Valider docker-compose.yml
docker compose config

# Voir config finale (avec vars resolved)
docker compose config

# Valider sans résoudre variables
docker compose config --no-interpolate

# Lister services définis
docker compose config --services

# Voir images utilisées
docker compose config --images
```

### Mise à Jour Stack

```bash
# Pull nouvelles images
docker compose pull

# Recreate containers avec nouvelles images
docker compose up -d --pull always

# Force recreate (même si image identique)
docker compose up -d --force-recreate

# Rebuild + recreate
docker compose up -d --build --force-recreate
```

---

## 🔌 Supabase Services

### Navigation Projet

```bash
# Aller dans projet Supabase
cd ~/stacks/supabase

# Voir structure
ls -la

# Voir .env (secrets)
cat .env

# Éditer .env
nano .env
```

### Contrôle Services

```bash
cd ~/stacks/supabase

# Démarrer tout
docker compose up -d

# Arrêter tout
docker compose down

# Redémarrer service spécifique
docker compose restart auth
docker compose restart realtime
docker compose restart db
docker compose restart kong
docker compose restart studio

# Voir statut santé
docker compose ps

# Logs service spécifique
docker compose logs -f auth
docker compose logs -f realtime
docker compose logs -f db
```

### Scripts Utilitaires

```bash
cd ~/stacks/supabase

# Rapport santé (TXT + MD)
sudo ./scripts/maintenance/supabase-healthcheck.sh

# Sauvegarde complète (DB + volumes)
sudo ./scripts/maintenance/supabase-backup.sh BACKUP_TARGET_DIR=/mnt/backups/supabase

# Restauration guidée
sudo ./scripts/maintenance/supabase-restore.sh /mnt/backups/supabase/supabase-20241004-120000.tar.gz

# Mise à jour + rollback auto
sudo ./scripts/maintenance/supabase-update.sh update --yes

# Collecte journaux
sudo ./scripts/maintenance/supabase-logs.sh OUTPUT_DIR=~/stacks/supabase/reports

# Planification (systemd timers)
sudo ./scripts/maintenance/supabase-scheduler.sh BACKUP_SCHEDULE=daily
```

### Tests Connectivité

```bash
# Tester Studio
curl -I http://localhost:3000

# Tester API Gateway
curl http://localhost:8000

# Tester REST API
curl http://localhost:8000/rest/v1/

# Tester Auth endpoint
curl http://localhost:8000/auth/v1/health

# Tester Realtime
curl http://localhost:4000/api/health

# Tester Edge Functions
curl http://localhost:54321
```

---

## 🐘 PostgreSQL Database

### Connexion Database

```bash
cd ~/stacks/supabase

# Connexion psql en tant que postgres
docker compose exec db psql -U postgres

# Connexion à database spécifique
docker compose exec db psql -U postgres -d postgres

# Connexion avec utilisateur supabase_admin
docker compose exec db psql -U supabase_admin -d postgres

# Exécuter commande SQL directe
docker compose exec db psql -U postgres -c "SELECT version();"

# Exécuter script SQL
docker compose exec db psql -U postgres -f /path/to/script.sql
```

### Commandes SQL Utiles

```sql
-- Lister databases
\l

-- Lister schémas
\dn

-- Lister tables dans schéma auth
\dt auth.*

-- Lister tables dans schéma public
\dt public.*

-- Voir structure table
\d auth.users

-- Lister extensions installées
\dx

-- Voir version PostgreSQL
SELECT version();

-- Voir page size PostgreSQL
SHOW block_size;

-- Lister utilisateurs
\du

-- Lister connexions actives
SELECT * FROM pg_stat_activity;

-- Taille database
SELECT pg_database_size('postgres');

-- Taille table spécifique
SELECT pg_total_relation_size('auth.users');
```

### Gestion Utilisateurs PostgreSQL

```bash
# Créer utilisateur
docker compose exec db psql -U postgres -c "
CREATE USER myuser WITH PASSWORD 'mypassword';"

# Donner droits
docker compose exec db psql -U postgres -c "
GRANT ALL PRIVILEGES ON DATABASE postgres TO myuser;"

# Lister utilisateurs
docker compose exec db psql -U postgres -c "\du"

# Changer mot de passe
docker compose exec db psql -U postgres -c "
ALTER USER postgres PASSWORD 'newpassword';"
```

### Backup & Restore Database

```bash
cd ~/stacks/supabase

# Backup database complète
docker compose exec db pg_dump -U postgres postgres > backup.sql

# Backup avec compression
docker compose exec db pg_dump -U postgres postgres | gzip > backup.sql.gz

# Backup schéma auth uniquement
docker compose exec db pg_dump -U postgres -n auth postgres > auth_backup.sql

# Restore database
docker compose exec -T db psql -U postgres postgres < backup.sql

# Restore depuis backup compressé
gunzip -c backup.sql.gz | docker compose exec -T db psql -U postgres postgres
```

### Migrations

```bash
# Voir migrations appliquées (Auth)
docker compose exec db psql -U postgres -c "
SELECT * FROM auth.schema_migrations ORDER BY version;"

# Voir migrations GoTrue
docker compose logs auth | grep migration

# Appliquer migration manuelle
docker compose exec -T db psql -U postgres postgres < migration.sql

# Marquer migration comme appliquée
docker compose exec db psql -U postgres -c "
INSERT INTO auth.schema_migrations (version) VALUES ('20221208132122');"
```

---

## 🌐 Networking & Ports

### Vérification Ports

```bash
# Lister ports en écoute
sudo netstat -tulpn

# Vérifier port spécifique
sudo netstat -tulpn | grep :3000
sudo netstat -tulpn | grep :8000
sudo netstat -tulpn | grep :5432

# Alternative avec ss
sudo ss -tulpn

# Voir processus utilisant port
sudo lsof -i :3000
sudo lsof -i :8000

# Tuer processus sur port
sudo fuser -k 3000/tcp
```

### Tests Connectivité

```bash
# Ping host
ping IP_ADDRESS

# Test port TCP
nc -zv IP_ADDRESS PORT
telnet IP_ADDRESS PORT

# Curl avec headers
curl -I http://IP_ADDRESS:PORT

# Test timeout
curl --connect-timeout 5 http://IP_ADDRESS:PORT

# Suivre redirects
curl -L http://IP_ADDRESS:PORT
```

### Docker Networks

```bash
# Lister networks
docker network ls

# Inspecter network
docker network inspect NETWORK_NAME

# Créer network
docker network create NETWORK_NAME

# Connecter container à network
docker network connect NETWORK_NAME CONTAINER_NAME

# Déconnecter container de network
docker network disconnect NETWORK_NAME CONTAINER_NAME

# Supprimer network
docker network rm NETWORK_NAME
```

---

## 🛡️ Sécurité & Firewall

### UFW (Uncomplicated Firewall)

```bash
# Status UFW
sudo ufw status

# Status détaillé avec numéros règles
sudo ufw status numbered

# Activer UFW
sudo ufw enable

# Désactiver UFW
sudo ufw disable

# Autoriser port
sudo ufw allow 3000/tcp
sudo ufw allow 8000/tcp

# Autoriser depuis IP spécifique
sudo ufw allow from 192.168.1.100 to any port 22

# Bloquer port
sudo ufw deny 3000/tcp

# Supprimer règle (par numéro)
sudo ufw delete 5

# Supprimer règle (par spec)
sudo ufw delete allow 3000/tcp

# Reset UFW (DANGEREUX)
sudo ufw reset

# Reload règles
sudo ufw reload
```

### Fail2ban

```bash
# Status Fail2ban
sudo systemctl status fail2ban

# Démarrer Fail2ban
sudo systemctl start fail2ban

# Arrêter Fail2ban
sudo systemctl stop fail2ban

# Redémarrer Fail2ban
sudo systemctl restart fail2ban

# Activer au démarrage
sudo systemctl enable fail2ban

# Voir jails actives
sudo fail2ban-client status

# Voir jail spécifique (sshd)
sudo fail2ban-client status sshd

# Débannir IP
sudo fail2ban-client set sshd unbanip IP_ADDRESS

# Bannir IP manuellement
sudo fail2ban-client set sshd banip IP_ADDRESS
```

### SSH Sécurité

```bash
# Éditer config SSH
sudo nano /etc/ssh/sshd_config

# Redémarrer SSH
sudo systemctl restart ssh

# Voir connexions SSH actives
who
w

# Générer clé SSH
ssh-keygen -t ed25519 -C "your_email@example.com"

# Copier clé publique vers serveur
ssh-copy-id user@IP_ADDRESS

# Connexion avec clé
ssh -i ~/.ssh/id_ed25519 user@IP_ADDRESS

# Test connexion SSH (sans login)
ssh -T user@IP_ADDRESS
```

---

## 📊 Monitoring & Logs

### Monitoring Système

```bash
# CPU/RAM/Disk temps réel
htop

# I/O disque temps réel
sudo iotop

# Processus réseau
sudo nethogs

# Température CPU (Pi 5)
vcgencmd measure_temp

# Voltage
vcgencmd measure_volts

# Fréquence CPU
vcgencmd measure_clock arm

# Usage CPU
top
mpstat 1

# Usage RAM détaillé
free -h
vmstat 1

# Usage disque I/O
iostat -x 1

# Espace disque par répertoire
du -sh *
du -h --max-depth=1
```

### Logs Système

```bash
# Logs kernel
sudo dmesg

# Logs kernel en temps réel
sudo dmesg -w

# Logs système (systemd)
sudo journalctl

# Logs aujourd'hui
sudo journalctl --since today

# Logs service spécifique
sudo journalctl -u docker
sudo journalctl -u ssh

# Suivre logs temps réel
sudo journalctl -f

# Logs avec priorité error
sudo journalctl -p err

# Nettoyer vieux logs
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=100M
```

### Monitoring Docker

```bash
# Stats containers temps réel
docker stats

# Stats sans stream
docker stats --no-stream

# Stats format custom
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Events Docker temps réel
docker events

# Events depuis timestamp
docker events --since '2025-01-01'

# Inspect détaillé container
docker inspect CONTAINER_NAME

# Voir processus container
docker top CONTAINER_NAME
```

---

## 💾 Backup & Restore

### Backup Système

```bash
# Backup .env Supabase
cp ~/stacks/supabase/.env ~/backups/.env.$(date +%Y%m%d)

# Backup docker-compose.yml
cp ~/stacks/supabase/docker-compose.yml ~/backups/docker-compose.yml.$(date +%Y%m%d)

# Backup complet répertoire Supabase (sans volumes)
tar -czf ~/backups/supabase-config-$(date +%Y%m%d).tar.gz \
  --exclude='volumes' \
  ~/stacks/supabase

# Backup complet avec volumes (GROS fichier)
tar -czf ~/backups/supabase-full-$(date +%Y%m%d).tar.gz \
  ~/stacks/supabase
```

### Backup Database

```bash
cd ~/stacks/supabase

# Backup SQL simple
docker compose exec db pg_dump -U postgres postgres > backup-$(date +%Y%m%d).sql

# Backup compressé
docker compose exec db pg_dump -U postgres postgres | gzip > backup-$(date +%Y%m%d).sql.gz

# Backup format custom (plus rapide restore)
docker compose exec db pg_dump -U postgres -Fc postgres > backup-$(date +%Y%m%d).dump

# Backup avec schémas spécifiques
docker compose exec db pg_dump -U postgres -n public -n auth postgres > backup.sql

# Backup toutes databases
docker compose exec db pg_dumpall -U postgres > backup-all.sql
```

### Restore Database

```bash
cd ~/stacks/supabase

# Restore depuis SQL
docker compose exec -T db psql -U postgres postgres < backup.sql

# Restore depuis SQL compressé
gunzip -c backup.sql.gz | docker compose exec -T db psql -U postgres postgres

# Restore format custom
docker compose exec db pg_restore -U postgres -d postgres backup.dump

# Restore avec drop tables avant
docker compose exec -T db psql -U postgres -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
docker compose exec -T db psql -U postgres postgres < backup.sql
```

### Automatisation Backup

```bash
# Créer script backup
cat > ~/stacks/supabase/scripts/auto-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR=~/backups/supabase
mkdir -p $BACKUP_DIR
cd ~/stacks/supabase
docker compose exec db pg_dump -U postgres postgres | gzip > $BACKUP_DIR/db-$(date +%Y%m%d-%H%M%S).sql.gz
# Garder seulement 7 derniers backups
ls -t $BACKUP_DIR/db-*.sql.gz | tail -n +8 | xargs rm -f
EOF

chmod +x ~/stacks/supabase/scripts/auto-backup.sh

# Ajouter à crontab (backup quotidien 3h du matin)
echo "0 3 * * * /home/pi/stacks/supabase/scripts/auto-backup.sh" | crontab -

# Voir crontab
crontab -l
```

---

## 🛠️ Troubleshooting

### Reset Complet Supabase

```bash
cd ~/stacks/supabase

# Arrêter tous services
docker compose down

# Supprimer volumes database (PERTE DONNÉES)
sudo rm -rf volumes/db/data

# Optionnel : supprimer tous volumes
sudo rm -rf volumes/

# Redémarrer (recrée DB vierge)
docker compose up -d
```

### Reset Docker Complet

```bash
# ATTENTION : Supprime TOUS containers/images/volumes/networks

# Arrêter tous containers
docker stop $(docker ps -aq)

# Supprimer tous containers
docker rm $(docker ps -aq)

# Supprimer toutes images
docker rmi $(docker images -q)

# Supprimer tous volumes
docker volume rm $(docker volume ls -q)

# Nettoyer tout
docker system prune -a --volumes
```

### Réparation Page Size

```bash
# Vérifier page size actuel
getconf PAGESIZE

# Si 16384, fixer :
sudo nano /boot/firmware/cmdline.txt
# Ajouter : pagesize=4k

# Redémarrer OBLIGATOIRE
sudo reboot

# Vérifier après reboot
getconf PAGESIZE  # Doit afficher 4096
```

### Fix Permissions Docker

```bash
# Ajouter user au groupe docker
sudo usermod -aG docker $USER

# Appliquer immédiatement
newgrp docker

# Ou logout/login

# Test
docker ps  # Doit fonctionner sans sudo
```

### Diagnostic Complet

```bash
# Script diagnostic rapide
cat > ~/diagnostic.sh <<'EOF'
#!/bin/bash
echo "=== DIAGNOSTIC PI 5 SUPABASE ==="
echo "Page size: $(getconf PAGESIZE)"
echo "Architecture: $(uname -m)"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker compose version)"
echo "UFW status: $(sudo ufw status | head -1)"
docker ps --format "table {{.Names}}\t{{.Status}}"
EOF

chmod +x ~/diagnostic.sh
./diagnostic.sh
```

---

## 🔗 Commandes Combinées Utiles

### Pipeline Monitoring

```bash
# Voir RAM par container + trier
docker stats --no-stream --format "{{.Name}}\t{{.MemUsage}}" | sort -k2 -h

# Services unhealthy
docker compose ps | grep unhealthy

# Logs erreurs uniquement
docker compose logs | grep -i error

# Top 10 processus RAM
ps aux --sort=-%mem | head -n 10

# Espace disque par volume Docker
docker system df -v
```

### Quick Restart Workflow

```bash
# Redémarrage propre complet
cd ~/stacks/supabase && \
docker compose down && \
sleep 5 && \
docker compose up -d && \
sleep 30 && \
docker compose ps
```

### Health Check One-Liner

```bash
# Check santé tous services
curl -s http://localhost:3000 > /dev/null && echo "✅ Studio" || echo "❌ Studio" && \
curl -s http://localhost:8000 > /dev/null && echo "✅ Kong" || echo "❌ Kong" && \
docker compose exec db pg_isready -U postgres && echo "✅ DB" || echo "❌ DB"
```

---

<p align="center">
  <strong>📚 Référence Complète - Bookmark cette page ! 📚</strong>
</p>

<p align="center">
  <a href="../README.md">← Retour Index</a>
</p>
