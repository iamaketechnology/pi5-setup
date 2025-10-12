# 🏛️ Guide Architecture PI5-SETUP

> **Pour les contributeurs et développeurs** : Comprendre l'organisation du projet

---

## 🎯 Philosophie du Projet

### Principe Central : **"1 commande curl = 1 action"**

L'utilisateur doit pouvoir installer **n'importe quel service** en copiant-collant **une seule commande** dans le terminal.

**Exemple** :
```bash
curl -fsSL https://raw.githubusercontent.com/.../01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

**Résultat** : Supabase installé, configuré, démarré, accessible via HTTPS.

---

## 📐 Structure du Repository

### 🔢 Organisation par Catégories Numérotées

Le projet est organisé en **11 catégories**, chacune représentant un **domaine fonctionnel** :

```
01-infrastructure/     # Infrastructure de base (backend, reverse proxy, VPN)
02-securite/          # Sécurité & authentification
03-monitoring/        # Monitoring & observabilité
04-developpement/     # Outils développement
05-stockage/          # Stockage cloud
06-media/             # Serveurs média
07-domotique/         # Home automation
08-interface/         # Dashboards & UI
09-backups/           # Sauvegardes
10-productivity/      # Productivité
11-intelligence-artificielle/  # AI & automation
```

### ✅ Avantages de cette structure

1. **Navigation intuitive** : Un novice trouve facilement ce qu'il cherche
2. **Scalabilité** : Facile d'ajouter de nouveaux services
3. **Ordre logique** : Infra → Sécurité → Apps (dépendances naturelles)
4. **Pas de duplication** : Une stack = un emplacement unique

---

## 📂 Structure Standard d'une Stack

**CHAQUE stack** suit cette structure **OBLIGATOIRE** :

```
<categorie>/<stack-name>/
│
├── 📄 README.md                    # Vue d'ensemble (français, ~300-800 lignes)
├── 📄 <stack>-guide.md            # Guide débutant (analogies, ~500-1500 lignes)
├── 📄 <stack>-setup.md            # Instructions installation (détaillé, ~500-1000 lignes)
│
├── 📂 scripts/
│   ├── 01-<stack>-deploy.sh       # Script principal (curl one-liner)
│   ├── 02-<action>.sh             # Scripts complémentaires (optionnel)
│   │
│   ├── maintenance/               # Wrappers vers common-scripts
│   │   ├── _<stack>-common.sh     # Config wrapper
│   │   ├── <stack>-backup.sh
│   │   ├── <stack>-healthcheck.sh
│   │   ├── <stack>-update.sh
│   │   └── <stack>-logs.sh
│   │
│   └── utils/                     # Scripts utilitaires spécifiques
│       └── <action>.sh
│
├── 📂 compose/                    # Docker Compose files
│   └── docker-compose.yml
│
├── 📂 config/                     # Templates configuration
│   └── <service>/
│       └── config-files...
│
└── 📂 docs/                       # Documentation supplémentaire (optionnel)
    └── advanced-topics.md
```

### 📝 Conventions de Nommage

#### Fichiers Documentation

| Type | Ancien (❌) | Nouveau (✅) | Description |
|------|------------|-------------|-------------|
| Vue d'ensemble | `README.md` | `README.md` | Présentation stack |
| Guide débutant | `GUIDE-DEBUTANT.md` | `<stack>-guide.md` | Tutoriel pédagogique |
| Installation | `INSTALL.md` | `<stack>-setup.md` | Instructions détaillées |

**Exemples** :
- `01-infrastructure/email/email-guide.md`
- `01-infrastructure/apps/apps-setup.md`
- `03-monitoring/prometheus-grafana/monitoring-guide.md`

#### Scripts

| Type | Format | Exemple |
|------|--------|---------|
| Déploiement principal | `01-<stack>-deploy.sh` | `01-supabase-deploy.sh` |
| Scripts complémentaires | `02-<action>.sh` | `02-integrate-traefik.sh` |
| Maintenance | `<stack>-<action>.sh` | `supabase-backup.sh` |
| Wrappers internes | `_<stack>-common.sh` | `_email-common.sh` |

#### Dossiers

| Type | Format | Exemple |
|------|--------|---------|
| Catégorie | `<numero>-<nom>/` | `01-infrastructure/` |
| Stack | `<nom-court>/` | `supabase/`, `email/`, `apps/` |
| Sous-dossiers | minuscules | `scripts/`, `config/`, `docs/` |

---

## 🔑 Principes Architecture

### 1. **Idempotence**

**Règle** : Un script peut être exécuté **plusieurs fois** sans erreur.

```bash
# ✅ BON
if [[ ! -f "/opt/supabase/docker-compose.yml" ]]; then
    log "Déploiement Supabase..."
    # ... déploiement
else
    log "Supabase déjà déployé, skip"
fi

# ❌ MAUVAIS
docker-compose up -d  # Peut échouer si déjà démarré
```

### 2. **Wrapper Pattern (Maintenance)**

**Problème** : Éviter duplication code (backup, healthcheck, etc.)

**Solution** : Scripts maintenance = **wrappers** vers `common-scripts/`

```bash
# 01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh

#!/usr/bin/env bash
set -euo pipefail

# Config spécifique stack
source _supabase-common.sh

# Variables stack
export SERVICE_NAME="supabase"
export BACKUP_SOURCES=(
    "docker:supabase-db:postgres:postgres:/var/lib/postgresql/data"
    "directory:/opt/supabase/config"
)

# Déléguer à script commun
exec ${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh "$@"
```

**Avantages** :
- Code réutilisé (1 seul script backup pour toutes les stacks)
- Maintenance centralisée
- Cohérence garantie

### 3. **Validation & Error Handling**

**Chaque script DOIT** :

```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined var, pipe failure

# Fonctions standard (lib.sh)
log()   { echo -e "\033[36m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[33m[WARN]\033[0m $*"; }
ok()    { echo -e "\033[32m[OK]\033[0m $*"; }
error() { echo -e "\033[31m[ERROR]\033[0m $* (line ${BASH_LINENO[0]})" >&2; exit 1; }

# Vérifications avant exécution
check_root() {
    [[ $EUID -eq 0 ]] || error "Script must be run as root"
}

check_dependencies() {
    command -v docker &>/dev/null || error "Docker not installed"
}

# Backup avant modification
backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup-$(date +%Y%m%d-%H%M%S)"
    fi
}

# Rollback si échec
trap 'on_error' ERR
on_error() {
    warn "Error occurred, rolling back..."
    # Restore backup, stop containers, etc.
}
```

### 4. **Logging Structuré**

```bash
readonly LOG_DIR="/var/log/pi5-<stack>"
readonly LOG_FILE="${LOG_DIR}/<stack>-deploy.log"

# Rediriger stdout/stderr vers fichier + console
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

log "Starting deployment..."
# Tous les messages sont loggés automatiquement
```

### 5. **Résumé Final**

**Chaque script DOIT** afficher un résumé à la fin :

```bash
print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║              SUPABASE DEPLOYMENT SUCCESS                      ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "🌐 URLs"
    echo "   Studio:  https://studio.yourdomain.com"
    echo "   API:     https://api.yourdomain.com"
    echo ""
    echo "🔑 Credentials"
    echo "   Anon Key: ${ANON_KEY}"
    echo "   Service Role Key: ${SERVICE_ROLE_KEY}"
    echo ""
    echo "📂 Paths"
    echo "   Config: /opt/supabase/.env"
    echo "   Logs:   /var/log/pi5-supabase/"
    echo ""
}
```

---

## 📚 Documentation Obligatoire

### README.md (Vue d'ensemble)

**Contenu** (~300-800 lignes) :
- Description stack (1-2 paragraphes)
- Fonctionnalités principales (bullet points)
- Prérequis (Docker, Traefik, etc.)
- Installation rapide (curl one-liner)
- Configuration (variables importantes)
- Accès (URLs, ports)
- Architecture (diagramme ASCII optionnel)
- Troubleshooting basique

**Style** : Technique mais accessible

### <stack>-guide.md (Guide Débutant)

**Contenu** (~500-1500 lignes) :
- **Analogies simples** : "Supabase = Firebase gratuit et open source"
- **Use cases** (3-5 exemples concrets)
- **Concepts expliqués** : Qu'est-ce que PostgreSQL ? API REST ? Auth ?
- **Tutoriel pas-à-pas** : Installation + première utilisation
- **Exemples code** : Copier-coller ready
- **Troubleshooting débutants** : Erreurs courantes + solutions
- **Checklist progression** : Débutant → Intermédiaire → Avancé
- **Ressources** : Vidéos, docs officielles, communautés

**Style** : Pédagogique, français, **aucun jargon non expliqué**

### <stack>-setup.md (Installation Détaillée)

**Contenu** (~500-1000 lignes) :
- Installation automatique (curl one-liner)
- Installation manuelle (étapes détaillées)
- Configuration avancée
- Intégration avec autres stacks
- Multi-scénarios (si applicable)
- Vérification post-installation
- Commandes utiles
- Migration/Upgrade

**Style** : Technique, exhaustif

---

## 🛠️ Créer une Nouvelle Stack

### Étapes

1. **Déterminer catégorie** (01-11)

2. **Créer dossier** :
   ```bash
   mkdir -p <numero-categorie>/<nom-stack>/{scripts/{maintenance,utils},compose,config,docs}
   ```

3. **Copier template** :
   ```bash
   cp .templates/GUIDE-DEBUTANT-TEMPLATE.md <categorie>/<stack>/<stack>-guide.md
   ```

4. **Créer fichiers obligatoires** :
   - `README.md`
   - `<stack>-guide.md`
   - `<stack>-setup.md`
   - `scripts/01-<stack>-deploy.sh`

5. **Créer wrappers maintenance** :
   ```bash
   # scripts/maintenance/_<stack>-common.sh
   export SERVICE_NAME="<stack>"
   export BACKUP_SOURCES=(...)

   # scripts/maintenance/<stack>-backup.sh
   source _<stack>-common.sh
   exec ${COMMON_SCRIPTS_DIR}/04-backup-rotate.sh "$@"
   ```

6. **Tester sur Pi 5 ARM64**

7. **Mettre à jour** :
   - `<categorie>/README.md` (ajouter stack)
   - `CLAUDE.md` (section stacks principales)
   - `ROADMAP.md` (si nouvelle phase)

---

## 🚫 Erreurs Courantes à Éviter

### ❌ Mauvais Placement

```
# MAUVAIS
pi5-setup/
├── my-cool-stack/        # ❌ À la racine
└── pi5-xyz-stack/        # ❌ Ancien naming

# BON
pi5-setup/
├── 01-infrastructure/
│   └── my-cool-stack/    # ✅ Dans catégorie appropriée
```

### ❌ Naming Inconsistant

```
# MAUVAIS
├── GUIDE-DEBUTANT.md     # ❌ Générique
├── INSTALL.md            # ❌ Générique
└── install-xyz.sh        # ❌ Pas de numéro

# BON
├── xyz-guide.md          # ✅ Préfixe stack
├── xyz-setup.md          # ✅ Préfixe stack
└── 01-xyz-deploy.sh      # ✅ Numéroté
```

### ❌ Scripts Non-Idempotents

```bash
# MAUVAIS
docker-compose up -d  # Peut échouer si déjà running

# BON
if docker ps --format '{{.Names}}' | grep -q '^myapp$'; then
    log "Already running, skipping..."
else
    docker-compose up -d
fi
```

### ❌ Pas de Documentation Débutant

```
# MAUVAIS
├── README.md           # Seulement doc technique
└── scripts/

# BON
├── README.md           # Vue d'ensemble
├── xyz-guide.md        # Pour débutants (analogies, tutos)
├── xyz-setup.md        # Installation détaillée
└── scripts/
```

---

## 🤖 Agent Architecture Guardian

Un agent Claude spécialisé valide la cohérence architecture.

**Localisation** : `.claude/agents/architecture-guardian.md`

**Rôles** :
- ✅ Valider structure nouvelle stack
- ✅ Vérifier naming conventions
- ✅ Assurer présence fichiers obligatoires
- ✅ Proposer réorganisation si incohérence
- ✅ Mettre à jour `CLAUDE.md` automatiquement

**Quand consulter** :
- Création nouvelle stack
- Doute sur placement catégorie
- Réorganisation fichiers
- Modification structure

---

## 📊 Exemples de Référence

### Structure Parfaite

[01-infrastructure/supabase/](01-infrastructure/supabase/)
```
supabase/
├── README.md                      # Vue d'ensemble
├── supabase-guide.md             # Guide débutant (500+ lignes)
├── supabase-setup.md             # Installation détaillée
├── scripts/
│   ├── 01-prerequisites-setup.sh
│   ├── 02-supabase-deploy.sh
│   ├── maintenance/
│   │   ├── _supabase-common.sh
│   │   ├── supabase-backup.sh
│   │   └── ...
│   └── utils/
├── compose/
├── config/
└── docs/
    └── advanced/
```

### Script Parfait

[01-infrastructure/supabase/scripts/02-supabase-deploy.sh](01-infrastructure/supabase/scripts/02-supabase-deploy.sh)

**Caractéristiques** :
- ✅ `set -euo pipefail`
- ✅ Fonctions error handling
- ✅ Validation prérequis
- ✅ Idempotent
- ✅ Backup avant modification
- ✅ Logging structuré
- ✅ Résumé final avec URLs/credentials

### Documentation Parfaite

[01-infrastructure/traefik/traefik-guide.md](01-infrastructure/traefik/traefik-guide.md)

**Caractéristiques** :
- ✅ Analogie simple ("Traefik = réceptionniste d'hôtel")
- ✅ 3 use cases concrets
- ✅ Tutoriels pas-à-pas (3 scénarios)
- ✅ Code copier-coller
- ✅ Troubleshooting débutants (tableau)
- ✅ Checklist progression
- ✅ Ressources apprentissage

---

## 🎯 Checklist Validation Stack

Avant de soumettre une nouvelle stack, vérifier :

### Structure
- [ ] Dossier dans bonne catégorie (`<numero>-<categorie>/<stack>/`)
- [ ] Naming correct (`<stack>-guide.md`, `<stack>-setup.md`)
- [ ] Scripts numérotés (`01-<stack>-deploy.sh`)
- [ ] Wrappers maintenance présents

### Documentation
- [ ] `README.md` présent (~300-800 lignes)
- [ ] `<stack>-guide.md` présent (~500-1500 lignes)
- [ ] `<stack>-setup.md` présent (~500-1000 lignes)
- [ ] Analogies simples dans guide
- [ ] Exemples concrets (3-5 use cases)
- [ ] Code copier-coller ready
- [ ] Troubleshooting débutants

### Scripts
- [ ] Idempotents (safe re-run)
- [ ] `set -euo pipefail`
- [ ] Error handling (fonctions log/warn/error)
- [ ] Validation prérequis
- [ ] Backup avant modification
- [ ] Logging vers `/var/log/`
- [ ] Résumé final avec URLs/credentials

### Intégration
- [ ] Testé sur Pi 5 ARM64 (si possible)
- [ ] `<categorie>/README.md` mis à jour
- [ ] `CLAUDE.md` mis à jour
- [ ] `ROADMAP.md` mis à jour (si nouvelle phase)

---

## 🤝 Contribution

**Pour contribuer** :

1. **Fork** le repo
2. **Créer branche** : `git checkout -b feature/ma-stack`
3. **Suivre architecture** (ce document)
4. **Tester** sur Pi 5 (si possible)
5. **Valider** avec `architecture-guardian` agent
6. **Pull Request** avec description détaillée

**Code review portera sur** :
- Respect structure standard
- Qualité documentation (pédagogique)
- Idempotence scripts
- Error handling
- Tests ARM64

---

## 📖 Ressources

**Templates** :
- [.templates/GUIDE-DEBUTANT-TEMPLATE.md](.templates/GUIDE-DEBUTANT-TEMPLATE.md)

**Exemples** :
- Structure : [01-infrastructure/supabase/](01-infrastructure/supabase/)
- Scripts : [common-scripts/](common-scripts/)
- Docs : [01-infrastructure/traefik/traefik-guide.md](01-infrastructure/traefik/traefik-guide.md)

**Guides** :
- [CLAUDE.md](CLAUDE.md) - Instructions pour AI assistants
- [ROADMAP.md](ROADMAP.md) - Vision projet
- [INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md) - Parcours complet

---

**Version** : 1.0
**Dernière mise à jour** : 2025-01-12
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
