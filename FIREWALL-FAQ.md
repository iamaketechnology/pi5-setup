# 🔥 Pare-feu (Firewall) - FAQ

> **Questions fréquentes sur le firewall UFW du Raspberry Pi 5**

---

## ❓ Le pare-feu est-il nécessaire ?

**OUI, ABSOLUMENT !** Surtout si vous exposez votre Pi sur Internet (DuckDNS, Cloudflare).

### Pourquoi c'est important

| Situation | Sans Firewall | Avec Firewall (UFW) |
|-----------|---------------|---------------------|
| **Exposition Internet** | ⚠️ Tous les ports accessibles | ✅ Seulement ports autorisés |
| **Scan de ports** | ⚠️ Tous services visibles | ✅ Ports fermés invisibles |
| **Attaques brute-force** | ⚠️ Toutes surfaces exposées | ✅ Surface réduite + Fail2ban |
| **Services Docker** | ⚠️ Tous ports exposés | ✅ Bloqués par défaut |
| **Sécurité** | ⚠️ Vulnérable | ✅ Protégé |

**Exemple concret** : Sans firewall, un robot pourrait scanner votre Pi et trouver PostgreSQL sur port 5432, Redis sur 6379, etc. Avec le firewall, seuls les ports 22, 80, 443, 8080 sont visibles.

---

## ✅ Configuration Automatique

**Bonne nouvelle** : Le firewall UFW est **déjà configuré automatiquement** lors de la Phase 1 (script `01-prerequisites-setup.sh`) !

### Ports ouverts par défaut

```bash
# Voir la configuration actuelle
sudo ufw status verbose
```

**Résultat** :
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere    # SSH
80/tcp                     ALLOW       Anywhere    # HTTP (Traefik)
443/tcp                    ALLOW       Anywhere   # HTTPS (Traefik)
8080/tcp                   ALLOW       Anywhere   # Portainer
```

**Explication** :

| Port | Service | Pourquoi ouvert | Peut être fermé ? |
|------|---------|-----------------|-------------------|
| **22** | SSH | Accès terminal au Pi | ❌ NON (vous seriez bloqué) |
| **80** | HTTP | Traefik (redirection → HTTPS) | ⚠️ Seulement si VPN only |
| **443** | HTTPS | Traefik (services web) | ⚠️ Seulement si VPN only |
| **8080** | Portainer | Gestion Docker (interface web) | ✅ OUI si pas utilisé |

**Tous les autres ports sont FERMÉS** (PostgreSQL 5432, Redis 6379, etc.)

---

## 🔧 Gestion du Firewall

### Voir les règles actuelles

```bash
# Statut complet
sudo ufw status verbose

# Liste numérotée (pour supprimer)
sudo ufw status numbered
```

### Ouvrir un port

```bash
# Ouvrir port TCP
sudo ufw allow 3000/tcp

# Ouvrir port UDP
sudo ufw allow 1194/udp

# Ouvrir port depuis IP spécifique
sudo ufw allow from 192.168.1.100 to any port 5432
```

### Fermer un port

```bash
# Supprimer règle par numéro
sudo ufw status numbered
sudo ufw delete 5  # Remplacer 5 par le numéro de la règle

# Supprimer règle par port
sudo ufw delete allow 8080/tcp
```

### Activer/Désactiver le firewall

```bash
# Activer
sudo ufw enable

# Désactiver (⚠️ NE PAS FAIRE en production !)
sudo ufw disable

# Recharger après modifications
sudo ufw reload
```

---

## 🎯 Cas d'Usage Spécifiques

### Scénario 1 : VPN Seulement (Tailscale)

Si vous utilisez **uniquement VPN** (pas d'accès Internet direct), vous pouvez fermer les ports 80 et 443 :

```bash
# Fermer ports publics (HTTP/HTTPS)
sudo ufw delete allow 80/tcp
sudo ufw delete allow 443/tcp

# Garder seulement SSH
sudo ufw status
# Résultat : Seulement port 22 ouvert
```

**Avantage** : Pi invisible depuis Internet (sécurité maximale)

### Scénario 2 : DuckDNS ou Cloudflare

Si vous utilisez **DuckDNS ou Cloudflare**, vous **devez** garder ports 80 et 443 ouverts :

```bash
# Vérifier que 80 et 443 sont ouverts
sudo ufw status | grep -E "80|443"
```

**Si fermés, les ouvrir** :
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
```

### Scénario 3 : Portainer non utilisé

Si vous n'utilisez pas Portainer, fermer le port 8080 :

```bash
# Fermer Portainer
sudo ufw delete allow 8080/tcp
```

### Scénario 4 : Home Assistant (port 8123)

Si vous installez **Home Assistant** (Phase 10) et voulez y accéder directement :

```bash
# Ouvrir port Home Assistant
sudo ufw allow 8123/tcp
```

**Recommandation** : Utilisez plutôt **Traefik** pour accéder via HTTPS (pas besoin d'ouvrir 8123)

### Scénario 5 : SSH sur port personnalisé

Si vous changez le port SSH (par exemple 2222) :

```bash
# Ouvrir nouveau port SSH
sudo ufw allow 2222/tcp

# Fermer ancien port 22
sudo ufw delete allow 22/tcp

# Tester AVANT de fermer la session !
ssh pi@IP -p 2222
```

---

## 🛡️ Sécurité Avancée

### Fail2ban (Déjà Installé)

**Fail2ban** est automatiquement installé en Phase 1 et protège contre les **attaques brute-force** :

- ✅ **SSH** : 3 échecs de login → IP bannie 10 min
- ✅ **Traefik** : Tentatives répétées → IP bannie
- ✅ **Logs** : `/var/log/fail2ban.log`

**Vérifier Fail2ban** :
```bash
# Statut
sudo systemctl status fail2ban

# Voir IPs bannies
sudo fail2ban-client status sshd
```

### Rate Limiting UFW (Optionnel)

Limiter les connexions SSH (protection DoS) :

```bash
# Supprimer règle SSH actuelle
sudo ufw delete allow 22/tcp

# Ajouter avec rate limiting (max 6 connexions/30sec)
sudo ufw limit 22/tcp

# Vérifier
sudo ufw status verbose
```

### Whitelist IP Spécifique

Autoriser seulement votre IP pour SSH :

```bash
# Supprimer règle SSH globale
sudo ufw delete allow 22/tcp

# Autoriser seulement votre IP
sudo ufw allow from VOTRE_IP to any port 22

# Exemple : Autoriser seulement réseau local
sudo ufw allow from 192.168.1.0/24 to any port 22
```

**⚠️ Attention** : Vous serez bloqué si votre IP change (4G, WiFi public, etc.)

---

## 🔍 Diagnostic & Troubleshooting

### Problème : "Connection refused" après activation UFW

**Cause** : Port nécessaire fermé par le firewall

**Solution** :
```bash
# Vérifier quel port est nécessaire (exemple : service sur port 3000)
sudo netstat -tlnp | grep 3000

# Ouvrir le port
sudo ufw allow 3000/tcp
sudo ufw reload

# Tester
curl http://localhost:3000
```

### Problème : "SSH connection timed out"

**Cause** : Port 22 fermé ou rate limiting actif

**Solution** :
```bash
# Si accès physique au Pi (écran + clavier)
sudo ufw status
sudo ufw allow 22/tcp

# Si pas d'accès physique, redémarrer le Pi
# (UFW se désactive temporairement au boot)
```

### Problème : Traefik ne fonctionne plus

**Cause** : Ports 80/443 fermés

**Solution** :
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload

# Vérifier Traefik
sudo docker logs traefik -f
```

### Voir logs UFW

```bash
# Activer logs (déjà fait par défaut)
sudo ufw logging on

# Voir logs
sudo tail -f /var/log/ufw.log

# Chercher connexions bloquées
sudo grep BLOCK /var/log/ufw.log
```

---

## 📊 Tableau Récapitulatif

| Scénario | Ports Ouverts | Commande |
|----------|---------------|----------|
| **DuckDNS/Cloudflare** | 22, 80, 443, 8080 | Configuration par défaut ✅ |
| **VPN seulement** | 22 | `sudo ufw delete allow 80/tcp && sudo ufw delete allow 443/tcp` |
| **Local seulement** | Aucun (ou 22 réseau local) | `sudo ufw allow from 192.168.1.0/24 to any port 22` |
| **Home Assistant direct** | 22, 80, 443, 8123 | `sudo ufw allow 8123/tcp` |
| **Production critique** | 22 (rate limited), 80, 443 | `sudo ufw limit 22/tcp` |

---

## ✅ Checklist Sécurité Firewall

- [ ] UFW activé (`sudo ufw status` → "Status: active")
- [ ] Ports minimaux ouverts (22, 80, 443 si nécessaire)
- [ ] Fail2ban actif (`sudo systemctl status fail2ban`)
- [ ] SSH rate limiting configuré (optionnel : `sudo ufw limit 22/tcp`)
- [ ] Logs UFW activés (`sudo ufw logging on`)
- [ ] Portainer fermé si non utilisé (`sudo ufw delete allow 8080/tcp`)
- [ ] Test connexion SSH fonctionne AVANT de fermer session
- [ ] Backup règles UFW : `sudo cp /etc/ufw/user.rules ~/ufw-backup.rules`

---

## 📚 Ressources

### Documentation UFW
- [UFW Official Docs](https://help.ubuntu.com/community/UFW)
- [DigitalOcean UFW Guide](https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-with-ufw-on-ubuntu)

### Fail2ban
- [Fail2ban Official](https://www.fail2ban.org/)
- [Wiki Fail2ban](https://github.com/fail2ban/fail2ban/wiki)

### Communautés
- [r/raspberry_pi](https://reddit.com/r/raspberry_pi)
- [Stack Exchange Security](https://security.stackexchange.com/)

---

## 🎯 Résumé

**Le firewall UFW est** :
- ✅ **Automatiquement installé** lors de Phase 1
- ✅ **Configuré par défaut** avec ports minimaux (22, 80, 443, 8080)
- ✅ **Essentiel pour sécurité** si exposition Internet
- ✅ **Facile à gérer** avec commandes `ufw`
- ✅ **Complété par Fail2ban** contre brute-force

**Vous n'avez rien à faire** si installation par défaut ! 🎉

**Si besoin d'ouvrir/fermer ports** : Utilisez `sudo ufw allow/delete` comme documenté ci-dessus.

---

<p align="center">
  <strong>🔥 Firewall Configuré, Pi Sécurisé ! 🔥</strong>
</p>
