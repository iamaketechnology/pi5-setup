#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Get Supabase Credentials Helper Script
# =============================================================================
# Purpose: Display Supabase credentials for application configuration
# Usage: ./get-supabase-credentials.sh
# Author: PI5-SETUP Project
# =============================================================================

# Color output functions
log()   { echo -e "\033[1;36m[INFO]\033[0m $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok()    { echo -e "\033[1;32m[OK]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

# Global variables
TARGET_USER="${SUDO_USER:-${USER}}"
SUPABASE_DIR="/home/${TARGET_USER}/stacks/supabase"
TRAEFIK_DIR="/home/${TARGET_USER}/stacks/traefik"

echo ""
echo "=========================================="
echo "🔑 Supabase Credentials Retriever"
echo "=========================================="
echo ""

# Check if Supabase is installed
if [[ ! -d "$SUPABASE_DIR" ]]; then
    error "Supabase directory not found at $SUPABASE_DIR"
    echo ""
    echo "Please ensure Supabase is installed first."
    exit 1
fi

# Check if .env file exists
if [[ ! -f "$SUPABASE_DIR/.env" ]]; then
    error "Supabase .env file not found at $SUPABASE_DIR/.env"
    echo ""
    echo "Please ensure Supabase is properly installed."
    exit 1
fi

# Extract credentials
ANON_KEY=$(grep "^ANON_KEY=" "$SUPABASE_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
SERVICE_ROLE_KEY=$(grep "^SERVICE_ROLE_KEY=" "$SUPABASE_DIR/.env" | cut -d'=' -f2- | tr -d '"' | tr -d "'")

if [[ -z "$ANON_KEY" ]]; then
    error "Could not extract ANON_KEY from .env file"
    exit 1
fi

# Detect Traefik scenario and construct URL
SUPABASE_URL=""
STUDIO_URL=""

if [[ -d "$TRAEFIK_DIR" ]] && [[ -f "$TRAEFIK_DIR/.env" ]]; then
    source "$TRAEFIK_DIR/.env" 2>/dev/null || true

    if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
        # DuckDNS scenario - path-based routing
        DOMAIN="${DUCKDNS_SUBDOMAIN}.duckdns.org"
        SUPABASE_URL="https://${DOMAIN}/api"
        STUDIO_URL="https://${DOMAIN}/studio"
        ok "Detected: Traefik with DuckDNS (${DOMAIN})"
    elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]]; then
        # Cloudflare scenario - subdomain routing
        DOMAIN="${CLOUDFLARE_DOMAIN}"
        SUPABASE_URL="https://api.${DOMAIN}"
        STUDIO_URL="https://studio.${DOMAIN}"
        ok "Detected: Traefik with Cloudflare (${DOMAIN})"
    elif [[ -n "${VPN_DOMAIN:-}" ]]; then
        # VPN scenario
        DOMAIN="${VPN_DOMAIN}"
        SUPABASE_URL="https://api.pi.local"
        STUDIO_URL="https://studio.pi.local"
        ok "Detected: Traefik with VPN (local access)"
    else
        warn "Traefik found but scenario not detected"
        # Fallback to Kong port
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        SUPABASE_URL="http://${LOCAL_IP}:8001"
        STUDIO_URL="http://${LOCAL_IP}:3000"
        warn "Using local IP fallback: ${LOCAL_IP}"
    fi
else
    warn "Traefik not detected or not installed"
    # Fallback to Kong port
    LOCAL_IP=$(hostname -I | awk '{print $1}')
    SUPABASE_URL="http://${LOCAL_IP}:8001"
    STUDIO_URL="http://${LOCAL_IP}:3000"
    warn "Using local IP: ${LOCAL_IP}"
    echo ""
    echo "💡 Tip: Install Traefik to get HTTPS and public access"
    echo "   Run: curl -fsSL https://raw.githubusercontent.com/.../01-traefik-deploy-duckdns.sh | sudo bash"
fi

echo ""
echo "=========================================="
echo "📋 Copy-Paste for Lovable.ai / Vercel / Netlify"
echo "=========================================="
echo ""
echo "VITE_SUPABASE_URL=${SUPABASE_URL}"
echo "VITE_SUPABASE_ANON_KEY=${ANON_KEY}"
echo ""

echo "=========================================="
echo "📋 Copy-Paste for Next.js"
echo "=========================================="
echo ""
echo "NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL}"
echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}"
echo ""

echo "=========================================="
echo "🌐 Access URLs"
echo "=========================================="
echo ""
echo "Supabase API  : ${SUPABASE_URL}"
echo "Supabase Studio : ${STUDIO_URL}"
echo ""

if [[ -f "$TRAEFIK_DIR/.env" ]]; then
    DASHBOARD_PASSWORD=$(grep "^DASHBOARD_PASSWORD=" "$TRAEFIK_DIR/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'")
    if [[ -n "$DASHBOARD_PASSWORD" ]] && [[ -n "${DOMAIN:-}" ]]; then
        echo "=========================================="
        echo "🔐 Traefik Dashboard"
        echo "=========================================="
        echo ""
        if [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
            echo "URL      : https://${DOMAIN}/traefik"
        elif [[ -n "${CLOUDFLARE_DOMAIN:-}" ]]; then
            echo "URL      : https://traefik.${DOMAIN}"
        else
            echo "URL      : https://traefik.pi.local"
        fi
        echo "Username : admin"
        echo "Password : ${DASHBOARD_PASSWORD}"
        echo ""
    fi
fi

echo "=========================================="
echo "⚠️  Service Role Key (Backend Only)"
echo "=========================================="
echo ""
echo "⚠️  NEVER expose this key to the client (browser)!"
echo "⚠️  Use only in secure backend/server environments"
echo ""
echo "SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}"
echo ""

echo "=========================================="
echo "💾 Save These Credentials"
echo "=========================================="
echo ""
echo "This information is also saved in:"
echo "  - $SUPABASE_DIR/.env"
if [[ -d "$TRAEFIK_DIR" ]]; then
    echo "  - $TRAEFIK_DIR/.env (Traefik dashboard password)"
fi
echo ""
echo "To retrieve credentials again, run:"
echo "  bash $(realpath "$0")"
echo ""
echo "=========================================="
