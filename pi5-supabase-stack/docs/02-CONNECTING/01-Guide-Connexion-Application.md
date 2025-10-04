# 🔌 Connecter votre application à Supabase (Self‑Hosted sur Raspberry Pi 5)

> Guide complet pour configurer l’URL, les clés, les clients (JS/TS, Flutter/Dart, Python), la sécurité (RLS), les tests et le dépannage.

---

## 🎯 Objectif

- Récupérer l’URL d’API et les clés (anon, service_role, JWT)
- Initialiser un client Supabase (JS/TS, Flutter/Dart, Python)
- Utiliser Auth, REST, Realtime, Storage, Edge Functions
- Mettre en place RLS, variables d’environnement, CORS/redirects
- Tester rapidement et dépanner

---

## ✅ Prérequis

- Supabase installé et « healthy » via les scripts du repo
- IP locale de votre Pi 5 (ex. `192.168.1.50`)
- Ports ouverts en LAN: `3000` (Studio), `8000` (API Gateway/Kong)
- Vérification kernel: `getconf PAGESIZE` doit renvoyer `4096`

---

## 🔎 Récupérer l’URL et les clés

Exécutez le script utilitaire depuis votre Pi 5:

```bash
curl -fsSL https://raw.githubusercontent.com/iamaketechnology/pi5-setup/main/pi5-supabase-stack/scripts/utils/get-supabase-info.sh | sudo bash
```

Vous obtiendrez:
- URL API: `http://<IP_DU_PI>:8000`
- `anon` key (client, publique)
- `service_role` key (serveur, SECRÈTE)
- `JWT secret`
- Accès Studio: `http://<IP_DU_PI>:3000`

Points d’extrémité (Kong):
- Auth: `/auth/v1`
- REST: `/rest/v1`
- Storage: `/storage/v1`
- Realtime: `/realtime/v1`
- Functions: `/functions/v1`

> Utilisez toujours la base `http://<IP_PI>:8000` en LAN. En production publique, configurez un domaine et du HTTPS (voir plus bas).

---

## 🔐 Variables d’environnement (recommandé)

Web (Next.js/SPA):

```env
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.50:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=collez_votre_anon_key_ici
```

Backend/Node:

```env
SUPABASE_URL=http://192.168.1.50:8000
SUPABASE_SERVICE_ROLE_KEY=collez_votre_service_role_key_ici
DATABASE_URL=postgres://postgres:<motdepasse>@192.168.1.50:5432/postgres
```

Flutter/Dart (selon votre système de config):

```env
SUPABASE_URL=http://192.168.1.50:8000
SUPABASE_ANON_KEY=collez_votre_anon_key_ici
```

Python:

```env
SUPABASE_URL=http://192.168.1.50:8000
SUPABASE_ANON_KEY=collez_votre_anon_key_ici
```

> Ne jamais exposer `service_role` ou `JWT secret` côté client.

---

## 🟩 Client JavaScript/TypeScript (supabase-js)

Installation:

```bash
npm i @supabase/supabase-js
```

Initialisation:

```ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: { persistSession: true, autoRefreshToken: true },
  global: { headers: { 'x-application-name': 'myapp/web' } }
})
```

Auth (email/password):

```ts
await supabase.auth.signUp({ email, password })
const { data, error } = await supabase.auth.signInWithPassword({ email, password })
```

REST (PostgREST):

```ts
const { data, error } = await supabase
  .from('todos')
  .select('*')
  .order('id', { ascending: false })
```

Realtime (changements Postgres):

```ts
const channel = supabase
  .channel('public:todos')
  .on('postgres_changes', { event: '*', schema: 'public', table: 'todos' }, payload => {
    console.log('Changement:', payload)
  })
  .subscribe()
```

Storage (upload):

```ts
const filePath = `avatars/${user.id}.png`
const { data, error } = await supabase
  .storage
  .from('avatars')
  .upload(filePath, file, { upsert: true })
```

Edge Functions:

```ts
const { data, error } = await supabase
  .functions
  .invoke('hello', { body: { name: 'Pi5' } })
```

---

## 🟦 Client Flutter/Dart

Installation:

```bash
flutter pub add supabase_flutter
```

Initialisation:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);

final supabase = Supabase.instance.client;
```

Auth:

```dart
await supabase.auth.signUp(email: email, password: password);
final res = await supabase.auth.signInWithPassword(email: email, password: password);
```

REST:

```dart
final res = await supabase.from('todos').select().order('id');
```

Realtime:

```dart
final channel = supabase.channel('public:todos')
  ..onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'todos',
    callback: (payload) => print(payload),
  )
  ..subscribe();
```

Storage:

```dart
await supabase.storage.from('avatars').upload('avatars/${userId}.png', file);
```

---

## 🐍 Client Python

Installation:

```bash
pip install supabase
```

Initialisation et requête:

```python
from supabase import create_client
import os

supabase = create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_ANON_KEY"])
res = supabase.table("todos").select("*").execute()
print(res.data)
```

---

## 🐘 Connexion Postgres (serveur/ETL)

- DSN: `postgres://postgres:<motdepasse>@<IP_PI>:5432/postgres`
- À utiliser côté serveur (scripts, ETL, ORM: Prisma, SQLAlchemy, etc.) — jamais côté client.

---

## 🔁 Auth: redirections et CORS

- Redirections (magic links, OAuth): Studio → Auth → Redirect URLs
  - Ajouter vos origines: `http://localhost:3000`, `http://192.168.1.50:3000`, `https://app.mondomaine.com`
- CORS: si erreurs, ajouter l’origine côté Auth et vérifier les en-têtes. En dernier recours, ajuster la config GoTrue/Kong.
- Mobile/dev sans HTTPS: iOS/Android exigent des exceptions “cleartext” en dev. Pour prod, configurez HTTPS.

---

## 🛡️ Sécurité & RLS (exemples)

Activer RLS:

```sql
alter table public.todos enable row level security;
```

Politiques usuelles:

```sql
-- Lecture: utilisateurs authentifiés
create policy "read own or public todos"
on public.todos
for select
to authenticated
using (true);

-- Écriture: restreindre à l’utilisateur
create policy "insert own todos"
on public.todos
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "update own todos"
on public.todos
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);
```

Table publique en lecture:

```sql
create policy "read public"
on public.posts
for select
to anon
using (true);
```

---

## 🧪 Tests rapides (curl)

REST:

```bash
curl -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <ANON_KEY>" \
     "http://<IP_PI>:8000/rest/v1/todos?select=*"
```

Auth health:

```bash
curl -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <ANON_KEY>" \
     "http://<IP_PI>:8000/auth/v1/health"
```

Buckets Storage:

```bash
curl -H "apikey: <ANON_KEY>" \
     -H "Authorization: Bearer <ANON_KEY>" \
     "http://<IP_PI>:8000/storage/v1/bucket"
```

---

## 🌍 Accès LAN vs Internet

- LAN: `http://<IP_PI>:8000` (dev/test)
- Internet/Production:
  - Reverse proxy (Traefik/Caddy) + domaine + certificats SSL
  - `SUPABASE_URL` en `https://api.mondomaine.com`
  - Ouvrir uniquement 80/443 (rediriger 80 → 443)
  - UFW/Fail2ban actifs, sauvegardes et monitoring en place

---

## 🩺 Dépannage rapide

- 401/invalid token: clé incorrecte, RLS bloque, horloge NTP, mauvaise URL (manque `:8000`)
- CORS: ajouter l’origine dans Auth, vérifier en-têtes, tester via curl
- 404 `/rest/v1`: Kong non joignable → `cd ~/stacks/supabase && docker compose ps`
- Realtime silencieux: filtre `postgres_changes` incorrect, RLS, triggers OK
- Storage upload: bucket manquant ou policy absente (créer via Studio + policy)
- Clés perdues: relancer `get-supabase-info.sh` ou vérifier variables dans Portainer/compose

---

## ✅ Checklist mise en production

- Domaine + HTTPS opérationnels
- `SUPABASE_URL` en HTTPS (pas d’IP brute)
- Secrets en variables d’environnement (jamais commités)
- RLS activé sur les tables sensibles
- Redirect URLs exactes (Auth)
- Sauvegardes Postgres planifiées et testées
- Logs/Monitoring (Portainer, métriques, alertes)

---

## 📎 Annexe: Modèles d’environnement

Web (Next.js):

```env
NEXT_PUBLIC_SUPABASE_URL=http://192.168.1.50:8000
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxxxxxxx
```

Backend/Node:

```env
SUPABASE_URL=http://192.168.1.50:8000
SUPABASE_SERVICE_ROLE_KEY=xxxxxxxx
DATABASE_URL=postgres://postgres:xxxxxxxx@192.168.1.50:5432/postgres
```

Flutter/Dart & Python: voir sections dédiées ci‑dessus.

