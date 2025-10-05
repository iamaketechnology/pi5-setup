# 🔐 Pi5 VPN Stack - Tailscale Zero-Config VPN

> **Accès sécurisé à votre Pi depuis n'importe où sans ouvrir de ports**

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](CHANGELOG.md)
[![Pi 5](https://img.shields.io/badge/Raspberry%20Pi-5-red.svg)](https://www.raspberrypi.com/)
[![Tailscale](https://img.shields.io/badge/Tailscale-Latest-5A67D8.svg)](https://tailscale.com/)
[![WireGuard](https://img.shields.io/badge/WireGuard-Based-88171A.svg)](https://www.wireguard.com/)

---

## 📖 Table des Matières

- [Vue d'Ensemble](#-vue-densemble)
- [Fonctionnalités](#-fonctionnalités)
- [Installation Rapide](#-installation-rapide)
- [Architecture](#-architecture)
- [Comparaison VPN](#-comparaison-vpn)
- [Cas d'Usage](#-cas-dusage)
- [Configuration](#-configuration)
- [Clients](#-clients)
- [Sécurité](#-sécurité)
- [Troubleshooting](#-troubleshooting)
- [Documentation](#-documentation)

---

## 🎯 Vue d'Ensemble

**Pi5-VPN-Stack** permet d'accéder à votre Raspberry Pi 5 et tous vos services depuis n'importe où, de manière **sécurisée**, **sans ouvrir de ports** sur votre box Internet.

### Pourquoi Tailscale ?

**Sans VPN** :
```
Vous au café → ❌ Pas d'accès à Supabase
              → ❌ Pas d'accès à Grafana
              → ❌ Besoin d'ouvrir ports 80/443
              → ❌ Risques de sécurité
```

**Avec Tailscale** :
```
Vous n'importe où → VPN activé → ✅ Accès à tous vos services
                               → ✅ Aucun port à ouvrir
                               → ✅ Chiffrement WireGuard
                               → ✅ Connection automatique
```

### Avantages Tailscale

- ✅ **Zero-Config** - Installation en 2 minutes, aucune configuration réseau
- ✅ **NAT Traversal** - Fonctionne derrière n'importe quel routeur/firewall
- ✅ **MagicDNS** - Accès via noms (ex: `raspberrypi` au lieu de `100.64.1.5`)
- ✅ **Multi-Plateforme** - Windows, macOS, Linux, iOS, Android
- ✅ **Gratuit** - Plan free pour jusqu'à 100 appareils
- ✅ **Basé sur WireGuard** - Protocole moderne ultra-rapide

---

## 🚀 Fonctionnalités

### Core Features

- 🔐 **VPN Mesh Network** - Tous vos appareils se connectent directement
- 🌐 **MagicDNS** - Résolution de noms automatique (`raspberrypi`, `mon-laptop`)
- 🚀 **Subnet Router** - Accès au réseau local entier via le Pi
- 🌍 **Exit Node** - Utilisez le Pi comme proxy Internet
- 🔑 **ACLs** - Contrôle d'accès granulaire entre appareils
- 📱 **Mobile Apps** - iOS et Android natifs

### Intégration Pi5-Setup

Le script détecte automatiquement :
- ✅ **Services installés** - Supabase, Traefik, Grafana, Homepage
- ✅ **Génération MagicDNS names** - Noms courts pour tous vos services
- ✅ **Configuration Traefik** - Accès HTTPS via VPN (optionnel)
- ✅ **Firewall rules** - Ouverture ports VPN uniquement

### Scénarios Supportés

| Scénario | Description | Use Case |
|----------|-------------|----------|
| **Basic VPN** | Accès au Pi uniquement | SSH, Portainer, services Pi |
| **Subnet Router** | Accès réseau local entier | NAS, imprimante, autres devices |
| **Exit Node** | Proxy Internet via Pi | Sécuriser WiFi public |
| **Hybrid** | VPN + Traefik public | Certains services VPN, autres publics |

---

## ⚡ Installation Rapide

### Prérequis

- ✅ Raspberry Pi 5 avec Raspberry Pi OS 64-bit
- ✅ Docker installé ([01-prerequisites-setup.sh](../common-scripts/01-prerequisites-setup.sh))
- ✅ Compte Tailscale (gratuit, création durant installation)
- ✅ Smartphone ou ordinateur pour authentification

### Installation en 1 Commande

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-vpn-stack/scripts/01-tailscale-setup.sh | sudo bash
```

**Durée** : ~3 minutes

### Ce que fait le Script

1. ✅ Crée compte Tailscale (si nécessaire)
2. ✅ Installe Tailscale sur le Pi
3. ✅ Configure MagicDNS
4. ✅ Génère URL d'authentification
5. ✅ (Optionnel) Active Subnet Router
6. ✅ (Optionnel) Active Exit Node
7. ✅ Affiche résumé avec noms MagicDNS

### Accès Après Installation

**Via MagicDNS** (noms automatiques) :
```
http://raspberrypi                → Homepage
http://raspberrypi:8000/studio   → Supabase Studio
http://raspberrypi:3002          → Grafana
http://raspberrypi:9000          → Portainer
```

**Via IP Tailscale** :
```
http://100.64.1.5                → Homepage
http://100.64.1.5:8000/studio   → Supabase Studio
```

**Prochaine étape** : Installer clients Tailscale sur vos appareils

---

## 🏗️ Architecture

### Tailscale Network (Mesh VPN)

```
                     Tailscale Control Plane
                    (Coordination Servers)
                              │
                              │ (DERP relay si nécessaire)
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        │                     │                     │
    Laptop                Smartphone          Raspberry Pi 5
  100.64.1.2             100.64.1.3           100.64.1.5
        │                     │                     │
        └─────────────────────┴─────────────────────┘
                  WireGuard Encrypted Mesh
               (Peer-to-peer si possible)
```

### Comment ça fonctionne ?

**Étape 1 : Connexion initiale**
```
1. Appareil démarre Tailscale
2. Contacte Coordination Server (login.tailscale.com)
3. Reçoit liste des peers et leurs endpoints
4. Établit connexion WireGuard directe (si possible)
5. Sinon, utilise DERP relay (serveurs Tailscale)
```

**Étape 2 : Communication**
```
Laptop → Veut accéder à Pi (100.64.1.5)
      → WireGuard chiffre les paquets
      → Connexion directe ou via DERP
      → Pi reçoit requête chiffrée
      → Pi répond via même tunnel
```

### MagicDNS

```
Sans MagicDNS :
http://100.64.1.5:8000    → Difficile à retenir

Avec MagicDNS :
http://raspberrypi:8000   → Nom automatique du hostname
http://mon-pi:8000        → Nom personnalisé (configurable)
```

### Subnet Router (Optionnel)

```
Internet
    │
    ├─ Laptop (100.64.1.2)
    │      │
    │      └─ Via VPN → Raspberry Pi (100.64.1.5)
    │                         │
    │                         └─ Accès réseau local (192.168.1.0/24)
    │                                  │
    │                                  ├─ NAS (192.168.1.50)
    │                                  ├─ Imprimante (192.168.1.100)
    │                                  └─ Autres appareils
```

**Permet d'accéder** :
- NAS Synology/QNAP via VPN
- Imprimantes réseau
- Caméras IP
- Tous appareils du réseau local

### Exit Node (Optionnel)

```
Vous au café WiFi public
         │
         └─ VPN → Raspberry Pi (100.64.1.5)
                       │
                       └─ Internet (via connexion Pi)

Avantages :
✅ Chiffre trafic sur WiFi public
✅ Masque IP réelle (IP = IP du Pi)
✅ Contourne censure/géoblocage
```

---

## 📊 Comparaison VPN

### Tailscale vs WireGuard vs OpenVPN

| Critère | Tailscale | WireGuard Natif | OpenVPN |
|---------|-----------|-----------------|---------|
| **Difficulté** | ⭐ Très facile | ⭐⭐⭐ Complexe | ⭐⭐⭐⭐ Très complexe |
| **Setup** | 2 min | 30+ min | 1+ heure |
| **Configuration** | Zero-config | Manuelle | Manuelle complexe |
| **NAT Traversal** | ✅ Automatique | ❌ Difficile | ❌ Difficile |
| **Multi-appareils** | ✅ Illimité (100 free) | ❌ Config par appareil | ❌ Config par appareil |
| **Vitesse** | ⚡ Très rapide | ⚡ Très rapide | 🐌 Lent |
| **Ports à ouvrir** | ❌ Aucun | ✅ UDP 51820 | ✅ UDP 1194 |
| **Mobile** | ✅ Apps natives | ⚠️ Apps tierces | ✅ Apps natives |
| **MagicDNS** | ✅ Intégré | ❌ Absent | ❌ Absent |
| **ACLs** | ✅ Interface web | ❌ Manuel (iptables) | ❌ Manuel |
| **Coût** | Gratuit (100 devices) | Gratuit | Gratuit |
| **Open Source** | ⚠️ Client oui, serveur non | ✅ 100% | ✅ 100% |

**Recommandation** :
- 🟢 **Débutants** → **Tailscale** (facile, rapide, fiable)
- 🟠 **Avancés** → **WireGuard** (contrôle total, self-hosted)
- 🔴 **Legacy** → **OpenVPN** (compatibilité anciens systèmes)

### Tailscale vs Cloudflare Tunnel

| Critère | Tailscale | Cloudflare Tunnel |
|---------|-----------|-------------------|
| **Type** | VPN mesh | Reverse proxy tunnel |
| **Accès** | Appareils autorisés | N'importe qui avec URL |
| **Sécurité** | WireGuard (très sécurisé) | TLS (bon) |
| **Ports** | Aucun | Aucun |
| **Setup** | 2 min | 10 min |
| **Use Case** | Accès personnel | Exposition publique |
| **Gratuit** | 100 devices | Illimité |

**Quand utiliser quoi ?** :
- **Tailscale** : Accès personnel à vos services (vous, famille)
- **Cloudflare Tunnel** : Exposer un service au public (blog, portfolio)

---

## 🎯 Cas d'Usage

### 1. Accès SSH Sécurisé

**Problème** : Accéder au Pi en SSH sans exposer port 22 au monde

**Solution Tailscale** :
```bash
# Depuis n'importe où avec Tailscale actif
ssh pi@raspberrypi          # Via MagicDNS
ssh pi@100.64.1.5          # Via IP Tailscale

# Aucun port ouvert sur Internet !
```

### 2. Monitoring Grafana en Déplacement

**Problème** : Consulter Grafana depuis le travail/vacances

**Solution** :
```
1. Activer VPN Tailscale sur smartphone/laptop
2. Ouvrir http://raspberrypi:3002
3. Accéder à Grafana comme si vous étiez chez vous
```

### 3. Montrer Homepage à un Ami

**Problème** : Ami veut voir votre setup sans exposer publiquement

**Solution** :
```bash
# Inviter l'ami dans votre Tailnet
tailscale share raspberrypi --email ami@example.com

# Ami reçoit lien, installe Tailscale, accède à Homepage
```

### 4. Sécuriser WiFi Public

**Problème** : WiFi café pas sécurisé, risque de sniffing

**Solution** :
```bash
# Sur le Pi, activer Exit Node
sudo tailscale up --advertise-exit-node

# Sur laptop au café
tailscale up --exit-node=raspberrypi

# Tout le trafic passe par le Pi (chiffré)
```

### 5. Accès NAS Synology via VPN

**Problème** : NAS uniquement sur réseau local (192.168.1.50)

**Solution** :
```bash
# Sur le Pi, activer Subnet Router
sudo tailscale up --advertise-routes=192.168.1.0/24

# Depuis n'importe où
http://192.168.1.50:5000   → DiskStation Manager accessible !
```

### 6. Dev Mobile avec Backend Supabase Local

**Problème** : Tester app mobile avec Supabase sur Pi

**Solution** :
```swift
// Dans app iOS/Android
let supabase = SupabaseClient(
    supabaseURL: URL(string: "http://raspberrypi:8000")!,
    supabaseKey: "anon-key"
)

// Fonctionne via Tailscale VPN, comme si en local
```

---

## ⚙️ Configuration

### Installation avec Options

```bash
# Installation basique
curl -fsSL https://raw.githubusercontent.com/.../01-tailscale-setup.sh | sudo bash

# Installation avec Subnet Router (accès réseau local)
curl -fsSL https://raw.githubusercontent.com/.../01-tailscale-setup.sh | sudo ENABLE_SUBNET_ROUTER=true bash

# Installation avec Exit Node (proxy Internet)
curl -fsSL https://raw.githubusercontent.com/.../01-tailscale-setup.sh | sudo ENABLE_EXIT_NODE=true bash

# Installation complète
curl -fsSL https://raw.githubusercontent.com/.../01-tailscale-setup.sh | sudo ENABLE_SUBNET_ROUTER=true ENABLE_EXIT_NODE=true bash
```

### Activer MagicDNS

**MagicDNS est activé par défaut** dans le script.

**Manuellement** (si désactivé) :
1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. DNS → Enable MagicDNS
3. Tous vos appareils auront des noms automatiques

**Personnaliser le nom** :
```bash
# Sur le Pi
sudo tailscale set --hostname=mon-pi

# Maintenant accessible via :
http://mon-pi:8000/studio
```

### Configurer Subnet Router

**Étape 1 : Activer IP Forwarding**
```bash
# Déjà fait par le script, mais si besoin :
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

**Étape 2 : Advertiser routes**
```bash
# Advertiser votre réseau local (ex: 192.168.1.0/24)
sudo tailscale up --advertise-routes=192.168.1.0/24
```

**Étape 3 : Approuver dans admin panel**
1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. Machines → raspberrypi → Edit route settings
3. Approuver subnet routes

**Tester** :
```bash
# Depuis autre appareil Tailscale
ping 192.168.1.1          → Votre box
http://192.168.1.50       → Appareil local
```

### Configurer Exit Node

**Étape 1 : Activer sur le Pi**
```bash
sudo tailscale up --advertise-exit-node
```

**Étape 2 : Approuver dans admin panel**
1. [login.tailscale.com](https://login.tailscale.com)
2. Machines → raspberrypi → Edit route settings
3. Use as exit node → Enable

**Étape 3 : Utiliser sur autre appareil**
```bash
# Desktop/laptop
tailscale up --exit-node=raspberrypi

# Vérifier IP publique
curl ifconfig.me
# → Affiche IP publique de votre Pi !
```

**Désactiver** :
```bash
tailscale up --exit-node=
```

### Configurer ACLs (Access Control Lists)

**ACLs permettent** : Contrôler qui accède à quoi dans votre réseau

**Exemple : Bloquer accès Supabase pour certains users**

1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. Access Controls → Edit
3. Ajouter règles :

```json
{
  "acls": [
    // Admin accède à tout
    {
      "action": "accept",
      "src": ["user@example.com"],
      "dst": ["*:*"]
    },

    // Famille accède à Homepage et Grafana uniquement
    {
      "action": "accept",
      "src": ["famille@example.com"],
      "dst": ["raspberrypi:80", "raspberrypi:3002"]
    },

    // Ami accède à Homepage uniquement
    {
      "action": "accept",
      "src": ["ami@example.com"],
      "dst": ["raspberrypi:80"]
    }
  ]
}
```

### Configurer SSH via Tailscale

**Avantage** : SSH sans mot de passe, authentification Tailscale

**Activer** :
```bash
# Sur le Pi
sudo tailscale up --ssh

# Depuis autre appareil
ssh raspberrypi    # Pas besoin de user@ ni mot de passe !
```

**Fonctionne avec** :
- VSCode Remote SSH
- rsync
- scp
- git (si Gitea installé)

---

## 📱 Clients

### Installation Clients par Plateforme

#### Windows
1. Télécharger : [Tailscale pour Windows](https://tailscale.com/download/windows)
2. Installer `.exe`
3. Lancer Tailscale → Se connecter avec compte
4. Icône apparaît dans system tray

#### macOS
1. Télécharger : [Tailscale pour macOS](https://tailscale.com/download/macos)
2. Installer `.pkg`
3. Lancer Tailscale → Se connecter
4. Menu bar icon

#### Linux (Ubuntu/Debian)
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

#### iOS (iPhone/iPad)
1. App Store → Rechercher "Tailscale"
2. Installer
3. Ouvrir → Se connecter
4. Activer VPN dans Settings

#### Android
1. Google Play → Rechercher "Tailscale"
2. Installer
3. Ouvrir → Se connecter
4. Activer VPN

### Configuration Clients

**Après installation** :

1. **Se connecter** avec même compte que le Pi
2. **Vérifier connexion** :
   ```bash
   # Desktop
   tailscale status

   # Mobile
   Ouvrir app → Voir liste appareils
   ```

3. **Tester accès Pi** :
   ```bash
   ping raspberrypi
   curl http://raspberrypi
   ```

4. **(Optionnel) Utiliser Exit Node** :
   - Desktop : `tailscale up --exit-node=raspberrypi`
   - Mobile : App Tailscale → Exit Node → Sélectionner Pi

### Accès Services depuis Clients

**Homepage** :
```
http://raspberrypi              # MagicDNS
http://100.64.1.5              # IP Tailscale
```

**Supabase Studio** :
```
http://raspberrypi:8000/studio
```

**Grafana** :
```
http://raspberrypi:3002
```

**Portainer** :
```
http://raspberrypi:9000
```

**SSH** :
```bash
ssh pi@raspberrypi
```

---

## 🔐 Sécurité

### Bonnes Pratiques

✅ **Activées par défaut** :
- Chiffrement WireGuard (ultra-sécurisé)
- Authentification SSO (Google, GitHub, Microsoft)
- Clés rotées automatiquement
- MagicDNS sécurisé (requêtes chiffrées)

✅ **Recommandées** :
- Activer 2FA sur compte Tailscale
- Utiliser ACLs pour limiter accès
- Désactiver key expiry (si confiance totale)
- Utiliser SSH via Tailscale (pas besoin port 22 ouvert)

✅ **Pour paranoïaques** :
- Self-host Headscale (alternative open-source)
- Exit Node + Pi-hole (blocage ads/trackers)
- Firewall strict (allow Tailscale uniquement)

❌ **À éviter** :
- Partager clés d'authentification
- Désactiver MagicDNS (moins sécurisé sans)
- Exposer services via Tailscale ET publiquement (doublon)

### Activer 2FA

1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. Settings → User Settings
3. Two-factor authentication → Enable
4. Scanner QR code avec app (Google Authenticator, Authy)

### Configurer Key Expiry

**Par défaut** : Clés expirent après 180 jours (sécurité)

**Désactiver expiry** (confiance totale dans appareil) :
1. [login.tailscale.com](https://login.tailscale.com)
2. Machines → raspberrypi → ...
3. Disable key expiry

**Révoquer appareil** :
1. Machines → Appareil → ...
2. Delete

### Firewall Configuration

**Tailscale configure automatiquement le firewall**, mais si besoin manuel :

```bash
# UFW
sudo ufw allow in on tailscale0
sudo ufw enable

# iptables
sudo iptables -A INPUT -i tailscale0 -j ACCEPT
```

### Alternative : Headscale (Self-Hosted)

**Headscale** = Serveur de coordination Tailscale open-source

**Avantages** :
- ✅ 100% self-hosted
- ✅ Pas de dépendance à Tailscale Inc.
- ✅ Contrôle total

**Inconvénients** :
- ❌ Plus complexe à installer
- ❌ Pas de DERP relay (NAT traversal difficile)
- ❌ Pas d'apps mobiles officielles

**Installation** : Voir [Guide Headscale](docs/HEADSCALE.md)

---

## 🆘 Troubleshooting

### Tailscale ne se connecte pas

**Symptôme** : `tailscale status` affiche "Logged out"

**Solutions** :

1. **Re-authentifier** :
   ```bash
   sudo tailscale up
   # Ouvrir URL affichée dans navigateur
   ```

2. **Vérifier service** :
   ```bash
   sudo systemctl status tailscaled
   sudo systemctl restart tailscaled
   ```

3. **Vérifier firewall** :
   ```bash
   sudo ufw status
   # Tailscale utilise UDP 41641 (si NAT traversal échoue)
   ```

### MagicDNS ne fonctionne pas

**Symptôme** : `ping raspberrypi` échoue, mais `ping 100.64.1.5` fonctionne

**Solutions** :

1. **Vérifier MagicDNS activé** :
   - [login.tailscale.com](https://login.tailscale.com) → DNS → MagicDNS → Enable

2. **Vérifier DNS client** :
   ```bash
   # Desktop Linux/macOS
   cat /etc/resolv.conf
   # Doit contenir : nameserver 100.100.100.100

   # Windows
   ipconfig /all
   # DNS Servers doit contenir 100.100.100.100
   ```

3. **Redémarrer Tailscale** :
   ```bash
   sudo tailscale down
   sudo tailscale up
   ```

### Subnet Router ne route pas

**Symptôme** : Impossible d'accéder à 192.168.1.x via VPN

**Solutions** :

1. **Vérifier IP forwarding activé** :
   ```bash
   sysctl net.ipv4.ip_forward
   # Doit retourner : net.ipv4.ip_forward = 1

   # Si 0 :
   sudo sysctl -w net.ipv4.ip_forward=1
   ```

2. **Vérifier routes advertised** :
   ```bash
   tailscale status
   # Doit afficher : raspberrypi ... relay 192.168.1.0/24
   ```

3. **Vérifier approval dans admin panel** :
   - [login.tailscale.com](https://login.tailscale.com)
   - Machines → raspberrypi → Routes → Approve

4. **Vérifier client utilise route** :
   ```bash
   # Sur client
   tailscale status --peers
   # Doit afficher routes acceptées
   ```

### Exit Node lent

**Symptôme** : Internet très lent via Exit Node

**Solutions** :

1. **Vérifier bande passante Pi** :
   ```bash
   # Tester upload depuis Pi
   speedtest-cli
   ```

2. **Utiliser DERP relay proche** :
   - Tailscale choisit automatiquement
   - Vérifier dans `tailscale netcheck`

3. **Optimiser MTU** :
   ```bash
   # Sur le Pi
   sudo ip link set dev tailscale0 mtu 1280
   ```

### Connection via DERP uniquement (pas direct)

**Symptôme** : `tailscale status` affiche "relay" au lieu de "direct"

**Explications** : Normal si :
- Derrière CGNAT (IP 100.x.x.x)
- Firewall strict bloque UDP
- NAT très restrictif

**Améliorer** :

1. **Ouvrir UDP 41641** sur firewall
2. **Activer UPnP** sur box Internet
3. **Utiliser Tailscale DERP** (automatique, performance OK)

**Vérifier DERP utilisé** :
```bash
tailscale netcheck
```

---

## 📚 Documentation

### Guides Disponibles

- **[Guide Débutant](vpn-wireguard-guide.md)** - Guide pédagogique complet pour novices
- **[Installation](vpn-wireguard-setup.md)** - Installation détaillée étape par étape
- **[ROADMAP.md](../ROADMAP.md)** - Plan de développement Pi5-Setup

### Documentation Externe

- **[Tailscale Docs](https://tailscale.com/kb/)** - Documentation officielle
- **[WireGuard Docs](https://www.wireguard.com/)** - Protocole sous-jacent
- **[Headscale](https://github.com/juanfont/headscale)** - Alternative self-hosted

### Guides Spécifiques

- [Subnet Router Guide](https://tailscale.com/kb/1019/subnets/) - Tailscale officiel
- [Exit Node Guide](https://tailscale.com/kb/1103/exit-nodes/) - Tailscale officiel
- [ACL Examples](https://tailscale.com/kb/1018/acls/) - Exemples de règles

### Communautés

- [r/Tailscale](https://reddit.com/r/Tailscale) - Reddit community
- [Tailscale Slack](https://tailscale.com/contact/support) - Support officiel
- [GitHub Discussions](https://github.com/tailscale/tailscale/discussions)

---

## 🎯 Prochaines Étapes

Une fois Tailscale installé :

1. **Installer clients** sur tous vos appareils
2. **Tester accès** à Homepage, Supabase, Grafana
3. **(Optionnel) Activer Subnet Router** pour accès NAS/réseau local
4. **(Optionnel) Activer Exit Node** pour sécuriser WiFi public
5. **Configurer ACLs** si vous partagez avec famille/amis
6. **Intégrer avec Homepage** → Liens directs via MagicDNS

**Prochaine phase** : [Phase 5 - Gitea + CI/CD](../ROADMAP.md#phase-5)

---

## 🤝 Contribution

Contributions bienvenues ! Voir [CONTRIBUTING.md](../CONTRIBUTING.md).

---

## 📄 Licence

MIT License - Voir [LICENSE](../LICENSE)

---

<p align="center">
  <strong>🔐 VPN Zero-Config pour Raspberry Pi 5 🔐</strong>
</p>

<p align="center">
  <sub>Tailscale • WireGuard • MagicDNS • Subnet Router • Exit Node • ACLs</sub>
</p>
