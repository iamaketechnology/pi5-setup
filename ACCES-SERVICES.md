# 🔗 Accès aux Services - Pi5 Setup

> **Guide de connexion pour tous les services installés sur votre Raspberry Pi 5**

---

## 📋 Résumé Rapide

| Service | URL Principale | Type d'Accès |
|---------|---------------|--------------|
| **Homepage** | `http://192.168.1.74:3001` | Local uniquement |
| **Traefik Dashboard** | `http://localhost:8081/dashboard/` | SSH Tunnel requis |
| **Portainer** | `http://192.168.1.74:8080` | Direct local |
| **Grafana** | `https://pimaketechnology.duckdns.org/grafana` | HTTPS (DuckDNS) |
| **Supabase Studio** | `https://pimaketechnology.duckdns.org/project/default` | HTTPS (DuckDNS) |
| **Supabase API** | `https://pimaketechnology.duckdns.org/api` | HTTPS (DuckDNS) |

---

## 🏠 Homepage Dashboard

### Accès Direct (Recommandé)

**URL**: `http://192.168.1.74:3001`

**Pourquoi pas de HTTPS?**
- Homepage est une application Next.js
- Next.js ne supporte pas les chemins de base (`/home`) avec path-based routing
- Solution: Accès local uniquement sur port 3001

**Depuis votre Mac**:
```
http://192.168.1.74:3001
```

**Depuis le Pi**:
```bash
curl http://localhost:3001
# ou
firefox http://localhost:3001  # si interface graphique
```

**Widgets Disponibles**:
- CPU, RAM, disque, température
- Portainer (stats containers)
- Liens vers tous vos services

---

## 🔀 Traefik Reverse Proxy

### Dashboard (Localhost Uniquement)

**⚠️ Limitation**: Traefik v3 dashboard ne supporte pas PathPrefix routing.

**Solution**: Dashboard accessible uniquement via localhost sur le Pi.

### Option 1: SSH Tunnel (Depuis Mac)

```bash
# Ouvrir un tunnel SSH
ssh -L 8081:localhost:8081 pi@192.168.1.74 -N

# Dans un autre terminal, ou en arrière-plan:
ssh -L 8081:localhost:8081 pi@192.168.1.74 -N &
```

Ensuite, accédez au dashboard:
```
http://localhost:8081/dashboard/
```

**⚠️ IMPORTANT**: Le slash final `/` est **OBLIGATOIRE**

### Option 2: Accès Direct depuis le Pi

```bash
# SSH dans le Pi
ssh pi@192.168.1.74

# Puis accédez au dashboard localement
curl http://localhost:8081/dashboard/ | less
# ou avec un navigateur sur le Pi
firefox http://localhost:8081/dashboard/
```

### API REST Traefik

```bash
# Lister tous les routers
curl -s http://localhost:8081/api/http/routers | jq

# Lister tous les services
curl -s http://localhost:8081/api/http/services | jq

# Voir les middlewares
curl -s http://localhost:8081/api/http/middlewares | jq

# Status overview
curl -s http://localhost:8081/api/overview | jq
```

---

## 🐳 Portainer

### Accès Web

**URL**: `http://192.168.1.74:8080`

**Credentials**:
- Username: `maketech`
- Password: `testadmin1234`

**Depuis votre Mac**:
```
http://192.168.1.74:8080
```

**Depuis le Pi**:
```bash
curl http://localhost:8080
# ou
firefox http://localhost:8080
```

### API Portainer

**Endpoint**: `http://192.168.1.74:8080/api/`

**Authentification**: API Token (via Header)

**Créer un Token**:
```bash
# Sur le Pi
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/portainer/scripts/create-portainer-token.sh | sudo bash
```

**Utiliser le Token**:
```bash
# Exemple: Lister les endpoints
curl -s http://localhost:8080/api/endpoints \
  -H 'X-API-Key: ptr_VOTRE_TOKEN_ICI' | jq

# Lister les containers
curl -s http://localhost:8080/api/endpoints/3/docker/containers/json?all=1 \
  -H 'X-API-Key: ptr_VOTRE_TOKEN_ICI' | jq
```

**Endpoint ID**: `3` (pour votre installation)

---

## 📊 Grafana Monitoring

### Interface Web

**URL**: `https://pimaketechnology.duckdns.org/grafana`

**Type**: HTTPS via Traefik + DuckDNS

**Credentials**:
- Username: `admin`
- Password: `Monitoring2025!Pi5` (ou voir `/home/pi/stacks/monitoring/CREDENTIALS.txt`)

**Accès**:
- Depuis n'importe où (internet)
- HTTPS automatique avec Let's Encrypt
- Path-based routing: `/grafana/*`

**Depuis votre Mac**:
```
https://pimaketechnology.duckdns.org/grafana
```

**Depuis le Pi**:
```bash
# Health check
curl http://localhost:3000/api/health

# Via Traefik
curl -k https://pimaketechnology.duckdns.org/grafana/api/health
```

### Dashboards Pré-configurés

1. **Raspberry Pi 5 - System Metrics**
   - CPU usage, Memory, Disk, Temperature, Network

2. **Docker Containers - Resource Usage**
   - Container CPU, Memory, Network I/O

3. **Supabase PostgreSQL - Database Metrics**
   - Connections, Transactions, Cache hit ratio, Database size

### Prometheus (Backend)

**URL**: Interne uniquement (réseau Docker)

**Accès depuis le Pi**:
```bash
# API
curl http://localhost:9090/api/v1/status/config

# Targets
curl http://localhost:9090/api/v1/targets

# Query
curl 'http://localhost:9090/api/v1/query?query=up'
```

**Métriques collectées**:
- **Node Exporter**: Métriques système (CPU, RAM, disque, température)
- **cAdvisor**: Métriques Docker containers
- **Postgres Exporter**: Métriques PostgreSQL Supabase

**Retention**: 15 jours (configurable)

### Commandes Utiles

```bash
# Voir password Grafana
ssh pi@192.168.1.74 "grep GRAFANA_ADMIN_PASSWORD /home/pi/stacks/monitoring/.env"

# Restart Grafana
ssh pi@192.168.1.74 "cd /home/pi/stacks/monitoring && docker compose restart grafana"

# Logs Grafana
ssh pi@192.168.1.74 "docker logs grafana --tail 50"

# Logs Prometheus
ssh pi@192.168.1.74 "docker logs prometheus --tail 50"

# Status containers monitoring
ssh pi@192.168.1.74 "docker ps | grep -E '(grafana|prometheus|node_exporter|cadvisor|postgres_exporter)'"
```

---

## 🗄️ Supabase

### Studio (Interface Web)

**URL**: `https://pimaketechnology.duckdns.org/project/default`

**Type**: HTTPS via Traefik + DuckDNS

**Accès**:
- Depuis n'importe où (internet)
- HTTPS automatique avec Let's Encrypt
- Path-based routing: `/project/*`

**Credentials** (à configurer au premier accès):
- Voir: `/home/pi/stacks/supabase/.env`
- Variables: `DASHBOARD_USERNAME` et `DASHBOARD_PASSWORD`

**Depuis votre Mac**:
```
https://pimaketechnology.duckdns.org/project/default
```

### API REST

**URL**: `https://pimaketechnology.duckdns.org/api`

**Documentation**: Auto-générée par PostgREST

**Exemples**:
```bash
# Health check (sans auth)
curl https://pimaketechnology.duckdns.org/api/

# Accéder à une table (avec auth)
curl https://pimaketechnology.duckdns.org/api/your_table \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

**Clés API**:
```bash
# Sur le Pi, lire les clés:
ssh pi@192.168.1.74 "grep 'ANON_KEY\|SERVICE_ROLE_KEY' /home/pi/stacks/supabase/.env"
```

### Realtime (WebSockets)

**URL**: `wss://pimaketechnology.duckdns.org/api/realtime/v1/websocket`

### Storage

**URL**: `https://pimaketechnology.duckdns.org/api/storage/v1`

**Exemple**:
```bash
# Lister les buckets
curl https://pimaketechnology.duckdns.org/api/storage/v1/bucket \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY"
```

### Auth

**URL**: `https://pimaketechnology.duckdns.org/api/auth/v1`

**Exemples**:
```bash
# Sign up
curl -X POST https://pimaketechnology.duckdns.org/api/auth/v1/signup \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"securepassword"}'

# Sign in
curl -X POST https://pimaketechnology.duckdns.org/api/auth/v1/token?grant_type=password \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"securepassword"}'
```

### PostgreSQL Direct

**Host**: `192.168.1.74`
**Port**: `5432`
**Database**: `postgres`
**User**: `postgres`
**Password**: Voir `/home/pi/stacks/supabase/.env` → `POSTGRES_PASSWORD`

**Connexion depuis Mac**:
```bash
psql -h 192.168.1.74 -p 5432 -U postgres -d postgres
```

**Connexion depuis Pi**:
```bash
docker exec -it supabase-db psql -U postgres
```

---

## 🔐 Credentials par Défaut

### Supabase

```bash
# Voir tous les credentials
ssh pi@192.168.1.74 "cat /home/pi/stacks/supabase/.env | grep -E '(PASSWORD|KEY|JWT_SECRET)'"
```

**Variables importantes**:
- `POSTGRES_PASSWORD`: Mot de passe PostgreSQL
- `ANON_KEY`: Clé publique pour client-side
- `SERVICE_ROLE_KEY`: Clé admin (backend uniquement)
- `JWT_SECRET`: Secret pour JWT tokens
- `DASHBOARD_USERNAME`: Username Studio
- `DASHBOARD_PASSWORD`: Password Studio

### Portainer

- **Username**: `maketech`
- **Password**: `testadmin1234`

### Traefik

- Aucun credential (dashboard localhost uniquement)

---

## 🌐 Accès depuis l'Extérieur (Internet)

### Services Accessibles Publiquement

Seuls ces services sont accessibles depuis internet via DuckDNS + Let's Encrypt:

1. **Supabase Studio**: `https://pimaketechnology.duckdns.org/project/default`
2. **Supabase API**: `https://pimaketechnology.duckdns.org/api`

### Services Locaux Uniquement

Ces services ne sont **PAS** exposés sur internet:

- Homepage: `http://192.168.1.74:3001`
- Portainer: `http://192.168.1.74:8080`
- Traefik Dashboard: `http://localhost:8081/dashboard/` (localhost Pi uniquement)

**Pour y accéder depuis l'extérieur**, vous devez:

#### Option 1: VPN (Recommandé)

```bash
# Installer Tailscale (exemple)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

Ensuite, accédez via IP Tailscale au lieu de `192.168.1.74`

#### Option 2: SSH Tunnel (Temporaire)

```bash
# Depuis votre machine externe
ssh -L 3001:localhost:3001 -L 8080:localhost:8080 pi@your-public-ip -N

# Puis accédez via:
# http://localhost:3001 (Homepage)
# http://localhost:8080 (Portainer)
```

#### Option 3: Cloudflare Tunnel (Avancé)

Voir: `01-infrastructure/external-access/cloudflare-tunnel/`

---

## 🛠️ Commandes Utiles

### Lister Tous les Containers

```bash
ssh pi@192.168.1.74 "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
```

### Tester Connectivité depuis Mac

```bash
# Homepage
curl -I http://192.168.1.74:3001

# Portainer
curl -I http://192.168.1.74:8080

# Supabase Studio (HTTPS)
curl -I https://pimaketechnology.duckdns.org/project/default

# Supabase API
curl -I https://pimaketechnology.duckdns.org/api
```

### Tester Connectivité depuis Pi

```bash
ssh pi@192.168.1.74 << 'EOSSH'
echo "=== Homepage ==="
curl -I http://localhost:3001 2>&1 | head -1

echo "=== Portainer ==="
curl -I http://localhost:8080 2>&1 | head -1

echo "=== Traefik Dashboard ==="
curl -I http://localhost:8081/dashboard/ 2>&1 | head -1

echo "=== Supabase Studio ==="
curl -I http://localhost:3000 2>&1 | head -1

echo "=== Supabase Kong ==="
curl -I http://localhost:8000 2>&1 | head -1
EOSSH
```

### Vérifier Logs

```bash
# Homepage
ssh pi@192.168.1.74 "docker logs homepage --tail 50"

# Portainer
ssh pi@192.168.1.74 "docker logs portainer --tail 50"

# Traefik
ssh pi@192.168.1.74 "docker logs traefik --tail 50"

# Supabase Studio
ssh pi@192.168.1.74 "docker logs supabase-studio --tail 50"
```

---

## 📱 Bookmarks Recommandés

Créez ces bookmarks dans votre navigateur:

### Accès Quotidiens
```
📊 Homepage       → http://192.168.1.74:3001
🐳 Portainer      → http://192.168.1.74:8080
📈 Grafana        → https://pimaketechnology.duckdns.org/grafana
🗄️ Supabase       → https://pimaketechnology.duckdns.org/project/default
```

### Accès Occasionnels
```
🔀 Traefik        → http://localhost:8081/dashboard/ (SSH tunnel requis)
🌐 API Supabase   → https://pimaketechnology.duckdns.org/api
```

---

## 🔒 Sécurité

### Recommandations

1. **Changez les mots de passe par défaut**:
   ```bash
   # Portainer: via UI (Settings → Users)
   # Supabase: éditez /home/pi/stacks/supabase/.env puis docker compose restart
   ```

2. **Ne pas exposer Portainer sur internet** (déjà le cas)

3. **Utilisez VPN pour accès externe** aux services locaux

4. **Sauvegardes régulières**:
   ```bash
   # Supabase
   ssh pi@192.168.1.74 "cd /home/pi/stacks/supabase && docker compose exec -T db pg_dumpall -U postgres > backup_$(date +%Y%m%d).sql"
   ```

5. **Monitoring des logs**:
   ```bash
   ssh pi@192.168.1.74 "tail -f /home/pi/stacks/traefik/logs/access.log"
   ```

---

## 🐛 Troubleshooting

### Service ne répond pas

1. Vérifier que le container tourne:
   ```bash
   ssh pi@192.168.1.74 "docker ps | grep <service>"
   ```

2. Vérifier les logs:
   ```bash
   ssh pi@192.168.1.74 "docker logs <service> --tail 50"
   ```

3. Redémarrer le service:
   ```bash
   ssh pi@192.168.1.74 "docker restart <service>"
   ```

### Traefik Dashboard 404

**Problème**: `http://localhost:8081/dashboard` retourne 404

**Solution**: Ajoutez le slash final → `http://localhost:8081/dashboard/`

### Homepage ne charge pas

1. Vérifier port 3001:
   ```bash
   ssh pi@192.168.1.74 "netstat -tlnp | grep 3001"
   ```

2. Vérifier host validation:
   ```bash
   ssh pi@192.168.1.74 "docker logs homepage --tail 20 | grep -i 'host validation'"
   ```

### Supabase Studio assets 404

**Cause**: Problème de routing Next.js

**Solution**: Vérifiez que les deux routers Traefik sont présents:
```bash
ssh pi@192.168.1.74 "docker exec traefik wget -qO- http://localhost:8080/api/http/routers | jq '.[] | select(.name | contains(\"studio\"))'"
```

Vous devriez voir:
- `supabase-studio@docker` (route `/project`)
- `supabase-studio-assets@docker` (routes `/_next`, `/img`, `/monaco-editor`)

---

## 📚 Documentation Complémentaire

- [Homepage Guide](08-interface/homepage/GUIDE-DEBUTANT.md)
- [Portainer Scripts](08-interface/portainer/scripts/README.md)
- [Traefik Scenarios](01-infrastructure/traefik/docs/SCENARIOS-COMPARISON.md)
- [Supabase Setup](01-infrastructure/supabase/INSTALL.md)

---

**Dernière mise à jour**: 2025-10-13
**Version**: 1.1.0
**Maintainer**: [@iamaketechnology](https://github.com/iamaketechnology)
