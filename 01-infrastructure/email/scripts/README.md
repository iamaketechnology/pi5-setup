# 📂 Scripts Email - Organisation

> **Structure claire et logique des scripts de configuration email**

---

## 🗂️ Structure des Dossiers

```
scripts/
├── providers/              # Scripts d'installation par provider
│   ├── smtp-setup.sh       # Configuration SMTP (Gmail, SendGrid, Mailgun)
│   ├── resend-setup.sh     # Configuration Resend API
│   └── mailu-setup.sh      # Installation Mailu (wrapper)
├── maintenance/            # Scripts d'administration
│   └── email-test.sh       # Test universel de configuration email
└── legacy/                 # Anciens scripts (ne pas utiliser)
    ├── 01-mailu-deploy.sh  # (Remplacé par providers/mailu-setup.sh)
    └── 02-integrate-traefik.sh
```

---

## 📚 Guide d'Utilisation

### 🧙 Méthode Recommandée : Wizard Interactif

Utilisez le wizard principal qui choisit automatiquement le bon script :

```bash
sudo bash ../00-email-setup-wizard.sh
```

**Le wizard** :
- Pose 3 questions simples
- Recommande la meilleure solution
- Lance automatiquement le bon script

---

### 🎯 Installation Manuelle (Si vous savez ce que vous voulez)

#### Option 1 : SMTP (Gmail/SendGrid)

**Quand utiliser** : Débutants, petits projets, < 500 emails/jour

```bash
sudo bash providers/smtp-setup.sh
```

**Durée** : 5-10 minutes
**Prérequis** : Compte Gmail ou SendGrid

---

#### Option 2 : Resend API

**Quand utiliser** : Apps modernes, besoin analytics, 1000-10k emails/mois

```bash
sudo bash providers/resend-setup.sh
```

**Durée** : 10-15 minutes
**Prérequis** : Compte Resend.com (gratuit)

---

#### Option 3 : Mailu (Self-hosted)

**Quand utiliser** : > 10k emails/mois, contrôle total, boîtes mail

```bash
sudo bash providers/mailu-setup.sh
```

**Durée** : 30+ minutes
**Prérequis** : Domaine, DNS configurés, 8GB+ RAM

---

## 🧪 Test de Configuration

Après installation, testez votre configuration :

```bash
# Auto-détecte la méthode installée
sudo bash maintenance/email-test.sh your@email.com

# Ou forcer une méthode spécifique
sudo bash maintenance/email-test.sh --smtp your@email.com
sudo bash maintenance/email-test.sh --resend your@email.com
sudo bash maintenance/email-test.sh --mailu your@email.com
```

---

## 🔧 Options Avancées

Tous les scripts supportent ces flags :

```bash
--dry-run          # Affiche ce qui serait fait sans exécuter
--yes, -y          # Saute les confirmations (mode automatique)
--verbose, -v      # Sortie détaillée (debug)
--force            # Force la reconfiguration (même si déjà installé)
```

**Exemples** :

```bash
# Tester ce qui serait fait
sudo bash providers/smtp-setup.sh --dry-run

# Installation non-interactive
sudo bash providers/resend-setup.sh --yes

# Debug verbose
sudo bash providers/smtp-setup.sh --verbose
```

---

## 📊 Comparaison Rapide

| Script | Difficulté | Temps | RAM | Gratuit ? |
|--------|------------|-------|-----|-----------|
| **smtp-setup.sh** | ⭐ Facile | 5 min | 0 MB | ✅ Oui (500/jour) |
| **resend-setup.sh** | ⭐⭐ Moyen | 10 min | 50 MB | ✅ Oui (3k/mois) |
| **mailu-setup.sh** | ⭐⭐⭐ Avancé | 30 min | 2-3 GB | ✅ Oui (illimité) |

---

## 🔍 Détails des Scripts

### providers/smtp-setup.sh

**Fonctionnalités** :
- Support 4 providers (Gmail, SendGrid, Mailgun, Custom)
- Test connexion SMTP automatique
- Configuration Supabase Auth
- Idempotent (safe à relancer)

**Variables d'environnement** :
```bash
SMTP_PROVIDER=gmail
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASS=app-password
SMTP_FROM=noreply@yourdomain.com
```

---

### providers/resend-setup.sh

**Fonctionnalités** :
- Création Edge Function automatique
- Test API Key
- Templates email HTML
- Support CORS

**Variables d'environnement** :
```bash
RESEND_API_KEY=re_xxxxx
RESEND_FROM_EMAIL=noreply@yourdomain.com
RESEND_DOMAIN=yourdomain.com
```

---

### providers/mailu-setup.sh

**Fonctionnalités** :
- Validation prérequis (RAM, ports, DNS)
- Guide configuration DNS
- Check DNS automatique
- Wrapper autour de legacy/01-mailu-deploy.sh

**Variables d'environnement** :
```bash
MAILU_DOMAIN=yourdomain.com
MAILU_ADMIN_EMAIL=admin@yourdomain.com
MAILU_ADMIN_PASSWORD=SecurePassword123!
```

---

### maintenance/email-test.sh

**Fonctionnalités** :
- Auto-détection méthode installée
- Envoi email de test
- Diagnostic configuration
- Support multi-méthodes

**Usage** :
```bash
# Auto-détection
sudo bash maintenance/email-test.sh test@example.com

# Force méthode
sudo bash maintenance/email-test.sh --smtp test@example.com
```

---

## 🛠️ Troubleshooting

### Script ne se lance pas

**Problème** : Permission denied

**Solution** :
```bash
chmod +x providers/*.sh maintenance/*.sh
```

---

### Erreur "lib.sh not found"

**Problème** : Bibliothèque commune non trouvée

**Solution** :
```bash
# Vérifier que common-scripts existe
ls -la ../../common-scripts/lib.sh

# Si manquant, installer depuis repo
```

---

### Configuration existante détectée

**Comportement normal** : Le script est idempotent

**Options** :
1. Garder config actuelle (quitter)
2. Reconfigurer (remplacer)

**Forcer reconfiguration** :
```bash
sudo bash providers/smtp-setup.sh --force
```

---

## 📝 Logs

Tous les scripts génèrent des logs dans `/var/log/pi5-setup/` :

```bash
# Voir logs récents
ls -lt /var/log/pi5-setup/

# Consulter un log spécifique
cat /var/log/pi5-setup/smtp-setup-20250111-143025.log

# Suivre en temps réel
tail -f /var/log/pi5-setup/smtp-setup-*.log
```

---

## 🔄 Migration Entre Options

Vous pouvez migrer facilement :

```bash
# SMTP → Resend
sudo bash providers/resend-setup.sh

# Resend → Mailu
sudo bash providers/mailu-setup.sh

# Retour SMTP (avec --force)
sudo bash providers/smtp-setup.sh --force
```

Les configurations ne se suppriment pas mutuellement. Vous pouvez avoir SMTP (pour Auth) + Resend (pour notifications).

---

## 📚 Documentation Complète

- **Guide débutant** : [../GUIDE-EMAIL-CHOICES.md](../GUIDE-EMAIL-CHOICES.md)
- **README principal** : [../README.md](../README.md)
- **Wizard** : [../00-email-setup-wizard.sh](../00-email-setup-wizard.sh)

---

## 🆘 Support

**Problème avec un script ?**

1. Relancer avec `--verbose` :
   ```bash
   sudo bash providers/smtp-setup.sh --verbose
   ```

2. Consulter les logs :
   ```bash
   cat /var/log/pi5-setup/smtp-setup-*.log
   ```

3. Ouvrir une issue :
   [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)

---

**Version** : 1.1.0
**Dernière mise à jour** : 2025-10-11
**Auteur** : PI5-SETUP Project
