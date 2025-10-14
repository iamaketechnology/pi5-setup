# 🚀 PI5 Control Center v3.5.0

**Interface web modulaire pour gérer votre Raspberry Pi 5 - Architecture ES6 + CSS modulaire.**

⚡ **v3.5.0** : Architecture 100% modulaire (JS: 14 modules ES6 + CSS: 16 composants), maintainabilité maximale, zéro build step.

---

## 🎯 Fonctionnalités v2.0

### 📊 Dashboard Système
- **Monitoring temps réel** : CPU, RAM, Température, Disque (update toutes les 5s)
- **Services Docker** : Statut live avec métriques CPU/RAM
- **Actions rapides** : Backup, Healthcheck, Security Scan, Update
- **Terminal intégré** : Logs d'exécution en temps réel via WebSocket

### 🗂️ Organisation par Catégories
- **🚀 Déploiement** : Tous les scripts `*-deploy.sh`
- **🔧 Maintenance** : Scripts de backup, healthcheck, update
- **🧪 Tests** : Scripts de diagnostic et validation
- **⚙️ Configuration** : Scripts utils + common-scripts
- **🐳 Docker** : Gestion complète des conteneurs (start/stop/restart/logs)

### ✨ Nouvelles Fonctionnalités
- ✅ **Navigation par onglets** (6 sections distinctes)
- ✅ **Auto-découverte** de TOUS les scripts du projet
- ✅ **Recherche/Filtrage** par nom ou catégorie
- ✅ **Stats système live** (CPU, RAM, Temp, Disk, Uptime)
- ✅ **Déploiement Docker** (tourne sur le Pi, pas localement)
- ✅ **SSH localhost** (commandes exécutées directement sur le Pi)
- ✅ **Traefik integration** (admin.pi5.local)

---

## 🏗️ Architecture Modulaire v3.5.0

### 📦 JavaScript - ES6 Modules (14 modules / ~86KB)

**Core**
- `main.js` - Entry point & orchestration
- `config.js` - Configuration dynamique (zéro hardcoding)
- `utils/api.js` - API client wrapper
- `utils/socket.js` - WebSocket wrapper

**Features**
- `modules/tabs.js` - Navigation par onglets
- `modules/pi-selector.js` - Gestion multi-Pi
- `modules/terminal.js` - Terminal interactif multi-onglets
- `modules/network.js` - Monitoring réseau complet
- `modules/docker.js` - Gestion containers Docker
- `modules/system-stats.js` - Stats système (CPU/RAM/Disk/Temp)
- `modules/scripts.js` - Découverte & exécution scripts
- `modules/history.js` - Historique d'exécution
- `modules/scheduler.js` - Planificateur de tâches
- `modules/services.js` - Découverte services Docker

### 🎨 CSS - Modular Components (16 composants / ~30KB)

**Architecture**
- `main.css` - Entry point avec @import
- `components/variables.css` - Design tokens (colors, spacing)
- `components/base.css` - Reset & base styles
- `components/layout.css` - Layout system
- 12 composants UI (header, tabs, cards, terminal, buttons, modal, forms, scripts, docker, history, scheduler, network)
- `components/responsive.css` - Media queries
- `style.css` - Legacy (~14K reste)

**Avantages Architecture Modulaire**
- ✅ **JS Maintenable** : ~180 lignes/module (vs 1883 lignes monolithique)
- ✅ **CSS Maintenable** : 16 fichiers CSS (vs 2338 lignes monolithique)
- ✅ **Testable** : Isolation complète, tests unitaires faciles
- ✅ **Réutilisable** : Import/export natifs (JS + CSS @import)
- ✅ **Zéro build** : Modules natifs du navigateur
- ✅ **Performance** : Browser caching, lazy loading

---

## 🚀 Installation RAPIDE (Sur le Pi)

**RECOMMANDÉ** : Installer ceci en PREMIER sur un Pi vierge.

### One-Liner Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/tools/admin-panel/scripts/00-install-panel-on-pi.sh | sudo bash
```

**Ce script va** :
1. ✅ Cloner le repo `pi5-setup`
2. ✅ Installer Docker + Node.js
3. ✅ Configurer SSH localhost
4. ✅ Build l'image Docker
5. ✅ Déployer le container
6. ✅ Vérifier le démarrage

**Durée** : ~5-10 minutes (selon connexion internet)

---

## 🌐 Accès

Après installation, ouvrir dans le navigateur :

```
http://<IP_DU_PI>:4000
```

**Exemples** :
- `http://192.168.1.74:4000`
- `http://pi5.local:4000`
- `http://localhost:4000` (depuis le Pi)

**Avec Traefik** (si installé) :
- `http://admin.pi5.local`

---

## 📸 Interface v2.0

```
┌─────────────────────────────────────────────────────────────────┐
│ 🚀 PI5 Control Center          SSH: 🟢 pi@pi5  Version: v2.0   │
├─────────────────────────────────────────────────────────────────┤
│ [🏠 Dashboard] [🚀 Deploy] [🔧 Maintenance] [🧪 Tests] [🐳 Docker] [⚙️ Config] │
├──────────────────────┬──────────────────────────────────────────┤
│                      │                                          │
│ 📊 Système           │ 🐳 Services Docker (12 running)          │
│ ┌──────────────────┐ │ ┌──────────────────────────────────────┐ │
│ │ CPU:   45% 🟢    │ │ │ ✅ supabase-db      Up 2d            │ │
│ │ RAM:   3.2/8GB   │ │ │ ✅ supabase-kong    Up 2d            │ │
│ │ Temp:  52°C      │ │ │ ✅ dashboard        Up 5h            │ │
│ │ Disk:  120/500GB │ │ │ ✅ n8n              Up 3h            │ │
│ └──────────────────┘ │ └──────────────────────────────────────┘ │
│ ⏱️ Uptime: 2 days    │                                          │
│                      │ ⚡ Actions Rapides                        │
│ ⚡ Actions Rapides   │ ┌──────────────────────────────────────┐ │
│ ┌──────────────────┐ │ │ 💾 Backup All    🏥 Healthcheck      │ │
│ │ 💾 Backup All    │ │ │ 🔒 Security Scan 🔄 Update All       │ │
│ │ 🏥 Healthcheck   │ │ └──────────────────────────────────────┘ │
│ │ 🔒 Security Scan │ │                                          │
│ │ 🔄 Update All    │ │ 💻 Terminal                              │
│ └──────────────────┘ │ ┌──────────────────────────────────────┐ │
│                      │ │ [INFO] Script uploaded               │ │
│                      │ │ [INFO] Running supabase-deploy.sh    │ │
│                      │ │ [SUCCESS] Deployment completed       │ │
│                      │ └──────────────────────────────────────┘ │
└──────────────────────┴──────────────────────────────────────────┘
```

---

## 🔧 Gestion du Container

### Status & Logs

```bash
# Vérifier statut
docker ps | grep pi5-admin-panel

# Voir logs en temps réel
docker logs -f pi5-admin-panel

# Voir dernières 50 lignes
docker logs pi5-admin-panel --tail 50
```

### Restart / Stop

```bash
# Redémarrer
docker restart pi5-admin-panel

# Arrêter
docker stop pi5-admin-panel

# Démarrer
docker start pi5-admin-panel

# Rebuild complet
cd ~/pi5-setup/tools/admin-panel
docker compose down
docker compose build --no-cache
docker compose up -d
```

### Mise à jour du Panel

```bash
# Pull dernière version du repo
cd ~/pi5-setup
git pull origin main

# Rebuild image Docker
cd tools/admin-panel
docker compose down
docker compose build
docker compose up -d
```

---

## 🗂️ Structure du Projet

```
tools/admin-panel/
├── Dockerfile                   # Image Docker Node.js + SSH
├── docker-compose.yml           # Déploiement avec volumes
├── package.json                 # Dépendances (express, socket.io, node-ssh)
├── server.js                    # Backend API + WebSocket
├── config.pi.js                 # Config localhost (pour Pi)
├── config.example.js            # Config exemple (pour dev local)
├── scripts/
│   └── 00-install-panel-on-pi.sh  # Bootstrap installer
├── public/
│   ├── index.html               # UI multi-tabs
│   ├── css/
│   │   └── style.css            # Styles dark theme
│   └── js/
│       └── app.js               # Client logic + WebSocket
└── README.md                    # Ce fichier
```

---

## 🔌 API Endpoints

### `GET /api/status`
Statut connexion SSH

**Response:**
```json
{
  "connected": true,
  "host": "localhost",
  "username": "pi"
}
```

---

### `GET /api/system/stats`
Stats système temps réel

**Response:**
```json
{
  "cpu": 42.5,
  "memory": {
    "used": 3200,
    "total": 8192,
    "percent": 39
  },
  "temperature": 52.3,
  "disk": {
    "used": "120G",
    "total": "500G",
    "percent": 24
  },
  "uptime": "2 days, 3 hours",
  "docker": [
    { "name": "supabase-db", "cpu": "2.5%", "mem": "512MB" }
  ]
}
```

---

### `GET /api/scripts`
Liste TOUS les scripts découverts (groupés par type)

**Response:**
```json
{
  "scripts": [
    {
      "id": "base64...",
      "name": "supabase deploy",
      "category": "01-infrastructure",
      "service": "supabase",
      "type": "deploy",
      "icon": "🚀",
      "typeLabel": "Déploiement",
      "path": "01-infrastructure/supabase/scripts/02-supabase-deploy.sh"
    }
  ]
}
```

**Types détectés** :
- `deploy` : Scripts `*-deploy.sh`
- `maintenance` : Scripts dans `/maintenance/`
- `utils` : Scripts dans `/utils/`
- `test` : Scripts `*-test.sh` ou `diagnose*`
- `common` : Scripts dans `common-scripts/`

---

### `POST /api/execute`
Exécuter un script

**Body:**
```json
{
  "scriptPath": "01-infrastructure/supabase/scripts/02-supabase-deploy.sh"
}
```

**Response:**
```json
{
  "success": true,
  "executionId": "1736874000000",
  "message": "Script execution started. Connect to WebSocket for logs."
}
```

---

### `GET /api/docker/containers`
Liste conteneurs Docker

---

### `POST /api/docker/:action/:container`
Actions Docker (start/stop/restart)

---

### `GET /api/docker/logs/:container?lines=100`
Logs conteneur

---

## 🔐 Sécurité

### ⚠️ IMPORTANT

- ✅ **Écoute sur 0.0.0.0** : Accessible depuis le réseau local
- ✅ **SSH localhost** : Pas d'exposition SSH externe
- ✅ **Clés SSH** : Authentification par clé (pas de password)
- ✅ **Docker socket** : Read-only dans le container
- ⚠️ **Pas d'auth web** : Utiliser firewall ou Traefik avec BasicAuth

### Bonnes Pratiques

1. **Firewall UFW** : Limiter accès port 4000 à IP locales
```bash
sudo ufw allow from 192.168.1.0/24 to any port 4000
```

2. **Traefik BasicAuth** : Ajouter authentification via Traefik
```yaml
# docker-compose.yml
labels:
  - "traefik.http.routers.admin-panel.middlewares=auth@file"
```

3. **VPN uniquement** : Installer Tailscale, n'exposer que via VPN

---

## 🐛 Dépannage

| Problème | Solution |
|----------|----------|
| **Container won't start** | `docker logs pi5-admin-panel --tail 50` |
| **Can't connect to SSH** | Vérifier `~/.ssh/authorized_keys` permissions (600) |
| **Scripts not found** | Vérifier volume `/app/project` mounted correctly |
| **Port 4000 in use** | Changer port dans `docker-compose.yml` |
| **Stats not updating** | SSH localhost connection failed, check keys |

### Tester SSH localhost manuellement

```bash
ssh -o StrictHostKeyChecking=no localhost "echo 'SSH OK'"
```

Si ça ne marche pas, le panel ne pourra pas exécuter de commandes.

---

## 🔄 Workflow Typique

1. **Bootstrap Pi** : Curl one-liner installer
2. **Accès panel** : Ouvrir `http://pi5.local:4000`
3. **Dashboard** : Voir stats système + services
4. **Déployer service** : Onglet Deploy → Cliquer script → Confirmer
5. **Observer logs** : Terminal montre exécution live
6. **Gérer Docker** : Onglet Docker → Restart services
7. **Maintenance** : Onglet Maintenance → Backup, Healthcheck

---

## 🆚 Comparaison v1.0 vs v2.0

| Feature | v1.0 (Local Mac) | v2.0 (Sur Pi) |
|---------|------------------|---------------|
| **Déploiement** | Tourne sur Mac | Tourne sur Pi (Docker) |
| **SSH** | Mac → Pi | Localhost (Pi → Pi) |
| **Interface** | Liste scripts simple | Multi-tabs + Dashboard |
| **Monitoring** | ❌ | ✅ Stats temps réel |
| **Catégories** | ❌ | ✅ 5 types organisés |
| **Docker mgmt** | Basique | Complet (stats, logs) |
| **Accès** | Localhost:4000 | Réseau:4000 + Traefik |
| **Installation** | npm install local | One-liner bootstrap |

---

## 🚀 Prochaines Évolutions (v3.0)

- [ ] Multi-Pi support (switcher entre plusieurs Pi)
- [ ] Historique exécutions (base SQLite)
- [ ] Scheduler cron jobs via interface
- [ ] Notifications webhooks/Telegram
- [ ] Authentification utilisateurs
- [ ] Export/Import configuration
- [ ] Graphiques stats historiques
- [ ] Backup automatiques planifiés

---

## 📚 Stack Technique

| Composant | Version | Rôle |
|-----------|---------|------|
| **Node.js** | 18 Alpine | Runtime |
| **Express** | 4.21 | HTTP server |
| **Socket.io** | 4.8 | WebSocket (logs temps réel) |
| **node-ssh** | 13.2 | Client SSH (localhost) |
| **Glob** | - | Découverte scripts |
| **Docker** | - | Container runtime |

---

## 🤝 Contribution

Le panel est extensible :

### Ajouter un Quick Action

Éditer [public/js/app.js](public/js/app.js:406-417) :

```js
const actionMap = {
  'backup': 'common-scripts/04-backup-rotate.sh',
  'custom': 'path/to/your-script.sh'  // Ajouter ici
};
```

### Ajouter un Pattern de Découverte

Éditer [server.js](server.js:115-122) :

```js
const allPatterns = [
  '*/*/scripts/*-deploy.sh',
  'custom-folder/**/*.sh'  // Ajouter ici
];
```

---

## 📚 Documentation

### Structure du Projet

```
tools/admin-panel/
├── docs/                       # 📚 Documentation
│   ├── architecture/
│   │   ├── JS-ARCHITECTURE.md     # Architecture JS ES6
│   │   ├── CSS-ARCHITECTURE.md    # Architecture CSS modulaire
│   │   └── REFACTORING-*.md       # Historique refactoring
│   └── changelogs/
│       └── CHANGELOG-v3.*.md      # Changelogs par version
├── lib/                        # Backend modules (7 files)
│   ├── auth.js
│   ├── database.js
│   ├── network-manager.js
│   ├── notifications.js
│   ├── pi-manager.js
│   ├── scheduler.js
│   └── services-info.js
├── public/                     # Frontend
│   ├── css/
│   │   ├── components/         # 16 modules CSS
│   │   ├── main.css           # Entry point CSS
│   │   └── style.css          # Legacy (~14K)
│   ├── js/
│   │   ├── modules/            # 10 ES6 modules
│   │   ├── utils/              # API + Socket
│   │   ├── main.js            # Entry point JS
│   │   └── config.js          # Client config
│   └── index.html
├── scripts/                    # Utility scripts
├── config.example.js          # Configuration template
├── config.js                  # Active configuration
├── server.js                  # Express backend
├── package.json
├── CHANGELOG.md               # Master changelog
├── REFACTORING-PLAN.md        # Current refactoring plan
└── README.md                  # This file
```

### Documentation Technique

- **[docs/architecture/JS-ARCHITECTURE.md](docs/architecture/JS-ARCHITECTURE.md)** - Architecture JavaScript ES6 complète
- **[docs/architecture/CSS-ARCHITECTURE.md](docs/architecture/CSS-ARCHITECTURE.md)** - Architecture CSS modulaire complète
- **[REFACTORING-PLAN.md](REFACTORING-PLAN.md)** - Plan de refactoring et progression
- **[CHANGELOG.md](CHANGELOG.md)** - Historique des versions

---

**Version**: 3.5.0
**Auteur**: PI5-SETUP Project
**Licence**: MIT
**Repo**: https://github.com/iamaketechnology/pi5-setup
