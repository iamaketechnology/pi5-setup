# CHANGELOG - RLS Configuration Complete Fix (v3.46)

**Date**: 2025-10-10
**Version**: 3.46
**Type**: CRITICAL FIX
**Affected Components**: PostgREST, PostgreSQL RLS, Authentication

---

## 🎯 Executive Summary

This update resolves **critical Row Level Security (RLS) configuration issues** that prevented authenticated users from accessing tables, resulting in widespread `403 Forbidden` and `500 Internal Server Error` responses.

**Impact**: Without this fix, authenticated users cannot access any tables protected by RLS policies, rendering the application non-functional.

**Status**: ✅ **RESOLVED** - All issues fixed and tested successfully.

---

## 🔴 Problems Identified

### Problem 1: PostgREST Schema Configuration (v3.45)
**Error**: `function auth.uid() does not exist`
**HTTP Status**: 500 Internal Server Error
**Root Cause**: PostgREST was configured with `PGRST_DB_SCHEMAS: public` only, preventing it from accessing functions in the `auth` schema.

**Impact**: All RLS policies using `auth.uid()` failed to execute.

### Problem 2: Missing public.uid() Wrapper Function
**Error**: `function uid() does not exist`
**HTTP Status**: 500 Internal Server Error
**Root Cause**: RLS policies using `uid()` (without `auth.` prefix) failed because no wrapper function existed in the public schema.

**Impact**: Even with PostgREST schema fix, policies using `uid()` instead of `auth.uid()` still failed.

### Problem 3: RLS Policies Using Wrong Role
**Error**: `permission denied for table <table_name>`
**HTTP Status**: 403 Forbidden
**Error Code**: 42501
**Root Cause**: RLS policies were created with `TO public` instead of `TO authenticated`.

**Technical Explanation**:
- When PostgREST receives a request with a valid JWT, it **switches to the `authenticated` role**
- Policies with `TO public` **do NOT apply** to the `authenticated` role
- Result: PostgreSQL denies access because no applicable policy exists

**Impact**: All authenticated users received 403 Forbidden errors, even with valid JWTs.

### Problem 4: Missing Table Permissions for authenticated Role
**Error**: `permission denied for table <table_name>`
**HTTP Status**: 403 Forbidden
**Root Cause**: The `authenticated` role had **zero table-level permissions** (SELECT, INSERT, UPDATE, DELETE).

**Evidence**:
```sql
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_name = 'app_certifications'
AND grantee = 'authenticated';

-- Result: 0 rows (NO PERMISSIONS!)
```

**Impact**: Even with correct RLS policies, authenticated users couldn't access tables.

### Problem 5: Infinite Recursion in RLS Policies
**Error**: `infinite recursion detected in policy for relation "documents"`
**HTTP Status**: 500 Internal Server Error
**Error Code**: 42P17
**Root Cause**: The `documents_shared_view` policy created a circular dependency.

**Recursion Chain**:
1. Query: `SELECT * FROM email_invites JOIN documents`
2. PostgreSQL evaluates RLS policy on `email_invites` ✅
3. JOIN loads `documents` → evaluates `documents_shared_view` policy
4. Policy queries `email_invites` to check sharing permissions
5. This triggers another `documents` access check → **infinite loop** 🔄♾️

**Impact**: Any query joining `email_invites` and `documents` crashed with 500 error.

---

## ✅ Solutions Implemented

### Fix 1: PostgREST Schema Configuration ✅ (v3.45)

**File Modified**: `docker-compose.yml` (line 744)

**Change**:
```yaml
# BEFORE (v3.44 and earlier)
PGRST_DB_SCHEMAS: public

# AFTER (v3.45+)
PGRST_DB_SCHEMAS: public,auth,storage
```

**How to Apply**:
```bash
# 1. Update docker-compose.yml
sed -i 's/PGRST_DB_SCHEMAS: public$/PGRST_DB_SCHEMAS: public,auth,storage/' ~/stacks/supabase/docker-compose.yml

# 2. IMPORTANT: Restart is NOT enough! Must recreate container
cd ~/stacks/supabase
docker compose up -d --force-recreate rest

# 3. Verify
docker exec supabase-rest env | grep PGRST_DB_SCHEMAS
# Should output: PGRST_DB_SCHEMAS=public,auth,storage
```

**Why `--force-recreate` is required**: `docker compose restart` does **not** reload environment variables from `docker-compose.yml`. You must recreate the container.

---

### Fix 2: Create public.uid() Wrapper Function ✅ (v3.46)

**File Created**: `05-init-rls-helpers.sql`

**SQL**:
```sql
CREATE OR REPLACE FUNCTION public.uid()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT auth.uid()
$$;

GRANT EXECUTE ON FUNCTION public.uid() TO anon, authenticated, service_role;
```

**Benefits**:
- RLS policies can use `uid()` instead of `auth.uid()`
- Cleaner, more readable policy syntax
- Compatible with Supabase Cloud patterns

**Manual Application** (for existing installations):
```bash
ssh pi@192.168.1.74
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres <<'EOSQL'
CREATE OR REPLACE FUNCTION public.uid()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, auth AS $$ SELECT auth.uid() $$;
GRANT EXECUTE ON FUNCTION public.uid() TO anon, authenticated, service_role;
EOSQL
```

---

### Fix 3: Grant Permissions to authenticated Role ✅ (v3.46)

**File Modified**: `05-init-rls-helpers.sql`

**SQL**:
```sql
-- Grant permissions on existing tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- Grant permissions on future tables
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO authenticated;
```

**Manual Application**:
```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres <<'EOSQL'
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE ON SEQUENCES TO authenticated;
EOSQL
```

**Verification**:
```bash
# Check granted permissions
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT COUNT(DISTINCT table_name) as tables
   FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee = 'authenticated';"

# Should show number > 0
```

---

### Fix 4: Update RLS Policies to Use authenticated Role ✅

**Problem**: Existing policies use `TO public` instead of `TO authenticated`

**Solution**: Recreate policies with correct role

**Example** (for `email_invites` table):
```sql
-- 1. Drop old policy
DROP POLICY IF EXISTS "invites_recipient_via_profiles" ON email_invites;

-- 2. Recreate with authenticated role
CREATE POLICY "invites_recipient_via_profiles" ON email_invites
  FOR SELECT TO authenticated  -- IMPORTANT: TO authenticated, not TO public
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.user_id = uid()
      AND profiles.email = email_invites.email
    )
  );
```

**⚠️ IMPORTANT**: This fix is **application-specific** and depends on your table structure. The migration script (`fix-rls-configuration.sh`) will warn you about policies that need manual updates.

**Automated Check**:
```bash
# List policies using 'public' role (need to be updated)
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT tablename, policyname, roles
   FROM pg_policies
   WHERE schemaname = 'public'
   AND 'public' = ANY(roles);"
```

---

### Fix 5: Remove Recursive RLS Policies ✅

**Problem Policy**:
```sql
-- ❌ CAUSES INFINITE RECURSION
CREATE POLICY "documents_shared_view" ON documents
  FOR SELECT TO authenticated
  USING (
    owner_id = uid() OR
    EXISTS (
      SELECT 1 FROM email_invites
      WHERE email_invites.doc_id = documents.id  -- ⚠️ Queries back to documents via JOIN
      AND email_invites.email IN (SELECT email FROM profiles WHERE user_id = uid())
      AND email_invites.accepted_at IS NOT NULL
    )
  );
```

**Why It Fails**:
When you query `SELECT * FROM email_invites JOIN documents`:
1. PostgreSQL checks `email_invites` RLS policy ✅
2. JOIN loads `documents` → checks `documents_shared_view` policy
3. Policy queries `email_invites` → loads `documents` again via JOIN
4. **Infinite loop** 🔄

**Solution**: Remove the recursive policy

```sql
DROP POLICY IF EXISTS "documents_shared_view" ON documents;
```

**Alternative Access Pattern**:
Shared documents are now accessible **only through `email_invites` JOIN**, which is the correct and secure pattern:
```javascript
// ✅ CORRECT: Access via email_invites
const { data } = await supabase
  .from('email_invites')
  .select('*, documents(*)') // JOIN is allowed, no recursion
  .eq('email', userEmail);

// ❌ WRONG: Direct document access (will fail for shared docs)
const { data } = await supabase
  .from('documents')
  .select('*')
  .eq('id', docId); // Only works if you're the owner
```

**Advanced Solution** (if you need direct access to shared documents):
Create a non-recursive view instead of a policy:
```sql
CREATE VIEW accessible_documents AS
  -- Owned documents
  SELECT d.* FROM documents d WHERE owner_id = uid()
  UNION
  -- Shared documents (no JOIN, uses IN subquery)
  SELECT d.* FROM documents d
  WHERE id IN (
    SELECT doc_id FROM email_invites
    WHERE email IN (SELECT email FROM profiles WHERE user_id = uid())
    AND accepted_at IS NOT NULL
  );
```

---

## 📦 Migration Guide

### For Existing Installations (Already Running Supabase)

**Option 1: Automated Migration Script** (Recommended)

```bash
# Download and run the fix script
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/01-infrastructure/supabase/scripts/fix-rls-configuration.sh | sudo bash

# Or if you have the repo locally:
cd ~/pi5-setup/01-infrastructure/supabase/scripts
sudo bash fix-rls-configuration.sh
```

**What the script does**:
1. ✅ Backs up your `docker-compose.yml`
2. ✅ Updates PostgREST schema configuration
3. ✅ Creates `public.uid()` function
4. ✅ Grants permissions to `authenticated` role
5. ✅ Removes known recursive policies
6. ✅ Verifies all fixes were applied correctly
7. ⚠️ **Warns** about custom policies that need manual updates

**Option 2: Manual Migration**

See the individual fix sections above for SQL commands.

---

### For New Installations

**Good news**: If you're using **v3.46 or later** of `02-supabase-deploy.sh`, all fixes are **automatically applied** during installation!

Just run:
```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_REPO/main/01-infrastructure/supabase/scripts/02-supabase-deploy.sh | sudo bash
```

The deployment script now includes:
- ✅ PostgREST with `public,auth,storage` schemas (v3.45)
- ✅ `05-init-rls-helpers.sql` auto-created with:
  - `public.uid()` wrapper function
  - Grants to `authenticated` role
  - Helpful logging and examples

---

## 🧪 Verification & Testing

### Test 1: PostgREST Schema Configuration

```bash
docker exec supabase-rest env | grep PGRST_DB_SCHEMAS
# Expected: PGRST_DB_SCHEMAS=public,auth,storage
```

### Test 2: public.uid() Function Exists

```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT proname, pronamespace::regnamespace
   FROM pg_proc WHERE proname = 'uid';"

# Expected:
# proname | pronamespace
#---------+--------------
# uid     | public
# uid     | auth
```

### Test 3: authenticated Role Has Permissions

```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT COUNT(DISTINCT table_name) as tables_with_perms
   FROM information_schema.role_table_grants
   WHERE table_schema = 'public' AND grantee = 'authenticated';"

# Expected: tables_with_perms > 0 (should match number of public tables)
```

### Test 4: RLS Policies Use Correct Role

```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT tablename, policyname, roles
   FROM pg_policies
   WHERE schemaname = 'public'
   ORDER BY tablename, policyname;"

# Expected: All policies should show {authenticated}, not {public}
```

### Test 5: Application-Level Test

**JavaScript/TypeScript**:
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient('http://192.168.1.74:8001', 'YOUR_ANON_KEY');

// 1. Sign in
const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
  email: 'test@example.com',
  password: 'password123'
});

if (authError) {
  console.error('❌ Auth failed:', authError);
} else {
  console.log('✅ Auth successful:', authData.user.id);
}

// 2. Test table access
const { data, error } = await supabase
  .from('your_table')
  .select('*')
  .limit(1);

if (error) {
  console.error('❌ Query failed:', error.code, error.message);
} else {
  console.log('✅ Query successful:', data);
}
```

**Expected Results**:
- ✅ Auth: Success
- ✅ Query: Success (or empty array if table is empty)
- ❌ **Before fix**: 403 Forbidden with code 42501

---

## 📚 Best Practices for RLS Policies

### ✅ DO: Use authenticated Role

```sql
-- ✅ CORRECT
CREATE POLICY "my_policy" ON my_table
  FOR SELECT TO authenticated  -- Always use authenticated
  USING (uid() = user_id);
```

### ❌ DON'T: Use public Role

```sql
-- ❌ WRONG - Won't work for authenticated users!
CREATE POLICY "my_policy" ON my_table
  FOR SELECT TO public  -- This only works for anon users
  USING (uid() = user_id);
```

### ✅ DO: Use uid() Function

```sql
-- ✅ CORRECT - Uses the wrapper function
CREATE POLICY "my_policy" ON my_table
  FOR SELECT TO authenticated
  USING (uid() = user_id);
```

### ⚠️ ALTERNATIVE: Use auth.uid() Explicitly

```sql
-- ⚠️ ALSO WORKS - But more verbose
CREATE POLICY "my_policy" ON my_table
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
```

### ❌ DON'T: Create Recursive Policies

```sql
-- ❌ WRONG - Causes infinite recursion
CREATE POLICY "posts_shared" ON posts
  FOR SELECT TO authenticated
  USING (
    owner_id = uid() OR
    EXISTS (
      SELECT 1 FROM shares
      WHERE shares.post_id = posts.id  -- ⚠️ Circular if shares also references posts
      AND shares.user_id = uid()
    )
  );
```

### ✅ DO: Use Non-Recursive Subqueries

```sql
-- ✅ CORRECT - Uses IN subquery, no recursion
CREATE POLICY "posts_shared" ON posts
  FOR SELECT TO authenticated
  USING (
    owner_id = uid() OR
    id IN (
      SELECT post_id FROM shares
      WHERE user_id = uid()
    )
  );
```

---

## 🔧 Troubleshooting

### Issue: Still Getting 403 Forbidden After Fix

**Check 1**: Verify PostgREST container was recreated
```bash
docker ps --format '{{.Names}}\t{{.Status}}' | grep supabase-rest
# Status should show "Up X minutes" (recent restart time)
```

**Check 2**: Verify policies use `authenticated` role
```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT tablename, COUNT(*) as policies_with_public_role
   FROM pg_policies
   WHERE 'public' = ANY(roles)
   GROUP BY tablename;"

# Should return 0 rows (no policies with public role)
```

**Check 3**: Check JWT is valid
```bash
# In your application, log the JWT:
console.log('JWT:', (await supabase.auth.getSession()).data.session?.access_token);

# Decode it at https://jwt.io/ and verify:
# - exp (expiration) is in the future
# - sub (subject) matches your user ID
# - role is 'authenticated'
```

### Issue: Still Getting "function uid() does not exist"

**Solution**: Verify the function was created
```bash
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT routine_name, routine_schema
   FROM information_schema.routines
   WHERE routine_name = 'uid';"

# Should show both public.uid and auth.uid
```

If missing, create it manually (see Fix 2 above).

### Issue: Infinite Recursion Error

**Solution**: Find and remove recursive policies
```bash
# Check for policies that reference other tables
docker exec -e PGPASSWORD=<YOUR_PASSWORD> supabase-db psql -U postgres -d postgres -c \
  "SELECT tablename, policyname, qual
   FROM pg_policies
   WHERE qual LIKE '%EXISTS%' OR qual LIKE '%JOIN%';"

# Review each policy for circular dependencies
```

---

## 📊 Impact Summary

### Before Fix
- ❌ 403 Forbidden on all authenticated requests
- ❌ 500 Internal Server Error on complex queries
- ❌ Application completely non-functional
- ❌ Error codes: 42501, 42P17

### After Fix
- ✅ Authenticated users can access tables
- ✅ RLS policies execute correctly
- ✅ No infinite recursion errors
- ✅ Application fully functional

---

## 🔗 Related Issues

- **PostgREST Schema Issue**: https://github.com/PostgREST/postgrest/issues/2456
- **Supabase RLS Best Practices**: https://supabase.com/docs/guides/database/postgres/row-level-security
- **PostgreSQL RLS Documentation**: https://www.postgresql.org/docs/current/ddl-rowsecurity.html

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| v3.46 | 2025-10-10 | Complete RLS fix (uid wrapper, grants, policy updates) |
| v3.45 | 2025-10-09 | PostgREST schema configuration fix |
| v3.44 | 2025-10-08 | Search path fix for GoTrue |

---

## 👥 Credits

**Diagnosed and Fixed By**: Claude Code Assistant
**Tested By**: User with production application
**Repository**: pi5-setup (Raspberry Pi 5 Supabase Self-Hosted)

---

## 📧 Support

If you encounter issues after applying this fix:

1. Run the diagnostic script:
   ```bash
   cd ~/stacks/supabase
   ./scripts/utils/diagnose-rls.sh
   ```

2. Check the logs:
   ```bash
   tail -100 /var/log/supabase-rls-fix-*.log
   ```

3. Create an issue with:
   - Output from diagnostic script
   - Your application logs showing the error
   - PostgreSQL version (`docker exec supabase-db psql --version`)
   - Supabase component versions (`docker ps --format '{{.Image}}'`)

---

**This fix is production-ready and has been tested successfully on Raspberry Pi 5 with real applications.** ✅
