# 📧 Stack Email - Configuration et Gestion des Emails

> **Solutions pour l'envoi d'emails transactionnels et l'hébergement de serveurs de messagerie complets sur Raspberry Pi 5.**

[![Status](https://img.shields.io/badge/status-stable-green.svg)](.)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![ARM64](https://img.shields.io/badge/arch-ARM64-green.svg)](https://www.arm.com/)

---

## 🎯 Vue d'Ensemble

Ce dossier contient tout le nécessaire pour configurer l'envoi d'emails depuis vos applications et, si vous le souhaitez, pour héberger votre propre serveur de messagerie complet.

L'envoi d'emails est crucial pour des fonctionnalités comme :
- La confirmation de compte utilisateur (authentification)
- La réinitialisation de mot de passe
- Les notifications
- Les emails transactionnels (confirmation de commande, etc.)

Ce projet propose **trois solutions adaptées à différents besoins**, du plus simple au plus complexe.

### ✅ Solutions Proposées

1.  **SMTP Externe (via Gmail, Sendgrid...)**:
    *   **Idéal pour** : Démarrer rapidement, projets personnels, faibles volumes.
    *   **Difficulté** : Très facile.
    *   **Coût** : Gratuit (avec des limites journalières).

2.  **API Email Transactionnel (via Resend)**:
    *   **Idéal pour** : Applications modernes, SaaS, besoin d'analytics et de templates.
    *   **Difficulté** : Facile.
    *   **Coût** : Gratuit jusqu'à 3000 emails/mois, puis payant.

3.  **Serveur Email Auto-Hébergé (via Mailu)**:
    *   **Idéal pour** : Contrôle total, volumes élevés, confidentialité, créer ses propres boîtes mail.
    *   **Difficulté** : Avancé.
    *   **Coût** : Gratuit (hors coût du nom de domaine et du matériel).

> **📖 Pour une comparaison détaillée, consultez le [GUIDE DE CHOIX DES SOLUTIONS EMAIL](GUIDE-EMAIL-CHOICES.md).**

---

## 🚀 Démarrage Rapide : L'Assistant d'Installation

> **⚡ Pressé ?** Consultez le [QUICK-START.md](QUICK-START.md) pour les commandes essentielles (1 page)

Le moyen le plus simple de commencer est d'utiliser l'assistant interactif. Il vous posera quelques questions sur vos besoins et configurera automatiquement la solution la plus adaptée.

### 📋 Ordre d'Installation (IMPORTANT)

#### ✅ Méthode Recommandée : Wizard Automatique

**UN SEUL SCRIPT À LANCER** (via SSH sur votre Pi) :

```bash
# Via curl (pas besoin de git clone !)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/00-email-setup-wizard.sh | sudo bash

# Ou si vous avez déjà cloné le repo
sudo bash 00-email-setup-wizard.sh
```

Le wizard s'occupe de TOUT :
1. ✅ Détecte votre environnement (Supabase, Traefik, RAM, domaine)
2. ✅ Pose 3 questions simples
3. ✅ Recommande la meilleure solution
4. ✅ Lance automatiquement le bon script
5. ✅ Configure tout ce qui est nécessaire
6. ✅ Affiche un résumé avec instructions

**Durée totale** : 5-30 minutes selon l'option choisie

---

#### 🎯 Méthode Manuelle (Si vous savez déjà ce que vous voulez)

**Option A : SMTP (Gmail/SendGrid)**

```bash
# Via curl (depuis SSH sur votre Pi)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/smtp-setup.sh | sudo bash

# Ou si repo déjà cloné
sudo bash scripts/providers/smtp-setup.sh
```

**Durée** : 5-10 minutes
**Prérequis** : Compte Gmail ou SendGrid

---

**Option B : Resend API**

```bash
# Via curl
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/resend-setup.sh | sudo bash

# Ou local
sudo bash scripts/providers/resend-setup.sh
```

**Durée** : 10-15 minutes
**Prérequis** : Compte Resend.com (gratuit)

---

**Option C : Mailu (Self-hosted)**

```bash
# Via curl
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/mailu-setup.sh | sudo bash

# Ou local
sudo bash scripts/providers/mailu-setup.sh
```

**Durée** : 30+ minutes
**Prérequis** :
- Domaine acheté (ex: example.com)
- DNS configurés AVANT installation (MX, A, SPF)
- 8GB+ RAM sur le Pi

---

### 🧪 Test de Configuration (Après Installation)

**Après avoir installé une solution, testez-la** :

```bash
# Via curl
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/maintenance/email-test.sh | sudo bash -s your@email.com

# Ou local (détecte automatiquement la méthode installée)
sudo bash scripts/maintenance/email-test.sh your@email.com
```

**Résultat attendu** : Email reçu dans votre boîte mail ✅

---

### ⚠️ Important à Savoir

1. **Pas besoin de git clone** : Tous les scripts sont standalone
2. **Idempotent** : Safe à relancer (détecte config existante)
3. **Une seule commande** : Le wizard fait tout automatiquement
4. **Logs automatiques** : Tout est logué dans `/var/log/pi5-setup/`
5. **Rollback possible** : Backups automatiques avant modifications

---

## 📁 Structure du Dossier

```
01-infrastructure/email/
├── README.md                         # ⭐ Ce fichier : le hub central pour l'email
├── GUIDE-EMAIL-CHOICES.md            # 📚 Guide détaillé (2000+ lignes, analogies, tutoriels)
├── INSTALLATION-SUMMARY.md           # 📝 Récapitulatif technique complet
├── 00-email-setup-wizard.sh          # 🧙 Assistant interactif (POINT D'ENTRÉE)
│
├── scripts/                          # Scripts organisés par fonction
│   ├── README.md                     # Documentation de l'organisation
│   │
│   ├── providers/                    # 🎯 Scripts d'installation par provider
│   │   ├── smtp-setup.sh             # SMTP (Gmail, SendGrid, Mailgun, Custom)
│   │   ├── resend-setup.sh           # Resend API + Edge Function
│   │   └── mailu-setup.sh            # Mailu wrapper (validation + DNS)
│   │
│   ├── maintenance/                  # 🔧 Scripts d'administration
│   │   └── email-test.sh             # Test universel (auto-détecte config)
│   │
│   └── legacy/                       # 📦 Anciens scripts (ne pas utiliser)
│       ├── 01-mailu-deploy.sh        # (Remplacé par providers/mailu-setup.sh)
│       └── 02-integrate-traefik.sh   # (Ancienne intégration Traefik)
│
├── docs/                             # Documentation existante
│   ├── mailu-guide.md
│   └── ...
│
└── config/                           # Configurations (templates, etc.)
```

### 🎯 Fichiers Clés

| Fichier | Description | Quand l'utiliser |
|---------|-------------|------------------|
| **00-email-setup-wizard.sh** | 🧙 Wizard interactif | **TOUJOURS commencer ici** |
| **GUIDE-EMAIL-CHOICES.md** | 📚 Guide complet | Comprendre les options |
| **scripts/providers/smtp-setup.sh** | SMTP config | Installation manuelle SMTP |
| **scripts/providers/resend-setup.sh** | Resend config | Installation manuelle Resend |
| **scripts/providers/mailu-setup.sh** | Mailu wrapper | Installation manuelle Mailu |
| **scripts/maintenance/email-test.sh** | Test universel | Après installation |

---

## 🔧 Quelle Solution Choisir ?

Voici un résumé pour vous aider à décider.

| Critère | SMTP (Ex: Gmail) | Resend (API) | Mailu (Auto-hébergé) |
|:---|:---:|:---:|:---:|
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐⭐ Avancé |
| **Maintenance** | Aucune | Aucune | Régulière |
| **Coût (début)** | Gratuit | Gratuit | Gratuit |
| **Scalabilité** | Faible | Élevée | Très élevée |
| **Contrôle** | Faible | Moyen | **Total** |
| **Cas d'usage** | Authentification | Emails transactionnels | Serveur complet |
| **RAM requise** | 0 | ~50 MB | **~2-3 GB** |
| **Idéal pour** | Débutants, tests | Apps modernes, SaaS | Experts, confidentialité |

---

## 📚 Documentation

- **[GUIDE : Choisir sa Solution Email](GUIDE-EMAIL-CHOICES.md)** : **(⭐ COMMENCEZ ICI)** Guide complet avec analogies, tutoriels pas-à-pas, troubleshooting (2000+ lignes)
- **[INSTALLATION-SUMMARY.md](INSTALLATION-SUMMARY.md)** : Récapitulatif technique complet de ce qui a été créé (architecture, exemples, tests)
- **[scripts/README.md](scripts/README.md)** : Documentation de l'organisation des scripts et exemples d'utilisation
- **[GUIDE : Installer et Gérer Mailu](docs/mailu-guide.md)** : Guide complet Mailu (installation, DNS, maintenance)

---

## 💡 Exemples Concrets d'Utilisation

### Exemple 1 : Installation Simple (Débutant)

**Situation** : Vous voulez juste envoyer des emails d'authentification (signup, reset password) pour votre app.

**Solution** : SMTP avec Gmail

```bash
# 1. Lancer le wizard
sudo bash 00-email-setup-wizard.sh

# Réponses suggérées :
# - Cas d'usage ? → 1 (Auth uniquement)
# - Volume ? → 1 (< 1000/mois)
# - Niveau ? → 1 (Débutant)

# Le wizard recommande : SMTP (Gmail)
# Continuer ? → Oui

# 2. Suivre les instructions pour créer App Password Gmail

# 3. Tester
sudo bash scripts/maintenance/email-test.sh your@email.com

# ✅ Résultat : Email reçu en 5 minutes !
```

---

### Exemple 2 : Installation Production (SaaS)

**Situation** : Vous lancez une application SaaS avec emails transactionnels + notifications.

**Solution** : Resend API

```bash
# 1. Créer compte Resend (gratuit)
# → https://resend.com

# 2. Obtenir API Key
# → Dashboard → API Keys → Create

# 3. Vérifier domaine
# → Dashboard → Domains → Add Domain
# → Ajouter DNS records (TXT, MX)

# 4. Installation automatique
sudo bash 00-email-setup-wizard.sh

# Réponses suggérées :
# - Cas d'usage ? → 2 (Transactionnel + notifications)
# - Volume ? → 2 (1000-10k/mois)
# - Niveau ? → 2 (Intermédiaire)

# Le wizard recommande : Resend API
# → Entrer API Key, domaine, from email

# 5. Tester l'Edge Function
sudo bash scripts/maintenance/email-test.sh --resend test@yourdomain.com

# ✅ Résultat : Edge Function créée + email envoyé + analytics visibles sur Resend.com
```

**Utilisation dans votre app** :
```typescript
// Dans votre frontend ou backend
const { data, error } = await supabase.functions.invoke('send-email', {
  body: {
    to: 'user@example.com',
    subject: 'Welcome!',
    html: '<h1>Welcome to our app!</h1>'
  }
})
```

---

### Exemple 3 : Migration SMTP → Resend

**Situation** : Vous avez démarré avec SMTP Gmail, mais vous avez maintenant besoin de plus de volume et d'analytics.

```bash
# 1. Installer Resend (conserve SMTP)
sudo bash scripts/providers/resend-setup.sh

# 2. Tester les deux méthodes
sudo bash scripts/maintenance/email-test.sh --smtp test@gmail.com
sudo bash scripts/maintenance/email-test.sh --resend test@yourdomain.com

# ✅ Résultat : Les deux fonctionnent !
# - SMTP : Utilisé par Supabase Auth (signup, reset password)
# - Resend : Utilisé pour vos notifications customs (Edge Function)
```

---

### Exemple 4 : Installation CI/CD (Non-interactif)

**Situation** : Vous voulez automatiser l'installation dans un pipeline CI/CD.

```bash
# Installation SMTP non-interactive
export SMTP_PROVIDER=gmail
export SMTP_HOST=smtp.gmail.com
export SMTP_PORT=587
export SMTP_USER=bot@yourcompany.com
export SMTP_PASS=$GMAIL_APP_PASSWORD  # Depuis secrets
export SMTP_FROM=noreply@yourcompany.com

sudo bash scripts/providers/smtp-setup.sh --yes --quiet

# Vérifier succès
if [ $? -eq 0 ]; then
  echo "✅ Email configuration success"
else
  echo "❌ Email configuration failed"
  exit 1
fi

# Test automatisé
sudo bash scripts/maintenance/email-test.sh --smtp test@yourcompany.com
```

---

### Exemple 5 : Debug Verbose

**Situation** : Une installation échoue et vous voulez comprendre pourquoi.

```bash
# 1. Relancer avec verbose max
sudo bash scripts/providers/smtp-setup.sh --verbose --verbose

# 2. Consulter les logs détaillés
cat /var/log/pi5-setup/smtp-setup-*.log

# 3. Test en dry-run (sans exécuter)
sudo bash scripts/providers/smtp-setup.sh --dry-run

# Le script affiche toutes les actions qu'il ferait sans les exécuter
```

---

## 🆘 Dépannage (Troubleshooting)

**Problème : Mes emails arrivent dans les spams.**
- **Cause la plus fréquente** : Votre configuration DNS (SPF, DKIM, DMARC) est incorrecte ou manquante. C\'est surtout critique pour Mailu.
- **Solution** : Utilisez des outils comme [mail-tester.com](https://www.mail-tester.com) pour analyser votre score et obtenir des recommandations. Suivez le guide DNS dans la documentation de Mailu.

**Problème : Le script d\'installation échoue.**
- **Solution** : Vérifiez les prérequis pour chaque script. Pour Mailu, assurez-vous d\'avoir un nom de domaine, une IP publique et les ports nécessaires ouverts.

**Problème : Je ne sais pas si ma configuration fonctionne.**
- **Solution** : Utilisez le script de test fourni.
  ```bash
  sudo bash scripts/99-email-test.sh votre-adresse@email.com
  ```

---