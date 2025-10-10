# Edge Functions Fat Router Pattern

**Solution pour déployer plusieurs Edge Functions sur Supabase auto-hébergé**

---

## 🎯 Problème Identifié

### Symptômes

```bash
# Test d'une fonction métier
curl http://192.168.1.74:8001/functions/v1/verify-document
# Résultat: "Hello undefined!" ❌
```

- **Cloud Supabase** : Routing automatique vers `/functions/v1/{function-name}`
- **Self-Hosted Supabase** : Edge Runtime ne supporte PAS le multi-function routing natif
- **Cause** : `supabase/edge-runtime` Docker image utilise une seule fonction `main`

### Architecture Cloud vs Self-Hosted

```
┌─────────────────────────────────────────────────────────────┐
│ CLOUD SUPABASE (Routing automatique)                        │
├─────────────────────────────────────────────────────────────┤
│ /functions/v1/verify-document    → verify-document/index.ts │
│ /functions/v1/create-access-link → create-access-link/...   │
│ /functions/v1/generate-cert      → generate-cert/...        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ SELF-HOSTED (Fat Router requis)                             │
├─────────────────────────────────────────────────────────────┤
│ /functions/v1/*                  → main/index.ts (router)   │
│   ↓ dispatch interne                                         │
│   ├─ verify-document handler                                │
│   ├─ create-access-link handler                             │
│   └─ generate-cert handler                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## ✅ Solution : Fat Function Router

### Concept

Créer une **fonction principale `main/index.ts`** qui :
1. Parse l'URL pour identifier la fonction demandée
2. Dispatch vers le handler approprié
3. Retourne la réponse

### Structure des fichiers

```
supabase/functions/
├── main/
│   └── index.ts                    # Router principal (OBLIGATOIRE)
├── handlers/
│   ├── verify-document.ts          # Logique métier
│   ├── create-access-link.ts
│   ├── generate-certificate.ts
│   └── ...
└── _shared/
    ├── cors.ts
    ├── supabase-client.ts
    └── types.ts
```

---

## 🔧 Implémentation

### 1. Router Principal (`main/index.ts`)

```typescript
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Import handlers
import { handleVerifyDocument } from '../handlers/verify-document.ts';
import { handleCreateAccessLink } from '../handlers/create-access-link.ts';
// ... autres imports

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Router map
const routes: Record<string, (req: Request, supabase: any) => Promise<Response>> = {
  'verify-document': handleVerifyDocument,
  'create-access-link': handleCreateAccessLink,
  'generate-certificate': handleGenerateCertificate,
  'sign-document': handleSignDocument,
  // ... autres routes
};

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Parse URL to extract function name
    // URL format: /functions/v1/{function-name}
    const url = new URL(req.url);
    const pathParts = url.pathname.split('/').filter(Boolean);

    // Extract function name (last part of path or from query param)
    let functionName = pathParts[pathParts.length - 1];

    // Si appelé depuis Kong avec strip_path, le nom peut être dans l'URL d'origine
    const xForwardedPath = req.headers.get('x-forwarded-path') || '';
    if (xForwardedPath) {
      const forwardedParts = xForwardedPath.split('/').filter(Boolean);
      functionName = forwardedParts[forwardedParts.length - 1];
    }

    console.log(`[Router] Request for function: ${functionName}`);

    // Get handler for this function
    const handler = routes[functionName];

    if (!handler) {
      console.error(`[Router] Function not found: ${functionName}`);
      console.log(`[Router] Available functions:`, Object.keys(routes));

      return new Response(
        JSON.stringify({
          error: 'Function not found',
          available: Object.keys(routes)
        }),
        {
          status: 404,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        }
      );
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Call handler
    console.log(`[Router] Dispatching to ${functionName} handler`);
    const response = await handler(req, supabase);

    return response;

  } catch (error) {
    console.error('[Router] Error:', error);

    return new Response(
      JSON.stringify({
        error: error.message,
        stack: error.stack
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    );
  }
});
```

### 2. Handler Exemple (`handlers/verify-document.ts`)

```typescript
export async function handleVerifyDocument(
  req: Request,
  supabase: any
): Promise<Response> {
  console.log('[verify-document] Handler called');

  try {
    // Parse request body
    const { token } = await req.json();

    if (!token) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Token is required'
        }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Validate token and fetch access link
    const { data: accessLink, error: linkError } = await supabase
      .from('access_links')
      .select('*, documents(*)')
      .eq('token', token)
      .single();

    if (linkError || !accessLink) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Document not found or access link invalid',
          details: 'Access link not found'
        }),
        {
          status: 404,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Check expiration
    if (accessLink.expires_at && new Date(accessLink.expires_at) < new Date()) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Access link has expired',
          expires_at: accessLink.expires_at
        }),
        {
          status: 403,
          headers: { 'Content-Type': 'application/json' }
        }
      );
    }

    // Return document data
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          document: accessLink.documents,
          access_link: {
            id: accessLink.id,
            expires_at: accessLink.expires_at,
            max_views: accessLink.max_views,
            view_count: accessLink.view_count
          }
        }
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    );

  } catch (error) {
    console.error('[verify-document] Error:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}
```

### 3. Handler Stub (pour fonctions non implémentées)

```typescript
export async function handleNotImplemented(
  req: Request,
  supabase: any
): Promise<Response> {
  return new Response(
    JSON.stringify({
      error: 'Not implemented yet',
      message: 'This function is not yet implemented in self-hosted version'
    }),
    {
      status: 501,
      headers: { 'Content-Type': 'application/json' }
    }
  );
}
```

---

## 📦 Déploiement

### Option 1 : Script Automatique

```bash
# Créer le script deploy-functions-to-pi.sh
#!/bin/bash
set -e

PI_HOST="pi@192.168.1.74"
SUPABASE_DIR="/home/pi/stacks/supabase"
LOCAL_FUNCTIONS="./supabase/functions"

echo "🚀 Deploying Edge Functions to Pi..."

# Backup existing functions
ssh $PI_HOST "
  if [ -d '$SUPABASE_DIR/volumes/functions' ]; then
    cp -r '$SUPABASE_DIR/volumes/functions' \
          '$SUPABASE_DIR/backups/functions-\$(date +%Y%m%d-%H%M%S)'
  fi
"

# Deploy via rsync
rsync -avz --delete \
  --exclude='node_modules' \
  --exclude='.git' \
  --exclude='*.test.ts' \
  "$LOCAL_FUNCTIONS/" \
  "$PI_HOST:$SUPABASE_DIR/volumes/functions/"

# Fix permissions
ssh $PI_HOST "sudo chown -R 1000:1000 $SUPABASE_DIR/volumes/functions"

# Restart Edge Functions
ssh $PI_HOST "cd $SUPABASE_DIR && docker compose restart edge-functions"

echo "⏳ Waiting for container to be healthy..."
sleep 15

# Test
echo "🧪 Testing verify-document..."
curl -X POST "http://192.168.1.74:8001/functions/v1/verify-document" \
  -H "Content-Type: application/json" \
  -d '{"token":"test"}'

echo ""
echo "✅ Deployment complete!"
```

### Option 2 : Manuel

```bash
# 1. Copier les fonctions
rsync -avz ./supabase/functions/ pi@192.168.1.74:~/stacks/supabase/volumes/functions/

# 2. Fixer les permissions
ssh pi@192.168.1.74 "sudo chown -R 1000:1000 ~/stacks/supabase/volumes/functions"

# 3. Redémarrer
ssh pi@192.168.1.74 "cd ~/stacks/supabase && docker compose restart edge-functions"
```

---

## 🧪 Testing

### 1. Test Local (avant déploiement)

```bash
# Avec Deno
cd supabase/functions/main
deno run --allow-net --allow-env --allow-read index.ts

# Test curl
curl http://localhost:8000/verify-document \
  -H 'Content-Type: application/json' \
  -d '{"token":"test-token"}'
```

### 2. Test sur Pi (après déploiement)

```bash
# Test basique
curl -X POST 'http://192.168.1.74:8001/functions/v1/verify-document' \
  -H 'Content-Type: application/json' \
  -d '{"token":"test"}'

# Résultat attendu (token invalide):
# {"success":false,"error":"Document not found or access link invalid","details":"Access link not found"}

# Test avec vrai token (à créer dans votre app d'abord)
curl -X POST 'http://192.168.1.74:8001/functions/v1/verify-document' \
  -H 'Content-Type: application/json' \
  -d '{"token":"REAL_TOKEN_HERE"}'

# Résultat attendu (token valide):
# {"success":true,"data":{"document":{...},"access_link":{...}}}
```

### 3. Debugging

```bash
# Voir les logs en temps réel
ssh pi@192.168.1.74 "docker logs -f supabase-edge-functions"

# Filtrer par fonction
ssh pi@192.168.1.74 "docker logs supabase-edge-functions 2>&1 | grep verify-document"

# Vérifier que les fichiers sont bien déployés
ssh pi@192.168.1.74 "ls -la ~/stacks/supabase/volumes/functions/"
ssh pi@192.168.1.74 "cat ~/stacks/supabase/volumes/functions/main/index.ts | head -20"
```

---

## 📊 Comparaison des Approches

| Aspect | Multi-Functions | Fat Router |
|--------|-----------------|------------|
| **Structure** | 1 dossier = 1 fonction | 1 router + handlers |
| **Déploiement Cloud** | ✅ Natif | ⚠️ Adaptations |
| **Déploiement Self-Hosted** | ❌ Non supporté | ✅ Fonctionne |
| **Maintenance** | ⭐⭐⭐ Simple | ⭐⭐ Moyen |
| **Performance** | ⭐⭐⭐ Isolation | ⭐⭐ Partagé |
| **Debugging** | ⭐⭐⭐ Logs séparés | ⭐⭐ Logs groupés |
| **Code Sharing** | ⭐⭐ Via _shared | ⭐⭐⭐ Direct |

---

## ⚡ Optimisations

### 1. Lazy Loading des Handlers

```typescript
// Au lieu d'importer tous les handlers au démarrage
const routes = {
  'verify-document': async (req, supabase) => {
    const { handleVerifyDocument } = await import('../handlers/verify-document.ts');
    return handleVerifyDocument(req, supabase);
  },
  // ...
};
```

### 2. Caching des Clients Supabase

```typescript
let _supabaseClient: any = null;

function getSupabaseClient() {
  if (!_supabaseClient) {
    _supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );
  }
  return _supabaseClient;
}
```

### 3. Middleware Pattern

```typescript
type Middleware = (req: Request, next: () => Promise<Response>) => Promise<Response>;

const authMiddleware: Middleware = async (req, next) => {
  const authHeader = req.headers.get('authorization');
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 });
  }
  return next();
};

async function applyMiddleware(
  req: Request,
  middlewares: Middleware[],
  handler: () => Promise<Response>
): Promise<Response> {
  let index = 0;

  const next = async (): Promise<Response> => {
    if (index >= middlewares.length) {
      return handler();
    }
    const middleware = middlewares[index++];
    return middleware(req, next);
  };

  return next();
}
```

---

## 🐛 Troubleshooting

### Problème 1 : "Function not found"

**Logs** :
```
[Router] Function not found: verify-document
[Router] Available functions: []
```

**Cause** : Routes map vide ou handler non importé

**Solution** :
```typescript
// Vérifier que les imports sont corrects
import { handleVerifyDocument } from '../handlers/verify-document.ts';

// Vérifier que le handler est dans la map
const routes = {
  'verify-document': handleVerifyDocument, // ← Vérifier cette ligne
};
```

### Problème 2 : "Cannot find module"

**Logs** :
```
error: Module not found "file:///home/deno/functions/handlers/verify-document.ts"
```

**Cause** : Fichier handler n'existe pas sur le Pi

**Solution** :
```bash
# Vérifier que le fichier existe
ssh pi@192.168.1.74 "ls -la ~/stacks/supabase/volumes/functions/handlers/"

# Redéployer si manquant
rsync -avz ./supabase/functions/ pi@192.168.1.74:~/stacks/supabase/volumes/functions/
```

### Problème 3 : Mauvais function name extrait

**Logs** :
```
[Router] Request for function: v1
```

**Cause** : Parsing d'URL incorrect avec Kong strip_path

**Solution** :
```typescript
// Utiliser x-forwarded-path header si disponible
const xForwardedPath = req.headers.get('x-forwarded-path') || req.url;
const url = new URL(xForwardedPath, 'http://localhost');
const pathParts = url.pathname.split('/').filter(Boolean);

// Avec Kong strip_path, le path est déjà clean
let functionName = pathParts[pathParts.length - 1];

console.log('[Router] Full path:', url.pathname);
console.log('[Router] Function name extracted:', functionName);
```

---

## 📚 Ressources

### Exemples Complets
- [main-router.ts complet](./examples/main-router.ts) - Router production-ready
- [verify-document handler](./examples/handlers/verify-document.ts)
- [deploy-functions-to-pi.sh](../../scripts/utils/deploy-edge-functions.sh)

### Documentation
- [Edge Functions Deployment Guide](../guides/EDGE-FUNCTIONS-DEPLOYMENT.md)
- [Supabase Edge Runtime Docs](https://github.com/supabase/edge-runtime)
- [Deno Deploy Docs](https://deno.com/deploy/docs)

---

## ✅ Checklist de Migration

- [ ] Créer dossier `handlers/` avec la logique métier
- [ ] Créer `main/index.ts` avec router
- [ ] Tester localement avec Deno
- [ ] Déployer sur Pi avec rsync
- [ ] Fixer permissions (1000:1000)
- [ ] Redémarrer Edge Functions container
- [ ] Tester chaque fonction via curl
- [ ] Vérifier logs Docker
- [ ] Tester depuis frontend application
- [ ] Créer script de déploiement automatique
- [ ] Documenter les fonctions disponibles

---

## 🎯 Conclusion

Le pattern **Fat Router** est actuellement la **seule solution viable** pour déployer plusieurs Edge Functions sur Supabase auto-hébergé. Bien que moins élégant que le multi-function routing du cloud, il offre :

- ✅ **Compatibilité** : Fonctionne avec Edge Runtime Docker
- ✅ **Flexibilité** : Facile d'ajouter de nouvelles fonctions
- ✅ **Performance** : Overhead minimal (dispatch simple)
- ✅ **Debugging** : Logs centralisés dans un seul container

**Recommandation** : Utilisez cette approche en production jusqu'à ce que Supabase Edge Runtime supporte nativement le multi-function routing en self-hosted.

---

**Version** : 1.0.0
**Dernière mise à jour** : 2025-10-10
**Status** : ✅ Production-Ready
