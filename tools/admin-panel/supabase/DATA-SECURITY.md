# Data Security & Privacy - PI5 Control Center

## ✅ Données NON sensibles stockées sur Supabase

### Inventaire & Identité
- `name` - Nom du Pi (pi5, pi-office, pi-dev)
- `hostname` - Hostname réseau (pi5.local)
- `description` - Usage, emplacement physique
- `serial_number` - Numéro de série hardware
- `tags[]` - Classification (production, dev, test)
- `color` - Code couleur UI

### Hardware
- `model` - Modèle (Raspberry Pi 5)
- `ram_mb` - RAM en MB (8192)
- `storage_gb` - Stockage en GB (500)
- `cpu_cores` - Nombre de cœurs (4)
- `architecture` - Architecture (aarch64, arm64)

### Système d'exploitation
- `os_name` - Nom de l'OS (Raspberry Pi OS, Ubuntu)
- `os_version` - Version ('12 bookworm', '22.04 LTS')
- `kernel_version` - Version kernel ('6.1.21-v8+')

### Réseau (métadonnées publiques)
- `ip_address` - Adresse IP locale (192.168.1.x)
- `ssh_port` - Port SSH (22)
- `mac_address` - Adresse MAC
- `network_interface` - Interface réseau (eth0, wlan0)

### Monitoring & Métriques

#### État actuel
- `status` - État (active, offline, maintenance, error)
- `last_seen` - Dernier contact réussi
- `last_boot` - Dernier démarrage
- `uptime_seconds` - Temps de fonctionnement

#### CPU
- `cpu_usage_percent` - Utilisation CPU (0-100%)
- `cpu_temperature_celsius` - Température CPU (°C)
- `load_average_1m/5m/15m` - Charge système

#### Mémoire
- `memory_total_mb` - RAM totale
- `memory_used_mb` - RAM utilisée
- `memory_free_mb` - RAM libre
- `memory_usage_percent` - Utilisation RAM (%)
- `swap_total_mb/swap_used_mb` - Swap

#### Disque
- `disk_total_gb` - Stockage total
- `disk_used_gb` - Stockage utilisé
- `disk_free_gb` - Stockage libre
- `disk_usage_percent` - Utilisation (%)
- `disk_path` - Point de montage surveillé (/)

#### Réseau
- `network_rx_bytes/tx_bytes` - Bytes transférés
- `network_rx_mb_total/tx_mb_total` - Total en MB
- `network_rx_rate_mbps/tx_rate_mbps` - Débit instantané

#### Docker (si installé)
- `docker_version` - Version Docker
- `docker_containers_running` - Conteneurs actifs
- `docker_containers_total` - Total conteneurs
- `docker_images_count` - Nombre d'images
- `docker_volumes_count` - Nombre de volumes

#### Services
- `services_status` - État des services (JSONB)
  ```json
  {
    "docker": "running",
    "supabase": "running",
    "traefik": "stopped"
  }
  ```

### Historique (table `installations`)
- `stack_name` - Service installé (supabase, traefik)
- `version` - Version installée
- `status` - Résultat (success, failed)
- `output_summary` - Logs sanitisés (sans secrets!)
- `started_at/completed_at` - Horodatage
- `duration_seconds` - Durée

### Historique des métriques (table `system_stats`)
- Historique des métriques avec timestamp
- Rétention: 7 jours (auto-cleanup)
- Permet graphiques de performance

### Métadonnées flexibles (JSONB)
```json
{
  "location": "Bureau",
  "owner": "DevOps Team",
  "backup_schedule": "daily",
  "primary_use": "Development",
  "notes": "Main production server"
}
```

---

## ❌ Données SENSIBLES - JAMAIS stockées sur Supabase

### Credentials & Authentification
- ❌ **Mots de passe SSH** - Jamais en base!
- ❌ **Clés privées SSH** - Restent sur Mac uniquement (`~/.ssh/`)
- ❌ **Clés publiques SSH complètes** - Seulement fingerprint
- ❌ **Tokens d'authentification** - JWT, OAuth tokens
- ❌ **API keys privées** - Service role keys, secrets

### Configuration système
- ❌ **Contenu de .env** - Variables d'environnement sensibles
- ❌ **Database passwords** - Postgres, MySQL, etc.
- ❌ **Docker secrets** - Secrets Docker Swarm/Compose
- ❌ **Certificats SSL privés** - Clés TLS/SSL privées
- ❌ **Fichiers de config complets** - Peuvent contenir secrets

### Données applicatives
- ❌ **User passwords** - Applications hébergées
- ❌ **Session tokens** - Cookies, JWT
- ❌ **Encryption keys** - Clés de chiffrement

---

## 🔒 Architecture de sécurité

### Stockage des credentials (Mac local uniquement)

**config.js** (Local, jamais commit!)
```javascript
module.exports = {
  pis: [
    {
      id: 'uuid-from-supabase',  // Référence Supabase
      ssh: {
        host: 'pi5.local',
        username: 'pi',
        privateKeyPath: '~/.ssh/id_rsa_pi'  // ❌ Jamais upload!
      }
    }
  ]
};
```

**~/.ssh/config** (Standard Unix)
```
Host pi5
  HostName pi5.local
  User pi
  IdentityFile ~/.ssh/id_rsa_pi
  ServerAliveInterval 60
```

**macOS Keychain** (Optionnel, pour passwords)
```bash
# Stocker password dans Keychain
security add-generic-password \
  -a "pi" \
  -s "pi5.local" \
  -w "password"

# Récupérer depuis Keychain
security find-generic-password \
  -a "pi" \
  -s "pi5.local" \
  -w
```

### Workflow sécurisé

```
┌─────────────────────────────────────┐
│  Mac (Control Center)               │
│                                     │
│  ┌───────────────┐  ┌─────────────┐│
│  │ Supabase DB   │  │ config.js   ││
│  │ (Métadonnées) │  │ (SSH creds) ││
│  └───────┬───────┘  └──────┬──────┘│
│          │                  │       │
└──────────┼──────────────────┼───────┘
           │                  │
           ▼                  ▼
    ┌──────────────────────────────┐
    │  Pi Manager (Hybrid)         │
    │  - Load metadata from Supabase│
    │  - Load credentials from local│
    │  - Merge for SSH connection   │
    └──────────────────────────────┘
```

### Pi Manager - Approche hybride

```javascript
class PiManager {
  async getAllPis() {
    // 1. Récupérer métadonnées depuis Supabase
    const pisFromSupabase = await supabaseClient.getPis();

    // 2. Charger credentials depuis config.js local
    const localConfig = require('./config.js');

    // 3. Merger
    return pisFromSupabase.map(pi => ({
      ...pi,  // Métadonnées publiques (Supabase)
      ssh: localConfig.pis.find(c => c.id === pi.id)?.ssh  // Credentials (local)
    }));
  }

  async connect(piId) {
    const pi = await this.getPiById(piId);

    // SSH credentials viennent UNIQUEMENT du local
    const ssh = new NodeSSH();
    await ssh.connect({
      host: pi.hostname,  // Supabase
      username: pi.ssh.username,  // config.js local
      privateKey: fs.readFileSync(pi.ssh.privateKeyPath)  // ~/.ssh/
    });

    return ssh;
  }
}
```

---

## 🛡️ Bonnes pratiques

### 1. Séparation des données

| Type de donnée | Stockage | Backup | Partage |
|----------------|----------|--------|---------|
| Inventaire | Supabase | Auto | ✅ Équipe |
| Métriques | Supabase | Auto | ✅ Équipe |
| SSH Keys | ~/.ssh/ | Manual | ❌ Jamais |
| Passwords | Keychain | OS | ❌ Jamais |
| .env files | .gitignore | Manual | ❌ Jamais |

### 2. Git ignore
```.gitignore
# Config avec credentials
tools/admin-panel/config.js
tools/admin-panel/.env

# SSH keys
*.pem
*.key
id_rsa*

# Secrets
secrets/
*.secret
```

### 3. Rotation des secrets
- **Tokens de pairing**: One-time use, deleted après activation
- **SSH keys**: Rotation annuelle recommandée
- **Supabase service_role**: Rotation semestrielle
- **Database passwords**: Rotation trimestrielle

### 4. Accès Supabase

**Row Level Security (RLS)** activé:
```sql
-- Anon key: Read-only sur metadata
CREATE POLICY "anon_read_pis" ON control_center.pis
  FOR SELECT TO anon
  USING (status = 'active');

-- Service role: Full access (backend only)
GRANT ALL ON control_center.pis TO service_role;
```

### 5. Logs sanitisés

**Avant stockage dans `installations.output_summary`:**
```javascript
function sanitizeLogs(output) {
  return output
    .replace(/password[=:]\s*\S+/gi, 'password=***')
    .replace(/token[=:]\s*\S+/gi, 'token=***')
    .replace(/api[_-]?key[=:]\s*\S+/gi, 'api_key=***')
    .replace(/[A-Za-z0-9+/]{40,}/g, '***');  // Base64 secrets
}
```

---

## 📊 Cas d'usage

### Monitoring dashboard
```javascript
// ✅ Safe: Afficher métriques publiques
const pis = await supabase
  .from('pis')
  .select('name, cpu_usage_percent, memory_usage_percent, status')
  .eq('status', 'active');
```

### Installation script
```javascript
// ✅ Safe: Logger installation sans secrets
await supabase
  .from('installations')
  .insert({
    pi_id: piId,
    stack_name: 'supabase',
    output_summary: sanitizeLogs(output),  // ⚠️ Sanitize!
    status: 'success'
  });
```

### SSH Connection
```javascript
// ✅ Safe: Credentials depuis local uniquement
const pi = await supabase.from('pis').select('hostname').eq('id', piId).single();
const localCreds = config.pis.find(p => p.id === piId);

await ssh.connect({
  host: pi.data.hostname,  // Supabase (non sensible)
  privateKey: fs.readFileSync(localCreds.ssh.privateKeyPath)  // Local (sensible)
});
```

---

## ✅ Checklist sécurité

- [ ] config.js dans .gitignore
- [ ] SSH keys dans ~/.ssh/ (chmod 600)
- [ ] Passwords dans Keychain (pas plaintext)
- [ ] .env dans .gitignore (.env.example OK)
- [ ] Logs sanitisés avant insert
- [ ] RLS activé sur toutes les tables
- [ ] Service role key en ENV var (pas hardcodé)
- [ ] Anon key read-only (via policies)
- [ ] Backup SSH keys (coffre-fort offline)
- [ ] Rotation secrets planifiée

---

**Version**: 4.1.0
**Last Updated**: 2025-01-17
**Auteur**: PI5-SETUP Project
