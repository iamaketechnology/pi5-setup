# 🤖 Claude - Instructions Projet PI5-SETUP

---

## 📢 Communication

**Sois BREF** :
- Va droit au but
- Explique seulement si demandé ou concept complexe
- Tableaux > paragraphes

---

## 🎯 Projet

Installation automatisée serveur Pi 5 via curl one-liners.
Public : débutants. Tout doit être idempotent, pédagogique, production-ready.

---

## 🔧 Scripts - L'ESSENTIEL

### Structure Obligatoire

```bash
#!/bin/bash
# =============================================================================
# Nom du Script - Description courte
# =============================================================================
# Version: 1.0.0
# Last updated: 2025-01-14
# Author: PI5-SETUP Project
# Usage: sudo bash script.sh
# =============================================================================

set -euo pipefail  # OBLIGATOIRE

# Fonctions logging inline (standalone)
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Détection auto
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")

# Validation
if [[ $EUID -ne 0 ]]; then
    log_error "Lancer avec sudo"
    exit 1
fi

# Backup avant modif
backup() {
    local file=$1
    [[ -f "$file" ]] && cp "$file" "$file.bak.$(date +%Y%m%d_%H%M%S)"
}

# Idempotent : vérifier état avant action
if docker ps --format '{{.Names}}' | grep -q "^mon-service$"; then
    log_success "Service déjà installé"
    exit 0
fi

# Créer répertoires
mkdir -p "${USER_HOME}/stacks/mon-service"
cd "${USER_HOME}/stacks/mon-service"

# Action principale avec error handling
install_service() {
    docker compose up -d || {
        log_error "Échec installation"
        docker logs mon-service --tail 50
        exit 1
    }
}

install_service

# Vérifier démarrage
sleep 10
if ! docker ps --filter "name=mon-service" --filter "status=running" | grep -q "mon-service"; then
    log_error "Service non démarré"
    exit 1
fi

# Résumé final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SERVICE INSTALLÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "URL : http://localhost:8080"
echo "SSH tunnel : ssh -L 8080:localhost:8080 pi@pi5.local"
```

### Checklist Script

- [ ] Header version (Version, Last updated, Author, Usage)
- [ ] `set -euo pipefail` en haut
- [ ] Logging inline (`log_info`, `log_error`, `log_success`)
- [ ] Détection auto (user, home, interface)
- [ ] Check root (`if [[ $EUID -ne 0 ]]`)
- [ ] Idempotent (vérifier état avant action)
- [ ] Backup avant modif
- [ ] Error handling (`|| { error; exit 1; }`)
- [ ] Résumé final (URLs, credentials)
- [ ] Variables quotées (`"$VAR"`)
- [ ] **Vérifier existant Pi AVANT toute action**
- [ ] **Corriger script local pendant tests**
- [ ] **Testé sur Pi réel avant commit**
- [ ] **UN SEUL COMMIT quand 100% fonctionnel**
- [ ] **⚠️ ZÉRO INFO SENSIBLE hardcodée** (voir 🔒 Sécurité)

### Versioning Scripts

**Format** : `Version: X.Y.Z` ou `Version: X.Y.Z-description`

**Incrémentation** :
- **X.0.0** (major) : Breaking changes, incompatible avec version précédente
- **X.Y.0** (minor) : Nouvelle feature, compatible
- **X.Y.Z** (patch) : Bugfix, compatible

**Exemples** :
- `Version: 1.0.0` → Première version stable
- `Version: 1.0.1` → Bugfix (faux positif corrigé)
- `Version: 1.1.0` → Nouvelle feature (ajout auto-détection)
- `Version: 2.0.0` → Breaking change (changement structure)
- `Version: 3.49-security-hardening` → Feature avec description

---

## 🏗️ Architecture

Catégories numérotées :

```
01-infrastructure/  (Supabase, Traefik, Email, Apps)
02-securite/
03-monitoring/
04-developpement/
common-scripts/    (Scripts réutilisables)
```

Chaque stack :
```
<categorie>/<stack>/
├── README.md
├── scripts/01-<stack>-deploy.sh
├── compose/docker-compose.yml
└── config/
```

---

## 🛠️ Workflow Test & Debug

### Règle d'Or : Test-Driven Deployment

**AVANT toute installation** :
1. **Vérifier existant** : `ssh pi@pi5.local "docker ps; ls ~/stacks"`
2. **Analyser config** : Lire fichiers existants avant modification
3. **Identifier blockers** : Réseaux, permissions, dépendances

**PENDANT les tests** :
1. Éditer script local (Mac)
2. Copier sur Pi : `scp script.sh pi@pi5.local:/tmp/`
3. Tester : `ssh pi@pi5.local "sudo bash /tmp/script.sh"`
4. **Corriger en continu** : Fix script local immédiatement
5. Re-tester jusqu'à succès complet

**APRÈS validation** :
- **UN SEUL COMMIT** quand tout fonctionne
- Message commit détaillé (problèmes + solutions)
- Script doit être rejouable sans intervention

### Problèmes Courants Pi5

| Problème | Solution |
|----------|----------|
| **Permissions volumes Docker** | `chown -R 1000:1000` (user node/www-data) |
| **docker-compose introuvable** | Utiliser `docker compose` (V2 plugin) |
| **BASH_SOURCE undefined** | Mode standalone (pas de source lib.sh via stdin) |
| **version: '3.8' warning** | Supprimer ligne (Docker Compose V2) |
| **Réseau externe manquant** | Vérifier `docker network ls` avant usage |
| **Lib.sh introuvable** | Fonctions logging inline dans script |

### Scripts Standalone vs Sourced

**Standalone** (préféré pour déploiement) :
```bash
# Logging inline
log_info() { echo -e "\033[0;34m[INFO]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# Auto-détection user
CURRENT_USER="${SUDO_USER:-$(whoami)}"
USER_HOME=$(eval echo "~${CURRENT_USER}")
```

**Sourced** (pour scripts maintenance locaux) :
```bash
source "${PROJECT_ROOT}/common-scripts/lib.sh"
```

---

## 🔒 Sécurité - CRITIQUE

**⚠️ Ce projet est PUBLIC sur GitHub - ZÉRO secret hardcodé!**

### Fichiers Protégés (`.gitignore`)

✅ **Toujours ignorés** :
- `config.js` - Credentials SSH Pi
- `.env` - API tokens, passwords
- `data/` - Databases, logs
- Clés SSH privées

### Règles Absolues

**❌ JAMAIS commit** :
- Passwords hardcodés (`password: 'secret123'`)
- API tokens (`SUPABASE_KEY=eyJ...`)
- IPs personnelles (192.168.1.74 → exemple générique OK)
- Clés privées SSH
- Tokens admin (Vaultwarden, etc.)

**✅ Utiliser à la place** :
- Variables d'environnement (`.env`)
- Fichiers example (`.env.example`, `config.example.js`)
- Secrets managers (Keychain, 1Password, Bitwarden)
- SSH keys (pas de passwords)

### Pre-Commit Check

**Avant CHAQUE commit** :
```bash
# Scanner secrets
git diff --cached | grep -iE "password.*=|token.*=|192\.168\.[0-9]"

# Vérifier fichiers ignorés
git status --ignored
```

### Exemples

**❌ MAUVAIS** :
```javascript
const password = 'mySecretPassword123';
const token = 'sk_live_abc123';
ssh.connect({ host: '192.168.1.74', password: 'raspberry' });
```

**✅ BON** :
```javascript
const password = process.env.SSH_PASSWORD;
const token = process.env.API_TOKEN;
ssh.connect({ host: 'pi5.local', privateKeyPath: '~/.ssh/id_rsa' });
```

### Fichiers Example

Toujours utiliser **placeholders** :
```javascript
// config.example.js
module.exports = {
  pis: [{
    hostname: 'raspberrypi.local',  // ✅ Générique
    username: 'pi',
    password: 'YOUR_PASSWORD_HERE',  // ✅ Placeholder
    // privateKeyPath: '~/.ssh/id_rsa'  // ✅ Recommandé
  }]
};
```

**Plus d'infos** : Voir `SECURITY.md`

---

## ⚠️ Règles

**NE PAS** :
- Scripts non-idempotents
- Résumés verbeux
- Créer .md sans demande
- **Commits multiples pendant debug**
- **Installer sans vérifier existant**
- **WebSearch AVANT avoir vérifié Pi**
- **❌ SECRETS HARDCODÉS** (voir 🔒 Sécurité)

**FAIRE** :
- **Vérifier Pi d'abord** (`docker ps`, `ls stacks/`, `free -h`)
- Curl one-liners
- Idempotent
- Bref et direct
- **Corriger script local en continu**
- **UN SEUL COMMIT final**
- WebSearch SI besoin (bonnes pratiques)
- **✅ Variables d'environnement** (`.env`)

---

**Version** : 4.4
**Last Updated** : 2025-10-17
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
