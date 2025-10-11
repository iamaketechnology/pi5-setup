# 📧 Guide Débutant : Choisir sa Solution Email

> **Comprendre et choisir la meilleure solution email pour votre Raspberry Pi 5**

---

## 📋 Table des Matières

1. [Introduction](#introduction)
2. [Les 3 Options Expliquées](#les-3-options-expliquées)
3. [Tableau Comparatif](#tableau-comparatif)
4. [Cas d'Usage](#cas-dusage)
5. [Installation](#installation)
6. [Tutoriels Pas-à-Pas](#tutoriels-pas-à-pas)
7. [Troubleshooting](#troubleshooting)
8. [FAQ](#faq)

---

## 🎯 Introduction

### Pourquoi ce guide ?

Vous avez installé Supabase sur votre Raspberry Pi 5, et maintenant vous voulez envoyer des emails (authentification, notifications, etc.). **Mais quelle solution choisir ?**

Ce guide compare **3 approches** :
1. **SMTP** (simple, gratuit)
2. **Resend API** (moderne, flexible)
3. **Mailu** (self-hosted complet)

### Analogie Simple

Imaginez que vous voulez envoyer du courrier :

- **SMTP** = Utiliser La Poste (service existant, simple)
- **Resend** = Service de coursier privé (moderne, suivi en temps réel)
- **Mailu** = Créer votre propre bureau de poste (contrôle total, mais complexe)

---

## 📊 Les 3 Options Expliquées

### 1. SMTP (Simple Mail Transfer Protocol)

**C'est quoi ?** Le protocole standard pour envoyer des emails, en utilisant un fournisseur existant (Gmail, SendGrid, etc.)

**Analogie** : C'est comme utiliser votre compte Gmail pour envoyer des emails depuis votre application.

**Comment ça marche ?**
```
Votre App → Supabase Auth → Gmail SMTP → Destinataire
```

**Avantages** :
- ✅ **Très simple** : Configuration en 5 minutes
- ✅ **Gratuit** : 500 emails/jour avec Gmail
- ✅ **Zéro maintenance** : Gmail/SendGrid s'occupent de tout
- ✅ **Fiable** : Bonne délivrabilité (pas de spam)

**Inconvénients** :
- ❌ **Limites** : Quotas (500/jour Gmail, 100/jour SendGrid gratuit)
- ❌ **Dépendance** : Si Gmail est down, vos emails aussi
- ❌ **Basique** : Peu de features avancées

**Idéal pour** :
- Débuter rapidement
- Emails d'authentification uniquement
- Petits projets (<500 emails/jour)

---

### 2. Resend API

**C'est quoi ?** Un service moderne d'envoi d'emails avec API, analytics, et support de templates React.

**Analogie** : C'est comme Stripe pour les paiements, mais pour les emails.

**Comment ça marche ?**
```
Votre App → Edge Function → Resend API → Destinataire
```

**Avantages** :
- ✅ **API moderne** : Simple à utiliser, bien documentée
- ✅ **Analytics** : Dashboard avec statistiques détaillées
- ✅ **Templates React** : Créer des emails avec React Email
- ✅ **Gratuit** : 3000 emails/mois (vs 500/jour SMTP)
- ✅ **Excellente délivrabilité** : Infrastructure optimisée
- ✅ **Webhooks** : Notifications (ouvert, cliqué, etc.)

**Inconvénients** :
- ❌ **Payant au-delà** : $20/mois après 3000 emails/mois
- ❌ **Dépendance externe** : Service tiers
- ❌ **Vérification domaine** : Nécessite configuration DNS

**Idéal pour** :
- Applications modernes (SaaS, web apps)
- Emails transactionnels + notifications
- Besoin d'analytics
- Volume modéré (< 10 000/mois)

---

### 3. Mailu (Self-Hosted Email Server)

**C'est quoi ?** Un serveur email complet que vous hébergez sur votre Pi (comme Gmail, mais chez vous).

**Analogie** : C'est comme créer votre propre Netflix au lieu d'utiliser le service officiel.

**Comment ça marche ?**
```
Votre App → Mailu SMTP → Internet → Destinataire
```

**Avantages** :
- ✅ **Contrôle total** : Vos données, vos règles
- ✅ **Gratuit** : Illimité (sauf coût domaine ~10€/an)
- ✅ **Serveur complet** : Boîtes mail, webmail, anti-spam
- ✅ **Pas de quotas** : Envoyez autant que vous voulez
- ✅ **Confidentialité** : Vos emails restent chez vous

**Inconvénients** :
- ❌ **Complexe** : Configuration DNS critique (MX, SPF, DKIM, DMARC)
- ❌ **RAM** : 8GB+ recommandé
- ❌ **Maintenance** : Mises à jour, monitoring, sécurité
- ❌ **Risque blacklist** : Si mal configuré, vos emails iront en spam
- ❌ **IP publique** : Nécessaire, ports 25/587/993 ouverts

**Idéal pour** :
- Apprentissage (comprendre comment fonctionne l'email)
- Volume élevé (> 10 000 emails/mois)
- Entreprise (boîtes mail pour employés)
- Confidentialité absolue

---

## 📊 Tableau Comparatif

| Critère | SMTP | Resend | Mailu |
|---------|------|--------|-------|
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐ Avancé |
| **Temps d'installation** | 5-10 min | 10-15 min | 30+ min |
| **Coût/mois** | Gratuit | Gratuit → $20 | Gratuit |
| **Volume gratuit** | 500/jour | 3000/mois | Illimité |
| **Maintenance** | Zéro | Zéro | Régulière |
| **RAM requise** | Aucune | Aucune | 8GB+ |
| **Configuration DNS** | Non | Oui (simple) | Oui (complexe) |
| **Analytics** | Non | ✅ Oui | Basique |
| **Templates** | Basique | ✅ React Email | Basique |
| **Délivrabilité** | ✅ Bonne | ✅ Excellente | ⚠️ À configurer |
| **Contrôle** | ❌ Limité | ⚠️ Moyen | ✅ Total |

---

## 🎯 Cas d'Usage

### Cas 1 : Blog Personnel

**Besoin** : Envoyer 10-20 emails/jour (notifications nouveaux articles)

**Recommandation** : **SMTP (Gmail)**
- Volume très faible
- Gratuit
- Installation 5 minutes

---

### Cas 2 : SaaS en Développement

**Besoin** : 100-500 emails/jour (signup, reset password, notifications)

**Recommandation** : **Resend API**
- API moderne
- Analytics pour optimiser
- Gratuit au début (3000/mois)
- Scalable ($20/mois pour 50k)

---

### Cas 3 : E-commerce avec 1000+ clients

**Besoin** : 5000 emails/jour (confirmations, tracking, marketing)

**Recommandation** : **Resend API** (puis Mailu si > 10k/mois)
- Commencer avec Resend ($20/mois)
- Migrer vers Mailu si coûts augmentent

---

### Cas 4 : Startup avec Équipe

**Besoin** : Emails app + boîtes mail employés (team@startup.com)

**Recommandation** : **Mailu**
- Serveur email complet
- Boîtes mail illimitées
- Économies long-terme vs Google Workspace

---

### Cas 5 : Apprendre le Self-Hosting

**Besoin** : Comprendre comment fonctionne l'email

**Recommandation** : **Mailu**
- Éducatif
- Contrôle total
- Projet d'apprentissage

---

## 🚀 Installation

### Méthode 1 : Wizard Interactif (Recommandé)

Le wizard pose 3 questions et installe automatiquement la meilleure option :

```bash
sudo bash /path/to/00-email-setup-wizard.sh
```

**Questions posées** :
1. Cas d'usage ? (Auth / Transactionnel / Serveur complet)
2. Volume estimé ? (< 1000 / 1000-10000 / > 10000)
3. Niveau technique ? (Débutant / Intermédiaire / Avancé)

**Résultat** : Installation automatique de la solution recommandée.

---

### Méthode 2 : Installation Manuelle

Si vous savez déjà quelle option vous voulez :

#### Option A : SMTP
```bash
sudo bash /path/to/scripts/01-smtp-setup.sh
```

**Durée** : 5-10 minutes
**Prérequis** : Compte Gmail ou SendGrid

#### Option B : Resend
```bash
sudo bash /path/to/scripts/02-resend-setup.sh
```

**Durée** : 10-15 minutes
**Prérequis** : Compte Resend.com (gratuit)

#### Option C : Mailu
```bash
sudo bash /path/to/scripts/03-mailu-wrapper.sh
```

**Durée** : 30+ minutes
**Prérequis** : Domaine, DNS configurés, 8GB+ RAM

---

## 📚 Tutoriels Pas-à-Pas

### Tutoriel 1 : SMTP avec Gmail (Débutant)

#### Étape 1 : Créer un App Password Gmail

1. Aller sur [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Sélectionner "App" : Mail
3. Sélectionner "Device" : Other (Supabase)
4. Cliquer "Generate"
5. Copier le mot de passe (16 caractères)

#### Étape 2 : Lancer le script

```bash
sudo bash /path/to/scripts/01-smtp-setup.sh
```

#### Étape 3 : Répondre aux questions

- Provider ? → **1 (Gmail)**
- Email Gmail ? → **votre-email@gmail.com**
- App Password ? → **[coller le mot de passe]**
- From email ? → **votre-email@gmail.com**

#### Étape 4 : Tester

```bash
sudo bash /path/to/scripts/99-email-test.sh votre-email@gmail.com
```

**Résultat attendu** : Email reçu dans votre boîte Gmail !

---

### Tutoriel 2 : Resend API (Intermédiaire)

#### Étape 1 : Créer un compte Resend

1. Aller sur [resend.com](https://resend.com)
2. Créer un compte (gratuit)
3. Vérifier votre email

#### Étape 2 : Obtenir une API Key

1. Dashboard → [API Keys](https://resend.com/api-keys)
2. "Create API Key"
3. Nom : "Supabase PI5"
4. Copier la clé (commence par `re_`)

#### Étape 3 : Vérifier votre domaine

1. Dashboard → [Domains](https://resend.com/domains)
2. "Add Domain"
3. Entrer votre domaine (ex: `example.com`)
4. Ajouter les DNS records fournis (TXT, MX, etc.)
5. Attendre vérification (5-30 minutes)

#### Étape 4 : Lancer le script

```bash
sudo bash /path/to/scripts/02-resend-setup.sh
```

#### Étape 5 : Configuration

- API Key ? → **re_xxxxx**
- Domaine ? → **example.com**
- From email ? → **noreply@example.com**

#### Étape 6 : Tester

```bash
sudo bash /path/to/scripts/99-email-test.sh --resend test@example.com
```

**Résultat** : Email envoyé + visible dans [Resend Analytics](https://resend.com/emails)

---

### Tutoriel 3 : Mailu (Avancé)

#### Étape 1 : Préparer le domaine

**Prérequis** : Posséder un domaine (acheté sur Namecheap, OVH, etc.)

#### Étape 2 : Configurer DNS (AVANT installation)

**Records à créer** :

| Type | Nom | Valeur | Priorité |
|------|-----|--------|----------|
| A | mail.example.com | [IP_PI] | - |
| MX | example.com | mail.example.com | 10 |
| TXT | example.com | v=spf1 mx ~all | - |

**Tester DNS** :
```bash
dig MX example.com
dig A mail.example.com
```

#### Étape 3 : Lancer le wrapper

```bash
sudo bash /path/to/scripts/03-mailu-wrapper.sh
```

Le script :
- ✅ Valide les prérequis (RAM, ports, DNS)
- ✅ Guide la configuration
- ✅ Installe Mailu automatiquement

#### Étape 4 : Configuration DKIM (APRÈS installation)

```bash
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu config-export --format=dkim
```

Copier la sortie et créer :

| Type | Nom | Valeur |
|------|-----|--------|
| TXT | dkim._domainkey.example.com | [sortie commande] |

#### Étape 5 : Tester

1. Webmail : `https://mail.example.com/webmail`
2. Envoyer un email de test
3. Vérifier score spam : [mail-tester.com](https://www.mail-tester.com)
4. Objectif : **10/10**

---

## 🛠️ Troubleshooting

### Problème 1 : Emails vont en spam (SMTP/Resend)

**Cause** : SPF/DKIM non configurés

**Solution** :
- **Resend** : Vérifier domaine sur resend.com
- **SMTP Gmail** : Pas de solution (utiliser Resend)

---

### Problème 2 : "Connection refused" (SMTP)

**Cause** : Credentials incorrects ou port bloqué

**Solution** :
```bash
# Tester connexion manuellement
telnet smtp.gmail.com 587

# Vérifier config
cat /home/pi/stacks/supabase/.env | grep SMTP

# Relancer script avec --verbose
sudo bash /path/to/scripts/01-smtp-setup.sh --verbose
```

---

### Problème 3 : Resend API "Unauthorized"

**Cause** : API Key invalide

**Solution** :
1. Vérifier API key sur [resend.com/api-keys](https://resend.com/api-keys)
2. Relancer script :
```bash
sudo bash /path/to/scripts/02-resend-setup.sh --force
```

---

### Problème 4 : Mailu emails non reçus

**Cause** : DNS mal configurés

**Solution** :
```bash
# Tester DNS
dig MX example.com
dig A mail.example.com
dig TXT example.com | grep spf

# Vérifier ports ouverts
sudo netstat -tuln | grep ':25\|:587'

# Voir logs Mailu
cd /home/pi/stacks/mailu
docker compose logs -f postfix
```

---

## ❓ FAQ

### Q1 : Puis-je utiliser plusieurs options en même temps ?

**Oui !** Par exemple :
- SMTP pour authentification (Supabase Auth)
- Resend pour notifications (Edge Functions)

---

### Q2 : Quelle option est la plus fiable ?

**Resend > SMTP > Mailu** (en termes de délivrabilité)

Mailu nécessite configuration parfaite pour ne pas aller en spam.

---

### Q3 : Combien coûte chaque option par mois ?

| Option | 0-3000 emails | 3000-10k | 10k-50k |
|--------|---------------|----------|---------|
| SMTP (Gmail) | Gratuit | Gratuit* | Impossible |
| Resend | Gratuit | $20/mois | $20/mois |
| Mailu | Gratuit | Gratuit | Gratuit |

*Gmail = max 500/jour = 15k/mois théorique

---

### Q4 : Puis-je migrer d'une option à l'autre ?

**Oui**, facilement :
- SMTP → Resend : Lancer `02-resend-setup.sh`
- Resend → Mailu : Lancer `03-mailu-wrapper.sh`
- Retour arrière : Relancer script précédent avec `--force`

---

### Q5 : Quelle option consomme le plus de ressources ?

- **SMTP** : 0 MB RAM (utilise Gmail)
- **Resend** : ~50 MB RAM (Edge Function)
- **Mailu** : 2-3 GB RAM (serveur complet)

---

### Q6 : Comment tester ma configuration ?

```bash
# Test universel (auto-détecte la config)
sudo bash /path/to/scripts/99-email-test.sh your@email.com

# Test spécifique
sudo bash /path/to/scripts/99-email-test.sh --smtp your@email.com
sudo bash /path/to/scripts/99-email-test.sh --resend your@email.com
```

---

## 🎓 Ressources Complémentaires

### Documentation Officielle

- **SMTP** : [Nodemailer](https://nodemailer.com/)
- **Resend** : [resend.com/docs](https://resend.com/docs)
- **Mailu** : [mailu.io/master](https://mailu.io/master/)

### Outils de Test

- **Mail Tester** : [mail-tester.com](https://www.mail-tester.com) (score spam)
- **MX Toolbox** : [mxtoolbox.com](https://mxtoolbox.com) (DNS check)
- **DKIM Validator** : [dkimvalidator.com](https://dkimvalidator.com)

### Communautés

- **PI5-SETUP** : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- **Resend Discord** : [discord.gg/resend](https://discord.gg/resend)
- **Mailu Matrix** : [#mailu:matrix.org](https://matrix.to/#/#mailu:matrix.org)

---

## 🎯 Checklist de Progression

### Débutant
- [ ] Comprendre les 3 options
- [ ] Installer SMTP avec Gmail
- [ ] Envoyer un email de test
- [ ] Utiliser dans une app simple

### Intermédiaire
- [ ] Créer compte Resend
- [ ] Configurer domaine personnalisé
- [ ] Utiliser Edge Functions
- [ ] Analyser statistiques d'envoi

### Avancé
- [ ] Installer Mailu complet
- [ ] Configurer DNS (MX, SPF, DKIM, DMARC)
- [ ] Atteindre score 10/10 sur mail-tester
- [ ] Gérer boîtes mail multiples
- [ ] Mettre en place backups

---

## 📝 Conclusion

### Récapitulatif

| Votre Situation | Recommandation |
|-----------------|----------------|
| Je débute, je veux du simple | **SMTP (Gmail)** |
| J'ai une app SaaS moderne | **Resend API** |
| Je veux apprendre le self-hosting | **Mailu** |
| Budget zéro strict | **SMTP** puis **Mailu** |
| Je veux des analytics | **Resend API** |
| > 10 000 emails/mois | **Mailu** |

### Prochaines Étapes

1. **Installer** : Lancer `00-email-setup-wizard.sh`
2. **Tester** : Envoyer un email de test
3. **Intégrer** : Utiliser dans votre application
4. **Optimiser** : Monitorer et ajuster

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-11
**Auteur** : PI5-SETUP Project

---

[← Retour README](README.md) | [Installation →](00-email-setup-wizard.sh) | [Troubleshooting →](docs/TROUBLESHOOTING.md)
