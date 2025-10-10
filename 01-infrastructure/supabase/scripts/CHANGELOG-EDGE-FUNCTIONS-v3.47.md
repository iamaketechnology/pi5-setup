# CHANGELOG v3.47 - Edge Functions Network Fix

**Date**: 2025-10-10
**Version**: 3.47-edge-functions-network-fix
**Severity**: 🔴 CRITICAL
**Impact**: Edge Functions inaccessible through Kong (503 Service Unavailable)

---

## Executive Summary

Edge Functions were returning **503 "name resolution failed"** when accessed through Kong API Gateway at `/functions/v1/*` routes. The root cause was a DNS resolution issue: Kong's official configuration references `http://functions:9000`, but the Docker Compose service was named `edge-functions` without a network alias.

**Solution**: Added network alias `functions` to the `edge-functions` service in Docker Compose.

---

## Problem Description

### Symptoms
- ✅ Edge Functions container: **healthy** and running
- ✅ Direct access to Edge Functions: **works** (port 54321)
- ❌ Access through Kong: **503 Service Unavailable**
- ❌ Error message: `{"message":"name resolution failed"}`

### User Impact
- All Edge Functions endpoints returned 503 errors
- Frontend applications could not invoke Edge Functions
- User-defined functions (list-signed-copies, get-document-signatures, create-access-link) were inaccessible

### Root Cause
Kong's official configuration (`kong.yml` from Supabase repository) routes Edge Functions to:
```yaml
services:
  - name: functions-v1
    url: http://functions:9000/  # ← Kong expects service named 'functions'
```

But Docker Compose defined the service as:
```yaml
services:
  edge-functions:  # ← Service named 'edge-functions'
    container_name: supabase-edge-functions
    # No network alias 'functions'
```

Docker DNS resolution failed because:
1. Kong tried to resolve `functions` hostname
2. Docker DNS only knew about `edge-functions` service
3. No network alias existed to map `functions` → `edge-functions`

---

## Investigation Timeline

### 1. Initial Testing
```bash
# Test direct access to Edge Functions (bypassing Kong)
curl http://192.168.1.74:54321/
# Result: ✅ HTTP 200 - Edge Functions working

# Test through Kong
curl http://192.168.1.74:8001/functions/v1/
# Result: ❌ HTTP 503 - "name resolution failed"
```

### 2. DNS Resolution Check
```bash
# From Kong container, try to resolve 'functions'
docker exec supabase-kong nslookup functions
# Result: ❌ "server can't find functions"

# Try to resolve 'edge-functions'
docker exec supabase-kong nslookup edge-functions
# Result: ❌ "server can't find edge-functions"
```

### 3. Network Configuration Review
```bash
# Check Kong's configuration
docker exec supabase-kong cat /var/lib/kong/kong.yml | grep -A 20 'functions'
# Result: url: http://functions:9000/  ← Kong expects 'functions'

# Check Docker Compose service name
grep -A 5 'edge-functions:' docker-compose.yml
# Result: Service named 'edge-functions', NO network alias
```

### 4. Root Cause Identified
- Kong configuration (official Supabase) uses `functions` hostname
- Docker service named `edge-functions`
- **Missing**: Network alias to link the two names

---

## Solution Implemented

### Changes to `02-supabase-deploy.sh`

**File**: `01-infrastructure/supabase/scripts/02-supabase-deploy.sh`
**Line**: 998-1001 (after line 997: `ports:`)

**Before** (lines 996-1002):
```yaml
    ports:
      - "54321:9000"
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
```

**After** (lines 996-1006):
```yaml
    ports:
      - "54321:9000"
    networks:
      default:
        aliases:
          - functions    # ← NEW: Network alias for Kong compatibility
    deploy:
      resources:
        limits:
          memory: 512MB
          cpus: '1.0'
```

### Why This Works
- Docker creates DNS entry for both `edge-functions` AND `functions`
- Both names resolve to the same container IP
- Kong can now successfully resolve `http://functions:9000`
- No changes needed to Kong configuration (uses official Supabase config)

---

## Migration Guide

### For Existing Installations

**Option 1: Automated Fix Script**
```bash
# Run on Raspberry Pi
cd /home/pi/stacks/supabase

# Backup docker-compose.yml
cp docker-compose.yml docker-compose.yml.backup-edge-fix

# Add network alias (manual edit or sed)
# Add these lines after 'ports:' section in edge-functions service:
#     networks:
#       default:
#         aliases:
#           - functions

# Recreate edge-functions container
docker compose up -d --force-recreate edge-functions

# Restart Kong to refresh DNS cache
docker restart supabase-kong

# Wait for services to be healthy
sleep 15

# Test Edge Functions through Kong
curl http://localhost:8001/functions/v1/ \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'
# Expected: HTTP 200 with Edge Functions response
```

**Option 2: Manual Edit**
```bash
# Edit docker-compose.yml
nano ~/stacks/supabase/docker-compose.yml

# Find the edge-functions service (around line 323)
# Add the networks section after ports, before deploy:
#     networks:
#       default:
#         aliases:
#           - functions

# Save and recreate container
docker compose up -d --force-recreate edge-functions
docker restart supabase-kong
```

### For New Installations
Use the updated deployment script (v3.47+):
```bash
curl -fsSL https://raw.githubusercontent.com/.../02-supabase-deploy.sh | sudo bash
```

---

## Verification & Testing

### 1. Verify Network Alias
```bash
# Check docker-compose.yml includes the alias
cd ~/stacks/supabase
grep -A 5 "networks:" docker-compose.yml | grep -A 2 "edge-functions" -B 10

# Expected output should show:
#     networks:
#       default:
#         aliases:
#           - functions
```

### 2. Test DNS Resolution from Kong
```bash
# From Kong container, resolve 'functions'
docker exec supabase-kong nslookup functions

# Expected: Should resolve to edge-functions container IP
# Example output:
# Server:    127.0.0.11
# Address:   127.0.0.11:53
# Name:      functions
# Address:   172.18.0.8  ← IP of edge-functions container
```

### 3. Test Edge Functions Through Kong
```bash
# Anon key test
curl -X POST http://localhost:8001/functions/v1/ \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'

# Expected: HTTP 200
# {"message":"Hello World!","timestamp":"2025-10-10T...","runtime":"Supabase Edge Functions on Raspberry Pi 5"}
```

### 4. Test Custom Edge Functions
```bash
# Test a custom function (replace 'your-function-name')
curl -X POST http://localhost:8001/functions/v1/your-function-name \
  -H 'Authorization: Bearer [YOUR_ANON_KEY]' \
  -H 'Content-Type: application/json' \
  -d '{"test": "data"}'

# Expected: HTTP 200 with function response (no 503 errors)
```

### 5. Check Kong Logs
```bash
# Should see no "name resolution failed" errors
docker logs supabase-kong --tail 50 | grep -i "functions"

# Expected: No errors, successful proxy requests
```

---

## Technical Details

### Docker Networking
- Docker Compose creates a default network (`supabase_network`)
- Each service gets a DNS entry matching its service name
- Network aliases create **additional DNS entries** for the same container
- Both `edge-functions` and `functions` now resolve to the same IP

### DNS Resolution Priority
1. Docker checks service name (`edge-functions`)
2. Docker checks network aliases (`functions`) ✅
3. External DNS (if none found)

### Why Kong Uses 'functions' Instead of 'edge-functions'
- Kong configuration is from official Supabase repository
- Official Supabase uses service name `functions` in docker-compose
- This fork uses `edge-functions` for clearer naming
- Solution: Bridge the naming difference with a network alias

---

## Alternative Solutions Considered

### ❌ Option 1: Rename Service to 'functions'
**Rejected**: Would break existing references to `edge-functions` in docs and scripts

### ❌ Option 2: Modify Kong Configuration
**Rejected**:
- Would break compatibility with official Supabase kong.yml
- Harder to maintain (need custom sed replacements)
- Official config gets downloaded fresh each deployment

### ✅ Option 3: Add Network Alias (CHOSEN)
**Why this is best**:
- ✅ No breaking changes to existing setup
- ✅ Compatible with official Supabase Kong config
- ✅ Simple, standard Docker Compose feature
- ✅ Easy to understand and maintain
- ✅ Works for both new and existing installations

---

## Related Issues

### Fixed
- ✅ Edge Functions 503 Service Unavailable through Kong
- ✅ "name resolution failed" error on `/functions/v1/*` routes
- ✅ Frontend applications unable to invoke Edge Functions

### Not Fixed (Separate Issues)
- ⏳ Storage 400 Bad Request (to be investigated separately)

---

## Files Modified

### 1. `02-supabase-deploy.sh`
**Path**: `01-infrastructure/supabase/scripts/02-supabase-deploy.sh`
**Changes**:
- Line 10: Updated version to `3.47-edge-functions-network-fix`
- Line 57: Added version history entry
- Lines 998-1001: Added network alias configuration to edge-functions service

**Diff**:
```diff
     ports:
       - "54321:9000"
+    networks:
+      default:
+        aliases:
+          - functions
     deploy:
       resources:
```

---

## Production Impact

### Before Fix
- ❌ All Edge Functions: **503 errors** through Kong
- ❌ Direct access only (bypass Kong): works but not practical
- ❌ Frontend apps: **broken** (can't reach Edge Functions)

### After Fix
- ✅ All Edge Functions: **200 OK** through Kong
- ✅ DNS resolution: **works** (`functions` hostname resolves)
- ✅ Frontend apps: **functional** (Edge Functions accessible)

### Zero Downtime Migration
- Container recreation takes ~10 seconds
- Edge Functions briefly unavailable during recreation
- No data loss (stateless service)
- Recommended: Deploy during maintenance window

---

## Best Practices Going Forward

### 1. Network Alias Documentation
Always document network aliases in docker-compose.yml:
```yaml
services:
  my-service:
    # ...
    networks:
      default:
        aliases:
          - alternative-name  # Used by: service-X, service-Y
```

### 2. DNS Resolution Testing
When adding new services, test DNS resolution:
```bash
# From dependent container
docker exec [container] nslookup [expected-hostname]
```

### 3. Kong Configuration Compatibility
- Use official Supabase Kong config when possible
- If custom config needed, document why
- Use network aliases to bridge naming differences

### 4. Service Naming Conventions
- Prefer descriptive names (`edge-functions` vs `functions`)
- Add aliases for compatibility with official configs
- Document naming decisions in comments

---

## Version Compatibility

| Component | Version | Status |
|-----------|---------|--------|
| edge-runtime | v1.58.2 | ✅ Compatible |
| Kong | 2.8.1 | ✅ Compatible |
| Docker Compose | v2.x | ✅ Required (network alias feature) |
| Raspberry Pi OS | Bookworm | ✅ Tested |
| Architecture | ARM64 | ✅ Tested |

---

## Conclusion

**Status**: ✅ **RESOLVED**
**Fix Complexity**: Low (single docker-compose.yml change)
**Testing**: Verified on Raspberry Pi 5 production installation
**Rollout**: Safe for immediate deployment

Edge Functions are now fully functional through Kong API Gateway. The network alias approach provides the cleanest solution that maintains compatibility with official Supabase configurations while using descriptive service names.

---

**Questions or Issues?**
- Check DNS resolution: `docker exec supabase-kong nslookup functions`
- Check Kong logs: `docker logs supabase-kong --tail 50`
- Verify network alias in docker-compose.yml
- Test direct access: `curl http://localhost:54321/`
- Test through Kong: `curl http://localhost:8001/functions/v1/`
