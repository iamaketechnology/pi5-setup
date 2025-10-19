📋 Système de Détection des Pi - Vue Complète
🎯 Architecture Générale
L'application utilise une approche à deux niveaux :
Niveau	Source	Priorité	Type
Primaire	config.js	🥇 Première	Statique (manuel)
Secondaire	Supabase DB	🥈 Fallback	Dynamique (auto)
1️⃣ À L'ALLUMAGE DE L'APP
server.js:111
    ↓
piManager.initPiManager(config)
    ├─ Supabase activé?
    │  ├─ OUI → Charger depuis control_center.pis (Supabase)
    │  └─ NON → Continuer
    └─ Sinon → Utiliser config.pis array
    ↓
    Set currentPiId = default ou premier actif
    ↓
    Cache rafraîchi (TTL: 30s)
Fichiers clés :
pi-manager.js:15-45 - Initialisation
server.js:111 - Point d'entrée
supabase-client.js - Requêtes DB
2️⃣ DÉTECTION D'UN PI NEUF (Freshly Deployed)
Étape 1️⃣ : Registration (Bootstrap Script)
Le Pi fraîchement déployé exécute :
curl -fsSL http://localhost:4000/bootstrap | sudo bash
Le Pi POST automatiquement à /api/bootstrap/register avec :
token (clé d'appairage unique)
hostname (ex: raspberrypi.local)
ip_address (détectée auto)
mac_address (détectée auto)
metadata (infos Pi)
Code : bootstrap.routes.js
// Pi status: 'pending' ← Marqueur de "fraîchement déployé"
// tags: ['bootstrap', 'pending-pairing']
Étape 2️⃣ : Pairing (Appairage Manuel)
L'admin entre le token dans l'UI :
Control Center UI
    ↓
Modal "Ajouter un Pi"
    ↓
Entrer token → POST /api/pis/pair
    ↓
Test SSH connection
    ↓
Si OK : status 'pending' → 'active'
Code : pi.routes.js + pi-manager.js:197-251
3️⃣ MARQUEURS DE PI "FRAÎCHEMENT DÉPLOYÉ"
{
  id: 'pi-xyz',
  hostname: 'raspberrypi.local',
  ip_address: '192.168.1.50',
  status: 'pending',           // ← KEY: Fraîchement déployé
  tags: ['bootstrap', 'pending-pairing'],  // ← Markers
  token: 'unique-pairing-token-abc123',    // ← Pour appairage
  last_seen: '2025-10-19T08:20:00Z'
}
Cycle de vie :
New Pi Registration
    ↓
status: 'pending'  ← DÉTECTABLE
    ↓
token assigned
    ↓
User pairs
    ↓
SSH test OK
    ↓
status: 'active'   ← Complètement intégré
4️⃣ CE QUI EST DÉTECTÉ AUTOMATIQUEMENT
Une fois le Pi connecté, l'app récupère :
Information	Source	Fichier
Services Docker	docker ps	services-info.js
Interfaces réseau	ip -j addr show	network-manager.js
Setup Status	Divers checks	setup.routes.js
System Stats	/proc, sensors	SQLite stats_history
Traefik URLs	Container labels	services-info.js
Exemple - Setup Status Check :
{
  docker: true,           // docker --version
  network: true,          // Static IP configured
  security: false,        // ufw status
  traefik: true,          // Docker container running
  monitoring: false       // Prometheus/Grafana
}
5️⃣ FRONTEND - DÉTECTION AU CHARGEMENT
main.js:113
    ↓
DOMContentLoaded
    ↓
loadServerConfig()  ← Config serveur
    ↓
initModules()
    ↓
PiSelectorManager.loadPis()
    ↓
GET /api/pis  ← Fetch tous les Pis
    ↓
Render <select> dropdown
    ├─ [OK] pour actifs
    └─ [OFF] pour inactifs
Code : pi-selector.js:19-72 UI Affiche :
┌─────────────────────────────┐
│ Pi5 [OK] - Default          │ ← Statut live
├─────────────────────────────┤
│ NewPi [PENDING] - Bootstrap │ ← Pi fraîchement déployé
└─────────────────────────────┘
6️⃣ INTÉGRATION CONFIG vs DATABASE
Mode Config Statique (par défaut) :
// config.js
pis: [
  {
    id: 'pi-prod',
    host: 'pi5.local',        // mDNS (pas d'IP hardcodée)
    username: 'pi',
    privateKey: fs.readFileSync('~/.ssh/id_rsa'),
    tags: ['production']
  }
]
Mode Supabase Dynamique (si SUPABASE_URL configurée) :
-- control_center.pis table
SELECT * FROM pis WHERE status = 'active';

-- Cache TTL: 30 secondes
-- Refresh: refreshPisCache() automatique
Fallback Logic :
if (Supabase enabled && connected) {
  Load from DB
} else {
  Use config.pis (fallback)
}
7️⃣ DETECTION À DIFFÉRENTES ÉCHELLES
Cas	Détection
1 Pi	Config statique config.pis[0] → SSH test au démarrage
N Pis (Config)	Tous définis dans config.pis → Dropdown pour switch
N Pis (Supabase)	DB queries → Cache 30s → Refresh auto
Pi Neuf Bootstrap	POST /api/bootstrap/register → status: 'pending'
8️⃣ FLOW COMPLET : PI FRAÎCHEMENT DÉPLOYÉ
┌─────────────────────────────────────────────────────────┐
│ 1. New Pi boots up (fresh install)                     │
│    ↓                                                    │
│ 2. Runs bootstrap script (registers itself)            │
│    POST /api/bootstrap/register                        │
│    ↓ [bootstrap.routes.js:25-65]                       │
│ 3. Control Center creates DB entry                    │
│    status: 'pending'                                  │
│    tags: ['bootstrap', 'pending-pairing']             │
│    ↓                                                    │
│ 4. Frontend UI reloads Pi selector                     │
│    Shows: "NewPi [PENDING]"                           │
│    ↓                                                    │
│ 5. Admin enters pairing token in modal                 │
│    ↓ [pi.routes.js - POST /api/pis/pair]              │
│ 6. System tests SSH connection                         │
│    ↓ [pi-manager.js:197-251]                           │
│ 7. If OK: status 'pending' → 'active'                 │
│    token cleared (one-time use)                       │
│    ↓                                                    │
│ 8. UI updates: "NewPi [OK]"                           │
│    Auto-discovers services, network, stats            │
│    ↓                                                    │
│ 9. Setup Wizard appears (checklist)                   │
│    Guides through infrastructure setup                │
└─────────────────────────────────────────────────────────┘
9️⃣ KEY INSIGHTS
Point	Détail
mDNS, pas d'IPs	Utilise pi5.local pour flexibilité
SSH-First	Toute découverte passe par SSH
Hybrid Mode	Config + Supabase = robustesse
30s Cache	Réduit requêtes DB
Marqueurs Clairs	status: 'pending' = Pi neuf détectable
Bootstrap Auto	Pi s'enregistre automatiquement
Pairing Token	One-time security token pour appairage
Graceful Degradation	Fonctionne offline avec config.js
🔗 Fichiers Clés
lib/
├── pi-manager.js           ← Core discovery engine
├── supabase-client.js      ← DB queries
├── services-info.js        ← Docker detection
└── network-manager.js      ← Network detection

routes/
├── bootstrap.routes.js     ← New Pi registration
├── pi.routes.js            ← Pi pairing & listing
└── setup.routes.js         ← Setup status checks

public/js/modules/
├── pi-selector.js          ← Frontend dropdown
├── setup-wizard.js         ← Installation guide
└── installation-assistant.js ← Smart setup helper