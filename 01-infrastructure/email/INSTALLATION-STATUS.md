# 📧 Email Server Stack (Mailu) - État d'Installation

**Version** : 1.0.0
**Date** : 2025-10-06
**Statut** : ✅ Scripts prêts à tester

---

## ✅ Composants Créés

### Scripts d'Installation
- ✅ `scripts/01-mailu-deploy.sh` (26 KB) - Déploiement complet Mailu
- ✅ `scripts/02-integrate-traefik.sh` (18 KB) - Intégration Traefik

### Structure
```
email/
├── scripts/           ✅ Créé
│   ├── 01-mailu-deploy.sh
│   └── 02-integrate-traefik.sh
├── config/            ✅ Créé
│   ├── mailu/         (généré à l'installation)
│   └── docker-mailserver/  (alternatif, non implémenté)
└── docs/              ✅ Créé (vide, à remplir)
```

---

## 🚀 Installation Rapide

### Mailu (recommandé - léger, 2GB RAM)
```bash
# Déployer Mailu
sudo MAILU_DOMAIN=mydomain.com \
     MAILU_ADMIN_EMAIL=admin@mydomain.com \
     MAILU_ADMIN_PASSWORD='SecurePass123!' \
     /path/to/01-mailu-deploy.sh

# Intégrer avec Traefik (optionnel)
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-traefik.sh | sudo bash
```

### Configuration DNS Requise
```
A Record:    mail.mydomain.com -> [IP_DU_PI]
MX Record:   mydomain.com -> mail.mydomain.com (priority 10)
SPF (TXT):   mydomain.com -> v=spf1 mx ~all
DKIM (TXT):  [généré après installation]
DMARC (TXT): _dmarc.mydomain.com -> v=DMARC1; p=quarantine
```

---

## 📋 TODO - Documentation

### À créer
- [ ] `README.md` - Vue d'ensemble, installation, use cases
- [ ] `email-guide.md` - Guide débutant (analogies, configuration)
- [ ] `email-setup.md` - Guide technique avancé
- [ ] `docs/DNS-SETUP.md` - Configuration DNS détaillée
- [ ] `docs/CLIENT-SETUP.md` - Configuration clients email
- [ ] `docs/ANTI-SPAM.md` - Configuration anti-spam/DKIM/SPF
- [ ] `docs/TROUBLESHOOTING.md` - Résolution problèmes courants
- [ ] `docs/MIGRATION.md` - Migration depuis autre serveur

---

## ✅ Features Implémentées

### Mailu Deployment Script
- ✅ Validation variables requises (domaine, email, password)
- ✅ Génération secrets automatique (16 bytes)
- ✅ Check RAM (minimum 2GB)
- ✅ Check ports (25, 80, 143, 443, 465, 587, 993, 995)
- ✅ Configuration mailu.env complète
- ✅ Download docker-compose.yml officiel
- ✅ Support ARM64 natif
- ✅ Création admin user automatique
- ✅ Guide DNS intégré
- ✅ README.md généré automatiquement
- ✅ Antivirus optionnel (ClamAV = +1GB RAM)
- ✅ Webmail optionnel (Roundcube)
- ✅ Healthcheck services
- ✅ Backup automatique
- ✅ Idempotent

### Traefik Integration Script
- ✅ Auto-détection scénario Traefik
- ✅ Support DuckDNS (path-based)
- ✅ Support Cloudflare (subdomain)
- ✅ Support VPN (local domains)
- ✅ Update TLS_FLAVOR (cert mode)
- ✅ Labels Traefik dynamiques
- ✅ Keep SMTP/IMAP direct (ports 25, 465, 587, 993...)
- ✅ Proxy HTTP/HTTPS only (Admin + Webmail)
- ✅ Backup config avant modifications
- ✅ Restart services automatique
- ✅ Validation complète
- ✅ Idempotent

---

## 🧪 Tests Requis

### Tests Mailu
- [ ] Installation sur Pi5 8GB
- [ ] Installation sur Pi5 16GB
- [ ] Avec Antivirus (ClamAV)
- [ ] Sans Antivirus
- [ ] Avec Webmail (Roundcube)
- [ ] Création utilisateurs
- [ ] Envoi/réception emails
- [ ] Configuration clients (Thunderbird, mobile)
- [ ] Génération DKIM
- [ ] Validation SPF/DMARC
- [ ] Intégration Traefik DuckDNS
- [ ] Intégration Traefik Cloudflare
- [ ] Test anti-spam (rspamd)

### Tests DNS
- [ ] Validation MX records
- [ ] Validation A records
- [ ] Test SPF avec mail-tester.com
- [ ] Test DKIM avec mail-tester.com
- [ ] Test DMARC
- [ ] Score spam < 5 sur mail-tester

---

## 📊 Statistiques

- **Lignes de code** : ~1800 lignes Bash
- **Temps développement** : ~6h
- **Scripts** : 2 fichiers
- **Taille totale** : ~44 KB
- **RAM requise** : 2GB minimum, 3GB avec ClamAV
- **Installation** : 15-20 minutes (pull images)
- **Services Mailu** : 6-8 containers Docker

---

## ⚠️ Notes Importantes

### Configuration DNS Critique
- ❌ Sans DNS : Emails ne seront **PAS** envoyés/reçus
- ✅ MX Record obligatoire pour recevoir
- ✅ SPF/DKIM/DMARC obligatoires pour éviter spam

### Sécurité
- 🔒 Ports SMTP/IMAP restent exposés (normal pour email)
- 🔒 Utiliser mots de passe forts (12+ caractères)
- 🔒 Activer 2FA dans admin panel
- 🔒 Fail2ban intégré (rspamd)

### Performance
- 💾 2GB RAM minimum (sans ClamAV)
- 💾 3GB RAM recommandé (avec ClamAV)
- 💾 8GB Pi5 : OK pour ~5-10 utilisateurs
- 💾 16GB Pi5 : OK pour ~20-30 utilisateurs

---

## 🔜 Prochaines Étapes

1. **Documentation complète** (~6-8h)
   - README.md
   - Guide débutant
   - DNS setup guide
   - Client setup guide
   - Anti-spam guide
   - Troubleshooting

2. **Tests complets** (~6-8h)
   - Tests sur Pi5 réel
   - Configuration DNS réelle
   - Envoi/réception emails
   - Validation spam score
   - Tests clients multiples

3. **Alternatives** (~4-6h, optionnel)
   - Docker Mailserver script
   - mailcow script (si 16GB Pi5)

4. **Update README principal** (~30min)
   - Ajouter à table des stacks
   - Update ROADMAP.md
   - Warnings DNS/sécurité

**Total estimé restant : 12-18h** (documentation + tests)

---

## 🎯 Use Cases

### Débutant
- Email perso (1-5 boîtes)
- Pas de dépendance Gmail/Outlook
- Apprendre self-hosting

### Intermédiaire
- Famille (5-10 boîtes)
- Domaine perso
- Webmail accessible partout

### Avancé
- Petite entreprise (10-30 boîtes)
- Multiple domaines
- Anti-spam avancé
- Monitoring
