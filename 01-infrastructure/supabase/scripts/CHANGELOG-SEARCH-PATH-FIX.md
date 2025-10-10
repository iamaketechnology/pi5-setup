# 🔧 CHANGELOG - PostgreSQL search_path Fix v3.44

> **Date** : 2025-10-10
> **Version** : v3.44
> **Type** : Critical Database Configuration Fix

---

## 🎯 Problem Resolved

### Symptom
After fixing Kong configuration issues (v3.31), Auth endpoints returned **500 Database error**:

```json
{
  "code": 500,
  "error_code": "unexpected_failure",
  "msg": "Database error finding user",
  "error": "unable to find identity by email: ERROR: relation \"identities\" does not exist (SQLSTATE 42P01)"
}
```

### Cause Racine

PostgreSQL `search_path` did NOT include the `auth` schema, causing GoTrue to fail finding auth tables.

**Verification** :
```sql
-- Table exists in auth schema
\dt auth.*
-- Returns: auth.identities (and 16 other auth tables)

-- But search_path doesn't include auth
SHOW search_path;
-- Returns: "$user", public  ❌ Missing 'auth'
```

**Root cause**: GoTrue queries use unqualified table names like `identities` instead of `auth.identities`, relying on PostgreSQL's `search_path` to resolve the schema.

---

## ✅ Solution Implemented

### Database Configuration Change

Added new init SQL file: `04-fix-search-path.sql`

**Content**:
```sql
-- Set database-level search_path to include auth schema
ALTER DATABASE postgres SET search_path TO auth, public;
```

This ensures ALL connections to the `postgres` database automatically have the `auth` schema in their search path.

---

## 📁 Files Modified

### Main Deployment Script

**File**: `02-supabase-deploy.sh`

**Changes**:
- **Version**: Updated from v3.43 to v3.44
- **Lines 1504-1524**: Added new init SQL file creation
- **Line 1530**: Updated success message to include "04-search-path"
- **Line 54**: Added version history entry

**New Init File**:
```bash
cat > "$PROJECT_DIR/sql/init/04-fix-search-path.sql" << 'SQL_EOF'
-- =============================================================================
-- DATABASE CONFIGURATION - SEARCH_PATH FIX
-- =============================================================================
-- Fix for GoTrue "relation 'identities' does not exist" error
-- The auth schema needs to be in the search_path for GoTrue to find auth.identities
-- Reference: https://github.com/supabase/auth/issues/1265

-- Set database-level search_path to include auth schema
ALTER DATABASE postgres SET search_path TO auth, public;

-- Log the change
DO $$
BEGIN
  RAISE NOTICE 'search_path configured to include auth schema';
  RAISE NOTICE 'This fixes GoTrue error: relation "identities" does not exist';
END $$;

SQL_EOF
```

---

## 🔄 Migration Path

### For Existing Installations (Manual Fix)

If you already have Supabase installed and experiencing this issue:

```bash
# Connect to Pi
ssh pi@192.168.1.74

# Fix search_path
docker exec -e PGPASSWORD="<YOUR_POSTGRES_PASSWORD>" supabase-db \
  psql -U postgres -d postgres \
  -c "ALTER DATABASE postgres SET search_path TO auth, public;"

# Restart Auth service
cd ~/stacks/supabase
docker compose restart auth

# Verify fix
docker exec -e PGPASSWORD="<YOUR_POSTGRES_PASSWORD>" supabase-db \
  psql -U postgres -d postgres \
  -c "SHOW search_path;"
# Should return: auth, public
```

### For New Installations (After v3.44)

The fix is applied automatically during database initialization via `04-fix-search-path.sql`.

**No manual action required** ✅

---

## 🧪 Verification Tests

### Test 1: Verify search_path

```bash
ssh pi@192.168.1.74 "docker exec -e PGPASSWORD='<PASSWORD>' supabase-db \
  psql -U postgres -d postgres -c 'SHOW search_path;'"
```

**Expected result**: `auth, public`

### Test 2: Test Signup Endpoint

```bash
curl -X POST http://192.168.1.74:8001/auth/v1/signup \
  -H "Content-Type: application/json" \
  -H "apikey: <ANON_KEY>" \
  -d '{"email":"test@example.com","password":"testpass123"}'
```

**Expected result**: JSON response with user object (not 500 error)

### Test 3: Verify Auth Tables Accessible

```bash
ssh pi@192.168.1.74 "docker exec -e PGPASSWORD='<PASSWORD>' supabase-db \
  psql -U postgres -d postgres -c 'SELECT COUNT(*) FROM identities;'"
```

**Expected result**: Row count (not "relation does not exist")

---

## 📊 Impact

### Before v3.44 (Problem)
- ❌ Auth signup/login fails with 500 error
- ❌ GoTrue cannot access auth.identities table
- ❌ Applications cannot authenticate users
- ❌ Manual database fix required after installation

### After v3.44 (Solution)
- ✅ Auth signup/login works correctly
- ✅ GoTrue can access all auth tables
- ✅ Applications can authenticate users
- ✅ Automatic fix applied during installation
- ✅ No manual intervention needed

---

## 🔗 References

- **GitHub Issue**: https://github.com/supabase/auth/issues/1265
- **Stack Overflow**: https://stackoverflow.com/questions/76985060/supabase-auth-server-cant-find-tables
- **PostgreSQL search_path docs**: https://www.postgresql.org/docs/current/ddl-schemas.html#DDL-SCHEMAS-PATH
- **Supabase Self-Hosting**: https://supabase.com/docs/guides/self-hosting/docker

---

## 📚 Related Fixes

| Version | Date | Issue | Fix |
|---------|------|-------|-----|
| v3.29 | 2025-10-10 | Hardcoded API keys (2022) | Dynamic keys from .env |
| v3.30 | 2025-10-10 | Missing CORS header `x-supabase-api-version` | Added to all services |
| v3.31 | 2025-10-10 | Kong configuration structurally wrong | Use official Supabase config |
| **v3.44** | **2025-10-10** | **PostgreSQL search_path missing auth schema** | **Add 04-fix-search-path.sql** |

---

## 🎓 Technical Details

### Why This Happens

GoTrue uses **unqualified table names** in its SQL queries:

```sql
-- GoTrue query (simplified)
SELECT * FROM identities WHERE email = 'user@example.com';
```

PostgreSQL resolves unqualified table names using `search_path`:
1. Check `"$user"` schema (user-specific, usually doesn't exist)
2. Check `public` schema
3. **FAIL** - `identities` not found (it's in `auth` schema)

### Correct Behavior

With `search_path = auth, public`:
1. Check `"$user"` schema (skip)
2. Check `auth` schema → **FOUND** `auth.identities`
3. Query succeeds ✅

### Alternative Approaches (NOT Used)

**Option 1**: Modify GoTrue queries to use qualified names
- ❌ Requires forking Supabase Auth
- ❌ Maintenance burden

**Option 2**: Set search_path per connection
- ❌ Doesn't work with GoTrue's connection pooling
- ❌ Environment variable `PGOPTIONS` ignored

**Option 3**: Database-level search_path (CHOSEN ✅)
- ✅ Works for all connections
- ✅ No code changes needed
- ✅ Standard PostgreSQL feature
- ✅ Used by official Supabase Cloud

---

## ✅ Checklist Validation

- [x] Script `02-supabase-deploy.sh` modified
- [x] New init SQL file `04-fix-search-path.sql` created
- [x] Version updated to v3.44
- [x] Version history entry added
- [x] Manual fix tested on existing installation
- [x] Signup endpoint verified working
- [x] Auth tables accessible via unqualified names
- [x] CHANGELOG created
- [x] Issue researched and documented

---

**Status** : ✅ Fixed and tested
**Version** : v3.44
**Date** : 2025-10-10
**Author** : Claude Code

**🎉 Auth service now works correctly with automatic schema resolution!**
