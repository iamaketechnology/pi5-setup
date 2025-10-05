#!/usr/bin/env bash
# Navidrome - Phase 20
# Serveur de streaming musical
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(cd "${SCRIPT_DIR}/../../.." && pwd)/common-scripts/lib.sh"

STACK_DIR="${HOME}/stacks/navidrome"
mkdir -p "${STACK_DIR}" "${HOME}/data/music"

cat > "${STACK_DIR}/docker-compose.yml" <<'EOF'
version: '3.8'
services:
  navidrome:
    image: deluan/navidrome:latest
    container_name: navidrome
    user: 1000:1000
    ports:
      - "4533:4533"
    environment:
      ND_SCANSCHEDULE: "1h"
      ND_LOGLEVEL: info
      ND_BASEURL: ""
    volumes:
      - ./data:/data
      - ~/data/music:/music:ro
    restart: unless-stopped
EOF

docker-compose -f "${STACK_DIR}/docker-compose.yml" up -d
sleep 20
echo "✅ Navidrome: http://raspberrypi.local:4533"
echo "   Créer compte admin à première connexion"
echo "   Musique: ${HOME}/data/music"
echo "   Apps: Subsonic-compatibles (DSub, Ultrasonic, etc.)"
