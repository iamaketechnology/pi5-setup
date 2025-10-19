#!/bin/bash
# =============================================================================
# Admin Panel Server Starter
# =============================================================================
# Kills existing instances before starting a fresh server
# Usage: bash start-server.sh
# =============================================================================

set -euo pipefail

echo "🔍 Checking for existing server instances..."

# Kill all existing node server.js instances
pkill -9 -f "node server.js" 2>/dev/null && echo "✅ Killed existing instances" || echo "ℹ️  No existing instances"

# Wait for ports to be released
sleep 2

# Check if port 4000 is still in use
if lsof -ti:4000 >/dev/null 2>&1; then
    echo "⚠️  Port 4000 still in use, forcing cleanup..."
    lsof -ti:4000 | xargs kill -9 2>/dev/null
    sleep 1
fi

echo "🚀 Starting Admin Panel Server..."
echo ""

# Start server
cd "$(dirname "$0")"
node server.js
