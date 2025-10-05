# 📚 Guide Débutant - VPN avec Tailscale

> **Pour qui ?** Débutants en VPN, sécurité réseau et accès distant
> **Durée de lecture** : 25 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est Quoi un VPN ?

### En une phrase
**VPN = Un tunnel privé et sécurisé pour accéder à ton Raspberry Pi depuis n'importe où, comme si tu étais chez toi.**

### Analogie Simple

Imagine que ton Raspberry Pi est **ta maison** et tous tes services (Supabase, Grafana, etc.) sont des **pièces** de ta maison.

**Sans VPN** :
```
Toi au café → Rue publique → ❌ Impossible d'entrer dans ta maison
              (Internet)        (pas de clé, porte fermée)
```

**Avec VPN** :
```
Toi au café → Tunnel secret → ✅ Tu arrives directement dans ta maison
              (VPN chiffré)     (comme si tu n'étais jamais parti)
```

**En termes techniques** :
- **VPN** = Virtual Private Network (Réseau Privé Virtuel)
- **Tunnel chiffré** = Personne ne peut voir ce que tu fais
- **Accès distant** = Utiliser ton Pi comme si tu étais chez toi

---

## 🎯 Pourquoi Tailscale ?

### Le Problème avec les VPN Traditionnels

**VPN classique (OpenVPN, WireGuard natif)** :
```
❌ Configuration complexe (certificats, clés, fichiers config)
❌ Besoin d'ouvrir ports sur ta box Internet
❌ Installation différente sur chaque appareil
❌ Galère si tu es derrière CGNAT (certaines box 4G/5G)
❌ Pas de gestion centralisée
```

**Tailscale (VPN moderne)** :
```
✅ Installation en 2 minutes (vraiment !)
✅ Aucun port à ouvrir (magie du NAT traversal)
✅ Même app sur tous les appareils (Windows, Mac, iOS, Android)
✅ Fonctionne partout (même derrière CGNAT)
✅ Interface web pour tout gérer
✅ GRATUIT pour usage personnel (jusqu'à 100 appareils)
```

### Tailscale vs Ouvrir des Ports

**Méthode 1 : Ouvrir ports 80/443 (Traefik)** :
```
Avantages :
✅ Accessible depuis n'importe quel navigateur
✅ Pas besoin d'installer VPN

Inconvénients :
❌ Exposé sur Internet (risques de sécurité)
❌ Besoin d'ouvrir ports sur box (complexe pour débutants)
❌ Ne fonctionne pas derrière CGNAT
❌ Attaques possibles (bots, scanners)
```

**Méthode 2 : Tailscale VPN** :
```
Avantages :
✅ Aucun port à ouvrir (sécurité maximale)
✅ Fonctionne partout (CGNAT, 4G, hôtel)
✅ Authentification forte (Google, GitHub)
✅ Chiffrement WireGuard (ultra-sécurisé)

Inconvénients :
❌ Besoin d'installer app VPN sur chaque appareil
❌ Pas accessible publiquement (seulement vos appareils)
```

**Recommandation débutant** :
- **Tailscale seul** : Maximum sécurité, usage personnel
- **Tailscale + Traefik** : Mix sécurisé (certains services publics, d'autres VPN)

---

## 🧩 Comment Ça Marche ?

### Architecture Tailscale Simplifiée

```
         Internet
             │
    ┌────────┴────────┐
    │                 │
Laptop            Smartphone
(Chez toi)      (Au travail)
    │                 │
    └─────VPN─────────┘
          │
    Raspberry Pi
    (Chez toi)
```

**Ce qui se passe** :
1. **Tous tes appareils** installent Tailscale
2. **Tailscale crée un réseau privé** entre eux (IP 100.x.x.x)
3. **Connexion directe** si possible (peer-to-peer)
4. **Sinon** : Via serveurs Tailscale (DERP relay)
5. **Tout est chiffré** avec WireGuard

### Les 3 Composants Magiques

#### 1. **Coordination Server** (login.tailscale.com)
**Rôle** : Annuaire central des appareils

```
Laptop dit : "Je veux parler au Raspberry Pi"
Coordination Server répond : "Raspberry Pi est à 100.64.1.5"
                            "Voici ses clés de chiffrement"
                            "Essaie connexion directe sur ces IPs"
Laptop : "Merci !" → Se connecte directement au Pi
```

**Analogie** : C'est l'annuaire téléphonique de ton réseau VPN.

#### 2. **WireGuard** (Protocole de Chiffrement)
**Rôle** : Chiffrer toutes les communications

```
Sans chiffrement :
Laptop → "Mot de passe: admin123" → 🕵️ Hacker voit tout → Raspberry Pi

Avec WireGuard :
Laptop → "Xk#9$mP@..." → 🕵️ Hacker voit du charabia → Raspberry Pi
         (chiffré)                                        (déchiffre)
```

**Fun fact** : WireGuard fait 4000 lignes de code, OpenVPN 100 000 lignes !
(Moins de code = moins de bugs = plus sécurisé)

#### 3. **MagicDNS** (Noms Automatiques)
**Rôle** : Transformer IPs en noms faciles

```
Sans MagicDNS :
http://100.64.1.5:8000/studio   → Impossible à retenir

Avec MagicDNS :
http://raspberrypi:8000/studio  → Facile !
http://mon-pi:8000/studio       → Encore mieux !
```

**Analogie** : Au lieu de retenir "192.168.1.5", tu retiens "l'ordi de papa".

---

## 🎯 Cas d'Usage Réels

### 1. Accéder à Grafana depuis le Travail

**Scénario** : Tu es au bureau, tu veux voir les stats de ton Pi.

**Sans Tailscale** :
```
Toi → Ouvrir http://192.168.1.100:3002
    → ❌ Erreur "Site inaccessible"
    → Pourquoi ? Tu n'es pas sur le réseau WiFi de ta maison !
```

**Avec Tailscale** :
```
1. Activer Tailscale sur laptop bureau (1 clic)
2. Ouvrir http://raspberrypi:3002
3. ✅ Grafana s'affiche comme si tu étais chez toi !
```

**Magie** : Le tunnel VPN te "téléporte" sur ton réseau maison.

---

### 2. Montrer Homepage à un Ami

**Scénario** : Tu veux montrer ton setup Pi à un ami qui vit loin.

**Solution 1 - Sans Tailscale (risqué)** :
```
1. Ouvrir ports 80/443 sur ta box
2. Configurer DuckDNS/Cloudflare
3. Donner URL publique à l'ami
4. ❌ N'importe qui peut trouver ton URL (Google, scanners de bots)
5. ❌ Risques de sécurité
```

**Solution 2 - Avec Tailscale (sécurisé)** :
```
1. Inviter ami dans ton Tailnet :
   tailscale share raspberrypi --email ami@example.com

2. Ami reçoit email → Installe Tailscale → Se connecte

3. Ami peut voir http://raspberrypi uniquement via VPN

4. ✅ Personne d'autre ne peut accéder (même s'ils connaissent l'URL)
```

**Analogie** : C'est comme donner la clé de ta maison à ton ami, pas laisser la porte ouverte à tout le monde.

---

### 3. SSH au Pi depuis Café WiFi Public

**Scénario** : Tu codes dans un café, tu veux SSH sur ton Pi.

**Sans VPN (dangereux !)** :
```
Café WiFi → SSH pi@ton-ip-publique
          → 🕵️ Hacker sur même WiFi intercepte :
              - Ton IP publique
              - Tentatives de connexion
              - Potentiellement mot de passe si mal configuré
```

**Avec Tailscale (sécurisé)** :
```
1. Activer Tailscale sur laptop
2. SSH pi@raspberrypi
3. ✅ Connexion chiffrée WireGuard
4. ✅ Hacker voit juste du bruit cryptographique
5. ✅ Aucune info exploitable
```

**Bonus** : Avec `tailscale up --ssh`, même pas besoin de mot de passe !

---

### 4. Partager Jellyfin avec Famille

**Scénario** : Tu as installé Jellyfin (serveur média) sur ton Pi, ta famille veut regarder films.

**Problème avec méthode classique** :
```
❌ Ouvrir port 8096 sur Internet
❌ Donner URL publique à famille
❌ Consommation bande passante upload (si plusieurs personnes)
❌ Risques DMCA si partage films copyrighted
```

**Solution Tailscale** :
```
1. Installer Tailscale sur TV/tablettes famille
2. Tous se connectent au même Tailnet
3. Accès Jellyfin via http://raspberrypi:8096
4. ✅ Streaming local (bande passante infinie)
5. ✅ Aucun port exposé publiquement
6. ✅ Contrôle d'accès via ACLs Tailscale
```

**Analogie** : C'est comme avoir un Netflix familial privé, accessible que par ta famille.

---

## 🚀 Installation Pas-à-Pas

### Étape 1 : Créer Compte Tailscale (2 min)

**Visuel** :
```
1. Aller sur tailscale.com
2. Cliquer bouton "Get Started" (bleu, en haut à droite)
3. Choisir méthode connexion :
   [  Google  ] [  GitHub  ] [  Microsoft  ] [ Email ]
4. Cliquer sur ton choix (ex: Google)
5. Fenêtre Google s'ouvre → Choisir compte
6. ✅ Redirection vers Tailscale Admin Panel
```

**Résultat** : Tu as maintenant un compte Tailscale (gratuit, 100 appareils max).

---

### Étape 2 : Installer sur Raspberry Pi (3 min)

**Commande magique** :
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-vpn-stack/scripts/01-tailscale-setup.sh | sudo bash
```

**Ce qui se passe** :
```
1. Le script télécharge Tailscale
2. Installe le service
3. Génère URL d'authentification
4. Affiche :

   🔗 Ouvrir cette URL pour authentifier :
   https://login.tailscale.com/a/1234567890abcdef

5. Copie cette URL
```

---

### Étape 3 : Authentifier le Pi (1 min)

**Actions** :
```
1. Copier l'URL affichée
2. Ouvrir dans navigateur (n'importe quel appareil)
3. Page Tailscale s'ouvre :

   "Autoriser appareil 'raspberrypi' à rejoindre votre réseau ?"

   [  Annuler  ]  [  Autoriser  ]

4. Cliquer "Autoriser"
5. ✅ Page confirme : "Appareil connecté !"
```

**Retour au Pi** :
```bash
# Vérifier connexion
tailscale status

# Affiche :
# 100.64.1.5   raspberrypi   user@example.com   linux   -
```

**100.64.1.5** = Ton adresse IP Tailscale (unique dans ton réseau VPN)

---

### Étape 4 : Installer sur Laptop/Smartphone (5 min)

**Windows** :
```
1. Aller sur tailscale.com/download/windows
2. Télécharger fichier .exe
3. Double-cliquer → Installer
4. Tailscale se lance → Cliquer "Log in"
5. Navigateur s'ouvre → Se connecter avec même compte
6. ✅ Icône Tailscale dans barre tâches (état connecté)
```

**macOS** :
```
1. Aller sur tailscale.com/download/macos
2. Télécharger .pkg
3. Installer
4. Lancer Tailscale → Menu bar icon apparaît
5. Cliquer icône → "Log in"
6. ✅ Connecté
```

**iPhone/iPad** :
```
1. App Store → Rechercher "Tailscale"
2. Installer (icône bleu/blanc)
3. Ouvrir → "Log in with Google" (ou GitHub, etc.)
4. Autoriser
5. Toggle VPN en haut → Activer (devient vert)
6. ✅ Connecté
```

**Android** :
```
1. Google Play → "Tailscale"
2. Installer
3. Ouvrir → Se connecter
4. Activer VPN
5. ✅ Connecté
```

---

### Étape 5 : Tester l'Accès (2 min)

**Depuis laptop/smartphone avec Tailscale actif** :

**Test 1 - Ping** :
```bash
# Terminal (macOS/Linux) ou PowerShell (Windows)
ping raspberrypi

# Résultat :
# PING raspberrypi (100.64.1.5): 56 data bytes
# 64 bytes from 100.64.1.5: time=12.3 ms
# ✅ Ça marche !
```

**Test 2 - Homepage** :
```
Navigateur → http://raspberrypi

✅ Homepage s'affiche (si installé)
```

**Test 3 - Supabase Studio** :
```
Navigateur → http://raspberrypi:8000/studio

✅ Supabase Studio s'affiche
```

**Test 4 - SSH** :
```bash
ssh pi@raspberrypi

# Si activé --ssh lors install :
# ✅ Connexion directe (pas besoin mot de passe)

# Sinon :
# Demande mot de passe → Entrer
# ✅ Connecté au Pi
```

---

## 🎨 Accéder aux Services

### Via MagicDNS (Facile)

**MagicDNS transforme IPs en noms** :

| Service | URL Difficile | URL Facile (MagicDNS) |
|---------|---------------|------------------------|
| Homepage | http://100.64.1.5 | http://raspberrypi |
| Supabase Studio | http://100.64.1.5:8000/studio | http://raspberrypi:8000/studio |
| Grafana | http://100.64.1.5:3002 | http://raspberrypi:3002 |
| Portainer | http://100.64.1.5:9000 | http://raspberrypi:9000 |
| SSH | ssh pi@100.64.1.5 | ssh pi@raspberrypi |

**Pourquoi ça marche ?**
```
1. Tailscale active MagicDNS par défaut
2. MagicDNS utilise hostname de la machine ("raspberrypi")
3. Quand tu tapes "raspberrypi", résolu en 100.64.1.5 automatiquement
```

---

### Personnaliser le Nom

**Changer "raspberrypi" en "mon-pi"** :

```bash
# Sur le Pi
sudo tailscale set --hostname=mon-pi
```

**Résultat** :
```
http://mon-pi              → Homepage
http://mon-pi:8000/studio  → Supabase Studio
ssh pi@mon-pi              → SSH
```

**Ou via Interface Web** :
1. login.tailscale.com
2. Machines → raspberrypi → ... → Rename
3. Entrer "mon-pi"
4. Sauvegarder

---

### Exemples d'Utilisation

#### Développer App React avec Backend Supabase

**Fichier `.env.local`** :
```bash
REACT_APP_SUPABASE_URL=http://raspberrypi:8000
REACT_APP_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Code React** :
```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.REACT_APP_SUPABASE_URL,
  process.env.REACT_APP_SUPABASE_ANON_KEY
)

// Fonctionne via Tailscale, comme si Supabase était en local !
const { data, error } = await supabase.from('users').select('*')
```

**Avantage** : Dev en local, mais backend sur Pi (base de données persistante).

---

#### Monitorer avec Grafana Mobile

**Scénario** : Tu es en déplacement, tu veux check les métriques.

**Étapes** :
```
1. iPhone/Android → Ouvrir Tailscale app
2. Vérifier VPN actif (toggle vert)
3. Ouvrir Safari/Chrome → http://raspberrypi:3002
4. Grafana s'ouvre
5. Voir dashboards (CPU, RAM, Docker, etc.)
6. ✅ Tout est accessible comme si chez toi
```

**Bonus** : Ajouter bookmark "Grafana Pi" sur écran d'accueil mobile.

---

#### Accéder NAS Synology via VPN

**Problème** : Ton NAS est sur 192.168.1.50, accessible uniquement chez toi.

**Solution : Subnet Router** :

```bash
# 1. Sur le Pi, activer Subnet Router
sudo tailscale up --advertise-routes=192.168.1.0/24

# 2. Approuver dans admin panel
# login.tailscale.com → Machines → raspberrypi → Edit routes → Approve

# 3. Depuis n'importe où (Tailscale actif)
Navigateur → http://192.168.1.50:5000
✅ DSM (Synology) accessible !
```

**Magie** : Le Pi devient une "passerelle VPN" vers ton réseau local entier.

---

## ❓ Questions Fréquentes

### Est-ce Sécurisé ?

**OUI, très sécurisé** :

✅ **Chiffrement WireGuard** :
- Protocole moderne (2016), audité par experts
- Utilisé par Google, Cloudflare, etc.
- Plus sécurisé qu'OpenVPN (ancien, complexe)

✅ **Authentification forte** :
- Google/GitHub/Microsoft SSO
- 2FA disponible
- Clés révocables à tout moment

✅ **Zero Trust** :
- Coordination server ne voit pas ton trafic
- Connexion peer-to-peer quand possible
- DERP relay chiffré (si peer-to-peer impossible)

**Comparaison** :
```
Port ouvert public (Traefik seul) : 🟠 Risqué (attaques possibles)
VPN Tailscale                    : 🟢 Très sécurisé
VPN + 2FA + ACLs                 : 🟢🟢 Sécurité maximale
```

---

### C'est Gratuit ?

**OUI, pour usage personnel** :

**Plan Free** (0€/mois) :
- ✅ Jusqu'à 100 appareils
- ✅ 3 utilisateurs
- ✅ Toutes les fonctionnalités core
- ✅ MagicDNS
- ✅ Subnet router
- ✅ Exit node
- ✅ ACLs basiques

**Plan Team** (5$/user/mois) - Pour entreprises :
- 👥 Utilisateurs illimités
- 🔐 SSO avancé
- 📊 Audit logs
- 🏢 Support prioritaire

**Recommandation débutant** : Plan Free largement suffisant.

---

### Ça Consomme Beaucoup de Batterie Mobile ?

**NON, très peu** :

**Tests réels** :
- iOS : ~2-3% batterie par jour (VPN actif 24/7)
- Android : ~3-5% batterie par jour

**Pourquoi si peu ?**
- WireGuard ultra-optimisé (vs OpenVPN gourmand)
- Connexion directe (pas de relay permanent)
- Veille intelligente (désactive si pas utilisé)

**Astuce** : Activer VPN uniquement quand besoin :
```
iOS/Android :
1. Ouvrir app Tailscale
2. Toggle OFF quand pas besoin
3. Toggle ON quand besoin accès Pi
```

---

### Ça Ralentit Internet ?

**Très peu, voire imperceptible** :

**Sans Exit Node** (accès Pi uniquement) :
- ✅ Aucun impact sur navigation web
- ✅ Netflix, YouTube, etc. passent direct (pas via VPN)
- ✅ Seul trafic vers Pi chiffré

**Avec Exit Node** (tout trafic via Pi) :
- 🟠 Limité par upload de ton domicile
- Ex: Upload 50 Mbps → Internet max 50 Mbps
- Mais : Sécurité WiFi public (worth it)

**Latence** :
- Connexion directe : +1-5ms (imperceptible)
- Via DERP relay : +10-50ms (selon distance serveur)

---

### Ça Fonctionne Derrière CGNAT ?

**OUI, 100% compatible** :

**CGNAT** = Carrier-Grade NAT (certaines box 4G/5G, fibre)
- Symptôme : IP publique commence par 100.x.x.x
- Problème : Impossible d'ouvrir ports (Traefik ne fonctionne pas)

**Tailscale résout ça** :
- Pas besoin d'ouvrir ports
- NAT traversal automatique
- Utilise DERP relay si peer-to-peer impossible
- ✅ Fonctionne dans 99% des cas

**Test CGNAT** :
```bash
# Vérifier IP publique
curl ifconfig.me

# Si commence par 100.x.x.x → CGNAT
# → Tailscale est LA solution !
```

---

## 🎯 Scénarios Réels

### Scénario 1 : Étudiant en Déplacement

**Contexte** :
- Pi chez parents (192.168.1.100)
- Toi en appartement étudiant (autre ville)
- Tu veux accéder à :
  - Fichiers sur Pi (Nextcloud/FileBrowser)
  - Jupyter Notebooks (dev Python)
  - Base de données Supabase

**Solution** :
```
1. Installer Tailscale sur Pi (chez parents)
2. Installer Tailscale sur laptop étudiant
3. Accès permanent via VPN :
   - http://raspberrypi:3000 → Nextcloud
   - http://raspberrypi:8888 → Jupyter
   - http://raspberrypi:8000 → Supabase

4. Bonus : Activer --ssh pour VSCode Remote
```

**Avantages** :
- ✅ Pas besoin configurer box parents
- ✅ Aucun port ouvert (sécurisé)
- ✅ Accès comme si tu étais chez parents

---

### Scénario 2 : Freelance en Nomade Digital

**Contexte** :
- Pi chez toi (Europe)
- Toi en voyage (Asie)
- WiFi hôtels pas fiables
- Tu veux :
  - Accéder clients Supabase
  - Monitorer infra (Grafana)
  - Sécuriser navigation web

**Solution** :
```
1. Tailscale sur Pi (exit node activé)
2. Tailscale sur laptop voyage
3. Activer Exit Node :
   tailscale up --exit-node=raspberrypi

4. Résultat :
   - Tout trafic web passe par Pi (IP européenne)
   - WiFi hôtel chiffré (sécurisé)
   - Accès services Pi normal
```

**Avantages** :
- ✅ Navigation web sécurisée (chiffrement)
- ✅ IP européenne (contourne géoblocage)
- ✅ Accès infra personnel

---

### Scénario 3 : Famille Tech-Savvy

**Contexte** :
- Toi : Admin principal, Pi configuré
- Conjoint : Veut accéder photos (Immich/PhotoPrism)
- Enfants : Jellyfin pour films/séries
- Parents : Consulter docs partagés

**Solution avec ACLs** :

```json
// login.tailscale.com → Access Controls
{
  "acls": [
    // Toi : Accès total
    {
      "action": "accept",
      "src": ["admin@example.com"],
      "dst": ["*:*"]
    },

    // Conjoint : Photos + Homepage
    {
      "action": "accept",
      "src": ["conjoint@example.com"],
      "dst": ["raspberrypi:80", "raspberrypi:2283"]  // Homepage + Immich
    },

    // Enfants : Jellyfin uniquement
    {
      "action": "accept",
      "src": ["enfant@example.com"],
      "dst": ["raspberrypi:8096"]  // Jellyfin
    },

    // Parents : Nextcloud docs
    {
      "action": "accept",
      "src": ["parent@example.com"],
      "dst": ["raspberrypi:3000"]  // Nextcloud
    }
  ]
}
```

**Avantages** :
- ✅ Chacun voit que ce qui le concerne
- ✅ Pas de risque manipulation accidentelle (Portainer, etc.)
- ✅ Contrôle granulaire par service

---

### Scénario 4 : Dev Team Distribuée

**Contexte** :
- Petit startup, 3 devs
- Pi héberge :
  - Supabase (dev database)
  - Gitea (Git self-hosted)
  - Grafana (monitoring)

**Solution Team** :

```bash
# 1. Créer Tailnet team (login.tailscale.com)
# 2. Inviter devs :
tailscale share raspberrypi --email dev1@startup.com
tailscale share raspberrypi --email dev2@startup.com

# 3. Chaque dev installe Tailscale
# 4. Tous accèdent via MagicDNS :
#    - http://raspberrypi:8000 → Supabase
#    - http://raspberrypi:3001 → Gitea
#    - http://raspberrypi:3002 → Grafana
```

**Configuration App Dev** :
```javascript
// .env
VITE_SUPABASE_URL=http://raspberrypi:8000
VITE_GIT_REMOTE=http://raspberrypi:3001/startup/app.git
```

**Avantages** :
- ✅ Infra partagée sans cloud coûteux
- ✅ Sécurisé (VPN uniquement team)
- ✅ Latence faible (connexion directe)

---

## 🔧 Commandes Utiles

### Vérifier Statut VPN

```bash
# Statut complet
tailscale status

# Exemple sortie :
# 100.64.1.2   mon-laptop      admin@example.com   windows -
# 100.64.1.3   mon-phone       admin@example.com   ios     -
# 100.64.1.5   raspberrypi     admin@example.com   linux   -
```

### Voir IP Tailscale

```bash
# IPv4
tailscale ip -4
# → 100.64.1.5

# IPv6 (si activé)
tailscale ip -6
# → fd7a:115c:a1e0::5
```

### Tester Connectivité

```bash
# Test NAT traversal et DERP
tailscale netcheck

# Exemple sortie :
# DERP latency:
#   - sfo (San Francisco): 12ms
#   - nyc (New York): 45ms
#   - fra (Frankfurt): 23ms ← Meilleur
```

### Voir Logs

```bash
# Logs temps réel
journalctl -u tailscaled -f

# 100 dernières lignes
journalctl -u tailscaled -n 100
```

### Redémarrer Tailscale

```bash
# Déconnecter
sudo tailscale down

# Reconnecter
sudo tailscale up

# Redémarrer service
sudo systemctl restart tailscaled
```

### Changer Options à la Volée

```bash
# Activer SSH Tailscale
sudo tailscale up --ssh

# Activer Exit Node
sudo tailscale up --exit-node=raspberrypi

# Advertiser Subnet
sudo tailscale up --advertise-routes=192.168.1.0/24

# Combiner options
sudo tailscale up --ssh --advertise-routes=192.168.1.0/24 --advertise-exit-node
```

---

## 🆘 Problèmes Courants

### "ping raspberrypi" ne fonctionne pas

**Cause** : MagicDNS pas activé

**Vérifications** :
```bash
# 1. Vérifier MagicDNS activé
# → login.tailscale.com → DNS → MagicDNS (toggle vert)

# 2. Vérifier DNS client
cat /etc/resolv.conf | grep 100.100.100.100
# Si absent → Redémarrer Tailscale :
sudo tailscale down && sudo tailscale up
```

**Solution rapide** : Utiliser IP directement
```bash
# Récupérer IP Pi
tailscale status | grep raspberrypi
# → 100.64.1.5

# Ping par IP
ping 100.64.1.5
# ✅ Doit fonctionner
```

---

### Connexion Très Lente

**Cause 1 : Via DERP relay au lieu de direct**

**Vérifier** :
```bash
tailscale status
# Si affiche "relay" → Via DERP (plus lent)
# Si affiche "direct" → Peer-to-peer (rapide)
```

**Améliorer** :
```bash
# Ouvrir UDP 41641 sur firewall (si possible)
sudo ufw allow 41641/udp

# Activer UPnP sur box Internet
# → Interface web box → UPnP → Activer
```

**Cause 2 : Exit Node avec faible upload**

**Diagnostic** :
```bash
# Sur Pi (si exit node)
speedtest-cli

# Upload <10 Mbps → Lent pour exit node
# → Désactiver exit node si pas nécessaire
```

---

### Services Pi Inaccessibles via VPN

**Cause** : Firewall bloque Tailscale

**Solution** :
```bash
# Autoriser interface Tailscale
sudo ufw allow in on tailscale0

# Vérifier règle ajoutée
sudo ufw status | grep tailscale0
# → tailscale0           ALLOW IN    Anywhere
```

**Autre cause** : Service pas démarré

```bash
# Vérifier Docker containers
docker ps

# Si service absent :
cd ~/stacks/supabase  # ou autre stack
docker compose up -d
```

---

### "Device is logged out"

**Cause** : Clé expirée (après 180 jours par défaut)

**Solution** :
```bash
# Re-authentifier
sudo tailscale up

# Ouvrir URL affichée → Autoriser
```

**Éviter à l'avenir** :
```
1. login.tailscale.com
2. Machines → raspberrypi → ...
3. "Disable key expiry"
4. ✅ Plus jamais de déconnexion
```

---

## 📚 Pour Aller Plus Loin

### Headscale (Alternative Self-Hosted)

**Headscale** = Serveur coordination Tailscale open-source

**Avantages** :
- ✅ 100% self-hosted (pas de dépendance Tailscale Inc.)
- ✅ Contrôle total données
- ✅ Gratuit, illimité

**Inconvénients** :
- ❌ Installation complexe
- ❌ Pas de DERP relay (NAT traversal difficile)
- ❌ Pas d'apps mobiles officielles

**Quand utiliser** :
- Paranoïa maximale (zéro confiance externes)
- Besoins entreprise avec infra existante

**Installation** : [Guide Headscale](docs/HEADSCALE.md) (pour avancés)

---

### Exit Node + Pi-hole (Blocage Pub)

**Combo puissant** : VPN + Blocage pubs/trackers

**Setup** :
```bash
# 1. Installer Pi-hole sur Pi
curl -sSL https://install.pi-hole.net | bash

# 2. Configurer Pi-hole sur port 53

# 3. Activer Exit Node Tailscale
sudo tailscale up --advertise-exit-node

# 4. Sur clients, utiliser exit node
tailscale up --exit-node=raspberrypi
```

**Résultat** :
- ✅ Tout trafic via Pi
- ✅ Pi-hole bloque pubs/trackers
- ✅ WiFi public sécurisé + sans pub !

---

### Intégration Home Assistant

**Use case** : Contrôler domotique à distance

**Setup** :
```bash
# 1. Installer Home Assistant sur Pi (Docker)
# 2. Exposer port 8123
# 3. Accès via Tailscale :
http://raspberrypi:8123

# 4. Depuis smartphone (Tailscale actif) :
# → App Home Assistant → Ajouter serveur
# → URL : http://raspberrypi:8123
# ✅ Contrôle domotique n'importe où
```

---

### Monitoring Tailscale avec Grafana

**Dashboard métriques VPN** :

```bash
# 1. Exporter métriques Tailscale
tailscale status --json > /tmp/tailscale-status.json

# 2. Script cron pour collecte
# /etc/cron.d/tailscale-metrics :
*/5 * * * * pi tailscale status --json > /var/lib/prometheus/tailscale.json

# 3. Prometheus scrape
# prometheus.yml :
scrape_configs:
  - job_name: 'tailscale'
    static_configs:
      - targets: ['localhost:9090']
    file_sd_configs:
      - files: ['/var/lib/prometheus/tailscale.json']
```

**Dashboard Grafana** :
- Nombre de peers connectés
- Latence par peer
- Trafic VPN (MB/s)
- Type connexion (direct vs relay)

---

## ✅ Checklist Maîtrise Tailscale

### Niveau Débutant

- [ ] Installer Tailscale sur Pi
- [ ] Installer Tailscale sur 1 autre appareil (laptop/mobile)
- [ ] Authentifier les deux appareils
- [ ] Ping d'un appareil à l'autre
- [ ] Accéder à un service Pi (ex: Homepage)
- [ ] Comprendre différence MagicDNS vs IP
- [ ] Désactiver/Activer VPN sur mobile

### Niveau Intermédiaire

- [ ] Activer MagicDNS et personnaliser hostname
- [ ] Installer Tailscale sur 3+ appareils (famille/amis)
- [ ] Configurer Subnet Router (accès réseau local)
- [ ] Tester Exit Node (proxy Internet)
- [ ] Utiliser `tailscale ssh` (SSH sans mot de passe)
- [ ] Configurer ACLs basiques (limiter accès)
- [ ] Intégrer avec services (Supabase, Grafana, etc.)

### Niveau Avancé

- [ ] Déployer Headscale (self-hosted)
- [ ] Configurer ACLs complexes (multiples règles)
- [ ] Exit Node + Pi-hole (blocage pub)
- [ ] Monitoring Tailscale avec Grafana
- [ ] Tags et groups pour organisation
- [ ] Tailscale sur serveurs multiples (mesh network)
- [ ] Automatisation (Ansible/Terraform)

---

**Besoin d'aide ?** Consulte la [documentation complète](README.md) ou rejoins la [communauté Tailscale](https://tailscale.com/contact/support) !

🎉 **Bon VPN sécurisé !**
