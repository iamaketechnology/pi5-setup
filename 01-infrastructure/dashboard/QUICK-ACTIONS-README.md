# 🚀 Quick Actions - Documentation

Dashboard n8n avec actions rapides, stats et health checks.

**Version:** 1.2.0
**Stack:** Node.js + Express + Socket.IO + Vanilla JS

---

## ✨ Nouvelles Fonctionnalités

### 1. **Trigger n8n Workflows** (1-click)
- Liste des workflows actifs
- Bouton play pour déclencher instantanément
- Notification en temps réel du déclenchement

### 2. **Dashboard Statistiques**
- Stats 24h (total, succès, erreurs)
- Taux de succès en pourcentage
- Auto-refresh toutes les 30s

### 3. **Health Checks Services**
- Vérification état n8n, Supabase, Docker
- Modal détaillé avec status codes
- Raccourci clavier: `Ctrl+H`

### 4. **Raccourcis Clavier**
- `Ctrl+H` : Ouvrir health check
- `Ctrl+R` : Rafraîchir données

---

## 📡 Nouvelles Routes API

### n8n Integration

#### `GET /api/n8n/workflows`
Liste tous les workflows n8n

**Response:**
```json
{
  "success": true,
  "workflows": [
    {
      "id": "workflow-123",
      "name": "Backup Supabase",
      "active": true
    }
  ]
}
```

#### `POST /api/n8n/workflows/:id/trigger`
Déclenche un workflow

**Body:**
```json
{
  "source": "dashboard",
  "data": {}
}
```

**Response:**
```json
{
  "success": true,
  "executionId": "exec-456",
  "message": "Workflow triggered"
}
```

#### `GET /api/n8n/executions?limit=10`
Historique des exécutions

**Response:**
```json
{
  "success": true,
  "executions": [
    {
      "id": "exec-456",
      "workflowId": "workflow-123",
      "finished": true,
      "status": "success"
    }
  ]
}
```

#### `GET /api/n8n/health`
Vérifie si n8n est accessible

**Response:**
```json
{
  "status": "healthy",
  "statusCode": 200
}
```

---

### Stats & Health

#### `GET /api/stats`
Stats dashboard complètes

**Response:**
```json
{
  "last24h": {
    "total": 42,
    "success": 38,
    "error": 3,
    "pending": 1,
    "successRate": "90.5%"
  },
  "workflows": {
    "Backup Supabase": {
      "total": 10,
      "success": 10,
      "error": 0
    }
  },
  "timeline": [
    {
      "date": "2025-01-19",
      "success": 15,
      "error": 1,
      "total": 16
    }
  ]
}
```

#### `GET /api/stats/timeline?days=7`
Timeline des notifications (charts)

#### `GET /api/health/services`
Health check tous les services

**Response:**
```json
{
  "services": {
    "n8n": {
      "name": "n8n",
      "url": "http://n8n:5678",
      "status": "healthy",
      "statusCode": 200
    },
    "supabase": {
      "name": "Supabase",
      "url": "http://kong:8000",
      "status": "healthy",
      "statusCode": 200
    }
  },
  "timestamp": "2025-01-19T20:30:00Z"
}
```

---

## 🔧 Configuration

### Variables d'environnement

Copier `.env.example` → `.env` :

```bash
cp .env.example .env
```

**Configurer n8n** :

```env
N8N_URL=http://n8n:5678
N8N_API_KEY=your_api_key_here
```

### Obtenir la clé API n8n

1. Ouvrir n8n → Settings → API
2. Créer une API key
3. Copier dans `.env`

**Note:** Si pas de clé API, le dashboard utilisera les webhooks (méthode alternative).

---

## 🚀 Déploiement

### Avec Docker Compose

```yaml
services:
  dashboard:
    image: node:22-alpine
    working_dir: /app
    volumes:
      - ./src:/app
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - N8N_URL=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
      - SUPABASE_URL=http://kong:8000
    command: sh -c "npm install && npm start"
    networks:
      - pi5-network
```

### Démarrer

```bash
cd 01-infrastructure/dashboard/compose
docker compose up -d
```

### Vérifier logs

```bash
docker logs pi5-dashboard -f
```

---

## 🎯 Utilisation

### Interface Web

**Accès:**
- Local: http://localhost:3000
- Réseau: http://192.168.1.74:3000
- Traefik: http://dashboard.pi5.local

### Widgets Quick Actions

**1. Stats Widget**
- Affiche stats 24h (total, succès, erreurs)
- Taux de succès en pourcentage
- Auto-refresh toutes les 30s

**2. Workflows Widget**
- Liste 5 workflows actifs
- Bouton play pour déclencher
- Badge actif/inactif

**3. Health Widget**
- Bouton "Vérifier l'état"
- Modal détaillé avec status de chaque service

---

## 🔗 Intégration avec n8n

### Méthode 1: API Key (recommandé)

**Avantages:**
- Trigger workflows via API
- Récupérer historique exécutions
- Lister tous les workflows

**Setup:**
1. Générer API key dans n8n
2. Ajouter dans `.env`
3. Restart dashboard

### Méthode 2: Webhooks (sans API key)

**Avantages:**
- Pas besoin de configuration
- Fonctionne immédiatement

**Limitations:**
- Pas d'historique
- Pas de liste workflows

Le dashboard détecte automatiquement la méthode disponible.

---

## 📊 Architecture

```
┌──────────────────┐
│  Frontend        │
│  (Vanilla JS)    │
│  - quick-actions.js
│  - Stats widgets│
│  - Health modals│
└────────┬─────────┘
         │ WebSocket + HTTP
         ▼
┌──────────────────┐
│  Backend         │
│  (Express)       │
│  - n8n-integration.js
│  - stats.js      │
└────────┬─────────┘
         │ HTTP Requests
         ▼
┌──────────────────┐     ┌──────────────────┐
│  n8n API         │     │  Supabase API    │
│  :5678/api/v1    │     │  :8000/health    │
└──────────────────┘     └──────────────────┘
```

---

## 🐛 Dépannage

### Workflows n'apparaissent pas

**Vérifier:**
```bash
# 1. n8n accessible ?
curl http://n8n:5678/healthz

# 2. API key configurée ?
docker exec pi5-dashboard cat /app/.env | grep N8N_API_KEY

# 3. Logs dashboard
docker logs pi5-dashboard | grep n8n
```

### Stats vides

**Normal si:**
- Aucune notification reçue dans les 24h
- Premier démarrage

**Tester:**
```bash
curl -X POST http://localhost:3000/api/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "workflow": "Test",
    "status": "success",
    "message": "Test notification"
  }'
```

### Health check échoue

**Vérifier réseau Docker:**
```bash
docker network inspect pi5-network
```

**Tester connectivité:**
```bash
docker exec pi5-dashboard wget -O- http://n8n:5678/healthz
```

---

## 📝 Exemples Use Cases

### 1. Déclencher backup manuel

1. Ouvrir dashboard
2. Section "Workflows n8n"
3. Trouver "Backup Supabase"
4. Cliquer ▶
5. Confirmer → Backup lancé

### 2. Surveiller taux de succès

1. Widget "Statistiques 24h"
2. Vérifier "Taux de succès"
3. Si < 90% → Vérifier erreurs

### 3. Vérifier services avant déploiement

1. Cliquer "Vérifier l'état"
2. Modal affiche status
3. Si ✅ tous healthy → Safe to deploy
4. Si ❌ unhealthy → Fix avant deploy

---

## 🔐 Sécurité

### API Key n8n

**Stocker de manière sécurisée:**
```bash
# Ne JAMAIS commit .env
echo ".env" >> .gitignore

# Utiliser secrets Docker (production)
docker secret create n8n_api_key /path/to/key
```

### Authentication Dashboard

**Activer dans `server/auth.js`:**
```javascript
const DASHBOARD_PASSWORD = process.env.DASHBOARD_PASSWORD;
```

Puis ajouter dans `.env`:
```env
DASHBOARD_PASSWORD=votre_mot_de_passe_fort
```

---

## 📚 Ressources

- [n8n API Documentation](https://docs.n8n.io/api/)
- [Socket.IO Documentation](https://socket.io/docs/)
- [Express.js Documentation](https://expressjs.com/)

---

## 🗺️ Roadmap

**v1.3.0 (à venir):**
- [ ] Charts timeline (Chart.js)
- [ ] Export stats CSV
- [ ] Slack/Discord notifications
- [ ] Workflow scheduler

**v1.4.0:**
- [ ] Multi-Pi support
- [ ] Docker container management
- [ ] Automated health checks (cron)

---

**Version:** 1.2.0
**Auteur:** PI5-SETUP Project
**Licence:** MIT
