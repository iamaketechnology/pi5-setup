# 📊 Monitoring - Scripts Génériques

Scripts de surveillance santé système, Docker et collecte de logs.

---

## 📜 Scripts

### `generic-healthcheck.sh`

Génère un rapport de santé complet (Docker, HTTP, ressources) en texte et Markdown.

**Variables** :
```bash
REPORT_DIR=/opt/reports                              # Dossier de sortie
REPORT_PREFIX=healthcheck                            # Préfixe fichier
HTTP_ENDPOINTS=http://localhost:8000/health,...      # URLs à tester (séparées par ,)
DOCKER_COMPOSE_DIRS=/path/to/stack1,...              # Stacks Docker (séparés par ,)
```

**Exemples** :

```bash
# Healthcheck Supabase
export HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:54323/status"
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
sudo bash generic-healthcheck.sh

# Healthcheck multi-stacks
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase,/home/pi/stacks/traefik"
export HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:8080/dashboard/"
sudo bash generic-healthcheck.sh

# Rapport custom
export REPORT_DIR=/tmp/reports
export REPORT_PREFIX=my-app-health
sudo bash generic-healthcheck.sh
```

**Rapport généré** :
- `healthcheck-YYYYMMDD-HHMMSS.txt` : Format texte
- `healthcheck-YYYYMMDD-HHMMSS.md` : Format Markdown

**Contenu** :
- ✅ Informations système (OS, kernel, uptime, load)
- ✅ Ressources (RAM, disque)
- ✅ État Docker (version, services)
- ✅ État containers (running/stopped)
- ✅ Endpoints HTTP (status code + latency)

---

### `generic-logs-collect.sh`

Collecte les logs système et Docker dans une archive tar.gz.

**Variables** :
```bash
OUTPUT_DIR=/opt/reports                          # Dossier de sortie
DOCKER_COMPOSE_DIRS=/path/to/stack1,...          # Stacks Docker
INCLUDE_SYSTEMD=1                                # Inclure journalctl (0/1)
INCLUDE_DMESG=1                                  # Inclure dmesg (0/1)
TAIL_LINES=1000                                  # Nombre de lignes
```

**Exemples** :

```bash
# Collecte logs Supabase
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
sudo bash generic-logs-collect.sh

# Logs système uniquement (sans Docker)
export DOCKER_COMPOSE_DIRS=""
export INCLUDE_SYSTEMD=1
export INCLUDE_DMESG=1
sudo bash generic-logs-collect.sh

# Logs 5000 dernières lignes
export TAIL_LINES=5000
sudo bash generic-logs-collect.sh
```

**Archive générée** :
```
/opt/reports/logs-YYYYMMDD-HHMMSS.tar.gz
├── uname.txt              # Infos système
├── disk-usage.txt         # df -h
├── memory.txt             # free -h
├── journalctl.txt         # Logs systemd
├── dmesg.txt              # Kernel logs
├── docker-containers.txt  # Liste containers
├── docker-supabase-kong.log
├── docker-supabase-postgres.log
└── compose_home_pi_stacks_supabase.log
```

**Utilisation** :
```bash
# Extraire
tar -xzf logs-20250114-153045.tar.gz

# Chercher erreur
grep -i error logs-*/docker-*.log
```

---

## 🔗 Automation

### Healthcheck toutes les heures

1. Créer wrapper :
```bash
sudo tee /usr/local/bin/healthcheck-supabase.sh > /dev/null <<'EOF'
#!/bin/bash
export REPORT_DIR=/opt/reports
export HTTP_ENDPOINTS="http://localhost:8000/health,http://localhost:54323/status"
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase"
/home/pi/pi5-setup/maintenance/monitoring/generic-healthcheck.sh
EOF
sudo chmod +x /usr/local/bin/healthcheck-supabase.sh
```

2. Configurer timer :
```bash
HEALTHCHECK_SCRIPT=/usr/local/bin/healthcheck-supabase.sh \
HEALTHCHECK_SCHEDULE=hourly \
sudo bash ../management/generic-scheduler-setup.sh
```

3. Vérifier :
```bash
systemctl list-timers | grep healthcheck
sudo journalctl -u pi5-healthcheck.service -f
```

---

### Collecte logs hebdomadaire

```bash
sudo tee /usr/local/bin/logs-collect-weekly.sh > /dev/null <<'EOF'
#!/bin/bash
export OUTPUT_DIR=/opt/reports
export DOCKER_COMPOSE_DIRS="/home/pi/stacks/supabase,/home/pi/stacks/traefik"
export TAIL_LINES=5000
/home/pi/pi5-setup/maintenance/monitoring/generic-logs-collect.sh

# Nettoyer logs > 30 jours
find /opt/reports -name "logs-*.tar.gz" -mtime +30 -delete
EOF
sudo chmod +x /usr/local/bin/logs-collect-weekly.sh

LOGS_SCRIPT=/usr/local/bin/logs-collect-weekly.sh \
LOGS_SCHEDULE=weekly \
sudo bash ../management/generic-scheduler-setup.sh
```

---

## 📈 Intégration Monitoring

### Uptime Kuma

```bash
# Créer HTTP(s) monitor dans Uptime Kuma
# URL: http://localhost:8000/health
# Interval: 60s
# Method: GET
# Expected status: 200-299
```

### Prometheus + Grafana

```bash
# Node Exporter (déjà installé si monitoring stack)
curl http://localhost:9100/metrics | grep node_

# Docker metrics
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

## 📊 Analyse Rapide

### Santé globale

```bash
# Derniers healthchecks
ls -lt /opt/reports/healthcheck-*.md | head -5

# Afficher dernier rapport
cat /opt/reports/healthcheck-*.md | head -50
```

### Recherche erreurs

```bash
# Extraire dernier logs
cd /tmp && tar -xzf /opt/reports/logs-latest.tar.gz

# Chercher patterns
grep -i "error\|fail\|fatal" logs-*/*.log
grep -i "out of memory" logs-*/docker-*.log
grep -i "connection refused" logs-*/docker-*.log
```

### Alertes

```bash
# Endpoint down ?
curl -f http://localhost:8000/health || echo "ALERTE: Service down!"

# RAM critique ?
FREE_MB=$(free -m | awk '/^Mem:/ {print $7}')
if [ $FREE_MB -lt 500 ]; then
  echo "ALERTE: RAM < 500MB disponible"
fi

# Disque > 90% ?
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
if [ $DISK_USAGE -gt 90 ]; then
  echo "ALERTE: Disque > 90%"
fi
```

---

## 🆘 Troubleshooting

### Healthcheck timeout

```bash
# Tester endpoint manuellement
curl -v http://localhost:8000/health

# Vérifier container
docker ps | grep supabase
docker logs supabase-kong --tail 50
```

### Logs incomplets

```bash
# Augmenter TAIL_LINES
export TAIL_LINES=10000
sudo bash generic-logs-collect.sh

# Vérifier permissions
ls -la /opt/reports/
sudo chown -R pi:pi /opt/reports/
```

### Rapport vide

```bash
# Vérifier Docker
docker ps
docker info

# Test verbose
sudo bash generic-healthcheck.sh --verbose
```

---

**Version** : 1.0.0
