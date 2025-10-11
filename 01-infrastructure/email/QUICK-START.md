# ⚡ Quick Start - Installation Email en 1 Commande

> **Configurez l'envoi d'emails sur votre Raspberry Pi 5 en moins de 10 minutes**

---

## 🚀 Installation Ultra-Rapide

### Méthode 1 : Wizard Automatique (Recommandé)

**Une seule commande** depuis SSH sur votre Pi :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/00-email-setup-wizard.sh | sudo bash
```

**Ce qui se passe** :
1. Le wizard pose 3 questions simples
2. Recommande automatiquement la meilleure solution
3. Installe et configure tout

**Durée** : 5-30 minutes selon l'option choisie

---

### Méthode 2 : Installation Directe (Si vous savez ce que vous voulez)

#### Option A : SMTP (Gmail) - Le plus simple

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/smtp-setup.sh | sudo bash
```

**Prérequis** : Compte Gmail + App Password

---

#### Option B : Resend API - Pour production

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/resend-setup.sh | sudo bash
```

**Prérequis** : Compte Resend.com (gratuit)

**⚠️ Important - DuckDNS** : Si vous utilisez DuckDNS (ex: `monpi.duckdns.org`), vous ne pouvez PAS vérifier votre domaine sur Resend (DuckDNS ne supporte pas les DNS avancés). Utilisez le **mode test** :
- Laissez le domaine vide dans le script
- Utilisez votre email personnel comme expéditeur
- Limitation : Ne peut envoyer qu'à VOTRE email
- Pour production : Achetez un vrai domaine (~10€/an)

---

#### Option C : Mailu - Serveur complet self-hosted

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/mailu-setup.sh | sudo bash
```

**Prérequis** : Domaine + DNS configurés + 8GB RAM

---

## 🧪 Test Rapide

Après installation, testez :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/maintenance/email-test.sh | sudo bash -s your@email.com
```

**Résultat attendu** : Email reçu ✅

---

## 📚 Besoin d'Aide ?

- **Guide complet** : [GUIDE-EMAIL-CHOICES.md](GUIDE-EMAIL-CHOICES.md)
- **README détaillé** : [README.md](README.md)
- **Documentation scripts** : [scripts/README.md](scripts/README.md)

---

## 🎯 Comparaison Rapide

| Solution | Difficulté | Gratuit | Temps | Cas d'usage |
|----------|------------|---------|-------|-------------|
| **SMTP (Gmail)** | ⭐ Facile | ✅ Oui | 5 min | Auth uniquement |
| **Resend API** | ⭐⭐ Moyen | ✅ 3k/mois | 10 min | Apps modernes |
| **Mailu** | ⭐⭐⭐ Avancé | ✅ Oui | 30 min | Serveur complet |

---

## 💡 Exemples d'Utilisation

### Exemple 1 : Installation Gmail (Débutant)

```bash
# 1. Installer
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/00-email-setup-wizard.sh | sudo bash

# Répondre :
# - Cas d'usage ? → 1 (Auth)
# - Volume ? → 1 (< 1000)
# - Niveau ? → 1 (Débutant)

# 2. Créer App Password Gmail
# → https://myaccount.google.com/apppasswords

# 3. Tester
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/maintenance/email-test.sh | sudo bash -s your@email.com
```

---

### Exemple 2 : Installation Resend (Production)

```bash
# 1. Créer compte Resend
# → https://resend.com (gratuit)

# 2. Obtenir API Key
# → Dashboard → API Keys → Create

# 3. Vérifier domaine
# → Dashboard → Domains → Add

# 4. Installer
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/resend-setup.sh | sudo bash

# 5. Tester
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/maintenance/email-test.sh | sudo bash -s test@yourdomain.com
```

---

## ⚡ One-Liner Complet

**Installation wizard + test automatique** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/00-email-setup-wizard.sh | sudo bash && curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/maintenance/email-test.sh | sudo bash -s your@email.com
```

---

## 🔧 Flags Utiles

```bash
# Dry-run (voir ce qui serait fait)
curl -fsSL https://raw.githubusercontent.com/.../smtp-setup.sh | sudo bash -s -- --dry-run

# Non-interactif (CI/CD)
export SMTP_PROVIDER=gmail
export SMTP_USER=user@gmail.com
export SMTP_PASS=app-password
curl -fsSL https://raw.githubusercontent.com/.../smtp-setup.sh | sudo bash -s -- --yes

# Verbose (debug)
curl -fsSL https://raw.githubusercontent.com/.../smtp-setup.sh | sudo bash -s -- --verbose
```

---

## 📝 Notes Importantes

1. **Pas besoin de `git clone`** : Tout fonctionne via `curl`
2. **Idempotent** : Safe à relancer (détecte config existante)
3. **Logs** : Automatiquement dans `/var/log/pi5-setup/`
4. **Backups** : Créés automatiquement avant modifications
5. **Rollback** : Possible si problème
6. **Versionnés** : Tous les scripts affichent leur version (v1.1.0)

---

## 🆘 Problèmes Courants

### "curl: command not found"

```bash
sudo apt update && sudo apt install -y curl
```

### "Permission denied"

Ajoutez `sudo` avant la commande :

```bash
curl -fsSL https://... | sudo bash
```

### Script échoue

Relancez avec `--verbose` :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/providers/smtp-setup.sh | sudo bash -s -- --verbose
```

Consultez les logs :

```bash
cat /var/log/pi5-setup/smtp-setup-*.log
```

---

## 🎓 Après Installation

### Utiliser SMTP dans votre app (Supabase Auth)

Rien à faire ! Supabase Auth est déjà configuré.

### Utiliser Resend dans votre app (Edge Function)

```typescript
const { data, error } = await supabase.functions.invoke('send-email', {
  body: {
    to: 'user@example.com',
    subject: 'Welcome!',
    html: '<h1>Hello!</h1>'
  }
})
```

### Utiliser Mailu (Webmail)

```
Webmail : https://mail.yourdomain.com/webmail
Admin   : https://mail.yourdomain.com/admin
```

---

**Version** : 1.1.0
**Dernière mise à jour** : 2025-10-11
**Support** : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)

---

[← Retour README](README.md) | [Guide Complet →](GUIDE-EMAIL-CHOICES.md)
