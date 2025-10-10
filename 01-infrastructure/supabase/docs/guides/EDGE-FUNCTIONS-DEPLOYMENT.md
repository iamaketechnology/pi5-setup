# Edge Functions Deployment Guide

**Guide de déploiement des Edge Functions sur Supabase auto-hébergé (Pi 5)**

---

## 📋 Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Structure des fonctions](#structure-des-fonctions)
4. [Déploiement automatique](#déploiement-automatique)
5. [Déploiement manuel](#déploiement-manuel)
6. [Testing et debugging](#testing-et-debugging)
7. [Troubleshooting](#troubleshooting)
8. [Best practices](#best-practices)

---

## Vue d'ensemble

### ⚠️ Limitation Critique : Pas de Multi-Function Routing

**IMPORTANT** : Le Edge Runtime Docker de Supabase **NE SUPPORTE PAS** le routing automatique multi-fonctions comme le cloud.

**Problème** :
```bash
# Cloud Supabase ✅
/functions/v1/verify-document    → verify-document/index.ts
/functions/v1/create-access-link → create-access-link/index.ts

# Self-Hosted ❌
/functions/v1/*                  → main/index.ts (seulement)
```

**Solution** : Vous devez utiliser le pattern **"Fat Router"** (voir [EDGE-FUNCTIONS-FAT-ROUTER.md](../troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md))

### Pourquoi ce guide ?

1. La **CLI Supabase officielle ne supporte PAS le déploiement vers des instances auto-hébergées**
2. Le **Edge Runtime ne route PAS automatiquement vers plusieurs fonctions**
3. Vous devez **créer un router principal** qui dispatch les requêtes

### Différences avec Supabase Cloud

| Aspect | Supabase Cloud | Supabase Self-Hosted |
|--------|----------------|----------------------|
| Déploiement | `supabase functions deploy` | Copie manuelle via SSH |
| Multi-Functions | ✅ Routing automatique | ❌ Nécessite Fat Router |
| CLI | ✅ Supporte | ❌ Ne supporte pas |
| Secrets | Via CLI/Dashboard | Variables d'environnement Docker |
| Logs | Dashboard | `docker logs` |
| Rollback | Automatique | Manuel (backups) |

---

## Prérequis

### Sur votre machine locale

- ✅ Projet avec dossier `supabase/functions/`
- ✅ Clé SSH configurée pour le Pi : `ssh-copy-id pi@192.168.1.74`
- ✅ Script de déploiement : `deploy-edge-functions.sh`

### Sur le Raspberry Pi

- ✅ Supabase déployé et fonctionnel
- ✅ Container `supabase-edge-functions` en état `running`
- ✅ Dossier : `/home/pi/stacks/supabase/volumes/functions/`

### Vérification rapide

```bash
# Test connexion SSH
ssh pi@192.168.1.74 "echo 'SSH OK'"

# Vérifier Edge Functions container
ssh pi@192.168.1.74 "docker ps | grep edge-functions"

# Vérifier dossier functions
ssh pi@192.168.1.74 "ls -la ~/stacks/supabase/volumes/functions/"
```

---

## Structure des fonctions

### ⚠️ Deux Approches Possibles

#### Approche 1 : Fat Router (RECOMMANDÉ pour Self-Hosted)

**Structure locale** :
```
your-app/
├── supabase/
│   └── functions/
│       ├── main/
│       │   └── index.ts           # 🔥 ROUTER PRINCIPAL (dispatch)
│       ├── handlers/
│       │   ├── verify-document.ts # Logique métier
│       │   ├── create-access-link.ts
│       │   └── generate-certificate.ts
│       └── _shared/               # Code partagé
│           ├── cors.ts
│           └── supabase-client.ts
```

**Structure sur le Pi** :
```
/home/pi/stacks/supabase/volumes/functions/
├── main/
│   └── index.ts                   # Router qui dispatch vers handlers
├── handlers/
│   ├── verify-document.ts
│   ├── create-access-link.ts
│   └── generate-certificate.ts
└── _shared/
    ├── cors.ts
    └── supabase-client.ts
```

**Pourquoi cette structure** :
- ✅ Fonctionne avec Edge Runtime Docker (une seule fonction `main`)
- ✅ Le router parse l'URL et dispatch vers le bon handler
- ✅ Toutes les fonctions accessibles via `/functions/v1/{function-name}`

**Exemple de router** (voir [EDGE-FUNCTIONS-FAT-ROUTER.md](../troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md) pour le code complet)

#### Approche 2 : Multi-Functions (Cloud Supabase uniquement)

**Structure** :
```
your-app/
├── supabase/
│   └── functions/
│       ├── verify-document/
│       │   └── index.ts
│       ├── create-access-link/
│       │   └── index.ts
│       └── generate-certificate/
│           └── index.ts
```

**⚠️ Limitation** : Cette structure **NE FONCTIONNE PAS** sur Edge Runtime Docker auto-hébergé

**Important** :
- Approche 1 (Fat Router) = **OBLIGATOIRE** pour self-hosted
- Approche 2 (Multi-Functions) = **UNIQUEMENT** sur Supabase Cloud
- Le dossier `_shared/` est optionnel mais recommandé

---

## Déploiement automatique

### Utilisation du script

```bash
# Depuis la racine de votre projet local
cd /path/to/your-app

# Déployer toutes les fonctions
sudo bash /path/to/pi5-setup/01-infrastructure/supabase/scripts/utils/deploy-edge-functions.sh \
  ./supabase/functions

# Avec un hôte Pi personnalisé
sudo bash deploy-edge-functions.sh \
  ./supabase/functions \
  pi@192.168.1.100
```

### Ce que fait le script

1. ✅ **Validation** : Vérifie que le dossier functions existe et contient des fonctions
2. ✅ **Connectivité** : Teste la connexion SSH au Pi
3. ✅ **Backup** : Sauvegarde les fonctions existantes (avant écrasement)
4. ✅ **Déploiement** : Rsync des fichiers vers le Pi (préserve symlinks et permissions)
5. ✅ **Permissions** : Configure les permissions correctes (UID 1000:1000)
6. ✅ **Restart** : Redémarre le container Edge Functions
7. ✅ **Testing** : Teste chaque fonction déployée (HTTP 200/401, pas 503)
8. ✅ **Summary** : Affiche un résumé avec les URLs des fonctions

### Sortie du script

```
🚀 Edge Functions Deployment for Supabase Pi 5
=======================================================================

📋 Configuration:
   Functions Directory: /home/user/my-app/supabase/functions
   Pi Host: pi@192.168.1.74
   Supabase Directory: /home/pi/stacks/supabase

=== Phase 1: Validation ===
✅ Found 16 function(s) to deploy
✅ SSH connection successful
✅ Edge Functions container is running

=== Phase 2: Backup ===
💾 Creating backup of existing functions...
✅ Backup complete

=== Phase 3: Deployment ===
📦 Deploying Edge Functions...
📋 Functions to deploy:
   - verify-document
   - create-access-link
   - generate-certificate
   ...

🔄 Syncing functions to Pi...
✅ Functions synced to Pi
✅ Permissions set

=== Phase 4: Restart ===
🔄 Restarting Edge Functions container...
⏳ Waiting for Edge Functions to be healthy...
✅ Edge Functions container is healthy

=== Phase 5: Testing ===
🧪 Testing deployed Edge Functions...

Testing function: verify-document
   ✅ verify-document - Accessible (HTTP 401)

Testing function: create-access-link
   ✅ create-access-link - Accessible (HTTP 401)

...

📊 Test Results:
   ✅ Success: 16
   ❌ Failed: 0

✅ All functions deployed successfully!

=======================================================================
✅ Edge Functions Deployment Complete
=======================================================================
```

---

## Déploiement manuel

### Méthode 1 : rsync (Recommandé)

```bash
# Depuis votre machine locale
rsync -avz --delete \
  --exclude='node_modules' \
  --exclude='.git' \
  ./supabase/functions/ \
  pi@192.168.1.74:~/stacks/supabase/volumes/functions/

# Fixer les permissions sur le Pi
ssh pi@192.168.1.74 "sudo chown -R 1000:1000 ~/stacks/supabase/volumes/functions"

# Redémarrer Edge Functions
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

### Méthode 2 : scp (Simple)

```bash
# Copier une fonction spécifique
scp -r ./supabase/functions/verify-document \
  pi@192.168.1.74:~/stacks/supabase/volumes/functions/

# Redémarrer
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

### Méthode 3 : Git (Avancé)

```bash
# Sur le Pi, créer un repo Git dans functions/
ssh pi@192.168.1.74 "cd ~/stacks/supabase/volumes/functions && git init"

# Ajouter remote vers votre repo
ssh pi@192.168.1.74 "cd ~/stacks/supabase/volumes/functions && git remote add origin https://github.com/you/your-app.git"

# Pull depuis subtree
ssh pi@192.168.1.74 "cd ~/stacks/supabase/volumes/functions && git subtree pull --prefix=supabase/functions origin main"

# Redémarrer
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

---

## Testing et debugging

### Tester une fonction localement (avant déploiement)

```bash
# Avec Deno local
cd supabase/functions/verify-document
deno run --allow-net --allow-env index.ts

# Avec Supabase CLI (ne déploiera pas sur self-hosted)
supabase functions serve verify-document
```

### Tester une fonction déployée

```bash
# Depuis le Pi (localhost)
ssh pi@192.168.1.74 "curl -X POST 'http://localhost:8001/functions/v1/verify-document' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{\"token\":\"test-token\"}'"

# Depuis votre machine (réseau local)
curl -X POST 'http://192.168.1.74:8001/functions/v1/verify-document' \
  -H 'Authorization: Bearer YOUR_ANON_KEY' \
  -H 'Content-Type: application/json' \
  -d '{"token":"test-token"}'
```

### Voir les logs

```bash
# Logs en temps réel
ssh pi@192.168.1.74 "docker logs -f supabase-edge-functions"

# Logs des 50 dernières lignes
ssh pi@192.168.1.74 "docker logs supabase-edge-functions --tail 50"

# Logs avec timestamps
ssh pi@192.168.1.74 "docker logs supabase-edge-functions --timestamps"

# Filtrer les logs par fonction
ssh pi@192.168.1.74 "docker logs supabase-edge-functions 2>&1 | grep 'verify-document'"
```

### Débugger une fonction

```typescript
// Dans votre fonction index.ts
Deno.serve(async (req) => {
  // Log dans les logs Docker
  console.log('[verify-document] Request received:', {
    method: req.method,
    url: req.url,
    headers: Object.fromEntries(req.headers.entries())
  });

  try {
    const body = await req.json();
    console.log('[verify-document] Body:', body);

    // Votre logique...
    const result = await processDocument(body);
    console.log('[verify-document] Result:', result);

    return new Response(JSON.stringify(result), {
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (error) {
    console.error('[verify-document] ERROR:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' }
    });
  }
});
```

Puis voir les logs :
```bash
ssh pi@192.168.1.74 "docker logs supabase-edge-functions --tail 100 | grep verify-document"
```

---

## Troubleshooting

### Problème 1 : "Hello undefined!" (CRITIQUE)

**Symptôme** :
```bash
curl http://192.168.1.74:8001/functions/v1/verify-document
# Résultat: {"message":"Hello undefined!"}
```

**Cause** : **Edge Runtime ne supporte PAS le multi-function routing**

**Explication** :
- Supabase Cloud : Route automatiquement `/functions/v1/verify-document` vers `verify-document/index.ts`
- Self-Hosted : Toutes les requêtes vont vers `main/index.ts` uniquement
- Si `main/index.ts` n'existe pas ou ne fait pas de routing → "Hello undefined!"

**Solution** : Utiliser le pattern **Fat Router**

1. **Créer le router principal** (`main/index.ts`) :
```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

// Import handlers
import { handleVerifyDocument } from '../handlers/verify-document.ts';

const routes = {
  'verify-document': handleVerifyDocument,
  // ... autres fonctions
};

serve(async (req) => {
  const url = new URL(req.url);
  const pathParts = url.pathname.split('/').filter(Boolean);
  const functionName = pathParts[pathParts.length - 1];

  const handler = routes[functionName];
  if (!handler) {
    return new Response(JSON.stringify({ error: 'Function not found' }), {
      status: 404,
      headers: { 'Content-Type': 'application/json' }
    });
  }

  return handler(req);
});
```

2. **Créer le handler** (`handlers/verify-document.ts`) :
```typescript
export async function handleVerifyDocument(req: Request): Promise<Response> {
  const { token } = await req.json();
  // Votre logique métier...
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

3. **Déployer** :
```bash
rsync -avz ./supabase/functions/ pi@192.168.1.74:~/stacks/supabase/volumes/functions/
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

**Voir** : [EDGE-FUNCTIONS-FAT-ROUTER.md](../troubleshooting/EDGE-FUNCTIONS-FAT-ROUTER.md) pour le guide complet

### Problème 2 : Permission Denied

**Symptôme** : Logs montrent `EACCES: permission denied`

**Cause** : Mauvaises permissions sur les fichiers

**Solution** :
```bash
# Fixer les permissions (UID 1000 = utilisateur deno dans le container)
ssh pi@192.168.1.74 "sudo chown -R 1000:1000 ~/stacks/supabase/volumes/functions"
ssh pi@192.168.1.74 "sudo chmod -R 755 ~/stacks/supabase/volumes/functions"

# Redémarrer
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

### Problème 3 : Module Not Found

**Symptôme** : `error: Module not found "file:///home/deno/functions/..."`

**Cause** : Import relatif incorrect

**Solution** :
```typescript
// ❌ WRONG - Ne fonctionne pas en production
import { corsHeaders } from '../_shared/cors.ts';

// ✅ CORRECT - Chemin absolu depuis /home/deno/functions
import { corsHeaders } from '/home/deno/functions/_shared/cors.ts';

// ✅ CORRECT - Import depuis URL (Deno style)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
```

### Problème 4 : Database Connection Failed

**Symptôme** : `Error connecting to database`

**Cause** : Variable d'environnement `SUPABASE_DB_URL` manquante ou incorrecte

**Solution** :
```bash
# Vérifier les variables d'env du container
ssh pi@192.168.1.74 "docker exec supabase-edge-functions env | grep SUPABASE"

# Devrait afficher :
# SUPABASE_URL=http://kong:8000
# SUPABASE_ANON_KEY=eyJ...
# SUPABASE_SERVICE_ROLE_KEY=eyJ...
# SUPABASE_DB_URL=postgresql://postgres:password@db:5432/postgres

# Si manquant, vérifier docker-compose.yml
ssh pi@192.168.1.74 "grep -A 5 'edge-functions:' ~/stacks/supabase/docker-compose.yml"
```

### Problème 5 : Container Crash Loop

**Symptôme** : Container redémarre constamment

**Solution** :
```bash
# Voir les logs d'erreur
ssh pi@192.168.1.74 "docker logs supabase-edge-functions --tail 100"

# Vérifier l'état du container
ssh pi@192.168.1.74 "docker inspect supabase-edge-functions --format '{{.State.Status}}'"

# Vérifier si la fonction main existe (requis)
ssh pi@192.168.1.74 "ls -la ~/stacks/supabase/volumes/functions/main/"

# Si main manquant, restaurer depuis backup ou créer un dummy
ssh pi@192.168.1.74 "mkdir -p ~/stacks/supabase/volumes/functions/main"
ssh pi@192.168.1.74 "cat > ~/stacks/supabase/volumes/functions/main/index.ts << 'EOF'
Deno.serve(async (req) => {
  return new Response(JSON.stringify({ message: 'Hello World!' }), {
    headers: { 'Content-Type': 'application/json' }
  });
});
EOF"
```

---

## Best Practices

### 1. Toujours tester localement d'abord

```bash
# Avec Supabase CLI (start local instance)
supabase start
supabase functions serve your-function

# Tester avec curl
curl http://localhost:54321/functions/v1/your-function
```

### 2. Utiliser des variables d'environnement

```typescript
// Dans votre fonction
const DATABASE_URL = Deno.env.get('SUPABASE_DB_URL');
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');

// Toujours vérifier qu'elles existent
if (!DATABASE_URL) {
  throw new Error('SUPABASE_DB_URL not set');
}
```

### 3. Gérer les CORS correctement

```typescript
// _shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Dans votre fonction
import { corsHeaders } from '/home/deno/functions/_shared/cors.ts';

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Your logic...
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }
});
```

### 4. Logger abondamment (pour debugging)

```typescript
console.log('[function-name] Starting...');
console.log('[function-name] Config:', { env: Deno.env.get('NODE_ENV') });
console.log('[function-name] Request:', { method: req.method, url: req.url });
console.log('[function-name] Body:', body);
console.log('[function-name] Result:', result);
```

### 5. Créer un script de déploiement projet-spécifique

```bash
#!/bin/bash
# deploy-to-pi.sh

set -e

echo "🚀 Deploying to Pi..."

# Deploy functions
rsync -avz ./supabase/functions/ pi@192.168.1.74:~/stacks/supabase/volumes/functions/

# Fix permissions
ssh pi@192.168.1.74 "sudo chown -R 1000:1000 ~/stacks/supabase/volumes/functions"

# Restart
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"

# Wait for healthy
echo "⏳ Waiting for Edge Functions..."
sleep 10

# Test critical functions
echo "🧪 Testing functions..."
curl -X POST http://192.168.1.74:8001/functions/v1/verify-document \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -d '{"token":"test"}'

echo "✅ Deployment complete!"
```

### 6. Versionner vos fonctions

```bash
# Créer un tag Git avant chaque déploiement
git tag -a "edge-functions-v1.2.0" -m "Deploy verify-document fix"
git push origin edge-functions-v1.2.0

# Inclure la version dans vos réponses
export const VERSION = '1.2.0';

Deno.serve(async (req) => {
  return new Response(JSON.stringify({
    version: VERSION,
    timestamp: new Date().toISOString(),
    data: result
  }));
});
```

### 7. Utiliser TypeScript strict

```typescript
// deno.json dans votre projet
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true
  }
}
```

---

## Ressources

### Documentation officielle
- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Manual](https://deno.land/manual)
- [Deno Deploy](https://deno.com/deploy/docs)

### Scripts utiles
- `deploy-edge-functions.sh` : Script de déploiement automatique (ce guide)
- [pi5-setup repo](https://github.com/your-repo/pi5-setup) : Scripts Supabase Pi 5

### Communauté
- [Supabase Discord](https://discord.supabase.com/)
- [Deno Discord](https://discord.gg/deno)

---

## Conclusion

Le déploiement d'Edge Functions sur Supabase auto-hébergé nécessite une approche manuelle, mais avec les bons scripts et pratiques, le processus devient **simple et reproductible**.

**Résumé** :
- ✅ Utilisez `deploy-edge-functions.sh` pour déploiement automatique
- ✅ Testez localement avant de déployer
- ✅ Loggez abondamment pour debugging
- ✅ Gérez les CORS correctement
- ✅ Utilisez des variables d'environnement
- ✅ Versionnez vos fonctions

**Prochain guide** : [Edge Functions Secrets Management](./EDGE-FUNCTIONS-SECRETS.md)

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-10
**Auteur** : Claude Code Assistant
