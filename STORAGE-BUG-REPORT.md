# Supabase Storage API Bug Report - search_path Configuration Ignored

## 🐛 Bug Summary

**storage-api v1.11.6** completely ignores ALL `search_path` configuration methods, causing `relation "buckets" does not exist` errors when storage tables are in the `storage` schema (as per official Supabase self-hosting setup).

## 📊 Environment

- **Storage API Version**: v1.11.6 (and v1.27.6 - also affected)
- **Docker Image**: `supabase/storage-api:v1.11.6`
- **PostgreSQL Version**: 15.8 (supabase/postgres:15.8.1.060)
- **Platform**: ARM64 (Raspberry Pi 5)
- **Schema Setup**: Tables in `storage` schema (official Supabase structure)

## 🔍 Root Cause

The storage-api uses **Knex.js** with connection pooling. All attempts to configure `search_path` are ignored:

1. **URL parameters** - `?search_path=storage,public` ❌
2. **PGOPTIONS env var** - Only applies to initial connection, not pooled connections ❌
3. **DATABASE_SEARCH_PATH env var** - Listed in official `.env.sample` but not used by code ❌
4. **ALTER ROLE search_path** - Overridden by Knex connection settings ❌
5. **ALTER DATABASE search_path** - Same issue ❌

The Knex configuration appears to hardcode schema or set an empty search_path that overrides all PostgreSQL settings.

## 🧪 Reproduction Steps

### 1. Setup PostgreSQL with storage schema

```sql
-- Create storage schema (as per official Supabase setup)
CREATE SCHEMA storage;

-- Create tables in storage schema
CREATE TABLE storage.buckets (
    id text PRIMARY KEY,
    name text NOT NULL,
    public boolean DEFAULT false,
    owner uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE TABLE storage.objects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bucket_id text REFERENCES storage.buckets(id),
    name text,
    owner uuid,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    path_tokens text[] GENERATED ALWAYS AS (string_to_array(name, '/')) STORED
);
```

### 2. Configure storage-api with DATABASE_URL

```yaml
# docker-compose.yml
services:
  storage:
    image: supabase/storage-api:v1.11.6
    environment:
      DATABASE_URL: postgres://postgres:password@db:5432/postgres?sslmode=disable&search_path=storage,public
```

### 3. Test the API

```bash
curl -H "apikey: YOUR_SERVICE_KEY" \
     -H "Authorization: Bearer YOUR_SERVICE_KEY" \
     http://localhost:5000/bucket
```

**Expected**: List of buckets
**Actual**:
```json
{
  "statusCode": "500",
  "code": "DatabaseError",
  "error": "DatabaseError",
  "message": "select \"id\", \"name\", \"public\", \"owner\", \"created_at\", \"updated_at\" from \"buckets\" - relation \"buckets\" does not exist"
}
```

## 🧪 Tests Performed

We tested **EVERY** possible search_path configuration method:

### Test 1: URL Parameter (Official method)
```yaml
DATABASE_URL: postgres://postgres:password@db:5432/postgres?search_path=storage,public
```
**Result**: ❌ Ignored

### Test 2: PGOPTIONS Environment Variable
```yaml
PGOPTIONS: "-c search_path=storage,public"
```
**Result**: ❌ Only applies to first connection, not pooled connections

### Test 3: DATABASE_SEARCH_PATH (From official .env.sample)
```yaml
DATABASE_SEARCH_PATH: storage,public
```
**Result**: ❌ Variable not used by storage-api code

### Test 4: ALTER ROLE
```sql
ALTER ROLE postgres SET search_path TO storage, public;
ALTER ROLE service_role SET search_path TO storage, public;
```
**Result**: ❌ Overridden by Knex

### Test 5: ALTER DATABASE
```sql
ALTER DATABASE postgres SET search_path TO storage, public;
```
**Result**: ❌ Same issue

### Test 6: PostgreSQL Views in public schema
```sql
CREATE VIEW public.buckets AS SELECT * FROM storage.buckets;
CREATE VIEW public.objects AS SELECT * FROM storage.objects;
```
**Result**: ❌ Still queries `buckets` without schema qualifier

### Test 7: Copy tables to public schema
```sql
CREATE TABLE public.buckets (LIKE storage.buckets INCLUDING ALL);
INSERT INTO public.buckets SELECT * FROM storage.buckets;
```
**Result**: ✅ **WORKAROUND WORKS** - storage-api finds tables

## ✅ Workaround (Temporary Solution)

Copy all storage tables to the `public` schema:

```sql
-- Drop existing tables
DROP TABLE IF EXISTS public.objects CASCADE;
DROP TABLE IF EXISTS public.buckets CASCADE;
DROP TABLE IF EXISTS public.migrations CASCADE;
DROP TABLE IF EXISTS public.s3_multipart_uploads_parts CASCADE;
DROP TABLE IF EXISTS public.s3_multipart_uploads CASCADE;

-- Create tables in public
CREATE TABLE public.buckets (LIKE storage.buckets INCLUDING ALL);
CREATE TABLE public.objects (LIKE storage.objects INCLUDING ALL);
CREATE TABLE public.migrations (LIKE storage.migrations INCLUDING ALL);
CREATE TABLE public.s3_multipart_uploads (LIKE storage.s3_multipart_uploads INCLUDING ALL);
CREATE TABLE public.s3_multipart_uploads_parts (LIKE storage.s3_multipart_uploads_parts INCLUDING ALL);

-- Copy data (exclude generated columns like path_tokens)
INSERT INTO public.buckets SELECT * FROM storage.buckets;
INSERT INTO public.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata)
  SELECT id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata, version, owner_id, user_metadata
  FROM storage.objects;
INSERT INTO public.migrations SELECT * FROM storage.migrations;
INSERT INTO public.s3_multipart_uploads SELECT * FROM storage.s3_multipart_uploads;
INSERT INTO public.s3_multipart_uploads_parts SELECT * FROM storage.s3_multipart_uploads_parts;

-- Grant permissions
GRANT ALL ON public.buckets TO postgres, service_role, authenticated, anon;
GRANT ALL ON public.objects TO postgres, service_role, authenticated, anon;
GRANT ALL ON public.migrations TO postgres, service_role, authenticated, anon;
GRANT ALL ON public.s3_multipart_uploads TO postgres, service_role, authenticated, anon;
GRANT ALL ON public.s3_multipart_uploads_parts TO postgres, service_role, authenticated, anon;
```

After this workaround, storage-api works correctly.

## 🔧 Proposed Fix

The issue is likely in the Knex configuration. The storage-api should explicitly set `searchPath` in its Knex config:

```typescript
// Current (implicit, broken)
const knex = Knex({
  client: 'pg',
  connection: process.env.DATABASE_URL,
  pool: { min: 2, max: 10 }
})

// Proposed fix
const knex = Knex({
  client: 'pg',
  connection: process.env.DATABASE_URL,
  pool: { min: 2, max: 10 },
  searchPath: (process.env.DATABASE_SEARCH_PATH || 'public').split(',')
})
```

**References**:
- Knex documentation: https://knexjs.org/guide/#configuration-options
- searchPath option: https://github.com/knex/knex/blob/master/types/index.d.ts#L2089

## 📝 Additional Information

### Database Logs

PostgreSQL logs show storage-api queries without schema qualifier:

```
2025-10-05 19:54:15.711 UTC [1] ERROR:  select "id", "name", "public", "owner", "created_at", "updated_at", "file_size_limit", "allowed_mime_types" from "buckets"
2025-10-05 19:54:15.711 UTC [1] DETAIL:  relation "buckets" does not exist
```

Expected query should be:
```sql
SELECT "id", "name", "public", "owner", "created_at", "updated_at" FROM "storage"."buckets"
```

### Environment Variables Tested

From official `.env.sample` (https://github.com/supabase/storage/blob/master/.env.sample):

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres
DATABASE_SEARCH_PATH=storage,public  # ← This variable is ignored
```

### Version Information

```bash
# Storage API container
docker inspect supabase-storage | grep -A 5 Env
# Shows: DATABASE_URL, DATABASE_SEARCH_PATH (both present)

# Storage API logs
docker logs supabase-storage
# Shows queries to "buckets" without "storage." prefix
```

## 🎯 Expected Behavior

1. `DATABASE_SEARCH_PATH` environment variable should be respected
2. OR `?search_path=` URL parameter should work
3. OR explicit schema qualifier `storage.buckets` should be used in queries

## 📚 References

- Official Supabase self-hosting guide: https://supabase.com/docs/guides/self-hosting
- PostgreSQL search_path documentation: https://www.postgresql.org/docs/current/ddl-schemas.html#DDL-SCHEMAS-PATH
- Knex.js searchPath option: https://knexjs.org/guide/#configuration-options
- Related issue: https://github.com/supabase/storage/issues/491 (PGOPTIONS)

## 🤝 Willingness to Contribute

I'm willing to submit a PR to fix this issue if the maintainers can confirm the proposed approach (adding `searchPath` to Knex config).

---

**Tested versions**: v1.11.6, v1.27.6 (both affected)
**Platform**: Docker on ARM64 (Raspberry Pi 5)
**Workaround status**: ✅ Confirmed working (copy tables to public schema)
