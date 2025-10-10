# 🔌 Guide : Connecter votre Application à Supabase sur Raspberry Pi

> **Guide complet pour connecter votre application (React, Vue, Next.js, etc.) à votre instance Supabase self-hosted sur Raspberry Pi**

---

## 📋 Informations de votre Installation

### 🌐 URLs d'Accès

Vous avez **3 méthodes d'accès** à votre Supabase :

| Contexte | URL à utiliser | Quand l'utiliser |
|----------|---------------|------------------|
| 🏠 **Développement Local** (même WiFi) | `http://192.168.1.74:8000` | Développement sur votre PC à la maison |
| 🌍 **Production Publique** (Internet) | `https://pimaketechnology.duckdns.org` | Application déployée (Vercel, Netlify, etc.) |
| 🔐 **Accès Sécurisé** (VPN Tailscale) | `http://100.120.58.57:8000` | Développement en déplacement via VPN |

---

## 🔑 Récupérer vos Clés d'API

### Sur le Raspberry Pi

Connectez-vous en SSH et récupérez vos clés :

```bash
ssh pi@192.168.1.74

# Afficher toutes les clés
cat ~/stacks/supabase/.env | grep -E "(ANON_KEY|SERVICE_KEY|JWT_SECRET)"
```

**Résultat attendu** :
```bash
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
```

### Depuis votre Mac/PC

Récupération rapide depuis votre machine locale :

```bash
# Anon Key (clé publique - safe pour le frontend)
ssh pi@192.168.1.74 "grep SUPABASE_ANON_KEY ~/stacks/supabase/.env"

# Service Role Key (clé secrète - BACKEND SEULEMENT)
ssh pi@192.168.1.74 "grep SUPABASE_SERVICE_KEY ~/stacks/supabase/.env"
```

---

## 🚀 Configuration selon votre Stack

### 1️⃣ React / Vite

#### Installation

```bash
npm install @supabase/supabase-js
```

#### Configuration `.env`

Créez un fichier `.env` à la racine de votre projet :

**Développement Local (même WiFi que le Pi)** :
```env
VITE_SUPABASE_URL=http://192.168.1.74:8000
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Production (déployé sur Internet)** :
```env
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Code `src/lib/supabase.js`

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

#### Utilisation dans un composant

```javascript
import { supabase } from './lib/supabase'
import { useEffect, useState } from 'react'

function App() {
  const [users, setUsers] = useState([])

  useEffect(() => {
    fetchUsers()
  }, [])

  async function fetchUsers() {
    const { data, error } = await supabase
      .from('users')
      .select('*')

    if (error) console.error('Error:', error)
    else setUsers(data)
  }

  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users.map(user => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </div>
  )
}

export default App
```

---

### 2️⃣ Next.js (App Router)

#### Installation

```bash
npm install @supabase/supabase-js
```

#### Configuration `.env.local`

```env
# Développement local
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.74:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Production (déployé)
# NEXT_PUBLIC_SUPABASE_URL=https://pimaketechnology.duckdns.org
# NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Code `lib/supabase.js`

```javascript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)
```

#### Server Component `app/users/page.jsx`

```javascript
import { supabase } from '@/lib/supabase'

export default async function UsersPage() {
  const { data: users } = await supabase.from('users').select('*')

  return (
    <div>
      <h1>Users</h1>
      <ul>
        {users?.map(user => (
          <li key={user.id}>{user.name}</li>
        ))}
      </ul>
    </div>
  )
}
```

#### Client Component (avec auth)

```javascript
'use client'
import { supabase } from '@/lib/supabase'
import { useState } from 'react'

export default function LoginForm() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')

  async function handleLogin(e) {
    e.preventDefault()

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password
    })

    if (error) alert(error.message)
    else console.log('Logged in:', data)
  }

  return (
    <form onSubmit={handleLogin}>
      <input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="Email"
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
      />
      <button type="submit">Login</button>
    </form>
  )
}
```

---

### 3️⃣ Vue.js / Nuxt

#### Installation

```bash
npm install @supabase/supabase-js
```

#### Configuration `.env`

```env
VITE_SUPABASE_URL=http://192.168.1.74:8000
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Plugin `src/plugins/supabase.js`

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

#### Composant Vue `src/components/UserList.vue`

```vue
<template>
  <div>
    <h1>Users</h1>
    <ul>
      <li v-for="user in users" :key="user.id">
        {{ user.name }}
      </li>
    </ul>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from '@/plugins/supabase'

const users = ref([])

onMounted(async () => {
  const { data } = await supabase.from('users').select('*')
  users.value = data
})
</script>
```

---

### 4️⃣ Lovable.ai / Bolt.new / v0.dev

Ces plateformes acceptent directement les variables d'environnement :

#### Dans les Settings/Environment Variables :

```env
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

#### Code (identique à React/Vite)

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)

// Utilisation
const { data } = await supabase.from('users').select('*')
```

---

### 5️⃣ Backend Node.js / Express

#### Installation

```bash
npm install @supabase/supabase-js dotenv
```

#### Configuration `.env`

```env
SUPABASE_URL=https://pimaketechnology.duckdns.org
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**⚠️ IMPORTANT** : Utilisez `SUPABASE_SERVICE_KEY` (pas `ANON_KEY`) côté backend pour contourner les RLS (Row Level Security).

#### Code `server.js`

```javascript
require('dotenv').config()
const express = require('express')
const { createClient } = require('@supabase/supabase-js')

const app = express()

// Client Supabase avec Service Role Key (bypass RLS)
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_KEY
)

app.get('/api/users', async (req, res) => {
  const { data, error } = await supabase
    .from('users')
    .select('*')

  if (error) return res.status(500).json({ error: error.message })
  res.json(data)
})

app.listen(3000, () => console.log('Server running on port 3000'))
```

---

## 🔒 Sécurité : Quelle Clé Utiliser ?

### 🟢 ANON_KEY (Clé Publique)

**Utilisation** : Frontend (React, Vue, Next.js client-side)

**Sécurité** :
- ✅ Safe pour être exposée publiquement
- ✅ Respecte les Row Level Security (RLS) policies
- ✅ Utilisateurs ne peuvent accéder qu'à leurs propres données

**Exemple** :
```javascript
// Frontend - OK
const supabase = createClient(
  'https://pimaketechnology.duckdns.org',
  'eyJhbG...ANON_KEY'  // ✅ Publique
)
```

---

### 🔴 SERVICE_KEY (Clé Secrète)

**Utilisation** : Backend seulement (API, scripts, cron jobs)

**Sécurité** :
- ⛔ **JAMAIS** dans le frontend
- ⛔ **JAMAIS** dans le code versionné (git)
- ✅ Contourne les RLS policies
- ✅ Accès admin complet à la database

**Exemple** :
```javascript
// Backend Node.js - OK
const supabase = createClient(
  'https://pimaketechnology.duckdns.org',
  process.env.SUPABASE_SERVICE_KEY  // ✅ Serveur seulement
)
```

---

## 🧪 Tests de Connexion

### Test 1 : Depuis votre Terminal

```bash
# Test connexion + récupération données
curl -X GET 'http://192.168.1.74:8000/rest/v1/users?select=*' \
  -H "apikey: VOTRE_ANON_KEY" \
  -H "Authorization: Bearer VOTRE_ANON_KEY"
```

**Résultat attendu** : JSON avec vos données ou `[]` si table vide

---

### Test 2 : Depuis votre Application

Créez un fichier `test-connection.js` :

```javascript
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'http://192.168.1.74:8000',
  'VOTRE_ANON_KEY'
)

async function testConnection() {
  // Test 1: Récupérer version Postgres
  const { data, error } = await supabase
    .from('pg_stat_database')
    .select('*')
    .limit(1)

  if (error) {
    console.error('❌ Erreur connexion:', error.message)
  } else {
    console.log('✅ Connexion réussie!')
  }

  // Test 2: Lister les tables
  const { data: tables } = await supabase
    .from('information_schema.tables')
    .select('table_name')
    .eq('table_schema', 'public')

  console.log('📊 Tables disponibles:', tables)
}

testConnection()
```

Exécutez :
```bash
node test-connection.js
```

---

## 🌍 Déploiement Production

### Vercel / Netlify / Railway

#### 1. Configurez les variables d'environnement dans le dashboard

**Vercel** : Settings → Environment Variables
```
NEXT_PUBLIC_SUPABASE_URL=https://pimaketechnology.duckdns.org
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
```

**Netlify** : Site settings → Environment variables
```
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGc...
```

#### 2. Déployez

```bash
# Vercel
vercel --prod

# Netlify
netlify deploy --prod
```

#### 3. Testez

Ouvrez votre app déployée et vérifiez que les données s'affichent !

---

## 🔧 Problèmes Courants

### ❌ "Failed to fetch" / CORS Error

**Cause** : CORS non configuré sur le Pi

**Solution** :
```bash
ssh pi@192.168.1.74

# Vérifier CORS dans Kong
docker exec supabase-kong cat /etc/kong/kong.yml | grep cors
```

Si pas de CORS, ajoutez dans `/home/pi/stacks/supabase/docker-compose.yml` sous le service Kong :

```yaml
kong:
  environment:
    KONG_CORS_ORIGINS: '*'  # En dev - restreindre en prod
```

Redémarrez :
```bash
cd ~/stacks/supabase
docker compose restart kong
```

---

### ❌ "Invalid API key"

**Cause** : Mauvaise clé ou mal copiée

**Solution** :
```bash
# Récupérer la bonne clé
ssh pi@192.168.1.74 "grep SUPABASE_ANON_KEY ~/stacks/supabase/.env"

# Copier-coller EXACTEMENT (avec les points à la fin)
```

---

### ❌ "Table does not exist"

**Cause** : Table pas encore créée

**Solution** :

1. Ouvrez Studio : `http://192.168.1.74:3000`
2. Allez dans **Table Editor**
3. Créez une table test :

```sql
CREATE TABLE users (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT,
  email TEXT UNIQUE,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Insérer des données test
INSERT INTO users (name, email) VALUES
  ('Alice', 'alice@example.com'),
  ('Bob', 'bob@example.com');
```

4. Retestez votre application

---

### ❌ Connection Timeout (HTTPS depuis Vercel/Netlify)

**Cause** : Le Pi n'est pas accessible depuis Internet

**Solution** : Vérifiez que :
1. ✅ Ports 80/443 ouverts sur routeur
2. ✅ DNS DuckDNS pointe vers votre IP publique
3. ✅ Traefik déployé et certificat SSL généré

```bash
# Test depuis l'extérieur
curl -I https://pimaketechnology.duckdns.org/rest/v1/

# Doit retourner HTTP/2 (pas timeout)
```

---

## 📊 Récapitulatif des URLs

| Environnement | SUPABASE_URL | Quand utiliser |
|---------------|--------------|----------------|
| **Dev Local** (PC maison) | `http://192.168.1.74:8000` | Développement sur même WiFi |
| **Dev VPN** (déplacement) | `http://100.120.58.57:8000` | Dev en déplacement via Tailscale |
| **Production** (déployé) | `https://pimaketechnology.duckdns.org` | App sur Vercel/Netlify/etc. |

---

## 🎯 Configuration Recommandée par Contexte

### 👨‍💻 Développement Local

```env
# .env.local (Next.js) ou .env (Vite)
VITE_SUPABASE_URL=http://192.168.1.74:8000
VITE_SUPABASE_ANON_KEY=eyJhbGc...

# Avantages:
# - Latence 0ms (ultra-rapide)
# - Pas besoin d'Internet
# - Debug facile
```

---

### 🚀 Production Déployée

```env
# Variables Vercel/Netlify
NEXT_PUBLIC_SUPABASE_URL=https://pimaketechnology.duckdns.org
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...

# Avantages:
# - HTTPS sécurisé
# - Accessible de partout
# - Certificat SSL Let's Encrypt
```

---

### 🔐 Backend Privé

```env
# .env (Node.js backend)
SUPABASE_URL=https://pimaketechnology.duckdns.org
SUPABASE_SERVICE_KEY=eyJhbGc...  # ⚠️ SERVICE KEY

# Avantages:
# - Bypass RLS policies
# - Accès admin complet
# - Pour cron jobs, scripts, etc.
```

---

## 📚 Ressources Utiles

- **Documentation Supabase JS** : https://supabase.com/docs/reference/javascript/introduction
- **Studio Local** : http://192.168.1.74:3000
- **Votre API** : https://pimaketechnology.duckdns.org/rest/v1/
- **Dashboard Traefik** : http://192.168.1.74:8080 (si activé)

---

## ✅ Checklist Connexion Application

Avant de coder, vérifiez :

- [ ] Supabase tourne : `docker ps | grep supabase`
- [ ] Studio accessible : http://192.168.1.74:3000
- [ ] Au moins 1 table créée dans la DB
- [ ] ANON_KEY récupérée : `grep ANON_KEY ~/stacks/supabase/.env`
- [ ] Variable d'environnement configurée dans l'app
- [ ] `@supabase/supabase-js` installé : `npm list @supabase/supabase-js`

---

**🎉 Votre application est maintenant prête à communiquer avec Supabase sur votre Raspberry Pi !**

---

**Version** : 1.0.0
**Date** : 2025-01-XX
**Testé sur** : Raspberry Pi 5 + React + Next.js + Vue.js
**IP Pi** : 192.168.1.74
**Domaine** : pimaketechnology.duckdns.org
