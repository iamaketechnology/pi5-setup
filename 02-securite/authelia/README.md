# 🔐 Authentification Centralisée sur Raspberry Pi 5

> **Stack SSO + 2FA avec Authelia pour sécuriser tous vos services auto-hébergés**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Authelia](https://img.shields.io/badge/Authelia-Latest-5A67D8.svg)](https://www.authelia.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## 📖 Table des Matières

- [Vue d'Ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Architecture](#-architecture)
- [Installation Rapide](#-installation-rapide)
- [Configuration 2FA](#-configuration-2fa)
- [Intégration Traefik](#-intégration-traefik)
- [Protection des Services](#-protection-des-services)
- [Gestion des Utilisateurs](#-gestion-des-utilisateurs)
- [Règles d'Accès](#-règles-daccès)
- [Comparaison SSO](#-comparaison-sso)
- [Cas d'Usage](#-cas-dusage)
- [Maintenance](#-maintenance)
- [Ressources Système](#-ressources-système)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)

---

## 🎯 Vue d'Ensemble

**Pi5-Auth-Stack** est une solution d'authentification centralisée basée sur **Authelia** et **Redis**, offrant du **Single Sign-On (SSO)** et de l'**authentification à deux facteurs (2FA)** pour tous vos services auto-hébergés sur Raspberry Pi 5.

### Pourquoi ce Stack ?

**Sans authentification centralisée** :
```
Grafana      → Login séparé (admin/password1)
Portainer    → Login séparé (admin/password2)
Traefik      → Login séparé (admin/password3)
Supabase     → Login séparé (admin/password4)
→ 4 mots de passe différents à retenir
→ Aucune protection 2FA
→ Pas de gestion centralisée
```

**Avec Authelia** :
```
Authelia SSO → Login unique (admin + code 2FA)
             ↓
             ├── Grafana      ✅ Accès automatique
             ├── Portainer    ✅ Accès automatique
             ├── Traefik      ✅ Accès automatique
             └── Supabase     ✅ Accès automatique

→ 1 seul login pour tous les services
→ Protection 2FA/TOTP obligatoire
→ Gestion centralisée des utilisateurs
→ Contrôle d'accès granulaire par service
```

### Avantages Authelia

- ✅ **Installation en 1 commande** - Déploiement automatisé, zéro configuration manuelle
- ✅ **SSO universel** - Un seul login pour tous vos services
- ✅ **2FA/TOTP intégré** - Google Authenticator, Authy, Microsoft Authenticator
- ✅ **Protection brute-force** - Bannissement automatique après 3 tentatives
- ✅ **Sessions sécurisées** - Stockage Redis avec expiration automatique
- ✅ **Intégration Traefik** - Auto-détection scénario (DuckDNS/Cloudflare/VPN)
- ✅ **Léger** - ~150 MB RAM (Authelia 100 MB + Redis 50 MB)
- ✅ **Open Source** - 100% gratuit, auditable

### Que Protège-t-on ?

| Service | Sans Authelia | Avec Authelia |
|---------|---------------|---------------|
| **Grafana** | Accès public ou login simple | Login + 2FA obligatoire |
| **Portainer** | Accès public dangereux | Login + 2FA obligatoire |
| **Traefik Dashboard** | Exposé sans protection | Login + 2FA obligatoire |
| **Prometheus** | Métriques accessibles | Login + 2FA obligatoire |
| **Supabase Studio** | Login simple | Login + 2FA obligatoire |

---

## 🚀 Fonctionnalités

### Core Features

- 🔐 **Single Sign-On (SSO)** - Authentification unique pour tous les services
- 🔑 **Two-Factor Authentication (2FA/TOTP)** - Code à 6 chiffres via app mobile
- 🛡️ **Protection Brute-Force** - 3 tentatives max, ban 5 minutes
- 💾 **Session Management** - Redis pour stockage rapide et sécurisé
- 👥 **Multi-utilisateurs** - Gestion centralisée des comptes
- 🔒 **Access Control Lists (ACLs)** - Contrôle granulaire par service/utilisateur
- 📧 **Notifications** - Alertes connexions suspectes (SMTP optionnel)

### Auto-Détection Intelligente

Le script détecte automatiquement :
- ✅ **Traefik installé ?** → Configure domaines et certificats SSL
- ✅ **Scénario Traefik ?** → Adapte config (DuckDNS/Cloudflare/VPN)
- ✅ **Services protégeables ?** → Liste Grafana, Portainer, Prometheus, etc.

### Applications d'Authentification Supportées

| App | Plateforme | Gratuit | Recommandé |
|-----|-----------|---------|------------|
| **Google Authenticator** | iOS, Android | ✅ | ⭐⭐⭐ Débutants |
| **Authy** | iOS, Android, Desktop | ✅ | ⭐⭐⭐⭐ Multi-device |
| **Microsoft Authenticator** | iOS, Android | ✅ | ⭐⭐⭐ Ecosystème MS |
| **Bitwarden** | Tous | ✅ | ⭐⭐⭐⭐⭐ Gestionnaire passwords |
| **1Password** | Tous | 💰 Payant | ⭐⭐⭐⭐ Premium |

---

## 🏗️ Architecture

### Stack Docker Compose

```
authelia/
├── authelia         # Serveur SSO + 2FA (port 9091)
└── redis           # Stockage sessions (port 6379)
```

### Flux d'Authentification

```
┌─────────────────────────────────────────────────────────────┐
│                    Utilisateur se connecte                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
             ┌───────────────────────┐
             │   Traefik (Reverse    │
             │      Proxy)           │
             └───────────┬───────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │   Middleware Authelia          │
        │   (ForwardAuth Check)          │
        └────────┬──────────────┬────────┘
                 │              │
          ❌ Non authentifié   ✅ Authentifié
                 │              │
                 ▼              ▼
        ┌────────────────┐  ┌──────────────┐
        │   Authelia     │  │   Service    │
        │   Login Page   │  │  (Grafana,   │
        │                │  │  Portainer)  │
        │ 1. Username +  │  │              │
        │    Password    │  │   Accès      │
        │                │  │   direct     │
        │ 2. Code TOTP   │  │              │
        │    (6 chiffres)│  │              │
        └────────┬───────┘  └──────────────┘
                 │
                 ▼
        ┌────────────────┐
        │  Redis Session │
        │    Storage     │
        │  (1h expiry)   │
        └────────────────┘
```

### Processus Login Détaillé

**Étape 1 : Accès au service**
```
Utilisateur → https://grafana.mondomaine.com
          ↓
Traefik → Middleware Authelia vérifie session
       ↓
Pas de session valide → Redirection vers Authelia
```

**Étape 2 : Première authentification (Username + Password)**
```
Authelia → Page login
        ↓
Utilisateur entre : admin / password
                 ↓
Authelia vérifie users_database.yml
         ↓
Hash Argon2id validé → Demande 2FA
```

**Étape 3 : Deuxième authentification (TOTP)**
```
Authelia → Page 2FA
        ↓
Utilisateur ouvre Google Authenticator
         ↓
Entre code 6 chiffres (ex: 123456)
         ↓
Authelia vérifie code TOTP
         ↓
Code valide → Crée session Redis
```

**Étape 4 : Accès au service**
```
Session créée → Cookie authelia_session
            ↓
Redirection vers Grafana
            ↓
Traefik vérifie session (via middleware)
            ↓
Session valide → Accès direct à Grafana
```

### Arborescence Fichiers

```
~/stacks/authelia/
├── docker-compose.yml              # Stack Authelia + Redis
├── .env                            # Variables + secrets (chmod 600)
├── config/
│   ├── configuration.yml           # Config Authelia principale
│   ├── users_database.yml          # Base utilisateurs (Argon2id hash)
│   └── CREDENTIALS.txt             # Login admin initial (chmod 600)
├── data/
│   ├── db.sqlite3                  # Base SQLite (2FA secrets, etc.)
│   └── notification.txt            # Notifications (si SMTP désactivé)
└── redis/
    └── dump.rdb                    # Sauvegarde sessions Redis
```

---

## ⚡ Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec Raspberry Pi OS 64-bit
- ✅ Docker + Docker Compose installés ([01-prerequisites-setup.sh](../common-scripts/01-prerequisites-setup.sh))
- ✅ **Traefik installé** (Phase 2, obligatoire)
- ✅ Smartphone avec app authentification (Google Authenticator, Authy)

**⚠️ IMPORTANT** : Authelia nécessite Traefik pour fonctionner. Installez Traefik d'abord :
```bash
# Scénario DuckDNS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# Scénario Cloudflare
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash

# Scénario VPN
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

### Installation Simple (Curl One-Liner)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-auth-stack/scripts/01-authelia-deploy.sh | sudo bash
```

**Durée** : ~3-4 minutes

### Installation Avancée (avec Options)

```bash
# Télécharger le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-auth-stack/scripts/01-authelia-deploy.sh -o authelia-deploy.sh
chmod +x authelia-deploy.sh

# Dry-run (simulation)
sudo ./authelia-deploy.sh --dry-run --verbose

# Installation avec protection automatique de services
sudo PROTECTED_SERVICES="grafana,portainer,traefik" ./authelia-deploy.sh

# Installation custom
sudo AUTH_DOMAIN="auth.mondomaine.com" \
     ADMIN_USERNAME="superadmin" \
     ADMIN_EMAIL="admin@mondomaine.com" \
     ./authelia-deploy.sh
```

### Ce que fait le Script

1. ✅ Détecte scénario Traefik (DuckDNS/Cloudflare/VPN)
2. ✅ Génère secrets sécurisés (JWT, Session, Encryption)
3. ✅ Crée répertoire `~/stacks/authelia/`
4. ✅ Génère configuration Authelia (ACLs, TOTP, Redis)
5. ✅ Génère mot de passe admin aléatoire (20 caractères)
6. ✅ Hash mot de passe avec Argon2id
7. ✅ Configure middleware Traefik ForwardAuth
8. ✅ Démarre Authelia + Redis
9. ✅ Affiche URL + credentials admin

### Accès Après Installation

**URL Authelia selon scénario** :

| Scénario | URL Authelia |
|----------|--------------|
| **DuckDNS** | `https://auth.votresubdomain.duckdns.org` |
| **Cloudflare** | `https://auth.votredomaine.com` |
| **VPN** | `http://auth.pi.local` |

**Credentials admin** :
- Affichés dans le terminal après installation
- Sauvegardés dans `~/stacks/authelia/config/CREDENTIALS.txt`
- Exemple : `admin` / `aB3cD5eF7gH9jK2lM4nP` (généré aléatoirement)

---

## 🔐 Configuration 2FA

### Pourquoi 2FA/TOTP ?

**2FA (Two-Factor Authentication)** = Authentification à deux facteurs

**Sans 2FA** :
```
Hacker obtient mot de passe (phishing, fuite DB)
  ↓
Accède directement à tous vos services ❌
```

**Avec 2FA** :
```
Hacker obtient mot de passe
  ↓
Tente de se connecter
  ↓
Authelia demande code TOTP (6 chiffres)
  ↓
Hacker n'a pas accès à votre smartphone ✅
  ↓
Connexion refusée 🛡️
```

### Configuration Première Connexion

**Étape 1 : Se connecter à Authelia**

1. Ouvrir URL Authelia (voir installation ci-dessus)
2. Entrer credentials affichés après installation :
   ```
   Username : admin
   Password : aB3cD5eF7gH9jK2lM4nP
   ```

**Étape 2 : Activer 2FA (TOTP)**

3. Après login, redirection automatique vers page 2FA
4. Scanner QR code avec app :
   - **Google Authenticator** (iOS/Android)
   - **Authy** (iOS/Android/Desktop)
   - **Microsoft Authenticator** (iOS/Android)
5. Entrer code à 6 chiffres affiché dans l'app
6. Cliquer **Valider**

**Étape 3 : Sauvegarder codes de récupération**

7. Page affiche **codes de récupération** (ex: `ABCD-EFGH-IJKL`)
8. **TRÈS IMPORTANT** : Sauvegarder ces codes dans un endroit sûr
9. Si vous perdez smartphone, ces codes permettent de récupérer accès

**Étape 4 : Changer mot de passe (optionnel)**

10. Aller dans **Settings**
11. **Change Password**
12. Entrer nouveau mot de passe (min 8 caractères)
13. Confirmer avec code TOTP

### Applications TOTP Recommandées

**Google Authenticator** (Débutants)
- ✅ Simple d'utilisation
- ✅ Gratuit
- ❌ Pas de backup cloud (codes perdus si téléphone perdu)
- ❌ Un seul appareil

**Authy** (Recommandé)
- ✅ Backup cloud (récupération sur nouveau téléphone)
- ✅ Multi-device (smartphone + tablette + desktop)
- ✅ Protection par PIN
- ✅ Gratuit

**Bitwarden** (Avancé)
- ✅ Gestionnaire de mots de passe + TOTP
- ✅ Backup cloud chiffré
- ✅ Multi-device
- ✅ Open source
- ⚠️ Ne pas stocker password ET TOTP au même endroit (sécurité)

### Tester l'Authentification

**Test 1 : Connexion normale**
```bash
# Ouvrir navigateur en navigation privée
# Aller sur https://auth.votredomaine.com
# Login : admin / password
# 2FA : Code 6 chiffres de l'app
# → Accès autorisé ✅
```

**Test 2 : Code TOTP invalide**
```bash
# Login : admin / password
# 2FA : 000000 (code invalide)
# → Accès refusé ❌
# Message : "Invalid credentials"
```

**Test 3 : Protection brute-force**
```bash
# Login : admin / wrongpassword (3 fois)
# → Compte banni 5 minutes ⛔
# Message : "Account locked"
```

---

## 🔗 Intégration Traefik

Authelia s'intègre avec Traefik via le middleware **ForwardAuth**.

### Détection Automatique Scénario

Le script lit `/home/pi/stacks/traefik/.env` :

```bash
if grep -q "DUCKDNS_SUBDOMAIN" "$TRAEFIK_ENV"; then
    TRAEFIK_SCENARIO="duckdns"
elif grep -q "CLOUDFLARE_API_TOKEN" "$TRAEFIK_ENV"; then
    TRAEFIK_SCENARIO="cloudflare"
else
    TRAEFIK_SCENARIO="vpn"
fi
```

### Configuration par Scénario

#### Scénario 1 : DuckDNS (Gratuit)

**Domaines** :
- Authelia : `https://auth.votresubdomain.duckdns.org`
- Grafana : `https://votresubdomain.duckdns.org/grafana` (protégé)
- Portainer : `https://votresubdomain.duckdns.org/portainer` (protégé)

**Labels Traefik (Authelia)** :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.authelia.rule=Host(`auth.${DUCKDNS_SUBDOMAIN}.duckdns.org`)"
  - "traefik.http.routers.authelia.entrypoints=websecure"
  - "traefik.http.routers.authelia.tls.certresolver=letsencrypt"
  - "traefik.http.services.authelia.loadbalancer.server.port=9091"

  # Middleware ForwardAuth
  - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.${DUCKDNS_SUBDOMAIN}.duckdns.org"
  - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
  - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
```

#### Scénario 2 : Cloudflare (Domaine Perso)

**Domaines** :
- Authelia : `https://auth.votredomaine.com`
- Grafana : `https://grafana.votredomaine.com` (protégé)
- Portainer : `https://portainer.votredomaine.com` (protégé)

**DNS Cloudflare** (à configurer manuellement) :
```
Type: A
Name: auth
Content: <IP_PUBLIQUE>
Proxy: Enabled (orange cloud)
```

**Labels Traefik (Authelia)** :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.authelia.rule=Host(`auth.${DOMAIN}`)"
  - "traefik.http.routers.authelia.entrypoints=websecure"
  - "traefik.http.routers.authelia.tls.certresolver=cloudflare"
  - "traefik.http.services.authelia.loadbalancer.server.port=9091"

  # Middleware ForwardAuth
  - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.${DOMAIN}"
  - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
  - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
```

#### Scénario 3 : VPN (Local)

**Domaines** :
- Authelia : `http://auth.pi.local`
- Grafana : `http://grafana.pi.local` (protégé)
- Portainer : `http://portainer.pi.local` (protégé)

**Accès** : Via VPN (Tailscale/WireGuard) uniquement

**Labels Traefik (Authelia)** :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.authelia.rule=Host(`auth.${LOCAL_DOMAIN}`)"
  - "traefik.http.routers.authelia.entrypoints=web"
  - "traefik.http.services.authelia.loadbalancer.server.port=9091"

  # Middleware ForwardAuth
  - "traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=http://auth.${LOCAL_DOMAIN}"
  - "traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
  - "traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
```

---

## 🛡️ Protection des Services

### Middleware Authelia

Le script crée automatiquement le middleware dans `/home/pi/stacks/traefik/dynamic/authelia-middleware.yml` :

```yaml
http:
  middlewares:
    authelia:
      forwardAuth:
        address: "http://authelia:9091/api/verify?rd=https://auth.votredomaine.com"
        trustForwardHeader: true
        authResponseHeaders:
          - "Remote-User"
          - "Remote-Groups"
          - "Remote-Name"
          - "Remote-Email"
```

### Protéger un Service Manuellement

**Exemple : Protéger Grafana**

1. **Éditer docker-compose.yml du service** :
   ```bash
   cd ~/stacks/monitoring
   nano docker-compose.yml
   ```

2. **Ajouter middleware aux labels Traefik** :
   ```yaml
   services:
     grafana:
       labels:
         - "traefik.enable=true"
         - "traefik.http.routers.grafana.rule=Host(`grafana.votredomaine.com`)"
         - "traefik.http.routers.grafana.entrypoints=websecure"
         - "traefik.http.routers.grafana.tls.certresolver=cloudflare"

         # AJOUTER CETTE LIGNE
         - "traefik.http.routers.grafana.middlewares=authelia@file"
   ```

3. **Redémarrer service** :
   ```bash
   docker compose restart grafana
   ```

4. **Tester** :
   - Ouvrir `https://grafana.votredomaine.com`
   - Redirection automatique vers Authelia
   - Login + 2FA → Accès à Grafana ✅

### Protéger Automatiquement à l'Installation

```bash
# Protéger plusieurs services d'un coup
PROTECTED_SERVICES="grafana,portainer,traefik,prometheus" sudo ./01-authelia-deploy.sh
```

**Services supportés** :
- `grafana` - Dashboards métriques
- `portainer` - Gestion Docker
- `traefik` - Dashboard Traefik
- `prometheus` - Métriques brutes

### Services à Protéger en Priorité

| Service | Raison | Danger si non-protégé |
|---------|--------|----------------------|
| **Portainer** | Contrôle total Docker | Attaquant peut déployer malware |
| **Traefik Dashboard** | Config reverse proxy | Attaquant peut rediriger trafic |
| **Prometheus** | Métriques sensibles | Fuite d'informations système |
| **Supabase Studio** | Accès base de données | Lecture/modification données |
| **Grafana** | Dashboards internes | Fuite d'informations monitoring |

### Services à NE PAS Protéger

| Service | Raison |
|---------|--------|
| **Homepage** | Dashboard d'accueil (doit rester public) |
| **API publiques** | Endpoints publics (ex: blog, portfolio) |
| **Webhooks** | Services externes (GitHub, Stripe, etc.) |

---

## 👥 Gestion des Utilisateurs

### Fichier users_database.yml

**Localisation** : `~/stacks/authelia/config/users_database.yml`

**Structure** :
```yaml
users:
  admin:
    displayname: "Administrator"
    password: "$argon2id$v=19$m=65536,t=1,p=8$..."
    email: "admin@example.com"
    groups:
      - admins

  alice:
    displayname: "Alice Dupont"
    password: "$argon2id$v=19$m=65536,t=1,p=8$..."
    email: "alice@example.com"
    groups:
      - users
```

### Ajouter un Utilisateur

**Étape 1 : Générer hash du mot de passe**
```bash
# Remplacer PASSWORD_ALICE par le mot de passe souhaité
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password PASSWORD_ALICE
```

**Output** :
```
Password hash: $argon2id$v=19$m=65536,t=1,p=8$abc123...xyz789
```

**Étape 2 : Éditer users_database.yml**
```bash
cd ~/stacks/authelia
nano config/users_database.yml
```

**Ajouter** :
```yaml
users:
  admin:
    # ... (existant)

  alice:  # Nouveau user
    displayname: "Alice Dupont"
    password: "$argon2id$v=19$m=65536,t=1,p=8$abc123...xyz789"
    email: "alice@example.com"
    groups:
      - users  # Groupe "users" (accès limité)
```

**Étape 3 : Redémarrer Authelia**
```bash
docker compose restart authelia
```

**Étape 4 : Test**
- Alice se connecte à `https://auth.votredomaine.com`
- Login : `alice` / `PASSWORD_ALICE`
- Configure 2FA (scan QR code)
- Accès aux services autorisés ✅

### Groupes Utilisateurs

**Deux groupes par défaut** :

| Groupe | Permissions | Use Case |
|--------|-------------|----------|
| **admins** | Accès complet à tous les services | Vous, co-admins |
| **users** | Accès limité selon ACLs | Famille, amis, utilisateurs externes |

**Exemple ACL** :
```yaml
# Admins : accès complet
- domain: "*.votredomaine.com"
  policy: two_factor
  subject:
    - "group:admins"

# Users : accès Homepage et Grafana uniquement
- domain:
    - "homepage.votredomaine.com"
    - "grafana.votredomaine.com"
  policy: two_factor
  subject:
    - "group:users"
```

### Supprimer un Utilisateur

1. **Éditer users_database.yml** :
   ```bash
   nano ~/stacks/authelia/config/users_database.yml
   ```

2. **Supprimer section utilisateur** :
   ```yaml
   users:
     admin:
       # ... (garder)

     # alice:  # Supprimer ou commenter
     #   displayname: "Alice Dupont"
     #   ...
   ```

3. **Redémarrer Authelia** :
   ```bash
   cd ~/stacks/authelia
   docker compose restart authelia
   ```

### Réinitialiser Mot de Passe Utilisateur

**Scénario** : Utilisateur a oublié son mot de passe

1. **Générer nouveau hash** :
   ```bash
   docker run --rm authelia/authelia:latest \
     authelia crypto hash generate argon2 --password NEW_PASSWORD
   ```

2. **Éditer users_database.yml** :
   ```bash
   nano ~/stacks/authelia/config/users_database.yml
   ```

3. **Remplacer hash** :
   ```yaml
   alice:
     password: "$argon2id$v=19$m=65536,t=1,p=8$NEW_HASH_HERE"
   ```

4. **Redémarrer** :
   ```bash
   docker compose restart authelia
   ```

5. **Communiquer nouveau mot de passe** à l'utilisateur

### Réinitialiser 2FA Utilisateur

**Scénario** : Utilisateur a perdu smartphone, ne peut plus générer codes TOTP

1. **Supprimer secret TOTP de la base** :
   ```bash
   cd ~/stacks/authelia

   # Backup DB
   cp data/db.sqlite3 data/db.sqlite3.backup

   # Ouvrir DB SQLite
   docker exec -it authelia sqlite3 /data/db.sqlite3
   ```

2. **Supprimer TOTP secret** :
   ```sql
   DELETE FROM totp_configurations WHERE username = 'alice';
   .quit
   ```

3. **Redémarrer Authelia** :
   ```bash
   docker compose restart authelia
   ```

4. **Utilisateur se reconnecte** :
   - Login avec username + password
   - Authelia détecte absence de 2FA
   - Propose de scanner nouveau QR code
   - Nouveau secret TOTP créé ✅

---

## 🔐 Règles d'Accès

### Fichier configuration.yml

**Localisation** : `~/stacks/authelia/config/configuration.yml`

**Section Access Control** :
```yaml
access_control:
  default_policy: deny  # Deny par défaut (sécurité)

  rules:
    # Règle 1 : Bypass pour Homepage (pas de login)
    - domain: "homepage.votredomaine.com"
      policy: bypass

    # Règle 2 : Two-factor pour services sensibles (admins uniquement)
    - domain:
        - "grafana.votredomaine.com"
        - "portainer.votredomaine.com"
        - "traefik.votredomaine.com"
      policy: two_factor
      subject:
        - "group:admins"

    # Règle 3 : One-factor pour services moins critiques (users)
    - domain:
        - "homepage.votredomaine.com"
      policy: one_factor
      subject:
        - "group:users"
```

### Politiques d'Accès

| Politique | Description | Use Case |
|-----------|-------------|----------|
| **bypass** | Aucune authentification | Homepage, API publiques, Webhooks |
| **one_factor** | Username + Password uniquement | Services peu sensibles |
| **two_factor** | Username + Password + TOTP | Services sensibles (recommandé) |
| **deny** | Accès refusé | Bloquer accès spécifique |

### Exemples Règles Avancées

**Règle 1 : Accès par utilisateur spécifique**
```yaml
# Seul admin et alice peuvent accéder à Grafana
- domain: "grafana.votredomaine.com"
  policy: two_factor
  subject:
    - "user:admin"
    - "user:alice"
```

**Règle 2 : Accès par réseau (IP whitelisting)**
```yaml
# Portainer accessible uniquement depuis réseau local
- domain: "portainer.votredomaine.com"
  policy: two_factor
  networks:
    - "192.168.1.0/24"
  subject:
    - "group:admins"
```

**Règle 3 : Accès par ressource (URL path)**
```yaml
# API publique sans auth, admin avec auth
- domain: "api.votredomaine.com"
  policy: bypass
  resources:
    - "^/public/.*"

- domain: "api.votredomaine.com"
  policy: two_factor
  resources:
    - "^/admin/.*"
  subject:
    - "group:admins"
```

**Règle 4 : Bypass pour certains endpoints (Webhooks)**
```yaml
# Webhooks GitHub sans auth
- domain: "gitea.votredomaine.com"
  policy: bypass
  resources:
    - "^/api/webhooks/.*"

# Tout le reste protégé
- domain: "gitea.votredomaine.com"
  policy: two_factor
  subject:
    - "group:admins"
```

### Ordre des Règles

**IMPORTANT** : Authelia évalue les règles **de haut en bas**, première règle matchée gagne.

**❌ Mauvais ordre** :
```yaml
# Règle 1 : Deny par défaut (match tout)
- domain: "*.votredomaine.com"
  policy: deny

# Règle 2 : Bypass Homepage (JAMAIS ÉVALUÉE !)
- domain: "homepage.votredomaine.com"
  policy: bypass
```

**✅ Bon ordre** :
```yaml
# Règle 1 : Bypass Homepage (spécifique d'abord)
- domain: "homepage.votredomaine.com"
  policy: bypass

# Règle 2 : Deny par défaut (générique à la fin)
- domain: "*.votredomaine.com"
  policy: deny
```

---

## 📊 Comparaison SSO

### Authelia vs Authentik vs Keycloak

| Critère | Authelia | Authentik | Keycloak |
|---------|----------|-----------|----------|
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐⭐ Complexe |
| **Setup** | 5 min | 15 min | 30+ min |
| **RAM** | 100 MB | 300 MB | 500+ MB |
| **TOTP/2FA** | ✅ Natif | ✅ Natif | ✅ Natif |
| **LDAP** | ✅ Oui | ✅ Oui | ✅ Oui |
| **OAuth2/OIDC** | ❌ Non | ✅ Oui | ✅ Oui |
| **SAML** | ❌ Non | ✅ Oui | ✅ Oui |
| **Interface** | Minimal | Moderne | Complexe |
| **Use Case** | Self-hosting Pi | PME | Entreprise |
| **Open Source** | ✅ MIT | ✅ MIT | ✅ Apache 2.0 |

**Recommandation** :
- 🟢 **Raspberry Pi 5** → **Authelia** (léger, simple, suffisant)
- 🟠 **Serveur dédié** → **Authentik** (plus de features, UI moderne)
- 🔴 **Entreprise** → **Keycloak** (SAML, OAuth2, gestion complexe)

### Authelia vs Google SSO / OAuth2

| Critère | Authelia | Google SSO |
|---------|----------|------------|
| **Self-hosted** | ✅ Oui | ❌ Non (cloud) |
| **Données** | Chez vous | Google |
| **Gratuit** | ✅ Toujours | ⚠️ Limites gratuites |
| **Offline** | ✅ Fonctionne | ❌ Nécessite Internet |
| **Personnalisation** | ✅ Totale | ❌ Limitée |
| **Setup** | 5 min | 30 min (OAuth config) |
| **TOTP** | ✅ Intégré | ✅ Via Google Account |

**Quand utiliser Google SSO ?** :
- Application publique (blog, SaaS)
- Besoin "Login with Google" pour utilisateurs externes

**Quand utiliser Authelia ?** :
- Services internes (Grafana, Portainer)
- Self-hosting pur (zéro dépendance cloud)
- Contrôle total des données

---

## 🎯 Cas d'Usage

### 1. Sécuriser Dashboard Grafana

**Problème** : Grafana expose métriques sensibles (CPU, RAM, services)

**Solution Authelia** :
```yaml
# Ajouter middleware au service Grafana
services:
  grafana:
    labels:
      - "traefik.http.routers.grafana.middlewares=authelia@file"
```

**Résultat** :
- Accès à `https://grafana.votredomaine.com`
- Redirection automatique vers Authelia
- Login + 2FA obligatoire
- Accès dashboards seulement si authentifié ✅

### 2. Protéger Portainer (Gestion Docker)

**Problème** : Portainer donne contrôle total sur Docker (déployer containers malveillants)

**Solution** :
```yaml
services:
  portainer:
    labels:
      - "traefik.http.routers.portainer.middlewares=authelia@file"
```

**Résultat** :
- Impossible d'accéder à Portainer sans 2FA
- Protection contre attaques automatisées
- Logs d'accès dans Authelia

### 3. Contrôle Multi-Utilisateurs

**Problème** : Donner accès Grafana à un collègue, mais pas à Portainer

**Solution ACLs** :
```yaml
# Admins (vous) : accès complet
- domain:
    - "grafana.votredomaine.com"
    - "portainer.votredomaine.com"
  policy: two_factor
  subject:
    - "group:admins"

# Users (collègue) : Grafana uniquement
- domain: "grafana.votredomaine.com"
  policy: two_factor
  subject:
    - "group:users"
```

**Résultat** :
- Collègue accède à Grafana ✅
- Collègue tente Portainer → "Access Denied" ❌

### 4. Exposer Homepage Publique + Services Protégés

**Problème** : Homepage doit être accessible publiquement, mais pas les autres services

**Solution** :
```yaml
# Homepage : bypass (pas de login)
- domain: "homepage.votredomaine.com"
  policy: bypass

# Tout le reste : 2FA
- domain: "*.votredomaine.com"
  policy: two_factor
  subject:
    - "group:admins"
```

**Résultat** :
- `https://homepage.votredomaine.com` → Accès direct ✅
- `https://grafana.votredomaine.com` → Login 2FA obligatoire 🔐

### 5. Audit Logs Connexions

**Problème** : Qui s'est connecté à quand ?

**Solution** : Logs Authelia
```bash
docker logs authelia | grep "successful authentication"
```

**Output** :
```
2025-10-04 10:32:15 INFO Successful authentication for user 'admin' from IP 192.168.1.50
2025-10-04 14:21:03 INFO Successful authentication for user 'alice' from IP 192.168.1.75
```

**Utilisation** :
- Détection connexions suspectes (IP inconnue)
- Audit accès services sensibles
- Compliance (RGPD, logs d'accès)

### 6. Bannissement Brute-Force

**Problème** : Bot tente 1000 mots de passe sur Grafana

**Protection Authelia** :
```yaml
regulation:
  max_retries: 3       # 3 tentatives max
  find_time: 2m        # Sur 2 minutes
  ban_time: 5m         # Ban 5 minutes
```

**Résultat** :
- Tentative 1 : Username + mauvais password → Erreur
- Tentative 2 : Username + mauvais password → Erreur
- Tentative 3 : Username + mauvais password → Erreur
- Tentative 4 : → **"Account locked for 5 minutes"** ⛔
- Bot ne peut plus continuer, abandon ✅

---

## 🛠️ Maintenance

### Backup Configuration

**Fichiers critiques à sauvegarder** :
```bash
~/stacks/authelia/
├── config/
│   ├── configuration.yml       # Config Authelia
│   └── users_database.yml      # Utilisateurs + hash passwords
├── data/
│   └── db.sqlite3              # Secrets TOTP, sessions
└── .env                        # Secrets JWT, session, encryption
```

**Backup manuel** :
```bash
# Créer archive
tar -czf ~/backups/authelia-config-$(date +%Y%m%d).tar.gz \
  ~/stacks/authelia/config/ \
  ~/stacks/authelia/data/db.sqlite3 \
  ~/stacks/authelia/.env

# Vérifier
ls -lh ~/backups/authelia-config-*.tar.gz
```

**Restaurer backup** :
```bash
cd ~/backups
tar -xzf authelia-config-20251004.tar.gz -C ~/stacks/
cd ~/stacks/authelia
docker compose restart authelia
```

**⚠️ IMPORTANT** : Ne PAS sauvegarder `redis/dump.rdb` (sessions temporaires, non critique)

### Exporter Utilisateurs

**Scénario** : Migrer vers autre serveur

```bash
# Exporter users_database.yml
cp ~/stacks/authelia/config/users_database.yml ~/backups/users-$(date +%Y%m%d).yml

# Sur nouveau serveur
scp ~/backups/users-20251004.yml pi@nouveau-serveur:/home/pi/stacks/authelia/config/users_database.yml
```

### Rotation Secrets

**Scénario** : Changer JWT secret tous les 6 mois (sécurité)

1. **Générer nouveau secret** :
   ```bash
   NEW_JWT_SECRET=$(openssl rand -hex 64)
   echo "Nouveau JWT Secret: $NEW_JWT_SECRET"
   ```

2. **Éditer .env** :
   ```bash
   nano ~/stacks/authelia/.env
   ```

3. **Remplacer JWT_SECRET** :
   ```env
   JWT_SECRET=NOUVEAU_SECRET_ICI
   ```

4. **Redémarrer Authelia** :
   ```bash
   docker compose restart authelia
   ```

5. **Tester** : Se connecter à Authelia → Login doit fonctionner ✅

**⚠️ Note** : Rotation secret invalide toutes les sessions actives (utilisateurs doivent se reconnecter)

### Mettre à Jour Authelia

```bash
cd ~/stacks/authelia

# Backup config avant update
tar -czf ~/backups/authelia-pre-update-$(date +%Y%m%d).tar.gz config/ data/ .env

# Pull nouvelle image
docker compose pull authelia

# Redémarrer avec nouvelle image
docker compose up -d authelia

# Vérifier logs
docker logs -f authelia
```

### Nettoyer Sessions Expirées

**Authelia nettoie automatiquement** les sessions via Redis.

**Manuel (si besoin)** :
```bash
# Connexion Redis
docker exec -it authelia-redis redis-cli

# Lister toutes les clés
KEYS *

# Supprimer sessions expirées manuellement (Redis le fait auto)
FLUSHDB

# Quitter
quit
```

**⚠️ Warning** : `FLUSHDB` déconnecte tous les utilisateurs

---

## 💾 Ressources Système

### Consommation RAM

| Container | RAM Idle | RAM Charge | Notes |
|-----------|----------|------------|-------|
| **authelia** | 80-100 MB | 120 MB | Dépend du nombre d'utilisateurs |
| **redis** | 30-50 MB | 80 MB | Augmente avec sessions actives |
| **Total** | **~150 MB** | **~200 MB** | Stack complet |

**Comparaison** :
- Authentik : ~300 MB (PostgreSQL + Redis + Worker)
- Keycloak : ~500 MB (Java + PostgreSQL)

### Consommation CPU

**Idle** : <1% CPU (Pi 5)
**Login** : Pic 5-10% CPU durant hash Argon2id (normal)
**Charge** : <2% CPU avec 10+ utilisateurs simultanés

### Consommation Disque

```bash
~/stacks/authelia/
├── config/              ~10 KB
├── data/db.sqlite3      ~1 MB (100 users, 1000 sessions)
└── redis/dump.rdb       ~500 KB (sessions actives)

Total: ~2 MB (négligeable)
```

**Croissance** : +10 KB par nouvel utilisateur

### Performance Tests

**Temps de réponse** (login complet) :
```
Username + Password → 200-300 ms (hash Argon2id)
TOTP Verification   → 50-100 ms (crypto TOTP)
Session Creation    → 20-50 ms (Redis write)
Total               → ~500 ms (acceptable)
```

**Comparaison** :
- Authentik : ~800 ms
- Keycloak : ~1200 ms

### Optimisations

**Réduire RAM Redis** :
```yaml
# docker-compose.yml
services:
  redis:
    command:
      - redis-server
      - --maxmemory 30mb          # Limite RAM Redis
      - --maxmemory-policy allkeys-lru  # Supprime anciennes sessions
```

**Réduire CPU Argon2id** (⚠️ diminue sécurité) :
```yaml
# configuration.yml
authentication_backend:
  file:
    password:
      algorithm: argon2id
      iterations: 1
      parallelism: 4  # Réduire de 8 à 4
      memory: 32      # Réduire de 64 à 32
```

---

## 🆘 Troubleshooting

### Authelia ne démarre pas

**Symptôme** : `docker ps` affiche `authelia` en `Exited`

**Solutions** :

1. **Vérifier logs** :
   ```bash
   docker logs authelia
   ```

   **Erreurs courantes** :
   ```
   ERROR: configuration.yml syntax error
   → Vérifier syntaxe YAML (indentation, espaces)

   ERROR: Redis connection refused
   → Vérifier container Redis running

   ERROR: Invalid JWT secret
   → Vérifier .env (JWT_SECRET non vide)
   ```

2. **Vérifier Redis** :
   ```bash
   docker ps --filter "name=authelia-redis"
   docker logs authelia-redis
   ```

3. **Valider configuration YAML** :
   ```bash
   # Installer yamllint
   sudo apt install yamllint

   # Valider fichier
   yamllint ~/stacks/authelia/config/configuration.yml
   ```

4. **Redémarrer stack** :
   ```bash
   cd ~/stacks/authelia
   docker compose down
   docker compose up -d
   ```

### Login échoue malgré bon mot de passe

**Symptôme** : "Invalid credentials" avec password correct

**Solutions** :

1. **Vérifier hash mot de passe** :
   ```bash
   # Re-générer hash
   docker run --rm authelia/authelia:latest \
     authelia crypto hash generate argon2 --password VOTRE_PASSWORD

   # Comparer avec users_database.yml
   cat ~/stacks/authelia/config/users_database.yml
   ```

2. **Vérifier syntaxe YAML** :
   ```yaml
   # ❌ Mauvais (guillemets manquants)
   password: $argon2id$v=19$m=65536...

   # ✅ Bon (avec guillemets)
   password: "$argon2id$v=19$m=65536..."
   ```

3. **Vérifier username** (case-sensitive) :
   ```yaml
   # users_database.yml
   users:
     admin:  # Doit être "admin" (minuscule)

   # Login avec "Admin" (majuscule) → Echec ❌
   # Login avec "admin" (minuscule) → OK ✅
   ```

4. **Réinitialiser utilisateur** :
   ```bash
   # Supprimer user de la DB
   docker exec -it authelia sqlite3 /data/db.sqlite3
   DELETE FROM authentication_logs WHERE username = 'admin';
   DELETE FROM totp_configurations WHERE username = 'admin';
   .quit

   # Redémarrer
   docker compose restart authelia
   ```

### Code TOTP refusé

**Symptôme** : Code 6 chiffres refusé (2FA)

**Solutions** :

1. **Vérifier horloge** (TOTP dépend du temps) :
   ```bash
   # Pi
   date

   # Smartphone
   # Comparer heures (doivent être identiques ±30 secondes)

   # Si décalage, synchroniser
   sudo timedatectl set-ntp true
   sudo timedatectl set-timezone Europe/Paris
   ```

2. **Attendre nouveau code** :
   - Codes TOTP changent toutes les 30 secondes
   - Attendre 1 minute, réessayer

3. **Utiliser code de récupération** :
   - Affichés lors de setup 2FA
   - Format : `ABCD-EFGH-IJKL`
   - Entrer à la place du code TOTP

4. **Réinitialiser 2FA** (voir section Gestion Utilisateurs)

### Middleware Authelia non détecté par Traefik

**Symptôme** : Service non protégé malgré label middleware

**Solutions** :

1. **Vérifier fichier middleware** :
   ```bash
   cat /home/pi/stacks/traefik/dynamic/authelia-middleware.yml
   ```

   Doit contenir :
   ```yaml
   http:
     middlewares:
       authelia:
         forwardAuth:
           address: "http://authelia:9091/api/verify?rd=..."
   ```

2. **Vérifier Traefik voit le middleware** :
   ```bash
   docker logs traefik | grep authelia
   ```

   Doit afficher :
   ```
   INFO middleware/authelia registered
   ```

3. **Vérifier réseau Docker** :
   ```bash
   # Authelia doit être sur réseau traefik-public
   docker network inspect traefik-public | grep authelia
   ```

4. **Redémarrer Traefik** :
   ```bash
   docker restart traefik
   ```

5. **Tester connexion** :
   ```bash
   # Depuis container Traefik, tester connexion Authelia
   docker exec traefik wget -O- http://authelia:9091/api/health
   ```

### Session expire trop vite

**Symptôme** : Déconnecté après 5 minutes d'inactivité

**Solution** : Modifier expiration session

```bash
nano ~/stacks/authelia/config/configuration.yml
```

```yaml
session:
  expiration: 4h          # De 1h → 4h
  inactivity: 30m         # De 5m → 30m
  remember_me_duration: 1M  # OK
```

```bash
docker compose restart authelia
```

### Redis connexion refusée

**Symptôme** : `docker logs authelia` affiche "Redis connection refused"

**Solutions** :

1. **Vérifier Redis running** :
   ```bash
   docker ps --filter "name=authelia-redis"
   ```

2. **Vérifier health Redis** :
   ```bash
   docker exec authelia-redis redis-cli ping
   # Doit retourner: PONG
   ```

3. **Vérifier réseau** :
   ```bash
   docker network inspect authelia-internal | grep redis
   ```

4. **Redémarrer Redis** :
   ```bash
   docker compose restart redis
   ```

---

## 📚 Documentation

### Guides Disponibles

- **[GUIDE-DEBUTANT.md](GUIDE-DEBUTANT.md)** - Guide pédagogique complet pour novices
- **[INSTALL.md](INSTALL.md)** - Installation détaillée étape par étape
- **[ROADMAP.md](../ROADMAP.md)** - Plan de développement Pi5-Setup

### Documentation Externe

- **[Authelia Docs](https://www.authelia.com/)** - Documentation officielle
- **[Configuration Reference](https://www.authelia.com/configuration/prologue/introduction/)** - Référence complète
- **[Access Control](https://www.authelia.com/configuration/security/access-control/)** - Règles ACL
- **[Traefik Integration](https://www.authelia.com/integration/proxies/traefik/)** - Intégration officielle

### Exemples Configuration

**Configuration complète** : [authelia-config-examples](https://github.com/authelia/authelia/tree/master/examples)

**ACL Examples** :
- [Basic ACL](https://www.authelia.com/configuration/security/access-control/#basic-examples)
- [Advanced ACL](https://www.authelia.com/configuration/security/access-control/#advanced-examples)
- [Bypass Rules](https://www.authelia.com/configuration/security/access-control/#bypass-rules)

### Communautés

- [r/selfhosted](https://reddit.com/r/selfhosted) - Reddit self-hosting
- [Authelia Discord](https://discord.authelia.com/) - Support officiel
- [GitHub Discussions](https://github.com/authelia/authelia/discussions) - Questions/réponses

---

## 🎯 Prochaines Étapes

Une fois Authelia installé :

1. **Se connecter** à `https://auth.votredomaine.com`
2. **Configurer 2FA** (scan QR code avec app)
3. **Changer mot de passe** admin (optionnel)
4. **Protéger services** sensibles (Grafana, Portainer, Traefik)
5. **Créer utilisateurs** supplémentaires (famille, collègues)
6. **Configurer ACLs** pour contrôle accès granulaire
7. **Tester** authentification sur tous les services

**Prochaine phase** : [Phase 6 - Gitea + CI/CD](../ROADMAP.md#phase-6)

---

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## 📄 Licence

MIT License - Voir [LICENSE](../LICENSE)

---

<p align="center">
  <strong>🔐 SSO + 2FA Production-Ready pour Raspberry Pi 5 🔐</strong>
</p>

<p align="center">
  <sub>Authelia • Redis • TOTP/2FA • SSO • Brute-Force Protection • ACLs</sub>
</p>
