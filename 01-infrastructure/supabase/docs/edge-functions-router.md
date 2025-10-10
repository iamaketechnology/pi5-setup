# Edge Functions Router - Supabase Self-Hosted

## ⚠️ LIMITATION CRITIQUE

Le **Edge Runtime Docker de Supabase en mode self-hosted NE SUPPORTE PAS le routing automatique** de plusieurs fonctions comme le cloud Supabase.

**Configuration actuelle (incompatible):**
```yaml
# ❌ NE FONCTIONNE PAS en self-hosted Docker
command:
  - start
  # Pas de --main-service = routing automatique (cloud uniquement)
```

**OU**

```yaml
# ❌ NE FONCTIONNE PAS - charge UNE SEULE fonction
command:
  - start
  - --main-service
  - /home/deno/functions  # Essaie de charger toutes les fonctions
```

---

## ✅ SOLUTION : Fat Function Router

Le Edge Runtime self-hosted nécessite **UNE SEULE fonction "main"** qui agit comme router et dispatch vers toutes les fonctions métier.

### Architecture

```
Edge Runtime (Docker)
  |
  └─> main/index.ts (FAT FUNCTION ROUTER)
       |
       ├─> /verify-document     → handleVerifyDocument()
       ├─> /create-access-link  → handleCreateAccessLink()
       ├─> /generate-certificate → handleGenerateCertificate()
       └─> ...
```

---

## 📁 Structure Requise

### Projet Application

```
your-app/
└── supabase/
    └── functions/
        ├── _router/                    # ← NOUVEAU (OBLIGATOIRE)
        │   └── index.ts                # Fat function router
        ├── verify-document/            # Fonctions individuelles (référence)
        │   └── index.ts
        ├── create-access-link/
        │   └── index.ts
        └── ...
```

### Pi (après déploiement)

```
~/stacks/supabase/volumes/functions/
├── main/                          # ← Router déployé ici
│   └── index.ts                   # Copie de _router/index.ts
├── verify-document/               # Copies pour référence/documentation
│   └── index.ts
├── create-access-link/
│   └── index.ts
└── ...
```

---

## 🔧 Configuration Docker Compose

### ✅ Configuration Correcte

```yaml
edge-functions:
  container_name: supabase-edge-functions
  image: supabase/edge-runtime:v1.58.2
  platform: linux/arm64
  restart: unless-stopped
  command:
    - start
    - --main-service
    - /home/deno/functions/main    # ← DOIT pointer vers /main
  volumes:
    - ./volumes/functions:/home/deno/functions:Z
  environment:
    JWT_SECRET: ${JWT_SECRET}
    SUPABASE_URL: http://kong:8000
    SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY}
    SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
    # ✅ IMPORTANT: Fix DB URL (pas de variables vides)
    SUPABASE_DB_URL: postgresql://postgres:${POSTGRES_PASSWORD}@db:5432/postgres
    VERIFY_JWT: ${FUNCTIONS_VERIFY_JWT:-false}
```

---

## 📝 Créer le Router

### Template de Base

**Fichier:** `supabase/functions/_router/index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
};

function getSupabaseClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  );
}

serve(async (req) => {
  // CORS
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const path = url.pathname;

    console.log(`[Router] ${req.method} ${path}`);

    // Route vers les handlers
    switch (path) {
      case '/verify-document':
        return await handleVerifyDocument(req);
      case '/create-access-link':
        return await handleCreateAccessLink(req);
      // ... Ajouter toutes vos fonctions ici
      default:
        return new Response(
          JSON.stringify({ error: `Function not found: ${path}` }),
          { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

// ============================================================================
// HANDLERS - Copier la logique de chaque fonction ICI
// ============================================================================

async function handleVerifyDocument(req: Request) {
  // TODO: Copier TOUT le code de verify-document/index.ts
  // SAUF le appel à serve() du début
  const supabase = getSupabaseClient();
  const { token } = await req.json();

  // ... logique complète de verify-document
}

async function handleCreateAccessLink(req: Request) {
  // TODO: Copier la logique de create-access-link/index.ts
}

// ... Ajouter tous les autres handlers
```

### Implémenter les Handlers

Pour chaque fonction, vous devez :

1. **Ouvrir** `supabase/functions/<nom-fonction>/index.ts`
2. **Copier** TOUT le code SAUF la ligne `serve(async (req) => { ... })`
3. **Coller** dans le handler correspondant du router
4. **Adapter** les imports si nécessaire

**Exemple : verify-document**

```typescript
// ❌ Fonction originale (verify-document/index.ts)
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  const supabase = createClient(...);
  const { token } = await req.json();

  const { data, error } = await supabase.from('access_links')...
  // ... logique
});
```

```typescript
// ✅ Dans le router (_router/index.ts)
async function handleVerifyDocument(req: Request) {
  // Pas de serve(), directement la logique
  const supabase = getSupabaseClient();
  const { token } = await req.json();

  const { data, error } = await supabase.from('access_links')...
  // ... logique

  return new Response(
    JSON.stringify({ success: true, document: data }),
    { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  );
}
```

---

## 🚀 Déploiement

### Option 1 : Script Automatique

```bash
# Utiliser le script de déploiement
cd /path/to/your-app

sudo bash "/path/to/pi5-setup/01-infrastructure/supabase/scripts/utils/deploy-edge-functions.sh" \
  ./supabase/functions \
  pi@pi5.local
```

**⚠️ IMPORTANT:** Le script actuel ne gère PAS encore le router. Il faut le modifier.

### Option 2 : Manuel

```bash
# 1. Créer le dossier main sur le Pi
ssh pi@pi5.local "mkdir -p ~/stacks/supabase/volumes/functions/main"

# 2. Copier le router comme fonction main
scp ./supabase/functions/_router/index.ts pi@pi5.local:~/stacks/supabase/volumes/functions/main/index.ts

# 3. (Optionnel) Copier les autres fonctions pour référence
for dir in ./supabase/functions/*/; do
  func=$(basename "$dir")
  if [ "$func" != "_router" ]; then
    ssh pi@pi5.local "mkdir -p ~/stacks/supabase/volumes/functions/$func"
    scp -r "$dir"* "pi@pi5.local:~/stacks/supabase/volumes/functions/$func/"
  fi
done

# 4. Vérifier docker-compose.yml
ssh pi@pi5.local "grep -A 2 '\-\- start' ~/stacks/supabase/docker-compose.yml"
# Doit afficher:
#     - start
#     - --main-service
#     - /home/deno/functions/main

# 5. Si incorrect, corriger:
ssh pi@pi5.local "cd ~/stacks/supabase && \
  sed -i 's|/home/deno/functions$|/home/deno/functions/main|' docker-compose.yml"

# 6. Redémarrer
ssh pi@pi5.local "cd ~/stacks/supabase && docker compose restart edge-functions"

# 7. Attendre et tester
sleep 12
curl -X POST 'http://192.168.1.74:8001/functions/v1/verify-document' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -d '{"token":"test"}'

# Résultat attendu: JSON structuré (pas "Hello undefined!")
```

---

## 🧪 Vérification

### Test 1 : Vérifier que le Router est Chargé

```bash
# Si retourne "Hello undefined!" = Router pas chargé
# Si retourne JSON structuré = Router fonctionne ✅
curl -X POST 'http://192.168.1.74:8001/functions/v1/verify-document' \
  -H 'Authorization: Bearer <ANON_KEY>' \
  -d '{"token":"test"}'
```

**Résultat attendu:**
```json
{
  "success": false,
  "error": "Document not found or access link invalid",
  "details": "Access link not found"
}
```

**PAS:**
```json
{
  "message": "Hello undefined!",
  "timestamp": "...",
  "runtime": "Supabase Edge Functions on Raspberry Pi 5"
}
```

### Test 2 : Vérifier Toutes les Fonctions

```bash
# Tester chaque fonction (attend 404 ou erreur structurée)
for func in verify-document create-access-link generate-certificate; do
  echo "Testing $func..."
  curl -s -w "\nHTTP: %{http_code}\n" \
    -X POST "http://192.168.1.74:8001/functions/v1/$func" \
    -H 'Authorization: Bearer <ANON_KEY>' \
    -d '{"test":"data"}'
  echo ""
done
```

### Test 3 : Logs

```bash
# Vérifier les logs pour les erreurs
ssh pi@pi5.local "docker logs supabase-edge-functions --tail 50"

# Chercher:
# ✅ "[Router] POST /verify-document"
# ❌ "thread panicked" ou "Error: main worker boot error"
```

---

## 📊 Limitations et Alternatives

### ❌ Limitations du Router

1. **Maintenabilité**: Tout le code dans un seul fichier
2. **Taille**: Le fichier `main/index.ts` peut devenir très gros
3. **Debugging**: Plus difficile de débugger qu'avec des fonctions séparées
4. **Hot Reload**: Nécessite un redémarrage complet pour chaque modification

### ✅ Alternative : Configuration Hybride

Si le router devient trop complexe, utilisez une configuration hybride :

- **Pi** : PostgreSQL, PostgREST, Auth, Storage
- **Cloud Supabase** : Edge Functions uniquement

**Avantages:**
- ✅ Toutes les fonctions séparées
- ✅ Routing automatique
- ✅ Hot reload
- ✅ Meilleure maintenabilité

**Configuration:**
```typescript
// Dans votre app
const supabase = createClient(
  'http://192.168.1.74:8001',  // DB sur Pi
  ANON_KEY,
  {
    global: {
      headers: {
        // Edge Functions sur cloud
        'X-Edge-Functions-URL': 'https://emdyhdijspozmvfdzylm.supabase.co'
      }
    }
  }
);
```

---

## 📚 Ressources

- [Supabase Self-Hosting Functions](https://supabase.com/docs/reference/self-hosting-functions/introduction)
- [Edge Runtime GitHub](https://github.com/supabase/edge-runtime)
- [Deno Deploy](https://deno.com/deploy/docs)

---

## 🔄 Historique

### Version 1.0.0 - 10 Octobre 2025
- Documentation initiale
- Template de router
- Instructions de déploiement

---

**Créé par:** Claude Code
**Date:** 10 Octobre 2025
**Dernière mise à jour:** 10 Octobre 2025
