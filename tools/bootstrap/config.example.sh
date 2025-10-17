#!/bin/bash
# =============================================================================
# Bootstrap Configuration Example
# =============================================================================
# Copy this file to config.sh and customize for your environment
# =============================================================================

# Control Center URL (where the admin panel is running)
# Examples:
#   - Local network: http://192.168.1.100:4000
#   - Tailscale VPN: http://100.x.x.x:4000
#   - Public domain: https://pi-control.example.com
CONTROL_CENTER_URL="http://192.168.1.100:4000"

# SSH User (default: pi)
SSH_USER="pi"

# Optional: Custom hostname prefix
# If set, new Pi will be named: <PREFIX>-<RANDOM>
# Example: HOSTNAME_PREFIX="pi5" → pi5-a3f9b2c8
HOSTNAME_PREFIX="pi5"

# Optional: Default tags for new Pi
# Comma-separated list
DEFAULT_TAGS="production,auto-provisioned"

# Optional: Supabase direct connection (for Phase 3+)
# If Control Center is unavailable, Pi can register directly to Supabase
SUPABASE_URL="http://pi5.local:8001"
SUPABASE_ANON_KEY="your-anon-key-here"
