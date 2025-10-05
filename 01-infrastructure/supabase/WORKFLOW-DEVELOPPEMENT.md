# 🚀 Workflow de Développement - Supabase sur Pi 5

> **Guide pratique** : Comment développer et tester vos applications avec Supabase hébergé sur Raspberry Pi 5

---

## 📋 Vue d'Ensemble

Ce guide explique comment connecter votre application en développement (VS Code sur votre ordinateur) avec Supabase hébergé sur votre Raspberry Pi 5.

### Architecture
```
┌─────────────────────┐          ┌──────────────────────┐
│   Ordinateur Dev    │          │   Raspberry Pi 5     │
│                     │          │                      │
│  VS Code            │  ────→   │  Supabase Stack      │
│  localhost:3000     │  Local   │  :8000 (Studio)      │
│  (Next.js/React)    │  Network │  :54321 (API)        │
│                     │          │  :5432 (PostgreSQL)  │
└─────────────────────┘          └──────────────────────┘
```

---

## 🎯 Workflow Optimal

### Phase 1 : Développement Local (Recommandé)

#### ✅ Avantages
- ✅ **Pas besoin de déployer** à chaque modification
- ✅ **Hot reload rapide** (temps réel)
- ✅ **Debug facile** (DevTools + logs locaux)
- ✅ **Gratuit** (pas de domaine/HTTPS nécessaire)

#### Configuration

**1. Variables d'environnement** (`.env.local` ou `.env`) :
```bash
# Backend Supabase sur Pi
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.X:8000  # Remplace X par IP du Pi
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbG...           # Clé récupérée du Pi

# Alternative avec domaine local (optionnel)
# NEXT_PUBLIC_SUPABASE_URL=http://raspberrypi.local:8000
```

**2. Développer normalement** :
```bash
# Démarrer app en mode dev
npm run dev          # Next.js
# ou
npm start            # React/Vue
# ou
yarn dev / pnpm dev  # Autres

# Accès : http://localhost:3000
```

---

### Phase 2 : Déployer en Production (Quand Prêt)

#### Étape 1 : Installer Traefik + HTTPS
```bash
# Sur le Pi - Installer reverse proxy avec domaine gratuit DuckDNS
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/01-traefik-deploy-duckdns.sh | sudo bash

# Intégrer Supabase avec Traefik (HTTPS automatique)
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/01-infrastructure/traefik/scripts/02-integrate-supabase.sh | sudo bash

# Résultat : https://studio.monpi.duckdns.org ✅
```

#### Étape 2 : Déployer votre Application
```bash
# Build production
npm run build

# Copier build sur Pi
scp -r ./dist/* pi@IP_DU_PI:/var/www/monapp/
# ou (Next.js)
scp -r ./.next pi@IP_DU_PI:/var/www/monapp/

# Déployer avec Docker sur Pi
# (Voir GUIDE-DEPLOIEMENT-WEB.md pour détails)
```

---

## 🚀 Quick Start - Tester Maintenant

### Étape 1 : Récupérer Credentials Supabase

**Sur le Raspberry Pi** :
```bash
# SSH sur le Pi
ssh pi@IP_DU_PI

# Afficher les clés d'API
cat ~/supabase/.env | grep ANON_KEY
cat ~/supabase/.env | grep SERVICE_ROLE_KEY

# Ou afficher tout
cat ~/supabase/.env
```

**Exemple de sortie** :
```bash
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24ifQ...
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSJ9...
JWT_SECRET=super-secret-jwt-token-with-at-least-32-characters-long
```

**Trouver l'IP du Pi** :
```bash
# Sur le Pi
hostname -I | awk '{print $1}'
# Exemple : 192.168.1.150
```

---

### Étape 2 : Configurer votre Application

#### Next.js / React / Vue

**Créer fichier `.env.local`** (racine projet) :
```bash
# Backend Supabase
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.150:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Pour production (après config 2)
# NEXT_PUBLIC_SUPABASE_URL=https://studio.monpi.duckdns.org
```

**Client Supabase** (`lib/supabase.js` ou `lib/supabase.ts`) :
```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

**TypeScript** (`lib/supabase.ts`) :
```typescript
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/types/database.types'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient<Database>(supabaseUrl, supabaseAnonKey)
```

---

### Étape 3 : Tests Rapides

#### Test 1 : Connexion Basique
```javascript
// pages/test.jsx (ou components/TestSupabase.jsx)
import { supabase } from '@/lib/supabase'
import { useEffect } from 'react'

export default function TestPage() {
  useEffect(() => {
    async function testConnection() {
      const { data, error } = await supabase
        .from('_test')
        .select('*')
        .limit(1)

      if (error) {
        console.log('Connexion OK (table inexistante normale):', error.message)
      } else {
        console.log('Connexion OK, données:', data)
      }
    }

    testConnection()
  }, [])

  return <div>Check console pour résultats</div>
}
```

#### Test 2 : Authentification
```javascript
// Test signup
const { data, error } = await supabase.auth.signUp({
  email: 'test@example.com',
  password: 'password123456'
})

console.log('Signup:', data, error)

// Test login
const { data: loginData, error: loginError } = await supabase.auth.signInWithPassword({
  email: 'test@example.com',
  password: 'password123456'
})

console.log('Login:', loginData, loginError)
```

#### Test 3 : Base de Données
```javascript
// Créer table (via Supabase Studio ou SQL)
// http://IP_DU_PI:8000 → SQL Editor

// CREATE TABLE posts (
//   id SERIAL PRIMARY KEY,
//   title TEXT NOT NULL,
//   created_at TIMESTAMP DEFAULT NOW()
// );

// Insérer données
const { data, error } = await supabase
  .from('posts')
  .insert({ title: 'Mon premier post' })
  .select()

console.log('Insert:', data, error)

// Lire données
const { data: posts, error: fetchError } = await supabase
  .from('posts')
  .select('*')

console.log('Posts:', posts, fetchError)
```

#### Test 4 : Realtime (WebSocket)
```javascript
// Écouter changements en temps réel
const channel = supabase
  .channel('posts-changes')
  .on(
    'postgres_changes',
    { event: '*', schema: 'public', table: 'posts' },
    (payload) => {
      console.log('Change reçu!', payload)
    }
  )
  .subscribe()

// Cleanup
return () => {
  supabase.removeChannel(channel)
}
```

#### Test 5 : Storage (Fichiers)
```javascript
// Upload fichier
const file = event.target.files[0]
const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`public/${file.name}`, file)

console.log('Upload:', data, error)

// Récupérer URL publique
const { data: urlData } = supabase.storage
  .from('avatars')
  .getPublicUrl(`public/${file.name}`)

console.log('URL:', urlData.publicUrl)
```

---

## 🔧 Configuration Avancée

### 1. Multiples Environnements

**.env.local** (développement) :
```bash
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.150:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...dev-key...
```

**.env.production** (production) :
```bash
NEXT_PUBLIC_SUPABASE_URL=https://studio.monpi.duckdns.org
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...prod-key...
```

---

### 2. Service Role (Admin)

⚠️ **ATTENTION** : Ne JAMAIS exposer `SERVICE_ROLE_KEY` côté client !

**Utilisation côté serveur uniquement** (Next.js API routes, serveur Node.js) :
```javascript
// pages/api/admin.js (Next.js API route)
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY  // Variable serveur uniquement
)

export default async function handler(req, res) {
  // Bypass RLS (Row Level Security)
  const { data, error } = await supabase
    .from('users')
    .select('*')  // Accès admin complet

  res.json({ data, error })
}
```

---

### 3. Row Level Security (RLS)

**Activer RLS sur vos tables** (Supabase Studio) :
```sql
-- Activer RLS
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Policy : Lecture publique
CREATE POLICY "Posts publics en lecture"
  ON posts FOR SELECT
  USING (true);

-- Policy : Écriture authentifiée uniquement
CREATE POLICY "Utilisateurs authentifiés peuvent créer"
  ON posts FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Policy : Utilisateur peut modifier ses posts
CREATE POLICY "Utilisateur peut modifier ses posts"
  ON posts FOR UPDATE
  USING (auth.uid() = user_id);
```

---

### 4. Types TypeScript Auto-générés

**Générer types depuis votre schéma** :
```bash
# Installer CLI Supabase
npm install -D supabase

# Login
npx supabase login

# Link projet
npx supabase link --project-ref your-project-ref

# Générer types
npx supabase gen types typescript --linked > types/database.types.ts
```

**Alternative manuelle** (depuis Pi) :
```bash
# Sur le Pi
docker exec supabase-db pg_dump -s -h localhost -U postgres postgres > schema.sql

# Copier sur ordi dev
scp pi@IP_DU_PI:~/schema.sql ./

# Utiliser https://supabase.com/docs/guides/api/generating-types
```

---

## 🐛 Troubleshooting

### Problème 1 : CORS Error
```
Access to fetch at 'http://192.168.1.150:8000' from origin 'http://localhost:3000'
has been blocked by CORS policy
```

**Solution** : Ajouter origin dans config Supabase
```bash
# Sur le Pi
cd ~/supabase
nano docker-compose.yml

# Modifier GOTRUE_EXTERNAL_URL
environment:
  GOTRUE_SITE_URL: http://localhost:3000
  GOTRUE_ADDITIONAL_REDIRECT_URLS: http://localhost:3000,http://localhost:3001

# Redémarrer
docker-compose restart
```

---

### Problème 2 : Network Unreachable
```
Error: connect ENETUNREACH 192.168.1.150:8000
```

**Solutions** :
```bash
# 1. Vérifier IP du Pi
ping 192.168.1.150

# 2. Vérifier firewall sur Pi
sudo ufw status
sudo ufw allow 8000/tcp

# 3. Vérifier Supabase actif
docker ps | grep supabase

# 4. Utiliser hostname si disponible
# NEXT_PUBLIC_SUPABASE_URL=http://raspberrypi.local:8000
```

---

### Problème 3 : Invalid API Key
```
{"message":"Invalid API key"}
```

**Solution** : Vérifier la clé
```bash
# Sur le Pi
cat ~/supabase/.env | grep ANON_KEY

# Comparer avec .env.local
# Copier-coller EXACTE (pas d'espace, guillemets, etc.)
```

---

### Problème 4 : Auth Redirect Loop
```
Infinite redirect between /login and /
```

**Solution** : Configurer callback URL
```javascript
// Dans supabase client
const supabase = createClient(url, key, {
  auth: {
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: true
  }
})

// Callback URL dans Supabase Studio
// Authentication → URL Configuration
// Site URL: http://localhost:3000
// Redirect URLs: http://localhost:3000/auth/callback
```

---

## 📊 Monitoring & Debug

### Logs Supabase (sur Pi)
```bash
# Voir logs API
docker logs supabase-kong -f --tail 100

# Voir logs Auth
docker logs supabase-auth -f --tail 100

# Voir logs Realtime
docker logs supabase-realtime -f --tail 100

# Voir logs PostgreSQL
docker logs supabase-db -f --tail 100
```

### Performance Network
```bash
# Tester latence
ping 192.168.1.150

# Tester vitesse API
curl -w "\nTime: %{time_total}s\n" http://192.168.1.150:8000/rest/v1/

# Monitoring réseau
sudo iftop -i eth0  # Sur le Pi
```

---

## 🚀 Passage en Production

### Checklist avant déploiement
- [ ] **Variables d'environnement** : Changer URL/keys pour production
- [ ] **RLS activé** : Sur toutes les tables sensibles
- [ ] **Auth configuré** : Redirect URLs, email templates
- [ ] **Storage buckets** : Policies configurées
- [ ] **Backups** : Automatiques activés (`supabase-scheduler.sh`)
- [ ] **HTTPS** : Traefik + DuckDNS/Cloudflare configuré
- [ ] **Monitoring** : Grafana + alertes actives

### Déploiement
```bash
# 1. Build production
npm run build

# 2. Variables production
NEXT_PUBLIC_SUPABASE_URL=https://studio.monpi.duckdns.org
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...prod-key...

# 3. Déployer sur Pi
# (Voir GUIDE-DEPLOIEMENT-WEB.md)
```

---

## 📚 Ressources

### Documentation
- [Supabase Docs](https://supabase.com/docs)
- [Supabase JS Client](https://supabase.com/docs/reference/javascript/introduction)
- [Next.js + Supabase](https://supabase.com/docs/guides/getting-started/quickstarts/nextjs)
- [GUIDE-DEPLOIEMENT-WEB.md](../../GUIDE-DEPLOIEMENT-WEB.md)

### Guides Connexes
- [README.md](README.md) - Documentation Supabase Pi 5
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Problèmes courants
- [INSTALLATION-COMPLETE.md](../../INSTALLATION-COMPLETE.md) - Installation détaillée

### Scripts Utiles
```bash
# Healthcheck Supabase
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-healthcheck.sh

# Backup manuel
~/pi5-setup/01-infrastructure/supabase/scripts/maintenance/supabase-backup.sh

# Diagnostic complet
~/pi5-setup/01-infrastructure/supabase/scripts/utils/diagnostic-supabase-complet.sh
```

---

## 💡 Tips & Best Practices

### Performance
- ✅ Utiliser **Ethernet** sur Pi (plus stable que WiFi)
- ✅ Activer **connection pooling** (pgBouncer déjà configuré)
- ✅ **Indexer** colonnes fréquemment requêtées
- ✅ Utiliser **select()** pour limiter colonnes retournées

### Sécurité
- ✅ **RLS toujours actif** sur tables avec données utilisateurs
- ✅ **SERVICE_ROLE_KEY** côté serveur uniquement
- ✅ **Valider inputs** côté client ET serveur
- ✅ **Rate limiting** activé (Traefik + Kong)

### Développement
- ✅ **Migrations SQL** versionnées (git)
- ✅ **Seed data** pour développement
- ✅ **Tests** avec base de test séparée
- ✅ **Logs** centralisés (Grafana Loki optionnel)

---

<p align="center">
  <strong>🚀 Bon développement avec Supabase sur Pi 5 ! 🚀</strong>
</p>

<p align="center">
  <sub>Questions ? Voir <a href="https://github.com/iamaketechnology/pi5-setup/issues">GitHub Issues</a></sub>
</p>
