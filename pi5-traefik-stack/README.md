# 🌐 Pi5 Traefik Stack - Reverse Proxy + HTTPS

> **Accès sécurisé à vos webapps depuis l'extérieur avec HTTPS automatique**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Traefik](https://img.shields.io/badge/Traefik-v3-37B5EF.svg)](https://traefik.io/)
[![HTTPS](https://img.shields.io/badge/HTTPS-Let's%20Encrypt-brightgreen.svg)](https://letsencrypt.org/)

---

## 🎯 Overview

Traefik est un **reverse proxy moderne** qui permet d'accéder à vos services (Supabase, Gitea, etc.) depuis l'extérieur avec :
- ✅ **HTTPS automatique** (certificats Let's Encrypt gratuits)
- ✅ **Sous-domaines** (studio.monpi.fr, api.monpi.fr)
- ✅ **Dashboard** pour surveiller le trafic
- ✅ **Configuration automatique** via Docker labels

### 🤔 Pourquoi Traefik ?

**Sans Traefik** :
```
Vous → http://192.168.1.100:8000 ❌ Pas sécurisé, pas accessible depuis l'extérieur
```

**Avec Traefik** :
```
Vous (n'importe où) → https://studio.monpi.fr ✅ Sécurisé, accessible partout
                    → https://api.monpi.fr
                    → https://grafana.monpi.fr
```

---

## 📋 Scénarios d'Usage

Ce stack propose **3 scénarios** adaptés à différents besoins :

### 🟢 Scénario 1 : DuckDNS + Let's Encrypt (RECOMMANDÉ DÉBUTANTS)

**Pour qui ?** Novices, pas de domaine, veut du HTTPS gratuit et valide

**Avantages** :
- ✅ 100% gratuit
- ✅ Setup en 10 minutes
- ✅ Certificats HTTPS valides (navigateur affiche cadenas vert)
- ✅ Pas besoin d'acheter un domaine

**Limitations** :
- ❌ Sous-domaine imposé : `monpi.duckdns.org`
- ❌ Pas de sous-sous-domaines (pas `studio.monpi.duckdns.org`)

**Use case** :
```
https://monpi.duckdns.org       → Homepage (portail)
https://monpi.duckdns.org/studio → Supabase Studio
https://monpi.duckdns.org/api   → Supabase API
```

**Voir** : [Guide DuckDNS](docs/SCENARIO-DUCKDNS.md)

---

### 🔵 Scénario 2 : Domaine Personnel + Cloudflare DNS (RECOMMANDÉ PRODUCTION)

**Pour qui ?** Utilisateurs avec domaine, veulent sous-domaines multiples

**Avantages** :
- ✅ Sous-domaines illimités (`studio.monpi.fr`, `api.monpi.fr`)
- ✅ HTTPS automatique avec DNS-01 challenge (fonctionne même sans exposer ports)
- ✅ Cloudflare gratuit (protection DDoS, cache, analytics)
- ✅ Professionnel

**Coût** :
- 💰 Domaine : ~3-15€/an (OVH, Gandi, Namecheap)
- ✅ Cloudflare : Gratuit

**Use case** :
```
https://studio.monpi.fr   → Supabase Studio
https://api.monpi.fr      → Supabase API
https://git.monpi.fr      → Gitea
https://grafana.monpi.fr  → Monitoring
https://monpi.fr          → Homepage
```

**Voir** : [Guide Domaine + Cloudflare](docs/SCENARIO-CLOUDFLARE.md)

---

### 🟡 Scénario 3 : VPN + Certificats Locaux (PAS D'EXPOSITION PUBLIQUE)

**Pour qui ?** Paranoïaques de la sécurité, ne veulent RIEN exposer sur Internet

**Avantages** :
- ✅ Aucun port exposé sur Internet (sauf WireGuard/Tailscale)
- ✅ Accès via VPN uniquement
- ✅ Sécurité maximale

**Limitations** :
- ❌ Certificats auto-signés (navigateur affiche warning)
- ❌ Doit installer VPN sur chaque appareil
- ❌ Plus complexe

**Use case** :
```
1. Se connecter au VPN (WireGuard/Tailscale)
2. Accéder à https://studio.pi.local (warning certificat)
3. Cliquer "Accepter le risque"
```

**Voir** : [Guide VPN](docs/SCENARIO-VPN.md)

---

## 🚀 Installation Rapide

### Prérequis
- Raspberry Pi 5 avec **Supabase déjà installé** ([Phase 1](../pi5-supabase-stack/))
- Ports **80** et **443** ouverts sur votre box (sauf Scénario 3)
- Choix du scénario (voir ci-dessus)

### Étape 1 : Choisir votre scénario

**Scénario 1 - DuckDNS** (Débutants) :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Scénario 2 - Cloudflare** (Production) :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

**Scénario 3 - VPN** (Sécurité max) :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

### Étape 2 : Intégrer Supabase avec Traefik

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

## 📚 Documentation

### 🎓 Pour Débutants - Commencer ici !

👉 **[GUIDE DÉBUTANT](GUIDE-DEBUTANT.md)** - Comprendre Traefik et les reverse proxies
- C'est quoi un reverse proxy ? (analogie réceptionniste d'hôtel)
- Pourquoi HTTPS est important ?
- Comment fonctionnent les certificats SSL ?
- Sous-domaines vs sous-chemins (paths)
- Tutoriels pas-à-pas par scénario

### 📖 Guides par Scénario

- [Scénario 1 : DuckDNS](docs/SCENARIO-DUCKDNS.md) - Guide complet débutants
- [Scénario 2 : Cloudflare](docs/SCENARIO-CLOUDFLARE.md) - Guide domaine personnel
- [Scénario 3 : VPN](docs/SCENARIO-VPN.md) - Guide sécurité maximale
- [Comparaison des scénarios](docs/SCENARIOS-COMPARISON.md) - Tableau comparatif

### 🔧 Configuration Avancée

- [Labels Docker Traefik](docs/TRAEFIK-LABELS.md) - Exposer vos propres apps
- [Middlewares](docs/MIDDLEWARES.md) - Auth, rate limiting, headers
- [Dashboard Traefik](docs/DASHBOARD.md) - Surveiller le trafic
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Résoudre les problèmes courants

---

## 🏗️ Architecture

### Scénario 1 (DuckDNS)
```
Internet
  ↓
Box (Port Forwarding 80→80, 443→443)
  ↓
Raspberry Pi 5
  ↓
Traefik (port 80, 443)
  ↓
  ├─→ /studio → Supabase Studio (8000)
  ├─→ /api    → Supabase API (8000)
  └─→ /       → Homepage (3000)

Certificat : Let's Encrypt (HTTP-01 challenge)
```

### Scénario 2 (Cloudflare)
```
Internet
  ↓
Cloudflare DNS (A record → IP publique)
  ↓
Box (Port Forwarding 80→80, 443→443)
  ↓
Raspberry Pi 5
  ↓
Traefik (port 80, 443)
  ↓
  ├─→ studio.monpi.fr → Supabase Studio (8000)
  ├─→ api.monpi.fr    → Supabase API (8000)
  ├─→ git.monpi.fr    → Gitea (3001)
  └─→ monpi.fr        → Homepage (3000)

Certificat : Let's Encrypt (DNS-01 challenge via Cloudflare API)
```

### Scénario 3 (VPN)
```
Internet (aucun port exposé)
  ↓
VPN WireGuard/Tailscale (UDP 51820)
  ↓
Réseau VPN (10.0.0.0/24)
  ↓
Raspberry Pi 5 (10.0.0.1)
  ↓
Traefik (port 443 uniquement)
  ↓
  ├─→ studio.pi.local → Supabase Studio (8000)
  ├─→ api.pi.local    → Supabase API (8000)
  └─→ pi.local        → Homepage (3000)

Certificat : Auto-signé (mkcert ou self-signed)
```

---

## 🛠️ Structure du Projet

```
pi5-traefik-stack/
├── README.md                           # Ce fichier
├── GUIDE-DEBUTANT.md                   # Guide pédagogique
├── INSTALL.md                          # Instructions installation
├── scripts/
│   ├── 01-traefik-deploy-duckdns.sh   # Script Scénario 1
│   ├── 01-traefik-deploy-cloudflare.sh # Script Scénario 2
│   ├── 01-traefik-deploy-vpn.sh       # Script Scénario 3
│   └── 02-integrate-supabase.sh       # Intégration Supabase
├── compose/
│   ├── scenarios/
│   │   ├── duckdns.yml                # Docker Compose Scénario 1
│   │   ├── cloudflare.yml             # Docker Compose Scénario 2
│   │   └── vpn.yml                    # Docker Compose Scénario 3
│   └── shared/
│       └── supabase-labels.yml        # Labels Traefik pour Supabase
├── config/
│   ├── static/
│   │   └── traefik.yml                # Config statique Traefik
│   └── dynamic/
│       ├── middlewares.yml            # Middlewares (auth, rate limit)
│       └── tls.yml                    # Config TLS
├── docs/
│   ├── SCENARIO-DUCKDNS.md
│   ├── SCENARIO-CLOUDFLARE.md
│   ├── SCENARIO-VPN.md
│   ├── SCENARIOS-COMPARISON.md
│   ├── TRAEFIK-LABELS.md
│   ├── MIDDLEWARES.md
│   └── TROUBLESHOOTING.md
└── commands/
    ├── README.md
    └── 00-Quick-Start.md
```

---

## 📊 Comparaison Rapide des Scénarios

| Critère | 🟢 DuckDNS | 🔵 Cloudflare | 🟡 VPN |
|---------|-----------|---------------|--------|
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐ Avancé |
| **Coût** | Gratuit | ~5€/an domaine | Gratuit (Tailscale) |
| **Setup** | 10 min | 20 min | 30 min |
| **HTTPS valide** | ✅ Oui | ✅ Oui | ❌ Auto-signé |
| **Sous-domaines** | ❌ Non | ✅ Illimités | ✅ Illimités |
| **Exposition publique** | ✅ Oui | ✅ Oui | ❌ Non |
| **Ports à ouvrir** | 80, 443 | 80, 443 | Aucun (juste VPN) |
| **Recommandé pour** | Débutants | Production | Paranoïaques |

---

## 🔐 Sécurité

### Bonnes Pratiques

✅ **Toujours activé** :
- HTTPS automatique (Let's Encrypt)
- Redirection HTTP → HTTPS
- Headers de sécurité (HSTS, CSP)
- Rate limiting sur Dashboard

✅ **Recommandé** :
- Authentification sur Dashboard Traefik
- Fail2ban pour bloquer bruteforce
- Cloudflare protection DDoS (Scénario 2)
- VPN pour services sensibles (Portainer, Grafana)

❌ **À éviter** :
- Exposer ports Docker directement (8000, 5432, etc.)
- Désactiver HTTPS
- Utiliser HTTP-01 challenge si derrière CGNAT (préférer DNS-01)

---

## 🆘 Problèmes Courants

### "ERR_SSL_PROTOCOL_ERROR"
**Cause** : Certificat pas encore généré ou ports fermés

**Solution** :
```bash
# Vérifier logs Traefik
docker logs traefik -f

# Vérifier ports ouverts
sudo ufw status
```

### "404 - Backend not found"
**Cause** : Labels Docker mal configurés

**Solution** :
```bash
# Vérifier labels du container
docker inspect supabase-studio | grep traefik

# Redémarrer Traefik
docker restart traefik
```

### "DNS not resolving"
**Cause** : DNS pas propagé ou mal configuré

**Solution** :
```bash
# Tester DNS
nslookup studio.monpi.fr

# Attendre propagation (jusqu'à 48h)
```

**Plus de solutions** : [Troubleshooting complet](docs/TROUBLESHOOTING.md)

---

## 🎯 Prochaines Étapes

Une fois Traefik installé :

1. **Tester l'accès HTTPS** à Supabase Studio
2. **Configurer Homepage** (portail d'accès) → [Phase 2b](docs/HOMEPAGE-SETUP.md)
3. **Ajouter monitoring** → [Phase 3 Roadmap](../ROADMAP.md#phase-3)
4. **Exposer d'autres services** (Gitea, Grafana) via labels Traefik

---

## 📖 Ressources

### Documentation Officielle
- [Traefik Docs](https://doc.traefik.io/traefik/)
- [Let's Encrypt Docs](https://letsencrypt.org/docs/)
- [Cloudflare API](https://developers.cloudflare.com/api/)

### Tutoriels
- [Traefik + Docker](https://doc.traefik.io/traefik/providers/docker/)
- [Let's Encrypt DNS Challenge](https://doc.traefik.io/traefik/https/acme/#dnschallenge)

### Communautés
- [r/Traefik](https://reddit.com/r/Traefik)
- [Traefik Discord](https://discord.gg/traefik)

---

**Dernière mise à jour** : 2025-10-04
**Version** : 1.0
**Mainteneur** : [@iamaketechnology](https://github.com/iamaketechnology)
