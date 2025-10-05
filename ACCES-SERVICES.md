# 🔗 Accès aux Services - Raspberry Pi 5

> **Tableau de bord rapide** - Tous vos services en un coup d'œil

**Remplacez `PI_IP` par l'IP de votre Raspberry Pi** (ex: `192.168.1.74`)

Pour trouver l'IP de votre Pi :
```bash
hostname -I
```

---

## 🗄️ Backend & Base de données

### Supabase
- **Studio (Interface Web)** : http://PI_IP:3000
- **API Kong Gateway** : http://PI_IP:8000
- **PostgreSQL** : `PI_IP:5432`
- **Clés API** : `~/stacks/supabase/.env`

---

## 🐳 Docker Management

### Portainer
- **Interface Web** : http://PI_IP:8080
- **Documentation** : Gestion visuelle de tous vos conteneurs Docker

---

## 🌐 Reverse Proxy & HTTPS

### Traefik
- **Dashboard** : http://PI_IP:8888 (si configuré avec --api)
- **HTTP** : Port 80
- **HTTPS** : Port 443

---

## 📊 Monitoring & Observabilité

### Prometheus + Grafana
- **Grafana** : http://PI_IP:3001
- **Prometheus** : http://PI_IP:9090
- **Node Exporter** : http://PI_IP:9100
- **cAdvisor** : http://PI_IP:8081

### Uptime Kuma
- **Dashboard** : http://PI_IP:3002

---

## 🐙 Développement & Git

### Gitea
- **Interface Web** : http://PI_IP:3001 (si installé)
- **SSH** : Port 2222

---

## 💾 Stockage & Cloud

### FileBrowser
- **Interface Web** : http://PI_IP:8082

### Nextcloud
- **Interface Web** : http://PI_IP:8080 (si installé)

### Syncthing
- **Interface Web** : http://PI_IP:8384

---

## 🎬 Media & Divertissement

### Jellyfin
- **Interface Web** : http://PI_IP:8096

### Radarr (Films)
- **Interface Web** : http://PI_IP:7878

### Sonarr (Séries)
- **Interface Web** : http://PI_IP:8989

### Prowlarr (Indexeur)
- **Interface Web** : http://PI_IP:9696

### qBittorrent
- **WebUI** : http://PI_IP:8083

### Navidrome (Musique)
- **Interface Web** : http://PI_IP:4533

### Calibre-Web (eBooks)
- **Interface Web** : http://PI_IP:8084

---

## 🏠 Domotique

### Home Assistant
- **Interface Web** : http://PI_IP:8123

### Node-RED
- **Interface Web** : http://PI_IP:1880

### MQTT (Mosquitto)
- **Broker** : `PI_IP:1883`
- **WebSocket** : `PI_IP:9001`

### Zigbee2MQTT
- **Interface Web** : http://PI_IP:8085

---

## 📝 Productivité

### Immich (Photos)
- **Interface Web** : http://PI_IP:2283

### Paperless-ngx (Documents)
- **Interface Web** : http://PI_IP:8086

### Joplin Server (Notes)
- **API** : http://PI_IP:22300

---

## 🔐 Sécurité & Auth

### Authelia (SSO)
- **Interface** : http://PI_IP:9091

### Vaultwarden (Passwords)
- **Interface Web** : http://PI_IP:8087

---

## 🔧 Infrastructure

### Pi-hole (DNS)
- **Admin** : http://PI_IP:8088
- **DNS** : Port 53

### Homepage (Dashboard)
- **Interface** : http://PI_IP:3003

---

## 🔑 Identifiants par défaut

### Supabase
- **Studio** : Pas d'auth par défaut
- **PostgreSQL** : `postgres` / (voir `~/stacks/supabase/.env`)

### Grafana
- **User** : `admin`
- **Password** : `admin` (à changer au 1er login)

### Traefik
- **Dashboard** : Protégé par Authelia (si configuré)

### FileBrowser
- **User** : `admin`
- **Password** : `admin`

---

## 🚀 Accès rapide

### Dashboard principal
```bash
http://PI_IP:3003  # Homepage
```

### Services essentiels
```bash
http://PI_IP:3000  # Supabase Studio
http://PI_IP:3001  # Grafana
http://PI_IP:8123  # Home Assistant
```

### Monitoring
```bash
http://PI_IP:8080  # Traefik Dashboard
http://PI_IP:3002  # Uptime Kuma
http://PI_IP:9090  # Prometheus
```

---

## 📱 Accès distant (VPN)

Si Tailscale est configuré :
```
http://pi5.tailscale-name.ts.net:PORT
```

Ou avec DuckDNS/Cloudflare :
```
https://monpi.duckdns.org/service
https://service.mondomaine.fr
```

---

## 🔍 Trouver un service

**Méthode 1 : Docker**
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

**Méthode 2 : Netstat**
```bash
sudo netstat -tlnp | grep LISTEN
```

**Méthode 3 : Script info**
```bash
~/pi5-setup/common-scripts/09-stack-manager.sh status
```

---

## 💡 Conseils

### Favoris navigateur
Créez un dossier "Pi5 Services" avec :
- Supabase Studio (3000)
- Grafana (3001)
- Homepage (3003)
- Home Assistant (8123)

### Accès mobile
Utilisez une app type "Hermit" ou "Web Apps" pour créer des raccourcis sur mobile.

### Sécurité
- Changez **tous** les mots de passe par défaut
- Activez Authelia pour protéger les services sensibles
- Utilisez Traefik + HTTPS pour l'accès externe

---

<p align="center">
  <strong>🎯 Tous vos services à portée de clic !</strong>
</p>
