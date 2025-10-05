# 📊 Monitoring & Observabilité

> **Catégorie** : Surveillance système, métriques et alerting

---

## 📦 Stacks Inclus

### 1. [Prometheus + Grafana](prometheus-grafana/)
**Stack Monitoring Complète**

**Composants** :
- 📊 **Prometheus** : Collecte métriques (CPU, RAM, disk, réseau, Docker)
- 📈 **Grafana** : Dashboards visualisation + alerting
- 🐳 **cAdvisor** : Métriques containers Docker
- 🖥️ **Node Exporter** : Métriques système Raspberry Pi

**RAM** : ~1.1 GB
**Ports** : 9090 (Prometheus), 3000 (Grafana)

**Dashboards pré-configurés** :
- Vue d'ensemble Raspberry Pi (CPU, RAM, température)
- Docker containers (usage RAM/CPU par container)
- Supabase PostgreSQL (connexions, queries)
- Traefik (requêtes HTTP, latence)

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
```

**Accès** :
- Grafana : `http://raspberrypi.local:3000` (admin/admin)
- Prometheus : `http://raspberrypi.local:9090`

---

### 2. [Uptime Kuma](uptime-kuma/)
**Monitoring Uptime Services**

- 📊 **Monitors** : HTTP, TCP, Ping, Docker, etc.
- 🔔 **90+ notifications** : Discord, Slack, Email, Telegram
- 📈 **Status page** public
- ⏱️ **Historique** uptime

**RAM** : ~100 MB
**Port** : 3001

**Installation** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/uptime-kuma/scripts/01-uptime-kuma-deploy.sh | sudo bash
```


## 📊 Statistiques Catégorie

| Métrique | Valeur |
|----------|--------|
| **Nombre de stacks** | 1 (4 composants) |
| **RAM totale** | ~1.1 GB |
| **Complexité** | ⭐⭐ (Modérée) |
| **Priorité** | 🟡 **RECOMMANDÉ** (essentiel pour production) |
| **Ordre installation** | Phase 3 (après infrastructure de base) |

---

## 🎯 Cas d'Usage

### Alerting Température
Alerte si Raspberry Pi > 70°C :
```yaml
# Grafana Alert
- alert: RaspberryPiHighTemp
  expr: node_hwmon_temp_celsius > 70
  for: 5m
  annotations:
    summary: "Température élevée ({{ $value }}°C)"
```

### Surveillance RAM
Alerte si RAM > 90% :
```yaml
- alert: HighMemoryUsage
  expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) > 0.9
  for: 10m
```

---

## 🔗 Liens Utiles

- [Grafana Dashboards](https://grafana.com/grafana/dashboards/) - Dashboards communautaires
- [Prometheus Docs](https://prometheus.io/docs/) - Documentation officielle
