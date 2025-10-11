# 🚀 Installation Tailscale VPN - Guide Complet

> **Installation pas-à-pas de Tailscale sur Raspberry Pi 5**

---

## 📋 Prérequis

### Système

- [ ] Raspberry Pi 5 avec Raspberry Pi OS 64-bit
- [ ] Docker installé ([voir Phase 1](../pi5-supabase-stack/))
- [ ] Connexion Internet active
- [ ] Au moins 500 MB d'espace disque libre

### Vérifier Prérequis

```bash
# Vérifier OS
uname -a
# Doit afficher : Linux raspberrypi ... aarch64 GNU/Linux

# Vérifier Docker
docker --version
# Doit afficher : Docker version 24.x.x ou supérieur

# Vérifier Internet
ping -c 3 tailscale.com

# Vérifier espace disque
df -h /
# Au moins 500M disponible
```

---

## 🎯 Étape 1 : Créer Compte Tailscale

### Option A : Nouveau Compte (Gratuit)

1. **Aller sur [tailscale.com](https://tailscale.com)**
2. **Cliquer "Get Started"**
3. **Choisir méthode d'authentification** :
   - Google
   - GitHub
   - Microsoft
   - Email (avec SSO)

4. **Se connecter avec compte choisi**
5. **Compte créé** - Vous êtes redirigé vers admin panel

### Option B : Compte Existant

Si vous avez déjà un compte Tailscale :
- Vous pouvez ajouter le Pi à votre réseau existant
- Limite : 100 appareils en plan gratuit

---

## 🚀 Étape 2 : Installer Tailscale sur le Pi

### Installation Automatique (Recommandé)

**Une seule commande** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-vpn-stack/scripts/01-tailscale-setup.sh | sudo bash
```

**Ce que fait le script** :
1. ✅ Vérifie prérequis (OS, Docker, Internet)
2. ✅ Télécharge et installe Tailscale
3. ✅ Configure le service systemd
4. ✅ Active MagicDNS
5. ✅ Génère URL d'authentification
6. ✅ (Optionnel) Active Subnet Router
7. ✅ (Optionnel) Active Exit Node
8. ✅ Affiche résumé configuration

**Durée** : ~2-3 minutes

### Installation Manuelle (Avancé)

Si vous préférez installer manuellement :

```bash
# 1. Télécharger script officiel Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 2. Démarrer Tailscale
sudo tailscale up

# 3. Ouvrir URL affichée dans navigateur pour authentifier
```

---

## 🔑 Étape 3 : Authentifier le Pi

### Méthode Web (Automatique)

**Le script affiche une URL**, exemple :
```
https://login.tailscale.com/a/1234567890abcdef
```

**Actions** :
1. **Copier l'URL** affichée
2. **Ouvrir dans navigateur** (sur n'importe quel appareil)
3. **Se connecter** avec compte Tailscale
4. **Autoriser l'appareil** "raspberrypi"
5. **Succès** - Le Pi apparaît dans votre réseau

### Vérifier Authentification

```bash
# Vérifier statut
tailscale status

# Doit afficher :
# 100.64.1.5   raspberrypi          user@example.com   linux   -
```

### Troubleshooting Authentification

**Erreur "Logged out"** :

```bash
# Re-générer URL
sudo tailscale up

# Ouvrir nouvelle URL affichée
```

**Erreur "Permission denied"** :

```bash
# Vérifier service
sudo systemctl status tailscaled

# Redémarrer si nécessaire
sudo systemctl restart tailscaled
```

---

## ✅ Étape 4 : Vérifier Connexion

### Vérifier IP Tailscale

```bash
tailscale ip -4
# Doit afficher : 100.64.1.X (votre IP Tailscale)
```

### Vérifier MagicDNS

```bash
# Ping par nom
ping -c 3 raspberrypi
# Doit fonctionner si MagicDNS activé

# Si échec, activer MagicDNS :
# 1. Aller sur login.tailscale.com
# 2. DNS → Enable MagicDNS
```

### Vérifier Services Accessibles

```bash
# Vérifier Homepage (si installé)
curl -I http://raspberrypi

# Vérifier Supabase Studio (si installé)
curl -I http://raspberrypi:8000

# Vérifier Portainer (si installé)
curl -I http://raspberrypi:9000
```

### Lister Tous les Peers

```bash
tailscale status

# Exemple sortie :
# 100.64.1.2   mon-laptop         user@example.com   windows -
# 100.64.1.3   mon-smartphone     user@example.com   ios     -
# 100.64.1.5   raspberrypi        user@example.com   linux   -
```

---

## 📱 Étape 5 : Installer Clients sur Vos Appareils

### Windows

1. **Télécharger** : [tailscale.com/download/windows](https://tailscale.com/download/windows)
2. **Exécuter** le fichier `.exe`
3. **Suivre l'installateur**
4. **Lancer Tailscale** depuis menu Démarrer
5. **Se connecter** avec même compte
6. **Icône apparaît** dans system tray (barre des tâches)

**Tester connexion** :
```powershell
# PowerShell
ping raspberrypi
```

### macOS

1. **Télécharger** : [tailscale.com/download/macos](https://tailscale.com/download/macos)
2. **Installer** le fichier `.pkg`
3. **Lancer Tailscale** depuis Applications
4. **Se connecter** avec même compte
5. **Icône menu bar** en haut à droite

**Tester connexion** :
```bash
# Terminal
ping raspberrypi
```

### Linux (Ubuntu/Debian)

```bash
# Installer Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Démarrer et authentifier
sudo tailscale up

# Ouvrir URL affichée dans navigateur
```

**Tester connexion** :
```bash
ping raspberrypi
```

### iOS (iPhone/iPad)

1. **Ouvrir App Store**
2. **Rechercher** "Tailscale"
3. **Installer** l'application
4. **Ouvrir Tailscale**
5. **Se connecter** avec compte
6. **Activer VPN** (toggle en haut)

**Tester connexion** :
- Ouvrir Safari
- Aller sur `http://raspberrypi`

### Android

1. **Ouvrir Google Play Store**
2. **Rechercher** "Tailscale"
3. **Installer** l'application
4. **Ouvrir Tailscale**
5. **Se connecter** avec compte
6. **Activer VPN** (toggle en haut)

**Tester connexion** :
- Ouvrir Chrome
- Aller sur `http://raspberrypi`

---

## 🌐 Étape 6 : Accéder aux Services Pi

### Via MagicDNS (Noms Automatiques)

**Homepage** (si installé) :
```
http://raspberrypi
http://raspberrypi:80
```

**Supabase Studio** :
```
http://raspberrypi:8000/studio
http://raspberrypi:8000/project/default
```

**Supabase API** :
```
http://raspberrypi:8000
```

**Grafana** (si installé) :
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

### Via IP Tailscale

Si MagicDNS ne fonctionne pas :

```bash
# Récupérer IP Tailscale du Pi
tailscale status | grep raspberrypi
# Ex: 100.64.1.5

# Accéder aux services
http://100.64.1.5              # Homepage
http://100.64.1.5:8000/studio  # Supabase Studio
http://100.64.1.5:3002         # Grafana
```

### Exemples Pratiques

**Développer en React avec Backend Supabase** :

```javascript
// .env.local
REACT_APP_SUPABASE_URL=http://raspberrypi:8000
REACT_APP_SUPABASE_ANON_KEY=votre-anon-key
```

**Configurer App Mobile** :

```swift
// iOS
let supabase = SupabaseClient(
    supabaseURL: URL(string: "http://raspberrypi:8000")!,
    supabaseKey: "anon-key"
)
```

**Monitorer avec Grafana Mobile** :
- iOS/Android : Ouvrir Tailscale
- Navigateur : `http://raspberrypi:3002`
- Dashboard accessible comme en local

---

## 🎯 Étape 7 : (Optionnel) Fonctionnalités Avancées

### Option A : Activer Subnet Router

**À quoi ça sert ?** Accéder à tout votre réseau local (NAS, imprimante, etc.) via VPN

**Prérequis** :
- [ ] Connaître votre subnet (ex: `192.168.1.0/24`)
- [ ] Pi connecté au réseau local

**Installation** :

```bash
# 1. Activer IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# 2. Advertiser routes (remplacer par votre subnet)
sudo tailscale up --advertise-routes=192.168.1.0/24

# 3. Approuver dans admin panel
# Aller sur login.tailscale.com
# Machines → raspberrypi → Edit route settings → Approve
```

**Tester** :

```bash
# Depuis autre appareil Tailscale
ping 192.168.1.1           # Votre box Internet
http://192.168.1.50        # Ex: NAS Synology
```

**Use Cases** :
- Accéder au NAS depuis n'importe où
- Imprimer sur imprimante réseau
- Accéder caméras IP
- Gérer domotique (Home Assistant)

---

### Option B : Activer Exit Node

**À quoi ça sert ?** Utiliser le Pi comme proxy Internet (sécuriser WiFi public)

**Installation sur Pi** :

```bash
# 1. Advertiser comme exit node
sudo tailscale up --advertise-exit-node

# 2. Approuver dans admin panel
# login.tailscale.com → Machines → raspberrypi → Use as exit node → Enable
```

**Utiliser sur autre appareil** :

**Desktop/Laptop** :
```bash
# Activer
tailscale up --exit-node=raspberrypi

# Vérifier IP publique
curl ifconfig.me
# → Affiche IP publique de votre domicile (via Pi)

# Désactiver
tailscale up --exit-node=
```

**Mobile (iOS/Android)** :
1. Ouvrir app Tailscale
2. Cliquer sur "Exit node"
3. Sélectionner "raspberrypi"
4. Activer

**Use Cases** :
- Sécuriser connexion sur WiFi public (café, hôtel)
- Masquer IP réelle
- Contourner censure/géoblocage
- Bloquer ads (si Pi-hole installé sur Pi)

---

### Option C : Configurer SSH via Tailscale

**Avantages** :
- SSH sans mot de passe
- Authentification via Tailscale
- Aucun port 22 à exposer

**Activer** :

```bash
# Sur le Pi
sudo tailscale up --ssh
```

**Utiliser depuis autre appareil** :

```bash
# SSH automatique (pas besoin de mot de passe)
ssh raspberrypi

# Fonctionne aussi avec user explicite
ssh pi@raspberrypi

# Copier fichiers
scp fichier.txt raspberrypi:~/

# Rsync
rsync -avz dossier/ raspberrypi:~/backup/
```

**Use Cases** :
- VSCode Remote SSH (éditer code sur Pi depuis laptop)
- Deploy via rsync/scp
- Git push/pull (si Gitea sur Pi)

---

### Option D : Configurer ACLs (Contrôle d'Accès)

**À quoi ça sert ?** Limiter qui accède à quoi (famille, amis)

**Accéder ACL Editor** :
1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. Access Controls → Edit

**Exemple : Famille accède à Homepage, pas à Portainer**

```json
{
  "acls": [
    // Admin (vous) accède à tout
    {
      "action": "accept",
      "src": ["admin@example.com"],
      "dst": ["*:*"]
    },

    // Famille accède à Homepage (80) et Grafana (3002)
    {
      "action": "accept",
      "src": ["famille@example.com"],
      "dst": ["raspberrypi:80", "raspberrypi:3002"]
    },

    // Bloquer accès Portainer pour famille
    {
      "action": "drop",
      "src": ["famille@example.com"],
      "dst": ["raspberrypi:9000"]
    }
  ]
}
```

**Tester** :
1. Sauvegarder ACLs
2. Inviter famille dans Tailnet
3. Depuis compte famille : `http://raspberrypi` fonctionne
4. `http://raspberrypi:9000` est bloqué

---

### Option E : Personnaliser Hostname

**Par défaut** : Hostname = nom de la machine (`raspberrypi`)

**Changer pour nom custom** :

```bash
# Méthode 1 : Via Tailscale
sudo tailscale set --hostname=mon-pi

# Méthode 2 : Via admin panel
# login.tailscale.com → Machines → raspberrypi → ... → Rename
```

**Résultat** :
```
http://mon-pi              # Nouveau nom
http://mon-pi:8000/studio  # Supabase via nouveau nom
```

---

## 🔍 Vérification Finale

### Checklist Post-Installation

- [ ] Tailscale installé et authentifié sur Pi
- [ ] `tailscale status` affiche Pi dans le réseau
- [ ] MagicDNS activé (ping raspberrypi fonctionne)
- [ ] Clients installés sur desktop/mobile
- [ ] Services Pi accessibles via VPN (Homepage, Supabase, etc.)
- [ ] (Optionnel) Subnet Router fonctionne
- [ ] (Optionnel) Exit Node fonctionne
- [ ] (Optionnel) SSH via Tailscale fonctionne

### Commandes de Diagnostic

```bash
# 1. Vérifier statut Tailscale
tailscale status

# 2. Vérifier IP Tailscale
tailscale ip -4

# 3. Vérifier MagicDNS
ping raspberrypi

# 4. Vérifier peers
tailscale status --peers

# 5. Tester connectivité réseau
tailscale netcheck

# 6. Voir logs
journalctl -u tailscaled -f
```

### Résultats Attendus

**tailscale status** :
```
100.64.1.5   raspberrypi        admin@example.com   linux   -
100.64.1.2   mon-laptop         admin@example.com   windows -
```

**tailscale ip -4** :
```
100.64.1.5
```

**ping raspberrypi** :
```
PING raspberrypi (100.64.1.5): 56 data bytes
64 bytes from 100.64.1.5: icmp_seq=0 ttl=64 time=2.3 ms
```

---

## 🆘 Troubleshooting Installation

### Erreur "tailscale: command not found"

**Cause** : Tailscale pas installé correctement

**Solution** :
```bash
# Réinstaller
curl -fsSL https://tailscale.com/install.sh | sh

# Vérifier installation
which tailscale
# Doit afficher : /usr/bin/tailscale
```

---

### Erreur "Logged out" après installation

**Cause** : Authentification pas complétée

**Solution** :
```bash
# Re-générer URL authentification
sudo tailscale up

# Ouvrir URL affichée et autoriser appareil
```

---

### MagicDNS ne résout pas noms

**Cause** : MagicDNS pas activé dans admin panel

**Solution** :
1. Aller sur [login.tailscale.com](https://login.tailscale.com)
2. DNS → Enable MagicDNS
3. Redémarrer Tailscale sur clients :
   ```bash
   sudo tailscale down
   sudo tailscale up
   ```

---

### Impossible de ping d'autres appareils

**Cause** : Firewall bloque trafic Tailscale

**Solution** :
```bash
# UFW
sudo ufw allow in on tailscale0

# iptables
sudo iptables -A INPUT -i tailscale0 -j ACCEPT
sudo iptables-save > /etc/iptables/rules.v4
```

---

### Connexion lente (relay au lieu de direct)

**Cause** : NAT traversal échoue, utilise DERP relay

**C'est normal si** :
- Derrière CGNAT
- Firewall très strict
- Réseau mobile

**Améliorer (optionnel)** :
```bash
# Ouvrir UDP 41641 sur firewall
sudo ufw allow 41641/udp

# Activer UPnP sur box Internet (via interface web box)
```

**Vérifier type de connexion** :
```bash
tailscale status
# "relay" = via DERP (normal, performance OK)
# "direct" = peer-to-peer (meilleur, mais pas toujours possible)
```

---

## 🎯 Prochaines Étapes

### Intégration avec Homepage

Si Homepage installé, ajouter liens Tailscale :

```yaml
# ~/stacks/homepage/config/services.yaml
- VPN:
    - Tailscale Admin:
        href: https://login.tailscale.com/admin/machines
        description: Gérer appareils et ACLs
        icon: tailscale.png

- Services (via VPN):
    - Supabase Studio:
        href: http://raspberrypi:8000/studio
        description: Via Tailscale uniquement
```

### Optimisations Avancées

**1. Activer Tailscale SSH** (pas besoin port 22) :
```bash
sudo tailscale up --ssh
```

**2. Désactiver key expiry** (confiance totale) :
- login.tailscale.com → Machines → raspberrypi → Disable key expiry

**3. Configurer Exit Node permanent** :
```bash
# Sur client, auto-connect à exit node
tailscale up --exit-node=raspberrypi --exit-node-allow-lan-access
```

**4. Ajouter tags pour organisation** :
- login.tailscale.com → Machines → raspberrypi → Edit tags
- Ex: `tag:server`, `tag:pi`, `tag:home`

### Sécurité Renforcée

**1. Activer 2FA** :
- login.tailscale.com → Settings → Two-factor authentication

**2. Configurer ACLs strictes** :
- Limiter accès par user/appareil
- Bloquer ports sensibles (Portainer, SSH)

**3. Monitoring Tailscale** :
```bash
# Voir connexions actives
watch -n 1 tailscale status

# Logs en temps réel
journalctl -u tailscaled -f
```

---

## 📚 Documentation Complémentaire

- **[README.md](README.md)** - Vue d'ensemble Tailscale
- **[Guide Débutant](vpn-wireguard-guide.md)** - Guide pédagogique complet
- **[Tailscale Docs](https://tailscale.com/kb/)** - Documentation officielle

---

**Installation terminée !** 🎉

Vous pouvez maintenant accéder à votre Pi depuis n'importe où, de manière sécurisée, sans ouvrir de ports.

**Prochaine phase** : [Phase 5 - Gitea + CI/CD](../ROADMAP.md#phase-5)
