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
set -euo pipefail  # OBLIGATOIRE

# Fonctions logging (copier de common-scripts/lib.sh)
log_info()   { echo -e "[INFO] $*"; }
log_error()  { echo -e "[ERROR] $*"; }
ok()         { echo -e "✅ $*"; }

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
if docker ps | grep -q "mon-service"; then
    ok "Service déjà installé"
    exit 0
fi

# Action principale avec error handling
install_service() {
    docker run -d \
        --name mon-service \
        --restart=always \
        -p 127.0.0.1:8080:8080 \
        image:latest || {
            log_error "Échec installation"
            exit 1
        }
}

install_service

# Résumé final
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 SERVICE INSTALLÉ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "URL : http://localhost:8080"
echo "SSH tunnel : ssh -L 8080:localhost:8080 pi@pi5.local"
```

### Checklist Script

- [ ] `set -euo pipefail` en haut
- [ ] Logging (`log_info`, `log_error`, `ok`)
- [ ] Détection auto (user, home, interface)
- [ ] Check root (`if [[ $EUID -ne 0 ]]`)
- [ ] Idempotent (vérifier état avant action)
- [ ] Backup avant modif
- [ ] Error handling (`|| { error; exit 1; }`)
- [ ] Résumé final (URLs, credentials)
- [ ] Variables quotées (`"$VAR"`)
- [ ] Testé sur Pi réel avant commit

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

## 🛠️ Workflow Debug

1. Éditer local (Mac)
2. Tester SSH : `ssh pi@pi5.local "bash -s" < script.sh`
3. Corriger bugs
4. Re-tester
5. **UN SEUL COMMIT** après validation

---

## ⚠️ Règles

**NE PAS** :
- Scripts non-idempotents
- Résumés verbeux
- Créer .md sans demande

**FAIRE** :
- Curl one-liners
- Idempotent
- Bref et direct
- **WebSearch sur bugs/erreurs** (bonnes pratiques, syntaxe correcte)

---

**Version** : 4.2
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
