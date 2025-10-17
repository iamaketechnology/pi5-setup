# Secrets Management - PI5 Control Center

Gestion unifiée et sécurisée des credentials SSH et API keys pour l'administration multi-Pi.

---

## 🎯 Objectif

Séparer les **données sensibles** (passwords, keys) des **métadonnées publiques** (inventaire, monitoring) en utilisant un coffre-fort numérique au lieu de fichiers plaintext.

### ❌ Avant (Insécure)

```javascript
// config.js (commité dans Git!)
module.exports = {
  pis: [
    {
      name: 'pi5',
      host: 'pi5.local',
      username: 'pi',
      password: 'raspberry123'  // ⚠️ Plaintext!
    }
  ]
};
```

### ✅ Après (Sécurisé)

```javascript
// config.js (référence uniquement)
module.exports = {
  pis: [
    {
      id: 'uuid-from-supabase',  // Référence Supabase
      // Password récupéré depuis Keychain/1Password/Bitwarden/Vault
    }
  ]
};

// Récupération sécurisée
const password = await secretsManager.getSSHPassword('pi5.local', 'pi');
```

---

## 📦 Composants

### 1. Secrets Manager (`lib/secrets-manager.js`)

Module unifié supportant 5 backends:

| Backend | Type | Gratuit | Recommandé pour |
|---------|------|---------|-----------------|
| **macOS Keychain** | Natif | ✅ | Solo Mac |
| **1Password** | SaaS | ❌ | Équipes |
| **Bitwarden** | Open-source | ✅ | Self-hosted |
| **HashiCorp Vault** | Enterprise | ✅ | Infra complexe |
| **pass** | Unix CLI | ✅ | CLI purists |

**API simple:**
```javascript
const SecretsManager = require('./secrets-manager');
const secrets = new SecretsManager('keychain');

// SSH passwords
const password = await secrets.getSSHPassword('pi5.local', 'pi');

// API keys
const apiKey = await secrets.getAPIKey('supabase', 'service_role_key');

// Vault: Multiple secrets
const allSecrets = await secrets.getServiceSecrets('supabase');
```

### 2. Documentation

- **[DATA-SECURITY.md](../supabase/DATA-SECURITY.md)** (650 lignes)
  - Classification données sensibles vs publiques
  - Architecture hybride (local + Supabase)
  - Workflows sécurisés
  - Checklist sécurité

- **[SECRETS-SETUP.md](./SECRETS-SETUP.md)** (900 lignes)
  - Guide installation complet pour chaque backend
  - Configuration step-by-step
  - Exemples d'utilisation
  - Troubleshooting

---

## 🚀 Quick Start

### Option 1: macOS Keychain (5 minutes)

```bash
# 1. Stocker password SSH
security add-generic-password \
  -a "pi" \
  -s "pi5.local" \
  -w "votre_password" \
  -T ""

# 2. Configurer Control Center
cd tools/admin-panel
echo "SECRETS_BACKEND=keychain" >> .env

# 3. Tester
node -e "
const SecretsManager = require('./lib/secrets-manager');
const sm = new SecretsManager('keychain');
sm.getSSHPassword('pi5.local', 'pi').then(console.log);
"
```

### Option 2: 1Password (10 minutes)

```bash
# 1. Installer
brew install --cask 1password 1password-cli
op signin

# 2. Stocker credentials
op item create \
  --category=login \
  --title="Pi5 SSH" \
  --vault="Infrastructure" \
  username=pi \
  password="votre_password" \
  hostname=pi5.local

# 3. Configurer
echo "SECRETS_BACKEND=1password" >> tools/admin-panel/.env

# 4. Tester
op item get "Pi5 SSH" --fields password
```

### Option 3: Bitwarden (10 minutes)

```bash
# 1. Installer
brew install bitwarden-cli
bw login

# 2. Unlock
export BW_SESSION=$(bw unlock --raw)

# 3. Créer item
bw create item '{
  "type": 1,
  "name": "Pi5 SSH",
  "login": {
    "username": "pi",
    "password": "votre_password",
    "uris": [{"uri": "ssh://pi5.local"}]
  }
}'

# 4. Configurer
cat >> tools/admin-panel/.env <<EOF
SECRETS_BACKEND=bitwarden
BW_SESSION=$BW_SESSION
EOF
```

---

## 💡 Cas d'usage

### 1. Connexion SSH automatique

```javascript
// lib/pi-manager.js
const SecretsManager = require('./secrets-manager');
const secretsManager = new SecretsManager();

class PiManager {
  async connect(piId) {
    // Récupérer metadata depuis Supabase
    const pi = await supabaseClient.getPiById(piId);

    // Récupérer password depuis coffre-fort
    const password = await secretsManager.getSSHPassword(
      pi.hostname,  // pi5.local
      'pi'          // username
    );

    // Connexion SSH
    await this.ssh.connect({
      host: pi.hostname,
      username: 'pi',
      password: password
    });
  }
}
```

### 2. API Keys depuis environnement

```javascript
// server.js
const serviceRoleKey = await secretsManager.getAPIKey(
  'supabase',
  'service_role_key'
);

const supabase = createClient(
  process.env.SUPABASE_URL,
  serviceRoleKey  // Depuis coffre-fort, pas .env!
);
```

### 3. Rotation de secrets

```bash
#!/bin/bash
# scripts/rotate-pi-password.sh

NEW_PASSWORD=$(openssl rand -base64 32)

# Changer sur Pi
ssh pi@pi5.local "echo 'pi:$NEW_PASSWORD' | sudo chpasswd"

# Mettre à jour dans Keychain
security delete-generic-password -a "pi" -s "pi5.local" 2>/dev/null
security add-generic-password \
  -a "pi" \
  -s "pi5.local" \
  -w "$NEW_PASSWORD" \
  -T ""

echo "✅ Password rotated for pi5.local"
```

---

## 🔐 Sécurité

### Données JAMAIS stockées sur Supabase

- ❌ SSH passwords
- ❌ SSH private keys
- ❌ API keys privées
- ❌ Database credentials
- ❌ Tokens d'auth
- ❌ Certificats SSL privés

### Données safe sur Supabase

- ✅ Inventaire Pis (hostname, IP, model)
- ✅ Monitoring (CPU, RAM, disk usage)
- ✅ Historique installations
- ✅ Logs sanitisés (sans secrets)
- ✅ Configuration publique

### Architecture hybride

```
┌─────────────────────────────────────────────────────┐
│  Mac (Control Center)                                │
│                                                      │
│  ┌──────────────────┐    ┌────────────────────────┐│
│  │  Secrets Store   │    │  Supabase (Cloud)      ││
│  │  (Keychain/1P)   │    │                        ││
│  │                  │    │  ┌──────────────────┐  ││
│  │  • SSH passwords │    │  │ control_center   │  ││
│  │  • API keys      │    │  │                  │  ││
│  │  • Certificates  │    │  │ • pis (metadata) │  ││
│  └─────────┬────────┘    │  │ • system_stats   │  ││
│            │             │  │ • installations  │  ││
│            │             │  └──────────────────┘  ││
│            ▼             │                        ││
│  ┌──────────────────────┐└────────────────────────┘│
│  │  Pi Manager          │                          │
│  │  (Merge + Connect)   │                          │
│  └──────────┬───────────┘                          │
└─────────────┼──────────────────────────────────────┘
              │
              ▼
        SSH Connection
```

---

## 📊 Comparaison backends

| Critère | Keychain | 1Password | Bitwarden | Vault | pass |
|---------|----------|-----------|-----------|-------|------|
| **Setup** | 0 min | 10 min | 10 min | 30 min | 15 min |
| **Gratuit** | ✅ | ❌ | ✅ | ✅ | ✅ |
| **Équipe** | ❌ | ✅ | ✅ | ✅ | ⚠️  |
| **Self-hosted** | ✅ | ❌ | ✅ | ✅ | ✅ |
| **GUI** | Basic | Excellent | Good | Web UI | ❌ |
| **CLI** | Basic | Excellent | Good | Excellent | Excellent |
| **Sync** | iCloud | Cloud | Cloud/Self | Manual | Git |
| **Audit** | Basic | Excellent | Good | Excellent | Git log |
| **Rotation** | Manual | Manual | Manual | Auto | Manual |

---

## 🆘 Support

### Docs

- Installation: [SECRETS-SETUP.md](./SECRETS-SETUP.md)
- Architecture: [DATA-SECURITY.md](../supabase/DATA-SECURITY.md)
- Code: [lib/secrets-manager.js](../lib/secrets-manager.js)

### Troubleshooting

**Keychain: Item not found**
```bash
security dump-keychain | grep pi5.local
```

**1Password: Not signed in**
```bash
op signin
```

**Bitwarden: Session expired**
```bash
export BW_SESSION=$(bw unlock --raw)
```

**Vault: Connection refused**
```bash
vault status
export VAULT_ADDR='http://127.0.0.1:8200'
```

---

## 🎓 Best Practices

### 1. Préférer clés SSH aux passwords

```bash
# Générer clé dédiée
ssh-keygen -t ed25519 -C "pi5-control-center" -f ~/.ssh/id_rsa_pi

# Copier sur Pi
ssh-copy-id -i ~/.ssh/id_rsa_pi.pub pi@pi5.local

# Utiliser dans code
ssh.connect({
  host: 'pi5.local',
  username: 'pi',
  privateKey: fs.readFileSync('~/.ssh/id_rsa_pi', 'utf8')
});
```

### 2. Rotation régulière

- SSH keys: 1x/an
- API keys: 2x/an
- Passwords: 4x/an

### 3. Backup

- Keychain: Time Machine
- 1Password: Cloud (auto)
- Bitwarden: Export chiffré mensuel
- Vault: Snapshot weekly
- pass: Git push

### 4. Principe du moindre privilège

```bash
# Créer user spécifique pour Control Center
sudo adduser pi5-control --disabled-password
sudo usermod -aG docker pi5-control

# Utiliser ce user au lieu de 'pi'
security add-generic-password \
  -a "pi5-control" \
  -s "pi5.local" \
  -w "password"
```

---

**Version**: 1.0.0
**Auteur**: PI5-SETUP Project
**License**: MIT
