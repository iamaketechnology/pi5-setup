# 🚀 PI5 Admin Panel

Interface web locale pour gérer vos déploiements Raspberry Pi 5 via SSH depuis votre Mac.

**⚠️ Outil local uniquement** : Ne jamais déployer sur le Pi (risque sécurité).

---

## 🎯 Fonctionnalités

- ✅ **Auto-découverte scripts** de déploiement du projet
- ✅ **Exécution SSH** avec logs temps réel (WebSocket)
- ✅ **Gestion Docker** : start/stop/restart/logs des conteneurs
- ✅ **Terminal intégré** pour suivre l'exécution
- ✅ **Confirmation avant exécution** (modal de sécurité)
- ✅ **Status SSH** en temps réel

---

## 🚀 Installation

### 1. Créer la configuration

```bash
cd tools/admin-panel
cp config.example.js config.js
```

### 2. Éditer `config.js`

```js
module.exports = {
  server: {
    port: 4000,
    host: 'localhost'
  },
  pi: {
    host: '192.168.1.118',  // Votre IP Pi
    username: 'pi',
    privateKey: require('fs').readFileSync(
      require('path').join(require('os').homedir(), '.ssh', 'id_rsa'),
      'utf8'
    )
  }
};
```

### 3. Installer les dépendances

```bash
npm install
```

---

## 🎮 Utilisation

### Lancer le serveur

```bash
npm run dev
```

Ouvrez http://localhost:4000

### Interface

```
┌─────────────────────────────────────────────────┐
│ 🚀 PI5 Admin Panel                              │
│ SSH Status: 🟢 Connected   Target: pi@pi5.local │
├─────────────────────────────────────────────────┤
│                                                 │
│  📜 Deployment Scripts      💻 Terminal         │
│  ┌──────────────────────┐  ┌─────────────────┐ │
│  │ 01-infrastructure    │  │ $ Executing...  │ │
│  │  🐳 Supabase  [▶️]   │  │ [INFO] Upload   │ │
│  │  🌐 Traefik   [▶️]   │  │ [INFO] Running  │ │
│  │  📊 Dashboard [▶️]   │  │ [SUCCESS] Done  │ │
│  │                      │  │                 │ │
│  │ 🐳 Docker Services   │  └─────────────────┘ │
│  │  supabase-db  🟢     │                      │
│  │   [🔄] [⏸️] [📋]     │                      │
│  └──────────────────────┘                      │
└─────────────────────────────────────────────────┘
```

---

## 📡 API Endpoints

### GET `/api/status`
Statut connexion SSH

**Response:**
```json
{
  "connected": true,
  "host": "192.168.1.118",
  "username": "pi"
}
```

---

### GET `/api/scripts`
Liste des scripts découverts

**Response:**
```json
{
  "scripts": [
    {
      "id": "base64_encoded",
      "name": "supabase deploy",
      "category": "01-infrastructure",
      "service": "supabase",
      "path": "01-infrastructure/supabase/scripts/01-supabase-deploy.sh"
    }
  ]
}
```

---

### POST `/api/execute`
Exécuter un script

**Body:**
```json
{
  "scriptPath": "01-infrastructure/dashboard/scripts/01-dashboard-deploy.sh"
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

### GET `/api/docker/containers`
Liste des conteneurs Docker

**Response:**
```json
{
  "containers": [
    {
      "Names": "supabase-db",
      "State": "running",
      "Status": "Up 2 hours"
    }
  ]
}
```

---

### POST `/api/docker/:action/:container`
Actions Docker (start/stop/restart)

**Example:**
```bash
POST /api/docker/restart/supabase-db
```

---

### GET `/api/docker/logs/:container?lines=100`
Logs d'un conteneur

---

## 🔧 Configuration avancée

### Changer le port

```js
// config.js
server: {
  port: 5000,  // Au lieu de 4000
  host: 'localhost'
}
```

### Utiliser hostname

```js
pi: {
  host: 'pi5.local',  // Au lieu de l'IP
  username: 'pi'
}
```

### Authentification par mot de passe

```js
pi: {
  host: '192.168.1.118',
  username: 'pi',
  password: 'your_password'  // Au lieu de privateKey
}
```

---

## 🔐 Sécurité

### ⚠️ IMPORTANT

- ✅ **Local uniquement** : Jamais exposer publiquement
- ✅ **config.js gitignored** : Credentials non versionnés
- ✅ **SSH keys** : Préférer clés SSH au password
- ✅ **Confirmation modale** : Double-check avant exec
- ✅ **Logs audit** : Toutes les actions loggées

### Bonnes pratiques

1. **Ne pas commit config.js** (déjà dans .gitignore)
2. **Utiliser clés SSH** avec passphrase
3. **Limiter sudo** sur le Pi (scripts doivent demander sudo explicitement)
4. **Fermer l'app** quand non utilisée

---

## 🐛 Dépannage

| Problème | Solution |
|----------|----------|
| **SSH connection failed** | Vérifier IP, username, clé SSH |
| **ECONNREFUSED** | Pi éteint ou firewall |
| **Permission denied** | Vérifier `~/.ssh/id_rsa` permissions (600) |
| **Scripts not found** | Vérifier `paths.projectRoot` dans config.js |
| **Port 4000 in use** | Changer `server.port` dans config.js |

### Tester connexion SSH manuellement

```bash
ssh -i ~/.ssh/id_rsa pi@192.168.1.118
```

Si ça marche pas, l'admin panel ne marchera pas non plus.

---

## 📦 Structure

```
tools/admin-panel/
├── package.json              # Dépendances
├── server.js                 # Backend Express + SSH
├── config.js                 # Configuration (gitignored)
├── config.example.js         # Template config
├── .gitignore                # Ignore node_modules + config.js
├── README.md                 # Ce fichier
└── public/
    ├── index.html            # Interface
    ├── css/style.css         # Styles terminal
    └── js/app.js             # Client WebSocket
```

---

## 🎨 Personnalisation

### Ajouter pattern de scripts

```js
// config.js
scripts: {
  patterns: [
    '01-infrastructure/*/scripts/*-deploy.sh',
    'custom-folder/*/deploy.sh'  // Ajouter
  ]
}
```

### Changer couleurs

```css
/* public/css/style.css */
:root {
  --bg-primary: #0f172a;    /* Fond principal */
  --success: #10b981;       /* Couleur succès */
  --info: #3b82f6;          /* Couleur info */
}
```

---

## 🔄 Workflow typique

1. **Lancer** : `npm run dev`
2. **Vérifier** : Status SSH 🟢
3. **Sélectionner** : Cliquer sur un script
4. **Confirmer** : Modal de confirmation
5. **Observer** : Logs temps réel dans terminal
6. **Gérer Docker** : Restart services si besoin
7. **Logs Docker** : Cliquer 📋 pour voir logs conteneur

---

## 🚀 Prochaines améliorations possibles

- [ ] Authentification local (login/password)
- [ ] Multi-Pi support (switcher entre plusieurs Pi)
- [ ] Historique exécutions (base SQLite)
- [ ] Favoris scripts
- [ ] Notifications desktop (Electron)
- [ ] Export logs en fichier

---

## 📚 Stack technique

| Composant | Version | Rôle |
|-----------|---------|------|
| **Node.js** | >=18 | Runtime |
| **Express** | 4.21 | HTTP server |
| **Socket.io** | 4.8 | WebSocket (logs temps réel) |
| **node-ssh** | 13.2 | Client SSH |
| **Glob** | - | Découverte scripts |

---

**Version**: 1.0.0
**Auteur**: PI5-SETUP Project
**Licence**: MIT
