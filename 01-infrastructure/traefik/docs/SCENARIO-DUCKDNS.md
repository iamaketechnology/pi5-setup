# 🟢 Scénario 1 : DuckDNS + Let's Encrypt

> **Pour débutants : HTTPS gratuit sans acheter de domaine**

**Durée** : ~15 minutes
**Difficulté** : ⭐ Facile
**Coût** : 100% Gratuit

---

## 📋 Vue d'Ensemble

### Ce que vous allez avoir

```
https://monpi.duckdns.org          → Homepage (portail d'accueil)
https://monpi.duckdns.org/studio   → Supabase Studio
https://monpi.duckdns.org/api      → Supabase REST API
https://monpi.duckdns.org/traefik  → Dashboard Traefik
```

### Avantages
- ✅ 100% gratuit (domaine + certificat HTTPS)
- ✅ Setup ultra-rapide (15 min)
- ✅ Certificat HTTPS valide (cadenas vert dans navigateur)
- ✅ Parfait pour débuter

### Limitations
- ❌ Pas de sous-domaines (juste des sous-chemins `/studio`, `/api`)
- ❌ Domaine imposé `.duckdns.org`
- ❌ Ne fonctionne PAS si vous êtes derrière CGNAT (voir FAQ)

---

## 🚀 Installation Pas-à-Pas

### Étape 1 : Créer un compte DuckDNS (2 min)

1. **Aller sur** [duckdns.org](https://www.duckdns.org)

2. **Se connecter** avec :
   - GitHub
   - Google
   - Twitter
   - Reddit
   (Pas besoin de créer un compte, utilise juste ton compte existant)

3. **Créer un sous-domaine** :
   - Dans "domains", tape un nom : `monpi` (ou ce que tu veux)
   - Clic "add domain"
   - Tu obtiens : `monpi.duckdns.org`

4. **Noter ton IP publique** :
   - DuckDNS affiche automatiquement ton IP publique actuelle
   - Exemple : `86.245.123.45`

5. **Noter ton token** :
   - En haut de la page, tu vois : `token: a1b2c3d4-e5f6-7890-abcd-ef1234567890`
   - **COPIE CE TOKEN** (tu en auras besoin)

---

### Étape 2 : Configurer votre Box Internet (5 min)

**Objectif** : Rediriger les ports 80 et 443 vers votre Raspberry Pi

#### A. Trouver l'IP locale de votre Pi

Sur le Pi :
```bash
hostname -I
```
→ Exemple : `192.168.1.100`

#### B. Ouvrir l'interface de votre Box

| Opérateur | URL Interface | Login |
|-----------|---------------|-------|
| **Freebox** | http://mafreebox.freebox.fr | Mot de passe box |
| **Livebox Orange** | http://192.168.1.1 | admin / 8 premiers caractères clé WiFi |
| **SFR Box** | http://192.168.1.1 | admin / mot de passe au dos box |
| **Bouygues** | http://192.168.1.254 | admin / mot de passe au dos box |

#### C. Configurer le Port Forwarding

**Chercher dans les menus** :
- Freebox : "Paramètres de la Freebox" → "Mode avancé" → "Redirections de ports"
- Livebox : "Configuration avancée" → "NAT/PAT" → "Redirection de ports"
- SFR Box : "Réseau" → "NAT/PAT"
- Bouygues : "Configuration avancée" → "NAT"

**Créer 2 redirections** :

| Nom | Port Externe | Port Interne | Protocole | IP Destination |
|-----|--------------|--------------|-----------|----------------|
| HTTP | 80 | 80 | TCP | 192.168.1.100 (IP du Pi) |
| HTTPS | 443 | 443 | TCP | 192.168.1.100 (IP du Pi) |

**Sauvegarder et redémarrer la box** si demandé.

#### D. Vérifier que les ports sont ouverts

Depuis un autre appareil (téléphone 4G, pas WiFi maison) :
```bash
# Tester si port ouvert
curl http://VOTRE_IP_PUBLIQUE
```

Ou utiliser : [canyouseeme.org](https://canyouseeme.org/) → Port 80

---

### Étape 3 : Installer Traefik avec DuckDNS (5 min)

**Sur votre Raspberry Pi** :

```bash
# Télécharger et exécuter le script
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Le script va vous demander** :

1. **Votre sous-domaine DuckDNS** :
   ```
   Enter your DuckDNS subdomain (without .duckdns.org): monpi
   ```

2. **Votre token DuckDNS** :
   ```
   Enter your DuckDNS token: a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **Votre email** (pour Let's Encrypt) :
   ```
   Enter your email for Let's Encrypt notifications: votre@email.com
   ```

**Le script va** :
- ✅ Créer la configuration Traefik
- ✅ Lancer Traefik dans Docker
- ✅ Configurer DuckDNS pour mettre à jour votre IP automatiquement
- ✅ Demander un certificat Let's Encrypt (peut prendre 1-2 min)
- ✅ Configurer la redirection HTTP → HTTPS

---

### Étape 4 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

**Le script va** :
- ✅ Ajouter les labels Traefik au docker-compose de Supabase
- ✅ Configurer les routes :
  - `/studio` → Supabase Studio
  - `/api` → Supabase REST API
- ✅ Redémarrer Supabase

---

### Étape 5 : Tester ! (1 min)

**Depuis n'importe quel navigateur (même hors de chez vous)** :

1. **Supabase Studio** :
   ```
   https://monpi.duckdns.org/studio
   ```
   → Vous devez voir Supabase Studio avec le cadenas vert 🔒

2. **Supabase API** :
   ```
   https://monpi.duckdns.org/api
   ```

3. **Dashboard Traefik** :
   ```
   https://monpi.duckdns.org/traefik
   ```
   → Login : `admin` / Password : celui affiché à la fin du script

🎉 **C'est terminé !** Vos webapps sont accessibles depuis l'extérieur en HTTPS !

---

## 🔧 Configuration

### Fichiers Créés

```
/home/pi/stacks/traefik/
├── docker-compose.yml           # Config Docker
├── traefik.yml                  # Config statique Traefik
├── dynamic/
│   ├── middlewares.yml          # Middlewares (auth, etc.)
│   └── tls.yml                  # Config TLS
├── acme.json                    # Certificats Let's Encrypt (mode 600)
└── .env                         # Variables (token DuckDNS, email)
```

### Variables d'Environnement

Fichier `/home/pi/stacks/traefik/.env` :
```bash
DUCKDNS_SUBDOMAIN=monpi
DUCKDNS_TOKEN=a1b2c3d4-e5f6-7890-abcd-ef1234567890
ACME_EMAIL=votre@email.com
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD_HASH=$apr1$xxx...
```

### Docker Compose

```yaml
services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - DUCKDNS_TOKEN=${DUCKDNS_TOKEN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./dynamic:/dynamic:ro
      - ./acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=PathPrefix(`/traefik`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.middlewares=auth"

  duckdns:
    image: lscr.io/linuxserver/duckdns:latest
    container_name: duckdns
    environment:
      - SUBDOMAINS=${DUCKDNS_SUBDOMAIN}
      - TOKEN=${DUCKDNS_TOKEN}
    restart: unless-stopped
```

---

## 🎨 Ajouter d'Autres Services

### Exemple : Exposer Portainer

**Ajouter dans le docker-compose.yml de Portainer** :

```yaml
services:
  portainer:
    # ... config existante ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portainer.rule=PathPrefix(`/portainer`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"
      - "traefik.http.middlewares.portainer-strip.stripprefix.prefixes=/portainer"
      - "traefik.http.routers.portainer.middlewares=portainer-strip"
```

**Résultat** : `https://monpi.duckdns.org/portainer`

---

## 🆘 Troubleshooting

### ❌ "ERR_SSL_PROTOCOL_ERROR"

**Cause** : Certificat pas encore généré

**Solution** :
```bash
# Vérifier logs Traefik
docker logs traefik -f

# Chercher :
# "Unable to obtain ACME certificate" → Voir cause
```

**Causes possibles** :
1. **Ports 80/443 pas ouverts** → Vérifier box
2. **DNS pas propagé** → Attendre 5-10 min
3. **Rate limit Let's Encrypt** → Attendre 1h (max 5 certificats/heure)

---

### ❌ "404 - Backend not found"

**Cause** : Labels Docker mal configurés

**Solution** :
```bash
# Vérifier que Supabase a bien les labels
docker inspect supabase-studio | grep traefik

# Si pas de labels, relancer l'intégration :
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

### ❌ "DNS not resolving"

**Test** :
```bash
nslookup monpi.duckdns.org
```

**Si pas de réponse** :
1. Vérifier que le container `duckdns` tourne :
   ```bash
   docker ps | grep duckdns
   ```

2. Vérifier logs DuckDNS :
   ```bash
   docker logs duckdns
   ```

3. Forcer mise à jour manuelle :
   ```bash
   curl "https://www.duckdns.org/update?domains=monpi&token=VOTRE_TOKEN&ip="
   ```

---

### ❌ "Je suis derrière CGNAT"

**Symptôme** : L'IP publique affichée par DuckDNS change constamment ou commence par `100.x.x.x`

**Explication** : Votre FAI utilise CGNAT (Carrier-Grade NAT), vous n'avez pas d'IP publique fixe.

**Solutions** :
1. **Contacter votre FAI** pour demander une IP publique (parfois payant)
2. **Utiliser Cloudflare Tunnel** (gratuit, pas besoin d'IP publique) → Voir [Scénario 2 alternatif](SCENARIO-CLOUDFLARE.md#cloudflare-tunnel)
3. **Passer au Scénario 3 (VPN)** → [SCENARIO-VPN.md](SCENARIO-VPN.md)

---

## 📊 Performances

### Latence Ajoutée par Traefik

- **Sans Traefik** : `http://192.168.1.100:8000` → ~5ms
- **Avec Traefik** : `https://monpi.duckdns.org/studio` → ~8-12ms (+3-7ms)

**Impact** : Négligeable pour des webapps classiques.

### Consommation Ressources

- **RAM** : ~50-80 MB
- **CPU** : <1% (idle), 5-10% (trafic modéré)

---

## 🔐 Sécurité

### Ce qui est Automatiquement Sécurisé

✅ **HTTPS obligatoire** (redirection HTTP → HTTPS)
✅ **Certificats valides** (Let's Encrypt)
✅ **Headers de sécurité** (HSTS, X-Frame-Options)
✅ **Dashboard protégé** (authentification)

### Recommandations Supplémentaires

1. **Activer Fail2ban** (bloquer bruteforce) :
   ```bash
   sudo apt install fail2ban
   ```

2. **Limiter rate** (éviter abus) :
   Déjà configuré dans `middlewares.yml` : 100 req/s max

3. **Surveiller logs** :
   ```bash
   docker logs traefik -f --tail 100
   ```

---

## 🎯 Prochaines Étapes

Maintenant que Traefik fonctionne :

1. **Installer Homepage** (portail d'accueil) :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
   ```

2. **Exposer Portainer** (voir section "Ajouter d'Autres Services")

3. **Ajouter Monitoring** → [Phase 3 Roadmap](../../ROADMAP.md#phase-3)

---

## 📚 Ressources

- [DuckDNS Docs](https://www.duckdns.org/spec.jsp)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)
- [Traefik HTTP Challenge](https://doc.traefik.io/traefik/https/acme/#httpchallenge)

---

**Besoin d'aide ?** → [Troubleshooting complet](TROUBLESHOOTING.md) | [Discord Traefik](https://discord.gg/traefik)
