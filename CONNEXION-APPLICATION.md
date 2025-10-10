# 🔌 Guide de Connexion d'une Application à Supabase sur Pi

> **Objectif** : Connecter votre application hébergée (ou locale) à votre instance Supabase auto-hébergée sur Raspberry Pi 5

---

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :

- ✅ Supabase installé et fonctionnel sur votre Pi
- ✅ Accès SSH à votre Pi
- ✅ Une application web existante (ou en développement)

---

## 🎯 Étape 1 : Déterminer Votre Scénario

### Option A : Application Hébergée Ailleurs → Supabase sur Pi

**Architecture :**
```
[App sur Vercel/Netlify]  →  Internet  →  [Pi à la maison]
     Frontend                HTTPS           Backend Supabase
```

**✅ Avantages :**
- Déploiement immédiat (juste changer les variables d'environnement)
- Frontend rapide (CDN global)
- Pas besoin de rebuild l'app
- Séparation frontend/backend (architecture moderne)

**❌ Inconvénients :**
- Latence accrue (requêtes passent par Internet)
- Nécessite exposition publique du Pi (HTTPS obligatoire)
- Dépendance à deux services (Vercel ET Pi)
- Bande passante upload sollicitée

**👉 Choisir si :**
- Vous avez déjà une app en production
- Vous voulez tester rapidement
- Vous avez besoin de performance frontend globale
- Architecture JAMStack (Frontend statique + API)

---

### Option B : Application Complète sur le Pi

**Architecture :**
```
[Navigateur]  →  Internet  →  [Pi : Frontend + Backend]
                HTTPS           Tout sur place
```

**✅ Avantages :**
- Latence minimale (frontend et backend au même endroit)
- Full contrôle et indépendance
- Pas de coûts externes (tout gratuit après achat du Pi)
- Monitoring unifié (tout dans Grafana)

**❌ Inconvénients :**
- Performance frontend limitée (pas de CDN)
- Plus complexe à setup (Docker pour l'app + Supabase)
- Rebuild/redéploiement nécessaire pour updates

**👉 Choisir si :**
- App interne / usage personnel / équipe locale
- Vous voulez tout self-hosted
- Données sensibles (santé, finance, etc.)
- Apprentissage DevOps complet

---

## 🔍 Étape 2 : Collecte d'Informations

### 2.1 Informations sur Votre Application

Notez les informations suivantes :

**Hébergement actuel :**
- [ ] Vercel
- [ ] Netlify
- [ ] Localhost (développement)
- [ ] Autre : _______________

**Framework utilisé :**
- [ ] Next.js
- [ ] React (Create React App / Vite)
- [ ] Vue.js / Nuxt
- [ ] Autre : _______________

**Nombre d'utilisateurs prévus :**
- [ ] Personnel (1-5 utilisateurs)
- [ ] Équipe (5-50 utilisateurs)
- [ ] Public (50+ utilisateurs)

---

### 2.2 État de Traefik sur le Pi

Vérifiez si Traefik est installé :

```bash
docker ps | grep traefik
```

**Résultat :**
- [ ] ✅ Traefik est installé
- [ ] ❌ Traefik n'est pas installé (passage à l'étape 3 requis)

**Si installé, quel scénario ?**
- [ ] DuckDNS (gratuit, chemins `/studio`, `/api`)
- [ ] Cloudflare (domaine perso, sous-domaines)
- [ ] VPN (accès local seulement)

---

### 2.3 Récupération des Credentials Supabase

**🎯 Méthode Recommandée : Script Automatique**

Exécutez ce script qui affichera automatiquement TOUS vos credentials formatés pour Lovable/Vercel/Next.js :

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/get-supabase-credentials.sh | bash
```

**Le script affichera :**
- ✅ URL Supabase complète (avec HTTPS si Traefik installé)
- ✅ ANON_KEY (pour le client)
- ✅ SERVICE_ROLE_KEY (pour le backend)
- ✅ Variables prêtes à copier-coller pour Lovable.ai, Vercel, Netlify, Next.js
- ✅ URLs d'accès (Studio, Dashboard Traefik)
- ✅ Mots de passe Dashboard si disponibles

**💡 Astuce :** Ce script détecte automatiquement si vous avez :
- Traefik DuckDNS → Affiche `https://votre-domaine.duckdns.org/api`
- Traefik Cloudflare → Affiche `https://api.votre-domaine.com`
- Pas de Traefik → Affiche l'IP locale `http://192.168.X.X:8001`

---

**Alternative : Commande Manuelle**

Si vous préférez extraire manuellement les credentials :

```bash
# Chemin Supabase (ajuster si nécessaire)
SUPABASE_DIR="/home/pi/stacks/supabase"

# Afficher ANON_KEY
grep "^ANON_KEY=" $SUPABASE_DIR/.env | cut -d'=' -f2

# Afficher SERVICE_ROLE_KEY
grep "^SERVICE_ROLE_KEY=" $SUPABASE_DIR/.env | cut -d'=' -f2
```

⚠️ **Important** : La `SERVICE_ROLE_KEY` contourne toutes les règles de sécurité. Ne l'utilisez JAMAIS côté client !

---

## 🚀 Étape 3 : Configuration selon Votre Scénario

### Scénario A : Application Hébergée Ailleurs

#### 3.A.1 : Vérifier/Installer Traefik (si pas déjà fait)

**Si Traefik n'est pas installé**, choisissez un scénario :

**🟢 Option 1 : DuckDNS (Gratuit, Débutants)**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-duckdns.sh | sudo bash
```

**Puis intégrer Supabase :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

**🔵 Option 2 : Cloudflare (Domaine Perso, Production)**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-cloudflare.sh | sudo bash
```

**Puis intégrer Supabase :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

**🟡 Option 3 : VPN (Accès Sécurisé, Pas d'Exposition Publique)**

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/01-traefik-deploy-vpn.sh | sudo bash
```

**Puis intégrer Supabase :**
```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-traefik-stack/scripts/02-integrate-supabase.sh | sudo bash
```

---

#### 3.A.2 : Déterminer Votre URL Supabase

Selon votre configuration Traefik :

**DuckDNS :**
```
SUPABASE_URL=https://votre-domaine.duckdns.org/api
```

**Cloudflare :**
```
SUPABASE_URL=https://api.votre-domaine.com
# OU
SUPABASE_URL=https://supabase.votre-domaine.com
```

**VPN :**
```
SUPABASE_URL=http://192.168.X.X:8000
# OU
SUPABASE_URL=http://supabase.pi.local:8000
```

---

#### 3.A.3 : Configurer les Variables d'Environnement

**Pour Next.js / React / Vue :**

Ajoutez dans votre fichier `.env` (ou `.env.local`) :

```bash
# URL de votre Supabase sur Pi
NEXT_PUBLIC_SUPABASE_URL=https://votre-url-ici
NEXT_PUBLIC_SUPABASE_ANON_KEY=votre-anon-key-ici

# Pour Vite (React/Vue)
VITE_SUPABASE_URL=https://votre-url-ici
VITE_SUPABASE_ANON_KEY=votre-anon-key-ici
```

---

**Pour Vercel (via Dashboard) :**

1. Allez dans **Settings** → **Environment Variables**
2. Ajoutez :
   - `NEXT_PUBLIC_SUPABASE_URL` : `https://votre-url-ici`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` : `votre-anon-key-ici`
3. Redéployez votre application

---

**Pour Netlify (via Dashboard) :**

1. Allez dans **Site settings** → **Environment variables**
2. Ajoutez :
   - `NEXT_PUBLIC_SUPABASE_URL` : `https://votre-url-ici`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY` : `votre-anon-key-ici`
3. Redéployez votre application

---

#### 3.A.4 : Tester la Connexion

**Test depuis votre navigateur (Console DevTools) :**

```javascript
// Créez un client Supabase
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'https://votre-url-ici',
  'votre-anon-key-ici'
)

// Test de connexion
const { data, error } = await supabase.from('_table_inexistante').select('*')

// Si erreur = "relation "_table_inexistante" does not exist"
// ✅ Connexion OK !

// Si erreur = "Failed to fetch" ou "Network error"
// ❌ Problème de connexion/CORS
```

---

### Scénario B : Application sur le Pi

#### 3.B.1 : Dockeriser Votre Application (si pas déjà fait)

**Exemple pour Next.js :**

Créez un fichier `Dockerfile` à la racine de votre projet :

```dockerfile
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
ENV PORT 3000

CMD ["node", "server.js"]
```

**Buildez l'image :**

```bash
docker build -t mon-app:latest .
```

---

#### 3.B.2 : Créer un Docker Compose

Créez `/home/mon-app/docker-compose.yml` :

```yaml
version: '3.8'

services:
  mon-app:
    image: mon-app:latest
    container_name: mon-app
    restart: unless-stopped
    environment:
      # Variables Supabase (localhost car même réseau Docker)
      NEXT_PUBLIC_SUPABASE_URL: http://kong:8000
      NEXT_PUBLIC_SUPABASE_ANON_KEY: ${ANON_KEY}
    networks:
      - traefik
      - supabase_default
    labels:
      # Configuration Traefik
      - "traefik.enable=true"
      - "traefik.http.routers.mon-app.rule=Host(`app.votre-domaine.com`)"
      - "traefik.http.routers.mon-app.entrypoints=websecure"
      - "traefik.http.routers.mon-app.tls.certresolver=letsencrypt"
      - "traefik.http.services.mon-app.loadbalancer.server.port=3000"

networks:
  traefik:
    external: true
  supabase_default:
    external: true
```

---

#### 3.B.3 : Créer un Fichier .env

Créez `/home/mon-app/.env` :

```bash
# Récupérez l'ANON_KEY depuis Supabase
ANON_KEY=votre-anon-key-ici
```

---

#### 3.B.4 : Déployer l'Application

```bash
cd /home/mon-app
docker compose up -d
```

---

#### 3.B.5 : Vérifier le Déploiement

```bash
# Voir les logs
docker compose logs -f mon-app

# Vérifier que le container tourne
docker ps | grep mon-app

# Tester l'accès
curl -I https://app.votre-domaine.com
```

---

## 🛠️ Troubleshooting

### Erreur : "Failed to fetch" ou "Network error"

**Causes possibles :**

1. **Firewall bloque le port**
   ```bash
   # Sur le Pi, vérifier les ports ouverts
   sudo ufw status

   # Si port 443 fermé, l'ouvrir
   sudo ufw allow 443/tcp
   ```

2. **Traefik n'a pas de certificat SSL**
   ```bash
   # Vérifier les logs Traefik
   docker logs traefik | grep -i certificate
   ```

3. **URL incorrecte**
   ```bash
   # Vérifier la config Kong dans Supabase
   docker exec supabase-kong cat /etc/kong/kong.yml | grep -A 5 "routes:"
   ```

---

### Erreur : "CORS policy blocked"

**Solution :** Ajouter votre domaine dans la config Supabase

```bash
# Éditer le .env de Supabase
nano /home/supabase/docker/.env

# Ajouter votre domaine frontend
ADDITIONAL_REDIRECT_URLS=https://votre-app.vercel.app,https://votre-domaine.com
JWT_AUD=authenticated

# Redémarrer Supabase
cd /home/supabase/docker
docker compose restart
```

---

### Erreur : "Invalid API key"

**Vérifications :**

1. **La clé est bien l'ANON_KEY (pas SERVICE_ROLE_KEY)**
   ```bash
   grep "ANON_KEY" /home/supabase/docker/.env
   ```

2. **Pas d'espaces ou guillemets dans la variable**
   ```javascript
   // ❌ Mauvais
   const key = "eyJhbGc..."

   // ✅ Bon
   const key = 'eyJhbGc...'
   ```

3. **Variable d'environnement bien chargée**
   ```javascript
   console.log('URL:', process.env.NEXT_PUBLIC_SUPABASE_URL)
   console.log('Key:', process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)
   ```

---

### Erreur : "relation does not exist"

**C'est normal !** Cela signifie que :
- ✅ La connexion à Supabase fonctionne
- ❌ Mais la table n'existe pas encore

**Solution :** Créez vos tables via Supabase Studio

```
https://votre-domaine.duckdns.org/studio
# OU
https://studio.votre-domaine.com
```

---

### Erreur : "403 Forbidden" ou "permission denied for table XXX" 🆕

**Cause :** Row Level Security (RLS) activé sans policies configurées

**Symptôme typique :**
```javascript
// Console navigateur
Error: {
  "code": "42501",
  "message": "permission denied for table users"
}
```

**✅ Solutions :**

**Option 1 : Diagnostic rapide**
```bash
# Sur le Pi
cd ~/stacks/supabase
./scripts/utils/diagnose-rls.sh users  # Remplacer 'users' par votre table
```

**Option 2 : Application automatique de policies basiques**
```bash
# Applique policies user-based sur toutes les tables
./scripts/utils/setup-rls-policies.sh

# Ou sur une table spécifique
./scripts/utils/setup-rls-policies.sh --table users
```

**Option 3 : Créer des policies personnalisées**
```bash
# Générer un template adapté
./scripts/utils/generate-rls-template.sh users --basic           # user_id based
./scripts/utils/generate-rls-template.sh posts --public-read     # lecture publique
./scripts/utils/generate-rls-template.sh invites --email         # email based
./scripts/utils/generate-rls-template.sh projects --team         # team based

# Éditer le template si nécessaire
nano rls-policies-users-basic.sql

# Appliquer
./scripts/utils/setup-rls-policies.sh --custom rls-policies-users-basic.sql
```

**📖 Documentation complète RLS** : [01-infrastructure/supabase/scripts/utils/RLS-TOOLS-README.md](01-infrastructure/supabase/scripts/utils/RLS-TOOLS-README.md)

**Exemples de policies courantes :**

```sql
-- Users peuvent voir leurs propres données
CREATE POLICY "Users can view own data"
ON public.users FOR SELECT TO authenticated
USING (id = auth.uid());

-- Lecture publique, écriture privée (blogs, forums)
CREATE POLICY "Anyone can read posts"
ON public.posts FOR SELECT TO public
USING (true);

CREATE POLICY "Users can create own posts"
ON public.posts FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

-- Policies basées sur email (invitations)
CREATE POLICY "Users view own invites"
ON public.email_invites FOR SELECT TO authenticated
USING (email = (auth.jwt() ->> 'email'));
```

---

## 📚 Ressources Supplémentaires

### Documentation des Stacks

- **[Traefik Stack](pi5-traefik-stack/README.md)** - Configuration reverse proxy
- **[Supabase Stack](pi5-supabase-stack/README.md)** - Configuration backend
- **[Guide Traefik Débutant](pi5-traefik-stack/GUIDE-DEBUTANT.md)** - Comprendre Traefik
- **[Comparaison Scénarios](pi5-traefik-stack/docs/SCENARIOS-COMPARISON.md)** - Quel scénario choisir

### Exemples de Code

**Client Supabase Next.js :**
```typescript
// lib/supabase.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Client Supabase React (Vite) :**
```javascript
// src/lib/supabase.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**Client Supabase Vue.js :**
```javascript
// src/plugins/supabase.js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

---

## ✅ Checklist de Connexion

### Avant de Commencer
- [ ] Supabase installé et fonctionnel sur le Pi
- [ ] Accès SSH au Pi disponible
- [ ] Application web existante (ou en développement)

### Configuration Traefik
- [ ] Traefik installé (DuckDNS, Cloudflare ou VPN)
- [ ] Certificat SSL valide (vérifier avec `curl -I https://...`)
- [ ] Supabase intégré à Traefik (`02-integrate-supabase.sh`)

### Credentials Récupérés
- [ ] `API_EXTERNAL_URL` notée
- [ ] `ANON_KEY` notée
- [ ] `SERVICE_ROLE_KEY` notée (mais pas utilisée côté client !)

### Configuration Application
- [ ] Variables d'environnement ajoutées
- [ ] Application redéployée (Vercel/Netlify) OU rebuild local
- [ ] Test de connexion effectué

### Vérifications Finales
- [ ] Connexion fonctionne (test console navigateur)
- [ ] Pas d'erreurs CORS
- [ ] Supabase Studio accessible
- [ ] Tables créées (si nécessaire)

---

## 🔧 Développement Local : Configuration CORS

### Problème : Erreur CORS en Développement Local

Si vous développez en local (`localhost:8080`, `localhost:5173`, etc.) et que vous voyez cette erreur :

```
Access to fetch at 'http://192.168.X.X:8001/auth/v1/...' from origin 'http://localhost:8080'
has been blocked by CORS policy
```

### Solution : Script Automatique

Utilisez le script `configure-cors-localhost.sh` pour autoriser votre localhost :

```bash
# Sur le Pi (via SSH)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/supabase/scripts/configure-cors-localhost.sh | sudo bash -s -- 8080
```

**Ou avec un port personnalisé :**
```bash
# Si votre app tourne sur le port 5173 (Vite)
curl -fsSL https://raw.githubusercontent.com/.../ configure-cors-localhost.sh | sudo bash -s -- 5173
```

**Le script va automatiquement :**
- ✅ Créer un backup de votre configuration
- ✅ Ajouter les URLs localhost autorisées
- ✅ Configurer CORS pour `localhost:8080`, `localhost:5173`, `localhost:3000`
- ✅ Ajouter les variations IP locale (`192.168.X.X`)
- ✅ Redémarrer les services Supabase (Kong + Auth)

**Configuration dans votre `.env.local` :**
```bash
# Pour développement LOCAL uniquement
VITE_SUPABASE_URL=http://192.168.1.74:8001
VITE_SUPABASE_ANON_KEY=votre-anon-key

# ⚠️ Utilisez HTTP (pas HTTPS) pour connexion locale
```

### Rollback

Si vous devez annuler la configuration CORS :

```bash
# Sur le Pi
cd /home/pi/stacks/supabase
sudo cp backups/.env.backup-YYYYMMDD_HHMMSS .env
docker compose restart kong auth
```

---

## 🆘 Support

Si vous rencontrez des problèmes :

1. **Vérifiez les logs :**
   ```bash
   # Traefik
   docker logs traefik

   # Supabase Kong
   docker logs supabase-kong

   # Votre app (si sur Pi)
   docker logs mon-app
   ```

2. **Testez la connectivité :**
   ```bash
   # Depuis le Pi
   curl -I https://votre-domaine.com/api/health

   # Depuis votre machine
   curl -I https://votre-domaine.com/api/health
   ```

3. **Consultez les guides :**
   - [Troubleshooting Traefik](pi5-traefik-stack/docs/TROUBLESHOOTING.md)
   - [Troubleshooting Supabase](pi5-supabase-stack/docs/04-TROUBLESHOOTING/)

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-10
**Auteur** : [@iamaketechnology](https://github.com/iamaketechnology)
