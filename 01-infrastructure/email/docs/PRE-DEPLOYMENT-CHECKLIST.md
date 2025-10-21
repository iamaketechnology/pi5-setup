# ✅ Checklist Pré-Déploiement Mailu Pi5

**Version**: 1.0.0
**Date**: 2025-10-21

---

## 🎯 Avant de commencer

Cette checklist vous permet de vérifier que tout est prêt pour déployer Mailu sur votre Pi5.

---

## 📋 Checklist Système

### Raspberry Pi 5

- [ ] **Modèle** : Raspberry Pi 5 (ARM64)
- [ ] **RAM** : Minimum 4GB (16GB recommandé)
- [ ] **OS** : Raspberry Pi OS Bookworm 64-bit
- [ ] **Espace disque libre** : Minimum 10GB

```bash
# Vérifier RAM
free -h

# Vérifier espace disque
df -h

# Vérifier architecture
uname -m  # Doit afficher: aarch64

# Vérifier OS
cat /etc/os-release
```

### Docker

- [ ] **Docker installé** : Version 20.10+
- [ ] **Docker Compose installé** : Plugin V2
- [ ] **Utilisateur dans groupe docker**

```bash
# Vérifier Docker
docker --version

# Vérifier Docker Compose
docker compose version

# Vérifier groupe
groups $USER | grep docker
```

---

## 🌐 Checklist Réseau

### IP & Ports

- [ ] **IP publique** : Fixe ou DynDNS configuré
- [ ] **Box/Firewall** : Ports redirigés vers Pi5

**Ports à ouvrir** :

| Port | Service | Protocole | Requis |
|------|---------|-----------|--------|
| 25 | SMTP | TCP | ✅ Oui |
| 80 | HTTP | TCP | ✅ Oui |
| 443 | HTTPS | TCP | ✅ Oui |
| 465 | SMTPS | TCP | ✅ Oui |
| 587 | Submission | TCP | ✅ Oui |
| 993 | IMAPS | TCP | ✅ Oui |

```bash
# Obtenir IP publique
curl ifconfig.me

# Tester ouverture port (depuis machine externe)
telnet VOTRE_IP_PUBLIQUE 25
```

### DNS

- [ ] **Nom de domaine** : Enregistré et actif
- [ ] **Accès panneau DNS** : OVH / Cloudflare / autre
- [ ] **IP publique connue** : Pour configurer A record

---

## 🔐 Checklist Sécurité

### Credentials

- [ ] **Mot de passe admin** : Fort (min 16 caractères)
  - Majuscules ✓
  - Minuscules ✓
  - Chiffres ✓
  - Symboles ✓

```bash
# Générer mot de passe sécurisé
openssl rand -base64 24
```

### Firewall (Recommandé)

- [ ] **UFW installé** : `sudo apt install ufw`
- [ ] **Règles configurées** : Autoriser ports nécessaires

```bash
# Configuration UFW basique
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 25/tcp   # SMTP
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 465/tcp  # SMTPS
sudo ufw allow 587/tcp  # Submission
sudo ufw allow 993/tcp  # IMAPS
sudo ufw enable
```

---

## 📦 Checklist Pré-Installation

### Variables d'environnement

- [ ] **MAILU_DOMAIN** : Votre nom de domaine (ex: example.com)
- [ ] **MAILU_HOSTNAME** : Sous-domaine mail (généralement "mail")
- [ ] **MAILU_ADMIN_EMAIL** : Email admin (ex: admin@example.com)
- [ ] **MAILU_ADMIN_PASSWORD** : Mot de passe fort

```bash
# Template à compléter
export MAILU_DOMAIN=example.com
export MAILU_HOSTNAME=mail
export MAILU_ADMIN_EMAIL=admin@example.com
export MAILU_ADMIN_PASSWORD='VotreMotDePasseSecurise123!'
```

### Script de déploiement

- [ ] **Script téléchargé** : `/tmp/mailu-deploy.sh`
- [ ] **Version vérifiée** : 1.6.0 ou supérieur
- [ ] **Permissions exécution** : `chmod +x`

```bash
# Télécharger script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/email/scripts/legacy/01-mailu-deploy.sh -o /tmp/mailu-deploy.sh

# Vérifier version
grep 'SCRIPT_VERSION=' /tmp/mailu-deploy.sh

# Donner permissions
chmod +x /tmp/mailu-deploy.sh
```

---

## 🌍 Checklist Post-Installation

### DNS à configurer (OVH)

**⚠️ À faire APRÈS installation Mailu**

- [ ] **A Record** : mail.example.com → IP_PUBLIQUE
- [ ] **MX Record** : example.com → mail.example.com (priorité 10)
- [ ] **SPF (TXT)** : example.com → `v=spf1 mx ~all`
- [ ] **DMARC (TXT)** : _dmarc.example.com → `v=DMARC1; p=quarantine; rua=mailto:admin@example.com`
- [ ] **DKIM (TXT)** : mail._domainkey.example.com → *À générer*

**Guide complet** : [`MAILU-DNS-OVH-SETUP.md`](./MAILU-DNS-OVH-SETUP.md)

### Tests à effectuer

- [ ] **Tous conteneurs healthy** : `docker ps --filter 'name=mailu'`
- [ ] **Interface Admin accessible** : https://mail.example.com/admin
- [ ] **Login admin fonctionnel** : Connexion avec credentials
- [ ] **Utilisateur test créé** : Via admin panel ou CLI
- [ ] **Webmail accessible** : https://mail.example.com/webmail
- [ ] **Email interne testé** : test@example.com → admin@example.com
- [ ] **DKIM généré** : `docker compose exec admin flask mailu config-export --format=dkim`
- [ ] **DNS propagés** : Vérification dig/nslookup
- [ ] **Email externe testé** : admin@example.com → gmail.com

---

## ⏱️ Timeline estimée

| Étape | Durée |
|-------|-------|
| Vérification pré-requis | 10 min |
| Installation Mailu | 15-20 min |
| Configuration DNS | 15 min |
| Propagation DNS | 15 min - 24h |
| Tests et validation | 15 min |
| **TOTAL** | **~1h à 2h** |

---

## 📞 Support

**Problèmes** ? Consultez :

1. **Logs installation** : `/var/log/mailu-deploy-*.log`
2. **Guide déploiement** : [`PI5-DEPLOYMENT-GUIDE.md`](./PI5-DEPLOYMENT-GUIDE.md)
3. **Dépannage Mailu** : Section troubleshooting du guide
4. **Issues GitHub** : https://github.com/iamaketechnology/pi5-setup/issues

---

**Tout coché ?** 🎉 **Vous êtes prêt pour l'installation !**

```bash
sudo -E bash /tmp/mailu-deploy.sh
```
