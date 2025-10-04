# 🔵 Scénario 2 : Domaine Personnel + Cloudflare DNS

> **Pour production : Sous-domaines illimités avec HTTPS automatique**

**Durée** : ~25 minutes
**Difficulté** : ⭐⭐ Moyen
**Coût** : ~3-15€/an (domaine uniquement, Cloudflare gratuit)

---

## 📋 Vue d'Ensemble

### Ce que vous allez avoir

```
https://monpi.fr              → Homepage (portail)
https://studio.monpi.fr       → Supabase Studio
https://api.monpi.fr          → Supabase REST API
https://git.monpi.fr          → Gitea (futur)
https://grafana.monpi.fr      → Monitoring (futur)
https://traefik.monpi.fr      → Dashboard Traefik
```

### Avantages
- ✅ Sous-domaines illimités (`*.monpi.fr`)
- ✅ Votre propre nom de domaine (professionnel)
- ✅ Certificats HTTPS automatiques (Let's Encrypt)
- ✅ Protection DDoS gratuite (Cloudflare)
- ✅ Cache et CDN gratuit
- ✅ Analytics gratuit
- ✅ Fonctionne même derrière CGNAT (avec Cloudflare Tunnel)

### Coût
- 💰 **Domaine** : ~3-15€/an selon extension
  - `.fr` : ~8€/an (OVH, Gandi)
  - `.com` : ~12€/an
  - `.dev` : ~15€/an
  - `.xyz` : ~3€/an (le moins cher)
- ✅ **Cloudflare** : Gratuit (plan Free suffit amplement)

---

## 🚀 Installation Pas-à-Pas

### Étape 1 : Acheter un Domaine (5 min)

**Registrars recommandés** :

| Registrar | Prix `.fr` | Prix `.com` | Avantages |
|-----------|------------|-------------|-----------|
| **[OVH](https://www.ovh.com)** | ~8€/an | ~10€/an | Français, support FR, WHOIS anonyme |
| **[Gandi](https://www.gandi.net)** | ~15€/an | ~15€/an | Éthique, WHOIS anonyme inclus |
| **[Namecheap](https://www.namecheap.com)** | - | ~10€/an | Anglais, pas cher |
| **[Porkbun](https://porkbun.com)** | ~9€/an | ~9€/an | Très bon rapport qualité/prix |

**Conseil** : Commencez avec OVH (français, simple) ou Porkbun (pas cher).

**Acheter** :
1. Chercher disponibilité : `monpi.fr`
2. Ajouter au panier
3. Payer (carte bleue, PayPal)
4. **NE PAS configurer les DNS encore** (on le fera à l'étape 2)

---

### Étape 2 : Configurer Cloudflare (10 min)

#### A. Créer un compte Cloudflare

1. Aller sur [cloudflare.com](https://www.cloudflare.com)
2. Cliquer "Sign Up" (gratuit)
3. Confirmer email

#### B. Ajouter votre domaine

1. Cliquer "Add a Site"
2. Entrer `monpi.fr` (votre domaine)
3. Choisir plan **Free** (gratuit)
4. Cliquer "Continue"

#### C. Scanner DNS existants

Cloudflare va scanner les DNS existants de votre domaine. Cliquer "Continue".

#### D. Modifier les nameservers chez votre registrar

**Cloudflare vous donne 2 nameservers** :
```
layla.ns.cloudflare.com
rex.ns.cloudflare.com
```

**Aller dans l'interface de votre registrar** :

**OVH** :
1. Se connecter à [ovh.com](https://www.ovh.com/manager/)
2. "Noms de domaine" → Votre domaine
3. "Serveurs DNS"
4. "Modifier les serveurs DNS"
5. Remplacer par les 2 nameservers Cloudflare
6. Sauvegarder (propagation : 15 min - 48h, généralement 30 min)

**Gandi** :
1. Se connecter à [gandi.net](https://admin.gandi.net)
2. Domaines → Votre domaine
3. "Nameservers"
4. "Modifier"
5. Entrer les 2 nameservers Cloudflare

**Autres registrars** : Chercher "Nameservers" ou "DNS Servers" dans les paramètres.

#### E. Attendre propagation DNS

Dans Cloudflare, vous verrez "Pending nameserver update".

**Vérifier propagation** :
```bash
dig NS monpi.fr +short
```

Quand ça affiche les nameservers Cloudflare → C'est bon ! ✅

---

### Étape 3 : Configurer les DNS dans Cloudflare (3 min)

1. Dans Cloudflare → Votre domaine → **DNS** → **Records**

2. **Ajouter un enregistrement A** :
   - Type : `A`
   - Name : `@` (domaine racine)
   - IPv4 address : Votre **IP publique** (voir [whatismyip.com](https://www.whatismyip.com))
   - Proxy status : 🟠 **DNS only** (important pour Let's Encrypt)
   - TTL : Auto
   - Cliquer "Save"

3. **Ajouter un wildcard** (pour tous les sous-domaines) :
   - Type : `A`
   - Name : `*`
   - IPv4 address : Votre IP publique (même que ci-dessus)
   - Proxy status : 🟠 **DNS only**
   - TTL : Auto
   - Cliquer "Save"

**Résultat** :
```
monpi.fr       → 86.245.123.45 (votre IP)
*.monpi.fr     → 86.245.123.45 (tous les sous-domaines)
```

**Tester** :
```bash
nslookup studio.monpi.fr
```
→ Doit afficher votre IP publique

---

### Étape 4 : Obtenir un API Token Cloudflare (2 min)

**Pourquoi ?** Pour que Traefik puisse valider les certificats via DNS-01 challenge.

1. Dans Cloudflare → Profil → **API Tokens**
2. Cliquer "Create Token"
3. Template : **"Edit zone DNS"**
4. Permissions :
   - Zone → DNS → Edit
   - Zone → Zone → Read
5. Zone Resources :
   - Include → Specific zone → `monpi.fr`
6. Cliquer "Continue to summary"
7. Cliquer "Create Token"
8. **COPIER LE TOKEN** (affiché une seule fois) :
   ```
   aBcD1234EfGh5678IjKl9012MnOp3456QrSt7890
   ```

---

### Étape 5 : Configurer votre Box Internet (5 min)

**Même procédure que Scénario 1** (voir [SCENARIO-DUCKDNS.md](SCENARIO-DUCKDNS.md#étape-2--configurer-votre-box-internet-5-min))

**Résumé** :
- Redirection port **80** → `192.168.1.100:80` (IP du Pi)
- Redirection port **443** → `192.168.1.100:443`

---

### Étape 6 : Installer Traefik avec Cloudflare (3 min)

**Sur votre Raspberry Pi** :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

**Le script va demander** :

1. **Votre domaine** :
   ```
   Enter your domain (e.g., monpi.fr): monpi.fr
   ```

2. **Votre token Cloudflare** :
   ```
   Enter your Cloudflare API token: aBcD1234EfGh5678IjKl9012MnOp3456QrSt7890
   ```

3. **Votre email** (pour Let's Encrypt) :
   ```
   Enter your email for Let's Encrypt: votre@email.com
   ```

**Le script va** :
- ✅ Créer la configuration Traefik avec DNS-01 challenge
- ✅ Lancer Traefik
- ✅ Demander un certificat wildcard `*.monpi.fr` (1-2 min)
- ✅ Configurer HTTPS automatique

---

### Étape 7 : Intégrer Supabase (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

**Le script va demander** :
```
Enter your domain: monpi.fr
```

**Il va** :
- ✅ Configurer `studio.monpi.fr` → Supabase Studio
- ✅ Configurer `api.monpi.fr` → Supabase REST API
- ✅ Redémarrer Supabase avec les labels Traefik

---

### Étape 8 : Tester ! (1 min)

**Depuis n'importe où** :

1. **Supabase Studio** :
   ```
   https://studio.monpi.fr
   ```
   → Cadenas vert 🔒

2. **Supabase API** :
   ```
   https://api.monpi.fr/rest/v1/
   ```

3. **Dashboard Traefik** :
   ```
   https://traefik.monpi.fr
   ```

🎉 **Terminé !** Vous avez des sous-domaines illimités en HTTPS !

---

## 🔧 Configuration

### Structure des Fichiers

```
/home/pi/stacks/traefik/
├── docker-compose.yml
├── traefik.yml
├── dynamic/
│   ├── middlewares.yml
│   └── tls.yml
├── acme.json              # Certificats wildcard
└── .env
```

### Variables d'Environnement

`/home/pi/stacks/traefik/.env` :
```bash
DOMAIN=monpi.fr
CLOUDFLARE_API_TOKEN=aBcD1234...
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
      - CF_DNS_API_TOKEN=${CLOUDFLARE_API_TOKEN}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./dynamic:/dynamic:ro
      - ./acme.json:/acme.json
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.dashboard.rule=Host(`traefik.${DOMAIN}`)"
      - "traefik.http.routers.dashboard.service=api@internal"
      - "traefik.http.routers.dashboard.tls.certresolver=cloudflare"
```

### Traefik Static Config

`traefik.yml` :
```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

certificatesResolvers:
  cloudflare:
    acme:
      email: ${ACME_EMAIL}
      storage: /acme.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "8.8.8.8:53"
```

---

## 🎨 Ajouter d'Autres Services

### Exemple : Exposer Gitea

**Dans le docker-compose.yml de Gitea** :

```yaml
services:
  gitea:
    image: gitea/gitea:latest
    # ... config existante ...
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.gitea.rule=Host(`git.monpi.fr`)"
      - "traefik.http.routers.gitea.entrypoints=websecure"
      - "traefik.http.routers.gitea.tls.certresolver=cloudflare"
      - "traefik.http.services.gitea.loadbalancer.server.port=3000"
```

**Résultat** : `https://git.monpi.fr` ✅

### Exemple : Exposer Homepage

```yaml
services:
  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.homepage.rule=Host(`monpi.fr`)"
      - "traefik.http.routers.homepage.entrypoints=websecure"
      - "traefik.http.routers.homepage.tls.certresolver=cloudflare"
      - "traefik.http.services.homepage.loadbalancer.server.port=3000"
```

**Résultat** : `https://monpi.fr` → Portail d'accueil

---

## 🚀 Option Avancée : Cloudflare Tunnel (CGNAT)

**Pour qui ?** Si vous êtes derrière CGNAT (pas d'IP publique fixe)

**Avantages** :
- ✅ Pas besoin d'ouvrir de ports sur la box
- ✅ Pas besoin d'IP publique
- ✅ Gratuit
- ✅ Sécurisé (tunnel chiffré)

**Inconvénient** :
- ❌ Tout le trafic passe par Cloudflare

### Installation Cloudflare Tunnel

1. **Dans Cloudflare** → Zero Trust → Access → Tunnels
2. Cliquer "Create a tunnel"
3. Nom : `pi5-homelab`
4. Cliquer "Save tunnel"
5. **Copier le token** affiché

6. **Sur le Pi** :
```bash
docker run -d \
  --name cloudflared \
  --restart unless-stopped \
  cloudflare/cloudflared:latest \
  tunnel --no-autoupdate run --token VOTRE_TOKEN
```

7. **Dans Cloudflare** → Public Hostname :
   - Subdomain : `studio`
   - Domain : `monpi.fr`
   - Service : `http://localhost:8000`
   - Cliquer "Save"

**Résultat** : `https://studio.monpi.fr` accessible sans ouvrir de ports ! 🎉

---

## 🆘 Troubleshooting

### ❌ "DNS_PROBE_FINISHED_NXDOMAIN"

**Cause** : DNS pas propagé ou mal configuré

**Vérifier** :
```bash
nslookup studio.monpi.fr
```

**Si pas de réponse** :
1. Attendre propagation (jusqu'à 48h, généralement 1h)
2. Vérifier les nameservers :
   ```bash
   dig NS monpi.fr +short
   ```
   → Doit afficher les nameservers Cloudflare

---

### ❌ "ERR_SSL_PROTOCOL_ERROR"

**Cause** : Certificat pas encore généré

**Solution** :
```bash
# Logs Traefik
docker logs traefik -f

# Chercher :
# "Obtained certificate for *.monpi.fr" → OK
# "Unable to obtain ACME certificate" → Problème
```

**Causes possibles** :
1. **Token Cloudflare invalide** → Vérifier `.env`
2. **Proxy Cloudflare activé** → Doit être "DNS only" (🟠)
3. **Rate limit Let's Encrypt** → Attendre 1h

---

### ❌ "403 Forbidden" depuis Cloudflare

**Cause** : Cloudflare bloque le trafic (protection)

**Solution** :
1. Cloudflare → Security → WAF
2. Désactiver temporairement
3. Ou ajouter votre IP en whitelist

---

## 🔐 Sécurité Avancée

### Activer Proxy Cloudflare (DDoS Protection)

**Après avoir validé que tout fonctionne** :

1. Cloudflare → DNS → Records
2. Cliquer sur 🟠 "DNS only" → Passer à 🟧 "Proxied"
3. Sauvegarder

**Avantages** :
- ✅ Protection DDoS
- ✅ Cache (site plus rapide)
- ✅ IP du Pi cachée

**Inconvénient** :
- ❌ Ne fonctionne PAS avec DNS-01 challenge

**Solution** :
1. Générer le certificat d'abord (DNS only)
2. Une fois obtenu, activer Proxy
3. Certificat valide 90 jours, se renouvelle automatiquement

---

### Authentification SSO (Authelia)

**Pour protéger les services sensibles** (Portainer, Traefik Dashboard) :

Voir [Phase 9 Roadmap](../../ROADMAP.md#phase-9) - Authelia

---

## 📊 Performances

### Latence

- **Sans Cloudflare Proxy** : +3-7ms (Traefik)
- **Avec Cloudflare Proxy** : +20-50ms (cache peut réduire)

### Consommation

- **RAM** : ~80-100 MB (Traefik seul)
- **CPU** : <1% idle, 5-15% sous charge

---

## 💰 Coûts Annuels

| Service | Coût |
|---------|------|
| Domaine `.fr` (OVH) | 8€/an |
| Domaine `.com` (Namecheap) | 10€/an |
| Domaine `.xyz` (Porkbun) | 3€/an |
| Cloudflare | Gratuit |
| Let's Encrypt | Gratuit |
| **TOTAL** | **3-15€/an** |

---

## 🎯 Prochaines Étapes

1. **Activer Cloudflare Proxy** (protection DDoS)
2. **Installer Homepage** (portail)
3. **Exposer Gitea, Grafana** avec sous-domaines
4. **Configurer Authelia** (SSO) → Phase 9

---

## 📚 Ressources

- [Cloudflare DNS Docs](https://developers.cloudflare.com/dns/)
- [Traefik DNS Challenge](https://doc.traefik.io/traefik/https/acme/#dnschallenge)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)

---

**Besoin d'aide ?** → [Troubleshooting](TROUBLESHOOTING.md) | [Discord Cloudflare](https://discord.gg/cloudflare)
