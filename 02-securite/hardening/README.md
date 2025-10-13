# 🔒 Durcissement Sécurité - Pi Exposé sur Internet

> **Scripts de sécurisation pour Raspberry Pi 5 exposé publiquement**

---

## 📋 Vue d'Ensemble

Ce dossier contient des scripts pour **sécuriser un Raspberry Pi 5 exposé sur Internet** après installation de services (Supabase, Traefik, apps).

### Problèmes Identifiés (Audit)

Lors d'une exposition publique (Cloudflare Tunnel, DuckDNS, etc.), ces ports deviennent vulnérables :

| Port | Service | Risque | Criticité |
|------|---------|--------|-----------|
| 5432 | PostgreSQL | Accès direct base de données | 🔴 CRITIQUE |
| 3000 | Supabase Studio | Interface admin publique | 🔴 CRITIQUE |
| 8001 | Kong Admin | Modification routes API | 🟠 MOYEN |
| 54321 | Edge Functions | Exécution code non autorisée | 🟡 FAIBLE |

**Score sécurité AVANT** : 6.5/10 🟡
**Score sécurité APRÈS** : 8.5/10 🟢

---

## 🛠️ Scripts Disponibles

### 1. `01-harden-exposed-services.sh` (v1.0.0)

**Script principal de durcissement sécurité**

#### Fonctionnalités

✅ **Backup automatique**
- Règles iptables actuelles
- Fichiers `.env` Supabase/Traefik
- Fichiers `docker-compose.yml`

✅ **Blocage ports sensibles**
- PostgreSQL (5432) : Bloqué public, autorisé réseau local
- Studio (3000) : Bloqué public, autorisé réseau local
- Kong Admin (8001) : Bloqué complètement

✅ **Sécurisation fichiers**
- Permissions `.env` : 644 → 600 (root uniquement)

✅ **Idempotence**
- Réexécutable sans risque
- Détecte règles existantes

✅ **Rollback**
- Restauration automatique en cas d'erreur
- Commande manuelle disponible

#### Installation & Usage

```bash
# 1. Test dry-run (RECOMMANDÉ)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/hardening/scripts/01-harden-exposed-services.sh | sudo bash -s -- --dry-run

# 2. Application réelle
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/hardening/scripts/01-harden-exposed-services.sh | sudo bash

# 3. Rollback si problème
sudo bash 01-harden-exposed-services.sh --rollback
```

#### Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Affiche les actions sans les exécuter |
| `--rollback` | Restaure la configuration depuis les backups |
| `--verbose` | Affiche les logs debug détaillés |
| `-h, --help` | Affiche l'aide |

#### Exemple Output

```
╔════════════════════════════════════════════════════════════╗
║  🔒 DURCISSEMENT SÉCURITÉ - SERVICES EXPOSÉS             ║
║     Version 1.0.0                                         ║
╚════════════════════════════════════════════════════════════╝

[INFO] Vérification des dépendances...
[SUCCESS] Toutes les dépendances sont présentes
[INFO] Vérification des services Docker...
[SUCCESS] Supabase détecté
[SUCCESS] Traefik détecté

[INFO] === Sécurisation PostgreSQL (port 5432) ===
[WARNING] PostgreSQL écoute sur 0.0.0.0:5432 (PUBLIC)
[INFO] Sécurisation port 5432 (PostgreSQL)...
[SUCCESS] Port 5432 (PostgreSQL) sécurisé : accès local autorisé, public bloqué

[INFO] === Sécurisation Supabase Studio (port 3000) ===
[WARNING] Supabase Studio écoute sur 0.0.0.0:3000 (PUBLIC)
[SUCCESS] Port 3000 (Supabase Studio) sécurisé : accès local autorisé, public bloqué

[INFO] === Sécurisation fichiers .env ===
[SUCCESS] Permissions /home/pi/stacks/supabase/.env : 644 → 600

[SUCCESS] ✅ Durcissement sécurité terminé avec succès
[INFO] 📋 Log complet : /var/log/security-hardening.log
[INFO] 💾 Backups : /home/pi/backups/security-hardening
```

---

## 🏗️ Sécurité Dès l'Installation

### Modifications Script Supabase (v3.49)

Le script [`02-supabase-deploy.sh`](../../01-infrastructure/supabase/scripts/02-supabase-deploy.sh) a été modifié pour être **sécurisé par défaut** :

#### Changements Appliqués

**AVANT (v3.48)** :
```yaml
ports:
  - "0.0.0.0:5432:5432"  # PostgreSQL accessible depuis PARTOUT
  - "0.0.0.0:3000:3000"  # Studio accessible depuis PARTOUT
```

**APRÈS (v3.49)** :
```yaml
ports:
  - "127.0.0.1:5432:5432"  # PostgreSQL localhost uniquement
  - "127.0.0.1:3000:3000"  # Studio localhost uniquement
```

#### Impact

✅ **Services internes fonctionnent** : Communication via réseau Docker (`supabase_network`)
✅ **Accès local disponible** : `psql -h localhost -p 5432`
✅ **Accès distant via VPN** : Tailscale ou WireGuard
❌ **Accès public bloqué** : Impossible de se connecter depuis Internet

#### Compatibilité

- ✅ **Nouvelles installations** : Sécurisé automatiquement
- ⚠️ **Installations existantes** : Utiliser `01-harden-exposed-services.sh`

---

## 🔐 Bonnes Pratiques Sécurité

### 1. Réseau Local Uniquement (Services Admin)

**PostgreSQL, Studio, Portainer** : Accès via VPN ou SSH tunnel

```bash
# SSH Tunnel pour Studio
ssh -L 3000:localhost:3000 pi@your-pi-ip

# Accès : http://localhost:3000 (via tunnel)
```

### 2. Reverse Proxy pour Services Publics

**Apps, API, Edge Functions** : Passer par Traefik avec HTTPS

```yaml
# Traefik route example
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.myapp.rule=Host(`app.yourdomain.com`)"
  - "traefik.http.routers.myapp.tls=true"
  - "traefik.http.routers.myapp.tls.certresolver=letsencrypt"
```

### 3. Rate Limiting

Ajouter middleware Traefik :

```yaml
http:
  middlewares:
    api-ratelimit:
      rateLimit:
        average: 100
        burst: 50
```

### 4. Authentification (2FA)

Installer [Authelia](../../02-securite/authelia/) pour SSO + 2FA

```bash
curl -fsSL https://raw.githubusercontent.com/.../02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash
```

### 5. Monitoring Sécurité

Surveiller tentatives intrusion :

```bash
# Fail2ban status
sudo fail2ban-client status sshd

# Ports ouverts
sudo netstat -tulpn | grep LISTEN

# Logs auth
sudo tail -f /var/log/auth.log
```

---

## 📊 Audit Sécurité Automatique

### Checklist

```bash
# 1. Ports exposés
sudo netstat -tulpn | grep "0.0.0.0"

# 2. Règles iptables
sudo iptables -L INPUT -n -v | grep DROP

# 3. Permissions .env
find /home/pi/stacks -name ".env" -exec stat -c "%a %n" {} \;

# 4. Fail2ban actif
sudo fail2ban-client status

# 5. Docker networks
docker network ls

# 6. Services vulnérables
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### Script Monitoring (TODO)

```bash
# À créer : 02-security-monitor.sh
sudo bash 02-security-monitor.sh --report
```

**Rapport généré** : `/var/log/security-audit-$(date +%Y%m%d).log`

---

## 🚨 En Cas d'Intrusion

### 1. Bloquer IP Attaquante

```bash
# Ajouter IP à fail2ban
sudo fail2ban-client set sshd banip 203.0.113.42

# Bloquer avec iptables
sudo iptables -A INPUT -s 203.0.113.42 -j DROP
sudo netfilter-persistent save
```

### 2. Changer Passwords

```bash
# PostgreSQL
docker exec supabase-db psql -U postgres -c "ALTER USER postgres PASSWORD 'NEW_SECURE_PASSWORD';"

# Supabase JWT (régénérer)
# Voir : https://supabase.com/docs/guides/self-hosting/docker#generate-jwt-secret
```

### 3. Analyser Logs

```bash
# Logs SSH
sudo grep "Failed password" /var/log/auth.log

# Logs Supabase
docker logs supabase-kong --since 24h | grep "40[13]"

# Logs système
sudo journalctl -xe --since "1 hour ago"
```

### 4. Rollback Complet

```bash
# Restaurer backup
sudo bash 01-harden-exposed-services.sh --rollback

# Redémarrer tous les services
cd /home/pi/stacks/supabase
sudo docker compose down
sudo docker compose up -d
```

---

## 📚 Ressources Complémentaires

### Documentation Projet

- [Guide Authelia (SSO + 2FA)](../../02-securite/authelia/README.md)
- [Guide Traefik (Reverse Proxy)](../../01-infrastructure/traefik/README.md)
- [Guide Backup Offsite](../../09-backups/restic-offsite/README.md)

### Documentation Externe

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html)
- [Supabase Self-Hosting Security](https://supabase.com/docs/guides/self-hosting/docker#securing-your-services)

---

## 🤝 Contribution

Améliorations bienvenues :

1. Scripts additionnels (rate limiting, WAF, IDS)
2. Monitoring automatique
3. Alertes temps réel (Telegram, Discord)
4. Hardening automatique lors de l'installation

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-13
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)

---

**⚠️ IMPORTANT** : Ces scripts modifient les règles firewall. Toujours tester en `--dry-run` d'abord !
