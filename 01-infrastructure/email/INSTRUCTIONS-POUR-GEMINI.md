# 📧 INSTRUCTIONS POUR GEMINI - DOCUMENTATION PI5-EMAIL-STACK

> **Objectif** : Générer la documentation complète pour la stack email (Roundcube + mail servers)

---

## 🎯 CONTEXTE

**Stack** : pi5-email-stack
**Version** : 1.0.0
**Composants** :
- **Scénario 1 (External)** : Roundcube + PostgreSQL → fournisseur mail externe (Gmail, Outlook, Proton)
- **Scénario 2 (Full)** : Roundcube + Postfix + Dovecot + Rspamd + PostgreSQL (serveur mail complet)

**Public cible** : Débutants à intermédiaires en self-hosting
**Philosophie** : Installation curl one-liner, pédagogique, français

---

## 📂 FICHIERS À GÉNÉRER

### 1. README.md (800-1200 lignes)

**Contenu obligatoire** :
```markdown
# 📧 PI5-EMAIL-STACK - Webmail et Serveur Mail Self-Hosted

## Vue d'ensemble
[Description des 2 scénarios, tableau comparatif]

## Caractéristiques
[Features principales par scénario]

## Architecture
[Diagrammes ASCII des 2 scénarios]

## Prérequis
[Docker, Traefik, domaine (pour scénario 2)]

## Installation rapide
[Commandes curl pour les 2 scénarios]

## Composants
[Description détaillée: Roundcube, Postfix, Dovecot, Rspamd]

## Configuration
[Variables .env, fichiers config]

## Maintenance
[Scripts disponibles: backup, restore, healthcheck, update, logs]

## Sécurité
[SPF, DKIM, DMARC, TLS, authentification]

## Monitoring
[Intégration Grafana/Prometheus]

## Troubleshooting
[Problèmes courants + solutions]

## Ressources
[Liens utiles]
```

**Style** : Technique mais accessible, exemples concrets, tableaux comparatifs

---

### 2. GUIDE-DEBUTANT.md (1500-2000 lignes)

**Template** : `.templates/GUIDE-DEBUTANT-TEMPLATE.md`

**Sections obligatoires** :

#### Introduction
- Analogie simple : "Roundcube = Gmail que vous contrôlez"
- "Serveur mail = bureau de poste personnel"

#### Pourquoi cette stack ?
- 3-5 use cases concrets :
  - Débutant : Interface web pour consulter emails existants (Gmail, Outlook)
  - Créateur de contenu : Emails personnalisés avec son propre domaine
  - Entrepreneur : Communication professionnelle indépendante
  - Famille : Adresses email familiales (@famille-dupont.com)
  - Privacy-conscious : Contrôle total de ses données

#### Concepts clés expliqués simplement
- **Webmail** : Interface web pour lire/écrire emails (vs client lourd Thunderbird)
- **IMAP/SMTP** : Protocoles de réception/envoi (analogie : boîte aux lettres / bureau de poste)
- **MX/SPF/DKIM/DMARC** : Records DNS (analogie : carte d'identité du serveur mail)
- **Postfix** : Le facteur (distribue le courrier)
- **Dovecot** : Le casier (stocke les emails)
- **Rspamd** : Le filtre anti-spam (garde du bureau de poste)

#### Choisir son scénario

**Tableau de décision** :
| Critère | Scénario 1 (External) | Scénario 2 (Full) |
|---------|----------------------|-------------------|
| Niveau | ⭐ Débutant | ⭐⭐⭐ Avancé |
| Coût | Gratuit | 10-20€/an (domaine) |
| Domaine requis | Non | Oui (obligatoire) |
| DNS complexe | Non | Oui (MX, SPF, DKIM, DMARC) |
| Emails custom | Non (@gmail.com) | Oui (@ton-domaine.com) |
| Contrôle total | Non (Google/MS) | Oui (100%) |
| Maintenance | Facile | Moyenne |
| Risque spam | Aucun | Moyen (config requise) |

**Recommandation** :
- Débuter avec **Scénario 1** pour tester Roundcube
- Passer au **Scénario 2** si besoin d'emails personnalisés

#### Tutoriel pas-à-pas : Scénario 1 (External)

**Étape 1 : Prérequis**
```bash
# Vérifier Docker
docker --version

# Vérifier Traefik
docker ps | grep traefik
```

**Étape 2 : Déploiement**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-external.sh | sudo bash
```

**Captures d'écran décrites** :
- "Vous verrez : 'Select your email provider: 1) Gmail...'"
- "Tapez 1 et appuyez sur Entrée pour Gmail"
- "Entrez votre domaine : mail.votredomaine.com"
- "Attendez... vous verrez : ✅ Deployment completed successfully!"

**Étape 3 : Configuration Gmail**
- Activer 2FA : https://myaccount.google.com/security
- Créer App Password : https://myaccount.google.com/apppasswords
- Copier le mot de passe (16 caractères)

**Étape 4 : Première connexion**
- Ouvrir : https://mail.votredomaine.com
- Username : votre-email@gmail.com
- Password : le mot de passe App Password (PAS votre mot de passe normal)

**Résultat attendu** :
- Interface Roundcube (capture décrite)
- Emails Gmail visibles
- Possibilité d'envoyer/recevoir

#### Tutoriel pas-à-pas : Scénario 2 (Full)

**Étape 0 : Prérequis critiques**
- Posséder un domaine (ex: Namecheap, OVH, Gandi)
- Accès aux DNS du domaine
- Port 25 ouvert chez votre FAI (tester : telnet smtp.gmail.com 25)

**Étape 1 : Préparer DNS (AVANT déploiement)**

Ajouter ces records dans votre registrar :

```
# A Record (obligatoire)
mail.votredomaine.com  A  192.168.1.100  # IP publique de votre Pi

# MX Record (obligatoire)
votredomaine.com  MX  10  mail.votredomaine.com

# SPF Record (obligatoire)
votredomaine.com  TXT  "v=spf1 mx ~all"
```

**Vérifier propagation** :
```bash
dig mail.votredomaine.com A
dig votredomaine.com MX
```

**Étape 2 : Déploiement**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-email-stack/scripts/01-roundcube-deploy-full.sh | sudo bash
```

**Interaction avec le script** :
1. "Enter your domain: votredomaine.com"
2. Script vérifie DNS automatiquement
3. "Use SMTP relay? [y/N]:" → Taper N pour débuter (direct send)
4. Script génère clés DKIM

**Étape 3 : Ajouter DKIM et DMARC**

Le script affiche :
```
⚠️  CRITICAL: ADD THESE DNS RECORDS NOW

1. DKIM Record:
   dkim._domainkey.votredomaine.com TXT "v=DKIM1; k=rsa; p=MIGfMA0GCS..."
```

**Copier-coller exactement** ce TXT dans votre DNS provider.

Ajouter aussi DMARC :
```
_dmarc.votredomaine.com  TXT  "v=DMARC1; p=quarantine; rua=mailto:postmaster@votredomaine.com"
```

**Attendre 15-30 min** (propagation DNS).

**Étape 4 : Créer premier utilisateur**

```bash
# Se connecter à la DB
docker exec -it mail-db psql -U mailuser mailserver

# Créer utilisateur
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
    (SELECT id FROM virtual_domains WHERE name = 'votredomaine.com'),
    'admin@votredomaine.com',
    crypt('MonMotDePasse123', gen_salt('bf'))
);
```

**Étape 5 : Tester**

1. Connexion Roundcube : https://mail.votredomaine.com
   - User : admin@votredomaine.com
   - Pass : MonMotDePasse123

2. Envoyer email test vers Gmail
3. Vérifier score spam : https://www.mail-tester.com
   - Objectif : 8-10/10

#### Troubleshooting débutants

**Scénario 1 : Problèmes courants**

| Erreur | Cause | Solution |
|--------|-------|----------|
| "Authentication failed" | Mot de passe incorrect | Utiliser App Password, pas mot de passe normal |
| "Cannot connect to IMAP" | Gmail IMAP désactivé | Activer IMAP : Gmail Settings > Forwarding and POP/IMAP |
| "502 Bad Gateway" | Traefik non démarré | docker ps \| grep traefik → Déployer Traefik d'abord |

**Scénario 2 : Problèmes courants**

| Erreur | Cause | Solution |
|--------|-------|----------|
| "Relay access denied" | DNS MX manquant | Vérifier : dig votredomaine.com MX |
| Emails en spam | SPF/DKIM/DMARC manquants | Vérifier présence des 3 TXT records |
| "Connection refused port 25" | FAI bloque port 25 | Utiliser SMTP relay (SendGrid, Mailgun) |
| "DKIM verification failed" | Mauvaise copie TXT | Copier DKIM record sans espaces/retours ligne |

#### Checklist de progression

**Niveau Débutant** ✅
- [ ] Déployer Scénario 1 avec Gmail
- [ ] Se connecter à Roundcube
- [ ] Envoyer/recevoir emails via Gmail
- [ ] Comprendre différence IMAP/SMTP

**Niveau Intermédiaire** 🔄
- [ ] Acheter un domaine
- [ ] Configurer DNS (A, MX, SPF)
- [ ] Déployer Scénario 2
- [ ] Ajouter DKIM/DMARC
- [ ] Créer utilisateurs manuellement

**Niveau Avancé** 🚀
- [ ] Configurer SMTP relay (SendGrid)
- [ ] Score mail-tester.com > 8/10
- [ ] Automatiser création utilisateurs (script)
- [ ] Intégrer monitoring (Grafana dashboard)
- [ ] Backup/restore automatique

#### Ressources d'apprentissage

**Vidéos** :
- "How email works" - Hussein Nasser (YouTube)
- "Self-hosting email server 2024" - Techno Tim

**Documentation** :
- Roundcube : https://roundcube.net/
- Postfix : http://www.postfix.org/documentation.html
- DKIM/SPF/DMARC : https://www.cloudflare.com/learning/dns/dns-records/

**Communautés** :
- r/selfhosted (Reddit)
- Homelab Discord
- Forum Yunohost (français)

**Outils de test** :
- https://www.mail-tester.com (score spam)
- https://mxtoolbox.com (DNS/MX checker)
- https://dkimvalidator.com (DKIM validator)

---

### 3. INSTALL.md (800-1000 lignes)

**Contenu** :

#### Installation Scénario 1 (External)

**Prérequis détaillés** :
- Raspberry Pi 5 (4GB+ RAM)
- Docker 24+
- Docker Compose 2.20+
- Traefik déployé
- Compte email existant (Gmail/Outlook/Proton)

**Installation automatique** :
```bash
curl -fsSL https://raw.githubusercontent.com/.../01-roundcube-deploy-external.sh | sudo bash
```

**Installation manuelle** (si besoin) :
```bash
# 1. Cloner repo
git clone https://github.com/iamaketechnology/pi5-setup
cd pi5-setup/pi5-email-stack

# 2. Configurer .env
cp .env.example .env
nano .env  # Éditer MAIL_DOMAIN, IMAP_HOST, SMTP_HOST

# 3. Déployer
docker-compose -f compose/docker-compose-external.yml up -d

# 4. Vérifier santé
docker ps
docker logs roundcube
```

**Configuration providers** :

**Gmail** :
```env
IMAP_HOST=ssl://imap.gmail.com
IMAP_PORT=993
SMTP_HOST=tls://smtp.gmail.com
SMTP_PORT=587
```
Setup : https://support.google.com/mail/answer/7126229

**Outlook** :
```env
IMAP_HOST=ssl://outlook.office365.com
IMAP_PORT=993
SMTP_HOST=tls://smtp.office365.com
SMTP_PORT=587
```

**Proton Mail** (nécessite Proton Bridge) :
```env
IMAP_HOST=127.0.0.1
IMAP_PORT=1143
SMTP_HOST=127.0.0.1
SMTP_PORT=1025
```
Installer Bridge : https://proton.me/mail/bridge

**Vérification post-installation** :
```bash
# Santé containers
docker ps --filter "name=roundcube"

# Logs
docker logs roundcube
docker logs roundcube-db

# Test HTTP
curl -I http://localhost:8080

# Test HTTPS (via Traefik)
curl -I https://mail.votredomaine.com
```

#### Installation Scénario 2 (Full)

**Prérequis détaillés** :
- Tous les prérequis Scénario 1 +
- **Domaine acheté** (Namecheap, Gandi, OVH, etc.)
- **Accès DNS** avec support TXT records
- **Port 25 ouvert** (vérifier : `telnet smtp.gmail.com 25`)
- **IP statique** ou DynDNS
- Min 8GB RAM (serveur mail = gourmand)

**⚠️ Vérifications critiques AVANT installation** :

```bash
# 1. Port 25 ouvert ?
telnet smtp.gmail.com 25
# Si connexion OK → Port ouvert ✅
# Si timeout → Port bloqué ❌ (contacter FAI ou utiliser relay)

# 2. DNS propagé ?
dig mail.votredomaine.com A
# Doit retourner IP publique du Pi

dig votredomaine.com MX
# Doit retourner : 10 mail.votredomaine.com

# 3. Résolution inverse (important pour réputation)
dig -x VOTRE_IP_PUBLIQUE
# Devrait idéalement pointer vers mail.votredomaine.com
# Configurer via FAI/VPS provider
```

**Installation automatique** :
```bash
curl -fsSL https://raw.githubusercontent.com/.../01-roundcube-deploy-full.sh | sudo bash
```

**Ce que fait le script** :
1. Vérifie dépendances (Docker, dig, openssl)
2. Demande domaine
3. Vérifie DNS A/MX/SPF
4. Génère clés DKIM (2048-bit RSA)
5. Demande config SMTP relay (optionnel)
6. Génère .env
7. Crée configs Postfix/Dovecot/Rspamd/Roundcube
8. Déploie stack Docker Compose
9. Affiche records DKIM/DMARC à ajouter

**Configuration DNS post-installation** :

Le script affiche :
```
⚠️  CRITICAL: ADD THESE DNS RECORDS NOW

1. DKIM Record (copy exactly):
   dkim._domainkey.votredomaine.com TXT "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBA..."

2. DMARC Record:
   _dmarc.votredomaine.com TXT "v=DMARC1; p=quarantine; rua=mailto:postmaster@votredomaine.com"
```

**Ajouter dans votre DNS provider** :

**Namecheap** :
1. Advanced DNS
2. Add New Record → TXT Record
3. Host : `dkim._domainkey`
4. Value : `v=DKIM1; k=rsa; p=...` (copier-coller exactement)
5. TTL : Automatic
6. Répéter pour DMARC (_dmarc)

**Cloudflare** :
1. DNS → Add record
2. Type : TXT
3. Name : `dkim._domainkey`
4. Content : `v=DKIM1; k=rsa; p=...`
5. TTL : Auto

**Vérifier propagation** (15-30 min) :
```bash
dig dkim._domainkey.votredomaine.com TXT
dig _dmarc.votredomaine.com TXT
```

**Gestion des utilisateurs** :

**Créer utilisateur via script** (TODO: à implémenter) :
```bash
sudo bash scripts/utils/create-email-user.sh admin@votredomaine.com
# Demande mot de passe
# Créé entrée dans PostgreSQL
```

**Créer utilisateur manuellement** :
```bash
docker exec -it mail-db psql -U mailuser mailserver

# Créer utilisateur
INSERT INTO virtual_users (domain_id, email, password)
VALUES (
    (SELECT id FROM virtual_domains WHERE name = 'votredomaine.com'),
    'user@votredomaine.com',
    crypt('MotDePasse123', gen_salt('bf'))
);

# Lister utilisateurs
SELECT email FROM virtual_users;

# Supprimer utilisateur
DELETE FROM virtual_users WHERE email = 'user@votredomaine.com';
```

**Créer alias** :
```sql
INSERT INTO virtual_aliases (domain_id, source, destination)
VALUES (
    (SELECT id FROM virtual_domains WHERE name = 'votredomaine.com'),
    'contact@votredomaine.com',
    'admin@votredomaine.com'
);
```

**Tests de délivrabilité** :

**1. Test envoi email** :
- Connecter Roundcube : https://mail.votredomaine.com
- Envoyer email à votre Gmail personnel
- Vérifier arrivée (inbox, pas spam)

**2. Score spam (mail-tester.com)** :
1. Aller sur https://www.mail-tester.com
2. Noter l'adresse test affichée : `test-xxxxx@srv1.mail-tester.com`
3. Depuis Roundcube, envoyer email vers cette adresse
4. Rafraîchir page mail-tester
5. Score affiché (objectif : 8-10/10)

**Interprétation score** :
- **10/10** : Configuration parfaite ✅
- **8-9/10** : Bon, acceptable ✅
- **6-7/10** : Moyen, améliorer DKIM/SPF ⚠️
- **<6/10** : Mauvais, emails iront en spam ❌

**Problèmes courants et fixes** :

| Score | Problème | Solution |
|-------|----------|----------|
| -0.5 | SPF missing | Ajouter TXT : `v=spf1 mx ~all` |
| -1.0 | DKIM not signed | Vérifier rspamd logs, clés DKIM |
| -1.0 | DMARC missing | Ajouter TXT : `v=DMARC1; p=quarantine...` |
| -0.5 | No reverse DNS | Configurer PTR record chez FAI/VPS |
| -2.0 | Blacklisted IP | Utiliser SMTP relay |

**Utiliser SMTP Relay (recommandé pour débutants)** :

**Pourquoi** : Évite blacklist IP résidentielle, améliore délivrabilité

**Providers gratuits** :
- **SendGrid** : 100 emails/jour gratuit
- **Mailgun** : 5000 emails/mois gratuit (3 mois)
- **Brevo (ex-Sendinblue)** : 300 emails/jour gratuit

**Configuration SendGrid** :
1. Créer compte : https://sendgrid.com
2. Create API Key (SMTP Relay)
3. Noter : `smtp.sendgrid.net:587`, username `apikey`, password `SG.xxx`

**Éditer .env** :
```env
RELAYHOST=smtp.sendgrid.net:587
RELAYHOST_USERNAME=apikey
RELAYHOST_PASSWORD=SG.xxxxxxxxxxxxxxxxxxxxx
```

**Redémarrer Postfix** :
```bash
docker-compose -f compose/docker-compose-full.yml restart postfix
```

**Tester** : Envoyer email depuis Roundcube → Vérifier headers Gmail (via relay)

#### Intégration avec stacks existantes

**Backup offsite (rclone)** :
```bash
# Le backup email sera automatiquement inclus si vous utilisez
# le scheduler setup de common-scripts

sudo bash /opt/pi5-setup/common-scripts/08-scheduler-setup.sh
# Choisir : "Setup all services" → Inclut email stack
```

**Monitoring (Grafana)** :
```bash
# Dashboard Roundcube/Postfix disponible dans
# pi5-monitoring-stack/config/grafana/dashboards/email-dashboard.json

# Import manuel :
# Grafana UI → Dashboards → Import → Upload JSON
```

**Traefik (déjà intégré)** :
- Le script détecte automatiquement Traefik
- Labels docker-compose gèrent routing/HTTPS
- Aucune config manuelle nécessaire

#### Commandes utiles

**Gestion services** :
```bash
# Démarrer
docker-compose -f compose/docker-compose-full.yml start

# Arrêter
docker-compose -f compose/docker-compose-full.yml stop

# Redémarrer
docker-compose -f compose/docker-compose-full.yml restart

# Voir logs (tous services)
docker-compose -f compose/docker-compose-full.yml logs -f

# Logs service spécifique
docker logs -f postfix
docker logs -f dovecot
docker logs -f rspamd
docker logs -f roundcube
```

**Maintenance** :
```bash
# Backup manuel
sudo bash scripts/maintenance/email-backup.sh

# Healthcheck
sudo bash scripts/maintenance/email-healthcheck.sh

# Mise à jour
sudo bash scripts/maintenance/email-update.sh

# Collecter logs
sudo bash scripts/maintenance/email-logs.sh
```

**Debugging** :
```bash
# Tester connexion SMTP
telnet mail.votredomaine.com 587

# Tester IMAP
openssl s_client -connect mail.votredomaine.com:993

# Voir file d'attente Postfix
docker exec postfix postqueue -p

# Flush file d'attente
docker exec postfix postqueue -f

# Tester DKIM
echo "Test" | docker exec -i postfix sendmail -f admin@votredomaine.com test@gmail.com
# Vérifier headers email reçu sur Gmail (Show original)

# Vérifier Rspamd stats
curl http://localhost:11334/stat
```

---

### 4. docs/SCENARIOS-COMPARISON.md (300-500 lignes)

**Contenu** :

#### Comparaison détaillée des scénarios

**Tableau complet** :

| Critère | Scénario 1 : External | Scénario 2 : Full |
|---------|----------------------|-------------------|
| **Complexité** | ⭐ Simple | ⭐⭐⭐ Complexe |
| **Temps installation** | 5-10 min | 30-60 min |
| **Niveau requis** | Débutant | Avancé |
| **Domaine nécessaire** | Optionnel (pour HTTPS) | Obligatoire |
| **DNS complexe** | Non (A record uniquement) | Oui (A, MX, SPF, DKIM, DMARC) |
| **Port 25 ouvert** | Non | Oui (critique) |
| **Emails personnalisés** | Non (@gmail.com) | Oui (@votredomaine.com) |
| **Contrôle données** | Non (chez Google/MS) | Oui (100% local) |
| **Risque spam** | Aucun | Moyen-élevé (si mal configuré) |
| **Maintenance** | Faible | Moyenne-élevée |
| **Consommation RAM** | ~500MB | ~1.5-2GB |
| **Coût** | Gratuit | 10-20€/an (domaine) |
| **Backup requis** | Config uniquement | Config + données mail |
| **Dépendance externe** | Oui (Gmail/MS) | Non (ou relay optionnel) |

**Quand choisir Scénario 1** :
✅ Vous voulez juste une interface web pour lire vos emails Gmail/Outlook
✅ Vous débutez en self-hosting
✅ Vous n'avez pas besoin d'adresses email personnalisées
✅ Vous ne voulez pas gérer DNS complexe
✅ Vous voulez quelque chose qui "juste marche"

**Quand choisir Scénario 2** :
✅ Vous voulez emails @votredomaine.com
✅ Vous voulez contrôle total de vos données
✅ Vous êtes à l'aise avec DNS et troubleshooting
✅ Vous avez un domaine et pouvez configurer DNS
✅ Votre FAI ne bloque pas le port 25 (ou vous utilisez relay)

**Migration Scénario 1 → 2** :
- Possible sans perte de données
- Sauvegarder config Roundcube existante
- Déployer Scénario 2
- Importer paramètres Roundcube
- Créer utilisateurs dans nouveau serveur mail

---

## 🎨 STYLE ET TONE

**Général** :
- Français
- Pédagogique et accessible
- Analogies monde réel
- Exemples concrets
- Tableaux et listes
- Emojis pour sections (📧 🔐 ⚠️ ✅)

**Éviter** :
- Jargon sans explication
- Supposer connaissances avancées
- Laisser étapes implicites
- Oublier cas d'erreur

---

## ✅ CHECKLIST VALIDATION

Avant de soumettre la doc, vérifier :

**README.md** :
- [ ] Vue d'ensemble claire des 2 scénarios
- [ ] Tableau comparatif présent
- [ ] Commandes curl one-liner pour installation
- [ ] Section troubleshooting complète
- [ ] Liens vers autres docs (GUIDE-DEBUTANT, INSTALL, SCENARIOS-COMPARISON)

**GUIDE-DEBUTANT.md** :
- [ ] Analogies simples présentes
- [ ] 3-5 use cases concrets décrits
- [ ] Tutoriels pas-à-pas pour les 2 scénarios
- [ ] Captures d'écran décrites (textuellement)
- [ ] Troubleshooting débutants (tableau)
- [ ] Checklist progression (débutant → avancé)
- [ ] Ressources apprentissage (vidéos, docs, communautés)
- [ ] Français impeccable

**INSTALL.md** :
- [ ] Prérequis détaillés par scénario
- [ ] Installation automatique (curl one-liner)
- [ ] Installation manuelle (si échec automatique)
- [ ] Configuration providers (Gmail, Outlook, Proton)
- [ ] Vérifications post-installation
- [ ] Gestion utilisateurs (scripts + manuel)
- [ ] Tests délivrabilité (mail-tester.com)
- [ ] Commandes debugging

**SCENARIOS-COMPARISON.md** :
- [ ] Tableau comparatif exhaustif
- [ ] Critères de choix clairs
- [ ] Migration path décrit

---

## 🚀 FICHIERS DE RÉFÉRENCE

**Pour comprendre la stack** :
- [compose/docker-compose-external.yml](compose/docker-compose-external.yml)
- [compose/docker-compose-full.yml](compose/docker-compose-full.yml)
- [scripts/01-roundcube-deploy-external.sh](scripts/01-roundcube-deploy-external.sh)
- [scripts/01-roundcube-deploy-full.sh](scripts/01-roundcube-deploy-full.sh)

**Templates de référence** :
- [.templates/GUIDE-DEBUTANT-TEMPLATE.md](../.templates/GUIDE-DEBUTANT-TEMPLATE.md)
- [pi5-supabase-stack/GUIDE-DEBUTANT.md](../pi5-supabase-stack/GUIDE-DEBUTANT.md) (excellent exemple)
- [pi5-traefik-stack/GUIDE-DEBUTANT.md](../pi5-traefik-stack/GUIDE-DEBUTANT.md)

**Documentation technique officielle** :
- Roundcube : https://github.com/roundcube/roundcubemail/wiki
- Postfix : http://www.postfix.org/BASIC_CONFIGURATION_README.html
- Dovecot : https://doc.dovecot.org/
- Rspamd : https://rspamd.com/doc/index.html

---

## 📊 INFORMATIONS TECHNIQUES

**Images Docker utilisées** :
- `roundcube/roundcubemail:latest` (officielle)
- `postgres:15-alpine` (BDD)
- `boky/postfix:latest` (ARM64 compatible)
- `dovecot/dovecot:latest` (officielle)
- `a-mail/rspamd:latest` (ARM64 compatible)

**Ports exposés** :
- 25 (SMTP)
- 587 (SMTP Submission)
- 143 (IMAP)
- 993 (IMAPS)
- 110 (POP3)
- 995 (POP3S)
- 11334 (Rspamd WebUI)

**Volumes Docker** :
- `roundcube-db-data` : PostgreSQL Roundcube
- `mail-db-data` : PostgreSQL mailserver
- `postfix-data` : File d'attente Postfix
- `dovecot-data` : Stockage emails
- `rspamd-data` : Configs/stats Rspamd

**Réseau Docker** :
- `email-network` : Communication interne
- `traefik-network` : Exposition externe (Traefik)

---

## 🎯 OBJECTIF FINAL

L'utilisateur doit pouvoir :

**Scénario 1** :
1. Copier-coller la commande curl
2. Choisir son provider (Gmail/Outlook/Proton)
3. Entrer son domaine
4. Attendre 2-3 minutes
5. Se connecter à Roundcube avec ses identifiants existants
6. Lire/écrire emails via interface web

**Scénario 2** :
1. Acheter un domaine
2. Configurer DNS de base (A, MX, SPF)
3. Copier-coller la commande curl
4. Suivre le wizard (domaine, relay optionnel)
5. Ajouter DKIM/DMARC (affichés par le script)
6. Attendre propagation DNS (15-30 min)
7. Créer premier utilisateur
8. Se connecter à Roundcube
9. Tester envoi email → Score mail-tester.com > 8/10
10. Utiliser email personnalisé (@son-domaine.com)

**Sans** :
❌ Erreurs cryptiques
❌ Étapes manuelles complexes
❌ Documentation technique incompréhensible
❌ Besoin de chercher ailleurs

---

**Bon courage Gemini ! 🤖**

Si tu as des questions sur les scripts ou l'architecture, documente dans README.md section "Architecture détaillée".

---

**Version** : 1.0.0
**Date** : 2025-01-XX
**Auteur original (scripts)** : Claude Code
**Auteur doc** : Gemini (toi!)
