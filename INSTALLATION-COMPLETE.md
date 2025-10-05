# 🚀 Installation Complète - Raspberry Pi 5 Setup

> **Guide étape par étape pour transformer un Raspberry Pi 5 neuf en serveur auto-hébergé complet**

**Temps total** :
- **Installation minimale** (Phases 0-2) : ~2-3 heures
- **Installation complète** (10 stacks) : ~4-6 heures

**Niveau** : Débutant à Avancé

---

## 📋 Vue d'Ensemble

Ce guide vous permet d'installer **depuis zéro** un serveur **100% open source et gratuit** avec :

### 🎯 Installation de Base (Phases 0-2) - **RECOMMANDÉ POUR DÉBUTANTS**

1. ✅ **Raspberry Pi OS** (système d'exploitation 64-bit)
2. ✅ **Sécurité** (UFW firewall, Fail2ban, SSH hardening)
3. ✅ **Docker** + Docker Compose
4. ✅ **Supabase** (Backend-as-a-Service : PostgreSQL + Auth + API + Realtime)
5. ✅ **Traefik** (Reverse Proxy + HTTPS automatique)
6. ✅ **Homepage** (Dashboard centralisé)
7. ✅ **Sauvegardes** automatiques (rotation GFS)

**Temps** : ~2-3 heures | **RAM** : ~2.5 GB / 16 GB | **Résultat** : Backend complet accessible en HTTPS !

---

### 🚀 Stacks Additionnels (Phases 3-9) - **OPTIONNEL**

8. ✅ **Monitoring** (Prometheus + Grafana + 8 dashboards)
9. ✅ **VPN** (Tailscale - accès sécurisé distant)
10. ✅ **Git + CI/CD** (Gitea + Actions - GitHub-like)
11. ✅ **Backups Offsite** (rclone → Cloudflare R2 / Backblaze B2)
12. ✅ **Storage Cloud** (FileBrowser léger OU Nextcloud complet)
13. ✅ **Media Server** (Jellyfin + *arr stack - Netflix-like)
14. ✅ **Auth SSO** (Authelia + 2FA - authentification centralisée)
15. ✅ **Stack Manager** (Gestion facile RAM/Boot - NEW!)

**RAM totale** (toutes phases) : ~4.5 GB / 16 GB | **Économies** : ~840€/an vs services cloud équivalents

---

## 🎛️ Nouveau : Stack Manager

**Gérez facilement vos stacks Docker** pour optimiser la RAM :

```bash
# Interface interactive (menus)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive

# Voir état + RAM de tous les stacks
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status
```

**Fonctionnalités** :
- ✅ Start/stop stacks en 1 commande
- ✅ Monitoring RAM en temps réel
- ✅ Configuration démarrage auto au boot
- ✅ Interface interactive (TUI)

**Documentation** : [common-scripts/STACK-MANAGER.md](common-scripts/STACK-MANAGER.md)

---

**Résultat final** : Serveur auto-hébergé complet 100% open source ! 🎉

---

## 🛠️ Matériel Nécessaire

### Obligatoire
- [ ] Raspberry Pi 5 (8GB ou 16GB RAM)
- [ ] Carte microSD (32GB minimum, 64GB+ recommandé, classe A2)
- [ ] Alimentation USB-C 27W officielle Raspberry Pi
- [ ] Câble Ethernet (pour installation initiale)

### Recommandé
- [ ] Boîtier avec ventilateur actif (refroidissement)
- [ ] Dissipateurs thermiques
- [ ] Carte microSD rapide (SanDisk Extreme Pro, Samsung EVO Plus)

### Optionnel
- [ ] SSD externe USB 3.0 (pour boot, plus rapide que SD)
- [ ] Écran HDMI + clavier (si pas d'accès SSH)

---

## 📂 Avant de Commencer

### Décisions à Prendre

**1. Scénario Traefik** (choisir UN seul) :
- 🟢 **DuckDNS** : Gratuit, débutants, 15 min → [Voir détails](01-infrastructure/traefik/docs/SCENARIO-DUCKDNS.md)
- 🔵 **Cloudflare** : Domaine perso (~8€/an), production → [Voir détails](01-infrastructure/traefik/docs/SCENARIO-CLOUDFLARE.md)
- 🟡 **VPN** : Privé, sécurité max, 0 exposition → [Voir détails](01-infrastructure/traefik/docs/SCENARIO-VPN.md)

**2. Nom de machine** :
- Exemple : `pi5-homelab`, `pi5-dev`, `monpi`

**3. Adresse IP fixe** :
- Réserver une IP dans votre box (ex: `192.168.1.100`)

---

## 🎬 Installation Étape par Étape

### ═══════════════════════════════════════
### PHASE 0 : Préparation du Pi (30 min)
### ═══════════════════════════════════════

#### Étape 0.1 : Flasher Raspberry Pi OS

**Sur votre PC/Mac** :

1. **Télécharger Raspberry Pi Imager** :
   - [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/)

2. **Lancer Imager** :
   - **Appareil** : Raspberry Pi 5
   - **OS** : Raspberry Pi OS (64-bit) - **Bookworm**
   - **Stockage** : Votre carte microSD

3. **Cliquer sur l'engrenage ⚙️** (paramètres avancés) :
   ```
   ✅ Activer SSH
      → Utiliser mot de passe

   Nom d'utilisateur : pi
   Mot de passe : [VOTRE_MOT_DE_PASSE_FORT]

   ✅ Configurer WiFi (optionnel si Ethernet)
      SSID : [VOTRE_WIFI]
      Mot de passe : [MOT_DE_PASSE_WIFI]

   ✅ Définir locale
      Fuseau horaire : Europe/Paris
      Clavier : fr

   Nom de machine : pi5-homelab
   ```

4. **Écrire** :
   - Cliquer "Écrire"
   - Attendre fin (~5 min)
   - Éjecter la carte SD

---

#### Étape 0.2 : Premier Boot

1. **Insérer** la microSD dans le Pi 5
2. **Brancher** Ethernet
3. **Brancher** alimentation USB-C
4. **Attendre** ~2 min (boot initial)

---

#### Étape 0.3 : Se Connecter en SSH

**Trouver l'IP du Pi** :

Option A - Via interface box :
- Freebox : http://mafreebox.freebox.fr
- Livebox : http://192.168.1.1
- Chercher "pi5-homelab" dans appareils connectés

Option B - Scan réseau :
```bash
# Sur votre PC (nécessite nmap)
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"
```

**Connexion SSH** :
```bash
ssh pi@192.168.1.XXX
# Mot de passe : celui défini dans Imager
```

✅ **Vous êtes connecté !** Passez à Phase 1.

---

### ═══════════════════════════════════════
### PHASE 1 : Supabase Stack (~40 min)
### ═══════════════════════════════════════

#### Étape 1.1 : Prérequis & Infrastructure (20 min + reboot)

**Sur le Pi (via SSH)** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/01-prerequisites-setup.sh | sudo bash
```

**Ce script fait** :
- ✅ Mise à jour système (apt update/upgrade)
- ✅ Sécurité (UFW firewall, Fail2ban, SSH hardening)
- ✅ Installation Docker + Docker Compose
- ✅ Installation Portainer (http://IP:8080)
- ✅ Fix page size kernel (16KB → 4KB pour PostgreSQL)
- ✅ Optimisations RAM Pi 5

**Durée** : ~15-20 min

**À la fin, le script demande** :
```
⚠️  REBOOT REQUIRED - Changes will take effect after reboot
Do you want to reboot now? (y/n):
```

→ Tapez `y` et appuyez sur Entrée

**⏳ Attendre ~2 min** (reboot)

---

#### Étape 1.2 : Reconnecter SSH

```bash
ssh pi@192.168.1.XXX
```

---

#### Étape 1.3 : Déploiement Supabase (20 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

**Ce script fait** :
- ✅ Clonage repo Supabase
- ✅ Génération mots de passe sécurisés
- ✅ Configuration docker-compose.yml
- ✅ Téléchargement images Docker ARM64 (~5-10 min)
- ✅ Lancement de tous les services
- ✅ Healthcheck (vérification que tout fonctionne)
- ✅ Affichage des credentials (API keys, passwords)

**Durée** : ~15-20 min

**À la fin, COPIER et SAUVEGARDER** :
```
═════════════════════════════════════════════════
📋 SUPABASE DEPLOYMENT SUMMARY
═════════════════════════════════════════════════

🌐 Access URLs:
   Studio UI    : http://192.168.1.XXX:8000
   API URL      : http://192.168.1.XXX:8000

🔑 API Keys:
   ANON_KEY     : eyJhbGciOiJI...
   SERVICE_KEY  : eyJhbGciOiJI...

📊 Portainer   : http://192.168.1.XXX:8080

⚠️  SAVE THESE CREDENTIALS - They won't be shown again!
```

**→ Sauvegarder dans un fichier sécurisé (gestionnaire de mots de passe)**

---

#### Étape 1.4 : Vérifier Installation

**Tester Supabase Studio** :
```
http://192.168.1.XXX:8000
```

Vous devriez voir l'interface Supabase Studio. ✅

---

#### Étape 1.5 : Activer Sauvegardes Automatiques (3 min)

```bash
sudo ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-scheduler.sh
```

**Le script demande** :
```
Select backup frequency:
1) Daily
2) Weekly
3) Custom
Choice: 1
```

→ Tapez `1` (Daily recommandé)

**Le script configure** :
- ✅ Backup quotidien à 2h du matin
- ✅ Healthcheck quotidien
- ✅ Rotation GFS (7 daily, 4 weekly, 12 monthly)
- ✅ Systemd timers

**Vérifier** :
```bash
systemctl list-timers | grep supabase
```

Vous devriez voir :
```
supabase-backup.timer
supabase-healthcheck.timer
```

✅ **Phase 1 terminée !** Supabase fonctionne en local.

---

### ═══════════════════════════════════════
### PHASE 2 : Traefik + HTTPS (~30 min)
### ═══════════════════════════════════════

#### Choix du Scénario

**Relire** : [Comparaison des scénarios](01-infrastructure/traefik/docs/SCENARIOS-COMPARISON.md)

**Choisir UN scénario** :
- 🟢 DuckDNS → Étape 2.A
- 🔵 Cloudflare → Étape 2.B
- 🟡 VPN → Étape 2.C

---

### Étape 2.A : Scénario DuckDNS (15 min)

#### 2.A.1 : Créer compte DuckDNS (2 min)

1. Aller sur [duckdns.org](https://www.duckdns.org)
2. Se connecter avec GitHub/Google
3. Créer un sous-domaine : `monpi` (ou votre choix)
4. **Noter le token** affiché en haut de la page

#### 2.A.2 : Configurer box Internet (5 min)

**Ouvrir ports** (voir manuel de votre box) :
- Port **80** (HTTP) → 192.168.1.XXX:80
- Port **443** (HTTPS) → 192.168.1.XXX:443

**Guides par opérateur** :
- [Freebox](https://www.free.fr/assistance/2305-redirection-de-ports.html)
- [Livebox Orange](https://assistance.orange.fr/livebox-modem/toutes-les-livebox-et-modems/installer-et-utiliser/piloter-et-parametrer-votre-materiel/le-parametrage-avance-reseau-nat-pat-ip/ouvrir-un-port_188149-736682)
- [SFR Box](https://www.sfr.fr/assistance/box-nb6/internet/configuration-avancee-box/nat-pat.html)

#### 2.A.3 : Installer Traefik (5 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Le script demande** :
```
Enter your DuckDNS subdomain (without .duckdns.org): monpi
Enter your DuckDNS token: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Enter your email for Let's Encrypt: votre@email.com
```

**Attendre** ~2-3 min (génération certificat Let's Encrypt)

#### 2.A.4 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

**Le script détecte** automatiquement le scénario DuckDNS.

#### 2.A.5 : Tester

**Depuis n'importe où (même 4G)** :
```
https://monpi.duckdns.org/studio   → Supabase Studio ✅
https://monpi.duckdns.org/api      → Supabase API ✅
https://monpi.duckdns.org/traefik  → Traefik Dashboard ✅
```

✅ **Phase 2.A terminée !** Accès HTTPS public fonctionnel.

**→ Passer à Phase 3**

---

### Étape 2.B : Scénario Cloudflare (25 min)

#### 2.B.1 : Acheter un domaine (5 min)

**Registrars recommandés** :
- [OVH](https://www.ovh.com) : ~8€/an (.fr)
- [Porkbun](https://porkbun.com) : ~9€/an
- [Namecheap](https://namecheap.com) : ~10€/an

Acheter un domaine (ex: `monpi.fr`)

#### 2.B.2 : Configurer Cloudflare (10 min)

1. Créer compte sur [cloudflare.com](https://www.cloudflare.com)
2. Ajouter votre domaine (plan **Free**)
3. Changer nameservers chez votre registrar vers Cloudflare
4. Attendre propagation DNS (~30 min, vous pouvez continuer pendant ce temps)
5. Créer API Token :
   - Profil → API Tokens → Create Token
   - Template : "Edit zone DNS"
   - **Copier le token**

**Ajouter enregistrements DNS** :
- Type `A` → `@` → Votre IP publique → DNS only (🟠)
- Type `A` → `*` → Votre IP publique → DNS only (🟠)

#### 2.B.3 : Configurer box Internet (5 min)

Même que DuckDNS (ports 80 et 443)

#### 2.B.4 : Installer Traefik (3 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

**Le script demande** :
```
Enter your domain (e.g., monpi.fr): monpi.fr
Enter your Cloudflare API token: aBcD1234EfGh5678...
Enter your email for Let's Encrypt: votre@email.com
```

#### 2.B.5 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

**Le script demande** :
```
Enter subdomain for API (default: api): api
Enter subdomain for Studio (default: studio): studio
```

→ Appuyer Entrée pour utiliser les valeurs par défaut

#### 2.B.6 : Tester

```
https://studio.monpi.fr   → Supabase Studio ✅
https://api.monpi.fr      → Supabase API ✅
https://traefik.monpi.fr  → Traefik Dashboard ✅
```

✅ **Phase 2.B terminée !** Sous-domaines HTTPS fonctionnels.

**→ Passer à Phase 3**

---

### Étape 2.C : Scénario VPN (30 min)

#### 2.C.1 : Installer Tailscale sur le Pi (3 min)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**Suivre le lien** affiché pour s'authentifier.

**Noter l'IP Tailscale** :
```bash
tailscale ip -4
```
→ Exemple : `100.64.1.5`

#### 2.C.2 : Installer Tailscale sur vos appareils (5 min)

**PC/Mac** :
- Télécharger [Tailscale](https://tailscale.com/download)
- Se connecter avec même compte

**Smartphone** :
- Android : [Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn)
- iOS : [App Store](https://apps.apple.com/app/tailscale/id1470499037)

#### 2.C.3 : Installer Traefik (VPN mode) (5 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

**Le script demande** :
```
Enter VPN network CIDR (default: 100.64.0.0/10 for Tailscale): [Entrée]
Enter local domain (default: pi.local): [Entrée]
Certificate type (1: self-signed, 2: mkcert): 1
```

#### 2.C.4 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash
```

#### 2.C.5 : Configurer /etc/hosts (2 min)

**Sur chaque appareil connecté au VPN** :

Linux/macOS :
```bash
sudo nano /etc/hosts
```

Windows (Notepad en Administrateur) :
```
C:\Windows\System32\drivers\etc\hosts
```

**Ajouter** :
```
100.64.1.5  pi.local studio.pi.local api.pi.local traefik.pi.local
```

(Remplacer `100.64.1.5` par l'IP Tailscale de votre Pi)

#### 2.C.6 : Tester

**Depuis un appareil connecté au VPN** :
```
https://studio.pi.local   → Warning certificat → Accepter ✅
https://api.pi.local      ✅
https://traefik.pi.local  ✅
```

✅ **Phase 2.C terminée !** Accès VPN sécurisé fonctionnel.

---

### ═══════════════════════════════════════
### PHASE 3 : Finalisation & Vérification
### ═══════════════════════════════════════

#### Étape 3.1 : Tester l'Installation Complète

**Vérifier tous les services** :

1. **Supabase Studio** :
   - Se connecter
   - Créer une table test
   - Insérer des données

2. **Supabase API** :
   ```bash
   curl https://VOTRE_URL/rest/v1/
   ```
   → Doit retourner une réponse (même si vide)

3. **Traefik Dashboard** :
   - Login avec credentials affichés lors installation
   - Vérifier que tous les routers sont verts

4. **Portainer** :
   - Se connecter sur http://IP:8080
   - Voir tous les containers running

#### Étape 3.2 : Sauvegarder les Credentials

**Créer un fichier de credentials** :

```bash
nano ~/PI5-CREDENTIALS.txt
```

**Copier toutes les infos** :
```
═══════════════════════════════════════
RASPBERRY PI 5 HOMELAB - CREDENTIALS
═══════════════════════════════════════

📍 IP Locale: 192.168.1.XXX
📍 IP Tailscale (si VPN): 100.64.1.XX

🌐 URLs:
- Supabase Studio: https://...
- Supabase API: https://...
- Traefik Dashboard: https://...
- Portainer: http://IP:8080

🔑 Supabase:
- ANON_KEY: eyJhbGci...
- SERVICE_KEY: eyJhbGci...
- JWT_SECRET: xxx
- DB Password: xxx

🔑 Traefik Dashboard:
- User: admin
- Password: xxx

🔑 DuckDNS (si applicable):
- Subdomain: monpi
- Token: xxx

🔑 Cloudflare (si applicable):
- Domain: monpi.fr
- API Token: xxx

📅 Date installation: 2025-XX-XX
```

**Sauvegarder** : Ctrl+O, Entrée, Ctrl+X

**Copier sur votre PC** :
```bash
scp pi@192.168.1.XXX:~/PI5-CREDENTIALS.txt ~/Desktop/
```

**⚠️ IMPORTANT** : Stocker dans un gestionnaire de mots de passe (Bitwarden, 1Password, etc.)

---

#### Étape 3.3 : Vérifier les Sauvegardes

```bash
# Vérifier que les timers sont actifs
systemctl list-timers | grep supabase

# Voir les logs du dernier backup
journalctl -u supabase-backup.service -n 50
```

---

#### Étape 3.4 : Tester un Backup Manuel

```bash
sudo ~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh
```

**Vérifier** :
```bash
ls -lh ~/backups/supabase/daily/
```

Vous devriez voir un fichier `.tar.gz` récent. ✅

---

## 🎉 Installation Terminée !

### Ce que vous avez maintenant

✅ **Raspberry Pi 5 sécurisé**
- Firewall UFW actif
- Fail2ban contre bruteforce
- SSH hardening

✅ **Supabase Stack complet**
- PostgreSQL 15 + extensions
- Auth, REST API, Realtime, Storage
- Studio UI
- Edge Functions

✅ **Traefik + HTTPS**
- Certificats SSL automatiques
- Accès depuis partout (ou VPN)
- Dashboard de monitoring

✅ **Sauvegardes automatiques**
- Daily backups
- Rotation GFS
- Healthchecks quotidiens

✅ **Portainer**
- Gestion Docker via UI

---

## 🎯 Prochaines Étapes (Optionnel)

L'installation de base (Phases 0-2) est terminée ! Vous pouvez maintenant installer les **stacks additionnels** selon vos besoins.

### 🎛️ Stack Manager - Gestion RAM/Boot

**IMPORTANT** : Avant d'installer plus de stacks, installez le Stack Manager pour gérer facilement la RAM :

```bash
# Mode interactif (recommandé)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh interactive

# Voir état de tous les stacks
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status

# Gérer RAM (start/stop stacks)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin  # Libère RAM
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh start jellyfin # Redémarre
```

**Documentation** : [common-scripts/STACK-MANAGER.md](common-scripts/STACK-MANAGER.md)

---

### Phase 2b : Homepage (Dashboard) - 5 min

**Portail d'accueil centralisé** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/08-interface/homepage/scripts/01-homepage-deploy.sh | sudo bash
```

**Accès** :
- DuckDNS : `https://monpi.duckdns.org`
- Cloudflare : `https://monpi.fr` ou `https://home.monpi.fr`

---

### Phase 3 : Monitoring (Prometheus + Grafana) - 5 min

**Dashboards système + Docker + PostgreSQL** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/03-monitoring/prometheus-grafana/scripts/01-monitoring-deploy.sh | sudo bash
```

**Accès Grafana** :
- DuckDNS : `https://monpi.duckdns.org/grafana`
- Cloudflare : `https://grafana.monpi.fr`

**RAM** : ~1.1 GB

---

### Phase 4 : VPN (Tailscale) - 10 min

**Accès sécurisé distant** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/vpn-wireguard/scripts/01-tailscale-setup.sh | sudo bash
```

**RAM** : ~50 MB

---

### Phase 5 : Gitea (Git + CI/CD) - 20 min

**GitHub-like self-hosted + Actions** :
```bash
# Gitea + PostgreSQL
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/01-gitea-deploy.sh | sudo bash

# CI/CD Runner (optionnel)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/04-developpement/gitea/scripts/02-runners-setup.sh | sudo bash
```

**RAM** : ~450 MB

---

### Phase 6 : Backups Offsite (rclone → R2/B2) - 15 min

**Sauvegardes cloud** :
```bash
# Configuration rclone (R2/B2/S3)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/01-rclone-setup.sh | sudo bash

# Activer backups offsite Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/09-backups/restic-offsite/scripts/02-enable-offsite-backups.sh | sudo bash
```

---

### Phase 7 : Storage Cloud (FileBrowser ou Nextcloud) - 15 min

**Option 1 - FileBrowser (léger)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/01-filebrowser-deploy.sh | sudo bash
```
**RAM** : ~50 MB

**Option 2 - Nextcloud (complet)** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/05-stockage/filebrowser-nextcloud/scripts/02-nextcloud-deploy.sh | sudo bash
```
**RAM** : ~500 MB

---

### Phase 8 : Media Server (Jellyfin + *arr) - 20 min

**Netflix-like + automatisation** :
```bash
# Jellyfin (serveur média)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/01-jellyfin-deploy.sh | sudo bash

# *arr Stack (Radarr, Sonarr, Prowlarr) - optionnel
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/06-media/jellyfin-arr/scripts/02-arr-stack-deploy.sh | sudo bash
```

**RAM** : ~800 MB (total)

---

### Phase 9 : Auth SSO (Authelia + 2FA) - 10 min

**Authentification centralisée** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/02-securite/authelia/scripts/01-authelia-deploy.sh | sudo bash
```

**RAM** : ~150 MB

---

### Phase 10 : Domotique (Home Assistant) - 10 min

**Hub domotique + automatisations** :
```bash
# Configuration minimale (Home Assistant + MQTT + Node-RED)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/01-homeassistant-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/03-mqtt-deploy.sh | sudo bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/02-nodered-deploy.sh | sudo bash
```

**Accès** :
- Home Assistant : `http://raspberrypi.local:8123`
- Node-RED : `http://raspberrypi.local:1880`

**RAM** : ~630 MB

**Optionnel - Zigbee2MQTT** (nécessite dongle Zigbee USB ~20€) :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/07-domotique/homeassistant/scripts/04-zigbee2mqtt-deploy.sh | sudo bash
```

**Fonctionnalités** :
- ✅ 2000+ intégrations (Philips Hue, Xiaomi, Sonoff, Google Home, Alexa)
- ✅ Automatisations visuelles
- ✅ Dashboard personnalisable
- ✅ Commande vocale
- ✅ Contrôle Zigbee sans hubs propriétaires (économie ~100€)

---

### 📊 Estimation RAM Totale

| Configuration | Stacks | RAM Utilisée | RAM Disponible |
|---------------|--------|--------------|----------------|
| **Minimal** (Backend) | Supabase + Traefik + Homepage | ~2.5 GB | ~13.5 GB |
| **Standard** (+ Monitoring) | + Prometheus/Grafana | ~3.6 GB | ~12.4 GB |
| **Complet** (10 phases) | Toutes phases sauf domotique | ~4.5 GB | ~11.5 GB |
| **Complet + Domotique** | Toutes phases + Home Assistant | ~5.1 GB | ~10.9 GB |

**Astuce** : Utilisez le **Stack Manager** pour arrêter les stacks non utilisés et libérer de la RAM !

---

**Voir** : [ROADMAP complète](ROADMAP.md) pour tous les détails

---

## 🆘 Problèmes Courants

### "Cannot connect via SSH"

**Vérifier** :
```bash
# Sur votre PC, trouver l'IP du Pi
nmap -sn 192.168.1.0/24 | grep -B 2 Raspberry

# Ping le Pi
ping 192.168.1.XXX
```

**Si pas de réponse** :
- Vérifier câble Ethernet
- Vérifier que le Pi boot (LED verte clignote)
- Connecter écran HDMI + clavier

---

### "Docker containers not starting"

```bash
# Voir logs
docker compose -f ~/stacks/supabase/docker-compose.yml logs -f

# Redémarrer
docker compose -f ~/stacks/supabase/docker-compose.yml restart
```

---

### "ERR_SSL_PROTOCOL_ERROR"

**Attendre 2-3 min** que Let's Encrypt génère le certificat.

**Vérifier logs Traefik** :
```bash
docker logs traefik -f
```

Chercher : `"Obtained certificate"` → OK ✅

---

### "Cannot access Supabase Studio"

**Vérifier firewall** :
```bash
sudo ufw status
```

**Si port 8000 fermé** :
```bash
sudo ufw allow 8000/tcp
```

---

### "Pi ralentit / Pas assez de RAM"

**Utiliser le Stack Manager pour libérer de la RAM** :

```bash
# Voir consommation RAM par stack
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh ram

# Arrêter stacks non utilisés
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop jellyfin
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop nextcloud
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh stop gitea

# Vérifier RAM disponible
free -h
```

**Désactiver démarrage auto des stacks gourmands** :
```bash
# Désactiver au boot (démarrage manuel quand nécessaire)
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable jellyfin
sudo ~/pi5-setup/common-scripts/09-stack-manager.sh disable monitoring
```

**Documentation** : [common-scripts/STACK-MANAGER.md](common-scripts/STACK-MANAGER.md)

---

## 📚 Documentation Complète

### Par Phase
- [Phase 1 : Supabase](01-infrastructure/supabase/README.md)
- [Phase 2 : Traefik](01-infrastructure/traefik/README.md)
- [Roadmap complète](ROADMAP.md)

### Guides Débutants
- [Supabase pour débutants](01-infrastructure/supabase/GUIDE-DEBUTANT.md)
- [Traefik pour débutants](01-infrastructure/traefik/GUIDE-DEBUTANT.md)

### Maintenance
- [Sauvegardes Supabase](01-infrastructure/supabase/scripts/maintenance/README.md)
- [Scripts communs](common-scripts/README.md)
- [Stack Manager - Gestion RAM/Boot](common-scripts/STACK-MANAGER.md)

---

## ✅ Checklist Post-Installation

### Installation de Base (Phases 0-2)
- [ ] Supabase Studio accessible
- [ ] API Supabase fonctionne
- [ ] HTTPS actif (cadenas vert)
- [ ] Traefik Dashboard accessible
- [ ] Portainer accessible
- [ ] Sauvegardes automatiques activées
- [ ] Credentials sauvegardés en sécurité
- [ ] Test backup manuel réussi
- [ ] Firewall UFW actif
- [ ] Fail2ban actif

### Gestion Avancée (Recommandé)
- [ ] Stack Manager testé (`sudo ~/pi5-setup/common-scripts/09-stack-manager.sh status`)
- [ ] Configuration démarrage auto optimisée (stacks essentiels seulement)
- [ ] Consommation RAM vérifiée (`free -h` → <50% utilisé recommandé)

---

**Félicitations ! Votre Raspberry Pi 5 est maintenant un serveur de développement complet ! 🎉**

**Besoin d'aide ?** Consultez la [documentation complète](README.md) ou ouvrez une [issue GitHub](https://github.com/iamaketechnology/pi5-setup/issues).
