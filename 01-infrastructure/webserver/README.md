# 🌐 Web Server Stack - Nginx & Caddy

> **Hébergez vos sites web et applications sur votre Raspberry Pi 5**

[![Statut](https://img.shields.io/badge/statut-production-green.svg)](.)
[![ARM64](https://img.shields.io/badge/ARM64-compatible-blue.svg)](.)
[![RAM](https://img.shields.io/badge/RAM-20--30MB-orange.svg)](.)

**Version** : 1.0.0
**Difficulté** : ⭐ Débutant (Nginx) / ⭐ Débutant (Caddy)
**Temps d'installation** : 5-10 minutes
**RAM requise** : 500 MB disponibles minimum

---

## 📋 Vue d'Ensemble

Cette stack vous permet d'héberger vos sites web et applications directement sur votre Raspberry Pi 5. Vous avez le choix entre **deux serveurs web performants** :

### 🔵 Nginx
- **Le plus performant** (~20 MB RAM)
- Support PHP-FPM intégré
- Configuration traditionnelle
- Idéal si vous utilisez déjà Traefik pour HTTPS

### 🟢 Caddy
- **Le plus simple** (~30 MB RAM)
- HTTPS automatique (Let's Encrypt intégré)
- Configuration ultra-simple (Caddyfile)
- HTTP/2 et HTTP/3 natifs
- Idéal pour débuter ou en standalone

---

## 🎯 Cas d'Usage

### Débutant
- ✅ Portfolio personnel (HTML/CSS/JS)
- ✅ Blog statique (Hugo, Jekyll)
- ✅ Landing page
- ✅ Site vitrine

### Intermédiaire
- ✅ Application React/Vue/Angular
- ✅ Site WordPress
- ✅ Application PHP
- ✅ API Node.js/Python

### Avancé
- ✅ Multiple sites (virtual hosts)
- ✅ Load balancing
- ✅ Reverse proxy custom
- ✅ WebSocket support

---

## ⚡ Installation Rapide

### Option 1 : Nginx (Recommandé avec Traefik)

```bash
# Installation Nginx
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-nginx-deploy.sh | sudo bash

# Intégration Traefik (optionnel, pour HTTPS)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/02-integrate-traefik.sh | sudo bash
```

**Accès** : `http://raspberrypi.local:8080`

### Option 2 : Caddy (HTTPS automatique)

```bash
# Avec domaine (HTTPS automatique via Let's Encrypt)
sudo DOMAIN=mysite.com \
     EMAIL=me@email.com \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-caddy-deploy.sh)

# OU mode local (HTTP seulement)
sudo CADDY_PORT=9000 \
     bash <(curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/webserver/scripts/01-caddy-deploy.sh)
```

**Accès** :
- Avec domaine : `https://mysite.com`
- Mode local : `http://raspberrypi.local:9000`

---

## 📁 Structure Installée

### Nginx
```
/home/pi/stacks/webserver/
├── sites/
│   └── mysite/
│       └── index.html          # Votre site web
├── config/
│   └── nginx.conf              # Configuration Nginx
├── logs/
│   ├── access.log
│   └── error.log
├── docker-compose.yml          # Configuration Docker
├── .env                        # Variables d'environnement
└── backups/                    # Sauvegardes automatiques
```

### Caddy
```
/home/pi/stacks/caddy/
├── sites/
│   └── mysite/
│       └── index.html          # Votre site web
├── config/
│   └── Caddyfile               # Configuration Caddy
├── data/                       # Certificats SSL (Let's Encrypt)
├── logs/
│   └── access.log
├── docker-compose.yml
├── .env
└── backups/
```

---

## 🚀 Déployer Votre Site

### 1. Upload via SFTP/SCP

```bash
# Depuis votre machine locale
scp -r mon-site/* pi@raspberrypi.local:/home/pi/stacks/webserver/sites/mysite/

# Ou avec FileZilla/Cyberduck
# Host: raspberrypi.local
# User: pi
# Path: /home/pi/stacks/webserver/sites/mysite/
```

### 2. Upload via rsync

```bash
# Synchronisation (plus rapide pour updates)
rsync -avz --progress mon-site/ pi@raspberrypi.local:/home/pi/stacks/webserver/sites/mysite/
```

### 3. Git Clone

```bash
# SSH dans le Pi
ssh pi@raspberrypi.local

# Clone direct
cd /home/pi/stacks/webserver/sites/mysite/
git clone https://github.com/vous/votre-site.git .
```

---

## 🔧 Configuration Avancée

### Nginx : Activer PHP-FPM

Par défaut, PHP-FPM est activé. Pour le désactiver :

```bash
# Redéployer sans PHP
sudo ENABLE_PHP=no \
     /path/to/01-nginx-deploy.sh
```

### Nginx : Changer le Port

```bash
sudo NGINX_PORT=9000 \
     /path/to/01-nginx-deploy.sh
```

### Caddy : Recharger Config

```bash
# Après modification du Caddyfile
docker exec caddy-webserver caddy reload --config /etc/caddy/Caddyfile
```

### Multiple Sites (Virtual Hosts)

**Nginx** : Modifier `config/nginx.conf`
```nginx
server {
    listen 80;
    server_name site1.local;
    root /usr/share/nginx/html/site1;
}

server {
    listen 80;
    server_name site2.local;
    root /usr/share/nginx/html/site2;
}
```

**Caddy** : Modifier `config/Caddyfile`
```
site1.com {
    root * /srv/site1
    file_server
}

site2.com {
    root * /srv/site2
    file_server
}
```

---

## 🔗 Intégration Traefik

### Pourquoi intégrer Traefik ?

- ✅ HTTPS automatique (Let's Encrypt)
- ✅ Un seul point d'entrée (port 80/443)
- ✅ Multiple sites avec sous-domaines
- ✅ Renouvellement certificats automatique

### Scénarios Supportés

#### 🟢 DuckDNS (Gratuit, path-based)
```
https://monpi.duckdns.org/www    → Nginx/Caddy
https://monpi.duckdns.org/blog   → Autre site
```

#### 🔵 Cloudflare (Domaine perso, subdomain)
```
https://www.mondomaine.fr  → Nginx/Caddy
https://blog.mondomaine.fr → Autre site
```

#### 🟡 VPN (Local, pas de HTTPS)
```
http://www.pi.local  → Nginx/Caddy
```

### Installation Traefik + Intégration

```bash
# 1. Installer Traefik (choisir un scénario)
curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash

# 2. Intégrer votre web server
curl -fsSL https://raw.githubusercontent.com/.../02-integrate-webserver.sh | sudo bash
```

Le script d'intégration :
- Détecte automatiquement le scénario Traefik
- Configure les labels Docker appropriés
- Vous demande le sous-domaine ou path
- Redémarre les services

---

## 📊 Commandes Utiles

### Nginx

```bash
# Voir les logs
docker logs -f webserver-nginx

# Restart
cd /home/pi/stacks/webserver && docker compose restart

# Stop
cd /home/pi/stacks/webserver && docker compose down

# Reload config (sans restart)
docker exec webserver-nginx nginx -s reload

# Tester config
docker exec webserver-nginx nginx -t

# Voir version
docker exec webserver-nginx nginx -v
```

### Caddy

```bash
# Voir les logs
docker logs -f caddy-webserver

# Restart
cd /home/pi/stacks/caddy && docker compose restart

# Stop
cd /home/pi/stacks/caddy && docker compose down

# Reload config (sans restart)
docker exec caddy-webserver caddy reload --config /etc/caddy/Caddyfile

# Valider config
docker exec caddy-webserver caddy validate --config /etc/caddy/Caddyfile

# Voir version
docker exec caddy-webserver caddy version
```

### Monitoring

```bash
# Utilisation RAM/CPU
docker stats webserver-nginx  # ou caddy-webserver

# Espace disque
du -sh /home/pi/stacks/webserver/

# Taille logs
du -sh /home/pi/stacks/webserver/logs/
```

---

## 🛠️ Exemples Pratiques

### Site Statique (HTML/CSS/JS)

Voir [examples/static-site/](examples/static-site/)

### WordPress + MySQL

Voir [examples/wordpress/](examples/wordpress/)

### Application Node.js

Voir [examples/nodejs-app/](examples/nodejs-app/)

---

## ❓ Troubleshooting

### Port déjà utilisé
```bash
# Trouver quel processus utilise le port 8080
sudo lsof -i :8080

# Changer le port
sudo NGINX_PORT=9000 /path/to/01-nginx-deploy.sh
```

### Permission denied sur fichiers
```bash
# Corriger ownership
sudo chown -R pi:pi /home/pi/stacks/webserver/sites/
```

### 502 Bad Gateway (Nginx + PHP)
```bash
# Vérifier PHP-FPM
docker logs webserver-php

# Restart PHP-FPM
cd /home/pi/stacks/webserver && docker compose restart php
```

### Certificat Let's Encrypt échoue (Caddy)
```bash
# Vérifier que ports 80 et 443 sont accessibles depuis Internet
sudo ufw status

# Vérifier DNS
dig mysite.com

# Voir logs Caddy
docker logs caddy-webserver
```

### RAM insuffisante
```bash
# Désactiver PHP si pas utilisé
sudo ENABLE_PHP=no /path/to/01-nginx-deploy.sh

# Ou utiliser Caddy sans domaine (pas de Let's Encrypt)
sudo CADDY_PORT=8080 /path/to/01-caddy-deploy.sh
```

---

## 📚 Documentation Complémentaire

- **[Guide Débutant](webserver-guide.md)** - Tutoriel complet avec analogies
- **[Exemples](examples/)** - Sites prêts à l'emploi
- **[Traefik Integration](../traefik/)** - Setup HTTPS automatique

### Ressources Externes

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Let's Encrypt](https://letsencrypt.org/docs/)

---

## 🔒 Sécurité

### Bonnes Pratiques

- ✅ Garder Docker à jour : `sudo apt update && sudo apt upgrade`
- ✅ Utiliser HTTPS (Traefik ou Caddy)
- ✅ Limiter upload size (défaut : 100MB)
- ✅ Désactiver listing directories
- ✅ Configurer fail2ban (protection brute-force)

### Firewall (UFW)

```bash
# Autoriser HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Ou seulement le port custom
sudo ufw allow 8080/tcp
```

---

## 📈 Performance

### Benchmarks (Raspberry Pi 5 8GB)

**Nginx** :
- Requêtes/sec : ~5000 (site statique)
- RAM : 18-25 MB
- CPU : <5% (idle), ~30% (charge)

**Caddy** :
- Requêtes/sec : ~4000 (site statique)
- RAM : 25-35 MB
- CPU : <5% (idle), ~35% (charge)

### Optimisations

**Nginx** :
```nginx
# Dans nginx.conf
worker_processes auto;
worker_connections 2048;

# Activer cache
location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**Caddy** :
```
# Dans Caddyfile
{
    # Activer compression
    encode gzip zstd
}
```

---

## 💡 FAQ

**Q: Nginx ou Caddy, lequel choisir ?**
A:
- **Nginx** si vous avez déjà Traefik (HTTPS géré par Traefik)
- **Caddy** si standalone et vous voulez HTTPS automatique
- **Nginx** si vous cherchez la performance maximale
- **Caddy** si vous cherchez la simplicité maximale

**Q: Puis-je utiliser les deux en même temps ?**
A: Oui, sur des ports différents. Nginx sur 8080, Caddy sur 9000 par exemple.

**Q: Comment migrer de Nginx vers Caddy (ou inverse) ?**
A:
1. Copier vos fichiers : `cp -r /home/pi/stacks/webserver/sites/* /home/pi/stacks/caddy/sites/`
2. Arrêter l'ancien : `cd /home/pi/stacks/webserver && docker compose down`
3. Démarrer le nouveau : `cd /home/pi/stacks/caddy && docker compose up -d`

**Q: Combien de sites puis-je héberger ?**
A: Limité par la RAM. Sur Pi5 8GB : 10-20 sites statiques facilement. Sites dynamiques : 3-5.

**Q: Support SSL/TLS sans Traefik ni Caddy auto-HTTPS ?**
A: Oui, utilisez Certbot manuellement et montez les certificats dans Nginx.

---

## 🆘 Support

- **Issues** : [GitHub Issues](https://github.com/iamaketechnology/pi5-setup/issues)
- **Documentation** : [PI5-SETUP](https://github.com/iamaketechnology/pi5-setup)
- **Guide débutant** : [webserver-guide.md](webserver-guide.md)

---

## 🎯 Roadmap

- [ ] Support Apache (alternatif)
- [ ] Templates sites prédéfinis (Hugo, Jekyll, Gatsby)
- [ ] Auto-deploy depuis Git (webhooks)
- [ ] Dashboard monitoring (Grafana)
- [ ] Backup automatique vers cloud

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-06
**Auteur** : PI5-SETUP Project

---

[← Retour Infrastructure](../) | [Guide Débutant →](webserver-guide.md)
