# 🌐 Architecture Réseau - PI5-SETUP

> **Document technique complet de l'architecture réseau du Raspberry Pi 5**

---

## 📋 Table des Matières

1. [Vue d'Ensemble](#vue-densemble)
2. [Diagramme Réseau Complet](#diagramme-réseau-complet)
3. [Services Publics (Internet)](#services-publics-internet)
4. [Services Localhost (Sécurisés)](#services-localhost-sécurisés)
5. [Services Internes (Docker)](#services-internes-docker)
6. [Flux de Données](#flux-de-données)
7. [Ports & Protocoles](#ports--protocoles)
8. [Sécurité Réseau](#sécurité-réseau)
9. [Troubleshooting](#troubleshooting)

---

## 🎯 Vue d'Ensemble

### **Philosophie de Sécurité**

L'architecture PI5-Setup suit le principe de **Defense in Depth** (Défense en Profondeur) :

```
┌─────────────────────────────────────────────────────────────┐
│ COUCHE 1: Internet (Attaques potentielles)                  │
└──────────────────┬──────────────────────────────────────────┘
                   │ Filtrage DDoS, TLS 1.3
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ COUCHE 2: Traefik Reverse Proxy                             │
│ - HTTPS obligatoire                                          │
│ - Rate limiting                                              │
│ - Headers sécurité                                           │
└──────────────────┬──────────────────────────────────────────┘
                   │ Routage intelligent
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ COUCHE 3: Kong API Gateway                                  │
│ - Validation JWT                                             │
│ - CORS policies                                              │
│ - Request logging                                            │
└──────────────────┬──────────────────────────────────────────┘
                   │ Docker Network (isolé)
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ COUCHE 4: Services Application (PostgREST, GoTrue, etc.)    │
│ - RLS (Row Level Security)                                  │
│ - Business logic                                             │
│ - Aucun port exposé                                          │
└──────────────────┬──────────────────────────────────────────┘
                   │ Localhost UNIQUEMENT
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ COUCHE 5: PostgreSQL (127.0.0.1:5432)                       │
│ - Bind localhost seulement                                  │
│ - Impossible d'accéder depuis Internet                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🗺️ Diagramme Réseau Complet

### **Architecture Globale**

```
                            INTERNET
                               │
                               │ HTTPS (443) / HTTP (80)
                               ▼
                    ┌──────────────────────┐
                    │   Traefik v3         │
                    │   Reverse Proxy      │
                    │   0.0.0.0:80/443     │
                    └──────────┬───────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
┌────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Kong API       │  │ Edge Functions   │  │ Vos Apps         │
│ :8001 (public) │  │ :54321 (public)  │  │ (routes Traefik) │
│                │  │                  │  │                  │
│ JWT validation │  │ Serverless funcs │  │ React/Next.js    │
└───────┬────────┘  └──────────────────┘  └──────────────────┘
        │
        │ Docker Network (supabase_network)
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│              SERVICES INTERNES (Docker)                   │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  PostgREST  │  │   GoTrue     │  │    Realtime     │  │
│  │  REST API   │  │   Auth       │  │    WebSocket    │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
│                                                           │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────┐  │
│  │  Storage    │  │   ImgProxy   │  │    Meta         │  │
│  │  Files      │  │   Images     │  │    Migrations   │  │
│  └─────────────┘  └──────────────┘  └─────────────────┘  │
└─────────────────────────┬─────────────────────────────────┘
                          │
                          │ Localhost UNIQUEMENT (127.0.0.1)
                          ▼
              ┌───────────────────────┐
              │   PostgreSQL 15       │
              │   127.0.0.1:5432      │
              │   ❌ Pas d'accès      │
              │      depuis Internet  │
              └───────────────────────┘

              ┌───────────────────────┐
              │   Supabase Studio     │
              │   127.0.0.1:3000      │
              │   ❌ Pas d'accès      │
              │      depuis Internet  │
              └───────────────────────┘
```

---

### **Services Monitoring & Management**

```
              LOCALHOST UNIQUEMENT (SSH Tunnel requis)
                          │
         ┌────────────────┼────────────────┐
         │                │                │
         ▼                ▼                ▼
┌─────────────────┐  ┌─────────────┐  ┌──────────────┐
│ Supabase Studio │  │ Traefik UI  │  │ Portainer    │
│ 127.0.0.1:3000  │  │ 127.0.0.1:  │  │ 127.0.0.1:   │
│                 │  │ 8081        │  │ 8080         │
│ Admin DB/Users  │  │ Routes      │  │ Docker Mgmt  │
└─────────────────┘  └─────────────┘  └──────────────┘

         PUBLIC (Dashboard)
              │
              ▼
    ┌──────────────────┐
    │ Homepage         │
    │ 0.0.0.0:3001     │
    │                  │
    │ Dashboard        │
    └──────────────────┘
```

---

### **Services Monitoring (Prometheus Stack)**

```
         INTERNES (Docker Network)
                   │
      ┌────────────┼────────────┐
      │            │            │
      ▼            ▼            ▼
┌───────────┐  ┌──────────┐  ┌─────────────┐
│ Grafana   │  │Prometheus│  │ Exporters   │
│ :3000     │  │ :9090    │  │ node/cadvis │
│ (interne) │  │ (interne)│  │ postgres    │
└───────────┘  └──────────┘  └─────────────┘
```

---

## 🌍 Services Publics (Internet)

### **1. Traefik Reverse Proxy**

**Exposition** : `0.0.0.0:80` (HTTP) + `0.0.0.0:443` (HTTPS)

**Rôle** :
- Point d'entrée unique depuis Internet
- Gestion HTTPS automatique (Let's Encrypt)
- Routage par domaine/sous-domaine
- Headers sécurité (HSTS, CSP, etc.)
- Rate limiting (anti-DDoS)

**Exemple de Route** :
```yaml
# votre-domain.duckdns.org → Routage intelligent
https://votre-domain.duckdns.org/           → Homepage
https://votre-domain.duckdns.org/api        → Kong API
https://votre-domain.duckdns.org/functions  → Edge Functions
https://votre-domain.duckdns.org/app        → Votre app
```

**Configuration** :
```yaml
# /home/pi/stacks/traefik/docker-compose.yml
ports:
  - "0.0.0.0:80:80"    # HTTP → redirige vers HTTPS
  - "0.0.0.0:443:443"  # HTTPS
  - "127.0.0.1:8081:8080"  # Dashboard (localhost seulement)
```

**Sécurité** :
- ✅ TLS 1.3 minimum
- ✅ HSTS activé (force HTTPS)
- ✅ Dashboard localhost seulement (8081)

---

### **2. Kong API Gateway (Supabase)**

**Exposition** : `0.0.0.0:8001` (API publique)

**Rôle** :
- Gateway unique vers tous les services Supabase
- Validation JWT (tokens Supabase)
- CORS policies
- Request/Response logging
- Routage vers services internes

**Routes Exposées** :
```bash
# PostgREST (REST API)
http://192.168.1.118:8001/rest/v1/...

# GoTrue (Auth)
http://192.168.1.118:8001/auth/v1/...

# Realtime (WebSocket)
ws://192.168.1.118:8001/realtime/v1/...

# Storage (Files)
http://192.168.1.118:8001/storage/v1/...
```

**Sécurité** :
- ✅ JWT validation obligatoire (sauf routes publiques)
- ✅ Admin API (8444) localhost seulement
- ✅ Rate limiting configuré

---

### **3. Edge Functions (Serverless)**

**Exposition** : `0.0.0.0:54321`

**Rôle** :
- Fonctions serverless Deno
- Logic métier custom
- Intégrations tierces (email, webhooks, etc.)

**Exemple d'Appel** :
```bash
curl -X POST http://192.168.1.118:54321/functions/v1/verify-document \
  -H "Authorization: Bearer YOUR_JWT" \
  -H "Content-Type: application/json" \
  -d '{"documentId":"123"}'
```

**Sécurité** :
- ✅ JWT validation (même tokens que Kong)
- ✅ Variables d'env sécurisées (.env)
- ⚠️ Pas de rate limiting natif (ajouter via Traefik)

---

### **4. Vos Applications (Frontend)**

**Exposition** : Via Traefik (ports dynamiques)

**Exemples** :
```bash
# CertiDoc Frontend
http://192.168.1.118:9000
https://certidoc.votre-domain.duckdns.org

# Homepage Dashboard
http://192.168.1.118:3001
https://votre-domain.duckdns.org/
```

**Sécurité** :
- ✅ HTTPS via Traefik
- ✅ CSP headers configurés
- ✅ SameSite cookies

---

## 🔒 Services Localhost (Sécurisés)

### **1. PostgreSQL (Base de Données)**

**Exposition** : `127.0.0.1:5432` (localhost **UNIQUEMENT**)

**Pourquoi Localhost ?**
- ❌ Si public (`0.0.0.0:5432`) :
  - Attaques brute-force SQL
  - Exploitation failles PostgreSQL
  - Accès direct aux données (bypass RLS)
  - DoS via requêtes lourdes

- ✅ En localhost :
  - Accessible SEULEMENT depuis le Pi
  - Attaquant doit d'abord compromettre SSH
  - Services Docker communiquent via réseau interne

**Accès depuis l'Extérieur** :
```bash
# Via SSH Tunnel
ssh -L 5432:localhost:5432 pi@pi5.local
psql -h localhost -U postgres

# Via VPN (Tailscale)
psql -h 100.64.0.1 -U postgres
```

**Vérification** :
```bash
# Depuis Internet (devrait timeout)
telnet 192.168.1.118 5432
# ❌ Connection timed out (CORRECT)

# Depuis le Pi (devrait fonctionner)
ssh pi@pi5.local
psql -h 127.0.0.1 -U postgres
# ✅ Connecté (CORRECT)
```

---

### **2. Supabase Studio (Interface Admin)**

**Exposition** : `127.0.0.1:3000` (localhost **UNIQUEMENT**)

**Pourquoi Localhost ?**
- ❌ Si public, attaquant peut :
  - Voir TOUTES les données (tables, users)
  - Modifier RLS policies
  - Supprimer tables/buckets
  - Voir API keys
  - Exécuter SQL arbitraire

**Accès depuis l'Extérieur** :
```bash
# Via SSH Tunnel
ssh -L 3000:localhost:3000 pi@pi5.local
# Ouvrir : http://localhost:3000

# Via VPN (Tailscale)
# Ouvrir : http://100.64.0.1:3000
```

---

### **3. Traefik Dashboard**

**Exposition** : `127.0.0.1:8081` (localhost **UNIQUEMENT**)

**Pourquoi Localhost ?**
- Visualise toutes les routes Traefik
- Config reverse proxy
- Stats temps réel

**Accès** :
```bash
ssh -L 8081:localhost:8081 pi@pi5.local
# Ouvrir : http://localhost:8081
```

---

### **4. Portainer (Gestion Docker)**

**Exposition** : ⚠️ **ATTENTION - Actuellement PUBLIC** (`0.0.0.0:8080`)

**RECOMMANDATION** : Passer en localhost

**Correction** :
```bash
cd /home/pi/stacks/portainer
sudo nano docker-compose.yml

# Changer :
ports:
  - "127.0.0.1:8080:9000"  # Au lieu de 0.0.0.0:8080

# Redémarrer
sudo docker compose down && sudo docker compose up -d
```

---

## 🐳 Services Internes (Docker)

Ces services **n'ont AUCUN port exposé** (ni Internet, ni localhost). Communication uniquement via réseau Docker interne (`supabase_network`).

### **PostgREST (REST API auto-générée)**

**Réseau** : `supabase_network`
**Port interne** : `3000` (pas exposé)

**Accès** : Via Kong uniquement

```bash
# ❌ Direct (impossible)
curl http://192.168.1.118:3000/rest/v1/...
# Connection refused

# ✅ Via Kong (fonctionne)
curl http://192.168.1.118:8001/rest/v1/...
```

---

### **GoTrue (Authentification)**

**Réseau** : `supabase_network`
**Port interne** : `9999` (pas exposé)

**Accès** : Via Kong uniquement

---

### **Realtime (WebSocket subscriptions)**

**Réseau** : `supabase_network`
**Port interne** : `4000` (pas exposé)

**Accès** : Via Kong uniquement

---

### **Storage API (Upload/Download fichiers)**

**Réseau** : `supabase_network`
**Port interne** : `5000` (pas exposé)

**Accès** : Via Kong uniquement

---

### **ImgProxy (Transformation images)**

**Réseau** : `supabase_network`
**Port interne** : `8080` (pas exposé)

**Utilisé par** : Storage API (transformations à la volée)

---

### **Meta (Migrations DB)**

**Réseau** : `supabase_network`
**Port interne** : `8080` (pas exposé)

**Rôle** : Gestion migrations Supabase

---

## 🔄 Flux de Données

### **Scénario 1 : Appel API REST depuis une App**

```
┌─────────────────┐
│ App React       │
│ (navigateur)    │
└────────┬────────┘
         │ HTTPS GET /rest/v1/users
         ▼
┌─────────────────┐
│ Traefik:443     │ (Déchiffre HTTPS, route vers Kong)
└────────┬────────┘
         │ HTTP /rest/v1/users + JWT
         ▼
┌─────────────────┐
│ Kong:8001       │ (Valide JWT, route vers PostgREST)
└────────┬────────┘
         │ HTTP /users (réseau Docker interne)
         ▼
┌─────────────────┐
│ PostgREST:3000  │ (Génère requête SQL + RLS)
└────────┬────────┘
         │ SELECT * FROM users WHERE auth.uid() = ...
         ▼
┌─────────────────┐
│ PostgreSQL:5432 │ (Exécute query, retourne données)
└────────┬────────┘
         │ Résultats JSON
         ▼
      (Retour inverse : PostgreSQL → PostgREST → Kong → Traefik → App)
```

---

### **Scénario 2 : Login Utilisateur**

```
┌─────────────────┐
│ App React       │
└────────┬────────┘
         │ POST /auth/v1/token + email/password
         ▼
┌─────────────────┐
│ Traefik:443     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Kong:8001       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ GoTrue:9999     │ (Vérifie credentials)
└────────┬────────┘
         │ Query auth.users
         ▼
┌─────────────────┐
│ PostgreSQL:5432 │
└────────┬────────┘
         │ Retourne user + génère JWT
         ▼
      (Retour : JWT access_token + refresh_token)
```

---

### **Scénario 3 : Upload Fichier**

```
┌─────────────────┐
│ App React       │
└────────┬────────┘
         │ POST /storage/v1/object/documents/file.pdf + JWT
         ▼
┌─────────────────┐
│ Traefik:443     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Kong:8001       │ (Valide JWT)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Storage API:    │ (Vérifie RLS policies sur storage.objects)
│ 5000            │
└────────┬────────┘
         │ INSERT INTO storage.objects
         ▼
┌─────────────────┐
│ PostgreSQL:5432 │ (Sauvegarde metadata)
└─────────────────┘
         │
         ▼ (Fichier binaire stocké sur disque)
      /home/pi/stacks/supabase/volumes/storage/
```

---

## 📊 Ports & Protocoles

### **Table Complète des Ports**

| Port | Service | Proto | Exposition | Sécurité | Notes |
|------|---------|-------|------------|----------|-------|
| **22** | SSH | TCP | 0.0.0.0 | ⚠️ | Porte d'entrée système - CRITIQUE |
| **80** | HTTP | TCP | 0.0.0.0 | ✅ | Redirige vers 443 |
| **443** | HTTPS | TCP | 0.0.0.0 | ✅ | TLS 1.3, HSTS |
| **3000** | Studio | TCP | 127.0.0.1 | ✅ | Admin interface (secured) |
| **3001** | Homepage | TCP | 0.0.0.0 | ✅ | Dashboard public |
| **5432** | PostgreSQL | TCP | 127.0.0.1 | ✅ | Database (secured) |
| **8001** | Kong API | TCP | 0.0.0.0 | ✅ | Supabase API (JWT protected) |
| **8080** | Portainer | TCP | 0.0.0.0 | ⚠️ | SHOULD be 127.0.0.1 |
| **8081** | Traefik UI | TCP | 127.0.0.1 | ✅ | Dashboard (secured) |
| **8444** | Kong Admin | TCP | 127.0.0.1 | ✅ | Admin API (secured) |
| **9000** | CertiDoc | TCP | 0.0.0.0 | ✅ | Frontend app |
| **54321** | Edge Funcs | TCP | 0.0.0.0 | ✅ | Serverless (JWT protected) |

---

### **Protocoles Réseau**

```yaml
HTTP/HTTPS:
  - Port 80 → 443 (redirect)
  - TLS 1.3 (Let's Encrypt)
  - HTTP/2 enabled

WebSocket:
  - Realtime subscriptions (via Kong:8001)
  - Protocole: ws:// ou wss://

PostgreSQL:
  - Protocol: PostgreSQL wire protocol
  - Authentication: SCRAM-SHA-256
  - SSL: Optional (localhost, not required)

Docker:
  - Network: bridge (default) + custom (supabase_network)
  - DNS: Docker embedded DNS (service discovery)
```

---

## 🛡️ Sécurité Réseau

### **1. Firewall (UFW)**

**Status** : À configurer

```bash
# Installer UFW
sudo apt install ufw -y

# Configuration basique
sudo ufw default deny incoming  # Bloquer tout par défaut
sudo ufw default allow outgoing

# Autoriser services essentiels
sudo ufw allow 22/tcp          # SSH
sudo ufw allow 80/tcp          # HTTP
sudo ufw allow 443/tcp         # HTTPS

# Activer
sudo ufw enable

# Vérifier
sudo ufw status verbose
```

---

### **2. Fail2ban (Brute-Force Protection)**

**Status** : À installer

```bash
# Installer
sudo apt install fail2ban -y

# Config SSH
sudo tee /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = 22
maxretry = 5
bantime = 600
findtime = 600
EOF

# Redémarrer
sudo systemctl restart fail2ban

# Vérifier
sudo fail2ban-client status sshd
```

---

### **3. Rate Limiting (Traefik)**

**Config** : `/home/pi/stacks/traefik/traefik.yml`

```yaml
http:
  middlewares:
    rate-limit:
      rateLimit:
        average: 100  # 100 req/sec
        burst: 50     # 50 req burst
        period: 1s
```

---

### **4. Security Headers (Traefik)**

```yaml
http:
  middlewares:
    security-headers:
      headers:
        stsSeconds: 31536000  # HSTS 1 an
        stsIncludeSubdomains: true
        contentTypeNosniff: true
        browserXssFilter: true
        frameDeny: true
        referrerPolicy: "strict-origin-when-cross-origin"
```

---

## 🔧 Troubleshooting

### **Problème : "Cannot connect to Supabase API from Internet"**

**Diagnostic** :
```bash
# Tester depuis Internet
curl http://VOTRE_IP_PUBLIQUE:8001/rest/v1/

# Si timeout :
# 1. Vérifier Kong est accessible en local
ssh pi@pi5.local
curl http://127.0.0.1:8001/rest/v1/

# 2. Vérifier port 8001 écoute sur 0.0.0.0
sudo netstat -tlnp | grep 8001

# 3. Vérifier firewall
sudo ufw status
```

**Solution** :
```bash
# Si Kong écoute sur 127.0.0.1 au lieu de 0.0.0.0 :
cd /home/pi/stacks/supabase
sudo nano docker-compose.yml

# Trouver :
ports:
  - "127.0.0.1:8001:8000"

# Changer en :
ports:
  - "0.0.0.0:8001:8000"

# Redémarrer
sudo docker compose restart kong
```

---

### **Problème : "Cannot access Studio from my Mac"**

**C'est NORMAL** ! Studio est localhost pour sécurité.

**Solution** : SSH Tunnel
```bash
# Sur votre Mac
ssh -L 3000:localhost:3000 pi@pi5.local

# Ouvrir navigateur :
http://localhost:3000
```

---

### **Problème : "Traefik HTTPS ne fonctionne pas"**

**Diagnostic** :
```bash
# Vérifier certificats Let's Encrypt
ssh pi@pi5.local
sudo docker logs traefik | grep "acme"

# Vérifier domaine DuckDNS
curl https://www.duckdns.org/update?domains=VOTRE_SUBDOMAIN&token=VOTRE_TOKEN

# Tester résolution DNS
nslookup votre-subdomain.duckdns.org
```

**Solution** :
```bash
# Si certificat échoue :
# 1. Vérifier ports 80/443 ouverts
sudo ufw status | grep -E "80|443"

# 2. Vérifier domaine pointe vers votre IP
curl ifconfig.me  # IP publique

# 3. Forcer renouvellement certificat
cd /home/pi/stacks/traefik
sudo rm -rf letsencrypt/acme.json
sudo docker compose restart traefik
```

---

### **Problème : "Docker containers cannot communicate"**

**Diagnostic** :
```bash
# Tester communication Kong → PostgREST
docker exec supabase-kong wget -O- http://rest:3000/

# Vérifier réseau Docker
docker network ls
docker network inspect supabase_network
```

**Solution** :
```bash
# Recréer le réseau
cd /home/pi/stacks/supabase
sudo docker compose down
sudo docker network rm supabase_network
sudo docker compose up -d
```

---

## 📚 Ressources

- **Architecture Microservices** : https://microservices.io/patterns/architecture/
- **Docker Networking** : https://docs.docker.com/network/
- **Traefik Documentation** : https://doc.traefik.io/traefik/
- **Kong API Gateway** : https://docs.konghq.com/
- **Supabase Self-Hosting** : https://supabase.com/docs/guides/self-hosting

---

**Dernière mise à jour** : 14 Octobre 2025
**Version** : 1.0.0
**Auteur** : PI5-SETUP Project

---

**Liens Utiles** :
- [SSH Tunneling Guide](SSH-TUNNELING-GUIDE.md)
- [Security Checklist](SECURITY-CHECKLIST.md)
- [Troubleshooting](../01-infrastructure/supabase/docs/troubleshooting/)
