# 📊 Pi5 Monitoring Stack - Prometheus + Grafana

> **Production-ready monitoring stack pour Raspberry Pi 5 avec dashboards pré-configurés**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Raspberry Pi 5](https://img.shields.io/badge/Platform-Raspberry%20Pi%205-red.svg)](https://www.raspberrypi.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)

---

## 📖 Table des Matières

- [Vue d'Ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Architecture](#-architecture)
- [Installation Rapide](#-installation-rapide)
- [Composants](#-composants)
- [Dashboards Pré-Configurés](#-dashboards-pré-configurés)
- [Intégration Traefik](#-intégration-traefik)
- [Configuration](#-configuration)
- [Maintenance](#-maintenance)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)

---

## 🎯 Vue d'Ensemble

**Pi5-Monitoring-Stack** est une solution complète de monitoring pour Raspberry Pi 5, basée sur **Prometheus** et **Grafana**, optimisée pour les stacks auto-hébergés (Supabase, Traefik, Homepage, etc.).

### Pourquoi ce Stack ?

- ✅ **Installation en 1 commande** - Curl one-liner, zéro configuration manuelle
- ✅ **3 dashboards pré-configurés** - Prêts à l'emploi dès l'installation
- ✅ **Auto-détection** - Détecte Supabase, Traefik et ajoute métriques automatiquement
- ✅ **Optimisé Pi 5** - Métriques ARM64, température CPU, ressources limitées
- ✅ **Production-ready** - Rétention 30j, alertes visuelles, HTTPS via Traefik
- ✅ **Pédagogique** - Documentation débutant complète en français

### Que Surveille-t-on ?

| Catégorie | Métriques | Collecteur |
|-----------|-----------|------------|
| **Système** | CPU, RAM, Disque, Température, Network, Load | Node Exporter |
| **Docker** | CPU/RAM par container, Network I/O, Disk I/O | cAdvisor |
| **PostgreSQL** | Connexions, Cache hit ratio, Query duration, Locks, DB size | postgres_exporter |

---

## 🚀 Fonctionnalités

### Core Features

- 📊 **Prometheus** - Time-series database avec rétention 30 jours
- 📈 **Grafana** - Interface moderne avec 3 dashboards pré-configurés
- 🔍 **Node Exporter** - Métriques système (CPU, RAM, température, disque)
- 🐳 **cAdvisor** - Métriques containers Docker en temps réel
- 🗄️ **postgres_exporter** - Métriques PostgreSQL (si Supabase détecté)

### Auto-Détection Intelligente

Le script d'installation détecte automatiquement :

- ✅ **Traefik installé ?** → Ajoute labels pour accès HTTPS (duckdns/cloudflare/vpn)
- ✅ **Supabase installé ?** → Active postgres_exporter avec connexion auto-configurée
- ✅ **Scénario Traefik ?** → Configure routing path/subdomain selon config

### Dashboards Pré-Configurés

| Dashboard | Description | Panneaux |
|-----------|-------------|----------|
| **Raspberry Pi 5 - Système** | Vue matériel/OS complète | CPU, Température, RAM, Disque, Network, Load, Uptime |
| **Docker Containers** | Monitoring containers | Top 10 CPU/RAM, Graphiques temporels, Network/Disk I/O |
| **Supabase PostgreSQL** | Métriques base de données | Connexions, Cache hit, Query duration, Locks, DB size, WAL |

### Intégration Traefik

Supporte les 3 scénarios automatiquement :

| Scénario | URL Grafana | URL Prometheus |
|----------|-------------|----------------|
| **DuckDNS** | `https://votresubdomain.duckdns.org/grafana` | `https://votresubdomain.duckdns.org/prometheus` |
| **Cloudflare** | `https://grafana.votredomaine.com` | `https://prometheus.votredomaine.com` |
| **VPN** | `http://raspberrypi.local:3002` | `http://raspberrypi.local:9090` |

---

## 🏗️ Architecture

### Stack Docker Compose

```
monitoring/
├── prometheus        # Collecteur métriques (port 9090)
├── grafana          # Dashboards visualisation (port 3002)
├── node-exporter    # Métriques système (port 9100)
├── cadvisor         # Métriques Docker (port 8080)
└── postgres-exporter # Métriques PostgreSQL (port 9187, si Supabase)
```

### Flux de Données

```
┌─────────────────┐
│  Node Exporter  │ ───┐
│  (Métr. Système)│    │
└─────────────────┘    │
                       │
┌─────────────────┐    │    ┌─────────────┐    ┌──────────┐
│    cAdvisor     │ ───┼───→│ Prometheus  │───→│ Grafana  │
│  (Métr. Docker) │    │    │  (Stockage) │    │  (Viz.)  │
└─────────────────┘    │    └─────────────┘    └──────────┘
                       │
┌─────────────────┐    │
│postgres_exporter│ ───┘
│  (Métr. PG)     │
└─────────────────┘
```

### Arborescence Fichiers

```
~/stacks/monitoring/
├── docker-compose.yml              # Stack Prometheus + Grafana
├── .env                            # Variables environnement
├── config/
│   ├── prometheus/
│   │   └── prometheus.yml          # Config Prometheus (scrape targets)
│   └── grafana/
│       ├── grafana.ini             # Config Grafana
│       ├── provisioning/
│       │   ├── datasources/
│       │   │   └── prometheus.yml  # Datasource Prometheus auto-provisionné
│       │   └── dashboards/
│       │       └── default.yml     # Auto-load dashboards
│       └── dashboards/
│           ├── raspberry-pi-dashboard.json
│           ├── docker-containers-dashboard.json
│           └── supabase-postgres-dashboard.json
└── data/
    ├── prometheus/                 # TSDB Prometheus (30 jours)
    └── grafana/                    # DB Grafana (dashboards, users)
```

---

## ⚡ Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec Raspberry Pi OS 64-bit
- ✅ Docker + Docker Compose installés ([01-prerequisites-setup.sh](../common-scripts/01-prerequisites-setup.sh))
- ✅ **(Optionnel)** Traefik pour accès HTTPS externe
- ✅ **(Optionnel)** Supabase pour monitoring PostgreSQL

### Installation Simple (Curl One-Liner)

```bash
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh | sudo bash
```

**Durée** : ~2-3 minutes

### Installation Avancée (avec Options)

```bash
# Télécharger le script
curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/pi5-monitoring-stack/scripts/01-monitoring-deploy.sh -o monitoring-deploy.sh
chmod +x monitoring-deploy.sh

# Dry-run (simulation)
sudo ./monitoring-deploy.sh --dry-run --verbose

# Installation avec confirmation auto
sudo ./monitoring-deploy.sh --yes --verbose

# Installation custom
sudo GRAFANA_ADMIN_PASSWORD=SuperSecure123 \
     PROMETHEUS_RETENTION=60d \
     ./monitoring-deploy.sh
```

### Ce que fait le Script

1. ✅ Détecte Traefik (scénario duckdns/cloudflare/vpn)
2. ✅ Détecte Supabase (active postgres_exporter)
3. ✅ Crée répertoire `~/stacks/monitoring/`
4. ✅ Génère `docker-compose.yml` avec services
5. ✅ Configure Prometheus (targets auto-détectés)
6. ✅ Configure Grafana (datasource + dashboards)
7. ✅ Ajoute labels Traefik (si installé)
8. ✅ Démarre les containers
9. ✅ Affiche URLs d'accès

### Accéder aux Interfaces

#### Grafana (Dashboards)

**URL selon scénario** :
- Sans Traefik : http://raspberrypi.local:3002
- DuckDNS : https://votresubdomain.duckdns.org/grafana
- Cloudflare : https://grafana.votredomaine.com
- VPN : http://raspberrypi.local:3002

**Login par défaut** :
- Username : `admin`
- Password : `admin` (vous devrez changer au premier login)

#### Prometheus (Métriques)

**URL selon scénario** :
- Sans Traefik : http://raspberrypi.local:9090
- DuckDNS : https://votresubdomain.duckdns.org/prometheus
- Cloudflare : https://prometheus.votredomaine.com
- VPN : http://raspberrypi.local:9090

#### cAdvisor (Interface Docker)

**URL** : http://raspberrypi.local:8080

**Accès direct aux métriques containers** (interface simple).

---

## 🧩 Composants

### Prometheus

**Time-series database pour métriques**

- **Port** : 9090
- **Rétention** : 30 jours (configurable)
- **Scrape interval** : 15 secondes
- **Stockage** : `~/stacks/monitoring/data/prometheus/`

**Targets scrapés** :
```yaml
- job_name: 'prometheus'
  static_configs:
    - targets: ['localhost:9090']

- job_name: 'node-exporter'
  static_configs:
    - targets: ['node-exporter:9100']

- job_name: 'cadvisor'
  static_configs:
    - targets: ['cadvisor:8080']

- job_name: 'postgres-exporter'  # Si Supabase détecté
  static_configs:
    - targets: ['postgres-exporter:9187']
```

**Endpoints utiles** :
- `/` - Interface web Prometheus
- `/metrics` - Métriques Prometheus lui-même
- `/targets` - État des targets (UP/DOWN)
- `/graph` - Tester requêtes PromQL

### Grafana

**Interface de visualisation moderne**

- **Port** : 3002
- **Version** : Latest stable
- **Stockage** : `~/stacks/monitoring/data/grafana/`

**Features activées** :
- ✅ Datasource Prometheus auto-provisionné
- ✅ 3 dashboards auto-chargés au démarrage
- ✅ Anonymous access désactivé (sécurité)
- ✅ Alerting disponible (à configurer)

**Datasource Prometheus** :
```yaml
name: Prometheus
type: prometheus
url: http://prometheus:9090
access: proxy
isDefault: true
```

### Node Exporter

**Métriques système Linux**

- **Port** : 9100
- **Version** : Latest stable
- **Optimisations Pi 5** : Collectors ARM64 activés

**Métriques exposées** :
- `node_cpu_seconds_total` - Utilisation CPU par core
- `node_memory_*` - RAM (total, available, buffers, cached)
- `node_disk_*` - Disque (read/write bytes, I/O time)
- `node_filesystem_*` - Système de fichiers (size, free, files)
- `node_network_*` - Réseau (receive/transmit bytes, errors)
- `node_load*` - Load average (1m, 5m, 15m)
- `node_thermal_zone_temp` - Température CPU
- `node_boot_time_seconds` - Timestamp du boot (pour uptime)

### cAdvisor

**Container Advisor - Métriques Docker**

- **Port** : 8080
- **Version** : Latest stable
- **Privilèges** : Accès root au système (nécessaire)

**Métriques exposées** :
- `container_cpu_usage_seconds_total` - CPU par container
- `container_memory_usage_bytes` - RAM par container
- `container_network_*` - Network I/O par container
- `container_fs_*` - Disk I/O par container
- `container_last_seen` - Timestamp dernière observation

**Interface web** : http://raspberrypi.local:8080
- Vue simple des containers
- Graphiques basiques CPU/RAM
- Alternative à Grafana pour débutants

### postgres_exporter

**Métriques PostgreSQL (si Supabase installé)**

- **Port** : 9187
- **Version** : Latest stable
- **Connexion** : Auto-détectée depuis `~/stacks/supabase/.env`

**Métriques exposées** :
- `pg_stat_activity_count` - Connexions actives
- `pg_stat_database_*` - Stats par database (size, transactions, deadlocks)
- `pg_stat_bgwriter_*` - Checkpoints, buffers
- `pg_settings_*` - Configuration PostgreSQL
- `pg_locks_count` - Locks actifs
- `pg_stat_user_tables_*` - Stats par table (scans, inserts, updates)

**DSN auto-détecté** :
```bash
POSTGRES_DSN="postgresql://postgres:PASSWORD@supabase-db:5432/postgres?sslmode=disable"
# PASSWORD extrait depuis ~/stacks/supabase/.env
```

---

## 📊 Dashboards Pré-Configurés

### 1. Raspberry Pi 5 - Système

**Fichier** : `raspberry-pi-dashboard.json`

**Description** : Vue complète du matériel et de l'OS du Raspberry Pi 5.

**Panneaux** :

| Panneau | Type | Métrique | Seuils | Description |
|---------|------|----------|--------|-------------|
| **CPU Usage** | Graph | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | 🟢 <70% / 🟠 70-80% / 🔴 >80% | Utilisation CPU moyenne |
| **CPU Temperature** | Gauge | `node_thermal_zone_temp` | 🟢 <60°C / 🟠 60-70°C / 🔴 >70°C | Température CPU |
| **Memory Usage** | Gauge | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | 🟢 <70% / 🟠 70-85% / 🔴 >85% | RAM utilisée |
| **Disk Usage** | Gauge | `100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)` | 🟢 <70% / 🟠 70-85% / 🔴 >85% | Espace disque (/) |
| **Network Traffic** | Graph | `rate(node_network_receive_bytes_total[5m])` / `rate(node_network_transmit_bytes_total[5m])` | - | Trafic RX/TX |
| **System Load** | Graph | `node_load1` / `node_load5` / `node_load15` | - | Load 1m/5m/15m |
| **Uptime** | Stat | `time() - node_boot_time_seconds` | - | Temps depuis boot |

**Quand consulter** :
- 📅 Check quotidien (tout vert ?)
- 🔥 Surchauffe (température >70°C)
- 💾 Espace disque faible
- 🐌 Lenteurs générales

### 2. Docker Containers

**Fichier** : `docker-containers-dashboard.json`

**Description** : Monitoring détaillé de tous les containers Docker.

**Panneaux** :

| Panneau | Type | Métrique | Description |
|---------|------|----------|-------------|
| **Top 10 CPU** | Table | `topk(10, rate(container_cpu_usage_seconds_total[5m]))` | Containers les + gourmands en CPU |
| **Top 10 Memory** | Table | `topk(10, container_memory_usage_bytes)` | Containers les + gourmands en RAM |
| **CPU Over Time** | Graph | `rate(container_cpu_usage_seconds_total{name!=""}[5m])` | Évolution CPU par container |
| **Memory Over Time** | Graph | `container_memory_usage_bytes{name!=""}` | Évolution RAM par container |
| **Network I/O** | Table | `rate(container_network_receive_bytes_total[5m])` / `rate(container_network_transmit_bytes_total[5m])` | Trafic réseau par container |
| **Disk I/O** | Table | `rate(container_fs_reads_bytes_total[5m])` / `rate(container_fs_writes_bytes_total[5m])` | Lecture/écriture disque |

**Quand consulter** :
- 🐌 Lenteurs système (identifier container gourmand)
- 🆕 Après installation nouveau service
- 🔍 Optimisation ressources
- 🔴 Alerte RAM/CPU

**Exemple de lecture** :
```
Top 10 CPU:
1. supabase-db        : 15%
2. supabase-realtime  : 8%
3. grafana            : 5%
→ Supabase consomme le plus (normal)

Top 10 Memory:
1. supabase-db        : 1200 MB
2. grafana            : 350 MB
3. prometheus         : 280 MB
→ Répartition normale
```

### 3. Supabase PostgreSQL

**Fichier** : `supabase-postgres-dashboard.json`

**Description** : Métriques avancées PostgreSQL (uniquement si Supabase installé).

**Panneaux** :

| Panneau | Type | Métrique | Seuils | Description |
|---------|------|----------|--------|-------------|
| **Active Connections** | Stat + Graph | `pg_stat_activity_count{state="active"}` | 🟢 <50 / 🟠 50-80 / 🔴 >80 | Connexions actives |
| **Database Size** | Stat + Graph | `pg_database_size_bytes` | - | Taille DB en MB |
| **Cache Hit Ratio** | Gauge | `rate(pg_stat_database_blks_hit) / (rate(pg_stat_database_blks_hit) + rate(pg_stat_database_blks_read))` | 🟢 >95% / 🟠 85-95% / 🔴 <85% | % requêtes depuis cache |
| **Transaction Rate** | Graph | `rate(pg_stat_database_xact_commit[5m])` | - | Transactions/seconde |
| **Query Duration P50/P95/P99** | Graph | `pg_stat_statements_mean_time_seconds` | 🟢 P95<50ms / 🟠 50-200ms / 🔴 >200ms | Durée requêtes (percentiles) |
| **Locks** | Stat | `pg_locks_count` | 🟢 <5 / 🟠 5-10 / 🔴 >10 | Verrous actifs |
| **WAL Size** | Graph | `pg_wal_lsn_diff` | - | Taille Write-Ahead Log |

**Quand consulter** :
- 🐌 Supabase lent
- 📊 Dimensionnement (besoin de + de RAM ?)
- 🔍 Optimisation requêtes
- 💾 Surveillance croissance DB

**Signaux d'alerte** :

| Métrique | ⚠️ Alerte | 🔴 Critique | Action |
|----------|-----------|-------------|--------|
| Connexions | >50 | >80 | Augmenter `max_connections` ou optimiser pooling |
| Cache Hit | <90% | <85% | Augmenter `shared_buffers` (plus de RAM pour cache) |
| P99 Query | >500ms | >1000ms | Optimiser requêtes, ajouter index |
| Locks | >10 | >20 | Identifier requête bloquante (`SELECT * FROM pg_locks`) |

---

## 🔗 Intégration Traefik

Le script détecte automatiquement le scénario Traefik installé et configure les labels appropriés.

### Détection Automatique

Le script lit `/home/pi/stacks/traefik/.env` :

```bash
if grep -q "DUCKDNS_SUBDOMAIN" "$TRAEFIK_ENV"; then
    TRAEFIK_SCENARIO="duckdns"
elif grep -q "CLOUDFLARE_API_TOKEN" "$TRAEFIK_ENV"; then
    TRAEFIK_SCENARIO="cloudflare"
else
    TRAEFIK_SCENARIO="vpn"
fi
```

### Configuration par Scénario

#### Scénario 1 : DuckDNS (Path-Based)

```yaml
labels:
  - "traefik.enable=true"

  # Grafana
  - "traefik.http.routers.grafana.rule=Host(`${DUCKDNS_SUBDOMAIN}.duckdns.org`) && PathPrefix(`/grafana`)"
  - "traefik.http.routers.grafana.entrypoints=websecure"
  - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
  - "traefik.http.services.grafana.loadbalancer.server.port=3000"
  - "traefik.http.middlewares.grafana-strip.stripprefix.prefixes=/grafana"
  - "traefik.http.routers.grafana.middlewares=grafana-strip"

  # Prometheus
  - "traefik.http.routers.prometheus.rule=Host(`${DUCKDNS_SUBDOMAIN}.duckdns.org`) && PathPrefix(`/prometheus`)"
  - "traefik.http.routers.prometheus.entrypoints=websecure"
  - "traefik.http.routers.prometheus.tls.certresolver=letsencrypt"
  - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
  - "traefik.http.middlewares.prometheus-strip.stripprefix.prefixes=/prometheus"
  - "traefik.http.routers.prometheus.middlewares=prometheus-strip"
```

**URLs** :
- Grafana : `https://votresubdomain.duckdns.org/grafana`
- Prometheus : `https://votresubdomain.duckdns.org/prometheus`

#### Scénario 2 : Cloudflare (Subdomain-Based)

```yaml
labels:
  - "traefik.enable=true"

  # Grafana
  - "traefik.http.routers.grafana.rule=Host(`grafana.${CLOUDFLARE_DOMAIN}`)"
  - "traefik.http.routers.grafana.entrypoints=websecure"
  - "traefik.http.routers.grafana.tls.certresolver=letsencrypt"
  - "traefik.http.services.grafana.loadbalancer.server.port=3000"

  # Prometheus
  - "traefik.http.routers.prometheus.rule=Host(`prometheus.${CLOUDFLARE_DOMAIN}`)"
  - "traefik.http.routers.prometheus.entrypoints=websecure"
  - "traefik.http.routers.prometheus.tls.certresolver=letsencrypt"
  - "traefik.http.services.prometheus.loadbalancer.server.port=9090"
```

**URLs** :
- Grafana : `https://grafana.votredomaine.com`
- Prometheus : `https://prometheus.votredomaine.com`

**DNS Cloudflare** (à configurer manuellement) :
```
Type: A
Name: grafana
Content: <IP_PUBLIQUE>
Proxy: Enabled (orange cloud)

Type: A
Name: prometheus
Content: <IP_PUBLIQUE>
Proxy: Enabled (orange cloud)
```

#### Scénario 3 : VPN (Local Access)

```yaml
# Pas de labels Traefik
# Accès direct via IP locale ou hostname
```

**URLs** :
- Grafana : `http://raspberrypi.local:3002`
- Prometheus : `http://raspberrypi.local:9090`

**Accès via VPN** (Tailscale/WireGuard) :
- Grafana : `http://<tailscale-ip>:3002`
- Prometheus : `http://<tailscale-ip>:9090`

---

## ⚙️ Configuration

### Variables d'Environnement

**Fichier** : `~/stacks/monitoring/.env`

| Variable | Défaut | Description |
|----------|--------|-------------|
| `GRAFANA_ADMIN_USER` | `admin` | Username admin Grafana |
| `GRAFANA_ADMIN_PASSWORD` | `admin` | Password admin (changer au 1er login) |
| `PROMETHEUS_RETENTION` | `30d` | Rétention métriques Prometheus |
| `SCRAPE_INTERVAL` | `15s` | Fréquence collecte métriques |
| `POSTGRES_DSN` | Auto-détecté | Connexion PostgreSQL (si Supabase) |

**Surcharger à l'installation** :

```bash
sudo GRAFANA_ADMIN_PASSWORD=SuperSecure123 \
     PROMETHEUS_RETENTION=60d \
     SCRAPE_INTERVAL=30s \
     ./01-monitoring-deploy.sh
```

**Modifier après installation** :

```bash
cd ~/stacks/monitoring
nano .env
docker compose up -d  # Redémarrer pour appliquer
```

### Modifier la Rétention Prometheus

**Par défaut** : 30 jours

**Économiser espace disque** (15 jours) :

```bash
cd ~/stacks/monitoring
nano docker-compose.yml
```

Modifier :
```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=15d'
```

**Historique long** (90 jours) :

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=90d'
```

**Appliquer** :
```bash
docker compose up -d
```

### Ajouter un Target Prometheus

**Exemple** : Monitorer un autre service (Portainer, Gitea, etc.)

```bash
cd ~/stacks/monitoring
nano config/prometheus/prometheus.yml
```

Ajouter :
```yaml
scrape_configs:
  - job_name: 'portainer'
    static_configs:
      - targets: ['portainer:9000']
```

Redémarrer :
```bash
docker compose restart prometheus
```

Vérifier dans Prometheus : http://raspberrypi.local:9090/targets

### Configurer Alertes Email Grafana

**Modifier config Grafana** :

```bash
cd ~/stacks/monitoring
nano config/grafana/grafana.ini
```

Ajouter section SMTP :
```ini
[smtp]
enabled = true
host = smtp.gmail.com:587
user = votre-email@gmail.com
password = votre-mot-de-passe-application
from_address = votre-email@gmail.com
from_name = Grafana Pi5
```

Redémarrer :
```bash
docker compose restart grafana
```

**Créer alerte dans Grafana** :
1. Ouvrir dashboard "Raspberry Pi 5"
2. Éditer panneau "CPU Usage"
3. Onglet **Alert**
4. Créer règle : "Si CPU >80% pendant 5 minutes"
5. Ajouter notification email

---

## 🛠️ Maintenance

### Backup Configuration

**Sauvegarder config Grafana** :

```bash
# Backup manuel
tar -czf ~/backups/monitoring-config-$(date +%Y%m%d).tar.gz \
  ~/stacks/monitoring/config/ \
  ~/stacks/monitoring/docker-compose.yml \
  ~/stacks/monitoring/.env

# Exclure les données (trop volumineuses)
# data/ contient 30 jours de métriques (~plusieurs GB)
```

**Restaurer config** :

```bash
cd ~/backups
tar -xzf monitoring-config-20251004.tar.gz -C ~/stacks/
cd ~/stacks/monitoring
docker compose up -d
```

### Exporter Dashboards Grafana

**Via UI** :
1. Ouvrir dashboard
2. Icône **Share** > **Export**
3. **Save to file** → JSON téléchargé

**Via API** :

```bash
# Lister dashboards
curl -s -u admin:admin http://raspberrypi.local:3002/api/search?query=

# Exporter dashboard par UID
curl -s -u admin:admin http://raspberrypi.local:3002/api/dashboards/uid/<UID> \
  | jq '.dashboard' > my-dashboard.json
```

### Nettoyer Vieilles Métriques

**Prometheus auto-gère la rétention** (30j par défaut).

**Forcer nettoyage manuel** (libérer espace disque) :

```bash
cd ~/stacks/monitoring
docker compose stop prometheus
sudo rm -rf data/prometheus/*
docker compose up -d prometheus
```

**⚠️ Attention** : Perte de tout l'historique !

### Mettre à Jour le Stack

```bash
cd ~/stacks/monitoring

# Sauvegarder config
tar -czf ~/backups/monitoring-backup-$(date +%Y%m%d).tar.gz config/ docker-compose.yml .env

# Pull nouvelles images
docker compose pull

# Redémarrer avec nouvelles images
docker compose up -d

# Vérifier logs
docker compose logs -f
```

---

## 🆘 Troubleshooting

### Grafana Ne S'Ouvre Pas

**Erreur** : "Unable to connect" sur http://raspberrypi.local:3002

**Solutions** :

1. **Vérifier container** :
   ```bash
   cd ~/stacks/monitoring
   docker compose ps
   ```

   Si `grafana` est `Exited` :
   ```bash
   docker compose logs grafana
   docker compose restart grafana
   ```

2. **Vérifier port** :
   ```bash
   netstat -tuln | grep 3002
   ```

   Si pas de résultat :
   ```bash
   docker compose up -d
   ```

3. **Essayer IP locale** :
   ```bash
   hostname -I  # Ex: 192.168.1.50
   ```
   Ouvrir : `http://192.168.1.50:3002`

### Dashboards Vides ("No Data")

**Cause** : Prometheus ne collecte pas les métriques

**Solutions** :

1. **Vérifier targets Prometheus** :
   - Ouvrir http://raspberrypi.local:9090/targets
   - Tous doivent être **UP** (vert)

   Si un target est **DOWN** (rouge) :
   ```bash
   cd ~/stacks/monitoring
   docker compose restart <service>
   # Ex: node-exporter, cadvisor, postgres-exporter
   ```

2. **Vérifier datasource Grafana** :
   - Dans Grafana : **Connections > Data Sources > Prometheus**
   - Cliquer **Test** → "Data source is working"

   Si erreur :
   - Vérifier URL : `http://prometheus:9090`
   - Redémarrer Grafana

3. **Attendre 15-30 secondes** :
   - Prometheus scrappe toutes les 15s
   - Rafraîchir le dashboard

### postgres_exporter DOWN

**Symptôme** : Dashboard "Supabase PostgreSQL" vide, target DOWN dans Prometheus

**Cause** : Connexion PostgreSQL échouée

**Solutions** :

1. **Vérifier Supabase en cours** :
   ```bash
   cd ~/stacks/supabase
   docker compose ps
   ```

   Si `supabase-db` n'est pas `Up` :
   ```bash
   docker compose up -d
   ```

2. **Vérifier DSN dans .env** :
   ```bash
   grep POSTGRES_DSN ~/stacks/monitoring/.env
   ```

   Format attendu :
   ```
   POSTGRES_DSN=postgresql://postgres:PASSWORD@supabase-db:5432/postgres?sslmode=disable
   ```

3. **Tester connexion depuis postgres_exporter** :
   ```bash
   docker exec monitoring-postgres-exporter psql "${POSTGRES_DSN}" -c "SELECT version();"
   ```

   Si erreur → Vérifier mot de passe dans `~/stacks/supabase/.env`

### CPU/Température Toujours en Rouge

**Symptôme** : CPU >80% ou Température >70°C constant

**Solutions** :

1. **Identifier container gourmand** :
   - Ouvrir dashboard "Docker Containers"
   - Top 10 CPU → Redémarrer container problématique

2. **Améliorer ventilation** :
   - Acheter ventilateur PWM pour Pi 5
   - Vérifier circulation d'air dans boîtier

3. **Réduire charge** :
   ```bash
   # Arrêter services non-critiques
   cd ~/stacks/<service>
   docker compose stop
   ```

---

## 📚 Documentation

### Guides Disponibles

- **[GUIDE-DEBUTANT.md](GUIDE-DEBUTANT.md)** - Guide pédagogique complet pour novices
- **[INSTALL.md](INSTALL.md)** - Installation détaillée étape par étape
- **[ROADMAP.md](../ROADMAP.md)** - Plan de développement Pi5-Setup

### Documentation Externe

- **[Prometheus Docs](https://prometheus.io/docs/)** - Documentation officielle Prometheus
- **[Grafana Docs](https://grafana.com/docs/)** - Documentation officielle Grafana
- **[PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)** - Requêtes courantes
- **[Grafana Dashboards](https://grafana.com/grafana/dashboards/)** - 6000+ dashboards communautaires

### Dashboards Communautaires Recommandés

| ID | Nom | Description |
|----|-----|-------------|
| **1860** | Node Exporter Full | Dashboard Pi très complet (alternative à notre dashboard système) |
| **893** | Docker and System Monitoring | Monitoring Docker avancé |
| **11074** | Node Exporter for Prometheus Dashboard | Graphiques système élégants |
| **9628** | PostgreSQL Database | Métriques PostgreSQL avancées |

**Importer dans Grafana** :
1. **Dashboards > Import**
2. Entrer l'ID (ex: 1860)
3. Cliquer **Load**
4. Sélectionner datasource "Prometheus"
5. Cliquer **Import**

---

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## 📄 Licence

MIT License - Voir [LICENSE](../LICENSE)

---

<p align="center">
  <strong>📊 Monitoring Production-Ready pour Raspberry Pi 5 📊</strong>
</p>

<p align="center">
  <sub>Prometheus • Grafana • Dashboards pré-configurés • Auto-détection • HTTPS</sub>
</p>
