# ⚡ Guide Connexion Rapide - Application → Supabase Pi

> **Configuration en 5 minutes pour connecter votre application React/Vue/Next.js**

---

## 🎯 Votre Configuration

### 📍 URLs Supabase

| Contexte | URL | Port |
|----------|-----|------|
| **Local** (même WiFi) | `http://192.168.1.74:8001` | 8001 |
| **HTTPS** (Internet) | `https://pimaketechnology.duckdns.org` | 443 |
| **VPN** (Tailscale) | `http://100.120.58.57:8001` | 8001 |

### 🔑 Clés API (Mises à jour 2025-10-10)

```bash
# ✅ ANON_KEY (Frontend - React/Vue/Next.js)
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg

# ⚠️ SERVICE_KEY (Backend uniquement - Node.js/Python)
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJzZXJ2aWNlX3JvbGUiLCJpYXQiOjE3NjAwOTk4NjksImV4cCI6MjA3NTQ1OTg2OX0._GNOnc4OwWlX2Vz_q6tUfU4RYoN2nPwfTgiRe4NbWTU
```

---

## ⚡ Configurations Express

### React / Vite

#### 1. Installation
```bash
npm install @supabase/supabase-js
```

#### 2. `.env.local` (Développement)
```env
VITE_SUPABASE_URL=http://192.168.1.74:8001
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

#### 3. `.env.production` (Déploiement)
```env
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

#### 4. Code `src/lib/supabase.js`
```javascript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)
```

#### 5. Utilisation
```javascript
import { supabase } from './lib/supabase'

// Lire données
const { data, error } = await supabase
  .from('users')
  .select('*')

// Créer données
const { data, error } = await supabase
  .from('users')
  .insert({ name: 'John', email: 'john@example.com' })

// Mise à jour
const { data, error } = await supabase
  .from('users')
  .update({ name: 'Jane' })
  .eq('id', 1)
```

---

### Next.js

#### 1. Installation
```bash
npm install @supabase/supabase-js
```

#### 2. `.env.local`
```env
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.74:8001
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

#### 3. Code `lib/supabase.js`
```javascript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)
```

#### 4. Usage (App Router)
```javascript
// app/page.js
import { supabase } from '@/lib/supabase'

export default async function Page() {
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

---

### Vue.js

#### 1. Installation
```bash
npm install @supabase/supabase-js
```

#### 2. `.env`
```env
VITE_SUPABASE_URL=http://192.168.1.74:8001
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg
```

#### 3. Code `src/supabase.js`
```javascript
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_ANON_KEY
)
```

#### 4. Usage
```vue
<script setup>
import { ref, onMounted } from 'vue'
import { supabase } from './supabase'

const users = ref([])

onMounted(async () => {
  const { data } = await supabase.from('users').select('*')
  users.value = data
})
</script>

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
```

---

## 🧪 Test Rapide

### Script de Test
```javascript
// test-connection.js
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  'http://192.168.1.74:8001',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzYwMDk5ODY5LCJleHAiOjIwNzU0NTk4Njl9.G3Kwpg_7R3SLHmjIMkuxZ7wkK3HVy5x93RpMhKe7mvg'
)

async function test() {
  console.log('🔍 Test connexion Supabase...')

  const { data, error } = await supabase
    .from('users')
    .select('*')
    .limit(1)

  if (error) {
    console.error('❌ Erreur:', error.message)
  } else {
    console.log('✅ Connexion réussie!')
    console.log('📊 Données:', data)
  }
}

test()
```

Exécuter :
```bash
node test-connection.js
```

---

## ⚠️ Erreurs Courantes

### 1. CORS Error
```
Access to fetch has been blocked by CORS policy
```

**Solution** : Les clés Kong ont été mises à jour (2025-10-10). Si vous avez encore l'erreur :
```bash
ssh pi@192.168.1.74
cd ~/stacks/supabase
docker compose restart kong
```

### 2. Invalid API Key
```
Invalid API key
```

**Solution** : Vérifiez que vous utilisez bien les nouvelles clés (2025) dans votre `.env`.

### 3. Connection Timeout
```
Failed to fetch
```

**Solutions** :
- **Local** : Vérifiez que vous êtes sur le même WiFi que le Pi
- **HTTPS** : Vérifiez que le Pi est accessible depuis Internet
- **VPN** : Vérifiez que Tailscale est connecté

---

## 📊 Quelle URL Utiliser ?

| Situation | URL | Quand |
|-----------|-----|-------|
| Dev sur Mac (même WiFi) | `http://192.168.1.74:8001` | Développement quotidien |
| Dev en déplacement | `http://100.120.58.57:8001` | Via Tailscale VPN |
| App déployée (Vercel) | `https://pimaketechnology.duckdns.org` | Production Internet |
| Backend Node.js | `https://pimaketechnology.duckdns.org` | Serveur backend |

---

## 🔐 ANON_KEY vs SERVICE_KEY

| Clé | Utilisation | Sécurité | RLS |
|-----|-------------|----------|-----|
| **ANON_KEY** | Frontend (React, Vue, Next.js) | ✅ Safe à exposer | ✅ Respecte les règles RLS |
| **SERVICE_KEY** | Backend uniquement (Node.js, API) | ⚠️ CONFIDENTIEL | ❌ Bypass RLS (admin) |

**Règle** :
- Frontend → `ANON_KEY`
- Backend → `SERVICE_KEY`

---

## 🚀 Déploiement Production

### Vercel

1. Ajouter variables d'environnement :
```
NEXT_PUBLIC_SUPABASE_URL=https://pimaketechnology.duckdns.org
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGci...MTc2MDA5OTg2OQ...
```

2. Déployer :
```bash
vercel --prod
```

### Netlify

1. Site settings → Environment variables :
```
VITE_SUPABASE_URL=https://pimaketechnology.duckdns.org
VITE_SUPABASE_ANON_KEY=eyJhbGci...MTc2MDA5OTg2OQ...
```

2. Déployer :
```bash
netlify deploy --prod
```

---

## 📚 Documentation Complète

- **Guide Détaillé** : [CONNEXION-APPLICATION-SUPABASE-PI.md](CONNEXION-APPLICATION-SUPABASE-PI.md)
- **Index Documentation** : [INDEX-DOCUMENTATION.md](INDEX-DOCUMENTATION.md)
- **Troubleshooting** : [01-infrastructure/supabase/docs/troubleshooting/](01-infrastructure/supabase/docs/troubleshooting/)

---

## ✅ Checklist Post-Configuration

- [ ] `.env.local` créé avec bonnes clés
- [ ] `supabase.js` créé avec client configuré
- [ ] Test connexion réussi (script test)
- [ ] Première requête fonctionne (select)
- [ ] CORS OK (pas d'erreur navigateur)
- [ ] Authentification testée (signup/login)

---

## 🆘 Besoin d'Aide ?

### Vérifier Status Supabase
```bash
ssh pi@192.168.1.74
docker ps | grep supabase
```

Tous les conteneurs doivent être `(healthy)`.

### Vérifier Logs Kong
```bash
ssh pi@192.168.1.74
docker logs supabase-kong --tail 50
```

### Test API Direct
```bash
curl -H "apikey: <ANON_KEY>" http://192.168.1.74:8001/rest/v1/
```

Doit retourner JSON (pas d'erreur 401).

---

**Date** : 2025-10-10
**Version** : v3.29
**Status** : ✅ Kong mis à jour avec nouvelles clés

**Prêt à coder !** 🚀
