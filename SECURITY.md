# 🔒 Security & Configuration Guide

## ⚠️ IMPORTANT: Before Using This Project

This repository is designed to be **safe for public sharing** while managing **sensitive infrastructure**.

### What is NOT committed to Git:

✅ **Protected (in `.gitignore`):**
- `config.js` - Your Pi SSH credentials
- `.env` - API keys, tokens, passwords
- `data/` - Runtime databases, logs
- Private keys, certificates

❌ **Never commit:**
- SSH passwords or private keys
- API tokens (Supabase, monitoring services)
- Admin credentials
- Personal IP addresses (beyond examples)
- Production secrets

---

## 🚀 Initial Setup (REQUIRED)

### 1. Configure Admin Panel

```bash
cd tools/admin-panel

# Copy example config
cp config.example.js config.js
cp .env.example .env
```

**Edit `config.js`:**
```javascript
module.exports = {
  pis: [{
    id: 'my-pi',
    name: 'My Raspberry Pi',
    hostname: 'raspberrypi.local',  // or IP
    username: 'pi',
    // Choose ONE method:
    privateKeyPath: '/path/to/.ssh/id_rsa',  // Recommended
    // OR
    password: 'your_password'  // Less secure
  }]
};
```

**Edit `.env`:**
```bash
# Supabase (if using database features)
SUPABASE_URL=http://your-pi.local:8001
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here

# Secrets Backend (optional)
SECRETS_BACKEND=keychain  # keychain, 1password, bitwarden, vault, pass
```

### 2. SSH Key Authentication (Recommended)

**Generate SSH key if you don't have one:**
```bash
ssh-keygen -t ed25519 -C "pi5-admin"
```

**Copy to your Pi:**
```bash
ssh-copy-id pi@raspberrypi.local
```

**Update `config.js`:**
```javascript
privateKeyPath: '~/.ssh/id_ed25519'
```

### 3. Secure Secrets with Keychain (macOS)

Instead of storing passwords in `config.js`, use macOS Keychain:

```bash
# Store SSH password
security add-generic-password \
  -a "pi" \
  -s "raspberrypi.local" \
  -w "your_password" \
  -T ""
```

Then in `config.js`:
```javascript
// Leave password undefined
// Secrets manager will fetch from Keychain
```

---

## 📂 File Security Checklist

### Before Every Commit:

```bash
# Check for sensitive data
git diff --cached | grep -iE "password|token|key|secret|192\.168\."

# Verify .gitignore works
git status --ignored
```

### Files That Should NEVER Be Committed:

- `config.js` ✅ (already in .gitignore)
- `.env` ✅ (already in .gitignore)
- `data/control-center.db` ✅ (ignored)
- `node_modules/` ✅ (ignored)
- Personal SSH keys
- API tokens in scripts (use `.env` instead)

### Example Files (SAFE to commit):

- `config.example.js` - Template with placeholders
- `.env.example` - Variable names only, no values
- `seed.sql` - Generic example data only
- Documentation with example IPs (192.168.1.x OK if generic)

---

## 🔐 Best Practices

### 1. Use Environment Variables

**BAD:**
```javascript
const apiKey = 'sk_live_abc123xyz';  // NEVER do this
```

**GOOD:**
```javascript
const apiKey = process.env.API_KEY;
require('dotenv').config();
```

### 2. Use SSH Keys (Not Passwords)

**Why:**
- More secure (4096-bit RSA > any password)
- No password in config files
- Can be easily revoked
- Works with automation

**Setup:**
```bash
# Generate key
ssh-keygen -t ed25519 -f ~/.ssh/pi5_admin

# Add to Pi
ssh-copy-id -i ~/.ssh/pi5_admin.pub pi@raspberrypi.local

# Configure
privateKeyPath: '~/.ssh/pi5_admin'
```

### 3. Secrets Manager

For production, use a secrets manager:

**Options:**
1. **macOS Keychain** (zero-config, local only)
2. **1Password** (team collaboration)
3. **Bitwarden/Vaultwarden** (self-hosted)
4. **HashiCorp Vault** (enterprise)

**Example:**
```javascript
const SecretsManager = require('./lib/secrets-manager');
const secrets = new SecretsManager('keychain');

const password = await secrets.getSSHPassword('pi5.local', 'pi');
```

### 4. Network Security

**Firewall Rules:**
```bash
# On your Pi
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 8001/tcp  # Supabase (local network only)
sudo ufw deny from any to any  # Default deny
```

**SSH Hardening:**
```bash
# /etc/ssh/sshd_config
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
```

---

## 🧪 Testing Security

### Scan for Leaked Secrets

```bash
# Check current repo
git log --all --full-history --source --pretty=format:'%H' -- .env config.js

# Search for patterns
git grep -i password
git grep -i token
git grep -i "192\.168\.1\."
```

### Audit Tools

```bash
# Install gitleaks (detects secrets in commits)
brew install gitleaks

# Scan repo
gitleaks detect --source . --verbose
```

### Pre-commit Hook

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Check for sensitive data before commit

if git diff --cached | grep -iE "password.*=|token.*=|192\.168\.1\.[0-9]{1,3}"; then
    echo "❌ BLOCKED: Potential secret detected!"
    echo "Review your changes and remove sensitive data"
    exit 1
fi
```

```bash
chmod +x .git/hooks/pre-commit
```

---

## 🚨 Emergency: Secret Leaked to GitHub

### If you accidentally commit a secret:

**1. Remove from history:**
```bash
# Install BFG Repo-Cleaner
brew install bfg

# Remove sensitive file
bfg --delete-files config.js

# Clean history
git reflog expire --expire=now --all
git gc --prune=now --aggressive

# Force push (⚠️ WARNING: rewrites history)
git push origin --force --all
```

**2. Rotate compromised secrets:**
- Change SSH password
- Regenerate API keys
- Revoke tokens
- Update `.env` and `config.js`

**3. GitHub reporting:**
- Go to repository settings
- Security → Secret scanning alerts
- Revoke exposed tokens

---

## 📚 Additional Resources

- [GitHub Security Best Practices](https://docs.github.com/en/code-security)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/hardening)

---

## ✅ Security Checklist

Before sharing this repo:

- [ ] `config.js` in .gitignore ✅
- [ ] `.env` in .gitignore ✅
- [ ] No hardcoded passwords in code ✅
- [ ] No real API tokens in examples ✅
- [ ] SSH keys stored outside repo ✅
- [ ] `config.example.js` uses placeholders ✅
- [ ] `.env.example` has no real values ✅
- [ ] Ran `git log` to verify no secrets ✅
- [ ] Firewall configured on Pi
- [ ] SSH password auth disabled

---

**Version:** 1.0.0
**Last Updated:** 2025-10-17
**Maintainer:** [@iamaketechnology](https://github.com/iamaketechnology)
