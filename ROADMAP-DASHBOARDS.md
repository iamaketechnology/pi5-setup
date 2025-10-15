# 🗺️ Roadmap - PI5 Dashboard & Admin Panel

**Version actuelle** : Dashboard v1.0.0 | Admin Panel v1.0.0
**Dernière mise à jour** : 2025-01-14

---

## 📊 PI5 Dashboard (Monitoring n8n)

### ✅ v1.0.0 - Actuel (2025-01-14)
- [x] WebSocket temps réel
- [x] Interface responsive dark mode
- [x] Filtres basiques (tous/succès/erreurs/pending)
- [x] Boutons actions (approuver/rejeter)
- [x] 100 dernières notifications en mémoire
- [x] API webhook pour n8n
- [x] Health check endpoint

---

### 🎯 v1.1.0 - Authentification & Sécurité

**Priorité** : HAUTE
**Estimation** : 2-3h

#### Features
- [ ] **Login/Password simple** (variables env)
  - Session cookies (express-session)
  - Route `/login` avec formulaire
  - Middleware auth pour protéger routes

- [ ] **Rate limiting** sur webhook
  - express-rate-limit (100 req/min max)
  - Éviter spam notifications

- [ ] **HTTPS via Traefik**
  - Labels Traefik TLS
  - Certificate resolver Let's Encrypt

#### Fichiers concernés
```
src/server/index.js          # Middleware auth
src/server/auth.js           # Logique authentification (nouveau)
src/public/login.html        # Page login (nouveau)
compose/docker-compose.yml   # Variables AUTH_USER/AUTH_PASSWORD
```

#### Breaking changes
⚠️ Webhook n8n devra inclure header `Authorization: Bearer <token>`

---

### 🎯 v1.2.0 - Persistance & Historique

**Priorité** : MOYENNE
**Estimation** : 3-4h

#### Features
- [ ] **Redis pour storage**
  - Remplacer array en mémoire
  - Persistance après redémarrage
  - Historique illimité (avec TTL 30 jours)

- [ ] **Pagination** notifications
  - Charger 50 par 50
  - Infinite scroll

- [ ] **Recherche full-text**
  - Chercher dans message/workflow
  - Regex support

#### Architecture
```
services:
  dashboard:
    depends_on:
      - redis

  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data
```

#### Dépendances
- `redis` (npm package)
- Service Redis Docker

---

### 🎯 v1.3.0 - Analytics & Export

**Priorité** : BASSE
**Estimation** : 4-5h

#### Features
- [ ] **Dashboard stats**
  - Total success/errors (graphiques Chart.js)
  - Workflows les plus actifs
  - Performance moyenne (durée exécution)

- [ ] **Export logs**
  - Format JSON (download)
  - Format CSV (Excel compatible)
  - Format PDF (rapport)

- [ ] **Filtres avancés**
  - Par date (range picker)
  - Par workflow (multi-select)
  - Par execution ID

#### Dépendances
- `chart.js` (graphiques)
- `jspdf` (export PDF)
- `papaparse` (export CSV)

---

### 🎯 v1.4.0 - Notifications & Intégrations

**Priorité** : MOYENNE
**Estimation** : 2-3h

#### Features
- [ ] **Notifications desktop**
  - Web Push API (permission utilisateur)
  - Notifier même si page fermée

- [ ] **Sons personnalisables**
  - Différents sons par statut (success/error)
  - Upload fichiers .mp3

- [ ] **Webhooks sortants**
  - Notification vers Slack/Discord/Teams
  - Configuration par workflow

#### Configuration exemple
```json
{
  "notifications": {
    "desktop": true,
    "sound": {
      "success": "/sounds/success.mp3",
      "error": "/sounds/error.mp3"
    },
    "webhooks": [
      {
        "url": "https://hooks.slack.com/...",
        "events": ["error"]
      }
    ]
  }
}
```

---

## 🖥️ Admin Panel (Gestion Pi via SSH)

### ✅ v1.0.0 - Actuel (2025-01-14)
- [x] Connexion SSH avec node-ssh
- [x] Auto-découverte scripts déploiement
- [x] Exécution scripts avec logs temps réel
- [x] Gestion Docker (list/start/stop/restart/logs)
- [x] Terminal interface
- [x] Confirmation modale avant exécution

---

### 🎯 v1.1.0 - Multi-Pi Support

**Priorité** : HAUTE
**Estimation** : 3-4h

#### Features
- [ ] **Gestion plusieurs Pi**
  - Switcher entre Pi via dropdown
  - Config multi-hosts dans `config.js`
  - Status simultané (tous les Pi)

- [ ] **Comparaison Pi**
  - Vue côte-à-côte (containers, scripts)
  - Déployer même script sur plusieurs Pi

- [ ] **Groupes Pi**
  - Production / Staging / Dev
  - Actions groupées (restart all)

#### Configuration
```js
// config.js
pis: [
  {
    name: 'Pi Production',
    host: '192.168.1.118',
    username: 'pi',
    privateKey: '...',
    tags: ['production']
  },
  {
    name: 'Pi Staging',
    host: '192.168.1.119',
    username: 'pi',
    privateKey: '...',
    tags: ['staging']
  }
]
```

---

### 🎯 v1.2.0 - Historique & Audit

**Priorité** : MOYENNE
**Estimation** : 4-5h

#### Features
- [ ] **Base SQLite locale**
  - Historique toutes exécutions
  - Durée, exit code, logs complets

- [ ] **Audit trail**
  - Qui a lancé quoi, quand
  - Logs consultables

- [ ] **Favoris & Templates**
  - Épingler scripts fréquents
  - Templates déploiement (variables)

#### Schema SQLite
```sql
CREATE TABLE executions (
  id INTEGER PRIMARY KEY,
  pi_host TEXT,
  script_name TEXT,
  executed_at DATETIME,
  duration_ms INTEGER,
  exit_code INTEGER,
  stdout TEXT,
  stderr TEXT
);

CREATE TABLE favorites (
  id INTEGER PRIMARY KEY,
  script_path TEXT,
  display_name TEXT,
  order_index INTEGER
);
```

---

### 🎯 v1.3.0 - Gestion Fichiers

**Priorité** : MOYENNE
**Estimation** : 5-6h

#### Features
- [ ] **Upload fichiers**
  - Drag & drop vers Pi
  - Progress bar (gros fichiers)

- [ ] **Browser fichiers**
  - Explorateur répertoires Pi
  - Download depuis Pi

- [ ] **Éditeur inline**
  - Éditer docker-compose.yml
  - Éditer .env
  - Syntax highlighting (Monaco Editor)

#### Interface mockup
```
┌─────────────────────────────────────┐
│ 📁 /home/pi/stacks/supabase/        │
├─────────────────────────────────────┤
│ 📄 docker-compose.yml      [✏️] [⬇️] │
│ 📄 .env                    [✏️] [⬇️] │
│ 📁 config/                 [📂]     │
└─────────────────────────────────────┘
```

#### Dépendances
- `multer` (upload files)
- `monaco-editor` (code editor web)

---

### 🎯 v1.4.0 - Monitoring Avancé

**Priorité** : BASSE
**Estimation** : 4-5h

#### Features
- [ ] **Métriques système Pi**
  - CPU, RAM, Disk en temps réel
  - Graphiques Chart.js

- [ ] **Logs système**
  - journalctl viewer
  - Filtrer par service

- [ ] **Alertes**
  - CPU > 90% → notification
  - Disk > 80% → warning

#### Données collectées
```
GET /api/pi/metrics
{
  "cpu": 45.2,
  "memory": { "used": 2048, "total": 8192 },
  "disk": { "used": 35, "total": 128 },
  "temperature": 58.3,
  "uptime": 864000
}
```

---

## 🔗 Intégrations Dashboard ↔ Admin Panel

### 🎯 v2.0.0 - Unified Interface

**Priorité** : HAUTE
**Estimation** : 6-8h

#### Vision
**Dashboard** et **Admin Panel** communiquent entre eux.

#### Features
- [ ] **Dashboard → Admin Panel**
  - Notification error → Bouton "Redeploy"
  - Click → Ouvre Admin Panel + Pré-sélection script

- [ ] **Admin Panel → Dashboard**
  - Après déploiement → Webhook Dashboard
  - Status déploiement apparaît dans Dashboard

- [ ] **Single Sign-On**
  - Même authentification (JWT)
  - Un seul login pour les deux

#### Architecture
```
┌─────────────────────────────────────┐
│         Mac (localhost)             │
│                                     │
│  Dashboard (monitoring)  :3100     │
│       ↕️ WebSocket                  │
│  Admin Panel (deploy)    :4000     │
│                                     │
└──────────────┬──────────────────────┘
               │ SSH + HTTP
               ▼
┌─────────────────────────────────────┐
│      Raspberry Pi 5                 │
│                                     │
│  n8n → Webhook → Dashboard          │
│  Docker Services                    │
└─────────────────────────────────────┘
```

---

## 📚 Documentation & Démo

### 🎯 Content à créer

#### Dashboard
- [ ] **Screenshot homepage**
- [ ] **GIF démo** (notification temps réel)
- [ ] **Vidéo tutoriel** (5 min)
  - Setup webhook n8n
  - Recevoir première notification
  - Utiliser filtres/actions

#### Admin Panel
- [ ] **Screenshot interface**
- [ ] **GIF démo** (exécution script)
- [ ] **Vidéo tutoriel** (7 min)
  - Configuration SSH
  - Lancer premier script
  - Gérer Docker

#### Blog posts
- [ ] "Monitoring n8n workflows avec Dashboard temps réel"
- [ ] "Gérer son Raspberry Pi avec GUI SSH"
- [ ] "Self-hosted vs Cloud : notre setup Pi5"

---

## 🏗️ Refactoring & Architecture

### v1.5.0 - Code Quality

**Priorité** : BASSE
**Estimation** : 3-4h

- [ ] **Tests unitaires**
  - Jest pour backend
  - API endpoints coverage 80%+

- [ ] **TypeScript migration**
  - server.js → server.ts
  - Type safety

- [ ] **Docker optimizations**
  - Multi-stage builds
  - Réduire image size

---

## 📊 Priorisation

| Feature | Dashboard | Admin Panel | Priority | Effort |
|---------|-----------|-------------|----------|--------|
| **Authentification** | v1.1.0 | - | 🔴 HIGH | 2-3h |
| **Multi-Pi** | - | v1.1.0 | 🔴 HIGH | 3-4h |
| **Redis persistance** | v1.2.0 | - | 🟡 MED | 3-4h |
| **Historique SQLite** | - | v1.2.0 | 🟡 MED | 4-5h |
| **Upload files** | - | v1.3.0 | 🟡 MED | 5-6h |
| **Notifications desktop** | v1.4.0 | - | 🟡 MED | 2-3h |
| **Unified interface** | v2.0.0 | v2.0.0 | 🔴 HIGH | 6-8h |
| **Analytics** | v1.3.0 | - | 🟢 LOW | 4-5h |
| **Métriques Pi** | - | v1.4.0 | 🟢 LOW | 4-5h |

---

## 🎯 Prochaine session

**Recommandation** : Commencer par v1.1.0 (authentification + multi-Pi)

**Ordre suggéré** :
1. Dashboard v1.1.0 (auth) → 2-3h
2. Admin Panel v1.1.0 (multi-pi) → 3-4h
3. Test intégration n8n webhook → 1h
4. Dashboard v1.2.0 (Redis) → 3-4h

**Total estimé** : ~12h développement

---

**Voulez-vous que je commence par une de ces features ?**

Options :
1. **Dashboard Auth** (sécuriser accès)
2. **Admin Panel Multi-Pi** (gérer plusieurs Pi)
3. **Intégrer webhook n8n** (tester bout-en-bout)
4. **Autre suggestion**
