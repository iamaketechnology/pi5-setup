# 🚀 Installation Traefik Stack - Guide Rapide

> **3 scénarios d'installation selon vos besoins**

---

## 🎯 Choisir Votre Scénario

### Quel scénario pour vous ?

**Répondez à ces questions** :

1. **Avez-vous un nom de domaine** (ex: monpi.fr) ?
   - ✅ Oui → **Scénario 2 (Cloudflare)**
   - ❌ Non → **Scénario 1 (DuckDNS)** ou **Scénario 3 (VPN)**

2. **Voulez-vous exposer sur Internet** ou juste accès local/VPN ?
   - 🌍 Internet → **Scénario 1 ou 2**
   - 🔒 VPN uniquement → **Scénario 3**

3. **Budget** ?
   - 💰 Gratuit total → **Scénario 1 (DuckDNS)** ou **Scénario 3 (VPN)**
   - 💰 ~8€/an pour domaine → **Scénario 2 (Cloudflare)**

4. **Niveau technique** ?
   - ⭐ Débutant → **Scénario 1 (DuckDNS)**
   - ⭐⭐ Intermédiaire → **Scénario 2 (Cloudflare)**
   - ⭐⭐⭐ Avancé → **Scénario 3 (VPN)**

---

## 🟢 Scénario 1 : DuckDNS (Recommandé Débutants)

### Vue d'Ensemble
- **Gratuit** : 100%
- **Difficulté** : ⭐ Facile
- **Temps** : ~15 min
- **Résultat** : `https://monpi.duckdns.org/studio`

### Prérequis
- [ ] Raspberry Pi 5 avec Supabase installé
- [ ] Ports 80 et 443 ouverts sur votre box Internet
- [ ] Compte GitHub/Google (pour DuckDNS)

### Installation

#### 1️⃣ Créer compte DuckDNS (2 min)

1. Aller sur [duckdns.org](https://www.duckdns.org)
2. Se connecter avec GitHub/Google
3. Créer un sous-domaine : `monpi`
4. **Noter le token** affiché en haut

#### 2️⃣ Configurer box Internet (5 min)

**Ouvrir ports** :
- Port **80** (HTTP) → 192.168.1.100:80
- Port **443** (HTTPS) → 192.168.1.100:443

(Remplacer 192.168.1.100 par l'IP de votre Pi)

#### 3️⃣ Installer Traefik (5 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Le script va demander** :
- Sous-domaine DuckDNS : `monpi`
- Token DuckDNS : `a1b2c3d4...`
- Email : `votre@email.com`

#### 4️⃣ Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

#### 5️⃣ Tester ✅

```
https://monpi.duckdns.org/studio   → Supabase Studio
https://monpi.duckdns.org/api      → Supabase API
https://monpi.duckdns.org/traefik  → Traefik Dashboard
```

**Guide complet** : [SCENARIO-DUCKDNS.md](docs/SCENARIO-DUCKDNS.md)

---

## 🔵 Scénario 2 : Cloudflare (Recommandé Production)

### Vue d'Ensemble
- **Coût** : ~8€/an (domaine)
- **Difficulté** : ⭐⭐ Moyen
- **Temps** : ~25 min
- **Résultat** : `https://studio.monpi.fr`

### Prérequis
- [ ] Raspberry Pi 5 avec Supabase installé
- [ ] Nom de domaine acheté (OVH, Gandi, etc.)
- [ ] Compte Cloudflare (gratuit)
- [ ] Ports 80 et 443 ouverts sur votre box

### Installation

#### 1️⃣ Acheter un domaine (5 min)

**Registrars recommandés** :
- [OVH](https://www.ovh.com) : ~8€/an (.fr)
- [Porkbun](https://porkbun.com) : ~9€/an
- [Namecheap](https://namecheap.com) : ~10€/an

#### 2️⃣ Configurer Cloudflare (10 min)

1. Créer compte sur [cloudflare.com](https://www.cloudflare.com)
2. Ajouter votre domaine (plan **Free**)
3. Changer les nameservers chez votre registrar
4. Attendre propagation DNS (~30 min)

**Ajouter DNS** :
- Type `A` → `@` → Votre IP publique → DNS only (🟠)
- Type `A` → `*` → Votre IP publique → DNS only (🟠)

**Créer API Token** :
- Profil → API Tokens → Create Token
- Template : "Edit zone DNS"
- **Copier le token**

#### 3️⃣ Configurer box Internet (5 min)

Même que Scénario 1 (ports 80 et 443)

#### 4️⃣ Installer Traefik (3 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

**Le script va demander** :
- Domaine : `monpi.fr`
- Token Cloudflare : `aBcD1234...`
- Email : `votre@email.com`

#### 5️⃣ Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

**Le script va demander** :
- Sous-domaine API : `api`
- Sous-domaine Studio : `studio`

#### 6️⃣ Tester ✅

```
https://studio.monpi.fr   → Supabase Studio
https://api.monpi.fr      → Supabase API
https://traefik.monpi.fr  → Traefik Dashboard
https://monpi.fr          → Homepage (à installer)
```

**Guide complet** : [SCENARIO-CLOUDFLARE.md](docs/SCENARIO-CLOUDFLARE.md)

---

## 🟡 Scénario 3 : VPN (Sécurité Maximale)

### Vue d'Ensemble
- **Coût** : Gratuit (Tailscale) ou self-hosted (WireGuard)
- **Difficulté** : ⭐⭐⭐ Avancé
- **Temps** : ~30 min
- **Résultat** : `https://studio.pi.local` (via VPN)

### Prérequis
- [ ] Raspberry Pi 5 avec Supabase installé
- [ ] Aucun port à ouvrir (sauf VPN)
- [ ] Choix VPN : Tailscale (simple) ou WireGuard (avancé)

### Installation

#### Option A : Avec Tailscale (Simple)

**1️⃣ Installer Tailscale sur le Pi (3 min)**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**2️⃣ Installer Tailscale sur vos appareils (5 min)**
- [Télécharger Tailscale](https://tailscale.com/download)
- Se connecter avec même compte

**3️⃣ Installer Traefik (VPN mode) (5 min)**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

**4️⃣ Intégrer Supabase (2 min)**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

**5️⃣ Configurer /etc/hosts (2 min)**

Sur chaque appareil, ajouter dans `/etc/hosts` :
```
100.64.1.5  pi.local studio.pi.local api.pi.local
```
(Remplacer `100.64.1.5` par l'IP Tailscale du Pi)

**6️⃣ Tester ✅**
```
https://studio.pi.local   → Warning certificat → Accepter
https://api.pi.local
```

#### Option B : Avec WireGuard (Avancé)

**Voir** : [SCENARIO-VPN.md](docs/SCENARIO-VPN.md#installation-option-b--wireguard)

**Guide complet** : [SCENARIO-VPN.md](docs/SCENARIO-VPN.md)

---

## 📊 Comparaison Rapide

| Critère | 🟢 DuckDNS | 🔵 Cloudflare | 🟡 VPN |
|---------|-----------|---------------|--------|
| **Difficulté** | ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐ Avancé |
| **Temps** | 15 min | 25 min | 30 min |
| **Coût** | Gratuit | ~8€/an | Gratuit |
| **HTTPS valide** | ✅ Oui | ✅ Oui | ❌ Auto-signé |
| **Sous-domaines** | ❌ Paths | ✅ Illimités | ✅ Illimités |
| **Exposition** | ✅ Public | ✅ Public | ❌ VPN seul |
| **Ports box** | 80, 443 | 80, 443 | Aucun |
| **URLs** | `/studio`, `/api` | `studio.`, `api.` | `.pi.local` |

---

## 🆘 Problèmes Courants

### "ERR_SSL_PROTOCOL_ERROR"

**Cause** : Certificat pas généré

**Solution** :
```bash
docker logs traefik -f
```
Attendre 1-2 min que Let's Encrypt génère le certificat.

---

### "404 - Backend not found"

**Cause** : Labels Traefik manquants

**Solution** :
```bash
# Relancer intégration Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

### "DNS not resolving"

**DuckDNS** :
```bash
# Vérifier container DuckDNS
docker logs duckdns

# Forcer mise à jour
curl "https://www.duckdns.org/update?domains=monpi&token=VOTRE_TOKEN&ip="
```

**Cloudflare** :
```bash
# Vérifier propagation
nslookup studio.monpi.fr
```

---

### "Je suis derrière CGNAT"

**Symptôme** : IP publique change constamment ou commence par `100.x.x.x`

**Solution** :
- **Option 1** : Utiliser **Cloudflare Tunnel** (gratuit, pas besoin IP publique)
- **Option 2** : Utiliser **Scénario 3 (VPN)**
- **Option 3** : Contacter votre FAI pour demander IP publique

**Voir** : [SCENARIO-CLOUDFLARE.md#cloudflare-tunnel](docs/SCENARIO-CLOUDFLARE.md#option-avancée--cloudflare-tunnel-cgnat)

---

## 🎯 Après l'Installation

### Étape Suivante : Homepage (Portail)

Une fois Traefik installé, installez Homepage pour avoir un portail d'accueil :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
```

**Résultat** :
- DuckDNS : `https://monpi.duckdns.org`
- Cloudflare : `https://monpi.fr`
- VPN : `https://pi.local`

---

### Services Recommandés à Exposer

**Déjà exposé** :
- ✅ Supabase Studio
- ✅ Supabase API
- ✅ Traefik Dashboard

**À ajouter** (futures phases) :
- [ ] Homepage (portail)
- [ ] Gitea (Git self-hosted)
- [ ] Grafana (monitoring)
- [ ] Portainer (Docker UI)

**Voir** : [Roadmap complète](../ROADMAP.md)

---

## 📚 Documentation Complète

### Guides Détaillés par Scénario
- [Scénario 1 : DuckDNS](docs/SCENARIO-DUCKDNS.md)
- [Scénario 2 : Cloudflare](docs/SCENARIO-CLOUDFLARE.md)
- [Scénario 3 : VPN](docs/SCENARIO-VPN.md)

### Documentation Générale
- [GUIDE DÉBUTANT](traefik-guide.md) - Comprendre Traefik
- [README Principal](README.md) - Vue d'ensemble
- [Comparaison Scénarios](docs/SCENARIOS-COMPARISON.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)

---

## 🔧 Commandes Utiles

### Vérifier statut Traefik
```bash
docker logs traefik -f
docker ps | grep traefik
```

### Redémarrer Traefik
```bash
cd /home/pi/stacks/traefik
docker compose restart
```

### Forcer renouvellement certificat
```bash
cd /home/pi/stacks/traefik
docker compose down
rm acme/acme.json
chmod 600 acme/acme.json
docker compose up -d
```

### Tester connectivité
```bash
# DuckDNS
curl -I https://monpi.duckdns.org/studio

# Cloudflare
curl -I https://studio.monpi.fr

# VPN
curl -k -I https://studio.pi.local
```

---

**Besoin d'aide ?** Consultez le [Troubleshooting complet](docs/TROUBLESHOOTING.md) ou le [GUIDE DÉBUTANT](traefik-guide.md)

🎉 **Bon déploiement !**
