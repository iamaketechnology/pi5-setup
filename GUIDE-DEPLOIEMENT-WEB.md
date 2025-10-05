# 🚀 Guide de Déploiement - Serveur Web de Développement

> **Objectif** : Transformer votre Raspberry Pi 5 en serveur de développement complet pour héberger vos applications web

---

## 📋 Vue d'Ensemble

Ce guide vous montre **dans quel ordre exécuter les scripts** pour obtenir un serveur de développement fonctionnel selon votre configuration.

### Ce que vous aurez à la fin :
- ✅ Backend Supabase (Base de données + Auth + API)
- ✅ Serveur web avec HTTPS automatique
- ✅ Hébergement d'applications web
- ✅ Accès sécurisé depuis internet ou VPN
- ✅ Monitoring et backups automatiques

---

## 🎯 Configurations Disponibles

### Configuration 1 : Serveur Local (Débutant)
**Temps** : ~1h | **Accès** : Réseau local uniquement
- Idéal pour développement et apprentissage
- Pas besoin de domaine
- Accès via IP locale

### Configuration 2 : Serveur Public DuckDNS (Intermédiaire)
**Temps** : ~2h | **Accès** : Internet (gratuit)
- Domaine gratuit DuckDNS (monpi.duckdns.org)
- HTTPS automatique
- Ouverture de ports requise

### Configuration 3 : Serveur Public Cloudflare (Avancé)
**Temps** : ~2h | **Accès** : Internet (domaine perso)
- Votre propre domaine (~8€/an)
- HTTPS automatique
- Protection DDoS Cloudflare

### Configuration 4 : Serveur VPN Privé (Expert)
**Temps** : ~2.5h | **Accès** : VPN sécurisé
- Accès distant sans ouvrir de ports
- Sécurité maximale
- Tailscale (gratuit) ou WireGuard

---

## 📦 Configuration 1 : Serveur Local (Développement)

### Phase 1 : Installation Base (~40 min)

#### Étape 1.1 : Prérequis Système
```bash
# Installation Docker + sécurité + firewall
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash

# ⚠️ REDÉMARRAGE OBLIGATOIRE
sudo reboot
```

**Ce que ça installe** :
- Docker + Docker Compose
- UFW Firewall configuré
- Fail2ban (protection brute-force)
- Optimisations Pi 5

---

#### Étape 1.2 : Déploiement Supabase (après reboot)
```bash
# Backend complet (PostgreSQL + Auth + API + Storage)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

**Ce que ça déploie** :
- PostgreSQL 15 (base de données)
- GoTrue (authentification)
- PostgREST (API REST auto-générée)
- Realtime (WebSocket)
- Storage (fichiers S3-compatible)
- Studio UI (interface admin)

**Vérification** :
```bash
# Vérifier que Supabase fonctionne
curl http://localhost:8000

# Accéder au Studio
# Dans navigateur : http://VOTRE_IP_PI:8000
```

---

### Phase 2 : Hébergement Web (~15 min)

#### Étape 2.1 : Déployer votre Application Web

**Option A : Site statique (HTML/CSS/JS)**
```bash
# Créer dossier web
sudo mkdir -p /var/www/monsite
sudo chown -R $USER:$USER /var/www/monsite

# Copier vos fichiers (exemple)
cp -r /chemin/vers/votre/site/* /var/www/monsite/

# Déployer avec Nginx
docker run -d \
  --name monsite \
  --network supabase_default \
  -v /var/www/monsite:/usr/share/nginx/html:ro \
  -p 8080:80 \
  nginx:alpine

# Accès : http://VOTRE_IP_PI:8080
```

**Option B : Application React/Vue/Angular**
```bash
# Build votre app localement
npm run build

# Copier le dossier build/dist sur le Pi
scp -r ./dist/* pi@VOTRE_IP_PI:/var/www/monsite/

# Déployer avec Nginx (même commande qu'Option A)
```

**Option C : Application Node.js/Express**
```bash
# Copier votre app sur le Pi
scp -r ./mon-app pi@VOTRE_IP_PI:~/mon-app

# Sur le Pi, créer Dockerfile
cat > ~/mon-app/Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
EOF

# Build et run
cd ~/mon-app
docker build -t mon-app .
docker run -d \
  --name mon-app \
  --network supabase_default \
  -p 3000:3000 \
  -e DATABASE_URL="postgresql://postgres:your-super-secret-and-long-postgres-password@supabase-db:5432/postgres" \
  mon-app

# Accès : http://VOTRE_IP_PI:3000
```

---

#### Étape 2.2 : Connecter votre App à Supabase

**Dans votre application web** :
```javascript
// Configuration Supabase Client (JavaScript)
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'http://VOTRE_IP_PI:8000'
const supabaseKey = 'votre-anon-key' // Voir ~/supabase/.env

const supabase = createClient(supabaseUrl, supabaseKey)

// Exemple : Authentification
const { data, error } = await supabase.auth.signUp({
  email: 'user@example.com',
  password: 'password123'
})

// Exemple : Requête base de données
const { data, error } = await supabase
  .from('users')
  .select('*')
```

**Récupérer vos credentials Supabase** :
```bash
# Sur le Pi
cat ~/supabase/.env | grep -E "(ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET)"
```

---

### Phase 3 : Monitoring & Backups (~20 min)

#### Étape 3.1 : Dashboard Homepage (optionnel)
```bash
# Interface centralisant tous vos services
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash

# Accès : http://VOTRE_IP_PI:3030
```

#### Étape 3.2 : Monitoring Grafana (optionnel mais recommandé)
```bash
# Métriques + dashboards (Pi, Docker, PostgreSQL)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# Accès : http://VOTRE_IP_PI:3001
# Login : admin / admin (changer au 1er login)
```

#### Étape 3.3 : Backups Automatiques
```bash
# Backup local Supabase (base de données + volumes)
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh

# Planifier backups quotidiens
sudo crontab -e
# Ajouter :
0 2 * * * /home/pi/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh
```

---

### ✅ Résultat Configuration 1

Vous avez maintenant :
- 🗄️ **Backend Supabase** : `http://VOTRE_IP_PI:8000`
- 🌐 **Votre App Web** : `http://VOTRE_IP_PI:3000` (ou autre port)
- 📊 **Dashboard Homepage** : `http://VOTRE_IP_PI:3030`
- 📈 **Monitoring Grafana** : `http://VOTRE_IP_PI:3001`
- 💾 **Backups quotidiens** : Automatiques 2h du matin

**Accès** : Réseau local uniquement (WiFi/Ethernet maison)

---

## 🌍 Configuration 2 : Serveur Public DuckDNS (Internet)

### Prérequis
- Configuration 1 terminée
- Compte DuckDNS gratuit : https://www.duckdns.org
- Port 80 et 443 redirigés vers Pi (configuration box internet)

---

### Phase 1 : Traefik + DuckDNS (~30 min)

#### Étape 1.1 : Configurer DuckDNS
```bash
# 1. Créer compte sur duckdns.org
# 2. Créer sous-domaine : monpi.duckdns.org
# 3. Noter votre TOKEN DuckDNS
```

#### Étape 1.2 : Déployer Traefik
```bash
# Installation Traefik avec DuckDNS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# Le script va demander :
# - Votre sous-domaine DuckDNS : monpi
# - Votre TOKEN DuckDNS : abc123...
# - Email Let's Encrypt : vous@email.com
```

#### Étape 1.3 : Intégrer Supabase
```bash
# Exposer Supabase via HTTPS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

---

### Phase 2 : Configurer Box Internet

**Redirection de ports (sur votre box)** :
```
Port 80 (HTTP)  → IP_DU_PI:80
Port 443 (HTTPS) → IP_DU_PI:443
```

**Guides par FAI** :
- Orange Livebox : Paramètres → NAT/PAT
- Free Freebox : Paramètres → Gestion des ports
- SFR Box : Réseau → NAT/PAT
- Bouygues Bbox : Services de la box → NAT

---

### Phase 3 : Exposer votre Application Web

#### Méthode 1 : Labels Docker (recommandé)
```bash
# Recréer votre container avec labels Traefik
docker stop mon-app && docker rm mon-app

docker run -d \
  --name mon-app \
  --network traefik_web \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.mon-app.rule=Host(\`app.monpi.duckdns.org\`)" \
  --label "traefik.http.routers.mon-app.entrypoints=websecure" \
  --label "traefik.http.routers.mon-app.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.mon-app.loadbalancer.server.port=3000" \
  mon-app

# Votre app est maintenant sur : https://app.monpi.duckdns.org
```

#### Méthode 2 : Docker Compose (apps complexes)
```yaml
# ~/mon-app/docker-compose.yml
version: '3.8'
services:
  app:
    build: .
    networks:
      - traefik_web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mon-app.rule=Host(`app.monpi.duckdns.org`)"
      - "traefik.http.routers.mon-app.entrypoints=websecure"
      - "traefik.http.routers.mon-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.mon-app.loadbalancer.server.port=3000"

networks:
  traefik_web:
    external: true
```

```bash
# Déployer
cd ~/mon-app
docker-compose up -d
```

---

### ✅ Résultat Configuration 2

Vous avez maintenant :
- 🌐 **Accès public HTTPS** : `https://monpi.duckdns.org`
- 🔒 **Certificat SSL** : Automatique (Let's Encrypt)
- 🗄️ **Supabase Studio** : `https://studio.monpi.duckdns.org`
- 📱 **Votre App Web** : `https://app.monpi.duckdns.org`
- 📊 **Dashboard** : `https://home.monpi.duckdns.org`

**Accès** : Depuis n'importe où sur internet ! 🌍

---

## 🏢 Configuration 3 : Serveur Public Cloudflare (Domaine Perso)

### Prérequis
- Domaine acheté (~8€/an) : Namecheap, OVH, Gandi
- Compte Cloudflare gratuit
- Configuration 1 terminée

---

### Phase 1 : Configuration Cloudflare (~15 min)

#### Étape 1.1 : Ajouter domaine à Cloudflare
```bash
# 1. Créer compte sur cloudflare.com
# 2. Ajouter votre domaine : mondomaine.fr
# 3. Changer nameservers chez votre registrar vers ceux de Cloudflare
# 4. Attendre propagation DNS (5-30 min)
```

#### Étape 1.2 : Créer API Token Cloudflare
```bash
# Sur Cloudflare Dashboard :
# 1. My Profile → API Tokens → Create Token
# 2. Template "Edit zone DNS"
# 3. Zone Resources : mondomaine.fr
# 4. Copier le token généré
```

---

### Phase 2 : Déployer Traefik Cloudflare (~20 min)

```bash
# Installation Traefik avec Cloudflare DNS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# Le script va demander :
# - Domaine principal : mondomaine.fr
# - API Token Cloudflare : xxxxx
# - Email Let's Encrypt : vous@email.com

# Intégrer Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

---

### Phase 3 : Créer Records DNS Cloudflare

**Sur Cloudflare Dashboard → DNS** :
```
Type  | Name   | Content        | Proxy
------|--------|----------------|-------
A     | @      | IP_PUBLIQUE_PI | ✅ Proxied
A     | studio | IP_PUBLIQUE_PI | ✅ Proxied
A     | app    | IP_PUBLIQUE_PI | ✅ Proxied
A     | home   | IP_PUBLIQUE_PI | ✅ Proxied
```

**Trouver votre IP publique** :
```bash
curl ifconfig.me
```

---

### Phase 4 : Exposer Applications

**Même principe que Config 2**, changer le domaine :
```bash
docker run -d \
  --name mon-app \
  --network traefik_web \
  --label "traefik.enable=true" \
  --label "traefik.http.routers.mon-app.rule=Host(\`app.mondomaine.fr\`)" \
  --label "traefik.http.routers.mon-app.entrypoints=websecure" \
  --label "traefik.http.routers.mon-app.tls.certresolver=letsencrypt" \
  --label "traefik.http.services.mon-app.loadbalancer.server.port=3000" \
  mon-app
```

---

### ✅ Résultat Configuration 3

Vous avez maintenant :
- 🌐 **Domaine professionnel** : `https://mondomaine.fr`
- 🔒 **SSL automatique** : Let's Encrypt
- 🛡️ **Protection DDoS** : Cloudflare CDN
- 🗄️ **Supabase** : `https://studio.mondomaine.fr`
- 📱 **Apps** : `https://app.mondomaine.fr`
- 🚀 **Performance** : CDN mondial Cloudflare

---

## 🔐 Configuration 4 : Serveur VPN Privé (Tailscale)

### Avantages
- ✅ Pas besoin d'ouvrir de ports
- ✅ Accès sécurisé depuis n'importe où
- ✅ Chiffrement de bout en bout
- ✅ Gratuit pour usage personnel (100 devices)

---

### Phase 1 : Installation Tailscale (~10 min)

```bash
# Installation Tailscale sur Pi
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash

# Le script va :
# 1. Installer Tailscale
# 2. Ouvrir lien d'authentification
# 3. Configurer subnet routes
```

**Noter votre Tailscale IP** : (ex: 100.x.y.z)
```bash
tailscale ip -4
```

---

### Phase 2 : Déployer Traefik VPN

```bash
# Traefik pour réseau VPN uniquement
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash

# Intégrer Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

---

### Phase 3 : Installer Tailscale sur vos Appareils

**Ordinateur / Téléphone** :
```bash
# macOS
brew install tailscale

# Windows
# Télécharger sur tailscale.com/download

# iPhone/Android
# App Store / Play Store : "Tailscale"

# Se connecter avec le même compte
tailscale login
```

---

### Phase 4 : Accéder à vos Services

**Via IP Tailscale** :
```
Supabase : https://100.x.y.z:8000
Votre App : https://100.x.y.z:3000
Homepage : https://100.x.y.z:3030
```

**Via nom de machine (Magic DNS)** :
```bash
# Activer Magic DNS sur tailscale.com/admin
# Puis accéder via :
https://raspberrypi:8000
https://raspberrypi:3000
```

---

### ✅ Résultat Configuration 4

Vous avez maintenant :
- 🔐 **Réseau privé sécurisé** : Chiffré de bout en bout
- 🌍 **Accès depuis partout** : Sans ouvrir de ports
- 📱 **Multi-devices** : Ordi, téléphone, tablette
- 🛡️ **Sécurité maximale** : Pas exposé sur internet
- 💚 **Gratuit** : Tailscale Free tier (100 devices)

---

## 🎯 Tableau Comparatif des Configurations

| Critère | Config 1<br>Local | Config 2<br>DuckDNS | Config 3<br>Cloudflare | Config 4<br>VPN |
|---------|---------|---------|---------|---------|
| **Temps installation** | ~1h | ~2h | ~2h | ~2.5h |
| **Coût** | Gratuit | Gratuit | ~8€/an | Gratuit |
| **Accès Internet** | ❌ | ✅ | ✅ | ✅ (VPN) |
| **HTTPS** | ❌ | ✅ | ✅ | ✅ |
| **Ports à ouvrir** | 0 | 2 (80,443) | 2 (80,443) | 0 |
| **Sécurité** | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Complexité** | Facile | Moyen | Moyen | Avancé |
| **Protection DDoS** | N/A | ❌ | ✅ | N/A |
| **Domaine perso** | ❌ | ❌ | ✅ | ❌ |
| **Performance** | ⚡⚡⚡⚡ | ⚡⚡⚡ | ⚡⚡⚡⚡ | ⚡⚡⚡ |

---

## 🔄 Workflows de Développement Recommandés

### Workflow 1 : Développement Local → Production
```bash
# 1. Développer en local (Config 1)
# Votre app sur : http://192.168.1.x:3000

# 2. Tester sur réseau local

# 3. Passer en production (Config 2/3)
# Ajouter labels Traefik au container
# Votre app sur : https://app.mondomaine.fr
```

---

### Workflow 2 : Staging + Production
```bash
# 1. Environnement staging (Config 1)
docker run -d --name mon-app-staging \
  -p 3001:3000 \
  -e NODE_ENV=staging \
  mon-app

# 2. Environnement production (Config 3)
docker run -d --name mon-app-prod \
  --network traefik_web \
  --label "traefik.http.routers.mon-app.rule=Host(\`app.mondomaine.fr\`)" \
  -e NODE_ENV=production \
  mon-app
```

---

### Workflow 3 : CI/CD avec Gitea
```bash
# 1. Installer Gitea (optionnel mais puissant)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# 2. Push code déclenche build + deploy automatique
# Voir : 04-developpement/gitea/examples/workflows/
```

---

## 🛠️ Maintenance & Opérations

### Gérer vos Stacks

**Stack Manager** (start/stop/RAM) :
```bash
# Interface interactive
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive

# Voir état + RAM
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Start/stop
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop mon-app
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start mon-app
```

---

### Backups & Restore

**Backup manuel Supabase** :
```bash
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh
```

**Restore Supabase** :
```bash
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-restore.sh
```

**Backup offsite (cloud)** :
```bash
# Configuration R2/B2/S3
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

---

### Monitoring & Logs

**Voir logs d'un container** :
```bash
docker logs -f mon-app --tail 100
```

**Healthcheck Supabase** :
```bash
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-healthcheck.sh
```

**Métriques système** :
```bash
# Dashboard Grafana : http://VOTRE_IP:3001
# Login : admin / admin
```

---

### Mises à Jour

**Update Supabase** :
```bash
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-update.sh
```

**Update système** :
```bash
sudo apt update && sudo apt upgrade -y
sudo reboot
```

---

## 🆘 Troubleshooting

### Problème : Container ne démarre pas
```bash
# Vérifier logs
docker logs mon-app

# Vérifier santé
docker ps -a | grep mon-app

# Recréer container
docker stop mon-app && docker rm mon-app
# Puis relancer docker run...
```

---

### Problème : HTTPS ne fonctionne pas
```bash
# Vérifier Traefik
docker logs traefik

# Vérifier certificats
docker exec traefik ls -la /letsencrypt/

# Redémarrer Traefik
docker restart traefik
```

---

### Problème : Supabase inaccessible
```bash
# Healthcheck complet
~/pi5-setup/01-infrastructure/supabase/scripts/utils/diagnostic-supabase-complet.sh

# Vérifier tous les containers
docker ps | grep supabase

# Redémarrer stack
cd ~/supabase && docker-compose restart
```

---

### Problème : Manque de RAM
```bash
# Voir consommation
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Arrêter stacks non utilisés
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop nextcloud
```

---

## 📚 Ressources Supplémentaires

### Documentation Principale
- [README.md](README.md) - Vue d'ensemble projet
- [INSTALLATION-COMPLETE.md](INSTALLATION-COMPLETE.md) - Installation détaillée
- [SCRIPTS-STRATEGY.md](SCRIPTS-STRATEGY.md) - Stratégie scripts

### Par Thème
- **Backend** : [01-infrastructure/supabase/](01-infrastructure/supabase/)
- **Reverse Proxy** : [01-infrastructure/traefik/](01-infrastructure/traefik/)
- **VPN** : [01-infrastructure/vpn-wireguard/](01-infrastructure/vpn-wireguard/)
- **Git** : [04-developpement/gitea/](04-developpement/gitea/)
- **Monitoring** : [03-monitoring/prometheus-grafana/](03-monitoring/prometheus-grafana/)

### Guides Spécifiques
- [HEBERGER-SITE-WEB.md](HEBERGER-SITE-WEB.md) - Déployer sites web
- [FIREWALL-FAQ.md](FIREWALL-FAQ.md) - Configuration firewall
- [Stack Manager](common-scripts/STACK-MANAGER.md) - Gestion stacks

---

## 🎉 Prochaines Étapes

Une fois votre serveur configuré, vous pouvez ajouter :

### Services Optionnels
```bash
# Dashboard centralisé
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash

# Monitoring complet
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash

# Git self-hosted
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# Cloud storage
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash

# Password manager
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/passwords/scripts/01-vaultwarden-deploy.sh | sudo bash
```

Voir [README.md](README.md) pour la liste complète des 20+ stacks disponibles !

---

## 💡 Conseils Pro

### Performance
- ✅ Utilisez Pi 5 16GB pour applications gourmandes
- ✅ SSD NVMe > microSD (5x plus rapide)
- ✅ Ethernet > WiFi (stabilité)

### Sécurité
- ✅ Changez tous les mots de passe par défaut
- ✅ Activez 2FA où possible (Authelia)
- ✅ Backups quotidiens automatiques
- ✅ Updates réguliers (système + containers)

### Organisation
- ✅ Un container = Une app (isolation)
- ✅ Utilisez docker-compose pour apps complexes
- ✅ Variables d'environnement pour configs
- ✅ Volumes Docker pour persistence données

---

<p align="center">
  <strong>🚀 Bon développement avec votre Pi 5 ! 🚀</strong>
</p>

<p align="center">
  <sub>Questions ? Voir <a href="https://github.com/iamaketechnology/pi5-setup/issues">GitHub Issues</a></sub>
</p>
