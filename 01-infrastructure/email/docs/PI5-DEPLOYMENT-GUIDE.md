# 🚀 Mailu - Guide de Déploiement Pi5 Production

**Version**: 1.0.0
**Date**: 2025-10-21
**Script Version**: 1.6.0-auto-retry-admin

---

## 📋 Pré-requis

### Système
- ✅ Raspberry Pi 5 (ARM64)
- ✅ Raspberry Pi OS Bookworm 64-bit
- ✅ Minimum 4GB RAM (16GB recommandé)
- ✅ Minimum 10GB espace disque libre
- ✅ Docker & Docker Compose installés

### Réseau
- ✅ IP publique fixe ou DynDNS
- ✅ Accès au panneau DNS de votre domaine (OVH)
- ✅ Ports ouverts sur box/firewall : 25, 80, 443, 465, 587, 993

### Domaine
- ✅ Nom de domaine enregistré (ex: iamaketechnology.fr)
- ✅ Accès au panneau de gestion DNS

---

## 🎯 Vue d'ensemble

**Mailu** est un serveur email complet auto-hébergé incluant :
- 📨 **SMTP** (Postfix) - Envoi d'emails
- 📥 **IMAP** (Dovecot) - Réception et stockage
- 🛡️ **Antispam** (Rspamd) - Filtrage anti-spam
- 🌐 **Webmail** (Roundcube) - Interface web
- ⚙️ **Admin Panel** - Gestion utilisateurs/domaines
- 🔒 **TLS** - Chiffrement emails
- 🔐 **DKIM/SPF/DMARC** - Authentification

**Ressources Pi5** :
- RAM utilisée : ~1.5 GB
- CPU au repos : 2-5%
- Espace disque : ~2-3 GB

---

## 📦 Installation sur Pi5

### Étape 1 : Télécharger le script

```bash
# Se connecter au Pi5
ssh pi@pi5.local

# Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/legacy/01-mailu-deploy.sh -o /tmp/mailu-deploy.sh

# Vérifier le téléchargement
ls -lh /tmp/mailu-deploy.sh
grep 'SCRIPT_VERSION=' /tmp/mailu-deploy.sh
```

**Sortie attendue** : `SCRIPT_VERSION="1.6.0-auto-retry-admin"` ou supérieur

### Étape 2 : Configurer les variables d'environnement

```bash
# Définir les variables AVANT de lancer le script
export MAILU_DOMAIN=votre-domaine.fr
export MAILU_HOSTNAME=mail
export MAILU_ADMIN_EMAIL=admin@votre-domaine.fr
export MAILU_ADMIN_PASSWORD='VotreMotDePasseSecurise123!'

# ⚠️ IMPORTANT : Utilisez un mot de passe fort (min 12 caractères)
# Exemple : export MAILU_ADMIN_PASSWORD='Sup3r$ecureP@ssw0rd2025!'
```

### Étape 3 : Lancer l'installation

```bash
# Lancer avec sudo en préservant les variables (-E)
sudo -E bash /tmp/mailu-deploy.sh
```

**Durée** : 15-20 minutes (téléchargement images Docker ~2GB)

### Étape 4 : Vérifier l'installation

```bash
# Vérifier que tous les conteneurs sont healthy
docker ps --filter 'name=mailu' --format 'table {{.Names}}\t{{.Status}}'
```

**Sortie attendue** :
```
NAMES                STATUS
mailu-webmail-1      Up 5 minutes (healthy)
mailu-imap-1         Up 5 minutes (healthy)
mailu-antispam-1     Up 5 minutes (healthy)
mailu-smtp-1         Up 5 minutes (healthy)
mailu-admin-1        Up 5 minutes (healthy)
mailu-front-1        Up 5 minutes (healthy)
mailu-redis-1        Up 5 minutes
mailu-resolver-1     Up 5 minutes (healthy)
```

---

## 🌐 Configuration DNS OVH

**⚠️ CRITIQUE** : Sans DNS configurés, les emails ne fonctionneront PAS.

### Guide complet

Voir : [`MAILU-DNS-OVH-SETUP.md`](./MAILU-DNS-OVH-SETUP.md)

### Résumé rapide

| Type | Nom | Valeur | Priorité |
|------|-----|--------|----------|
| **A** | mail | IP_PUBLIQUE_PI5 | - |
| **MX** | @ | mail.votre-domaine.fr | 10 |
| **TXT** | @ | `v=spf1 mx ~all` | - |
| **TXT** | _dmarc | `v=DMARC1; p=quarantine; rua=mailto:admin@votre-domaine.fr` | - |

**DKIM** : À générer après installation (voir étape suivante)

### Vérifier DNS propagation

```bash
# A Record
dig +short mail.votre-domaine.fr

# MX Record
dig +short MX votre-domaine.fr

# SPF
dig +short TXT votre-domaine.fr

# DMARC
dig +short TXT _dmarc.votre-domaine.fr
```

**Délai de propagation** : 15 minutes à 24 heures

---

## 🔐 Configuration DKIM (Post-Installation)

### Générer la clé DKIM

```bash
# Sur le Pi5
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu config-export --format=dkim
```

**Sortie** :
```
mail._domainkey IN TXT ( "v=DKIM1; k=rsa; "
"p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC..." )
```

### Ajouter l'enregistrement DNS

**Sur OVH** :
1. Type : **TXT**
2. Sous-domaine : `mail._domainkey`
3. Valeur : Copier tout le contenu entre guillemets (sans les `( )`)
4. TTL : 3600

**Format final** :
```
v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC...
```

### Vérifier DKIM

```bash
dig +short TXT mail._domainkey.votre-domaine.fr
```

---

## ✅ Vérification complète

### 1. Test connexion Admin

**URL** : `https://mail.votre-domaine.fr/admin`

**Credentials** :
- Email : `admin@votre-domaine.fr`
- Mot de passe : Celui défini dans `MAILU_ADMIN_PASSWORD`

### 2. Créer utilisateur de test

**Via Admin Panel** :
1. Login → Section "Users"
2. Cliquer "Add user"
3. Email : `test@votre-domaine.fr`
4. Password : (au choix)
5. Quota : 1GB
6. Save

**Via CLI** :
```bash
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu user test votre-domaine.fr 'MotDePasse123'
```

### 3. Test Webmail

**URL** : `https://mail.votre-domaine.fr/webmail`

Login avec `test@votre-domaine.fr`

### 4. Test envoi email interne

**Webmail** :
- De : `test@votre-domaine.fr`
- À : `admin@votre-domaine.fr`
- Sujet : "Test email interne"
- Envoyer

Vérifier réception dans boîte admin.

### 5. Test envoi email externe

**Webmail** :
- De : `admin@votre-domaine.fr`
- À : votre_email_gmail@gmail.com
- Sujet : "Test Mailu production"
- Envoyer

**Vérifier** :
- ✅ Email reçu (pas dans spam)
- ✅ Headers DKIM/SPF validés
- ✅ Pas de warning sécurité

---

## 🛠️ Commandes utiles

### Gestion quotidienne

```bash
# Voir les logs
cd /home/pi/stacks/mailu
docker compose logs -f

# Logs d'un service spécifique
docker compose logs -f admin
docker compose logs -f smtp

# Redémarrer tous les services
docker compose restart

# Redémarrer un service spécifique
docker compose restart admin

# Arrêter Mailu
docker compose down

# Démarrer Mailu
docker compose up -d

# Voir l'état des conteneurs
docker ps --filter 'name=mailu'

# Statistiques ressources
docker stats --filter 'name=mailu'
```

### Gestion utilisateurs (CLI)

```bash
cd /home/pi/stacks/mailu

# Créer utilisateur
docker compose exec admin flask mailu user USERNAME DOMAIN PASSWORD

# Créer admin
docker compose exec admin flask mailu admin USERNAME DOMAIN PASSWORD

# Supprimer utilisateur
docker compose exec admin flask mailu user-delete USERNAME@DOMAIN

# Lister utilisateurs
docker compose exec admin flask mailu user list

# Changer mot de passe
docker compose exec admin flask mailu password USERNAME@DOMAIN NEW_PASSWORD
```

### Backup

```bash
# Backup complet
cd /home/pi/stacks
tar -czf mailu-backup-$(date +%Y%m%d).tar.gz mailu/

# Backup données uniquement
tar -czf mailu-data-backup-$(date +%Y%m%d).tar.gz mailu/data/ mailu/mail/

# Copier sur machine distante
scp mailu-backup-*.tar.gz user@backup-server:/backups/
```

### Restore

```bash
# Arrêter Mailu
cd /home/pi/stacks/mailu
docker compose down

# Restaurer
cd /home/pi/stacks
tar -xzf mailu-backup-YYYYMMDD.tar.gz

# Redémarrer
cd /home/pi/stacks/mailu
docker compose up -d
```

---

## 🔧 Dépannage

### Problème : Admin user non créé

**Symptôme** : "Wrong email or password" lors du login

**Solution** :
```bash
cd /home/pi/stacks/mailu
docker compose exec admin flask mailu admin admin votre-domaine.fr 'VotrePassword'
```

### Problème : Emails marqués comme spam

**Causes possibles** :
1. ❌ DKIM non configuré
2. ❌ SPF incorrect
3. ❌ IP dans blacklist

**Vérifications** :
```bash
# Tester configuration email
# Envoyer email à : check-auth@verifier.port25.com
# Réponse automatique avec rapport complet

# Vérifier IP blacklist
# https://mxtoolbox.com/blacklists.aspx
```

### Problème : Conteneur unhealthy

**Vérifier logs** :
```bash
docker logs mailu-NOM-DU-CONTENEUR-1 --tail 100
```

**Redémarrer conteneur** :
```bash
docker compose restart NOM-DU-SERVICE
```

### Problème : Ports déjà utilisés

**Vérifier** :
```bash
sudo lsof -i :25
sudo lsof -i :80
sudo lsof -i :443
```

**Libérer port** :
```bash
sudo systemctl stop SERVICE_NAME
```

---

## 📚 Documentation

- **Mailu officiel** : https://mailu.io/master/
- **Configuration DNS** : [`MAILU-DNS-OVH-SETUP.md`](./MAILU-DNS-OVH-SETUP.md)
- **PI5-SETUP Repo** : https://github.com/iamaketechnology/pi5-setup

---

## 🔒 Sécurité

### Bonnes pratiques

1. ✅ **Mots de passe forts** (min 16 caractères, mix majuscules/minuscules/chiffres/symboles)
2. ✅ **Certificats TLS** (Let's Encrypt via Traefik ou standalone)
3. ✅ **Fail2ban** (bloquer tentatives bruteforce)
4. ✅ **Backups réguliers** (quotidiens recommandés)
5. ✅ **Mises à jour** (suivre releases Mailu)
6. ✅ **Firewall** (ufw - autoriser seulement ports nécessaires)

### Firewall recommandé

```bash
# Installer ufw
sudo apt install ufw

# Règles de base
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Autoriser SSH
sudo ufw allow 22/tcp

# Autoriser Mailu
sudo ufw allow 25/tcp    # SMTP
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 465/tcp   # SMTPS
sudo ufw allow 587/tcp   # Submission
sudo ufw allow 993/tcp   # IMAPS

# Activer
sudo ufw enable
```

---

## 📊 Monitoring

### Vérifications hebdomadaires

```bash
# Espace disque
df -h | grep -E '/|mailu'

# RAM
free -h

# Logs erreurs
docker compose logs --since 7d | grep -i error

# Conteneurs status
docker ps --filter 'name=mailu'
```

### Alertes recommandées

- ❗ Espace disque < 20%
- ❗ RAM > 80%
- ❗ Conteneur stopped/unhealthy
- ❗ Logs erreurs SMTP/IMAP

---

## 🚀 Intégration Traefik (Optionnel)

Pour SSL automatique avec Let's Encrypt via Traefik :

**Fichier** : `01-infrastructure/traefik/scripts/add-mailu-route.sh`

```bash
# À venir - script d'intégration automatique
```

---

## 📝 Changelog

### v1.0.0 (2025-10-21)
- ✅ Guide initial de déploiement Pi5
- ✅ Testé sur émulateur x86_64 (Linux Mint)
- ✅ Prêt pour déploiement Pi5 ARM64
- ✅ Script v1.6.0-auto-retry-admin

---

**Auteur** : PI5-SETUP Project
**License** : MIT
**Support** : https://github.com/iamaketechnology/pi5-setup/issues
