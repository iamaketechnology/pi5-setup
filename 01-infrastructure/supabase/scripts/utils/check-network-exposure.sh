#!/bin/bash
# =============================================================================
# Network Exposure Checker - Supabase Pi5 Security Audit
# =============================================================================
# Purpose: Verify which services are accessible from Internet vs localhost
# Version: 1.0.0
# Author: PI5-SETUP Project
# =============================================================================

set -euo pipefail
# Auto-detect environment
PI_USER="${SUDO_USER:-$(whoami)}"
PI_IP=$(hostname -I | awk '{print $1}' || echo "unknown")

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  SUPABASE PI5 - NETWORK EXPOSURE SECURITY AUDIT${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# =============================================================================
# 1. Docker Containers Ports
# =============================================================================

echo -e "${BLUE}📦 1. DOCKER CONTAINERS & EXPOSED PORTS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
docker ps --format 'table {{.Names}}\t{{.Ports}}' | grep -E "supabase|traefik" || echo "No Supabase/Traefik containers running"
echo ""

# =============================================================================
# 2. Network Listening Ports
# =============================================================================

echo -e "${BLUE}🌐 2. NETWORK LISTENING PORTS${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${GREEN}✅ PUBLIC (0.0.0.0) - Accessible depuis Internet:${NC}"
sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0" | grep -E ":(80|443|8000|8001|3000|5432|54321)" || echo "  (none found - all services are localhost or internal)"
echo ""

echo -e "${YELLOW}🔒 LOCALHOST (127.0.0.1) - Accessible seulement depuis le Pi:${NC}"
sudo netstat -tlnp 2>/dev/null | grep "127.0.0.1" | grep -E ":(80|443|8000|8001|3000|5432|8080|8081)" || echo "  (none found)"
echo ""

# =============================================================================
# 3. Critical Services Check
# =============================================================================

echo -e "${BLUE}🔍 3. CRITICAL SERVICES EXPOSURE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_service() {
    local service_name="$1"
    local port="$2"
    local should_be_localhost="$3"

    local result=$(sudo netstat -tlnp 2>/dev/null | grep ":${port} " || true)

    if [[ -z "$result" ]]; then
        echo -e "${YELLOW}⚠️  ${service_name} (port ${port}): NOT LISTENING${NC}"
        return
    fi

    if echo "$result" | grep -q "0.0.0.0:${port}"; then
        if [[ "$should_be_localhost" == "yes" ]]; then
            echo -e "${RED}❌ ${service_name} (port ${port}): PUBLIC (DANGER!)${NC}"
            echo -e "   ${RED}   → Should be localhost only for security${NC}"
        else
            echo -e "${GREEN}✅ ${service_name} (port ${port}): PUBLIC (OK)${NC}"
        fi
    elif echo "$result" | grep -q "127.0.0.1:${port}"; then
        if [[ "$should_be_localhost" == "yes" ]]; then
            echo -e "${GREEN}✅ ${service_name} (port ${port}): LOCALHOST ONLY (Secured)${NC}"
        else
            echo -e "${YELLOW}⚠️  ${service_name} (port ${port}): LOCALHOST ONLY (may need to be public)${NC}"
        fi
    fi
}

# Check services
check_service "PostgreSQL" "5432" "yes"
check_service "Supabase Studio" "3000" "yes"
check_service "Kong API" "8001" "no"
check_service "Traefik HTTP" "80" "no"
check_service "Traefik HTTPS" "443" "no"

echo ""

# =============================================================================
# 4. Docker Network Connectivity Test
# =============================================================================

echo -e "${BLUE}🐳 4. DOCKER INTERNAL NETWORK${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if containers can communicate
if docker ps | grep -q "supabase-kong"; then
    echo -e "${GREEN}✅ Kong container running${NC}"

    # Test Kong → PostgREST
    if docker exec supabase-kong wget -q -O- http://rest:3000/rest/v1/ 2>/dev/null | grep -q "OpenAPI" || true; then
        echo -e "${GREEN}✅ Kong → PostgREST: Connected${NC}"
    else
        echo -e "${YELLOW}⚠️  Kong → PostgREST: Cannot verify${NC}"
    fi

    # Test Kong → GoTrue
    if docker exec supabase-kong wget -q -O- http://auth:9999/health 2>/dev/null | grep -q "ok" || true; then
        echo -e "${GREEN}✅ Kong → GoTrue: Connected${NC}"
    else
        echo -e "${YELLOW}⚠️  Kong → GoTrue: Cannot verify${NC}"
    fi
else
    echo -e "${RED}❌ Kong container not running${NC}"
fi

echo ""

# =============================================================================
# 5. External Access Test (from Internet)
# =============================================================================

echo -e "${BLUE}🌍 5. EXTERNAL ACCESS TEST${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get Pi IP
PI_IP=$(hostname -I | awk '{print $1}')
echo "Pi IP Address: $PI_IP"
echo ""

echo -e "${YELLOW}Testing from Pi (should work for all):${NC}"

# Test Kong API
if curl -s --connect-timeout 2 http://127.0.0.1:8001/rest/v1/ >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Kong API (8001): Accessible from localhost${NC}"
else
    echo -e "${RED}❌ Kong API (8001): NOT accessible from localhost${NC}"
fi

# Test Studio
if curl -s --connect-timeout 2 http://127.0.0.1:3000 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Supabase Studio (3000): Accessible from localhost${NC}"
else
    echo -e "${RED}❌ Supabase Studio (3000): NOT accessible from localhost${NC}"
fi

# Test PostgreSQL
if timeout 2 bash -c "cat < /dev/null > /dev/tcp/127.0.0.1/5432" 2>/dev/null; then
    echo -e "${GREEN}✅ PostgreSQL (5432): Accessible from localhost${NC}"
else
    echo -e "${RED}❌ PostgreSQL (5432): NOT accessible from localhost${NC}"
fi

echo ""

# =============================================================================
# 6. Security Recommendations
# =============================================================================

echo -e "${BLUE}🛡️  6. SECURITY ASSESSMENT${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if PostgreSQL is public (fix: only check 0.0.0.0, not 127.0.0.1)
if sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:5432" | grep -v "127.0.0.1" >/dev/null 2>&1; then
    echo -e "${RED}❌ CRITICAL: PostgreSQL is publicly accessible!${NC}"
    echo -e "   Run: sudo bash /path/to/03-secure-supabase-ports.sh"
    echo ""
fi

# Check if Studio is public (fix: only check 0.0.0.0, not 127.0.0.1)
if sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:3000" | grep -v "127.0.0.1" >/dev/null 2>&1; then
    echo -e "${RED}❌ CRITICAL: Supabase Studio is publicly accessible!${NC}"
    echo -e "   Run: sudo bash /path/to/03-secure-supabase-ports.sh"
    echo ""
fi

# Check if Kong is localhost (should be public)
if sudo netstat -tlnp 2>/dev/null | grep -q "127.0.0.1:8001"; then
    echo -e "${YELLOW}⚠️  WARNING: Kong API is localhost only (apps won't work from Internet)${NC}"
    echo -e "   Kong should bind to 0.0.0.0:8001 for external access"
    echo ""
fi

# Final verdict
postgres_public=$(sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:5432" || true)
studio_public=$(sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:3000" || true)
kong_ok=$(sudo netstat -tlnp 2>/dev/null | grep "0.0.0.0:8001" || true)

if [[ -z "$postgres_public" ]] && [[ -z "$studio_public" ]] && [[ -n "$kong_ok" ]]; then
    echo -e "${GREEN}✅ SECURITY STATUS: EXCELLENT${NC}"
    echo -e "   - PostgreSQL is localhost only (secured)"
    echo -e "   - Studio is localhost only (secured)"
    echo -e "   - Kong API is public (correct)"
    echo ""
    echo -e "${GREEN}Your Supabase installation follows security best practices!${NC}"
elif [[ -n "$postgres_public" ]] || [[ -n "$studio_public" ]]; then
    echo -e "${RED}❌ SECURITY STATUS: VULNERABLE${NC}"
    echo -e "   Critical services are exposed to the Internet!"
    echo ""
    echo -e "${YELLOW}RECOMMENDED ACTION:${NC}"
    echo -e "   sudo bash /path/to/03-secure-supabase-ports.sh"
else
    echo -e "${YELLOW}⚠️  SECURITY STATUS: NEEDS REVIEW${NC}"
    echo -e "   Some services may not be configured optimally"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  ACCESS SERVICES FROM OUTSIDE:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}To access localhost services from your Mac:${NC}"
echo ""
echo "  # SSH Tunnel (recommended)"
echo "  ssh -L 3000:localhost:3000 -L 5432:localhost:5432 pi@${PI_IP}"
echo "  # Then open: http://localhost:3000 (Studio)"
echo ""
echo "  # Or install Tailscale VPN on both Pi and Mac"
echo "  # https://tailscale.com/download"
echo ""

echo -e "${BLUE}Report generated: $(date)${NC}"
echo ""
