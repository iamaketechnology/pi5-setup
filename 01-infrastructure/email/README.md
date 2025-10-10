# 📧 Email Server Stack - Mailu

> **Hébergez votre propre serveur email complet sur Raspberry Pi 5**

[![Statut](https://img.shields.io/badge/statut-production-green.svg)](.)
[![ARM64](https://img.shields.io/badge/ARM64-compatible-blue.svg)](.)
[![RAM](https://img.shields.io/badge/RAM-2--3GB-orange.svg)](.)

**Version** : 1.0.0 (Mailu 2024.06)
**Difficulté** : ⭐⭐⭐ Avancé (Configuration DNS requise)
**Temps d'installation** : 15-30 minutes (script) + 1-2h (DNS/tests)
**RAM requise** : 2 GB minimum, 3 GB avec antivirus

---

## ⚠️ Avertissement Important

**Héberger un serveur email est COMPLEXE**. Avant de commencer :

- ❌ **PAS pour débutants** - Requiert connaissances DNS, SMTP, sécurité
- ✅ **Configuration DNS obligatoire** - MX, SPF, DKIM, DMARC
- ✅ **IP publique statique recommandée** - Ou DynDNS fiable
- ✅ **Ports 25, 465, 587 ouverts** - Configuration box Internet
- ✅ **Maintenance régulière** - Mises à jour sécurité, monitoring

**Alternative recommandée pour débutants** :
- Utiliser Gmail/ProtonMail/Fastmail
- Ou service managé comme Migadu, mailbox.org

**Ce guide est pour** :
- Apprendre comment fonctionne l'email
- Contrôle total de ses données
- Usage personnel/famille (5-30 boîtes)
- Éviter dépendance Gmail/Outlook

---

## 📋 Vue d'Ensemble

### Qu'est-ce que Mailu ?

Mailu est une **solution email complète** open-source qui inclut :

- 📬 **Serveur SMTP** (Postfix) - Envoi/réception emails
- 📥 **Serveur IMAP/POP3** (Dovecot) - Accès boîtes mail
- 🌐 **Webmail** (Roundcube) - Interface web type Gmail
- 🛡️ **Anti-spam** (Rspamd) - Filtrage intelligent
- 🦠 **Antivirus** (ClamAV, optionnel) - Protection malwares
- ⚙️ **Admin UI** - Gestion utilisateurs/domaines
- 🔐 **DKIM/SPF/DMARC** - Authentification emails

**Tout-en-un**, optimisé pour ARM64, conteneurisé avec Docker.

### Pourquoi Mailu ?

| Critère | Mailu | Docker Mailserver | mailcow |
|---------|-------|-------------------|---------|
| **RAM** | 2 GB | 2-3 GB | 4-6 GB |
| **Difficulté** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **Interface Admin** | ✅ Moderne | ❌ CLI | ✅ Complète |
| **ARM64** | ✅ Natif | ✅ Natif | ✅ Depuis 2023 |
| **Pi5 8GB** | ✅ OK | ✅ OK | ⚠️ Limite |

**Choix pour Pi5** : Mailu = meilleur compromis légèreté/features.

---

## 🎯 Cas d'Usage

### Personnel
- ✅ Email famille (vous@votredomaine.fr)
- ✅ Indépendance Gmail/Outlook
- ✅ Données sous contrôle
- ✅ Alias illimités

### Professionnel
- ✅ Email entreprise (contact@startup.com)
- ✅ 5-30 employés
- ✅ Domaines multiples
- ✅ Économies (~15€/mois/utilisateur vs G Suite)

### Apprentissage
- ✅ Comprendre protocoles email
- ✅ Apprendre DNS/sécurité
- ✅ Self-hosting avancé

---

## ⚡ Installation Rapide

### Prérequis Absolus

1. **Nom de domaine** (acheté, ex: `mondomaine.fr`)
2. **Accès DNS** (pouvoir créer MX/A/TXT records)
3. **Pi5 avec 8GB+ RAM** minimum
4. **IP publique** accessible ports 25, 465, 587, 993
5. **Reverse DNS configuré** (optionnel mais recommandé)

### Commande d'Installation

```bash
sudo MAILU_DOMAIN=mondomaine.fr \
     MAILU_ADMIN_EMAIL=admin@mondomaine.fr \
     MAILU_ADMIN_PASSWORD='VotreMotDePasseSecure123!' \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/01-mailu-deploy.sh)
```

**Durée** : 15-20 minutes (pull images Docker)

### Variables Optionnelles

```bash
# Désactiver webmail (Roundcube)
ENABLE_WEBMAIL=no

# Activer antivirus (ClamAV, +1GB RAM)
ENABLE_ANTIVIRUS=yes

# Changer hostname
MAILU_HOSTNAME=mail  # Défaut: mail → mail.mondomaine.fr

# Version Mailu
MAILU_VERSION=2024.06  # Défaut: 2024.06
```

---

## 📁 Structure Installée

```
/home/pi/stacks/mailu/
├── docker-compose.yml          # Configuration services
├── mailu.env                   # Variables Mailu
├── README.md                   # Guide rapide auto-généré
├── data/                       # Données persistantes
│   ├── mail/                   # Emails stockés
│   ├── dkim/                   # Clés DKIM
│   ├── certs/                  # Certificats SSL
│   └── ...
├── overrides/                  # Configurations custom
├── dkim/                       # Clés DKIM publiques
└── backups/                    # Sauvegardes config
```

---

## 🌐 Interfaces Web

### Admin Panel

**URL** : `https://mail.mondomaine.fr/admin`

**Login** : `admin@mondomaine.fr` (défini à l'installation)

**Fonctionnalités** :
- Créer/gérer utilisateurs
- Créer/gérer domaines
- Créer alias (redirection emails)
- Voir statistiques
- Configurer anti-spam
- Gérer quotas

### Webmail (Roundcube)

**URL** : `https://mail.mondomaine.fr/webmail`

**Login** : `utilisateur@mondomaine.fr` + mot de passe

**Interface type Gmail** :
- Lire/envoyer emails
- Dossiers (Inbox, Sent, Spam, Trash)
- Contacts
- Calendrier (optionnel)
- Filtres

---

## 📬 Configuration Clients Email

### Paramètres Génériques

**Serveur Entrant (IMAP)** :
- Serveur : `mail.mondomaine.fr`
- Port : `993`
- Sécurité : SSL/TLS
- Username : `vous@mondomaine.fr`
- Password : (votre mot de passe)

**Serveur Sortant (SMTP)** :
- Serveur : `mail.mondomaine.fr`
- Port : `587` (STARTTLS) ou `465` (SSL/TLS)
- Sécurité : STARTTLS ou SSL/TLS
- Authentification : Oui
- Username : `vous@mondomaine.fr`
- Password : (votre mot de passe)

### Guides Par Client

- [Thunderbird](docs/CLIENT-SETUP.md#thunderbird)
- [Apple Mail (iOS/macOS)](docs/CLIENT-SETUP.md#apple-mail)
- [Gmail App](docs/CLIENT-SETUP.md#gmail-app)
- [Outlook](docs/CLIENT-SETUP.md#outlook)
- [Android Mail](docs/CLIENT-SETUP.md#android)

---

## 🌍 Configuration DNS (CRITIQUE)

**⚠️ Sans DNS correct, votre serveur ne fonctionnera PAS**

### Records Obligatoires

#### 1. A Record (IPv4)
```
mail.mondomaine.fr  →  [IP_PUBLIQUE_PI]
```

#### 2. MX Record (Mail Exchange)
```
mondomaine.fr  →  mail.mondomaine.fr  (priority 10)
```

#### 3. SPF Record (Sender Policy Framework)
```
Type: TXT
Nom: mondomaine.fr
Valeur: v=spf1 mx ~all
```

#### 4. DKIM Record (DomainKeys Identified Mail)

**Générer après installation** :
```bash
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu config-export --format=dkim
```

**Copier sortie vers DNS** :
```
Type: TXT
Nom: dkim._domainkey.mondomaine.fr
Valeur: v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3...
```

#### 5. DMARC Record (Domain-based Message Authentication)
```
Type: TXT
Nom: _dmarc.mondomaine.fr
Valeur: v=DMARC1; p=quarantine; rua=mailto:admin@mondomaine.fr; pct=100
```

### Vérification DNS

```bash
# Tester MX record
dig MX mondomaine.fr

# Tester A record
dig mail.mondomaine.fr

# Tester SPF
dig TXT mondomaine.fr

# Tester DKIM
dig TXT dkim._domainkey.mondomaine.fr
```

**Outils en ligne** :
- https://mxtoolbox.com - Test complet DNS/email
- https://www.mail-tester.com - Score spam (objectif: 10/10)
- https://dkimvalidator.com - Validation DKIM

**Guide détaillé** : [docs/DNS-SETUP.md](docs/DNS-SETUP.md)

---

## 🔧 Post-Installation

### 1. Créer Premier Utilisateur

**Via Admin UI** :
1. Login admin : `https://mail.mondomaine.fr/admin`
2. Onglet "Mail domains" → Cliquer sur domaine
3. "Users" → "Add user"
4. Email: `jean@mondomaine.fr`, Password, Quota
5. Save

**Via CLI** :
```bash
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu user jean mondomaine.fr 'MotDePasse123'
```

### 2. Générer et Configurer DKIM

```bash
# Générer clé DKIM
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu config-export --format=dkim

# Copier sortie dans DNS (voir ci-dessus)

# Attendre propagation DNS (5-30 minutes)
dig TXT dkim._domainkey.mondomaine.fr
```

### 3. Tester Envoi/Réception

**Test envoi** :
1. Login webmail : `https://mail.mondomaine.fr/webmail`
2. Envoyer email vers Gmail/Outlook
3. Vérifier réception (inbox, pas spam)

**Test réception** :
1. Depuis Gmail, envoyer vers `vous@mondomaine.fr`
2. Vérifier réception dans webmail

**Test spam score** :
1. Envoyer email vers `check-auth@verifier.port25.com`
2. Lire réponse (rapport SPF/DKIM/DMARC)

---

## 🔗 Intégration Traefik (Optionnel)

### Pourquoi Intégrer ?

- ✅ HTTPS pour admin/webmail via Traefik
- ✅ Sous-domaine propre (mail.mondomaine.fr)
- ✅ Centralisation certificats

**Note** : Ports SMTP/IMAP restent directs (25, 465, 587, 993)

### Installation

```bash
# Si Traefik pas installé, choisir un scénario
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-cloudflare.sh | sudo bash

# Puis intégrer Mailu
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/02-integrate-traefik.sh | sudo bash
```

**Résultat** :
- `https://mail.mondomaine.fr/admin` → Admin UI (via Traefik)
- `https://mail.mondomaine.fr/webmail` → Webmail (via Traefik)
- SMTP/IMAP : Connexion directe (comme avant)

---

## 📊 Commandes Utiles

### Gestion Services

```bash
cd /home/pi/stacks/mailu

# Voir tous les containers
docker compose ps

# Voir logs (tous services)
docker compose logs -f

# Voir logs service spécifique
docker compose logs -f postfix   # SMTP
docker compose logs -f dovecot   # IMAP
docker compose logs -f rspamd    # Anti-spam
docker compose logs -f webmail   # Roundcube

# Restart service
docker compose restart postfix

# Restart tous services
docker compose restart

# Stop tout
docker compose down

# Start tout
docker compose up -d
```

### Gestion Utilisateurs (CLI)

```bash
cd /home/pi/stacks/mailu

# Créer utilisateur
docker compose exec admin flask mailu user jean mondomaine.fr 'password'

# Créer admin
docker compose exec admin flask mailu admin marie mondomaine.fr 'password'

# Lister utilisateurs
docker compose exec admin flask mailu users mondomaine.fr

# Supprimer utilisateur
docker compose exec admin flask mailu user-delete jean mondomaine.fr

# Changer password
docker compose exec admin flask mailu user-password jean mondomaine.fr 'newpassword'
```

### Alias

```bash
# Créer alias (contact@ → jean@)
docker compose exec admin flask mailu alias contact mondomaine.fr jean@mondomaine.fr

# Lister alias
docker compose exec admin flask mailu aliases mondomaine.fr
```

### Maintenance

```bash
# Voir espace disque utilisé
du -sh /home/pi/stacks/mailu/data/

# Purger emails spam > 30 jours (Dovecot)
docker compose exec dovecot doveadm expunge -A mailbox Junk savedbefore 30d

# Nettoyer logs
truncate -s 0 /home/pi/stacks/mailu/data/logs/*.log
```

---

## 🛡️ Sécurité & Anti-Spam

### Rspamd (Anti-spam intégré)

**Interface Web** : `http://mail.mondomaine.fr:11334`

**Fonctionnalités** :
- Analyse bayésienne
- Filtres règles multiples
- Whitelist/Blacklist
- Scoring automatique

**Configuration** :
```bash
# Voir config actuelle
docker compose exec rspamd rspamadm configdump

# Entraîner sur spam
# (marquer emails comme spam dans webmail)
```

### Fail2ban (Protection brute-force)

**Inclus dans Mailu**, monitore :
- Login webmail (10 tentatives = ban 1h)
- Login IMAP/SMTP
- Regex logs Postfix/Dovecot

**Voir bans actifs** :
```bash
docker compose exec front fail2ban-client status
```

### ClamAV (Antivirus)

**Si activé** (`ENABLE_ANTIVIRUS=yes`) :
- Scan pièces jointes automatique
- Rejet emails avec virus
- +1GB RAM utilisée

**Vérifier status** :
```bash
docker compose logs clamav
```

### Recommandations

- ✅ Mots de passe forts (16+ caractères)
- ✅ 2FA pour admin (via Authelia si intégré)
- ✅ Quotas par utilisateur (limiter spam sortant)
- ✅ Monitoring logs régulier
- ✅ Mises à jour Mailu (suivi releases)
- ✅ Backup hebdomadaire (data/ folder)

---

## 📈 Monitoring

### Métriques à Surveiller

**Via Admin UI** :
- Nombre emails envoyés/reçus
- Taille boîtes mail (quotas)
- Score spam moyen
- Rejets (spam détecté)

**Via Ligne de Commande** :
```bash
# Queue emails sortants
docker compose exec postfix postqueue -p

# Statistiques Postfix
docker compose exec postfix pflogsumm -d today /var/log/mail.log

# Statistiques Dovecot
docker compose exec dovecot doveadm stats dump
```

### Intégration Grafana/Prometheus

**Optionnel**, voir stack monitoring :
- Métriques temps réel
- Alertes (queue pleine, disk full)
- Dashboards

---

## 🔄 Backup & Restore

### Backup Manuel

```bash
# Arrêter services
cd /home/pi/stacks/mailu
docker compose down

# Backup data folder
sudo tar -czf mailu-backup-$(date +%Y%m%d).tar.gz data/

# Restart services
docker compose up -d

# Upload backup offsite (optionnel)
rclone copy mailu-backup-*.tar.gz cloudflare-r2:backups/mailu/
```

### Backup Automatique

**Via cron** :
```bash
# Éditer crontab
crontab -e

# Ajouter backup hebdomadaire (dimanche 3h)
0 3 * * 0 cd /home/pi/stacks/mailu && docker compose down && tar -czf /home/pi/backups/mailu-$(date +\%Y\%m\%d).tar.gz data/ && docker compose up -d
```

### Restore

```bash
# Stop services
cd /home/pi/stacks/mailu
docker compose down

# Supprimer data actuel
rm -rf data/

# Extraire backup
tar -xzf mailu-backup-20250106.tar.gz

# Restart
docker compose up -d
```

---

## ❓ Troubleshooting

### Emails envoyés vont en spam

**Causes** :
- ❌ SPF/DKIM/DMARC mal configurés
- ❌ IP blacklistée
- ❌ Reverse DNS absent

**Solutions** :
```bash
# Tester configuration
https://www.mail-tester.com
# Objectif: Score 10/10

# Vérifier IP blacklistée
https://mxtoolbox.com/blacklists.aspx

# Configurer reverse DNS
# (contacter FAI/hébergeur)
```

### Emails non reçus

**Causes** :
- ❌ MX record incorrect
- ❌ Port 25 bloqué par FAI
- ❌ Firewall/NAT mal configuré

**Solutions** :
```bash
# Tester MX
dig MX mondomaine.fr

# Tester port 25 accessible
telnet mail.mondomaine.fr 25

# Voir logs Postfix
docker compose logs postfix | grep "reject\|error"
```

### "Relay access denied"

**Cause** : Authentification SMTP échouée

**Solution** :
```bash
# Vérifier credentials client email
# Username = email complet (jean@mondomaine.fr)
# Password = correct

# Voir logs
docker compose logs postfix | grep "authentication"
```

### Webmail inaccessible

**Solutions** :
```bash
# Vérifier container running
docker compose ps | grep webmail

# Restart webmail
docker compose restart webmail

# Voir logs
docker compose logs webmail
```

### RAM insuffisante

**Solutions** :
```bash
# Désactiver ClamAV
# Éditer mailu.env: ANTIVIRUS=none
docker compose down && docker compose up -d

# Ou upgrade vers Pi5 16GB
```

---

## 📚 Documentation Complémentaire

- **[Guide Débutant](email-guide.md)** - Tutoriel complet avec analogies
- **[Configuration DNS](docs/DNS-SETUP.md)** - Guide détaillé MX/SPF/DKIM/DMARC
- **[Configuration Clients](docs/CLIENT-SETUP.md)** - Thunderbird, iOS, Android
- **[Anti-Spam](docs/ANTI-SPAM.md)** - Optimisation Rspamd
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Problèmes courants

### Ressources Externes

- [Mailu Documentation](https://mailu.io/master/)
- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Documentation](https://doc.dovecot.org/)
- [Email Testing Tools](https://www.mail-tester.com)

---

## 💰 Coûts Comparatifs

### Self-hosted (Mailu)

- **Domaine** : ~10€/an (Namecheap, OVH)
- **Pi5 8GB** : ~80€ (one-time)
- **Électricité** : ~2€/mois
- **Total première année** : ~104€ (10 utilisateurs)
- **Années suivantes** : ~34€/an

### Gmail Workspace

- **5 utilisateurs** : 5 × 5.60€ = **28€/mois** = **336€/an**
- **10 utilisateurs** : 10 × 5.60€ = **56€/mois** = **672€/an**

### Économies

- **10 utilisateurs** : ~570€/an économisés
- **ROI** : 2-3 mois

---

## 🆘 Support

- **Issues** : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- **Documentation** : [PI5-SETUP](https://github.com/iamaketechnology/pi5-setup)
- **Mailu Community** : [GitHub Discussions](https://github.com/Mailu/Mailu/discussions)

---

## 🎯 Roadmap

- [ ] Support Docker Mailserver (alternatif)
- [ ] Support mailcow (pour Pi5 16GB)
- [ ] Auto-configuration clients (Autoconfig/Autodiscover)
- [ ] Calendrier/Contacts (CalDAV/CardDAV)
- [ ] Backup automatique vers cloud
- [ ] Migration assistant (depuis Gmail/Outlook)

---

**Version** : 1.0.0 (Mailu 2024.06)
**Dernière mise à jour** : 2025-10-06
**Auteur** : PI5-SETUP Project

---

[← Retour Infrastructure](../) | [Guide Débutant →](email-guide.md) | [DNS Setup →](docs/DNS-SETUP.md)
