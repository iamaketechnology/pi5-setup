# 🛡️ Security Checklist - PI5-SETUP

> **Liste de vérification complète pour sécuriser votre Raspberry Pi 5 en production**

---

## 📋 Comment Utiliser Cette Checklist

### **Niveaux de Priorité**

- 🔴 **CRITIQUE** : À faire immédiatement (risque de compromission)
- 🟡 **RECOMMANDÉ** : À faire sous 7 jours (améliore grandement la sécurité)
- 🟢 **OPTIONNEL** : Bonnes pratiques (pour aller plus loin)

### **Statut**

- ✅ **Fait** : Cochez quand terminé
- ⏳ **En cours** : En cours de configuration
- ❌ **Non fait** : Pas encore configuré

---

## 🔐 1. ACCÈS SYSTÈME

### **SSH Sécurisé** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| SSH activé | ✅ ❌ | `sudo systemctl status ssh` |
| Mot de passe utilisateur `pi` changé | ✅ ❌ | `passwd` (minimum 12 caractères) |
| Root login désactivé | ✅ ❌ | `sudo nano /etc/ssh/sshd_config` → `PermitRootLogin no` |
| Clés SSH configurées | ✅ ❌ | [Guide](#configurer-clés-ssh) |
| Authentification par mot de passe désactivée (key-only) | ✅ ❌ | `PasswordAuthentication no` dans sshd_config |
| Port SSH changé (non-standard) | ✅ ❌ | `Port 2222` dans sshd_config 🟡 |

**Vérification Rapide** :
```bash
# Tester config SSH
sudo sshd -t

# Redémarrer SSH après changements
sudo systemctl restart ssh
```

---

### **Utilisateurs & Permissions** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Utilisateur `pi` a un mot de passe fort | ✅ ❌ | `passwd` |
| Pas d'utilisateurs avec mot de passe vide | ✅ ❌ | `sudo awk -F: '($2 == "") {print $1}' /etc/shadow` |
| Utilisateur dédié pour applications (non-root) | ✅ ❌ | `sudo useradd -m appuser` 🟡 |
| Sudoers configuré correctement | ✅ ❌ | `sudo visudo` |

---

## 🌐 2. RÉSEAU & FIREWALL

### **Firewall (UFW)** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| UFW installé | ✅ ❌ | `sudo apt install ufw` |
| Règles par défaut (deny incoming) | ✅ ❌ | `sudo ufw default deny incoming` |
| SSH autorisé | ✅ ❌ | `sudo ufw allow 22/tcp` (ou port custom) |
| HTTP/HTTPS autorisés | ✅ ❌ | `sudo ufw allow 80,443/tcp` |
| Ports Supabase API autorisés | ✅ ❌ | `sudo ufw allow 8001/tcp` |
| UFW activé | ✅ ❌ | `sudo ufw enable` |
| Vérifier status | ✅ ❌ | `sudo ufw status verbose` |

**Configuration Complète** :
```bash
# Setup complet UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp       # SSH (ou votre port custom)
sudo ufw allow 80/tcp       # HTTP
sudo ufw allow 443/tcp      # HTTPS
sudo ufw allow 8001/tcp     # Kong API
sudo ufw enable
sudo ufw status numbered
```

---

### **Exposition des Services** 🔴 CRITIQUE

| Service | Port | Doit Être | Status | Vérification |
|---------|------|-----------|--------|--------------|
| PostgreSQL | 5432 | 127.0.0.1 ONLY | ✅ ❌ | `sudo netstat -tlnp \| grep 5432` |
| Supabase Studio | 3000 | 127.0.0.1 ONLY | ✅ ❌ | `sudo netstat -tlnp \| grep 3000` |
| Traefik Dashboard | 8080/8081 | 127.0.0.1 ONLY | ✅ ❌ | `sudo netstat -tlnp \| grep 808` |
| Portainer | 8080/9000 | 127.0.0.1 ONLY | ✅ ❌ | `sudo netstat -tlnp \| grep 8080` |
| Kong Admin API | 8444 | 127.0.0.1 ONLY | ✅ ❌ | `sudo netstat -tlnp \| grep 8444` |
| Kong API | 8001 | 0.0.0.0 (PUBLIC) | ✅ ❌ | OK si JWT activé |
| Traefik HTTP/HTTPS | 80/443 | 0.0.0.0 (PUBLIC) | ✅ ❌ | OK |

**Script de Vérification Automatique** :
```bash
# Lancer le script d'audit réseau
sudo bash /path/to/common-scripts/security-audit-complete.sh
```

---

### **Fail2ban (Anti Brute-Force)** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Fail2ban installé | ✅ ❌ | `sudo apt install fail2ban` |
| Jail SSH activé | ✅ ❌ | Config dans `/etc/fail2ban/jail.local` |
| Fail2ban démarré | ✅ ❌ | `sudo systemctl enable fail2ban && sudo systemctl start fail2ban` |
| Vérifier bans actifs | ✅ ❌ | `sudo fail2ban-client status sshd` |

**Configuration Minimale** :
```bash
# Créer config
sudo tee /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = 22
maxretry = 5
bantime = 600
findtime = 600

[traefik-auth]
enabled = true
port = 80,443
maxretry = 10
bantime = 3600
EOF

# Redémarrer
sudo systemctl restart fail2ban

# Vérifier
sudo fail2ban-client status
```

---

## 🐳 3. DOCKER & CONTAINERS

### **Sécurité Docker** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Docker rootless configuré | ✅ ❌ | [Guide Docker Rootless](https://docs.docker.com/engine/security/rootless/) 🟢 |
| Pas de containers privilégiés | ✅ ❌ | `docker ps --filter "label=privileged=true"` |
| Images officielles uniquement | ✅ ❌ | Vérifier `docker-compose.yml` |
| Docker socket protégé | ✅ ❌ | `ls -la /var/run/docker.sock` (permissions 660) |
| Limiteur de ressources (CPU/RAM) | ✅ ❌ | `docker stats` 🟢 |

**Vérification Containers Privilégiés** :
```bash
# Lister containers avec leurs privilèges
for container in $(docker ps --format '{{.Names}}'); do
    privileged=$(docker inspect $container --format '{{.HostConfig.Privileged}}')
    if [[ "$privileged" == "true" ]]; then
        echo "⚠️  $container est PRIVILEGED (risque sécurité)"
    fi
done
```

---

### **Images & Mises à Jour** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Images à jour | ✅ ❌ | `docker images` → vérifier tags |
| Scan vulnérabilités images | ✅ ❌ | `docker scout quickview` 🟢 |
| Mises à jour automatiques Docker | ✅ ❌ | [Watchtower](https://containrrr.dev/watchtower/) 🟢 |

---

## 🗄️ 4. BASES DE DONNÉES

### **PostgreSQL** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Bind localhost uniquement | ✅ ❌ | `127.0.0.1:5432` dans docker-compose.yml |
| Mot de passe fort (32+ caractères) | ✅ ❌ | Vérifier `.env` : `POSTGRES_PASSWORD=...` |
| SSL/TLS activé | ✅ ❌ | `sslmode=require` 🟢 |
| Backups automatiques configurés | ✅ ❌ | [Guide Backups](#backups) |
| RLS (Row Level Security) activé | ✅ ❌ | Vérifier tables Supabase |

**Vérifier Mot de Passe PostgreSQL** :
```bash
# Sur le Pi
cat /home/pi/stacks/supabase/.env | grep POSTGRES_PASSWORD

# Doit être au minimum 32 caractères aléatoires
# Exemple BON : POSTGRES_PASSWORD=a8f3k2m9p1x7c4v6b0n5j8l2q9w3e7r1t
# Exemple MAUVAIS : POSTGRES_PASSWORD=password123
```

---

### **Supabase Secrets** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| JWT_SECRET unique et fort (32+ chars) | ✅ ❌ | Vérifier `.env` |
| ANON_KEY généré dynamiquement | ✅ ❌ | Script génère avec timestamps |
| SERVICE_ROLE_KEY sécurisé | ✅ ❌ | Jamais commit dans Git |
| API Keys rotation planifiée | ✅ ❌ | Tous les 90 jours 🟡 |

**Vérifier Secrets Supabase** :
```bash
cd /home/pi/stacks/supabase

# JWT Secret (minimum 32 caractères)
JWT_LEN=$(grep "^JWT_SECRET=" .env | cut -d= -f2 | wc -c)
if [[ $JWT_LEN -lt 32 ]]; then
    echo "❌ JWT_SECRET trop court ($JWT_LEN chars)"
else
    echo "✅ JWT_SECRET OK ($JWT_LEN chars)"
fi

# ANON_KEY (doit être un JWT valide, ~100+ caractères)
ANON_LEN=$(grep "^ANON_KEY=" .env | cut -d= -f2 | wc -c)
if [[ $ANON_LEN -lt 100 ]]; then
    echo "❌ ANON_KEY invalide ($ANON_LEN chars)"
else
    echo "✅ ANON_KEY OK ($ANON_LEN chars)"
fi
```

---

## 🔐 5. FICHIERS & PERMISSIONS

### **Permissions .env** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Tous .env en mode 600 | ✅ ❌ | `find /home/pi/stacks -name ".env" -exec chmod 600 {} \;` |
| Propriétaire correct (pi:pi) | ✅ ❌ | `sudo chown pi:pi /home/pi/stacks/*/.env` |
| .env pas dans Git | ✅ ❌ | Vérifier `.gitignore` |

**Fixer Permissions Automatiquement** :
```bash
# Sur le Pi
sudo find /home/pi/stacks -name ".env" -exec chmod 600 {} \;
sudo find /home/pi/stacks -name ".env" -exec chown pi:pi {} \;

# Vérifier
find /home/pi/stacks -name ".env" -exec ls -la {} \;
# Doit afficher : -rw------- 1 pi pi
```

---

### **Secrets Git** 🔴 CRITIQUE

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| .gitignore contient .env | ✅ ❌ | `echo ".env" >> .gitignore` |
| Pas de secrets dans l'historique Git | ✅ ❌ | `git log -S "password"` |
| Git-secrets installé | ✅ ❌ | [git-secrets](https://github.com/awslabs/git-secrets) 🟢 |

---

## 🔒 6. HTTPS & CERTIFICATS

### **Traefik & Let's Encrypt** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| HTTPS activé (Let's Encrypt) | ✅ ❌ | Vérifier `https://votre-domain.duckdns.org` |
| Certificats auto-renouvelables | ✅ ❌ | Traefik gère automatiquement |
| TLS 1.3 minimum | ✅ ❌ | Config dans `traefik.yml` |
| HSTS activé | ✅ ❌ | Headers Traefik |
| Certificat valide | ✅ ❌ | `openssl s_client -connect votre-domain:443` |

**Vérifier HTTPS** :
```bash
# Tester certificat
curl -vI https://votre-domain.duckdns.org 2>&1 | grep -E "SSL|TLS"

# Doit afficher : TLSv1.3 (ou TLSv1.2 minimum)
# Doit afficher : SSL certificate verify ok
```

---

### **Headers Sécurité** 🟡 RECOMMANDÉ

| Header | Status | Valeur Recommandée |
|--------|--------|--------------------|
| Strict-Transport-Security (HSTS) | ✅ ❌ | `max-age=31536000; includeSubDomains` |
| X-Content-Type-Options | ✅ ❌ | `nosniff` |
| X-Frame-Options | ✅ ❌ | `DENY` ou `SAMEORIGIN` |
| X-XSS-Protection | ✅ ❌ | `1; mode=block` |
| Content-Security-Policy | ✅ ❌ | [Config CSP](#csp) 🟢 |

**Tester Headers** :
```bash
curl -I https://votre-domain.duckdns.org

# Doit contenir :
# Strict-Transport-Security: max-age=31536000
# X-Content-Type-Options: nosniff
# X-Frame-Options: DENY
```

---

## 💾 7. BACKUPS & RESTAURATION

### **Backups Automatiques** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Backup PostgreSQL quotidien | ✅ ❌ | Cron + pg_dump |
| Backup volumes Docker | ✅ ❌ | Cron + tar |
| Backup .env et configs | ✅ ❌ | Scripts Supabase |
| Backup offsite (cloud) | ✅ ❌ | Rclone + Backblaze/S3 🟢 |
| Rotation backups (GFS) | ✅ ❌ | [Script Rotation](../common-scripts/04-backup-rotate.sh) |
| Test de restauration | ✅ ❌ | **Testez au moins 1 fois !** |

**Setup Backup Minimal** :
```bash
# Cron quotidien PostgreSQL
(crontab -l 2>/dev/null; echo "0 2 * * * /home/pi/stacks/supabase/scripts/maintenance/supabase-backup.sh") | crontab -

# Vérifier
crontab -l
```

---

### **Plan de Restauration** 🟡 RECOMMANDÉ

| Tâche | Status | Documentation |
|-------|--------|---------------|
| Procédure restauration documentée | ✅ ❌ | [Guide Restauration](#restauration) |
| Backup testé 1 fois | ✅ ❌ | **CRITIQUE - Ne pas négliger !** |
| RTO/RPO définis | ✅ ❌ | Recovery Time/Point Objective 🟢 |

---

## 📊 8. MONITORING & LOGS

### **Logs Système** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Logs centralisés | ✅ ❌ | `/var/log/` + Docker logs |
| Rotation logs configurée | ✅ ❌ | `logrotate` |
| Monitoring logs SSH | ✅ ❌ | `journalctl -u ssh -f` |
| Monitoring logs Docker | ✅ ❌ | `docker logs -f <container>` |

---

### **Alertes** 🟢 OPTIONNEL

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Uptime monitoring (Uptime Kuma) | ✅ ❌ | [Stack Monitoring](../03-monitoring/) |
| Alertes email/Slack configurées | ✅ ❌ | Via Grafana/Uptime Kuma |
| Alerte disque plein (>80%) | ✅ ❌ | Script + cron |

---

## 🔄 9. MISES À JOUR

### **Système** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Raspberry Pi OS à jour | ✅ ❌ | `sudo apt update && sudo apt upgrade` |
| Unattended upgrades activé | ✅ ❌ | `sudo apt install unattended-upgrades` |
| Reboot automatique si nécessaire | ✅ ❌ | Config unattended-upgrades 🟢 |

**Activer Mises à Jour Auto** :
```bash
# Installer
sudo apt install unattended-upgrades apt-listchanges

# Configurer
sudo dpkg-reconfigure -plow unattended-upgrades

# Vérifier
sudo systemctl status unattended-upgrades
```

---

### **Docker & Stacks** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Docker Engine à jour | ✅ ❌ | `docker version` |
| Images Docker récentes | ✅ ❌ | `docker pull <image>` |
| Supabase à jour | ✅ ❌ | Vérifier versions dans docker-compose.yml |
| Traefik à jour | ✅ ❌ | [Traefik Releases](https://github.com/traefik/traefik/releases) |

---

## 🌐 10. ACCÈS EXTERNE

### **IP Fixe ou DNS** 🟡 RECOMMANDÉ

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| IP fixe configurée | ✅ ❌ | Réservation DHCP box ou IP statique |
| DuckDNS configuré | ✅ ❌ | [Stack Traefik](../01-infrastructure/traefik/) |
| mDNS configuré (pi5.local) | ✅ ❌ | `avahi-daemon` |
| Domaine custom (optionnel) | ✅ ❌ | Cloudflare/OVH 🟢 |

---

### **VPN (Accès Distant)** 🟢 OPTIONNEL

| Tâche | Status | Commande/Action |
|-------|--------|-----------------|
| Tailscale installé | ✅ ❌ | `curl -fsSL https://tailscale.com/install.sh \| sh` |
| WireGuard configuré | ✅ ❌ | Alternative à Tailscale |
| Accès services via VPN testé | ✅ ❌ | SSH + tunnels via VPN |

---

## 📝 11. DOCUMENTATION

### **Documentation Interne** 🟡 RECOMMANDÉ

| Tâche | Status | Documentation |
|-------|--------|---------------|
| Liste services & ports documentée | ✅ ❌ | [NETWORK-ARCHITECTURE.md](NETWORK-ARCHITECTURE.md) |
| Procédures backup/restore | ✅ ❌ | Dans README stacks |
| Mots de passe dans gestionnaire | ✅ ❌ | 1Password/Bitwarden |
| Contacts urgence définis | ✅ ❌ | Qui appeler si problème ? 🟢 |

---

## 🎯 SCORE DE SÉCURITÉ

### **Calculer Votre Score**

Comptez le nombre de ✅ dans chaque catégorie :

| Catégorie | Items Critiques ✅ | Total Critiques | Score |
|-----------|-------------------|-----------------|-------|
| 1. Accès Système | ___ / 11 | 11 | ___% |
| 2. Réseau & Firewall | ___ / 16 | 16 | ___% |
| 3. Docker & Containers | ___ / 9 | 9 | ___% |
| 4. Bases de Données | ___ / 9 | 9 | ___% |
| 5. Fichiers & Permissions | ___ / 6 | 6 | ___% |
| 6. HTTPS & Certificats | ___ / 10 | 10 | ___% |
| 7. Backups | ___ / 7 | 7 | ___% |
| 8. Monitoring & Logs | ___ / 8 | 8 | ___% |
| 9. Mises à Jour | ___ / 6 | 6 | ___% |
| 10. Accès Externe | ___ / 7 | 7 | ___% |

**TOTAL** : ___ / 89 = ____%

---

### **Interprétation**

- **90-100%** : 🟢 **EXCELLENT** - Production-ready
- **75-89%** : 🟡 **BON** - Quelques améliorations mineures
- **60-74%** : 🟠 **MOYEN** - Nécessite attention
- **< 60%** : 🔴 **CRITIQUE** - Vulnérable, action immédiate requise

---

## 🚀 PLAN D'ACTION PRIORITAIRE

### **Semaine 1 : Les Essentiels** 🔴

1. ✅ Changer mot de passe utilisateur `pi`
2. ✅ Configurer UFW firewall
3. ✅ Vérifier exposition PostgreSQL/Studio (localhost only)
4. ✅ Fixer permissions .env (chmod 600)
5. ✅ Installer Fail2ban
6. ✅ Setup backup PostgreSQL quotidien

### **Semaine 2 : Renforcement** 🟡

7. ✅ Configurer clés SSH
8. ✅ Désactiver authentification SSH par mot de passe
9. ✅ Activer unattended-upgrades
10. ✅ Tester un backup restore
11. ✅ Configurer headers sécurité Traefik
12. ✅ Fixer IP ou configurer DuckDNS

### **Semaine 3 : Monitoring** 🟢

13. ✅ Installer stack Monitoring (Grafana)
14. ✅ Configurer alertes
15. ✅ Documenter architecture
16. ✅ Setup VPN (Tailscale)

---

## 📚 GUIDES DE RÉFÉRENCE

### Configurer Clés SSH

```bash
# Sur votre Mac/PC (générer clé si pas déjà fait)
ssh-keygen -t ed25519 -C "votre-email@example.com"

# Copier clé publique vers le Pi
ssh-copy-id pi@pi5.local

# Tester connexion sans mot de passe
ssh pi@pi5.local
# ✅ Devrait se connecter sans demander de mot de passe

# Désactiver authentification mot de passe
ssh pi@pi5.local
sudo nano /etc/ssh/sshd_config
# Changer : PasswordAuthentication no
sudo systemctl restart ssh
```

---

### Configurer Content Security Policy

```yaml
# traefik.yml ou docker-compose labels
headers:
  contentSecurityPolicy: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' wss: ws:; frame-ancestors 'none';"
```

---

### Plan de Restauration

```bash
# Restaurer PostgreSQL depuis backup
cat backup-20251014.sql | docker exec -i supabase-db psql -U postgres -d postgres

# Restaurer volumes Docker
cd /home/pi/stacks/supabase
sudo docker compose down
sudo tar -xzf volumes-backup-20251014.tar.gz -C ./
sudo docker compose up -d

# Vérifier
docker ps
curl http://localhost:8001/rest/v1/
```

---

## 🔧 SCRIPTS UTILES

### Script Audit Automatique

```bash
# Lancer audit complet
sudo bash /path/to/common-scripts/security-audit-complete.sh

# Génère rapport : /var/log/pi5-security-audit-YYYYMMDD_HHMMSS.log
```

---

### Script Vérification Rapide

```bash
#!/bin/bash
# quick-security-check.sh

echo "🔍 Quick Security Check"
echo ""

# SSH
echo "SSH:"
grep -E "^PermitRootLogin|^PasswordAuthentication" /etc/ssh/sshd_config || echo "  Config SSH par défaut (⚠️)"

# Firewall
echo ""
echo "Firewall:"
sudo ufw status | head -5

# PostgreSQL
echo ""
echo "PostgreSQL Exposure:"
sudo netstat -tlnp 2>/dev/null | grep 5432 | grep -q "127.0.0.1" && echo "  ✅ Localhost only" || echo "  ❌ PUBLIC (DANGER!)"

# Studio
echo ""
echo "Supabase Studio Exposure:"
sudo netstat -tlnp 2>/dev/null | grep ":3000 " | grep -q "127.0.0.1" && echo "  ✅ Localhost only" || echo "  ❌ PUBLIC (DANGER!)"

# .env permissions
echo ""
echo ".env Permissions:"
find /home/pi/stacks -name ".env" -not -perm 600 | while read file; do
    echo "  ⚠️  $file (permissions incorrectes)"
done

echo ""
echo "Done!"
```

**Utilisation** :
```bash
chmod +x quick-security-check.sh
./quick-security-check.sh
```

---

## 📞 EN CAS DE COMPROMISSION

### **Procédure d'Urgence** 🚨

1. **ISOLER LE PI** :
   ```bash
   # Déconnecter réseau immédiatement
   sudo ip link set eth0 down
   # Ou débrancher câble Ethernet
   ```

2. **CHANGER TOUS LES MOTS DE PASSE** :
   ```bash
   # Système
   passwd pi
   sudo passwd root

   # PostgreSQL
   docker exec -it supabase-db psql -U postgres -c "ALTER USER postgres PASSWORD 'NOUVEAU_MOT_DE_PASSE';"

   # Supabase API Keys
   # Regénérer dans .env avec nouveaux secrets
   ```

3. **VÉRIFIER LOGS** :
   ```bash
   # Dernières connexions SSH
   sudo last -20

   # Logs SSH
   sudo journalctl -u ssh | tail -100

   # Logs Docker
   docker logs supabase-db | tail -100
   ```

4. **ANALYSER COMPROMISSION** :
   ```bash
   # Fichiers modifiés récemment
   find /home/pi -type f -mtime -1

   # Processus suspects
   ps auxf | grep -v "\["

   # Connexions réseau actives
   sudo netstat -tunap
   ```

5. **RESTAURER DEPUIS BACKUP** :
   ```bash
   # Si compromission confirmée → clean install
   # Restaurer données depuis dernier backup sain
   ```

6. **CONTACTER SUPPORT** :
   - GitHub Issues : https://github.com/iamaketechnology/pi5-setup/issues
   - Discord PI5-SETUP (si disponible)

---

## 📅 CALENDRIER DE MAINTENANCE

### **Hebdomadaire** (5 min)

- ✅ Vérifier `sudo apt update && sudo apt upgrade`
- ✅ Vérifier logs Fail2ban : `sudo fail2ban-client status sshd`
- ✅ Vérifier espace disque : `df -h`

### **Mensuel** (30 min)

- ✅ Tester restauration backup
- ✅ Mettre à jour images Docker
- ✅ Vérifier certificats HTTPS
- ✅ Auditer logs système
- ✅ Relancer script sécurité : `security-audit-complete.sh`

### **Trimestriel** (2h)

- ✅ Rotation mots de passe (PostgreSQL, API keys)
- ✅ Audit complet sécurité (cette checklist)
- ✅ Review permissions utilisateurs
- ✅ Tester plan de reprise d'activité

---

**Dernière mise à jour** : 14 Octobre 2025
**Version** : 1.0.0
**Auteur** : PI5-SETUP Project

---

**Ressources** :
- [Network Architecture](NETWORK-ARCHITECTURE.md)
- [SSH Tunneling Guide](SSH-TUNNELING-GUIDE.md)
- [CIS Benchmarks Debian](https://www.cisecurity.org/benchmark/debian_linux)
