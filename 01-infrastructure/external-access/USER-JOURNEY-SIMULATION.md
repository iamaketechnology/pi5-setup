# 🎬 Simulation du Parcours Utilisateur

> **Ce document simule l'expérience complète d'un utilisateur qui configure l'accès externe à son Supabase**

---

## 👤 Profil Utilisateur : Marie

**Contexte** :
- Vient d'installer Supabase sur son Raspberry Pi 5
- Veut y accéder depuis son téléphone et son PC
- Niveau technique : Débutant-Intermédiaire
- Configuration : Freebox Revolution, IP locale `192.168.1.105`

---

## 📍 Étape 0 : Situation de départ

Marie a terminé l'installation de Supabase. Elle peut y accéder localement :

```bash
# Sur son réseau local
http://192.168.1.105:3000  # ✅ Fonctionne
```

**Problème** : Elle veut y accéder depuis l'extérieur (travail, café, téléphone en 4G)

---

## 🤔 Étape 1 : Choix de la méthode

Marie consulte le README et répond au quiz :

### Questions du quiz :

**Q1 : Qui doit accéder à votre instance ?**
- ❌ N'importe qui sur Internet
- ✅ **Seulement moi et mon équipe** ← Marie choisit ceci

**Q2 : Voulez-vous installer une app sur vos appareils ?**
- ✅ **Oui, pas de problème** ← Marie choisit ceci
- ❌ Non, je veux un accès web direct

**Q3 : Configuration routeur possible ?**
- ✅ **Oui, j'ai accès à ma box**
- ❌ Non (4G, réseau d'entreprise, etc.)

### 🎯 Résultat du quiz : **HYBRIDE** (Port Forwarding + Tailscale)

**Pourquoi ?** Marie veut :
- ✅ Performance max à la maison (port forwarding)
- ✅ Sécurité en déplacement (Tailscale VPN)
- ✅ Partager avec 1-2 collègues (HTTPS public)

---

## 🚀 Étape 2 : Installation Hybride

### 2.1 - Téléchargement et exécution

Marie se connecte en SSH à son Pi :

```bash
ssh pi@192.168.1.105
```

Elle exécute la commande d'installation hybride :

```bash
curl -fsSL https://raw.githubusercontent.com/VOTRE-REPO/pi5-setup/main/01-infrastructure/external-access/hybrid-setup/scripts/01-setup-hybrid-access.sh | bash
```

### 2.2 - Écran d'accueil du script

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     🌐 Configuration Hybride - Accès Externe Supabase         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

La configuration hybride combine 2 méthodes d'accès :

┌─────────────────────────────────────────────────────────────────┐
│ 🏠 Méthode 1 : Port Forwarding + Traefik                       │
├─────────────────────────────────────────────────────────────────┤
│ • Accès LOCAL ultra-rapide (0ms latence)                        │
│ • Accès PUBLIC via HTTPS (votre-domaine.duckdns.org)           │
│ • Performance maximale                                           │
│ • Nécessite ouverture ports 80/443 sur routeur                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 🔐 Méthode 2 : Tailscale VPN                                   │
├─────────────────────────────────────────────────────────────────┤
│ • Accès SÉCURISÉ depuis vos appareils personnels                │
│ • Chiffrement bout-en-bout (WireGuard)                          │
│ • Zéro configuration routeur                                    │
│ • Fonctionne partout dans le monde                              │
└─────────────────────────────────────────────────────────────────┘

⏱️  Durée estimée : 30-35 minutes
```

### 2.3 - Menu interactif

```
Choisissez votre installation :

  1) Installation complète (RECOMMANDÉ)
     → Port Forwarding + Tailscale
     → 3 méthodes d'accès

  2) Port Forwarding seulement
  3) Tailscale seulement
  4) Annuler

Votre choix [1-4]: _
```

**Marie tape** : `1` ✅

---

## 🔧 Étape 3 : Installation Port Forwarding

### 3.1 - Détection réseau automatique

```
ℹ️  Détection de l'IP locale du Raspberry Pi...
✅ IP locale détectée: 192.168.1.105

ℹ️  Détection de votre IP publique...
✅ IP publique détectée: 82.65.55.248

ℹ️  Détection de l'IP du routeur...
✅ IP routeur détectée: 192.168.1.254

ℹ️  Tentative de détection de votre FAI...

═══════════════════════════════════════════════════════════════
📡 Informations réseau détectées
═══════════════════════════════════════════════════════════════
IP locale (Pi)    : 192.168.1.105
IP publique       : 82.65.55.248
IP routeur        : 192.168.1.254
Opérateur détecté : Free SAS
═══════════════════════════════════════════════════════════════
```

### 3.2 - Configuration DuckDNS

```
Votre domaine DuckDNS complet (ex: monpi.duckdns.org): _
```

**Marie tape** : `mariepro.duckdns.org` ✅

### 3.3 - Guide Freebox spécifique

Le script détecte que Marie est chez Free et affiche :

```
╔════════════════════════════════════════════════════════════════╗
║  📝 Guide de configuration du routeur                          ║
╚════════════════════════════════════════════════════════════════╝

🔷 Freebox - Configuration redirection de ports

1. Accéder à l'interface web:
   URL: http://mafreebox.freebox.fr
   Ou: http://192.168.1.254
   Login: (sans mot de passe par défaut)

2. Navigation:
   ▸ Onglet "Paramètres de la Freebox"
   ▸ Section "Gestion des ports"

3. Configuration Port 80 (HTTP):
   • IP destination: 192.168.1.105
   • IP source: Toutes
   • Port de début: 80
   • Port de fin: 80
   • Port de destination: 80
   • Protocole: TCP
   • Commentaire: Traefik-HTTP
   • Cliquez "Ajouter"

4. Configuration Port 443 (HTTPS):
   • Répétez avec Port 443

5. Cliquez "Sauvegarder"

📖 Documentation officielle:
   https://www.free.fr/assistance/

Appuyez sur Entrée après avoir configuré votre routeur...
```

### 3.4 - Marie configure sa Freebox

Marie ouvre un navigateur et va sur http://mafreebox.freebox.fr

**Actions dans l'interface Freebox** :
1. ✅ Paramètres de la Freebox
2. ✅ Mode avancé
3. ✅ Gestion des ports
4. ✅ Crée règle port 80 → 192.168.1.105
5. ✅ Crée règle port 443 → 192.168.1.105
6. ✅ Sauvegarde

Elle retourne au terminal et appuie sur **Entrée** ⏎

### 3.5 - Tests de connectivité

```
═══════════════════════════════════════════════════════════════
🔍 Tests de connectivité
═══════════════════════════════════════════════════════════════

ℹ️  Test résolution DNS mariepro.duckdns.org...
✅ DNS résout correctement vers 82.65.55.248 ✅

ℹ️  Test du port 80 (HTTP) depuis l'extérieur...
✅ Port 80 accessible depuis Internet ✅

ℹ️  Test du port 443 (HTTPS) depuis l'extérieur...
✅ Port 443 accessible depuis Internet ✅

✅ ✅ Configuration réussie ! Tous les ports sont accessibles
```

---

## 🔐 Étape 4 : Installation Tailscale

### 4.1 - Installation du client

```
═══════════════════════════════════════════════════════════════
🔐 Installation Tailscale VPN
═══════════════════════════════════════════════════════════════

ℹ️  Téléchargement de Tailscale...
✅ Tailscale installé avec succès

ℹ️  Démarrage de l'authentification...

Pour terminer l'authentification, ouvrez cette URL dans votre navigateur :

🌐 https://login.tailscale.com/a/1a2b3c4d5e

Appuyez sur Entrée après avoir authentifié...
```

### 4.2 - Marie ouvre l'URL

Marie copie l'URL et l'ouvre dans son navigateur :

**Page Tailscale** :
```
╔════════════════════════════════════════╗
║  Autoriser cet appareil ?              ║
╠════════════════════════════════════════╣
║  Nom : raspberry-pi-marie              ║
║  OS  : Linux (Raspberry Pi OS)         ║
║                                        ║
║  [Autoriser]  [Refuser]                ║
╚════════════════════════════════════════╝
```

Marie clique sur **[Autoriser]** ✅

Elle retourne au terminal et appuie sur **Entrée** ⏎

### 4.3 - Configuration avancée Tailscale

```
✅ Authentification réussie !

IP Tailscale assignée : 100.64.12.45

❓ Activer MagicDNS (noms d'hôtes automatiques) ? [O/n]: _
```

**Marie tape** : `O` ✅

```
✅ MagicDNS activé

Votre Pi est maintenant accessible via :
  • 100.64.12.45
  • raspberry-pi-marie

❓ Activer Subnet Router (partager réseau local 192.168.1.0/24) ? [O/n]: _
```

**Marie tape** : `n` ❌ (elle n'a pas besoin de partager tout son réseau)

```
❓ Installer Nginx reverse proxy (URLs amicales) ? [O/n]: _
```

**Marie tape** : `n` ❌ (elle préfère les URLs directes)

---

## 🎉 Étape 5 : Résumé Final

### 5.1 - Rapport de configuration

```
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ✅ Installation Hybride Terminée !                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

═══════════════════════════════════════════════════════════════
📊 Vos 3 méthodes d'accès
═══════════════════════════════════════════════════════════════

🏠 Méthode 1 : Local (ultra-rapide)
   → Utilisez depuis votre réseau WiFi maison
   • Studio : http://192.168.1.105:3000
   • API    : http://192.168.1.105:8000

🌍 Méthode 2 : HTTPS Public (partage facile)
   → Utilisez depuis n'importe où, partagez avec amis
   • Studio : https://mariepro.duckdns.org/studio
   • API    : https://mariepro.duckdns.org/api

🔐 Méthode 3 : Tailscale VPN (sécurisé)
   → Utilisez depuis téléphone/PC perso
   • Studio : http://100.64.12.45:3000
   • API    : http://100.64.12.45:8000
   • Ou     : http://raspberry-pi-marie:3000 (MagicDNS)

═══════════════════════════════════════════════════════════════
🎯 Cas d'usage recommandés
═══════════════════════════════════════════════════════════════

Depuis                    | Méthode           | URL à utiliser
══════════════════════════╪═══════════════════╪══════════════════
🏠 PC bureau (maison)     | Local             | 192.168.1.105:3000
📱 Téléphone (4G/5G)      | Tailscale VPN     | 100.64.12.45:3000
💻 Laptop en déplacement  | Tailscale VPN     | 100.64.12.45:3000
👥 Partage avec collègue  | HTTPS Public      | mariepro.duckdns.org
🔐 Données sensibles      | Tailscale VPN     | 100.64.12.45:3000

═══════════════════════════════════════════════════════════════
📚 Documentation complète
═══════════════════════════════════════════════════════════════

Un guide détaillé a été généré :
→ /tmp/external-access/hybrid-setup/docs/GUIDE-PERSONNALISE-marie.md

Contient :
  ✅ Vos 3 URLs d'accès
  ✅ Guide installation Tailscale sur téléphone/PC
  ✅ Exemples de connexion depuis applications
  ✅ Troubleshooting spécifique à votre config

═══════════════════════════════════════════════════════════════
🔧 Prochaines étapes
═══════════════════════════════════════════════════════════════

1. 📱 Installer Tailscale sur votre téléphone :
   → Android : https://play.google.com/store/apps/details?id=com.tailscale.ipn
   → iOS     : https://apps.apple.com/app/tailscale/id1470499037

2. 💻 Installer Tailscale sur votre PC :
   → Windows : https://tailscale.com/download/windows
   → Mac     : https://tailscale.com/download/mac
   → Linux   : https://tailscale.com/download/linux

3. 🧪 Tester les 3 méthodes d'accès (voir guide ci-dessus)

═══════════════════════════════════════════════════════════════

Installation terminée avec succès ! 🎉
```

---

## 📱 Étape 6 : Marie installe Tailscale sur son téléphone

### 6.1 - Installation Android

Marie ouvre le Play Store et cherche **"Tailscale"**

**Actions** :
1. ✅ Installe l'app Tailscale
2. ✅ Ouvre l'app
3. ✅ Se connecte avec son compte Google (même compte que l'authentification Pi)
4. ✅ Active la connexion VPN

### 6.2 - Test depuis le téléphone (4G activée)

Marie ouvre Chrome sur son téléphone et tape :

```
http://100.64.12.45:3000
```

**Résultat** : ✅ **Supabase Studio s'ouvre !**

Elle peut maintenant gérer sa base de données depuis n'importe où ! 🎉

---

## 💻 Étape 7 : Utilisation quotidienne

### Scénario 1 : Marie travaille à la maison

**Appareil** : PC de bureau (même WiFi que le Pi)

```
URL utilisée : http://192.168.1.105:3000
Performance  : ⚡ Instantané (0ms latence)
Raison       : Communication directe sur réseau local
```

### Scénario 2 : Marie est au café

**Appareil** : MacBook (WiFi du café)

**Actions** :
1. Active Tailscale (icône dans barre menu)
2. Vérifie connexion : ✅ Connected
3. Ouvre navigateur

```
URL utilisée : http://100.64.12.45:3000
Performance  : 🟢 Rapide (~20-50ms latence)
Raison       : Connexion P2P chiffrée via Tailscale
Sécurité     : 🔒 Bout-en-bout chiffré (WireGuard)
```

### Scénario 3 : Marie partage avec son collègue Thomas

**Situation** : Thomas doit ajouter des données dans la DB

**Actions de Marie** :
1. Envoie l'URL publique à Thomas par Slack :
   ```
   Hey Thomas, voici l'accès Supabase :
   https://mariepro.duckdns.org/studio

   User: thomas@example.com
   Pass: (je t'envoie en privé)
   ```

2. Thomas ouvre l'URL (aucune installation requise)
3. ✅ Il accède au Studio et peut travailler

**Performance** : 🟡 Correct (~100-200ms selon location)
**Avantage** : Aucune installation côté Thomas

### Scénario 4 : Marie en vacances à l'étranger

**Appareil** : iPhone (4G/5G)

**Actions** :
1. Ouvre l'app Tailscale
2. Active la connexion
3. Ouvre Safari

```
URL utilisée : http://raspberry-pi-marie:3000 (MagicDNS)
Performance  : 🟢 Rapide malgré la distance
Raison       : Tailscale optimise le routing automatiquement
Sécurité     : 🔒 Connexion chiffrée même sur WiFi d'hôtel
```

---

## 📊 Étape 8 : Bilan après 1 mois d'utilisation

### Statistiques de Marie

| Méthode | Fréquence | Cas d'usage |
|---------|-----------|-------------|
| 🏠 **Local** | 60% | Travail quotidien à la maison |
| 🔐 **Tailscale VPN** | 35% | Déplacements, téléphone, sécurité |
| 🌍 **HTTPS Public** | 5% | Partage avec collaborateurs |

### Retour d'expérience

**✅ Ce qui marche super bien** :
- Local ultra-rapide pour le travail quotidien
- Tailscale parfait sur téléphone (app native)
- HTTPS public pratique pour partages ponctuels
- MagicDNS : URL mémorisable (`raspberry-pi-marie`)

**⚠️ Petits inconvénients** :
- Tailscale ajoute ~30ms de latence (acceptable)
- HTTPS public plus lent depuis certains pays
- Doit penser à activer Tailscale en déplacement

**🎯 Conclusion** :
> "Parfait ! J'ai exactement ce qu'il me fallait : rapidité à la maison, sécurité en déplacement, et possibilité de partager facilement. Le setup hybride était le bon choix !" — Marie

---

## 🔄 Scénarios Alternatifs

### Alternative 1 : Utilisateur qui choisit "Option 3 seulement" (Tailscale uniquement)

**Profil** : Julien, très orienté sécurité, ne veut PAS exposer son Pi sur Internet

**Parcours** :
1. Choisit option 3 au menu (Tailscale seulement)
2. Installation Tailscale (~5 minutes)
3. ✅ Résultat : 1 seule URL (VPN), aucun port ouvert sur routeur

**Utilisation** :
- Accès uniquement via Tailscale (100.x.x.x)
- Sécurité maximale (zéro exposition Internet)
- Doit installer Tailscale sur TOUS ses appareils

### Alternative 2 : Utilisateur qui choisit "Option 1 seulement" (Port Forwarding uniquement)

**Profil** : Sophie, veut partager son instance publiquement (projet open-source)

**Parcours** :
1. Choisit option 2 au menu (Port Forwarding seulement)
2. Configure routeur (~10 minutes)
3. ✅ Résultat : URL publique HTTPS (sophiedb.duckdns.org)

**Utilisation** :
- Accessible depuis n'importe où via HTTPS
- Pas besoin d'installer d'app
- Moins de sécurité (exposé sur Internet)
- Idéal pour partage public ou démos

### Alternative 3 : Utilisateur avec Cloudflare Tunnel (Option 2)

**Profil** : David, bloqué derrière NAT CGNAT (pas d'IP publique)

**Parcours** :
1. Choisit option 2 (Cloudflare Tunnel)
2. Authentification Cloudflare OAuth
3. ✅ Résultat : Sous-domaines (studio.david.com, api.david.com)

**Utilisation** :
- Fonctionne même sans IP publique
- DDoS protection Cloudflare gratuite
- Cloudflare voit le trafic (trade-off vie privée)
- Domaine personnalisé propre

---

## 📝 Points clés pour tous les utilisateurs

### ✅ Ce que les scripts font automatiquement
- Détection IP locale/publique/routeur
- Détection FAI (guide adapté)
- Tests de connectivité
- Génération certificats SSL (Let's Encrypt)
- Configuration Docker Compose
- Création guide personnalisé avec les IPs/URLs de l'utilisateur

### 🔧 Ce que l'utilisateur doit faire
- Répondre aux questions du quiz
- Configurer routeur (Option 1)
- Authentifier Cloudflare/Tailscale (Options 2/3)
- Installer clients Tailscale sur autres appareils (Option 3)

### ⏱️ Durées moyennes
- **Option 1** : 15-20 minutes (config routeur incluse)
- **Option 2** : 10-15 minutes (OAuth Cloudflare)
- **Option 3** : 5-10 minutes (installation Tailscale)
- **Hybride** : 30-35 minutes (somme Option 1 + 3)

---

**🎓 Pédagogie** : Cette simulation montre qu'un utilisateur débutant peut réussir grâce à :
1. Quiz interactif pour choisir la bonne option
2. Détection automatique (FAI, IPs, réseau)
3. Guides contextuels (Freebox, Orange, etc.)
4. Tests de validation en temps réel
5. Documentation personnalisée générée automatiquement
