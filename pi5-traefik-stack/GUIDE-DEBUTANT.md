# 📚 Guide Débutant - Traefik Stack (Reverse Proxy)

> **Pour qui ?** Débutants en reverse proxy, HTTPS et exposition de webapps
> **Durée de lecture** : 20 minutes
> **Niveau** : Débutant (aucune connaissance préalable requise)

---

## 🤔 C'est quoi Traefik ?

### En une phrase
**Traefik = Un réceptionniste d'hôtel automatique qui dirige les visiteurs vers vos webapps et leur donne des certificats HTTPS gratuits.**

### Analogie simple

Imagine un **grand hôtel** (ton Raspberry Pi) avec plusieurs chambres (Supabase, Gitea, Grafana, etc.).

**Sans Traefik** :
```
Visiteur arrive → "Chambre Supabase ? C'est la porte 8000 au fond du couloir"
                → "Grafana ? Porte 3001, 3ème étage"
                → "Gitea ? Porte 3000... ou 3002 ? J'ai oublié"
```

**Avec Traefik** (le réceptionniste) :
```
Visiteur : "Je veux voir Supabase Studio"
Traefik  : "Suivez-moi, c'est par ici !"
           → Le conduit automatiquement à la bonne chambre (port 8000)
           → Lui donne une clé sécurisée (certificat HTTPS)
           → Il n'a même pas besoin de connaître le numéro de chambre
```

**En informatique** :
- Tu ne tapes plus `http://192.168.1.100:8000` (compliqué, pas sécurisé)
- Tu tapes `https://studio.monpi.fr` (simple, sécurisé, professionnel)

---

## 🎯 À quoi ça sert concrètement ?

### Use Cases (Exemples d'utilisation)

#### 1. **Accéder à tes webapps depuis n'importe où**
Tu es au travail, en vacances, chez un ami, et tu veux accéder à ton Supabase Studio :
```
Traefik fait :
✅ Transforme http://192.168.1.100:8000 en https://studio.monpi.fr
✅ Accessible depuis n'importe où (pas juste ton WiFi maison)
✅ Sécurisé avec HTTPS (cadenas vert dans le navigateur)
✅ Tu n'as pas besoin de retenir des numéros de ports bizarres
```

#### 2. **Gérer plusieurs webapps sans conflit de ports**
Tu veux installer 10 services sur ton Pi (Supabase, Gitea, Grafana, Homepage, etc.) :
```
Sans Traefik :
❌ Supabase : http://192.168.1.100:8000
❌ Gitea : http://192.168.1.100:3001
❌ Grafana : http://192.168.1.100:3002
→ Tu dois retenir tous les ports, c'est le chaos !

Avec Traefik :
✅ https://studio.monpi.fr   → Supabase Studio
✅ https://git.monpi.fr      → Gitea
✅ https://grafana.monpi.fr  → Grafana
✅ https://monpi.fr          → Homepage
→ Des noms clairs, faciles à retenir !
```

#### 3. **HTTPS automatique et gratuit**
Tu veux que ton site affiche le cadenas vert (HTTPS) sans payer :
```
Traefik fait :
✅ Génère automatiquement des certificats SSL (Let's Encrypt)
✅ Les renouvelle automatiquement tous les 3 mois
✅ Configure HTTPS pour tous tes services
✅ 100% gratuit, zéro configuration manuelle
```

#### 4. **Développer comme un professionnel**
Tu veux apprendre le développement web moderne :
```
Traefik t'apprend :
✅ Comment fonctionnent les reverse proxies (utilisés par TOUTES les entreprises)
✅ Les certificats SSL/TLS (essentiel pour la sécurité web)
✅ Les sous-domaines et DNS (infrastructure réseau)
✅ Docker labels (configuration moderne)
```

---

## 🧩 Les Composants (Expliqués simplement)

### 1. **Traefik** - Le Réceptionniste Automatique

**C'est quoi ?** Un logiciel qui reçoit toutes les requêtes HTTP/HTTPS et les redirige vers le bon service.

**Exemple concret** :
```
1. Tu tapes : https://studio.monpi.fr
2. Traefik reçoit la requête
3. Traefik regarde ses "labels Docker" (annuaire automatique)
4. Traefik trouve : "studio = port 8000 du container supabase-studio"
5. Traefik redirige vers Supabase Studio
6. Tu vois l'interface Supabase !
```

**Pourquoi c'est magique ?**
- Configuration **automatique** (détecte les nouveaux containers Docker)
- Certificats SSL **automatiques** (demande et renouvelle tout seul)
- Dashboard **intégré** (voir le trafic en temps réel)

---

### 2. **HTTPS / SSL** - La Sécurité

**C'est quoi ?** Un système de chiffrement qui protège tes données sur Internet.

**Analogie** :
- **HTTP** (sans S) = Envoyer une lettre **sans enveloppe** 📧
  → N'importe qui peut lire ton mot de passe en chemin

- **HTTPS** (avec S) = Envoyer une lettre dans un **coffre-fort blindé** 🔒
  → Personne ne peut lire tes données, même si elles sont interceptées

**Exemple visuel dans le navigateur** :
```
❌ http://monpi.fr          → "Non sécurisé" (barre rouge)
✅ https://monpi.fr         → 🔒 Cadenas vert
```

**Comment Traefik génère les certificats ?**
1. Tu demandes à Traefik de gérer `studio.monpi.fr`
2. Traefik contacte **Let's Encrypt** (autorité gratuite)
3. Let's Encrypt vérifie que tu possèdes bien le domaine
4. Let's Encrypt génère un certificat valide 3 mois
5. Traefik renouvelle automatiquement avant expiration

**C'est comme** :
- Let's Encrypt = La préfecture qui délivre des passeports gratuits
- Certificat SSL = Un passeport officiel pour ton site web
- Traefik = Ton assistant qui va chercher et renouvelle le passeport automatiquement

---

### 3. **Sous-domaines vs Sous-chemins** - Deux manières d'organiser

**Sous-domaines** (comme des immeubles séparés) :
```
https://studio.monpi.fr   → Supabase Studio
https://api.monpi.fr      → Supabase API
https://git.monpi.fr      → Gitea

Avantages :
✅ Plus propre, plus professionnel
✅ Chaque service a son propre "nom"
✅ Permet des certificats SSL par service

Inconvénient :
❌ Nécessite un vrai domaine (monpi.fr)
```

**Sous-chemins** (comme des appartements dans le même immeuble) :
```
https://monpi.fr/studio   → Supabase Studio
https://monpi.fr/api      → Supabase API
https://monpi.fr/git      → Gitea

Avantages :
✅ Fonctionne avec DuckDNS (gratuit)
✅ Un seul certificat SSL pour tout

Inconvénient :
❌ URLs plus longues
❌ Certains services ne supportent pas bien les sous-chemins
```

**Analogie** :
- **Sous-domaines** = Avoir plusieurs maisons séparées (studio-house.com, api-house.com)
- **Sous-chemins** = Avoir un immeuble avec plusieurs appartements (house.com/studio, house.com/api)

---

### 4. **Docker Labels** - L'Annuaire Automatique

**C'est quoi ?** Des étiquettes que tu colles sur tes containers Docker pour dire à Traefik comment les gérer.

**Exemple simple** :
```yaml
services:
  mon-site:
    image: nginx
    labels:
      - "traefik.enable=true"                                    # Active Traefik
      - "traefik.http.routers.mon-site.rule=Host(`site.monpi.fr`)"  # Nom de domaine
      - "traefik.http.services.mon-site.loadbalancer.server.port=80" # Port interne
```

**Traduction en français** :
```
Traefik, je te présente "mon-site" :
1. Active-toi pour ce container (traefik.enable=true)
2. Quand quelqu'un demande "site.monpi.fr", envoie-le vers moi
3. Mon service tourne sur le port 80 en interne
```

**C'est comme** :
- Labels = Une fiche de contact que tu donnes au réceptionniste
- Traefik lit automatiquement toutes les fiches et sait où diriger les visiteurs

---

### 5. **Let's Encrypt** - Les Certificats Gratuits

**C'est quoi ?** Une organisation à but non lucratif qui donne des certificats SSL **gratuits** à tout le monde.

**Pourquoi c'est révolutionnaire ?**

**Avant Let's Encrypt (2015)** :
```
❌ Acheter un certificat SSL : 50-200€/an
❌ Configuration manuelle complexe
❌ Renouvellement manuel tous les ans
→ Seules les grosses entreprises avaient HTTPS
```

**Avec Let's Encrypt (depuis 2015)** :
```
✅ Gratuit (0€)
✅ Automatique (Traefik fait tout)
✅ Valide partout (navigateurs font confiance)
→ Tout le monde peut avoir HTTPS !
```

**Deux méthodes de validation** :

**HTTP-01 Challenge** (la plus simple) :
```
1. Let's Encrypt : "Prouve que tu possèdes monpi.fr"
2. Let's Encrypt : "Crée un fichier sur http://monpi.fr/.well-known/acme-challenge/xyz"
3. Traefik crée le fichier automatiquement
4. Let's Encrypt vérifie que le fichier existe
5. Let's Encrypt : "OK, voici ton certificat !"

Nécessite : Ports 80 et 443 ouverts sur Internet
```

**DNS-01 Challenge** (plus avancé) :
```
1. Let's Encrypt : "Prouve que tu possèdes monpi.fr"
2. Let's Encrypt : "Crée un enregistrement DNS TXT"
3. Traefik utilise l'API Cloudflare pour créer l'enregistrement
4. Let's Encrypt vérifie l'enregistrement DNS
5. Let's Encrypt : "OK, voici ton certificat !"

Avantage : Fonctionne même sans ouvrir de ports (idéal CGNAT)
```

---

### 6. **Dashboard Traefik** - Le Tableau de Bord

**C'est quoi ?** Une interface web pour voir tout ce que fait Traefik en temps réel.

**Tu peux voir** :
- Tous les services exposés (Supabase, Gitea, etc.)
- Le trafic en direct (nombre de requêtes/seconde)
- Les certificats SSL (date d'expiration)
- Les erreurs (404, 502, etc.)

**Exemple d'utilisation** :
```
1. Ouvrir : https://monpi.fr/traefik
2. Login : admin / ton-mot-de-passe
3. Voir :
   - 3 routers actifs (studio, api, homepage)
   - 145 requêtes dans les 5 dernières minutes
   - Certificat SSL expire dans 89 jours
```

**C'est comme** :
- Le tableau de bord de ta voiture (vitesse, essence, température)
- Mais pour ton reverse proxy

---

## 🚀 Comment l'utiliser ? (Pas à pas)

### Choix du Scénario

**Avant de commencer**, tu dois choisir un scénario selon ton besoin :

| Scénario | Pour qui ? | Coût | Difficulté | HTTPS valide ? |
|----------|-----------|------|------------|----------------|
| **1. DuckDNS** | Débutants, pas de domaine | Gratuit | ⭐ Facile | ✅ Oui |
| **2. Cloudflare** | Domaine perso, production | ~5€/an | ⭐⭐ Moyen | ✅ Oui |
| **3. VPN** | Sécurité max, aucune exposition | Gratuit | ⭐⭐⭐ Avancé | ❌ Auto-signé |

**Recommandation débutant** : Commence par le **Scénario 1 (DuckDNS)**, c'est le plus rapide et 100% gratuit.

---

### Scénario 1 : DuckDNS (Débutants) - Pas à Pas

#### Étape 1 : Créer un compte DuckDNS (2 min)

1. **Va sur** [duckdns.org](https://www.duckdns.org)

2. **Connecte-toi** avec GitHub, Google, Twitter ou Reddit
   (Pas besoin de créer un nouveau compte)

3. **Crée un sous-domaine** :
   - Dans "domains", tape : `monpi` (ou ce que tu veux)
   - Clic "add domain"
   - Tu obtiens : `monpi.duckdns.org`

4. **Note ton token** (en haut de la page) :
   ```
   token: a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```
   COPIE-LE, tu en auras besoin !

---

#### Étape 2 : Ouvrir les ports sur ta box Internet (5 min)

**Pourquoi ?** Pour que les visiteurs de l'extérieur puissent atteindre ton Pi.

**A. Trouve l'IP locale de ton Pi** :
```bash
hostname -I
```
→ Exemple : `192.168.1.100`

**B. Connecte-toi à ta box** :

| Box | Adresse | Login |
|-----|---------|-------|
| **Freebox** | http://mafreebox.freebox.fr | Mot de passe box |
| **Livebox** | http://192.168.1.1 | admin / clé WiFi (8 premiers caractères) |
| **SFR** | http://192.168.1.1 | admin / mot de passe au dos |
| **Bouygues** | http://192.168.1.254 | admin / mot de passe au dos |

**C. Configure le Port Forwarding** :

Cherche dans les menus :
- Freebox : "Paramètres" → "Mode avancé" → "Redirections de ports"
- Livebox : "Configuration avancée" → "NAT/PAT"
- SFR/Bouygues : "Réseau" → "NAT/PAT"

**Crée 2 redirections** :

| Nom | Port Externe | Port Interne | Protocole | IP Destination |
|-----|--------------|--------------|-----------|----------------|
| HTTP | 80 | 80 | TCP | 192.168.1.100 |
| HTTPS | 443 | 443 | TCP | 192.168.1.100 |

**Sauvegarde** et redémarre la box si demandé.

**D. Vérifie que c'est ouvert** :

Depuis ton téléphone (désactive WiFi, utilise 4G/5G) :
- Va sur [canyouseeme.org](https://canyouseeme.org/)
- Teste le port **80**
- Si "Success" → C'est bon !
- Si "Error" → Revérifie la config box

---

#### Étape 3 : Installer Traefik (5 min)

**Sur ton Raspberry Pi** :

```bash
# Télécharge et exécute le script d'installation
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Le script va te demander** :

1. **Ton sous-domaine DuckDNS** :
   ```
   Enter your DuckDNS subdomain (without .duckdns.org): monpi
   ```

2. **Ton token DuckDNS** :
   ```
   Enter your DuckDNS token: a1b2c3d4-e5f6-7890-abcd-ef1234567890
   ```

3. **Ton email** (pour notifications Let's Encrypt) :
   ```
   Enter your email: toi@example.com
   ```

**Le script va** :
- Créer le dossier `/home/pi/stacks/traefik/`
- Générer la configuration Traefik
- Lancer Traefik dans Docker
- Demander un certificat SSL à Let's Encrypt (1-2 min)
- Configurer DuckDNS pour mettre à jour ton IP automatiquement

**Résultat** :
```
✅ Traefik is running!
✅ SSL certificate obtained
✅ Dashboard available at: https://monpi.duckdns.org/traefik
   Login: admin
   Password: [affiché à l'écran]
```

---

#### Étape 4 : Intégrer Supabase avec Traefik (2 min)

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

**Ce que fait le script** :
- Ajoute les labels Traefik au `docker-compose.yml` de Supabase
- Configure les routes :
  - `/studio` → Supabase Studio
  - `/api` → Supabase REST API
- Redémarre Supabase

---

#### Étape 5 : Tester ! (1 min)

**Depuis n'importe quel navigateur** (même hors de chez toi) :

1. **Supabase Studio** :
   ```
   https://monpi.duckdns.org/studio
   ```
   → Tu dois voir Supabase Studio avec le cadenas vert 🔒

2. **Supabase API** :
   ```
   https://monpi.duckdns.org/api
   ```

3. **Dashboard Traefik** :
   ```
   https://monpi.duckdns.org/traefik
   ```
   Login : `admin` / Password affiché précédemment

🎉 **Félicitations !** Tes webapps sont maintenant accessibles depuis l'extérieur en HTTPS sécurisé !

---

### Scénario 2 : Domaine + Cloudflare (Production)

**Pour qui ?** Tu as acheté un domaine (ex: `monpi.fr`) et tu veux des sous-domaines propres.

**Avantages** :
- URLs professionnelles : `studio.monpi.fr`, `api.monpi.fr`
- Sous-domaines illimités
- Protection DDoS Cloudflare (gratuit)
- Fonctionne même derrière CGNAT (avec DNS-01 challenge)

**Étapes résumées** :

1. **Acheter un domaine** (~3-15€/an) :
   - OVH, Gandi, Namecheap, etc.

2. **Créer un compte Cloudflare** (gratuit) :
   - Ajouter ton domaine
   - Changer les nameservers chez ton registrar
   - Récupérer ton API Token

3. **Installer Traefik** :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
   ```

4. **Résultat** :
   ```
   https://studio.monpi.fr   → Supabase Studio
   https://api.monpi.fr      → Supabase API
   https://git.monpi.fr      → Gitea (futur)
   https://monpi.fr          → Homepage (futur)
   ```

**Guide complet** : [SCENARIO-CLOUDFLARE.md](docs/SCENARIO-CLOUDFLARE.md)

---

### Scénario 3 : VPN (Aucune exposition Internet)

**Pour qui ?** Tu ne veux RIEN exposer sur Internet (sécurité maximale).

**Comment ça marche ?**
1. Tu installes un VPN (WireGuard ou Tailscale) sur ton Pi
2. Tu installes le client VPN sur ton téléphone/laptop
3. Tu te connectes au VPN pour accéder à tes services
4. Aucun port ouvert sur Internet (sauf le VPN)

**Avantages** :
- Sécurité maximale (rien n'est exposé publiquement)
- Pas besoin de domaine

**Inconvénients** :
- Certificats auto-signés (warning dans le navigateur)
- Doit installer VPN sur chaque appareil
- Plus complexe

**Guide complet** : [SCENARIO-VPN.md](docs/SCENARIO-VPN.md)

---

## 🛠️ Cas d'Usage Complets

### Exemple 1 : Exposer un nouveau service (Portainer)

Tu viens d'installer Portainer et tu veux y accéder via Traefik.

**Ajoute ces labels au `docker-compose.yml` de Portainer** :

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    ports:
      - "9000:9000"  # Tu peux enlever cette ligne (Traefik s'en occupe)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data
    labels:
      # Active Traefik pour ce container
      - "traefik.enable=true"

      # Route : https://monpi.duckdns.org/portainer
      - "traefik.http.routers.portainer.rule=PathPrefix(`/portainer`)"
      - "traefik.http.routers.portainer.entrypoints=websecure"
      - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"

      # Service : port interne de Portainer
      - "traefik.http.services.portainer.loadbalancer.server.port=9000"

      # Middleware : enlève "/portainer" avant de passer à Portainer
      - "traefik.http.middlewares.portainer-strip.stripprefix.prefixes=/portainer"
      - "traefik.http.routers.portainer.middlewares=portainer-strip"
```

**Redémarre Portainer** :
```bash
cd ~/stacks/portainer
docker compose down && docker compose up -d
```

**Teste** :
```
https://monpi.duckdns.org/portainer
```

🎉 **Portainer est maintenant accessible via Traefik !**

---

### Exemple 2 : Exposer avec un sous-domaine (Cloudflare)

Si tu utilises le Scénario 2 (Cloudflare), tu peux avoir des sous-domaines propres.

**Pour Portainer avec sous-domaine** :

```yaml
labels:
  - "traefik.enable=true"

  # Route : https://portainer.monpi.fr (sous-domaine entier)
  - "traefik.http.routers.portainer.rule=Host(`portainer.monpi.fr`)"
  - "traefik.http.routers.portainer.entrypoints=websecure"
  - "traefik.http.routers.portainer.tls.certresolver=letsencrypt"

  # Service
  - "traefik.http.services.portainer.loadbalancer.server.port=9000"

  # Pas besoin de stripprefix avec un sous-domaine !
```

**Résultat** :
```
https://portainer.monpi.fr → Portainer
(URL beaucoup plus propre qu'avec /portainer)
```

---

### Exemple 3 : Ajouter une authentification basique

Tu veux protéger le Dashboard Traefik avec un mot de passe.

**Générer le hash du mot de passe** :

```bash
# Remplace "monmotdepasse" par ton mot de passe
htpasswd -nb admin monmotdepasse
```

Résultat :
```
admin:$apr1$xyz...
```

**Ajouter le middleware dans `~/stacks/traefik/dynamic/middlewares.yml`** :

```yaml
http:
  middlewares:
    auth:
      basicAuth:
        users:
          - "admin:$apr1$xyz..."  # Copie le résultat de htpasswd
```

**Appliquer à un service** :

```yaml
labels:
  - "traefik.http.routers.mon-service.middlewares=auth"
```

**Résultat** :
- Quand tu visites le service, une popup demande login/password
- Login : `admin`
- Password : `monmotdepasse`

---

## 📊 Quand utiliser Traefik vs autres solutions ?

| Besoin | Traefik | Nginx Proxy Manager | Caddy |
|--------|---------|---------------------|-------|
| **Débutant Docker** | ✅ Parfait (auto-détecte containers) | ✅ Bon (UI graphique) | ⭐ Moyen (config manuelle) |
| **HTTPS auto** | ✅ Let's Encrypt intégré | ✅ Let's Encrypt intégré | ✅ HTTPS automatique |
| **Dashboard** | ✅ Intégré | ✅ UI complète | ❌ Pas de dashboard |
| **Config automatique** | ✅ Docker labels | ❌ Config manuelle UI | ❌ Fichier Caddyfile |
| **Performances** | ✅ Excellent | ✅ Bon | ✅ Excellent |
| **Communauté** | ✅ Très active | ✅ Active | ⭐ Moyenne |

**Traefik est idéal si** :
- Tu utilises Docker (détection automatique des containers)
- Tu veux de l'HTTPS automatique
- Tu veux une config "Infrastructure as Code" (labels dans docker-compose)
- Tu veux apprendre un outil professionnel (utilisé par des millions d'apps)

**Nginx Proxy Manager est mieux si** :
- Tu préfères une UI graphique (point-and-clic)
- Tu débutes et veux quelque chose de visuel
- Tu ne veux pas toucher de YAML

**Caddy est mieux si** :
- Tu veux le setup le plus simple possible (1 fichier config)
- Tu n'as pas besoin de features avancées

---

## 🎓 Apprendre par la pratique

### Tutoriels recommandés

1. **[Traefik Quick Start](https://doc.traefik.io/traefik/getting-started/quick-start/)** - Officiel - 10 min
2. **[Traefik + Docker Tutorial](https://www.smarthomebeginner.com/traefik-docker-compose-guide-2022/)** - Smarthomebeginner - 45 min
3. **"Traefik in 100 Seconds"** - Fireship (YouTube) - 2 min

### Projets débutants recommandés

**Niveau 1 - Facile** (30 min - 1h)
- [ ] Installer Traefik avec DuckDNS
- [ ] Exposer Supabase Studio via Traefik
- [ ] Ajouter Homepage avec une route `/`
- [ ] Consulter le Dashboard Traefik

**Niveau 2 - Intermédiaire** (2-3h)
- [ ] Passer au Scénario 2 (domaine + Cloudflare)
- [ ] Configurer des sous-domaines pour chaque service
- [ ] Ajouter une authentification sur le Dashboard
- [ ] Configurer des middlewares (rate limiting, headers)

**Niveau 3 - Avancé** (1-2 jours)
- [ ] Mettre en place le Scénario 3 (VPN)
- [ ] Configurer Fail2ban avec Traefik
- [ ] Créer des middlewares personnalisés (géolocalisation, IP whitelist)
- [ ] Monitorer Traefik avec Prometheus/Grafana
- [ ] Mettre en place du load balancing (plusieurs instances d'un service)

---

## 🔧 Commandes Utiles

### Voir les logs Traefik
```bash
# Logs en temps réel
docker logs traefik -f

# Dernières 50 lignes
docker logs traefik --tail 50

# Chercher une erreur spécifique
docker logs traefik | grep "ERROR"
```

### Vérifier que Traefik fonctionne
```bash
# Voir tous les containers
docker ps

# Traefik doit être "Up" et "healthy"
docker ps | grep traefik
```

### Redémarrer Traefik
```bash
docker restart traefik

# Ou si tu veux tout redémarrer proprement
cd ~/stacks/traefik
docker compose down && docker compose up -d
```

### Forcer le renouvellement du certificat SSL
```bash
# Supprimer le certificat existant
rm ~/stacks/traefik/acme.json
touch ~/stacks/traefik/acme.json
chmod 600 ~/stacks/traefik/acme.json

# Redémarrer Traefik (il redemandera un certificat)
docker restart traefik
```

### Voir la configuration détectée par Traefik
```bash
# Afficher tous les routers et services détectés
docker exec traefik traefik healthcheck

# Voir les labels d'un container spécifique
docker inspect supabase-studio | grep traefik
```

### Tester la résolution DNS
```bash
# Vérifier que ton domaine pointe vers ton IP
nslookup monpi.duckdns.org

# Résultat attendu :
# Address: 86.245.123.45 (ton IP publique)
```

### Vérifier les ports ouverts
```bash
# Sur le Pi
sudo netstat -tulpn | grep -E '80|443'

# Résultat attendu :
# tcp6  0  0  :::80   :::*  LISTEN  12345/docker-proxy
# tcp6  0  0  :::443  :::*  LISTEN  12346/docker-proxy
```

---

## 🆘 Problèmes Courants

### "ERR_SSL_PROTOCOL_ERROR" ou "Connexion non sécurisée"

**Cause** : Certificat SSL pas encore généré ou invalide.

**Vérifications** :
1. Vérifier que Traefik a bien demandé le certificat :
   ```bash
   docker logs traefik | grep -i "certificate"
   ```

2. Vérifier que `acme.json` contient des données :
   ```bash
   cat ~/stacks/traefik/acme.json
   ```
   Si vide ou `{}` → Certificat pas généré

3. Vérifier que les ports 80 et 443 sont bien ouverts sur la box

4. Attendre 2-3 minutes (Let's Encrypt peut être lent)

**Solution** :
```bash
# Relancer Traefik
docker restart traefik

# Vérifier logs en direct
docker logs traefik -f

# Chercher des erreurs comme :
# - "Unable to obtain ACME certificate"
# - "Invalid response from http://monpi.duckdns.org/.well-known/..."
```

**Causes fréquentes** :
- Ports 80/443 fermés sur la box → Ouvre-les
- DNS pas propagé → Attends 5-10 min
- Rate limit Let's Encrypt → Attends 1h (max 5 certificats/heure)

---

### "404 - Backend not found"

**Cause** : Traefik ne trouve pas le service (labels Docker manquants ou incorrects).

**Vérifications** :
1. Vérifier que le container a bien les labels Traefik :
   ```bash
   docker inspect supabase-studio | grep "traefik"
   ```

2. Vérifier que le container est sur le même réseau Docker que Traefik :
   ```bash
   docker network inspect traefik-network
   ```

**Solution** :
```bash
# Relancer le script d'intégration Supabase
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash

# Ou ajouter manuellement les labels (voir section "Cas d'usage")
```

---

### "DNS not resolving" (nslookup ne trouve pas le domaine)

**Cause** : DNS pas configuré ou pas propagé.

**Test** :
```bash
nslookup monpi.duckdns.org
```

**Si "server can't find..."** :

**Pour DuckDNS** :
1. Vérifier que le container DuckDNS tourne :
   ```bash
   docker ps | grep duckdns
   ```

2. Vérifier les logs DuckDNS :
   ```bash
   docker logs duckdns
   ```
   Doit afficher : `OK` (mise à jour réussie)

3. Forcer la mise à jour manuelle :
   ```bash
   curl "https://www.duckdns.org/update?domains=monpi&token=TON_TOKEN&ip="
   ```

**Pour Cloudflare** :
1. Vérifier l'enregistrement DNS dans Cloudflare Dashboard
2. Vérifier que tu as bien changé les nameservers chez ton registrar
3. Attendre la propagation (peut prendre jusqu'à 48h, généralement 10-30 min)

---

### "502 Bad Gateway"

**Cause** : Traefik ne peut pas joindre le service backend.

**Vérifications** :
1. Le service tourne bien ?
   ```bash
   docker ps | grep supabase-studio
   ```

2. Le port est correct dans les labels ?
   ```bash
   docker inspect supabase-studio | grep "loadbalancer.server.port"
   ```

3. Le service écoute bien sur le port indiqué ?
   ```bash
   docker exec supabase-studio netstat -tulpn
   ```

**Solution** :
- Redémarre le service :
  ```bash
  docker restart supabase-studio
  ```

- Vérifie les logs du service :
  ```bash
  docker logs supabase-studio
  ```

---

### "Je suis derrière CGNAT, ça ne marche pas"

**Symptôme** : Ton IP publique change constamment ou commence par `100.x.x.x`.

**Explication** : Ton FAI utilise CGNAT, tu n'as pas d'IP publique directe.

**Solutions** :
1. **Contacter ton FAI** pour demander une IPv4 publique (parfois gratuit, parfois 5€/mois)

2. **Utiliser Cloudflare Tunnel** (gratuit, pas besoin d'IP publique) :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare-tunnel.sh | sudo bash
   ```

3. **Passer au Scénario 3 (VPN)** → [SCENARIO-VPN.md](docs/SCENARIO-VPN.md)

---

### "Rate limit exceeded" (Let's Encrypt)

**Cause** : Trop de demandes de certificats en peu de temps.

**Limites Let's Encrypt** :
- 5 certificats identiques par semaine
- 50 certificats par domaine par semaine

**Solution** :
- Attends 1 heure avant de réessayer
- Évite de relancer le script plusieurs fois
- Utilise le staging environment pour tester :

  Dans `~/stacks/traefik/traefik.yml` :
  ```yaml
  certificatesResolvers:
    letsencrypt:
      acme:
        caServer: https://acme-staging-v02.api.letsencrypt.org/directory  # Staging
  ```

---

## 📚 Ressources pour Débutants

### Documentation

- **[Traefik Docs](https://doc.traefik.io/traefik/)** - Documentation officielle (excellent)
- **[Let's Encrypt Docs](https://letsencrypt.org/docs/)** - Comprendre les certificats SSL
- **[DuckDNS Docs](https://www.duckdns.org/spec.jsp)** - Doc DuckDNS
- **[Reverse Proxy Explained](https://www.cloudflare.com/learning/cdn/glossary/reverse-proxy/)** - Cloudflare Learning Center

### Vidéos YouTube

- "What is a Reverse Proxy?" - ByteByteGo (8 min) - [EN]
- "Traefik Tutorial" - TechnoTim (20 min) - [EN]
- "HTTPS explained with carrier pigeons" - Art of the Problem (3 min) - [EN]
- "Let's Encrypt explained" - Computerphile (10 min) - [EN]

### Communautés

- [r/Traefik](https://reddit.com/r/Traefik) - Reddit (très actif)
- [Traefik Discord](https://discord.gg/traefik) - Support communautaire
- [r/selfhosted](https://reddit.com/r/selfhosted) - Communauté self-hosting
- [GitHub Discussions](https://github.com/traefik/traefik/discussions) - Questions techniques

### Outils en ligne

- [SSL Labs](https://www.ssllabs.com/ssltest/) - Tester la qualité de ton SSL
- [Can You See Me](https://canyouseeme.org/) - Vérifier si tes ports sont ouverts
- [What's My DNS](https://www.whatsmydns.net/) - Vérifier propagation DNS

---

## 🎯 Prochaines Étapes

Une fois à l'aise avec Traefik :

1. **Installer Homepage** (portail d'accueil pour tous tes services) :
   ```bash
   curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-homepage-stack/scripts/01-homepage-deploy.sh | sudo bash
   ```
   → Voir [Phase 2b de la Roadmap](../ROADMAP.md#phase-2b)

2. **Ajouter Monitoring** (Grafana + Prometheus) → [Phase 3](../ROADMAP.md#phase-3)

3. **Installer Gitea** (GitHub self-hosted) → [Phase 5](../ROADMAP.md#phase-5)

4. **Sécuriser avec Fail2ban** (bloquer les attaques bruteforce)

5. **Créer des middlewares personnalisés** (rate limiting, géo-blocking, etc.)

---

## ✅ Checklist Maîtrise Traefik

**Niveau Débutant** :
- [ ] Je comprends c'est quoi un reverse proxy
- [ ] Je sais ce que fait HTTPS et pourquoi c'est important
- [ ] J'ai installé Traefik avec DuckDNS
- [ ] J'ai exposé Supabase via Traefik
- [ ] Je peux accéder à mes services depuis l'extérieur en HTTPS

**Niveau Intermédiaire** :
- [ ] Je sais ajouter des labels Docker pour exposer un nouveau service
- [ ] Je comprends la différence entre sous-domaines et sous-chemins
- [ ] J'ai configuré un domaine personnel avec Cloudflare
- [ ] Je sais consulter les logs Traefik pour débugger
- [ ] J'ai ajouté une authentification basique sur un service

**Niveau Avancé** :
- [ ] J'ai créé des middlewares personnalisés
- [ ] Je sais configurer du load balancing (plusieurs instances)
- [ ] J'ai mis en place Fail2ban avec Traefik
- [ ] Je comprends les différents types de challenges ACME (HTTP-01, DNS-01)
- [ ] J'ai configuré des headers de sécurité avancés (HSTS, CSP, etc.)
- [ ] Je monitore Traefik avec Prometheus/Grafana

---

**Besoin d'aide ?** Consulte les [guides par scénario](docs/) ou pose tes questions sur [r/Traefik](https://reddit.com/r/Traefik) !

🎉 **Bon reverse proxying !**
