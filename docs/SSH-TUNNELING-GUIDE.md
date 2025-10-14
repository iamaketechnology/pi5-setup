# 🔐 Guide SSH Tunneling pour Débutants - PI5-SETUP

> **Accédez aux services localhost de votre Pi depuis n'importe où, en toute sécurité**

---

## 📋 Table des Matières

1. [Qu'est-ce qu'un Tunnel SSH ?](#quest-ce-quun-tunnel-ssh-)
2. [Pourquoi Utiliser un Tunnel SSH ?](#pourquoi-utiliser-un-tunnel-ssh-)
3. [Prérequis](#prérequis)
4. [Tunnel Simple (Un Service)](#tunnel-simple-un-service)
5. [Tunnel Multiple (Plusieurs Services)](#tunnel-multiple-plusieurs-services)
6. [Tunnel Permanent (Background)](#tunnel-permanent-background)
7. [Cas d'Usage Spécifiques](#cas-dusage-spécifiques)
8. [Troubleshooting](#troubleshooting)
9. [Alternatives (VPN)](#alternatives-vpn)

---

## 🤔 Qu'est-ce qu'un Tunnel SSH ?

### **Analogie Simple**

Imaginez que vous avez un **trésor** (votre base de données PostgreSQL) dans un **coffre-fort** (votre Pi) situé dans une **banque** (votre réseau local). Le coffre-fort n'a pas de fenêtre et ne peut être ouvert que depuis l'intérieur de la banque.

Un **tunnel SSH**, c'est comme creuser un **passage secret sécurisé** depuis votre maison jusqu'à l'intérieur de la banque, vous permettant d'accéder au coffre comme si vous étiez physiquement sur place.

```
┌─────────────────────┐              ┌──────────────────────┐
│   VOTRE MAC         │              │   VOTRE PI (banque)  │
│                     │              │                      │
│  localhost:3000 ────┼──Tunnel SSH──┼───> localhost:3000   │
│  (porte d'entrée)   │  (chiffré)   │     (Studio)         │
│                     │              │                      │
│  localhost:5432 ────┼──Tunnel SSH──┼───> localhost:5432   │
│  (porte d'entrée)   │  (chiffré)   │     (PostgreSQL)     │
└─────────────────────┘              └──────────────────────┘

Vous tapez : http://localhost:3000
→ Magie : le tunnel redirige vers le Pi
→ Vous accédez à Supabase Studio comme si vous étiez sur le Pi !
```

---

## 🎯 Pourquoi Utiliser un Tunnel SSH ?

### **Problème Sans Tunnel**

```bash
# Depuis votre Mac (chez vous ou ailleurs)
curl http://192.168.1.118:3000
# ❌ Connection timeout

psql -h 192.168.1.118 -U postgres
# ❌ Connection refused
```

**Pourquoi ça ne marche pas ?**
Ces services sont configurés en **localhost only** (`127.0.0.1`) pour sécurité. Ils ne répondent qu'aux connexions **depuis le Pi lui-même**.

---

### **Solution : Tunnel SSH**

```bash
# Créer un tunnel
ssh -L 3000:localhost:3000 pi@192.168.1.118

# Maintenant depuis votre Mac :
curl http://localhost:3000
# ✅ Fonctionne ! (redirigé vers le Pi)

open http://localhost:3000
# ✅ Studio s'ouvre dans votre navigateur !
```

---

### **Avantages**

| Avantage | Explication |
|----------|-------------|
| 🔒 **Sécurité** | Connexion chiffrée SSH (même niveau que votre login SSH) |
| 🚀 **Simple** | Une seule commande, pas de config à changer sur le Pi |
| 🔄 **Temporaire** | Fermer le terminal = tunnel fermé (pas de risque oublié ouvert) |
| 🌍 **Universel** | Fonctionne depuis n'importe où (maison, travail, café) |
| 🎯 **Précis** | Tunnel seulement les services dont vous avez besoin |

---

## ✅ Prérequis

### **1. Accès SSH Fonctionnel**

```bash
# Tester depuis votre Mac/PC
ssh pi@192.168.1.118
# OU (si vous avez configuré mDNS)
ssh pi@pi5.local

# Si ça marche → vous êtes prêt !
# Si ça échoue → configurer SSH d'abord
```

**Configurer SSH** (si pas déjà fait) :
```bash
# Sur le Pi (via clavier+écran ou autre session)
sudo raspi-config
# Interface Options → SSH → Enable

# Redémarrer SSH
sudo systemctl restart ssh
```

---

### **2. Connaître l'IP du Pi**

```bash
# Depuis le Pi
hostname -I
# Exemple : 192.168.1.118

# Ou utiliser mDNS (si configuré)
ping pi5.local
# PING pi5.local (192.168.1.118)
```

---

### **3. Connaître les Ports des Services**

| Service | Port Localhost | Utilité |
|---------|----------------|---------|
| **Supabase Studio** | 3000 | Interface admin DB |
| **PostgreSQL** | 5432 | Base de données |
| **Traefik Dashboard** | 8081 | Routes reverse proxy |
| **Portainer** | 8080 | Gestion Docker |
| **Grafana** | 3000 | Dashboards monitoring (si installé) |

---

## 🚀 Tunnel Simple (Un Service)

### **Exemple 1 : Accéder à Supabase Studio**

#### **Commande de Base**

```bash
# Sur votre Mac/PC
ssh -L 3000:localhost:3000 pi@192.168.1.118
```

**Explication** :
- `-L 3000:localhost:3000` : "Forward mon port local 3000 vers le port 3000 du Pi"
- `pi@192.168.1.118` : "Se connecter au Pi"

#### **Utilisation**

1. **Lancer le tunnel** (terminal 1) :
   ```bash
   ssh -L 3000:localhost:3000 pi@pi5.local
   # Terminal reste ouvert, c'est normal !
   ```

2. **Ouvrir navigateur** (nouvel onglet/fenêtre) :
   ```
   http://localhost:3000
   ```

3. **Supabase Studio s'affiche !** 🎉

4. **Fermer le tunnel** :
   ```bash
   # Dans le terminal SSH, taper :
   exit
   # Ou fermer le terminal (Cmd+W)
   ```

---

### **Exemple 2 : Se Connecter à PostgreSQL**

```bash
# Terminal 1 : Créer le tunnel
ssh -L 5432:localhost:5432 pi@pi5.local

# Terminal 2 : Se connecter à PostgreSQL
psql -h localhost -p 5432 -U postgres -d postgres
# Mot de passe : (celui configuré sur le Pi)

# ✅ Vous êtes connecté !
postgres=# \dt
# Liste les tables
```

---

## 🔗 Tunnel Multiple (Plusieurs Services)

### **Plusieurs Ports en Une Commande**

```bash
# Tunneler Studio (3000), PostgreSQL (5432), et Traefik (8081)
ssh -L 3000:localhost:3000 \
    -L 5432:localhost:5432 \
    -L 8081:localhost:8081 \
    pi@pi5.local
```

**Maintenant accessible** :
- `http://localhost:3000` → Supabase Studio
- `psql -h localhost -p 5432` → PostgreSQL
- `http://localhost:8081` → Traefik Dashboard

---

### **Conflit de Ports ? Utiliser d'Autres Ports Locaux**

**Problème** : Vous avez déjà un service local sur le port 3000 (ex: React dev server).

**Solution** : Mapper vers un autre port local (ex: 3001)

```bash
# Forward port LOCAL 3001 → port DISTANT 3000
ssh -L 3001:localhost:3000 pi@pi5.local

# Ouvrir : http://localhost:3001 (pas 3000)
# → Redirige vers le port 3000 du Pi
```

---

## 🌙 Tunnel Permanent (Background)

### **Problème**

Le tunnel SSH basique **bloque le terminal**. Si vous fermez le terminal, le tunnel se ferme.

### **Solution 1 : Option `-f` (Background)**

```bash
# Lancer en arrière-plan
ssh -f -N -L 3000:localhost:3000 pi@pi5.local

# Maintenant le terminal est libre !
# Le tunnel tourne en background
```

**Options** :
- `-f` : Lance SSH en background
- `-N` : Ne pas exécuter de commande (juste le tunnel)
- `-L` : Forward de port

**Fermer le tunnel** :
```bash
# Trouver le PID du process SSH
ps aux | grep "ssh.*3000:localhost:3000"
# pi  12345  ... ssh -f -N -L 3000:localhost:3000 pi@pi5.local

# Tuer le process
kill 12345
```

---

### **Solution 2 : Alias Shell (Simplifié)**

Créer des **raccourcis** pour vos tunnels fréquents.

```bash
# Éditer ~/.zshrc (ou ~/.bashrc)
nano ~/.zshrc

# Ajouter ces alias :
alias tunnel-studio="ssh -f -N -L 3000:localhost:3000 pi@pi5.local && echo 'Studio accessible : http://localhost:3000'"
alias tunnel-postgres="ssh -f -N -L 5432:localhost:5432 pi@pi5.local && echo 'PostgreSQL accessible : localhost:5432'"
alias tunnel-all="ssh -f -N -L 3000:localhost:3000 -L 5432:localhost:5432 -L 8081:localhost:8081 pi@pi5.local && echo 'Tous services accessibles'"

# Sauvegarder (Ctrl+X, Y, Enter)

# Recharger config
source ~/.zshrc

# Maintenant vous pouvez taper simplement :
tunnel-studio
# ✅ Tunnel créé en background !
```

**Fermer tous les tunnels** :
```bash
# Alias pour tuer tous les tunnels SSH
alias tunnel-kill="killall ssh"

# Utiliser :
tunnel-kill
```

---

### **Solution 3 : Script Automatique**

```bash
#!/bin/bash
# ~/bin/pi-tunnel.sh

PI_HOST="pi5.local"
TUNNEL_PORTS=(
    "3000:localhost:3000"  # Studio
    "5432:localhost:5432"  # PostgreSQL
    "8081:localhost:8081"  # Traefik
)

echo "🚀 Démarrage tunnels SSH vers $PI_HOST..."

for port_mapping in "${TUNNEL_PORTS[@]}"; do
    local_port=$(echo "$port_mapping" | cut -d: -f1)

    # Vérifier si tunnel existe déjà
    if lsof -Pi :$local_port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $local_port déjà utilisé (tunnel actif ?)"
    else
        ssh -f -N -L "$port_mapping" "$PI_HOST"
        echo "✅ Tunnel actif : localhost:$local_port"
    fi
done

echo ""
echo "📍 Services accessibles :"
echo "   - Supabase Studio : http://localhost:3000"
echo "   - PostgreSQL      : psql -h localhost -p 5432"
echo "   - Traefik         : http://localhost:8081"
echo ""
echo "🛑 Fermer : killall ssh"
```

**Utilisation** :
```bash
# Rendre exécutable
chmod +x ~/bin/pi-tunnel.sh

# Lancer
~/bin/pi-tunnel.sh

# Fermer
killall ssh
```

---

## 🎯 Cas d'Usage Spécifiques

### **Cas 1 : Développement Local avec DB Distante**

**Scénario** : Vous développez une app React localement, mais vous voulez utiliser la base Supabase du Pi.

```bash
# 1. Lancer tunnel PostgreSQL
ssh -f -N -L 5432:localhost:5432 pi@pi5.local

# 2. Configurer votre app locale
# .env.local
DATABASE_URL=postgresql://postgres:password@localhost:5432/postgres
SUPABASE_URL=http://192.168.1.118:8001  # API Kong (public)
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# 3. Lancer votre app
npm run dev

# ✅ App locale connectée à la DB du Pi !
```

---

### **Cas 2 : Backup Base de Données**

```bash
# 1. Tunneler PostgreSQL
ssh -f -N -L 5432:localhost:5432 pi@pi5.local

# 2. Dump la database
pg_dump -h localhost -p 5432 -U postgres -d postgres > backup-$(date +%Y%m%d).sql

# 3. Fermer tunnel
killall ssh

# ✅ Backup créé : backup-20251014.sql
```

---

### **Cas 3 : Accès depuis un Autre Réseau (Travail, Café)**

**Problème** : Depuis votre bureau au travail, `192.168.1.118` n'existe pas (réseau différent).

**Solutions** :

#### **Option A : VPN (Tailscale)** ⭐ RECOMMANDÉ

```bash
# 1. Installer Tailscale sur Pi et Mac
# Pi : curl -fsSL https://tailscale.com/install.sh | sh
# Mac : brew install --cask tailscale

# 2. Se connecter au même compte Tailscale

# 3. Le Pi a maintenant une IP privée (ex: 100.64.0.1)
ssh pi@100.64.0.1

# 4. Tunnel SSH via VPN
ssh -L 3000:localhost:3000 pi@100.64.0.1

# ✅ Fonctionne depuis n'importe où !
```

---

#### **Option B : SSH Jump Host (via IP Publique)**

**Prérequis** : Port 22 ouvert sur votre box (port forwarding).

```bash
# Si votre box redirige le port 22 vers le Pi
ssh -L 3000:localhost:3000 pi@VOTRE_IP_PUBLIQUE

# ⚠️ Sécurité : Changer le port SSH (pas 22) et utiliser clés SSH
```

---

#### **Option C : Cloudflare Tunnel** (Sans Port Forwarding)

```bash
# Sur le Pi (installer cloudflared)
sudo apt install cloudflared

# Créer tunnel
cloudflared tunnel create pi5-tunnel

# Config
cloudflared tunnel route dns pi5-tunnel pi5.example.com

# Depuis n'importe où
ssh -L 3000:localhost:3000 pi@pi5.example.com
```

---

### **Cas 4 : Partager Accès avec un Collègue**

**Scénario** : Vous voulez que votre collègue accède temporairement à Studio.

**Solution** : VPN + Tunnel SSH

```bash
# 1. Ajouter votre collègue à votre Tailscale
# (Interface web Tailscale)

# 2. Lui donner l'IP Tailscale du Pi
# Ex: 100.64.0.1

# 3. Il peut maintenant tunneler
ssh -L 3000:localhost:3000 pi@100.64.0.1

# ⚠️ Assurez-vous qu'il a les droits SSH !
```

---

## 🔧 Troubleshooting

### **Problème 1 : "bind: Address already in use"**

```bash
# Erreur
ssh -L 3000:localhost:3000 pi@pi5.local
# bind: Address already in use
# channel_setup_fwd_listener_tcpip: cannot listen to port: 3000
```

**Cause** : Un service local ou un tunnel existant utilise déjà le port 3000.

**Solution A** : Utiliser un autre port local
```bash
ssh -L 3001:localhost:3000 pi@pi5.local
# Ouvrir : http://localhost:3001
```

**Solution B** : Tuer le process sur le port 3000
```bash
# macOS/Linux
lsof -ti:3000 | xargs kill -9

# Ou trouver et tuer manuellement
lsof -i :3000
# COMMAND   PID   USER
# node     1234   pi
kill 1234
```

---

### **Problème 2 : "Connection refused"**

```bash
ssh -L 3000:localhost:3000 pi@pi5.local
# ✅ SSH fonctionne

# Mais :
curl http://localhost:3000
# ❌ curl: (7) Failed to connect to localhost port 3000: Connection refused
```

**Cause** : Le service sur le Pi n'écoute pas sur le port 3000.

**Diagnostic** :
```bash
# Sur le Pi
ssh pi@pi5.local
sudo netstat -tlnp | grep 3000

# Si aucun résultat → service non démarré
docker ps | grep studio

# Si container arrêté → démarrer
cd /home/pi/stacks/supabase
sudo docker compose up -d studio
```

---

### **Problème 3 : "Connection timed out"**

```bash
ssh -L 3000:localhost:3000 pi@192.168.1.118
# ❌ ssh: connect to host 192.168.1.118 port 22: Operation timed out
```

**Causes possibles** :

1. **Pi éteint ou déconnecté**
   ```bash
   ping 192.168.1.118
   # Si pas de réponse → Pi offline
   ```

2. **IP a changé (DHCP)**
   ```bash
   # Utiliser mDNS au lieu de l'IP
   ssh -L 3000:localhost:3000 pi@pi5.local
   ```

3. **Firewall bloque SSH**
   ```bash
   # Sur le Pi
   sudo ufw status
   # Si SSH (22) pas dans la liste :
   sudo ufw allow 22/tcp
   ```

---

### **Problème 4 : Tunnel Se Ferme Tout Seul**

**Cause** : Connexion SSH timeout après inactivité.

**Solution** : KeepAlive SSH

```bash
# Éditer config SSH locale
nano ~/.ssh/config

# Ajouter :
Host pi5.local
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Maintenant le tunnel reste actif même sans activité
```

---

## 🆚 Alternatives (VPN)

### **Pourquoi un VPN au Lieu de Tunnels SSH ?**

| Critère | Tunnel SSH | VPN (Tailscale) |
|---------|------------|-----------------|
| **Setup** | Aucune config (1 commande) | Installation requise (Pi + Mac) |
| **Simplicité** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Permanent** | ❌ (relancer à chaque fois) | ✅ (toujours actif) |
| **Tous Réseaux** | ⚠️ (nécessite IP publique ou VPN) | ✅ (fonctionne partout) |
| **Sécurité** | ✅ (SSH chiffré) | ✅ (WireGuard chiffré) |
| **Performance** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

---

### **Installer Tailscale (VPN Simplifié)**

#### **Sur le Pi**

```bash
# Installer
curl -fsSL https://tailscale.com/install.sh | sh

# Démarrer
sudo tailscale up

# Copier l'URL affichée et s'authentifier dans navigateur
```

#### **Sur votre Mac**

```bash
# Installer
brew install --cask tailscale

# Lancer l'app Tailscale
# Se connecter avec le même compte

# Le Pi apparaît avec une IP (ex: 100.64.0.1)
```

#### **Utilisation**

```bash
# Maintenant vous pouvez SSH directement via l'IP Tailscale
ssh pi@100.64.0.1

# Et tunneler
ssh -L 3000:localhost:3000 pi@100.64.0.1

# ✅ Fonctionne depuis n'importe où (maison, travail, 4G)
```

---

## 📚 Ressources

### **Commandes Utiles**

```bash
# Lister tous les tunnels SSH actifs
ps aux | grep "ssh.*-L"

# Tuer tous les tunnels
killall ssh

# Tester si un port local est ouvert
lsof -i :3000

# Vérifier connexion SSH
ssh -v pi@pi5.local  # Mode verbose (debug)
```

---

### **Liens**

- **SSH Tunneling (EN)** : https://www.ssh.com/academy/ssh/tunneling
- **Tailscale** : https://tailscale.com/
- **Cloudflare Tunnel** : https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/

---

**Dernière mise à jour** : 14 Octobre 2025
**Version** : 1.0.0
**Auteur** : PI5-SETUP Project

---

**Liens Utiles** :
- [Network Architecture](NETWORK-ARCHITECTURE.md)
- [Security Checklist](SECURITY-CHECKLIST.md)
