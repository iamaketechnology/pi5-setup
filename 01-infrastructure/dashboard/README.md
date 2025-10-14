# 🚀 PI5 Dashboard - Real-time Workflow Monitoring

Dashboard web temps réel pour superviser vos workflows n8n hébergés sur Raspberry Pi 5.

**Stack**: Node.js 22 Alpine + Express + Socket.io + Vanilla JS

---

## 📋 Fonctionnalités

- ✅ **Notifications temps réel** via WebSocket
- ✅ **Interface responsive** accessible sur tout le réseau
- ✅ **Filtres** (tous/succès/erreurs/en attente)
- ✅ **Boutons actions** (approuver/rejeter workflows)
- ✅ **Historique** des 100 dernières notifications
- ✅ **Intégration Traefik** (dashboard.pi5.local)

---

## 🚀 Installation

### Prérequis

- Docker installé
- Réseau `traefik-public` existant (voir [01-infrastructure/traefik](../traefik))

### Déploiement one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/dashboard/scripts/01-dashboard-deploy.sh | sudo bash
```

### Déploiement manuel

```bash
cd 01-infrastructure/dashboard/scripts
sudo bash 01-dashboard-deploy.sh
```

---

## 🔗 Intégration n8n

### 1. Ajouter un nœud HTTP Request dans n8n

Dans votre workflow n8n, ajoutez un nœud **HTTP Request** :

**Configuration** :
- **Method**: POST
- **URL**: `http://192.168.1.74:3000/api/webhook` (remplacer par l'IP de votre Pi)
- **Body Content Type**: JSON
- **Body**:
```json
{
  "workflow": "{{ $workflow.name }}",
  "status": "success",
  "message": "Lead capturé: {{ $json.email }}",
  "executionId": "{{ $workflow.id }}",
  "requiresAction": false
}
```

### 2. Champs disponibles

| Champ | Type | Description | Exemple |
|-------|------|-------------|---------|
| `workflow` | string | Nom du workflow | "Capture Leads" |
| `status` | string | success/error/pending/info | "success" |
| `message` | string | Message descriptif | "Nouveau client ajouté" |
| `executionId` | string | ID d'exécution (optionnel) | "abc123" |
| `requiresAction` | boolean | Affiche boutons Approuver/Rejeter | true |

### 3. Exemples de notifications

**Succès simple** :
```json
{
  "workflow": "Import Contacts",
  "status": "success",
  "message": "25 contacts importés depuis Google Sheets"
}
```

**Erreur avec détails** :
```json
{
  "workflow": "Sync Supabase",
  "status": "error",
  "message": "Connexion à la base de données échouée",
  "executionId": "exec_456"
}
```

**Validation manuelle** :
```json
{
  "workflow": "Validation Facture",
  "status": "pending",
  "message": "Facture 2025-001 en attente de validation (1250€)",
  "requiresAction": true
}
```

---

## 🎯 Utilisation

### Accès à l'interface

| Type | URL |
|------|-----|
| **Local** | http://localhost:3000 |
| **Réseau** | http://192.168.1.74:3000 |
| **Traefik** | http://dashboard.pi5.local |

### Actions disponibles

1. **Filtrer notifications** : Cliquez sur Tous/Succès/Erreurs/En attente
2. **Approuver/Rejeter** : Cliquez sur les boutons d'action (si `requiresAction: true`)
3. **Effacer tout** : Bouton rouge en haut à droite

---

## 📡 API Endpoints

### POST `/api/webhook`
Recevoir une notification depuis n8n.

**Body** :
```json
{
  "workflow": "string",
  "status": "success|error|pending|info",
  "message": "string",
  "executionId": "string (optional)",
  "requiresAction": false
}
```

**Response** :
```json
{
  "success": true,
  "message": "Notification received",
  "id": 1736872800000
}
```

---

### GET `/api/notifications`
Récupérer toutes les notifications.

**Response** :
```json
{
  "total": 42,
  "data": [...]
}
```

---

### POST `/api/action/:notificationId`
Exécuter une action (approuver/rejeter).

**Body** :
```json
{
  "action": "approve",
  "data": {}
}
```

---

### DELETE `/api/notifications`
Effacer toutes les notifications.

---

### GET `/health`
Health check.

**Response** :
```json
{
  "status": "ok",
  "uptime": 3600,
  "timestamp": "2025-01-14T10:30:00Z"
}
```

---

## 🛠️ Maintenance

### Voir les logs
```bash
docker logs pi5-dashboard -f
```

### Redémarrer
```bash
docker restart pi5-dashboard
```

### Arrêter
```bash
docker stop pi5-dashboard
```

### Mettre à jour
```bash
cd ~/stacks/dashboard/compose
docker compose pull
docker compose up -d
```

---

## 🔧 Configuration Avancée

### Variables d'environnement

Éditez `compose/docker-compose.yml` :

```yaml
environment:
  - NODE_ENV=production
  - PORT=3000
  - LOG_LEVEL=info  # debug|info|warn|error
```

### Changer le port

```yaml
ports:
  - "8080:3000"  # Accès via :8080
```

### Persistance avec Redis (optionnel)

Par défaut, les notifications sont en mémoire (100 dernières). Pour persister avec Redis :

```yaml
services:
  redis:
    image: redis:7-alpine
    volumes:
      - redis-data:/data

  dashboard:
    environment:
      - REDIS_URL=redis://redis:6379

volumes:
  redis-data:
```

---

## 🎨 Personnalisation Interface

### Changer les couleurs

Éditez `src/public/css/style.css` :

```css
:root {
    --bg-primary: #0f172a;    /* Fond principal */
    --success: #10b981;       /* Couleur succès */
    --error: #ef4444;         /* Couleur erreur */
}
```

### Ajouter un logo

Éditez `src/public/index.html` :

```html
<h1>
    <img src="/logo.png" alt="Logo" style="height: 40px;">
    PI5 Dashboard
</h1>
```

---

## 🔐 Sécurité

### Authentification basique (recommandé)

Ajoutez au `docker-compose.yml` :

```yaml
environment:
  - AUTH_USER=admin
  - AUTH_PASSWORD=votre_mot_de_passe_fort
```

Puis modifiez `server/index.js` pour ajouter un middleware d'authentification.

### HTTPS avec Traefik

```yaml
labels:
  - "traefik.http.routers.dashboard.entrypoints=websecure"
  - "traefik.http.routers.dashboard.tls=true"
```

---

## 📊 Monitoring

### Statistiques conteneur

```bash
docker stats pi5-dashboard
```

### Vérifier santé

```bash
curl http://localhost:3000/health
```

---

## 🐛 Dépannage

| Problème | Solution |
|----------|----------|
| **Connexion refusée** | Vérifier que le conteneur est démarré: `docker ps` |
| **WebSocket ne se connecte pas** | Vérifier firewall: `sudo ufw allow 3000/tcp` |
| **Notifications n'arrivent pas** | Vérifier URL webhook n8n (IP correcte) |
| **Page blanche** | Voir logs: `docker logs pi5-dashboard` |

---

## 📚 Ressources

- [Documentation n8n](https://docs.n8n.io/)
- [Socket.io Documentation](https://socket.io/docs/)
- [Express.js Documentation](https://expressjs.com/)

---

## 🗺️ Architecture

```
┌─────────────────┐
│   Workflows n8n │
│   (Pi ou Cloud) │
└────────┬────────┘
         │ HTTP POST /api/webhook
         ▼
┌─────────────────────────┐
│  Dashboard Server       │
│  (Express + Socket.io)  │
└────────┬───────────────┘
         │ WebSocket push
         ▼
┌─────────────────────────┐
│  Client Web Browser     │
│  (Vanilla JS)           │
└─────────────────────────┘
```

---

## 📦 Structure Fichiers

```
01-infrastructure/dashboard/
├── README.md                        # Ce fichier
├── scripts/
│   └── 01-dashboard-deploy.sh       # Script de déploiement
├── compose/
│   └── docker-compose.yml           # Configuration Docker
└── src/
    ├── package.json                 # Dépendances Node.js
    ├── server/
    │   └── index.js                 # Serveur Express + Socket.io
    └── public/
        ├── index.html               # Interface utilisateur
        ├── css/style.css            # Styles
        └── js/app.js                # Client WebSocket
```

---

## 📝 Changelog

### Version 1.0.0 (2025-01-14)
- ✨ Release initiale
- ✅ Serveur Express + Socket.io
- ✅ Interface web responsive
- ✅ Filtres et actions
- ✅ Intégration Traefik

---

**Version**: 1.0.0
**Auteur**: PI5-SETUP Project
**Licence**: MIT
