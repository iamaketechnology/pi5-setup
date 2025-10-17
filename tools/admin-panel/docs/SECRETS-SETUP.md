# Guide de configuration - Secrets Manager

Guide complet pour configurer le stockage sécurisé de vos credentials SSH et API keys.

---

## 🔐 Options disponibles

| Backend | Gratuit | Self-hosted | Équipe | Complexité | Recommandé pour |
|---------|---------|-------------|--------|------------|-----------------|
| **macOS Keychain** | ✅ | ✅ | ❌ | 🟢 Simple | Solo Mac |
| **1Password** | ❌ | ❌ | ✅ | 🟢 Simple | Équipes 2-20 |
| **Bitwarden** | ✅ | ✅ | ✅ | 🟡 Moyen | Open-source fans |
| **HashiCorp Vault** | ✅ | ✅ | ✅ | 🔴 Complexe | Enterprise |
| **pass** | ✅ | ✅ | ⚠️  | 🟡 Moyen | Unix purists |

---

## 1️⃣ macOS Keychain (Recommandé pour démarrer)

### Installation

Déjà installé sur macOS! Aucune configuration nécessaire.

### Configuration initiale

```bash
# Stocker password SSH pour pi5
security add-generic-password \
  -a "pi" \
  -s "pi5.local" \
  -w "votre_password_ssh" \
  -T ""

# Stocker Supabase service role key
security add-generic-password \
  -a "supabase" \
  -s "service_role_key" \
  -w "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -T ""

# Tester récupération
security find-generic-password -a "pi" -s "pi5.local" -w
```

### Configuration PI5 Control Center

```bash
# .env
SECRETS_BACKEND=keychain
```

```javascript
// config.js
module.exports = {
  pis: [
    {
      id: 'uuid-from-supabase',
      // SSH credentials stored in Keychain
      // Access via: secretsManager.getSSHPassword('pi5.local', 'pi')
    }
  ]
};
```

### Avantages

- ✅ Déjà installé (macOS natif)
- ✅ Chiffrement FileVault
- ✅ Backup avec Time Machine
- ✅ Sync iCloud Keychain (optionnel)
- ✅ Touch ID support
- ✅ Aucun service externe

### Limitations

- ❌ Mac uniquement
- ❌ Pas de partage d'équipe
- ❌ Interface limitée

---

## 2️⃣ 1Password (Recommandé pour équipes)

### Installation

```bash
# Installer 1Password app + CLI
brew install --cask 1password
brew install --cask 1password-cli

# Connecter CLI
op signin
```

### Configuration initiale

```bash
# Créer vault "Infrastructure"
# Via 1Password app: New Vault → Infrastructure

# Ajouter Pi SSH credentials
op item create \
  --category=login \
  --title="Pi5 SSH" \
  --vault="Infrastructure" \
  username=pi \
  password="votre_password" \
  hostname=pi5.local

# Ajouter Supabase keys
op item create \
  --category=api-credential \
  --title="Supabase Service Role" \
  --vault="Infrastructure" \
  credential="eyJhbGciOiJI..."

# Tester
op item get "Pi5 SSH" --fields password
```

### Configuration PI5 Control Center

```bash
# .env
SECRETS_BACKEND=1password
```

### Partage en équipe

```bash
# Inviter membre d'équipe
# 1Password app → Settings → People → Invite

# Partager vault Infrastructure
# Vaults → Infrastructure → Share → Select members
```

### Avantages

- ✅ UX excellente (app + CLI + browser)
- ✅ Partage équipe facile
- ✅ Vaults organisés par projet
- ✅ Audit logs complets
- ✅ 2FA intégré
- ✅ Support multi-plateformes

### Limitations

- ❌ Payant ($2.99/mois solo, $19.95/mois famille)
- ❌ Service externe (pas self-hosted)

---

## 3️⃣ Bitwarden (Open-source)

### Installation

```bash
# Installer CLI
brew install bitwarden-cli

# Login
bw login your-email@example.com

# Unlock et sauvegarder session
export BW_SESSION=$(bw unlock --raw)

# Ajouter à .zshrc/.bashrc pour persistance
echo 'export BW_SESSION="your-session-key"' >> ~/.zshrc
```

### Configuration initiale

```bash
# Créer dossier Infrastructure
bw create folder '{
  "name": "Infrastructure"
}'

# Ajouter Pi SSH
bw create item '{
  "type": 1,
  "name": "Pi5 SSH",
  "login": {
    "username": "pi",
    "password": "votre_password",
    "uris": [{"uri": "ssh://pi5.local"}]
  }
}'

# Tester
bw get password "Pi5 SSH"
```

### Configuration PI5 Control Center

```bash
# .env
SECRETS_BACKEND=bitwarden
BW_SESSION=your-session-key-from-unlock
```

### Self-hosted (optionnel)

```bash
# Installer Vaultwarden (Bitwarden compatible)
docker run -d \
  --name vaultwarden \
  -p 8080:80 \
  -v vw-data:/data \
  vaultwarden/server:latest

# Configurer CLI pour instance custom
bw config server https://your-domain.com
```

### Avantages

- ✅ Open-source (auditable)
- ✅ Gratuit pour solo
- ✅ Self-hosted possible (Vaultwarden)
- ✅ CLI complet
- ✅ Multi-plateformes

### Limitations

- ❌ Partage équipe payant ($10/mois/org)
- ❌ Interface CLI moins intuitive que 1Password

---

## 4️⃣ HashiCorp Vault (Enterprise)

### Installation

```bash
# Installer Vault
brew install vault

# Démarrer serveur dev (local testing)
vault server -dev

# Dans nouveau terminal, configurer env
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='dev-token-from-server-output'
```

### Production setup

```bash
# Vault config file
cat > vault-config.hcl <<EOF
storage "file" {
  path = "/opt/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

ui = true
EOF

# Start production server
vault server -config=vault-config.hcl

# Initialize (première fois uniquement)
vault operator init

# Unseal (après chaque restart)
vault operator unseal <unseal-key-1>
vault operator unseal <unseal-key-2>
vault operator unseal <unseal-key-3>
```

### Configuration initiale

```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Stocker Pi credentials
vault kv put secret/pi/pi5 \
  username=pi \
  password=votre_password \
  hostname=pi5.local \
  port=22

# Stocker Supabase
vault kv put secret/supabase \
  service_role_key=eyJhbGc... \
  anon_key=eyJhbGc... \
  url=http://pi5.local:8001

# Lire
vault kv get secret/pi/pi5
vault kv get -field=password secret/pi/pi5
```

### Configuration PI5 Control Center

```bash
# .env
SECRETS_BACKEND=vault
VAULT_ADDR=http://127.0.0.1:8200
VAULT_TOKEN=your-root-token
```

### Avantages

- ✅ Enterprise-grade security
- ✅ Dynamic secrets (auto-rotation)
- ✅ Audit logs détaillés
- ✅ API complète
- ✅ Multi-cloud support
- ✅ Namespaces/policies avancés

### Limitations

- ❌ Complexe à configurer
- ❌ Requires ops knowledge
- ❌ Overkill pour petites équipes

---

## 5️⃣ pass (Unix password store)

### Installation

```bash
# Installer pass et GPG
brew install pass gnupg

# Générer GPG key (si pas déjà fait)
gpg --full-generate-key
# Choix: RSA, 4096 bits, expire 2 ans

# Lister keys
gpg --list-secret-keys --keyid-format LONG
# Note ton Key ID: rsa4096/ABCD1234...

# Initialiser pass avec key ID
pass init ABCD1234
```

### Configuration initiale

```bash
# Stocker Pi password
pass insert pi5.local/ssh
# Enter password: ****

# Stocker Supabase (multi-line)
pass insert -m supabase/service_role_key
# Paste key, puis Ctrl+D

# Lire
pass pi5.local/ssh

# Copier dans clipboard (auto-clear après 45s)
pass -c pi5.local/ssh
```

### Git sync (optionnel)

```bash
# Initialiser repo git
pass git init

# Ajouter remote
pass git remote add origin git@github.com:you/password-store.git

# Push
pass git push -u origin master

# Sur autre machine
git clone git@github.com:you/password-store.git ~/.password-store
```

### Configuration PI5 Control Center

```bash
# .env
SECRETS_BACKEND=pass
```

### Avantages

- ✅ Simple et Unix-friendly
- ✅ Chiffré GPG (standard)
- ✅ Git-based sync
- ✅ Open-source
- ✅ Extensions: browser, mobile

### Limitations

- ❌ CLI uniquement (pas de GUI native)
- ❌ Nécessite connaissance GPG
- ❌ Partage équipe = partage GPG keys (complexe)

---

## 🚀 Utilisation dans PI5 Control Center

### Exemple de connexion SSH

```javascript
// lib/pi-manager.js
const SecretsManager = require('./secrets-manager');
const secretsManager = new SecretsManager(); // Auto-detect depuis SECRETS_BACKEND

async connect(piId) {
  const pi = await supabaseClient.getPiById(piId);

  // Récupérer password depuis backend configuré
  const password = await secretsManager.getSSHPassword(
    pi.hostname,  // 'pi5.local'
    'pi'          // username
  );

  const ssh = new NodeSSH();
  await ssh.connect({
    host: pi.hostname,
    username: 'pi',
    password: password  // Depuis Keychain/1Password/Bitwarden/Vault/pass
  });

  return ssh;
}
```

### Exemple avec clés SSH (recommandé)

```javascript
// Si tu utilises clés SSH au lieu de passwords
const fs = require('fs');
const os = require('os');

async connect(piId) {
  const pi = await supabaseClient.getPiById(piId);

  // Private key path depuis config.js local
  const privateKeyPath = `${os.homedir()}/.ssh/id_rsa_pi`;

  await ssh.connect({
    host: pi.hostname,
    username: 'pi',
    privateKey: fs.readFileSync(privateKeyPath, 'utf8')
  });

  return ssh;
}
```

### Récupérer API keys

```javascript
// Get Supabase service role key
const serviceRoleKey = await secretsManager.getAPIKey(
  'supabase',           // service name
  'service_role_key'    // key name
);

// Initialize Supabase avec key depuis secrets
const supabase = createClient(
  process.env.SUPABASE_URL,
  serviceRoleKey
);
```

---

## 🔒 Bonnes pratiques de sécurité

### 1. Utiliser clés SSH plutôt que passwords

```bash
# Générer clé SSH
ssh-keygen -t ed25519 -C "pi5-control-center" -f ~/.ssh/id_rsa_pi

# Copier sur Pi
ssh-copy-id -i ~/.ssh/id_rsa_pi.pub pi@pi5.local

# Permissions correctes
chmod 600 ~/.ssh/id_rsa_pi
chmod 644 ~/.ssh/id_rsa_pi.pub
```

### 2. Rotation régulière

```bash
# SSH keys: Rotation annuelle
# API keys: Rotation semestrielle
# Passwords: Rotation trimestrielle

# Script de rotation
#!/bin/bash
# rotate-secrets.sh

echo "🔄 Rotating Pi5 SSH password..."
NEW_PASSWORD=$(openssl rand -base64 32)
ssh pi@pi5.local "echo 'pi:$NEW_PASSWORD' | sudo chpasswd"
pass insert -e pi5.local/ssh <<< "$NEW_PASSWORD"
echo "✅ Pi5 password rotated"
```

### 3. Backup des secrets

```bash
# Keychain: Time Machine backup
# 1Password: Cloud backup (auto)
# Bitwarden: Export periodique
bw export --format json --output backup.json
gpg --encrypt --recipient you@email.com backup.json
rm backup.json

# pass: Git push
pass git push

# Vault: Backup Raft storage
vault operator raft snapshot save backup.snap
```

### 4. Audit & monitoring

```bash
# Vault audit logs
vault audit enable file file_path=/var/log/vault_audit.log

# 1Password activity logs
# Via app: Settings → Activity

# macOS Keychain logs
log show --predicate 'process == "security"' --last 1h
```

---

## 🆘 Dépannage

### Keychain: "The specified item could not be found"

```bash
# Lister tous les passwords
security dump-keychain

# Recréer entry
security delete-generic-password -a "pi" -s "pi5.local" 2>/dev/null
security add-generic-password -a "pi" -s "pi5.local" -w "password" -T ""
```

### 1Password: "op: command not found"

```bash
# Vérifier installation
which op

# Réinstaller si besoin
brew reinstall --cask 1password-cli

# S'assurer d'être connecté
op signin
```

### Bitwarden: "Session key required"

```bash
# Unlock et exporter session
export BW_SESSION=$(bw unlock --raw)

# Vérifier
echo $BW_SESSION

# Ajouter à shell config
echo "export BW_SESSION='$BW_SESSION'" >> ~/.zshrc
```

### Vault: "connection refused"

```bash
# Vérifier server status
vault status

# Vérifier VAULT_ADDR
echo $VAULT_ADDR

# Démarrer server si down
vault server -dev
```

---

## 📊 Comparaison de performance

| Backend | Latence read | Latence write | Offline | Sync |
|---------|-------------|---------------|---------|------|
| Keychain | <1ms | <5ms | ✅ | iCloud |
| 1Password | ~50ms | ~100ms | ✅ (cache) | Cloud |
| Bitwarden | ~80ms | ~150ms | ✅ (cache) | Cloud/Self |
| Vault | ~10ms (local) | ~20ms (local) | ❌ | Manual |
| pass | <1ms | ~50ms (git) | ✅ | Git |

---

**Version**: 1.0.0
**Last Updated**: 2025-01-17
**Auteur**: PI5-SETUP Project
