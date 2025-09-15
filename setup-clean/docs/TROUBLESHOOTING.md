# 🔧 Guide de dépannage - Raspberry Pi 5 Setup

## 📋 Vue d'ensemble

Ce guide couvre tous les problèmes courants rencontrés lors de l'installation et de l'utilisation du système Pi 5 avec Docker et Supabase.

## 🚨 Problèmes critiques identifiés

### 1. 🔐 Auth Service - `auth.factor_type does not exist`

**Symptômes :**
```
ERROR: type "auth.factor_type" does not exist (SQLSTATE 42704)
running db migrations: error executing migrations/20240729123726_add_mfa_phone_config.up.sql
```

**Cause :** Schema auth incomplet sur ARM64, migration MFA échoue.

**Solution :**
```bash
# Créer le type manquant
docker exec -it supabase-db psql -U postgres -d postgres -c "
DO \$\$
BEGIN
    CREATE SCHEMA IF NOT EXISTS auth;
    CREATE TYPE auth.factor_type AS ENUM ('totp', 'phone');
    RAISE NOTICE 'auth.factor_type créé avec succès';
EXCEPTION
    WHEN duplicate_object THEN
        RAISE NOTICE 'auth.factor_type existe déjà';
END \$\$;
"

# Redémarrer le service
docker compose restart auth
```

### 2. ⚡ Realtime Service - Migration Errors

**Symptômes :**
```
DBConnection.EncodeError) Postgrex expected a binary, got 20210706140551
APP_NAME not available
```

**Cause :** Table `realtime.schema_migrations` avec mauvais type de colonne + variables manquantes.

**Solution complète :**
```bash
# 1. Créer le schéma Realtime correct
docker exec -it supabase-db psql -U postgres -d postgres -c "
CREATE SCHEMA IF NOT EXISTS realtime;

CREATE TABLE IF NOT EXISTS realtime.schema_migrations(
  version BIGINT PRIMARY KEY,
  inserted_at TIMESTAMP(0) WITHOUT TIME ZONE DEFAULT NOW()
);

-- Supprimer la table conflictuelle
DROP TABLE IF EXISTS public.schema_migrations;
"

# 2. Ajouter les variables manquantes au .env
cd /home/pi/stacks/supabase
echo "APP_NAME=supabase_realtime" >> .env
echo "REALTIME_APP_NAME=supabase_realtime" >> .env

# 3. Mettre à jour docker-compose.yml avec config complète
# Voir section "Configuration Realtime complète" ci-dessous

# 4. Redémarrer Realtime
docker compose restart realtime
```

### 3. 🌐 Kong Gateway - Template Failures

**Symptômes :**
```
apk: not found
envsubst: command not found
failed to parse declarative config
```

**Cause :** Image Kong Debian ne supporte pas les commandes Alpine, envsubst manquant.

**Solution :**
```bash
# 1. Installer envsubst sur l'hôte
sudo apt-get update && sudo apt-get install -y gettext-base

# 2. Pré-rendre la configuration Kong
cd /home/pi/stacks/supabase
envsubst < config/kong.tpl.yml > volumes/kong/kong.yml

# 3. Modifier docker-compose.yml pour supprimer l'entrypoint custom
# et monter le fichier pré-rendu
```

### 4. 🗄️ PostgreSQL Connection Issues

**Symptômes :**
```
password authentication failed
connection refused
SSL connection error
```

**Solutions :**
```bash
# 1. Ajouter sslmode=disable aux URLs de connexion
# Dans docker-compose.yml ou .env :
GOTRUE_DB_DATABASE_URL=postgres://postgres:${POSTGRES_PASSWORD}@db:5432/postgres?sslmode=disable

# 2. Vérifier la connectivité
docker exec supabase-db pg_isready -U postgres

# 3. Tester la connexion
docker exec -it supabase-db psql -U postgres -d postgres
```

## 🔍 Diagnostic général

### Commandes de base

```bash
# État de tous les services
cd /home/pi/stacks/supabase
docker compose ps

# Logs détaillés d'un service
docker compose logs [service] --tail=50 --follow

# Vérifier les variables d'environnement
docker exec [container] env | grep [VARIABLE]

# Espace disque et ressources
df -h
docker system df
docker stats --no-stream
```

### Vérification de la santé du système

```bash
# Page size (doit être 4096 pour PostgreSQL)
getconf PAGESIZE

# Température CPU
vcgencmd measure_temp

# Mémoire disponible
free -h

# Services système essentiels
sudo systemctl status docker
sudo systemctl status fail2ban
sudo ufw status
```

## 🐳 Problèmes Docker

### Conteneurs qui redémarrent en boucle

**Diagnostic :**
```bash
# Voir les logs d'erreur
docker compose logs [service] --tail=100

# Vérifier les health checks
docker inspect [container] | grep -A 10 Health

# Tester manuellement les health checks
docker exec [container] curl -f http://localhost:[port]/health
```

**Solutions courantes :**
```bash
# 1. Problème de permissions
sudo chown -R pi:pi /home/pi/stacks/supabase/volumes/

# 2. Manque de ressources
docker stats
# Si CPU/RAM > 90%, redémarrer ou optimiser

# 3. Port conflicts
lsof -i :[port]
# Tuer le processus ou changer le port

# 4. Volume corruption
docker compose down
sudo rm -rf volumes/db/data  # ATTENTION: supprime les données
docker compose up -d
```

### Problèmes réseau Docker

```bash
# Recréer les réseaux
docker compose down
docker network prune -f
docker compose up -d

# Vérifier la connectivité inter-conteneurs
docker exec supabase-studio ping supabase-db
docker exec supabase-auth curl http://supabase-db:5432

# Réinitialiser Docker complètement
sudo systemctl restart docker
```

## 📊 Problèmes de performance

### Pi 5 spécifiques

**Symptômes :** Services lents, timeouts, memory errors

**Solutions :**
```bash
# 1. Vérifier l'overheating
vcgencmd measure_temp
# Si > 70°C, améliorer le refroidissement

# 2. Optimiser la swap
sudo dphys-swapfile swapoff
sudo nano /etc/dphys-swapfile
# CONF_SWAPSIZE=4096
sudo dphys-swapfile setup
sudo dphys-swapfile swapon

# 3. Ajuster les ulimits Docker
sudo nano /etc/docker/daemon.json
```

**Configuration Docker optimisée :**
```json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 65536,
      "Soft": 65536
    }
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### Memory cgroup warnings

**Symptômes :**
```
Your kernel does not support memory limit capabilities or the cgroup is not mounted
```

**Solution :**
```bash
# Ajouter à /boot/firmware/cmdline.txt
sudo nano /boot/firmware/cmdline.txt
# Ajouter : cgroup_enable=memory cgroup_memory=1

sudo reboot
```

## 🗄️ Problèmes base de données

### PostgreSQL ne démarre pas

```bash
# 1. Vérifier les logs
docker compose logs db --tail=50

# 2. Problème de page size (Pi 5)
getconf PAGESIZE
# Si != 4096 :
echo "kernel=kernel8.img" | sudo tee -a /boot/firmware/config.txt
sudo reboot

# 3. Volume corrompu
docker compose down
sudo rm -rf volumes/db/data
docker compose up -d db
# Attendre l'initialisation complète
```

### Migrations échouent

```bash
# 1. Vérifier que PostgreSQL est prêt
docker exec supabase-db pg_isready -U postgres

# 2. Exécuter les migrations manuellement
docker exec -it supabase-db psql -U postgres -d postgres -c "
SELECT * FROM auth.schema_migrations ORDER BY version DESC LIMIT 5;
"

# 3. Créer les schémas manquants si nécessaire
docker exec -it supabase-db psql -U postgres -d postgres -c "
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS storage;
"
```

## 🔧 Configuration Realtime complète

**docker-compose.yml section Realtime :**
```yaml
  realtime:
    container_name: supabase-realtime
    image: supabase/realtime:v2.30.23
    platform: linux/arm64
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
    environment:
      # Configuration DB
      DB_HOST: db
      DB_PORT: 5432
      DB_NAME: postgres
      DB_USER: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_SSL: disable
      DB_IP_VERSION: ipv4

      # Runtime Elixir (critique pour ARM64)
      ERL_AFLAGS: "-proto_dist inet_tcp"
      APP_NAME: supabase_realtime
      DNS_NODES: ""

      # Service config
      PORT: 4000
      API_JWT_SECRET: ${JWT_SECRET}
      SECRET_KEY_BASE: ${JWT_SECRET}

      # Performance Pi 5
      DB_POOL_SIZE: 10
      MAX_CONNECTIONS: 16384
      RLIMIT_NOFILE: 65536

      # Self-hosted
      SEED_SELF_HOST: "true"
    ulimits:
      nofile:
        soft: 65536
        hard: 65536
```

## 🌐 Problèmes d'accès web

### Supabase Studio inaccessible

```bash
# 1. Vérifier que le service fonctionne
docker compose ps | grep studio

# 2. Tester le port
curl -I http://localhost:3000

# 3. Vérifier les logs
docker compose logs studio --tail=20

# 4. Redémarrer si nécessaire
docker compose restart studio

# 5. Vérifier la configuration réseau
docker port supabase-studio
```

### API inaccessible

```bash
# 1. Tester l'API REST
curl -H "apikey: YOUR_ANON_KEY" http://localhost:8001/rest/v1/

# 2. Vérifier Kong
docker compose logs kong --tail=20

# 3. Tester Kong directement
curl -I http://localhost:8001/
```

## 🔄 Sauvegardes et récupération

### Sauvegarde complète

```bash
# Script de sauvegarde
#!/bin/bash
BACKUP_DIR="/home/pi/backups/$(date +%Y%m%d_%H%M)"
mkdir -p $BACKUP_DIR

# Base de données
docker exec supabase-db pg_dump -U postgres -d postgres > $BACKUP_DIR/database.sql

# Volumes
sudo tar -czf $BACKUP_DIR/volumes.tar.gz /home/pi/stacks/supabase/volumes/

# Configuration
cp /home/pi/stacks/supabase/.env $BACKUP_DIR/
cp /home/pi/stacks/supabase/docker-compose.yml $BACKUP_DIR/

echo "Backup créé dans $BACKUP_DIR"
```

### Restauration

```bash
# 1. Arrêter les services
cd /home/pi/stacks/supabase
docker compose down

# 2. Restaurer les volumes
sudo rm -rf volumes/
sudo tar -xzf backup_volumes.tar.gz

# 3. Démarrer la base de données
docker compose up -d db
sleep 30

# 4. Restaurer la base de données
docker exec -i supabase-db psql -U postgres -d postgres < backup_database.sql

# 5. Démarrer tous les services
docker compose up -d
```

## 📝 Logs et monitoring

### Collecte de logs pour debug

```bash
# Script de collecte automatique
#!/bin/bash
LOG_DIR="/tmp/supabase_debug_$(date +%Y%m%d_%H%M)"
mkdir -p $LOG_DIR

cd /home/pi/stacks/supabase

# Logs de tous les services
docker compose logs > $LOG_DIR/all_services.log

# Logs individuels
for service in db auth realtime storage kong studio meta rest; do
  docker compose logs $service > $LOG_DIR/${service}.log 2>&1
done

# État du système
docker compose ps > $LOG_DIR/services_status.txt
docker stats --no-stream > $LOG_DIR/resources.txt
free -h > $LOG_DIR/memory.txt
df -h > $LOG_DIR/disk.txt
vcgencmd measure_temp > $LOG_DIR/temperature.txt

# Configuration
cp .env $LOG_DIR/ 2>/dev/null || echo "No .env file" > $LOG_DIR/env_missing.txt
cp docker-compose.yml $LOG_DIR/

echo "Logs collectés dans $LOG_DIR"
tar -czf $LOG_DIR.tar.gz $LOG_DIR/
echo "Archive créée: $LOG_DIR.tar.gz"
```

### Monitoring continu

```bash
# Script de monitoring
#!/bin/bash
while true; do
  echo "=== $(date) ==="
  echo "Temperature: $(vcgencmd measure_temp)"
  echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
  echo "Services:"
  docker compose ps --format "table {{.Name}}\t{{.Status}}"
  echo "---"
  sleep 60
done > /home/pi/monitoring.log
```

## 🆘 Procédures d'urgence

### Reset complet système

```bash
# ATTENTION: Supprime toutes les données Supabase
cd /home/pi/stacks/supabase
docker compose down -v
sudo rm -rf volumes/
docker system prune -a -f

# Redémarrer l'installation
sudo ./setup-week2-supabase-final.sh
```

### Reset Docker complet

```bash
# ATTENTION: Supprime tous les conteneurs Docker
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker

# Réinstaller les services
cd /home/pi/stacks/supabase
docker compose up -d
```

## 📞 Obtenir de l'aide

### Informations à collecter

Avant de demander de l'aide, collectez :

1. **Logs système** : Script de collecte ci-dessus
2. **Configuration** : `.env` et `docker-compose.yml` (masquer les secrets)
3. **État des services** : `docker compose ps`
4. **Informations système** :
   ```bash
   uname -a
   getconf PAGESIZE
   vcgencmd measure_temp
   free -h
   df -h
   docker version
   ```

### Ressources utiles

- **Documentation officielle** : [Supabase Self-hosting](https://supabase.com/docs/guides/self-hosting)
- **GitHub Issues** : [Supabase GitHub](https://github.com/supabase/supabase/issues)
- **Communauté** : [Supabase Discord](https://discord.supabase.com/)
- **Pi 5 spécifique** : [Raspberry Pi Forums](https://forums.raspberrypi.com/)

## ✅ Checklist de vérification rapide

```bash
# Copier-coller ce script pour un diagnostic rapide
cd /home/pi/stacks/supabase

echo "=== DIAGNOSTIC RAPIDE SUPABASE ==="
echo "Date: $(date)"
echo

echo "1. Page size (doit être 4096):"
getconf PAGESIZE

echo "2. Température CPU:"
vcgencmd measure_temp

echo "3. État des services:"
docker compose ps

echo "4. Espace disque:"
df -h | grep -E "/$|/home"

echo "5. Mémoire:"
free -h

echo "6. Services en erreur:"
docker compose ps | grep -E "restarting|exited|unhealthy" || echo "Aucun"

echo "7. Test connectivité base:"
docker exec supabase-db pg_isready -U postgres 2>/dev/null && echo "✅ PostgreSQL OK" || echo "❌ PostgreSQL KO"

echo "8. Test API Supabase:"
curl -s -I http://localhost:8001/rest/v1/ | head -1 || echo "❌ API inaccessible"

echo "=== FIN DIAGNOSTIC ==="
```

---

## 🆘 **Nouveaux Problèmes Identifiés (Testing Reset 2025)**

### 🔧 **JWT_SECRET cassé sur plusieurs lignes**

**Symptômes :**
```
Services redémarrent, variables d'environnement mal parsées
JWT_SECRET visible sur plusieurs lignes dans .env
```

**Diagnostic :**
```bash
# Vérifier le nombre de lignes JWT_SECRET
cat .env | grep -c "JWT_SECRET"
# Doit retourner 1, si plus = problème

# Voir le contenu exact
cat .env | grep -A 2 JWT_SECRET
```

**Solution :**
```bash
# Nettoyer et régénérer JWT_SECRET propre
sed -i '/JWT_SECRET/d' .env
NEW_JWT=$(openssl rand -base64 64 | tr -d '\n')
echo "JWT_SECRET=$NEW_JWT" >> .env

# Redémarrer les services
docker compose restart auth realtime storage
```

### 🔧 **Realtime : Données corrompues après changement JWT**

**Symptômes :**
```
** (ErlangError) Erlang error: {:badarg, "Bad key"}
crypto_one_time(:aes_128_ecb, nil, "data", true) échoue
Realtime redémarre en boucle infinie
```

**Diagnostic :**
```bash
# Vérifier les logs Realtime
docker compose logs realtime --tail=10 | grep -i "bad key"
```

**Solution :**
```bash
# 1. Arrêter Realtime
docker compose stop realtime

# 2. Nettoyer données corrompues en base
docker exec -it supabase-db psql -U postgres -d postgres -c "
DELETE FROM realtime.tenants WHERE jwt_secret IS NOT NULL;
DELETE FROM realtime.extensions;
"

# 3. Redémarrer Realtime (recrée les données)
docker compose start realtime
```

### 🔧 **Race condition schémas/services**

**Symptômes :**
```
schema "auth" does not exist
Services démarrent avant création complète schémas
```

**Solution préventive :**
```bash
# Créer TOUS les schémas/rôles AVANT démarrage
docker exec -it supabase-db psql -U postgres -d postgres -c "
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS realtime;
CREATE SCHEMA IF NOT EXISTS storage;

DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN;
  END IF;
END \$\$;

GRANT USAGE ON SCHEMA auth TO postgres, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA realtime TO postgres, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA storage TO postgres, anon, authenticated, service_role;
"
```

## ✅ **Checklist nouvelle génération**

```bash
# Script de diagnostic complet des nouveaux problèmes
cd /home/pi/stacks/supabase

echo "=== DIAGNOSTIC AVANCÉ SUPABASE 2025 ==="
echo "Date: $(date)"
echo

echo "1. JWT_SECRET intégrité:"
JWT_LINES=$(cat .env | grep -c "JWT_SECRET" || echo "0")
if [[ $JWT_LINES -eq 1 ]]; then
  echo "✅ JWT_SECRET sur une ligne"
else
  echo "❌ JWT_SECRET cassé ($JWT_LINES lignes)"
fi

echo "2. Schémas database:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT schema_name FROM information_schema.schemata
WHERE schema_name IN ('auth', 'realtime', 'storage');" 2>/dev/null | grep -v "schema_name" | wc -l | xargs -I {} echo "Schémas présents: {}/3"

echo "3. Rôles PostgreSQL:"
docker exec supabase-db psql -U postgres -d postgres -c "
SELECT rolname FROM pg_roles
WHERE rolname IN ('anon', 'authenticated', 'service_role');" 2>/dev/null | grep -v "rolname" | wc -l | xargs -I {} echo "Rôles présents: {}/3"

echo "4. Services problématiques:"
docker compose ps | grep -E "restarting|exited|unhealthy" || echo "Aucun"

echo "5. Test Realtime spécifique:"
if docker compose logs realtime --tail=5 2>/dev/null | grep -q "Bad key"; then
  echo "❌ Realtime: Données corrompues détectées"
else
  echo "✅ Realtime: Pas d'erreur crypto visible"
fi

echo "=== FIN DIAGNOSTIC AVANCÉ ==="
```

---

**🎯 Ce guide couvre tous les problèmes majeurs identifiés. Utilisez la checklist de diagnostic en premier lieu !**