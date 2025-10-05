# 🟡 Scénario 3 : VPN + Certificats Locaux

> **Pour sécurité maximale : Aucune exposition publique**

**Durée** : ~30 minutes
**Difficulté** : ⭐⭐⭐ Avancé
**Coût** : Gratuit (Tailscale) ou WireGuard (self-hosted)

---

## 📋 Vue d'Ensemble

### Ce que vous allez avoir

```
1. Se connecter au VPN (depuis n'importe où)
   ↓
2. Accès sécurisé aux services :
   https://studio.pi.local    → Supabase Studio
   https://api.pi.local       → Supabase API
   https://git.pi.local       → Gitea
   https://pi.local           → Homepage
```

### Avantages
- ✅ **Sécurité maximale** : Aucun port exposé sur Internet
- ✅ **Accès distant** : Depuis n'importe où via VPN
- ✅ **Gratuit** : Tailscale (100 devices) ou WireGuard
- ✅ **Réseau privé** : Comme si vous étiez chez vous

### Limitations
- ❌ **Certificats auto-signés** : Warning navigateur (contournable)
- ❌ **Setup VPN** : Doit installer VPN sur chaque appareil
- ❌ **Plus complexe** : Nécessite compréhension VPN

---

## 🔀 Choix du VPN

### Option A : Tailscale (RECOMMANDÉ)

**Avantages** :
- ✅ Setup ultra-simple (5 min)
- ✅ Mesh VPN (peer-to-peer)
- ✅ NAT traversal automatique
- ✅ Apps mobiles/desktop
- ✅ Gratuit jusqu'à 100 devices
- ✅ DNS Magic (`.ts.net` domains)

**Inconvénient** :
- ❌ Service tiers (coordination servers)

**Recommandé si** : Vous voulez simple et rapide

---

### Option B : WireGuard (SELF-HOSTED)

**Avantages** :
- ✅ 100% self-hosted
- ✅ Très léger (~20 MB RAM)
- ✅ Très rapide (kernel-level)
- ✅ Contrôle total

**Inconvénients** :
- ❌ Config manuelle (clés, peers)
- ❌ Pas de NAT traversal auto
- ❌ Port UDP à ouvrir (51820)

**Recommandé si** : Vous êtes expert et voulez 100% self-hosted

---

## 🚀 Installation Option A : Tailscale

### Étape 1 : Créer un compte Tailscale (2 min)

1. Aller sur [tailscale.com](https://tailscale.com)
2. Cliquer "Get Started"
3. Se connecter avec GitHub / Google / Microsoft
4. Plan : **Personal** (gratuit, 100 devices)

---

### Étape 2 : Installer Tailscale sur le Pi (3 min)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**Suivre le lien affiché** :
```
To authenticate, visit: https://login.tailscale.com/a/abc123def456
```

→ S'authentifier dans le navigateur

**Résultat** :
```
Success. You are now connected to Tailscale!
```

**Noter l'IP Tailscale du Pi** :
```bash
tailscale ip -4
```
→ Exemple : `100.64.1.5`

---

### Étape 3 : Installer Tailscale sur vos appareils (5 min)

#### Sur votre PC/Mac/Linux

**Windows** :
1. Télécharger [Tailscale Windows](https://tailscale.com/download/windows)
2. Installer
3. Se connecter avec même compte

**macOS** :
1. Télécharger [Tailscale macOS](https://tailscale.com/download/macos)
2. Installer
3. Se connecter

**Linux** :
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

#### Sur votre smartphone

**Android** :
1. [Tailscale sur Google Play](https://play.google.com/store/apps/details?id=com.tailscale.ipn)
2. Installer
3. Se connecter

**iOS** :
1. [Tailscale sur App Store](https://apps.apple.com/app/tailscale/id1470499037)
2. Installer
3. Se connecter

---

### Étape 4 : Activer MagicDNS (1 min)

**Dans l'admin Tailscale** ([admin.tailscale.com](https://login.tailscale.com/admin)):

1. DNS → Enable MagicDNS
2. Sauvegarder

**Résultat** : Vous pouvez accéder au Pi via :
- `http://100.64.1.5` (IP Tailscale)
- `http://pi` (hostname)

---

### Étape 5 : Installer Traefik (VPN mode) (5 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

**Le script va** :
- ✅ Configurer Traefik pour écouter sur l'IP Tailscale
- ✅ Générer des certificats auto-signés (mkcert)
- ✅ Configurer les domaines `.pi.local`
- ✅ Lancer Traefik

---

### Étape 6 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase-vpn.sh | sudo bash
```

---

### Étape 7 : Configurer `/etc/hosts` (2 min)

**Sur chaque appareil connecté au VPN** :

**Linux/macOS** :
```bash
sudo nano /etc/hosts
```

**Windows** :
```
C:\Windows\System32\drivers\etc\hosts
```
(Ouvrir en Administrateur avec Notepad)

**Ajouter** :
```
100.64.1.5  pi.local
100.64.1.5  studio.pi.local
100.64.1.5  api.pi.local
100.64.1.5  git.pi.local
100.64.1.5  traefik.pi.local
```

(Remplacer `100.64.1.5` par l'IP Tailscale de votre Pi)

---

### Étape 8 : Tester ! (1 min)

**Depuis un appareil connecté au VPN** :

1. **Supabase Studio** :
   ```
   https://studio.pi.local
   ```
   → Warning certificat → Cliquer "Avancé" → "Accepter le risque"

2. **Supabase API** :
   ```
   https://api.pi.local/rest/v1/
   ```

🎉 **Terminé !** Accès sécurisé sans exposer de ports !

---

## 🚀 Installation Option B : WireGuard

### Étape 1 : Installer WireGuard sur le Pi (3 min)

```bash
sudo apt update
sudo apt install wireguard wireguard-tools
```

---

### Étape 2 : Générer les clés (2 min)

**Sur le Pi** :
```bash
# Clés serveur
wg genkey | sudo tee /etc/wireguard/server_private.key
sudo cat /etc/wireguard/server_private.key | wg pubkey | sudo tee /etc/wireguard/server_public.key

# Clés client (pour votre PC)
wg genkey | tee client_private.key
cat client_private.key | wg pubkey | tee client_public.key
```

---

### Étape 3 : Configurer le serveur WireGuard (5 min)

**Créer** `/etc/wireguard/wg0.conf` :
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <SERVER_PRIVATE_KEY>
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 10.0.0.2/32
```

**Remplacer** :
- `<SERVER_PRIVATE_KEY>` : Contenu de `/etc/wireguard/server_private.key`
- `<CLIENT_PUBLIC_KEY>` : Contenu de `client_public.key`

**Démarrer** :
```bash
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

---

### Étape 4 : Ouvrir le port UDP 51820 (2 min)

**Sur la box** :
- Port externe : 51820 UDP
- Port interne : 51820 UDP
- IP : 192.168.1.100 (Pi)

**Firewall Pi** :
```bash
sudo ufw allow 51820/udp
```

---

### Étape 5 : Configurer le client WireGuard (5 min)

**Sur votre PC**, créer `wg-client.conf` :
```ini
[Interface]
PrivateKey = <CLIENT_PRIVATE_KEY>
Address = 10.0.0.2/24
DNS = 10.0.0.1

[Peer]
PublicKey = <SERVER_PUBLIC_KEY>
Endpoint = VOTRE_IP_PUBLIQUE:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

**Remplacer** :
- `<CLIENT_PRIVATE_KEY>` : Contenu de `client_private.key`
- `<SERVER_PUBLIC_KEY>` : Contenu de `/etc/wireguard/server_public.key`
- `VOTRE_IP_PUBLIQUE` : Votre IP (voir [whatismyip.com](https://www.whatismyip.com))

**Connecter** :
```bash
sudo wg-quick up wg-client
```

**Tester** :
```bash
ping 10.0.0.1
```

---

### Étape 6 : Installer Traefik + Intégrer Supabase

**Même procédure qu'avec Tailscale** (Étapes 5-8)

---

## 🔐 Certificats HTTPS (Éliminer le Warning)

### Option 1 : mkcert (Simple)

**Sur le Pi** :
```bash
# Installer mkcert
sudo apt install libnss3-tools
wget https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-arm64
chmod +x mkcert-v1.4.4-linux-arm64
sudo mv mkcert-v1.4.4-linux-arm64 /usr/local/bin/mkcert

# Générer CA
mkcert -install

# Générer certificats
mkcert "*.pi.local" pi.local
```

**Sur chaque client** :
1. Copier `rootCA.pem` (depuis `~/.local/share/mkcert/`)
2. L'installer dans le magasin de certificats du système

**Windows** :
```powershell
certutil -addstore -f "ROOT" rootCA.pem
```

**macOS** :
```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem
```

**Linux** :
```bash
sudo cp rootCA.pem /usr/local/share/ca-certificates/mkcert.crt
sudo update-ca-certificates
```

---

### Option 2 : Accepter le Risque (Plus Simple)

**Dans Chrome/Edge** :
1. `https://studio.pi.local`
2. Warning → "Avancé"
3. "Continuer vers studio.pi.local (dangereux)"
4. Cocher "Se souvenir de ce choix"

**Dans Firefox** :
1. Warning → "Avancé"
2. "Accepter le risque et continuer"

---

## 🆘 Troubleshooting

### ❌ "Cannot connect to VPN"

**Tailscale** :
```bash
# Vérifier statut
sudo tailscale status

# Relancer
sudo tailscale down
sudo tailscale up
```

**WireGuard** :
```bash
# Vérifier statut
sudo wg show

# Relancer
sudo systemctl restart wg-quick@wg0
```

---

### ❌ "Cannot reach pi.local"

**Vérifier** :
```bash
# Depuis le client VPN
ping 10.0.0.1  # WireGuard
ping 100.64.1.5  # Tailscale
```

**Si pas de réponse** :
1. VPN pas connecté
2. Firewall bloque
3. IP incorrecte

---

### ❌ "NET::ERR_CERT_AUTHORITY_INVALID"

**Normal** avec certificats auto-signés.

**Solutions** :
1. Installer mkcert (voir ci-dessus)
2. Accepter le risque
3. Utiliser HTTP (pas HTTPS) → Pas recommandé

---

## 📊 Performances

### Latence Ajoutée

- **Tailscale** : +5-15ms (DERP relay) ou +1-3ms (direct)
- **WireGuard** : +1-5ms
- **Traefik** : +3-7ms

**Total** : ~10-25ms (Tailscale) ou ~5-12ms (WireGuard)

### Débit

- **Tailscale** : ~500-800 Mbps (direct), ~100-300 Mbps (relay)
- **WireGuard** : ~900 Mbps+ (limité par le Pi)

---

## 🎯 Quand Utiliser ce Scénario ?

### ✅ Recommandé si :
- Vous ne voulez **rien exposer** sur Internet
- Vous êtes derrière **CGNAT** (pas d'IP publique)
- Vous voulez **sécurité maximale**
- Vous accédez depuis des **réseaux non sûrs** (WiFi public)

### ❌ Pas recommandé si :
- Vous voulez partager l'accès avec **non-techniciens** (warning certificat)
- Vous voulez accès **sans VPN** (ex: montrer un site à un client)
- Vous préférez **simplicité** → Utiliser Scénario 1 ou 2

---

## 🔄 Combiner avec Scénario 1 ou 2

**Vous pouvez avoir les 2** :

1. **Services publics** → Traefik avec domaine (Scénario 2)
   - Homepage (portail public)
   - Blog, portfolio

2. **Services sensibles** → VPN uniquement (Scénario 3)
   - Supabase Studio
   - Portainer
   - Grafana
   - Traefik Dashboard

**Config** :
```yaml
# Supabase Studio → VPN only
labels:
  - "traefik.http.routers.studio.rule=Host(`studio.pi.local`)"
  - "traefik.http.routers.studio.middlewares=vpn-only"

# Homepage → Public
labels:
  - "traefik.http.routers.homepage.rule=Host(`monpi.fr`)"
```

---

## 📚 Ressources

### Tailscale
- [Tailscale Docs](https://tailscale.com/kb/)
- [MagicDNS](https://tailscale.com/kb/1081/magicdns/)

### WireGuard
- [WireGuard Docs](https://www.wireguard.com/quickstart/)
- [WireGuard Setup Guide](https://github.com/pirate/wireguard-docs)

### mkcert
- [mkcert GitHub](https://github.com/FiloSottile/mkcert)

---

**Besoin d'aide ?** → [Troubleshooting](TROUBLESHOOTING.md) | [r/Tailscale](https://reddit.com/r/Tailscale)
